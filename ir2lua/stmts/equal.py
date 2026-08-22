
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
            ctx.resolve_operand(stmt.get("a"), "Equal a"),
            ctx.resolve_operand(stmt.get("b"), "Equal b"),
        )

    def emit(self, ctx: Emit, label: str) -> None:
        ctx.jump_if(f"not rt.values_equal({self.a.lua}, {self.b.lua})", label)


@dataclass
class NotEqualStmt:
    ir_type: ClassVar[str] = "NotEqualStmt"
    a: Operand
    b: Operand

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> NotEqualStmt:
        return cls(
            ctx.resolve_operand(stmt.get("a"), "NotEqual a"),
            ctx.resolve_operand(stmt.get("b"), "NotEqual b"),
        )

    def emit(self, ctx: Emit, label: str) -> None:
        ctx.jump_if(f"rt.values_equal({self.a.lua}, {self.b.lua})", label)
