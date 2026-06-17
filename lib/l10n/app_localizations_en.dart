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
  String get collectionActionConnections => 'Connections';

  @override
  String get collectionActionShare => 'Share';

  @override
  String get collectionActionReorder => 'Reorder';

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
  String get cardEditLinkToWhichCollection => 'Link to which collection?';

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
      'Save your collections and cards to a file';

  @override
  String get settingsImport => 'Import data';

  @override
  String get settingsImportSubtitle =>
      'Restore from a previously exported file';

  @override
  String get settingsExportIdentity => 'Export identity';

  @override
  String get settingsExportIdentitySubtitle =>
      'Back up your private key so you can restore \"you\"';

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
      'Discard this device\'s key and start over';

  @override
  String settingsComingSoon(String feature) {
    return '$feature — coming soon';
  }

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
}
