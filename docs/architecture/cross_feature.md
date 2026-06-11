# Cross-Feature Seams

> Part of the application architectural contract. This is a generalized,
> app-agnostic specification. Companion docs:
> [Scope/Controller/FCIS](fcis.md), [Result pattern](result.md),
> [App composition](composition.md).

A feature is a closed FCIS box (pure updater + shell + View). This doc
covers the four sanctioned seams through which the outside world talks to
a feature without coupling it to navigation, to other features' types, or
to platform sources:

1. **External signals** — lifecycle-aware bridge from any outside source
   (channels, push, sensors, timers, another feature's actions) into a
   feature's `ActionSink`.
2. **Route args carrier** — pass data between pages without coupling to
   the navigation system.
3. **Feature input channel** — a feature-owned event seam other code
   emits into; the controller folds events into State.
4. **`EffectEmitter`** — the UI side-effect seam the shell pushes one-shot
   effects through (navigation, snackbars, dialogs).

---

## 1. External Signals

An **external signal** is anything that originates outside the
application's own control flow — a platform channel, a push notification,
a hardware sensor, a timer, another feature's action stream, and so on.
The external-signal seam gives these a uniform, lifecycle-aware
attach/detach contract that races cleanly against teardown.

### 1.1 The contract — `ExternalSignalListener`

A listener subscribes in `onAttach` and releases everything in `onDetach`.
The two form a strict pair: `onDetach` is always called after `onAttach`,
even when attachment was cancelled mid-flight, so cleanup is guaranteed.

```dart
abstract class ExternalSignalListener {
  const ExternalSignalListener();

  /// Subscribe to the signal source here; hold any handles needed for
  /// cleanup in [onDetach].
  ///
  /// [cancellationToken] fires if the owner detaches before this method
  /// completes — use it to abort expensive/multi-step setup early.
  /// [onDetach] is always called after this returns, cancelled or not.
  Future<void> onAttach(CancellationToken cancellationToken);

  /// Cancel subscriptions and release every resource acquired — even
  /// partially — during [onAttach]. Must be safe to call even if
  /// [onAttach] did not fully complete.
  Future<void> onDetach();
}
```

### 1.2 `CancellationToken` — racing setup against teardown

```dart
class CancellationToken {
  CancellationToken() : _completer = Completer<void>();

  final Completer<void> _completer;

  bool get isCancelled => _completer.isCompleted;

  /// Completes when cancellation is requested. Compose with `Future.any`:
  ///   await Future.any([doWork(), token.signal]);
  Future<void> get signal => _completer.future;

  void _cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
```

Two usage patterns inside `onAttach`:

```dart
// Await-based (recommended):
await Future.any([myHeavySetup(), token.signal]);
if (token.isCancelled) return;

// Poll-based (inside loops):
for (final step in steps) {
  if (token.isCancelled) return;
  await step();
}
```

### 1.3 `ExternalSignalRegistrar` — managing the wave

The registrar manages the attach/detach lifecycle for a fixed list of
listeners. Guarantees:

- Listeners attach concurrently and detach concurrently.
- A detach wave always waits for the preceding attach wave to drain
  before proceeding — no partial/interleaved state.
- If `onDetach` is called while attachment is in progress, all in-flight
  `CancellationToken`s are cancelled immediately; detachment begins once
  the attach wave drains.
- `onDetach` is always called on every listener whose `onAttach` was
  started, even if `onAttach` was cancelled or threw.
- Errors from individual listeners go to `onError`; the wave continues
  for the rest.

```dart
enum _Phase { idle, attaching, attached, detaching }

class ExternalSignalRegistrar {
  ExternalSignalRegistrar(
    List<ExternalSignalListener> listeners, {
    void Function(ExternalSignalListener, Object error, StackTrace)? onError,
  })  : _listeners = List.unmodifiable(listeners),
        _onError = onError;

  final List<ExternalSignalListener> _listeners;
  final void Function(ExternalSignalListener, Object, StackTrace)? _onError;

  _Phase _phase = _Phase.idle;
  final List<CancellationToken> _tokens = [];
  Completer<void>? _attachCompleter;
  Completer<void>? _detachCompleter;

  /// No-op if already attaching or attached. Waits for any draining
  /// detach wave before starting.
  void onAttach() {
    if (_phase != _Phase.idle) return;
    _phase = _Phase.attaching;
    _attachCompleter = Completer<void>();
    unawaited(_runAttachWave());
  }

  /// No-op if idle or already detaching. Cancels in-flight attachments;
  /// the detach wave begins after the attach wave drains.
  void onDetach() {
    if (_phase != _Phase.attaching && _phase != _Phase.attached) return;
    _phase = _Phase.detaching;
    _detachCompleter = Completer<void>();
    for (final token in _tokens) {
      token._cancel();
    }
    unawaited(_runDetachWave());
  }

  Future<void> _runAttachWave() async {
    if (_detachCompleter != null) {
      await _detachCompleter!.future;
    }
    await Future.wait(_listeners.map(_attachOne));
    if (_phase == _Phase.attaching) _phase = _Phase.attached;
    _attachCompleter!.complete();
  }

  Future<void> _runDetachWave() async {
    await _attachCompleter!.future;
    await Future.wait(_listeners.take(_tokens.length).map(_detachOne));
    _tokens.clear();
    _attachCompleter = null;
    _detachCompleter!.complete();
    _detachCompleter = null;
    _phase = _Phase.idle;
  }

  Future<void> _attachOne(ExternalSignalListener listener) async {
    final token = CancellationToken();
    _tokens.add(token);
    try {
      await listener.onAttach(token);
    } on Exception catch (e, st) {
      _onError?.call(listener, e, st);
    }
  }

  Future<void> _detachOne(ExternalSignalListener listener) async {
    try {
      await listener.onDetach();
    } on Exception catch (e, st) {
      _onError?.call(listener, e, st);
    }
  }
}
```

### 1.4 Wiring a signal into a controller

The controller owns the registrar and drives it from its attach/detach
hooks alongside the `EffectEmitter`:

```dart
class <Feature>Controller {
  <Feature>Controller({
    required this.stateHolder,
    required EffectEmitter<<Feature>UiEffect> effectEmitter,
    required ActionSink<<Feature>Action> sink,
    required ExternalSignalRegistrar registrar,
  })  : _effectEmitter = effectEmitter,
        _sink = sink,
        _registrar = registrar;

  final ValueListenableStateHolder<<Feature>State> stateHolder;
  final EffectEmitter<<Feature>UiEffect> _effectEmitter;
  final ActionSink<<Feature>Action> _sink;
  final ExternalSignalRegistrar _registrar;

  void onViewAttach({
    required EffectPusher<<Feature>UiEffect> pusher,
  }) {
    _effectEmitter.attach(pusher);
    _registrar.onAttach();
    dispatch(const ViewAttached());
  }

  void onViewDetach() {
    _registrar.onDetach();
    _effectEmitter.detach();
  }
}
```

### 1.5 Binder + listener — unwrapping a foreign event into an Action

A **binder** is a manual reactor over a source: `bind` subscribes,
`unbind` removes, and the handler unwraps the foreign event into a
**feature-owned Action** (scalars only — see
[FCIS §6.3](fcis.md)). A thin `ExternalSignalListener` adapts the binder
to the registrar's lifecycle.

```dart
/// Routes [AppEvent]s the feature cares about into actions.
class <Feature>AppEventBinder {
  <Feature>AppEventBinder({
    required AppEventHub hub,
    required ActionSink<<Feature>Action> sink,
  })  : _hub = hub,
        _sink = sink;

  final AppEventHub _hub;
  final ActionSink<<Feature>Action> _sink;
  bool _bound = false;

  void _onEvent(AppEvent event) {
    switch (event) {
      case ActiveProfileChanged():
        _sink.dispatch(const ActiveProfileChangedAction());
    }
  }

  void bind() {
    if (_bound) return;
    _hub.addListener(_onEvent);
    _bound = true;
  }

  void unbind() {
    if (!_bound) return;
    _hub.removeListener(_onEvent);
    _bound = false;
  }
}

/// Adapts the binder to the external-signal lifecycle.
class <Feature>AppEventSignalListener extends ExternalSignalListener {
  <Feature>AppEventSignalListener({required this.binder});

  final <Feature>AppEventBinder binder;

  @override
  Future<void> onAttach(CancellationToken _) => Future.syncValue(binder.bind());

  @override
  Future<void> onDetach() => Future.syncValue(binder.unbind());
}
```

Assembled in the feature's composition root:

```dart
late final ExternalSignalRegistrar registrar = ExternalSignalRegistrar([
  <Feature>AppEventSignalListener(
    binder: <Feature>AppEventBinder(hub: shared.appEventHub, sink: sink),
  ),
]);
```

**MUST:** the binder unwraps foreign types into feature-owned, scalar
Actions; the reducer (not the binder) decides whether to act on them.

---

## 2. Route Args Carrier — passing data between pages

Do **not** couple a feature to the navigation system to receive its
inputs. Pass data through an external carrier: a small store the origin
screen writes before navigating and the destination reads on entry.

Split the carrier into a read interface, a write interface, and a store
that implements both:

```dart
/// Read side — what the destination screen consumes.
abstract class StoryAnswersRouteArgs {
  String get userId;

  /// Whether the target profile belongs to the current user. When true,
  /// the answers are our own content and are never gated.
  bool get isMe;
}

/// Write side — what the origin screen sets.
abstract class StoryAnswersRouteArgsWriter {
  /// Sets the target in one call so [isMe] can never go stale across
  /// navigations from different origin screens.
  void setUserId(String userId, {required bool isMe});
}

/// The store implements both halves.
abstract class StoryAnswersRouteArgsStore
    implements StoryAnswersRouteArgs, StoryAnswersRouteArgsWriter {}
```

Flow: the origin screen **writes** the args before navigating; the
destination **reads** them on entry.

**MUST:**

1. Set all correlated fields in a single writer call (as `setUserId`
   does for `userId` + `isMe`) so they can never go stale or
   half-updated across navigations from different origins.
2. The destination depends on the **read** interface only; the origin
   depends on the **write** interface only.
3. Navigation passes no payload — it only triggers the route. The
   carrier is the payload.

---

## 3. Feature Input Channel — pushing intent into a feature

A **feature input channel** is a feature-owned event seam that other
sources (a cached repository, another feature, a background job) emit
into. The feature's controller subscribes and folds events into State —
typically via an external-signal binder (§1.5).

The channel splits into a sealed event family, a listener half (consumer
subscribes), and a notifier/emitter half (producer emits). Back it with a
`ValueNotifier`/`ChangeNotifier`.

```dart
/// Feature-owned event seam for the feed's cache.
///
/// When the remote feed is unreachable, the cached repository emits a
/// [FeedStoriesReplaced] carrying the DB-filtered offline snapshot; the
/// controller's signal folds it into State as a full replace.
sealed class FeedChannelEvent {
  const FeedChannelEvent();
}

/// An offline snapshot that should fully replace the stories currently in
/// State (not merged).
final class FeedStoriesReplaced extends FeedChannelEvent {
  const FeedStoriesReplaced(this.result);
  final FeedResult result;
}

/// Listener half — the controller subscribes here.
abstract interface class FeedChannel<T> {
  T latestEvent;
  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}

/// Notifier half — the cached repository emits here.
abstract interface class FeedChannelEmitter
    implements Notifier<FeedChannelEvent> {
  void emit(FeedChannelEvent event);
}

/// Both halves, for the impl.
abstract interface class ObservableFeedChannel
    implements FeedChannel, FeedChannelEmitter {}
```

Implement the channel with a `ValueNotifier`/`ChangeNotifier`. The
producer holds the **emitter** interface; the controller holds the
**listener** interface — neither sees the other's half.

**MUST:** events are a sealed family; the consuming controller forwards
them as feature-owned Actions and lets the reducer decide
([FCIS §6.3](fcis.md)). A channel is for *inbound intent into one
feature*; it is not a general pub/sub bus.

---

## 4. `EffectEmitter` — the UI side-effect seam

`EffectEmitter<T>` is the decoupled seam the shell pushes one-shot UI
effects through — navigation, snackbars, dialogs, bottom sheets, loading
toggles — without the controller depending on the UI. The View attaches a
handler in `initState`/`onAttach` and detaches it in `dispose`/`onDetach`.

> **Naming.** This seam was previously called `SideEffector` (with a
> `SideEffectPusher` callback typedef). The canonical name is
> **`EffectEmitter`** with an **`EffectPusher`** callback typedef; the old
> names are legacy aliases — use the new names in all new code.

This seam lives in its own local package, **`package:effect_emitter`**
(`packages/effect_emitter/`); import it rather than redefining it per app.

```dart
// package:effect_emitter/effect_emitter.dart

/// Handler the View registers to receive one-shot effects.
typedef EffectPusher<T> = void Function(T effect);

/// Emits one-time side effects (events) from a controller/shell to the UI
/// layer without a direct dependency on the UI.
///
/// Use cases: navigation (push/pop/replace), snackbars, dialogs, bottom
/// sheets, loading/error notifications.
class EffectEmitter<T> {
  EffectPusher<T>? _pusher;

  void _emit(T effect) => _pusher?.call(effect);

  /// Push a side effect to the UI. No-op if no pusher is attached.
  void push(T effect) => _emit(effect);

  /// Attach the View's handler. Typically called from `initState` /
  /// `onAttach`.
  // ignore: use_setters_to_change_properties
  void attach(EffectPusher<T> pusher) => _pusher = pusher;

  /// Detach the handler. Call from `dispose` / `onDetach` to prevent
  /// leaks.
  void detach() => _pusher = null;
}
```

Defining and consuming effects (the View exhaustively switches the sealed
`<Feature>UiEffect` — see [FCIS §6.4/§6.7](fcis.md)):

```dart
// Controller/shell side:
_effectEmitter.push(const <Feature>FinishedUiEffect());
_effectEmitter.push(<Feature>ShowErrorUiEffect(message));

// View side (attached handler):
void _onUiEffect(<Feature>UiEffect effect) {
  if (!mounted) return;
  switch (effect) {
    case <Feature>PopUiEffect():
      Navigator.of(context).maybePop();
    case <Feature>ShowErrorUiEffect(:final message):
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_uiMessage(message))));
    case <Feature>FinishedUiEffect():
      Navigator.of(context).pushReplacement(NextPage.route());
  }
}
```

**MUST:** `UiEffect`s are pushed from the shell only, never the updater
([FCIS §6.3](fcis.md)). The emitter is one-shot fire-and-forget — it does
not buffer; effects pushed while detached are dropped.

---

## 5. Feature-to-feature — observe state, dispatch Actions

A feature built on FCIS that is consumed by **other features** (not only
its own View) exposes a deliberately narrow surface. Outside consumers get
exactly two capabilities:

1. **Observe its state** — read-only.
2. **Pass intent into it** — by dispatching Actions through an
   `ActionSink`.

That is the *entire* contract. Everything else — the controller's
attach/detach hooks, the shell, the injected deps, the `EffectEmitter` —
stays private. The feature remains a closed FCIS box: outside code
expresses *intent* as Actions and *reacts* to state; it never drives
effects, mutates state directly, or reaches the feature's internals. The
reducer stays the single place that interprets intent against current
state ([FCIS §6.3](fcis.md)).

### 5.1 The access facade

```dart
import 'package:fcis_core/fcis_core.dart'; // ActionSink
import 'package:flutter/foundation.dart';  // ValueListenable

/// What the <Feature> feature exposes to OTHER features.
/// Two capabilities: observe state, pass intent. Nothing else.
abstract interface class <Feature>Access {
  /// Read-only observation of the feature's state.
  ValueListenable<<Feature>State> get state;

  /// The sole input: pass intent as a feature-owned Action.
  ActionSink<<Feature>Action> get input;
}
```

The feature's module implements it by handing out the pieces it already
owns: its `stateHolder` exposed as the read-only `ValueListenable`, and
the loop — which **is** the `ActionSink<Action>` ([FCIS §6.8](fcis.md)) —
as the input:

```dart
class <Feature>Module implements <Feature>Access {
  // …wires stateHolder → effectEmitter → shell → loop → controller…

  @override
  ValueListenable<<Feature>State> get state => stateHolder; // read-only view
  @override
  ActionSink<<Feature>Action> get input => loop;            // dispatch only
}
```

### 5.2 The consumer side

A consumer feature receives the access object as a constructor dependency.
It depends on the target feature's `State` + `Action` sealed families
([FCIS §6.4](fcis.md)) — a deliberate, visible coupling, and the *only*
coupling. It observes state via the listenable and forwards its own intent
by dispatching the target's Actions (typically from its shell, or bridged
through an external-signal binder (§1) so a state change there becomes an
Action here).

**MUST:**

1. Outside consumers get exactly two capabilities: **observe state**
   (read-only) and **`dispatch` Actions** (`ActionSink`). Do not expose
   the controller's `onAttach`/`onDetach`, the `EffectEmitter`, the shell,
   or any dep.
2. The state handle is **read-only** (`ValueListenable<State>`, not the
   mutable `ValueNotifier` / `StateHolder`). Consumers never set state.
3. Intent crosses the boundary as the target feature's **own sealed
   Actions** — scalars / feature-local types only, never the consumer's
   foreign types ([FCIS §6.3](fcis.md)).
4. `UiEffect`s never cross features — they belong to the feature's own
   View (§4). A consumer reacts to **state**, not to another feature's UI
   effects.

**Relation to §3.** The feature input channel (§3) is a loosely-coupled,
event-emission seam the feature owns and subscribes to internally — good
for fire-and-forget events from infrastructure. The access facade here is
the direct, FCIS-native handle a consumer holds to *observe and steer*
another feature. Reach for the channel for inbound events; reach for the
facade when one feature must watch another's state and push intent into
it.
