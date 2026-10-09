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

## Revision opportunities

## Runtime record

## Done
