
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

## Phase 4a — Figure, Canvas, savefig Pipeline (2026-02-06)

### Implementation Summary
- **layout-engine.lisp**: LayoutEngine base, PlaceHolderLayoutEngine (no-op), TightLayoutEngine (simplified)
- **figure.lisp**: mpl-figure class inheriting from artist, FigureCanvas integration, savefig with format detection, SubFigure support
- **129 tests, 129 checks, 100% pass rate**
- **Evidence**: phase4a-empty-figure.png (640x480 white PNG)

### Architecture Decisions

1. **Figure as Artist subclass**: mpl-figure inherits from mpl.rendering:artist, getting all artist properties (visible, zorder, transform, etc.) for free. The figure's `draw` method follows matplotlib's pattern: background first, then children sorted by z-order.

2. **savefig creates canvas on-the-fly**: Following matplotlib's pattern, savefig creates a fresh canvas-vecto for each save operation rather than reusing a stored canvas. This allows DPI/format overrides per-save without mutating the figure permanently.

3. **Property restoration via unwind-protect**: savefig temporarily overrides facecolor/edgecolor/dpi during rendering, then restores originals via unwind-protect. This matches matplotlib's ExitStack pattern.

4. **draw-figure-background guards on renderer type**: The background drawing uses `mpl.backends:draw-path` which only works with `renderer-base` subclasses. Added a `typep` check so mock-renderer tests work without error.

5. **Format detection**: Simple extension-based detection (`.png` → :png, `.pdf` → :pdf, etc.). Only PNG is actually implemented; other formats warn and fall back to PNG.

6. **Layout engine protocol**: Three generics (execute, set, get) on a base class. PlaceHolder is a true no-op. TightLayout is simplified (no actual Axes layout computation yet since Axes don't exist).

### Gotchas Encountered

1. **FiveAM `(is t)` is INVALID**: Must use `(is (eq t t))` or `(pass)`. FiveAM's `is` macro requires a list form, not a bare value.

2. **Single-to-double float coercion precision**: `(coerce 0.15 'double-float)` produces `0.15000000596046448d0`, not `0.15d0`. Tests must use `0.15d0` literals when comparing with coerced values.

3. **Rendering vs Backends generic function split**: `mpl.rendering:renderer-draw-path` and `mpl.backends:draw-path` are DIFFERENT generic functions. Line2D uses the rendering protocol; the Vecto backend implements the backends protocol. This gap will need bridging when Axes pipeline connects artists to backends.

4. **Named class `mpl-figure` instead of `figure`**: Avoided naming the class `figure` to prevent conflicts with the CL symbol and with the pyplot `figure` function. Using `mpl-figure` is more explicit.

### Stats
- 129/129 tests passing (100%)
- Files: layout-engine.lisp, figure.lisp, test-figure.lisp
- Classes: layout-engine, placeholder-layout-engine, tight-layout-engine, mpl-figure, sub-figure
- All prior phases still green: backends 52/52, rendering 119/119, fonts 84/84

## Phase 4b — Axes with plot, scatter, bar (2026-02-06)

### Implementation Summary
- **axes-base.lisp**: AxesBase class with coordinate transforms (transData, transAxes, transScale), data limit tracking, autoscaling, artist management, z-order draw
- **axes.lisp**: Axes (mpl-axes) with plot(), scatter(), bar(), axes-fill(), fill-between(), add-subplot()
- **test-axes.lisp**: 45 tests, 116 checks, 100% pass rate
- **Combined: 245/245 checks passing** (129 figure + 116 axes)
- **Evidence: phase4b-mvp-plot.png (10KB), phase4b-scatter.png (13.7KB)**

### Architecture Decisions

1. **AxesBase ← Artist**: Single inheritance. AxesBase manages own artist lists (lines, patches, artists, texts, images) and draws them in z-order.

2. **Coordinate Transform Pipeline**: transData = viewLim→unitBbox ∘ transAxes. transAxes maps (0,1) → display pixels based on axes position in figure. transData maps data coords → display pixels via view limits.

3. **BboxTransform for viewLim→unit**: Used existing make-bbox-transform from transforms.lisp. Composes with transAxes for full data→display mapping.

4. **add-subplot position calculation**: Computes grid cell position from figure subplot params (left/right/top/bottom) with wspace/hspace gaps. Row 0 = top (matches matplotlib).

5. **Scatter as circles**: Each scatter point is a circle patch with radius from marker size. Simple but correct approach matching matplotlib's marker-per-point model.

6. **bar alignment**: Default :center alignment shifts x by -width/2. Data limits computed from bar extents (x0, x0+w) not just x positions.

7. **fill-between as polygon**: Forward pass along y2 curve, backward pass along y1 curve creates closed polygon. Clean simple approach.

8. **Bridge method for renderer protocol**: Added renderer-draw-path method on renderer-vecto to bridge artist draw protocol (keyword :fill/:stroke) to backend draw-path (positional rgbface).

### Gotchas Encountered

1. **CL:FILL name collision**: `fill` is a CL standard function. Defining `fill` as our plotting function in the containers package triggers `SYMBOL-PACKAGE-LOCKED-ERROR`. Solution: rename to `axes-fill`.

2. **to-rgba returns vector not multiple-values**: `(mpl.colors:to-rgba "C0")` returns `#(0.12 0.46 0.70 1.0)` (a vector), NOT multiple values. Using `multiple-value-list` wraps it as `(#(...))` — a list of ONE element. This causes `(fourth edge-color)` to be NIL, crashing with `(* NIL 1.0)`. Fix: unpack vector to flat list in `%resolve-color`.

3. **Artist draw protocol vs backend draw-path mismatch**: Line2D/Patch call `renderer-draw-path` (generic from artist.lisp) with `:fill/:stroke` keywords. Backend has `draw-path` (different generic from backends package) with positional `rgbface`. Need bridge method on renderer-vecto to translate between them.

4. **Autoscale zero-range handling**: When all data has same value (e.g., single point), x-range or y-range is 0. Must handle by expanding to ±0.5 (for zero) or ±5% of abs value. Otherwise BboxTransform divides by zero.

### Files Created/Modified
- `src/containers/axes-base.lisp` — ~300 LOC, AxesBase class
- `src/containers/axes.lisp` — ~280 LOC, Axes with plot methods
- `tests/test-axes.lisp` — ~530 LOC, 45 tests
- `src/packages.lisp` — Added 30+ exports for axes symbols
- `cl-matplotlib-containers.asd` — Added axes-base, axes components
- `src/backends/backend-vecto.lisp` — Fixed %resolve-color, added bridge method

## Phase 4c — Axis, Ticker, Spines (2026-02-06)

### Implementation Summary
- **ticker.lisp**: 7 locators (NullLocator, FixedLocator, LinearLocator, MultipleLocator, MaxNLocator, AutoLocator, LogLocator) + 6 formatters (NullFormatter, FixedFormatter, ScalarFormatter, StrMethodFormatter, LogFormatter, PercentFormatter)
- **spines.lisp**: Spine class (line-based, inherits from Patch), Spines container (hash-table dict)
- **axis.lisp**: Tick class, axis-obj base, XAxis, YAxis with tick mark/label/grid rendering
- **Integration**: AxesBase gets xaxis/yaxis/spines slots, draw method renders all three
- **Bridge**: renderer-draw-text bridge method added to backend-vecto
- **111 new tests, 356 total checks, 100% pass rate**
- **Evidence**: phase4c-ticks-labels.png (640x480, 17KB PNG)

### Architecture Decisions

1. **tick-formatter not formatter**: CL's `cl:formatter` macro conflicts with a class named `formatter`. Renamed to `tick-formatter` with accessors `tick-formatter-call`, `tick-formatter-format-ticks`, etc. Same pattern as matplotlib's `Formatter` but with namespace prefix.

2. **MaxNLocator's _raw_ticks algorithm**: Ported the extended staircase approach from matplotlib. Steps array (1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10) is extended with 0.1× and 10× factors. The algorithm walks backward through steps to find the smallest that provides enough ticks.

3. **scale_range helper**: Key utility from matplotlib.ticker that computes scale (order of magnitude of step) and offset (for large-value ranges). Pure arithmetic port.

4. **Spine as Patch subclass**: Each spine is a 2-vertex path (line segment) in axes coordinates (0-1). Four spines per axes (left, right, top, bottom). Drawn using axes-base-trans-axes transform.

5. **XAxis/YAxis draw methods**: Transform tick locations from data→display coords, then draw tick marks as 2-vertex paths, labels via renderer-draw-text, and gridlines as full-span paths.

6. **AxesBase integration**: The draw method was updated to: background → artists → xaxis → yaxis → spines. Spines replace the old %draw-axes-frame for border rendering.

7. **renderer-draw-text bridge**: Added `mpl.rendering:renderer-draw-text` method on `renderer-vecto` to bridge the artist draw protocol to the backend `draw-text` method. Similar to the existing draw-path bridge.

### Gotchas Encountered

1. **cl:formatter package lock**: SBCL locks the CL package. Defining a class named `formatter` in a package that `(:use #:cl)` triggers `SYMBOL-PACKAGE-LOCKED-ERROR`. Solution: rename to `tick-formatter`.

2. **CL ~,0F format**: `(format nil "~,0F" 42.0d0)` produces `"42."` (with trailing dot), not `"42"`. Tests must accept this or use custom formatting.

3. **Multiline --eval with quotes**: SBCL's `--eval` with multiline strings containing `'(...)` can fail to parse. Use `--load /dev/stdin` with heredoc instead for complex eval scenarios.

4. **renderer-draw-text bridge missing**: The axis draw code calls `mpl.rendering:renderer-draw-text` but `renderer-vecto` only had `mpl.backends:draw-text`. Had to add a bridge method (same pattern as the draw-path bridge from Phase 4b).

### Files Created/Modified
- `src/containers/ticker.lisp` — ~400 LOC, 7 locators + 6 formatters + helpers
- `src/containers/spines.lisp` — ~170 LOC, Spine class + Spines container
- `src/containers/axis.lisp` — ~420 LOC, Tick, XAxis, YAxis + drawing
- `src/containers/axes-base.lisp` — Modified: added xaxis/yaxis/spines slots, updated draw
- `src/containers/axes.lisp` — Modified: added axes-grid-toggle function
- `src/packages.lisp` — Added 70+ new exports for axis/ticker/spine symbols
- `src/backends/backend-vecto.lisp` — Added renderer-draw-text bridge method
- `cl-matplotlib-containers.asd` — Added ticker, spines, axis components + test-axis
- `tests/test-axis.lisp` — ~330 LOC, 42 tests, 111 checks
- `.sisyphus/evidence/phase4c-ticks-labels.png` — 640x480 PNG evidence

### Stats
- 356/356 checks passing (129 figure + 116 axes + 111 axis) — 100%
- Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-containers)' --quit` exits 0
