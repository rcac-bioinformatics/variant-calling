#!/bin/bash
# collect.sh: tar the records of one reference run (login node, about a minute).
# Usage: bash pipeline/collect.sh --run RUN_ID
# Records only, never BAM, VCF or FASTQ: the run's records/ (console logs of every interactive
# block, metrics, hap.py summaries and ROC tables, annotation and trio tables, determinism,
# draft anchors, sentinels), the job table and sacct, trimmed kit logs and learner job logs
# (cluster-*.out/err), preflight and staging records from PREP_DIR/records, and the staged
# manifests. Prints the rsync command that brings the tarball back.
set -euo pipefail
RUN_ID=""
while [ $# -gt 0 ]; do
  case $1 in --run) RUN_ID=$2; shift 2;; -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; *) echo "unknown option $1" >&2; exit 1;; esac
done
[ -n "$RUN_ID" ] || { echo "--run RUN_ID is required" >&2; exit 1; }
export RUN_ID
PIPE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PIPE_DIR
# shellcheck source=pipeline/lib.sh
source "$PIPE_DIR/lib.sh"
[ -d "$RECORDS" ] || kit_die "no records at $RECORDS"
P2REC=$PREP_DIR/records

# ---- SLURM accounting for every job of the run
if [ -f "$STATE/jobs.tsv" ]; then
  cp "$STATE/jobs.tsv" "$RECORDS/jobs.tsv"
  ids=$(awk -F'\t' 'NR > 1 && $2 ~ /^[0-9]+$/ { printf "%s%s", s, $2; s = "," }' "$STATE/jobs.tsv")
  if [ -n "$ids" ]; then
    sacct -j "$ids" -P --format=JobID,JobName%40,State,Submit,Start,End,Elapsed,AllocCPUS,MaxRSS,TotalCPU,ExitCode \
      > "$RECORDS/sacct.tsv" 2>/dev/null || kit_log "sacct failed; runtimes will be missing"
    python3 "$KIT_DIR/py/sacct_summary.py" "$RECORDS/sacct.tsv" > "$RECORDS/sacct_summary.tsv" || kit_log "sacct summary failed"
  fi
fi

# ---- markers, trimmed logs (kit jobs and learner jobs), preflight, staging, manifests
mkdir -p "$RECORDS/markers" "$RECORDS/logs_trimmed" "$RECORDS/learner_logs" "$RECORDS/phase2" "$RECORDS/manifests"
cp "$STATE"/markers/*.done "$RECORDS/markers/" 2>/dev/null || true
trim() { { head -n 60 "$1"; printf '\n... (trimmed) ...\n\n'; tail -n 200 "$1"; } > "$2"; }
for f in "$LOGS"/*; do [ -f "$f" ] && trim "$f" "$RECORDS/logs_trimmed/$(basename "$f")"; done
for cs in $COPIES det; do
  for f in "$(work_dir "$cs")"/scripts/cluster-*; do [ -f "$f" ] && trim "$f" "$RECORDS/learner_logs/$cs.$(basename "$f")"; done
done
for f in preflight.tsv preflight_summary.txt; do [ -f "$P2REC/$f" ] && cp "$P2REC/$f" "$RECORDS/phase2/"; done
[ -d "$P2REC/preflight" ] && cp -r "$P2REC/preflight" "$RECORDS/phase2/"
[ -d "$P2REC/stage" ] && cp -r "$P2REC/stage" "$RECORDS/phase2/"
cp "$KIT_DIR"/staged_*manifest.tsv "$RECORDS/manifests/" 2>/dev/null || true
cp "$KIT_DIR/config.sh" "$RECORDS/config.sh.used"
printf 'collected %s by %s on %s, run %s\n' "$(kit_ts)" "$(id -un)" "$(hostname)" "$RUN_ID" > "$RECORDS/COLLECTED.txt"

NAME=varcall-p3-records-$RUN_ID-$(date +%Y%m%d-%H%M)
TAR=$RUN/$NAME.tar.gz
tar -czf "$TAR" -C "$RUN" --transform "s#^records#$NAME#" records
kit_log "wrote $TAR ($(du -h "$TAR" | cut -f1))"
kit_log "bring it back to the repository root with:"
printf 'rsync -avP %s@negishi.rcac.purdue.edu:%s ~/svn/variant-calling/\n' "$(id -un)" "$TAR"
