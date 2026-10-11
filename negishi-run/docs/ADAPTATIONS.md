# Adaptations: where the episode run kit does not run exactly as a learner would

The rule is learner fidelity. The kit (`build_kit.py`, `submit_all.sh`, `collect.sh --run`) runs the commands of the setup page and Episodes 2-4 as they appear on the page: same module loads, paths, flags and SLURM headers, in the real Negishi environment. Every command is extracted from the lesson text by `build_kit.py`; nothing is hand-copied, and the build fails if a canonical block differs from `pipeline/learner-scripts/`. This page lists every place where running unattended forces a difference, and why. If a learner command fails as written, the run records the failure (`### KIT-ERR` in the console log, FAIL marker); the kit never works around it.

## Where the learner directory lives

| What | Learner | Kit | Why |
|---|---|---|---|
| `$SCRATCH` | `/scratch/negishi/<user>` | `$KIT_RUNS/<RUN_ID>/scratch` (`KIT_RUNS` in `config.sh`, default `$SCRATCH/varcall-kit/kit-runs`) | Each run starts from an empty scratch and never touches the operator's own workshop directory. Every episode command uses `$SCRATCH/varcall-workshop`, so pointing `SCRATCH` elsewhere gives unchanged commands a fresh copy. `kitrun.sh` refuses a run directory inside a staged copy, on Depot, or outside `KIT_RUNS`. As a consequence, `echo $SCRATCH` on the setup page prints the kit path, not `/scratch/negishi/<user>`. |
| Starting directory | the login or session shell starts in `$HOME` | every session starts in `$KIT_RUNS/<RUN_ID>/home`, an empty directory | Commands that depend on the current directory behave as for a learner who has just logged in. `HOME` itself is not changed (Lmod and the containers use it). |
| `TMPDIR` | as set by the system | as set by the system | Not changed, for fidelity. No episode command writes to `TMPDIR`; `samtools sort` and `markdup` use `-T` paths inside `results/bam`. |

## The setup page and Episode 2 run on the login node

Step `02-setup` runs, on the login node where `submit_all.sh` runs, every block of the setup page and Episode 2 that belongs to `interactive/02-setup.sh`, plus the read-only Episode 2 blocks (`.fai` and `.dict`, `samtools faidx`, the BED lines, the FASTQ record), in page order, in one learner-like shell. A learner does the setup page before the workshop and Episode 2 later, possibly in a new login; the Episode 2 blocks start with `cd $SCRATCH/varcall-workshop` for that reason, so one shell or two give the same result.

After the session, kit-only lines record the size and tree of the copy (`records/listings/02-setup-*.txt`) and fail the step if a link in `ref/` is broken. They read the learner directory and write only to the run's records.

`02-setup` never reruns within one run: its `ln -s` refuses links that already exist, as it would for a learner who repeats the setup. A new `RUN_ID` starts over.

## Interactive blocks become batch jobs

| Block | Learner | Kit |
|---|---|---|
| Episode 3 (`03-qc.sh`) | `sinteractive -A rcac -q standby -p cpu -N 1 -n 4 --time=1:00:00`, then types the commands | Step `03-qc`: a batch job with the same account, QoS, partition, nodes, tasks and time, parsed from the episode's `sinteractive` line (`generated/jobs/03-qc.sh`). The `sinteractive` line itself is not run: the job is the session. |
| Episode 4 (`04-alignment-qc.sh` and the read-only blocks after it) | the same `sinteractive` line, after `align.sh` has finished | Step `04-alignqc`: a batch job built the same way, submitted with `--dependency=afterok` on the alignment array. |

Learner-like shell: each session runs in a child `bash --noprofile --norc` without `set -e`, `set -u` or `pipefail`, as in a terminal, with an `ERR` trap that logs every failing command as `### KIT-ERR`. The step fails if any command failed. One line marked `KIT EXTRA` loads Lmod's init file if the `module` function is not already in the batch environment, which gives the same function a login shell has. `### KIT-BLOCK` lines around each block mark its console output, which `summarize.py` turns into the output spoilers.

`--qos normal` on `submit_all.sh` overrides the QoS of every job, including the learner's `align.sh`; the default, standby, is what the episodes use.

## The learner's SLURM script

`align.sh` is not copied from the episode: learners submit the copy that the staged data puts in `scripts/`, so the kit does the same. Before submitting, `submit_all.sh` checks that `$W/scripts/align.sh` is byte-identical to the block in Episode 4 (and `build_kit.py` has already checked that block against `pipeline/learner-scripts/align.sh`, and the staged manifest's md5 against both). The episode's submit block is exactly `cd $SCRATCH/varcall-workshop/scripts` and `sbatch align.sh`; the kit runs that with submission options only:

- `--parsable`, to read the job ID;
- `--kill-on-invalid-dep=yes` and, for later steps, `--dependency=afterok:<id>`;
- `--qos=<standby|normal>` (standby unless `--qos normal`);
- `--export=ALL,SCRATCH=<run>/scratch`, the learner directory above.

Account, partition, cores, time, array and log names come from the script's own header.

## Blocks the kit does not run

Every bash fence carries a marker (`<!-- kit: ... -->`, invisible on the site). Blocks marked `not-run` are never executed:

| Reason | Blocks | Why, and what covers them |
|---|---|---|
| `laptop` | `ssh your_username@negishi.rcac.purdue.edu` (setup page) | Runs on the learner's computer. |
| `download` | Episode 2 "Downloading from the source": `wget` of the BAMs, reference, bwa index and HG002 v5.0q files; `samtools collate`/`fastq` | More than 9 GB, and the staged copy already holds the results. `build_kit.py` checks that every URL is in `data-prep/sources.tsv`, where each was downloaded and checksummed in P2 (`data-prep/01_fetch.sh`). |
| `fallback` | "Short on time?" copies from `/depot/workshop/data/varcall-workshop_results` (Episodes 3 and 4, setup page) | A learner uses them only when a job did not finish; running them would overwrite the outputs the kit measures. `build_kit.py` checks that every path matches a file in `staged_results_manifest.tsv`. |
| `monitoring` | `squeue -u $USER` | Output depends on the moment; the kit waits on job dependencies instead. |
| `reference` | `fastp` (Episode 3) and `bwa index` (Episode 4) spoilers | Reference only, on placeholder file names, and not part of the workshop path. Not tested. |

## Read-only extra blocks

Rule (P4 decision, 2026-10-10): commands that create or change files or submit jobs must match `pipeline/learner-scripts/` byte for byte. Read-only inspection commands (viewing, counting, printing regions, `tview`) may appear only in episodes, provided the kit check confirms they write nothing and submit nothing.

Episodes 2 and 4 show a few commands that are not in `pipeline/learner-scripts/interactive/`: inspecting the `.fai` and `.dict`, `samtools faidx`, `head` of a BED file and of a FASTQ file (Episode 2); `samtools view` of a region, `samtools flags`, and `samtools tview -d T -i` at two sentinel sites (Episode 4). They are marked `extra` and run in the same session as the canonical block they follow. `build_kit.py` refuses an extra block that writes a file, creates or removes anything, or submits a job, so they cannot change any output that later episodes or the frozen anchors depend on.

`samtools tview` is an interactive full-screen viewer; the episode uses its text mode (`-d T`), which the kit can run. Graphical viewing (IGV) is decided in P6 and is not run by the kit.

## Kit-only additions (never change learner files)

| Where | What |
|---|---|
| End of `03-qc` and `04-alignqc` | `kit_multiqc_export`: MultiQC with `--export` on the learner's QC folders, written to `records/multiqc_export/<step>/` (PNG plots for Part C figures). A failure is a WARN, not a FAIL. |
| `submit_all.sh` start | `build_kit.py --check`, recorded in `records/build_kit_check.txt`; the run stops if the kit no longer matches the lesson text. |
| `collect.sh --run` | sacct for every job and array task, the module each pinned version resolves to, a checksum check of the episodes and learner scripts against the build, and `py/summarize.py`. |

## Not covered by this run

- Episodes 1 (no commands) and 5A-8 (P5, P6). The canonical scripts for 5A-8 were run in the P3 reference run.
- The interactive `samtools tview` viewer and IGV.
- Several learners submitting at once: standby waits are measured for one run only.
