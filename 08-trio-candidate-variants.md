---
source: Rmd
title: '8\. Application: candidate variants in a family trio'
teaching: 35
exercises: 40
---

:::::::::::::::::::::::::::::::::::::: questions

- Which variants in HG002 are consistent with a de novo or recessive model?
- How many candidates survive quality, annotation and frequency filters?
- What does the evidence support, and what does it not?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Confirm relationships and sample order before trio analysis.
- Report the Mendelian-consistency rate as a QC metric.
- Select de novo and recessive candidates with genotype expressions.
- Add quality and annotation filters and report a filtering funnel.
- Inspect candidates in IGV and against the benchmark.
- Write an interpretation that separates call quality from biological significance.

::::::::::::::::::::::::::::::::::::::::::::::::

## The question

A family trio, a child and both parents, lets us ask questions that one genome cannot answer. Two classic ones:

- **De novo**: which variants does the child carry that neither parent has? Each of us carries a few new mutations that arose in a parent's egg or sperm.
- **Recessive**: where does the child carry two copies of an ALT allele, one from each parent, who each carry one?

In a clinical or research study, such variants become candidates for explaining a condition in the child. **HG002, HG003 and HG004 are reference samples, not patients**: we use them because the benchmark tells us which calls are right. This episode is about the method, and about how many naive candidates turn out to be errors. Nothing here is a statement about the health of any of these people.

The question for this episode: in HG002, which variants are consistent with a de novo or a recessive model, are predicted to alter a protein, and are rare in an ancestry-matched population? And how many of those candidates survive a closer look?

::::::::::::::::::::::::::::::::::::::: prereq

## Before you start

You need `results/annot/trio.ann.vcf.gz` and its index from Episode 7 (or its "Short on time?" copy), `results/vcf/trio.filtered.vcf.gz` from Episode 6, and `data/trio.ped` from Episode 2.

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: instructor

Live path (50 minutes; plan section 4, ending by 4:00):

| Minutes | Section | Live or self-paced |
|---|---|---|
| 5 | Step 1: session, sample order and relationships | live |
| 6 | Step 2: Mendelian consistency as QC | live |
| 10 | Step 3: the de novo funnel, filter by filter, including the missing-genotype trap | live |
| 4 | Step 4: the recessive funnel | live |
| 6 | Step 5: the funnel table; why both funnels end at zero | live |
| 8 | Step 6: the 41 de novo candidates, the base rate and the cell line | live, discussion |
| 6 | Step 7: inspecting two candidates (`tview` text and IGV snapshots) | live |
| 5 | Step 8: what the evidence supports; key points | live |

Self-paced: the challenges "Which parental reads did the evidence step remove?" and "Predict the region step", the relationship check (`gtcheck`), the IGV session spoiler, compound heterozygotes, and the confounders table.

:::::::::::::::::::::::::::::::::::::::::::::::::

## Step 1: Sample order and relationships

Every genotype expression in this episode names samples by their column: `GT[0]` is the first sample of the VCF, `GT[1]` the second, `GT[2]` the third. If the order is not what we think, a "de novo" filter silently becomes a filter for something else. Check it first, against the pedigree file from Episode 2:

<!-- kit: interactive 08-trio.sh -->
```bash
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load bcftools/1.24
cd $SCRATCH/varcall-workshop
ANN=results/annot/trio.ann.vcf.gz
T=results/trio
# 1. Sample order: the genotype expressions below use [0] child, [1] father, [2] mother
bcftools query -l $ANN
cat data/trio.ped
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
HG002
HG003
HG004
AJ	HG002	HG003	HG004	1	0
AJ	HG003	0	0	1	0
AJ	HG004	0	0	2	0
```

:::::::::::::::::::::::::::::::::::::

The outputs in this episode leave out the `[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float` lines that bcftools prints before them; the Episode 5A callout "MQ should be declared as Type=Float" explains them.

The VCF lists HG002, HG003, HG004: child, father, mother, as the PED file says (columns: family, sample, father, mother, sex, phenotype). The order comes from the order of the BAM files in `call.sh` (Episode 5A), not from any rule; always check it.

### Are they really related as stated?

Sample order says which column is which name. It does not prove that the person called "father" is the child's father, or that two samples were not swapped in the lab. The genotypes can check this: a parent and child share at least one allele at every site, so **opposite homozygotes** (one `0/0`, the other `1/1`) should be rare between them, made only by errors and new mutations, while they are common between unrelated people. `bcftools gtcheck` compares every pair of samples in a file and reports how discordant their genotypes are ([bcftools manual, `gtcheck`](https://samtools.github.io/bcftools/bcftools.html#gtcheck)). The workshop's scripts do not run it; the command for a self-paced look is:

::::::::::::::::::::::::::::::::::::: spoiler

## Checking relationships with `gtcheck` (not tested in the workshop)

<!-- kit: not-run reference -->
```bash
bcftools gtcheck results/vcf/trio.filtered.vcf.gz
```

Read the discordance of each pair: the two parent-child pairs should be clearly less discordant than the two parents with each other. A swap or a wrong parent shows up as a pair that does not fit. PLINK 2's KING kinship estimate (self-paced Episode 9, when published) gives the same answer as a number: about 0.25 for parent and child.

:::::::::::::::::::::::::::::::::::::

## Step 2: Mendelian consistency as QC

A child's genotype must be explainable by one allele from each parent. A site where it is not is a **Mendelian violation**. Count them for the PASS calls:

<!-- kit: interactive 08-trio.sh -->
```bash
# 2. Mendelian consistency of the PASS calls, as a quality-control number
bcftools +mendelian2 -P data/trio.ped -i 'FILTER="PASS"' results/vcf/trio.filtered.vcf.gz > $T/mendelian2.txt
cat $T/mendelian2.txt
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
Identified 1 complete trio in the VCF file
# Summary stats
sites_ref_only	0	# sites skipped because there was no ALT allele
sites_many_als	0	# skipped because of too many ALT alleles
sites_fail	27763	# skipped because of failed -i/-e filter
sites_no_GT	0	# skipped because of absent FORMAT/GT field
sites_not_diploid	0	# skipped because FORMAT/GT not formatted diploid
sites_no_rule	0	# number of sites with no applicable inheritance rule in at least one trio
sites_missing	13177	# number of sites with missing or unusable GT information in at least one trio
sites_merr	449	# number of sites with at least one definite Mendelian error
sites_good	144536	# number of sites with at least one evaluable and Mendelian-consistent trio
# Note: sites_missing, sites_merr, sites_good, and sites_no_rule are not mutually exclusive with multiple trios.
# Per-trio stats, each column corresponds to one trio. List of trios is below.
# The meaning of per-trio stats is the same as described above, ngood_alt is
# the number of good genotypes with at least one non-reference allele, and is
# included in the ngood counter
ngood	144536
ngood_alt	144536
nmerr	449
nmissing	13177
nfail	0
nno_rule	0
# List of trios. Their ids are in the same order as the values listed in the stats lines above. For
# example, the values for the first trio (id=1) and the third trio (id=3) are in the 2nd and the 4th
# column and their stats can be obtained with the unix command
#     cat stats.txt | grep ^n | cut -f1,2,4
# TRIO	[2]id	[3]child	[4]father	[5]mother
TRIO	1	HG002	HG003	HG004
```

:::::::::::::::::::::::::::::::::::::

`+mendelian2` is a bcftools plugin ([bcftools plugins](https://samtools.github.io/bcftools/howtos/plugins.html)); `-P` reads the trio from the PED file, and `-i 'FILTER="PASS"'` skips sites that failed a filter (`sites_fail`). The lines to read:

- `sites_merr`: 449 sites with a definite Mendelian error;
- `sites_good`: 144,536 sites that are consistent;
- `sites_missing`: 13,177 sites where at least one genotype is missing, mostly the genotype mask of Episode 6. These cannot be evaluated, so they count as neither.

The **Mendelian error rate** is 449 / (449 + 144,536) = 0.31% of the PASS sites that could be evaluated. As a quality measure it needs no truth set, only a family: Episode 6 listed it among the proxies. Each violation has a cause, and only one cause is biology:

- a **genotype error** in any of the three samples, for example a heterozygous site in a parent called `0/0` because few reads carried the ALT allele;
- a **deletion or copy-number change** in one person, which makes a heterozygous region look homozygous;
- **mapping artifacts** in repeats and segmental duplications, where reads from elsewhere pile up;
- a **new mutation** in the child, or in the cell line the DNA came from (Step 6).

A de novo variant *is* a Mendelian violation. So the de novo candidates we are about to select are drawn from the same small set of sites as the errors, and most of what we find there will be errors.

## Step 3: The de novo funnel

Each step keeps the records that pass one filter and writes them to a new file, so we can count what each filter removes. First, keep only PASS sites of the annotated file:

<!-- kit: interactive 08-trio.sh -->
```bash
# 3. PASS sites only
bcftools view -f PASS -Oz -W -o $T/pass.vcf.gz $ANN
# 4. De novo: child heterozygous, both parents homozygous reference
bcftools view -i 'GT[0]="het" && GT[1]="RR" && GT[2]="RR"' -Oz -W -o $T/denovo_1_genotype.vcf.gz $T/pass.vcf.gz
```

**Filter 1, genotype:** `GT[0]="het" && GT[1]="RR" && GT[2]="RR"`: the child (column 0) heterozygous, the father (column 1) and the mother (column 2) homozygous for the reference allele. `het`, `RR` (reference-reference) and `AA` (ALT-ALT) are bcftools keywords for genotypes ([bcftools manual, expressions](https://samtools.github.io/bcftools/bcftools.html#expressions)). `&&` joins conditions that may hold in different samples, which is what we need here (Episode 6).

### Missing is not reference

What about a parent whose genotype the mask of Episode 6 set to missing (`./.`)? `GT[1]="RR"` does not match a missing genotype, so such a site is not a candidate. That is right: a masked genotype is one we decided not to trust, often because the parent had few reads there. Count what we would add if missing parents were treated as reference:

<!-- kit: extra 08-trio.sh -->
```bash
bcftools view -H -i 'GT[0]="het" && GT[1]="RR" && GT[2]="RR"' $T/pass.vcf.gz | wc -l
bcftools view -H -i 'GT[0]="het" && (GT[1]="RR" || GT[1]="mis") && (GT[2]="RR" || GT[2]="mis")' $T/pass.vcf.gz | wc -l
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
312
2411
```

:::::::::::::::::::::::::::::::::::::

The first count is filter 1 (312, as in the funnel below). The second adds every site where a parent's genotype is missing (`mis`). Those extra "candidates" rest on a parent we have no confident genotype for: if that parent has too few reads to see an ALT allele, the child may simply have inherited it. **Treating missing genotypes as reference** is a classic way to inflate a de novo list. Some tools and file conversions do it silently, for example when a missing genotype is written out as `0/0`.

### Evidence in every sample

<!-- kit: interactive 08-trio.sh -->
```bash
# 5. Evidence: GQ >= 20 and DP >= 10 in all three, no ALT reads in either parent
bcftools view -i 'MIN(FMT/GQ)>=20 && MIN(FMT/DP)>=10 && FMT/AD[1:1]=0 && FMT/AD[2:1]=0' -Oz -W -o $T/denovo_2_evidence.vcf.gz $T/denovo_1_genotype.vcf.gz
```

**Filter 2, evidence:** each condition is about the genotypes, not the site:

- `MIN(FMT/GQ)>=20`: the lowest genotype quality of the three samples is at least 20;
- `MIN(FMT/DP)>=10`: each of the three has at least 10 reads;
- `FMT/AD[1:1]=0 && FMT/AD[2:1]=0`: `AD` holds the read counts for REF and ALT; `AD[1:1]` is sample 1 (the father), second value (the ALT count). The father and the mother have **no read at all** with the ALT allele.

These must be genotype-level conditions. A site-level depth (`INFO/DP`) of 60 can be 55 reads in the child and 5 in the father; a de novo call needs enough reads in *each parent* to be confident that they lack the allele. A parent with one or two ALT reads may carry the variant at a low fraction (parental mosaicism) or be heterozygous and undersampled.

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: which parental reads did the evidence step remove?

The evidence step takes the 312 records of filter 1 down to 81.

1. The genotype mask of Episode 6 already set every genotype with DP below 10 or GQ below 20 to missing, and filter 1 requires called genotypes. What can the `GQ` and `DP` conditions of filter 2 still remove?
2. Predict how many of the 312 records have at least one ALT read in a parent, then check:

<!-- kit: extra 08-trio.sh -->
```bash
bcftools view -H -i 'FMT/AD[1:1]>0 || FMT/AD[2:1]>0' $T/denovo_1_genotype.vcf.gz | wc -l
```

::::::::::::::::::::::::::::::::::: solution

```output
231
```

1. Nothing: every genotype that survived the mask already has DP of at least 10 and GQ of at least 20. The conditions stay in the filter because they state the evidence we require, and because without the mask of Episode 6 they would do the work.
2. 312 - 81 = 231, if the parental ALT reads do all the work. The count above confirms it. Most naive de novo calls at this stage have the ALT allele in a parent, a few reads that the genotype call `0/0` overruled.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

### Regions, impact and frequency

<!-- kit: interactive 08-trio.sh -->
```bash
# 6. Regions where the benchmark is trio-consistent in all three samples
bcftools view -T resources/truth/trio_v4.2.1_chr20.bed -Oz -W -o $T/denovo_3_regions.vcf.gz $T/denovo_2_evidence.vcf.gz
# 7. Predicted to change the protein (HIGH or MODERATE impact)
bcftools view -i 'INFO/ANN~"[|]HIGH[|]" || INFO/ANN~"[|]MODERATE[|]"' -Oz -W -o $T/denovo_4_impact.vcf.gz $T/denovo_3_regions.vcf.gz
# 8. Rare: below 1% (or absent) in gnomAD overall and in the Ashkenazi group
bcftools view -i '(INFO/gnomad_AF<0.01 || INFO/gnomad_AF=".") && (INFO/gnomad_AF_asj<0.01 || INFO/gnomad_AF_asj=".")' -Oz -W -o $T/denovo_5_rare.vcf.gz $T/denovo_4_impact.vcf.gz
```

**Filter 3, regions:** `-T` keeps records inside the regions of a BED file. `trio_v4.2.1_chr20.bed` is the intersection of the three v4.2.1 benchmark regions of HG002, HG003 and HG004, in the versions that exclude regions with Mendelian-inconsistent benchmark variants (`_noinconsistent`; the v4.2.1 README says that putative HG002 de novo variants are kept in them). Inside these regions, NIST is confident about all three genotypes. Outside them lies the sequence where calls are least reliable: in Episode 6, HG002's PASS calls had a Ts/Tv of 2.30 inside the benchmark regions and 1.44 outside. The step is needed for two reasons: it removes the regions where errors concentrate, and it makes every remaining candidate checkable against the truth sets (Step 6).

**Filter 4, impact:** at least one `HIGH` or `MODERATE` prediction (Episode 7).

**Filter 5, frequency:** below 1% in gnomAD overall *and* in the Ashkenazi group, or absent. A variant common in the population cannot be a new mutation in this child, and is unlikely to explain a rare condition. `INFO/gnomad_AF="."` tests for a missing value: no gnomAD record.

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: predict the region step

The region step takes the de novo candidates from 81 to 41, and the recessive candidates (next step) from 5,282 to 4,632.

1. The trio regions cover most of chromosome 20, yet the de novo step loses half its candidates and the recessive step about an eighth. Why the difference?
2. What would you lose by skipping this step?

::::::::::::::::::::::::::::::::::: solution

1. Errors are not spread evenly: they concentrate in repeats, segmental duplications and the centromere, which lie mostly outside the benchmark regions (Episode 6). De novo candidates are selected *for* being inconsistent with the parents, so they are enriched for errors, and many sit in those regions. Recessive candidates (child `1/1`, both parents `0/1`) are consistent with Mendelian inheritance and mostly real; they are spread more like ordinary variants.
2. You would keep 40 more de novo candidates, most of them in sequence where the calls are unreliable and where no benchmark can say whether they are right. Skipping the step is defensible only if you can check every candidate another way.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

## Step 4: The recessive funnel

The same steps, with a different genotype pattern:

<!-- kit: interactive 08-trio.sh -->
```bash
# Recessive: child homozygous ALT, both parents heterozygous; same evidence, regions, impact and frequency
bcftools view -i 'GT[0]="AA" && GT[1]="het" && GT[2]="het"' -Oz -W -o $T/recessive_1_genotype.vcf.gz $T/pass.vcf.gz
bcftools view -i 'MIN(FMT/GQ)>=20 && MIN(FMT/DP)>=10' -Oz -W -o $T/recessive_2_evidence.vcf.gz $T/recessive_1_genotype.vcf.gz
bcftools view -T resources/truth/trio_v4.2.1_chr20.bed -Oz -W -o $T/recessive_3_regions.vcf.gz $T/recessive_2_evidence.vcf.gz
bcftools view -i 'INFO/ANN~"[|]HIGH[|]" || INFO/ANN~"[|]MODERATE[|]"' -Oz -W -o $T/recessive_4_impact.vcf.gz $T/recessive_3_regions.vcf.gz
bcftools view -i '(INFO/gnomad_AF<0.01 || INFO/gnomad_AF=".") && (INFO/gnomad_AF_asj<0.01 || INFO/gnomad_AF_asj=".")' -Oz -W -o $T/recessive_5_rare.vcf.gz $T/recessive_4_impact.vcf.gz
```

`GT[0]="AA" && GT[1]="het" && GT[2]="het"`: the child homozygous for the ALT allele, both parents heterozygous. The evidence filter has no parental ALT-read condition: the parents are supposed to carry the allele. As in the challenge above, the `GQ` and `DP` conditions cannot remove anything after the genotype mask: `GT="AA"` and `GT="het"` never match a missing genotype, and every called genotype already has DP of at least 10 and GQ of at least 20. So the recessive evidence step keeps all 5,282 records. It stays in the funnel to state the evidence we require, and it would matter on calls without the mask.

## Step 5: The funnel

Count the records at each step:

<!-- kit: interactive 08-trio.sh -->
```bash
# 9. The funnel: how many records survive each step
for F in $T/pass.vcf.gz $T/denovo_*.vcf.gz $T/recessive_*.vcf.gz; do
    printf '%s\t%s\n' "$(basename $F .vcf.gz)" "$(bcftools view -H $F | wc -l)"
done > $T/funnel.tsv
cat $T/funnel.tsv
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
pass	158151
denovo_1_genotype	312
denovo_2_evidence	81
denovo_3_regions	41
denovo_4_impact	0
denovo_5_rare	0
recessive_1_genotype	5282
recessive_2_evidence	5282
recessive_3_regions	4632
recessive_4_impact	8
recessive_5_rare	0
```

:::::::::::::::::::::::::::::::::::::

The frozen values of this workshop, starting from 158,151 PASS records:

| Step | Filter | De novo | Recessive |
|---|---|---|---|
| 1 genotype | child `het`, parents `RR` / child `AA`, parents `het` | 312 | 5,282 |
| 2 evidence | GQ at least 20 and DP at least 10 in all three; de novo: no ALT read in either parent | 81 | 5,282 |
| 3 regions | inside the trio benchmark regions | 41 | 4,632 |
| 4 impact | at least one `HIGH` or `MODERATE` prediction | 0 | 8 |
| 5 frequency | below 1% (or absent) in gnomAD overall and in the Ashkenazi group | 0 | 0 |

**Both funnels end at zero.** The de novo funnel stops at the impact step: none of the 41 candidates is predicted to change a protein. That is not surprising: in Episode 7, about 0.2% of HG002's variants had a `HIGH` or `MODERATE` most severe prediction, so among 41 variants we would expect none. The recessive funnel keeps 8 protein-altering variants, and the frequency step removes all of them. See why, without gene names:

<!-- kit: extra 08-trio.sh -->
```bash
bcftools +split-vep -a ANN -s worst -f '%POS\t%Annotation\t%INFO/gnomad_AF\t%INFO/gnomad_AF_asj\n' $T/recessive_4_impact.vcf.gz
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
3044461	missense_variant	0.173277	0.159078
9307875	missense_variant	0.515974	0.704205
38241114	missense_variant	0.280701	0.40841
44051315	missense_variant	0.00573602	0.0414986
45877334	missense_variant	0.577478	0.510951
45891598	disruptive_inframe_deletion	0.655311	0.531521
63562677	missense_variant	0.436001	0.417291
63562775	missense_variant	0.249412	0.294118
```

:::::::::::::::::::::::::::::::::::::

The columns are position, most severe consequence, and the gnomAD frequencies overall and in the Ashkenazi group. Every one of the 8 is at 1% or more in gnomAD, so none can be a rare recessive variant: homozygous carriers of common protein-altering variants are found in many healthy people. This is the reason a frequency filter belongs in the funnel.

Finally, the candidate table that a study would hand on:

<!-- kit: interactive 08-trio.sh -->
```bash
# 10. The candidates, with genotypes, depths, alleles and frequencies (child, father, mother)
FIELDS='%CHROM\t%POS\t%REF\t%ALT\t%Gene_Name\t%Annotation\t%Annotation_Impact\t%HGVS.p\t%INFO/gnomad_AF\t%INFO/gnomad_AF_asj[\t%GT:%DP:%GQ:%AD]\n'
printf 'model\tchrom\tpos\tref\talt\tgene\tconsequence\timpact\thgvs_p\tgnomad_af\tgnomad_af_asj\tchild\tfather\tmother\n' > $T/candidates.tsv
bcftools +split-vep -a ANN -s worst -f "denovo\t$FIELDS" $T/denovo_5_rare.vcf.gz >> $T/candidates.tsv
bcftools +split-vep -a ANN -s worst -f "recessive\t$FIELDS" $T/recessive_5_rare.vcf.gz >> $T/candidates.tsv
cat $T/candidates.tsv
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
model	chrom	pos	ref	alt	gene	consequence	impact	hgvs_p	gnomad_af	gnomad_af_asj	child	father	mother
```

:::::::::::::::::::::::::::::::::::::

Only the header: no candidates. An empty list is a result, and a common one. Resist the temptation to loosen a threshold until a "nice" list appears: that is the trio version of tuning on the test set (Episode 6), and the list it produces is the filters' doing, not the data's.

## Step 6: The 41 de novo candidates

The impact step emptied the de novo list, but the 41 candidates before it are worth a closer look: they passed every quality filter, inside the regions where the benchmark is confident. Print their genotypes and read counts (child, father, mother; `AD` is REF reads, ALT reads):

<!-- kit: extra 08-trio.sh -->
```bash
bcftools query -f '%POS\t%REF\t%ALT[\t%GT:%AD]\n' $T/denovo_3_regions.vcf.gz
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
2202238	C	T	0/1:16,18	0/0:34,0	0/0:39,0
3390371	CT	C	0/1:23,12	0/0:44,0	0/0:23,0
7382842	C	A	0/1:20,12	0/0:43,0	0/0:37,0
10429137	C	T	0/1:24,15	0/0:44,0	0/0:27,0
11132316	A	G	0/1:20,15	0/0:26,0	0/0:33,0
11134213	A	G	0/1:26,15	0/0:28,0	0/0:35,0
11142983	A	G	0/1:10,17	0/0:30,0	0/0:23,0
11143024	A	C	0/1:10,16	0/0:33,0	0/0:19,0
11149076	G	A	0/1:23,11	0/0:42,0	0/0:39,0
11156729	A	C	0/1:13,19	0/0:27,0	0/0:34,0
11161443	A	G	0/1:20,6	0/0:41,0	0/0:32,0
11165407	A	G	0/1:19,21	0/0:32,0	0/0:39,0
11179079	A	G	0/1:11,9	0/0:43,0	0/0:27,0
11179241	G	A	0/1:19,21	0/0:33,0	0/0:23,0
11509736	G	A	0/1:15,15	0/0:38,0	0/0:35,0
11860952	C	T	0/1:19,14	0/0:30,0	0/0:36,0
12788964	A	C	0/1:24,23	0/0:31,0	0/0:31,0
13604987	CATAT	C	0/1:6,3	0/0:4,0	0/0:3,0
13911267	C	T	0/1:16,20	0/0:33,0	0/0:32,0
14450826	G	A	0/1:23,6	0/0:42,0	0/0:27,0
18487989	C	A	0/1:12,11	0/0:33,0	0/0:40,0
18487996	C	G	0/1:12,10	0/0:33,0	0/0:39,0
22097831	G	A	0/1:18,13	0/0:49,0	0/0:22,0
22780342	C	T	0/1:13,15	0/0:33,0	0/0:34,0
24504452	C	T	0/1:22,14	0/0:39,0	0/0:35,0
31885288	T	C	0/1:26,4	0/0:27,0	0/0:32,0
31885293	G	T	0/1:25,4	0/0:28,0	0/0:32,0
32950012	A	AC	0/1:19,13	0/0:31,0	0/0:19,0
36652410	C	CA	0/1:30,11	0/0:24,0	0/0:48,0
42496452	C	T	0/1:22,22	0/0:29,0	0/0:33,0
44266379	C	A	0/1:27,19	0/0:44,0	0/0:46,0
47053475	G	T	0/1:37,9	0/0:35,0	0/0:38,0
47138749	CA	C	0/1:21,10	0/0:45,0	0/0:30,0
47928416	G	GTT	0/1:4,3	0/0:5,0	0/0:3,0
55252401	GCACA	G	0/1:24,9	0/0:21,0	0/0:15,0
55368617	A	G	0/1:17,15	0/0:34,0	0/0:38,0
55450538	C	T	0/1:14,14	0/0:33,0	0/0:26,0
57665372	C	T	0/1:18,17	0/0:31,0	0/0:47,0
57830448	G	T	0/1:20,18	0/0:31,0	0/0:34,0
59782723	C	T	0/1:24,12	0/0:34,0	0/0:45,0
63923947	G	A	0/1:16,15	0/0:42,0	0/0:37,0
```

:::::::::::::::::::::::::::::::::::::

### What the truth sets say

The workshop's reference run looked up each of the 41 in the four truth sets ([reference-run memo](https://github.com/rcac-bioinformatics/variant-calling/blob/main/maintenance/plan/reference-run.md), section 6, corrected 2026-10-14). A truth set speaks only inside its benchmark regions, so the lookup first asks whether the position is inside them:

| HG002 v5.0q | HG002 v4.2.1 | HG003 v4.2.1 | HG004 v4.2.1 | Candidates |
|---|---|---|---|---|
| heterozygous | heterozygous | homozygous reference | homozygous reference | 7 |
| outside the benchmark regions | heterozygous | homozygous reference | homozygous reference | 27 |
| homozygous reference | homozygous reference | homozygous reference | homozygous reference | 2 |
| another allele at the same position | another allele | another allele | another allele | 2 |
| other combinations | | | | 3 |

"Heterozygous" means the position is inside that benchmark's regions and its truth VCF has the child's allele with a heterozygous genotype; "homozygous reference" means inside the regions and absent from the truth VCF.

So **the HG002 v4.2.1 benchmark supports 34 of the 41 as variants present in HG002 and absent from both parents**: 31 SNVs and 3 indels. The v5.0q benchmark, which NIST recommends for HG002, supports 7 of them and contradicts none; the other 27 lie outside its benchmark regions, where it makes no claim. In the child, the ALT reads of the 34 make up 0.44 of the reads on average (median 0.46), as expected for a heterozygous variant present in nearly every cell. In both parents, none of the 41 has a single ALT read. Ten of the 34 lie within 47 kb of each other, between chr20:11,132,316 and 11,179,241.

### Base rates

How many germline de novo mutations should we expect? The human germline mutation rate is about 1.2 x 10^-8 per base per generation ([Kong et al. 2012](https://doi.org/10.1038/nature11396)). A child inherits two copies of chromosome 20, each 64.4 Mb:

1.2 x 10^-8 x 2 x 64,444,167 = 1.55 expected new SNVs on chromosome 20.

New mutations arrive independently, so the number in one child follows a Poisson distribution, and the chance of none at all is e^-1.55 = 0.21: about one child in five has no germline de novo SNV on chromosome 20. (With the expectation rounded to 1.5, e^-1.5 = 0.22.) The benchmark regions cover less than the whole chromosome, so the expectation inside them is lower still.

Against an expectation of about 1.5, **312** candidates after the genotype step means that most of them must be errors: the base rate, not the filter, should set our level of skepticism. Even 41 is more than twenty times the expectation. Yet 34 are supported by the v4.2.1 benchmark, and ten of them sit within 47 kb: independent germline mutations at a rate of 1.5 per chromosome would almost never cluster like that.

### The DNA comes from a cell line

The HG002 reference DNA is extracted from a lymphoblastoid **cell line**, grown from the donor's blood cells ([Daniels et al. 2024](https://doi.org/10.1101/2024.12.02.625685)). Mutations that arose early in the life of that cell line, or in the cell that founded it, are present in nearly every cell of the DNA we sequenced, and they look exactly like germline de novo variants: heterozygous in the child, absent from both parents. The truth-supported candidates are therefore best described as **real variants in the DNA that was sequenced, most likely clonal cell-line mutations rather than germline de novo mutations**. Short reads from this DNA cannot tell the two origins apart; that would take, for example, DNA from another tissue of the donor.

NIST has published a benchmark of such variants in HG002 (Daniels et al. 2024). The authors write that mosaic variants in HG002 may come "from mutations that have arisen during the cell line generation and culturing process", and they report variants at allele fractions of 5% to 30%, a **subclonal** set. That is the caveat: our truth-supported candidates sit near 0.5, a **clonal** fraction, so they are not the variants that benchmark describes, and the paper does not tell us their origin. It does show that cell-line mutations exist in this DNA.

Which explanation fits the other 7? They include the clearest errors: a pair of SNVs 5 bp apart at chr20:31,885,288 and 31,885,293 with only about 13% ALT reads in the child and homozygous reference in every truth set, and two indels in repeats (an `AT` repeat and a run of `T`s) with fewer than 10 reads counted in `AD` in every sample (one of them is the second site of Step 7).

## Step 7: Inspecting candidates

A candidate list is a list of positions to look at. We inspect two of the 41, chosen to show the two cases above:

- **chr20:11,156,729 A>C**, child `0/1`, both parents `0/0`, heterozygous in both HG002 benchmarks and homozygous reference in both parents' benchmarks: a truth-supported candidate, one of the ten in the 47 kb cluster;
- **chr20:13,604,987 CATAT>C** (a 4 bp deletion), child `0/1`, both parents `0/0`, in an `AT` repeat where the truth sets record an inherited 2 bp deletion: a candidate made by overlapping indel records.

`samtools tview -d T` prints the reads as text, as in Episode 4: column 21 is the site, `.` and `,` are reads that match the reference on the forward and reverse strand, letters are other bases, and `*` marks a deleted base. Load samtools in the same session and look at the first site in all three samples:

<!-- kit: extra 08-trio.sh -->
```bash
module load samtools/1.22.1
samtools tview -d T -i -w 41 -p chr20:11156709 results/bam/HG002.markdup.bam ref/GRCh38_no_alt.fa
samtools tview -d T -i -w 41 -p chr20:11156709 results/bam/HG003.markdup.bam ref/GRCh38_no_alt.fa
samtools tview -d T -i -w 41 -p chr20:11156709 results/bam/HG004.markdup.bam ref/GRCh38_no_alt.fa
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
  11156711  11156721  11156731
AAGCTCTTTACATTTACTTAATAGATAAGTATTCTTAGGCA
....................M....................
,,,,,, .............C....................
,,,,,,,,        .........................
...................    ,,,,,,,,,,,,,,,,,,
....................C.......
....................C..............
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
....................C....................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
....................C....................
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,t,,,,,,,,,,
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
....................C....................
.........................................
....................C....................
....................C....................
....................C....................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
.........................................
.........................................
.........................................
.........................................
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
....................C....................
....................C....................
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
....................C....................
....................C....................
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
  ,,,,,,,,,,,,,,,,,,c,,,,,,,,,,,,,,,,,,,,
                       ,,,,,,,,,,,,,,,,,,
                       ,,,,,,,,,,,,,,,,,,
  11156711  11156721  11156731
AAGCTCTTTACATTTACTTAATAGATAAGTATTCTTAGGCA
.........................................
..,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
...         ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,       ,,,,,,,,,,,,,,,,,,,,,,,,
............              ...............
................          ,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,        ............
......................                  .
,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
.........................................
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,t,,
.........................................
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
  11156711  11156721  11156731
AAGCTCTTTACATTTACTTAATAGATAAGTATTCTTAGGCA
.........................................
,........................................
,,,,,, ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.......                              ....
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,                             ..
...........
................
,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,
.........................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
.........................................
.........................................
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
.........................................
.........................................
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
.........................................
.........................................
.........................................
 ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
  .......................................
```

:::::::::::::::::::::::::::::::::::::

In the child, more than half of the reads in column 21 carry `C` (upper case on the forward strand, lower case on the reverse); in the father and the mother, every read matches the reference. Many reads, both strands, an allele fraction near one half, and nothing in either parent: what a real heterozygous variant absent from the parents looks like. The `AD` counts of the call are lower than the rows here (child 13 REF and 19 ALT, father 27,0, mother 34,0) because `mpileup` skips duplicates and counts an overlapping read pair once (Episode 5A); `tview` shows every read.

The same site in IGV:

<div class="figure" style="text-align: center">
<img src="fig/08/igv_chr20_11156729.png" alt="IGV window of 62 bases centered on chr20:11,156,729. A variant track at the top has one blue bar at the center; its genotype rows are blue for HG002 and grey for HG003 and HG004. Three read panels follow. In HG002's panel the reads at the top carry a blue C at the center line and the coverage bar there is split blue and green; the reads below match the reference. In HG003's and HG004's panels every read is grey at the center, with only a few scattered mismatches elsewhere. The reference sequence and a solid blue benchmark-region bar run along the bottom."  />
<p class="caption">chr20:11,156,729 A>C in IGV 2.19.2, a de novo candidate supported by both HG002 benchmarks (v5.0q and v4.2.1) and one of the ten candidates in the 47 kb cluster. Tracks, top to bottom: the filtered trio calls (one record; HG002 heterozygous, HG003 and HG004 homozygous reference), then coverage and reads of HG002, HG003 and HG004, the reference sequence, and the trio benchmark regions. The dashed lines mark the site; reads are sorted by their base there. IGV shows every read not marked as a duplicate, so its counts can differ from the AD of mpileup (Episode 5A). The call: HG002 0/1 with AD 13,19 (DP 32), HG003 0/0 with 27,0, HG004 0/0 with 34,0.</p>
</div>

Now the second site:

<!-- kit: extra 08-trio.sh -->
```bash
samtools tview -d T -i -w 41 -p chr20:13604967 results/bam/HG002.markdup.bam ref/GRCh38_no_alt.fa
samtools tview -d T -i -w 41 -p chr20:13604967 results/bam/HG003.markdup.bam ref/GRCh38_no_alt.fa
samtools tview -d T -i -w 41 -p chr20:13604967 results/bam/HG004.markdup.bam ref/GRCh38_no_alt.fa
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
    13604971  13604981  13604991
GTCTACATAAAGACATAATACATATATATATATATATATAT
.........................................
........  ,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,  ..........**..................
,,,,,,,,,               ,,,,,,,,,,,,,,,,,
...............          ,,,,,,,,,,,,,,,,
................         ,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,      ,,,,,,,,,,,,,
.........T.............          ,,,,,,,,
................................       ,,
.....................................
......................................
.........................................
.....................**..................
.....................**..................
.....................****................
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
.....................**..................
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
...A.........T.......**.............A....
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,a,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
.....................**..................
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,a,,a,,,,,,,,,,,,,**,a,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
.....................****................
.....................**..................
.....................**..................
,,,,,,,,,,,,,,,,,,,,,****,,,,,,,,,,,,,,,,
.....................**..................
   ..................**..................
    13604971  13604981  13604991
GTCTACATAAAGACATAATACATATATATATATATATATAT
.........................................
.....         ,,,,,,,**,,,,,,,,,,,,,,,,,,
..........      ,,,,,**,,,,,,,,,,,,,,,,,,
..........             ,,,,,,,,,,,,,,,,,,
.................          ,,,,,,,,c,,,,,
..................          ,,,,,,,,,,,,,
..................          ,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,               ,,,,,,,,
..............................   ,,,,,,,,
..............................    .......
.................................  ,,,,,,
.....................................   .
.........................................
.........................................
.....................**..................
.....................**..................
.....................**..................
,,a,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
t,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
.....................**..................
.....................**..................
.....................**..................
.....................**..................
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,t,,,,,,,**,a,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
.....................**..................
.....................**..................
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
.....................**..................
,,,,,,,,,,,,,,,,,,,,,**,,,a,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
                                    .....
                                        ,
    13604971  13604981  13604991
GTCTACATAAAGACATAATACATATATATATATATATATAT
.........................................
.....        ............................
,,,,,         .......**..................
,,,,,                  ,,,,,,,,,,,,,,,,,,
,,,,,,,                             .....
,,,,,,,                             ,,,,,
,,,,,,,                                ,,
,,,,,,,,,,                             ,,
,,,,,,,,,,,,
,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,c,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.....................**..................
.....................**..................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
...........T.........**..................
.....................**..................
.........................................
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
.........................................
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
.........................................
.....................**..................
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,**,,,,,,,,,,,,,,,,,,
```

:::::::::::::::::::::::::::::::::::::

The deletion removes `ATAT` at the start of a run of 13 `AT` repeats (the reference line of the output). The truth sets record an inherited 2 bp deletion here, inside all their benchmark regions: HG002 `CAT>C` at 13,604,987 with genotype `1|1` (v5.0q), the father, HG003, `CAT>C` at 13,604,987 with genotype `1/1`, and the mother, HG004, `CAT>CATAT,C` at 13,604,987 with genotype `2/1`, one copy of the 2 bp deletion and one 2 bp insertion.

Our calls see that deletion too, in other records at the same position. The workshop's run kit recorded all three records of the filtered calls at chr20:13,604,987 (`GT`, then `DP` and `AD`):

| Record | HG002 (child) | HG003 (father) | HG004 (mother) |
|---|---|---|---|
| `CAT>C`, 2 bp deletion | `1/0`, DP 29, AD 6,20 | `1/1`, DP 31, AD 4,27 | `1/0`, DP 21, AD 3,10 |
| `C>CAT`, 2 bp insertion | `0/0`, AD 6,0 | `0/0`, AD 4,0 | `0/1`, AD 3,8 |
| `CATAT>C`, 4 bp deletion (the candidate) | `0/1`, AD 6,3 | `0/0`, AD 4,0 | `0/0`, AD 3,0 |

For the parents, the first two records agree with the truth sets: the father homozygous for the 2 bp deletion, the mother with one 2 bp deletion and one 2 bp insertion. For the child, the truth sets record two copies of the 2 bp deletion, and our calls one copy plus a 4 bp deletion seen in 3 reads.

Where does the candidate record come from? Before normalization, `bcftools call` wrote **one record** here with three ALT alleles (the 2 bp deletion, the 2 bp insertion and the 4 bp deletion): child `1/3`, father `1/1`, mother `1/2`. `bcftools norm -m -any` split it into one record per ALT allele, and in each record it fills in the reference allele for the other ALT alleles (`--multi-overlaps`, default `0`; Episode 5A, Step 5). So on the 4 bp record the father's `1/1` and the mother's `1/2` both become `0/0`, and the child's `1/3` becomes `0/1`: a child heterozygous, both parents reference, exactly the de novo pattern. `AD` keeps only the REF count and that record's ALT count: the father's 4,0 against a `DP` of 31 says that 27 of his reads support another allele, the 2 bp deletion of the record above.

The de novo expression `GT[0]="het" && GT[1]="RR" && GT[2]="RR"` looks at one record at a time, and cannot see an overlapping allele in a neighboring record. Before trusting a de novo call in a repeat, compare `AD` with `DP` in each parent, and look at the other records at the same position.

<div class="figure" style="text-align: center">
<img src="fig/08/igv_chr20_13604987.png" alt="IGV window of 62 bases centered on chr20:13,604,987, where the reference sequence at the bottom turns into a long run of AT repeats. The variant track at the top shows three stacked blue bars of different lengths starting at the site: about four bases, about two bases, and a thin insertion mark. Below it, the genotype rows are blue for HG002 across the longest bar, cyan for HG003 and blue for HG004 over the shorter bar. Coverage dips at the site in all three samples. In HG002's panel most reads have a short black gap labelled 2 at the site and three reads a longer gap labelled 4; in HG003's panel most reads have the gap labelled 2; in HG004's panel the top eight reads carry a purple insertion mark at the site and many others the gap labelled 2. Further from the site some reads end inside the repeat."  />
<p class="caption">chr20:13,604,987 in IGV 2.19.2, at the start of an AT repeat. Tracks, top to bottom: the filtered trio calls (three overlapping records at this position: the 4 bp deletion that became the de novo candidate, the 2 bp deletion and the 2 bp insertion), then coverage and reads of HG002, HG003 and HG004, the reference sequence, and the trio benchmark regions. The dashed lines mark the site; reads are sorted by their base there. IGV shows every read not marked as a duplicate, so its counts can differ from the AD of mpileup (Episode 5A). Most reads of all three samples carry the 2 bp deletion that the truth sets record as inherited; a few HG002 reads carry the 4 bp deletion, and HG004 reads also carry the 2 bp insertion. On the 4 bp record the call is HG002 0/1 with AD 6,3 (DP 29), HG003 0/0 with 4,0 (DP 31) and HG004 0/0 with 3,0 (DP 21).</p>
</div>

The region step cannot remove this candidate, because the repeat lies inside the benchmark regions. The split also defeats the evidence filter: after `norm` the parents keep their `FORMAT/DP` of 31 and 21, so `MIN(FMT/DP)>=10` holds, but on this record their `AD` is 4,0 and 3,0, so "no ALT read in either parent" holds too.

::::::::::::::::::::::::::::::::::::::: discussion

## Discussion: missing instead of reference

`bcftools norm` can fill in the missing allele instead of the reference allele when it splits a record: `--multi-overlaps .` instead of the default `0`. The workshop keeps the default (Episode 5A); this variant of the command is not run:

<!-- kit: not-run reference -->
```bash
bcftools norm -f ref/GRCh38_no_alt.fa -m -any --multi-overlaps . -Oz -W -o results/vcf/trio.norm.missing.vcf.gz results/vcf/trio.raw.bcf
```

What would it write for the 4 bp record at chr20:13,604,987, and would the de novo genotype filter still select it? What would it cost elsewhere?

::::::::::::::::::::::::::::::::::::: spoiler

## One answer (not tested in the workshop)

On the 4 bp record, the alleles that belong to the other two records become missing instead of reference: the father's `1/1` and the mother's `1/2` become `./.`. `GT[1]="RR"` does not match a missing genotype (Step 3, "Missing is not reference"), so the de novo expression no longer selects the record. The cost: at every split site, a sample that carries another ALT allele gets a partly or fully missing genotype on each record, and every count and filter downstream must handle it.

:::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: spoiler

## Looking at the reads yourself in IGV (self-paced)

IGV ([IGV desktop](https://igv.org/doc/desktop/)) shows the same reads graphically. It needs a graphical desktop: on the Negishi Gateway (Open OnDemand), start the **Desktop** app (partition `cpu`, QoS `standby`, wall time up to 4 hours under standby); it takes 2 to 3 minutes to start. In a terminal inside that desktop:

<!-- kit: not-run desktop -->
```bash
module load biocontainers
module load igv/2.19.1
igv.sh &
```

<!-- TBD(P6 Part C): seconds from igv.sh to the IGV main window (docs/ood_igv_check.md, operator fills it); the only IGV timing in this note (decision 8: IGV runtime n/a, not a timed live job). -->

Then, in IGV: **Genomes > Load Genome from File** and choose `ref/GRCh38_no_alt.fa` in your workshop directory; **File > Load from File** and choose the three BAM files in `results/bam/`, `results/vcf/trio.filtered.vcf.gz` and `resources/truth/trio_v4.2.1_chr20.bed`; type `chr20:11156699-11156759` in the locus box. The module runs IGV 2.19.2 (module igv/2.19.1: the version IGV reports at startup). The figures in this episode were made the same way, from an IGV batch script ([IGV batch commands](https://igv.org/doc/desktop/UserGuide/tools/batch/)).

:::::::::::::::::::::::::::::::::::::

Type `exit` to leave the interactive session.

::::::::::::::::::::::::::::::::::::::: callout

## Short on time?

If your annotation or trio session did not finish, copy the annotated calls and the trio results from the results copy, and read the outputs above:

<!-- kit: not-run fallback -->
```bash
cp /depot/workshop/data/varcall-workshop_results/results/annot/trio.ann.vcf.gz* $SCRATCH/varcall-workshop/results/annot/
cp /depot/workshop/data/varcall-workshop_results/results/trio/*.vcf.gz* $SCRATCH/varcall-workshop/results/trio/
cp /depot/workshop/data/varcall-workshop_results/results/trio/*.tsv $SCRATCH/varcall-workshop/results/trio/
cp /depot/workshop/data/varcall-workshop_results/results/trio/mendelian2.txt $SCRATCH/varcall-workshop/results/trio/
```

:::::::::::::::::::::::::::::::::::::::

## Step 8: What the evidence supports

A written interpretation separates two questions that are easy to mix up:

1. **Call quality:** is the variant really in the DNA we sequenced? Evidence: reads, genotype quality, depth in every sample, the parents' reads, the region, a truth set if one exists, and in the end an independent assay.
2. **Biological significance:** if it is real, does it matter? Evidence: predicted consequence, population frequency, prior reports, and, far beyond this workshop, functional and clinical studies.

A template for this analysis:

::::::::::::::::::::::::::::::::::::::: callout

## Interpretation template

- **Data:** HG002 (child), HG003 (father), HG004 (mother); Illumina short reads, chromosome 20 only, about 40x; bcftools 1.24 calls, filtered as in Episode 6.
- **QC:** sample order and relationships checked; Mendelian error rate 0.31% of evaluable PASS sites.
- **Filters, in order:** genotype pattern; GQ at least 20 and DP at least 10 in all three samples, and no parental ALT reads (de novo); trio benchmark regions; `HIGH` or `MODERATE` predicted impact (SnpEff, MANE 1.2); gnomAD v4.1 below 1% overall and in the Ashkenazi group.
- **Result:** de novo 312, 81, 41, 0, 0; recessive 5,282, 5,282, 4,632, 8, 0. No candidate remains.
- **Call quality:** 34 of the 41 de novo candidates after the region step are supported by the GIAB v4.2.1 benchmark, 7 of them also by v5.0q (the other 27 are outside the v5.0q benchmark regions); at clonal allele fractions in DNA from a cell line, their origin (germline or cell line) cannot be determined from these data.
- **Justified conclusion:** with these filters, the data contain no rare, protein-altering candidate for either model on chromosome 20. Had candidates remained, the justified output would be a ranked list for orthogonal validation (for example Sanger sequencing or a second technology), with the filters stated.
- **Not justified:** any claim of pathogenicity or causation, and any statement about the health of the people who provided these samples.

:::::::::::::::::::::::::::::::::::::::

Why so careful, even with a candidate in hand? Healthy people each carry about 100 predicted loss-of-function variants, with about 20 genes inactivated in both copies ([MacArthur et al. 2012](https://doi.org/10.1126/science.1215040)). A rare variant that looks damaging is common in a healthy genome. It is a reason to look further, not a diagnosis.

::::::::::::::::::::::::::::::::::::::: discussion

## Discussion: one candidate left

Suppose a looser frequency threshold (5% instead of 1%) had left one recessive candidate: a `MODERATE` missense variant, homozygous in the child, at 2% in gnomAD's Ashkenazi group. What would you write about it? What would you check before writing anything?

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: spoiler

## Compound heterozygotes (self-paced, concept only)

A recessive condition can also come from two *different* variants in the same gene, one inherited from each parent: the child is heterozygous for both, a **compound heterozygote**. Finding them takes a step our funnel does not have: group the child's heterozygous candidates by gene, and keep genes with at least one variant from the father (father heterozygous, mother `0/0`) and at least one from the mother (the reverse). The parents' genotypes phase the child's variants, which is a second advantage of a trio. The workshop's scripts do not include this step.

:::::::::::::::::::::::::::::::::::::

## Confounders and common mistakes

| Mistake or confounder | What it does | What to do |
|---|---|---|
| wrong sample order | a de novo filter selects something else | `bcftools query -l` against the PED file, every time |
| missing genotypes treated as reference | candidates resting on a parent with no confident genotype | match `RR` explicitly; never convert `./.` to `0/0` |
| site-level instead of genotype-level evidence | enough reads at the site, too few in a parent | `FMT/DP`, `FMT/GQ` and `FMT/AD` per sample |
| low parental coverage | a heterozygous parent looks `0/0` | require parental depth and zero parental ALT reads |
| deletions and copy-number changes | apparent Mendelian errors, false homozygosity | check depth across the region; look at the reads |
| repeats, segmental duplications, reference errors | mis-mapped reads make variants that are not there | restrict to confident regions; inspect the reads |
| parental mosaicism | a parent carries the variant in some cells, with a few ALT reads | do not dismiss parental ALT reads as noise |
| sample swaps | relationships are not what the PED file says | check relationships (`gtcheck`, kinship) |
| cell-line DNA | cell-line mutations look like de novo variants | know where the DNA came from; validate in another tissue |
| global frequency for an Ashkenazi individual | founder variants look rare | use the ancestry-matched group as well |
| the transcript chosen during annotation | a variant is coding in one transcript, not another | know which transcript set you used (MANE here) |
| thresholds tuned until a "nice" list appears | the list reflects the filters, not the data | set thresholds before looking; report them |
| overinterpretation | a candidate becomes a diagnosis | separate call quality from significance; validate |

## Summary

::::::::::::::::::::::::::::::::::::: keypoints

- Check sample order (`bcftools query -l`) and relationships before any trio filter: genotype expressions name samples by column.
- The Mendelian error rate (here 0.31% of evaluable PASS sites) is a quality measure that needs a family, not a truth set; de novo variants are drawn from the same sites as the errors.
- Missing genotypes are not reference genotypes; evidence filters must hold in every sample, at the genotype level.
- Report a funnel: what each filter removed and why. Both funnels here end at zero, and an empty list is a valid result.
- Base rates come first: about 1.5 germline de novo SNVs are expected on chromosome 20, so hundreds of naive candidates are almost all errors.
- The truth-supported candidates left after quality filters are real in the sequenced DNA but most likely cell-line mutations; reads from cell-line DNA cannot settle their origin.
- A candidate list justifies validation, not a statement about pathogenicity, causation or anyone's health.

::::::::::::::::::::::::::::::::::::::::::::::::
