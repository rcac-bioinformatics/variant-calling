#!/usr/bin/env python3
"""pr_figure.py: the Episode 6 precision-recall figure for HG002 against benchmark v5.0q.

Usage (laptop, Part C):
  python3 negishi-run/pr_figure.py EVAL_DIR OUT.png
EVAL_DIR holds the kit's hap.py outputs (collect.sh copies them to qc/eval/ in the tarball):
  HG002.v5.0q.norm.roc.Locations.SNP.csv.gz, HG002.v5.0q.norm.roc.Locations.INDEL.csv.gz
      precision and recall at every QUAL threshold of the unfiltered calls (hap.py --roc QUAL)
  HG002.v5.0q.filtered.summary.csv
      the PASS row of each type: the calls after the workshop's filters (one point per type)
SNV and indel curves differ in line style as well as color, and the PASS points in marker shape.
The axes start where the data start, not at 0; the script prints the axis ranges so that the
caption can say so. Writes OUT.png at 200 dpi. Needs matplotlib (tested with 3.10.8, Python 3.13).
"""
import csv
import gzip
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

TYPES = [("SNP", "SNVs", "#1b6ca8", "-", "o"), ("INDEL", "Indels", "#c0392b", "--", "s")]


def roc(path):
    """[(QUAL, recall, precision)] sorted by QUAL"""
    rows = []
    with gzip.open(path, "rt") as fh:
        for r in csv.DictReader(fh):
            try:
                rows.append((float(r["QQ"]), float(r["METRIC.Recall"]), float(r["METRIC.Precision"])))
            except (KeyError, ValueError):
                pass
    return sorted(rows)


def pass_points(path):
    out = {}
    with open(path) as fh:
        for r in csv.DictReader(fh):
            if r["Filter"] == "PASS":
                out[r["Type"]] = (float(r["METRIC.Recall"]), float(r["METRIC.Precision"]))
    return out


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    d, out = sys.argv[1], sys.argv[2]
    pts = pass_points(os.path.join(d, "HG002.v5.0q.filtered.summary.csv"))
    fig, ax = plt.subplots(figsize=(6.4, 5.6))
    xs, ys = [], []
    for typ, label, color, ls, marker in TYPES:
        rows = roc(os.path.join(d, "HG002.v5.0q.norm.roc.Locations.%s.csv.gz" % typ))
        rec = [r[1] for r in rows]
        prec = [r[2] for r in rows]
        ax.plot(rec, prec, color=color, linestyle=ls, linewidth=2,
                label="%s, unfiltered calls by QUAL threshold" % label)
        xs += rec
        ys += prec
        if typ in pts:
            ax.plot(*pts[typ], marker=marker, markersize=9, color=color, markeredgecolor="black", linestyle="none",
                    label="%s, PASS after the workshop filters" % label)
            xs.append(pts[typ][0])
            ys.append(pts[typ][1])
    pad_x = 0.03 * (max(xs) - min(xs) or 1)
    pad_y = 0.03 * (max(ys) - min(ys) or 1)
    xlim = (max(0.0, min(xs) - pad_x), min(1.0, max(xs) + pad_x))
    ylim = (max(0.0, min(ys) - pad_y), min(1.0, max(ys) + pad_y))
    ax.set_xlim(*xlim)
    ax.set_ylim(*ylim)
    ax.set_xlabel("Recall")
    ax.set_ylabel("Precision")
    ax.set_title("HG002 against GIAB v5.0q, chromosome 20")
    ax.grid(True, color="#dddddd")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.14), ncol=2, fontsize=8, frameon=False)
    fig.tight_layout()
    fig.savefig(out, dpi=200)
    print("wrote %s; recall axis %.3f-%.3f, precision axis %.3f-%.3f (neither starts at 0: say so in the caption)"
          % (out, xlim[0], xlim[1], ylim[0], ylim[1]))
    for typ in pts:
        print("PASS point %s: recall %.4f, precision %.4f" % (typ, pts[typ][0], pts[typ][1]))


if __name__ == "__main__":
    main()
