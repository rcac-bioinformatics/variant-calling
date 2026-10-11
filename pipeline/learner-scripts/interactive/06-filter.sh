# Episode 6: look at the distributions, then flag sites and mask weak genotypes
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load bcftools/1.24
cd $SCRATCH/varcall-workshop
VCF=results/vcf/trio.norm.vcf.gz
mkdir -p results/vcf/stats
# 1. Distributions: site QUAL, total depth and mean mapping quality; then per-sample depth and GQ
bcftools query -f '%QUAL\t%INFO/DP\t%INFO/MQ\n' $VCF > results/vcf/stats/site_qual_dp_mq.tsv
bcftools query -f '[%SAMPLE\t%GT\t%DP\t%GQ\n]' $VCF > results/vcf/stats/genotype_dp_gq.tsv
# The depth cutoff follows a rule, not the benchmark: flag sites deeper than twice the median
MEDIAN_DP=$(cut -f2 results/vcf/stats/site_qual_dp_mq.tsv | sort -n | awk '{ d[NR] = $1 } END { print d[int((NR + 1) / 2)] }')
MAX_DP=$((2 * MEDIAN_DP))
echo "median site depth $MEDIAN_DP; sites above $MAX_DP are flagged HighDP"
# 2. Site filters add a label to FILTER and keep the record; the genotype filter sets
#    genotypes with DP < 10 or GQ < 20 to missing (./.)
bcftools filter -m+ -s LowQual -e 'QUAL<30' -Ou $VCF \
  | bcftools filter -m+ -s HighDP -e "INFO/DP>$MAX_DP" -Ou \
  | bcftools filter -m+ -s LowMQ -e 'INFO/MQ<30' -Ou \
  | bcftools filter -S . -e 'FMT/DP<10 | FMT/GQ<20' -Oz -W -o results/vcf/trio.filtered.vcf.gz
bcftools view -H results/vcf/trio.filtered.vcf.gz | cut -f7 | sort | uniq -c
bcftools stats -f PASS -s - results/vcf/trio.filtered.vcf.gz > results/vcf/trio.filtered.stats.txt
grep -E '^(SN|TSTV)' results/vcf/trio.filtered.stats.txt
# 3. Ts/Tv of HG002's raw calls inside and outside the benchmark regions (^ means outside)
bcftools view -s HG002 -c 1 -Ou $VCF | bcftools stats -T resources/truth/HG002_v4.2.1_chr20.bed - | grep ^TSTV
bcftools view -s HG002 -c 1 -Ou $VCF | bcftools stats -T ^resources/truth/HG002_v4.2.1_chr20.bed - | grep ^TSTV
