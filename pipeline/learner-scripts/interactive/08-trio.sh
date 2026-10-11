# Episode 8: candidate variants in the trio, one filter at a time
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load bcftools/1.24
cd $SCRATCH/varcall-workshop
ANN=results/annot/trio.ann.vcf.gz
T=results/trio
# 1. Sample order: the genotype expressions below use [0] child, [1] father, [2] mother
bcftools query -l $ANN
cat data/trio.ped
# 2. Mendelian consistency of the PASS calls, as a quality-control number
bcftools +mendelian2 -P data/trio.ped -i 'FILTER="PASS"' results/vcf/trio.filtered.vcf.gz > $T/mendelian2.txt
cat $T/mendelian2.txt
# 3. PASS sites only
bcftools view -f PASS -Oz -W -o $T/pass.vcf.gz $ANN
# 4. De novo: child heterozygous, both parents homozygous reference
bcftools view -i 'GT[0]="het" && GT[1]="RR" && GT[2]="RR"' -Oz -W -o $T/denovo_1_genotype.vcf.gz $T/pass.vcf.gz
# 5. Evidence: GQ >= 20 and DP >= 10 in all three, no ALT reads in either parent
bcftools view -i 'MIN(FMT/GQ)>=20 && MIN(FMT/DP)>=10 && FMT/AD[1:1]=0 && FMT/AD[2:1]=0' -Oz -W -o $T/denovo_2_evidence.vcf.gz $T/denovo_1_genotype.vcf.gz
# 6. Regions where the benchmark is trio-consistent in all three samples
bcftools view -T resources/truth/trio_v4.2.1_chr20.bed -Oz -W -o $T/denovo_3_regions.vcf.gz $T/denovo_2_evidence.vcf.gz
# 7. Predicted to change the protein (HIGH or MODERATE impact)
bcftools view -i 'INFO/ANN~"[|]HIGH[|]" || INFO/ANN~"[|]MODERATE[|]"' -Oz -W -o $T/denovo_4_impact.vcf.gz $T/denovo_3_regions.vcf.gz
# 8. Rare: below 1% (or absent) in gnomAD overall and in the Ashkenazi group
bcftools view -i '(INFO/gnomad_AF<0.01 || INFO/gnomad_AF=".") && (INFO/gnomad_AF_asj<0.01 || INFO/gnomad_AF_asj=".")' -Oz -W -o $T/denovo_5_rare.vcf.gz $T/denovo_4_impact.vcf.gz
# Recessive: child homozygous ALT, both parents heterozygous; same evidence, regions, impact and frequency
bcftools view -i 'GT[0]="AA" && GT[1]="het" && GT[2]="het"' -Oz -W -o $T/recessive_1_genotype.vcf.gz $T/pass.vcf.gz
bcftools view -i 'MIN(FMT/GQ)>=20 && MIN(FMT/DP)>=10' -Oz -W -o $T/recessive_2_evidence.vcf.gz $T/recessive_1_genotype.vcf.gz
bcftools view -T resources/truth/trio_v4.2.1_chr20.bed -Oz -W -o $T/recessive_3_regions.vcf.gz $T/recessive_2_evidence.vcf.gz
bcftools view -i 'INFO/ANN~"[|]HIGH[|]" || INFO/ANN~"[|]MODERATE[|]"' -Oz -W -o $T/recessive_4_impact.vcf.gz $T/recessive_3_regions.vcf.gz
bcftools view -i '(INFO/gnomad_AF<0.01 || INFO/gnomad_AF=".") && (INFO/gnomad_AF_asj<0.01 || INFO/gnomad_AF_asj=".")' -Oz -W -o $T/recessive_5_rare.vcf.gz $T/recessive_4_impact.vcf.gz
# 9. The funnel: how many records survive each step
for F in $T/pass.vcf.gz $T/denovo_*.vcf.gz $T/recessive_*.vcf.gz; do
    printf '%s\t%s\n' "$(basename $F .vcf.gz)" "$(bcftools view -H $F | wc -l)"
done > $T/funnel.tsv
cat $T/funnel.tsv
# 10. The candidates, with genotypes, depths, alleles and frequencies (child, father, mother)
FIELDS='%CHROM\t%POS\t%REF\t%ALT\t%Gene_Name\t%Annotation\t%Annotation_Impact\t%HGVS.p\t%INFO/gnomad_AF\t%INFO/gnomad_AF_asj[\t%GT:%DP:%GQ:%AD]\n'
printf 'model\tchrom\tpos\tref\talt\tgene\tconsequence\timpact\thgvs_p\tgnomad_af\tgnomad_af_asj\tchild\tfather\tmother\n' > $T/candidates.tsv
bcftools +split-vep -a ANN -s worst -f "denovo\t$FIELDS" $T/denovo_5_rare.vcf.gz >> $T/candidates.tsv
bcftools +split-vep -a ANN -s worst -f "recessive\t$FIELDS" $T/recessive_5_rare.vcf.gz >> $T/candidates.tsv
cat $T/candidates.tsv
