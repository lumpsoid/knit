// The knotted k: one geometry for the gallery (knot_k.html) and the shipped icons (build_icons.mjs).
// Needs gallery.js loaded first (poly, stroke).

// Traced in the reference image's 350px coordinates.
const STEM = [[175, 84], [175, 110], [166, 160], [157, 205], [153, 235], [153, 264]];
const STRAND = [
  [217, 164], [214, 180], [208, 196], [196, 208],            // 0-3  arm, passing under the leg
  [180, 214], [160, 219], [142, 215],                         // 3-6  ring bottom, over the stem
  [133, 202], [136, 188], [146, 179], [158, 177], [172, 183], // 7-11 ring left and top, under the stem
  [188, 196], [200, 210], [208, 228], [212, 248], [214, 264], // 11-16 leg, over the arm
];
// A leg that runs out into a long straight thread, for the "loose end" variant.
const STRAND_TAIL = [...STRAND.slice(0, 15), [214, 254], [222, 268], [240, 274], [290, 275]];
// The traced glyph's box (x 127-220, y 78-270, rope ends included).
const KNOT_CENTER = [173.5, 174], KNOT_HEIGHT = 192;

// Dense Catmull-Rom samples, so any slice of a strand lies exactly on the full curve.
const PER = 24;
function sample(pts) {
  const out = [];
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
    for (let k = 0; k < PER; k++) {
      const t = k / PER, t2 = t * t, t3 = t2 * t;
      out.push([0, 1].map(j => .5 * (2 * p1[j] + (-p0[j] + p2[j]) * t
        + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)));
    }
  }
  out.push(pts[pts.length - 1]);
  return out;
}
// Samples between fractional control-point indices a..b.
const span = (s, a, b) => s.slice(Math.round(a * PER), Math.round(b * PER) + 1);
const slice = (s, a, b) => poly(span(s, a, b));

function distToLine([px, py], line) {
  let best = Infinity;
  for (let i = 0; i < line.length - 1; i++) {
    const [ax, ay] = line[i], [bx, by] = line[i + 1], dx = bx - ax, dy = by - ay;
    const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy || 1)));
    best = Math.min(best, Math.hypot(px - ax - t * dx, py - ay - t * dy));
  }
  return best;
}

// The knot as plain round-capped polylines. Each crossing is a real gap cut into the under-strand, wide enough for
// the over-strand plus `gap` (in rope widths) of clearance, so the strokes work on any background, transparent included.
function knotStrokes({ rope = 12, gap = .75, strand = STRAND } = {}) {
  const st = sample(STEM), sd = sample(strand), last = strand.length - 1;
  const ringTop = { role: 'strand', pts: span(sd, 7, 12) };
  const stem = { role: 'stem', pts: span(st, 0, 5) };
  const armAndBottom = { role: 'strand', pts: span(sd, 0, 7.2) };
  const leg = { role: 'strand', pts: span(sd, 11, last) };
  const stemOverRing = span(st, 1.75, 2.75), bottomOverStem = span(sd, 4, 6.2), legOverArm = span(sd, 12.2, 13.8);
  const under = new Map([
    [ringTop, [stemOverRing]],
    [leg, [stemOverRing]],
    [stem, [bottomOverStem]],
    [armAndBottom, [legOverArm]],
  ]);
  const clearance = rope * (1 + .45 * gap);
  const out = [];
  for (const layer of [ringTop, stem, armAndBottom, leg]) {
    let run = [];
    for (const p of layer.pts) {
      if (under.get(layer).some(o => distToLine(p, o) < clearance)) {
        if (run.length > 1) out.push({ role: layer.role, pts: run });
        run = [];
      } else run.push(p);
    }
    if (run.length > 1) out.push({ role: layer.role, pts: run });
  }
  return out;
}

function knot({ fg, strandColor = fg, rope, gap = .75, strand = STRAND, finish = '' }) {
  return knotStrokes({ rope, gap, strand })
    .map(s => `<path d="${poly(s.pts)}" ${stroke(s.role === 'stem' ? fg : strandColor, rope)}/>`).join('') + finish;
}
