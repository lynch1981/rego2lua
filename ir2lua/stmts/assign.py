
# Copyright (c) 2026, Lei Meng

"""Slot writes: ResetLocal, AssignVar, AssignVarOnce."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.ctx import Emit


def _jump_if_undef_src(ctx: Emit, src: Operand, label: str) -> None:
    idx = src.local_index
    if idx is None or ctx.known_def(idx):
        return
    ctx.jump_if(f"rt.is_undef({src.lua})", label)
    ctx.mark_def(idx)


@dataclass
class ResetLocalStmt:
    ir_type: ClassVar[str] = "ResetLocalStmt"
    target: int

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> ResetLocalStmt:
        return cls(ctx.decl_local(stmt.get("target"), "ResetLocal target"))

    def emit(self, ctx: Emit, _label: str) -> None:
        ctx.add_line(f"t{self.target} = rt.UNDEF")
        ctx.mark_undef(self.target)


@dataclass
class AssignVarStmt:
    ir_type: ClassVar[str] = "AssignVarStmt"
    target: int
    source: Operand

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> AssignVarStmt:
        return cls(
            ctx.decl_local(stmt.get("target"), "AssignVar target"),
            ctx.resolve_operand(stmt.get("source"), "AssignVar source"),
        )

    def emit(self, ctx: Emit, label: str) -> None:
        _jump_if_undef_src(ctx, self.source, label)
        ctx.add_line(f"t{self.target} = {self.source.lua}")
        ctx.mark_def(self.target)


@dataclass
class AssignVarOnceStmt:
    """Write-once. Official IR: error if the target is already defined."""

    ir_type: ClassVar[str] = "AssignVarOnceStmt"
    target: int
    source: Operand

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> AssignVarOnceStmt:
        return cls(
            ctx.decl_local(stmt.get("target"), "AssignVarOnce target"),
            ctx.resolve_operand(stmt.get("source"), "AssignVarOnce source"),
        )

    def emit(self, ctx: Emit, label: str) -> None:
        _jump_if_undef_src(ctx, self.source, label)
        ctx.add_line(f'if rt.is_def(t{self.target}) then error("AssignVarOnce conflict") end')
        ctx.add_line(f"t{self.target} = {self.source.lua}")
        ctx.mark_def(self.target)
