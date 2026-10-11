#!/usr/bin/env python3
"""metrics.py: call-set distributions, Ts/Tv by region, and the soft-filter proposal for the
reference run. Reads a bcftools query dump; never reads hap.py output.

Usage:
  python3 metrics.py DUMP OUTDIR --samples HG002,HG003,HG004 --chunks chr20_chunks.txt
                     [--bed NAME=PATH ...] [--pass-only] [--label LABEL]
DUMP: tab-separated, optionally gzipped, from
  bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t%TYPE\t%QUAL\t%INFO/DP\t%INFO/MQ\t%INFO/MQ0F\t%FILTER[\t%GT\t%DP\t%GQ\t%AD]\n'
Writes into OUTDIR: quantiles.tsv, mq_hist.tsv, allele_balance.tsv, tstv_regions.tsv and, unless
--pass-only, filter_proposal.tsv. The rule in filter_proposal.tsv is the one the learner block
06-filter.sh applies: HighDP above twice the median site depth; QUAL < 30; mean MQ < 30;
genotypes with DP < 10 or GQ < 20 set to missing. Python 3.6.
"""
import argparse
import bisect
import gzip
import os

TS = {("A", "G"), ("G", "A"), ("C", "T"), ("T", "C")}
HEADER = "# reference run, not frozen"


def opener(p):
    return gzip.open(p, "rt") if p.endswith(".gz") else open(p)


def num(x):
    try:
        return float(x)
    except ValueError:
        return None


def quantiles(v, qs=(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99)):
    if not v:
        return ["NA"] * len(qs)
    v = sorted(v)
    return ["%g" % v[min(len(v) - 1, int(q * len(v)))] for q in qs]


def median_low(v):
    """Same element the learner's awk picks: d[int((NR + 1) / 2)] on sorted values, 1-based."""
    v = sorted(v)
    return v[(len(v) + 1) // 2 - 1]


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


def read_chunks(path):
    out = []
    with open(path) as fh:
        for i, line in enumerate(fh, 1):
            c, r = line.strip().split(":")
            s, e = r.split("-")
            out.append(("chunk%02d" % i, c, int(s), int(e)))
    return out


def gt_alt(gt):
    a = gt.replace("|", "/").split("/")
    if "." in a:
        return None
    return sum(1 for x in a if x != "0")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dump")
    ap.add_argument("outdir")
    ap.add_argument("--samples", required=True)
    ap.add_argument("--chunks", required=True)
    ap.add_argument("--bed", action="append", default=[])
    ap.add_argument("--pass-only", action="store_true")
    ap.add_argument("--label", default="")
    a = ap.parse_args()
    samples = a.samples.split(",")
    beds = [(n, Bed(p)) for n, p in (b.split("=", 1) for b in a.bed)]
    chunks = read_chunks(a.chunks)
    os.makedirs(a.outdir, exist_ok=True)

    qual = {"all": [], "SNP": [], "INDEL": []}
    sdp, mq = [], []
    gdp = {s: [] for s in samples}
    ggq = {s: [] for s in samples}
    ab = {s: [0] * 20 for s in samples}
    mqh = [0] * 7  # <10, 10-19, ..., 50-59, >=60
    # tstv[(set, region)] = [snv, ts, tv, indel]
    tstv = {}
    nsites = 0
    gt_masked = {s: 0 for s in samples}
    gt_low = {s: 0 for s in samples}

    def add(key, typ, ts):
        r = tstv.setdefault(key, [0, 0, 0, 0])
        if typ == "SNP":
            r[0] += 1
            r[1 if ts else 2] += 1
        elif typ == "INDEL":
            r[3] += 1

    with opener(a.dump) as fh:
        for line in fh:
            f = line.rstrip("\n").split("\t")
            chrom, pos, ref, alt, typ, q, dp, m, mq0f, filt = f[:10]
            if a.pass_only and filt != "PASS":
                continue
            pos = int(pos)
            nsites += 1
            qv = num(q)
            if qv is not None:
                qual["all"].append(qv)
                if typ in qual:
                    qual[typ].append(qv)
            d = num(dp)
            if d is not None:
                sdp.append(d)
            mv = num(m)
            if mv is not None:
                mq.append(mv)
                mqh[min(6, int(mv // 10))] += 1
            ts = typ == "SNP" and (ref.upper(), alt.upper()) in TS
            regions = ["all"]
            for name, b in beds:
                regions.append(name + ("_in" if b.has(chrom, pos) else "_out"))
            for cid, c, s, e in chunks:
                if c == chrom and s <= pos <= e:
                    regions.append(cid)
                    break
            for r in regions:
                add(("trio_sites", r), typ, ts)
            for i, s in enumerate(samples):
                gt, sd, sg, sad = f[10 + 4 * i:14 + 4 * i]
                na = gt_alt(gt)
                if na is None:
                    gt_masked[s] += 1
                    continue
                vd, vg = num(sd), num(sg)
                if vd is not None:
                    gdp[s].append(vd)
                if vg is not None:
                    ggq[s].append(vg)
                if vd is None or vg is None or vd < 10 or vg < 20:
                    gt_low[s] += 1
                if na == 1:
                    ad = [num(x) for x in sad.split(",")]
                    if len(ad) == 2 and None not in ad and sum(ad) > 0:
                        ab[s][min(19, int(20 * ad[1] / sum(ad)))] += 1
                if na >= 1:
                    for r in regions:
                        add((s + "_carried", r), typ, ts)

    tag = HEADER + (" (%s)" % a.label if a.label else "") + ("; PASS sites only" if a.pass_only else "")
    with open(os.path.join(a.outdir, "quantiles.tsv"), "w") as o:
        o.write(tag + "\nmeasure\tn\tp01\tp05\tp10\tp25\tp50\tp75\tp90\tp95\tp99\n")
        for k in ("all", "SNP", "INDEL"):
            o.write("QUAL_%s\t%d\t%s\n" % (k, len(qual[k]), "\t".join(quantiles(qual[k]))))
        o.write("site_DP\t%d\t%s\n" % (len(sdp), "\t".join(quantiles(sdp))))
        o.write("site_MQ\t%d\t%s\n" % (len(mq), "\t".join(quantiles(mq))))
        for s in samples:
            o.write("%s_DP\t%d\t%s\n" % (s, len(gdp[s]), "\t".join(quantiles(gdp[s]))))
            o.write("%s_GQ\t%d\t%s\n" % (s, len(ggq[s]), "\t".join(quantiles(ggq[s]))))
    with open(os.path.join(a.outdir, "mq_hist.tsv"), "w") as o:
        o.write(tag + "\nsite_MQ_bin\tsites\n")
        for i, n in enumerate(mqh):
            o.write("%s\t%d\n" % ("%d-%d" % (10 * i, 10 * i + 9) if i < 6 else ">=60", n))
    with open(os.path.join(a.outdir, "allele_balance.tsv"), "w") as o:
        o.write(tag + "\nalt_fraction_bin\t" + "\t".join(samples) + "\n")
        for b in range(20):
            o.write("%.2f-%.2f\t%s\n" % (b / 20.0, (b + 1) / 20.0, "\t".join(str(ab[s][b]) for s in samples)))
    with open(os.path.join(a.outdir, "tstv_regions.tsv"), "w") as o:
        o.write(tag + "\nset\tregion\tsnvs\tts\ttv\ttstv\tindels\n")
        for (st, r), (n, t, v, ind) in sorted(tstv.items()):
            o.write("%s\t%s\t%d\t%d\t%d\t%s\t%d\n" % (st, r, n, t, v, ("%.3f" % (t / float(v))) if v else "NA", ind))
    if not a.pass_only and sdp:
        med = median_low(sdp)
        maxdp = int(2 * med)
        rows = [
            ("HighDP", "INFO/DP > 2 x median site depth", "%d (median %g)" % (maxdp, med), sum(1 for x in sdp if x > maxdp)),
            ("LowQual", "QUAL < 30", "30", sum(1 for x in qual["all"] if x < 30)),
            ("LowMQ", "INFO/MQ < 30", "30", sum(1 for x in mq if x < 30)),
        ]
        with open(os.path.join(a.outdir, "filter_proposal.tsv"), "w") as o:
            o.write(tag + "\n# proposed from distributions before any hap.py result exists\n")
            o.write("filter\trule\tthreshold\tsites_flagged\tfraction_of_sites\n")
            for name, rule, thr, n in rows:
                o.write("%s\t%s\t%s\t%d\t%.4f\n" % (name, rule, thr, n, n / float(nsites)))
            for s in samples:
                low = gt_low[s]
                o.write("GT_mask_%s\tFMT/DP < 10 or FMT/GQ < 20 -> ./.\tDP 10, GQ 20\t%d\t%.4f\n" % (s, low, low / float(max(1, nsites - gt_masked[s]))))
    with open(os.path.join(a.outdir, "sites.tsv"), "w") as o:
        o.write(tag + "\nmeasure\tvalue\n")
        o.write("sites\t%d\n" % nsites)
        for s in samples:
            o.write("%s_genotypes_missing\t%d\n" % (s, gt_masked[s]))


if __name__ == "__main__":
    main()
