# AGENTS.md

Guidance for humans and coding agents working in this repo.

## Goal

Build **`rego2lua`**: turn Rego policies into **Lua** that makes the **same decisions**.

**Target product is unchanged:** Lua modules for **LuaJIT 2.1 / OpenResty**.

**Implementation path is short:** we do **not** implement a full Rego frontend in this repo. We start from **OPA’s official plan IR (JSON)** and focus on **IR → Lua**.

```text
Rego source  ──►  OPA (`opa build -t plan`)  ──►  plan.json (IR)  ──►  rego2lua  ──►  Lua
                     (existing tool)                  (our work)
```

| Stage | Who | Notes |
|-------|-----|--------|
| Rego → IR | **OPA** | Lex, parse, compile to plan IR |
| IR → Lua | **This project** | Walk IR, emit Lua + small runtime helpers |
| Run / test | **LuaJIT** + `t/*.t` | Behavior must match `--- out` |

Keep the translator small and correct. Prefer a working subset of IR/statement types over full OPA feature coverage until the scope is expanded.

Primary design doc: **`doc/IR_to_Lua_Guide.md`**.

Optional background only (not the production pipeline):

- `doc/learning-tokenize.md` — Rego lexer (learning)
- `doc/learning-ast.md` — AST / recursive descent (learning)

## Target runtime

Generated Lua must run on **LuaJIT 2.1** (OpenResty; Lua **5.1** language level + LuaJIT extensions).

| Do | Don't |
|----|--------|
| Write Lua 5.1 / LuaJIT 2.1 code | Use Lua 5.2+ / 5.3 / 5.4-only features |
| Test with `luajit` | Rely on `lua` / `lua5.4` as the primary check |

## What agents should implement

1. Obtain IR: `opa build -t plan -e <entrypoint> <policy.rego>` → `plan.json`.
2. Translate IR → Lua (Python is the intended backend language; see the IR guide).
3. Ship a small **Lua runtime** for Rego semantics Lua tables lack (undefined, sets, `not`, scan, …).
4. Expose a stable **module API** (below) so tests and OpenResty callers look the same.
5. Grow statement coverage in lockstep with `t/*.t` (start with `sanity.t`).

Do **not** spend effort re-building OPA’s lexer/parser unless the project explicitly pivots.

## Generated Lua module shape

Output must satisfy:

1. **Optional header** — original Rego as `--` line comments is fine (and useful for debugging).
2. **No other comments** in the body (no EmmyLua, no restated IR notes).
3. **Same decisions** as Rego for the given `input` / `data`.
4. **Rule name = function name**
   - `package foo` → module table `foo`
   - rule `allow` → `function foo.allow(input, data)` returning the rule value
   - Do not invent APIs (`eval`, `check`, …) that are not Rego rules

### Example shape

```lua
-- package foo
-- default allow := false
-- allow if { input.method == "GET" }

local foo = {}

function foo.allow(input, data)
  -- generated from IR (or bootstrap ref)
  return allow
end

return foo
```

## Repo layout

| Path | Role |
|------|------|
| `doc/IR_to_Lua_Guide.md` | **Main** implementation plan (IR → Lua) |
| `doc/learning-*.md` | Optional learning notes (lexer/AST); not the short path |
| `t/*.t` | Behavioral regression tests |
| `t/Rego.pm` | Harness: get Lua → run under LuaJIT → compare `--- out` |
| `t/eval_pkg.lua` | Call each exported rule; print JSON (`lua-cjson`) |
| `opa/` | Local OPA plan examples / helpers (if present) |

## Tests (`t/*.t`)

OpenResty-style `Test::Base` files. Success = **Lua behavior matches `--- out`**, not that source equals `--- ref_lua`.

| Section | Meaning |
|---------|---------|
| `input` | JSON OPA/Rego **input** |
| `data` | JSON OPA/Rego **data** (often `{}`) |
| `Rego` | Policy source (OPA produces IR from this; human-readable fixture) |
| `ref_lua` | Hand reference Lua — **bootstrap** until IR→Lua works |
| `out` | Expected `{ rule_name: value, ... }` |
| `ONLY` | Test::Base: run only this block; harness prints Lua under test |

Notes:

- Section name is `ref_lua` (underscore). `ref-lua` is wrong (Test::Base treats `-` as a filter).
- Leave **three blank lines** between `=== TEST` cases (OpenResty style).

### What the harness does today

1. If `./rego2lua` (or `$REGO2LUA`) exists: produce Lua from the policy (intended: Rego→OPA IR→Lua).
2. Else: use `--- ref_lua` (bootstrap).
3. Run under **LuaJIT** via `t/eval_pkg.lua` with `input` / `data`.
4. Deep-compare result to `--- out`.

### Run

```bash
prove t/sanity.t    # start here
./go                # full suite, simple first
```

Needs: `luajit`, `lua-cjson`, `opa` (for IR generation), Perl `Test::Base` (`libtest-base-perl`), `JSON::PP`.

### Suites (`./go` order)

| File | Covers |
|------|--------|
| `sanity.t` | `default`, field compare, AND, `not`, local `:=` |
| `scalars.t` | string, number, boolean, null |
| `access.t` | object `.`, array `[i]`, nested |
| `membership.t` | `"x" in arr`, `arr[_] == "x"` |
| `cmp_*.t` | `==` `!=` `>` `>=` `<` `<=` |

Implement IR statement support in roughly this order so tests unlock early (details in `doc/IR_to_Lua_Guide.md`).
