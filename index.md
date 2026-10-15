---
site: sandpaper::sandpaper_site
---

# Welcome

This hands-on workshop teaches you how to find genetic variants in short-read sequencing data, from raw FASTQ files to a filtered, annotated and interpreted set of variant calls. You will work with a real human family trio from the Genome in a Bottle project (HG002 and their parents, HG003 and HG004) on Purdue's Negishi cluster, and you will run every step yourself with SLURM batch and array jobs.

The workshop is for graduate students, postdocs, staff and faculty who are comfortable with the basics of the command line and want to call germline SNVs and small indels in their own data. No prior variant-calling experience is needed. The methods apply to any diploid organism with a reference genome; the last episode shows how to adapt them.

## Learning outcomes

After completing this workshop, you will be able to:

- Explain how aligned reads become genotype calls and why calls can be wrong.
- Produce analysis-ready BAMs and a normalized multi-sample VCF on an HPC cluster, using batch and array jobs.
- Read and query VCF records, and filter calls with stated, justified thresholds.
- Measure call quality against a benchmark, and choose proxy measures when no benchmark exists.
- Annotate variants and use population frequencies appropriately.
- Derive a candidate-variant list for a family and state what the evidence does and does not support.

Before the workshop, follow the [setup instructions](learners/setup.md) to connect to Negishi and copy the workshop data.
