import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../llm/flutter_gemma_llm_engine.dart';
import '../../application/home_hub_bloc.dart';
import '../../application/home_hub_state.dart';
import '../hub_layout_constants.dart';
import 'on_device_hub_loading_panel.dart';

/// Shown while re-verifying the on-device model after returning to the hub.
class HomeHubResumeBanner extends StatelessWidget {
  const HomeHubResumeBanner({super.key, required this.modelInitPercent});

  final int? modelInitPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocSelector<HomeHubBloc, HomeHubState, bool>(
      selector: (s) =>
          s is HomeHubReady && s.resumeBusy && shouldUseFlutterGemmaEngine,
      builder: (context, showResume) {
        if (!showResume) return const SizedBox.shrink();
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
              child: Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: OnDeviceHubLoadingPanel(
                    showDiagnostics: false,
                    modelInitPercent: modelInitPercent,
                    showElapsedExpectations: true,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
