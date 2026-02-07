# cl-matplotlib

A Common Lisp port of Python's matplotlib library, providing a comprehensive plotting and visualization toolkit for Lisp applications.

[![CI](https://github.com/yacin-hamza/cl-ingrid/workflows/CI/badge.svg)](https://github.com/yacin-hamza/cl-ingrid/actions)

## Features

- **Object-Oriented API**: Figure, Axes, Artist hierarchy matching matplotlib's design
- **Multiple Plot Types**: line, scatter, bar, histogram, contour, image, pie, errorbar, stem, and more
- **Advanced Features**: legends, colorbars, annotations, gridspec layouts, shared axes
- **Scale Systems**: linear, logarithmic, symlog, logit, and custom function scales
- **Font Management**: TrueType font support with CSS-like font matching
- **PNG Backend**: Vecto-based rendering to PNG format
- **Procedural API**: pyplot-style interface for quick plotting
- **Multi-Implementation**: Tested on SBCL and CCL

## Installation

### Prerequisites

- Common Lisp implementation (SBCL or CCL)
- Quicklisp

### Setup

```lisp
(ql:quickload :cl-matplotlib-pyplot)
```

## Quick Start

```lisp
(use-package :cl-matplotlib.pyplot)

;; Create a simple plot
(figure)
(plot '(1 2 3 4) '(1 4 2 3))
(xlabel "X Axis")
(ylabel "Y Axis")
(title "Simple Plot")
(savefig "/tmp/plot.png")
```

## System Architecture

The library is organized into modular systems:

- **cl-matplotlib-foundation**: Core data structures (colors, transforms, paths)
- **cl-matplotlib-primitives**: Primitive shapes and transforms
- **cl-matplotlib-rendering**: Artist hierarchy and rendering protocol
- **cl-matplotlib-backends**: PNG backend via Vecto
- **cl-matplotlib-containers**: High-level containers (Figure, Axes, Legend, etc.)
- **cl-matplotlib-pyplot**: Procedural pyplot-style interface

## Testing

Run the full test suite:

```bash
sbcl --eval '(ql:quickload :cl-matplotlib-pyplot)' \
     --eval '(asdf:test-system :cl-matplotlib-pyplot)' \
     --quit
```

Or test individual systems:

```bash
sbcl --eval '(ql:quickload :cl-matplotlib-foundation)' \
     --eval '(asdf:test-system :cl-matplotlib-foundation)' \
     --quit
```

## Supported Implementations

- **SBCL** (Steel Bank Common Lisp) - Primary development target
- **CCL** (Clozure Common Lisp) - Fully supported

CI runs tests on both implementations automatically on every push and pull request.

## Examples

### Scatter Plot with Legend

```lisp
(figure)
(scatter '(1 2 3 4 5) '(2 4 5 4 6) :label "Data")
(legend)
(savefig "/tmp/scatter.png")
```

### Subplots with GridSpec

```lisp
(multiple-value-bind (fig axs) (subplots 2 2)
  (plot-on (aref axs 0 0) '(1 2 3) '(1 2 3))
  (plot-on (aref axs 0 1) '(1 2 3) '(3 2 1))
  (plot-on (aref axs 1 0) '(1 2 3) '(2 2 2))
  (plot-on (aref axs 1 1) '(1 2 3) '(1 3 2))
  (savefig "/tmp/subplots.png"))
```

### Contour Plot

```lisp
(figure)
(let* ((x (loop for i from 0 to 10 collect (float i)))
       (y (loop for i from 0 to 10 collect (float i)))
       (z (make-array '(11 11))))
  ;; Fill z with some data
  (contourf z :levels 10)
  (colorbar)
  (savefig "/tmp/contour.png"))
```

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please ensure:

1. All tests pass on both SBCL and CCL
2. New features include comprehensive tests
3. Code follows the existing style conventions

## Status

**Production-Ready MVP** - 2,069/2,069 tests passing (100%)

The library implements a comprehensive subset of matplotlib functionality suitable for scientific visualization, data analysis, and publication-quality plots.
