
# Copyright (c) 2026, Lei Meng

"""ReturnLocalStmt: leave the function with this local."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.ctx import Emit


@dataclass
class ReturnLocalStmt:
    ir_type: ClassVar[str] = "ReturnLocalStmt"
    source: Operand

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> ReturnLocalStmt:
        return cls(ctx.resolve_operand(stmt.get("source"), "ReturnLocal source"))

    def emit(self, ctx: Emit, _label: str) -> None:
        ctx.add_line(f"return {self.source.lua}")
        ctx.mark_return()
