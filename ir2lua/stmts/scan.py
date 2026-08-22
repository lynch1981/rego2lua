
# Copyright (c) 2026, Lei Meng

"""ScanStmt: only IR loop. Nested undefined → next element."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import TranslateError
from ir2lua.stmts.ctx import Emit, Lowered


@dataclass
class ScanStmt:
    ir_type: ClassVar[str] = "ScanStmt"
    source: int
    key: int
    value: int
    inner: list[Lowered]

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> ScanStmt:
        block = stmt.get("block")
        if not isinstance(block, dict):
            raise TranslateError(f"ScanStmt missing block: {stmt!r}")
        return cls(
            ctx.decl_local(stmt.get("source"), "Scan source"),
            ctx.decl_local(stmt.get("key"), "Scan key"),
            ctx.decl_local(stmt.get("value"), "Scan value"),
            ctx.parse_nested(block.get("stmts") or []),
        )

    def emit(self, ctx: Emit, label: str) -> None:
        src = f"t{self.source}"
        ctx.jump_if(
            f"rt.is_undef({src}) or type({src}) ~= \"table\" or next({src}) == nil",
            label,
        )
        iter_lbl = ctx.fresh_label("scan")
        ctx.add_line(f"for k, v in pairs({src}) do")
        ctx.add_line(f"    t{self.key} = k")
        ctx.add_line(f"    t{self.value} = v")
        ctx.mark_def(self.key)
        ctx.mark_def(self.value)
        for node in self.inner:
            node.emit(ctx, iter_lbl)
        ctx.add_line(f"    ::{iter_lbl}::")
        ctx.add_line("end")
