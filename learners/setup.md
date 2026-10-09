---
title: Setup
---

## Instructors

<!-- TBD(P10): instructor roster for the delivery. Arun Seetharam is confirmed; the co-instructor is TBD (D8). -->

1. **Arun Seetharam, Ph.D.**: Arun is a lead bioinformatics scientist at Purdue University's Rosen Center for Advanced Computing.

## Schedule

<!-- TBD(P10): delivery date in the heading, for example "Schedule (MM/DD/YYYY)". The day runs 9:00 to 4:30 with 6 hours of instruction (D6). Fill the table from instructors/instructor-notes.md once job runtimes are measured (P2, P3). -->

| **Time** | **Session** |
|:---|:---|
| **8:30 AM** | Arrival, login, and data check |
| **9:00 AM** | **Introduction to genetic variation and variant calling (Episode 1)** |
| **9:30 AM** | **Data, reference, and read quality control (Episodes 2-3)** |
| **10:05 AM** | **Break** |
| **10:20 AM** | **Read alignment and alignment QC (Episode 4)** |
| **11:30 AM** | **Calling variants with bcftools (Episode 5A)** |
| **12:15 PM** | **Lunch** |
| **1:15 PM** | **Filtering and evaluating variant calls (Episode 6)** |
| **2:15 PM** | **Break** |
| **2:30 PM** | **Annotating variants (Episode 7)** |
| **3:10 PM** | **Application: candidate variants in a family trio (Episode 8)** |
| **4:00 PM** | **Wrap-up, next steps, and survey** |
| **4:30 PM** | End of workshop |

The full lesson is longer than one day. Episodes 5B (GATK HaplotypeCaller), 9 (variation across samples and populations), and 10 (adapting the workflow) are self-paced and will be published on this site when they are ready.

## Prerequisites

This workshop assumes:

- **Basic Linux/command-line skills**: navigating directories, running commands, editing files
- **A Purdue career account with access to the Negishi cluster**
- **An SSH client**: terminal (macOS/Linux) or MobaXterm/PuTTY (Windows)
- **Genetics knowledge**: genes, alleles, and the basics of DNA sequencing

<!-- TBD(P2): how registrants get Negishi access (membership in the workshop SLURM account, a reservation, or their own group's account) and in the Depot group that can read the staged data. -->

No prior variant-calling experience is required.

## Scope of this workshop

This workshop teaches calling germline SNVs and small indels (under 50 bp) from Illumina short-read whole-genome data of diploid samples:

- **Dataset:** the Genome in a Bottle Ashkenazi trio: HG002 (child), HG003 (father), and HG004 (mother). Illumina NovaSeq, PCR-free, about 35x coverage, reads from chromosome 20.
- **Reference:** GRCh38, no-alt analysis set.
- **Benchmarks:** Genome in a Bottle truth sets for measuring call quality.

<!-- TBD(P2): read length, read counts per sample, benchmark versions, and any region or coverage subsetting. -->

### Toolchain

<!-- TBD(P2): module versions. samtools and bcftools are loaded with explicit versions (D5); record the version of every module used for the delivery. -->

| Step | Tools | Where it runs | Episode |
|:-----|:------|:--------------|:--------|
| Project setup and reference | samtools | Negishi shell | 2 |
| Read quality control | FastQC, MultiQC (fastp shown for reference) | Negishi, interactive job | 3 |
| Alignment and alignment QC | bwa mem, samtools, mosdepth, MultiQC | Negishi, SLURM batch and array jobs | 4 |
| Variant calling | bcftools | Negishi, SLURM array job | 5A |
| Filtering and evaluation | bcftools, hap.py | Negishi | 6 |
| Annotation | SnpEff, SnpSift, bcftools | Negishi | 7 |
| Trio analysis | bcftools, IGV | Negishi | 8 |

Command-line tools are loaded as modules with `module load biocontainers` followed by the tool module.

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

Episode 10 (self-paced) points to methods for these cases.

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

```bash
ssh your_username@negishi.rcac.purdue.edu
```

3. Enter your password (characters do not appear as you type, but your password is being entered)
4. Complete Purdue two-factor authentication

:::::::::::::::::::::::::

Once logged in, check that your scratch directory variable is set. Every episode works under `$SCRATCH`, so it must print your scratch path:

```bash
echo $SCRATCH
```

```output
/scratch/negishi/your_username
```

## Data setup

### Copying the workshop data

<!-- TBD(P3): the copy command from /depot/workshop/data/varcall-workshop into $SCRATCH/varcall-workshop, and the list of what it copies. The reference and its indexes stay on Depot and are linked from ref/ (plan section 5.4). -->

### Verifying the data

<!-- TBD(P3): verification commands, expected file count, and size of the copy. -->

::::::::::::::::::::::::::::::::::::::: callout

## Scratch is temporary

Negishi scratch is not backed up, and files that are not accessed for a while are purged automatically. Copy the data shortly before the workshop, and move anything you want to keep to your home directory or your group's Depot space afterwards.

:::::::::::::::::::::::::::::::::::::::

### Completed results (backup)

<!-- TBD(P3): how to use /depot/workshop/data/varcall-workshop_results when a job does not finish, with one copy example. -->

## Graphical session for IGV

<!-- TBD(P2): which graphical session learners use for IGV in Episodes 4 and 8 (an Open OnDemand desktop or ThinLinc), the resource request, and the fallback (samtools tview plus snapshots). -->
