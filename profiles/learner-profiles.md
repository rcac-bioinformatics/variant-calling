---
title: Learner Profile
---

This lesson is designed for researchers who want to find genetic variants in their own sequencing data using standard tools and reproducible workflows. Learners are typically graduate students, postdocs, research staff, or faculty working with DNA sequencing data from humans, animals, or plants.

### Background and experience

* Familiarity with basic genetics: genes, alleles, and the basics of DNA sequencing
* Some exposure to the command line (navigating directories, running commands)
* Little or no experience with SLURM or HPC clusters
* Little or no prior experience with variant calling
* No requirement for programming experience beyond running provided scripts

### Motivations

* Call variants in sequencing data from their own samples or populations
* Learn a standard workflow from raw reads to a filtered, annotated variant set
* Understand how reliable variant calls are and how to measure it
* Gain exposure to reproducible analysis approaches on HPC systems

### Needs and goals

* Know how to evaluate read and alignment quality
* Learn how to align reads and produce analysis-ready BAM files
* Call, normalize, and filter variants across several samples
* Read and query VCF files with confidence
* Measure call quality against a benchmark, or with proxy measures when none exists
* Annotate variants and interpret them without overclaiming
* Adapt the workflow to their own organism and data

### Challenges

* Managing multiple tools, file formats, and coordinate systems
* Understanding genotype likelihoods, quality scores, and filtering trade-offs
* Navigating HPC environments, array jobs, and resource requests
* Telling real variants from errors in difficult regions of the genome
* Interpreting a candidate variant without overstating its significance

### Computing requirements

* Access to a Unix-like shell environment on an HPC cluster
* Ability to run command-line tools and submit SLURM jobs
* A graphical session for viewing alignments in IGV
* Internet browser for reports and documentation
