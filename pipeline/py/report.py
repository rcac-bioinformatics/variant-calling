#!/usr/bin/env python3
"""report.py: reference-run tables that need more than one file. Python 3.6.

  truth-status CANDIDATES OUT --truth LABEL=DUMP=BED [...]
      CANDIDATES: model, chrom, pos, ref, alt (tab-separated, header allowed).
      DUMP: bcftools query -f '%CHROM\t%POS\t%REF\t%ALT[\t%GT]\n' of one truth VCF.
      For each candidate and truth set: the truth genotype for the same allele, "absent_in_bed"
      (the benchmark says homozygous reference there), "other_allele", or "outside_bed".

  sentinels OUT --truth DUMP=BED --parents DUMP=BED,DUMP=BED --trio-bed BED --cen BED
            --exclude-bed BED [...] --calls LABEL=DUMP [...]
      Calls DUMP: bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t%QUAL\t%FILTER[\t%GT]\n' -s HG002
      Picks a heterozygous SNV, a homozygous-ALT SNV and an indel from the HG002 truth set
      (inside the trio regions, called identically and PASS in every call set), a truth-set
      site where HG002 carries an allele that neither parent has (inside both parents' BEDs),
      and an artifact: the highest-QUAL call of the first call set inside the centromere and
      outside every --exclude-bed. The first site of each kind by position wins.

  anchors OUT --kv FILE [...]
      FILE: tab-separated metric, call_set, value, tolerance, source (header allowed); rows are
      concatenated under one header after checks for empty values.
"""
import argparse
import bisect
import sys

HEADER = "# reference run, not frozen"


class Bed(object):
    def __init__(self, path):
        self.iv = {}
        with open(path) as fh:
            for line in fh:
                f = line.split("\t")
                if len(f) < 3 or line.startswith(("#", "track")):
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


def read_truth(path):
    """(chrom, pos) -> list of (ref, alt, gt); multiallelic ALT kept as written."""
    d = {}
    with open(path) as fh:
        for line in fh:
            f = line.rstrip("\n").split("\t")
            if len(f) < 5:
                continue
            d.setdefault((f[0], int(f[1])), []).append((f[2], f[3], f[4]))
    return d


def truth_gt(truth, chrom, pos, ref, alt):
    """GT of the truth record carrying this REF/ALT, recoded to 0/1 for that allele."""
    recs = truth.get((chrom, pos))
    if not recs:
        return None, False
    for r, a, gt in recs:
        alts = a.split(",")
        if r == ref and alt in alts:
            k = str(alts.index(alt) + 1)
            al = gt.replace("|", "/").split("/")
            return "/".join("1" if x == k else ("." if x == "." else "0") for x in al), True
    return None, True


def cmd_truth_status(a):
    sets = []
    for t in a.truth:
        label, dump, bed = t.split("=", 2)
        sets.append((label, read_truth(dump), Bed(bed)))
    out = [HEADER, "model\tchrom\tpos\tref\talt\t" + "\t".join(l for l, _, _ in sets)]
    n = 0
    with open(a.candidates) as fh:
        for line in fh:
            f = line.rstrip("\n").split("\t")
            if len(f) < 5 or f[0] == "model" or line.startswith("#"):
                continue
            model, chrom, pos, ref, alt = f[0], f[1], int(f[2]), f[3], f[4]
            row = [model, chrom, str(pos), ref, alt]
            for _, truth, bed in sets:
                gt, seen = truth_gt(truth, chrom, pos, ref, alt)
                if gt is not None:
                    row.append("GT=" + gt)
                elif seen:
                    row.append("other_allele")
                elif bed.has(chrom, pos):
                    row.append("absent_in_bed")
                else:
                    row.append("outside_bed")
            out.append("\t".join(row))
            n += 1
    with open(a.out, "w") as o:
        o.write("\n".join(out) + "\n")
    sys.stderr.write("truth-status: %d candidates\n" % n)


def read_calls(path):
    d = {}
    with open(path) as fh:
        for line in fh:
            f = line.rstrip("\n").split("\t")
            if len(f) < 7:
                continue
            d[(f[0], int(f[1]), f[2], f[3])] = (f[4], f[5], f[6].replace("|", "/"))
    return d


def cmd_sentinels(a):
    tdump, tbed = a.truth.split("=", 1)
    truth = read_truth(tdump)
    hbed = Bed(tbed)
    parents = []
    for p in a.parents.split(","):
        d, b = p.split("=", 1)
        parents.append((read_truth(d), Bed(b)))
    trio = Bed(a.trio_bed)
    cen = Bed(a.cen)
    excl = [Bed(b) for b in a.exclude_bed]
    calls = []
    for c in a.calls:
        label, dump = c.split("=", 1)
        calls.append((label, read_calls(dump)))
    picks = {}

    def called_same(key, gt):
        for _, d in calls:
            r = d.get(key)
            if not r or r[1] != "PASS" or r[2] != gt:
                return False
        return True

    for (chrom, pos) in sorted(truth, key=lambda k: (k[0], k[1])):
        for ref, alt, gt in truth[(chrom, pos)]:
            if "," in alt:
                continue
            g = gt.replace("|", "/")
            snv = len(ref) == 1 and len(alt) == 1
            key = (chrom, pos, ref, alt)
            if trio.has(chrom, pos) and hbed.has(chrom, pos):
                kind = None
                if snv and g in ("0/1", "1/0") and "het_snv" not in picks:
                    kind, g = "het_snv", "0/1"
                elif snv and g == "1/1" and "homalt_snv" not in picks:
                    kind = "homalt_snv"
                elif not snv and g in ("0/1", "1/0", "1/1") and "indel" not in picks:
                    kind, g = "indel", ("1/1" if g == "1/1" else "0/1")
                if kind and called_same(key, g):
                    picks[kind] = (key, g)
            if "trio_inconsistent" not in picks and g in ("0/1", "1/0", "1/1"):
                inside = all(b.has(chrom, pos) for _, b in parents) and hbed.has(chrom, pos)
                carried = any(truth_gt(t, chrom, pos, ref, alt)[0] not in (None, "0/0") for t, _ in parents)
                if inside and not carried:
                    picks["trio_inconsistent"] = (key, g)
    # artifact: highest QUAL call of the first call set in the centromere, outside every benchmark
    best = None
    label0, d0 = calls[0]
    for key, (q, filt, gt) in d0.items():
        chrom, pos = key[0], key[1]
        if not cen.has(chrom, pos) or any(b.has(chrom, pos) for b in excl):
            continue
        try:
            qv = float(q)
        except ValueError:
            continue
        if gt in ("./.", "0/0"):
            continue
        if best is None or qv > best[0] or (qv == best[0] and key < best[1]):
            best = (qv, key)
    if best:
        picks["artifact"] = (best[1], "not in any truth set")
    out = [HEADER, "sentinel\tchrom\tpos\tref\talt\texpected_truth_gt\t" +
           "\t".join("%s_qual\t%s_filter\t%s_gt" % (l, l, l) for l, _ in calls)]
    for kind in ("het_snv", "homalt_snv", "indel", "trio_inconsistent", "artifact"):
        if kind not in picks:
            out.append("%s\tnone found" % kind)
            continue
        key, g = picks[kind]
        row = [kind, key[0], str(key[1]), key[2], key[3], g]
        for _, d in calls:
            row.extend(d.get(key, ("NA", "not_called", "NA")))
        out.append("\t".join(row))
    with open(a.out, "w") as o:
        o.write("\n".join(out) + "\n")
    sys.stderr.write("sentinels: %s\n" % ", ".join(sorted(picks)))


def cmd_anchors(a):
    rows, bad = [], 0
    for p in a.kv:
        with open(p) as fh:
            for line in fh:
                if line.startswith("#") or line.startswith("metric\t") or not line.strip():
                    continue
                f = line.rstrip("\n").split("\t")
                if len(f) != 5 or f[2] in ("", "NA"):
                    sys.stderr.write("anchors: missing value in %s: %s" % (p, line))
                    bad += 1
                rows.append("\t".join(f))
    with open(a.out, "w") as o:
        o.write(HEADER + "; draft for gate G3\nmetric\tcall_set\tvalue\ttolerance\tsource\n")
        o.write("\n".join(rows) + "\n")
    sys.stderr.write("anchors: %d rows, %d with a missing value\n" % (len(rows), bad))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd")
    t = sp.add_parser("truth-status")
    t.add_argument("candidates")
    t.add_argument("out")
    t.add_argument("--truth", action="append", required=True)
    s = sp.add_parser("sentinels")
    s.add_argument("out")
    s.add_argument("--truth", required=True)
    s.add_argument("--parents", required=True)
    s.add_argument("--trio-bed", required=True)
    s.add_argument("--cen", required=True)
    s.add_argument("--exclude-bed", action="append", default=[])
    s.add_argument("--calls", action="append", required=True)
    n = sp.add_parser("anchors")
    n.add_argument("out")
    n.add_argument("--kv", action="append", required=True)
    a = ap.parse_args()
    if a.cmd == "truth-status":
        cmd_truth_status(a)
    elif a.cmd == "sentinels":
        cmd_sentinels(a)
    elif a.cmd == "anchors":
        sys.exit(cmd_anchors(a))
    else:
        ap.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
