
## Task 13: Gallery Batch B Learnings

### colorbar is broken
- `colorbar` calls `SM-NORM` on the mappable, but neither `AXES-IMAGE` nor `QUAD-CONTOUR-SET` inherits from `scalar-mappable`
- Neither class has the `sm-norm` accessor slot
- Fallback: skip colorbar entirely, use the plots without it

### Pattern confirmed
- All Batch A examples use `defpackage #:example` pattern (not unique package names)
- All use `(uiop:quit)` at the end
- Double-float values required for data (`1.0d0` not `1.0`)

