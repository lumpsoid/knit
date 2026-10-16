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
  String get actionAdd => 'Add';

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
  String get timelineNewCollectionTitle => 'New collection';

  @override
  String get timelineNewCollectionHint => 'Title or theme';

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
  String get collectionAddLinkTitle => 'Add a link';

  @override
  String get collectionAddLinkHint => 'https://…';

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
  String get collectionReorderTooltip => 'Reorder';

  @override
  String collectionComingSoon(String feature) {
    return '$feature — coming soon';
  }

  @override
  String get collectionPhotoCards => 'Photo cards';

  @override
  String get collectionAudioCards => 'Audio cards';

  @override
  String get collectionBlockLink => 'Link';

  @override
  String get collectionBlockLinkSubtitle => 'A standalone link card';

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
  String get collectionActionEdit => 'Edit';

  @override
  String get collectionActionMakeLink => 'Make a link';

  @override
  String get collectionActionShare => 'Share';

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
  String get collectionAppBarTitle => 'Collection';

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
  String get cardEditAddPhoto => 'Add photo';

  @override
  String get cardEditAttachFile => 'Attach file';

  @override
  String get cardEditAttachment => 'Attachment';

  @override
  String get cardEditReplace => 'Replace';

  @override
  String get cardEditRemove => 'Remove';

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
  String get collectionMoveSheetTitle => 'Move to…';

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
}
