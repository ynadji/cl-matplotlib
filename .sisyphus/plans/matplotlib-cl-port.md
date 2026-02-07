# Port matplotlib to Pure Common Lisp (cl-matplotlib)

## TL;DR

> **Quick Summary**: Full port of Python's matplotlib (~196K LOC) to pure (zero-CFFI) Common Lisp, producing an idiomatic CL library named `cl-matplotlib` with PNG and PDF output backends. Includes all ~2,571 tests with new CL-native baselines.
> 
> **Deliverables**:
> - `cl-matplotlib` ASDF system loadable via Quicklisp/ASDF
> - PNG output via Vecto/cl-aa rasterization (extended as needed)
> - PDF output via cl-pdf
> - Font rendering via zpb-ttf (pure CL, no FreeType)
> - FiveAM test suite with ~2,571 tests + new baseline images
> - Cross-validation pipeline comparing CL output against Python reference images
> 
> **Estimated Effort**: XL (12-18 months, multi-phase)
> **Parallel Execution**: YES — Phases 0-3 sequential, then parallel waves
> **Critical Path**: Phase 0 (validate feasibility) → Phase 1 (foundation) → Phase 2 (primitives) → Phase 3 (rendering) → Phase 4 (containers/MVP) → Phase 5-8 parallel

---

## Context

### Original Request
Port the Python library matplotlib (located at `~/src/matplotlib`) fully to portable Common Lisp. All of the same tests must be included. Port the generic backend structure, but only support PNG/PDF output for now. Code may be slightly altered to fit idiomatic CL style. Tests should be more or less identical.

### Interview Summary
**Key Discussions**:
- **Portability**: Pure CL only — zero CFFI, zero C dependencies. Use zpb-ttf for fonts.
- **Test baselines**: Generate new CL-native baselines. Tests verify CL consistency, not Python pixel-identity.
- **Library name**: `cl-matplotlib`
- **mpl_toolkits**: Excluded for now (3D, axisartist, axes_grid1)
- **rcParams**: Relevant subset only (~150-200 params for PNG/PDF output)

**Research Findings**:
- matplotlib: ~196K LOC Python, 12 C++ files, 253 .py modules, 94 test files
- Architecture: Foundation → Primitives → Rendering → Containers → Formatting → Backends → Interface
- CL ecosystem has building blocks: Vecto (raster), cl-pdf (PDF), zpb-ttf (fonts), FiveAM (testing)
- No prior matplotlib→CL port exists anywhere
- Oracle recommended: CLOS 1:1 mapping, 6 ASDF systems, 8 phases, Vecto + cl-pdf backends

### Metis Review
**Identified Gaps** (addressed):
- Vecto has significant capability gaps vs. matplotlib needs (no dashes, no clipping, no image blitting) → Added Phase 0 PoC to validate/extend
- Mathtext engine is a TeX subset (~5K LOC) → Included as Phase 6 with explicit scope
- No correctness oracle (CL baselines are self-referential) → Added cross-validation pipeline against Python reference images
- numcl may not support matplotlib's array patterns → Added validation in Phase 0
- "Idiomatic CL" vs "identical tests" tension → Defined precisely: naming/structure changes OK, API semantics preserved
- Contour generation requires marching squares → Included in Phase 5
- Font management system (~2K LOC) unplanned → Added to Phase 3
- Performance criteria undefined → Added per-phase benchmarks
- Function-level scope undefined → Phase 0 produces explicit IN/OUT/DEFERRED list

---

## Work Objectives

### Core Objective
Create `cl-matplotlib`, a pure Common Lisp library that reproduces matplotlib's core plotting functionality with PNG and PDF output, passing a ported test suite of ~2,571 tests with CL-native baseline images.

### Concrete Deliverables
- 6 ASDF systems: `cl-matplotlib-foundation`, `cl-matplotlib-primitives`, `cl-matplotlib-rendering`, `cl-matplotlib-containers`, `cl-matplotlib-backends`, `cl-matplotlib-pyplot`
- 1 test system: `cl-matplotlib-tests` (FiveAM)
- PNG backend using Vecto/cl-aa (extended with dashes, clipping, image blitting)
- PDF backend using cl-pdf
- Font rendering via zpb-ttf
- ~2,225 new CL-native baseline images
- Cross-validation report showing SSIM ≥ 0.85 against Python reference images

### Definition of Done
- [ ] `(ql:quickload :cl-matplotlib)` succeeds on SBCL and CCL
- [ ] `(asdf:test-system :cl-matplotlib-tests)` passes ≥ 95% of ported tests
- [ ] Can produce valid PNG and PDF files for all core plot types
- [ ] Cross-validation SSIM ≥ 0.85 against Python reference images for core plots

### Must Have
- All core plot types: plot, scatter, bar, hist, pie, fill, errorbar, boxplot, stem, step, stackplot, imshow, contour/contourf
- Axes, Figure, Axis, Ticks, Labels, Legends, Colorbars
- Transform system with invalidation caching
- Path system with clipping, simplification, point-in-path
- Color system with colormaps (core ~20 maps)
- rcParams configuration (PNG/PDF-relevant subset)
- pyplot procedural interface
- savefig to PNG and PDF

### Must NOT Have (Guardrails)
- NO CFFI or C dependencies of any kind
- NO GUI backends (Qt, GTK, Tk, wxWidgets, macOS, WebAgg)
- NO interactive features (widgets, event handling, mouse/keyboard callbacks)
- NO animation framework
- NO mpl_toolkits (3D, axisartist, axes_grid1)
- NO `**kwargs` passthrough chains — use explicit CLOS initargs
- NO string-based enums from Python — use CL keyword symbols (`:solid`, `:dashed`, not `"solid"`, `"--"`)
- NO porting ALL 150+ colormaps — core set of ~20, extensible engine
- NO porting ALL ticker/locator types — core set sufficient for standard plots
- NO Sphinx extensions or documentation generation
- NO SVG backend "while we're at it"
- NO performance-critical path without `(declare (optimize (speed 3)))` and type declarations

---

## Verification Strategy (MANDATORY)

> **UNIVERSAL RULE: ZERO HUMAN INTERVENTION**
>
> ALL tasks in this plan MUST be verifiable WITHOUT any human action.
> Every criterion is verified by running CL code or shell commands.

### Test Decision
- **Infrastructure exists**: NO (greenfield project)
- **Automated tests**: YES (Tests-after — build module, then port tests for it)
- **Framework**: FiveAM

### Test Infrastructure (Built in Phase 0)
- FiveAM test suites mirroring matplotlib's test file organization
- Custom `def-image-test` macro wrapping FiveAM's `test` with image comparison
- Image comparison via pixel-level RMS and structural similarity (SSIM)
- Cross-validation pipeline: render with both Python matplotlib and CL, compare with SSIM
- Baseline generation mode: `(setf cl-matplotlib-tests:*generate-baselines* t)`

### Agent-Executed QA Scenarios (MANDATORY — ALL tasks)

> Every task includes executable verification scenarios.
> The executing agent will run CL code, check outputs, and capture evidence.

**Verification Tool by Deliverable Type:**

| Type | Tool | How Agent Verifies |
|------|------|-------------------|
| **CL library code** | Bash (sbcl --script) | Load system, call functions, check return values |
| **PNG output** | Bash (sbcl + identify/file) | Generate PNG, verify file is valid PNG, check dimensions |
| **PDF output** | Bash (sbcl + file) | Generate PDF, verify file is valid PDF |
| **Test suite** | Bash (sbcl --eval '(asdf:test-system ...)') | Run tests, parse pass/fail counts |
| **Cross-validation** | Bash (python3 + sbcl + compare) | Generate reference + CL output, compute SSIM |

---

## Execution Strategy

### Parallel Execution Waves

```
Phase 0 (Validation):
└── Rendering PoC + Feasibility validation (GATE: go/no-go on Vecto)

Phase 1 (Foundation):
└── Foundation system (cbook, rcsetup, config)

Phase 2 (Primitives — after Phase 1):
├── Task 2a: Path system + algorithms
├── Task 2b: Transform system
└── Task 2c: Color system + colormaps

Phase 3 (Rendering — after Phase 2):
├── Task 3a: Artist base + rendering primitives
├── Task 3b: Vecto PNG backend (extended)
├── Task 3c: cl-pdf PDF backend
└── Task 3d: Font management + text rendering

Phase 4 (Containers/MVP — after Phase 3):
├── Task 4a: Figure + FigureCanvas
├── Task 4b: Axes (base + _axes with plot/scatter/bar)
├── Task 4c: Axis + Ticker + Spines
└── Task 4d: Legend + Colorbar

Phase 5 (Extended Features — after Phase 4):
├── Task 5a: Scale (log, symlog, logit)
├── Task 5b: GridSpec + subplot layouts
├── Task 5c: Collections + advanced artists (hatching, markers)
├── Task 5d: Contour (marching squares in pure CL)
└── Task 5e: Image display (imshow + interpolation)

Phase 6 (Mathtext + Specialized — after Phase 4):
├── Task 6a: Mathtext parser + layout engine
├── Task 6b: Additional plot types (hist, pie, errorbar, boxplot, stem, step, stackplot)
└── Task 6c: Annotation system (FancyArrowPatch, text annotations)

Phase 7 (Interface — after Phase 5, 6):
├── Task 7a: pyplot procedural interface
├── Task 7b: Full rcParams system
└── Task 7c: Style sheets

Phase 8 (Tests + Polish — after Phase 7):
├── Task 8a: Port all test files (batch — 94 files)
├── Task 8b: Generate CL-native baseline images
├── Task 8c: Cross-validation against Python references
└── Task 8d: CI setup (SBCL + CCL)

Critical Path: Phase 0 → 1 → 2 → 3 → 4 → 7 → 8
Parallel Groups: (2a, 2b, 2c), (3a, 3b, 3c, 3d), (5a-e ∥ 6a-c)
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 0 | None | 1-8 (go/no-go gate) | Nothing |
| 1 | 0 | 2a, 2b, 2c | Nothing |
| 2a | 1 | 3a, 3b | 2b, 2c |
| 2b | 1 | 3a, 3b, 4a | 2a, 2c |
| 2c | 1 | 3a, 3d | 2a, 2b |
| 3a | 2a, 2b, 2c | 4a, 4b | 3b, 3c, 3d |
| 3b | 2a, 2b | 4a | 3a, 3c, 3d |
| 3c | 2a, 2b | 4a | 3a, 3b, 3d |
| 3d | 2c | 4c | 3a, 3b, 3c |
| 4a | 3a, 3b, 3c | 5a-e, 7a | 4b, 4c, 4d |
| 4b | 3a, 4a | 5b, 6b, 7a | 4c, 4d |
| 4c | 3d, 4a | 5a, 7a | 4b, 4d |
| 4d | 4b | 7a | 4c |
| 5a-e | 4a, 4b, 4c | 7a | 6a-c |
| 6a-c | 4a, 4b | 7a | 5a-e |
| 7a-c | 5, 6 | 8 | Nothing |
| 8a-d | 7 | None | Batch parallel |

---

## TODOs

### Phase 0: Rendering Proof-of-Concept & Feasibility Validation

- [x] 0. Rendering PoC + Feasibility Validation (GATE)

  **What to do**:
  - Create a proof-of-concept CL file that uses Vecto + zpb-ttf to render:
    - A solid line with round caps
    - A dashed line (implement dash pattern extension for Vecto)
    - A filled polygon with alpha transparency
    - A clipped region (implement clip path extension for Vecto)
    - Text labels using zpb-ttf glyph outlines rendered through cl-aa
    - An embedded raster image (implement pixel blitting into Vecto canvas)
  - Test numcl fitness: take 20 most common numpy operations used in matplotlib source, verify each has a numcl equivalent or document the gap
  - Validate trivial-garbage weak reference finalization callbacks on SBCL and CCL
  - Generate a Python reference image via matplotlib for the same plot, compute SSIM between Python and CL outputs
  - Produce a function-level scope document: scan all public functions in matplotlib, classify each as IN/OUT/DEFERRED
  - Set up project structure: git repo, ASDF system files, package definitions, directory layout
  - Install dependencies via Quicklisp: vecto, cl-pdf, zpb-ttf, fiveam, trivial-garbage, zpng
  - **GATE DECISION**: If Vecto extensions take >2 weeks or produce unacceptable quality, pivot to building directly on cl-aa with custom scanline rasterizer

  **Must NOT do**:
  - Don't port any matplotlib code yet
  - Don't optimize for performance yet
  - Don't set up CI yet

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Feasibility exploration requiring autonomous research and experimentation
  - **Skills**: [`playwright`]
    - `playwright`: For screenshot-based visual verification of rendered output

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (must complete before all other phases)
  - **Blocks**: All subsequent phases
  - **Blocked By**: None

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/backends/backend_agg.py:58-361` — RendererAgg showing what draw_path, draw_text, draw_image need to produce
  - `/home/yacin/src/matplotlib/lib/matplotlib/backend_bases.py:134-691` — RendererBase abstract interface defining the minimum backend protocol
  - `/home/yacin/src/matplotlib/lib/matplotlib/backend_bases.py:693-1022` — GraphicsContextBase showing all rendering state properties

  **API/Type References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/path.py` — Path class showing vertices+codes representation
  - `/home/yacin/src/matplotlib/lib/matplotlib/transforms.py` — Transform hierarchy showing affine 3×3 matrix format

  **External References**:
  - Vecto documentation: http://www.xach.com/lisp/vecto/
  - cl-aa documentation: anti-aliased scanline rasterization
  - zpb-ttf: https://github.com/xach/zpb-ttf — TTF glyph outline extraction
  - trivial-garbage: https://github.com/trivial-garbage/trivial-garbage — portable weak references

  **WHY Each Reference Matters**:
  - RendererAgg shows the actual draw calls we need to replicate — this is the target interface
  - RendererBase defines what our Vecto backend MUST implement to be a valid backend
  - GraphicsContextBase shows every rendering property (dashes, clips, alpha, etc.) we must support
  - Path.py defines the vertex+code representation we must consume
  - Vecto docs tell us what's already available vs what we must extend

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Vecto PoC renders reference plot to PNG
    Tool: Bash (sbcl --script)
    Preconditions: Quicklisp installed, vecto/zpb-ttf/zpng available
    Steps:
      1. sbcl --load poc.lisp --eval '(render-poc "/tmp/cl-matplotlib-poc.png")'
      2. file /tmp/cl-matplotlib-poc.png → Assert "PNG image data"
      3. identify /tmp/cl-matplotlib-poc.png → Assert dimensions ≥ 640x480
      4. Assert file size > 10KB (not blank/trivial)
    Expected Result: Valid PNG with visible plot elements
    Evidence: .sisyphus/evidence/phase0-poc-render.png

  Scenario: Dashed line rendering works
    Tool: Bash (sbcl --script)
    Preconditions: Vecto dash extension implemented
    Steps:
      1. Render a dashed line with pattern [5 3 2 3] to PNG
      2. Load PNG, sample pixels along the line path
      3. Assert alternating drawn/gap segments are present
    Expected Result: Visible dash pattern in output
    Evidence: .sisyphus/evidence/phase0-dash-test.png

  Scenario: Cross-validation SSIM against Python
    Tool: Bash (python3 + sbcl)
    Preconditions: Python matplotlib installed, CL PoC working
    Steps:
      1. python3 -c "generate simple reference plot → /tmp/py-ref.png"
      2. sbcl --load poc.lisp --eval '(render-same-plot "/tmp/cl-ref.png")'
      3. python3 -c "from skimage.metrics import structural_similarity; ssim = structural_similarity(py, cl, channel_axis=2); print(ssim)"
      4. Assert SSIM ≥ 0.70 (lenient for PoC — different rasterizers)
    Expected Result: Structural similarity above threshold
    Evidence: .sisyphus/evidence/phase0-ssim-report.txt

  Scenario: numcl validation of top-20 numpy ops
    Tool: Bash (sbcl --script)
    Preconditions: numcl loaded
    Steps:
      1. Test: array creation (zeros, ones, arange, linspace)
      2. Test: arithmetic (add, subtract, multiply, divide)
      3. Test: reduction (sum, min, max, mean)
      4. Test: shape ops (reshape, transpose, concatenate)
      5. Test: comparison (>, <, ==, where/mask)
      6. For each, assert correct result or document gap
    Expected Result: ≥ 16/20 operations work, gaps documented
    Evidence: .sisyphus/evidence/phase0-numcl-validation.txt

  Scenario: trivial-garbage weak ref finalization
    Tool: Bash (sbcl --script)
    Preconditions: trivial-garbage loaded
    Steps:
      1. Create object with weak pointer and finalization callback
      2. Remove strong reference
      3. Force GC
      4. Assert finalization callback was called
    Expected Result: Callback fires on both SBCL and CCL
    Evidence: .sisyphus/evidence/phase0-weakref-test.txt
  ```

  **Evidence to Capture:**
  - [ ] .sisyphus/evidence/phase0-poc-render.png
  - [ ] .sisyphus/evidence/phase0-dash-test.png
  - [ ] .sisyphus/evidence/phase0-ssim-report.txt
  - [ ] .sisyphus/evidence/phase0-numcl-validation.txt
  - [ ] .sisyphus/evidence/phase0-weakref-test.txt
  - [ ] .sisyphus/evidence/phase0-scope-document.md (function-level IN/OUT/DEFERRED list)

  **Commit**: YES
  - Message: `feat(core): phase 0 — rendering PoC and feasibility validation`
  - Files: `poc.lisp`, `cl-matplotlib.asd`, `src/packages.lisp`, scope doc
  - Pre-commit: `sbcl --load poc.lisp --eval '(render-poc "/tmp/test.png")' --quit`

---

### Phase 1: Foundation

- [x] 1. Foundation System (cl-matplotlib-foundation)

  **What to do**:
  - Port `cbook.py` utilities (cherry-pick useful functions: `normalize-kwargs`, `silent-list`, `ls-mapper`, type-checking helpers, `_check_isinstance`, `_check_in_list`, `_check_shape`, dict/list utilities). Skip deprecated functions and Python-only patterns.
  - Port `rcsetup.py` as rc-params system: hash table with validator functions, `define-rc-param` macro, `with-rc` context macro, `rc` accessor. Only include ~150-200 params relevant to PNG/PDF output.
  - Port `_api/` utilities: deprecation warning system, caching decorators (adapt to CL `load-time-value` and memoize patterns)
  - Define package hierarchy: `cl-matplotlib`, `cl-matplotlib.cbook`, `cl-matplotlib.rc`, `cl-matplotlib.api`
  - Write the `matplotlibrc` file parser (simple `key : value` format, ~50 LOC)
  - Port color name database and CSS4 color constants

  **Must NOT do**:
  - Don't port Python-specific utilities (pickle, subprocess, importlib helpers)
  - Don't port GUI-related rcParams
  - Don't port the logging system (use CL conditions)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Foundational code requiring careful design decisions, not purely frontend or backend
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: 2a, 2b, 2c
  - **Blocked By**: Phase 0

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/cbook.py` — Utility functions (cherry-pick, don't port everything)
  - `/home/yacin/src/matplotlib/lib/matplotlib/rcsetup.py` — RC param definitions with validators
  - `/home/yacin/src/matplotlib/lib/matplotlib/_api/__init__.py` — API utilities (deprecation, caching)

  **API/Type References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/__init__.py` — RcParams class definition, default loading
  - `/home/yacin/src/matplotlib/lib/matplotlib/mpl-data/matplotlibrc` — Default config file format

  **WHY Each Reference Matters**:
  - cbook.py contains shared utilities used by every other module — must port first
  - rcsetup.py defines the configuration schema — needed before any rendering code
  - matplotlibrc shows the file format our parser must read

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: RC params load and validate
    Tool: Bash (sbcl --script)
    Steps:
      1. (ql:quickload :cl-matplotlib-foundation)
      2. (cl-matplotlib.rc:rc "lines.linewidth") → Assert returns 1.5 (default)
      3. (setf (cl-matplotlib.rc:rc "lines.linewidth") 2.0) → Assert succeeds
      4. (setf (cl-matplotlib.rc:rc "lines.linewidth") -1.0) → Assert signals error
      5. (cl-matplotlib.rc:with-rc (("lines.linewidth" 3.0)) (cl-matplotlib.rc:rc "lines.linewidth")) → Assert 3.0
      6. (cl-matplotlib.rc:rc "lines.linewidth") → Assert 2.0 (restored)
    Expected Result: Config system works with validation and dynamic rebinding
    Evidence: .sisyphus/evidence/phase1-rc-params.txt

  Scenario: cbook utilities work
    Tool: Bash (sbcl --script)
    Steps:
      1. (cl-matplotlib.cbook:normalize-kwargs '(:line-width 2 :color "red") ...) → Assert normalized
      2. Type checking: (cl-matplotlib.cbook:check-isinstance 42 'integer) → no error
      3. Type checking: (cl-matplotlib.cbook:check-isinstance "hi" 'integer) → signals error
    Expected Result: Core utilities functional
    Evidence: .sisyphus/evidence/phase1-cbook.txt
  ```

  **Commit**: YES
  - Message: `feat(foundation): rc-params, cbook utilities, API helpers`
  - Files: `src/foundation/*.lisp`
  - Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-foundation)' --quit`

---

### Phase 2: Primitives (Parallel Wave)

- [x] 2a. Path System

  **What to do**:
  - Port `path.py` Path class: vertices (simple-array double-float (* 2)), codes (simple-array (unsigned-byte 8) (*))
  - Define path code constants: `+moveto+` (1), `+lineto+` (2), `+curve3+` (3), `+curve4+` (4), `+closepoly+` (79)
  - Port path operations: `iter-segments`, `iter-bezier`, `get-extents`, `cleaned`, `contains-point`, `contains-points`, `intersects-path`, `intersects-bbox`, `transformed`, `to-polygons`, `clip-to-bbox`, `interpolated`
  - Port path constructors: `make-compound-path`, `unit-rectangle`, `unit-circle`, `arc`, `wedge`
  - Implement C++ algorithms in pure CL with type declarations:
    - Winding number point-in-path (~50 LOC)
    - Sutherland-Hodgman polygon clipping (~80 LOC)
    - Douglas-Peucker path simplification (~40 LOC)
    - Pixel grid snapping (~20 LOC)
    - De Casteljau Bézier curve subdivision (~60 LOC)
    - Bézier curve extrema calculation for bounds
  - Port unit tests from `test_path.py` (~658 lines)

  **Must NOT do**:
  - Don't optimize prematurely — correctness first
  - Don't port the `_path_wrapper.cpp` verbatim — reimplement algorithms idiomatically

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Computational geometry algorithms require careful mathematical reasoning
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with 2b, 2c)
  - **Blocks**: 3a, 3b
  - **Blocked By**: Phase 1

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/path.py` — Complete Path class with all methods
  - `/home/yacin/src/matplotlib/src/_path.h` — C++ algorithms (point-in-path, clipping, simplification)
  - `/home/yacin/src/matplotlib/src/_path_wrapper.cpp` — Python bindings showing exact function signatures

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_path.py` — 658 lines of path tests
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_simplification.py` — Path simplification tests

  **WHY Each Reference Matters**:
  - path.py defines every method signature and behavior we must reproduce
  - _path.h contains the actual C++ algorithm implementations to port to CL
  - test_path.py contains the exact test cases we must pass

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Path creation and basic operations
    Tool: Bash (sbcl --script)
    Steps:
      1. Create path from vertices and codes
      2. (path-get-extents path) → Assert bounding box correct
      3. (path-contains-point path #(0.5 0.5)) → Assert T for point inside unit square
      4. (path-contains-point path #(2.0 2.0)) → Assert NIL for point outside
      5. (path-unit-circle) → Assert 19 vertices, correct codes
    Expected Result: Path operations produce correct results
    Evidence: .sisyphus/evidence/phase2a-path-ops.txt

  Scenario: Path clipping
    Tool: Bash (sbcl --script)
    Steps:
      1. Create a line path crossing a bounding box
      2. (path-clip-to-bbox path bbox) → Assert clipped path only inside bbox
      3. Verify clipped vertices are on bbox boundaries
    Expected Result: Sutherland-Hodgman clipping works correctly
    Evidence: .sisyphus/evidence/phase2a-path-clip.txt

  Scenario: Path tests pass
    Tool: Bash (sbcl --eval)
    Steps:
      1. (asdf:test-system :cl-matplotlib-primitives/path-tests)
      2. Parse FiveAM output for pass/fail counts
    Expected Result: ≥ 90% of ported path tests pass
    Evidence: .sisyphus/evidence/phase2a-test-results.txt
  ```

  **Commit**: YES
  - Message: `feat(primitives): path system with CL-native geometry algorithms`
  - Files: `src/primitives/path.lisp`, `src/primitives/path-algorithms.lisp`, `tests/test-path.lisp`
  - Pre-commit: `sbcl --eval '(asdf:test-system :cl-matplotlib-primitives)' --quit`

- [x] 2b. Transform System

  **What to do**:
  - Port CLOS class hierarchy: `transform-node` → `bbox-base`/`transform` → `affine-2d-base` → `affine-2d`, `composite-affine-2d`, `identity-transform`, `bbox-transform`, `blended-affine-2d`, `composite-generic-transform`, `blended-generic-transform`, `transform-wrapper`, `transformed-bbox`, `transformed-path`
  - Implement invalidation caching using `trivial-garbage` weak pointers:
    - `+valid+` (0), `+invalid-affine-only+` (1), `+invalid-full+` (2)
    - Walk weak-pointer children on invalidation, prune dead refs
  - Implement 3×3 affine matrix operations as `(simple-array double-float (6))`:
    - Matrix multiply (inline, ~6 muls + 4 adds)
    - Matrix inversion
    - Transform point, transform path
  - Implement transform composition via `compose` generic function with type-dispatched methods
  - Implement `frozen-transform` for immutable snapshots
  - Port unit tests from `test_transforms.py`

  **Must NOT do**:
  - Don't use BLAS/LAPACK — 3×3 matrices are trivial
  - Don't use operator overloading (+/-) — use `compose` generic function
  - Don't implement non-rectilinear projections yet (polar, geo)

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Complex invalidation tree with weak references requires precise reasoning
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with 2a, 2c)
  - **Blocks**: 3a, 3b, 4a
  - **Blocked By**: Phase 1

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/transforms.py` — Complete transform hierarchy (3,900+ lines of actual code)

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_transforms.py` — Transform unit tests

  **External References**:
  - trivial-garbage API: `make-weak-pointer`, `weak-pointer-value`, `finalize`

  **WHY Each Reference Matters**:
  - transforms.py is the single most architecturally critical module — every coordinate conversion goes through it
  - The invalidation caching pattern must be replicated exactly for correctness

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Affine transform composition
    Tool: Bash (sbcl --script)
    Steps:
      1. Create translate(10, 20) and scale(2, 3) transforms
      2. Compose them: (compose translate scale)
      3. Transform point (1, 1) → Assert (12, 23) — translate first, then scale
      4. Get inverse, transform (12, 23) → Assert (1, 1)
    Expected Result: Composition and inversion produce correct results
    Evidence: .sisyphus/evidence/phase2b-affine-compose.txt

  Scenario: Invalidation caching works
    Tool: Bash (sbcl --script)
    Steps:
      1. Create parent and child transforms
      2. Compose them
      3. Read composed matrix (should be cached)
      4. Modify parent
      5. Read composed matrix again (should recompute)
      6. Assert matrices differ
    Expected Result: Cache invalidation propagates correctly
    Evidence: .sisyphus/evidence/phase2b-invalidation.txt
  ```

  **Commit**: YES
  - Message: `feat(primitives): transform system with invalidation caching`
  - Files: `src/primitives/transforms.lisp`, `tests/test-transforms.lisp`
  - Pre-commit: `sbcl --eval '(asdf:test-system :cl-matplotlib-primitives)' --quit`

- [x] 2c. Color System

  **What to do**:
  - Port `colors.py`: `Colormap`, `Normalize`, `LinearSegmentedColormap`, `ListedColormap`, `BoundaryNorm`, `NoNorm`, `LogNorm`, `SymLogNorm`, `PowerNorm`, `TwoSlopeNorm`
  - Port color conversion functions: `to-rgba`, `to-hex`, `to-rgb`, CSS4 named color database, XKCD color names
  - Port ~20 core colormaps: viridis, plasma, inferno, magma, cividis, Greys, Reds, Blues, Greens, hot, cool, coolwarm, RdBu, RdYlGn, Spectral, jet, gray, binary, spring, summer, autumn, winter
  - Port colormap data from `_cm.py` and `_cm_listed.py` (lookup tables)
  - Implement colormap registry with `register-colormap`, `get-colormap`
  - Port `cm.py` ScalarMappable mixin
  - Port tests from `test_colors.py` (~2,251 lines)

  **Must NOT do**:
  - Don't port ALL 150+ colormaps — only the ~20 core ones
  - Don't port bivariate/multivariate colormaps
  - Don't port color cycling (cycler) yet — add in Phase 4

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Data-heavy work (colormap tables) with moderate algorithmic complexity
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with 2a, 2b)
  - **Blocks**: 3a, 3d
  - **Blocked By**: Phase 1

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/colors.py` — Color classes and colormaps
  - `/home/yacin/src/matplotlib/lib/matplotlib/_cm.py` — Colormap data tables
  - `/home/yacin/src/matplotlib/lib/matplotlib/_cm_listed.py` — Listed colormap data
  - `/home/yacin/src/matplotlib/lib/matplotlib/cm.py` — ScalarMappable and colormap registry

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_colors.py` — 2,251 lines of color tests

  **WHY Each Reference Matters**:
  - colors.py defines the normalization and mapping pipeline (data → [0,1] → RGBA)
  - _cm.py contains the actual numerical data for colormaps — must be transcribed accurately

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Color conversion works
    Tool: Bash (sbcl --script)
    Steps:
      1. (to-rgba "red") → Assert #(1.0 0.0 0.0 1.0)
      2. (to-rgba "#FF8000") → Assert #(1.0 0.5 0.0 1.0) approximately
      3. (to-rgba '(0.5 0.5 0.5)) → Assert #(0.5 0.5 0.5 1.0)
      4. (to-hex #(1.0 0.0 0.0 1.0)) → Assert "#ff0000"
    Expected Result: All color formats convert correctly
    Evidence: .sisyphus/evidence/phase2c-color-convert.txt

  Scenario: Colormap mapping works
    Tool: Bash (sbcl --script)
    Steps:
      1. (get-colormap :viridis) → Assert non-nil
      2. (funcall (get-colormap :viridis) 0.0) → Assert dark purple RGBA
      3. (funcall (get-colormap :viridis) 1.0) → Assert bright yellow RGBA
      4. (funcall (get-colormap :viridis) 0.5) → Assert greenish RGBA
    Expected Result: Colormaps produce expected colors
    Evidence: .sisyphus/evidence/phase2c-colormap.txt
  ```

  **Commit**: YES
  - Message: `feat(primitives): color system with 20 core colormaps`
  - Files: `src/primitives/colors.lisp`, `src/primitives/colormaps.lisp`, `tests/test-colors.lisp`
  - Pre-commit: `sbcl --eval '(asdf:test-system :cl-matplotlib-primitives)' --quit`

---

### Phase 3: Rendering (Parallel Wave)

- [x] 3a. Artist Base + Rendering Primitives

  **What to do**:
  - Port `artist.py` Artist CLOS class: slots for transform, alpha, visible, clip-box, clip-path, label, zorder, animated, picker, url, gid, rasterized, sketch-params
  - Implement `initialize-instance :after` chain replacing Python `__init__`
  - Port `draw` generic function protocol: `(defgeneric draw (artist renderer))`
  - Port `lines.py` Line2D class: line data, line style, color, marker, draw method
  - Port `patches.py` core patches: Rectangle, Circle, Ellipse, Polygon, FancyBboxPatch, Wedge, Arc, PathPatch
  - Port `text.py` Text class: text content, position, font properties, rotation, alignment, draw method
  - Port `markers.py` MarkerStyle: marker path generation for standard markers (o, s, ^, v, <, >, d, +, x, *, |, _)
  - Port `image.py` AxesImage: basic image display (imshow data holder)

  **Must NOT do**:
  - Don't port FancyArrowPatch yet (Phase 6)
  - Don't port Collections yet (Phase 5)
  - Don't port PathEffects yet
  - Don't port all 30+ patch types — core ones only

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Large scope, many classes, but straightforward CLOS porting
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with 3b, 3c, 3d)
  - **Blocks**: 4a, 4b
  - **Blocked By**: 2a, 2b, 2c

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/artist.py` — Artist base class (all slots, methods)
  - `/home/yacin/src/matplotlib/lib/matplotlib/lines.py` — Line2D class
  - `/home/yacin/src/matplotlib/lib/matplotlib/patches.py` — Patch classes
  - `/home/yacin/src/matplotlib/lib/matplotlib/text.py` — Text class
  - `/home/yacin/src/matplotlib/lib/matplotlib/markers.py` — MarkerStyle class
  - `/home/yacin/src/matplotlib/lib/matplotlib/image.py` — AxesImage class

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_artist.py` — 628 lines
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_lines.py` — Line2D tests
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_patches.py` — Patch tests
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_text.py` — Text tests
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_marker.py` — Marker tests

  **WHY Each Reference Matters**:
  - Artist base class is the root of the entire rendering hierarchy — must be right
  - Line2D/Patch/Text are the three fundamental drawing primitives used by Axes

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Artist hierarchy creates and draws
    Tool: Bash (sbcl --script)
    Steps:
      1. Create Line2D instance with data
      2. Create Rectangle patch
      3. Create Text instance
      4. Call draw on each with a mock renderer that logs calls
      5. Assert renderer received draw-path, draw-text calls
    Expected Result: Artist draw protocol works through CLOS dispatch
    Evidence: .sisyphus/evidence/phase3a-artist-draw.txt
  ```

  **Commit**: YES
  - Message: `feat(rendering): artist base, Line2D, patches, text, markers`
  - Files: `src/rendering/*.lisp`
  - Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-rendering)' --quit`

- [x] 3b. Vecto PNG Backend (Extended)

  **What to do**:
  - Implement `renderer-vecto` class implementing the `renderer-base` protocol:
    - `draw-path`: Map Path vertices+codes to Vecto move-to/line-to/curve-to/fill/stroke
    - `draw-image`: Blit RGBA pixel array into Vecto canvas buffer
    - `draw-text`: Convert zpb-ttf glyph outlines to paths, render through cl-aa
    - `draw-gouraud-triangles`: Interpolate colors per-scanline, blit to canvas
    - `draw-markers`: Optimized repeated path drawing at multiple positions
  - Implement `graphics-context-vecto` class mapping to Vecto state:
    - Line width, line cap, line join, dash pattern, clip rectangle/path, alpha, RGBA color, hatch
  - Extend Vecto as needed (based on Phase 0 findings):
    - Dash pattern support (if not in Vecto)
    - Clip path support (if not in Vecto)
    - Alpha compositing improvements
  - Implement `canvas-vecto` class:
    - `draw`: Clear canvas, call figure.draw(renderer)
    - `print-png`: Render to Vecto canvas, save via zpng
    - `get-renderer`: Create/cache renderer-vecto
  - Implement `points-to-pixels` DPI conversion

  **Must NOT do**:
  - Don't implement format-specific optimizations yet
  - Don't worry about performance — correctness first
  - Don't implement gradient fills (not needed for core plots)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Requires deep understanding of both Vecto internals and matplotlib's rendering protocol
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with 3a, 3c, 3d)
  - **Blocks**: 4a
  - **Blocked By**: 2a, 2b

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/backends/backend_agg.py:58-361` — RendererAgg implementation pattern
  - `/home/yacin/src/matplotlib/lib/matplotlib/backends/backend_agg.py:363-548` — FigureCanvasAgg implementation
  - `/home/yacin/src/matplotlib/lib/matplotlib/backend_bases.py:134-691` — RendererBase interface

  **External References**:
  - Vecto source: understand canvas buffer format, drawing primitives
  - cl-aa: anti-aliased scanline rasterization API
  - zpng: PNG output API

  **WHY Each Reference Matters**:
  - RendererAgg shows exactly how matplotlib maps draw calls to a rasterizer — our Vecto backend must replicate this mapping
  - FigureCanvasAgg shows the draw→save flow we must implement

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Backend renders path to PNG
    Tool: Bash (sbcl --script)
    Steps:
      1. Create canvas-vecto with 640x480, dpi=100
      2. Get renderer
      3. Draw a red line path from (100,100) to (500,400)
      4. Draw a blue filled rectangle at (200,200,300,300)
      5. Save to /tmp/backend-test.png
      6. file /tmp/backend-test.png → Assert "PNG image data, 640 x 480"
      7. Assert file size > 5KB
    Expected Result: Valid PNG with visible drawn elements
    Evidence: .sisyphus/evidence/phase3b-backend-render.png

  Scenario: Dashed lines render correctly
    Tool: Bash (sbcl --script)
    Steps:
      1. Create path, set dash pattern [5 3] on graphics context
      2. Draw path through renderer
      3. Save PNG, verify visually distinct dash segments
    Expected Result: Dashed line visible in output
    Evidence: .sisyphus/evidence/phase3b-dashed-line.png
  ```

  **Commit**: YES
  - Message: `feat(backends): Vecto-based PNG backend with extended capabilities`
  - Files: `src/backends/backend-vecto.lisp`, `src/backends/vecto-extensions.lisp`
  - Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-backends)' --quit`

- [ ] 3c. cl-pdf PDF Backend

  **What to do**:
  - Implement `renderer-pdf` class implementing `renderer-base` protocol:
    - `draw-path`: Map to cl-pdf `move-to`/`line-to`/`bezier-to`/`fill-path`/`stroke`
    - `draw-text`: Map to cl-pdf `draw-text` with font selection
    - `draw-image`: Map to cl-pdf inline image embedding
    - `draw-gouraud-triangles`: Decompose to gradient patches
  - Implement `graphics-context-pdf` mapping to PDF graphics state:
    - `set-line-width`, `set-rgb-fill`, `set-rgb-stroke`, `set-dash-pattern`, `set-line-cap`, `set-line-join`
    - Clipping via `with-saved-state` + `clip-path`
    - Alpha via PDF ExtGState
  - Implement `canvas-pdf` class:
    - `print-pdf`: Wraps `pdf:with-document`/`pdf:with-page`/`pdf:write-document`
  - Font handling: Map font properties to cl-pdf font selection (AFM + TTF via zpb-ttf)
  - Implement PdfPages equivalent for multi-page PDF

  **Must NOT do**:
  - Don't implement PDF encryption or security features
  - Don't implement PDF bookmarks/annotations
  - Don't optimize font subsetting

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Straightforward mapping between two well-defined APIs
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with 3a, 3b, 3d)
  - **Blocks**: 4a
  - **Blocked By**: 2a, 2b

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/backends/backend_pdf.py` — PDF backend implementation

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_backend_pdf.py` — 698 lines of PDF tests

  **External References**:
  - cl-pdf documentation and examples
  - PDF specification (relevant operator subset)

  **WHY Each Reference Matters**:
  - backend_pdf.py shows how matplotlib maps drawing calls to PDF operators — we map to cl-pdf's API instead
  - test_backend_pdf.py shows what PDF-specific features we must support

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Backend renders path to PDF
    Tool: Bash (sbcl --script)
    Steps:
      1. Create canvas-pdf
      2. Draw a line, rectangle, and text
      3. Save to /tmp/backend-test.pdf
      4. file /tmp/backend-test.pdf → Assert "PDF document"
      5. Assert file size > 1KB
    Expected Result: Valid PDF with drawn elements
    Evidence: .sisyphus/evidence/phase3c-pdf-render.pdf
  ```

  **Commit**: YES
  - Message: `feat(backends): cl-pdf based PDF backend`
  - Files: `src/backends/backend-pdf.lisp`
  - Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-backends)' --quit`

- [x] 3d. Font Management + Text Rendering

  **What to do**:
  - Port `font_manager.py` core: font discovery, property matching (family/weight/style/size), fallback chains
  - Implement font cache (serialize discovered fonts to disk)
  - Integrate zpb-ttf: load TTF files, extract glyph outlines, compute metrics (advance width, ascent, descent, kerning)
  - Ship DejaVu Sans fonts with the library (same as matplotlib) for testing reproducibility
  - Implement `text-to-path` conversion: string → list of glyph paths with proper positioning
  - Port `_afm.py` AFM file parser (for PDF backend Type1 font support)
  - Port text layout: multi-line text, horizontal/vertical alignment, rotation

  **Must NOT do**:
  - Don't implement font hinting (pure CL constraint — zpb-ttf doesn't hint)
  - Don't implement Unicode shaping (ligatures, RTL, combining marks)
  - Don't implement LaTeX/TeX text rendering yet (Phase 6)

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Font management is complex with many edge cases in discovery and fallback
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3 (with 3a, 3b, 3c)
  - **Blocks**: 4c
  - **Blocked By**: 2c

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/font_manager.py` — Font discovery and management (~2K LOC)
  - `/home/yacin/src/matplotlib/lib/matplotlib/_afm.py` — AFM parser
  - `/home/yacin/src/matplotlib/lib/matplotlib/textpath.py` — Text to path conversion

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_font_manager.py` — Font tests
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_ft2font.py` — Font rendering tests
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test__afm.py` — AFM parser tests

  **External References**:
  - zpb-ttf API: `open-font-loader`, `glyph-contours`, `glyph-advance-width`, `kerning-offset`
  - `/home/yacin/src/matplotlib/lib/matplotlib/mpl-data/fonts/ttf/` — DejaVu font files to ship

  **WHY Each Reference Matters**:
  - font_manager.py contains the font matching algorithm — maps (family, weight, style) → font file path
  - textpath.py shows how text strings become drawable paths — critical for both PNG and PDF rendering

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Font loading and text metrics
    Tool: Bash (sbcl --script)
    Steps:
      1. Load DejaVu Sans TTF via zpb-ttf
      2. Get glyph for "A" — Assert advance width > 0
      3. Get text extents for "Hello" at 12pt — Assert width > 0, height > 0
      4. Convert "Hello" to paths — Assert list of path objects returned
    Expected Result: Font system produces valid metrics and glyph paths
    Evidence: .sisyphus/evidence/phase3d-font-metrics.txt
  ```

  **Commit**: YES
  - Message: `feat(rendering): font management, text-to-path, DejaVu fonts`
  - Files: `src/rendering/font-manager.lisp`, `src/rendering/text-path.lisp`, `src/rendering/afm.lisp`, `data/fonts/`
  - Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-rendering)' --quit`

---

### Phase 4: Containers / MVP

- [x] 4a. Figure + FigureCanvas

  **What to do**:
  - Port `figure.py` Figure class: figure size, dpi, facecolor, edgecolor, tight_layout, subplots_adjust
  - Port FigureBase: artist management, axes list, layout engine interface
  - Port SubFigure support
  - Implement `savefig`: format detection, DPI handling, bbox_inches='tight', canvas switching
  - Implement `print-figure` method on FigureCanvasBase: the format-dispatch + render flow
  - Connect Figure → Canvas → Renderer → Backend pipeline end-to-end
  - Port `layout_engine.py`: PlaceHolderLayoutEngine, TightLayoutEngine
  - Port `_tight_layout.py`: Auto-spacing computation

  **Must NOT do**:
  - Don't implement ConstrainedLayout yet (Phase 5)
  - Don't implement interactive figure display
  - Don't implement figure events/callbacks

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: Critical integration point — the full rendering pipeline must work end-to-end
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with 4b, 4c, 4d)
  - **Blocks**: 5a-e, 7a
  - **Blocked By**: 3a, 3b, 3c

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/figure.py` — Figure class
  - `/home/yacin/src/matplotlib/lib/matplotlib/layout_engine.py` — Layout engines
  - `/home/yacin/src/matplotlib/lib/matplotlib/_tight_layout.py` — Tight layout algorithm

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_figure.py` — 1,882 lines

  **WHY Each Reference Matters**:
  - figure.py is the top-level container — savefig flows through here to canvas to backend
  - The draw pipeline (figure.draw → axes.draw → artist.draw → renderer) must be wired correctly

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Figure saves to PNG
    Tool: Bash (sbcl --script)
    Steps:
      1. (let ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))) (savefig fig "/tmp/empty-fig.png"))
      2. file /tmp/empty-fig.png → Assert "PNG image data, 640 x 480"
    Expected Result: Empty figure saves as correctly-sized PNG
    Evidence: .sisyphus/evidence/phase4a-empty-figure.png

  Scenario: Figure saves to PDF
    Tool: Bash (sbcl --script)
    Steps:
      1. (let ((fig (make-figure))) (savefig fig "/tmp/empty-fig.pdf"))
      2. file /tmp/empty-fig.pdf → Assert "PDF document"
    Expected Result: Empty figure saves as valid PDF
    Evidence: .sisyphus/evidence/phase4a-empty-figure.pdf
  ```

  **Commit**: YES
  - Message: `feat(containers): figure, canvas, savefig pipeline`
  - Files: `src/containers/figure.lisp`, `src/containers/layout-engine.lisp`
  - Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-containers)' --quit`

- [x] 4b. Axes (Base + Core Plot Methods)

  **What to do**:
  - Port `axes/_base.py` _AxesBase: coordinate setup, artist management, data limits, autoscaling, view limits
  - Port `axes/_axes.py` core plotting methods: `plot`, `scatter`, `bar`, `fill`, `fill_between`
  - Implement the Axes → data transform → display transform pipeline
  - Port rectilinear projection (default Axes)
  - Implement artist z-ordering for draw
  - Port `_secondary_axes.py` for twinx/twiny support
  - Implement data limit tracking and autoscaling

  **Must NOT do**:
  - Don't port polar or geographic projections yet
  - Don't port all 50+ Axes methods — core 5-8 first
  - Don't port 3D axes

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Axes is the most complex class — coordinate transforms + data management + artist orchestration
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with 4a, 4c, 4d)
  - **Blocks**: 5b, 6b, 7a
  - **Blocked By**: 3a, 4a

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/axes/_base.py` — Base Axes class
  - `/home/yacin/src/matplotlib/lib/matplotlib/axes/_axes.py` — Plot methods (plot, scatter, bar, etc.)

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_axes.py` — 10,161 lines (THE largest test file)

  **WHY Each Reference Matters**:
  - _base.py defines coordinate system setup — transData, transAxes mapping
  - _axes.py contains the actual plot() function — this is the MVP target

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: MVP — plot() produces PNG
    Tool: Bash (sbcl --script)
    Steps:
      1. Create figure and axes
      2. (plot ax '(1 2 3 4) '(1 4 9 16))
      3. (savefig fig "/tmp/mvp-plot.png")
      4. file /tmp/mvp-plot.png → Assert "PNG image data"
      5. Assert file size > 10KB (non-trivial plot)
    Expected Result: First working plot! Line visible on axes with correct data
    Evidence: .sisyphus/evidence/phase4b-mvp-plot.png

  Scenario: scatter() produces PNG
    Tool: Bash (sbcl --script)
    Steps:
      1. (scatter ax '(1 2 3 4 5) '(2 4 1 5 3))
      2. (savefig fig "/tmp/scatter.png")
      3. Assert valid PNG, file size > 5KB
    Expected Result: Scatter plot with visible dots
    Evidence: .sisyphus/evidence/phase4b-scatter.png
  ```

  **Commit**: YES
  - Message: `feat(containers): axes with plot, scatter, bar — MVP complete`
  - Files: `src/containers/axes-base.lisp`, `src/containers/axes.lisp`
  - Pre-commit: `sbcl --eval '(savefig (let ... (plot ...)) "/tmp/test.png")' --quit`

- [x] 4c. Axis + Ticker + Spines

  **What to do**:
  - Port `axis.py` XAxis/YAxis: tick generation, label positioning, grid lines
  - Port `ticker.py` core locators: AutoLocator, MaxNLocator, LinearLocator, FixedLocator, NullLocator, MultipleLocator, LogLocator
  - Port `ticker.py` core formatters: ScalarFormatter, StrMethodFormatter, FixedFormatter, NullFormatter, LogFormatter, PercentFormatter
  - Port `spines.py` Spine class: border rendering for axes
  - Port tick mark rendering: major/minor ticks, tick direction, tick size

  **Must NOT do**:
  - Don't port DateLocator/DateFormatter (Phase 5 if needed)
  - Don't port all 15+ locator types — core 7 only
  - Don't port all formatter types — core 6 only

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Moderate complexity, mostly straightforward porting with tick algorithm logic
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with 4a, 4b, 4d)
  - **Blocks**: 5a, 7a
  - **Blocked By**: 3d, 4a

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/axis.py` — Axis classes
  - `/home/yacin/src/matplotlib/lib/matplotlib/ticker.py` — Locators and formatters
  - `/home/yacin/src/matplotlib/lib/matplotlib/spines.py` — Spine rendering

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_ticker.py` — 2,020 lines
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_axis.py` — Axis tests
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_spines.py` — Spine tests

  **WHY Each Reference Matters**:
  - ticker.py contains the algorithms that decide WHERE to place tick marks — critical for readable plots
  - axis.py orchestrates tick generation, label placement, and grid line rendering

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Plot has ticks and labels
    Tool: Bash (sbcl --script)
    Steps:
      1. Create figure+axes, plot data, savefig
      2. Load PNG, verify tick marks are visible (non-uniform pixels along axes)
      3. Verify axis labels are rendered (text regions present)
    Expected Result: Plot has visible tick marks and labels
    Evidence: .sisyphus/evidence/phase4c-ticks-labels.png
  ```

  **Commit**: YES
  - Message: `feat(containers): axis, ticker, spines — complete axes frame`
  - Files: `src/containers/axis.lisp`, `src/containers/ticker.lisp`, `src/containers/spines.lisp`
  - Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-containers)' --quit`

- [x] 4d. Legend + Colorbar

  **What to do**:
  - Port `legend.py` Legend class: legend positioning (best, upper right, etc.), legend entries, legend frame
  - Port `legend_handler.py` core handlers: HandlerLine2D, HandlerPatch, HandlerLineCollection, HandlerPathCollection
  - Port `colorbar.py` Colorbar class: colorbar rendering, tick placement, label
  - Implement legend auto-placement algorithm ("best" position)

  **Must NOT do**:
  - Don't port all legend handler types — core 4 only
  - Don't port draggable legend
  - Don't port inset colorbars

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: Moderate complexity, well-defined scope
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 4 (with 4a, 4b, 4c)
  - **Blocks**: 7a
  - **Blocked By**: 4b

  **References**:

  **Pattern References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/legend.py` — Legend class
  - `/home/yacin/src/matplotlib/lib/matplotlib/legend_handler.py` — Legend handlers
  - `/home/yacin/src/matplotlib/lib/matplotlib/colorbar.py` — Colorbar class

  **Test References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_legend.py` — 1,752 lines
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_colorbar.py` — Colorbar tests

  **WHY Each Reference Matters**:
  - Legend is one of the most user-visible features — incorrect positioning or rendering is immediately obvious
  - Colorbar integrates deeply with the color normalization system

  **Acceptance Criteria**:

  **Agent-Executed QA Scenarios:**

  ```
  Scenario: Plot with legend
    Tool: Bash (sbcl --script)
    Steps:
      1. Plot two lines with labels
      2. Call (legend ax)
      3. savefig → verify legend box visible in PNG
    Expected Result: Legend with correct entries rendered
    Evidence: .sisyphus/evidence/phase4d-legend.png
  ```

  **Commit**: YES
  - Message: `feat(containers): legend and colorbar`
  - Files: `src/containers/legend.lisp`, `src/containers/colorbar.lisp`
  - Pre-commit: `sbcl --eval '(asdf:load-system :cl-matplotlib-containers)' --quit`

---

### Phase 5: Extended Features (Parallel with Phase 6)

- [x] 5a. Scale System (log, symlog, logit)

  **What to do**:
  - Port `scale.py`: LinearScale, LogScale, SymmetricalLogScale, LogitScale, FuncScale
  - Port scale transforms: LogTransform, InvertedLogTransform, SymmetricalLogTransform
  - Integrate with Axis for `set-xscale`/`set-yscale`
  - Handle NaN/negative value masking for log scales

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Skills**: []
  **Parallelization**: Wave 5 (with 5b-e, 6a-c) | Blocked By: 4c

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/scale.py` — Scale classes
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_scale.py` — Scale tests

  **Acceptance Criteria**: Log-scaled plot produces correctly spaced ticks.
  **Commit**: YES — `feat(containers): log/symlog/logit scale support`

- [x] 5b. GridSpec + Subplot Layouts

  **What to do**:
  - Port `gridspec.py`: GridSpec, SubplotSpec, GridSpecFromSubplotSpec
  - Port `subplots`: multi-axes figure creation, shared axes
  - Implement `subplot_mosaic` for named layouts

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  **Parallelization**: Wave 5 | Blocked By: 4a, 4b

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/gridspec.py` — GridSpec
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_gridspec.py` — GridSpec tests
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_subplots.py` — Subplot tests

  **Acceptance Criteria**: 2×2 subplot grid renders correctly.
  **Commit**: YES — `feat(containers): gridspec and subplot layouts`

- [x] 5c. Collections + Advanced Artists

  **What to do**:
  - Port `collections.py`: LineCollection, PathCollection, PatchCollection, PolyCollection, QuadMesh
  - Port `hatch.py`: hatch pattern generation
  - These are needed for scatter(), bar(), contourf(), and other batch-drawing operations

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  **Parallelization**: Wave 5 | Blocked By: 4b

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/collections.py` — Collection classes
  - `/home/yacin/src/matplotlib/lib/matplotlib/hatch.py` — Hatch patterns
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_collections.py` — 1,540 lines

  **Acceptance Criteria**: Scatter with 1000 points renders using PathCollection.
  **Commit**: YES — `feat(rendering): collections, hatch patterns`

- [x] 5d. Contour (Marching Squares in Pure CL)

  **What to do**:
  - Port `contour.py`: ContourSet, QuadContourSet
  - Implement marching squares algorithm in pure CL (replacing `_contour.cpp`)
  - Implement contour labeling (inline labels on contour lines)
  - Support `contour()` (lines) and `contourf()` (filled)

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Marching squares is a well-defined but non-trivial algorithm
  - **Skills**: []
  **Parallelization**: Wave 5 | Blocked By: 4b

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/contour.py` — Contour classes
  - `/home/yacin/src/matplotlib/src/tri/_tri.cpp` — C++ triangulation (for reference only)
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_contour.py` — 880 lines

  **Acceptance Criteria**: `contourf` of a 2D Gaussian produces filled contours.
  **Commit**: YES — `feat(plotting): contour and contourf with pure CL marching squares`

- [x] 5e. Image Display (imshow + Interpolation)

  **What to do**:
  - Implement `imshow()` on Axes: map 2D array → colormap → RGBA image → render
  - Implement interpolation: nearest-neighbor, bilinear (pure CL, ~100 LOC each)
  - Port `image.py` AxesImage rendering: extent, origin, aspect handling

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  **Parallelization**: Wave 5 | Blocked By: 4b

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/image.py` — Image rendering
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_image.py` — 1,873 lines

  **Acceptance Criteria**: `imshow` of a 100×100 random array produces a colorful image.
  **Commit**: YES — `feat(plotting): imshow with nearest/bilinear interpolation`

---

### Phase 6: Mathtext + Specialized (Parallel with Phase 5)

- [ ] 6a. Mathtext Parser + Layout Engine

  **What to do**:
  - Port `_mathtext.py` recursive-descent parser (~3K LOC): parses `$\int_0^\infty e^{-x} dx$` syntax
  - Port box-layout engine: hboxes, vboxes, kerns, glue (like TeX's box model)
  - Port `_mathtext_data.py`: glyph metrics tables for math symbols
  - Port `mathtext.py` public interface
  - Use STIX fonts shipped with matplotlib for math rendering

  **Must NOT do**:
  - Don't port LaTeX/TeX integration (texmanager) — pure mathtext only
  - Don't port all TeX commands — core math subset only

  **Recommended Agent Profile**:
  - **Category**: `ultrabrain`
    - Reason: Recursive-descent parser + TeX-style layout is genuinely hard
  - **Skills**: []
  **Parallelization**: Wave 6 (parallel with Wave 5) | Blocked By: 4a, 4b

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/_mathtext.py` — Parser + layout engine
  - `/home/yacin/src/matplotlib/lib/matplotlib/_mathtext_data.py` — Glyph metrics
  - `/home/yacin/src/matplotlib/lib/matplotlib/mathtext.py` — Public interface
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_mathtext.py` — 600 lines

  **Acceptance Criteria**: `$x^2 + y^2 = r^2$` renders correctly in a plot title.
  **Commit**: YES — `feat(rendering): mathtext parser and layout engine`

- [x] 6b. Additional Plot Types

  **What to do**:
  - Port remaining core Axes methods: `hist`, `pie`, `errorbar`, `boxplot`, `violinplot`, `stem`, `step`, `stackplot`, `fill_between`, `barh`
  - Port `bezier.py` Bezier curve utilities (needed by some plot types)
  - Port `quiver.py` if in scope, `streamplot.py` if in scope

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  **Parallelization**: Wave 6 | Blocked By: 4b

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/axes/_axes.py` — All plot methods (hist, pie, errorbar, etc.)

  **Acceptance Criteria**: Each plot type produces visually correct output.
  **Commit**: YES — `feat(plotting): hist, pie, errorbar, boxplot, stem, step, stackplot`

- [x] 6c. Annotation System

  **What to do**:
  - Port annotation from `text.py`: Annotation class, arrow properties
  - Port `patches.py` FancyArrowPatch, ConnectionStyle, BoxStyle
  - Port `offsetbox.py` core: AnchoredText, AnnotationBbox

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  **Parallelization**: Wave 6 | Blocked By: 4b

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/text.py` — Annotation class
  - `/home/yacin/src/matplotlib/lib/matplotlib/patches.py` — FancyArrowPatch
  - `/home/yacin/src/matplotlib/lib/matplotlib/offsetbox.py` — Anchored text

  **Acceptance Criteria**: Annotated plot with arrow pointing to data point renders.
  **Commit**: YES — `feat(rendering): annotation system with arrows and anchored text`

---

### Phase 7: Interface

- [x] 7a. pyplot Procedural Interface

  **What to do**:
  - Port `pyplot.py` as `cl-matplotlib.pyplot` package
  - Implement figure tracking: current figure, figure list, `gcf`, `gca`
  - Implement convenience wrappers: `plot`, `scatter`, `bar`, `hist`, `imshow`, `contour`, `show`, `savefig`, `subplots`, `figure`, `close`, `clf`, `cla`
  - Implement `set-xlabel`, `set-ylabel`, `set-title`, `set-xlim`, `set-ylim`, `grid`, `legend`, `colorbar`
  - Idiomatic CL: these become exported functions from `cl-matplotlib.pyplot` package

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  **Parallelization**: Sequential | Blocked By: 5, 6

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/pyplot.py` — Complete pyplot interface

  **Acceptance Criteria**: 
  ```lisp
  (cl-matplotlib.pyplot:figure)
  (cl-matplotlib.pyplot:plot '(1 2 3) '(1 4 9))
  (cl-matplotlib.pyplot:xlabel "X")
  (cl-matplotlib.pyplot:ylabel "Y")
  (cl-matplotlib.pyplot:title "Test")
  (cl-matplotlib.pyplot:savefig "/tmp/pyplot-test.png")
  ```
  Produces a valid plot.
  **Commit**: YES — `feat(pyplot): procedural interface`

- [ ] 7b. Full rcParams System

  **What to do**:
  - Complete the rcParams system with all ~150-200 PNG/PDF-relevant parameters
  - Port default matplotlibrc file
  - Implement `rc-context` (temporary override context)
  - Implement `rc-defaults` (reset to defaults)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-low`
  - **Skills**: []
  **Parallelization**: Wave 7 (with 7a, 7c) | Blocked By: Phase 1 (extends)

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/rcsetup.py` — Complete param definitions
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_rcparams.py` — 693 lines

  **Acceptance Criteria**: All ported params load from rcfile and validate correctly.
  **Commit**: YES — `feat(config): complete rcParams for PNG/PDF`

- [ ] 7c. Style Sheets

  **What to do**:
  - Port `style/core.py`: style sheet loading, `use-style`, style context manager
  - Port core style sheets: `default`, `classic`, `ggplot`, `seaborn`, `bmh`, `dark_background`, `fivethirtyeight`, `grayscale`
  - Implement `available-styles` listing

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  **Parallelization**: Wave 7 (with 7a, 7b) | Blocked By: 7b

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/style/core.py` — Style loading
  - `/home/yacin/src/matplotlib/lib/matplotlib/mpl-data/stylelib/` — Style sheet files
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/test_style.py` — Style tests

  **Acceptance Criteria**: `(use-style :ggplot)` changes plot appearance.
  **Commit**: YES — `feat(config): style sheets`

---

### Phase 8: Tests + Polish

- [ ] 8a. Port All Test Files (Batch)

  **What to do**:
  - Port all 94 test files from pytest to FiveAM
  - Map `@image_comparison` decorator to `def-image-test` FiveAM macro
  - Map `@check_figures_equal` to `def-figure-equality-test` macro
  - Map `@pytest.mark.parametrize` to FiveAM test generators
  - Map `@pytest.mark.backend('pdf')` to FiveAM test suites per backend
  - Port `matplotlib.testing` module as `cl-matplotlib.testing`:
    - `compare-images` function (RMS + SSIM comparison)
    - Image conversion (PDF→PNG via Ghostscript for comparison)
    - Baseline directory management
  - Map test helpers: fixtures, mock events, subprocess tests

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  **Parallelization**: Can parallelize by test file batches | Blocked By: Phase 7

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/testing/` — All testing infrastructure
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/` — All 94 test files
  - `/home/yacin/src/matplotlib/lib/matplotlib/testing/compare.py` — Image comparison
  - `/home/yacin/src/matplotlib/lib/matplotlib/testing/decorators.py` — Test decorators

  **Acceptance Criteria**: `(asdf:test-system :cl-matplotlib-tests)` runs, reports pass/fail.
  **Commit**: YES — `feat(tests): port all test files to FiveAM`

- [ ] 8b. Generate CL-Native Baseline Images

  **What to do**:
  - Run all image comparison tests in baseline generation mode
  - Generate ~2,225 PNG baseline images
  - Organize in `tests/baseline_images/` mirroring matplotlib's structure
  - Store in git LFS or as regular files (assess size)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  **Parallelization**: After 8a | Blocked By: 8a

  **References**:
  - `/home/yacin/src/matplotlib/lib/matplotlib/tests/baseline_images/` — Reference for directory structure

  **Acceptance Criteria**: All baseline images generated, ≥ 95% of tests pass with baselines.
  **Commit**: YES — `feat(tests): generate CL-native baseline images`

- [ ] 8c. Cross-Validation Against Python References

  **What to do**:
  - Generate Python reference images for all image comparison tests
  - Compute SSIM between Python and CL outputs for each test
  - Produce cross-validation report with per-test SSIM scores
  - Flag any test with SSIM < 0.85 for investigation
  - Document known differences (font hinting, anti-aliasing, color precision)

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: []
  **Parallelization**: After 8b | Blocked By: 8b

  **Acceptance Criteria**: Cross-validation report shows ≥ 85% of tests with SSIM ≥ 0.85.
  **Commit**: YES — `docs: cross-validation report against Python matplotlib`

- [ ] 8d. CI Setup (SBCL + CCL)

  **What to do**:
  - Set up GitHub Actions CI with SBCL and CCL
  - Run full test suite on both implementations
  - Verify system loads cleanly on both
  - Add badge for test status

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  **Parallelization**: After 8a | Blocked By: 8a

  **Acceptance Criteria**: CI green on both SBCL and CCL.
  **Commit**: YES — `ci: GitHub Actions for SBCL and CCL`

---

## Commit Strategy

| After Task | Message | Key Files | Verification |
|------------|---------|-----------|--------------|
| 0 | `feat(core): phase 0 — rendering PoC and feasibility validation` | poc.lisp, *.asd | Renders PNG |
| 1 | `feat(foundation): rc-params, cbook utilities, API helpers` | src/foundation/*.lisp | System loads |
| 2a | `feat(primitives): path system with CL-native geometry algorithms` | src/primitives/path*.lisp | Path tests pass |
| 2b | `feat(primitives): transform system with invalidation caching` | src/primitives/transforms.lisp | Transform tests pass |
| 2c | `feat(primitives): color system with 20 core colormaps` | src/primitives/colors*.lisp | Color tests pass |
| 3a | `feat(rendering): artist base, Line2D, patches, text, markers` | src/rendering/*.lisp | Artist tests pass |
| 3b | `feat(backends): Vecto-based PNG backend with extended capabilities` | src/backends/backend-vecto.lisp | Renders PNG |
| 3c | `feat(backends): cl-pdf based PDF backend` | src/backends/backend-pdf.lisp | Renders PDF |
| 3d | `feat(rendering): font management, text-to-path, DejaVu fonts` | src/rendering/font*.lisp | Font tests pass |
| 4a | `feat(containers): figure, canvas, savefig pipeline` | src/containers/figure.lisp | Empty fig → PNG |
| 4b | `feat(containers): axes with plot, scatter, bar — MVP complete` | src/containers/axes*.lisp | **plot() → PNG** |
| 4c | `feat(containers): axis, ticker, spines — complete axes frame` | src/containers/axis*.lisp | Ticks render |
| 4d | `feat(containers): legend and colorbar` | src/containers/legend.lisp | Legend renders |
| 5a-e | Various `feat(...)` | Various | Each feature renders |
| 6a-c | Various `feat(...)` | Various | Each feature renders |
| 7a-c | Various `feat(...)` | Various | pyplot API works |
| 8a-d | Various `feat(tests)/ci:` | tests/*.lisp | ≥ 95% tests pass |

---

## Success Criteria

### Verification Commands
```bash
# System loads on SBCL
sbcl --eval '(ql:quickload :cl-matplotlib)' --eval '(format t "OK~%")' --quit
# Expected: "OK" with no errors

# System loads on CCL
ccl --eval '(ql:quickload :cl-matplotlib)' --eval '(format t "OK~%")' --eval '(quit)'
# Expected: "OK" with no errors

# MVP test: plot() → PNG
sbcl --eval '(ql:quickload :cl-matplotlib)' \
     --eval '(cl-matplotlib.pyplot:figure)' \
     --eval '(cl-matplotlib.pyplot:plot (list 1 2 3 4) (list 1 4 9 16))' \
     --eval '(cl-matplotlib.pyplot:savefig "/tmp/test.png")' \
     --quit
file /tmp/test.png
# Expected: "PNG image data, 640 x 480"

# Test suite
sbcl --eval '(ql:quickload :cl-matplotlib-tests)' \
     --eval '(asdf:test-system :cl-matplotlib-tests)' \
     --quit
# Expected: ≥ 95% pass rate

# PDF output
sbcl --eval '...(savefig "/tmp/test.pdf")...' --quit
file /tmp/test.pdf
# Expected: "PDF document"
```

### Final Checklist
- [ ] All "Must Have" plot types produce correct output (plot, scatter, bar, hist, pie, fill, errorbar, boxplot, stem, step, stackplot, imshow, contour)
- [ ] All "Must NOT Have" items confirmed absent (no CFFI, no GUI, no animation, etc.)
- [ ] ≥ 95% of ported FiveAM tests pass on SBCL
- [ ] ≥ 90% of ported FiveAM tests pass on CCL
- [ ] Cross-validation SSIM ≥ 0.85 for ≥ 85% of image comparison tests
- [ ] CI green on SBCL + CCL
- [ ] Zero CFFI dependencies in entire dependency tree
