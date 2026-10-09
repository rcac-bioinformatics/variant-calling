#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=04:00:00
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
kit_job_begin prep-bwaindex
# shellcheck source=/dev/null
source "$STATE/ref.env"
kit_load "$BWA_MODULE" "$SAMTOOLS_MODULE"
C=$(kit_cores)
D=$RECORDS/reference; mkdir -p "$D"
kit_module -t list > "$D/modules-prep-bwaindex.txt" 2>&1 || true
bwa 2>&1 | grep -i version > "$D/bwa_version.txt" || true

# 1,000 read pairs from the child's source BAM, for the load-and-align test
T=$PREP_DIR/ref/test_reads; mkdir -p "$T"
bam=$PREP_DIR/src/bam/$(basename "$(src_url bam_HG002)")
samtools view -u "$bam" "$REGION:30000000-30200000" | samtools collate -u -O -T "$TMPDIR/col" - \
  | samtools fastq -n -1 "$T/r1.fq" -2 "$T/r2.fq" -0 /dev/null -s /dev/null - 2> "$T/fastq.log"
head -n 4000 "$T/r1.fq" > "$T/test_R1.fq"; head -n 4000 "$T/r2.fq" > "$T/test_R2.fq"

try_index() {  # prefix label -> 0 if 1,000 pairs align
  local p=$1 n
  if bwa mem -t "$C" "$p" "$T/test_R1.fq" "$T/test_R2.fq" 2> "$D/bwa_test_$2.log" | samtools view -c -F 0x904 - > "$T/mapped_$2.txt"; then
    n=$(cat "$T/mapped_$2.txt"); printf '%s: %s of 2000 reads mapped\n' "$2" "$n" >> "$D/bwa_index_choice.txt"
    [ "$n" -gt 0 ]
  else
    printf '%s: bwa mem failed (see bwa_test_%s.log)\n' "$2" "$2" >> "$D/bwa_index_choice.txt"; return 1
  fi
}
: > "$D/bwa_index_choice.txt"
PREFIX=""
tgz=$PREP_DIR/src/ref/$(basename "$(src_url ref_bwa_index)")
if [ -f "$tgz" ]; then
  N=$PREP_DIR/ref/ncbi_bwa; mkdir -p "$N"
  if [ ! -f "$N/.extracted" ] || [ "${KIT_FORCE:-0}" = 1 ]; then
    kit_t0 extract; tar -xzf "$tgz" -C "$N"; kit_t1 extract prep-bwaindex ref; touch "$N/.extracted"
  fi
  bwt=$(find "$N" -name '*.bwt' | head -1)
  if [ -n "$bwt" ] && try_index "${bwt%.bwt}" ncbi; then PREFIX=${bwt%.bwt}; echo "choice: NCBI index ${PREFIX}" >> "$D/bwa_index_choice.txt"; fi
else
  echo "NCBI bwa index tarball not downloaded (absent upstream or skipped)" >> "$D/bwa_index_choice.txt"
fi
if [ -z "$PREFIX" ]; then
  B=$PREP_DIR/ref/bwa; mkdir -p "$B"
  PREFIX=$B/$(basename "$REF_FA")
  if [ ! -f "$PREFIX.sa" ] || [ "${KIT_FORCE:-0}" = 1 ]; then
    kit_t0 bwa_index; bwa index -p "$PREFIX" "$REF_FA" > "$D/bwa_index_build.log" 2>&1; kit_t1 bwa_index prep-bwaindex ref
  fi
  try_index "$PREFIX" built || kit_die "the built bwa index does not align the test reads"
  echo "choice: built with $(cat "$D/bwa_version.txt") at $PREFIX" >> "$D/bwa_index_choice.txt"
fi
kit_metric prep-bwaindex ref bwa_index_bytes "$(du -cb "$PREFIX".* | tail -1 | cut -f1)" bytes
printf 'BWA_PREFIX=%q\n' "$PREFIX" > "$STATE/bwa.env"
kit_job_end
