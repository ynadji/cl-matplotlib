# Root Cause Analysis

## File:Line
`src/containers/colorbar.lisp:103` (vertical case) and `src/containers/colorbar.lisp:125` (horizontal case)

## Bug
`(push cax (figure-axes fig))` makes the invisible colorbar axes the "current axes" returned by `gca`, causing subsequent pyplot calls like `title` to target the wrong axes.

## Fix Location
Same lines — `src/containers/colorbar.lisp:103` and `src/containers/colorbar.lisp:125`

## Fix Approach
Replace `(push cax (figure-axes fig))` with `(setf (figure-axes fig) (nconc (figure-axes fig) (list cax)))` to append the colorbar axes to the END of the list. This keeps the main axes as `(first (figure-axes fig))`, so `gca` continues to return the correct axes after colorbar creation. This matches matplotlib's behavior where the current axes is not changed by colorbar().

## Implemented
YES — both vertical and horizontal branches fixed. Verified:
- pcolormesh-basic.png now shows title
- bar-chart.png still shows title (no regression)
- All 208 tests pass
