#!/usr/bin/env python3
"""summarize.py RUN_DIR KIT_GEN OUT_DIR

Reads one episode-kit run (submit_all.sh) and writes into OUT_DIR:
  SUMMARY.md              per-step status with the first error of any failure; the alignment, calling,
                          filtering, hap.py, Mendelian and funnel anchors and the sentinels against
                          negishi-run/anchors.tsv (exact match); every hap.py summary.csv (SNV and
                          indel, ALL and PASS); the annotation counts and the trio candidate tables
                          against the reference-run memo; runtime against front matter; memory
                          headroom of each evaluate.sh task and of the annotation and trio steps; the
                          live load per learner and for 20 learners; the kit-only records; the value
                          of every {{kit:...}} placeholder; MultiQC plot exports; and the console
                          output of every block the kit ran
  placeholder_values.tsv  one row per placeholder: id, file, line, status, value (newlines as \\n)
  outputs/<id>.txt        full value of each placeholder (console text for -out- placeholders)
  outputs/blocks/<page>_<NN>.txt   console output of every block, as a learner would see it
Python 3.6, standard library only (Negishi login nodes).

METRICS maps every non-output placeholder id to a function of the run; FIGURES maps every figure
slot to a glob under records/multiqc_export/. build_kit.py checks that both cover the episodes.
"""
import csv
import glob
import io
import os
import re
import sys
import zipfile

SAMPLES = ["HG002", "HG003", "HG004"]
KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Ctx(object):
    def __init__(self, run, gen):
        self.run, self.gen = run, gen
        env = {}
        p = os.path.join(run, "kit.env")
        if os.path.exists(p):
            for line in open(p):
                if "=" in line:
                    k, v = line.rstrip("\n").split("=", 1)
                    env[k] = v.strip("'\"")
        self.W = env.get("W", os.path.join(run, "scratch", "varcall-workshop"))
        self.rec = os.path.join(run, "records")
        self.console = {}  # step -> {block ref: [lines]}

    def path(self, *a):
        return os.path.join(self.W, *a)

    def blocks(self, step):
        if step not in self.console:
            self.console[step] = parse_console(os.path.join(self.rec, "console", "%s.log" % step))
        return self.console[step]

    def block_by_text(self, step, needle):
        """console lines of the block of a step whose generated text contains needle"""
        idx = read_tsv(os.path.join(self.gen, "index.tsv"))
        for r in idx:
            if r["step"] == step and r["file"] != "-":
                f = os.path.join(self.gen, r["file"])
                if os.path.exists(f) and needle in open(f).read():
                    return self.blocks(step).get("%s/%s" % (r["page"], r["block"]))
        return None


def read_tsv(p):
    if not os.path.exists(p):
        return []
    with open(p) as fh:
        return list(csv.DictReader((l for l in fh if not l.startswith("#")), delimiter="\t"))


def parse_console(p):
    out, cur = {}, None
    if not os.path.exists(p):
        return out
    for line in open(p, errors="replace"):
        line = line.rstrip("\n")
        m = re.match(r'^### KIT-BLOCK (\S+) (begin|end) ', line)
        if m:
            cur = m.group(1) if m.group(2) == "begin" else None
            if cur is not None:
                out[cur] = []
            continue
        if cur is not None and not line.startswith("### KIT-"):
            out[cur].append(line)
    return out


def fmt_int(n):
    return "{:,}".format(int(n))


# ------------------------------------------------------------ parsers of tool outputs
def stats_sn(ctx, s):
    sn = {}
    p = ctx.path("results", "qc_alignment", "%s.stats.txt" % s)
    if os.path.exists(p):
        for line in open(p):
            if line.startswith("SN\t"):
                f = line.rstrip("\n").split("\t")
                sn[f[1].rstrip(":")] = f[2]
    return sn


def mosdepth_mean(ctx, s):
    p = ctx.path("results", "qc_alignment", "%s.mosdepth.summary.txt" % s)
    if os.path.exists(p):
        for line in open(p):
            f = line.split("\t")
            if f[0] == "chr20":
                return f[3].strip()
    return None


def fastqc(ctx):
    """file stem -> {'summary': {module: status}, 'total': n, 'gc': x, 'dedup': x, 'adapter_max': x}"""
    res = {}
    for z in sorted(glob.glob(ctx.path("results", "qc", "*_fastqc.zip"))):
        stem = os.path.basename(z)[:-len("_fastqc.zip")]
        d = {"summary": {}, "adapter_max": 0.0}
        try:
            zf = zipfile.ZipFile(z)
        except zipfile.BadZipfile:
            continue
        for name in zf.namelist():
            if name.endswith("/summary.txt"):
                for line in io.TextIOWrapper(zf.open(name)):
                    f = line.rstrip("\n").split("\t")
                    if len(f) >= 2:
                        d["summary"][f[1]] = f[0]
            elif name.endswith("/fastqc_data.txt"):
                sect = None
                for line in io.TextIOWrapper(zf.open(name)):
                    line = line.rstrip("\n")
                    if line.startswith(">>END_MODULE"):
                        sect = None
                        continue
                    if line.startswith(">>"):
                        sect = line[2:].split("\t")[0]
                        continue
                    f = line.split("\t")
                    if sect == "Basic Statistics" and len(f) == 2:
                        if f[0] == "Total Sequences":
                            d["total"] = int(f[1])
                        elif f[0] == "%GC":
                            d["gc"] = f[1]
                    elif sect == "Sequence Duplication Levels" and f[0] == "#Total Deduplicated Percentage":
                        d["dedup"] = float(f[1])
                    elif sect == "Adapter Content" and not line.startswith("#"):
                        for v in f[1:]:
                            try:
                                d["adapter_max"] = max(d["adapter_max"], float(v))
                            except ValueError:
                                pass
        res[stem] = d
    return res


def tview_counts(lines, alt, col=20):
    """reads with the ALT base and reads matching the reference in one column of a samtools tview
    -d T -i snapshot (column 21, index 20: the episode starts the window 20 bases before the site,
    and -i hides insertions so columns are reference positions). Line 1 is the ruler, line 2 the
    reference, line 3 the consensus; each later line holds one or more reads."""
    if not lines or len(lines) < 4:
        return None
    n_alt = n_ref = n_other = 0
    for l in lines[3:]:
        if col >= len(l):
            continue
        c = l[col]
        if c.upper() == alt:
            n_alt += 1
        elif c in ".,":
            n_ref += 1
        elif c.strip():
            n_other += 1
    return lines[2][col] if col < len(lines[2]) else "?", n_alt, n_ref, n_other


# ------------------------------------------------------------ placeholder handlers
def m_bed(kind):
    def f(ctx):
        p = ctx.path("resources", "truth", "HG002_v4.2.1_chr20.bed")
        if not os.path.exists(p):
            return None
        for line in open(p):
            if line.startswith(("#", "track", "browser")) or not line.strip():
                continue
            c, s, e = line.split("\t")[:3]
            s, e = int(s), int(e)
            return "`%s:%d-%d`" % (c, s + 1, e) if kind == "region" else fmt_int(e - s)
        return None
    return f


def m_fq_reads(ctx):
    fq = fastqc(ctx)
    if not fq:
        return None
    return "FastQC reads per file: " + "; ".join("%s %s" % (k, fmt_int(v.get("total", 0))) for k, v in sorted(fq.items())) + "."


def m_fq_status(ctx):
    fq = fastqc(ctx)
    if not fq:
        return None
    mods = {}
    for stem, d in sorted(fq.items()):
        for mod, st in d["summary"].items():
            if st != "PASS":
                mods.setdefault(mod, {}).setdefault(st, []).append(stem)
    if not mods:
        return "Every module passes in every file."
    parts = []
    for mod in sorted(mods):
        parts.append("%s: %s" % (mod, "; ".join("%s in %s" % (st, ", ".join(v)) for st, v in sorted(mods[mod].items()))))
    return "Not marked pass: " + ". ".join(parts) + "."


def m_fq_adapter(ctx):
    fq = fastqc(ctx)
    if not fq:
        return None
    st = sorted(set(d["summary"].get("Adapter Content", "?") for d in fq.values()))
    mx = max(fq.items(), key=lambda kv: kv[1]["adapter_max"])
    return ("Adapter Content is %s in all %d files; the largest adapter fraction at any position is %.2f%% (%s)."
            % ("/".join(st), len(fq), mx[1]["adapter_max"], mx[0]))


def m_fq_dup(ctx):
    fq = fastqc(ctx)
    vals = [(k, d["dedup"]) for k, d in sorted(fq.items()) if "dedup" in d]
    if not vals:
        return None
    lo, hi = min(v for _, v in vals), max(v for _, v in vals)
    return ("FastQC estimates that %.1f%% to %.1f%% of reads would remain after removing duplicates "
            "(Total Deduplicated Percentage), that is about %.1f%% to %.1f%% duplicates per file."
            % (lo, hi, 100 - hi, 100 - lo))


def m_insert(ctx):
    parts = []
    for s in SAMPLES:
        sn = stats_sn(ctx, s)
        if "insert size average" in sn:
            parts.append("%s %s bp (standard deviation %s)" % (s, sn["insert size average"], sn.get("insert size standard deviation", "?")))
    return ("Average insert size: " + "; ".join(parts) + ".") if parts else None


def m_cov10(ctx):
    p = ctx.path("results", "qc_alignment", "HG002.mosdepth.global.dist.txt")
    if not os.path.exists(p):
        return None
    for line in open(p):
        f = line.rstrip("\n").split("\t")
        if f[0] == "chr20" and f[1] == "10":
            return "%.1f%%" % (100 * float(f[2]))
    return None


def m_mapq0_view(ctx):
    lines = ctx.block_by_text("04-alignqc", "mapq==0")
    if not lines:
        return None
    first = [l for l in lines if l.strip()]
    return fmt_int(first[0].strip()) if first and first[0].strip().isdigit() else None


def m_tview(needle, alt, ref):
    def f(ctx):
        c = tview_counts(ctx.block_by_text("04-alignqc", needle), alt)
        if c is None:
            return None
        return ("In the snapshot, column 21 has %d reads with %s or %s and %d matching the reference %s "
                "(other characters: %d); the consensus line shows %s." % (c[1], alt, alt.lower(), c[2], ref, c[3], c[0]))
    return f


# ------------------------------------------------------------ Episode 3 (P5 correction 2)
BINS = (2.0, 11.0, 25.0, 37.0)


def fastqc_q10(ctx):
    """file stem -> [(group, 10th percentile)] from the Per base sequence quality module"""
    res = {}
    for z in sorted(glob.glob(ctx.path("results", "qc", "*_fastqc.zip"))):
        stem = os.path.basename(z)[:-len("_fastqc.zip")]
        try:
            zf = zipfile.ZipFile(z)
        except zipfile.BadZipfile:
            continue
        rows, on = [], False
        for name in zf.namelist():
            if not name.endswith("/fastqc_data.txt"):
                continue
            for line in io.TextIOWrapper(zf.open(name)):
                if line.startswith(">>Per base sequence quality"):
                    on = True
                    continue
                if on and line.startswith(">>END_MODULE"):
                    break
                if on and not line.startswith("#"):
                    f = line.rstrip("\n").split("\t")
                    rows.append((f[0], float(f[5])))
        res[stem] = rows
    return res


def m_q10_drop(ctx):
    q = fastqc_q10(ctx)
    if not q:
        return None
    parts = []
    for read in ("R1", "R2"):
        first = []
        for stem, rows in sorted(q.items()):
            if stem.endswith(read):
                low = [g for g, v in rows if v < 37.0]
                if low:
                    first.append(int(low[0].split("-")[0]))
        if first:
            parts.append("%s from position %d to %d" % (read, min(first), max(first)) if min(first) != max(first)
                         else "%s from position %d" % (read, first[0]))
    return "; ".join(parts) + " (first position group whose 10th percentile is below 37, across the three samples)"


def m_q10_between(ctx):
    q = fastqc_q10(ctx)
    vals = sorted(set(v for rows in q.values() for _, v in rows if v not in BINS))
    return ", ".join("%g" % v for v in vals) if vals else ("none" if q else None)


# ------------------------------------------------------------ Episodes 5A and 6 (P5)
def kit_only(ctx, *a):
    return os.path.join(ctx.rec, "kit-only", *a)


def usage_line(ctx, cmd, opt):
    """the line of the recorded bcftools 1.24 usage text that documents option opt"""
    p = kit_only(ctx, "usage", "bcftools-%s.txt" % cmd)
    if not os.path.exists(p):
        return None
    for line in open(p, errors="replace"):
        if re.search(r'(^|[\s,])%s(?=[\s,=\[]|$)' % re.escape(opt), line):
            return line.strip()
    return None


def m_usage(cmd, opt, part="default"):
    """the bracketed default of an option, or (part='line') the whole usage line"""
    def f(ctx):
        line = usage_line(ctx, cmd, opt)
        if line is None or part == "line":
            return line
        m = re.findall(r'\[([^\]]*)\]', line)
        return m[-1] if m else line
    return f


def site_rows(ctx):
    rows = {}
    p = kit_only(ctx, "site_88108.tsv")
    if os.path.exists(p):
        for line in open(p):
            f = line.rstrip("\n").split("\t")
            if f and f[0] and not f[0].startswith("#") and f[0] != "row":
                rows.setdefault(f[0], []).append(f[1:])
    return rows


def m_site_step(row):
    def f(ctx):
        r = site_rows(ctx).get(row)
        if not r or len(r[0]) < 3:
            return None
        return "AD %s; DP %s" % (r[0][1], r[0][2])
    return f


def site_vcf(ctx, pos):
    """{'QUAL', 'INFO_DP', sample: {GT, AD, DP, PL, GQ}} at chr20:pos in the learner's trio.norm"""
    for r in site_rows(ctx).get("vcf", []):
        if r[0] == "chr20:%s" % pos and len(r) >= 3:
            f = r[1:]
            d = {"QUAL": f[0], "INFO_DP": f[1]}
            for i in range(2, len(f) - 5, 6):
                d[f[i]] = dict(zip(("GT", "AD", "DP", "PL", "GQ"), f[i + 1:i + 6]))
            return d
    return None


def m_site(pos, what):
    def f(ctx):
        d = site_vcf(ctx, pos)
        if d is None:
            return None
        if what == "INFO_DP":
            return d["INFO_DP"]
        h = d.get("HG002", {})
        if what == "ALT":
            ad = h.get("AD", "").split(",")
            return ad[1] if len(ad) > 1 else None
        if what == "summary":
            return "`AD` %s, `DP` %s, `PL` %s and `GQ` %s" % (h.get("AD"), h.get("DP"), h.get("PL"), h.get("GQ"))
        return h.get(what)
    return f


def psc(path):
    """bcftools stats PSC lines -> {sample: {ts, tv, indels, missing}}"""
    out = {}
    if os.path.exists(path):
        for line in open(path):
            f = line.rstrip("\n").split("\t")
            if f[0] == "PSC" and len(f) >= 14:
                out[f[2]] = {"ts": int(f[6]), "tv": int(f[7]), "indels": int(f[8]), "missing": int(f[13])}
    return out


def m_counts(ctx):
    p = psc(ctx.path("results", "vcf", "trio.norm.stats.txt"))
    if not p:
        return None
    return "; ".join("%s %s SNVs and %s indels" % (s, fmt_int(v["ts"] + v["tv"]), fmt_int(v["indels"]))
                     for s, v in sorted(p.items())) + "."


def m_missing_norm(ctx):
    p = psc(ctx.path("results", "vcf", "trio.norm.stats.txt"))
    return ", ".join("%s %s" % (s, fmt_int(v["missing"])) for s, v in sorted(p.items())) if p else None


def m_missing_both(ctx):
    a = psc(ctx.path("results", "vcf", "trio.norm.stats.txt"))
    b = psc(kit_only(ctx, "psc.filtered.txt"))
    if not a or not b:
        return None
    return "; ".join("%s %s before, %s after" % (s, fmt_int(a[s]["missing"]), fmt_int(b[s]["missing"]))
                     for s in sorted(a) if s in b)


def console_numbers(ctx, step, needle):
    lines = ctx.block_by_text(step, needle) or []
    return [l.strip() for l in lines if l.strip() and not l.startswith("[W::")]


def m_predict(i):
    def f(ctx):
        n = console_numbers(ctx, "06-filter", "awk '$1 < 30'")
        if len(n) < 3 or not n[i].isdigit():
            return None
        return fmt_int(n[i])
    return f


def m_predict_mask(ctx):
    n = console_numbers(ctx, "06-filter", "awk '$1 < 30'")
    if len(n) < 4:
        return None
    return "low DP or GQ: " + ", ".join(" ".join(x.split()[::-1]) for x in n[3:])


def filter_counts(ctx):
    out = {}
    p = kit_only(ctx, "filter_counts.tsv")
    if os.path.exists(p):
        for line in open(p):
            f = line.rstrip("\n").split("\t")
            if len(f) == 3 and f[0] != "what":
                out[f[0]] = (f[1], f[2])
    return out


def m_records(i):
    def f(ctx):
        r = filter_counts(ctx).get("records")
        return fmt_int(r[i]) if r and r[i].strip().isdigit() else None
    return f


def happy(ctx, sample, truth, calls):
    """summary.csv -> {(Type, Filter): row dict}"""
    p = ctx.path("results", "eval", "%s.%s.%s.summary.csv" % (sample, truth, calls))
    out = {}
    if os.path.exists(p):
        with open(p) as fh:
            for r in csv.DictReader(fh):
                out[(r["Type"], r["Filter"])] = r
    return out


def rp(r):
    return "%.4f / %.4f" % (float(r["METRIC.Recall"]), float(r["METRIC.Precision"]))


def m_tradeoff(ctx):
    n, f = happy(ctx, "HG002", "v5.0q", "norm"), happy(ctx, "HG002", "v5.0q", "filtered")
    try:
        return ("Indels against v5.0q, recall / precision: unfiltered ALL %s; filtered ALL (genotype mask) %s; "
                "filtered PASS (mask and site filters) %s. SNVs: %s; %s; %s." % (
                    rp(n[("INDEL", "ALL")]), rp(f[("INDEL", "ALL")]), rp(f[("INDEL", "PASS")]),
                    rp(n[("SNP", "ALL")]), rp(f[("SNP", "ALL")]), rp(f[("SNP", "PASS")])))
    except KeyError:
        return None


def m_fpgt_snv(ctx):
    r = happy(ctx, "HG002", "v5.0q", "filtered").get(("SNP", "PASS"))
    if not r:
        return None
    gt, fp = int(r["FP.gt"]), int(r["QUERY.FP"])
    return "%s of %s false positives are genotype errors (%.0f%%)" % (fmt_int(gt), fmt_int(fp), 100.0 * gt / fp if fp else 0)


def roc_rows(ctx, truth, typ, calls="norm"):
    """[(QUAL, recall, precision, F1)] of a hap.py ROC table, sorted by QUAL"""
    import gzip
    p = ctx.path("results", "eval", "HG002.%s.%s.roc.Locations.%s.csv.gz" % (truth, calls, typ))
    if not os.path.exists(p):
        return []
    rows = []
    with gzip.open(p, "rt") as fh:
        for r in csv.DictReader(fh):
            try:
                rows.append((float(r["QQ"]), float(r["METRIC.Recall"]), float(r["METRIC.Precision"]),
                             float(r["METRIC.F1_Score"])))
            except (ValueError, KeyError):
                pass
    return sorted(rows)


def roc_at(rows, q):
    for r in rows:
        if r[0] >= q:
            return r
    return None


def m_roc(ctx):
    parts = []
    for typ, name in (("SNP", "SNV"), ("INDEL", "Indel")):
        rows = roc_rows(ctx, "v5.0q", typ)
        a, b = roc_at(rows, 30), roc_at(rows, 225)
        if not a or not b:
            return None
        parts.append("%s recall %.4f to %.4f, precision %.4f to %.4f" % (name, a[1], b[1], a[2], b[2]))
    return "From QUAL 30 to 225 against v5.0q: " + "; ".join(parts) + "."


def f1_peak(ctx, truth, typ="SNP"):
    rows = roc_rows(ctx, truth, typ)
    if not rows:
        return None
    return max(rows, key=lambda r: r[3])


def m_f1_peak(truth):
    def f(ctx):
        r = f1_peak(ctx, truth)
        return "QUAL %.1f (F1 %.4f)" % (r[0], r[3]) if r else None
    return f


def m_split_n(ctx):
    n = console_numbers(ctx, "05a-merge", "POS=$(")
    return str(len(n)) if n else None


# ------------------------------------------------------------ Episodes 7 and 8 (P6)
def step_tasks(ctx, step):
    """sacct entries {job or task id: dict} of the last submission of a step (jobs.tsv)"""
    jobs = read_tsv(os.path.join(ctx.run, "jobs.tsv"))
    ids = [r["jobid"] for r in jobs if r["step"] == step and r["jobid"].isdigit()]
    if not ids:
        return {}
    sacct = parse_sacct(os.path.join(ctx.rec, "sacct.tsv"))
    return dict((k, v) for k, v in sacct.items() if k == ids[-1] or k.startswith(ids[-1] + "_"))


def m_step_wall(step):
    def f(ctx):
        w = [v["elapsed"] for v in step_tasks(ctx, step).values() if v["elapsed"] is not None]
        return ("%d seconds" % round(max(w))) if w else None
    return f


def m_step_rss(step):
    def f(ctx):
        t = list(step_tasks(ctx, step).values())
        r = [v["rss"] for v in t if v["rss"] is not None]
        if not r:
            return None
        cpus = max(int(v["cpus"] or 0) for v in t)
        return "%.2f GiB of the %.1f GiB that %d cores provide" % (max(r), cpus * mem_per_core(ctx), cpus)
    return f


EXAMPLE_NEEDLE = "$2 == 44337201"  # Episode 7, the illustrative missense variant (chr20:44,337,201)


def example_lines(ctx):
    return [l for l in (ctx.block_by_text("07-tables", EXAMPLE_NEEDLE) or []) if l.strip() and not l.startswith("[W::")]


def m_example_af(col):
    def f(ctx):
        for l in example_lines(ctx):
            x = l.split("\t")
            if len(x) >= 10 and x[1] == "44337201":
                try:
                    return "%s (%.1f%%)" % (x[col], 100 * float(x[col]))
                except ValueError:
                    return x[col]
        return None
    return f


def m_example_gt(ctx):
    for l in example_lines(ctx):
        x = l.split("\t")
        if len(x) == 3 and x[0] == "HG002":
            return "`%s`, with `AD` %s (REF and ALT reads)" % (x[1], x[2])
    return None


def m_inspect_truth(site, truth_set):
    """Episode 8: one truth set at an inspection site (records/kit-only/trio/inspection_truth.tsv)"""
    def f(ctx):
        p = kit_only(ctx, "trio", "inspection_truth.tsv")
        if not os.path.exists(p):
            return None
        for line in open(p):
            x = line.rstrip("\n").split("\t")
            if len(x) < 5 or x[1] != site or x[2] != truth_set:
                continue
            if x[3] != "yes":
                return "outside its benchmark regions"
            if x[4] == "none":
                return "homozygous reference (inside its benchmark regions, no record)"
            out = []
            for r in x[4].split(";"):
                pos, al, gt = r.split(":", 2)
                out.append("`%s` at %s with genotype `%s`" % (al, "{:,}".format(int(pos)), gt))
            return "; ".join(out)
        return None
    return f


# Part C decisions (2026-10-14): the bcftools 1.24 header warning is trimmed, identically, from every
# Episode 7 and 8 output placeholder; each episode points back to the Episode 5A callout at its first output
TRIM_PREFIX = ("07-out-", "08-out-")
TRIM_LINE = "[W::bcf_hdr_check_sanity] MQ should be declared as Type=Float"


METRICS = {
    "08-sol-error-truth-hg002": m_inspect_truth("chr20:13604987", "HG002_v5.0q"),
    "08-sol-error-truth-hg003": m_inspect_truth("chr20:13604987", "HG003_v4.2.1"),
    "08-sol-error-truth-hg004": m_inspect_truth("chr20:13604987", "HG004_v4.2.1"),
    "07-sol-example-gt": m_example_gt,
    "07-sol-example-af": m_example_af(8),
    "07-sol-example-af-asj": m_example_af(9),
    "07-sol-annotate-wall": m_step_wall("07-annotate"),
    "07-sol-annotate-rss": m_step_rss("07-annotate"),
    "03-sol-q10-drop": m_q10_drop,
    "03-sol-q10-between": m_q10_between,
    "05a-def-skip-flags": m_usage("mpileup", "--skip-any-set"),
    "05a-def-min-mq": m_usage("mpileup", "--min-MQ"),
    "05a-def-min-bq": m_usage("mpileup", "--min-BQ"),
    "05a-def-min-bq-table": m_usage("mpileup", "--min-BQ"),
    "05a-def-max-depth": m_usage("mpileup", "--max-depth"),
    "05a-def-max-depth-callout": m_usage("mpileup", "--max-depth"),
    "05a-def-prior": m_usage("call", "--prior"),
    "05a-def-ploidy": m_usage("call", "--ploidy", "line"),
    "05a-def-multi-overlaps": m_usage("norm", "--multi-overlaps", "line"),
    "05a-site-step-all": m_site_step("all"),
    "05a-site-step-nodup": m_site_step("nodup"),
    "05a-site-step-proper": m_site_step("proper"),
    "05a-site-step-overlap": m_site_step("overlap"),
    "05a-site-step-bq": m_site_step("bq"),
    "05a-site-step-default": m_site_step("default"),
    "05a-sol-site-ad": m_site(88108, "AD"),
    "05a-sol-site-fmt-dp": m_site(88108, "DP"),
    "05a-sol-site-alt": m_site(88108, "ALT"),
    "05a-sol-site-alt-pl": m_site(88108, "ALT"),
    "05a-sol-site-info-dp": m_site(88108, "INFO_DP"),
    "05a-sol-site-pl": m_site(88108, "PL"),
    "05a-sol-site-gq": m_site(88108, "GQ"),
    "05a-sol-homalt": m_site(85259, "summary"),
    "05a-sol-split-n": m_split_n,
    "05a-sol-counts": m_counts,
    "05a-sol-missing": m_missing_norm,
    "06-sol-predict-qual": m_predict(0),
    "06-sol-predict-highdp": m_predict(1),
    "06-sol-predict-mq": m_predict(2),
    "06-sol-predict-mask": m_predict_mask,
    "06-sol-records-before": m_records(0),
    "06-sol-records-after": m_records(1),
    "06-sol-missing": m_missing_both,
    "06-sol-tradeoff": m_tradeoff,
    "06-sol-fpgt-snv": m_fpgt_snv,
    "06-sol-roc": m_roc,
    "06-sol-f1-peak-v5": m_f1_peak("v5.0q"),
    "02-sol-bed-region": m_bed("region"),
    "02-sol-bed-length": m_bed("length"),
    "03-sol-reads": m_fq_reads,
    "03-sol-status": m_fq_status,
    "03-sol-adapter": m_fq_adapter,
    "03-sol-duplication": m_fq_dup,
    "04-sol-insert": m_insert,
    "04-sol-cov10": m_cov10,
    "04-sol-mapq0-view": m_mapq0_view,
    "04-sol-tview-het": m_tview("-p chr20:88088", "C", "T"),
    "04-sol-tview-homalt": m_tview("-p chr20:85239", "A", "G"),
}

# Figure slot -> glob under records/multiqc_export/ (MultiQC --export PNG names)
FIGURES = {
    "03-fastqc-per-base-quality": "03-qc/multiqc_plots/png/*per_base_sequence_quality*.png",
    "03-fastqc-per-sequence-quality": "03-qc/multiqc_plots/png/*per_sequence_quality_scores*.png",
    "03-fastqc-gc": "03-qc/multiqc_plots/png/*per_sequence_gc_content*.png",
    "03-fastqc-duplication": "03-qc/multiqc_plots/png/*sequence_duplication_levels*.png",
    "03-fastqc-adapter": "03-qc/multiqc_plots/png/*adapter_content*.png",
    "04-multiqc-samtools-alignment": "04-alignqc/multiqc_plots/png/*samtools_alignment_plot*.png",
    "04-multiqc-mosdepth-cumcoverage": "04-alignqc/multiqc_plots/png/*cumcoverage*.png",
    # kit-only: MultiQC 1.23 file names checked locally on the P3 stats files (2026-10-11)
    "06-multiqc-bcftools-qual": "06-filter/multiqc_plots/png/bcftools_stats_vqc_Count_SNP.png",
    "06-multiqc-bcftools-depth": "06-filter/multiqc_plots/png/bcftools_stats_variant_depths.png",
}

# Alignment anchors: (anchors.tsv metric suffix, samtools stats SN key or "mosdepth")
ANCHOR_SOURCES = [("raw_total_sequences", "raw total sequences"), ("reads_mapped", "reads mapped"),
                  ("reads_properly_paired", "reads properly paired"), ("reads_duplicated", "reads duplicated"),
                  ("reads_MQ0", "reads MQ0"), ("mean_depth_chr20", "mosdepth")]


# ------------------------------------------------------------ SLURM records
def hms(s):
    if not s or s in ("Unknown", "INVALID"):
        return None
    d = 0
    if "-" in s:
        d, s = s.split("-", 1)
        d = int(d)
    parts = [float(x) for x in s.split(":")]
    while len(parts) < 3:
        parts.insert(0, 0.0)
    return d * 86400 + parts[0] * 3600 + parts[1] * 60 + parts[2]


def ts(s):
    m = re.match(r'(\d+)-(\d+)-(\d+)T(\d+):(\d+):(\d+)', s or "")
    if not m:
        return None
    y, mo, d, h, mi, se = [int(x) for x in m.groups()]
    import datetime
    return (datetime.datetime(y, mo, d, h, mi, se) - datetime.datetime(1970, 1, 1)).total_seconds()


def gib(s):
    m = re.match(r'([\d.]+)([KMGT]?)', s or "")
    if not m:
        return None
    return float(m.group(1)) * {"": 1.0 / 1024 ** 3, "K": 1.0 / 1024 ** 2, "M": 1.0 / 1024, "G": 1.0, "T": 1024.0}[m.group(2)]


def parse_sacct(p):
    """records/sacct.tsv as collect.sh writes it: sacct -P with a header, fields JobID, JobName,
    State, Submit, Start, End, Elapsed, AllocCPUS, MaxRSS, TotalCPU, ExitCode (the P3 format that
    py/sacct_summary.py also reads)"""
    jobs = {}
    if not os.path.exists(p):
        return jobs
    with open(p) as fh:
        for r in csv.DictReader(fh, delimiter="|"):
            jid = r.get("JobID", "")
            root = jid.split(".")[0]
            e = jobs.setdefault(root, {"elapsed": None, "rss": None, "state": "", "wait": None, "cpus": "", "exit": "",
                                       "start": None, "end": None, "submit": None})
            if "." not in jid:
                st, sb = ts(r.get("Start")), ts(r.get("Submit"))
                e.update(elapsed=hms(r.get("Elapsed")), state=r.get("State", ""), cpus=r.get("AllocCPUS", ""),
                         exit=r.get("ExitCode", ""), wait=(st - sb) if (st is not None and sb is not None) else None,
                         start=st, end=ts(r.get("End")), submit=sb)
            g = gib(r.get("MaxRSS"))
            if g is not None and (e["rss"] is None or g > e["rss"]):
                e["rss"] = g
    return jobs


def mins(s):
    return "%.1f" % (s / 60.0) if s is not None else "?"


# ------------------------------------------------------------ anchors, memory, live load
CALL_ANCHORS = [("records", "number of records:"), ("SNVs", "number of SNPs:"), ("indels", "number of indels:")]
SENTINELS = [("het_snv", "chr20:88108 T>C"), ("homalt_snv", "chr20:85259 G>A"), ("indel", "chr20:86859 T>TTGGTATCTAG"),
             ("trio_inconsistent", "chr20:338577 A>ATG"), ("artifact", "chr20:29070822 T>G")]
USAGE_QUOTED = [("mpileup", "--skip-any-set"), ("mpileup", "--min-MQ"), ("mpileup", "--min-BQ"), ("mpileup", "--max-depth"),
                ("mpileup", "--count-orphans"), ("mpileup", "--ignore-overlaps"), ("mpileup", "--no-BAQ"),
                ("call", "--prior"), ("call", "--ploidy"), ("call", "--multiallelic-caller"), ("call", "--annotate"),
                ("filter", "--mode"), ("filter", "--soft-filter"), ("filter", "--set-GTs"), ("norm", "--multiallelics"),
                ("norm", "--multi-overlaps")]
# Live jobs of Episodes 4, 5A and 6, grouped by what runs at the same time in the episode's flow
LIVE_GROUPS = [("04", [["04-align"], ["04-alignqc"]]),
               ("05A", [["05a-call", "05a-merge"]]),
               ("06", [["06-filter"], ["06-evaluate"], ["06-evalsum"]]),
               ("07", [["07-annotate"], ["07-tables"]]),
               ("08", [["08-trio"]])]
LIVE_LABEL = {"04-align": "align.sh array", "04-alignqc": "alignment QC session", "05a-call": "call.sh array",
              "05a-merge": "merge session (open while calling runs)", "06-filter": "filter session",
              "06-evaluate": "evaluate.sh, task 1 only (live path)", "06-evalsum": "summary (login node)",
              "07-annotate": "annotate.sh (SnpEff, gnomAD)", "07-tables": "annotation tables session",
              "08-trio": "trio session"}
# array tasks a learner submits on the live path (Episode 6: sbatch --array=1 evaluate.sh)
LIVE_ARRAY_TASKS = {"06-evaluate": 1}


def live_cores(s):
    if s is None:
        return 0
    if s["step"] == "06-evalsum":
        return 0  # learners type it on a login node; the kit runs it as a 1-task job
    try:
        cpus = int(s["cpus"])
    except ValueError:
        cpus = int(s["ntasks"] or 1)
    arr = s.get("array", "-")
    n = 1
    m = re.match(r'^(\d+)-(\d+)$', arr or "")
    if m:
        n = int(m.group(2)) - int(m.group(1)) + 1
    n = LIVE_ARRAY_TASKS.get(s["step"], n)
    return cpus * n


def mem_per_core(ctx):
    """GiB per core of the cpu partition: records/sinfo_cpu.txt ('CPUS MEMORY_MB'), else the P3 preflight value"""
    p = os.path.join(ctx.rec, "sinfo_cpu.txt")
    cpus, mb = 128, 257400.0
    if os.path.exists(p):
        f = open(p).read().split()
        try:
            cpus, mb = int(f[0]), float(f[1])
        except (IndexError, ValueError):
            pass
    return mb / 1024.0 / cpus


def stats_sn_tstv(path):
    sn, tstv = {}, None
    if os.path.exists(path):
        for line in open(path):
            f = line.rstrip("\n").split("\t")
            if f[0] == "SN" and len(f) >= 4:
                sn[f[2]] = f[3]
            elif f[0] == "TSTV" and len(f) >= 5 and tstv is None:
                tstv = f[4]
    return sn, tstv


def anchor_rows(ctx):
    rows = []
    for smp in SAMPLES:
        sn = stats_sn(ctx, smp)
        for key, src in ANCHOR_SOURCES:
            rows.append(("%s %s" % (smp, key), mosdepth_mean(ctx, smp) if src == "mosdepth" else sn.get(src)))
    for label, f in (("trio_norm", "trio.norm.stats.txt"), ("trio_filtered", "trio.filtered.stats.txt")):
        sn, tstv = stats_sn_tstv(ctx.path("results", "vcf", f))
        for key, src in CALL_ANCHORS:
            rows.append(("%s %s" % (label, key), sn.get(src)))
        rows.append(("%s tstv" % label, tstv))
    tr = {}
    for r in read_tsv(kit_only(ctx, "metrics_pass", "tstv_regions.tsv")):
        if r.get("set") == "HG002_carried":
            tr[r.get("region")] = r.get("tstv")
    for reg in ("bench_HG002_v4.2.1_in", "bench_HG002_v4.2.1_out"):
        rows.append(("HG002 PASS tstv %s" % reg, tr.get(reg)))
    for sample, truth in (("HG002", "v5.0q"), ("HG002", "v4.2.1"), ("HG003", "v4.2.1"), ("HG004", "v4.2.1")):
        h = happy(ctx, sample, truth, "filtered")
        for typ in ("INDEL", "SNP"):
            r = h.get((typ, "PASS"))
            for m, col in (("recall", "METRIC.Recall"), ("precision", "METRIC.Precision")):
                rows.append(("%s %s %s %s" % (sample, truth, typ, m), r[col] if r else None))
    sent = {}
    for r in read_tsv(kit_only(ctx, "sentinels.tsv")):
        sent[r.get("role")] = r
    for role, label in SENTINELS:
        r = sent.get(role)
        got = None
        if r:
            # per benchmark: "outside" its BED, "absent" (inside, no truth record: 0/0), or the truth GT
            t = next((x for x in (r.get("v5.0q GT"), r.get("v4.2.1 GT")) if x not in (None, "outside")), None)
            if t is None:
                truth = "outside every benchmark region"
            elif t == "absent":
                truth = "0/0"
            else:  # truth sets may be phased: 1|0 is 0/1 here
                truth = "/".join(sorted(t.replace("|", "/").split("/")))
            got = "FILTER %s, HG002 GT %s, truth %s" % (r.get("FILTER"), r.get("HG002 GT"), truth)
        rows.append(("sentinel %s %s" % (role, label), got))
    mend = {}
    p = ctx.path("results", "trio", "mendelian2.txt")
    if os.path.exists(p):
        for line in open(p):
            f = line.rstrip("\n").split("\t")
            if len(f) >= 2 and f[0] in ("nmerr", "ngood"):
                mend[f[0]] = f[1]
    for k in ("nmerr", "ngood"):
        rows.append(("mendelian2 %s" % k, mend.get(k)))
    fun = {}
    p = ctx.path("results", "trio", "funnel.tsv")
    if os.path.exists(p):
        for line in open(p):
            f = line.rstrip("\n").split("\t")
            if len(f) == 2:
                fun[f[0]] = f[1]
    for k in ("pass", "denovo_1_genotype", "denovo_2_evidence", "denovo_3_regions", "denovo_4_impact", "denovo_5_rare",
              "recessive_1_genotype", "recessive_2_evidence", "recessive_3_regions", "recessive_4_impact",
              "recessive_5_rare"):
        rows.append(("funnel %s" % k, fun.get(k)))
    return rows


# Episode 7: annotation counts of the reference-run memo (section 7; not frozen anchors), read from the
# console of the 07-tables blocks (needle: text of the generated block) or from snpEff_summary.csv
ANNOT_MEMO = [("HG002 PASS variants (HG002.ann.vcf.gz records)", "07-tables", "-s HG002 -c 1", 0, "115059"),
              ("HG002 variants with a HIGH prediction", "07-tables", "INFO/ANN~\"[|]HIGH[|]\"' results/annot", 0, "3"),
              ("HG002 protein-altering rows (worst consequence HIGH or MODERATE)", "07-tables",
               "wc -l results/annot/HG002.protein_altering.tsv", 0, "240"),
              ("rare protein-altering, gnomAD overall < 1% or absent", "07-tables", "$9 == \".\"", 0, "20"),
              ("rare protein-altering, gnomAD asj < 1% or absent", "07-tables", "$9 == \".\"", 1, "12")]
SNPEFF_MEMO = [("HIGH", "10"), ("MODERATE", "348"), ("LOW", "542"), ("MODIFIER", "197597")]


def snpeff_impacts(ctx):
    out, on = {}, False
    p = ctx.path("results", "annot", "snpEff_summary.csv")
    if os.path.exists(p):
        for line in open(p, errors="replace"):
            if line.startswith("# Effects by impact"):
                on = True
                continue
            if on and line.startswith("#"):
                break
            f = [x.strip() for x in line.split(",")]
            if on and len(f) >= 2 and f[0] in ("HIGH", "MODERATE", "LOW", "MODIFIER"):
                out[f[0]] = f[1]
    return out


def first_ints(lines):
    out = []
    for l in lines or []:
        m = re.match(r'^\s*(\d+)(\s|$)', l)
        if m and not l.startswith("[W::"):
            out.append(m.group(1))
    return out


def truth_class(r):
    """classes of a de novo candidate's truth status (pipeline/py/report.py, BED checked first since
    2026-10-14; memo section 6, corrected 2026-10-14)"""
    v5, v4, f, m = (r.get("HG002_v5.0q"), r.get("HG002_v4.2.1"), r.get("HG003_v4.2.1"), r.get("HG004_v4.2.1"))
    het = lambda x: x in ("GT=0/1", "GT=1/0")
    if het(v4) and f == "absent_in_bed" and m == "absent_in_bed":
        if het(v5):
            return SUP_BOTH
        if v5 == "outside_bed":
            return SUP_V4
    if v5 == v4 == f == m == "absent_in_bed":
        return "hom-ref in every truth set"
    if v5 == v4 == f == m == "other_allele":
        return "other allele in every truth set"
    return "other combinations"


SUP_BOTH = "truth-supported in both HG002 benchmarks (het in v5.0q and v4.2.1, parents hom-ref)"
SUP_V4 = "truth-supported in HG002 v4.2.1, outside the v5.0q benchmark (parents hom-ref)"
TRUTH_MEMO = {SUP_BOTH: "7", SUP_V4: "27", "hom-ref in every truth set": "2",
              "other allele in every truth set": "2", "other combinations": "3"}


def trio_sections(ctx):
    md, ko = [], os.path.join(ctx.rec, "kit-only", "trio")
    md += ["## Episode 7: annotation counts against the reference-run memo (section 7)", "",
           "| Count | Memo | This run | Result |", "|---|---|---|---|"]
    for label, step, needle, i, want in ANNOT_MEMO:
        n = first_ints(ctx.block_by_text(step, needle))
        got = n[i] if len(n) > i else None
        md.append("| %s | %s | %s | %s |" % (label, want, got or "(missing)", "PASS" if got == want else "**DIFF**"))
    imp = snpeff_impacts(ctx)
    for k, want in SNPEFF_MEMO:
        got = imp.get(k)
        md.append("| SnpEff effects, %s (whole trio file) | %s | %s | %s |" % (k, want, got or "(missing)",
                                                                            "PASS" if got == want else "**DIFF**"))
    md += ["", "A DIFF here is not an anchor failure (these counts are not frozen), but every number Episode 7 quotes "
               "from the memo must then come from this run instead.", ""]

    md += ["## Episode 8: de novo candidates after the region step, truth status (memo section 6)", ""]
    ts = read_tsv(os.path.join(ko, "denovo_3_regions_truth_status.tsv"))
    af = dict(((r["chrom"], r["pos"]), r) for r in read_tsv(os.path.join(ko, "denovo_3_regions.tsv")))
    if not ts:
        md += ["**missing** (records/kit-only/trio/denovo_3_regions_truth_status.tsv)", ""]
    else:
        cls = {}
        for r in ts:
            cls.setdefault(truth_class(r), []).append(r)
        md += ["| Class | Memo | This run | Result |", "|---|---|---|---|"]
        for c, want in sorted(TRUTH_MEMO.items()):
            got = str(len(cls.get(c, [])))
            md.append("| %s | %s | %s | %s |" % (c, want, got, "PASS" if got == want else "**DIFF**"))
        inside = sum(1 for r in ts if r.get("trio_bed") == "absent_in_bed")
        md += ["", "Inside the trio BED: %d of %d (all must be inside after the region step)." % (inside, len(ts)), ""]
        sup = cls.get(SUP_BOTH, []) + cls.get(SUP_V4, [])
        fr = []
        for r in sup:
            a = af.get((r["chrom"], r["pos"]), {}).get("child_alt_fraction", ".")
            if a not in (".", None):
                fr.append(float(a))
        pos = sorted(int(r["pos"]) for r in sup)
        win = max([sum(1 for q in pos if p <= q < p + 50000) for p in pos] or [0])
        snv = sum(1 for r in sup if len(r["ref"]) == 1 and len(r["alt"]) == 1)
        fs = sorted(fr)
        med = (fs[len(fs) // 2] if len(fs) % 2 else (fs[len(fs) // 2 - 1] + fs[len(fs) // 2]) / 2) if fs else None
        md += ["Truth-supported in HG002 v4.2.1 (both classes above, %d; memo, corrected 2026-10-14: 34): %d SNVs and %d "
               "indels (memo 31 and 3); child ALT fraction mean %s, median %s (memo 0.44, 0.46), %d below 0.3 (memo 3); "
               "most in any 50 kb window: %d (memo, corrected 2026-10-14: 10, chr20:11,132,316-11,179,241)."
               % (len(sup), snv, len(sup) - snv, "%.2f" % (sum(fr) / len(fr)) if fr else "?",
                  "%.2f" % med if med is not None else "?", sum(1 for x in fr if x < 0.3), win), ""]
        md += ["| Position | REF>ALT | Class | trio BED | HG002 v5.0q | HG002 v4.2.1 | HG003 | HG004 | Child | Father | Mother | Child ALT fraction |",
               "|---|---|---|---|---|---|---|---|---|---|---|---|"]
        for r in ts:
            a = af.get((r["chrom"], r["pos"]), {})
            md.append("| %s:%s | %s>%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                r["chrom"], r["pos"], r["ref"], r["alt"], truth_class(r).split(" (")[0],
                "inside" if r.get("trio_bed") == "absent_in_bed" else r.get("trio_bed"), r.get("HG002_v5.0q"),
                r.get("HG002_v4.2.1"), r.get("HG003_v4.2.1"), r.get("HG004_v4.2.1"), a.get("child", "?"),
                a.get("father", "?"), a.get("mother", "?"), a.get("child_alt_fraction", "?")))
        md.append("")
    md += ["## Episode 8: benchmark scope of the 41 (records/kit-only/trio/denovo_3_regions_bench_scope.tsv)", "",
           "A truth record counts only inside its own benchmark BED (Part C decision 1, 2026-10-14). Computed before "
           "the kit record existed (memo, corrected 2026-10-14): v5.0q 9, v4.2.1 35, both 8, truth-supported 7.", ""]
    sp = os.path.join(ko, "denovo_3_regions_bench_scope.tsv")
    if os.path.exists(sp):
        md += ["```"] + [l.rstrip("\n")[2:] for l in open(sp) if l.startswith("# ")] + ["```", ""]
        md += ["Inside the HG002 v5.0q BED (last column: truth-supported under the rule):", "", "```"]
        md += ["%s:%s %s>%s %s" % (r["chrom"], r["pos"], r["ref"], r["alt"], r["truth_supported"]) for r in read_tsv(sp)
               if r["HG002_v5.0q_in_bed"] == "yes"] + ["```", ""]
    else:
        md += ["**missing**", ""]
    nm = os.path.join(ko, "inspection_norm_missing.tsv")
    md += ["## Episode 8: norm --multi-overlaps . at the inspection sites (records/kit-only/trio/inspection_norm_missing.tsv)", "",
           "GT per record if norm filled in missing instead of reference (the not-run discussion of Episode 8).", "", "```"]
    md += ([l.rstrip("\n") for l in open(nm)] if os.path.exists(nm) else ["missing (kit run before 2026-10-14 follow-up)"]) + ["```", ""]
    ic = os.path.join(ko, "inspection_calls.tsv")
    md += ["## Episode 8: filtered trio calls at the inspection sites (records/kit-only/trio/inspection_calls.tsv)", "", "```"]
    md += ([l.rstrip("\n") for l in open(ic)] if os.path.exists(ic) else ["missing"]) + ["```", ""]
    pa = read_tsv(os.path.join(ko, "denovo_parent_alt.tsv"))
    if pa:
        md += ["De novo genotype step: %s. Expected 231 (312 - 81) for the first if the GQ and DP parts of the evidence "
               "step remove nothing (the genotype mask already applied them)." % "; ".join(
                   "%s: %s" % (r["what"], r["count"]) for r in pa), ""]
    rec = os.path.join(ko, "recessive_4_impact_annotation.tsv")
    md += ["## Episode 8: the recessive impact-step variants (no gene names)", "",
           "Which part of the rare filter (gnomAD overall and asj below 1%, or absent) removes each.", "",
           "| Position | REF>ALT | Worst consequence | Impact | gnomAD AF | gnomAD AF asj | Fails |", "|---|---|---|---|---|---|---|"]
    if os.path.exists(rec):
        for line in open(rec):
            f = line.rstrip("\n").split("\t")
            if len(f) < 8:
                continue
            fails = []
            for name, v in (("overall", f[6]), ("asj", f[7])):
                try:
                    if float(v) >= 0.01:
                        fails.append("%s >= 1%%" % name)
                except ValueError:
                    pass
            md.append("| %s:%s | %s>%s | %s | %s | %s | %s | %s |" % (f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7],
                                                                    ", ".join(fails) or "**passes (should be 0)**"))
    else:
        md.append("| **missing** | | | | | | |")
    md += ["", "## Episode 8: inspection sites (config.sh INSPECT_SITES)", "", "```"]
    p = os.path.join(ko, "inspection_sites.tsv")
    md.append(open(p).read().rstrip("\n") if os.path.exists(p) else "(missing)")
    md += ["```", "", "The tview text of all three samples is in records/kit-only/trio/tview_inspection_sites.txt; the IGV "
           "batch script for Part B in records/kit-only/igv/snapshots.batch.", ""]
    md += ["## Episode 8: inspection sites in the truth sets (records/kit-only/trio/inspection_truth.tsv)", "", "```"]
    p = os.path.join(ko, "inspection_truth.tsv")
    md.append(open(p).read().rstrip("\n") if os.path.exists(p) else "(missing)")
    md += ["```", "", "## Episode 8: IGV snapshots (igv/run_snapshots.sh, records/igv_snapshots.tsv)", ""]
    p = os.path.join(ctx.rec, "igv_snapshots.tsv")
    if os.path.exists(p):
        rows = [l.rstrip("\n").split("\t") for l in open(p)][1:]
        nf = sum(1 for r in rows if len(r) > 1 and r[1] == "FAIL")
        md += ["%d FAIL, %d WARN; IGV version: %s" % (nf, sum(1 for r in rows if len(r) > 1 and r[1] == "WARN"),
               open(os.path.join(ctx.rec, "igv_version.txt")).read().strip()
               if os.path.exists(os.path.join(ctx.rec, "igv_version.txt")) else "not recorded"), "", "```"]
        md += ["\t".join(r) for r in rows] + ["```", ""]
    else:
        md += ["not run yet (sbatch negishi-run/igv/run_snapshots.sh --run RUN_ID)", ""]
    return md


# ------------------------------------------------------------ the summary
def main():
    if len(sys.argv) != 4:
        sys.exit("usage: summarize.py RUN_DIR KIT_GEN OUT_DIR")
    run, gen, out = sys.argv[1:]
    ctx = Ctx(run, gen)
    os.makedirs(os.path.join(out, "outputs", "blocks"), exist_ok=True)
    md = ["# Episode run kit: %s" % os.path.basename(run.rstrip("/")), ""]
    chk = os.path.join(ctx.rec, "build_kit_check.txt")
    md += ["Learner directory: `%s`" % ctx.W, "",
           "Kit checks at submission: `%s`" % (open(chk).read().strip().splitlines()[-1] if os.path.exists(chk) else "not recorded"), ""]

    # steps
    steps = read_tsv(os.path.join(gen, "steps.tsv"))
    jobs = read_tsv(os.path.join(run, "jobs.tsv"))
    sacct = parse_sacct(os.path.join(ctx.rec, "sacct.tsv"))
    md += ["## Steps", "", "| Step | Kind | Job | State | Wall (min) | Wait (min) | MaxRSS (GiB) | First error |", "|---|---|---|---|---|---|---|---|"]
    step_wall = {}
    for s in steps:
        name = s["step"]
        mk = os.path.join(run, "markers", name + ".done")
        marker = open(mk).read().split()[0] if os.path.exists(mk) else "-"
        ids = [r["jobid"] for r in jobs if r["step"] == name and r["jobid"].isdigit()]
        jid = ids[-1] if ids else "-"
        tasks = sorted((k, v) for k, v in sacct.items() if k == jid or k.startswith(jid + "_"))
        states = sorted(set(v["state"] for _, v in tasks)) or [marker]
        walls = [v["elapsed"] for _, v in tasks if v["elapsed"] is not None]
        waits = [v["wait"] for _, v in tasks if v["wait"] is not None]
        # queue wait only: a dependent job is eligible when its last dependency ends, not at submission
        if s["deps"] != "-":
            dep_ends = []
            for d in s["deps"].split(","):
                for r2 in jobs:
                    if r2["step"] == d and r2["jobid"].isdigit():
                        dep_ends += [v["end"] for k, v in sacct.items()
                                     if (k == r2["jobid"] or k.startswith(r2["jobid"] + "_")) and v["end"] is not None]
            if dep_ends:
                waits = [max(0.0, v["start"] - max(v["submit"], max(dep_ends))) for _, v in tasks
                         if v["start"] is not None and v["submit"] is not None]
        rss = [v["rss"] for _, v in tasks if v["rss"] is not None]
        if s["kind"] == "login":
            tf = os.path.join(ctx.rec, "listings", "%s-seconds.txt" % name)
            if os.path.exists(tf):
                walls = [float(open(tf).read().strip() or 0)]
        step_wall[name] = (max(walls) if walls else None, max(waits) if waits else None)
        first = "-"
        con = os.path.join(ctx.rec, "console", "%s.log" % name)
        if os.path.exists(con):
            for l in open(con, errors="replace"):
                if l.startswith("### KIT-ERR"):
                    first = l.strip()[:160]
                    break
        if first == "-" and s["kind"] == "learner":
            for f in sorted(glob.glob(ctx.path("scripts", "cluster-*.err"))):
                for l in open(f, errors="replace"):
                    if re.search(r'error|fail|abort|killed|denied', l, re.I):
                        first = "%s: %s" % (os.path.basename(f), l.strip()[:140])
                        break
                if first != "-":
                    break
        state = ",".join(states) + ("" if marker in ("-",) else " (marker %s)" % marker)
        md.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
            name, s["kind"], jid + (" x%d" % len([t for t in tasks if "_" in t[0]]) if any("_" in t[0] for t in tasks) else ""),
            state, "/".join(mins(w) for w in walls) or "?", mins(max(waits)) if waits else "-",
            "%.2f" % max(rss) if rss else "-", first.replace("|", "\\|")))
    md.append("")

    # anchors
    anchors = {}
    for r in read_tsv(os.path.join(KIT, "anchors.tsv")):
        anchors[r["metric"]] = r["value"]
    rows = anchor_rows(ctx)
    md += ["## Anchors (exact match with negishi-run/anchors.tsv)", "",
           "Alignment, calling, filtering, hap.py, Mendelian and funnel anchors, and the sentinels.", "",
           "| Anchor | Expected | This run | Result |", "|---|---|---|---|"]
    nbad = 0
    for name, got in rows:
        want = anchors.get(name, "(missing)")
        ok = got is not None and got == want
        nbad += 0 if ok else 1
        md.append("| %s | %s | %s | %s |" % (name, want, got if got is not None else "(missing)", "PASS" if ok else "**FAIL**"))
    md += ["", "Anchors: %s." % ("all %d PASS" % len(rows) if nbad == 0 else
                                 "**%d of %d FAIL: an upstream break, stop and investigate**" % (nbad, len(rows))), ""]

    # Episode 5A multiallelic demo: the staged example was cut from trio.raw.bcf (before norm), so the
    # N_ALT>1 query must print a record and the split query two or more (decision 2026-10-11)
    multi = console_numbers(ctx, "05a-merge", "bcftools query -i 'N_ALT>1' -f '%CHROM")
    split = console_numbers(ctx, "05a-merge", "POS=$(")
    ok = len(multi) >= 1 and len(split) >= 2
    md += ["## Stop check: Episode 5A multiallelic demo", "",
           "N_ALT>1 query: %d line(s); split records at that position: %d line(s). %s" % (
               len(multi), len(split), "PASS" if ok else
               "**FAIL: stop in Part C; the demo has no multiallelic site to show**"), ""]

    # hap.py summaries
    md += ["## hap.py summary.csv (SNV and indel, ALL and PASS)", "",
           "| Sample | Truth | Calls | Type | Filter | TRUTH.TOTAL | TP | FN | QUERY.TOTAL | FP | UNK | FP.gt | Recall | Precision | F1 |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for sample, truth in (("HG002", "v5.0q"), ("HG002", "v4.2.1"), ("HG003", "v4.2.1"), ("HG004", "v4.2.1")):
        for calls in ("norm", "filtered"):
            h = happy(ctx, sample, truth, calls)
            if not h:
                md.append("| %s | %s | %s | **missing** | | | | | | | | | | | |" % (sample, truth, calls))
                continue
            for typ in ("SNP", "INDEL"):
                for flt in ("ALL", "PASS"):
                    r = h.get((typ, flt))
                    if r:
                        md.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                            sample, truth, calls, typ, flt, r["TRUTH.TOTAL"], r["TRUTH.TP"], r["TRUTH.FN"],
                            r["QUERY.TOTAL"], r["QUERY.FP"], r["QUERY.UNK"], r.get("FP.gt", "-"), r["METRIC.Recall"],
                            r["METRIC.Precision"], r["METRIC.F1_Score"]))
    peaks = []
    for truth in ("v5.0q", "v4.2.1"):
        for typ in ("SNP", "INDEL"):
            pk = f1_peak(ctx, truth, typ)
            if pk:
                ties = sorted(r[0] for r in roc_rows(ctx, truth, typ) if r[3] == pk[3])
                peaks.append("%s %s: QUAL %s, F1 %.6f" % (truth, typ, "%.3f" % ties[0] if len(ties) == 1 else
                                                          "%.3f-%.3f (%d tied rows)" % (ties[0], ties[-1], len(ties)), pk[3]))
    md += ["", "F1 peak of the unfiltered calls by QUAL (ROC tables; Episode 6 quotes the reference run: v5.0q SNV "
               "QUAL 117.7, v4.2.1 SNV about QUAL 156-160): " + ("; ".join(peaks) if peaks else "**ROC tables missing**") + ".", ""]

    md += trio_sections(ctx)

    # runtime against front matter
    fm = {r["episode"]: r for r in read_tsv(os.path.join(gen, "frontmatter.tsv"))}
    md += ["## Runtime against front matter", "",
           "Wall time is the longest task of each step; wait is the standby queue wait before it started.", "",
           "| Episode | Steps | Wall (min) | Wait (min) | Front matter (teaching + exercises) | Live minutes (plan 3.3) |",
           "|---|---|---|---|---|---|"]
    for ep in sorted(fm):
        ss = [s["step"] for s in steps if s["episode"] == ep]
        if not ss:
            continue
        wall = sum(step_wall[x][0] or 0 for x in ss)
        wait = sum(step_wall[x][1] or 0 for x in ss)
        md.append("| %s | %s | %s | %s | %s (%s + %s) | %s |" % (ep, ", ".join(ss), mins(wall), mins(wait),
                                                                 fm[ep]["full_min"], fm[ep]["teaching"], fm[ep]["exercises"], fm[ep]["live_min"]))
    md.append("")

    # memory headroom of evaluate.sh
    gib_core = mem_per_core(ctx)
    md += ["## Memory headroom of evaluate.sh", "",
           "Memory per core: %.2f GiB (%s). Stop item (Prompt 05 Part C): any task above 80%% of what its cores provide." % (
               gib_core, "sinfo -p cpu in records/sinfo_cpu.txt" if os.path.exists(os.path.join(ctx.rec, "sinfo_cpu.txt"))
               else "not recorded; Negishi P3 preflight value, 257400 MB for 128 cores"), "",
           "Task N evaluates line N+1 of resources/truth/truth_sets.tsv (two hap.py runs: norm, then filtered). "
           "Node from records/sacct_nodes.tsv. Without RTG_MEM, the same task peaked between 1 and 39 GiB in different runs "
           "(P3 and kit run kit5-2026-10-11; HG002 v5.0q at most 10.2 GiB).", "",
           "| Task | Sample and truth | Node | Cores | Memory of its cores (GiB) | MaxRSS (GiB) | Used | Wall (min) |",
           "|---|---|---|---|---|---|---|---|"]
    truth_lines = []
    tp = ctx.path("resources", "truth", "truth_sets.tsv")
    if os.path.exists(tp):
        truth_lines = [l.rstrip("\n").split("\t") for l in open(tp)]
    nodes = {}
    np_ = os.path.join(ctx.rec, "sacct_nodes.tsv")
    if os.path.exists(np_):
        for l in open(np_):
            f = l.rstrip("\n").split("|")
            if len(f) == 2:
                nodes[f[0]] = f[1]
    for r in jobs:
        if r["step"] != "06-evaluate" or not r["jobid"].isdigit():
            continue
        for k, v in sorted(sacct.items()):
            if k.startswith(r["jobid"] + "_"):
                task = k.split("_", 1)[1]
                t = truth_lines[int(task)] if task.isdigit() and int(task) < len(truth_lines) else []
                label = "%s %s" % (t[0], t[1]) if len(t) >= 2 else "?"
                cores = int(v["cpus"] or 0)
                prov = cores * gib_core
                used = "%.0f%%" % (100 * v["rss"] / prov) if v["rss"] is not None and prov else "?"
                md.append("| %s | %s | %s | %s | %.1f | %s | %s%s | %s |" % (
                    k, label, nodes.get(k, "?"), cores, prov, "%.2f" % v["rss"] if v["rss"] is not None else "?",
                    used, " **over 80%**" if v["rss"] and prov and v["rss"] > 0.8 * prov else "", mins(v["elapsed"])))
    md.append("")
    md += ["## Memory headroom of the annotation and trio steps", "",
           "Stop item (Prompt 06 Part C): an annotation or trio task above 80% of the memory its cores provide. "
           "annotate.sh gives SnpEff a 6 GB Java heap (-Xmx6g) on 4 cores.", "",
           "| Step | Job | Node | Cores | Memory of its cores (GiB) | MaxRSS (GiB) | Used | Wall (min) |",
           "|---|---|---|---|---|---|---|---|"]
    for name in ("07-annotate", "07-tables", "08-trio"):
        for k, v in sorted(step_tasks(ctx, name).items()):
            cores = int(v["cpus"] or 0)
            prov = cores * gib_core
            used = "%.0f%%" % (100 * v["rss"] / prov) if v["rss"] is not None and prov else "?"
            md.append("| %s | %s | %s | %s | %.1f | %s | %s%s | %s |" % (
                name, k, nodes.get(k, "?"), cores, prov, "%.2f" % v["rss"] if v["rss"] is not None else "?", used,
                " **over 80%**" if v["rss"] and prov and v["rss"] > 0.8 * prov else "", mins(v["elapsed"])))
    md.append("")

    # live load: cores per learner for each live job, and for 20 learners
    md += ["## Live load (cores per learner and for 20 learners)", "",
           "Cores = cores per task x array tasks (all tasks of an array can run at once). Jobs in one row group run "
           "at the same time in the episode's flow; the peak is the largest group.", "",
           "| Episode | Job | Cores per learner | 20 learners | Runs alongside |", "|---|---|---|---|---|"]
    st = {x["step"]: x for x in steps}
    for ep, groups in LIVE_GROUPS:
        peak = 0
        for g in groups:
            tot = 0
            for name in g:
                c = live_cores(st.get(name))
                tot += c
                md.append("| %s | %s | %d | %d | %s |" % (ep, LIVE_LABEL.get(name, name), c, 20 * c,
                                                          ", ".join(LIVE_LABEL.get(x, x) for x in g if x != name) or "-"))
            peak = max(peak, tot)
        md.append("| %s | **peak** | **%d** | **%d** | |" % (ep, peak, 20 * peak))
    md.append("")

    # kit-only records
    md += ["## Kit-only records (records/kit-only/; never learner commands)", ""]
    ko = os.path.join(ctx.rec, "kit-only")
    if not os.path.isdir(ko):
        md += ["**missing**", ""]
    else:
        st_p = os.path.join(ko, "status.tsv")
        md += ["Status: %s" % ("all recorded" if not os.path.exists(st_p) else "**" + open(st_p).read().strip().replace("\n", "; ") + "**"), ""]
        for name in ("mapq0_counts.tsv", "site_88108.tsv", "filter_counts.tsv", "filter_values.norm.txt",
                     "filter_values.filtered.txt", "missing_gt.norm.tsv", "missing_gt.filtered.tsv", "mask_reasons.tsv",
                     "sentinels.tsv", "trio/funnel.tsv", "trio/denovo_parent_alt.tsv", "trio/inspection_sites.tsv",
                     "trio/inspection_truth.tsv",
                     "igv/snapshots.batch"):
            f = os.path.join(ko, name)
            md += ["### %s" % name, "", "```", open(f).read().rstrip("\n") if os.path.exists(f) else "(missing)", "```", ""]
        md += ["### bcftools 1.24 usage lines quoted by the episodes", "", "```"]
        for cmd, opt in USAGE_QUOTED:
            md.append("%-8s %-18s %s" % (cmd, opt, usage_line(ctx, cmd, opt) or "(not found)"))
        md += ["```", ""]

    # placeholders
    rows = ["id\tfile\tline\tstatus\tvalue"]
    trimmed = []
    md += ["## Placeholder values", "", "| Placeholder | Where | Value |", "|---|---|---|"]
    for r in read_tsv(os.path.join(gen, "placeholders.tsv")):
        val = None
        if r["kind"] == "block":
            _, step, ref = r["source"].split(":", 2)
            lines = ctx.blocks(step).get(ref)
            if lines is not None and r["id"].startswith(TRIM_PREFIX):
                n_trim = sum(1 for l in lines if l == TRIM_LINE)
                lines = [l for l in lines if l != TRIM_LINE]
                if n_trim:
                    trimmed.append("%s: %d" % (r["id"], n_trim))
            val = "\n".join(lines).rstrip("\n") if lines is not None else None
        else:
            try:
                val = METRICS[r["id"]](ctx)
            except Exception as e:  # report, never stop the summary
                val = None
                r["error"] = repr(e)
        status = "OK" if val not in (None, "") else "MISSING" + (" " + r.get("error", "") if r.get("error") else "")
        with open(os.path.join(out, "outputs", "%s.txt" % r["id"]), "w") as fh:
            fh.write((val or "") + "\n")
        rows.append("%s\t%s\t%s\t%s\t%s" % (r["id"], r["file"], r["line"], status, (val or "").replace("\t", "\\t").replace("\n", "\\n")))
        short = (val or "**%s**" % status).splitlines()
        cell = (short[0][:120] + (" ... (%d lines)" % len(short) if len(short) > 1 else "")) if short else ""
        md.append("| `%s` | %s:%s | %s |" % (r["id"], r["file"], r["line"], cell.replace("|", "\\|")))
    with open(os.path.join(out, "placeholder_values.tsv"), "w") as fh:
        fh.write("\n".join(rows) + "\n")
    md.append("")
    md += ["Trimmed from the Episode 7 and 8 outputs (Part C decisions, 2026-10-14: every line equal to `%s`): %s."
           % (TRIM_LINE, "; ".join(trimmed) or "none"), ""]

    # figures
    md += ["## MultiQC plot exports", "", "| Figure slot | Where | File |", "|---|---|---|"]
    for r in read_tsv(os.path.join(gen, "figures.tsv")):
        hits = sorted(glob.glob(os.path.join(ctx.rec, "multiqc_export", FIGURES.get(r["id"], "-"))))
        md.append("| `%s` | %s:%s | %s |" % (r["id"], r["file"], r["line"],
                                           ", ".join(os.path.relpath(h, ctx.rec) for h in hits) or "**missing**"))
    md.append("")

    # every block's console output
    md += ["## Console output of every block the kit ran", ""]
    for r in read_tsv(os.path.join(gen, "index.tsv")):
        if r["step"] == "-" or r["kind"] not in ("interactive", "extra"):
            continue
        lines = ctx.blocks(r["step"]).get("%s/%s" % (r["page"], r["block"]))
        name = "%s_%s.txt" % (r["page"], r["block"])
        with open(os.path.join(out, "outputs", "blocks", name), "w") as fh:
            fh.write("\n".join(lines or []) + ("\n" if lines else ""))
        md.append("### %s/%s (%s, step %s, %s line %s)" % (r["page"], r["block"], r["kind"], r["step"], r["arg"], r["start"]))
        md.append("")
        if lines is None:
            md += ["Not run (no console record).", ""]
            continue
        shown = lines[:80]
        md += ["```", "\n".join(shown) if shown else "(no output)", "```"]
        if len(lines) > 80:
            md.append("(%d more lines in outputs/blocks/%s)" % (len(lines) - 80, name))
        md.append("")
    with open(os.path.join(out, "SUMMARY.md"), "w") as fh:
        fh.write("\n".join(md) + "\n")
    print("summarize: wrote %s (anchors failing: %d)" % (os.path.join(out, "SUMMARY.md"), nbad))


if __name__ == "__main__":
    main()
