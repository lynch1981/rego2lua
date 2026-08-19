
# Copyright (c) 2026, Lei Meng

"""DotStmt: target := source[key]. Undefined if the key is missing."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.ctx import Emit


@dataclass
class DotStmt:
    ir_type: ClassVar[str] = "DotStmt"
    target: int
    source: Operand
    key: Operand

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> DotStmt:
        return cls(
            ctx.local(stmt.get("target"), "Dot target"),
            ctx.operand(stmt.get("source"), "Dot source"),
            ctx.operand(stmt.get("key"), "Dot key"),
        )

    def emit(self, ctx: Emit, end: str) -> None:
        ctx.add(f"t{self.target} = rt.dot({self.source.lua}, {self.key.lua})")
        ctx.jump(f"rt.is_undef(t{self.target})", end)
        ctx.mark_def(self.target)
