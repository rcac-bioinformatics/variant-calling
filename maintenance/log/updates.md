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
- `[should-fix]` `evaluate.sh` array task 2 (HG002 v5.0q, 2 hap.py runs; corrected 2026-10-11: task 2 is HG002 against v4.2.1, see "Phase 5 Part B") peaked at 35.1-35.6 GiB MaxRSS on 16 cores, above what 16 cores provide (about 31 GiB). Proposed `--cpus-per-task=24` (G3 decision 6).
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
- `[check]` Results copy: `regen_results.sh --finalize --call-set q0 --run ref-final-2026-10-11` passed both guards (final scripts; example matches the run's calls) and wrote the dated build directory (6.6 GB, 235 files). (Corrected 2026-10-12: the copy was never swapped in. It stayed in the dated directory until it was moved to `/depot/workshop/data/varcall-workshop_results` on 2026-10-12; see "Results copy swap, 2026-10-12".) `check_staged.sh --results`: 0 problems. `negishi-run/staged_results_manifest.tsv` brought back. Part D accepted: both staged copies and the results copy pass `check_staged.sh`; `anchors.tsv` traces to the final run; episodes and learner pages untouched. G3 frozen.

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

### Phase 5 Part A, 2026-10-10 (prompt-05-episodes-5a-6.md; branch `dev/p05-episodes-5a-6`, which holds the P4 commit d57f706; local `main` is still at f628d91)

Episodes 5A and 6, the five P4-review corrections, and run kit v2, written and checked on the laptop. Nothing was run on Negishi in this part. Every dataset number in 5A and 6 comes from `anchors.tsv`, `reference-run.md` or `feasibility.md` (labeled "reference run" where learners do not reproduce it) or is a `{{kit:...}}` placeholder that Part C fills.

Files:
- **Episodes:** `05a` and `06` written (front matter 30/30 and 40/40, unchanged); each shows its learner script (`call.sh`, `evaluate.sh`) byte for byte and the `05-merge.sh`, `06-filter.sh` and `06-evaluate-summary.sh` blocks in canonical order (checked by the kit). `02`, `03`, `04`: the five corrections only (below). Episodes 1, 7, 8, `pipeline/learner-scripts/` and the staged manifests unchanged.
- **Learner pages:** `setup.md` (module notice sentence in the toolchain section); `reference.md` (14 glossary terms, sources cited in 5A and 6, the FastQC sources for Episode 3).
- **Kit:** `build_kit.py` (pages 5A and 6, front-matter times 30/30/45 and 40/40/60, 9-step graph, "Short on time?" check, quoted text ignored by the write check of extra blocks), `kitrun.sh` (`kit_ep_done` for `call.sh` and `evaluate.sh`; kit-only `kit_mapq0_counts`, `kit_bcftools_usage`, `kit_site_counts`, `kit_filter_counts`), `py/summarize.py` (placeholder handlers; anchors extended to calling, filtering, hap.py and sentinels; hap.py tables; F1 peaks; memory headroom of `evaluate.sh`; live load; kit-only records), `collect.sh` (stats, hap.py summaries and ROC tables, kit-only records, `sinfo`, bcftools and hap.py module versions; tarball `varcall-p5-kit-*`), `submit_all.sh` (comments), new `pr_figure.py`, `docs/ADAPTATIONS.md`, `README.md` (Phase 5 runbook).

Live path: Episodes 1-4 do not mark live timings or self-paced sections. 5A and 6 now carry an instructor note with the live path, minutes per section summing to 45 and 60, and what is self-paced. `[should-fix]` P7: apply the same note to every episode.

Corrections (P4 review):
1. Episode 4, chr20:88,108: "14 or fewer `C` reads 5.4% of the time, and 14 or fewer reads of either allele 10.8%" (binomial, n = 39, checked), with a pointer to the likelihood argument in 5A. 5A repeats the numbers.
2. Episode 3, per-base quality. `[check]` The correction's premise does not hold: 25 is a bin (`:` = Q25, Episode 3's own table), and the P4 FastQC data show the 10th percentile at exactly 25.0 over the read end. What is not a quality in the data are the in-between values 27.4, 29.8, 32.2 and 34.6 (P4 kit FastQC zips), which are averages over FastQC's position groups (3 x 37 + 2 x 25 over 5 = 32.2). The text keeps "drops to 25, the next bin down", adds the grouping sentence (source: FastQC `--nogroup` help text), and takes the positions and the in-between values from new placeholders (`03-sol-q10-drop`, `03-sol-q10-between`).
3. Episode 3, poly-A and clean QC: FastQC's poly-A series is 12 A's in a row (FastQC `adapter_list.txt`); every read here came from a chr20 alignment, so the series is no reason to trim. New callout "Why these reports look clean": reads that aligned nowhere (adapter dimers, single-base reads) are largely absent (feasibility memo). The specific claim "A-rich genomic repeats contain such runs" was not written (no source at hand); the text says such runs occur in the genome itself.
4. Episode 4, MAPQ 0 gap: option 1. The text is unchanged; the kit-only `mapq0_counts.tsv` splits HG002's 1,054,357 MAPQ 0 records into primary mapped (`-F 0x904`), unmapped, supplementary and secondary, so Part C fixes the wording from the record.
5. Module notice: the first `module load` is in Episode 2, whose spoiler said "The first line is a message the biocontainers module prints" while the kit output above it omits that line; Episode 4 said the same about "the first two lines". Both sentences now say the notice is printed and the outputs leave it out; the setup page says so once in the toolchain section. Episode 2 is outside the prompt's file list but is where the first `module load` is; the change is that one sentence.

Placeholders for Part C (65 new; ids, lines and sources in `negishi-run/generated/placeholders.tsv`): `03-sol-q10-drop`, `03-sol-q10-between`; 5A defaults from the 1.24 usage text `05a-def-skip-flags`, `05a-def-min-mq`, `05a-def-min-bq`, `05a-def-min-bq-table`, `05a-def-max-depth`, `05a-def-max-depth-callout`, `05a-def-prior`, `05a-def-ploidy`, `05a-def-multi-overlaps`; 5A outputs `05a-out-chunks`, `-header`, `-site-example`, `-homalt`, `-sentinels`, `-multiallelic`, `-split`, `-chunk-list`, `-concat-norm`, `-samples-head`, `-site-own`, `-stats`; 5A values `05a-sol-site-ad`, `-site-fmt-dp`, `-site-alt`, `-site-alt-pl`, `-site-info-dp`, `-site-pl`, `-site-gq`, `05a-site-step-all`, `-nodup`, `-proper`, `-overlap`, `-bq`, `-default`, `05a-sol-homalt`, `05a-sol-split-n`, `05a-sol-counts`, `05a-sol-missing`; 6 outputs `06-out-quantiles`, `-median`, `-predict`, `-filter`, `-filter-labels`, `-psc-filtered`, `-pass-stats`, `-tstv-regions`, `-tstv-pass`, `-tstv-centromere`, `-eval-norm`, `-eval-filtered`, `-roc`, `-eval-v421`; 6 values `06-sol-predict-highdp`, `-predict-qual`, `-predict-mq`, `-predict-mask`, `06-sol-records-before`, `-records-after`, `06-sol-missing`, `06-sol-tradeoff`, `06-sol-fpgt-snv`, `06-sol-roc`, `06-sol-f1-peak-v5`. Plus one figure: `<!-- TBD(P5 Part C) -->` in Episode 6 for `pr_figure.py`.

Multiallelic site: the memo's Part D result holds (one multiallelic record in the staged raw example, chr20:60,000-90,000), so no intermediate file is needed. Its position is not in any record on the laptop; the episode finds it with a read-only `bcftools query -i 'N_ALT>1'` on `resources/example/trio.example.raw.vcf.gz` and shows the split records in `trio.example.filtered.vcf.gz` (a shell variable carries the position). Part C reads the position from `05a-out-multiallelic`.

Tool defaults: the online bcftools manual is 1.22 (fetched 2026-10-10), so every default in 5A and 6 is a placeholder filled from the kit's 1.24 usage text. `[check]` A local look at the staphb `bcftools:1.24` image (laptop, drafting only) shows `-Q, --min-BQ [1]`, not 13 as in older manuals; `-d [250]`; `-q [0]`; `--ns [UNMAP,SECONDARY,QCFAIL,DUP]`; anomalous pairs skipped unless `-A`; `-P [1.1e-3]`; `--ploidy [2]`. Part C must confirm them from the Negishi module.

Claims cut or changed for lack of a source:
- The cause of the `MQ should be declared as Type=Float` warning: the callout says only that the VCF specification reserves INFO/MQ as Float (VCF v4.3, Table 1) and that the mpileup header declares another type (visible in the learner's `view -h` output); no claim about htslib internals. A synthetic VCF with `MQ` declared `Integer` reproduces the warning with bcftools 1.24.
- "`tview` shows duplicates, so its 39 matches the first row" (cut; already cut in P4).
- Where HighDP and LowMQ sites fall (the centromere): not written. Episode 6 gives the centromere Ts/Tv and PASS counts only as the memo measured them (all filters together).
- Ts/Tv "about 2.0-2.1 for human WGS" (plan 3.4, an approximate value without a source): replaced by the benchmark's own 2.31 (memo) and the combinatorial 0.5 for random errors.
- Alu poly-A tails as the source of FastQC's poly-A hits (no source at hand; not written).
- "Very new, frequent variants are suspicious" (known-sites proxy; replaced by a weaker statement: an unusually low known fraction suggests errors).
- Stratification numbers: no GIAB stratification BED is staged; concept only. 5B and DeepVariant comparisons omitted (nothing staged).

Findings:
- `[check]` Episode 6 MultiQC: plan 3.4 lists "`bcftools stats` and MultiQC", but `06-filter.sh` runs no MultiQC, and adding it would change a canonical file (stop-and-ask item). Episode 6 reads the `bcftools stats` sections with `grep` instead and has no MultiQC figure. Decision needed: add `multiqc -o results/vcf results/vcf` to `06-filter.sh` (interactive files are not staged, so no restage), or keep it out.
- `[check]` v5.0q SNV F1 peaks near QUAL 118, not 150 (150 is the memo's value against v4.2.1), in the P3 records (`q0/eval/*.roc.Locations.SNP.csv.gz`). The leakage callout quotes the memo's 150 (v4.2.1) and the v5.0q peak from a placeholder; its sentence "the two benchmarks do not even agree on the best value" depends on Part C confirming this.
- `[check]` The genotype mask of the v5.0q evaluation (filtered `ALL` row) is not in the memo, so Episode 6 quotes the v4.2.1 decomposition from memo section 4 and lets learners read the v5.0q rows from their own `summary.csv` (`06-sol-tradeoff`).
- `[check]` `06-evaluate-summary.sh` is typed on a login node but must wait for `evaluate.sh`; the kit runs it as a 1-task batch job (ADAPTATIONS).
- `[nice]` The ROC tables are not sorted by QUAL; the episode's lookup sorts them (`sort -t, -k1,1g`) before taking the first row at or above a threshold. Tested on the P3 tables: the v4.2.1 rows reproduce memo section 9 (QUAL 30: SNV 0.9944/0.9889; 225: 0.9906/0.9949).
- `[should-fix]` Episode 6 runs long for its 80 minutes if every self-paced part is done; the live path (60 min) marks the challenges that move to self-paced study. P10 dry run to confirm.

Live load (cores per learner, and for 20 learners; peaks are jobs that run together in the episode's flow):

| Episode | Job | Cores per learner | 20 learners |
|---|---|---|---|
| 4 | `align.sh` (3 x 16) | 48 | 960 |
| 4 | alignment QC session | 4 | 80 |
| 5A | `call.sh` (8 x 2) plus the merge session (4), open together | 20 | 400 |
| 6 | filter session | 4 | 80 |
| 6 | `evaluate.sh` (4 x 24) | 96 | 1,920 |
| 6 | summary (login node) | 0 | 0 |

`[check]` Episode 6's hap.py array is the largest load of the day: 1,920 cores for 20 learners if all start at once, against Episode 4's 960. `SUMMARY.md` prints this table from the run. Memory headroom from the P3 records: 24 cores provide 47.1 GiB (Negishi cpu nodes: 128 cores, 257,400 MB; 1.96 GiB per core); the final run peaked at 6.31 GiB (13%); the first run's 35.6 GiB peak (at 16 threads) would be 76% of 24 cores, under the 80% stop line.

Static validation (all pass):
- `python3 negishi-run/build_kit.py --check`: all kit checks pass; 76 bash blocks (script 3, interactive 29, extra 23, submit 3, not-run 18), 9 steps, 65 placeholders; `generated/` matches a fresh build.
- Mutation test on a copy of the repository: 15 mutations (a "Short on time?" path not in the results manifest, in a block and in prose; a callout block not marked fallback; front matter of 5A and of 6; the `call.sh` block; the `06-filter.sh` text; the account in Episode 6; `--mem` in 5A; an extra block with `>` and one with `-o`; a cited URL missing from `reference.md`; a placeholder without a handler; the `evaluate.sh` submit block; an unmarked fence) caught 15 of 15.
- `bash -n` on every kit script and generated file; shellcheck 0.10.0 clean on `kitrun.sh`, `submit_all.sh`, `collect.sh` and the generated jobs, and on the generated sessions with `-s bash` and the P3 learner-style excludes.
- `py_compile` of `build_kit.py`, `py/summarize.py`, `py/sacct_summary.py`, `pipeline/py/metrics.py`, and `build_kit.py --check`, under Python 3.6.15 (`python:3.6-slim`).
- `submit_all.sh --run test-dry --dry-run` with a stub `sbatch` (rejects `--mem` and any account but `rcac`): 9 steps, 8 test-only submissions accepted, `afterok` chain as in `graph.txt`.
- `summarize.py` (Python 3.6) on a synthetic run built from the P3 final-run records (stats, hap.py summaries and ROC tables, `sacct`, region metrics), the P4 alignment records, the real bcftools 1.24 usage text and small invented kit-only tables: all 49 anchors PASS; every metric placeholder resolves; memory headroom, live load and kit-only sections fill. One parser bug found and fixed (`--prior` matched `--prior-freqs`).
- The new read-only and kit-only bcftools commands ran with `staphb/bcftools:1.24` on a synthetic 3-sample VCF (header grep, `view -r`, `query -r` lists, `-i 'N_ALT>1'`, the `POS=$(...)` split view, `stats -s - | grep PSC`, the filter pipeline, `FILTER~`, the percentile and threshold `awk` lines); the five `mpileup` option sets of `kit_site_counts` parse.
- `pr_figure.py` on a synthetic ROC table and summary (matplotlib 3.10.8, Python 3.13.5): SNV solid and indel dashed, PASS points as circle and square, legend below the axes; it prints the axis ranges for the caption.
- `sandpaper::validate_lesson()` (0.17.1) clean; `build_lesson(preview = FALSE)` builds; titles render as "5A. Calling variants with bcftools" and "6. Filtering and evaluating variant calls"; only lesson pages rebuilt (the stale `site/built/prompt-01-scaffold.md` is from P1).
- No em or en dashes in the changed files.

Part B commands: `negishi-run/README.md`, "Phase 5". Laptop: `python3 negishi-run/build_kit.py`, `--check`, then the `rsync`. Negishi: `00_preflight.sh`; `submit_all.sh --run kit5-2026-10-11 --dry-run`; `submit_all.sh --run kit5-2026-10-11`; when `squeue` is empty, `collect.sh --run kit5-2026-10-11`; on the laptop, `rsync` the tarball and extract it under `negishi-run/records/`.

### Phase 5 Part A review decisions, 2026-10-11 (uncommitted, same branch)

Decisions on the Part A report:

1. Correction 2 accepted as written (Q25 is a real bin; the in-between values are averages over FastQC's position groups). Correction 5 in Episode 2 and the setup page accepted.
2. MultiQC in Episode 6: `06-filter.sh` stays unchanged and learners keep the `bcftools stats`/`grep` approach. Added a kit-only `kit_multiqc_export 06-filter results/vcf` (MultiQC 1.23) and two figure slots in Episode 6 Step 1, `06-multiqc-bcftools-qual` (`bcftools_stats_vqc_Count_SNP.png`) and `06-multiqc-bcftools-depth` (`bcftools_stats_variant_depths.png`), labeled in the text as made by the kit from `trio.norm.stats.txt` (all records) and `trio.filtered.stats.txt` (PASS only). File names checked locally with `quay.io/biocontainers/multiqc:1.23--pyhdfd78af_0` on the P3 stats files. Documented in `docs/ADAPTATIONS.md`.
   - `[check]` The two plots are weak teaching figures on the P3 data: the SNV QUAL count plot is a few tall spikes (QUAL saturates at a few values), and the depth plot shows fractions on a 1-500 axis, so the body is a low bump and the cap at 500 dominates the right edge. Part C decides whether they earn their place or whether a kit-drawn histogram from `site_qual_dp_mq.tsv` (with the thresholds marked) would serve better.
3. Leakage callout: now leads with the primary benchmark (the learner's own v5.0q SNV F1 peak, `{{kit:06-sol-f1-peak-v5}}`) and adds that the same calls peak elsewhere against v4.2.1. Reference-run values by argmax of the P3 final ROC tables: v5.0q QUAL 117.7 (F1 0.9869), v4.2.1 QUAL 159.8 (F1 0.9931). `[check]` The memo's "150 (SNV F1 peak, 0.9931)" is a grid row (0.9930 at 150); the argmax is 159.8, so the episode says "near QUAL 160". The curve is flat there.
4. Multiallelic demo: `restage.sh --example` cuts `trio.example.raw.vcf.gz` from `trio.raw.bcf`, the concatenated calls before `norm` (P3 `example.tsv`: `multiallelic_raw 1`, 179 raw and 180 filtered records, the extra one from the split). The `N_ALT>1` demo therefore stays. `summarize.py` adds a stop check: Part C stops if the `N_ALT>1` query prints nothing or the split view prints fewer than two records (both paths tested on the synthetic run). The text after the query no longer assumes the genotype is `1/2`.
5. `evaluate.sh` memory, the gap explained from the records (P3 first run `varcall-p3-records-ref-2026-10-10-20261010-1908`, final run `...-final-2026-10-11-20261010-2016`):
   - (Task labels corrected under "Phase 5 Part B": array task 2 is HG002 against v4.2.1, not v5.0q.) The 35.1 and 35.6 GiB peaks were array task 2 in the first run's q0 and q20 arrays (16 cores, `--threads 16`). The 6.31 GiB final-run peak was task 1, HG002 against v5.0q; the final run's task 2 peaked at 2.34 GiB.
   - Inputs were the same: hap.py logged the same record counts per task in both runs, and the q0 calls are anchor-identical. The thread count was the same (16). What changed was the allocation (16 to 24 cores) and the node.
   - The first run's q0 task 4 also peaked at 23.1 GiB, while the same task in its q20 array peaked at 2.0 GiB. So MaxRSS of a hap.py task is not set by its inputs. `[check]` Unverified hypothesis: RTG vcfeval (Java) sizes its heap from the node's physical memory, not the job's allocation, so how far the heap grows before garbage collection depends on the node. P3 did not record nodes.
   - Cores unchanged (24). `collect.sh` now also writes `records/sacct_nodes.tsv` (JobID, NodeList; `sacct.tsv` keeps its P3 format), and the `SUMMARY.md` headroom table labels each task with its sample, truth set and node next to MaxRSS and wall time, for the decision on fewer cores or a single HG002 v5.0q task on the live path.

Checks after these changes: `build_kit.py --check` passes (76 bash blocks, 9 steps, 65 placeholders, 2 figure slots); `summarize.py` on the synthetic run: 49 anchors PASS, both figure slots resolve to the MultiQC 1.23 exports, the headroom table shows sample, truth and node; Python 3.6.15 parses `summarize.py` and `build_kit.py`; shellcheck 0.10.0 on `collect.sh` and `kitrun.sh` reports only SC1091 (sourced files not followed); `validate_lesson()` clean; no em dashes.

### Phase 5 Part B, 2026-10-11 (kit run `kit5-2026-10-11`, tarball `varcall-p5-kit-kit5-2026-10-11-20261011-1013.tar.gz`)

Results (`SUMMARY.md`): all 9 steps completed, no learner command failed; 48 of 49 anchors exact; the multiallelic stop check passed (1 site, split into 2 records); all 65 placeholders and both MultiQC figures resolved; no kit-only warning. bcftools 1.24 usage text: `-Q` default `[1]`, `-q` `[0]`, `-d` `[250]` (closes the `-Q` question).

- `[blocker]`, fixed: sentinel artifact chr20:29070822 failed (truth `1|1` instead of "not in any truth set"). Kit bug: `kitrun.sh` read the truth genotype from the truth VCF without the benchmark BED, and GIAB truth VCFs also list variants outside their benchmark regions; P3's `report.py` chose the site as outside every benchmark BED. Confirmed on Negishi: outside both HG002 BEDs. Fixed: the lookup reports `outside` for a position outside a benchmark's BED and `absent` for one inside it with no truth record. Anchor wording changed in `anchors.tsv` from "truth not in any truth set" to "truth outside every benchmark region" (value unchanged: the call is FILTER HighDP;LowMQ, HG002 1/1). Episode 6 may use the site as the UNK example (Part C).
- `[blocker]`, decided: `evaluate.sh` task 3 (HG003 v4.2.1) peaked at 39.09 GiB, 83% of 24 cores (47.1 GiB); task 4 (HG004) 37.31 GiB, 79%; both on node a130. Task 1 (HG002 v5.0q) 7.29 GiB, task 2 (HG002 v4.2.1) 18.37 GiB.
- `[check]`, corrected: P3 task labels. SLURM gives the array's base job ID to the last task (P5: base 44099796 is task 4, HG004; tasks 1-3 are 44101081-83), and the P3 logs had been matched to tasks by job ID. In `truth_sets.tsv` order (task 1 HG002 v5.0q, 2 HG002 v4.2.1, 3 HG003, 4 HG004), the P3 peaks were: first run task 2 (HG002 v4.2.1) 35.1 and 35.6 GiB, task 4 (HG004) 23.1 GiB in one array and 2.0 GiB in the other, task 1 (HG002 v5.0q) 10.2 and 6.8 GiB; final run task 1 6.31, task 2 2.34, task 3 6.05, task 4 1.75 GiB. Across P3 and P5 the same task peaked between 1.2 and 39.1 GiB (HG003), with identical inputs; HG002 v5.0q never exceeded 10.2 GiB. Corrected in the 2026-10-10 entries above, the reference-run memo (item 6) and the local `.claude/CLAUDE.md`.

Decisions (2026-10-11):

1. Sentinel: fix the kit lookup and reword the anchor (above).
2. `evaluate.sh`: `export RTG_MEM=8g` after the module loads, with a comment; the episode's explanation of the 24 cores now names the varying peaks and `RTG_MEM`. The tested MaxRSS comes from the rerun (below). `staged_manifest.tsv` row for `scripts/evaluate.sh` updated locally to the new md5 (`b99b4cda...`, 1734 bytes); `restage.sh --scripts` on Negishi rewrites the whole file, which comes back in Part C. Live path: learners submit task 1 only, `sbatch --array=1 evaluate.sh` (now in `interactive/06-evaluate-summary.sh` and Episode 6 Step 4), and copy the other three tasks' results from the results copy (a fallback block); self-paced learners submit the full array (the submit block stays). The kit runs the full array in `06-evaluate` and validates the learner's line with `sbatch --test-only` in `06-evalsum`; `build_kit.py` allows `sbatch` in an interactive block only as `sbatch --array=N SCRIPT` for a learner script. Live load of Episode 6: 24 cores per learner, 480 for 20 (was 96 and 1,920).
   - `[check]` The results copy (`varcall-workshop_results`, `staged_results_manifest.tsv`) still holds the old `scripts/evaluate.sh` (md5 `34a0ed8e...`). Its eval outputs do not depend on `RTG_MEM` if the rerun's `summary.csv` files are identical. Updating that copy needs a decision (regen or a single-file update).
   - The rerun starts at `06-filter`, not `06-evaluate`: the sentinels are kit-only records of `06-filter`, so the fix is only verified by rerunning it (about 2 min; same outputs).
3. Leakage callout: the main number is the learner's own v5.0q SNV peak (placeholder, now formatted with one decimal: QUAL 117.7, F1 0.9869 in this run); the contrast is v4.2.1 "about QUAL 156-160" (F1 0.993067 on 6 tied ROC rows from QUAL 155.6 to 159.8). `SUMMARY.md` now prints tied F1 rows as a QUAL range.
4. Tarball moved from the repository root to `negishi-run/records/`.

Checks: `build_kit.py --check` passes (78 bash blocks, 9 steps, 65 placeholders, 2 figure slots); the generated `06-evalsum` session holds `sbatch --test-only --array=1 evaluate.sh`; the BED test of the sentinel lookup gives the expected inside/outside at interval edges; `summarize.py` on the synthetic run: 49 anchors PASS with the new artifact wording, F1 ties as ranges, Episode 6 live peak 24/480; shellcheck 0.10.0 clean on `kitrun.sh` and `collect.sh` (SC1091 excluded); Python 3.6.15 parses the kit's Python.

### Phase 5 Part B rerun, 2026-10-11 (from `06-filter`; tarball `varcall-p5-kit-kit5-2026-10-11-20261011-1047.tar.gz`)

Answers to the four questions of the Part B decisions:

1. Results copy: its eval outputs came from the uncapped script and stay valid, because a memory cap does not change results. Update only `scripts/evaluate.sh` there and its row in `staged_results_manifest.tsv` (done locally: md5 `b99b4cda...`, 1734 bytes, note "single-file update 2026-10-11"); then run `check_staged.sh` on all three Depot copies.
2. Rerun from `06-filter`: accepted.
3. Staged manifest: bring the Negishi copy back and diff it; stop if rows other than `evaluate.sh` differ. All 43 data rows differed, but only in the note column: `restage.sh --scripts` writes one note on every row. Path, type, bytes, md5 and need were identical in all rows. Decision: take the Negishi copy (installed as `negishi-run/staged_manifest.tsv`).
   - Provenance that the notes no longer carry: the example region `resources/example/` (chr20:60,000-90,000) was cut by `restage.sh --example` from run `ref-2026-10-10`, call set q0, on 2026-10-10; data and resources come from the stage-build of 2026-10-10.
4. The tested MaxRSS: the "<X>" blank is dropped from the decision text; the rerun records the real number.

Rerun results (`SUMMARY.md`):

- All 49 anchors PASS; the artifact sentinel reads "truth outside every benchmark region". Multiallelic stop check PASS.
- `summary.csv`: all 8 files byte-identical (`cmp`) to those of the first tarball (`varcall-p5-kit-kit5-2026-10-11-20261011-1013`, `qc/eval/`).
- `06-evalsum` console: `sbatch: Job 44102636 to start at 2026-10-17T12:02:20 a using 24 processors on nodes a049 in partition cpu` (the `--test-only` validation of `sbatch --array=1 evaluate.sh`; nothing submitted).
- `evaluate.sh` MaxRSS at 24 cores (47.1 GiB), `RTG_MEM=8g`: task 1 HG002 v5.0q 4.37 GiB (9%, node a082), task 2 HG002 v4.2.1 2.25 GiB (5%, a102), task 3 HG003 v4.2.1 27.14 GiB (58%, a102), task 4 HG004 v4.2.1 1.16 GiB (2%, a109). Wall 1.5-2.5 min.
- `[check]` (P9 open item, decided 2026-10-12; not a Part C stop) The cap is not proven. Every `runinfo.json` records `RTG_MEM=8g` in hap.py's environment inside the container, but no hap.py log prints the Java command line, so the `-Xmx` that vcfeval used is not recorded. Task 3 peaked at 27.14 GiB, more than an 8 GiB Java heap plus ordinary overhead would explain: either the cap did not reach Java, or most of the memory is outside the Java heap (hap.py's own preprocessing and quantification, or what SLURM counts as RSS). Unresolved; needs a check on Negishi before the cap is described as working.

### Results copy swap, 2026-10-12

- `[should-fix]`, fixed: the completed-results copy was never swapped in after P3 Part D, although the Part D record said it was. It stayed in the dated build directory until 2026-10-12, when it was moved to `/depot/workshop/data/varcall-workshop_results`. The Part D record above is corrected. Until then the Episode 5A and 6 fallback blocks, which read the undated path, would have failed.
- `scripts/evaluate.sh` in the results copy is now the `RTG_MEM` version (md5 `b99b4cda...`, as in `staged_results_manifest.tsv`).
- `check_staged.sh`: 0 problems on all three copies (learner, ref, results), 2026-10-12.
- Dated-path references in the repository changed to the undated path: the header comment of `negishi-run/staged_results_manifest.tsv` and the Part D record in this log. `regen_results.sh` still builds into `<STAGED_RESULTS>.<date>` and prints the swap commands; that is its design (a new copy never replaces the current one without a manual step), and its README row describes it generically (`varcall-workshop_results.<date>`). No episode, learner page or kit script names a dated path.

### Phase 5 Part C, 2026-10-12 (kit run `kit5-2026-10-11`, tarball `varcall-p5-kit-kit5-2026-10-11-20261011-1047.tar.gz`, which holds the full run plus the rerun from `06-filter`)

Run check: all 9 steps COMPLETED (markers PASS), no `### KIT-ERR`, no learner command failed; all 49 anchors and the 5 sentinels match `anchors.tsv`; the multiallelic stop check passed (1 site, 2 split records); `sources_check.txt` OK for every episode and learner script. Since the run, only Episode 6 prose changed (2026-10-12): `index.tsv`, `placeholders.tsv`, `steps.tsv` and `graph.txt` of the run equal a fresh build, so every command block is the one the kit ran. `evaluate.sh` memory at 24 cores, rerun: 1.16-27.14 GiB (2-58%), under the 80% stop line; the first run's 83% (task 3) was decided under "Phase 5 Part B" (`RTG_MEM`, live path task 1 only).

Filled from the run (65 placeholders, 0 left): the 26 `-out-` spoilers verbatim; trimmed only trailing spaces (the `column -t` lines of `06-out-eval-*`). Not trimmed: the `MQ should be declared as Type=Float` lines (Episode 5A now points to its callout at the first one) and the `Concatenating ... seconds` lines (the text says the seconds vary). Value placeholders written into the prose, several rewritten around their values (below).

Tool defaults, confirmed against the recorded 1.24 usage text: `--ns` `UNMAP,SECONDARY,QCFAIL,DUP`, `-q 0`, `-Q 1`, `-d 250`, anomalous pairs skipped unless `-A`, `-x` disables overlap detection, `call -P 1.1e-3`, `--ploidy` `[2]`, `norm --multi-overlaps` `[0]`, `filter -m +`, `-s`, `-S`. Episode 5A now also lists the anomalous-pair default.

Text corrected from the run or the records (old, then new):
- `[should-fix]` 5A, chr20:88,108 table: the overlap row changes nothing (35) and the base-quality row drops 3 bases (32), so "a row that changes nothing means that filter removes nothing" was wrong for overlaps. htslib 1.24 `sam.h` (`bam_mplp_init_overlaps`, checked in `staphb/htslib:1.24`) sets the lower-quality base of an overlapping pair to quality 0; `-Q 1` then drops it. Our data hold no quality below 2, so the floor removes only zeroed bases. The solution now names the two causes from the kit counts: 4 duplicates (all `T`; samtools: 4 duplicates, 0 non-proper pairs, 0 MAPQ 0 at the site) and 3 overlapping pairs (2 `T`, 1 `C`); 25,14 / 39 becomes 19,13 / 32. The mpileup bullet list now says the same and cites `sam.h` (added to `learners/reference.md`).
- `[should-fix]` 5A, multiallelic site: chr20:88,865, a `CA` repeat with two insertion ALTs (+6 and +4 bases); HG002 `0/0`, HG003 `0/2` (26,0,4), HG004 `0/1` (15,17,0). The text described a `1/2` genotype; it now walks through HG003's `0/2` becoming `0/0` and `0/1`, the trimmed `G>GACACAC` / `G>GACAC` records, and keeps `1/2` as the general case.
- `[should-fix]` 6, Ts/Tv of HG002 raw calls outside the v4.2.1 regions: "1.29" (memo, 1.285 rounded) became 1.28, what `bcftools stats` prints (26,876 / 20,920), in the spoiler text and the challenge solution.
- `[should-fix]` 6, ROC solution: "indel precision rises less than it does for SNVs" is false against v5.0q (SNV 0.9843 to 0.9932, indel 0.8772 to 0.9023). Now stated as the share of wrong calls: SNV 1.6% to 0.7% (more than half), indel 12.3% to 9.8% (about a fifth). The v4.2.1 values quoted from the memo match the kit's ROC tables.
- `[nice]` 6, hap.py memory: "never above 10.2 GiB in six runs" became five (P3 first run q0 and q20, P3 final, P5 run, P5 rerun).
- `[nice]` 6, mask threshold table: "more than 0.2%" became "about 0.2% (2 x 0.5^10 = 0.195%)".
- `[nice]` 6, "Predict the filters" question 3: now answers yes, with the matching counts, and the kit's mask reasons for HG002 (GQ alone 7,639, DP alone 1,920, both 1,707 of 11,266 newly masked).
- 4 (correction 4): the MAPQ 0 gap is the 36,402 unmapped reads plus 34,519 of the 55,861 supplementary alignments, exactly 70,921 (`mapq0_counts.tsv`); "can account for the rest" removed.
- 3 (correction 2): the 10th percentile drops from position 125 in R1 and 85-95 in R2 (checked in the six FastQC zips: values 25.0 to the read end, in-between values 27.4, 29.8, 32.2, 34.6).
- Corrections 1, 3 and 5 confirmed against the run: binomial 5.4% / 10.8% (n = 39, recomputed); the "Why these reports look clean" callout; the module notice (the run shows the banner; the outputs leave it out).
- Runtimes: 5A calling "2 to 4 minutes (133 to 254 seconds), reference run" became "test runs, 2 to 4 minutes" (kit 2.2-3.7 min); 6 hap.py "1.5 to 2.5 minutes (89 to 145 seconds)" kept as test runs (kit 1.5-2.5 min). Values the learner reproduces are no longer labeled "reference run"; values only the memo has keep the label (centromere PASS 12,390 and Ts/Tv 1.36, the v4.2.1 decomposition table, v4.2.1 F1 peak).
- Added: hap.py UNK example, the artifact sentinel chr20:29,070,822 (HG002 `1/1`, `HighDP;LowMQ`, outside both HG002 benchmark BEDs), as allowed by the Part B decision.

Every other number in 5A, 6 and the corrected passages matches the run or the records (checked line by line, including the 50 reads at chr20:85,259 in the Episode 4 `tview` output).

Figures:
- `[should-fix]`, decided: the two MultiQC `bcftools stats` exports are dropped from Episode 6 (slots and the paragraph removed). The PNG exports have no legend for their two lines, the SNV QUAL count plot is a few saturation spikes (near QUAL 220, 474, 730), and the depth plot is a low bump with a spike at the 500 bin. The percentile table carries the distributions. A kit-drawn histogram with the thresholds marked would teach better, but the prompt limits new images to MultiQC exports and the PR figure; `[nice]` P7 decision. `kit_multiqc_export 06-filter` still runs (ADAPTATIONS updated).
- Precision-recall figure `episodes/fig/06/pr_hg002_v5.0q.png` from `negishi-run/pr_figure.py` on the kit's `qc/eval/` (matplotlib 3.10.8, Python 3.13.5), placed after the filtered summary in Step 5, with caption (precision axis starts at 0.868) and alt text written from the plot. The indel PASS point (0.779 / 0.930) lies above the indel QUAL curve: the mask and site filters beat any QUAL threshold at that recall. Credited in `learners/reference.md`.

Schedule (plan section 4): the calling array's longest task was 3.7 min after a 1.8 min wait, well inside the 15 minutes after the 11:40 submission; `evaluate.sh` task 1 ran 2.5 min after a 1.3 min wait, inside the 10-minute "while hap.py runs" slot. Front matter unchanged (5A 30/30, 6 40/40). Live load: Episode 4 peak 48 cores per learner (960 for 20), 5A 20 (400), 6 24 (480).

Remaining: `[check]` P9: `RTG_MEM=8g` unproven as a cap (unchanged). `[nice]` P7: live-path notes for Episodes 1-4.

Checks: `build_kit.py` and `--check` pass (78 bash blocks, 9 steps, 0 placeholders, 0 figure slots; command columns of `index.tsv` identical to the run's); `validate_lesson()` clean; `build_lesson()` builds, titles render, only the stale P1 `prompt-01-scaffold.md` outside the lesson pages; no em or en dashes in changed files.

## Revision opportunities

- `[should-fix]` P9: `check_staged.sh --results` should fail when the undated `STAGED_RESULTS` path is missing (and not pass on a dated directory given as DIR without saying so), and `regen_results.sh` should end by saying plainly that the swap is still pending; `make_staged_manifest.py` should write the undated path in the results manifest header (2026-10-12: the results copy sat in the dated directory from Part D until 2026-10-12).
- `[nice]` P9: `restage.sh --scripts` (and `--example`) should rewrite only the manifest rows they change. Today `make_staged_manifest.py` writes one `--note` on every row, so a script update erases the provenance of the data, resources and example rows (2026-10-11: all 43 rows of `staged_manifest.tsv` lost their notes).

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

P5 episode kit run `kit5-2026-10-11`, 2026-10-11 (rerun from `06-filter` with `RTG_MEM=8g`); wait from eligibility.

| Step | Cores | Wall | MaxRSS (GiB) | Wait |
|---|---|---|---|---|
| `02-setup` (login node) | - | 43 s | - | - |
| `03-qc` session | 4 | 4.0 min | 2.23 | 0.1 min |
| `align.sh`, per sample | 16 | 11.2-12.6 min | 13.56 | 0.1 min |
| `04-alignqc` session | 4 | 5.0 min | 0.45 | 1.8 min |
| `call.sh`, per chunk | 2 | 2.2-3.7 min | 0.19 | 1.8 min |
| `05-merge.sh` session | 4 | 0.5 min | <0.01 | 1.3 min |
| `06-filter.sh` session (rerun) | 4 | 1.4 min | 0.55 | 1.3 min |
| `evaluate.sh`, per task, first run (no `RTG_MEM`) | 24 | 1.5-2.5 min | 7.29-39.09 | - |
| `evaluate.sh`, per task, rerun (`RTG_MEM=8g`) | 24 | 1.5-2.5 min | 1.16-27.14 | 1.3 min |
| `06-evalsum` (login-node commands as a job) | 1 | 0.1 min | <0.01 | 0.2 min |
