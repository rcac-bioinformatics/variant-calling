# negishi-run/config.sh: settings shared by every kit and data-prep script. Sourced, never executed.
# shellcheck shell=bash disable=SC2034  # variables are used by the scripts that source this file
# Edit here, not in the scripts. Every value can be overridden from the environment, for example
#   KIT_ACCOUNT=myaccount BCFTOOLS_MODULE=bcftools/1.24 bash negishi-run/00_preflight.sh
# No secrets, and no memory requests: Negishi gives about 1.9 GB per core, so memory is sized by cores.

# ---- SLURM. Every submit refuses to run while KIT_ACCOUNT is empty. The P2 pilot used rcac
# (QoS normal and standby, standby limit 4 h); the workshop account is TBD (feasibility memo).
KIT_ACCOUNT=${KIT_ACCOUNT:-}
KIT_PARTITION=${KIT_PARTITION:-cpu}
KIT_QOS=${KIT_QOS:-standby}

# ---- Where the phase-2 work lives (downloads, references, FASTQ, pilot outputs, records).
# Never under /depot/workshop/data: staging belongs to phase 3.
PREP_DIR=${PREP_DIR:-${SCRATCH:-}/varcall-prep}

# ---- Pinned modules (loaded after `module load biocontainers`). Override bcftools and htslib
# with the 1.24 versions if they have been deployed. Verified 2026-10-09: every pinned version
# loads and is the Negishi default; hap.py/0.3.9 reports v0.3.8-17; bcftools 1.24 and htslib 1.24
# are not installed. The bcftools/1.17 wrapper (singularity run) drops embedded double quotes
# from filter expressions: a module fix is pending (feasibility memo, decision 3).
BWA_MODULE=${BWA_MODULE:-bwa/0.7.17}
SAMTOOLS_MODULE=${SAMTOOLS_MODULE:-samtools/1.22.1}
BCFTOOLS_MODULE=${BCFTOOLS_MODULE:-bcftools/1.17}
HTSLIB_MODULE=${HTSLIB_MODULE:-htslib/1.17}
MOSDEPTH_MODULE=${MOSDEPTH_MODULE:-mosdepth/0.3.3}
HAPPY_MODULE=${HAPPY_MODULE:-hap.py/0.3.9}
SNPEFF_MODULE=${SNPEFF_MODULE:-snpeff/5.3.0a}
SNPSIFT_MODULE=${SNPSIFT_MODULE:-snpsift/5.2}
FASTQC_MODULE=${FASTQC_MODULE:-fastqc/0.12.1}
MULTIQC_MODULE=${MULTIQC_MODULE:-multiqc/1.23}
IGV_MODULE=${IGV_MODULE:-igv/2.19.1}
# Other bcftools versions to compare on one calling chunk (only those installed are used).
BCFTOOLS_COMPARE_MODULES=${BCFTOOLS_COMPARE_MODULES:-bcftools/1.13 bcftools/1.24}
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
