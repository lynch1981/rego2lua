# 08 — `BlockStmt` and `BreakStmt`

**Goal:** understand nested multi-block control — when Rego produces it, and how it differs from “logical OR” via multiple rules.

**Related examples**

| Example | What to look at |
|---------|-----------------|
| [`examples/03-not-else/`](./examples/03-not-else/) | `else` chain → **`BlockStmt`** |
| [`examples/04-merge/`](./examples/04-merge/) | base∪virtual → **`BlockStmt` + `BreakStmt`** |
| [`examples/08-multi-allow/`](./examples/08-multi-allow/) | two `allow if` → **top-level blocks only** (no `BlockStmt`) |

Official field tables: https://www.openpolicyagent.org/docs/ir

---

## 1. Block vs `BlockStmt`

| Concept | Meaning |
|---------|---------|
| **Block** | Ordered list of stmts. Undefined stmt → skip rest of **this** block. |
| **Top-level `blocks[]`** | Phases of a plan/func (`blocks[0]`, `blocks[1]`, … on the func itself). |
| **`BlockStmt`** | **One statement** whose payload is **nested** `blocks[]`. |

```text
func.blocks[i]          ← top-level phase (not a BlockStmt)
    stmts:
      BlockStmt         ← nested multi-block structure
        blocks[0..]
```

Many policies never use `BlockStmt`; they only use top-level func blocks.

---

## 2. `BlockStmt` — shape and execution

```json
{
  "type": "BlockStmt",
  "stmt": {
    "blocks": [
      { "stmts": [ /* A */ ] },
      { "stmts": [ /* B */ ] },
      { "stmts": [ /* C */ ] }
    ]
  }
}
```

```text
run nested blocks[0]
run nested blocks[1]
run nested blocks[2]
… then continue after this BlockStmt
```

| Rule | Behavior |
|------|----------|
| Order | Nested blocks run **sequentially** |
| Undefined inside nested Bi | Only **Bi** stops early |
| Next nested block | Still runs (unless **`Break`** left the outer nest) |
| Loop? | **No** — that is `ScanStmt` |

---

## 3. From Rego: classic `else` chain

### Rego

```rego
package example

role := "admin" if {
	input.role == "admin"
} else := "user" if {
	input.role == "user"
} else := "guest"
```

### IR (func body, simplified)

```text
BlockStmt
  blocks[0]:
    Reset L3
    Equal input.role == "admin" → AssignOnce L3 := "admin"

  blocks[1]:
    IsUndefined L3
    Equal input.role == "user"  → AssignOnce L3 := "user"

  blocks[2]:
    IsUndefined L3
    AssignOnce L3 := "guest"

  blocks[3]:
    IsDefined L3 → return_slot := L3

ReturnLocal
```

### Trace `role == "user"`

| Nested block | Outcome |
|--------------|---------|
| 0 | equal fails → L3 still undef |
| 1 | IsUndefined OK → L3 = `"user"` |
| 2 | IsUndefined **fails** → skip guest |
| 3 | copy to return |

**Rego `else` ≈ if / else if / else**, not a boolean `||` expression.  
IR: **`BlockStmt` + `IsUndefined` guards**.

See also: [03-not-and-else.md](./03-not-and-else.md).

---

## 4. From Rego: two `allow if` rules (OR) — usually **no** `BlockStmt`

```rego
package example

allow if {
	input.role == "admin"
}
allow if {
	input.role == "user"
}
```

Meaning: allow is true if **either** body holds (same complete value `true`).

### IR pattern

```text
block[0]:  body admin  → AssignOnce L3 := true
block[1]:  IsDefined L3 → L2 := L3
block[2]:  body user   → AssignOnce L3 := true
block[3]:  IsDefined L3 → L2 := L3
block[4]:  ReturnLocal L2
```

| | `else` chain | Two `allow if` |
|--|--------------|----------------|
| Semantics | first branch **wins** (may different values) | **OR** of ways to prove same value |
| Typical IR | **`BlockStmt`** | **top-level** func `blocks[]` only |
| `BreakStmt` | rare | no |

If both rules can set **different** complete values → `AssignVarOnce` **conflict**.

---

## 5. From Rego: multi-field virtual object (grouping)

```rego
config.timeout := 30
config.retries := 3
```

Planner may wrap each contribution:

```text
BlockStmt { Call retries; ObjectInsert … }
BlockStmt { Call timeout; ObjectInsert … }
```

Here `BlockStmt` **isolates** each field’s call/insert so one undefined path doesn’t flatten the whole sequence the same way. Still not “OR of booleans.”

---

## 6. `BreakStmt` — planner early exit

### Shape

```json
{
  "type": "BreakStmt",
  "stmt": { "index": 1 }
}
```

| `index` | Leave |
|---------|--------|
| 0 | current block only |
| 1 | current + parent |
| n | n+1 levels |

There is **no** `break` keyword in normal Rego.  
`BreakStmt` is inserted when the planner builds **try / success / fallback**.

### Merge example (base data ∪ rules)

Query path with **both** `data.json` and rules → plan often:

```text
BlockStmt                          # parent: try merge or fallback
  BlockStmt                        # child: try base
    Dot data… → base
    ObjectMerge(base, virtual) → out
    BreakStmt index=1              # success → leave parent
  AssignVar out := virtual         # fallback if try never Broke
```

| Path | What happens |
|------|----------------|
| Base exists, merge OK | **Break** → skip fallback |
| Base missing (`Dot` undef) | no Break → **fallback** virtual-only |

So:

```text
Break  = “try succeeded; do not run fallback”
undef  = “try failed softly; fall through”
```

See: [04-merge-base-virtual.md](./04-merge-base-virtual.md).

---

## 7. Undefined vs Break vs Return

| Mechanism | Effect |
|-----------|--------|
| **Undefined stmt** | Stop **current** block only; no multi-level jump |
| **`BreakStmt`** | Jump out of **N** enclosing blocks on purpose |
| **`ReturnLocalStmt`** | Leave the **function** |
| Failed **Scan** iteration | Only that element; scan continues |

---

## 8. Is this “logical OR”?

| Want | Mechanism |
|------|-----------|
| Boolean OR of two bodies, same value | **Multiple rules** → top-level blocks (no `BlockStmt` required) |
| if / else if / else values | **`else`** → **`BlockStmt`** |
| Any element matches | **`ScanStmt`** |
| Try then skip fallback | **`BreakStmt`** inside nested `BlockStmt` |
| Dedicated `OrStmt` | **Does not exist** |

**Loose OR intuition** only for “try another path if this one didn’t bind.”  
IR still uses **blocks + definedness (+ break)**, not an OR opcode.

---

## 9. Lua-shaped sketches

### `BlockStmt` (else-style)

```lua
local L3 = UNDEF
-- nested 0
if input.role == "admin" then L3 = "admin" end
-- nested 1
if L3 == UNDEF and input.role == "user" then L3 = "user" end
-- nested 2
if L3 == UNDEF then L3 = "guest" end
return L3
```

### `Break` (try / fallback)

```lua
local out
local ok = true
-- try
local base = data.example and data.example.config
if base == nil then ok = false
else out = object_merge(base, virtual) end

if ok then
  -- Break: skip fallback
else
  out = virtual  -- fallback
end
```

---

## 10. Cheat sheet

| Stmt | Role |
|------|------|
| **`BlockStmt`** | Ordered **nested** blocks in one stmt |
| **`BreakStmt`** | Multi-level **exit** from nested blocks |

| Rego situation | Expect |
|----------------|--------|
| `else` / `else :=` | `BlockStmt` |
| Two `allow if {…}` | top-level blocks, usually **no** `BlockStmt` |
| data ∪ virtual path | `BlockStmt` + often `BreakStmt` |
| `not` / `some` / `with` | `NotStmt` / `ScanStmt` / `WithStmt` |

---

## 11. Catalog links

- Full stmt index: [99-stmt-catalog.md](./99-stmt-catalog.md)
- Execution model: [00-execution-model.md](./00-execution-model.md)
- Control-flow summary: [00b-control-flow.md](./00b-control-flow.md)

---

## One-liners

- **`BlockStmt`**: nest several blocks for **else**, **staged builds**, or **try shells**.  
- **`BreakStmt`**: planner **success jump** past fallback (esp. merge).  
- **Two `allow if`**: OR via **top-level blocks**, not `BlockStmt`.
