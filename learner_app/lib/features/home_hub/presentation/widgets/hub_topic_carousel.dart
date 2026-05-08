import 'package:flutter/material.dart';

import '../../../../hub/daily_topics_service.dart';
import '../../../../theme/ikamva_colors.dart';
import '../../domain/hub_payload.dart';
import '../hub_layout_constants.dart';
import 'hub_carousel_chevron.dart';
import 'hub_page_dots.dart';
import 'hub_topic_card.dart';

class HubTopicCarousel extends StatefulWidget {
  const HubTopicCarousel({
    super.key,
    required this.theme,
    required this.ik,
    required this.payload,
    required this.onOpenTopic,
  });

  final ThemeData theme;
  final IkamvaColors ik;
  final HubPayload payload;
  final Future<void> Function(HubTopicOffer offer) onOpenTopic;

  @override
  State<HubTopicCarousel> createState() => _HubTopicCarouselState();
}

class _HubTopicCarouselState extends State<HubTopicCarousel> {
  late PageController _pageController = PageController(viewportFraction: 1);
  int _pageIndex = 0;
  int _carouselTopicsPerPage = 2;
  bool _carouselSyncScheduled = false;

  @override
  void didUpdateWidget(covariant HubTopicCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload != widget.payload) {
      _pageIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static int _pageCount(int offerCount, int topicsPerPage) {
    if (topicsPerPage < 1) return 0;
    return (offerCount + topicsPerPage - 1) ~/ topicsPerPage;
  }

  void _syncCarouselTopicsPerPageIfNeeded(int layoutPerPage) {
    if (layoutPerPage == _carouselTopicsPerPage) return;
    if (_carouselSyncScheduled) return;
    _carouselSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carouselSyncScheduled = false;
      if (!mounted || layoutPerPage == _carouselTopicsPerPage) return;
      setState(() {
        _pageController.dispose();
        _pageController = PageController(viewportFraction: 1);
        _carouselTopicsPerPage = layoutPerPage;
        _pageIndex = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final offers = widget.payload.offers;
    final done = widget.payload.done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, rowConstraints) {
              final rowBudget = rowConstraints.maxHeight - 24;
              final perPage =
                  rowBudget >= kCarouselMinHeightForTwoUp ? 2 : 1;
              _syncCarouselTopicsPerPageIfNeeded(perPage);
              final pages = _pageCount(offers.length, perPage);
              final safePages = pages > 0 ? pages : 1;
              final safeIndex = _pageIndex.clamp(0, safePages - 1);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HubCarouselChevron(
                          icon: Icons.chevron_left_rounded,
                          enabled: safeIndex > 0,
                          label: perPage == 2
                              ? 'Previous pair'
                              : 'Previous topic',
                          onTap: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            );
                          },
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: pages,
                            onPageChanged: (i) {
                              setState(() => _pageIndex = i);
                            },
                            itemBuilder: (context, pageIdx) {
                              final children = <Widget>[];
                              for (var slot = 0; slot < perPage; slot++) {
                                final idx = pageIdx * perPage + slot;
                                if (idx >= offers.length) {
                                  children.add(
                                    const Expanded(child: SizedBox.shrink()),
                                  );
                                } else {
                                  children.add(
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 2,
                                          right: 2,
                                        ),
                                        child: HubTopicCard(
                                          theme: widget.theme,
                                          ik: widget.ik,
                                          offer: offers[idx],
                                          doneToday: done.contains(
                                            offers[idx].topic,
                                          ),
                                          questLevel: widget.payload.questLevel,
                                          questMaxTasks:
                                              widget.payload.questMaxTasks,
                                          onStart: () => widget.onOpenTopic(
                                            offers[idx],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                if (slot < perPage - 1) {
                                  children.add(const SizedBox(height: 8));
                                }
                              }
                              return Column(children: children);
                            },
                          ),
                        ),
                        HubCarouselChevron(
                          icon: Icons.chevron_right_rounded,
                          enabled: safeIndex < safePages - 1,
                          label: perPage == 2 ? 'Next pair' : 'Next topic',
                          onTap: () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: HubPageDots(
                      count: pages,
                      index: safeIndex,
                      color: widget.theme.colorScheme.primary,
                      inactive: widget.theme.colorScheme.outline.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
