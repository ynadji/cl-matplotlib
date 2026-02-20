# Push All 27 Examples to SSIM ≥ 0.95

## TL;DR

> **Quick Summary**: Fix concrete rendering bugs in cl-matplotlib (dead log-transform pipeline, dashed boxplot whiskers, hardcoded scatter defaults, crude legend text-width heuristic) to push all 27 visual regression examples from SSIM > 0.90 to ≥ 0.95 against Python matplotlib 3.8.4 references.
> 
> **Deliverables**:
> - All 27 examples passing `make compare` at SSIM ≥ 0.95
> - Makefile threshold updated from 0.90 to 0.95
> - 4 systemic bug fixes + targeted per-example fixes
> 
> **Estimated Effort**: Medium-Large
> **Parallel Execution**: YES — 4 waves
> **Critical Path**: Task 1 (baseline) → Task 4 (log-scale transform) → Task 8+ (example-specific) → Task F1-F4 (verification)

---

## Context

### Original Request
Push all 27 cl-matplotlib examples from SSIM > 0.90 to ≥ 0.95 against Python matplotlib reference images. Focus on fixable bugs — accept rendering engine quality floor (zpb-ttf vs FreeType, Vecto vs Agg).

### Interview Summary
**Key Discussions**:
- Title mismatch: Investigated and debunked — SSIM computed on raw PNGs with identical titles
- Curve jaggedness: Both implementations use same data points and straight segments; difference is anti-aliasing quality (accepted as floor)
- Priority: Systemic fixes first (lift many examples), then example-specific
- Scope: Fixable bugs only — no rendering engine replacement

**Research Findings**:
- 17/27 examples below 0.95 (gaps from 0.003 to 0.049)
- Legend text width uses `0.6 × fontsize × char_count` heuristic (should use actual glyph metrics via `get-text-extents`)
- Scatter hardcodes edge color and linewidth ignoring rcParams
- Boxplot whiskers hardcoded to `:dashed` (rcParams says solid)
- Log-scale: `trans-scale` field is DEAD — initialized to identity, never incorporated into data→display pipeline

### Metis Review
**Identified Gaps** (addressed):
- Log-transform is 1D X-only — must support Y-axis application for `yscale :log`
- `get-text-extents` requires font-loader plumbing into legend/annotation code
- 0.6× heuristic exists in 4 places (legend, annotation, fancy-arrow, annotation-bbox)
- TightLayoutEngine is a no-op stub — explains shared-axes spacing issues
- Log-scale fix has cascade effects on autoscaling and tick positioning (view limits must stay in data space)
- Per-fix regression checking is mandatory (no example currently ≥ 0.95 may drop below)

---

## Work Objectives

### Core Objective
Fix identified rendering bugs so all 27 cl-matplotlib examples achieve SSIM ≥ 0.95 against their Python matplotlib 3.8.4 reference images.

### Concrete Deliverables
- `make compare` exits 0 with `THRESHOLD=0.95`
- All 27 SSIM scores ≥ 0.95 in `comparison_report/summary.json`
- No regressions: examples currently above 0.95 stay above 0.95

### Definition of Done
- [ ] `make compare` exit code 0 with THRESHOLD=0.95
- [ ] `comparison_report/summary.json` shows 27/27 passed, 0 failed
- [ ] Mean SSIM ≥ 0.95 (currently 0.9415)
- [ ] Min SSIM ≥ 0.95 (currently 0.9012)

### Must Have
- Log-scale transform incorporated into data→display pipeline
- Boxplot whiskers rendered as solid lines
- Scatter edge color and linewidth from rcParams
- Legend text width computed from actual glyph metrics
- All 27 examples at SSIM ≥ 0.95

### Must NOT Have (Guardrails)
- NO modifications to reference images or reference scripts
- NO modifications to `tools/compare.py` (SSIM computation must stay constant)
- NO changing font rendering engine (zpb-ttf) or anti-aliasing engine (Vecto/cl-aa)
- NO adding new plot types or restructuring the rendering pipeline beyond the identified fixes
- NO changing the transform pipeline for purposes other than incorporating `trans-scale`
- NO acceptance criteria requiring human visual inspection

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (`make compare` pipeline with SSIM thresholds)
- **Automated tests**: Tests-after (verify SSIM after each fix)
- **Framework**: Python SSIM comparison via `tools/compare.py`
- **Per-fix regression check**: After EVERY fix, run `make cl-images && make compare` and verify:
  - No example currently ≥ 0.95 has dropped below 0.95
  - Overall mean SSIM has not decreased
  - The targeted example's SSIM has improved

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Rendering fixes**: Use Bash — regenerate images, run SSIM comparison, assert scores
- **Transform fixes**: Use Bash — run specific example, pixel-analyze output vs reference

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Baseline — required first):
├── Task 1: Update Makefile threshold + record baseline [quick]

Wave 2 (Systemic fixes — order by risk, lowest first):
├── Task 2: Fix boxplot whisker linestyle dashed→solid [quick]
├── Task 3: Fix scatter edgecolor/linewidth to match rcParams [quick]
├── Task 4: Fix log-scale trans-scale integration into transform pipeline [deep]
├── Task 5: Fix legend/annotation text width → actual glyph metrics [unspecified-high]

Wave 3 (Example-specific fixes — MAX PARALLEL, after Wave 2):
├── Task 6: Investigate + fix shared-axes (depends: 4, 5) [unspecified-high]
├── Task 7: Investigate + fix color-cycle (depends: 5) [unspecified-high]
├── Task 8: Investigate + fix step-plot (depends: 5) [unspecified-high]
├── Task 9: Investigate + fix barh (depends: 5) [unspecified-high]
├── Task 10: Investigate + fix twin-axes (depends: 4, 5) [unspecified-high]
├── Task 11: Investigate + fix custom-markers (depends: 5) [unspecified-high]
├── Task 12: Investigate + fix annotations (depends: 5) [unspecified-high]
├── Task 13: Investigate + fix imshow-heatmap grid alignment [unspecified-high]
├── Task 14: Investigate + fix remaining stragglers (depends: all Wave 2) [unspecified-high]

Wave FINAL (After ALL tasks — independent review, 4 parallel):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Full QA — run every example and verify SSIM (unspecified-high)
├── Task F4: Scope fidelity check (deep)

Critical Path: Task 1 → Task 4 → Task 6/10 → Task 14 → F1-F4
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 8 (Wave 3)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1    | —         | 2,3,4,5 |
| 2    | 1         | 6,14 |
| 3    | 1         | 6,14 |
| 4    | 1         | 6,10,14 |
| 5    | 1         | 6,7,8,9,10,11,12,14 |
| 6    | 4,5       | 14 |
| 7    | 5         | 14 |
| 8    | 5         | 14 |
| 9    | 5         | 14 |
| 10   | 4,5       | 14 |
| 11   | 5         | 14 |
| 12   | 5         | 14 |
| 13   | 1         | 14 |
| 14   | all Wave 2+3 | F1-F4 |
| F1-F4 | 14       | — |

### Agent Dispatch Summary

- **Wave 1**: **1** — T1 → `quick`
- **Wave 2**: **4** — T2 → `quick`, T3 → `quick`, T4 → `deep`, T5 → `unspecified-high`
- **Wave 3**: **8** — T6-T13 → `unspecified-high`
- **Wave 3b**: **1** — T14 → `unspecified-high`
- **FINAL**: **4** — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [x] 1. Update Makefile SSIM Threshold + Record Baseline

  **What to do**:
  - Change `THRESHOLD ?= 0.90` to `THRESHOLD ?= 0.95` in `Makefile` (line 9 or wherever THRESHOLD is defined — use `grep -n THRESHOLD Makefile` to find)
  - Run `make cl-images && make compare` to establish the failing baseline
  - Record all 27 SSIM scores and which 17 fail at 0.95

  **Must NOT do**:
  - Do NOT modify `tools/compare.py`
  - Do NOT modify any reference scripts or images

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (solo)
  - **Blocks**: Tasks 2, 3, 4, 5
  - **Blocked By**: None

  **References**:
  - `Makefile` — THRESHOLD variable definition (grep for `THRESHOLD`)
  - `tools/compare.py:293-294` — `--threshold` argument (default 0.90)
  - `comparison_report/summary.json` — current scores for baseline

  **Acceptance Criteria**:
  - [ ] Makefile THRESHOLD updated to 0.95
  - [ ] `make compare` runs (expected: exit code 1, 17 failures)
  - [ ] All 27 SSIM scores recorded in evidence

  **QA Scenarios**:
  ```
  Scenario: Verify threshold change and record baseline
    Tool: Bash
    Steps:
      1. grep -n 'THRESHOLD' Makefile → verify line shows 0.95
      2. make cl-images && make compare 2>&1 | tail -5 → expect "17 failed"
      3. .venv/bin/python3 -c "import json; d=json.load(open('comparison_report/summary.json')); [print(f'{e[\"name\"]}: {e[\"ssim\"]:.4f} {e[\"status\"]}') for e in sorted(d['examples'], key=lambda x: x['ssim'])]"
    Expected Result: 10 PASS, 17 FAIL at 0.95 threshold
    Evidence: .sisyphus/evidence/task-1-baseline.txt
  ```

  **Commit**: YES
  - Message: `chore: bump SSIM threshold from 0.90 to 0.95`
  - Files: `Makefile`

- [ ] 2. Fix Boxplot Whisker Linestyle (dashed → solid)

  **What to do**:
  - In `src/plotting/stats.lisp`, find all `:linestyle :dashed` in whisker line creation (lines ~124, ~132 for vertical, ~196, ~203 for horizontal)
  - Change all 4 instances from `:linestyle :dashed` to `:linestyle :solid`
  - This matches rcParams `boxplot.whiskerprops.linestyle = "-"` (solid) at `src/foundation/rcparams.lisp:86`
  - Regenerate boxplot and run SSIM check

  **Must NOT do**:
  - Do NOT change any other boxplot properties (median, caps, boxes, fliers)
  - Do NOT modify rcparams.lisp

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4, 5)
  - **Blocks**: Task 14
  - **Blocked By**: Task 1

  **References**:
  - `src/plotting/stats.lisp:124,132` — vertical boxplot whisker lines with `:linestyle :dashed`
  - `src/plotting/stats.lisp:196,203` — horizontal boxplot whisker lines with `:linestyle :dashed`
  - `src/foundation/rcparams.lisp:86` — `boxplot.whiskerprops.linestyle = "-"` (solid)
  - `reference_scripts/boxplot.py` — Python reference (uses default solid whiskers)

  **Acceptance Criteria**:
  - [ ] All 4 `:linestyle :dashed` in stats.lisp changed to `:linestyle :solid`
  - [ ] `sbcl --noinform --load examples/boxplot.lisp` succeeds
  - [ ] boxplot SSIM improved (currently 0.9354)
  - [ ] No regressions: run `make cl-images && make compare` — all 10 examples previously ≥ 0.95 still pass

  **QA Scenarios**:
  ```
  Scenario: Boxplot whiskers render as solid lines
    Tool: Bash
    Steps:
      1. grep -n ':linestyle :dashed' src/plotting/stats.lisp → expect 0 matches
      2. sbcl --noinform --load examples/boxplot.lisp → expect "Saved to"
      3. .venv/bin/python3 -c "from PIL import Image; import numpy as np; from skimage.metrics import structural_similarity as ssim; cl=np.array(Image.open('examples/boxplot.png').convert('RGB')); ref=np.array(Image.open('reference_images/boxplot.png').convert('RGB')); print('SSIM:', ssim(cl, ref, channel_axis=2, data_range=255))"
    Expected Result: SSIM > 0.9354 (improvement from current)
    Evidence: .sisyphus/evidence/task-2-boxplot-whiskers.txt

  Scenario: No regressions on previously-passing examples
    Tool: Bash
    Steps:
      1. make cl-images && make compare 2>&1 | grep -E 'stem-plot|colorbar-custom|simple-line|fill-between|stackplot|subplots|errorbar|gridspec-custom|figure-sizes|contour-lines'
    Expected Result: All 10 still show "PASS"
    Evidence: .sisyphus/evidence/task-2-regression-check.txt
  ```

  **Commit**: YES
  - Message: `fix(boxplot): change whisker linestyle from dashed to solid`
  - Files: `src/plotting/stats.lisp`

- [ ] 3. Fix Scatter Edgecolor and Linewidth Defaults

  **What to do**:
  - In `src/containers/axes.lisp`, find the `scatter` function (around line 62-111)
  - At line ~99: change `edgecolors` from the face color to `"face"` (which means match face color — check how PathCollection interprets this) OR check what matplotlib 3.8.4 actually does: when `color='darkorchid'` is passed, `scatter.edgecolors` rcParam is `"face"`, so edgecolors = facecolors. The current CL code already does this (sets edgecolors to effective-color). The REAL issue may be `linewidths`.
  - At line ~100: change `linewidths` from `0.5` to `0.0` (or check rcParams `lines.linewidth` default). In matplotlib 3.8.4, scatter linewidth is actually `rcParams['lines.linewidth'] * 0.25` or similar — investigate by comparing pixel-level rendering.
  - **IMPORTANT**: Before changing, do a pixel comparison of scatter points between CL and REF to understand the actual difference. The edge ring visibility is the key differentiator.
  - Run scatter example and check SSIM

  **Must NOT do**:
  - Do NOT change the scatter marker type
  - Do NOT change how the `s` (size) parameter is handled

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 2, 4, 5)
  - **Blocks**: Task 14
  - **Blocked By**: Task 1

  **References**:
  - `src/containers/axes.lisp:99-100` — scatter edgecolors and linewidths
  - `src/foundation/rcparams.lisp:330` — `scatter.edgecolors = "face"` (defined but unused)
  - `reference_scripts/scatter.py` — Python reference using `plt.scatter(xs, ys, s=25.0, color='darkorchid', alpha=0.6)`
  - `reference_images/scatter.png` — pixel reference for scatter dot rendering

  **Acceptance Criteria**:
  - [ ] Scatter SSIM improved from 0.9219
  - [ ] `sbcl --noinform --load examples/scatter.lisp` succeeds
  - [ ] No regressions on 10 examples currently ≥ 0.95

  **QA Scenarios**:
  ```
  Scenario: Scatter dots match reference rendering
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/scatter.lisp → expect "Saved to"
      2. .venv/bin/python3 -c "from PIL import Image; import numpy as np; from skimage.metrics import structural_similarity as ssim; cl=np.array(Image.open('examples/scatter.png').convert('RGB')); ref=np.array(Image.open('reference_images/scatter.png').convert('RGB')); print('SSIM:', ssim(cl, ref, channel_axis=2, data_range=255))"
    Expected Result: SSIM > 0.9219 (improvement)
    Evidence: .sisyphus/evidence/task-3-scatter-defaults.txt

  Scenario: Pixel comparison of scatter dot edges
    Tool: Bash
    Steps:
      1. .venv/bin/python3 -c "from PIL import Image; import numpy as np; cl=np.array(Image.open('examples/scatter.png').convert('RGB')); ref=np.array(Image.open('reference_images/scatter.png').convert('RGB')); diff=np.abs(cl.astype(int)-ref.astype(int)); big=diff.max(axis=2)>30; print(f'Big diff pixels: {big.sum()}, pct: {big.sum()/(cl.shape[0]*cl.shape[1])*100:.2f}%')"
    Expected Result: Big diff pixels decreased from pre-fix baseline
    Evidence: .sisyphus/evidence/task-3-scatter-pixels.txt
  ```

  **Commit**: YES
  - Message: `fix(scatter): use rcParams for edgecolors and linewidths`
  - Files: `src/containers/axes.lisp`

- [ ] 4. Fix Log-Scale Transform Pipeline (CRITICAL — Highest Impact)

  **What to do**:
  This is the highest-impact fix. The `trans-scale` field in `axes-base` is initialized to identity and NEVER incorporated into the data→display pipeline. For log-scale plots, data is rendered linearly instead of logarithmically.

  **Step 1: Fix `%update-trans-data` to incorporate `trans-scale`**
  - In `src/containers/axes-base.lisp`, function `%update-trans-data` (line ~201-211)
  - Currently: `data → viewLim→unit → transAxes = transData`
  - Should be: `data → trans-scale → viewLim→unit → transAxes = transData`
  - The composition should be: `compose(trans-scale, compose(view-to-unit, trans-axes))`
  - For linear scale (identity transform), this is a no-op

  **Step 2: Fix `log-transform` to support Y-axis**
  - In `src/containers/scale-transforms.lisp` (or wherever log-transform is defined), the current `transform-point` only transforms the X coordinate (slot 0)
  - For `axes-set-yscale :log`, we need the Y coordinate (slot 1) transformed
  - Approach: Have `axes-set-xscale` and `axes-set-yscale` set up the correct transform that applies to the right axis
  - One approach: create `log-y-transform` that transforms slot 1, or use a composition approach
  - Another approach: have `trans-scale` be a 2D transform where one axis is identity and the other is log

  **Step 3: Ensure `axes-set-yscale`/`axes-set-xscale` update `trans-scale`**
  - In `src/containers/axes-base.lisp`, find `axes-set-xscale` and `axes-set-yscale` (line ~473-487)
  - They must set `axes-base-trans-scale` to the appropriate transform AND call `%update-trans-data`

  **Step 4: Verify autoscale still works**
  - View limits must remain in DATA space (not display space)
  - The log transform maps data-space values through log() before the linear view→unit mapping
  - For log Y axis with data range [1, 148.4]: view limits stay as [1, 148.4], but the transform pipeline applies log10 before mapping to [0,1]

  **Step 5: Verify tick positions**
  - LogLocator already generates tick positions in data space (1, 10, 100, 1000...)
  - Once trans-data incorporates log, these will be correctly spaced in display space
  - Grid lines use the same tick positions, so they'll also auto-fix

  **Must NOT do**:
  - Do NOT change the transform pipeline for any purpose other than incorporating trans-scale
  - Do NOT modify how linear-scale plots work (identity trans-scale must be preserved as no-op)
  - Do NOT change tick locator or formatter logic

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  - Reason: This is the most architecturally complex fix — modifying the core transform pipeline

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 2, 3, 5)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 6, 10, 14
  - **Blocked By**: Task 1

  **References**:
  - `src/containers/axes-base.lisp:183-211` — `%setup-transforms`, `%update-trans-data` — CORE CHANGE LOCATION
  - `src/containers/axes-base.lisp:194-195` — `trans-scale` initialized to identity
  - `src/containers/axes-base.lisp:473-487` — `axes-set-xscale`, `axes-set-yscale` — must update trans-scale
  - `src/containers/scale.lisp:65-114` — LogScale class definition
  - `src/primitives/scale-transforms.lisp` — log-transform class (contains `transform-point` method with log)
  - `src/primitives/transforms.lisp` — `compose` function for transform composition
  - `examples/log-scale.lisp` — test example using `axes-set-yscale :log`
  - `reference_images/log-scale.png` — reference rendering (curve should appear nearly straight since y=exp(x) on log Y axis → log(exp(x))=x)

  **WHY Each Reference Matters**:
  - `axes-base.lisp:201-211` — This is WHERE the fix goes: trans-scale must be composed into trans-data
  - `scale-transforms.lisp` — The log-transform implementation must handle both X and Y axis application
  - `transforms.lisp:compose` — Pattern for composing affine transforms (needed for the pipeline fix)
  - `log-scale.lisp` — The example renders y=exp(x) with log Y axis — on a log scale this should be nearly linear

  **Acceptance Criteria**:
  - [ ] `%update-trans-data` incorporates `trans-scale` in composition
  - [ ] `axes-set-yscale :log` updates `trans-scale` and calls `%update-trans-data`
  - [ ] log-scale example renders correctly (curve should appear nearly linear)
  - [ ] log-scale SSIM dramatically improved from 0.9012 (target: ≥ 0.95)
  - [ ] ALL 10 examples currently ≥ 0.95 still pass (no regressions)
  - [ ] Linear-scale examples unchanged (identity trans-scale is no-op)

  **QA Scenarios**:
  ```
  Scenario: Log-scale curve renders correctly (nearly linear)
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/log-scale.lisp → expect "Saved to"
      2. .venv/bin/python3 -c "from PIL import Image; import numpy as np; from skimage.metrics import structural_similarity as ssim; cl=np.array(Image.open('examples/log-scale.png').convert('RGB')); ref=np.array(Image.open('reference_images/log-scale.png').convert('RGB')); print('SSIM:', ssim(cl, ref, channel_axis=2, data_range=255))"
    Expected Result: SSIM > 0.95 (was 0.9012)
    Evidence: .sisyphus/evidence/task-4-log-scale-ssim.txt

  Scenario: Linear-scale examples not regressed
    Tool: Bash
    Steps:
      1. make cl-images 2>&1 | tail -3
      2. .venv/bin/python3 -c "from PIL import Image; import numpy as np; from skimage.metrics import structural_similarity as ssim; [print(f'{n}: {ssim(np.array(Image.open(f\"examples/{n}.png\").convert(\"RGB\")), np.array(Image.open(f\"reference_images/{n}.png\").convert(\"RGB\")), channel_axis=2, data_range=255):.4f}') for n in ['simple-line','fill-between','contour-lines','errorbar','figure-sizes']]"
    Expected Result: All 5 scores ≥ 0.95 (same as baseline or better)
    Failure Indicators: Any score drops below 0.95
    Evidence: .sisyphus/evidence/task-4-regression-check.txt
  ```

  **Commit**: YES
  - Message: `fix(transforms): integrate trans-scale into data→display pipeline for log-scale support`
  - Files: `src/containers/axes-base.lisp`, `src/primitives/scale-transforms.lisp`

- [ ] 5. Fix Legend/Annotation Text Width (Heuristic → Actual Glyph Metrics)

  **What to do**:
  Replace the crude `(* 0.6d0 fontsize (length text))` text width heuristic with actual glyph metrics using the existing `get-text-extents` function from `src/rendering/font-manager.lisp`.

  **Step 1: Find all instances of the heuristic**
  - Use `grep -rn '0.6d0.*fontsize.*length\|0.6.*fontsize.*length' src/` to find all 4 occurrences:
    - `src/containers/legend.lisp:~225` — legend box sizing
    - `src/rendering/annotation.lisp:~127` — annotation text bbox
    - `src/rendering/fancy-arrow.lisp:~613` — arrow text positioning
    - Possibly a 4th location (search thoroughly)

  **Step 2: Wire font-loader into legend/annotation**
  - `get-text-extents` requires a `font-loader` argument (zpb-ttf font object)
  - The legend code currently has no access to a font-loader
  - Solution: Use `%get-font` from `src/backends/backend-vecto.lisp` to load the default font, or cache a font-loader accessible from the legend code
  - Alternatively: Add a utility function that loads the default font (DejaVu Sans) and calls `get-text-extents`
  - Check how `src/rendering/text-path.lisp` gets its font-loader — follow that pattern

  **Step 3: Replace each heuristic with actual measurement**
  - For each occurrence: call `get-text-extents(text, font-loader, fontsize)` → get width
  - This function already exists and handles kerning

  **Step 4: Verify legend sizing improved**
  - Run examples with legends: legend-styles, multi-line, scatter, custom-markers, histogram, etc.
  - Compare SSIM scores before and after

  **Must NOT do**:
  - Do NOT change the legend positioning algorithm (just the sizing)
  - Do NOT add new font loading infrastructure — reuse existing patterns
  - Do NOT modify how legend entries are drawn (only the bounding box computation)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - Reason: Moderate complexity — plumbing font-loader through legend code

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 2, 3, 4)
  - **Parallel Group**: Wave 2
  - **Blocks**: Tasks 6, 7, 8, 9, 10, 11, 12, 14
  - **Blocked By**: Task 1

  **References**:
  - `src/containers/legend.lisp:222-226` — PRIMARY: text width heuristic `(* 0.6d0 fontsize (length text))`
  - `src/rendering/annotation.lisp:127` — annotation text bbox heuristic
  - `src/rendering/fancy-arrow.lisp:613` — arrow text positioning heuristic
  - `src/rendering/font-manager.lisp:464-500` — `get-text-extents()` with kerning and proper glyph metrics
  - `src/rendering/text-path.lisp:74-101` — Example of how font-loader is used for text metrics
  - `src/backends/backend-vecto.lisp:374` — `%get-font()` for loading fonts
  - `data/fonts/ttf/DejaVuSans.ttf` — bundled default font

  **WHY Each Reference Matters**:
  - `legend.lisp:222-226` — The main heuristic to replace
  - `font-manager.lisp:464-500` — The correct function to call instead
  - `text-path.lisp:74-101` — Shows the pattern for loading a font and getting metrics
  - `backend-vecto.lisp:374` — Shows how to get a font-loader from the font system

  **Acceptance Criteria**:
  - [ ] No instances of `0.6d0.*fontsize.*(length` pattern remain in source
  - [ ] Legend text width computed using `get-text-extents` or equivalent actual metrics
  - [ ] legend-styles SSIM improved from 0.9384
  - [ ] Examples with legends show improved or stable SSIM
  - [ ] No regressions on 10 examples currently ≥ 0.95

  **QA Scenarios**:
  ```
  Scenario: Legend sizing matches reference
    Tool: Bash
    Steps:
      1. grep -rn '0\.6d0' src/containers/legend.lisp src/rendering/annotation.lisp src/rendering/fancy-arrow.lisp → expect 0 matches of the old heuristic
      2. make cl-images 2>&1 | tail -3
      3. .venv/bin/python3 -c "from PIL import Image; import numpy as np; from skimage.metrics import structural_similarity as ssim; [print(f'{n}: {ssim(np.array(Image.open(f\"examples/{n}.png\").convert(\"RGB\")), np.array(Image.open(f\"reference_images/{n}.png\").convert(\"RGB\")), channel_axis=2, data_range=255):.4f}') for n in ['legend-styles','multi-line','scatter','custom-markers','histogram','color-cycle']]"
    Expected Result: All scores improved or stable vs baseline
    Evidence: .sisyphus/evidence/task-5-legend-text-width.txt

  Scenario: No regressions
    Tool: Bash
    Steps:
      1. make compare 2>&1 | grep -c 'PASS' → expect ≥ 10 (no regression from baseline)
    Expected Result: Pass count ≥ baseline (10 at 0.95)
    Evidence: .sisyphus/evidence/task-5-regression-check.txt
  ```

  **Commit**: YES
  - Message: `fix(legend): replace text width heuristic with actual glyph metrics`
  - Files: `src/containers/legend.lisp`, `src/rendering/annotation.lisp`, `src/rendering/fancy-arrow.lisp`

- [ ] 6. Investigate + Fix shared-axes (SSIM 0.9056)

  **What to do**:
  - Run pixel-level SSIM analysis on shared-axes (regional SSIM shows: ylabel area=0.87, axes area=0.89)
  - The ylabel area is the worst region — investigate text positioning differences
  - The axes area differences may be from subplot spacing (TightLayoutEngine is a no-op stub)
  - Compare subplot spacing: check `hspace`/`wspace` parameters between CL and Python
  - If spacing is wrong, hardcode correct `subplots_adjust` parameters in the example to match reference, or fix the default spacing logic
  - Check if shared axis tick labels are being drawn on inner axes (they shouldn't be)

  **Must NOT do**:
  - Do NOT implement full TightLayoutEngine (too invasive)
  - Do NOT modify reference scripts

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with Tasks 7-13)
  - **Blocks**: Task 14
  - **Blocked By**: Tasks 4, 5

  **References**:
  - `examples/shared-axes.lisp` — CL example script
  - `reference_scripts/shared-axes.py` — Python reference
  - `src/containers/axes-base.lisp` — subplot spacing defaults
  - `src/containers/layout-engine.lisp:99-110` — TightLayoutEngine no-op stub

  **Acceptance Criteria**:
  - [ ] shared-axes SSIM ≥ 0.95 (currently 0.9056)
  - [ ] No regressions on subplots example (currently 0.9636)

  **QA Scenarios**:
  ```
  Scenario: shared-axes SSIM improved
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/shared-axes.lisp
      2. .venv/bin/python3 -c "from PIL import Image; import numpy as np; from skimage.metrics import structural_similarity as ssim; cl=np.array(Image.open('examples/shared-axes.png').convert('RGB')); ref=np.array(Image.open('reference_images/shared-axes.png').convert('RGB')); print('SSIM:', ssim(cl, ref, channel_axis=2, data_range=255))"
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-6-shared-axes.txt
  ```

  **Commit**: YES (groups with Wave 3)
  - Message: `fix(rendering): fix shared-axes subplot spacing and label positioning`

- [ ] 7. Investigate + Fix color-cycle (SSIM 0.9154)

  **What to do**:
  - Run pixel-level analysis on color-cycle to identify dominant SSIM differences
  - Likely candidate: legend sizing (should be fixed by Task 5) or line rendering differences
  - After Wave 2 fixes are applied, re-check SSIM — it may already pass 0.95
  - If still below 0.95, investigate: line colors matching, legend position, axis limits, tick positions

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14
  - **Blocked By**: Task 5

  **References**:
  - `examples/color-cycle.lisp` — CL example
  - `reference_scripts/color-cycle.py` — Python reference

  **Acceptance Criteria**:
  - [ ] color-cycle SSIM ≥ 0.95 (currently 0.9154)

  **QA Scenarios**:
  ```
  Scenario: color-cycle SSIM check
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/color-cycle.lisp
      2. SSIM check as above
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-7-color-cycle.txt
  ```

  **Commit**: YES (groups with Wave 3)

- [ ] 8. Investigate + Fix step-plot (SSIM 0.9177)

  **What to do**:
  - Investigate step rendering: does CL implement `drawstyle='steps-mid'` or similar?
  - Compare step positions pixel-by-pixel with reference
  - Check if step-plot uses a legend (legend fix from Task 5 may help)
  - After Wave 2 fixes, re-check — may already pass

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14
  - **Blocked By**: Task 5

  **References**:
  - `examples/step-plot.lisp` — CL example
  - `reference_scripts/step-plot.py` — Python reference
  - `src/rendering/lines.lisp` — Line2D rendering (check for step/drawstyle support)

  **Acceptance Criteria**:
  - [ ] step-plot SSIM ≥ 0.95 (currently 0.9177)

  **QA Scenarios**:
  ```
  Scenario: step-plot SSIM check
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/step-plot.lisp
      2. SSIM check
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-8-step-plot.txt
  ```

  **Commit**: YES (groups with Wave 3)

- [ ] 9. Investigate + Fix barh (SSIM 0.9221)

  **What to do**:
  - Investigate bar positioning/sizing differences in horizontal bar chart
  - Compare bar positions, widths, colors pixel-by-pixel
  - Check if legend sizing (Task 5) or sticky edges are involved
  - After Wave 2 fixes, re-check

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14
  - **Blocked By**: Task 5

  **References**:
  - `examples/barh.lisp` — CL example
  - `reference_scripts/barh.py` — Python reference
  - `src/containers/axes.lisp` — `barh()` function

  **Acceptance Criteria**:
  - [ ] barh SSIM ≥ 0.95 (currently 0.9221)

  **QA Scenarios**:
  ```
  Scenario: barh SSIM check
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/barh.lisp
      2. SSIM check
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-9-barh.txt
  ```

  **Commit**: YES (groups with Wave 3)

- [ ] 10. Investigate + Fix twin-axes (SSIM 0.9260)

  **What to do**:
  - Investigate dual-axis rendering differences
  - After log-scale transform fix (Task 4), check if twin-axes uses any scale that would benefit
  - Check axis label positioning on secondary Y axis
  - Compare tick positions and grid alignment

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14
  - **Blocked By**: Tasks 4, 5

  **References**:
  - `examples/twin-axes.lisp` — CL example
  - `reference_scripts/twin-axes.py` — Python reference
  - `src/containers/axes-base.lisp` — twin axes support

  **Acceptance Criteria**:
  - [ ] twin-axes SSIM ≥ 0.95 (currently 0.9260)

  **QA Scenarios**:
  ```
  Scenario: twin-axes SSIM check
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/twin-axes.lisp
      2. SSIM check
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-10-twin-axes.txt
  ```

  **Commit**: YES (groups with Wave 3)

- [ ] 11. Investigate + Fix custom-markers (SSIM 0.9266)

  **What to do**:
  - Compare marker rendering pixel-by-pixel: size, shape, fill
  - Check if marker size scaling matches matplotlib's points² convention
  - The marker size may be computed differently: matplotlib uses `sqrt(s)` for marker diameter, CL may use `s` directly
  - Check `src/rendering/markers.lisp` for size computation
  - After legend fix (Task 5), re-check — legend differences may be the main issue

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14
  - **Blocked By**: Task 5

  **References**:
  - `examples/custom-markers.lisp` — CL example
  - `reference_scripts/custom-markers.py` — Python reference
  - `src/rendering/markers.lisp` — marker path generation and sizing

  **Acceptance Criteria**:
  - [ ] custom-markers SSIM ≥ 0.95 (currently 0.9266)

  **QA Scenarios**:
  ```
  Scenario: custom-markers SSIM check
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/custom-markers.lisp
      2. SSIM check
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-11-custom-markers.txt
  ```

  **Commit**: YES (groups with Wave 3)

- [ ] 12. Investigate + Fix annotations (SSIM 0.9333)

  **What to do**:
  - Compare annotation arrow geometry pixel-by-pixel with reference
  - Check arrow shrinkA/shrinkB defaults in CL vs matplotlib 3.8.4
  - Check connectionstyle parameters (arc3 curvature radius)
  - The annotation text bbox may also differ (uses the 0.6× heuristic — should be fixed by Task 5)
  - After Task 5, re-check — text bbox fix may be sufficient

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14
  - **Blocked By**: Task 5

  **References**:
  - `examples/annotations.lisp` — CL example
  - `reference_scripts/annotations.py` — Python reference
  - `src/rendering/annotation.lisp` — annotation class with arrow support
  - `src/rendering/fancy-arrow.lisp` — arrow and connection styles

  **Acceptance Criteria**:
  - [ ] annotations SSIM ≥ 0.95 (currently 0.9333)

  **QA Scenarios**:
  ```
  Scenario: annotations SSIM check
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/annotations.lisp
      2. SSIM check
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-12-annotations.txt
  ```

  **Commit**: YES (groups with Wave 3)

- [ ] 13. Investigate + Fix imshow-heatmap Grid Alignment (SSIM 0.9379)

  **What to do**:
  - Compare grid line positions with image cell boundaries pixel-by-pixel
  - Check if grid lines are aligned to integer data coordinates (0, 1, 2, ..., 9)
  - The extent was changed to `(-0.5, w-0.5, -0.5, h-0.5)` in the recent fix — verify grid lines align with cell centers vs edges
  - Check if colorbar positioning matches reference
  - After other systemic fixes, re-check — may already pass

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 14
  - **Blocked By**: Task 1

  **References**:
  - `examples/imshow-heatmap.lisp` — CL example
  - `reference_scripts/imshow-heatmap.py` — Python reference
  - `src/plotting/image.lisp` — imshow implementation (recently modified for aspect ratio)

  **Acceptance Criteria**:
  - [ ] imshow-heatmap SSIM ≥ 0.95 (currently 0.9379)

  **QA Scenarios**:
  ```
  Scenario: imshow-heatmap SSIM check
    Tool: Bash
    Steps:
      1. sbcl --noinform --load examples/imshow-heatmap.lisp
      2. SSIM check
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-13-imshow-heatmap.txt
  ```

  **Commit**: YES (groups with Wave 3)

- [ ] 14. Fix Remaining Stragglers (After All Systemic + Specific Fixes)

  **What to do**:
  - After ALL Tasks 2-13 are complete, run full `make cl-images && make compare` with threshold 0.95
  - Identify any examples STILL below 0.95
  - For each remaining example, do targeted pixel analysis to find the specific SSIM-killing difference
  - Apply targeted fixes
  - This task covers: histogram (0.9375), pie-chart (0.9390), filled-contour (0.9414), bar-chart (0.9467), multi-line (0.9312), and any others still failing
  - Some of these may already pass after systemic fixes — only fix what's still below 0.95

  **Must NOT do**:
  - Do NOT modify reference scripts
  - Do NOT lower the threshold

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on all previous tasks)
  - **Parallel Group**: Sequential (Wave 3b, after all Wave 3)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 2-13

  **References**:
  - All example files in `examples/` and `reference_scripts/`
  - `comparison_report/summary.json` — current scores
  - All source files in `src/` as needed per example

  **Acceptance Criteria**:
  - [ ] `make compare` with THRESHOLD=0.95 exits 0 (ALL 27 pass)
  - [ ] All 27 SSIM scores ≥ 0.95
  - [ ] Mean SSIM ≥ 0.95

  **QA Scenarios**:
  ```
  Scenario: All 27 examples pass at 0.95
    Tool: Bash
    Steps:
      1. make cl-images && make compare 2>&1 | tail -10
      2. .venv/bin/python3 -c "import json; d=json.load(open('comparison_report/summary.json')); print(f'Pass: {d[\"overall\"][\"passed\"]}/27, Min: {d[\"overall\"][\"min_ssim\"]:.4f}, Mean: {d[\"overall\"][\"mean_ssim\"]:.4f}'); assert d['overall']['failed']==0, 'FAILURES REMAIN'"
    Expected Result: Pass: 27/27, Min: ≥0.9500, Mean: ≥0.9500
    Failure Indicators: Any example below 0.95
    Evidence: .sisyphus/evidence/task-14-final-scores.txt

  Scenario: Detailed score listing
    Tool: Bash
    Steps:
      1. .venv/bin/python3 -c "import json; d=json.load(open('comparison_report/summary.json')); [print(f'{e[\"name\"]:25s} {e[\"ssim\"]:.4f} {e[\"status\"]}') for e in sorted(d['examples'], key=lambda x: x['ssim'])]"
    Expected Result: All 27 show PASS
    Evidence: .sisyphus/evidence/task-14-all-scores.txt
  ```

  **Commit**: YES
  - Message: `fix(rendering): final tuning — all 27 examples at SSIM ≥ 0.95`
  - Files: various as needed

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists. For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in `.sisyphus/evidence/`. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `make compare THRESHOLD=0.95`. Check all changed files for: empty catches, `as any`, commented-out code, unused imports, debug prints. Verify no AI-slop: excessive comments, over-abstraction, generic names.
  Output: `Compare [PASS/FAIL] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Full QA — run every example and verify SSIM** — `unspecified-high`
  Run `make cl-images && make compare`. Extract all 27 SSIM scores. Verify: ALL ≥ 0.95, mean ≥ 0.95, no regressions from baseline. Run each of the 6 user-flagged examples individually and capture pixel analysis. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [27/27 pass] | Mean SSIM [value] | Min SSIM [value] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (`git log`/`git diff`). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **After Task 1**: `chore: bump SSIM threshold from 0.90 to 0.95`
- **After Task 2**: `fix(boxplot): change whisker linestyle from dashed to solid`
- **After Task 3**: `fix(scatter): use rcParams for edgecolors and linewidths`
- **After Task 4**: `fix(transforms): integrate trans-scale into data→display pipeline for log-scale support`
- **After Task 5**: `fix(legend): replace text width heuristic with actual glyph metrics`
- **After Tasks 6-13**: `fix(rendering): example-specific fixes for SSIM ≥ 0.95` (group commit)
- **After Task 14**: `fix(rendering): final tuning for remaining SSIM stragglers`

---

## Success Criteria

### Verification Commands
```bash
make cl-images && make compare  # Expected: exit code 0, 27/27 passed
.venv/bin/python3 -c "import json; d=json.load(open('comparison_report/summary.json')); print(f'Pass: {d[\"overall\"][\"passed\"]}/27, Min: {d[\"overall\"][\"min_ssim\"]:.4f}, Mean: {d[\"overall\"][\"mean_ssim\"]:.4f}')"
# Expected: Pass: 27/27, Min: ≥0.9500, Mean: ≥0.9500
```

### Final Checklist
- [ ] All 27 examples SSIM ≥ 0.95
- [ ] `make compare` exit code 0
- [ ] No regressions from current scores (10 examples already ≥ 0.95 stay there)
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
