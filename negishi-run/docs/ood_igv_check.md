# OOD and IGV check (fill in on Negishi)

Fill in each line, then run `collect.sh`; it copies this file into the records tarball.
Date checked:
Checked by:

## Graphical session

- [ ] Open OnDemand (gateway.negishi.rcac.purdue.edu) offers a desktop session. App name and menu path:
- [ ] ThinLinc is available for Negishi. Address:
- [ ] The desktop session can use the workshop account and the standby QoS. Fields required on the form:
- [ ] Time from Launch to a usable desktop (minutes):

## IGV in that session

In a terminal inside the desktop:

```bash
module load biocontainers
module load igv/2.19.1
igv &
```

- [ ] `igv/2.19.1` loads. If not, the version that loads:
- [ ] IGV starts. Seconds to the main window:
- [ ] Genome > Load Genome from File: `$SCRATCH/varcall-prep/ref/GCA_000001405.15_GRCh38_no_alt_analysis_set.fna` loads (with its `.fai`).
- [ ] File > Load from File: a pilot BAM, `$SCRATCH/varcall-prep/pilot/align/c16/HG002.markdup.bam`, loads and shows reads at `chr20:30,000,000-30,001,000`.
- [ ] Memory or display errors seen (paste):

## Notes

- Anything a learner would trip on:
- Preferred approach for the lesson (desktop session, IGV-Web, or `samtools tview` plus snapshots):
