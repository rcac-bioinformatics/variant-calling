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

- Allelic depth (AD)
- Benchmark (truth set)
- Confident regions
- Depth cap (`mpileup -d`)
- F1 score
- False negative
- False positive
- FILTER field
- Genotype likelihood
- Genotype mask
- Genotype quality (GQ)
- Haplotype-aware comparison
- Hard filter
- INFO and FORMAT fields (site-level and per-sample)
- Joint calling
- Multiallelic site
- Normalization (left-alignment, multiallelic splitting)
- PL field
- Precision
- Prior (in `bcftools call`)
- QUAL
- Recall
- ROC curve (precision and recall by threshold)
- Site-level and genotype-level filters
- Soft filter
- Stratification
- Test-set leakage (tuning on the benchmark)
- True positive
- UNK (not assessed)

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

### Sources cited in Episodes 5A and 6

Specifications, methods and benchmarks:

- VCF specification, version 4.3 (reserved INFO and FORMAT fields, QUAL, GQ, PL): <https://samtools.github.io/hts-specs/VCFv4.3.pdf>
- Li H. (2011). A statistical framework for SNP calling, mutation discovery, association mapping and population genetical parameter estimation from sequencing data. Bioinformatics 27(21): 2987-2993. <https://doi.org/10.1093/bioinformatics/btr509>
- Tan A., Abecasis G. R., Kang H. M. (2015). Unified representation of genetic variants. Bioinformatics 31(13): 2202-2204. <https://doi.org/10.1093/bioinformatics/btv112>
- Krusche P. et al. (2019). Best practices for benchmarking germline small-variant calls in human genomes. Nature Biotechnology 37: 555-560. <https://doi.org/10.1038/s41587-019-0054-x>
- GIAB HG002 v5.0q benchmark README, NIST: <https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/latest/NIST_HG002_v5.0q_variant-benchmarksets_README.md>

Tools:

- bcftools manual, with the sections for [`filter`](https://samtools.github.io/bcftools/bcftools.html#filter) and [`isec`](https://samtools.github.io/bcftools/bcftools.html#isec). Default values in Episodes 5A and 6 come from the usage text of the pinned bcftools 1.24 (`bcftools mpileup`, `call`, `filter` and `norm` without arguments), which the workshop's run kit records.
- htslib `sam.h` (version 1.24), the comment on `bam_mplp_init_overlaps`: how overlapping read pairs are handled in a pileup: <https://github.com/samtools/htslib/blob/1.24/htslib/sam.h>
- hap.py user guide (vcfeval engine, `summary.csv` columns, UNK, ROC tables): <https://github.com/Illumina/hap.py/blob/master/doc/happy.md>
- FastQC program options (`--nogroup`): <https://github.com/s-andrews/FastQC/blob/master/fastqc>; adapter list, including the poly-A and poly-G series: <https://github.com/s-andrews/FastQC/blob/master/Configuration/adapter_list.txt>

Figures:

- The precision-recall figure in Episode 6 is drawn by the workshop's run kit (`negishi-run/pr_figure.py`) from the hap.py ROC tables of a test run.
- The FastQC contrast cartoons in Episode 3 are by Zandra Selina, CC BY 4.0, reused from the [RCAC RNA-seq workshop](https://github.com/rcac-bioinformatics/rnaseq-analysis).
