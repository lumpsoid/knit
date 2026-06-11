# Run on the persistent sqflite graph (§9.1 gate 5)

## What's missing

The app runs on the **in-memory graph by default** (`AppConfig.dev` in
`main.dart`). The persistent sqflite graph (`AppConfig.prod`) is implemented but
**not yet the default**, so the §9.1 **gate 5** persistence check can't be
exercised through the live app.

## What to build

- Flip `main.dart` to `AppConfig.prod` (or make it selectable).
- Wire the platform DB factory — sqflite needs **ffi** on desktop/CI; mobile
  uses the native factory.
- Verify **gate 5** through the real app lifecycle: kill & reopen → projection
  rebuilds from `change_log` byte-identical, device clock resumes strictly
  monotone. (Engine-proven on sqflite in `write_rebuild_test`; this confirms it
  end to end in the running app.)

## References

- spec §9.1 gate 5, §8.9 (rebuild-from-log)
- `lib/main.dart` (`AppConfig.dev` → `.prod`), `lib/app/app_config.dart`,
  `lib/app/schema/knit_migrations.dart`
- `TASK.md` — the current remaining §9.1 slice item
