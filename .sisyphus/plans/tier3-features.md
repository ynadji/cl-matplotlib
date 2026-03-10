# Tier 3 Features: Violin, Quiver, Polar, Streamplot

## TL;DR

> **Quick Summary**: Implement 4 new plot types in cl-matplotlib — violin plots, quiver fields, polar projection, and streamplots — with gallery examples for each, ordered by effort-to-unlock ratio.
> 
> **Deliverables**:
> - Violin plots: GaussianKDE algorithm + violinplot() function + 3 gallery examples
> - Quiver: QuiverCollection class + quiver() function + 4 gallery examples
> - Polar: PolarAxes subclass + transform pipeline + axes projection dispatch + 6 gallery examples
> - Streamplot: RK12 integrator + streamplot() function + 2 gallery examples
> - Unit tests for all new math (KDE, transforms, geometry)
> - Zero regressions on existing 64 examples
> 
> **Estimated Effort**: XL
> **Parallel Execution**: YES — 7 waves
> **Critical Path**: Violin impl → Violin examples → Quiver impl → Quiver examples → Polar transforms → Polar axes → Polar examples → Streamplot → Final verification

---

## Context

### Original Request
User wants to implement Tier 3 features from the gallery-expansion plan: polar projection (~6 examples), violin plots (~3 examples), quiver (~4 examples), and streamplot (~2 examples). All four features, ordered by unlock ratio.

### Interview Summary
**Key Discussions**:
- Prioritize by unlock ratio: violin (BEST) → quiver (GOOD) → polar (MODERATE) → streamplot (WORST)
- Full PolarAxes with circular grid, radial ticks, theta labels — not simplified
- Same test strategy as Tier 1-2: tests-after, SSIM comparison, agent-executed QA
- Include streamplot despite worst ratio — user wants maximum coverage

**Research Findings**:
- Transform system is fully extensible — composite-generic-transform supports non-affine composition
- Axes are hardcoded rectangular — need simple projection dispatch (not registry)
- PolyCollection exists and is proven by contour — extend for QuiverCollection
- FancyArrowPatch with 9 arrow styles exists — reusable for streamplot
- path-arc (path.lisp:957-1023) generates cubic Bézier arc approximations — reusable for polar grid
- Boxplot pattern (stats.lisp:58-281) is the exact template for violin
- No existing polar, KDE, quiver, or streamplot code

### Metis Review
**Identified Gaps** (addressed):
- Polar surface is larger than 8 methods — actually 12-15 functions need override. Plan adjusted for full scope.
- PolarAxes must subclass axes-base directly (not mpl-axes) — mpl-axes methods assume rectangular coords
- Must NOT modify axes-base.lisp class definitions — add new classes in new files only
- Projection dispatch via simple `case` in add-subplot/subplots — no factory/registry pattern
- KDE edge cases: single data point, all-identical values, empty datasets — must handle gracefully
- Quiver zero-length arrows and NaN/Inf — must skip gracefully
- Polar theta wrapping requires path tessellation before transform
- .asd/packages.lisp/pyplot.lisp updates must be part of each feature's definition of done

---

## Work Objectives

### Core Objective
Implement 4 new plot types (violin, quiver, polar, streamplot) with gallery examples, expanding from 64 to ~79 examples while maintaining zero regressions.

### Concrete Deliverables
- `src/plotting/violin.lisp` — GaussianKDE + violinplot function
- `src/rendering/quiver.lisp` — QuiverCollection class
- `src/plotting/quiver.lisp` — quiver() function
- `src/primitives/polar-transforms.lisp` — PolarTransform + InvertedPolarTransform + PolarAffine
- `src/containers/polar.lisp` — PolarAxes subclass with full rendering
- `src/algorithms/streamplot.lisp` — RK12 integrator + StreamMask + streamplot function
- 15 new gallery examples (3 + 4 + 6 + 2) with matching Python reference scripts
- Unit tests for KDE, polar transforms, quiver geometry
- .asd, packages.lisp, pyplot.lisp updates for each feature

### Definition of Done
- [ ] `jq '.overall.failed' comparison_report/summary.json` → `1` (color-cycle only, pre-existing)
- [ ] `jq '.overall.total' comparison_report/summary.json` → `≥ 79`
- [ ] All unit tests pass on SBCL
- [ ] All new files committed and tracked in git

### Must Have
- All new src/ code uses `double-float` exclusively for numerical computation
- Full SSIM regression after EACH feature (not just at the end)
- Each feature delivers implementation + examples + tests together (vertical slice)
- .asd, packages.lisp, pyplot.lisp updates included in each feature's commit
- PolarAxes subclasses `axes-base` directly (not `mpl-axes`)
- Projection dispatch via `:projection :polar` keyword in add-subplot/subplots
- All examples use `defpackage #:example` pattern
- All Python reference scripts include `matplotlib.use('Agg')`, `savefig.dpi = 100`, `text.hinting = 'none'`

### Must NOT Have (Guardrails)
- Do NOT modify `axes-base.lisp`, `axes.lisp`, `axis.lisp`, `spines.lisp` class DEFINITIONS (only add-subplot/subplots dispatch)
- Do NOT modify `tools/compare.py`
- Do NOT modify `src/pyplot/pyplot.lisp` line 242 (hist linewidth=1.0)
- Do NOT lower SSIM threshold below 0.95
- Do NOT implement QuiverKey, half-violins, polar-bar, polar-scatter, polar-contour, polar-fill-between
- Do NOT implement start_points, broken_streamlines for streamplot
- Do NOT implement interactive pan/zoom on polar
- Do NOT implement partial-polar wedge plots, set_rorigin, set_theta_zero_location
- Do NOT create abstract projection registry — simple `case` dispatch only
- Do NOT use single-float for numerical computation
- Do NOT introduce new CL library dependencies

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (208 FiveAM tests, SSIM comparison pipeline)
- **Automated tests**: Tests-after for src/ changes
- **Framework**: FiveAM (existing) + SSIM comparison
- **Unit tests required**: YES for new math (KDE, transforms, geometry)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Primary QA mechanism: SSIM comparison via `tools/compare.py`.
Evidence saved to `.sisyphus/evidence/task-{N}-*.{ext}`.

### Render Commands (CANONICAL)
```bash
# Single example
setarch $(uname -m) -R ros run -- --noinform --load examples/{name}.lisp 2>/dev/null

# Generate reference
.venv/bin/python reference_scripts/{name}.py

# Full SSIM comparison
.venv/bin/python tools/compare.py --reference reference_images/ --actual examples/ --threshold 0.95 --output comparison_report/

# Verify
jq '.overall | {total, passed, failed}' comparison_report/summary.json
```

### Regression Baseline
- 64 existing examples, 63 passing (color-cycle at 0.9462 = known limitation)
- 208 unit tests passing
- Fragile examples to monitor: step-plot (0.955), histogram-multi (0.951)

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — violin implementation + examples):
├── Task 1: Implement GaussianKDE + violinplot() [unspecified-high]
├── Task 2: Violin gallery examples (3 examples) [unspecified-high]

Wave 2 (After Wave 1 — quiver implementation + examples):
├── Task 3: Implement QuiverCollection + quiver() [unspecified-high]
├── Task 4: Quiver gallery examples (4 examples) [unspecified-high]

Wave 3 (After Wave 2 — polar foundation):
├── Task 5: Implement PolarTransform + PolarAffine [unspecified-high]
├── Task 6: Implement PolarAxes class + grid/spine rendering [unspecified-high]

Wave 4 (After Wave 3 — polar integration + examples):
├── Task 7: Polar projection dispatch + pyplot integration [unspecified-high]
├── Task 8: Polar gallery examples (6 examples) [unspecified-high]

Wave 5 (After Wave 4 — streamplot):
├── Task 9: Implement RK12 integrator + StreamMask + streamplot() [unspecified-high]
├── Task 10: Streamplot gallery examples (2 examples) [unspecified-high]

Wave 6 (After Wave 5 — checkpoint):
├── Task 11: Final regression + checkpoint commit [quick]

Wave FINAL (After ALL tasks — independent review, 4 parallel):
├── Task F1: Plan compliance audit [oracle]
├── Task F2: Code quality review [unspecified-high]
├── Task F3: Full SSIM QA [unspecified-high]
├── Task F4: Scope fidelity check [unspecified-high]

Critical Path: T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9 → T10 → T11 → F1-F4
Max Concurrent: 4 (Final wave)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | — | 2 |
| 2 | 1 | 3 |
| 3 | 2 | 4 |
| 4 | 3 | 5 |
| 5 | 4 | 6 |
| 6 | 5 | 7 |
| 7 | 6 | 8 |
| 8 | 7 | 9 |
| 9 | 8 | 10 |
| 10 | 9 | 11 |
| 11 | 10 | F1-F4 |
| F1-F4 | 11 | — |

### Agent Dispatch Summary

- **Wave 1**: 2 tasks — T1-T2 → `unspecified-high`
- **Wave 2**: 2 tasks — T3-T4 → `unspecified-high`
- **Wave 3**: 2 tasks — T5-T6 → `unspecified-high`
- **Wave 4**: 2 tasks — T7-T8 → `unspecified-high`
- **Wave 5**: 2 tasks — T9-T10 → `unspecified-high`
- **Wave 6**: 1 task — T11 → `quick`
- **FINAL**: 4 tasks — F1 → `oracle`, F2-F4 → `unspecified-high`

---

## TODOs

> Implementation + Test = ONE Task. Never separate.
> EVERY task MUST have: Recommended Agent Profile + Parallelization info + QA Scenarios.

- [x] 1. Implement GaussianKDE + violinplot()

  **What to do**:
  - Create `src/plotting/violin.lisp` with:
    - `gaussian-kde` function: Scott's rule bandwidth (`h = n^(-1/5) * σ`), Gaussian kernel evaluation at grid points. Accept dataset (list of doubles), return density values at evaluation points. Use `double-float` exclusively.
    - `violinplot` function following boxplot pattern (stats.lisp:58-281): accept axes + list of datasets + keyword args
    - For each dataset: compute KDE, create symmetric Polygon patch via fill-between pattern (forward vertices + reversed backward), add median line via Line-2D
    - Support kwargs: `:positions`, `:widths` (default 0.5), `:vert` (default t), `:showmedians` (default t), `:showextrema` (default t)
    - Edge cases: skip nil/empty datasets gracefully, clamp bandwidth minimum for identical values
  - Add `violinplot` pyplot wrapper to `src/pyplot/pyplot.lisp`
  - Update `packages.lisp` with new exports
  - Update `.asd` file with new component
  - Add unit tests: KDE of N(0,1) samples peaks near 0.3989, bandwidth scales correctly, empty input doesn't crash

  **Must NOT do**:
  - Do NOT implement half-violins (side='low'/'high'), grouped violins, split violins
  - Do NOT implement bw_method parameter — use Scott's rule only
  - Do NOT add scipy or any external dependency

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 2
  - **Blocked By**: None

  **References**:
  **Pattern References**:
  - `src/plotting/stats.lisp:58-281` — Boxplot implementation: exact pattern to follow for function structure, artist creation, axes integration
  - `src/containers/axes.lisp:254-302` — fill-between: Polygon construction with forward + reversed vertices for symmetric shapes
  - `src/rendering/patches.lisp:191-221` — Polygon class with cached paths

  **API/Type References**:
  - `src/pyplot/pyplot.lisp` — pyplot wrapper pattern (defun + gca + delegate)
  - `src/rendering/lines.lisp` — Line-2D for median/extrema lines

  **External References**:
  - matplotlib `mlab.py:828-870` — GaussianKDE implementation with Scott's rule
  - matplotlib `axes/_axes.py:8976-9273` — violinplot/violin implementation

  **Acceptance Criteria**:
  - [ ] `(violinplot ax (list data1 data2 data3))` renders 3 violin shapes
  - [ ] KDE unit test: 1000 samples from N(0,1) → peak density within 5% of 0.3989
  - [ ] Unit tests pass: `ros run -- --noinform --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --eval '(uiop:quit)'`
  - [ ] Full SSIM regression: `jq '.overall.failed' comparison_report/summary.json` → `1` (color-cycle only)

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: Violin renders without crash
    Tool: Bash
    Steps:
      1. Create minimal test script: (figure) (violinplot (list data)) (savefig "test.png")
      2. Render with ros run
      3. Verify PNG exists and is non-empty
    Expected Result: PNG file > 0 bytes, no errors
    Evidence: .sisyphus/evidence/task-1-violin-render.png

  Scenario: No regression on existing 64 examples
    Tool: Bash
    Steps:
      1. Run full SSIM comparison
      2. jq '.overall | {total, passed, failed}' comparison_report/summary.json
    Expected Result: total=64, failed≤1 (color-cycle only)
    Evidence: .sisyphus/evidence/task-1-regression.json
  ```

  **Commit**: YES
  - Message: `feat(plotting): add violin plots with GaussianKDE`
  - Files: `src/plotting/violin.lisp`, `src/pyplot/pyplot.lisp`, `packages.lisp`, `.asd`, test files

- [x] 2. Violin Gallery Examples (3 examples)

  **What to do**:
  Write Python reference scripts and CL example scripts for:
  1. **violin-basic** — Basic violin plot of 3 datasets with different distributions (normal, uniform, bimodal)
  2. **violin-comparison** — Side-by-side violin + boxplot comparison of same data
  3. **violin-styled** — Styled violins with custom colors, widths, and horizontal orientation

  For each: create `reference_scripts/{name}.py` + `examples/{name}.lisp`, generate reference, render CL, verify SSIM ≥ 0.95.

  **Must NOT do**:
  - Do NOT modify src/ files
  - Do NOT use external data

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:
  - Task 1 implementation
  - `reference_scripts/boxplot.py` / `examples/boxplot.lisp` — Similar statistical plot pattern
  - matplotlib gallery: `violinplot.py`, `customized_violin.py`

  **Acceptance Criteria**:
  - [ ] 3 new example pairs created
  - [ ] Full SSIM: total=67, failed≤1 (color-cycle only)
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: All 3 violin examples pass SSIM
    Tool: Bash
    Steps:
      1. Generate 3 references, render 3 CL examples
      2. Run full SSIM comparison
      3. Verify each new example ≥ 0.95
    Expected Result: 3/3 new examples pass
    Evidence: .sisyphus/evidence/task-2-violin-examples.json
  ```

  **Commit**: YES
  - Message: `feat(examples): add violin plot gallery examples`

- [x] 3. Implement QuiverCollection + quiver()

  **What to do**:
  - Create `src/rendering/quiver.lisp` with `quiver-collection` class extending `poly-collection`:
    - Store X, Y position arrays and U, V vector arrays
    - Override `collection-get-paths` to generate arrow polygon vertices
    - Arrow geometry: 7-vertex polygon (tip, head-right, shaft-right, tail-right, tail-left, shaft-left, head-left)
    - Default proportions matching matplotlib: headwidth=3, headlength=5, headaxislength=4.5 (relative to shaft width)
    - Rotation via complex multiplication: `(x + iy) * e^(iθ)` where θ = atan2(V, U)
    - Deferred initialization: compute span and width at draw() time from axes bbox
    - Autoscaling: width = 0.06 * span / sqrt(N), scale from mean magnitude
  - Create `src/plotting/quiver.lisp` with `quiver` function:
    - Parse args: (ax U V), (ax X Y U V), optional C for colors
    - Create QuiverCollection, add to axes, update data limits
    - Support kwargs: `:scale`, `:width`, `:color`, `:alpha`, `:pivot` (:tail/:middle/:tip)
  - Add `quiver` pyplot wrapper
  - Update packages.lisp, .asd, pyplot.lisp
  - Handle edge cases: zero-length arrows (skip), NaN/Inf in U/V (skip), single arrow
  - Unit tests: arrow at 0° produces expected vertices, arrow at 90° rotated correctly

  **Must NOT do**:
  - Do NOT implement QuiverKey (legend key for arrow scale)
  - Do NOT implement barbs or 3D quiver
  - Do NOT implement `angles='xy'` mode

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 4
  - **Blocked By**: Task 2

  **References**:
  **Pattern References**:
  - `src/rendering/collections.lisp:356-450` — PolyCollection: base class to extend
  - `src/rendering/collections.lisp:132-203` — Collection draw method: per-item colors/transforms
  - `src/plotting/contour.lisp:199-222` — PolyCollection usage in production

  **API/Type References**:
  - `src/rendering/collections.lisp:25-77` — Collection base: offsets, facecolors, edgecolors
  - matplotlib `quiver.py:489-710` — Quiver class: `_h_arrows()`, `_make_verts()`, draw()

  **Acceptance Criteria**:
  - [ ] `(quiver ax u-array v-array)` renders arrow field
  - [ ] Arrow geometry unit test: horizontal arrow at 0° has correct vertex positions
  - [ ] Zero-length arrows are skipped without crash
  - [ ] Full SSIM regression: failed≤1

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: Quiver renders arrow field
    Tool: Bash
    Steps:
      1. Create test: uniform grid of arrows pointing right
      2. Render, verify PNG exists
    Expected Result: Visible arrows in grid pattern
    Evidence: .sisyphus/evidence/task-3-quiver-render.png

  Scenario: No regression
    Tool: Bash
    Steps:
      1. Full SSIM comparison
    Expected Result: failed≤1
    Evidence: .sisyphus/evidence/task-3-regression.json
  ```

  **Commit**: YES
  - Message: `feat(plotting): add quiver vector field plots`

- [x] 4. Quiver Gallery Examples (4 examples)

  **What to do**:
  Write Python reference scripts and CL example scripts for:
  1. **quiver-basic** — Simple uniform arrow field on a grid
  2. **quiver-colored** — Arrows colored by magnitude using colormap
  3. **quiver-scaled** — Arrows with explicit scale parameter showing wind-like patterns
  4. **quiver-gradient** — Gradient field of a mathematical function (e.g., f(x,y) = x² + y²)

  **Must NOT do**: Do NOT modify src/. Do NOT use external data.

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2
  - **Blocks**: Task 5
  - **Blocked By**: Task 3

  **Acceptance Criteria**:
  - [ ] 4 new example pairs created
  - [ ] Full SSIM: total=71, failed≤1
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: All 4 quiver examples pass SSIM
    Tool: Bash
    Steps:
      1. Generate 4 references, render 4 CL, compare
    Expected Result: 4/4 pass
    Evidence: .sisyphus/evidence/task-4-quiver-examples.json
  ```

  **Commit**: YES
  - Message: `feat(examples): add quiver vector field gallery examples`

- [x] 5. Implement PolarTransform + PolarAffine + InvertedPolarTransform

  **What to do**:
  - Create `src/primitives/polar-transforms.lisp` with three transform classes:
    - `polar-transform` (subclass of `transform`):
      - `transform-point`: takes `(theta, r)` → `(r * cos(theta), r * sin(theta))`. Input theta is in RADIANS.
      - `transform-path`: For constant-r segments (straight lines where r0 ≈ r1), interpolate using `path-arc` to produce cubic Bézier arcs (reuse existing `path-arc` from path.lisp:957-1023). For non-constant-r segments, subdivide and transform vertices individually.
      - Detection: a segment is "constant-r" if `|r1 - r0| < epsilon * max(|r0|, |r1|, 1)` with epsilon ~ 1e-6.
    - `inverted-polar-transform` (subclass of `transform`):
      - `transform-point`: takes `(x, y)` → `(atan2(y, x) mod 2π, hypot(x, y))`
      - `invert` method returns a `polar-transform`
    - `polar-affine` (subclass of `affine-2d`):
      - Scale factor `0.5 / r_max`, translate `(0.5, 0.5)` — maps unit circle to center of axes bbox
      - Provide `polar-affine-update` to recompute when r_max changes (called during autoscale)
  - All numerical computation uses `double-float`
  - `invert` on `polar-transform` returns `inverted-polar-transform`
  - Update `packages.lisp` with new exports
  - Update `.asd` file with new component
  - Add unit tests:
    - Round-trip: polar→inverted→original for sample points (0,1), (π/2,1), (π,2), (3π/2,0.5)
    - `transform-point` at θ=0, r=1 → (1.0, 0.0)
    - `transform-point` at θ=π/2, r=1 → (0.0, 1.0)
    - `transform-path` on a constant-r horizontal line produces arc (verify Bézier codes present)
    - PolarAffine at center maps correctly

  **Must NOT do**:
  - Do NOT implement theta offset or direction (counter-clockwise only, 0=right)
  - Do NOT implement `set_rorigin` or `set_theta_zero_location`
  - Do NOT modify existing transform classes in transforms.lisp

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Non-trivial numerical transforms with arc interpolation requiring careful math
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 6
  - **Blocked By**: Task 4

  **References**:
  **Pattern References**:
  - `src/primitives/scale-transforms.lisp:11-63` — LogTransform: exact class structure to follow for transform-point, transform-path, invert
  - `src/primitives/transforms.lisp:1-50` — Transform base class: slots, protocols, generic functions
  - `src/primitives/path.lisp:957-1023` — `path-arc`: generates cubic Bézier arc approximations on unit circle — REUSE this for constant-r arc interpolation
  - `src/primitives/transforms.lisp:60-130` — `affine-2d` class: subclass this for PolarAffine

  **API/Type References**:
  - `src/primitives/transforms.lisp` — `transform-point`, `transform-path`, `invert` generic functions
  - `src/primitives/path.lisp:23-55` — `mpl-path` struct: vertices (Nx2 double-float array), codes (N array of path codes)
  - `src/primitives/path.lisp:5-20` — Path code constants: `+moveto+`, `+lineto+`, `+curve4+`, `+closepoly+`

  **External References**:
  - matplotlib `projections/polar.py:30-120` — PolarTransform and InvertedPolarTransform
  - matplotlib `projections/polar.py:120-180` — PolarAffine transform

  **WHY Each Reference Matters**:
  - `scale-transforms.lisp` — Shows the CL idiom for transform classes (slots, initialize-instance, method signatures). Follow this EXACTLY.
  - `path-arc` — Already generates unit-circle Bézier arcs. For constant-r polar segments, scale the path-arc output by r and you get the correct curved path.
  - `affine-2d` — PolarAffine is conceptually an affine: scale + translate. Subclassing avoids reimplementation.

  **Acceptance Criteria**:
  - [ ] Round-trip test passes: transform → invert → compare to original within 1e-10
  - [ ] `(transform-point polar-tf (list 0.0d0 1.0d0))` → `#(1.0d0 0.0d0)` (θ=0, r=1)
  - [ ] `(transform-point polar-tf (list (/ pi 2) 1.0d0))` → `#(~0.0d0 1.0d0)` (θ=π/2, r=1)
  - [ ] Constant-r path through polar-transform produces Bézier arc codes (CURVE4 present)
  - [ ] Unit tests pass: `ros run -- --noinform --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --eval '(uiop:quit)'`
  - [ ] Full SSIM regression: `jq '.overall.failed' comparison_report/summary.json` → `1` (no new regressions)

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: Polar transform round-trip
    Tool: Bash
    Preconditions: cl-matplotlib loaded
    Steps:
      1. Create test script that loads cl-matplotlib, creates polar-transform
      2. Transform point (0.0d0, 1.0d0) → should get (1.0d0, 0.0d0)
      3. Invert result → should get back (0.0d0, 1.0d0) within epsilon
      4. Test 4 quadrant points: (0,1), (π/2,1), (π,2), (3π/2,0.5)
    Expected Result: All round-trips within 1e-10 of original
    Failure Indicators: Any delta > 1e-10, or error during transform
    Evidence: .sisyphus/evidence/task-5-roundtrip.txt

  Scenario: Path arc interpolation for constant-r segment
    Tool: Bash
    Preconditions: polar-transform created
    Steps:
      1. Create path: two vertices at (θ1=0, r=1) and (θ2=π/2, r=1)
      2. Call transform-path on this path
      3. Inspect result codes for CURVE4 entries
    Expected Result: Output path contains CURVE4 codes (Bézier arc, not straight LINETO)
    Failure Indicators: Only MOVETO/LINETO codes in output (missing arc interpolation)
    Evidence: .sisyphus/evidence/task-5-arc-interpolation.txt

  Scenario: No regression on existing examples
    Tool: Bash
    Steps:
      1. Run full SSIM comparison
      2. jq '.overall | {total, passed, failed}' comparison_report/summary.json
    Expected Result: total=71, failed≤1
    Evidence: .sisyphus/evidence/task-5-regression.json
  ```

  **Commit**: YES
  - Message: `feat(primitives): add polar coordinate transforms`
  - Files: `src/primitives/polar-transforms.lisp`, `packages.lisp`, `.asd`, test files

- [x] 6. Implement PolarAxes class with grid, spines, ticks, and rendering

  **What to do**:
  - Create `src/containers/polar.lisp` with `polar-axes` class subclassing `axes-base` (NOT `mpl-axes`):

  **A. Class definition** — slots for:
    - `theta-axis` (replaces xaxis) — angular axis (0 to 2π)
    - `radial-axis` (replaces yaxis) — radial axis (0 to rmax)
    - `r-max` — maximum radius (from data or set explicitly)
    - Inherit all `axes-base` slots (patches, lines, artists, etc.)

  **B. `initialize-instance :after`** — override axes-base setup:
    - Do NOT call parent's axis/spine creation (create own axes/spines instead)
    - Set view-lim to `(0.0, 0.0, 2π, r_max)` where x=theta, y=r
    - Create theta-axis: fixed locator at `(0, π/4, π/2, 3π/4, π, 5π/4, 3π/2, 7π/4)`, formatter producing degree labels (0°, 45°, 90°, ..., 315°)
    - Create radial-axis: auto-locator along radial direction, numeric formatter
    - Set up transform pipeline:
      - `trans-scale` = identity (no log scale on polar)
      - Create `polar-transform` instance
      - Create `polar-affine` instance (from Task 5)
      - `trans-data` = polar-transform ∘ polar-affine ∘ trans-axes
    - Create circular background patch (using `path-arc(0, 360)` scaled by polar-affine ∘ trans-axes)
    - NO rectangular spines — set `axes-base-spines` to nil or empty structure

  **C. `draw` method override** — replaces `axes-base` draw:
    - Recalculate r_max from data limits (autoscale radial axis)
    - Update polar-affine with new r_max
    - Recompute trans-data
    - Draw circular background (filled circle, white by default)
    - Draw radial grid lines: for each r tick value, draw a circle arc(0°, 360°) at that radius, transformed through polar-affine ∘ trans-axes. Use `path-arc` scaled by `r/r_max`.
    - Draw theta grid lines: for each theta tick value, draw a radial ray from r=0 to r=r_max, transformed through trans-data.
    - Draw all artists (patches, lines, collections) in z-order — same pattern as axes-base:431-492 but artists already have trans-data set
    - Draw theta tick labels: positioned at radius = r_max + padding, at each theta angle, using text rendering
    - Draw radial tick labels: positioned along θ=0 (rightward), at each r tick value
    - Draw circular boundary spine: arc(0°, 360°) at r=r_max, black, linewidth 1.0

  **D. Plotting API compatibility**:
    - `plot` on polar-axes: data is (theta, r) pairs — works automatically via trans-data
    - `set-xlim` / `set-ylim` on polar-axes: xlim controls theta range (default 0→2π), ylim controls r range (default auto)
    - Override `axes-autoscale-view` to handle polar data limits (r ≥ 0 always, theta wraps)
    - Ensure `axes-add-line`, `axes-add-patch`, `axes-add-collection` work (inherited from axes-base)

  **Must NOT do**:
  - Do NOT modify `axes-base.lisp` class definition
  - Do NOT modify `axis.lisp` class definitions — create theta-axis/radial-axis inline or as simple structs
  - Do NOT implement interactive pan/zoom
  - Do NOT implement partial wedge polar (theta not 0→2π)
  - Do NOT implement polar-specific plot types (polar bar, polar scatter, polar contour, polar fill-between)
  - Do NOT implement `set_theta_zero_location` or `set_theta_direction`
  - Keep theta-axis/radial-axis as simple as possible — they only need: tick positions, tick labels, grid drawing. NOT full x-axis/y-axis class instances.

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Large, complex class with 12+ methods to implement, careful coordinate geometry required
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3
  - **Blocks**: Task 7
  - **Blocked By**: Task 5

  **References**:
  **Pattern References**:
  - `src/containers/axes-base.lisp:122-155` — `initialize-instance :after` for axes-base: shows what PolarAxes must replicate/override (transforms, axes, spines)
  - `src/containers/axes-base.lisp:183-200` — `%setup-transforms`: rectangular transform pipeline to replace with polar pipeline
  - `src/containers/axes-base.lisp:431-492` — `draw` method for axes-base: the draw sequence (background → grid → artists → ticks → spines → legend) — PolarAxes MUST follow this pattern but replace rectangular elements with circular
  - `src/containers/axes-base.lisp:494-526` — `%draw-axes-background` and `%draw-axes-frame`: shows how to draw background/frame using renderer — adapt for circular shape
  - `src/containers/axis.lisp:390-500` — `draw` method for x-axis: shows tick positioning and label rendering pattern
  - `src/containers/spines.lisp:114-180` — Spine draw method: shows path + transform + gc rendering pattern

  **API/Type References**:
  - `src/containers/axes-base.lisp:10-120` — axes-base slot definitions: understand ALL slots that PolarAxes inherits
  - `src/primitives/path.lisp:957-1023` — `path-arc(theta1, theta2)` — reuse for circular grid lines and boundary
  - `src/primitives/transforms.lisp:60-130` — `affine-2d`, `make-affine-2d`, `make-bbox-transform` — used in transform pipeline
  - `src/backends/backend-vecto.lisp:200-300` — `draw-path` renderer method: how paths + transforms + gc render to pixels

  **External References**:
  - matplotlib `projections/polar.py:180-800` — PolarAxes: full reference for method list, transform setup, grid drawing, tick placement
  - matplotlib `projections/polar.py:300-400` — `_gen_axes_patch()`, `_gen_axes_spines()` — circular background and spine generation

  **WHY Each Reference Matters**:
  - `axes-base:431-492` draw method — PolarAxes draw MUST follow the same artist ordering (background → grid → artists → ticks → spines → legend) but replace rectangular grid/frame with circles/rays. Copy the z-order interleaving logic.
  - `axes-base:122-155` initialize — Shows what parent init does. PolarAxes must do the same things but differently (polar transforms instead of bbox transforms, no rectangular spines).
  - `path-arc` — Called repeatedly for radial grid circles, boundary spine, and background. This is the workhorse function for all circular geometry.
  - Spine draw pattern — Shows exactly how a path + transform → rendered line. Use this pattern for the circular boundary.

  **Acceptance Criteria**:
  - [ ] `(make-instance 'polar-axes :figure fig :position pos)` creates without error
  - [ ] `trans-data` correctly maps `(0, 1)` → point on right edge of circular area
  - [ ] Radial grid circles are concentric and centered
  - [ ] Theta grid lines are radial rays from center to edge
  - [ ] Theta labels show 0°, 45°, ..., 315° around perimeter
  - [ ] Radial labels show numeric values along θ=0 ray
  - [ ] Circular boundary spine renders as complete circle
  - [ ] `(plot ax theta-list r-list)` correctly renders data in polar coords
  - [ ] Unit tests pass
  - [ ] Full SSIM regression: failed≤1

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: PolarAxes renders basic polar plot
    Tool: Bash
    Preconditions: cl-matplotlib loaded with polar-axes class
    Steps:
      1. Create test script:
         (figure)
         (let ((ax (make-instance 'polar-axes :figure (gcf) :position '(0.125d0 0.11d0 0.775d0 0.77d0))))
           (push ax (figure-axes (gcf)))
           (plot ax (list 0 1.57 3.14 4.71 6.28) (list 1 1 1 1 1))  ;; circle at r=1
           (savefig "test-polar.png"))
      2. Render with ros run
      3. Verify PNG exists and shows circular plot (not rectangular)
    Expected Result: PNG with circular grid, radial lines, theta labels
    Failure Indicators: Rectangular grid, no circular boundary, crash
    Evidence: .sisyphus/evidence/task-6-polar-basic.png

  Scenario: PolarAxes grid lines are correct
    Tool: Bash
    Steps:
      1. Create polar plot with data spanning r=0 to r=3
      2. Render, inspect visually
      3. Check: concentric circles present, radial rays present, theta labels at 8 positions
    Expected Result: Visible concentric grid circles + 8 radial rays + degree labels
    Failure Indicators: Missing grid, straight lines instead of arcs, no labels
    Evidence: .sisyphus/evidence/task-6-polar-grid.png

  Scenario: No regression on existing examples
    Tool: Bash
    Steps:
      1. Full SSIM comparison
    Expected Result: total=71, failed≤1
    Evidence: .sisyphus/evidence/task-6-regression.json
  ```

  **Commit**: YES (groups with Task 5)
  - Message: `feat(containers): add PolarAxes with circular grid and polar transforms`
  - Files: `src/containers/polar.lisp`, `src/primitives/polar-transforms.lisp` (if amended), `packages.lisp`, `.asd`

- [x] 7. Polar projection dispatch in add-subplot/subplots + pyplot integration

  **What to do**:
  - Modify `src/containers/axes.lisp` function `add-subplot` (line 1361):
    - Add `:projection` keyword parameter (default nil)
    - Replace `(make-instance 'mpl-axes ...)` with:
      ```lisp
      (let ((ax (case projection
                  (:polar (make-instance 'polar-axes :figure figure :position position :facecolor facecolor :frameon frameon :zorder 0))
                  (otherwise (make-instance 'mpl-axes :figure figure :position position :facecolor facecolor :frameon frameon :zorder 0)))))
        ...)
      ```
    - Ensure artist-figure and artist-axes are set on the result (same as current code)
  - Modify `src/containers/gridspec.lisp` function `subplots` (line 363):
    - Add `:projection` keyword parameter (default nil)
    - Pass through to axes creation: replace `(make-instance 'mpl-axes ...)` with same case dispatch
    - NOTE: This means ALL axes in a subplots grid will have the same projection. This matches matplotlib's `subplot_kw={'projection': 'polar'}` pattern.
  - Modify `src/pyplot/pyplot.lisp`:
    - Update `subplots` wrapper (line 155) to accept and pass `:projection` keyword
    - Add `polar-plot` convenience function: `(polar-plot theta-list r-list &rest kwargs)` — creates polar axes if not already, calls plot
    - Ensure existing `plot`, `set-xlim`, `set-ylim`, `title`, `grid` work with polar-axes (they should, since they delegate to axes-base methods)
  - Update `packages.lisp` with new exports (polar-axes, polar-plot if added)
  - Test: `(subplots 1 1 :projection :polar)` returns a polar-axes instance

  **Must NOT do**:
  - Do NOT create a projection registry or factory pattern — simple `case` dispatch only
  - Do NOT add other projections (only :polar and default rectangular)
  - Do NOT modify class definitions of axes-base, mpl-axes, x-axis, y-axis, spine

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small modifications to 3 existing files — adding keyword params and case dispatch
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 8
  - **Blocked By**: Task 6

  **References**:
  **Pattern References**:
  - `src/containers/axes.lisp:1361-1408` — `add-subplot`: current implementation to modify (add `:projection` keyword, case dispatch on axes class)
  - `src/containers/gridspec.lisp:363-402` — `subplots`: current implementation to modify (add `:projection`, pass to make-instance)
  - `src/pyplot/pyplot.lisp:155-180` — pyplot `subplots` wrapper: add `:projection` keyword passthrough

  **API/Type References**:
  - `src/containers/polar.lisp` — `polar-axes` class (from Task 6): class name to use in case dispatch
  - `src/pyplot/pyplot.lisp:1-30` — pyplot package and pattern for adding new wrapper functions

  **WHY Each Reference Matters**:
  - `add-subplot` line 1396 — The exact `make-instance 'mpl-axes` call to wrap with case dispatch. The surrounding code (position calculation, figure-axes push, artist refs) stays identical.
  - `gridspec.lisp` subplots line 391 — Same pattern: `make-instance 'mpl-axes` to wrap. Everything else unchanged.
  - pyplot wrapper — Must pass `:projection` through to containers layer. Follow existing keyword passthrough pattern.

  **Acceptance Criteria**:
  - [ ] `(add-subplot fig 1 1 1 :projection :polar)` returns a `polar-axes` instance
  - [ ] `(add-subplot fig 1 1 1)` still returns a `mpl-axes` instance (backward compatible)
  - [ ] `(subplots fig 1 1 :projection :polar)` returns array of `polar-axes`
  - [ ] pyplot `(subplots 1 1 :projection :polar)` works end-to-end
  - [ ] All existing examples still render correctly (no regression from dispatch change)
  - [ ] Full SSIM regression: failed≤1

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: Projection dispatch creates correct axes type
    Tool: Bash
    Steps:
      1. Create test script checking: (type-of (add-subplot fig 1 1 1 :projection :polar))
      2. Verify it's polar-axes
      3. Create test: (type-of (add-subplot fig 1 1 1)) — verify mpl-axes
    Expected Result: :polar → polar-axes, default → mpl-axes
    Failure Indicators: Wrong type, error on :projection keyword
    Evidence: .sisyphus/evidence/task-7-dispatch.txt

  Scenario: pyplot subplots with :projection :polar renders
    Tool: Bash
    Steps:
      1. (multiple-value-bind (fig ax) (subplots 1 1 :projection :polar)
           (plot (list 0 1 2 3 4 5 6) (list 1 2 3 2 1 2 3))
           (savefig "test-polar-pyplot.png"))
      2. Verify PNG renders with circular polar plot
    Expected Result: PNG with polar circular grid
    Failure Indicators: Rectangular grid, crash on :projection keyword
    Evidence: .sisyphus/evidence/task-7-pyplot-polar.png

  Scenario: No regression — all 71 existing examples still pass
    Tool: Bash
    Steps:
      1. Full SSIM comparison
    Expected Result: total=71, failed≤1
    Evidence: .sisyphus/evidence/task-7-regression.json
  ```

  **Commit**: YES
  - Message: `feat(containers): add polar projection dispatch to add-subplot and subplots`
  - Files: `src/containers/axes.lisp`, `src/containers/gridspec.lisp`, `src/pyplot/pyplot.lisp`, `packages.lisp`

- [x] 8. Polar Gallery Examples (6 examples)

  **What to do**:
  Write Python reference scripts and CL example scripts for:
  1. **polar-line** — Basic polar line plot: r = 1 + cos(θ) (cardioid), with grid and theta labels
  2. **polar-rose** — Rose curve: r = cos(4θ), showing multi-petal flower pattern
  3. **polar-spiral** — Archimedean spiral: r = θ/2π, showing outward spiral
  4. **polar-multi** — Multiple datasets on one polar axes: cardioid + circle + limaçon
  5. **polar-styled** — Styled polar: custom title, colored line, linewidth, grid styling, alpha
  6. **polar-scatter** — Polar scatter plot using markers at polar positions (use `plot` with marker style, NOT a separate polar-scatter function)

  For each: create `reference_scripts/{name}.py` + `examples/{name}.lisp`, generate reference, render CL, verify SSIM ≥ 0.95.

  **Python reference requirements**:
  - `import matplotlib; matplotlib.use('Agg')`
  - `plt.rcParams['savefig.dpi'] = 100`
  - `plt.rcParams['text.hinting'] = 'none'`
  - Use `fig, ax = plt.subplots(subplot_kw={'projection': 'polar'})` pattern
  - Use deterministic data (mathematical functions, not random)
  - `fig.savefig(f'reference_images/{name}.png')` output path

  **CL example requirements**:
  - `(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))` pattern
  - Use `(subplots 1 1 :projection :polar)` to create polar axes
  - Match Python data exactly (same theta arrays, same functions)
  - `(savefig (format nil "examples/~a.png" name))` output

  **Must NOT do**:
  - Do NOT modify src/ files
  - Do NOT use random data (deterministic mathematical functions only)
  - Do NOT use polar-specific plot types that don't exist (no polar-bar, no polar-fill)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 6 example pairs with careful Python/CL matching, iterative SSIM tuning
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 4
  - **Blocks**: Task 9
  - **Blocked By**: Task 7

  **References**:
  - Task 5-7 implementations (polar-transforms, PolarAxes, projection dispatch)
  - `reference_scripts/contour-basic.py` / `examples/contour-basic.lisp` — Pattern for Python/CL example pairs with mathematical data
  - `examples/line-basic.lisp` — Simplest example pattern to follow for CL structure
  - matplotlib gallery: `polar_demo.py`, `polar_scatter.py`

  **Acceptance Criteria**:
  - [ ] 6 new example pairs created (12 files total)
  - [ ] Full SSIM: total=77, failed≤1 (color-cycle only)
  - [ ] Each new polar example SSIM ≥ 0.95
  - [ ] Polar plots show circular grid, theta labels, radial ticks

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: All 6 polar examples pass SSIM
    Tool: Bash
    Steps:
      1. Generate 6 references: for name in polar-line polar-rose polar-spiral polar-multi polar-styled polar-scatter; do .venv/bin/python reference_scripts/${name}.py; done
      2. Render 6 CL examples: for name in polar-line polar-rose polar-spiral polar-multi polar-styled polar-scatter; do setarch $(uname -m) -R ros run -- --noinform --load examples/${name}.lisp 2>/dev/null; done
      3. Run full SSIM comparison
      4. Check each new example ≥ 0.95
    Expected Result: 6/6 new examples pass SSIM ≥ 0.95, total=77, failed≤1
    Failure Indicators: Any polar example < 0.95, missing theta labels, wrong curve shape
    Evidence: .sisyphus/evidence/task-8-polar-examples.json

  Scenario: Polar-line cardioid shape matches reference
    Tool: Bash
    Steps:
      1. Generate reference + CL for polar-line
      2. Compare visually: both should show heart-shaped cardioid with r = 1 + cos(θ)
    Expected Result: SSIM ≥ 0.95 with matching cardioid shape
    Evidence: .sisyphus/evidence/task-8-polar-line.png
  ```

  **Commit**: YES
  - Message: `feat(examples): add polar projection gallery examples`
  - Files: 6 × `reference_scripts/{name}.py` + 6 × `examples/{name}.lisp`

- [x] 9. Implement RK12 integrator + StreamMask + streamplot()

  **What to do**:
  - Create `src/algorithms/streamplot.lisp` with:

  **A. StreamMask class** — occupancy grid for streamline spacing:
    - Grid of `density * 30` × `density * 30` cells (default density=1 → 30×30)
    - Methods: `mask-occupied-p (mask xi yi)` — check if cell occupied, `mask-occupy (mask xi yi)` — mark cell + neighbors, `mask-undo (mask xi yi)` — unmark cell
    - Coordinates map from data space to grid indices via linear transform

  **B. DomainMap** — maps data coordinates to grid:
    - Store X, Y 1D arrays (grid coordinates for each axis)
    - `domain-point-in-bounds-p (dm x y)` → boolean
    - `domain-grid2data (dm xi yi)` → (x, y) in data space
    - `domain-data2grid (dm x y)` → (xi, yi) in grid space (fractional)
    - Bilinear interpolation of U, V at fractional grid coordinates: `domain-interp-velocity (dm xi yi U V)` → (u, v)

  **C. RK12 adaptive integrator**:
    - Runge-Kutta 1st/2nd order with adaptive step control
    - `integrate-streamline (dm mask U V x0 y0 direction max-length)`:
      - Start at (x0, y0), integrate in `direction` (+1 forward, -1 backward)
      - Step: RK2 trial step, RK1 comparison, error = |RK2 - RK1|
      - If error > tolerance: halve step, retry
      - If error < tolerance/4: double step (max step ≤ 1.0 grid cell)
      - Terminate when: out of bounds, velocity < 1e-8, cell occupied in mask, max_length reached
      - Mark traversed cells in mask
      - Return list of (x, y) data-space points along streamline

  **D. Seed point selection**:
    - Generate candidate starting points from a grid of evenly-spaced positions
    - For each candidate: if not masked, integrate forward+backward, store trajectory
    - Sort candidates to start near field center for visual quality

  **E. `streamplot` function**:
    - Signature: `(streamplot ax x-array y-array u-2d-array v-2d-array &key density color linewidth arrowsize arrowstyle)`
    - X, Y are 1D arrays defining grid coordinates
    - U, V are 2D arrays of velocity components at each grid point
    - For each streamline trajectory: create LineCollection segments
    - For each streamline: add one FancyArrowPatch at midpoint showing flow direction
    - Default: density=1, linewidth=1.0, arrowsize=1.0, color="C0"
    - Add collections to axes, update data limits

  - Add `streamplot` pyplot wrapper to `src/pyplot/pyplot.lisp`
  - Update `packages.lisp`, `.asd`
  - Add unit tests:
    - Uniform rightward flow: all streamlines are horizontal lines going right
    - Circular flow field: streamlines are concentric circles
    - Zero velocity everywhere: no streamlines generated

  **Must NOT do**:
  - Do NOT implement `start_points` parameter
  - Do NOT implement `broken_streamlines`
  - Do NOT implement variable-color streamlines (color mapped to velocity magnitude)
  - Do NOT implement `maxlength` or `integration_direction` parameters beyond basic forward+backward
  - Keep it simple: one color for all streamlines, one linewidth

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Complex numerical algorithm with RK12 integrator, occupancy grid, bilinear interpolation — requires careful implementation
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5
  - **Blocks**: Task 10
  - **Blocked By**: Task 8

  **References**:
  **Pattern References**:
  - `src/rendering/collections.lisp:245-350` — LineCollection: class to use for streamlines. Shows how to create segments, set colors, draw.
  - `src/rendering/fancy-arrow.lisp:1-50` — FancyArrowPatch: class to use for direction arrows along streamlines
  - `src/plotting/contour.lisp:199-222` — PolyCollection usage and axes integration pattern — follow for adding collections to axes

  **API/Type References**:
  - `src/rendering/collections.lisp:245-280` — LineCollection constructor: accepts list of segment paths, colors, linewidths
  - `src/rendering/fancy-arrow.lisp:100-200` — FancyArrowPatch: posA, posB, arrowstyle, mutation-scale
  - `src/containers/axes-base.lisp:280-320` — `axes-add-collection`: how to register a collection with axes

  **External References**:
  - matplotlib `streamplot.py:1-50` — Overall streamplot() function signature and flow
  - matplotlib `streamplot.py:50-150` — StreamMask and DomainMap implementations
  - matplotlib `streamplot.py:150-300` — `_integrate_rk12()` and `_gen_starting_points()`
  - matplotlib `streamplot.py:300-400` — Trajectory collection and arrow placement

  **WHY Each Reference Matters**:
  - `LineCollection` — Each streamline becomes segments in a LineCollection. Must understand the constructor pattern.
  - `FancyArrowPatch` — Direction indicators. One per streamline at midpoint. Already implemented, just instantiate.
  - matplotlib `streamplot.py` — The DEFINITIVE reference for the RK12 algorithm, step control, and mask logic. This is a direct port.
  - `contour.lisp` pattern — Shows exactly how to add collections to axes with proper transform and limit updates.

  **Acceptance Criteria**:
  - [ ] `(streamplot ax x-arr y-arr u-2d v-2d)` renders streamlines with arrows
  - [ ] Uniform rightward flow produces horizontal streamlines
  - [ ] Zero-velocity field produces no streamlines (no crash)
  - [ ] Streamlines don't overlap (mask working correctly)
  - [ ] Direction arrows visible on streamlines
  - [ ] Unit tests pass
  - [ ] Full SSIM regression: failed≤1

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: Streamplot renders uniform flow
    Tool: Bash
    Preconditions: cl-matplotlib loaded
    Steps:
      1. Create test script with uniform rightward flow: U=1, V=0 on a 10×10 grid
      2. Call (streamplot ax x y u v)
      3. (savefig "test-streamplot.png")
      4. Verify PNG exists, shows horizontal streamlines with rightward arrows
    Expected Result: PNG with ~5-10 horizontal streamlines, each with a right-pointing arrow
    Failure Indicators: No streamlines, vertical lines, crash, arrows pointing wrong way
    Evidence: .sisyphus/evidence/task-9-streamplot-uniform.png

  Scenario: Streamplot handles zero velocity without crash
    Tool: Bash
    Steps:
      1. Create U=0, V=0 everywhere on 10×10 grid
      2. Call streamplot
      3. Verify no crash, empty or minimal plot
    Expected Result: No streamlines drawn, no error
    Failure Indicators: Crash, infinite loop, division by zero
    Evidence: .sisyphus/evidence/task-9-streamplot-zero.txt

  Scenario: No regression on existing examples
    Tool: Bash
    Steps:
      1. Full SSIM comparison
    Expected Result: total=77, failed≤1
    Evidence: .sisyphus/evidence/task-9-regression.json
  ```

  **Commit**: YES
  - Message: `feat(plotting): add streamplot with RK12 adaptive integrator`
  - Files: `src/algorithms/streamplot.lisp`, `src/pyplot/pyplot.lisp`, `packages.lisp`, `.asd`, test files

- [x] 10. Streamplot Gallery Examples (2 examples)

  **What to do**:
  Write Python reference scripts and CL example scripts for:
  1. **streamplot-basic** — Basic streamplot of a simple flow field: U = -Y, V = X (circular/rotational flow), on a grid from -3 to 3. Default styling with blue streamlines.
  2. **streamplot-styled** — Styled streamplot with custom linewidth, color, density: show a saddle-point flow field (U = X, V = -Y) with density=1.5, linewidth=2, color="darkred".

  For each: create `reference_scripts/{name}.py` + `examples/{name}.lisp`, generate reference, render CL, verify SSIM ≥ 0.95.

  **Python reference requirements**:
  - `import matplotlib; matplotlib.use('Agg')`
  - `plt.rcParams['savefig.dpi'] = 100`
  - `plt.rcParams['text.hinting'] = 'none'`
  - Use `np.meshgrid` for grid generation, simple mathematical velocity fields
  - `fig.savefig(f'reference_images/{name}.png')` output path

  **CL example requirements**:
  - `(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))` pattern
  - Replicate exact same grid and velocity computation as Python
  - Match figure size, styling, labels

  **Must NOT do**:
  - Do NOT modify src/ files
  - Do NOT use color-mapped streamlines (single color only)
  - Do NOT use `start_points` or `broken_streamlines`

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 2 example pairs with iterative SSIM matching
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 5
  - **Blocks**: Task 11
  - **Blocked By**: Task 9

  **References**:
  - Task 9 implementation (streamplot function)
  - `reference_scripts/contour-basic.py` / `examples/contour-basic.lisp` — Pattern for 2D array data with meshgrid
  - matplotlib gallery: `streamplot_demo.py`

  **Acceptance Criteria**:
  - [ ] 2 new example pairs created (4 files total)
  - [ ] Full SSIM: total=79, failed≤1
  - [ ] Each new streamplot example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: Both streamplot examples pass SSIM
    Tool: Bash
    Steps:
      1. Generate 2 references, render 2 CL examples
      2. Run full SSIM comparison
      3. Verify each new example ≥ 0.95
    Expected Result: 2/2 pass, total=79, failed≤1
    Failure Indicators: Streamlines in wrong direction, missing arrows, SSIM < 0.95
    Evidence: .sisyphus/evidence/task-10-streamplot-examples.json
  ```

  **Commit**: YES
  - Message: `feat(examples): add streamplot gallery examples`
  - Files: 2 × `reference_scripts/{name}.py` + 2 × `examples/{name}.lisp`

- [x] 11. Final Regression + Checkpoint Commit

  **What to do**:
  - Clear FASL cache: `rm -rf ~/.cache/common-lisp/`
  - Re-render ALL examples (79 total): loop through all .lisp files in examples/
  - Re-generate ALL reference images: loop through all .py files in reference_scripts/
  - Run full SSIM comparison with `tools/compare.py`
  - Verify: `jq '.overall | {total, passed, failed}' comparison_report/summary.json` → `{"total": >=79, "passed": >=78, "failed": <=1}`
  - Run full unit test suite: `ros run -- --noinform --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --eval '(uiop:quit)'`
  - Verify fragile examples still safe:
    - `jq '.examples[] | select(.name=="step-plot") | .ssim' comparison_report/summary.json` → ≥ 0.955
    - `jq '.examples[] | select(.name=="histogram-multi") | .ssim' comparison_report/summary.json` → ≥ 0.951
  - Create checkpoint commit with all remaining changes

  **Must NOT do**:
  - Do NOT modify any src/ files or examples (just verify)
  - Do NOT lower SSIM threshold

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Pure verification + commit, no implementation
  - **Skills**: [`git-master`]
    - `git-master`: Clean checkpoint commit with proper message

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 6
  - **Blocks**: F1-F4
  - **Blocked By**: Task 10

  **References**:
  - `comparison_report/summary.json` — SSIM results format
  - `tools/compare.py` — comparison tool (DO NOT MODIFY)

  **Acceptance Criteria**:
  - [ ] FASL cache cleared
  - [ ] All 79+ examples rendered successfully
  - [ ] `jq '.overall.total' comparison_report/summary.json` → ≥ 79
  - [ ] `jq '.overall.failed' comparison_report/summary.json` → ≤ 1
  - [ ] All unit tests pass (0 failures)
  - [ ] step-plot SSIM ≥ 0.955, histogram-multi SSIM ≥ 0.951
  - [ ] Checkpoint commit created

  **QA Scenarios (MANDATORY):**
  ```
  Scenario: Full regression on all 79+ examples
    Tool: Bash
    Steps:
      1. rm -rf ~/.cache/common-lisp/
      2. Re-render all examples
      3. Re-generate all references
      4. .venv/bin/python tools/compare.py --reference reference_images/ --actual examples/ --threshold 0.95 --output comparison_report/
      5. jq '.overall | {total, passed, failed}' comparison_report/summary.json
    Expected Result: {"total": >=79, "passed": >=78, "failed": <=1}
    Failure Indicators: failed > 1, total < 79, any new regression
    Evidence: .sisyphus/evidence/task-11-final-regression.json

  Scenario: All unit tests pass
    Tool: Bash
    Steps:
      1. ros run -- --noinform --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --eval '(uiop:quit)'
    Expected Result: 0 failures, all tests pass
    Evidence: .sisyphus/evidence/task-11-unit-tests.txt
  ```

  **Commit**: YES
  - Message: `chore: tier 3 checkpoint — violin, quiver, polar, streamplot complete`
  - Files: all uncommitted changes

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [x] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists. For each "Must NOT Have": search for violations. Check evidence files. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Code Quality Review** — `unspecified-high`
  Run full unit test suite. Review all new src/ files for: double-float usage, error handling for edge cases, consistent style, proper docstrings. Check examples follow defpackage pattern. Check reference scripts include required rcParams.
  Output: `Tests [N pass/N fail] | Style [N clean/N issues] | VERDICT`

- [x] F3. **Full SSIM QA — All Examples** — `unspecified-high`
  Clear FASL cache. Re-render ALL examples. Run full SSIM comparison. Verify: ≤1 failure (color-cycle only), total ≥ 79, step-plot still ≥ 0.955.
  Output: `Total [N] | Passed [N] | Failed [N] | Min SSIM [X] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `unspecified-high`
  For each task: verify deliverables match spec, nothing beyond spec was built. Check "Must NOT do" compliance. Verify no modifications to forbidden files. Detect cross-task contamination.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | VERDICT`

---

## Commit Strategy

- **Per-feature commits**: Each feature (violin, quiver, polar, streamplot) gets a single commit after passing SSIM + unit tests
  - `feat(plotting): add violin plots with GaussianKDE`
  - `feat(plotting): add quiver vector field plots`
  - `feat(containers): add polar projection with PolarAxes`
  - `feat(plotting): add streamplot with RK12 integrator`
- **Example commits**: Gallery examples committed with their feature
- **Bug fix commits**: Any src/ fixes get separate commits
- **Checkpoint commit**: Final commit after all features pass

---

## Success Criteria

### Verification Commands
```bash
# All examples pass (except known color-cycle)
jq '.overall | {total, passed, failed}' comparison_report/summary.json
# Expected: {"total": >=79, "passed": >=78, "failed": <=1}

# All unit tests pass
ros run -- --noinform --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --eval '(uiop:quit)'
# Expected: 0 failures

# Fragile examples still safe
jq '.examples[] | select(.name=="step-plot") | .ssim' comparison_report/summary.json
# Expected: >= 0.955
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All unit tests pass
- [ ] All SSIM comparisons pass at 0.95 threshold (except color-cycle)
- [ ] 15 new gallery examples committed
- [ ] No new CL library dependencies
