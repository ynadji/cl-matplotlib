# Title Rendering Bug Diagnosis

## Scope
- bar-chart title: **VISIBLE** — "Programming Language Popularity" renders correctly
- pcolormesh-basic title: **NOT VISIBLE** — "Radial Wave: cos(r)*exp(-r^2/10)" missing from PNG
- Conclusion: **colorbar-specific** (not systemic)

## Root Cause
The `%make-colorbar-axes` function (colorbar.lisp:103,125) uses `(push cax (figure-axes fig))` to add the colorbar axes to the figure. Since `push` prepends, the colorbar axes becomes the first element in `figure-axes`. The `gca` function (pyplot.lisp:80) returns `(first axes-list)`, so any pyplot call made after `(colorbar ...)` — including `(title ...)` — targets the **invisible colorbar axes** (which has `visible=nil`). The title text-artist is added to an invisible axes whose `draw` method returns immediately, so the title is never rendered.

## Affected Examples
Any example that calls `(title ...)` (or `(xlabel ...)`, `(ylabel ...)`, etc.) AFTER `(colorbar ...)` would be affected. Currently only `pcolormesh-basic.lisp` exhibits this pattern.
