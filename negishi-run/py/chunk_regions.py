#!/usr/bin/env python3
"""chunk_regions.py: split one contig into N calling regions, cutting inside runs of N where
possible so that no variant (an indel near a cut) can straddle two regions.

Usage: python3 chunk_regions.py FASTA CONTIG N [MIN_GAP] > chunks.txt
Writes regions as CONTIG:START-END (1-based, inclusive), one per line, in order, and a report
on stderr. For each of the N-1 cuts it takes the N-run (length >= MIN_GAP, default 1000) whose
midpoint is closest to the equal-length cut point, within a quarter of a chunk; if there is
none, it cuts at the equal-length point and says so. Needs FASTA.fai. Python 3.6.
"""
import sys


def read_contig(fasta, contig):
    with open(fasta + ".fai") as fh:
        for line in fh:
            f = line.rstrip("\n").split("\t")
            if f[0] == contig:
                length, offset, bases, width = int(f[1]), int(f[2]), int(f[3]), int(f[4])
                break
        else:
            sys.exit("contig %s not in %s.fai" % (contig, fasta))
    nlines = (length + bases - 1) // bases
    with open(fasta, "rb") as fh:
        fh.seek(offset)
        raw = fh.read(nlines * width)
    seq = raw.replace(b"\n", b"").replace(b"\r", b"")[:length]
    if len(seq) != length:
        sys.exit("read %d bases of %s, expected %d" % (len(seq), contig, length))
    return seq


def n_runs(seq, min_gap):
    runs, i, n = [], 0, len(seq)
    up = seq.upper()
    while i < n:
        j = up.find(b"N", i)
        if j < 0:
            break
        k = j
        while k < n and up[k:k + 1] == b"N":
            k += 1
        if k - j >= min_gap:
            runs.append((j, k))  # 0-based, half-open
        i = k
    return runs


def main():
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    fasta, contig, nchunk = sys.argv[1], sys.argv[2], int(sys.argv[3])
    min_gap = int(sys.argv[4]) if len(sys.argv) > 4 else 1000
    seq = read_contig(fasta, contig)
    length = len(seq)
    runs = n_runs(seq, min_gap)
    size = length / float(nchunk)
    cuts = []  # 1-based last position of each chunk but the last
    for k in range(1, nchunk):
        target = k * size
        best = None
        for s, e in runs:
            mid = (s + e) // 2
            if abs(mid - target) <= size / 4 and (best is None or abs(mid - target) < abs(best[0] - target)):
                best = (mid, s, e)
        if best:
            cuts.append(best[0])
            sys.stderr.write("cut %d at %d, inside N-run %d-%d (%d bp)\n" % (k, best[0], best[1] + 1, best[2], best[2] - best[1]))
        else:
            cuts.append(int(round(target)))
            sys.stderr.write("cut %d at %d, equal-length point (no N-run >= %d bp within %d bp)\n" % (k, int(round(target)), min_gap, int(size / 4)))
    starts = [1] + [c + 1 for c in cuts]
    ends = cuts + [length]
    for s, e in zip(starts, ends):
        print("%s:%d-%d" % (contig, s, e))
    sys.stderr.write("%s: %d bp, %d N-runs >= %d bp, %d chunks\n" % (contig, length, len(runs), min_gap, nchunk))


if __name__ == "__main__":
    main()
