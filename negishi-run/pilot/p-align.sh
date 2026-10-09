#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --time=03:00:00
# P-align: the child's chr20 FASTQ through bwa mem (with a read group), samtools fixmate -m,
# sort, markdup, index; then flagstat, stats, mosdepth. Submitted once per pilot core count
# (--cpus-per-task overrides the header); the step name carries the core count.
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
kit_job_begin "${SLURM_JOB_NAME:-p-align}"
step=${SLURM_JOB_NAME:-p-align}
# shellcheck source=/dev/null
source "$STATE/ref.env"
# shellcheck source=/dev/null
source "$STATE/bwa.env"
kit_load "$BWA_MODULE" "$SAMTOOLS_MODULE" "$MOSDEPTH_MODULE"
C=$(kit_cores)
read -r -a S_ARR <<< "$SAMPLES"; S=${S_ARR[0]}
O=$PREP_DIR/pilot/align/c$C; D=$RECORDS/pilot/align/c$C; mkdir -p "$O" "$D"
kit_module -t list > "$D/modules.txt" 2>&1 || true
r1=$PREP_DIR/fastq/${S}_R1.fastq.gz; r2=$PREP_DIR/fastq/${S}_R2.fastq.gz
bam=$O/$S.markdup.bam
ST=$(( C / 4 )); [ "$ST" -ge 1 ] || ST=1   # threads for sort and markdup

kit_t0 align_pipeline
bwa mem -t "$C" -R "@RG\tID:$S.pilot\tSM:$S\tLB:$S\tPL:ILLUMINA" "$BWA_PREFIX" "$r1" "$r2" 2> "$O/bwa.log" \
  | samtools fixmate -m -u - - \
  | samtools sort -u -@ "$ST" -m 1500M -T "$TMPDIR/sort" - \
  | samtools markdup -@ "$ST" -f "$D/markdup_stats.txt" -T "$TMPDIR/md" - "$bam"
kit_t1 align_pipeline "$step" "$S"
kit_t0 index; samtools index -@ "$C" "$bam"; kit_t1 index "$step" "$S"
tail -n 30 "$O/bwa.log" > "$D/bwa_log_tail.txt"

kit_t0 alignment_qc
samtools flagstat -@ "$C" "$bam" > "$D/flagstat.txt"
samtools stats -@ "$C" "$bam" > "$D/stats.txt"
grep '^SN' "$D/stats.txt" | cut -f2- > "$D/stats_SN.txt"
mosdepth -t 4 -n --fast-mode -c "$REGION" "$O/$S" "$bam"
cp "$O/$S.mosdepth.summary.txt" "$D/"
kit_t1 alignment_qc "$step" "$S"

sn() { awk -F'\t' -v k="$1" '$1 == k":" { print $2 }' "$D/stats_SN.txt"; }
kit_metric "$step" "$S" reads_total "$(sn 'raw total sequences')"
kit_metric "$step" "$S" reads_mapped "$(sn 'reads mapped')"
kit_metric "$step" "$S" reads_properly_paired "$(sn 'reads properly paired')"
kit_metric "$step" "$S" reads_duplicated "$(sn 'reads duplicated')"
kit_metric "$step" "$S" reads_mq0 "$(sn 'reads MQ0')"
kit_metric "$step" "$S" insert_size_avg "$(sn 'insert size average')" bp
kit_metric "$step" "$S" "mean_depth_$REGION" "$(awk -v r="$REGION" '$1 == r { print $4 }' "$D/$S.mosdepth.summary.txt")" x
kit_metric "$step" "$S" duplicate_fraction_markdup "$(awk -F': ' '/^READ:/ { r = $2 } /^DUPLICATE TOTAL:/ { d = $2 } END { if (r > 0) printf "%.4f", d / r }' "$D/markdup_stats.txt")"
kit_metric "$step" "$S" bam_bytes "$(stat -c %s "$bam")" bytes
kit_job_end
