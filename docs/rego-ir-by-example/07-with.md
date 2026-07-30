# 07 — `with` (`WithStmt`)

**Example:** [`examples/07-with/`](./examples/07-with/)

---

## Rego

```rego
package example

inner if {
	input.x == 1
}

allow if {
	inner with input as {"x": 1}
}
```

Temporarily replaces `input` (or a path under a local) while evaluating the expression.

---

## IR

```text
WithStmt
  local: 0              # usually input
  path:  [] or [string indices]   # empty = replace whole local
  value: operand        # new value
  block:
    CallStmt / body under mutated local
# after block: local restored
```

| Field | Meaning |
|-------|---------|
| `local` | which slot to mutate |
| `path` | string-constant indices under that local (`[]` = whole value) |
| `value` | replacement / upsert value |
| `block` | run with mutation in effect |

---

## Lua sketch

```lua
local saved = L[0]
L[0] = deep_upsert(L[0], path, new_value)
-- run block stmts
L[0] = saved
```

Always restore, even if the block fails (use `pcall` / `finally` style).

---

## Next

Full index: [99-stmt-catalog.md](./99-stmt-catalog.md)
