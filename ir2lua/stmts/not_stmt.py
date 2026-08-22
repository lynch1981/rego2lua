
# Copyright (c) 2026, Lei Meng

"""NotStmt: succeed if the nested block is undefined."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import TranslateError
from ir2lua.stmts.ctx import Emit, Lowered


@dataclass
class NotStmt:
    ir_type: ClassVar[str] = "NotStmt"
    inner: list[Lowered]

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> NotStmt:
        block = stmt.get("block")
        if not isinstance(block, dict):
            raise TranslateError(f"NotStmt missing block: {stmt!r}")
        inner = ctx.parse_nested(block.get("stmts") or [])
        return cls(inner)

    def emit(self, ctx: Emit, label: str) -> None:
        inner_lbl = ctx.fresh_label("not")
        ctx.add_line("do")
        ctx.add_line("    local hit = false")
        for node in self.inner:
            node.emit(ctx, inner_lbl)
        ctx.add_line("    hit = true")
        ctx.add_line(f"    ::{inner_lbl}::")
        ctx.add_line(f"    if hit then goto {label} end")
        ctx.add_line("end")
