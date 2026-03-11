# Task 6: fill-between :where Parameter Support

## Changes Made

### `src/containers/axes.lisp`
- Added `%find-true-regions` helper: finds contiguous true-region index pairs in a boolean sequence
- Added `:where` keyword parameter to `fill-between` (default nil)
- When `:where` is nil: original single-polygon behavior unchanged
- When `:where` is provided: calls `%find-true-regions` to find contiguous true runs, then creates separate polygon per region via recursive call to `fill-between` (without `:where`)
- All sub-polygons share same color, alpha, label, zorder

### `src/pyplot/pyplot.lisp`
- Added `(where nil)` to `fill-between` keyword args
- Passes `:where where` through to `mpl.containers:fill-between`

## Test Results

### Visual Test
- Generated `/tmp/test-fill-where.png` with:
  - Two sine curves: y1=sin(x), y2=0.5*sin(2x), x in [0, 4π]
  - Green fill where y1 > y2 (multiple separate regions)
  - Red fill where y1 ≤ y2 (multiple separate regions)
- Verified: alternating green/red filled regions correctly match curve crossings

### Test Suite
- `FILL-BETWEEN-BASIC` test: PASSED
- All other test results identical to baseline (same 156 checks, same pre-existing failures unrelated to fill-between)
- No new test regressions

## API
```lisp
;; Without :where — original behavior
(fill-between ax xdata y1data y2data :color "blue" :alpha 0.3)

;; With :where — conditional fill
(fill-between ax xdata y1data y2data
  :where (mapcar #'> y1data y2data)
  :color "green" :alpha 0.4)
```
