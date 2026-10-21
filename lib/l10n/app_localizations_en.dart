// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Knit';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionCreate => 'Create';

  @override
  String get actionSave => 'Save';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionDone => 'Done';

  @override
  String get actionLink => 'Link';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionClose => 'Close';

  @override
  String get actionPin => 'Pin';

  @override
  String get actionUnpin => 'Unpin';

  @override
  String get actionArchive => 'Archive';

  @override
  String get actionUnarchive => 'Unarchive';

  @override
  String get labelUntitled => 'Untitled';

  @override
  String get labelEmptyNote => 'Empty note';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get appLaunchError => 'Couldn\'t start Knit';

  @override
  String get appLaunchUnknownError => 'Unknown error';

  @override
  String get onboardWelcomeTitle => 'Welcome to Knit';

  @override
  String get onboardWelcomeBody =>
      'Capture anything as cards, woven together in your own collections. Local-first — your data lives on your device.';

  @override
  String get onboardGetStarted => 'Get started';

  @override
  String get onboardNicknameTitle => 'What should people call you?';

  @override
  String get onboardNicknameBody =>
      'A nickname is just a label — your identity is your key, not this name. You can change it anytime.';

  @override
  String get onboardNicknameLabel => 'Nickname';

  @override
  String get onboardNicknameHint => 'e.g. mira';

  @override
  String get onboardExplainTitle => 'Your identity is a key';

  @override
  String get onboardExplainKeyPair =>
      'We\'ll generate a cryptographic key pair on this device. The public key IS your identity — not a username on someone\'s server.';

  @override
  String get onboardExplainPrivate =>
      'The private half never leaves your device. Keep it safe — backing it up later (in Settings) is how you back up \"you\".';

  @override
  String onboardExplainNickname(String nickname) {
    return 'Hi, $nickname — your key is who you are, your nickname is what you\'re called.';
  }

  @override
  String get onboardGenerate => 'Generate my identity';

  @override
  String get onboardIdentityError =>
      'We couldn\'t create your identity. Please try again.';

  @override
  String get onboardGeneratingTitle => 'Minting your keypair…';

  @override
  String get onboardGeneratingBody =>
      'Generating Ed25519 keys and signing your profile.';

  @override
  String get onboardRevealTitle => 'Meet yourself';

  @override
  String get onboardKeyTagline =>
      'key = who you are · nickname = what you\'re called';

  @override
  String get onboardPrivateKeyNote =>
      'Your private key is stored only on this device. Back it up later from Settings.';

  @override
  String get onboardEnter => 'Enter Knit';

  @override
  String get onboardCopyPublicKey => 'Copy public key';

  @override
  String get onboardPublicKeyCopied => 'Public key copied';

  @override
  String get onboardRestore => 'Restore from backup';

  @override
  String get onboardRestoreTitle => 'Restore your backup';

  @override
  String onboardRestoreBody(String date) {
    return 'Enter the passphrase you chose when you exported this backup on $date.';
  }

  @override
  String get onboardRestoreAction => 'Restore';

  @override
  String get onboardRestoreWrongPassphrase => 'Wrong passphrase';

  @override
  String get onboardRestoringTitle => 'Restoring your backup…';

  @override
  String get onboardRestoringBody =>
      'Unlocking your key and replaying your cards.';

  @override
  String get onboardRestoreUnreadable => 'That file isn\'t a Knit backup.';

  @override
  String get onboardRestoreNoIdentity =>
      'This backup was made before backups included the key, so it can\'t restore an identity. Create a new identity, then import it from Settings.';

  @override
  String get onboardRestoreFailed =>
      'We couldn\'t restore the backup. Please try again.';

  @override
  String get onboardWelcomeBackTitle => 'Welcome back';

  @override
  String get timelineCollectionFab => 'Collection';

  @override
  String get newCollectionHint => 'What\'s this about?';

  @override
  String get newCollectionCreateTooltip => 'Create collection';

  @override
  String get newCollectionExistingLead => 'You already have';

  @override
  String get newCollectionOpenExisting => 'Open';

  @override
  String get newCollectionSaveThere => 'Save there';

  @override
  String get timelineDeleteTitle => 'Delete collection?';

  @override
  String timelineDeleteBody(String title) {
    return '\"$title\" and its cards will be removed.';
  }

  @override
  String get timelineEmptyTitle => 'No collections yet';

  @override
  String get timelineEmptyBody =>
      'Collections are chat-style notebooks of cards.\nCreate one to start weaving things together.';

  @override
  String get timelineLoadError => 'Could not load your collections.';

  @override
  String get timelineCreateFailed =>
      'Couldn\'t create the collection. Please try again.';

  @override
  String get timelineDeleteFailed =>
      'Couldn\'t delete the collection. Please try again.';

  @override
  String timelineCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String get timelinePinnedSection => 'Pinned';

  @override
  String get timelineRecentSection => 'Recent';

  @override
  String get timelinePinFailed => 'Couldn\'t update the pin. Please try again.';

  @override
  String get timelineArchiveFailed =>
      'Couldn\'t update the archive. Please try again.';

  @override
  String get timelineArchiveRow => 'Archive';

  @override
  String timelineArchiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collections',
      one: '1 collection',
    );
    return '$_temp0';
  }

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archiveEmpty => 'No archived collections';

  @override
  String get searchArchived => 'Archived';

  @override
  String get timelineNoCardsYet => 'No cards yet';

  @override
  String get timelinePreviewPhoto => '📷 Photo';

  @override
  String get timelinePreviewAudio => '🎙 Audio';

  @override
  String get timelinePreviewLink => '🔗 Link';

  @override
  String get timeNow => 'now';

  @override
  String timeMinutesShort(int count) {
    return '${count}m';
  }

  @override
  String timeHoursShort(int count) {
    return '${count}h';
  }

  @override
  String timeDaysShort(int count) {
    return '${count}d';
  }

  @override
  String get collectionLinkOpenFailed => 'Couldn\'t open this link';

  @override
  String get collectionRenameTitle => 'Rename collection';

  @override
  String get collectionComposerHint => 'Write a card…';

  @override
  String get collectionAddBlockTooltip => 'Add block';

  @override
  String get collectionSendTooltip => 'Send';

  @override
  String get collectionConnectionsTooltip => 'Connections';

  @override
  String collectionCardConnections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count connections',
      one: '1 connection',
    );
    return '$_temp0';
  }

  @override
  String collectionComingSoon(String feature) {
    return '$feature — coming soon';
  }

  @override
  String get collectionPhotoCards => 'Photo cards';

  @override
  String get collectionAudioCards => 'Audio cards';

  @override
  String get collectionBlockConnection => 'Connection';

  @override
  String get collectionBlockConnectionSubtitle => 'Link to another collection';

  @override
  String get collectionBlockPhoto => 'Photo';

  @override
  String get collectionBlockAudio => 'Audio';

  @override
  String get collectionBlockFile => 'File';

  @override
  String get collectionPhotoSourceGallery => 'Gallery';

  @override
  String get collectionPhotoSourceCamera => 'Camera';

  @override
  String get collectionAddMorePhotos => 'Add more photos';

  @override
  String get collectionAudioStart => 'Start recording';

  @override
  String get collectionAudioStop => 'Stop';

  @override
  String get collectionAudioPause => 'Pause';

  @override
  String get collectionAudioResume => 'Resume';

  @override
  String get collectionAudioRecording => 'Recording';

  @override
  String get collectionAudioPaused => 'Paused';

  @override
  String get collectionAudioPlay => 'Play';

  @override
  String get collectionAudioNowPlaying => 'Now playing';

  @override
  String get collectionAudioMessage => 'Audio message';

  @override
  String get collectionAudioPermissionDenied =>
      'Microphone access is needed to record audio.';

  @override
  String get collectionImageOptimize => 'Optimize size';

  @override
  String get collectionImageOptimizing => 'Optimizing photo…';

  @override
  String get collectionImageOptimizingHint =>
      'Resizing to 1600×1200. This can take a few seconds.';

  @override
  String get collectionImageAlreadySmall => 'Already small';

  @override
  String collectionImageSizeSaved(String from, String to) {
    return '$from → $to';
  }

  @override
  String get collectionActionEdit => 'Edit';

  @override
  String get collectionActionMakeLink => 'Make a link';

  @override
  String get collectionActionCopy => 'Copy';

  @override
  String get collectionCopied => 'Copied to clipboard';

  @override
  String get collectionActionShare => 'Share';

  @override
  String get collectionActionMove => 'Move to collection…';

  @override
  String get collectionActionSettle => 'Settle';

  @override
  String get collectionActionUnsettle => 'Unsettle';

  @override
  String get collectionCardSettled => 'Settled';

  @override
  String get collectionActionEmphasize => 'Emphasize';

  @override
  String get collectionActionUnemphasize => 'Unemphasize';

  @override
  String get collectionCardEmphasized => 'Emphasized';

  @override
  String get collectionActionDelete => 'Delete';

  @override
  String get collectionCardLink => 'Link';

  @override
  String get collectionCardPhoto => 'Photo';

  @override
  String get collectionCardAudio => 'Audio';

  @override
  String get collectionCardFile => 'File';

  @override
  String get collectionReorderPhoto => '[Photo]';

  @override
  String get collectionEmptyTitle => 'No cards yet';

  @override
  String get collectionEmptyBody =>
      'Write your first card below, or tap + to add a block.';

  @override
  String get collectionLoadError => 'Could not load this collection.';

  @override
  String get collectionSaveFailed => 'That didn\'t save. Please try again.';

  @override
  String get collectionLinkFinderTitle => 'Make a link';

  @override
  String get collectionConnectionPickerTitle => 'Connect to a collection';

  @override
  String get collectionNothingToLink => 'Nothing to link to yet.';

  @override
  String get collectionBackToCollections => 'Back to collections';

  @override
  String collectionLinkToCollection(String label) {
    return 'Link to \"$label\"';
  }

  @override
  String get collectionNoCardsToLink => 'No cards here to link to.';

  @override
  String get collectionOrACardInIt => 'Or a card in it';

  @override
  String get collectionDescriptionEmpty => 'No description';

  @override
  String get collectionEditTitle => 'Edit collection';

  @override
  String get collectionEditTitleHint => 'Title';

  @override
  String get collectionEditDescriptionHint => 'Description (optional)';

  @override
  String get collectionEditCover => 'Cover';

  @override
  String get collectionEditAddCover => 'Add cover photo';

  @override
  String get collectionEditReplaceCover => 'Replace cover';

  @override
  String get collectionEditRemoveCover => 'Remove cover';

  @override
  String get collectionEditMedia => 'Media';

  @override
  String get collectionEditMediaEmpty => 'No media yet';

  @override
  String get collectionMediaTitle => 'Media';

  @override
  String get collectionMediaTabPhotos => 'Photos';

  @override
  String get collectionMediaTabAudio => 'Audio';

  @override
  String get collectionMediaTabFiles => 'Files';

  @override
  String get collectionMediaTabLinks => 'Links';

  @override
  String get collectionMediaEmptyTab => 'Nothing here yet';

  @override
  String get collectionMediaLoadFailed => 'Couldn\'t load media';

  @override
  String collectionMediaPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String collectionMediaAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audio',
      one: '1 audio',
    );
    return '$_temp0';
  }

  @override
  String collectionMediaFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String collectionMediaLinkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links',
      one: '1 link',
    );
    return '$_temp0';
  }

  @override
  String get cardEditTitle => 'Edit card';

  @override
  String get cardEditHint => 'Edit this card…';

  @override
  String get cardEditAddPhoto => 'Add photos';

  @override
  String get cardEditAttachFile => 'Attach file';

  @override
  String get cardEditAttachment => 'Attachment';

  @override
  String get cardEditReplace => 'Replace';

  @override
  String get cardEditRemove => 'Remove';

  @override
  String get cardEditRemoveAll => 'Remove all';

  @override
  String get cardEditOptimize => 'Optimize';

  @override
  String get cardEditImageNotSmaller => 'This photo can\'t be made smaller.';

  @override
  String cardEditImageOptimized(String from, String to) {
    return 'Photo optimized: $from → $to';
  }

  @override
  String get cardEditLinksHeader => 'LINKS';

  @override
  String get cardEditNoLinks => 'No links yet.';

  @override
  String get cardEditAddLink => 'Add link';

  @override
  String get cardEditBrokenLink => 'Broken link';

  @override
  String get cardEditBrokenLinkSubtitle => 'The linked item was deleted';

  @override
  String get cardEditSaveFailed => 'That didn\'t save. Please try again.';

  @override
  String get cardEditSettled => 'Settled';

  @override
  String get cardEditSettledSubtitle => 'Kept for history, no longer current';

  @override
  String get cardEditEmphasized => 'Emphasized';

  @override
  String get cardEditEmphasizedSubtitle =>
      'Stands out in the feed with a bright frame';

  @override
  String get connectionsTitle => 'Connections';

  @override
  String get connectionsClearTitle => 'Clear this link?';

  @override
  String get connectionsClearBody =>
      'The broken link will be removed. The cards and collections it pointed at are not deleted.';

  @override
  String get connectionsLinksOut => 'Links out';

  @override
  String get connectionsLinkedFrom => 'Linked from';

  @override
  String get connectionsOpen => 'Open in collection';

  @override
  String get connectionsBrokenLink => 'Broken link';

  @override
  String connectionsLinkedDeleted(String kind) {
    return 'The linked $kind was deleted';
  }

  @override
  String connectionsLinkingDeleted(String kind) {
    return 'The linking $kind was deleted';
  }

  @override
  String get connectionsKindCollection => 'collection';

  @override
  String get connectionsKindCard => 'card';

  @override
  String get connectionsKindItem => 'item';

  @override
  String get connectionsEmptyTitle => 'No connections yet';

  @override
  String get connectionsEmptyBody =>
      'Link a card to a collection and it will show up here.';

  @override
  String get connectionsLoadError => 'Could not load connections.';

  @override
  String get connectionsClearFailed => 'That didn\'t clear. Please try again.';

  @override
  String get connectionsMentionedIn => 'Mentioned in';

  @override
  String connectionsMentionsMore(int count) {
    return '+$count more';
  }

  @override
  String get connectionsLinkFailed => 'That didn\'t link. Please try again.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileNicknameLabel => 'Nickname';

  @override
  String get profileEditNickname => 'Edit nickname';

  @override
  String get profileRenameTitle => 'Edit nickname';

  @override
  String get profileRenameHint => 'e.g. mira';

  @override
  String get profileRenameFailed =>
      'Couldn\'t update your nickname. Please try again.';

  @override
  String get profilePublicKeyLabel => 'Public key';

  @override
  String get profileCopyKey => 'Copy public key';

  @override
  String get profileKeyCopied => 'Public key copied';

  @override
  String get profileLoadError => 'Couldn\'t load your profile.';

  @override
  String get profileOpen => 'Profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsOpen => 'Settings';

  @override
  String get settingsDataTitle => 'Data';

  @override
  String get settingsDataSubtitle => 'Export, import, and manage your data';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsThemeSystem => 'System default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsKeepPhotoMetadataTitle => 'Keep photo metadata';

  @override
  String get settingsKeepPhotoMetadataSubtitle =>
      'When a photo is optimized, keep its camera, date and location details';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutSubtitle => 'Version and app info';

  @override
  String get settingsAboutTagline =>
      'A local-first space for weaving your thoughts together.';

  @override
  String get settingsAboutVersionLabel => 'Version';

  @override
  String get settingsDataTransferSection => 'Backup & transfer';

  @override
  String get settingsExport => 'Export data';

  @override
  String get settingsExportSubtitle =>
      'Save your collections, cards and key to a file';

  @override
  String get settingsImport => 'Import data';

  @override
  String get settingsImportSubtitle =>
      'Restore from a previously exported file';

  @override
  String get settingsDangerSection => 'Danger zone';

  @override
  String get settingsWipeData => 'Wipe data';

  @override
  String get settingsWipeDataSubtitle =>
      'Delete all collections and cards on this device';

  @override
  String get settingsResetIdentity => 'Reset identity';

  @override
  String get settingsResetIdentitySubtitle =>
      'Delete all data and this device\'s key, then start over';

  @override
  String get settingsExportChooseTitle => 'Export backup';

  @override
  String get settingsExportChooseShare => 'Share…';

  @override
  String get settingsExportChooseShareSubtitle =>
      'Send the backup to another app';

  @override
  String get settingsExportChooseSave => 'Save to a file';

  @override
  String get settingsExportChooseSaveSubtitle =>
      'Choose where to keep the backup';

  @override
  String get settingsBackupExported => 'Backup ready to share';

  @override
  String get settingsBackupSaved => 'Backup saved';

  @override
  String get settingsBackupExportFailed => 'Couldn\'t create the backup';

  @override
  String get settingsBackupImportFailed => 'Couldn\'t restore the backup';

  @override
  String settingsBackupImported(int applied, int deduped) {
    return 'Restored $applied items ($deduped already present)';
  }

  @override
  String settingsBackupImportWarning(int quarantined, int mismatched) {
    return '$quarantined ops skipped, $mismatched files corrupt';
  }

  @override
  String get settingsWipeConfirmTitle => 'Wipe all data?';

  @override
  String get settingsWipeConfirmMessage =>
      'This permanently deletes every collection, card, and link on this device. Your identity is kept. This can\'t be undone — export a backup first if you might want this data back.';

  @override
  String get settingsWipeConfirmAction => 'Wipe data';

  @override
  String get settingsWipeDone => 'All data wiped';

  @override
  String get settingsWipeFailed => 'Couldn\'t wipe the data';

  @override
  String get settingsExportPassphraseTitle => 'Protect your key';

  @override
  String get settingsExportPassphraseMessage =>
      'The backup includes your private key. Choose a passphrase to encrypt it — you\'ll need it to restore the backup, and it can\'t be recovered if you forget it.';

  @override
  String get settingsPassphraseLabel => 'Passphrase';

  @override
  String get settingsPassphraseConfirmLabel => 'Repeat passphrase';

  @override
  String settingsPassphraseTooShort(int min) {
    return 'Use at least $min characters';
  }

  @override
  String get settingsPassphraseMismatch => 'The passphrases don\'t match';

  @override
  String get settingsExportPassphraseAction => 'Continue';

  @override
  String get settingsReplaceTitle => 'Replace this device?';

  @override
  String settingsReplaceMessage(String date) {
    return 'This backup from $date belongs to another identity. Restoring it deletes everything on this device, including your key, and makes you that identity. Enter the backup\'s passphrase to continue.';
  }

  @override
  String get settingsReplaceWrongPassphrase => 'Wrong passphrase';

  @override
  String get settingsReplaceAction => 'Erase and restore';

  @override
  String settingsDeviceReplaced(int applied) {
    return 'Backup restored — $applied items';
  }

  @override
  String get settingsResetConfirmTitle => 'Reset identity?';

  @override
  String settingsResetConfirmMessage(String word) {
    return 'This permanently deletes every collection, card and link on this device, and your key. Without a backup, nothing you made can be restored as you. Type $word to confirm.';
  }

  @override
  String get settingsResetConfirmAction => 'Reset';

  @override
  String get settingsResetBackupFirst => 'Back up first';

  @override
  String get settingsResetFailed => 'Couldn\'t reset the identity';

  @override
  String get syncAllSaved => 'All changes saved';

  @override
  String get syncUnavailable => 'Sync status unavailable';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes saved on this device — not yet shared',
      one: '1 change saved on this device — not yet shared',
    );
    return '$_temp0';
  }

  @override
  String get searchOpen => 'Search';

  @override
  String get searchHint => 'Search collections and cards';

  @override
  String get searchIdle => 'Type a query and press search';

  @override
  String get searchFailed => 'Couldn\'t run the search';

  @override
  String searchNoResults(String query) {
    return 'Nothing found for “$query”';
  }

  @override
  String get searchFilterAll => 'All';

  @override
  String get searchFilterCollections => 'Collections';

  @override
  String get searchFilterCards => 'Cards';

  @override
  String get searchHintScoped => 'Search cards in this collection';

  @override
  String searchScopeChip(String title) {
    return 'In: $title';
  }

  @override
  String get searchScopeClear => 'Search everywhere';

  @override
  String get searchKindText => 'Text';

  @override
  String get searchKindImage => 'Photos';

  @override
  String get searchKindLink => 'Links';

  @override
  String get searchKindFile => 'Files';

  @override
  String get searchKindAudio => 'Audio';

  @override
  String get searchSettledAny => 'Settled: any';

  @override
  String get searchSettledLive => 'Live only';

  @override
  String get searchSettledOnly => 'Settled only';

  @override
  String get searchIncludeArchived => 'Archived';

  @override
  String searchInCollection(String title) {
    return 'in $title';
  }

  @override
  String collectionSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get collectionSelectAllTooltip => 'Select all';

  @override
  String get collectionUnselectAll => 'Unselect all';

  @override
  String get collectionClearSelectionTooltip => 'Cancel selection';

  @override
  String get collectionMoveTooltip => 'Move to collection';

  @override
  String get collectionMoveShort => 'Move';

  @override
  String get collectionDeleteSelectedTooltip => 'Delete selected';

  @override
  String collectionDeleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count cards?',
      one: 'Delete 1 card?',
    );
    return '$_temp0';
  }

  @override
  String get collectionDeleteSelectedBody =>
      'Links to them will show as broken.';

  @override
  String get collectionMoveSheetTitle => 'Move to…';

  @override
  String get collectionMoveNewCollection => 'New collection';

  @override
  String get collectionMoveThere => 'Move there';

  @override
  String get pickerRecent => 'Recent';

  @override
  String get collectionMoveNoTargets => 'No other collections yet.';

  @override
  String get collectionMoveTargetsError => 'Couldn\'t load collections.';

  @override
  String collectionCardsMoved(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moved $count cards to “$title”',
      one: 'Moved 1 card to “$title”',
    );
    return '$_temp0';
  }

  @override
  String get collectionCardsMovedOpen => 'Open';

  @override
  String get shareCaptureTitle => 'Save to Knit';

  @override
  String get shareCaptureSearchHint => 'Find a collection';

  @override
  String get shareCaptureNewCollection => 'New collection';

  @override
  String get shareCaptureEmpty =>
      'No collections yet — create one to save into';

  @override
  String get shareCaptureNoMatches => 'No matching collections';

  @override
  String get shareCaptureLoadError => 'Couldn\'t load your collections';

  @override
  String get shareCaptureSaveError => 'Couldn\'t save everything — try again';

  @override
  String get shareCaptureNeedsSetup =>
      'Set up Knit first — the shared item wasn\'t saved';

  @override
  String shareCaptureItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String shareCaptureSaved(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved $count cards to “$title”',
      one: 'Saved 1 card to “$title”',
    );
    return '$_temp0';
  }

  @override
  String get collectionWidgetPickTitle => 'Choose a collection for the widget';

  @override
  String get collectionWidgetEmpty =>
      'No collections yet — create one in Knit first';

  @override
  String get collectionWidgetSaveError =>
      'Couldn\'t set up the widget — try again';

  @override
  String get collectionWidgetNeedsSetup =>
      'Set up Knit first, then tap the widget again';

  @override
  String get collectionWidgetRemoved =>
      'That collection was removed — tap the widget to pick another';

  @override
  String get collectionMoreTooltip => 'More';

  @override
  String get collectionMenuPresent => 'Present';

  @override
  String get collectionMenuOutline => 'Outline';

  @override
  String get collectionMenuSearch => 'Search in collection';

  @override
  String get collectionOutlineTitle => 'Outline';

  @override
  String get collectionOutlineEmpty =>
      'No headings yet. Emphasize a card to make it a heading: it shows up here, and opens a slide when you present.';

  @override
  String get collectionOutlineError => 'Couldn\'t load the outline.';

  @override
  String get collectionMenuReorder => 'Reorder cards';

  @override
  String get collectionMenuDelete => 'Delete collection';

  @override
  String presentSlideCount(int index, int count) {
    return '$index / $count';
  }

  @override
  String presentContinueFrom(int number) {
    return 'Continue from slide $number';
  }

  @override
  String get presentSwipeHint => 'Swipe up to start';

  @override
  String get presentEmpty => 'Nothing to present yet';

  @override
  String get presentLoadFailed => 'Couldn\'t open this collection';

  @override
  String get presentSeeAlso => 'See also';

  @override
  String get presentNextTooltip => 'Next slide';

  @override
  String get presentPreviousTooltip => 'Previous slide';

  @override
  String get collectionMenuShareFile => 'Share as file';

  @override
  String get shareExportTitle => 'Share as file';

  @override
  String shareExportSummary(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$title · $_temp0';
  }

  @override
  String get shareExportIncludeMedia => 'Include media';

  @override
  String shareExportMediaSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 · $size';
  }

  @override
  String shareExportSize(String size) {
    return 'File size: $size';
  }

  @override
  String get shareExportHint =>
      'The recipient sees it read-only, marked as from you, and can save their own copy.';

  @override
  String get shareExportSend => 'Send';

  @override
  String get shareExportSave => 'Save to file';

  @override
  String get shareExportFailed =>
      'Couldn\'t create the file. Please try again.';

  @override
  String get shareExportLoadFailed => 'Couldn\'t read this collection.';

  @override
  String get shareExportSaved => 'Collection file saved';

  @override
  String get shareImportTitle => 'Import collection';

  @override
  String get shareImportReading => 'Reading the file…';

  @override
  String shareImportSummary(int count, String handle) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0 · from $handle';
  }

  @override
  String get shareImportNoMedia => 'Media not included';

  @override
  String get shareImportReadOnlyHint =>
      'It arrives read-only. You can save your own copy later.';

  @override
  String get shareImportOwnHint =>
      'This is your own collection. It merges into the one on this device.';

  @override
  String get shareImportAction => 'Import';

  @override
  String get shareImportUpdate => 'Update';

  @override
  String get shareImportUnreadable =>
      'This isn\'t a Knit collection file, or it\'s damaged.';

  @override
  String get shareImportNewer =>
      'This file is from a newer Knit. Update the app to open it.';

  @override
  String get shareImportRefused =>
      'This file failed its safety checks, so nothing was imported.';

  @override
  String get shareImportFailed =>
      'The import stopped part-way. Import the file again to finish it.';

  @override
  String get settingsImportCollection => 'Import collection';

  @override
  String get settingsImportCollectionSubtitle =>
      'Open a .knitc file someone shared with you';

  @override
  String get collectionActionConnections => 'Connections';

  @override
  String get collectionActionLinkFromMine => 'Link from my card…';

  @override
  String get collectionLinkFromMineTitle => 'Link from which of your cards?';

  @override
  String collectionReadOnlyFrom(String handle) {
    return 'Read-only · from $handle';
  }

  @override
  String timelineInHubs(String names) {
    return 'in: $names';
  }

  @override
  String timelineInHubsMore(String names, int more) {
    return 'in: $names +$more';
  }

  @override
  String get collectionLinkTileOpen => 'Open collection';

  @override
  String timelineFromHandle(String handle) {
    return 'from $handle';
  }

  @override
  String get collectionMenuSaveCopy => 'Save a copy';

  @override
  String get collectionMenuRemove => 'Remove from this device';

  @override
  String get collectionCopySaved => 'Saved your own copy';

  @override
  String get collectionCopyFailed => 'Couldn\'t save a copy. Please try again.';

  @override
  String get collectionRemoveTitle => 'Remove this collection?';

  @override
  String collectionRemoveBody(String title) {
    return '“$title” and its media leave this device. Importing the file again brings it back.';
  }

  @override
  String get collectionRemoveAction => 'Remove';

  @override
  String get collectionRemoveFailed =>
      'Couldn\'t remove the collection. Please try again.';
}
