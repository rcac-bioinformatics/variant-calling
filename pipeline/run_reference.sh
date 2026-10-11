#!/bin/bash
# run_reference.sh: submit the reference-run job graph for one run (login node, under a minute).
# Usage: bash pipeline/run_reference.sh --run RUN_ID [--dry-run] [--force] [--redo "step ..."]
#   --dry-run   submit nothing; print each sbatch command (needs no setup)
#   --force     resubmit steps that are already done; --redo LIST: only these
# Learner scripts are submitted from the copy's scripts/ exactly as a learner would ("sbatch
# align.sh"), with submission options only: --parsable, --dependency, --kill-on-invalid-dep,
# --export=ALL,SCRATCH=<copy> and, for the determinism check,
# --array=1 --cpus-per-task=DET_CORES. Interactive blocks run as kit batch jobs (jobs/session.sh)
# with the cores and time of their sinteractive line. Graph:
#   qc, align, align-det (no dependency); alignqc after align; det-compare after align, align-det
#   fork-CS after qc, align, alignqc for each call set other than q0 (none since G3)
#   per call set CS in REF_CALL_SETS: call-CS -> merge-CS -> metrics-CS -> filter-CS
#     -> eval-CS -> evalsum-CS; filter-CS -> annot-CS -> tables-CS -> trio-CS; report-CS after
#     evalsum-CS and trio-CS
#   anchors after every report-CS, det-compare and alignqc
set -euo pipefail
RUN_ID=""; FORCE=0; REDO=""; DRY=0
while [ $# -gt 0 ]; do
  case $1 in
    --run) RUN_ID=$2; shift 2;;
    --dry-run) DRY=1; shift;;
    --force) FORCE=1; shift;;
    --redo) REDO=" $2 "; shift 2;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown option $1" >&2; exit 1;;
  esac
done
[ -n "$RUN_ID" ] || { echo "--run RUN_ID is required" >&2; exit 1; }
export RUN_ID DRY
PIPE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export PIPE_DIR
# shellcheck source=pipeline/lib.sh
source "$PIPE_DIR/lib.sh"
[ "$DRY" = 1 ] || kit_is_done setup || kit_die "run $RUN_ID is not set up; run pipeline/01_setup.sh $RUN_ID first"
kit_dirs
J=$PIPE_DIR/jobs; I=$LS/interactive
for b in "$I"/*.sh; do check_block_slurm "$b"; done
for f in "$LS"/*.sh; do
  grep -q "^#SBATCH --account=$KIT_ACCOUNT\$" "$f" || kit_die "$f: #SBATCH --account is not $KIT_ACCOUNT (config.sh)"
done
tsv=$(kit_jobs_tsv); first=$( [ -f "$tsv" ] && wc -l < "$tsv" || echo 1)

want() {  # step: 0 if it should be submitted
  local f=$FORCE
  case $REDO in *" $1 "*) f=1;; esac
  [ "$f" = 0 ] && [ "$DRY" != 1 ] || return 0
  if kit_step_done "$1"; then kit_log "skip $1 (done; --force or --redo to rerun)"; return 1; fi
  local id; id=$(kit_jobid "$1")
  if [ -n "$id" ] && [ -n "$(squeue -h -j "$id" -o '%T' 2>/dev/null | head -1 || true)" ]; then
    kit_log "skip $1 (job $id still queued or running)"; return 1
  fi
  return 0
}

# A learner script, submitted from the copy's scripts/ with submission options only
learner() {  # step copy script [--dep "steps"] [--env K=V] [sbatch options...]
  local step=$1 copy=$2 script=$3 deps="" env="" dep="" jid; shift 3
  while [ $# -gt 0 ]; do
    case $1 in --dep) deps=$2; shift 2;; --env) env="$env,$2"; shift 2;; *) break;; esac
  done
  want "$step" || return 0
  # shellcheck disable=SC2086  # deps is a space-separated list of step names
  [ -n "$deps" ] && dep=$(kit_dep $deps)
  local args=(--parsable --kill-on-invalid-dep=yes "--export=ALL,SCRATCH=$(copy_scratch "$copy")$env")
  [ -n "$dep" ] && args+=("--dependency=$dep")
  args+=("$@")
  if [ "$DRY" = 1 ]; then
    jid=$(( 9000000 + $(wc -l < "$tsv" 2>/dev/null || echo 0) ))
    printf '\n[%s] learner %s in copy %s (dry-run id %s)%s\n' "$step" "$script" "$copy" "$jid" "${dep:+, after ${dep#afterok:}}" >&2
    grep '^#SBATCH' "$LS/$script" | sed 's/^/    /' >&2
    printf '    cd %s/scripts && sbatch %s %s\n' "$(work_dir "$copy")" "${args[*]}" "$script" >&2
  else
    jid=$(cd "$(work_dir "$copy")/scripts" && sbatch "${args[@]}" "$script") || kit_die "sbatch failed for $step"
    jid=${jid%%;*}
    kit_log "submitted $step ($script, copy $copy) as job $jid${dep:+ ($dep)}"
  fi
  [ -f "$tsv" ] || printf 'step\tjobid\tsubmitted\tdependency\tscript\n' > "$tsv"
  printf '%s\t%s\t%s\t%s\t%s\n' "$step" "$jid" "$(kit_ts)" "${dep:--}" "learner:$script:$copy" >> "$tsv"
}

# A kit job; sessions take cores and time from the block's sinteractive line
kitjob() {  # step script [--dep "steps"] [--cores N] [--time T] [--export K=V,...]
  local step=$1; shift
  want "$step" || return 0
  local script=$1; shift
  local ex="RUN_ID=$RUN_ID,PIPE_DIR=$PIPE_DIR" a=()
  while [ $# -gt 0 ]; do
    case $1 in --export) ex="$ex,$2"; shift 2;; *) a+=("$1"); shift;; esac
  done
  kit_submit "$step" "$script" "${a[@]}" --export "$ex"
}
session() {  # step block copy [--dep "steps"]
  local step=$1 block=$2 copy=$3 c t; shift 3
  read -r c t <<< "$(block_resources "$I/$block")"
  kitjob "$step" "$J/session.sh" --cores "$c" --time "$t" --export "STEP=$step,BLOCK=$I/$block,COPY=$copy" "$@"
}

# ---- determinism copy: data and ref of q0, its own results (prepared here, on the login node)
if [ "$DRY" != 1 ] && want align-det; then
  D=$(work_dir det); Q=$(work_dir q0)
  mkdir -p "$D/results/bam"
  for x in data ref resources; do [ -e "$D/$x" ] || ln -s "$Q/$x" "$D/$x"; done
  [ -d "$D/scripts" ] || cp -a "$Q/scripts" "$D/scripts"
  rm -f "$D"/scripts/cluster-*   # KIT: only q0's job logs could be there
fi

session qc 03-qc.sh q0
learner align q0 align.sh
learner align-det det align.sh --array=1 "--cpus-per-task=$DET_CORES"
session alignqc 04-alignment-qc.sh q0 --dep align
kitjob det-compare "$J/det-compare.sh" --cores 4 --time 01:00:00 --dep "align align-det"
for cs in $COPIES; do
  [ "$cs" = q0 ] || kitjob "fork-$cs" "$J/fork.sh" --cores 1 --time 00:30:00 --dep "qc align alignqc" --export "FROM=q0,TO=$cs"
done
for cs in $COPIES; do
  if [ "$cs" = q0 ]; then cdep=align; else
    cdep=fork-$cs
    # sbatch reads the script at submission, before fork-CS has run: give the copy its
    # scripts/ now (hard links to q0's); fork.sh keeps them
    if [ "$DRY" != 1 ]; then
      mkdir -p "$(work_dir "$cs")/scripts"
      for f in "$(work_dir q0)"/scripts/*.sh; do
        [ -e "$(work_dir "$cs")/scripts/$(basename "$f")" ] || ln "$f" "$(work_dir "$cs")/scripts/"
      done
    fi
  fi
  learner "call-$cs" "$cs" call.sh --dep "$cdep"
  session "merge-$cs" 05-merge.sh "$cs" --dep "call-$cs"
  kitjob "metrics-$cs" "$J/metrics.sh" --cores 2 --time 01:00:00 --dep "merge-$cs" --export "COPY=$cs"
  session "filter-$cs" 06-filter.sh "$cs" --dep "metrics-$cs"
  learner "eval-$cs" "$cs" evaluate.sh --dep "filter-$cs"
  session "evalsum-$cs" 06-evaluate-summary.sh "$cs" --dep "eval-$cs"
  learner "annot-$cs" "$cs" annotate.sh --dep "filter-$cs"
  session "tables-$cs" 07-annotation-tables.sh "$cs" --dep "annot-$cs"
  session "trio-$cs" 08-trio.sh "$cs" --dep "tables-$cs"
  kitjob "report-$cs" "$J/report.sh" --cores 4 --time 01:00:00 --dep "evalsum-$cs trio-$cs" --export "COPY=$cs"
done
reps=""; for cs in $COPIES; do reps="$reps report-$cs"; done
kitjob anchors "$J/anchors.sh" --cores 2 --time 00:30:00 --dep "$reps det-compare alignqc"

printf '\nJob graph (%s):\n' "$( [ "$DRY" = 1 ] && echo "dry run, placeholder ids" || echo submitted)" >&2
awk -F'\t' -v f="$first" 'NR > f { printf "  %-14s %-9s %s\n", $1, $2, ($4 == "-" ? "no dependency" : $4) }' "$tsv" >&2
[ "$DRY" = 1 ] || kit_log "watch: squeue -u $(id -un) -o '%.10i %.16j %.8T %.10M %R'   then: bash $PIPE_DIR/collect.sh --run $RUN_ID"
