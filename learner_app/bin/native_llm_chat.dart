// ignore_for_file: avoid_void_async
import 'package:flutter/widgets.dart';

import 'package:ikamva_lam/tool/native_llm_chat_app.dart';

/// Entry point for the terminal-style native LLM chat dev tool.
///
/// Run on a connected device or emulator:
/// ```
///   flutter run -d DEVICE_ID --target=bin/native_llm_chat.dart
/// ```
///
/// Run with CPU-only backend on Android (safer on unknown GPUs):
/// ```
///   flutter run -d DEVICE_ID --target=bin/native_llm_chat.dart
///       --dart-define=IKAMVA_FORCE_CPU_BACKEND=1
/// ```
///
/// Run with GPU backend opted in on Android:
/// ```
///   flutter run -d DEVICE_ID --target=bin/native_llm_chat.dart
///       --dart-define=IKAMVA_PREFER_ANDROID_GPU=true
/// ```
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NativeLlmChatApp());
}
