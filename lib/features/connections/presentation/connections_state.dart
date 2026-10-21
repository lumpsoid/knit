import 'package:flutter/foundation.dart';
import 'package:knit/features/connections/domain/connections_models.dart';
import 'package:knit/features/connections/domain/unlinked_mentions.dart';

enum ConnectionsStatus { loading, ready, failed }

/// State for the Connections view (§4.4). [breadcrumb] is the back-stack from
/// the root entity to the current focus (`breadcrumb.last`); [data] is the
/// loaded payload for that focus. Jumping a connection pushes a crumb; tapping a
/// crumb truncates the stack — so "deep wandering doesn't lose you" is modelled
/// here, not in the navigator. [mentions] is the collection focus's
/// "Mentioned in" list (§8.6.5), loaded after [data]; null until then, and for
/// a card focus.
@immutable
class ConnectionsState {
  const ConnectionsState({
    this.status = ConnectionsStatus.loading,
    this.breadcrumb = const [],
    this.data,
    this.mentions,
  });

  final ConnectionsStatus status;
  final List<ConnectionCrumb> breadcrumb;
  final ConnectionsData? data;
  final UnlinkedMentions? mentions;

  /// True once the root focus is the only crumb — the app-bar back then exits
  /// the feature rather than popping a hop.
  bool get atRoot => breadcrumb.length <= 1;

  bool get isEmpty => (data?.isEmpty ?? true) && (mentions?.isEmpty ?? true);

  /// [clearMentions] drops the mention list (the focus moved).
  ConnectionsState copyWith({
    ConnectionsStatus? status,
    List<ConnectionCrumb>? breadcrumb,
    ConnectionsData? data,
    UnlinkedMentions? mentions,
    bool clearMentions = false,
  }) => ConnectionsState(
    status: status ?? this.status,
    breadcrumb: breadcrumb ?? this.breadcrumb,
    data: data ?? this.data,
    mentions: clearMentions ? null : mentions ?? this.mentions,
  );
}
