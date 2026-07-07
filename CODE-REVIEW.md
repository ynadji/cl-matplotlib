# Full-repo review — 2026-07-06

Six parallel review passes (foundation+primitives, rendering, backends, containers,
pyplot/plotting/algorithms, cross-cutting infra). Every finding below was verified by
re-reading surrounding code; the top backend finding was verified empirically by rendering.
Grouped by priority, not by subsystem. `[bug]` `[perf]` `[design]` `[hygiene]`.

`[x]` = fixed in the 2026-07-06 session (all 7 system test suites pass; full SSIM
comparison vs Python references re-validated — several examples improved, none regressed).
Additional fix not in the original list: `ros run --eval '(error ...)' --quit` exits 0,
so CI steps could never fail regardless of the runners — `tools/ci-run.sh` now traps
errors in Lisp and calls `uiop:quit 1`. Also: `trans-axes`/`trans-data` are now stable
`transform-wrapper`s updated in place, eliminating the stale-transform-reference class of
bugs (the draw-time transform propagation loops are now belt-and-suspenders only).
Note: `cl-matplotlib-testing/ported` is NOT in CI — its committed baselines predate
203 commits of rendering work and need regeneration (delete stale
`tests/baseline_images/*` and re-run with `:save-baseline t` once rendering settles).

P1 follow-up session (same day): all remaining P1 items fixed. Notable extras
discovered along the way: (1) the streamplot *reference scripts* were a Python
transcription of the CL port's buggy algorithm — rewritten to use real
`plt.streamplot` and references regenerated; the two streamplot examples are now
allowlisted (faithful algorithm, chaotic trajectory selection prevents pixel
alignment). (2) fancy-arrow-patch `mutation-scale` used a nonstandard 10px base —
now matplotlib's factors (head 0.4·scale points) with points→px conversion, plus
a filled-head `:-|>` style (matplotlib's streamplot default); annotate now
defaults mutation-scale to the text fontsize like matplotlib. (3) `get-text-extents`
also measured glyph ink after the pen advance (widths inflated by one glyph) and
ignored negative left bearings — both fixed alongside the kerning bug.

## P0 — meta-issue: fix before anything else

- [x] **CI cannot fail for most systems** [bug] — 26 of 29 `run-*-tests` functions return the
  FiveAM status boolean instead of signaling, and every `.asd` `:perform (test-op ...)` discards
  it (`cl-matplotlib-primitives.asd` calls `fiveam:run!` directly, which only prints). Only
  pyplot, testing, and annotation suites signal on failure (e.g. `tests/test-pyplot.lisp:1032`).
  Failing tests in foundation/primitives/rendering/backends/containers pass CI green.
  Fix pattern: `(unless (fiveam:results-status results) (error ...))` in every runner.
- [x] **CI never runs `cl-matplotlib-testing` or `cl-matplotlib-testing/ported`** [hygiene] —
  the 5 ported image-comparison suites are referenced by no CI step or Makefile target.

## P1 — high-severity bugs

### Backends (scanline caching — recent work)
- [x] **PNG fast path vertically mirrors asymmetric markers** [bug, verified empirically] —
  `backend-vecto.lisp:548-549,685-696`. Commit 9876fca fixed marker *position* flip
  (`dy = img-height - ty`) but removed the sy negation that kept marker *shape* upright:
  scanlines are rasterized Y-up but replayed Y-down. `:^` renders apex-down (measured: 62px-wide
  top row → 2px bottom). `:v`/`:^` swapped; PNG disagrees with SVG/PDF (which use the correct
  per-item fallback). Fix: negate sy when building scanlines.
- [x] **Fast path drops rotation/shear from marker transform** [bug, latent] —
  `backend-vecto.lisp:548-549` uses only matrix elements 0 and 3. Gate the fast path on
  `(and (zerop (aref mtx 1)) (zerop (aref mtx 2)))` and fall back otherwise.
- [x] **Multi-subpath marker paths lose all but the last subpath in fast path** [bug] —
  `backend-vecto.lisp:557-561`. `net.tuxee.paths:path-reset` clears the whole path on each
  MOVETO. Accumulate a list of paths instead.

### Containers
- [x] **Legend drawn twice per frame + stale legends accumulate** [bug] —
  `axes-base.lisp:515-517` + `legend.lisp:672-674`. Legend is in `axes-base-artists` AND drawn
  explicitly from the slot; framealpha composites darker than matplotlib, `:best` placement scan
  runs twice. Re-calling `axes-legend` leaves the old legend in the artists list.
- [x] **Text/annotate artists registered twice → drawn twice** [bug] — `axes.lisp:1312-1313`
  (text), `:1369-1371` (annotate). Pushed into both `axes-base-texts` and `axes-base-artists`;
  `axes-get-all-artists` appends both. `pie` shows the intended single-registration convention.
- [x] **`ncol > 1` legends compute multi-column bbox but draw one column** [bug] —
  `legend.lisp:488-511`. Draw loop never advances a column; entries spill outside the frame.
- [x] **`add-subplot` spacing math wrong** [bug] — `axes.lisp:1640-1651`. Treats wspace/hspace
  as absolute figure fractions; matplotlib (and this repo's own `gridspec-get-grid-positions`)
  use fraction-of-average-axes-size. `subplot()` and `subplots()` figures disagree with each
  other and with Python references.
- [x] **`axes-set-xlim`/`ylim` silently clobbered by next plot call** [bug] —
  `axes-base.lisp:272-343`. `axes-autoscale-view` uses the autoscale flags only to gate margins,
  then unconditionally overwrites view-lim from datalim. `(ylim 0 5)` then `(plot ...)` discards
  the user's limits.

### Rendering
- [x] **Kerning never applied in `get-text-extents`** [bug] — `font-manager.lisp:475-498`.
  A trailing `(setf prev-glyph nil)` runs every iteration, clobbering the tracking; measured
  widths disagree with rendered glyphs (`text-to-path` does kern). Feeds legend sizing,
  multiline alignment, annotation bboxes.
- [x] **mathtext sub+superscript layout reads the kern node instead of the sup box** [bug] —
  `mathtext-parser.lisp:371-380`. `(car (cdr result-elements))` is the mt-kern; sup-width is
  always 0 so `x^2_i` places the subscript after the superscript. Should be `(car result-elements)`.
- [x] **`anchored-text` draws in wrong units entirely** [bug, latent] —
  `fancy-arrow.lisp:626-667`. Axes-fraction coords passed as pixels; point pads subtracted from
  fractions. Any use renders in the bottom-left corner.

### Primitives / foundation
- [x] **`%perpendicular-distance` sign error** [bug] — `path-algorithms.lisp:278`. Constant term
  sign-flipped (`− x2·y1 + x1·y2` instead of `+ x2·y1 − x1·y2`); only correct for lines through
  the origin. Breaks `douglas-peucker` point selection.
- [x] **`transformed-bbox` never calls `set-children` → cache never invalidates** [bug] —
  `transforms.lisp:729-731`. After first recompute, changes to the source transform are never
  seen. `bbox-transform` (`:685-687`) has the same problem (plain structs, no invalidation channel).
- [x] **`polar-transform` crashes on codeless paths** [bug] — `polar-transforms.lisp:30,36`.
  `(aref codes i)` with codes = NIL — the common case for plain line data. Live in the polar pipeline.
- [x] **Missing `transform-path`/`get-matrix` methods on non-affine transforms** [bug] —
  `scale-transforms.lisp` (inverted-log, symlog, inverted-symlog, logit, logistic, func-transform),
  `transforms.lisp:518-522,601-627` (blended-generic). `no-applicable-method` at runtime when
  composed. A default `transform-path` looping `transform-point` closes most of the hole.
- [x] **Infinite loop on malformed/truncated curve data** [bug] — `path.lisp:633-661` (also
  `:352-393`, `:460-490`). CURVE3/CURVE4 clauses only `incf i` inside the guard; if the guard
  fails, `i` never advances and `loop while` spins forever.

### Algorithms / plotting
- [x] **streamplot mask indexed in wrong coordinate system** [bug] —
  `streamplot.lisp:17-20,156-157,171,237-238`. Mask is `(density*30)²` but lookups use data-grid
  indices; matplotlib's grid→mask mapping was dropped. Density control is broken for any grid
  larger than 30×30.
- [x] **streamplot backward integration dead + wrong ordering if revived** [bug] —
  `streamplot.lisp:239-242,151-178`. Forward pass occupies seed cell so backward pass exits
  immediately; and `(reverse bwd)` would produce a zigzag anyway. Correct: `(append bwd (rest fwd))`,
  no reverse, integrate both directions before committing to the mask.
- [x] **streamplot RK12 never adapts** [bug] — `streamplot.lisp:162-169`. On `err > tolerance`
  the branch is `nil` and the identical step is retried until the 1000-iteration budget burns.
  Halve ds on failure. Also `max-length` accumulates time, not arc length (`:162,173`).
- [x] **`hist :density t :cumulative t` computes garbage** [bug] — `hist.lisp:102-108`.
  Cumulates raw counts then normalizes by the sum of cumulative counts. matplotlib: density
  first, then cumsum(density·widths) ending at 1.0.

## P2 — medium bugs & cross-backend inconsistencies

### Backend consistency (same gc, three different results)
- [x] Points→pixels linewidth conversion only in Vecto — `backend-vecto.lisp:95-97` vs
  `backend-svg.lisp:242-244` (raw), `backend-pdf.lisp:51-52,797` (raw + CTM). PNG strokes ~39%
  thicker than SVG/PDF at dpi 100. Convert in one place.
- [x] Dash patterns computed 3 different ways (px vs pt scaling, different clamping) —
  `backend-vecto.lisp:123-151`, `backend-svg.lisp:269-290`, `backend-pdf.lisp:77-93`. Explicit
  `gc-dashes` in Vecto not converted from points.
- [x] PDF `draw-path-collection` never applies alpha to strokes — `backend-pdf.lisp:650-678`.
- [ ] Hatch silently skipped when transform is nil (Vecto+PDF) — `backend-vecto.lisp:381-389`,
  `backend-pdf.lisp:272-280`. Vertex accumulation wrapped in `(when transform ...)`.
- [ ] `%path-axis-aligned-p` misclassifies densely-sampled curves (every segment dx<0.5 → whole
  curve snapped to half-pixel grid, visible stair-stepping) AND double-transforms every vertex —
  `backend-vecto.lisp:170-219`, duplicated in svg/pdf. Snapping also bakes raster coords into
  vector output.
- [ ] Uniform-collection fast path drops linestyle/capstyle/joinstyle/clip — protocol
  `artist.lisp:220-232`, gate `collections.lisp:171-191`. `:linestyles '(:dashed)` renders solid.
  Gate should require solid/defaults or the protocol should carry the state.
- [ ] SVG `draw-image` temp file keyed on `get-universal-time` (1s resolution) — races;
  `backend-svg.lisp:546`. PDF already fixed with `(random 100000)`. Both should use in-memory PNG.

### Silently-ignored user options
- [ ] `boxplot :labels` — `stats.lisp:74` `(declare (ignore labels))`.
- [ ] `errorbar :fmt` — `axes.lisp:826,849`; no format-string parser ("r--o") exists anywhere;
  `plot(x, y, fmt)` signature missing; `stem` fmt args treated as bare colors.
- [ ] pyplot `title :loc :color` ignored; repeated calls stack overlapping titles; layout math
  inlined in pyplot instead of an axes-level `set-title` — `pyplot.lisp:544-580`.
- [x] `line-2d :linestyle :none` still strokes the line — `lines.lisp:191` + vecto dash
  `otherwise → solid`. Marker-only plots draw a connecting polyline.
- [x] `max-n-locator :integer t` accepted, never consulted — `ticker.lisp:207-211`.
- [ ] image `:bicubic` silently degrades to nearest — `image.lisp:410-412`.
- [ ] Artist `clip-box`/`clip-path`/`clip-on` and `collection-hatch` stored, never consumed —
  `artist.lisp:54-66`, `collections.lisp:56-59`.
- [ ] Text `fontfamily`/`fontweight`/`fontstyle` never reach the renderer; fontsize smuggled via
  `gc-linewidth` (all 3 backends decode `gc-linewidth` as font size) — `text.lisp:78-96`,
  `backend-vecto.lisp:828`, `backend-svg.lisp:459`, `backend-pdf.lisp:498`. `:fontweight :bold`
  is a no-op; the entire find-font machinery is bypassed for normal text.

### Containers / ticks / scales
- [x] `fixed-formatter` labels misalign when fixed ticks are clipped by view range —
  `axis.lisp:299-313` + `ticker.lisp:437-442` (format by index among ALL locator ticks).
- [x] `log-locator` yields zero ticks for sub-decade ranges (view (2,5) → no ticks/labels) —
  `ticker.lisp:372-388`. Needs numdec<1 → subs fallback.
- [x] Log autoscale with nonpositive data explodes range to ~10^-315 — `axes-base.lisp:308-329`
  (`-300.0d0` fallback); should ignore nonpositive data like matplotlib.
- [x] `%nonsingular` both-inputs-~0 case returns unchanged instead of expanding — `ticker.lisp:60-64`.
- [x] errorbar/bar `capsize` converted pts→data with hardcoded 0.01 — `axes.lisp:299,311,883,897`.
  Cap size depends on data range.
- [ ] `axhline`/`axvline`/`axhspan`/`axvspan` bake current limits as data coords —
  `axes.lisp:1386-1434,522-582`. Needs blended transform; `axhline` before `plot` yields a short line.
- [x] Shared-axes limit propagation not transitive — `axes-base.lisp:740-772` +
  `gridspec.lisp:413-423` (all wired to axarr[0,0] only).
- [x] figure frame `rgba-edge` shadowed by malformed duplicate binding — `figure.lisp:383-389`
  (`multiple-value-list` of a vector). Masked by lw 0 default; delete the second binding.
- [x] `wedge :width` normalization wrong for r≠1 — `patches.lisp:240-246`; should be
  `(/ (- r width) r)`. Masked by pie's r=1.
- [x] annotation draw drops ha/va and duplicates text-artist draw — `annotation.lisp:99-113`;
  annotation bbox mixes data coords with point units then applies data transform — `:116-139`.
- [ ] `colormap-call` coerces ints to float, breaking `boundary-norm` LUT indexing —
  `colors.lisp:161-193,644-681`. Needs an `(integerp value)` direct-index branch.
- [ ] `normalize-call` scalar autoscale pins vmin=vmax → everything maps to one color —
  `colors.lisp:353-365`.
- [ ] rcParams file round-trip corrupts values (`nil`→"None" dead branch; `#`-hex colors eaten
  as comments on re-read) — `rcsetup.lisp:680-695` + `matplotlibrc-parser.lisp:11-23`.
- [x] Polar constant-r arcs always CCW (decreasing theta renders complementary 270° arc) —
  `polar-transforms.lisp:47-60`.
- [x] `polar-affine-update` mutates matrix without invalidating parents — `polar-transforms.lisp:142-159`.
- [x] Double-closing in `path-create-closed` / `path-unit-rectangle` (start vertex 3×; crashes on
  empty input) — `path.lisp:1111-1116,882-888,203-218`.
- [x] imshow `origin :upper` + user extent inverts the whole y-axis — `plotting/image.lisp:94-97`
  (fixed; `:aspect` numeric/`:auto` still documented-but-unimplemented — `:99`).
- [ ] contour: NaN in Z crashes (SBCL FP traps) or propagates NaN vertices — `contour.lisp:243-249`,
  `marching-squares.lisp:90-96`. No masking anywhere.
- [x] boxplot/violin/hist reject vectors where lists work (dataset normalization via `listp`) —
  `stats.lisp:77-79`, `violin.lisp:69-78`, `hist.lisp:98`.
- [ ] per-pixel 0-255 vs 0-1 detection in image RGB conversion (uint8 (1,1,1) renders white) —
  `rendering/image.lisp:272-289`. Decide once per array.
- [ ] fancy-arrow connectionstyles computed then ignored (`:arc3 :rad` no-op; sign also mirrored
  vs matplotlib if wired up) — `fancy-arrow.lisp:198,430-438,44-45`; cached path not invalidated
  by slot writes (`:358-362`).

### pyplot design
- [x] **No current-axes tracking** — `pyplot.lisp:73-82`. `gca` returns last-created axes; no
  `sca`/`subplot` switching. After `(subplots 2 2)` all pyplot calls target one axes.
- [ ] Figure registry: eql-keyed nums (1 vs 1.0 distinct), no string labels, `close-figure`
  rejects figure objects, `:all` doesn't reset counter, no locking — `pyplot.lisp:19-120`.
- [ ] quiver positional args via `&rest/&key/&allow-other-keys` is CLHS-nonconforming (works on
  SBCL/CCL/ECL today) — `pyplot.lisp:453-464`, `plotting/quiver.lisp:107-109`.

## P3 — performance

- [ ] **O(n²) `%coll-nth` in line/poly/quad-mesh/quiver draw loops** — `collections.lisp:312-329,
  494-512,621-637`, `quiver.lisp:167-186`. Base method already has the fix (`%coll-nth-vec`);
  apply it to the four overriding methods. pcolormesh 100×100 ≈ 10⁸ list traversals per draw.
- [ ] **Marching-squares segment joining quadratic-plus** (`append`/`last` inside rescan loop) —
  `marching-squares.lisp:156-199`. Hash on endpoints → near-linear. Multiplied by level count.
- [ ] **contourf emits one polygon per grid cell per band** + seam-hiding strokes —
  `marching-squares.lisp:228-264`, `contour.lisp:213-223`. 500×500×8 bands ≈ 2M micro-polygons.
- [ ] Font manager: full system TTF scan on first use; `load-font-cache`/`save-font-cache` are
  dead code; no `find-font` memoization; annotation loads a font per draw —
  `font-manager.lisp:236-253,296-329,361-410`.
- [ ] `%draw-y-axis-label` opens a fresh zpb-ttf loader every draw, no unwind-protect (leaks on
  error) — `axis.lisp:798-830`. Use the caching `load-font`.
- [ ] Ticks regenerated 2-3× per draw (grid pass, tick pass, ylabel measurement) — `axis.lisp` +
  `axes-base.lisp:492-503`. Cache on the axis.
- [ ] `%path-axis-aligned-p` transforms all vertices, then trace transforms them again (2N
  transforms + 4N allocations per polyline) — see P2 backends entry.
- [ ] `scalar-mappable-autoscale` uses `(apply #'min vals)` — exceeds call-arguments-limit on
  CCL at 65536 elements — `colors.lisp:713-717`. Use reduce.
- [ ] SVG emits identical `<clipPath>` per clipped draw (~15 dups in simple-line.svg) —
  `backend-svg.lisp:297-313`. Dedup by rect.
- [ ] `hatch-get-path` rebuilt per fill per draw; collection get-paths recons arrays + gc per
  item per draw — `hatch.lisp:283-348`, `collections.lisp:222-257,539-605`.
- [ ] `%histogram-counts` linear scan per point (comment claims binary search) — `hist.lisp:36-45`.
- [ ] `compose` grows weak-parent lists on long-lived children per draw; `transform-wrapper-set`
  never detaches old child — `transforms.lisp:167-172,666-673`.

## P4 — architecture & design

- [~] **Layering violations, and CLAUDE.md's `uiop:symbol-call` claim is false** — zero uses in
  `src/`. Actual mechanism is raw forward references: `quiver.lisp:153` calls
  `cl-matplotlib.containers::%compute-display-bbox` (2 layers up, internal symbol);
  `text.lisp:79`, `lines.lisp:208,225` call `mpl.backends:` functions (1 layer up). Loading
  rendering alone breaks at runtime. Fix the calls or fix the docs (preferably both).
  PARTIALLY FIXED: rendering now owns `renderer-dpi`/`renderer-draw-markers` protocol
  generics (backends bridge them; containers switched over); `quiver.lisp:153` and the
  CLAUDE.md doc drift remain.
- [x] **`*read-eval*` not bound to nil around `read-from-string` on external input** —
  `rcsetup.lisp:58,80` (rc/style files), `colors-database.lisp:118-120` (color strings),
  `afm.lisp:35` (AFM font files). `#.(...)` executes code at parse time.
  FIXED: all four sites bind `*read-eval*` to nil; colors-database now reads once and
  reuses the parsed value.
- [ ] `src/packages.lisp` is a component of 3 systems (double compile/load, package clobber
  risk) — foundation, primitives, and meta `.asd`s.
- [ ] `cl-matplotlib-containers.asd` modules lack `:serial t` internally — incremental/parallel
  builds have no ordering guarantee for order-dependent files.
- [x] `with-style` loads style files at macroexpansion time (freezes key set into compiled code,
  requires stylelib at compile time) — `style.lisp:94-120`. Do it at runtime like `rc-context`.
- [x] `with-rc` and `rc-context` are byte-identical duplicates — `rcsetup.lisp:549-567,601-620`.
  FIXED: `rc-context` now expands into `with-rc`.
- [x] zorder draws rely on `sort` stability (unspecified in CL) — `axes-base.lisp:447`,
  `figure.lisp:356`. Use `stable-sort`.
- [~] Dead package `cl-matplotlib.foundation` exports 8 undefined symbols, 2 colliding with real
  primitives exports — `packages.lisp:78-85`. `cl-matplotlib:version` exported, never defined
  (`:704`). `%make-mpl-path` internal constructor exported (`:100`). `mock-renderer` lives in the
  production rendering package (`:233`).
  PARTIALLY FIXED: dead `cl-matplotlib.foundation` defpackage deleted (verified unreferenced);
  `version`, `%make-mpl-path`, and `mock-renderer` remain.
- [ ] renderer-base default `draw-markers`/`draw-path-collection` are dead-but-wrong (ignore
  trans, drop offsets) — `renderer-base.lisp:132-169`.
- [ ] Vecto fast path depends on unexported vecto/cl-aa internals; roswell has cl-vectors
  20241012 vs quicklisp 20180228 — `backend-vecto.lisp:594-679`. Add a load-time sanity check.
- [ ] Vecto fill+stroke y-offset: code -0.7, comments say -0.5, duplicated 3×; fill-only uses 0
  (0.7px misalignment between edged and un-edged shapes) — `backend-vecto.lisp:441-470,393`.
- [ ] colorbar mutates parent position in place; pre-existing twins don't follow —
  `colorbar.lisp:91,115`.
- [ ] `label_outer` ignores share mode (`:row`/`:col`) — `gridspec.lisp:424-450`.
- [x] repeated `suptitle` accumulates artists — `figure.lisp:247-274`.
- [x] `hlines`/`vlines` reject vectors, silently truncate short `colors` — `axes.lisp:1446-1490`
  (fixed; `stem` errors on empty data — `:1001-1002` — not addressed).
- [ ] Violin parity: population vs sample variance in KDE bandwidth, ±5% range padding,
  missing center bar — `violin.lisp:28-36,92-94,191-236`.
- [ ] hexbin can't render matplotlib's zero-count background (hash accumulation, mincnt≥1) —
  `hexbin.lisp:105,131-132`.
- [~] Misc dead code: `%sort-polygon-vertices`, `define-cached-function` (broken on lambda-list
  keywords, exported), `%interpolate-control-points`, `path-annular-wedge` duplicate arc,
  mathtext dead branches, marker scaffolding — see agent reports for lines.
  PARTIALLY FIXED: `%sort-polygon-vertices` and `define-cached-function` removed (no callers);
  the rest remains.

## P5 — repo hygiene

- [ ] 48 tracked files under gitignored `reference_images/`; 167 under `.sisyphus/`.
  **`make clean` deletes the tracked reference images.** Decide: commit-and-unignore, or
  `git rm --cached`. `.sisyphus/` should almost certainly be untracked.
- [ ] Untracked at root: `CLAUDE.md` (referenced as checked-in — commit it), `benchmarks/`
  (Makefile targets depend on it — commit minus `output/`), `label-vts.tsv` (43 MB — don't
  commit), `.continue.bak` (delete).
- [ ] `data/7x7s-*` — 5.3 MB of crossword-solver logs from another project committed here,
  only read by untracked benchmark scripts.
- [ ] CI: `actions/checkout@v3` outdated; second Quicklisp installed into `~/quicklisp` that
  `ros run` never uses; redundant Load-then-Test steps.
- [ ] 10 tests end in unconditional `(pass)`; `test-backend-vecto.lisp:361` silently skips
  without a font. Test-file gaps: no tests for cbook, colormaps, polar-transforms, lines,
  patches, text, markers, image, hatch, fancy-arrow, quiver, ticker, spines, layout-engine,
  legend-handler.
- [ ] CLAUDE.md architecture diagram omits `src/plotting/` and `src/algorithms/` (both compiled
  into cl-matplotlib-containers — sensible, just undocumented); `uiop:symbol-call` claim stale.
