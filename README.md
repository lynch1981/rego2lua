# rego2lua

[![ci](https://github.com/lynch1981/rego2lua/actions/workflows/ci.yml/badge.svg)](https://github.com/lynch1981/rego2lua/actions/workflows/ci.yml)

Source-to-source compiler: **Rego** (OPA policy language) → **Lua** for **LuaJIT 2.1** / OpenResty.

Production path (no in-tree Rego frontend):

```text
Rego  →  OPA (`opa build -t plan`)  →  plan.json (IR)  →  rego2lua  →  Lua
```

Backend plan: [`docs/ir2lua-guide.md`](docs/ir2lua-guide.md). Agent notes: [`AGENTS.md`](AGENTS.md). Tags and CI: [`docs/releasing.md`](docs/releasing.md).

## Status (0.0.1)

**Developer preview.** Tag [`v0.0.1`](https://github.com/lynch1981/rego2lua/releases/tag/v0.0.1). Changelog: [`CHANGELOG.md`](CHANGELOG.md). License: [BSD-2-Clause](LICENSE).

Works today: `package`, `default`, `input.field == …`, implicit AND, `local :=`, nested object and array index, `not`, `!=` / order compares, scalars (string / number / boolean / null). Required bar [`./ci`](ci): `t/runtime.t`, `t/sanity.t`, `t/not.t`, `t/scalars.t`, `t/access.t`, `t/cmp_*.t`. Still failing: `in` / `some` (`t/membership.t`). `./go` is **not** green.

Generated Lua loads `runtime/rego_rt.lua` with a CWD-relative `loadfile`. Evaluate from the **repo root**.

### Quick start

Needs `opa`, Python 3, and LuaJIT 2.1 on `PATH`.

```bash
git clone https://github.com/lynch1981/rego2lua.git
cd rego2lua
./rego2lua path/to/policy.rego > policy.lua
# optional: also write the OPA plan IR the translator used
./rego2lua -d plan.json path/to/policy.rego > policy.lua
# evaluate from repo root so runtime/rego_rt.lua resolves
luajit t/eval_pkg.lua policy.lua '{"method":"GET"}' '{}'
```

## Docs

| Doc | Topic |
|-----|--------|
| [`docs/ir2lua-guide.md`](docs/ir2lua-guide.md) | **Backend plan:** OPA IR (JSON) → Lua; §8 points at the runtime contract |
| [`docs/rego-ir-by-example/`](docs/rego-ir-by-example/) | IR learning path: execution model, runnable plans, stmt catalog |
| [`docs/rego-builtins.md`](docs/rego-builtins.md) | Full OPA Rego built-in catalog (reference) |
| [`docs/rego-builtins-priority.md`](docs/rego-builtins-priority.md) | Which builtins we care about (Need × Cost → P0–P3) |
| [`docs/rego-builtins-runtime.md`](docs/rego-builtins-runtime.md) | How to implement those builtins (pure Lua → OpenResty) |
| [`docs/learning-tokenize.md`](docs/learning-tokenize.md) | Rego lexer / tokens (**learning only**) |
| [`docs/learning-ast.md`](docs/learning-ast.md) | AST + recursive-descent (**learning only**) |
| [`docs/releasing.md`](docs/releasing.md) | Version numbers, tags, GitHub pre-releases, CI |

**Runtime (in progress):** [`runtime/`](runtime/) — slice **1.1.1** (undefined, compare, types, numbers). Entry: `rego_rt.lua`; layers explained in [`runtime/README.md`](runtime/README.md). Unit tests: `prove t/runtime.t`.

**Layers of work** (do not mix priorities):

1. **Runtime + IR → Lua for current tests** — grow `runtime/` layers, unlock `t/*.t` / `./go` (see IR guide, IR-by-example, `AGENTS.md`).
2. **Builtins** — priority (P0–P3) in `rego-builtins-priority.md`, implement slices in `rego-builtins-runtime.md` (**1.1.1** done).
3. **Full catalog** — `rego-builtins.md` is lookup only, not a backlog.
4. **Learning notes** — optional; not the production pipeline.

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
| `ref_lua` | bootstrap | Hand-written **reference Lua** that implements the same policy. Used only when `rego2lua` is not built yet, so tests can still check behavior. Not the primary success criterion. Generated modules must use `rule(input, data)`; bootstrap refs may omit `data` if unused (the harness still passes both). |
| `out` | **yes** | Expected evaluation result as JSON. Keys are **rule names**, values are rule results (e.g. `{ "allow": false }`). |
| `ONLY` | debug | **Test::Base** built-in: run only this block. The harness **prints the Lua under test** and writes `tmp/{policy.lua,input.json,data.json,plan.json,run.sh}` so you can re-eval with `./tmp/run.sh`. Remove before commit. |

\* If `input` or `data` is omitted or empty, the harness treats it as `{}`.

### Debugging with `ONLY`

Stderr shows the generated (or reference) Lua. The harness also dumps the module plus `input` / `data` JSON and the OPA `plan.json` to `tmp/` (gitignored) and writes `tmp/run.sh`, which re-runs the same `t/eval_pkg.lua` evaluation from the repo root. Do not leave `ONLY` in committed tests.

### How a case is judged

1. Compile `Rego` with `./rego2lua` when present; otherwise use `ref_lua`.
2. Run the module under **LuaJIT**, calling each rule with `(input, data)`.
3. Compare the result to `out` (deep equality).

Success is matching `out`, not matching `ref_lua` source text.

**Module API:** every rule is `function <pkg>.<rule>(input, data)` and returns the rule value. The product/generated shape always takes both arguments. Bootstrap `ref_lua` may declare only `input` when `data` is unused — Lua ignores the extra argument the harness still passes.

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
package foo

default allow := false

allow if {
    input.a == input.b
}
--- ref_lua
local foo = {}

function foo.allow(input, data)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if a ~= nil and b ~= nil and a == b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}
```

### Run tests

```bash
# required CI bar (GitHub Actions on pull requests)
./ci

# runtime unit tests (no policy)
prove t/runtime.t

# policy fixtures (start here after runtime)
prove t/sanity.t

# all suites: runtime first, then language / compares (not yet green)
./go
```

Pull requests run `./ci` on GitHub Actions (Ubuntu 24.04, OPA **1.18.2**). How that job installs OPA: [`docs/releasing.md`](docs/releasing.md#ci). Expand `./ci` when a suite goes fully green; do not treat `./go` as the gate until it is.

Requirements:

| Dependency | Debian/Ubuntu package | Notes |
|------------|----------------------|--------|
| LuaJIT 2.1 | `luajit` | Policy evaluation |
| lua-cjson | `lua-cjson` | Used by `t/eval_pkg.lua` |
| Test::Base | `libtest-base-perl` | `.t` harness |
| JSON::PP | (Perl core) | Harness JSON |
| OPA | install from [openpolicyagent.org](https://www.openpolicyagent.org/docs/latest/#running-opa) | `opa build -t plan` for IR generation (IR → Lua path) |

See `AGENTS.md` for compiler output conventions and agent-oriented project notes.
