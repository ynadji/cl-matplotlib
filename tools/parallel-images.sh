#!/bin/sh
# Parallel image generation for the visual-comparison pipeline.
#
# Usage: parallel-images.sh base|gg|reference|gg-reference [jobs]
#
# Lisp modes warm-compile the system ONCE first (a single process populates
# the shared ~/.cache/common-lisp FASLs), then fan out one `ros run` per
# example with xargs -P. Without the warm step, N cold workers race to
# compile the same system into the same cache.
#
# Failure detection: `ros run --load` exits 0 even when the Lisp errors
# (debugger EOF), so Lisp examples are judged by whether they refreshed
# their own <name>.png after the run started; Python reference scripts are
# judged by exit code. Failures are listed and the script exits nonzero
# (the serial Makefile loops only print WARNING).
set -eu

MODE=${1:?usage: parallel-images.sh base|gg|reference|gg-reference [jobs]}
JOBS=${2:-$(nproc)}

case "$MODE" in
  base)       GLOB="examples/*.lisp";           WARM=":cl-matplotlib-pyplot" ;;
  gg)         GLOB="examples/gg/*.lisp";        WARM=":ggplot" ;;
  reference)  GLOB="reference_scripts/*.py";    WARM="" ;;
  gg-reference) GLOB="reference_scripts/gg/*.py"; WARM="" ;;
  *) echo "unknown mode: $MODE" >&2; exit 2 ;;
esac

if [ -n "$WARM" ]; then
  echo "Warm-compiling $WARM..."
  ros run -- \
    --eval "(handler-case (progn (require :asdf) (asdf:load-system $WARM)) (serious-condition (e) (format *error-output* \"~&WARM-COMPILE FAILED: ~A~%\" e) (uiop:quit 1)))" \
    --quit
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
FAILLOG="$WORKDIR/failures"
: > "$FAILLOG"
STAMP="$WORKDIR/stamp"
touch "$STAMP"
export FAILLOG STAMP MODE

echo "Generating images ($MODE, $JOBS jobs)..."
# shellcheck disable=SC2086
ls $GLOB | xargs -P "$JOBS" -I{} sh -c '
  f={}
  case "$MODE" in
    base|gg)
      ros run -- --load "$f" --quit >/dev/null 2>&1 || true
      png="${f%.lisp}.png"
      # success = the example refreshed its own png after the stamp
      if [ ! -f "$png" ] || [ "$png" -ot "$STAMP" ]; then
        echo "$f" >> "$FAILLOG"
      fi
      ;;
    *)
      .venv/bin/python "$f" >/dev/null 2>&1 || echo "$f" >> "$FAILLOG"
      ;;
  esac
'

if [ -s "$FAILLOG" ]; then
  echo "FAILED examples:" >&2
  sort "$FAILLOG" >&2
  exit 1
fi
echo "All $MODE images generated."
