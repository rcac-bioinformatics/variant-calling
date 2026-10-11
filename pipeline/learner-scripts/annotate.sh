#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --account=rcac
#SBATCH --qos=standby
#SBATCH --partition=cpu
#SBATCH --time=01:00:00
#SBATCH --job-name=annotate
#SBATCH --output=cluster-%x.%j.out
#SBATCH --error=cluster-%x.%j.err

module load biocontainers
module load snpeff/5.3.0a
module load bcftools/1.24

WORK=$SCRATCH/varcall-workshop
OUTDIR=$WORK/results/annot
GNOMAD=$WORK/resources/gnomad/gnomad.genomes.v4.1.chr20.af.vcf.gz
mkdir -p $OUTDIR

# 1. Predicted consequences with SnpEff (MANE transcripts, Ensembl IDs). The database is
#    already downloaded in ref/snpeff_data; -nodownload stops SnpEff from fetching it.
#    4 cores bring about 7.6 GB of memory, so the Java heap gets 6 GB.
snpEff -Xmx6g ann -nodownload \
    -dataDir $WORK/ref/snpeff_data \
    -stats $OUTDIR/snpEff_summary.html \
    -csvStats $OUTDIR/snpEff_summary.csv \
    GRCh38.mane.1.2.ensembl \
    $WORK/results/vcf/trio.filtered.vcf.gz \
  | bcftools view -Oz -W -o $OUTDIR/trio.snpeff.vcf.gz

# 2. Population allele frequencies from gnomAD v4.1 genomes, renamed so they do not clash
#    with the AC, AN and AF of our own three samples
bcftools annotate -a $GNOMAD \
    -c INFO/gnomad_AF:=INFO/AF,INFO/gnomad_AC:=INFO/AC,INFO/gnomad_AN:=INFO/AN,INFO/gnomad_nhomalt:=INFO/nhomalt,INFO/gnomad_AF_asj:=INFO/AF_asj,INFO/gnomad_AC_asj:=INFO/AC_asj,INFO/gnomad_AN_asj:=INFO/AN_asj \
    -Oz -W -o $OUTDIR/trio.ann.vcf.gz \
    $OUTDIR/trio.snpeff.vcf.gz
