# data-prep/snpeff_lib.sh: SnpEff database discovery and download, shared by 05_annotation.sh
# (login node) and jobs/prep-annot.sh (compute node). Sourced after negishi-run/lib.sh, with
# the SnpEff module loaded.
# shellcheck shell=bash

SNPEFF_DATA=${SNPEFF_DATA:-$PREP_DIR/annot/snpeff_data}

# List the databases this SnpEff knows and pick the first available MANE and full database.
snpeff_pick() {
  local D=$RECORDS/annot db
  mkdir -p "$D" "$SNPEFF_DATA"
  snpEff -Xmx2g databases > "$D/snpeff_databases.txt" 2> "$D/snpeff_databases.err" || kit_die "snpEff databases failed (see $D/snpeff_databases.err)"
  grep -E '^[[:space:]]*GRCh38' "$D/snpeff_databases.txt" > "$D/snpeff_databases_GRCh38.txt" || true
  : > "$D/snpeff_candidates.tsv"
  SNPEFF_MANE=""; SNPEFF_FULL=""
  for db in $SNPEFF_DB_MANE $SNPEFF_DB_FULL; do
    if grep -qE "^[[:space:]]*${db//./\\.}[[:space:]]" "$D/snpeff_databases.txt"; then
      printf '%s\tlisted\n' "$db" >> "$D/snpeff_candidates.tsv"
      case " $SNPEFF_DB_MANE " in *" $db "*) [ -n "$SNPEFF_MANE" ] || SNPEFF_MANE=$db;; *) [ -n "$SNPEFF_FULL" ] || SNPEFF_FULL=$db;; esac
    else
      printf '%s\tnot listed\n' "$db" >> "$D/snpeff_candidates.tsv"
    fi
  done
  [ -n "$SNPEFF_MANE$SNPEFF_FULL" ] || kit_die "none of the configured SnpEff databases is listed by this SnpEff"
  printf 'SNPEFF_DATA=%q\nSNPEFF_MANE=%q\nSNPEFF_FULL=%q\n' "$SNPEFF_DATA" "$SNPEFF_MANE" "$SNPEFF_FULL" > "$STATE/snpeff.env"
}

# Download the chosen databases into SNPEFF_DATA; record time and size.
snpeff_download() {
  local D=$RECORDS/annot db t0
  for db in $SNPEFF_MANE $SNPEFF_FULL; do
    if [ -d "$SNPEFF_DATA/$db" ] && [ "${KIT_FORCE:-0}" != 1 ]; then kit_log "SnpEff $db already present"; continue; fi
    t0=$(date +%s)
    if snpEff -Xmx4g download -v -dataDir "$SNPEFF_DATA" "$db" > "$D/snpeff_download_$db.log" 2>&1; then
      kit_metric prep-annot "$db" wall_s_snpeff_download "$(( $(date +%s) - t0 ))" s
      kit_metric prep-annot "$db" snpeff_db_bytes "$(du -sb "$SNPEFF_DATA/$db" | cut -f1)" bytes
    else
      kit_log "SnpEff download of $db failed; see $D/snpeff_download_$db.log"
      printf '%s\tdownload FAILED\n' "$db" >> "$D/snpeff_candidates.tsv"
    fi
  done
  grep -ohE 'https?://[^ ]+' "$D"/snpeff_download_*.log 2>/dev/null | sort -u > "$D/snpeff_download_urls.txt" || true
}
