# Scope, Controller & FCIS

> Part of the application architectural contract for the **presentation
> layer**. This is a generalized, app-agnostic specification: replace
> `<Feature>` / `<feature>` with the feature name and `<app>` with your
> package name. Section numbers (§N) are preserved from the shared contract
> so cross-references stay stable; companion docs:
> [Result pattern](result.md), [App composition](composition.md),
> [Cross-feature seams](cross_feature.md).

The layer is **Functional Core / Imperative Shell (FCIS)**: a pure updater
decides *what* should happen, an imperative shell performs the I/O, and the
View only renders state and dispatches intents. New code realizes FCIS
through the shared **`package:fcis_core`** runtime (§6.8) rather than a
hand-rolled fat controller.

---

## 4. The `<Feature>Scope` Rule

**Statement.** Every feature has exactly one `<Feature>Scope`. The Scope
hosts exactly one `<Feature>Controller`. The Scope holds nothing else. The
Scope's sole role is to decouple the controller from the UI layer — the UI
uses the Scope as a handle to acquire the controller, because the UI only
ever needs the controller in order to make the feature work.

**Canonical template** (copy-paste, replace `<Feature>` / `<feature>` /
`<app>`):

```dart
// lib/features/<feature>/presentation/<feature>_scope.dart
import 'package:<app>/features/<feature>/presentation/<feature>_controller.dart';

/// Cell for [<Feature>Controller]. The Scope holds nothing else.
abstract class <Feature>Scope {
  static <Feature>Controller? _controller;
  static <Feature>Controller Function()? _factory;

  static void setController(<Feature>Controller c) => _controller = c;
  static void setFactory(<Feature>Controller Function() factory) =>
      _factory = factory;
  static void reset() => _controller = null;

  static <Feature>Controller get controller {
    if (_controller != null) return _controller!;
    if (_factory == null) {
      throw StateError(
        '<Feature>Scope is not initialized.\n'
        'Call <Feature>Scope.setController() or <Feature>Scope.setFactory() '
        'before accessing <Feature>Scope.controller.',
      );
    }
    return _controller = _factory!();
  }
}
```

**MUST:**

1. The Scope is an `abstract class` used as a namespace. It is never
   instantiated.
2. It declares exactly two static fields: `_controller` and `_factory`.
3. It exposes exactly four members: `setController`, `setFactory`,
   `reset`, and the `controller` getter.
4. It imports only its own controller. No repositories, no storages, no
   channels, no widgets, no third-party packages.
5. The file is ≤ 30 lines.
6. The Scope file is sited at
   `lib/features/<feature>/presentation/<feature>_scope.dart`.

**MUST NOT:**

1. Hold feature state, notifiers, or caches beyond the controller cell.
2. Subscribe to streams, channels, or callbacks. All subscriptions happen
   inside the controller's attach hook (`onAttach` for fcis_core,
   `onViewAttach` for inline) and tear down in the matching detach hook.
3. Hold sub-controllers, presenters, or sub-services.
4. Expose any of the controller's dependencies (`.repository`, `.session`, …).
5. Contain any method body longer than one expression.

**Anti-example — REFUSE to write code like this:**

```dart
// ❌ WRONG — Scope is doing things other than hosting the controller
abstract class OnboardScope {
  static OnboardController? _controller;
  static OnboardController Function()? _factory;

  static final repository = OnboardRepositoryImpl();            // ❌ no
  static final subscriptions = <StreamSubscription>[];          // ❌ no
  static late ValueNotifier<OnboardState> stateNotifier;        // ❌ no

  static Future<void> initialize() async {                      // ❌ no
    subscriptions.add(SomeChannel.events.listen(_handle));
  }

  static OnboardController get controller { … }
}
```

Every line marked `❌` is a violation. Move the repository into the
controller's constructor (§5.2); move the subscription to
`controller.onAttach`; move the notifier to the View.

**Narrow sanctioned exception.** A Scope may host an
`AppDestinationResolver` instead of a `<Feature>Controller` **only** for
the post-initialization destination decision at app launch (see
[App composition §3](composition.md)). That resolver must sequence after
initialization completes, and the work is too small to warrant a full
feature. This is the *only* sanctioned `<Feature>Resolver`-shaped Scope;
do not introduce others.

---

## 5. The Controller (Orchestrator)

### 5.1 Responsibilities

- Accepts all external dependencies in its constructor.
- Owns the `ViewStateBinder<State>` and `EffectEmitter<UiEffect>` seams
  (each defaulted so tests can inject custom ones).
- Provides `onAttach`/`onDetach` (fcis_core) or
  `onViewAttach`/`onViewDetach` (inline-legacy) to bind/unbind the View.
- Provides `dispatch(<Feature>Action)` as the single public entry point
  for user/system intents.
- Runs the imperative shell: switches on the sealed `<Feature>Effect`,
  performs I/O via injected deps, dispatches result Actions, and pushes
  `<Feature>UiEffect`s as needed.
- May hold a `<Feature>Updater` instance (§6.5) instead of a top-level
  `update` function reference, when the updater needs encapsulation.

### 5.2 Constructor shape — every external dep is `required`

```dart
class <Feature>Controller {
  <Feature>Controller({
    required <Repo1> someRepo,
    required <Repo2> otherRepo,
    // …all other external deps as `required` parameters…
    ViewStateBinder<<Feature>State>? viewBinding,
    EffectEmitter<<Feature>UiEffect>? effectEmitter,
  })  : _someRepo = someRepo,
        _otherRepo = otherRepo,
        _viewBinding = viewBinding ?? ViewStateBinder<<Feature>State>(),
        _effectEmitter = effectEmitter ?? EffectEmitter<<Feature>UiEffect>();

  final <Repo1> _someRepo;
  final <Repo2> _otherRepo;
  final ViewStateBinder<<Feature>State> _viewBinding;
  final EffectEmitter<<Feature>UiEffect> _effectEmitter;
  // …
}
```

**MUST:** every external dep is a `required` named parameter. The
view-side seams (`viewBinding`, `effectEmitter`) are optional, defaulting
to fresh instances; tests inject custom ones.
(`EffectEmitter` is the UI side-effect seam — see
[Cross-feature seams §4](cross_feature.md).) Each external dep is a
**narrow, single-purpose** port, not one fat catch-all repository — see
[Business logic §5](business_logic.md).

### 5.3 Public API surface — exactly three methods

> **inline-FCIS shape.** The `onViewAttach(getter, updater, pusher)` /
> `onViewDetach` / `dispatch` surface below is the legacy inline form.
> fcis_core controllers (canonical, §6.8) expose `onAttach(pusher)` /
> `onDetach()` / `dispatch`, own a public `stateHolder`, and delegate
> `dispatch` to the loop's `ActionSink`. `onAttach` is the canonical
> name; `onViewAttach` is inline-legacy.

```dart
void onViewAttach({
  required StateGetter<<Feature>State> getter,
  required StateUpdater<<Feature>State> updater,
  required EffectPusher<<Feature>UiEffect> pusher,
}) { /* bind seams, start subscriptions */ }

void onViewDetach() { /* tear down */ }

Future<void> dispatch(<Feature>Action action) async {
  final (next, effects) = _update(_viewBinding.state, action);
  _viewBinding.update(next);
  if (effects != null) {
    for (final effect in effects) {
      await _runEffect(effect);
    }
  }
}
```

The controller MUST NOT expose per-intent wrapper methods. The View
dispatches Actions directly:

```dart
// ✅ RIGHT — the View dispatches Actions directly.
TextField(onChanged: (v) => controller.dispatch(NameChanged(v)))
ElevatedButton(onPressed: () => controller.dispatch(const ContinueTapped()))
```

```dart
// ❌ WRONG — wrapper method on the controller, hides the Action.
TextField(onChanged: controller.onNameChanged)
ElevatedButton(onPressed: controller.onContinue)

// inside controller:
void onNameChanged(String value) => dispatch(NameChanged(value));
void onContinue() => dispatch(const ContinueTapped());
```

Wrapper methods are debt. Do not add new ones. **Do not remove existing
wrappers as a side-effect of unrelated work** — removal is reserved for a
dedicated cleanup change.

### 5.4 External-dependency lifecycle (subscriptions, timers, sockets)

There is no single rule. `onViewAttach` and `onViewDetach` are
**synchronous** because they are called from `StatefulWidget`'s
`initState` / `dispose`. Calling async work directly from them is
undefined behavior.

Patterns:

- **Simple listener** (e.g. a refresh channel): subscribe in
  `onAttach`, unsubscribe in `onDetach`.

- **Ordered async (sockets, sequenced ops)**: push **idempotency** into
  the infrastructure (so a binder can be called multiple times safely)
  and use an **`AsyncOperationQueue`** (`lib/core/async_operation_queue.dart`)
  to guarantee sequential execution where order matters.

When you have a choice and ordering matters, prefer pushing ordering
into infrastructure (idempotent binder + queue) over imperative
"if-not-attached-attach-now" guards in the controller.

For richer cross-feature / external sources, prefer the
**external-signal** lifecycle ([Cross-feature seams §1](cross_feature.md))
over ad-hoc subscriptions.

**Listener tear-off discipline.** Do NOT retain method tear-offs in
instance fields to feed them back to `removeListener`. Dart instance
method tear-offs are stable across calls — `_x.addListener(_onEvent)`
and `_x.removeListener(_onEvent)` operate on the same callable
identity. The retention pattern below solves a problem Dart doesn't
have:

```dart
// ❌ WRONG — pointless retention.
void Function(Event)? _listener;

void onViewAttach(...) {
  final listener = _onEvent;
  _listener = listener;
  _channel.addListener(listener);
}

void onViewDetach() {
  final listener = _listener;
  if (listener != null) {
    _channel.removeListener(listener);
    _listener = null;
  }
}
```

```dart
// ✅ RIGHT — direct tear-off, symmetric add/remove.
void onViewAttach(...) {
  _channel.addListener(_onEvent);
}

void onViewDetach() {
  _channel.removeListener(_onEvent);
}
```

### 5.5 State location

State is **owned by the View**, in a `ValueNotifier<<Feature>State>` the
View constructs in `initState` (inline form) or in the controller's
public `stateHolder` (fcis_core form). The controller is **stateless with
respect to feature state**; it reaches state through the
`ViewStateBinder` / `stateHolder`. This makes the controller cheap to
construct, re-attachable across page rebuilds, and trivially testable
(inject a custom binder driven by a test-owned notifier).

### 5.6 Updater wiring (function vs class)

The default is a top-level pure `update` function (§6). When the updater
needs encapsulation (private helpers, sub-reducers, internal types), the
updater is extracted into a `<Feature>Updater` class (§6.5). The
controller accepts either via an optional constructor parameter:

```dart
// Variant A — top-level function (default for simple updaters):
class <Feature>Controller {
  <Feature>Controller({
    // …deps…
    (<Feature>State, List<<Feature>Effect>?) Function(
      <Feature>State, <Feature>Action,
    )? update,
  })  : _update = update ?? update<Feature>;
  // …
  final (<Feature>State, List<<Feature>Effect>?) Function(
    <Feature>State, <Feature>Action,
  ) _update;
}

// Variant B — class form (when encapsulation is needed):
class <Feature>Controller {
  <Feature>Controller({
    // …deps…
    <Feature>Updater? updater,
  })  : _updater = updater ?? const <Feature>Updater();
  // …
  final <Feature>Updater _updater;
}
```

---

## 6. Functional Core, Imperative Shell

> **Runtime: `package:fcis_core`.** §6.1–6.7 describe the FCIS *concept*
> (pure updater, effect descriptors, imperative shell, View binding) —
> that concept is unchanged and authoritative. **New code realizes it
> through the shared `package:fcis_core` runtime, not a hand-rolled fat
> controller with a `_runEffect` method.** The inline shape shown in §5.3
> / §6.6 (top-level `update()` + controller-owned `_runEffect`) is the
> **legacy** form — do not write new code that way. **§6.8 is the
> canonical realization for new features.**

### 6.1 The contract

```dart
(<Feature>State, List<<Feature>Effect>?) update(
  <Feature>State state,
  <Feature>Action action,
);
```

The updater MUST be pure. It returns the new state and an optional list
of `Effect`s (descriptors of async work). The shell performs the I/O
described by each `Effect` and feeds results back as Actions.

### 6.2 Allowed inside the updater

- Pattern matching on the sealed `Action`.
- Reading from `state`.
- Calling other pure helpers in the same module.
- Returning a new state via `state.copyWith(...)`.
- Returning a non-null `List<Effect>` to request async work.
- Recursively calling `update(state', otherAction)` to chain reductions
  (e.g. `ContinueTapped` may resolve internally to
  `update(validatedState, const SubmitRequested())`).

### 6.3 Forbidden inside the updater

- `await`, `Future`, `Stream` — the updater is synchronous.
- `DateTime.now()`, `Random`, file/network I/O, `print`, `log`.
- Reading from a repository, storage, channel, or any injected dep.
- Pushing `UiEffect`s. `UiEffect`s are pushed by the shell only.
- Touching `BuildContext` or any Flutter widget.
- Mutating fields of `state` — always produce a new instance via
  `copyWith`.

If the updater needs "current time" or "a fresh UUID", the value is
passed in as an Action payload (the shell synthesizes it).

**Controller-side corollary: binder discipline.** Outside the
controller's canonical `dispatch` / `_runEffect` cycle, the controller
MUST NOT read the current state. Listener callbacks (channel events,
repository updates, timer ticks, …) MUST NOT filter by current state
before dispatching — they forward the raw event as an Action, and the
**reducer reads `state`** to decide whether to act.

```dart
// ❌ WRONG — listener filters by state before dispatching.
void _onBlockEvent(UserBlockEvent event) {
  if (event.targetUserId != _viewBinding.state.partnerId) return;
  dispatch(BlockRelationChanged(BlockRelation.fromFlags(...)));
}
```

```dart
// ✅ RIGHT — listener forwards unwrapped scalars; reducer filters.
void _onBlockEvent(UserBlockEvent event) {
  dispatch(UserBlockChannelPulsed(
    targetUserId: event.targetUserId,
    isBlockedByMe: event.isBlockedByMe,
    hasBlockedMe: event.hasBlockedMe,
  ));
}

// In update():
case UserBlockChannelPulsed(
  :final targetUserId,
  :final isBlockedByMe,
  :final hasBlockedMe,
):
  if (targetUserId != state.partnerId) return (state, null);
  return update(state, BlockRelationChanged(
    BlockRelation.fromFlags(
      isBlockedByMe: isBlockedByMe,
      hasBlockedMe: hasBlockedMe,
    ),
  ));
```

The same rule applies to any other source of asynchronous input
(repository listeners, socket handlers, etc.). The principle: **all
business logic — including event filtering — lives inside `update`**.
The controller's job between `dispatch` boundaries is plumbing only.

**Action payloads MUST NOT carry shared cross-feature types.** Sealed
Action subtypes for a feature describe that feature's own contract;
they MUST be defined in terms of scalars and feature-local domain
types only. The listener at the seam unwraps a foreign type
(a channel event, a socket payload, a remote DTO) into the
feature-owned Action's fields. Two reasons:

1. **Coupling visibility.** An `Action` carrying a foreign event field
   hides the cross-feature dependency inside the action sealed family —
   the reducer transitively imports the other module's domain model.
   Unwrapping at the seam keeps the dependency confined to the
   controller file.
2. **Stability against the foreign type's evolution.** If the foreign
   type adds, renames, or reshapes a field, an unwrapped action is
   unaffected; the listener is the only thing that breaks (and breaks at
   a single, obvious place).

```dart
// ❌ WRONG — action couples this reducer to UserBlockEvent's shape.
final class UserBlockChannelPulsed extends ChatAction {
  const UserBlockChannelPulsed(this.event);
  final UserBlockEvent event;
}
```

```dart
// ✅ RIGHT — action carries feature-owned scalars; listener unwraps.
final class UserBlockChannelPulsed extends ChatAction {
  const UserBlockChannelPulsed({
    required this.targetUserId,
    required this.isBlockedByMe,
    required this.hasBlockedMe,
  });
  final String targetUserId;
  final bool isBlockedByMe;
  final bool hasBlockedMe;
}
```

Within-feature domain types are fine (e.g. `PartnerLoaded(this.partner)`
carrying the feature's own `Partner`).

**Effect parsimony.** Don't introduce a new `<Name>Effect` type when the
work fits inside an existing effect's cycle that ends in the same outcome
action. If an existing shell handler already dispatches the outcome
action, fold a related seed into that handler rather than minting a
sibling effect the caller has to chain. New types are justified when the
work is independently triggerable or has a distinct outcome.

### 6.4 Sealed Action / Effect / UiEffect

**`<Feature>Action`** — every intent the feature responds to, plus every
async-result delivery, as a sealed family.

```dart
sealed class <Feature>Action { const <Feature>Action(); }

// View lifecycle
class InitialLoad extends <Feature>Action { const InitialLoad(); }

// UI intents
class NameChanged extends <Feature>Action { const NameChanged(this.value); final String value; }
class ContinueTapped extends <Feature>Action { const ContinueTapped(); }

// Async-result deliveries
class ItemsLoaded extends <Feature>Action { const ItemsLoaded(this.items); final IList<Item> items; }
class ItemsLoadFailed extends <Feature>Action { const ItemsLoadFailed(this.error); final FeatureFailure error; }
```

**`<Feature>Effect`** — the core architectural type. Sealed family of
async-work descriptors returned by the updater and consumed by the
shell.

```dart
sealed class <Feature>Effect { const <Feature>Effect(); }

class LoadItemsEffect extends <Feature>Effect { const LoadItemsEffect(); }
class SaveItemEffect extends <Feature>Effect {
  const SaveItemEffect(this.item); final Item item;
}
```

**`<Feature>UiEffect`** — UI-only specialization. Sealed family of
one-shot effects the shell pushes for the View to consume (navigation,
snackbars, dialogs, controller-managed `TextEditingController` syncs).

```dart
sealed class <Feature>UiEffect { const <Feature>UiEffect(); }

class <Feature>PopUiEffect extends <Feature>UiEffect { const <Feature>PopUiEffect(); }
class <Feature>ShowErrorUiEffect extends <Feature>UiEffect {
  const <Feature>ShowErrorUiEffect(this.message); final <Feature>UiMessage message;
}
class <Feature>FinishedUiEffect extends <Feature>UiEffect { const <Feature>FinishedUiEffect(); }
```

**Case-naming asymmetry — read carefully:**

- `Action` cases: `<Name>` (e.g. `NameChanged`, `ContinueTapped`,
  `ItemsLoaded`). **No `Action` suffix, no `<Feature>` prefix.**
- `Effect` cases: `<Name>Effect` (e.g. `LoadItemsEffect`,
  `SaveItemEffect`). **No `<Feature>` prefix.** Effects are scoped to
  the feature folder and are never imported across features.
- `UiEffect` cases: `<Feature><Name>UiEffect` (e.g.
  `OnboardShowErrorUiEffect`). **The `<Feature>` prefix IS required on
  UiEffect cases** — they cross the feature boundary into UI code that
  may handle effects from multiple features (navigation, shared snackbar
  plumbing, etc.) and need the prefix at the call site for
  disambiguation.

The sealed parents always carry the feature prefix (`<Feature>Action`,
`<Feature>Effect`, `<Feature>UiEffect`).

### 6.5 `<Feature>Updater` — class form

When the updater needs private helpers, sub-reducers, or internal types,
extract a `<Feature>Updater` class instead of leaving helpers as
top-level functions cluttering the file:

```dart
// lib/features/<feature>/presentation/<feature>_update.dart
class <Feature>Updater {
  const <Feature>Updater();

  (<Feature>State, List<<Feature>Effect>?) update(
    <Feature>State state,
    <Feature>Action action,
  ) {
    switch (action) {
      case Foo(:final x):
        return _onFoo(state, x);
      case BarPressed():
        return _onBar(state);
      // …
    }
  }

  (<Feature>State, List<<Feature>Effect>?) _onFoo(<Feature>State state, X x) {
    // private helper, not visible to the controller or anyone else
  }

  (<Feature>State, List<<Feature>Effect>?) _onBar(<Feature>State state) {
    if (_isValid(state)) {
      return (state, const [SaveFooEffect()]);
    }
    return (state.copyWith(error: 'invalid'), null);
  }

  bool _isValid(<Feature>State state) { /* … */ return true; }
}
```

**When to use each form:**

- Top-level `update` function — default for simple updaters (handful of
  cases, no shared helpers, no internal types).
- `<Feature>Updater` class — as soon as the updater needs private
  helpers / sub-reducers / encapsulation. Don't wait for the file to
  become unmaintainable.

Both forms are equivalent in test-friendliness: the function is called
directly; the class is `const`-constructible and exposes a single
`update` method.

### 6.6 The imperative shell

```dart
Future<void> _runEffect(<Feature>Effect effect) async {
  switch (effect) {
    case LoadItemsEffect():
      final result = await _itemsRepo.fetchAll();
      result.onTap(
        (items) => dispatch(ItemsLoaded(items)),
        (error) => dispatch(ItemsLoadFailed(error)),
      );
    case SaveItemEffect(:final item):
      final result = await _itemsRepo.save(item);
      result.onFailure((error) => dispatch(SaveItemFailed(error)));
    case ShowErrorEffect(:final message):
      _effectEmitter.push(<Feature>ShowErrorUiEffect(message));
  }
}
```

**MUST in the shell:**

- Exhaustively switch on the sealed `Effect`.
- Unwrap `Result` at the seam: dispatch a success-Action or a
  failure-Action; do not propagate `Result` into the updater
  ([Result pattern §9.3](result.md)).
- Push `UiEffect`s here, never from the updater.

### 6.7 The View consumes everything

> **inline-FCIS shape.** The View below owns a `ValueNotifier<State>` and
> calls `onViewAttach`/`onViewDetach` — the legacy form. A fcis_core
> View binds `ValueListenableBuilder(valueListenable:
> controller.stateHolder, …)` and calls `onAttach`/`onDetach` (§6.8).

```dart
class <Feature>Page extends StatefulWidget { /* … */ }

class _<Feature>PageState extends State<<Feature>Page> {
  <Feature>Controller get _controller => <Feature>Scope.controller;
  late final ValueNotifier<<Feature>State> _stateNotifier;

  @override
  void initState() {
    super.initState();
    _stateNotifier = ValueNotifier<<Feature>State>(const <Feature>State());
    _controller
      ..onViewAttach(
        getter: () => _stateNotifier.value,
        updater: (s) => _stateNotifier.value = s,
        pusher: _onUiEffect,
      )
      ..dispatch(const InitialLoad());
  }

  @override
  void dispose() {
    _controller.onViewDetach();
    _stateNotifier.dispose();
    super.dispose();
  }

  void _onUiEffect(<Feature>UiEffect effect) {
    if (!mounted) return;
    switch (effect) {
      case <Feature>PopUiEffect():
        Navigator.of(context).maybePop();
      case <Feature>ShowErrorUiEffect(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_uiMessage(message))),
        );
      case <Feature>FinishedUiEffect():
        Navigator.of(context).pushReplacement(NextPage.route());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<bool>(
      listenable: _stateNotifier,
      selector: (_) => _stateNotifier.value.isLoading,
      builder: (context, isLoading, child) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () => _controller.dispatch(const ContinueTapped()),
            child: const Text('Continue'),
          ),
        );
      },
    );
  }
}
```

`Selector<T>` (`lib/core/presentation/selector.dart`) is the
performance primitive: it listens to a `Listenable` (here the
`ValueNotifier<State>`) and rebuilds only when the projected value
changes (deep equality).

### 6.8 Realizing FCIS with `package:fcis_core` (canonical for new code)

New features do NOT hand-roll the `dispatch` / `_runEffect` loop on a
fat controller. They compose the shared **`package:fcis_core`** runtime.
The pure updater and effect/shell split of §6.1–6.7 are unchanged;
fcis_core just provides the runtime that drives them.

**Package API:**

- `Updater<S, A, E>` — abstract, `const`. Single method
  `(S, List<E>?) update(S, A)`. This is the §6 pure updater.
- `Shell<E, A>` — abstract. `Future<void> run(E effect, {required void
  Function(A) dispatch})`. This is the §6.6 imperative shell, extracted
  off the controller into its own class.
- `FcisLoop<S, A, E>({stateHolder, updater, effectRunner})` — the loop.
  **Implements `ActionSink<A>`**, so the loop instance *is* the sink the
  controller and signals dispatch into.
- `ShellEffectRunner<E, A>({required Shell shell})` — adapts a `Shell`
  into the loop's `effectRunner`.
- `StateHolder<S>` / `ActionSink<A>` — the loop's state + dispatch
  interfaces.
- Flutter glue: `ValueListenableStateHolder<S>`
  (`lib/core/fcis_flutter/`) extends `ValueNotifier<S>` implements
  `StateHolder<S>` — the View binds it via `ValueListenableBuilder`.
- UI effects ride `EffectEmitter<UiEffect>` / `EffectPusher`
  ([Cross-feature seams §4](cross_feature.md)), pushed from the Shell.

**Per-feature presentation files** (replacing the single fat controller):

| File | Class | Role |
|---|---|---|
| `<feature>_updater.dart` | `<F>Updater implements Updater<…>` | `const`, pure `update()` switch. `ViewAttached` lifecycle action returns the initial-load effect; `DeactivateFeature` is a no-op. Inline helpers become private methods. |
| `<feature>_shell.dart` | `<F>Shell extends Shell<…>` | ctor with injected deps incl. an injected `package:logging` `Logger` (the module defaults it to `Logger('<app>.<feature>')`; tests pass their own to assert/mute). Ping-pongs async results back via `dispatch(Action)`; pushes UI effects via injected `EffectEmitter`. Log catches as `severe`, never swallow (`(e, st)`). |
| `<feature>_fcis_loop.dart` | `<F>FcisLoop extends FcisLoop<…>` | super-params only, no logic. |
| `<feature>_controller.dart` | `<F>Controller` | **thin.** Holds public `stateHolder`, `_effectEmitter`, `_sink` (`ActionSink`), signals. `onAttach(pusher)` = effectEmitter.attach + signals.bind; `onDetach()` = signals.unbind + effectEmitter.detach; `dispatch` delegates to `_sink`. |
| `<feature>_module.dart` | `<F>Module` | composition root. Takes external deps; `late final` wires stateHolder → effectEmitter → shell → loop(sink) → signal → controller; exposes `.controller`. |

Channel/stream listeners become bind/unbind **Signal** classes (map a
foreign event → a feature Action), wired through the controller's
`onAttach` / `onDetach`. For cross-feature / external sources, prefer the
external-signal lifecycle ([Cross-feature seams §1](cross_feature.md)).

**Wiring.** Each lazily-initialized repository holds a
`late final <F>Module _module = <F>Module(…deps…)` field; the Scope
factory becomes `<F>Scope.setFactory(() => _module.controller)`.

**View.** `initState`: `_controller..onAttach(_onUiEffect)..dispatch(const
ViewAttached())`. `dispose`: `_controller..dispatch(const
DeactivateFeature())..onDetach()`. Subscribe via
`ValueListenableBuilder(valueListenable: _controller.stateHolder, …)`.
Dispatch Actions directly — no per-intent wrappers (§5.3).

**Naming.** New features MUST use the §6.4 naming: `<F>Effect` for core
async effects, `<F>UiEffect` for UI-only effects. (Some legacy features
use an inverted `<F>ShellEffect` / `<F>Effect` split; do not copy it.)
