#!/usr/bin/env python3
"""bench_scope.py: benchmark scope of candidates already given a truth status (Prompt 06 Part C,
decision 1, 2026-10-14). Python 3.6.

Usage: python3 bench_scope.py TRUTH_STATUS OUT --bed LABEL=BED [...]
  TRUTH_STATUS: pipeline/py/report.py truth-status output (model, chrom, pos, ref, alt, then one
  column per truth set: GT=..., absent_in_bed, other_allele or outside_bed), copied to OUT. report.py reports a
  matching truth record before it looks at the BED, so GT=... does not say the site is inside
  the benchmark. For each LABEL (a truth-set column) this adds two columns:
    LABEL_in_bed     yes or no: the candidate's POS is inside BED
    LABEL_supported  yes when the truth VCF has the candidate's allele (a GT with a 1) and POS is
                     inside BED (the "VCF within BED" rule); otherwise no
  Then: both_HG002_supported (yes when every LABEL starting with HG002_ is supported) and
  truth_supported (child het in both HG002 sets under that rule, HG003_v4.2.1 and HG004_v4.2.1
  absent_in_bed, as in the P3 class). Counts go to stderr and to the end of OUT as # lines.
"""
import argparse
import bisect
import sys


class Bed(object):
    def __init__(self, path):
        self.iv = {}
        with open(path) as fh:
            for line in fh:
                f = line.split("\t")
                if len(f) < 3 or line.startswith(("#", "track", "browser")):
                    continue
                self.iv.setdefault(f[0], []).append((int(f[1]), int(f[2])))
        for c in self.iv:
            self.iv[c].sort()
        self.st = {c: [s for s, _ in v] for c, v in self.iv.items()}

    def has(self, chrom, pos1):
        v = self.iv.get(chrom)
        if not v:
            return False
        i = bisect.bisect_right(self.st[chrom], pos1 - 1) - 1
        return i >= 0 and v[i][0] <= pos1 - 1 < v[i][1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("truth_status")
    ap.add_argument("out")
    ap.add_argument("--bed", action="append", required=True, help="LABEL=BED")
    a = ap.parse_args()
    beds = []
    for b in a.bed:
        label, path = b.split("=", 1)
        beds.append((label, Bed(path)))
    rows, head = [], None
    with open(a.truth_status) as fh:
        for line in fh:
            if line.startswith("#"):
                continue
            f = line.rstrip("\n").split("\t")
            if head is None:
                head = f
                continue
            if len(f) == len(head):
                rows.append(dict(zip(head, f)))
    for label, _ in beds:
        if label not in head:
            sys.exit("bench_scope.py: no column %s in %s" % (label, a.truth_status))
    het = lambda x: x in ("GT=0/1", "GT=1/0")
    out = ["\t".join(head + sum([[l + "_in_bed", l + "_supported"] for l, _ in beds], [])
                     + ["both_HG002_supported", "truth_supported"])]
    n = {"rows": 0, "both": 0, "truth": 0}
    for l, _ in beds:
        n[l] = 0
    for r in rows:
        pos = int(r["pos"])
        line = [r[c] for c in head]
        sup = {}
        for l, bed in beds:
            inb = bed.has(r["chrom"], pos)
            s = inb and r[l].startswith("GT=") and "1" in r[l]
            sup[l] = s
            n[l] += s
            line += ["yes" if inb else "no", "yes" if s else "no"]
        h2 = [l for l, _ in beds if l.startswith("HG002_")]
        both = bool(h2) and all(sup[l] for l in h2)
        truth = (bool(h2) and all(sup[l] and het(r[l]) for l in h2)
                 and r.get("HG003_v4.2.1") == "absent_in_bed" and r.get("HG004_v4.2.1") == "absent_in_bed")
        n["rows"] += 1
        n["both"] += both
        n["truth"] += truth
        out.append("\t".join(line + ["yes" if both else "no", "yes" if truth else "no"]))
    summ = ["# candidates\t%d" % n["rows"]]
    summ += ["# in the %s truth VCF within its BED\t%d" % (l, n[l]) for l, _ in beds]
    summ += ["# in both HG002 truth VCFs within their BEDs\t%d" % n["both"],
             "# truth-supported (het in both HG002 sets within their BEDs, parents hom-ref)\t%d" % n["truth"]]
    with open(a.out, "w") as o:
        o.write("\n".join(out + summ) + "\n")
    sys.stderr.write("\n".join(s[2:] for s in summ) + "\n")


if __name__ == "__main__":
    main()
