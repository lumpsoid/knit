/// Handler the View registers to receive one-shot effects.
typedef EffectPusher<T> = void Function(T effect);

/// Emits one-time side effects (events) from a controller/shell to the UI
/// layer without a direct dependency on the UI.
///
/// Use cases: navigation (push/pop/replace), snackbars, dialogs, bottom
/// sheets, loading/error notifications.
///
/// One-shot fire-and-forget: it does **not** buffer — effects pushed while no
/// handler is attached are dropped. `UiEffect`s are pushed from the shell only,
/// never the updater (FCIS §6.3).
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

/// Legacy alias for [EffectPusher]; the seam was once `SideEffector`. Use
/// [EffectPusher] in all new code (cross_feature.md §4).
@Deprecated('Use EffectPusher')
typedef SideEffectPusher<T> = void Function(T effect);

/// Legacy alias for [EffectEmitter]; renamed from `SideEffector`. Use
/// [EffectEmitter] in all new code (cross_feature.md §4).
@Deprecated('Use EffectEmitter')
typedef SideEffector<T> = EffectEmitter<T>;
