"""Shell out to OPA: Rego → plan.json."""

from __future__ import annotations

import json
import subprocess
import tarfile
import tempfile
from pathlib import Path
from typing import Any


class OpaError(RuntimeError):
    pass


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError as e:
        raise OpaError("opa not found on PATH") from e


def read_package(rego_path: str | Path) -> str:
    """Return the package path without the leading ``data.`` (e.g. ``foo``)."""
    path = str(rego_path)
    proc = _run(["opa", "parse", "--format=json", path])
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip()
        raise OpaError(f"opa parse failed (exit {proc.returncode}): {detail}")
    try:
        ast = json.loads(proc.stdout)
    except json.JSONDecodeError as e:
        raise OpaError(f"opa parse produced invalid JSON: {e}") from e

    parts: list[str] = []
    for node in (ast.get("package") or {}).get("path") or []:
        if not isinstance(node, dict):
            continue
        value = node.get("value")
        ntype = node.get("type")
        if ntype == "var" and value == "data":
            continue
        if ntype in ("string", "var") and isinstance(value, str):
            parts.append(value)
    if not parts:
        raise OpaError(f"could not determine package in {path}")
    return ".".join(parts)


def extract_plan_json(bundle_path: str | Path) -> dict[str, Any]:
    with tarfile.open(bundle_path, "r:gz") as tar:
        for member in tar.getmembers():
            name = member.name.lstrip("./")
            if name == "plan.json" or name.endswith("/plan.json"):
                fh = tar.extractfile(member)
                if fh is None:
                    continue
                return json.loads(fh.read().decode("utf-8"))
    raise OpaError("plan.json not found in opa bundle")


def compile_plan(rego_path: str | Path) -> tuple[dict[str, Any], str]:
    """Build a package-level plan IR. Returns ``(plan, package)``."""
    pkg = read_package(rego_path)
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
        plan = extract_plan_json(bundle)
    return plan, pkg
