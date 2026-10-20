import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Faint roots creeping in from a settled card's edges (§3.3). The pattern is
/// seeded from the card id, so each card keeps its own roots across rebuilds
/// and devices. [progress] (0 → 1) grows them, so settling animates.
class SettledRootsPainter extends CustomPainter {
  SettledRootsPainter({
    required this.seed,
    required this.progress,
    required this.color,
  });

  /// The card id the pattern is derived from.
  final String seed;
  final double progress;
  final Color color;

  static const int _stepsPerRoot = 7;
  static const int _maxDepth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || size.isEmpty) return;
    final segments = _grow(size);
    if (segments.isEmpty) return;
    // The last segment starts at the max time and takes one step to draw.
    final total =
        segments.map((s) => s.time).reduce(math.max) + 1 / _stepsPerRoot;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final s in segments) {
      // Each segment appears once growth reaches it, tracing outward.
      final local = ((progress * total - s.time) * _stepsPerRoot).clamp(
        0.0,
        1.0,
      );
      if (local <= 0) continue;
      paint.strokeWidth = s.width;
      canvas.drawLine(s.from, Offset.lerp(s.from, s.to, local)!, paint);
    }
  }

  /// The root segments for [size]: a few roots enter from the edges and steer
  /// along the card's long axis, branching as they go.
  List<_Segment> _grow(Size size) {
    final random = math.Random(_hash(seed));
    final segments = <_Segment>[];
    final area = size.width * size.height;
    final roots = (area / 9000).round().clamp(2, 5);
    final reach = (size.width + size.height) * 0.32;
    final wide = size.width >= size.height;

    for (var i = 0; i < roots; i++) {
      final (start, angle) = _edgeStart(size, random);
      _branch(
        segments,
        random,
        from: start,
        angle: angle,
        length: reach * (0.7 + random.nextDouble() * 0.5),
        width: 1.6 + random.nextDouble() * 0.8,
        depth: 0,
        time: random.nextDouble() * 0.25,
        wide: wide,
      );
    }
    return segments;
  }

  void _branch(
    List<_Segment> out,
    math.Random random, {
    required Offset from,
    required double angle,
    required double length,
    required double width,
    required int depth,
    required double time,
    required bool wide,
  }) {
    final step = length / _stepsPerRoot;
    var point = from;
    var heading = angle;
    for (var k = 0; k < _stepsPerRoot; k++) {
      // Wander, while easing toward the long axis so the roots creep along
      // the card instead of leaving it straight away.
      final axis = wide
          ? (math.cos(heading) >= 0 ? 0.0 : math.pi)
          : (math.sin(heading) >= 0 ? math.pi / 2 : -math.pi / 2);
      heading += (random.nextDouble() - 0.5) * 0.7;
      heading += _shortestTurn(heading, axis) * 0.18;
      final next = point + Offset(math.cos(heading), math.sin(heading)) * step;
      final taper = 1 - k / (_stepsPerRoot + 2);
      final t = time + k / _stepsPerRoot / (depth + 1);
      out.add(_Segment(point, next, math.max(0.5, width * taper), t));
      if (depth < _maxDepth && k > 0 && random.nextDouble() < 0.3) {
        final side = random.nextBool() ? 1 : -1;
        _branch(
          out,
          random,
          from: next,
          angle: heading + side * (0.5 + random.nextDouble() * 0.6),
          length: length * 0.5,
          width: width * taper * 0.65,
          depth: depth + 1,
          time: t,
          wide: wide,
        );
      }
      point = next;
    }
  }

  /// A start point on one of the edges (picked by edge length) and a heading
  /// pointing inward, give or take.
  static (Offset, double) _edgeStart(Size size, math.Random random) {
    final w = size.width;
    final h = size.height;
    final pick = random.nextDouble() * 2 * (w + h);
    final jitter = (random.nextDouble() - 0.5) * 1.2;
    if (pick < w) {
      return (Offset(pick, 0), math.pi / 2 + jitter);
    } else if (pick < 2 * w) {
      return (Offset(pick - w, h), -math.pi / 2 + jitter);
    } else if (pick < 2 * w + h) {
      return (Offset(0, pick - 2 * w), jitter);
    }
    return (Offset(w, pick - 2 * w - h), math.pi + jitter);
  }

  static double _shortestTurn(double from, double to) {
    var d = (to - from) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return d;
  }

  /// A stable string hash — `String.hashCode` isn't guaranteed across runs.
  static int _hash(String s) =>
      s.codeUnits.fold<int>(17, (a, c) => (a * 31 + c) & 0x7fffffff);

  @override
  bool shouldRepaint(SettledRootsPainter old) =>
      old.seed != seed || old.progress != progress || old.color != color;
}

class _Segment {
  const _Segment(this.from, this.to, this.width, this.time);
  final Offset from;
  final Offset to;
  final double width;

  /// When growth reaches this segment, before normalizing.
  final double time;
}
