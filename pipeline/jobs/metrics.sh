#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=01:00:00
# metrics: step 05 before the filter block. Distributions of the merged, unfiltered calls
# (QUAL, site DP and MQ, per-sample DP and GQ, allele balance at heterozygous genotypes), Ts/Tv
# and counts by region (inside/outside each benchmark BED, centromere, each chunk), and the
# soft-filter proposal from the stated rule. Runs before any hap.py job exists. Needs COPY.
set -euo pipefail
# shellcheck source=pipeline/lib.sh
source "${PIPE_DIR:?PIPE_DIR must be exported by the submitter}/lib.sh"
kit_job_begin "metrics-${COPY:?}"
kit_load "$BCFTOOLS_MODULE"
W=$(work_dir "$COPY"); D=$RECORDS/$COPY; mkdir -p "$D"
TR=$W/resources/truth; RG=$W/resources/regions
F='%CHROM\t%POS\t%REF\t%ALT\t%TYPE\t%QUAL\t%INFO/DP\t%INFO/MQ\t%INFO/MQ0F\t%FILTER[\t%GT\t%DP\t%GQ\t%AD]\n'
bcftools query -f "$F" "$W/results/vcf/trio.norm.vcf.gz" | gzip > "$RUN/$COPY/norm.dump.tsv.gz"
python3 "$PIPE_DIR/py/metrics.py" "$RUN/$COPY/norm.dump.tsv.gz" "$D/metrics_norm" --label "$COPY, unfiltered" \
  --samples "$(tr ' ' ',' <<< "$SAMPLES")" --chunks "$RG/chr20_chunks.txt" \
  --bed "bench_HG002_v4.2.1=$TR/HG002_v4.2.1_chr20.bed" --bed "bench_HG002_v5.0q=$TR/HG002_v5.0q_chr20.bed" \
  --bed "trio_regions=$TR/trio_v4.2.1_chr20.bed" --bed "centromere=$RG/chr20_centromere.bed"
cat "$D/metrics_norm/filter_proposal.tsv" >&2
cp "$W/results/vcf/trio.norm.stats.txt" "$D/" 2>/dev/null || true
kit_job_end
