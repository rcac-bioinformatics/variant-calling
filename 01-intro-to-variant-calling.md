---
source: Rmd
title: '1\. Introduction to genetic variation and variant calling'
teaching: 35
exercises: 15
---

:::::::::::::::::::::::::::::::::::::: questions

- What kinds of genetic variation can short-read sequencing detect?
- How does a variant caller turn aligned reads into a genotype?
- Why can a variant call be wrong?
- What question will we answer with the Ashkenazi trio today?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Distinguish SNVs, MNVs, indels and SVs/CNVs, and germline from somatic variants.
- Read diploid genotypes (0/0, 0/1, 1/1, ./.).
- Explain how a call is inferred from read evidence and base and mapping quality, and why errors arise.
- Describe the workflow and its files.
- State the workshop question for the GIAB Ashkenazi trio (HG002, HG003, HG004).

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

Variant calling answers a simple-sounding question: where does the DNA of this individual differ from a reference sequence, and what are the two alleles at each of those positions? The answer is never read directly off the sequencer. It is inferred from millions of short, imperfect reads, each placed on the genome by an aligner that can also be wrong. Every call is therefore a statistical statement with a confidence attached, and part of the job is deciding which statements to believe.

In this workshop we call variants on chromosome 20 in three people: a child and both parents, from the Genome in a Bottle (GIAB) Ashkenazi trio. Their genomes have been characterized so thoroughly that public benchmark call sets exist for all three, so later in the day we can measure how many of our calls are right instead of guessing.

This episode introduces the vocabulary and the reasoning. There are no commands to run.

## Types of genetic variation

A **variant** is a position, or a stretch of sequence, where a sample differs from the reference genome. The **allele** that matches the reference is the reference allele (REF); any other allele is an alternate allele (ALT).

| Type | What changes | Example (reference > sample) |
|---|---|---|
| Single-nucleotide variant (SNV) | One base is replaced by another | `T > C` |
| Multi-nucleotide variant (MNV) | Two or more adjacent bases change together | `AG > TC` |
| Insertion or deletion (indel) | Bases are added or removed | `T > TTGG` (insertion), `CAT > C` (deletion) |
| Structural variant (SV) | Larger rearrangements: large deletions and insertions, inversions, translocations | thousands of bases moved or lost |
| Copy-number variant (CNV) | A segment is present in more or fewer copies than in the reference | a gene present three times instead of twice |

In this lesson, "small variants" means SNVs and indels shorter than 50 bp. Structural and copy-number variants need different methods and are not covered (see the setup page).

SNVs come in two kinds that matter later. A **transition** exchanges a purine for a purine (A and G) or a pyrimidine for a pyrimidine (C and T). A **transversion** exchanges a purine for a pyrimidine or the reverse. The ratio of the two (Ts/Tv) is a quick quality check on a call set, which Episode 6 uses.

### Germline and somatic variants

A **germline** variant was inherited from a parent or arose in a parent's egg or sperm, so it is present in every cell of the body. A **somatic** variant arose after conception, in some cells only, and is present in only a fraction of the cells sampled. A germline variant in a diploid individual is therefore expected in either half of the reads (one copy) or all of them (two copies). A somatic variant can be present in any fraction. This workshop calls germline variants; somatic calling uses different statistical models and is not covered.

A **de novo** variant is a germline variant present in a child and absent from both parents. They are rare, and Episode 8 will show how hard they are to find among the many apparent de novo calls that are errors.

## The reference is a coordinate system

The reference genome is one haploid sequence used as a shared map. Every position has a name (`chr20:88108` is base 88,108 of chromosome 20), and REF is simply the base found at that position in the reference. REF is not "normal", "healthy" or "ancestral", and ALT is not necessarily rare or harmful. An ALT allele only differs from the reference sequence; it can be the more common allele at that position in many populations.

::::::::::::::::::::::::::::::::::::::: callout

## Two different frequencies

Two numbers are easy to confuse:

- **Variant allele fraction** (within one sample): the fraction of reads at a position that carry the ALT allele, for example 18 of 40 reads, 0.45. It tells you about the genotype of that one sample.
- **Population allele frequency**: the fraction of chromosomes in a population that carry the ALT allele, for example from gnomAD (Episode 7). It tells you how common the allele is among other people.

A heterozygous call has an allele fraction near 0.5 whether the allele is rare or common in the population.

:::::::::::::::::::::::::::::::::::::::

## Diploid genotypes

Humans are diploid: each autosome is present in two copies, one from each parent. A **genotype** lists the two alleles at a position, written as allele numbers: 0 is REF, 1 is the first ALT, 2 the second ALT, and so on. This is how genotypes appear in a VCF file, the format Episode 5A produces ([VCF specification](https://samtools.github.io/hts-specs/)).

| Genotype | Name | Meaning |
|---|---|---|
| `0/0` | homozygous reference | both copies match the reference |
| `0/1` | heterozygous | one copy REF, one copy ALT |
| `1/1` | homozygous alternate | both copies carry the ALT allele |
| `1/2` | heterozygous, two ALT alleles | each copy carries a different ALT allele |
| `./.` | missing | no genotype could be called (for example, no reads) |

The `/` means the two alleles are unphased: we know which two alleles are present, not which parental chromosome carries which. A `|` (as in `0|1`) marks a phased genotype.

## From reads to a genotype

A caller sees, at each position, the stack of aligned reads covering it: the **pileup**. The schematic pileups below show a 9 bp window. Dots are bases that match the reference; letters are mismatches.

```schematic
SCHEMATIC, NOT DATA
position     1 2 3 4 5 6 7 8 9
reference    A C G T T G C A T
read 1       . . . . C . . . .
read 2       . . . . . . . . .
read 3       . . . . C . . . .
read 4       . . . . . . . . .
read 5       . . . . C . . . .
read 6       . . . . . . . . .
read 7       . . . . C . . . .
read 8       . . . . . . . . .
```

At position 5, four of eight reads carry `C` and four carry the reference `T`. That is what a heterozygous `T/C` (genotype `0/1`) is expected to look like. A homozygous ALT site would show `C` in nearly every read.

Not every read counts equally. Two kinds of quality decide how much a read contributes:

- **Base quality** is the sequencer's estimate that a base call is wrong, on the Phred scale: Q = -10 log10(probability of error). Q20 means a 1 in 100 chance of error, Q30 1 in 1,000 ([SAM specification](https://samtools.github.io/hts-specs/SAMv1.pdf)). A mismatch on a Q2 base is weak evidence; a mismatch on a Q37 base is strong evidence.
- **Mapping quality (MAPQ)** is the aligner's estimate, on the same scale, that the read is placed at the wrong position in the genome. A read from a repeat that occurs twice in the genome cannot be placed with confidence, and gets a mapping quality near 0 (Episode 4).

The caller then asks, for each possible genotype (`0/0`, `0/1`, `1/1`): how likely are these reads, with these qualities, if that genotype were true? Those **genotype likelihoods** are stored in the VCF as `PL`, Phred-scaled so that the most likely genotype gets 0. The called genotype is the most probable one, and two quality values summarize the confidence ([VCF specification](https://samtools.github.io/hts-specs/); [bcftools manual](https://samtools.github.io/bcftools/bcftools.html)):

- **QUAL**, per site: how confident the caller is that any ALT allele is present at this position in any of the samples.
- **GQ** (genotype quality), per sample: how confident the caller is that this sample's genotype is the right one.

Calling, filtering and interpretation are separate steps. The caller writes down every site it thinks may be variant, together with these qualities. Filtering (Episode 6) decides which calls to trust. Interpretation (Episodes 7 and 8) decides what the trusted calls mean. Mixing them up, for example by treating every line of a raw VCF as a real variant, is one of the most common errors in variant analysis.

::::::::::::::::::::::::::::::::::::: instructor

Animation placeholder: "From reads to a genotype" (about 80 seconds) goes here. Its storyboard, scene list and alt text are specified in `maintenance/plan/figures/reads-to-genotype.md` (local file, not published); P7 builds the HTML animation in the style of the RNA-seq lesson animations. Until then, draw the pileup above on the board and walk through the three genotype hypotheses.

:::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: call the genotype

Each schematic pileup shows one position in one sample. All bases have high base quality, and all reads have high mapping quality unless marked. What genotype would you call at the marked position (`*`), and how confident are you?

```schematic
SCHEMATIC, NOT DATA        position *, reference base G

Pileup A (10 reads)   G G A G A A G A G A
Pileup B (3 reads)    A A A
Pileup C (12 reads)   A A A A A A A A A A A A
Pileup D (10 reads)   G G G G G G G G G A
Pileup E (8 reads)    A A A A G G G G     (every read has mapping quality 0)
```

::::::::::::::::::::::::::::::::::: solution

- **A:** 5 `A` and 5 `G`: heterozygous `0/1`, called with confidence.
- **B:** 3 `A`: most likely `1/1`, but only three reads. A heterozygous site shows only one allele in three reads one time in four (next section), so the genotype quality is low.
- **C:** 12 `A`: homozygous alternate `1/1`, confident.
- **D:** one `A` in 10 reads: most likely `0/0` with one sequencing error. If the `A` had low base quality, even more so.
- **E:** the allele fraction looks like a perfect heterozygote, but every read has mapping quality 0. The reads may come from another copy of a repeat, so the "variant" may be a difference between two copies of the repeat, not between this person's two chromosomes. A careful caller gives it little or no weight. Episode 6 filters sites like this on mapping quality.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::::::::::::

## How many reads make a heterozygous call?

At a heterozygous site, each read comes from one of the two chromosomes with equal probability, like a coin toss. With n reads, the chance that all of them come from the same chromosome, so that the site looks homozygous, is 2 x 0.5^n. This idealized model ignores sequencing errors and assumes both chromosomes are sampled equally.

| Reads (n) | Chance a heterozygous site shows only one allele |
|---|---|
| 3 | 0.25 (1 in 4) |
| 5 | 0.0625 (1 in 16) |
| 10 | 0.002 (about 1 in 500) |
| 15 | 0.00006 (about 1 in 16,000) |

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: how many reads before you trust a heterozygous call?

1. Use the formula above. At 5 reads, how often would a true heterozygous site look homozygous? At 10 reads?
2. Our samples have a mean depth of about 39x on chromosome 20 (Episode 4). Why is the mean depth not enough to say that every heterozygous site will be called correctly?
3. In Episode 6 we will set genotypes supported by fewer than 10 reads to missing (`./.`). What do we gain, and what do we lose?

::::::::::::::::::::::::::::::::::: solution

1. At 5 reads, 2 x 0.5^5 = 0.0625, about one heterozygous site in 16 looks homozygous. At 10 reads, 2 x 0.5^10 = 0.002, about one in 500. The benchmark for the child alone lists more than 70,000 SNVs on chromosome 20 (Episode 6), so even one in 500 of the heterozygous ones adds up.
2. Depth varies along the genome. A mean of 39x includes positions with far fewer reads (and far more), and the low-depth positions are where heterozygous sites are missed or miscalled. Episode 4 measures how much of chromosome 20 is covered at a given depth.
3. We gain precision: genotypes with too little evidence no longer count as calls. We lose recall: some true genotypes become missing. Episode 6 measures this trade-off against the benchmark.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::::::::::::

## Why calls can be wrong

Every error source below produces calls that look real in a raw VCF:

- **Sequencing errors.** A wrong base on a few reads looks like a low-fraction ALT allele. Base quality and the number of supporting reads separate most of them from real variants.
- **Sampling.** Too few reads, or unlucky sampling, makes a heterozygous site look homozygous or hides it (previous section).
- **Mapping errors.** Reads from a repeat or a duplicated region can be placed at the wrong copy. Differences between the copies then look like variants. Mapping quality flags many of these reads, not all.
- **Duplicates.** Copies of the same original DNA fragment are not independent evidence. Episode 4 marks them so the caller can skip them.
- **Reference problems.** Gaps, errors or collapsed repeats in the reference attract misplaced reads.
- **Representation.** One indel can often be written in several equivalent ways, and two call sets can disagree only in how they wrote it. Episode 5A normalizes calls to remove this.

## What short reads cannot see

Our reads are 151 bases long, from DNA fragments a few hundred bases long. A read cannot be placed uniquely if it falls entirely inside a repeat longer than the fragment. In our data, about 5% of each sample's reads get mapping quality 0, which means the aligner found several equally good places for them (Episode 4).

Repeats concentrate the errors. In the reference run of this workshop, the centromere of chromosome 20, about 5.6% of the chromosome's length, held 22% of the raw SNV calls in the child (HG002), with a transition/transversion ratio of 1.22, far below the 2.28 of calls inside the benchmark regions ([reference-run memo](https://github.com/rcac-bioinformatics/variant-calling/blob/main/maintenance/plan/reference-run.md), section 3). Many of those calls are almost certainly mapping artifacts, and Episode 6 filters most of them.

Short reads also miss most structural variants, cannot resolve which copy of a segmental duplication a read comes from, and cannot tell which parental chromosome carries each allele over long distances (phasing). Other methods, such as long-read sequencing, are needed for these questions; they are outside the scope of this workshop.

## The workflow and its files

| Step | Episode | Tools | Input | Output |
|---|---|---|---|---|
| Set up the project and check the data | 2 | `rsync`, `md5sum`, samtools | staged copy on Depot | `data/`, `ref/`, `resources/`, `scripts/`, `results/` |
| Check read quality | 3 | FastQC, MultiQC | FASTQ (`data/*.fastq.gz`) | `results/qc/multiqc_report.html` |
| Align reads, mark duplicates | 4 | bwa mem, samtools | FASTQ, reference and bwa index | `results/bam/<sample>.markdup.bam` and `.csi` index |
| Check the alignments | 4 | samtools, mosdepth, MultiQC | BAM | `results/qc_alignment/` |
| Call variants jointly in the trio | 5A | bcftools | three BAMs, reference | `results/vcf/trio.norm.vcf.gz` |
| Filter and evaluate | 6 | bcftools, hap.py | VCF, GIAB benchmarks | `results/vcf/trio.filtered.vcf.gz`, `results/eval/` |
| Annotate | 7 | SnpEff, bcftools | filtered VCF, gnomAD frequencies | `results/annot/trio.ann.vcf.gz` |
| Find candidate variants in the trio | 8 | bcftools | annotated VCF, PED file | `results/trio/funnel.tsv`, `results/trio/candidates.tsv` |

The file formats (FASTQ, BAM, VCF, BED, PED) are introduced in the episode where they first appear.

::::::::::::::::::::::::::::::::::::: instructor

A workflow diagram for this table is a P7 figure (plan section 2). Until it exists, sketch the boxes on the board: FASTQ to BAM to VCF, with the QC step after each.

:::::::::::::::::::::::::::::::::::::::::::::::::

## The workshop question

The trio is a child (HG002) and both parents (HG003, HG004). By the end of the day we will ask:

> In the child, which variants are consistent with a de novo or a recessive inheritance model, are plausibly protein-altering, and are rare in an ancestry-matched population? How many of these candidates survive inspection?

Answering it needs every step of the workflow: good alignments, trustworthy calls, filters we can justify, measured error rates, and annotation. It also needs restraint. These are public reference samples, and nothing we find says anything about anyone's health. The goal is to learn how evidence accumulates, and how often an exciting-looking candidate turns out to be an error.

::::::::::::::::::::::::::::::::::::::: discussion

## Discussion: what would convince you?

Suppose the final list contains one variant that is heterozygous in the child and absent from both parents. Before calling it a de novo mutation, what evidence would you want to see? Keep your list; Episode 8 comes back to it.

:::::::::::::::::::::::::::::::::::::::::::::::::

## Summary

::::::::::::::::::::::::::::::::::::: keypoints

- A variant is a difference from the reference sequence. The reference is a coordinate system, not a description of a healthy or ancestral genome.
- Diploid genotypes are written as allele numbers: `0/0`, `0/1`, `1/1`, and `./.` for missing.
- A caller weighs each read by its base quality and mapping quality, computes genotype likelihoods, and reports the most probable genotype with QUAL and GQ.
- At a heterozygous site, the chance of seeing only one allele in n reads is 2 x 0.5^n, so low-depth genotypes are unreliable.
- Sequencing errors, sampling, mapping errors in repeats, duplicates and representation differences all produce calls that look real. Calling, filtering and interpretation are separate steps.

::::::::::::::::::::::::::::::::::::::::::::::::
