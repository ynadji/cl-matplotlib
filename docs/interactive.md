# Interactive display (`show`)

cl-matplotlib can display figures in live windows with zoom, pan, and a
cursor readout. The display stack is split into optional systems that
are **not** part of the `cl-matplotlib` meta-system — load only what you
use:

| system | what it is |
|---|---|
| `cl-matplotlib-show` | core: in-memory rendering, the zoom/pan interactor, the adapter protocol, and the `pyplot:show` hook |
| `cl-matplotlib-show-web` | browser backend — HTTP + websocket + HTML canvas (works everywhere, including over SSH) |
| `cl-matplotlib-show-sdl2` | native window backend via SDL2 (needs `libsdl2` and a display) |
| `cl-matplotlib-show-capi` | LispWorks CAPI backend (stretch; see caveats below) |

## Quick start

```lisp
(ql:quickload :cl-matplotlib-show-web)   ; or :cl-matplotlib-show-sdl2
(use-package :cl-matplotlib.pyplot)

(plot '(1 2 3 4) '(1 4 2 3))
(show)              ; opens a window/tab, returns immediately
(show :block t)     ; returns when the window/page is closed
```

`(show)` displays the current figure through whichever backend is
loaded. With several loaded, `mpl.show:*show-backend*` picks:

```lisp
(setf mpl.show:*show-backend* :web)    ; or :sdl2, :capi
(setf mpl.show:*show-backend* :auto)   ; default: best available
```

`:auto` prefers a native window (`:capi` 30 > `:sdl2` 20 > `:web` 10)
among backends whose environment check passes — SDL2 requires
`DISPLAY`/`WAYLAND_DISPLAY` (or `SDL_VIDEODRIVER`), the web backend is
always available. `(mpl.show:show figure)` displays a specific figure.

## Interaction reference

| action | web (browser) | SDL2 window |
|---|---|---|
| zoom (anchored at cursor) | scroll wheel | scroll wheel |
| pan | left-drag | left-drag |
| reset view (home) | Home button or double-click | `h` |
| save PNG | Save button (downloads last frame) | `s` (writes `figure-<time>.png` in cwd) |
| close | close the tab | `q` / Escape / close window |
| cursor data coordinates | toolbar readout | window title |

Zoom and pan operate on the axes under the cursor, respect log scales
(the math runs in scaled space), and propagate through shared axes.
Resizing the window/page re-renders the figure at the new size.

## The web backend

The first `(show)` starts one HTTP server on a random ephemeral port
(`SHOW_WEB_PORT=<port>` pins it) and opens `http://127.0.0.1:<port>/figure/<n>`
in your browser (`SHOW_WEB_NO_BROWSER=1` prints the URL instead — handy
over SSH with port forwarding: `ssh -L 8977:localhost:8977 host`).
Each `(show)` registers a new figure page on the same server;
`(mpl.show.web:stop-server)` shuts it down.

Frames travel as PNG over a binary websocket; events (wheel, drag,
home, resize) go back as JSON and are coalesced server-side so a fast
mouse can't outrun rendering. `:block t` returns when the page's last
websocket disconnects.

## The SDL2 backend

Frames are RGBA buffers uploaded into a streaming `:abgr8888` texture
(RGBA byte order on little-endian machines; `+texture-format+` in
`src/show/sdl2/sdl2-adapter.lisp` is the single constant to flip if a
platform renders swapped colors).

**macOS**: Cocoa requires the GUI event loop on the initial thread —
call `(show :block t)` from the main thread (e.g. a `ros run` script or
the initial REPL thread). The non-blocking form spawns a worker thread
and is Linux/Windows-only.

**Headless smoke test**: `SDL_VIDEODRIVER=dummy` lets the full
init/window/texture/upload path run without a display (this is what CI
does).

## The CAPI backend (LispWorks, stretch)

`cl-matplotlib-show-capi` is written best-effort without a LispWorks
environment and needs validation on a real LispWorks install. Known
soft spots, in likely order of adjustment:

- the `:input-model` wheel gesture specs (`(:gesture-spec :wheel-up)`)
  vary across LispWorks versions;
- frames are decoded from PNG via `gp:external-image :data` — correct
  but per-frame; switch to `render-figure-to-rgba` +
  `gp:image-access-pixels-from-bgra` (RGBA→BGRA shuffle) if it's slow.

## Writing a new adapter

An adapter is one class, one method, one registration:

```lisp
(defclass my-adapter () ())

(defmethod mpl.show:show-figure ((a my-adapter) figure &key block)
  (let ((it (mpl.show:make-interactor figure)))
    ;; render:  (interactor-render-rgba it) => (values rgba w h)
    ;;          (interactor-render-png it)  => (values png-octets w h)
    ;; events (pixel coords, TOP-LEFT origin):
    ;;          (interactor-zoom it x y factor)
    ;;          (interactor-pan-start/move/end it ...)
    ;;          (interactor-reset it)
    ;;          (interactor-resize it w h)
    ;;          (interactor-cursor-coords it x y) => (values x-data y-data axes)
    ...))

(mpl.show:register-show-adapter :mine (lambda () (make-instance 'my-adapter))
                                :available-fn (lambda () t)
                                :priority 15)
```

Every interactor operation returns the axes it acted on (NIL = cursor
outside all axes → nothing changed → skip the redraw). All operations
are internally locked; calling them from event threads is safe. RGBA
buffers are flat `(unsigned-byte 8)` vectors, 4 bytes/pixel, row-major
from the top-left.

## Testing

```bash
# core invariants (zoom anchoring incl. log axes, pan, reset, hit test)
ros run -- --eval '(ql:quickload :cl-matplotlib-show)' \
           --eval '(asdf:test-system :cl-matplotlib-show)' --quit

# web: pure event layer (FiveAM) + live websocket round-trip (python)
ros run -- --eval '(ql:quickload :cl-matplotlib-show-web)' \
           --eval '(asdf:test-system :cl-matplotlib-show-web)' --quit
.venv/bin/python tests/integration/test_show_web.py   # needs: pip install websocket-client

# sdl2: headless smoke
SDL_VIDEODRIVER=dummy ros run -- --eval '(ql:quickload :cl-matplotlib-show-sdl2)' \
           --eval '(asdf:test-system :cl-matplotlib-show-sdl2)' --quit
```
