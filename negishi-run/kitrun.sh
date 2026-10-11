# negishi-run/kitrun.sh: helpers for the episode run kit (Prompt 04): submit_all.sh, the generated
# jobs in generated/jobs/ and collect.sh --run. Sourced, never executed. Needs RUN for every helper
# that works inside a run; submit_all.sh exports it to the jobs.
# A run lives in $KIT_RUNS/<RUN_ID>/ (config.sh): scratch/ is the learner's $SCRATCH (so the
# learner directory is scratch/varcall-workshop), home/ the directory a learner shell starts in,
# records/ what collect.sh brings back, markers/ step status, logs/ job and session logs.
# shellcheck shell=bash

KIT_DIR=${KIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
KIT_GEN=${KIT_GEN:-$KIT_DIR/generated}
export KIT_GEN KIT_RUNS

kit_run_dir() {  # RUN_ID or absolute path -> run directory
  case "$1" in /*) echo "$1";; *) echo "$KIT_RUNS/$1";; esac
}

# Refuse a run directory inside a staged copy, on Depot, or outside KIT_RUNS
kit_guard_run() {  # dir
  local r; r=$(readlink -m "$1")
  case "$r" in
    "$(readlink -m "$STAGED")"|"$(readlink -m "$STAGED")"/*|"$(readlink -m "$STAGED_REF")"/*|"$(readlink -m "$STAGED_RESULTS")"/*|/depot/*)
      kit_die "run directory $1 is inside a staged copy or on Depot";;
  esac
  case "$r" in
    "$(readlink -m "$KIT_RUNS")"/*) ;;
    *) [ "${KIT_ALLOW_ANY_ROOT:-0}" = 1 ] || kit_die "run directory $1 is not under KIT_RUNS=$KIT_RUNS";;
  esac
}

kit_init_run() {  # dir: a fresh run with its kit.env
  local run=$1
  kit_guard_run "$run"
  [ -e "$run/kit.env" ] && kit_die "$run already exists; use another RUN_ID"
  mkdir -p "$run"/{scratch,home,logs,markers,records/console,records/listings,records/multiqc_export}
  {
    printf 'RUN=%q\n' "$run"
    printf 'RUN_ID=%q\n' "$(basename "$run")"
    printf 'KIT_LEARNER_SCRATCH=%q\n' "$run/scratch"
    printf 'W=%q\n' "$run/scratch/varcall-workshop"
    printf 'KIT_HOME=%q\n' "$run/home"
    printf 'KIT_BUILT_FROM=%q\n' "$(sha256sum "$KIT_GEN/sources.sha256" | cut -c1-16)"
    printf 'KIT_STARTED=%q\n' "$(kit_ts)"
  } > "$run/kit.env"
}

kit_load_run() {
  : "${RUN:?RUN is not set}"
  [ -f "$RUN/kit.env" ] || kit_die "$RUN/kit.env is missing; start the run with submit_all.sh --run RUN_ID"
  # shellcheck source=/dev/null
  source "$RUN/kit.env"
  kit_guard_run "$RUN"
  # lib.sh's markers, records and logs live in the run, not in the phase-2 prep directory
  STATE=$RUN; RECORDS=$RUN/records; LOGS=$RUN/logs
  export RUN RUN_ID W KIT_LEARNER_SCRATCH KIT_HOME STATE RECORDS LOGS
}

# Done: a PASS marker; the learner's align.sh writes none, so its three indexes must be newer
# than the run (an index is the last thing each task writes)
kit_ep_done() {  # step
  local s
  case $1 in
    04-align)
      for s in $SAMPLES; do
        [ -s "$W/results/bam/$s.markdup.bam.csi" ] && [ "$W/results/bam/$s.markdup.bam.csi" -nt "$RUN/kit.env" ] || return 1
      done;;
    *) kit_is_done "$1";;
  esac
}

# Run a generated learner session in a child bash without -e, -u or pipefail, starting in the
# run's home/ as a fresh login would, with SCRATCH pointing at the run. Fails if any command failed.
kit_ep_session() {  # step
  local step=$1 log rc=0 nerr
  log=$LOGS/session-$step.${SLURM_JOB_ID:-login}.log
  kit_log "session $step: $KIT_GEN/sessions/$step.sh -> $log"
  ( cd "$KIT_HOME" && export SCRATCH="$KIT_LEARNER_SCRATCH" && bash --noprofile --norc "$KIT_GEN/sessions/$step.sh" ) > "$log" 2>&1 || rc=$?
  cp "$log" "$RECORDS/console/$step.log"
  nerr=$(grep -c '^### KIT-ERR' "$log" || true)
  if [ "$rc" -ne 0 ] || [ "$nerr" -gt 0 ]; then
    kit_log "session $step: exit $rc, $nerr failed command(s); first: $(grep -m1 '^### KIT-ERR' "$log" || true)"
    return 1
  fi
}

kit_ep_on_exit() {
  local rc=$?
  if [ "$rc" -ne 0 ] && [ -n "${KIT_EP_STEP:-}" ]; then kit_marker "$KIT_EP_STEP" FAIL; kit_log "step $KIT_EP_STEP FAILED (exit $rc)"; fi
}
kit_ep_begin() {  # step (in a generated job)
  kit_load_run
  KIT_EP_STEP=$1
  trap kit_ep_on_exit EXIT
  kit_marker "$1" RUNNING
  kit_log "step $1 begin: job ${SLURM_JOB_ID:-none} on $(hostname), ${SLURM_NTASKS:-?} tasks"
}
kit_ep_end() {
  kit_marker "$1" PASS
  KIT_EP_STEP=""
  kit_log "step $1 end: PASS"
}

# KIT EXTRA: MultiQC plot export (PNG) into the run's records, never into the learner directory.
# A failure is recorded as WARN and does not fail the step.
kit_multiqc_export() {  # step dir...
  local step=$1 out; shift
  out=$RECORDS/multiqc_export/$step
  mkdir -p "$out"
  if ( kit_load "$MULTIQC_MODULE" && cd "$W" && multiqc --export -f -o "$out" "$@" ) > "$out.log" 2>&1; then
    printf 'PASS\t%s\n' "$(find "$out" -name '*.png' | wc -l) png" > "$out.status"
  else
    printf 'WARN\tmultiqc export failed; see %s\n' "$out.log" > "$out.status"
    kit_log "WARN: MultiQC export for $step failed (see $out.log)"
  fi
}
