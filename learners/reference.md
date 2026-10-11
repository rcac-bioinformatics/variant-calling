---
title: Reference
---

## Glossary

<!-- TBD(P7): definitions. Every term is defined at or before its first use in the episodes. -->

### Variation and genotypes

- Allele
- Allele balance
- Allele frequency (population)
- Copy-number variant (CNV)
- De novo variant
- Genotype
- Germline variant
- Heterozygous
- Homozygous alternate
- Homozygous reference
- Indel
- Mendelian error
- Multi-nucleotide variant (MNV)
- Phasing (phased and unphased genotypes)
- Pileup
- Ploidy
- Single-nucleotide variant (SNV)
- Somatic variant
- Structural variant (SV)
- Transition and transversion (Ts/Tv)
- Variant allele fraction

### Reference genomes and file formats

- Alt contig
- BAM, CRAM and SAM
- BCF
- BED
- BGZF (block gzip)
- bgzip
- Checksum (MD5)
- Contig
- Coordinate systems (0-based half-open, 1-based closed)
- Decoy sequence
- FASTA
- FASTQ
- gVCF
- Index (`.fai`, `.dict`, `.bai`, `.csi`, `.tbi`)
- No-alt analysis set
- PED file
- Pseudoautosomal region (PAR)
- Reference genome
- Sample sheet
- Sequence dictionary (`.dict`)
- VCF

### Sequencing and alignment

- Base alignment quality (BAQ)
- Base quality (Phred score)
- Base quality score recalibration (BQSR)
- CIGAR string
- Coverage (depth)
- Duplicate marking
- Duplicate read (PCR, optical)
- FLAG
- Insert size
- IUPAC ambiguity code
- Local alignment
- Mapping quality (MAPQ)
- Paired-end reads
- Proper pair
- Quality binning
- Read group
- Secondary alignment
- Seed-and-extend alignment
- Soft clipping
- Supplementary alignment
- Template length (TLEN)

### Calling, filtering and evaluation

- Benchmark (truth set)
- Confident regions
- F1 score
- False negative
- False positive
- FILTER field
- Genotype likelihood
- Genotype quality (GQ)
- Hard filter
- Joint calling
- Normalization (left-alignment, multiallelic splitting)
- PL field
- Precision
- QUAL
- Recall
- Soft filter
- Stratification
- True positive

### Annotation and interpretation

- ANN field
- ClinVar
- Consequence (effect)
- gnomAD
- HGVS notation
- Impact class
- MANE transcript
- Sequence Ontology term
- Transcript

### Running jobs on the cluster

- Array job
- Interactive session (`sinteractive`)
- Login node
- Module (`module load`)
- Standby QoS

## Further reading

<!-- TBD(P7): references for the methods and tools of Episodes 5A-8, and for the topics listed under "What is not covered" on the setup page. -->

### Sources cited in Episodes 1-4

Data and reference:

- Genome in a Bottle, NIST: <https://www.nist.gov/programs-projects/genome-bottle>. The data usage terms are in the HG002 v5.0q README in the [HG002 release directory](https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/latest/).
- DeepTrio WGS case study (source of the chromosome 20 alignments): <https://github.com/google/deepvariant/blob/r1.10/docs/deeptrio-wgs-case-study.md>
- GRCh38 no-alt analysis set and its README, NCBI: <https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/000/001/405/GCA_000001405.15_GRCh38/seqs_for_alignment_pipelines.ucsc_ids/>
- Workshop data sources, sizes and checksums: <https://github.com/rcac-bioinformatics/variant-calling/blob/main/data-prep/sources.tsv>, and the preparation scripts: <https://github.com/rcac-bioinformatics/variant-calling/tree/main/data-prep>
- Workshop run records: the [feasibility memo](https://github.com/rcac-bioinformatics/variant-calling/blob/main/maintenance/plan/feasibility.md) and the [reference-run memo](https://github.com/rcac-bioinformatics/variant-calling/blob/main/maintenance/plan/reference-run.md)

File formats:

- SAM and BAM: <https://samtools.github.io/hts-specs/SAMv1.pdf>; VCF, CRAM and the other htslib formats: <https://samtools.github.io/hts-specs/>
- BED (UCSC): <https://genome.ucsc.edu/FAQ/FAQformat.html#format1>
- PED and FAM (PLINK 1.9): <https://www.cog-genomics.org/plink/1.9/formats#fam>

Tools:

- bwa manual: <https://bio-bwa.sourceforge.net/bwa.shtml>; alt-aware alignment: <https://github.com/lh3/bwa/blob/master/README-alt.md>
- samtools manual: <https://www.htslib.org/doc/samtools.html>, with the pages for [faidx](https://www.htslib.org/doc/samtools-faidx.html), [flags](https://www.htslib.org/doc/samtools-flags.html), [markdup](https://www.htslib.org/doc/samtools-markdup.html), [tview](https://www.htslib.org/doc/samtools-tview.html) and [view](https://www.htslib.org/doc/samtools-view.html)
- bcftools manual: <https://samtools.github.io/bcftools/bcftools.html> (see [`mpileup`](https://samtools.github.io/bcftools/bcftools.html#mpileup))
- mosdepth: <https://github.com/brentp/mosdepth>
- FastQC: <https://www.bioinformatics.babraham.ac.uk/projects/fastqc/>
- fastp: <https://github.com/OpenGene/fastp>
- GATK base quality score recalibration: <https://gatk.broadinstitute.org/hc/en-us/articles/360035890531-Base-Quality-Score-Recalibration-BQSR>

Figures:

- The FastQC contrast cartoons in Episode 3 are by Zandra Selina, CC BY 4.0, reused from the [RCAC RNA-seq workshop](https://github.com/rcac-bioinformatics/rnaseq-analysis).
