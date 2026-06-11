/// Fractional indexing for card placement (spec §8.7) — the **one** intended
/// string ordering in Knit: a card's `position` is compared lexicographically,
/// and a new key can always be minted strictly between any two neighbours
/// without renumbering the rest. That is what lets a reorder touch a single
/// card (§8.4) instead of rewriting the whole feed.
///
/// This is a faithful port of the well-known jitter-free `generateKeyBetween`
/// algorithm (base-62, integer-length-prefixed), so keys stay short and
/// human-legible (`a0`, `a1`, `a0V`, …) — the same shape the sync tests use.
///
/// App-agnostic, so it lives in `core/`. The composer appends with
/// [keyAfter]; reorder mints with [between].
library;

/// Card-feed position keys (spec §8.7). All keys order by plain string
/// comparison; [between] returns a key strictly between its neighbours.
abstract final class FractionalIndex {
  static const String _digits =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

  /// `'a0'` — the integer zero; the first key when a feed is empty.
  static const String _integerZero = 'a0';

  /// `'A' + 26 zeros` — the most-negative integer part.
  static const String _smallestInteger = 'A00000000000000000000000000';

  /// The first key for an empty feed.
  static String first() => _integerZero;

  /// A key ordered immediately after [last] (append to the end of a feed).
  static String keyAfter(String last) => between(last, null);

  /// A key ordered immediately before [first] (prepend to a feed).
  static String keyBefore(String first) => between(null, first);

  /// A key strictly between [a] and [b]. Either bound may be null (open end);
  /// when both are given they must satisfy `a < b`.
  static String between(String? a, String? b) {
    if (a != null) _validate(a);
    if (b != null) _validate(b);
    if (a != null && b != null && a.compareTo(b) >= 0) {
      throw ArgumentError('fractional index: "$a" is not before "$b"');
    }

    if (a == null) {
      if (b == null) return _integerZero;
      final ib = _integerPart(b);
      final fb = b.substring(ib.length);
      if (ib == _smallestInteger) return ib + _midpoint('', fb);
      if (ib.compareTo(b) < 0) return ib;
      final res = _decrementInteger(ib);
      if (res == null) throw StateError('fractional index: cannot decrement');
      return res;
    }

    if (b == null) {
      final ia = _integerPart(a);
      final fa = a.substring(ia.length);
      final i = _incrementInteger(ia);
      return i ?? ia + _midpoint(fa, null);
    }

    final ia = _integerPart(a);
    final fa = a.substring(ia.length);
    final ib = _integerPart(b);
    final fb = b.substring(ib.length);
    if (ia == ib) return ia + _midpoint(fa, fb);
    final i = _incrementInteger(ia);
    if (i == null) throw StateError('fractional index: cannot increment');
    if (i.compareTo(b) < 0) return i;
    return ia + _midpoint(fa, null);
  }

  // --- internals (ported verbatim from the reference algorithm) -------------

  /// A digit string `c` with `a < c < b` (both fractional parts, no integer
  /// head), with no trailing zero. [a] may be empty; [b] may be null.
  static String _midpoint(String a, String? b) {
    const zero = '0';
    if (b != null && a.compareTo(b) >= 0) {
      throw ArgumentError('fractional index: midpoint $a >= $b');
    }
    if (a.isNotEmpty && a[a.length - 1] == zero ||
        (b != null && b.isNotEmpty && b[b.length - 1] == zero)) {
      throw ArgumentError('fractional index: trailing zero');
    }
    if (b != null) {
      var n = 0;
      while ((n < a.length ? a[n] : zero) == (n < b.length ? b[n] : '')) {
        n++;
        if (n >= b.length) break;
      }
      if (n > 0) {
        return b.substring(0, n) +
            _midpoint(n < a.length ? a.substring(n) : '', b.substring(n));
      }
    }
    final digitA = a.isNotEmpty ? _digits.indexOf(a[0]) : 0;
    final digitB = b != null && b.isNotEmpty ? _digits.indexOf(b[0]) : _digits.length;
    if (digitB - digitA > 1) {
      final midDigit = (0.5 * (digitA + digitB)).round();
      return _digits[midDigit];
    }
    if (b != null && b.length > 1) {
      return b.substring(0, 1);
    }
    return _digits[digitA] + _midpoint(a.isNotEmpty ? a.substring(1) : '', null);
  }

  static int _integerLength(String head) {
    if (head.compareTo('a') >= 0 && head.compareTo('z') <= 0) {
      return head.codeUnitAt(0) - 'a'.codeUnitAt(0) + 2;
    }
    if (head.compareTo('A') >= 0 && head.compareTo('Z') <= 0) {
      return 'Z'.codeUnitAt(0) - head.codeUnitAt(0) + 2;
    }
    throw ArgumentError('fractional index: invalid integer head "$head"');
  }

  static String _integerPart(String key) {
    final len = _integerLength(key[0]);
    if (len > key.length) {
      throw ArgumentError('fractional index: invalid key "$key"');
    }
    return key.substring(0, len);
  }

  static void _validate(String key) {
    final i = _integerPart(key);
    final f = key.substring(i.length);
    if (f.isNotEmpty && f[f.length - 1] == '0') {
      throw ArgumentError('fractional index: invalid key (trailing zero) "$key"');
    }
  }

  static String? _incrementInteger(String x) {
    final head = x[0];
    final digs = x.substring(1).split('');
    var carry = true;
    for (var i = digs.length - 1; carry && i >= 0; i--) {
      final d = _digits.indexOf(digs[i]) + 1;
      if (d == _digits.length) {
        digs[i] = _digits[0];
      } else {
        digs[i] = _digits[d];
        carry = false;
      }
    }
    if (carry) {
      if (head == 'Z') return 'a0';
      if (head == 'z') return null;
      final h = String.fromCharCode(head.codeUnitAt(0) + 1);
      if (h.compareTo('a') > 0) {
        digs.add(_digits[0]);
      } else {
        digs.removeLast();
      }
      return h + digs.join();
    }
    return head + digs.join();
  }

  static String? _decrementInteger(String x) {
    final head = x[0];
    final digs = x.substring(1).split('');
    var borrow = true;
    for (var i = digs.length - 1; borrow && i >= 0; i--) {
      final d = _digits.indexOf(digs[i]) - 1;
      if (d == -1) {
        digs[i] = _digits[_digits.length - 1];
      } else {
        digs[i] = _digits[d];
        borrow = false;
      }
    }
    if (borrow) {
      if (head == 'a') return 'Z${_digits[_digits.length - 1]}';
      if (head == 'A') return null;
      final h = String.fromCharCode(head.codeUnitAt(0) - 1);
      if (h.compareTo('Z') < 0) {
        digs.add(_digits[_digits.length - 1]);
      } else {
        digs.removeLast();
      }
      return h + digs.join();
    }
    return head + digs.join();
  }
}
