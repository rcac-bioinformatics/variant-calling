#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --account=rcac
#SBATCH --qos=standby
#SBATCH --partition=cpu
#SBATCH --time=01:00:00
#SBATCH --job-name=align
#SBATCH --array=1-3
#SBATCH --output=cluster-%x.%j.out
#SBATCH --error=cluster-%x.%j.err

module load biocontainers
module load bwa/0.7.17
module load samtools/1.22.1

WORK=$SCRATCH/varcall-workshop
REF=$WORK/ref/GRCh38_no_alt.fa
OUTDIR=$WORK/results/bam
mkdir -p $OUTDIR

# One sample per array task: task N reads line N+1 of samples.tsv (line 1 is the header)
LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" $WORK/data/samples.tsv)
IFS=$'\t' read -r SAMPLE ROLE SEX FAMILY FASTQ_R1 FASTQ_R2 RG_ID RG_LB RG_PL <<< "$LINE"

# Read group: SM becomes the sample name in the VCF. Keep \t as typed; bwa turns it into tabs.
RG="@RG\tID:${RG_ID}\tSM:${SAMPLE}\tLB:${RG_LB}\tPL:${RG_PL}"

# -K 100000000 makes the alignments identical for any number of threads
bwa mem -K 100000000 -t $SLURM_CPUS_PER_TASK -R "$RG" $REF \
    $WORK/data/$FASTQ_R1 $WORK/data/$FASTQ_R2 \
  | samtools fixmate -m -u - - \
  | samtools sort -u -@ 4 -m 1500M -T $OUTDIR/${SAMPLE}.sorttmp - \
  | samtools markdup -@ 4 --write-index -f $OUTDIR/${SAMPLE}.markdup.stats.txt \
      -T $OUTDIR/${SAMPLE}.mdtmp - $OUTDIR/${SAMPLE}.markdup.bam
