import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../llm/llm_generate_request.dart';
import '../llm/llm_service.dart';
import '../state/settings_store.dart';

enum ChatLoadState { initializing, modelLoading, ready, generating, error }

@immutable
class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  /// 'user' | 'assistant' | 'system'
  final String role;
  final String content;
}

/// Drives the terminal chat UI.
///
/// Call [initialize] once, then [sendMessage] / [reset] / [dispose].
class NativeLlmChatController extends ChangeNotifier {
  NativeLlmChatController();

  final _llm = LlmService.instance;

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  ChatLoadState _state = ChatLoadState.initializing;
  ChatLoadState get state => _state;

  String _statusMessage = 'Starting up…';
  String get statusMessage => _statusMessage;

  /// Token buffer while an assistant response is still streaming.
  String _streamingBuffer = '';
  String get streamingBuffer => _streamingBuffer;

  double? _loadProgress;
  double? get loadProgress => _loadProgress;

  bool get isBusy =>
      _state == ChatLoadState.initializing ||
      _state == ChatLoadState.modelLoading ||
      _state == ChatLoadState.generating;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _set(ChatLoadState.modelLoading, 'Loading settings…');

    final settings = SettingsStore();
    try {
      await settings.load();
    } on Object {
      // SharedPreferences can fail in test / first-run environments.
    }

    _llm.configure(
      settings,
      onModelLifecycle: (phase, msg, pct) {
        _statusMessage = msg;
        _loadProgress = pct?.toDouble();
        notifyListeners();
      },
      onModelInstallProgress: (pct) {
        _loadProgress = pct.toDouble();
        notifyListeners();
      },
    );

    _set(ChatLoadState.modelLoading, 'Loading on-device model…');

    try {
      await _llm.ensureReady();
      _llm.releaseInstallUiHooks(settings);
      _set(ChatLoadState.ready, 'Gemma 4 ready — type a message and press ↵');
      _messages.add(
        const ChatMessage(
          role: 'system',
          content:
              'Gemma 4 on-device model loaded.\n'
              'Commands: /reset  /model  /quit',
        ),
      );
      notifyListeners();
    } on Object catch (e) {
      _set(ChatLoadState.error, 'Failed to load model: $e');
    }
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Handle slash commands.
    if (trimmed.startsWith('/')) {
      _handleCommand(trimmed);
      return;
    }

    if (_state != ChatLoadState.ready) return;

    _messages.add(ChatMessage(role: 'user', content: trimmed));
    _streamingBuffer = '';
    _set(ChatLoadState.generating, 'Generating…');

    final prompt = _buildPrompt();
    final request = LlmGenerateRequest(
      prompt: ModelBoundPrompt(prompt),
      maxTokens: 512,
    );

    try {
      final stream = await _llm.tryOpenGenerateStream(request);
      if (stream != null) {
        await for (final token in stream) {
          if (token.isEmpty) continue;
          _streamingBuffer += token;
          notifyListeners();
        }
        _commitStreamingBuffer();
      } else {
        final result = await _llm.generate(request);
        _messages.add(ChatMessage(role: 'assistant', content: result.text));
      }
    } on Object catch (e) {
      _commitStreamingBuffer();
      if (_isRecoverableStreamError(e)) {
        await _retryWithSyncFallback(request, originalError: e);
      } else {
        _messages.add(ChatMessage(role: 'assistant', content: '[Error] $e'));
      }
    }

    _set(ChatLoadState.ready, 'Ready');
  }

  void reset() {
    _messages.clear();
    _streamingBuffer = '';
    _messages.add(
      const ChatMessage(role: 'system', content: 'Conversation cleared.'),
    );
    notifyListeners();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  void _set(ChatLoadState newState, String msg) {
    _state = newState;
    _statusMessage = msg;
    notifyListeners();
  }

  void _commitStreamingBuffer() {
    if (_streamingBuffer.isNotEmpty) {
      _messages.add(
        ChatMessage(role: 'assistant', content: _streamingBuffer),
      );
      _streamingBuffer = '';
    }
  }

  /// True when the stream error is a LiteRT-LM async-prefill failure that can
  /// be recovered by closing + reloading the engine, then calling sync generate.
  ///
  /// `generateChunkStream` already resets [FlutterGemmaLlmEngine._loaded] and
  /// queues a native `closeModel` when it detects this pattern; we just need to
  /// finish the handshake by calling [LlmService.invalidateCachedEngine] (which
  /// discards the Dart engine object) and then reload via [LlmService.ensureReady].
  bool _isRecoverableStreamError(Object e) {
    if (e is! PlatformException) return false;
    if (e.code != 'stream_failed') return false;
    final m = (e.message ?? '').toLowerCase();
    return m.contains('failed to invoke') ||
        m.contains('failed to allocate') ||
        m.contains('dynamic_update_slice') ||
        m.contains('status code:') ||
        m.contains('litertlmjniexception') ||
        m.contains('litertlm') ||
        m.contains('litert');
  }

  /// Two-tier recovery after a [stream_failed] LiteRT async-prefill error.
  ///
  /// **Tier 1 (caller):** streaming path (`RunPrefillAsync`) — already failed.
  ///
  /// **Tier 2 (here):** invalidate + reload at 512 tokens, try sync
  /// `generate()` (`nativeSendMessage` / `RunPrefill` — different code path).
  ///
  /// If Tier 2 also fails (same XNNPack DYNAMIC_UPDATE_SLICE root cause) the
  /// user is shown a clear message pointing to the GPU config.
  ///
  /// **Why no Tier 3 (256 tokens):** 256-token engine init hits
  /// `DYNAMIC_UPDATE_SLICE` node 2122 during `Engine.initialize()` itself
  /// (`load_failed`) — worse than 512, and would trigger the
  /// purge-and-redownload chain inside [FlutterGemmaLlmEngine]. Ruled out.
  Future<void> _retryWithSyncFallback(
    LlmGenerateRequest request, {
    required Object originalError,
  }) async {
    _messages.add(
      const ChatMessage(
        role: 'system',
        content:
            'Stream inference failed (LiteRT async-prefill error). '
            'Reloading engine and retrying with sync path…',
      ),
    );
    notifyListeners();

    try {
      _set(ChatLoadState.modelLoading, 'Reloading engine (512 tokens)…');
      await _llm.invalidateCachedEngine();
      await _llm.ensureReady();

      _set(ChatLoadState.generating, 'Retrying sync…');
      final result = await _llm.generate(request);
      _messages.add(ChatMessage(role: 'assistant', content: result.text));
    } on Object catch (e2) {
      _messages.add(_cpuExhaustedMessage(originalError, e2));
    }
  }

  /// Terminal error shown when both CPU code paths are blocked.
  ChatMessage _cpuExhaustedMessage(Object streamErr, Object syncErr) {
    return ChatMessage(
      role: 'assistant',
      content:
          '[Both CPU paths blocked — XNNPack DYNAMIC_UPDATE_SLICE]\n\n'
          'Async prefill: ${_shortError(streamErr)}\n'
          'Sync prefill:  ${_shortError(syncErr)}\n\n'
          'GPU is the only remaining option on this device:\n'
          '  VS Code  →  "cli chat (GPU • 23106RN0DA)"\n'
          '  Terminal →  learner_app/tool/run_chat.sh --gpu\n\n'
          'Caution: GPU loadModel init may crash on some MIUI devices.\n'
          'Run with --verbose to confirm "native loadModel end" appears.',
    );
  }

  /// Extracts the most readable part of an error for terminal display.
  String _shortError(Object e) {
    final s = e.toString();
    final inner = RegExp(r'PlatformException\([^,]+, ([^,\n]+)').firstMatch(s);
    if (inner != null) return inner.group(1) ?? s;
    if (s.contains('LlmResourceException')) {
      return s.replaceFirst('LlmResourceException: Inference failed: ', '');
    }
    return s;
  }

  void _handleCommand(String cmd) {
    switch (cmd.toLowerCase()) {
      case '/reset':
        reset();
      case '/quit':
        _messages.add(
          const ChatMessage(
            role: 'system',
            content: 'Use the device back button or swipe down to exit.',
          ),
        );
        notifyListeners();
      case '/model':
        _messages.add(
          const ChatMessage(
            role: 'system',
            content:
                'Active model: Gemma 4 (LiteRT-LM on Android, MediaPipe on iOS).',
          ),
        );
        notifyListeners();
      default:
        _messages.add(
          ChatMessage(
            role: 'system',
            content: 'Unknown command: $cmd\nAvailable: /reset  /model  /quit',
          ),
        );
        notifyListeners();
    }
  }

  /// Gemma 4 multi-turn chat template.
  String _buildPrompt() {
    final sb = StringBuffer();
    for (final msg in _messages) {
      if (msg.role == 'user') {
        sb.write('<start_of_turn>user\n${msg.content}<end_of_turn>\n');
      } else if (msg.role == 'assistant') {
        sb.write('<start_of_turn>model\n${msg.content}<end_of_turn>\n');
      }
      // 'system' messages are not forwarded to the model.
    }
    sb.write('<start_of_turn>model\n');
    return sb.toString();
  }

  @override
  void dispose() {
    _llm.dispose();
    super.dispose();
  }
}
