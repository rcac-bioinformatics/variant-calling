#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=00:30:00
# anchors: step 10. Draft anchors (records/anchors.draft.tsv: metric, call_set, value,
# tolerance, source) from the learner outputs of every call set, and 3-5 sentinel sites
# (records/sentinels.tsv). Values are "reference run, not frozen" until gate G3.
set -euo pipefail
# shellcheck source=pipeline/lib.sh
source "${PIPE_DIR:?PIPE_DIR must be exported by the submitter}/lib.sh"
kit_job_begin anchors
kit_load "$BCFTOOLS_MODULE"
K=$RUN/anchors; mkdir -p "$K"
Q=$(work_dir q0); TR=$Q/resources/truth

# ---- alignment (copy q0; identical in every call set): exact, bwa -K and pinned versions
{
  for s in $SAMPLES; do
    st=$Q/results/qc_alignment/$s.stats.txt
    for k in 'raw total sequences' 'reads mapped' 'reads properly paired' 'reads duplicated' 'reads MQ0'; do
      v=$(awk -F'\t' -v k="$k:" '$1 == "SN" && $2 == k { print $3 }' "$st")
      printf '%s %s\tall\t%s\texact\tresults/qc_alignment/%s.stats.txt\n' "$s" "${k// /_}" "$v" "$s"
    done
    printf '%s mean_depth_chr20\tall\t%s\texact\tresults/qc_alignment/%s.mosdepth.summary.txt\n' "$s" \
      "$(awk '$1 == "chr20" { print $4 }' "$Q/results/qc_alignment/$s.mosdepth.summary.txt")" "$s"
  done
} > "$K/alignment.tsv"

# ---- per call set: counts, Ts/Tv, hap.py, Mendelian errors, funnel
for cs in $COPIES; do
  W=$(work_dir "$cs"); R=$RECORDS/$cs
  sn() { awk -F'\t' -v k="$2:" '$1 == "SN" && $3 == k { print $4 }' "$1"; }
  tt() { awk -F'\t' '$1 == "TSTV" { print $5; exit }' "$1"; }
  {
    for v in norm filtered; do
      f=$W/results/vcf/trio.$v.stats.txt
      printf 'trio_%s records\t%s\t%s\texact\tresults/vcf/trio.%s.stats.txt\n' "$v" "$cs" "$(sn "$f" 'number of records')" "$v"
      printf 'trio_%s SNVs\t%s\t%s\texact\tresults/vcf/trio.%s.stats.txt\n' "$v" "$cs" "$(sn "$f" 'number of SNPs')" "$v"
      printf 'trio_%s indels\t%s\t%s\texact\tresults/vcf/trio.%s.stats.txt\n' "$v" "$cs" "$(sn "$f" 'number of indels')" "$v"
      printf 'trio_%s tstv\t%s\t%s\texact\tresults/vcf/trio.%s.stats.txt\n' "$v" "$cs" "$(tt "$f")" "$v"
    done
    awk -F'\t' -v cs="$cs" 'NR > 2 && $1 == "HG002_carried" && ($2 ~ /^bench_HG002_v4.2.1_/) { printf "HG002 PASS tstv %s\t%s\t%s\texact\trecords/%s/metrics_pass/tstv_regions.tsv\n", $2, cs, $6, cs }' "$R/metrics_pass/tstv_regions.tsv"
    while IFS=$'\t' read -r s t _ _; do
      [ "$s" = sample ] && continue
      f=$W/results/eval/$s.$t.filtered.summary.csv
      awk -F, -v s="$s" -v t="$t" -v cs="$cs" 'NR == 1 { for (i = 1; i <= NF; i++) h[$i] = i; next }
        $2 == "PASS" { printf "%s %s %s recall\t%s\t%s\texact\tresults/eval/%s.%s.filtered.summary.csv\n", s, t, $1, cs, $h["METRIC.Recall"], s, t
                       printf "%s %s %s precision\t%s\t%s\texact\tresults/eval/%s.%s.filtered.summary.csv\n", s, t, $1, cs, $h["METRIC.Precision"], s, t }' "$f"
    done < "$TR/truth_sets.tsv"
    m=$W/results/trio/mendelian2.txt
    ng=$(awk -F'\t' '$1 == "ngood" { print $2 }' "$m"); ne=$(awk -F'\t' '$1 == "nmerr" { print $2 }' "$m")
    printf 'mendelian2 nmerr\t%s\t%s\texact\tresults/trio/mendelian2.txt\n' "$cs" "$ne"
    printf 'mendelian2 ngood\t%s\t%s\texact\tresults/trio/mendelian2.txt\n' "$cs" "$ng"
    awk -F'\t' -v cs="$cs" '{ printf "funnel %s\t%s\t%s\texact\tresults/trio/funnel.tsv\n", $1, cs, $2 }' "$W/results/trio/funnel.tsv"
  } > "$K/$cs.tsv"
done

# ---- sentinels: HG002 truth v4.2.1, parents v4.2.1, calls of every call set (HG002 column)
bcftools query -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' "$TR/HG002_v4.2.1_chr20.vcf.gz" > "$K/truth_HG002.tsv"
bcftools query -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' "$TR/HG003_v4.2.1_chr20.vcf.gz" > "$K/truth_HG003.tsv"
bcftools query -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' "$TR/HG004_v4.2.1_chr20.vcf.gz" > "$K/truth_HG004.tsv"
calls=()
for cs in $COPIES; do
  bcftools query -s HG002 -f '%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t%FILTER[\t%GT]\n' "$(work_dir "$cs")/results/vcf/trio.filtered.vcf.gz" > "$K/calls_$cs.tsv"
  calls+=(--calls "$cs=$K/calls_$cs.tsv")
done
python3 "$PIPE_DIR/py/report.py" sentinels "$RECORDS/sentinels.tsv" \
  --truth "$K/truth_HG002.tsv=$TR/HG002_v4.2.1_chr20.bed" \
  --parents "$K/truth_HG003.tsv=$TR/HG003_v4.2.1_chr20.bed,$K/truth_HG004.tsv=$TR/HG004_v4.2.1_chr20.bed" \
  --trio-bed "$TR/trio_v4.2.1_chr20.bed" --cen "$Q/resources/regions/chr20_centromere.bed" \
  --exclude-bed "$TR/HG002_v4.2.1_chr20.bed" --exclude-bed "$TR/HG002_v5.0q_chr20.bed" "${calls[@]}"
kv=(--kv "$K/alignment.tsv"); for cs in $COPIES; do kv+=(--kv "$K/$cs.tsv"); done
python3 "$PIPE_DIR/py/report.py" anchors "$RECORDS/anchors.draft.tsv" "${kv[@]}" || kit_log "anchors: some values are missing (see the job log)"
kit_job_end
