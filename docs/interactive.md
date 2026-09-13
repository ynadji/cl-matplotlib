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
| `cl-matplotlib-show-emacs` | Emacs backend — SVG image buffer over the SLIME/SLY connection (static; no window system or server needed) |

## Quick start

```lisp
(ql:quickload :cl-matplotlib-show-web)   ; or :cl-matplotlib-show-sdl2
(use-package :cl-matplotlib.pyplot)

(plot '(1 2 3 4) '(1 4 2 3))
(show)              ; opens a window/tab, returns immediately
(show :block t)     ; returns when the window/page is closed
```

`(show)` displays every open figure — like matplotlib's `plt.show()` —
with the current one on top, through whichever backend is loaded;
`(mpl.show:show figure)` shows one figure. With several loaded, `mpl.show:*show-backend*` picks:

```lisp
(setf mpl.show:*show-backend* :web)    ; or :sdl2, :capi, :emacs
(setf mpl.show:*show-backend* :auto)   ; default: best available
```

`:auto` prefers a native window (`:capi` 30 > `:sdl2` 20 > `:emacs` 15 > `:web` 10)
among backends whose environment check passes — SDL2 requires
`DISPLAY`/`WAYLAND_DISPLAY` (or `SDL_VIDEODRIVER`), the web backend is
always available. `(mpl.show:show figure)` displays a specific figure.

## Interaction reference

Both live backends share one event dispatcher (`src/show/events.lisp`),
so they behave the same; the browser client is a dumb terminal.

| action | web (browser) | SDL2 window |
|---|---|---|
| zoom (anchored at cursor; 3D: about the center) | scroll wheel | scroll wheel |
| pan (2D) / rotate (3D) | left-drag | left-drag |
| pan a 3D view | shift-drag | shift-drag |
| reset view (home) | Home button, `h`, or double-click | `h` |
| select a trace | click it | click it |
| copy / cut / paste the selected trace | ctrl-c / ctrl-x / ctrl-v | same |
| delete the selected trace | Delete | Delete |
| undo / redo | ctrl-z / ctrl-shift-z (toolbar buttons too) | same |
| hide or show a series | click its legend entry | same |
| data cursor mode (click pins a vertex's value) | Cursor button or `c` | `c` |
| clear selection and pins | Escape | Escape |
| save PNG | Save button (downloads last frame) | `s` (writes `figure-<time>.png` in cwd) |
| switch figure | click its tab | focus its window |
| new empty figure | New button | — |
| close | Close button, the tab's ×, or ctrl-w | `q` / the window's close button |
| cursor readout (data coords, nearest vertex) | toolbar readout | window title |

Paste targets the axes under the pointer (else the figure's first axes)
and works across figures and windows: the clipboard
(`mpl.show:*trace-clipboard*`) is global. Edits are undoable per figure.
The selection highlight and pinned cursors are drawn as an overlay, never
by mutating the figure's artists.

Zoom and pan operate on the axes under the cursor, respect log scales
(the math runs in scaled space), and propagate through shared axes. A 3D
axes rotates like matplotlib's (`Axes3D._on_move`) and zooms by scaling
its projected window, leaving ticks in place. Resizing the window/page
re-renders the figure at the new size.

The key map is `mpl.show:*key-bindings*`; SDL2 maps its scancodes onto
the browser key names so one table serves both.

## Windows and figures

Every shown figure is a window of the window manager (`mpl.show:*wm*`),
whatever the backend: `wm-register` gives it an id, a title ("Figure n"
from pyplot, or `:title`) and an interactor; `wm-windows`, `wm-find`,
`wm-activate`, `wm-close`, `wm-close-all` and `wm-wait-closed` manage
them, and `wm-add-listener` hands backends the `:added` / `:removed` /
`:activated` / `:changed` events they render from. The active window is
pyplot's current figure — `(gca)` and a paste follow the tab you
clicked — and `(close-figure)` closes the figure's window, which unblocks
a pending `(show :block t)`. `wm-notify-changed` asks every backend for a
fresh frame after the REPL edits a shown figure.

## Frame times

Every interaction re-renders the whole figure through the Vecto
rasterizer. `benchmarks/show_frame_benchmark.lisp` prints ms per frame;
on a 2024 laptop at 640x480:

| figure | ms/frame |
|---|---|
| empty axes | 7 |
| line plot with title and legend | 25 |
| 5,000-point scatter | 48 |
| 40x40 colormapped surface (3D) | 76 |

The interactive path fills opaque axis-aligned rectangles (figure and
axes backgrounds) directly instead of through the anti-aliased scanline
rasterizer (`mpl.backends:*fast-rect-fills*`; file output keeps the exact
rasterizer), keeps font loaders across frames, and coalesces input so a
drag renders once per idle step rather than once per motion event.

## The web backend

The first `(show)` starts one HTTP server on a random ephemeral port
(`SHOW_WEB_PORT=<port>` pins it) and opens `http://127.0.0.1:<port>/`
in your browser (`SHOW_WEB_NO_BROWSER=1` prints the URL instead — handy
over SSH with port forwarding: `ssh -L 8977:localhost:8977 host`).
That one page shows every figure as a tab: a later `(show)` from the
REPL adds a tab to the page already open rather than opening another
browser window, `/figure/<n>` opens the page on that tab, and the New
button makes an empty pyplot figure. `(mpl.show.web:stop-server)`
shuts the server down and closes every window.

The page holds one websocket, `/ws`, for all figures. Server to client:
a JSON `windows` message (the tab list and the active id) on every
window-manager event, JSON `coords` readouts, and binary frames — a
4-byte big-endian window id followed by the PNG. Client to server: JSON
events carrying `fig` (wheel, drag, click, keydown, resize, ...) plus the
page events `activate`, `close`, `new` and `refresh`. Events are
coalesced server-side so a fast mouse can't outrun rendering. The server
pings each page every 10 s so an idle or background tab stays connected
(hunchentoot drops a silent socket after 20 s), and the page reconnects
by itself if the socket drops. `:block t` returns when the figure's
window closes — its tab, `(close-figure)`, or the last page staying
away for 5 s, which closes every window.

## The SDL2 backend

One native window per figure, all driven by one event loop that mirrors
the window manager: a figure shown from the REPL while windows are open
pops up as a new window, a window closed anywhere (its close button,
`q`, `(close-figure)`, a web tab) disappears here too, and focusing a
window makes its figure the current one. Copy in one window, paste in
another. The first `(show)` starts the loop — in the calling thread for
`:block t`, which returns when that figure's window closes (remaining
windows move to a worker thread), else on a worker; later `(show)`s just
add windows, and `:block t` waits for theirs to close.

Frames are RGBA buffers uploaded into a streaming `:abgr8888` texture
(RGBA byte order on little-endian machines; `+texture-format+` in
`src/show/sdl2/sdl2-adapter.lisp` is the single constant to flip if a
platform renders swapped colors).

**macOS**: Cocoa requires the GUI event loop on the initial thread, and
cl-sdl2 takes that thread over to pump SDL. From a terminal REPL (whose
thread *is* the initial thread) `(show)` therefore runs the loop right
there and the REPL resumes once every window is closed — build all your
figures first, then `(show)` once to get a window for each. For a live
REPL alongside SDL2 windows use SLIME/Sly (the REPL runs on another
thread) or the web backend.

**Headless tests**: `SDL_VIDEODRIVER=dummy` lets the full
init/window/texture/upload path and the multi-window loop run without a
display (this is what CI does).

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

## The Emacs backend

`cl-matplotlib-show-emacs` displays figures inside Emacs itself. Each
`(show)` renders the figure to SVG text and, through swank/slynk's
`eval-in-emacs`, drops it into the `*cl-matplotlib*` buffer in
`image-mode` (Emacs renders SVG natively). No file is written, no server
runs, and there is no elisp to install. The image is static: no zoom or
pan, and `:block` is ignored.

One Emacs setting is required, since SLIME/SLY refuse Lisp-initiated
evaluation by default:

```elisp
(setq slime-enable-evaluate-in-emacs t)   ; SLIME
(setq sly-enable-evaluate-in-emacs t)     ; SLY
```

Then, in the SLIME/SLY REPL:

```lisp
(ql:quickload '(:cl-matplotlib-show-emacs :ggplot))

(plt:plot '(1 2 3) '(1 4 2))
(plt:show)                     ; pyplot: current figure → Emacs buffer

(gg:ggshow my-plot)            ; ggplot: any plot value, same backend
```

`:auto` picks `:emacs` whenever an Emacs connection is live and no native
window backend is available; `(setf mpl.show:*show-backend* :emacs)`
forces it. `mpl.show.emacs:*buffer-name*` changes the target buffer.
Text in the SVG references font names rather than embedding outlines, so
Emacs's librsvg substitutes the fonts it has installed.

`gg:ggshow` is backend-agnostic: it draws the plot and hands the figure
to `mpl.pyplot:*show-hook*`, so it works with the web and SDL2 backends
too. With no backend loaded it prints a hint, like `(show)`.
