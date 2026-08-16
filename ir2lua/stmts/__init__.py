"""IR statement handlers. Add a module, then list the class here."""

from __future__ import annotations

from typing import Any

from ir2lua.operands import TranslateError
from ir2lua.stmts.assign import AssignVarOnceStmt, AssignVarStmt, ResetLocalStmt
from ir2lua.stmts.cx import Emit, Lowered
from ir2lua.stmts.defined import IsDefinedStmt, IsUndefinedStmt
from ir2lua.stmts.dot import DotStmt
from ir2lua.stmts.equal import EqualStmt
from ir2lua.stmts.return_local import ReturnLocalStmt

HANDLERS = {
    h.ir_type: h
    for h in (
        ResetLocalStmt,
        AssignVarStmt,
        AssignVarOnceStmt,
        DotStmt,
        EqualStmt,
        IsDefinedStmt,
        IsUndefinedStmt,
        ReturnLocalStmt,
    )
}


def parse_node(cx: Emit, node: dict[str, Any]) -> Lowered:
    typ = node.get("type")
    stmt = node.get("stmt")
    if not typ:
        raise TranslateError(f"statement missing type: {node!r}")
    if not isinstance(stmt, dict):
        raise TranslateError(f"{typ}: missing stmt object")
    handler = HANDLERS.get(typ)
    if handler is None:
        raise TranslateError(f"unsupported IR statement: {typ}")
    return handler.parse(cx, stmt)
