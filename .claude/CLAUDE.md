# CLAUDE.md

This file guides Claude Code (claude.ai/code) when working in this repository.

## What this is

A Carpentries Workbench (sandpaper) lesson: "Variant Calling: Hands-on Training". It is course material, not software. Learners run every step in the shell on Purdue RCAC Negishi (SLURM, `module load biocontainers` then the tool module with an explicit version for samtools and bcftools). There is no R in the live core; R appears only in self-paced Episode 9 (Open OnDemand RStudio, TBD(P8)). Canonical repo: `rcac-bioinformatics/variant-calling`, branch `main`, site built from `gh-pages`. No git remote is configured yet (2026-10-09); create it before the first push.

Status: phase P1 (scaffold). The development plan is `maintenance/plan/development-plan.md`; decisions D1-D8 and their status are in `maintenance/log/updates.md`. Episodes are stubs until P4-P6.

## Dataset and validation anchors

- Data (D1, approved 2026-10-09): Genome in a Bottle Ashkenazi trio, HG002 (child), HG003 (father), HG004 (mother). Illumina NovaSeq PCR-free, about 35x, reads selected from chr20 alignments, converted to paired FASTQ for learners. Source: the DeepTrio WGS case-study BAMs (plan section 5.1). Exact files, read length, read counts and sizes: TBD(P2).
- Reference: GRCh38 no-alt analysis set (`GCA_000001405.15_GRCh38_no_alt_analysis_set`). Kept read-only on Depot and used in place (symlinked into the learner's `ref/`), not copied per learner. Index files and sizes: TBD(P2).
- Truth sets: NIST GIAB benchmarks. HG003 and HG004 v4.2.1; HG002 v5.0q is recommended by NIST and v4.2.1 is deprecated for HG002. Which files and which GRCh38 BED are staged: TBD(P2).
- Because reads were selected from chr20 alignments, mapping rate and coverage outside chr20 are not realistic. Episodes must say so.
- Anchors (alignment metrics per sample, SNV and indel counts, Ts/Tv, HG002 precision and recall, Mendelian violation rate, de novo funnel counts, 3-5 sentinel positions): TBD(P3). Values come from the reference run, never set in advance. When recorded, a missing anchor or a changed sign means an upstream break, not "different but fine".
- Tool versions: TBD(P2). D5: load explicit module versions for samtools and bcftools; target bcftools 1.24 plus htslib 1.24 as biocontainers (to be deployed), else bcftools 1.17. Other tools load the module default unless P2 shows a reason to pin.

## Build and preview

Run from the repo root in R (sandpaper pinned in `.github/workflows/sandpaper-version.txt`, currently 0.17.1; theme `aseetharam/varnish`):

```r
sandpaper::build_lesson()    # render into site/ (gitignored except site/README.md)
sandpaper::serve()           # live preview, rebuilds on save
sandpaper::validate_lesson() # fenced-div structure, links, image alt text
```

There are no unit tests. "Done" for a content edit means `validate_lesson()` is clean and the page renders. Every output block, number, and figure of this workshop's data in an episode comes from the Negishi run kit (`negishi-run/`, built in P4 on the RNA-seq pattern), never from memory or an off-cluster test. CI (`.github/workflows/sandpaper-main.yaml`) builds and deploys on push to `main`; the other workflows are stock Carpentries files, do not hand-edit them.

## Structure that is not obvious from the tree

- `config.yaml` controls episode order and navigation. A new episode file is invisible until added to the `episodes:` list. Self-paced episodes (5B, 9, 10) stay out of `config.yaml` until they pass the run kit (P8). Custom theme: `carpentry: 'rcac'`, `varnish: aseetharam/varnish`.
- File names are numbered (`01-...`, `05a-...`), and titles carry the episode number because `disable_sidebar_numbering: true`. A title that starts with a bare digit escapes the period inside single quotes, for example `title: '1\. Introduction to genetic variation and variant calling'`. Unescaped, pandoc reads it as an ordered list and `build_lesson()` fails with "StartTag: invalid element name". A letter-suffixed title such as `"5A. Calling variants with bcftools"` needs no escape.
- Episodes are `.Rmd` but analysis code is NOT executed at build time. Code sits in plain ```` ```bash ```` display fences; never convert them to `{r}` chunks (the build machine has no data or tools). The only knitr chunks allowed are `echo=FALSE` calls to `knitr::include_graphics("fig/...")`. To run or test episode code, parse the fences out of the Rmd (the run kit does this).
- Paths: learners work in `$SCRATCH/varcall-workshop` (`data/`, `ref/`, `scripts/`, `results/`). `$SCRATCH` is the only scratch variable in episodes and on the setup page; setup verifies it points to the learner's scratch. Never use `$RCAC_SCRATCH` or `/scratch/negishi/$USER`.
- Staged data (D8): `/depot/workshop/data/varcall-workshop`; completed results: `/depot/workshop/data/varcall-workshop_results`. Both do not exist yet; contents, manifest, permissions and size: TBD(P3).
- SLURM header, identical in every episode (RNA-seq pattern):

  ```
  #SBATCH --nodes=1
  #SBATCH --ntasks=1
  #SBATCH --cpus-per-task=<n>
  #SBATCH --account=TBD(P2)
  #SBATCH --qos=standby
  #SBATCH --partition=cpu
  #SBATCH --time=<hh:mm:ss>
  #SBATCH --job-name=<name>
  #SBATCH --output=cluster-%x.%j.out
  #SBATCH --error=cluster-%x.%j.err
  ```

  Never set `--mem`: Negishi allocates about 1.9 GB per core, so memory-heavy steps request more cores. Core counts and wall times per step: TBD(P2).
- Module versions: load samtools and bcftools with explicit versions (`module load bcftools/<version>`), never the default. Reason (plan section 5.3): bcftools behavior changed across releases. 1.13 revamped BAQ (calls change); 1.17 replaced `+mendelian` with `+mendelian2`; 1.18 added `--write-index` (1.17 lacks it); 1.20 added the `--indels-cns` model used by `-X illumina`; 1.24 replaced `+trio-dnm2` with `+trio-dnm3`. Keep the core trio logic in plain filter expressions so the lesson does not depend on fast-moving plugins. If 1.17 is used, avoid `--write-index`. The bcftools module does not expose `bgzip` or `tabix`; those come from htslib. Exact versions: TBD(P2).
- Episode markup uses Workbench fenced divs (`questions`, `objectives`, `callout`, `challenge` with nested `solution`, `discussion`, `spoiler`, `keypoints`, `instructor`). Every episode needs front matter with `source: Rmd`, `title`, `teaching`, `exercises`. `teaching` plus `exercises` equals the full self-paced time (plan section 3.3); live timings belong in the instructor notes and on the setup page.
- Headings are sentence case. No em dashes in prose.

## Delivery format

- Full curriculum (plan section 3.3): core episodes 1, 2, 3, 4, 5A, 6, 7, 8 plus self-paced 5B, 9, 10. Front matter totals 695 min (about 11.6 h); the core episodes alone total 485 min.
- One day, in person (D6): 6 h of instruction excluding breaks and lunch, 9:00-4:30. Live core plus wrap-up totals 360 min (plan section 4); a 5.5 h cut list is in the plan.
- Live: 1, 2 and 3 condensed, 4, 5A, 6, 7 (can be compressed), 8. Self-paced: 5B (GATK, D2), 9 (population variation, D4), 10. Every live job has a completed-results fallback.
- All episodes, live and self-paced, must keep working and be tested before a delivery.
- `learners/setup.md` carries the dated schedule and the instructor list; update both for every delivery. Delivery date and co-instructor: TBD(P10).

## Instructor materials (local only, gitignored)

- `instructors/instructor-notes.md` is public (scRNA-seq structure, D7): timing table, delivery modes, common issues, pre-workshop checklist, challenge discussion points.
- `instructor-notes/`: per-episode narration scripts plus a timing table in its README.md (RNA-seq pattern). Not created yet; TBD(P10).
- `coaching/`: TTS-friendly prep text (plain `.txt`, flowing prose, no markup). Coaching is a conceptual briefing, not narration. Not created yet; TBD(P10).
- `maintenance/prompts/`: the phase prompts (prompt-NN-<name>.md). Gitignored.
- If episode content or `teaching`/`exercises` times change, update the public timing table, the matching narration file, and the coaching file.

## Maintenance log and what the site publishes

sandpaper renders every `.md`/`.Rmd` file at the repo root and one folder below it (except files named README or CONTRIBUTING), and CI publishes whatever is tracked. Keep non-lesson Markdown out of that reach: this file lives in `.claude/` (hidden folders are skipped), the plan, log and prompts two levels down in `maintenance/plan/`, `maintenance/log/` and `maintenance/prompts/`, and the kit docs in `negishi-run/docs/`. Never add a Markdown file to `maintenance/` or `negishi-run/` directly.

`maintenance/log/updates.md` is the running log of decisions, findings and revision opportunities, tagged `[blocker]`, `[should-fix]`, `[nice]`, or `[check]`. Log every content issue there before or alongside fixing it; do not silently fix and move on.
