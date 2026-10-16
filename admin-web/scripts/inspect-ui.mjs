import puppeteer from 'puppeteer-core';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.normalize('C:/Users/hp g7/ZEGA-ALERT/admin-web/dist');
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PORT = 4399;
const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.json': 'application/json', '.woff2': 'font/woff2', '.ico': 'image/x-icon', '.txt': 'text/plain',
};

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  let f = path.normalize(path.join(ROOT, p));
  if (!f.startsWith(ROOT)) { res.writeHead(403); return res.end('nope'); }
  if (fs.existsSync(f) && fs.statSync(f).isDirectory()) f = path.join(f, 'index.html');
  if (!fs.existsSync(f)) {
    if (path.extname(p)) { res.writeHead(404); return res.end('404'); }
    f = path.join(ROOT, 'index.html');
  }
  res.writeHead(200, { 'content-type': MIME[path.extname(f)] || 'application/octet-stream' });
  fs.createReadStream(f).pipe(res);
});

const AUDIT = () => {
  const parse = (c) => {
    const m = (c || '').match(/rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)/);
    return m ? [ +m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4] ] : null;
  };
  const lum = (rgb) => {
    const [r, g, b] = rgb.slice(0, 3).map((v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  };
  const ratio = (a, b) => { const l1 = lum(a), l2 = lum(b); return +(((Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05))).toFixed(2); };
  const hex = (h) => {
    const m = h.match(/^#([0-9a-f]{3}|[0-9a-f]{6})$/i);
    if (!m) return null;
    let s = m[1];
    if (s.length === 3) s = s.split('').map((c) => c + c).join('');
    return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16), 1];
  };
  const parseAny = (s) => parse(s) || hex(String(s).trim());
  const comp = (fg, bg) => {
    const a = fg[3];
    return [
      Math.round(fg[0] * a + bg[0] * (1 - a)),
      Math.round(fg[1] * a + bg[1] * (1 - a)),
      Math.round(fg[2] * a + bg[2] * (1 - a)), 1,
    ];
  };
  const bgOf = (el) => {
    const stack = [];
    let method = 'solid';
    let n = el;
    while (n && n !== document.documentElement) {
      const cs = getComputedStyle(n);
      if (cs.backgroundImage && cs.backgroundImage !== 'none') {
        const found = (cs.backgroundImage.match(/rgba?\([^)]+\)|#[0-9a-f]{3,6}/gi) || []).map(parseAny).filter(Boolean);
        if (found.length) { stack.push(found[0]); method = 'first gradient stop'; }
      }
      const c = parse(cs.backgroundColor);
      if (c && c[3] > 0) {
        stack.push(c);
        if (c[3] >= 0.999) break;
      }
      n = n.parentElement;
    }
    stack.push([7, 11, 20, 1]);
    let base = stack[stack.length - 1];
    for (let i = stack.length - 2; i >= 0; i--) base = comp(stack[i], base);
    return { rgb: base, el: (el.className || el.tagName) + ' (composited)', method };
  };
  const path_ = (el) => {
    if (el === document.body) return 'body';
    let s = el.tagName.toLowerCase();
    if (el.id) return '#' + el.id;
    if (el.className && typeof el.className === 'string') s += '.' + el.className.trim().split(/\s+/).slice(0, 3).join('.');
    return s;
  };

  const vw = window.innerWidth, vh = window.innerHeight;
  const doc = document.documentElement;
  const out = {
    viewport: { vw, vh },
    title: document.title,
    scroll: { scrollWidth: doc.scrollWidth, scrollHeight: doc.scrollHeight, horizontalOverflow: doc.scrollWidth > vw + 1 },
  };

  const escaped = [];
  for (const el of document.querySelectorAll('body *')) {
    const r = el.getBoundingClientRect();
    if (r.width === 0 || r.height === 0) continue;
    if (r.right > vw + 1.5 || r.left < -1.5) {
      escaped.push({ sel: path_(el), left: Math.round(r.left), right: Math.round(r.right) });
    }
  }
  out.escapedElements = escaped.slice(0, 12);
  out.escapedCount = escaped.length;

  const box = (sel) => {
    const el = document.querySelector(sel);
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { sel, x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height), visible: r.width > 0 && r.height > 0 };
  };
  out.boxes = ['.auth', '.auth-hero', '.hero-content', '.hero-wordmark', '.shield', '.hero-flag-band',
               '.auth-panel', '.auth-form', '.auth-form-head h2', '.btn-gradient', '.auth-foot',
               '.sidebar', '.brand', '.main', '.cards', '.page-head'].map(box).filter(Boolean);

  const contrast = (sel) => {
    const el = document.querySelector(sel);
    if (!el) return { sel, missing: true };
    const cs = getComputedStyle(el);
    const fg = parseAny(cs.color);
    const bg = bgOf(el);
    if (!fg) return { sel, color: cs.color, skip: true };
    if (fg[3] < 0.05) return { sel, skip: 'transparent text (background-clip:text gradient)' };
    const fgO = fg[3] < 1 ? comp(fg, bg.rgb) : fg;
    const r = ratio(fgO, bg.rgb);
    return {
      sel,
      fg: cs.color,
      bg: `rgb(${bg.rgb[0]}, ${bg.rgb[1]}, ${bg.rgb[2]})`,
      bgVia: bg.method,
      ratio: r,
      pass: r >= 4.5 ? 'AA' : (r >= 3 ? 'AA-large' : 'FAIL'),
    };
  };
  out.contrast = ['.hero-tagline', '.hero-features li', '.hero-langs span', '.auth-form-head p',
                  '.auth-form label', '.pill.demo', '.pill.secure', '.btn-gradient',
                  '.brand strong', '.brand span', '.sidebar nav a', '.card .lbl', 'th'].map(contrast);

  out.fonts = {
    inter: document.fonts.check('700 16px Inter'),
    ethiopic: document.fonts.check('700 16px "Noto Sans Ethiopic"'),
    bodyFamily: getComputedStyle(document.body).fontFamily.split(',')[0],
    heroFont: getComputedStyle(document.querySelector('.hero-tagline') || document.body).fontFamily.split(',')[0],
  };

  const flag = performance.getEntriesByName(new URL('/brand/ethiopia-flag.png', location.origin).href)[0];
  out.flagAsset = flag ? { bytes: flag.transferSize || flag.decodedBodySize, durationMs: Math.round(flag.duration) } : 'NOT REQUESTED';

  out.svgIcons = document.querySelectorAll('.icon svg, .fi svg, .shield svg, .pill svg, .btn svg').length;
  out.heroText = (document.querySelector('.hero-wordmark') || {}).innerText;
  out.hasFlagStripe = !!document.querySelector('.hero-flag-band');

  const seam = document.querySelector('.auth-panel');
  if (seam) {
    const ps = getComputedStyle(seam, '::before');
    out.seam = { width: ps.width, height: ps.height, bg: ps.backgroundImage.slice(0, 60), display: ps.display };
  }

  // visibility of key interactive controls
  const vis = (sel) => {
    const el = document.querySelector(sel);
    if (!el) return { sel, present: false };
    const r = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    return { sel, present: true, w: Math.round(r.width), h: Math.round(r.height),
             onScreen: r.bottom > 0 && r.top < window.innerHeight && r.width > 0, display: cs.display };
  };
  out.controls = ['.sidebar-foot', '.lang-select', '.sidebar-foot .btn.ghost', '.user-chip', '.brand', '.sidebar nav'].map(vis);

  const sb = document.querySelector('.sidebar');
  const mn = document.querySelector('.main');
  if (sb && mn) {
    const nav = sb.querySelector('nav');
    out.layoutDiag = {
      sidebarOffsetH: sb.offsetHeight,
      sidebarRect: Math.round(sb.getBoundingClientRect().bottom),
      mainOffsetTop: mn.offsetTop,
      mainRectTop: Math.round(mn.getBoundingClientRect().top),
      order: `${getComputedStyle(sb).order} | ${getComputedStyle(mn).order}`,
      sidebarPos: getComputedStyle(sb).position,
      nav: nav ? { scrollW: nav.scrollWidth, clientW: nav.clientWidth, overflowX: getComputedStyle(nav).overflowX,
                   items: nav.children.length, scrollable: nav.scrollWidth > nav.clientWidth } : null,
      overlap: Math.round(sb.getBoundingClientRect().bottom) - Math.round(mn.getBoundingClientRect().top),
    };
  }

  // any element whose content is clipped by its own box
  const clippedText = [];
  for (const el of document.querySelectorAll('h1,h2,h3,p,span,a,button,td,th,li')) {
    if (el.scrollWidth > el.clientWidth + 2 && getComputedStyle(el).overflow !== 'visible') {
      clippedText.push({ sel: path_(el), scrollWidth: el.scrollWidth, clientWidth: el.clientWidth, text: (el.innerText || '').slice(0, 40) });
    }
  }
  out.clippedText = clippedText.slice(0, 10);
  return out;
};

async function run() {
  await new Promise((r) => server.listen(PORT, r));
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--no-sandbox', '--disable-gpu', '--font-render-hinting=none'] });
  const results = {};

  for (const vp of [{ name: 'desktop', w: 1440, h: 900 }, { name: 'laptop', w: 1280, h: 720 }, { name: 'mobile', w: 390, h: 844 }]) {
    const page = await browser.newPage();
    const errors = [];
    page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') errors.push(`${m.type()}: ${m.text()}`); });
    page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
    await page.setViewport({ width: vp.w, height: vp.h, deviceScaleFactor: 1 });
    await page.goto(`http://localhost:${PORT}/login`, { waitUntil: 'networkidle2', timeout: 45000 });
    await new Promise((r) => setTimeout(r, 2500));
    const audit = await page.evaluate(AUDIT);
    audit.consoleIssues = errors.slice(0, 10);
    results[`login-${vp.name}`] = audit;
    await page.close();
  }

  // try a real login and audit the dashboard (desktop + mobile)
  for (const vp of [{ name: 'desktop', w: 1440, h: 900 }, { name: 'mobile', w: 390, h: 844 }]) {
    try {
      const page = await browser.newPage();
      const errors = [];
      page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
      await page.setViewport({ width: vp.w, height: vp.h });
      await page.goto(`http://localhost:${PORT}/login`, { waitUntil: 'networkidle2', timeout: 45000 });
      await page.click('.btn-gradient');
      await page.waitForFunction(() => location.pathname !== '/login', { timeout: 120000 }).catch(() => {});
      await new Promise((r) => setTimeout(r, 5000));
      const audit = await page.evaluate(AUDIT);
      audit.path = await page.evaluate(() => location.pathname);
      audit.consoleIssues = errors.slice(0, 10);
      results[`dashboard-${vp.name}`] = audit;
      await page.close();
    } catch (e) {
      results[`dashboard-${vp.name}`] = { failed: e.message };
    }
  }

  console.log(JSON.stringify(results, null, 2));
  await browser.close();
  server.close();
}

run().catch((e) => { console.error('FATAL', e); server.close(); process.exit(1); });
