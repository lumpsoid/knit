import 'dart:async';

import 'package:knit/features/collection_widget/domain/domain.dart';
import 'package:result_dart/result_dart.dart';

class FakeRequestSource implements CollectionWidgetRequestSource {
  FakeRequestSource({this.launch});

  CollectionWidgetRequest? launch;
  final StreamController<CollectionWidgetRequest> warm =
      StreamController.broadcast();

  @override
  Future<CollectionWidgetRequest?> initial() async {
    final request = launch;
    launch = null;
    return request;
  }

  @override
  Stream<CollectionWidgetRequest> get requests => warm.stream;
}

class FakeHost implements CollectionWidgetHost {
  List<CollectionWidgetBinding> placed = [];
  final List<List<CollectionWidgetTile>> published = [];
  final Map<int, CollectionWidgetTarget> bound = {};
  int returnedHome = 0;
  bool failBind = false;

  @override
  Future<Result<List<CollectionWidgetBinding>, CollectionWidgetFailure>>
  bindings() async => Ok(placed);

  @override
  Future<Result<void, CollectionWidgetFailure>> bind(
    int widgetId,
    CollectionWidgetTarget target,
  ) async {
    if (failBind) return Failure(CollectionWidgetHostFailure('nope'));
    bound[widgetId] = target;
    return const Ok<void, CollectionWidgetFailure>(null);
  }

  @override
  Future<Result<void, CollectionWidgetFailure>> publish(
    List<CollectionWidgetTile> tiles,
  ) async {
    published.add(tiles);
    return const Ok<void, CollectionWidgetFailure>(null);
  }

  @override
  Future<void> returnToHomeScreen() async => returnedHome++;
}

class FakeRead implements CollectionWidgetReadRepository {
  /// Live collections: id → title, in timeline order.
  Map<String, String> live = {};
  bool failTargets = false;

  @override
  Future<Result<List<CollectionWidgetTarget>, CollectionWidgetFailure>>
  loadTargets() async {
    if (failTargets) return Failure(CollectionWidgetLoadFailure('boom'));
    return Ok([
      for (final e in live.entries)
        CollectionWidgetTarget(collectionId: e.key, title: e.value),
    ]);
  }

  @override
  Future<Result<Map<String, String>, CollectionWidgetFailure>> liveTitles(
    Set<String> collectionIds,
  ) async => Ok({for (final id in collectionIds) id: ?live[id]});
}
