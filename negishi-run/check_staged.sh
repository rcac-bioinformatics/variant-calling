#!/bin/bash
# check_staged.sh: check a staged copy against its manifest. Read only: changes nothing.
# Usage: bash negishi-run/check_staged.sh [DIR] [--ref | --results] [--manifest FILE]
#                                        [--quick] [--perm group|other]
#   (default)  STAGED with staged_manifest.tsv (the copy learners rsync)
#   --ref      STAGED_REF with staged_ref_manifest.tsv (reference, indexes, SDF, SnpEff data)
#   --results  STAGED_RESULTS with staged_results_manifest.tsv (completed results, Part D)
#   DIR        check this directory instead (with the manifest the other options select)
#   --perm     who must read it: group (default STAGED_PERM; files must also belong to
#              STAGED_GROUP) or other
#   --quick    md5 only for files under 50 MB (sizes are always checked)
# Checks: every manifest entry present with its size and md5, readable by the group (or others),
# every directory in and above the copy traversable, nothing extra (job logs, results, indexes
# that should not be there). Exit 1 on any problem.
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"

DIR=""; WHICH=learner; MAN=""; QUICK=0; PERM=$STAGED_PERM
while [ $# -gt 0 ]; do
  case $1 in
    --ref) WHICH=ref; shift;;
    --results) WHICH=results; shift;;
    --manifest) MAN=$2; shift 2;;
    --quick) QUICK=1; shift;;
    --perm) PERM=$2; shift 2;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    -*) kit_die "unknown option $1";;
    *) DIR=$1; shift;;
  esac
done
case $WHICH in
  learner) DIR=${DIR:-$STAGED}; MAN=${MAN:-$KIT_DIR/staged_manifest.tsv};;
  ref) DIR=${DIR:-$STAGED_REF}; MAN=${MAN:-$KIT_DIR/staged_ref_manifest.tsv};;
  results) DIR=${DIR:-$STAGED_RESULTS}; MAN=${MAN:-$KIT_DIR/staged_results_manifest.tsv};;
esac
case $PERM in group) RPOS=4; XPOS=6;; other) RPOS=7; XPOS=9;; *) kit_die "--perm must be group or other";; esac
[ -d "$DIR" ] || kit_die "$DIR is not a directory"
[ -s "$MAN" ] || kit_die "no manifest $MAN (restage.sh --build writes it)"
bad=0
fail() { printf 'FAIL  %s\n' "$*"; bad=$((bad + 1)); }
ok() { printf 'ok    %s\n' "$*"; }
grp_ok() {  # path
  [ "$PERM" != group ] && return 0
  local g; g=$(stat -L -c %G "$1")
  [ "$g" = "$STAGED_GROUP" ] || { fail "$1 group $g, expected $STAGED_GROUP"; return 1; }
}

expected=$(mktemp)
while IFS=$'\t' read -r p typ bytes md5 _need _src; do
  case "$p" in path|\#*|"") continue;; esac
  echo "$p" >> "$expected"
  f="$DIR/$p"
  if [ "$typ" = dir ]; then
    if [ -d "$f" ]; then ok "$p/"; else fail "$p/ missing"; fi
    continue
  fi
  [ -f "$f" ] || { fail "$p missing"; continue; }
  [ ! -L "$f" ] || { fail "$p is a symbolic link"; continue; }
  perm=$(stat -c %A "$f")
  [ "${perm:$RPOS:1}" = r ] || { fail "$p not readable by $PERM ($perm)"; continue; }
  grp_ok "$f" || continue
  sz=$(stat -c %s "$f")
  [ "$sz" = "$bytes" ] || { fail "$p size $sz, expected $bytes"; continue; }
  if [ $QUICK = 1 ] && [ "$bytes" -gt 50000000 ]; then ok "$p (size only)"; continue; fi
  m=$(md5sum < "$f" | cut -c1-32)
  if [ "$m" = "$md5" ]; then ok "$p"; else fail "$p md5 $m, expected $md5"; fi
done < "$MAN"

# directories inside the copy, and on the path to it, must be traversable
while IFS= read -r d; do
  perm=$(stat -c %A "$d")
  case "${perm:$XPOS:1}" in x|s|t) ;; *) fail "directory $d not traversable by $PERM ($perm)";; esac
done < <(find "$DIR" -type d)
d=$(readlink -f "$DIR")
while [ "$d" != / ]; do
  perm=$(stat -c %A "$d")
  case "${perm:$XPOS:1}" in x|s|t) ;; *) fail "directory $d not traversable by $PERM ($perm)";; esac
  d=$(dirname "$d")
done
# anything not in the manifest
extra=$(cd "$DIR" && find . -mindepth 1 | sed 's#^\./##' | sort | comm -23 - <(sort "$expected"))
if [ -n "$extra" ]; then
  printf 'FAIL  not in the manifest (learners would receive these):\n'; printf '%s\n' "$extra" | head -40 | sed 's/^/        /'
  bad=$((bad + 1))
fi
rm -f "$expected"
printf '\n%s (%s): %d problem(s)\n' "$DIR" "$(basename "$MAN")" "$bad"
[ "$bad" -eq 0 ]
