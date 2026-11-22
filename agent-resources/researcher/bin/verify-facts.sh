#!/usr/bin/env bash
# Usage: verify-facts.sh [decisions_dir=docs/decisions] [--stamp] [--tests] [--online]
# Runs the dec:probe checks of every non-retired Fact in <dir>/*.ttl.
#   HOLDS    true at dec:atCommit and now
#   DRIFT    true at atCommit, false now (code changed). Blocks unless acknowledged
#   DRIFT-ACK drift acknowledged by dec:driftedTo -> a newer Fact that HOLDS
#   WRONG    false at atCommit (never true), or false now with no atCommit
#   ERROR    probe cannot run (missing file, bad regex, bad TOML key)
#   CONFIRMED-MANUAL  no probe, but dec:confirmedBy (Human/SecondSource) is recorded
#   UNVERIFIABLE  no probe, or probe skipped (Test needs --tests, URL Hash needs --online)
# --stamp  writes dec:atCommit = HEAD into the Fact when its probes pass at HEAD.
# Exit: 0 ok, 1 any WRONG / ERROR / DRIFT, 2 setup error. Needs uv, git.
set -euo pipefail
dir="docs/decisions"; args=()
for a in "$@"; do case "$a" in --*) args+=("$a");; *) dir="$a";; esac; done
command -v uv >/dev/null || { echo "uv not installed" >&2; exit 2; }
[ -f "$dir/context.ttl" ] || { echo "no $dir/context.ttl" >&2; exit 2; }
exec uv run --no-project --quiet --python ">=3.11" --with rdflib python -I - "$dir" "${args[@]+"${args[@]}"}" <<'PY'
import glob, hashlib, os, re, subprocess, sys, tomllib, urllib.request
from rdflib import Graph, Namespace, RDF, URIRef, Literal

DEC = Namespace("urn:researcher:decision#")
d = os.path.abspath(sys.argv[1])
flags = set(sys.argv[2:])
root = os.path.dirname(os.path.dirname(d))

g = Graph()
files = sorted(glob.glob(os.path.join(d, "*.ttl")))
for f in files:
    g.parse(f, format="turtle")


def git(*a, check=True):
    return subprocess.run(["git", "-C", root, *a], capture_output=True, check=check)


def read_now(target):
    with open(os.path.join(root, target), "rb") as fh:
        return fh.read()


def read_at(sha, target):
    r = git("show", f"{sha}:{target}", check=False)
    if r.returncode != 0:
        raise FileNotFoundError(f"{target} not in {sha[:8]}")
    return r.stdout


def run_probe(p, reader):
    """Return True/False, or raise (ERROR). reader(target) -> bytes."""
    kind = g.value(p, DEC.probeKind)
    tgt = str(g.value(p, DEC.probeTarget) or "")
    if kind == DEC.GrepProbe:
        text = reader(tgt).decode("utf-8", "replace")
        n = len(re.findall(str(g.value(p, DEC.probePattern)), text, re.M))
        if g.value(p, DEC.probeExpect) == DEC.Absent:
            return n == 0
        mc = g.value(p, DEC.probeMinCount)
        return n >= (int(mc) if mc is not None else 1)
    if kind == DEC.HashProbe:
        return hashlib.sha256(reader(tgt)).hexdigest() == str(g.value(p, DEC.probeSha256))
    if kind == DEC.KeyProbe:
        data = tomllib.loads(reader(tgt).decode())
        cur = data
        for part in str(g.value(p, DEC.probeKeyPath)).split("."):
            cur = cur[int(part)] if isinstance(cur, list) else cur[part]
        return str(cur) == str(g.value(p, DEC.probeExpected))
    raise ValueError(f"unknown probe kind {kind}")


def now_reader(p):
    tgt = str(g.value(p, DEC.probeTarget) or "")
    if tgt.startswith("https://"):
        if "--online" not in flags:
            raise LookupError("skip-online")
        with urllib.request.urlopen(tgt, timeout=20) as r:  # noqa: S310
            body = r.read()
        return lambda _t: body
    return read_now


def evaluate(fact):
    probes = list(g.objects(fact, DEC.probe))
    if not probes:
        if g.value(fact, DEC.confirmedBy) is not None:
            return "CONFIRMED-MANUAL", f"{str(g.value(fact, DEC.confirmedBy)).rsplit('#',1)[-1]} on {g.value(fact, DEC.confirmedOn)}"
        return "UNVERIFIABLE", "no probe"
    sha = g.value(fact, DEC.atCommit)
    results, notes = [], []
    for p in probes:
        kind = g.value(p, DEC.probeKind)
        if kind == DEC.TestProbe:
            if "--tests" not in flags:
                results.append("SKIP"); notes.append("test needs --tests"); continue
            tid = str(g.value(p, DEC.probeTestId))
            py = os.path.join(root, ".venv", "bin", "python")
            r = subprocess.run([py, "-m", "pytest", "-q", "-x", tid], cwd=root,
                               capture_output=True, text=True, timeout=600)
            results.append("OK" if r.returncode == 0 else "FAILNOW"); continue
        try:
            rd = now_reader(p)
            now = run_probe(p, rd)
        except LookupError:
            results.append("SKIP"); notes.append("url needs --online"); continue
        except Exception as e:
            results.append("ERROR"); notes.append(f"{type(e).__name__}: {e}"); continue
        if sha is None:
            results.append("OK" if now else "FAILNOW")
            continue
        try:
            then = run_probe(p, lambda t, s=str(sha): read_at(s, t))
        except Exception as e:
            results.append("ERROR"); notes.append(f"at commit: {type(e).__name__}: {e}"); continue
        results.append("OK" if (then and now) else "DRIFT" if then else "WRONG")
    note = "; ".join(notes)
    if "ERROR" in results: return "ERROR", note
    if "WRONG" in results: return "WRONG", note
    if "DRIFT" in results: return "DRIFT", note
    if "FAILNOW" in results: return ("WRONG", "fails now, no atCommit") if sha is None else ("DRIFT", note)
    if all(r == "SKIP" for r in results): return "UNVERIFIABLE", note
    return "HOLDS", note


facts = [f for f in g.subjects(RDF.type, DEC.Fact)
         if g.value(f, DEC.itemStatus) != DEC.Retired]
status = {f: evaluate(f) for f in facts}

# acknowledge drift
for f in facts:
    st, note = status[f]
    if st == "DRIFT":
        t = g.value(f, DEC.driftedTo)
        if t is not None and t in status and status[t][0] in ("HOLDS", "UNVERIFIABLE"):
            status[f] = ("DRIFT-ACK", f"-> {str(t).rsplit(':',1)[-1]}")

# stamp
if "--stamp" in flags:
    head = git("rev-parse", "HEAD").stdout.decode().strip()
    for f in facts:
        if g.value(f, DEC.atCommit) is not None or not list(g.objects(f, DEC.probe)):
            continue
        if any(g.value(p, DEC.probeKind) == DEC.TestProbe for p in g.objects(f, DEC.probe)):
            continue
        ok = True
        for p in g.objects(f, DEC.probe):
            try:
                if g.value(p, DEC.probeTarget) and str(g.value(p, DEC.probeTarget)).startswith("https://"):
                    ok = False; break
                ok = ok and run_probe(p, lambda t: read_at(head, t))
            except Exception:
                ok = False
        if not ok:
            continue
        name = str(f).rsplit(":", 1)[-1]
        done = False
        for fp in files:
            txt = open(fp).read()
            new, n = re.subn(rf"^(d:{re.escape(name)} a dec:Fact ;)", rf'\1 dec:atCommit "{head}" ;', txt, count=1, flags=re.M)
            if n:
                open(fp, "w").write(new); done = True; break
        if done:
            g.add((f, DEC.atCommit, Literal(head)))
            status[f] = evaluate(f)
        else:
            status[f] = ("ERROR", "could not stamp (fact not in 'd:NAME a dec:Fact ;' form)")

order = ["WRONG", "ERROR", "DRIFT", "DRIFT-ACK", "UNVERIFIABLE", "CONFIRMED-MANUAL", "HOLDS"]
counts = {k: 0 for k in order}
rows = []
for f, (st, note) in status.items():
    counts[st] += 1
    rows.append((order.index(st), str(f).rsplit(":", 1)[-1], st, note))
for _, name, st, note in sorted(rows, key=lambda r: (r[0], r[1])):
    if st != "HOLDS":
        print(f"{st}\t{name}\t{note}")
print("SUMMARY " + " ".join(f"{k}={v}" for k, v in counts.items()))
sys.exit(1 if counts["WRONG"] or counts["ERROR"] or counts["DRIFT"] else 0)
PY
