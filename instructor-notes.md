---
title: Instructor Notes
---

## Workshop timing

The full lesson is longer than one day. Front matter `teaching` plus `exercises` gives the full self-paced time; the live column is the time each episode gets in the one-day delivery.

| Episode | Title | Mode | Live | Teaching | Exercises | Full |
|:-------:|:------|:-----|:----:|:--------:|:---------:|:----:|
| 1 | Introduction to genetic variation and variant calling | Core live | 30 min | 35 min | 15 min | 50 min |
| 2 | Data, reference genomes, and project setup | Core live, condensed | 20 min | 20 min | 20 min | 40 min |
| 3 | Read quality control | Core live, condensed | 15 min | 15 min | 15 min | 30 min |
| 4 | Read alignment and alignment QC | Core live | 70 min | 45 min | 45 min | 90 min |
| 5A | Calling variants with bcftools | Core live | 45 min | 30 min | 30 min | 60 min |
| 5B | Calling variants with GATK HaplotypeCaller | Self-paced; can replace 5A live | n/a | 45 min | 45 min | 90 min |
| 6 | Filtering and evaluating variant calls | Core live | 60 min | 40 min | 40 min | 80 min |
| 7 | Annotating variants | Core live, can be compressed | 40 min | 30 min | 30 min | 60 min |
| 8 | Application: candidate variants in a family trio | Core live | 50 min | 35 min | 40 min | 75 min |
| 9 | Application: variation across samples and populations | Self-paced; can replace 8 live | n/a | 35 min | 40 min | 75 min |
| 10 | Adapting the workflow: your organism, your data, at scale | Self-paced | n/a | 30 min | 15 min | 45 min |
| | Wrap-up and survey | Live | 30 min | | | |
| | **Total** | | **360 min** | **360 min** | **335 min** | **695 min** |

Episodes 5B, 9 and 10 are not yet in the lesson; they are added to the navigation once they pass the run kit.

## Delivery modes

### One-day schedule

Six hours of instruction, excluding breaks and lunch. The day runs 9:00 to 4:30 with a 60-minute lunch and two 15-minute breaks. Login checks and the data copy happen from 8:30 to 9:00 and are not counted.

<!-- TBD(P2, P3): job runtimes in the last column are placeholders until the pilot and the reference run measure them. -->

| Time | Block | Explain | Hands-on | Exercise and discussion | Running in the background |
|:-----|:------|:-------:|:--------:|:-----------------------:|:--------------------------|
| 8:30-9:00 | Arrival, login, data check | | | | rsync if not done earlier |
| 9:00-9:30 | Episode 1 | 20 | 0 | 10 | |
| 9:30-10:05 | Episodes 2 and 3 | 12 | 15 | 8 | FastQC |
| 10:05-10:20 | Break | | | | |
| 10:20-11:30 | Episode 4 | 25 | 30 | 15 | Alignment array |
| 11:30-12:15 | Episode 5A | 20 | 15 | 10 | Calling array |
| 12:15-1:15 | Lunch | | | | Buffer for late jobs only |
| 1:15-2:15 | Episode 6 | 20 | 20 | 20 | hap.py |
| 2:15-2:30 | Break | | | | |
| 2:30-3:10 | Episode 7 | 15 | 15 | 10 | SnpEff |
| 3:10-4:00 | Episode 8 | 15 | 20 | 15 | |
| 4:00-4:30 | Wrap-up, limitations, next steps, survey | 15 | 0 | 15 | |
| | **Total (360 min)** | **142** | **115** | **103** | |

Design rules:

- Each live job should finish within about 15 minutes on standby when nodes are free. A longer step is reduced (by region or coverage) or replaced by a completed-results fallback.
- Teach the matching concepts while jobs run: SAM and BAM anatomy during alignment, VCF anatomy during calling.
- Lunch is a buffer, not part of the plan.

### 5.5-hour version (ends at 4:00)

Episode 1 to 25 minutes; Episodes 2 and 3 to 30; Episode 7 to 30 (demo only); wrap-up to 20, with the survey on the way out.

### What to teach live and what to leave for self-paced study

- **Live:** genotype and VCF semantics, read groups, filtering trade-offs, evaluation, and interpretation. These topics carry the misconceptions that lead to wrong conclusions. Cluster mechanics (accounts, queues, arrays) also fail most often on first use, and instructors can fix them in the room.
- **Self-paced:** alternative callers (5B), population analysis (9), adapting to a learner's own organism (10), downloads from public archives, and the full-length versions of Episodes 1-3.

### Selecting a subset

- Minimum live path: 1, 2 and 3 condensed, 4, 5A, 6, 7 (can be compressed to a demo), 8.
- Substitutions: 5B for 5A for a GATK-focused audience; 9 for 8 for a population-genetics audience.
- Do not drop Episode 4 before 5 (read groups), Episode 6 before 8 (filtered calls and precision), or Episode 2 (paths and metadata).
- Every live job has a completed-results fallback, so a learner who falls behind can rejoin at the next episode.

## Common issues

<!-- TBD(P7): filled from the pilot, the reference run, and the run kit. -->

## Pre-workshop checklist

<!-- TBD(P10): account and queue, staged data and completed results, module versions, graphical session for IGV, build test, survey link. -->

## Challenge discussion points

<!-- TBD(P7): one subsection per episode, written after the episodes and their solutions. -->
