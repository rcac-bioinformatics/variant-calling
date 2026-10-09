#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=03:30:00
# P-eval: hap.py for each sample against each truth set in truth/truth_sets.tsv (HG002 latest
# if present, plus v4.2.1 for every sample), restricted to the region, with --roc QUAL, using
# the xcmp engine and, if it works, vcfeval. A vcfeval failure is recorded, not fatal.
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
step=$(kit_set_step p-eval)
kit_job_begin "$step"
# shellcheck source=/dev/null
source "$STATE/ref.env"
kit_load "$BCFTOOLS_MODULE" "$HAPPY_MODULE"
C=$(kit_cores)
V=$PREP_DIR/$(kit_set_dir)/call/trio.norm.vcf.gz
O=$PREP_DIR/$(kit_set_dir)/eval; D=$RECORDS/$(kit_set_dir)/eval; mkdir -p "$O" "$D"
kit_module -t list > "$D/modules.txt" 2>&1 || true
hap.py --version > "$D/happy_version.txt" 2>&1 || true
{ kit_pilot_header; printf 'sample\ttruth\tengine\tstatus\twall_s\n'; } > "$D/eval_status.tsv"
{ kit_pilot_header; printf 'sample\ttruth\tengine\ttype\tfilter\trecall\tprecision\tf1\n'; } > "$D/happy_metrics.tsv"
nfail_xcmp=0
while IFS=$'\t' read -r s ver tvcf tbed _; do
  [ "$s" = sample ] && continue
  [ -s "$tbed" ] || kit_die "benchmark BED for $s $ver is missing or empty: $tbed (rerun prep-truth)"
  q=$O/query.$s.vcf.gz
  if [ ! -s "$q.tbi" ]; then
    bcftools view -s "$s" -c 1 -Oz -o "$q" "$V" || bcftools view -s "$(grep -m1 "$s" "$RECORDS/pilot/call/sample_order.txt")" -c 1 -Oz -o "$q" "$V"
    bcftools index -t -f "$q"
  fi
  for e in xcmp vcfeval; do
    p=$O/$s.$ver.$e; t0=$(date +%s); st=PASS
    hap.py "$tvcf" "$q" -f "$tbed" -r "$REF_FA" -o "$p" -l "$REGION" --roc QUAL --threads "$C" --engine "$e" \
      > "$p.log" 2>&1 || st=FAIL
    w=$(( $(date +%s) - t0 ))
    [ -s "$p.summary.csv" ] || st=FAIL
    printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$ver" "$e" "$st" "$w" >> "$D/eval_status.tsv"
    tail -n 40 "$p.log" > "$D/$s.$ver.$e.log_tail.txt"
    if [ "$st" = FAIL ]; then
      [ "$e" = xcmp ] && nfail_xcmp=$((nfail_xcmp + 1))
      continue
    fi
    cp "$p.summary.csv" "$D/"
    for f in "$p".extended.csv "$p".roc.all.csv.gz "$p".roc.Locations.*.csv.gz "$p".metrics.json.gz; do
      if [ -f "$f" ]; then cp "$f" "$D/"; fi
    done
    kit_metric "$step" "$s" "wall_s_happy_${ver}_$e" "$w" s
    # recall, precision, F1 for SNP and INDEL, all calls (no filters applied yet) and PASS
    awk -F, -v s="$s" -v t="$ver" -v e="$e" 'NR == 1 { for (i = 1; i <= NF; i++) h[$i] = i; next }
      { printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", s, t, e, $h["Type"], $h["Filter"], $h["METRIC.Recall"], $h["METRIC.Precision"], $h["METRIC.F1_Score"] }' \
      "$p.summary.csv" >> "$D/happy_metrics.tsv"
  done
done < "$PREP_DIR/truth/truth_sets.tsv"
[ "$nfail_xcmp" -eq 0 ] || kit_die "$nfail_xcmp xcmp evaluation(s) failed; see $D/eval_status.tsv"
kit_job_end
