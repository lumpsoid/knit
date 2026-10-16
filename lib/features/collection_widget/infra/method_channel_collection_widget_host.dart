import 'dart:async';

import 'package:flutter/services.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_failure.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_host.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_models.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_request.dart';
import 'package:knit/features/collection_widget/domain/collection_widget_request_source.dart';
import 'package:result_dart/result_dart.dart';

/// The Android home-screen widget over the `knit/collection_widget` method
/// channel (`CollectionWidgetChannel.kt`). One adapter serves both ports:
/// requests flow in (a tapped or newly placed widget), bindings and tiles flow
/// out (the native provider redraws from what it is handed).
class MethodChannelCollectionWidgetHost
    implements CollectionWidgetHost, CollectionWidgetRequestSource {
  MethodChannelCollectionWidgetHost({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handle);
  }

  static const String channelName = 'knit/collection_widget';

  final MethodChannel _channel;
  final StreamController<CollectionWidgetRequest> _requests =
      StreamController.broadcast();

  Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'request') return null;
    final request = parseRequest(call.arguments);
    if (request != null) _requests.add(request);
    return null;
  }

  @override
  Future<CollectionWidgetRequest?> initial() async =>
      parseRequest(await _channel.invokeMethod<Object?>('initialRequest'));

  @override
  Stream<CollectionWidgetRequest> get requests => _requests.stream;

  @override
  Future<Result<List<CollectionWidgetBinding>, CollectionWidgetFailure>>
  bindings() async {
    try {
      final raw = await _channel.invokeListMethod<Object?>('bindings') ?? [];
      return Ok([
        for (final entry in raw.whereType<Map<Object?, Object?>>())
          if (entry['widgetId'] case final int widgetId)
            CollectionWidgetBinding(
              widgetId: widgetId,
              collectionId: entry['collectionId'] as String?,
            ),
      ]);
    } catch (e, st) {
      return Failure(CollectionWidgetHostFailure(e, st));
    }
  }

  @override
  Future<Result<void, CollectionWidgetFailure>> bind(
    int widgetId,
    CollectionWidgetTarget target,
  ) => _invoke('bind', {
    'widgetId': widgetId,
    'collectionId': target.collectionId,
    'title': target.title,
  });

  @override
  Future<Result<void, CollectionWidgetFailure>> publish(
    List<CollectionWidgetTile> tiles,
  ) => _invoke('publish', [
    for (final t in tiles)
      {'widgetId': t.widgetId, 'title': t.title, 'removed': t.removed},
  ]);

  @override
  Future<void> returnToHomeScreen() async {
    await _channel.invokeMethod<void>('returnToHomeScreen');
  }

  Future<Result<void, CollectionWidgetFailure>> _invoke(
    String method,
    Object arguments,
  ) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
      return const Ok<void, CollectionWidgetFailure>(null);
    } catch (e, st) {
      return Failure(CollectionWidgetHostFailure(e, st));
    }
  }

  /// Decode a request map from the platform — `{type: open, collectionId}` or
  /// `{type: configure, widgetId}`; anything else is null.
  static CollectionWidgetRequest? parseRequest(Object? raw) {
    if (raw is! Map) return null;
    return switch ((raw['type'], raw['collectionId'], raw['widgetId'])) {
      ('open', final String id, _) when id.isNotEmpty => OpenCollectionRequest(
        id,
      ),
      ('configure', _, final int widgetId) => ConfigureWidgetRequest(widgetId),
      _ => null,
    };
  }
}
