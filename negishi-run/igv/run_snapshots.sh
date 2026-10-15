#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --account=rcac
#SBATCH --qos=standby
#SBATCH --partition=cpu
#SBATCH --time=00:20:00
#SBATCH --job-name=igv-snapshots
#SBATCH --output=cluster-%x.%j.out
#SBATCH --error=cluster-%x.%j.err
# run_snapshots.sh (Prompt 06b): render the Episode 8 IGV snapshots of a kit run without a desktop,
# under Xvfb in a standby job. KIT EXTRA: no learner command; writes only into the run directory.
# Usage, from the repository root (sbatch runs a spool copy, so KIT_DIR comes from the submit dir):
#   sbatch negishi-run/igv/run_snapshots.sh --run RUN_ID                  render the snapshots
#   sbatch negishi-run/igv/run_snapshots.sh --run RUN_ID --preflight-only checks only
#   IGV_MAKE_BAI=1 sbatch negishi-run/igv/run_snapshots.sh --run RUN_ID   with temporary .bai copies
# The batch is $RUN/igv/snapshots.batch (kitrun.sh kit_igv_batch, written by the 08-trio step).
# Pre-flight: xvfb-run on the host or in IGV_SIF; the batch shape (kit_igv_batch_check); the genome
# line is the learner's ref/GRCh38_no_alt.fa, resolves into STAGED_REF and matches
# staged_ref_manifest.tsv (size and md5, FASTA and .fai); every genome and load path, the .fai, a
# BAM index per BAM and a .tbi or .csi for the VCF exist inside the container (ls -lL); the index
# type of each BAM. IGV_MAKE_BAI=1 (decision 5, 2026-10-14; set only after a run shows IGV
# rejecting .csi): .bai copies made with samtools index -b in $RUN/igv/bai/, loaded through
# "load BAM index=BAI" (IGV batch documentation, https://igv.org/doc/desktop/UserGuide/tools/batch/)
# in a derived batch, and removed after the run; an existing index is never overwritten or removed.
# Records ($RUN/records/): igv_snapshots.tsv (check, status, detail), igv_run.log (IGV output),
# igv_version.txt. Exit 1 if any check FAILs. The desktop fallback: negishi-run/README.md, Phase 6.
set -euo pipefail

if [ -z "${KIT_DIR:-}" ]; then
  if [ -n "${SLURM_SUBMIT_DIR:-}" ] && [ -f "$SLURM_SUBMIT_DIR/negishi-run/kitrun.sh" ]; then KIT_DIR=$SLURM_SUBMIT_DIR/negishi-run
  elif [ -f "$(dirname "${BASH_SOURCE[0]}")/../kitrun.sh" ]; then KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  else echo "ERROR: cannot find negishi-run/; submit from the repository root or set KIT_DIR" >&2; exit 1; fi
fi
export KIT_DIR
# shellcheck source=negishi-run/config.sh
source "$KIT_DIR/config.sh"
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
# shellcheck source=negishi-run/kitrun.sh
source "$KIT_DIR/kitrun.sh"

RUN_ARG=${RUN:-}; ONLY_PRE=0
while [ $# -gt 0 ]; do
  case $1 in
    --run) RUN_ARG=${2:?--run needs a RUN_ID}; shift 2;;
    --preflight-only) ONLY_PRE=1; shift;;
    *) kit_die "unknown option $1 (usage: run_snapshots.sh --run RUN_ID [--preflight-only])";;
  esac
done
[ -n "$RUN_ARG" ] || kit_die "no run: pass --run RUN_ID"
RUN=$(kit_run_dir "$RUN_ARG")
export RUN
kit_load_run
IGV_DIR=$RUN/igv
BATCH=$IGV_DIR/snapshots.batch
REF_MANIFEST=${STAGED_REF_MANIFEST:-$KIT_DIR/staged_ref_manifest.tsv}
IGV_TIMEOUT=${IGV_TIMEOUT:-15m}
MIN_PNG_BYTES=${IGV_MIN_PNG_BYTES:-10240}   # a blank IGV window is a few kB; reads at 40x are far more
ROWS_TSV=$RECORDS/igv_snapshots.tsv
IGV_LOG=$RECORDS/igv_run.log
printf 'check\tstatus\tdetail\n' > "$ROWS_TSV"
NFAIL=0; NWARN=0
JOB=${SLURM_JOB_ID:-$$}
# Negishi compute $TMPDIR is node-wide /tmp: one directory per job, inside the run
export TMPDIR=$IGV_DIR/tmp.$JOB
mkdir -p "$TMPDIR"
START_MARK=$TMPDIR/start
: > "$START_MARK"
kit_row INFO "job" "${SLURM_JOB_ID:-none} on $(hostname), ${SLURM_CPUS_PER_TASK:-?} cores, account ${SLURM_JOB_ACCOUNT:-?}"
if [ -n "${SLURM_JOB_ACCOUNT:-}" ] && [ "$SLURM_JOB_ACCOUNT" != "$KIT_ACCOUNT" ]; then
  kit_row WARN "account" "job account $SLURM_JOB_ACCOUNT, config.sh KIT_ACCOUNT $KIT_ACCOUNT"
fi
kit_row INFO "run" "$RUN"
kit_row INFO "IGV_MAKE_BAI" "$IGV_MAKE_BAI"

# ---------------------------------------------------------------- temporary .bai copies
CREATED=()       # files this job created and has not removed yet; only these are ever removed
CREATED_ALL=()   # every file this job created (post-check: none may remain)
cleanup_bai() {
  local f
  for f in "${CREATED[@]+"${CREATED[@]}"}"; do
    if [ -e "$f" ]; then rm -f -- "$f" && kit_row INFO "removed" "$f"; fi
  done
  CREATED=()
  rmdir "$IGV_DIR/bai" 2> /dev/null || true
}
on_exit() { cleanup_bai; rm -rf -- "${TMPDIR:?}"; }
trap on_exit EXIT

sx() { singularity exec "$IGV_SIF" "$@"; }   # the igv module's igv.sh is a shell function; call the image directly

# ---------------------------------------------------------------- pre-flight
# image
if [ -r "$IGV_SIF" ]; then kit_row PASS "IGV_SIF readable" "$IGV_SIF"
else kit_row FAIL "IGV_SIF readable" "$IGV_SIF is missing or unreadable"; fi
command -v singularity > /dev/null 2>&1 || kit_row FAIL "singularity" "not on PATH"
# shellcheck disable=SC2016  # expanded inside the container
LAUNCHER=$(sx sh -c 'command -v igv.sh || { [ -x /opt/igv/igv.sh ] && echo /opt/igv/igv.sh; }' 2> /dev/null | tail -1 || true)
if [ -n "$LAUNCHER" ]; then kit_row PASS "IGV launcher in the image" "$LAUNCHER"
else kit_row FAIL "IGV launcher in the image" "neither igv.sh on PATH nor /opt/igv/igv.sh"; LAUNCHER=igv.sh; fi
# a. xvfb-run: host first, then the image
XVFB_MODE=none
if command -v xvfb-run > /dev/null 2>&1; then XVFB_MODE=host; kit_row PASS "xvfb-run" "host: $(command -v xvfb-run)"
elif x=$(sx sh -c 'command -v xvfb-run' 2> /dev/null | tail -1) && [ -n "$x" ]; then XVFB_MODE=image; kit_row PASS "xvfb-run" "image: $x"
else kit_row FAIL "xvfb-run" "not on the host or in $IGV_SIF; use the desktop fallback (negishi-run/README.md, Phase 6)"; fi

# the batch
if [ ! -s "$BATCH" ]; then
  kit_row FAIL "batch" "$BATCH is missing; the 08-trio step writes it (kitrun.sh kit_igv_batch)"
  kit_log "pre-flight: $NFAIL FAIL"; exit 1
fi
if chk=$(kit_igv_batch_check "$BATCH" 2>&1); then kit_row PASS "batch shape" "$BATCH"
else kit_row FAIL "batch shape" "$(printf '%s' "$chk" | tr '\n' ';')"; fi

# b. reference: the learner's ref/GRCh38_no_alt.fa, resolving into STAGED_REF, as in the manifest
GENOME=$(awk '$1 == "genome" { print $2; exit }' "$BATCH")
if [ "$GENOME" = "$W/ref/$REF_NAME.fa" ]; then kit_row PASS "genome line" "$GENOME"
else kit_row FAIL "genome line" "${GENOME:-none}, expected $W/ref/$REF_NAME.fa"; fi
manifest_row() {  # path relative to STAGED_REF -> "bytes md5"
  awk -F'\t' -v p="$1" '$1 == p && $2 == "file" { print $3, $4; exit }' "$REF_MANIFEST"
}
SREF=${STAGED_REF%/}; SREF_REAL=$(readlink -f "$SREF" 2> /dev/null || echo "$SREF")
for f in "$GENOME" "$GENOME.fai"; do
  r=$(readlink -f "$f" 2> /dev/null || true)
  case "$r" in
    "$SREF"/*) rel=${r#"$SREF"/};;
    "$SREF_REAL"/*) rel=${r#"$SREF_REAL"/};;
    *) kit_row FAIL "reference resolves" "$f -> ${r:-unresolved}, not inside $SREF/"; continue;;
  esac
  kit_row PASS "reference resolves" "$f -> $r"
  read -r mb mm <<< "$(manifest_row "$rel")" || true
  if [ -z "${mb:-}" ]; then kit_row FAIL "reference manifest" "$rel has no file row in $REF_MANIFEST"; continue; fi
  sz=$(stat -L -c %s "$r" 2> /dev/null || echo missing)
  if [ "$sz" != "$mb" ]; then kit_row FAIL "reference size" "$rel: $sz bytes, manifest $mb"; continue; fi
  if [ -n "${mm:-}" ] && [ "$mm" != - ]; then
    m=$(md5sum "$r" | cut -c1-32)
    if [ "$m" = "$mm" ]; then kit_row PASS "reference md5" "$rel: $sz bytes, md5 $m (manifest)"
    else kit_row FAIL "reference md5" "$rel: md5 $m, manifest $mm"; fi
  else kit_row PASS "reference size" "$rel: $sz bytes (manifest has no md5)"; fi
done

# c, d. every genome and load path, and their indexes, inside the container (resolves /depot links)
in_image() {  # label path
  local o
  if o=$(sx ls -lL "$2" 2>&1 | grep -v -iE 'SINGULARITY_BIND|APPTAINER_BIND' | tail -1) && [ -n "$o" ] && sx test -e "$2" 2> /dev/null; then
    kit_row PASS "$1" "$o"; return 0
  fi
  kit_row FAIL "$1" "not readable in the image: $2"; return 1
}
in_image "genome in image" "$GENOME" || true
in_image "genome .fai in image" "$GENOME.fai" || true
BAMS=()
while read -r c p rest; do
  [ "$c" = load ] || continue
  in_image "load in image" "$p" || continue
  case "$p" in
    *.bam)
      BAMS+=("$p"); t=""
      for ix in "$p.csi" "$p.bai" "${p%.bam}.bai"; do
        if sx test -e "$ix" 2> /dev/null; then t="$t ${ix##*.}:$ix"; fi
      done
      if [ -n "$t" ]; then kit_row PASS "BAM index" "$(basename "$p"):$t"
      else kit_row FAIL "BAM index" "no .csi or .bai for $p"; fi
      case "$t" in *csi:*) kit_row INFO "BAM index type" "$(basename "$p") csi";; *) kit_row INFO "BAM index type" "$(basename "$p") bai";; esac;;
    *.vcf.gz|*.bcf)
      if sx test -e "$p.tbi" 2> /dev/null; then kit_row PASS "VCF index" "$p.tbi"
      elif sx test -e "$p.csi" 2> /dev/null; then kit_row PASS "VCF index" "$p.csi"
      else kit_row FAIL "VCF index" "no .tbi or .csi for $p"; fi;;
  esac
  [ -z "${rest:-}" ] || kit_row INFO "load option" "$p $rest"
done < "$BATCH"
# e. the snapshot directory, inside this run only
SNAPDIR=$(awk '$1 == "snapshotDirectory" { print $2; exit }' "$BATCH")
case "$SNAPDIR" in
  "$IGV_DIR"/*) mkdir -p "$SNAPDIR"; kit_row PASS "snapshotDirectory" "$SNAPDIR";;
  *) kit_row FAIL "snapshotDirectory" "${SNAPDIR:-none} is not inside $IGV_DIR";;
esac

if [ "$NFAIL" -gt 0 ]; then kit_log "pre-flight: $NFAIL FAIL, $NWARN WARN; see $ROWS_TSV"; exit 1; fi
if [ "$ONLY_PRE" = 1 ]; then kit_log "pre-flight only: PASS ($NWARN WARN); see $ROWS_TSV"; exit 0; fi

# ---------------------------------------------------------------- temporary .bai copies (decision 5)
RUN_BATCH=$BATCH
if [ "$IGV_MAKE_BAI" = 1 ]; then
  BAIDIR=$IGV_DIR/bai
  mkdir -p "$BAIDIR"
  RUN_BATCH=$IGV_DIR/snapshots.bai.batch
  kit_load "$SAMTOOLS_MODULE" > /dev/null 2>&1
  cp "$BATCH" "$TMPDIR/batch"
  for b in "${BAMS[@]}"; do
    out=$BAIDIR/$(basename "$b").bai
    if [ -e "$out" ]; then kit_row FAIL "temporary .bai" "$out exists (not made by this job); left in place"; continue; fi
    if samtools index -b -@ "${SLURM_CPUS_PER_TASK:-4}" "$b" "$out"; then
      CREATED+=("$out"); CREATED_ALL+=("$out"); kit_row INFO "created" "$out"
      awk -v b="$b" -v i="$out" '$1 == "load" && $2 == b && NF == 2 { print "load " b " index=" i; next } { print }' \
        "$TMPDIR/batch" > "$TMPDIR/batch.new" && mv "$TMPDIR/batch.new" "$TMPDIR/batch"
    else kit_row FAIL "temporary .bai" "samtools index -b failed for $b"; fi
  done
  cp "$TMPDIR/batch" "$RUN_BATCH"
  if chk=$(kit_igv_batch_check "$RUN_BATCH" 2>&1); then kit_row PASS "derived batch shape" "$RUN_BATCH"
  else kit_row FAIL "derived batch shape" "$(printf '%s' "$chk" | tr '\n' ';')"; fi
  [ "$NFAIL" -eq 0 ] || { kit_log "temporary .bai: $NFAIL FAIL; see $ROWS_TSV"; exit 1; }
fi

# ---------------------------------------------------------------- render
SCREEN="-screen 0 $IGV_XVFB_SCREEN"
if [ "$XVFB_MODE" = host ]; then
  CMD=(timeout "$IGV_TIMEOUT" xvfb-run -a -s "$SCREEN" singularity exec "$IGV_SIF" "$LAUNCHER" -b "$RUN_BATCH")
else
  CMD=(timeout "$IGV_TIMEOUT" singularity exec "$IGV_SIF" xvfb-run -a -s "$SCREEN" "$LAUNCHER" -b "$RUN_BATCH")
fi
kit_row INFO "command" "${CMD[*]}"
rc=0
"${CMD[@]}" > "$IGV_LOG" 2>&1 || rc=$?
kit_row INFO "IGV exit status" "$rc"

# ---------------------------------------------------------------- post-checks
cleanup_bai
if [ "$rc" -eq 124 ]; then kit_row FAIL "timeout" "IGV did not finish within $IGV_TIMEOUT (see $IGV_LOG)"
elif [ "$rc" -ne 0 ]; then kit_row FAIL "IGV exit" "status $rc (see $IGV_LOG)"
else kit_row PASS "IGV exit" "status 0 within $IGV_TIMEOUT"; fi
if grep -q SEVERE "$IGV_LOG"; then kit_row FAIL "IGV log" "SEVERE: $(grep -m1 SEVERE "$IGV_LOG" | cut -c1-200)"
else kit_row PASS "IGV log" "no SEVERE line"; fi
if grep -iE 'index' "$IGV_LOG" | grep -qiE 'error|exception|could not|unable|unsupported'; then
  kit_row WARN "index messages" "$(grep -iE 'index' "$IGV_LOG" | grep -m1 -iE 'error|exception|could not|unable|unsupported' | cut -c1-200); if IGV rejects .csi, resubmit with IGV_MAKE_BAI=1"
fi
# the version line is in IGV's console output, else in its own log under the home directory
v=$(cat "$IGV_LOG" "$HOME"/igv/igv*.log 2> /dev/null | grep -m1 -oE 'IGV Version [^ ]+( [0-9/]+)?' || true)
if [ -n "$v" ]; then printf '%s\n' "$v" > "$RECORDS/igv_version.txt"; kit_row PASS "IGV version" "$v (image $IGV_SIF)"
else kit_row WARN "IGV version" "no 'IGV Version' line in $IGV_LOG"; fi
while read -r c name; do
  [ "$c" = snapshot ] || continue
  f=$SNAPDIR/$name
  if [ ! -s "$f" ]; then kit_row FAIL "snapshot" "$name missing"; continue; fi
  sz=$(stat -c %s "$f")
  if [ ! "$f" -nt "$START_MARK" ]; then kit_row FAIL "snapshot" "$name is older than this job"
  elif [ "$sz" -le "$MIN_PNG_BYTES" ]; then kit_row FAIL "snapshot" "$name is $sz bytes (minimum $MIN_PNG_BYTES)"
  else kit_row PASS "snapshot" "$name, $sz bytes; $(file -b "$f" | cut -c1-120)"; fi
done < "$RUN_BATCH"
left=""
for f in "${CREATED_ALL[@]+"${CREATED_ALL[@]}"}"; do if [ -e "$f" ]; then left="$left $f"; fi; done
if [ -n "$left" ]; then kit_row FAIL "temporary .bai removed" "still present:$left"
else kit_row PASS "temporary .bai removed" "${#CREATED_ALL[@]} created, none left"; fi

kit_log "igv snapshots: $NFAIL FAIL, $NWARN WARN; records in $ROWS_TSV, IGV output in $IGV_LOG"
[ "$NFAIL" -eq 0 ]
