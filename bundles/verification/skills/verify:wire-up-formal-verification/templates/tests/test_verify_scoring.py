"""Toolchain tests: Z3 scoring fixtures and SHACL negative cases."""

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
FIX = ROOT / "tests" / "fixtures" / "decisions"
pytestmark = pytest.mark.skipif(shutil.which("uv") is None, reason="uv not installed")


def run(path: Path) -> subprocess.CompletedProcess:
    cmd = [
        "uv", "run", "--quiet", "--with", "z3-solver", "--with", "rdflib",
        "python", "-I", str(ROOT / "scripts" / "verify_scoring.py"), str(path),
    ]  # fmt: skip
    # fixed argv, no shell; paths are repo-local
    return subprocess.run(  # noqa: S603
        cmd, capture_output=True, text=True, timeout=300
    )


def test_pass_case() -> None:
    r = run(FIX / "pass")
    assert r.returncode == 0, r.stdout + r.stderr
    assert "failures=0" in r.stdout


def test_story_seq_identity() -> None:
    r = run(FIX / "story_seq")
    assert r.returncode == 0, r.stdout + r.stderr
    assert r.stdout.startswith("D9-1\t")


def test_wrong_winner() -> None:
    r = run(FIX / "wrong_winner")
    assert r.returncode == 1
    assert "not max" in r.stdout
    assert "X-O1 beats chosen" in r.stdout


def test_false_robust_reports_counterexample() -> None:
    r = run(FIX / "false_robust")
    assert r.returncode == 1
    assert "declared Robust, Z3 found Fragile" in r.stdout
    assert "counterexample" in r.stdout


def test_false_fragile() -> None:
    r = run(FIX / "false_fragile")
    assert r.returncode == 1
    assert "declared Fragile, Z3 found Robust" in r.stdout


def test_bad_weights() -> None:
    r = run(FIX / "bad_weights")
    assert r.returncode == 1
    assert "weight outside [0,1]" not in r.stdout
    assert "sum" in r.stdout


def test_real_records_pass() -> None:
    r = run(ROOT / "docs" / "decisions")
    assert r.returncode == 0, r.stdout


# ---- SHACL / contract negative cases (built from the sample record) ----------


def shacl(tmp: Path) -> subprocess.CompletedProcess:
    cmd = [
        "uv", "run", "--quiet", "--with", "pyshacl", "--with", "rdflib",
        "python", "-I", str(ROOT / "scripts" / "validate_decisions.py"),
        str(tmp / "docs" / "decisions"),
    ]  # fmt: skip
    return subprocess.run(  # noqa: S603  fixed argv, no shell
        cmd, capture_output=True, text=True, timeout=300
    )


def clone_decisions(tmp: Path) -> Path:
    dst = tmp / "docs" / "decisions"
    shutil.copytree(ROOT / "docs" / "decisions", dst)
    return dst


def test_shacl_passes_on_sample(tmp_path: Path) -> None:
    clone_decisions(tmp_path)
    r = shacl(tmp_path)
    assert r.returncode == 0, r.stdout + r.stderr


def test_duplicate_story_seq(tmp_path: Path) -> None:
    dst = clone_decisions(tmp_path)
    sample = (dst / "d1-01-sample.ttl").read_text()
    # new IRIs, same (story, seq) pair
    (dst / "d1-09-dup.ttl").write_text(sample.replace("D1-1", "D1-9"))
    r = shacl(tmp_path)
    assert r.returncode == 1
    assert "share the same (dec:story, dec:seq)" in r.stdout


def test_missing_contract_file(tmp_path: Path) -> None:
    dst = clone_decisions(tmp_path)
    f = dst / "d1-01-sample.ttl"
    f.write_text(
        f.read_text().replace(
            "dec:touchesInterface false ;",
            'dec:touchesInterface true ; dec:consumer "none" ;'
            ' dec:contract "docs/contracts/nope-v1.pyi" ;',
        )
    )
    r = shacl(tmp_path)
    assert r.returncode == 1
    assert "contract file not found: docs/contracts/nope-v1.pyi" in r.stdout


def test_no_git_history_does_not_crash(tmp_path: Path) -> None:
    clone_decisions(tmp_path)  # tmp_path is not a git repo
    r = subprocess.run(  # noqa: S603
        [str(ROOT / "scripts" / "verify_facts.sh"), str(tmp_path / "docs" / "decisions")],
        capture_output=True, text=True, timeout=300,
    )  # fmt: skip
    assert r.returncode == 0, r.stdout + r.stderr
    assert "no git history" in r.stdout + r.stderr
