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
| G2 | Gate G2 (from Prompt 03): whole chr20 at native depth (about 40x); account `rcac-rnaseq` (one value in `config.sh` and the learner script headers); module wrappers switched to `singularity exec`, bcftools 1.24 and htslib 1.24 deployed and pinned with bwa 0.7.17, samtools 1.22.1, mosdepth 0.3.3, hap.py 0.3.9, snpeff 5.3.0a, snpsift 5.2, fastqc 0.12.1, multiqc 1.23; cores: alignment 16, calling 8 chunks x 2, hap.py 16, SnpEff 4, trio 4; hap.py vcfeval with a staged RTG SDF; SnpEff `GRCh38.mane.1.2.ensembl`; truth sets HG002 v5.0q primary (v4.2.1 for comparison), HG003 and HG004 v4.2.1, trio analyses inside the intersection of the three v4.2.1 `_noinconsistent` BEDs; IGV decided in P6. Open until G3: mpileup read filters (defaults vs `-q 20 -Q 20`) and the filter rule and thresholds | approved | 2026-10-09 |
| G3 | Gate G3 (from Prompt 03 Part C, `maintenance/plan/reference-run.md`): call set q0 (mpileup defaults, no read filters); filters QUAL < 30 (`LowQual`), INFO/DP > 2 x median site depth (`HighDP`), INFO/MQ < 30 (`LowMQ`), genotypes with FMT/DP < 10 or FMT/GQ < 20 set to missing, the mask taught as the precision-recall trade-off; Episode 8 keeps the zero-candidate funnel and frames the 41 candidates after the region step as mostly real cell-line variants, not germline de novo (about 1-2 expected on chr20), citing the NIST HG002 mosaic benchmark paper, with the child allele fractions recorded in the memo; the recessive evidence step stays, with the reason it removes nothing; `evaluate.sh` at 24 cores; example region chr20:60,000-90,000, checked for a multiallelic site in Part D; Episode 5A callout that the `MQ should be declared as Type=Float` warning is harmless. Anchors frozen after the Part D finalize run | approved; frozen 2026-10-10 (`negishi-run/anchors.tsv`; results copy staged) | 2026-10-10 |

Open parts of approved decisions: the frozen anchors (P3 Part D), delivery date and co-instructor (P10). The SLURM account and bcftools version are settled by G2.

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

### Phase 3 Part A, 2026-10-09 (prompt-03-reference-run.md; branch `dev/p03-reference` from d4e61a4)

P2 was committed (d4e61a4) but not merged, so the branch starts from the P2 commit instead of `main` (agreed in session). Built off-cluster, nothing run on Negishi:

- **Learner scripts:** `pipeline/learner-scripts/` holds `align.sh`, `call.sh`, `evaluate.sh`, `annotate.sh` and the interactive blocks `interactive/02-setup.sh` to `08-trio.sh`. The episodes will show these verbatim.
- **Reference run:** `pipeline/` holds `01_setup.sh`, `run_reference.sh` (27-job graph), `jobs/`, `py/metrics.py`, `py/report.py`, `collect.sh` and `docs/ADAPTATIONS.md`.
- **Staging:** `negishi-run/` gains `restage.sh`, `check_staged.sh`, `make_staged_manifest.py`, `regen_results.sh`, `jobs/stage-build.sh`, `py/chunk_regions.py` and `py/bed_intersect.py`.
- **Updated:** `00_preflight.sh`, `config.sh`, `lib.sh`, `README.md` (Part B and Part D runbooks) and `data-prep/sources.tsv`.
- **Manifests:** `staged_manifest.tsv` and `staged_ref_manifest.tsv` are written by `stage-build` on Negishi, come back in the Part B tarball, and are committed then.

Layout fixed for the episodes:
- **Workspace:** `$SCRATCH/varcall-workshop/` holds `data/` (`HG00N_R1/R2.fastq.gz`, `md5sums.txt`, `samples.tsv`, `trio.ped`), `ref/`, `resources/` (`truth/`, `gnomad/`, `regions/`), `scripts/`, and `results/` with `qc`, `bam`, `qc_alignment`, `vcf`, `eval`, `annot` and `trio`.
- **Reference links:** `ref/` is created by one learner command, `ln -s /depot/workshop/data/varcall-workshop_ref/* ref/`. `varcall-workshop_ref/` stages the files under learner-facing names: `GRCh38_no_alt.fa` with `.fai`, `.dict` and the bwa index under the same prefix, `GRCh38_no_alt.sdf`, `snpeff_data/GRCh38.mane.1.2.ensembl` and `SOURCES.tsv` (NCBI origins).

Checks run:
- **Static checks:** `bash -n` on every script. shellcheck 0.10.0 is clean on the kit and pipeline scripts (two justified `SC2034` disables in `pipeline/lib.sh`). On the learner scripts, run with `-e SC2086,SC2164,SC2103,SC2231,SC2034`. Reason: they are typed-terminal style, as in the RNA-seq lesson (unquoted variables, bare `cd`, every `samples.tsv` column named on read); the one real issue, unquoted command substitutions in the funnel `printf`, was fixed.
- **Python:** `py_compile` and real runs of every script under Python 3.6.15 (`python:3.6-slim`); output is identical to 3.13.
- **Dry runs:** `restage.sh --build --dry-run` and `run_reference.sh --dry-run` print the full graph with `--account=rcac-rnaseq --partition=cpu --qos=standby`, cores and time, and no memory request.
- **Greps:** no `--mem` and no URL outside `sources.tsv` and `config.sh`.
- **Lesson:** `sandpaper::validate_lesson()` is clean, and the only new Markdown is two levels down (`pipeline/docs/ADAPTATIONS.md`).
- **Local end-to-end test:** a 40 kb synthetic trio, with module commands shimmed to `docker run` of `bwa:0.7.17`, `samtools:1.22.1` and `staphb/bcftools:1.24`. `align.sh` and `call.sh` ran verbatim, then `05-merge.sh`, `06-filter.sh`, the gnomAD step of `annotate.sh` (SnpEff replaced by a stand-in `ANN`), `07-annotation-tables.sh` and `08-trio.sh`, all without a failed command. The funnel ended at exactly the simulated de novo and recessive sites, and `report.py` gave them the right truth status. `evaluate.sh` (hap.py), SnpEff, FastQC, MultiQC and mosdepth were not run locally.

Findings and deviations:

- `[should-fix]` The prompt's `call.sh` command has no GQ, but `bcftools call -m` writes FORMAT/GQ only when asked. `call.sh` adds `-a FORMAT/GQ`, needed by the genotype filter (Episode 6) and the trio evidence filter (Episode 8).
- `[check]` `samtools markdup --write-index` (samtools 1.22.1) writes a `.csi` BAM index, not `.bai`; mosdepth and bcftools read it. P6 must confirm that the chosen IGV route reads CSI. Otherwise switch to `samtools index` (`.bai`).
- `[check]` hap.py inputs use `--write-index=tbi` (`evaluate.sh`) in case the old htslib inside hap.py 0.3.9 does not read CSI for VCF; every other output uses `-W` (CSI).
- `[should-fix]` bcftools regex alternation inside a quoted `~` string does not work: `INFO/ANN~"[|](HIGH|MODERATE)[|]"` and `INFO/ANN~"HIGH|MODERATE"` match nothing in 1.24, while `INFO/ANN~"[|]HIGH[|]" || INFO/ANN~"[|]MODERATE[|]"` works (staphb 1.24 container). The learner blocks use the two-term form. Episodes 7 and 8 must not show the alternation form.
- `[nice]` Tested in the staphb bcftools 1.24 container:
  - `+mendelian2 -P` works again (1.17 rejected it);
  - `+split-vep` reads SnpEff `ANN`, including `-s worst`, `%INFO/...` and mixed `-i` expressions; SnpSift `extractFields` stays a kit-side fallback check;
  - `filter -S .` without `-s` keeps sites and masks genotypes;
  - `MIN(FMT/DP)` and `FMT/AD[1:1]` subscripts work;
  - `stats -T ^bed` gives the complement;
  - `plugin -l` lists `mendelian2`, `trio-dnm3`, `split-vep` and `fill-tags`.
- `[nice]` Chunk regions now cut inside N-runs of 1 kb or more near the equal-length points (`py/chunk_regions.py`), so no variant can straddle two chunks. Cuts with no N-run nearby fall back to the equal-length point and are listed in `records/stage/chunks.txt`.
- `[check]` New source `ucsc_centromeres` (UCSC hg38 `centromeres.txt.gz`, 1549 bytes, md5 94cb08b0b00932436cf4d5704257e224, checked 2026-10-09) gives the chr20 centromere span, 26,436,232-30,038,348, for the by-region breakdown. It is staged as `resources/regions/chr20_centromere.bed`.
- `[should-fix]` Interim thresholds, which G3 confirms or changes:
  - `06-filter.sh`: QUAL < 30, mean MQ < 30, HighDP above twice the median site depth (the block computes the cut), genotypes with DP < 10 or GQ < 20 masked;
  - `08-trio.sh`: GQ >= 20 and DP >= 10 in all three samples, no ALT reads in either parent for de novo candidates, gnomAD AF < 0.01 (or absent) both globally and in asj.

  `metrics-CS` writes the distributions and the proposal before any hap.py job runs.
- `[check]` Depot group: `/depot/workshop/data` is `drwxrws--- jin456:workshop` (P2 preflight), so learners must be in the `workshop` group. `check_staged.sh --perm group` also checks that each file's group is `STAGED_GROUP` (`workshop`). Confirm the group before Part B.
- `[nice]` `.gitignore`: only `maintenance/prompts/` is ignored now, so the plan, log and memos track normally (restores the P1 intent). An exception `!pipeline/docs/` was needed because a global `docs/` rule hid `pipeline/docs/ADAPTATIONS.md`. Run directories and P3 tarballs are ignored.
- `[nice]` `negishi-run/lib.sh`:
  - `kit_metric` and the record header take `KIT_LABEL` (pilot in P2, "reference run, not frozen" in P3);
  - `kit_submit` takes `--time`;
  - `kit_fetch` and `kit_dep` are unchanged from P2.

What only Negishi can verify, and the check that covers it:

| Not verifiable off-cluster | Covered by |
|---|---|
| Wrappers pass quotes, tabs and backslashes (bcftools `-i`/`query -f`, samtools `-e`, SnpSift filter, bwa `-R`) | preflight "quoting" rows, plus the wrapper kind (`run` is a FAIL) |
| bcftools 1.24 plugins on Negishi | preflight plugin rows (`trio-dnm3` required) |
| rtg inside the hap.py image; vcfeval with an SDF template | preflight (synthetic SDF), `stage-build` (`records/stage/rtg.txt`) |
| Containers can read Depot through learners' `ref/` links | preflight "Depot visible inside containers" |
| `rcac-rnaseq` association; learner headers accepted | preflight `sacctmgr` rows and `sbatch --test-only` on every learner script and kit job |
| Staged copies complete, group-readable, nothing extra | `restage.sh --install` and preflight `check_staged.sh` rows |
| chr20 N-runs usable as chunk cuts | `records/stage/chunks.txt` |
| bwa `-K` determinism at 16 vs 32 cores on real data | `det-compare` (`records/determinism.tsv`) |
| hap.py 0.3.9 reads the CSI/TBI indexes, `--engine-vcfeval-template` on the real SDF | `eval-CS`, `evalsum-CS` |
| SnpEff from the staged `ref/snpeff_data` through the symlink | `annot-CS` |
| Runtimes, memory and waits of every step | `sacct_summary.tsv` in the Part B tarball |

### Phase 3 Part B preflight, 2026-10-09 (first run on Negishi, login06)

Preflight: FAIL 16, WARN 2 (the two WARN rows are the staged copies, not built yet). Verified on Negishi:
- **Modules:** bcftools/1.24 and htslib/1.24 load and are the defaults. Plugins `mendelian2`, `fill-tags`, `split-vep` and `trio-dnm3` are listed.
- **Quoting:** the bcftools `-i`/`query -f`, SnpSift and bwa `-R` checks pass.
- **Infrastructure:** containers see Depot; every kit job and learner script passes `sbatch --test-only`; the compute node has internet access, including the new UCSC host.

- `[should-fix]` Account: the user chose `rcac` for now; a workshop-specific account comes later. Changed in `config.sh`, the four learner script headers and the six `sinteractive` lines. These replace the G2 value `rcac-rnaseq`. The account lives in three places, not two as the prompt said: the `sinteractive` lines carry it too, and preflight checks all three. This cleared 10 FAIL rows.
- `[blocker]` Wrappers still on `singularity run`: bwa/0.7.17, samtools/1.22.1, fastqc/0.12.1 and multiqc/1.23. samtools shows the effect: `samtools view -c -e 'rname=="chrT"'` printed nothing. bwa `-R` passed, because its argument has no embedded quotes. Switching these four wrappers to `exec` is a module-side fix.
- `[check]` `rtg format in the hap.py image` failed (`preflight/happy_rtg.txt` not seen here). The likely cause is that the kit called `apptainer exec` on the image directly, without the wrapper's binds and options; hap.py's own vcfeval run passed, so rtg itself works. New `lib.sh` helpers: `kit_wrapper_prefix` (the module wrapper's own container command) and `kit_happy_rtg` (hap.py's `--engine-vcfeval-path` default, else a search). Preflight and `stage-build` now run rtg through them, and the FAIL row carries the error text.

- `[check]` Second preflight (2026-10-09, 22:29): FAIL 1, WARN 2. All wrappers now use `exec` and every quoting check passes. The account rows pass with `rcac`. Remaining FAIL: `/opt/hap.py/libexec/rtg-tools-install/rtg: Unable to execute java`. The launcher cannot start Java when called directly, although hap.py's own vcfeval runs (which call the same rtg) pass. New `kit_rtg_format` (`lib.sh`) tries four ways in order, each into its own temporary directory, and moves only a complete SDF into place: the launcher without `RTG_MEM`, the launcher with `RTG_MEM`, the Java named in the launcher's `rtg.cfg` on `RTG.jar`, then Java from `PATH` on `RTG.jar`. It records PATH, `java -version` and `rtg.cfg` from inside the container in `preflight/happy_rtg.txt`, or `records/stage/rtg_format.log` for `stage-build`. Tested locally on a mock where the launcher fails.

- `[check]` Third preflight (2026-10-10): FAIL 0, WARN 2 (staged copies not built yet). rtg format works by way 4 (`java -jar RTG.jar` with java from PATH inside the hap.py image), and hap.py vcfeval with the SDF template passes.
- `[should-fix]` `stage-build` job 44043753 failed within about 2 minutes; `restage.sh --install` then refused, as designed. Probable cause, not yet confirmed from the job log: the diagnostic line `$PRE "$RTG" version | head -5` calls the rtg launcher, which fails ("Unable to execute java"), and under `set -euo pipefail` that kills the job before the SDF step. Fixed with `|| true` on that diagnostic line. Also hardened: the `@RG` lookup read `samtools view -H | grep -m1`, which can SIGPIPE samtools under `pipefail`; it now reads the whole header first and stops if there is no `@RG`.
- `[should-fix]` Job 44043753 actually failed on `missing state/ref.env`: the phase-2 prep folder had been removed before Part B, so the prep was rerun with `data-prep/01`-`05`. The prep outputs must stay in `$SCRATCH/varcall-prep` until Part D.
- `[should-fix]` `stage-build` job 44051852 failed at the `@RG` lookup with `samtools: command not found` (exit 127). `kit_load` purges before loading, so loading the hap.py module for the SDF step dropped the samtools, bcftools and htslib modules loaded at the top of the job. The job now loads them again after the SDF step. No other job loads a second module and then uses the first (`report.sh` uses only SnpSift after loading it).
- `[check]` Staged and checked 2026-10-10: `stage-build` job 44052021 PASS, `restage.sh --install` and `check_staged.sh` 0 problems on both copies, preflight FAIL 0, WARN 0.
- `[should-fix]` `run_reference.sh` stopped after submitting the 16 q0 steps: `call-q20` is submitted from the q20 copy's `scripts/`, which `fork-q20` creates only after alignment, and sbatch reads the script at submission. The submitter now creates q20's `scripts/` (hard links to q0's) on the login node, and `fork.sh` keeps it. Also, a rerun skipped only finished steps and would have resubmitted queued ones; `want()` now also skips a step whose recorded job is still queued or running. Tested locally with stub `sbatch`/`squeue` in the failed state: the q0 steps are skipped and the q20 chain depends on the queued `fork-q20`.
- `[should-fix]` First reference run `ref-2026-10-10` (records tarball 18:26) stopped at two kit failures; everything after them was cancelled by dependency. (1) `fork-q20` ran the old `fork.sh`, which refuses an existing copy directory: sbatch stores the script at submission, so a job submitted before a kit update keeps the old code (the earlier note that it would pick up the new file was wrong). (2) `merge-q0`: `bcftools view -H ... | head -3` in `05-merge.sh` gave `KIT-ERR rc=141`. `set -E` in the session file made the ERR trap fire inside the module's wrapper function on the tool's SIGPIPE, although the pipeline succeeded. `set -E` removed from `run_block` (`pipeline/lib.sh`); tested locally: without it, `tool | head` is not reported, while failing function calls, failing `$(...)` and failing commands still are, each once. Alignment, calling, QC and the determinism check completed: HG002 at 16 and 32 cores gives the same md5 of `samtools view -h` without `@PG` (18,980,761 records), PASS.

### Phase 3 Part C, 2026-10-10 (records `varcall-p3-records-ref-2026-10-10-20261010-1908`; memo `maintenance/plan/reference-run.md`)

All values "reference run, not frozen".

- `[check]` Run `ref-2026-10-10` complete after the two kit fixes: 20 step markers PASS, no `KIT-ERR` in any console, determinism PASS (HG002 16 vs 32 cores identical), staged copies 0 problems, preflight FAIL 0, WARN 0. q0 agrees with the pilot within 0.0003 on every recall and precision value.
- `[check]` Staged manifests (`negishi-run/staged_manifest.tsv`, `staged_ref_manifest.tsv`) brought back from the run and identical to the `stage-build` copies.
- `[check]` q0 vs q20 (`-q 20 -Q 20`): inside the benchmark within 0.001 for SNVs; indels worse with q20 throughout. q20 adds calls in the centromere and outside the benchmark (whole-chr20 PASS Ts/Tv 1.96 vs 2.01) and halves what the LowMQ site filter catches (2,502 vs 6,407 sites). Recommendation q0 (G3).
- `[should-fix]` The genotype mask (FMT/DP < 10 or GQ < 20) causes almost all of the indel recall loss from filtering (HG002 v4.2.1 0.943 to 0.908) while precision rises (0.947 to 0.971); indel F1 falls 0.9449 to 0.9383. SNV F1 rises 0.9905 to 0.9911. Keep and teach as the trade-off, or mask on DP only (G3 decision 2).
- `[blocker]` 33 of the 41 de novo candidates left after the trio-region step are de novo in both HG002 truth sets (child het in v5.0q and v4.2.1, both parents hom-ref inside their benchmarks); 30 SNVs, 3 indels, 11 within 50 kb near 11.1-11.2 Mb. The plan expects about 1-2 germline de novo SNVs on chr20, and NIST's HG002 subclonal benchmark (85 SNVs genome-wide at AF > 5%) does not account for them. Episode 8's framing "most candidates are errors" does not hold after step 3. Next: child allele fractions at these sites (command in the memo, decision 3). Blocks the Episode 8 text, not the anchors.
- `[check]` Episode 8 funnel ends at zero in both models (de novo 312, 81, 41, 0, 0; recessive 5,282, 5,282, 4,632, 8, 0). The recessive evidence step removes nothing after the genotype mask.
- `[check]` Mendelian consistency (q0, PASS): 449 errors, 144,536 consistent, 0.31%.
- `[should-fix]` `evaluate.sh` array task 2 (HG002 v5.0q, 2 hap.py runs) peaked at 35.1-35.6 GiB MaxRSS on 16 cores, above what 16 cores provide (about 31 GiB). Proposed `--cpus-per-task=24` (G3 decision 6).
- `[check]` ACMG SF v3.3 (84 genes, August 2025): none of the 27 genes among HG002's rare protein-altering, HIGH-impact and recessive-impact variants (both call sets) is on the list. Gene list local only (`.claude/notes/`, gitignored).
- `[nice]` Every bcftools read of these VCFs prints `[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float`. Episode 5A callout proposed.
- `[check]` Annotation: `+split-vep` and `SnpSift extractFields` both work (240 rows for HG002). HG002 PASS variants 115,059; HIGH 3; HIGH or MODERATE 240; rare 20 by global AF and 12 by asj AF.

### Phase 3 Part D, tasks 1-4, 2026-10-10 (G3 decided; finalize run pending)

- `[check]` G3 recorded in the Decisions table.
- `[check]` Learner scripts final: `call.sh` without the `READ_FILTERS` line (q0, mpileup defaults); `evaluate.sh` at 24 cores. Kit: `REF_CALL_SETS=q0`, the `READ_FILTERS` plumbing removed, a fork job only for call sets other than q0 (16 jobs per run).
- `[should-fix]` `evaluate.sh` passed `--threads $SLURM_CPUS_PER_TASK` to hap.py; at 24 cores that means 24 threads, and memory appears to grow with threads (23.9 GiB at 8 threads in the pilot, 35.6 GiB at 16 here). Fixed at `--threads 16` on 24 cores. Not yet measured at 24 cores.
- `[should-fix]` `evaluate.sh` array tasks 1 and 2 (HG002 v5.0q and v4.2.1) wrote the same `results/eval/HG002.<calls>.vcf.gz` at the same time; the first run was unaffected, but the race could corrupt the hap.py input. Each task now writes `<sample>.<truth>.<calls>.calls.vcf.gz`. Nothing else reads those files.
- `[check]` `restage.sh --example --run RUN_ID`: cuts `resources/example/` (raw and filtered VCFs for `EXAMPLE_REGION`, chr20:60000-90000), checks for het, hom-alt, indel, multiallelic and not-PASS records, grows the region to the nearest multiallelic site if needed, and rewrites the manifest. Tested locally with bcftools 1.24 (staphb image) on mock VCFs: the widening path and the failure path both work; the failure path leaves the manifest untouched.
- `[check]` `regen_results.sh --finalize` now refuses a run whose `scripts/` differ from `pipeline/learner-scripts/`, and a staged example that differs from the run's filtered calls in its region. `report.sh` writes `records/<cs>/trio/denovo_3_regions_af.tsv` (child, father and mother AD; child allele fraction) for the memo.
- `[check]` Runbook (`negishi-run/README.md`, Phase 3 finalize) adds a final q0-only run before `regen_results.sh`: the first run used the pre-G3 scripts, and the results copy ships the run's `scripts/`. The rerun also gives the second run for the determinism of calling, evaluation and trio steps.
- `[should-fix]` For P5: Episode 5A callout that the `MQ should be declared as Type=Float` warning is harmless; Episode 6 teaches the genotype mask as the precision-recall trade-off. For P6: Episode 8 frames the 41 de novo candidates after the region step as mostly real cell-line variants (NIST HG002 mosaic benchmark paper), keeps the zero-candidate funnel, and explains why the recessive evidence step removes nothing.

### Phase 3 Part D, final run and anchors, 2026-10-10 (records `varcall-p3-records-ref-final-2026-10-11-20261010-2016`)

- `[check]` `restage.sh --scripts`, `--example` (chr20:60000-90000, no widening: 1 multiallelic site before norm, 116 records not PASS) and `--install`: 0 problems on both staged copies. Updated `staged_manifest.tsv` brought back (36 files, `resources/example/` and final scripts; sizes match the repo).
- `[check]` Final run `ref-final-2026-10-11` (q0, final learner scripts): 12 steps PASS, determinism PASS. All 57 anchor values and 5 sentinels identical to `ref-2026-10-10`, so every step is reproducible, not only alignment. Anchors frozen in `negishi-run/anchors.tsv` (tolerance exact).
- `[check]` `evaluate.sh` at 24 cores, 16 threads: MaxRSS 1.75-6.31 GiB, 89-145 s per task. The first run's 35.6 GiB peak did not recur.
- `[check]` De novo allele fractions (memo section 6): the 33 truth-supported candidates have a mean child AF of 0.44 (median 0.455; 3 below 0.3), with zero ALT reads in both parents. Heterozygous fractions point to clonal variants, germline or early cell line; they are not the low-fraction subclonal variants of the NIST mosaic benchmark. The P6 framing of "cell-line variants" needs this nuance.
- `[check]` Results copy: `regen_results.sh --finalize --call-set q0 --run ref-final-2026-10-11` passed both guards (final scripts; example matches the run's calls) and wrote `/depot/workshop/data/varcall-workshop_results.2026-10-10` (6.6 GB, 235 files); swapped in as `/depot/workshop/data/varcall-workshop_results` (no earlier copy existed). `check_staged.sh --results`: 0 problems. `negishi-run/staged_results_manifest.tsv` brought back. Part D accepted: both staged copies and the results copy pass `check_staged.sh`; `anchors.tsv` traces to the final run; episodes and learner pages untouched. G3 frozen.

### Phase 4 Part A, 2026-10-10 (prompt-04-episodes-1-4.md; branch `dev/p04-episodes-1-4` from `main` at f628d91)

Episodes 1-4, the full setup page and run kit v1, written and checked on the laptop. Nothing was run on Negishi in this part; every output block and dataset number not held by `anchors.tsv`, `reference-run.md` or `feasibility.md` is a `{{kit:...}}` placeholder that Part C fills from the kit run.

Files:
- **Episodes:** `01`-`04` written to plan 3.4 with the Prompt 04 front-matter times (35/15, 20/20, 15/15, 45/45, unchanged). `04` shows `align.sh` byte-for-byte from `pipeline/learner-scripts/align.sh`; every interactive block matches `pipeline/learner-scripts/interactive/` (checked by the kit). Episodes 5A-8 untouched.
- **Figures:** `episodes/fig/03/contrast_*.png`, six FastQC cartoons by Zandra Selina (CC BY 4.0) copied from `../rnaseq-analysis/episodes/fig/02_qc/examples/` with their RNA-seq captions and alt text. Seven figure slots for the MultiQC plot exports (`<!-- kit: figure ID -->`) wait for Part C.
- **Learner pages:** `learners/setup.md` complete (instructors, schedule with date `TBD(P10)`, prerequisites, scope with the dataset facts, toolchain table with the pinned modules of `pipeline/learner-scripts/`, not covered, SSH, data setup with the canonical copy and link commands, verification, scratch purge, completed results, `TBD(P6)` graphical session); `learners/reference.md` gains 22 glossary terms and the list of sources cited in Episodes 1-4.
- **Kit:** `negishi-run/build_kit.py`, `kitrun.sh`, `submit_all.sh`, `py/summarize.py`, `docs/ADAPTATIONS.md`; `collect.sh` gains `--run` (without it, the phase-2 collection is unchanged); `config.sh` gains `KIT_RUNS`; `README.md` gains the Phase 4 runbook and the account swap.
- **Figure specification:** `maintenance/plan/figures/reads-to-genotype.md` (storyboard of 8 scenes, about 80 s, Play and `?autoplay=1`, alt and title text).

Kit design: every bash fence carries an invisible marker, `<!-- kit: script|interactive|extra|submit|not-run ... -->`; `build_kit.py` fails on an unmarked fence. The step graph is `02-setup` (login node: setup page and Episode 2), `03-qc` (batch job with the `sinteractive` resources), `04-align` (the learner's staged `scripts/align.sh`), `04-alignqc` (batch job after `04-align`).

Static validation (all pass):
- `python3 negishi-run/build_kit.py --check`: all kit checks pass; 39 bash blocks (script 1, interactive 15, extra 9, submit 1, not-run 13), 4 steps, 27 placeholders, 7 figure slots; `generated/` matches a fresh build.
- Kit checks fire: a mutation test on a copy of the repository (14 mutations: script text, interactive order, account in an episode and in a learner block, `--mem`, a command URL not in `sources.tsv`, a cited URL missing from `reference.md`, front matter, an extra block that writes, a fallback path missing from the results manifest, an unmarked fence, a staged-script md5, a placeholder without a handler, the submit block) caught all 14.
- `bash -n` on every kit script, generated job and session; shellcheck 0.10.0 (Docker `koalaman/shellcheck:v0.10.0`) clean on `kitrun.sh`, `submit_all.sh`, `collect.sh` and the generated jobs, and on the generated sessions with the P3 learner-style excludes (`-e SC2086,SC2164,SC2103,SC2231,SC2034`).
- `py_compile` of `build_kit.py`, `py/summarize.py` and `py/sacct_summary.py`, and `build_kit.py --check`, under Python 3.6.15 (`python:3.6-slim`).
- `submit_all.sh --run test-dry --dry-run` with a stub `sbatch` (rejects `--mem` and any account but `rcac`): 4 steps, 3 test-only submissions accepted.
- `summarize.py` on a synthetic run: the alignment-anchor table PASSes 17 values and FAILs the one changed on purpose; runtime, placeholder, figure and console sections fill; FastQC values parsed from a real FastQC 0.12.1 zip; the `tview` counts parsed from real output.
- The Episode 4 read-only commands (`samtools view` of a region, `samtools flags 99 1123`, both `samtools tview -d T -i -w 41 -p ...`) ran on a synthetic 90 kb chr20 with the pinned `samtools:1.22.1` container.
- `sandpaper::validate_lesson()` (sandpaper 0.17.1) clean; `sandpaper::build_lesson(preview = FALSE)` builds; titles render as "1. ..." to "4. ..."; no Markdown from `maintenance/` or `negishi-run/` rendered (the stale `site/built/prompt-01-scaffold.md` is from P1, noted then).
- No em or en dashes in the changed files.

Findings and decisions:
- `[check]` Extra commands. Plan 3.4 and the prompt ask for commands that are not in `pipeline/learner-scripts/interactive/`: `samtools faidx`, the `.fai` and `.dict` heads, a BED head and a FASTQ head (Episode 2); `samtools view` of a region, `samtools flags`, and two `samtools tview -d T -i` views (Episode 4); plus one `cd $SCRATCH/varcall-workshop` so Episode 2 works in a new login. They are marked `extra`, run in the kit, and `build_kit.py` refuses any extra block that writes, creates, removes or submits, so no canonical command or anchor input changes. Decided 2026-10-10: the exact-match rule applies to commands that create or change files or submit jobs; read-only inspection commands may appear only in episodes if the kit check confirms they write and submit nothing. Recorded in `.claude/CLAUDE.md` and `negishi-run/docs/ADAPTATIONS.md`.
- `[should-fix]` `samtools tview -d T` ruler labels do not sit at the `-p` position (seen on the synthetic test: `-p chr20:88088` labels 88091, 88101, 88111). The episode places the site in column 21 instead and adds `-i` (hide insertions) so that columns are reference positions; `summarize.py` reads column 21 and the consensus line.
- `[check]` Account `rcac` now also appears on the setup page (`-A rcac` in the prerequisites) and in the two `sinteractive` lines of Episodes 3 and 4. The README one-line swap was tested on a copy: it rewrote 5 headers, 9 `-A` values and `config.sh`; the staged-script md5 check then fails until `restage.sh --scripts` and `--install` are run on Negishi, as intended.
- `[check]` MultiQC 1.23 `--export` (PNG) inside the biocontainer is not verified (it needs a static-image backend). The export is a kit extra: a failure is a WARN and Part C falls back to screenshots or the `multiqc_data` tables.
- `[check]` Spoiler descriptions written before the run that Part C must verify against the output: the `flagstat` line explanation, the `mosdepth` summary `total` row, the `samtools stats` field names, the 3-line `tview` header (ruler, reference, consensus), and the `samtools view -c -e 'mapq==0'` count against `reads MQ0` (983,436).
- `[nice]` Plan 3.4 Episode 4 "optional tiny-FASTA demo" of index building: replaced by a not-run `bwa index` spoiler (a demo would write files). Plan 3.4 Episode 2 "writing `samples.tsv` and `trio.ped`": per the prompt, learners inspect the staged files and write one PED line in a challenge.
- `[nice]` `.gitignore` should ignore extracted kit tarballs (`varcall-p4-*/`) at the repository root; `.gitignore` is outside the Part A file list, so not changed. Done by the owner in Part C (`varcall-p*-*/`).
- `[nice]` FastQC duplication (Episode 3) is compared with the duplicate fractions after `markdup`, 10.44%, 10.98% and 10.99%, computed from the frozen `reads_duplicated` and `raw_total_sequences` anchors. Mapping and pairing percentages in Episode 4 are computed the same way.

Placeholders for Part C (27): `setup-out-ls`; `02-out-md5`, `02-out-samples-ped`, `02-out-fai-dict`, `02-out-faidx`, `02-out-bed`, `02-sol-bed-region`, `02-sol-bed-length`, `02-out-fastq`; `03-out-multiqc-ls`, `03-sol-reads`, `03-sol-status`, `03-sol-adapter`, `03-sol-duplication`; `04-out-ls-bam`, `04-out-flagstat`, `04-out-stats-sn`, `04-out-mosdepth`, `04-out-mapq0-rg`, `04-sol-insert`, `04-sol-cov10`, `04-sol-mapq0-view`, `04-out-view-region`, `04-out-flags`, `04-out-tview-het`, `04-sol-tview-het`, `04-sol-tview-homalt`. Figure slots (7): `03-fastqc-per-base-quality`, `03-fastqc-per-sequence-quality`, `03-fastqc-gc`, `03-fastqc-duplication`, `03-fastqc-adapter`, `04-multiqc-samtools-alignment`, `04-multiqc-mosdepth-cumcoverage`. Each id, its line and its source are in `negishi-run/generated/placeholders.tsv` and `figures.tsv`.

Claims cut or changed for lack of an acceptable source:
- Episode 1: "public reference samples from healthy volunteers" (now "public reference samples"); "long-read methods address these limits" (now "other methods, such as long-read sequencing, are needed"); "tens of thousands of heterozygous sites per person" (now the benchmark count, more than 70,000 SNVs for HG002 on chr20).
- Episode 2: plan 3.4's "GIAB consent permits public release" (replaced by NIST's redistribution terms from the v5.0q README); "cell lines such as ours are made with EBV"; "tools such as PLINK report an error when a father is not male".
- Episode 3: "older Illumina instruments reported about 40 quality values".
- Episode 4: "PCR-free duplicates are mostly optical"; "duplicate-flagged reads are not shown by tview"; "MultiQC parses the markdup statistics"; "sorting before fixmate makes markdup fail or mark nothing" (softened to what the samtools manual supports); "much of the centromere is N in the reference" (wrong for GRCh38, removed).
- Sources used beyond the plan's list are official documentation or run records: the SAM, VCF and BED specifications, the bwa, samtools, bcftools, mosdepth, FastQC, fastp, PLINK and GATK manuals, bwa `README-alt.md`, the NCBI analysis-set README (captured in the P2 records), the feasibility and reference-run memos. All are listed in `learners/reference.md`, and `build_kit.py` fails if an episode cites a URL that page does not list.

Part B commands (from `negishi-run/README.md`, Phase 4):
1. Laptop: `python3 negishi-run/build_kit.py`, then `python3 negishi-run/build_kit.py --check`, then `rsync -av --relative ./episodes ./learners ./negishi-run ./pipeline ./data-prep aseethar@negishi.rcac.purdue.edu:/scratch/negishi/aseethar/variant-calling/`.
2. Negishi: `bash negishi-run/00_preflight.sh` (FAIL 0).
3. `bash negishi-run/submit_all.sh --run kit-2026-10-11 --dry-run`, then `bash negishi-run/submit_all.sh --run kit-2026-10-11`.
4. When `squeue -u $USER` is empty: `bash negishi-run/collect.sh --run kit-2026-10-11`, and run the printed `rsync` on the laptop.

### Phase 4 Part C, 2026-10-10 (kit run `kit-2026-10-11`, tarball `varcall-p4-kit-kit-2026-10-11-20261010-2143.tar.gz`)

Run check: `build_kit.py --check` passed at submission; all four steps completed (`02-setup` PASS on the login node in 46 s; `03-qc`, `04-align` x3 and `04-alignqc` COMPLETED, markers PASS); no `### KIT-ERR` in any console; `sources_check.txt` 17 of 17 OK (the run used the committed episodes and learner scripts); modules resolved to bwa/0.7.17, samtools/1.22.1, mosdepth/0.3.3, fastqc/0.12.1, multiqc/1.23; both MultiQC PNG exports PASS (12 and 10 plots). All 18 alignment anchors match `anchors.tsv` exactly, so alignment reproduces for the third time (two P3 runs and this one). No learner command failed.

Filled from the run (27 placeholders, 7 figures):
- Output spoilers: the console output of each block, verbatim. Trimmed only: the biocontainers banner ("User guides for each biocontainer module ...") that `module load` prints, in `02-out-faidx` and `04-out-ls-bam`, and MultiQC's start banner and update notice in `03-out-multiqc-ls`. Both spoilers now say that `module load` prints such a message.
- Solutions: the BED region `chr20:81336-101267` (19,932 bp); FastQC read counts; module status (only Per sequence GC content, WARN in all six files); adapter content; FastQC duplication (14.7% to 15.7%); insert sizes (410.1, 417.8, 399.4 bp); 98.0% of chr20 at 10x or more in HG002; `samtools view -c -e 'mapq==0'` 1,054,357 against `reads MQ0` 983,436; the two `tview` columns.
- Figures: seven MultiQC exports copied to `episodes/fig/03/multiqc_*.png` (per-base quality, per-sequence quality, GC content in percent, duplication, adapter content) and `episodes/fig/04/multiqc_*.png` (samtools alignment in percent, mosdepth cumulative coverage), each with a caption and descriptive alt text written from the plot.

Text corrected from the run (old, then new):
- `[should-fix]` Episode 4, het site chr20:88,108: "Roughly half the reads carry `C`" became 14 of 39 reads carry `C` (36%), with the binomial point that 14 or fewer of one allele out of 39 happens about 5% of the time at a balanced site. The genotype and the benchmark (`0/1`) are unchanged.
- `[should-fix]` Episode 3, adapter content: the highest lines (1.43% to 1.49%) are FastQC 0.12's poly-A series, not adapter; the Illumina Universal Adapter reaches 0.37% to 0.54%. The text now says that FastQC counts poly-A and poly-G in this module.
- `[should-fix]` Episode 3, per-base quality: "boxes and whiskers jump between the four values" became what the data show: median and quartiles 37 at every position, the 10th percentile 25 near the read end, MultiQC means near 35 to 36.
- `[should-fix]` Episode 3, GC content: "a single smooth peak is expected ... reflects chromosome 20" became the observed curve (peak near 40% GC, shoulder near 50%, identical in all six files, FastQC WARN) and why that does not point to contamination.
- `[nice]` Episode 4: BAM size "about 1.1 GB" became "about 1 GB" (HG004 is 1015M); the FLAG challenge's third answer now decodes the reads in the output (163, and 1171 = duplicate of the 147 read with the same position, mate position and template length); the MAPQ 0 solution now explains the 70,921 difference (unmapped reads, 36,402, carry MAPQ 0; `samtools stats` counts only mapped reads and leaves out supplementary alignments, 55,861 in all); the flagstat spoiler names the primary, supplementary and singleton counts; the `.fai` spoiler gives 195 sequences and the `.dict` fields `UR`, `AS`, `SP`.
- Runtimes: Episode 3 "about 3 minutes" became "about 4 minutes" (217 s); Episode 4 alignment "11 to 13 minutes" became "10 to 14 minutes" (585-833 s here, 651-750 s in P3); setup page "reference run" became "test runs" (46 s here, 44 s in P3). Every other number in Episodes 1-4 and the setup page matches the run or the frozen records (checked line by line).

Runtimes against front matter: Episode 2, 0.8 min of work against 40 min (live 20); Episode 3, 3.6 min (wait 0.1) against 30 (live 15); Episode 4, alignment 9.8-13.9 min plus QC 3.9 min (waits 0.1 and 1.8 min) against 90 (live 70). Alignment stays under the plan's 15-minute live-job rule; the schedule in plan section 4 holds.

Kit fixes after the run:
- `[should-fix]` `py/summarize.py` reported a 15.8 min "wait" for `04-alignqc`: it counted the time the job waited for its dependency. The wait of a dependent step is now measured from when its last dependency ended (recomputed from this run's sacct: about 1.8 min).
- `[nice]` `submit_all.sh` recorded only the total in `02-setup-du.txt` (one `du -sb` call counts subfolders once); it now runs `du -sb` per path.
- `[nice]` Extracting the tarball at the repository root made `sandpaper::build_lesson()` render its `SUMMARY.md` (one folder down). The extraction now lives in the gitignored `negishi-run/records/`. `.gitignore` now also ignores `varcall-p*-*/` (owner change, 2026-10-10), which keeps such folders out of git but not out of a local `build_lesson()`, so extract kit tarballs under `negishi-run/records/`.

Checks after the edits: `build_kit.py --check` passes (0 placeholders and 0 figure slots left; the generated sessions' commands are identical to the run's); `validate_lesson()` clean; `build_lesson()` builds; no em dashes; shellcheck 0.10.0 clean on `submit_all.sh`; `summarize.py` parses under Python 3.6.15.

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

P3 reference run `ref-2026-10-10` on Negishi, 2026-10-10, account `rcac`, QoS `standby`, partition `cpu`. Reference run, not frozen; details in `maintenance/plan/reference-run.md`.

| Step | Cores | Wall | MaxRSS (GiB) | Wait |
|---|---|---|---|---|
| `02-setup.sh` (login node) | - | 44 s | - | - |
| `03-qc.sh` | 4 | 196 s | 2.14 | 27 s |
| `align.sh`, per sample | 16 | 651-750 s | 13.4-13.5 | 27 s |
| `align.sh` HG002 (determinism) | 32 | 402 s | 13.5 | 27 s |
| `04-alignment-qc.sh` | 4 | 203 s | 0.27 | 815 s |
| `call.sh`, per chunk, q0 / q20 | 2 | 141-254 s / 122-156 s | 0.18 | 124-815 s |
| `05-merge.sh` | 4 | 13 s | <0.01 | 6-365 s |
| `06-filter.sh` | 4 | 17 s | <0.01 | 247-605 s |
| `evaluate.sh`, per task (2 hap.py runs) | 16 | 91-160 s | 1.2-35.6 | 306-713 s |
| `annotate.sh` | 4 | 89-98 s | 0.05-1.75 | 306-713 s |
| `07-annotation-tables.sh` | 4 | 15-19 s | <0.01 | 426-875 s |
| `08-trio.sh` | 4 | 29 s | <0.01 | 545-1025 s |

P3 final run `ref-final-2026-10-11`, 2026-10-10, q0 only (anchors frozen from it).

| Step | Cores | Wall | MaxRSS (GiB) | Wait |
|---|---|---|---|---|
| `align.sh`, per sample | 16 | 668-738 s | 13.4-13.5 | 16 s |
| `align.sh` HG002 (determinism) | 32 | 463 s | 13.5 | 16 s |
| `call.sh`, per chunk | 2 | 133-220 s | 0.18 | 840 s |
| `evaluate.sh`, per task (2 hap.py runs, 16 threads) | 24 | 89-145 s | 1.75-6.31 | 1578 s |
| `annotate.sh` | 4 | 86 s | 0.05 | 1578 s |

P4 episode kit run `kit-2026-10-11`, 2026-10-10, account `rcac`, QoS `standby` (wait = time from eligibility to start).

| Step | Cores | Wall | MaxRSS (GiB) | Wait |
|---|---|---|---|---|
| `02-setup` (login node: setup page and Episode 2 blocks) | - | 46 s | - | - |
| `03-qc` session | 4 | 217 s | 2.23 | 3 s |
| `align.sh`, per sample | 16 | 585-833 s | 13.34-13.47 | 3 s |
| `04-alignqc` session | 4 | 233 s | 0.27 | about 110 s after alignment ended |
