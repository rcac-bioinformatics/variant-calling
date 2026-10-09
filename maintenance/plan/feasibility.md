# Phase 2 feasibility memo

Date: 2026-10-09. Phase P2, gate G2. Branch `dev/p02-feasibility`.

Every number below is a **pilot** number from one feasibility run on Negishi. None of them is a lesson anchor: anchors come from the P3 reference run. Each number cites its record file. Paths are relative to the tarball root.

- **Records:** `varcall-p2-records-20261009-1615` (cumulative: the first run plus the rerun). The first tarball, `varcall-p2-records-20261009-1517`, is superseded. Its hap.py and trio outputs were invalid (kit bugs, see `maintenance/log/updates.md`, Phase 2 Part C).
- **Kit:** `negishi-run/` and `data-prep/` as on this branch. The pilot account was `rcac`, partition `cpu`, QoS `standby`.
- **Not run:** the second call set with `mpileup -q 20 -Q 20` (`CALL_SET=q20`, runbook step R5). The OOD/IGV checklist came back blank.

## Environment

Source: `preflight.tsv` and `preflight/`, collected 2026-10-09 on login06 and compute node a012 (0 FAIL, 0 WARN).

| Module | Version reported | Negishi default |
|---|---|---|
| bwa/0.7.17 | 0.7.17-r1188 | same |
| samtools/1.22.1 | 1.22.1 | same |
| bcftools/1.17 | 1.17 (image `staphb_bcftools:1.17.sif`) | same |
| htslib/1.17 | bgzip and tabix 1.17 | same |
| mosdepth/0.3.3 | 0.3.3 | same |
| hap.py/0.3.9 | prints `Hap.py v0.3.8-17-gf15de4a` | same |
| snpeff/5.3.0a | SnpEff 5.3a (2025-09-02) | same |
| snpsift/5.2 | 5.2 | same |
| fastqc/0.12.1, multiqc/1.23, igv/2.19.1 | load (IGV launch not checked) | same |

Other installed or missing versions:
- bcftools 1.13 is installed. bcftools 1.24 and htslib 1.24 are not installed.
- Apptainer is 1.3.0 on login06. Python on the login node is 3.6.8.

**bcftools plugins.** `mendelian2`, `fill-tags`, `split-vep` and `trio-dnm2` are listed. `bgzip` and `tabix` come only from the htslib module; with bcftools alone they are absent.

**bcftools 1.17 quirks**, confirmed on Negishi and in the stock `quay.io/biocontainers/bcftools:1.17--haef29d1_0`:
- `+mendelian2 -P <ped>` fails with "invalid option -- 'P'" although `-h` lists it. `-p child,father,mother` works.
- `bcftools annotate -a` cannot read a pipe ("not compressed with bgzip").
- `--write-index` does not exist in 1.17.

**Module wrapper drops embedded double quotes (blocker for the lesson).**
- The bcftools module defines `bcftools () { /usr/bin/singularity run /apps/biocontainers/images/staphb_bcftools:1.17.sif bcftools "$@"; }` (`pilot/trio/bcftools_wrapper.txt`).
- Through it, every filter expression with a quoted string fails. bcftools' own error shows the quotes are gone: `Could not parse the expression: GT[0]=0/1 && GT[1]=0/0 && GT[2]=0/0` (`pilot/trio/gt_syntax_test.tsv`). The same expressions work in the stock 1.17 container.
- The function passes `"$@"` intact, so the quotes are lost in `singularity run`, that is, in the image's runscript. `singularity exec` does not re-parse arguments.
- Affected lesson content: `GT="het"`, `INFO/gnomad_AF="."`, and `FILTER="PASS"` in Episodes 6 to 8.
- Other modules built from the same template may be affected too. The `samtools` wrapper was not inspected.
- SnpSift's `(ANN[*].IMPACT = 'HIGH')` returned the expected count (4, `metrics.tsv`), probably because SnpSift tolerates the unquoted word.

**hap.py.**
- Both engines work, xcmp and vcfeval. vcfeval warns that it builds an SDF template on every run (`pilot/eval/*.vcfeval.log_tail.txt`).
- hap.py warns that no default reference exists (`HGREF`); `-r` covers that.

**SnpEff.**
- Repository: `https://snpeff.odsp.astrazeneca.com/databases`. The login and compute nodes both reach it (HTTP 403 on the bare host, downloads work).
- GRCh38 databases that 5.3a lists (`annot/snpeff_databases_GRCh38.txt`): `GRCh38.86`, `GRCh38.99`, `GRCh38.mane.0.95.{ensembl,refseq}`, `GRCh38.mane.1.0.{ensembl,refseq}`, `GRCh38.mane.1.2.{ensembl,refseq}`, `GRCh38.p13`, `GRCh38.p14`.
- `GRCh38.mane.1.5.*` and `GRCh38.105` are not listed.
- Downloaded: `GRCh38.mane.1.2.ensembl`, 0.40 GB in 12 s, and `GRCh38.p14`, 0.67 GB in 19 s (`metrics.tsv`).
- Heap: `snpEff -Xmx<N>m` and `_JAVA_OPTIONS` both reach the JVM (`preflight/snpeff_heap_*.txt`).
- On every run the module prints a note about `copy_snpeff_config`. It is harmless with `-dataDir`.

**`module --force purge`.** Not needed for correctness. samtools starts in 1048 ms without it and 1043 ms with it on the login node, and in 1039 and 923 ms on a compute node (`preflight/purge_compare.txt`, `preflight/compute_node.txt`). XALT's `LD_PRELOAD` is set on login and compute nodes and did not interfere.

**Network.** Compute nodes reach `storage.googleapis.com`, `ftp.ncbi.nlm.nih.gov`, `ftp-trace.ncbi.nlm.nih.gov` and the SnpEff host (`preflight.tsv`).

**SLURM.**
- Account `rcac` has QoS `normal` and `standby`. Standby's wall-time limit is 4 h.
- Partition `cpu`: 446 nodes, 128 cores and about 257 GB per node.
- `sbatch --test-only` accepted all 14 pilot job headers.

## Data and resources

Source: `provenance.tsv`, `fetch.tsv`, `terms/`, `listings/`. All downloads happened on 2026-10-09.

| ID | File | Bytes | md5 | Checked against |
|---|---|---|---|---|
| bam_HG002 | HG002.novaseq.pcr-free.35x.dedup.grch38_no_alt.chr20.bam | 1,093,938,924 | 8f1a541a348803e304275359ac52da57 | GCS JSON API |
| bam_HG003 | HG003...chr20.bam | 1,112,015,824 | b5855488be918c6b376fb67d2b3973ee | GCS JSON API |
| bam_HG004 | HG004...chr20.bam | 1,080,497,082 | 815c052592d45544c7ef2c5b17ff04d1 | GCS JSON API |
| ref_fasta | GCA_000001405.15_GRCh38_no_alt_analysis_set.fna.gz | 872,949,833 | a08035b6a6e31780e96a34008ff21bd6 | NCBI md5checksums.txt |
| ref_fai | ...no_alt_analysis_set.fna.fai | 7,804 | 5fddbc109c82980f9436aa5c21a57c61 | NCBI md5checksums.txt |
| ref_bwa_index | ...no_alt_analysis_set.fna.bwa_index.tar.gz | 3,445,310,260 | a4f359513f544d8713a74537da7c3322 | NCBI md5checksums.txt |
| giab421_HG002_vcf | HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz | 156,252,944 | dc750b3807d4af1f7ffec852e9c2f771 | none published |
| giab421_HG002_noinc_bed | HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed | 11,494,021 | 97265e922a97c69a0391cf3f92a89b8b | none published |
| giab421_HG003_vcf | HG003_GRCh38_1_22_v4.2.1_benchmark.vcf.gz | 147,212,428 | ea98d8b9de762e050e34666462bf3452 | none published |
| giab421_HG003_noinc_bed | HG003_..._noinconsistent.bed | 13,219,856 | 26f7a0a353c653e4e2979654586110b1 | none published |
| giab421_HG004_vcf | HG004_GRCh38_1_22_v4.2.1_benchmark.vcf.gz | 148,948,118 | 6c3f7c0736de259d400826ac84922d44 | none published |
| giab421_HG004_noinc_bed | HG004_..._noinconsistent.bed | 13,081,043 | 38fcb13f53634c898c8e9aadcd0fe292 | none published |
| giab_HG002_latest_vcf | HG002_GRCh38_v5.0q_smvar.vcf.gz | 42,067,644 | c71acc71069bf7cd7f51eb8fb0c1a1ab | NIST checksum.md5 |
| giab_HG002_latest_bed | HG002_GRCh38_v5.0q_smvar.benchmark.bed | 685,544 | 3366858af85875cbb3c579412ffa4c56 | NIST checksum.md5 |
| gnomad_chr20_vcf | gnomad.genomes.v4.1.sites.chr20.vcf.bgz | 11,838,569,571 | 6c6f326c67b288ec99932905da72c1e6 | GCS JSON API |

Indexes (`.bai`, `.tbi`) are in `provenance.tsv`. The v4.2.1 GRCh38 directories publish only the `_noinconsistent` BED; there is no plain `_benchmark.bed` (`listings/giab421_*_dir.txt`).

Terms. No source restricts keeping a copy on Depot for teaching:
- **NIST GIAB:** copying, redistribution and derived works are allowed with acknowledgment of NIST (v5.0q README, Data Usage section, `terms/giab_HG002_latest/`).
- **gnomAD:** CC0. Attribution is requested, and users agree not to attempt re-identification (gnomad-browser `about/policies/terms.md`, read 2026-10-09). The kept AF fields carry no restricted annotations; SpliceAI is CC BY-NC and is not kept.
- **NCBI reference:** NCBI policies page.
- **DeepVariant case-study BAMs:** public GCS bucket; the reads are GIAB data.
- **SnpEff:** MIT. Its databases derive from Ensembl and MANE.

**Facts later episodes must state.** Source: `source_bam/<sample>/`, `metrics.tsv` and `pilot/align/c16/`.

- **Read length:** 151 bp, paired.
- **Insert size:** mean 410.2, 417.9 and 399.5 bp (HG002, HG003, HG004).
- **Quality binning:** 4 distinct base-quality characters in the first 200k reads, `#`, `,`, `:` and `F` (Q2, Q11, Q25, Q37).
- **Duplicates:** the "dedup" BAMs are duplicate-*marked* (Picard MarkDuplicates 4.1.2.0 in `@PG`), not deduplicated. Duplicate-flagged reads: HG002 1,993,115, HG003 2,100,151, HG004 2,071,975. After realignment and `samtools markdup`, the HG002 duplicate fraction is 0.1041.
- **QC-fail and secondary reads:** 0 in every sample. Supplementary: about 200k per sample.
- **Mates outside chr20:** 332,047, 328,989 and 327,588 reads (HG002, HG003, HG004). `samtools fastq` drops them as singletons.
- **FASTQ read pairs:** HG002 9,462,450, HG003 9,480,040, HG004 9,347,118. The plan's 7.5M estimate was low.
- **FASTQ size:** 0.79 to 0.83 GB per file, 4.85 GB for all six.
- **Mean chr20 depth of the source BAMs (mosdepth):** 39.88x, 39.68x, 39.22x. That is about 40x, not 35x.
- **Alignment (HG002, bwa mem):** 18,924,900 reads; 99.81% mapped; 99.13% properly paired; 983,439 reads at MAPQ 0 (5.2%); mean depth 39.08x.
- **BAM header:** chr20 is 64,444,167 bp in both the BAM header and the reference `.fai`; all `@SQ` names and lengths match. The read group is `ID:HG002.pcr-free SM:HG002 LB:HG002.pcr-free PL:ILLUMINA`.
- **bwa index:** NCBI publishes a bwa index for the analysis set. It loads in bwa 0.7.17, and 1,998 of 2,000 test reads mapped (`reference/bwa_index_choice.txt`), so no index build is needed. The unpacked index is 5.42 GB.

## Runtime and memory

Source: `sacct_summary.tsv` and `metrics.tsv`. Wait is the time from submission to start on standby.

| Step | Cores | Wall | MaxRSS (GiB) | CPU eff. | Wait |
|---|---|---|---|---|---|
| prep-faidx (gunzip, faidx, dict) | 2 | 60 s | 0.04 | 0.42 | 63 s |
| prep-bwaindex (extract NCBI index, test) | 4 | 54 s | 0.01 | 0.29 | 303 s |
| prep-fastq, per sample (stats, BAM to FASTQ) | 8 | 189-219 s | 0.30-0.40 | 0.24-0.25 | 206 s |
| prep-truth | 2 | 50 s | 0.04 | 0.26 | 140 s |
| prep-annot (gnomAD download plus AF subset, SnpEff downloads) | 8 | 1045 s (subset 890 s) | 0.28 | 0.17 | 198 s |
| p-align HG002, full chr20 | 16 | 781 s job; 718 s pipeline | 14.77 | 0.82 | 156 s |
| p-align HG002, full chr20 | 32 | 452 s job; 386 s pipeline | 18.10 | 0.75 | 401 s |
| p-call, per chunk (8 chunks of about 8 Mb, joint trio) | 2 | 129-246 s; slowest chunk 4 (centromere) 235 s calling | 0.17-0.18 | 0.44-0.49 | 156 s |
| p-call-merge (concat, norm, stats) | 4 | 17 s | 0.00 | 0.17 | 637 s |
| p-eval, 8 hap.py runs in sequence | 8 | 829 s; one run 74-154 s | 23.88 | 0.36 | 40 s |
| p-snpeff, MANE 1.2 | 4 | 24 s (heap 5.7 GB) | not captured | 0.27 | 870 s |
| p-snpeff, MANE 1.2 plus p14 | 8 | 23 s plus 64 s (heap 11.4 GB) | 5.43 | 0.20 | 870 s |
| p-trio (mendelian2, counts, gnomAD annotate) | 4 | 193 s | 0.11 | 0.24 | 40 s |

Notes:
- **Alignment cost:** about 1.4 GB per core at 16 cores. CPU efficiency is 0.82 at 16 cores and 0.75 at 32; doubling the cores cut wall time by 46%.
- **Calling:** the chunks are single-thread pipelines (`mpileup | call`), so 2 cores means about 1 core used per process. The centromere chunk produced 53,561 records against 14,624-21,287 elsewhere, and is the slowest.
- **hap.py memory:** MaxRSS of 23.88 GiB on 8 cores is more than the 15.2 GB that 8 cores nominally bring, and the job was not killed. The first run's p-eval, with near-empty confident regions, peaked at 3.54 GiB. Which engine drives the peak is not recorded per run (still unverified).
- **Queue waits:** 40 to 1107 s across both runs (`sacct_summary.tsv` in both tarballs). The longest was p-trio in the first run.
- **bcftools 1.13 vs 1.17** on chunk 1 (chr20:1-8,055,521): 21,386 vs 21,287 records, the same 17,520 SNVs, and 3,866 vs 3,767 indels, at 143 vs 140 s (`pilot/call/bcftools_version_compare.tsv`). 1.24 was not tested because it is not installed.

## Budget check

The live-job rule is about 15 minutes per live job (plan 5.4). The schedule (plan 4) submits alignment by about 10:35, during Episode 4's 70 minutes, and calling by about 11:40, during Episode 5A's 45 minutes.

| Live job | Measured (pilot) | Within 15 min? |
|---|---|---|
| Alignment array, 3 samples in parallel, full chr20 | 7.5 min at 32 cores, 13.0 min at 16 cores, plus standby wait (156-401 s in the pilot) | 32 cores: yes, with margin. 16 cores: only without queue wait |
| Calling array, 8 chunks in parallel | slowest chunk 4.1 min (job), plus merge 17 s | yes |
| hap.py, HG002 only, one engine | 1.2-2.6 min per run | yes |
| SnpEff, MANE | 24 s | yes |
| Trio steps | 193 s for the whole p-trio job | yes |

Concurrency:
- 20 learners at 3 x 32 cores is 1,920 cores; 3 x 16 cores is 960. The cpu partition has 446 x 128 cores.
- Standby waits in the pilot came from a single user. Twenty simultaneous submissions are not measured.

No option needs to change D1 to fit the budget.

## Options and recommendation

| Option | Alignment (per sample) | Calling (slowest chunk) | Teachability (below) | Evidence |
|---|---|---|---|---|
| (a) Whole chr20, native depth (about 40x) | 7.5 min at 32 c; 13.0 min at 16 c | 4.1 min | Keeps all measured examples | measured |
| (b) Whole chr20, subsampled to about 20x, fixed seed | about 3.2 min at 32 c; about 6.0 min at 16 c | about 2 min | Fewer het calls pass DP filters; more parental dropout, so more false de novo candidates | scaled from (a) by read count, not measured |
| (c) Sub-region at native depth, for example 16 Mb outside the centromere | about 1.6 min at 32 c for a quarter of the reads | 2.2-2.4 min (chunks 5 and 6) | About a quarter of the coding examples; chr20-wide there are only 4 HIGH-impact calls in HG002, so (c) may have none | scaled; the positions of the 4 HIGH calls were not recorded |

**Recommendation: option (a).**
- **Alignment:** 32 cores per sample task, an array of 3. 16 cores is the fallback if the account's core limit binds; then submit at the end of the Episode 2-3 block, as the plan's pacing option says.
- **Calling:** 8 chunks at 2 cores, an array of 8. The P3 reference run should use chunk boundaries that cannot split an indel. An alternative is to drop the equal-length split and use region boundaries in gaps, for example the centromere.
- **hap.py:** 16 cores, until per-run memory is measured.
- **SnpEff:** 4 cores.
- **Trio steps:** 4 cores.
- **Never `--mem`.**

## Teachability check

Source: the first call set (mpileup defaults, `pilot/call/`), evaluated in the rerun. These are pilot numbers on unfiltered calls.

| Measure | Value | Source |
|---|---|---|
| Trio records after norm | 185,628 (155,130 SNVs, 30,498 indels); 3,932 multiallelic sites before splitting | `pilot/call/trio.norm.SN_TSTV.txt`, `metrics.tsv` |
| Per-sample SNV genotypes (het + hom-alt) | HG002 119,775; HG003 117,657; HG004 118,571 | `pilot/call/trio.norm.stats.txt` (PSC) |
| Ts/Tv, all trio SNVs | 1.81 (1.93 at QUAL >= 100) | `pilot/call/trio.norm.stats.txt` |
| Ts/Tv, HG002 calls inside the v4.2.1 benchmark that match truth | 2.31 (truth set: 2.31) | `pilot/eval/HG002.v4.2.1.vcfeval.extended.csv` |
| Ts/Tv, HG002 calls outside the benchmark regions | 1.29 (47,644 SNV calls, 40% of HG002's SNV calls) | same |
| Ts/Tv, false positives inside the benchmark | 0.98 | same |
| HG002 vs v4.2.1, vcfeval, no filters | SNV recall 0.9946, precision 0.9861; indel recall 0.9425, precision 0.9457 | `pilot/eval/happy_metrics.tsv` |
| HG003, HG004 vs v4.2.1, vcfeval | SNV recall 0.9954 and 0.9953, precision 0.9852 and 0.9870; indel recall 0.9403 and 0.9427 | same |
| QUAL threshold, HG002 SNV (vcfeval ROC) | QUAL >= 30: recall 0.9942, precision 0.9887. QUAL >= 100: 0.9934, 0.9919. QUAL >= 225: 0.9904, 0.9948 | `pilot/eval/HG002.v4.2.1.vcfeval.roc.Locations.SNP.csv.gz` |
| QUAL threshold, HG002 indel | QUAL >= 30: 0.9418, 0.9469. QUAL >= 225: 0.9065, 0.9502 | `...roc.Locations.INDEL.csv.gz` |
| Mendelian consistency (`+mendelian2 -p`) | 3,319 sites with an error, 181,521 consistent, 792 with a missing GT: 1.80% of evaluated sites | `pilot/trio/mendelian2_counts.pilot.txt` |
| Naive de novo, child het and both parents 0/0 | all calls 1,509 SNVs and 402 indels; QUAL >= 30 and DP >= 10 in all three 540 and 243; plus the child's v4.2.1 benchmark regions 63 and 35 | `pilot/trio/naive_candidates.tsv` |
| Naive recessive, child 1/1 and both parents 0/1 | 4,899 and 1,103; 4,768 and 1,089; 4,321 and 744 (same tiers) | same |
| HG002 annotation (SnpEff MANE 1.2), all carried calls | 141,451 carried; HIGH 4; MODERATE 244; rare (gnomAD AF < 0.01 or absent) protein-altering 24; rare in asj 16; no gnomAD record 28,675 | `pilot/trio/child_counts.tsv`; SnpSift HIGH cross-check 4 |
| Rare protein-altering naive de novo / recessive | 0 / 1 | same |
| SnpEff effects, whole trio VCF, MANE 1.2 vs p14 | missense 336 vs 1,977; HIGH effects 10 vs 130; MODERATE 348 vs 2,049 | `pilot/annot/c8/snpeff_*.csv` |

How to read these numbers:
- **Ts/Tv and calls outside the benchmark.** Calls inside the benchmark regions look like the truth (Ts/Tv 2.31). The low overall Ts/Tv comes from about 40% of the raw calls, which fall outside the benchmark regions, mostly around the centromere and other repeats. QUAL alone barely removes them: 33,323 outside-benchmark SNV calls remain at QUAL >= 225. That makes Episode 6 a strong lesson on depth, mapping-quality and region filters. Whether `-q 20` at the mpileup stage removes them was the purpose of `CALL_SET=q20`, which was not run.
- **Ts/Tv baseline.** The plan quotes about 2.0-2.1 for whole-genome germline SNVs. Inside chr20 benchmark regions the truth itself is 2.31 (`truth/` via hap.py), so the episode should quote the chr20 benchmark value, or explain the difference.
- **Mendelian error rate.** 1.8% on unfiltered calls is in the range expected from genotyping error. A sample swap or reference mismatch would give a far higher rate, so the trio checks out.
- **De novo candidates.** The plan expects about 1-2 true de novo SNVs on chr20. Naive lists of 1,509, then 540, then 63 SNVs fit the plan's framing ("tens or hundreds, most candidates are errors"). No count is orders of magnitude off.
- **Episode 8's funnel ends near zero:** 0 rare protein-altering de novo candidates and 1 recessive, on unfiltered calls. That is a realistic and teachable outcome (base rates), but the episode has to frame it so. HIGH-impact examples in HG002 are few (4 with MANE), enough for the Episode 7 challenge on whole chr20.

Against the options:
- **(a)** keeps every example above.
- **(b)** lowers depth. Fewer calls pass DP >= 10 in all three samples, and parental under-calling inflates false de novo candidates. That is a plausible extra teaching point, but it is not measured.
- **(c)** risks losing the 4 HIGH-impact and some of the 24 rare protein-altering examples, and the recessive candidate.

## Benchmark notes

- **HG002 v5.0q vs v4.2.1 on chr20.** v5.0q's benchmark BED covers 58.1 Mb of chr20 (v4.2.1 noinconsistent: 56.9 Mb), and v5.0q has 75,854 SNVs and 18,173 indels inside it against 71,333 and 11,256 for v4.2.1 (`truth/truth_counts.tsv`, `pilot/eval/*summary.csv`). With the same calls, vcfeval scores:
  - v5.0q: SNV recall 0.9878, precision 0.9793; indel recall 0.8381, precision 0.8728.
  - v4.2.1: SNV 0.9946 and 0.9861; indel 0.9425 and 0.9457.

  v5.0q, the assembly-based benchmark, reaches into harder regions, so the same calls look worse, especially for indels. This is the "performance depends on the benchmark's scope" teaching point.
- **v5.0q file format.** The v5.0q VCF holds 155,971 SNV records on chr20, of which 94,196 records fall inside the BED. Many records outside the BED carry partial genotypes such as `.|0` (`truth/genotypes_HG002_latest.txt`). Always use the VCF with its BED.
- **xcmp vs vcfeval.** The two engines agree to within 0.002 on every metric (`pilot/eval/happy_metrics.tsv`). vcfeval takes 107-154 s and xcmp 74-97 s, and vcfeval builds an SDF template each run. NIST's v5.0q README recommends vcfeval and `--gender male` for HG002; sex does not matter on chr20.
- **De novo sites.**
  - v4.2.1 (`terms/giab421_readme_dir/README_v4.2.1.txt`): "we now perform a trio Mendelian analysis and exclude most Mendelian violations from the benchmark regions for all individuals. An exception is that putative de novo variants in HG002 are not excluded." 50 bp around non-de-novo Mendelian errors are excluded.
  - The v5.0q README does not mention Mendelian or de novo handling (`truth/readme_denovo_excerpts.txt` holds only the v4.2.1 passages). v5.0q is a single-sample, assembly-based benchmark.
  - So a de novo candidate that lies inside the HG002 v4.2.1 benchmark and appears in its VCF is supported by NIST's data. The 63 naive SNVs inside the benchmark have not yet been checked against the truth VCF; that is a P3 count.
- **Which truth set per sample:**
  - HG002: v5.0q as the primary benchmark (NIST's recommendation), with v4.2.1 shown for comparison.
  - HG003 and HG004: v4.2.1 with the `_noinconsistent` BED, the only GRCh38 BED published.

## Decisions needed

| # | Decision | Recommendation |
|---|---|---|
| 1 | Region and coverage | (a) whole chr20 at native depth (about 40x). No change to D1 |
| 2 | Core counts and chunks | Alignment 32 cores per sample (array of 3; 16 as fallback); calling 8 chunks at 2 cores; hap.py 16; SnpEff 4; trio steps 4 |
| 3 | bcftools module (blocker) | Fix the biocontainer wrapper to use `singularity exec` (or a runscript that does not re-parse), at least for bcftools, samtools and snpsift, before P3. Then confirm with `pilot/trio/gt_syntax_test.tsv` (all forms PASS) |
| 4 | bcftools version | Deploy bcftools 1.24 and htslib 1.24 with the fixed wrapper and pin them (D5 target), so the lesson gets `--write-index` and avoids 1.17's `-P` bug. If 1.24 is not deployed before P3, pin 1.17 and htslib 1.17 and use `+mendelian2 -p` |
| 5 | SnpEff database | `GRCh38.mane.1.2.ensembl` (MANE 1.5 is not available for 5.3a). One transcript per gene keeps the ANN output readable; p14 stays a self-paced comparison |
| 6 | hap.py engine | vcfeval, with xcmp mentioned. Stage an SDF template if the module allows, to avoid rebuilding it every run |
| 7 | Truth sets | HG002 v5.0q (GRCh38 smvar VCF plus benchmark BED) as primary, v4.2.1 for comparison; HG003 and HG004 v4.2.1 with `_noinconsistent` |
| 8 | mpileup filters | Rerun `CALL_SET=q20` (runbook R5, about 20 min) before choosing the Episode 5A command. Otherwise P3 runs both and chooses |
| 9 | Staging layout and Depot quota (P3) | `varcall-workshop/`: `data/` (6 FASTQ, 4.85 GB), `ref/` (FASTA, `.fai`, `.dict`, NCBI bwa index, 8.58 GB), `annot/` (gnomAD AF subset 0.91 GB, MANE 1.2 database), `truth/` (chr20 subsets, 13 MB). That is about 14.5 GB. `_results/` would hold BAMs (about 3.3 GB) plus VCFs and reports. The workshop Depot has 683.1 GB of 1.0 TB used, so about 317 GB is free (`preflight/myquota.txt`) |
| 10 | Workshop SLURM account | Not resolved. The pilot used `rcac`; RNA-seq uses `rcac-rnaseq`, scRNA-seq `workshop`. Choose an account for the delivery |
| 11 | IGV approach | `samtools tview` plus prepared IGV snapshots as the baseline; a desktop session only if the OOD/IGV checklist, still blank, shows it works under the workshop account |

## Still unverified

- OOD desktop or ThinLinc availability, and whether IGV 2.19.1 launches and loads the reference and a BAM (`ood_igv_check.md` is blank).
- Effect of `mpileup -q 20 -Q 20` on calls, Ts/Tv and precision (`CALL_SET=q20` not run).
- Which other biocontainer modules use `singularity run` and drop quotes, starting with samtools (`samtools view -e`) and snpsift.
- hap.py memory per run and per engine; the 23.88 GiB peak is for 8 sequential runs.
- bcftools 1.24 behavior (not installed).
- Options (b) and (c): scaled, not measured.
- Standby waits with about 20 learners submitting at once.
- How many of the 63 naive de novo SNVs inside the HG002 benchmark appear in the truth VCF (P3).
- Counts on filtered calls (all teachability counts above are on unfiltered calls).
- The workshop SLURM account and its core limits.
