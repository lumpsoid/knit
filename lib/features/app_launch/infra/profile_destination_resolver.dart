import 'package:knit/app/app_graph.dart';
import 'package:knit/features/app_launch/domain/app_destination.dart';
import 'package:knit/sync/sync.dart';

/// Routes first-run users into onboarding and returning users into the timeline
/// (composition.md §3). First-run = no device identity yet, or an identity
/// without a published `profile` record (the onboarding ceremony writes both;
/// a half-finished run resumes at onboarding). Reads the graph's store, which
/// exists because `resolve()` runs only post-init.
class ProfileAppDestinationResolver implements AppDestinationResolver {
  ProfileAppDestinationResolver({required AppGraph graph}) : _graph = graph;

  final AppGraph _graph;

  @override
  Future<AppLaunchDestination> resolve() async {
    final store = _graph.store;
    if (!await store.hasIdentity()) return AppLaunchDestination.onboarding;

    final pubkey = await store.authorPubkey();
    final profile = await store.get(EntityType.profile, pubkey);
    if (profile == null || profile.deleted) {
      return AppLaunchDestination.onboarding;
    }
    return AppLaunchDestination.timeline;
  }
}
