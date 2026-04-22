import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../llm/flutter_gemma_llm_engine.dart';
import '../llm/llm_service.dart';
import '../llm/model_prepare_prefs.dart';
import '../state/settings_scope.dart';
import '../theme/ikamva_colors.dart';
import '../widgets/ikamva_logo.dart';

/// Brief branded screen shown on cold start before [GoRouter] resolves home or welcome.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1)
      .animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );

  static const _dwell = Duration(milliseconds: 2000);

  Future<void> _goNext() async {
    if (!mounted) return;
    final settings = SettingsScope.of(context);
    if (!settings.onboardingComplete) {
      context.go('/welcome');
      return;
    }
    if (!shouldUseFlutterGemmaEngine) {
      context.go('/home');
      return;
    }
    final donePrepare = await ModelPreparePrefs.isPrepareDone();
    if (!mounted) return;
    if (!donePrepare) {
      context.go('/model-prepare');
      return;
    }
    final modelOk = await probeFlutterGemmaActiveModelReady(settings);
    if (!mounted) return;
    if (modelOk) {
      context.go('/home');
    } else {
      await ModelPreparePrefs.setPrepareDone(false);
      if (!mounted) return;
      LlmService.instance.invalidateCachedEngine();
      context.go('/model-prepare');
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(_dwell).then((_) => _goNext());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvas = context.ikamvaColors.canvas;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: canvas,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IkamvaLogo(height: 96),
                const SizedBox(height: 20),
                Text(
                  'Ikamva Lam',
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: theme.textTheme.bodyLarge,
                    children: [
                      const TextSpan(text: 'Playful English\n'),
                      TextSpan(
                        text: 'practice that works offline.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
