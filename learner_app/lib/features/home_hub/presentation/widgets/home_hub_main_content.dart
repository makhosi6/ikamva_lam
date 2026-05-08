import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../hub/daily_topics_service.dart';
import '../../../../theme/ikamva_colors.dart';
import '../../application/home_hub_bloc.dart';
import '../../application/home_hub_state.dart';
import '../hub_layout_constants.dart';
import 'home_hub_loaded_body.dart';
import 'home_hub_loading_body.dart';

bool homeHubMainBodyBuildWhen(HomeHubState previous, HomeHubState current) {
  if (previous.runtimeType != current.runtimeType) return true;
  if (previous is HomeHubReady && current is HomeHubReady) {
    return previous.payload != current.payload;
  }
  if (previous is HomeHubLoading && current is HomeHubLoading) {
    return previous.phase != current.phase;
  }
  return false;
}

/// Expanded region: loading, error, or loaded hub (carousel).
class HomeHubMainContent extends StatelessWidget {
  const HomeHubMainContent({
    super.key,
    required this.loadingDiagnosticsScroll,
    required this.hubPeekDiagnosticsScroll,
    required this.modelInitPercent,
    required this.theme,
    required this.ik,
    required this.onOpenTopic,
  });

  final ScrollController loadingDiagnosticsScroll;
  final ScrollController hubPeekDiagnosticsScroll;
  final int? modelInitPercent;
  final ThemeData theme;
  final IkamvaColors ik;
  final Future<void> Function(HubTopicOffer offer) onOpenTopic;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeHubBloc, HomeHubState>(
      buildWhen: homeHubMainBodyBuildWhen,
      builder: (context, state) {
        return switch (state) {
          HomeHubInitial() => HomeHubLoadingBody(
              scrollController: loadingDiagnosticsScroll,
              modelInitPercent: modelInitPercent,
              loadPhase: null,
            ),
          HomeHubLoading(:final phase) => HomeHubLoadingBody(
              scrollController: loadingDiagnosticsScroll,
              modelInitPercent: modelInitPercent,
              loadPhase: phase,
            ),
          HomeHubFailure(:final message) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: kHubTextGutter),
              child: Center(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          HomeHubReady(:final payload) => HomeHubLoadedBody(
              theme: theme,
              ik: ik,
              payload: payload,
              hubPeekDiagnosticsScroll: hubPeekDiagnosticsScroll,
              onOpenTopic: onOpenTopic,
            ),
        };
      },
    );
  }
}
