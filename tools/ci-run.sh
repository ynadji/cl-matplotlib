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
# On failure print the condition text (with *print-readably* off — ASDF's
# test-op can leave it on, which turns the message into "cannot be printed
# readably") and a backtrace, so the log names the failing call.
exec ros run \
  --eval "(handler-case $FORM (serious-condition (e) (let ((*print-readably* nil)) (format *error-output* \"~&CI FAILED: ~A~%\" e) (uiop:print-condition-backtrace e :stream *error-output*)) (uiop:quit 1)))" \
  --quit
