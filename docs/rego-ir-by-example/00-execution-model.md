# 00 — Execution model

Read this before walking any plan. Everything else is “stmts that obey these rules.”

---

## Top-level plan.json

| Key | Role |
|-----|------|
| **`static`** | Constant pool: `strings`, `builtin_funcs`, `files` |
| **`plans`** | Named **entrypoints** (what `-e` asked for) |
| **`funcs`** | Compiled rule/function bodies |

You edit Rego; `plan.json` is machine output.

---

## Locals = slots in a frame

A **local** is a numbered slot (`0`, `1`, `2`, …), like a virtual register.

| | Meaning |
|--|---------|
| **Index** | Slot number in the JSON |
| **Value** | null, bool, number, string, array, object, set, or **undefined** |

```text
Frame for one plan or one func call:

  L0  L1  L2  L3  L4  ...
  │   │   │
  │   │   temps / return
  │   data (usual)
  input (usual)
```

- Slots are **untyped**; type follows whatever was written.
- No separate “global slot” bank: `input`/`data` are still locals (0/1 by convention).
- **Static strings** are not slots — use `string_index` into `static.strings`.

### Operand vs bare local

```json
{ "type": "local", "value": 3 }   // operand: a value (from a slot)
"target": 3                         // bare Local: always a slot index
"source": 3                         // bare Local: e.g. IsDefined / Return
```

Bare index is **not** a free short form for every field — only when the IR types the field as `Local`.

---

## Plan vs func

| | **Plan** (entrypoint) | **Func** (rule body) |
|--|----------------------|----------------------|
| Pre-bound | `L0=input`, `L1=data` | `params` (usually 0=input, 1=data, then more) |
| Success output | **`ResultSetAddStmt`** → implicit result set | **`ReturnLocalStmt`** → caller `CallStmt.result` |
| Typical shape | thin wrapper that **calls** a func | real policy logic |

```text
Plan frame                         Func frame
L0, L1 ──CallStmt args──────────►  params L0, L1, …
L_result ◄── return value ──────  ReturnLocal (return slot)
ResultSetAdd { result: L_result }
```

Each call gets a **new frame**. Caller’s `L3` ≠ callee’s `L3`.

### Calling convention (planned funcs)

```text
args[0] = input
args[1] = data
args[2+] = real parameters (if any)
```

**Builtins** (e.g. `lower`) take only their operands — no forced input/data prefix.

Caller arg indices need **not** be sequential; callee `params` usually are `0..n-1`.

---

## Blocks and definedness

A **block** is an ordered list of stmts.

1. Run stmts in order.
2. If a stmt is **undefined**, stop the **rest of that block**.
3. Plans/funcs are made of one or more top-level blocks (and nested blocks inside some stmts).

**Undefined** means “this path failed” (missing key, failed `Equal`, failed type check, …) — not always a hard error.

**Conflict** (e.g. `AssignVarOnce` with a different value) is a **hard error**, not mere undefined.

---

## Declarative Rego → write-once values

Rego is **declarative**: you define values, you don’t reassign temps in source.

| Source style | IR |
|--------------|-----|
| Complete rule value | often **`AssignVarOnceStmt`** |
| Planner temps / copies | **`AssignVarStmt`** (may overwrite slots) |
| Clear a slot | **`ResetLocalStmt`** → undefined |

---

## Result set (plans only)

```text
MakeObject  →  ObjectInsert "result"  →  ResultSetAdd
```

The plan’s **result set** is an implicit bag of solution objects. Empty set ⇒ no solutions.

---

## Nested control (not loops)

| Stmt | Role |
|------|------|
| **`ScanStmt`** | **only** iteration construct |
| **`BlockStmt`** | nested blocks (e.g. `else` chains) |
| **`NotStmt`** | succeed if nested block fails |
| **`WithStmt`** | run block under a temporary mutation |
| **`BreakStmt`** | jump out of enclosing block(s) |

Deep dive: [08-block-and-break.md](./08-block-and-break.md) (`else` vs multi-rule OR, merge + Break).

**Full control-flow summary:** [00b-control-flow.md](./00b-control-flow.md).

---

## Lua mental model

```lua
local UNDEF = {}           -- if you distinguish undefined from null

local function frame()
  return {}                -- dynamic; no need for frame_size
end

-- Plan:
local L = frame()
L[0], L[1] = input, data
-- run plan stmts
-- ResultSet[#ResultSet+1] = L[k]

-- Func call:
local C = frame()
C[0], C[1] = args...
-- run func stmts
return C[return_index]
```

---

## Next

Control flow in one place: [00b-control-flow.md](./00b-control-flow.md).  
Then walk a full policy: [01-spine-allow.md](./01-spine-allow.md).
