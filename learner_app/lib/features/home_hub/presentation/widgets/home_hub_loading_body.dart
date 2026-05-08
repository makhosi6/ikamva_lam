import 'package:flutter/material.dart';

import '../../application/home_hub_state.dart';
import '../hub_layout_constants.dart';
import 'on_device_hub_loading_panel.dart';

/// Centered loading panel (model warm + hub fetch).
class HomeHubLoadingBody extends StatelessWidget {
  const HomeHubLoadingBody({
    super.key,
    required this.scrollController,
    required this.modelInitPercent,
    required this.loadPhase,
  });

  final ScrollController scrollController;
  final int? modelInitPercent;
  final HomeHubLoadPhase? loadPhase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kHubTextGutter),
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kHubMaxContentWidth),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: OnDeviceHubLoadingPanel(
                  scrollController: scrollController,
                  diagnosticsHeight: kHubDiagnosticsPeekHeight,
                  modelInitPercent: modelInitPercent,
                  loadPhase: loadPhase,
                  showElapsedExpectations: true,
                  useOnPrimaryContainerTextColors: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
