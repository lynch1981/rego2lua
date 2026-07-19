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
| `t/*.rego` | Sample Rego policies (compiler input / golden sources) |
| `t/*.lua` | Hand-translated Lua for those policies (expected output, for now) |
| `t/test_*.lua` | Behavioral checks under LuaJIT |

### First-step fixtures

Start with small policies that exercise one idea each:

| Files | What it covers |
|-------|----------------|
| `simple-allow.rego` + `.lua` | `default`, local `:=` binding, compare to string |
| `simple-allow2.rego` + `.lua` | same decision via direct `input.field` compare |
| `cmp_eq.rego` + `.lua` | `==` |
| `cmp_ne.rego` + `.lua` | `!=` |
| `cmp_gt.rego` + `.lua` | `>` |
| `cmp_gte.rego` + `.lua` | `>=` |
| `cmp_lt.rego` + `.lua` | `<` |
| `cmp_lte.rego` + `.lua` | `<=` |

`simple-allow*` should allow only when `input.method == "GET"`.  
Each comparison op is its **own** golden pair so you can implement and test one operator at a time.

Run one suite:

```bash
luajit t/test_cmp_eq.lua
```

Run all suites:

```bash
luajit t/run_all.lua
```



## When changing examples

1. Edit the `.rego` file.
2. Update the matching `.lua` translation (header Rego + body).
3. Update / run the matching `t/test_*.lua` with **`luajit`**.

## Suggested next fixtures (later)

Add new pairs only when the compiler needs a new language feature, for example:

- multi-statement bodies
- `not`
- multiple rules for one name
- nested `input` fields
