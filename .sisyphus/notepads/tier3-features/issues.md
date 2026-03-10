# Tier 3 Features — Issues & Gotchas

## [2026-02-22] Session ses_383b1abbdffeaEsvS36ri8MZk1 — Known Risks

### KDE Edge Cases (Task 1)
- Single data point or all-identical values: bandwidth → 0 → Dirac delta → numeric issue
  - Fix: clamp minimum bandwidth to sigma * 0.1 or use fixed fallback (e.g., 1e-3)
- Empty dataset: skip/return nil gracefully

### Quiver Edge Cases (Task 3)
- Zero-length arrows (U=0, V=0): skip, don't try to normalize
- NaN or Inf in U/V: skip that arrow

### Polar Edge Cases (Task 5)
- Theta wrapping: paths crossing the 2π/0 boundary need special handling
- Path tessellation: must happen BEFORE transform (not after)

### Known Pre-Existing Failure
- color-cycle: SSIM 0.9462 (< 0.95) — rendering engine limitation (zpb-ttf vs FreeType)
- Do NOT try to fix this — accepted by user

### Fragile Existing Examples (Monitor During Regressions)
- step-plot: SSIM 0.955 (barely above threshold)
- histogram-multi: SSIM 0.951 (barely above threshold)

### Render Command
- MUST use: setarch $(uname -m) -R ros run -- --noinform --load examples/{name}.lisp 2>/dev/null
- Do NOT use: make cl-images or make compare
- Do NOT modify: tools/compare.py or src/pyplot/pyplot.lisp line 242
