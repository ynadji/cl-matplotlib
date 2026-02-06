# Phase 0 Findings — cl-matplotlib Feasibility Validation
Date: 2026-02-06

## GATE DECISION: GO — Continue with Vecto

Vecto is significantly more capable than the Metis review indicated.
No pivot to custom cl-aa rasterizer is needed.

---

## Vecto Capability Assessment

### What Works Out-of-the-Box (No Extension Needed)
1. **Solid lines** — `stroke` with `set-line-width`, `set-rgb-stroke`
2. **Dashed lines** — `set-dash-pattern` already wraps cl-vectors `dash-path`
3. **Line caps** — `:round`, `:butt`, `:square` via `set-line-cap`
4. **Line joins** — `:miter`, `:round`, `:bevel` via `set-line-join`
5. **Filled polygons** — `fill-path` with `set-rgba-fill`
6. **Alpha transparency** — Full premultiplied alpha compositing
7. **Clipping** — `clip-path` and `even-odd-clip-path` with grayscale mask channel
8. **Text rendering** — `draw-string` via zpb-ttf glyph outlines through cl-aa
9. **Bezier curves** — `curve-to` (cubic), used internally for arcs/ellipses
10. **Ellipses/arcs** — `centered-ellipse-path`, `ellipse-arc`
11. **Transform matrices** — Full affine 2D transforms
12. **Gradient fills** — `set-gradient-fill` (linear/radial)
13. **Graphics state save/restore** — `with-graphics-state`
14. **Even-odd fill rule** — `even-odd-fill-path`

### What Needed Extension (Trivial)
1. **Image blitting** — Direct pixel buffer manipulation via `zpng:image-data`
   - Implemented as 25-line `blit-image-to-canvas` function
   - Alpha-over compositing in pure CL
   - Access internal state: `(zpng:image-data (vecto::image vecto::*graphics-state*))`
   - This is the ONLY "extension" needed

### What's Infeasible in Vecto
- Nothing blocking was found. All matplotlib rendering primitives map cleanly.

### Key Internal APIs to Use
- `vecto::*graphics-state*` — Access current state during `with-canvas`
- `vecto::image` — Get zpng image from state
- `zpng:image-data` — Flat RGBA byte array, row-major, 4 channels
- `vecto::draw-paths` — Low-level path drawing with custom draw-function
- `vecto::state-draw-function` — Create compositing draw function

---

## numcl Assessment

### Results: 18/20 (90%) pass
- **Working**: zeros, ones, arange, +, -, *, /, sum, reshape, transpose, concatenate, >, <, =, boolean masks
- **Failing**: linspace (API mismatch — different keyword args), sqrt (result type issue)
- **Missing from exports**: amin, amax, mean (must use reduce or sum/n)
- **Critical issue**: Requires `--dynamic-space-size 4096` on SBCL 2.2.9 (heap exhaustion during compilation at default 1GB)

### numcl Gaps for matplotlib
- No `where` with replacement (can implement with CL loop)
- `linspace` has different API than numpy (fixable with wrapper)
- sqrt returns integer type for integer input (need float coercion)
- Heavy compilation cost — 4GB heap for a numeric library is concerning
- **Recommendation**: Use numcl for core array ops, supplement with thin wrappers for missing ops. Consider falling back to plain CL arrays + loops for simple operations to avoid the 4GB heap requirement.

---

## trivial-garbage Assessment

### Results: 4/4 (100%) pass on SBCL 2.2.9
1. `make-weak-pointer` — Creates weak references correctly
2. `finalize` — Callbacks fire after GC
3. Weak pointer invalidation — Value becomes NIL after GC
4. `cancel-finalization` — Correctly prevents callback

### Notes
- All core features work on SBCL
- CCL not tested (not available in this environment) but trivial-garbage is well-tested across implementations
- Suitable for Figure/Axes resource cleanup

---

## Cross-Validation (SSIM)

### Result: 0.8241 (threshold 0.70 — PASS)
- Per-channel: R=0.7815, G=0.7667, B=0.7503, A=0.9978
- Alpha channel nearly perfect (0.9978) — compositing is correct
- Differences from: font rendering (zpb-ttf vs FreeType), anti-aliasing algo, coordinate mapping, axis decoration differences
- Both images: 640x480, PNG, all 6 elements visible

---

## Key Decisions Made

1. **Vecto is the rendering foundation** — No pivot needed
2. **Image blitting via direct buffer access** — Works cleanly, 25 LOC
3. **numcl as optional dependency** — Heavy compilation cost suggests making it opt-in; CL arrays sufficient for basic ops
4. **Font path**: `/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf` — LiberationSans available as matplotlib-compatible sans-serif

---

## Patterns & Conventions Discovered

1. Vecto Y=0 is top (like screen coords) — matches matplotlib's `flipy()=True`
2. Vecto uses cl-vectors+cl-aa for scanline rasterization — same family as AGG
3. Dash patterns are in user-space units (like PostScript)
4. Clipping uses a grayscale mask channel intersected with drawing alpha
5. `with-graphics-state` provides save/restore (like PDF `gsave`/`grestore`)
6. Text rendering through zpb-ttf produces glyph outlines → cl-aa paths
7. Image data is flat `(simple-array (unsigned-byte 8) (*))`, RGBA interleaved, row-major

---

## Evidence Files
- `.sisyphus/evidence/phase0-poc-render.png` — Full PoC (640x480, 31KB)
- `.sisyphus/evidence/phase0-dash-test.png` — Dash patterns (400x300, 12.5KB)
- `.sisyphus/evidence/phase0-ssim-report.txt` — SSIM = 0.8241
- `.sisyphus/evidence/phase0-numcl-validation.txt` — 18/20 pass
- `.sisyphus/evidence/phase0-weakref-test.txt` — 4/4 pass
- `.sisyphus/evidence/phase0-scope-document.md` — ~1396 functions classified

---

## Phase 1 Findings — Foundation Layer
Date: 2026-02-06

### Implementation Summary
- **265 rcParams** registered (exceeds 150-200 target — includes boxplot, date, SVG, PS, PDF params)
- **166 named colors** loaded (8 base + 10 tableau + 148 CSS4)
- **All acceptance scenarios PASS** (RC params, cbook, colors, API utilities)

### Gotchas Encountered

1. **CL strings are vectors** — `(vectorp "red")` returns T in CL. Must use `(not (stringp x))` guard when checking for numeric vectors. This caused `to-rgba "red"` to try floating `#\r`.

2. **SBCL --eval only allows one expression** — Must use `--load` for multi-expression test scripts.

3. **normalize-kwargs push order** — When building a plist with push+nreverse, must push key THEN value (not value then key) because nreverse flips the order.

4. **Color name lookup must precede hex-without-# check** — "red" and many color names are valid hex strings (r=13, e=14, d=13). Named color lookup must happen first.

5. **validate-float returns double** — Using `(float x 1.0d0)` produces double-float, which is correct for precision but means equality tests need `=` not `eql`.

### Architecture Decisions

1. **Single hash table per concern** — `*rc-params*`, `*rc-validators*`, `*rc-defaults*` are separate hash tables with string keys. This matches matplotlib's approach.

2. **with-rc uses unwind-protect** — Restores values even on non-local exit. Uses direct `gethash` bypass during restore (not `(setf rc)`) to avoid re-validation of already-validated values.

3. **Validators return validated/coerced values** — Following matplotlib pattern, validators like `validate-float` both validate AND coerce (e.g., int→float, string→float).

4. **Color database uses lowercase keys** — All named color lookups convert to lowercase first, matching matplotlib behavior.

5. **Keyword symbols for enums** — Line styles (`:solid`, `:dashed`), join styles (`:miter`, `:round`), cap styles (`:butt`, `:projecting`) all use CL keywords as specified.

### Files Created
- `src/foundation/cbook.lisp` — 145 LOC, 11 functions
- `src/foundation/api.lisp` — 113 LOC, 11 functions/macros
- `src/foundation/rcsetup.lisp` — 440 LOC, 35 validators + RC store + with-rc
- `src/foundation/rcparams.lisp` — 270 LOC, 265 params registered
- `src/foundation/matplotlibrc-parser.lisp` — 65 LOC, 4 functions
- `src/foundation/colors-database.lisp` — 300 LOC, 166 colors

### Evidence Files
- `.sisyphus/evidence/phase1-all-scenarios.txt` — Full test output (all PASS)
- `.sisyphus/evidence/phase1-rc-params.txt` — RC params scenario
- `.sisyphus/evidence/phase1-cbook.txt` — cbook utilities scenario

---

## Phase 2a Findings — Path System
Date: 2026-02-06

### Implementation Summary
- **Path class** with vertices (simple-array double-float (* 2)) and codes (simple-array (unsigned-byte 8) (*))
- **6 path code constants**: +stop+ (0), +moveto+ (1), +lineto+ (2), +curve3+ (3), +curve4+ (4), +closepoly+ (79)
- **BBox struct** with full operations (union, contains-point, extents)
- **7 core algorithms** ported from C++ to pure CL:
  1. Crossings-multiply point-in-path (from _path.h)
  2. Sutherland-Hodgman polygon clipping
  3. Douglas-Peucker path simplification
  4. De Casteljau Bézier curve subdivision (cubic + quadratic)
  5. Bézier curve extrema calculation (cubic + quadratic)
  6. Segment-segment intersection (from _path.h segments_intersect)
  7. Segment-rectangle intersection
- **12 path operations**: make-path, path-get-extents, path-contains-point, path-contains-points, path-intersects-path, path-intersects-bbox, path-transformed, path-clip-to-bbox, path-to-polygons, path-interpolated, path-cleaned, path-iter-segments
- **5 path constructors**: path-unit-rectangle, path-unit-circle, path-circle, path-arc, path-wedge
- **58 tests, 215 checks, 100% pass rate**

### Gotchas Encountered

1. **float-features:double-float-nan is a constant, not a function** — Use it as a symbol-value, not a function call.

2. **NaN in CL arithmetic** — CL comparison operators (>=, <=) may signal errors with NaN, unlike Python/C++ which return False. Must guard with float-nan-p checks before numeric comparisons.

3. **%coerce-codes with mismatched length** — When coercing a list of codes to an array of size N, if the list has fewer elements, the array silently has zeros in unfilled positions. Must validate input length before coercing.

4. **Bézier curve extents need both x AND y extrema** — Computing extrema along just one axis is insufficient. Must find zeros of the derivative for both x(t) and y(t) independently.

5. **Sutherland-Hodgman requires polygon input** — The clipping algorithm works on closed polygons, not arbitrary paths. Must convert path to polygon(s) first via path-to-polygon-points.

6. **Unit circle uses 8 cubic Bézier segments** — 26 vertices total (MOVETO + 8*3 CURVE4 vertices + CLOSEPOLY). The MAGIC constant 0.2652031 provides optimal circle approximation.

### Architecture Decisions

1. **Two files: path-algorithms.lisp + path.lisp** — Algorithms are pure math (no path struct dependency), path.lisp builds on top with the Path struct and operations.

2. **Cons cells for polygon points** — Internal polygon operations use (x . y) cons cells for efficiency. Public API uses arrays.

3. **Bézier curves flattened to line segments for point-in-path** — Rather than exact curve math, we subdivide curves into line segments (4 segments for quadratic, 8 for cubic). This matches matplotlib's approach of converting curves before testing.

4. **float-features dependency** — Added for NaN handling (float-nan-p). Essential for robust geometry operations.

### Files Created
- `src/primitives/path-algorithms.lisp` — ~350 LOC, 7 algorithms
- `src/primitives/path.lisp` — ~620 LOC, Path struct + 17 operations/constructors
- `tests/test-path.lisp` — ~500 LOC, 58 tests, 215 checks

### Evidence Files
- `.sisyphus/evidence/phase2a-path-ops.txt` — Path creation, extents, containment, constructors
- `.sisyphus/evidence/phase2a-path-clip.txt` — Sutherland-Hodgman clipping scenarios
- `.sisyphus/evidence/phase2a-test-results.txt` — 215/215 checks pass (100%)

---

## Phase 2b Findings — Transform System
Date: 2026-02-06

### Implementation Summary
- **Full CLOS class hierarchy** ported from matplotlib's transforms.py (~530 LOC)
- **12 classes**: transform-node, transform, affine-2d-base, affine-2d, identity-transform, frozen-transform, composite-affine-2d, composite-generic-transform, blended-affine-2d, blended-generic-transform, transform-wrapper, bbox-transform, transformed-bbox, transformed-path-node
- **3×3 affine matrix** as `(simple-array double-float (6))` — inline multiply (~6 muls + 4 adds), invert, point transform
- **Invalidation caching** with 3 states: +valid+ (0), +invalid-affine-only+ (1), +invalid-full+ (2)
- **Weak pointer child management** via trivial-garbage — parents stored as weak pointers, pruned on invalidation walk
- **52 tests, 162 checks, 100% pass rate**

### Architecture Decisions

1. **CLOS classes with :allocation :class for flags** — `is-affine`, `pass-through`, `has-inverse` are class-allocated slots, not per-instance. This mirrors Python's class-level attributes.

2. **Weak pointer list (not dict)** — matplotlib uses a dict with `id(self)` keys for O(1) removal. We use a list of weak pointers and prune dead refs during invalidation walks. Simpler, and transform trees in practice are small.

3. **compose generic function** — Type-dispatched: `(compose affine affine)` → `composite-affine-2d`, `(compose transform transform)` → checks `is-affine` and picks `composite-affine-2d` or `composite-generic-transform`. Identity transforms short-circuit.

4. **Matrix storage convention** — `[a b c d e f]` representing `[[a c e] [b d f] [0 0 1]]`. This matches matplotlib's `(a, b, c, d, e, f)` from `to_values()`.

5. **Frozen transforms** — `frozen-transform` class holds immutable copy. No invalidation propagation. Used for snapshots.

6. **make-affine-2d API** — Constructor accepts `:matrix`, `:translate`, `:scale`, `:rotate` keywords. Operations applied in order: scale → rotate → translate.

### Gotchas Encountered

1. **Acceptance scenario semantics** — The plan's acceptance scenario 1 says "translate first, then scale" → (12, 23) for point (1,1). This means scale(1,1)→(2,3) THEN translate(2,3)→(12,23), so scale is applied first in the composition: `(compose scale translate)`.

2. **Invalidation direction** — matplotlib's invalidation propagates from children UP to parents (parents depend on children). `set_children` registers the PARENT as a dependent OF each child. This is counterintuitive — "children" in transform parlance are the INPUT transforms, not parent-child in the tree sense.

3. **Class-allocated slots and subclasses** — Using `:allocation :class` with `:initform` on the base class means subclasses that override must also use `:allocation :class`. This works cleanly in SBCL.

### Files Created
- `src/primitives/transforms.lisp` — ~530 LOC, 12 classes + operations
- `tests/test-transforms.lisp` — ~550 LOC, 52 tests, 162 checks

### Evidence Files
- `.sisyphus/evidence/phase2b-affine-compose.txt` — Scenario 1 PASS
- `.sisyphus/evidence/phase2b-invalidation.txt` — Scenario 2 PASS
- `.sisyphus/evidence/phase2b-test-results.txt` — 377/377 checks pass (215 path + 162 transform)

---

## Phase 2c Findings — Color System
Date: 2026-02-06

### Implementation Summary
- **Colormap base class** with CLOS: `colormap`, `linear-segmented-colormap`, `listed-colormap`
- **7 Normalize classes**: `normalize`, `no-norm`, `log-norm`, `sym-log-norm`, `power-norm`, `two-slope-norm`, `boundary-norm`
- **ScalarMappable** mixin combining norm + colormap
- **23 colormaps registered**: viridis, plasma, inferno, magma, cividis, Greys, Reds, Blues, Greens, hot, cool, coolwarm, RdBu, RdYlGn, Spectral, jet, gray, binary, spring, summer, autumn, winter, grey (alias)
- **Colormap registry**: hash table with string keys, `register-colormap`, `get-colormap`, `list-colormaps`
- **55 tests, 211 checks, 100% pass rate**
- **Total system: 588 checks (215 path + 162 transform + 211 color), 100% pass**

### Gotchas Encountered

1. **Cannot define method on FUNCALL** — CL's `funcall` is a built-in function, not a generic function. Cannot use `(defmethod funcall ((cmap colormap) ...))`. Instead, use `colormap-call` as the generic function name.

2. **CL format ~x produces uppercase hex** — `(format nil "~2,'0x" 255)` → "FF" not "ff". Must wrap with `string-downcase` to match matplotlib's lowercase hex convention.

3. **Perceptually uniform colormaps (viridis etc.) have 256 entries** — Too large to embed directly. Used 16 control points with linear interpolation to approximate. This is a tradeoff: exact values would require ~15KB per colormap. The interpolated version is close but not bit-exact with matplotlib.

4. **From-list colormaps (Blues, Reds, etc.) use 9-11 RGB control points** — These are passed through `linear-segmented-colormap-from-list` which builds segment data internally.

5. **Segment data format** — matplotlib uses tuples `(x, y0, y1)` where y0 is the value approaching from below and y1 is the value leaving above. For continuous colormaps, y0 == y1. The `%create-lookup-table` function handles this correctly.

### Architecture Decisions

1. **CLOS classes for colormaps** — `colormap` base class with `linear-segmented-colormap` and `listed-colormap` subclasses. Uses `colormap-init` generic function for lazy LUT initialization.

2. **LUT as 2D array** — `(simple-array double-float ((N+3) 4))` where N is the number of quantization levels, +3 for under/over/bad colors. This matches matplotlib's layout.

3. **Normalize as CLOS classes** — Each normalization type is a separate class with `normalize-call` and `normalize-inverse` generic functions. This allows easy extension.

4. **Colormap registry uses string keys** — `get-colormap` accepts keywords, strings, or symbols and normalizes to lowercase strings. Case-insensitive lookup as fallback.

5. **Control point interpolation for listed colormaps** — Rather than embedding 256×3 = 768 floats per colormap, we store 16 control points and interpolate. This keeps the source compact while providing reasonable accuracy.

### Files Created
- `src/primitives/colors.lisp` — ~480 LOC, Colormap + Normalize classes + ScalarMappable
- `src/primitives/colormaps.lisp` — ~350 LOC, Colormap data + registry
- `tests/test-colors.lisp` — ~500 LOC, 55 tests, 211 checks

### Evidence Files
- `.sisyphus/evidence/phase2c-color-convert.txt` — Color conversion scenarios PASS
- `.sisyphus/evidence/phase2c-colormap.txt` — Colormap mapping scenarios PASS
- `.sisyphus/evidence/phase2c-test-results.txt` — 588/588 checks pass (100%)
