#!/bin/bash
# restage.sh: build the staged copies in scratch, then install them on Depot and check them.
# Usage: bash negishi-run/restage.sh --build | --scripts | --example --run RUN_ID | --install [--yes] [--dry-run]
#   --build    submit the stage-build job (about 20 min on standby): assembles STAGE_BUILD
#              (varcall-workshop and varcall-workshop_ref) from the phase-2 prep outputs and
#              writes staged_manifest.tsv and staged_ref_manifest.tsv in negishi-run/
#   --scripts  login node, seconds: copy pipeline/learner-scripts/*.sh into the build's scripts/
#              and rewrite staged_manifest.tsv (after the learner scripts change, Part D)
#   --example  login node, seconds: cut the teaching VCFs for EXAMPLE_REGION from the q0 calls of
#              run RUN_ID into the build's resources/example/ (raw, before norm, and filtered),
#              check that they hold het, hom-alt, indel, multiallelic and filtered records (the
#              region grows to the nearest multiallelic site if it has none), and rewrite
#              staged_manifest.tsv
#   --install  login node, about 10 minutes: copy the build to STAGED and STAGED_REF on Depot
#              (rsync without --delete; files take the Depot directory's group), make them
#              group-readable (chmod -R g+rX), then run check_staged.sh on both
#   --yes      skip the confirmation before writing to Depot
#   --dry-run  with --build: print the job's SLURM header and sbatch command; submit nothing
# Never deletes anything. Files on Depot that the manifest does not list make check_staged.sh
# fail; remove them by hand.
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"
MODE=""; YES=0; RUN_ID=""
while [ $# -gt 0 ]; do
  case $1 in
    --build|--scripts|--example|--install) MODE=${1#--}; shift;;
    --run) RUN_ID=$2; shift 2;;
    --yes) YES=1; shift;;
    --dry-run) DRY=1; shift;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) kit_die "unknown option $1";;
  esac
done
[ -n "$MODE" ] || kit_die "give --build, --scripts, --example or --install (see --help)"
export DRY
[ "$DRY" = 1 ] && [ "$MODE" != build ] && kit_die "--dry-run works with --build only"
kit_dirs
L=$STAGE_BUILD/varcall-workshop; F=$STAGE_BUILD/varcall-workshop_ref

case $MODE in
  build)
    kit_submit stage-build "$KIT_DIR/jobs/stage-build.sh"
    kit_log "when it finishes (squeue -u $(id -un)): bash $0 --install"
    ;;
  scripts)
    [ -d "$L/scripts" ] || kit_die "no build at $L; run --build first"
    cp -f "$REPO_DIR"/pipeline/learner-scripts/*.sh "$L/scripts/"
    python3 "$KIT_DIR/make_staged_manifest.py" "$L" "$KIT_DIR/staged_manifest.tsv" \
      --note "restage --scripts $(date +%F); data and resources from the stage-build of $(stat -c %y "$L/data/samples.tsv" | cut -c1-10)"
    kit_log "scripts updated in the build; now: bash $0 --install"
    ;;
  example)
    [ -n "$RUN_ID" ] || kit_die "--example needs --run RUN_ID (the reference run to cut from)"
    [ -d "$L/resources" ] || kit_die "no build at $L; run --build first"
    V=$KIT_SCRATCH_BASE/runs/$RUN_ID/q0/scratch/varcall-workshop/results/vcf
    RAW=$V/trio.raw.bcf; FILT=$V/trio.filtered.vcf.gz
    for f in "$RAW" "$FILT"; do [ -s "$f" ] || kit_die "missing $f (run $RUN_ID, call set q0)"; done
    kit_load "$BCFTOOLS_MODULE"
    E=$L/resources/example; D=$PREP_DIR/records/stage; mkdir -p "$E" "$D"
    chrom=${EXAMPLE_REGION%%:*}; r=${EXAMPLE_REGION#*:}; r=${r//,/}; beg=${r%-*}; end=${r#*-}
    n=$(bcftools view -H -i 'N_ALT>1' -r "$chrom:$beg-$end" "$RAW" | wc -l)
    if [ "$n" -eq 0 ]; then
      # the nearest multiallelic site (before norm) outside the window
      p=$(bcftools query -i 'N_ALT>1' -f '%POS\n' -r "$chrom" "$RAW" |
          awk -v b="$beg" -v e="$end" '{ d = ($1 < b) ? b - $1 : $1 - e; if (best == "" || d < best) { best = d; pos = $1 } } END { print pos }')
      [ -n "$p" ] || kit_die "no multiallelic site on $chrom in $RAW"
      kit_log "example: no multiallelic site in $chrom:$beg-$end; widened to include $chrom:$p"
      if [ "$p" -lt "$beg" ]; then beg=$p; else end=$p; fi
    fi
    reg=$chrom:$beg-$end
    bcftools view -r "$reg" -Oz -o "$E/trio.example.raw.vcf.gz" "$RAW"
    bcftools view -r "$reg" -Oz -o "$E/trio.example.filtered.vcf.gz" "$FILT"
    for f in "$E"/trio.example.*.vcf.gz; do bcftools index -t -f "$f"; done
    printf '%s\n' "$reg" > "$E/region.txt"
    X=$E/trio.example.filtered.vcf.gz
    {
      printf 'region\t%s\nsource\trun %s, call set q0\n' "$reg" "$RUN_ID"
      printf 'records_raw\t%s\nrecords_filtered\t%s\n' "$(bcftools view -H "$E/trio.example.raw.vcf.gz" | wc -l)" "$(bcftools view -H "$X" | wc -l)"
      printf 'multiallelic_raw\t%s\n' "$(bcftools view -H -i 'N_ALT>1' "$E/trio.example.raw.vcf.gz" | wc -l)"
      printf 'het\t%s\n' "$(bcftools view -H -i 'GT="het"' "$X" | wc -l)"
      printf 'hom_alt\t%s\n' "$(bcftools view -H -i 'GT="AA"' "$X" | wc -l)"
      printf 'indel\t%s\n' "$(bcftools view -H -i 'TYPE="indel"' "$X" | wc -l)"
      printf 'not_pass\t%s\n' "$(bcftools view -H -e 'FILTER="PASS"' "$X" | wc -l)"
    } > "$D/example.tsv"
    cat "$D/example.tsv" >&2
    awk -F'\t' 'NR > 4 && $2 == 0 { print $1; bad = 1 } END { exit bad }' "$D/example.tsv" > "$D/example_missing.txt" ||
      kit_die "the example region lacks: $(tr '\n' ' ' < "$D/example_missing.txt")(see $D/example.tsv)"
    python3 "$KIT_DIR/make_staged_manifest.py" "$L" "$KIT_DIR/staged_manifest.tsv" \
      --note "restage --example $(date +%F) from run $RUN_ID ($reg); data and resources from the stage-build of $(stat -c %y "$L/data/samples.tsv" | cut -c1-10)"
    kit_log "example written to $E ($reg); now: bash $0 --install"
    ;;
  install)
    kit_is_done stage-build || kit_die "stage-build has not passed (state/markers/stage-build.done)"
    for m in staged_manifest.tsv staged_ref_manifest.tsv; do [ -s "$KIT_DIR/$m" ] || kit_die "missing $KIT_DIR/$m"; done
    kit_log "install: $L -> $STAGED"
    kit_log "         $F -> $STAGED_REF"
    kit_log "         (about $(du -sh "$L" | cut -f1) and $(du -sh "$F" | cut -f1); group-readable; nothing is deleted)"
    if [ $YES = 0 ]; then
      read -r -p "Proceed? [y/N] " ans
      case $ans in y|Y|yes) ;; *) kit_die "cancelled";; esac
    fi
    for pair in "$L:$STAGED" "$F:$STAGED_REF"; do
      src=${pair%%:*}; dst=${pair#*:}
      mkdir -p "$dst"
      # -rlt: no owner, group or mode from scratch; the setgid Depot directory sets the group
      rsync -rlt --info=progress2 "$src/" "$dst/"
      chmod -R g+rX "$dst"
    done
    kit_log "install: checking (full md5; a few minutes)"
    rc=0
    bash "$KIT_DIR/check_staged.sh" "$STAGED" --perm "$STAGED_PERM" || rc=1
    bash "$KIT_DIR/check_staged.sh" --ref --perm "$STAGED_PERM" || rc=1
    kit_log "learners must be in the Depot group $(stat -c %G "$STAGED") to read $STAGED and $STAGED_REF"
    exit $rc
    ;;
esac
