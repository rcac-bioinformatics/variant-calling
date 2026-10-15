---
source: Rmd
title: "5A. Calling variants with bcftools"
teaching: 30
exercises: 30
---

:::::::::::::::::::::::::::::::::::::: questions

- How does bcftools turn aligned reads into genotype calls?
- Why call the trio jointly?
- How do we read a VCF record?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Explain what `mpileup` summarizes and how `call` turns it into genotypes and QUAL.
- Call the trio jointly by region with an array job.
- Concatenate, normalize (left-align, split multiallelic sites) and index the calls.
- Read a VCF record (REF, ALT, QUAL, FILTER, INFO; GT, GQ, PL, AD, DP).

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

In Episode 4 we looked at the reads at chr20:88,108 and guessed the genotype by eye. In this episode bcftools makes that guess for every position of chromosome 20, for all three samples at once, and writes the result as a VCF file. We start the calling job first, read a small example VCF while it runs, and then join, normalize and index our own calls.

::::::::::::::::::::::::::::::::::::::: prereq

## Before you start

You need the three duplicate-marked BAM files and their indexes from Episode 4 in `results/bam/`, the reference links in `ref/`, and the script `scripts/call.sh`. If your alignment job did not finish, copy the BAM files from the results copy first (Episode 4, "Short on time?").

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: instructor

Live path (45 minutes; plan section 4: submit the calling array by about 11:40). Episodes 1-4 do not mark live and self-paced sections, so this note gives the live path; P7 applies the same format to every episode.

| Minutes | Section | Live or self-paced |
|---|---|---|
| 5 | Step 1: submit `call.sh`; Step 3: start the interactive session | live |
| 10 | How bcftools calls a genotype (PL, prior, QUAL and GQ); joint calling | live, short version |
| 15 | Step 4: VCF anatomy on the example file; the chr20:88,108 record; challenge "Reading AD at a heterozygous site" | live |
| 5 | Step 5: a multiallelic site and normalization | live |
| 10 | Step 6: concatenate, normalize, count; challenge "SNVs and indels per sample" | live |

Self-paced: Step 2 (the script line by line), the challenge "Predict a homozygous record", and the callouts on the depth cap, ploidy and gVCF. If calling has not finished by the 35-minute mark, switch to the "Short on time?" copy and run Step 6 on it.

:::::::::::::::::::::::::::::::::::::::::::::::::

## Step 1: Submit the calling job

The calling script is already in your `scripts/` folder. Submit it now; the next sections explain it while it runs:

<!-- kit: submit call.sh -->
```bash
cd $SCRATCH/varcall-workshop/scripts
sbatch call.sh
```

The script is an array job with eight tasks, one per region of chromosome 20, and each task uses 2 cores. In the workshop's test runs each task took 2 to 4 minutes, plus the time waiting in the standby queue. Check on it with:

<!-- kit: not-run monitoring -->
```bash
squeue -u $USER
```

Each task writes its log to `scripts/cluster-call.<jobid>.out` and `.err`.

::::::::::::::::::::::::::::::::::::::: callout

## Short on time?

If your calling job fails or is still waiting when we reach Step 6, cancel it (`scancel <jobid>`) and copy the eight finished chunks and their indexes from the results copy:

<!-- kit: not-run fallback -->
```bash
mkdir -p $SCRATCH/varcall-workshop/results/vcf/chunks
cp /depot/workshop/data/varcall-workshop_results/results/vcf/chunks/chunk0?.bcf* $SCRATCH/varcall-workshop/results/vcf/chunks/
```

Then continue with Step 6 as written.

:::::::::::::::::::::::::::::::::::::::

## How bcftools calls a genotype

Calling is two commands joined by a pipe ([bcftools manual](https://samtools.github.io/bcftools/bcftools.html)).

**`bcftools mpileup`** reads the BAM files position by position. At each position it collects the bases of the reads that cover it, with their base qualities and mapping qualities, and computes for each sample a **genotype likelihood** for every possible genotype: how probable the observed bases are if the true genotype were `0/0`, `0/1` or `1/1`. It stores them in the `PL` field, Phred-scaled and rounded, so that the most likely genotype gets 0 and a genotype with `PL` 30 is 1,000 times less likely than that one ([VCF specification](https://samtools.github.io/hts-specs/VCFv4.3.pdf), section 1.6.2). The statistical model is described by [Li (2011)](https://doi.org/10.1093/bioinformatics/btr509).

Before counting, `mpileup` drops some reads and bases. With the defaults of bcftools 1.24, as its usage text lists them:

- reads with any of the flags `UNMAP,SECONDARY,QCFAIL,DUP` are skipped (`--ns`), so duplicates marked in Episode 4 do not count;
- anomalous pairs, flagged as paired but not as a proper pair, are skipped (`-A` includes them);
- reads with mapping quality below 0 are skipped (`-q 0`; that is, none are);
- where the two reads of a pair overlap, the lower-quality base of each overlapping pair of bases gets base quality 0, so the overlap counts once ([htslib `sam.h`](https://github.com/samtools/htslib/blob/1.24/htslib/sam.h), `bam_mplp_init_overlaps`; `-x` disables this);
- bases with base quality below 1 are skipped (`-Q 1`), after the BAQ adjustment of Episode 3. Our data hold only the qualities 2, 11, 25 and 37 (Episode 3), so this floor removes only bases whose quality was set to 0, by BAQ or by the overlap rule;
- at most 250 reads are read per position and input file (`-d 250`, the depth cap, see the callout below).

**`bcftools call -m`** turns the likelihoods into calls. `-m` selects the "multiallelic caller", which also handles sites with more than one ALT allele. It combines each sample's likelihoods with a **prior**, the expected rate of variation (`-P`, default `1.1e-3`, "mutation rate (use bigger for greater sensitivity)" in the usage text). From likelihoods and prior it decides whether the site is variant at all, and if so writes:

- **QUAL**, for the site: the Phred-scaled probability that the site is not variant in any of the samples, "−10log10 prob(no variant)" in the VCF specification.
- **GT** for each sample: the most probable genotype.
- **GQ** for each sample, because `call.sh` asks for it with `-a FORMAT/GQ`: the Phred-scaled probability that this sample's genotype is wrong, given that the site is variant (the specification's "conditional genotype quality").

QUAL and GQ answer different questions. In a joint call of three samples, QUAL pools the evidence of all three: a site where only one sample carries the ALT allele can have a high QUAL, while another sample at the same site has a low GQ because few reads cover it. Filtering on QUAL judges the site; filtering on GQ judges one person's genotype. Episode 6 uses both.

`-v` writes variant sites only. Without it, every position of the chromosome would get a record.

::::::::::::::::::::::::::::::::::::::: callout

## Joint calling and per-sample calling

We pass all three BAM files to one `mpileup` command, so the trio is called **jointly**: every site that is variant in any sample gets one record with a genotype for each of the three samples. Two things follow:

- A sample without the ALT allele gets an explicit `0/0` with its own read counts, so "this person is homozygous for the reference allele, and we looked" is different from "no reads here" (`./.`). Episode 8 relies on this difference.
- Evidence is pooled at the site level (QUAL), which helps at sites where one sample has few reads.

Calling each sample separately and merging the VCFs afterwards loses the first point: a site missing from one sample's VCF could be homozygous reference or simply not covered. The gVCF approach (callout at the end) solves this for large cohorts.

:::::::::::::::::::::::::::::::::::::::

## Step 2: The calling script, line by line

This is `scripts/call.sh` as you submitted it:

<!-- kit: script call.sh -->
```bash
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
```

### Calling by region with an array job

Calling works one position at a time and does not need the rest of the chromosome, so chromosome 20 can be split into regions that are called independently and joined afterwards. The region list has one region per line:

<!-- kit: extra 05-merge.sh -->
```bash
cat $SCRATCH/varcall-workshop/resources/regions/chr20_chunks.txt
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
chr20:1-8055521
chr20:8055522-16111042
chr20:16111043-24166563
chr20:24166564-31160372
chr20:31160373-40277604
chr20:40277605-48333125
chr20:48333126-56388646
chr20:56388647-64444167
```

Eight regions in `chrom:start-end` form, 1-based and inclusive (Episode 2), in chromosome order. Together they cover chromosome 20 without overlap.

:::::::::::::::::::::::::::::::::::::

Array task N reads line N of this list (`sed -n "${SLURM_ARRAY_TASK_ID}p"`; this file has no header, unlike `samples.tsv`), and names its output `chunk01.bcf` to `chunk08.bcf` (`printf '%02d'` pads the number to two digits). The regions were cut to hold similar amounts of sequence, so the tasks take similar times; the one that holds the centromere has the most calls and runs longest.

### The `mpileup` and `call` options

| Option | Meaning |
|---|---|
| `-f $REF` | the reference FASTA. Its sequence names must match the BAM headers (`chr20` in both) |
| `-r $REGION` | call only this region; needs the BAM indexes from Episode 4 |
| `-a AD,DP,SP` | add per-sample allelic depths (`AD`), depth (`DP`) and a strand-bias score (`SP`) |
| `-Ou` | pass uncompressed BCF through the pipe |
| three BAM files | one sample each; their order is the order of the sample columns in the VCF |
| `call -m` | the multiallelic caller |
| `call -v` | write variant sites only |
| `-a FORMAT/GQ` | add the genotype quality |
| `-Ob -W -o` | write compressed BCF, write its index, and name the output file |

The sample names in the VCF come from the `SM` field of each BAM's read group (Episode 4), and their order from the order of the BAM files: HG002 (child), HG003 (father), HG004 (mother), the order of `trio.ped`.

::::::::::::::::::::::::::::::::::::::: callout

## Why BCF for the chunks, and VCF for the result?

**BCF** is the binary form of VCF: the same content, stored so that programs read it without parsing text. It is faster to write and read, which matters for intermediate files that only bcftools reads. The final file is **bgzipped VCF** (`.vcf.gz`), which other tools (hap.py, SnpEff, IGV) read and people can inspect with `zcat` or `bcftools view`. Both formats are compressed in blocks (BGZF), which lets an **index** (`.csi` or `.tbi`) jump straight to a region ([htslib file formats](https://samtools.github.io/hts-specs/)). `-W` writes the index next to the output, so `-r` region queries work on every file we create.

:::::::::::::::::::::::::::::::::::::::

## Step 3: Start an interactive session

While the calling tasks run, start an interactive session and load bcftools. You will use the same session to join the chunks in Step 6:

<!-- kit: interactive 05-merge.sh -->
```bash
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load bcftools/1.24
cd $SCRATCH/varcall-workshop
```

## Step 4: Anatomy of a VCF record

Your own calls are not ready yet, so we read a small example first: `resources/example/trio.example.raw.vcf.gz` holds the calls of the workshop's reference run for chr20:60,000-90,000, before normalization. It contains the three sites of Episodes 2 and 4.

A VCF file has a header (lines starting with `##`, then one line starting with `#CHROM`) and one line per variant. The header declares every field the records use. Print the declarations of the fields we need, and the column line:

<!-- kit: extra 05-merge.sh -->
```bash
bcftools view -h resources/example/trio.example.raw.vcf.gz | grep -E '^##(INFO|FORMAT)=<ID=(DP|MQ|AD|GT|PL|GQ),'
bcftools view -h resources/example/trio.example.raw.vcf.gz | tail -1
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
##INFO=<ID=DP,Number=1,Type=Integer,Description="Raw read depth">
##FORMAT=<ID=PL,Number=G,Type=Integer,Description="List of Phred-scaled genotype likelihoods">
##FORMAT=<ID=DP,Number=1,Type=Integer,Description="Number of high-quality bases">
##FORMAT=<ID=AD,Number=R,Type=Integer,Description="Allelic depths (high-quality bases)">
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
##FORMAT=<ID=GQ,Number=1,Type=Integer,Description="Phred-scaled Genotype Quality">
##INFO=<ID=MQ,Number=1,Type=Integer,Description="Average mapping quality">
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	HG002	HG003	HG004
```

The `[W::bcf_hdr_check_sanity]` lines are a warning that bcftools prints for these files; the callout in Step 6 explains it. Each `##INFO` and `##FORMAT` line gives a field's ID, how many values it has (`Number`: 1, `R` for one per allele including REF, `G` for one per possible genotype), its type and a description. INFO fields describe the site; FORMAT fields are repeated for each sample. The last line names the columns: eight fixed columns, `FORMAT`, then one column per sample.

:::::::::::::::::::::::::::::::::::::

Now the record at the heterozygous site of Episode 4:

<!-- kit: extra 05-merge.sh -->
```bash
bcftools view -H -r chr20:88108 resources/example/trio.example.raw.vcf.gz
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
chr20	88108	.	T	C	723.977	.	DP=117;VDB=0.244275;SGB=-7.53767;RPBZ=-1.26517;MQBZ=0;MQSBZ=0;BQBZ=0.232513;SCBZ=0;MQ0F=0;AC=3;AN=6;DP4=30,23,31,23;MQ=60	GT:PL:DP:SP:AD:GQ	0/1:249,0,255:32:8:19,13:127	0/1:255,0,255:42:4:20,22:127	0/1:255,0,255:33:16:14,19:127
```

:::::::::::::::::::::::::::::::::::::

Reading it column by column ([VCF specification](https://samtools.github.io/hts-specs/VCFv4.3.pdf), section 1.6):

| Column | Here | Meaning |
|---|---|---|
| CHROM, POS | `chr20`, `88108` | 1-based position |
| ID | `.` | no identifier (for example a dbSNP rs number) |
| REF, ALT | `T`, `C` | reference allele and the alternate allele(s) |
| QUAL | about 724 | site quality (above) |
| FILTER | `.` | not filtered yet; Episode 6 fills this column |
| INFO | `DP=...;...;MQ=...` | site-level fields, separated by `;` |
| FORMAT | `GT:PL:DP:SP:AD:GQ` | the order of the per-sample fields that follow |
| HG002, HG003, HG004 | `0/1:...` | one column per sample, values in the FORMAT order |

So the HG002 column reads as: `GT` the genotype; `PL` the three genotype likelihoods for `0/0`, `0/1`, `1/1`; `DP` this sample's depth; `SP` the strand-bias score; `AD` the read counts for REF and ALT; `GQ` the genotype quality. `PL` and `GQ` stop at 255 and 127 in these files: a value at the cap means "at least this confident".

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: reading AD at a heterozygous site

1. From the record above, what are HG002's `AD` and `DP` at chr20:88,108? How many reads support `C`?
2. In Episode 4, `samtools tview` showed 14 reads with `C` and 25 with the reference `T` in this column, 39 in all. Do the numbers agree? If not, list what `mpileup` does that `tview` does not.
3. The INFO field also has a `DP`. Why is it larger than HG002's `DP`?

::::::::::::::::::::::::::::::::::: solution

1. HG002 has `AD` 19,13 and `DP` 32: 13 reads support `C`.
2. They differ, because `mpileup` counts only some of the reads that `tview` displays. The workshop's test run counted the same position with each of `mpileup`'s read and base filters switched off, then on again one at a time:

   | What `mpileup` counts at chr20:88,108 in HG002 | AD (T,C) and DP |
   |---|---|
   | every read and base, filters off | 25,14,0; DP 39 |
   | skip reads flagged as duplicates | 21,14,0; DP 35 |
   | also skip anomalous pairs (paired, not in a proper pair) | 21,14,0; DP 35 |
   | also detect overlapping mates (one base of each overlap gets quality 0) | 21,14,0; DP 35 |
   | also apply the base-quality floor (`-Q 1`) | 19,13,0; DP 32 |
   | also apply BAQ: the defaults, as in `call.sh` | 19,13,0; DP 32 |

   Each row adds one filter to the row above (the third number of `AD` counts bases that are neither `T` nor `C`). The options are those of the bcftools 1.24 usage text (`--ns`, `-A`, `-x`, `-Q`, `-B`). With every filter off, `mpileup` counts the same 39 reads as the `tview` column, 25 `T` and 14 `C`. Two causes explain the difference at this site:

   - **duplicates**: 4 reads, all `T`, are marked as duplicates (Episode 4) and skipped;
   - **overlapping mates**: in 3 read pairs both mates cover the site. Overlap detection sets one base of each pair to quality 0, which changes no count by itself (the overlap row), and the base-quality floor then drops those 3 bases (2 `T`, 1 `C`).

   Anomalous pairs and BAQ remove nothing here. That leaves 19 `T` and 13 `C`, 32 in all.
3. `INFO/DP` (117) is the site's raw depth summed over all three samples; `FORMAT/DP` is one sample's depth after the filters above. The header lines from the start of this step give both descriptions. Episode 6 filters on each, so it matters which one an expression reads.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

### Why `0/1`: the likelihood argument

In Episode 4 we reasoned with a coin toss: with 39 reads at a balanced heterozygous site, 14 or fewer `C` reads happen 5.4% of the time (10.8% for 14 or fewer of either allele). That is a tail probability, and it does not by itself decide anything. The caller compares the three genotypes instead. HG002's `PL` at this site is `249,0,255`:

- `0/0` would mean that all 13 `C` bases are sequencing errors, each of them at high base quality. That is extremely unlikely, so its `PL` is large.
- `1/1` would mean that all the `T` bases are errors. Also extremely unlikely.
- `0/1` explains both alleles with ordinary sampling, so its `PL` is 0.

A difference of 10 in `PL` is a factor of 10 in likelihood, so a difference in the hundreds means that the other genotypes are less likely by many orders of magnitude. The call is `0/1` because the alternatives are far less likely, not because 14 of 39 passes a test of balance. GQ (at the cap, 127) says the same.

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: predict a homozygous record

The benchmark says HG002 is homozygous for the ALT allele `A` at chr20:85,259 (reference `G`), and in Episode 4 all 50 reads in that column showed `A`.

1. Before you look: what do you expect for HG002's `GT`, the two numbers of `AD`, and which of the three `PL` values is 0?
2. Check with `bcftools query`, which prints the fields you name in the format you give it (`%` for a field, `[...]` repeated for each sample):

<!-- kit: extra 05-merge.sh -->
```bash
bcftools query -r chr20:85259 -f '%POS %REF %ALT %QUAL[\n  %SAMPLE %GT AD=%AD DP=%DP PL=%PL GQ=%GQ]\n' resources/example/trio.example.raw.vcf.gz
```

::::::::::::::::::::::::::::::::::: solution

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
85259 G A 739.009
  HG002 1/1 AD=0,43 DP=43 PL=255,129,0 GQ=127
  HG003 1/1 AD=0,38 DP=38 PL=255,114,0 GQ=127
  HG004 1/1 AD=0,32 DP=32 PL=255,96,0 GQ=127
```

HG002 is `1/1` with `AD` 0,43, `DP` 43, `PL` 255,129,0 and `GQ` 127. No read supports `G`, and the third `PL` value (for `1/1`) is 0. If your prediction had `AD` equal to 0,50: `mpileup` counts fewer reads than `tview` shows, for the reasons in the previous challenge.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

`bcftools query` turns a VCF into a table, which is how most questions about a call set are answered. One table with the genotypes of all three samples at the three sites from Episode 4 (the het SNV, the hom-ALT SNV and a 10 bp insertion):

<!-- kit: extra 05-merge.sh -->
```bash
bcftools query -r chr20:85259,chr20:86859,chr20:88108 -f '%POS\t%REF\t%ALT\t%QUAL[\t%SAMPLE=%GT]\n' resources/example/trio.example.raw.vcf.gz
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
85259	G	A	739.009	HG002=1/1	HG003=1/1	HG004=1/1
86859	TTGGTAT	TTGGTATCTAGTGGTAT	729.329	HG002=1/1	HG003=1/1	HG004=0/1
88108	T	C	723.977	HG002=0/1	HG003=0/1	HG004=0/1
```

:::::::::::::::::::::::::::::::::::::

## Step 5: Variant representation and normalization

The same variant can be written in more than one way. A deletion inside a repeat can be placed at any copy of the repeat unit, and a site with two different ALT alleles can be one record (`ALT` = `A,T`) or two. Tools that compare calls by position and allele, such as `bcftools isec` ([bcftools manual](https://samtools.github.io/bcftools/bcftools.html#isec)), see different representations as different variants. **Normalization** gives each variant one form ([Tan et al. 2015](https://doi.org/10.1093/bioinformatics/btv112)):

- **left-alignment**: shift each indel to its leftmost equivalent position and trim shared bases; this needs the reference (`norm -f`);
- **splitting**: write each ALT allele of a multiallelic site as its own record (`norm -m -any`).

The example region has one multiallelic site before normalization. Find it:

<!-- kit: extra 05-merge.sh -->
```bash
bcftools query -i 'N_ALT>1' -f '%CHROM\t%POS\t%REF\t%ALT\t%QUAL[\t%SAMPLE=%GT:%AD]\n' resources/example/trio.example.raw.vcf.gz
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
chr20	88865	GACACACACACACACACACACACACACACA	GACACACACACACACACACACACACACACACACACA,GACACACACACACACACACACACACACACACACA	240.617	HG002=0/0:36,0,0	HG003=0/2:26,0,4	HG004=0/1:15,17,0
```

:::::::::::::::::::::::::::::::::::::

`-i 'N_ALT>1'` keeps records with more than one ALT allele. This one is in a `CA` repeat: the two ALT alleles add 6 and 4 bases to it (`ACACAC` and `ACAC`). Genotypes number the alleles in order, `0` for REF, `1` for the first ALT and `2` for the second, and `AD` has one number per allele in the same order. So HG003 is `0/2` (26 reads for REF, 4 for the second ALT), HG004 is `0/1` (15 and 17), and the child HG002 is `0/0`. Now look at the same position in the normalized version of the example, `trio.example.filtered.vcf.gz` (it is also filtered, which Episode 6 explains). The first line stores the position in a shell variable:

<!-- kit: extra 05-merge.sh -->
```bash
POS=$(bcftools query -i 'N_ALT>1' -f '%POS\n' resources/example/trio.example.raw.vcf.gz)
bcftools query -r chr20:$POS -f '%CHROM\t%POS\t%REF\t%ALT\t%QUAL[\t%SAMPLE=%GT:%AD]\n' resources/example/trio.example.filtered.vcf.gz
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
chr20	88865	G	GACACAC	240.617	HG002=0/0:36,0	HG003=0/0:26,0	HG004=0/1:15,17
chr20	88865	G	GACAC	240.617	HG002=0/0:36,0	HG003=0/1:26,4	HG004=0/0:15,0
```

:::::::::::::::::::::::::::::::::::::

The one record became 2 records at the same position, each with a single ALT allele, and `norm` also trimmed the repeat bases that REF and ALT shared, so each insertion is now written as `G` followed by the inserted bases. A sample's genotype is rewritten for each record: HG003's `0/2` becomes `0/0` in the first record and `0/1` in the second, because when splitting, `norm` fills in the reference allele for the other ALT (`--multi-overlaps 0|.`, default `[0]`, in the 1.24 usage text). In the same way a `1/2` would become `1/0` and `0/1`. `AD` keeps the REF count and the count of that record's ALT: HG003's 4 reads for the shorter insertion appear only in the second record. Reads of the other ALT count as neither allele, so read the `AD` of split records with care.

After splitting, every record is biallelic, which makes counting simple (one ALT, one variant), and Episodes 6-8 can treat each record as one variant.

## Step 6: Join, normalize and index the calls

When `squeue -u $USER` no longer lists the `call` job, continue in your session. First, list the chunks in order:

<!-- kit: interactive 05-merge.sh -->
```bash
# chunk01 ... chunk08: the names sort in chromosome order
ls results/vcf/chunks/chunk*.bcf > results/vcf/chunks.txt
cat results/vcf/chunks.txt
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
results/vcf/chunks/chunk01.bcf
results/vcf/chunks/chunk02.bcf
results/vcf/chunks/chunk03.bcf
results/vcf/chunks/chunk04.bcf
results/vcf/chunks/chunk05.bcf
results/vcf/chunks/chunk06.bcf
results/vcf/chunks/chunk07.bcf
results/vcf/chunks/chunk08.bcf
```

:::::::::::::::::::::::::::::::::::::

Because the chunk numbers are padded to two digits, `ls` lists them in chromosome order. Join them, then normalize:

<!-- kit: interactive 05-merge.sh -->
```bash
bcftools concat -f results/vcf/chunks.txt -Ob -W -o results/vcf/trio.raw.bcf
bcftools norm -f ref/GRCh38_no_alt.fa -m -any -Oz -W -o results/vcf/trio.norm.vcf.gz results/vcf/trio.raw.bcf
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
Checking the headers and starting positions of 8 files
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
Concatenating results/vcf/chunks/chunk01.bcf	0.105096 seconds
Concatenating results/vcf/chunks/chunk02.bcf	0.088082 seconds
Concatenating results/vcf/chunks/chunk03.bcf	0.084996 seconds
Concatenating results/vcf/chunks/chunk04.bcf	0.271559 seconds
Concatenating results/vcf/chunks/chunk05.bcf	0.092314 seconds
Concatenating results/vcf/chunks/chunk06.bcf	0.079879 seconds
Concatenating results/vcf/chunks/chunk07.bcf	0.095996 seconds
Concatenating results/vcf/chunks/chunk08.bcf	0.106483 seconds
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
Lines   total/split/joined/realigned/mismatch_removed/dup_removed/skipped:	181481/3956/0/28035/0/0/0
```

`concat` first checks the headers and the starting position of each file; the files must be listed in chromosome order. `norm` reports what it did on its `Lines` line: the number of records read, how many multiallelic records it split (3,956), and how many indels it realigned (28,035). The seconds on the `Concatenating` lines differ from run to run.

:::::::::::::::::::::::::::::::::::::

`concat -f` reads the list of files to join, in order. `norm -f` left-aligns indels against the reference, and `-m -any` splits every multiallelic site, SNVs and indels alike. Both write with `-W`, so both outputs get an index.

::::::::::::::::::::::::::::::::::::::: callout

## "MQ should be declared as Type=Float"

Every bcftools command that reads these files prints:

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
```

It is a header-type notice, not an error. The VCF specification reserves the INFO key `MQ` ("RMS mapping quality") with `Type=Float` ([VCF specification](https://samtools.github.io/hts-specs/VCFv4.3.pdf), Table 1), and the header that `mpileup` writes declares `MQ` with another type (the `##INFO=<ID=MQ` line in Step 4). The warning changes nothing in the output: the `INFO/MQ < 30` filter in Episode 6 flags 6,407 sites, as expected from the MQ distribution. You can ignore it.

:::::::::::::::::::::::::::::::::::::::

Check the sample names and the first records:

<!-- kit: interactive 05-merge.sh -->
```bash
bcftools query -l results/vcf/trio.norm.vcf.gz
bcftools view -H results/vcf/trio.norm.vcf.gz | head -3
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
HG002
HG003
HG004
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
chr20	61083	.	C	T	389.284	.	DP=122;VDB=0.110165;SGB=0.0318579;RPBZ=-2.14575;MQBZ=2.20292;MQSBZ=2.23992;BQBZ=-1.50832;SCBZ=-0.208065;MQ0F=0.0245902;AC=2;AN=6;DP4=52,30,17,13;MQ=54	GT:PL:DP:SP:AD:GQ	0/0:0,126,255:42:0:42,0:127	0/1:255,0,255:39:3:19,20:127	0/1:171,0,255:31:4:21,10:127
chr20	61264	.	T	C	8.72949	.	DP=123;VDB=0.00922863;SGB=-25.4761;RPBZ=-1.36098;MQBZ=-6.90319;MQSBZ=1.12068;BQBZ=-1.24528;SCBZ=4.03624;MQ0F=0.130081;AC=1;AN=6;DP4=42,44,15,9;MQ=45	GT:PL:DP:SP:AD:GQ	0/0:0,47,255:39:10:32,6:54	0/1:44,0,255:32:2:25,5:36	0/0:0,32,255:39:0:29,9:39
chr20	61275	.	A	G	344.637	.	DP=184;VDB=1.69768e-13;SGB=-38.0955;RPBZ=-5.45572;MQBZ=-3.51699;MQSBZ=1.17918;BQBZ=-0.407145;SCBZ=7.27953;MQ0F=0.108696;AC=3;AN=6;DP4=62,58,21,17;MQ=42	GT:PL:DP:SP:AD:GQ	0/1:111,0,255:56:3:43,11:108	0/1:176,0,255:50:4:34,15:127	0/1:97,0,255:52:1:43,9:94
```

`query -l` lists the samples in column order: HG002, HG003, HG004, the order of the BAM files in `call.sh` and of `trio.ped`. Episode 8 depends on this order.

:::::::::::::::::::::::::::::::::::::

Your record at chr20:88,108 should be identical to the one in the example file, because the example was cut from the reference run, made with the same scripts:

<!-- kit: extra 05-merge.sh -->
```bash
bcftools view -H -r chr20:88108 results/vcf/trio.norm.vcf.gz
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
chr20	88108	.	T	C	723.977	.	DP=117;VDB=0.244275;SGB=-7.53767;RPBZ=-1.26517;MQBZ=0;MQSBZ=0;BQBZ=0.232513;SCBZ=0;MQ0F=0;AC=3;AN=6;DP4=30,23,31,23;MQ=60	GT:PL:DP:SP:AD:GQ	0/1:249,0,255:32:8:19,13:127	0/1:255,0,255:42:4:20,22:127	0/1:255,0,255:33:16:14,19:127
```

:::::::::::::::::::::::::::::::::::::

### Count the calls

`bcftools stats` summarizes a VCF file. `-s -` adds per-sample counts for all samples. Save the summary, then print the overall numbers and the per-sample lines:

<!-- kit: interactive 05-merge.sh -->
```bash
bcftools stats -s - results/vcf/trio.norm.vcf.gz > results/vcf/trio.norm.stats.txt
grep -E '^(SN|TSTV)' results/vcf/trio.norm.stats.txt
grep ^PSC results/vcf/trio.norm.stats.txt
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float
SN	0	number of samples:	3
SN	0	number of records:	185914
SN	0	number of no-ALTs:	0
SN	0	number of SNPs:	155291
SN	0	number of MNPs:	0
SN	0	number of indels:	30623
SN	0	number of others:	0
SN	0	number of multiallelic sites:	0
SN	0	number of multiallelic SNP sites:	0
TSTV	0	100039	55252	1.81	100039	55252	1.81
PSC	0	HG002	44001	31755	88101	76976	42880	21759	44.0	2049	0	0	298
PSC	0	HG003	46627	29277	88481	75644	42114	21267	43.9	17640	0	0	262
PSC	0	HG004	45117	30599	88065	76259	42405	21684	43.5	18746	0	0	449
```

The `SN` lines count records by type: 185,914 records, 155,291 SNVs and 30,623 indels, and no multiallelic sites left after `norm`. The `TSTV` line gives the transition/transversion ratio of the SNVs, 1.81 (Episode 6 explains why it matters). Each `PSC` line describes one sample; its columns are listed in the comment line above them in the stats file (`grep -m1 '^# PSC' results/vcf/trio.norm.stats.txt`).

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: SNVs and indels per sample

The trio file has 155,291 SNV records and 30,623 indel records, but no single person carries all of them.

1. From the `PSC` lines, how many SNVs and how many indels does each sample carry? (SNVs are transitions plus transversions; use the `# PSC` comment line to find the columns.)
2. Why does each sample carry fewer than the trio file holds?
3. Which column counts the genotypes with no call (`./.`)?

::::::::::::::::::::::::::::::::::: solution

1. HG002 119,856 SNVs and 21,759 indels; HG003 117,758 SNVs and 21,267 indels; HG004 118,664 SNVs and 21,684 indels. For HG002, 76,976 transitions plus 42,880 transversions give 119,856.
2. A trio record is written when any of the three samples carries an ALT allele; at many sites only one or two of them do. A sample with `0/0` or `./.` at a site does not carry that variant.
3. `nMissing`, the last column: HG002 298, HG003 262 and HG004 449 missing genotypes. Before filtering, a genotype is missing only where the sample has no usable reads.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

Type `exit` to leave the interactive session.

::::::::::::::::::::::::::::::::::::::: callout

## Short on time?

If you could not join and normalize the calls, copy the result and its statistics from the results copy:

<!-- kit: not-run fallback -->
```bash
cp /depot/workshop/data/varcall-workshop_results/results/vcf/trio.norm.vcf.gz* $SCRATCH/varcall-workshop/results/vcf/
cp /depot/workshop/data/varcall-workshop_results/results/vcf/trio.norm.stats.txt $SCRATCH/varcall-workshop/results/vcf/
```

Episode 6 starts from `results/vcf/trio.norm.vcf.gz`.

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: callout

## The depth cap

`mpileup` reads at most 250 reads per position from each input file (`-d`). At about 40x this never matters in ordinary sequence. It matters in two cases. In a **collapsed repeat**, many copies of a sequence that the reference holds only once, reads from all copies pile up at one place. Depth far above the mean does occur in our data: in Episode 4, `mosdepth` reported a maximum depth of 13,784 in HG002. At such places the cap keeps memory in check, and the calls deserve suspicion anyway; Episode 6 flags sites with unusually high depth. In **deep data** (targeted panels, amplicons, mitochondria), the cap silently throws away reads at every position; raise `-d` for such data.

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: callout

## Ploidy

Human chromosome 20 is diploid, so every genotype here has two alleles. `bcftools call` assumes diploid genotypes unless told otherwise; its usage text gives `--ploidy` the default `[2]`. For haploid sequence (chrY and most of chrX in males, mitochondria, many microbes) or polyploid organisms, set `--ploidy` or `--ploidy-file`. Pooled samples need a different approach altogether (Episode 10).

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: callout

## The gVCF idea

Our VCF has records only at variant sites (`-v`). To add a fourth sample later, we would have to call all four again, because the existing file does not say whether the new sample's variant sites were covered in the other three. A **gVCF** solves this: it also stores blocks of non-variant positions with their depth and genotype quality, so each sample is called once and the samples are genotyped together afterwards. `bcftools mpileup -g` writes gVCF blocks, and GATK's HaplotypeCaller is built around them; Episode 5B (self-paced) uses that route.

:::::::::::::::::::::::::::::::::::::::

## Common problems

| Symptom | Likely cause | Fix |
|---|---|---|
| errors that name a sequence, or an empty VCF | contig names differ between FASTA and BAM (`chr20` against `20`), or a different reference build | align to the same FASTA you call with; check `samtools view -H` against the `.fai` (Episode 2) |
| no `AD` in the FORMAT column | `-a AD` missing from `mpileup` | add `-a AD,DP,SP` as in `call.sh` |
| millions of records, nearly all `0/0` | `-v` missing from `call` | call again with `-mv` |
| `mpileup` reports a region it cannot parse | region syntax: `chr20:1-8060000`, no spaces, no thousands separators | fix the line in the region list |
| depth stuck at 250 in deep data | the depth cap | raise `-d` |
| `concat` complains about the order of the files | chunks listed out of order | list them in chromosome order (the padded names do this) |
| "could not load index" or `-r` does not work | an output written without an index | write with `-W`, or run `bcftools index` |
| one sample column, or unexpected sample names | wrong `SM` in the read groups | fix `samples.tsv` and realign (Episode 4) |

## Summary

::::::::::::::::::::::::::::::::::::: keypoints

- `bcftools mpileup` computes per-sample genotype likelihoods (`PL`) from the bases, base qualities and mapping qualities of the reads; it skips duplicates and some other reads and bases by default.
- `bcftools call -m` combines the likelihoods with a prior to give GT for each sample and QUAL for the site; GQ is added on request (`-a FORMAT/GQ`).
- QUAL is about the site, pooled over the samples of a joint call; GQ is about one sample's genotype.
- Joint calling gives every sample a genotype at every variant site, so homozygous reference is distinct from no data.
- Calling by region with an array job, then `concat` in order, `norm -f -m -any` and indexing (`-W`), gives one normalized, indexed VCF.
- A genotype is chosen because the alternatives are much less likely (`PL`), not because the read counts pass a balance test.

::::::::::::::::::::::::::::::::::::::::::::::::
