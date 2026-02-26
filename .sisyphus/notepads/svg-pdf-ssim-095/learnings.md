# Learnings — svg-pdf-ssim-095

## [2026-02-26] Session ses_36519319affe8bw0xkjMJ2dY8P — Plan Started

### Inherited From svg-pdf-rendering-fixes

#### Current SSIM State (post rendering-fixes plan)
- SVG: 77/79 pass at 0.70 threshold, mean=0.870, min=0.633 (pcolormesh), max=0.967
- PDF: 79/79 pass at 0.50 threshold, mean=0.925, min=0.795, max=0.964
- 4 PDFs (polar-line, polar-rose, polar-spiral, step-plot) had VoidChar font errors during regen but stale PDFs from Feb 23 compared OK

#### Key Backend Facts
- SVG canvas: 800×600px — CORRECT, matches PNG. Do NOT change.
- SVG DPI bug: compare.py uses `-density 100` but should be `-density 96` for CSS px SVGs
- PDF image rendering: placeholder gray rectangle in draw-image method (lines 364-381)
- PDF dash patterns: hardcoded constants (lines 64-78), not linewidth-scaled
- Vecto half-pixel snapping exists at backend-vecto.lisp:170-219 — need to port to SVG/PDF

#### cl-pdf API (Verified Working)
- `pdf::text-width` (internal, 3 args: string font fontsize) — returns width in points
- `pdf:get-font-descender` (external, 2 args: font fontsize) — returns negative scaled value
- `(pdf::ascender (pdf:font-metrics font))` — ascender ratio, multiply by fontsize
- `pdf:make-image path` — loads PNG from file path
- `pdf:draw-image image x y width height` — draws image in PDF

#### FASL Cache Warning
- SBCL FASL cache at `~/.cache/common-lisp/` can become stale
- Always `rm -rf ~/.cache/common-lisp/` before major re-render sessions

#### compare.py Current State
- Has `--format svg|pdf|png` and `--dpi` flags (added in rendering-fixes plan)
- SVG rasterization: `convert -density {dpi} input.svg -flatten output.png`
- PDF rasterization: `pdftoppm -r {dpi} -png -singlefile input.pdf prefix`
- NO allowlist mechanism yet — needs to be added in Task 2
- pdftoppm naming quirk: `-singlefile` creates `{prefix}.png`

#### Root Causes for Current SSIM Gap
1. SVG: DPI mismatch (100 vs 96) → +0.002 to +0.022 per example
2. SVG: Missing half-pixel snapping → uncertain benefit
3. SVG/PDF: pcolormesh uses flat-color, not Gouraud → allowlist candidate
4. PDF: draw-image placeholder gray rect → -0.15 SSIM on imshow/heatmap examples
5. PDF: Hardcoded dash patterns → -0.05 to -0.08 on multi-line-styles

### Key Guardrails
- DO NOT modify backend-vecto.lisp
- DO NOT change SVG canvas dimensions or viewBox
- DO NOT add new external Lisp dependencies
- DO NOT embed TrueType fonts in PDF (accept Helvetica)
- DO NOT implement Gouraud shading
- DO NOT change compare.py JSON/HTML schema
- DO NOT tune SVG for ImageMagick quirks — fix the tool
- MINIMIZE allowlist — data-driven only

## [2026-02-26] Task 1: Baseline SSIM Measurements — COMPLETED

### SVG Baseline (DPI 100, current default)
- **Total examples**: 79
- **Mean SSIM**: 0.8697
- **Min SSIM**: 0.6329 (pcolormesh)
- **Max SSIM**: 0.9711 (streamplot-basic)
- **Below 0.95**: 70 examples
- **Below 0.90**: 51 examples
- **Below 0.85**: 26 examples
- **Below 0.80**: 9 examples

**Worst performers** (flat-color pcolormesh, multi-line-styles, span-regions, fill-between-alpha):
- pcolormesh: 0.6329
- pcolormesh-basic: 0.6596
- span-regions: 0.7630
- fill-between-alpha: 0.7632
- curve-error-band: 0.7635
- multi-line-styles: 0.7819

### PDF Baseline (DPI 72, default)
- **Total examples**: 79
- **Mean SSIM**: 0.9255
- **Min SSIM**: 0.8012 (pcolormesh-basic)
- **Max SSIM**: 0.9693 (scatter-sizes)
- **Below 0.95**: 65 examples
- **Below 0.90**: 10 examples
- **Below 0.85**: 4 examples
- **Below 0.80**: 0 examples

**Worst performers** (pcolormesh, imshow, annotated-heatmap, multi-line-styles):
- pcolormesh-basic: 0.8012
- pcolormesh: 0.8126
- imshow-heatmap: 0.8273
- annotated-heatmap: 0.8341
- multi-line-styles: 0.8692

### Evidence Files Created
- `.sisyphus/evidence/task-1-svg-baseline.json` — 79 examples, sorted ascending (worst first)
- `.sisyphus/evidence/task-1-pdf-baseline.json` — 79 examples, sorted ascending (worst first)

### Key Observations
1. **SVG gap**: 0.8697 mean is 0.0558 below PDF (0.9255). Aligns with inherited wisdom of ~0.870.
2. **PDF strength**: Only 4 examples below 0.85 threshold, none below 0.80. Solid baseline.
3. **Shared worst cases**: pcolormesh (flat-color) and multi-line-styles are worst in both formats.
4. **PDF image rendering**: imshow-heatmap (0.8273) suggests draw-image placeholder gray rect issue.
5. **SVG dimension mismatch**: All comparisons show 2-4% dimension mismatch (e.g., 600×800 vs 625×833), likely due to DPI 100 vs 96 CSS px conversion.

### Next Steps (Task 2)
- Fix SVG DPI to 96 (CSS px standard) — expect +0.002 to +0.022 per example
- Add allowlist mechanism for pcolormesh (flat-color) and other known worst cases
- Measure improvement in Task 2 baseline

## [2026-02-26] Task 3: Makefile Targets and allowlist.json — COMPLETED

### Changes Made
1. **Makefile**: Added three new targets
   - `compare-svg`: Runs compare.py with `--format svg --dpi 96 --allowlist allowlist.json`
   - `compare-pdf`: Runs compare.py with `--format pdf --allowlist allowlist.json`
   - `compare-all`: Depends on compare, compare-svg, compare-pdf (runs all three)
   - Updated `.PHONY` to include new targets
   - Updated `all` target to include compare-svg and compare-pdf

2. **allowlist.json**: Created at repo root with content `{}`
   - Will be populated in Task 9 (allowlist calibration)
   - Used by both compare-svg and compare-pdf targets

### Verification
- `make -n compare-svg` ✓ Shows correct command with --dpi 96
- `make -n compare-pdf` ✓ Shows correct command with --allowlist
- `make -n compare-all` ✓ Runs all three comparisons in sequence

### Key Implementation Details
- SVG target uses `--dpi 96` (CSS px standard, not 100)
- Both SVG and PDF targets reference `allowlist.json`
- All targets depend on `cl-images` to ensure fresh renders
- Output directories: `comparison_report_svg/`, `comparison_report_pdf/`, `comparison_report/`

### Next Steps (Task 2)
- Task 2 will add DPI fix to compare.py (already done in rendering-fixes plan)
- Task 9 will populate allowlist.json with known SSIM mismatches


## [2026-02-26] Task 2: DPI 96 Fix & Allowlist in compare.py — COMPLETED

### Changes to tools/compare.py
1. **SVG DPI default**: Changed `--dpi` default from 100 to None, then conditionally set to 96 for SVG, 100 for PDF/PNG
   - CSS px = 1/96 inch, so `-density 96` produces exact pixel dimensions
   - At DPI 100: 800px SVG → 833px rasterized (1.04x oversized)
   - At DPI 96: 800px SVG → 800px rasterized (exact match)
   - Mean SSIM improved: 0.8697 (DPI 100) → 0.8829 (DPI 96), +0.013 gain

2. **--allowlist argument**: Reads JSON file `{"name": "reason", ...}`
   - Matched FAILs become status=ALLOW with reason in note
   - ALLOW entries: SSIM still computed, comparison sheet still generated
   - Exit code: 0 if all PASS/ALLOW, 1 if any FAIL
   - JSON summary.json extended with "allowed" count in overall
   - HTML report shows ALLOW in amber (#f59e0b)

### QA Results
- SVG DPI 96: 79/79 PASS at 0.30, mean SSIM 0.8829
- Allowlist: pcolormesh correctly shows ALLOW, exit code 1 with other FAILs
- PNG compat: 79/79 PASS, SSIM 1.0000, exit 0 (DPI change does not affect PNG)

### Evidence
- `.sisyphus/evidence/task-2-dpi96-test.txt`
- `.sisyphus/evidence/task-2-allowlist-test.txt`
- `.sisyphus/evidence/task-2-png-compat.txt`

## [2026-02-26] Task 6: DPI 96 Improvement Measurement — COMPLETED

### Measurement Results
- **DPI 96 Mean SSIM**: 0.8829 (vs 0.8697 at DPI 100)
- **Mean Improvement**: +0.0132 (+1.52%)
- **Count above 0.95 at DPI 96**: 13 (vs 9 at DPI 100)
- **New examples above 0.95**: +4 (bar-labels, custom-ticks, inverted-axes, text-alignment)

### Top 10 Movers (Biggest Improvements)
1. hlines-vlines: 0.9037 → 0.9411 (+0.0374)
2. stem-plot: 0.7940 → 0.8281 (+0.0341)
3. histogram-multi: 0.8687 → 0.8984 (+0.0297)
4. step-plot: 0.8576 → 0.8860 (+0.0284)
5. barh: 0.8633 → 0.8903 (+0.0270)
6. threshold-lines: 0.8905 → 0.9170 (+0.0265)
7. figure-sizes: 0.8324 → 0.8587 (+0.0263)
8. subplots: 0.7956 → 0.8212 (+0.0256)
9. errorbar-features: 0.8567 → 0.8823 (+0.0256)
10. boxplot-styles: 0.8902 → 0.9148 (+0.0246)

### Regressions (Minor)
- pcolormesh: 0.6329 → 0.6208 (-0.0121) — flat-color issue, not DPI-related
- pcolormesh-basic: 0.6596 → 0.6509 (-0.0087) — flat-color issue, not DPI-related
- streamplot-styled: 0.9695 → 0.9671 (-0.0024) — negligible
- pie-features: 0.9564 → 0.9550 (-0.0014) — negligible
- pie-chart: 0.9611 → 0.9600 (-0.0011) — negligible

### Key Insights
1. **DPI 96 fix validates**: +0.0132 mean improvement aligns with expected +0.002 to +0.022 range
2. **Pixel-perfect alignment**: DPI 96 (CSS px standard) produces exact 800×600 rasterization
3. **Biggest winners**: Line-based plots (hlines-vlines, stem-plot, histogram-multi) benefit most
4. **pcolormesh regression**: Not DPI-related; flat-color rendering issue persists
5. **4 new examples above 0.95**: bar-labels, custom-ticks, inverted-axes, text-alignment

### Evidence File
- `.sisyphus/evidence/task-6-dpi-improvement.json` — Full per-example comparison with deltas

## [2026-02-26] Task 4: PDF Dash Pattern Scaling — COMPLETED

### Problem
- PDF dash patterns were hardcoded constants: dashed=(6,4), dashdot=(6,3,2,3), dotted=(2,4)
- SVG backend uses linewidth-relative patterns: dashed=(3.7,1.6), dashdot=(6.4,1.6,1.0,1.6), dotted=(1.0,1.65)
- PDF patterns not scaled by linewidth → rendering mismatch with SVG/PNG
- multi-line-styles SSIM: 0.8692 (below target of 0.869)

### Solution
- Modified `%apply-gc-to-pdf` in `src/backends/backend-pdf.lisp` (lines 63-84)
- Extracted linewidth from graphics context: `lw = (or (gc-linewidth gc) 1.0)`
- Computed multiplier: `mult = max(lw, 1.0)` (prevents scaling down below 1.0)
- Applied to all named line styles:
  - `:dashed` → `(list (* 3.7d0 mult) (* 1.6d0 mult))`
  - `:dashdot` → `(list (* 6.4d0 mult) (* 1.6d0 mult) (* 1.0d0 mult) (* 1.6d0 mult))`
  - `:dotted` → `(list (* 1.0d0 mult) (* 1.65d0 mult))`
- Explicit dash lists (gc-dashes) remain unchanged

### Results
- Test suite: 208/208 PASS (100%)
- multi-line-styles SSIM: 0.8767 (was 0.8692)
- Improvement: +0.0075 (+0.86%)
- Status: EXCEEDS target of 0.869

### Key Learnings
1. **Pattern alignment**: PDF and SVG must use same base patterns for rendering parity
2. **Linewidth scaling**: Dash patterns must scale with linewidth to maintain visual consistency
3. **Multiplier guard**: `max(lw, 1.0)` prevents degenerate patterns at very small linewidths
4. **Explicit vs named**: Explicit dash lists (gc-dashes) bypass scaling — correct behavior

### Evidence
- `.sisyphus/evidence/task-4-dash-improvement.txt` — SSIM improvement verification

## [2026-02-26] Task 5: PDF Image Rendering — COMPLETED

### Problem
- `draw-image` in backend-pdf.lisp drew a gray rectangle placeholder instead of actual image content
- imshow-heatmap SSIM: 0.8273, annotated-heatmap SSIM: 0.8341

### Solution
- Replaced placeholder with real image rendering using cl-pdf's native API
- Pattern mirrors SVG backend: zpng creates PNG from RGBA data → temp file → cl-pdf loads and draws
- Key implementation: zpng `:truecolor-alpha` → `pdf:make-image` → `pdf:add-images-to-page` → `pdf:draw-image`

### Critical Discoveries
1. **`pdf:draw-image` takes 6 args**: `(image x y dx dy rotation)`, NOT 5 as initially assumed
2. **`pdf:add-images-to-page` is MANDATORY**: Without it, image XObjects aren't registered with the page
   - Symptom: pdftoppm reports "XObject 'CLI101' is unknown"
   - Fix: Call `(pdf:add-images-to-page pdf-image)` before drawing
3. **RGBA PNGs work with cl-pdf**: No pre-compositing to RGB needed
4. **Y-coordinate is correct as-is**: PDF Y-up coordinate system matches what the backend passes

### Results
- imshow-heatmap: 0.8273 → **0.9707** (+0.1434) — exceeds 0.90 target
- annotated-heatmap: 0.8341 → **0.9255** (+0.0914) — exceeds 0.87 target
- Test suite: 208/208 PASS (100%)

### Evidence
- `.sisyphus/evidence/task-5-pdf-image-ssim.txt`
- `.sisyphus/evidence/task-5-test-suite.txt`