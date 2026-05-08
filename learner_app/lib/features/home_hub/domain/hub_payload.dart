import 'package:equatable/equatable.dart';

import '../../../hub/daily_topics_service.dart';

/// Hub carousel data once loading finishes (domain aggregate for this feature).
class HubPayload extends Equatable {
  const HubPayload(
    this.offers,
    this.done, {
    required this.questLevel,
    required this.questMaxTasks,
  });

  final List<HubTopicOffer> offers;
  final Set<String> done;
  final String questLevel;
  final int questMaxTasks;

  @override
  List<Object?> get props => [offers, done, questLevel, questMaxTasks];
}
