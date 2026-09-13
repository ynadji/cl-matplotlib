// cl-matplotlib web display client.
// One websocket carries every figure: binary messages are frames
// prefixed by a 4-byte big-endian window id, text messages are JSON
// ("windows" = the tab list, "coords" = a readout). Events go back as
// JSON with the window id. The server owns all coordinate math and the
// interaction semantics; this file only routes and draws.

const tabsEl = document.getElementById('tabs');
const wrapEl = document.getElementById('fig-wrap');
const emptyEl = document.getElementById('empty');
const coordsEl = document.getElementById('coords');
const statusEl = document.getElementById('status');

const windows = new Map();   // id -> { canvas, ctx, lastBlob, title }
let activeId = null;
// /figure/<id> asks for that tab once the list arrives
const wantedId = (() => {
  const m = location.pathname.match(/^\/figure\/(\d+)/);
  return m ? Number(m[1]) : null;
})();
let wantedApplied = false;

const ws = new WebSocket(`ws://${location.host}/ws`);
ws.binaryType = 'arraybuffer';

function send(obj) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
}

// ---- windows / tabs --------------------------------------------------

function ensureWindow(id, title) {
  let w = windows.get(id);
  if (!w) {
    const canvas = document.createElement('canvas');
    canvas.dataset.fig = id;
    wrapEl.appendChild(canvas);
    attachCanvasEvents(canvas, id);
    w = { canvas, ctx: canvas.getContext('2d'), lastBlob: null, title: title || `Figure ${id}` };
    windows.set(id, w);
  }
  if (title) w.title = title;
  return w;
}

function setActive(id) {
  activeId = id;
  for (const [wid, w] of windows) w.canvas.classList.toggle('active', wid === id);
  for (const t of tabsEl.children) t.classList.toggle('active', Number(t.dataset.fig) === id);
  coordsEl.textContent = '';
}

function renderTabs(items, active) {
  const seen = new Set();
  tabsEl.innerHTML = '';
  for (const item of items) {
    seen.add(item.id);
    ensureWindow(item.id, item.title);
    const tab = document.createElement('div');
    tab.className = 'tab';
    tab.dataset.fig = item.id;
    const label = document.createElement('span');
    label.textContent = item.title;
    const close = document.createElement('span');
    close.className = 'close';
    close.textContent = '×';
    close.title = 'Close';
    close.onclick = (ev) => { ev.stopPropagation(); send({ type: 'close', fig: item.id }); };
    tab.appendChild(label);
    tab.appendChild(close);
    tab.onclick = () => send({ type: 'activate', fig: item.id });
    tabsEl.appendChild(tab);
  }
  // windows that disappeared
  for (const [id, w] of windows) {
    if (!seen.has(id)) { w.canvas.remove(); windows.delete(id); }
  }
  emptyEl.hidden = items.length > 0;
  if (!wantedApplied && wantedId !== null && seen.has(wantedId)) {
    wantedApplied = true;
    if (active !== wantedId) { send({ type: 'activate', fig: wantedId }); return; }
  }
  setActive(active !== null && seen.has(active) ? active : (items.length ? items[items.length - 1].id : null));
}

// ---- incoming ------------------------------------------------------------

ws.onmessage = async (ev) => {
  if (ev.data instanceof ArrayBuffer) {
    const view = new DataView(ev.data);
    const id = view.getUint32(0);
    const png = new Blob([ev.data.slice(4)], { type: 'image/png' });
    const w = ensureWindow(id);
    w.lastBlob = png;
    const bmp = await createImageBitmap(png);
    w.canvas.width = bmp.width;
    w.canvas.height = bmp.height;
    w.ctx.drawImage(bmp, 0, 0);
    bmp.close();
    return;
  }
  const msg = JSON.parse(ev.data);
  if (msg.type === 'windows') {
    renderTabs(msg.items, msg.active);
  } else if (msg.type === 'coords') {
    if (msg.fig !== undefined && msg.fig !== activeId) return;
    // The server decides what the readout says; this only formats it.
    let text = (msg.x !== undefined && msg.x !== null)
      ? `x=${Number(msg.x).toPrecision(6)}  y=${Number(msg.y).toPrecision(6)}`
      : '';
    if (msg.label !== undefined && msg.label !== null) {
      const z = (msg.pz !== undefined && msg.pz !== null) ? `  z=${Number(msg.pz).toPrecision(6)}` : '';
      text = `${msg.label}[${msg.index}]  x=${Number(msg.px).toPrecision(6)}  y=${Number(msg.py).toPrecision(6)}${z}`;
    }
    coordsEl.textContent = text;
    document.body.classList.toggle('cursor-mode', msg.mode === 'cursor');
  }
};
ws.onclose = () => { statusEl.textContent = 'disconnected'; };

// ---- pointer events on a figure's canvas ---------------------------------

function attachCanvasEvents(canvas, id) {
  const pos = (ev) => {
    const r = canvas.getBoundingClientRect();
    return { x: Math.round(ev.clientX - r.left), y: Math.round(ev.clientY - r.top) };
  };
  // Scroll zoom, anchored at the cursor (server-side math).
  canvas.addEventListener('wheel', (ev) => {
    ev.preventDefault();
    const p = pos(ev);
    send({ type: 'wheel', fig: id, x: p.x, y: p.y, deltaY: ev.deltaY });
  }, { passive: false });

  // Drag pan (2D) / rotate (3D; shift-drag pans). A press-and-release
  // without movement is a click: select a trace, toggle a legend entry,
  // or pin a data cursor — the server decides.
  let dragging = false, pressAt = null, moved = false;
  canvas.addEventListener('mousedown', (ev) => {
    if (ev.button !== 0) return;
    dragging = true; moved = false;
    const p = pos(ev); pressAt = p;
    send({ type: 'mousedown', fig: id, x: p.x, y: p.y, shift: ev.shiftKey, button: ev.button });
  });
  window.addEventListener('mouseup', (ev) => {
    if (!dragging) return;
    dragging = false;
    send({ type: 'mouseup', fig: id });
    if (!moved && pressAt) send({ type: 'click', fig: id, x: pressAt.x, y: pressAt.y, shift: ev.shiftKey, ctrl: ev.ctrlKey });
    pressAt = null;
  });

  // Mousemove throttled to one message per animation frame; the server
  // coalesces further. Drives pan/rotate (while dragging) and the coords
  // readout (while hovering).
  let pendingMove = null;
  canvas.addEventListener('mousemove', (ev) => {
    const p = pos(ev);
    lastMouse = p;
    if (dragging && pressAt && (Math.abs(p.x - pressAt.x) > 2 || Math.abs(p.y - pressAt.y) > 2)) moved = true;
    if (pendingMove === null) {
      pendingMove = p;
      requestAnimationFrame(() => {
        send({ type: 'mousemove', fig: id, x: pendingMove.x, y: pendingMove.y });
        pendingMove = null;
      });
    } else {
      pendingMove = p;
    }
  });
  canvas.addEventListener('mouseleave', () => { coordsEl.textContent = ''; });
  canvas.addEventListener('dblclick', () => send({ type: 'home', fig: id }));
}

// ---- toolbar and keyboard -----------------------------------------------

let lastMouse = null;
function sendKey(key, opts = {}) {
  if (activeId === null) return;
  send({ type: 'keydown', fig: activeId, key, ctrl: !!opts.ctrl, shift: !!opts.shift,
         x: lastMouse ? lastMouse.x : null, y: lastMouse ? lastMouse.y : null });
}
document.getElementById('home').onclick = () => { if (activeId !== null) send({ type: 'home', fig: activeId }); };
document.getElementById('cursor').onclick = () => sendKey('c');
document.getElementById('undo').onclick = () => sendKey('z', { ctrl: true });
document.getElementById('redo').onclick = () => sendKey('z', { ctrl: true, shift: true });
document.getElementById('new').onclick = () => send({ type: 'new' });
document.getElementById('closetab').onclick = () => { if (activeId !== null) send({ type: 'close', fig: activeId }); };

// Save: download the active figure's most recent frame, no server round-trip.
document.getElementById('save').onclick = () => {
  const w = windows.get(activeId);
  if (!w || !w.lastBlob) return;
  const a = document.createElement('a');
  a.href = URL.createObjectURL(w.lastBlob);
  a.download = `figure-${activeId}.png`;
  a.click();
  URL.revokeObjectURL(a.href);
};

// The key map lives on the server (mpl.show:*key-bindings*); ctrl-w
// closes the tab here.
window.addEventListener('keydown', (ev) => {
  if (ev.target && (ev.target.tagName === 'INPUT' || ev.target.tagName === 'TEXTAREA')) return;
  const ctrl = ev.ctrlKey || ev.metaKey;
  if (ctrl && ev.key === 'w') { ev.preventDefault(); document.getElementById('closetab').onclick(); return; }
  const plain = ['h', 'c', 'Escape', 'Delete', 'Backspace'].includes(ev.key) && !ctrl;
  const chord = ctrl && ['c', 'x', 'v', 'z', 'Z', 'y'].includes(ev.key);
  if (!plain && !chord) return;
  sendKey(ev.key, { ctrl, shift: ev.shiftKey });
  ev.preventDefault();
});

// Window resize → re-render the active figure at the new size (debounced).
let resizeTimer = null;
window.addEventListener('resize', () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => {
    if (activeId === null) return;
    send({
      type: 'resize', fig: activeId,
      w: Math.max(100, window.innerWidth - 32),
      h: Math.max(100, window.innerHeight - wrapEl.offsetTop - 32),
    });
  }, 200);
});
