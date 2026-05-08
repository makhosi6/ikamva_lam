import 'package:equatable/equatable.dart';

import '../domain/hub_payload.dart';

enum HomeHubLoadPhase {
  /// Bundled model copy / engine open (mobile only).
  modelWarm,

  /// Daily topics + DB reads (runs after model warm or alone on desktop).
  fetchingHub,
}

sealed class HomeHubState extends Equatable {
  const HomeHubState();

  @override
  List<Object?> get props => [];
}

final class HomeHubInitial extends HomeHubState {
  const HomeHubInitial();
}

final class HomeHubLoading extends HomeHubState {
  const HomeHubLoading({required this.phase});

  final HomeHubLoadPhase phase;

  bool get showTopicHeaders => phase == HomeHubLoadPhase.fetchingHub;

  @override
  List<Object?> get props => [phase];
}

final class HomeHubReady extends HomeHubState {
  const HomeHubReady(this.payload, {this.resumeBusy = false});

  final HubPayload payload;
  final bool resumeBusy;

  HomeHubReady copyWith({HubPayload? payload, bool? resumeBusy}) {
    return HomeHubReady(
      payload ?? this.payload,
      resumeBusy: resumeBusy ?? this.resumeBusy,
    );
  }

  @override
  List<Object?> get props => [payload, resumeBusy];
}

final class HomeHubFailure extends HomeHubState {
  const HomeHubFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
