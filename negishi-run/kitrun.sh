# negishi-run/kitrun.sh: helpers for the episode run kit (Prompt 04): submit_all.sh, the generated
# jobs in generated/jobs/ and collect.sh --run. Sourced, never executed. Needs RUN for every helper
# that works inside a run; submit_all.sh exports it to the jobs.
# A run lives in $KIT_RUNS/<RUN_ID>/ (config.sh): scratch/ is the learner's $SCRATCH (so the
# learner directory is scratch/varcall-workshop), home/ the directory a learner shell starts in,
# records/ what collect.sh brings back, markers/ step status, logs/ job and session logs.
# shellcheck shell=bash

KIT_DIR=${KIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
KIT_GEN=${KIT_GEN:-$KIT_DIR/generated}
export KIT_GEN KIT_RUNS

kit_run_dir() {  # RUN_ID or absolute path -> run directory
  case "$1" in /*) echo "$1";; *) echo "$KIT_RUNS/$1";; esac
}

# Refuse a run directory inside a staged copy, on Depot, or outside KIT_RUNS
kit_guard_run() {  # dir
  local r; r=$(readlink -m "$1")
  case "$r" in
    "$(readlink -m "$STAGED")"|"$(readlink -m "$STAGED")"/*|"$(readlink -m "$STAGED_REF")"/*|"$(readlink -m "$STAGED_RESULTS")"/*|/depot/*)
      kit_die "run directory $1 is inside a staged copy or on Depot";;
  esac
  case "$r" in
    "$(readlink -m "$KIT_RUNS")"/*) ;;
    *) [ "${KIT_ALLOW_ANY_ROOT:-0}" = 1 ] || kit_die "run directory $1 is not under KIT_RUNS=$KIT_RUNS";;
  esac
}

kit_init_run() {  # dir: a fresh run with its kit.env
  local run=$1
  kit_guard_run "$run"
  [ -e "$run/kit.env" ] && kit_die "$run already exists; use another RUN_ID"
  mkdir -p "$run"/{scratch,home,logs,markers,records/console,records/listings,records/multiqc_export}
  {
    printf 'RUN=%q\n' "$run"
    printf 'RUN_ID=%q\n' "$(basename "$run")"
    printf 'KIT_LEARNER_SCRATCH=%q\n' "$run/scratch"
    printf 'W=%q\n' "$run/scratch/varcall-workshop"
    printf 'KIT_HOME=%q\n' "$run/home"
    printf 'KIT_BUILT_FROM=%q\n' "$(sha256sum "$KIT_GEN/sources.sha256" | cut -c1-16)"
    printf 'KIT_STARTED=%q\n' "$(kit_ts)"
  } > "$run/kit.env"
}

kit_load_run() {
  : "${RUN:?RUN is not set}"
  [ -f "$RUN/kit.env" ] || kit_die "$RUN/kit.env is missing; start the run with submit_all.sh --run RUN_ID"
  # shellcheck source=/dev/null
  source "$RUN/kit.env"
  kit_guard_run "$RUN"
  # lib.sh's markers, records and logs live in the run, not in the phase-2 prep directory
  STATE=$RUN; RECORDS=$RUN/records; LOGS=$RUN/logs
  export RUN RUN_ID W KIT_LEARNER_SCRATCH KIT_HOME STATE RECORDS LOGS
}

# Done: a PASS marker. The learner's scripts write none, so their last outputs must exist and be
# newer than the run: align.sh the three BAM indexes, call.sh the eight chunk indexes (-W),
# evaluate.sh one summary.csv per task and call set (4 tasks x norm, filtered).
kit_ep_done() {  # step
  local s n
  case $1 in
    04-align)
      for s in $SAMPLES; do
        [ -s "$W/results/bam/$s.markdup.bam.csi" ] && [ "$W/results/bam/$s.markdup.bam.csi" -nt "$RUN/kit.env" ] || return 1
      done;;
    05a-call)
      for n in 01 02 03 04 05 06 07 08; do
        [ -s "$W/results/vcf/chunks/chunk$n.bcf.csi" ] && [ "$W/results/vcf/chunks/chunk$n.bcf.csi" -nt "$RUN/kit.env" ] || return 1
      done;;
    06-evaluate)
      [ -d "$W/results/eval" ] || return 1
      n=$(find "$W/results/eval" -maxdepth 1 -name '*.summary.csv' -newer "$RUN/kit.env" | wc -l)
      [ "$n" -ge 8 ];;
    *) kit_is_done "$1";;
  esac
}

# Run a generated learner session in a child bash without -e, -u or pipefail, starting in the
# run's home/ as a fresh login would, with SCRATCH pointing at the run. Fails if any command failed.
kit_ep_session() {  # step
  local step=$1 log rc=0 nerr
  log=$LOGS/session-$step.${SLURM_JOB_ID:-login}.log
  kit_log "session $step: $KIT_GEN/sessions/$step.sh -> $log"
  ( cd "$KIT_HOME" && export SCRATCH="$KIT_LEARNER_SCRATCH" && bash --noprofile --norc "$KIT_GEN/sessions/$step.sh" ) > "$log" 2>&1 || rc=$?
  cp "$log" "$RECORDS/console/$step.log"
  nerr=$(grep -c '^### KIT-ERR' "$log" || true)
  if [ "$rc" -ne 0 ] || [ "$nerr" -gt 0 ]; then
    kit_log "session $step: exit $rc, $nerr failed command(s); first: $(grep -m1 '^### KIT-ERR' "$log" || true)"
    return 1
  fi
}

kit_ep_on_exit() {
  local rc=$?
  if [ "$rc" -ne 0 ] && [ -n "${KIT_EP_STEP:-}" ]; then kit_marker "$KIT_EP_STEP" FAIL; kit_log "step $KIT_EP_STEP FAILED (exit $rc)"; fi
}
kit_ep_begin() {  # step (in a generated job)
  kit_load_run
  KIT_EP_STEP=$1
  trap kit_ep_on_exit EXIT
  kit_marker "$1" RUNNING
  kit_log "step $1 begin: job ${SLURM_JOB_ID:-none} on $(hostname), ${SLURM_NTASKS:-?} tasks"
}
kit_ep_end() {
  kit_marker "$1" PASS
  KIT_EP_STEP=""
  kit_log "step $1 end: PASS"
}

# KIT EXTRA: MultiQC plot export (PNG) into the run's records, never into the learner directory.
# A failure is recorded as WARN and does not fail the step.
kit_multiqc_export() {  # step dir...
  local step=$1 out; shift
  out=$RECORDS/multiqc_export/$step
  mkdir -p "$out"
  if ( kit_load "$MULTIQC_MODULE" && cd "$W" && multiqc --export -f -o "$out" "$@" ) > "$out.log" 2>&1; then
    printf 'PASS\t%s\n' "$(find "$out" -name '*.png' | wc -l) png" > "$out.status"
  else
    printf 'WARN\tmultiqc export failed; see %s\n' "$out.log" > "$out.status"
    kit_log "WARN: MultiQC export for $step failed (see $out.log)"
  fi
}

# ---------------------------------------------------------------- kit-only records (Prompt 05)
# KIT EXTRA: records that no learner command produces. Each reads the learner directory, writes
# only to $RECORDS/kit-only/, runs in a subshell with its own module loads, and never fails the
# step: a failure is logged as WARN in $RECORDS/kit-only/status.tsv. docs/ADAPTATIONS.md lists them.
kit_only_warn() {  # name message
  mkdir -p "$RECORDS/kit-only"
  printf 'WARN\t%s\t%s\n' "$1" "$2" >> "$RECORDS/kit-only/status.tsv"
  kit_log "WARN: kit-only record $1: $2"
}

# Episode 4, correction 4 (P4 review): what the 1,054,357 records with MAPQ 0 are, against the
# 983,436 "reads MQ0" of samtools stats
kit_mapq0_counts() {
  local o=$RECORDS/kit-only/mapq0_counts.tsv
  mkdir -p "$RECORDS/kit-only"
  if ! ( set +e
         kit_load "$SAMTOOLS_MODULE" > /dev/null 2>&1
         b=$W/results/bam/HG002.markdup.bam
         printf 'what\tsamtools view options\tcount\n'
         for x in "all records, MAPQ 0 (the Episode 4 command)|-e mapq==0" \
                  "primary mapped, MAPQ 0|-F 0x904 -e mapq==0" \
                  "unmapped, MAPQ 0|-f 0x4 -e mapq==0" \
                  "supplementary, MAPQ 0|-f 0x800 -e mapq==0" \
                  "secondary, MAPQ 0|-f 0x100 -e mapq==0" \
                  "unmapped, any MAPQ|-f 0x4" \
                  "supplementary, any MAPQ|-f 0x800"; do
           # shellcheck disable=SC2086  # the options are split on purpose
           printf '%s\t%s\t%s\n' "${x%%|*}" "${x#*|}" "$(samtools view -c ${x#*|} "$b" 2>&1)"
         done ) > "$o" 2> "$o.err"; then
    kit_only_warn mapq0_counts "see $o.err"
  fi
}

# Episode 5A: the bcftools 1.24 usage text, the source of every default the episodes quote
kit_bcftools_usage() {
  local d=$RECORDS/kit-only/usage c
  mkdir -p "$d"
  if ! ( set +e
         kit_load "$BCFTOOLS_MODULE" > /dev/null 2>&1
         bcftools --version > "$d/bcftools-version.txt" 2>&1
         bcftools mpileup > "$d/bcftools-mpileup.txt" 2>&1
         for c in call filter norm concat view query stats; do
           bcftools "$c" --help > "$d/bcftools-$c.txt" 2>&1 < /dev/null
         done
         grep -q 'Usage' "$d/bcftools-mpileup.txt" ); then
    kit_only_warn bcftools_usage "no usage text recorded; see $d"
  fi
}

# Episode 5A: HG002 at chr20:88108 (and 85259). Episode 4's tview column shows 39 reads; each row
# below adds one of mpileup's default read or base filters, so the rows separate the causes of the
# difference with the VCF's AD and DP: duplicates (--ns), anomalous pairs (-A), overlapping mates
# (-x), the base-quality floor (-Q) and BAQ (-B). Then the VCF records themselves.
kit_site_counts() {
  local o=$RECORDS/kit-only/site_88108.tsv TAB=$'\t'
  mkdir -p "$RECORDS/kit-only"
  if ! ( set +e
         kit_load "$BCFTOOLS_MODULE" > /dev/null 2>&1
         cd "$W" || exit 1
         B=results/bam/HG002.markdup.bam; R=ref/GRCh38_no_alt.fa; P=chr20:88108
         printf 'row\tmpileup options\tAD\tDP\n'
         for x in "all|--ns UNMAP,SECONDARY,QCFAIL -A -x -Q 0 -B" "nodup|-A -x -Q 0 -B" "proper|-x -Q 0 -B" \
                  "overlap|-Q 0 -B" "bq|-B" "default|"; do
           # shellcheck disable=SC2086  # the options are split on purpose
           v=$(bcftools mpileup -f "$R" -r "$P" -a AD,DP ${x#*|} "$B" 2> /dev/null | bcftools query -f '[%AD\t%DP]\n' 2> /dev/null)
           printf '%s\t%s\t%s\n' "${x%%|*}" "${x#*|}" "${v:-FAILED${TAB}FAILED}"
         done
         printf '#vcf\tposition\tQUAL INFO/DP then per sample: SAMPLE GT AD DP PL GQ\n'
         for p in 88108 85259; do
           printf 'vcf\tchr20:%s\t%s\n' "$p" "$(bcftools query -r "chr20:$p" -f '%QUAL\t%INFO/DP[\t%SAMPLE\t%GT\t%AD\t%DP\t%PL\t%GQ]\n' results/vcf/trio.norm.vcf.gz 2> /dev/null)"
         done
         kit_load "$SAMTOOLS_MODULE" > /dev/null 2>&1
         printf '#samtools\tview options at chr20:88108\tcount\n'
         for x in "all records|" "duplicates|-f 0x400" "not duplicates|-F 0x400" \
                  "paired, not proper, not duplicates|-f 0x1 -F 0x402" "MAPQ 0, not duplicates|-F 0x400 -e mapq==0"; do
           # shellcheck disable=SC2086
           printf 'samtools\t%s (%s)\t%s\n' "${x%%|*}" "${x#*|}" "$(samtools view -c ${x#*|} "$B" chr20:88108-88108 2>&1)"
         done ) > "$o" 2> "$o.err"; then
    kit_only_warn site_counts "see $o.err"
  fi
}

# Episode 6: what the filters changed (FILTER values, records, missing genotypes per sample, the
# reasons for the mask), the sentinels against anchors.tsv, and the reference run's region metrics
# (pipeline/py/metrics.py, as in P3) for the HG002 PASS Ts/Tv anchors
kit_filter_counts() {
  local d=$RECORDS/kit-only TAB=$'\t'
  mkdir -p "$d"
  if ! ( set +e
         kit_load "$BCFTOOLS_MODULE" > /dev/null 2>&1
         cd "$W" || exit 1
         N=results/vcf/trio.norm.vcf.gz; F=results/vcf/trio.filtered.vcf.gz
         { printf 'what\tnorm\tfiltered\n'
           printf 'records\t%s\t%s\n' "$(bcftools view -H $N 2> /dev/null | wc -l)" "$(bcftools view -H $F 2> /dev/null | wc -l)"
           for f in PASS LowQual HighDP LowMQ; do
             printf 'FILTER contains %s\t%s\t%s\n' "$f" "$(bcftools view -H -i "FILTER~\"$f\"" $N 2> /dev/null | wc -l)" "$(bcftools view -H -i "FILTER~\"$f\"" $F 2> /dev/null | wc -l)"
           done
         } > "$d/filter_counts.tsv"
         for x in norm:$N filtered:$F; do
           bcftools query -f '%FILTER\n' "${x#*:}" 2> /dev/null | sort | uniq -c > "$d/filter_values.${x%%:*}.txt"
           bcftools stats -s - "${x#*:}" 2> /dev/null | grep -E '^(# )?PSC' > "$d/psc.${x%%:*}.txt"
           bcftools query -f '[%SAMPLE\t%GT\n]' "${x#*:}" 2> /dev/null | awk -F'\t' '$2 == "./." || $2 == "." { n[$1]++ } END { for (s in n) print s "\t" n[s] }' | sort > "$d/missing_gt.${x%%:*}.tsv"
         done
         # why each genotype was masked (unfiltered calls): low DP only, low GQ only, both
         bcftools query -f '[%SAMPLE\t%GT\t%DP\t%GQ\n]' $N 2> /dev/null | awk -F'\t' '
           $2 != "./." && $2 != "." { lowdp = ($3 == "." || $3 < 10); lowgq = ($4 == "." || $4 < 20)
             if (lowdp && lowgq) b[$1]++; else if (lowdp) d[$1]++; else if (lowgq) g[$1]++ }
           END { print "sample\tDP<10 only\tGQ<20 only\tboth"; for (s in d) print s "\t" d[s] + 0 "\t" g[s] + 0 "\t" b[s] + 0 }' > "$d/mask_reasons.tsv"
         # sentinels (anchors.tsv): FILTER and HG002 GT in the filtered calls, truth GT in HG002 v5.0q and v4.2.1
         printf 'role\tposition\tREF>ALT\tFILTER\tHG002 GT\tv5.0q GT\tv4.2.1 GT\n' > "$d/sentinels.tsv"
         for x in het_snv:88108 homalt_snv:85259 indel:86859 trio_inconsistent:338577 artifact:29070822; do
           p=${x#*:}
           r=$(bcftools query -r "chr20:$p" -i "POS=$p" -f '%REF>%ALT\t%FILTER[\t%GT]\n' -s HG002 $F 2> /dev/null | head -1)
           # truth: "outside" if the position is outside the benchmark BED (the truth VCF also lists
           # variants outside its benchmark regions), "absent" if inside with no truth record, else the GT
           for v in v5.0q v4.2.1; do
             t=outside
             if awk -v p="$p" '$1 == "chr20" && $2 < p && p <= $3 { f = 1; exit } END { exit !f }' "resources/truth/HG002_${v}_chr20.bed"; then
               t=$(bcftools query -r "chr20:$p" -i "POS=$p" -f '[%GT]\n' "resources/truth/HG002_${v}_chr20.vcf.gz" 2> /dev/null | head -1)
               t=${t:-absent}
             fi
             if [ "$v" = v5.0q ]; then t5=$t; else t4=$t; fi
           done
           printf '%s\tchr20:%s\t%s\t%s\t%s\n' "${x%%:*}" "$p" "${r:-absent${TAB}-${TAB}-}" "$t5" "$t4" >> "$d/sentinels.tsv"
         done
         # region metrics on PASS sites, exactly as the reference run computed the anchors
         TR=resources/truth; RG=resources/regions
         for x in norm:$N filtered:$F; do
           bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t%TYPE\t%QUAL\t%INFO/DP\t%INFO/MQ\t%INFO/MQ0F\t%FILTER[\t%GT\t%DP\t%GQ\t%AD]\n' \
             "${x#*:}" 2> /dev/null | gzip > "$RUN/kit-only.${x%%:*}.dump.tsv.gz"
         done
         common=(--samples "$(tr ' ' ',' <<< "$SAMPLES")" --chunks "$RG/chr20_chunks.txt"
                 --bed "bench_HG002_v4.2.1=$TR/HG002_v4.2.1_chr20.bed" --bed "bench_HG002_v5.0q=$TR/HG002_v5.0q_chr20.bed"
                 --bed "trio_regions=$TR/trio_v4.2.1_chr20.bed" --bed "centromere=$RG/chr20_centromere.bed")
         python3 "$REPO_DIR/pipeline/py/metrics.py" "$RUN/kit-only.norm.dump.tsv.gz" "$d/metrics_norm" --label "kit run, unfiltered" "${common[@]}"
         python3 "$REPO_DIR/pipeline/py/metrics.py" "$RUN/kit-only.filtered.dump.tsv.gz" "$d/metrics_pass" --pass-only --label "kit run, filtered" "${common[@]}"
       ) > "$d/filter_counts.log" 2>&1; then
    kit_only_warn filter_counts "see $d/filter_counts.log"
  fi
}
