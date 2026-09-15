import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_llm_chat_controller.dart';

// ── Palette ─────────────────────────────────────────────────────────────────

const _kBg = Color(0xFF0D1117);
const _kBgAlt = Color(0xFF161B22);
const _kGreen = Color(0xFF3FB950);
const _kBlue = Color(0xFF79C0FF);
const _kYellow = Color(0xFFE3B341);
const _kRed = Color(0xFFF85149);
const _kMuted = Color(0xFF8B949E);
const _kBorder = Color(0xFF21262D);
const _kWhite = Color(0xFFE6EDF3);

const _kMono = TextStyle(
  fontFamily: 'monospace',
  fontSize: 13.5,
  height: 1.55,
  letterSpacing: 0.2,
);

// ── Screen ──────────────────────────────────────────────────────────────────

class NativeLlmChatScreen extends StatefulWidget {
  const NativeLlmChatScreen({super.key});

  @override
  State<NativeLlmChatScreen> createState() => _NativeLlmChatScreenState();
}

class _NativeLlmChatScreenState extends State<NativeLlmChatScreen>
    with TickerProviderStateMixin {
  late final NativeLlmChatController _ctrl;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();

  /// Tracks typed-ahead history for ↑/↓ navigation.
  final List<String> _history = [];
  int _histIdx = -1;
  String _draft = '';

  late final AnimationController _spinnerTick;
  int _spinnerFrame = 0;
  Timer? _blinkTimer;
  bool _cursorVisible = true;

  static const _spinFrames = ['⠋', '⠙', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  @override
  void initState() {
    super.initState();

    _ctrl = NativeLlmChatController();
    _ctrl.addListener(_onStateChange);
    _ctrl.initialize();

    _spinnerTick = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..addListener(() {
        setState(() => _spinnerFrame = (_spinnerFrame + 1) % _spinFrames.length);
      });
    _spinnerTick.repeat();

    _blinkTimer = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _cursorVisible = !_cursorVisible);
    });
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ctrl
      ..removeListener(_onStateChange)
      ..dispose();
    _spinnerTick.dispose();
    _blinkTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Input handling ─────────────────────────────────────────────────────────

  void _submit() {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    // Add to local history.
    if (_history.isEmpty || _history.last != text) _history.add(text);
    _histIdx = -1;
    _draft = '';

    _input.clear();
    _ctrl.sendMessage(text);
    _inputFocus.requestFocus();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_history.isEmpty) return true;
      if (_histIdx == -1) {
        _draft = _input.text;
        _histIdx = _history.length - 1;
      } else if (_histIdx > 0) {
        _histIdx--;
      }
      _input.text = _history[_histIdx];
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_histIdx == -1) return true;
      if (_histIdx < _history.length - 1) {
        _histIdx++;
        _input.text = _history[_histIdx];
      } else {
        _histIdx = -1;
        _input.text = _draft;
      }
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      return true;
    }

    return false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(state: _ctrl.state, statusMessage: _ctrl.statusMessage),
            if (_ctrl.state == ChatLoadState.modelLoading)
              _LoadingBar(progress: _ctrl.loadProgress),
            Expanded(child: _MessageList(ctrl: _ctrl, scroll: _scroll)),
            _divider(),
            _InputRow(
              input: _input,
              focus: _inputFocus,
              ctrl: _ctrl,
              onSubmit: _submit,
              onKey: _handleKey,
              spinFrame: _spinFrames[_spinnerFrame],
              cursorVisible: _cursorVisible,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(height: 1, color: _kBorder);
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.statusMessage});

  final ChatLoadState state;
  final String statusMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _kBgAlt,
      child: Row(
        children: [
          _dot(_stateColor(state)),
          const SizedBox(width: 8),
          Text(
            'gemma-4 native-llm',
            style: _kMono.copyWith(color: _kWhite, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusMessage,
              style: _kMono.copyWith(color: _kMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Color _stateColor(ChatLoadState s) {
    return switch (s) {
      ChatLoadState.ready => _kGreen,
      ChatLoadState.generating => _kYellow,
      ChatLoadState.error => _kRed,
      _ => _kMuted,
    };
  }
}

// ── Loading bar ───────────────────────────────────────────────────────────────

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({this.progress});
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final pct = progress;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct != null ? pct / 100.0 : null,
              backgroundColor: _kBgAlt,
              valueColor: const AlwaysStoppedAnimation(_kGreen),
              minHeight: 3,
            ),
          ),
          if (pct != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${pct.toInt()}%',
                style: _kMono.copyWith(color: _kMuted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Message list ──────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({required this.ctrl, required this.scroll});
  final NativeLlmChatController ctrl;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final messages = ctrl.messages;
    final streaming = ctrl.streamingBuffer;
    final isGenerating = ctrl.state == ChatLoadState.generating;

    final itemCount = messages.length + (isGenerating ? 1 : 0);

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        if (i < messages.length) {
          return _MessageTile(msg: messages[i]);
        }
        // Streaming bubble.
        return _MessageTile(
          msg: ChatMessage(role: 'assistant', content: streaming),
          isStreaming: true,
        );
      },
    );
  }
}

// ── Message tile ──────────────────────────────────────────────────────────────

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.msg, this.isStreaming = false});
  final ChatMessage msg;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    return switch (msg.role) {
      'user' => _UserBubble(text: msg.content),
      'assistant' => _AssistantBubble(text: msg.content, streaming: isStreaming),
      _ => _SystemLine(text: msg.content),
    };
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('> ', style: _kMono.copyWith(color: _kGreen, fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: _kMono.copyWith(color: _kWhite),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text, this.streaming = false});
  final String text;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            streaming ? '~ ' : '  ',
            style: _kMono.copyWith(color: _kBlue, fontSize: 13),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: text.isEmpty && streaming ? ' ' : text,
                style: _kMono.copyWith(color: _kWhite),
                children: streaming
                    ? [
                        WidgetSpan(
                          child: _BlinkingCursor(),
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  bool _show = true;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 530), (_) {
      if (mounted) setState(() => _show = !_show);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 80),
      child: Text('▋', style: _kMono.copyWith(color: _kBlue, fontSize: 13)),
    );
  }
}

class _SystemLine extends StatelessWidget {
  const _SystemLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('# ', style: _kMono.copyWith(color: _kMuted, fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: _kMono.copyWith(color: _kMuted, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input row ─────────────────────────────────────────────────────────────────

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.input,
    required this.focus,
    required this.ctrl,
    required this.onSubmit,
    required this.onKey,
    required this.spinFrame,
    required this.cursorVisible,
  });

  final TextEditingController input;
  final FocusNode focus;
  final NativeLlmChatController ctrl;
  final VoidCallback onSubmit;
  final bool Function(KeyEvent) onKey;
  final String spinFrame;
  final bool cursorVisible;

  @override
  Widget build(BuildContext context) {
    final busy = ctrl.isBusy;

    return Container(
      color: _kBgAlt,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Prompt glyph or spinner
          SizedBox(
            width: 22,
            child: Text(
              busy ? spinFrame : '\$',
              style: _kMono.copyWith(
                color: busy ? _kYellow : _kGreen,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: onKey,
              child: TextField(
                controller: input,
                focusNode: focus,
                autofocus: true,
                enabled: !busy,
                style: _kMono.copyWith(color: _kWhite),
                cursorColor: _kGreen,
                cursorWidth: 2,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: busy ? ctrl.statusMessage : 'Message Gemma…',
                  hintStyle: _kMono.copyWith(color: _kMuted),
                ),
                onSubmitted: (_) => onSubmit(),
                textInputAction: TextInputAction.send,
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!busy)
            GestureDetector(
              onTap: onSubmit,
              child: Text(
                '↵',
                style: _kMono.copyWith(color: _kMuted, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }
}
