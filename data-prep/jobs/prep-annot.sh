#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=04:00:00
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
kit_job_begin prep-annot
step=prep-annot
C=$(kit_cores)
D=$RECORDS/annot; A=$PREP_DIR/annot; mkdir -p "$D" "$A"
gv=$PREP_DIR/src/annot/$(basename "$(src_url gnomad_chr20_vcf)")

if [ "${FETCH_ON:-login}" = compute ]; then
  ROWS_TSV=$D/fetch.tsv
  annot_dest() { echo "$PREP_DIR/src/annot/$(basename "$(src_url "$1")")"; }
  KIT_DEST_FN=annot_dest
  FORCE=${KIT_FORCE:-0}
  kit_fetch gnomad_chr20_vcf
  kit_fetch gnomad_chr20_tbi
  [ "$NFAIL" -eq 0 ] || kit_die "gnomAD download failed; see $ROWS_TSV"
  kit_load "$SNPEFF_MODULE"
  # shellcheck source=data-prep/snpeff_lib.sh
  source "$REPO_DIR/data-prep/snpeff_lib.sh"
  snpeff_pick
  snpeff_download
fi

# ---- gnomAD: allele-frequency fields only
kit_load "$BCFTOOLS_MODULE" "$HTSLIB_MODULE"
kit_module -t list > "$D/modules-prep-annot.txt" 2>&1 || true
bcftools view -h "$gv" > "$D/gnomad_header.txt"
grep '^##INFO=<ID=' "$D/gnomad_header.txt" | sed -E 's/^##INFO=<ID=([^,]+),.*/\1/' > "$D/gnomad_info_fields.txt"
grep -E "$GNOMAD_KEEP_REGEX" "$D/gnomad_info_fields.txt" > "$D/gnomad_kept_fields.txt" || true
for f in AF AC AN "AF_$GNOMAD_REQUIRED_GROUP" "AC_$GNOMAD_REQUIRED_GROUP" "AN_$GNOMAD_REQUIRED_GROUP"; do
  grep -qx "$f" "$D/gnomad_kept_fields.txt" || kit_die "gnomAD INFO field $f not found; see $D/gnomad_info_fields.txt and GNOMAD_KEEP_REGEX"
done
keep=$(sed 's#^#INFO/#' "$D/gnomad_kept_fields.txt" | paste -sd, -)
out=$A/gnomad.genomes.v4.1.$REGION.af.vcf.gz
if [ "${KIT_FORCE:-0}" = 1 ] || [ ! -s "$out.tbi" ]; then
  kit_t0 gnomad_subset
  bcftools annotate --threads "$C" -x "^$keep" -Oz -o "$out" "$gv"
  bcftools index -t -f "$out"
  kit_t1 gnomad_subset "$step" gnomad
fi
kit_metric "$step" gnomad source_bytes "$(stat -c %s "$gv")" bytes
kit_metric "$step" gnomad subset_bytes "$(stat -c %s "$out")" bytes
kit_metric "$step" gnomad subset_records "$(bcftools index -n "$out")"
kit_metric "$step" gnomad kept_info_fields "$(wc -l < "$D/gnomad_kept_fields.txt")"
printf 'GNOMAD_AF=%q\n' "$out" > "$STATE/gnomad.env"
[ -f "$STATE/snpeff.env" ] || kit_die "no SnpEff database recorded (state/snpeff.env)"
kit_job_end
