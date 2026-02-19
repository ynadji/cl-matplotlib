# Visual Regression Testing & Bug Fixing for cl-matplotlib

## TL;DR

> **Quick Summary**: Build automated comparison infrastructure (Python matplotlib reference images + SSIM scoring), systematically fix 6 categories of rendering bugs, then expand to a comprehensive 27-example gallery — all passing SSIM > 0.90 against Python matplotlib.
> 
> **Deliverables**:
> - Python comparison tooling (pyenv venv, reference generation, SSIM comparison, side-by-side diffs)
> - Makefile targets: `make setup-python`, `make reference-images`, `make cl-images`, `make compare`, `make report`
> - Fixes for 6 rendering bug categories (background, text, patches, collections, contour, layout)
> - 27 total examples (7 existing + 20 new) with matching Python references
> - All examples achieving SSIM > 0.90 against Python matplotlib output
> 
> **Estimated Effort**: Large (2-3 weeks)
> **Parallel Execution**: YES — 6 waves
> **Critical Path**: Setup → Comparison Infra → Bug Fixes (sequential) → Gallery Expansion → Final Verification

---

## Context

### Original Request
The cl-matplotlib library is feature-complete but the 7 existing example images are visually incorrect. User wants: (1) automated comparison infrastructure against Python matplotlib, (2) systematic bug fixing guided by the comparison results, and (3) a comprehensive example gallery of 27 examples all passing visual comparison.

### Interview Summary
**Key Discussions**:
- Library is feature-complete (Phases 0-7, 2,507 tests passing) but visual output has 6 categories of bugs
- Comparison infra FIRST, then bug fixes (TDD-like approach)
- pyenv for Python env, automated SSIM comparison, Makefile targets
- SSIM threshold: 0.90 (moderate — accounts for different rasterizers)
- Comprehensive gallery: expand from 7 to 27 examples

**Research Findings**:
- Line2D rendering works, but Patches, Collections, and Text are broken
- Legend text renders because it passes fontsize via `:linewidth` — other text paths don't
- Bar chart shows steelblue fill (the bar color!) — patches ARE rendering but with wrong transforms
- `to-rgba` may return a vector, and callers using `multiple-value-list` corrupt the RGBA values — likely root cause of black backgrounds
- CL uses Liberation Sans vs Python's DejaVu Sans — font mismatch affects SSIM
- Existing CL image comparison infra in `src/testing/` — new Python tooling supplements it

### Metis Review
**Identified Gaps** (addressed):
- **`to-rgba` return type corruption**: `multiple-value-list` on vector return gives `(#(r g b a))` not `(r g b a)` — explains black background. Added as first bug fix.
- **Bar chart transform bug misdiagnosed**: Bars ARE rendering (steelblue fill proves it) but with wrong transforms. Changed from "patches don't render" to "patch transform composition bug."
- **Text rendering deeper than fontsize**: Even with 12pt default, text invisible — something prevents draw-text from being called for axis labels. Added diagnostic step.
- **Font mismatch**: CL uses Liberation Sans, Python uses DejaVu Sans. Plan normalizes fonts for fair comparison.
- **Existing CL testing infra**: `src/testing/compare.lisp` already exists. New Python SSIM supplements (not replaces) it.
- **Bug fix order matters**: Fix `to-rgba` callers first (fixes background), then text, then patches, then collections, then layout. Each depends on the previous.

---

## Work Objectives

### Core Objective
Build automated visual comparison infrastructure against Python matplotlib, fix all rendering bugs so the 7 existing examples render correctly, and create a comprehensive gallery of 27 examples all achieving SSIM > 0.90.

### Concrete Deliverables
- `.venv/` Python environment with matplotlib + scikit-image
- `tools/compare.py` — SSIM comparison + side-by-side diff generation
- `reference_scripts/` — Python equivalents of all 27 examples
- `reference_images/` — Python matplotlib output for all 27 examples
- `Makefile` with `setup-python`, `reference-images`, `cl-images`, `compare`, `report` targets
- Bug fixes across rendering pipeline (6 categories)
- 20 new example scripts in `examples/`
- `comparison_report/` — HTML report with SSIM scores and side-by-side diffs

### Definition of Done
- [ ] `make setup-python` creates working venv with matplotlib + scikit-image
- [ ] `make reference-images` generates Python reference PNGs for all 27 examples
- [ ] `make cl-images` generates CL PNGs for all 27 examples without errors
- [ ] `make compare` produces comparison report with SSIM scores
- [ ] ALL 27 examples achieve SSIM > 0.90 against Python references
- [ ] Full CL test suite still passes after all bug fixes (0 regressions)

### Must Have
- Python comparison tooling (SSIM + visual diff)
- Makefile-driven workflow
- Fixes for: black background, missing text, broken patches, broken collections, broken contour, layout issues
- 27 working examples (7 fixed + 20 new)
- Matching Python reference scripts for all 27

### Must NOT Have (Guardrails)
- NO refactoring of fontsize-via-linewidth pattern — use quick fix (pass fontsize as linewidth everywhere)
- NO CI integration for comparison workflow (that's a future task)
- NO examples for unimplemented features (3D, animation, polar, interactive)
- NO changes to Python reference scripts during bug-fix phase
- NO Roswell dependency — all CL examples use `sbcl --load` directly
- NO ImageMagick dependency — use Python PIL/scikit-image only
- NO modifications to the existing CL test infrastructure in `src/testing/`
- NO fixing more than one bug category per task/commit
- NO over-engineering the comparison tool (simple Python script, not a framework)

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (FiveAM, 2,507 tests)
- **Automated tests**: YES (Tests-after — fix bugs, then verify via SSIM comparison)
- **Framework**: SSIM comparison via Python scikit-image + existing FiveAM tests for regression

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Comparison infra**: Use Bash — run Makefile targets, verify outputs exist and are valid
- **Bug fixes**: Use Bash — run `make compare`, check SSIM deltas, run CL test suite
- **Gallery examples**: Use Bash — generate images, run comparison, verify SSIM > 0.90

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Setup — 3 parallel, quick):
├── Task 1: Python environment setup (pyenv + venv) [quick]
├── Task 2: Diagnostic audit — verify to-rgba return type, find all broken callers [quick]
└── Task 3: Directory structure + Makefile skeleton [quick]

Wave 2 (Comparison Infrastructure — 3 parallel):
├── Task 4: Python reference scripts for 7 existing examples [unspecified-high]
├── Task 5: Comparison tool (compare.py with SSIM, diff images, report) [deep]
└── Task 6: Complete Makefile + run initial comparison baseline [quick]

Wave 3 (Bug Fixes — sequential, depends on Wave 2):
├── Task 7: Fix to-rgba return handling across codebase (depends: 2) [deep]
├── Task 8: Fix text rendering pipeline (depends: 7) [deep]
├── Task 9: Fix patch/rectangle transforms (depends: 7) [deep]
├── Task 10: Fix collection rendering — scatter + contour (depends: 7) [deep]
└── Task 11: Fix layout issues — pie centering, clipping (depends: 8,9,10) [unspecified-high]

Wave 4 (Gallery Expansion — 3 parallel batches + refs):
├── Task 12: Gallery batch A — 7 basic plot type examples [unspecified-high]
├── Task 13: Gallery batch B — 6 advanced feature examples [unspecified-high]
└── Task 14: Gallery batch C — 7 style/config/layout examples [unspecified-high]

Wave 5 (Gallery References + Comparison):
└── Task 15: Python reference scripts + comparison for all 20 new examples [unspecified-high]

Wave FINAL (Verification — 4 parallel):
├── Task F1: Plan compliance audit [oracle]
├── Task F2: Code quality review [unspecified-high]
├── Task F3: Full comparison report — all 27 examples SSIM verification [unspecified-high]
└── Task F4: Scope fidelity check [deep]

Critical Path: Task 1 → Task 5 → Task 6 → Task 7 → Task 8-11 → Task 12-14 → Task 15 → F1-F4
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 3 (Waves 1, 2, 4)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|------------|--------|------|
| 1 | None | 4, 5, 6 | 1 |
| 2 | None | 7 | 1 |
| 3 | None | 6 | 1 |
| 4 | 1 | 6 | 2 |
| 5 | 1 | 6 | 2 |
| 6 | 3, 4, 5 | 7 | 2 |
| 7 | 2, 6 | 8, 9, 10 | 3 |
| 8 | 7 | 11 | 3 |
| 9 | 7 | 11 | 3 |
| 10 | 7 | 11 | 3 |
| 11 | 8, 9, 10 | 12-14 | 3 |
| 12 | 11 | 15 | 4 |
| 13 | 11 | 15 | 4 |
| 14 | 11 | 15 | 4 |
| 15 | 12, 13, 14 | F1-F4 | 5 |
| F1-F4 | 15 | None | FINAL |

### Agent Dispatch Summary

- **Wave 1**: **3** — T1 → `quick`, T2 → `quick`, T3 → `quick`
- **Wave 2**: **3** — T4 → `unspecified-high`, T5 → `deep`, T6 → `quick`
- **Wave 3**: **5** — T7-T10 → `deep`, T11 → `unspecified-high`
- **Wave 4**: **3** — T12-T14 → `unspecified-high`
- **Wave 5**: **1** — T15 → `unspecified-high`
- **FINAL**: **4** — F1 → `oracle`, F2-F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

### Wave 1: Setup

- [ ] 1. Python Environment Setup (pyenv + venv)

  **What to do**:
  - Use `pyenv` to install Python 3.11 (stable, well-supported by matplotlib)
  - Create `.python-version` file pinning 3.11
  - Create virtualenv at `.venv/` using pyenv's Python
  - Install dependencies: `matplotlib==3.8.5`, `scikit-image>=0.22`, `Pillow`, `numpy`
  - Create `requirements.txt` with pinned versions
  - Add `.venv/` to `.gitignore`
  - Verify: `python -c "import matplotlib; import skimage; print('OK')"`

  **Must NOT do**:
  - Don't install system-wide packages
  - Don't use conda or poetry — plain venv + pip
  - Don't install unnecessary dependencies

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 4, 5, 6
  - **Blocked By**: None

  **References**:
  - `pyenv` is already installed on the system
  - matplotlib 3.8.5 is a stable release with good SSIM reproducibility

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Python environment works
    Tool: Bash
    Preconditions: pyenv installed
    Steps:
      1. pyenv install 3.11 (if not already installed)
      2. Create .venv: python -m venv .venv
      3. pip install -r requirements.txt
      4. .venv/bin/python -c "import matplotlib; print(matplotlib.__version__)"
      5. .venv/bin/python -c "from skimage.metrics import structural_similarity; print('SSIM available')"
    Expected Result: matplotlib version 3.8.5, SSIM function importable
    Evidence: .sisyphus/evidence/task-1-python-env.txt

  Scenario: gitignore updated
    Tool: Bash
    Steps:
      1. grep ".venv" .gitignore
    Expected Result: .venv is in .gitignore
    Evidence: .sisyphus/evidence/task-1-gitignore.txt
  ```

  **Commit**: YES (group with 3)
  - Message: `chore: setup python venv for visual comparison`
  - Files: `.python-version`, `requirements.txt`, `.gitignore`

- [ ] 2. Diagnostic Audit — Verify `to-rgba` Return Type and Find All Broken Callers

  **What to do**:
  - Load cl-matplotlib in SBCL and call `(mpl.colors:to-rgba "red")` — document whether it returns a vector `#(1.0 0.0 0.0 1.0)` or multiple values
  - Use `lsp_find_references` and `ast_grep_search` to find ALL callers of `to-rgba` across the codebase
  - For each caller, check if it uses `multiple-value-list`, `multiple-value-bind`, or direct vector access
  - Identify which callers would break if `to-rgba` returns a vector (i.e., `multiple-value-list` callers)
  - Specifically check: `figure.lisp` (background color), `axes-base.lisp` (axes background), `backend-vecto.lisp` (`%resolve-color`)
  - Produce a report: file, line, calling pattern, broken Y/N
  - This is DIAGNOSTIC ONLY — do not fix anything yet

  **Must NOT do**:
  - Don't fix any bugs — diagnostic only
  - Don't modify any source files

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Task 7
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `src/primitives/colors.lisp` — `to-rgba` function definition
  - `src/backends/backend-vecto.lisp:55-65` — `%resolve-color` function (handles to-rgba returns)
  - `src/containers/figure.lisp:~290` — Figure background uses `(multiple-value-list (mpl.colors:to-rgba fc))`
  - `src/containers/axes-base.lisp:~415` — Axes background color resolution

  **WHY Each Reference Matters**:
  - `to-rgba` return type is the suspected root cause of black backgrounds across ALL examples
  - `%resolve-color` already has vector handling — need to verify it catches all cases
  - `figure.lisp` and `axes-base.lisp` use `multiple-value-list` which corrupts vector returns

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Identify to-rgba return type
    Tool: Bash (sbcl --eval)
    Steps:
      1. sbcl --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(let ((result (mpl.colors:to-rgba "red"))) (format t "Type: ~A~%Value: ~A~%" (type-of result) result))' --quit
      2. Record type: SIMPLE-VECTOR vs multiple-values
    Expected Result: Clear documentation of return type
    Evidence: .sisyphus/evidence/task-2-to-rgba-type.txt

  Scenario: All callers catalogued
    Tool: Bash (grep/ast-grep)
    Steps:
      1. Search all .lisp files for calls to to-rgba
      2. For each, note: file, line, pattern (multiple-value-list? vector access? other?)
      3. Mark each as: CORRECT / BROKEN / NEEDS-REVIEW
    Expected Result: Complete caller report with fix/no-fix classification
    Evidence: .sisyphus/evidence/task-2-caller-audit.txt
  ```

  **Commit**: NO (diagnostic only — evidence files only)

- [ ] 3. Directory Structure + Makefile Skeleton

  **What to do**:
  - Create directory structure:
    - `tools/` — comparison tooling
    - `reference_scripts/` — Python equivalent scripts
    - `reference_images/` — Python matplotlib output PNGs
    - `comparison_report/` — generated HTML + diff images
  - Create initial `Makefile` with target stubs:
    - `setup-python`: Create venv, install deps
    - `reference-images`: Run all Python reference scripts
    - `cl-images`: Run all CL example scripts via `sbcl --load`
    - `compare`: Run comparison tool
    - `report`: Generate HTML report
    - `clean`: Remove generated files
  - Add `reference_images/`, `comparison_report/`, `.venv/` to `.gitignore`

  **Must NOT do**:
  - Don't implement the comparison tool yet (Task 5)
  - Don't create Python reference scripts yet (Task 4)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2)
  - **Blocks**: Task 6
  - **Blocked By**: None

  **References**:
  - Existing `examples/` directory with 7 `.lisp` + `.png` files

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Directory structure exists
    Tool: Bash
    Steps:
      1. test -d tools && test -d reference_scripts && test -d reference_images && echo "OK"
    Expected Result: "OK"
    Evidence: .sisyphus/evidence/task-3-dirs.txt

  Scenario: Makefile has all targets
    Tool: Bash
    Steps:
      1. make -n setup-python 2>&1 | head -1  (dry-run, should not error)
      2. make -n reference-images 2>&1 | head -1
      3. make -n cl-images 2>&1 | head -1
      4. make -n compare 2>&1 | head -1
    Expected Result: All targets recognized (no "No rule to make target" errors)
    Evidence: .sisyphus/evidence/task-3-makefile.txt
  ```

  **Commit**: YES (group with 1)
  - Message: `chore: comparison infrastructure skeleton`
  - Files: `Makefile`, `tools/`, `.gitignore`

---

### Wave 2: Comparison Infrastructure

- [ ] 4. Python Reference Scripts for 7 Existing Examples

  **What to do**:
  - Create Python scripts in `reference_scripts/` that produce IDENTICAL plots to the 7 CL examples:
    1. `simple-line.py` — two curves (y=x^2, y=2x+10), labels, title, legend, grid
    2. `scatter.py` — 200 points with same PRNG seed (42), Box-Muller normal distribution
    3. `bar-chart.py` — 6 colored bars with same colors/values
    4. `histogram.py` — 1000 normal samples (mean=5, std=2), 30 bins, same PRNG seed (7)
    5. `pie-chart.py` — 5 slices with same values/colors
    6. `filled-contour.py` — 50x50 Gaussian exp(-(x^2+y^2)), 12 levels, viridis
    7. `subplots.py` — 2x2 grid with sin, cos, sin*cos, sin^2
  - EACH script must:
    - Use exact same data, colors, figsize, parameters as CL counterpart
    - Set `plt.rcParams['savefig.dpi'] = 100` (match CL default)
    - Save to `reference_images/<name>.png` with `dpi=100`
    - Replicate PRNG sequences exactly (same seeds, same LCG algorithm for scatter/histogram)
    - Be runnable via `.venv/bin/python reference_scripts/<name>.py`
  - Configure matplotlib for fair comparison:
    - `plt.rcParams['text.hinting'] = 'none'` (disable hinting for reproducibility)
    - Consider setting font to Liberation Sans to match CL rendering if available

  **Must NOT do**:
  - Don't add features not in the CL examples
  - Don't use bbox_inches='tight' (changes output geometry)
  - Don't use Python-specific styling

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 5, 6)
  - **Blocks**: Task 6
  - **Blocked By**: Task 1 (needs Python env)

  **References**:

  **Pattern References**:
  - `examples/simple-line.lisp` — CL source to mirror (two curves: y=x^2, y=2x+10)
  - `examples/scatter.lisp` — CL source with LCG PRNG seed=42, Box-Muller
  - `examples/bar-chart.lisp` — 6 bars with specific colors
  - `examples/histogram.lisp` — LCG PRNG seed=7, N=1000, bins=30
  - `examples/pie-chart.lisp` — 5 slices
  - `examples/filled-contour.lisp` — 50x50 grid, exp(-(x^2+y^2))
  - `examples/subplots.lisp` — 2x2 grid, trig functions

  **WHY Each Reference Matters**:
  - Each CL example defines the exact data, parameters, and styling. Python scripts must match exactly for SSIM comparison to be meaningful.

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 7 Python scripts run without error
    Tool: Bash
    Steps:
      1. for f in reference_scripts/*.py; do .venv/bin/python "$f" && echo "OK: $f"; done
    Expected Result: All 7 print "OK"
    Evidence: .sisyphus/evidence/task-4-python-scripts.txt

  Scenario: Reference images generated with correct dimensions
    Tool: Bash
    Steps:
      1. ls reference_images/*.png | wc -l → Assert 7
      2. .venv/bin/python -c "from PIL import Image; img=Image.open('reference_images/simple-line.png'); print(img.size)"
         → Assert (800, 600) for 8x6 figsize at 100 DPI
      3. file reference_images/simple-line.png → Assert "PNG image data"
    Expected Result: 7 valid PNG files with correct dimensions
    Evidence: .sisyphus/evidence/task-4-reference-images.txt
  ```

  **Commit**: YES (group with 5, 6)
  - Message: `feat(testing): visual comparison infrastructure with SSIM`
  - Files: `reference_scripts/*.py`, `reference_images/*.png`

- [ ] 5. Comparison Tool (compare.py)

  **What to do**:
  - Create `tools/compare.py` — a standalone Python script that:
    1. Takes two directories as input (reference images dir, CL images dir)
    2. For each matching image pair, computes:
       - SSIM score (scikit-image `structural_similarity`, `data_range=255`, `channel_axis=-1`)
       - Per-pixel absolute difference
    3. Generates per-example comparison sheet (4-panel PNG):
       - Panel 1: Reference image (Python matplotlib)
       - Panel 2: Actual image (CL-matplotlib)
       - Panel 3: Absolute difference ×10 (amplified for visibility)
       - Panel 4: SSIM heatmap (local similarity map)
    4. Generates `comparison_report/index.html` with:
       - Table of all examples with SSIM scores
       - Embedded comparison sheet images
       - PASS/FAIL status per example (threshold: 0.90)
       - Overall summary (N pass / N fail / mean SSIM)
    5. Returns exit code 0 if ALL examples pass threshold, non-zero otherwise
    6. Outputs machine-parseable JSON summary to `comparison_report/summary.json`
  - Handle edge cases:
    - Missing images in either directory (report as SKIP)
    - Different image dimensions (resize smaller to match larger, report dimension mismatch)
    - Alpha channels (composite on white background before comparison)
  - CLI interface: `python tools/compare.py --reference reference_images/ --actual examples/ --threshold 0.90 --output comparison_report/`

  **Must NOT do**:
  - Don't over-engineer — single file, ~200-300 LOC
  - Don't add web server or interactive features
  - Don't require any dependencies beyond matplotlib, scikit-image, Pillow, numpy
  - Don't use matplotlib.testing.compare (we want our own clean implementation)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 6)
  - **Blocks**: Task 6
  - **Blocked By**: Task 1 (needs Python env)

  **References**:

  **External References**:
  - scikit-image SSIM docs: `skimage.metrics.structural_similarity(im1, im2, data_range=255, channel_axis=-1)`
  - PIL/Pillow for image loading and compositing

  **WHY Each Reference Matters**:
  - SSIM API has specific parameter requirements (data_range=255 for uint8, channel_axis=-1 not multichannel=True)

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Comparison tool produces report
    Tool: Bash
    Steps:
      1. .venv/bin/python tools/compare.py --reference reference_images/ --actual examples/ --threshold 0.90 --output comparison_report/
      2. test -f comparison_report/index.html && echo "HTML exists"
      3. test -f comparison_report/summary.json && echo "JSON exists"
      4. ls comparison_report/*-comparison.png | wc -l → Assert 7
    Expected Result: HTML report + JSON summary + 7 comparison sheets
    Evidence: .sisyphus/evidence/task-5-comparison-tool.txt

  Scenario: JSON summary has correct structure
    Tool: Bash
    Steps:
      1. .venv/bin/python -c "import json; d=json.load(open('comparison_report/summary.json')); print(d.keys()); assert 'examples' in d; assert 'overall' in d"
    Expected Result: JSON has 'examples' and 'overall' keys
    Evidence: .sisyphus/evidence/task-5-json-structure.txt

  Scenario: Tool returns non-zero exit code when SSIM below threshold
    Tool: Bash
    Steps:
      1. Run compare tool (current broken images should fail SSIM > 0.90)
      2. echo $? → Assert non-zero
    Expected Result: Exit code indicates failures
    Evidence: .sisyphus/evidence/task-5-exit-code.txt
  ```

  **Commit**: YES (group with 4, 6)
  - Message: `feat(testing): visual comparison infrastructure with SSIM`
  - Files: `tools/compare.py`

- [ ] 6. Complete Makefile + Run Initial Comparison Baseline

  **What to do**:
  - Complete the Makefile from Task 3 with full implementation:
    - `setup-python`: Install pyenv Python 3.11, create .venv, install requirements.txt
    - `reference-images`: Run all `reference_scripts/*.py` to generate `reference_images/*.png`
    - `cl-images`: Run all `examples/*.lisp` via `sbcl --load <file> --quit` to regenerate PNGs
    - `compare`: Run `tools/compare.py` with proper arguments
    - `report`: Alias for compare (report is generated as part of compare)
    - `clean`: Remove `reference_images/*.png`, `comparison_report/`, `examples/*.png`
    - `all`: `setup-python reference-images cl-images compare`
  - The `cl-images` target should:
    - Loop over all `examples/*.lisp` files
    - Run each via `sbcl --load <file> --quit` (NOT Roswell)
    - Continue on errors (some may fail before bugs are fixed)
  - Run the FULL pipeline once to capture baseline SSIM scores (before any bug fixes)
  - Save the baseline comparison report to `.sisyphus/evidence/task-6-baseline-comparison/`

  **Must NOT do**:
  - Don't fix any CL bugs in this task
  - Don't skip running the baseline comparison

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (after Wave 2 parallel tasks complete)
  - **Blocks**: Task 7
  - **Blocked By**: Tasks 3, 4, 5

  **References**:
  - Task 3 Makefile skeleton
  - Task 4 reference scripts
  - Task 5 comparison tool

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: make all runs end-to-end
    Tool: Bash
    Steps:
      1. make reference-images → generates reference PNGs
      2. make cl-images → generates CL PNGs
      3. make compare → generates comparison report
      4. test -f comparison_report/summary.json && echo "PASS"
    Expected Result: Full pipeline completes, report generated
    Evidence: .sisyphus/evidence/task-6-baseline-comparison/

  Scenario: Baseline SSIM scores captured
    Tool: Bash
    Steps:
      1. cat comparison_report/summary.json | .venv/bin/python -c "import sys,json; d=json.load(sys.stdin); [print(f'{e[\"name\"]}: SSIM={e[\"ssim\"]:.4f}') for e in d['examples']]"
    Expected Result: SSIM scores for all 7 examples (expected to be low — bugs not yet fixed)
    Evidence: .sisyphus/evidence/task-6-baseline-ssim.txt
  ```

  **Commit**: YES (group with 4, 5)
  - Message: `feat(testing): visual comparison infrastructure with SSIM`
  - Files: `Makefile`

---

### Wave 3: Bug Fixes

- [ ] 7. Fix `to-rgba` Return Handling Across Codebase

  **What to do**:
  - Using the audit from Task 2, fix ALL callers that incorrectly handle `to-rgba` returns
  - Root cause: `to-rgba` likely returns a vector `#(r g b a)`, but some callers use `multiple-value-list` which wraps it as `(#(r g b a))` instead of `(r g b a)` — this corrupts RGBA values and causes black backgrounds
  - Specific known locations to check/fix:
    - `src/containers/figure.lisp:~290` — `(multiple-value-list (mpl.colors:to-rgba fc))` in `draw-figure-background`
    - `src/containers/axes-base.lisp:~415` — axes background color resolution
    - `src/backends/backend-vecto.lisp:~55` — `%resolve-color` (may already handle vectors correctly)
    - Any other callers identified in Task 2's audit
  - The fix: replace `(multiple-value-list (mpl.colors:to-rgba x))` with proper vector unpacking: `(let ((rgba (mpl.colors:to-rgba x))) (list (elt rgba 0) (elt rgba 1) (elt rgba 2) (elt rgba 3)))`
  - Or: create a utility `(defun rgba-to-list (rgba) ...)` that handles both vector and multiple-value returns
  - After fixing, run `make compare` and verify background color changes from black to white
  - Run full CL test suite to verify no regressions

  **Must NOT do**:
  - Don't fix text, patches, or collection bugs in this task — background only
  - Don't change the `to-rgba` function itself — fix its callers
  - Don't refactor beyond what's needed to fix the return type handling

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential)
  - **Blocks**: Tasks 8, 9, 10
  - **Blocked By**: Tasks 2, 6

  **References**:

  **Pattern References**:
  - `src/primitives/colors.lisp` — `to-rgba` function definition (the source of truth for return type)
  - `src/backends/backend-vecto.lisp:55-65` — `%resolve-color` function (already handles vectors — use this pattern)
  - `src/containers/figure.lisp:~290` — `draw-figure-background` with `multiple-value-list` call
  - `src/containers/axes-base.lisp` — Axes background color path
  - `.sisyphus/evidence/task-2-caller-audit.txt` — Complete caller audit from Task 2

  **WHY Each Reference Matters**:
  - `%resolve-color` in backend-vecto.lisp already correctly handles vector returns — this is the PATTERN to follow
  - The `multiple-value-list` callers in figure.lisp and axes-base.lisp are the suspected broken paths
  - Task 2's audit provides the complete list of callers to fix

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Background is white after fix
    Tool: Bash
    Steps:
      1. make cl-images (regenerate CL images)
      2. .venv/bin/python -c "
         from PIL import Image; import numpy as np
         img = np.array(Image.open('examples/simple-line.png').convert('RGB'))
         corner = img[5, 5]
         print(f'Corner pixel: {corner}')
         assert all(c > 200 for c in corner), f'Background not white: {corner}'
         print('PASS: Background is white')
         "
    Expected Result: Top-left corner pixel is white (>200 in all channels)
    Failure Indicators: Corner pixel is (0,0,0) or dark
    Evidence: .sisyphus/evidence/task-7-white-background.txt

  Scenario: SSIM improves for simple-line
    Tool: Bash
    Steps:
      1. make compare
      2. Check simple-line SSIM in summary.json — should improve from baseline
    Expected Result: SSIM for simple-line increases
    Evidence: .sisyphus/evidence/task-7-ssim-delta.txt

  Scenario: CL test suite still passes
    Tool: Bash
    Steps:
      1. sbcl --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit 2>&1 | tail -20
    Expected Result: 0 failures, 0 errors
    Evidence: .sisyphus/evidence/task-7-test-regression.txt
  ```

  **Commit**: YES
  - Message: `fix(rendering): correct to-rgba return handling — fixes black backgrounds`
  - Files: All modified `.lisp` files
  - Pre-commit: `sbcl --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit`

- [ ] 8. Fix Text Rendering Pipeline — Axis Labels, Titles, Tick Labels

  **What to do**:
  - Diagnose WHY text is invisible despite fontsize defaulting to 12pt:
    - Add temporary diagnostic logging to `renderer-draw-text` in `backend-vecto.lisp` to verify if it's being called for axis labels
    - Check if `text-artist:draw` is being reached (it creates GC with only `:foreground` and `:alpha`, no `:linewidth`)
    - Check if axis labels are drawn outside the visible canvas area (Y-coordinate issue — Vecto origin is bottom-left)
    - Check if `mpl.rendering:renderer-draw-text` bridge method is properly dispatching
  - Fix the identified text rendering issue(s):
    - If fontsize not being passed: add `:linewidth (text-fontsize txt)` to graphics-context creation in `text.lisp` draw method and `axis.lisp` draw methods
    - If text drawn outside visible area: fix Y-coordinate transform for text positions
    - If bridge method not dispatching: fix the method signature/specializers
  - Verify ALL text elements render: axis labels (xlabel, ylabel), title, tick labels, annotation text
  - Remove any diagnostic logging after fixing
  - Run `make compare` to measure SSIM improvement
  - Run CL test suite for regression check

  **Must NOT do**:
  - Don't refactor fontsize-via-linewidth pattern (use the quick fix)
  - Don't fix patch or collection bugs in this task
  - Don't change the text-artist class structure — just fix the rendering path

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential after Task 7)
  - **Blocks**: Task 11
  - **Blocked By**: Task 7

  **References**:

  **Pattern References**:
  - `src/rendering/text.lisp:~72-85` — `text-artist:draw` method (creates GC without fontsize)
  - `src/containers/axis.lisp:~420-450` — XAxis/YAxis draw methods (draw tick labels and axis labels)
  - `src/containers/legend.lisp:~510-530` — Legend text drawing (WORKS — fontsize passed via `:linewidth`)
  - `src/backends/backend-vecto.lisp:~360-380` — `draw-text` method (reads fontsize from `gc-linewidth`)
  - `src/backends/backend-vecto.lisp:~255-271` — `renderer-draw-text` bridge method

  **WHY Each Reference Matters**:
  - Legend text WORKS because legend.lisp passes fontsize via `:linewidth` — this is the pattern to copy
  - text.lisp doesn't pass fontsize — this is the suspected bug
  - axis.lisp axis label drawing creates GC without fontsize — also needs fix
  - Backend reads fontsize from `gc-linewidth` — confirms fontsize must be set in GC

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Axis labels visible in simple-line
    Tool: Bash
    Steps:
      1. make cl-images
      2. .venv/bin/python -c "
         from PIL import Image; import numpy as np
         img = np.array(Image.open('examples/simple-line.png').convert('RGB'))
         # Bottom center: xlabel region
         region = img[int(img.shape[0]*0.92):int(img.shape[0]*0.98), int(img.shape[1]*0.3):int(img.shape[1]*0.7)]
         variance = np.var(region)
         print(f'xlabel region variance: {variance:.1f}')
         assert variance > 100, f'No text in xlabel region: variance={variance}'
         print('PASS: xlabel text visible')
         "
    Expected Result: xlabel text has detectable variance in pixel values
    Evidence: .sisyphus/evidence/task-8-text-visible.txt

  Scenario: Title renders in simple-line
    Tool: Bash
    Steps:
      1. .venv/bin/python -c "
         from PIL import Image; import numpy as np
         img = np.array(Image.open('examples/simple-line.png').convert('RGB'))
         # Top center: title region
         region = img[int(img.shape[0]*0.01):int(img.shape[0]*0.07), int(img.shape[1]*0.3):int(img.shape[1]*0.7)]
         variance = np.var(region)
         print(f'title region variance: {variance:.1f}')
         assert variance > 100, f'No text in title region: variance={variance}'
         print('PASS: title text visible')
         "
    Expected Result: Title text visible
    Evidence: .sisyphus/evidence/task-8-title-visible.txt

  Scenario: SSIM improves
    Tool: Bash
    Steps:
      1. make compare
      2. Compare SSIM scores against Task 7 baseline
    Expected Result: SSIM increases for text-heavy examples
    Evidence: .sisyphus/evidence/task-8-ssim-delta.txt
  ```

  **Commit**: YES
  - Message: `fix(rendering): text rendering pipeline — axis labels, titles, ticks`
  - Files: `src/rendering/text.lisp`, `src/containers/axis.lisp`, related files
  - Pre-commit: `sbcl --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit`

- [ ] 9. Fix Patch/Rectangle Transform Composition — Bar and Histogram Rendering

  **What to do**:
  - Diagnose the bar chart transform bug:
    - The bar chart shows steelblue fill across the entire axes area — this proves Rectangle patches ARE being drawn, but with wrong transforms (filling entire axes instead of individual bar areas)
    - Create a minimal test: render a single Rectangle at known data coordinates, verify it appears at the correct display position
    - Trace the transform chain: Rectangle.get-path → identity path (0,0,1,1) → Rectangle.get-patch-transform → apply data limits and figure coords
    - Check if `get-patch-transform` is properly composing with `transData`
    - Check if the bridge method `renderer-draw-path` correctly applies the patch transform
  - Fix the identified transform issue:
    - Likely: patches need their path transformed through `get-patch-transform` composed with `transData` before being passed to the renderer
    - The unit rectangle (0,0,1,1) should be scaled by `patch-transform` to data coordinates, then by `transData` to display coordinates
  - Verify bar chart, histogram, and all other patch-based plots render correctly
  - Run `make compare` and CL test suite

  **Must NOT do**:
  - Don't fix text or collection bugs in this task
  - Don't change the Patch class hierarchy
  - Don't modify the backend draw-path method

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential after Task 7, parallel consideration with Task 8 — but safer sequential)
  - **Blocks**: Task 11
  - **Blocked By**: Task 7

  **References**:

  **Pattern References**:
  - `src/rendering/patches.lisp` — Patch classes with `get-path` and `get-patch-transform` methods
  - `src/rendering/patches.lisp:draw` — Patch draw method (composes transforms, calls renderer-draw-path)
  - `src/containers/axes.lisp:bar` — Bar function creating Rectangle patches
  - `src/plotting/hist.lisp` — Histogram creating Rectangle patches
  - `src/backends/backend-vecto.lisp:~255-271` — Bridge method renderer-draw-path

  **WHY Each Reference Matters**:
  - The Patch draw method composes `get-patch-transform` with `artist-transform` — this composition is where the bug likely is
  - The bar function creates Rectangles at data coordinates — these must be transformed through transData
  - The bridge method must apply the composed transform when rendering

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Bar chart has visible, distinct bars
    Tool: Bash
    Steps:
      1. make cl-images
      2. .venv/bin/python -c "
         from PIL import Image; import numpy as np
         img = np.array(Image.open('examples/bar-chart.png').convert('RGB'))
         unique_colors = len(np.unique(img.reshape(-1, 3), axis=0))
         print(f'Unique colors: {unique_colors}')
         assert unique_colors > 20, f'Too few colors ({unique_colors}), bars not distinct'
         print('PASS: Bar chart has distinct visual elements')
         "
    Expected Result: Multiple distinct colors visible (bars + background + grid)
    Evidence: .sisyphus/evidence/task-9-bar-chart.txt

  Scenario: Histogram has visible bars
    Tool: Bash
    Steps:
      1. .venv/bin/python -c "
         from PIL import Image; import numpy as np
         img = np.array(Image.open('examples/histogram.png').convert('RGB'))
         # Check vertical variation (bars should create height differences)
         col_means = img[:, img.shape[1]//2, :].mean(axis=1)
         variation = np.std(col_means)
         print(f'Vertical variation in center column: {variation:.1f}')
         assert variation > 20, f'No bar variation: {variation}'
         print('PASS: Histogram has visible height variation')
         "
    Expected Result: Significant vertical pixel variation (bars of different heights)
    Evidence: .sisyphus/evidence/task-9-histogram.txt

  Scenario: SSIM improves for bar-chart and histogram
    Tool: Bash
    Steps:
      1. make compare
      2. Check bar-chart and histogram SSIM in summary.json
    Expected Result: SSIM increases substantially for both
    Evidence: .sisyphus/evidence/task-9-ssim-delta.txt
  ```

  **Commit**: YES
  - Message: `fix(rendering): patch transform composition — bar and histogram rendering`
  - Files: `src/rendering/patches.lisp`, `src/containers/axes.lisp`, `src/backends/backend-vecto.lisp`
  - Pre-commit: CL test suite

- [ ] 10. Fix Collection Rendering — Scatter (PathCollection) and Contour (PolyCollection/LineCollection)

  **What to do**:
  - Diagnose scatter (PathCollection) rendering failure:
    - Scatter uses PathCollection (changed in Phase 5c from individual circles)
    - PathCollection has `trans-offset` for data→display coordinate mapping
    - Check if `draw-path-collection` method on `renderer-vecto` is being reached
    - Check if offsets are correctly transformed through `transData`
    - Check if the marker path (circle) is correctly generated and positioned
  - Diagnose contour (PolyCollection/LineCollection) rendering failure:
    - Filled contour is completely black — total rendering failure
    - Check if `contourf` generates valid PolyCollection objects
    - Check if PolyCollection's `draw` method is called
    - Check if the collection's paths/colors are correctly populated
    - Check Y-coordinate handling (Vecto bottom-left origin vs data coordinates)
  - Fix both issues:
    - Likely involves fixing how `draw-path-collection` handles transforms, offsets, and per-item colors
    - May also involve how contour paths are generated (marching squares output format)
  - Verify scatter and contour both render visible data
  - Run `make compare` and CL test suite

  **Must NOT do**:
  - Don't fix text, patches, or layout bugs in this task
  - Don't change the marching squares algorithm — only fix rendering pipeline
  - Don't modify the Collection class hierarchy

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (sequential after Task 7, parallel consideration with Tasks 8-9 — but collections may depend on patch fix)
  - **Blocks**: Task 11
  - **Blocked By**: Task 7

  **References**:

  **Pattern References**:
  - `src/rendering/collections.lisp` — Collection base + PathCollection + PolyCollection + LineCollection
  - `src/rendering/collections.lisp:draw` — Collection draw methods (different per type)
  - `src/backends/backend-vecto.lisp:draw-path-collection` — Backend collection rendering
  - `src/containers/axes.lisp:scatter` — Scatter creates PathCollection
  - `src/plotting/contour.lisp` — Contour creates PolyCollection/LineCollection
  - `src/algorithms/marching-squares.lisp` — Marching squares generates contour paths

  **WHY Each Reference Matters**:
  - The collection draw methods dispatch differently per type — PathCollection uses offsets, PolyCollection uses direct paths
  - `draw-path-collection` in the Vecto backend is where per-item colors and transforms are applied
  - The contour module generates paths from marching squares — if paths are empty or wrong, nothing renders

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Scatter points visible
    Tool: Bash
    Steps:
      1. make cl-images
      2. .venv/bin/python -c "
         from PIL import Image; import numpy as np
         img = np.array(Image.open('examples/scatter.png').convert('RGB'))
         # Scatter points should create many small colored regions
         # Count pixels that are NOT background and NOT grid
         unique = len(np.unique(img.reshape(-1, 3), axis=0))
         print(f'Unique colors in scatter: {unique}')
         assert unique > 50, f'Too few unique colors ({unique}), scatter points not visible'
         print('PASS: Scatter has visible data points')
         "
    Expected Result: Many unique colors from scatter point rendering
    Evidence: .sisyphus/evidence/task-10-scatter.txt

  Scenario: Filled contour is NOT black
    Tool: Bash
    Steps:
      1. .venv/bin/python -c "
         from PIL import Image; import numpy as np
         img = np.array(Image.open('examples/filled-contour.png').convert('RGB'))
         mean_brightness = img.mean()
         print(f'Mean brightness: {mean_brightness:.1f}')
         assert mean_brightness > 30, f'Image too dark ({mean_brightness}), contour not rendering'
         unique = len(np.unique(img.reshape(-1, 3), axis=0))
         print(f'Unique colors: {unique}')
         assert unique > 10, f'Too few colors ({unique}), no contour bands'
         print('PASS: Filled contour has visible content')
         "
    Expected Result: Image has visible brightness and multiple color bands
    Evidence: .sisyphus/evidence/task-10-contour.txt

  Scenario: SSIM improves for scatter and filled-contour
    Tool: Bash
    Steps:
      1. make compare
    Expected Result: SSIM increases for both scatter and filled-contour
    Evidence: .sisyphus/evidence/task-10-ssim-delta.txt
  ```

  **Commit**: YES
  - Message: `fix(rendering): collection rendering — scatter and contour`
  - Files: `src/rendering/collections.lisp`, `src/plotting/contour.lisp`, `src/backends/backend-vecto.lisp`
  - Pre-commit: CL test suite

- [ ] 11. Fix Layout Issues — Pie Centering, Clipping, Axes Positioning

  **What to do**:
  - Fix pie chart centering:
    - Pie chart is offset to the left — the equal aspect ratio and centering logic needs adjustment
    - Check if `axes-set-aspect` (equal) works correctly for pie
    - Check if pie wedge center (0,0) is properly positioned in the axes area
    - Fix: ensure axes data limits center the pie, or adjust axes positioning
  - Fix clipping issues in simple-line:
    - Lines extend beyond plot boundaries on the left
    - Check if clip_on is being respected in the draw method
    - Verify clip rectangle is set correctly in the graphics context
  - Fix any remaining minor layout issues:
    - Tick marks showing on pie chart (should be hidden)
    - Subplot spacing and margins
  - Run `make compare` and CL test suite

  **Must NOT do**:
  - Don't fix text, patch, or collection bugs here (should be fixed by Tasks 7-10)
  - Don't add tight_layout or constrained_layout implementation
  - Don't change the axis or spine architecture

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 (final sequential task — needs all other fixes first)
  - **Blocks**: Tasks 12, 13, 14
  - **Blocked By**: Tasks 8, 9, 10

  **References**:

  **Pattern References**:
  - `src/containers/axes.lisp:pie` — Pie chart function (sets center, data limits)
  - `src/containers/axes-base.lisp` — Axes clip handling, aspect ratio, data limits
  - `src/rendering/lines.lisp:draw` — Line2D draw method (clip_on handling)
  - `src/backends/backend-vecto.lisp` — Clip rectangle application in graphics context

  **WHY Each Reference Matters**:
  - Pie function sets data limits around the unit circle — if these are wrong, pie is off-center
  - Line2D clip handling determines whether lines are clipped at axes boundaries
  - Backend clip rect must be applied before drawing to prevent overflow

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Pie chart is centered
    Tool: Bash
    Steps:
      1. make cl-images
      2. .venv/bin/python -c "
         from PIL import Image; import numpy as np
         img = np.array(Image.open('examples/pie-chart.png').convert('L'))  # grayscale
         # Find bounding box of non-background content
         non_bg = img < 250  # content pixels
         rows = np.any(non_bg, axis=1)
         cols = np.any(non_bg, axis=0)
         rmin, rmax = np.where(rows)[0][[0, -1]]
         cmin, cmax = np.where(cols)[0][[0, -1]]
         center_r = (rmin + rmax) / 2
         center_c = (cmin + cmax) / 2
         img_center_r = img.shape[0] / 2
         img_center_c = img.shape[1] / 2
         offset_r = abs(center_r - img_center_r) / img.shape[0]
         offset_c = abs(center_c - img_center_c) / img.shape[1]
         print(f'Vertical offset: {offset_r:.2%}, Horizontal offset: {offset_c:.2%}')
         assert offset_c < 0.15, f'Pie too far off-center horizontally: {offset_c:.2%}'
         print('PASS: Pie chart approximately centered')
         "
    Expected Result: Pie center within 15% of image center
    Evidence: .sisyphus/evidence/task-11-pie-centering.txt

  Scenario: All 7 examples achieve reasonable SSIM
    Tool: Bash
    Steps:
      1. make compare
      2. Check all SSIM scores in summary.json
    Expected Result: All 7 examples > 0.70 (with font differences)
    Evidence: .sisyphus/evidence/task-11-final-ssim.txt
  ```

  **Commit**: YES
  - Message: `fix(rendering): layout issues — pie centering, clipping`
  - Files: `src/containers/axes.lisp`, `src/containers/axes-base.lisp`
  - Pre-commit: CL test suite

---

### Wave 4: Gallery Expansion

- [ ] 12. Gallery Batch A — 7 Basic Plot Type Examples

  **What to do**:
  - Create 7 new examples in `examples/` covering basic plot types not yet demonstrated:
    1. `errorbar.lisp` — Error bar plot with x and y errors, labeled axes
    2. `stem-plot.lisp` — Stem plot of discrete data
    3. `step-plot.lisp` — Step plot with :pre, :post modes
    4. `barh.lisp` — Horizontal bar chart
    5. `stackplot.lisp` — Stacked area chart with 3-4 layers
    6. `boxplot.lisp` — Box and whisker plot with multiple distributions
    7. `fill-between.lisp` — Fill between two curves with alpha transparency
  - Each example must:
    - Use the pyplot interface (`cl-matplotlib.pyplot`)
    - Set figsize, labels, title, grid
    - Save to `examples/<name>.png` via savefig
    - Be runnable via `sbcl --load examples/<name>.lisp --quit`
    - Use descriptive, self-contained data (no external files)

  **Must NOT do**:
  - Don't modify existing examples
  - Don't add examples for features not implemented (polar, 3D, animation)
  - Don't use features that were broken and may not be fully fixed

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 13, 14)
  - **Blocks**: Task 15
  - **Blocked By**: Task 11

  **References**:

  **Pattern References**:
  - `examples/simple-line.lisp` — Pattern for example script structure (require, load-system, pyplot)
  - `examples/bar-chart.lisp` — Pattern for using short pyplot package alias
  - `src/containers/axes.lisp` — Available plot functions: `errorbar`, `stem`, `axes-step`, `barh`, `stackplot`, `boxplot`, `fill-between`

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 7 new examples generate valid PNGs
    Tool: Bash
    Steps:
      1. for f in examples/errorbar.lisp examples/stem-plot.lisp examples/step-plot.lisp examples/barh.lisp examples/stackplot.lisp examples/boxplot.lisp examples/fill-between.lisp; do sbcl --load "$f" --quit && echo "OK: $f"; done
      2. ls examples/errorbar.png examples/stem-plot.png examples/step-plot.png examples/barh.png examples/stackplot.png examples/boxplot.png examples/fill-between.png | wc -l
    Expected Result: All 7 generate valid PNGs
    Evidence: .sisyphus/evidence/task-12-gallery-a.txt

  Scenario: Each PNG is non-trivial
    Tool: Bash
    Steps:
      1. for f in examples/errorbar.png examples/stem-plot.png examples/step-plot.png examples/barh.png examples/stackplot.png examples/boxplot.png examples/fill-between.png; do size=$(stat -c%s "$f"); echo "$f: $size bytes"; test $size -gt 5000 || echo "WARN: small file"; done
    Expected Result: All files > 5KB (non-trivial content)
    Evidence: .sisyphus/evidence/task-12-file-sizes.txt
  ```

  **Commit**: YES (group with 13, 14)
  - Message: `feat(examples): gallery batch A — basic plot types`
  - Files: `examples/*.lisp`, `examples/*.png`

- [ ] 13. Gallery Batch B — 6 Advanced Feature Examples

  **What to do**:
  - Create 6 new examples in `examples/` covering advanced features:
    1. `imshow-heatmap.lisp` — Heatmap with colorbar and viridis colormap
    2. `contour-lines.lisp` — Contour lines (not filled) with clabel
    3. `annotations.lisp` — Plot with arrow annotations pointing to data
    4. `legend-styles.lisp` — Multiple legend positions and styles
    5. `colorbar-custom.lisp` — Custom colorbar with different colormaps
    6. `multi-line.lisp` — Multiple lines with different colors and styles (solid, dashed, dotted)
  - Same standards as Task 12 (pyplot interface, savefig, runnable via sbcl --load)

  **Must NOT do**:
  - Don't modify existing examples
  - Don't use unimplemented features
  - Don't add more than 6 examples in this batch

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 12, 14)
  - **Blocks**: Task 15
  - **Blocked By**: Task 11

  **References**:

  **Pattern References**:
  - `examples/filled-contour.lisp` — Pattern for contour-based examples
  - `src/plotting/contour.lisp` — Available: `contour`, `contourf`, `clabel`
  - `src/containers/axes.lisp:annotate` — Annotation function
  - `src/containers/legend.lisp` — Legend positioning keywords
  - `src/containers/colorbar.lisp` — Colorbar function
  - `src/rendering/image.lisp` — imshow function

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 6 examples generate valid PNGs
    Tool: Bash
    Steps:
      1. for f in examples/imshow-heatmap.lisp examples/contour-lines.lisp examples/annotations.lisp examples/legend-styles.lisp examples/colorbar-custom.lisp examples/multi-line.lisp; do sbcl --load "$f" --quit && echo "OK: $f"; done
      2. Count PNG outputs → Assert 6
    Expected Result: All 6 generate valid PNGs
    Evidence: .sisyphus/evidence/task-13-gallery-b.txt
  ```

  **Commit**: YES (group with 12, 14)
  - Message: `feat(examples): gallery batch B — advanced features`
  - Files: `examples/*.lisp`, `examples/*.png`

- [ ] 14. Gallery Batch C — 7 Style, Config, and Layout Examples

  **What to do**:
  - Create 7 new examples in `examples/` covering configuration and layout:
    1. `ggplot-style.lisp` — Plot using ggplot style sheet
    2. `log-scale.lisp` — Logarithmic y-axis with exponential data
    3. `mathtext-title.lisp` — Title containing math expressions ($x^2 + y^2 = r^2$)
    4. `custom-markers.lisp` — Various marker types (o, s, ^, v, d, +, x) with line styles
    5. `shared-axes.lisp` — Subplots with shared x and y axes
    6. `gridspec-custom.lisp` — Non-uniform grid layout (different row/col sizes)
    7. `figure-sizes.lisp` — Different figure sizes showing DPI and dimensions
  - Same standards as Tasks 12-13

  **Must NOT do**:
  - Don't modify existing examples
  - Don't use features not implemented in cl-matplotlib
  - Don't create overly complex examples (keep each focused on ONE feature)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with Tasks 12, 13)
  - **Blocks**: Task 15
  - **Blocked By**: Task 11

  **References**:

  **Pattern References**:
  - `src/pyplot/pyplot.lisp` — Available pyplot functions including `use-style`
  - `src/containers/scale.lisp` — Scale types: `:log`, `:symlog`, `:logit`
  - `src/rendering/mathtext.lisp` — Mathtext rendering
  - `src/containers/gridspec.lisp` — GridSpec, subplots with shared axes
  - `examples/subplots.lisp` — Existing subplot example pattern

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 7 examples generate valid PNGs
    Tool: Bash
    Steps:
      1. for f in examples/ggplot-style.lisp examples/log-scale.lisp examples/mathtext-title.lisp examples/custom-markers.lisp examples/shared-axes.lisp examples/gridspec-custom.lisp examples/figure-sizes.lisp; do sbcl --load "$f" --quit && echo "OK: $f"; done
      2. Count PNG outputs → Assert 7
    Expected Result: All 7 generate valid PNGs
    Evidence: .sisyphus/evidence/task-14-gallery-c.txt
  ```

  **Commit**: YES (group with 12, 13)
  - Message: `feat(examples): gallery batch C — style, config, layout`
  - Files: `examples/*.lisp`, `examples/*.png`

---

### Wave 5: Gallery References + Comparison

- [ ] 15. Python Reference Scripts + Full Comparison for All 20 New Examples

  **What to do**:
  - Create matching Python reference scripts in `reference_scripts/` for all 20 new examples from Tasks 12-14:
    - Each Python script must produce the IDENTICAL plot as its CL counterpart
    - Same data, colors, figsize, DPI, parameters
    - Same `plt.rcParams['text.hinting'] = 'none'` and font configuration
  - Generate all reference images via `make reference-images`
  - Run `make compare` for the full 27-example gallery
  - Identify any examples with SSIM < 0.90 and document the causes
  - If any SSIM < 0.90 is due to remaining rendering bugs (not font differences):
    - Document the bug with specific file/line/symptom
    - Create a hotfix (small targeted fix) for each
    - Re-run comparison after hotfix
  - Generate the final comparison report

  **Must NOT do**:
  - Don't do major refactoring — hotfixes only for SSIM < 0.90 issues
  - Don't lower the SSIM threshold to pass
  - Don't modify existing 7 reference scripts from Task 4

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (depends on all gallery tasks)
  - **Blocks**: F1-F4
  - **Blocked By**: Tasks 12, 13, 14

  **References**:
  - Task 4 Python reference scripts (pattern to follow for new scripts)
  - All new CL example files from Tasks 12-14

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: All 27 reference scripts exist and run
    Tool: Bash
    Steps:
      1. ls reference_scripts/*.py | wc -l → Assert 27
      2. for f in reference_scripts/*.py; do .venv/bin/python "$f" 2>&1 | tail -1; done
    Expected Result: 27 scripts, all run without error
    Evidence: .sisyphus/evidence/task-15-reference-scripts.txt

  Scenario: All 27 examples achieve SSIM > 0.90
    Tool: Bash
    Steps:
      1. make reference-images && make cl-images && make compare
      2. .venv/bin/python -c "
         import json
         d = json.load(open('comparison_report/summary.json'))
         failures = [e for e in d['examples'] if e['ssim'] < 0.90]
         print(f'Total: {len(d[\"examples\"])}, Passed: {len(d[\"examples\"]) - len(failures)}, Failed: {len(failures)}')
         for f in failures: print(f'  FAIL: {f[\"name\"]} SSIM={f[\"ssim\"]:.4f}')
         assert len(failures) == 0, f'{len(failures)} examples below 0.90'
         print('ALL PASS: 27/27 examples above SSIM 0.90')
         "
    Expected Result: 27/27 examples pass SSIM > 0.90
    Evidence: .sisyphus/evidence/task-15-final-comparison.txt

  Scenario: Comparison report complete
    Tool: Bash
    Steps:
      1. test -f comparison_report/index.html && echo "HTML: OK"
      2. ls comparison_report/*-comparison.png | wc -l → Assert 27
    Expected Result: HTML report + 27 comparison sheets
    Evidence: .sisyphus/evidence/task-15-report.txt
  ```

  **Commit**: YES
  - Message: `feat(examples): comprehensive gallery with 27 examples + Python references`
  - Files: `reference_scripts/*.py`, `reference_images/*.png`, `examples/*.lisp`, `examples/*.png`

---

## Final Verification Wave

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (run make targets, check file existence). For each "Must NOT Have": search codebase for forbidden patterns. Check evidence files exist in `.sisyphus/evidence/`. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run full CL test suite (`sbcl --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit`). Review all changed `.lisp` files for: `as any` equivalents, empty handlers, debugging prints left in, commented-out code. Check Python scripts for correct matplotlib usage.
  Output: `CL Tests [PASS/FAIL] | Python Scripts [N/N valid] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Full Comparison Report** — `unspecified-high`
  Run `make compare` for ALL 27 examples. Verify every example has SSIM > 0.90. Generate final HTML report. Check all comparison images exist in `comparison_report/`. Capture final SSIM scores.
  Output: `Examples [27/27 generated] | SSIM [N/27 > 0.90] | Mean SSIM [value] | Min SSIM [value, example] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| After Task | Message | Key Files |
|------------|---------|-----------|
| 1 | `chore: setup python venv for visual comparison` | `.python-version`, `requirements.txt`, `.gitignore` |
| 2 | `chore: diagnostic audit of to-rgba callers` | `.sisyphus/evidence/` only |
| 3 | `chore: comparison infrastructure skeleton` | `Makefile`, `tools/`, directory structure |
| 4+5+6 | `feat(testing): visual comparison infrastructure with SSIM` | `tools/compare.py`, `reference_scripts/`, `reference_images/`, `Makefile` |
| 7 | `fix(rendering): correct to-rgba return handling — fixes black backgrounds` | `src/` `.lisp` files |
| 8 | `fix(rendering): text rendering pipeline — axis labels, titles, ticks` | `src/rendering/text.lisp`, `src/containers/axis.lisp` |
| 9 | `fix(rendering): patch transform composition — bar and histogram rendering` | `src/containers/axes.lisp`, `src/backends/backend-vecto.lisp` |
| 10 | `fix(rendering): collection rendering — scatter and contour` | `src/rendering/collections.lisp`, `src/plotting/contour.lisp` |
| 11 | `fix(rendering): layout issues — pie centering, clipping` | `src/containers/axes.lisp` |
| 12-15 | `feat(examples): comprehensive gallery with 27 examples` | `examples/`, `reference_scripts/`, `reference_images/` |

---

## Success Criteria

### Verification Commands
```bash
# Python env works
make setup-python && .venv/bin/python -c "import matplotlib; import skimage; print('OK')"
# Expected: "OK"

# Reference images generated
make reference-images && ls reference_images/*.png | wc -l
# Expected: 27

# CL images generated
make cl-images && ls examples/*.png | wc -l
# Expected: 27

# All SSIM scores above threshold
make compare
# Expected: exit code 0, all scores > 0.90

# CL test suite still passes
sbcl --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit 2>&1 | grep -c "0 failures"
# Expected: 1

# Comparison report generated
test -f comparison_report/index.html && echo "EXISTS"
# Expected: EXISTS
```

### Final Checklist
- [ ] All 27 examples generate valid PNGs from CL
- [ ] All 27 examples have matching Python reference images
- [ ] All 27 examples achieve SSIM > 0.90
- [ ] Zero regressions in CL test suite
- [ ] Makefile workflow works end-to-end
- [ ] Comparison report generated with visual diffs
- [ ] No "Must NOT Have" items present
