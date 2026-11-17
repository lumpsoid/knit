# Contributing to Knit

Thanks for wanting to help. Knit is a small personal project, so a short
conversation before code saves everyone time.

## Start with an issue

My wish, not a rule: for a feature or a larger change, open a
[proposal](https://github.com/lumpsoid/knit_mobile/issues/new?template=proposal.yml)
first. We agree on the problem and the shape of the fix, and then a pull
request links the issue (`Closes #12`). Small, obvious fixes like typos,
crashes with a clear cause or broken docs links can go straight to a PR.

Found a bug? Open a
[bug report](https://github.com/lumpsoid/knit_mobile/issues/new?template=bug_report.yml)
with the version from Settings → About.

## Setup

You need [Flutter](https://docs.flutter.dev/get-started/install) at the version
pinned in `.fvmrc` (or [fvm](https://fvm.app), which reads it), the Android
SDK, and SQLite (`libsqlite3`) for the real-database tests.

```sh
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart   # in-memory data, separate app id
scripts/check.sh                                 # every gate CI runs
```

The `dev` flavor installs beside a release build (`.dev` app id) and keeps its
data in memory, so experiments never touch your real collections.

## Where a change goes

- **`docs/app_spec.md`** is the product and protocol spec. Behaviour changes
  start there, and code cites its `§` sections.
- **`CLAUDE.md`** maps the code: `lib/sync/` (the merge engine and storage),
  `lib/core/` (shared pieces), `lib/features/<feature>/` (each screen).
- **`docs/architecture/`** describes the UI layer. New features use the
  lightweight pattern: a controller with a `ChangeNotifier` state, narrow
  ports, and pure domain logic. Older features follow the FCIS contract
  there; keep them in it when you change them.
- Every storage has an in-memory and a sqflite implementation that pass the
  same tests.
- User-visible changes get a line under `## [Unreleased]` in `CHANGELOG.md`.

## Checks

`scripts/check.sh` must pass: `dart format`, `flutter analyze` with no issues,
and every test (the app's and those in `packages/`). Test domain logic with
plain unit tests and controllers with fake ports; most logic needs no widget
pumping. Never break the key invariants listed in `CLAUDE.md`, such as one
transaction per apply and rebuild-from-log.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/) with a scope,
as in the history: `feat(collection): …`, `fix(sync): …`, `docs: …`. One
logical change per commit; the body says why.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
