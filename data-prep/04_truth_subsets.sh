#!/bin/bash
# 04_truth_subsets.sh: submit prep-truth (login node, seconds). The job cuts every benchmark
# VCF and BED to the region, counts variants per sample and version, writes
# truth/truth_sets.tsv for the pilot evaluation, and saves the README passages on
# Mendelian-inconsistent and de novo sites. Needs 01_fetch.sh.
# Usage: bash data-prep/04_truth_subsets.sh [--dry-run] [--force]
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
if [ $FORCE = 0 ] && kit_step_done prep-truth; then kit_log "skip prep-truth (done; --force to rerun)"; exit 0; fi
kit_submit prep-truth "$J/prep-truth.sh" --export "KIT_FORCE=$FORCE"
