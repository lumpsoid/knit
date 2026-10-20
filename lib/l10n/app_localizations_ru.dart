// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Knit';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get actionCreate => 'Создать';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get actionClear => 'Очистить';

  @override
  String get actionRemove => 'Убрать';

  @override
  String get actionDone => 'Готово';

  @override
  String get actionAdd => 'Добавить';

  @override
  String get actionLink => 'Связать';

  @override
  String get actionContinue => 'Продолжить';

  @override
  String get actionOpen => 'Открыть';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionPin => 'Закрепить';

  @override
  String get actionUnpin => 'Открепить';

  @override
  String get actionArchive => 'В архив';

  @override
  String get actionUnarchive => 'Вернуть из архива';

  @override
  String get labelUntitled => 'Без названия';

  @override
  String get labelEmptyNote => 'Пустая заметка';

  @override
  String get errorGeneric => 'Что-то пошло не так';

  @override
  String get appLaunchError => 'Не удалось запустить Knit';

  @override
  String get appLaunchUnknownError => 'Неизвестная ошибка';

  @override
  String get onboardWelcomeTitle => 'Добро пожаловать в Knit';

  @override
  String get onboardWelcomeBody =>
      'Сохраняйте что угодно в виде карточек, сплетённых в ваши собственные коллекции. Local-first — ваши данные хранятся на вашем устройстве.';

  @override
  String get onboardGetStarted => 'Начать';

  @override
  String get onboardNicknameTitle => 'Как к вам обращаться?';

  @override
  String get onboardNicknameBody =>
      'Никнейм — это просто метка: ваша личность определяется ключом, а не этим именем. Его можно изменить в любой момент.';

  @override
  String get onboardNicknameLabel => 'Никнейм';

  @override
  String get onboardNicknameHint => 'напр. mira';

  @override
  String get onboardExplainTitle => 'Ваша личность — это ключ';

  @override
  String get onboardExplainKeyPair =>
      'Мы создадим на этом устройстве криптографическую пару ключей. Публичный ключ И ЕСТЬ ваша личность — а не имя пользователя на чьём-то сервере.';

  @override
  String get onboardExplainPrivate =>
      'Приватная половина никогда не покидает ваше устройство. Берегите её — создав её резервную копию позже (в настройках), вы сохраните «себя».';

  @override
  String onboardExplainNickname(String nickname) {
    return 'Привет, $nickname — ваш ключ — это кто вы есть, а никнейм — то, как вас называют.';
  }

  @override
  String get onboardGenerate => 'Создать мою личность';

  @override
  String get onboardIdentityError =>
      'Не удалось создать вашу личность. Попробуйте ещё раз.';

  @override
  String get onboardGeneratingTitle => 'Создаём вашу пару ключей…';

  @override
  String get onboardGeneratingBody =>
      'Генерируем ключи Ed25519 и подписываем ваш профиль.';

  @override
  String get onboardRevealTitle => 'Знакомьтесь — это вы';

  @override
  String get onboardKeyTagline =>
      'ключ = кто вы есть · никнейм = как вас называют';

  @override
  String get onboardPrivateKeyNote =>
      'Ваш приватный ключ хранится только на этом устройстве. Создайте его резервную копию позже в настройках.';

  @override
  String get onboardEnter => 'Войти в Knit';

  @override
  String get onboardCopyPublicKey => 'Скопировать публичный ключ';

  @override
  String get onboardPublicKeyCopied => 'Публичный ключ скопирован';

  @override
  String get onboardRestore => 'Восстановить из копии';

  @override
  String get onboardRestoreTitle => 'Восстановление копии';

  @override
  String onboardRestoreBody(String date) {
    return 'Введите пароль, который вы задали при экспорте этой копии $date.';
  }

  @override
  String get onboardRestoreAction => 'Восстановить';

  @override
  String get onboardRestoreWrongPassphrase => 'Неверный пароль';

  @override
  String get onboardRestoringTitle => 'Восстанавливаем копию…';

  @override
  String get onboardRestoringBody => 'Открываем ключ и переносим карточки.';

  @override
  String get onboardRestoreUnreadable =>
      'Этот файл не является резервной копией Knit.';

  @override
  String get onboardRestoreNoIdentity =>
      'Эта копия создана до того, как копии стали включать ключ, поэтому личность из неё не восстановить. Создайте новую личность, затем импортируйте копию в настройках.';

  @override
  String get onboardRestoreFailed =>
      'Не удалось восстановить копию. Попробуйте ещё раз.';

  @override
  String get onboardWelcomeBackTitle => 'С возвращением';

  @override
  String get timelineCollectionFab => 'Коллекция';

  @override
  String get timelineNewCollectionTitle => 'Новая коллекция';

  @override
  String get timelineNewCollectionHint => 'Название или тема';

  @override
  String get timelineDeleteTitle => 'Удалить коллекцию?';

  @override
  String timelineDeleteBody(String title) {
    return '«$title» и её карточки будут удалены.';
  }

  @override
  String get timelineEmptyTitle => 'Пока нет коллекций';

  @override
  String get timelineEmptyBody =>
      'Коллекции — это блокноты с карточками в стиле чата.\nСоздайте одну, чтобы начать сплетать всё воедино.';

  @override
  String get timelineLoadError => 'Не удалось загрузить ваши коллекции.';

  @override
  String get timelineCreateFailed =>
      'Не удалось создать коллекцию. Попробуйте ещё раз.';

  @override
  String get timelineDeleteFailed =>
      'Не удалось удалить коллекцию. Попробуйте ещё раз.';

  @override
  String timelineCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки',
      many: '$count карточек',
      few: '$count карточки',
      one: '1 карточка',
    );
    return '$_temp0';
  }

  @override
  String get timelinePinnedSection => 'Закреплённые';

  @override
  String get timelineRecentSection => 'Недавние';

  @override
  String get timelinePinFailed =>
      'Не удалось изменить закрепление. Попробуйте ещё раз.';

  @override
  String get timelineArchiveFailed =>
      'Не удалось обновить архив. Попробуйте ещё раз.';

  @override
  String get timelineArchiveRow => 'Архив';

  @override
  String timelineArchiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count коллекции',
      many: '$count коллекций',
      few: '$count коллекции',
      one: '1 коллекция',
    );
    return '$_temp0';
  }

  @override
  String get archiveTitle => 'Архив';

  @override
  String get archiveEmpty => 'В архиве пусто';

  @override
  String get timelineNoCardsYet => 'Пока нет карточек';

  @override
  String get timelinePreviewPhoto => '📷 Фото';

  @override
  String get timelinePreviewAudio => '🎙 Аудио';

  @override
  String get timelinePreviewLink => '🔗 Ссылка';

  @override
  String get timeNow => 'сейчас';

  @override
  String timeMinutesShort(int count) {
    return '$count мин';
  }

  @override
  String timeHoursShort(int count) {
    return '$count ч';
  }

  @override
  String timeDaysShort(int count) {
    return '$count д';
  }

  @override
  String get collectionAddLinkTitle => 'Добавить ссылку';

  @override
  String get collectionAddLinkHint => 'https://…';

  @override
  String get collectionLinkOpenFailed => 'Не удалось открыть ссылку';

  @override
  String get collectionRenameTitle => 'Переименовать коллекцию';

  @override
  String get collectionComposerHint => 'Напишите карточку…';

  @override
  String get collectionAddBlockTooltip => 'Добавить блок';

  @override
  String get collectionSendTooltip => 'Отправить';

  @override
  String get collectionConnectionsTooltip => 'Связи';

  @override
  String collectionCardConnections(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count связей',
      few: '$count связи',
      one: '1 связь',
    );
    return '$_temp0';
  }

  @override
  String get collectionReorderTooltip => 'Изменить порядок';

  @override
  String collectionComingSoon(String feature) {
    return '$feature — скоро';
  }

  @override
  String get collectionPhotoCards => 'Фотокарточки';

  @override
  String get collectionAudioCards => 'Аудиокарточки';

  @override
  String get collectionBlockLink => 'Ссылка';

  @override
  String get collectionBlockLinkSubtitle => 'Отдельная карточка-ссылка';

  @override
  String get collectionBlockPhoto => 'Фото';

  @override
  String get collectionBlockAudio => 'Аудио';

  @override
  String get collectionBlockFile => 'Файл';

  @override
  String get collectionPhotoSourceGallery => 'Галерея';

  @override
  String get collectionPhotoSourceCamera => 'Камера';

  @override
  String get collectionAudioStart => 'Начать запись';

  @override
  String get collectionAudioStop => 'Стоп';

  @override
  String get collectionAudioPause => 'Пауза';

  @override
  String get collectionAudioResume => 'Продолжить';

  @override
  String get collectionAudioRecording => 'Запись';

  @override
  String get collectionAudioPaused => 'Пауза';

  @override
  String get collectionAudioPlay => 'Воспроизвести';

  @override
  String get collectionAudioNowPlaying => 'Сейчас играет';

  @override
  String get collectionAudioMessage => 'Аудиосообщение';

  @override
  String get collectionAudioPermissionDenied =>
      'Для записи аудио нужен доступ к микрофону.';

  @override
  String get collectionActionEdit => 'Изменить';

  @override
  String get collectionActionMakeLink => 'Создать связь';

  @override
  String get collectionActionCopy => 'Копировать';

  @override
  String get collectionCopied => 'Скопировано в буфер обмена';

  @override
  String get collectionActionShare => 'Поделиться';

  @override
  String get collectionActionSettle => 'Приглушить';

  @override
  String get collectionActionUnsettle => 'Оживить';

  @override
  String get collectionCardSettled => 'Приглушена';

  @override
  String get collectionActionDelete => 'Удалить';

  @override
  String get collectionCardLink => 'Ссылка';

  @override
  String get collectionCardPhoto => 'Фото';

  @override
  String get collectionCardAudio => 'Аудио';

  @override
  String get collectionCardFile => 'Файл';

  @override
  String get collectionReorderPhoto => '[Фото]';

  @override
  String get collectionEmptyTitle => 'Пока нет карточек';

  @override
  String get collectionEmptyBody =>
      'Напишите первую карточку ниже или нажмите +, чтобы добавить блок.';

  @override
  String get collectionLoadError => 'Не удалось загрузить эту коллекцию.';

  @override
  String get collectionSaveFailed =>
      'Не удалось сохранить. Попробуйте ещё раз.';

  @override
  String get collectionLinkFinderTitle => 'Создать связь';

  @override
  String get collectionNothingToLink => 'Пока не с чем связывать.';

  @override
  String get collectionBackToCollections => 'Назад к коллекциям';

  @override
  String collectionLinkToCollection(String label) {
    return 'Связать с «$label»';
  }

  @override
  String get collectionNoCardsToLink => 'Здесь нет карточек для связи.';

  @override
  String get collectionOrACardInIt => 'Или карточку в ней';

  @override
  String get collectionAppBarTitle => 'Коллекция';

  @override
  String get collectionDescriptionEmpty => 'Без описания';

  @override
  String get collectionEditTitle => 'Редактировать коллекцию';

  @override
  String get collectionEditTitleHint => 'Название';

  @override
  String get collectionEditDescriptionHint => 'Описание (необязательно)';

  @override
  String get collectionEditCover => 'Обложка';

  @override
  String get collectionEditAddCover => 'Добавить обложку';

  @override
  String get collectionEditReplaceCover => 'Заменить обложку';

  @override
  String get collectionEditRemoveCover => 'Удалить обложку';

  @override
  String get collectionEditMedia => 'Медиа';

  @override
  String get collectionEditMediaEmpty => 'Пока нет медиа';

  @override
  String get collectionMediaTitle => 'Медиа';

  @override
  String get collectionMediaTabPhotos => 'Фото';

  @override
  String get collectionMediaTabAudio => 'Аудио';

  @override
  String get collectionMediaTabFiles => 'Файлы';

  @override
  String get collectionMediaTabLinks => 'Ссылки';

  @override
  String get collectionMediaEmptyTab => 'Здесь пока пусто';

  @override
  String get collectionMediaLoadFailed => 'Не удалось загрузить медиа';

  @override
  String collectionMediaPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      many: '$count фото',
      few: '$count фото',
      one: '$count фото',
    );
    return '$_temp0';
  }

  @override
  String collectionMediaAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count аудио',
      many: '$count аудио',
      few: '$count аудио',
      one: '$count аудио',
    );
    return '$_temp0';
  }

  @override
  String collectionMediaFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла',
      many: '$count файлов',
      few: '$count файла',
      one: '$count файл',
    );
    return '$_temp0';
  }

  @override
  String collectionMediaLinkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ссылки',
      many: '$count ссылок',
      few: '$count ссылки',
      one: '$count ссылка',
    );
    return '$_temp0';
  }

  @override
  String get cardEditTitle => 'Редактировать карточку';

  @override
  String get cardEditHint => 'Редактировать эту карточку…';

  @override
  String get cardEditAddPhoto => 'Добавить фото';

  @override
  String get cardEditAttachFile => 'Прикрепить файл';

  @override
  String get cardEditAttachment => 'Вложение';

  @override
  String get cardEditReplace => 'Заменить';

  @override
  String get cardEditRemove => 'Убрать';

  @override
  String get cardEditLinksHeader => 'СВЯЗИ';

  @override
  String get cardEditNoLinks => 'Пока нет связей.';

  @override
  String get cardEditAddLink => 'Добавить связь';

  @override
  String get cardEditBrokenLink => 'Битая связь';

  @override
  String get cardEditBrokenLinkSubtitle => 'Связанный элемент был удалён';

  @override
  String get cardEditSaveFailed => 'Не удалось сохранить. Попробуйте ещё раз.';

  @override
  String get cardEditSettled => 'Приглушена';

  @override
  String get cardEditSettledSubtitle =>
      'Остаётся в истории, но уже не актуальна';

  @override
  String get connectionsTitle => 'Связи';

  @override
  String get connectionsClearTitle => 'Очистить эту связь?';

  @override
  String get connectionsClearBody =>
      'Битая связь будет удалена. Карточки и коллекции, на которые она указывала, не удаляются.';

  @override
  String get connectionsLinksOut => 'Исходящие связи';

  @override
  String get connectionsLinkedFrom => 'Ссылаются на это';

  @override
  String get connectionsOpen => 'Открыть в коллекции';

  @override
  String get connectionsBrokenLink => 'Битая связь';

  @override
  String connectionsLinkedDeleted(String kind) {
    return 'Связанный объект ($kind) был удалён';
  }

  @override
  String connectionsLinkingDeleted(String kind) {
    return 'Ссылающийся объект ($kind) был удалён';
  }

  @override
  String get connectionsKindCollection => 'коллекция';

  @override
  String get connectionsKindCard => 'карточка';

  @override
  String get connectionsKindItem => 'элемент';

  @override
  String get connectionsEmptyTitle => 'Пока нет связей';

  @override
  String get connectionsEmptyBody =>
      'Свяжите карточку с коллекцией, и она появится здесь.';

  @override
  String get connectionsLoadError => 'Не удалось загрузить связи.';

  @override
  String get connectionsClearFailed =>
      'Не удалось очистить. Попробуйте ещё раз.';

  @override
  String get profileTitle => 'Профиль';

  @override
  String get profileNicknameLabel => 'Никнейм';

  @override
  String get profileEditNickname => 'Изменить никнейм';

  @override
  String get profileRenameTitle => 'Изменить никнейм';

  @override
  String get profileRenameHint => 'напр. mira';

  @override
  String get profileRenameFailed =>
      'Не удалось обновить никнейм. Попробуйте ещё раз.';

  @override
  String get profilePublicKeyLabel => 'Публичный ключ';

  @override
  String get profileCopyKey => 'Скопировать публичный ключ';

  @override
  String get profileKeyCopied => 'Публичный ключ скопирован';

  @override
  String get profileLoadError => 'Не удалось загрузить профиль.';

  @override
  String get profileOpen => 'Профиль';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsOpen => 'Настройки';

  @override
  String get settingsDataTitle => 'Данные';

  @override
  String get settingsDataSubtitle => 'Экспорт, импорт и управление данными';

  @override
  String get settingsThemeTitle => 'Тема';

  @override
  String get settingsThemeSystem => 'Как в системе';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsLanguageTitle => 'Язык';

  @override
  String get settingsLanguageSystem => 'Как в системе';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get settingsAboutTitle => 'О приложении';

  @override
  String get settingsAboutSubtitle => 'Версия и сведения о приложении';

  @override
  String get settingsAboutTagline =>
      'Локальное пространство, где сплетаются ваши мысли.';

  @override
  String get settingsAboutVersionLabel => 'Версия';

  @override
  String get settingsDataTransferSection => 'Резервное копирование и перенос';

  @override
  String get settingsExport => 'Экспорт данных';

  @override
  String get settingsExportSubtitle =>
      'Сохраните коллекции, карточки и ключ в файл';

  @override
  String get settingsImport => 'Импорт данных';

  @override
  String get settingsImportSubtitle =>
      'Восстановить из ранее экспортированного файла';

  @override
  String get settingsDangerSection => 'Опасная зона';

  @override
  String get settingsWipeData => 'Стереть данные';

  @override
  String get settingsWipeDataSubtitle =>
      'Удалить все коллекции и карточки на этом устройстве';

  @override
  String get settingsResetIdentity => 'Сбросить ключ';

  @override
  String get settingsResetIdentitySubtitle =>
      'Удалить все данные и ключ этого устройства и начать заново';

  @override
  String get settingsExportChooseTitle => 'Экспорт резервной копии';

  @override
  String get settingsExportChooseShare => 'Поделиться…';

  @override
  String get settingsExportChooseShareSubtitle =>
      'Отправить копию в другое приложение';

  @override
  String get settingsExportChooseSave => 'Сохранить в файл';

  @override
  String get settingsExportChooseSaveSubtitle => 'Выберите, где хранить копию';

  @override
  String get settingsBackupExported => 'Резервная копия готова к отправке';

  @override
  String get settingsBackupSaved => 'Резервная копия сохранена';

  @override
  String get settingsBackupExportFailed => 'Не удалось создать резервную копию';

  @override
  String get settingsBackupImportFailed =>
      'Не удалось восстановить из резервной копии';

  @override
  String settingsBackupImported(int applied, int deduped) {
    return 'Восстановлено элементов: $applied (уже было: $deduped)';
  }

  @override
  String settingsBackupImportWarning(int quarantined, int mismatched) {
    return 'Пропущено операций: $quarantined, повреждено файлов: $mismatched';
  }

  @override
  String get settingsWipeConfirmTitle => 'Стереть все данные?';

  @override
  String get settingsWipeConfirmMessage =>
      'Это безвозвратно удалит все коллекции, карточки и связи на этом устройстве. Ваш ключ сохранится. Отменить нельзя — сначала экспортируйте резервную копию, если данные могут понадобиться.';

  @override
  String get settingsWipeConfirmAction => 'Стереть данные';

  @override
  String get settingsWipeDone => 'Все данные стёрты';

  @override
  String get settingsWipeFailed => 'Не удалось стереть данные';

  @override
  String get settingsExportPassphraseTitle => 'Защитите ключ';

  @override
  String get settingsExportPassphraseMessage =>
      'Резервная копия содержит ваш приватный ключ. Задайте пароль для его шифрования — он понадобится для восстановления, и восстановить забытый пароль нельзя.';

  @override
  String get settingsPassphraseLabel => 'Пароль';

  @override
  String get settingsPassphraseConfirmLabel => 'Повторите пароль';

  @override
  String settingsPassphraseTooShort(int min) {
    return 'Не меньше $min символов';
  }

  @override
  String get settingsPassphraseMismatch => 'Пароли не совпадают';

  @override
  String get settingsExportPassphraseAction => 'Продолжить';

  @override
  String get settingsReplaceTitle => 'Заменить данные устройства?';

  @override
  String settingsReplaceMessage(String date) {
    return 'Эта резервная копия от $date принадлежит другой личности. Восстановление удалит всё на этом устройстве, включая ваш ключ, и сделает вас этой личностью. Введите пароль копии, чтобы продолжить.';
  }

  @override
  String get settingsReplaceWrongPassphrase => 'Неверный пароль';

  @override
  String get settingsReplaceAction => 'Стереть и восстановить';

  @override
  String settingsDeviceReplaced(int applied) {
    return 'Копия восстановлена — элементов: $applied';
  }

  @override
  String get settingsResetConfirmTitle => 'Сбросить ключ?';

  @override
  String settingsResetConfirmMessage(String word) {
    return 'Все коллекции, карточки и связи на этом устройстве, а также ваш ключ будут удалены навсегда. Без резервной копии ничего из созданного не получится восстановить от вашего имени. Введите $word для подтверждения.';
  }

  @override
  String get settingsResetConfirmAction => 'Сбросить';

  @override
  String get settingsResetBackupFirst => 'Сначала сохранить копию';

  @override
  String get settingsResetFailed => 'Не удалось сбросить ключ';

  @override
  String get syncAllSaved => 'Все изменения сохранены';

  @override
  String get syncUnavailable => 'Статус синхронизации недоступен';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count изменения сохранены на этом устройстве — ещё не отправлены',
      many: '$count изменений сохранены на этом устройстве — ещё не отправлены',
      few: '$count изменения сохранены на этом устройстве — ещё не отправлены',
      one: '1 изменение сохранено на этом устройстве — ещё не отправлено',
    );
    return '$_temp0';
  }

  @override
  String get searchOpen => 'Поиск';

  @override
  String get searchHint => 'Поиск по коллекциям и карточкам';

  @override
  String get searchIdle => 'Введите запрос и нажмите «Поиск»';

  @override
  String get searchFailed => 'Не удалось выполнить поиск';

  @override
  String searchNoResults(String query) {
    return 'По запросу «$query» ничего не найдено';
  }

  @override
  String get searchFilterAll => 'Все';

  @override
  String get searchFilterCollections => 'Коллекции';

  @override
  String get searchFilterCards => 'Карточки';

  @override
  String searchInCollection(String title) {
    return 'в «$title»';
  }

  @override
  String collectionSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get collectionSelectAllTooltip => 'Выбрать все';

  @override
  String get collectionUnselectAll => 'Снять выбор';

  @override
  String get collectionClearSelectionTooltip => 'Отменить выбор';

  @override
  String get collectionMoveTooltip => 'Переместить в коллекцию';

  @override
  String get collectionMoveSheetTitle => 'Переместить в…';

  @override
  String get collectionMoveNoTargets => 'Других коллекций пока нет.';

  @override
  String get collectionMoveTargetsError => 'Не удалось загрузить коллекции.';

  @override
  String collectionCardsMoved(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки перемещены в «$title»',
      many: '$count карточек перемещено в «$title»',
      few: '$count карточки перемещены в «$title»',
      one: '1 карточка перемещена в «$title»',
    );
    return '$_temp0';
  }

  @override
  String get collectionCardsMovedOpen => 'Открыть';

  @override
  String get shareCaptureTitle => 'Сохранить в Knit';

  @override
  String get shareCaptureSearchHint => 'Найти коллекцию';

  @override
  String get shareCaptureNewCollection => 'Новая коллекция';

  @override
  String get shareCaptureEmpty => 'Коллекций пока нет — создайте новую';

  @override
  String get shareCaptureNoMatches => 'Подходящих коллекций нет';

  @override
  String get shareCaptureLoadError => 'Не удалось загрузить коллекции';

  @override
  String get shareCaptureSaveError =>
      'Не удалось сохранить всё — попробуйте ещё раз';

  @override
  String get shareCaptureNeedsSetup =>
      'Сначала настройте Knit — полученные данные не сохранены';

  @override
  String shareCaptureItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '1 элемент',
    );
    return '$_temp0';
  }

  @override
  String shareCaptureSaved(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карточки сохранены в «$title»',
      many: '$count карточек сохранено в «$title»',
      few: '$count карточки сохранены в «$title»',
      one: '1 карточка сохранена в «$title»',
    );
    return '$_temp0';
  }

  @override
  String get collectionWidgetPickTitle => 'Выберите коллекцию для виджета';

  @override
  String get collectionWidgetEmpty =>
      'Коллекций пока нет — сначала создайте её в Knit';

  @override
  String get collectionWidgetSaveError =>
      'Не удалось настроить виджет — попробуйте ещё раз';

  @override
  String get collectionWidgetNeedsSetup =>
      'Сначала настройте Knit, затем снова нажмите на виджет';

  @override
  String get collectionWidgetRemoved =>
      'Эта коллекция удалена — нажмите на виджет, чтобы выбрать другую';
}
