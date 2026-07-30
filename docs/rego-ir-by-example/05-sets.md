# 05 — Sets (`MakeSetStmt`, `SetAddStmt`)

**Example:** [`examples/05-sets/`](./examples/05-sets/)

---

## Rego

```rego
package example

deny contains msg if {
	msg := "missing admin"
	not "admin" in input.roles
}

deny contains msg if {
	msg := "prod without approval"
	input.env == "prod"
	not input.approved
}
```

Partial **set** rules: many members are OK (unlike one complete `allow := bool`).

```bash
opa eval -d policy.rego -i input.json 'data.example.deny'
# → { "missing admin", "prod without approval" }  (as set)
```

---

## IR

```text
MakeSetStmt       Lset := empty set
…
SetAddStmt        Lset.add("missing admin")    # when first body holds
…
SetAddStmt        Lset.add("prod without approval")
Return / result set packaging
```

Also uses **`NotStmt`** for `not "admin" in …` / `not input.approved`.

---

## Lua sketch

Represent sets as tables with element keys, or a dedicated set type:

```lua
L[set] = {}
function set_add(s, v)
  s[v] = true   -- or store v as value
end
```

JSON export of sets is often an array; IR values are still **sets**.

---

## Vs arrays

| | Array | Set |
|--|-------|-----|
| Make | `MakeArrayStmt` | `MakeSetStmt` |
| Add | `ArrayAppendStmt` (ordered) | `SetAddStmt` (unique) |
| Rego | literals / comprehensions | `contains` partial rules |

---

## Next

[06-len-unify.md](./06-len-unify.md)
