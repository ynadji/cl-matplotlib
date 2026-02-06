
## Phase 3a — Artist Hierarchy (2026-02-06)

### Patterns
- CLOS classes with `initialize-instance :after` work well for Python `__init__` chains
- `defgeneric draw (artist renderer)` provides clean polymorphic dispatch
- Mock renderer pattern (recording calls) excellent for testing draw protocol
- Package exports must be comprehensive — test file imports everything it needs

### Gotchas
- CL reader interprets `:|`, `:*`, `:+`, `:.`, `:_` as valid symbols but they cause parsing issues in `case` forms
- Solution: Use descriptive keywords `:plus`, `:star`, `:vline`, `:hline`, `:point` instead
- Must be careful with `defmethod (setf accessor) :after` — useful for stale tracking
- FancyBboxPatch simplified (no rounded corners yet) — just uses unit rectangle

### Stats
- 119/119 tests passing (100%)
- Files: artist.lisp, lines.lisp, patches.lisp, text.lisp, markers.lisp, image.lisp
- Classes: artist, line-2d, patch, rectangle, circle, ellipse, polygon, wedge, arc, path-patch, fancy-bbox-patch, text-artist, marker-style, axes-image, mock-renderer, graphics-context
