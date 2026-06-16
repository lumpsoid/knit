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

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

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

  /// No description provided for @timelineCollectionFab.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get timelineCollectionFab;

  /// No description provided for @timelineNewCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get timelineNewCollectionTitle;

  /// No description provided for @timelineNewCollectionHint.
  ///
  /// In en, this message translates to:
  /// **'Title or theme'**
  String get timelineNewCollectionHint;

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

  /// No description provided for @collectionAddLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a link'**
  String get collectionAddLinkTitle;

  /// No description provided for @collectionAddLinkHint.
  ///
  /// In en, this message translates to:
  /// **'https://…'**
  String get collectionAddLinkHint;

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

  /// No description provided for @collectionReorderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get collectionReorderTooltip;

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

  /// No description provided for @collectionBlockLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get collectionBlockLink;

  /// No description provided for @collectionBlockLinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A standalone link card'**
  String get collectionBlockLinkSubtitle;

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

  /// No description provided for @collectionActionConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get collectionActionConnections;

  /// No description provided for @collectionActionReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get collectionActionReorder;

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

  /// No description provided for @collectionOrACardInIt.
  ///
  /// In en, this message translates to:
  /// **'Or a card in it'**
  String get collectionOrACardInIt;

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
  /// **'Add photo'**
  String get cardEditAddPhoto;

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

  /// No description provided for @cardEditLinkToWhichCollection.
  ///
  /// In en, this message translates to:
  /// **'Link to which collection?'**
  String get cardEditLinkToWhichCollection;

  /// No description provided for @cardEditSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t save. Please try again.'**
  String get cardEditSaveFailed;

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
  /// **'Save your collections and cards to a file'**
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

  /// No description provided for @settingsExportIdentity.
  ///
  /// In en, this message translates to:
  /// **'Export identity'**
  String get settingsExportIdentity;

  /// No description provided for @settingsExportIdentitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your private key so you can restore \"you\"'**
  String get settingsExportIdentitySubtitle;

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
  /// **'Discard this device\'s key and start over'**
  String get settingsResetIdentitySubtitle;

  /// No description provided for @settingsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{feature} — coming soon'**
  String settingsComingSoon(String feature);

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
