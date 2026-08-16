"""DotStmt: target := source[key]. Undefined if the key is missing."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.cx import Emit


@dataclass
class DotStmt:
    ir_type: ClassVar[str] = "DotStmt"
    target: int
    source: Operand
    key: Operand

    @classmethod
    def parse(cls, cx: Emit, stmt: dict[str, Any]) -> DotStmt:
        return cls(
            cx.local(stmt.get("target"), "Dot target"),
            cx.operand(stmt.get("source"), "Dot source"),
            cx.operand(stmt.get("key"), "Dot key"),
        )

    def emit(self, cx: Emit, end: str) -> None:
        cx.add(f"l{self.target} = rt.dot({self.source.lua}, {self.key.lua})")
        cx.jump(f"rt.is_undef(l{self.target})", end)
        cx.mark_def(self.target)
