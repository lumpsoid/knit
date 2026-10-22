import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// The application name, shown as the app title and on splash/home.
  ///
  /// In en, this message translates to:
  /// **'Knit'**
  String get appTitle;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get actionLink;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get actionPin;

  /// No description provided for @actionUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get actionUnpin;

  /// No description provided for @actionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get actionArchive;

  /// No description provided for @actionUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get actionUnarchive;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @labelUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get labelUntitled;

  /// No description provided for @labelEmptyNote.
  ///
  /// In en, this message translates to:
  /// **'Empty note'**
  String get labelEmptyNote;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @appLaunchError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start Knit'**
  String get appLaunchError;

  /// No description provided for @appLaunchUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get appLaunchUnknownError;

  /// No description provided for @onboardWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Knit'**
  String get onboardWelcomeTitle;

  /// No description provided for @onboardWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Capture anything as cards, woven together in your own collections. Local-first — your data lives on your device.'**
  String get onboardWelcomeBody;

  /// No description provided for @onboardGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardGetStarted;

  /// No description provided for @onboardNicknameTitle.
  ///
  /// In en, this message translates to:
  /// **'What should people call you?'**
  String get onboardNicknameTitle;

  /// No description provided for @onboardNicknameBody.
  ///
  /// In en, this message translates to:
  /// **'A nickname is just a label — your identity is your key, not this name. You can change it anytime.'**
  String get onboardNicknameBody;

  /// No description provided for @onboardNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get onboardNicknameLabel;

  /// No description provided for @onboardNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. mira'**
  String get onboardNicknameHint;

  /// No description provided for @onboardExplainTitle.
  ///
  /// In en, this message translates to:
  /// **'Your identity is a key'**
  String get onboardExplainTitle;

  /// No description provided for @onboardExplainKeyPair.
  ///
  /// In en, this message translates to:
  /// **'We\'ll generate a cryptographic key pair on this device. The public key IS your identity — not a username on someone\'s server.'**
  String get onboardExplainKeyPair;

  /// No description provided for @onboardExplainPrivate.
  ///
  /// In en, this message translates to:
  /// **'The private half never leaves your device. Keep it safe — backing it up later (in Settings) is how you back up \"you\".'**
  String get onboardExplainPrivate;

  /// No description provided for @onboardExplainNickname.
  ///
  /// In en, this message translates to:
  /// **'Hi, {nickname} — your key is who you are, your nickname is what you\'re called.'**
  String onboardExplainNickname(String nickname);

  /// No description provided for @onboardGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate my identity'**
  String get onboardGenerate;

  /// No description provided for @onboardIdentityError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t create your identity. Please try again.'**
  String get onboardIdentityError;

  /// No description provided for @onboardGeneratingTitle.
  ///
  /// In en, this message translates to:
  /// **'Minting your keypair…'**
  String get onboardGeneratingTitle;

  /// No description provided for @onboardGeneratingBody.
  ///
  /// In en, this message translates to:
  /// **'Generating Ed25519 keys and signing your profile.'**
  String get onboardGeneratingBody;

  /// No description provided for @onboardRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'Meet yourself'**
  String get onboardRevealTitle;

  /// No description provided for @onboardKeyTagline.
  ///
  /// In en, this message translates to:
  /// **'key = who you are · nickname = what you\'re called'**
  String get onboardKeyTagline;

  /// No description provided for @onboardPrivateKeyNote.
  ///
  /// In en, this message translates to:
  /// **'Your private key is stored only on this device. Back it up later from Settings.'**
  String get onboardPrivateKeyNote;

  /// No description provided for @onboardEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter Knit'**
  String get onboardEnter;

  /// No description provided for @onboardCopyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Copy public key'**
  String get onboardCopyPublicKey;

  /// No description provided for @onboardPublicKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Public key copied'**
  String get onboardPublicKeyCopied;

  /// No description provided for @onboardRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get onboardRestore;

  /// No description provided for @onboardRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore your backup'**
  String get onboardRestoreTitle;

  /// No description provided for @onboardRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase you chose when you exported this backup on {date}.'**
  String onboardRestoreBody(String date);

  /// No description provided for @onboardRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get onboardRestoreAction;

  /// No description provided for @onboardRestoreWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase'**
  String get onboardRestoreWrongPassphrase;

  /// No description provided for @onboardRestoringTitle.
  ///
  /// In en, this message translates to:
  /// **'Restoring your backup…'**
  String get onboardRestoringTitle;

  /// No description provided for @onboardRestoringBody.
  ///
  /// In en, this message translates to:
  /// **'Unlocking your key and replaying your cards.'**
  String get onboardRestoringBody;

  /// No description provided for @onboardRestoreUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t a Knit backup.'**
  String get onboardRestoreUnreadable;

  /// No description provided for @onboardRestoreNoIdentity.
  ///
  /// In en, this message translates to:
  /// **'This backup was made before backups included the key, so it can\'t restore an identity. Create a new identity, then import it from Settings.'**
  String get onboardRestoreNoIdentity;

  /// No description provided for @onboardRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t restore the backup. Please try again.'**
  String get onboardRestoreFailed;

  /// No description provided for @onboardWelcomeBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get onboardWelcomeBackTitle;

  /// No description provided for @timelineCollectionFab.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get timelineCollectionFab;

  /// No description provided for @newCollectionHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s this about?'**
  String get newCollectionHint;

  /// No description provided for @newCollectionCreateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create collection'**
  String get newCollectionCreateTooltip;

  /// No description provided for @newCollectionExistingLead.
  ///
  /// In en, this message translates to:
  /// **'You already have'**
  String get newCollectionExistingLead;

  /// No description provided for @newCollectionOpenExisting.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get newCollectionOpenExisting;

  /// No description provided for @newCollectionSaveThere.
  ///
  /// In en, this message translates to:
  /// **'Save there'**
  String get newCollectionSaveThere;

  /// No description provided for @timelineDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete collection?'**
  String get timelineDeleteTitle;

  /// No description provided for @timelineDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" and its cards will be removed.'**
  String timelineDeleteBody(String title);

  /// No description provided for @timelineEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get timelineEmptyTitle;

  /// No description provided for @timelineEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Collections are chat-style notebooks of cards.\nCreate one to start weaving things together.'**
  String get timelineEmptyBody;

  /// No description provided for @timelineLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your collections.'**
  String get timelineLoadError;

  /// No description provided for @timelineCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the collection. Please try again.'**
  String get timelineCreateFailed;

  /// No description provided for @timelineDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the collection. Please try again.'**
  String get timelineDeleteFailed;

  /// No description provided for @timelineCardCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card} other{{count} cards}}'**
  String timelineCardCount(int count);

  /// No description provided for @timelinePinnedSection.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get timelinePinnedSection;

  /// No description provided for @timelineRecentSection.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get timelineRecentSection;

  /// No description provided for @timelinePinFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the pin. Please try again.'**
  String get timelinePinFailed;

  /// No description provided for @timelineArchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the archive. Please try again.'**
  String get timelineArchiveFailed;

  /// No description provided for @timelineArchiveRow.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get timelineArchiveRow;

  /// No description provided for @timelineArchiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 collection} other{{count} collections}}'**
  String timelineArchiveCount(int count);

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTitle;

  /// No description provided for @archiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No archived collections'**
  String get archiveEmpty;

  /// No description provided for @searchArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get searchArchived;

  /// No description provided for @timelineNoCardsYet.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get timelineNoCardsYet;

  /// No description provided for @timelinePreviewPhoto.
  ///
  /// In en, this message translates to:
  /// **'📷 Photo'**
  String get timelinePreviewPhoto;

  /// No description provided for @timelinePreviewAudio.
  ///
  /// In en, this message translates to:
  /// **'🎙 Audio'**
  String get timelinePreviewAudio;

  /// No description provided for @timelinePreviewLink.
  ///
  /// In en, this message translates to:
  /// **'🔗 Link'**
  String get timelinePreviewLink;

  /// No description provided for @timelinePreviewFile.
  ///
  /// In en, this message translates to:
  /// **'📎 File'**
  String get timelinePreviewFile;

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// No description provided for @timeMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String timeMinutesShort(int count);

  /// No description provided for @timeHoursShort.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String timeHoursShort(int count);

  /// No description provided for @timeDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String timeDaysShort(int count);

  /// No description provided for @collectionLinkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this link'**
  String get collectionLinkOpenFailed;

  /// No description provided for @collectionRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get collectionRenameTitle;

  /// No description provided for @collectionComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Write a card…'**
  String get collectionComposerHint;

  /// No description provided for @collectionAddBlockTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add block'**
  String get collectionAddBlockTooltip;

  /// No description provided for @collectionSendTooltip.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get collectionSendTooltip;

  /// No description provided for @collectionConnectionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get collectionConnectionsTooltip;

  /// No description provided for @collectionCardBacklinks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Linked from 1 place} other{Linked from {count} places}}'**
  String collectionCardBacklinks(int count);

  /// No description provided for @linkTo.
  ///
  /// In en, this message translates to:
  /// **'→ {name}'**
  String linkTo(String name);

  /// No description provided for @linkChipUnavailable.
  ///
  /// In en, this message translates to:
  /// **'→ unavailable'**
  String get linkChipUnavailable;

  /// No description provided for @linkChipMore.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String linkChipMore(int count);

  /// No description provided for @linkChipMoreLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more link} other{{count} more links}}'**
  String linkChipMoreLabel(int count);

  /// No description provided for @linkArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get linkArchived;

  /// No description provided for @collectionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} — coming soon'**
  String collectionComingSoon(String feature);

  /// No description provided for @collectionPhotoCards.
  ///
  /// In en, this message translates to:
  /// **'Photo cards'**
  String get collectionPhotoCards;

  /// No description provided for @collectionAudioCards.
  ///
  /// In en, this message translates to:
  /// **'Audio cards'**
  String get collectionAudioCards;

  /// No description provided for @collectionBlockConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get collectionBlockConnection;

  /// No description provided for @collectionBlockConnectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Link to a collection or card'**
  String get collectionBlockConnectionSubtitle;

  /// No description provided for @collectionBlockPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get collectionBlockPhoto;

  /// No description provided for @collectionBlockAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get collectionBlockAudio;

  /// No description provided for @collectionBlockFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get collectionBlockFile;

  /// No description provided for @collectionPhotoSourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get collectionPhotoSourceGallery;

  /// No description provided for @collectionPhotoSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get collectionPhotoSourceCamera;

  /// No description provided for @collectionAddMorePhotos.
  ///
  /// In en, this message translates to:
  /// **'Add more photos'**
  String get collectionAddMorePhotos;

  /// No description provided for @collectionAudioStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get collectionAudioStart;

  /// No description provided for @collectionAudioStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get collectionAudioStop;

  /// No description provided for @collectionAudioPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get collectionAudioPause;

  /// No description provided for @collectionAudioResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get collectionAudioResume;

  /// No description provided for @collectionAudioRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get collectionAudioRecording;

  /// No description provided for @collectionAudioPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get collectionAudioPaused;

  /// No description provided for @collectionAudioPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get collectionAudioPlay;

  /// No description provided for @collectionAudioNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get collectionAudioNowPlaying;

  /// No description provided for @collectionAudioMessage.
  ///
  /// In en, this message translates to:
  /// **'Audio message'**
  String get collectionAudioMessage;

  /// No description provided for @collectionAudioPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed to record audio.'**
  String get collectionAudioPermissionDenied;

  /// No description provided for @collectionImageOptimize.
  ///
  /// In en, this message translates to:
  /// **'Optimize size'**
  String get collectionImageOptimize;

  /// No description provided for @collectionImageOptimizing.
  ///
  /// In en, this message translates to:
  /// **'Optimizing photo…'**
  String get collectionImageOptimizing;

  /// No description provided for @collectionImageOptimizingHint.
  ///
  /// In en, this message translates to:
  /// **'Resizing to 1600×1200. This can take a few seconds.'**
  String get collectionImageOptimizingHint;

  /// No description provided for @collectionImageAlreadySmall.
  ///
  /// In en, this message translates to:
  /// **'Already small'**
  String get collectionImageAlreadySmall;

  /// A photo's size before and after optimizing, e.g. 4.2 MB → 380 KB.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String collectionImageSizeSaved(String from, String to);

  /// No description provided for @collectionActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get collectionActionEdit;

  /// No description provided for @collectionActionMakeLink.
  ///
  /// In en, this message translates to:
  /// **'Make a link'**
  String get collectionActionMakeLink;

  /// No description provided for @collectionActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get collectionActionCopy;

  /// No description provided for @collectionCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get collectionCopied;

  /// No description provided for @collectionActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get collectionActionShare;

  /// No description provided for @collectionActionMove.
  ///
  /// In en, this message translates to:
  /// **'Move to collection…'**
  String get collectionActionMove;

  /// No description provided for @collectionActionSettle.
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get collectionActionSettle;

  /// No description provided for @collectionActionUnsettle.
  ///
  /// In en, this message translates to:
  /// **'Unsettle'**
  String get collectionActionUnsettle;

  /// No description provided for @collectionCardSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get collectionCardSettled;

  /// No description provided for @collectionActionEmphasize.
  ///
  /// In en, this message translates to:
  /// **'Emphasize'**
  String get collectionActionEmphasize;

  /// No description provided for @collectionActionUnemphasize.
  ///
  /// In en, this message translates to:
  /// **'Unemphasize'**
  String get collectionActionUnemphasize;

  /// No description provided for @collectionCardEmphasized.
  ///
  /// In en, this message translates to:
  /// **'Emphasized'**
  String get collectionCardEmphasized;

  /// No description provided for @collectionActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get collectionActionDelete;

  /// No description provided for @collectionCardLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get collectionCardLink;

  /// No description provided for @collectionCardPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get collectionCardPhoto;

  /// No description provided for @collectionCardAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get collectionCardAudio;

  /// No description provided for @collectionCardFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get collectionCardFile;

  /// No description provided for @collectionReorderPhoto.
  ///
  /// In en, this message translates to:
  /// **'[Photo]'**
  String get collectionReorderPhoto;

  /// No description provided for @collectionEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No cards yet'**
  String get collectionEmptyTitle;

  /// No description provided for @collectionEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Write your first card below, or tap + to add a block.'**
  String get collectionEmptyBody;

  /// No description provided for @collectionLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this collection.'**
  String get collectionLoadError;

  /// No description provided for @collectionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t save. Please try again.'**
  String get collectionSaveFailed;

  /// No description provided for @collectionLinkFinderTitle.
  ///
  /// In en, this message translates to:
  /// **'Make a link'**
  String get collectionLinkFinderTitle;

  /// No description provided for @collectionConnectionPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to a collection or card'**
  String get collectionConnectionPickerTitle;

  /// No description provided for @collectionNothingToLink.
  ///
  /// In en, this message translates to:
  /// **'Nothing to link to yet.'**
  String get collectionNothingToLink;

  /// No description provided for @collectionBackToCollections.
  ///
  /// In en, this message translates to:
  /// **'Back to collections'**
  String get collectionBackToCollections;

  /// No description provided for @collectionLinkToCollection.
  ///
  /// In en, this message translates to:
  /// **'Link to \"{label}\"'**
  String collectionLinkToCollection(String label);

  /// No description provided for @collectionNoCardsToLink.
  ///
  /// In en, this message translates to:
  /// **'No cards here to link to.'**
  String get collectionNoCardsToLink;

  /// No description provided for @linkPickerLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get linkPickerLinked;

  /// No description provided for @linkPickerChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get linkPickerChoose;

  /// No description provided for @linkPickerChosen.
  ///
  /// In en, this message translates to:
  /// **'Chosen'**
  String get linkPickerChosen;

  /// No description provided for @linkPickerChooseCollection.
  ///
  /// In en, this message translates to:
  /// **'Choose “{label}”'**
  String linkPickerChooseCollection(String label);

  /// No description provided for @linkPickerNewCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get linkPickerNewCollection;

  /// No description provided for @linkPickerLinkThere.
  ///
  /// In en, this message translates to:
  /// **'Link there'**
  String get linkPickerLinkThere;

  /// No description provided for @collectionLinkSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Link 1 card to…} other{Link {count} cards to…}}'**
  String collectionLinkSelectedTitle(int count);

  /// No description provided for @collectionOrACardInIt.
  ///
  /// In en, this message translates to:
  /// **'Or a card in it'**
  String get collectionOrACardInIt;

  /// No description provided for @collectionDescriptionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get collectionDescriptionEmpty;

  /// No description provided for @collectionEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit collection'**
  String get collectionEditTitle;

  /// No description provided for @collectionEditTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get collectionEditTitleHint;

  /// No description provided for @collectionEditDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get collectionEditDescriptionHint;

  /// No description provided for @collectionEditCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get collectionEditCover;

  /// No description provided for @collectionEditAddCover.
  ///
  /// In en, this message translates to:
  /// **'Add cover photo'**
  String get collectionEditAddCover;

  /// No description provided for @collectionEditReplaceCover.
  ///
  /// In en, this message translates to:
  /// **'Replace cover'**
  String get collectionEditReplaceCover;

  /// No description provided for @collectionEditRemoveCover.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get collectionEditRemoveCover;

  /// No description provided for @collectionEditMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get collectionEditMedia;

  /// No description provided for @collectionEditMediaEmpty.
  ///
  /// In en, this message translates to:
  /// **'No media yet'**
  String get collectionEditMediaEmpty;

  /// No description provided for @collectionMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get collectionMediaTitle;

  /// No description provided for @collectionMediaTabPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get collectionMediaTabPhotos;

  /// No description provided for @collectionMediaTabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get collectionMediaTabAudio;

  /// No description provided for @collectionMediaTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get collectionMediaTabFiles;

  /// No description provided for @collectionMediaTabLinks.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get collectionMediaTabLinks;

  /// No description provided for @collectionMediaEmptyTab.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get collectionMediaEmptyTab;

  /// No description provided for @collectionMediaLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load media'**
  String get collectionMediaLoadFailed;

  /// No description provided for @collectionMediaPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String collectionMediaPhotoCount(int count);

  /// No description provided for @collectionMediaAudioCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 audio} other{{count} audio}}'**
  String collectionMediaAudioCount(int count);

  /// No description provided for @collectionMediaFileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String collectionMediaFileCount(int count);

  /// No description provided for @collectionMediaLinkCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 link} other{{count} links}}'**
  String collectionMediaLinkCount(int count);

  /// No description provided for @cardEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit card'**
  String get cardEditTitle;

  /// No description provided for @cardEditHint.
  ///
  /// In en, this message translates to:
  /// **'Edit this card…'**
  String get cardEditHint;

  /// No description provided for @cardEditAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get cardEditAddPhoto;

  /// No description provided for @cardEditAttachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get cardEditAttachFile;

  /// No description provided for @cardEditAttachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get cardEditAttachment;

  /// No description provided for @cardEditReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get cardEditReplace;

  /// No description provided for @cardEditRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get cardEditRemove;

  /// No description provided for @cardEditRemoveAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get cardEditRemoveAll;

  /// No description provided for @cardEditOptimize.
  ///
  /// In en, this message translates to:
  /// **'Optimize'**
  String get cardEditOptimize;

  /// No description provided for @cardEditImageNotSmaller.
  ///
  /// In en, this message translates to:
  /// **'This photo can\'t be made smaller.'**
  String get cardEditImageNotSmaller;

  /// No description provided for @cardEditImageOptimized.
  ///
  /// In en, this message translates to:
  /// **'Photo optimized: {from} → {to}'**
  String cardEditImageOptimized(String from, String to);

  /// No description provided for @cardEditLinksHeader.
  ///
  /// In en, this message translates to:
  /// **'LINKS'**
  String get cardEditLinksHeader;

  /// No description provided for @cardEditNoLinks.
  ///
  /// In en, this message translates to:
  /// **'No links yet.'**
  String get cardEditNoLinks;

  /// No description provided for @cardEditAddLink.
  ///
  /// In en, this message translates to:
  /// **'Add link'**
  String get cardEditAddLink;

  /// No description provided for @cardEditBrokenLink.
  ///
  /// In en, this message translates to:
  /// **'Broken link'**
  String get cardEditBrokenLink;

  /// No description provided for @cardEditBrokenLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The linked item was deleted'**
  String get cardEditBrokenLinkSubtitle;

  /// No description provided for @cardEditSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t save. Please try again.'**
  String get cardEditSaveFailed;

  /// No description provided for @cardEditSettled.
  ///
  /// In en, this message translates to:
  /// **'Settled'**
  String get cardEditSettled;

  /// No description provided for @cardEditSettledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Kept for history, no longer current'**
  String get cardEditSettledSubtitle;

  /// No description provided for @cardEditEmphasized.
  ///
  /// In en, this message translates to:
  /// **'Emphasized'**
  String get cardEditEmphasized;

  /// No description provided for @cardEditEmphasizedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Stands out in the feed with a bright frame'**
  String get cardEditEmphasizedSubtitle;

  /// No description provided for @connectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connectionsTitle;

  /// No description provided for @connectionsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this link?'**
  String get connectionsClearTitle;

  /// No description provided for @connectionsClearBody.
  ///
  /// In en, this message translates to:
  /// **'The broken link will be removed. The cards and collections it pointed at are not deleted.'**
  String get connectionsClearBody;

  /// No description provided for @connectionsLinksOut.
  ///
  /// In en, this message translates to:
  /// **'Links out'**
  String get connectionsLinksOut;

  /// No description provided for @connectionsLinkedFrom.
  ///
  /// In en, this message translates to:
  /// **'Linked from'**
  String get connectionsLinkedFrom;

  /// No description provided for @connectionsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open in collection'**
  String get connectionsOpen;

  /// No description provided for @connectionsBrokenLink.
  ///
  /// In en, this message translates to:
  /// **'Broken link'**
  String get connectionsBrokenLink;

  /// No description provided for @connectionsLinkedDeleted.
  ///
  /// In en, this message translates to:
  /// **'The linked {kind} was deleted'**
  String connectionsLinkedDeleted(String kind);

  /// No description provided for @connectionsLinkingDeleted.
  ///
  /// In en, this message translates to:
  /// **'The linking {kind} was deleted'**
  String connectionsLinkingDeleted(String kind);

  /// No description provided for @connectionsKindCollection.
  ///
  /// In en, this message translates to:
  /// **'collection'**
  String get connectionsKindCollection;

  /// No description provided for @connectionsKindCard.
  ///
  /// In en, this message translates to:
  /// **'card'**
  String get connectionsKindCard;

  /// No description provided for @connectionsKindItem.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get connectionsKindItem;

  /// No description provided for @connectionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No connections yet'**
  String get connectionsEmptyTitle;

  /// No description provided for @connectionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Link a card to a collection and it will show up here.'**
  String get connectionsEmptyBody;

  /// No description provided for @connectionsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load connections.'**
  String get connectionsLoadError;

  /// No description provided for @connectionsClearFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t clear. Please try again.'**
  String get connectionsClearFailed;

  /// No description provided for @connectionsMentionedIn.
  ///
  /// In en, this message translates to:
  /// **'Mentioned in'**
  String get connectionsMentionedIn;

  /// No description provided for @connectionsMentionsMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String connectionsMentionsMore(int count);

  /// No description provided for @connectionsLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t link. Please try again.'**
  String get connectionsLinkFailed;

  /// No description provided for @connectionsLinkActions.
  ///
  /// In en, this message translates to:
  /// **'Link actions'**
  String get connectionsLinkActions;

  /// No description provided for @connectionsRemoveLink.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get connectionsRemoveLink;

  /// No description provided for @connectionsLinkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Link removed'**
  String get connectionsLinkRemoved;

  /// No description provided for @connectionsRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t remove. Please try again.'**
  String get connectionsRemoveFailed;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get profileNicknameLabel;

  /// No description provided for @profileEditNickname.
  ///
  /// In en, this message translates to:
  /// **'Edit nickname'**
  String get profileEditNickname;

  /// No description provided for @profileRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit nickname'**
  String get profileRenameTitle;

  /// No description provided for @profileRenameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. mira'**
  String get profileRenameHint;

  /// No description provided for @profileRenameFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your nickname. Please try again.'**
  String get profileRenameFailed;

  /// No description provided for @profilePublicKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get profilePublicKeyLabel;

  /// No description provided for @profileCopyKey.
  ///
  /// In en, this message translates to:
  /// **'Copy public key'**
  String get profileCopyKey;

  /// No description provided for @profileKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Public key copied'**
  String get profileKeyCopied;

  /// No description provided for @profileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile.'**
  String get profileLoadError;

  /// No description provided for @profileOpen.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileOpen;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsOpen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsOpen;

  /// No description provided for @settingsDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsDataTitle;

  /// No description provided for @settingsDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export, import, and manage your data'**
  String get settingsDataSubtitle;

  /// No description provided for @settingsThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeTitle;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsKeepPhotoMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep photo metadata'**
  String get settingsKeepPhotoMetadataTitle;

  /// No description provided for @settingsKeepPhotoMetadataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When a photo is optimized, keep its camera, date and location details'**
  String get settingsKeepPhotoMetadataSubtitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get settingsLanguageRussian;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version and app info'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsAboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A local-first space for weaving your thoughts together.'**
  String get settingsAboutTagline;

  /// No description provided for @settingsAboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersionLabel;

  /// No description provided for @settingsDataTransferSection.
  ///
  /// In en, this message translates to:
  /// **'Backup & transfer'**
  String get settingsDataTransferSection;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get settingsExport;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save your collections, cards and key to a file'**
  String get settingsExportSubtitle;

  /// No description provided for @settingsImport.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get settingsImport;

  /// No description provided for @settingsImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore from a previously exported file'**
  String get settingsImportSubtitle;

  /// No description provided for @settingsDangerSection.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsDangerSection;

  /// No description provided for @settingsWipeData.
  ///
  /// In en, this message translates to:
  /// **'Wipe data'**
  String get settingsWipeData;

  /// No description provided for @settingsWipeDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all collections and cards on this device'**
  String get settingsWipeDataSubtitle;

  /// No description provided for @settingsResetIdentity.
  ///
  /// In en, this message translates to:
  /// **'Reset identity'**
  String get settingsResetIdentity;

  /// No description provided for @settingsResetIdentitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all data and this device\'s key, then start over'**
  String get settingsResetIdentitySubtitle;

  /// No description provided for @settingsExportChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get settingsExportChooseTitle;

  /// No description provided for @settingsExportChooseShare.
  ///
  /// In en, this message translates to:
  /// **'Share…'**
  String get settingsExportChooseShare;

  /// No description provided for @settingsExportChooseShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send the backup to another app'**
  String get settingsExportChooseShareSubtitle;

  /// No description provided for @settingsExportChooseSave.
  ///
  /// In en, this message translates to:
  /// **'Save to a file'**
  String get settingsExportChooseSave;

  /// No description provided for @settingsExportChooseSaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose where to keep the backup'**
  String get settingsExportChooseSaveSubtitle;

  /// No description provided for @settingsBackupExported.
  ///
  /// In en, this message translates to:
  /// **'Backup ready to share'**
  String get settingsBackupExported;

  /// No description provided for @settingsBackupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved'**
  String get settingsBackupSaved;

  /// No description provided for @settingsBackupExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the backup'**
  String get settingsBackupExportFailed;

  /// No description provided for @settingsBackupImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore the backup'**
  String get settingsBackupImportFailed;

  /// No description provided for @settingsBackupImported.
  ///
  /// In en, this message translates to:
  /// **'Restored {applied} items ({deduped} already present)'**
  String settingsBackupImported(int applied, int deduped);

  /// No description provided for @settingsBackupImportWarning.
  ///
  /// In en, this message translates to:
  /// **'{quarantined} ops skipped, {mismatched} files corrupt'**
  String settingsBackupImportWarning(int quarantined, int mismatched);

  /// No description provided for @settingsWipeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Wipe all data?'**
  String get settingsWipeConfirmTitle;

  /// No description provided for @settingsWipeConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes every collection, card, and link on this device. Your identity is kept. This can\'t be undone — export a backup first if you might want this data back.'**
  String get settingsWipeConfirmMessage;

  /// No description provided for @settingsWipeConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Wipe data'**
  String get settingsWipeConfirmAction;

  /// No description provided for @settingsWipeDone.
  ///
  /// In en, this message translates to:
  /// **'All data wiped'**
  String get settingsWipeDone;

  /// No description provided for @settingsWipeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t wipe the data'**
  String get settingsWipeFailed;

  /// No description provided for @settingsExportPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your key'**
  String get settingsExportPassphraseTitle;

  /// No description provided for @settingsExportPassphraseMessage.
  ///
  /// In en, this message translates to:
  /// **'The backup includes your private key. Choose a passphrase to encrypt it — you\'ll need it to restore the backup, and it can\'t be recovered if you forget it.'**
  String get settingsExportPassphraseMessage;

  /// No description provided for @settingsPassphraseLabel.
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get settingsPassphraseLabel;

  /// No description provided for @settingsPassphraseConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat passphrase'**
  String get settingsPassphraseConfirmLabel;

  /// No description provided for @settingsPassphraseTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least {min} characters'**
  String settingsPassphraseTooShort(int min);

  /// No description provided for @settingsPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passphrases don\'t match'**
  String get settingsPassphraseMismatch;

  /// No description provided for @settingsExportPassphraseAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get settingsExportPassphraseAction;

  /// No description provided for @settingsReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace this device?'**
  String get settingsReplaceTitle;

  /// No description provided for @settingsReplaceMessage.
  ///
  /// In en, this message translates to:
  /// **'This backup from {date} belongs to another identity. Restoring it deletes everything on this device, including your key, and makes you that identity. Enter the backup\'s passphrase to continue.'**
  String settingsReplaceMessage(String date);

  /// No description provided for @settingsReplaceWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase'**
  String get settingsReplaceWrongPassphrase;

  /// No description provided for @settingsReplaceAction.
  ///
  /// In en, this message translates to:
  /// **'Erase and restore'**
  String get settingsReplaceAction;

  /// No description provided for @settingsDeviceReplaced.
  ///
  /// In en, this message translates to:
  /// **'Backup restored — {applied} items'**
  String settingsDeviceReplaced(int applied);

  /// No description provided for @settingsResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset identity?'**
  String get settingsResetConfirmTitle;

  /// No description provided for @settingsResetConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes every collection, card and link on this device, and your key. Without a backup, nothing you made can be restored as you. Type {word} to confirm.'**
  String settingsResetConfirmMessage(String word);

  /// No description provided for @settingsResetConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetConfirmAction;

  /// No description provided for @settingsResetBackupFirst.
  ///
  /// In en, this message translates to:
  /// **'Back up first'**
  String get settingsResetBackupFirst;

  /// No description provided for @settingsResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reset the identity'**
  String get settingsResetFailed;

  /// No description provided for @syncAllSaved.
  ///
  /// In en, this message translates to:
  /// **'All changes saved'**
  String get syncAllSaved;

  /// No description provided for @syncUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sync status unavailable'**
  String get syncUnavailable;

  /// No description provided for @syncPending.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change saved on this device — not yet shared} other{{count} changes saved on this device — not yet shared}}'**
  String syncPending(int count);

  /// No description provided for @searchOpen.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchOpen;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search collections and cards'**
  String get searchHint;

  /// No description provided for @searchIdle.
  ///
  /// In en, this message translates to:
  /// **'Type a query and press search'**
  String get searchIdle;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t run the search'**
  String get searchFailed;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for “{query}”'**
  String searchNoResults(String query);

  /// No description provided for @searchFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchFilterAll;

  /// No description provided for @searchFilterCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get searchFilterCollections;

  /// No description provided for @searchFilterCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get searchFilterCards;

  /// No description provided for @searchHintScoped.
  ///
  /// In en, this message translates to:
  /// **'Search cards in this collection'**
  String get searchHintScoped;

  /// No description provided for @searchScopeChip.
  ///
  /// In en, this message translates to:
  /// **'In: {title}'**
  String searchScopeChip(String title);

  /// No description provided for @searchScopeClear.
  ///
  /// In en, this message translates to:
  /// **'Search everywhere'**
  String get searchScopeClear;

  /// No description provided for @searchKindText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get searchKindText;

  /// No description provided for @searchKindImage.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get searchKindImage;

  /// No description provided for @searchKindLink.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get searchKindLink;

  /// No description provided for @searchKindFile.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get searchKindFile;

  /// No description provided for @searchKindAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get searchKindAudio;

  /// No description provided for @searchSettledAny.
  ///
  /// In en, this message translates to:
  /// **'Settled: any'**
  String get searchSettledAny;

  /// No description provided for @searchSettledLive.
  ///
  /// In en, this message translates to:
  /// **'Live only'**
  String get searchSettledLive;

  /// No description provided for @searchSettledOnly.
  ///
  /// In en, this message translates to:
  /// **'Settled only'**
  String get searchSettledOnly;

  /// No description provided for @searchIncludeArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get searchIncludeArchived;

  /// No description provided for @searchLinkedTo.
  ///
  /// In en, this message translates to:
  /// **'Linked to…'**
  String get searchLinkedTo;

  /// No description provided for @searchLinkedToChip.
  ///
  /// In en, this message translates to:
  /// **'→ {label}'**
  String searchLinkedToChip(String label);

  /// No description provided for @searchLinkedToRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from filter'**
  String get searchLinkedToRemove;

  /// No description provided for @searchNothingLinked.
  ///
  /// In en, this message translates to:
  /// **'Nothing linked matches'**
  String get searchNothingLinked;

  /// No description provided for @searchInCollection.
  ///
  /// In en, this message translates to:
  /// **'in {title}'**
  String searchInCollection(String title);

  /// No description provided for @collectionSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String collectionSelectedCount(int count);

  /// No description provided for @collectionSelectAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get collectionSelectAllTooltip;

  /// No description provided for @collectionUnselectAll.
  ///
  /// In en, this message translates to:
  /// **'Unselect all'**
  String get collectionUnselectAll;

  /// No description provided for @collectionClearSelectionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get collectionClearSelectionTooltip;

  /// No description provided for @collectionMoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Move to collection'**
  String get collectionMoveTooltip;

  /// No description provided for @collectionMoveShort.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get collectionMoveShort;

  /// No description provided for @collectionLinkSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Link to…'**
  String get collectionLinkSelectedTooltip;

  /// No description provided for @collectionDeleteSelectedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get collectionDeleteSelectedTooltip;

  /// No description provided for @collectionDeleteSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 card?} other{Delete {count} cards?}}'**
  String collectionDeleteSelectedTitle(int count);

  /// No description provided for @collectionDeleteSelectedBody.
  ///
  /// In en, this message translates to:
  /// **'Links to them will show as broken.'**
  String get collectionDeleteSelectedBody;

  /// No description provided for @collectionMoveSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to…'**
  String get collectionMoveSheetTitle;

  /// No description provided for @collectionMoveNewCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get collectionMoveNewCollection;

  /// No description provided for @collectionMoveThere.
  ///
  /// In en, this message translates to:
  /// **'Move there'**
  String get collectionMoveThere;

  /// No description provided for @pickerRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get pickerRecent;

  /// No description provided for @collectionMoveNoTargets.
  ///
  /// In en, this message translates to:
  /// **'No other collections yet.'**
  String get collectionMoveNoTargets;

  /// No description provided for @collectionMoveTargetsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load collections.'**
  String get collectionMoveTargetsError;

  /// No description provided for @collectionCardsMoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Moved 1 card to “{title}”} other{Moved {count} cards to “{title}”}}'**
  String collectionCardsMoved(int count, String title);

  /// No description provided for @collectionCardsMovedOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get collectionCardsMovedOpen;

  /// No description provided for @collectionCardsLinked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Linked 1 card to “{title}”} other{Linked {count} cards to “{title}”}}'**
  String collectionCardsLinked(int count, String title);

  /// No description provided for @collectionCardsAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'Already linked to “{title}”'**
  String collectionCardsAlreadyLinked(String title);

  /// No description provided for @shareCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Save to Knit'**
  String get shareCaptureTitle;

  /// No description provided for @shareCaptureSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Find a collection'**
  String get shareCaptureSearchHint;

  /// No description provided for @shareCaptureNewCollection.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get shareCaptureNewCollection;

  /// No description provided for @shareCaptureEmpty.
  ///
  /// In en, this message translates to:
  /// **'No collections yet — create one to save into'**
  String get shareCaptureEmpty;

  /// No description provided for @shareCaptureNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching collections'**
  String get shareCaptureNoMatches;

  /// No description provided for @shareCaptureLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your collections'**
  String get shareCaptureLoadError;

  /// No description provided for @shareCaptureSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save everything — try again'**
  String get shareCaptureSaveError;

  /// No description provided for @shareCaptureNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up Knit first — the shared item wasn\'t saved'**
  String get shareCaptureNeedsSetup;

  /// No description provided for @shareCaptureItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String shareCaptureItemCount(int count);

  /// No description provided for @shareCaptureSaved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Saved 1 card to “{title}”} other{Saved {count} cards to “{title}”}}'**
  String shareCaptureSaved(int count, String title);

  /// No description provided for @collectionWidgetPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a collection for the widget'**
  String get collectionWidgetPickTitle;

  /// No description provided for @collectionWidgetEmpty.
  ///
  /// In en, this message translates to:
  /// **'No collections yet — create one in Knit first'**
  String get collectionWidgetEmpty;

  /// No description provided for @collectionWidgetSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set up the widget — try again'**
  String get collectionWidgetSaveError;

  /// No description provided for @collectionWidgetNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'Set up Knit first, then tap the widget again'**
  String get collectionWidgetNeedsSetup;

  /// No description provided for @collectionWidgetRemoved.
  ///
  /// In en, this message translates to:
  /// **'That collection was removed — tap the widget to pick another'**
  String get collectionWidgetRemoved;

  /// No description provided for @collectionMoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get collectionMoreTooltip;

  /// No description provided for @collectionMenuPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get collectionMenuPresent;

  /// No description provided for @collectionMenuOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get collectionMenuOutline;

  /// No description provided for @collectionMenuSearch.
  ///
  /// In en, this message translates to:
  /// **'Search in collection'**
  String get collectionMenuSearch;

  /// No description provided for @collectionMenuFindLinked.
  ///
  /// In en, this message translates to:
  /// **'Find linked cards'**
  String get collectionMenuFindLinked;

  /// No description provided for @collectionOutlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get collectionOutlineTitle;

  /// No description provided for @collectionOutlineEmpty.
  ///
  /// In en, this message translates to:
  /// **'No headings yet. Emphasize a card to make it a heading: it shows up here, and opens a slide when you present.'**
  String get collectionOutlineEmpty;

  /// No description provided for @collectionOutlineError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the outline.'**
  String get collectionOutlineError;

  /// No description provided for @collectionMenuReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder cards'**
  String get collectionMenuReorder;

  /// No description provided for @collectionMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get collectionMenuDelete;

  /// No description provided for @presentSlideCount.
  ///
  /// In en, this message translates to:
  /// **'{index} / {count}'**
  String presentSlideCount(int index, int count);

  /// No description provided for @presentContinueFrom.
  ///
  /// In en, this message translates to:
  /// **'Continue from slide {number}'**
  String presentContinueFrom(int number);

  /// No description provided for @presentSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe up to start'**
  String get presentSwipeHint;

  /// No description provided for @presentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to present yet'**
  String get presentEmpty;

  /// No description provided for @presentLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this collection'**
  String get presentLoadFailed;

  /// No description provided for @presentSeeAlso.
  ///
  /// In en, this message translates to:
  /// **'See also'**
  String get presentSeeAlso;

  /// No description provided for @presentNextTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next slide'**
  String get presentNextTooltip;

  /// No description provided for @presentPreviousTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous slide'**
  String get presentPreviousTooltip;

  /// No description provided for @collectionMenuShareFile.
  ///
  /// In en, this message translates to:
  /// **'Share as file'**
  String get collectionMenuShareFile;

  /// No description provided for @shareExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Share as file'**
  String get shareExportTitle;

  /// No description provided for @shareExportSummary.
  ///
  /// In en, this message translates to:
  /// **'{title} · {count, plural, =1{1 card} other{{count} cards}}'**
  String shareExportSummary(String title, int count);

  /// No description provided for @shareExportIncludeMedia.
  ///
  /// In en, this message translates to:
  /// **'Include media'**
  String get shareExportIncludeMedia;

  /// No description provided for @shareExportMediaSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}} · {size}'**
  String shareExportMediaSummary(int count, String size);

  /// No description provided for @shareExportSize.
  ///
  /// In en, this message translates to:
  /// **'File size: {size}'**
  String shareExportSize(String size);

  /// No description provided for @shareExportHint.
  ///
  /// In en, this message translates to:
  /// **'The recipient sees it read-only, marked as from you, and can save their own copy.'**
  String get shareExportHint;

  /// No description provided for @shareExportSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get shareExportSend;

  /// No description provided for @shareExportSave.
  ///
  /// In en, this message translates to:
  /// **'Save to file'**
  String get shareExportSave;

  /// No description provided for @shareExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the file. Please try again.'**
  String get shareExportFailed;

  /// No description provided for @shareExportLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read this collection.'**
  String get shareExportLoadFailed;

  /// No description provided for @shareExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Collection file saved'**
  String get shareExportSaved;

  /// No description provided for @shareImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import collection'**
  String get shareImportTitle;

  /// No description provided for @shareImportReading.
  ///
  /// In en, this message translates to:
  /// **'Reading the file…'**
  String get shareImportReading;

  /// No description provided for @shareImportSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card} other{{count} cards}} · from {handle}'**
  String shareImportSummary(int count, String handle);

  /// No description provided for @shareImportNoMedia.
  ///
  /// In en, this message translates to:
  /// **'Media not included'**
  String get shareImportNoMedia;

  /// No description provided for @shareImportReadOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'It arrives read-only. You can save your own copy later.'**
  String get shareImportReadOnlyHint;

  /// No description provided for @shareImportOwnHint.
  ///
  /// In en, this message translates to:
  /// **'This is your own collection. It merges into the one on this device.'**
  String get shareImportOwnHint;

  /// No description provided for @shareImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get shareImportAction;

  /// No description provided for @shareImportUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get shareImportUpdate;

  /// No description provided for @shareImportUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a Knit collection file, or it\'s damaged.'**
  String get shareImportUnreadable;

  /// No description provided for @shareImportNewer.
  ///
  /// In en, this message translates to:
  /// **'This file is from a newer Knit. Update the app to open it.'**
  String get shareImportNewer;

  /// No description provided for @shareImportRefused.
  ///
  /// In en, this message translates to:
  /// **'This file failed its safety checks, so nothing was imported.'**
  String get shareImportRefused;

  /// No description provided for @shareImportFailed.
  ///
  /// In en, this message translates to:
  /// **'The import stopped part-way. Import the file again to finish it.'**
  String get shareImportFailed;

  /// No description provided for @settingsImportCollection.
  ///
  /// In en, this message translates to:
  /// **'Import collection'**
  String get settingsImportCollection;

  /// No description provided for @settingsImportCollectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open a .knitc file someone shared with you'**
  String get settingsImportCollectionSubtitle;

  /// No description provided for @collectionActionConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get collectionActionConnections;

  /// No description provided for @collectionActionLinkFromMine.
  ///
  /// In en, this message translates to:
  /// **'Link from my card…'**
  String get collectionActionLinkFromMine;

  /// No description provided for @collectionLinkFromMineTitle.
  ///
  /// In en, this message translates to:
  /// **'Link from which of your cards?'**
  String get collectionLinkFromMineTitle;

  /// No description provided for @collectionReadOnlyFrom.
  ///
  /// In en, this message translates to:
  /// **'Read-only · from {handle}'**
  String collectionReadOnlyFrom(String handle);

  /// Home row line listing the collections that link to this one (joined by ' · ').
  ///
  /// In en, this message translates to:
  /// **'in: {names}'**
  String timelineInHubs(String names);

  /// The in: line when more collections link here than are named.
  ///
  /// In en, this message translates to:
  /// **'in: {names} +{more}'**
  String timelineInHubsMore(String names, int more);

  /// No description provided for @collectionLinkTileOpen.
  ///
  /// In en, this message translates to:
  /// **'Open collection'**
  String get collectionLinkTileOpen;

  /// No description provided for @collectionCardLinkTileOpen.
  ///
  /// In en, this message translates to:
  /// **'Open card'**
  String get collectionCardLinkTileOpen;

  /// No description provided for @collectionCardLinkTileIn.
  ///
  /// In en, this message translates to:
  /// **'in {title}'**
  String collectionCardLinkTileIn(String title);

  /// No description provided for @timelineFromHandle.
  ///
  /// In en, this message translates to:
  /// **'from {handle}'**
  String timelineFromHandle(String handle);

  /// No description provided for @collectionMenuSaveCopy.
  ///
  /// In en, this message translates to:
  /// **'Save a copy'**
  String get collectionMenuSaveCopy;

  /// No description provided for @collectionMenuRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from this device'**
  String get collectionMenuRemove;

  /// No description provided for @collectionCopySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved your own copy'**
  String get collectionCopySaved;

  /// No description provided for @collectionCopyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save a copy. Please try again.'**
  String get collectionCopyFailed;

  /// No description provided for @collectionRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this collection?'**
  String get collectionRemoveTitle;

  /// No description provided for @collectionRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” and its media leave this device. Importing the file again brings it back.'**
  String collectionRemoveBody(String title);

  /// No description provided for @collectionRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get collectionRemoveAction;

  /// No description provided for @collectionRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove the collection. Please try again.'**
  String get collectionRemoveFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
