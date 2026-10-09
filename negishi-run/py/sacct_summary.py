#!/usr/bin/env python3
"""Summarize records/sacct.tsv: queue wait, elapsed, CPU efficiency and MaxRSS per job step.

Usage: python3 sacct_summary.py records/sacct.tsv > records/sacct_summary.tsv
Runs on Python 3.6 (the Negishi system python). Every row is labeled "pilot".
"""
import csv
import sys
from datetime import datetime


def seconds(t):
    """[D-]HH:MM:SS[.fff] or MM:SS[.fff] -> seconds."""
    if not t or t in ("Unknown", "INVALID"):
        return None
    days = 0
    if "-" in t:
        d, t = t.split("-", 1)
        days = int(d)
    parts = [float(p) for p in t.split(":")]
    while len(parts) < 3:
        parts.insert(0, 0.0)
    h, m, s = parts
    return days * 86400 + h * 3600 + m * 60 + s


def gib(rss):
    """sacct MaxRSS (e.g. 12345K, 1.5G) -> GiB."""
    if not rss:
        return None
    units = {"K": 1 / 1048576.0, "M": 1 / 1024.0, "G": 1.0, "T": 1024.0}
    if rss[-1] in units:
        return float(rss[:-1]) * units[rss[-1]]
    return float(rss) / 1073741824.0


def when(t):
    try:
        return datetime.strptime(t, "%Y-%m-%dT%H:%M:%S")
    except (TypeError, ValueError):
        return None


def main(path):
    rows = list(csv.DictReader(open(path), delimiter="|"))
    jobs = {}
    for r in rows:
        jid = r["JobID"]
        base = jid.split(".")[0]
        if "." not in jid:
            jobs[base] = dict(r)
            jobs[base]["_rss"] = gib(r.get("MaxRSS", ""))
        elif base in jobs:
            rss = gib(r.get("MaxRSS", ""))
            if rss is not None and (jobs[base]["_rss"] is None or rss > jobs[base]["_rss"]):
                jobs[base]["_rss"] = rss
    out = csv.writer(sys.stdout, delimiter="\t", lineterminator="\n")
    out.writerow(["jobid", "name", "state", "cpus", "wait_s", "elapsed_s", "cpu_efficiency", "maxrss_gib", "label"])
    for jid, r in jobs.items():
        sub, start = when(r.get("Submit")), when(r.get("Start"))
        wait = (start - sub).total_seconds() if sub and start else None
        el = seconds(r.get("Elapsed"))
        cpu = seconds(r.get("TotalCPU"))
        n = int(r.get("AllocCPUS") or 0)
        eff = cpu / (el * n) if el and n and cpu is not None else None
        rss = r["_rss"]
        out.writerow([jid, r.get("JobName", ""), r.get("State", ""), n,
                      "" if wait is None else int(wait), "" if el is None else int(el),
                      "" if eff is None else "%.2f" % eff, "" if rss is None else "%.2f" % rss, "pilot"])


if __name__ == "__main__":
    main(sys.argv[1])
