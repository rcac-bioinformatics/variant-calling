#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
# P-annot, trio part: sample order, +mendelian2 counts with the configured pedigree, naive de
# novo and recessive candidate counts from genotype expressions, gnomAD annotation, and
# HIGH/MODERATE and rare protein-altering counts in the child. All counts are pilot values.
# Counts come from bcftools query + awk, which needs no quoted strings: in the first pilot the
# expression GT[0]="het" failed on Negishi with 'the tag "het" is not defined', while the same
# expression works in the stock bcftools 1.17 container, which points at the module wrapper
# dropping embedded double quotes. The -i filter forms are kept as a cross-check (ERROR if they
# fail, not fatal) and the wrapper definition is saved. The job exits non-zero at the end if an
# awk count or +mendelian2 failed; the first pilot lost every count to silent zeros.
set -euo pipefail
# shellcheck source=negishi-run/lib.sh
source "${KIT_DIR:?KIT_DIR must be exported by the submitter}/lib.sh"
step=$(kit_set_step p-trio)
kit_job_begin "$step"
# shellcheck source=/dev/null
source "$STATE/ref.env"
# shellcheck source=/dev/null
source "$STATE/gnomad.env"
# shellcheck source=/dev/null
source "$STATE/ann_${SNPEFF_RUN:?SNPEFF_RUN must be exported by the submitter}.env"
kit_load "$BCFTOOLS_MODULE" "$HTSLIB_MODULE"
V=$PREP_DIR/$(kit_set_dir)/call/trio.norm.vcf.gz
O=$PREP_DIR/$(kit_set_dir)/trio; D=$RECORDS/$(kit_set_dir)/trio; mkdir -p "$O" "$D"
kit_module -t list > "$D/modules.txt" 2>&1 || true

# ---- sample order: resolve each configured ID to a VCF sample name
bcftools query -l "$V" > "$D/sample_order_vcf.txt"
names=()
for s in $SAMPLES; do
  n=$(grep -x "$s" "$D/sample_order_vcf.txt" || grep -m1 "$s" "$D/sample_order_vcf.txt" || true)
  [ -n "$n" ] || kit_die "sample $s not found in the VCF (see $D/sample_order_vcf.txt)"
  names+=("$n")
done
child=${names[0]}; father=${names[1]}; mother=${names[2]}
printf 'child\t%s\nfather\t%s\nmother\t%s\n' "$child" "$father" "$mother" > "$D/sample_roles.tsv"
read -r -a SEX <<< "$SAMPLE_SEX"
printf '%s\t%s\t%s\t%s\t%s\t0\n' \
  "$FAMILY_ID" "$child" "$father" "$mother" "${SEX[0]}" \
  "$FAMILY_ID" "$father" 0 0 "${SEX[1]}" \
  "$FAMILY_ID" "$mother" 0 0 "${SEX[2]}" > "$O/trio.ped"
cp "$O/trio.ped" "$D/"
ordered=$O/trio.ordered.vcf.gz
bcftools view -s "$child,$father,$mother" -Oz -o "$ordered" "$V"; bcftools index -t -f "$ordered"

NERR=0
: > "$D/count_errors.txt"
cntm() {  # sample metric bcftools-view-args...: filter-expression cross-check; ERROR is not fatal
  local s=$1 k=$2 n; shift 2
  printf '== %s %s: bcftools view -H %s\n' "$s" "$k" "$*" >> "$D/count_errors.txt"
  if n=$(bcftools view -H "$@" 2>> "$D/count_errors.txt" | wc -l); then kit_metric "$step" "$s" "${k}_filter" "$n"
  else kit_metric "$step" "$s" "${k}_filter" ERROR; fi
}
# How the module provides bcftools (function, alias or wrapper script) and an argument echo test
{ type bcftools 2>&1 || true
  f=$(command -v bcftools || true)
  if [ -n "$f" ] && [ -f "$f" ] && [ "$(stat -c %s "$f")" -lt 20000 ] && grep -Iq . "$f"; then printf '\n==== %s\n' "$f"; head -c 6000 "$f"; fi
  printf '\n==== quoted-expression probe\n'
  bcftools view -H -i 'GT[0]="het"' "$ordered" 2>&1 | head -2 | cut -c1-200 || true
} > "$D/bcftools_wrapper.txt"

# ---- Mendelian consistency. bcftools 1.17 lists -P/--ped in +mendelian2 -h but rejects it
# ("invalid option -- 'P'"), so the trio goes in with -p child,father,mother (autosomal rules).
bcftools +mendelian2 -h > "$D/mendelian2_help.txt" 2>&1 || true
if bcftools +mendelian2 -m c -p "$child,$father,$mother" "$ordered" > "$D/mendelian2_counts.txt" 2> "$D/mendelian2.err"; then
  { kit_pilot_header; cat "$D/mendelian2_counts.txt"; } > "$D/mendelian2_counts.pilot.txt"
else
  echo "FAILED: see mendelian2.err and mendelian2_help.txt" > "$D/mendelian2_counts.pilot.txt"; NERR=$((NERR + 1))
fi

# ---- filter-expression syntax that bcftools accepts for the trio genotypes (child, father,
# mother = sample 0, 1, 2). 1.17 rejected GT[0]="het" in the first pilot; record what works.
{ kit_pilot_header; printf 'syntax\texpression\tstatus\trecords\terror\n'; } > "$D/gt_syntax_test.tsv"
syn() {  # name expression
  local n st=PASS
  n=$(bcftools view -H -i "$2" "$ordered" 2> "$O/syn_$1.err" | wc -l) || { st=FAIL; n=-; }
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$st" "$n" "$(head -1 "$O/syn_$1.err" | tr '\t' ' ')" >> "$D/gt_syntax_test.tsv"
}
syn keyword_sub 'GT[0]="het" && GT[1]="RR" && GT[2]="RR"'
syn keyword_ref 'GT[0]="het" && GT[1]="ref" && GT[2]="ref"'
syn string_sub 'GT[0]="0/1" && GT[1]="0/0" && GT[2]="0/0"'
syn string_sub_rx 'GT[0]~"0.1" && GT[1]~"0.0" && GT[2]~"0.0"'
syn sample_set 'GT[1,2]="RR" && GT[0]="het"'

# ---- naive candidates, counted with query + awk so the count does not depend on filter syntax.
# Tiers: all calls; QUAL>=30 and DP>=10 in all three; that plus the child's v4.2.1
# benchmark regions (bcftools view -T). Multiallelic sites were split by norm, so GT is 0/1-coded.
kid_bed=$(awk -F'\t' -v s="$child" '$1 == s && $2 == "v4.2.1" { print $4 }' "$PREP_DIR/truth/truth_sets.tsv")
[ -s "$kid_bed" ] || kit_die "no v4.2.1 benchmark BED for $child in truth/truth_sets.tsv"
{ kit_pilot_header; printf 'tier\tdenovo_snps\tdenovo_indels\trecessive_snps\trecessive_indels\tsites_snps\tsites_indels\n'; } > "$D/naive_candidates.tsv"
tier() {  # name [extra bcftools view args]
  local t=$1; shift
  bcftools view "$@" -Ou "$ordered" | bcftools query -f '%TYPE\t%QUAL[\t%GT\t%DP]\n' \
    | awk -F'\t' -v t="$t" -v q="$([ "$t" = all ] && echo 0 || echo 30)" -v d="$([ "$t" = all ] && echo 0 || echo 10)" '
      function het(g) { return g == "0/1" || g == "1/0" || g == "0|1" || g == "1|0" }
      function rr(g) { return g == "0/0" || g == "0|0" }
      function aa(g) { return g == "1/1" || g == "1|1" }
      { k = ($1 == "SNP") ? "s" : (($1 == "INDEL") ? "i" : "") ; if (k == "") next
        if ($2 != "." && $2 + 0 < q) next
        if (($4 == "." ? 0 : $4) < d || ($6 == "." ? 0 : $6) < d || ($8 == "." ? 0 : $8) < d) next
        n[k]++
        if (het($3) && rr($5) && rr($7)) dn[k]++
        if (aa($3) && het($5) && het($7)) rc[k]++ }
      END { printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\n", t, dn["s"], dn["i"], rc["s"], rc["i"], n["s"], n["i"] }'
}
for spec in all q30dp10 q30dp10_bench; do
  case $spec in
    all|q30dp10) row=$(tier "$spec") || { row="$spec	ERROR"; NERR=$((NERR + 1)); };;
    q30dp10_bench) row=$(tier "$spec" -T "$kid_bed") || { row="$spec	ERROR"; NERR=$((NERR + 1)); };;
  esac
  printf '%s\n' "$row" >> "$D/naive_candidates.tsv"
  IFS=$'\t' read -r _ a b c e _ _ <<< "$row"
  kit_metric "$step" trio "naive_denovo_snps_$spec" "${a:-ERROR}"
  kit_metric "$step" trio "naive_denovo_indels_$spec" "${b:-ERROR}"
  kit_metric "$step" trio "naive_recessive_snps_$spec" "${c:-ERROR}"
  kit_metric "$step" trio "naive_recessive_indels_$spec" "${e:-ERROR}"
done
# Expressions for the annotated counts below: the first form the syntax test accepted
syn_ok() { awk -F'\t' -v n="$1" '$1 == n && $3 == "PASS" { f = 1 } END { exit !f }' "$D/gt_syntax_test.tsv"; }
if syn_ok string_sub; then DN='GT[0]="0/1" && GT[1]="0/0" && GT[2]="0/0"'; RC='GT[0]="1/1" && GT[1]="0/1" && GT[2]="0/1"'
elif syn_ok keyword_sub; then DN='GT[0]="het" && GT[1]="RR" && GT[2]="RR"'; RC='GT[0]="AA" && GT[1]="het" && GT[2]="het"'
else DN='GT[0]~"0.1" && GT[1]~"0.0" && GT[2]~"0.0"'; RC='GT[0]~"1.1" && GT[1]~"0.1" && GT[2]~"0.1"'; fi
printf 'chosen for annotated counts: DN=%s RC=%s\n' "$DN" "$RC" >> "$D/gt_syntax_test.tsv"

# ---- gnomAD frequencies on the annotated VCF (renamed gnomad_<field>, so they do not clash with
# INFO/AC, AN). annotate -a needs an indexed file, not a pipe ("not compressed with bgzip").
cols=$(sed 's#.*#INFO/gnomad_&:=INFO/&#' "$RECORDS/annot/gnomad_kept_fields.txt" | paste -sd, -)
annin=$O/trio.ann.ordered.vcf.gz
ann=$O/trio.ann.gnomad.vcf.gz
bcftools view -s "$child,$father,$mother" -Oz -o "$annin" "$ANN_VCF"; bcftools index -t -f "$annin"
bcftools annotate -a "$GNOMAD_AF" -c "$cols" -Oz -o "$ann" "$annin" 2> "$D/annotate.err"
bcftools index -t -f "$ann"
bcftools view -h "$ann" | grep -E '^##INFO=<ID=(gnomad_|ANN)' > "$D/annotated_info_fields.txt" || true

# ---- the child's variants: impact and frequency
kid=$O/child.ann.gnomad.vcf.gz
bcftools view -s "$child" -c 1 -Oz -o "$kid" "$ann"; bcftools index -t -f "$kid"   # -c 1: carried by the child
# ANN impact is a pipe-delimited field. Bracket the pipes: in bcftools' POSIX regex "\|HIGH\|"
# is alternation with empty branches and matches every record (seen in the local 1.17 test).
HI='INFO/ANN ~ "[|]HIGH[|]"'; MO='INFO/ANN ~ "[|]MODERATE[|]"'
RARE="(INFO/gnomad_AF<$RARE_AF || INFO/gnomad_AF=\".\")"
RARE_G="(INFO/gnomad_AF_$GNOMAD_REQUIRED_GROUP<$RARE_AF || INFO/gnomad_AF_$GNOMAD_REQUIRED_GROUP=\".\")"
# authoritative counts: query + awk on the trio file (child = first sample), no quoted strings
{ kit_pilot_header; printf 'metric\tvalue\n'; } > "$D/child_counts.tsv"
bcftools query -f "%INFO/ANN\t%INFO/gnomad_AF\t%INFO/gnomad_AF_${GNOMAD_REQUIRED_GROUP}[\t%GT]\n" "$ann" \
  | awk -F'\t' -v r="$RARE_AF" -v g="$GNOMAD_REQUIRED_GROUP" '
    function alt(x) { return x ~ /1/ }
    function het(x) { return x == "0/1" || x == "1/0" || x == "0|1" || x == "1|0" }
    function rr(x) { return x == "0/0" || x == "0|0" }
    function aa(x) { return x == "1/1" || x == "1|1" }
    { hi = index($1, "|HIGH|") > 0; mo = index($1, "|MODERATE|") > 0; pa = hi || mo
      rare = ($2 == "." || $2 + 0 < r); rareg = ($3 == "." || $3 + 0 < r)
      if (pa && rare && het($4) && rr($5) && rr($6)) dn++
      if (pa && rare && aa($4) && het($5) && het($6)) rc++
      if (!alt($4)) next
      n++; h += hi; m += mo; if (pa && rare) rp++; if (pa && rareg) rpg++; if ($2 == ".") ng++ }
    END { printf "variants_carried\t%d\nhigh_impact\t%d\nmoderate_impact\t%d\nrare_protein_altering_global\t%d\n", n, h, m, rp
          printf "rare_protein_altering_%s\t%d\nno_gnomad_record\t%d\n", g, rpg, ng
          printf "naive_denovo_protein_altering_rare\t%d\nnaive_recessive_protein_altering_rare\t%d\n", dn, rc }' \
  > "$O/child_counts.body" || { NERR=$((NERR + 1)); echo "ERROR" > "$O/child_counts.body"; }
cat "$O/child_counts.body" >> "$D/child_counts.tsv"
while IFS=$'\t' read -r k v; do
  case $k in naive_*) kit_metric "$step" trio "$k" "$v";; ERROR) ;; *) kit_metric "$step" "$child" "$k" "$v";; esac
done < "$O/child_counts.body"

# cross-checks with filter expressions (recorded as <metric>_filter)
cntm "$child" variants_carried "$kid"
cntm "$child" high_impact -i "$HI" "$kid"
cntm "$child" moderate_impact -i "$MO" "$kid"
cntm "$child" rare_protein_altering_global -i "($HI || $MO) && $RARE" "$kid"
cntm "$child" "rare_protein_altering_$GNOMAD_REQUIRED_GROUP" -i "($HI || $MO) && $RARE_G" "$kid"
cntm "$child" no_gnomad_record -i 'INFO/gnomad_AF="."' "$kid"
cntm trio naive_denovo_protein_altering_rare -i "$DN && ($HI || $MO) && $RARE" "$ann"
cntm trio naive_recessive_protein_altering_rare -i "$RC && ($HI || $MO) && $RARE" "$ann"

# ---- SnpSift cross-check of the HIGH count
kit_load "$SNPSIFT_MODULE"
if zcat "$kid" | SnpSift filter "(ANN[*].IMPACT = 'HIGH')" > "$O/child.high.snpsift.vcf" 2> "$D/snpsift.err"; then
  kit_metric "$step" "$child" high_impact_snpsift "$(grep -vc '^#' "$O/child.high.snpsift.vcf" || true)"
else
  echo "SnpSift filter failed; see snpsift.err" > "$D/snpsift_status.txt"
fi
[ "$NERR" -eq 0 ] || kit_die "$NERR count(s) failed; see $D/count_errors.txt and gt_syntax_test.tsv"
kit_job_end
