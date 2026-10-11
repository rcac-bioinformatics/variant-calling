#!/usr/bin/env python3
"""summarize.py RUN_DIR KIT_GEN OUT_DIR

Reads one episode-kit run (submit_all.sh) and writes into OUT_DIR:
  SUMMARY.md              per-step status with the first error of any failure; the alignment anchors
                          against negishi-run/anchors.tsv (exact match); runtime against front matter;
                          the value of every {{kit:...}} placeholder; MultiQC plot exports; and the
                          console output of every block the kit ran
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


METRICS = {
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
    md += ["## Alignment anchors (exact match with negishi-run/anchors.tsv)", "",
           "| Anchor | Expected | This run | Result |", "|---|---|---|---|"]
    nbad = 0
    for s in SAMPLES:
        sn = stats_sn(ctx, s)
        for key, src in ANCHOR_SOURCES:
            name = "%s %s" % (s, key)
            want = anchors.get(name, "(missing)")
            got = mosdepth_mean(ctx, s) if src == "mosdepth" else sn.get(src)
            ok = got is not None and got == want
            nbad += 0 if ok else 1
            md.append("| %s | %s | %s | %s |" % (name, want, got if got is not None else "(missing)", "PASS" if ok else "**FAIL**"))
    md += ["", "Anchors: %s." % ("all 18 PASS" if nbad == 0 else "**%d FAIL: an upstream break, stop and investigate**" % nbad), ""]

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

    # placeholders
    rows = ["id\tfile\tline\tstatus\tvalue"]
    md += ["## Placeholder values", "", "| Placeholder | Where | Value |", "|---|---|---|"]
    for r in read_tsv(os.path.join(gen, "placeholders.tsv")):
        val = None
        if r["kind"] == "block":
            _, step, ref = r["source"].split(":", 2)
            lines = ctx.blocks(step).get(ref)
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
