#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
# det-compare: the first sample aligned at 16 cores (copy q0) and at DET_CORES (copy det) must
# give the same records: md5 of `samtools view -h` without @PG lines (the bwa @PG line holds -t).
set -euo pipefail
# shellcheck source=pipeline/lib.sh
source "${PIPE_DIR:?PIPE_DIR must be exported by the submitter}/lib.sh"
kit_job_begin det-compare
kit_load "$SAMTOOLS_MODULE"
read -r S _ <<< "$SAMPLES"
a=$(work_dir q0)/results/bam/$S.markdup.bam; b=$(work_dir det)/results/bam/$S.markdup.bam
ma=$(samtools view -h "$a" | grep -v '^@PG' | md5sum | cut -c1-32)
mb=$(samtools view -h "$b" | grep -v '^@PG' | md5sum | cut -c1-32)
ca=$(samtools view -c "$a"); cb=$(samtools view -c "$b")
st=FAIL; [ "$ma" = "$mb" ] && st=PASS
{ kit_pilot_header; printf 'sample\tcores_a\tmd5_a\trecords_a\tcores_b\tmd5_b\trecords_b\tstatus\n'
  printf '%s\t16\t%s\t%s\t%s\t%s\t%s\t%s\n' "$S" "$ma" "$ca" "$DET_CORES" "$mb" "$cb" "$st"; } > "$RECORDS/determinism.tsv"
samtools view -H "$a" | grep '^@PG' > "$RECORDS/determinism_pg_q0.txt"
samtools view -H "$b" | grep '^@PG' > "$RECORDS/determinism_pg_det.txt"
kit_metric det-compare "$S" determinism "$st"
[ "$st" = PASS ] || kit_die "alignment differs between 16 and $DET_CORES cores (records/determinism.tsv)"
kit_job_end
