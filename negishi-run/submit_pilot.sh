#!/bin/bash
# submit_pilot.sh: submit the pilot job graph (login node, under a minute).
# Usage: [CALL_SET=raw|q20] bash negishi-run/submit_pilot.sh [--dry-run] [--test-only] [--force] [--redo "step..."]
#   --dry-run    submit nothing; print each job's SLURM header and full sbatch command
#   --test-only  with --dry-run, also ask SLURM to validate each job (sbatch --test-only)
#   --force      resubmit steps whose marker says PASS
#   --redo LIST  resubmit only these steps even if done (names as in the graph, e.g. "p-eval p-trio")
#   CALL_SET     call set from config.sh; a set other than raw gets its own outputs and step names
# Dependencies on the data-prep jobs come from state/jobs.tsv: a prep step that is done adds no
# dependency, one that is queued or running adds afterok, anything else stops the script.
# Graph:
#   prep-bwaindex + prep-fastq -> p-align-c<N> (one job per PILOT_ALIGN_CORES value)
#   prep-faidx -> p-call-chunks (array) -> p-call-merge -> p-eval (+ prep-truth)
#   prep-faidx -> p-call-vcmp
#   p-call-merge + prep-annot -> p-snpeff-c<N> (one per PILOT_SNPEFF_CORES) -> p-trio
# p-call, p-eval and the annotation jobs do not wait for the bwa index. With CALL_SET other than
# raw, p-call-chunks, p-call-merge, p-eval, p-snpeff-c<N> and p-trio are named <step>-<set>.
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
FORCE=0
REDO=""
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY=1; shift;;
    --test-only) KIT_TEST_ONLY=1; shift;;
    --force) FORCE=1; shift;;
    --redo) REDO=" $2 "; shift 2;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) kit_die "unknown option $1";;
  esac
done
export DRY KIT_TEST_ONLY
[ "${KIT_TEST_ONLY:-0}" = 1 ] && [ "$DRY" != 1 ] && kit_die "--test-only needs --dry-run"
kit_dirs
P=$KIT_DIR/pilot
tsv=$(kit_jobs_tsv)
first=$( [ -f "$tsv" ] && wc -l < "$tsv" || echo 1)

sub() {  # step script [kit_submit options]
  local step=$1 f=$FORCE
  case $REDO in *" $step "*) f=1;; esac
  if [ "$f" = 0 ] && kit_step_done "$step"; then kit_log "skip $step (done; --force or --redo to rerun)"; return 0; fi
  kit_submit "$@" --export "KIT_FORCE=$f${EXTRA_EXPORT:+,$EXTRA_EXPORT}"
}
for c in $PILOT_ALIGN_CORES; do sub "p-align-c$c" "$P/p-align.sh" --cores "$c" --dep "prep-bwaindex prep-fastq"; done
chunks=$(kit_set_step p-call-chunks); merge=$(kit_set_step p-call-merge)
sub "$chunks" "$P/p-call-chunk.sh" --array "1-$CALL_CHUNKS" --dep prep-faidx
sub p-call-vcmp "$P/p-call-vcmp.sh" --dep prep-faidx
sub "$merge" "$P/p-call-merge.sh" --dep "$chunks"
sub "$(kit_set_step p-eval)" "$P/p-eval.sh" --dep "$merge prep-truth"
max=0
for c in $PILOT_SNPEFF_CORES; do
  sub "$(kit_set_step "p-snpeff-c$c")" "$P/p-snpeff.sh" --cores "$c" --dep "$merge prep-annot"
  [ "$c" -gt "$max" ] && max=$c
done
EXTRA_EXPORT="SNPEFF_RUN=$(kit_set_step "c$max")" sub "$(kit_set_step p-trio)" "$P/p-trio.sh" \
  --dep "$merge $(kit_set_step "p-snpeff-c$max") prep-annot"

printf '\nJob graph (%s):\n' "$( [ "$DRY" = 1 ] && echo "dry run, placeholder ids" || echo submitted)" >&2
awk -F'\t' -v f="$first" 'NR > f { printf "  %-16s %-9s %s\n", $1, $2, ($4 == "-" ? "no dependency" : $4) }' "$tsv" >&2
[ "$DRY" = 1 ] || kit_log "watch: squeue -u $(id -un) -o '%.10i %.16j %.8T %.10M %R'   then: bash $KIT_DIR/collect.sh"
