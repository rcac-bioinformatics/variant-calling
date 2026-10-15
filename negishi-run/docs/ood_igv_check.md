# OOD and IGV check (fill in on Negishi)

Fill in each line, then run `collect.sh --run RUN_ID`; it copies this file into the tarball (`igv/`).
Date checked:
Checked by:

## Graphical session

- [x] Open OnDemand (gateway.negishi.rcac.purdue.edu) offers a desktop session. App name and menu path:
- [x] ThinLinc is available for Negishi. Address: https://desktop.negishi.rcac.purdue.edu:300/
- [ ] The desktop session can use the workshop account and the standby QoS. Fields required on the form:
```text
### Desktop
This app will launch an interactive desktop on one or more compute nodes.

Partition: cpu
The partition where this job should run.

Account: <account>
The account the resources for this job should be charged to.

QoS: standby
Quality of Service this job should run under.

Wall Time in Hours: 4

    Max of 336 hours in the CPU partition under the normal QOS
    Max of 4 hours in the CPU partition under the standby QOS
    Max of 24 hours in the GPU partition under the normal QOS
    Max of 24 hours in the highmem partition under the normal QOS

Cores: 2
You will receive ~2GB of memory per core requested.
- [ ] I would like to receive an email when the session starts

[[LAUNCH]]

* The Desktop session data for this session can be accessed under the data root directory.
```


- [x] Time from Launch to a usable desktop (minutes): 2-3
- [x] Which one the episode should name (Episode 8 says only "a graphical desktop session" until this is filled in): Gateway (or Open OnDemand)

## Headless snapshots (Prompt 06b, Part B)

The kit renders the snapshots in a standby job (`sbatch negishi-run/igv/run_snapshots.sh --run RUN_ID`; README, Phase 6). Its records are in `kit-runs/<RUN_ID>/records/igv_snapshots.tsv`, `igv_run.log` and `igv_version.txt`; copy the answers here.

- [x] `xvfb-run` found on the host, in the image, or neither: neither
- [x] IGV version reported (`igv_version.txt`; the image tag says 2.19.1): 2.19.1
- [x] IGV accepted the `.csi` indexes of the BAMs and the VCF (yes, or the message and whether `IGV_MAKE_BAI=1` was needed):
- [ ] With `IGV_MAKE_BAI=1`: the `created` and `removed` rows match, and "none left":
- [x] Two PNGs in `kit-runs/<RUN_ID>/igv/snapshots/`: `08_denovo_truth_supported_chr20_2202238.png` and `08_denovo_error_source_chr20_13604987.png`. Reads visible at base level in all three tracks; center line on the site; reads sorted at the site:
- [x] A 600-pixel panel shows every read at about 40x (or the reads cut off):
- [ ] Job wall time and MaxRSS (`sacct -j <jobid> --format=Elapsed,MaxRSS`):

```
   Elapsed     MaxRSS 
---------- ---------- 
  03:13:37            
  03:13:38    266572K 
  03:13:39            
```

## IGV in a desktop session (fallback, and the learner path)

In a terminal inside the desktop, with the same batch file:

```bash
module load biocontainers
module load igv/2.19.1
igv.sh -b $SCRATCH/varcall-kit/kit-runs/kit5-2026-10-11/igv/snapshots.batch
```

If `-b` does not run the script, start `igv.sh &` and use Tools > Run Batch Script with the same file. The batch ends with `exit`.

- [x] Which commands the module provides (`igv`, `igv.sh`, both); Episode 8 shows `igv &`: only igv.sh
- [x] IGV starts. Seconds to the main window:
- [x] The batch script loads the genome, the three BAMs, the VCF and the trio BED without an error dialog. If an index is refused, the message:
- [X] Deviations from the batch script (anything changed by hand): none
- [x] Memory or display errors seen (paste): bunch of stdout but no error dialogs

## Notes

- Anything a learner would trip on:
- Preferred approach for the lesson (desktop session, IGV-Web, or `samtools tview` plus snapshots):
