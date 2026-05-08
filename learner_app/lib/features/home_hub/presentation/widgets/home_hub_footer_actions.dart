import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../state/game_pause_store.dart';
import '../hub_layout_constants.dart';

/// Bottom-of-hub navigation: resume, summaries, teacher, dev link.
class HomeHubFooterActions extends StatelessWidget {
  const HomeHubFooterActions({
    super.key,
    required this.pauseFuture,
  });

  final Future<GamePauseSnapshot?> pauseFuture;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kHubTextGutter,
        8,
        kHubTextGutter,
        8,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kHubMaxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<GamePauseSnapshot?>(
                future: pauseFuture,
                builder: (context, snap) {
                  final pause = snap.data;
                  if (pause == null) return const SizedBox.shrink();
                  return OutlinedButton(
                    onPressed: () => context.push('/game?resume=1'),
                    child: const Text('Resume paused session'),
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/session-summary'),
                child: const Text('View sample session summary'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.push('/teacher'),
                child: const Text('Teacher/Parent mode'),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/dev/stats'),
                  child: const Text('Developer tools (dev)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
