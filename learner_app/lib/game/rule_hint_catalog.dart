import '../domain/skill_id.dart';

/// Light rule hints before any model call (TASKS §9.1).
String ruleHintForFirstWrong(String skillId) {
  final id = SkillId.tryParse(skillId);
  if (id == null) {
    return 'Read slowly and match the sentence meaning.';
  }
  switch (id) {
    case SkillId.grammarTense:
      return 'Look at the verb: does the time (past / now / future) match the sentence?';
    case SkillId.grammarPlural:
      return 'Count the subject: one thing or more than one?';
    case SkillId.grammarArticles:
      return 'Think about a / an / the before the noun.';
    case SkillId.sentenceStructure:
      return 'Read the words in order like a short story.';
    case SkillId.vocabulary:
      return 'Which word fits the meaning of the sentence best?';
    case SkillId.readingFluency:
      return 'Read in short chunks and keep your eyes moving along the line.';
    case SkillId.pronunciationIntonation:
      return 'Listen for stress and tune — which option fits best?';
    case SkillId.readAloud:
      return 'Say it clearly, matching the calm example you heard.';
  }
}
