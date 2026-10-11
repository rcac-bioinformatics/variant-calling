#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --time=02:00:00
# stage-build: assemble both staged copies in STAGE_BUILD (scratch) from the phase-2 prep outputs,
# then write their manifests. Never touches Depot; restage.sh --install copies the result.
#   varcall-workshop/      data/ (FASTQ, md5sums.txt, samples.tsv, trio.ped), resources/ (truth
#                          subsets and BEDs, trio regions, gnomAD subset, chunk regions,
#                          centromere), scripts/ (pipeline/learner-scripts/*.sh)
#   varcall-workshop_ref/  GRCh38_no_alt.fa with .fai, .dict and the NCBI bwa index under the
#                          same prefix, GRCh38_no_alt.sdf (RTG, built with the rtg inside the
#                          hap.py image), snpeff_data/<SNPEFF_DB>, SOURCES.tsv
# Large files are hard links to the prep copies. Reruns overwrite files in place and never
# delete; an existing SDF stops the job (remove it by hand to rebuild).
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
kit_job_begin stage-build
step=stage-build
for e in ref bwa gnomad snpeff truth_latest; do
  [ -s "$STATE/$e.env" ] || kit_die "missing $STATE/$e.env: the phase-2 data prep is incomplete"
  # shellcheck source=/dev/null
  source "$STATE/$e.env"
done
kit_load "$BCFTOOLS_MODULE" "$HTSLIB_MODULE" "$SAMTOOLS_MODULE"
L=$STAGE_BUILD/varcall-workshop; F=$STAGE_BUILD/varcall-workshop_ref; D=$RECORDS/stage
mkdir -p "$L/data" "$L/resources/truth" "$L/resources/gnomad" "$L/resources/regions" "$L/scripts" "$F" "$D"
ROWS_TSV=$D/stage_rows.tsv; printf 'check\tstatus\tdetail\n' > "$ROWS_TSV"
lnf() { ln -f "$1" "$2" 2>/dev/null || cp -f "$1" "$2"; }

# ---------------------------------------------------------------- reference copy
R=$F/GRCh38_no_alt.fa
lnf "$REF_FA" "$R"; lnf "$REF_FA.fai" "$R.fai"
for e in amb ann bwt pac sa; do lnf "$BWA_PREFIX.$e" "$R.$e"; done
samtools dict -a GRCh38 -s "Homo sapiens" -u GRCh38_no_alt.fa -o "$F/GRCh38_no_alt.dict" "$R"
mkdir -p "$F/snpeff_data"
[ -d "$SNPEFF_DATA/$SNPEFF_DB" ] || kit_die "SnpEff database $SNPEFF_DB not in $SNPEFF_DATA"
cp -alf "$SNPEFF_DATA/$SNPEFF_DB" "$F/snpeff_data/"
# RTG SDF with the rtg that hap.py itself calls, through the hap.py module's container command
kit_load "$HAPPY_MODULE"
PRE=$(kit_wrapper_prefix hap.py)
[ -n "$PRE" ] || kit_die "no container command in the hap.py wrapper: $(type hap.py 2>&1 | head -5)"
RTG=$(kit_happy_rtg "$PRE")
[ -n "$RTG" ] || kit_die "no rtg in the hap.py image ($PRE)"
# shellcheck disable=SC2086  # PRE is the wrapper's command prefix, split on purpose
# diagnostics only: the launcher may fail here ("Unable to execute java"); kit_rtg_format has fallbacks
{ printf 'container command\t%s\nrtg path in the image\t%s\n' "$PRE" "$RTG"; $PRE "$RTG" version 2>&1 | head -5 || true; } > "$D/rtg.txt"
if [ -d "$F/GRCh38_no_alt.sdf" ]; then
  kit_row INFO "SDF" "exists, kept: $F/GRCh38_no_alt.sdf"
else
  kit_t0 sdf
  way=$(kit_rtg_format "$PRE" "$RTG" "$F/GRCh38_no_alt.sdf" "$R" 8g "$D/rtg_format.log") \
    || kit_die "rtg format failed every way (see $D/rtg_format.log)"
  kit_t1 sdf "$step" ref
  kit_row INFO "SDF" "built with way $way of kit_rtg_format"
fi
# kit_load purges, so loading hap.py above dropped samtools and bcftools: load them again
kit_load "$BCFTOOLS_MODULE" "$HTSLIB_MODULE" "$SAMTOOLS_MODULE"
{
  printf 'file\tfrom\tsource_id\tnote\n'
  printf 'GRCh38_no_alt.fa\t%s\tref_fasta\tgunzipped NCBI GCA_000001405.15 no-alt analysis set\n' "$(basename "$REF_FA")"
  printf 'GRCh38_no_alt.fa.fai\t%s\tref_fai\tNCBI\n' "$(basename "$REF_FA").fai"
  printf 'GRCh38_no_alt.fa.{amb,ann,bwt,pac,sa}\t%s\tref_bwa_index\tNCBI bwa index (bwa 0.7.17)\n' "$(basename "$BWA_PREFIX")"
  printf 'GRCh38_no_alt.dict\t-\t-\tsamtools dict (%s)\n' "$SAMTOOLS_MODULE"
  printf 'GRCh38_no_alt.sdf\t-\t-\trtg format, rtg from the %s image\n' "$HAPPY_MODULE"
  printf 'snpeff_data/%s\t-\tsnpeff_db\tSnpEff 5.3a database download\n' "$SNPEFF_DB"
} > "$F/SOURCES.tsv"

# ---------------------------------------------------------------- learner copy: data
read -r -a S_ARR <<< "$SAMPLES"; read -r -a R_ARR <<< "$SAMPLE_ROLES"; read -r -a X_ARR <<< "$SAMPLE_SEX"
printf 'sample\trole\tsex\tfamily\tfastq_r1\tfastq_r2\trg_id\trg_lb\trg_pl\n' > "$L/data/samples.tsv"
for i in "${!S_ARR[@]}"; do
  s=${S_ARR[$i]}
  for r in R1 R2; do lnf "$PREP_DIR/fastq/${s}_$r.fastq.gz" "$L/data/${s}_$r.fastq.gz"; done
  hdr=$(samtools view -H "$PREP_DIR/src/bam/$(basename "$(src_url "bam_$s")")")   # whole header first: grep -m1 on a pipe can SIGPIPE samtools
  rg=$(printf '%s\n' "$hdr" | grep -m1 '^@RG' || true)
  [ -n "$rg" ] || kit_die "no @RG line in the $s source BAM header"
  id=$(printf '%s' "$rg" | tr '\t' '\n' | sed -n 's/^ID://p'); lb=$(printf '%s' "$rg" | tr '\t' '\n' | sed -n 's/^LB://p')
  printf '%s\t%s\t%s\tAJ\t%s_R1.fastq.gz\t%s_R2.fastq.gz\t%s\t%s\tILLUMINA\n' "$s" "${R_ARR[$i]}" "${X_ARR[$i]}" "$s" "$s" "$id" "$lb" >> "$L/data/samples.tsv"
done
( cd "$L/data" && md5sum ./*.fastq.gz | sed 's#  \./#  #' > md5sums.txt )
{
  printf 'AJ\t%s\t%s\t%s\t%s\t0\n' "${S_ARR[0]}" "${S_ARR[1]}" "${S_ARR[2]}" "${X_ARR[0]}"
  printf 'AJ\t%s\t0\t0\t%s\t0\n' "${S_ARR[1]}" "${X_ARR[1]}"
  printf 'AJ\t%s\t0\t0\t%s\t0\n' "${S_ARR[2]}" "${X_ARR[2]}"
} > "$L/data/trio.ped"

# ---------------------------------------------------------------- resources: truth sets
T=$L/resources/truth
sub() {  # src_vcf src_bed out_prefix
  bcftools view -r "$REGION" -Oz -o "$3.vcf.gz" "$1"
  bcftools index -t -f "$3.vcf.gz"
  awk -v r="$REGION" 'BEGIN { OFS = "\t" } $1 == r { print $1, $2, $3 }' "$2" > "$3.bed"
  [ -s "$3.bed" ] || kit_die "no $REGION intervals in $2"
  kit_metric "$step" "$(basename "$3")" records "$(bcftools index -n "$3.vcf.gz")"
  kit_metric "$step" "$(basename "$3")" bed_bp "$(awk '{ s += $3 - $2 } END { print s }' "$3.bed")" bp
}
printf 'sample\ttruth\tvcf\tbed\n' > "$T/truth_sets.tsv"
LB=$(basename "$LATEST_BED_URL"); case $LB in *GRCh38*) ;; *) kit_die "HG002 latest BED is not GRCh38: $LB";; esac
sub "$PREP_DIR/src/truth/HG002_latest/$(basename "$LATEST_VCF_URL")" "$PREP_DIR/src/truth/HG002_latest/$LB" "$T/HG002_v5.0q_chr20"
printf 'HG002\tv5.0q\tHG002_v5.0q_chr20.vcf.gz\tHG002_v5.0q_chr20.bed\n' >> "$T/truth_sets.tsv"
beds=()
for s in "${S_ARR[@]}"; do
  d=$PREP_DIR/src/truth/v4.2.1/$s
  sub "$d/$(basename "$(src_url "giab421_${s}_vcf")")" "$d/$(basename "$(src_url "giab421_${s}_noinc_bed")")" "$T/${s}_v4.2.1_chr20"
  printf '%s\tv4.2.1\t%s_v4.2.1_chr20.vcf.gz\t%s_v4.2.1_chr20.bed\n' "$s" "$s" "$s" >> "$T/truth_sets.tsv"
  beds+=("$T/${s}_v4.2.1_chr20.bed")
done
python3 "$KIT_DIR/py/bed_intersect.py" "${beds[@]}" > "$T/trio_v4.2.1_chr20.bed" 2> "$D/trio_bed.txt"
kit_metric "$step" trio_v4.2.1_chr20 bed_bp "$(awk '{ s += $3 - $2 } END { print s }' "$T/trio_v4.2.1_chr20.bed")" bp

# ---------------------------------------------------------------- resources: gnomAD, regions
lnf "$GNOMAD_AF" "$L/resources/gnomad/gnomad.genomes.v4.1.chr20.af.vcf.gz"
lnf "$GNOMAD_AF.tbi" "$L/resources/gnomad/gnomad.genomes.v4.1.chr20.af.vcf.gz.tbi"
python3 "$KIT_DIR/py/chunk_regions.py" "$R" "$REGION" "$CALL_CHUNKS" > "$L/resources/regions/chr20_chunks.txt" 2> "$D/chunks.txt"
cat "$D/chunks.txt" >&2
cen=$PREP_DIR/src/other/$(basename "$(src_url ucsc_centromeres)")
kit_fetch ucsc_centromeres "$(src_url ucsc_centromeres)" "$cen" 0
[ -s "$cen" ] || kit_die "centromere table not downloaded (see $ROWS_TSV)"
zcat "$cen" | awk -v r="$REGION" 'BEGIN { OFS = "\t" } $2 == r { if (s == "" || $3 < s) s = $3; if ($4 > e) e = $4 } END { if (s != "") print r, s, e }' \
  > "$L/resources/regions/chr20_centromere.bed"
[ -s "$L/resources/regions/chr20_centromere.bed" ] || kit_die "no $REGION rows in $cen"
cat "$L/resources/regions/chr20_centromere.bed" > "$D/centromere.bed"

# ---------------------------------------------------------------- scripts and manifests
cp -f "$REPO_DIR"/pipeline/learner-scripts/*.sh "$L/scripts/"
python3 "$KIT_DIR/make_staged_manifest.py" "$L" "$KIT_DIR/staged_manifest.tsv" \
  --note "stage-build $(date +%F) from $PREP_DIR (phase-2 prep) and pipeline/learner-scripts"
python3 "$KIT_DIR/make_staged_manifest.py" "$F" "$KIT_DIR/staged_ref_manifest.tsv" \
  --note "stage-build $(date +%F) from $PREP_DIR/ref, annot/snpeff_data and rtg format"
cp "$KIT_DIR/staged_manifest.tsv" "$KIT_DIR/staged_ref_manifest.tsv" "$D/"
du -sb "$L" "$F" > "$D/sizes.txt"
kit_job_end
