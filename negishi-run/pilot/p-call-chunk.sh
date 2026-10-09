#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --time=02:00:00
# P-call, one array task per region chunk: joint bcftools mpileup | call -mv on the three
# source BAMs (already aligned to the same reference), child, father, mother order.
# MPILEUP_FILTER comes from the call set in config.sh (empty for "raw").
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
step=$(kit_set_step p-call-chunks)
kit_job_begin "$step"
# shellcheck source=/dev/null
source "$STATE/ref.env"
kit_load "$BCFTOOLS_MODULE"
i=$SLURM_ARRAY_TASK_ID
O=$PREP_DIR/$(kit_set_dir)/call; D=$RECORDS/$(kit_set_dir)/call; mkdir -p "$O/chunks" "$D"
[ "$i" = 1 ] && { kit_module -t list > "$D/modules.txt" 2>&1 || true; }
len=$(awk -v r="$REGION" '$1 == r { print $2 }' "$REF_FA.fai")
size=$(( (len + CALL_CHUNKS - 1) / CALL_CHUNKS ))
start=$(( (i - 1) * size + 1 )); end=$(( i * size )); [ "$end" -le "$len" ] || end=$len
reg="$REGION:$start-$end"
bams=(); for s in $SAMPLES; do bams+=("$PREP_DIR/src/bam/$(basename "$(src_url "bam_$s")")"); done
out=$O/chunks/chunk_$(printf '%02d' "$i").bcf
kit_t0 call
# shellcheck disable=SC2086  # MPILEUP_FILTER holds separate options
bcftools mpileup -f "$REF_FA" -r "$reg" $MPILEUP_FILTER -a AD,DP,SP -Ou "${bams[@]}" 2> "$O/chunks/mpileup_$i.log" \
  | bcftools call -mv -Ob -o "$out"
bcftools index -f "$out"
kit_t1 call "$step" "chunk$i"
kit_metric "$step" "chunk$i" region "$reg"
kit_metric "$step" "chunk$i" records "$(bcftools index -n "$out")"
kit_job_end
