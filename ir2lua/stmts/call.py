
# Copyright (c) 2026, Lei Meng

"""CallStmt: builtin via rt.call_builtin, or a compiled func."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, ClassVar

from ir2lua.operands import Operand, TranslateError, lua_string
from ir2lua.stmts.ctx import Emit

# IR names implemented in runtime/builtins.lua. Keep in sync.
IMPLEMENTED = frozenset({
    "equal",
    "neq",
    "gt",
    "gte",
    "lt",
    "lte",
    "is_string",
    "is_number",
    "is_boolean",
    "is_null",
    "is_array",
    "is_object",
    "is_set",
    "type_name",
    "to_number",
    "plus",
    "minus",
    "mul",
    "div",
    "rem",
    "abs",
    "numbers.range",
})


@dataclass
class CallStmt:
    ir_type: ClassVar[str] = "CallStmt"
    func: str
    args: list[Operand]
    result: int
    planned_lua: str | None

    @classmethod
    def parse(cls, ctx: Emit, stmt: dict[str, Any]) -> CallStmt:
        func = stmt.get("func")
        if not isinstance(func, str) or not func:
            raise TranslateError(f"CallStmt missing func: {stmt!r}")
        raw_args = stmt.get("args")
        if not isinstance(raw_args, list):
            raise TranslateError(f"CallStmt args must be a list: {stmt!r}")
        args = [
            ctx.resolve_operand(a, f"CallStmt arg {i}")
            for i, a in enumerate(raw_args)
        ]
        planned = ctx.planned_func_lua(func)
        if planned is None and func not in IMPLEMENTED:
            raise TranslateError(f"unsupported builtin: {func}")
        return cls(
            func,
            args,
            ctx.decl_local(stmt.get("result"), "CallStmt result"),
            planned,
        )

    def emit(self, ctx: Emit, label: str) -> None:
        for a in self.args:
            idx = a.local_index
            if idx is None or ctx.known_def(idx):
                continue
            ctx.jump_if(f"rt.is_undef({a.lua})", label)
            ctx.mark_def(idx)
        arglist = ", ".join(a.lua for a in self.args)
        call_args = f", {arglist}" if arglist else ""
        if self.planned_lua:
            ctx.add_line(f"t{self.result} = {self.planned_lua}({arglist})")
            ctx.jump_if(f"rt.is_undef(t{self.result})", label)
        else:
            ctx.add_line("do")
            ctx.add_line(
                f"    local def, v = rt.call_builtin({lua_string(self.func)}{call_args})"
            )
            ctx.add_line(f"    if not def then goto {label} end")
            ctx.add_line(f"    t{self.result} = v")
            ctx.add_line("end")
        ctx.mark_def(self.result)
