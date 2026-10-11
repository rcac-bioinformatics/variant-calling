#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --account=rcac
#SBATCH --qos=standby
#SBATCH --partition=cpu
#SBATCH --time=00:30:00
#SBATCH --job-name=call
#SBATCH --array=1-8
#SBATCH --output=cluster-%x.%j.out
#SBATCH --error=cluster-%x.%j.err

module load biocontainers
module load bcftools/1.24

WORK=$SCRATCH/varcall-workshop
REF=$WORK/ref/GRCh38_no_alt.fa
BAMDIR=$WORK/results/bam
OUTDIR=$WORK/results/vcf/chunks
mkdir -p $OUTDIR

# One region of chr20 per array task (line N of the chunk list)
REGION=$(sed -n "${SLURM_ARRAY_TASK_ID}p" $WORK/resources/regions/chr20_chunks.txt)
CHUNK=chunk$(printf '%02d' $SLURM_ARRAY_TASK_ID)

# Joint calling of the trio; BAM order sets the sample order: child, father, mother
bcftools mpileup -f $REF -r $REGION -a AD,DP,SP -Ou \
    $BAMDIR/HG002.markdup.bam $BAMDIR/HG003.markdup.bam $BAMDIR/HG004.markdup.bam \
  | bcftools call -mv -a FORMAT/GQ -Ob -W -o $OUTDIR/$CHUNK.bcf
