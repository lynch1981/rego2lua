# AGENTS.md

Guidance for humans and coding agents working in this repo.

## Goal

Build a simple **source-to-source compiler** called **`rego2lua`**.

- **Input:** Rego policy (OPA policy language)
- **Output:** Lua that implements the same decisions

Keep the compiler small and correct. Prefer a working subset over a full OPA clone until the scope is explicitly expanded.

## Target runtime

Generated Lua must run on **LuaJIT 2.1** — the same engine OpenResty uses (Lua **5.1** language level, plus LuaJIT extensions).

| Do | Don't |
|----|--------|
| Write Lua 5.1 / LuaJIT 2.1 code | Use Lua 5.2+ / 5.3 / 5.4-only features |
| Test with `luajit` | Rely on `lua` / `lua5.4` as the primary check |

## Generated Lua file shape

For each Rego source file, emit a Lua module that follows these rules:

1. **Header = the Rego source**  
   Put the full Rego text at the top of the `.lua` file as line comments (`-- ...`).  
   A single first line naming the source file is fine, for example:
   `-- simple-allow.rego`

2. **No other comments**  
   Do not add EmmyLua annotations, restated rule comments in the body, or other explanatory comments outside that header.

3. **Preserve semantics**  
   Defaults, rule bodies, and local bindings must match the Rego policy.

4. **Rule name = function name**  
   - Rego `package foo` → Lua module table `foo`  
   - Rego rule `allow` → `function foo.allow(input)` returning the rule value  
   - Do not invent extra API names (`eval`, `check`, …) for rules that do not exist in the Rego

### Example header

Only the Rego appears as comments; the rest of the file is uncommented code:

```lua
-- simple-allow.rego
--
-- package foo
--
-- default allow := false
--
-- allow if {
--     method := input.method
--     method == "GET"
-- }

local foo = {}

function foo.allow(input)
  -- ...
  return allow
end

return foo
```


## Repo layout

| Path | Role |
|------|------|
| `t/*.t` | Regression tests (Test::Base / `t::Rego`) |
| `t/Rego.pm` | Test harness: compile (or use ref Lua) → eval → compare `--- out` |
| `t/eval_pkg.lua` | LuaJIT helper: load module, call each rule, print JSON result |

## Primary test format (`t/*.t`)

OpenResty-style `__DATA__` blocks. Each case has:

| Section | Meaning |
|---------|---------|
| `--- input` | JSON **input** document for the policy |
| `--- data` | JSON **data** document (may be `{}`) |
| `--- Rego` | Rego policy source (compiler input) |
| `--- ref_lua` | Reference Lua translation (bootstrap until `rego2lua` exists) |
| `--- out` | Expected evaluation result (JSON object of rule → value) |
| `--- ONLY` | Test::Base: run only this block; harness prints Lua under test |

Note: use `ref_lua` (underscore), not `ref-lua`. In Test::Base, text after a hyphen is a **filter** name (`--- ref-lua` would be section `ref` + filter `lua`).

### What the harness checks

1. If `./rego2lua` (or `$REGO2LUA`) is executable: compile `--- Rego` → Lua.
2. Else: use `--- ref_lua` as the module under test (bootstrap mode).
3. Load the module with **LuaJIT**, call each exported rule function with `(input, data)`.
4. Require the JSON result to match `--- out` deeply.

Goal: **behavior of generated Lua equals `--- out`**, not string-identity with `--- ref_lua` (the ref is a guide and a bootstrap fallback).

### Example (from `t/cmp_eq.t`)

```
=== TEST 1: simple eq (unequal numbers)
--- input
{ "a": 10, "b": 11 }
--- data
{}
--- Rego
package cmp
default eq := false
eq if { input.a == input.b }
--- ref_lua
... reference module with cmp.eq ...
--- out
{ "eq": false }
```

### Run

```bash
# one file
prove t/cmp_eq.t

# all .t tests
prove t/*.t
```

Needs: `luajit`, `lua-cjson`, Perl `Test::Base` (`libtest-base-perl`), `JSON::PP` (core).

## Generated Lua API (for `--- ref_lua` / compiler output)

- `package foo` → module table `foo`
- rule `eq` → `function foo.eq(input, data)` returning the rule value  
  (`data` may be ignored when unused)
- Header comments = full Rego source; no other body comments

## Current `.t` suites

| File | Covers |
|------|--------|
| `simple-allow.t` | `default`, local `:=` binding |
| `simple-allow2.t` | direct `input.field` compare |
| `cmp_eq.t` … `cmp_lte.t` | comparison operators one op each |
