# updates.md

Running log of decisions, testing findings and revision opportunities for this lesson. Severity tags: `[blocker]` breaks a learner or the live delivery, `[should-fix]` wrong or stale but survivable, `[nice]` polish, `[check]` needs verification before it becomes a finding. Append dated entries; move resolved items to Done with the fixing commit.

## Decisions

Recorded from the Prompt 01 decisions block. Details and alternatives are in `maintenance/plan/development-plan.md`.

| ID | Decision | Status | Date |
|---|---|---|---|
| D1 | Dataset: GIAB Ashkenazi trio HG002 (child), HG003 (father), HG004 (mother); Illumina NovaSeq PCR-free ~35x reads from chr20; GRCh38 no-alt analysis set | approved | 2026-10-09 |
| D2 | Live caller: bcftools mpileup/call. GATK HaplotypeCaller is self-paced Episode 5B | approved | 2026-10-09 |
| D3 | Annotation: SnpEff/SnpSift plus gnomAD allele frequencies via `bcftools annotate` | approved | 2026-10-09 |
| D4 | Live application: Episode 8, candidate variants in the trio. Episode 9, population variation, is self-paced | approved | 2026-10-09 |
| D5 | Versions: explicit module versions for samtools and bcftools; target bcftools 1.24 (to be deployed), else 1.17 | approved | 2026-10-09 |
| D6 | Six hours means instruction excluding breaks and lunch; the day runs 9:00-4:30 | approved | 2026-10-09 |
| D7 | Conventions: follow rnaseq-analysis (numbered files and titles, display fences never executed at build, run kit, `.claude/CLAUDE.md`, maintenance log), plus public instructor notes structured like singlecell-rnaseq | approved | 2026-10-09 |
| D8 | Logistics: repo `rcac-bioinformatics/variant-calling`; SLURM account TBD; Depot `/depot/workshop/data/varcall-workshop` and `/depot/workshop/data/varcall-workshop_results`; working directory `$SCRATCH/varcall-workshop`, with `$SCRATCH` as the only scratch variable; delivery date TBD; co-instructor TBD | approved | 2026-10-09 |

Open parts of approved decisions: SLURM account (P2), bcftools 1.24 deployment or fallback to 1.17 (P2), Depot directories created and staged (P3), delivery date and co-instructor (P10).

## Open findings

### Phase 1 assessment, 2026-10-09 (prompt-01-scaffold.md; branch `dev/p01-scaffold` from 822e8c5)

Plan section 1 checked against this checkout and the sibling checkouts `../rnaseq-analysis` (2d0b5f8), `../singlecell-rnaseq` (89eea2a), `../genome-assembly` (20e694a). The commits match the ones the plan read. Discrepancies, as "plan says X, repository shows Y":

- `[should-fix]` Plan 1.1 says `README.md` is the one-line template placeholder; the working tree had an uncommitted 143-line README for an unrelated project (RCAC_biocontainers-deploy, an older version of its README). The same file is committed in `../RCAC_biocontainers-deploy` (blob present in f9e4b0b), so nothing is lost by replacing it. Replaced with this lesson's README in P1.
- `[nice]` Plan header and Prompt 01 say the plan is at `maintenance/plan/development-plan.md` and prompts go in `maintenance/prompts/`; the checkout had both files in an untracked top-level `prompts/` directory and no `maintenance/`. Moved them to `maintenance/plan/development-plan.md` and `maintenance/prompts/prompt-01-scaffold.md` (P1). A top-level `prompts/` folder would also have been rendered by sandpaper.
- `[nice]` Plan 1.2 says all three workshops are delivered as one full day in person; `../singlecell-rnaseq/learners/setup.md` shows a one-day schedule, but its `instructors/instructor-notes.md` says the workshop "is designed for a two-day schedule". Internal inconsistency in scRNA-seq, outside this repo; not changed.
- `[nice]` Plan 1.2 lists the RNA-seq scratch variables as `$SCRATCH` in episodes and `$RCAC_SCRATCH` in setup; the RNA-seq R episodes also build `/scratch/negishi/$USER` (its log, status sweep 2026-10-07). Supports the D8 rule here: `$SCRATCH` only.
- `[check]` Not in the plan: `../rnaseq-analysis/.gitignore` ignores `CLAUDE.md` everywhere and its `.claude/CLAUDE.md` is force-added. Prompt 01 does not list that entry, so this repo does not ignore `CLAUDE.md` and `.claude/CLAUDE.md` is an ordinary tracked file. Confirm that is intended.

Confirmed as stated in plan section 1: one commit 822e8c5; stock workflows pinned to sandpaper 0.17.1 (0.17.1 in RNA-seq and scRNA-seq, 0.16.11 in genome assembly); `episodes/introduction.Rmd` is the Workbench demo; placeholder `index.md`, setup, reference, instructor notes, learner profile (title FIXME), `CITATION.cff` (FIXME), template `links.md`; the uncommitted `config.yaml` and `variant-calling.Rproj` edits; no git remote; gitignored `site/` and `.Rproj.user/`. RNA-seq: numbered files and titles with `disable_sidebar_numbering: true`, display fences, `source:` is the GitHub URL, SLURM header `--account=rcac-rnaseq --qos=standby --partition=cpu` with `cluster-%x.%j.out`, no `--mem`, public instructor notes are a placeholder, sentence-case headings. scRNA-seq: topical file names, `eval=FALSE` chunks, Pages URL as `source:`, `--account=workshop`, Title Case headings. Genome assembly: display fences, `--qos=normal`, mentions `--mem`. Side findings in plan 1.3 (scRNA-seq schedule dated 4/21/2026, `--mem=40G` in its instructor notes, `--account=workshop`) are still present; not changed.

- `[nice]` The local, gitignored `site/` holds stale output from builds before P1: `site/docs/development-plan.html` and `prompt-01-scaffold.html` (rendered while the plan sat in top-level `prompts/`), `introduction.html`, `site/built/prompt-01-scaffold.md`, and several HTML pages unrelated to this lesson (meeting briefs, narration, survey summary). None are tracked or published (CI builds from a clean checkout). A clean build of the P1 tree in a scratch copy renders only the lesson pages. Clear with `sandpaper::reset_site()` when the unrelated pages are no longer needed.

No git remote is configured (expected at this stage). Create `rcac-bioinformatics/variant-calling` before the first push.

Deviations from the RNA-seq conventions, decided in the plan:

- `[nice]` samtools and bcftools load explicit module versions instead of module defaults (D5, plan 5.3).
- `[nice]` `$SCRATCH` on the setup page as well as in episodes (RNA-seq setup uses `$RCAC_SCRATCH`) (D8).
- `[nice]` The reference and its indexes stay read-only on Depot and are symlinked into `ref/`, instead of copied to every learner (plan 5.4). Confirm in P2.
- `[nice]` The public `instructors/instructor-notes.md` follows scRNA-seq (timing, common issues, checklist, discussion points); RNA-seq keeps a placeholder there (D7).

### Gap analysis (plan section 2), 2026-10-09

- `[blocker]` Episodes: P1 adds stubs for the 8 core episodes; content for 1-8 in P4-P6, self-paced 5B, 9, 10 in P8.
- `[blocker]` Dataset, staging and completed results: none yet. Data-prep scripts, Depot staging with manifest and checksums, completed-results copy (P2-P3).
- `[blocker]` Reference run and validation: none yet. Reference pipeline that produces anchors; run kit that executes episode code as a new learner would (P3-P5, P9).
- `[blocker]` SLURM account for the workshop: TBD (P2).
- `[should-fix]` `config.yaml`: Pages URL as `source`, `life_cycle: stable`, template keywords, demo-only episode list, empty learners/instructors/profiles. Fixed in P1 (uncommitted).
- `[should-fix]` Setup page: FIXME. Skeleton in P1, full page in P4.
- `[should-fix]` Instructor notes, learner profile, glossary: placeholders. Skeletons in P1, content in P7.
- `[should-fix]` `index.md`, `README.md`, `CITATION.cff`: placeholders. Written in P1; revisit in P7.
- `[nice]` Figures and animations: none. Workflow diagram, reads-to-genotype animation, VCF anatomy, precision-recall, filtering funnel, IGV examples (P7).
- `[should-fix]` Development infrastructure: `.claude/CLAUDE.md`, this log, `.gitignore` entries. Added in P1 (uncommitted).
- `[should-fix]` Remote: none. Create `rcac-bioinformatics/variant-calling` (owner action).

### Phase 2 Part A, 2026-10-09 (prompt-02-feasibility.md; branch `dev/p02-feasibility` from `main` at e94a023)

Built the feasibility kit off-cluster: `negishi-run/` (`config.sh`, `lib.sh`, `00_preflight.sh`, `submit_pilot.sh`, `collect.sh`, `pilot/` jobs, `py/sacct_summary.py`, `README.md`, `docs/ood_igv_check.md`) and `data-prep/` (`01`-`05` scripts, `jobs/`, `snpeff_lib.sh`, `sources.tsv`, `README.md`). Nothing has run on Negishi. All work goes to `$SCRATCH/varcall-prep`; the scripts refuse a `PREP_DIR` under `/depot/workshop/data`.

Static checks (all pass): `bash -n` on every script; shellcheck 0.10.0 (Docker `koalaman/shellcheck:v0.10.0`), one justified `SC2016` disable plus the `SC2034`/`SC2086` disables with comments; `py_compile` and a sample run of `sacct_summary.py` under Python 3.13 and 3.6.15 (Docker `python:3.6-slim`); every `--dry-run` in run order prints the full graph (14 jobs, `--account`, `--partition=cpu`, `--qos=standby`, no memory request); grep finds no `--mem` and no URL outside `data-prep/sources.tsv` and `negishi-run/config.sh`; `sandpaper::validate_lesson()` clean, and the only new Markdown is two `README.md` files and `negishi-run/docs/ood_igv_check.md` (two levels down).

Findings and deviations:

- `[check]` `sources.tsv` rows `ref_md5` (`md5checksums.txt`) and `ref_bwa_index` (`...fna.bwa_index.tar.gz`) use file names that are not verified; both are marked optional, and `01_fetch.sh` records a WARN if either is absent.
- `[check]` Terms URLs for gnomAD and SnpEff are `TBD(P2)` in `sources.tsv`; `01_fetch.sh` lists them as WARN rows. Find and record them in Part C.
- `[check]` HG002 `latest` file selection is heuristic (GRCh38 in the path, `.vcf.gz`, not SV or tandem-repeat names, preferring "smvar", "small" or "benchmark"). All candidates are recorded; confirm the choice in Part C against the release README.
- `[nice]` Prompt asks for P-align "as an array, once at each pilot core count". A SLURM array cannot vary `--cpus-per-task` between tasks, so P-align is one job per core count (`p-align-c16`, `p-align-c32`); the same applies to SnpEff (`p-snpeff-c4`, `p-snpeff-c8`).
- `[nice]` sacct fields add `TotalCPU` to the list in the prompt, needed for CPU efficiency.
- `[nice]` P-call uses equal-length chunks of chr20 with `mpileup -r`; an indel spanning a chunk boundary can be lost or split. Acceptable for timing; the reference run (P3) should use boundaries that avoid it or a single region.
- `[nice]` The naive candidate and impact counts in `p-trio` use plain filter expressions on unfiltered calls; they size the teaching examples only.
- `[check]` `bcftools +mendelian2 -P <ped>` is called with the 1.17 syntax as understood; `p-trio` saves the plugin's help and stderr so Part C can correct the call if it fails.

What cannot be verified off-cluster, and the check that covers it:

| Not verifiable off-cluster | Covered by |
|---|---|
| Installed module versions, defaults, pinned versions load | preflight, per module |
| bcftools plugins exposed; `bgzip`/`tabix` from htslib | preflight (`plugin -l`, `+mendelian2 -h`, `type`) |
| hap.py `--engine vcfeval` | preflight synthetic pair; `p-eval` |
| SnpEff databases, repository host, heap through the wrapper | preflight (`databases`, container config, `-Xmx1m` and `_JAVA_OPTIONS` failure tests) |
| Account, QoS, partition; job headers accepted | preflight (`sacctmgr`, `sinfo`, `sbatch --test-only` on every job) |
| `module --force purge` needed or not | preflight, login and compute node |
| Compute-node internet | preflight standby job; `state/egress.env` |
| Scratch and Depot space and quota | preflight (`df`, `myquota`, read only) |
| NCBI checksum and bwa index files; HG002 `latest` names | `01_fetch.sh` |
| BAM header vs reference, duplicate flags, quality binning, mates outside chr20 | `prep-fastq` |
| gnomAD v4.1 INFO field names | `prep-annot` (stops if AF/AC/AN or asj fields are missing) |
| Runtimes, memory, queue waits | the run (`sacct_summary.tsv`, `metrics.tsv`) |
| OOD desktop or ThinLinc; IGV launch | `docs/ood_igv_check.md`, by hand |

### Phase 2 Part C, first pass, 2026-10-09 (records `varcall-p2-records-20261009-1517`)

Run check: preflight 0 FAIL, 0 WARN; every pinned module is also the Negishi default; all BAM, BAI, reference, NCBI bwa index and gnomAD files match their published md5 (the HG002 v5.0q VCF and index match NIST `checksum.md5`; `provenance.tsv` labels that `match:none` because the id has no `sources.tsv` row). All jobs completed except `p-trio` (FAILED); one `prep-truth` was cancelled by hand and resubmitted. Three blockers to the memo, all kit bugs, so the memo waits for a short rerun (decision 2026-10-09: fix the kit, rerun, then write the memo).

- `[blocker]` v4.2.1 truth BEDs were empty: GRCh38 v4.2.1 publishes only `<ID>_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed`; the plain `_benchmark.bed` named in Prompt 02 does not exist (three FAIL rows in `fetch.tsv`). `prep-truth` wrote 0-bp BEDs and still passed, and hap.py ran with a confident region of about 109 kb, so the v4.2.1 recall and precision are invalid. Fixed: `sources.tsv` drops the three `giab421_*_bed` rows, `prep-truth` uses the `_noinconsistent` BED and stops on a missing or empty BED, `p-eval` stops on an empty BED.
- `[blocker]` HG002 v5.0q was evaluated against `HG002_CHM13v2.0_v5.0q_smvar.benchmark.bed` (CHM13 coordinates on a GRCh38 VCF); recall 0.94-0.97 reflects the mismatch. Fixed: `01_fetch.sh` takes `<vcf name>.benchmark.bed` (`HG002_GRCh38_v5.0q_smvar.benchmark.bed`, md5 3366858af85875cbb3c579412ffa4c56 in NIST `checksum.md5`), else a GRCh38 BED only; `prep-truth` refuses a non-GRCh38 BED and records how many truth records fall in the BED.
- `[blocker]` `p-trio` produced no counts; the zeros in `metrics.tsv` are command failures, not data. Causes, checked in the stock `quay.io/biocontainers/bcftools:1.17--haef29d1_0` container: `+mendelian2 -P` is rejected ("invalid option -- 'P'") although `-h` lists it, `-p child,father,mother` works; `bcftools annotate -a` cannot read a pipe ("not compressed with bgzip"). Fixed in `p-trio`; counts now come from `bcftools query` plus awk, and failures are recorded instead of becoming zeros.
- `[check]` `GT[0]="het"` failed on Negishi with 'the tag "het" is not defined' but works in the stock 1.17 container. Likely the RCAC bcftools module wrapper drops embedded double quotes, which would break every string filter expression in the lesson. `p-trio` now saves the wrapper definition and a syntax table (`bcftools_wrapper.txt`, `gt_syntax_test.tsv`). If confirmed, this is a module fix before P4, not a lesson workaround.
- `[should-fix]` Kit's own filter `INFO/ANN ~ "\|HIGH\|"` matches every record (POSIX regex alternation with empty branches; local 1.17 test). Use `"[|]HIGH[|]"`. Same trap for any lesson expression on ANN.
- `[check]` Ts/Tv of the raw trio calls is 1.81 (1.93 at QUAL>=100) against 2.31 in the chr20 v4.2.1 truth; HG002 has about 120k SNV calls against 73k truth SNVs, and chunk 4 (chr20:24.2-32.2 Mb, the centromere) has 53.6k records against 14-21k elsewhere. The kit called with mpileup defaults (no `-q`), and the pilot BAM has 983k MQ0 reads. Rerun adds `CALL_SET=q20` (`-q 20 -Q 20`) for comparison; not yet a finding about the data.
- `[nice]` `sources.tsv`: gnomAD terms are CC0 with attribution requested (gnomad-browser `about/policies/terms.md`); SnpEff is MIT; NIST data may be copied and redistributed with acknowledgment (v5.0q README). No source restricts a Depot copy. The v4.2.1 README (de novo handling) is `NISTv4.2.1/README_v4.2.1.txt`, one level above `GRCh38/`; new listing row `giab421_readme_dir`.
- `[check]` `docs/ood_igv_check.md` came back blank; requested again in the rerun.

Kit changes for the rerun: `config.sh` `CALL_SET` (raw, q20) with `MPILEUP_FILTER`; `lib.sh` call-set paths and step names, `CALL_SET` exported to jobs, and `kit_dep` waits for a queued job before trusting an old PASS marker (a `--force` resubmission was otherwise not waited for); `submit_pilot.sh --redo`; runbook section "Rerun after the first pilot". Checks: `bash -n` and shellcheck 0.10.0 clean; dry runs of `04_truth_subsets.sh` and `submit_pilot.sh` (raw with `--redo p-eval`, and `CALL_SET=q20`) print the expected graph with no memory request; `p-trio.sh` ran end to end on a synthetic trio in the bcftools 1.17 container, and its counts match hand counts.

### Phase 2 Part C, rerun and memo, 2026-10-09 (records `varcall-p2-records-20261009-1615`)

The rerun (R2-R4 of the runbook) completed: `prep-truth`, `p-eval` and `p-trio` all COMPLETED. R5 (`CALL_SET=q20`) was not submitted, and `ood_igv_check.md` is still blank. Memo: `maintenance/plan/feasibility.md` (all values pilot). Truth BEDs are now correct: v4.2.1 noinconsistent 56.4-56.9 Mb of chr20 and v5.0q GRCh38 58.1 Mb, and hap.py's confident-region size matches.

- `[blocker]` Confirmed: the bcftools module wrapper is `/usr/bin/singularity run /apps/biocontainers/images/staphb_bcftools:1.17.sif bcftools "$@"` and the runscript strips embedded double quotes. bcftools reports `Could not parse the expression: GT[0]=0/1 && GT[1]=0/0 && GT[2]=0/0` (`pilot/trio/gt_syntax_test.tsv`), and every `GT`/string filter form fails. This breaks the filter expressions planned for Episodes 6-8 (plan 3.4 shows `GT[0]="het" && GT[1]="RR" && GT[2]="RR"`). Fix in the biocontainer modulefiles (`singularity exec`), and check samtools and snpsift for the same template. Supersedes the first-pass `[check]`.
- `[check]` resolved: Ts/Tv 1.81 is explained. HG002 calls inside the v4.2.1 benchmark that match truth have Ts/Tv 2.31 (truth 2.31); the 47,644 SNV calls outside the benchmark regions have 1.29 (`pilot/eval/HG002.v4.2.1.vcfeval.extended.csv`). QUAL barely removes them (33,323 remain at QUAL >= 225). No reference or truth mismatch.
- `[should-fix]` Plan 3.4 (Episode 6) quotes Ts/Tv of about 2.0-2.1 for germline WGS SNVs; inside chr20 benchmark regions the truth is 2.31. The episode must quote the measured chr20 value or explain the difference (P5).
- `[should-fix]` Plan 5.4 estimates about 7.5M read pairs per sample at 35x; measured 9.35-9.48M pairs, and the mean chr20 depth is about 40x (39.2-39.9x). Plan 5.1's "dedup BAMs may lack duplicates" is answered: duplicates are marked, not removed (about 10.4%).
- `[check]` Plan 5.1 cites about 143,000 trio-variant records on chr20 (DeepTrio case study); the raw bcftools trio VCF has 185,628, about 40% of HG002's SNV calls lying outside the benchmark regions. Expected for unfiltered calls; compare after filtering in P3.
- `[check]` Mendelian error rate on unfiltered calls: 1.80% of evaluated sites (3,319 errors). Naive de novo: 1,509, then 540, then 63 SNVs (all calls; QUAL >= 30 and DP >= 10; within the benchmark). Rare protein-altering de novo: 0; recessive: 1. Consistent with plan 5.5's framing. Episode 8's funnel may end at 0, so frame it as a base-rate lesson.
- `[nice]` HG002 v5.0q vs v4.2.1 on the same calls (vcfeval): SNV recall 0.9878 vs 0.9946, indel recall 0.8381 vs 0.9425. xcmp and vcfeval agree within 0.002; vcfeval takes 107-154 s against 74-97 s for xcmp.
- `[check]` p-eval peaked at 23.88 GiB MaxRSS on 8 cores, more than the nominal 15.2 GB. Measure per run and engine in P3; the memo recommends 16 cores for a learner's hap.py job.
- `[nice]` The SnpEff MANE 1.2 database gives HG002 4 HIGH and 244 MODERATE calls, with 24 rare protein-altering (16 by asj AF). The p14 database gives 6-7x more effects through transcript multiplicity.

Kit and docs changed in this step: `data-prep/sources.tsv` gains an `expected_md5` column with the verified sizes and md5 values, plus explicit `giab_HG002_latest_{vcf,tbi,bed}` rows; `lib.sh` `kit_fetch` falls back to that column when no md5 is published; `config.sh` gets comments with verified facts only; `data-prep/README.md` records the verified items; the local `.claude/CLAUDE.md` replaces every `TBD(P2)` (the open items are now `TBD(G2)`).

Decisions requested at G2 (details and recommendations in the feasibility memo):

| # | Decision | Recommendation |
|---|---|---|
| G2-1 | Region and coverage | Whole chr20 at native depth (option a); D1 unchanged |
| G2-2 | Core counts and chunks | Alignment 32 cores per sample (16 as fallback); calling 8 chunks at 2 cores; hap.py 16; SnpEff 4; trio steps 4 |
| G2-3 | Module wrapper quote stripping | Fix modulefiles to `singularity exec` before P3; recheck with `gt_syntax_test.tsv` |
| G2-4 | bcftools version | Deploy and pin bcftools 1.24 and htslib 1.24 with the fixed wrapper; else 1.17 with `+mendelian2 -p` |
| G2-5 | SnpEff database | `GRCh38.mane.1.2.ensembl` |
| G2-6 | hap.py engine | vcfeval |
| G2-7 | Truth sets | HG002 v5.0q primary, v4.2.1 for comparison; HG003 and HG004 v4.2.1 noinconsistent |
| G2-8 | mpileup filters | Run `CALL_SET=q20` (runbook R5) before choosing the Episode 5A command, or decide in P3 |
| G2-9 | Staging and Depot | About 14.5 GB learner copy (data, ref, annot, truth) plus results; about 317 GB free on the workshop Depot |
| G2-10 | Workshop SLURM account | Open; the pilot used `rcac` |
| G2-11 | IGV approach | `samtools tview` plus prepared snapshots as the baseline; a desktop session only if `ood_igv_check.md` shows it works |

## Revision opportunities

## Runtime record

P2 pilot on Negishi, 2026-10-09, account `rcac`, QoS `standby`, partition `cpu`. These are pilot values; details in `maintenance/plan/feasibility.md`.

| Step | Cores | Wall | MaxRSS (GiB) | Wait |
|---|---|---|---|---|
| prep-faidx | 2 | 60 s | 0.04 | 63 s |
| prep-bwaindex (NCBI index, no build) | 4 | 54 s | 0.01 | 303 s |
| prep-fastq, per sample | 8 | 189-219 s | 0.30-0.40 | 206 s |
| prep-truth | 2 | 50 s | 0.04 | 140 s |
| prep-annot (gnomAD subset 890 s) | 8 | 1045 s | 0.28 | 198 s |
| p-align HG002 chr20 | 16 | 781 s | 14.77 | 156 s |
| p-align HG002 chr20 | 32 | 452 s | 18.10 | 401 s |
| p-call chunk (of 8) | 2 | 129-246 s | 0.18 | 156 s |
| p-call-merge | 4 | 17 s | 0.00 | 637 s |
| p-eval (8 hap.py runs) | 8 | 829 s | 23.88 | 40 s |
| p-snpeff MANE | 4 | 35 s job, 24 s SnpEff | n/a | 870 s |
| p-trio | 4 | 193 s | 0.11 | 40 s |

## Done
