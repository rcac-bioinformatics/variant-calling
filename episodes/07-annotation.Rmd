---
source: Rmd
title: '7\. Annotating variants'
teaching: 30
exercises: 30
---

:::::::::::::::::::::::::::::::::::::: questions

- What does a variant do to a gene or protein?
- How common is a variant in the population?
- What are the limits of annotation?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Annotate consequences with SnpEff using a database that matches the reference build.
- Add gnomAD allele frequencies, including the ancestry-matched group.
- Read ANN fields (allele, effect, impact, gene, transcript, HGVS).
- Filter and tabulate by impact and frequency.
- Explain annotation caveats.

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

After Episode 6 we have calls we trust, with labels for the ones we do not. A call says *where* the genome differs from the reference and *which* genotype each person has. It does not say what the difference might do, or whether it is common. Annotation adds both:

- a **predicted consequence** for each variant: which gene and transcript it falls in, and what it would change in the transcript or the protein;
- a **population allele frequency**: how often the same allele is seen in a large reference population.

Both are predictions and summaries made by other people's tools and data. They help us sort variants, and Episode 8 uses them to narrow a list of candidates. They are not measurements of what a variant does in a person.

::::::::::::::::::::::::::::::::::::::: prereq

## Before you start

You need `results/vcf/trio.filtered.vcf.gz` and its index from Episode 6, and the script `scripts/annotate.sh`. If you do not have the filtered calls, use the "Short on time?" copy in Episode 6, Step 3.

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: instructor

Live path (40 minutes; plan section 4, with SnpEff running in the background):

| Minutes | Section | Live or self-paced |
|---|---|---|
| 3 | Step 1: submit `annotate.sh` | live |
| 7 | While it runs: what the script does; why the database must match the reference | live |
| 8 | What SnpEff predicts: consequences, impact classes, the ANN field, transcripts | live |
| 10 | Step 2: the tables session, the flood of MODIFIER annotations, HIGH and MODERATE counts | live |
| 7 | Step 3: frequencies and ancestry; challenge "One missense variant, two frequencies" | live |
| 5 | ClinVar and the limits of annotation; key points | live |

Self-paced: the challenges "How many HIGH-impact variants?" and "Predict, then check: ANN entries", the callout on staged databases, and the common problems table. If `annotate.sh` has not finished when Step 2 starts, use the "Short on time?" copy.

:::::::::::::::::::::::::::::::::::::::::::::::::

## Step 1: Submit the annotation job

Annotation of the whole trio file takes a few minutes, so we submit it first and talk about what it does while it runs. This is `scripts/annotate.sh`:

<!-- kit: script annotate.sh -->
```bash
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --account=rcac
#SBATCH --qos=standby
#SBATCH --partition=cpu
#SBATCH --time=01:00:00
#SBATCH --job-name=annotate
#SBATCH --output=cluster-%x.%j.out
#SBATCH --error=cluster-%x.%j.err

module load biocontainers
module load snpeff/5.3.0a
module load bcftools/1.24

WORK=$SCRATCH/varcall-workshop
OUTDIR=$WORK/results/annot
GNOMAD=$WORK/resources/gnomad/gnomad.genomes.v4.1.chr20.af.vcf.gz
mkdir -p $OUTDIR

# 1. Predicted consequences with SnpEff (MANE transcripts, Ensembl IDs). The database is
#    already downloaded in ref/snpeff_data; -nodownload stops SnpEff from fetching it.
#    4 cores bring about 7.6 GB of memory, so the Java heap gets 6 GB.
snpEff -Xmx6g ann -nodownload \
    -dataDir $WORK/ref/snpeff_data \
    -stats $OUTDIR/snpEff_summary.html \
    -csvStats $OUTDIR/snpEff_summary.csv \
    GRCh38.mane.1.2.ensembl \
    $WORK/results/vcf/trio.filtered.vcf.gz \
  | bcftools view -Oz -W -o $OUTDIR/trio.snpeff.vcf.gz

# 2. Population allele frequencies from gnomAD v4.1 genomes, renamed so they do not clash
#    with the AC, AN and AF of our own three samples
bcftools annotate -a $GNOMAD \
    -c INFO/gnomad_AF:=INFO/AF,INFO/gnomad_AC:=INFO/AC,INFO/gnomad_AN:=INFO/AN,INFO/gnomad_nhomalt:=INFO/nhomalt,INFO/gnomad_AF_asj:=INFO/AF_asj,INFO/gnomad_AC_asj:=INFO/AC_asj,INFO/gnomad_AN_asj:=INFO/AN_asj \
    -Oz -W -o $OUTDIR/trio.ann.vcf.gz \
    $OUTDIR/trio.snpeff.vcf.gz
```

Submit it:

<!-- kit: submit annotate.sh -->
```bash
cd $SCRATCH/varcall-workshop/scripts
sbatch annotate.sh
```

In the workshop's test run the job ran for 102 seconds once it started (the reference runs took 86 to 98 seconds), plus the time waiting in the queue. Check on it with `squeue -u $USER`.

### What the script does

**SnpEff** ([Cingolani et al. 2012](https://doi.org/10.4161/fly.19695); [SnpEff manual](https://pcingola.github.io/SnpEff/)) compares each variant with a database of gene models (exons, introns, coding sequence, untranslated regions) and writes its predictions into a new INFO field, `ANN`. The parts of the command:

- **`ann`** annotates a VCF; **`GRCh38.mane.1.2.ensembl`** names the database: gene models for the GRCh38 reference, restricted to MANE transcripts (below), with Ensembl identifiers.
- **`-dataDir $WORK/ref/snpeff_data`** points SnpEff to the copy of that database prepared for the workshop (a link into the shared reference folder, like the FASTA), and **`-nodownload`** tells SnpEff not to download a database it cannot find. With both, every learner and every run uses the same database files, and a wrong path is an error instead of a silent download of whatever version the server holds that day.
- **`-Xmx6g`** sets the maximum Java heap. SnpEff runs in Java, and Java never uses more heap than `-Xmx` allows. A job on Negishi gets memory with its cores, about 1.96 GiB per core on the cpu nodes (recorded by the workshop's run kit), so 4 cores give about 7.9 GiB: room for a 6 GB heap plus Java's own overhead.
- **`-stats`** and **`-csvStats`** write a summary report (HTML for a browser, CSV for the command line).
- The output goes through a pipe to **`bcftools view -Oz -W`**, which compresses and indexes it.

**`bcftools annotate -a`** then copies fields from a second VCF, the gnomAD subset, into our records where position, REF and ALT match. `-c NEW:=OLD` copies the gnomAD field `OLD` under the new name `NEW`: gnomAD's `AF` becomes `gnomad_AF`. The renaming matters because our VCF already has `AC`, `AN` and `AF` fields, computed by `bcftools call` from our three samples; copying gnomAD's `AF` under the same name would overwrite ours, and nobody reading the file could tell which was which.

### The database must match the reference

SnpEff places a variant by its chromosome name and position. Those only mean something together with the reference they were measured on (Episode 2): position 44,337,201 on chromosome 20 of GRCh38 and position 44,337,201 of GRCh37 point to different places in the genome. A database built for another assembly would put variants into the wrong genes, or report positions that do not exist. The same goes for gnomAD: the staged subset (`resources/gnomad/gnomad.genomes.v4.1.chr20.af.vcf.gz`) comes from gnomAD v4.1 genomes on GRCh38 ([gnomAD v4.1](https://gnomad.broadinstitute.org/news/2024-04-gnomad-v4-1/)), and `bcftools annotate` matches by chromosome name, position and alleles, so a `20` against `chr20` mismatch would add nothing at all, silently.

::::::::::::::::::::::::::::::::::::::: callout

## Why is the database staged?

On Negishi the compute nodes can reach the SnpEff download server: the workshop's preparation runs downloaded databases from them. We stage the database anyway so that every learner annotates with the same files, a run next month gives the same result, and twenty learners do not each download the same database during the workshop. On your own cluster, check whether compute nodes have internet access before you rely on a download inside a job.

:::::::::::::::::::::::::::::::::::::::

## What SnpEff predicts

### Consequences and impact classes

Each prediction names a **consequence** (SnpEff calls it the annotation or effect) with a term from the **Sequence Ontology** ([Sequence Ontology](https://github.com/The-Sequence-Ontology/SO-Ontologies)), a shared vocabulary that tools use for the same idea: `missense_variant` (one amino acid changes to another), `synonymous_variant` (the codon changes, the amino acid does not), `stop_gained`, `frameshift_variant`, `splice_region_variant`, `intron_variant`, `upstream_gene_variant`, `intergenic_region` and so on.

SnpEff groups the consequences into four **impact classes**. In the words of the [SnpEff manual](https://pcingola.github.io/SnpEff/snpeff/inputoutput/):

| Impact | SnpEff's description | Examples |
|---|---|---|
| `HIGH` | "high (disruptive) impact in the protein, probably causing protein truncation, loss of function" | `stop_gained`, `frameshift_variant`, splice acceptor or donor |
| `MODERATE` | "A non-disruptive variant that might change protein effectiveness" | `missense_variant`, in-frame insertion or deletion |
| `LOW` | "Assumed to be mostly harmless or unlikely to change protein behavior" | `synonymous_variant` |
| `MODIFIER` | "Usually non-coding variants or variants affecting non-coding genes, where predictions are difficult" | `intron_variant`, `upstream_gene_variant`, `intergenic_region` |

The manual adds that "Impact categories must be used with care, they were created only to help and simplify the filtering process."

### The ANN field

`ANN` holds one or more predictions, separated by commas. Each prediction has 16 sub-fields separated by `|`; the header of the annotated file names them. The ones we use ([SnpEff manual](https://pcingola.github.io/SnpEff/snpeff/inputoutput/); [ANN format specification](https://pcingola.github.io/SnpEff/adds/VCFannotationformat_v1.0.pdf)):

| Position | Name in the header | Meaning |
|---|---|---|
| 1 | `Allele` | the ALT allele this prediction is for |
| 2 | `Annotation` | the consequence (Sequence Ontology term) |
| 3 | `Annotation_Impact` | `HIGH`, `MODERATE`, `LOW` or `MODIFIER` |
| 4 | `Gene_Name` | the gene symbol |
| 7 | `Feature_ID` | the transcript |
| 10 | `HGVS.c` | the change in transcript (coding DNA) coordinates, for example `c.44T>G` |
| 11 | `HGVS.p` | the change in the protein, for example `p.Phe15Cys`; empty for variants outside coding sequence |

HGVS is the standard notation for describing sequence variants ([HGVS nomenclature](https://hgvs-nomenclature.org/)). `c.` coordinates count along the coding sequence of one transcript, so the same genomic variant has a different `c.` name in each transcript it overlaps.

### One variant, several predictions

A variant can fall in several genes or transcripts at once: inside one gene and upstream of its neighbor, or in a region where two genes overlap. SnpEff writes one prediction for each, and the manual says a variant "can have (and usually has) more than one annotation". It sorts them with the highest impact first.

The number of transcripts per gene makes this much worse: many genes have dozens of annotated transcripts, and a variant in such a gene gets one prediction for each. **MANE** (Matched Annotation from NCBI and EMBL-EBI) chose one representative transcript per protein-coding gene, identical in the RefSeq and Ensembl annotations ([Morales et al. 2022](https://doi.org/10.1038/s41586-022-04558-8); [MANE at NCBI](https://www.ncbi.nlm.nih.gov/refseq/MANE/)). Annotating against MANE transcripts only gives fewer, more readable predictions. It does not give exactly one per variant: neighboring and overlapping genes still each get their own, and a few genes have a second MANE transcript. It also hides consequences in the transcripts left out, which may matter in a tissue that uses another one.

### A prediction is not a demonstrated effect

SnpEff predicts consequences from the gene model and the genetic code alone. It does not know whether the transcript is expressed in a given tissue, whether the changed amino acid matters for the protein, or whether a predicted loss of function escapes some other way. The manual says so itself: "Proper wet-lab validation is required to infer 'real' LOF". A `HIGH` label means "this would truncate the protein if the gene model is right and the transcript is used", not "this protein is broken".

## Step 2: Tables by impact and frequency

When `squeue -u $USER` no longer lists `annotate`, start an interactive session and look at the new header lines:

<!-- kit: interactive 07-annotation-tables.sh -->
```bash
sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00
module load biocontainers
module load bcftools/1.24
cd $SCRATCH/varcall-workshop
ANN=results/annot/trio.ann.vcf.gz
bcftools view -h $ANN | grep -E '^##INFO=<ID=(ANN|gnomad_)' | cut -c1-120
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
##INFO=<ID=ANN,Number=.,Type=String,Description="Functional annotations: 'Allele | Annotation | Annotation_Impact | Gene
##INFO=<ID=gnomad_AF,Number=A,Type=Float,Description="Alternate allele frequency">
##INFO=<ID=gnomad_AC,Number=A,Type=Integer,Description="Alternate allele count">
##INFO=<ID=gnomad_AN,Number=1,Type=Integer,Description="Total number of alleles">
##INFO=<ID=gnomad_nhomalt,Number=A,Type=Integer,Description="Count of homozygous individuals">
##INFO=<ID=gnomad_AF_asj,Number=A,Type=Float,Description="Alternate allele frequency in samples in the Ashkenazi Jewish
##INFO=<ID=gnomad_AC_asj,Number=A,Type=Integer,Description="Alternate allele count for samples in the Ashkenazi Jewish g
##INFO=<ID=gnomad_AN_asj,Number=1,Type=Integer,Description="Total number of alleles in samples in the Ashkenazi Jewish g
```

:::::::::::::::::::::::::::::::::::::

The outputs in this episode leave out the `[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float` lines that bcftools prints before them; the Episode 5A callout "MQ should be declared as Type=Float" explains them. `cut -c1-120` keeps each line to 120 characters; the `ANN` line goes on to list all 16 sub-fields. The `gnomad_` lines are the fields `annotate.sh` copied, with the descriptions gnomAD wrote for them.

SnpEff's summary file records what it processed:

<!-- kit: extra 07-annotation-tables.sh -->
```bash
grep -E '^(Genome|Number_of_variants_processed|Number_of_effects|Warnings|Errors) ' results/annot/snpEff_summary.csv
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
Genome , GRCh38.mane.1.2.ensembl
Warnings , 6682
Number_of_variants_processed , 185914
Number_of_effects , 198497
```

:::::::::::::::::::::::::::::::::::::

All 185,914 records of the filtered file were processed, filtered or not; annotation does not look at FILTER. `snpEff_summary.html` holds the same summary with plots; copy it to your computer to open it in a browser.

### HG002's variants

The trio file has a record wherever any of the three people has a variant. For one person's variants, keep that person's column and the sites where they carry an ALT allele (as in Episode 6), and keep only records that PASS:

<!-- kit: interactive 07-annotation-tables.sh -->
```bash
# HG002's variants: PASS sites where the child carries an ALT allele
bcftools view -f PASS -s HG002 -c 1 -Oz -W -o results/annot/HG002.ann.vcf.gz $ANN
bcftools view -H results/annot/HG002.ann.vcf.gz | wc -l
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
115059
```

HG002 has 115,059 PASS variants on chromosome 20.

:::::::::::::::::::::::::::::::::::::

### The flood of MODIFIER annotations

Count the most severe prediction of each of HG002's variants. `bcftools +split-vep` reads the `ANN` field ([split-vep documentation](https://samtools.github.io/bcftools/howtos/plugin.split-vep.html)): `-a ANN` names the field, `-s worst` keeps only the most severe prediction per variant, and `-f` prints sub-fields by the names in the header:

<!-- kit: extra 07-annotation-tables.sh -->
```bash
bcftools +split-vep -a ANN -s worst -f '%Annotation_Impact\n' results/annot/HG002.ann.vcf.gz | sort | uniq -c
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
      3 HIGH
    387 LOW
    237 MODERATE
 114432 MODIFIER
```

:::::::::::::::::::::::::::::::::::::

Almost every variant's most severe prediction is `MODIFIER`: intronic, intergenic, upstream or downstream of a gene. Coding sequence is a small part of chromosome 20, and most variation in any genome lies outside it. Across the whole trio file, SnpEff wrote 198,497 predictions: 10 `HIGH`, 348 `MODERATE`, 542 `LOW` and 197,597 `MODIFIER` (`snpEff_summary.csv`; these count predictions, not variants). A table of every prediction is therefore almost all `MODIFIER`. To find the variants that might change a protein, select on impact first and look at the rest only when you have a reason to.

Before filtering, see how many predictions each variant carries:

<!-- kit: extra 07-annotation-tables.sh -->
```bash
bcftools query -f '%INFO/ANN\n' results/annot/HG002.ann.vcf.gz | awk -F, '{ print NF }' | sort -n | uniq -c
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
 107532 1
   6800 2
    691 3
     32 4
      4 5
```

The first column is the number of variants, the second the number of predictions each carries (comma-separated entries in `ANN`). Even with one MANE transcript per gene, many variants carry more than one.

:::::::::::::::::::::::::::::::::::::

### HIGH and MODERATE predictions

Count the variants with at least one `HIGH` and at least one `MODERATE` prediction. The pattern `[|]HIGH[|]` matches `HIGH` between two `|` characters, so it matches the impact sub-field and not, for example, a gene name that contains the letters HIGH:

<!-- kit: interactive 07-annotation-tables.sh -->
```bash
# How many carry at least one HIGH or MODERATE prediction
bcftools view -H -i 'INFO/ANN~"[|]HIGH[|]"' results/annot/HG002.ann.vcf.gz | wc -l
bcftools view -H -i 'INFO/ANN~"[|]MODERATE[|]"' results/annot/HG002.ann.vcf.gz | wc -l
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
3
237
```

:::::::::::::::::::::::::::::::::::::

The two counts can overlap: a variant with a `HIGH` prediction in one gene and a `MODERATE` one in another is counted in both. Now write one row per variant, with its most severe prediction and the gnomAD frequencies, for the variants whose most severe prediction is `HIGH` or `MODERATE`:

<!-- kit: interactive 07-annotation-tables.sh -->
```bash
# One row per variant: the most severe consequence, with gnomAD frequencies
bcftools +split-vep -a ANN -s worst \
    -f '%CHROM\t%POS\t%REF\t%ALT\t%Gene_Name\t%Annotation\t%Annotation_Impact\t%HGVS.p\t%INFO/gnomad_AF\t%INFO/gnomad_AF_asj\n' \
    -i 'Annotation_Impact="HIGH" || Annotation_Impact="MODERATE"' \
    results/annot/HG002.ann.vcf.gz > results/annot/HG002.protein_altering.tsv
wc -l results/annot/HG002.protein_altering.tsv
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
240 results/annot/HG002.protein_altering.tsv
```

240 of HG002's variants have a `HIGH` or `MODERATE` most severe prediction (3 `HIGH`, 237 `MODERATE`): about 0.2% of its 115,059 variants.

:::::::::::::::::::::::::::::::::::::

`-i` with `Annotation_Impact` filters on the sub-field after `-s worst` has chosen the prediction, so each variant appears at most once. The table has no header line; its columns are the fields of `-f`, in order. A `.` in the last two columns means gnomAD has no record of that allele.

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: how many HIGH-impact variants?

1. How many of HG002's variants have a `HIGH` most severe prediction? Use the table you just wrote, or `-i` with `split-vep`.
2. Which consequence types are they? Count them without printing gene names:

<!-- kit: extra 07-annotation-tables.sh -->
```bash
bcftools +split-vep -a ANN -s worst -f '%Annotation_Impact\t%Annotation\n' -i 'Annotation_Impact="HIGH"' results/annot/HG002.ann.vcf.gz | sort | uniq -c
```

3. Is a `HIGH`-impact variant in a healthy person surprising?

::::::::::::::::::::::::::::::::::: solution

```output
      1 HIGH	frameshift_variant
      2 HIGH	splice_acceptor_variant&intron_variant
```

1. Three (count the lines above, or `awk -F'\t' '$7 == "HIGH"' results/annot/HG002.protein_altering.tsv | wc -l`).
2. The consequence types and their counts are in the output above.
3. No. Healthy people carry about 100 predicted loss-of-function variants each across the whole genome, about 20 of them with both copies affected ([MacArthur et al. 2012](https://doi.org/10.1126/science.1215040)). A few on one chromosome are expected. Episode 8 returns to this.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

## Step 3: Population frequencies and ancestry

**gnomAD**, the Genome Aggregation Database, collects sequencing data of hundreds of thousands of people and publishes how often each allele is seen ([Karczewski et al. 2020](https://doi.org/10.1038/s41586-020-2308-7); [gnomAD v4.1](https://gnomad.broadinstitute.org/news/2024-04-gnomad-v4-1/)). `gnomad_AF` is the allele frequency over all gnomAD v4.1 genomes. gnomAD also reports frequencies within **genetic ancestry groups**, which it assigns from the genetic data by comparing each sample with samples of known ancestry; one of them is Ashkenazi Jewish, `asj` ([gnomAD help: genetic ancestry](https://gnomad.broadinstitute.org/help/ancestry)). `annotate.sh` copied that group's frequency as `gnomad_AF_asj`.

Why does the group matter here? HG002, HG003 and HG004 are an Ashkenazi Jewish family (the GIAB Ashkenazi trio). The Ashkenazi Jewish population went through a recent bottleneck of about 350 individuals ([Carmi et al. 2014](https://doi.org/10.1038/ncomms5835)). Variants carried by those founders can be common among their descendants and rare everywhere else. Against the global frequency, such a **founder variant** looks rare, and a rare-variant filter would keep it as interesting. Carmi et al. found that an Ashkenazi reference panel was eightfold more effective than a European one at filtering benign variants out of Ashkenazi clinical genomes.

Count HG002's protein-altering variants that look rare (below 1%, or absent from gnomAD), first with the global frequency (column 9), then with the Ashkenazi group (column 10):

<!-- kit: interactive 07-annotation-tables.sh -->
```bash
# Rare: below 1% in gnomAD overall, or absent from gnomAD; then the same with the Ashkenazi group
awk -F'\t' '$9 == "." || $9 < 0.01' results/annot/HG002.protein_altering.tsv | wc -l
awk -F'\t' '$10 == "." || $10 < 0.01' results/annot/HG002.protein_altering.tsv | wc -l
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
20
12
```

20 variants are rare by the global frequency, 12 by the Ashkenazi frequency. 8 variants that look rare in gnomAD as a whole are seen at 1% or more in the Ashkenazi group.

:::::::::::::::::::::::::::::::::::::

The ancestry-matched frequency removed 8 of 20 apparently rare candidates. In Episode 8 the frequency filter requires both: below 1% globally *and* in the Ashkenazi group.

### Using ancestry labels with care

Ancestry groups in a database are statistical clusters built for one purpose, frequency estimates, from the samples that database happens to hold. They are not fixed biological categories, and a person's self-description, the database's group and their genetic ancestry need not agree. The US National Academies recommend describing such groups by how they were defined, and using them only where they help answer the question ([NASEM 2023](https://doi.org/10.17226/26902)). Here the question is "is this allele common among people whose genomes resemble HG002's?", and the `asj` group is the best match gnomAD offers. For a person of mixed or unlisted ancestry, the honest answer may be that no group fits, and one conservative choice is the highest frequency in any group.

### One missense variant

HG002 carries a missense variant at chr20:44,337,201 (T>G), in the gene *R3HDML*. Look at its row, its genotype, and every prediction SnpEff made for it:

<!-- kit: extra 07-annotation-tables.sh -->
```bash
awk -F'\t' '$2 == 44337201' results/annot/HG002.protein_altering.tsv
bcftools query -r chr20:44337201 -f '[%SAMPLE\t%GT\t%AD]\n' results/annot/HG002.ann.vcf.gz
bcftools query -r chr20:44337201 -f '%INFO/ANN\n' results/annot/HG002.ann.vcf.gz | tr ',' '\n'
```

::::::::::::::::::::::::::::::::::::: spoiler

## What does the output look like?

```output
chr20	44337201	T	G	R3HDML	missense_variant	MODERATE	p.Phe15Cys	0.100238	0.196542
HG002	0/1	23,14
G|missense_variant|MODERATE|R3HDML|ENSG00000101074.5|transcript|ENST00000217043.4|protein_coding|1/5|c.44T>G|p.Phe15Cys|159/1323|44/762|15/253||
```

:::::::::::::::::::::::::::::::::::::

`tr ',' '\n'` puts each prediction on its own line.

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: one missense variant, two frequencies

Use the row above.

1. What does SnpEff predict for this variant, in which impact class? What does `HGVS.p` say?
2. How common is the ALT allele in gnomAD overall, and in the Ashkenazi group? Roughly how many people in a hundred carry it, in each?
3. Would the rare-variant filter of Episode 8 keep it? Would it keep it if it used the global frequency only?
4. What can you conclude about this variant from the annotation, and what not?

::::::::::::::::::::::::::::::::::: solution

1. A `missense_variant`, impact `MODERATE`: one amino acid is predicted to change to another (`HGVS.p` names both and the position). HG002's genotype is in the second line of the output: `0/1`, with `AD` 23,14 (REF and ALT reads).
2. Overall allele frequency 0.100238 (10.0%); in the Ashkenazi group 0.196542 (19.7%). An allele frequency counts chromosomes, not people: with frequency *p*, the share of people with at least one copy is 1 - (1 - *p*)^2, about 2*p* when *p* is small.
3. No in both cases: the allele is far above 1% globally and in the Ashkenazi group. This variant shows the opposite case to a founder variant: it is common everywhere, more common in the Ashkenazi group.
4. A common missense variant is, by its frequency alone, unlikely to cause a rare, severe condition: too many healthy people carry it. The annotation predicts a change in the protein; it says nothing about whether the change matters. In ClinVar (next section) this variant had no record when the workshop checked (2026-10-14).

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::: challenge

## Challenge: predict, then check: ANN entries

Before you look at the third command's output above: how many entries will `ANN` hold for the missense variant, given one MANE transcript per gene? In which order will they come, and which sub-fields will be empty in an entry for a neighboring gene?

::::::::::::::::::::::::::::::::::: solution

Count the lines of the third command's output: each line is one prediction. SnpEff lists the highest impact first, so the `missense_variant` entry comes first. Any further entries belong to other genes or transcripts near the variant (for example `upstream_gene_variant` or `downstream_gene_variant`, impact `MODIFIER`); for those, `HGVS.p` is empty, because the variant is not in that gene's coding sequence, and the last sub-fields give the distance to the gene. One transcript per gene reduces the number of entries; it does not reduce it to one.

:::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::

Type `exit` to leave the interactive session.

::::::::::::::::::::::::::::::::::::::: callout

## Short on time?

If `annotate.sh` did not finish, copy the annotated trio file and its index from the results copy, then run Step 2:

<!-- kit: not-run fallback -->
```bash
cp /depot/workshop/data/varcall-workshop_results/results/annot/trio.ann.vcf.gz* $SCRATCH/varcall-workshop/results/annot/
```

:::::::::::::::::::::::::::::::::::::::

## ClinVar and its limits

::::::::::::::::::::::::::::::::::::::: callout

## What ClinVar is for

**ClinVar** is a public archive at NCBI where clinical laboratories, researchers and expert panels submit their interpretations of variants, for example "pathogenic", "benign" or "uncertain significance", for a stated condition ([ClinVar](https://www.ncbi.nlm.nih.gov/clinvar/); [Landrum et al. 2018](https://doi.org/10.1093/nar/gkx1153)). It is useful for finding out whether anyone has seen a variant before and what they concluded.

Its limits:

- ClinVar holds **submitted interpretations**, not proof. Submitters can disagree, and ClinVar shows conflicts instead of resolving them. The **review status** (stars) says how much review stands behind a record ([ClinVar review status](https://www.ncbi.nlm.nih.gov/clinvar/docs/review_status/)).
- Most variants have no record at all. Absence means nobody has submitted one, not that the variant is harmless.
- Interpretations change as evidence accumulates; record the date you checked.
- An interpretation is made for a condition and a context. It is not a statement about a particular person.

The workshop does not annotate with ClinVar, and does not interpret any variant of HG002 for health. The one variant we looked up, chr20:44,337,201 T>G, had no ClinVar record on 2026-10-14.

:::::::::::::::::::::::::::::::::::::::

## Common problems

| Symptom | Likely cause | Fix |
|---|---|---|
| SnpEff stops: database not found | wrong `-dataDir`, or a database name that is not in it | check the path and the name; with `-nodownload` SnpEff never fetches a missing database |
| every variant is `intergenic_region`, or errors about missing chromosomes | database for another build, or chromosome names that do not match | use a database for the reference you aligned to; check `chr20` against `20` |
| `java.lang.OutOfMemoryError` in the job's error file | Java heap (`-Xmx`) too small for the database, or larger than the job's memory | raise `-Xmx` and request more cores (about 1.96 GiB each on Negishi), keeping `-Xmx` below what the cores provide |
| `gnomad_AF` is `.` everywhere | contig names or build differ between the VCF and the gnomAD file | annotate with a gnomAD file on the same build and contig names |
| our own `AF` changed after annotation | gnomAD fields copied without renaming | rename with `-c INFO/gnomad_AF:=INFO/AF` |
| a table of thousands of `MODIFIER` rows | every prediction printed | filter on impact (`-i`), and use `-s worst` for one row per variant |
| one variant appears on several rows | several predictions per variant | `-s worst`, or count unique positions |
| "rare" variants that are common in the person's population | global frequency only | use an ancestry-matched group as well (`gnomad_AF_asj` here) |

In the workshop's test run, `annotate.sh` used at most 2.60 GiB of the 7.9 GiB that 4 cores provide (SLURM's MaxRSS).

## Summary

::::::::::::::::::::::::::::::::::::: keypoints

- SnpEff predicts each variant's consequence from gene models: a Sequence Ontology term, an impact class, the gene, the transcript and HGVS names, in the `ANN` field.
- The database must match the reference build and its chromosome names; stage it and use `-nodownload` so every run uses the same files.
- One variant can have several predictions; MANE transcripts reduce, but do not remove, them. `split-vep -s worst` gives one row per variant.
- Almost all predictions are `MODIFIER`: filter on impact before you read.
- gnomAD frequencies need the ancestry-matched group as well as the global one: founder variants can look rare globally.
- A predicted effect, a frequency and a ClinVar record are evidence of different kinds; none of them shows what a variant does in a person.

::::::::::::::::::::::::::::::::::::::::::::::::
