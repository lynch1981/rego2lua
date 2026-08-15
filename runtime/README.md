# `runtime/` — Rego semantics for LuaJIT

Generated policy Lua does **control flow**. This directory does **Rego meaning** that plain Lua lacks (undefined, deep equality, types, numbers, …).

**You only need one entry point:**

```lua
local rt = assert(loadfile("runtime/rego_rt.lua"))()
-- later: require("rego_rt")
```

Everything else is split so each file teaches **one layer** of runtime design.

---

## Read this map first (beginner)

| Order | File | Layer | One-sentence job |
|------:|------|--------|------------------|
| 0 | **`rego_rt.lua`** | Facade | Loads layers; returns public `rt` |
| 1 | **`value.lua`** | Value model | UNDEF / NULL / make_* / table_kind (priv) |
| 2 | **`dot.lua`** | Field access | `rt.dot` (DotStmt) |
| 3 | **`types.lua`** | Type builtins | `priv.is_*` / `type_name` → CallStmt |
| 4 | **`compare.lua`** | Eq & order | `rt.values_equal` + `priv.equal` / `lt`… |
| 5 | **`numbers.lua`** | Number builtins | `priv.plus` … `numbers_range` → CallStmt |
| 6 | **`builtins.lua`** | IR dispatch | Wire `priv.*` into `rt.builtins` / `call_builtin` |

```text
  codegen
     │
     ▼
  rego_rt.lua          ◄── only public load path
     │
     ├─ value.lua        foundation (public kernel + priv helpers)
     ├─ dot.lua          public kernel
     ├─ types.lua        priv only → builtins
     ├─ compare.lua      values_equal public; equal/lt… priv → builtins
     ├─ numbers.lua      priv only → builtins
     └─ builtins.lua     CallStmt name table
```

---

## Codegen contract

**This is the law for IR → Lua.** The walker may only emit the public kernel and `rt.call_builtin`. Review generated Lua against these rules.

Also: [`docs/ir2lua-guide.md`](../docs/ir2lua-guide.md) §8 · slices: [`docs/rego-builtins-runtime.md`](../docs/rego-builtins-runtime.md).

### Allowed APIs

| Kind | Call these |
|------|------------|
| Load | facade only: `loadfile("runtime/rego_rt.lua")` / `require("rego_rt")` |
| Kernel | `UNDEF`, `is_undef`, `is_def`, `is_ok`, `NULL`, `dot`, `values_equal`, `make_array` / `make_object` / `make_set` |
| CallStmt | **`rt.call_builtin(name, …)` only** |

Do not emit `rt.plus`, `rt.equal`, `rt.is_string`, etc. Do not `require` layer files. Do not use `priv`. Prefer `call_builtin` over `rt.builtins[name]`.

### Rules

1. **Facade only** — one load path: `rego_rt.lua`.
2. **Slots** — every IR local is `rt.UNDEF` or a Rego value. Do not leave Lua `nil` if you use `is_def` (`is_def(nil)` is true today).
3. **UNDEF ≠ NULL ≠ nil** — missing path → `UNDEF`; JSON null → `rt.NULL`.
4. **IR statement → kernel** — `DotStmt` → `rt.dot`; `EqualStmt` → `rt.values_equal`; `Make*` → `make_*`; definedness → `is_def` / `is_undef`.
5. **CallStmt → `rt.call_builtin(name, …)`** — OPA names (`plus`, `equal`, `is_string`, `numbers.range`, …) only this way.
6. **Boolean CallStmt** — result is `true` \| `false` \| `UNDEF`. **Never** `if call_builtin(...)`. Use `rt.is_ok(...)`.
7. **Value CallStmt** (`plus`, `to_number`, …) — check `is_undef` / `is_def` on the result. `is_ok` is only for exact `true`.
8. **Fail closed** — unknown builtin or unknown stmt type → generate-time error (preferred) or runtime `UNDEF`. Do not invent APIs.

### Emit: good vs bad

```lua
-- good: EqualStmt
if not rt.values_equal(a, b) then goto fail end

-- good: CallStmt boolean
if rt.is_ok(rt.call_builtin("equal", a, b)) then
  -- matched
end

-- good: CallStmt value
local sum = rt.call_builtin("plus", a, b)
if rt.is_undef(sum) then goto fail end

-- bad: UNDEF is a table (truthy)
if rt.call_builtin("equal", a, b) then end

-- bad: free-floating builtin
local x = rt.plus(a, b)
```

---

## Design ideas (short)

1. **Not an interpreter** — no loop over IR statements here. Ops only.
2. **`UNDEF` is a value** — failures return `rt.UNDEF`, they do not throw.
3. **Kernel vs CallStmt** — stmt helpers on `rt`; OPA names only via `call_builtin`.
4. **Layers install into `rt` and/or `priv`** — facade wires load order.

---

## Tests

```bash
prove t/runtime.t
```

Loads only `runtime/rego_rt.lua`. Tests use kernel APIs + `call_builtin` (not `rt.plus`, etc.).

---

## How to add something new

| If you need… | Edit… |
|--------------|--------|
| Value / tagging | `value.lua` |
| DotStmt | `dot.lua` |
| New CallStmt type/number/compare op | implement on `priv` in the right layer + register in `builtins.lua` |
| New IR stmt helper for codegen | install on `rt` in the right layer; document here |

Then add a check in `t/runtime_rt.lua` and run `prove t/runtime.t`.

---

## Slice status

**1.1.1** — undefined, DotStmt, compare, types, numbers (this tree).  
Later slices add files or grow layers; keep the facade as the single entry.
