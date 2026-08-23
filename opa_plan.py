
# Copyright (c) 2026, Lei Meng

"""Shell out to OPA: ``opa check --strict``, then ``opa build -t plan`` → plan.json."""

from __future__ import annotations

import json
import re
import subprocess
import tarfile
import tempfile
from pathlib import Path
from typing import Any

_PACKAGE_RE = re.compile(r"^\s*package\s+([A-Za-z_][\w.]*)")


class OpaError(RuntimeError):
    pass


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError as e:
        raise OpaError("opa not found on PATH") from e


def read_package_name(rego_path: str | Path) -> str:
    """Return the package name (e.g. ``foo`` or ``foo.bar``)."""
    path = Path(rego_path)
    for line in path.read_text(encoding="utf-8").splitlines():
        m = _PACKAGE_RE.match(line)
        if m:
            return m.group(1)
    raise OpaError(f"no package line in {path}")


def extract_plan_json(
    bundle_path: str | Path,
    dest: str | Path | None = None,
) -> dict[str, Any]:
    with tarfile.open(bundle_path, "r:gz") as tar:
        for member in tar.getmembers():
            name = member.name.lstrip("./")
            if name == "plan.json" or name.endswith("/plan.json"):
                fh = tar.extractfile(member)
                if fh is None:
                    continue
                raw = fh.read()
                if dest is not None:
                    Path(dest).write_bytes(raw)
                return json.loads(raw.decode("utf-8"))
    raise OpaError("plan.json not found in opa bundle")


def check_rego(rego_path: str | Path) -> None:
    """Parse and compile ``rego_path`` with ``opa check --strict``."""
    proc = _run(["opa", "check", "--strict", str(rego_path)])
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip()
        raise OpaError(f"opa check failed (exit {proc.returncode}): {detail}")


def build_ir_plan(
    rego_path: str | Path,
    dump_plan: str | Path | None = None,
) -> tuple[dict[str, Any], str]:
    """Check Rego, then build an OPA IR plan. Returns ``(plan, package)``."""
    check_rego(rego_path)
    pkg = read_package_name(rego_path)
    entry = pkg.replace(".", "/")
    with tempfile.TemporaryDirectory(prefix="rego2lua-") as tmp:
        bundle = Path(tmp) / "bundle.tar.gz"
        proc = _run(
            [
                "opa",
                "build",
                "-t",
                "plan",
                "-e",
                entry,
                str(rego_path),
                "-o",
                str(bundle),
            ]
        )
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout or "").strip()
            raise OpaError(f"opa build failed (exit {proc.returncode}): {detail}")
        plan = extract_plan_json(bundle, dest=dump_plan)
    return plan, pkg
