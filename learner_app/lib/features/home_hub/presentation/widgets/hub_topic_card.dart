import 'package:flutter/material.dart';

import '../../../../hub/daily_topics_service.dart';
import '../../../../theme/ikamva_colors.dart';

class HubTopicCard extends StatelessWidget {
  const HubTopicCard({
    super.key,
    required this.theme,
    required this.ik,
    required this.offer,
    required this.doneToday,
    required this.questLevel,
    required this.questMaxTasks,
    required this.onStart,
  });

  final ThemeData theme;
  final IkamvaColors ik;
  final HubTopicOffer offer;
  final bool doneToday;
  final String questLevel;
  final int questMaxTasks;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: doneToday
              ? ik.success.withValues(alpha: 0.65)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: doneToday ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ik.accentSun.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      offer.label,
                                      style: theme.textTheme.labelLarge,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (doneToday)
                                      Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: ik.success,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(questLevel, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'About $questMaxTasks questions / games.(est 10min playtime)',
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: onStart,
                          child: const Text('Start'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
