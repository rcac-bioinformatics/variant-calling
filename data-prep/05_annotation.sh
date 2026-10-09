#!/bin/bash
# 05_annotation.sh: SnpEff GRCh38 databases and a gnomAD allele-frequency subset.
# Downloads run on the login node unless preflight found that compute nodes reach the internet
# (or --fetch-on compute is given); the gnomAD processing always runs in the prep-annot job.
# Usage: bash data-prep/05_annotation.sh [--dry-run] [--force] [--fetch-on auto|login|compute]
# The gnomAD chr20 file is about 11.8 GB; on the login node, run this in tmux or screen.
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../negishi-run" && pwd)
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
FORCE=0; FETCH_ON=auto
while [ $# -gt 0 ]; do
  case $1 in --dry-run) DRY=1; shift;; --force) FORCE=1; shift;; --fetch-on) FETCH_ON=$2; shift 2;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; *) kit_die "unknown option $1";; esac
done
export DRY FORCE
kit_dirs
mkdir -p "$RECORDS/annot"
if [ "$FETCH_ON" = auto ]; then
  FETCH_ON=login
  if [ -f "$STATE/egress.env" ]; then
    # shellcheck source=/dev/null
    source "$STATE/egress.env"
    [ "${COMPUTE_INTERNET:-no}" = yes ] && FETCH_ON=compute
  fi
fi
case $FETCH_ON in login|compute) ;; *) kit_die "--fetch-on must be auto, login, or compute";; esac
kit_log "downloads run on the $FETCH_ON node"
if [ $FORCE = 0 ] && kit_step_done prep-annot; then kit_log "skip prep-annot (done; --force to rerun)"; exit 0; fi

if [ "$FETCH_ON" = login ]; then
  ROWS_TSV=$RECORDS/annot/fetch.tsv
  annot_dest() { echo "$PREP_DIR/src/annot/$(basename "$(src_url "$1")")"; }
  KIT_DEST_FN=annot_dest
  kit_fetch gnomad_chr20_vcf
  kit_fetch gnomad_chr20_tbi
  if [ "$DRY" = 1 ]; then
    printf '  + module load biocontainers %s; snpEff databases; snpEff download -dataDir %s <MANE and full GRCh38 databases>\n' "$SNPEFF_MODULE" "$PREP_DIR/annot/snpeff_data" >&2
  else
    [ "$NFAIL" -eq 0 ] || kit_die "gnomAD download failed; see $ROWS_TSV"
    kit_load "$SNPEFF_MODULE"
    # shellcheck source=data-prep/snpeff_lib.sh
    source "$HERE/snpeff_lib.sh"
    snpeff_pick
    KIT_FORCE=$FORCE snpeff_download
  fi
fi
kit_submit prep-annot "$HERE/jobs/prep-annot.sh" --export "KIT_FORCE=$FORCE,FETCH_ON=$FETCH_ON"
