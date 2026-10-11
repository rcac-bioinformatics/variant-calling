#!/bin/bash
# 00_preflight.sh: check Negishi before staging and the reference run (phase 3; it also served
# the phase-2 pilot). Login node, about 5 to 15 minutes, most of it waiting for one standby job
# of at most 10 minutes. Phase 3 adds: argument-quoting checks for every workshop module (the
# 1.17 wrappers dropped embedded quotes), hap.py vcfeval with an RTG template, containers can
# read Depot, the account in the learner scripts, and check_staged.sh on both staged copies.
# Usage: bash negishi-run/00_preflight.sh [--no-srun]
#   --no-srun  skip the compute-node job (network and module checks on a compute node)
# Writes records/preflight.tsv (check, status, detail), records/preflight_summary.txt,
# records/preflight/ (raw outputs), and state/egress.env (COMPUTE_INTERNET=yes|no|unknown,
# read by data-prep/05_annotation.sh). Exit 1 if any check FAILs.
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
DO_SRUN=1
[ "${1:-}" = "--no-srun" ] && DO_SRUN=0
kit_dirs
R=$RECORDS/preflight; mkdir -p "$R"
ROWS_TSV=$RECORDS/preflight.tsv
printf 'check\tstatus\tdetail\n' > "$ROWS_TSV"
section() { printf '\n== %s ==\n' "$1" >&2; }
T0=$(date +%s)
kit_log "preflight: user $(id -un), host $(hostname), PREP_DIR $PREP_DIR"

# Run a command string in a fresh child bash with Lmod available; optional purge first.
# Output: stdout+stderr of the commands. Status: the commands' status.
# shellcheck disable=SC2016  # expanded by the child bash that runs it, not here
MODINIT='type module >/dev/null 2>&1 || { if [ -n "${LMOD_PKG:-}" ]; then source "$LMOD_PKG/init/bash"; else source /etc/profile.d/lmod.sh; fi; } >/dev/null 2>&1'
in_mod() {  # purge(0|1) commands
  local p=""; [ "$1" = 1 ] && p="module --force purge >/dev/null 2>&1;"
  timeout 300 bash --noprofile --norc -c "$MODINIT; $p module load biocontainers >/dev/null 2>&1; $2" 2>&1
}

# ---------------------------------------------------------------- environment
section "Environment"
for t in sbatch sacct sacctmgr squeue srun sinfo curl python3 md5sum timeout; do
  if command -v "$t" >/dev/null 2>&1; then kit_row PASS "command $t" "$(command -v "$t")"; else kit_row FAIL "command $t" "not found"; fi
done
if python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)' 2>/dev/null; then
  kit_row PASS "python3 >= 3.6" "$(python3 --version 2>&1)"; else kit_row FAIL "python3 >= 3.6" "$(python3 --version 2>&1 || true)"; fi
case "${SCRATCH:-}" in
  /scratch/negishi/"$(id -un)") kit_row PASS "\$SCRATCH" "$SCRATCH";;
  "") kit_row FAIL "\$SCRATCH" "unset; the lesson uses \$SCRATCH everywhere";;
  *) kit_row WARN "\$SCRATCH" "$SCRATCH (expected /scratch/negishi/$(id -un))";;
esac
kit_row INFO "\$RCAC_SCRATCH" "${RCAC_SCRATCH:-unset} (not used by the lesson)"
kit_row INFO "PREP_DIR" "$PREP_DIR"
if [ -n "$KIT_ACCOUNT" ]; then kit_row PASS "KIT_ACCOUNT set" "$KIT_ACCOUNT"; else kit_row FAIL "KIT_ACCOUNT set" "empty; set it in config.sh or the environment"; fi
APP=$(command -v apptainer || command -v singularity || true)
if [ -n "$APP" ]; then kit_row PASS "apptainer/singularity" "$APP: $("$APP" --version 2>&1 | head -1)"; else kit_row WARN "apptainer/singularity" "not on PATH (needed only for the SnpEff config check)"; fi
if bash --noprofile --norc -c 'type module' >/dev/null 2>&1; then kit_row PASS "module function exported" "available in a non-login child shell"
else kit_row INFO "module function" "not exported; scripts source Lmod's init file"; fi

# ---------------------------------------------------------------- modules
section "Modules (available versions, default, pinned version loads and runs)"
declare -A VCMD=(
  [bwa]='bwa 2>&1 | grep -m1 -i version'
  [samtools]='samtools --version | head -1'
  [bcftools]='bcftools --version | head -1'
  [htslib]='tabix --version 2>&1 | head -1; bgzip --version 2>&1 | head -1'
  [mosdepth]='mosdepth --version'
  [hap.py]='hap.py --version 2>&1 | tail -1'
  [snpeff]='snpEff -version 2>&1 | head -1'
  [snpsift]='SnpSift 2>&1 | grep -m1 -i version'
  [fastqc]='fastqc --version'
  [multiqc]='multiqc --version'
)
{ kit_pilot_header; printf 'module\tpinned\tdefault\tavailable\tversion_output\n'; } > "$R/modules.tsv"
for var in BWA_MODULE SAMTOOLS_MODULE BCFTOOLS_MODULE HTSLIB_MODULE MOSDEPTH_MODULE HAPPY_MODULE SNPEFF_MODULE SNPSIFT_MODULE FASTQC_MODULE MULTIQC_MODULE IGV_MODULE; do
  mv=${!var}; tool=${mv%%/*}
  avail=$(in_mod 1 "module -t avail $tool 2>&1 | grep -E '^$tool/' | tr '\n' ' '" || true)
  def=$(in_mod 1 "module load $tool >/dev/null 2>&1 && module -t list 2>&1 | grep -E '^$tool/' | head -1" || echo none)
  if [ "$tool" = igv ]; then
    if printf '%s' "$avail" | grep -qw "$mv"; then kit_row PASS "module $mv" "available (launch checked in docs/ood_igv_check.md); default ${def:-none}"
    else kit_row WARN "module $mv" "not available; installed: ${avail:-none}"; fi
    printf '%s\t%s\t%s\t%s\t-\n' "$tool" "$mv" "${def:-none}" "$avail" >> "$R/modules.tsv"
    continue
  fi
  vout=$(in_mod 1 "module load $mv >/dev/null 2>&1 || { echo LOADFAIL; exit 3; }; ${VCMD[$tool]}" | grep -viE 'warning|^$' | tr '\n' ' ' || true)
  printf '%s\t%s\t%s\t%s\t%s\n' "$tool" "$mv" "${def:-none}" "$avail" "$vout" >> "$R/modules.tsv"
  case "$vout" in
    *LOADFAIL*) kit_row FAIL "module $mv" "does not load; available: ${avail:-none}";;
    "") kit_row WARN "module $mv" "loads but printed no version; default ${def:-none}";;
    *) kit_row PASS "module $mv" "$vout; default ${def:-none}";;
  esac
done
for m in $BCFTOOLS_COMPARE_MODULES; do
  if in_mod 1 "module load $m >/dev/null 2>&1" >/dev/null; then kit_row INFO "compare module $m" "installed; p-call-vcmp uses it"
  else kit_row INFO "compare module $m" "not installed; p-call-vcmp skips it"; fi
done

# ---------------------------------------------------------------- module --force purge
section "module --force purge before module load biocontainers"
for p in 0 1; do
  t0=$(date +%s%N)
  out=$(in_mod "$p" "module load $SAMTOOLS_MODULE >/dev/null 2>&1; samtools --version | head -1; echo rc=\$?" || true)
  ms=$(( ($(date +%s%N) - t0) / 1000000 ))
  printf 'purge=%s ms=%s\n%s\n\n' "$p" "$ms" "$out" >> "$R/purge_compare.txt"
  if printf '%s' "$out" | grep -qiE 'LD_PRELOAD|xalt|GLIBC'; then kit_row WARN "samtools startup, purge=$p" "${ms} ms; loader messages (see preflight/purge_compare.txt)"
  else kit_row PASS "samtools startup, purge=$p" "${ms} ms; $(printf '%s' "$out" | head -1)"; fi
done
kit_row INFO "LD_PRELOAD on the login node" "${LD_PRELOAD:-unset}"

# ---------------------------------------------------------------- bcftools plugins and htslib tools
section "bcftools plugins, bgzip and tabix"
in_mod 1 "module load $BCFTOOLS_MODULE >/dev/null 2>&1; bcftools plugin -l" > "$R/bcftools_plugins.txt" || true
in_mod 1 "module load $BCFTOOLS_MODULE >/dev/null 2>&1; bcftools +mendelian2 -h" > "$R/bcftools_mendelian2_help.txt" || true
for pl in mendelian2 fill-tags split-vep trio-dnm3; do
  if grep -qE "(^|[^a-z0-9-])$pl([^a-z0-9-]|$)" "$R/bcftools_plugins.txt"; then
    kit_row PASS "bcftools plugin $pl" "$BCFTOOLS_MODULE"
  else kit_row FAIL "bcftools plugin $pl" "not listed by bcftools plugin -l (see preflight/bcftools_plugins.txt)"; fi
done
for t in bgzip tabix; do
  a=$(in_mod 1 "module load $BCFTOOLS_MODULE >/dev/null 2>&1; type -t $t || echo absent" | tail -1)
  b=$(in_mod 1 "module load $HTSLIB_MODULE >/dev/null 2>&1; type -t $t || echo absent" | tail -1)
  if [ "$b" != absent ]; then kit_row PASS "$t from $HTSLIB_MODULE" "with $BCFTOOLS_MODULE alone: $a"
  else kit_row FAIL "$t from $HTSLIB_MODULE" "not provided"; fi
done

# ---------------------------------------------------------------- hap.py engines on a synthetic pair
section "hap.py engines (synthetic 2 kb contig)"
H=$PREP_DIR/preflight/happy_test; rm -rf "$H"; mkdir -p "$H"
python3 - "$H" <<'PY'
import random, sys
d = sys.argv[1]
random.seed(1)
seq = "".join(random.choice("ACGT") for _ in range(2000))
open(d + "/tiny.fa", "w").write(">chrT\n" + seq + "\n")
open(d + "/tiny.fa.fai", "w").write("chrT\t2000\t6\t2000\t2001\n")
alt = {"A": "G", "C": "T", "G": "A", "T": "C"}
def vcf(path, positions):
    with open(path, "w") as f:
        f.write("##fileformat=VCFv4.2\n##contig=<ID=chrT,length=2000>\n")
        f.write('##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">\n')
        f.write("#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tS\n")
        for p in positions:
            r = seq[p - 1]
            f.write("chrT\t%d\t.\t%s\t%s\t50\tPASS\t.\tGT\t0/1\n" % (p, r, alt[r]))
vcf(d + "/truth.vcf", [500, 1000])
vcf(d + "/query.vcf", [500, 1000, 1500])
open(d + "/conf.bed", "w").write("chrT\t0\t2000\n")
PY
for e in xcmp vcfeval; do
  o=$(in_mod 1 "module load $HAPPY_MODULE >/dev/null 2>&1; cd '$H' && hap.py truth.vcf query.vcf -f conf.bed -r tiny.fa -o out_$e --engine $e; echo rc=\$?" || true)
  printf '%s\n' "$o" > "$R/happy_$e.log"
  if [ -s "$H/out_$e.summary.csv" ]; then kit_row PASS "hap.py --engine $e" "summary.csv written ($(grep -c . "$H/out_$e.summary.csv") lines)"
  elif [ "$e" = vcfeval ]; then kit_row WARN "hap.py --engine $e" "failed (see preflight/happy_vcfeval.log); evaluations use xcmp"
  else kit_row FAIL "hap.py --engine $e" "failed (see preflight/happy_xcmp.log)"; fi
done
cp "$H"/out_*.summary.csv "$R/" 2>/dev/null || true
# vcfeval with an RTG SDF template, built with the rtg that hap.py itself calls, run through the
# hap.py module's own container command (its binds and options), as stage-build does
APPX=$(command -v apptainer || command -v singularity || true)
cat > "$H/rtg_test.sh" <<'T'
source "$KIT_DIR/lib.sh" >/dev/null 2>&1
module load "$HAPPY_MODULE" >/dev/null 2>&1
pre=$(kit_wrapper_prefix hap.py); echo "PREFIX=$pre"
r=$(kit_happy_rtg "$pre"); echo "RTG=$r"
[ -n "$pre" ] && [ -n "$r" ] || exit 0
cd "$H" && rm -rf tiny.sdf
if w=$(kit_rtg_format "$pre" "$r" "$H/tiny.sdf" "$H/tiny.fa" 1g "$H/rtg_attempts.log"); then echo "RC=0"; echo "WAY=$w"
else echo "RC=1"; grep -iE 'unable|error|exception|not found' "$H/rtg_attempts.log" | tail -2; fi
T
o=$(in_mod 1 "export KIT_DIR='$KIT_DIR' HAPPY_MODULE='$HAPPY_MODULE' H='$H'; source '$H/rtg_test.sh'" || true)
printf '%s\n' "$o" > "$R/happy_rtg.txt"
cat "$H/rtg_attempts.log" >> "$R/happy_rtg.txt" 2>/dev/null || true
HPRE=$(printf '%s\n' "$o" | sed -n 's/^PREFIX=//p'); RTGP=$(printf '%s\n' "$o" | sed -n 's/^RTG=//p')
if [ -z "$HPRE" ]; then kit_row FAIL "hap.py container command" "no singularity/apptainer ... .sif in the hap.py wrapper (see preflight/happy_rtg.txt)"
elif [ -z "$RTGP" ]; then kit_row FAIL "rtg in the hap.py image" "not found (see preflight/happy_rtg.txt)"
elif ! printf '%s\n' "$o" | grep -qx 'RC=0'; then
  kit_row FAIL "rtg format in the hap.py image" "$RTGP, 4 ways tried: $(printf '%s\n' "$o" | grep -v -E '^(PREFIX|RTG|RC|WAY)=' | tail -2 | tr '\n' ' ') (see preflight/happy_rtg.txt)"
else
  kit_row PASS "rtg format in the hap.py image" "$RTGP, way $(printf '%s\n' "$o" | sed -n 's/^WAY=//p') of kit_rtg_format (see preflight/happy_rtg.txt)"
  o=$(in_mod 1 "module load $HAPPY_MODULE >/dev/null 2>&1; cd '$H' && hap.py truth.vcf query.vcf -f conf.bed -r tiny.fa -o out_tmpl --engine vcfeval --engine-vcfeval-template tiny.sdf; echo rc=\$?" || true)
  printf '%s\n' "$o" > "$R/happy_vcfeval_template.log"
  if [ -s "$H/out_tmpl.summary.csv" ]; then kit_row PASS "hap.py vcfeval with SDF template" "summary.csv written"
  else kit_row FAIL "hap.py vcfeval with SDF template" "failed (see preflight/happy_vcfeval_template.log)"; fi
fi

# ---------------------------------------------------------------- argument quoting through module wrappers
section "Argument quoting (each module must pass quotes, tabs and backslashes through unchanged)"
Q=$H/quote; mkdir -p "$Q"
python3 - "$Q" "$H" <<'PY'
import sys
q, h = sys.argv[1], sys.argv[2]
seq = open(h + "/tiny.fa").read().split("\n")[1]
open(q + "/tiny.sam", "w").write("@SQ\tSN:chrT\tLN:2000\n" + "".join(
    "r%d\t0\tchrT\t%d\t60\t50M\t*\t0\t0\t%s\t%s\n" % (i, p, seq[p - 1:p + 49], "I" * 50) for i, p in enumerate((100, 300))))
open(q + "/reads.fq", "w").write("@r1\n%s\n+\n%s\n" % (seq[200:270], "I" * 70))
PY
cp "$H/tiny.fa" "$Q/tiny.fa"
# Each test is sourced in a shell with the module loaded, typed exactly as an episode would show it.
cat > "$Q/bcftools_i.sh" <<'T'
echo "RESULT=$(bcftools view -H -i 'TYPE="snp"' query.vcf | wc -l)"
T
cat > "$Q/bcftools_query.sh" <<'T'
echo "RESULT=$(bcftools query -f '%CHROM\t%POS\n' query.vcf | head -1 | awk -F'\t' '{ print NF }')"
T
cat > "$Q/samtools_e.sh" <<'T'
echo "RESULT=$(samtools view -c -e 'rname=="chrT"' tiny.sam)"
T
cat > "$Q/snpsift_filter.sh" <<'T'
echo "RESULT=$(SnpSift filter "(CHROM = 'chrT')" query.vcf | grep -vc '^#')"
T
cat > "$Q/bwa_rg.sh" <<'T'
bwa index tiny.fa >/dev/null 2>&1
echo "RESULT=$(bwa mem -R '@RG\tID:t\tSM:t' tiny.fa reads.fq 2>/dev/null | awk -F'\t' '$1 == "@RG" { print NF ":" $2 ":" $3 }')"
T
cp "$H/query.vcf" "$Q/"
qtest() {  # label module test_file expected
  local o; o=$(in_mod 1 "module load $2 >/dev/null 2>&1 || { echo LOADFAIL; exit 3; }; cd '$Q' && source '$Q/$3'" || true)
  printf '== %s (%s)\n%s\n' "$1" "$2" "$o" >> "$R/quoting.txt"
  local got; got=$(printf '%s\n' "$o" | sed -n 's/^RESULT=//p' | tail -1)
  if [ "$got" = "$4" ]; then kit_row PASS "quoting: $1" "$2"
  else kit_row FAIL "quoting: $1" "$2 gave '${got:-nothing}', expected '$4' (see preflight/quoting.txt)"; fi
}
: > "$R/quoting.txt"
qtest "bcftools view -i 'TYPE=\"snp\"'" "$BCFTOOLS_MODULE" bcftools_i.sh 3
qtest "bcftools query -f '%CHROM\\t%POS\\n'" "$BCFTOOLS_MODULE" bcftools_query.sh 2
qtest "samtools view -e 'rname==\"chrT\"'" "$SAMTOOLS_MODULE" samtools_e.sh 2
qtest "SnpSift filter \"(CHROM = 'chrT')\"" "$SNPSIFT_MODULE" snpsift_filter.sh 3
qtest "bwa mem -R '@RG\\tID:t\\tSM:t'" "$BWA_MODULE" bwa_rg.sh "3:ID:t:SM:t"
for m in BWA_MODULE SAMTOOLS_MODULE BCFTOOLS_MODULE HTSLIB_MODULE HAPPY_MODULE SNPEFF_MODULE SNPSIFT_MODULE MOSDEPTH_MODULE FASTQC_MODULE MULTIQC_MODULE; do
  t=${!m%%/*}; c=$t; case $t in snpeff) c=snpEff;; snpsift) c=SnpSift;; htslib) c=tabix;; esac
  w=$(in_mod 1 "module load ${!m} >/dev/null 2>&1; type $c 2>&1 | grep -oE 'singularity (run|exec)|apptainer (run|exec)' | head -1" | tail -1 || true)
  printf '%s\t%s\n' "${!m}" "${w:-unknown}" >> "$R/wrapper_kind.tsv"
  case "$w" in *run) kit_row FAIL "wrapper ${!m}" "uses '$w' (drops embedded quotes); switch to exec";;
    *exec) kit_row PASS "wrapper ${!m}" "$w";; *) kit_row INFO "wrapper ${!m}" "not a shell function with singularity/apptainer (see quoting tests)";; esac
done

# ---------------------------------------------------------------- SnpEff
section "SnpEff"
in_mod 1 "module load $SNPEFF_MODULE >/dev/null 2>&1; snpEff -Xmx2g databases" > "$R/snpeff_databases.txt" || true
grep -E '^[[:space:]]*GRCh38' "$R/snpeff_databases.txt" > "$R/snpeff_databases_GRCh38.txt" || true
kit_row INFO "SnpEff GRCh38 databases listed" "$(wc -l < "$R/snpeff_databases_GRCh38.txt")"
for db in $SNPEFF_DB_MANE $SNPEFF_DB_FULL; do
  if grep -qE "^[[:space:]]*${db//./\\.}[[:space:]]" "$R/snpeff_databases.txt"; then kit_row PASS "SnpEff database $db" "listed"
  else kit_row INFO "SnpEff database $db" "not listed"; fi
done
REPO_HOST=""
sif=$(in_mod 1 "module show $SNPEFF_MODULE" | grep -oE '/[^" ,)]+\.sif' | head -1 || true)
if [ -n "$sif" ] && [ -n "$APP" ] && [ -r "$sif" ]; then
  # shellcheck disable=SC2016  # expanded inside the container
  "$APP" exec "$sif" sh -c 'c=$(find /usr/local/share /opt -name snpEff.config 2>/dev/null | head -1); echo "config: $c"; grep -E "^[[:space:]]*database.repository" "$c"' > "$R/snpeff_config_repository.txt" 2>&1 || true
  REPO_HOST=$(grep -oE 'https?://[^/[:space:]]+' "$R/snpeff_config_repository.txt" | head -1 || true)
  if [ -n "$REPO_HOST" ]; then kit_row PASS "SnpEff database repository" "$(grep -m1 repository "$R/snpeff_config_repository.txt" | tr -s ' ')"
  else kit_row WARN "SnpEff database repository" "not found in the container config (see preflight/snpeff_config_repository.txt)"; fi
else
  kit_row WARN "SnpEff database repository" "SIF not found from 'module show $SNPEFF_MODULE'"
fi
# Heap: a 1 MB heap must make the JVM fail if the setting reaches it
o=$(in_mod 1 "module load $SNPEFF_MODULE >/dev/null 2>&1; snpEff -Xmx1m -version; echo rc=\$?" || true)
printf '%s\n' "$o" > "$R/snpeff_heap_flag.txt"
if printf '%s' "$o" | grep -qiE 'heap|OutOfMemory|Could not create the Java'; then kit_row PASS "SnpEff heap via -Xmx flag" "reaches the JVM (jobs use snpEff -Xmx<N>m)"
else kit_row FAIL "SnpEff heap via -Xmx flag" "ignored by the wrapper (see preflight/snpeff_heap_flag.txt)"; fi
o=$(in_mod 1 "module load $SNPEFF_MODULE >/dev/null 2>&1; _JAVA_OPTIONS=-Xmx1m snpEff -version; echo rc=\$?" || true)
printf '%s\n' "$o" > "$R/snpeff_heap_env.txt"
if printf '%s' "$o" | grep -qiE 'heap|OutOfMemory|Could not create the Java'; then kit_row PASS "SnpEff heap via _JAVA_OPTIONS" "reaches the JVM"
else kit_row INFO "SnpEff heap via _JAVA_OPTIONS" "not passed into the container"; fi

# ---------------------------------------------------------------- SLURM
section "SLURM"
sacctmgr -nP show assoc where user="$(id -un)" format=account,partition,qos > "$R/sacctmgr_assoc.txt" 2>&1 || true
if [ -n "$KIT_ACCOUNT" ]; then
  a=$(grep -i "^$KIT_ACCOUNT|" "$R/sacctmgr_assoc.txt" || true)
  if [ -n "$a" ]; then kit_row PASS "association $KIT_ACCOUNT" "$(printf '%s' "$a" | tr '\n' ' ')"
  else kit_row FAIL "association $KIT_ACCOUNT" "no association for $(id -un)"; fi
  if printf '%s' "$a" | grep -qw "$KIT_QOS"; then kit_row PASS "QoS $KIT_QOS on $KIT_ACCOUNT" ""
  else kit_row FAIL "QoS $KIT_QOS on $KIT_ACCOUNT" "not in the association"; fi
fi
sacctmgr -nP show qos "$KIT_QOS" format=name,maxwall,maxtrespu,maxjobspu,maxsubmitpu > "$R/qos_$KIT_QOS.txt" 2>&1 || true
kit_row INFO "QoS $KIT_QOS limits" "$(head -1 "$R/qos_$KIT_QOS.txt")"
sinfo -h -p "$KIT_PARTITION" -o '%P %l %D %c %m' > "$R/sinfo_$KIT_PARTITION.txt" 2>&1 || true
kit_row INFO "partition $KIT_PARTITION" "$(head -1 "$R/sinfo_$KIT_PARTITION.txt") (partition, timelimit, nodes, cpus, memory MB)"
if [ -n "$KIT_ACCOUNT" ]; then
  testjob() {  # name script [cores] [array]
    local a=(--test-only "--account=$KIT_ACCOUNT" "--partition=$KIT_PARTITION" "--qos=$KIT_QOS" "--job-name=$1" -o /dev/null)
    [ -n "${3:-}" ] && a+=("--cpus-per-task=$3")
    [ -n "${4:-}" ] && a+=("--array=$4")
    local r; r=$(sbatch "${a[@]}" "$2" 2>&1 | tail -1) || true
    case "$r" in *"to start at"*) kit_row PASS "sbatch --test-only $1" "${r#sbatch: }";; *) kit_row FAIL "sbatch --test-only $1" "$r";; esac
  }
  testjob stage-build "$KIT_DIR/jobs/stage-build.sh"
  PJ=$REPO_DIR/pipeline/jobs
  for j in session fork det-compare metrics report anchors; do testjob "$j" "$PJ/$j.sh"; done
  # learner scripts: their own headers decide account, QoS, partition, cores and array
  for f in "$REPO_DIR"/pipeline/learner-scripts/*.sh; do
    r=$(sbatch --test-only -o /dev/null "$f" 2>&1 | tail -1) || true
    case "$r" in *"to start at"*) kit_row PASS "sbatch --test-only $(basename "$f")" "${r#sbatch: }";; *) kit_row FAIL "sbatch --test-only $(basename "$f")" "$r";; esac
  done
fi
# the account appears only in config.sh and the learner script headers; they must agree
for f in "$REPO_DIR"/pipeline/learner-scripts/*.sh; do
  acct=$(sed -n 's/^#SBATCH --account=//p' "$f")
  if [ "$acct" = "$KIT_ACCOUNT" ]; then kit_row PASS "account in $(basename "$f")" "$acct"; else kit_row FAIL "account in $(basename "$f")" "'$acct', config.sh has '$KIT_ACCOUNT'"; fi
done
for f in "$REPO_DIR"/pipeline/learner-scripts/interactive/*.sh; do
  l=$(grep -m1 '^sinteractive ' "$f" || true); [ -n "$l" ] || continue
  case "$l" in *"-A $KIT_ACCOUNT "*) kit_row PASS "account in $(basename "$f")" "$KIT_ACCOUNT";; *) kit_row FAIL "account in $(basename "$f")" "$l";; esac
done

# ---------------------------------------------------------------- storage (read only)
section "Storage (read only)"
kit_row INFO "scratch free" "$(df -h --output=size,used,avail,target "${SCRATCH:-$PREP_DIR}" 2>/dev/null | tail -1 | tr -s ' ')"
if command -v myquota >/dev/null 2>&1; then myquota > "$R/myquota.txt" 2>&1 || true; kit_row INFO "myquota" "see preflight/myquota.txt"
else kit_row INFO "myquota" "not available"; fi
if [ -d /depot/workshop/data ]; then
  kit_row PASS "/depot/workshop/data exists" "$(stat -c '%A %U:%G' /depot/workshop/data)"
  kit_row INFO "/depot/workshop/data free" "$(df -h --output=size,used,avail,target /depot/workshop/data 2>/dev/null | tail -1 | tr -s ' ')"
  # containers must see Depot: learners' ref/ links point there and every tool reads through them
  BSIF=$(in_mod 1 "module load $BCFTOOLS_MODULE >/dev/null 2>&1; type bcftools" | grep -oE '/[^ "]+\.sif' | head -1 || true)
  if [ -n "$BSIF" ] && [ -n "$APPX" ] && "$APPX" exec "$BSIF" ls -d /depot/workshop/data >/dev/null 2>&1; then
    kit_row PASS "Depot visible inside containers" "$(basename "$BSIF")"
  else kit_row FAIL "Depot visible inside containers" "could not list /depot/workshop/data inside ${BSIF:-the bcftools image}"; fi
  for which in learner ref; do
    case $which in learner) d=$STAGED; a=();; ref) d=$STAGED_REF; a=(--ref);; esac
    if [ ! -e "$d" ]; then kit_row WARN "staged copy $d" "not there yet (restage.sh --build, then --install)"; continue; fi
    if bash "$KIT_DIR/check_staged.sh" "$d" "${a[@]}" --quick > "$R/check_staged_$which.txt" 2>&1; then
      kit_row PASS "staged copy $d" "check_staged.sh --quick: $(tail -1 "$R/check_staged_$which.txt")"
    else kit_row FAIL "staged copy $d" "$(tail -1 "$R/check_staged_$which.txt") (see preflight/check_staged_$which.txt)"; fi
  done
  if [ -e "$STAGED_RESULTS" ]; then kit_row INFO "$STAGED_RESULTS" "exists ($(stat -c '%A %U:%G' "$STAGED_RESULTS"))"
  else kit_row INFO "$STAGED_RESULTS" "does not exist yet (Part D)"; fi
else kit_row WARN "/depot/workshop/data exists" "not visible from this node"; fi
kit_row INFO "groups" "$(id -Gn)"

# ---------------------------------------------------------------- internet
# One file URL per host from sources.tsv, plus the SnpEff repository host from the container config.
URLS=$(awk -F'\t' 'NR > 1 && $2 ~ /^https?:/ && $2 !~ /\/$/ { split($2, a, "/"); if (!(a[3] in s)) { s[a[3]] = 1; print $2 } }' "$SOURCES_TSV")
[ -n "$REPO_HOST" ] && URLS="$URLS"$'\n'"$REPO_HOST/"
# shellcheck disable=SC2016  # expanded by the bash that runs the probe
PROBE='for u in "$@"; do printf "%s %s\n" "$(curl -s -o /dev/null -r 0-0 -L --max-time 30 -w "%{http_code}" "$u" || echo 000)" "$u"; done'
probe_rows() {  # where output
  local where=$1 code url ok=yes
  while read -r code url; do
    [ -n "$url" ] || continue
    # any HTTP answer shows the host is reachable; 000 means no connection
    case "$code" in 2??|3??|4??) kit_row PASS "internet $where $(printf '%s' "$url" | cut -d/ -f3)" "HTTP $code";;
      *) kit_row WARN "internet $where $(printf '%s' "$url" | cut -d/ -f3)" "HTTP $code $url"; ok=no;; esac
  done <<< "$2"
  echo "$ok"
}
section "Internet from the login node"
# shellcheck disable=SC2086  # URLS is a newline-separated list of URLs without spaces
lo=$(bash -c "$PROBE" _ $URLS 2>&1 || true)
printf '%s\n' "$lo" > "$R/internet_login.txt"
probe_rows login "$lo" > /dev/null

section "Compute node (one standby job, at most 10 minutes, waits at most 8 minutes to start)"
COMPUTE_INTERNET=unknown
if [ $DO_SRUN = 1 ] && [ -n "$KIT_ACCOUNT" ]; then
  CP=$PREP_DIR/preflight/compute_probe.sh
  {
    printf '#!/bin/bash\n# generated by 00_preflight.sh: network and module startup on a compute node\n'
    printf 'MODINIT=%q\nSAMTOOLS_MODULE=%q\nPROBE=%q\n' "$MODINIT" "$SAMTOOLS_MODULE" "$PROBE"
    cat <<'PROBE_EOF'
bash -c "$PROBE" _ "$@"
echo "### host=$(hostname) TMPDIR=${TMPDIR:-unset} LD_PRELOAD=${LD_PRELOAD:-unset}"
for p in 0 1; do
  pre=""; [ $p = 1 ] && pre="module --force purge >/dev/null 2>&1;"
  t0=$(date +%s%N)
  o=$(bash --noprofile --norc -c "$MODINIT; $pre module load biocontainers >/dev/null 2>&1; module load $SAMTOOLS_MODULE >/dev/null 2>&1; samtools --version | head -1" 2>&1)
  echo "### purge=$p ms=$(( ($(date +%s%N) - t0) / 1000000 )) $(printf '%s' "$o" | tr '\n' ' ')"
done
PROBE_EOF
  } > "$CP"
  # shellcheck disable=SC2086  # URLS is a newline-separated list of URLs without spaces
  co=$(timeout 480 srun -A "$KIT_ACCOUNT" -q "$KIT_QOS" -p "$KIT_PARTITION" -N1 -n1 -c1 -t 00:10:00 --job-name=p2-preflight \
       bash "$CP" $URLS 2>&1 || true)
  printf '%s\n' "$co" > "$R/compute_node.txt"
  if printf '%s' "$co" | grep -qE '^[0-9]{3} '; then
    COMPUTE_INTERNET=$(probe_rows compute "$(printf '%s\n' "$co" | grep -E '^[0-9]{3} ')" | tail -1)
    while read -r l; do kit_row INFO "compute node" "${l#\#\#\# }"; done < <(grep '^### ' "$R/compute_node.txt" || true)
  else
    kit_row WARN "compute-node job" "did not start or failed within 8 minutes: $(printf '%s' "$co" | tail -1)"
  fi
else
  kit_row WARN "compute-node job" "skipped (--no-srun or KIT_ACCOUNT empty)"
fi
printf 'COMPUTE_INTERNET=%s\n' "$COMPUTE_INTERNET" > "$STATE/egress.env"
kit_row INFO "compute-node internet" "$COMPUTE_INTERNET (05_annotation.sh downloads on the $( [ "$COMPUTE_INTERNET" = yes ] && echo compute || echo login ) node)"

section "Result"
# count from the table: some rows are written from subshells
NF=$(awk -F'\t' 'NR > 1 && $2 == "FAIL"' "$ROWS_TSV" | wc -l)
NW=$(awk -F'\t' 'NR > 1 && $2 == "WARN"' "$ROWS_TSV" | wc -l)
{
  printf 'Preflight, %s, user %s, host %s, %s s\n' "$(kit_ts)" "$(id -un)" "$(hostname)" "$(( $(date +%s) - T0 ))"
  printf 'FAIL %d, WARN %d\n\n' "$NF" "$NW"
  awk -F'\t' 'NR > 1 && ($2 == "FAIL" || $2 == "WARN") { printf "%-5s %s: %s\n", $2, $1, $3 }' "$ROWS_TSV"
} | tee "$RECORDS/preflight_summary.txt" >&2
[ "$NF" -eq 0 ]
