# Episode 7: tabulate consequences and frequencies after annotate.sh has finished
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load bcftools/1.24
cd $SCRATCH/varcall-workshop
ANN=results/annot/trio.ann.vcf.gz
bcftools view -h $ANN | grep -E '^##INFO=<ID=(ANN|gnomad_)' | cut -c1-120
# HG002's variants: PASS sites where the child carries an ALT allele
bcftools view -f PASS -s HG002 -c 1 -Oz -W -o results/annot/HG002.ann.vcf.gz $ANN
bcftools view -H results/annot/HG002.ann.vcf.gz | wc -l
# How many carry at least one HIGH or MODERATE prediction
bcftools view -H -i 'INFO/ANN~"[|]HIGH[|]"' results/annot/HG002.ann.vcf.gz | wc -l
bcftools view -H -i 'INFO/ANN~"[|]MODERATE[|]"' results/annot/HG002.ann.vcf.gz | wc -l
# One row per variant: the most severe consequence, with gnomAD frequencies
bcftools +split-vep -a ANN -s worst \
    -f '%CHROM\t%POS\t%REF\t%ALT\t%Gene_Name\t%Annotation\t%Annotation_Impact\t%HGVS.p\t%INFO/gnomad_AF\t%INFO/gnomad_AF_asj\n' \
    -i 'Annotation_Impact="HIGH" || Annotation_Impact="MODERATE"' \
    results/annot/HG002.ann.vcf.gz > results/annot/HG002.protein_altering.tsv
wc -l results/annot/HG002.protein_altering.tsv
# Rare: below 1% in gnomAD overall, or absent from gnomAD; then the same with the Ashkenazi group
awk -F'\t' '$9 == "." || $9 < 0.01' results/annot/HG002.protein_altering.tsv | wc -l
awk -F'\t' '$10 == "." || $10 < 0.01' results/annot/HG002.protein_altering.tsv | wc -l
