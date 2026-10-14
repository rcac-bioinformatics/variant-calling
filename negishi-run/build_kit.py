#!/usr/bin/env python3
"""build_kit.py: generate the episode run kit (Episodes 2-6) from the lesson text, and check it.

Usage:  python3 negishi-run/build_kit.py            check, then write negishi-run/generated/
        python3 negishi-run/build_kit.py --check    check only; also fails if generated/ exists and is stale

Every learner command the kit runs is extracted from the episodes and the setup page; nothing is
hand-copied. Each bash fence carries an HTML comment on the line before it (invisible on the site):

  <!-- kit: script NAME -->        a SLURM script the learner saves or finds in scripts/; must equal
                                    pipeline/learner-scripts/NAME, and the text above must name NAME
  <!-- kit: interactive FILE -->   commands typed in a shell; all blocks for FILE, in page order
                                    (setup page first, then the episodes), must equal
                                    pipeline/learner-scripts/interactive/FILE, ignoring comments
                                    and blank lines
  <!-- kit: extra FILE -->         extra read-only commands typed in the same shell as FILE
                                    (inspection, not in the canonical file); run by the kit, never
                                    allowed to write files
  <!-- kit: submit NAME -->        the commands that submit script NAME
  <!-- kit: not-run REASON -->     shown, never run: download, fallback, laptop, monitoring, reference
  <!-- kit: figure ID -->          (not before a fence) where a MultiQC plot export goes in Part C

Placeholders {{kit:ID}} in the text are filled from the run: an ID containing "-out-" is the
console output of the run block just above it; any other ID needs a handler in py/summarize.py.

Kit checks (the build fails on any): script or interactive text that differs from its canonical
file; an account (--account=, -A) that is not KIT_ACCOUNT in config.sh; any --mem; a URL in a
command that is not in data-prep/sources.tsv; a URL in Episodes 1-4 that learners/reference.md
does not list; front-matter times that differ from the Prompt 04 and 05 tables; a staged script
whose md5 in staged_manifest.tsv differs from its canonical file; a fallback path missing from
staged_results_manifest.tsv; a "Short on time?" callout whose block is not a fallback or whose
results-copy path is not in staged_results_manifest.tsv; an extra block that writes; a bash fence
without a marker.

Output is deterministic (sorted, no timestamps). Python 3.6, standard library only.
"""
import fnmatch
import hashlib
import os
import re
import shlex
import shutil
import sys

KIT = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(KIT)
GEN = os.path.join(KIT, "generated")
LS = os.path.join(ROOT, "pipeline", "learner-scripts")
sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(KIT, "py"))
import summarize  # noqa: E402  (placeholder handlers; checked for coverage below)

# Pages the kit reads, in learner order. Episodes 1, 7 and 8 are scanned by the checks only.
PAGES = [("setup", "learners/setup.md"),
         ("01", "episodes/01-intro-to-variant-calling.Rmd"),
         ("02", "episodes/02-data-and-project-setup.Rmd"),
         ("03", "episodes/03-read-qc.Rmd"),
         ("04", "episodes/04-alignment-and-alignment-qc.Rmd"),
         ("05a", "episodes/05a-calling-with-bcftools.Rmd"),
         ("06", "episodes/06-filtering-and-evaluation.Rmd")]
OTHER_EPISODES = ["episodes/07-annotation.Rmd", "episodes/08-trio-candidate-variants.Rmd"]
# Front matter (Prompt 04 and Prompt 05 tables) and the live minutes of plan section 3.3
TIMES = {"01": (35, 15, 30), "02": (20, 20, 20), "03": (15, 15, 15), "04": (45, 45, 70),
         "05a": (30, 30, 45), "06": (40, 40, 60)}
NOT_RUN_REASONS = ("download", "fallback", "laptop", "monitoring", "reference")
RESULTS_ROOT = "/depot/workshop/data/varcall-workshop_results/"

OPEN_RE = re.compile(r'^(\s*)```\s*([A-Za-z]*)\s*$')
CHUNK_RE = re.compile(r'^\s*```\{')
CLOSE_RE = re.compile(r'^\s*```\s*$')
MARK_RE = re.compile(r'^\s*<!--\s*kit:\s*([a-z-]+)\s*(\S*)\s*-->\s*$')
ANY_MARK_RE = re.compile(r'<!--\s*kit:')
PH_RE = re.compile(r'\{\{kit:([^}]*)\}\}')
PH_ID_RE = re.compile(r'^[a-z0-9][a-z0-9-]*$')
URL_RE = re.compile(r'https?://[^\s)<>`"\']+')
MD_LINK_RE = re.compile(r'\]\((https?://[^)\s]+)\)|<(https?://[^>\s]+)>')

ERRORS = []


def err(msg):
    ERRORS.append(msg)


def rel(p):
    return os.path.relpath(p, ROOT)


def read(path):
    with open(path) as fh:
        return fh.read()


class Block(object):
    def __init__(self, page, nn, lang, start, end, text, kind, arg, indent):
        self.page, self.nn, self.lang, self.start, self.end = page, nn, lang, start, end
        self.text, self.kind, self.arg, self.indent = text, kind, arg, indent
        self.step = "-"

    @property
    def ref(self):
        return "%s/%02d" % (self.page, self.nn)


def parse(page, path):
    """Return (blocks, placeholders[(line, id)], figures[(line, id)], front-matter dict)."""
    lines = read(os.path.join(ROOT, path)).splitlines()
    blocks, phs, figs, fm = [], [], [], {}
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                break
            m = re.match(r'^(teaching|exercises):\s*(\d+)\s*$', lines[i])
            if m:
                fm[m.group(1)] = int(m.group(2))
    pending = None  # (line, kind, arg) of a marker waiting for its fence
    n, i = 0, 0
    while i < len(lines):
        L = lines[i]
        for m in PH_RE.finditer(L):
            phs.append((i + 1, m.group(1)))
        mk = MARK_RE.match(L)
        if mk:
            kind, arg = mk.group(1), mk.group(2)
            if kind == "figure":
                figs.append((i + 1, arg))
            else:
                if pending:
                    err("%s:%d: kit marker without a fence after it" % (path, pending[0]))
                pending = (i + 1, kind, arg)
            i += 1
            continue
        if ANY_MARK_RE.search(L):
            err("%s:%d: malformed kit marker: %s" % (path, i + 1, L.strip()))
        if CHUNK_RE.match(L):  # knitr chunk: only include_graphics() is allowed; skip it
            i += 1
            while i < len(lines) and not CLOSE_RE.match(lines[i]):
                i += 1
            i += 1
            continue
        m = OPEN_RE.match(L)
        if m:
            indent, lang = m.group(1), (m.group(2) or "plain").lower()
            start, body = i + 1, []
            i += 1
            while i < len(lines) and not CLOSE_RE.match(lines[i]):
                body.append(lines[i][len(indent):] if lines[i].startswith(indent) else lines[i])
                for m in PH_RE.finditer(lines[i]):  # output spoilers hold placeholders
                    phs.append((i + 1, m.group(1)))
                i += 1
            n += 1
            text = "\n".join(body) + "\n"
            kind, arg = "-", ""
            if lang == "bash":
                if pending is None:
                    err("%s:%d: bash fence without a kit marker on the line before it" % (path, start))
                else:
                    kind, arg = pending[1], pending[2]
            elif pending is not None:
                err("%s:%d: kit marker before a %s fence (only bash fences are classified)" % (path, pending[0], lang))
            pending = None
            blocks.append(Block(page, n, lang, start, i + 1, text, kind, arg, indent))
            i += 1
            continue
        if L.strip() and pending is not None:
            err("%s:%d: kit marker is not directly above a fence" % (path, pending[0]))
            pending = None
        i += 1
    if pending:
        err("%s:%d: kit marker at the end of the file" % (path, pending[0]))
    return blocks, phs, figs, fm, lines


PARSED = {}
for page, path in PAGES:
    PARSED[page] = (path,) + parse(page, path)
ALL_BLOCKS = [b for page, _ in PAGES for b in PARSED[page][1]]


# ---------------------------------------------------------------- config values
def config_default(var):
    m = re.search(r'^%s=\$\{%s:-([^}]*)\}' % (var, var), read(os.path.join(KIT, "config.sh")), re.M)
    if not m:
        sys.exit("build_kit: %s not found in config.sh" % var)
    return m.group(1)


ACCOUNT = config_default("KIT_ACCOUNT")
PARTITION = config_default("KIT_PARTITION")
QOS = config_default("KIT_QOS")
MULTIQC_MODULE = config_default("MULTIQC_MODULE")


def commands(text):
    """Command lines of a shell text: no comments, no blank lines, trailing space removed."""
    out = []
    for line in text.splitlines():
        s = line.rstrip()
        if not s.strip() or s.strip().startswith("#"):
            continue
        out.append(s)
    return out


# ---------------------------------------------------------------- check: classes
KINDS = ("script", "interactive", "extra", "submit", "not-run")
for b in ALL_BLOCKS:
    if b.lang != "bash" or b.kind == "-":
        continue
    where = "%s:%d" % (PARSED[b.page][0], b.start)
    if b.kind not in KINDS:
        err("%s: unknown kit marker kind '%s'" % (where, b.kind))
    elif b.kind == "not-run" and b.arg not in NOT_RUN_REASONS:
        err("%s: not-run reason '%s' is not one of %s" % (where, b.arg, ", ".join(NOT_RUN_REASONS)))
    elif b.kind in ("script", "submit") and not os.path.isfile(os.path.join(LS, b.arg)):
        err("%s: %s %s: no such file in pipeline/learner-scripts/" % (where, b.kind, b.arg))
    elif b.kind in ("interactive", "extra") and not os.path.isfile(os.path.join(LS, "interactive", b.arg)):
        err("%s: %s %s: no such file in pipeline/learner-scripts/interactive/" % (where, b.kind, b.arg))
    if PH_RE.search(b.text):
        err("%s: placeholder inside a bash fence" % where)

# saved scripts: exact text, and the surrounding text names the file
SCRIPTS = {}
for b in ALL_BLOCKS:
    if b.kind != "script":
        continue
    where = "%s:%d" % (PARSED[b.page][0], b.start)
    canon = read(os.path.join(LS, b.arg))
    if b.text != canon:
        err("%s: script block differs from pipeline/learner-scripts/%s" % (where, b.arg))
    lines = PARSED[b.page][5]
    before = "\n".join(lines[max(0, b.start - 40):b.start - 1])
    if b.arg not in before:
        err("%s: the text before the script block does not name %s" % (where, b.arg))
    if b.arg in SCRIPTS:
        err("%s: script %s is shown twice" % (where, b.arg))
    SCRIPTS[b.arg] = b

# submit blocks: exactly cd into scripts/ and sbatch the script, which the page must show
SUBMITS = {}
for b in ALL_BLOCKS:
    if b.kind != "submit":
        continue
    where = "%s:%d" % (PARSED[b.page][0], b.start)
    want = ["cd $SCRATCH/varcall-workshop/scripts", "sbatch %s" % b.arg]
    if commands(b.text) != want:
        err("%s: submit block must be exactly: %s" % (where, " / ".join(want)))
    if b.arg not in SCRIPTS:
        err("%s: submits %s, but no script block shows it" % (where, b.arg))
    SUBMITS[b.arg] = b

# interactive: concatenation equals the canonical file, ignoring comments and blank lines
INTERACTIVE = {}
for b in ALL_BLOCKS:
    if b.kind in ("interactive", "extra"):
        INTERACTIVE.setdefault(b.arg, []).append(b)
for f, bl in sorted(INTERACTIVE.items()):
    got = [c for b in bl if b.kind == "interactive" for c in commands(b.text)]
    canon = commands(read(os.path.join(LS, "interactive", f)))
    if got != canon:
        k = 0
        while k < min(len(got), len(canon)) and got[k] == canon[k]:
            k += 1
        err("interactive %s: episode blocks differ from the canonical file at command %d:\n"
            "    episodes: %s\n    canonical: %s" % (f, k + 1, got[k] if k < len(got) else "(end)",
                                                    canon[k] if k < len(canon) else "(end)"))

# extra blocks must not write anything or submit jobs. Text inside single or double quotes is
# ignored (awk programs, filter expressions such as 'N_ALT>1'); everything outside is checked.
WRITE_RE = re.compile(r'(^|[\s;|&(])(>|>>|mkdir|rm|mv|cp|ln|touch|tee|sbatch|scancel|rsync|sed\s+-i)(\s|$)|\s-o\s|\s--output[=\s]')
QUOTED_RE = re.compile(r"'[^']*'|\"[^\"]*\"")
for b in ALL_BLOCKS:
    if b.kind == "extra":
        for c in commands(b.text):
            bare = QUOTED_RE.sub("''", c)
            if WRITE_RE.search(bare) or re.search(r'[^2&]>', bare):
                err("%s:%d: extra block writes or submits: %s" % (PARSED[b.page][0], b.start, c))

# ---------------------------------------------------------------- check: accounts, --mem, URLs
ACCT_RE = [re.compile(r'--account[= ]+([^\s`\'"]+)'), re.compile(r'(?<![\w-])-A\s+([^\s`\'"]+)')]
scan = [p for _, p in PAGES] + OTHER_EPISODES
scan += [rel(os.path.join(LS, f)) for f in sorted(os.listdir(LS)) if f.endswith(".sh")]
scan += [rel(os.path.join(LS, "interactive", f)) for f in sorted(os.listdir(os.path.join(LS, "interactive")))]
for p in scan:
    for ln, line in enumerate(read(os.path.join(ROOT, p)).splitlines(), 1):
        for rx in ACCT_RE:
            for m in rx.finditer(line):
                v = m.group(1).rstrip(".,;:)")
                if v != ACCOUNT:
                    err("%s:%d: account '%s' is not KIT_ACCOUNT '%s'" % (p, ln, v, ACCOUNT))
        if "--mem" in line:
            err("%s:%d: --mem is never set on Negishi (request cores instead)" % (p, ln))

SOURCE_URLS = set()
for line in read(os.path.join(ROOT, "data-prep", "sources.tsv")).splitlines()[1:]:
    f = line.split("\t")
    if len(f) > 1 and f[1].startswith("http"):
        SOURCE_URLS.add(f[1])
for b in ALL_BLOCKS:
    if b.lang == "bash":
        for u in URL_RE.findall(b.text):
            if u not in SOURCE_URLS:
                err("%s:%d: URL in a command is not in data-prep/sources.tsv: %s" % (PARSED[b.page][0], b.start, u))
REFERENCE = read(os.path.join(ROOT, "learners", "reference.md"))
for page, path in PAGES:
    if page == "setup":
        continue
    for ln, line in enumerate(PARSED[page][5], 1):
        for m in MD_LINK_RE.finditer(line):
            u = m.group(1) or m.group(2)
            if u not in REFERENCE:
                err("%s:%d: cited URL not listed in learners/reference.md: %s" % (path, ln, u))

# ---------------------------------------------------------------- check: front matter
for ep, (t, e, _) in sorted(TIMES.items()):
    fm = PARSED[ep][4]
    if fm.get("teaching") != t or fm.get("exercises") != e:
        err("%s: front matter teaching/exercises %s/%s, expected %d/%d" % (PARSED[ep][0], fm.get("teaching"),
                                                                           fm.get("exercises"), t, e))


# ---------------------------------------------------------------- check: staged manifests
def manifest(name):
    rows = {}
    for line in read(os.path.join(KIT, name)).splitlines():
        if line.startswith("#") or line.startswith("path\t"):
            continue
        f = line.split("\t")
        if len(f) >= 4:
            rows[f[0]] = (f[1], f[2], f[3])
    return rows


STAGED = manifest("staged_manifest.tsv")
RESULTS = manifest("staged_results_manifest.tsv")
for f in sorted(os.listdir(LS)):
    if not f.endswith(".sh"):
        continue
    md5 = hashlib.md5(open(os.path.join(LS, f), "rb").read()).hexdigest()
    row = STAGED.get("scripts/" + f)
    if row is None:
        err("staged_manifest.tsv has no scripts/%s" % f)
    elif row[2] != md5:
        err("staged_manifest.tsv: scripts/%s md5 %s differs from pipeline/learner-scripts/%s (%s); restage the scripts"
            % (f, row[2], f, md5))
for b in ALL_BLOCKS:
    if b.lang != "bash":
        continue
    for tok in re.findall(re.escape(RESULTS_ROOT) + r'[^\s]+', b.text):
        pat = tok[len(RESULTS_ROOT):]
        if not any(fnmatch.fnmatch(p, pat) for p, r in RESULTS.items() if r[0] == "file"):
            err("%s:%d: no file in staged_results_manifest.tsv matches %s" % (PARSED[b.page][0], b.start, tok))
    if b.kind == "not-run" and b.arg == "fallback" and RESULTS_ROOT not in b.text:
        err("%s:%d: fallback block does not read from %s" % (PARSED[b.page][0], b.start, RESULTS_ROOT))


# "Short on time?" callouts (Prompt 05): every bash block inside one must be a fallback block, the
# callout must hold at least one, and every results-copy path in it (blocks and prose) must match
# a file in staged_results_manifest.tsv
def short_on_time(page):
    """(first line, last line) of each callout whose heading is Short on time?"""
    lines, out, i = PARSED[page][5], [], 0
    while i < len(lines):
        if re.match(r'^:{3,}\s*callout\s*$', lines[i]):
            j = i + 1
            while j < len(lines) and not re.match(r'^:{3,}\s*$', lines[j]):
                j += 1
            if any(re.match(r'^##\s+Short on time\?\s*$', l) for l in lines[i + 1:j]):
                out.append((i + 1, j + 1))
            i = j
        i += 1
    return out


for page, path in PAGES:
    for lo, hi in short_on_time(page):
        inside = [b for b in PARSED[page][1] if lo < b.start < hi]
        if not any(b.kind == "not-run" and b.arg == "fallback" for b in inside):
            err("%s:%d: \"Short on time?\" callout without a fallback block" % (path, lo))
        for b in inside:
            if b.lang == "bash" and not (b.kind == "not-run" and b.arg == "fallback"):
                err("%s:%d: block in a \"Short on time?\" callout is not marked not-run fallback" % (path, b.start))
        for ln in range(lo, hi):
            for tok in re.findall(re.escape(RESULTS_ROOT) + r'[^\s`]+', PARSED[page][5][ln - 1]):
                pat = tok[len(RESULTS_ROOT):]
                if not any(fnmatch.fnmatch(p, pat) for p, r in RESULTS.items() if r[0] == "file"):
                    err("%s:%d: \"Short on time?\" path not in staged_results_manifest.tsv: %s" % (path, ln, tok))


# ---------------------------------------------------------------- the step graph
def sint(block):
    """sinteractive line of a block -> (resources, text without that line)"""
    res, out = None, []
    for line in block.text.splitlines():
        if line.strip().startswith("sinteractive "):
            a = shlex.split(line)
            res = {}
            k = 1
            while k < len(a):
                if a[k] in ("-A", "-q", "-p", "-N", "-n"):
                    res[a[k]] = a[k + 1]
                    k += 2
                    continue
                if a[k].startswith("--time="):
                    res["--time"] = a[k].split("=", 1)[1]
                k += 1
            continue
        out.append(line)
    return res, "\n".join(out) + "\n"


INTERACTIVE_SBATCH_RE = re.compile(r'^(\s*)sbatch --array=(\d+) (\S+)\s*$')


def kit_sbatch(block, text):
    """An interactive block may submit part of a learner script's array (Episode 6 live path:
    sbatch --array=1 evaluate.sh). The kit's learner step has already run the full array, so the
    session only validates the command with sbatch --test-only."""
    out = []
    for line in text.splitlines():
        if re.match(r'^\s*sbatch\b', line):
            m = INTERACTIVE_SBATCH_RE.match(line)
            if not m or m.group(3) not in LEARNER_SCRIPTS:
                err("%s:%d: an interactive block may only run sbatch --array=N SCRIPT for a learner script: %s"
                    % (PARSED[block.page][0], block.start, line.strip()))
            else:
                out.append("%s# KIT: the learner step %s ran the full array; validate the learner's command only"
                           % (m.group(1), LEARNER_SCRIPTS[m.group(3)][0]))
                out.append("%ssbatch --test-only --array=%s %s" % (m.group(1), m.group(2), m.group(3)))
                continue
        out.append(line)
    return "\n".join(out) + "\n"


STEPS = []  # dicts, in submission order


def add_step(name, kind, deps, desc, **kw):
    d = dict(name=name, kind=kind, deps=deps, desc=desc, ntasks=1, time="-", script="-", episode=name.split("-")[0])
    d.update(kw)
    STEPS.append(d)
    return d


# interactive file -> step; learner script -> (step, deps, description)
STEP_OF_FILE = {"02-setup.sh": "02-setup", "03-qc.sh": "03-qc", "04-alignment-qc.sh": "04-alignqc",
                "05-merge.sh": "05a-merge", "06-filter.sh": "06-filter", "06-evaluate-summary.sh": "06-evalsum"}
LEARNER_SCRIPTS = {"align.sh": ("04-align", ["02-setup"], "Episode 4: align.sh array, submitted from scripts/"),
                   "call.sh": ("05a-call", ["04-align"], "Episode 5A: call.sh array (8 regions), submitted from scripts/"),
                   "evaluate.sh": ("06-evaluate", ["06-filter"], "Episode 6: evaluate.sh array (hap.py), submitted from scripts/")}
SESSIONS = {}  # step -> [(block, text)]
for f, step in sorted(STEP_OF_FILE.items()):
    if f not in INTERACTIVE:
        err("no episode blocks for interactive/%s" % f)
        continue
    pieces, res = [], None
    for b in INTERACTIVE[f]:
        r, text = sint(b)
        text = kit_sbatch(b, text)
        if r is not None:
            if res is not None:
                err("%s: two sinteractive lines for %s" % (b.ref, f))
            res = r
        pieces.append((b, text))
        b.step = step
    SESSIONS[step] = (pieces, res)
for b in ALL_BLOCKS:
    if b.kind in ("submit", "script"):
        b.step = LEARNER_SCRIPTS[b.arg][0] if b.arg in LEARNER_SCRIPTS else "-"
for s_ in sorted(LEARNER_SCRIPTS):
    if s_ not in SCRIPTS or s_ not in SUBMITS:
        err("the episodes must show and submit %s" % s_)


def session_step(name, deps, desc):
    """A step for the blocks of one interactive file. With a sinteractive line: a batch job with its
    resources. Without one and without dependencies: the login node, inside submit_all.sh. Without
    one but after a job (06-evalsum, typed on a login node once evaluate.sh has finished): a 1-task
    batch job, because a login step cannot wait for a job."""
    pieces, res = SESSIONS.get(name, ([], None))
    if res is None and not deps:
        return add_step(name, "login", deps, desc)
    if res is None:
        return add_step(name, "session", deps, desc + " (login-node commands, run as a 1-task job)", ntasks=1,
                        nodes=1, time="00:15:00", account=ACCOUNT, qos=QOS, partition=PARTITION)
    for k, v in (("-A", ACCOUNT), ("-q", QOS), ("-p", PARTITION)):
        if res.get(k) != v:
            err("%s: sinteractive %s %s, expected %s" % (name, k, res.get(k), v))
    return add_step(name, "session", deps, desc, ntasks=int(res.get("-n", "1")), nodes=int(res.get("-N", "1")),
                    time=res.get("--time", "00:30:00"), account=res.get("-A"), qos=res.get("-q"),
                    partition=res.get("-p"))


def learner_step(script):
    name, deps, desc = LEARNER_SCRIPTS[script]
    if script not in SCRIPTS:
        return
    hdr = dict(re.findall(r'^#SBATCH\s+--([\w-]+)=(\S+)', SCRIPTS[script].text, re.M))
    add_step(name, "learner", deps, desc, script=script, ntasks=1, time=hdr.get("time", "-"),
             cpus=hdr.get("cpus-per-task", "-"), array=hdr.get("array", "-"))


session_step("02-setup", [], "setup page and Episode 2: copy, link, md5, sample sheet, reference, coordinates (login node)")
session_step("03-qc", ["02-setup"], "Episode 3: FastQC and MultiQC (interactive session as a batch job)")
learner_step("align.sh")
session_step("04-alignqc", ["04-align"], "Episode 4: flagstat, stats, mosdepth, MultiQC, view, flags, tview")
learner_step("call.sh")
session_step("05a-merge", ["05a-call"], "Episode 5A: example VCF, concat, norm, stats (interactive session as a batch job)")
session_step("06-filter", ["05a-merge"], "Episode 6: distributions, filters, Ts/Tv (interactive session as a batch job)")
learner_step("evaluate.sh")
session_step("06-evalsum", ["06-evaluate"], "Episode 6: hap.py summaries and ROC rows")
EXPECTED_STEPS = ["02-setup", "03-qc", "04-align", "04-alignqc", "05a-call", "05a-merge", "06-filter", "06-evaluate",
                  "06-evalsum"]
if [d["name"] for d in STEPS] != EXPECTED_STEPS:
    err("step graph incomplete: %s" % [d["name"] for d in STEPS])

# ---------------------------------------------------------------- placeholders and figures
PLACEHOLDERS = []  # (id, file, line, kind, source)
seen = set()
for page, path in PAGES:
    blocks, phs = PARSED[page][1], PARSED[page][2]
    for line, pid in phs:
        if not PH_ID_RE.match(pid):
            err("%s:%d: bad placeholder id '%s'" % (path, line, pid))
            continue
        if pid in seen:
            err("%s:%d: placeholder id %s used twice" % (path, line, pid))
        seen.add(pid)
        if "-out-" in pid:
            above = [b for b in blocks if b.end < line and b.lang == "bash" and b.kind in ("interactive", "extra")]
            if not above:
                err("%s:%d: %s has no run block above it" % (path, line, pid))
                continue
            b = above[-1]
            PLACEHOLDERS.append((pid, path, line, "block", "console:%s:%s" % (b.step, b.ref)))
        else:
            if pid not in summarize.METRICS:
                err("%s:%d: no handler for %s in py/summarize.py METRICS" % (path, line, pid))
            PLACEHOLDERS.append((pid, path, line, "metric", pid))
FIGURES = []
for page, path in PAGES:
    for line, fid in PARSED[page][3]:
        if fid not in summarize.FIGURES:
            err("%s:%d: no MultiQC export mapping for figure %s in py/summarize.py FIGURES" % (path, line, fid))
        FIGURES.append((fid, path, line))
for page, path in [(None, p) for p in OTHER_EPISODES]:
    if PH_RE.search(read(os.path.join(ROOT, path))):
        err("%s: placeholders outside the setup page and Episodes 2-6 are not filled by this kit" % path)

# ---------------------------------------------------------------- generated files
OUT = {}


def put(relpath, text):
    OUT[relpath] = text if text.endswith("\n") else text + "\n"


def render_session(name, pieces):
    out = ["# GENERATED by build_kit.py from the lesson text; do not edit. Learner shell for step %s." % name,
           "# Run by kit_ep_session (kitrun.sh) in a child bash without set -e, -u or pipefail, as a",
           "# learner's terminal behaves. Every failing command is logged as ### KIT-ERR.",
           "trap 'echo \"### KIT-ERR rc=$? line=$LINENO cmd=$BASH_COMMAND\" >&2' ERR",
           "# KIT EXTRA: Lmod in a non-login shell, as a learner terminal has it",
           "# shellcheck disable=SC1091",
           'type module >/dev/null 2>&1 || { if [ -n "${LMOD_PKG:-}" ]; then source "$LMOD_PKG/init/bash"; '
           'else source /etc/profile.d/lmod.sh; fi; }']
    for b, text in pieces:
        out.append('echo "### KIT-BLOCK %s begin $(date +%%s) %s:%d"' % (b.ref, PARSED[b.page][0], b.start))
        out.append(text.rstrip("\n"))
        out.append('echo "### KIT-BLOCK %s end $(date +%%s)"' % b.ref)
    return "\n".join(out)


EXTRA_AFTER = {
    "03-qc": ['kit_multiqc_export 03-qc results/qc'],
    "04-alignqc": ['kit_multiqc_export 04-alignqc results/qc_alignment results/bam', 'kit_mapq0_counts'],
    "05a-merge": ['kit_bcftools_usage', 'kit_site_counts'],
    "06-filter": ['kit_multiqc_export 06-filter results/vcf', 'kit_filter_counts'],
}


def render_job(d):
    lines = ["#!/bin/bash",
             "# GENERATED by build_kit.py; do not edit. Step %s: %s" % (d["name"], d["desc"]),
             "# Resources come from the episode's sinteractive line; --qos may be overridden by submit_all.sh.",
             "#SBATCH --account=%s" % d["account"],
             "#SBATCH --qos=%s" % d["qos"],
             "#SBATCH --partition=%s" % d["partition"],
             "#SBATCH --nodes=%d" % d["nodes"],
             "#SBATCH --ntasks=%d" % d["ntasks"],
             "#SBATCH --time=%s" % d["time"],
             "#SBATCH --job-name=kit-%s" % d["name"],
             "set -euo pipefail",
             "# shellcheck source=negishi-run/kitrun.sh",
             'source "${KIT_DIR:?KIT_DIR must be exported by submit_all.sh}/kitrun.sh"',
             'kit_ep_begin %s' % d["name"],
             'kit_ep_session %s' % d["name"]]
    for x in EXTRA_AFTER.get(d["name"], []):
        lines.append("# KIT EXTRA (kit records only, never the learner directory)")
        lines.append(x)
    lines.append('kit_ep_end %s' % d["name"])
    return "\n".join(lines)


def build():
    sums = []
    for page, path in PAGES:
        sums.append("%s  %s" % (hashlib.sha256(open(os.path.join(ROOT, path), "rb").read()).hexdigest(), path))
    for f in sorted(os.listdir(LS)):
        p = os.path.join(LS, f)
        if os.path.isfile(p):
            sums.append("%s  %s" % (hashlib.sha256(open(p, "rb").read()).hexdigest(), rel(p)))
    for f in sorted(os.listdir(os.path.join(LS, "interactive"))):
        p = os.path.join(LS, "interactive", f)
        sums.append("%s  %s" % (hashlib.sha256(open(p, "rb").read()).hexdigest(), rel(p)))
    put("sources.sha256", "\n".join(sums))

    idx = ["page\tblock\tlang\tkind\targ\tstart\tend\tstep\tfile"]
    for b in ALL_BLOCKS:
        if b.lang == "bash":
            f = "blocks/%s/%02d.sh" % (b.page, b.nn)
            put(f, b.text)
        else:
            f = "-"
        idx.append("\t".join([b.page, "%02d" % b.nn, b.lang, b.kind, b.arg or "-", str(b.start), str(b.end),
                              b.step, f]))
    put("index.tsv", "\n".join(idx))

    for name, b in sorted(SCRIPTS.items()):
        put("learner-scripts/" + name, b.text)
    for name, b in sorted(SUBMITS.items()):
        put("submit/%s.sh" % name, b.text)
    for d in STEPS:
        if d["kind"] in ("session", "login"):
            put("sessions/%s.sh" % d["name"], render_session(d["name"], SESSIONS[d["name"]][0]))
        if d["kind"] == "session":
            put("jobs/%s.sh" % d["name"], render_job(d))

    st = ["step\tkind\tdeps\tepisode\tntasks\tcpus\tarray\ttime\tscript\tdescription"]
    for d in STEPS:
        st.append("\t".join([d["name"], d["kind"], ",".join(d["deps"]) or "-", d["episode"], str(d["ntasks"]),
                             str(d.get("cpus", d["ntasks"])), str(d.get("array", "-")), d["time"], d["script"],
                             d["desc"]]))
    put("steps.tsv", "\n".join(st))
    g = ["# Step graph (submit_all.sh runs them in this order; deps are afterok)"]
    for d in STEPS:
        where = {"login": "login node", "session": "batch job (interactive block)", "learner": "learner sbatch"}[d["kind"]]
        g.append("%-12s %-30s after: %s" % (d["name"], where, ", ".join(d["deps"]) or "-"))
    put("graph.txt", "\n".join(g))

    ph = ["id\tfile\tline\tkind\tsource"]
    for r in PLACEHOLDERS:
        ph.append("%s\t%s\t%d\t%s\t%s" % r)
    put("placeholders.tsv", "\n".join(ph))
    fg = ["id\tfile\tline\tmultiqc_export"]
    for fid, path, line in FIGURES:
        fg.append("%s\t%s\t%d\t%s" % (fid, path, line, summarize.FIGURES.get(fid, "-")))
    put("figures.tsv", "\n".join(fg))
    fm = ["episode\tteaching\texercises\tfull_min\tlive_min"]
    for ep, (t, e, live) in sorted(TIMES.items()):
        fm.append("%s\t%d\t%d\t%d\t%d" % (ep, t, e, t + e, live))
    put("frontmatter.tsv", "\n".join(fm))
    put("kit.conf", "ACCOUNT=%s\nPARTITION=%s\nQOS=%s\nMULTIQC_MODULE=%s" % (ACCOUNT, PARTITION, QOS, MULTIQC_MODULE))


def main():
    check = "--check" in sys.argv[1:]
    build()
    for rp, text in OUT.items():
        if "--mem" in text:
            err("generated/%s: contains --mem" % rp)
    if ERRORS:
        print("build_kit: %d kit check failure(s):" % len(ERRORS))
        for e in ERRORS:
            print("  FAIL " + e)
        sys.exit(1)
    nblk = sum(1 for b in ALL_BLOCKS if b.lang == "bash")
    summary = ("%d bash blocks (%s), %d steps, %d placeholders, %d figure slots" % (
        nblk, ", ".join("%s %d" % (k, sum(1 for b in ALL_BLOCKS if b.kind == k)) for k in KINDS),
        len(STEPS), len(PLACEHOLDERS), len(FIGURES)))
    if check:
        if os.path.isdir(GEN):
            stale = [r for r, t in sorted(OUT.items())
                     if not os.path.isfile(os.path.join(GEN, r)) or read(os.path.join(GEN, r)) != t]
            have = set()
            for d, _, files in os.walk(GEN):
                for f in files:
                    have.add(os.path.relpath(os.path.join(d, f), GEN))
            stale += ["%s (not built any more)" % r for r in sorted(have - set(OUT))]
            if stale:
                print("build_kit --check: all kit checks pass, but generated/ is stale; rerun without --check:\n  "
                      + "\n  ".join(stale))
                sys.exit(1)
            print("build_kit --check: all kit checks pass; generated/ matches a fresh build. %s" % summary)
        else:
            print("build_kit --check: all kit checks pass (generated/ not built yet). %s" % summary)
        return
    if os.path.isdir(GEN):
        shutil.rmtree(GEN)
    for rp, text in sorted(OUT.items()):
        p = os.path.join(GEN, rp)
        if not os.path.isdir(os.path.dirname(p)):
            os.makedirs(os.path.dirname(p))
        with open(p, "w") as fh:
            fh.write(text)
        if rp.endswith(".sh") and (rp.startswith("jobs/") or rp.startswith("learner-scripts/")):
            os.chmod(p, 0o755)
    print("build_kit: all kit checks pass; wrote %d files to negishi-run/generated/. %s" % (len(OUT), summary))


if __name__ == "__main__":
    main()
