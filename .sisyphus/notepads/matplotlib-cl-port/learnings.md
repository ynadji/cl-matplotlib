
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

## Phase 4d — Legend, Colorbar, Legend Handlers (2026-02-06)

### Implementation Summary
- **legend-handler.lisp**: 4 core handler classes (HandlerLine2D, HandlerPatch, HandlerLineCollection, HandlerPathCollection) with `create-legend-artists` generic + default handler map
- **legend.lisp**: mpl-legend class inheriting from Artist, 10 position keywords, auto-placement algorithm ("best"), `axes-legend` convenience function, frame rendering, entry building from handles+labels
- **colorbar.lisp**: mpl-colorbar class, auto-creates colorbar axes, color gradient rendering via ScalarMappable, auto tick generation, tick+label drawing, border and label
- **Integration**: `axes-base-legend` slot added to AxesBase, draw method updated to draw legend on top
- **137 new checks (110 legend + 27 colorbar), 493 total, 100% pass rate**
- **Evidence**: phase4d-legend.png (640x480, 16KB PNG)

### Architecture Decisions

1. **Handler dispatch via typep**: Instead of using `closer-mop:class-precedence-list` (would add a dependency), handler lookup walks the handler map with `typep` for type matching. Falls back to `handler-patch` for any `patch` subclass and `handler-line-2d` for any `line-2d` subclass.

2. **Legend as Artist subclass**: mpl-legend inherits from Artist, gets zorder=5 (above all data artists). Drawn last in axes draw cycle via explicit check after spines.

3. **Legend auto-labels skip underscore**: Following matplotlib convention, `%axes-get-legend-handles-labels` skips artists whose label starts with `_`. This allows internal artists (like background patch) to be labeled without appearing in legends.

4. **Position computation in display coords**: Legend bbox computed in display pixels by transforming axes-fraction positions through transAxes. The x/y fractions (0.05-0.95) determine anchor points; legend is positioned so it doesn't overflow at edges.

5. **"Best" placement via overlap minimization**: Tests all 9 fixed positions, computes bounding-box overlap with data artists (lines), picks position with minimum overlap. Simple but effective for most cases.

6. **Colorbar creates its own axes**: `%make-colorbar-axes` shrinks the parent axes and inserts a narrow axes for the colorbar. Vertical: to the right; horizontal: below. This matches matplotlib's `make_axes` approach.

7. **Fontsize via gc-linewidth**: The Vecto backend uses `gc-linewidth` as fontsize for `draw-text` (a design decision from Phase 3b). Legend and colorbar text drawing must pass fontsize through linewidth in the graphics context, not as a separate parameter.

### Gotchas Encountered

1. **`push` reverses order**: `axes-base-lines` stores lines via `push`, so the most recently added line is first. When iterating for legend labels, `nreverse` is needed — but the resulting order depends on the traversal order of `push`-accumulated lists. Tests should check membership, not exact order.

2. **Backend draw-text signature**: `draw-text(renderer gc x y s prop angle)` — no `:fontsize` keyword. Fontsize comes from `gc-linewidth` (a Vecto renderer convention). Calling `draw-text` with keyword args causes errors.

3. **`closer-mop` not in dependencies**: Can't use `class-precedence-list` for handler dispatch without adding the dependency. Used `typep`-based matching instead, which is simpler and sufficient for the 5 types we handle.

4. **Colorbar axes frameon**: Must pass `:frameon nil` when creating colorbar axes to avoid drawing a background rectangle that covers the gradient.

### Files Created/Modified
- `src/containers/legend-handler.lisp` — ~170 LOC, 4 handler classes + dispatch
- `src/containers/legend.lisp` — ~380 LOC, Legend class + positioning + drawing + axes-legend
- `src/containers/colorbar.lisp` — ~280 LOC, Colorbar class + gradient + ticks + label
- `src/containers/axes-base.lisp` — Modified: added axes-legend slot + draw legend in draw method
- `src/packages.lisp` — Added ~40 new exports for legend/colorbar/handler symbols
- `cl-matplotlib-containers.asd` — Added 3 components + 2 test files
- `tests/test-legend.lisp` — ~380 LOC, 42 tests, 110 checks
- `tests/test-colorbar.lisp` — ~190 LOC, 15 tests, 27 checks
- `.sisyphus/evidence/phase4d-legend.png` — 640x480 PNG evidence

### Stats
- 493/493 checks passing (129 figure + 116 axes + 111 axis + 110 legend + 27 colorbar) — 100%
- Pre-commit: `sbcl --eval '(asdf:test-system :cl-matplotlib-containers)' --quit` exits 0

## Phase 5a — Scale System (2026-02-06)

### Implementation Summary
- **scale-transforms.lisp**: 5 transform classes (LogTransform, InvertedLogTransform, SymLogTransform, LogitTransform, LogisticTransform, FuncTransform)
- **scale.lisp**: 5 scale classes (LinearScale, LogScale, SymLogScale, LogitScale, FuncScale) + ScaleBase + factory
- **axis.lisp**: Added axis-scale slot + axis-set-scale method
- **axes-base.lisp**: Added axes-set-xscale + axes-set-yscale methods
- **59 new tests, 552 total checks, 100% pass rate**
- **Evidence**: phase5a-log-scale.png (640x480, 9.6KB PNG)

### Architecture Decisions

1. **Transform-only approach**: Scale transforms only transform the X coordinate, leaving Y unchanged. This matches matplotlib's 1D transform model where each axis has its own scale.

2. **Scale as CLOS class with transform slot**: Each scale class stores a transform instance in a slot (e.g., `log-scale-transform`). The `scale-get-transform` generic returns this cached transform.

3. **Scale sets locators/formatters**: The `scale-set-default-locators-and-formatters` generic allows each scale to configure appropriate tick placement. LogScale sets LogLocator + LogFormatter, LinearScale sets AutoLocator + ScalarFormatter.

4. **Axis owns scale**: Added `axis-scale` slot to `axis-obj`. The `axis-set-scale` function sets the scale and calls `scale-set-default-locators-and-formatters` to update ticks.

5. **Axes convenience methods**: `axes-set-xscale` and `axes-set-yscale` create scale instances via `make-scale` factory and call `axis-set-scale` on the appropriate axis.

6. **Factory pattern**: `make-scale` takes a keyword (`:linear`, `:log`, `:symlog`, `:logit`, `:function`) and additional args, returning the appropriate scale instance.

7. **Limit range protocol**: `scale-limit-range-for-scale` generic allows scales to constrain data limits. LogScale replaces non-positive values with minpos (1e-300 fallback). LogitScale clamps to (0, 1).

### Gotchas Encountered

1. **Transform point signature**: Scale transforms must implement `transform-point` taking a 2-element point and returning a 2-element array. The Y coordinate passes through unchanged for 1D scales.

2. **Nonpositive handling**: LogTransform supports both `:clip` (replace with -1000) and `:mask` (replace with NaN) for non-positive values. Clipping is the default to avoid breaking rendering.

3. **SymLog complexity**: SymmetricalLogTransform has a piecewise definition: linear within `[-linthresh, linthresh]`, logarithmic outside. The `linscale` parameter controls the relative width of the linear region.

4. **Logit domain**: LogitTransform is only valid for (0, 1). Values outside this range are clipped or masked. The inverse (LogisticTransform) maps all reals to (0, 1).

5. **FuncScale validation**: FuncScale requires both forward and inverse functions. The constructor validates that both are callable before creating the FuncTransform.

6. **Scale initialization order**: Scales must be created AFTER the axis exists, since `scale-set-default-locators-and-formatters` needs to call `axis-set-major-locator` etc.

### Files Created/Modified
- `src/primitives/scale-transforms.lisp` — ~330 LOC, 6 transform classes
- `src/containers/scale.lisp` — ~230 LOC, 5 scale classes + factory
- `src/containers/axis.lisp` — Modified: added axis-scale slot + axis-set-scale
- `src/containers/axes-base.lisp` — Modified: added axes-set-xscale + axes-set-yscale
- `src/packages.lisp` — Added 30+ scale exports
- `cl-matplotlib-primitives.asd` — Added scale-transforms component
- `cl-matplotlib-containers.asd` — Added scale component + test-scale
- `tests/test-scale.lisp` — ~280 LOC, 26 tests, 59 checks
- `.sisyphus/evidence/phase5a-log-scale.png` — 640x480 PNG evidence

### Stats
- 552/552 checks passing (129 figure + 116 axes + 111 axis + 59 scale + 110 legend + 27 colorbar) — 100%
- Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-containers)' --quit` exits 0
- Evidence: `file .sisyphus/evidence/phase5a-log-scale.png` → "PNG image data, 640 x 480, 8-bit/color RGBA"


## Phase 5b — GridSpec System (2026-02-06)

### Implementation Summary
- **gridspec.lisp**: GridSpec, SubplotSpec, GridSpecFromSubplotSpec classes + subplots() + subplot-mosaic()
- **axes-base.lisp**: Added sharex/sharey slots, axes-share-x/axes-share-y functions, limit propagation with circular-update guard
- **158 new tests, 710 total checks, 100% pass rate**
- **Evidence**: phase5b-gridspec.png (640x480, 11.6KB PNG)

### Architecture Decisions

1. **gridspec-get-subplot-params as defgeneric**: Must be a generic function (not defun) because GridSpecFromSubplotSpec needs a specialized method. The gridspec class method merges overrides with figure/default params; the nested version computes params from parent SubplotSpec position.

2. **Grid position algorithm (port of matplotlib's get_grid_positions)**: Cumulative accumulation of cell heights/widths with separator gaps. Uses height-ratios and width-ratios to scale cell sizes proportionally. Row 0 = top (matplotlib convention preserved).

3. **Shared axes via guard flag**: `axes-base-%propagating-p` slot prevents circular updates. When ax1 shares with ax2, setting xlim on ax1 propagates to ax2 but ax2's guard flag prevents re-propagating back to ax1. Uses `unwind-protect` to always clear the flag.

4. **subplot-mosaic via hash-table parsing**: Iterates layout string array character by character, building a hash of name→cells. Then computes bounding rectangle for each name's cells and creates a spanning SubplotSpec. '.' character treated as empty space.

5. **subplots squeeze semantics**: Matches matplotlib exactly — 1×1 returns single axes, 1×N or N×1 returns 1D array, N×M returns 2D array. squeeze=nil forces 2D array always.

6. **Shared axes in subplots**: Normalized sharex/sharey values (:all, :row, :col, :none). For each cell, identifies the share-target based on mode: :all→(0,0), :row→(row,0), :col→(0,col). Skips self-sharing.

### Gotchas Encountered

1. **defun → defgeneric conflict**: Defining `gridspec-get-subplot-params` as a regular function first, then trying to specialize it with `defmethod` for `gridspec-from-subplot-spec`, causes "already names an ordinary function" error. Must define as `defgeneric` from the start.

2. **copy-list for figure-subplot-params**: When using figure's subplot params as defaults, must `copy-list` to avoid mutating the figure's actual params when applying GridSpec overrides via `setf getf`.

3. **Limit propagation in autoscale**: `axes-autoscale-view` also needs to propagate shared limits, not just `axes-set-xlim/axes-set-ylim`. Added `%propagate-xlim/%propagate-ylim` calls at end of autoscale.

4. **Row-major indexing**: SubplotSpec uses flat row-major indices (num1, num2). Converting (row, col) to flat index: `num = row * ncols + col`. Converting back: `row = floor(num / ncols)`, `col = num mod ncols`.

### Files Created/Modified
- `src/containers/gridspec.lisp` — ~350 LOC, GridSpec + SubplotSpec + subplots + subplot-mosaic
- `src/containers/axes-base.lisp` — Modified: +3 slots (sharex-group, sharey-group, %propagating-p), +6 functions (axes-share-x, axes-share-y, %propagate-xlim, %propagate-ylim), modified axes-set-xlim/axes-set-ylim/axes-autoscale-view for propagation
- `src/packages.lisp` — Added ~30 gridspec/shared-axes exports
- `cl-matplotlib-containers.asd` — Added gridspec component + test-gridspec
- `tests/test-gridspec.lisp` — ~450 LOC, 49 tests, 158 checks

### Stats
- 710/710 checks passing (129 figure + 116 axes + 111 axis + 59 scale + 110 legend + 27 colorbar + 158 gridspec) — 100%
- Pre-commit: `sbcl --eval '(asdf:test-system :cl-matplotlib-containers)' --quit` exits 0
- Evidence: `file .sisyphus/evidence/phase5b-gridspec.png` → "PNG image data, 640 x 480, 8-bit/color RGBA"

## Phase 5c — Collection Classes and Hatch Patterns (2026-02-06)

### Implementation Summary
- **hatch.lisp**: 10 hatch patterns (/, \, |, -, +, x, o, O, ., *) with density control. Generates mpl-paths tiling a unit square.
- **collections.lisp**: Collection base class + 5 types (LineCollection, PathCollection, PatchCollection, PolyCollection, QuadMesh). Each type has specialized `collection-get-paths` and custom `draw` methods.
- **backend-vecto.lisp**: Added `draw-path-collection` method for batch rendering with per-item colors/transforms.
- **axes.lisp**: Updated `scatter()` to use PathCollection instead of individual Circle patches.
- **122 new tests (collection tests), 325 rendering total, 711 container total, all passing 100%**
- **Evidence**: phase5c-collections.png (640x480, 9.2KB PNG, 1000-point scatter)

### Architecture Decisions

1. **Collection inherits from Artist (not Patch)**: Collections are a sibling to Patch, not a subclass. They share the draw protocol but handle multiple items rather than a single shape. This matches matplotlib's hierarchy.

2. **Cyclic property access via %coll-nth**: Properties (colors, linewidths, etc.) are accessed cyclically using `(mod index (length list))`. This matches matplotlib's `prop[i % len(prop)]` pattern.

3. **Specialized draw methods per collection type**: LineCollection, PolyCollection, and QuadMesh override the base `draw` method because their drawing semantics differ:
   - LineCollection: each segment is its own path, no offsets needed
   - PolyCollection: each polygon is its own path, no offsets needed  
   - QuadMesh: quads generated from coordinate grid, per-quad colors
   - PathCollection/base Collection: paths + offsets + per-item transforms

4. **scatter() returns PathCollection**: Changed from returning a list of Circle patches to returning a single PathCollection. This is more efficient and matches matplotlib's actual implementation. Required updating 2 existing tests.

5. **Hatch as functional generation**: Each hatch type (horizontal, vertical, diagonal, shapes) is a standalone function that returns (values vertices codes n-vertices). The main `hatch-get-path` merges all patterns into a single mpl-path. This avoids the class-based approach of matplotlib which is unnecessary without numpy array slicing.

6. **draw-path-collection on backend**: Added as a generic function on renderer-base with a default fallback implementation, plus an optimized Vecto-specific method that minimizes state changes.

### Gotchas Encountered

1. **scatter() return type change breaks tests**: The old scatter() returned `(nreverse artists)` — a list of circles. Changing to PathCollection broke 2 tests that called `(length artists)`. Fixed by updating tests to check `typep` and PathCollection properties instead.

2. **PathCollection needs trans-offset not transform**: When scatter creates a PathCollection, the offsets are in data coordinates. These need to be transformed through `transData` (via `trans-offset` slot), NOT through the artist's main transform. The main transform stays nil; offset transform does the data→display mapping.

3. **QuadMesh coordinates are (H+1, W+1, 2)**: For a mesh of W×H quads, you need (H+1)×(W+1) corner points. Each quad uses 4 corners: (i,j), (i,j+1), (i+1,j+1), (i+1,j).

4. **Hatch circle approximation**: Used 16-segment polygon approximation for circles instead of Bézier curves. Simpler and sufficient for hatch fill patterns where exact smoothness isn't critical.

### Files Created/Modified
- `src/rendering/hatch.lisp` — ~240 LOC, 10 hatch pattern types + generator
- `src/rendering/collections.lisp` — ~430 LOC, Collection base + 5 types + constructors
- `tests/test-collections.lisp` — ~350 LOC, 47 tests, 122 checks
- `src/packages.lisp` — Added ~35 collection/hatch exports
- `cl-matplotlib-rendering.asd` — Added hatch, collections components + test
- `src/backends/renderer-base.lisp` — Added draw-path-collection generic + default
- `src/backends/backend-vecto.lisp` — Added draw-path-collection Vecto implementation
- `src/containers/axes.lisp` — Updated scatter() to use PathCollection
- `tests/test-axes.lisp` — Updated 2 scatter tests for new return type
- `.sisyphus/evidence/phase5c-collections.png` — 1000-point scatter evidence

### Stats
- Rendering: 325/325 checks (119 artist + 84 font + 122 collections) — 100%
- Containers: 711/711 checks (129 figure + 117 axes + 111 axis + 59 scale + 110 legend + 27 colorbar + 158 gridspec) — 100%
- Total: 1036 checks passing, 100% pass rate

## Phase 5d — Contour Plotting with Marching Squares (2026-02-06)

### Implementation Summary
- **marching-squares.lisp**: Pure CL marching squares algorithm (~250 LOC). 16-case lookup table, linear interpolation, saddle point disambiguation (center value), segment connectivity via greedy path building.
- **contour.lisp**: ContourSet and QuadContourSet classes (~300 LOC). ContourSet inherits from Artist, manages per-level collections. QuadContourSet auto-builds LineCollection (contour) or PolyCollection (contourf) from marching squares output.
- **contour/contourf/clabel**: Three main API functions added to containers package. Auto level selection, cmap+norm color mapping, alpha support.
- **130 new tests, 841 total checks, 100% pass rate**
- **Evidence**: phase5d-contour.png (640x480, 9.2KB PNG, filled Gaussian contours)

### Architecture Decisions

1. **Marching squares in containers package**: Rather than creating a separate `cl-matplotlib-algorithms` system, the marching-squares functions live in the containers package since they're only used by contour plotting. This avoids another system dependency.

2. **Module-based .asd structure**: Changed from flat `:pathname "src/containers/"` to module-based structure with three modules (`src/containers`, `src/algorithms`, `src/plotting`). This allows the single `cl-matplotlib-containers` system to span multiple directories while keeping `:serial t` for load ordering.

3. **Filled contours via cell-clipping**: Rather than the more complex approach of tracing boundary contours and forming closed regions, used a per-cell band-clipping algorithm. For each grid cell, walk the boundary and include corners in-band plus interpolated edge crossings. Simpler, O(N*M) per level pair.

4. **Segment connectivity via greedy extension**: Raw marching squares produces disconnected line segments. Connected them by repeatedly scanning unmatched segments for endpoint matches (within tolerance). Each pass extends the current path in both directions. Produces clean polylines from raw segments.

5. **Saddle disambiguation by center value**: Cases 5 and 10 (diagonal saddle points) are resolved using the average of the 4 corner values. If center >= level, use alternative connection. This matches the standard approach.

6. **ContourSet as Artist**: Follows matplotlib's pattern — ContourSet is an Artist that owns per-level collections. The draw method delegates to each collection's draw. This integrates cleanly with the existing axes draw pipeline.

7. **Auto-level selection**: Simple even spacing between zmin and zmax. For contour lines: N levels interior to the range. For contourf: N+1 boundary levels spanning the full range. Could be enhanced with MaxNLocator but kept simple for correctness.

### Gotchas Encountered

1. **Module path in ASDF**: When using `:module` directive, the component files are relative to the module's path. `(:module "src/algorithms" :components ((:file "marching-squares")))` looks for `src/algorithms/marching-squares.lisp`.

2. **PolyCollection vs LineCollection for filled contours**: contour() uses LineCollection (segments), contourf() uses PolyCollection (filled polygons). The key difference is facecolors — LineCollection has nil facecolors by default, PolyCollection fills them.

3. **clabel position via path midpoint**: Simple but effective — find the longest contour path for each level and place the label at its midpoint. Full inline labeling (breaking the contour line) is deferred as optional enhancement.

4. **Z array indexing**: CL arrays are row-major. `(aref z j i)` where j=row=Y, i=col=X. This matches matplotlib's convention but requires care when iterating.

### Files Created/Modified
- `src/algorithms/marching-squares.lisp` — ~250 LOC, marching squares + filled + auto levels
- `src/plotting/contour.lisp` — ~300 LOC, ContourSet + QuadContourSet + contour/contourf/clabel
- `tests/test-contour.lisp` — ~470 LOC, 45 tests, 130 checks
- `src/packages.lisp` — Added ~20 contour exports
- `cl-matplotlib-containers.asd` — Changed to module structure, added algorithms+plotting+test-contour

### Stats
- 841/841 checks passing (129 figure + 117 axes + 111 axis + 59 scale + 110 legend + 27 colorbar + 158 gridspec + 130 contour) — 100%
- Pre-commit: `sbcl --eval '(asdf:test-system :cl-matplotlib-containers)' --quit` exits 0
- Evidence: `file .sisyphus/evidence/phase5d-contour.png` → "PNG image data, 640 x 480, 8-bit/color RGBA"


## Phase 5e — Image Display (imshow) with Interpolation (2026-02-06)

### Implementation Summary
- **image.lisp (rendering)**: Extended AxesImage class with interpolation algorithms (nearest-neighbor, bilinear), data→RGBA conversion pipeline, origin handling, aspect ratio support, and proper draw method with backend integration
- **image.lisp (plotting)**: imshow() function creating AxesImage with colormap, normalization, extent, origin, and aspect parameters. axes-add-image() for artist management
- **backend-vecto.lisp**: Added renderer-draw-image bridge method (mpl.rendering → mpl.backends)
- **158 new checks, 999 total, 100% pass rate**
- **Evidence**: phase5e-imshow.png (640x480, RGBA PNG, 100×100 random array with viridis colormap)

### Architecture Decisions

1. **Two-file split**: Rendering logic (AxesImage class, interpolation, data→RGBA) lives in `src/rendering/image.lisp`. Plotting API (imshow function) lives in `src/plotting/image.lisp`. This follows the contour pattern.

2. **Interpolation target size cap**: Capped interpolation target dimensions at 2048×2048 pixels to prevent heap exhaustion. Without this, a 100×100 image with extent 0-100 in data coords gets transformed to ~50,000 pixels in display coords through the data→display transform pipeline.

3. **Data→RGBA pipeline**: 2D scalar data flows through `normalize-call → colormap-call → RGBA`. 3D data (RGB/RGBA) auto-detects 0-255 vs 0-1 range. All intermediate processing uses double-float arrays; final conversion to (unsigned-byte 8) flat array for backend blitting.

4. **Origin handling via flip**: `:upper` origin (matplotlib default, row 0 at top) implemented by vertically flipping the RGBA array after colormap application but before interpolation. `:lower` passes through unchanged.

5. **Bridge method pattern**: Added `renderer-draw-image` method on `renderer-vecto` to bridge from artist protocol (`mpl.rendering:renderer-draw-image`) to backend protocol (`mpl.backends:draw-image`). Same pattern as draw-path and draw-text bridges from Phase 4b/4c.

6. **Extent default**: When extent is nil, defaults to `(0 W 0 H)` where W=cols, H=rows. This maps each data pixel to one unit in data coordinates.

### Gotchas Encountered

1. **Heap exhaustion on large interpolation**: A 100×100 image at extent (0,100,0,100) with transData mapping data→display coordinates results in target dimensions of ~50K×37K pixels — requiring ~55 GB for the RGBA array. Solution: cap target dimensions at 2048×2048.

2. **renderer-draw-image bridge missing**: The existing AxesImage draw method called `renderer-draw-image` from the artist protocol, but no method was defined on `renderer-vecto` to bridge to the backend's `draw-image`. Had to add the bridge (same pattern as Phase 4b's draw-path bridge).

3. **Colormap auto-detection**: When cmap is nil, must resolve to the viridis colormap instance via `get-colormap`. When it's a keyword, must look it up. When it's already a colormap instance, use as-is. Three cases in the cond.

4. **Normalize auto-detection for vmin/vmax**: When norm is nil, create a new Normalize instance and scan the 2D data array for min/max values. Must check both image-vmin/vmax (explicit) and data-derived values.

### Files Created/Modified
- `src/rendering/image.lisp` — ~400 LOC, AxesImage class + interpolation + data→RGBA + draw (extended from ~110 LOC)
- `src/plotting/image.lisp` — ~100 LOC, imshow() + axes-add-image()
- `tests/test-image.lisp` — ~370 LOC, 42 tests, 158 checks
- `src/packages.lisp` — Added ~8 new exports (interpolation functions, image-aspect, imshow, axes-add-image)
- `cl-matplotlib-containers.asd` — Added image component + test-image
- `src/backends/backend-vecto.lisp` — Added renderer-draw-image bridge method

### Stats
- 999/999 checks passing (129 figure + 117 axes + 111 axis + 59 scale + 110 legend + 27 colorbar + 158 gridspec + 130 contour + 158 image) — 100%
- Pre-commit: `sbcl --eval '(asdf:test-system :cl-matplotlib-containers)' --quit` exits 0
- Evidence: `file .sisyphus/evidence/phase5e-imshow.png` → "PNG image data, 640 x 480, 8-bit/color RGBA"

## Phase 6b — Additional Plot Types (2026-02-06)

### Implementation Summary
- **hist.lisp**: Histogram with binning, density normalization, cumulative mode, 3 histtypes (:bar, :step, :stepfilled)
- **stats.lisp**: Simplified boxplot with quartiles, IQR whiskers, outlier detection, vertical/horizontal orientation
- **axes.lisp**: Added 6 more plot types: pie, errorbar, stem, axes-step, stackplot, barh
- **109 new tests, 1108 total checks, 100% pass rate**
- **Evidence**: phase6b-hist.png (800x600, 16.7KB PNG, 1000-point histogram with 30 bins)

### Architecture Decisions

1. **Histogram binning as standalone functions**: `%compute-bin-edges` and `%histogram-counts` are utility functions, not methods. Linear search for bin assignment (correct for small bin counts). Density normalization divides by total*bin_width so sum of areas = 1.0.

2. **Three histtypes via ecase**: `:bar` creates N Rectangle patches. `:step` creates a single Line2D with the step outline. `:stepfilled` creates a single Polygon with the filled step outline. Each returns different artist types but the same (values counts bin-edges patches).

3. **Pie chart with Wedge patches**: Normalizes input to fractions, converts to angular sweeps (360°). Each slice is a Wedge patch with center=(0,0), radius=1. Label positions computed from midpoint angles.

4. **Errorbar delegates to plot() for main line**: Creates the main data line via existing `plot()`, then adds LineCollections for error bar segments and caps. Returns (values line err-lc cap-lc).

5. **Stem uses LineCollection for stems**: Vertical stem lines stored as a LineCollection for efficiency. Marker heads as a Line2D with linewidth=0 and marker=:circle. Baseline as a separate Line2D.

6. **Step plot builds explicit path**: Three modes (:pre, :post, :mid) construct different vertex sequences. Returns a single Line2D with the pre-computed step path.

7. **Stackplot via cumulative sums**: Uses a 2D array for cumulative layer boundaries. Each layer is a Polygon formed by forward pass (upper boundary) and backward pass (lower boundary). Clean closed polygon.

8. **Barh mirrors bar() with x/y swapped**: Rectangle patches with x0=left, y0=y-height/2, width=horizontal extent, height=bar thickness.

9. **Boxplot with IQR-based whiskers**: Q1/median/Q3 via linear interpolation percentile. Whiskers extend to most extreme data within 1.5×IQR. Points beyond whiskers are outliers (rendered as markers).

### Gotchas Encountered

1. **`step` name collision**: CL's `step` is a debugging macro. Named our function `axes-step` to avoid the package conflict (same pattern as `axes-fill` from Phase 4b).

2. **line-2d-ydata returns whatever was passed**: Line2D stores xdata/ydata as-is (list or vector). Tests must use `elt` not `first` to access elements generically.

3. **Density normalization returns heights not counts**: The `hist` function returns raw counts in the first value but uses normalized heights for the rectangles. Tests checking density must read patch heights, not the counts return value.

4. **Step :mid point count**: For n=4 input points, :mid generates 1+2*(n-1)+1=8 step path points (first + midpoint pairs + last), not 2*(n-1)+1=7.

5. **Boxplot single vs multiple datasets**: Boxplot must handle both a single dataset (list of numbers) and multiple datasets (list of lists). Detection via `(listp (first data))`.

### Files Created/Modified
- `src/plotting/hist.lisp` — ~175 LOC, histogram binning + plotting
- `src/plotting/stats.lisp` — ~200 LOC, boxplot with quartiles + whiskers + outliers
- `src/containers/axes.lisp` — +350 LOC, 6 plot types (pie, errorbar, stem, axes-step, stackplot, barh)
- `tests/test-plot-types.lisp` — ~370 LOC, 39 tests, 109 checks
- `src/packages.lisp` — Added 8 new exports (hist, pie, errorbar, stem, axes-step, stackplot, barh, boxplot)
- `cl-matplotlib-containers.asd` — Added hist + stats components + test-plot-types

### Stats
- 1108/1108 checks passing (129 figure + 117 axes + 111 axis + 59 scale + 110 legend + 27 colorbar + 158 gridspec + 130 contour + 158 image + 109 plot-types) — 100%
- Evidence: `file .sisyphus/evidence/phase6b-hist.png` → "PNG image data, 800 x 600, 8-bit/color RGBA"

## Phase 6c — Annotation System (2026-02-06)

### Implementation Summary
- **fancy-arrow.lisp**: FancyArrowPatch class (inherits Patch), 3 ConnectionStyle classes (Arc3, Angle3, Angle), 5 BoxStyle classes (Square, Round, Round4, Sawtooth, Roundtooth), AnchoredText class, 9 arrow styles, arrow path generation algorithms
- **annotation.lisp**: Annotation class (inherits Text), arrow creation from arrowprops, bbox text box support, position/target update methods
- **axes.lisp**: `annotate` function added to containers package
- **127 new tests, 1235 total checks across all systems, 100% pass rate**
- **Evidence**: phase6c-annotation.png (800x600, 17.6KB PNG, plot with red arrow annotation)

### Architecture Decisions

1. **Annotation inherits from text-artist**: Clean subclass that adds xy (target), xytext (text position), arrowprops, and bbox. The text-artist parent handles text rendering; Annotation adds arrow drawing before text.

2. **FancyArrowPatch inherits from Patch**: Gets edge/face color, linewidth, etc. for free. Overrides `draw` and `get-path`. Default capstyle/joinstyle set to :round (matching matplotlib).

3. **Arrow path computation as standalone function**: `%compute-arrow-path` takes positions, style, and parameters and returns (values shaft-path head-path). The cond dispatch on style-key supports 9 styles. Clean separation from class logic.

4. **ConnectionStyle as generic function protocol**: `connect(style posA posB) → mpl-path`. Three implementations: Arc3 (quadratic Bézier via cubic approximation), Angle3 (3 segments via line intersection), Angle (2 segments at right angle).

5. **Arrow styles as keywords**: `:->`, `:<-`, `:<->`, `:-`, `:-bracket`, `:-bar-bar`, `:simple`, `:fancy`, `:wedge`. Avoided `:-[` and `:|` in CL because special characters in keyword symbols cause reader issues with `ecase`.

6. **cond instead of ecase for arrow styles**: After discovering that CL reader interprets `:-[` and `:|-|` problematically (pipe character starts escape sequences), switched from ecase to cond with eq/member tests. Clean arrow style names: `:->`, `:-bracket`, `:-bar-bar`.

7. **AnchoredText as Artist subclass**: Simple text box anchored to axes corners. 9 location keywords. frameon controls border. zorder=5 (above data). Position computed as axes-fraction coordinates.

### Gotchas Encountered

1. **CL keyword symbol naming**: `:|-|` is parsed as the symbol `:-` by CL reader because `|` starts an escape sequence. `:-[` requires `:-\[` with escape. Using `ecase` with these produces "duplicate key" warnings. Solution: use descriptive keywords (`:->`, `:-bracket`, `:-bar-bar`) and `cond` instead of `ecase`.

2. **Extra closing paren from ecase→cond migration**: When converting `ecase` (which has its own closing paren) to `cond` (which also closes with `)`), easy to leave an extra `)`. CL reader gives "unmatched close parenthesis" error with line number.

3. **declare ignore in inner scope**: `(declare (ignore connection-path))` inside an inner let/cond scope triggers a style warning "IGNORE declaration for a variable from outer scope". Must place declare at the correct scope level.

4. **Arrow head direction**: Arrow heads point in the direction the arrow is going. For `->` style, the head points from xytext toward xy (the annotated point). The direction vector is `(- posA posB)` for the B-end head.

### Files Created/Modified
- `src/rendering/fancy-arrow.lisp` — ~520 LOC, FancyArrowPatch + 3 ConnectionStyles + 5 BoxStyles + AnchoredText
- `src/rendering/annotation.lisp` — ~170 LOC, Annotation class + arrow creation + draw
- `src/containers/axes.lisp` — +55 LOC, annotate() function
- `tests/test-annotation.lisp` — ~420 LOC, 49 tests, 127 checks
- `src/packages.lisp` — Added ~40 annotation/arrow/connection/box exports
- `cl-matplotlib-rendering.asd` — Added fancy-arrow, annotation components + test

### Stats
- Rendering: 452/452 checks (119 artist + 84 font + 122 collections + 127 annotation) — 100%
- Containers: 1108/1108 checks (unchanged) — 100%
- Total: 1235 checks passing, 100% pass rate
- Evidence: `file .sisyphus/evidence/phase6c-annotation.png` → "PNG image data, 800 x 600, 8-bit/color RGBA"
