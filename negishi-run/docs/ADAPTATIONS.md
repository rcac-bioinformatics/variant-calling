# Adaptations: where the episode run kit does not run exactly as a learner would

The rule is learner fidelity. The kit (`build_kit.py`, `submit_all.sh`, `collect.sh --run`) runs the commands of the setup page and Episodes 2-6 as they appear on the page: same module loads, paths, flags and SLURM headers, in the real Negishi environment. Every command is extracted from the lesson text by `build_kit.py`; nothing is hand-copied, and the build fails if a canonical block differs from `pipeline/learner-scripts/`. This page lists every place where running unattended forces a difference, and why. If a learner command fails as written, the run records the failure (`### KIT-ERR` in the console log, FAIL marker); the kit never works around it.

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
| Episode 5A (`05-merge.sh` and the read-only blocks around it) | starts the session while `call.sh` runs, reads the staged example VCF, then joins the chunks once the array has finished | Step `05a-merge`: a batch job built the same way, after the calling array. The example-VCF blocks therefore run after calling, not during it; they read only `resources/example/`, so the order does not change their output. The `cat` of the region list sits before the `sinteractive` block on the page and runs first in the job; it uses an absolute path. |
| Episode 6 (`06-filter.sh` and its read-only blocks) | the same `sinteractive` line, after Episode 5A | Step `06-filter`: a batch job built the same way, after `05a-merge`. |
| Episode 6 (`06-evaluate-summary.sh` and the ROC block) | typed on a login node after `evaluate.sh` has finished | Step `06-evalsum`: the only blocks without a `sinteractive` line that must wait for a job. A login step runs inside `submit_all.sh` and cannot wait, so the kit runs them as a 1-task, 15-minute batch job (account, QoS and partition from `config.sh`) after `06-evaluate`. The commands are read-only and take seconds; the live-load table counts 0 cores for learners. |
| Episode 6 live path (`06-evaluate-summary.sh`: `sbatch --array=1 evaluate.sh`) | a learner submits task 1 only (HG002 against v5.0q) and copies the other three tasks' results from the completed results (decision 2026-10-11) | The kit's step `06-evaluate` submits the full array (the self-paced `sbatch evaluate.sh`), so all four tasks and their anchors are checked. In `06-evalsum` the learner's partial-array line runs as `sbatch --test-only --array=1 evaluate.sh`: SLURM validates it and nothing is submitted. `build_kit.py` accepts `sbatch` in an interactive block only as `sbatch --array=N SCRIPT` for a learner script. The live-load table counts task 1 only (24 cores per learner). The copy of the other three tasks is a fallback block and is not run. |

Learner-like shell: each session runs in a child `bash --noprofile --norc` without `set -e`, `set -u` or `pipefail`, as in a terminal, with an `ERR` trap that logs every failing command as `### KIT-ERR`. The step fails if any command failed. One line marked `KIT EXTRA` loads Lmod's init file if the `module` function is not already in the batch environment, which gives the same function a login shell has. `### KIT-BLOCK` lines around each block mark its console output, which `summarize.py` turns into the output spoilers.

`--qos normal` on `submit_all.sh` overrides the QoS of every job, including the learner's `align.sh`; the default, standby, is what the episodes use.

## The learner's SLURM scripts

`align.sh` (Episode 4), `call.sh` (5A) and `evaluate.sh` (6) are not copied from the episodes: learners submit the copies that the staged data puts in `scripts/`, so the kit does the same. Before submitting, `submit_all.sh` checks that `$W/scripts/<script>` is byte-identical to the block in the episode (and `build_kit.py` has already checked that block against `pipeline/learner-scripts/`, and the staged manifest's md5 against both). Each episode's submit block is exactly `cd $SCRATCH/varcall-workshop/scripts` and `sbatch <script>`; the kit runs that with submission options only:

- `--parsable`, to read the job ID;
- `--kill-on-invalid-dep=yes` and, for later steps, `--dependency=afterok:<id>` (`call.sh` after `align.sh`, `evaluate.sh` after `06-filter`);
- `--qos=<standby|normal>` (standby unless `--qos normal`);
- `--export=ALL,SCRATCH=<run>/scratch`, the learner directory above.

Account, partition, cores, time, array and log names come from the script's own header.

## Blocks the kit does not run

Every bash fence carries a marker (`<!-- kit: ... -->`, invisible on the site). Blocks marked `not-run` are never executed:

| Reason | Blocks | Why, and what covers them |
|---|---|---|
| `laptop` | `ssh your_username@negishi.rcac.purdue.edu` (setup page) | Runs on the learner's computer. |
| `download` | Episode 2 "Downloading from the source": `wget` of the BAMs, reference, bwa index and HG002 v5.0q files; `samtools collate`/`fastq` | More than 9 GB, and the staged copy already holds the results. `build_kit.py` checks that every URL is in `data-prep/sources.tsv`, where each was downloaded and checksummed in P2 (`data-prep/01_fetch.sh`). |
| `fallback` | "Short on time?" copies from `/depot/workshop/data/varcall-workshop_results` (Episodes 3-6, setup page) | A learner uses them only when a job did not finish; running them would overwrite the outputs the kit measures. `build_kit.py` checks that every path matches a file in `staged_results_manifest.tsv`, and (Prompt 05) that every "Short on time?" callout holds a fallback block, that every bash block in such a callout is one, and that every results-copy path in the callout, in blocks or prose, is in the manifest. |
| `monitoring` | `squeue -u $USER` | Output depends on the moment; the kit waits on job dependencies instead. |
| `reference` | `fastp` (Episode 3) and `bwa index` (Episode 4) spoilers | Reference only, on placeholder file names, and not part of the workshop path. Not tested. |

## Read-only extra blocks

Rule (P4 decision, 2026-10-10): commands that create or change files or submit jobs must match `pipeline/learner-scripts/` byte for byte. Read-only inspection commands (viewing, counting, printing regions, `tview`) may appear only in episodes, provided the kit check confirms they write nothing and submit nothing.

Episodes 2 and 4 show a few commands that are not in `pipeline/learner-scripts/interactive/`: inspecting the `.fai` and `.dict`, `samtools faidx`, `head` of a BED file and of a FASTQ file (Episode 2); `samtools view` of a region, `samtools flags`, and `samtools tview -d T -i` at two sentinel sites (Episode 4). They are marked `extra` and run in the same session as the canonical block they follow. `build_kit.py` refuses an extra block that writes a file, creates or removes anything, or submits a job, so they cannot change any output that later episodes or the frozen anchors depend on.

Episodes 5A and 6 add read-only extras of the same kind: `cat` of the region list, `bcftools view -h`/`view -H`/`query` on the staged example VCF and on the learner's own calls (the multiallelic site, the Episode 4 site), percentiles and threshold counts with `sort`/`awk`/`wc` on the tables `06-filter.sh` writes, `bcftools stats ... | grep` without an output file, the PASS and centromere Ts/Tv commands, and the ROC lookup (`zcat ... | sort | awk`). The write check ignores text inside quotes, so `-i 'N_ALT>1'` and `awk '$2 > max'` are allowed, while a `>` outside quotes, `-o` or `--output` still fails the build. One extra sets a shell variable (`POS=$(bcftools query ...)`), which writes no file.

`samtools tview` is an interactive full-screen viewer; the episode uses its text mode (`-d T`), which the kit can run. Graphical viewing (IGV) is decided in P6 and is not run by the kit.

## Kit-only additions (never change learner files)

| Where | What |
|---|---|
| End of `03-qc` and `04-alignqc` | `kit_multiqc_export`: MultiQC with `--export` on the learner's QC folders, written to `records/multiqc_export/<step>/` (PNG plots for Part C figures). A failure is a WARN, not a FAIL. |
| `submit_all.sh` start | `build_kit.py --check`, recorded in `records/build_kit_check.txt`; the run stops if the kit no longer matches the lesson text. |
| `collect.sh --run` | sacct for every job and array task, the partition's cores and memory per node (`sinfo`, for the memory headroom of `evaluate.sh`), the module each pinned version resolves to, a checksum check of the episodes and learner scripts against the build, and `py/summarize.py`. |
| End of `04-alignqc` | `kit_mapq0_counts`: `samtools view -c` of HG002's MAPQ 0 records split into primary mapped, unmapped, supplementary and secondary (`records/kit-only/mapq0_counts.tsv`), for the Episode 4 MAPQ 0 challenge (P4 review, correction 4). |
| End of `05a-merge` | `kit_bcftools_usage`: the usage text of the pinned bcftools (`mpileup` without arguments; `call`, `filter`, `norm`, `concat`, `view`, `query`, `stats` with `--help`) in `records/kit-only/usage/`, the only source of the defaults that Episodes 5A and 6 quote. `kit_site_counts`: HG002 at chr20:88108 counted by `bcftools mpileup` with its read and base filters switched off, then on one at a time (duplicates `--ns`, anomalous pairs `-A`, overlapping mates `-x`, base-quality floor `-Q`, BAQ `-B`), the VCF records at 88108 and 85259, and `samtools view -c` counts at 88108 (`records/kit-only/site_88108.tsv`). |
| End of `06-filter` | `kit_multiqc_export 06-filter results/vcf`: MultiQC 1.23 with `--export` on the two `bcftools stats` files (`trio.norm.stats.txt`, all records; `trio.filtered.stats.txt`, PASS only), for the two Episode 6 figures of the QUAL and depth distributions (`06-multiqc-bcftools-qual`, `06-multiqc-bcftools-depth`). Learners do not run MultiQC in Episode 6 (decision 2026-10-11: `06-filter.sh` stays unchanged); the episode labels the plots as made by the kit. Part C (2026-10-12) dropped both figure slots: the exports have no legend for their two lines, the SNV QUAL plot is a few saturation spikes, and the depth plot is a flat bump next to the 500 cap; Episode 6 keeps the percentile table. The export still runs and is recorded. `kit_filter_counts`: records and FILTER values before and after filtering, sites per filter name, missing genotypes per sample before and after, the reason for each mask (DP, GQ, both), the five sentinels with their truth genotypes (`outside` when the position is outside that benchmark's BED, since the truth VCFs also list variants outside their benchmark regions; `absent` when inside with no truth record; fixed 2026-10-11 after the artifact sentinel was found in the v5.0q VCF outside its BED), and the region metrics of `pipeline/py/metrics.py` run exactly as in the P3 reference run (the HG002 PASS Ts/Tv anchors). Dumps go to `$RUN/kit-only.*.dump.tsv.gz`, the tables to `records/kit-only/`. |

Every kit-only record runs in a subshell with its own module loads after the learner session has finished, reads the learner directory, writes only to the run's records (or `$RUN` for the dumps), and records a failure as `WARN` in `records/kit-only/status.tsv` without failing the step. None of them is shown to learners as a command.

## Not covered by this run

- Episodes 1 (no commands), 7 and 8 (P6). Their canonical scripts were run in the P3 reference run.
- The interactive `samtools tview` viewer and IGV.
- Several learners submitting at once: standby waits are measured for one run only.
