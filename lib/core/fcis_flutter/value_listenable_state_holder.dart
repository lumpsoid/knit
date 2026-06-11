import 'package:fcis_core/fcis_core.dart';
import 'package:flutter/foundation.dart';

/// The Flutter glue between `package:fcis_core`'s [StateHolder] and the widget
/// tree (fcis.md §6.8). A [ValueNotifier] the loop writes via [update] and the
/// View binds with `ValueListenableBuilder(valueListenable: …)`.
class ValueListenableStateHolder<S> extends ValueNotifier<S>
    implements StateHolder<S> {
  ValueListenableStateHolder(super.value);

  @override
  S get state => value;

  @override
  void update(S next) => value = next;
}
