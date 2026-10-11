# negishi-run/config.sh: settings shared by every kit and data-prep script. Sourced, never executed.
# shellcheck shell=bash disable=SC2034  # variables are used by the scripts that source this file
# Edit here, not in the scripts. Every value can be overridden from the environment, for example
#   KIT_ACCOUNT=myaccount BCFTOOLS_MODULE=bcftools/1.24 bash negishi-run/00_preflight.sh
# No secrets, and no memory requests: Negishi gives about 1.9 GB per core, so memory is sized by cores.

# ---- SLURM. Account rcac for now (2026-10-09); a workshop-specific account replaces it later.
# It lives only here, in the #SBATCH headers of pipeline/learner-scripts/*.sh and in the
# sinteractive lines of pipeline/learner-scripts/interactive/*.sh (00_preflight.sh checks all agree).
KIT_ACCOUNT=${KIT_ACCOUNT:-rcac}
KIT_PARTITION=${KIT_PARTITION:-cpu}
KIT_QOS=${KIT_QOS:-standby}

# ---- Where the phase-2 work lives (downloads, references, FASTQ, pilot outputs, records).
# Never under /depot/workshop/data: staging belongs to phase 3.
PREP_DIR=${PREP_DIR:-${SCRATCH:-}/varcall-prep}

# ---- Pinned modules (loaded after `module load biocontainers`), G2 decision 2026-10-09.
# P2 (2026-10-09) verified everything except bcftools/htslib 1.24, which were deployed for
# phase 3 together with `singularity exec` wrappers (the 1.17 wrapper used `singularity run`
# and dropped embedded double quotes). 00_preflight.sh checks quoting for every module.
BWA_MODULE=${BWA_MODULE:-bwa/0.7.17}
SAMTOOLS_MODULE=${SAMTOOLS_MODULE:-samtools/1.22.1}
BCFTOOLS_MODULE=${BCFTOOLS_MODULE:-bcftools/1.24}
HTSLIB_MODULE=${HTSLIB_MODULE:-htslib/1.24}
MOSDEPTH_MODULE=${MOSDEPTH_MODULE:-mosdepth/0.3.3}
HAPPY_MODULE=${HAPPY_MODULE:-hap.py/0.3.9}
SNPEFF_MODULE=${SNPEFF_MODULE:-snpeff/5.3.0a}
SNPSIFT_MODULE=${SNPSIFT_MODULE:-snpsift/5.2}
FASTQC_MODULE=${FASTQC_MODULE:-fastqc/0.12.1}
MULTIQC_MODULE=${MULTIQC_MODULE:-multiqc/1.23}
IGV_MODULE=${IGV_MODULE:-igv/2.19.1}
# Phase 2 only: other bcftools versions p-call-vcmp compared on one chunk.
BCFTOOLS_COMPARE_MODULES=${BCFTOOLS_COMPARE_MODULES:-bcftools/1.13 bcftools/1.17}
# 1 = start every kit job with `module --force purge`. Preflight 2026-10-09: not needed, no
# startup difference (kept at 1 for a clean environment)
KIT_PURGE=${KIT_PURGE:-1}

# ---- Samples, in the order child, father, mother (D1). Sex: 1 male, 2 female (PED coding).
SAMPLES=${SAMPLES:-"HG002 HG003 HG004"}
SAMPLE_ROLES=${SAMPLE_ROLES:-"child father mother"}
SAMPLE_SEX=${SAMPLE_SEX:-"1 1 2"}
FAMILY_ID=${FAMILY_ID:-AJ_trio}

# ---- Region and pilot sizes
REGION=${REGION:-chr20}
CALL_CHUNKS=${CALL_CHUNKS:-8}
PILOT_ALIGN_CORES=${PILOT_ALIGN_CORES:-"16 32"}
PILOT_SNPEFF_CORES=${PILOT_SNPEFF_CORES:-"4 8"}
# Call set for p-call, p-eval, p-snpeff and p-trio. "raw" is the first pilot (mpileup defaults,
# outputs under pilot/); any other set writes under pilot/<set>/ and its job names end in -<set>.
#   CALL_SET=q20 bash negishi-run/submit_pilot.sh
CALL_SET=${CALL_SET:-raw}
case $CALL_SET in
  raw) MPILEUP_FILTER="";;
  q20) MPILEUP_FILTER="-q 20 -Q 20";;   # minimum mapping quality 20, minimum base quality 20
  *) echo "ERROR: unknown CALL_SET '$CALL_SET' (raw or q20)" >&2; exit 1;;
esac
# "Rare" for the pilot candidate counts (feasibility only; the lesson states its own cutoff)
RARE_AF=${RARE_AF:-0.01}

# ---- SnpEff databases, in order of preference. The first one that `snpEff databases` lists
# is used; all are recorded. MANE first, then one full-transcript database for comparison.
# SnpEff 5.3a (2026-10-09) lists GRCh38.mane.1.2.ensembl and GRCh38.p14, not MANE 1.5 or GRCh38.105.
SNPEFF_DB_MANE=${SNPEFF_DB_MANE:-"GRCh38.mane.1.5.ensembl GRCh38.mane.1.2.ensembl GRCh38.mane.1.5.refseq"}
SNPEFF_DB_FULL=${SNPEFF_DB_FULL:-"GRCh38.p14 GRCh38.105 GRCh38.99"}

# ---- gnomAD INFO fields kept in the allele-frequency subset: an extended regex on the
# field name, applied to the names read from the file header (05_annotation.sh records them).
GNOMAD_KEEP_REGEX=${GNOMAD_KEEP_REGEX:-'^(AC|AN|AF|nhomalt)(_(afr|ami|amr|asj|eas|fin|mid|nfe|remaining|sas))?$'}
GNOMAD_REQUIRED_GROUP=${GNOMAD_REQUIRED_GROUP:-asj}

# ---- Service endpoints that are not files (files are listed in data-prep/sources.tsv)
GCS_BASE=${GCS_BASE:-https://storage.googleapis.com}
GCS_JSON_API=${GCS_JSON_API:-$GCS_BASE/storage/v1/b}

# ---- Phase 3: staging and the reference run
# Staged copies on Depot (D8). Learners rsync STAGED; STAGED_REF is read in place through the
# symlinks in their ref/; STAGED_RESULTS is created only by regen_results.sh --finalize (Part D).
STAGED=${STAGED:-/depot/workshop/data/varcall-workshop}
STAGED_REF=${STAGED_REF:-/depot/workshop/data/varcall-workshop_ref}
STAGED_RESULTS=${STAGED_RESULTS:-/depot/workshop/data/varcall-workshop_results}
STAGED_PERM=${STAGED_PERM:-group}          # who must read the staged copies: group or other
STAGED_GROUP=${STAGED_GROUP:-workshop}     # Depot group of /depot/workshop/data (P2 preflight)
# Staged content is assembled here first (scratch), then copied to Depot by restage.sh.
STAGE_BUILD=${STAGE_BUILD:-$PREP_DIR/stage}
# Reference runs: $KIT_SCRATCH_BASE/runs/<RUN_ID>/ (each call set gets its own learner copy).
KIT_SCRATCH_BASE=${KIT_SCRATCH_BASE:-${SCRATCH:-}/varcall-kit}
# Phase 4 episode run kit (submit_all.sh, collect.sh --run): one directory per run ID
KIT_RUNS=${KIT_RUNS:-$KIT_SCRATCH_BASE/kit-runs}
# Call sets of the reference run. G3 (2026-10-10) chose q0, mpileup defaults, now written into
# call.sh; the q0 vs q20 (-q 20 -Q 20) comparison is in maintenance/plan/reference-run.md.
REF_CALL_SETS=${REF_CALL_SETS:-q0}
# Teaching VCF region for resources/example/ (G3; restage.sh --example grows it to the nearest
# multiallelic site if it has none)
EXAMPLE_REGION=${EXAMPLE_REGION:-chr20:60000-90000}
SNPEFF_DB=${SNPEFF_DB:-GRCh38.mane.1.2.ensembl}
# Learner-facing name of the reference in ref/ (symlinks to the NCBI-named files on Depot)
REF_NAME=${REF_NAME:-GRCh38_no_alt}
DET_CORES=${DET_CORES:-32}                 # determinism check: realign one sample at this core count
