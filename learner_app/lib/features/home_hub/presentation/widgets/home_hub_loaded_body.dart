import 'package:flutter/material.dart';

import '../../../../hub/daily_topics_service.dart';
import '../../../../llm/flutter_gemma_llm_engine.dart';
import '../../../../theme/ikamva_colors.dart';
import '../../domain/hub_payload.dart';
import '../hub_layout_constants.dart';
import 'hub_diagnostics_peek.dart';
import 'hub_topic_carousel.dart';

class HomeHubLoadedBody extends StatelessWidget {
  const HomeHubLoadedBody({
    super.key,
    required this.theme,
    required this.ik,
    required this.payload,
    required this.hubPeekDiagnosticsScroll,
    required this.onOpenTopic,
  });

  final ThemeData theme;
  final IkamvaColors ik;
  final HubPayload payload;
  final ScrollController hubPeekDiagnosticsScroll;
  final Future<void> Function(HubTopicOffer offer) onOpenTopic;

  @override
  Widget build(BuildContext context) {
    final offers = payload.offers;
    final done = payload.done;

    if (offers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: kHubTextGutter),
        child: Center(
          child: Text(
            'Daily topics are generated on this device. When the '
            'learning model is ready, fresh child-safe themes '
            'will appear here. Try again in a moment, or check Settings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }

    final practised = offers.where((o) => done.contains(o.topic)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$practised of ${offers.length} topics practised today',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (shouldUseFlutterGemmaEngine)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 6, right: 6),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.18),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timeline_outlined,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'On-device model diagnostics',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Same live log as Developer → Event Log: '
                      'install, open, inference, and hub steps.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                      child: HubDiagnosticsPeek(
                        theme: theme,
                        height: kHubDiagnosticsPeekHeight,
                        scrollController: hubPeekDiagnosticsScroll,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kHubMaxContentWidth),
              child: HubTopicCarousel(
                theme: theme,
                ik: ik,
                payload: payload,
                onOpenTopic: onOpenTopic,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
