# IR → Lua Guide

Backend plan for **rego2lua**: compile **OPA’s official policy IR (JSON)** into **LuaJIT 2.1 / OpenResty**-compatible Lua.

First tagged subset: **0.0.1-dev** ([`CHANGELOG.md`](../CHANGELOG.md), [`releasing.md`](./releasing.md)). That tag is a snapshot, not the end of this guide.

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
- **Always** emit `(input, data)` — the harness calls every rule with both (`t/eval_pkg.lua`).
- Behavioral gold: `t/*.t` `--- out` (via `prove` / `t::Rego`).
- `--- ref_lua` remains a bootstrap / human reference until IR→Lua is trusted; hand refs may omit unused `data`, but codegen must not.

### Non-goals (for this backend)

- Hand-written Rego lexer/parser in-tree (see `learning-tokenize.md` / `learning-ast.md` for *education*; production path here is **OPA IR**).
- Full OPA built-in catalog on day one.
- Matching `ref_lua` source text character-for-character.

---

## 2. Pipeline in this repo

```text
Rego  --opa build -t plan-->  plan.json (IR)
                                    │
                                    │  codegen (no IR interpreter at runtime)
                                    ▼
                              Lua source/module
                                    │
                                    │  LuaJIT + small runtime (builtins, undef, sets, …)
                                    ▼
                              rule value  e.g. true / false
```

Repo harness view:

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

OPA must be on `PATH` (`opa version`). There is no in-repo `opa/` wrapper.

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

In-repo learning path (walked plans + stmt catalog): **[rego-ir-by-example/](./rego-ir-by-example/)**.

---

## 3. IR shape (what you will walk)

OPA’s **plan IR** is a low-level, imperative representation of Rego. It is meant for evaluators and backends that do not run Rego directly (custom runtimes, Wasm-style pipelines, or further codegen). You edit Rego; `plan.json` is machine output, not hand-written policy.

Root object is a **Policy** with three top-level keys:

| Key | Role |
|-----|------|
| `static` | Constant pool: strings, builtin decls, source file names |
| `plans` | Named entrypoint programs (queries) |
| `funcs` | Compiled rule/function bodies called by plans |

### `static`

- **`strings[]`** — string constants; statements refer by **index** (`string_index`). Example: `0 → "result"`, `1 → "user"`, `2 → "alice"`.
- **`builtin_funcs[]`** — builtins the runtime must provide (name + type decl), e.g. `lower`.
- **`files[]`** — source map for debug only (`0 → allow.rego`); stmts carry `file` / `row` / `col`.

### `plans` (entrypoints)

```text
plans
└── plans[]
    └── Plan
        ├── name      # e.g. "example/allow"
        └── blocks[]
            └── stmts[]
```

One plan per `-e` entrypoint. Multiple entrypoints → multiple named plans.

#### Execution model

1. **Locals 0 and 1** are pre-bound: `0 = input`, `1 = data`.
2. **Blocks** run in order; **statements** in a block run in order.
3. If a statement is **undefined**, the rest of that block is skipped.
4. Successful plan blocks end with **`ResultSetAddStmt`**, which appends an object to an **implicit result set**.
5. The result object holds **query variable bindings** (for entrypoints, typically `{ "result": <value> }`).
6. Plans usually **call** functions under `funcs`; they do not contain full rule body logic.

For our product API we still want a **stable Lua surface** like `module.allow(input, data) → value`, not necessarily OPA’s full result-set object—map IR results into that shape in the codegen layer.

#### Plans vs funcs

| | `plans` | `funcs` |
|--|---------|---------|
| Role | Query entrypoints | Rule/function bodies |
| Output | Implicit result set | Explicit `ReturnLocalStmt` |
| Pre-bound | 0=input, 1=data | Params listed (`params`, `return`) |
| Typical content | Thin wrapper | Real policy (`lower`, `==`, default) |

### `funcs`

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

### Locals (slots)

| | Meaning |
|--|---------|
| **Index** | Always an integer slot number (`0`, `1`, `2`, …) |
| **Value in the slot** | Any IR value: null, bool, number, string, array, object, **set**, or **undefined** |

Slots are **untyped registers**; values carry runtime types. The plan JSON does not declare “local 4 is always object”—that follows from what wrote the slot.

- **IR contract:** local is a 32-bit integer; no small fixed bank (not “only 0–15”).
- Frames are **separate**: plan local 2 ≠ function local 2 until the call returns into the plan’s slot.
- `CallStmt.result` is chosen per call; locals are virtual slots, not a tiny CPU register file that the next call always clobbers.

### Operand (tagged union)

Operands appear all over IR:

```json
{ "type": "local", "value": 3 }
{ "type": "bool", "value": true }
{ "type": "string_index", "value": 0 }
```

Codegen needs a small helper: `operand_to_lua(op, env) → expression string`.

### Why untyped slots help codegen

Rego works over nested documents; the same path may be missing or different types depending on input/data. Untyped locals avoid full type inference in the planner:

```text
allocate local → emit Dot/Call/Equal/Assign → done
```

| Untyped IR | Typed IR |
|------------|----------|
| Easier Rego → IR | Harder planner |
| Dynamic checks at eval | Stronger static checking for backends |

IR locals are like **dynamically typed slots**, not “weak typing” (implicit coercions). Wrong ops fail or go undefined rather than silently coercing.

---

## 4. Worked example (`example/allow`)

Source policy:

```rego
package example

default allow := false

allow if {
	lower(input.user) == "alice"
}
```

Built with:

```bash
opa build -t plan -e example/allow allow.rego
```

### Plan (five statements)

| # | Stmt | Effect |
|---|------|--------|
| 1 | `CallStmt` | `g0.data.example.allow(local0, local1)` → local **2** |
| 2 | `AssignVarStmt` | local **3** ← local **2** |
| 3 | `MakeObjectStmt` | local **4** ← `{}` |
| 4 | `ObjectInsertStmt` | local **4**`["result"]` ← local **3** |
| 5 | `ResultSetAddStmt` | result set ← local **4** |

Pipeline:

```text
input/data → call allow → bind "result" → { result: bool } → result set
```

One block is enough here: the rule always defines a value (`default allow := false`), so the plan always produces one solution on success.

**Plan frame locals**

| Local | Role |
|------:|------|
| 0 | `input` |
| 1 | `data` |
| 2 | call result (temp) |
| 3 | query binding for `"result"` |
| 4 | result object `{ result = … }` |

### Statement notes (this plan)

#### `CallStmt`

Invokes a named function (or a builtin when compiling funcs). Stores the return value in `result` (a local index).

Example (trimmed from a real `plan.json`):

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

#### `AssignVarStmt` (2 → 3)

Copies the call result into the **query variable** local used for `"result"`.

- **Conceptually:** temp (call output) → stable binding.
- **In this plan:** redundant for correctness; nothing later overwrites local 2. OPA’s planner does not always eliminate the copy.

#### `MakeObjectStmt`

Creates an empty object `{}` in `target` (local 4). Always defined. Used so the plan can package bindings as an object for the result set.

#### `ObjectInsertStmt`

`object[key] = value` (in-place).

- `key`: operand (here `string_index` 0 → `"result"`).
- `value`: operand (here local 3).
- `object`: local index of the object (4).

Overwrite is allowed. Contrast **`ObjectInsertOnceStmt`**, which errors on conflicting redefinition (more common in rule construction).

#### `ResultSetAddStmt`

Publishes one solution object into the plan’s implicit result set. Empty result set = no solutions.

### Function body (`g0.data.example.allow`)

- Params: locals 0, 1 (`input`, `data`); return: local 2.
- Path: `["g0", "example", "allow"]`.
- Blocks encode: try body (`lower(input.user) == "alice"` → true), then if defined assign return, else default `false`, then return.
- Function frame (separate from the plan): params 0–1, return 2, partial/temps 3–7.

Uses **`AssignVarOnceStmt`**, **`ResetLocalStmt`**, **`IsDefinedStmt` / `IsUndefinedStmt`**, **`EqualStmt`**, **`DotStmt`**, **`CallStmt` (`lower`)**, **`ReturnLocalStmt`**.

You will also see `ScanStmt` (iteration), `NotStmt`, etc. Full list: OPA IR docs “Statement Definitions”.

---

## 5. Why Lua fits IR → codegen

### Lua typing

Lua is **dynamically typed**, not untyped:

- Values have types at runtime (`nil`, boolean, number, string, table, function, …).
- Variables/slots do not have fixed static types.

That lines up well with IR locals: untyped slots, typed values. Easier than targeting a strictly statically typed language (no need to invent a static type for every temp).

### Many IR statements map 1:1

| IR | Lua sketch |
|----|------------|
| Local slots | locals or `L[i]` table |
| Objects | `{}` tables |
| `MakeObject` + `ObjectInsert` | `t = {}; t[key] = value` |
| `CallStmt` | `L[2] = f(L[0], L[1])` |
| `AssignVar` | `L[3] = L[2]` |
| Result set | table of binding tables |

Example sketch for the entrypoint plan:

```lua
function plan_example_allow(input, data)
  local l2 = g0_data_example_allow(input, data)
  local l3 = l2
  local l4 = { result = l3 }
  return { l4 }  -- result set (product API then unwraps to the rule value)
end
```

### Preferred approach: AOT codegen (no mini-VM)

Preferred: **AOT compile IR → real Lua**, then run on the normal LuaJIT VM.

| Approach | Eval-time behavior |
|----------|--------------------|
| Mini-VM / interpreter | Loop over IR stmts, dispatch on `type` |
| **Codegen** (preferred) | Generated functions *are* the plan |

No second IR interpreter is required if generated Lua already implements IR semantics. IR “undefined → leave block” becomes ordinary Lua structure (`if`, nested functions, labels/`goto`), not a statement dispatcher.

Still needed (as a **runtime library**, not a VM):

- Builtins (`lower`, …) matching OPA where it matters
- Set helpers if policies use sets
- A convention for **undefined** (early return, `goto`, sentinel) mapped to Lua control flow
- Optional shared helpers for dot/lookup, conflicts (`AssignVarOnce`), etc.

A thin **VM-style** emitter (Lua that interprets a stmt list) can be a temporary bootstrap if it unlocks tests faster; do not treat it as the product architecture. Prefer lowering each stmt type to straight-line Lua as coverage grows.

### What remains non-trivial for full fidelity

- Full IR surface: `ScanStmt`, `WithStmt`, multi-block plans, multi-solution queries
- Sets and number edge cases vs OPA
- Builtin parity
- Mapping result-set plans into our stable `module.rule(input, data) → value` API

A **toy** for simple plans like `example/allow` can be small. **Full** IR coverage is mostly runtime/helper completeness plus careful control-flow lowering—not a separate mini-VM architecture.

---

## 6. Why Python for the backend

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

## 7. Six implementation steps

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

Start with a **tiny** subset that can satisfy `t/sanity.t` style policies (`default` + field compare):

- locals / `AssignVarStmt` / `AssignVarOnceStmt` / `ResetLocalStmt`  
- `DotStmt` (field access)  
- `EqualStmt` / `NotEqualStmt`  
- `IsDefinedStmt` / `IsUndefinedStmt` (body vs `default`)  
- constants (`MakeNullStmt`, numbers, `string_index`)  
- `CallStmt` to policy functions  
- `MakeObjectStmt` / `ObjectInsertStmt` / `ResultSetAddStmt` (plan entry; unwrap to the rule value)  
- `ReturnLocalStmt`  

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

Output shape (product convention — **both** args always):

```lua
-- <original rego as comments optional if you still have source>
local foo = {}

function foo.allow(input, data)
  return result
end

return foo
```

Do not emit `function foo.allow(input)` only. Locals 0/1 in IR are `input`/`data`; the stable Lua surface mirrors that. Bootstrap `ref_lua` in tests may still use a single-arg form when `data` is unused — that is not the product API.

Generation style (see §5):

1. **Direct AOT style** (preferred) — each IR stmt becomes straight-line Lua; closer to `ref_lua` readability as the emitter improves.  
2. **VM style** — optional short-term bootstrap: a small interpreter over locals + stmt list.

Also concatenate a **runtime preamble** (helpers + undef + sets).

### Step 6 — Testing (harness already exists)

Do **not** skip testing—the harness is ready; wire the compiler into it:

1. From `--- Rego`, run `opa build -t plan -e ...` (or cache IR).  
2. Run IR→Lua → write temp module.  
3. Existing `t/eval_pkg.lua` loads module, calls rules, compares to `--- out`.

Bootstrap order (same as `./go`):

| Order | Suite | Why |
|-------|--------|-----|
| 0 | `runtime.t` | Unit tests for `runtime/` (loads facade `rego_rt.lua`) |
| 1 | `sanity.t` | default, `==`, AND, `not`, `:=` |
| 2 | `scalars.t` | null / bool / number / string |
| 3 | `access.t` | `DotStmt`, indexing |
| 4 | `membership.t` | `ScanStmt` / `in` |
| 5 | `cmp_*.t` | compare stmts |

Until the binary exists, `t::Rego` still falls back to `--- ref_lua`.

---

## 8. Runtime helpers (Lua)

**Codegen contract (the law):** [`runtime/README.md` — Codegen contract](../runtime/README.md#codegen-contract). Do not restate those rules here.

Hand-written library under [`runtime/`](../runtime/) (facade `rego_rt.lua` + layers). Target: **LuaJIT 2.1** / OpenResty. Tests: `prove t/runtime.t`. Slices: [`rego-builtins-runtime.md`](./rego-builtins-runtime.md).

### Preferred generated Lua (AOT, clean)

Prefer **named locals + `if`**, not IR register dumps. Emit only APIs listed in the contract:

```lua
-- package foo
-- default allow := false
-- allow if { input.method == "GET" }

local rt = require("rego_rt")
local foo = {}

function foo.allow(input, data)
  input = input or {}
  data  = data or {}

  local allow = false

  local method = rt.dot(input, "method")
  if rt.is_def(method) and rt.values_equal(method, "GET") then
    allow = true
  end

  return allow
end

return foo
```

Register-style (`L[i]`, `goto`) is a plan-IR mental model ([`rego-ir-by-example/`](./rego-ir-by-example/)), not the readability target.

Later slices and runtime-vs-contract notes: [`runtime/README.md`](../runtime/README.md#later-slices). Slice map: [`rego-builtins-runtime.md`](./rego-builtins-runtime.md).

---

## 9. Suggested Python layout

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

## 10. Development tips

1. **Start with load + dump**: pretty-print plans/funcs from a real `plan.json` before generating Lua.  
2. **One statement type per PR**; unlock one `.t` case at a time.  
3. Keep runtime as **facade + layers** under `runtime/` (see `runtime/README.md`); public load path stays `rego_rt.lua`.  
4. Prefer correctness over pretty Lua until `sanity.t` is green on IR path.  
5. Log IR `type` on unknown statements; fail closed.  
6. Use `--- ONLY` in `.t` files when debugging: stderr dumps Lua; `tmp/` gets `policy.lua`, `input.json`, `data.json`, and `run.sh`.  
7. Walk the §4 example end-to-end once by hand (plan + func locals) before automating.

---

## 11. Mapping IR statements → early priority

These ranks are **IR statement order** for codegen (unlock `t/*.t`). They are **not** builtin Need × Cost **P0–P3**.

| Rank | IR `type` | Needed for |
|----------|-----------|------------|
| must | `AssignVarStmt`, `AssignVarOnceStmt`, `ResetLocalStmt` | locals / `default` |
| must | `IsDefinedStmt`, `IsUndefinedStmt` | body vs `default` |
| must | `MakeNullStmt`, `MakeNumberIntStmt`, `MakeNumberRefStmt` | scalars |
| must | `DotStmt` | `input.method` |
| must | `EqualStmt`, `NotEqualStmt` | compares |
| must | `CallStmt`, `ReturnLocalStmt` | funcs |
| must | `MakeObjectStmt`, `ObjectInsertStmt`, `ResultSetAddStmt` | plan entry (then unwrap to rule value) |
| next | `MakeArrayStmt`, `ArrayAppendStmt` | arrays |
| next | `NotStmt` | `not` |
| next | `ScanStmt`, `IsArrayStmt` / other `Is*` | membership / iteration |
| later | `MakeSetStmt`, `SetAddStmt` | sets |
| later | `WithStmt`, `CallDynamicStmt`, more builtins | advanced |

---

## 12. Relation to other docs

| Doc | Role |
|-----|------|
| **This guide** | Production backend: **OPA IR → Lua** (shape, worked example, codegen plan) |
| [`rego-ir-by-example/`](./rego-ir-by-example/) | IR learning path: execution model, control flow, runnable plans, stmt catalog |
| `rego-builtins.md` | Full OPA built-in catalog (reference; not day-one backlog) |
| `rego-builtins-priority.md` | Which builtins we care about (Need × Cost → P0–P3) |
| `rego-builtins-runtime.md` | Builtins implement slices (pure LuaJIT → OpenResty backends) |
| `learning-tokenize.md` | Educational Rego lexer (not required if OPA is frontend) |
| `learning-ast.md` | Educational AST / recursive descent |
| `README.md` / `t/*.t` / `AGENTS.md` | Behavioral contract, module API, agent priorities |

**Layers of work**

1. **This guide + `t/*.t`** — IR statements and minimal runtime until `./go` is green on the IR path.  
2. **Builtins** — after (1); Need × Cost → P0–P3 in `rego-builtins-priority.md`, implement plan in `rego-builtins-runtime.md` (e.g. `regex.*` is P2 / slice 1.2).  
3. **Learning notes** — optional; do not rebuild OPA’s frontend.

---

## 13. References

- OPA IR documentation: https://www.openpolicyagent.org/docs/ir  
- IR Go package: https://github.com/open-policy-agent/opa/tree/main/v1/ir  
- Plan JSON Schema: https://openpolicyagent.org/schemas/ir/v1/plan.schema.json  
- OPA policy test suite (conformance inspiration): https://github.com/open-policy-agent/opa/tree/main/v1/test/cases  
- In-repo IR by example: [rego-ir-by-example/](./rego-ir-by-example/)  

---

## 14. Checklist

- [x] Minimal runtime (slice **1.1.1**): `runtime/` layers + `t/runtime.t`  
- [ ] Generate `plan.json` for `example.rego` / a `sanity` policy  
- [ ] Load IR in Python; print plan names and stmt type histogram  
- [ ] Hand-trace the §4 plan + func locals once  
- [ ] Implement **must** IR statements (codegen) on top of the runtime  
- [ ] Emit `package` module API matching product shape  
- [ ] Green: first case of `t/sanity.t` via IR path  
- [ ] Grow statement coverage until `./go` is IR-backed  
