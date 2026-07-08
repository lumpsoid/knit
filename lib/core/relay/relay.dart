/// Relay web-publishing — the client half of the "publish a collection to the
/// web" contract (relay server §2.6 / §4.6). Barrel over the domain ports + DTOs
/// and their infra impls, mirroring `lib/core/attachments/attachments.dart`.
library;

export 'domain/collection_publisher.dart';
export 'domain/publication_snapshot.dart';
export 'domain/relay_failure.dart';
export 'domain/relay_publish_client.dart';
export 'domain/relay_publish_schema.dart';
export 'domain/relay_publish_store.dart';
export 'infra/fetch_relay_publish_client.dart';
export 'infra/in_memory_relay_publish_store.dart';
export 'infra/relay_collection_publisher.dart';
export 'infra/snapshot_builder.dart';
export 'infra/sqflite_relay_publish_store.dart';
