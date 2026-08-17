"""IR operands → Lua expressions.

OPA operand: local | bool | string_index.
Some Local-typed fields (IsDefined, Return) are a bare index in OPA 1.18.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any, Literal


class TranslateError(RuntimeError):
    pass


LUA_RESERVED = {
    "and", "break", "do", "else", "elseif", "end", "false", "for",
    "function", "goto", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
}


def lua_string(s: str) -> str:
    out: list[str] = []
    for ch in s:
        o = ord(ch)
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif o < 32:
            out.append("\\%03d" % o)
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def lua_ident(name: str) -> str:
    ident = re.sub(r"[^A-Za-z0-9_]", "_", name)
    if not ident or ident[0].isdigit() or ident in LUA_RESERVED:
        ident = "m_" + ident
    return ident


def _is_int(v: Any) -> bool:
    return isinstance(v, int) and not isinstance(v, bool)


@dataclass(frozen=True)
class Operand:
    kind: Literal["local", "bool", "string"]
    value: int | bool | str

    @property
    def lua(self) -> str:
        if self.kind == "local":
            return f"t{self.value}"
        if self.kind == "bool":
            return "true" if self.value else "false"
        return lua_string(str(self.value))

    @property
    def local_index(self) -> int | None:
        if self.kind == "local":
            return int(self.value)
        return None


def parse_local(raw: Any, what: str) -> int:
    if not _is_int(raw):
        raise TranslateError(f"{what} must be a local index, got {raw!r}")
    return raw


def parse_operand(raw: Any, strings: list[str], what: str) -> Operand:
    if _is_int(raw):
        return Operand("local", raw)
    if not isinstance(raw, dict) or "type" not in raw:
        raise TranslateError(f"{what}: invalid operand {raw!r}")
    typ = raw["type"]
    val = raw.get("value")
    if typ == "local":
        if not _is_int(val):
            raise TranslateError(f"{what}: invalid local operand {raw!r}")
        return Operand("local", val)
    if typ == "bool":
        if not isinstance(val, bool):
            raise TranslateError(f"{what}: invalid bool operand {raw!r}")
        return Operand("bool", val)
    if typ == "string_index":
        if not _is_int(val):
            raise TranslateError(f"{what}: invalid string_index {raw!r}")
        if val < 0 or val >= len(strings):
            raise TranslateError(f"{what}: string_index {val} out of range")
        return Operand("string", strings[val])
    raise TranslateError(f"{what}: unsupported operand type {typ!r}")


def static_strings(plan: dict[str, Any]) -> list[str]:
    raw = (plan.get("static") or {}).get("strings")
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise TranslateError("static.strings must be an array")
    out: list[str] = []
    for i, item in enumerate(raw):
        if not isinstance(item, dict) or "value" not in item:
            raise TranslateError(f"static.strings[{i}] must be an object with value")
        val = item["value"]
        if not isinstance(val, str):
            raise TranslateError(f"static.strings[{i}].value must be a string")
        out.append(val)
    return out
