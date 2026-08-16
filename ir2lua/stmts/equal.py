"""EqualStmt: continue if a == b, otherwise the block is undefined."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.cx import Emit


@dataclass
class EqualStmt:
    ir_type: ClassVar[str] = "EqualStmt"
    a: Operand
    b: Operand

    @classmethod
    def parse(cls, cx: Emit, stmt: dict[str, Any]) -> EqualStmt:
        return cls(
            cx.operand(stmt.get("a"), "Equal a"),
            cx.operand(stmt.get("b"), "Equal b"),
        )

    def emit(self, cx: Emit, end: str) -> None:
        cx.jump(f"not rt.values_equal({self.a.lua}, {self.b.lua})", end)
