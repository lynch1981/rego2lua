# IR → Lua Guide

Backend plan for **rego2lua**: compile **OPA’s official policy IR (JSON)** into **LuaJIT 2.1 / OpenResty**-compatible Lua.

---

## 1. Goal and non-goals

### Goal

```text
Rego source  ──(OPA)──►  plan.json (IR)  ──(this project)──►  Lua module
```

- **Frontend (done by OPA):** lex, parse, compile Rego → intermediate **plan** IR.
- **Backend (this project):** read IR JSON → emit Lua that preserves decisions for `input` / `data`.

Target runtime: **LuaJIT 2.1** (same language level as OpenResty). Generated modules should match our test conventions:

- Package table + **rule name = function name** (`foo.allow(input, data)`).
- Behavioral gold: `t/*.t` `--- out` (via `prove` / `t::Rego`).
- `--- ref_lua` remains a bootstrap / human reference until IR→Lua is trusted.

### Non-goals (for this backend)

- Hand-written Rego lexer/parser in-tree (see `learning-tokenize.md` / `learning-ast.md` for *education*; production path here is **OPA IR**).
- Full OPA built-in catalog on day one.
- Matching `ref_lua` source text character-for-character.

---

## 2. Pipeline in this repo

```text
                    ┌─────────────────────────────────────┐
  example.rego      │  opa build -t plan -e <entry> ...   │
  ─────────────►    │  → plan.json (+ optional bundle)    │
                    └─────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
  plan.json         │  rego2lua / ir2lua (Python)         │
  ─────────────►    │  walk IR → Lua source string        │
                    └─────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
  policy.lua        │  t/eval_pkg.lua + luajit            │
  + input/data      │  call each rule → JSON vs --- out   │
                    └─────────────────────────────────────┘
```

### Produce IR with OPA

OPA is already usable in this workspace (`opa/opa.run` style):

```bash
opa build -t plan -e example/allow example.rego -o bundle.tar.gz
tar -xzf bundle.tar.gz   # extracts plan.json (and related files)
```

- `-t plan` — emit the **plan IR** (not Wasm).
- `-e <path>` — entrypoint exposed as a plan (e.g. `data.foo.allow` path form `foo/allow` depending on package).

Machine-readable schema:

- https://openpolicyagent.org/schemas/ir/v1/plan.schema.json  

Official docs and Go types:

- https://www.openpolicyagent.org/docs/ir  
- https://github.com/open-policy-agent/opa/tree/main/v1/ir  

---

## 3. IR shape (what you will walk)

Root object is a **Policy** with three top-level keys:

| Key | Role |
|-----|------|
| `static` | String constants, builtin declarations, debug filenames |
| `plans` | Named entrypoints (evaluation paths) |
| `funcs` | Supporting functions called from plans / other funcs |

### Static

- `strings[]` — string constants; statements refer by **index** (`string_index`).
- `builtin_funcs[]` — builtins the runtime must provide (name + type decl).
- `files[]` — source names for debug only.

### Plans

Each plan:

- `name` — entrypoint id (e.g. `example/allow`).
- `blocks[]` — ordered blocks of statements.

Locals **0** and **1** are conventionally **`input`** and **`data`**.

Successful paths often end with `ResultSetAddStmt` (query result set). For our product API we still want a **stable Lua surface** like `module.allow(input, data) → value`, not necessarily OPA’s full result-set object—map IR results into that shape in the codegen layer.

### Functions

Each function:

- `name` / `path`, `params`, `return` local, `blocks[]`.
- Always has `input` and `data` as the first two parameters (locals).

### Blocks and statements

- A **block** runs `stmts` in order.
- A statement is **defined** or **undefined** (Rego’s three-valued feel).
- If any input is undefined → statement undefined → **break out of the current block** (not necessarily fail the whole plan).
- Many compares (`EqualStmt`, `NotEqualStmt`, `DotStmt` on missing key, …) use **undefined** instead of boolean false.

Each statement JSON roughly:

```json
{
  "type": "EqualStmt",
  "stmt": { "... type-specific fields ..." },
  "file": 0,
  "row": 1,
  "col": 2
}
```

### Operand (tagged union)

Operands appear all over IR:

```json
{ "type": "local", "value": 3 }
{ "type": "bool", "value": true }
{ "type": "string_index", "value": 0 }
```

Codegen needs a small helper: `operand_to_lua(op, env) → expression string`.

### Example (trimmed from a real `plan.json`)

Plan entry calling a compiled function, then building a result object:

```json
{
  "type": "CallStmt",
  "stmt": {
    "func": "g0.data.example.allow",
    "args": [
      { "type": "local", "value": 0 },
      { "type": "local", "value": 1 }
    ],
    "result": 2
  }
}
```

You will also see `DotStmt`, `EqualStmt`, `MakeObjectStmt`, `ScanStmt` (iteration), `NotStmt`, etc. Full list: OPA IR docs “Statement Definitions”.

---

## 4. Why Python for the backend

| Need | Python fit |
|------|------------|
| Load IR | `json` stdlib |
| Structured nodes | `dataclasses` |
| Emit source | f-strings / `string.Template` |
| Write files | `pathlib` |
| Iterate fast | no lexer work; pure tree walk |

Perl remains ideal for **`t/*.t`** (`Test::Base`). The IR walker does not need heavy regex; Python is the better codegen host.

Optional later: Jinja2, or generate from schema to typed models.

---

## 5. Six implementation steps

### Step 1 — Load and validate IR

```python
import json
from pathlib import Path

plan = json.loads(Path("plan.json").read_text())
assert "static" in plan and "plans" in plan
```

Optional: validate against the published JSON Schema; or convert dicts into dataclasses (`Policy`, `Plan`, `Block`, `Stmt`, `Operand`).

### Step 2 — Recursive translator

One driver that dispatches on `stmt["type"]`:

```text
translate_policy(plan) → lua_module_string
  translate_plan / translate_func
    translate_block
      translate_stmt(type, stmt)
```

Start with a **tiny** subset that can satisfy `t/sanity.t` style policies:

- locals / assign  
- `DotStmt` (field access)  
- `EqualStmt` / `NotEqualStmt`  
- constants (`MakeNullStmt`, numbers, `string_index`)  
- `CallStmt` to policy functions  
- early `ReturnLocalStmt` / result mapping  

### Step 3 — Values: array, object, set

| Rego / IR | Lua approach |
|-----------|----------------|
| array | sequence table (`t[1]`, `t[2]`, …) — remember Rego is 0-based, Lua 1-based at boundaries |
| object | map table (`t.key` / `t["key"]`) |
| set | dedicated representation (e.g. table used as set via helpers); **not** a bare array |

Emit constructors + helpers: `make_set`, `set_add`, `object_insert`, `array_append`, …

### Step 4 — Harder semantics

Map IR control to Lua + runtime:

| IR / concept | Direction |
|--------------|-----------|
| undefined | explicit `UNDEF` sentinel or dual (ok, value); block exit = `goto`/nested functions/`return` from block runner |
| `NotStmt` | run nested block; succeed if nested is undefined |
| `ScanStmt` | iterate keys/values; run nested block per element |
| `WithStmt` | temporarily mutate `input`/`data` path for nested block |
| builtins | call into Lua runtime table `builtins[name](...)` |

Implement **one statement type at a time**, gated by which tests you unlock.

### Step 5 — Complete Lua module

Output shape (product convention):

```lua
-- <original rego as comments optional if you still have source>
local foo = {}

function foo.allow(input, data)
  -- body generated from IR (or thin wrapper around plan execution)
  return result
end

return foo
```

Two generation styles (pick one early):

1. **Direct style** — IR becomes straight-line Lua resembling `ref_lua` (easier to read, harder for full IR).  
2. **VM style** — Lua function implements a small interpreter over locals + stmt list (closer to OPA IR execution model, easier completeness).

For v0.1, **VM style over IR statements** is usually faster to get correct; optimize to direct style later for hot paths.

Also concatenate a **runtime preamble** (helpers + undef + sets).

### Step 6 — Testing (harness already exists)

Do **not** skip testing—the harness is ready; wire the compiler into it:

1. From `--- Rego`, run `opa build -t plan -e ...` (or cache IR).  
2. Run IR→Lua → write temp module.  
3. Existing `t/eval_pkg.lua` loads module, calls rules, compares to `--- out`.

Bootstrap order (same as `./go` spirit):

| Order | Suite | Why |
|-------|--------|-----|
| 1 | `sanity.t` | default, `==`, AND, `not`, `:=` |
| 2 | `scalars.t` | null / bool / number / string |
| 3 | `access.t` | `DotStmt`, indexing |
| 4 | `membership.t` | `ScanStmt` / `in` |
| 5 | `cmp_*.t` | compare stmts |

Until the binary exists, `t::Rego` still falls back to `--- ref_lua`.

---

## 6. Runtime helpers (Lua)

Hand-written, shipped with every generated module (or a shared `rego_rt.lua` required by generated code).

Minimum ideas:

```text
rt.UNDEF
rt.is_undef(x)
rt.dot(obj, key)          -- DotStmt; undef if missing
rt.eq(a, b) / rt.neq      -- with undef rules
rt.make_set() / rt.set_add / rt.set_contains
rt.not_block(fn)          -- NotStmt
rt.scan(col, body_fn)     -- ScanStmt
rt.with(doc, path, val, body_fn)
rt.builtins["plus"] = ... -- as needed
```

**Undefined ≠ JSON null ≠ Lua nil.** Document the sentinel clearly; `cjson.null` is only for JSON null scalars (`scalars.t`).

---

## 7. Suggested Python layout

```text
rego2lua/                 # or ir2lua/
  __init__.py
  load.py                 # json → Policy dataclasses
  operands.py             # operand → Lua expr
  stmts/                  # one module per stmt family (optional)
  translate.py            # recursive driver
  runtime_lua.py          # string blob of helpers
  cli.py                  # plan.json → out.lua
```

CLI sketch:

```bash
python -m rego2lua compile plan.json -o policy.lua
# later: rego2lua foo.rego -e foo/allow -o foo.lua  (shells out to opa)
```

---

## 8. Development tips

1. **Start with load + dump**: pretty-print plans/funcs from `opa/plan.json` before generating Lua.  
2. **One statement type per PR**; unlock one `.t` case at a time.  
3. Keep runtime helpers in **one editable Lua blob**.  
4. Prefer correctness over pretty Lua until `sanity.t` is green on IR path.  
5. Log IR `type` on unknown statements; fail closed.  
6. Use `--- ONLY` in `.t` files when debugging generated Lua dumps.

---

## 9. Mapping IR statements → early priority

| Priority | IR `type` | Needed for |
|----------|-----------|------------|
| P0 | `AssignVarStmt`, `AssignVarOnceStmt`, `ResetLocalStmt` | locals |
| P0 | `MakeNullStmt`, `MakeNumberIntStmt`, `MakeNumberRefStmt` | scalars |
| P0 | `DotStmt` | `input.method` |
| P0 | `EqualStmt`, `NotEqualStmt` | compares |
| P0 | `CallStmt`, `ReturnLocalStmt` | funcs / entry |
| P1 | `MakeObjectStmt`, `ObjectInsertStmt`, `MakeArrayStmt`, `ArrayAppendStmt` | structures |
| P1 | `NotStmt` | `not` |
| P1 | `ScanStmt`, `Is*` checks | membership / iteration |
| P2 | `MakeSetStmt`, `SetAddStmt` | sets |
| P2 | `WithStmt`, `CallDynamicStmt`, builtins | advanced |

---

## 10. Relation to other docs

| Doc | Role |
|-----|------|
| **This guide** | Production backend: **OPA IR → Lua** |
| `learning-tokenize.md` | Educational Rego lexer (not required if OPA is frontend) |
| `learning-ast.md` | Educational AST / recursive descent |
| `README.md` / `t/*.t` | Behavioral contract for generated Lua |

---

## 11. References

- OPA IR documentation: https://www.openpolicyagent.org/docs/ir  
- IR Go package: https://github.com/open-policy-agent/opa/tree/main/v1/ir  
- Plan JSON Schema: https://openpolicyagent.org/schemas/ir/v1/plan.schema.json  
- OPA policy test suite (conformance inspiration): https://github.com/open-policy-agent/opa/tree/main/v1/test/cases  

---

## 12. Checklist

- [ ] Generate `plan.json` for `example.rego` / a `sanity` policy  
- [ ] Load IR in Python; print plan names and stmt type histogram  
- [ ] Implement P0 statements + minimal runtime  
- [ ] Emit `package` module API matching `ref_lua`  
- [ ] Green: first case of `t/sanity.t` via IR path  
- [ ] Grow statement coverage until `./go` is IR-backed  
