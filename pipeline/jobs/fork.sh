#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:30:00
# fork: start learner copy TO from copy FROM after alignment, so the call sets share inputs and
# BAMs. Hard links for data, resources, scripts and the finished results (bam, qc,
# qc_alignment), the same symlinks in ref/, and empty folders for everything the call set
# writes. Nothing the later steps write is shared: they only create new files under
# results/vcf, eval, annot and trio, which start empty here. Needs RUN_ID, FROM, TO.
set -euo pipefail
# shellcheck source=pipeline/lib.sh
source "${PIPE_DIR:?PIPE_DIR must be exported by the submitter}/lib.sh"
kit_job_begin "fork-${TO:?}"
S=$(work_dir "${FROM:?}"); D=$(work_dir "$TO")
# run_reference.sh creates $D/scripts at submission (sbatch needs the script then); anything
# else already there means an earlier fork
for x in data resources ref results; do
  [ -e "$D/$x" ] && kit_die "$D/$x exists already; remove $D by hand to fork again"
done
mkdir -p "$D/results"
cp -al "$S/data" "$S/resources" "$D/"
cp -a "$S/ref" "$D/"
mkdir -p "$D/scripts"
for f in "$S"/scripts/*.sh; do [ -e "$D/scripts/$(basename "$f")" ] || ln "$f" "$D/scripts/"; done
for r in bam qc qc_alignment; do cp -al "$S/results/$r" "$D/results/"; done
mkdir -p "$D/results/vcf" "$D/results/eval" "$D/results/annot" "$D/results/trio"
( cd "$D" && find . -maxdepth 2 | sort ) > "$RECORDS/listings-fork-$TO.txt"
kit_job_end
