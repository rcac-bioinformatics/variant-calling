---
source: Rmd
title: '6\. Filtering and evaluating variant calls'
teaching: 40
exercises: 40
---

:::::::::::::::::::::::::::::::::::::: questions

- How do we summarize a call set?
- How do we choose and apply filters?
- How good are our calls, and how do we know?
- What can we measure when there is no truth set?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Summarize a call set (counts, Ts/Tv, het/hom-alt ratio, indel lengths, depth and QUAL distributions).
- Apply soft filters at the site and genotype levels.
- Measure precision and recall against a GIAB benchmark in its confident regions.
- Explain the precision-recall trade-off of a threshold and why indels and difficult regions do worse.
- Choose proxy measures when no truth set exists.

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

The caller reports every site where the evidence favors a variant, including many that are wrong. In this episode we decide which calls to trust. We look at the distributions of the quality measures, choose thresholds from them, and label the calls that fail. Then we measure how good the calls are, before and after filtering, against the Genome in a Bottle benchmark for HG002, and look at what we can measure when no benchmark exists.

The order matters: **thresholds come from the call set, and the benchmark only evaluates them.** Choosing a threshold because it scores best against the benchmark would tune the filters to the answer key, and the score would no longer tell us how well they work on other data.

::::::::::::::::::::::::::::::::::::::: prereq

## Before you start

You need `results/vcf/trio.norm.vcf.gz` and its index from Episode 5A, and the script `scripts/evaluate.sh`. If you do not have them, use the "Short on time?" copy at the end of Episode 5A.

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: instructor

Live path (60 minutes; plan section 4, with hap.py running in the background):

| Minutes | Section | Live or self-paced |
|---|---|---|
| 5 | Step 1: session and distributions | live |
| 10 | Step 2: thresholds from the distributions; the filter commands | live |
| 7 | Step 3: site and genotype filters, and what they changed | live |
| 3 | Step 4: submit task 1 of `evaluate.sh`; copy the other three tasks' results | live |
| 10 | While hap.py runs: Ts/Tv inside and outside the benchmark (end of Step 3); benchmarks, precision and recall | live |
| 10 | Step 5: reading `summary.csv`; the genotype mask and the site filters | live |
| 7 | Challenge "Predict, then test a QUAL threshold" and the leakage callout | live |
| 8 | Discussion "Same calls, two benchmarks"; proxies without a truth set | live, discussion |

Self-paced: the challenge "Predict the filters", the Ts/Tv challenge with PASS calls, the challenge "Same calls, two benchmarks" (the live session uses it as a discussion), and the sections on stratification and on proxies beyond Ts/Tv.

:::::::::::::::::::::::::::::::::::::::::::::::::

## Step 1: Look at the distributions

Start an interactive session and write two tables: the site-level QUAL, depth (`INFO/DP`) and mean mapping quality (`INFO/MQ`) of every record, and the depth and GQ of every genotype:

<!-- kit: interactive 06-filter.sh -->
```bash
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load bcftools/1.24
cd $SCRATCH/varcall-workshop
VCF=results/vcf/trio.norm.vcf.gz
mkdir -p results/vcf/stats
bcftools query -f '%QUAL\t%INFO/DP\t%INFO/MQ\n' $VCF > results/vcf/stats/site_qual_dp_mq.tsv
bcftools query -f '[%SAMPLE\t%GT\t%DP\t%GQ\n]' $VCF > results/vcf/stats/genotype_dp_gq.tsv
```

The `[...]` in the second format repeats for each sample, so that table has one line per sample per record. Summarize the site table with a few percentiles: sort one column, then print the values 1%, 5%, 50%, 95% and 99% of the way through:

<!-- kit: extra 06-filter.sh -->
```bash
cut -f1 results/vcf/stats/site_qual_dp_mq.tsv | sort -g | awk '{ v[NR] = $1 } END { print "QUAL", "p01", v[int(NR * 0.01)], "p05", v[int(NR * 0.05)], "p50", v[int(NR * 0.5)], "p95", v[int(NR * 0.95)], "p99", v[int(NR * 0.99)] }'
cut -f2 results/vcf/stats/site_qual_dp_mq.tsv | sort -g | awk '{ v[NR] = $1 } END { print "DP", "p01", v[int(NR * 0.01)], "p05", v[int(NR * 0.05)], "p50", v[int(NR * 0.5)], "p95", v[int(NR * 0.95)], "p99", v[int(NR * 0.99)] }'
cut -f3 results/vcf/stats/site_qual_dp_mq.tsv | sort -g | awk '{ v[NR] = $1 } END { print "MQ", "p01", v[int(NR * 0.01)], "p05", v[int(NR * 0.05)], "p50", v[int(NR * 0.5)], "p95", v[int(NR * 0.95)], "p99", v[int(NR * 0.99)] }'
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
QUAL p01 6.9928 p05 38.8882 p50 469.376 p95 739.009 p99 741.877
DP p01 19 p05 69 p50 113 p95 358 p99 668
MQ p01 11 p05 35 p50 60 p95 60 p99 60
```

:::::::::::::::::::::::::::::::::::::

Read each line as a shape:

- **QUAL** has a long low tail: most sites are far above 30, but the lowest few percent are not (p05 is 38.9 and p01 7.0).
- **Depth** has a long high tail: the median site depth (all three samples together) is close to three times the 39x of each sample, but p95 and p99 are several times the median (median 113, p95 358, p99 668). Sites with far more reads than the genome has copies are typical of reads from several places piled onto one, as in collapsed repeats (Episode 5A).
- **MQ**, the mean mapping quality of the reads at a site, sits at 60 for most sites and has a low tail where reads may come from elsewhere in the genome (Episode 4).

## Step 2: Choose thresholds from the data

Each filter targets one of those tails, with a threshold set by a rule or a convention, not by the benchmark:

| Filter | Rule | Why this value |
|---|---|---|
| `LowQual`: `QUAL < 30` | a convention | QUAL is Phred-scaled (Episode 5A): 30 means a 1 in 1,000 chance that the site is not variant at all. It cuts the low tail |
| `HighDP`: `INFO/DP` above twice the median site depth | a rule, computed from your own calls | at twice the expected depth, more reads arrive than two copies of the sequence explain. The value adapts to any depth, so the rule carries over to other data |
| `LowMQ`: `INFO/MQ < 30` | a convention | MAPQ is Phred-scaled ([SAM specification](https://samtools.github.io/hts-specs/SAMv1.pdf)): MAPQ 30 means a 1 in 1,000 chance that a read is misplaced. A site whose reads average below 30 has many reads placed with little confidence |
| genotype mask: `FMT/DP < 10` or `FMT/GQ < 20` | conventions | with fewer than 10 reads, a heterozygous site looks homozygous about 0.2% of the time (2 x 0.5^10 = 0.195%, Episode 1); GQ 20 is a 1% chance that the genotype is wrong |

The depth threshold is computed in the next block: sort the site depths, take the middle value, double it.

<!-- kit: interactive 06-filter.sh -->
```bash
# The depth cutoff follows a rule, not the benchmark: flag sites deeper than twice the median
MEDIAN_DP=$(cut -f2 results/vcf/stats/site_qual_dp_mq.tsv | sort -n | awk '{ d[NR] = $1 } END { print d[int((NR + 1) / 2)] }')
MAX_DP=$((2 * MEDIAN_DP))
echo "median site depth $MEDIAN_DP; sites above $MAX_DP are flagged HighDP"
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
median site depth 113; sites above 226 are flagged HighDP
```

In the reference run the median site depth was 113, so `MAX_DP` was 226. Yours is computed from your own calls, so if your calls differ, so does the threshold.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: predict the filters

Before applying the filters, count how many sites each site filter will flag, and how many genotypes the mask will set to missing in each sample:

<!-- kit: extra 06-filter.sh -->
```bash
awk '$1 < 30' results/vcf/stats/site_qual_dp_mq.tsv | wc -l
awk -v max=$MAX_DP '$2 > max' results/vcf/stats/site_qual_dp_mq.tsv | wc -l
awk '$3 < 30' results/vcf/stats/site_qual_dp_mq.tsv | wc -l
awk '$3 < 10 || $4 < 20' results/vcf/stats/genotype_dp_gq.tsv | cut -f1 | sort | uniq -c
```

1. Which site filter flags the most sites?
2. Will the three site filters together flag the sum of the three counts? Why or why not?
3. The last command counts genotypes with low depth or low GQ. Will the mask set exactly these genotypes to missing?

::::::::::::::::::::::::::::::::::: solution

```output
7622
17821
6407
  11564 HG002
  10934 HG003
  11167 HG004
```

1. `HighDP`: 17,821 sites, against 7,622 with QUAL below 30 and 6,407 with MQ below 30.
2. No. A site can fail more than one filter, and it is counted once in each list. Step 3 shows the combinations.
3. Yes. Compare with the `nMissing` counts in Step 3: they are the same numbers (HG002 11,564, HG003 10,934, HG004 11,167). The count includes the genotypes that were already missing before filtering (Episode 5A; 298 in HG002), which have low depth too; the mask sets the others to missing. In the workshop's test run, most of HG002's newly masked genotypes failed on GQ alone (7,639 of 11,266), 1,920 on depth alone and 1,707 on both.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

## Step 3: Site-level and genotype-level filters

Apply the filters. The first three commands label sites; the last one masks genotypes:

<!-- kit: interactive 06-filter.sh -->
```bash
# 2. Site filters add a label to FILTER and keep the record; the genotype filter sets
#    genotypes with DP < 10 or GQ < 20 to missing (./.)
bcftools filter -m+ -s LowQual -e 'QUAL<30' -Ou $VCF \
  | bcftools filter -m+ -s HighDP -e "INFO/DP>$MAX_DP" -Ou \
  | bcftools filter -m+ -s LowMQ -e 'INFO/MQ<30' -Ou \
  | bcftools filter -S . -e 'FMT/DP<10 | FMT/GQ<20' -Oz -W -o results/vcf/trio.filtered.vcf.gz
```

What each part does ([bcftools manual, `filter`](https://samtools.github.io/bcftools/bcftools.html#filter), and the 1.24 usage text):

- **`-e EXPR`** names what *fails*: records for which the expression is true. (`-i` is the opposite: it names what passes. Swapping them inverts a filter.)
- **`-s NAME`** makes a **soft filter**: a failing record gets `NAME` in its FILTER column and stays in the file. A record that passes gets `PASS`. Without `-s` (and without `-S`), failing records would be deleted: a **hard filter**, which you cannot undo or inspect later.
- **`-m+`** adds the new label to labels already there ("do not replace but add to existing FILTER"), so a site that fails two filters reads `LowQual;HighDP`.
- The first three filters read **site-level** values: `QUAL`, and `INFO/DP` and `INFO/MQ`, which describe all reads at the site, from all three samples.
- The last command reads **genotype-level** values: `FMT/DP` and `FMT/GQ`, one per sample. With `-S .` it sets the genotypes of the failing samples to missing (`./.`), and it has no `-s`, so it adds no FILTER label and removes no record.

How does an expression on FORMAT fields combine across three samples? The bcftools manual says that with a single `&` or `|`, both conditions are tested within one sample, and the expression selects the samples for which it is true; `&&` and `||` let the conditions be met in different samples. So `FMT/DP<10 | FMT/GQ<20` selects each sample whose own depth is below 10 or whose own GQ is below 20, and `-S .` masks exactly those samples' genotypes. The other samples at the same site keep their calls.

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
```

:::::::::::::::::::::::::::::::::::::

Now count the labels in the FILTER column (column 7):

<!-- kit: interactive 06-filter.sh -->
```bash
bcftools view -H results/vcf/trio.filtered.vcf.gz | cut -f7 | sort | uniq -c
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
  15725 HighDP
   1118 HighDP;LowMQ
   3298 LowMQ
   4818 LowQual
    813 LowQual;HighDP
    165 LowQual;HighDP;LowMQ
   1826 LowQual;LowMQ
 158151 PASS
```

Every record is still there: the counts add up to the number of records before filtering (185,914 before, 185,914 after). 158,151 records PASS; `HighDP` alone flags 15,725, `LowQual` alone 4,818, `LowMQ` alone 3,298, and 3,922 records carry more than one label.

:::::::::::::::::::::::::::::::::::::

The mask shows up in the per-sample counts. Compare the `nMissing` column (the last one) with the same lines before filtering, in Episode 5A:

<!-- kit: extra 06-filter.sh -->
```bash
bcftools stats -s - results/vcf/trio.filtered.vcf.gz | grep ^PSC
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
PSC	0	HG002	40969	29704	84671	74303	40072	19006	44.0	4551	0	0	11564
PSC	0	HG003	43532	27512	85191	73164	39539	18745	43.9	19109	0	0	10934
PSC	0	HG004	42055	28711	84859	73732	39838	19122	43.5	20257	0	0	11167
```

Missing genotypes per sample, before and after the mask: HG002 298 before, 11,564 after; HG003 262 before, 10,934 after; HG004 449 before, 11,167 after. The other columns of these lines count only genotypes that are still called, so they drop by the same amount.

:::::::::::::::::::::::::::::::::::::

Finally, summarize the records that PASS, as Episode 5A did for all records:

<!-- kit: interactive 06-filter.sh -->
```bash
bcftools stats -f PASS -s - results/vcf/trio.filtered.vcf.gz > results/vcf/trio.filtered.stats.txt
grep -E '^(SN|TSTV)' results/vcf/trio.filtered.stats.txt
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
SN	0	number of samples:	3
SN	0	number of records:	158151
SN	0	number of no-ALTs:	0
SN	0	number of SNPs:	129329
SN	0	number of MNPs:	0
SN	0	number of indels:	28822
SN	0	number of others:	0
SN	0	number of multiallelic sites:	0
SN	0	number of multiallelic SNP sites:	0
TSTV	0	86429	42900	2.01	86429	42900	2.01
```

158,151 PASS records, 129,329 SNVs and 28,822 indels. Ts/Tv rises from 1.81 for all records to 2.01 for the PASS records.

:::::::::::::::::::::::::::::::::::::

### What Ts/Tv tells us

A **transition** exchanges a purine for a purine or a pyrimidine for a pyrimidine (A and G, C and T); a **transversion** is any other change. Of the three possible changes at a base, one is a transition and two are transversions, so random errors give a Ts/Tv near 0.5. Real human germline variation has more transitions than transversions: in the HG002 benchmark's own SNVs on chromosome 20, Ts/Tv is 2.31 inside the v4.2.1 regions (reference run, `TRUTH.TOTAL.TiTv_ratio`). A call set with many errors has a Ts/Tv pulled toward 0.5. That is why filtering raised it from 1.81 to 2.01: the filters removed relatively more transversions, the signature of errors. Ts/Tv works only as a comparison (before and after, inside and outside, one sample against another); it does not say how many calls are wrong.

### Ts/Tv inside and outside the benchmark regions

The last two commands of the session compute Ts/Tv for HG002's calls (raw, before filtering) inside the regions where the v4.2.1 benchmark is confident (`-T` with the BED file), and outside them (`^` negates the regions):

<!-- kit: interactive 06-filter.sh -->
```bash
# 3. Ts/Tv of HG002's raw calls inside and outside the benchmark regions (^ means outside)
bcftools view -s HG002 -c 1 -Ou $VCF | bcftools stats -T resources/truth/HG002_v4.2.1_chr20.bed - | grep ^TSTV
bcftools view -s HG002 -c 1 -Ou $VCF | bcftools stats -T ^resources/truth/HG002_v4.2.1_chr20.bed - | grep ^TSTV
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
TSTV	0	50100	21960	2.28	50100	21960	2.28
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
TSTV	0	26876	20920	1.28	26876	20920	1.28
```

Each line gives the numbers of transitions and transversions, then their ratio. Inside the benchmark regions it is close to the truth set's 2.31; outside, it is far lower (2.28 inside, 1.28 outside).

:::::::::::::::::::::::::::::::::::::

`view -s HG002 -c 1` keeps HG002's column and only the records where HG002 carries at least one ALT allele (Step 4 explains why). The benchmark regions are where NIST is confident it knows the truth; outside them lies sequence that NIST could not yet characterize, which includes difficult repeats ("Same calls, two benchmarks" below returns to this). A low Ts/Tv outside means many of the calls there are errors, and that is where a benchmark cannot score them.

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: do the filters help where the benchmark cannot look?

Repeat the two commands for HG002's PASS calls. `-f PASS` keeps only records that pass every filter, and `-Ou` passes the result through the pipe:

<!-- kit: extra 06-filter.sh -->
```bash
bcftools view -s HG002 -c 1 -f PASS -Ou results/vcf/trio.filtered.vcf.gz | bcftools stats -T resources/truth/HG002_v4.2.1_chr20.bed - | grep ^TSTV
bcftools view -s HG002 -c 1 -f PASS -Ou results/vcf/trio.filtered.vcf.gz | bcftools stats -T ^resources/truth/HG002_v4.2.1_chr20.bed - | grep ^TSTV
```

1. How does Ts/Tv change inside and outside the benchmark regions after filtering?
2. Why does it change more outside?
3. The staged file `resources/regions/chr20_centromere.bed` holds the centromere of chromosome 20. Write the command for HG002's raw calls in the centromere, and predict the result.

::::::::::::::::::::::::::::::::::: solution

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
TSTV	0	49743	21630	2.30	49743	21630	2.30
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
TSTV	0	15059	10458	1.44	15059	10458	1.44
```

1. Inside, it barely moves (2.28 to 2.30); outside, it rises (1.28 to 1.44).
2. Inside the benchmark regions few calls are wrong, so there is little to remove. Outside, many calls are errors, and the filters remove relatively more of them. The benchmark could never show this, because it does not score calls outside its regions.
3. Replace the BED file:

   <!-- kit: extra 06-filter.sh -->
   ```bash
   bcftools view -s HG002 -c 1 -Ou $VCF | bcftools stats -T resources/regions/chr20_centromere.bed - | grep ^TSTV
   ```

   ```output
   [W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
   [W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
   TSTV	0	14759	12135	1.22	14759	12135	1.22
   ```

   HG002 has 26,894 raw SNVs in the centromere (14,759 transitions plus 12,135 transversions), 22% of its 119,856 SNVs in 5.6% of the chromosome, with Ts/Tv 1.22. In the reference run, 12,390 of them PASS after filtering, with Ts/Tv 1.36: still far from 2.3. The filters remove many calls there and improve the ratio, but many remaining calls in the centromere are likely errors.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

Type `exit` to leave the interactive session.

::::::::::::::::::::::::::::::::::::::: callout

## Short on time?

If filtering did not finish, copy the filtered calls and the tables from the results copy:

<!-- kit: not-run fallback -->
```bash
cp /depot/workshop/data/varcall-workshop_results/results/vcf/trio.filtered.vcf.gz* $SCRATCH/varcall-workshop/results/vcf/
cp /depot/workshop/data/varcall-workshop_results/results/vcf/trio.filtered.stats.txt $SCRATCH/varcall-workshop/results/vcf/
```

:::::::::::::::::::::::::::::::::::::::

## Benchmarking against Genome in a Bottle

To measure accuracy we need the right answer. For HG002, NIST publishes **benchmark** variant calls and the **confident regions** (a BED file) where it vouches for them ([Genome in a Bottle](https://www.nist.gov/programs-projects/genome-bottle)). Inside those regions, every variant in the benchmark is real, and every position not in it is homozygous reference. Outside them, the benchmark says nothing.

Comparing our calls with the benchmark sorts them into:

- **true positives (TP)**: in both;
- **false positives (FP)**: in our calls, not in the benchmark;
- **false negatives (FN)**: in the benchmark, missed by our calls.

From these ([Krusche et al. 2019](https://doi.org/10.1038/s41587-019-0054-x)):

- **precision** = TP / (TP + FP): the fraction of our calls that are right;
- **recall** = TP / (TP + FN): the fraction of real variants we found;
- **F1** = 2 x precision x recall / (precision + recall): one number that is high only if both are.

A variant called with the wrong genotype (for example `0/1` where the benchmark says `1/1`) counts as both a false positive and a false negative.

### Comparing variants is harder than comparing positions

The same variant can be written in several ways (Episode 5A), especially indels in repeats and nearby variants that can be grouped differently. **hap.py** with the **vcfeval** engine compares the haplotypes, the sequences the variants produce, rather than the text of the records, so equivalent representations match ([hap.py documentation](https://github.com/Illumina/hap.py/blob/master/doc/happy.md)). Normalization still matters for everything that compares records by position and allele: counting variants, merging files, and tools such as `bcftools isec`.

## Step 4: Evaluate with hap.py

This is `scripts/evaluate.sh`:

<!-- kit: script evaluate.sh -->
```bash
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
```

The four array tasks are the four lines of `resources/truth/truth_sets.tsv`: task 1 is HG002 against benchmark v5.0q (NIST's current release for HG002), task 2 HG002 against v4.2.1 (for comparison), and tasks 3 and 4 HG003 and HG004 against v4.2.1. Each task evaluates the calls twice, before filtering (`trio.norm`) and after (`trio.filtered`). In the workshop's test runs each task took 1.5 to 2.5 minutes, plus the time waiting in the queue.

In the workshop, submit task 1 only. `--array=1` on the command line replaces the `--array=1-4` of the script:

<!-- kit: interactive 06-evaluate-summary.sh -->
```bash
cd $SCRATCH/varcall-workshop/scripts
sbatch --array=1 evaluate.sh
```

Then copy the results of the other three tasks from the completed results, so that Step 5 can compare all four:

<!-- kit: not-run fallback -->
```bash
cp /depot/workshop/data/varcall-workshop_results/results/eval/HG002.v4.2.1.* $SCRATCH/varcall-workshop/results/eval/
cp /depot/workshop/data/varcall-workshop_results/results/eval/HG003.v4.2.1.* $SCRATCH/varcall-workshop/results/eval/
cp /depot/workshop/data/varcall-workshop_results/results/eval/HG004.v4.2.1.* $SCRATCH/varcall-workshop/results/eval/
```

Working on your own, submit all four tasks instead:

<!-- kit: submit evaluate.sh -->
```bash
cd $SCRATCH/varcall-workshop/scripts
sbatch evaluate.sh
```

What the commands do:

- **`bcftools view -s $SAMPLE -c 1`**: hap.py compares one sample with one benchmark, so we give it one sample's column. `-c 1` keeps only records where that sample carries at least one ALT allele; the trio file also has records where this sample is `0/0` or masked (`./.`), which are not calls for this sample.
- **`-f $TRUTH_BED`**: the confident regions. hap.py counts query calls outside them as **UNK** (not assessed), not as false positives, so precision says nothing about calls outside the regions. Without `-f`, every call outside the benchmark's knowledge would count against us. For example, HG002's `1/1` call at chr20:29,070,822 in the centromere (FILTER `HighDP;LowMQ`) lies outside both HG002 benchmark regions, so in the evaluation of the unfiltered calls hap.py counts it as UNK, whether it is real or not.
- **`-l chr20`**: compare chromosome 20 only. hap.py otherwise processes chr1-22, X and Y; with a whole-genome benchmark, every benchmark variant on another chromosome would become a false negative.
- **`--engine vcfeval --engine-vcfeval-template $SDF`**: the haplotype-aware comparison, with the reference in the format it needs (`ref/GRCh38_no_alt.sdf`, prepared for the workshop).
- **`--roc QUAL`**: also compute precision and recall at every QUAL threshold (Step 6).
- **24 cores, 16 threads**: hap.py's memory use varies from run to run. In the workshop's test runs the same task peaked anywhere between 1 and 39 GiB, more than the memory that comes with 16 cores, so the script requests 24 cores for their memory and runs 16 threads. The HG002 v5.0q task (task 1) peaked at 4.4 GiB in the latest test run and never above 10.2 GiB in five runs. The script also sets `RTG_MEM`, the memory setting of RTG Tools, whose vcfeval engine hap.py runs; whether it limits the peak has not been confirmed.

::::::::::::::::::::::::::::::::::::::: callout

## Short on time?

If your evaluation job fails or is still waiting when we reach Step 5, copy the hap.py summaries and ROC tables from the results copy:

<!-- kit: not-run fallback -->
```bash
cp /depot/workshop/data/varcall-workshop_results/results/eval/*.summary.csv $SCRATCH/varcall-workshop/results/eval/
cp /depot/workshop/data/varcall-workshop_results/results/eval/*.roc.Locations.*.csv.gz $SCRATCH/varcall-workshop/results/eval/
```

:::::::::::::::::::::::::::::::::::::::

## Step 5: Read the hap.py summary

When `squeue -u $USER` no longer lists the `evaluate` job, look at the results on the login node. `column` aligns the comma-separated fields, and `cut -c1-120` keeps the lines on screen:

<!-- kit: interactive 06-evaluate-summary.sh -->
```bash
cd $SCRATCH/varcall-workshop
ls results/eval/*.summary.csv
column -s, -t results/eval/HG002.v5.0q.norm.summary.csv | cut -c1-120
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
results/eval/HG002.v4.2.1.filtered.summary.csv
results/eval/HG002.v4.2.1.norm.summary.csv
results/eval/HG002.v5.0q.filtered.summary.csv
results/eval/HG002.v5.0q.norm.summary.csv
results/eval/HG003.v4.2.1.filtered.summary.csv
results/eval/HG003.v4.2.1.norm.summary.csv
results/eval/HG004.v4.2.1.filtered.summary.csv
results/eval/HG004.v4.2.1.norm.summary.csv
Type   Filter  TRUTH.TOTAL  TRUTH.TP  TRUTH.FN  QUERY.TOTAL  QUERY.FP  QUERY.UNK  FP.gt  METRIC.Recall  METRIC.Precision
INDEL  ALL     18173        15261     2912      20265        2245      2731       1737   0.839762       0.871963
INDEL  PASS    18173        15261     2912      20265        2245      2731       1737   0.839762       0.871963
SNP    ALL     75854        74963     891       119754       1570      43202      286    0.988254       0.979491
SNP    PASS    75854        74963     891       119754       1570      43202      286    0.988254       0.979491
```

:::::::::::::::::::::::::::::::::::::

Each row is one variant type (`INDEL`, `SNP`) and one set of calls: `ALL` counts every call, `PASS` only calls with `PASS` in FILTER. Before filtering there is no FILTER label, so the two rows are the same. The columns ([hap.py documentation](https://github.com/Illumina/hap.py/blob/master/doc/happy.md)):

| Column | Meaning |
|---|---|
| `TRUTH.TOTAL` | benchmark variants in the confident regions |
| `TRUTH.TP`, `TRUTH.FN` | benchmark variants we found, and missed |
| `QUERY.TOTAL` | our calls for HG002 |
| `QUERY.FP` | our calls inside the confident regions that the benchmark does not support |
| `QUERY.UNK` | our calls outside the confident regions: not assessed |
| `FP.gt` | false positives where the variant is right but the genotype is wrong |
| `METRIC.Recall`, `METRIC.Precision` | as defined above |

`METRIC.F1_Score` is further to the right, past the 120 characters shown. For the unfiltered calls against v5.0q, SNV recall and precision are 0.9883 and 0.9795, and indel 0.8398 and 0.8720: indels are much harder.

Now the filtered calls:

<!-- kit: interactive 06-evaluate-summary.sh -->
```bash
column -s, -t results/eval/HG002.v5.0q.filtered.summary.csv | cut -c1-120
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
Type   Filter  TRUTH.TOTAL  TRUTH.TP  TRUTH.FN  QUERY.TOTAL  QUERY.FP  QUERY.UNK  FP.gt  METRIC.Recall  METRIC.Precision
INDEL  ALL     18173        14248     3925      17615        1133      2213       782    0.78402        0.926438
INDEL  PASS    18173        14161     4012      16823        1060      1575       768    0.779233       0.930483
SNP    ALL     75854        74596     1258      114284       1065      38614      173    0.983416       0.985926
SNP    PASS    75854        74383     1471      96848        848       21609      159    0.980607       0.988729
```

The `PASS` rows are the frozen values of this workshop: SNV recall 0.980607 and precision 0.988729, indel recall 0.779233 and precision 0.930483.

:::::::::::::::::::::::::::::::::::::

The figure puts both summaries and the ROC tables of Step 6 on one plot. Each curve shows the unfiltered calls filtered at every possible QUAL threshold: high thresholds sit at the left (few calls kept, low recall), no threshold at the right end. The two points are the `PASS` rows above.

<div class="figure" style="text-align: center">
<img src="fig/06/pr_hg002_v5.0q.png" alt="Line plot of precision (y axis, 0.868 to 1.0) against recall (x axis, 0 to 1). A solid blue SNV curve runs almost flat near precision 0.995 to 1.0 from recall 0 to about 0.97, then drops steeply to 0.979 at recall 0.988; a blue circle marks the SNV PASS point at recall 0.981, precision 0.989. A dashed red indel curve starts near precision 0.998 at recall 0.06, falls to about 0.935 by recall 0.16, wanders between 0.90 and 0.92 up to recall 0.75, and drops to 0.872 at recall 0.84; a red square marks the indel PASS point at recall 0.779, precision 0.930, above the dashed curve."  />
<p class="caption">Precision against recall for HG002's calls against benchmark v5.0q, chromosome 20, from the workshop's test run (drawn by the run kit from the hap.py ROC tables and summary; not a learner command). The precision axis starts at 0.868, not 0. SNVs keep precision above 0.98 almost all the way to recall 0.98. Indels reach recall 0.84 at best, and their precision falls below 0.90 as recall rises. The indel PASS point (recall 0.779, precision 0.930) lies above the indel curve: the genotype mask and site filters give higher precision at that recall than any QUAL threshold alone.</p>
</div>

### Two filters, two effects

The filtered file differs from the unfiltered one in two ways, and the summary separates them:

- the **`ALL` row of the filtered file** counts every record, whatever its FILTER label, but with the genotype mask applied (masked genotypes are gone, because `-c 1` drops `./.`);
- the **`PASS` row** adds the site filters.

So unfiltered `ALL` against filtered `ALL` shows the genotype mask alone, and filtered `ALL` against filtered `PASS` shows the site filters. The reference run, against v4.2.1 (comparison benchmark; [reference-run memo](https://github.com/rcac-bioinformatics/variant-calling/blob/main/maintenance/plan/reference-run.md), section 4):

| Type | Raw: recall / precision | After the genotype mask | After the site filters too |
|---|---|---|---|
| SNV | 0.9948 / 0.9862 | 0.9931 / 0.9891 | 0.9907 / 0.9914 |
| Indel | 0.9432 / 0.9465 | 0.9080 / 0.9712 | 0.9063 / 0.9727 |

For SNVs, both steps trade a little recall for precision. For indels, the genotype mask causes almost all of the recall loss and most of the precision gain: indel genotypes with GQ below 20 are common, and when the mask sets a real but uncertain genotype to missing, a true positive becomes a false negative. That is the **precision-recall trade-off**: any threshold that removes more wrong calls also removes some right ones, and where the balance should sit depends on what the calls are for. A screen for candidate variants that a person will check by hand can favor recall; a call set that goes straight into a report needs precision.

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: the trade-off in your own summary

Using the two v5.0q summaries you printed (unfiltered and filtered):

1. For indels, write down recall and precision for unfiltered `ALL`, filtered `ALL` and filtered `PASS`. Which step costs the most recall?
2. Look at `FP.gt` for indels and SNVs in the filtered `PASS` rows. What fraction of the false positives are genotype errors in each type?
3. Why can a QUAL threshold do little about those genotype errors?

::::::::::::::::::::::::::::::::::: solution

1. Indels against v5.0q, recall / precision: unfiltered `ALL` 0.8398 / 0.8720; filtered `ALL` (genotype mask) 0.7840 / 0.9264; filtered `PASS` (mask and site filters) 0.7792 / 0.9305. The mask costs 0.056 of recall, the site filters 0.005 more. As against v4.2.1, the genotype mask causes most of the indel recall loss.
2. Indels: 768 of 1,060 false positives are genotype errors (72%). SNVs: 159 of 848 (19%). Most indel false positives are real variant sites called with the wrong genotype; most SNV false positives are not.
3. QUAL measures how sure the caller is that the site is variant at all. A genotype error is at a real variant site, which can have a high QUAL; only the genotype is wrong. QUAL cannot tell the two genotypes apart, so a QUAL threshold removes these false positives no faster than the true positives around them.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

## Step 6: Predict, then test a threshold

`--roc QUAL` made hap.py compute recall and precision at every QUAL value of the unfiltered calls, as if we had filtered at that value. The tables are in `results/eval/HG002.v5.0q.norm.roc.Locations.SNP.csv.gz` and `...INDEL.csv.gz`.

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: predict, then test a QUAL threshold

Our filter flags QUAL below 30. Suppose we raised the threshold to 225.

1. Predict, before looking: what happens to SNV recall and precision? To indel recall and precision? Which type changes more?
2. Test the prediction. Each command prints the rows of the ROC table at the first QUAL values at or above 30 and 225, with the columns QUAL, recall, precision and F1:

<!-- kit: extra 06-evaluate-summary.sh -->
```bash
zcat results/eval/HG002.v5.0q.norm.roc.Locations.SNP.csv.gz | tail -n +2 | cut -d, -f7,8,9,11 | sort -t, -k1,1g | awk -F, '(30 <= $1 && !a++) || (225 <= $1 && !b++)'
zcat results/eval/HG002.v5.0q.norm.roc.Locations.INDEL.csv.gz | tail -n +2 | cut -d, -f7,8,9,11 | sort -t, -k1,1g | awk -F, '(30 <= $1 && !a++) || (225 <= $1 && !b++)'
```

::::::::::::::::::::::::::::::::::: solution

```output
30.481899,0.987067,0.984282,0.985673
225.110992,0.977404,0.993196,0.985237
30.222500,0.834095,0.877202,0.855105
225.104996,0.748638,0.902337,0.818333
```

The first two lines are SNVs, the last two indels. From QUAL 30 to 225 against v5.0q, SNV recall falls from 0.9871 to 0.9774 and precision rises from 0.9843 to 0.9932; indel recall falls from 0.8341 to 0.7486 and precision rises from 0.8772 to 0.9023. Indel recall falls much more. Indel precision rises more in absolute terms, but look at the wrong calls, 1 minus precision: for SNVs they fall from 1.6% to 0.7% of calls, by more than half; for indels from 12.3% to 9.8%, by about a fifth. Most indel false positives are genotype errors, which QUAL does not separate (previous challenge). Against v4.2.1 the reference run shows the same pattern: from QUAL 30 to 225, SNV recall 0.9944 to 0.9906 and precision 0.9889 to 0.9949; indel recall 0.9425 to 0.9074, precision 0.9478 to 0.9511.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: callout

## Do not tune thresholds on the benchmark

The ROC table makes it tempting to pick the QUAL with the best F1. In your SNV table against v5.0q, F1 peaks at QUAL 117.7 (F1 0.9869). Against v4.2.1, the same calls peak at about QUAL 156-160 (F1 0.9931 in the reference run). The best threshold moved because the test set changed, not the calls. Choosing it for that reason would be **tuning on the test set**: the threshold would be fitted to this benchmark, these samples and this region, and the scores would then overstate how well it works anywhere else. Choose thresholds from the call set's own distributions and from conventions, as in Step 2, and use the benchmark only to measure the result. On your own data there will usually be no benchmark at all.

:::::::::::::::::::::::::::::::::::::::

## Same calls, two benchmarks

Look at the HG002 summary against the older benchmark:

<!-- kit: interactive 06-evaluate-summary.sh -->
```bash
column -s, -t results/eval/HG002.v4.2.1.filtered.summary.csv | cut -c1-120
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
Type   Filter  TRUTH.TOTAL  TRUTH.TP  TRUTH.FN  QUERY.TOTAL  QUERY.FP  QUERY.UNK  FP.gt  METRIC.Recall  METRIC.Precision
INDEL  ALL     11256        10221     1035      17615        302       7123       241    0.908049       0.971216
INDEL  PASS    11256        10201     1055      16823        286       6364       239    0.906272       0.972655
SNP    ALL     71333        70839     494       114284       778       42598      40     0.993075       0.989147
SNP    PASS    71333        70671     662       96848        613       25496      32     0.99072        0.991409
```

:::::::::::::::::::::::::::::::::::::

The calls are identical, but PASS indel recall is 0.7792 against v5.0q and 0.9063 against v4.2.1, and SNV recall 0.9806 against 0.9907. The benchmark defines the score. NIST built v5.0q from a complete diploid assembly of HG002 (the T2T HG002 Q100 assembly), which "allows for the characterization and inclusion of challenging genomic regions and variant types previously excluded from GIAB benchmark sets", including segmental duplications and large tandem repeats ([v5.0q README](https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/latest/NIST_HG002_v5.0q_variant-benchmarksets_README.md)). On chromosome 20 its confident regions cover 58.1 Mb against 56.9 Mb, and it holds 6% more SNVs and 61% more indels than v4.2.1 (reference-run memo). The variants it adds sit in harder sequence, where short reads struggle, so recall falls. The README also says that some regions in v4.2.1 are excluded from v5.0q, for example regions inside inversions, and that results "should be carefully evaluated" because the approach is new.

::::::::::::::::::::::::::::::::::::::: discussion

## Discussion: which number would you report?

A paper reports "indel recall 0.91 against GIAB HG002". Another reports 0.78. Could both describe the same pipeline? What would you need to know before comparing them? What should you write when you report your own accuracy?

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: same calls, two benchmarks (self-paced)

1. From the two filtered HG002 summaries, compare `TRUTH.TOTAL` for SNVs and indels. How many more benchmark variants does v5.0q contain?
2. Compare `QUERY.UNK`. Why is it smaller against v5.0q?
3. Which part of the drop in indel recall comes from variants the newer benchmark adds, and which from calls that changed? (Hint: did any call change?)

::::::::::::::::::::::::::::::::::: solution

1. v5.0q: 75,854 SNVs and 18,173 indels; v4.2.1: 71,333 and 11,256. That is 6% more SNVs and 61% more indels.
2. `QUERY.UNK` counts our calls outside the confident regions. v5.0q's regions cover more of chromosome 20 and more of the difficult sequence, so more of our calls are assessed (and more of them can turn out to be false positives).
3. All of it comes from the benchmark: the calls are the same file. The added benchmark variants lie mostly in harder sequence, where our calls miss more of them.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

## Difficult regions and stratification

Accuracy is not uniform along the genome. Homopolymers and tandem repeats make indels hard to align and to represent; segmental duplications and regions of low mappability attract reads from elsewhere; the centromere combines all of these. GIAB publishes **stratification** BED files that divide the genome into such contexts, and hap.py can report precision and recall for each of them ([Krusche et al. 2019](https://doi.org/10.1038/s41587-019-0054-x)). They are not part of the workshop copy, so we do not compute per-context numbers here; the Ts/Tv inside and outside the benchmark regions, and in the centromere, gave a first view of the same effect.

## Proxy measures when there is no truth set

For your own samples there is usually no benchmark. These measures still tell you something:

- **Ts/Tv**, as above: before and after filtering, inside and outside regions you trust, across samples. A ratio far below that of the known variation of your organism points to errors.
- **Mendelian consistency** in families: a child's genotype must be explainable by one allele from each parent. In Episode 8 we count the sites where it is not.
- **Replicate concordance**: the same sample sequenced twice should give the same calls; disagreements point to errors.
- **Known sites**: the fraction of your calls already listed in a population database (for example gnomAD, Episode 7). An unusually low fraction suggests errors, although real rare variants are often absent from such databases.

None of these gives precision and recall, and each can be fooled, but together they show whether a filter moves a call set in the right direction.

## Common problems

| Symptom | Likely cause | Fix |
|---|---|---|
| a filter flags far too many or too few sites | `INFO/DP` and `FMT/DP` confused: one is summed over samples, the other per sample | name the field explicitly (`INFO/DP`, `FMT/DP`) |
| the filter keeps what it should remove | `-i` and `-e` swapped | `-e` names what fails, `-i` what passes |
| records disappeared after filtering | a hard filter: `-e` without `-s` | add `-s NAME` to label instead of delete |
| precision far too low | hap.py run without the confident-region BED (`-f`) | give `-f` the benchmark BED |
| recall close to 0, or hap.py complains about samples | a multi-sample VCF given to hap.py, or the wrong sample | extract one sample with `bcftools view -s SAMPLE -c 1` |
| recall far too low | whole-genome benchmark without `-l` | restrict with `-l chr20` |
| counts that differ between tools | calls not normalized | `bcftools norm -f ref.fa -m -any` (Episode 5A) |

## Summary

::::::::::::::::::::::::::::::::::::: keypoints

- `bcftools stats` and simple percentiles of QUAL, depth and MQ show the tails that filters should target; Ts/Tv rises when errors are removed.
- Thresholds come from the call set's distributions and from conventions; tuning them on the benchmark is test-set leakage.
- Site filters (`-s` with QUAL, `INFO/DP`, `INFO/MQ`) label records in FILTER and keep them; the genotype mask (`-S .` with `FMT/DP`, `FMT/GQ`) sets single genotypes to missing.
- hap.py with vcfeval compares one sample's calls with a benchmark inside its confident regions; calls outside them are UNK, not scored.
- Precision and recall trade against each other: the genotype mask raises indel precision and costs indel recall.
- The benchmark defines the score: the same calls score lower against the more complete v5.0q.
- Without a truth set, use proxies: Ts/Tv, Mendelian consistency, replicate concordance and known sites.

::::::::::::::::::::::::::::::::::::::::::::::::
