#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
# report: after evaluation and the trio block of one call set. Copies the learner's small
# outputs into records, recomputes the region metrics on PASS sites, gives every candidate (and
# every de novo candidate left after the region step) its status in each truth set, and runs the
# SnpSift extractFields alternative next to +split-vep. Needs COPY.
set -euo pipefail
# shellcheck source=pipeline/lib.sh
source "${PIPE_DIR:?PIPE_DIR must be exported by the submitter}/lib.sh"
kit_job_begin "report-${COPY:?}"
kit_load "$BCFTOOLS_MODULE"
W=$(work_dir "$COPY"); D=$RECORDS/$COPY; mkdir -p "$D/eval" "$D/annot" "$D/trio" "$D/vcf"
TR=$W/resources/truth; RG=$W/resources/regions

# ---- learner outputs (small files only)
cp "$W"/results/vcf/*.stats.txt "$W"/results/vcf/chunks.txt "$D/vcf/"
cp "$W"/results/eval/*.summary.csv "$W"/results/eval/*.extended.csv "$W"/results/eval/*.roc.all.csv.gz \
   "$W"/results/eval/*.roc.Locations.*.csv.gz "$W"/results/eval/*.metrics.json.gz "$D/eval/" 2>/dev/null || true
cp "$W"/results/annot/snpEff_summary.csv "$W"/results/annot/HG002.protein_altering.tsv "$D/annot/"
cp "$W"/results/trio/funnel.tsv "$W"/results/trio/candidates.tsv "$W"/results/trio/mendelian2.txt "$D/trio/"

# ---- region metrics on PASS sites of the filtered calls (genotype masks applied)
F='%CHROM\t%POS\t%REF\t%ALT\t%TYPE\t%QUAL\t%INFO/DP\t%INFO/MQ\t%INFO/MQ0F\t%FILTER[\t%GT\t%DP\t%GQ\t%AD]\n'
bcftools query -f "$F" "$W/results/vcf/trio.filtered.vcf.gz" | gzip > "$RUN/$COPY/filtered.dump.tsv.gz"
python3 "$PIPE_DIR/py/metrics.py" "$RUN/$COPY/filtered.dump.tsv.gz" "$D/metrics_pass" --pass-only --label "$COPY, filtered" \
  --samples "$(tr ' ' ',' <<< "$SAMPLES")" --chunks "$RG/chr20_chunks.txt" \
  --bed "bench_HG002_v4.2.1=$TR/HG002_v4.2.1_chr20.bed" --bed "bench_HG002_v5.0q=$TR/HG002_v5.0q_chr20.bed" \
  --bed "trio_regions=$TR/trio_v4.2.1_chr20.bed" --bed "centromere=$RG/chr20_centromere.bed"
bcftools view -H "$W/results/vcf/trio.filtered.vcf.gz" | cut -f7 | sort | uniq -c > "$D/vcf/filter_labels.txt"

# ---- truth-set status of candidates
TD=$RUN/$COPY/truthdump; mkdir -p "$TD"
args=()
while IFS=$'\t' read -r s t v b; do
  [ "$s" = sample ] && continue
  bcftools query -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' "$TR/$v" > "$TD/$s.$t.tsv" < /dev/null
  args+=(--truth "${s}_$t=$TD/$s.$t.tsv=$TR/$b")
done < "$TR/truth_sets.tsv"
lst() {  # model vcf...: model, chrom, pos, ref, alt
  local m=$1; shift
  for v in "$@"; do bcftools query -f "$m\t%CHROM\t%POS\t%REF\t%ALT\n" "$v"; done
}
lst denovo "$W/results/trio/denovo_5_rare.vcf.gz" > "$TD/final.tsv"
lst recessive "$W/results/trio/recessive_5_rare.vcf.gz" >> "$TD/final.tsv"
python3 "$PIPE_DIR/py/report.py" truth-status "$TD/final.tsv" "$D/trio/candidates_truth_status.tsv" "${args[@]}"
for st in denovo_2_evidence denovo_3_regions recessive_3_regions; do
  lst "${st%%_*}" "$W/results/trio/$st.vcf.gz" > "$TD/$st.tsv"
  python3 "$PIPE_DIR/py/report.py" truth-status "$TD/$st.tsv" "$D/trio/${st}_truth_status.tsv" "${args[@]}"
done
# allele fractions of the de novo candidates after the region step (child, father, mother; G3)
{
  kit_pilot_header
  printf 'chrom\tpos\tref\talt\tqual\tfilter\tchild_gt\tchild_dp\tchild_ad\tchild_af\tfather_ad\tmother_ad\n'
  bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t%FILTER[\t%GT\t%DP\t%AD]\n' "$W/results/trio/denovo_3_regions.vcf.gz" |
    awk -F'\t' 'BEGIN { OFS = "\t" } { split($9, a, ","); t = a[1] + a[2]
      print $1, $2, $3, $4, $5, $6, $7, $8, $9, (t > 0 ? sprintf("%.3f", a[2] / t) : "."), $12, $15 }'
} > "$D/trio/denovo_3_regions_af.tsv"

# ---- +split-vep (learner block 07) vs SnpSift extractFields (KIT EXTRA, the fallback)
{ kit_pilot_header; printf 'tool\tstatus\trows\tdetail\n'; } > "$D/annot/tabulation_tools.tsv"
sv=$(grep -c . "$W/results/annot/HG002.protein_altering.tsv" || true)
if grep -q '^### KIT-ERR.*split-vep' "$RECORDS/console/session-tables-$COPY.log" 2>/dev/null; then
  printf 'bcftools +split-vep\tFAIL\t%s\tsee console/session-tables-%s.log\n' "$sv" "$COPY" >> "$D/annot/tabulation_tools.tsv"
else printf 'bcftools +split-vep\tPASS\t%s\tHIGH or MODERATE rows in HG002.protein_altering.tsv\n' "$sv" >> "$D/annot/tabulation_tools.tsv"; fi
kit_load "$SNPSIFT_MODULE"
if SnpSift extractFields -s ',' -e '.' "$W/results/annot/HG002.ann.vcf.gz" CHROM POS REF ALT 'ANN[0].GENE' 'ANN[0].EFFECT' 'ANN[0].IMPACT' \
     > "$RUN/$COPY/snpsift_extract.tsv" 2> "$D/annot/snpsift_extract.err"; then
  hm=$(awk -F'\t' 'NR > 1 && ($7 == "HIGH" || $7 == "MODERATE")' "$RUN/$COPY/snpsift_extract.tsv" | wc -l)
  printf 'SnpSift extractFields\tPASS\t%s\tfirst ANN entry HIGH or MODERATE\n' "$hm" >> "$D/annot/tabulation_tools.tsv"
else printf 'SnpSift extractFields\tFAIL\t-\tsee annot/snpsift_extract.err\n' >> "$D/annot/tabulation_tools.tsv"; fi
kit_job_end
