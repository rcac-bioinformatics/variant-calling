#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=02:00:00
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
kit_job_begin prep-fastq
kit_load "$SAMTOOLS_MODULE" "$MOSDEPTH_MODULE"
C=$(kit_cores)
read -r -a S_ARR <<< "$SAMPLES"
S=${S_ARR[$((SLURM_ARRAY_TASK_ID - 1))]}
bam=$PREP_DIR/src/bam/$(basename "$(src_url "bam_$S")")
D=$RECORDS/source_bam/$S; mkdir -p "$D"
kit_module -t list > "$D/modules.txt" 2>&1 || true
step=prep-fastq

# ---- facts about the source BAM
samtools view -H "$bam" > "$D/header.sam"
grep '^@RG' "$D/header.sam" > "$D/read_groups.txt" || echo "no @RG lines" > "$D/read_groups.txt"
grep '^@PG' "$D/header.sam" > "$D/programs.txt" || true
fai=$PREP_DIR/src/ref/$(basename "$(src_url ref_fai)")
hlen=$(awk -v r="$REGION" -F'\t' '$1 == "@SQ" { n = ""; l = ""; for (i = 2; i <= NF; i++) { if ($i ~ /^SN:/) n = substr($i, 4); if ($i ~ /^LN:/) l = substr($i, 4) } if (n == r) print l }' "$D/header.sam")
flen=$(awk -v r="$REGION" '$1 == r { print $2 }' "$fai")
if [ -n "$hlen" ] && [ "$hlen" = "$flen" ]; then echo "PASS $REGION LN $hlen in BAM header and reference .fai" > "$D/header_vs_fai.txt"
else echo "FAIL $REGION BAM header LN '$hlen', reference .fai '$flen'" > "$D/header_vs_fai.txt"; fi
cmp -s <(awk -F'\t' '$1 == "@SQ" { print substr($2, 4) "\t" substr($3, 4) }' "$D/header.sam") <(cut -f1,2 "$fai") \
  && echo "all @SQ names and lengths match the .fai" >> "$D/header_vs_fai.txt" \
  || echo "@SQ list differs from the .fai (order, names, or lengths)" >> "$D/header_vs_fai.txt"

kit_t0 bamstats
samtools flagstat -@ "$C" "$bam" > "$D/flagstat.txt"
samtools stats -@ "$C" "$bam" > "$D/stats.txt"
grep '^SN' "$D/stats.txt" | cut -f2- > "$D/stats_SN.txt"
kit_t1 bamstats "$step" "$S"
sn() { awk -F'\t' -v k="$1" '$1 == k":" { print $2 }' "$D/stats_SN.txt"; }
kit_metric "$step" "$S" source_reads_total "$(sn 'raw total sequences')"
kit_metric "$step" "$S" source_read_length_avg "$(sn 'average length')" bp
kit_metric "$step" "$S" source_read_length_max "$(sn 'maximum length')" bp
kit_metric "$step" "$S" source_insert_size_avg "$(sn 'insert size average')" bp
kit_metric "$step" "$S" source_insert_size_sd "$(sn 'insert size standard deviation')" bp
kit_metric "$step" "$S" source_reads_duplicate_flagged "$(samtools view -c -@ "$C" -f 0x400 "$bam")"
kit_metric "$step" "$S" source_reads_qcfail "$(samtools view -c -@ "$C" -f 0x200 "$bam")"
kit_metric "$step" "$S" source_reads_secondary "$(samtools view -c -@ "$C" -f 0x100 "$bam")"
kit_metric "$step" "$S" source_reads_supplementary "$(samtools view -c -@ "$C" -f 0x800 "$bam")"
kit_metric "$step" "$S" source_reads_mate_unmapped "$(samtools view -c -@ "$C" -f 0x9 -F 0x904 "$bam")"
kit_metric "$step" "$S" "source_reads_mate_outside_$REGION" "$(samtools view -@ "$C" -f 0x1 -F 0x90C "$bam" | awk -v r="$REGION" '$7 != "=" && $7 != r' | wc -l)"
# base-quality values present (binning check): distinct quality characters in the first 200,000 reads
{ samtools view "$bam" || true; } | head -n 200000 | awk '{ print $11 }' | fold -w1 | sort | uniq -c | sort -k2 > "$D/quality_chars_first200k.txt"
kit_metric "$step" "$S" source_distinct_base_qualities_first200k "$(wc -l < "$D/quality_chars_first200k.txt")"
kit_t0 mosdepth
mosdepth -t 4 -n --fast-mode -c "$REGION" "$TMPDIR/md" "$bam"
cp "$TMPDIR/md.mosdepth.summary.txt" "$D/mosdepth.summary.txt"
kit_t1 mosdepth "$step" "$S"
kit_metric "$step" "$S" "source_mean_depth_$REGION" "$(awk -v r="$REGION" '$1 == r { print $4 }' "$D/mosdepth.summary.txt")" x

# ---- convert to paired FASTQ
F=$PREP_DIR/fastq; mkdir -p "$F"
r1=$F/${S}_R1.fastq.gz; r2=$F/${S}_R2.fastq.gz
if [ "${KIT_FORCE:-0}" = 1 ] || [ ! -s "$r2" ] || [ ! -f "$F/$S.ok" ]; then
  rm -f "$F/$S.ok"
  kit_t0 bam_to_fastq
  samtools collate -@ "$C" -u -O -T "$TMPDIR/collate" "$bam" \
    | samtools fastq -@ "$C" -n -1 "$r1" -2 "$r2" -0 /dev/null -s /dev/null - 2> "$D/samtools_fastq.log"
  kit_t1 bam_to_fastq "$step" "$S"
  touch "$F/$S.ok"
fi
n1=$(( $(zcat "$r1" | wc -l) / 4 )); n2=$(( $(zcat "$r2" | wc -l) / 4 ))
kit_metric "$step" "$S" fastq_pairs "$n1"
[ "$n1" = "$n2" ] || kit_die "R1 has $n1 reads, R2 has $n2"
kit_metric "$step" "$S" fastq_R1_bytes "$(stat -c %s "$r1")" bytes
kit_metric "$step" "$S" fastq_R2_bytes "$(stat -c %s "$r2")" bytes
(cd "$F" && md5sum "$(basename "$r1")" "$(basename "$r2")") > "$D/fastq.md5"
kit_job_end
