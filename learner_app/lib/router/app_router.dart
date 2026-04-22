import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/debug_stats_screen.dart';
import '../screens/model_prepare_screen.dart';
import '../screens/game_shell_screen.dart';
import '../screens/home_hub_screen.dart';
import '../screens/session_summary_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/teacher/teacher_class_summary_screen.dart';
import '../screens/teacher/teacher_gate_screen.dart';
import '../screens/teacher/teacher_home_screen.dart';
import '../screens/teacher/teacher_insights_screen.dart';
import '../screens/teacher/teacher_privacy_screen.dart';
import '../screens/teacher/teacher_quest_editor_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/welcome_screen.dart';
import '../state/settings_store.dart';

/// Drops any visible [SnackBar] when the stack changes so messages from the
/// previous route do not linger (e.g. game hints on the home hub).
class _ClearSnackBarsOnNavigate extends NavigatorObserver {
  void _clearSnackBars(Route<dynamic>? route) {
    final nav = route?.navigator;
    final ctx = nav?.context;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.maybeOf(ctx)?.clearSnackBars();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _clearSnackBars(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _clearSnackBars(previousRoute ?? route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _clearSnackBars(previousRoute ?? route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _clearSnackBars(newRoute);
  }
}

GoRouter createAppRouter(SettingsStore settings) {
  return GoRouter(
    initialLocation: '/splash',
    observers: [_ClearSnackBarsOnNavigate()],
    refreshListenable: settings,
    redirect: (BuildContext context, GoRouterState state) {
      final done = settings.onboardingComplete;
      final loc = state.matchedLocation;
      if (!done && loc != '/welcome' && loc != '/splash') {
        return '/welcome';
      }
      if (done && loc == '/welcome') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/model-prepare',
        builder: (context, state) => const ModelPrepareScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeHubScreen(),
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) {
          final resume = state.uri.queryParameters['resume'] == '1';
          final topic = state.uri.queryParameters['topic'];
          final day = state.uri.queryParameters['day'];
          return GameShellScreen(
            resume: resume,
            hubTopic: topic,
            hubDayKey: day,
          );
        },
      ),
      GoRoute(
        path: '/session-summary',
        builder: (context, state) {
          final id = state.extra as String?;
          return SessionSummaryScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/teacher',
        builder: (context, state) => const TeacherGateScreen(),
      ),
      GoRoute(
        path: '/teacher/home',
        builder: (context, state) => const TeacherHomeScreen(),
      ),
      GoRoute(
        path: '/teacher/quest',
        builder: (context, state) => const TeacherQuestEditorScreen(),
      ),
      GoRoute(
        path: '/teacher/class',
        builder: (context, state) => const TeacherClassSummaryScreen(),
      ),
      GoRoute(
        path: '/teacher/insights',
        builder: (context, state) => const TeacherInsightsScreen(),
      ),
      GoRoute(
        path: '/teacher/privacy',
        builder: (context, state) => const TeacherPrivacyScreen(),
      ),
      GoRoute(
        path: '/dev/stats',
        builder: (context, state) => const DebugStatsScreen(),
      ),
    ],
  );
}
