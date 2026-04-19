import 'package:drift/drift.dart';

import '../domain/skill_id.dart';
import '../domain/task_source.dart';
import '../domain/task_type.dart';
import 'app_database.dart';

/// Stable dev IDs for UI work without AI (TASKS §2.8).
const String kSeedLearnerId = 'seed-learner-1';
const String kSeedQuestId = 'seed-quest-1';
const String kSeedTaskId = 'seed-task-cloze-1';
const String kSeedTaskId2 = 'seed-task-cloze-2';
const String kSeedTaskId3 = 'seed-task-cloze-3';
const String kSeedTaskD2a = 'seed-task-cloze-d2-a';
const String kSeedTaskD2b = 'seed-task-cloze-d2-b';
const String kSeedTaskD3 = 'seed-task-cloze-d3';
const String kSeedReorderId = 'seed-task-reorder-1';
const String kSeedMatchId = 'seed-task-match-1';
const String kSeedDialogueId = 'seed-task-dialogue-1';
const String kSeedReadAloudId = 'seed-task-read-aloud-1';
const String kSeedPronunciationId = 'seed-task-pronunciation-1';

/// Extra demo quests (each topic has a full exercise matrix in dev seed).
const String kSeedQuestSchoolId = 'seed-quest-school';
const String kSeedQuestFamilyId = 'seed-quest-family';
const String kSeedQuestTravelId = 'seed-quest-travel';
const String kSeedQuestWeatherId = 'seed-quest-weather';
const String kSeedQuestAnimalsId = 'seed-quest-animals';
const String kSeedQuestShoppingId = 'seed-quest-shopping';
const String kSeedQuestHealthId = 'seed-quest-health';
const String kSeedQuestSportsId = 'seed-quest-sports';
const String kSeedQuestMusicId = 'seed-quest-music';
const String kSeedQuestHomeId = 'seed-quest-home';
const String kSeedQuestFoodId = 'seed-quest-food';
const String kSeedQuestClothingId = 'seed-quest-clothing';
const String kSeedQuestTransportationId = 'seed-quest-transportation';
const String kSeedQuestAccommodationId = 'seed-quest-accommodation';
const String kSeedQuestEntertainmentId = 'seed-quest-entertainment';
const String kSeedQuestEducationId = 'seed-quest-education';

/// Template task ids used when cloning dev-seed rows onto another topic
/// ([TaskQueueService] fallback).
const List<String> kDevSeedFallbackTemplateTaskIds = [
  kSeedReorderId,
  kSeedMatchId,
  kSeedDialogueId,
  kSeedReadAloudId,
  kSeedPronunciationId,
  kSeedTaskId,
  kSeedTaskId2,
  kSeedTaskId3,
  kSeedTaskD2a,
  kSeedTaskD2b,
  kSeedTaskD3,
];

/// Sample cloze payloads: each stem is written so grammar, collocation, or a
/// fixed expression leaves only one plausible option (see validators + prompts).
const String kSeedClozePayloadJson = '{'
    '"sentence":"We always ___ our hands before we eat.",'
    '"answer":"wash",'
    '"options":["wash","washes","washed","washing"]'
    '}';

const String kSeedCloze2PayloadJson = '{'
    '"sentence":"On a long walk we drink ___ from our bottle.",'
    '"answer":"water",'
    '"options":["water","bread","sand","salt"]'
    '}';

const String kSeedCloze3PayloadJson = '{'
    '"sentence":"An ___ a day keeps the doctor away.",'
    '"answer":"apple",'
    '"options":["apple","orange","egg","pill"]'
    '}';

const String kSeedClozeD2aPayloadJson = '{'
    '"sentence":"Every Friday they ___ rice for dinner.",'
    '"answer":"cook",'
    '"options":["cook","cooks","cooking","cooked"]'
    '}';

const String kSeedClozeD2bPayloadJson = '{'
    '"sentence":"She ___ a red apple.",'
    '"answer":"has",'
    '"options":["has","have","having","had"]'
    '}';

const String kSeedClozeD3PayloadJson = '{'
    '"sentence":"You eat soup with a round ___ .",'
    '"answer":"spoon",'
    '"options":["spoon","knife","fork","plate"]'
    '}';

const String kSeedReorderPayloadJson =
    '{"tokens":["like","I","apples"],"correct_order":[1,0,2]}';

const String kSeedMatchPayloadJson = '{'
    '"left":["rice","bread","milk"],'
    '"right":["grain","slice","drink"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String kSeedDialoguePayloadJson = '{'
    '"context":"Sam is hungry at the table.",'
    '"question":"What should Sam say?",'
    '"options":[{"id":"a","text":"I want some food."},{"id":"b","text":"I want a hat."}],'
    '"correct_index":0'
    '}';

const String kSeedReadAloudPayloadJson = '{'
    '"display_text":"I would like some water, please.",'
    '"instruction_en":"Read it politely, like at the school lunch line."'
    '}';

const String kSeedPronunciationPayloadJson = r'''{"question":"Which line puts the strongest stress on the food word rice?","options":["I like some RICE.","I LIKE some rice.","I like SOME rice.","She likes some rice."],"correct_index":0,"reference_line":"I like some rice."}''';

// --- School topic -----------------------------------------------------------

const String _schoolClozeA = '{'
    '"sentence":"We eat our lunch at a small round ___ .",'
    '"answer":"table",'
    '"options":["table","floor","roof","path"]'
    '}';

const String _schoolClozeB = '{'
    '"sentence":"I open my ___ to read.",'
    '"answer":"book",'
    '"options":["book","box","cup","hat"]'
    '}';

const String _schoolClozeC = '{'
    '"sentence":"Our ___ writes new words on the board.",'
    '"answer":"teacher",'
    '"options":["teacher","desk","eraser","clock"]'
    '}';

const String _schoolReorder =
    '{"tokens":["class","I","like"],"correct_order":[1,0,2]}';

const String _schoolMatch = '{'
    '"left":["pen","ruler","bag"],'
    '"right":["write","measure","carry"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _schoolDialogue = '{'
    '"context":"The teacher gives you a new book.",'
    '"question":"What do you say?",'
    '"options":[{"id":"a","text":"Thank you."},{"id":"b","text":"Go away."}],'
    '"correct_index":0'
    '}';

const String _schoolRead = '{'
    '"display_text":"This is my school bag.",'
    '"instruction_en":"Say it clearly and slowly."'
    '}';

const String _schoolPronun = r'''{"question":"Which line stresses the word school?","options":["I walk to SCHOOL.","I WALK to school.","My bag is VERY heavy.","I walk to school slowly."],"correct_index":0,"reference_line":"I walk to school."}''';

// --- Family topic -----------------------------------------------------------

const String _familyClozeA = '{'
    '"sentence":"At seven pm we eat ___ at home.",'
    '"answer":"dinner",'
    '"options":["dinner","breakfast","lunch","math"]'
    '}';

const String _familyClozeB = '{'
    '"sentence":"My ___ cooks rice.",'
    '"answer":"mother",'
    '"options":["mother","shoe","tree","car"]'
    '}';

const String _familyClozeC = '{'
    '"sentence":"We ___ our family.",'
    '"answer":"love",'
    '"options":["love","kick","hide","sell"]'
    '}';

const String _familyReorder =
    '{"tokens":["home","I","like"],"correct_order":[1,0,2]}';

const String _familyMatch = '{'
    '"left":["mother","father","baby"],'
    '"right":["cooks","reads","sleeps"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _familyDialogue = '{'
    '"context":"Grandma gives you a warm hug.",'
    '"question":"What do you say?",'
    '"options":[{"id":"a","text":"Thank you, Grandma."},{"id":"b","text":"Stop it."}],'
    '"correct_index":0'
    '}';

const String _familyRead = '{'
    '"display_text":"My family is kind to me.",'
    '"instruction_en":"Read with a warm, friendly tone."'
    '}';

const String _familyPronun = r'''{"question":"Which line stresses the word family?","options":["I love my FAMILY.","I LOVE my family.","My phone is VERY new.","I love my family pet."],"correct_index":0,"reference_line":"I love my family."}''';

// --- Travel topic -----------------------------------------------------------

const String _travelClozeA = '{'
    '"sentence":"We ___ the bus to town.",'
    '"answer":"take",'
    '"options":["take","eat","draw","sing"]'
    '}';

const String _travelClozeB = '{'
    '"sentence":"I buy a ___ at the station.",'
    '"answer":"ticket",'
    '"options":["ticket","cloud","sock","stone"]'
    '}';

const String _travelClozeC = '{'
    '"sentence":"Our train is ten minutes ___ behind schedule today.",'
    '"answer":"late",'
    '"options":["late","noisy","new","full"]'
    '}';

const String _travelReorder =
    '{"tokens":["trip","a","nice"],"correct_order":[1,2,0]}';

const String _travelMatch = '{'
    '"left":["bus","train","map"],'
    '"right":["road","rails","paper"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _travelDialogue = '{'
    '"context":"You are at the bus stop with a friend.",'
    '"question":"The bus comes. What do you say?",'
    '"options":[{"id":"a","text":"Let us get on together."},{"id":"b","text":"Push me."}],'
    '"correct_index":0'
    '}';

const String _travelRead = '{'
    '"display_text":"Please wait in line for the bus.",'
    '"instruction_en":"Read like a polite sign at a stop."'
    '}';

const String _travelPronun = r'''{"question":"Which line stresses the word ticket?","options":["I need a TICKET.","I NEED a ticket.","The bus is FULL now.","I need a ticket please."],"correct_index":0,"reference_line":"I need a ticket."}''';

// --- Weather topic ----------------------------------------------------------

const String _weatherClozeA = '{'
    '"sentence":"Today is hot and ___ with no clouds at all.",'
    '"answer":"sunny",'
    '"options":["sunny","metal","quiet","empty"]'
    '}';

const String _weatherClozeB = '{'
    '"sentence":"We wear a ___ when it rains.",'
    '"answer":"coat",'
    '"options":["coat","spoon","bell","rope"]'
    '}';

const String _weatherClozeC = '{'
    '"sentence":"When it rains the sky is usually flat and ___ .",'
    '"answer":"grey",'
    '"options":["grey","square","metal","hungry"]'
    '}';

const String _weatherReorder =
    '{"tokens":["cold","it","is"],"correct_order":[2,1,0]}';

const String _weatherMatch = '{'
    '"left":["sun","rain","wind"],'
    '"right":["hot","wet","blow"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _weatherDialogue = '{'
    '"context":"Your friend forgot a hat on a cold day.",'
    '"question":"What do you say?",'
    '"options":[{"id":"a","text":"You can share my scarf."},{"id":"b","text":"I do not care."}],'
    '"correct_index":0'
    '}';

const String _weatherRead = '{'
    '"display_text":"It looks like rain this afternoon.",'
    '"instruction_en":"Read like a calm weather report."'
    '}';

const String _weatherPronun = r'''{"question":"Which line stresses the word rain?","options":["I hear RAIN.","I HEAR rain.","The wind is STRONG now.","I hear rain softly."],"correct_index":0,"reference_line":"I hear rain."}''';

// --- Animals ---------------------------------------------------------------

const String _animalsClozeA = '{'
    '"sentence":"The ___ says meow.",'
    '"answer":"cat",'
    '"options":["cat","dog","fish","tree"]'
    '}';

const String _animalsClozeB = '{'
    '"sentence":"A dog can ___ .",'
    '"answer":"bark",'
    '"options":["bark","read","drive","paint"]'
    '}';

const String _animalsClozeC = '{'
    '"sentence":"At the zoo we see many wild ___ .",'
    '"answer":"animals",'
    '"options":["animals","cars","chairs","phones"]'
    '}';

const String _animalsReorder =
    '{"tokens":["dog","my","likes"],"correct_order":[1,0,2]}';

const String _animalsMatch = '{'
    '"left":["cat","sheep","fish"],'
    '"right":["meow","baa","swim"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _animalsDialogue = '{'
    '"context":"You see a small hurt bird on the path.",'
    '"question":"What should you do?",'
    '"options":[{"id":"a","text":"Tell an adult to help."},{"id":"b","text":"Walk away fast."}],'
    '"correct_index":0'
    '}';

const String _animalsRead = '{'
    '"display_text":"Animals need food and water.",'
    '"instruction_en":"Read like a kind poster at a park."'
    '}';

const String _animalsPronun = r'''{"question":"Which line stresses the word zoo?","options":["We go to the ZOO.","WE go to the zoo.","The park is OPEN today.","We go to the zoo now."],"correct_index":0,"reference_line":"We go to the zoo."}''';

// --- Shopping --------------------------------------------------------------

const String _shoppingClozeA = '{'
    '"sentence":"We pay at the ___ .",'
    '"answer":"till",'
    '"options":["till","roof","moon","lake"]'
    '}';

const String _shoppingClozeB = '{'
    '"sentence":"This shoe ___ is too big for my foot.",'
    '"answer":"size",'
    '"options":["size","sky","week","cloud"]'
    '}';

const String _shoppingClozeC = '{'
    '"sentence":"I carry a small ___ .",'
    '"answer":"bag",'
    '"options":["bag","hill","star","stone"]'
    '}';

const String _shoppingReorder =
    '{"tokens":["milk","I","buy"],"correct_order":[1,2,0]}';

const String _shoppingMatch = '{'
    '"left":["shop","coin","basket"],'
    '"right":["store","money","carry"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _shoppingDialogue = '{'
    '"context":"You bump into a friend and spill milk in the shop.",'
    '"question":"What do you say first?",'
    '"options":[{"id":"a","text":"Sorry about that."},{"id":"b","text":"It is your fault."}],'
    '"correct_index":0'
    '}';

const String _shoppingRead = '{'
    '"display_text":"How much is this apple, please?",'
    '"instruction_en":"Read like a polite shopper."'
    '}';

const String _shoppingPronun = r'''{"question":"Which line stresses the word cheap?","options":["This feels CHEAP.","THIS feels cheap.","The shop is CLOSED now.","This feels cheap today."],"correct_index":0,"reference_line":"This feels cheap."}''';

// --- Health ----------------------------------------------------------------

const String _healthClozeA = '{'
    '"sentence":"Wash your ___ before food.",'
    '"answer":"hands",'
    '"options":["hands","shoes","hat","coat"]'
    '}';

const String _healthClozeB = '{'
    '"sentence":"Drink more ___ .",'
    '"answer":"water",'
    '"options":["water","sand","paint","oil"]'
    '}';

const String _healthClozeC = '{'
    '"sentence":"Sleep helps your ___ .",'
    '"answer":"body",'
    '"options":["body","car","desk","shoe"]'
    '}';

const String _healthReorder =
    '{"tokens":["tired","feel","I"],"correct_order":[2,1,0]}';

const String _healthMatch = '{'
    '"left":["tooth","soap","rest"],'
    '"right":["brush","wash","sleep"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _healthDialogue = '{'
    '"context":"Your friend looks very tired at school.",'
    '"question":"What is a kind thing to say?",'
    '"options":[{"id":"a","text":"You should rest a little."},{"id":"b","text":"Go away."}],'
    '"correct_index":0'
    '}';

const String _healthRead = '{'
    '"display_text":"Brush your teeth twice a day.",'
    '"instruction_en":"Read like a short health tip."'
    '}';

const String _healthPronun = r'''{"question":"Which line stresses the word healthy?","options":["Eat HEALTHY food.","EAT healthy food.","Dinner smells GOOD today.","Eat healthy food slowly."],"correct_index":0,"reference_line":"Eat healthy food."}''';

// --- Sports ----------------------------------------------------------------

const String _sportsClozeA = '{'
    '"sentence":"We pass the ___ in football.",'
    '"answer":"ball",'
    '"options":["ball","book","spoon","key"]'
    '}';

const String _sportsClozeB = '{'
    '"sentence":"She can ___ very fast.",'
    '"answer":"run",'
    '"options":["run","hide","sleep","read"]'
    '}';

const String _sportsClozeC = '{'
    '"sentence":"They play in a ___ .",'
    '"answer":"team",'
    '"options":["team","boat","cake","cloud"]'
    '}';

const String _sportsReorder =
    '{"tokens":["team","our","won"],"correct_order":[1,0,2]}';

const String _sportsMatch = '{'
    '"left":["run","swim","jump"],'
    '"right":["fast","water","high"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _sportsDialogue = '{'
    '"context":"Your team lost a small match at school.",'
    '"question":"What is a good sport thing to say?",'
    '"options":[{"id":"a","text":"Good game, well played."},{"id":"b","text":"I hate you all."}],'
    '"correct_index":0'
    '}';

const String _sportsRead = '{'
    '"display_text":"Play fairly and have fun.",'
    '"instruction_en":"Read like a friendly coach."'
    '}';

const String _sportsPronun = r'''{"question":"Which line stresses the word win?","options":["We want to WIN.","WE want to win.","The game is LONG today.","We want to win soon."],"correct_index":0,"reference_line":"We want to win."}''';

// --- Music -----------------------------------------------------------------

const String _musicClozeA = '{'
    '"sentence":"We sing a ___ .",'
    '"answer":"song",'
    '"options":["song","road","chair","cloud"]'
    '}';

const String _musicClozeB = '{'
    '"sentence":"A flute sounds ___ than a big drum.",'
    '"answer":"higher",'
    '"options":["higher","slower","older","shorter"]'
    '}';

const String _musicClozeC = '{'
    '"sentence":"She plays the ___ with black and white keys.",'
    '"answer":"piano",'
    '"options":["piano","table","grass","wall"]'
    '}';

const String _musicReorder =
    '{"tokens":["music","I","like"],"correct_order":[1,0,2]}';

const String _musicMatch = '{'
    '"left":["drum","guitar","song"],'
    '"right":["sound","strings","words"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _musicDialogue = '{'
    '"context":"Music is very loud in the classroom.",'
    '"question":"What do you say politely?",'
    '"options":[{"id":"a","text":"Please turn it down a little."},{"id":"b","text":"Shut it off now."}],'
    '"correct_index":0'
    '}';

const String _musicRead = '{'
    '"display_text":"Music can make us happy.",'
    '"instruction_en":"Read with a warm smile."'
    '}';

const String _musicPronun = r'''{"question":"Which line stresses the word song?","options":["I love this SONG.","I LOVE this song.","The band is LOUD tonight.","I love this song today."],"correct_index":0,"reference_line":"I love this song."}''';

// --- Home ------------------------------------------------------------------

const String _homeClozeA = '{'
    '"sentence":"We cook in the ___ .",'
    '"answer":"kitchen",'
    '"options":["kitchen","street","sky","lake"]'
    '}';

const String _homeClozeB = '{'
    '"sentence":"My bed is in the ___ .",'
    '"answer":"bedroom",'
    '"options":["bedroom","garden","road","shop"]'
    '}';

const String _homeClozeC = '{'
    '"sentence":"Turn off the ___ at night.",'
    '"answer":"light",'
    '"options":["light","bird","cat","cloud"]'
    '}';

const String _homeReorder =
    '{"tokens":["home","safe","is"],"correct_order":[2,0,1]}';

const String _homeMatch = '{'
    '"left":["door","key","lamp"],'
    '"right":["open","lock","light"],'
    '"pairs":[[0,0],[1,1],[2,2]]'
    '}';

const String _homeDialogue = '{'
    '"context":"You forgot your house key.",'
    '"question":"What do you ask a trusted neighbor?",'
    '"options":[{"id":"a","text":"Could you help me call home?"},{"id":"b","text":"Break my window."}],'
    '"correct_index":0'
    '}';

const String _homeRead = '{'
    '"display_text":"Please close the door quietly.",'
    '"instruction_en":"Read like a polite note on a door."'
    '}';

const String _homePronun = r'''{"question":"Which line stresses the word home?","options":["I walk HOME now.","I WALK home now.","The street is DARK tonight.","I walk home now slowly."],"correct_index":0,"reference_line":"I walk home now."}''';

class _MultiTopicSpec {
  const _MultiTopicSpec({
    required this.topic,
    required this.questId,
    required this.reorderId,
    required this.matchId,
    required this.dialogueId,
    required this.readId,
    required this.pronunId,
    required this.clozeAId,
    required this.clozeBId,
    required this.clozeCId,
    required this.reorderJson,
    required this.matchJson,
    required this.dialogueJson,
    required this.readJson,
    required this.pronunJson,
    required this.clozeAJson,
    required this.clozeBJson,
    required this.clozeCJson,
    required this.baseSeconds,
  });

  final String topic;
  final String questId;
  final String reorderId;
  final String matchId;
  final String dialogueId;
  final String readId;
  final String pronunId;
  final String clozeAId;
  final String clozeBId;
  final String clozeCId;
  final String reorderJson;
  final String matchJson;
  final String dialogueJson;
  final String readJson;
  final String pronunJson;
  final String clozeAJson;
  final String clozeBJson;
  final String clozeCJson;
  final int baseSeconds;
}

const List<_MultiTopicSpec> _kMultiTopicSpecs = [
  _MultiTopicSpec(
    topic: 'school',
    questId: kSeedQuestSchoolId,
    reorderId: 'seed-school-reorder',
    matchId: 'seed-school-match',
    dialogueId: 'seed-school-dialogue',
    readId: 'seed-school-read',
    pronunId: 'seed-school-pronun',
    clozeAId: 'seed-school-cloze-a',
    clozeBId: 'seed-school-cloze-b',
    clozeCId: 'seed-school-cloze-c',
    reorderJson: _schoolReorder,
    matchJson: _schoolMatch,
    dialogueJson: _schoolDialogue,
    readJson: _schoolRead,
    pronunJson: _schoolPronun,
    clozeAJson: _schoolClozeA,
    clozeBJson: _schoolClozeB,
    clozeCJson: _schoolClozeC,
    baseSeconds: 1,
  ),
  _MultiTopicSpec(
    topic: 'family',
    questId: kSeedQuestFamilyId,
    reorderId: 'seed-family-reorder',
    matchId: 'seed-family-match',
    dialogueId: 'seed-family-dialogue',
    readId: 'seed-family-read',
    pronunId: 'seed-family-pronun',
    clozeAId: 'seed-family-cloze-a',
    clozeBId: 'seed-family-cloze-b',
    clozeCId: 'seed-family-cloze-c',
    reorderJson: _familyReorder,
    matchJson: _familyMatch,
    dialogueJson: _familyDialogue,
    readJson: _familyRead,
    pronunJson: _familyPronun,
    clozeAJson: _familyClozeA,
    clozeBJson: _familyClozeB,
    clozeCJson: _familyClozeC,
    baseSeconds: 2,
  ),
  _MultiTopicSpec(
    topic: 'travel',
    questId: kSeedQuestTravelId,
    reorderId: 'seed-travel-reorder',
    matchId: 'seed-travel-match',
    dialogueId: 'seed-travel-dialogue',
    readId: 'seed-travel-read',
    pronunId: 'seed-travel-pronun',
    clozeAId: 'seed-travel-cloze-a',
    clozeBId: 'seed-travel-cloze-b',
    clozeCId: 'seed-travel-cloze-c',
    reorderJson: _travelReorder,
    matchJson: _travelMatch,
    dialogueJson: _travelDialogue,
    readJson: _travelRead,
    pronunJson: _travelPronun,
    clozeAJson: _travelClozeA,
    clozeBJson: _travelClozeB,
    clozeCJson: _travelClozeC,
    baseSeconds: 3,
  ),
  _MultiTopicSpec(
    topic: 'weather',
    questId: kSeedQuestWeatherId,
    reorderId: 'seed-weather-reorder',
    matchId: 'seed-weather-match',
    dialogueId: 'seed-weather-dialogue',
    readId: 'seed-weather-read',
    pronunId: 'seed-weather-pronun',
    clozeAId: 'seed-weather-cloze-a',
    clozeBId: 'seed-weather-cloze-b',
    clozeCId: 'seed-weather-cloze-c',
    reorderJson: _weatherReorder,
    matchJson: _weatherMatch,
    dialogueJson: _weatherDialogue,
    readJson: _weatherRead,
    pronunJson: _weatherPronun,
    clozeAJson: _weatherClozeA,
    clozeBJson: _weatherClozeB,
    clozeCJson: _weatherClozeC,
    baseSeconds: 4,
  ),
  _MultiTopicSpec(
    topic: 'animals',
    questId: kSeedQuestAnimalsId,
    reorderId: 'seed-animals-reorder',
    matchId: 'seed-animals-match',
    dialogueId: 'seed-animals-dialogue',
    readId: 'seed-animals-read',
    pronunId: 'seed-animals-pronun',
    clozeAId: 'seed-animals-cloze-a',
    clozeBId: 'seed-animals-cloze-b',
    clozeCId: 'seed-animals-cloze-c',
    reorderJson: _animalsReorder,
    matchJson: _animalsMatch,
    dialogueJson: _animalsDialogue,
    readJson: _animalsRead,
    pronunJson: _animalsPronun,
    clozeAJson: _animalsClozeA,
    clozeBJson: _animalsClozeB,
    clozeCJson: _animalsClozeC,
    baseSeconds: 5,
  ),
  _MultiTopicSpec(
    topic: 'shopping',
    questId: kSeedQuestShoppingId,
    reorderId: 'seed-shopping-reorder',
    matchId: 'seed-shopping-match',
    dialogueId: 'seed-shopping-dialogue',
    readId: 'seed-shopping-read',
    pronunId: 'seed-shopping-pronun',
    clozeAId: 'seed-shopping-cloze-a',
    clozeBId: 'seed-shopping-cloze-b',
    clozeCId: 'seed-shopping-cloze-c',
    reorderJson: _shoppingReorder,
    matchJson: _shoppingMatch,
    dialogueJson: _shoppingDialogue,
    readJson: _shoppingRead,
    pronunJson: _shoppingPronun,
    clozeAJson: _shoppingClozeA,
    clozeBJson: _shoppingClozeB,
    clozeCJson: _shoppingClozeC,
    baseSeconds: 6,
  ),
  _MultiTopicSpec(
    topic: 'health',
    questId: kSeedQuestHealthId,
    reorderId: 'seed-health-reorder',
    matchId: 'seed-health-match',
    dialogueId: 'seed-health-dialogue',
    readId: 'seed-health-read',
    pronunId: 'seed-health-pronun',
    clozeAId: 'seed-health-cloze-a',
    clozeBId: 'seed-health-cloze-b',
    clozeCId: 'seed-health-cloze-c',
    reorderJson: _healthReorder,
    matchJson: _healthMatch,
    dialogueJson: _healthDialogue,
    readJson: _healthRead,
    pronunJson: _healthPronun,
    clozeAJson: _healthClozeA,
    clozeBJson: _healthClozeB,
    clozeCJson: _healthClozeC,
    baseSeconds: 7,
  ),
  _MultiTopicSpec(
    topic: 'sports',
    questId: kSeedQuestSportsId,
    reorderId: 'seed-sports-reorder',
    matchId: 'seed-sports-match',
    dialogueId: 'seed-sports-dialogue',
    readId: 'seed-sports-read',
    pronunId: 'seed-sports-pronun',
    clozeAId: 'seed-sports-cloze-a',
    clozeBId: 'seed-sports-cloze-b',
    clozeCId: 'seed-sports-cloze-c',
    reorderJson: _sportsReorder,
    matchJson: _sportsMatch,
    dialogueJson: _sportsDialogue,
    readJson: _sportsRead,
    pronunJson: _sportsPronun,
    clozeAJson: _sportsClozeA,
    clozeBJson: _sportsClozeB,
    clozeCJson: _sportsClozeC,
    baseSeconds: 8,
  ),
  _MultiTopicSpec(
    topic: 'music',
    questId: kSeedQuestMusicId,
    reorderId: 'seed-music-reorder',
    matchId: 'seed-music-match',
    dialogueId: 'seed-music-dialogue',
    readId: 'seed-music-read',
    pronunId: 'seed-music-pronun',
    clozeAId: 'seed-music-cloze-a',
    clozeBId: 'seed-music-cloze-b',
    clozeCId: 'seed-music-cloze-c',
    reorderJson: _musicReorder,
    matchJson: _musicMatch,
    dialogueJson: _musicDialogue,
    readJson: _musicRead,
    pronunJson: _musicPronun,
    clozeAJson: _musicClozeA,
    clozeBJson: _musicClozeB,
    clozeCJson: _musicClozeC,
    baseSeconds: 9,
  ),
  _MultiTopicSpec(
    topic: 'home',
    questId: kSeedQuestHomeId,
    reorderId: 'seed-home-reorder',
    matchId: 'seed-home-match',
    dialogueId: 'seed-home-dialogue',
    readId: 'seed-home-read',
    pronunId: 'seed-home-pronun',
    clozeAId: 'seed-home-cloze-a',
    clozeBId: 'seed-home-cloze-b',
    clozeCId: 'seed-home-cloze-c',
    reorderJson: _homeReorder,
    matchJson: _homeMatch,
    dialogueJson: _homeDialogue,
    readJson: _homeRead,
    pronunJson: _homePronun,
    clozeAJson: _homeClozeA,
    clozeBJson: _homeClozeB,
    clozeCJson: _homeClozeC,
    baseSeconds: 10,
  ),
];

void _insertTopicExerciseMatrix(
  Batch b,
  IkamvaDatabase db, {
  required String topic,
  required String questId,
  required DateTime questStart,
  required DateTime questEnd,
  required String reorderId,
  required String matchId,
  required String dialogueId,
  required String readId,
  required String pronunId,
  required String clozeAId,
  required String clozeBId,
  required String clozeCId,
  required String reorderJson,
  required String matchJson,
  required String dialogueJson,
  required String readJson,
  required String pronunJson,
  required String clozeAJson,
  required String clozeBJson,
  required String clozeCJson,
  required DateTime base,
}) {
  b.insert(
    db.quests,
    QuestsCompanion.insert(
      id: questId,
      topic: topic,
      level: 'A1',
      maxDifficultyStep: 3,
      sessionTimeLimitSec: const Value.absent(),
      maxTasks: const Value(16),
      startsAt: questStart,
      endsAt: questEnd,
      isActive: const Value(true),
    ),
  );
  var ms = 0;
  void task(
    String id,
    String type,
    String skill,
    int diff,
    String json,
  ) {
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: id,
        taskType: type,
        skillId: skill,
        difficulty: diff,
        topic: topic,
        payloadJson: json,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: base.add(Duration(milliseconds: ms++)),
      ),
    );
  }

  task(
    reorderId,
    TaskType.reorder.storageValue,
    SkillId.sentenceStructure.storageValue,
    1,
    reorderJson,
  );
  task(
    matchId,
    TaskType.match.storageValue,
    SkillId.vocabulary.storageValue,
    1,
    matchJson,
  );
  task(
    dialogueId,
    TaskType.dialogueChoice.storageValue,
    SkillId.vocabulary.storageValue,
    1,
    dialogueJson,
  );
  task(
    readId,
    TaskType.readAloud.storageValue,
    SkillId.readAloud.storageValue,
    1,
    readJson,
  );
  task(
    pronunId,
    TaskType.pronunciationIntonation.storageValue,
    SkillId.pronunciationIntonation.storageValue,
    1,
    pronunJson,
  );
  task(
    clozeAId,
    TaskType.cloze.storageValue,
    SkillId.vocabulary.storageValue,
    1,
    clozeAJson,
  );
  task(
    clozeBId,
    TaskType.cloze.storageValue,
    SkillId.vocabulary.storageValue,
    1,
    clozeBJson,
  );
  task(
    clozeCId,
    TaskType.cloze.storageValue,
    SkillId.vocabulary.storageValue,
    2,
    clozeCJson,
  );
}

/// Inserts seed profile, quest, and a **full A1 exercise matrix** per topic
/// when the DB has no learners (TASKS §2.8, mixed task types for demos).
Future<void> ensureDevSeed(IkamvaDatabase db) async {
  final count = await db.select(db.learnerProfiles).get();
  if (count.isNotEmpty) return;

  final now = DateTime.now().toUtc();
  final questEnd = now.add(const Duration(days: 30));

  await db.batch((b) {
    b.insert(
      db.learnerProfiles,
      LearnerProfilesCompanion.insert(
        id: kSeedLearnerId,
        displayName: 'Demo learner',
        homeLanguageCode: const Value('xh'),
        pairedTeacherCode: const Value('TEACH-DEMO'),
        createdAt: now,
      ),
    );
    b.insert(
      db.quests,
      QuestsCompanion.insert(
        id: kSeedQuestId,
        topic: 'food',
        level: 'A1',
        maxDifficultyStep: 3,
        sessionTimeLimitSec: const Value.absent(),
        maxTasks: const Value(24),
        startsAt: now,
        endsAt: questEnd,
        isActive: const Value(true),
      ),
    );

    var ms = 0;
    void foodTask(
      String id,
      String type,
      String skill,
      int diff,
      String json,
    ) {
      b.insert(
        db.taskRecords,
        TaskRecordsCompanion.insert(
          id: id,
          taskType: type,
          skillId: skill,
          difficulty: diff,
          topic: 'food',
          payloadJson: json,
          source: TaskSource.devSeedOnly.storageValue,
          createdAt: now.add(Duration(milliseconds: ms++)),
        ),
      );
    }

    // Non-cloze first so a capped session still includes every task type.
    foodTask(
      kSeedReorderId,
      TaskType.reorder.storageValue,
      SkillId.sentenceStructure.storageValue,
      1,
      kSeedReorderPayloadJson,
    );
    foodTask(
      kSeedMatchId,
      TaskType.match.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedMatchPayloadJson,
    );
    foodTask(
      kSeedDialogueId,
      TaskType.dialogueChoice.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedDialoguePayloadJson,
    );
    foodTask(
      kSeedReadAloudId,
      TaskType.readAloud.storageValue,
      SkillId.readAloud.storageValue,
      1,
      kSeedReadAloudPayloadJson,
    );
    foodTask(
      kSeedPronunciationId,
      TaskType.pronunciationIntonation.storageValue,
      SkillId.pronunciationIntonation.storageValue,
      1,
      kSeedPronunciationPayloadJson,
    );
    foodTask(
      kSeedTaskId,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedClozePayloadJson,
    );
    foodTask(
      kSeedTaskId2,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedCloze2PayloadJson,
    );
    foodTask(
      kSeedTaskId3,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      1,
      kSeedCloze3PayloadJson,
    );
    foodTask(
      kSeedTaskD2a,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      2,
      kSeedClozeD2aPayloadJson,
    );
    foodTask(
      kSeedTaskD2b,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      2,
      kSeedClozeD2bPayloadJson,
    );
    foodTask(
      kSeedTaskD3,
      TaskType.cloze.storageValue,
      SkillId.vocabulary.storageValue,
      3,
      kSeedClozeD3PayloadJson,
    );
  });
}

/// Adds non-cloze demo tasks for **legacy** DBs created before mixed-type
/// [ensureDevSeed] (TASKS §10.x).
Future<void> ensureExtraSeedTaskTypes(IkamvaDatabase db) async {
  final existing = await (db.select(db.taskRecords)
        ..where((t) => t.id.equals(kSeedReorderId)))
      .getSingleOrNull();
  if (existing != null) return;
  final now = DateTime.now().toUtc();
  await db.batch((b) {
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedReorderId,
        taskType: TaskType.reorder.storageValue,
        skillId: SkillId.sentenceStructure.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedReorderPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now,
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedMatchId,
        taskType: TaskType.match.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedMatchPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 1)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedDialogueId,
        taskType: TaskType.dialogueChoice.storageValue,
        skillId: SkillId.vocabulary.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedDialoguePayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 2)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedReadAloudId,
        taskType: TaskType.readAloud.storageValue,
        skillId: SkillId.readAloud.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedReadAloudPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 3)),
      ),
    );
    b.insert(
      db.taskRecords,
      TaskRecordsCompanion.insert(
        id: kSeedPronunciationId,
        taskType: TaskType.pronunciationIntonation.storageValue,
        skillId: SkillId.pronunciationIntonation.storageValue,
        difficulty: 1,
        topic: 'food',
        payloadJson: kSeedPronunciationPayloadJson,
        source: TaskSource.devSeedOnly.storageValue,
        createdAt: now.add(const Duration(milliseconds: 4)),
      ),
    );
  });
}

/// Idempotent: extra **topics + quests** (≥10 besides the main food seed),
/// each with all six task kinds. Inserts only rows whose [Quest] id is absent.
Future<void> ensureMultiTopicQuestSeed(IkamvaDatabase db) async {
  final missing = <_MultiTopicSpec>[];
  for (final spec in _kMultiTopicSpecs) {
    final hit = await (db.select(db.quests)
          ..where((q) => q.id.equals(spec.questId)))
        .getSingleOrNull();
    if (hit == null) missing.add(spec);
  }
  if (missing.isEmpty) return;

  final now = DateTime.now().toUtc();
  final questEnd = now.add(const Duration(days: 30));

  await db.batch((b) {
    for (final spec in missing) {
      _insertTopicExerciseMatrix(
        b,
        db,
        topic: spec.topic,
        questId: spec.questId,
        questStart: now,
        questEnd: questEnd,
        reorderId: spec.reorderId,
        matchId: spec.matchId,
        dialogueId: spec.dialogueId,
        readId: spec.readId,
        pronunId: spec.pronunId,
        clozeAId: spec.clozeAId,
        clozeBId: spec.clozeBId,
        clozeCId: spec.clozeCId,
        reorderJson: spec.reorderJson,
        matchJson: spec.matchJson,
        dialogueJson: spec.dialogueJson,
        readJson: spec.readJson,
        pronunJson: spec.pronunJson,
        clozeAJson: spec.clozeAJson,
        clozeBJson: spec.clozeBJson,
        clozeCJson: spec.clozeCJson,
        base: now.add(Duration(seconds: spec.baseSeconds)),
      );
    }
  });
}
