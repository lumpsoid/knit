/// Hybrid Logical Clock (HLC) — spec §6.1, §8.1–8.3.
///
/// An HLC is **two integers** `(ms, counter)` ordered by a *comparator*, never by
/// string sorting. It carries no display or ordering duty outside merge: it
/// solves sync and nothing else.
///
/// This file is intentionally Flutter-free so the sync core can be unit-tested
/// and reused on any platform.
library;

import 'dart:math' as math;

/// Clock-skew guard default — spec §8.3. Five minutes of slack for honest clock
/// disagreement while catching gross/future stamps. Overridable via `app_setting`.
const int kMaxSkewMs = 300000;

/// An `(ms, counter)` stamp. Immutable value type with a *total* order via the
/// content comparator on `(ms, counter)` (spec §6.1). Tiebreak beyond the clock
/// (`author`, then `sig`) lives in the merge comparator, not here.
class Hlc implements Comparable<Hlc> {
  /// Physical part — ms wall-clock at stamp time (merge only).
  final int ms;

  /// Logical part — disambiguates events within the same [ms] (merge only).
  final int counter;

  const Hlc(this.ms, this.counter)
      : assert(ms >= 0, 'hlc_ms must be non-negative'),
        assert(counter >= 0, 'hlc_counter must be non-negative');

  /// The zero clock — a fresh device before any event.
  static const Hlc zero = Hlc(0, 0);

  @override
  int compareTo(Hlc other) {
    if (ms != other.ms) return ms.compareTo(other.ms);
    return counter.compareTo(other.counter);
  }

  bool operator >(Hlc o) => compareTo(o) > 0;
  bool operator >=(Hlc o) => compareTo(o) >= 0;
  bool operator <(Hlc o) => compareTo(o) < 0;
  bool operator <=(Hlc o) => compareTo(o) <= 0;

  /// The later of two stamps under the content comparator.
  static Hlc max(Hlc a, Hlc b) => a >= b ? a : b;

  @override
  bool operator ==(Object other) =>
      other is Hlc && other.ms == ms && other.counter == counter;

  @override
  int get hashCode => Object.hash(ms, counter);

  @override
  String toString() => 'Hlc($ms.$counter)';
}

/// Raised when an op's observed clock is too far in the future — spec §8.3.
///
/// The guard is *one-directional* (future only): a past timestamp merely loses
/// LWW and is harmless. A single absurd-future stamp, left unchecked, would jam
/// the device clock in the future permanently and spread on sync.
class ClockSkewException implements Exception {
  final int observedMs;
  final int physicalNowMs;
  final int maxSkewMs;

  ClockSkewException(this.observedMs, this.physicalNowMs, this.maxSkewMs);

  int get skewMs => observedMs - physicalNowMs;

  @override
  String toString() =>
      'ClockSkewException: observed ms $observedMs is ${skewMs}ms ahead of '
      'now $physicalNowMs (> maxSkewMs $maxSkewMs)';
}

/// Returns true when [observedMs] is further in the future than the skew bound —
/// the op should be quarantined (`reason="skew"`), not applied, and must NOT
/// advance the clock (spec §8.3). Note: one-directional, future only.
bool exceedsSkew(int observedMs, int physicalNowMs, {int maxSkewMs = kMaxSkewMs}) =>
    observedMs - physicalNowMs > maxSkewMs;

/// The single per-device HLC — spec §8.1/§8.2.
///
/// Invariant: the device clock is `>=` (content comparator) every stamp this
/// device has ever *produced* or *observed* in a verified op. That invariant is
/// what lets a local write made *after* seeing a remote edit out-rank it.
///
/// Crash-safety (spec §8.1): in production the persisted `device_clock` row must
/// commit in the **same transaction** as the op that advanced it. This in-memory
/// clock exposes [now]/[restore] so the caller can persist atomically; never
/// stamp an op and persist the clock later.
class DeviceClock {
  Hlc _now;

  DeviceClock([Hlc start = Hlc.zero]) : _now = start;

  /// The current persisted clock value.
  Hlc get now => _now;

  /// Rehydrate from a persisted value (e.g. on startup, or rebuild-from-log
  /// recovery — spec §8.9 step 3).
  void restore(Hlc value) => _now = value;

  /// Generate a stamp for a **local event** (create/edit/delete/reorder) —
  /// spec §8.2. Monotonic: ms never goes backward; the counter breaks ties
  /// within the same ms.
  ///
  /// Which stamp *slot* this lands on (content `hlc_*` vs placement
  /// `position_*`) is the merge layer's concern (spec §8.4); this only mints the
  /// value and advances the device clock.
  Hlc localTick(int physicalNowMs) {
    if (physicalNowMs > _now.ms) {
      _now = Hlc(physicalNowMs, 0);
    } else {
      _now = Hlc(_now.ms, _now.counter + 1);
    }
    return _now;
  }

  /// Advance the clock on **receiving** a verified op — spec §8.2.
  ///
  /// Run for *every* verified, non-quarantined op, win or lose: observing a
  /// timestamp obligates the clock to move past it. [observed] is the op's
  /// reduced observed clock = max over all stamps it carries (for a card, both
  /// the content stamp and the placement stamp, since a reorder's `position_*`
  /// can exceed its `hlc_*`).
  ///
  /// The caller MUST run the skew guard ([exceedsSkew]) first; a skew-quarantined
  /// op must not reach here.
  Hlc observe(Hlc observed, int physicalNowMs) {
    final lastMs = _now.ms;
    final lastCounter = _now.counter;
    final om = observed.ms;
    final oc = observed.counter;

    final ms = math.max(math.max(lastMs, om), physicalNowMs);
    final int counter;
    if (ms == lastMs && ms == om) {
      counter = math.max(lastCounter, oc) + 1;
    } else if (ms == lastMs) {
      counter = lastCounter + 1;
    } else if (ms == om) {
      counter = oc + 1;
    } else {
      // ms == physicalNowMs strictly greatest.
      counter = 0;
    }
    _now = Hlc(ms, counter);
    return _now;
  }
}
