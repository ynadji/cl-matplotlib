# Task 16: SVG + PDF Hatch Pattern Rendering

## Summary
Implemented hatch pattern rendering in both SVG and PDF backends, matching the existing Vecto (PNG) backend.

## Implementation

### SVG Backend (`backend-svg.lisp`)
- Added `%emit-svg-hatch-pattern` function that uses `hatch-get-path` (same as Vecto) to generate SVG `<pattern>` definitions
- Pattern uses DPI-based tile size (100px) with 6-line density, matching Vecto exactly
- Hatch lines rendered as SVG `<path>` inside `<pattern>` in `<defs>`
- Applied as overlay fill `url(#hatch-N)` on a duplicate path after the solid fill

### PDF Backend (`backend-pdf.lisp`)
- Added `%render-hatch-pdf` function that uses `hatch-get-path` (same as Vecto)
- After fill+stroke, clips to patch shape and tiles hatch lines across bounding box
- Uses `pdf:with-saved-state` for isolation, matching Vecto's `vecto:with-graphics-state`
- Stroke color defaults to edge color or black

### Supported patterns: `/`, `\`, `x`, `o`, `|`, `-`, `+`, `O`, `.`, `*`

## SSIM Results
- PNG SSIM: 0.9627 (target: N/A, reference)
- SVG SSIM: 0.9434 (target: >= 0.90) PASS
- PDF SSIM: 0.9475 (target: >= 0.88) PASS

## Regression Check
- bar-chart PNG SSIM: 0.9621 (no regression)
- Test suite: 208/208 pass (100%)

## Visual Verification
- PNG: 4 bars with distinct hatch patterns (/, \, x, o) on colored fills
- SVG: 4 bars with distinct hatch patterns (/, \, x, o) on colored fills (verified via cairosvg)
- PDF: 4 bars with distinct hatch patterns (/, \, x, o) on colored fills (verified via ImageMagick)
