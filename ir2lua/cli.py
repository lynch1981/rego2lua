"""CLI: policy.rego → Lua on stdout."""

from __future__ import annotations

import sys
from pathlib import Path

from ir2lua.opa_plan import OpaError, build_ir_plan
from ir2lua.translate import TranslateError, translate_plan


def compile_rego(rego_path: str) -> str:
    plan, package = build_ir_plan(rego_path)
    return translate_plan(plan, package)


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 1 or args[0] in ("-h", "--help"):
        sys.stderr.write("usage: rego2lua <policy.rego>\n")
        return 0 if args and args[0] in ("-h", "--help") else 2
    path = args[0]
    if not Path(path).is_file():
        sys.stderr.write(f"rego2lua: not a file: {path}\n")
        return 2
    try:
        lua = compile_rego(path)
    except (OpaError, TranslateError) as e:
        sys.stderr.write(f"rego2lua: {e}\n")
        return 1
    sys.stdout.write(lua)
    if not lua.endswith("\n"):
        sys.stdout.write("\n")
    return 0
