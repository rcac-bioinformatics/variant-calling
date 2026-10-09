#!/bin/bash
# 01_fetch.sh: download the input BAMs, the reference, and the GIAB benchmarks into
# $PREP_DIR/src, verify sizes and md5 values, and record provenance. Login node (downloads
# only, about 5 GB); run it in tmux or screen.
# Usage: bash data-prep/01_fetch.sh [--dry-run] [--force]
#   --dry-run  print what would be downloaded; download nothing
#   --force    download again even if a verified copy exists
# Writes: records/fetch.tsv (check, status, detail), records/provenance.tsv,
#         records/listings/, records/terms/, state/truth_latest.env. Exit 1 on any FAIL.
set -euo pipefail
KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../negishi-run" && pwd)
export KIT_DIR
# shellcheck source=negishi-run/lib.sh
source "$KIT_DIR/lib.sh"

FORCE=0
KIT_DEST_FN=dest_for
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY=1; shift;;
    --force) FORCE=1; shift;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) kit_die "unknown option $1";;
  esac
done
export DRY
kit_dirs
SRC=$PREP_DIR/src
mkdir -p "$SRC" "$RECORDS/listings" "$RECORDS/terms" "$STATE/fetched"
ROWS_TSV=$RECORDS/fetch.tsv
[ "$DRY" = 1 ] || printf 'check\tstatus\tdetail\n' > "$ROWS_TSV"
command -v curl >/dev/null || kit_die "curl not found"
command -v python3 >/dev/null || kit_die "python3 not found"

dest_for() {  # id -> local path
  local id=$1 url base
  url=$(src_url "$id"); base=$(basename "$url")
  case $id in
    bam_*|bai_*) echo "$SRC/bam/$base";;
    ref_*) echo "$SRC/ref/$base";;
    giab421_*) local s=${id#giab421_}; s=${s%%_*}; echo "$SRC/truth/v4.2.1/$s/$base";;
    *) echo "$SRC/other/$base";;
  esac
}

# Save a listing and every README or md5 file in it
capture_listing() {  # id url
  local id=$1 url=$2 f
  if [ "$DRY" = 1 ]; then printf '  + list %s and save README/md5 files to records/terms/%s/\n' "$url" "$id" >&2; return 0; fi
  kit_listing "$url" > "$RECORDS/listings/$id.txt"
  if [ ! -s "$RECORDS/listings/$id.txt" ]; then kit_row WARN "listing $id" "empty or unreachable: $url"; return 0; fi
  mkdir -p "$RECORDS/terms/$id"
  { grep -iE 'readme|md5' "$RECORDS/listings/$id.txt" | grep -v '/$' || true; } | while read -r f; do
    curl -fsSL --max-time 120 -o "$RECORDS/terms/$id/$(basename "$f")" "$url$f" || kit_log "could not fetch $url$f"
  done
  kit_row PASS "listing $id" "$(wc -l < "$RECORDS/listings/$id.txt") entries; saved: $(find "$RECORDS/terms/$id" -type f -printf '%f ' 2>/dev/null)"
}

# ---------------------------------------------------------------- listings first (README and md5 files)
for id in $(src_ids '_dir$'); do capture_listing "$id" "$(src_url "$id")"; done

# ---------------------------------------------------------------- reference (md5checksums first, if published)
kit_fetch ref_md5
for id in ref_fasta ref_fai ref_bwa_index; do kit_fetch "$id"; done

# ---------------------------------------------------------------- input BAMs and indexes
for id in $(src_ids '^(bam|bai)_'); do kit_fetch "$id"; done

# ---------------------------------------------------------------- GIAB v4.2.1
for id in $(src_ids '^giab421_.*_(vcf|tbi|bed|noinc_bed)$'); do kit_fetch "$id"; done

# ---------------------------------------------------------------- HG002 latest: find the GRCh38 small-variant files
latest_url=$(src_url giab_HG002_latest_dir)
if [ "$DRY" = 1 ]; then
  printf '  + walk %s (3 levels), choose the GRCh38 small-variant VCF and BED, download them to %s\n' "$latest_url" "$SRC/truth/HG002_latest/" >&2
else
  tree=$RECORDS/listings/giab_HG002_latest_tree.txt
  : > "$tree"
  walk() {  # url relpath depth
    local u=$1 rel=$2 depth=$3 e
    while read -r e; do
      [ -n "$e" ] || continue
      printf '%s%s\n' "$rel" "$e" >> "$tree"
      case $e in */) [ "$depth" -lt 3 ] && walk "$u$e" "$rel$e" $((depth + 1));; esac
    done < <(kit_listing "$u")
  }
  walk "$latest_url" "" 1
  mkdir -p "$RECORDS/terms/giab_HG002_latest"
  { grep -iE 'readme' "$tree" | grep -v '/$' || true; } | while read -r f; do
    curl -fsSL --max-time 120 -o "$RECORDS/terms/giab_HG002_latest/$(echo "$f" | tr '/' '_')" "$latest_url$f" || true
  done
  # GRCh38 small-variant VCF: GRCh38 in the path, .vcf.gz, not structural or tandem-repeat calls
  grep -E 'GRCh38' "$tree" | grep -E '\.vcf\.gz$' | grep -viE 'stvar|struct|_sv[._]|/sv/|cnv|tr[_.]|trgt|draft' > "$STATE/latest_vcf_candidates.txt" || true
  nv=$(wc -l < "$STATE/latest_vcf_candidates.txt")
  if [ "$nv" = 0 ]; then
    kit_row FAIL "HG002 latest GRCh38 small-variant VCF" "none found under $latest_url (see records/listings/giab_HG002_latest_tree.txt)"
    : > "$STATE/truth_latest.env"
  else
    # prefer names that say small variants
    vcf=$(grep -iE 'smvar|small|benchmark' "$STATE/latest_vcf_candidates.txt" | head -1 || true)
    [ -n "$vcf" ] || vcf=$(head -1 "$STATE/latest_vcf_candidates.txt")
    dir=$(dirname "$vcf")
    if [ "$dir" = . ]; then dirpat='^[^/]+$'; else dirpat="^$dir/[^/]+$"; fi
    # BED: the VCF's own name with .benchmark.bed if listed; otherwise a GRCh38 small-variant BED
    # in the same directory (the first pilot took a CHM13v2.0 BED here: never mix references)
    bed=${vcf%.vcf.gz}.benchmark.bed
    grep -qxF "$bed" "$tree" || bed=$(grep -E "$dirpat" "$tree" | grep -E '\.bed(\.gz)?$' | grep -E 'GRCh38' \
      | grep -viE 'stvar|struct|_sv[._]|cnv' | grep -iE 'smvar|small|benchmark' | head -1 || true)
    if [ "$nv" -gt 1 ]; then kit_row WARN "HG002 latest VCF candidates" "$nv found, chose $vcf: $(tr '\n' ' ' < "$STATE/latest_vcf_candidates.txt")"; fi
    if [ -z "$bed" ]; then kit_row FAIL "HG002 latest GRCh38 benchmark BED" "none next to $vcf"; fi
    {
      printf 'LATEST_VCF_URL=%q\n' "$latest_url$vcf"
      printf 'LATEST_BED_URL=%q\n' "${bed:+$latest_url$bed}"
    } > "$STATE/truth_latest.env"
    kit_row PASS "HG002 latest GRCh38 files" "vcf=$vcf bed=${bed:-none}"
    d=$SRC/truth/HG002_latest
    kit_fetch giab_HG002_latest_vcf "$latest_url$vcf" "$d/$(basename "$vcf")" 0
    if grep -qxF "$vcf.tbi" "$tree"; then kit_fetch giab_HG002_latest_tbi "$latest_url$vcf.tbi" "$d/$(basename "$vcf").tbi" 0
    else kit_row WARN "HG002 latest VCF index" "no .tbi listed; 04_truth_subsets.sh indexes it"; fi
    if [ -n "$bed" ]; then kit_fetch giab_HG002_latest_bed "$latest_url$bed" "$d/$(basename "$bed")" 0; fi
  fi
fi

# ---------------------------------------------------------------- terms pages
if [ "$DRY" != 1 ]; then
  printf 'terms_url\tsaved_as\n' > "$RECORDS/terms/index.tsv"
  n=0
  while read -r t; do
    n=$((n + 1))
    if curl -fsSL --max-time 60 -o "$RECORDS/terms/terms_$n.html" "$t"; then
      printf '%s\tterms_%s.html\n' "$t" "$n" >> "$RECORDS/terms/index.tsv"
    else kit_row WARN "terms page" "could not fetch $t"; fi
  done < <(awk -F'\t' 'NR > 1 && $6 ~ /^https?:/ { print $6 }' "$SOURCES_TSV" | sort -u)
  awk -F'\t' 'NR > 1 && $6 !~ /^https?:/ { print $1 }' "$SOURCES_TSV" | while read -r id; do
    kit_row WARN "terms $id" "no terms URL in sources.tsv; find and record it in Part C"
  done
fi

if [ "$DRY" = 1 ]; then kit_log "dry run: nothing downloaded"; exit 0; fi
kit_log "fetch: FAIL $NFAIL, WARN $NWARN; rows in $ROWS_TSV"
[ "$NFAIL" -eq 0 ]
