# 02 — Scan and arrays

**Example:** [`examples/02-scan-arrays/`](./examples/02-scan-arrays/)

---

## Rego

```rego
package example

default allow := false

allow if {
	some name in input.names
	name == "alice"
}

errors := [msg |
	some msg in input.messages
	msg.level == "error"
]
```

```bash
opa eval -d policy.rego -i input.json 'data.example.allow'
opa eval -d policy.rego -i input.json 'data.example.errors'
opa build -t plan -e example/allow -e example/errors policy.rego
```

---

## New stmts

| Stmt | Role |
|------|------|
| **`ScanStmt`** | only IR loop — run nested block per element |
| **`MakeArrayStmt`** | `[]` (capacity = prealloc hint) |
| **`ArrayAppendStmt`** | push at end |

---

## `some name in xs` → ScanStmt

```text
DotStmt              L4 := input["names"]

ScanStmt  source=L4  key=L5  value=L6
  block:
    L8 := L6                      # name = element (value)
    EqualStmt  L8 == "alice"
    AssignVarOnce  allow_slot := true
```

| Collection | `key` local | `value` local |
|------------|-------------|---------------|
| array | index (often unused) | **element** |
| object | field name | field value |
| set | element | element |

### Lua

```lua
for i, name in ipairs(L[4]) do
  L[5] = i - 1          -- Rego arrays are 0-based if you materialize key
  L[6] = name
  if name == "alice" then
    L[3] = true
  end
  -- failed Equal ⇒ this iteration fails; scan continues
end
```

If you never read the index: `for _, name in ipairs(...)`.

---

## Comprehension → MakeArray + Scan + Append

```rego
errors := [msg | some msg in input.messages; msg.level == "error"]
```

```text
MakeArrayStmt     Larr := []          # capacity hint optional in Lua
ScanStmt          over input.messages
  block:
    … filter …
    ArrayAppendStmt  Larr.append(msg)
return Larr
```

**Rego source has no** `xs := []; append; append`.  
Literals and comprehensions lower to make+append under the hood:

```rego
xs := [1, 2, 3]
# → MakeArray + MakeNumber* + ArrayAppend ×3
```

### Lua

```lua
L[arr] = {}
for _, msg in ipairs(messages) do
  if msg.level == "error" then
    L[arr][#L[arr] + 1] = msg
  end
end
```

Ignore `capacity` in Lua.

---

## Important

- **`ScanStmt` is the only iteration construct** in IR.
- Array IR surface is only **Make / Append / IsArray** (plus shared Dot/Len/Scan).
- No `ArraySetStmt` — Rego doesn’t do imperative `arr[i] = x`.

---

## Next

[03-not-and-else.md](./03-not-and-else.md)
