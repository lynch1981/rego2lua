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
```

## Repo layout

| Path | Role |
|------|------|
| `t/*.rego` | Sample Rego policies |
| `t/*.lua` | Hand-translated (or later: compiler-emitted) Lua for those policies |
| `t/test_simple_allow.lua` | Self-check under LuaJIT |

Run tests from the repo root:

```bash
luajit t/test_simple_allow.lua
```

## When changing examples

1. Edit the `.rego` file.
2. Update the matching `.lua` translation (header Rego + body).
3. Update / run `t/test_simple_allow.lua` with **`luajit`**.
