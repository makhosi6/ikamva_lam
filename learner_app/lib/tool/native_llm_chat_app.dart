import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_llm_chat_screen.dart';

/// Minimal Flutter shell for the terminal chat dev tool.
///
/// Launched with:
/// ```
///   flutter run -d DEVICE_ID --target=bin/native_llm_chat.dart
/// ```
class NativeLlmChatApp extends StatelessWidget {
  const NativeLlmChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma 4 Native Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF3FB950),
          secondary: const Color(0xFF79C0FF),
          surface: const Color(0xFF161B22),
          error: const Color(0xFFF85149),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF3FB950),
          selectionColor: Color(0xFF1F6FEB),
          selectionHandleColor: Color(0xFF3FB950),
        ),
        inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
      ),
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFF0D1117),
        ),
        child: const NativeLlmChatScreen(),
      ),
    );
  }
}
