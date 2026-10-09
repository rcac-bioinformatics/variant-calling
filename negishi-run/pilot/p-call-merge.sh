#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
# P-call merge: concatenate the chunks in order, normalize (left-align, split multiallelic
# sites) against the reference, index, and run bcftools stats.
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
step=$(kit_set_step p-call-merge)
kit_job_begin "$step"
# shellcheck source=/dev/null
source "$STATE/ref.env"
kit_load "$BCFTOOLS_MODULE"
C=$(kit_cores)
O=$PREP_DIR/$(kit_set_dir)/call; D=$RECORDS/$(kit_set_dir)/call; mkdir -p "$D"
chunks=(); for i in $(seq 1 "$CALL_CHUNKS"); do chunks+=("$O/chunks/chunk_$(printf '%02d' "$i").bcf"); done
kit_t0 concat_norm
bcftools concat --threads "$C" -Ob -o "$O/trio.raw.bcf" "${chunks[@]}"
bcftools norm --threads "$C" -f "$REF_FA" -m -any -Oz -o "$O/trio.norm.vcf.gz" "$O/trio.raw.bcf" 2> "$D/norm.log"
bcftools index -t -f "$O/trio.norm.vcf.gz"
kit_t1 concat_norm "$step" trio
bcftools query -l "$O/trio.norm.vcf.gz" > "$D/sample_order.txt"
bcftools stats -s - "$O/trio.norm.vcf.gz" > "$D/trio.norm.stats.txt"
{ kit_pilot_header; grep -E '^(SN|TSTV)' "$D/trio.norm.stats.txt"; } > "$D/trio.norm.SN_TSTV.txt"
st() { awk -F'\t' -v k="$1" '$1 == "SN" && $3 == k":" { print $4 }' "$D/trio.norm.stats.txt"; }
kit_metric "$step" trio records "$(st 'number of records')"
kit_metric "$step" trio snps "$(st 'number of SNPs')"
kit_metric "$step" trio indels "$(st 'number of indels')"
kit_metric "$step" trio multiallelic_sites_before_split "$(bcftools view -H -m3 "$O/trio.raw.bcf" | wc -l)"
kit_metric "$step" trio tstv "$(awk -F'\t' '$1 == "TSTV" { print $5; exit }' "$D/trio.norm.stats.txt")"
kit_metric "$step" trio vcf_bytes "$(stat -c %s "$O/trio.norm.vcf.gz")" bytes
kit_job_end
