# Extending ggplot (gg)

The `ggplot.extend` package (nickname `gg.ext`) is the supported surface
for third-party geoms, stats, positions, scales, and data structures. The
`gg` package stays purely user-facing; everything an extension author
needs is exported from `gg.ext`.

A minimal extension system:

```lisp
;; my-ridges.asd
(defsystem "my-ridges" :depends-on ("ggplot") :components ((:file "ridges")))
```

```lisp
;; ridges.lisp
(defpackage #:my-ridges
  (:use #:cl #:gg.ext)
  (:export #:geom-ridgeline))
(in-package #:my-ridges)

(defclass geom-ridgeline-obj (geom) ())

(defmethod geom-default-aes ((geom geom-ridgeline-obj))
  '(:color "#333333" :fill "#7F7F7FCC" :size 0.5d0 :alpha 1.0d0))

(defmethod geom-key-glyph ((geom geom-ridgeline-obj)) :rect)

(defmethod geom-draw-panel ((geom geom-ridgeline-obj) data panel axes)
  ;; DATA is a gtable whose columns are fully mapped aesthetics
  ;; (hex color strings, final positions). Draw with the containers API.
  (let ((x (gtable-column data :x))
        (y (gtable-column data :y)))
    ...))

(defun geom-ridgeline (&rest args &key mapping data &allow-other-keys)
  (declare (ignore mapping data))
  (apply #'make-geom-layer 'geom-ridgeline-obj args))
```

Used like any built-in:

```lisp
(gg:stack (gg:ggplot df (gg:aes :x :len :y :grp :fill :grp))
  (my-ridges:geom-ridgeline))
```

## Extension points

### Geoms
Subclass `geom`; specialize:
- `geom-default-aes` — plist of default fixed aesthetics.
- `geom-setup-data` — derive geometry columns (e.g. x/width -> xmin/xmax).
- `geom-draw-panel (geom data panel axes)` — draw one panel's gtable.
- `geom-key-glyph` — `:point`, `:line`, or `:rect` legend key.
- `geom-legend-artist` — optional proxy artist for the key.
Build layers with `make-layer` (full control) or `make-geom-layer`
(the standard keyword-args-to-params convention used by the built-ins).

### Stats
Subclass `stat`; specialize `stat-compute-panel` (whole panel) — use
`map-stat-groups` to get the standard per-group split/rbind behavior —
and `stat-default-aes` for stat-supplied aesthetics like
`(:y (after-stat :count))`. Register a keyword so users can write
`:stat :my-stat` in geom constructors:

```lisp
(register-stat :ridge-density 'stat-ridge-density-obj)
```

### Positions
Subclass `ggposition`, specialize `position-adjust (position data &key)`,
optionally `(register-position :my-dodge 'my-dodge-obj)`.

### Scales
Subclass `scale-continuous` or `scale-discrete`; the protocol is
`scale-train`, `scale-transform`, `scale-map`, `scale-limits`,
`scale-breaks`, `scale-break-labels`, `scale-expanded-range`.

### New aesthetics
`(register-aesthetic :height)` makes `(aes :height ...)` legal. Your
geom/stat is responsible for consuming the column.

### Data structures
Implement the three protocol generics (exported from `gg` proper, since
they're user-facing too): `ggcolumns`, `ggcolumn`, `ggnrows`. Every gg
feature then works with your type directly.

### gtables
Stat/geom methods receive `gtable`s — ordered column tables. Exported
ops: `make-gtable`, `gtable-column`, `gtable-column-names`,
`gtable-set-column`, `gtable-select`, `gtable-split`, `gtable-rbind`,
`gtable-sort-by`, `gtable-nrows`.

### Helpers
- `size-to-linewidth`, `size-to-scatter-s` — gg size -> backend units
  (plotnine's sqrt(pi) conventions).
- `extended-breaks` — the mizani break algorithm.
- `finite-range`, `discrete-value-p`.
- `resolve-stat`, `resolve-position` — keyword/instance designators.

## Composing with plots

`ggadd` is a generic: a component class you define can specialize
`(ggadd plot component)` to fold itself into a plot any way it likes,
and then works inside `gg:stack` automatically.
