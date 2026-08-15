# 01 — Spine: `allow` end-to-end

**Goal:** see the most common IR path in one policy.  
**Example:** [`examples/01-spine-allow/`](./examples/01-spine-allow/)

---

## Rego

```rego
package example

default allow := false

allow if {
	lower(input.user) == "alice"
}
```

```json
// input.json
{ "user": "Alice" }
```

```bash
opa eval -d policy.rego -i input.json 'data.example.allow'   # true
opa build -t plan -e example/allow policy.rego
```

---

## What this covers

| Stmt | Role here |
|------|-----------|
| `CallStmt` | plan→func, func→builtin `lower` |
| `AssignVarStmt` | copies between temps |
| `AssignVarOnceStmt` | rule value + default |
| `ResetLocalStmt` | clear rule result slot |
| `DotStmt` | `input.user` |
| `EqualStmt` | `== "alice"` |
| `IsDefinedStmt` / `IsUndefinedStmt` | body vs default |
| `MakeObjectStmt` / `ObjectInsertStmt` | pack `{result: …}` |
| `ResultSetAddStmt` | publish plan solution |
| `ReturnLocalStmt` | func return |

Also: `static.strings`, `static.builtin_funcs` (`lower`).

---

## Static

```text
strings[0] = "result"
strings[1] = "user"
strings[2] = "alice"
builtin: lower
```

---

## Plan `example/allow` (entrypoint wrapper)

```text
CallStmt           L2 := g0.data.example.allow(L0, L1)  # input, data
AssignVarStmt      L3 := L2
MakeObjectStmt     L4 := {}
ObjectInsertStmt   L4["result"] = L3                    # strings[0]
ResultSetAddStmt   ResultSet += L4
```

### Lua sketch

```lua
local L = {}
L[0], L[1] = input, data
L[2] = g0_data_example_allow(L[0], L[1])
L[3] = L[2]
L[4] = {}
L[4]["result"] = L[3]
result_set[#result_set + 1] = L[4]
```

Plans stay thin: **call rule, box answer, add to result set**.

---

## Func `g0.data.example.allow`

### Block 0 — body

```text
ResetLocalStmt       L3 := undefined           # rule result slot

DotStmt              L4 := input["user"]       # L0, strings[1]
AssignVarStmt        L5 := L4
CallStmt             L6 := lower(L5)           # builtin
AssignVarStmt        L7 := L6
EqualStmt            L7 == "alice"             # strings[2]
AssignVarOnceStmt    L3 := true                # body matched
```

If `Equal` fails → rest of block skipped → `L3` stays undefined.

### Block 1 — take body value if set

```text
IsDefinedStmt        L3
AssignVarOnceStmt    L2 := L3                  # return slot
```

### Block 2 — default

```text
IsUndefinedStmt      L2
AssignVarOnceStmt    L2 := false               # default allow
```

### Block 3 — return

```text
ReturnLocalStmt      L2
```

### Lua sketch (simplified)

```lua
function g0_data_example_allow(input, data)
  local L, UNDEF = {}, {}
  L[0], L[1] = input, data
  L[3] = UNDEF

  local u = L[0] and L[0]["user"]
  if u == nil then goto after_body end
  L[7] = lower(u)                  -- CallStmt builtin
  if L[7] ~= "alice" then goto after_body end
  L[3] = true                      -- AssignVarOnce

  ::after_body::
  if L[3] ~= UNDEF then
    L[2] = L[3]
  end
  if L[2] == nil or L[2] == UNDEF then
    L[2] = false                   -- default
  end
  return L[2]
end
```

Sketches here are IR-shaped (slots / `nil` for missing). Product codegen uses `rt.UNDEF` / `rt.NULL` / `rt.dot` — see [`runtime/README.md`](../../runtime/README.md#codegen-contract).

---

## Picture

```text
input.user ──Dot──► lower ──Equal "alice" ──► L3=true
                                              │
                         IsDefined ───────────┤
                                              ▼
default false ◄── IsUndefined(L2) ──── L2 ── return
                                              │
plan: { result: L2 } ──► ResultSet
```

---

## Why `AssignVarOnce` (not plain assign)

```rego
allow := true   # complete value of the rule
```

Two different values for the same complete rule ⇒ **conflict**.  
`AssignVarOnce` encodes write-once for that binding.  
Planner temps use `AssignVar` (rewritable slots).

---

## Next

Control-flow map: [00b-control-flow.md](./00b-control-flow.md).  
Iteration and arrays: [02-scan-and-arrays.md](./02-scan-and-arrays.md).
