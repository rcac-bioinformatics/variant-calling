# Adaptations: where the reference run does not run exactly as a learner would

The rule is learner fidelity. The reference run uses the canonical learner commands in `pipeline/learner-scripts/` verbatim: the same module loads, paths, flags and SLURM headers, in the real Negishi environment. The episodes will show these files. This page lists every place where running unattended forces a difference, and why. If a learner command fails as written, the run records the failure; the kit never works around it.

## Where the learner directory lives

| What | Learner | Reference run | Why |
|---|---|---|---|
| `$SCRATCH` | `/scratch/negishi/<user>` | `$SCRATCH/varcall-kit/runs/<RUN_ID>/<copy>/scratch` | Each run starts from a fresh copy and never touches the operator's own workshop directory. Learner commands only use `$SCRATCH/varcall-workshop`, so pointing `$SCRATCH` elsewhere gives an unchanged command a fresh copy. `pipeline/lib.sh` refuses a run directory inside a staged copy or on Depot. |
| Call sets | one learner copy | copy `q0` (mpileup defaults). The first run (`ref-2026-10-10`) also had copy `q20` (`-q 20 -Q 20`) | Gate G3 (2026-10-10) chose q0. In the first run `fork-q20` built `q20` after alignment from hard links of `q0`'s data, resources, scripts and finished alignment results, so both call sets started from the same BAMs. Since G3 the run has only `q0`; `run_reference.sh` still forks any other call set listed in `REF_CALL_SETS`. |
| Determinism copy | none | copy `det`: `data`, `ref` and `resources` are symlinks to `q0`; it has its own `results/` | `align.sh` runs there for HG002 at 32 cores, and `det-compare` checks that the records match the 16-core run. |

## The learner's SLURM scripts

`align.sh`, `call.sh`, `evaluate.sh` and `annotate.sh` are submitted from the copy's `scripts/` folder (the staged copies, checked against this checkout by `01_setup.sh`), as a learner would: `cd scripts; sbatch align.sh`. `run_reference.sh` adds only submission options, never script content:

- `--parsable`, `--dependency=afterok:<ids>` and `--kill-on-invalid-dep=yes`, to chain the graph;
- `--export=ALL,SCRATCH=<copy>`, the learner directory above;
- (first run only) for `call.sh`, `READ_FILTERS=<empty | -q 20 -Q 20>` in the same `--export`, read by a line `READ_FILTERS=${READ_FILTERS:-}` that existed only for that run. G3 chose the defaults, so the line and the variable are gone and `call.sh` is final;
- for the determinism check, `--array=1 --cpus-per-task=32` on `align.sh`.

Account, QoS, partition, time and output files come from the scripts' own headers.

## Interactive blocks become batch jobs

| Block | Learner | Reference run |
|---|---|---|
| `02-setup.sh` | login node | login node (`01_setup.sh`), verbatim |
| `03-qc.sh`, `04-alignment-qc.sh`, `05-merge.sh`, `06-filter.sh`, `07-annotation-tables.sh`, `08-trio.sh` | `sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00`, then types the commands | A batch job (`jobs/session.sh`) with the cores and time of that `sinteractive` line. The `sinteractive` line itself is not run: the job is the session. |
| `06-evaluate-summary.sh` | login node | a 1-core batch job, because it must wait for `evaluate.sh` |

Learner-like shell: each block runs in a child `bash` without `set -e`, `set -u` or `pipefail` (as in a terminal), with an `ERR` trap that logs every failing command as `### KIT-ERR`. The step fails if any command failed. One line marked `# KIT EXTRA` loads Lmod's init file if the `module` function is not already in the batch environment, which gives the same function a login shell has. The console output of every block is kept in `records/console/`.

## Kit-only steps (never change learner files)

| Step | What it adds |
|---|---|
| `metrics-CS` | Distributions of the merged calls (QUAL, site DP and MQ, per-sample DP and GQ, allele balance) and Ts/Tv by region (inside and outside each benchmark BED, centromere, each chunk). It writes the filter proposal before any hap.py job exists, using the rule that `06-filter.sh` applies. |
| `report-CS` | Copies small learner outputs into records; region metrics on PASS sites; each trio candidate's status in every truth set; the allele fractions of the de novo candidates left after the region step; the SnpSift `extractFields` alternative next to `+split-vep`. |
| `det-compare` | md5 of `samtools view -h` without `@PG` lines, for HG002 at 16 and 32 cores. |
| `anchors` | Draft anchors table and sentinel sites. |

## Not covered by this run

- `evaluate.sh` and `annotate.sh` run on the soft-filtered VCF from `06-filter.sh` with thresholds the block computes or states. G3 kept the proposed thresholds unchanged. The anchors are frozen from a run made with the final learner scripts; `regen_results.sh --finalize` refuses a run whose `scripts/` differ from `pipeline/learner-scripts/`.
- IGV (P6).
- Episodes 5B, 9 and 10 (self-paced, P8).
