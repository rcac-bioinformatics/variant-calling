#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=01:00:00
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
kit_job_begin prep-truth
kit_load "$BCFTOOLS_MODULE" "$HTSLIB_MODULE"
step=prep-truth
T=$PREP_DIR/truth; D=$RECORDS/truth; mkdir -p "$T" "$D"
kit_module -t list > "$D/modules.txt" 2>&1 || true
printf 'sample\tversion\tvcf\tbed\tnoinconsistent_bed\n' > "$T/truth_sets.tsv"
{ kit_pilot_header; printf 'sample\tversion\tsnps\tindels\tother\tbed_bp\tnoinc_bed_bp\n'; } > "$D/truth_counts.tsv"

bed_cut() {  # in out -> bp in region; stops the job on a missing BED or an empty cut
  [ -s "$1" ] || kit_die "benchmark BED missing or empty: $1"
  case $1 in *.gz) zcat "$1";; *) cat "$1";; esac | awk -v r="$REGION" 'BEGIN { OFS = "\t" } $1 == r' > "$2"
  [ -s "$2" ] || kit_die "no $REGION intervals in $1"
  awk '{ s += $3 - $2 } END { print s + 0 }' "$2"
}
subset() {  # sample version src_vcf src_bed src_noinc_bed(or -)
  local s=$1 v=$2 vcf=$3 bed=$4 noinc=$5 o=$T/$2 bp nbp="-"
  mkdir -p "$o"
  [ -f "$vcf.tbi" ] || [ -f "$vcf.csi" ] || bcftools index -t "$vcf"
  bcftools view -r "$REGION" -Oz -o "$o/$s.$REGION.vcf.gz" "$vcf"
  bcftools index -t -f "$o/$s.$REGION.vcf.gz"
  bp=$(bed_cut "$bed" "$o/$s.$REGION.bed")
  local nb="-"
  if [ "$noinc" != - ] && [ -f "$noinc" ]; then nbp=$(bed_cut "$noinc" "$o/$s.$REGION.noinconsistent.bed"); nb=$o/$s.$REGION.noinconsistent.bed; fi
  local sn ind oth
  sn=$(bcftools view -H -v snps "$o/$s.$REGION.vcf.gz" | wc -l)
  ind=$(bcftools view -H -v indels "$o/$s.$REGION.vcf.gz" | wc -l)
  oth=$(bcftools view -H -V snps,indels "$o/$s.$REGION.vcf.gz" | wc -l)
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$s" "$v" "$sn" "$ind" "$oth" "$bp" "$nbp" >> "$D/truth_counts.tsv"
  printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$v" "$o/$s.$REGION.vcf.gz" "$o/$s.$REGION.bed" "$nb" >> "$T/truth_sets.tsv"
  bcftools query -l "$o/$s.$REGION.vcf.gz" | tr '\n' ' ' > "$D/samples_in_${s}_$v.txt"
  bcftools query -f '[%GT]\n' "$o/$s.$REGION.vcf.gz" | sort | uniq -c > "$D/genotypes_${s}_$v.txt"
  kit_metric "$step" "$s" "truth_${v}_snps" "$sn"
  kit_metric "$step" "$s" "truth_${v}_indels" "$ind"
  kit_metric "$step" "$s" "truth_${v}_bed_bp" "$bp" bp
  # VCF/BED pairing check: a BED from another reference leaves most variants outside it
  kit_metric "$step" "$s" "truth_${v}_records_in_bed" "$(bcftools view -H -T "$o/$s.$REGION.bed" "$o/$s.$REGION.vcf.gz" | wc -l)"
}
for s in $SAMPLES; do
  dir=$PREP_DIR/src/truth/v4.2.1/$s
  # GRCh38 v4.2.1 publishes only the _noinconsistent BED; it is the benchmark BED for all three
  noinc=$dir/$(basename "$(src_url "giab421_${s}_noinc_bed")")
  subset "$s" v4.2.1 "$dir/$(basename "$(src_url "giab421_${s}_vcf")")" "$noinc" "$noinc"
done
if [ -s "$STATE/truth_latest.env" ]; then
  # shellcheck source=/dev/null
  source "$STATE/truth_latest.env"
  L=$PREP_DIR/src/truth/HG002_latest
  case $(basename "${LATEST_BED_URL:-}") in *GRCh38*) ;; *) kit_die "HG002 latest BED is not a GRCh38 file: ${LATEST_BED_URL:-none}";; esac
  if [ -n "${LATEST_VCF_URL:-}" ] && [ -n "${LATEST_BED_URL:-}" ] && [ -f "$L/$(basename "$LATEST_VCF_URL")" ]; then
    subset HG002 latest "$L/$(basename "$LATEST_VCF_URL")" "$L/$(basename "$LATEST_BED_URL")" -
  else
    echo "HG002 latest: VCF or BED missing; not subset" > "$D/latest_missing.txt"
  fi
fi

# README passages on Mendelian-inconsistent and de novo sites
for f in "$RECORDS"/terms/giab*/*; do
  [ -f "$f" ] || continue
  case $f in *md5*|*MD5*) continue;; esac
  if grep -qiE 'inconsistent|de ?novo|mendel' "$f"; then
    printf '==== %s\n' "${f#"$RECORDS"/}"
    grep -iE -B2 -A4 'inconsistent|de ?novo|mendel' "$f"
  fi
done > "$D/readme_denovo_excerpts.txt"
kit_job_end
