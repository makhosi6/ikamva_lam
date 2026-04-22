import 'package:flutter/material.dart';

import '../audio/tts_service.dart';
import '../db/app_database.dart';
import '../llm/llm_generate_request.dart';
import '../llm/llm_service.dart';
import '../prompts/prompt_composer.dart';
import '../state/settings_scope.dart';
import '../safety/child_friendly_content_gate.dart';
import '../widgets/multilingual_hint_sheet.dart';
import 'ai_multilingual_hint.dart';

/// Fetches and presents structured multilingual hints (TASKS §9.2).
class AiHintCoordinator {
  AiHintCoordinator._();

  static Future<void> showForWrongAnswer(
    BuildContext context, {
    required TaskRecord task,
    required String wrongAnswerJson,
  }) async {
    final taskJson = task.payloadJson;
    final prompt = await PromptComposer().composeHintPrompt(
      taskJson: taskJson,
      wrongAnswer: wrongAnswerJson,
    );
    final raw = await LlmService.instance.generate(
      LlmGenerateRequest(prompt: ModelBoundPrompt(prompt)),
    );
    final parsed = AiMultilingualHint.tryParse(raw.text);
    if (!context.mounted) return;
    if (parsed != null) {
      final gate = await ChildFriendlyContentGate.evaluateJsonValue({
        'hint_en': parsed.hintEn,
        if (parsed.hintXh != null) 'hint_xh': parsed.hintXh,
        if (parsed.hintZu != null) 'hint_zu': parsed.hintZu,
        if (parsed.hintAf != null) 'hint_af': parsed.hintAf,
      });
      if (!context.mounted) return;
      if (!gate.ok) {
        final bottom = MediaQuery.paddingOf(context).bottom + 76;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
            content: const Text(
              'That hint did not pass safety checks. Try again later.',
            ),
          ),
        );
        return;
      }
    }
    if (parsed == null) {
      final bottom = MediaQuery.paddingOf(context).bottom + 76;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
          content: const Text(
            'Could not load an AI hint right now. Try again later.',
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => MultilingualHintSheet(hint: parsed),
    );
    if (!context.mounted) return;
    final settings = SettingsScope.of(context);
    if (settings.ttsEnabled) {
      await TtsService.instance.speak(parsed.hintEn.replaceAll('___', ' blank '));
    }
  }
}
