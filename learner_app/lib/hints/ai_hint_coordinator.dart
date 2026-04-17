import 'package:flutter/material.dart';

import '../audio/tts_service.dart';
import '../db/app_database.dart';
import '../llm/llm_generate_request.dart';
import '../llm/llm_service.dart';
import '../prompts/prompt_composer.dart';
import '../state/settings_scope.dart';
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
      LlmGenerateRequest(prompt: prompt),
    );
    final parsed = AiMultilingualHint.tryParse(raw);
    if (!context.mounted) return;
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load an AI hint right now. Try again later.'),
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
      await TtsService.instance.speak(parsed.hintEn);
    }
  }
}
