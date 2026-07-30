# 03 — `not` and `else` (NotStmt, BlockStmt)

**Example:** [`examples/03-not-else/`](./examples/03-not-else/)

---

## Rego

```rego
package example

allow if {
	not input.denied
}

role := "admin" if {
	input.role == "admin"
} else := "user" if {
	input.role == "user"
} else := "guest"
```

---

## NotStmt

Rego `not` applies to an **expression** (not the whole rule body).  
IR has no expression tree, so that expression is lowered into a **nested block**:

```text
NotStmt
  block:
    Dot / checks for input.denied
    …
```

| Nested block | `NotStmt` |
|--------------|-----------|
| undefined / fails | **succeeds** |
| succeeds | **undefined** (fail this path) |

Negation-as-failure, not C `!x` on a bool local alone.

### Lua sketch

```lua
local function not_block()
  -- run stmts; return false if any undefined, true if all ok
end

if not_block() then
  -- NotStmt fails
else
  -- NotStmt succeeds
end
```

---

## BlockStmt and `else`

```rego
role := "admin" if { … }
else := "user"  if { … }
else := "guest"
```

≈ if / else if / else for a **rule value**. IR often:

```text
BlockStmt
  blocks[0]:  try admin branch → AssignVarOnce role
  blocks[1]:  IsUndefined role; try user branch
  blocks[2]:  IsUndefined role; role := "guest"
  blocks[3]:  copy to return
```

Not a loop — **ordered nested blocks**. Later branches use `IsUndefined` so they run only if earlier ones did not bind.

### Lua sketch

```lua
local role = UNDEF
-- block 0
if input.role == "admin" then role = "admin" end
-- block 1
if role == UNDEF and input.role == "user" then role = "user" end
-- block 2
if role == UNDEF then role = "guest" end
return role
```

---

## Related: BreakStmt

`BreakStmt` jumps out of enclosing block(s) by `index` (0 = current).  
Appears in some planner patterns (e.g. merge fallback).

**Full treatment** (else vs two `allow if`, merge + Break):  
[08-block-and-break.md](./08-block-and-break.md).

---

## Next

[04-merge-base-virtual.md](./04-merge-base-virtual.md) · [08-block-and-break.md](./08-block-and-break.md)
