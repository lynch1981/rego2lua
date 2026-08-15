# 00b — Control-flow summary

How Rego IR **sequences**, **fails**, and **nests** work.  
Pair with [00-execution-model.md](./00-execution-model.md) (slots, frames, plan vs func).

Official reference: https://www.openpolicyagent.org/docs/ir

---

## 1. One rule to rule them all

```text
Run stmts in order inside a block.

If a stmt is UNDEFINED → skip the rest of THIS block.
If a stmt raises CONFLICT/ERROR → abort evaluation.
Otherwise → continue to the next stmt.
```

There is **no** general expression tree and **no** `OrStmt` / `IfStmt`.  
Control is **blocks + definedness + a few nested stmt types**.

---

## 2. What “undefined” means

| Outcome | Typical causes | Effect |
|---------|----------------|--------|
| **Defined** | op succeeded | next stmt |
| **Undefined** | missing key, failed `Equal`, failed type guard, failed `IsDefined`, empty scan source, … | **end current block early** |
| **Conflict / error** | `AssignVarOnce` different value, `ObjectInsertOnce` clash, bad merge types, … | **hard fail** |

Important:

```text
EqualStmt with false   →  UNDEFINED (block dies)
                          not “set false and continue”
```

That encodes declarative “this path does not hold.”

---

## 3. Structure hierarchy

```text
Policy
├── plans[]
│   └── blocks[]              ← top-level plan phases
│       └── stmts[]
│            └── nested control stmts (below)
└── funcs[]
    └── blocks[]              ← top-level func phases
        └── stmts[]
             └── nested …
```

| Level | What runs next after a block ends? |
|-------|-------------------------------------|
| Nested block inside `BlockStmt` / `Scan` / … | sibling nested block or outer stmt |
| Top-level `func.blocks[i]` | **`func.blocks[i+1]`** (always attempted in order) |
| After `ReturnLocal` | leave function |
| Plan after `ResultSetAdd` | continue plan block / next plan block |

**Top-level multi-block** ≠ **`BlockStmt`**.  
`BlockStmt` is one **stmt** that *contains* nested blocks.

---

## 4. Nested control statements

| Stmt | Kind | Control role |
|------|------|----------------|
| **`ScanStmt`** | loop | for each element, run nested `block` |
| **`NotStmt`** | invert | succeed iff nested `block` is **undefined** |
| **`BlockStmt`** | structure | run nested `blocks[]` **in order** |
| **`BreakStmt`** | jump | leave N enclosing blocks (`index`) |
| **`WithStmt`** | scope | mutate local → run `block` → **restore** |

Everything else is straight-line ops on locals (assign, make, call, equal, …).

Detail:

- Scan: [02-scan-and-arrays.md](./02-scan-and-arrays.md)  
- Not / else intro: [03-not-and-else.md](./03-not-and-else.md)  
- Block / Break deep dive: [08-block-and-break.md](./08-block-and-break.md)  
- With: [07-with.md](./07-with.md)

---

## 5. Per-construct behavior

### Straight-line block

```text
s0 → s1 → s2 → …
         ↑ undefined → stop
```

### Top-level func phases (e.g. default allow)

```text
blocks[0]  body maybe sets result
blocks[1]  IsDefined → copy to return
blocks[2]  IsUndefined → default false
blocks[3]  ReturnLocal
```

Each top-level block runs after the previous **finished** (success or early undefined).  
Guards (`IsDefined` / `IsUndefined`) decide whether **that phase** does anything.

### `ScanStmt` (only loop)

```text
for each (key, value) in source:
    run nested block
    # undefined this iteration → try next element
```

Not `BlockStmt`. Failed iteration ≠ end of function.

The **ScanStmt itself** is undefined if `source` is a scalar or **empty** (official IR). That exits the *containing* block. Comprehensions nest Scan in a `BlockStmt` so empty input still returns `[]` — see [02-scan-and-arrays.md](./02-scan-and-arrays.md).

### `NotStmt`

```text
run nested block
  undefined → Not succeeds
  defined   → Not fails (undefined)
```

Negation-as-failure of a **mini-program**, not `!bool` alone.

### `BlockStmt`

```text
for each nested Bi in blocks:
    run Bi
# then continue after BlockStmt
```

Classic Rego source: **`else` chains**.  
Also: staged document build, merge try shell.

### `BreakStmt`

```text
index 0 → leave current block
index 1 → leave current + parent
…
```

Planner-only (no Rego `break`). Used for **try succeeded → skip fallback** (e.g. merge).

### `WithStmt`

```text
save local
mutate (whole or path)
run block
restore local     # always
```

May nest (planner can emit nested `With` for one Rego `with`).

---

## 6. Rego patterns → control IR

| Rego | Typical IR control |
|------|---------------------|
| Single `allow if { … }` | top-level blocks; guards; no `BlockStmt` |
| `default` + body | top-level + `IsDefined` / `IsUndefined` |
| **Two `allow if`** (same value) | top-level blocks = **OR**; no `BlockStmt` |
| **`else` / `else :=`** | **`BlockStmt`** + `IsUndefined` |
| `some x in xs` / comprehension | **`ScanStmt`** (+ Make/Append for lists) |
| `not expr` | **`NotStmt`** |
| `with …` | **`WithStmt`** |
| data ∪ virtual same path | **`BlockStmt` + `BreakStmt`** often |
| Complete rule value | **`AssignVarOnce`** (conflict ≠ undefined) |

Example folders: `01`–`08` under [`examples/`](./examples/).

---

## 7. Logical OR / AND (how they really appear)

| Idea | IR reality |
|------|------------|
| **AND** of conditions in one body | sequential stmts; any undefined fails the body block |
| **OR** of two `allow if` | sequential **top-level** rule blocks; any success can set return |
| **if / else if / else** | **`BlockStmt`**, not OR |
| **any element** | **`ScanStmt`** |
| **`a \|\| b` expression** | no `OrStmt`; planner lowers however it does |

```text
AND  ≈  straight-line block (fail fast via undefined)
OR   ≈  more than one way to AssignOnce the same result
else ≈  BlockStmt alternatives with IsUndefined
```

---

## 8. Exits from a function / plan

| Unit | Success | Soft fail | Hard fail |
|------|---------|-----------|-----------|
| **Func** | `ReturnLocalStmt` | never bind return → call undefined | conflict |
| **Plan** | `ResultSetAddStmt` (0+ solutions) | empty result set | conflict |

```text
return only a local   — no `return 0` immediate
plan packs object     — MakeObject + insert + ResultSetAdd
```

---

## 9. Picture (spine `allow`)

```text
FUNC
│
├─ top block 0 ── body ── Equal fail ──► end block 0
│                 Equal ok ──► AssignOnce true
├─ top block 1 ── IsDefined? ──► copy to return
├─ top block 2 ── IsUndefined return? ──► default false
└─ top block 3 ── ReturnLocal
```

Gray walls = undefined ends **that** top-level block; later top-level blocks still run.

---

## 10. Picture (`else` vs multi-rule OR)

```text
else chain                    two allow if
──────────                    ────────────
BlockStmt                     top block: admin body
  nested: admin               top block: commit
  nested: user (if unset)     top block: user body
  nested: guest (if unset)    top block: commit
        │                              │
        ▼                              ▼
   first bind wins              any true binds return
   (maybe different values)     (same value true)
```

---

## 11. Implementer checklist (Lua / interpreter)

1. **Default:** run stmts in order in a block.  
2. **Undefined:** break out of **innermost** block only.  
3. **Top-level func/plan blocks:** after one ends, run the **next**.  
4. **`ScanStmt`:** loop; iteration undefined → next element.  
5. **`NotStmt`:** run block; invert definedness.  
6. **`BlockStmt`:** for each nested block, run it (undefined does not skip siblings).  
7. **`BreakStmt`:** unwind `index+1` block levels; resume after the target.  
8. **`WithStmt`:** save → mutate → block → **always restore** (stack if nested).  
9. **Conflict:** not the same as undefined — surface error.  
10. **Call:** new frame; callee undefined ⇒ call undefined.

---

## 12. Quick reference card

```text
sequence          stmts in a block
fail path         undefined → rest of block skipped
phases            multiple top-level blocks
loop              ScanStmt only
not               NotStmt + block
else / stages     BlockStmt + nested blocks
try / fallback    BreakStmt (+ nested BlockStmt)
with              WithStmt + save/restore
func out          ReturnLocalStmt
plan out          ResultSetAddStmt
hard fail         conflict (Once / InsertOnce / …)
```

---

## Next reading

| Order | Doc |
|------:|-----|
| Model | [00-execution-model.md](./00-execution-model.md) |
| Spine walk | [01-spine-allow.md](./01-spine-allow.md) |
| Block deep dive | [08-block-and-break.md](./08-block-and-break.md) |
| All stmts | [99-stmt-catalog.md](./99-stmt-catalog.md) |
