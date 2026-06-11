# Widgets — Shared vs Feature, and Data Inputs

> Part of the application architectural contract for the **presentation
> layer**. This is a generalized, app-agnostic specification. Companion
> docs: [Scope/Controller/FCIS](fcis.md), [Result pattern](result.md),
> [App composition](composition.md), [Cross-feature seams](cross_feature.md).

This doc governs how widgets declare their inputs. Two rules: shared
widgets stay feature-agnostic (§1); every widget takes only the data it
uses, never whole aggregates (§2).

---

## 1. Shared widgets take primitives, not feature types

A **shared widget** is one used by more than one feature (a button, a
card row, an avatar, a chip). A shared widget MUST NOT depend on any
feature's domain model — if it imports `<FeatureA>`'s type, then
`<FeatureB>` can't reuse it without dragging in `<FeatureA>`, and the
widget is no longer shared.

So a shared widget declares its fields in terms of **primitives and
platform/UI types** — `String`, `int`, `bool`, `double`, `Uri`,
`Duration`, `DateTime`, `Color`, `IconData`, callbacks (`VoidCallback`,
`ValueChanged<T>`) — never a feature's aggregate.

```dart
// ❌ WRONG — shared widget tied to a feature's domain model.
class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.user, super.key});
  final ChatUser user;            // now only `chat` can use this widget
  // …reads user.avatarUrl, user.displayName, user.isOnline
}
```

```dart
// ✅ RIGHT — primitives only; any feature can map its own type into it.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    required this.imageUrl,
    required this.label,
    this.isOnline = false,
    super.key,
  });
  final Uri imageUrl;
  final String label;
  final bool isOnline;
}

// Each feature adapts its own domain type at the call site:
UserAvatar(
  imageUrl: chatUser.avatarUrl,
  label: chatUser.displayName,
  isOnline: chatUser.isOnline,
)
```

### 1.1 When a primitive list isn't enough — a widget-owned type

When a shared widget genuinely needs structured input — e.g. a list of
items where each item carries several correlated fields — declaring a
dozen parallel-list primitives is worse than one type. In that case
create a **widget-owned view-model type**, colocated with the widget
(same file, or alongside it under `lib/core/widgets/...`), named for the
widget rather than any feature:

```dart
// lib/core/widgets/timeline_tile.dart

/// View-model owned by [TimelineTile]. Not a feature's domain type.
@immutable
class TimelineTileData {
  const TimelineTileData({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.unreadCount = 0,
  });
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final int unreadCount;
}

class TimelineTile extends StatelessWidget {
  const TimelineTile({required this.data, this.onTap, super.key});
  final TimelineTileData data;
  final VoidCallback? onTap;
}
```

This is **less prevalent** than the primitive form — reach for it only
when the input is genuinely structured. The point is the same either way:
the widget owns its contract; no feature type crosses into it. Features
map their domain model → the widget-owned type at the call site.

### 1.2 Feature-private widgets are exempt

A widget used by exactly **one** feature (it lives under that feature's
folder and nothing else imports it) may take that feature's domain type
directly — there's no reuse to protect. The primitive rule is
specifically about **shared** widgets. If such a widget later gets reused,
that's the moment to refactor it to primitives / a widget-owned type.

---

## 2. Pass only the data that's used, not the whole aggregate

> This rule is **more general than the UI** — it applies to any function
> parameter, constructor, or message payload — but it bites hardest in
> widgets, where over-broad inputs also widen the rebuild/equality
> surface.

A widget (or function) MUST take only the fields it actually uses, not a
large object that happens to contain them. Passing the whole aggregate
when two fields are read is wrong:

```dart
// ❌ WRONG — takes the entire profile to render a name and a count.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.profile, super.key});
  final UserProfile profile;      // 20 fields; this widget reads 2
}
```

```dart
// ✅ RIGHT — declares exactly what it renders.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.displayName,
    required this.followerCount,
    super.key,
  });
  final String displayName;
  final int followerCount;
}
```

Why:

1. **Decoupling.** The caller can supply the two values from anywhere —
   a different source, a test, a composed view — without constructing a
   full `UserProfile`.
2. **Narrower change surface.** A widget that takes the whole aggregate
   rebuilds (or fails equality) whenever *any* field of it changes, even
   fields it never reads. Taking only what it renders keeps rebuilds
   tight.
3. **Honest contract.** The constructor signature documents exactly what
   the widget depends on. A `UserProfile profile` field hides that.
4. **Stability.** If the aggregate gains, renames, or reshapes an unused
   field, a narrow widget is unaffected.

This is the same principle as **Action payloads carrying scalars, not
foreign aggregates** ([FCIS §6.3](fcis.md)): keep the dependency at the
call site (where one line maps aggregate → needed fields), not baked into
the consumer's type.

**Balance — don't explode into parallel primitives.** When many
correlated fields always travel and change together, that's exactly the
case for a small purpose-built type (§1.1 / a record), not fifteen loose
parameters. The rule is "only what's used", not "always primitives": if
the widget uses ten fields of an object, a focused view-model is right;
if it uses two, pass the two.
