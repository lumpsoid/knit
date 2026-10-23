// Shared by the icon galleries: palettes, drawing helpers, and the gallery renderer.
// ---------- palettes ----------
const PALETTES = {
  indigo: { name: 'Indigo', bg: '#5B6CFF', fg: '#FFFFFF', accent: '#FFC4A3', soft: '#C3C9FF' },
  cream:  { name: 'Cream',  bg: '#F6F1E7', fg: '#2B2F6B', accent: '#FF7A59', soft: '#8E96FF' },
  ink:    { name: 'Ink',    bg: '#1E2140', fg: '#F6F1E7', accent: '#FF8A65', soft: '#7C88FF' },
  coral:  { name: 'Coral',  bg: '#FF7A59', fg: '#FFFFFF', accent: '#2B2F6B', soft: '#FFD3C4' },
};

// ---------- geometry helpers ----------
const f = n => +n.toFixed(2);
const poly = pts => 'M' + pts.map(([x, y]) => `${f(x)} ${f(y)}`).join(' L');

// Catmull-Rom → cubic Bézier, for smooth curves through points.
function smooth(pts) {
  let d = `M${f(pts[0][0])} ${f(pts[0][1])}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += ` C${f(c1[0])} ${f(c1[1])} ${f(c2[0])} ${f(c2[1])} ${f(p2[0])} ${f(p2[1])}`;
  }
  return d;
}

// A thread that coils in loops which shrink until it runs straight (a decaying trochoid).
function loopsToLine({ x0 = 28, y0 = 54, loops = 3, B = 13, a = 2, xEnd = 88, pow = 1.15, n = 360 } = {}) {
  const T = loops * 2 * Math.PI, pts = [];
  for (let i = 0; i <= n; i++) {
    const t = T * i / n, b = B * Math.pow(1 - t / T, pow);
    pts.push([x0 + a * t - b * Math.sin(t), y0 - b * Math.cos(t)]);
  }
  pts.push([xEnd, y0]);
  return poly(pts);
}

function rng(seed) {
  return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
}

let uid = 0;
const stroke = (c, w, extra = '') => `fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" ${extra}`;

// ---------- concepts ----------

// ---------- rendering ----------
function mountGallery(CONCEPTS, favKey) {
  let palette = 'indigo';
  const favs = new Set(JSON.parse(localStorage.getItem(favKey) || '[]'));

  function svg(concept, p, w) {
    return `<svg viewBox="0 0 108 108" xmlns="http://www.w3.org/2000/svg">
      <rect width="108" height="108" fill="${p.bg}"/>${concept.draw(p, w)}</svg>`;
  }
  const icon = (c, p, w, size, shape = 'sq') =>
    `<span class="icon ${shape}" style="width:${size}px;height:${size}px">${svg(c, p, w)}</span>`;

  function render() {
    const p = PALETTES[palette], w = +document.getElementById('weight').value;
    const favOnly = document.getElementById('favOnly').checked;
    document.getElementById('grid').innerHTML = CONCEPTS
      .filter(c => !favOnly || favs.has(c.id))
      .map(c => `
      <article class="card ${favs.has(c.id) ? 'fav' : ''}">
        <h2>${c.name}<button data-fav="${c.id}" title="Favourite">★</button></h2>
        <p>${c.idea}</p>
        <div class="hero">
          ${icon(c, p, w, 150)}
          <div class="sizes">${icon(c, p, w, 72, 'ci')}${icon(c, p, w, 48)}${icon(c, p, w, 32)}${icon(c, p, w, 20)}</div>
        </div>
        <div class="trays">
          <div class="tray light">${icon(c, p, w, 52)}${icon(c, p, w, 52, 'ci')}</div>
          <div class="tray dark">${icon(c, p, w, 52)}${icon(c, p, w, 52, 'ci')}</div>
        </div>
      </article>`).join('');
    document.getElementById('home').innerHTML = CONCEPTS.map(c => `
      <div class="app" style="${favs.size && !favs.has(c.id) ? 'opacity:.35' : ''}">
        ${icon(c, p, w, 58)}<span>${c.name}</span></div>`).join('');
  }

  document.getElementById('palettes').innerHTML = Object.entries(PALETTES).map(([k, p]) =>
    `<button class="chip ${k === palette ? 'on' : ''}" data-pal="${k}">
       <span class="swatch" style="background:linear-gradient(135deg, ${p.bg} 55%, ${p.fg} 55% 78%, ${p.accent} 78%)"></span>${p.name}</button>`).join('');

  document.addEventListener('click', e => {
    const pal = e.target.closest('[data-pal]'), fav = e.target.closest('[data-fav]');
    if (pal) {
      palette = pal.dataset.pal;
      document.querySelectorAll('[data-pal]').forEach(b => b.classList.toggle('on', b === pal));
      render();
    }
    if (fav) {
      const id = fav.dataset.fav;
      favs.has(id) ? favs.delete(id) : favs.add(id);
      localStorage.setItem(favKey, JSON.stringify([...favs]));
      render();
    }
  });
  document.getElementById('weight').addEventListener('input', render);
  document.getElementById('favOnly').addEventListener('change', render);
  render();
}
