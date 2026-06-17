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
  String get collectionActionConnections => 'Связи';

  @override
  String get collectionActionShare => 'Поделиться';

  @override
  String get collectionActionReorder => 'Изменить порядок';

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
  String get cardEditLinkToWhichCollection => 'С какой коллекцией связать?';

  @override
  String get cardEditSaveFailed => 'Не удалось сохранить. Попробуйте ещё раз.';

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
  String get settingsExportSubtitle => 'Сохранить коллекции и карточки в файл';

  @override
  String get settingsImport => 'Импорт данных';

  @override
  String get settingsImportSubtitle =>
      'Восстановить из ранее экспортированного файла';

  @override
  String get settingsExportIdentity => 'Экспорт ключа';

  @override
  String get settingsExportIdentitySubtitle =>
      'Сохраните приватный ключ, чтобы восстановить «себя»';

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
      'Удалить ключ этого устройства и начать заново';

  @override
  String settingsComingSoon(String feature) {
    return '$feature — скоро';
  }

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
}
