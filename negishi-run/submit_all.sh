#!/bin/bash
# submit_all.sh: run Episodes 2-6 as a new learner would (login node; about 2 minutes, then jobs).
# Usage: bash negishi-run/submit_all.sh --run RUN_ID [--from STEP] [--qos standby|normal] [--force] [--dry-run]
#   --run RUN_ID  a new ID starts a fresh learner copy in $KIT_RUNS/RUN_ID; an existing one continues it
#   --from STEP   skip the steps before STEP in generated/steps.tsv (they must be done)
#   --qos Q       QoS for every job (default: standby, what the episodes use)
#   --force       resubmit batch steps that are already done (02-setup never reruns in a run:
#                 its ln -s refuses existing links, as it would for a learner; use a new RUN_ID)
#   --dry-run     submit nothing: check scripts with bash -n, print each sbatch command, and ask
#                 SLURM to validate every job with sbatch --test-only
# Steps (generated/steps.tsv, built from the episodes by build_kit.py):
#   02-setup     login node: the setup-page and Episode 2 blocks, verbatim (rsync, ln -s, md5sum ...)
#   03-qc        batch job with the resources of the Episode 3 sinteractive line
#   04-align     the learner's scripts/align.sh, submitted from scripts/ as Episode 4 says
#   04-alignqc   batch job with the resources of the Episode 4 sinteractive line, after 04-align
#   05a-call     the learner's scripts/call.sh, after 04-align
#   05a-merge    batch job with the resources of the Episode 5A sinteractive line, after 05a-call
#   06-filter    batch job with the resources of the Episode 6 sinteractive line, after 05a-merge
#   06-evaluate  the learner's scripts/evaluate.sh, after 06-filter
#   06-evalsum   1-task batch job (login-node commands that wait for evaluate.sh), after 06-evaluate
# Job IDs go to $RUN/jobs.tsv. Then: bash negishi-run/collect.sh --run RUN_ID
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export KIT_DIR
RUN_ID=""; FROM=""; QOS=""; FORCE=0; DRYRUN=0
usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
while [ $# -gt 0 ]; do
  case $1 in
    --run) RUN_ID=$2; shift 2;;
    --from) FROM=$2; shift 2;;
    --qos) QOS=$2; shift 2;;
    --force) FORCE=1; shift;;
    --dry-run) DRYRUN=1; shift;;
    -h|--help) usage 0;;
    *) echo "unknown option $1" >&2; usage 1;;
  esac
done
# shellcheck source=negishi-run/kitrun.sh
source "$KIT_DIR/kitrun.sh"
[ -n "$RUN_ID" ] || kit_die "--run RUN_ID is required"
QOS=${QOS:-$KIT_QOS}
case $QOS in standby|normal) ;; *) kit_die "--qos must be standby or normal";; esac
STEPS_TSV=$KIT_GEN/steps.tsv

# The kit must match the lesson text it was built from
CHECK_OUT=$(python3 "$KIT_DIR/build_kit.py" --check 2>&1) || { printf '%s\n' "$CHECK_OUT" >&2; kit_die "build_kit.py --check failed; fix the episodes or rebuild the kit"; }
kit_log "${CHECK_OUT##*$'\n'}"
if [ -n "$FROM" ] && ! awk -F'\t' -v s="$FROM" '$1 == s { f = 1 } END { exit !f }' "$STEPS_TSV"; then
  kit_die "--from $FROM: no such step; steps are: $(awk -F'\t' 'NR > 1 { printf "%s ", $1 }' "$STEPS_TSV")"
fi

RUN=$(kit_run_dir "$RUN_ID")
export RUN
if [ ! -f "$RUN/kit.env" ]; then
  if [ "$DRYRUN" = 1 ]; then
    kit_log "dry run: $RUN does not exist; nothing is created"
    W=$RUN/scratch/varcall-workshop; KIT_LEARNER_SCRATCH=$RUN/scratch
  else
    kit_init_run "$RUN"
    kit_log "new run $RUN_ID in $RUN"
  fi
fi
if [ -f "$RUN/kit.env" ]; then
  kit_load_run
  printf '%s\n' "$CHECK_OUT" > "$RECORDS/build_kit_check.txt"
fi

# Refuse while jobs of an earlier submission of this run are queued or running: two copies of
# a step would work in the same learner directory
if [ "$DRYRUN" = 0 ] && [ -f "$RUN/jobs.tsv" ]; then
  prev=$(awk -F'\t' 'NR > 1 && $2 ~ /^[0-9]+$/ { printf "%s%s", s, $2; s = "," }' "$RUN/jobs.tsv")
  if [ -n "$prev" ]; then
    live=$(squeue -h -j "$prev" -o '%i %j %T' 2>/dev/null || true)
    [ -z "$live" ] || kit_die "jobs of an earlier submission of this run are still queued or running; wait or scancel them:
$live"
  fi
fi

JOBS_TSV=$RUN/jobs.tsv
[ "$DRYRUN" = 1 ] && JOBS_TSV=$(mktemp)
[ -f "$JOBS_TSV" ] && [ -s "$JOBS_TSV" ] || printf 'step\tjobid\tsubmitted\tdeps\tqos\n' > "$JOBS_TSV"
declare -A JOB
NFAIL=0; FAKE=9000000

testonly() {  # dir args...: sbatch --test-only without the dependency options
  local wd=$1 a args=() r; shift
  for a in "$@"; do case $a in --dependency=*|--parsable|--kill-on-invalid-dep=*) ;; *) args+=("$a");; esac; done
  if ! command -v sbatch >/dev/null 2>&1; then printf '    test-only: skipped, no sbatch here\n' >&2; return 0; fi
  r=$( (cd "$wd" 2>/dev/null || cd "$KIT_GEN"; sbatch --test-only "${args[@]}") 2>&1 | tail -1) || true   # a dry run may have no run directory yet
  case "$r" in *"to start at"*|*"would"*) printf '    test-only: %s\n' "$r" >&2;;
    *) printf '    test-only FAILED: %s\n' "$r" >&2; NFAIL=$((NFAIL + 1));; esac
}

submit() {  # step dir args... : sets JID
  local step=$1 wd=$2; shift 2
  printf '  [%s] (cd %s && sbatch %s)\n' "$step" "$wd" "$*" >&2
  if [ "$DRYRUN" = 1 ]; then
    FAKE=$((FAKE + 1)); JID=$FAKE
    testonly "$wd" "$@"
  else
    JID=$(cd "$wd" && sbatch "$@") || kit_die "sbatch failed for $step"
    JID=${JID%%;*}
  fi
}

started=0; [ -z "$FROM" ] && started=1
while IFS=$'\t' read -r step kind deps _ _ _ _ _ script desc; do
  [ "$step" = step ] && continue
  if [ "$started" = 0 ]; then
    if [ "$step" = "$FROM" ]; then started=1; else
      [ "$DRYRUN" = 1 ] || kit_ep_done "$step" || kit_die "--from $FROM: earlier step $step is not done"
      continue
    fi
  fi
  if [ "$DRYRUN" = 0 ] && kit_ep_done "$step" && { [ "$FORCE" = 0 ] || [ "$kind" = login ]; }; then
    kit_log "skip $step (done)"; continue
  fi
  # afterok on steps submitted now; earlier steps must be done
  dl=""
  for d in ${deps//,/ }; do
    [ "$d" = - ] && continue
    if [ -n "${JOB[$d]:-}" ]; then dl="$dl:${JOB[$d]}"
    elif [ "$DRYRUN" = 1 ] || kit_ep_done "$d"; then :
    else kit_die "$step depends on $d, which is neither done nor submitted"; fi
  done
  common=(--parsable --kill-on-invalid-dep=yes "--qos=$QOS")
  [ -n "$dl" ] && common+=("--dependency=afterok$dl")
  kit_log "$step: $desc"
  case $kind in
    login)
      bash -n "$KIT_GEN/sessions/$step.sh"
      if [ "$DRYRUN" = 1 ]; then printf '  [%s] runs generated/sessions/%s.sh here, on the login node\n' "$step" "$step" >&2; continue; fi
      kit_marker "$step" RUNNING
      t0=$(date +%s)
      if ! kit_ep_session "$step"; then kit_marker "$step" FAIL; kit_die "$step failed; see $RECORDS/console/$step.log"; fi
      echo $(( $(date +%s) - t0 )) > "$RECORDS/listings/$step-seconds.txt"
      # KIT EXTRA: what the copy holds, for the setup page and Episode 2
      for x in "$W" "$W"/data "$W"/resources "$W"/scripts; do du -sb "$x"; done > "$RECORDS/listings/$step-du.txt" 2>&1 || true   # one du per path: du counts a subfolder once
      ( cd "$W" && find . -maxdepth 2 | sort ) > "$RECORDS/listings/$step-tree.txt"
      bad=$(find "$W/ref" -maxdepth 1 -xtype l)
      [ -z "$bad" ] || { kit_marker "$step" FAIL; kit_die "broken reference links: $bad"; }
      kit_marker "$step" PASS
      kit_log "$step done in $(cat "$RECORDS/listings/$step-seconds.txt") s"
      continue;;
    session)
      bash -n "$KIT_GEN/jobs/$step.sh"; bash -n "$KIT_GEN/sessions/$step.sh"
      [ "$DRYRUN" = 1 ] || kit_marker "$step" QUEUED
      submit "$step" "$RUN" "${common[@]}" -o "$RUN/logs/$step.%j.out" -e "$RUN/logs/$step.%j.out" \
        "--export=ALL,RUN=$RUN,KIT_DIR=$KIT_DIR,KIT_GEN=$KIT_GEN" "$KIT_GEN/jobs/$step.sh";;
    learner)
      # The learner submits the staged script (align.sh, call.sh, evaluate.sh); it must be the one the episode shows
      bash -n "$KIT_GEN/learner-scripts/$script"
      if [ "$DRYRUN" = 1 ]; then
        submit "$step" "$KIT_GEN/learner-scripts" "${common[@]}" "--export=ALL,SCRATCH=$KIT_LEARNER_SCRATCH" "$script"
      else
        cmp -s "$W/scripts/$script" "$KIT_GEN/learner-scripts/$script" || kit_die "$W/scripts/$script differs from the episode's $script; restage the scripts (restage.sh --scripts)"
        submit "$step" "$W/scripts" "${common[@]}" "--export=ALL,SCRATCH=$KIT_LEARNER_SCRATCH" "$script"
      fi;;
    *) kit_die "unknown step kind $kind";;
  esac
  JOB[$step]=$JID
  printf '%s\t%s\t%s\t%s\t%s\n' "$step" "$JID" "$(kit_ts)" "${dl#:}" "$QOS" >> "$JOBS_TSV"
done < "$STEPS_TSV"

if [ "$DRYRUN" = 1 ]; then
  rm -f "$JOBS_TSV"
  kit_log "dry run: nothing submitted; $NFAIL sbatch --test-only failure(s)"
  [ "$NFAIL" = 0 ]
else
  kit_log "submitted; job IDs in $JOBS_TSV"
  kit_log "watch: squeue -u $(id -un) -o '%.10i %.16j %.8T %.10M %R'   then: bash $KIT_DIR/collect.sh --run $RUN_ID"
fi
