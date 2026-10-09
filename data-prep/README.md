# data-prep

Phase-2 scripts that fetch and prepare the workshop inputs on Negishi, for the feasibility pilot. They write only under `$PREP_DIR` (default `$SCRATCH/varcall-prep`), never under `/depot/workshop/data`; staging the learner copy belongs to phase 3. Settings come from `../negishi-run/config.sh`; every external file is listed once in `sources.tsv`.

| Script | Where it runs | What it does |
|---|---|---|
| `01_fetch.sh` | login node (downloads, about 5 GB) | Input BAMs and indexes, reference FASTA and `.fai` (and NCBI's bwa index if one exists), GIAB v4.2.1 for all three samples, the HG002 `latest` GRCh38 small-variant files; sizes and md5 checked; provenance and README/terms texts recorded |
| `02_reference.sh` | submits `prep-faidx`, `prep-bwaindex` | Decompress, `samtools faidx` and `dict`; test NCBI's bwa index with 1,000 read pairs, or build one |
| `03_bam_to_fastq.sh` | submits the `prep-fastq` array (one task per sample) | Source-BAM facts (read length, insert size, duplicate and QC-fail flags, mates outside chr20, header vs reference, depth), then paired FASTQ with singletons dropped |
| `04_truth_subsets.sh` | submits `prep-truth` | chr20 subsets of every benchmark VCF and BED, counts, `truth/truth_sets.tsv`, README passages on Mendelian-inconsistent and de novo sites |
| `05_annotation.sh` | login node or compute node for downloads, then submits `prep-annot` | SnpEff GRCh38 databases (MANE preferred, plus one full-transcript database), and a gnomAD v4.1 chr20 subset with allele-frequency fields only |

Every script takes `--dry-run` (print the commands and SLURM jobs, change nothing) and `--force` (redo finished work). Without `--force`, finished downloads and jobs with a PASS marker are skipped.

`sources.tsv` columns: `id`, `url`, `purpose` (rows starting with "optional" may be absent upstream), `expected_size` in bytes (`-` if unknown), `checksum_source` (`gcs_json_api`: md5 from the Google Cloud Storage JSON API; `ncbi_md5checksums`: NCBI's `md5checksums.txt`, if published; `listing`: a directory whose README and md5 files are saved; `nist_checksum_md5`: the `checksum.md5` in the GIAB release directory; `none`: md5 computed and recorded only), `terms_url`, `expected_md5` (from the verified 2026-10-09 download; used when no md5 is published, `-` if unknown). The `giab_HG002_latest_*` rows record the v5.0q files that `01_fetch.sh` resolves from the `latest` listing; `latest` moves, so a size or md5 mismatch there means NIST released a new version.

Verified on 2026-10-09 (phase 2, `maintenance/plan/feasibility.md`): NCBI publishes `md5checksums.txt` and a bwa index tarball under the names in `sources.tsv`, and the index loads in bwa 0.7.17; the HG002 `latest` release is v5.0q (`HG002_GRCh38_v5.0q_smvar.vcf.gz` with `HG002_GRCh38_v5.0q_smvar.benchmark.bed`); GRCh38 v4.2.1 publishes only the `_noinconsistent` BED; gnomAD is CC0 and SnpEff MIT.

Outputs (all under `$PREP_DIR`): `src/` downloads, `ref/`, `fastq/`, `truth/`, `annot/`, `records/` (what `negishi-run/collect.sh` brings back), `state/` (markers, job table, settings found at run time), `logs/`. See `../negishi-run/README.md` for the run order.
