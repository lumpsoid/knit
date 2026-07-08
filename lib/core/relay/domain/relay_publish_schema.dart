/// Column names + DDL for the device-local relay-publishing tables.
///
/// Local-only, never synced and never signed (like `local_identity`, spec §6.5):
/// they hold this device's relay address and, per collection, the topic + WRITE
/// token + public slug that address it on the relay. Kept out of the
/// SQLite/change-log store's signed-envelope tables on purpose.
abstract class RelayPublishSchema {
  /// A tiny key/value table for device-local relay config (the relay base URL).
  static const String settingTable = 'relay_setting';
  static const String colSettingKey = 'setting_key';
  static const String colSettingValue = 'setting_value';

  /// The key under which the relay base URL is stored in [settingTable].
  static const String relayUrlKey = 'relay.url';

  /// One row per published (or publishable) collection.
  static const String publicationTable = 'relay_publication';
  static const String colCollectionId = 'collection_id';
  static const String colTopicId = 'topic_id';
  static const String colWriteToken = 'write_token';
  static const String colSlug = 'slug';
  static const String colVisibility = 'visibility';
  static const String colPublishedAt = 'published_at';

  static const String createSettingTable =
      '''
      CREATE TABLE IF NOT EXISTS $settingTable (
        $colSettingKey    TEXT PRIMARY KEY,
        $colSettingValue  TEXT
      )
      ''';

  static const String createPublicationTable =
      '''
      CREATE TABLE IF NOT EXISTS $publicationTable (
        $colCollectionId  TEXT PRIMARY KEY,
        $colTopicId       TEXT NOT NULL,
        $colWriteToken    TEXT NOT NULL,
        $colSlug          TEXT,
        $colVisibility    TEXT NOT NULL,
        $colPublishedAt   INTEGER
      )
      ''';
}
