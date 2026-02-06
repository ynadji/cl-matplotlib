
## Phase 3a — Artist Hierarchy (2026-02-06)

### Patterns
- CLOS classes with `initialize-instance :after` work well for Python `__init__` chains
- `defgeneric draw (artist renderer)` provides clean polymorphic dispatch
- Mock renderer pattern (recording calls) excellent for testing draw protocol
- Package exports must be comprehensive — test file imports everything it needs

### Gotchas
- CL reader interprets `:|`, `:*`, `:+`, `:.`, `:_` as valid symbols but they cause parsing issues in `case` forms
- Solution: Use descriptive keywords `:plus`, `:star`, `:vline`, `:hline`, `:point` instead
- Must be careful with `defmethod (setf accessor) :after` — useful for stale tracking
- FancyBboxPatch simplified (no rounded corners yet) — just uses unit rectangle

### Stats
- 119/119 tests passing (100%)
- Files: artist.lisp, lines.lisp, patches.lisp, text.lisp, markers.lisp, image.lisp
- Classes: artist, line-2d, patch, rectangle, circle, ellipse, polygon, wedge, arc, path-patch, fancy-bbox-patch, text-artist, marker-style, axes-image, mock-renderer, graphics-context

## Phase 3b — Vecto PNG Backend (2026-02-06)

### Implementation Summary
- **renderer-base.lisp**: RendererBase protocol with 10 generic functions (draw-path, draw-image, draw-text, draw-markers, draw-gouraud-triangles, get-canvas-width-height, points-to-pixels, renderer-clear, renderer-option-image-nocomposite, canvas protocol)
- **backend-vecto.lisp**: Full Vecto implementation with renderer-vecto, canvas-vecto, graphics-context mapping, path rendering, image blitting, text rendering
- **52 tests, 52 checks, 100% pass rate**
- **20 PNG files generated** across all test scenarios

### Architecture Decisions

1. **Render function pattern**: Canvas stores an optional `render-fn` lambda, executed inside `print-png`'s `vecto:with-canvas`. This avoids needing to track Vecto state externally — all draw calls happen within the active canvas context.

2. **Graphics context mapping**: Dedicated `%apply-gc-to-vecto` function maps all GC properties (linewidth, capstyle, joinstyle, dashes, clip-rect) to Vecto state calls. Called once per `draw-path` inside `with-graphics-state`.

3. **Path tracing**: `%trace-path-to-vecto` walks mpl-path vertices+codes and emits Vecto operations. Supports all 5 path codes: MOVETO, LINETO, CURVE3 (quadratic-to), CURVE4 (curve-to), CLOSEPOLY (close-subpath).

4. **Fill+stroke pattern**: Vecto consumes the path on fill. For fill+stroke, we trace path twice — once for fill-path, once for stroke. This is correct per Vecto's semantics.

5. **Canvas-base / canvas-vecto split**: Base class holds width/height/dpi/figure. Vecto subclass adds render-fn and the print-png implementation with vecto:with-canvas.

6. **Image blitting**: Direct buffer access via `zpng:image-data (vecto::image vecto::*graphics-state*)`. Alpha-over compositing in pure CL, matching Phase 0 poc.lisp approach.

### Gotchas Encountered

1. **CL `declare` placement**: `(declare (ignore ...))` MUST be at the top of a function body, not at the end. Placing it after executable forms causes "There is no function named DECLARE" error.

2. **transform-point API**: Takes `(transform point-as-list)`, NOT `(transform x y)`. Returns a 2-element array, not multiple values. Must destructure: `(let ((result (transform-point tr (list x y)))) (values (aref result 0) (aref result 1)))`.

3. **Vecto path consumption**: `vecto:fill-path` and `vecto:stroke` consume the current path. To fill+stroke, must trace the path twice.

4. **Cap style mapping**: matplotlib uses `:projecting`, Vecto uses `:square`. Must map `:projecting` → `:square` in the GC-to-Vecto translation.

5. **Color resolution**: `to-rgba` returns multiple values (r g b a), need `multiple-value-list` to capture as a list for storage in gc-foreground/gc-background.

### Files Created
- `src/backends/renderer-base.lisp` — ~190 LOC, protocol + base classes
- `src/backends/backend-vecto.lisp` — ~430 LOC, full Vecto implementation
- `tests/test-backend-vecto.lisp` — ~420 LOC, 31 tests, 52 checks

### Evidence Files
- `.sisyphus/evidence/phase3b-backend-render.png` — 640x480, 10KB, red line + blue rect
- `.sisyphus/evidence/phase3b-dashed-line.png` — 400x300, 4.6KB, dashed line [5,3] pattern
