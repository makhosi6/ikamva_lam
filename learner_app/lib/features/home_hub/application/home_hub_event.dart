sealed class HomeHubEvent {
  const HomeHubEvent();
}

/// Cold start: warm model (if needed) then fetch hub payload.
final class HomeHubStarted extends HomeHubEvent {
  const HomeHubStarted();
}

/// Refresh topics without re-running full model install (hub already ready).
final class HomeHubReloadRequested extends HomeHubEvent {
  const HomeHubReloadRequested();
}

/// After returning from a topic session — reload hub rows.
final class HomeHubReturnedFromTopic extends HomeHubEvent {
  const HomeHubReturnedFromTopic();
}

/// After [RouteAware.didPopNext] — re-verify on-device weights.
final class HomeHubResumeVerifyRequested extends HomeHubEvent {
  const HomeHubResumeVerifyRequested();
}
