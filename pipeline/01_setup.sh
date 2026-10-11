#!/bin/bash
# 01_setup.sh: start a reference run with the Episode 2 setup block, exactly as a learner types
# it, on the login node, into a fresh learner copy (copy q0). About 5 minutes for about 6 GB.
# Usage: bash pipeline/01_setup.sh [RUN_ID]     (default RUN_ID: ref-YYYY-MM-DD-HHMM)
# Before running the block it checks that the block copies from STAGED and links STAGED_REF (as
# set in config.sh), that both staged copies pass check_staged.sh --quick, and that the staged
# scripts/ are the learner scripts in this checkout. After it: the copy has every FASTQ and the
# reference links resolve. Next: bash pipeline/run_reference.sh --run RUN_ID
set -euo pipefail
RUN_ID=${1:-ref-$(date +%Y-%m-%d-%H%M)}
export RUN_ID
PIPE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PIPE_DIR
# shellcheck source=pipeline/lib.sh
source "$PIPE_DIR/lib.sh"

if kit_is_done setup 2>/dev/null; then kit_log "run $RUN_ID already set up; nothing to do"; exit 0; fi
B=$LS/interactive/02-setup.sh
grep -qF "rsync -av $STAGED/ " "$B" || kit_die "$B does not copy from STAGED=$STAGED"
grep -qF "ln -s $STAGED_REF/* ref/" "$B" || kit_die "$B does not link STAGED_REF=$STAGED_REF"
bash "$KIT_DIR/check_staged.sh" "$STAGED" --quick > /dev/null || kit_die "staged copy $STAGED fails check_staged.sh; run it to see why"
bash "$KIT_DIR/check_staged.sh" --ref --quick > /dev/null || kit_die "staged copy $STAGED_REF fails check_staged.sh --ref"
for f in "$LS"/*.sh; do
  cmp -s "$f" "$STAGED/scripts/$(basename "$f")" || kit_die "$STAGED/scripts/$(basename "$f") differs from $f; run restage.sh --scripts"
done

kit_dirs
mkdir -p "$(copy_scratch q0)" "$RECORDS/listings"
kit_marker setup RUNNING
t0=$(date +%s)
run_block 02-setup "$B" q0 || { kit_marker setup FAIL; kit_die "setup block failed; see $RECORDS/console/session-02-setup.log"; }
secs=$(( $(date +%s) - t0 ))
W=$(work_dir q0)
n=$(find "$W/data" -maxdepth 1 -name '*.fastq.gz' | wc -l)
[ "$n" = $(( 2 * $(wc -w <<< "$SAMPLES") )) ] || kit_die "learner copy has $n FASTQ files"
bad=$(find "$W/ref" -maxdepth 1 -xtype l)
[ -z "$bad" ] || kit_die "broken reference links: $bad"
grep -c ': OK$' "$RECORDS/console/session-02-setup.log" > "$RECORDS/listings/setup-md5-ok.txt" || true
printf 'setup block seconds\t%s\n' "$secs" > "$RECORDS/listings/setup-seconds.tsv"
du -sh "$W" > "$RECORDS/listings/setup-du.txt"
( cd "$W" && find . -maxdepth 2 | sort ) > "$RECORDS/listings/setup-tree.txt"
kit_metric setup q0 wall_s_setup_block "$secs" s
kit_marker setup PASS
kit_log "setup done in ${secs}s. Next: bash $PIPE_DIR/run_reference.sh --run $RUN_ID"
