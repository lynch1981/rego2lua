# 06 — Length and array unify (`LenStmt`, `IsArrayStmt`, …)

**Example:** [`examples/06-len-unify/`](./examples/06-len-unify/)

---

## Rego

```rego
package example

allow if {
	input.pair == [1, 2]
}
```

Comparing/unifying with a **fixed array literal** makes the planner check type and length.

---

## Important: `count()` ≠ `LenStmt`

```rego
n := count(input.xs)
```

Usually becomes:

```text
CallStmt  func = "count"     # builtin
```

**Not** `LenStmt`.

`LenStmt` is a low-level “length of this value” used inside other lowerings (e.g. unify with `[1,2]`).

---

## IR sketch

```text
L4 := input["pair"]
IsArrayStmt       L4
LenStmt           L6 := len(L4)
MakeNumberIntStmt L7 := 2          # or AssignInt / MakeNumberRef
EqualStmt         L6 == L7
AssignIntStmt     index locals for 0, 1
Dot + Equal       elements vs 1, 2
…
```

This example’s plan includes among others:

- `IsArrayStmt`, `LenStmt`
- `MakeNumberIntStmt`, `MakeNumberRefStmt`
- `AssignIntStmt`

---

## Lua

```lua
assert(is_array(L[4]))
if length(L[4]) ~= 2 then fail_block() end
-- then compare L[4][1], L[4][2] carefully with 0- vs 1-based indexing
```

---

## Next

[07-with.md](./07-with.md)
