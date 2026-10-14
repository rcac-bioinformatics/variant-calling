# Reference run (Phase 3 Part C)

Run `ref-2026-10-10` on Negishi, 2026-10-10, records `varcall-p3-records-ref-2026-10-10-20261010-1908`. Every value below is "reference run, not frozen". Anchors are frozen in Part D, after gate G3. Gene names are not written in this file.

## G3 decision (2026-10-10)

- Call set q0 (mpileup defaults); `call.sh` has no read filters.
- Filters as proposed: QUAL < 30, INFO/DP > 2 x median site depth, INFO/MQ < 30, genotypes with FMT/DP < 10 or FMT/GQ < 20 set to missing. Episode 6 teaches the genotype mask as the precision-recall trade-off (section 4).
- Episode 8 keeps the zero-candidate funnel. The 41 candidates after the region step are framed as mostly real cell-line variants, not germline de novo mutations (about 1-2 expected on chr20), citing the NIST HG002 mosaic benchmark paper (bioRxiv 2024.12.02.625685; PMC11642750). The child allele fractions are recorded in section 6 after the finalize run.
- The recessive evidence step stays, with the reason it removes nothing (section 6).
- `evaluate.sh` at 24 cores. Implementation note: hap.py now runs with `--threads 16`, not `$SLURM_CPUS_PER_TASK`. Peak memory was 23.9 GiB at 8 threads (pilot) and 35.6 GiB at 16 threads, so 24 threads could exceed the memory 24 cores provide. Also fixed: the two HG002 array tasks wrote the same per-sample input VCF (`results/eval/HG002.<calls>.vcf.gz`) at the same time; each task now writes `<sample>.<truth>.<calls>.calls.vcf.gz`.
- Example region chr20:60,000-90,000, staged as `resources/example/` by `restage.sh --example`. It holds the raw (before norm) and filtered records and is checked for het, hom-alt, indel, multiallelic and filtered records; the region grows to the nearest multiallelic site if it has none.
- Episode 5A gets a callout that the `MQ should be declared as Type=Float` warning is harmless.
- Anchors are frozen from the finalize run `ref-final-<date>`, made with the final learner scripts.

## Final run and frozen anchors (2026-10-10)

Run `ref-final-2026-10-11` (records `varcall-p3-records-ref-final-2026-10-11-20261010-2016`), q0 only, with the final learner scripts and the staged `resources/example/` (chr20:60000-90000: 179 raw and 180 filtered records, 1 multiallelic before norm, 174 with a het genotype, 7 with a hom-alt, 6 indels, 116 not PASS; no widening needed).

- 12 step markers PASS, no `KIT-ERR`; determinism PASS again (same md5 as the first run).
- All 57 q0 anchor values and all 5 sentinels are identical to run `ref-2026-10-10`. Calling, normalization, filtering, hap.py/vcfeval, annotation and trio steps are therefore reproducible, not only alignment. The anchors are frozen in `negishi-run/anchors.tsv` with tolerance "exact".
- `evaluate.sh` at 24 cores with `--threads 16`: 89-145 s per task, MaxRSS 1.75-6.31 GiB (first run, 16 cores and 16 threads: 1.2-35.6 GiB). The 35.6 GiB peak did not recur at the same thread count, so it was not simply a thread effect; 24 cores leaves headroom either way.
- Wall times close to the first run: alignment 668-738 s at 16 cores, 463 s at 32; calling chunks 133-220 s; annotate 86 s.

## 1. Run checks

| Check | Result |
|---|---|
| Preflight (2026-10-10 17:30) | FAIL 0, WARN 0 |
| Staged copies | `restage.sh --install` and `check_staged.sh`: 0 problems in `varcall-workshop` (31 files) and `varcall-workshop_ref` (55 files); full md5 |
| Learner setup (`02-setup.sh`, login node) | 44 s, `md5sum -c` OK, 5.4 GB copy |
| Steps | 20 markers, all PASS; no `KIT-ERR` line in any console log |
| Failed jobs | First submission: `fork-q20` and `merge-q0` failed on two kit bugs (log, 2026-10-10); resubmitted after the fixes, both PASS. No learner command failed |
| Determinism | PASS: HG002 at 16 and 32 cores, same md5 of `samtools view -h` without `@PG`, 18,980,761 records |
| Pilot agreement | HG002 SNV recall 0.9948 and precision 0.9862 (pilot 0.9946, 0.9861); indel 0.9432, 0.9465 (pilot 0.9425, 0.9457); calls 185,914 (pilot 185,628 with bcftools 1.17, so the difference reflects the version change) |

## 2. Versions and parameters actually used

- Modules (each the default and loaded by explicit version): bwa/0.7.17, samtools/1.22.1, bcftools/1.24, htslib/1.24, mosdepth/0.3.3, hap.py/0.3.9 (vcfeval engine, staged SDF template), snpeff/5.3.0a (`GRCh38.mane.1.2.ensembl`), snpsift/5.2, fastqc/0.12.1, multiqc/1.23. Apptainer 1.3.0; every wrapper uses `singularity exec`.
- SLURM: account `rcac`, QoS `standby`, partition `cpu`, no memory requests.
- Alignment: `bwa mem -K 100000000 -t 16`, then `samtools fixmate -m`, `sort`, `markdup --write-index`.
- Calling: 8 chunks of chr20 (cuts at 8.06, 16.11, 24.17, 31.16, 40.28, 48.33 and 56.39 Mb; the cut at 31.16 Mb falls inside a 2.5 kb N-run). `bcftools mpileup -a AD,DP,SP` with `READ_FILTERS` empty (q0) or `-q 20 -Q 20` (q20), then `bcftools call -mv -a FORMAT/GQ`. Concatenation, then `bcftools norm -m -any`.
- Filters (`06-filter.sh`): `LowQual` QUAL < 30; `HighDP` INFO/DP > 2 x the median site depth (q0: 226, median 113; q20: 224, median 112); `LowMQ` INFO/MQ < 30; genotypes with FMT/DP < 10 or FMT/GQ < 20 set to `./.`.
- Evaluation: `bcftools view -s SAMPLE -c 1`, then hap.py `-l chr20 --roc QUAL --engine vcfeval`, on the unfiltered (`norm`) and filtered calls, for HG002 v5.0q, HG002 v4.2.1, HG003 v4.2.1 and HG004 v4.2.1.
- Centromere: UCSC hg38 `centromeres.txt.gz`, chr20 26,436,232-30,038,348 (3.6 Mb, 5.6% of chr20). It lies inside chunk 4.

## 3. q0 versus q20

| Measure | q0 (defaults) | q20 (`-q 20 -Q 20`) |
|---|---|---|
| Records after norm (SNV, indel) | 185,914 (155,291; 30,623) | 188,740 (158,362; 30,378) |
| Multiallelic sites split by norm | 3,956 | 3,927 |
| Ts/Tv, all trio SNVs, raw / PASS | 1.81 / 2.01 | 1.78 / 1.96 |
| PASS records | 158,151 | 163,803 |
| Sites flagged LowMQ | 6,407 | 2,502 |
| HG002 genotypes missing, raw / after mask | 298 / 6,105 | 1,913 / 9,466 |
| HG002 SNVs, Ts/Tv inside v4.2.1 benchmark, raw / PASS | 2.281 / 2.300 | 2.291 / 2.304 |
| HG002 SNVs, Ts/Tv outside, raw / PASS | 1.285 / 1.440 | 1.266 / 1.409 |
| Trio SNV sites in the centromere, raw / PASS | 31,005 / 14,549 | 33,673 / 18,397 |
| Ts/Tv in the centromere, raw / PASS | 1.187 / 1.311 | 1.130 / 1.199 |
| HG002 v4.2.1 SNV recall / precision, raw | 0.9948 / 0.9862 | 0.9947 / 0.9876 |
| HG002 v4.2.1 SNV recall / precision, PASS | 0.9907 / 0.9914 | 0.9918 / 0.9922 |
| HG002 v4.2.1 indel recall / precision, raw | 0.9432 / 0.9465 | 0.9347 / 0.9397 |
| HG002 v4.2.1 indel recall / precision, PASS | 0.9063 / 0.9727 | 0.8969 / 0.9688 |
| HG002 v5.0q SNV F1 / indel F1, PASS | 0.9847 / 0.8482 | 0.9847 / 0.8335 |
| Mendelian errors / consistent sites | 449 / 144,536 | 534 / 145,784 |
| De novo funnel, steps 1-3 | 312, 81, 41 | 394, 125, 49 |
| Calling wall time per chunk (2 cores) | 141-254 s | 122-156 s |

Per region, for HG002's raw SNVs (q0): 119,856 in all; 72,060 inside the v4.2.1 benchmark (Ts/Tv 2.281) and 47,796 outside (1.285). The centromere holds 26,894 of them (22% of the SNVs in 5.6% of the sequence, Ts/Tv 1.216), and the filters remove 54% of those (12,390 PASS, Ts/Tv 1.364). Chunk 4 (24.2-31.2 Mb, holding the centromere) has 48,592 trio SNV sites and Ts/Tv 1.27; the other seven chunks have 13,025-17,737 sites each and Ts/Tv 2.05-2.41. The full tables are in `records/<cs>/metrics_norm/tstv_regions.tsv` and `metrics_pass/tstv_regions.tsv`.

**Recommendation: q0 (mpileup defaults).**

1. **Accuracy.** Inside the benchmark the two are within 0.001 for SNVs. Indels are worse with q20 in recall and precision, raw and filtered, against every truth set.
2. **Outside the benchmark.** q20 does not remove the outside-benchmark and centromere calls; it adds some (2,668 more centromere SNV sites). The read filter drops low-MQ reads before calling, so the site MQ looks better. As a result the LowMQ site filter catches 2,502 sites instead of 6,407, and more repeat calls PASS (whole-chr20 PASS Ts/Tv 1.96 against 2.01).
3. **Episode 6 teaching.** With q0, the MQ distribution shows the low-MQ tail (1,548 sites with MQ < 10). The site filters then visibly move Ts/Tv outside the benchmark (1.29 to 1.44) and in the centromere (1.19 to 1.31). With q20 that signal is mostly hidden before learners see it.
4. **Simplicity.** q0 is the command with no extra options, and it keeps the q20 comparison available as an exercise ("does a read filter replace a site filter?").

This does not reverse the planned story. The pilot left open whether `-q 20` at mpileup removes the outside-benchmark calls; it does not, and the site filters do the work.

## 4. Filter rule and thresholds

Distributions (q0, raw, all 185,914 sites; `records/q0/metrics_norm/quantiles.tsv`):

| Measure | p01 | p05 | p10 | p50 | p90 | p95 | p99 |
|---|---|---|---|---|---|---|---|
| QUAL | 7.0 | 38.9 | 102.1 | 469.4 | 730.3 | 739.0 | 741.9 |
| Site DP | 19 | 69 | 86 | 113 | 220 | 358 | 668 |
| Site MQ | 11 | 35 | 42 | 60 | 60 | 60 | 60 |
| HG002 DP | 5 | 19 | 24 | 36 | 68 | 111 | 209 |
| HG002 GQ | 4 | 19 | 41 | 127 | 127 | 127 | 127 |

- **QUAL < 30** catches the low tail (p05 is 38.9): 7,622 sites (4.1%).
- **HighDP, DP > 2 x median (226).** The p90 (220) lies just under the cutoff and the p95 (358) far above it: a long tail typical of collapsed repeats. 17,821 sites (9.6%), the largest single filter. How much of this tail lies in the centromere was not measured.
- **MQ < 30:** 6,407 sites (3.4%).
- **Genotype mask, DP < 10 or GQ < 20:** about 6% of genotypes per sample (HG002 11,266).
- **Labels:** 158,151 PASS; HighDP alone 15,725; LowQual alone 4,818; LowMQ alone 3,298; combinations 3,922.
- **Allele balance** (fraction of ALT reads in heterozygous genotypes, HG002): 39 below 0.05 raw, 0 after filtering.

Measured effect, HG002 v4.2.1, split into the genotype mask (hap.py `ALL` row on the filtered VCF) and the site filters (`PASS` row):

| Type | Raw R / P | After genotype mask | After site filters | F1 raw / final |
|---|---|---|---|---|
| SNV | 0.9948 / 0.9862 | 0.9931 / 0.9891 | 0.9907 / 0.9914 | 0.9905 / 0.9911 |
| Indel | 0.9432 / 0.9465 | 0.9080 / 0.9712 | 0.9063 / 0.9727 | 0.9449 / 0.9383 |

The filters improve SNV precision at a small recall cost. For indels, the genotype mask causes almost all of the recall loss (0.035), so indel F1 falls. Indel genotypes with GQ < 20 are frequent, and masking them turns true positives into false negatives. This is a clear precision-recall trade-off for the episode. QUAL thresholds behave the same way (section 8).

## 5. Benchmark table (q0)

Unfiltered (`norm`, `ALL`) and filtered (`PASS`):

| Sample | Truth | Type | Truth total | Raw R / P | PASS R / P | PASS F1 |
|---|---|---|---|---|---|---|
| HG002 | v5.0q | SNV | 75,854 | 0.9883 / 0.9795 | 0.9806 / 0.9887 | 0.9847 |
| HG002 | v5.0q | Indel | 18,173 | 0.8398 / 0.8720 | 0.7792 / 0.9305 | 0.8482 |
| HG002 | v4.2.1 | SNV | 71,333 | 0.9948 / 0.9862 | 0.9907 / 0.9914 | 0.9911 |
| HG002 | v4.2.1 | Indel | 11,256 | 0.9432 / 0.9465 | 0.9063 / 0.9727 | 0.9383 |
| HG003 | v4.2.1 | SNV | 70,166 | 0.9956 / 0.9852 | 0.9918 / 0.9906 | 0.9912 |
| HG003 | v4.2.1 | Indel | 10,628 | 0.9411 / 0.9474 | 0.9094 / 0.9725 | 0.9399 |
| HG004 | v4.2.1 | SNV | 71,659 | 0.9955 / 0.9871 | 0.9915 / 0.9927 | 0.9921 |
| HG004 | v4.2.1 | Indel | 11,000 | 0.9432 / 0.9504 | 0.9146 / 0.9757 | 0.9442 |

**HG002 v5.0q against v4.2.1.** v5.0q covers 58.1 Mb against 56.9 Mb. Its truth set has 6% more SNVs (75,854 against 71,333) and 61% more indels (18,173 against 11,256), and its Ts/Tv is 2.24 against 2.31. The same calls score lower against it: PASS SNV recall 0.981 against 0.991, indel recall 0.779 against 0.906. Most of the difference comes from indels in the harder repeat regions that v5.0q adds. This works as an Episode 6 point: the benchmark defines the score, and a newer, harder benchmark lowers it without the calls changing. False positives against v5.0q are mostly genotype errors for indels (`FP.gt` 768 of 1,060 PASS).

## 6. Trio (q0)

- **Sample order** in the VCF: HG002, HG003, HG004 (child, father, mother), matching `trio.ped`.
- **Mendelian consistency** (`+mendelian2 -P`, PASS sites): 449 sites with an error and 144,536 consistent, a rate of 0.31%. 13,177 sites have a genotype missing in at least one sample (the genotype mask); 27,763 are not PASS.
- **Funnel:**

  | Step | De novo | Recessive |
  |---|---|---|
  | 1 genotype | 312 | 5,282 |
  | 2 evidence | 81 | 5,282 |
  | 3 trio benchmark regions | 41 | 4,632 |
  | 4 HIGH or MODERATE impact | 0 | 8 |
  | 5 rare (global and asj below 1%) | 0 | 0 |

  The recessive evidence step removes nothing: the genotype mask already set every genotype with DP < 10 or GQ < 20 to missing, and `GT="AA"` and `GT="het"` do not match missing genotypes.
- **Truth status** of the 41 de novo candidates after step 3:

  | HG002 v5.0q | HG002 v4.2.1 | HG003 | HG004 | Count |
  |---|---|---|---|---|
  | het | het | hom-ref | hom-ref | 33 |
  | hom-ref | hom-ref | hom-ref | hom-ref | 2 |
  | other allele in every truth set | | | | 2 |
  | other combinations | | | | 4 |

  Here hom-ref means the position is inside that sample's benchmark and absent from its VCF.

**Open question (stop item).** NIST's data supports 33 of the 41 candidates as true de novo variants in HG002. 30 are SNVs (22 of them transitions) and 3 are indels; 11 lie within a 50 kb window near 11.1-11.2 Mb. The plan expects about 1-2 true germline de novo SNVs on chr20. NIST's HG002 subclonal benchmark lists 85 subclonal SNVs (AF > 5%) across 2.45 Gb of autosomes, which does not account for 33 on chr20. The v4.2.1 README states that putative HG002 de novo variants are kept in the benchmark regions. These may therefore be cell-line variants present in the reference-material DNA, or a clustered event. Either way, Episode 8's framing ("most de novo candidates are errors") does not hold after step 3 for this dataset. The child allele fractions at these sites are the next check (section 10).

**Child allele fractions** (finalize run, `records/q0/trio/denovo_3_regions_af.tsv`). Every one of the 41 candidates has zero ALT reads in both parents (parental depth 3-49).

| Group | Candidates | Mean child AF | Child AF below 0.3 | Range |
|---|---|---|---|---|
| Truth-supported (het in both HG002 truth sets, parents hom-ref) | 33 | 0.44 (median 0.455) | 3 | 0.21-0.63 |
| Other | 8 | 0.30 | 4 | 0.13-0.50 |

The truth-supported candidates sit at heterozygous allele fractions, so they are present in nearly all cells of the HG002 DNA. That fits clonal variants: true germline de novo mutations, or variants fixed early in the cell line. It does not fit low-fraction subclonal variants, which is what the NIST HG002 mosaic benchmark describes (85 subclonal SNVs at AF above 5%, PMC11642750). Short-read data from the cell line cannot separate germline from early cell-line origin. The other 8 include the clearest artifacts: a pair 5 bp apart at 31.9 Mb with AF 0.13-0.14, and two indels at 13.6 and 47.9 Mb with fewer than 10 reads in the AD field of every sample.

## 7. Annotation (q0)

- SnpEff effects by impact, whole trio file: HIGH 10, MODERATE 348, LOW 542, MODIFIER 197,597 (`snpEff_summary.csv`; these count effects, not variants).
- HG002 PASS variants: 115,059. With at least one HIGH prediction: 3. HIGH or MODERATE, worst consequence: 240 rows (237 MODERATE).
- Rare protein-altering (worst consequence HIGH or MODERATE): 20 below 1% (or absent) in gnomAD overall, 12 below 1% in the Ashkenazi (asj) group. The asj frequency removes 8 variants that look rare globally, which is the Episode 7 teaching point.
- Tabulation: `bcftools +split-vep` (worst consequence) and `SnpSift extractFields` (first ANN entry) both work, with 240 rows each. Recommend `+split-vep` as the episode tool: one module and the worst consequence. SnpSift is the alternative.
- q20 gives 116,926 PASS HG002 variants, 243 protein-altering, and the same rare counts (20 and 12).
- ACMG check: the 27 distinct genes among HG002's rare protein-altering, HIGH-impact and recessive-impact variants, in both call sets, were checked against ACMG SF v3.3 (84 genes, Genetics in Medicine, August 2025). None is on the list. The gene list is kept out of tracked files.

## 8. Proposed anchors and sentinels

The draft (`records/anchors.draft.tsv`, 98 rows for both call sets) covers, per sample, the read counts, duplicates, MQ0 reads and mean depth; the trio record, SNV and indel counts and Ts/Tv, raw and filtered; HG002 Ts/Tv inside and outside the benchmark; recall and precision per sample and truth set; Mendelian counts; and the funnel. For the chosen call set, the proposed anchors are:

| Anchor (q0) | Value | Tolerance |
|---|---|---|
| HG002 / HG003 / HG004 raw total sequences | 18,924,900 / 18,960,080 / 18,694,236 | exact |
| HG002 / HG003 / HG004 reads duplicated | 1,975,897 / 2,082,305 / 2,053,967 | exact |
| HG002 / HG003 / HG004 mean depth chr20 | 39.08 / 38.90 / 38.42 | exact (2 decimals) |
| Trio records after norm (SNV, indel) | 185,914 (155,291; 30,623) | exact |
| Trio PASS records (SNV, indel) | 158,151 (129,329; 28,822) | exact |
| Ts/Tv raw / PASS | 1.81 / 2.01 | exact (2 decimals) |
| HG002 PASS Ts/Tv inside / outside v4.2.1 | 2.300 / 1.440 | exact (3 decimals) |
| HG002 v5.0q PASS SNV R / P | 0.9806 / 0.9887 | exact (4 decimals) |
| HG002 v5.0q PASS indel R / P | 0.7792 / 0.9305 | exact (4 decimals) |
| HG002 v4.2.1 PASS SNV R / P | 0.9907 / 0.9914 | exact (4 decimals) |
| Mendelian errors / consistent | 449 / 144,536 | exact |
| De novo funnel | 312, 81, 41, 0, 0 | exact |
| Recessive funnel | 5,282, 5,282, 4,632, 8, 0 | exact |

Basis for "exact": alignment is identical across thread counts (determinism check). Calling, normalization, filtering, hap.py/vcfeval and the bcftools counts are deterministic for fixed inputs and pinned modules. This has been measured only for alignment. A second run (the P4 run kit) has to confirm it for the rest before a mismatch is treated as a break. Runtimes are never anchors.

Sentinels (`records/sentinels.tsv`; identical genotypes in q0 and q20):

| Role | Position | REF>ALT | Truth GT | q0 QUAL, FILTER, GT |
|---|---|---|---|---|
| Heterozygous SNV | chr20:88,108 | T>C | 0/1 | 724.0, PASS, 0/1 |
| Homozygous ALT SNV | chr20:85,259 | G>A | 1/1 | 739.0, PASS, 1/1 |
| Indel | chr20:86,859 | T>TTGGTATCTAG | 1/1 | 729.3, PASS, 1/1 |
| Trio-inconsistent | chr20:338,577 | A>ATG | 0/1 | 340.4, PASS, 0/1 |
| Artifact (centromere) | chr20:29,070,822 | T>G | not in any truth set | 742.0, HighDP;LowMQ, 1/1 |

The artifact is a useful teaching record: the highest QUAL in the file, yet filtered by depth and MQ, and outside every benchmark.

## 9. Proposed teaching artifacts (Episodes 5A-8)

1. **Example VCF.** The region chr20:60,000-90,000 of the q0 filtered VCF contains the three sentinels (het SNV, hom-alt SNV, 10 bp insertion) and, from the merge console, a LowQual SNV at 61,264 (QUAL 8.7). Part D checks that the window also holds a site split by `norm` (two records at one position) and widens it to the nearest such site if not. The raw (pre-norm) record of that site goes next to it for the normalization explanation.
2. **Ts/Tv table (Episode 6),** HG002, q0:

   | Region | Raw SNVs | Raw Ts/Tv | PASS SNVs | PASS Ts/Tv |
   |---|---|---|---|---|
   | Inside v4.2.1 benchmark | 72,060 | 2.28 | 71,373 | 2.30 |
   | Outside | 47,796 | 1.29 | 25,517 | 1.44 |
   | Centromere | 26,894 | 1.22 | 12,390 | 1.36 |
   | All chr20 | 119,856 | 1.80 | 96,890 | 2.02 |

   Truth set inside the benchmark: 2.31.
3. **QUAL thresholds for predict-then-test** (HG002, v4.2.1, q0, unfiltered, vcfeval ROC):

   | QUAL at least | SNV R / P / F1 | Indel R / P / F1 |
   |---|---|---|
   | 0 | 0.9948 / 0.9862 / 0.9905 | 0.9432 / 0.9465 / 0.9449 |
   | 30 | 0.9944 / 0.9889 / 0.9916 | 0.9425 / 0.9478 / 0.9451 |
   | 100 | 0.9937 / 0.9919 / 0.9928 | 0.9372 / 0.9489 / 0.9430 |
   | 150 (SNV F1 peak, 0.9931) | 0.9926 / 0.9935 / 0.9930 | 0.9297 / 0.9504 / 0.9399 |
   | 225 | 0.9906 / 0.9949 / 0.9927 | 0.9074 / 0.9511 / 0.9288 |

   Suggested challenge: "Raise QUAL from 30 to 225. Predict what happens to SNV and indel precision and recall." SNV precision rises and recall falls a little. Indel recall falls about 3.5 points while precision barely moves, because 520 of the 598 indel false positives are genotype errors that QUAL does not separate.

## 10. Decisions put to G3 (decided 2026-10-10; see the top of this file)

1. **Call set: q0** (section 3). The q20 comparison could become an optional challenge.
2. **Filter rule: keep** QUAL < 30, DP > 2 x median, MQ < 30 and the genotype mask DP < 10 or GQ < 20. Teach the indel recall cost of the mask as the trade-off. Alternative: mask on DP only. That needs a rerun of filter, evaluation and trio (about 15 min) before Part D.
3. **De novo framing (stop item).** Before deciding, run the following on Negishi (login node, seconds) and paste the output:

   ```bash
   module load biocontainers bcftools/1.24
   W=$SCRATCH/varcall-kit/runs/ref-2026-10-10/q0/scratch/varcall-workshop
   bcftools query -f '%POS\t%REF\t%ALT\t%QUAL\t%FILTER[\t%GT:%DP:%AD:%GQ]\n' $W/results/trio/denovo_3_regions.vcf.gz
   ```

   Allele fractions near 0.5 in the child would fit germline or early cell-line variants. Fractions well below 0.5 would fit subclonal cell-line variants. Recommended framing either way: keep the funnel. State that after the region step, most survivors are supported by NIST's own data, and that the benchmark's handling of HG002 de novo variants (README v4.2.1) explains why. Never present them as germline mutations without orthogonal evidence.
4. **Episode 8 ends with zero candidates** in both models. Recommend keeping it and framing it as base rates, as the feasibility memo suggested. Use the 8 recessive impact variants, none of them rare, as the example of why frequency filters matter.
5. **Recessive evidence step** removes nothing after the genotype mask. Recommend keeping it with a sentence that explains why (a good check of understanding), rather than removing it.
6. **hap.py memory.** Array task 2 (HG002 v5.0q; corrected 2026-10-11: task 2 is HG002 against v4.2.1, because SLURM gives the array's base job ID to the last task and the logs were matched by job ID; see the log, "Phase 5 Part B") peaked at 35.1-35.6 GiB MaxRSS on 16 cores. That is above what 16 cores provide on Negishi (about 31 GiB), and it completed on this node, so it is not safe for learners. Recommend `--cpus-per-task=24` in `evaluate.sh` (about 45 GB). The alternative, fewer hap.py threads, has not been measured.
7. **Example region** chr20:60,000-90,000, subject to the Part D check (section 9).
8. **The bcftools warning** `MQ should be declared as Type=Float` appears on every bcftools read of these VCFs, because the VCF header declares INFO/MQ with an integer type. Recommend a callout in Episode 5A saying it is harmless, rather than reheadering.

## 11. Runtimes (standby, wall time excluding queue wait)

| Step | Cores | Wall | MaxRSS (GiB) |
|---|---|---|---|
| `02-setup.sh` (login node) | - | 44 s | - |
| `03-qc.sh` session | 4 | 196 s | 2.14 |
| `align.sh`, per sample | 16 | 651-750 s | 13.4-13.5 |
| `align.sh`, HG002 | 32 | 402 s | 13.5 |
| `04-alignment-qc.sh` session | 4 | 203 s | 0.27 |
| `call.sh`, per chunk (q0 / q20) | 2 | 141-254 s / 122-156 s | 0.18 |
| `05-merge.sh` session | 4 | 13 s | <0.01 |
| `06-filter.sh` session | 4 | 17 s | <0.01 |
| `evaluate.sh`, per task (2 hap.py runs) | 16 | 91-160 s | 1.2-35.6 |
| `06-evaluate-summary.sh` | 1 | 6-9 s | <0.01 |
| `annotate.sh` | 4 | 89-98 s | 0.05-1.75 |
| `07-annotation-tables.sh` session | 4 | 15-19 s | <0.01 |
| `08-trio.sh` session | 4 | 29 s | <0.01 |

Critical path without queue wait, from alignment to anchors: about 21 min.

## 12. Not verified

- Determinism of calling, filtering and evaluation (only alignment was checked). The P4 run kit gives the second run.
- IGV through Open OnDemand (P6); the OOD checklist is still blank.
- Child allele fractions at the 33 truth-supported de novo sites (decision 3).
- hap.py memory on other node types (decision 6).
- Whether the proposed example region contains a split multiallelic site.
