# SVG Backend — Learnings

## [2026-02-23] Session ses_383b1abbdffeaEsvS36ri8MZk1 — Plan Initialized

### Architecture From Prior Research (Metis + Background Agents)
- Backend protocol: 6 core generics + 3 bridge methods in `src/rendering/artist.lisp:217-225`
- WITHOUT the 3 bridge methods (renderer-draw-path/text/image) specialized on renderer-svg, savefig produces BLANK SVGs
- `%resolve-color`, `%gc-edge-color`, `%gc-face-color` are defined in `backend-vecto.lisp` — reuse, DO NOT redefine
- `gc-linewidth` is DUAL-PURPOSE: stroke-width in draw-path, font-size in draw-text
- `zpng:write-png` only takes pathname (not stream) — temp-file approach needed for base64 image embedding
- SVG is y-down, figure is y-up — global `<g transform="translate(0,H) scale(1,-1)">` handles Y-flip
  - Text elements need counter-flip: `transform="translate(x,-y) scale(1,-1)"` or similar
  - Image elements need same counter-flip

### Integration Points (confirmed from code inspection)
- `src/containers/figure.lisp:417` — `detect-format` already returns `:svg` for .svg extension
- `src/containers/figure.lisp:510-526` — savefig `case` needs `:svg` branch (currently falls through to warn + PNG)
- `cl-matplotlib-backends.asd:15-17` — Add `backend-svg` to `:components` (after `backend-pdf`)
- `src/packages.lisp:653-656` — Mirror PDF exports pattern for SVG

### Path Code Mapping (confirmed)
- `+moveto+` → `M x y`
- `+lineto+` → `L x y`
- `+curve3+` → `Q cx cy ex ey` (SVG native quadratic — simpler than PDF)
- `+curve4+` → `C c1x c1y c2x c2y ex ey`
- `+closepoly+` → `Z`
- `+stop+` → exit loop

### Git State
- Branch: topic/yacin/svg-backend
- Tier 3 features fully complete and merged (PR #1)
- 208+ unit tests passing on main

### Key Constraints
- NO new ASDF/Quicklisp dependencies (no cl-svg, no cl-base64)
- Use inline base64 encoder (~25 lines) for image embedding
- Dash patterns: scale by linewidth-in-pixels (match Vecto, NOT PDF's fixed values)
- Float precision: `~,2f` for coordinates (0.01px)
- XML escape text: & → &amp;, < → &lt;, > → &gt;, " → &quot;

## [2026-02-22] Task 1: XML helper + renderer-svg class — COMPLETE

### What was built
- `src/backends/backend-svg.lisp` (166 lines) — foundation file
- `%svg-xml-escape`: & < > " escaping works correctly
- `renderer-svg` class: 5 slots (output-stream, defs-stream, id-counter, height, font-cache)
- `%format-float`: 2 decimal places via `~,2F` with double-float coercion
- `%next-id`: prefix + incrementing counter
- `%color-to-svg`: (r g b a) → "#RRGGBB" + opacity; nil → "none" + 0.0
- `%trace-path-to-svg`: M/L/Q/C/Z path commands with transform support
- `renderer-clear`: emits `<rect width="W" height="H" fill="white"/>`

### Key decisions
- Used `coerce` to double-float in `%color-to-svg` to handle mixed single/double inputs
- `%trace-path-to-svg` returns a string (unlike vecto which mutates graphics state)
- Synthesizes MOVETO+LINETO codes when `codes` is nil (matching vecto pattern)
- No Y-flip in path tracing — handled by global `<g>` transform in print-svg (Task 5)

### Patterns followed
- Same `(in-package #:cl-matplotlib.backends)` as other backends
- Class slot naming: `renderer-svg-*` accessor prefix (like `renderer-pdf-font-cache`)
- Did NOT redefine `%resolve-color`, `%gc-edge-color`, `%gc-face-color` — they're in vecto

### Evidence
- All 5 tests pass: xml-escape, path-trace (M/L/Z), curves-trace (Q/C), color-convert, renderer-clear
- File loads cleanly after `(ql:quickload :cl-matplotlib-backends)`

## [2026-02-22] Task 2: draw-path + GC→SVG mapping — COMPLETE

### What was built
- `%apply-gc-to-svg-attrs`: Returns plist of SVG attribute strings from GC state
  - stroke-width, stroke-linecap, stroke-linejoin, stroke-dasharray
  - Dash patterns: scales base patterns by linewidth with min 1.0 (matching Vecto)
  - Explicit gc-dashes list takes priority over gc-linestyle
- `%emit-clip-path`: Emits `<clipPath>` with `<rect>` to defs-stream, returns clip ID
- `draw-path` method on `renderer-svg`: Full fill+stroke SVG `<path>` emission

### Key patterns
- Returns plist from `%apply-gc-to-svg-attrs` (vs Vecto's imperative set-* calls)
- gc-alpha multiplied into both fill-opacity and stroke-opacity
- Always emits fill/stroke (even "none") for SVG parser compatibility
- Empty/zero-vertex paths silently skipped (return nil)
- Clip-path goes to defs-stream, path element to output-stream (separation for SVG document structure)
- `make-bbox` takes positional args (x0 y0 x1 y1), NOT keyword args

### Dash pattern verification
- lw=2.0, :dashed → "7.40 3.20" ✓ (3.7*2=7.4, 1.6*2=3.2)

### Evidence
- 5 tests pass: basic fill+stroke, dashed line, clip-rectangle, nil-edge→stroke=none, zero-vertex skip
