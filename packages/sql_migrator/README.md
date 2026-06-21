# sql_migrator

A backend-agnostic SQLite schema migrator: ordered up/down migrations, an
advisory lock, and a pluggable `MigrationExecutor` so the engine is not coupled
to any one driver (sqflite, sqlite3, drift, an in-memory fake for tests, …).

Migrations are **Dart closures**, not SQL files:

```dart
final migrator = Migrator(
  executor: SqfliteExecutor(db),
  migrations: [
    Migration(
      version: 1,
      description: 'baseline schema',
      up: (db) => db.execute('CREATE TABLE …'),
      down: (db) => db.execute('DROP TABLE …'),
    ),
  ],
);
await migrator.migrate(); // applies all pending versions in order
```

`migrate()` applies every pending version in order inside a transaction;
`migrateTo(n)` / `rollback()` move down again via each migration's `down`.

## Checksums and integrity — read before you rely on them

> **Limitation, by design.** The integrity checksum is
> `sha256("v$version:$description")`. **It does not hash the migration body**
> (the `up`/`down` closures). Editing the SQL a migration runs while leaving its
> `version` and `description` unchanged produces an **identical checksum** — the
> change is invisible to `validateIntegrity()`.

This is the opposite of how file-based migrators (Flyway, Liquibase) work, where
the checksum hashes the script and so detects any edit to an already-applied
migration. Dart cannot introspect a closure's contents at runtime, so there is
nothing to hash — the description is used as a human-maintained *proxy* for the
body. The doc on `computeMigrationChecksum` spells this out: *developers must
bump the description when they meaningfully change a migration.*

Consequences to keep in mind when making schema decisions:

- **It will not catch the dangerous case.** The canonical job of a migration
  checksum — "someone edited a migration that already ran on real devices" —
  is exactly what this cannot detect when the description is left unchanged.
- **It is mostly dormant as wired.** `migrate()` only checksum-checks *pending*
  migrations (which have no prior record, so the check no-ops). Already-applied
  migrations are validated **only** by `validateIntegrity()`, which nothing
  calls automatically — wire it into your boot path if you want it to run.
- **The flip side: editing a body is sometimes legitimate.** Rewriting *how* a
  migration expresses the *same* end state (e.g. swapping a constant-built DDL
  string for a frozen literal) keeps its identity, so the stable checksum is
  correct and the description should **not** change. The weakness and this
  convenience are the same property.

### Recommended discipline (pick to taste)

1. **Treat applied migrations as immutable.** Never edit a shipped migration's
   body; any schema change is a *new* `version`. With this rule the
   version+description checksum is sufficient, because bodies cannot drift. This
   is the cheapest and most robust option and is what consumers here rely on.
2. **Run `validateIntegrity()` on boot** if you want the (description-level)
   tripwire to actually fire.
3. **If you need real body-drift detection,** model DDL migrations as *data*
   (a list of SQL strings) and hash the SQL, or add an explicit per-migration
   `contentHash` the author maintains. Either makes the checksum trustworthy at
   the cost of giving up opaque closures (or adding manual bookkeeping).

In short: this checksum is a cheap **rename/renumber detector**, not a content
integrity guarantee. Do not lean on it to police edits to applied migrations —
lean on immutability-by-policy (option 1) instead.

## Testing

`MigrationExecutor` is an interface; an in-memory fake and a `SqfliteExecutor`
adapter ship for tests. Assert the same migration list against both.
