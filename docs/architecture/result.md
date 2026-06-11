# The Result Pattern

> Part of the application architectural contract. This is a generalized,
> app-agnostic specification. Section numbers (§N) are preserved from the
> shared contract; companion docs: [Scope/Controller/FCIS](fcis.md),
> [App composition](composition.md), [Cross-feature seams](cross_feature.md).

## 9. The Result Pattern

### 9.1 The type

`Result<S, F>` is the **`result_dart`** package (git dep), not a
project file. Two cases: success / failure. (Any project-local
`deepEquals` / `deepHashCode` used for value equality is separate — it
lives in the project's `lib/core/domain/deep_equality.dart`, not in this
package.)

Read the package source for the exact API:
`~/.cache/pub/git/result_dart-*/lib/src/`. Locate it for any importing
file with `/deps <file> --output flat`.

### 9.2 API surface

Do not duplicate the method catalog here — it lives in (and drifts
with) the package. Read the source above / use IDE autocomplete. The
idioms this codebase relies on: construction (success / failure),
`map` / `flatMap` / `mapError`, `fold`, `getOrElse`, `onSuccess` /
`onFailure` and their async variants, plus a `Future<Result<…>>`
extension so call sites skip explicit `await` plumbing.

### 9.3 Rules

1. **Every fallible operation MUST return `Result<S, F>` (or
   `Future<Result<S, F>>`).** This applies at every layer:
   - Remote API methods.
   - Repository implementations (API-backed, storage-backed,
     in-memory).
   - Domain repository **contracts** (the `abstract class`) MUST
     declare Result-returning signatures.
2. **Failure types are per-area or per-feature sealed classes.** Never
   a single global `AppFailure`.
3. **The updater never sees a `Result`.** The shell unwraps `Result`
   and dispatches a success-Action or a failure-Action
   ([FCIS §6.6](fcis.md)).
4. Infallible operations (e.g. a write that genuinely cannot fail)
   remain `Future<void>` / `Future<T>`. The bar for "infallible" is
   high — most local writes can throw on disk pressure or
   serialization, so they MUST be Results.

### 9.4 Anti-pattern — the naked `Future`

A repository that returns a naked `Future<T>` and swallows failures has
no failure channel:

```dart
// ❌ WRONG — no way to surface a failure; errors vanish or throw uncaught.
Future<List<Respondent>> getRespondents();
```

```dart
// ✅ RIGHT — fallible operation carries a per-area failure type.
Future<Result<List<Respondent>, FeedFailure>> getRespondents();
```

Do not match the naked-`Future` shape in new code. Existing naked
`Future` repositories are debt; migrate them to Results when touched.
