# Gallery Expansion: Port Matplotlib Examples & Implement Missing Features

## TL;DR

> **Quick Summary**: Expand cl-matplotlib's example coverage from 27 to 47+ by porting matplotlib gallery examples that current features support (Phase 1), then implement the simplest missing features that unlock the most gallery examples (Phase 2).
> 
> **Deliverables**:
> - ~20 new gallery examples (Python reference scripts + CL scripts + PNGs) all passing SSIM ≥ 0.95
> - Bug fixes in `src/` for any rendering issues discovered during porting
> - Phase 2: Implementation of Tier 1-3 missing features (text, axhline/axvline, set_xticks, suptitle, invert_axis, twinx, pcolormesh, axhspan/axvspan, polar, violin)
> - Additional gallery examples enabled by each new feature
> 
> **Estimated Effort**: XL (Phase 1: Medium, Phase 2: Large)
> **Parallel Execution**: YES — 8 waves
> **Critical Path**: Baseline validation → Batch porting → Bug fixes → Phase 1 checkpoint → Feature implementation → Feature examples

---

## Context

### Original Request
The user wants to expand gallery coverage in two phases:
1. Phase 1: Port all matplotlib gallery examples that current features can already generate, fix bugs to hit 0.95 SSIM
2. Phase 2: Implement missing features prioritized by "simplest feature → most examples unlocked", with user sign-off before implementation

### Interview Summary
**Key Discussions**:
- All 220 matplotlib gallery examples across 7 categories analyzed and classified
- 27 existing examples verified passing (27/27 at 0.95 SSIM threshold)
- ~20 new gallery examples identified as portable with existing 15 plot types
- Missing features cataloged: text(), axhline/axvline, set_xticks, suptitle, invert_axis, twinx, pcolormesh, axhspan/axvspan, polar, violin, quiver
- Phase 2 features prioritized into 3 tiers by complexity-to-unlock ratio
- User must sign off on Phase 2 priorities before implementation begins

**Research Findings**:
- 186/220 gallery examples (85%) don't require advanced features (PathEffects, custom artists, etc.)
- step-plot is the most fragile existing example (SSIM 0.955, only 0.005 above threshold)
- Makefile uses `ros run --` (SBCL 2.5.10), not system `sbcl` (2.2.9) — must use `ros` for consistency
- `make compare` depends on `make cl-images` — must invoke compare.py directly
- Subplot examples use `mpl.containers:` API directly (not pyplot), which is correct and intended
- twin-axes.lisp uses side-by-side subplots, not true twinx() — twinx is truly unimplemented

### Metis Review
**Identified Gaps** (addressed):
- Factual error corrected: 27/27 pass (not 26/27) — barh now at 0.96575
- SBCL version discrepancy: must use `ros run --` to match existing images
- Compare invocation: must call compare.py directly, not `make compare`
- Missing Phase 1 concrete example list — now fully enumerated in tasks
- Missing regression gate frequency — now set to every batch of ≤5 examples
- Missing per-example validation cycle — now defined in acceptance criteria
- Reference script template guardrails — now explicit in every task

---

## Work Objectives

### Core Objective
Expand cl-matplotlib gallery from 27 to 47+ examples, then implement missing features to unlock another 30+ examples, ensuring zero regressions throughout.

### Concrete Deliverables
- **Phase 1**: ~20 new `examples/*.lisp` + `reference_scripts/*.py` + rendered PNGs, all passing SSIM ≥ 0.95
- **Phase 1**: Bug fixes in `src/` as needed (each in separate commit with full regression)
- **Phase 2**: Implementation of Tier 1-3 features in `src/` with unit tests
- **Phase 2**: Additional gallery examples enabled by each new feature
- **Both**: Zero regressions on existing 27 examples

### Definition of Done
- [ ] `jq '.overall.failed' comparison_report/summary.json` → `0`
- [ ] `jq '.overall.total' comparison_report/summary.json` → `≥ 47` (after Phase 1)
- [ ] All unit tests pass: `ros run -- --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit`
- [ ] All new files committed and tracked in git
- [ ] User has reviewed and approved Phase 1 examples
- [ ] User has signed off on Phase 2 feature priorities

### Must Have
- All new examples use the `defpackage #:example` pattern (26/27 existing examples use this)
- All Python reference scripts include `matplotlib.use('Agg')`, `savefig.dpi = 100`, `text.hinting = 'none'`
- Full SSIM regression run after every batch of ≤5 new examples
- Bug fixes in `src/` get separate commits with full regression verification
- Phase 1 checkpoint commit before any Phase 2 work begins
- Phase 2 gated on explicit user sign-off

### Must NOT Have (Guardrails)
- Do NOT modify files in `reference_images/` (existing ones — new reference images ARE generated there)
- Do NOT modify `tools/compare.py`
- Do NOT modify `src/pyplot/pyplot.lisp` line 242 (hist linewidth=1.0)
- Do NOT lower SSIM threshold below 0.95
- Do NOT run `make cl-images` or `make compare` (invoke compare.py directly)
- Do NOT add new pyplot functions during Phase 1 (that's Phase 2 scope)
- Do NOT use `bbox_inches='tight'` in Python reference scripts (changes output dimensions)
- Do NOT introduce new CL library dependencies for examples (data must be self-generated)
- Do NOT use the `find-package` + `flet` pattern from simple-line.lisp (use defpackage pattern)
- Do NOT "improve" gallery examples beyond what's in the matplotlib original (no creative additions)
- Do NOT add examples that require external data files (all data must be generated in-script)
- Any change to `src/` requires immediate full regression before continuing

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.
> User visual review is a separate sign-off milestone, not blocking individual tasks.

### Test Decision
- **Infrastructure exists**: YES (2,069 FiveAM tests, SBCL + CCL CI)
- **Automated tests**: Tests-after (for Phase 2 feature implementations)
- **Framework**: FiveAM (existing), SSIM comparison (visual regression)
- **Unit tests required**: YES for Phase 2 `src/` changes; NO for Phase 1 example scripts

### QA Policy
Every task MUST include agent-executed QA scenarios.
Primary QA mechanism: SSIM comparison via `tools/compare.py`.
Evidence saved to `.sisyphus/evidence/task-{N}-*.{ext}`.

- **New examples**: Render CL, generate Python reference, run SSIM comparison, verify ≥ 0.95
- **Bug fixes**: Full 27+ example regression suite, verify 0 failures
- **Phase 2 features**: Unit tests + gallery examples using the feature + SSIM comparison

### Render Command (CANONICAL)
```bash
# Single example
setarch $(uname -m) -R ros run -- --noinform --load examples/{name}.lisp 2>/dev/null

# Generate reference
.venv/bin/python reference_scripts/{name}.py

# Run full SSIM comparison
.venv/bin/python tools/compare.py --reference reference_images/ --actual examples/ --threshold 0.95 --output comparison_report/

# Verify results
jq '.overall.failed' comparison_report/summary.json  # Assert: 0
jq '.examples[] | select(.name=="{name}") | .ssim' comparison_report/summary.json  # Assert: >= 0.95
```

### Fragile Examples to Monitor
- `step-plot`: SSIM 0.955062 — only 0.005 margin. Track after every `src/` change.
- `barh`: Was previously failing, now at 0.96575. Monitor for regression.

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — baseline + Phase 1 scaffolding):
├── Task 1: Baseline validation (verify 27/27 pass) [quick]
├── Task 2: Phase 1 Batch A — 5 examples (scales + simple plots) [unspecified-high]
├── Task 3: Phase 1 Batch B — 5 examples (scatter/fill variants) [unspecified-high]

Wave 2 (After Wave 1 — more Phase 1 batches):
├── Task 4: Phase 1 Batch C — 5 examples (bar/hist variants) [unspecified-high]
├── Task 5: Phase 1 Batch D — 5 examples (contour/subplot/misc) [unspecified-high]

Wave 3 (After Wave 2 — Phase 1 bug fixes):
├── Task 6: Phase 1 bug fixes for any failing examples [deep]
├── Task 7: Phase 1 final regression + checkpoint commit [quick]

Wave 4 (After Wave 3 — USER SIGN-OFF GATE):
├── Task 8: Present Phase 1 results + Phase 2 priorities for user sign-off [quick]

Wave 5 (After user sign-off — Phase 2 Tier 1 features):
├── Task 9: Implement text() pyplot wrapper [unspecified-high]
├── Task 10: Implement axhline/axvline/hlines/vlines [unspecified-high]
├── Task 11: Implement suptitle + supxlabel/supylabel [quick]
├── Task 12: Implement invert_xaxis/invert_yaxis [quick]
├── Task 13: Implement set_xticks/set_xticklabels/set_yticks/set_yticklabels [unspecified-high]

Wave 6 (After Wave 5 — Tier 1 gallery examples):
├── Task 14: Gallery examples using text() [unspecified-high]
├── Task 15: Gallery examples using axhline/axvline [unspecified-high]
├── Task 16: Gallery examples using suptitle, invert_axis, set_xticks [unspecified-high]

Wave 7 (After Wave 6 — Phase 2 Tier 2 features):
├── Task 17: Implement twinx/twiny [deep]
├── Task 18: Implement pcolormesh (build on existing QuadMesh) [deep]
├── Task 19: Implement axhspan/axvspan [unspecified-high]

Wave 8 (After Wave 7 — Tier 2 gallery examples):
├── Task 20: Gallery examples using twinx, pcolormesh, axhspan [unspecified-high]

Wave FINAL (After ALL tasks — independent review):
├── Task F1: Plan compliance audit [oracle]
├── Task F2: Code quality review [unspecified-high]
├── Task F3: Full SSIM QA — all examples [unspecified-high]
├── Task F4: Scope fidelity check [deep]

Critical Path: T1 → T2/T3 → T4/T5 → T6 → T7 → T8(user) → T9-T13 → T14-T16 → T17-T19 → T20 → F1-F4
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 5 (Wave 5)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 1 | — | 2, 3 |
| 2 | 1 | 4, 5 |
| 3 | 1 | 4, 5 |
| 4 | 2, 3 | 6 |
| 5 | 2, 3 | 6 |
| 6 | 4, 5 | 7 |
| 7 | 6 | 8 |
| 8 | 7 | 9-13 |
| 9 | 8 | 14 |
| 10 | 8 | 15 |
| 11 | 8 | 16 |
| 12 | 8 | 16 |
| 13 | 8 | 16 |
| 14 | 9 | 17-19 |
| 15 | 10 | 17-19 |
| 16 | 11, 12, 13 | 17-19 |
| 17 | 14, 15, 16 | 20 |
| 18 | 14, 15, 16 | 20 |
| 19 | 14, 15, 16 | 20 |
| 20 | 17, 18, 19 | F1-F4 |
| F1-F4 | 20 | — |

### Agent Dispatch Summary

- **Wave 1**: 3 tasks — T1 → `quick`, T2-T3 → `unspecified-high`
- **Wave 2**: 2 tasks — T4-T5 → `unspecified-high`
- **Wave 3**: 2 tasks — T6 → `deep`, T7 → `quick`
- **Wave 4**: 1 task — T8 → `quick` (user gate)
- **Wave 5**: 5 tasks — T9-T10, T13 → `unspecified-high`, T11-T12 → `quick`
- **Wave 6**: 3 tasks — T14-T16 → `unspecified-high`
- **Wave 7**: 3 tasks — T17-T18 → `deep`, T19 → `unspecified-high`
- **Wave 8**: 1 task — T20 → `unspecified-high`
- **FINAL**: 4 tasks — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

> Implementation + Test = ONE Task. Never separate.
> EVERY task MUST have: Recommended Agent Profile + Parallelization info + QA Scenarios.

- [x] 1. Baseline Validation — Verify 27/27 Examples Still Pass

  **What to do**:
  - Clear FASL cache: `find src -name "*.fasl" -delete && rm -rf ~/.cache/common-lisp/`
  - Re-render ALL 27 existing examples using: `setarch $(uname -m) -R ros run -- --noinform --load examples/{name}.lisp 2>/dev/null`
  - Generate all reference images: `make reference-images`
  - Run full SSIM comparison: `.venv/bin/python tools/compare.py --reference reference_images/ --actual examples/ --threshold 0.95 --output comparison_report/`
  - Verify: `jq '.overall' comparison_report/summary.json` shows `failed: 0`, `total: 27`
  - Specifically verify step-plot SSIM ≥ 0.955 (most fragile example)
  - Record all 27 SSIM scores as the baseline to detect future regressions

  **Must NOT do**:
  - Do NOT run `make cl-images` or `make compare` (they chain targets)
  - Do NOT modify any `src/` files during this task
  - Do NOT modify reference images

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple command execution and validation, no code changes
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser interaction needed
    - `git-master`: No git operations in this task

  **Parallelization**:
  - **Can Run In Parallel**: NO (must complete before example porting begins)
  - **Parallel Group**: Wave 1 (solo — gates T2, T3)
  - **Blocks**: Tasks 2, 3
  - **Blocked By**: None (can start immediately)

  **References**:
  
  **Pattern References**:
  - `Makefile:19-26` — `reference-images` target shows how Python scripts are run
  - `Makefile:28-34` — `cl-images` target shows the `ros run --` pattern (but we invoke individually)
  
  **API/Type References**:
  - `comparison_report/summary.json` — Structure: `{overall: {total, passed, failed, mean_ssim, min_ssim, max_ssim}, examples: [{name, ssim, status}]}`
  
  **External References**:
  - `tools/compare.py` — CLI: `--reference DIR --actual DIR --threshold FLOAT --output DIR`

  **Acceptance Criteria**:
  - [ ] `jq '.overall.failed' comparison_report/summary.json` → `0`
  - [ ] `jq '.overall.total' comparison_report/summary.json` → `27`
  - [ ] `jq '.examples[] | select(.name=="step-plot") | .ssim' comparison_report/summary.json` → `>= 0.955`
  - [ ] All 27 .png files in `examples/` have been freshly re-rendered

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Full baseline SSIM passes
    Tool: Bash
    Preconditions: FASL cache cleared, .venv exists with dependencies
    Steps:
      1. find src -name "*.fasl" -delete && rm -rf ~/.cache/common-lisp/
      2. make reference-images
      3. For each examples/*.lisp: setarch $(uname -m) -R ros run -- --noinform --load examples/{name}.lisp 2>/dev/null
      4. .venv/bin/python tools/compare.py --reference reference_images/ --actual examples/ --threshold 0.95 --output comparison_report/
      5. jq '.overall' comparison_report/summary.json
    Expected Result: {"total": 27, "passed": 27, "failed": 0, "skipped": 0, ...}
    Failure Indicators: Any "failed" > 0, or any example with status "FAIL"
    Evidence: .sisyphus/evidence/task-1-baseline-summary.json (copy of summary.json)

  Scenario: Step-plot margin is safe
    Tool: Bash
    Preconditions: Comparison report generated from scenario above
    Steps:
      1. jq '.examples[] | select(.name=="step-plot") | .ssim' comparison_report/summary.json
    Expected Result: Value >= 0.955
    Failure Indicators: Value < 0.955
    Evidence: .sisyphus/evidence/task-1-step-plot-ssim.txt
  ```

  **Commit**: NO (no code changes — validation only)

- [x] 2. Phase 1 Batch A — Scales + Simple Plot Variants (5 examples)

  **What to do**:
  Write Python reference scripts and CL example scripts for these 5 gallery examples:

  1. **scales-overview** — All 4 scale types (linear, log, symlog, logit) in a 2×2 subplot grid
     - Python: `plt.subplots(2, 2)`, each subplot with `set_yscale()`
     - CL: `(subplots 2 2)`, use `mpl.containers:axes-set-yscale` on each axes
  
  2. **symlog-demo** — Symmetric log scale showing behavior around zero
     - Python: `plt.yscale('symlog', linthresh=0.01)` with data spanning negative to positive
     - CL: `(axes-set-yscale ax :symlog :linthresh 0.01d0)` — verify linthresh kwarg works
  
  3. **logit-demo** — Logit scale for probability data
     - Python: `plt.yscale('logit')` with data in (0, 1) range
     - CL: `(axes-set-yscale ax :logit)` — this is used in existing log-scale.lisp pattern
  
  4. **multi-line-styles** — Multiple lines with different styles (solid, dashed, dotted, dashdot)
     - Python: 4 `plt.plot()` calls with `linestyle=` parameter
     - CL: 4 `(plot ...)` calls with `:linestyle` keyword
  
  5. **errorbar-features** — Different error bar types (symmetric, asymmetric)
     - Python: `plt.errorbar()` with various error specifications
     - CL: `(errorbar ...)` with different `:yerr` shapes

  For each example:
  - Create `reference_scripts/{name}.py` following the canonical template (Agg backend, dpi=100, text.hinting='none')
  - Create `examples/{name}.lisp` following the `defpackage #:example` pattern
  - Generate reference image: `.venv/bin/python reference_scripts/{name}.py`
  - Render CL version: `setarch $(uname -m) -R ros run -- --noinform --load examples/{name}.lisp 2>/dev/null`
  - Run full SSIM comparison after ALL 5 are done

  **Must NOT do**:
  - Do NOT add any new pyplot functions
  - Do NOT modify `src/` files (if an example fails, note it for Task 6)
  - Do NOT use `bbox_inches='tight'` in Python scripts
  - Do NOT use data that requires external files

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multiple file creation with careful template matching, data replication between Python and CL
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: No browser interaction
    - `git-master`: No git operations during task

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 3)
  - **Parallel Group**: Wave 1 (with Task 3)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: Task 1 (baseline must pass first)

  **References**:

  **Pattern References** (CRITICAL — follow these exactly):
  - `reference_scripts/bar-chart.py` — Canonical Python reference template: Agg backend, dpi=100, text.hinting='none', savefig to reference_images/
  - `examples/bar-chart.lisp` — Canonical CL example template: defpackage #:example, figure, plotting, savefig to examples/
  - `examples/log-scale.lisp` — Existing scale example showing `axes-set-yscale` usage pattern
  - `reference_scripts/log-scale.py` — Python reference for scales showing yscale() usage
  - `examples/multi-line.lisp` — Multi-line plotting pattern showing color + label kwargs
  - `examples/errorbar.lisp` — Errorbar pattern showing `:yerr`, `:xerr`, `:fmt` kwargs

  **API/Type References**:
  - `src/containers/scale.lisp` — Scale types: `:linear`, `:log`, `:symlog`, `:logit` — check `linthresh` kwarg for symlog
  - `src/pyplot/pyplot.lisp` — `errorbar` function signature, `plot` function signature

  **External References**:
  - Matplotlib gallery: `scales.py`, `symlog_demo.py`, `logit_demo.py`, `linestyles.py`, `errorbar_features.py`
  - Fetch these from: `https://matplotlib.org/stable/gallery/scales/` and `https://matplotlib.org/stable/gallery/statistics/`

  **WHY Each Reference Matters**:
  - `bar-chart.py` / `bar-chart.lisp`: The exact template to copy for file structure, imports, and savefig pattern
  - `log-scale.lisp`: Shows how to use `axes-set-yscale` with `mpl.containers:` API on subplot axes
  - `errorbar.lisp`: Shows the errorbar kwargs pattern to replicate for errorbar-features

  **Acceptance Criteria**:
  - [ ] 5 new files exist in `reference_scripts/`: scales-overview.py, symlog-demo.py, logit-demo.py, multi-line-styles.py, errorbar-features.py
  - [ ] 5 new files exist in `examples/`: scales-overview.lisp, symlog-demo.lisp, logit-demo.lisp, multi-line-styles.lisp, errorbar-features.lisp
  - [ ] 5 new PNG files in `reference_images/` and 5 in `examples/`
  - [ ] Full SSIM comparison: `jq '.overall.failed' comparison_report/summary.json` → `0`
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 5 Batch A examples render and pass SSIM
    Tool: Bash
    Preconditions: Task 1 baseline passed, .venv active
    Steps:
      1. For each of the 5 Python scripts: .venv/bin/python reference_scripts/{name}.py
      2. Verify: test -f reference_images/{name}.png for each
      3. For each of the 5 CL scripts: setarch $(uname -m) -R ros run -- --noinform --load examples/{name}.lisp 2>/dev/null
      4. Verify: test -f examples/{name}.png for each
      5. .venv/bin/python tools/compare.py --reference reference_images/ --actual examples/ --threshold 0.95 --output comparison_report/
      6. jq '.overall | {total, passed, failed}' comparison_report/summary.json
      7. For each new example: jq '.examples[] | select(.name=="{name}") | {name, ssim, status}' comparison_report/summary.json
    Expected Result: total=32, passed=32, failed=0. Each new example SSIM ≥ 0.95.
    Failure Indicators: Any example with status "FAIL" or missing PNG output
    Evidence: .sisyphus/evidence/task-2-batch-a-summary.json

  Scenario: No regression on existing 27 examples
    Tool: Bash
    Preconditions: Comparison report from scenario above
    Steps:
      1. jq '[.examples[] | select(.name == "step-plot" or .name == "barh" or .name == "annotations" or .name == "bar-chart") | {name, ssim}]' comparison_report/summary.json
    Expected Result: All 27 original examples still PASS, step-plot ≥ 0.955
    Failure Indicators: Any original example drops below 0.95
    Evidence: .sisyphus/evidence/task-2-regression-check.json
  ```

  **Commit**: YES
  - Message: `feat(examples): add gallery batch A — scales and line style variants`
  - Files: `reference_scripts/{5 new .py}`, `examples/{5 new .lisp}`, `examples/{5 new .png}`
  - Pre-commit: SSIM comparison passes with 0 failures

- [x] 3. Phase 1 Batch B — Scatter + Fill Variants (5 examples)

  **What to do**:
  Write Python reference scripts and CL example scripts for these 5 gallery examples:

  1. **scatter-sizes** — Scatter with varying point sizes and colors (size/color mapping)
     - Python: `plt.scatter(x, y, s=sizes, c=colors, alpha=0.5)` with colorbar
     - CL: `(scatter x y :s sizes :c colors :alpha 0.5)` + `(colorbar)`
  
  2. **scatter-legend** — Scatter plot with categorical legend (multiple scatter calls)
     - Python: Multiple `plt.scatter()` calls with different labels + `plt.legend()`
     - CL: Multiple `(scatter ...)` with `:label` + `(legend)`
  
  3. **fill-between-alpha** — Fill between curves with transparency
     - Python: `plt.fill_between(x, y1, y2, alpha=0.3)` with line plots overlaid
     - CL: `(fill-between x y1 y2 :alpha 0.3d0)` + `(plot ...)` lines
  
  4. **curve-error-band** — Line plot with shaded error band
     - Python: `plt.plot()` + `plt.fill_between(x, y-err, y+err, alpha=0.2)`
     - CL: `(plot ...)` + `(fill-between x y-minus y-plus :alpha 0.2d0)`
  
  5. **stacked-bar** — Stacked bar chart using bottom parameter
     - Python: Two `plt.bar()` calls, second with `bottom=` parameter
     - CL: Two `(bar ...)` calls, second with `:bottom` keyword

  For each example: follow same create/render/compare pattern as Task 2.

  **Must NOT do**:
  - Same guardrails as Task 2

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multiple file creation with data replication between Python and CL
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 2)
  - **Parallel Group**: Wave 1 (with Task 2)
  - **Blocks**: Tasks 4, 5
  - **Blocked By**: Task 1

  **References**:

  **Pattern References**:
  - `reference_scripts/scatter.py` / `examples/scatter.lisp` — Scatter pattern with kwargs
  - `reference_scripts/fill-between.py` / `examples/fill-between.lisp` — Fill-between pattern
  - `reference_scripts/bar-chart.py` / `examples/bar-chart.lisp` — Bar chart with color kwargs

  **API/Type References**:
  - `src/pyplot/pyplot.lisp` — `scatter` kwargs: `:s`, `:c`, `:marker`, `:alpha`, `:edgecolors`, `:linewidths`, `:label`
  - `src/pyplot/pyplot.lisp` — `fill-between` kwargs: `:alpha`, `:color`, `:label`
  - `src/pyplot/pyplot.lisp` — `bar` kwargs: `:width`, `:bottom`, `:color`, `:edgecolor`, `:linewidth`, `:label`

  **External References**:
  - Matplotlib gallery: `scatter_demo2.py`, `scatter_with_legend.py`, `fill_between_alpha.py`, `curve_error_band.py`, `bar_stacked.py`

  **Acceptance Criteria**:
  - [ ] 5 new files in `reference_scripts/` and `examples/`
  - [ ] Full SSIM comparison: 0 failures across all 32 examples
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 5 Batch B examples render and pass SSIM
    Tool: Bash
    Preconditions: Task 1 baseline passed
    Steps:
      1. Generate 5 reference images and render 5 CL examples
      2. Run full SSIM comparison
      3. Verify total=32, passed=32, failed=0
      4. Verify each new example SSIM ≥ 0.95
    Expected Result: All pass. No regressions.
    Failure Indicators: Any FAIL status or missing output file
    Evidence: .sisyphus/evidence/task-3-batch-b-summary.json

  Scenario: Stacked bar uses bottom parameter correctly
    Tool: Bash
    Preconditions: stacked-bar.lisp rendered
    Steps:
      1. Render: setarch $(uname -m) -R ros run -- --noinform --load examples/stacked-bar.lisp 2>/dev/null
      2. Verify output exists: test -f examples/stacked-bar.png
      3. Run comparison and check SSIM: jq '.examples[] | select(.name=="stacked-bar") | .ssim' comparison_report/summary.json
    Expected Result: SSIM ≥ 0.95 (bars visually stacked, not overlapping)
    Failure Indicators: Low SSIM indicating bars overlap instead of stack
    Evidence: .sisyphus/evidence/task-3-stacked-bar-ssim.txt
  ```

  **Commit**: YES
  - Message: `feat(examples): add gallery batch B — scatter and fill variants`
  - Files: `reference_scripts/{5 new .py}`, `examples/{5 new .lisp}`, `examples/{5 new .png}`
  - Pre-commit: SSIM comparison passes with 0 failures

- [ ] 4. Phase 1 Batch C — Bar + Histogram Variants (5 examples)

  **What to do**:
  Write Python reference scripts and CL example scripts for these 5 gallery examples:

  1. **bar-colors** — Bar chart with individual per-bar colors
     - Python: `plt.bar(x, heights, color=['red', 'blue', 'green', ...])` — each bar different color
     - CL: `(bar x heights :color '("red" "blue" "green" ...))` — list of colors
  
  2. **horizontal-bar-stacked** — Stacked horizontal bar chart for distributions
     - Python: Multiple `plt.barh()` calls with `left=` parameter for stacking
     - CL: Multiple `(barh ...)` calls with `:left` keyword
  
  3. **histogram-types** — Demo of histogram histtype settings (bar, step, stepfilled)
     - Python: `plt.hist(data, histtype='bar')`, `plt.hist(data, histtype='step')`, etc.
     - CL: `(hist data :histtype :bar)`, `(hist data :histtype :step)`, etc. — in subplots
  
  4. **histogram-multi** — Multiple overlapping histograms
     - Python: Multiple `plt.hist()` calls with `alpha=0.5` for transparency
     - CL: Multiple `(hist ...)` calls with `:alpha 0.5d0`
  
  5. **boxplot-styles** — Boxplot with custom styling (colors, notched)
     - Python: `plt.boxplot(data, notch=True, patch_artist=True)`
     - CL: `(boxplot data :notch t)` — check if `patch_artist` is supported

  For each example: follow same create/render/compare pattern.

  **Must NOT do**:
  - Same guardrails as Task 2
  - Do NOT add `bar_label()` or any new function — stacked bar must work with just `bar()` + `bottom`

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multiple file creation with careful API matching
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 5)
  - **Parallel Group**: Wave 2 (with Task 5)
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 2, 3 (Wave 1 must complete)

  **References**:

  **Pattern References**:
  - `reference_scripts/barh.py` / `examples/barh.lisp` — Horizontal bar pattern
  - `reference_scripts/histogram.py` / `examples/histogram.lisp` — Histogram pattern with histtype
  - `reference_scripts/boxplot.py` / `examples/boxplot.lisp` — Boxplot pattern

  **API/Type References**:
  - `src/pyplot/pyplot.lisp` — `barh` kwargs: `:height`, `:left`, `:color`, `:edgecolor`
  - `src/pyplot/pyplot.lisp` — `hist` kwargs: `:bins`, `:histtype`, `:alpha`, `:color`, `:edgecolor`, `:label`
  - `src/pyplot/pyplot.lisp` — `boxplot` kwargs: `:notch`, `:vert`, `:labels`
  - `src/plotting/hist.lisp` — Histtype implementation: `:bar`, `:step`, `:stepfilled`

  **External References**:
  - Matplotlib gallery: `bar_colors.py`, `horizontal_barchart_distribution.py`, `histogram_histtypes.py`, `histogram_multihist.py`, `boxplot.py`

  **Acceptance Criteria**:
  - [ ] 5 new files in `reference_scripts/` and `examples/`
  - [ ] Full SSIM comparison: 0 failures across all 37 examples
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 5 Batch C examples render and pass SSIM
    Tool: Bash
    Preconditions: Wave 1 (Tasks 2, 3) complete
    Steps:
      1. Generate 5 reference images and render 5 CL examples
      2. Run full SSIM comparison
      3. Verify total=37, passed=37, failed=0
    Expected Result: All pass. No regressions on earlier 32.
    Failure Indicators: Any FAIL status
    Evidence: .sisyphus/evidence/task-4-batch-c-summary.json

  Scenario: Histogram histtype variants render correctly
    Tool: Bash
    Preconditions: histogram-types.lisp rendered
    Steps:
      1. Render histogram-types and verify output exists
      2. Check SSIM: jq '.examples[] | select(.name=="histogram-types") | .ssim' comparison_report/summary.json
    Expected Result: SSIM ≥ 0.95 — all histtype variants (bar, step, stepfilled) render in subplots
    Failure Indicators: SSIM < 0.95 or render crash on specific histtype
    Evidence: .sisyphus/evidence/task-4-histogram-types-ssim.txt
  ```

  **Commit**: YES
  - Message: `feat(examples): add gallery batch C — bar and histogram variants`
  - Files: `reference_scripts/{5 new .py}`, `examples/{5 new .lisp}`, `examples/{5 new .png}`
  - Pre-commit: SSIM comparison passes with 0 failures

- [ ] 5. Phase 1 Batch D — Contour, Subplot, and Misc Variants (5 examples)

  **What to do**:
  Write Python reference scripts and CL example scripts for these 5 gallery examples:

  1. **contour-filled-log** — Filled contour with log color scale
     - Python: `plt.contourf(X, Y, Z, locator=ticker.LogLocator())` or `norm=LogNorm()`
     - CL: Check if contourf supports log norm — may need `(contourf Z :levels ...)` with log-spaced levels
  
  2. **pie-features** — Pie chart with explode, labels, autopct, shadow
     - Python: `plt.pie(sizes, explode=explode, labels=labels, autopct='%1.1f%%')`
     - CL: `(pie sizes :explode explode :labels labels :autopct "%1.1f%%")`
  
  3. **stem-simple** — Simple stem plot (lollipop chart)
     - Python: `plt.stem(x, y)` — minimal, clean stem plot
     - CL: `(stem x y)` — verify matches matplotlib defaults
  
  4. **gridspec-multi** — GridSpec with variable column/row sizes
     - Python: `GridSpec(2, 2, width_ratios=[2, 1], height_ratios=[1, 2])`
     - CL: Use `mpl.containers:gridspec` with width/height ratios
  
  5. **subplots-shared** — Subplots with shared x and y axes
     - Python: `plt.subplots(2, 2, sharex=True, sharey=True)` — four plots, shared axes
     - CL: `(subplots 2 2 :sharex t :sharey t)` — verify axis label hiding works

  For each example: follow same create/render/compare pattern.

  **Must NOT do**:
  - Same guardrails as Task 2
  - Do NOT implement LogNorm if it doesn't exist — use log-spaced contour levels instead

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Mix of plot types requiring understanding of different APIs
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 4)
  - **Parallel Group**: Wave 2 (with Task 4)
  - **Blocks**: Task 6
  - **Blocked By**: Tasks 2, 3 (Wave 1 must complete)

  **References**:

  **Pattern References**:
  - `reference_scripts/filled-contour.py` / `examples/filled-contour.lisp` — Contourf pattern
  - `reference_scripts/pie-chart.py` / `examples/pie-chart.lisp` — Pie chart pattern
  - `reference_scripts/stem-plot.py` / `examples/stem-plot.lisp` — Stem plot pattern
  - `reference_scripts/gridspec-custom.py` / `examples/gridspec-custom.lisp` — GridSpec pattern
  - `reference_scripts/shared-axes.py` / `examples/shared-axes.lisp` — Shared axes pattern

  **API/Type References**:
  - `src/pyplot/pyplot.lisp` — `contourf` kwargs: `:levels`, `:cmap`
  - `src/pyplot/pyplot.lisp` — `pie` kwargs: `:explode`, `:labels`, `:autopct`, `:shadow`
  - `src/containers/gridspec.lisp` — GridSpec constructor, width_ratios, height_ratios

  **External References**:
  - Matplotlib gallery: `contourf_log.py`, `pie_features.py`, `stem_plot.py`, `gridspec_customization.py`, `shared_axis_demo.py`

  **Acceptance Criteria**:
  - [ ] 5 new files in `reference_scripts/` and `examples/`
  - [ ] Full SSIM comparison: 0 failures across all 37 examples
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 5 Batch D examples render and pass SSIM
    Tool: Bash
    Preconditions: Wave 1 complete
    Steps:
      1. Generate 5 reference images and render 5 CL examples
      2. Run full SSIM comparison
      3. Verify total=37, passed=37, failed=0
    Expected Result: All pass. No regressions.
    Failure Indicators: Any FAIL status
    Evidence: .sisyphus/evidence/task-5-batch-d-summary.json

  Scenario: Contour-filled-log renders without crash
    Tool: Bash
    Preconditions: contour-filled-log.lisp exists
    Steps:
      1. Render: setarch $(uname -m) -R ros run -- --noinform --load examples/contour-filled-log.lisp 2>/dev/null
      2. Check exit code: echo $?
      3. Verify output: test -f examples/contour-filled-log.png
    Expected Result: Exit code 0, PNG file exists (log-scaled contour rendered without error)
    Failure Indicators: Non-zero exit, missing PNG, or SSIM < 0.95
    Evidence: .sisyphus/evidence/task-5-contour-log-render.txt
  ```

  **Commit**: YES
  - Message: `feat(examples): add gallery batch D — contour, pie, gridspec variants`
  - Files: `reference_scripts/{5 new .py}`, `examples/{5 new .lisp}`, `examples/{5 new .png}`
  - Pre-commit: SSIM comparison passes with 0 failures

- [ ] 6. Phase 1 Bug Fixes — Fix Any Failing Examples

  **What to do**:
  After all 4 batches (Tasks 2-5), some new examples may fail SSIM at 0.95. This task fixes the rendering bugs in `src/` to make them pass.
  
  - Review `comparison_report/summary.json` for all examples with status "FAIL" or SSIM < 0.95
  - Review `comparison_report/index.html` to visually compare failing examples
  - For each failing example:
    1. Identify the visual difference (tick placement, label position, color mismatch, shape error, etc.)
    2. Locate the relevant `src/` code causing the issue
    3. Fix the bug with minimal, targeted changes
    4. Re-render the fixed example and verify SSIM ≥ 0.95
    5. Run full regression (ALL examples) to verify no regressions
    6. Commit the fix BEFORE moving to the next bug
  
  - If NO examples fail, skip this task entirely (mark as complete with note "no bugs found")

  **Must NOT do**:
  - Do NOT modify reference images to match CL output
  - Do NOT lower the SSIM threshold
  - Do NOT modify `tools/compare.py`
  - Do NOT modify `src/pyplot/pyplot.lisp` line 242
  - Do NOT make broad refactoring changes — fix the specific rendering issue only
  - Do NOT modify Python reference scripts to work around CL limitations

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Debugging rendering issues requires understanding the rendering pipeline, backend internals, and mathematical algorithms
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (sequential bug-fix-verify cycle)
  - **Parallel Group**: Wave 3 (solo)
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 4, 5 (all batches must be attempted first)

  **References**:

  **Pattern References**:
  - `src/backends/backend-vecto.lisp` — Draw-path, text rendering, y-offset (-0.7) — common source of rendering bugs
  - `src/rendering/lines.lisp` — Marker rendering, line styles — marker alias fixes were needed previously
  - `src/algorithms/marching-squares.lisp` — Contour algorithm — crossing order fix was needed previously
  - `src/containers/axes-base.lisp` — Axis limits, tick computation — scaling issues appear here

  **API/Type References**:
  - `comparison_report/summary.json` — Identify failing examples and their SSIM scores
  - `comparison_report/index.html` — Visual comparison (reference vs actual side-by-side)

  **External References**:
  - Prior bug fix commits: `4b886b0` (markers + contour), `5721ced` (y-axis label centering)
  - These show the pattern: identify visual diff → locate src code → minimal fix → verify

  **WHY Each Reference Matters**:
  - `backend-vecto.lisp`: Most rendering bugs originate here (draw-path handles all vector graphics)
  - `comparison_report/`: These are the primary diagnostic tools for identifying what's wrong
  - Prior commits: Show the established pattern for how bug fixes should be structured

  **Acceptance Criteria**:
  - [ ] `jq '.overall.failed' comparison_report/summary.json` → `0` (all examples pass)
  - [ ] Each bug fix has its own commit with full regression verification
  - [ ] step-plot SSIM still ≥ 0.955 (most fragile)
  - [ ] Unit tests still pass after each src/ change

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All examples pass after bug fixes
    Tool: Bash
    Preconditions: All 4 batches attempted, some may have failed
    Steps:
      1. jq '[.examples[] | select(.status=="FAIL")] | length' comparison_report/summary.json
      2. If 0: task complete, no bugs to fix
      3. If > 0: for each failing example, apply fix, re-render, run full comparison
      4. After all fixes: jq '.overall | {total, passed, failed}' comparison_report/summary.json
    Expected Result: failed=0, all examples pass
    Failure Indicators: Unable to fix a rendering issue to reach 0.95
    Evidence: .sisyphus/evidence/task-6-bug-fixes-summary.json

  Scenario: No regressions from bug fixes
    Tool: Bash
    Preconditions: Bug fixes applied to src/
    Steps:
      1. Run full regression: re-render all examples, run SSIM comparison
      2. Compare SSIM scores to baseline (Task 1 evidence)
      3. Verify no existing example dropped more than 0.01 SSIM
    Expected Result: All 27 original examples maintain their SSIM within 0.01 of baseline
    Failure Indicators: Any original example drops below 0.95
    Evidence: .sisyphus/evidence/task-6-regression-check.json
  ```

  **Commit**: YES (one commit per bug fix)
  - Message: `fix(rendering): {specific fix description} for {example name}`
  - Files: Specific `src/` files changed
  - Pre-commit: Full SSIM comparison passes with 0 failures

- [ ] 7. Phase 1 Checkpoint — Final Regression + Tag

  **What to do**:
  - Clear FASL cache completely
  - Re-render ALL examples (original 27 + new ~20)
  - Run final full SSIM comparison
  - Verify: 0 failures, total ≥ 47
  - Run unit test suite to verify no test regressions
  - Create a checkpoint commit with all Phase 1 work
  - Note the commit SHA for rollback if Phase 2 causes issues

  **Must NOT do**:
  - Do NOT start Phase 2 work in this task
  - Do NOT modify any files — this is validation + commit only

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Validation and commit — no code changes
  - **Skills**: [`git-master`]
    - `git-master`: Clean commit with appropriate message and tag

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (after Task 6)
  - **Blocks**: Task 8
  - **Blocked By**: Task 6

  **References**:
  - `comparison_report/summary.json` — Final verification
  - All `examples/*.lisp` and `reference_scripts/*.py` — Files to commit

  **Acceptance Criteria**:
  - [ ] `jq '.overall | {total, passed, failed}' comparison_report/summary.json` → `{total: ≥47, passed: ≥47, failed: 0}`
  - [ ] Unit tests pass: `ros run -- --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit`
  - [ ] Checkpoint commit exists with all Phase 1 files
  - [ ] Commit SHA recorded for rollback reference

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Phase 1 checkpoint is clean
    Tool: Bash
    Preconditions: Tasks 1-6 complete
    Steps:
      1. find src -name "*.fasl" -delete && rm -rf ~/.cache/common-lisp/
      2. Re-render all examples
      3. .venv/bin/python tools/compare.py --reference reference_images/ --actual examples/ --threshold 0.95 --output comparison_report/
      4. jq '.overall' comparison_report/summary.json
      5. ros run -- --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit
    Expected Result: 0 SSIM failures, 0 test failures, total ≥ 47
    Failure Indicators: Any failure
    Evidence: .sisyphus/evidence/task-7-phase1-checkpoint.json

  Scenario: Git state is clean after commit
    Tool: Bash
    Steps:
      1. git status
      2. git log --oneline -1
    Expected Result: Working tree clean, latest commit is Phase 1 checkpoint
    Evidence: .sisyphus/evidence/task-7-git-status.txt
  ```

  **Commit**: YES
  - Message: `feat(examples): complete Phase 1 gallery expansion — N examples total`
  - Files: Any uncommitted files from Tasks 2-6
  - Pre-commit: Full SSIM + unit tests pass

- [ ] 8. Phase 1 Review + Phase 2 Sign-Off Gate

  **What to do**:
  Present Phase 1 results and Phase 2 feature priorities to the user for review and sign-off.

  - Generate the comparison report HTML: `comparison_report/index.html`
  - Summarize results: total examples, pass rate, mean SSIM, any interesting observations
  - Present the Phase 2 feature priority list for user sign-off:

    **Tier 1 (Simple features, ~29 examples unlocked):**
    - `text()` pyplot wrapper — ~10 examples (bar labels, heatmap annotations, text placement, watermarks)
    - `axhline()`/`axvline()` — ~5 examples (reference lines, thresholds, grid markers)
    - `set_xticks()`/`set_xticklabels()`/`set_yticks()`/`set_yticklabels()` — ~8 examples (categorical variables, custom tick formatting)
    - `suptitle()`/`supxlabel()`/`supylabel()` — ~4 examples (figure-level titles)
    - `invert_xaxis()`/`invert_yaxis()` — ~2 examples (axis inversion)

    **Tier 2 (Medium features, ~10 examples unlocked):**
    - `twinx()`/`twiny()` — ~4 examples (dual y-axes, different scales on same plot)
    - `pcolormesh()` — ~3 examples (pseudocolor mesh, QuadMesh class already exists internally)
    - `axhspan()`/`axvspan()` — ~3 examples (region highlighting/shading)

    **Tier 3 (Complex features, ~13 examples unlocked):**
    - Polar projection — ~6 examples (requires new coordinate system)
    - Violin plots — ~3 examples (requires kernel density estimation)
    - Quiver/streamplot — ~4 examples (vector field rendering)

  - Ask user: Which tiers should we implement? Any priority changes? Any features to skip?
  - **THIS IS A USER GATE** — wait for explicit sign-off before proceeding to Tasks 9+

  **Must NOT do**:
  - Do NOT start implementing any Phase 2 features
  - Do NOT modify any files

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Report generation and user communication only
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (user gate)
  - **Parallel Group**: Wave 4 (solo — user gate)
  - **Blocks**: Tasks 9-13 (all Phase 2 work)
  - **Blocked By**: Task 7

  **References**:
  - `comparison_report/index.html` — Visual comparison report to show user
  - `comparison_report/summary.json` — Quantitative results

  **Acceptance Criteria**:
  - [ ] Phase 1 results presented to user
  - [ ] Phase 2 feature priorities presented with tier breakdown
  - [ ] User explicitly approves which tiers to implement
  - [ ] User sign-off recorded (Phase 2 can proceed)

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Phase 2 priorities are presented clearly
    Tool: Bash
    Preconditions: Phase 1 checkpoint complete
    Steps:
      1. cat comparison_report/summary.json | jq '.overall'
      2. Present Tier 1/2/3 breakdown with example counts
      3. Wait for user response
    Expected Result: User provides explicit approval for Phase 2 scope
    Failure Indicators: User requests changes to priorities or scope
    Evidence: .sisyphus/evidence/task-8-user-signoff.txt
  ```

  **Commit**: NO (no code changes)

- [ ] 9. Phase 2 Tier 1a — Implement text() pyplot wrapper

  **What to do**:
  Implement `text()` as a pyplot function that places arbitrary text on the current axes.

  - Add `text` to `src/pyplot/pyplot.lisp` as a new pyplot function
  - Signature: `(text x y s &key fontsize color alpha ha va rotation transform bbox)`
  - It should delegate to the axes-level text method (similar to how `annotate` works but simpler)
  - Add the corresponding axes method in `src/containers/axes.lisp` if not already present
  - The backend already renders text (used by title, labels, annotate) — this just needs a new entry point
  - Add unit tests for the new function
  - Run full regression after implementation

  **Must NOT do**:
  - Do NOT implement mathtext/LaTeX rendering
  - Do NOT implement text wrapping (`wrap=True`)
  - Do NOT implement `fig.text()` (figure-level text) — just axes-level `text()`
  - Do NOT break existing text rendering (titles, labels, annotations)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: New API function requiring understanding of the pyplot/axes/backend text pipeline
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 10-13)
  - **Parallel Group**: Wave 5 (all Tier 1 features)
  - **Blocks**: Task 14
  - **Blocked By**: Task 8 (user sign-off)

  **References**:

  **Pattern References**:
  - `src/pyplot/pyplot.lisp` — How existing pyplot functions are defined (e.g., `annotate` at line ~580+)
  - `src/containers/axes.lisp:894+` — `annotate` method showing text + arrow rendering pattern
  - `src/backends/backend-vecto.lisp:500-550` — `draw-text` and `draw-text-at-point` — the actual text rendering

  **API/Type References**:
  - `src/pyplot/pyplot.lisp` — Export list at top, defun pattern for pyplot functions
  - `src/containers/axes-base.lisp` — How axes store artists (text is an artist)
  - Matplotlib `Axes.text()`: `text(x, y, s, fontdict=None, **kwargs)` — x, y in data coords, s is string

  **External References**:
  - Matplotlib docs: `https://matplotlib.org/stable/api/_as_gen/matplotlib.axes.Axes.text.html`

  **WHY Each Reference Matters**:
  - `annotate` in pyplot.lisp: Shows the exact pattern for adding a new text-related pyplot function
  - `axes.lisp:894+`: Shows how annotate creates text objects — text() is simpler (no arrows)
  - `backend-vecto.lisp:500-550`: Shows the rendering endpoint — text() must produce objects this can render

  **Acceptance Criteria**:
  - [ ] `(text 0.5 0.5 "Hello")` places text at data coordinates (0.5, 0.5)
  - [ ] Keywords `:fontsize`, `:color`, `:ha`, `:va`, `:rotation` work
  - [ ] Unit tests pass for text() function
  - [ ] Full SSIM regression: 0 failures on existing examples
  - [ ] Existing title/label/annotation rendering unchanged

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: text() renders text at correct position
    Tool: Bash
    Preconditions: text() function implemented
    Steps:
      1. Create a minimal test script that calls (text 0.5 0.5 "Test" :fontsize 14 :color "red")
      2. Render the script
      3. Verify output PNG exists and is non-empty
    Expected Result: PNG contains visible red text at center of plot
    Failure Indicators: Crash, empty output, or text not visible
    Evidence: .sisyphus/evidence/task-9-text-render.png

  Scenario: No regression from text() addition
    Tool: Bash
    Steps:
      1. Run full SSIM comparison on all existing examples
      2. jq '.overall.failed' comparison_report/summary.json
    Expected Result: 0 failures
    Failure Indicators: Any existing example fails
    Evidence: .sisyphus/evidence/task-9-regression.json
  ```

  **Commit**: YES
  - Message: `feat(pyplot): add text() function for arbitrary text placement`
  - Files: `src/pyplot/pyplot.lisp`, `src/containers/axes.lisp` (if modified), test files
  - Pre-commit: Unit tests + SSIM regression pass

- [ ] 10. Phase 2 Tier 1b — Implement axhline/axvline/hlines/vlines

  **What to do**:
  Implement reference line functions:

  - `axhline(y, xmin, xmax, **kwargs)` — horizontal line spanning axes at y
  - `axvline(x, ymin, ymax, **kwargs)` — vertical line spanning axes at x
  - `hlines(y, xmin, xmax, **kwargs)` — multiple horizontal lines at data coordinates
  - `vlines(x, ymin, ymax, **kwargs)` — multiple vertical lines at data coordinates

  Implementation approach:
  - `axhline`/`axvline`: Draw lines using axes-fraction coordinates (0 to 1) for the span
  - `hlines`/`vlines`: Draw lines using data coordinates
  - All should support standard line kwargs: `color`, `linestyle`, `linewidth`, `alpha`, `label`
  - Add to both axes methods and pyplot interface
  - Add unit tests

  **Must NOT do**:
  - Do NOT implement `axline()` (arbitrary-slope lines) — more complex, fewer examples
  - Do NOT implement `broken_barh()` — different feature

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: New API functions that need correct coordinate transforms (axes-fraction vs data coords)
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9, 11-13)
  - **Parallel Group**: Wave 5
  - **Blocks**: Task 15
  - **Blocked By**: Task 8

  **References**:

  **Pattern References**:
  - `src/pyplot/pyplot.lisp` — pyplot function definition pattern
  - `src/containers/axes.lisp` — How plot methods add artists to axes
  - `src/rendering/lines.lisp` — Line rendering implementation (draw-line, line styles)

  **API/Type References**:
  - `src/containers/axes-base.lisp` — Axes limits, transforms (data → display coords)
  - Matplotlib: `axhline(y=0, xmin=0, xmax=1)` — xmin/xmax are axes-fraction (0-1), y is data coord

  **Acceptance Criteria**:
  - [ ] `(axhline 0.5)` draws horizontal line at y=0.5 spanning full axes width
  - [ ] `(axvline 0.5)` draws vertical line at x=0.5 spanning full axes height
  - [ ] `(hlines '(1 2 3) 0 10)` draws three horizontal lines from x=0 to x=10
  - [ ] `(vlines '(1 2 3) 0 10)` draws three vertical lines from y=0 to y=10
  - [ ] Keywords work: `:color`, `:linestyle`, `:linewidth`, `:alpha`, `:label`
  - [ ] Full SSIM regression: 0 failures

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: axhline/axvline render at correct positions
    Tool: Bash
    Steps:
      1. Create test script: (plot '(0 10) '(0 10)) (axhline 5 :color "red") (axvline 5 :color "blue")
      2. Create matching Python reference
      3. Render both, run SSIM comparison
    Expected Result: SSIM ≥ 0.95 — lines at correct data coordinates
    Evidence: .sisyphus/evidence/task-10-axlines-test.png

  Scenario: No regression
    Tool: Bash
    Steps:
      1. Full SSIM comparison
    Expected Result: 0 failures
    Evidence: .sisyphus/evidence/task-10-regression.json
  ```

  **Commit**: YES
  - Message: `feat(pyplot): add axhline, axvline, hlines, vlines reference line functions`
  - Files: `src/pyplot/pyplot.lisp`, `src/containers/axes.lisp`, test files
  - Pre-commit: Unit tests + SSIM regression pass

- [ ] 11. Phase 2 Tier 1c — Implement suptitle/supxlabel/supylabel

  **What to do**:
  Implement figure-level title and axis labels:

  - `suptitle(t, **kwargs)` — centered title above all subplots
  - `supxlabel(t, **kwargs)` — centered x-label below all subplots
  - `supylabel(t, **kwargs)` — centered y-label to the left of all subplots

  Implementation approach:
  - These render text at figure level (not axes level)
  - Use existing text rendering from backend, but position in figure coordinates
  - `suptitle`: x=0.5, y=0.98 in figure coords, horizontally centered
  - `supxlabel`: x=0.5, y=0.02 in figure coords
  - `supylabel`: x=0.02, y=0.5 in figure coords, rotated 90°

  **Must NOT do**:
  - Do NOT implement complex layout adjustment (constrained_layout, tight_layout auto-adjustment)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple text rendering at known figure coordinates — reuses existing text infrastructure
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9, 10, 12, 13)
  - **Parallel Group**: Wave 5
  - **Blocks**: Task 16
  - **Blocked By**: Task 8

  **References**:

  **Pattern References**:
  - `src/containers/figure.lisp` — Figure class, existing methods (savefig, etc.)
  - `src/backends/backend-vecto.lisp:500-550` — Text rendering (draw-text-at-point)

  **API/Type References**:
  - `src/pyplot/pyplot.lisp` — pyplot function pattern for figure-level operations
  - Matplotlib: `fig.suptitle('Title', fontsize=14)`

  **Acceptance Criteria**:
  - [ ] `(suptitle "Main Title")` renders centered text above subplot grid
  - [ ] Works correctly with single plot and multi-subplot layouts
  - [ ] `:fontsize`, `:color` kwargs work
  - [ ] Full SSIM regression: 0 failures

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: suptitle renders above subplots
    Tool: Bash
    Steps:
      1. Create test: (subplots 2 2) (suptitle "Main Title" :fontsize 16) (savefig ...)
      2. Create matching Python reference
      3. Compare SSIM
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-11-suptitle-test.png
  ```

  **Commit**: YES
  - Message: `feat(pyplot): add suptitle, supxlabel, supylabel figure-level labels`
  - Files: `src/pyplot/pyplot.lisp`, `src/containers/figure.lisp`, test files

- [ ] 12. Phase 2 Tier 1d — Implement invert_xaxis/invert_yaxis

  **What to do**:
  Implement axis inversion methods:

  - `invert_xaxis()` — reverse x-axis direction (high to low)
  - `invert_yaxis()` — reverse y-axis direction (high to low)

  Implementation approach:
  - Add methods to axes-base that swap the axis limits (set xlim to (max, min))
  - Add pyplot wrappers that call these on gca()
  - This should integrate with existing `axes-set-xlim`/`axes-set-ylim`

  **Must NOT do**:
  - Do NOT implement `set_aspect()` in this task (separate concern)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple axis limit manipulation — swap min/max
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9-11, 13)
  - **Parallel Group**: Wave 5
  - **Blocks**: Task 16
  - **Blocked By**: Task 8

  **References**:

  **Pattern References**:
  - `src/containers/axes-base.lisp` — `axes-set-xlim`, `axes-set-ylim` — the functions that set axis limits

  **Acceptance Criteria**:
  - [ ] `(invert-xaxis)` reverses x-axis (ticks go from high to low)
  - [ ] `(invert-yaxis)` reverses y-axis
  - [ ] Works correctly with auto-scaled and manually-set limits
  - [ ] Full SSIM regression: 0 failures

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Inverted axis renders correctly
    Tool: Bash
    Steps:
      1. Create test with inverted y-axis and matching Python reference
      2. Compare SSIM
    Expected Result: SSIM ≥ 0.95, y-axis ticks decrease from bottom to top
    Evidence: .sisyphus/evidence/task-12-invert-test.png
  ```

  **Commit**: YES
  - Message: `feat(axes): implement invert_xaxis and invert_yaxis`
  - Files: `src/containers/axes-base.lisp`, `src/pyplot/pyplot.lisp`, test files

- [ ] 13. Phase 2 Tier 1e — Implement set_xticks/set_xticklabels/set_yticks/set_yticklabels

  **What to do**:
  Implement manual tick control methods:

  - `set_xticks(ticks, labels=None)` — set explicit x-axis tick positions (and optionally labels)
  - `set_xticklabels(labels)` — set x-axis tick label strings
  - `set_yticks(ticks, labels=None)` — set explicit y-axis tick positions
  - `set_yticklabels(labels)` — set y-axis tick label strings

  Implementation approach:
  - Add methods to axes that override the auto-tick computation
  - When `set_xticks` is called, store the tick positions and skip auto-tick generation
  - When `set_xticklabels` is called, map provided strings to tick positions
  - This enables categorical x-axes (e.g., bar charts with category names)
  - Add pyplot wrappers

  **Must NOT do**:
  - Do NOT implement tick formatters (FuncFormatter, StrMethodFormatter, etc.)
  - Do NOT implement minor ticks — major ticks only
  - Do NOT implement tick rotation in this task (that's a label property)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Requires understanding the tick computation pipeline and overriding it correctly
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 9-12)
  - **Parallel Group**: Wave 5
  - **Blocks**: Task 16
  - **Blocked By**: Task 8

  **References**:

  **Pattern References**:
  - `src/containers/axes-base.lisp` — Current tick computation (auto-scaling, tick generation)
  - `src/containers/scale.lisp` — Scale-dependent tick generation (linear tick locator, log tick locator)

  **API/Type References**:
  - Matplotlib: `ax.set_xticks([0, 1, 2], ['A', 'B', 'C'])` — positions + labels in one call
  - `src/backends/backend-vecto.lisp` — How tick labels are rendered (draw-text-at-point)

  **Acceptance Criteria**:
  - [ ] `(set-xticks '(1 2 3))` places ticks at exactly x=1, 2, 3
  - [ ] `(set-xticks '(1 2 3) :labels '("A" "B" "C"))` places labeled ticks
  - [ ] `(set-xticklabels '("Mon" "Tue" "Wed"))` sets tick label text
  - [ ] Same for y-axis variants
  - [ ] Full SSIM regression: 0 failures

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Custom tick labels render correctly
    Tool: Bash
    Steps:
      1. Create test: bar chart with categorical labels via set_xticks
      2. Create matching Python reference
      3. Compare SSIM
    Expected Result: SSIM ≥ 0.95, custom labels visible at correct positions
    Evidence: .sisyphus/evidence/task-13-ticks-test.png

  Scenario: Existing auto-tick examples unchanged
    Tool: Bash
    Steps:
      1. Run full SSIM comparison
    Expected Result: 0 failures — auto-tick path not broken
    Evidence: .sisyphus/evidence/task-13-regression.json
  ```

  **Commit**: YES
  - Message: `feat(axes): implement set_xticks, set_xticklabels, set_yticks, set_yticklabels`
  - Files: `src/containers/axes-base.lisp`, `src/pyplot/pyplot.lisp`, test files

- [ ] 14. Phase 2 Tier 1 Gallery — Examples Using text()

  **What to do**:
  Write Python reference scripts and CL example scripts for gallery examples that use `text()`:

  1. **annotated-heatmap** — Heatmap with cell value annotations using text()
     - Python: `ax.imshow(data)` + loop of `ax.text(j, i, f"{data[i,j]:.1f}", ha="center", va="center")`
     - CL: `(imshow data)` + loop of `(text j i (format nil "~,1F" val) :ha "center" :va "center")`
  
  2. **text-watermark** — Semi-transparent text watermark
     - Python: `fig.text(0.5, 0.5, "DRAFT", fontsize=40, alpha=0.2, ha="center", va="center", rotation=30)`
     - CL: Need fig-level text — if not implemented, use axes-level with axes coords
  
  3. **text-alignment** — Text horizontal/vertical alignment demo
     - Python: Multiple `ax.text()` calls demonstrating ha/va combinations
     - CL: Multiple `(text ...)` calls with `:ha` and `:va` kwargs
  
  4. **bar-labels** — Bar chart with value labels on top of bars
     - Python: `ax.bar()` + loop of `ax.text(x, height, str(height), ha='center', va='bottom')`
     - CL: `(bar ...)` + loop of `(text ...)` for each bar value
  
  5. **subplot-labels** — Subplots with panel labels (a), (b), (c), (d)
     - Python: `ax.text(0.05, 0.95, "(a)", transform=ax.transAxes, va='top')`
     - CL: `(text ...)` with axes-coordinate transform

  **Must NOT do**:
  - Do NOT implement mathtext or LaTeX
  - Do NOT implement text wrapping
  - If fig.text() is needed, note it as a limitation and adapt the example

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Multiple examples requiring the newly implemented text() function
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 15, 16)
  - **Parallel Group**: Wave 6
  - **Blocks**: Tasks 17-19
  - **Blocked By**: Task 9

  **References**:
  - Task 9 implementation (text() function)
  - Existing heatmap: `examples/imshow-heatmap.lisp` — base pattern
  - Matplotlib gallery: `image_annotated_heatmap.py`, `watermark_text.py`, `text_alignment.py`

  **Acceptance Criteria**:
  - [ ] 5 new example pairs created
  - [ ] Full SSIM comparison: 0 failures
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 5 text() examples render and pass SSIM
    Tool: Bash
    Steps:
      1. Generate 5 reference images, render 5 CL examples
      2. Run full SSIM comparison
      3. Verify 0 failures
    Expected Result: All pass, total count increases by 5
    Evidence: .sisyphus/evidence/task-14-text-examples.json
  ```

  **Commit**: YES
  - Message: `feat(examples): add gallery examples using text() — heatmap annotations, watermarks, labels`
  - Files: `reference_scripts/{5 .py}`, `examples/{5 .lisp}`, `examples/{5 .png}`

- [ ] 15. Phase 2 Tier 1 Gallery — Examples Using axhline/axvline

  **What to do**:
  Write Python reference scripts and CL example scripts for gallery examples that use reference lines:

  1. **hlines-vlines** — Demo of hlines() and vlines() at multiple positions
     - Python: `ax.hlines([1, 2, 3], 0, 10, colors=['red', 'blue', 'green'])` + `ax.vlines(...)`
     - CL: `(hlines '(1 2 3) 0 10 :colors '("red" "blue" "green"))` + `(vlines ...)`
  
  2. **threshold-lines** — Line plot with horizontal threshold reference lines
     - Python: `ax.plot(data)` + `ax.axhline(mean, color='red', linestyle='--')` + `ax.axhline(mean+std, ...)`
     - CL: `(plot data)` + `(axhline mean :color "red" :linestyle "--")`
  
  3. **reference-grid** — Custom reference line grid using axhline/axvline
     - Python: Multiple `ax.axhline()` and `ax.axvline()` calls with alpha
     - CL: Multiple `(axhline ...)` and `(axvline ...)` calls

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 14, 16)
  - **Parallel Group**: Wave 6
  - **Blocks**: Tasks 17-19
  - **Blocked By**: Task 10

  **References**:
  - Task 10 implementation (axhline/axvline/hlines/vlines)
  - Matplotlib gallery: `vline_hline_demo.py`

  **Acceptance Criteria**:
  - [ ] 3 new example pairs created
  - [ ] Full SSIM comparison: 0 failures
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Reference line examples pass SSIM
    Tool: Bash
    Steps:
      1. Generate references, render CL, compare SSIM
    Expected Result: All 3 new examples ≥ 0.95, 0 total failures
    Evidence: .sisyphus/evidence/task-15-axlines-examples.json
  ```

  **Commit**: YES
  - Message: `feat(examples): add gallery examples using axhline/axvline/hlines/vlines`

- [ ] 16. Phase 2 Tier 1 Gallery — Examples Using suptitle, invert_axis, set_xticks

  **What to do**:
  Write examples using the remaining Tier 1 features:

  1. **figure-labels** — Figure with suptitle, supxlabel, supylabel + 2×2 subplots
     - Python: `fig.suptitle("Main")`, `fig.supxlabel("X")`, `fig.supylabel("Y")`
     - CL: `(suptitle "Main")`, `(supxlabel "X")`, `(supylabel "Y")`
  
  2. **inverted-axes** — Scatter plot with inverted y-axis (common for depth/altitude)
     - Python: `ax.scatter(...)` + `ax.invert_yaxis()`
     - CL: `(scatter ...)` + `(invert-yaxis)`
  
  3. **categorical-bar** — Bar chart with categorical x-axis labels
     - Python: `ax.bar(x, heights)` + `ax.set_xticks(x, labels=['Mon','Tue','Wed','Thu','Fri'])`
     - CL: `(bar x heights)` + `(set-xticks x :labels '("Mon" "Tue" "Wed" "Thu" "Fri"))`
  
  4. **custom-ticks** — Plot with custom major tick positions and labels
     - Python: `ax.set_xticks([0, pi/2, pi, 3*pi/2, 2*pi], ['0', 'π/2', 'π', '3π/2', '2π'])`
     - CL: Custom tick labels for a sine curve

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 14, 15)
  - **Parallel Group**: Wave 6
  - **Blocks**: Tasks 17-19
  - **Blocked By**: Tasks 11, 12, 13

  **References**:
  - Tasks 11, 12, 13 implementations
  - Matplotlib gallery: `figure_title.py`, `invert_axes.py`, `categorical_variables.py`

  **Acceptance Criteria**:
  - [ ] 4 new example pairs created
  - [ ] Full SSIM comparison: 0 failures
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Tier 1 remaining examples pass SSIM
    Tool: Bash
    Steps:
      1. Generate references, render CL, compare SSIM
    Expected Result: All 4 new examples ≥ 0.95, 0 total failures
    Evidence: .sisyphus/evidence/task-16-tier1-remaining.json
  ```

  **Commit**: YES
  - Message: `feat(examples): add gallery examples using suptitle, invert_axis, set_xticks`

- [ ] 17. Phase 2 Tier 2a — Implement twinx/twiny

  **What to do**:
  Implement dual-axis functions:

  - `twinx()` — create a second y-axis sharing the same x-axis
  - `twiny()` — create a second x-axis sharing the same y-axis

  Implementation approach:
  - Create a new axes object that shares one axis with the parent
  - The twin axes overlays the parent (same position, same x-limits for twinx)
  - The twin gets its own y-axis on the right side (for twinx) or x-axis on top (for twiny)
  - The twin's spine on the shared side is hidden
  - Both axes render to the same figure area
  - This is the most architecturally complex Tier 2 feature

  **Must NOT do**:
  - Do NOT implement `secondary_xaxis()`/`secondary_yaxis()` (different API, transform-based)
  - Do NOT break the existing twin-axes.lisp example (it uses side-by-side subplots, not true twinx)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Requires understanding axes lifecycle, rendering order, and coordinate transforms
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 18, 19)
  - **Parallel Group**: Wave 7
  - **Blocks**: Task 20
  - **Blocked By**: Tasks 14, 15, 16 (Wave 6 must complete)

  **References**:

  **Pattern References**:
  - `src/containers/figure.lisp` — How axes are added to figures
  - `src/containers/axes-base.lisp` — Axes construction, position, transforms
  - `src/containers/axes.lisp` — High-level axes methods

  **API/Type References**:
  - Matplotlib: `ax2 = ax1.twinx()` — returns new Axes sharing x-axis
  - `src/backends/backend-vecto.lisp` — How multiple axes are rendered (draw order)

  **Acceptance Criteria**:
  - [ ] `(twinx)` returns a new axes sharing x-axis with current axes
  - [ ] Twin y-axis appears on right side
  - [ ] Data plotted on twin uses twin's y-scale independently
  - [ ] Twin works correctly with subplots
  - [ ] Full SSIM regression: 0 failures

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: twinx creates dual y-axis plot
    Tool: Bash
    Steps:
      1. Create test: (plot x y1 :color "blue") (let ((ax2 (twinx))) (plot-on ax2 x y2 :color "red"))
      2. Create matching Python reference
      3. Compare SSIM
    Expected Result: SSIM ≥ 0.95, two y-axes visible, data on correct scales
    Evidence: .sisyphus/evidence/task-17-twinx-test.png

  Scenario: Existing twin-axes example unchanged
    Tool: Bash
    Steps:
      1. Re-render twin-axes.lisp, check SSIM hasn't changed
    Expected Result: twin-axes SSIM stable (still uses subplots, not twinx)
    Evidence: .sisyphus/evidence/task-17-twin-axes-regression.txt
  ```

  **Commit**: YES
  - Message: `feat(axes): implement twinx and twiny for dual-axis plots`
  - Files: `src/containers/axes-base.lisp`, `src/containers/figure.lisp`, `src/pyplot/pyplot.lisp`, test files

- [ ] 18. Phase 2 Tier 2b — Implement pcolormesh

  **What to do**:
  Implement `pcolormesh()` for pseudocolor mesh plots:

  - `pcolormesh(X, Y, C, **kwargs)` — pseudocolor plot of 2D array on quadrilateral grid
  - Alternatively `pcolormesh(C)` — use implicit grid coordinates

  Implementation approach:
  - QuadMesh class already exists internally (`src/rendering/collections.lisp`)
  - Need to expose it via pyplot + axes interface
  - Support kwargs: `cmap`, `vmin`, `vmax`, `alpha`, `shading` ('flat' or 'gouraud')
  - Should work with `colorbar()`

  **Must NOT do**:
  - Do NOT implement `pcolor()` (slower, more general — pcolormesh is sufficient)
  - Do NOT implement Gouraud shading initially (start with flat shading only)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Requires understanding the QuadMesh internals and colormap pipeline
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 17, 19)
  - **Parallel Group**: Wave 7
  - **Blocks**: Task 20
  - **Blocked By**: Tasks 14, 15, 16

  **References**:

  **Pattern References**:
  - `src/rendering/collections.lisp` — Existing QuadMesh class
  - `src/plotting/contour.lisp` — How contourf builds collections (similar mesh data flow)
  - `src/containers/colorbar.lisp` — Colorbar integration pattern

  **API/Type References**:
  - Matplotlib: `ax.pcolormesh(X, Y, C, cmap='viridis', shading='flat')`

  **Acceptance Criteria**:
  - [ ] `(pcolormesh data :cmap "viridis")` renders a pseudocolor mesh
  - [ ] Works with colorbar: `(pcolormesh data) (colorbar)`
  - [ ] Flat shading works correctly
  - [ ] Full SSIM regression: 0 failures

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: pcolormesh renders 2D data correctly
    Tool: Bash
    Steps:
      1. Create test with 2D array, render pcolormesh + colorbar
      2. Create matching Python reference
      3. Compare SSIM
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-18-pcolormesh-test.png
  ```

  **Commit**: YES
  - Message: `feat(pyplot): add pcolormesh for pseudocolor mesh plots`
  - Files: `src/pyplot/pyplot.lisp`, `src/containers/axes.lisp`, `src/rendering/collections.lisp`, test files

- [ ] 19. Phase 2 Tier 2c — Implement axhspan/axvspan

  **What to do**:
  Implement region highlighting functions:

  - `axhspan(ymin, ymax, **kwargs)` — horizontal span (shaded region) between two y values
  - `axvspan(xmin, xmax, **kwargs)` — vertical span (shaded region) between two x values

  Implementation approach:
  - Draw filled rectangles spanning the full axes width (axhspan) or height (axvspan)
  - Support: `alpha`, `color`, `facecolor`, `edgecolor`, `label`
  - xmin/xmax for axhspan and ymin/ymax for axvspan are in axes-fraction coordinates (0 to 1)
  - This is similar to fill_between but with fixed rectangular regions

  **Must NOT do**:
  - Do NOT implement clipping or complex span shapes

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Similar to axhline/axvline but with filled regions instead of lines
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Tasks 17, 18)
  - **Parallel Group**: Wave 7
  - **Blocks**: Task 20
  - **Blocked By**: Tasks 14, 15, 16

  **References**:

  **Pattern References**:
  - Task 10 implementation (axhline/axvline — similar coordinate handling)
  - `src/pyplot/pyplot.lisp` — fill_between implementation (similar filled area concept)

  **Acceptance Criteria**:
  - [ ] `(axhspan 0.3 0.7 :alpha 0.3 :color "yellow")` highlights horizontal region
  - [ ] `(axvspan 2 4 :alpha 0.3 :color "blue")` highlights vertical region
  - [ ] Works with other plot elements (lines, scatter on top)
  - [ ] Full SSIM regression: 0 failures

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: axhspan/axvspan render highlighted regions
    Tool: Bash
    Steps:
      1. Create test with plot + highlighted regions
      2. Compare with Python reference
    Expected Result: SSIM ≥ 0.95
    Evidence: .sisyphus/evidence/task-19-spans-test.png
  ```

  **Commit**: YES
  - Message: `feat(pyplot): add axhspan, axvspan for region highlighting`
  - Files: `src/pyplot/pyplot.lisp`, `src/containers/axes.lisp`, test files

- [ ] 20. Phase 2 Tier 2 Gallery — Examples Using twinx, pcolormesh, axhspan

  **What to do**:
  Write gallery examples using Tier 2 features:

  1. **twin-y-axis** — True dual y-axis plot (temperature + precipitation, similar data to existing twin-axes but using real twinx)
     - Python: `ax1.plot(...)`, `ax2 = ax1.twinx()`, `ax2.plot(...)`
     - CL: `(plot ...)`, `(let ((ax2 (twinx))) ...)`
  
  2. **pcolormesh-basic** — Basic pseudocolor mesh with colorbar
     - Python: `ax.pcolormesh(X, Y, Z, cmap='viridis')`, `fig.colorbar()`
     - CL: `(pcolormesh X Y Z :cmap "viridis")`, `(colorbar)`
  
  3. **span-regions** — Plot with highlighted regions using axhspan/axvspan
     - Python: `ax.plot(data)` + `ax.axhspan(...)` + `ax.axvspan(...)`
     - CL: `(plot data)` + `(axhspan ...)` + `(axvspan ...)`
  
  4. **two-scales** — Different scales on same axes (from matplotlib gallery)
     - Python: Classic twinx example from matplotlib
     - CL: Using twinx implementation

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO (needs all Tier 2 features)
  - **Parallel Group**: Wave 8 (solo)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 17, 18, 19

  **References**:
  - Tasks 17, 18, 19 implementations
  - Matplotlib gallery: `two_scales.py`, `pcolormesh_grids.py`, `span_regions.py`

  **Acceptance Criteria**:
  - [ ] 4 new example pairs created
  - [ ] Full SSIM comparison: 0 failures
  - [ ] Each new example SSIM ≥ 0.95

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All Tier 2 gallery examples pass SSIM
    Tool: Bash
    Steps:
      1. Generate references, render CL, compare SSIM
    Expected Result: All 4 new examples ≥ 0.95, 0 total failures
    Evidence: .sisyphus/evidence/task-20-tier2-examples.json
  ```

  **Commit**: YES
  - Message: `feat(examples): add gallery examples using twinx, pcolormesh, axhspan/axvspan`

---

## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, check SSIM, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run full unit test suite. Review all changed `src/` files for: untested code paths, missing error handling, style inconsistencies with existing code. Check new examples follow the `defpackage #:example` pattern. Check reference scripts include required rcParams.
  Output: `Tests [N pass/N fail] | Style [N clean/N issues] | VERDICT`

- [ ] F3. **Full SSIM QA — All Examples** — `unspecified-high`
  Clear FASL cache. Re-render ALL examples (existing + new). Run full SSIM comparison. Verify: 0 failures, total count matches expected, step-plot still above 0.955. Generate comparison_report/index.html.
  Output: `Total [N] | Passed [N] | Failed [N] | Min SSIM [X] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual changes (git diff). Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance. Verify Phase 2 features are gated on user sign-off. Detect cross-task contamination.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | VERDICT`

---

## Commit Strategy

- **Per-batch commits**: After each batch of 5 examples passes SSIM, commit all new files
  - `feat(examples): add gallery batch A — scales and simple plots`
  - `feat(examples): add gallery batch B — scatter and fill variants`
  - etc.
- **Bug fix commits**: Each `src/` bug fix gets its own commit BEFORE continuing example work
  - `fix(rendering): correct {specific issue} for {example name}`
- **Phase 1 checkpoint**: Tagged commit after all Phase 1 examples pass
  - `feat(examples): complete Phase 1 gallery expansion (47 examples)`
- **Phase 2 feature commits**: One commit per feature implementation
  - `feat(pyplot): add text() function for arbitrary text placement`
  - `feat(axes): implement axhline/axvline reference line functions`
- **Phase 2 example commits**: Batch commits for examples using new features
  - `feat(examples): add gallery examples using text() and axhline`

---

## Success Criteria

### Verification Commands
```bash
# Phase 1 complete
jq '{total: .overall.total, passed: .overall.passed, failed: .overall.failed}' comparison_report/summary.json
# Expected: {"total": >=47, "passed": >=47, "failed": 0}

# All unit tests pass
ros run -- --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit
# Expected: 0 failures

# Step-plot margin check
jq '.examples[] | select(.name=="step-plot") | .ssim' comparison_report/summary.json
# Expected: >= 0.955
```

### Final Checklist
- [ ] All "Must Have" present (template patterns, regression gates, etc.)
- [ ] All "Must NOT Have" absent (no modified reference images, no lowered threshold)
- [ ] All unit tests pass (SBCL + CCL)
- [ ] All SSIM comparisons pass at 0.95 threshold
- [ ] Phase 1 checkpoint commit exists
- [ ] User sign-off recorded for Phase 2 priorities
- [ ] No new CL library dependencies introduced
