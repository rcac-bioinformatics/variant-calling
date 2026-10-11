# Episode 4: alignment QC after align.sh has finished
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load samtools/1.22.1
module load mosdepth/0.3.3
module load multiqc/1.23
cd $SCRATCH/varcall-workshop
ls -lh results/bam
for SAMPLE in HG002 HG003 HG004; do
    samtools flagstat -@ 4 results/bam/$SAMPLE.markdup.bam > results/qc_alignment/$SAMPLE.flagstat.txt
    samtools stats -@ 4 results/bam/$SAMPLE.markdup.bam > results/qc_alignment/$SAMPLE.stats.txt
    mosdepth -t 4 -n --fast-mode -c chr20 results/qc_alignment/$SAMPLE results/bam/$SAMPLE.markdup.bam
done
cat results/qc_alignment/HG002.flagstat.txt
grep ^SN results/qc_alignment/HG002.stats.txt | cut -f2- | head -40
cat results/qc_alignment/HG002.mosdepth.summary.txt
# Reads with mapping quality 0 (placed at random among equally good locations)
samtools view -c -e 'mapq==0' results/bam/HG002.markdup.bam
samtools view -H results/bam/HG002.markdup.bam | grep '^@RG'
multiqc -o results/qc_alignment results/qc_alignment results/bam
