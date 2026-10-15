#!/bin/bash
# igv_stubs.sh: negishi-run/igv/run_snapshots.sh under stubbed sbatch, singularity, samtools,
# xvfb-run and IGV (tests/stubs/igv/), in $WORK/igv (Prompt 06b). Each test gets a new run directory.
# Called by run_all.sh (REPO, WORK).
# shellcheck disable=SC2010,SC2012  # ls on fixed test file names only
set -u
: "${REPO:?}" "${WORK:?}"
T=$WORK/igv
mkdir -p "$T"
cp -r "$REPO/negishi-run/tests/stubs/igv/." "$T/"
mkdir -p "$T/imgx" "$T/spool" "$T/kit-runs" "$T/scratch"
cp -f "$T/host/xvfb-run" "$T/imgx/xvfb-run"
chmod +x "$T"/bin/* "$T"/img/* "$T"/host/* "$T"/imgx/*
export STUB_IMG=$T/img STUB_IMGX=$T/imgx STUB_SPOOL=$T/spool
export KIT_RUNS=$T/kit-runs SCRATCH=$T/scratch KIT_PURGE=0
export STAGED_REF=$T/depot/workshop/data/varcall-workshop_ref STAGED_REF_MANIFEST=$T/ref_manifest.tsv
export IGV_SIF=$T/igv.sif
: > "$IGV_SIF"
# the staged reference (tiny) and its manifest rows
mkdir -p "$STAGED_REF"
printf '>chr20\nACGTACGTAC\n' > "$STAGED_REF/GRCh38_no_alt.fa"
printf 'chr20\t10\t7\t10\t11\n' > "$STAGED_REF/GRCh38_no_alt.fa.fai"
{ printf 'path\ttype\tbytes\tmd5\tneed\tsource\n'
  for f in GRCh38_no_alt.fa GRCh38_no_alt.fa.fai; do
    printf '%s\tfile\t%s\t%s\trequired\ttest\n' "$f" "$(stat -c %s "$STAGED_REF/$f")" "$(md5sum < "$STAGED_REF/$f" | cut -c1-32)"
  done; } > "$STAGED_REF_MANIFEST"
# module: kit_load calls it (Lmod is not here)
module() { echo "module $*" >> "$STUB_LOG"; }
export -f module

fixture() {  # run id -> a run directory in the state after 08-trio
  local R=$KIT_RUNS/$1 W
  W=$R/scratch/varcall-workshop
  mkdir -p "$R"/{records,logs,markers} "$W"/{ref,results/bam,results/vcf,resources/truth}
  printf 'RUN=%q\nRUN_ID=%q\nW=%q\nKIT_LEARNER_SCRATCH=%q\nKIT_HOME=%q\n' "$R" "$1" "$W" "$R/scratch" "$R/home" > "$R/kit.env"
  ln -s "$STAGED_REF/GRCh38_no_alt.fa" "$W/ref/GRCh38_no_alt.fa"
  ln -s "$STAGED_REF/GRCh38_no_alt.fa.fai" "$W/ref/GRCh38_no_alt.fa.fai"
  for s in HG002 HG003 HG004; do echo bam > "$W/results/bam/$s.markdup.bam"; echo csi > "$W/results/bam/$s.markdup.bam.csi"; done
  echo vcf > "$W/results/vcf/trio.filtered.vcf.gz"; echo csi > "$W/results/vcf/trio.filtered.vcf.gz.csi"
  printf 'chr20\t0\t10\n' > "$W/resources/truth/trio_v4.2.1_chr20.bed"
  # the batch, from the kit's own generator
  ( export KIT_DIR=$REPO/negishi-run PREP_DIR=$T/prep
    # shellcheck source=/dev/null
    source "$REPO/negishi-run/kitrun.sh"
    # shellcheck disable=SC2034  # RUN and RECORDS are read by kit_igv_batch
    RUN=$R RECORDS=$R/records
    kit_igv_batch 2> /dev/null )
}

N=0; OK=0
expect() {  # name want(0|1) rc
  N=$((N + 1))
  if { [ "$2" = 0 ] && [ "$3" = 0 ]; } || { [ "$2" = 1 ] && [ "$3" != 0 ]; }; then OK=$((OK + 1)); echo "PASS: $1 (exit $3)"
  else echo "FAILED TEST: $1 (exit $3, wanted $([ "$2" = 0 ] && echo 0 || echo nonzero))"; fi
}
submit() {  # run id, extra args...; the host PATH gets the stubs; xvfb-run on the host unless NOHOSTX=1
  local id=$1; shift
  export STUB_LOG=$KIT_RUNS/$id.stub.log
  : > "$STUB_LOG"
  local p=$T/bin:$PATH; [ "${NOHOSTX:-0}" = 1 ] || p=$T/host:$p
  ( cd "$REPO" && env -u KIT_DIR PATH="$p" sbatch negishi-run/igv/run_snapshots.sh --run "$id" "$@" ) > "$KIT_RUNS/$id.out" 2>&1
}
rows() { grep -vE '^(check|INFO)' "$KIT_RUNS/$1/records/igv_snapshots.tsv" 2>/dev/null | grep -E "${2:-.}" | cut -c1-160; }

echo "== 1 normal run, xvfb-run on the host"
fixture t1; submit t1; rc=$?; expect "normal run" 0 $rc
echo "-- commands the job ran (stub log):"; grep -vE '^singularity exec [^ ]+ (test|ls) ' "$KIT_RUNS/t1.stub.log"
echo "-- $(grep -c '^singularity exec .* \(ls -lL\|test -e\) ' "$KIT_RUNS/t1.stub.log") ls/test calls inside the image"
echo "-- records:"; cat "$KIT_RUNS/t1/records/igv_snapshots.tsv"; echo "-- igv_version.txt: $(cat "$KIT_RUNS/t1/records/igv_version.txt")"
ls -l "$KIT_RUNS/t1/igv/snapshots/"

echo "== 2 xvfb-run only inside the image"
fixture t2; NOHOSTX=1 STUB_XVFB_IN_IMAGE=1 submit t2; rc=$?; expect "xvfb-run in the image" 0 $rc
grep -E '^singularity exec [^ ]+ xvfb-run|^xvfb-run' "$KIT_RUNS/t2.stub.log"

echo "== 3 xvfb-run nowhere"
fixture t3; NOHOSTX=1 submit t3; rc=$?; expect "no xvfb-run fails" 1 $rc; rows t3 FAIL

echo "== 4 missing load path (pre-flight only)"
fixture t4; mv "$KIT_RUNS/t4/scratch/varcall-workshop/results/bam/HG003.markdup.bam" "$KIT_RUNS/t4/HG003.moved"
submit t4 --preflight-only; rc=$?; expect "missing load path fails" 1 $rc; rows t4 FAIL
grep -c 'igv.sh -b' "$KIT_RUNS/t4.stub.log" | sed 's/^/   IGV started: /'

echo "== 5 reference symlink outside varcall-workshop_ref"
fixture t5; mkdir -p "$T/elsewhere"; cp "$STAGED_REF"/GRCh38_no_alt.fa* "$T/elsewhere/"
ln -sfn "$T/elsewhere/GRCh38_no_alt.fa" "$KIT_RUNS/t5/scratch/varcall-workshop/ref/GRCh38_no_alt.fa"
submit t5 --preflight-only; rc=$?; expect "reference outside STAGED_REF fails" 1 $rc; rows t5 FAIL

echo "== 6 reference md5 differs from the manifest"
fixture t6; cp "$STAGED_REF_MANIFEST" "$T/ref_manifest.good"
awk -F'\t' 'BEGIN { OFS = "\t" } $1 == "GRCh38_no_alt.fa" { $4 = "00000000000000000000000000000000" } { print }' "$T/ref_manifest.good" > "$T/ref_manifest.bad"
STAGED_REF_MANIFEST=$T/ref_manifest.bad submit t6 --preflight-only; rc=$?; expect "md5 mismatch fails" 1 $rc; rows t6 FAIL

echo "== 7 IGV rejects .csi (log WARN), then IGV_MAKE_BAI=1 with a pre-existing .bai next to one BAM"
fixture t7; STUB_CSI_ERROR=1 submit t7; rc=$?; expect "csi rejected: run passes with a WARN" 0 $rc; rows t7 WARN
B=$KIT_RUNS/t7/scratch/varcall-workshop/results/bam
echo "pre-existing" > "$B/HG002.markdup.bam.bai"; before=$(ls -l --time-style=+%s "$B" | md5sum)
IGV_MAKE_BAI=1 submit t7; rc=$?; expect "IGV_MAKE_BAI=1 run" 0 $rc
rows t7 'created|removed|temporary|derived'; grep 'created\|removed' "$KIT_RUNS/t7/records/igv_snapshots.tsv"
echo "-- derived batch:"; grep '^load' "$KIT_RUNS/t7/igv/snapshots.bai.batch"
echo "-- samtools calls:"; grep '^samtools' "$KIT_RUNS/t7.stub.log"
echo "-- left in igv/bai: $(ls -A "$KIT_RUNS/t7/igv/bai" 2>/dev/null | wc -l) files (directory $([ -d "$KIT_RUNS/t7/igv/bai" ] && echo kept || echo removed))"
after=$(ls -l --time-style=+%s "$B" | md5sum)
if [ "$before" = "$after" ] && [ "$(cat "$B/HG002.markdup.bam.bai")" = pre-existing ] && [ -s "$B/HG004.markdup.bam.csi" ]; then
  N=$((N + 1)); OK=$((OK + 1)); echo "PASS: pre-existing .bai and .csi next to the BAMs unchanged"
else N=$((N + 1)); echo "FAILED TEST: files next to the BAMs changed"; fi

echo "== 8 IGV_MAKE_BAI=1 with a file already in igv/bai (not made by this job)"
fixture t8; mkdir -p "$KIT_RUNS/t8/igv/bai"; echo old > "$KIT_RUNS/t8/igv/bai/HG003.markdup.bam.bai"
IGV_MAKE_BAI=1 submit t8; rc=$?; expect "existing temporary-name file fails" 1 $rc
rows t8 'FAIL|created|removed'
echo "   kept: $(cat "$KIT_RUNS/t8/igv/bai/HG003.markdup.bam.bai"); other created files left: $(ls "$KIT_RUNS/t8/igv/bai" | grep -vc HG003)"

echo "== 9 batch without exit fails the pre-flight"
fixture t9; sed -i '$d' "$KIT_RUNS/t9/igv/snapshots.batch"
submit t9 --preflight-only; rc=$?; expect "batch without exit fails" 1 $rc; rows t9 FAIL

echo "== 10 IGV never exits (timeout)"
fixture t10
IGV_TIMEOUT=2s STUB_HANG=1 submit t10; rc=$?; expect "timeout fails" 1 $rc; rows t10 FAIL

echo "== 11 a blank (small) snapshot fails"
fixture t11; cp "$T/img/igv.sh" "$T/igv.sh.good"
sed -i 's/head -c 20000/head -c 100/' "$T/img/igv.sh"
submit t11; rc=$?; expect "small PNG fails" 1 $rc; rows t11 FAIL
cp "$T/igv.sh.good" "$T/img/igv.sh"

echo
echo "IGV stub tests: $OK of $N as expected"
[ "$OK" -eq "$N" ]
