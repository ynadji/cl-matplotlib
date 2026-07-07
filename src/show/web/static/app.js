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
      coordsEl.textContent = (msg.x !== undefined && msg.x !== null)
        ? `x=${Number(msg.x).toPrecision(6)}  y=${Number(msg.y).toPrecision(6)}`
        : '';
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

// Drag pan.
let dragging = false;
canvas.addEventListener('mousedown', (ev) => {
  if (ev.button !== 0) return;
  dragging = true;
  const p = pos(ev);
  send({ type: 'mousedown', x: p.x, y: p.y });
});
window.addEventListener('mouseup', () => {
  if (dragging) { dragging = false; send({ type: 'mouseup' }); }
});

// Mousemove throttled to one message per animation frame; the server
// coalesces further. Drives both pan (while dragging) and the coords
// readout (while hovering).
let pendingMove = null;
canvas.addEventListener('mousemove', (ev) => {
  const p = pos(ev);
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
