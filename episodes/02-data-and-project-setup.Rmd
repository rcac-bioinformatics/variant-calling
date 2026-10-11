---
source: Rmd
title: '2\. Data, reference genomes, and project setup'
teaching: 20
exercises: 20
---

:::::::::::::::::::::::::::::::::::::: questions

- What data will we analyze, and where does it come from?
- What makes a reference genome suitable for variant calling?
- How do we organize the project and record sample metadata?
- How do we check that the data is complete and unchanged?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Verify the staged copy and lay out the project.
- Describe the HG002, HG003 and HG004 trio and record its metadata as a sample sheet and a PED file.
- Explain the GRCh38 no-alt analysis set, contig naming and index files (`.fai`, `.dict`, aligner index).
- Convert BED (0-based, half-open) to VCF-style (1-based) coordinates.
- Check integrity with md5.

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

Before any analysis, we need to know exactly what the data is, where it came from, and that our copy is complete. In this episode we look at the dataset and its sample metadata, check the files with checksums, and get to know the reference genome and its index files. These are short steps, but most failed variant-calling runs trace back to one of them: a truncated file, a reference that does not match the reads, or a sample recorded under the wrong name.

::::::::::::::::::::::::::::::::::::::: prereq

## Before you start

Complete the "Data setup" section of the [setup page](../learners/setup.md): copy the workshop data to `$SCRATCH/varcall-workshop` and link the reference into `ref/`. Every command in this episode runs on a Negishi login node; they are all quick.

:::::::::::::::::::::::::::::::::::::::

## The Ashkenazi trio

The [Genome in a Bottle](https://www.nist.gov/programs-projects/genome-bottle) (GIAB) consortium, hosted by NIST, characterizes reference human genomes and publishes benchmark variant calls for them. We use its Ashkenazi trio, a son and his parents:

| Sample | Cell line | Role | Sex |
|---|---|---|---|
| HG002 | NA24385 | child | male |
| HG003 | NA24149 | father | male |
| HG004 | NA24143 | mother | female |

The reads come from the [DeepTrio WGS case study](https://github.com/google/deepvariant/blob/r1.10/docs/deeptrio-wgs-case-study.md), which provides alignments of each sample to GRCh38 restricted to chromosome 20. We converted those alignments back to paired FASTQ files, so that you can align them yourself. The facts below were measured on the source files in this workshop's feasibility run ([feasibility memo](https://github.com/rcac-bioinformatics/variant-calling/blob/main/maintenance/plan/feasibility.md)):

- **Sequencing:** Illumina NovaSeq, PCR-free library, 151 bp paired-end reads.
- **Base qualities:** binned to four values (Episode 3).
- **Depth:** the files are labeled 35x, but the mean depth on chromosome 20 is about 40x (39.2x to 39.9x in the source alignments).
- **Duplicates:** the source alignments had duplicates marked, not removed (about 2.0 million flagged reads per sample). Converting to FASTQ kept those reads, so you will mark duplicates again in Episode 4.
- **Read pairs:** HG002 9,462,450, HG003 9,480,040, HG004 9,347,118. All six FASTQ files together are 4.85 GB.

::::::::::::::::::::::::::::::::::::::: callout

## The reads were selected from chromosome 20 alignments

Every read in our FASTQ files was aligned to chromosome 20 in the source data. About 330,000 reads per sample had a mate aligned elsewhere in the genome, and those reads were dropped, because a read without its mate cannot go into a paired FASTQ file.

Two consequences follow. First, when we align these reads to the whole genome in Episode 4, almost all of them land on chromosome 20 again. Mapping rates near 100% and almost no coverage on other chromosomes are artifacts of how the data was selected, not properties of a real whole-genome run. Second, reads that the source alignment placed on other chromosomes were never selected, so this data cannot show reads moving between chromosome 20 and similar sequences elsewhere, as they would in a real whole-genome run.

:::::::::::::::::::::::::::::::::::::::

## Project layout

The setup page created this layout under `$SCRATCH/varcall-workshop`:

| Directory | Contents |
|---|---|
| `data/` | the six FASTQ files, `md5sums.txt`, the sample sheet `samples.tsv`, the pedigree `trio.ped` |
| `ref/` | links to the read-only reference genome, its indexes and the annotation database on Depot |
| `resources/` | benchmark call sets (`truth/`), population frequencies (`gnomad/`), region lists (`regions/`), and a small example VCF (`example/`) |
| `scripts/` | the SLURM job scripts for Episodes 4 to 7 |
| `results/` | one folder per step: `qc`, `bam`, `qc_alignment`, `vcf`, `eval`, `annot`, `trio` |

The reference and its indexes take more than 10 GB. Every learner uses the same files, so they stay in one read-only copy on Depot, and `ref/` holds symbolic links to them instead of copies.

## Step 1: Check the copy with checksums

A checksum is a short fingerprint computed from a file's contents. If a single byte changes, the checksum changes. `md5sums.txt` holds the MD5 checksum of every FASTQ file as it was staged; `md5sum -c` recomputes each one and compares.

<!-- kit: extra 02-setup.sh -->
```bash
cd $SCRATCH/varcall-workshop
```

<!-- kit: interactive 02-setup.sh -->
```bash
cd data
md5sum -c md5sums.txt
cd ..
```

This reads all 4.85 GB, so give it up to a minute.

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
HG002_R1.fastq.gz: OK
HG002_R2.fastq.gz: OK
HG003_R1.fastq.gz: OK
HG003_R2.fastq.gz: OK
HG004_R1.fastq.gz: OK
HG004_R2.fastq.gz: OK
```

Every file must report `OK`. A `FAILED` line means that file is damaged or incomplete; copy it again with the `rsync` command from the setup page and rerun the check.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: callout

## Why checksums?

File sizes can match while contents differ, and a transfer that stops early can leave a file that looks normal until a tool fails on it hours later. Checksums catch both. Record them when you receive data, check them after every copy, and keep them with the data as part of its provenance. The sources we downloaded from publish checksums too, and we checked every download against them before staging ([`data-prep/sources.tsv`](https://github.com/rcac-bioinformatics/variant-calling/blob/main/data-prep/sources.tsv) lists each file, its size and its MD5).

:::::::::::::::::::::::::::::::::::::::

## Step 2: The sample sheet and the pedigree

Two small text files describe the samples. Every later step reads them, so they are worth a careful look.

<!-- kit: interactive 02-setup.sh -->
```bash
head data/samples.tsv
cat data/trio.ped
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
sample	role	sex	family	fastq_r1	fastq_r2	rg_id	rg_lb	rg_pl
HG002	child	1	AJ	HG002_R1.fastq.gz	HG002_R2.fastq.gz	HG002.pcr-free	HG002.pcr-free	ILLUMINA
HG003	father	1	AJ	HG003_R1.fastq.gz	HG003_R2.fastq.gz	HG003.pcr-free	HG003.pcr-free	ILLUMINA
HG004	mother	2	AJ	HG004_R1.fastq.gz	HG004_R2.fastq.gz	HG004.pcr-free	HG004.pcr-free	ILLUMINA
AJ	HG002	HG003	HG004	1	0
AJ	HG003	0	0	1	0
AJ	HG004	0	0	2	0
```

:::::::::::::::::::::::::::::::::::::

`samples.tsv` is the sample sheet: one row per sample, with a header. Its columns are the sample name, its role and sex, the family, the two FASTQ files, and three read-group fields (`rg_id`, `rg_lb`, `rg_pl`) that Episode 4 writes into the alignments. The alignment script reads it line by line, so the sample names in the VCF come from this file.

`trio.ped` is a pedigree file in the PED format used by PLINK, bcftools and other tools ([PLINK file formats](https://www.cog-genomics.org/plink/1.9/formats#fam)). It has no header and six whitespace-separated columns:

1. family ID
2. individual ID
3. father's ID (`0` if not in the file)
4. mother's ID (`0` if not in the file)
5. sex (`1` male, `2` female, `0` unknown)
6. phenotype (`1` unaffected, `2` affected, `0` or `-9` missing)

The parents have `0` in columns 3 and 4 because their own parents are not part of the dataset. No phenotype is recorded for anyone. Episode 8 uses this file to check Mendelian inheritance.

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: write a PED line

1. Without looking at `trio.ped`, write the PED line for HG002. Then compare it with the file.
2. Suppose the family had a second child, a daughter with the sample ID `KID2`, sequenced in the same project. Write her line.
3. What would go wrong in a trio analysis if columns 3 and 4 of HG002's line were swapped?

::::::::::::::::::::::::::::::::::: solution

1. The family ID in this file is `AJ`, and HG002 is male with no recorded phenotype:

   ```text
   AJ	HG002	HG003	HG004	1	0
   ```

   It should match the first line of `trio.ped` shown above.

2. `AJ	KID2	HG003	HG004	2	0`: same family, same parents, sex `2` for female.
3. Swapping father and mother changes nothing for autosomal inheritance checks such as the ones in Episode 8, but any analysis that uses sex, for example of the X chromosome, would treat the father as the mother. Metadata errors rarely fail loudly; check this file whenever you build one.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

## Step 3: The reference genome

We align to GRCh38, the current human reference assembly, in a version prepared for read-alignment pipelines: the **no-alt analysis set** from NCBI ([README in the NCBI directory](https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/)). According to its README, it contains:

- the chromosomes, the mitochondrial genome, and the unlocalized and unplaced scaffolds of GRCh38;
- an Epstein-Barr virus sequence (`chrEBV`), not part of the human genome, included as a "sink" for reads from the virus, which are often present in sequencing samples;
- and it leaves out the **alternate locus scaffolds** (alt contigs), extra versions of highly variable regions, because many alignment pipelines cannot handle them. An aligner that is not alt-aware would split reads from those regions between near-identical copies and give them low mapping quality ([bwa README-alt](https://github.com/lh3/bwa/blob/master/README-alt.md)).

The README also states that the two pseudoautosomal regions on chromosome Y, and duplicate copies of some centromeric arrays, are masked with `N`, for the same reason. Our copy has no decoy sequences (the README describes a separate set with them).

::::::::::::::::::::::::::::::::::::::: callout

## Why the exact reference matters

Reads, alignments, variant calls, benchmarks and annotation databases must all use the same assembly and the same sequence names. GRCh37 and GRCh38 coordinates differ. Even within GRCh38, sequence names differ between sources: this analysis set uses UCSC-style names (`chr20`), while some other resources name the same sequence `20`. A mismatch rarely fails loudly. More often a tool silently finds no overlap, or skips the "unknown" chromosome, and the result is empty or wrong. Check names first whenever you combine files from different sources.

:::::::::::::::::::::::::::::::::::::::

The reference comes with index files. Each tool needs its own:

| File | Made by | Used by | What it holds |
|---|---|---|---|
| `GRCh38_no_alt.fa.fai` | `samtools faidx` | samtools, bcftools, most tools | name, length and byte offsets of each sequence, for fast random access |
| `GRCh38_no_alt.dict` | `samtools dict` | GATK and Picard (Episode 5B) | a sequence dictionary: names, lengths and MD5 checksums in SAM header format |
| `GRCh38_no_alt.fa.{amb,ann,bwt,pac,sa}` | `bwa index` | bwa (Episode 4) | the aligner's index; NCBI publishes it, so we did not build it |
| `GRCh38_no_alt.sdf` | `rtg format` | hap.py with the vcfeval engine (Episode 6) | the reference in RTG's format |

Look at the FASTA index and the dictionary:

<!-- kit: extra 02-setup.sh -->
```bash
head -3 ref/GRCh38_no_alt.fa.fai
grep -w chr20 ref/GRCh38_no_alt.fa.fai
wc -l ref/GRCh38_no_alt.fa.fai
head -3 ref/GRCh38_no_alt.dict
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
chr1	248956422	112	70	71
chr2	242193529	252513167	70	71
chr3	198295559	498166716	70	71
chr20	64444167	2751788762	70	71
195 ref/GRCh38_no_alt.fa.fai
@HD	VN:1.0	SO:unsorted
@SQ	SN:chr1	LN:248956422	M5:6aef897c3d6ff0c78aff06ac189178dd	UR:GRCh38_no_alt.fa	AS:GRCh38	SP:Homo sapiens
@SQ	SN:chr2	LN:242193529	M5:f98db672eb0993dcfdabafe2a882905c	UR:GRCh38_no_alt.fa	AS:GRCh38	SP:Homo sapiens
```

The `.fai` columns are the sequence name, its length, the byte offset of its first base in the FASTA file, the number of bases per line, and the number of bytes per line. The analysis set has 195 sequences. chr20 is 64,444,167 bp long, and the same length appears in the headers of the source alignments. The `.dict` lines follow the SAM header format: `@SQ` lines with `SN` (name), `LN` (length), `M5` (MD5 of the sequence), and the file, assembly and species (`UR`, `AS`, `SP`).

:::::::::::::::::::::::::::::::::::::

With the index, `samtools faidx` extracts any region without reading the whole 3.1 GB file. Load samtools with its explicit version (the workshop pins every tool version; see the setup page):

<!-- kit: extra 02-setup.sh -->
```bash
module load biocontainers
module load samtools/1.22.1
samtools faidx ref/GRCh38_no_alt.fa chr20:88098-88118
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
>chr20:88098-88118
ATTTCATTGTTGTGTCCTATT
```

The first line is a message the biocontainers module prints when it is loaded; the region follows as a short FASTA record. The region is 21 bases: `samtools faidx` regions are 1-based and include both ends ([samtools faidx manual](https://www.htslib.org/doc/samtools-faidx.html)). Base 88,108, a `T`, sits in the middle. Remember this position; the child is heterozygous there, and we will come back to it in Episodes 4 and 5A.

:::::::::::::::::::::::::::::::::::::

## Step 4: Coordinate systems

Genomic files count positions in two different ways:

- **1-based, closed** (VCF, SAM, `samtools` regions such as `chr20:88098-88118`): the first base of a chromosome is 1, and a range includes both its start and its end.
- **0-based, half-open** (BED): the first base is 0, the start is included, and the end is not. The BED interval `chr20 88107 88108` is one base long: base 88,108 in 1-based coordinates ([UCSC BED format](https://genome.ucsc.edu/FAQ/FAQformat.html#format1)).

To convert a BED interval to 1-based coordinates, add 1 to the start and keep the end. The length of a BED interval is simply end minus start.

The benchmark regions we use in Episode 6 are BED files. Look at the first lines of the one for HG002:

<!-- kit: extra 02-setup.sh -->
```bash
head -3 resources/truth/HG002_v4.2.1_chr20.bed
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
chr20	81335	101267
chr20	101308	102558
chr20	102684	105312
```

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: convert coordinates

1. Write the first interval of `HG002_v4.2.1_chr20.bed` as a 1-based `samtools` region. How many bases does it cover?
2. A VCF record has `POS` 1000 and `REF` `CAT`, a deletion of `AT`. Which bases does `REF` span, in 1-based coordinates? Write the same span as a BED line.
3. Write the region we extracted with `samtools faidx` (`chr20:88098-88118`) as a BED line.

::::::::::::::::::::::::::::::::::: solution

1. The first line is `chr20	81335	101267`. Add 1 to the start and keep the end: `chr20:81336-101267`. Its length is end minus start of the BED line: 101267 - 81335 = 19,932 bp.
2. `REF` spans bases 1000 to 1002 (three bases, `C`, `A`, `T`). As BED: `chr20	999	1002`.
3. `chr20	88097	88118`: subtract 1 from the start, keep the end. The length is 88118 - 88097 = 21, as before.

Off-by-one errors are among the most common bugs in genomics scripts. When a tool accepts both formats, check which one it expects.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

## Step 5: What a FASTQ record looks like

Each read in a FASTQ file takes four lines: a name, the sequence, a `+` separator, and one quality character per base.

<!-- kit: extra 02-setup.sh -->
```bash
zcat data/HG002_R1.fastq.gz | head -4
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
@A00744:46:HV3C3DSXX:2:1654:24334:32456
GACTGGGGAATTATGAGTTCCCTGTACCAACAGCGGAATGGGCTTTTCCCCACAGAGTGACATACTCCATCAGGAAAAAGAAAATGGAATTTACAACACAAACTTTCAAATAATTTGTGATGGAATGGGGAACAGAAACTAAGGCTCACAT
+
FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF:FFFFF:FFFFFFFFFFFFFFFFFFF,FFFFFF:FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF:FFFFFFFFFF,FFFFFFFFFFFFFFFFF:F
```

The first line is the read name; it records the instrument, run, flow cell, lane, tile and cluster position. The fourth line encodes the base qualities: here mostly `F`, with a few `:` and `,`. Episode 3 decodes it.

:::::::::::::::::::::::::::::::::::::

The files are compressed with gzip (`.gz`). Later we meet BGZF, the block-compressed variant made by `bgzip`: it is still readable by `zcat`, but it also allows an index and random access, which BAM and indexed VCF files need. A VCF compressed with plain `gzip` cannot be indexed.

## Data responsibility

::::::::::::::::::::::::::::::::::::::: callout

## Public data here, controlled data at home

The GIAB data are public. NIST allows copying and redistribution of its benchmark data with acknowledgment of NIST (Data Usage section of the GIAB v5.0q README), which is why a copy can sit on Depot for this workshop.

Your own human sequencing data may be different. Data from patients or research participants often comes with consent limits, data use agreements, or legal protections, and may only be stored and analyzed on approved, access-controlled systems. Do not copy such data to scratch or to a shared workshop space just because the commands work there. Before you start, ask your data provider and RCAC (rcac-help@purdue.edu) where the data may be stored and processed.

:::::::::::::::::::::::::::::::::::::::

## Downloading from the source (not run)

::::::::::::::::::::::::::::::::::::: spoiler

## How was the staged data made?

*Reference only: do not run these commands in the workshop. The downloads are more than 9 GB, and the staged copy already contains the results.*

The source alignments for the three samples:

<!-- kit: not-run download -->
```bash
wget https://storage.googleapis.com/deepvariant/case-study-testdata/HG002.novaseq.pcr-free.35x.dedup.grch38_no_alt.chr20.bam
wget https://storage.googleapis.com/deepvariant/case-study-testdata/HG003.novaseq.pcr-free.35x.dedup.grch38_no_alt.chr20.bam
wget https://storage.googleapis.com/deepvariant/case-study-testdata/HG004.novaseq.pcr-free.35x.dedup.grch38_no_alt.chr20.bam
```

Each alignment was converted to paired FASTQ. `samtools collate` groups the two reads of a pair together, and `samtools fastq` writes them to two files; reads whose mate is missing go to `/dev/null`:

<!-- kit: not-run download -->
```bash
module load biocontainers
module load samtools/1.22.1
samtools collate -u -O -T collate.tmp HG002.novaseq.pcr-free.35x.dedup.grch38_no_alt.chr20.bam \
  | samtools fastq -n -1 HG002_R1.fastq.gz -2 HG002_R2.fastq.gz -0 /dev/null -s /dev/null -
```

The reference FASTA, its `.fai` index and the bwa index from NCBI:

<!-- kit: not-run download -->
```bash
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.fai
wget https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.bwa_index.tar.gz
```

The benchmark call sets come from the GIAB release directories, for example the HG002 v5.0q small-variant benchmark and its regions:

<!-- kit: not-run download -->
```bash
wget https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/latest/HG002_GRCh38_v5.0q_smvar.vcf.gz
wget https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/latest/HG002_GRCh38_v5.0q_smvar.benchmark.bed
```

The full list of sources, with sizes and checksums, is in [`data-prep/sources.tsv`](https://github.com/rcac-bioinformatics/variant-calling/blob/main/data-prep/sources.tsv), and the preparation scripts are in [`data-prep/`](https://github.com/rcac-bioinformatics/variant-calling/tree/main/data-prep).

:::::::::::::::::::::::::::::::::::::

## Summary

::::::::::::::::::::::::::::::::::::: keypoints

- The data are the GIAB Ashkenazi trio (HG002 child, HG003 father, HG004 mother): NovaSeq PCR-free 151 bp paired reads, about 40x on chromosome 20.
- The reads were selected from chromosome 20 alignments, so mapping rate and coverage outside chromosome 20 are not realistic.
- Check every copy with checksums (`md5sum -c`) before using it.
- The sample sheet and the PED file record sample names, roles, sex and relationships; later steps depend on them being right.
- The GRCh38 no-alt analysis set leaves out alt contigs and uses UCSC-style names (`chr20`); every file in an analysis must use the same assembly and sequence names.
- BED is 0-based and half-open; VCF, SAM and samtools regions are 1-based and closed.
- Public reference data can be shared; your own human data may need an approved, controlled system.

::::::::::::::::::::::::::::::::::::::::::::::::
