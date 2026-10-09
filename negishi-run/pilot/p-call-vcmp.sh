#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=03:00:00
# P-call version comparison: chunk 1 with the pinned bcftools and with each version in
# BCFTOOLS_COMPARE_MODULES that is installed. Records time and SNV and indel counts.
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
kit_job_begin p-call-vcmp
# shellcheck source=/dev/null
source "$STATE/ref.env"
O=$PREP_DIR/pilot/call/vcmp; D=$RECORDS/pilot/call; mkdir -p "$O" "$D"
len=$(awk -v r="$REGION" '$1 == r { print $2 }' "$REF_FA.fai")
size=$(( (len + CALL_CHUNKS - 1) / CALL_CHUNKS ))
reg="$REGION:1-$size"
bams=(); for s in $SAMPLES; do bams+=("$PREP_DIR/src/bam/$(basename "$(src_url "bam_$s")")"); done
{ kit_pilot_header; printf 'module\tversion\tregion\trecords\tsnps\tindels\twall_s\n'; } > "$D/bcftools_version_compare.tsv"
kit_module_init
for m in $BCFTOOLS_MODULE $BCFTOOLS_COMPARE_MODULES; do
  kit_module --force purge; kit_module load biocontainers
  if ! kit_module load "$m" 2>/dev/null; then printf '%s\tnot installed\t%s\t-\t-\t-\t-\n' "$m" "$reg" >> "$D/bcftools_version_compare.tsv"; continue; fi
  v=$(bcftools --version | head -1 | awk '{ print $2 }')
  out=$O/chunk01.${m//\//_}.bcf
  t0=$(date +%s)
  bcftools mpileup -f "$REF_FA" -r "$reg" -a AD,DP,SP -Ou "${bams[@]}" 2> "$O/mpileup.${m//\//_}.log" | bcftools call -mv -Ob -o "$out"
  w=$(( $(date +%s) - t0 ))
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$m" "$v" "$reg" "$(bcftools view -H "$out" | wc -l)" \
    "$(bcftools view -H -v snps "$out" | wc -l)" "$(bcftools view -H -v indels "$out" | wc -l)" "$w" >> "$D/bcftools_version_compare.tsv"
done
kit_job_end
