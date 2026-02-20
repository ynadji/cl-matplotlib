# Visual Regression Issues

## [2026-02-19] Root Cause Analysis

### Issue 1: INCORRECT VIRIDIS/PLASMA COLORMAP DATA (CRITICAL)
**Files**: `src/primitives/colormaps.lisp`
**Symptoms**: 
- filled-contour SSIM=0.52
- colorbar-custom SSIM=0.62
- imshow-heatmap SSIM=0.75
- contour-lines SSIM=0.74 (partially from this)

**Root Cause**: The viridis/plasma/inferno/magma/cividis colormaps use only 16 control points 
interpolated to 256 entries (`%interpolate-control-points`). Linear interpolation between 
16 points doesn't reproduce the actual perceptually-uniform viridis colormap.

**Proof**: 
- Python: norm=0.524 → rgb=(31,150,139) [teal]
- CL:     norm=0.524 → rgb=(89,206,95)  [bright green — WRONG]

**Fix**: Replace 16-point control points with full 256-entry lookup tables extracted from Python.
The `%register-listed-cmap` function already handles 256-entry lists; just need to update the data.
Use `%register-from-list-cmap` with 256 entries instead of `%register-listed-cmap`.

**Extract from Python**:
```python
import matplotlib.cm as cm
cmap = cm.viridis
data = [(float(cmap(i/255)[0]), float(cmap(i/255)[1]), float(cmap(i/255)[2])) for i in range(256)]
```

### Issue 2: TEXT ROTATION NOT IMPLEMENTED (CRITICAL)
**Files**: `src/backends/backend-vecto.lisp` (draw-text method, line ~361)
**Symptoms**: Y-label (ylabel) not visible in any example (variance=0.0, confirmed in evidence)
**Root Cause**: `draw-text` has TODO comment for rotation support. The `when angle ≠ 0` block is a no-op (`nil`). The text IS drawn (draw-string called outside the when block) but WITHOUT rotation — so a horizontal "y" label is placed at the wrong position.

**Additional Issue**: Y-label position (x ~35-45 pixels, left margin) is OUTSIDE the active axes clip rectangle. The clip inherits from the outer drawing context (axes clip), which cuts off the margin area.

**Fix**:
1. In `draw-text`, reset clip to full figure bounds when GC has no clip rectangle:
   ```lisp
   (unless (and gc (mpl.rendering:gc-clip-rectangle gc))
     (vecto:rectangle 0 0 (float (renderer-width renderer) 1.0) (float (renderer-height renderer) 1.0))
     (vecto:clip-path)
     (vecto:end-path-no-op))
   ```
2. Implement text rotation using Vecto's built-in `vecto:translate` + `vecto:rotate-degrees`:
   ```lisp
   (if (and (numberp angle) (/= angle 0.0))
     (progn
       (vecto:translate (float x 1.0) (float y 1.0))
       (vecto:rotate-degrees (float angle 1.0))
       (vecto:draw-string 0.0 0.0 s))
     (vecto:draw-string (float x 1.0) (float y 1.0) s))
   ```

**Note**: Vecto exports `vecto:rotate-degrees` and `vecto:translate`.
Check ~/quicklisp/dists/quicklisp/software/vecto-1.6/package.lisp for exact function names.

### Issue 3: CONTOUR GEOMETRY (MODERATE)
**Symptoms**: contour-lines SSIM=0.74
**Status**: Both CL and reference images look geometrically correct (centered, symmetric Gaussian).
The SSIM difference is PRIMARILY from the colormap issue (Issue 1). After fixing Issue 1,
this should improve significantly. May not need a separate fix.

### Issue 4: MINOR LAYOUT DIFFERENCES (LOW)
**Symptoms**: Most examples at 0.82-0.89 SSIM
**Causes**:
- Ylabel not visible (Issue 2 fix will help)
- Font rendering differences (Liberation Sans vs DejaVu Sans)
- Axis label positioning differences
- Minor spacing/margin differences
**Expected**: After fixing Issues 1+2, many 0.82-0.89 examples should cross 0.90.

## Technical Details

### Vecto Rotation API
- `vecto:rotate-degrees` — rotate current transform by degrees
- `vecto:translate` — translate current transform
- `vecto:with-graphics-state` — save/restore graphics state
- Use sequence: translate(x,y) → rotate-degrees(angle) → draw-string(0,0,s)

### Colormap Data Source
Python command to extract viridis 256 entries:
```python
import matplotlib.cm as cm
cmap = cm.viridis
data = [(float(cmap(i/255)[0]), float(cmap(i/255)[1]), float(cmap(i/255)[2])) for i in range(256)]
```

### CL Colormap Infrastructure
- `%register-from-list-cmap` — takes (R G B) list, interpolates to N entries
- `%register-listed-cmap` — takes pre-computed (R G B) list (256 entries)
- Viridis/plasma are currently registered with `%register-listed-cmap` 
  using 16 interpolated control points (wrong!) 
- Fix: register with `%register-from-list-cmap` using full 256-entry Python data
