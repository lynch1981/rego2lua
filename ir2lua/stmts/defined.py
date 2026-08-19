
# Copyright (c) 2026, Lei Meng

"""IsDefinedStmt / IsUndefinedStmt: block guards for default vs body."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.ctx import Emit


@dataclass
class IsDefinedStmt:
    ir_type: ClassVar[str] = "IsDefinedStmt"
    source: Operand

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> IsDefinedStmt:
        return cls(ctx.resolve_operand(stmt.get("source"), "IsDefined source"))

    def emit(self, ctx: Emit, label: str) -> None:
        ctx.jump_if(f"rt.is_undef({self.source.lua})", label)
        if self.source.local_index is not None:
            ctx.mark_def(self.source.local_index)


@dataclass
class IsUndefinedStmt:
    ir_type: ClassVar[str] = "IsUndefinedStmt"
    source: Operand

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> IsUndefinedStmt:
        return cls(ctx.resolve_operand(stmt.get("source"), "IsUndefined source"))

    def emit(self, ctx: Emit, label: str) -> None:
        ctx.jump_if(f"rt.is_def({self.source.lua})", label)
        if self.source.local_index is not None:
            ctx.mark_undef(self.source.local_index)
