#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=02:00:00
# P-annot, SnpEff part: annotate the trio VCF with the MANE database, timing heap and wall time.
# Submitted once per core count in PILOT_SNPEFF_CORES; the heap is 75% of the memory the cores
# bring (about 1.9 GB per core). The largest run also annotates with the full-transcript
# database for comparison, and its MANE output feeds p-trio.
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
kit_job_begin "${SLURM_JOB_NAME:-p-snpeff}"
step=${SLURM_JOB_NAME:-p-snpeff}
# shellcheck source=/dev/null
source "$STATE/snpeff.env"
C=$(kit_cores)
heap_mb=$(( C * 1900 * 3 / 4 ))
V=$PREP_DIR/$(kit_set_dir)/call/trio.norm.vcf.gz
O=$PREP_DIR/$(kit_set_dir)/annot/c$C; D=$RECORDS/$(kit_set_dir)/annot/c$C; mkdir -p "$O" "$D"
max=0; for c in $PILOT_SNPEFF_CORES; do [ "$c" -gt "$max" ] && max=$c; done
dbs=${SNPEFF_MANE:-$SNPEFF_FULL}
[ "$C" = "$max" ] && [ -n "$SNPEFF_FULL" ] && [ "$SNPEFF_FULL" != "$dbs" ] && dbs="$dbs $SNPEFF_FULL"
for db in $dbs; do
  kit_load "$SNPEFF_MODULE"
  [ -f "$D/modules.txt" ] || { kit_module -t list > "$D/modules.txt" 2>&1 || true; }
  kit_t0 snpeff
  snpEff "-Xmx${heap_mb}m" ann -nodownload -dataDir "$SNPEFF_DATA" -csvStats "$D/snpeff_$db.csv" -stats "$O/snpeff_$db.html" \
    "$db" "$V" 2> "$O/snpeff_$db.log" > "$O/trio.ann.$db.vcf"
  kit_t1 snpeff "$step" "$db"
  kit_metric "$step" "$db" snpeff_heap_mb "$heap_mb" MB
  tail -n 30 "$O/snpeff_$db.log" > "$D/snpeff_$db.log_tail.txt"
  kit_load "$HTSLIB_MODULE"
  bgzip -f -@ "$C" "$O/trio.ann.$db.vcf"
  tabix -f -p vcf "$O/trio.ann.$db.vcf.gz"
done
printf 'ANN_VCF=%q\nANN_DB=%q\n' "$O/trio.ann.${SNPEFF_MANE:-$SNPEFF_FULL}.vcf.gz" "${SNPEFF_MANE:-$SNPEFF_FULL}" > "$STATE/ann_$(kit_set_step "c$C").env"
kit_job_end
