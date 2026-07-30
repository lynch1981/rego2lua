# 04 — Base data + virtual rules (`ObjectMergeStmt`)

**Example:** [`examples/04-merge/`](./examples/04-merge/)

---

## Rego + data

**policy.rego** (virtual document):

```rego
package example

config.timeout := 30
config.retries := 3
```

**data.json** (base document):

```json
{
  "example": {
    "config": {
      "debug": false,
      "host": "localhost"
    }
  }
}
```

```bash
opa eval -d policy.rego -d data.json 'data.example.config'
# → { debug, host, timeout, retries }
```

There is **no `merge` keyword**. Merge is automatic when the same path has **both** base data and rule-defined fields.

---

## What each line does

| Source | Role |
|--------|------|
| `config.timeout := 30` | virtual field (→ insert into virtual object) |
| `config.retries := 3` | virtual field |
| `data.json` config | base object |
| *(planner)* | **`ObjectMergeStmt`** — not a Rego line |

`file/row/col` on `ObjectMergeStmt` are often `0` — synthetic.

---

## IR sketch (entrypoint `example/config`)

```text
# Build virtual object from rules
MakeObjectStmt     L2 := {}
Call timeout/retries funcs, ObjectInsert into L2
# L2 ≈ { timeout: 30, retries: 3 }

# Load base
Dot  L6 := data["example"]
Dot  L7 := L6["config"]
# L7 ≈ { debug: false, host: "localhost" }

ObjectMergeStmt    a=L7  b=L2  target=L5
# L5 ≈ full merged config

… box as { result: L5 }, ResultSetAdd
```

Also often: **`BlockStmt`**, **`BreakStmt`** around “try base then fall back to virtual-only.”

---

## Merge behavior (practical for Lua)

```text
merge(a, b):  # a=base, b=virtual
  both must be objects (else conflict)
  keys only in a or b → keep
  both values objects → recurse
  leaf clash → prefer a policy:
    recommended for overlays: b (virtual) wins
    Wasm-style: sometimes keep a
    strict ast.Merge: error on leaf clash
```

Complete rule vs base on the **same leaf** with different values is usually a **compile/eval conflict**, not silent overwrite:

```text
data timeout:10 + rule timeout:=30  →  error
```

Use **complementary keys** in demos.

### Lua sketch (right-wins leaves)

```lua
function object_merge(a, b)
  local out = {}
  for k, va in pairs(a) do
    local vb = b[k]
    if vb == nil then out[k] = va
    elseif is_object(va) and is_object(vb) then out[k] = object_merge(va, vb)
    else out[k] = vb end
  end
  for k, vb in pairs(b) do
    if out[k] == nil then out[k] = vb end
  end
  return out
end
```

---

## Picture

```text
BASE data.json              VIRTUAL rules
{ debug, host }             { timeout, retries }
         \                     /
          \                   /
           ObjectMergeStmt
                   │
                   ▼
     { debug, host, timeout, retries }
```

---

## BlockStmt + BreakStmt

Merge plans are a main source of **`BreakStmt`** (skip fallback after successful merge).  
Detail: [08-block-and-break.md](./08-block-and-break.md).

---

## Next

[05-sets.md](./05-sets.md) · [08-block-and-break.md](./08-block-and-break.md)
