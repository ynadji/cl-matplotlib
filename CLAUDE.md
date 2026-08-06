# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

cl-matplotlib is a pure Common Lisp port of Python's matplotlib, providing a pyplot-style API for creating publication-quality 2D plots (PNG, SVG, PDF). It uses Roswell (`ros`) as the Lisp runtime launcher and Quicklisp for dependency management.

## Build & Run

```bash
# Load the full system in a REPL
ros run -- --eval '(ql:quickload :cl-matplotlib-pyplot)' --eval '(use-package :cl-matplotlib.pyplot)'

# Run an example
ros run -- --load examples/bar-chart.lisp --quit

# Generate all CL example images
make cl-images
```

## Testing

Tests use the FiveAM framework. Each ASDF system has its own test suite.

```bash
# Run EVERY subsystem's suite in one shot (the cl-matplotlib/tests
# aggregate; also reachable as (asdf:test-system :cl-matplotlib)). Runs
# each suite even if an earlier one fails and prints a final summary. The
# base library suites are required; the display backends (show/-web/
# -sdl2) are load-guarded, so an unavailable one — missing libSDL2, web
# deps not fetched, or a freshly added .asd not yet in ASDF's registry —
# is reported skipped rather than aborting. If a show suite is
# unexpectedly skipped just after adding those systems, run
# (asdf:clear-source-registry) (or (ql:register-local-projects) under a
# Quicklisp local-projects setup) and re-run. Set SDL_VIDEODRIVER=dummy
# to exercise the SDL2 smoke test headlessly.
ros run -- --eval '(ql:quickload :cl-matplotlib/tests)' \
           --eval '(asdf:test-system :cl-matplotlib)' --quit

# Run tests for a specific system (foundation, primitives, rendering, backends, containers, pyplot)
ros run -- --eval '(ql:quickload :cl-matplotlib-foundation)' \
           --eval '(asdf:test-system :cl-matplotlib-foundation)' --quit

ros run -- --eval '(ql:quickload :cl-matplotlib-pyplot)' \
           --eval '(asdf:test-system :cl-matplotlib-pyplot)' --quit

# Run a single FiveAM test suite interactively
ros run -- --eval '(ql:quickload :cl-matplotlib-pyplot/tests)' \
           --eval '(fiveam:run! '"'"'cl-matplotlib.tests.pyplot::pyplot-suite)' --quit

# Run a single named test
ros run -- --eval '(ql:quickload :cl-matplotlib-pyplot/tests)' \
           --eval '(fiveam:run! '"'"'cl-matplotlib.tests.pyplot::test-name-here)' --quit
```

### Visual Comparison Tests

Compares CL-generated plots against Python matplotlib reference images using SSIM (thresholds: PNG >= 0.95, SVG >= 0.90, PDF >= 0.88).

```bash
make setup-python      # One-time: create Python venv
make reference-images  # Generate Python reference images
make compare           # Generate CL images + compare all formats
make compare-png       # Compare PNG only

# Parallel variants (all cores; warm-compiles once, then one process per
# example): cl-images-par, gg-images-par, reference-images-par.
# tools/compare.py takes --jobs N (default: all cores).
```

**FASL discipline**: never edit `src/` while an image-generation run is in
flight — a concurrent compile can stamp a fresh FASL from stale source and
later runs will silently load it. Parallel image generation must always
warm-compile first (tools/parallel-images.sh does this).

## Architecture

The codebase is split into 8 layered ASDF systems with a strict dependency chain:

```
cl-matplotlib-foundation   -- cbook utilities, RC params, color database, styles
  -> cl-matplotlib-primitives  -- paths, transforms, bounding boxes, colors, colormaps
    -> cl-matplotlib-rendering -- artist hierarchy, text, fonts, markers, collections, mathtext
      -> cl-matplotlib-backends -- renderer implementations (PNG via Vecto, SVG, PDF via cl-pdf)
        -> cl-matplotlib-containers -- figure, axes, axis, ticks, scales, legends, gridspec, polar
                                   -- also src/algorithms/ (marching squares, streamplot)
                                   -- and src/plotting/ (contour, hexbin, hist, ...)
          -> cl-matplotlib-pyplot   -- procedural API (the user-facing entry point)
          -> ggplot                 -- Grammar of Graphics layer (package nickname `gg`)
          -> cl-matplotlib-show     -- interactive display core (interactor + adapter protocol)
             -> cl-matplotlib-show-web / -sdl2 / -capi  -- display backends
cl-matplotlib              -- meta-system that loads everything
cl-matplotlib-testing      -- SSIM image comparison infrastructure
```

All package definitions live in `src/packages.lisp`, except the `ggplot`
system which owns `src/ggplot/packages.lisp` and the show systems which
own `src/show/**/packages.lisp`. Each system's source is under
`src/<module>/`, tests under `tests/`. The show/ggplot systems are
optional and not referenced by the meta-system; `(pyplot:show)` reaches
the display stack only through `mpl.pyplot:*show-hook*`
(see `docs/interactive.md`).

### ggplot (gg)

`ggplot.asd` implements a plotnine-compatible Grammar of Graphics on top of
the pyplot/containers layers: plots are values built with `gg:ggplot` +
`gg:aes` and composed with the `gg:stack` macro; `gg:ggsave` renders.
Output parity is validated against plotnine references
(`make gg-reference-images gg-images gg-compare-png`, threshold 0.90,
`allowlist-gg.json`); geometry constants in `src/ggplot/render.lisp` are
pixel measurements of plotnine output — check `docs/gg-compat-matrix.md`
before changing them.

### Key Design Patterns

- **pyplot global state**: `*figures*` (hash-table), `*current-figure*`, `*figure-counter*` manage the implicit figure/axes state, mirroring Python matplotlib's pyplot module.
- **RC params**: Runtime configuration via `(rc :key)` and `(with-rc (...) ...)`. Validators defined in `src/foundation/rcsetup.lisp`.
- **Artist protocol**: Abstract `artist` base class in `src/rendering/artist.lisp`; concrete types (Line2D, Patch, PathCollection, Text) implement `draw` methods.
- **Backend protocol**: `renderer-base` in `src/backends/renderer-base.lisp` defines the rendering interface; `backend-vecto.lisp`, `backend-svg.lisp`, `backend-pdf.lisp` implement it.
- **Lazy cross-system calls**: `uiop:symbol-call` used to avoid circular dependencies between ASDF systems.

## CI

GitHub Actions runs all system tests on both SBCL and CCL (see `.github/workflows/ci.yml`).
