# App Composition, Initialization & Launch

> Part of the application architectural contract. This is a generalized,
> app-agnostic specification: replace `<app>` with your package name.
> Companion docs: [Scope/Controller/FCIS](fcis.md),
> [Result pattern](result.md), [Cross-feature seams](cross_feature.md).

This doc covers how the dependency graph is selected and initialized, and
how the app launches: the `InitializationRepository` abstraction, the
`AppConfig` selector, the App Launch entry point, and the post-init
destination resolver.

---

## 1. `InitializationRepository` — the init seam

Application-startup work (open the DB, restore the device clock, provision
identity, warm caches, …) hides behind a single infallible-by-contract
seam:

```dart
abstract interface class InitializationRepository {
  Future<void> initialize();
}
```

**MUST:**

1. There is exactly one `InitializationRepository` per resolved dependency
   graph. It is the only thing App Launch calls to bring the app up.
2. `initialize()` is idempotent-safe to await once at startup. It composes
   the concrete init steps internally; callers never see those steps.
3. Concrete implementations live in `infra/`; the interface lives in
   `domain/`. Different graphs (production, dev/in-memory, integration
   test) provide different implementations.

The init repository is the place to sequence ordered startup work; do not
spread `await`-this-then-that startup logic across widgets or the Scope.

---

## 2. `AppConfig` — selecting the dependency graph

Which concrete dependencies the app uses is chosen by an **immutable
`AppConfig`** value, resolved once at the composition root. `AppConfig` is
a plain value object (flavor, environment, feature flags, backend mode,
…); resolvers switch on it to pick implementations.

```dart
@immutable
class AppConfig {
  const AppConfig({
    required this.environment,   // e.g. prod / dev / test
    required this.backend,       // e.g. relay-backed / local-only
    // …other graph-selecting flags…
  });

  final AppEnvironment environment;
  final BackendMode backend;
}

InitializationRepository _resolveInitializationRepository(AppConfig config) {
  switch (config.environment) {
    case AppEnvironment.prod:
      return ProductionInitializationRepository(/* real deps */);
    case AppEnvironment.dev:
      return InMemoryInitializationRepository(/* in-memory deps */);
    case AppEnvironment.test:
      return ProductionInitializationRepository(/* ffi DB, etc. */);
  }
}
```

**MUST:** `AppConfig` is immutable (`const`-constructible) and is the
*only* input to dependency selection. Resolvers are pure functions of
`AppConfig`; they do not read globals or ambient state.

---

## 3. App Launch — the entry point

App Launch is the application's entry point and splash screen. It owns two
distinct responsibilities, deliberately split across two seams so the
second can sequence strictly after the first:

1. **`AppLaunchController`** — drives initialization. It is given the
   resolved `InitializationRepository`, runs `initialize()`, and emits an
   `InitializationCompleteEffect` when the graph is up.
2. **`AppDestinationResolver`** — decides where to navigate *after*
   initialization completes. Because it depends on a fully-initialized
   graph, it must run after `AppLaunchController`, and so it is hosted in
   its own Scope ([the sole sanctioned resolver-Scope carve-out,
   FCIS §4](fcis.md)).

### 3.1 Wiring at the root

```dart
AppLaunchScope.setController(
  AppLaunchController(
    initializationRepository: _resolveInitializationRepository(config),
  ),
);
```

### 3.2 Sequencing — init, then resolve destination

The controller's FCIS loop performs initialization; on completion the
View consumes `InitializationCompleteEffect`, asks the destination
resolver where to go, and navigates. The resolver runs only here, after
init, guaranteeing the graph it depends on exists:

```dart
case InitializationCompleteEffect():
  unawaited(
    _destinationResolver.resolve().then((destination) {
      if (!mounted) return;
      switch (destination) {
        case AppLaunchDestination.onboarding:
          unawaited(
            Navigator.of(context).pushReplacement(AuthorizePage.route()),
          );
        case AppLaunchDestination.home:
          unawaited(
            Navigator.of(context).pushReplacement(HomePage.route()),
          );
      }
    }),
  );
```

**MUST:**

1. `AppDestinationResolver.resolve()` is called only after
   initialization completes — never during or before.
2. The destination is a sealed/enum `AppLaunchDestination`; the View
   exhaustively switches on it and `pushReplacement`s the splash.
3. The resolver-hosting Scope is the only sanctioned non-controller Scope.
   Do not generalize the `<Feature>Resolver`-shaped Scope into other
   features.
