
# Copyright (c) 2026, Lei Meng

"""BlockStmt: nested blocks in order. Inner undefined does not skip siblings."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import TranslateError
from ir2lua.stmts.ctx import Emit, Lowered


@dataclass
class BlockStmt:
    ir_type: ClassVar[str] = "BlockStmt"
    blocks: list[list[Lowered]]

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> BlockStmt:
        raw = stmt.get("blocks")
        if not isinstance(raw, list):
            raise TranslateError(f"BlockStmt missing blocks: {stmt!r}")
        blocks: list[list[Lowered]] = []
        for b in raw:
            if not isinstance(b, dict):
                raise TranslateError(f"BlockStmt nested block must be an object: {b!r}")
            blocks.append(ctx.parse_nested(b.get("stmts") or []))
        return cls(blocks)

    def emit(self, ctx: Emit, _label: str) -> None:
        for inner in self.blocks:
            skip = ctx.fresh_label("blk")
            for node in inner:
                node.emit(ctx, skip)
            ctx.add_line(f"::{skip}::")
