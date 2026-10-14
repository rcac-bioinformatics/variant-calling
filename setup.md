---
title: Setup
---

## Instructors

<!-- TBD(P10): confirm the instructor roster for the delivery. -->

1. **Arun Seetharam, Ph.D.**: Arun is a lead bioinformatics scientist at Purdue University's Rosen Center for Advanced Computing.

2. **Co-instructor**: TBD(P10).

## Schedule (date TBD(P10))

The day runs 9:00 AM to 4:30 PM, with 6 hours of instruction plus lunch and two breaks.

| **Time** | **Session** |
|:---|:---|
| **8:30 AM** | Arrival, login, and data check (copy the data now if you have not done it before the workshop) |
| **9:00 AM** | **Introduction to genetic variation and variant calling (Episode 1):** types of variants, genotypes, how reads become a genotype call, why calls can be wrong |
| **9:30 AM** | **Data, reference, and read quality control (Episodes 2-3):** the trio and its metadata, the reference genome and its indexes, checksums, FastQC and MultiQC. The alignment jobs are submitted at the end of this block and run over the break |
| **10:05 AM** | **Break** |
| **10:20 AM** | **Read alignment and alignment QC (Episode 4):** `bwa mem`, read groups, duplicate marking, alignment metrics, viewing a locus |
| **11:30 AM** | **Calling variants with bcftools (Episode 5A):** joint calling of the trio with an array job, normalization, reading a VCF |
| **12:15 PM** | **Lunch** |
| **1:15 PM** | **Filtering and evaluating variant calls (Episode 6):** filters, precision and recall against the GIAB benchmarks |
| **2:15 PM** | **Break** |
| **2:30 PM** | **Annotating variants (Episode 7):** predicted consequences with SnpEff, population frequencies from gnomAD |
| **3:10 PM** | **Application: candidate variants in a family trio (Episode 8):** Mendelian consistency, de novo and recessive candidates, a filtering funnel |
| **4:00 PM** | **Wrap-up, limitations, next steps, and survey** |
| **4:30 PM** | End of workshop |

Every job in the workshop has a completed-results fallback (see "Completed results" below), so you can rejoin at the next episode if a job does not finish.

The full lesson is longer than one day. Episodes 5B (GATK HaplotypeCaller), 9 (variation across samples and populations), and 10 (adapting the workflow) are self-paced and will be published on this site when they are ready.

## Prerequisites

This workshop assumes:

- **Basic Linux/command-line skills**: navigating directories, running commands, editing files
- **A Purdue career account with access to the Negishi cluster**, with membership in the workshop SLURM account (`-A rcac` in the commands) and in the Depot group `workshop`, which can read the staged data under `/depot/workshop/data`
- **An SSH client**: terminal (macOS/Linux) or MobaXterm/PuTTY (Windows)
- **Genetics knowledge**: genes, alleles, and the basics of DNA sequencing

<!-- TBD(P10): how registrants are added to the SLURM account and to the Depot group for the delivery. -->

No prior variant-calling experience is required.

## Scope of this workshop

This workshop teaches calling germline SNVs and small indels (under 50 bp) from Illumina short-read whole-genome data of diploid samples:

- **Dataset:** the Genome in a Bottle Ashkenazi trio: HG002 (child), HG003 (father), and HG004 (mother). Illumina NovaSeq, PCR-free library, 151 bp paired-end reads, with base qualities binned to four values. The files are labeled 35x; the mean depth on chromosome 20 is about 40x.
- **Region:** reads selected from alignments to chromosome 20 (64.4 Mb) and converted back to FASTQ: 9.35 to 9.48 million read pairs per sample. Because the reads were selected this way, mapping rate and coverage outside chromosome 20 are not realistic.
- **Reference:** GRCh38, NCBI no-alt analysis set, with NCBI's prebuilt bwa index.
- **Benchmarks:** Genome in a Bottle small-variant benchmarks for measuring call quality: v5.0q for HG002 (v4.2.1 for comparison), v4.2.1 for HG003 and HG004.
- **Annotation:** SnpEff with the `GRCh38.mane.1.2.ensembl` database, and gnomAD v4.1 genome allele frequencies.

### Toolchain

Every tool is loaded with `module load biocontainers` followed by the tool module at an explicit version, for example `module load bcftools/1.24`. The versions are pinned because tool behavior changes between releases, bcftools in particular. Loading `biocontainers` prints a notice with a link to the RCAC biocontainers user guides; the outputs shown in the episodes leave it out.

| Step | Modules | Where it runs | Episode |
|:-----|:--------|:--------------|:--------|
| Project setup and reference | samtools/1.22.1 | Negishi login node | 2 |
| Read quality control | fastqc/0.12.1, multiqc/1.23 (fastp shown for reference only) | Negishi, interactive job | 3 |
| Alignment and alignment QC | bwa/0.7.17, samtools/1.22.1, mosdepth/0.3.3, multiqc/1.23 | Negishi, SLURM array job and interactive job | 4 |
| Variant calling | bcftools/1.24 | Negishi, SLURM array job and interactive job | 5A |
| Filtering and evaluation | bcftools/1.24, hap.py/0.3.9 (vcfeval engine) | Negishi, interactive job and SLURM array job | 6 |
| Annotation | snpeff/5.3.0a, bcftools/1.24 | Negishi, SLURM batch job and interactive job | 7 |
| Trio analysis | bcftools/1.24 | Negishi, interactive job | 8 |

### What you will be able to do

By the end of the workshop you will be able to:

- Explain how aligned reads become genotype calls and why calls can be wrong.
- Produce analysis-ready BAMs and a normalized multi-sample VCF on an HPC cluster, using batch and array jobs.
- Read and query VCF records, and filter calls with stated, justified thresholds.
- Measure call quality against a benchmark, and choose proxy measures when no benchmark exists.
- Annotate variants and use population frequencies appropriately.
- Derive a candidate-variant list for a family and state what the evidence does and does not support.

## What is not covered

1. Wet-lab work: sample collection, library preparation, and sequencing
2. Somatic variant calling
3. Structural variant and copy-number variant calling
4. Long-read variant calling
5. Variant calling from RNA-seq data
6. Pooled and polyploid samples
7. Clinical interpretation of variants

Episode 10 (self-paced) points to methods for items 2 to 6.

## SSH setup

You need SSH access to Negishi to copy the workshop data and to run the command-line steps in Episodes 2 to 8. Follow the instructions for your operating system below.

::::::::::::::::::::::::::::::::::::::: discussion

## Connecting to the cluster

You will connect to `negishi.rcac.purdue.edu` with your Purdue career account username and password, followed by Purdue two-factor authentication. Choose the instructions for your operating system below.

:::::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::: solution

### Windows

**MobaXterm (recommended)**

1. Download and install [MobaXterm](https://mobaxterm.mobatek.net/)
2. Open MobaXterm and click **Session > SSH**
3. Set **Remote host** to `negishi.rcac.purdue.edu`
4. Check **Specify username** and enter your Purdue career account username
5. Click **OK** and enter your password when prompted
6. Complete Purdue two-factor authentication

**PuTTY**

1. Download and install [PuTTY](https://www.putty.org/)
2. Set **Host Name** to `negishi.rcac.purdue.edu`, **Port** to `22`, and **Connection type** to **SSH**
3. Click **Open**, then enter your Purdue career account username at the `login as:` prompt
4. Enter your password and complete Purdue two-factor authentication

:::::::::::::::::::::::::

:::::::::::::::: solution

### macOS

1. Open **Terminal** (Applications > Utilities > Terminal)
2. Connect to the cluster:

<!-- kit: not-run laptop -->
```bash
ssh your_username@negishi.rcac.purdue.edu
```

3. Enter your password (characters do not appear as you type, but your password is being entered)
4. Complete Purdue two-factor authentication

:::::::::::::::::::::::::

:::::::::::::::: solution

### Linux

1. Open your terminal emulator
2. Connect to the cluster:

<!-- kit: not-run laptop -->
```bash
ssh your_username@negishi.rcac.purdue.edu
```

3. Enter your password (characters do not appear as you type, but your password is being entered)
4. Complete Purdue two-factor authentication

:::::::::::::::::::::::::

Once logged in, check that your scratch directory variable is set. Every episode works under `$SCRATCH`, so it must print your scratch path:

<!-- kit: interactive 02-setup.sh -->
```bash
echo $SCRATCH
```

```output
/scratch/negishi/your_username
```

## Data setup

Do this before the workshop if you can; it takes a few minutes. All commands run on a Negishi login node.

### Copying the workshop data

The workshop data is staged on Depot. Create your working directory and copy the data into it:

<!-- kit: interactive 02-setup.sh -->
```bash
mkdir -p $SCRATCH/varcall-workshop
rsync -av /depot/workshop/data/varcall-workshop/ $SCRATCH/varcall-workshop/
```

This copies 36 files, about 5.7 GB, and took under a minute in the workshop's test runs. It creates:

- **`data/`**: the six FASTQ files (`HG002_R1.fastq.gz`, `HG002_R2.fastq.gz`, and the same for HG003 and HG004; 4.85 GB together), their checksums in `md5sums.txt`, the sample sheet `samples.tsv`, and the pedigree `trio.ped`.
- **`resources/`**: the GIAB benchmark call sets and regions for chromosome 20 (`truth/`), gnomAD allele frequencies for chromosome 20 (`gnomad/`), the region lists used for calling (`regions/`), and a small example VCF (`example/`).
- **`scripts/`**: the four SLURM job scripts of the workshop: `align.sh`, `call.sh`, `evaluate.sh` and `annotate.sh`.

Next, create the results folders and link the reference genome. The reference, its indexes and the SnpEff database stay in one read-only copy on Depot (about 10 GB); `ref/` holds links to them instead of copies:

<!-- kit: interactive 02-setup.sh -->
```bash
cd $SCRATCH/varcall-workshop
mkdir -p ref results/qc results/bam results/qc_alignment results/vcf results/eval results/annot results/trio
ln -s /depot/workshop/data/varcall-workshop_ref/* ref/
```

### Verifying the data

<!-- kit: interactive 02-setup.sh -->
```bash
ls -l ref/
ls data/ resources/ scripts/
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
total 28
lrwxrwxrwx 1 aseethar workshop 60 Oct 10 21:21 GRCh38_no_alt.dict -> /depot/workshop/data/varcall-workshop_ref/GRCh38_no_alt.dict
lrwxrwxrwx 1 aseethar workshop 58 Oct 10 21:21 GRCh38_no_alt.fa -> /depot/workshop/data/varcall-workshop_ref/GRCh38_no_alt.fa
lrwxrwxrwx 1 aseethar workshop 62 Oct 10 21:21 GRCh38_no_alt.fa.amb -> /depot/workshop/data/varcall-workshop_ref/GRCh38_no_alt.fa.amb
lrwxrwxrwx 1 aseethar workshop 62 Oct 10 21:21 GRCh38_no_alt.fa.ann -> /depot/workshop/data/varcall-workshop_ref/GRCh38_no_alt.fa.ann
lrwxrwxrwx 1 aseethar workshop 62 Oct 10 21:21 GRCh38_no_alt.fa.bwt -> /depot/workshop/data/varcall-workshop_ref/GRCh38_no_alt.fa.bwt
lrwxrwxrwx 1 aseethar workshop 62 Oct 10 21:21 GRCh38_no_alt.fa.fai -> /depot/workshop/data/varcall-workshop_ref/GRCh38_no_alt.fa.fai
lrwxrwxrwx 1 aseethar workshop 62 Oct 10 21:21 GRCh38_no_alt.fa.pac -> /depot/workshop/data/varcall-workshop_ref/GRCh38_no_alt.fa.pac
lrwxrwxrwx 1 aseethar workshop 61 Oct 10 21:21 GRCh38_no_alt.fa.sa -> /depot/workshop/data/varcall-workshop_ref/GRCh38_no_alt.fa.sa
lrwxrwxrwx 1 aseethar workshop 59 Oct 10 21:21 GRCh38_no_alt.sdf -> /depot/workshop/data/varcall-workshop_ref/GRCh38_no_alt.sdf
lrwxrwxrwx 1 aseethar workshop 53 Oct 10 21:21 snpeff_data -> /depot/workshop/data/varcall-workshop_ref/snpeff_data
lrwxrwxrwx 1 aseethar workshop 53 Oct 10 21:21 SOURCES.tsv -> /depot/workshop/data/varcall-workshop_ref/SOURCES.tsv
data/:
HG002_R1.fastq.gz
HG002_R2.fastq.gz
HG003_R1.fastq.gz
HG003_R2.fastq.gz
HG004_R1.fastq.gz
HG004_R2.fastq.gz
md5sums.txt
samples.tsv
trio.ped

resources/:
example
gnomad
regions
truth

scripts/:
align.sh
annotate.sh
call.sh
evaluate.sh
```

:::::::::::::::::::::::::::::::::::::

Check that:

- `ref/` has 11 entries, each a link (`->`) into `/depot/workshop/data/varcall-workshop_ref/`: the FASTA `GRCh38_no_alt.fa` with its `.fai` and the five bwa index files (`.amb`, `.ann`, `.bwt`, `.pac`, `.sa`), the dictionary `GRCh38_no_alt.dict`, the folders `GRCh38_no_alt.sdf` and `snpeff_data`, and `SOURCES.tsv`.
- `data/` has 9 files: six FASTQ files, `md5sums.txt`, `samples.tsv` and `trio.ped`.
- `resources/` has the folders `example`, `gnomad`, `regions` and `truth`, and `scripts/` the four `.sh` files.

If a link in `ls -l ref/` is shown in red or `ls` reports "No such file or directory", your account cannot read the Depot copy; contact the instructors. Episode 2 checks the FASTQ files with their checksums.

::::::::::::::::::::::::::::::::::::::: callout

## Scratch is temporary

Negishi scratch is not backed up, and files that are not accessed for a while are purged automatically. Copy the data shortly before the workshop, and move anything you want to keep (VCFs, tables, reports) to your home directory or your group's Depot space afterwards. If your copy was purged, run the commands above again; `rsync` copies only what is missing, and `ln -s` reports "File exists" for links that are already there, which you can ignore.

:::::::::::::::::::::::::::::::::::::::

### Completed results (backup)

A completed copy of the workshop directory, made with the same scripts, is at:

```
/depot/workshop/data/varcall-workshop_results
```

It has the same layout as your `$SCRATCH/varcall-workshop`, without the FASTQ files, `ref/` and `resources/`, which you already have. Use it **only if a job does not finish in time**. Do not copy the whole directory; copy only the files you need into the matching place in your own directory. Each episode's "Short on time?" box gives the exact command. For example, to continue with Episode 5A without your own alignments:

<!-- kit: not-run fallback -->
```bash
cp /depot/workshop/data/varcall-workshop_results/results/bam/HG00?.markdup.bam* $SCRATCH/varcall-workshop/results/bam/
```

List what is available with `ls /depot/workshop/data/varcall-workshop_results/results`.

## Graphical session for IGV

<!-- TBD(P6): whether learners use IGV in a graphical session (Open OnDemand desktop or ThinLinc) in Episodes 4 and 8, the resource request, and the fallback (samtools tview plus prepared snapshots). -->

TBD(P6). Episode 4 uses the text viewer `samtools tview`, which needs no graphical session.
