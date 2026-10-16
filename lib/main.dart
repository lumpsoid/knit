import 'dart:developer' as developer;

import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:knit/l10n/app_localizations.dart';
import 'package:knit/app/app_config.dart';
import 'package:knit/app/app_graph.dart';
import 'package:knit/app/composition.dart';
import 'package:knit/core/attachments/attachments.dart';
import 'package:knit/core/ids/uuid_id_generator.dart';
import 'package:knit/features/backup/infra/file_picker_backup_save_port.dart';
import 'package:knit/features/backup/infra/file_picker_backup_source_port.dart';
import 'package:knit/features/backup/infra/share_plus_backup_delivery_port.dart';
import 'package:knit/features/backup/infra/sync_store_backup_export_repository.dart';
import 'package:knit/features/backup/infra/sync_store_backup_import_repository.dart';
import 'package:knit/features/app_launch/presentation/app_launch_module.dart';
import 'package:knit/features/app_launch/presentation/app_launch_page.dart';
import 'package:knit/features/app_launch/presentation/app_launch_scope.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_links_read_repository.dart';
import 'package:knit/features/card_edit/infra/sync_store_card_edit_write_repository.dart';
import 'package:knit/features/card_edit/presentation/card_edit_module.dart';
import 'package:knit/features/card_edit/presentation/card_edit_route_args.dart';
import 'package:knit/features/card_edit/presentation/card_edit_scope.dart';
import 'package:knit/features/card_links/infra/sync_store_card_links_write_repository.dart';
import 'package:knit/features/card_links/infra/sync_store_link_targets_read_repository.dart';
import 'package:knit/features/card_links/presentation/card_links_controller.dart';
import 'package:knit/features/collection/infra/share_plus_card_share_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_read_repository.dart';
import 'package:knit/features/collection/infra/sync_store_collection_write_repository.dart';
import 'package:knit/features/collection/infra/url_launcher_link_launcher.dart';
import 'package:knit/features/collection/presentation/audio_playback_controller.dart';
import 'package:knit/features/collection/presentation/collection_controller.dart';
import 'package:knit/features/collection/presentation/collection_route_args.dart';
import 'package:knit/features/collection/presentation/collection_scope.dart';
import 'package:knit/features/collection_details/infra/sync_store_collection_details_write_repository.dart';
import 'package:knit/features/collection_details/presentation/collection_details_controller.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_module.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_route_args.dart';
import 'package:knit/features/collection_edit/presentation/collection_edit_scope.dart';
import 'package:knit/features/collection_media/infra/sync_store_collection_media_read_repository.dart';
import 'package:knit/features/collection_media/presentation/collection_media_module.dart';
import 'package:knit/features/collection_media/presentation/collection_media_route_args.dart';
import 'package:knit/features/collection_media/presentation/collection_media_scope.dart';
import 'package:knit/features/connections/infra/sync_store_connections_read_repository.dart';
import 'package:knit/features/connections/presentation/connections_controller.dart';
import 'package:knit/features/connections/presentation/connections_route_args.dart';
import 'package:knit/features/connections/presentation/connections_scope.dart';
import 'package:knit/features/onboard/infra/sync_store_onboard_repository.dart';
import 'package:knit/features/onboard/presentation/onboard_module.dart';
import 'package:knit/features/onboard/presentation/onboard_scope.dart';
import 'package:knit/features/profile/infra/sync_store_profile_read_repository.dart';
import 'package:knit/features/search/infra/sync_store_search_read_repository.dart';
import 'package:knit/features/search/presentation/search_controller.dart';
import 'package:knit/features/profile/infra/sync_store_profile_write_repository.dart';
import 'package:knit/features/profile/presentation/profile_module.dart';
import 'package:knit/features/profile/presentation/profile_scope.dart';
import 'package:knit/features/settings/domain/app_preferences.dart';
import 'package:knit/features/settings/infra/shared_preferences_settings_repository.dart';
import 'package:knit/features/settings/infra/sync_store_settings_wipe_repository.dart';
import 'package:knit/features/settings/presentation/settings_action.dart';
import 'package:knit/features/settings/presentation/settings_module.dart';
import 'package:knit/features/settings/presentation/settings_scope.dart';
import 'package:knit/features/settings/presentation/settings_state.dart';
import 'package:knit/features/sync_status/infra/sync_store_sync_status_read_repository.dart';
import 'package:knit/features/sync_status/presentation/sync_status_module.dart';
import 'package:knit/features/sync_status/presentation/sync_status_scope.dart';
import 'package:knit/features/timeline/infra/shared_preferences_timeline_pin_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_repository.dart';
import 'package:knit/features/timeline/infra/sync_store_timeline_write_repository.dart';
import 'package:knit/features/timeline/infra/timeline_channel_notifier.dart';
import 'package:knit/features/timeline/presentation/timeline_module.dart';
import 'package:knit/features/timeline/presentation/timeline_scope.dart';

/// Default entry point. Real builds use the flavor entry points
/// (`lib/main_dev.dart` / `main_staging.dart` / `main_prod.dart`), each of
/// which calls [bootstrap] with its [Flavor]'s config; this convenience `main`
/// boots the dev flavor so `flutter run -t lib/main.dart --flavor dev` works.
void main() => bootstrap(Flavor.dev.config);

/// Wires the composition root for [config] and runs the app. Pure of flavor
/// selection — the entry points pick the [AppConfig]; this builds the graph
/// from it (composition.md §2).
void bootstrap(AppConfig config) {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition routes the single package:logging stream: every layer logs to
  // a named Logger; here we drain Logger.root.onRecord into the Flutter/IDE
  // console (via dart:developer). Other consumers can subscribe to react.
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      name: record.loggerName,
      level: record.level.value,
      time: record.time,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  // composition.md §2 — [config] is the immutable graph selector handed in by
  // the flavor entry point: dev runs the in-memory graph (any platform, no
  // SQLite), staging/prod the persistent sqflite graph (one DB file per device).
  final graph = AppGraph();

  // App Launch hosts the only eagerly-built controller: it drives init, then
  // resolves where to go (composition.md §3).
  AppLaunchScope.setController(
    AppLaunchModule(
      initialization: resolveInitializationRepository(config, graph),
      destinationResolver: resolveAppDestinationResolver(config, graph),
    ).controller,
  );

  // Downstream features (fcis.md §6.8 wiring): the Scope factories capture the
  // graph and read its store lazily — only ever after init completes, which the
  // destination resolver guarantees.
  OnboardScope.setFactory(
    () => OnboardModule(
      repository: SyncStoreOnboardRepository(graph: graph),
    ).controller,
  );

  // The app-wide sync marker (§4.8/§6.6): a single lazy controller every
  // content page's app bar shares via SyncStatusScope.
  SyncStatusScope.setFactory(
    () => SyncStatusModule(
      readRepository: SyncStoreSyncStatusReadRepository(graph: graph),
    ).controller,
  );

  // The Profile screen (§5/§7.4.7): reads the device identity and edits the
  // nickname through a signed `profile` edit. Reached from the Timeline app bar.
  ProfileScope.setFactory(
    () => ProfileModule(
      readRepository: SyncStoreProfileReadRepository(graph: graph),
      writeRepository: SyncStoreProfileWriteRepository(graph: graph),
    ).controller,
  );

  // App-wide UI preferences (theme + language, §4 settings): one shared, lazily
  // built controller the root [KnitApp] observes and every settings page uses.
  // Persisted in shared_preferences — device-local config, not synced graph
  // data — so it's wired here regardless of the AppConfig graph selection.
  // The Timeline input channel (cross_feature.md §3): one shared instance — the
  // Collection and Settings (and any future feature) emit a RefreshChannelEvent
  // after a write/restore/wipe; the Timeline observes it and re-reads the home
  // feed. The producer gets the emitter half, the consumer the reader half.
  final timelineChannel = TimelineChannelNotifier();

  const settingsRepository = SharedPreferencesSettingsRepository();
  SettingsScope.setFactory(
    () => SettingsModule(
      readRepository: settingsRepository,
      writeRepository: settingsRepository,
      // The Data subpage wipe (§4 danger zone): truncate the store + blobs,
      // keeping the device identity.
      wipeRepository: SyncStoreSettingsWipeRepository(graph: graph),
      // The Data subpage export/import (§4): bundle the signed log + blobs to a
      // .zip and share it; pick a .zip and replay it back through the store.
      backupExportRepository: SyncStoreBackupExportRepository(graph: graph),
      backupImportRepository: SyncStoreBackupImportRepository(graph: graph),
      backupDeliveryPort: const SharePlusBackupDeliveryPort(),
      backupSavePort: const FilePickerBackupSavePort(),
      backupSourcePort: const FilePickerBackupSourcePort(),
      // A restore or wipe changes the home feed — emit into the Timeline channel.
      timelineChannel: timelineChannel,
    ).controller,
  );

  // The route-args carrier (cross_feature.md §2): Timeline writes the target
  // collection, the Collection page reads it on entry.
  final routeArgs = InMemoryCollectionRouteArgsStore();
  TimelineScope.setRouteArgsWriter(routeArgs);
  CollectionScope.setRouteArgs(routeArgs);
  // Search (§3.2/§4.1), opened from the Timeline app bar: a fresh controller
  // per page; a tapped hit writes the same carrier (with the card to reveal).
  TimelineScope.setSearchFactory(
    () => SearchController(
      readRepository: SyncStoreSearchReadRepository(graph: graph),
      collectionRouteArgs: routeArgs,
    ),
  );
  // The Connections view writes the same carrier to open a connected item
  // inside its collection (§4.2/§4.4) before navigating to the Collection page.
  ConnectionsScope.setCollectionRouteArgsWriter(routeArgs);

  // A second carrier for the Connections view (§4.4): the Collection page writes
  // the focused card/collection, the Connections page reads it on entry.
  final connectionsRouteArgs = InMemoryConnectionsRouteArgsStore();
  CollectionScope.setConnectionsRouteArgsWriter(connectionsRouteArgs);
  ConnectionsScope.setRouteArgs(connectionsRouteArgs);

  // A third carrier for the Card Edit page (§4.3): the Collection page writes the
  // card to edit, the Card Edit page reads it on entry.
  final cardEditRouteArgs = InMemoryCardEditRouteArgsStore();
  CollectionScope.setCardEditRouteArgsWriter(cardEditRouteArgs);
  CardEditScope.setRouteArgs(cardEditRouteArgs);

  // A fourth carrier for the Collection Edit page (§4.2): the Collection page
  // writes the collection to edit, the Collection Edit page reads it on entry.
  final collectionEditRouteArgs = InMemoryCollectionEditRouteArgsStore();
  CollectionScope.setCollectionEditRouteArgsWriter(collectionEditRouteArgs);
  CollectionEditScope.setRouteArgs(collectionEditRouteArgs);

  // A fifth carrier for the Collection Media overview (§4.2): the Collection
  // Edit page writes the collection, the Media page reads it on entry. A
  // long-press there opens the item's card through the Card Edit carrier.
  final collectionMediaRouteArgs = InMemoryCollectionMediaRouteArgsStore();
  CollectionEditScope.setMediaRouteArgsWriter(collectionMediaRouteArgs);
  CollectionMediaScope.setRouteArgs(collectionMediaRouteArgs);
  CollectionMediaScope.setCardEditRouteArgsWriter(cardEditRouteArgs);

  // Id minting behind the IdGenerator port (spec §6.1).
  const ids = UuidIdGenerator();

  // The shared decoded-image cache: one bounded copy of each attachment image
  // for every page that renders one (covers, card thumbnails, media grid).
  final imageCache = AttachmentImageCache(
    attachmentReadRepository: SyncStoreAttachmentReadRepository(graph: graph),
  );
  TimelineScope.setImages(imageCache.state);
  CollectionScope.setImages(imageCache.state);
  CollectionEditScope.setImages(imageCache.state);
  CollectionMediaScope.setImages(imageCache.state);
  CardEditScope.setImages(imageCache.state);

  // The shared collection headers (title, description, cover — §3.1): one
  // app-wide controller the Timeline, the Collection screen and the Collection
  // Edit page all read, and every header edit goes through.
  final collectionDetails = CollectionDetailsController(
    writeRepository: SyncStoreCollectionDetailsWriteRepository(graph: graph),
    attachmentWriteRepository: SyncStoreAttachmentWriteRepository(
      graph: graph,
      ids: ids,
    ),
  );
  TimelineScope.setCollectionDetails(collectionDetails.state);
  CollectionScope.setCollectionDetails(collectionDetails.state);
  CollectionEditScope.setCollectionDetails(collectionDetails.state);

  // The shared card links (§4.4): one app-wide controller owning the link
  // picker the Collection screen and Card Edit open, and every link write —
  // including the Connections view clearing a broken link.
  final cardLinks = CardLinksController(
    readRepository: SyncStoreLinkTargetsReadRepository(graph: graph),
    writeRepository: SyncStoreCardLinksWriteRepository(graph: graph, ids: ids),
  );
  CollectionScope.setCardLinks(cardLinks);
  CardEditScope.setCardLinks(cardLinks);

  // Pinned collections (§4.1): a device-local view preference, persisted in
  // shared_preferences like Settings — never synced or signed.
  const timelinePins = SharedPreferencesTimelinePinRepository();
  TimelineScope.setFactory(
    () => TimelineModule(
      readRepository: SyncStoreTimelineRepository(graph: graph),
      writeRepository: SyncStoreTimelineWriteRepository(graph: graph, ids: ids),
      pinReadRepository: timelinePins,
      pinWriteRepository: timelinePins,
      imageCache: imageCache,
      collectionDetails: collectionDetails,
      channelReader: timelineChannel,
    ).controller,
  );
  CollectionScope.setFactory(
    () => CollectionController(
      readRepository: SyncStoreCollectionReadRepository(graph: graph),
      writeRepository: SyncStoreCollectionWriteRepository(
        graph: graph,
        ids: ids,
      ),
      attachmentReadRepository: SyncStoreAttachmentReadRepository(graph: graph),
      attachmentWriteRepository: SyncStoreAttachmentWriteRepository(
        graph: graph,
        ids: ids,
      ),
      imageCache: imageCache,
      imagePicker: ImagePickerAdapter(),
      audioRecorder: RecordAudioRecorder(),
      filePicker: const FilePickerAdapter(),
      shareRepository: const SharePlusCardShareRepository(),
      linkLauncher: const UrlLauncherLinkLauncher(),
      collectionDetails: collectionDetails,
      cardLinks: cardLinks,
      timelineChannel: timelineChannel,
    ),
  );
  // The audio player is an app-wide singleton (not rebuilt per page entry) so a
  // clip survives the Collection feed's post-write re-syncs; the page stops it on
  // exit. It plays the same content-addressed bytes the read path already serves.
  // The Media overview shares it, so a clip started there keeps playing in the
  // feed's bar.
  final playback = AudioPlaybackController(
    player: AudioPlayersAudioPlayer(),
    attachmentRead: SyncStoreAttachmentReadRepository(graph: graph),
  );
  CollectionScope.setPlaybackController(playback);
  CollectionMediaScope.setPlaybackController(playback);
  ConnectionsScope.setFactory(
    () => ConnectionsController(
      readRepository: SyncStoreConnectionsReadRepository(graph: graph),
      cardLinks: cardLinks,
    ),
  );
  CardEditScope.setFactory(
    () => CardEditModule(
      writeRepository: SyncStoreCardEditWriteRepository(graph: graph),
      linksReadRepository: SyncStoreCardEditLinksReadRepository(graph: graph),
      cardLinks: cardLinks,
      imageCache: imageCache,
      attachmentWriteRepository: SyncStoreAttachmentWriteRepository(
        graph: graph,
        ids: ids,
      ),
      imagePicker: ImagePickerAdapter(),
      filePicker: const FilePickerAdapter(),
    ).controller,
  );
  CollectionEditScope.setFactory(
    () => CollectionEditModule(
      collectionDetails: collectionDetails,
      imageCache: imageCache,
      attachmentWriteRepository: SyncStoreAttachmentWriteRepository(
        graph: graph,
        ids: ids,
      ),
      imagePicker: ImagePickerAdapter(),
      mediaReadRepository: SyncStoreCollectionMediaReadRepository(graph: graph),
    ).controller,
  );
  CollectionMediaScope.setFactory(
    () => CollectionMediaModule(
      readRepository: SyncStoreCollectionMediaReadRepository(graph: graph),
      attachmentReadRepository: SyncStoreAttachmentReadRepository(graph: graph),
      imageCache: imageCache,
      shareRepository: const SharePlusCardShareRepository(),
      linkLauncher: const UrlLauncherLinkLauncher(),
    ).controller,
  );

  runApp(KnitApp(config: config));
}

class KnitApp extends StatefulWidget {
  const KnitApp({super.key, required this.config});

  /// The active build flavor's config — drives the non-prod flavor banner.
  final AppConfig config;

  @override
  State<KnitApp> createState() => _KnitAppState();
}

class _KnitAppState extends State<KnitApp> {
  static const _seedColor = Color(0xFF5B6CFF);

  @override
  void initState() {
    super.initState();
    // Load the persisted theme/language on launch; the ValueListenableBuilder
    // below then rebuilds MaterialApp once they land (the first frame uses the
    // system defaults, which is also the likely persisted value).
    SettingsScope.controller.dispatch(const ViewAttached());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsState>(
      valueListenable: SettingsScope.controller.stateHolder,
      builder: (context, state, _) {
        final prefs = state.preferences;
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: _localeOf(prefs.language),
          themeMode: _themeModeOf(prefs.themeMode),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _seedColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          builder: _flavorBanner,
          home: const AppLaunchPage(),
        );
      },
    );
  }

  /// Corner ribbon naming the flavor on every non-prod build, so a dev/staging
  /// install is never mistaken for prod. Prod renders the child untouched.
  Widget _flavorBanner(BuildContext context, Widget? child) {
    final content = child ?? const SizedBox.shrink();
    if (widget.config.isProd) return content;
    return Banner(
      message: widget.config.flavor.label,
      location: BannerLocation.topEnd,
      color: Colors.red.shade700,
      child: content,
    );
  }

  /// Map the domain preference enums to Flutter's types at the edge — the domain
  /// stays free of `package:flutter/material`.
  ThemeMode _themeModeOf(AppThemeMode mode) => switch (mode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  Locale? _localeOf(AppLanguage language) => switch (language) {
    AppLanguage.system => null,
    AppLanguage.english => const Locale('en'),
    AppLanguage.russian => const Locale('ru'),
  };
}
