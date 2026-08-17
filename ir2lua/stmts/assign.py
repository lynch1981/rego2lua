"""Slot writes: ResetLocal, AssignVar, AssignVarOnce."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.cx import Emit


def _jump_if_undef_src(cx: Emit, src: Operand, end: str) -> None:
    idx = src.local_index
    if idx is None or cx.known_def(idx):
        return
    cx.jump(f"rt.is_undef({src.lua})", end)
    cx.mark_def(idx)


@dataclass
class ResetLocalStmt:
    ir_type: ClassVar[str] = "ResetLocalStmt"
    target: int

    @classmethod
    def parse(cls, cx: Emit, stmt: dict[str, Any]) -> ResetLocalStmt:
        return cls(cx.local(stmt.get("target"), "ResetLocal target"))

    def emit(self, cx: Emit, _end: str) -> None:
        cx.add(f"t{self.target} = rt.UNDEF")
        cx.mark_undef(self.target)


@dataclass
class AssignVarStmt:
    ir_type: ClassVar[str] = "AssignVarStmt"
    target: int
    source: Operand

    @classmethod
    def parse(cls, cx: Emit, stmt: dict[str, Any]) -> AssignVarStmt:
        return cls(
            cx.local(stmt.get("target"), "AssignVar target"),
            cx.operand(stmt.get("source"), "AssignVar source"),
        )

    def emit(self, cx: Emit, end: str) -> None:
        _jump_if_undef_src(cx, self.source, end)
        cx.add(f"t{self.target} = {self.source.lua}")
        cx.mark_def(self.target)


@dataclass
class AssignVarOnceStmt:
    """Write-once. Official IR: error if the target is already defined."""

    ir_type: ClassVar[str] = "AssignVarOnceStmt"
    target: int
    source: Operand

    @classmethod
    def parse(cls, cx: Emit, stmt: dict[str, Any]) -> AssignVarOnceStmt:
        return cls(
            cx.local(stmt.get("target"), "AssignVarOnce target"),
            cx.operand(stmt.get("source"), "AssignVarOnce source"),
        )

    def emit(self, cx: Emit, end: str) -> None:
        _jump_if_undef_src(cx, self.source, end)
        cx.add(f'if rt.is_def(t{self.target}) then error("AssignVarOnce conflict") end')
        cx.add(f"t{self.target} = {self.source.lua}")
        cx.mark_def(self.target)
