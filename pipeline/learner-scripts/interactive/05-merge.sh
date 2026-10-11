# Episode 5A: join the eight chunks after call.sh has finished, then normalize
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load bcftools/1.24
cd $SCRATCH/varcall-workshop
# chunk01 ... chunk08: the names sort in chromosome order
ls results/vcf/chunks/chunk*.bcf > results/vcf/chunks.txt
cat results/vcf/chunks.txt
bcftools concat -f results/vcf/chunks.txt -Ob -W -o results/vcf/trio.raw.bcf
bcftools norm -f ref/GRCh38_no_alt.fa -m -any -Oz -W -o results/vcf/trio.norm.vcf.gz results/vcf/trio.raw.bcf
bcftools query -l results/vcf/trio.norm.vcf.gz
bcftools view -H results/vcf/trio.norm.vcf.gz | head -3
bcftools stats -s - results/vcf/trio.norm.vcf.gz > results/vcf/trio.norm.stats.txt
grep -E '^(SN|TSTV)' results/vcf/trio.norm.stats.txt
grep ^PSC results/vcf/trio.norm.stats.txt
