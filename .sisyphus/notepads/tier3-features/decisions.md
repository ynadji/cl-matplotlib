# Tier 3 Features — Decisions

## [2026-02-22] Session ses_383b1abbdffeaEsvS36ri8MZk1 — Initial Decisions

### Feature Order
- Violin → Quiver → Polar → Streamplot (by unlock ratio: most examples per effort)
- User confirmed: all four features, full polar axes

### PolarAxes Architecture
- Subclasses `axes-base` directly (NOT `mpl-axes`)
- Simple `case` dispatch on `:projection` keyword — no factory/registry
- Theta in RADIANS internally (degree labels for display only)
- Theta range: 0→2π (no partial wedge)
- NO modification of existing class definitions (axes-base, mpl-axes, axis, spines)

### Violin KDE
- Own GaussianKDE implementation (Scott's rule bandwidth: h = n^(-1/5) * σ)
- No scipy or external dependency
- Follow boxplot pattern exactly

### Quiver
- Extend PolyCollection (7-vertex polygon per arrow)
- Arrow rotation via complex multiplication
- Deferred geometry computation at draw() time

### Streamplot
- Direct port of matplotlib's RK12 adaptive integrator
- StreamMask: density×30 × density×30 occupancy grid
- Returns LineCollection + FancyArrowPatch direction indicators

### Scope Exclusions (User Confirmed)
- No QuiverKey, half-violins, polar-bar/scatter/contour/fill-between
- No start_points or broken_streamlines for streamplot
- No interactive pan/zoom on polar
- No variable-color streamlines (single color only)
