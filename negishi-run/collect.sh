#!/bin/bash
# collect.sh: gather records into one tarball to bring back (login node, 1 to 3 minutes).
# Usage: bash negishi-run/collect.sh --run RUN_ID   an episode kit run (submit_all.sh), Prompt 04 on
#        bash negishi-run/collect.sh                the phase-2 records in $PREP_DIR (kept for the record)
# --run writes $KIT_RUNS/varcall-p6-kit-<RUN_ID>-<date>.tar.gz with SUMMARY.md (py/summarize.py),
# placeholder_values.tsv, outputs/ (every placeholder and every block's console output), the
# MultiQC plot exports (PNG), sacct records and the partition's memory per core, the kit-only
# records (bcftools usage text, chr20:88108 counts, filter and MAPQ 0 counts, sentinels, region
# metrics; Prompt 06: trio candidate tables, truth status, inspection sites and their tview text,
# the IGV batch script), small QC outputs (FastQC zips, MultiQC data, samtools and mosdepth
# summaries), the bcftools stats files, the hap.py summaries, extended tables and ROC tables, the
# SnpEff summary and the annotation and trio tables (TSV and text), the IGV snapshots if Part B has
# made them (igv/run_snapshots.sh: PNGs, igv_snapshots.tsv, igv_version.txt and the trimmed
# igv_run.log), learner job logs and kit logs. Never BAM, VCF or FASTQ. Safe to rerun.
# The phase-2 mode tars $PREP_DIR/records only, with the sacct table and its summary, file sizes,
# trimmed logs, the job table, and the filled-in docs/ood_igv_check.md.
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export KIT_DIR

if [ "${1:-}" = --run ]; then
  [ -n "${2:-}" ] || { echo "usage: collect.sh --run RUN_ID" >&2; exit 1; }
  # shellcheck source=negishi-run/kitrun.sh
  source "$KIT_DIR/kitrun.sh"
  RUN=$(kit_run_dir "$2")
  export RUN
  kit_load_run
  NAME=varcall-p6-kit-$RUN_ID-$(date +%Y%m%d-%H%M)
  C=$RUN/collect/$NAME
  mkdir -p "$C"/{records,qc,logs,learner-logs,generated}
  kit_log "collecting $RUN into $C"
  # SLURM accounting for every job of the run, array tasks included (header format of P3)
  ids=$(awk -F'\t' 'NR > 1 && $2 ~ /^[0-9]+$/ { printf "%s%s", s, $2; s = "," }' "$RUN/jobs.tsv" 2>/dev/null || true)
  if [ -n "$ids" ]; then
    sacct -j "$ids" -P --format=JobID,JobName%40,State,Submit,Start,End,Elapsed,AllocCPUS,MaxRSS,TotalCPU,ExitCode \
      > "$RECORDS/sacct.tsv" 2>/dev/null || kit_log "sacct failed; runtimes will be missing"
    KIT_LABEL="episode kit run $RUN_ID" python3 "$KIT_DIR/py/sacct_summary.py" "$RECORDS/sacct.tsv" > "$RECORDS/sacct_summary.tsv" || kit_log "sacct summary failed"
    # the node of each job step, kept apart from sacct.tsv so that its P3 format stays (evaluate.sh MaxRSS by node)
    sacct -j "$ids" -P --format=JobID,NodeList%40 > "$RECORDS/sacct_nodes.tsv" 2>/dev/null || kit_log "sacct NodeList failed"
  fi
  # memory per core of the partition (memory headroom of evaluate.sh in SUMMARY.md): CPUS MEMORY_MB
  sinfo -p "$KIT_PARTITION" -h -o '%c %m' 2>/dev/null | sort -u | head -1 > "$RECORDS/sinfo_cpu.txt" || kit_log "sinfo failed"
  # module versions actually loaded (each pinned module, as the episodes load it)
  for m in "$BWA_MODULE" "$SAMTOOLS_MODULE" "$MOSDEPTH_MODULE" "$FASTQC_MODULE" "$MULTIQC_MODULE" "$BCFTOOLS_MODULE" "$HAPPY_MODULE" "$SNPEFF_MODULE"; do
    printf '%s\t%s\n' "$m" "$( (kit_load "$m" >/dev/null 2>&1 && module -t list 2>&1 | grep -v biocontainers | tr '\n' ' ') || echo 'load failed')"
  done > "$RECORDS/module_versions.tsv"
  (cd "$REPO_DIR" && sha256sum -c "$KIT_GEN/sources.sha256" > "$RECORDS/sources_check.txt" 2>&1) || kit_log "WARN: episodes or learner scripts changed since the kit was built (records/sources_check.txt)"
  python3 "$KIT_DIR/py/summarize.py" "$RUN" "$KIT_GEN" "$C"
  cpq() { local dst=$1 f; shift; mkdir -p "$dst"; for f in "$@"; do if [ -e "$f" ]; then cp -r "$f" "$dst/"; fi; done; return 0; }
  cpq "$C/records" "$RECORDS"/console "$RECORDS"/listings "$RECORDS"/multiqc_export "$RECORDS"/kit-only "$RECORDS"/*.tsv "$RECORDS"/*.txt \
    "$RUN/jobs.tsv" "$RUN/kit.env" "$RUN/markers"
  cpq "$C/qc/qc" "$W"/results/qc/*_fastqc.zip "$W/results/qc/multiqc_data" "$W/results/qc/multiqc_report.html"
  cpq "$C/qc/qc_alignment" "$W"/results/qc_alignment/*.txt "$W/results/qc_alignment/multiqc_data" "$W/results/qc_alignment/multiqc_report.html"
  cpq "$C/qc/bam" "$W"/results/bam/*.markdup.stats.txt
  cpq "$C/qc/vcf" "$W"/results/vcf/*.stats.txt "$W/results/vcf/chunks.txt"
  cpq "$C/qc/eval" "$W"/results/eval/*.summary.csv "$W"/results/eval/*.extended.csv "$W"/results/eval/*.roc.*.csv.gz \
    "$W"/results/eval/*.metrics.json.gz "$W"/results/eval/*.runinfo.json
  cpq "$C/qc/annot" "$W"/results/annot/snpEff_summary.csv "$W"/results/annot/snpEff_summary.genes.txt "$W"/results/annot/*.tsv
  cpq "$C/qc/trio" "$W"/results/trio/*.tsv "$W"/results/trio/*.txt
  cpq "$C/igv" "$RUN"/igv/snapshots.batch "$RUN"/igv/snapshots.bai.batch "$RUN"/igv/snapshots "$KIT_DIR/docs/ood_igv_check.md" \
    "$RECORDS/igv_snapshots.tsv" "$RECORDS/igv_version.txt"
  # IGV console output of igv/run_snapshots.sh, trimmed (the PNGs above are the snapshots themselves)
  if [ -f "$RECORDS/igv_run.log" ] && [ "$(wc -l < "$RECORDS/igv_run.log")" -le 300 ]; then
    cp "$RECORDS/igv_run.log" "$C/igv/"
  elif [ -f "$RECORDS/igv_run.log" ]; then
    { head -n 100 "$RECORDS/igv_run.log"; printf '\n... (trimmed) ...\n\n'; tail -n 200 "$RECORDS/igv_run.log"; } > "$C/igv/igv_run.log"
  fi
  cpq "$C/logs" "$RUN"/logs/*
  cpq "$C/learner-logs" "$W"/scripts/cluster-*
  cpq "$C/generated" "$KIT_GEN"/*.tsv "$KIT_GEN"/*.txt "$KIT_GEN/sources.sha256" "$KIT_GEN/kit.conf"
  TAR=$KIT_RUNS/$NAME.tar.gz
  tar -czf "$TAR" -C "$RUN/collect" "$NAME"
  kit_log "wrote $TAR ($(du -h "$TAR" | cut -f1)); summary: $C/SUMMARY.md"
  kit_log "bring it back to the repository root with:"
  printf 'rsync -avP %s@negishi.rcac.purdue.edu:%s ~/svn/variant-calling/\n' "$(id -un)" "$TAR"
  exit 0
fi
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
