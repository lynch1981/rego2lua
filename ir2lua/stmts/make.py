
# Copyright (c) 2026, Lei Meng

"""MakeNull / MakeNumber* / MakeArray / ArrayAppend."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand, TranslateError
from ir2lua.stmts.ctx import Emit


def _int_field(stmt: dict[str, Any], *keys: str) -> int | None:
    for k in keys:
        v = stmt.get(k)
        if isinstance(v, int) and not isinstance(v, bool):
            return v
    return None


@dataclass
class MakeNullStmt:
    ir_type: ClassVar[str] = "MakeNullStmt"
    target: int

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> MakeNullStmt:
        return cls(ctx.decl_local(stmt.get("target"), "MakeNull target"))

    def emit(self, ctx: Emit, _label: str) -> None:
        ctx.add_line(f"t{self.target} = rt.NULL")
        ctx.mark_def(self.target)


@dataclass
class MakeNumberIntStmt:
    ir_type: ClassVar[str] = "MakeNumberIntStmt"
    target: int
    value: int

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> MakeNumberIntStmt:
        value = _int_field(stmt, "value")
        if value is None:
            raise TranslateError(f"MakeNumberIntStmt missing value: {stmt!r}")
        return cls(ctx.decl_local(stmt.get("target"), "MakeNumberInt target"), value)

    def emit(self, ctx: Emit, _label: str) -> None:
        ctx.add_line(f"t{self.target} = {self.value}")
        ctx.mark_def(self.target)


@dataclass
class MakeNumberRefStmt:
    ir_type: ClassVar[str] = "MakeNumberRefStmt"
    target: int
    literal: str

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> MakeNumberRefStmt:
        idx = _int_field(stmt, "index", "Index")
        if idx is None:
            raise TranslateError(f"MakeNumberRefStmt missing index: {stmt!r}")
        # Resolve through a dummy string_index operand.
        op = ctx.resolve_operand(
            {"type": "string_index", "value": idx},
            "MakeNumberRef string",
        )
        if op.kind != "string":
            raise TranslateError(f"MakeNumberRefStmt index {idx} is not a string")
        text = str(op.value)
        try:
            float(text)
        except ValueError as e:
            raise TranslateError(f"MakeNumberRefStmt not a number: {text!r}") from e
        return cls(ctx.decl_local(stmt.get("target"), "MakeNumberRef target"), text)

    def emit(self, ctx: Emit, _label: str) -> None:
        ctx.add_line(f"t{self.target} = {self.literal}")
        ctx.mark_def(self.target)


@dataclass
class MakeArrayStmt:
    ir_type: ClassVar[str] = "MakeArrayStmt"
    target: int

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> MakeArrayStmt:
        return cls(ctx.decl_local(stmt.get("target"), "MakeArray target"))

    def emit(self, ctx: Emit, _label: str) -> None:
        ctx.add_line(f"t{self.target} = rt.make_array()")
        ctx.mark_def(self.target)


@dataclass
class ArrayAppendStmt:
    ir_type: ClassVar[str] = "ArrayAppendStmt"
    array: int
    value: Operand

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> ArrayAppendStmt:
        return cls(
            ctx.decl_local(stmt.get("array"), "ArrayAppend array"),
            ctx.resolve_operand(stmt.get("value"), "ArrayAppend value"),
        )

    def emit(self, ctx: Emit, label: str) -> None:
        idx = self.value.local_index
        if idx is not None and not ctx.known_def(idx):
            ctx.jump_if(f"rt.is_undef({self.value.lua})", label)
            ctx.mark_def(idx)
        ctx.add_line(
            f"t{self.array}[#t{self.array} + 1] = {self.value.lua}"
        )
