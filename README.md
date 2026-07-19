# rego2lua

Source-to-source compiler: **Rego** (OPA policy language) → **Lua** for **LuaJIT 2.1** / OpenResty.

## Test cases (`t/*.t`)

Regression tests use OpenResty-style Perl `Test::Base` files. Each file ends with a `__DATA__` section made of one or more cases:

```text
=== TEST n: short description
--- input
...
--- data
...
--- Rego
...
--- ref_lua
...
--- out
...
```

### What each section means

| Section | Required | Meaning |
|---------|----------|---------|
| `TEST` | yes | Case title (shown in `prove` output). |
| `input` | yes* | JSON **input** document. This is OPA/Rego `input` — the request or subject the policy decides on (e.g. `{ "a": 10, "b": 11 }`). |
| `data` | yes* | JSON **data** document. This is OPA/Rego `data` — shared base facts the policy may read. Use `{}` when unused. |
| `Rego` | **yes** | Full Rego policy source. This is the **compiler input** for `rego2lua`. |
| `ref_lua` | bootstrap | Hand-written **reference Lua** that implements the same policy. Used only when `rego2lua` is not built yet, so tests can still check behavior. Not the primary success criterion. |
| `out` | **yes** | Expected evaluation result as JSON. Keys are **rule names**, values are rule results (e.g. `{ "eq": false }`). |
| `ONLY` | debug | **Test::Base** built-in: run only this block. Our harness also **prints the Lua under test** (from `rego2lua`, or `ref_lua` in bootstrap mode). Remove before commit. |

\* If `input` or `data` is omitted or empty, the harness treats it as `{}`.

### Debugging with `ONLY`

Stderr shows the generated (or reference) Lua so you can inspect it while debugging. Do not leave `ONLY` in committed tests.

### How a case is judged

1. Compile `Rego` with `./rego2lua` when present; otherwise use `ref_lua`.
2. Run the module under **LuaJIT**, calling each rule with `(input, data)`.
3. Compare the result to `out` (deep equality).

Success is matching `out`, not matching `ref_lua` source text.

### Example

```text
=== TEST 1: simple eq (unequal numbers)
--- input
{
    "a": 10,
    "b": 11
}
--- data
{
}
--- Rego
package cmp

default eq := false

eq if {
    input.a == input.b
}
--- ref_lua
local cmp = {}

function cmp.eq(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local eq = false
  if a ~= nil and b ~= nil and a == b then
    eq = true
  end
  return eq
end

return cmp
--- out
{
    "eq": false
}
```

### Run tests

```bash
# one file
prove t/cmp_eq.t

# all .t tests
prove t/*.t
```

Requirements:

| Dependency | Debian/Ubuntu package | Notes |
|------------|----------------------|--------|
| LuaJIT 2.1 | `luajit` | Policy evaluation |
| lua-cjson | `lua-cjson` | Used by `t/eval_pkg.lua` |
| Test::Base | `libtest-base-perl` | `.t` harness |
| JSON::PP | (Perl core) | Harness JSON |

See `AGENTS.md` for compiler output conventions and agent-oriented project notes.
