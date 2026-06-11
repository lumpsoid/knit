# Business Logic Placement

> Part of the application architectural contract. This is a generalized,
> app-agnostic specification. Companion docs:
> [Scope/Controller/FCIS](fcis.md), [Result pattern](result.md),
> [App composition](composition.md), [Cross-feature seams](cross_feature.md),
> [Widgets](widgets.md).

You MUST follow these rules when writing or reviewing application code.
The architecture is layered (**domain → application/use-cases →
infrastructure → bridge/UI**) with a functional-core / imperative-shell
loop (state + pure updater + declarative effects + effect-running shell —
[FCIS §6](fcis.md)). **Dependencies point inward only.**

---

## 1. Core principle

Every `if`, comparison, or arithmetic on data is either a **business
decision** or **plumbing**.

- **Plumbing** = sequencing, fetching, retrying, DTO mapping, dispatching,
  branching on I/O outcomes (`Result` Ok/Err — [Result §9](result.md)).
- **Decision** = anything the business could change its mind about:
  limits, costs, thresholds, eligibility, state transitions, validity.

Decisions live in the **domain** layer, next to the data they govern, with
a name. Plumbing lives in shells, controllers, and use cases. **Shells
orchestrate; the domain decides.** Never write a business `if` inside an
effect runner (shell), controller, repository, or async I/O method.

---

## 2. The placement ladder

Place each rule at the **smallest level that has enough data to decide**:

1. **Rule about one value** → newtype / value object with a smart
   constructor. Private fields; the constructor is the only entry and
   enforces the rule (*parse, don't validate*). After construction the
   value is valid by definition — never re-validate downstream. Prefer
   representations where invalid values cannot exist at all (an unsigned
   type for non-negative, a sealed enum for a closed set, etc.).
2. **Rule about one entity's own fields** → method on that entity. **No
   public setters, ever.** State changes only through methods named after
   business operations (`order.submit()`, `account.withdraw(amount)`)
   that enforce invariants atomically.
3. **Rule spanning several entities, still pure** → domain service or
   policy object: a pure function or small injectable class
   (`PrefetchPolicy.shouldFetch(...)`, `checkDailyLimit(sent, requested)`).
   Thresholds and magic numbers go here as **named, injected
   configuration** — never inline.
4. **Rule needing fetched data** → a use case orchestrates: fetch the
   facts via ports (abstract interfaces), then call DOWN into levels 1–3
   for the verdict, then persist. The use-case body contains **zero**
   business decisions — only load → ask domain → save.

> **Fetching never decides. Deciding never fetches.**

---

## 3. Mandatory practices

- **Make invalid states unrepresentable.** Replace clusters of booleans +
  nullables that must stay in sync (`hasSelection` + `activeId?` +
  `replyId?`) with one sum type / sealed class
  (`sealed class Selection` → `None | Active(id, replyId)`). If you write
  `?? ''`, `!`, or `.unwrap()` to satisfy the compiler at a boundary,
  treat it as a design error: fix the type so the fallback is impossible.
- **Name every rule.** If the same threshold or formula appears (or would
  appear) in 2+ places, extract a policy object immediately. A rule has
  exactly one home.
- **Tell, don't ask.** Do not extract raw primitives from an object and
  decide in the caller.

  ```dart
  // ❌ WRONG — caller reaches in and decides.
  if (state.sparks - cost < 0) { … }

  // ✅ RIGHT — the object owns the decision, with a name.
  if (!state.balance.canAfford(SparkCost.match)) { … }
  ```

- **Validate exactly once, at the boundary.** DTO → domain conversion in
  the bridge runs the smart constructors. Domain types never derive
  serialization for wire formats; DTOs are separate types with explicit
  mappers ([Result §9](result.md) for the fallible mapping).
- **In updater/reducer code, compose named domain decisions; do not
  inline rule logic.** Effects are descriptions of intent
  (`SendEffect(...)`), never conditional logic. "Send if affordable" is
  two things: a domain check in the updater + a plain effect
  ([FCIS §6.2/§6.3](fcis.md)).
- **UI keeps only cosmetics** (formatting, localization, colors,
  animation). Structural view logic (pagination, selection, fetch-status
  transitions) belongs in the core ([Widgets §2](widgets.md) for the
  related "pass only what's used" rule).

---

## 4. Self-check before finishing any change

For every new conditional you wrote, verify:

1. If it's a business decision, it is NOT in a
   shell/controller/effect-runner/repository.
2. It sits at the smallest sufficient level of the ladder
   (value → entity → policy → use case).
3. The rule has a name and exactly one home; no duplicated thresholds.
4. No public path can put any object into an invalid state — remove the
   path rather than adding a defensive check.
5. The rule is testable with plain values: no mocks, no fakes, no async,
   no framework. **If testing a rule requires mocking a repository, the
   rule is in the wrong layer — move it before writing the mock.**
6. A future one-line business change ("raise the limit", "prefetch one
   earlier") touches exactly one file.

---

## 5. Narrow abstractions — segregate ports, don't fatten the repository

A dependency a shell / controller / use case takes MUST be a **narrow,
single-purpose abstraction**, not a fat interface bundling every external
call the feature makes. Prefer many small ports over one big one.

Why:

- **Composability.** Small ports compose into specific variants. A fat
  port forces every variant to implement (or stub) calls it doesn't care
  about.
- **Cheap variants.** An implementation with few dependencies is easy to
  build — in-memory, fake, offline, alternative backend. A fat repository
  drags in many dependencies, so *every* variant must satisfy *all* of
  them, and composable variations become hard.
- **Honest dependencies.** The constructor then lists exactly which
  capabilities the feature uses (interface segregation at the seam).

A feature depends on several narrow ports, each one concern:

```dart
<Feature>Controller({
  required ProfileOtherReadRepository profileRepository,    // read profile
  required ProfileOtherAnswersRepository answersRepository, // answers
  required ProfileOtherSubscriptionRepository subscriptionRepository,
  required ProfileOtherPaywallRepository paywallRepository,
});
```

Not one repository that does everything the feature happens to need:

```dart
// ❌ WRONG — a single repository bundling every external call.
abstract interface class ProfileOtherRepository {
  Future<Result<Profile, …>> getProfile(String id);
  Future<Result<Answers, …>> getAnswers(String id);     // not profile CRUD
  Future<Result<Subscription, …>> getSubscription();    // not profile CRUD
  Future<Result<void, …>> openPaywall();                // not even data
  // …grows without bound; every variant must implement all of it.
}
```

**Name ports for what they do.** Don't use a bare generic
`<Feature>Repository` — the name says nothing about the port's
responsibility and invites exactly the catch-all drift above. Name each
port for its one capability: `<Feature>ReadRepository`,
`<Feature>SubscriptionRepository`, a paywall port, a gateway, a service.
The name should tell a reader precisely what that port does and nothing
broader.

Each narrow port returns `Result` ([§9](result.md)) and is a port the use
case / shell calls into (ladder level 4, §2). Multiple implementations per
port (real, in-memory, …) compose into the variant a given `AppConfig`
selects ([composition §2](composition.md)). The same applies to every
injected abstraction, not just repositories — gateways, clients, services.

---

## 6. When refactoring existing code

Flag violations of these rules (a business `if` in a shell, magic
numbers, setter-style mutation, sync-by-discipline field clusters, a fat
catch-all repository) even when the task doesn't ask for it — propose the
inward move, but apply it only with the user's confirmation unless the
change is part of the requested scope.
