// cl-matplotlib web display client.
// Receives binary PNG frames over the websocket, draws them on the
// canvas, and sends zoom/pan/home/resize events back as JSON. The
// server owns all coordinate math; this file is deliberately dumb.

const figId = location.pathname.split('/').pop();
const canvas = document.getElementById('fig');
const ctx = canvas.getContext('2d');
const coordsEl = document.getElementById('coords');
const statusEl = document.getElementById('status');
let lastBlob = null;

const ws = new WebSocket(`ws://${location.host}/ws?fig=${figId}`);
ws.binaryType = 'blob';

ws.onmessage = async (ev) => {
  if (ev.data instanceof Blob) {
    lastBlob = ev.data;
    const bmp = await createImageBitmap(ev.data);
    canvas.width = bmp.width;
    canvas.height = bmp.height;
    ctx.drawImage(bmp, 0, 0);
    bmp.close();
  } else {
    const msg = JSON.parse(ev.data);
    if (msg.type === 'coords') {
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
  }
};
ws.onclose = () => { statusEl.textContent = 'disconnected'; };

function send(obj) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
}

function pos(ev) {
  const r = canvas.getBoundingClientRect();
  return { x: Math.round(ev.clientX - r.left), y: Math.round(ev.clientY - r.top) };
}

// Scroll zoom, anchored at the cursor (server-side math).
canvas.addEventListener('wheel', (ev) => {
  ev.preventDefault();
  const p = pos(ev);
  send({ type: 'wheel', x: p.x, y: p.y, deltaY: ev.deltaY });
}, { passive: false });

// Drag pan (2D) / rotate (3D; shift-drag pans). A press-and-release
// without movement is a click: select a trace, toggle a legend entry,
// or pin a data cursor — the server decides.
let dragging = false;
let pressAt = null;
let moved = false;
canvas.addEventListener('mousedown', (ev) => {
  if (ev.button !== 0) return;
  dragging = true;
  moved = false;
  const p = pos(ev);
  pressAt = p;
  send({ type: 'mousedown', x: p.x, y: p.y, shift: ev.shiftKey, button: ev.button });
});
window.addEventListener('mouseup', (ev) => {
  if (!dragging) return;
  dragging = false;
  send({ type: 'mouseup' });
  if (!moved && pressAt) {
    send({ type: 'click', x: pressAt.x, y: pressAt.y, shift: ev.shiftKey, ctrl: ev.ctrlKey });
  }
  pressAt = null;
});

// Mousemove throttled to one message per animation frame; the server
// coalesces further. Drives both pan (while dragging) and the coords
// readout (while hovering).
let pendingMove = null;
canvas.addEventListener('mousemove', (ev) => {
  const p = pos(ev);
  if (dragging && pressAt && (Math.abs(p.x - pressAt.x) > 2 || Math.abs(p.y - pressAt.y) > 2)) moved = true;
  if (pendingMove === null) {
    pendingMove = p;
    requestAnimationFrame(() => {
      send({ type: 'mousemove', x: pendingMove.x, y: pendingMove.y });
      pendingMove = null;
    });
  } else {
    pendingMove = p;
  }
});
canvas.addEventListener('mouseleave', () => { coordsEl.textContent = ''; });

// Home: toolbar button or double-click.
canvas.addEventListener('dblclick', () => send({ type: 'home' }));
document.getElementById('home').onclick = () => send({ type: 'home' });

// Toolbar buttons are keyboard shortcuts in disguise; the key map lives
// on the server (mpl.show:*key-bindings*).
let lastMouse = null;
canvas.addEventListener('mousemove', (ev) => { lastMouse = pos(ev); });
function sendKey(key, opts = {}) {
  send({ type: 'keydown', key, ctrl: !!opts.ctrl, shift: !!opts.shift,
         x: lastMouse ? lastMouse.x : null, y: lastMouse ? lastMouse.y : null });
}
document.getElementById('cursor').onclick = () => sendKey('c');
document.getElementById('undo').onclick = () => sendKey('z', { ctrl: true });
document.getElementById('redo').onclick = () => sendKey('z', { ctrl: true, shift: true });
window.addEventListener('keydown', (ev) => {
  if (ev.target && (ev.target.tagName === 'INPUT' || ev.target.tagName === 'TEXTAREA')) return;
  const ctrl = ev.ctrlKey || ev.metaKey;
  const plain = ['h', 'c', 'Escape', 'Delete', 'Backspace'].includes(ev.key) && !ctrl;
  const chord = ctrl && ['c', 'x', 'v', 'z', 'Z', 'y'].includes(ev.key);
  if (!plain && !chord) return;
  sendKey(ev.key, { ctrl, shift: ev.shiftKey });
  ev.preventDefault();
});

// Save: download the most recent frame, no server round-trip.
document.getElementById('save').onclick = () => {
  if (!lastBlob) return;
  const a = document.createElement('a');
  a.href = URL.createObjectURL(lastBlob);
  a.download = `figure-${figId}.png`;
  a.click();
  URL.revokeObjectURL(a.href);
};

// Window resize → re-render the figure at the new size (debounced).
let resizeTimer = null;
window.addEventListener('resize', () => {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => {
    const wrap = document.getElementById('fig-wrap');
    send({
      type: 'resize',
      w: Math.max(100, window.innerWidth - 32),
      h: Math.max(100, window.innerHeight - wrap.offsetTop - 32),
    });
  }, 200);
});
