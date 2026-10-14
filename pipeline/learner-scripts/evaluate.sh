#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --account=rcac
#SBATCH --qos=standby
#SBATCH --partition=cpu
#SBATCH --time=01:00:00
#SBATCH --job-name=evaluate
#SBATCH --array=1-4
#SBATCH --output=cluster-%x.%j.out
#SBATCH --error=cluster-%x.%j.err

module load biocontainers
module load bcftools/1.24
module load hap.py/0.3.9

# hap.py runs the vcfeval engine of RTG Tools (Java). Without a cap, the same task peaked between
# 1 and 39 GiB in different runs; RTG_MEM sets the memory that RTG Tools may use.
export RTG_MEM=8g

WORK=$SCRATCH/varcall-workshop
REF=$WORK/ref/GRCh38_no_alt.fa
SDF=$WORK/ref/GRCh38_no_alt.sdf
TRUTHDIR=$WORK/resources/truth
OUTDIR=$WORK/results/eval
mkdir -p $OUTDIR

# One sample and truth set per array task: task N reads line N+1 of truth_sets.tsv
LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" $TRUTHDIR/truth_sets.tsv)
IFS=$'\t' read -r SAMPLE TRUTH TRUTH_VCF TRUTH_BED <<< "$LINE"

# Evaluate the calls before and after filtering
for CALLS in norm filtered; do
    # hap.py compares one sample: keep that sample's column and the sites where it has an ALT allele.
    # The file name includes the truth set: two tasks evaluate HG002 at the same time.
    bcftools view -s $SAMPLE -c 1 -Oz --write-index=tbi \
        -o $OUTDIR/$SAMPLE.$TRUTH.$CALLS.calls.vcf.gz $WORK/results/vcf/trio.$CALLS.vcf.gz

    # 24 cores for memory (about 1.9 GB each), 16 threads
    hap.py $TRUTHDIR/$TRUTH_VCF $OUTDIR/$SAMPLE.$TRUTH.$CALLS.calls.vcf.gz \
        -f $TRUTHDIR/$TRUTH_BED \
        -r $REF \
        -o $OUTDIR/$SAMPLE.$TRUTH.$CALLS \
        -l chr20 \
        --roc QUAL \
        --engine vcfeval \
        --engine-vcfeval-template $SDF \
        --threads 16
done
