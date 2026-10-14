# Negishi run kit

Phase 5 (current) extends the episode run kit of Phase 4 to Episodes 5A and 6: `build_kit.py` extracts every command of the setup page and Episodes 2-6, checks it against `pipeline/learner-scripts/`, and `submit_all.sh` runs it as a new learner on standby. Phase 3 (below) staged the data and ran the reference run that froze the anchors in `anchors.tsv`; phase 2 measured feasibility. Settings live in `config.sh`; external files in `../data-prep/sources.tsv`.

## Phase 5: the episode run kit for Episodes 2-6 (Prompt 05, Part B)

The whole chain runs again from Episode 2 as a new learner: the alignment anchors are checked again, and calling, filtering and hap.py run on the learner's own BAMs. Steps (`generated/steps.tsv`), with the reference-run times:

| Step | Where | What | Expected |
|---|---|---|---|
| `02-setup`, `03-qc`, `04-align`, `04-alignqc` | as in Phase 4 below | plus a kit-only MAPQ 0 count after `04-alignqc` | about 20 min plus waits |
| `05a-call` | the learner's `scripts/call.sh`, array of 8 x 2 cores, after `04-align` | `mpileup` and `call` per region | 2-4 min per task (P3: 133-254 s) |
| `05a-merge` | batch job, 4 tasks, after `05a-call` | example-VCF blocks, `concat`, `norm`, `stats`; then the kit-only bcftools usage text and chr20:88108 counts | 1-2 min (P3 merge: 13-16 s) |
| `06-filter` | batch job, 4 tasks, after `05a-merge` | distributions, filters, Ts/Tv; then a kit-only MultiQC PNG export of the two `bcftools stats` files, filter counts, sentinels and region metrics | 2-4 min (P3 filter: 17 s; the kit-only metrics add the rest) |
| `06-evaluate` | the learner's `scripts/evaluate.sh`, array of 4 x 24 cores, after `06-filter` | `bcftools view -s`, hap.py vcfeval on norm and filtered calls | 1.5-2.5 min per task (P3: 89-145 s) |
| `06-evalsum` | 1-task batch job, after `06-evaluate` | `summary.csv` views and the ROC lookup (login-node commands) | under 1 min |

Critical path about 35 minutes plus standby waits.

On the laptop first:

```bash
cd ~/svn/variant-calling
python3 negishi-run/build_kit.py
python3 negishi-run/build_kit.py --check   # "all kit checks pass; generated/ matches a fresh build"
rsync -av --relative ./episodes ./learners ./negishi-run ./pipeline ./data-prep aseethar@negishi.rcac.purdue.edu:/scratch/negishi/aseethar/variant-calling/
```

On a Negishi login node, in `tmux` or `screen`, from `/scratch/negishi/aseethar/variant-calling` (any new run ID):

| Step | Command | Expected |
|---|---|---|
| 1 | `bash negishi-run/00_preflight.sh` | FAIL 0 |
| 2 | `bash negishi-run/submit_all.sh --run kit5-2026-10-11 --dry-run` | 9 steps; 8 `sbatch --test-only` lines that say "to start at"; "0 sbatch --test-only failure(s)" |
| 3 | `bash negishi-run/submit_all.sh --run kit5-2026-10-11` | runs `02-setup` on the login node, then submits the other 8 steps with `afterok` dependencies |
| 4 | wait until `squeue -u $USER` is empty | about 35 min plus standby waits |
| 5 | `bash negishi-run/collect.sh --run kit5-2026-10-11` | writes `$SCRATCH/varcall-kit/kit-runs/varcall-p5-kit-kit5-2026-10-11-<date>.tar.gz` and prints the `rsync` command |
| 6 | on the laptop: run the printed `rsync`, then `tar -xzf <tarball> -C negishi-run/records/` | the records under `negishi-run/records/`, never at the repository root |

Read `SUMMARY.md` first: per-step status, every anchor and sentinel (exact match; any FAIL is a stop item for Part C), the hap.py summaries, runtime against front matter, the memory headroom of each `evaluate.sh` task (sample, truth set, node, MaxRSS, wall time), the Episode 5A multiallelic stop check, the live-load table, the kit-only records, every placeholder value and every block's console output. Recovery is as in Phase 4 below; `kit_ep_done` also recognizes a finished `call.sh` (the eight chunk indexes) and `evaluate.sh` (eight `summary.csv` files newer than the run).

The precision-recall figure is made on the laptop in Part C, from the tarball's `qc/eval/` folder: `python3 negishi-run/pr_figure.py <tarball dir>/qc/eval episodes/fig/06/pr_hg002_v5.0q.png`.

### Phase 5 Part B rerun: `RTG_MEM` in `evaluate.sh` and the sentinel fix (2026-10-11)

`evaluate.sh` now caps the memory of hap.py's vcfeval engine (`export RTG_MEM=8g`), and the kit's sentinel lookup applies the benchmark BEDs. The rerun starts at `06-filter`, not `06-evaluate`, because the sentinels are kit-only records of `06-filter`; `06-filter` takes about 2 minutes and rewrites the same files. Run ID stays `kit5-2026-10-11`.

On the laptop: `build_kit.py`, `--check`, and the `rsync` as above.

On a Negishi login node, from `/scratch/negishi/aseethar/variant-calling`:

| Step | Command | Expected |
|---|---|---|
| 1 | `bash negishi-run/restage.sh --scripts` | the build's `scripts/` updated; `negishi-run/staged_manifest.tsv` rewritten (`scripts/evaluate.sh` md5 `b99b4cda77cc83c79337968944d60e4e`, 1734 bytes) |
| 2 | `bash negishi-run/restage.sh --install` | asks before writing to Depot; `check_staged.sh` reports 0 problems on both copies |
| 3 | `cp /depot/workshop/data/varcall-workshop/scripts/evaluate.sh $SCRATCH/varcall-kit/kit-runs/kit5-2026-10-11/scratch/varcall-workshop/scripts/evaluate.sh` | the run's learner copy gets the new script, as a learner who copies the scripts again would |
| 4 | `bash negishi-run/submit_all.sh --run kit5-2026-10-11 --from 06-filter --force --dry-run` | 3 steps (`06-filter`, `06-evaluate`, `06-evalsum`), 3 `--test-only` lines that say "to start at" |
| 5 | `bash negishi-run/submit_all.sh --run kit5-2026-10-11 --from 06-filter --force` | 3 jobs with `afterok` dependencies |
| 6 | when `squeue -u $USER` is empty: `bash negishi-run/collect.sh --run kit5-2026-10-11` | a new tarball |
| 7 | on the laptop: `rsync` the tarball and `negishi-run/staged_manifest.tsv` back; extract the tarball under `negishi-run/records/` | |

Read in `SUMMARY.md`: all 49 anchors PASS (the artifact sentinel now reads "truth outside every benchmark region"); in the memory table, MaxRSS of every `evaluate.sh` task of the new array well under 80%; the 8 `summary.csv` files identical to those of the first array (`cmp` against the first tarball's `qc/eval/`); the `06-evalsum` console shows `sbatch --test-only --array=1 evaluate.sh` accepted.

## Phase 4: the episode run kit (Prompt 04, Part B)

What runs (`generated/steps.tsv`, `generated/graph.txt`):

| Step | Where | What | Expected (records) |
|---|---|---|---|
| `02-setup` | login node, inside `submit_all.sh` | setup page and Episode 2 blocks: `rsync` of 36 files (5.7 GB), `ln -s` of the reference, `md5sum -c`, the sample sheet and PED file, `.fai`, `.dict`, `samtools faidx`, BED and FASTQ heads | about 1 min (the P3 setup block took 44 s) |
| `03-qc` | batch job, 4 tasks, 1 h limit (the Episode 3 `sinteractive` line) | FastQC on 6 files, MultiQC; then a kit-only MultiQC PNG export | about 3 min (P3: 196 s) |
| `04-align` | the learner's `scripts/align.sh`, array of 3 x 16 cores | `bwa mem`, `fixmate`, `sort`, `markdup` | 11-13 min per task (P3: 651-750 s) |
| `04-alignqc` | batch job, 4 tasks, after `04-align` | `flagstat`, `stats`, `mosdepth`, MultiQC, `samtools view`/`flags`/`tview -d T -i`; then a kit-only MultiQC PNG export | about 3-4 min (P3: 203 s) |

Critical path about 20 minutes plus standby waits. `docs/ADAPTATIONS.md` lists every difference from a learner.

### Before you start

- On the laptop, the kit must pass its checks and be built from the current text:

  ```bash
  cd ~/svn/variant-calling
  python3 negishi-run/build_kit.py          # checks, then writes negishi-run/generated/
  python3 negishi-run/build_kit.py --check  # must say "all kit checks pass; generated/ matches a fresh build"
  ```

- The staged copies on Depot pass `check_staged.sh` (preflight checks them), and `staged_manifest.tsv` lists the learner scripts with the md5 of `pipeline/learner-scripts/` (`build_kit.py` checks this).

### Send the kit

The kit reads the episodes, the setup page and the learner scripts, so send all of them (with `generated/`, which is not in git):

```bash
cd ~/svn/variant-calling
rsync -av --relative ./episodes ./learners ./negishi-run ./pipeline ./data-prep aseethar@negishi.rcac.purdue.edu:/scratch/negishi/aseethar/variant-calling/
```

### Part B command order

On a Negishi login node, in `tmux` or `screen`, from `/scratch/negishi/aseethar/variant-calling`:

| Step | Command | Expected |
|---|---|---|
| 1 | `bash negishi-run/00_preflight.sh` | FAIL 0 (WARN rows are reviewed in Part C) |
| 2 | `bash negishi-run/submit_all.sh --run kit-2026-10-11 --dry-run` | the four steps, three `sbatch --test-only` lines that say "to start at", "0 sbatch --test-only failure(s)" |
| 3 | `bash negishi-run/submit_all.sh --run kit-2026-10-11` | runs `02-setup` on the login node (about a minute), then submits `03-qc`, `04-align` and `04-alignqc` |
| 4 | wait until `squeue -u $USER` is empty | about 20 min plus standby waits |
| 5 | `bash negishi-run/collect.sh --run kit-2026-10-11` | writes `$SCRATCH/varcall-kit/kit-runs/varcall-p4-kit-kit-2026-10-11-<date>.tar.gz` and prints the `rsync` command |
| 6 | on the laptop, run the printed `rsync` | the tarball lands in the repository root |

Use any new run ID; the date in it is only a label. Start with `SUMMARY.md` in the tarball: per-step status with the first error of any failure, the 18 alignment anchors (each must PASS, exact match), runtime against front matter, every `{{kit:...}}` placeholder value, the MultiQC PNG exports, and the console output of every block.

### Recovery

- A failed step cancels its dependents (`--kill-on-invalid-dep=yes`). Logs: kit jobs in `kit-runs/<RUN_ID>/logs/`; session console in `kit-runs/<RUN_ID>/records/console/<step>.log` (search for `### KIT-ERR`); the learner's alignment logs in `kit-runs/<RUN_ID>/scratch/varcall-workshop/scripts/cluster-align.*`.
- If a learner command fails as written, do not patch the kit: bring the run back (step 5) so Part C can fix the episode.
- After fixing a kit-side cause, rerun `submit_all.sh --run <RUN_ID>`: finished steps are skipped (markers; for `04-align`, the three `.csi` indexes). `--from STEP` skips earlier steps that are done; `--force` resubmits batch steps. `02-setup` never reruns in the same run; use a new run ID.

### Changing the SLURM account

The account is `rcac` for now. It appears in `config.sh` (`KIT_ACCOUNT`), in the `#SBATCH --account=` headers of `pipeline/learner-scripts/*.sh`, in every `sinteractive -A` line (learner blocks and episodes), and in the setup page. To switch every place at once, from the repository root on the laptop (set `NEW` first):

```bash
NEW=rcac-varcall; grep -rlZE -- '(--account=|-A )rcac([^-[:alnum:]]|$)|KIT_ACCOUNT:-rcac\}' negishi-run/config.sh pipeline/learner-scripts episodes learners | xargs -0 sed -i -E "s/(--account=|-A )rcac([^-[:alnum:]]|$)/\1$NEW\2/g; s/KIT_ACCOUNT:-rcac\}/KIT_ACCOUNT:-$NEW}/"
```

Then check:

```bash
python3 negishi-run/build_kit.py --check
```

The account check passes at once (every `--account=` and `-A` equals the new `KIT_ACCOUNT`). The staged-script check fails until the scripts on Depot are restaged, because learners submit the staged copies: run `bash negishi-run/restage.sh --scripts` and `bash negishi-run/restage.sh --install` on Negishi, bring back `negishi-run/staged_manifest.tsv`, and run the check again. Tested on a copy of the repository on 2026-10-10: the command rewrote 5 `--account=` headers and 9 `-A` values and `config.sh`.

## Phase 3: staging and the reference run (Part B)

The learner scripts in `../pipeline/learner-scripts/` are what the episodes will show; the reference run submits them unchanged from a fresh learner copy and runs the interactive blocks as batch jobs (`../pipeline/docs/ADAPTATIONS.md` lists every difference from a learner). Everything is labeled "reference run, not frozen".

### Before you start

- Module wrappers switched to `singularity exec`, and `bcftools/1.24` plus `htslib/1.24` deployed. Preflight checks both (quoting rows and the `bcftools plugin -l` rows).
- The phase-2 prep under `$SCRATCH/varcall-prep` is still there (FASTQ, reference, bwa index, truth sets, gnomAD subset, SnpEff data); `stage-build` reuses it.
- Account `rcac` for now; a workshop account replaces it later (in `config.sh`, the learner script headers and the `sinteractive` lines only). Staging writes to `/depot/workshop/data/varcall-workshop` and `/depot/workshop/data/varcall-workshop_ref`; the results copy is made only in Part D.

Send the kit from the laptop:

```bash
cd ~/svn/variant-calling
rsync -av --relative ./negishi-run ./data-prep ./pipeline aseethar@negishi.rcac.purdue.edu:variant-calling/
```

### Command order

Run as `aseethar` on a Negishi login node, in `tmux` or `screen`. Wall times come from the P2 feasibility memo where a step was measured; the rest are estimates.

| Step | Command | Where it runs | Expected wall time |
|---|---|---|---|
| 1 | `bash ~/variant-calling/negishi-run/00_preflight.sh` | login node plus one standby job | 5-15 min |
| 2 | `bash ~/variant-calling/negishi-run/restage.sh --build` | submits `stage-build` (SDF, truth subsets, manifests) | about 20 min plus queue (estimate) |
| 3 | `bash ~/variant-calling/negishi-run/restage.sh --install` | login node; copies about 6 GB and 9 GB to Depot, then `check_staged.sh` on both | about 10-20 min |
| 4 | `bash ~/variant-calling/negishi-run/00_preflight.sh` | again: the staged-copy rows must now PASS | 5-15 min |
| 5 | `bash ~/variant-calling/pipeline/01_setup.sh ref-2026-10-10` | login node; the Episode 2 setup block into a fresh run | about 5 min |
| 6 | `bash ~/variant-calling/pipeline/run_reference.sh --run ref-2026-10-10 --dry-run` | login node; prints the graph | 1 min |
| 7 | `bash ~/variant-calling/pipeline/run_reference.sh --run ref-2026-10-10` | submits about 30 jobs | 1 min |
| 8 | wait: `squeue -u $USER` | | about 1.5-2 h with standby waits (alignment 13 min at 16 cores, calling chunks up to 4 min, hap.py 2 runs per task of 1-3 min, SnpEff under 1 min) |
| 9 | `bash ~/variant-calling/pipeline/collect.sh --run ref-2026-10-10` | login node | 1 min |
| 10 | bring back the tarball it names (`rsync` command printed) | laptop | 1 min |

Use any run ID; a new ID starts a new run directory under `$SCRATCH/varcall-kit/runs/`. Steps 1 and 4 must show no FAIL; WARN rows are reviewed in Part C. Step 3 asks for confirmation before writing to Depot (`--yes` skips it) and never deletes: files on Depot that the manifest does not list make `check_staged.sh` fail, and you remove them by hand. It prints the Depot group learners must belong to.

### Job graph

```
qc, align (array of 3, 16 cores), align-det (HG002 at 32 cores)    no dependency
alignqc            after align
det-compare        after align, align-det     (same records at 16 and 32 cores, or FAIL)
per call set CS (q0 = mpileup defaults; the first run also had q20 = -q 20 -Q 20, after a fork-q20 job):
  call-CS (array of 8) -> merge-CS -> metrics-CS -> filter-CS -> eval-CS (array of 4) -> evalsum-CS
  filter-CS -> annot-CS -> tables-CS -> trio-CS;  report-CS after evalsum-CS and trio-CS
anchors            after every report-CS, det-compare, alignqc
```

Since G3 (2026-10-10) `REF_CALL_SETS` is `q0` only: 16 jobs.

`metrics-CS` writes the distributions and the filter proposal before any hap.py job exists, so thresholds are never tuned on the benchmark.

### Recovery

- A failed job cancels its dependents (`--kill-on-invalid-dep=yes`). Read the log (kit jobs: `runs/<RUN_ID>/logs/`; learner scripts: `cluster-*.out` in the copy's `scripts/`; interactive blocks: `runs/<RUN_ID>/records/console/session-<step>.log`), fix the cause, then rerun `run_reference.sh --run <RUN_ID>`: it skips steps that are done (kit markers, or a learner script's final index file).
- `--redo "step ..."` resubmits named steps; `--force` resubmits everything.

## Phase 3: finalize (Part D)

G3 (2026-10-10, `maintenance/plan/reference-run.md`): call set q0, filters unchanged, `evaluate.sh` at 24 cores (16 hap.py threads), example region chr20:60,000-90,000. The learner scripts now hold these as literals. `regen_results.sh` copies a finished run's learner copy, `scripts/` included, so the anchors and the results copy come from one more run made with the final scripts. That run also checks that calling, evaluation and trio steps give the same values as `ref-2026-10-10`.

Send the kit first (the prep under `$SCRATCH/varcall-prep` and run `ref-2026-10-10` must still exist):

```bash
cd ~/svn/variant-calling
rsync -av --relative ./negishi-run ./pipeline aseethar@negishi.rcac.purdue.edu:/scratch/negishi/aseethar/variant-calling/
```

On a Negishi login node, from `/scratch/negishi/aseethar/variant-calling`:

| Step | Command | Expected |
|---|---|---|
| 1 | `bash negishi-run/restage.sh --scripts` | final learner scripts in the build; manifest rewritten |
| 2 | `bash negishi-run/restage.sh --example --run ref-2026-10-10` | prints the counts in `resources/example/` (region, raw and filtered records, multiallelic, het, hom-alt, indel, not PASS); stops if one is 0; widens the region to the nearest multiallelic site if needed |
| 3 | `bash negishi-run/restage.sh --install` | copies the changed files to Depot; `check_staged.sh` on both copies: 0 problems |
| 4 | `bash pipeline/01_setup.sh ref-final-2026-10-11` | fresh learner copy from the new staged copy |
| 5 | `bash pipeline/run_reference.sh --run ref-final-2026-10-11` | 16 jobs; about 1-1.5 h with standby waits |
| 6 | when `squeue -u $USER` is empty: `bash negishi-run/regen_results.sh --finalize --call-set q0 --run ref-final-2026-10-11` | refuses if the run's `scripts/` differ from `pipeline/learner-scripts/` or the example differs from the run's calls; writes `/depot/workshop/data/varcall-workshop_results.<date>` and its manifest; prints the swap and rollback commands |
| 7 | run the printed swap commands | the new copy becomes `/depot/workshop/data/varcall-workshop_results` |
| 8 | `bash negishi-run/check_staged.sh --results` | 0 problems |
| 9 | `bash pipeline/collect.sh --run ref-final-2026-10-11` | bring back the tarball it names |

Any run ID works; the date in it is only a label. `regen_results.sh` never deletes anything and never touches the current results copy; the swap is a manual step.

## Phase 2: environment and data feasibility (kept for the record)

Measures before anything is written: checks the Negishi environment, fetches and prepares the data under `$SCRATCH/varcall-prep`, runs a pilot of every live step (align, call, evaluate, annotate, trio counts), and brings back one tarball of records. Every number it produces is labeled "pilot" and is for feasibility only; lesson anchors come from the phase-3 reference run.

Nothing here writes to `/depot/workshop/data` (the scripts refuse a `PREP_DIR` there). Settings live in `config.sh`; external files in `../data-prep/sources.tsv`.

### Before you start

- Set the SLURM account. Every submit refuses to run while it is empty:

  ```bash
  export KIT_ACCOUNT=<account>      # or edit KIT_ACCOUNT in config.sh
  ```

- If bcftools 1.24 and htslib 1.24 are deployed, use them for the pilot:

  ```bash
  export BCFTOOLS_MODULE=bcftools/1.24 HTSLIB_MODULE=htslib/1.24
  ```

  Exported values must be the same in every step below; put them in `config.sh` if you work across several logins.

### Sending the kit

From the laptop:

```bash
cd ~/svn/variant-calling
rsync -av --relative ./negishi-run ./data-prep aseethar@negishi.rcac.purdue.edu:variant-calling/
```

### Command order

Run as `aseethar` on a Negishi login node, in `tmux` or `screen` (steps 2 and 6 download for a while). Expected wall times are `TBD(P2)`: this run measures them.

| Step | Command | Where it runs | Expected wall time |
|---|---|---|---|
| 1 | `bash ~/variant-calling/negishi-run/00_preflight.sh` | login node, plus one standby job (at most 10 min) | TBD(P2) |
| 2 | `bash ~/variant-calling/data-prep/01_fetch.sh` | login node (downloads about 5 GB) | TBD(P2) |
| 3 | `bash ~/variant-calling/data-prep/02_reference.sh` | submits `prep-faidx`, `prep-bwaindex` | TBD(P2) |
| 4 | `bash ~/variant-calling/data-prep/03_bam_to_fastq.sh` | submits the `prep-fastq` array | TBD(P2) |
| 5 | `bash ~/variant-calling/data-prep/04_truth_subsets.sh` | submits `prep-truth` | TBD(P2) |
| 6 | `bash ~/variant-calling/data-prep/05_annotation.sh` | downloads (gnomAD chr20 is 11.8 GB) on the login node unless preflight found compute-node internet; submits `prep-annot` | TBD(P2) |
| 7 | `bash ~/variant-calling/negishi-run/submit_pilot.sh --dry-run --test-only` | login node | 1 min |
| 8 | `bash ~/variant-calling/negishi-run/submit_pilot.sh` | login node; submits the pilot graph | TBD(P2) |
| 9 | Fill in `~/variant-calling/negishi-run/docs/ood_igv_check.md` once `p-align-c16` has finished | OOD or ThinLinc desktop | 20 min |
| 10 | `bash ~/variant-calling/negishi-run/collect.sh` | login node | 1 min |
| 11 | Bring the tarball back (below) | laptop | 1 min |

Step 1 must show no FAIL before you continue. Fix FAIL rows first (most likely: `KIT_ACCOUNT`, a module version that is not installed, a missing bcftools plugin). WARN rows are reviewed in Part C; the run can proceed. Step 2 also exits non-zero on any FAIL (a size or md5 mismatch, a missing HG002 `latest` GRCh38 file); read `records/fetch.tsv`.

Steps 3 to 6 can be run one after another without waiting: each submits its jobs and records their IDs, and `submit_pilot.sh` makes the pilot jobs wait for them. Every script takes `--dry-run`; running all of them with `--dry-run` in order prints the whole graph with placeholder IDs.

Watch the queue with `squeue -u $USER -o '%.10i %.16j %.8T %.10M %R'`.

### Dependency graph

All jobs start after `01_fetch.sh` (login node) has finished. Each line is "job: waits for".

```
prep-faidx      : -
prep-bwaindex   : prep-faidx
prep-fastq      : -              (array, one task per sample)
prep-truth      : -
prep-annot      : -              (after 05_annotation.sh's downloads)
p-align-c16/c32 : prep-bwaindex, prep-fastq
p-call-chunks   : prep-faidx     (array, one task per chunk)
p-call-vcmp     : prep-faidx
p-call-merge    : p-call-chunks
p-eval          : p-call-merge, prep-truth
p-snpeff-c4/c8  : p-call-merge, prep-annot
p-trio          : p-call-merge, p-snpeff-c8, prep-annot
```

Calling uses the source BAMs (already on the same reference), so `p-call`, `p-eval` and the annotation jobs run while the bwa index builds. `p-align` is the only pilot job that waits for the index.

| Job | Measures |
|---|---|
| `prep-bwaindex` | NCBI index usable, or index build wall time |
| `prep-fastq` | source-BAM facts the episodes must state; BAM to FASTQ time; read counts |
| `p-align-c<N>` | bwa mem, fixmate, sort, markdup at each core count (wall time, MaxRSS, CPU efficiency), flagstat, stats, mean depth, duplicate rate |
| `p-call-chunks`, `p-call-merge` | per-chunk calling time, slowest chunk, concat and normalize, counts and Ts/Tv |
| `p-call-vcmp` | chunk 1 with each installed bcftools version |
| `p-eval` | hap.py time and precision/recall per sample and truth set, xcmp and vcfeval engines |
| `p-snpeff-c<N>` | SnpEff heap and wall time at each core count; MANE vs full database |
| `p-trio` | sample order, `+mendelian2` counts, naive de novo and recessive counts, HIGH/MODERATE and rare protein-altering counts in HG002 |

### Options and recovery

- Reruns are safe: finished downloads and jobs whose marker says PASS are skipped. `--force` on any script redoes its part.
- A failed job cancels its dependents (`--kill-on-invalid-dep=yes`). Read `$SCRATCH/varcall-prep/logs/<job>.<id>.out`, fix the cause, rerun the script that submits it, then `submit_pilot.sh` again; it resubmits only steps without a PASS marker.
- `KIT_PURGE=0` runs jobs without `module --force purge` (preflight compares both).
- `05_annotation.sh --fetch-on login|compute` overrides where downloads run.

### Rerun after the first pilot (Part C, 2026-10-09)

The first records (`varcall-p2-records-20261009-1517`) showed three kit bugs: the v4.2.1 truth BEDs were empty (GRCh38 v4.2.1 publishes only `_noinconsistent.bed`), the HG002 v5.0q evaluation used the CHM13v2.0 BED, and `p-trio` failed (`+mendelian2 -P`, genotype filter syntax, `annotate` on a pipe). The rerun keeps every download, FASTQ, alignment and the first call set, redoes truth subsets, evaluation and trio counts, and adds a second call set with `mpileup -q 20 -Q 20` (`CALL_SET=q20`, outputs under `pilot/q20/`).

| Step | Command | Where it runs | Expected wall time |
|---|---|---|---|
| R1 | resend the kit (`rsync`, above) | laptop | 1 min |
| R2 | `bash ~/variant-calling/data-prep/01_fetch.sh` | login node; re-verifies existing files, downloads the GRCh38 v5.0q BED and the v4.2.1 README | 2 min |
| R3 | `bash ~/variant-calling/data-prep/04_truth_subsets.sh --force` | submits `prep-truth` | 1 min plus queue (pilot) |
| R4 | `bash ~/variant-calling/negishi-run/submit_pilot.sh --redo "p-eval"` | submits `p-eval` and `p-trio` for the first call set | 13 min plus queue (pilot) |
| R5 | `CALL_SET=q20 PILOT_SNPEFF_CORES=8 bash ~/variant-calling/negishi-run/submit_pilot.sh` | submits `p-call-chunks-q20`, `p-call-merge-q20`, `p-eval-q20`, `p-snpeff-c8-q20`, `p-trio-q20` | 20 min plus queue (pilot) |
| R6 | fill in `docs/ood_igv_check.md` (still blank) | OOD or ThinLinc desktop | 20 min |
| R7 | `bash ~/variant-calling/negishi-run/collect.sh` once `squeue` is empty | login node | 1 min |

R2 must end with no FAIL and the row `HG002 latest GRCh38 files ... bed=HG002_GRCh38_v5.0q_smvar.benchmark.bed`. R3 to R5 can be run back to back; the pilot jobs wait for `prep-truth`.

### Bringing the records back

`collect.sh` tars `$SCRATCH/varcall-prep/records` only (no BAM, VCF or FASTQ) and prints the command, for example:

```bash
rsync -avP aseethar@negishi.rcac.purdue.edu:/scratch/negishi/aseethar/varcall-prep/varcall-p2-records-<date>.tar.gz ~/svn/variant-calling/
```

The tarball holds: preflight table and raw outputs, provenance and fetch tables, terms and README texts, listings, source-BAM facts, `metrics.tsv` (every derived number, labeled pilot), alignment summaries, `bcftools stats` SN and TSTV, the bcftools version comparison, `+mendelian2` output, candidate counts, hap.py summaries and ROC tables, SnpEff CSV summaries, the gnomAD field list, `sacct.tsv` and `sacct_summary.tsv` (wait, elapsed, CPU efficiency, MaxRSS), file sizes, trimmed logs, the job table, and the filled-in `ood_igv_check.md`.

### What could not be verified before the first Negishi run

The kit was checked off-cluster only: `bash -n` and shellcheck 0.10.0 on every script, `py_compile` of the Python helper, every `--dry-run` in order (the full job graph with account, partition and QoS), and the parsers (sacct summary, hap.py summary, directory listings, gnomAD field filter) on sample input. Nothing has run on Negishi.

| Not verifiable off-cluster | What covers it |
|---|---|
| Module versions installed, defaults, and that the pinned versions load | preflight: available, default, load and version output per module |
| bcftools plugins inside the container; `bgzip`/`tabix` from htslib | preflight: `bcftools plugin -l`, `+mendelian2 -h`, `type bgzip tabix` per module |
| hap.py `--engine vcfeval` in the 0.3.9 container | preflight: both engines on a synthetic pair; `p-eval` on real data |
| SnpEff databases, repository host, heap passing through the wrapper | preflight: `snpEff databases`, container config, `-Xmx1m` and `_JAVA_OPTIONS` failure tests |
| Account, QoS, partition limits; job headers accepted | preflight: `sacctmgr`, `sinfo`, `sbatch --test-only` on every job |
| Whether `module --force purge` is needed | preflight: samtools startup with and without, on the login and a compute node |
| Compute-node internet (GCS, NCBI, GIAB, SnpEff host) | preflight: one standby job probes each host; sets `COMPUTE_INTERNET` |
| Scratch and Depot space and quota | preflight: `df`, `myquota` (read only) |
| NCBI `md5checksums.txt` and bwa index tarball names | `01_fetch.sh`: optional rows; absence is a WARN |
| HG002 `latest` GRCh38 small-variant file names | `01_fetch.sh`: walks the listing, records candidates, FAIL if none |
| BAM header matches the reference; duplicate flags; binned qualities | `prep-fastq` records |
| `bcftools +mendelian2` option syntax in the pinned version | `p-trio` saves the help text and the error if the call fails |
| gnomAD v4.1 INFO field names | `prep-annot` reads the header and stops if the AF/AC/AN or asj fields are missing |
| Runtimes, memory, queue waits | the run itself (`sacct_summary.tsv`, `metrics.tsv`) |
| OOD desktop or ThinLinc, IGV launch | `docs/ood_igv_check.md`, filled in by hand |
