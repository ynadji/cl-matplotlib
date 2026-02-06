
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

## Phase 3d Findings — Font Management, Text-to-Path, AFM Parser
Date: 2026-02-06

### Implementation Summary
- **font-manager.lisp**: Font discovery (system dirs + shipped), CSS-like matching (family/weight/style), zpb-ttf-based property extraction, font cache, font-loader cache
- **text-path.lisp**: zpb-ttf glyph contour → mpl-path conversion, text string → list of paths, multi-line layout with halign/valign
- **afm.lisp**: Full AFM parser (header, char metrics, kern pairs), Unicode→Type1 name mapping
- **DejaVu Sans font shipped** at `data/fonts/ttf/DejaVuSans.ttf` (756KB)
- **84 tests, 84 checks, 100% pass rate**

### Architecture Decisions

1. **Font manager as CLOS class with singleton pattern** — `*font-manager*` global, `ensure-font-manager` for lazy init. Font-loaders cached in hash table keyed by path.

2. **CSS-like font matching with scoring** — Each font entry scored against target (family, weight, style). Lower score = better match. Family mismatch = 10000, style mismatch = 1000, weight = absolute difference. This gives a reasonable CSS-like cascade.

3. **zpb-ttf contour conversion** — `explicit-contour-points` gives on/off curve points. On-curve = LINETO, off-curve = CURVE3 (quadratic Bézier). Each contour closed with CLOSEPOLY. All contours merged into one compound path per glyph.

4. **Font units → points scale** — `scale = size / units-per-em`. DejaVu Sans has 2048 units/em. All metrics (advance width, ascender, descender, bbox) scaled by this factor.

5. **AFM parser as separate functions** — No CLOS, just `parse-afm-file` returning `afm-font` struct with hash-table storage. Matches matplotlib's stateless parser approach.

### Gotchas Encountered

1. **zpb-ttf `unsupported-format` is a CONDITION not ERROR** — `zpb-ttf::unsupported-format` inherits from `condition`, not `error`. Handler-case catching `error` won't catch it. Must catch `condition` instead. This happens with OpenType fonts using PostScript (CFF) outlines — zpb-ttf only handles TrueType outlines.

2. **CL setf chain cannot contain loops** — In a multi-place `setf` form like `(setf (gethash x ht) "a" (loop ...) ...)`, the loop return value is interpreted as a place, causing `(setf BLOCK)` error. Must break setf into separate forms around loops.

3. **Font discovery performance** — Scanning system fonts via `directory` with wildcard patterns up to 3 levels deep works but is slow on first run. Cache serialization to `~/.cache/cl-matplotlib/fontlist.cache` mitigates this.

4. **Glyph space has no outlines** — The space character (U+0020) has a glyph with advance width but zero contours. `text-to-path` correctly returns no path for space while still advancing the x position.

5. **Kerning API** — `zpb-ttf:kerning-offset` takes glyph objects (not characters), and may return NIL for pairs with no kerning. Must guard with `when kern`.

### zpb-ttf API Used
- `open-font-loader` / `close-font-loader` / `with-font-loader`
- `family-name`, `subfamily-name`, `units/em`, `ascender`, `descender`
- `find-glyph`, `advance-width`, `bounding-box`
- `glyph-contours` (via `do-contours`), `explicit-contour-points`
- `on-curve-p`, `x`, `y` (point accessors)
- `kerning-offset`, `xmin`, `ymin`, `xmax`, `ymax` (bbox)

### Files Created
- `src/rendering/font-manager.lisp` — ~370 LOC, font discovery + matching + cache
- `src/rendering/text-path.lisp` — ~170 LOC, text→path + multi-line layout
- `src/rendering/afm.lisp` — ~330 LOC, AFM parser + Unicode→Type1 mapping
- `data/fonts/ttf/DejaVuSans.ttf` — 756KB shipped font
- `tests/test-font-manager.lisp` — ~400 LOC, 47 tests, 84 checks

### Evidence Files
- `.sisyphus/evidence/phase3d-font-metrics.txt` — Font loading, metrics, text-to-path
- `.sisyphus/evidence/phase3d-test-results.txt` — 84/84 checks pass (100%)
