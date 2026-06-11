import 'package:uuid/uuid.dart';
import 'package:knit/core/ids/id_generator.dart';

/// [IdGenerator] backed by `package:uuid`'s UUIDv7 (spec §6.1) — the leading 48
/// bits are the Unix-ms timestamp, so ids sort chronologically and serve as the
/// §8.7 creation-order tiebreak.
class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator([this._uuid = const Uuid()]);

  final Uuid _uuid;

  @override
  String newId() => _uuid.v7();
}
