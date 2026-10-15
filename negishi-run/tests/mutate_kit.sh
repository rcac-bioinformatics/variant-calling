#!/bin/bash
# mutate_kit.sh: mutations of the lesson and the kit that build_kit.py --check must catch (Prompts 06
# and 06b). Each case copies the repository to $WORK/mut/r, applies one edit and runs the check.
# Called by run_all.sh, which sets REPO and WORK. Gene symbols never appear in this file: the guard
# cases take a protected symbol and an ACMG SF symbol from .claude/notes/ at run time, and are
# skipped (reported, not counted) when that folder is absent.
set -u
: "${REPO:?}" "${WORK:?}"
M=$WORK/mut; mkdir -p "$M"
n=0; caught=0; skipped=0
NL=$'\n'

copy() {
  rm -rf "$M/r"
  rsync -a --exclude negishi-run/records --exclude site --exclude negishi-run/tests "$REPO/" "$M/r/"
}

run() {  # name file old new [FAIL|PASS]
  local name=$1 file=$2 old=$3 new=$4 expect=${5:-FAIL} out rc
  copy
  if ! python3 - "$M/r/$file" "$old" "$new" <<'PY'
import sys
p, a, b = sys.argv[1:]
s = open(p).read()
if a not in s:
    sys.exit(1)
open(p, "w").write(s.replace(a, b, 1))
PY
  then n=$((n + 1)); echo "NOT APPLIED (pattern not found): $name"; return; fi
  # a PASS case runs a build: any edit makes generated/ stale for --check
  if [ "$expect" = PASS ]; then out=$(cd "$M/r" && python3 negishi-run/build_kit.py 2>&1); rc=$?
  else out=$(cd "$M/r" && python3 negishi-run/build_kit.py --check 2>&1); rc=$?; fi
  n=$((n + 1))
  if [ "$expect" = FAIL ] && [ $rc -ne 0 ] && grep -q FAIL <<< "$out"; then
    caught=$((caught + 1)); echo "caught: $name -> $(grep -m1 FAIL <<< "$out" | sed 's/^ *//' | cut -c1-150)"
  elif [ "$expect" = PASS ] && [ $rc -eq 0 ]; then
    caught=$((caught + 1)); echo "ok (passes as it should): $name"
  else
    echo "MISSED: $name (exit $rc)"; echo "$out" | tail -3
  fi
}

# symbols for the gene-name guard cases, read from the gitignored notes
read -r PROT ACMG < <(python3 - "$REPO" <<'PY'
import os, sys
notes = os.path.join(sys.argv[1], ".claude", "notes")
allow = set()
al = os.path.join(sys.argv[1], "negishi-run", "gene_allowlist.tsv")
if os.path.isfile(al):
    allow = {l.split("\t")[0] for l in open(al) if l.strip() and not l.startswith(("#", "symbol\t"))}
prot = acmg = ""
if os.path.isdir(notes):
    for f in sorted(os.listdir(notes)):
        p = os.path.join(notes, f)
        rows = [l.rstrip("\n").split("\t") for l in open(p) if l.strip() and not l.startswith("#")]
        if "acmg" in f.lower():
            acmg = acmg or (rows[0][0].strip() if rows else "")
        elif rows and "gene" in rows[0]:
            c = rows[0].index("gene")
            for r in rows[1:]:
                if c < len(r) and r[c].strip() and r[c].strip() not in allow and r[c].strip() != ".":
                    prot = prot or r[c].strip()
print(prot or "-", acmg or "-")
PY
)
guard() {  # like run, for the cases that need a symbol from the notes
  if [ "$PROT" = - ] || [ "$ACMG" = - ]; then skipped=$((skipped + 1)); echo "SKIPPED (no .claude/notes/): $1"; return; fi
  run "$@"
}

# ---- Prompt 06: lesson text, front matter, learner-script equality, accounts, URLs, markers
guard "gene-name guard (episode 7)" episodes/07-annotation.Rmd "## Step 3: Population frequencies" "## Step 3: Population frequencies ($PROT)"
guard "gene-name guard (kit README)" negishi-run/README.md "# Negishi run kit" "# Negishi run kit $PROT"
run "front matter 07" episodes/07-annotation.Rmd "teaching: 30" "teaching: 31"
run "front matter 08" episodes/08-trio-candidate-variants.Rmd "exercises: 40" "exercises: 35"
run "annotate.sh block" episodes/07-annotation.Rmd "snpEff -Xmx6g ann" "snpEff -Xmx8g ann"
run "annotate.sh submit block" episodes/07-annotation.Rmd "sbatch annotate.sh" "sbatch --array=1 annotate.sh"
run "07 interactive text" episodes/07-annotation.Rmd "awk -F'\t' '\$10 == \".\" || \$10 < 0.01'" "awk -F'\t' '\$10 == \".\" || \$10 < 0.05'"
run "08 interactive text" episodes/08-trio-candidate-variants.Rmd "GT[0]=\"AA\" && GT[1]=\"het\"" "GT[0]=\"AA\" && GT[1]=\"RA\""
run "08 extra block writes" episodes/08-trio-candidate-variants.Rmd "results/bam/HG004.markdup.bam ref/GRCh38_no_alt.fa" "results/bam/HG004.markdup.bam ref/GRCh38_no_alt.fa > tview.txt"
run "08 account" episodes/08-trio-candidate-variants.Rmd "sinteractive -A rcac" "sinteractive -A other"
run "08 cited URL not in reference.md" episodes/08-trio-candidate-variants.Rmd "([IGV desktop](https://igv.org/doc/desktop/))" "([IGV desktop](https://igv.org/doc/desktop/x))"
run "08 not-run reason" episodes/08-trio-candidate-variants.Rmd "<!-- kit: not-run desktop -->" "<!-- kit: not-run gui -->"
run "08 short-on-time path" episodes/08-trio-candidate-variants.Rmd "results/trio/mendelian2.txt \$SCRATCH" "results/trio/mendelian.txt \$SCRATCH"
run "08 --mem" episodes/08-trio-candidate-variants.Rmd "--time=1:00:00" "--time=1:00:00 --mem=8G"
run "08 unmarked fence" episodes/08-trio-candidate-variants.Rmd "<!-- kit: not-run reference -->" ""

# notes folder absent: the guard is skipped with a warning, not a failure
copy; rm -rf "$M/r/.claude/notes"
out=$(cd "$M/r" && python3 negishi-run/build_kit.py --check 2>&1); n=$((n + 1))
if grep -q "WARNING: gene-name guard skipped" <<< "$out" && ! grep -q FAIL <<< "$out"; then
  caught=$((caught + 1)); echo "caught: notes absent -> $(grep -m1 WARNING <<< "$out")"
else echo "MISSED: notes absent"; fi

# ---- Prompt 06b: IGV batch shape, allowlist, snapshot job header; Part C: truth-status order
run "batch without exit" negishi-run/kitrun.sh "    printf 'exit\\n'${NL}" ""
run "batch without sort base" negishi-run/kitrun.sh "      printf 'sort base chr20:%s\\n' \"\$p\"${NL}" ""
run "batch without center line" negishi-run/kitrun.sh "    printf 'preference SAM.SHOW_CENTER_LINE true\\n'${NL}" ""
run "batch sort outside window" negishi-run/kitrun.sh "printf 'sort base chr20:%s\\n' \"\$p\"" "printf 'sort base chr20:%s\\n' \"\$((p + 100))\""
run "batch undocumented command" negishi-run/kitrun.sh "    printf 'exit\\n'" "    printf 'squish\\n'; printf 'exit\\n'"
run "batch genome not the staged reference" negishi-run/kitrun.sh "printf 'genome %s\\n' \"\$W/ref/GRCh38_no_alt.fa\"" "printf 'genome %s\\n' hg38"
run "batch PNG name changed" negishi-run/kitrun.sh "printf 'snapshot 08_%s_chr20_%s.png\\n'" "printf 'snapshot 8_%s_chr20_%s.png\\n'"
run "batch with new before genome (the Negishi NPE)" negishi-run/kitrun.sh "    printf 'genome %s\\n' \"\$W/ref/GRCh38_no_alt.fa\"${NL}    printf 'new\\n'${NL}" "    printf 'new\\n'${NL}    printf 'genome %s\\n' \"\$W/ref/GRCh38_no_alt.fa\"${NL}"
guard "protected symbol next to the allowlisted one" episodes/07-annotation.Rmd "in the gene *R3HDML*." "in the gene *R3HDML* (near $PROT)."
guard "protected ACMG symbol in a kit file" negishi-run/config.sh "# negishi-run/config.sh:" "# $ACMG negishi-run/config.sh:"
guard "allowlist row without a log entry" negishi-run/gene_allowlist.tsv "symbol	reason	decided	log_entry" "symbol	reason	decided	log_entry${NL}$PROT	test	2026-10-14	no such entry"
guard "allowlist an ACMG symbol (valid log entry)" negishi-run/gene_allowlist.tsv "symbol	reason	decided	log_entry" "symbol	reason	decided	log_entry${NL}$ACMG	test	2026-10-14	Phase 6 Part A decisions and headless IGV snapshots, 2026-10-14"
run "allowlist row with 3 fields" negishi-run/gene_allowlist.tsv "	2026-10-14	Phase 6 Part A decisions" " 2026-10-14	Phase 6 Part A decisions"
run "snapshot job with --mem" negishi-run/igv/run_snapshots.sh "#SBATCH --time=00:20:00" "#SBATCH --time=00:20:00${NL}#SBATCH --mem=8G"
run "snapshot job other account" negishi-run/igv/run_snapshots.sh "#SBATCH --account=rcac" "#SBATCH --account=other"
run "truth-status reports a record before the BED (the P3 order)" pipeline/py/report.py "                if not bed.has(chrom, pos):${NL}                    row.append(\"outside_bed\")${NL}                    continue${NL}" ""
run "truth-status: record outside the BED becomes absent_in_bed" pipeline/py/report.py "row.append(\"outside_bed\")${NL}                    continue" "row.append(\"absent_in_bed\")${NL}                    continue"
run "allowlisted symbol alone (control)" episodes/07-annotation.Rmd "Look at its row" "Look at its row (R3HDML)" PASS

echo "kit mutations: $caught of $n caught${skipped:+, $skipped skipped}"
rm -rf "$M/r"
[ "$caught" -eq "$n" ]
