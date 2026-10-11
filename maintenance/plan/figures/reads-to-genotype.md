# Figure specification: "From reads to a genotype" (Episode 1)

Status: specification, written in P4 (2026-10-10). P7 builds the animation from it. Not published (this folder is outside sandpaper's reach).

## Purpose

One short animation that carries the core idea of Episode 1: a genotype call is inferred from aligned reads, each weighted by its base quality and mapping quality, and summarized as genotype likelihoods, a called genotype and two quality values. It replaces the board sketch the Episode 1 instructor note asks for, and sits in the section "From reads to a genotype", after the schematic pileup and the two quality bullets, before the "call the genotype" challenge.

## Format and style

Match the RNA-seq lesson animations in `../rnaseq-analysis/episodes/fig/` (for example `From-reads-to-a-count-matrix.html`):

- One self-contained HTML file, no external requests: `episodes/fig/01/From-reads-to-a-genotype.html`.
- Drawing on a `<canvas id="cv" role="img" aria-label="...">` (label below).
- Controls: a **Play** button (`<button id="play" type="button">Play</button>`, toggling to Pause and Replay) and a timeline slider (`<input id="scrub" type="range" aria-label="Timeline position">`).
- Does not start on its own; `?autoplay=1` in the URL starts it (the "open it in a new tab" link uses it).
- Honors `prefers-reduced-motion`: show the final frame of each scene with its caption, advanced by Play.
- System font stack as in the RNA-seq files; colors with WCAG 2.1 AA contrast against the background; REF and ALT bases told apart by letter and position, never by color alone.
- Length about 80 seconds.
- Every number on screen is either labeled "illustrative" or taken from a kit run (see "Values" below).

Embedding in `episodes/01-intro-to-variant-calling.Rmd`, replacing the instructor note:

```html
<iframe src="fig/01/From-reads-to-a-genotype.html" title="Animation, 80 seconds: reads pile up at one position, base and mapping qualities weight the evidence, allele counts become genotype likelihoods, and the caller reports a heterozygous genotype with QUAL and GQ" loading="lazy" style="width:100%;aspect-ratio:16/11;border:0;"></iframe>

*Animation (80 seconds): from reads to a genotype at one heterozygous position.* Press **Play** to start, or <a href="fig/01/From-reads-to-a-genotype.html?autoplay=1" target="_blank" rel="noopener">open it in a new tab</a>.
```

## Storyboard

| Scene | Time (s) | What is shown | Caption (on screen) |
|---|---|---|---|
| 1. The question | 0-8 | A stretch of reference sequence with a coordinate ruler; one base, `T` at chr20:88,108, highlighted. | "Is this person's DNA different here, and what are their two alleles?" |
| 2. Reads align | 8-20 | About 12 read bars slide in and stack over the position (a pileup). Matching bases are dots; at the highlighted column about half the reads show `C`. Reads on the forward and reverse strand are drawn with different end markers (arrowheads), not only different colors. | "Each read is placed by the aligner. At this position some reads show C, some show T." |
| 3. Base quality | 20-32 | Each base in the highlighted column gets an opacity from its base quality, using the four binned values of our data (Q2, Q11, Q25, Q37), with a small legend. One `C` has Q2 and fades almost out. | "Base quality: how sure the sequencer is of each base. A Q2 base counts for little; a Q37 base counts for a lot." |
| 4. Mapping quality and duplicates | 32-42 | Two reads are labeled `MAPQ 0`: a ghost copy of the same sequence appears elsewhere on a second reference line (a repeat), and the two reads move aside, hatched. One read is labeled `duplicate` (same start and end as another read) and moves aside. | "Mapping quality: reads that fit equally well elsewhere, and duplicates of one fragment, add no independent evidence." |
| 5. Allele counts | 42-52 | The remaining reads collapse into two counters: `T` and `C`, each a bar with a count. | "What remains: the evidence for each allele, weighted by quality." |
| 6. Genotype likelihoods | 52-66 | Three hypotheses side by side, `0/0`, `0/1`, `1/1`, each with a bar for how well it explains the counts; `0/1` is tallest. Below, the same three as a `PL` triplet in which the best genotype is 0 and the others are larger (Phred scale). | "For each possible genotype: how likely are these reads if it were true? Stored as PL; the best genotype gets 0." |
| 7. The call | 66-76 | A VCF-like line builds up field by field: `chr20  88108  T  C  QUAL ...  GT 0/1  GQ ...`. QUAL is underlined with "is any ALT allele here?", GQ with "is this genotype right?". | "The call: the most likely genotype, with QUAL (a variant is present) and GQ (this genotype is right)." |
| 8. Close | 76-80 | The whole pileup fades behind the VCF line. | "A call is a statistical statement. Filtering (Episode 6) decides which calls to trust." |

## Values

- Positions, alleles and genotype: chr20:88,108, `T` > `C`, HG002 heterozygous `0/1`. These are frozen sentinel values (`negishi-run/anchors.tsv`, "sentinel het_snv"), so the scene shows a real position.
- Read counts, base qualities, PL, QUAL and GQ on screen: either illustrative (label the scene "illustrative values"), or, preferably, taken from kit runs: the column counts from the P4 kit's `04-sol-tview-het` value (Episode 4 `samtools tview` snapshot), and QUAL, PL and GQ from the HG002 record at chr20:88,108 in the P5 kit run's `trio.norm.vcf.gz`. Do not use the frozen reference-run QUAL (724.0) without the matching PL and GQ from the same record.
- The binned quality values Q2, Q11, Q25, Q37 come from the feasibility memo.

## Alt text and title

- `<title>`: "From reads to a genotype"
- Canvas `aria-label`: "Animated explainer: sequencing reads pile up at one position of chromosome 20; each base is weighted by its base quality, reads with mapping quality 0 and duplicates are set aside, the remaining evidence for the two alleles becomes genotype likelihoods for 0/0, 0/1 and 1/1, and the caller reports a heterozygous 0/1 genotype with QUAL and GQ."
- iframe `title`: as in the embedding snippet above.

## Acceptance (P7)

- Plays to the end in about 80 seconds; Play, Pause, Replay and the slider work with mouse and keyboard; `?autoplay=1` starts it.
- With reduced motion, every scene is reachable and readable.
- Contrast checked against WCAG 2.1 AA; no information carried by color alone.
- Every number is labeled illustrative or traced to a kit record in the log.
