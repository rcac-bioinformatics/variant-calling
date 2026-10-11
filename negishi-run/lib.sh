# negishi-run/lib.sh: functions shared by the kit, data-prep and pilot scripts.
# Sourced by scripts that run under `set -euo pipefail`. Jobs get KIT_DIR from the submitter
# (--export), because under sbatch BASH_SOURCE points at the spool copy of the script.
# shellcheck shell=bash

KIT_DIR=${KIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
REPO_DIR=${REPO_DIR:-$(cd "$KIT_DIR/.." && pwd)}
export KIT_DIR REPO_DIR
# shellcheck source=negishi-run/config.sh
source "$KIT_DIR/config.sh"
SOURCES_TSV=${SOURCES_TSV:-$REPO_DIR/data-prep/sources.tsv}
case "$PREP_DIR" in
  /varcall-prep|"") echo "ERROR: PREP_DIR is not set and \$SCRATCH is empty; set SCRATCH or PREP_DIR" >&2; exit 1;;
  /depot/workshop/data*) echo "ERROR: PREP_DIR=$PREP_DIR is under /depot/workshop/data; staging belongs to phase 3" >&2; exit 1;;
esac
RECORDS=$PREP_DIR/records
STATE=$PREP_DIR/state
LOGS=$PREP_DIR/logs
DRY=${DRY:-0}
export PREP_DIR RECORDS STATE LOGS SOURCES_TSV DRY

kit_ts() { date '+%Y-%m-%dT%H:%M:%S'; }
kit_log() { printf '[%s] %s\n' "$(kit_ts)" "$*" >&2; }
kit_die() { kit_log "ERROR: $*"; exit 1; }
kit_dirs() { mkdir -p "$RECORDS" "$STATE/markers" "$LOGS" "$PREP_DIR/tmp"; }

# Print a command in dry-run mode, run it otherwise
kit_run() {
  if [ "$DRY" = 1 ]; then printf '  + %s\n' "$*" >&2; else "$@"; fi
}

# ---------------------------------------------------------------- sources.tsv
# Columns: id url purpose expected_size checksum_source terms_url expected_md5
src_field() {  # id column-number; returns 1 if there is no such row
  awk -F'\t' -v id="$1" -v c="$2" '$1 == id { print $c; f = 1 } END { exit !f }' "$SOURCES_TSV"
}
src_url() { src_field "$1" 2 || kit_die "no row '$1' in $SOURCES_TSV"; }
src_ids() {  # regex on id -> matching ids, in file order
  awk -F'\t' -v re="$1" 'NR > 1 && $1 !~ /^#/ && $1 ~ re { print $1 }' "$SOURCES_TSV"
}

# ---------------------------------------------------------------- records
# PASS/WARN/FAIL/INFO rows: callers set ROWS_TSV and reset NFAIL/NWARN
NFAIL=0; NWARN=0
kit_row() {  # status check detail
  local s=$1 c=$2 d=${3:-}
  [ "$s" = FAIL ] && NFAIL=$((NFAIL + 1))
  [ "$s" = WARN ] && NWARN=$((NWARN + 1))
  printf '%-5s %-40s %s\n' "$s" "$c" "$d" >&2
  if [ -n "${ROWS_TSV:-}" ] && [ "$DRY" != 1 ]; then
    printf '%s\t%s\t%s\n' "$c" "$s" "$(printf '%s' "$d" | tr '\t\n' '  ')" >> "$ROWS_TSV"
  fi
}

# Every derived number goes through kit_metric and carries KIT_LABEL: "pilot" in phase 2,
# "reference run, not frozen" in phase 3 (pipeline/lib.sh sets it).
KIT_LABEL=${KIT_LABEL:-pilot}
kit_metric() {  # step sample metric value [unit]
  [ "$DRY" = 1 ] && return 0
  local f=$RECORDS/metrics.tsv
  [ -f "$f" ] || printf 'step\tsample\tmetric\tvalue\tunit\tlabel\tdate\n' > "$f"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "${5:-}" "$KIT_LABEL" "$(kit_ts)" >> "$f"
}

# Header line for derived-record files
kit_pilot_header() {
  if [ "$KIT_LABEL" = pilot ]; then printf '# pilot %s: feasibility only, not a lesson anchor\n' "$(date +%F)"
  else printf '# %s, %s\n' "$KIT_LABEL" "$(date +%F)"; fi
}

kit_prov() {  # id url local_path bytes md5 md5_check
  [ "$DRY" = 1 ] && return 0
  local f=$RECORDS/provenance.tsv
  [ -f "$f" ] || printf 'id\turl\tpath\tdate\tbytes\tmd5\tmd5_check\n' > "$f"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(kit_ts)" "$4" "$5" "$6" >> "$f"
}

# Wall time of a stage inside a job: kit_t0 label ... kit_t1 label step sample
kit_t0() { eval "KIT_T0_$1=\$(date +%s)"; }
kit_t1() {  # label step sample
  local v="KIT_T0_$1"
  kit_metric "$2" "$3" "wall_s_$1" "$(( $(date +%s) - ${!v} ))" s
}

# ---------------------------------------------------------------- modules
kit_module_init() {
  if ! type module >/dev/null 2>&1; then
    set +u
    if [ -n "${LMOD_PKG:-}" ] && [ -f "$LMOD_PKG/init/bash" ]; then
      # shellcheck source=/dev/null
      source "$LMOD_PKG/init/bash"
    elif [ -f /etc/profile.d/lmod.sh ]; then
      # shellcheck source=/dev/null
      source /etc/profile.d/lmod.sh
    fi
    set -u
  fi
  type module >/dev/null 2>&1 || kit_die "the Lmod module command is not available"
}
# Lmod is not written for `set -u`; relax it around every module call.
kit_module() { local rc=0; set +u; module "$@" || rc=$?; set -u; return $rc; }
# The container command a module's wrapper uses for TOOL: everything from singularity/apptainer
# up to the image path, with the wrapper's own options and binds. Kit code runs other programs
# from the same image through it (rtg inside the hap.py image). Reads a wrapper function, or an
# exported wrapper script. Prints nothing if neither names an image.
kit_wrapper_prefix() {  # tool (its module loaded)
  local f
  { type "$1" 2>/dev/null; f=$(command -v "$1" 2>/dev/null || true); if [ -f "$f" ]; then cat "$f"; fi; } \
    | grep -m1 -oE '[^ ;{(]*(singularity|apptainer) +(exec|run) +[^;]*\.sif' || true
}
# The rtg that hap.py itself calls for vcfeval (its --engine-vcfeval-path default), else a search.
kit_happy_rtg() {  # prefix from kit_wrapper_prefix hap.py
  local pre=$1 r
  r=$(hap.py --help 2>&1 | tr '\n' ' ' | grep -oE 'default is [^ ]*rtg[^ ]*' | head -1 | awk '{ print $3 }' | tr -d '".,')
  if [ -z "$r" ]; then
    # shellcheck disable=SC2086,SC2016  # pre is a command prefix; $ expanded inside the container
    r=$($pre sh -c 'command -v rtg || find / -xdev -name rtg -type f -perm -u+x 2>/dev/null | head -1' 2>/dev/null | tail -1)
  fi
  printf '%s\n' "$r"
}

# rtg format through the hap.py container, trying the ways rtg can be started until one works:
#   1 the rtg launcher as hap.py calls it (no RTG_MEM), 2 the launcher with RTG_MEM, 3 java -jar
#   RTG.jar with the java that the launcher's rtg.cfg names, 4 java -jar RTG.jar with java from PATH.
# Writes diagnostics (PATH, java, rtg.cfg) and every attempt to LOG; prints the attempt that worked.
kit_rtg_format() {  # prefix rtg out_sdf fasta mem log
  local pre=$1 rtg=$2 out=$3 fa=$4 mem=$5 log=$6 dir jv n
  dir=$(dirname "$rtg")
  {
    echo "== diagnostics (inside the container)"
    # shellcheck disable=SC2086,SC2016  # pre is a command prefix; $ expanded inside the container
    $pre sh -c 'echo "PATH=$PATH"; echo "java on PATH: $(command -v java || echo none)"; java -version 2>&1 | head -2' 2>&1
    # shellcheck disable=SC2086
    $pre sh -c "ls -l '$dir' | head -20; echo '-- rtg.cfg:'; grep -v '^#' '$dir/rtg.cfg' 2>/dev/null | grep -v '^\$'" 2>&1
  } > "$log"
  # shellcheck disable=SC2086,SC2016
  jv=$($pre sh -c ". '$dir/rtg.cfg' 2>/dev/null; echo \"\${RTG_JAVA:-}\"" 2>/dev/null | tail -1)
  [ -e "$out" ] && { echo "$out exists" >> "$log"; return 1; }
  # each attempt writes to its own scratch directory; only a complete SDF is moved to OUT
  local tmp; tmp=${TMPDIR:-$PREP_DIR/tmp}/rtg.$$; mkdir -p "$tmp"
  try() {  # label command... (the command writes to $tmp/try$n)
    printf '\n== attempt %s: %s\n' "$n" "$1" >> "$log"; shift
    if "$@" >> "$log" 2>&1 && [ -d "$tmp/try$n" ]; then mv "$tmp/try$n" "$out"; echo "$n"; return 0; fi
    return 1
  }
  n=1
  # shellcheck disable=SC2086
  try "launcher, no RTG_MEM" env -u RTG_MEM $pre "$rtg" format -o "$tmp/try$n" "$fa" && return 0
  n=2
  # shellcheck disable=SC2086
  try "launcher, RTG_MEM=$mem" env RTG_MEM="$mem" $pre "$rtg" format -o "$tmp/try$n" "$fa" && return 0
  n=3
  if [ -n "$jv" ]; then
    # shellcheck disable=SC2086
    try "$jv -jar RTG.jar (rtg.cfg)" $pre "$jv" -Xmx"$mem" -jar "$dir/RTG.jar" format -o "$tmp/try$n" "$fa" && return 0
  fi
  n=4
  # shellcheck disable=SC2086
  try "java -jar RTG.jar (PATH)" $pre java -Xmx"$mem" -jar "$dir/RTG.jar" format -o "$tmp/try$n" "$fa" && return 0
  return 1
}

# Fresh environment plus the given modules (KIT_PURGE=0 skips the purge)
kit_load() {
  [ "$DRY" = 1 ] && { printf '  + module load biocontainers %s\n' "$*" >&2; return 0; }
  kit_module_init
  [ "$KIT_PURGE" = 1 ] && kit_module --force purge
  kit_module load biocontainers
  local m
  for m in "$@"; do kit_module load "$m" || kit_die "module load $m failed"; done
}

# ---------------------------------------------------------------- jobs and markers
kit_marker() { [ "$DRY" = 1 ] || printf '%s %s %s\n' "$2" "$(kit_ts)" "${SLURM_JOB_ID:-none}" > "$STATE/markers/$1.done"; }
kit_is_done() { [ -f "$STATE/markers/$1.done" ] && grep -q '^PASS ' "$STATE/markers/$1.done"; }
# Array steps write one marker per task: <step>.t<N>
kit_is_done_n() {  # step ntasks
  local i
  for i in $(seq 1 "$2"); do kit_is_done "$1.t$i" || return 1; done
}
kit_step_done() {  # step: handles the array steps by name
  case $1 in
    prep-fastq) kit_is_done_n prep-fastq "$(wc -w <<< "$SAMPLES")";;
    p-call-chunks*) kit_is_done_n "$1" "$CALL_CHUNKS";;
    *) kit_is_done "$1";;
  esac
}

KIT_STEP_NAME=""
kit_on_exit() {
  local rc=$?
  if [ "$rc" -ne 0 ] && [ -n "$KIT_STEP_NAME" ]; then kit_marker "$KIT_STEP_NAME" FAIL; kit_log "step $KIT_STEP_NAME FAILED (exit $rc)"; fi
}
kit_job_begin() {  # step (array tasks get .t<N> appended)
  KIT_STEP_NAME=$1
  [ -n "${SLURM_ARRAY_TASK_ID:-}" ] && KIT_STEP_NAME="$1.t$SLURM_ARRAY_TASK_ID"
  kit_dirs
  trap kit_on_exit EXIT
  kit_marker "$KIT_STEP_NAME" RUNNING
  kit_log "step $KIT_STEP_NAME begin: job ${SLURM_JOB_ID:-none} on $(hostname) cpus=${SLURM_CPUS_PER_TASK:-?}"
  export TMPDIR="$PREP_DIR/tmp/${SLURM_JOB_ID:-$$}"   # Negishi /tmp is shared node-wide
  mkdir -p "$TMPDIR"
}
kit_job_end() {
  kit_marker "$KIT_STEP_NAME" PASS
  rm -rf "${TMPDIR:?}"
  kit_log "step $KIT_STEP_NAME end: PASS"
}
# Call set (config.sh CALL_SET): "raw" keeps the first pilot's paths and step names
kit_set_dir() { if [ "$CALL_SET" = raw ]; then echo pilot; else echo "pilot/$CALL_SET"; fi; }
kit_set_step() { if [ "$CALL_SET" = raw ]; then echo "$1"; else echo "$1-$CALL_SET"; fi; }
kit_cores() { echo "${SLURM_CPUS_PER_TASK:-${KIT_CORES:-2}}"; }

# Latest job id recorded for a step (dry runs keep their own table)
kit_jobs_tsv() { if [ "$DRY" = 1 ]; then echo "$STATE/jobs-dryrun.tsv"; else echo "$STATE/jobs.tsv"; fi; }
kit_jobid() { awk -F'\t' -v s="$1" '$1 == s { id = $2 } END { if (id != "") print id }' "$(kit_jobs_tsv)" 2>/dev/null || true; }

# Dependency on earlier steps: afterok on a queued or running job (checked first, so a step
# resubmitted with --force is waited for even though its old marker says PASS), nothing if
# done, else stop.
kit_dep() {  # step...
  local s id dl="" st
  for s in "$@"; do
    id=$(kit_jobid "$s")
    if [ -n "$id" ] && [ "$DRY" != 1 ] && [ -n "$(squeue -h -j "$id" -o '%T' 2>/dev/null | head -1 || true)" ]; then
      dl="$dl:$id"; continue
    fi
    kit_step_done "$s" && continue
    if [ -z "$id" ]; then
      [ "$DRY" = 1 ] && { kit_log "dry run: $s has no job in this dry run (run its data-prep script with --dry-run first)"; continue; }
      kit_die "$s is neither done nor submitted; run its script first"
    fi
    if [ "$DRY" != 1 ]; then
      st=$(squeue -h -j "$id" -o '%T' 2>/dev/null | head -1 || true)
      [ -n "$st" ] || kit_die "$s (job $id) is no longer queued and its marker is not PASS; check $LOGS and resubmit it"
    fi
    dl="$dl:$id"
  done
  [ -n "$dl" ] && echo "afterok$dl"
  return 0
}

# Submit a job script. Account, partition and QoS come from config; resources stay in the
# script header (cores may be overridden). No memory request is ever added.
# Usage: kit_submit step script [--dep "step1 step2"] [--cores N] [--time T] [--array SPEC] [--export K=V,...]
kit_submit() {
  local step=$1 script=$2; shift 2
  local deps="" cores="" wall="" array="" extra_export="" dep="" jid
  while [ $# -gt 0 ]; do
    case $1 in
      --dep) deps=$2; shift 2;;
      --cores) cores=$2; shift 2;;
      --time) wall=$2; shift 2;;
      --array) array=$2; shift 2;;
      --export) extra_export=",$2"; shift 2;;
      *) kit_die "kit_submit: unknown option $1";;
    esac
  done
  [ -f "$script" ] || kit_die "no job script $script"
  bash -n "$script"
  local acct=$KIT_ACCOUNT
  if [ -z "$acct" ]; then
    [ "$DRY" = 1 ] || kit_die "KIT_ACCOUNT is empty; set it in negishi-run/config.sh or the environment"
    acct="<KIT_ACCOUNT unset>"
  fi
  # shellcheck disable=SC2086  # deps is a space-separated list of step names
  [ -n "$deps" ] && dep=$(kit_dep $deps)
  local args=(--parsable --kill-on-invalid-dep=yes "--account=$acct" "--partition=$KIT_PARTITION" "--qos=$KIT_QOS"
              "--export=ALL,KIT_DIR=$KIT_DIR,REPO_DIR=$REPO_DIR,PREP_DIR=$PREP_DIR,KIT_PURGE=$KIT_PURGE,CALL_SET=$CALL_SET$extra_export")
  [ -n "$cores" ] && args+=("--cpus-per-task=$cores")
  [ -n "$wall" ] && args+=("--time=$wall")
  if [ -n "$array" ]; then args+=("--array=$array" "--output=$LOGS/%x.%A_%a.out" "--error=$LOGS/%x.%A_%a.out")
  else args+=("--output=$LOGS/%x.%j.out" "--error=$LOGS/%x.%j.out"); fi
  [ -n "$dep" ] && args+=("--dependency=$dep")
  args+=("--job-name=$step")
  local tsv; tsv=$(kit_jobs_tsv)
  mkdir -p "$STATE"
  [ -f "$tsv" ] || printf 'step\tjobid\tsubmitted\tdependency\tscript\n' > "$tsv"
  if [ "$DRY" = 1 ]; then
    jid=$(( 9000000 + $(wc -l < "$tsv") ))
    printf '\n[%s] job %s (dry-run id %s)%s\n' "$step" "$(basename "$script")" "$jid" "${dep:+, after ${dep#afterok:}}" >&2
    grep '^#SBATCH' "$script" | sed 's/^/    /' >&2
    printf '    sbatch %s %s\n' "${args[*]}" "$script" >&2
    if [ "${KIT_TEST_ONLY:-0}" = 1 ] && command -v sbatch >/dev/null 2>&1; then
      local t a targs=()
      for a in "${args[@]}"; do case $a in --parsable|--dependency=*|--kill-on-invalid-dep=*) ;; *) targs+=("$a");; esac; done
      t=$(sbatch --test-only "${targs[@]}" "$script" 2>&1 | tail -1) || true
      printf '    test-only: %s\n' "$t" >&2
    fi
  else
    mkdir -p "$LOGS"
    jid=$(sbatch "${args[@]}" "$script") || kit_die "sbatch failed for $step"
    jid=${jid%%;*}
    kit_log "submitted $step as job $jid${dep:+ ($dep)}"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$step" "$jid" "$(kit_ts)" "${dep:--}" "$(basename "$script")" >> "$tsv"
}

# ---------------------------------------------------------------- downloads
# md5 of a GCS object, from the JSON API, as hex (empty if unavailable)
kit_gcs_md5() {  # $GCS_BASE/<bucket>/<object>
  local rest=${1#"$GCS_BASE"/} bucket obj
  bucket=${rest%%/*}; obj=${rest#*/}
  curl -fsSL --max-time 60 "$GCS_JSON_API/$bucket/o/$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$obj")" 2>/dev/null \
    | python3 -c 'import sys, json, base64, binascii; d = json.load(sys.stdin); print(binascii.hexlify(base64.b64decode(d["md5Hash"])).decode(), d.get("size", ""))' 2>/dev/null || true
}

# Links in an HTTP directory listing (one per line, relative, no parent or sort links)
kit_listing() {  # url
  curl -fsSL --max-time 120 "$1" 2>/dev/null | grep -oiE 'href="[^"?#]+"' | sed -E 's/^href="//I; s/"$//' \
    | grep -vE '^(/|\.\./|https?:|mailto:)' | sort -u || true
}

# Download with resume and retries; returns curl's status
kit_curl() {  # url dest
  mkdir -p "$(dirname "$2")"
  curl -fL --retry 5 --retry-delay 10 -C - --create-dirs -o "$2" "$1"
}

# ---------------------------------------------------------------- verified downloads
# Used by data-prep/01_fetch.sh and 05_annotation.sh. Rows go through kit_row, provenance
# through kit_prov; a verified file is not downloaded again unless FORCE=1.
# Published md5 for a file: from md5checksums.txt (NCBI) or any *md5* file captured from a listing
published_md5() {  # basename
  local b=$1 f
  for f in "$PREP_DIR/src/ref/md5checksums.txt" "$RECORDS"/terms/*/*md5* "$RECORDS"/terms/*/*MD5*; do
    [ -f "$f" ] || continue
    awk -v b="$b" '{ n = $NF; sub(/^.*\//, "", n); if (n == b && $1 ~ /^[0-9a-f]{32}$/) { print $1; exit } }' "$f"
  done | head -1
}

kit_fetch() {  # id [url] [dest] [optional:0|1]; dest defaults to $($KIT_DEST_FN id)
  local id=$1 url=${2:-} dest=${3:-} optional=${4:-}
  [ -n "$url" ] || url=$(src_url "$id")
  [ -n "$dest" ] || dest=$("$KIT_DEST_FN" "$id")
  if [ -z "$optional" ]; then
    case "$(src_field "$id" 3 2>/dev/null || true)" in optional*) optional=1;; *) optional=0;; esac
  fi
  local exp csrc
  exp=$(src_field "$id" 4 2>/dev/null || echo -)
  csrc=$(src_field "$id" 5 2>/dev/null || echo none)
  if [ "$DRY" = 1 ]; then printf '  + curl -fL -C - -o %s %s\n' "$dest" "$url" >&2; return 0; fi
  mkdir -p "$STATE/fetched"
  if [ "${FORCE:-0}" = 0 ] && [ -f "$STATE/fetched/$id.ok" ] && [ -f "$dest" ] && [ "$(stat -c %s "$dest")" = "$(cut -f1 "$STATE/fetched/$id.ok")" ]; then
    kit_row PASS "fetch $id" "already verified: $dest"; return 0
  fi
  if [ "${FORCE:-0}" = 1 ]; then rm -f "$dest"; fi
  local gmd5="" gsize=""
  if [ "$csrc" = gcs_json_api ]; then read -r gmd5 gsize <<< "$(kit_gcs_md5 "$url")" || true; fi
  # a complete file makes curl -C - fail with 416; skip the download if the size already matches
  local want=${gsize:-}; [ -z "$want" ] && [ "$exp" != - ] && want=$exp
  if ! { [ -f "$dest" ] && [ -n "$want" ] && [ "$(stat -c %s "$dest")" = "$want" ]; }; then
    kit_log "downloading $id: $url"
    local t0; t0=$(date +%s)
    if ! kit_curl "$url" "$dest"; then
      rm -f "$dest"
      if [ "$optional" = 1 ]; then kit_row WARN "fetch $id" "not available (optional): $url"; else kit_row FAIL "fetch $id" "download failed: $url"; fi
      return 0
    fi
    kit_metric fetch "$id" wall_s_download "$(( $(date +%s) - t0 ))" s
  fi
  local size md5 check="none"
  size=$(stat -c %s "$dest")
  if [ "$exp" != - ] && [ -n "$exp" ] && [ "$size" != "$exp" ]; then kit_row FAIL "size $id" "$size bytes, expected $exp"; return 0; fi
  if [ -n "$gsize" ] && [ "$size" != "$gsize" ]; then kit_row FAIL "size $id" "$size bytes, GCS reports $gsize"; return 0; fi
  md5=$(md5sum "$dest" | cut -c1-32)
  local pub=""
  case $csrc in
    gcs_json_api) pub=$gmd5; [ -n "$pub" ] || kit_row WARN "md5 $id" "GCS JSON API returned no md5Hash";;
    *) pub=$(published_md5 "$(basename "$dest")");;
  esac
  # fall back to the md5 recorded in sources.tsv (column 7) from a verified earlier download
  local rec; rec=$(src_field "$id" 7 2>/dev/null || true)
  if [ -z "$pub" ] && [ -n "$rec" ] && [ "$rec" != - ]; then pub=$rec; csrc=sources_tsv; fi
  if [ -n "$pub" ]; then
    if [ "$pub" = "$md5" ]; then check="match:$csrc"; else kit_row FAIL "md5 $id" "$md5, published $pub"; check="MISMATCH"; fi
  else
    check="computed-only"
  fi
  kit_prov "$id" "$url" "${dest#"$PREP_DIR"/}" "$size" "$md5" "$check"
  if [ "$check" = MISMATCH ]; then return 0; fi
  printf '%s\t%s\n' "$size" "$md5" > "$STATE/fetched/$id.ok"
  kit_row PASS "fetch $id" "$size bytes, md5 $md5 ($check)"
}

