
# Copyright (c) 2026, Lei Meng

"""Parse one IR statement. Add a module, then list the class here."""

from __future__ import annotations

from typing import Any

from ir2lua.operands import TranslateError
from ir2lua.stmts.assign import AssignVarOnceStmt, AssignVarStmt, ResetLocalStmt
from ir2lua.stmts.block import BlockStmt
from ir2lua.stmts.call import CallStmt
from ir2lua.stmts.ctx import Emit, Lowered
from ir2lua.stmts.defined import IsDefinedStmt, IsUndefinedStmt
from ir2lua.stmts.dot import DotStmt
from ir2lua.stmts.equal import EqualStmt, NotEqualStmt
from ir2lua.stmts.make import (
    ArrayAppendStmt,
    MakeArrayStmt,
    MakeNullStmt,
    MakeNumberIntStmt,
    MakeNumberRefStmt,
)
from ir2lua.stmts.not_stmt import NotStmt
from ir2lua.stmts.return_local import ReturnLocalStmt
from ir2lua.stmts.scan import ScanStmt

HANDLERS = {
    h.ir_type: h
    for h in (
        ResetLocalStmt,
        AssignVarStmt,
        AssignVarOnceStmt,
        DotStmt,
        EqualStmt,
        NotEqualStmt,
        IsDefinedStmt,
        IsUndefinedStmt,
        ReturnLocalStmt,
        CallStmt,
        MakeNullStmt,
        MakeNumberIntStmt,
        MakeNumberRefStmt,
        MakeArrayStmt,
        ArrayAppendStmt,
        NotStmt,
        ScanStmt,
        BlockStmt,
    )
}


def parse_stmt(ctx: Emit, node: dict[str, Any]) -> Lowered:
    typ = node.get("type")
    stmt = node.get("stmt")
    if not typ:
        raise TranslateError(f"statement missing type: {node!r}")
    if not isinstance(stmt, dict):
        raise TranslateError(f"{typ}: missing stmt object")
    handler = HANDLERS.get(typ)
    if handler is None:
        raise TranslateError(f"unsupported IR statement: {typ}")
    return handler.parse(ctx, stmt)
