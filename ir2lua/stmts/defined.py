
# Copyright (c) 2026, Lei Meng <lynch.meng@hotmail.com>

"""IsDefinedStmt / IsUndefinedStmt: block guards for default vs body."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand
from ir2lua.stmts.cx import Emit


@dataclass
class IsDefinedStmt:
    ir_type: ClassVar[str] = "IsDefinedStmt"
    source: Operand

    @classmethod
    def parse(cls, cx: Emit, stmt: dict[str, Any]) -> IsDefinedStmt:
        return cls(cx.operand(stmt.get("source"), "IsDefined source"))

    def emit(self, cx: Emit, end: str) -> None:
        cx.jump(f"rt.is_undef({self.source.lua})", end)
        if self.source.local_index is not None:
            cx.mark_def(self.source.local_index)


@dataclass
class IsUndefinedStmt:
    ir_type: ClassVar[str] = "IsUndefinedStmt"
    source: Operand

    @classmethod
    def parse(cls, cx: Emit, stmt: dict[str, Any]) -> IsUndefinedStmt:
        return cls(cx.operand(stmt.get("source"), "IsUndefined source"))

    def emit(self, cx: Emit, end: str) -> None:
        cx.jump(f"rt.is_def({self.source.lua})", end)
        if self.source.local_index is not None:
            cx.mark_undef(self.source.local_index)
