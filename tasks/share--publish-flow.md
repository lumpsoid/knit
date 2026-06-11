# Share flow sheet — publish to a relay (§4.6, designed in §10)

## What's missing

No share flow. Spec §4.6: a sheet to **publish a collection or card to a relay**
as **read-only** or **shared**. The full design (capability tokens, scopes) is
in §10 and is **not yet designed in detail** — this task is gated on that.

## What to build

- A share sheet from a collection / card: choose read-only vs shared, produce a
  share token / topic, and publish via the relay path.
- Read-only share = a token without push scope; shared = token with push scope.
  The relay checks the token and never reads `payload` (§9.2).

## Blocked on

- **§10 capability-token design** (not finalized).
- **Relay push/pull sync** — see [relay--push-pull-sync](relay--push-pull-sync.md).

## References

- spec §4.6 (Share flow), §9.2 (push/pull, read-only vs shared tokens), §10
  (capability tokens — to be designed)
