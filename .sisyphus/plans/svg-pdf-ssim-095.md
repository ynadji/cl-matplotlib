# SSIM ≥ 0.95: SVG & PDF Rendering Parity with PNG

## TL;DR

> **Quick Summary**: Close the SSIM gap between SVG/PDF outputs and PNG references by fixing PDF image rendering (gray rect stub), PDF dash pattern scaling, SVG rasterization DPI in compare.py, adding half-pixel snapping to both backends, and calibrating an allowlist for structurally-hard examples.
> 
> **Deliverables**:
> - Per-example SSIM ≥ 0.95 for both SVG and PDF, with a data-driven allowlist for outliers
> - Fixed `tools/compare.py` — correct SVG DPI, `--allowlist` mechanism
> - Fixed `src/backends/backend-pdf.lisp` — real image rendering, linewidth-scaled dashes
> - Fixed `src/backends/backend-svg.lisp` and `backend-pdf.lisp` — half-pixel snapping
> - `allowlist.json` — data-driven list of excluded examples with justifications
> - Updated `Makefile` with `compare-svg` and `compare-pdf` targets
> - Regenerated all 79 examples with updated reports
> 
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 4 waves
> **Critical Path**: Task 1 (baseline) → Task 2 (compare.py) → Task 5 (PDF image) → Task 8 (regenerate) → Task 9 (allowlist calibration)

---

## Context

### Original Request
Reach SSIM ≥ 0.95 per-example for SVG and PDF outputs vs PNG references. Current: SVG mean=0.870, PDF mean=0.925. User chose per-example minimum with allowlist for known-hard outliers.

### Interview Summary
**Key Discussions**:
- SVG dimension mismatch is NOT a backend bug — it's an ImageMagick DPI issue in compare.py
- PDF draw-image is a gray rectangle placeholder — needs real implementation via cl-pdf's native API
- PDF dash patterns use fixed constants instead of linewidth scaling
- Half-pixel snapping missing from SVG and PDF (Vecto has it)
- Accept Helvetica for PDF (no TrueType embedding)
- Matplotlib uses per-test RMS tolerance, often removes text for font diffs

**Research Findings**:
- SVG canvas dimensions (800×600) match PNG exactly — compare.py uses `-density 100` but should use `-density 96` for CSS px units
- DPI fix gives only +0.002 to +0.022 SSIM — insufficient alone for 0.95
- cl-pdf has native `pdf:make-image` / `pdf:draw-image` API for PNG embedding
- Vecto half-pixel snapping (lines 170-219) snaps axis-aligned paths to 0.5px grid
- SVG rasterization (ImageMagick/librsvg2) vs Vecto (cl-aa) creates an irreducible rendering difference
- SVG allowlist may need 10-20+ entries due to rasterizer differences
- PDF allowlist likely smaller (2-5 entries for Gouraud + text-heavy examples)

### Metis Review
**Identified Gaps** (addressed):
- CRITICAL: SVG dimension mismatch root cause was misdiagnosed — fix is in compare.py, not backend-svg.lisp
- CRITICAL: DPI fix alone insufficient — half-pixel snapping benefit is uncertain for vector→rasterizer pipeline
- cl-pdf has native image support that should be used (not custom stream code)
- compare.py has no allowlist mechanism — must be built
- Makefile needs `compare-svg` and `compare-pdf` targets
- Half-pixel snapping may not help SVG/PDF because external rasterizers have their own pixel conventions

---

## Work Objectives

### Core Objective
Make every SVG and PDF example achieve SSIM ≥ 0.95 against PNG reference, with a curated allowlist for structurally-impossible cases (Gouraud flat-color, font-limited, rasterizer-limited).

### Concrete Deliverables
- Fixed `tools/compare.py` — DPI 96 for SVG, `--allowlist` CLI flag
- Fixed `src/backends/backend-pdf.lisp` — real image rendering, scaled dash patterns
- Half-pixel snapping in `src/backends/backend-svg.lisp` and `backend-pdf.lisp`
- `allowlist.json` — data-driven list of excluded examples with justifications
- Updated `Makefile` with SVG/PDF comparison targets
- Full comparison reports at 0.95 threshold

### Definition of Done
- [ ] `python3 tools/compare.py --format svg --threshold 0.95 --allowlist allowlist.json` → 0 FAIL (all PASS or ALLOW)
- [ ] `python3 tools/compare.py --format pdf --threshold 0.95 --allowlist allowlist.json` → 0 FAIL (all PASS or ALLOW)
- [ ] Existing test suite (208 checks) still passes 100%
- [ ] Allowlist is minimal and each entry has documented justification

### Must Have
- Per-example SSIM ≥ 0.95 for all non-allowlisted examples (SVG and PDF)
- Real image rendering in PDF (not gray rectangle placeholder)
- Linewidth-scaled dash patterns in PDF
- Correct SVG rasterization DPI (96, not 100)
- Allowlist mechanism in compare.py with JSON config
- Baseline SSIM measurements BEFORE any code changes (for progress tracking)

### Must NOT Have (Guardrails)
- DO NOT modify `backend-vecto.lisp` (PNG reference implementation)
- DO NOT modify SVG backend canvas dimensions or viewBox — they already match PNG correctly
- DO NOT add new external Lisp dependencies
- DO NOT embed TrueType fonts in PDF — accept Helvetica
- DO NOT implement true Gouraud shading (all backends use flat-color)
- DO NOT tune SVG coordinates to match ImageMagick's rasterization quirks — fix the tool, not the output
- DO NOT expand allowlist beyond what data justifies — minimize it
- DO NOT change compare.py JSON schema or HTML report format

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (FiveAM, 208 tests)
- **Automated tests**: Tests-after (compare.py SSIM checks)
- **Framework**: FiveAM (existing) + Python compare.py per-example
- **Primary metric**: Per-example SSIM at 0.95 threshold with allowlist

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Rendering fixes**: Bash — regenerate example, rasterize, run compare.py, check SSIM
- **compare.py changes**: Bash — run with various flags, check exit codes, parse JSON output
- **Test suite**: Bash — run `sbcl` with test-system, verify exit code 0

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — tooling + baselines):
├── Task 1: Capture baseline SSIM measurements (before ANY changes) [quick]
├── Task 2: Fix compare.py SVG DPI (96 not 100) + add --allowlist flag [unspecified-high]
└── Task 3: Add Makefile targets for compare-svg, compare-pdf [quick]

Wave 2 (After Wave 1 — PDF rendering fixes, PARALLEL):
├── Task 4: Fix PDF dash pattern scaling (linewidth-relative) [quick]
├── Task 5: Implement real PDF image rendering via cl-pdf native API [unspecified-high]
└── Task 6: Measure post-Wave-1 SVG SSIM improvement from DPI fix [quick]

Wave 3 (After Wave 2 — half-pixel snapping + regeneration):
├── Task 7: Port half-pixel snapping to SVG and PDF backends [deep]
└── Task 8: Regenerate all 79 examples + run comparison reports [quick]

Wave 4 (After Wave 3 — calibration + final):
├── Task 9: Calibrate allowlist based on final SSIM data [unspecified-high]
└── Task 10: Final comparison run at 0.95 threshold with allowlist [quick]

Wave FINAL (After ALL tasks — independent review, PARALLEL):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (oracle)

Critical Path: Task 1 → Task 2 → Task 5 → Task 8 → Task 9 → Task 10 → F1-F4
Parallel Speedup: ~50% faster than sequential
Max Concurrent: 3 (Waves 1, 2)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1 (Baseline) | — | 2, 4, 5, 6, 7 | 1 |
| 2 (compare.py DPI + allowlist) | — | 6, 8, 9, 10 | 1 |
| 3 (Makefile) | — | 8 | 1 |
| 4 (PDF dash scaling) | 1 | 8 | 2 |
| 5 (PDF image rendering) | 1 | 8 | 2 |
| 6 (SVG DPI measurement) | 2 | 7 | 2 |
| 7 (Half-pixel snapping) | 1, 6 | 8 | 3 |
| 8 (Regenerate + reports) | 2, 3, 4, 5, 7 | 9, 10 | 3 |
| 9 (Allowlist calibration) | 8 | 10 | 4 |
| 10 (Final comparison) | 2, 9 | F1-F4 | 4 |
| F1-F4 | 10 | — | FINAL |

### Agent Dispatch Summary

- **Wave 1**: 3 tasks — T1 → `quick`, T2 → `unspecified-high`, T3 → `quick`
- **Wave 2**: 3 tasks — T4 → `quick`, T5 → `unspecified-high`, T6 → `quick`
- **Wave 3**: 2 tasks — T7 → `deep`, T8 → `quick`
- **Wave 4**: 2 tasks — T9 → `unspecified-high`, T10 → `quick`
- **FINAL**: 4 tasks — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `oracle`

---

## TODOs

- [x] 1. Capture baseline SSIM measurements before any changes

  **What to do**:
  - Run compare.py for SVG at current DPI (100) to record pre-fix baseline:
    ```bash
    python3 tools/compare.py --reference examples/ --actual examples/ --format svg --output /tmp/baseline-svg/ --threshold 0.50
    ```
  - Run compare.py for PDF to record pre-fix baseline:
    ```bash
    python3 tools/compare.py --reference examples/ --actual examples/ --format pdf --output /tmp/baseline-pdf/ --threshold 0.50
    ```
  - Extract per-example SSIM scores from both summary.json files
  - Save complete per-example breakdown sorted ascending (worst first)
  - Record: mean, min, max, count below 0.95, count below 0.90

  **Must NOT do**:
  - DO NOT modify any files — this is measurement only

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3)
  - **Blocks**: Tasks 2, 4, 5, 6, 7 (provides baseline to measure improvement against)
  - **Blocked By**: None

  **References**:
  - `tools/compare.py` — comparison tool with `--format svg|pdf` flags
  - `comparison_report_svg/summary.json` — may already exist from previous run
  - `comparison_report_pdf/summary.json` — may already exist from previous run

  **Acceptance Criteria**:
  ```
  Scenario: SVG baseline captured
    Tool: Bash
    Steps:
      1. Run compare.py --format svg, parse summary.json
      2. Count: how many below 0.95, below 0.90, below 0.85
    Expected Result: 79 examples measured, mean ~0.870, scores saved
    Evidence: .sisyphus/evidence/task-1-svg-baseline.json

  Scenario: PDF baseline captured
    Tool: Bash
    Steps:
      1. Run compare.py --format pdf, parse summary.json
      2. Count: how many below 0.95, below 0.90
    Expected Result: 79 examples measured, mean ~0.925, scores saved
    Evidence: .sisyphus/evidence/task-1-pdf-baseline.json
  ```

  **Commit**: NO (measurement only)

- [x] 2. Fix compare.py: SVG rasterization DPI + add --allowlist mechanism

  **What to do**:
  - **DPI fix**: Change SVG rasterization default from `-density 100` to `-density 96`.
    The SVG backend correctly outputs dimensions in CSS px (1px = 1/96 inch).
    ImageMagick at `-density 100` produces 100/96 = 1.04x oversized images.
    When `--format svg`, default DPI should be 96 (not 100). For `--format pdf`, keep 100.
  - **Allowlist mechanism**: Add `--allowlist` CLI argument accepting a JSON file path.
    JSON format: `{"example-name": "reason string", ...}`
    When an example appears in the allowlist:
      - Still compute SSIM (do not skip)
      - Mark status as `"ALLOW"` instead of `"FAIL"` in summary.json
      - `ALLOW` examples do NOT count toward failure exit code
    Exit code: 0 if all PASS or ALLOW, 1 if any FAIL
  - **Backwards compatibility**: `--allowlist` is optional. Without it, behavior unchanged.

  **Must NOT do**:
  - DO NOT change HTML report layout
  - DO NOT change the SSIM calculation logic
  - DO NOT make the DPI change affect --format pdf or --format png

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3)
  - **Blocks**: Tasks 6, 8, 9, 10
  - **Blocked By**: None

  **References**:
  - `tools/compare.py:267-290` — `rasterize_to_png()` where DPI is used
  - `tools/compare.py:362-380` — argparse setup where `--dpi` default is defined
  - `tools/compare.py:382-460` — main loop where PASS/FAIL is determined

  **Acceptance Criteria**:
  ```
  Scenario: SVG at DPI 96 produces correct dimensions
    Tool: Bash
    Steps:
      1. Run compare.py --format svg --dpi 96
      2. Check for dimension mismatch warnings
    Expected Result: Fewer dimension mismatch warnings, mean SSIM > baseline
    Evidence: .sisyphus/evidence/task-2-dpi96-test.txt

  Scenario: --allowlist flag works
    Tool: Bash
    Steps:
      1. Create: echo '{"pcolormesh": "Gouraud test"}' > /tmp/test-al.json
      2. Run compare.py --threshold 0.99 --allowlist /tmp/test-al.json
      3. Check pcolormesh has status ALLOW, exit code reflects only FAILs
    Expected Result: ALLOW mechanism works correctly
    Evidence: .sisyphus/evidence/task-2-allowlist-test.txt

  Scenario: PNG backward compat
    Tool: Bash
    Steps:
      1. Run compare.py --format png --threshold 0.99
    Expected Result: 79/79 PASS, SSIM ~1.0
    Evidence: .sisyphus/evidence/task-2-png-compat.txt
  ```

  **Commit**: YES (groups with Task 3)
  - Message: `feat(tools): fix SVG rasterization DPI, add allowlist mechanism, add Makefile targets`
  - Files: `tools/compare.py`

- [x] 3. Add Makefile targets for compare-svg and compare-pdf

  **What to do**:
  - Add `compare-svg` target using --format svg --dpi 96 --threshold 0.95 --allowlist allowlist.json
  - Add `compare-pdf` target using --format pdf --threshold 0.95 --allowlist allowlist.json
  - Add `compare-all` target running compare, compare-svg, compare-pdf
  - Create empty `allowlist.json` (`{}`) if it doesn't exist

  **Recommended Agent Profile**: `quick`, Skills: []

  **Parallelization**: Wave 1 (with Tasks 1, 2). Blocks: Task 8. Blocked By: None.

  **References**: `Makefile` — existing `compare` target for PNG

  **Acceptance Criteria**:
  ```
  Scenario: make compare-svg runs
    Tool: Bash
    Steps: echo '{}' > allowlist.json && make compare-svg
    Expected Result: Produces comparison_report_svg/
    Evidence: .sisyphus/evidence/task-3-makefile.txt
  ```

  **Commit**: YES (groups with Task 2)
  - Files: `Makefile`

- [ ] 4. Fix PDF dash pattern scaling to use linewidth

  **What to do**:
  - In `src/backends/backend-pdf.lisp` `%apply-gc-to-pdf` (lines 64-78):
    Replace hardcoded `'(6 4)`, `'(6 3 2 3)`, `'(2 4)` with linewidth-scaled values.
  - Port SVG backend approach at `backend-svg.lisp:215-226`:
    Read base dash pattern, multiply each value by `(max lw 1.0)`.
  - Verify with test suite.

  **Must NOT do**: DO NOT change SVG dash handling. DO NOT modify backend-vecto.lisp.

  **Recommended Agent Profile**: `quick`, Skills: []

  **Parallelization**: Wave 2 (with Tasks 5, 6). Blocks: Task 8. Blocked By: Task 1.

  **References**:
  - `src/backends/backend-pdf.lisp:64-78` — hardcoded dash patterns to fix
  - `src/backends/backend-svg.lisp:200-226` — SVG dash scaling to port
  - `src/backends/backend-vecto.lisp:118-151` — Vecto dash reference

  **Acceptance Criteria**:
  ```
  Scenario: Tests pass, multi-line-styles SSIM improves
    Tool: Bash
    Steps: Run tests, regenerate multi-line-styles, check SSIM > 0.90 (was 0.869)
    Evidence: .sisyphus/evidence/task-4-dash-improvement.txt
  ```

  **Commit**: YES
  - Message: `fix(pdf): scale dash patterns by linewidth for rendering parity`
  - Files: `src/backends/backend-pdf.lisp`

- [ ] 5. Implement real PDF image rendering via cl-pdf native API

  **What to do**:
  - Replace placeholder gray rect in `draw-image` (lines 364-381 of backend-pdf.lisp).
  - Use cl-pdf's native image support:
    1. Convert RGBA data to PNG using zpng (same pattern as SVG backend)
    2. Write to temp file
    3. Load with `(pdf:make-image temp-path)`
    4. Draw with `(pdf:draw-image image x y width height)`
    5. Clean up temp file in unwind-protect
  - Follow SVG pattern at `backend-svg.lisp:426-459` for zpng encoding.
  - Handle alpha: pre-composite against white if cl-pdf doesn't support RGBA.
  - Test full pipeline first: zpng → make-image → draw-image → write-document.
  - IMPORTANT: verify cl-pdf's patched `extended-ascii-p` (lines 18-21) handles image streams.

  **Must NOT do**: DO NOT write custom PDF XObject code. DO NOT add new deps. DO NOT modify Vecto.

  **Recommended Agent Profile**: `unspecified-high`, Skills: []

  **Parallelization**: Wave 2 (with Tasks 4, 6). Blocks: Task 8. Blocked By: Task 1.

  **References**:
  - `src/backends/backend-pdf.lisp:364-381` — placeholder to replace
  - `src/backends/backend-pdf.lisp:18-21` — `extended-ascii-p` patch
  - `src/backends/backend-svg.lisp:426-459` — zpng encoding pattern to reuse
  - `src/backends/backend-vecto.lisp:400-451` — image data structure reference
  - cl-pdf API: `pdf:make-image`, `pdf:draw-image`

  **Acceptance Criteria**:
  ```
  Scenario: imshow-heatmap PDF renders actual image, SSIM > 0.90 (was 0.827)
    Tool: Bash
    Steps: Regenerate, rasterize, compare SSIM against baseline
    Evidence: .sisyphus/evidence/task-5-pdf-image-ssim.txt

  Scenario: Test suite passes (208/208)
    Evidence: .sisyphus/evidence/task-5-test-suite.txt
  ```

  **Commit**: YES
  - Message: `fix(pdf): implement real image rendering via cl-pdf native API`
  - Files: `src/backends/backend-pdf.lisp`

- [ ] 6. Measure post-DPI-fix SVG SSIM improvement

  **What to do**:
  - After Task 2, re-run SVG comparison at DPI 96. Compare per-example scores against baseline.
  - Report: mean improvement, count now above 0.95, biggest movers.
  - This data informs whether half-pixel snapping (Task 7) is worth pursuing.

  **Recommended Agent Profile**: `quick`, Skills: []

  **Parallelization**: Wave 2. Blocks: Task 7. Blocked By: Task 2.

  **Acceptance Criteria**:
  ```
  Scenario: SVG improvement documented
    Tool: Bash
    Steps: Run compare.py --format svg --dpi 96, compare against baseline
    Evidence: .sisyphus/evidence/task-6-dpi-improvement.json
  ```

  **Commit**: NO (measurement only)

- [ ] 7. Port half-pixel snapping to SVG and PDF backends

  **What to do**:
  - Read Vecto's implementation at `backend-vecto.lisp:170-219`.
  - It snaps axis-aligned path segments to 0.5-pixel boundaries for crispness.
  - Port to SVG `%trace-path-to-svg` and PDF `%trace-path-to-pdf`:
    If `y1 == y2` (horizontal), snap y to `round(y) + 0.5`.
    If `x1 == x2` (vertical), snap x to `round(x) + 0.5`.
  - Measure SSIM improvement. Keep change even if SSIM gain < 0.01 (rendering quality).

  **Must NOT do**: DO NOT snap curves/diagonals. DO NOT modify Vecto. DO NOT change SVG viewBox.

  **Recommended Agent Profile**: `deep`, Skills: []

  **Parallelization**: Wave 3. Blocks: Task 8. Blocked By: Tasks 1, 6.

  **References**:
  - `src/backends/backend-vecto.lisp:170-219` — snapping algorithm to port
  - `src/backends/backend-svg.lisp:90-130` — SVG path tracing to modify
  - `src/backends/backend-pdf.lisp:90-160` — PDF path tracing to modify

  **Acceptance Criteria**:
  ```
  Scenario: Tests pass, SSIM measured
    Tool: Bash
    Steps: Run tests, regenerate 3 examples, compare SVG+PDF SSIM vs Task 6
    Evidence: .sisyphus/evidence/task-7-snapping-improvement.json
  ```

  **Commit**: YES
  - Message: `fix(svg,pdf): add half-pixel snapping for axis-aligned paths`
  - Files: `src/backends/backend-svg.lisp`, `src/backends/backend-pdf.lisp`

- [ ] 8. Regenerate all 79 examples + run full comparison reports

  **What to do**:
  - Regenerate ALL 79 examples (SVG, PDF, PNG).
  - Run full SVG comparison at 0.95 threshold (DPI 96) and PDF comparison at 0.95.
  - Report per-example SSIM, count PASS/FAIL, list all FAILs.
  - This feeds Task 9 (allowlist calibration).

  **Recommended Agent Profile**: `quick`, Skills: []

  **Parallelization**: Wave 3. Blocks: Tasks 9, 10. Blocked By: Tasks 2-7.

  **Acceptance Criteria**:
  ```
  Scenario: 79 examples regenerated, reports generated
    Tool: Bash
    Steps: Count files, check summary.json, list FAILs
    Evidence: .sisyphus/evidence/task-8-comparison-results.json
  ```

  **Commit**: YES (groups with Tasks 9-10)

- [ ] 9. Calibrate allowlist based on final SSIM data

  **What to do**:
  - Analyze Task 8 results. Identify all examples with SSIM < 0.95.
  - Categorize root cause per failing example:
    - **Gouraud flat-color**: pcolormesh examples
    - **Font difference**: text-heavy PDFs with Helvetica gap
    - **Rasterizer difference**: SVGs where ImageMagick differs from Vecto
    - **Rendering bug**: actual fixable bugs — DO NOT allowlist these
  - Create `allowlist.json` with per-format entries and documented reasons.
  - MINIMIZE the allowlist. If >20 SVG entries needed, document as comparison pipeline limitation.

  **Recommended Agent Profile**: `unspecified-high`, Skills: []

  **Parallelization**: Wave 4. Blocks: Task 10. Blocked By: Task 8.

  **Acceptance Criteria**:
  ```
  Scenario: allowlist.json created, minimal, documented
    Tool: Bash
    Steps: cat allowlist.json, count entries, verify each has reason
    Evidence: .sisyphus/evidence/task-9-allowlist.json
  ```

  **Commit**: YES (groups with Task 8)
  - Files: `allowlist.json`

- [ ] 10. Final comparison run at 0.95 threshold with allowlist

  **What to do**:
  - Run SVG: `compare.py --format svg --dpi 96 --threshold 0.95 --allowlist allowlist.json`
  - Run PDF: `compare.py --format pdf --threshold 0.95 --allowlist allowlist.json`
  - Verify: ZERO FAIL in both. Run test suite one final time.

  **Recommended Agent Profile**: `quick`, Skills: []

  **Parallelization**: Wave 4. Blocks: F1-F4. Blocked By: Task 9.

  **Acceptance Criteria**:
  ```
  Scenario: SVG+PDF 0 FAIL at 0.95 with allowlist, tests pass
    Tool: Bash
    Steps: Run both comparisons with --allowlist, check exit 0, run tests
    Evidence: .sisyphus/evidence/task-10-svg-final.txt, task-10-pdf-final.txt, task-10-tests.txt
  ```

  **Commit**: YES (groups with Tasks 8, 9)
  - Files: `comparison_report_svg/`, `comparison_report_pdf/`, `examples/*`

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists. For each "Must NOT Have": search for forbidden patterns. Check evidence files. Compare deliverables against plan. Verify allowlist.json exists and is minimal.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run full test suite. Review all changed files (backend-pdf.lisp, backend-svg.lisp, compare.py, Makefile). Check for empty catches, debug prints, TODO/FIXME, unused vars. Verify Python syntax. Check scope creep.
  Output: `Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Regenerate 5 representative examples. Parse SVG XML, rasterize PDFs. Run compare.py with --allowlist. Verify HTML reports. Check per-example SSIM scores. Test allowlist mechanism (ALLOW vs FAIL status).
  Output: `SVG [N/N pass] | PDF [N/N pass] | Allowlist [working/broken] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `oracle`
  For each task: read spec, read actual diff. Verify 1:1 compliance. Check backend-vecto.lisp UNCHANGED. Check SVG canvas dimensions UNCHANGED. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Vecto unchanged [YES/NO] | VERDICT`

---

## Commit Strategy

- **Commit 1** (after Tasks 2-3): `feat(tools): fix SVG rasterization DPI, add allowlist mechanism, add Makefile targets`
- **Commit 2** (after Task 4): `fix(pdf): scale dash patterns by linewidth for rendering parity`
- **Commit 3** (after Task 5): `fix(pdf): implement real image rendering via cl-pdf native API`
- **Commit 4** (after Task 7): `fix(svg,pdf): add half-pixel snapping for axis-aligned paths`
- **Commit 5** (after Tasks 8-10): `chore: regenerate examples, calibrate allowlist, update comparison reports`

---

## Success Criteria

### Verification Commands
```bash
# 1. SVG comparison at 0.95 with allowlist
python3 tools/compare.py --reference examples/ --actual examples/ --format svg --dpi 96 --threshold 0.95 --allowlist allowlist.json --output comparison_report_svg/
# Expected: exit 0 (all PASS or ALLOW, no FAIL)

# 2. PDF comparison at 0.95 with allowlist
python3 tools/compare.py --reference examples/ --actual examples/ --format pdf --threshold 0.95 --allowlist allowlist.json --output comparison_report_pdf/
# Expected: exit 0 (all PASS or ALLOW, no FAIL)

# 3. Test suite green
sbcl --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit
# Expected: 208/208 pass, exit 0

# 4. Allowlist is minimal
python3 -c "import json; al=json.load(open('allowlist.json')); print(f'Allowlist: {len(al)} entries'); [print(f'  {k}: {v}') for k,v in al.items()]"
# Expected: Minimal entries with documented justifications
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass (208/208)
- [ ] SVG: 0 FAIL at 0.95 threshold (with allowlist)
- [ ] PDF: 0 FAIL at 0.95 threshold (with allowlist)
- [ ] Allowlist documented and minimal
