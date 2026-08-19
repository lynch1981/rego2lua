
# Copyright (c) 2026, Lei Meng

"""EqualStmt: continue if a == b, otherwise the block is undefined."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.ctx import Emit


@dataclass
class EqualStmt:
    ir_type: ClassVar[str] = "EqualStmt"
    a: Operand
    b: Operand

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> EqualStmt:
        return cls(
            ctx.operand(stmt.get("a"), "Equal a"),
            ctx.operand(stmt.get("b"), "Equal b"),
        )

    def emit(self, ctx: Emit, end: str) -> None:
        ctx.jump(f"not rt.values_equal({self.a.lua}, {self.b.lua})", end)
