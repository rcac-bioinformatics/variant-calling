#!/bin/bash
# collect.sh: gather the phase-2 records into one tarball to bring back (login node, about a minute).
# Usage: bash negishi-run/collect.sh
# Tars $PREP_DIR/records only: never BAM, VCF or FASTQ. Adds the sacct table and its summary,
# file sizes, trimmed logs, the job table, and the filled-in docs/ood_igv_check.md.
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
[ -d "$RECORDS" ] || kit_die "no records at $RECORDS"

# ---- SLURM accounting for every job submitted (array tasks and steps included)
if [ -f "$STATE/jobs.tsv" ]; then
  cp "$STATE/jobs.tsv" "$RECORDS/jobs.tsv"
  ids=$(awk -F'\t' 'NR > 1 && $2 ~ /^[0-9]+$/ { printf "%s%s", s, $2; s = "," }' "$STATE/jobs.tsv")
  if [ -n "$ids" ]; then
    sacct -j "$ids" -P --format=JobID,JobName%40,State,Submit,Start,End,Elapsed,AllocCPUS,MaxRSS,TotalCPU,ExitCode \
      > "$RECORDS/sacct.tsv" 2>/dev/null || kit_log "sacct failed; runtimes will be missing"
    python3 "$KIT_DIR/py/sacct_summary.py" "$RECORDS/sacct.tsv" > "$RECORDS/sacct_summary.tsv" || kit_log "sacct summary failed"
  fi
fi

# ---- markers, sizes, trimmed logs, OOD/IGV note
mkdir -p "$RECORDS/markers" "$RECORDS/logs_trimmed"
cp "$STATE"/markers/*.done "$RECORDS/markers/" 2>/dev/null || true
cp "$STATE"/*.env "$RECORDS/markers/" 2>/dev/null || true
{ printf 'bytes\tpath\n'
  find "$PREP_DIR" -path "$RECORDS" -prune -o -path "$PREP_DIR/tmp" -prune -o -type f -size +1M -printf '%s\t%P\n' | sort -k2
} > "$RECORDS/sizes.tsv"
du -sb "$PREP_DIR"/* 2>/dev/null | sed "s#$PREP_DIR/##" > "$RECORDS/sizes_by_dir.tsv" || true
for f in "$LOGS"/*; do
  [ -f "$f" ] || continue
  { head -n 50 "$f"; printf '\n... (trimmed) ...\n\n'; tail -n 150 "$f"; } > "$RECORDS/logs_trimmed/$(basename "$f")"
done
cp "$KIT_DIR/docs/ood_igv_check.md" "$RECORDS/"
cp "$KIT_DIR/config.sh" "$RECORDS/config.sh.used"
printf 'collected %s by %s on %s\n' "$(kit_ts)" "$(id -un)" "$(hostname)" > "$RECORDS/COLLECTED.txt"

NAME=varcall-p2-records-$(date +%Y%m%d-%H%M)
TAR=$PREP_DIR/$NAME.tar.gz
tar -czf "$TAR" -C "$PREP_DIR" --transform "s#^records#$NAME#" records
kit_log "wrote $TAR ($(du -h "$TAR" | cut -f1))"
kit_log "bring it back to the repository root with:"
printf 'rsync -avP %s@negishi.rcac.purdue.edu:%s ~/svn/variant-calling/\n' "$(id -un)" "$TAR"
