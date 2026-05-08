import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/home_hub_bloc.dart';
import '../../application/home_hub_state.dart';
import '../hub_layout_constants.dart';

/// “Today’s topics” intro — only when headers should be visible for the current bloc state.
class HomeHubTopicHeaders extends StatelessWidget {
  const HomeHubTopicHeaders({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocSelector<HomeHubBloc, HomeHubState, bool>(
      selector: (s) => switch (s) {
        HomeHubLoading(:final showTopicHeaders) => showTopicHeaders,
        HomeHubReady() => true,
        _ => false,
      },
      builder: (context, showHeaders) {
        if (!showHeaders) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            kHubTextGutter,
            8,
            kHubTextGutter,
            0,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kHubMaxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Today's topics",
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Swipe sideways for more themes. Fresh picks each day.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.82,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Resets after midnight (your device time).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
