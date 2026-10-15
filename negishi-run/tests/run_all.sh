#!/bin/bash
# run_all.sh: the kit's pre-merge tests, on a laptop or a Negishi login node (about 1-2 minutes;
# needs bash, python3 and rsync; no SLURM, no containers, no data).
# Usage: bash negishi-run/tests/run_all.sh
#   1. mutate_kit.sh     edits to the lesson and the kit that build_kit.py --check must catch
#   2. submit_guard.sh   submit_all.sh refuses a shell with SINGULARITY_BIND or APPTAINER_BIND
#   3. igv_stubs.sh      igv/run_snapshots.sh against stubbed SLURM, Apptainer, xvfb-run and IGV
# Everything is written to a new temporary directory, removed at the end (kept with KEEP_WORK=1).
# Exit 0 only if every suite passes.
set -u
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/varcall-kit-tests.XXXXXX") || exit 1
export REPO WORK
cleanup() { if [ "${KEEP_WORK:-0}" = 1 ]; then echo "work directory kept: $WORK"; else rm -rf "$WORK"; fi; }
trap cleanup EXIT
D=$REPO/negishi-run/tests
fail=0
for t in mutate_kit.sh submit_guard.sh igv_stubs.sh; do
  echo "=== $t"
  start=$SECONDS
  if bash "$D/$t" > "$WORK/$t.log" 2>&1; then r=PASS; else r=FAIL; fail=$((fail + 1)); fi
  if [ $r = FAIL ] || [ "${VERBOSE:-0}" = 1 ]; then cat "$WORK/$t.log"; else grep -E 'NOT APPLIED|MISSED|SKIPPED|FAILED' "$WORK/$t.log"; tail -1 "$WORK/$t.log"; fi
  echo "--- $t: $r ($((SECONDS - start)) s)"
done
if [ $fail -eq 0 ]; then echo "run_all: all 3 suites pass"; else echo "run_all: $fail of 3 suites FAIL"; fi
[ $fail -eq 0 ]
