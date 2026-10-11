# pipeline/lib.sh: reference-run helpers on top of negishi-run/lib.sh. Sourced, never executed.
# Needs RUN_ID. A run lives in $KIT_SCRATCH_BASE/runs/<RUN_ID>/ with one learner copy per call set
# (q0/ since G3; q20/ in the first run, each scratch/varcall-workshop) plus det/ for the determinism realignment; state/,
# records/ and logs/ there replace the phase-2 ones in $PREP_DIR.
# shellcheck shell=bash

PIPE_DIR=${PIPE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
KIT_DIR=${KIT_DIR:-$(cd "$PIPE_DIR/../negishi-run" && pwd)}
export PIPE_DIR KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
KIT_LABEL="reference run, not frozen"
[ -n "${RUN_ID:-}" ] || kit_die "RUN_ID is not set"
case "$KIT_SCRATCH_BASE" in /varcall-kit|"") kit_die "KIT_SCRATCH_BASE is empty; set SCRATCH";; esac
RUN=$KIT_SCRATCH_BASE/runs/$RUN_ID
case "$(readlink -m "$RUN")" in
  "$(readlink -m "$STAGED")"*|"$(readlink -m "$STAGED_REF")"*|"$(readlink -m "$STAGED_RESULTS")"*|/depot/*)
    kit_die "run directory $RUN is inside a staged copy or Depot";;
esac
STATE=$RUN/state; RECORDS=$RUN/records; LOGS=$RUN/logs
export RUN_ID RUN STATE RECORDS LOGS KIT_LABEL
# shellcheck disable=SC2034  # LS and COPIES are used by the scripts that source this file
LS=$PIPE_DIR/learner-scripts
# shellcheck disable=SC2034
COPIES="$REF_CALL_SETS"

copy_scratch() { echo "$RUN/$1/scratch"; }                # the SCRATCH a learner copy sees
work_dir() { echo "$RUN/$1/scratch/varcall-workshop"; }   # its varcall-workshop directory

# Done-ness: kit steps write markers; learner scripts are judged by their final outputs
# (each ends by writing an index, so a present index means the job got to its last command).
kit_step_done() {  # step
  local s=$1 cs w n
  case $s in
    align) w=$(work_dir q0); for n in $SAMPLES; do [ -s "$w/results/bam/$n.markdup.bam.csi" ] || return 1; done;;
    align-det) w=$(work_dir det); read -r n _ <<< "$SAMPLES"; [ -s "$w/results/bam/$n.markdup.bam.csi" ];;
    call-*) cs=${s#call-}; w=$(work_dir "$cs")
      for n in $(seq 1 "$CALL_CHUNKS"); do [ -s "$w/results/vcf/chunks/chunk$(printf '%02d' "$n").bcf.csi" ] || return 1; done;;
    eval-*) cs=${s#eval-}; w=$(work_dir "$cs")
      [ "$(find "$w/results/eval" -maxdepth 1 -name '*.filtered.summary.csv' 2>/dev/null | wc -l)" -ge 4 ];;
    annot-*) cs=${s#annot-}; [ -s "$(work_dir "$cs")/results/annot/trio.ann.vcf.gz.csi" ];;
    *) kit_is_done "$s";;
  esac
}

# The learner's shell: the block as typed, no strict mode, every failing command logged.
# The sinteractive line is not run (the kit job is the session); see docs/ADAPTATIONS.md.
run_block() {  # name block_file copy
  local name=$1 block=$2 copy=$3 sess log rc=0 nerr
  sess=$RUN/sessions/$name.sh; log=$RUN/logs/session-$name.${SLURM_JOB_ID:-$$}.log
  mkdir -p "$RUN/sessions" "$RUN/logs" "$RECORDS/console"
  {
    # No set -E: the trap must not fire inside module wrapper functions, where "tool | head"
    # shows the tool's SIGPIPE (141) although the pipeline succeeded. A failing function call
    # is still caught at the call site.
    # shellcheck disable=SC2016  # written into the session file, expanded there
    echo "trap 'echo \"### KIT-ERR rc=\$? line=\$LINENO cmd=\$BASH_COMMAND\" >&2' ERR"
    echo '# KIT EXTRA: Lmod in a non-login shell, as a learner terminal has it'
    # shellcheck disable=SC2016
    echo 'type module >/dev/null 2>&1 || { if [ -n "${LMOD_PKG:-}" ]; then source "$LMOD_PKG/init/bash"; else source /etc/profile.d/lmod.sh; fi; }'
    grep -v '^sinteractive ' "$block"
  } > "$sess"
  kit_log "session $name: $block in copy $copy"
  ( export SCRATCH; SCRATCH=$(copy_scratch "$copy"); cd "$SCRATCH" && bash --noprofile --norc "$sess" ) > "$log" 2>&1 || rc=$?
  cp "$log" "$RECORDS/console/session-$name.log"
  nerr=$(grep -c '^### KIT-ERR' "$log" || true)
  if [ "$rc" -ne 0 ] || [ "$nerr" -gt 0 ]; then
    kit_log "session $name: exit $rc, $nerr failed command(s); first: $(grep -m1 '^### KIT-ERR' "$log" || true)"
    return 1
  fi
}

# Resources of an interactive block, from its sinteractive line: "cores time" (default 1 00:30:00)
block_resources() {  # block_file
  local l c t
  l=$(grep -m1 '^sinteractive ' "$1" || true)
  c=$(printf '%s' "$l" | sed -nE 's/.* -n ([0-9]+).*/\1/p'); t=$(printf '%s' "$l" | sed -nE 's/.*--time=([0-9:]+).*/\1/p')
  echo "${c:-1} ${t:-00:30:00}"
}

# Account, QoS and partition of the block's sinteractive line must match config.sh
check_block_slurm() {  # block_file
  local l; l=$(grep -m1 '^sinteractive ' "$1" || true)
  [ -z "$l" ] && return 0
  case "$l" in *"-A $KIT_ACCOUNT "*"-q $KIT_QOS "*"-p $KIT_PARTITION "*) return 0;; esac
  kit_die "$1: sinteractive line does not use account $KIT_ACCOUNT, QoS $KIT_QOS, partition $KIT_PARTITION: $l"
}
