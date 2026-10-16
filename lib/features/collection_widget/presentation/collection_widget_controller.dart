import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_failure.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_host.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_read_repository.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_request.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_request_source.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_tile_planner.dart';
import 'package:knit/features/collection_widget/presentation/collection_widget_state.dart';
import 'package:logging/logging.dart';
import 'package:result_dart/result_dart.dart';

/// The app-wide owner of the home-screen collection widgets (Android).
///
/// Collects widget taps into [state], where the [CollectionWidgetGate] of the
/// current page picks them up with [take]. Once [attach]ed (the graph is up
/// and an identity exists) it keeps every placed widget's tile current: it
/// re-publishes whenever [headerChanges] fires (a rename) and whenever the
/// gate calls [refreshTiles] (the app leaves the foreground — which catches
/// deletes, restores and wipes too).
class CollectionWidgetController {
  CollectionWidgetController({
    required CollectionWidgetRequestSource source,
    required CollectionWidgetHost host,
    required CollectionWidgetReadRepository readRepository,
    required Listenable headerChanges,
    CollectionWidgetTilePlanner planner = const CollectionWidgetTilePlanner(),
    Logger? logger,
  }) : _source = source,
       _host = host,
       _read = readRepository,
       _headerChanges = headerChanges,
       _planner = planner,
       _log = logger ?? Logger('knit.collection_widget');

  final CollectionWidgetRequestSource _source;
  final CollectionWidgetHost _host;
  final CollectionWidgetReadRepository _read;
  final Listenable _headerChanges;
  final CollectionWidgetTilePlanner _planner;
  final Logger _log;

  final CollectionWidgetState state = CollectionWidgetState();

  StreamSubscription<CollectionWidgetRequest>? _subscription;
  bool _attached = false;

  /// The tiles last handed to the host — an unchanged plan isn't re-sent.
  List<CollectionWidgetTile>? _published;
  Future<void>? _refreshing;
  bool _refreshAgain = false;

  /// Start listening for warm taps, then read the cold-start one.
  Future<void> start() async {
    _subscription ??= _source.requests.listen(
      state.offer,
      onError: (Object e, StackTrace st) =>
          _log.severe('receiving a widget request failed', e, st),
    );
    try {
      final initial = await _source.initial();
      if (initial != null) state.offer(initial);
    } catch (e, st) {
      _log.severe('reading the launch widget request failed', e, st);
    }
  }

  /// Take the pending request (null when there is none).
  CollectionWidgetRequest? take() => state.take();

  /// Start keeping the tiles current; publishes them once now.
  void attach() {
    if (_attached) return;
    _attached = true;
    _headerChanges.addListener(_onHeaderChange);
    unawaited(refreshTiles());
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    _headerChanges.removeListener(_onHeaderChange);
  }

  void _onHeaderChange() => unawaited(refreshTiles());

  /// Re-read every bound collection and redraw the widgets whose tile changed.
  /// Calls made while one runs fold into a single follow-up run.
  Future<void> refreshTiles() {
    if (!_attached) return Future.value();
    final running = _refreshing;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    return _refreshing = _refreshLoop().whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshLoop() async {
    do {
      _refreshAgain = false;
      await _refreshOnce();
    } while (_refreshAgain);
  }

  Future<void> _refreshOnce() async {
    final bindings = switch (await _host.bindings()) {
      Ok(:final value) => value,
      Failure(:final error) => _logFailure('reading the widgets', error),
    };
    if (bindings == null) return;
    final titles = switch (await _read.liveTitles(
      _planner.boundIds(bindings),
    )) {
      Ok(:final value) => value,
      Failure(:final error) => _logFailure('reading the bound titles', error),
    };
    if (titles == null) return;
    final tiles = _planner.plan(bindings, titles);
    if (listEquals(tiles, _published)) return;
    switch (await _host.publish(tiles)) {
      case Ok():
        _published = tiles;
      case Failure(:final error):
        _logFailure('publishing the widget tiles', error);
    }
  }

  /// Whether [collectionId] is still a live collection. A gone one also
  /// refreshes the tiles, so its widget shows the removed state.
  Future<bool> isLive(String collectionId) async {
    final result = await _read.liveTitles({collectionId});
    switch (result) {
      case Ok(:final value) when value.containsKey(collectionId):
        return true;
      case Ok():
        unawaited(refreshTiles());
        return false;
      case Failure(:final error):
        _logFailure('reading the tapped collection', error);
        return false;
    }
  }

  /// Configuring ended — back to the home screen the widget lives on.
  Future<void> returnToHomeScreen() async {
    try {
      await _host.returnToHomeScreen();
    } catch (e, st) {
      _log.severe('returning to the home screen failed', e, st);
    }
  }

  Null _logFailure(String what, CollectionWidgetFailure failure) {
    _log.severe('$what failed', failure.error, failure.stackTrace);
    return null;
  }

  void dispose() {
    detach();
    unawaited(_subscription?.cancel());
    state.dispose();
  }
}
