# Visual Regression Learnings

## [2026-02-19] Initial Assessment — Resuming from previous session

### Current State
- Infrastructure (Tasks 1-6): COMPLETE
- Bug fixes (Tasks 7-11): PARTIALLY COMPLETE
- Gallery (Tasks 12-15): COMPLETE
- Final verification (F1-F4): NOT DONE
- SSIM results: 1/27 passing (pie-chart only, 0.939)

### What Was Fixed in Previous Sessions
1. **Black background**: to-rgba return type fix — corners are now white ✓
2. **Text rendering**: fontsize via :linewidth fixed — title, xlabel, ticks visible ✓
3. **Bar charts**: distinct bars visible ✓  
4. **Scatter**: visible colored points ✓
5. **Pie chart**: centered, SSIM 0.94 ✓

### Remaining Issues Identified by Visual Analysis

#### CRITICAL (SSIM far below 0.90):
1. **filled-contour (SSIM 0.52)**: 
   - Color mapping INVERTED — viridis colors reversed
   - Contour geometry distorted (peak shifted/elongated)
   - Root cause: likely Y-axis flip + colormap direction in contourf

2. **colorbar-custom (SSIM 0.62)**:
   - Plasma colormap not applied correctly — warm tones only, missing cool colors
   - Data value range compressed/remapped

3. **contour-lines (SSIM 0.74)**:
   - Contours shifted to upper-right quadrant
   - Same geometric distortion as filled-contour
   - Root cause: coordinate transformation issue

4. **imshow-heatmap (SSIM 0.75)**:
   - viridis colormap posterized/quantized (discrete blocks vs smooth gradient)
   - Root cause: colormap interpolation quality

#### MODERATE (SSIM 0.77-0.87, needs ~0.03-0.13 improvement):
5. **histogram (SSIM 0.78)**: Grid lines render as WHITE instead of gray
6. **boxplot (SSIM 0.80)**: Similar grid/spacing issues
7. **stackplot (SSIM 0.80)**: Grid/spacing issues  
8. **bar-chart (SSIM 0.82)**: Spacing/layout differences
9. **barh (SSIM 0.82)**: Similar
10. **Most 0.82-0.89 examples**: Text appears lighter/fainter, possible font weight difference
11. **Y-label (ylabel) NOT VISIBLE** in many examples — confirmed in task-8 evidence

### Key Technical Issues

#### Contour/Colormap Root Causes (hypothesis):
- The viridis/plasma colormap color order may be inverted in the CL implementation
- Contour Y-axis: Vecto uses bottom-left origin, but contour data may not account for flip
- The marching squares outputs may have coordinates in screen space vs data space

#### Grid Line Color:
- CL renders grid lines as WHITE (#ffffff) instead of the standard gray
- Check: `src/containers/axes-base.lisp` or `src/rendering/lines.lisp` grid color default

#### Text Weight:
- CL text appears lighter than Python matplotlib
- May be font rendering difference (Liberation Sans vs DejaVu Sans)
- Or font weight/style not matching

#### Y-Label Issue:
- From task-8 evidence: ylabel NOT VISIBLE (variance=0.0, non-white pixels=0)
- The ylabel is rotated 90 degrees — if rotation isn't implemented, it won't show
- Check: `src/containers/axis.lisp` ylabel draw method

### Evidence Files
- task-2-caller-audit.txt: to-rgba audit
- task-7-white-background.txt: background fix confirmed
- task-8-text-visible.txt: text fix — ylabel STILL missing  
- task-9-bar-chart.txt: bar chart fix confirmed
- task-10-contour.txt: contour visible but distorted
- task-11-final-ssim.txt: final scores after all fixes
- fix-text-rotation.txt: ylabel now visible (variance 63.4, 33 non-white pixels)

## [2026-02-19] Text Rotation Fix

### What Was Done
- **Clip reset**: In `draw-text`, when GC has no `clip-rectangle`, reset clip to full figure
  using `vecto:rectangle` + `vecto:clip-path` + `vecto:end-path-no-op`. This prevents
  ylabel (positioned at x≈35-45, outside axes clip) from being clipped invisible.
- **Rotation**: Replaced the no-op `(when angle≠0 nil)` with `vecto:translate` to the text
  position + `vecto:rotate-degrees` + `vecto:draw-string` at origin. Non-rotated text
  path unchanged (angle=0 still calls draw-string directly).

### Key Pattern
Vecto's `with-graphics-state` properly saves/restores transforms, so translate+rotate
inside it won't affect subsequent draws. The clip reset also stays scoped.
## [2026-02-19] Colormap Fix — Full 256-Entry Tables

### What Was Done
- Replaced 16-point interpolated control points with full 256-entry lookup tables
  for viridis, plasma, inferno, magma, cividis
- Data extracted directly from Python matplotlib via `cm.get_cmap(name)(i/255.0)`
- Changed `initialize-colormaps` to use `%register-listed-cmap` directly with the
  256-entry data instead of `%register-listed-cmap` + `%interpolate-control-points`
- Kept `%interpolate-control-points` function intact (tests may use it)

### Key Finding
- The 16-point linear interpolation produced SIGNIFICANTLY wrong colors in the
  middle of the colormap range where the gradient changes direction rapidly
- At norm=0.524: old CL → rgb=(89,206,95) [bright green], correct → rgb=(31,150,139) [teal]
- This is because viridis has a complex S-curve in the green channel that can't be
  captured with only 16 points + linear interpolation

### Results
- Viridis at 0.524: EXACT MATCH (0,0,0 per-channel diff)
- Test suite: 91/91 pass (100%)
- SSIM improvement: imshow-heatmap 0.75 → 0.8245 (+0.07)
- Other colormap-heavy examples also improved

### Pattern
- `%register-listed-cmap` creates a ListedColormap which does nearest-neighbor
  lookup into the 256 entries — no interpolation needed
- For perceptually uniform colormaps, 256 entries = exact reproduction

## [2026-02-19] Filled-Contour Colormap Inversion Fix

### What Was Done
- Fixed normalization in `src/plotting/contour.lisp` `initialize-instance :after` for
  `quad-contour-set`: changed from `(make-normalize :vmin zmin :vmax zmax)` (data range)
  to `(make-normalize :vmin (first levels) :vmax (car (last levels)))` (levels range)
- This matches Python matplotlib's behavior where contourf normalizes by the level
  boundaries, not the raw data min/max

### Root Cause (Two-Part)
1. **Transform staleness** (already fixed in `8cb1653`): `%update-trans-data` creates new
   transform objects but PolyCollections held refs to old composites. Fix: propagate
   updated transform at draw time in ContourSet's draw method.
2. **Normalization range** (fixed in `cbb83ad`): CL used `zmin/zmax` (data range) while
   Python uses `levels[0]/levels[-1]` (level range). When levels extend beyond data range
   (e.g., levels go to 1.04 but data max is 1.0), this shifts all colors.

### Key Findings
- Composite transforms (`composite-affine-2d`) store REFERENCES to child transforms,
  not copies — they're live. But `%update-trans-data` replaces the objects entirely.
- Python's `ContourSet.__init__` explicitly sets `self.norm.vmin = self.levels.min()`
  and `self.norm.vmax = self.levels.max()`.
- CL and Python produce identical levels: `(0.0, 0.08, 0.16, ..., 0.96, 1.04)` —
  14 levels, 13 bands.
- After fix: center pixel CL (231,228,25) = Reference (231,228,25) ✓
  BL corner pixel CL (71,14,97) = Reference (71,14,97) ✓

### SSIM Gap Analysis
- SSIM improved from 0.52 → ~0.61 but target was >0.90
- Remaining gap is NOT colormap-related — colors now match exactly
- Dominant factor: **cell-boundary antialiasing artifacts** — each grid cell is rendered
  as a separate polygon, creating 1-pixel color bleed at every cell boundary
  (136 color transitions vs 41 in reference)
- PolyCollection has `antialiased: t` hardcoded in `src/rendering/collections.lisp`
- Fixing this requires either: (a) merging adjacent same-color polygons before rendering,
  or (b) disabling antialiasing for contourf collections, or (c) rendering contourf bands
  as single merged paths instead of per-cell polygons

### Pattern
- When debugging visual output, verify BOTH spatial positions AND color values separately
- Pixel checks at known locations (center, corners) are more reliable than SSIM for
  diagnosing specific issues
- SSIM can be dominated by structural artifacts (antialiasing, line width) even when
  colors are pixel-perfect
## [2026-02-19] Three Rendering Fixes — Title, Sticky Edges, imshow Aspect

### Fix 1: Title Centering
- `vecto:draw-centered-string` uses `(- x (+ width/2 xmin))` where `xmin` is left bearing
- This shifts text RIGHT by `xmin` pixels (~64px for typical fonts at title size)
- **Fix**: Manual centering using `vecto:string-bounding-box` to get true width, then
  `(- dx (/ width 2.0))` for non-rotated, `(/ width -2.0)` for rotated center text
- **Key learning**: `font` from `%get-font` IS already a `zpb-ttf:font-loader` —
  do NOT call `vecto::loader` on it (that's for vecto font wrapper objects)

### Fix 2: Sticky Edges (y-axis)
- `axes-autoscale-view` applied 5% margin to BOTH y0 and y1
- For bar charts where data starts at y=0, this made y0=-2.25, shifting bars up
- **Fix**: `(unless (zerop y0) (setf y0 (- y0 y-margin)))` — skip bottom margin when y0=0
- Matches matplotlib's "sticky edge" behavior

### Fix 3: imshow Equal Aspect
- Default was `:auto`, matplotlib default is `'equal'`
- The `:equal` handler was a no-op with `(declare (ignore ext-w ext-h)) nil`
- **Fix**: After autoscale, compute display aspect from figure/axes dimensions,
  compare to data aspect, expand the smaller dimension to match
- Uses `axes-base-view-lim`, `axes-base-figure`, `axes-base-position`,
  `figure-width-px`, `figure-height-px` to get display dimensions
- Must call `%update-trans-data` after modifying `axes-base-view-lim`
- Aspect enforcement runs AFTER `axes-autoscale-view` so view-lim is already set

### SSIM Results
- simple-line: 0.9052 (title centering improved)
- bar-chart: 0.8914 (sticky edges + title centering improved)
- imshow-heatmap: 0.8201 (aspect ratio now correct)
- scatter: 0.8690 (title centering improved)

## Spine Snap Formula & Sticky Edge Fix (2026-02-19)

### Problem
Two regressions were introduced:
1. Horizontal spine snap formula changed from `(- (floor py) 0.5d0)` to `(float (floor py) 1.0d0)`, causing gray spines instead of clean black
2. Sticky edge (y=0 no margin) was applied to ALL plots, not just bar charts, breaking line plot autoscaling

### Root Cause
- **Spine formula**: The half-pixel offset `(- (floor py) 0.5d0)` places the spine at y=527.5, which Vecto renders as a clean black line at row 72. The integer offset `(float (floor py) 1.0d0)` places it at y=528.0, causing the 1.39px line to split across two rows as gray (77,77,77).
- **Sticky edge**: The autoscale logic was unconditionally skipping the bottom margin when y0=0, which is correct for bar charts but wrong for line plots that happen to have y0=0.

### Solution
1. **Reverted spine formula** in `src/containers/spines.lisp` line 109 back to `(- (floor py) 0.5d0)`
2. **Added `sticky-y-min` slot** to `axes-base` class (boolean, default nil)
3. **Updated `axes-autoscale-view`** to only apply sticky edge when `sticky-y-min` is t
4. **Set `sticky-y-min=t`** in `bar()` function before autoscale

### Key Insights
- Vecto coordinate system: y=0 at BOTTOM, y=height at TOP
- PNG saves with y=0 at TOP (flipped)
- Half-pixel offsets are critical for clean rendering of thin lines
- Feature flags (like `sticky-y-min`) should be set by the function that needs them, not globally

### Files Changed
- `src/containers/spines.lisp`: Reverted horizontal spine formula
- `src/containers/axes-base.lisp`: Added sticky-y-min slot and updated autoscale logic
- `src/containers/axes.lisp`: Set sticky-y-min=t in bar() function

### Verification
- `sbcl --load examples/simple-line.lisp` ✓ (no error)
- `sbcl --load examples/bar-chart.lisp` ✓ (no error)
- Commit: c3b8b3f fix(rendering): revert spine snap, fix sticky edge to bar-only

## Task 5: Text Width Heuristic → Glyph Metrics
- `get-text-extents` in font-manager.lisp returns a BBOX; use `bbox-width` to extract width
- `load-font "sans-serif"` returns cached zpb-ttf font-loader via font-manager
- The 0.6d0 heuristic was actually decent for DejaVu Sans — average advance width ≈ 0.6 em
- Actual glyph metrics give per-string accuracy (kerning, variable-width chars)
- SSIM improvement from this fix alone is marginal (+0.001-0.002) — legend sizing isn't the main SSIM bottleneck
- Font-loader is in `cl-matplotlib.rendering` package; accessible from containers via `mpl.rendering:` prefix

## Log-Scale Transform Pipeline (Task 4)
- `trans-scale` must be incorporated in `%update-trans-data` pipeline
- Pipeline: data → trans-scale → scaled-viewLim→unit → transAxes → display
- View limits stay in DATA space; scaled-view-lim is computed by transforming view limits through trans-scale
- For identity trans-scale (linear), `compose(identity, X) = X` — zero overhead
- Autoscale margins must be computed in LOG space for log scale (linear margins create negative Y values that clip to -1000)
- `%setup-transforms` should NOT reset trans-scale — use `unless nil` guard
- `log-y-transform` needed as separate class since existing `log-transform` only transforms X
- All non-affine transforms need `transform-path` methods for composite-generic-transform composition
