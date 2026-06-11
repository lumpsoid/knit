/// Column names and DDL for the `local_identity` table — spec §6.5.
///
/// Local-only; never synced, never signed. The secret key is stored encrypted
/// at rest (`secret_key_enc` BLOB), sealed by a `SecretBox`.
abstract class LocalIdentitySchema {
  static const String table = 'local_identity';

  static const String colPublicKey = 'public_key';
  static const String colSecretKeyEnc = 'secret_key_enc';
  static const String colCreatedAt = 'created_at';

  static const String createTable =
      '''
      CREATE TABLE IF NOT EXISTS $table (
        $colPublicKey      TEXT PRIMARY KEY,
        $colSecretKeyEnc   BLOB NOT NULL,
        $colCreatedAt      INTEGER NOT NULL
      )
      ''';
}
