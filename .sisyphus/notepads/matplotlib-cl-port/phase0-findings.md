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
