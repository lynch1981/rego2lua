"""ReturnLocalStmt: leave the function with this local."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.cx import Emit


@dataclass
class ReturnLocalStmt:
    ir_type: ClassVar[str] = "ReturnLocalStmt"
    source: Operand

    @classmethod
    def parse(cls, cx: Emit, stmt: dict[str, Any]) -> ReturnLocalStmt:
        return cls(cx.operand(stmt.get("source"), "ReturnLocal source"))

    def emit(self, cx: Emit, _end: str) -> None:
        cx.add(f"return {self.source.lua}")
        cx.mark_return()
