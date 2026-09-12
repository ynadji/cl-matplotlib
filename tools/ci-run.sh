#!/bin/sh
# CI helper: load (and optionally test) an ASDF system, exiting nonzero on failure.
# `ros run --eval` drops into the debugger on error and exits 0 at EOF, so any
# failure must be trapped in Lisp and turned into an explicit uiop:quit.
#
# Usage: ci-run.sh <system> [--test]
set -eu
SYSTEM=$1
MODE=${2:-load}
if [ "$MODE" = "--test" ]; then
  FORM="(progn (ql:quickload :$SYSTEM) (asdf:test-system :$SYSTEM))"
else
  FORM="(ql:quickload :$SYSTEM)"
fi
# Failure reporting. handler-bind (not handler-case) so the backtrace is taken
# where the condition was signaled, not after unwinding. *print-readably* is
# bound off: under a readably-T context an error whose report mentions an
# unreadable object (e.g. "no applicable method for #<GF ...>") turns into a
# PRINT-NOT-READABLE inside FiveAM's own reporting and aborts the whole run
# with a useless "#<...> cannot be printed readably" — when that still
# happens, unwrap it and print the condition it was trying to print.
REPORT='(lambda (e) (let ((*print-readably* nil)) (when (typep e (quote print-not-readable)) (setf e (print-not-readable-object e))) (format *error-output* "~&CI FAILED: ~A~%" e) (uiop:print-backtrace :stream *error-output* :count 40)) (uiop:quit 1))'
exec ros run \
  --eval "(let ((*print-readably* nil)) (handler-bind ((serious-condition $REPORT)) $FORM))" \
  --quit
