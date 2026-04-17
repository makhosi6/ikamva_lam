import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/game_shell_screen.dart';
import '../screens/home_hub_screen.dart';
import '../screens/session_summary_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/welcome_screen.dart';
import '../state/settings_store.dart';

GoRouter createAppRouter(SettingsStore settings) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: settings,
    redirect: (BuildContext context, GoRouterState state) {
      final done = settings.onboardingComplete;
      final loc = state.matchedLocation;
      if (!done && loc != '/welcome') {
        return '/welcome';
      }
      if (done && loc == '/welcome') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeHubScreen(),
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) => const GameShellScreen(),
      ),
      GoRoute(
        path: '/session-summary',
        builder: (context, state) => const SessionSummaryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
