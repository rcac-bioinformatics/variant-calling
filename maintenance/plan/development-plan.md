# Variant calling workshop: development plan

Version 0.1, 2026-10-09. Prepared with Claude for Arun Seetharam. Save as `maintenance/plan/development-plan.md` in the lesson repository.

**Basis of this assessment**

- Uploaded template `variant-calling.zip`: one commit, 822e8c5 "Initial commit [via {sandpaper}]" (2026-10-09 07:26 CDT), plus uncommitted edits to `config.yaml` and `variant-calling.Rproj`.
- Public clones read on 2026-10-09: `rcac-bioinformatics/rnaseq-analysis` at 2d0b5f8 (2026-10-05), `rcac-bioinformatics/singlecell-rnaseq` at 89eea2a (2026-05-19), `rcac-bioinformatics/genome-assembly` at 20e694a (2026-02-18), and the module inventory in `PurdueRCAC/Biocontainers` at a0e6be9 (2026-10-01).
- Not available to me: anything on Negishi, and the gitignored material in your RNA-seq checkout (`maintenance/prompts/`, `instructor-notes/`, `coaching/`). Nothing in this plan was executed on the cluster.

**Evidence labels:** [O] observed in files or official pages; [I] inferred; [A] assumption; [U] unverified, check before relying on it.

## Decisions needed

| ID | Decision | Recommendation | Why it matters |
|---|---|---|---|
| D1 | Teaching dataset | GIAB Ashkenazi trio (HG002 child, HG003 father, HG004 mother), Illumina NovaSeq PCR-free ~35x, reads from chr20, GRCh38 no-alt analysis set | The only practical option with public truth sets for every sample and a pedigree. Filtering becomes measurable, and a trio supports a realistic downstream task. Alternative in 5.1. |
| D2 | Live primary caller | bcftools mpileup/call; GATK HaplotypeCaller as self-paced Episode 5B | One toolchain (samtools, bcftools) from BAM to trio analysis, any organism, fast. |
| D3 | Annotation | SnpEff/SnpSift with a GRCh38 database, plus gnomAD frequencies via `bcftools annotate` | SnpEff transfers to non-model organisms. VEP on Negishi is release 108. |
| D4 | Live downstream application | Episode 8, candidate variants in a trio. Population variation (Episode 9) self-paced | Uses the day's own calls and teaches the most about false positives and interpretation. |
| D5 | Tool versions | Load explicit versions of samtools and bcftools. Deploy bcftools 1.24 plus htslib as biocontainers, or accept 1.17 | bcftools behavior changed in 1.13, 1.17, 1.18, 1.20 and 1.24 (section 5.3). |
| D6 | What "six hours" means | 6.0 h of instruction excluding breaks and lunch, day 9:00-4:30. A 5.5 h cut list is provided | Your 10/06 RNA-seq day (9:00-4:00) gave about 5.5 h. |
| D7 | Conventions where your workshops differ | Follow RNA-seq: numbered files and titles, display fences, run kit, `.claude/CLAUDE.md`, maintenance log. Add public instructor notes in the scRNA-seq style | RNA-seq is the most recently revised workshop (Oct 2026) and the only one with executable validation. |
| D8 | Logistics | Repo `rcac-bioinformatics/variant-calling`; SLURM account TBD; Depot `/depot/workshop/data/varcall-workshop` (+ `_results`); working directory `$SCRATCH/varcall-workshop`, with `$SCRATCH` as the only scratch variable; date and co-instructor TBD | These appear in every SLURM header and on the setup page. Names are proposals. |

## 1. Repository assessment

### 1.1 What the template contains [O]

- A stock `sandpaper::create_lesson()` skeleton. Workflows are pinned to sandpaper 0.17.1, the same as RNA-seq and scRNA-seq.
- One episode, `episodes/introduction.Rmd`, which is the Workbench demo (pie-chart pyramid, Carpentries badge, math example). There is no variant-calling content, data, scripts or figures.
- Placeholders: `index.md`, `learners/setup.md` (FIXME), `learners/reference.md`, `instructors/instructor-notes.md`, `profiles/learner-profiles.md` (title FIXME), `CITATION.cff` (FIXME), a one-line `README.md`, and the template `links.md`.
- Uncommitted `config.yaml` edits: `carpentry: 'rcac'`, `varnish: aseetharam/varnish`, title "Variant Calling: Hands-on Training", `life_cycle: 'stable'`, `source: 'https://rcac-bioinformatics.github.io/variant-calling'`, `contact: 'rcac-help@purdue.edu'`, `disable_sidebar_numbering: false`. Keywords are still the template default.
- No git remote is configured. The zip also contains locally built output under `site/` and an `.Rproj.user/` folder. Both are gitignored, except the tracked `site/README.md`.

### 1.2 Conventions in your existing workshops

Shared by all three workshops [O]:

| Area | Convention |
|---|---|
| Platform | Workbench with `carpentry: 'rcac'`, `varnish: aseetharam/varnish`, CC-BY 4.0. sandpaper 0.17.1 in RNA-seq and scRNA-seq; 0.16.11 in genome assembly |
| Episodes | `.Rmd` with `title`, `teaching` and `exercises` front matter; questions, objectives, keypoints; challenges with nested solutions |
| Code | Never executed at build time: display fences (RNA-seq, genome assembly) or `eval=FALSE` chunks (scRNA-seq) |
| HPC and data | Negishi with `module load biocontainers`; data staged under `/depot/workshop/data/` and copied to scratch with rsync |
| Delivery | One full day in person |

RNA-seq conventions to adopt (some are partly present in scRNA-seq) [O]:

| Area | Convention |
|---|---|
| Front matter | `source: Rmd` (also scRNA-seq) |
| Blocks | Callouts titled "Why X?"; discussion blocks; spoilers showing expected output; solutions that interpret this dataset's actual numbers |
| Jobs | Scripts saved in `scripts/` and submitted from there; array jobs over `samples.txt`; runtime stated after each job; "Short on time?" callouts that fall back to a completed-results copy (`<name>_results`) |
| Setup page | Instructors, dated schedule, prerequisites, scope, toolchain table, what is not covered, SSH tabs, data setup and verification, OOD steps |
| Delivery | The full lesson is longer than the day: selected episodes are taught live, the rest are self-paced, and all are tested |
| Validation | `negishi-run/` kit, anchors, maintenance log, `.claude/CLAUDE.md` |

Where the workshops differ (recommendation in the last column):

| Item | RNA-seq (Oct 2026) | scRNA-seq, genome assembly | Template | Recommendation |
|---|---|---|---|---|
| File names | Numbered (`04a-...`) | Topical | Topical demo | Numbered, letter suffix for tracks |
| Titles and sidebar | "4A. ..." with `disable_sidebar_numbering: true` | Unnumbered, `false` | `false` | Numbered titles, `true` |
| Code blocks | Display fences, parsed by the run kit | scRNA-seq `{r ..., eval=FALSE}`; genome assembly display fences | n/a | Display fences (shell-heavy lesson) |
| Scratch variable | `$SCRATCH` in episodes, `$RCAC_SCRATCH` in setup (its log flags this as a `[check]`) | `$RCAC_SCRATCH` | n/a | `$SCRATCH` everywhere; setup verifies it |
| `source:` | GitHub repo URL (its log records the fix on 2026-10-05) | Pages URL | Pages URL | `https://github.com/rcac-bioinformatics/variant-calling` [U: confirm name] |
| SLURM header | `--account=rcac-rnaseq --qos=standby --partition=cpu`, `cluster-%x.%j.out`, never `--mem` | scRNA-seq `--account=workshop`, no QoS; genome assembly `--qos=normal` and mentions `--mem` | n/a | RNA-seq pattern, never `--mem` |
| Instructor notes | Public page is a placeholder; narration and coaching kept local and gitignored | scRNA-seq: public page with timing table, common issues, pre-workshop checklist, challenge discussion points. Genome assembly: placeholder | Placeholder | Both: scRNA-seq-style public notes plus RNA-seq-style local narration and coaching |
| Validation | `negishi-run/` kit, anchors, maintenance log, `.claude/CLAUDE.md` | None | None | Adopt from the start |
| Headings | Sentence case | scRNA-seq Title Case; genome assembly mixed | n/a | Sentence case |

### 1.3 Side findings in other repos (outside scope; relevant to the 10/29 scRNA-seq delivery)

- `singlecell-rnaseq/learners/setup.md`: the schedule is still dated 4/21/2026.
- `singlecell-rnaseq/instructors/instructor-notes.md`: tells instructors to request `--mem=40G` for the STAR index. This conflicts with the cores-only memory convention on Negishi.
- `singlecell-rnaseq` episodes use `--account=workshop`. Confirm that the account exists for 10/29.

## 2. Gap analysis

| Item | Current state | Action | Phase |
|---|---|---|---|
| Episodes | Demo only | Replace with 8 core and 3 self-paced episodes | P4-P8 |
| Dataset, staging, completed results | None | Data-prep scripts; Depot staging with manifest and checksums; completed-results copy | P2-P3 |
| Reference run and validation | None | Reference pipeline that produces anchors; run kit that executes episode code as a new learner would | P3-P5, P9 |
| `config.yaml` | `source` is the Pages URL; `life_cycle: stable` before any delivery; template keywords; `episodes` lists only the demo, and the `learners`, `instructors` and `profiles` lists are empty | Fix; use `pre-alpha` until the first delivery | P1 |
| Setup page | FIXME | Full page in the RNA-seq structure | P1 skeleton, P4 full |
| Instructor notes, learner profile, glossary | Placeholders | Write | P1 skeleton, P7 |
| `index.md`, `README.md`, `CITATION.cff` | Placeholders | Write | P1 |
| Figures and animations | None | Workflow diagram, reads-to-genotype animation, VCF anatomy, precision-recall, filtering funnel, IGV examples | P7 |
| Development infrastructure | None | `.claude/CLAUDE.md`, `maintenance/log/updates.md`, `.gitignore` entries | P1 |
| Remote | None | Create `rcac-bioinformatics/variant-calling` (you) | P1 |

Keep as they are: the stock workflows (do not hand-edit), license, code of conduct, CONTRIBUTING, `.Rproj`, and the theme settings.

## 3. Proposed curriculum

### 3.1 Audience and scope assumptions

- [A] The audience matches the RNA-seq learner profile: graduate students, postdocs, staff and faculty with basic shell skills, little SLURM experience and no variant-calling experience. They work on a mix of organisms (biomedical, animal, plant).
- [A] In person, about 20 learners and two instructors, on Negishi with a workshop SLURM account on standby.
- [A] Scope is germline SNVs and small indels (under 50 bp) from Illumina short-read WGS of diploid samples. Somatic calling, SV and CNV calling, long reads, RNA-seq-based calling, and pooled or polyploid samples are not taught live; Episode 10 points to them.
- [A] No R in the live core. R appears only in self-paced Episode 9, run in OOD RStudio as in your other workshops.

### 3.2 Workshop learning outcomes

After the workshop, learners can:

1. Explain how aligned reads become genotype calls and why calls can be wrong.
2. Produce analysis-ready BAMs and a normalized multi-sample VCF on an HPC cluster, using batch and array jobs.
3. Read and query VCF records, and filter calls with stated, justified thresholds.
4. Measure call quality against a benchmark, and choose proxy measures when no benchmark exists.
5. Annotate variants and use population frequencies appropriately.
6. Derive a candidate-variant list for a family and state what the evidence does and does not support.

### 3.3 Episode map

| Ep | Title | Mode | Live min | Full min (teaching + exercises) | Depends on |
|---|---|---|---|---|---|
| 1 | Introduction to genetic variation and variant calling | Core live | 30 | 50 (35 + 15) | none |
| 2 | Data, reference genomes, and project setup | Core live, condensed | 20 | 40 (20 + 20) | 1 |
| 3 | Read quality control | Core live, condensed | 15 | 30 (15 + 15) | 2 |
| 4 | Read alignment and alignment QC | Core live | 70 | 90 (45 + 45) | 2 (3 optional) |
| 5A | Calling variants with bcftools | Core live | 45 | 60 (30 + 30) | 4 |
| 5B | Calling variants with GATK HaplotypeCaller | Self-paced; can replace 5A live | n/a | 90 (45 + 45) | 4 |
| 6 | Filtering and evaluating variant calls | Core live | 60 | 80 (40 + 40) | 5A or 5B |
| 7 | Annotating variants | Core live, can be compressed | 40 | 60 (30 + 30) | 6 |
| 8 | Application: candidate variants in a family trio | Core live | 50 | 75 (35 + 40) | 6 (7 for annotation filters) |
| 9 | Application: variation across samples and populations | Self-paced; can replace 8 live | n/a | 75 (35 + 40) | 6 |
| 10 | Adapting the workflow: your organism, your data, at scale | Self-paced | n/a | 45 (30 + 15) | 1-8 |
| | Wrap-up and survey (not an episode) | Live | 30 | n/a | |

The live core plus wrap-up totals 360 minutes. The full curriculum's front matter totals 695 minutes (360 teaching + 335 exercises, about 11.6 h), comparable to RNA-seq's roughly 9.5 h. Following the RNA-seq convention, front matter `teaching` plus `exercises` equals the full time. Live timings belong in the instructor notes and on the setup page.

### 3.4 Episode specifications

**Episode 1. Introduction to genetic variation and variant calling** (live 30, full 50; no dependencies; core live)
- Objectives: distinguish SNVs, MNVs, indels and SVs/CNVs, and germline from somatic variants; read diploid genotypes (0/0, 0/1, 1/1, ./.); explain how a call is inferred from read evidence and base and mapping quality, and why errors arise; describe the workflow and its files; state the workshop question.
- Prerequisites: genes, alleles, basics of DNA sequencing.
- Concepts: the reference is a coordinate system, not "normal"; coverage and allele balance at heterozygous sites (binomial sampling); genotype likelihood and quality in plain terms; calling, filtering and interpretation as separate steps; what short reads cannot see.
- Hands-on: a pileup-cartoon challenge (call the genotype); a discussion of how many reads you need before you trust a heterozygous call; a "From reads to a genotype" animation.
- Outputs: none.
- Common errors: equating REF with healthy or ancestral; treating every call as real; confusing within-sample allele fraction with population allele frequency.

**Episode 2. Data, reference genomes, and project setup** (live 20, full 40; depends on 1)
- Objectives: verify the staged copy and lay out the project; describe the trio and record its metadata as a sample sheet and a PED file; explain the GRCh38 no-alt analysis set, contig naming and index files (`.fai`, `.dict`, aligner index); convert BED (0-based, half-open) to VCF-style (1-based) coordinates; check integrity with md5.
- Concepts: FASTA, FASTQ, BED and PED; assemblies and patches; alt contigs and decoys; `chr20` vs `20`; checksums and provenance; data responsibility (GIAB consent permits public release, but learners' own human data may be controlled and belong on approved systems).
- Hands-on: `samtools faidx` region extraction; inspecting `.fai`; `md5sum -c`; writing `samples.tsv` and `trio.ped`; a coordinate-conversion challenge; download-from-source commands shown in a not-run spoiler.
- Outputs: `$SCRATCH/varcall-workshop/{data,ref,scripts,results}`, `samples.tsv`, `trio.ped`. `ref/` holds symlinks to the read-only reference and indexes on Depot (section 5.4); setup confirms that `$SCRATCH` points to the learner's scratch.
- Common errors: build or contig-name mismatch; gzip instead of bgzip; scratch purge; heavy commands on login nodes.
- Must state: the reads were selected from chr20 alignments, so mapping rate and coverage outside chr20 are not realistic.

**Episode 3. Read quality control** (live 15, full 30; depends on 2)
- Objectives: run FastQC and MultiQC in an interactive job; interpret base quality, adapter content, duplication and GC; decide whether trimming is needed before local alignment.
- Concepts: Phred scores; binned NovaSeq qualities; bwa mem soft-clipping, which usually makes adapter trimming unnecessary; PCR vs optical duplicates; why base quality enters genotype likelihoods.
- Hands-on: FastQC and MultiQC; an interpretation challenge; fastp as a reference spoiler; contrast figures from problem datasets, keeping your teaching stance.
- Outputs: `results/qc/multiqc_report.html`.
- Common errors: reading binned-quality plots as failures; over-trimming; running on login nodes.

**Episode 4. Read alignment and alignment QC** (live 70, full 90; depends on 2)
- Objectives: explain why mapping quality matters for calling; align with `bwa mem` using correct read groups; produce sorted, duplicate-marked and indexed BAMs; read SAM fields (FLAG, CIGAR, MAPQ); interpret mapping, pairing, duplicate, insert-size and coverage metrics; view a locus.
- Concepts: seed-and-extend alignment; multi-mapping and MAPQ 0; soft clips; read groups (ID, SM, LB, PL), where SM becomes the VCF sample name; marking vs removing duplicates; BAM vs CRAM; base quality recalibration (concept only); coverage uniformity.
- Hands-on: use the prebuilt index (index building explained, optional tiny-FASTA demo); an `align.sh` array over samples (`bwa mem -R` piped into `samtools fixmate -m`, `samtools sort` and `samtools markdup`); `samtools flagstat` and `stats`, `mosdepth`, MultiQC; `samtools view` challenges (decode a FLAG, count MAPQ 0 reads); a locus in IGV or `samtools tview`.
- Outputs: `results/bam/<sample>.markdup.bam` and its index; `results/qc_alignment/multiqc_report.html`; mosdepth summaries.
- Common errors: real TAB characters in the `-R` string instead of the escaped `\t` that bwa expects, or a missing ID or SM; `samples.txt` resolved relative to the submit directory; sorting before `fixmate`; too few cores to hold the index in memory; a missing index; `samtools rmdup`.
- Fallback: BAMs from the completed-results copy.

**Episode 5A. Calling variants with bcftools** (live 45, full 60; depends on 4)
- Objectives: explain what `mpileup` summarizes and how `call` turns it into genotypes and QUAL; call the trio jointly by region with an array job; concatenate, normalize (left-align, split multiallelic sites) and index; read a VCF record (REF, ALT, QUAL, FILTER, INFO; GT, GQ, PL, AD, DP).
- Concepts: joint vs per-sample calling; the multiallelic caller and its priors; BAQ, minimum base and mapping quality, and the per-file depth cap (default 250); variant representation and normalization; VCF vs BCF, bgzip and indexes; the gVCF idea (bridge to 5B); ploidy.
- Hands-on: a region list; a `call.sh` array (`bcftools mpileup -a AD,DP,SP ... | bcftools call -mv`); `concat`, `norm -f` and `index`; `bcftools view -h` and `query` challenges (SNV vs indel counts per sample, reading AD at a heterozygous site).
- Outputs: `results/vcf/trio.norm.vcf.gz` and index; a `bcftools stats` file.
- Common errors: contig mismatch between FASTA and BAM; missing `-a AD`; forgetting `-v`; region syntax; the depth cap at high coverage; concatenating out of order; unindexed outputs; wrong SM tags.
- Fallback: the trio VCF from completed results.

**Episode 5B. Calling variants with GATK HaplotypeCaller** (self-paced, full 90; depends on 4; can replace 5A live for GATK-centric audiences)
- Objectives: run HaplotypeCaller in GVCF mode per sample; joint-genotype the trio; apply GATK hard filters; compare with 5A in Episode 6.
- Concepts: active regions and local reassembly; pair-HMM; GVCF reference blocks and why they scale to cohorts; BQSR and VQSR, and when they do not apply (small data, non-model organisms).
- Hands-on: a per-sample array; `GenomicsDBImport` or `CombineGVCFs`; `GenotypeGVCFs`; `VariantFiltration`.
- Outputs: `results/gatk/trio.gatk.filtered.vcf.gz`.
- Common errors: missing `.dict` or read groups; Java heap vs requested cores; interval names; VQSR on too few variants.

**Episode 6. Filtering and evaluating variant calls** (live 60, full 80; depends on 5A or 5B)
- Objectives: summarize a call set (counts, Ts/Tv, het/hom-alt ratio, indel lengths, depth and QUAL distributions); apply soft filters at the site and genotype levels; measure precision and recall against a GIAB benchmark in its confident regions; explain the precision-recall trade-off of a threshold and why indels and difficult regions do worse; choose proxy measures when no truth set exists.
- Concepts: TP, FP, FN; precision, recall, F1; confident regions; haplotype-aware comparison; stratifications (homopolymers, segmental duplications, low mappability); depth upper bounds (collapsed repeats); allele balance; proxies (Ts/Tv, Mendelian errors, replicate concordance, known sites). Ts/Tv is roughly 2.0-2.1 for human germline WGS SNVs and higher in coding regions [I, standard approximate values].
- Hands-on: `bcftools stats` and MultiQC; soft filters with `bcftools filter -s` and genotype-level filters; extract HG002 (`bcftools view -s HG002 -c 1`); `hap.py` with `--roc QUAL`, restricted to the workshop region (`-l chr20`, or chr20-only truth and BED in the staged copy), otherwise whole-genome truth collapses recall; the vcfeval engine, as in the DeepTrio case study, only if the 0.3.9 container supports it (P2 tests this); reading `summary.csv`; a predict-then-test challenge on one threshold; optional comparison with 5B, and with a precomputed DeepVariant call set if one is staged.
- Teaching rule: choose thresholds from call-set distributions first, then evaluate against the benchmark. Tuning thresholds on the benchmark is test-set leakage; say so.
- Outputs: `results/vcf/trio.filtered.vcf.gz`; `results/eval/HG002.summary.csv` and ROC tables.
- Common errors: confusing INFO/DP with FORMAT/DP; inverting `-i` and `-e`; deleting records instead of flagging them; evaluating without the confident-region BED; giving `hap.py` a multi-sample query; comparing non-normalized calls.

**Episode 7. Annotating variants** (live 40, full 60; depends on 6)
- Objectives: annotate consequences with SnpEff using a database that matches the reference build; add gnomAD allele frequencies, including the ancestry-matched group; read ANN fields (allele, effect, impact, gene, transcript, HGVS); filter and tabulate by impact and frequency; explain annotation caveats.
- Concepts: Sequence Ontology terms; impact classes; transcripts (MANE, canonical); HGVS; population databases and ancestry; what ClinVar is for and its limits; matching versions and contig names; a predicted effect is not a demonstrated function.
- Hands-on: `snpEff -dataDir <staged>`; `bcftools annotate` with a staged gnomAD subset; SnpSift filters or `bcftools query` tables; challenges: count HIGH-impact calls in HG002, and interpret one missense variant using global and Ashkenazi (asj) frequencies.
- Outputs: `results/annot/trio.ann.vcf.gz`, `snpEff_summary.html`, TSV tables.
- Common errors: build or contig mismatch; Java heap; an unstaged database (compute nodes may lack internet access [U]); multiple ANN entries per variant; a flood of MODIFIER annotations; the wrong AF field.

**Episode 8. Application: candidate variants in a family trio** (live 50, full 75; depends on 6, uses 7). The full design is in section 5.5.
- Objectives: confirm relationships and sample order before trio analysis; report the Mendelian-consistency rate as a QC metric; select de novo and recessive candidates with genotype expressions; add quality and annotation filters and report a filtering funnel; inspect candidates in IGV and against the benchmark; write an interpretation that separates call quality from biological significance.
- Hands-on: `bcftools query -l`; `bcftools +mendelian2` (syntax depends on the version); genotype expressions such as `GT[0]="het" && GT[1]="RR" && GT[2]="RR"` (child, father, mother); parental alt-read checks, GQ and DP; annotation and frequency filters; funnel counts; IGV snapshots.
- Outputs: `results/trio/funnel.tsv`, `results/trio/candidates.tsv`, a short written interpretation.
- Common errors: wrong sample order; treating missing genotypes as reference; site-level filters where genotype-level filters are needed; global frequencies for an Ashkenazi individual; overinterpretation.

**Episode 9. Application: variation across samples and populations** (self-paced, full 75; depends on 6)
- Question: where do these samples sit within global genetic diversity, and how does that change what "rare" means?
- Objectives: genotype the trio at panel sites; merge with a staged 1000 Genomes high-coverage chr20 subset; compute PCA and KING kinship with PLINK 2; plot in R; interpret clusters and relatedness; recognize batch and ascertainment effects.
- Concepts: allele frequency; LD pruning; MAF filters; what PCA shows and what it does not; kinship coefficients (about 0.25 for parent and child); batch effects from different pipelines; careful use of ancestry labels.
- Outputs: eigenvectors, a kinship table, a PCA plot.

**Episode 10. Adapting the workflow: your organism, your data, at scale** (self-paced, 45)
- Objectives: adapt each step to non-model organisms (reference quality, ploidy settings, inbred or clonal lines, pooled samples), to other data types (exome and targeted intervals, low-pass and GBS data, RNA-seq caveats, long reads), and to scale (GVCF joint genotyping; nf-core/sarek; the RCAC nf-core OOD apps where available); plan resources; validate without a truth set; know when human data must go on controlled systems.
- Hands-on: build a SnpEff database from a small GFF; a "design your workflow" worksheet.

### 3.5 What to teach live and what to leave for self-paced study

- **Live:** genotype and VCF semantics, read groups, filtering trade-offs, evaluation and interpretation. These topics carry the misconceptions that lead to wrong conclusions, and they benefit from instructor feedback. Cluster mechanics (accounts, queues, arrays) also fail most often on first use, and instructors can fix them in the room.
- **Self-paced:** alternative callers (5B: long runtimes, many steps), population analysis (9: extra data and R), adapting to a learner's own organism (10: learner-specific), downloads from public archives, and the full-length versions of Episodes 1-3. This material is mechanical, long-running or audience-specific, and it reads well as text.

### 3.6 Selecting a subset

- Minimum viable live path: 1, 2 and 3 condensed, 4, 5A, 6, 7 (can be compressed to a demo), 8.
- Substitutions: 5B for 5A for a GATK-focused audience (needs a prebuilt GVCF fallback); 9 for 8 for a population-genetics audience (adds R in OOD).
- Do not drop: 4 before 5 (read groups), 6 before 8 (filtered calls and the precision idea), or 2 (paths and metadata).
- Every live job has a completed-results fallback, so a learner who falls behind can rejoin at the next episode.

## 4. Six-hour schedule

Assumption (D6): the six hours are instruction only and exclude breaks and lunch. The day runs 9:00-4:30 with a 60-minute lunch and two 15-minute breaks. Data copy and login checks happen 8:30-9:00 and are not counted. Job runtimes are placeholders until the reference run (P3).

| Time | Block | Explain | Hands-on | Exercise and discussion | Running in the background |
|---|---|---|---|---|---|
| 8:30-9:00 | Arrival, login, data check | | | | rsync if not done earlier |
| 9:00-9:30 | Ep 1 | 20 | 0 | 10 | |
| 9:30-10:05 | Ep 2 and 3 | 12 | 15 | 8 | FastQC |
| 10:05-10:20 | Break | | | | |
| 10:20-11:30 | Ep 4 | 25 | 30 | 15 | Alignment array (submit by about 10:35) |
| 11:30-12:15 | Ep 5A | 20 | 15 | 10 | Calling array (submit by about 11:40; target under 15 min) |
| 12:15-1:15 | Lunch | | | | Buffer for late jobs only |
| 1:15-2:15 | Ep 6 | 20 | 20 | 20 | hap.py |
| 2:15-2:30 | Break | | | | |
| 2:30-3:10 | Ep 7 | 15 | 15 | 10 | SnpEff |
| 3:10-4:00 | Ep 8 | 15 | 20 | 15 | |
| 4:00-4:30 | Wrap-up, limitations, next steps, survey | 15 | 0 | 15 | |
| | Total (360 min) | 142 | 115 | 103 | |

Design rules:
- Each live job should finish within about 15 minutes on standby when nodes are free. P2 measures this.
- Teach the matching concepts while jobs run: SAM/BAM anatomy during alignment; VCF anatomy during calling, using a small staged example VCF so the query challenges do not wait for the learner's own calls. Concatenation and normalization of the learner's calls close Episode 5A, with the completed-results VCF as fallback. Lunch is a buffer, not part of the plan.
- Pacing option recorded in your RNA-seq log: submit the alignment array from the staged script at the end of the Episode 2-3 block, so it runs over the break, and let Episode 4 dissect the script while it runs.
- The survey slot covers the post-workshop survey required by your Goal 1b.

5.5-hour version (ends at 4:00): Episode 1 to 25 minutes; Episodes 2 and 3 to 30; Episode 7 to 30 (demo only); wrap-up to 20, with the survey on the way out.

## 5. Technical recommendations

### 5.1 Dataset

**Recommended (D1): the GIAB Ashkenazi trio on chr20.**
- Inputs: the DeepTrio WGS case-study BAMs `HG00{2,3,4}.novaseq.pcr-free.35x.dedup.grch38_no_alt.chr20.bam` at `https://storage.googleapis.com/deepvariant/case-study-testdata` [O]. Convert them to paired FASTQ for learners.
- Reference: `GCA_000001405.15_GRCh38_no_alt_analysis_set` from the NCBI analysis-set directory, as used in the same case study [O].
- Truth sets: NIST v4.2.1 benchmarks for HG003 and HG004. For HG002, NIST now recommends v5.0q (based on the T2T-HG002 assembly, covering small variants and SVs) and marks v4.2.1 deprecated (NIST GIAB page, updated 2026-05-12) [O]. Read the v5.0q README and confirm its GRCh38 files [U]. Teaching opportunity (self-paced): measured performance changes with the benchmark's scope.
- Why this dataset: truth sets turn filtering from opinion into measurement; the pedigree supports Mendelian QC and a realistic downstream task; chr20 keeps per-learner compute modest but still yields many variants (the DeepTrio case study reports about 143,000 records variant in at least one trio member on chr20) [O].
- Caveats to teach: reads were selected from chr20 alignments; the "dedup" BAMs may already lack duplicates [U]; NovaSeq qualities are binned; annotation resources are human-centric.
- To verify in P2: file sizes, read length, duplicate flags, redistribution terms for a Depot copy, and whether to subset by region or coverage to meet the runtime budget.

**Alternative if your audience is mostly plant or agricultural:** Arabidopsis accessions from the 1001 Genomes Project on TAIR10.
- Gains: learners can build the index for a small genome; plant relevance; continuity with your genome assembly workshop; a phenotype story (FRIGIDA and FLC alleles and flowering time; Johanson et al. 2000; 1001 Genomes Consortium 2016); natural population analysis.
- Costs: no gold-standard truth set, so Episode 6 becomes proxy-based; inbred lines have few true heterozygotes, which weakens genotype teaching; and the FRIGIDA alleles include larger indels that small-variant callers can miss.
- Episodes 1 and 3-5 change little. Episodes 2, 6, 7 and 8 change substantially.

**Not recommended as the primary dataset:** E. coli LTEE data (Data Carpentry, wrangling-genomics). It is haploid, too simple for this audience, and duplicates an existing Carpentries lesson.

### 5.2 Workflow and tools

Negishi availability comes from the `PurdueRCAC/Biocontainers` modulefiles (2026-10-01) [O]. Upstream versions come from release tags checked on 2026-10-09 [O]. Default versions on Negishi are [U].

| Step | Tool | On Negishi (biocontainers) | Upstream latest | Role |
|---|---|---|---|---|
| Read QC | FastQC, MultiQC | 0.11.9, 0.12.1; up to 1.23 | 0.13.0; 1.35 | Live, as in RNA-seq |
| Trimming | fastp | 0.20.1, 0.23.2 | 1.4.0 | Reference only |
| Alignment | bwa mem | bwa 0.7.17; bwa-mem2 not deployed | bwa 0.7.19; bwa-mem2 2.3 | Live. Switch to bwa-mem2 only if runtime requires it: its README gives about 10 GB of memory to map against a human index and 28N GB to build one |
| BAM processing | samtools | 1.9, 1.15-1.17, 1.22.1 | 1.24 | Live; pin 1.22.1 |
| Coverage | mosdepth | 0.3.3 | 0.3.14 | Live |
| Calling | bcftools | 1.9, 1.13, 1.14, 1.17 | 1.24 | Live; see 5.3 |
| bgzip, tabix | htslib | 1.14-1.17 | 1.24 | The bcftools module exposes `bcftools` and its scripts but not `bgzip` or `tabix` [O] |
| Benchmarking | hap.py | 0.3.9 | 0.3.15 | Live; rtg-tools is not deployed |
| Annotation | SnpEff, SnpSift | Up to 5.3.0a; up to 5.2 | 5.4c | Live; stage the database |
| Viewing | IGV | 2.11.9 to 2.19.1 | | Needs a GUI session (ThinLinc or an OOD desktop) [U]; fallback is `samtools tview` plus snapshots |
| Track 5B | GATK | gatk4 up to 4.6.0.0 | 4.7.0.0 | Self-paced |
| Comparison | DeepVariant | 1.0.0, 1.1.0 | 1.10.0 | The Negishi versions are too old; precompute with a current image, or skip |
| Episode 9 | PLINK 2 | 2.00a2.3, a5.12, a6.9 | | Self-paced |
| Optional phasing | WhatsHap | 1.4 (2.8 on Gautschi) | 2.8 | Optional |

Why bcftools live (D2):
- One ecosystem (samtools, bcftools, htslib) carries learners from BAM to trio analysis: stats, filter, norm, annotate, query and `+mendelian2`. It works for any organism and ploidy, and it runs fast.
- Its weaker indel performance shows up in Episode 6, where it motivates 5B instead of being hidden.
- GATK is the production standard for human data, but its sequence dictionary, GVCF consolidation and Java tuning would consume the day. DeepVariant is the most accurate but opaque and CPU-heavy.

Why SnpEff (D3): it has prebuilt databases for many species, simple custom builds from GFF, and the standard ANN field. VEP on Negishi is release 108 (2022) and needs a large cache.

Why hap.py: it is the GA4GH-standard comparison tool, already deployed, and gives per-type precision and recall plus ROC tables in one run. rtg vcfeval is the alternative if you deploy rtg-tools 3.13.

### 5.3 Version policy (D5)

Pin and load explicit versions for samtools and bcftools. This deviates from the RNA-seq default-module convention because bcftools behavior changed across releases (bcftools NEWS and manual [O]):
- 1.13: BAQ was revamped, which changes calls; `--config 1.12` restores the old behavior.
- 1.17: `+mendelian` was deprecated and replaced by `+mendelian2`, with different options and output.
- 1.18: `--write-index` was added. Negishi's 1.17 does not have it.
- 1.20: a new `--indels-cns` indel model; the `-X illumina` preset uses it.
- 1.24 (2026-07-09): `+trio-dnm2` was removed and replaced by `+trio-dnm3`; `+split-vep` reads SnpEff output.

Recommendation:
- Deploy bcftools 1.24 and htslib 1.24 as biocontainers before content freeze, and pin them.
- Keep the core trio logic in plain filter expressions, so the lesson does not depend on fast-moving plugins.
- If you keep 1.17 instead, the episodes must avoid `--write-index` and treat `+trio-dnm2` as optional.

### 5.4 Compute and storage (estimates; P2 measures them)

- Per sample: about 7.5 million read pairs (64 Mb x 35 / 300 bp) [I].
- Reference: the GRCh38 FASTA is about 3.1 GB and the bwa index a few GB. Keep both read-only on Depot and use them in place, rather than copying them to every learner's scratch [I, proposal; a deviation from RNA-seq, which copies everything].
- Memory: Negishi provides about 1.9 GB per core. Request cores and never `--mem` (RNA-seq CLAUDE.md) [O]. bwa mem with a human index fits in 8 cores; use 16-32 for speed.
- Per-learner scratch: FASTQ, BAMs and VCFs, probably 10-20 GB [I].
- Budget rule: any live step longer than about 15 minutes gets reduced (by region or coverage) or replaced by a prebuilt fallback.
- Concurrency: 20 learners x 3 alignment tasks x 16 cores is about 960 cores on standby. RNA-seq ran a heavier pattern (8 tasks x 20 cores per learner) [I].

### 5.5 Downstream application (Episode 8)

**Question:** in the child (HG002), which variants are consistent with a de novo or autosomal recessive model, plausibly protein-altering, and rare in an ancestry-matched population? How many of these candidates survive inspection?

**Inputs:** the filtered trio VCF (Episode 6), the SnpEff- and gnomAD-annotated VCF (Episode 7), the PED file, the BAMs, and the benchmark VCF and BED.

**Outputs:**
- A funnel table: the number of variants remaining after each filter.
- A candidate TSV: position, gene, consequence, genotypes, DP, GQ and AD, and AF (global and asj).
- IGV notes and a short written interpretation.

**Steps:**
1. Check sample order and relationships (`bcftools query -l`; `bcftools gtcheck`, or PLINK 2 KING if time allows).
2. Report the Mendelian-consistency rate from `+mendelian2` as a QC number, and relate violations to their error sources.
3. Apply inheritance filters: de novo (child heterozygous, both parents homozygous reference) and recessive (child homozygous alternate, both parents heterozygous). Compound heterozygotes are a self-paced extension.
4. Apply evidence filters: GQ and depth in all three samples; zero or near-zero alternate reads in the parents for de novo candidates.
5. Apply annotation filters: HIGH or MODERATE impact; AF below a stated cutoff, both global and asj.
6. Inspect the survivors in IGV and check them against the benchmark.

**Interpretation:**
- Expect about 1-2 true de novo SNVs on chr20 in one child (1.2e-8 per bp per generation x 2 x 64 Mb; Kong et al. 2012). With an expectation of about 1.5, there is roughly a 22% chance (Poisson) of none at all. Naive candidate lists usually run to tens or hundreds, so most candidates are errors. Base rates should set the level of skepticism.
- HG002 DNA comes from a lymphoblastoid cell line, so cell-line mutations can look like de novo variants. This is a teaching point, and a reason to check how the benchmark BEDs (for example the `_noinconsistent` regions) treat de novo sites before any benchmark-based statement about them.
- Healthy genomes carry on the order of 100 loss-of-function variants (MacArthur et al. 2012). A rare, damaging-looking variant is not a diagnosis.
- Justified conclusion: a ranked list of candidates for orthogonal validation, with stated filters.
- Not justified: pathogenicity, causation, or any health statement about a real person.

**Confounders and common mistakes:**
- Low parental coverage read as homozygous reference.
- Deletions or CNVs that create apparent Mendelian errors or false homozygosity.
- Segmental duplications and reference errors.
- Parental mosaicism; sample swaps.
- Global AF used for an Ashkenazi individual, which makes founder variants look rare.
- The transcript chosen during annotation.
- Thresholds tuned until a "nice" list appears.

### 5.6 Validation anchors (values come from the reference run, not set in advance)

- Alignment: mapped and properly paired percentages, duplicate percentage, and mean chr20 depth per sample.
- Calls: SNV and indel counts per sample; Ts/Tv.
- Benchmark: HG002 SNV and indel precision and recall (PASS, confident regions); the shape of the ROC curve.
- Trio: Mendelian violation rate; de novo funnel counts; how many candidates are in the truth set (only after P2 confirms how the benchmark treats de novo sites).
- Sentinels: 3-5 positions with benchmark genotypes (a het SNV, a hom-alt SNV, an indel, and a Mendelian-violation site if one exists), checked on every kit run.
- Pass rule: if an anchor disappears or changes sign, treat it as an upstream break, as with the inverted-contrast bug in the RNA-seq workshop.

## 6. Implementation roadmap

| Phase | Objective | Main deliverables | Acceptance criteria | Depends on |
|---|---|---|---|---|
| P1 Scaffold and decisions | Verify this assessment in your checkout and set up infrastructure; no lesson content | `.claude/CLAUDE.md`; `maintenance/log/updates.md` with D1-D8; config and `.gitignore` fixes; episode stubs; page skeletons | `validate_lesson()` clean; nothing invented; non-lesson files not rendered | This plan |
| P2 Environment and data feasibility | Measure before writing | `negishi-run/00_preflight.sh` (modules, defaults, plugins, account, Depot, compute-node internet); `data-prep/` scripts; a one-sample pilot; feasibility memo | Every technical TBD (D1, D5, and the account and paths in D8) resolved with a number or a decision; runtimes within budget. Date and co-instructor stay open until P10 | P1, gate G1 |
| P3 Reference run and staging | Produce the answer key | Non-learner `pipeline/` scripts; a full trio run; staged learner copy and `_results`; `staged_manifest.tsv`; `check_staged.sh`; anchors in CLAUDE.md | Staged copy passes md5 and permission checks; anchors recorded with dates and versions | P2, gate G2 |
| P4 Episodes 1-4 and setup | Write and validate the front half | Episodes 1-4; full `setup.md`; run kit v1 (`build_kit.py` extracts episode fences) | The kit runs Episodes 2-4 as a new learner and the outputs match the reference run | P3, gate G3 |
| P5 Episodes 5A and 6 | Calling, filtering, evaluation | Episodes 5A and 6; kit extended | Anchors pass; every number in the text comes from the kit | P4 |
| P6 Episodes 7 and 8 | Annotation and the application | Episodes 7 and 8; funnel; IGV snapshots | The candidate list and funnel reproduce; interpretation reviewed for overclaiming | P5 |
| P7 Supporting material | Make the lesson teachable by others | Public instructor notes, glossary, learner profile, figures and animations with alt text, index, README, CITATION | Alt text meets WCAG; the timing table matches front matter | P4-P6 |
| P8 Self-paced episodes | 5B, 9, 10 | Episodes plus kit coverage | Same as P5. May ship after the first delivery; stays out of `config.yaml` until validated | P5 |
| P9 Validation and review | Independent check | A fresh-account kit run on standby; static checks; an independent scientific and pedagogical review | No open `[blocker]`; review findings fixed or accepted | P4-P8 |
| P10 Delivery readiness | Run the day | Dated schedule and instructor list; timed dry run with the co-instructor; local narration and coaching; survey link; `life_cycle` update | The dry run fits 360 minutes; fallbacks tested | P9 |

Gates:
- G1 during P1: you approve D1-D8 in the Prompt 01 decisions block. The episode stubs wait for it.
- G2 after P2: feasibility numbers are in.
- G3 after P3: anchors are frozen.

Content work starts only after G3, so no output block is ever written from memory.

## 7. Claude Code prompt sequence

### 7.1 How to use the prompts

- Save each prompt as `maintenance/prompts/prompt-NN-<name>.md`. That directory is gitignored, as in RNA-seq.
- Use one prompt per Claude Code session, and review the diff and report before running the next.
- Every prompt follows the same contract: inspect first; change only the listed files; never invent values; log findings with severity tags; stop at the listed questions; end with a report that separates executed tests, static checks and unverified assumptions.

### 7.2 Prompt 01 (full text)

The same text is in `prompt-01-scaffold.md`. Edit the Decisions block before pasting.

````text
# Prompt 01: Verify the assessment, record decisions, scaffold the lesson

## Decisions (edit before running: change each STATUS to approved, or write the change)
- D1 Dataset: GIAB Ashkenazi trio HG002 (child), HG003 (father), HG004 (mother); Illumina NovaSeq PCR-free ~35x reads from chr20; GRCh38 no-alt analysis set. STATUS: pending
- D2 Live caller: bcftools mpileup/call. GATK HaplotypeCaller is self-paced Episode 5B. STATUS: pending
- D3 Annotation: SnpEff/SnpSift plus gnomAD allele frequencies via bcftools annotate. STATUS: pending
- D4 Live application: Episode 8, candidate variants in the trio. Episode 9, population variation, is self-paced. STATUS: pending
- D5 Versions: explicit module versions for samtools and bcftools; target bcftools 1.24 (to be deployed), else 1.17. STATUS: pending
- D6 Six hours means instruction excluding breaks and lunch; the day runs 9:00-4:30. STATUS: pending
- D7 Conventions: follow rnaseq-analysis (numbered files and titles, display fences never executed at build, run kit, .claude/CLAUDE.md, maintenance log), plus public instructor notes structured like singlecell-rnaseq. STATUS: pending
- D8 Logistics: repo rcac-bioinformatics/variant-calling; SLURM account TBD; Depot /depot/workshop/data/varcall-workshop and /depot/workshop/data/varcall-workshop_results; working directory $SCRATCH/varcall-workshop, with $SCRATCH as the only scratch variable; delivery date TBD; co-instructor TBD. STATUS: pending

## Context
You are in the variant-calling lesson repository, a fresh Carpentries Workbench (sandpaper) skeleton. The development plan is maintenance/plan/development-plan.md. My other workshops are sibling checkouts and define the conventions to follow:
- ../rnaseq-analysis: the primary reference. It is the most recent and has .claude/CLAUDE.md, maintenance/log/updates.md and negishi-run/.
- ../singlecell-rnaseq
- ../genome-assembly
If any of these paths does not exist, ask me for the location. Do not clone anything.

## Objective
Confirm the repository state against the plan, record the decisions above, and create the development scaffolding that every later phase depends on. This phase writes no teaching prose, commands, data or numbers.

## Read first (read-only)
1. Everything tracked in this repository, plus git status and git log.
2. maintenance/plan/development-plan.md. Sections 1-4 and 6 matter most.
3. ../rnaseq-analysis: .claude/CLAUDE.md, config.yaml, .gitignore, learners/setup.md, profiles/learner-profiles.md, episodes/04a-genome-based-quantification.Rmd (the pattern episode), the first 60 lines and section headings of maintenance/log/updates.md, negishi-run/README.md, and negishi-run/docs/ADAPTATIONS.md. If they exist locally (they are gitignored), list maintenance/prompts/, instructor-notes/ and coaching/, and read one file of each kind to learn the format.
4. ../singlecell-rnaseq: config.yaml, index.md, learners/setup.md, instructors/instructor-notes.md, episodes/introduction.Rmd.
5. ../genome-assembly: config.yaml, CITATION.cff.

## Tasks
1. Create branch dev/p01-scaffold from main. Do not commit; leave all changes for my review.
2. Check section 1 of the plan against what you read. List every discrepancy as "plan says X, repository shows Y". Where the repositories and the plan disagree, the repositories win. Do not change my other repositories.
3. Create .claude/CLAUDE.md modeled on ../rnaseq-analysis/.claude/CLAUDE.md, with the same section order:
   - What this is
   - Dataset and validation anchors
   - Build and preview
   - Structure that is not obvious from the tree
   - Delivery format
   - Instructor materials (local only, gitignored)
   - Maintenance log and what the site publishes
   Fill in only what is decided (D1-D8) or observed. Mark every unknown TBD(Pn), naming the phase that resolves it: tool versions, runtimes, sizes, anchors, account, paths, dates. Record these conventions:
   - Display fences only, never executed at build time.
   - Numbered titles.
   - The RNA-seq SLURM header pattern, with the account as TBD.
   - Never set --mem.
   - Explicit module versions for samtools and bcftools, and why (plan section 5.3).
   - Every output block and number in an episode comes from the Negishi run kit.
   - $SCRATCH is the only scratch variable in episodes and on the setup page.
   - Titles that start with a bare digit escape the period in single-quoted YAML (the RNA-seq rule).
   - Non-lesson Markdown stays out of sandpaper's reach.
4. Create maintenance/log/updates.md:
   - Copy the RNA-seq severity legend ([blocker], [should-fix], [nice], [check]).
   - Add these sections: Decisions (a table of D1-D8 with status and today's date); Open findings (your discrepancies plus the gap-analysis items in plan section 2, each tagged); Revision opportunities; Runtime record; Done. Leave the last three empty.
5. config.yaml:
   - Set source to the GitHub repository URL from D8, not the Pages URL.
   - Set life_cycle to 'pre-alpha', keywords specific to this lesson, and disable_sidebar_numbering: true.
   - Fill the episodes list (stubs from task 7), learners (setup.md, reference.md), instructors (instructor-notes.md) and profiles (learner-profiles.md).
   - Keep carpentry, varnish, title, license, contact and branch.
   - Do not touch .github/workflows/.
6. .gitignore:
   - Add the RNA-seq local-only entries that apply: instructor-notes/, coaching/, maintenance/prompts/, local-test/, negishi-run/generated/, negishi-run/staged-data/, negishi-run/*.tar.gz, and !negishi-run/docs/.
   - Do not ignore maintenance/plan/ or maintenance/log/.
7. Episodes:
   - Delete the Workbench demo episodes/introduction.Rmd; it is template sample content with nothing to keep.
   - Create stubs for the core episodes in plan section 3.3 only (1, 2, 3, 4, 5A, 6, 7, 8), with file names in the 01-short-name.Rmd pattern (05a for 5A).
   - Each stub has front matter (source: Rmd; a numbered title; teaching and exercises taken from the split in the Full min column of plan section 3.3); questions; objectives from plan section 3.4 (dataset-specific wording only if D1 is approved); the section headings the spec implies; an instructor div that says "Stub: content arrives in phase Pn"; and keypoints marked TBD.
   - Title format: a title that starts with a bare digit must escape the period inside single quotes, exactly as in ../rnaseq-analysis/episodes/01-intro-to-rnaseq.Rmd, for example title: '1\. Introduction to genetic variation and variant calling'. Unescaped, sandpaper parses it as an ordered list and build_lesson() fails with "StartTag: invalid element name". A letter-suffixed title such as "5A. Calling variants with bcftools" needs no escape.
   - No prose, commands or outputs.
8. Public pages, skeleton only:
   - index.md: landing text in the style of ../singlecell-rnaseq/index.md (what the workshop is, who it is for, the outcomes from plan section 3.2, a link to setup).
   - learners/setup.md: the RNA-seq section structure (Instructors, Schedule, Prerequisites, Scope, Toolchain, What is not covered, SSH setup, Data setup), plus a heading for a graphical session (OOD desktop or ThinLinc) for IGV, marked TBD(P2). Copy the SSH setup section from ../rnaseq-analysis/learners/setup.md, since it is the same cluster, but adapt its episode references (it mentions "Episodes 2 to 4B"). Everything dataset- or delivery-specific becomes TBD(Pn) in HTML comments, like RNA-seq's TODO(instructor) comments.
   - learners/reference.md: glossary headings and a term list only, no definitions yet.
   - instructors/instructor-notes.md: the live and full timing table and the delivery modes from plan sections 3.3-3.6 and 4, plus headings for Common issues, Pre-workshop checklist and Challenge discussion points (the scRNA-seq structure).
   - profiles/learner-profiles.md: adapt ../rnaseq-analysis/profiles/learner-profiles.md to variant calling.
   - README.md and CITATION.cff: follow ../genome-assembly/CITATION.cff, with Arun Seetharam and the ORCID from that file; other authors TBD.
   - links.md: keep only the links that are used.
9. Validate:
   - If R and sandpaper are installed, run Rscript -e 'sandpaper::validate_lesson()' and Rscript -e 'sandpaper::build_lesson(preview = FALSE)'.
   - List the rendered pages under site/built/ and confirm that nothing from .claude/ or maintenance/ was rendered.
   - Search the changed files for em dashes and replace them; my style avoids them.
   - Report the sandpaper and varnish versions used.

## Constraints
- Preserve working functionality and existing conventions. Explain in the log any deviation from the ../rnaseq-analysis conventions.
- Do not invent tool versions, runtimes, file sizes, anchors, account names, paths or dates. Anything unknown is TBD(Pn).
- Writing style: plain and direct, sentence-case headings, no em dashes.
- Change only the files listed above.

## Stop and ask before continuing if
- any D1-D8 status is still pending. Record pending decisions as pending in the log, finish tasks 1-6, and stop before task 7 to ask me;
- a git remote exists and its repository name differs from D8. No remote is expected at this stage; if there is none, note it in the log and continue;
- the RNA-seq local-only files show conventions that conflict with this prompt (for example, a different instructor-notes structure);
- sandpaper or varnish differ from 0.17.1 and aseetharam/varnish, or the build fails for a reason unrelated to your changes;
- a change would require editing .github/workflows/ or any of my other repositories.

## Acceptance criteria
- Only the listed files changed (show git status --porcelain), and there are no commits. The pre-existing modifications to config.yaml and variant-calling.Rproj and the new maintenance/ directory are expected.
- validate_lesson() reports no new problems; any failures are explained and pre-existing.
- No invented values; every unknown is marked TBD(Pn).
- Non-lesson Markdown is not rendered.
- The log contains the decision table and tagged findings.

## Report at the end of the session
1. Changes: each file with one line on its purpose.
2. Validation: what was executed (command and result), what was checked statically, and what was not run and why.
3. Discrepancies with the plan.
4. Unresolved issues and questions for me.
5. Recommended next step (normally Prompt 02).
````

### 7.3 Prompts 02-10 (summaries; full text written when the previous phase closes)

**02 Environment and data feasibility** (runs partly on Negishi; depends on P1 and G1)
- Deliverables:
  - `negishi-run/00_preflight.sh`, adapted from RNA-seq. It checks module availability and defaults, the bcftools plugin list, hap.py and SnpEff smoke runs (including whether the hap.py 0.3.9 container supports the vcfeval engine), account and QoS (`sacctmgr`, `sbatch --test-only`), Depot space, and compute-node internet access to storage.googleapis.com, ftp.ncbi.nlm.nih.gov, ftp-trace.ncbi.nlm.nih.gov, gnomAD and the SnpEff database host.
  - `data-prep/` scripts with a dry-run mode: BAM download with checksums; BAM to FASTQ (`samtools collate`, `samtools fastq`); optional region or coverage subsetting with a fixed seed; reference and indexes; benchmark subsets, including a check of the HG002 v5.0q README; a gnomAD subset; the SnpEff database.
  - A one-sample pilot (align, then call one region) that records wall time, MaxRSS from `sacct`, and sizes. Output: `maintenance/plan/feasibility.md`.
- Acceptance: every TBD for versions, sizes, runtimes, account and internet is resolved or escalated, with a recommendation on whole chr20 vs a sub-region.
- Stop if: data terms prohibit staging; HG002 v5.0q lacks GRCh38 files; the budget forces a change to D1; a module must be deployed (you deploy it).

**03 Reference run and staging** (depends on P2 and G2)
- Deliverables:
  - Non-learner `pipeline/` scripts that run the whole trio workflow with the pinned versions.
  - The RNA-seq staging tools, adapted: `staged_manifest.tsv`, `make_staged_manifest.py`, `restage.sh`, `check_staged.sh`, `regen_results.sh`.
  - The staged learner copy and `_results` on Depot.
  - Anchors and sentinels written into `.claude/CLAUDE.md` with dates and versions; a runtime record in the log.
- Acceptance: the manifest, md5 sums and group-read permissions pass; a rerun reproduces the records.
- Stop if: anchors look implausible (for example, Ts/Tv far from about 2, low SNV recall, or a high Mendelian violation rate).

**04 Episodes 1-4, setup page, run kit v1** (depends on P3 and G3)
- Deliverables: full episodes in the RNA-seq style; a complete `setup.md` with a pinned toolchain table; `build_kit.py` (fence extraction and step graph), `submit_all.sh`, `collect.sh`, `summarize.py`, and `docs/ADAPTATIONS.md`, adapted from RNA-seq; the specification for the reads-to-genotype animation.
- Acceptance: the kit runs Episodes 2-4 as a new learner on standby; every output block comes from the kit; `validate_lesson()` is clean.
- Stop if: a command fails as written (fix the episode, not the kit), or the text needs a scientific claim without a citable source.

**05 Episodes 5A and 6** (depends on P4)
- Deliverables: the episodes; kit steps for calling, normalization, filtering and hap.py; a precision-recall figure built from the ROC tables.
- Acceptance: anchors pass; solutions use kit values; site-level and genotype-level filters are explained correctly; no accuracy claims beyond what was measured.
- Stop if: a threshold can only be justified by looking at the benchmark (leakage); ask how to frame it.

**06 Episodes 7 and 8** (depends on P5)
- Deliverables: the episodes; SnpEff and gnomAD steps; the funnel table; the candidate table; IGV snapshots; interpretation text checked for overclaiming.
- Acceptance: the funnel reproduces; each candidate's status against the benchmark is reported; no health statements about the individuals.
- Stop if: a candidate looks clinically significant for a real person; ask how to present it, or choose a different illustrative example.

**07 Supporting materials** (depends on P4-P6)
- Deliverables: public instructor notes (timing, checklist, common issues, discussion points); glossary definitions; learner profile; HTML animations in the RNA-seq style; figures with descriptive alt text; index, README, CITATION.
- Acceptance: alt text meets WCAG 2.1 AA; every term is defined at or before first use; the timing table matches front matter.

**08 Self-paced episodes 5B, 9, 10** (depends on P5)
- Deliverables: the episodes, kit coverage, and staged extras (GATK resources, the 1000 Genomes subset).
- Acceptance: as in P5. Add each episode to `config.yaml` only after it passes.
- Stop if: storage or runtime for Episode 9 exceeds the budget.

**09 Validation and independent review** (depends on P4-P8)
- Deliverables:
  - A full kit run from a fresh account on standby.
  - Static checks: `validate_lesson()`, shellcheck on every script, link check.
  - A review by a separate agent or colleague with no build context, using a rubric that covers scientific accuracy, overclaiming, terminology order and exercise-solution consistency.
  - Fixes for the findings, or log entries for them.
- Acceptance: no open `[blocker]`; every number traces to a kit file.

**10 Delivery readiness** (depends on P9)
- Deliverables: dated schedule and instructor list; an account and queue checklist; notes from a timed dry run; local narration and coaching files generated with your coaching prompt; survey link; `life_cycle` update; a post-delivery retrospective template.
- Acceptance: the dry run fits 360 minutes, and switching to each fallback mid-episode works.

## 8. Negishi check you can run now (optional, not executed here)

This settles part of D5 before Prompt 02. Run it on a Negishi login node and paste the output into the log.

```bash
module --force purge
module load biocontainers
for t in fastqc multiqc fastp bwa samtools bcftools htslib mosdepth hap.py snpeff snpsift igv gatk4 plink2; do
  avail=$(module -t avail "$t" 2>&1 | grep -E "^$t/" | tr '\n' ' ')
  def=$( (module load "$t" >/dev/null 2>&1 && module -t list 2>&1 | grep -E "^$t/") || echo none )
  printf '%-9s default=%-22s available=%s\n' "$t" "$def" "$avail"
done
( module load bcftools && bcftools --version | head -1 && bcftools plugin -l 2>/dev/null | grep -E 'mendelian|trio|split-vep|fill-tags' )
( module load hap.py && hap.py --version 2>&1 | tail -1 )
sacctmgr -nP show assoc user="$USER" format=account,qos | sort -u
```

If the plugin list comes back empty, the container does not expose bcftools plugins and `+mendelian2` will fail. That is a deployment fix, not a lesson fix.

## Sources

- Your workshops: [rnaseq-analysis](https://github.com/rcac-bioinformatics/rnaseq-analysis) (2d0b5f8, 2026-10-05); [singlecell-rnaseq](https://github.com/rcac-bioinformatics/singlecell-rnaseq) (89eea2a, 2026-05-19); [genome-assembly](https://github.com/rcac-bioinformatics/genome-assembly) (20e694a, 2026-02-18).
- [PurdueRCAC/Biocontainers](https://github.com/PurdueRCAC/Biocontainers), modulefiles per cluster (a0e6be9, 2026-10-01).
- [DeepTrio WGS case study](https://github.com/google/deepvariant/blob/r1.10/docs/deeptrio-wgs-case-study.md): trio chr20 BAMs, v4.2.1 benchmarks, Mendelian check (read at r1.10 branch head 45f2627, 2026-03-18).
- [NIST Genome in a Bottle](https://www.nist.gov/programs-projects/genome-bottle): HG002 v5.0q recommended, v4.2.1 deprecated for HG002 (page updated 2026-05-12).
- [bcftools NEWS](https://github.com/samtools/bcftools/blob/develop/NEWS) (develop at 347c273, 2026-09-30; release 1.24 dated 2026-07-09).
- [bwa-mem2 README](https://github.com/bwa-mem2/bwa-mem2): index memory 28N GB to build, about 10 GB to map against a human index.
- [Data Carpentry: Data Wrangling and Processing for Genomics](https://datacarpentry.org/wrangling-genomics/).
- Wagner et al. 2022, Cell Genomics, GIAB v4.2.1: [doi:10.1016/j.xgen.2022.100128](https://doi.org/10.1016/j.xgen.2022.100128).
- Kong et al. 2012, Nature, de novo mutation rate: [doi:10.1038/nature11396](https://doi.org/10.1038/nature11396).
- MacArthur et al. 2012, Science, loss-of-function variants in healthy genomes: [doi:10.1126/science.1215040](https://doi.org/10.1126/science.1215040).
- Byrska-Bishop et al. 2022, Cell, 1000 Genomes high coverage: [doi:10.1016/j.cell.2022.08.004](https://doi.org/10.1016/j.cell.2022.08.004).
- Johanson et al. 2000, Science, FRIGIDA: [doi:10.1126/science.290.5490.344](https://doi.org/10.1126/science.290.5490.344); 1001 Genomes Consortium 2016, Cell: [doi:10.1016/j.cell.2016.05.063](https://doi.org/10.1016/j.cell.2016.05.063).
