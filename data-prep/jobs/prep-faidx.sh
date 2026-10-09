#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=01:00:00
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
kit_job_begin prep-faidx
kit_load "$SAMTOOLS_MODULE"
R=$PREP_DIR/ref; mkdir -p "$R" "$RECORDS/reference"
gz=$PREP_DIR/src/ref/$(basename "$(src_url ref_fasta)")
fa=$R/$(basename "$gz" .gz)
kit_module -t list > "$RECORDS/reference/modules-prep-faidx.txt" 2>&1 || true
if [ "${KIT_FORCE:-0}" = 1 ] || [ ! -s "$fa.fai" ]; then
  kit_t0 gunzip; gzip -dc "$gz" > "$fa.tmp" && mv "$fa.tmp" "$fa"; kit_t1 gunzip prep-faidx ref
  kit_t0 faidx; samtools faidx "$fa"; kit_t1 faidx prep-faidx ref
  rm -f "${fa%.*}.dict"; samtools dict -o "${fa%.*}.dict" "$fa"
fi
# compare with the .fai NCBI publishes (columns 1-2: names and lengths)
ncbi_fai=$PREP_DIR/src/ref/$(basename "$(src_url ref_fai)")
if [ -f "$ncbi_fai" ]; then
  if cmp -s <(cut -f1,2 "$fa.fai") <(cut -f1,2 "$ncbi_fai"); then echo "fai names and lengths match NCBI" > "$RECORDS/reference/fai_check.txt"
  else { echo "fai DIFFERS from NCBI (names/lengths)"; diff <(cut -f1,2 "$fa.fai") <(cut -f1,2 "$ncbi_fai") | head -20; } > "$RECORDS/reference/fai_check.txt"; fi
fi
{ kit_pilot_header; cut -f1,2 "$fa.fai"; } > "$RECORDS/reference/contigs.tsv"
kit_metric prep-faidx ref n_contigs "$(wc -l < "$fa.fai")"
kit_metric prep-faidx ref "${REGION}_length" "$(awk -v r="$REGION" '$1 == r { print $2 }' "$fa.fai")" bp
kit_metric prep-faidx ref fasta_bytes "$(stat -c %s "$fa")" bytes
printf 'REF_FA=%q\nREF_DICT=%q\n' "$fa" "${fa%.*}.dict" > "$STATE/ref.env"
kit_job_end
