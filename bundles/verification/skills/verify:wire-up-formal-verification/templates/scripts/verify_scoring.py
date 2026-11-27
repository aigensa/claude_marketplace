"""Check decision scoring with Z3 (exact rationals).

Usage: uv run --with z3-solver --with rdflib python -I scripts/verify_scoring.py [dir]
For each non-Rejected decision with criteria: weights valid, chosen option wins,
declared sensitivity matches a +-20% per-weight perturbation search.
Exit 0 ok, 1 any failure, 2 setup error.
"""

import glob
import os
import sys
from fractions import Fraction

from rdflib import RDF, Graph, Namespace
from z3 import And, Or, Real, RealVal, Solver, Sum, sat

DEC = Namespace("urn:researcher:decision#")
PERTURB = Fraction(1, 5)
TOL = Fraction(1, 1000)


def rv(x: Fraction):
    return RealVal(f"{x.numerator}/{x.denominator}")


def frac(lit) -> Fraction:
    return Fraction(str(lit))  # exact from the decimal lexical form


def short(n) -> str:
    return str(n).rsplit(":", 1)[-1].rsplit("#", 1)[-1]


def ident(g: Graph, dec):
    """Sort key and label: dec:number (legacy) or dec:story + dec:seq; IRI fallback."""
    n = g.value(dec, DEC.number)
    if n is not None:
        return (0, int(n), 0), f"D{int(n):04d}"
    s, q = g.value(dec, DEC.story), g.value(dec, DEC.seq)
    if s is not None and q is not None:
        return (1, int(s), int(q)), f"D{int(s)}-{int(q)}"
    return (2, 0, 0), short(dec)


def load(d: str) -> Graph:
    g = Graph()
    for f in sorted(glob.glob(os.path.join(d, "*.ttl"))):
        g.parse(f, format="turtle")
    return g


def check_weights(w: dict, scores: dict, survivors: list, crit: list) -> list:
    errs = []
    s = Solver()
    ws = {k: Real(f"w_{i}") for i, k in enumerate(crit)}
    for k in crit:
        s.add(ws[k] == rv(w[k]))
    bad = Or(*[Or(ws[k] < 0, ws[k] > 1) for k in crit])
    s.push()
    s.add(bad)
    if s.check() == sat:
        errs.append("weight outside [0,1]")
    s.pop()
    s.push()
    total = Sum(*ws.values())
    s.add(Or(total - 1 > rv(TOL), 1 - total > rv(TOL)))
    if s.check() == sat:
        errs.append(f"weights sum {float(sum(w.values())):.4f} != 1 (+-0.001)")
    s.pop()
    for o in survivors:
        for k in crit:
            v = scores.get((o, k), [])
            if len(v) != 1:
                errs.append(f"{short(o)}/{short(k)}: {len(v)} scores")
            elif not 0 <= v[0] <= 5:
                errs.append(f"{short(o)}/{short(k)}: score {v[0]} out of 0..5")
    return errs


def winner(w, scores, survivors, crit, chosen):
    """Return (others strictly better [(opt, margin)], tied options)."""
    tot = {o: sum(w[k] * scores[(o, k)][0] for k in crit) for o in survivors}
    s = Solver()
    ct = rv(tot[chosen])
    better, ties = [], []
    for o in survivors:
        if o == chosen:
            continue
        s.push()
        s.add(rv(tot[o]) > ct)
        if s.check() == sat:
            better.append((o, tot[o] - tot[chosen]))
        s.pop()
        s.push()
        s.add(rv(tot[o]) == ct)
        if s.check() == sat:
            ties.append(o)
        s.pop()
    return better, ties


def find_flip(w, scores, survivors, crit, chosen):
    """Weights in [0.8w, 1.2w] per criterion (renormalised, so compare raw sums).
    Return (option, normalised weights) of a strict flip, else None."""
    for o in survivors:
        if o == chosen:
            continue
        x = {k: Real(f"x_{i}") for i, k in enumerate(crit)}
        s = Solver()
        for k in crit:
            s.add(And(x[k] >= rv(w[k] * (1 - PERTURB)), x[k] <= rv(w[k] * (1 + PERTURB))))
        diff = Sum(*[x[k] * rv(Fraction(scores[(o, k)][0] - scores[(chosen, k)][0])) for k in crit])
        s.add(diff > 0)
        if s.check() == sat:
            m = s.model()
            raw = {k: Fraction(str(m.eval(x[k], model_completion=True).as_fraction())) for k in crit}
            tot = sum(raw.values())
            return o, {short(k): float(raw[k] / tot) for k in crit}
    return None


def find_flip_single(w, scores, survivors, crit, chosen):
    """Records' convention: one weight at a time x(1 +- 20%), others fixed, renormalised
    (scale-invariant, so raw sums are compared). Return (option, weights) or None."""
    for k0 in crit:
        for sign in (-1, 1):
            raw = {k: w[k] * (1 + sign * PERTURB) if k == k0 else w[k] for k in crit}
            for o in survivors:
                if o == chosen:
                    continue
                s = Solver()
                d = sum(raw[k] * (scores[(o, k)][0] - scores[(chosen, k)][0]) for k in crit)
                s.add(rv(d) > 0)
                if s.check() == sat:
                    tot = sum(raw.values())
                    return o, {short(k): float(raw[k] / tot) for k in crit}
    return None


def check(g: Graph):
    rows, fails = [], []
    for dec in sorted(g.subjects(RDF.type, DEC.Decision), key=lambda x: ident(g, x)):
        name = ident(g, dec)[1]
        if g.value(dec, DEC.status) == DEC.Rejected:
            rows.append((name, "skip", "Rejected", "-"))
            continue
        crit = sorted(g.objects(dec, DEC.criterion), key=str)
        chosen = g.value(dec, DEC.chosen)
        if not crit or chosen is None:
            rows.append((name, "skip", "no criteria", "-"))
            continue
        opts = list(g.objects(dec, DEC.option))
        survivors = [o for o in opts if g.value(o, DEC.eliminatedBy) is None]
        w = {k: frac(g.value(k, DEC.weight)) for k in crit}
        scores = {}
        for sc in g.objects(dec, DEC.score):
            key = (g.value(sc, DEC.scoreOption), g.value(sc, DEC.scoreCriterion))
            scores.setdefault(key, []).append(int(g.value(sc, DEC.value)))
        errs = check_weights(w, scores, survivors, crit)
        if errs:
            fails += [f"{name}: {e}" for e in errs]
            rows.append((name, "BAD-DATA", "; ".join(errs), "-"))
            continue
        better, ties = winner(w, scores, survivors, crit, chosen)
        wres = "ok"
        if better:
            b = max(better, key=lambda t: t[1])
            wres = f"WRONG: {short(b[0])} beats chosen by {float(b[1]):.4f}"
            fails.append(f"{name}: chosen {short(chosen)} not max; {wres}")
        elif ties:
            wres = "ok (tie with " + ",".join(short(t) for t in ties) + ")"
        declared = short(g.value(dec, DEC.sensitivity))
        multi = len(survivors) > 1
        flip = find_flip_single(w, scores, survivors, crit, chosen) if multi else None
        joint = find_flip(w, scores, survivors, crit, chosen) if multi else None
        found = "Fragile" if flip else "Robust"
        sres = f"{declared} / found {found}"
        if joint and not flip:
            sres += f" (joint +-20% flip exists: {short(joint[0])} at {joint[1]})"
        if declared == "NotApplicable":
            sres += " (info)"
        elif declared != found:
            ce = f" counterexample: {short(flip[0])} wins at {flip[1]}" if flip else ""
            fails.append(f"{name}: declared {declared}, Z3 found {found}.{ce}")
            sres += " MISMATCH" + ce
        rows.append((name, wres, sres, f"{sum(1 for o in opts if o not in survivors)} elim, not machine-readable"))
    return rows, fails


def main(d: str) -> int:
    if not glob.glob(os.path.join(d, "*.ttl")):
        print(f"no *.ttl in {d}", file=sys.stderr)
        return 2
    rows, fails = check(load(d))
    for r in rows:
        print("\t".join(r))
    print(f"SUMMARY decisions={len(rows)} failures={len(fails)}")
    for f in fails:
        print("FAIL", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "docs/decisions"))
