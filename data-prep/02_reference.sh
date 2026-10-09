#!/bin/bash
# 02_reference.sh: submit the reference jobs (login node, seconds).
#   prep-faidx     decompress the analysis-set FASTA, samtools faidx and dict, compare with NCBI's .fai
#   prep-bwaindex  use NCBI's bwa index if 01_fetch.sh found one and it aligns 1,000 read pairs
#                  with the pinned bwa; otherwise build the index (wall time recorded)
# Needs 01_fetch.sh to have finished. Usage: bash data-prep/02_reference.sh [--dry-run] [--force]
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../negishi-run" && pwd)
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
FORCE=0
while [ $# -gt 0 ]; do
  case $1 in --dry-run) DRY=1; shift;; --force) FORCE=1; shift;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; *) kit_die "unknown option $1";; esac
done
export DRY
kit_dirs
J=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jobs
[ "$DRY" = 1 ] || [ -f "$PREP_DIR/src/ref/$(basename "$(src_url ref_fasta)")" ] || kit_die "reference FASTA not downloaded; run 01_fetch.sh first"
for step in prep-faidx prep-bwaindex; do
  if [ $FORCE = 0 ] && kit_step_done "$step"; then kit_log "skip $step (done; --force to rerun)"; continue; fi
  dep=""; [ "$step" = prep-bwaindex ] && dep="prep-faidx"
  kit_submit "$step" "$J/$step.sh" --dep "$dep" --export "KIT_FORCE=$FORCE"
done
