#!/bin/bash
# 03_bam_to_fastq.sh: submit prep-fastq, a SLURM array over the three samples (login node, seconds).
# Each task first records facts about its source BAM (flagstat, stats, duplicate and QC-fail
# counts, mates outside the region, read groups, header vs reference .fai, depth), then converts
# it to paired FASTQ with samtools collate and samtools fastq (singletons dropped) and records
# read counts and md5 sums. Needs 01_fetch.sh. Usage: bash data-prep/03_bam_to_fastq.sh [--dry-run] [--force]
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../negishi-run" && pwd)
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
FORCE=0
while [ $# -gt 0 ]; do
  case $1 in --dry-run) DRY=1; shift;; --force) FORCE=1; shift;;
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; *) kit_die "unknown option $1";; esac
done
export DRY
kit_dirs
J=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jobs
n=$(wc -w <<< "$SAMPLES")
if [ $FORCE = 0 ] && kit_step_done prep-fastq; then kit_log "skip prep-fastq (done; --force to rerun)"; exit 0; fi
kit_submit prep-fastq "$J/prep-fastq.sh" --array "1-$n" --export "KIT_FORCE=$FORCE"
