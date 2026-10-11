#!/usr/bin/env python3
"""bed_intersect.py: intersection of two or more BED files (first three columns), merged and
sorted, on stdout. Used for the trio region set: the three v4.2.1 _noinconsistent BEDs.

Usage: python3 bed_intersect.py A.bed B.bed [C.bed ...] > out.bed
Coordinates are BED (0-based, half-open). Overlapping or touching intervals within a file are
merged first. Python 3.6.
"""
import sys
from collections import defaultdict


def read_bed(path):
    iv = defaultdict(list)
    with open(path) as fh:
        for line in fh:
            if not line.strip() or line.startswith(("#", "track", "browser")):
                continue
            f = line.split("\t")
            iv[f[0]].append((int(f[1]), int(f[2])))
    return {c: merge(v) for c, v in iv.items()}


def merge(v):
    out = []
    for s, e in sorted(v):
        if out and s <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], e))
        else:
            out.append((s, e))
    return out


def intersect(a, b):
    out, i, j = [], 0, 0
    while i < len(a) and j < len(b):
        s, e = max(a[i][0], b[j][0]), min(a[i][1], b[j][1])
        if s < e:
            out.append((s, e))
        if a[i][1] < b[j][1]:
            i += 1
        else:
            j += 1
    return out


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    beds = [read_bed(p) for p in sys.argv[1:]]
    contigs = set(beds[0])
    for b in beds[1:]:
        contigs &= set(b)
    total = 0
    for c in sorted(contigs):
        cur = beds[0][c]
        for b in beds[1:]:
            cur = intersect(cur, b[c])
        for s, e in cur:
            print("%s\t%d\t%d" % (c, s, e))
            total += e - s
    sys.stderr.write("intersection of %d BEDs: %d bp\n" % (len(beds), total))


if __name__ == "__main__":
    main()
