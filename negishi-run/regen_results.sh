#!/bin/bash
# regen_results.sh: make the completed-results copy from a finished reference run (Part D).
# Usage: bash negishi-run/regen_results.sh --finalize --call-set q0 --run RUN_ID [--date YYYY-MM-DD]
# Copies the run's learner copy for that call set into a NEW directory next to STAGED_RESULTS,
#   <dirname STAGED_RESULTS>/varcall-workshop_results.<date>
# leaving out what learners already have from the staged copies (data/*.fastq.gz, ref/,
# resources/) and the kit's job logs (scripts/cluster-*). It makes the copy group-readable,
# writes staged_results_manifest.tsv, and prints the swap and rollback commands. It never
# deletes anything and never changes the current STAGED_RESULTS; the swap is a manual step.
set -euo pipefail
FINAL=0; CS=""; RUN_ID=""; DATE=$(date +%F)
while [ $# -gt 0 ]; do
  case $1 in
    --finalize) FINAL=1; shift;;
    --call-set) CS=$2; shift 2;;
    --run) RUN_ID=$2; shift 2;;
    --date) DATE=$2; shift 2;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown option $1" >&2; exit 1;;
  esac
done
[ "$FINAL" = 1 ] || { echo "only --finalize is supported; the run itself is pipeline/run_reference.sh" >&2; exit 1; }
[ -n "$RUN_ID" ] || { echo "--run RUN_ID is required" >&2; exit 1; }
export RUN_ID
PIPE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../pipeline" && pwd)
export PIPE_DIR
# shellcheck source=pipeline/lib.sh
source "$PIPE_DIR/lib.sh"
case " $REF_CALL_SETS " in *" $CS "*) ;; *) kit_die "--call-set must be one of: $REF_CALL_SETS";; esac
W=$(work_dir "$CS")
[ -d "$W" ] || kit_die "no learner copy $W"
DEST="$(dirname "$STAGED_RESULTS")/$(basename "$STAGED_RESULTS").$DATE"
[ -e "$DEST" ] && kit_die "$DEST already exists; pick another --date"

# every step of this call set, and the shared ones, must have passed
bad=""
for s in setup qc align alignqc det-compare "call-$CS" "merge-$CS" "metrics-$CS" "filter-$CS" "eval-$CS" \
         "evalsum-$CS" "annot-$CS" "tables-$CS" "trio-$CS" "report-$CS" anchors; do
  kit_step_done "$s" || bad="$bad $s"
done
[ -z "$bad" ] || kit_die "not every step passed in run $RUN_ID:$bad"
for p in results/bam results/vcf/trio.norm.vcf.gz results/vcf/trio.filtered.vcf.gz results/eval results/annot/trio.ann.vcf.gz \
         results/trio/funnel.tsv results/trio/candidates.tsv results/qc/multiqc_report.html results/qc_alignment/multiqc_report.html; do
  [ -e "$W/$p" ] || kit_die "expected $W/$p is missing"
done
# the run must have used the final learner scripts (the results copy ships its scripts/)
for f in "$REPO_DIR"/pipeline/learner-scripts/*.sh; do
  cmp -s "$f" "$W/scripts/$(basename "$f")" || kit_die "$W/scripts/$(basename "$f") differs from pipeline/learner-scripts: finalize from a run made with the final scripts"
done
# the staged example must match this run's filtered calls in its region
E=$W/resources/example
if [ -s "$E/region.txt" ]; then
  kit_load "$BCFTOOLS_MODULE"
  a=$(bcftools view -H "$E/trio.example.filtered.vcf.gz" | md5sum | cut -d' ' -f1)
  b=$(bcftools view -H -r "$(cat "$E/region.txt")" "$W/results/vcf/trio.filtered.vcf.gz" | md5sum | cut -d' ' -f1)
  [ "$a" = "$b" ] || kit_die "resources/example differs from this run's calls in $(cat "$E/region.txt")"
  kit_log "example region $(cat "$E/region.txt") matches this run's filtered calls"
else
  kit_log "WARNING: no resources/example in this run's copy (restage.sh --example before the run)"
fi

kit_log "copying $W -> $DEST (call set $CS, run $RUN_ID)"
mkdir "$DEST"
rsync -rlt --exclude='/data/*.fastq.gz' --exclude=/ref/ --exclude=/resources/ --exclude='/scripts/cluster-*' "$W/" "$DEST/"
chmod -R g+rX "$DEST"
python3 "$KIT_DIR/make_staged_manifest.py" "$DEST" "$KIT_DIR/staged_results_manifest.tsv" \
  --note "regen_results.sh $DATE from run $RUN_ID, call set $CS"
cp "$KIT_DIR/staged_results_manifest.tsv" "$RECORDS/"
bash "$KIT_DIR/check_staged.sh" "$DEST" --results --perm "$STAGED_PERM" > "$RECORDS/check_results_new.txt" || \
  kit_die "the new copy fails check_staged.sh (see $RECORDS/check_results_new.txt)"
kit_log "done: $DEST ($(du -sh "$DEST" | cut -f1)); not swapped in. To swap it in:"
cat <<EOF
  # keep the current copy (if any) under a dated name, then move the new one into place
  [ -e $STAGED_RESULTS ] && mv $STAGED_RESULTS $STAGED_RESULTS.replaced-$DATE
  mv $DEST $STAGED_RESULTS
  bash $KIT_DIR/check_staged.sh --results
  # rollback
  mv $STAGED_RESULTS $DEST
  [ -e $STAGED_RESULTS.replaced-$DATE ] && mv $STAGED_RESULTS.replaced-$DATE $STAGED_RESULTS
EOF
