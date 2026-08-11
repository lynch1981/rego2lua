# Rego Built-ins Runtime (Pure Lua → OpenResty)

Implementer companion to [`rego-builtins-priority.md`](./rego-builtins-priority.md).

| Doc | Audience | Content |
| --- | --- | --- |
| [`rego-builtins-priority.md`](./rego-builtins-priority.md) | Project priority | **Need × Cost → P0–P3** (what we care about) |
| **This file** | Runtime implementers | **How / when:** pure Lua first, then OpenResty |

**Difficulty / cost scale:** Easy · Medium · Hard · Platform · Very hard  
(same scale as the priority doc)

---

## Two-step model

Final product runs on **OpenResty**. Develop and test on **plain LuaJIT** first.

```text
plan.json  ──►  rego2lua  ──►  portable Lua module
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
           Step 1 — develop / CI              Step 2 — product
           LuaJIT + pure runtime              OpenResty backend
           prove t/*.t                        ngx / resty adapters
```

| Step | Runtime | Goal | What may use |
| --- | --- | --- | --- |
| **1** | Plain **LuaJIT** | Correct decisions; green `prove t/*.t` | Pure Lua, LuaJIT `bit.*`, optional portable C (`cjson`) |
| **2** | **OpenResty** | Same modules in the gateway | Step 1 core + `ngx.*` / `resty.*` backends |

**Rules**

1. Generated policy code and **core** runtime never call `ngx.*` directly.
2. Platform builtins go through a small **backend** interface (`regex_match`, `base64_decode`, …).
3. Step 1 is the default CI bar. Step 2 only adds adapters + request wiring.

---

## Slice map

Two axes only:

| Axis | Doc | Meaning |
| --- | --- | --- |
| **P0–P3** | [`rego-builtins-priority.md`](./rego-builtins-priority.md) | Per-function priority (Need × Cost) |
| **Slice** (`1.1.1` … `3.2`) | this file | CI / implement order + deps |

**P-band ≠ slice.** A slice groups work by cohesion and deps; it may mix P-items (e.g. `count` is P0 but lands in **1.1.4**). This table is **build order only** (basic fields). **What** each slice contains is under [Slice details](#slice-details) — same ids, full function lists.

| Order | Slice | P-band | Step | Dep | Status |
| ---: | --- | --- | --- | --- | --- |
| 1 | 1.1.1 | mostly P0 | 1 pure | none | done |
| 2 | 1.1.2 | mostly P0 | 1 pure | none | todo |
| 3 | 1.1.3 | mostly P0 | 1 pure | none | todo |
| 4 | 1.1.4 | P0–P1 mix | 1 pure | none | todo |
| 5 | 1.1.5 | mostly P1 | 1 pure | bit | todo |
| 6 | 2.1.1 | mostly P1 | 1 pure | none | todo |
| 7 | 2.1.2 | mostly P1 | 1 pure | cjson | todo |
| 8 | 2.1.3 | mostly P2 | 1 pure | none | todo |
| 9 | 1.2 | P2 | 2 OpenResty | ngx.re | todo |
| 10 | 2.2 | P2 | 2 OpenResty | ngx | todo |
| 11 | 3.1 | P3 | 1 pure | none | todo |
| 12 | 3.2 | P3 | 2 OpenResty | openssl | todo |

```text
Step 1 CI:   1.1.1 → 1.1.2 → 1.1.3 → 1.1.4 → 1.1.5 → 2.1.1 → 2.1.2 → 2.1.3
Step 2:      + 1.2 (regex) → 2.2 → 3.2   (3.1 can land in Step 1 when needed)
```

### Minimal deps

```text
Step 1:  pure Lua · bit.* (1.1.5) · cjson (2.1.2)
Step 2:  + ngx.re (1.2) · resty.openssl / resty.jwt (3.2 as needed)
```

---

## Backend contract (sketch)

```lua
-- backend/pure.lua  or  backend/openresty.lua
return {
  regex_match    = function(pattern, value) ... end,
  regex_is_valid = function(pattern) ... end,
  regex_replace  = function(s, pattern, value) ... end,
  base64_decode  = function(s) ... end,
  base64_encode  = function(s) ... end,
  json_decode    = function(s) ... end,
  json_encode    = function(v) ... end,
  -- crypto / time when 3.x ships
}
```

OPA regex is **RE2 / Go**-style. `ngx.re` / PCRE is close for most WAF signatures but **not** bit-identical to OPA.

---

## Dependency legend

| Dep | Step | Used for |
| --- | --- | --- |
| *(none)* | 1 & 2 | stdlib / small in-repo pure Lua |
| `bit` | 1 & 2 | LuaJIT `bit.*` — **1.1.5** |
| `cjson` | 1 & 2 | JSON — **2.1.2**; already in `t/eval_pkg.lua` |
| `ngx.re` / PCRE | **2** | `regex.*` — **1.2** |
| `ngx.decode_base64` / encode | **2** | optional **2.2** |
| `ngx.unescape_uri` | **2** | optional **2.2** |
| `resty.openssl` / `luaossl` | **2** | **3.2** crypto |
| `resty.jwt` | **2** | **3.2** JWT verify |
| `ngx.now` | **2** | optional time |

---

## Slice details

Extension of the [slice map](#slice-map): same order and ids; here is **what** each slice ships (functions, notes, gaps).

IR **field access** (`input.method`) is codegen + `rt.dot` (**1.1.1**), not `object.*` (**1.1.2**).

### 1.1.1 — Compare, types, numbers

**Status: done** — [`runtime/rego_rt.lua`](../runtime/rego_rt.lua) · `prove t/runtime.t` · codegen notes: [`ir2lua-guide.md` §8](./ir2lua-guide.md#8-runtime-helpers-lua).

What: compare, types, numbers; UNDEF / `dot` / `rt.builtins`.

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `equal` / `neq` | Easy | *(none)* | Deep eq; UNDEF args → UNDEF |
| `gt` / `gte` / `lt` / `lte` | Easy | *(none)* | OPA type-rank order |
| `is_string` / `is_number` / `is_array` / `is_object` / `is_boolean` / `is_null` | Easy | *(none)* | Array vs object: tags + heuristic |
| `type_name` | Easy | *(none)* | |
| `to_number` | Easy | *(none)* | Invalid → UNDEF |
| `plus` / `minus` / `mul` / `div` / `rem` | Easy | *(none)* | Soft UNDEF on type/zero errors |
| `abs` | Easy | *(none)* | |
| `numbers.range` | Easy | *(none)* | |

Also in **1.1.1** (IR helpers, not OPA builtins): `rt.UNDEF` / `is_undef` / `is_def`, `rt.NULL`, `rt.dot`, `make_array` / `make_object` / `make_set`, `rt.builtins` / `call_builtin`.

**Language (codegen):** `:=` · `default` · basic `not` (later).

**Follow-ups before IR wiring:** array Dot 0-based vs Lua 1-based; empty `[]` vs `{}` from cjson; `to_number` string parity with OPA.

### 1.1.2 — Object helpers

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `object.get` | Easy | *(none)* | Default when key missing |
| `object.keys` | Easy | *(none)* | Order not guaranteed |
| `object.filter` | Easy | *(none)* | |
| `object.remove` | Easy | *(none)* | |
| `object.subset` | Medium | *(none)* | Nested deep compare |

### 1.1.3 — Strings

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `contains` / `startswith` / `endswith` | Easy | *(none)* | |
| `lower` / `upper` | Easy | *(none)* | Unicode case limited |
| `split` / `concat` | Easy | *(none)* | |
| `substring` / `indexof` / `replace` | Easy | *(none)* | |
| `trim` / `trim_space` / `trim_prefix` / `trim_suffix` | Easy | *(none)* | Starter: `trim_space` |
| `sprintf` | Medium | *(none)* | Go `fmt` ≠ `string.format` |

### 1.1.4 — Collections, scan, sets

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `count` | Easy | *(none)* | String vs collection |
| `in` | Easy–Medium | *(none)* | Membership |
| `array.concat` / `slice` / `flatten` | Easy | *(none)* | |
| `intersection` / `union` / set `and` / `or` / `minus` | Medium | *(none)* | Set model |

**Language:** `in` · `_` (scan).

### 1.1.5 — Glob & network (CIDR)

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `glob.match` | Medium | *(none)* | Delimiter-aware `**` |
| `net.cidr_contains` | Medium* | `bit` | *IPv4 first; IPv6 Hard |
| `net.cidr_intersects` | Medium* | `bit` | |
| `net.cidr_is_valid` | Medium* | `bit` | |
| `net.cidr_contains_matches` | Medium* | `bit` | Batch |

### 1.2 — Regex (OpenResty)

| Function | Difficulty | Backend | Notes |
| --- | --- | --- | --- |
| `regex.match` | Easy–Medium | `ngx.re.match` | Do **not** hand-roll RE2 in Step 1 |
| `regex.is_valid` | Easy–Medium | compile-and-catch | |
| `regex.replace` | Easy–Medium | `ngx.re.gsub` | Capture syntax may differ |
| `regex.find_n` / `regex.split` | Medium | `ngx.re` glue | |

CI without nginx: stub/skip, or `lrexlib` / PCRE, until product smoke with `ngx.re`.

### 2.1.1 — Wire encoding

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `base64.decode` / `encode` / `is_valid` | Medium | pure-Lua | Padding / invalid input |
| `base64url.decode` / `encode` | Medium | pure-Lua | |
| `hex.decode` / `encode` | Easy | *(none)* | |
| `urlquery.decode` / `encode` / `decode_object` / `encode_object` | Medium | pure-Lua | |

### 2.1.2 — JSON (`cjson`)

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `json.is_valid` / `unmarshal` / `marshal` | Easy (w/ cjson) | `cjson` | |
| `json.filter` / `remove` | Medium | `cjson` + paths | |

Defer: `json.patch`, `json.match_schema`, `json.verify_schema` (Hard / Very hard).

### 2.1.3 — URI & string extras

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `uri.parse` / `uri.is_valid` | Medium | pure-Lua | |
| `strings.count` / `any_prefix_match` / `any_suffix_match` | Easy | *(none)* | |
| `strings.replace_n` | Medium | *(none)* | |
| `indexof_n` / `format_int` | Easy | *(none)* | |

### 2.2 — Optional OpenResty overrides

Same names as pure; swap backend only (`ngx.decode_base64`, `ngx.unescape_uri`, …). Keep pure if parity is good.

### 3.1 — Time, units, JWT decode (pure)

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `io.jwt.decode` | Medium | pure + `cjson` | No verify |
| `time.now_ns` / parse / `diff` / `add_date` | Easy–Hard | pure-Lua | `now_ns` non-deterministic |
| `units.parse_bytes` / `units.parse` | Easy–Medium | *(none)* | |
| `trace` | Easy | *(none)* | No-op in prod OK |

### 3.2 — JWT verify & crypto (OpenResty)

| Function | Difficulty | Backend | Notes |
| --- | --- | --- | --- |
| `io.jwt.decode_verify` / `verify_*` | Medium | `resty.jwt` + openssl | |
| `crypto.sha*` / `hmac.*` | Easy | `resty.openssl` | `hmac.equal` constant-time |
| `time.now_ns` | Easy | `ngx.now` | Optional override of 3.1 |

---

## Out of scope

| Category | Why skip |
| --- | --- |
| GraphQL, `http.send`, DNS lookup | Side effects / not WAF core |
| `net.cidr_expand`, graph walk | Prefer `cidr_contains` |
| YAML, X.509 / mTLS suite | Edge / other layers |
| `providers.aws.*`, `opa.runtime`, `rand.intn` | Meta / non-deterministic |
| `semver.*` / `uuid.*` | Rare |

---

## Layout

**Today (1.1.1):**

```text
runtime/rego_rt.lua     # core + rt.builtins
t/runtime.t             # prove entry
t/runtime_rt.lua        # unit checks (TAP)
```

**Later** (only if size or a second backend forces a split):

```text
runtime/
  rego_rt.lua           # facade (optional)
  core/                 # pure slices
  builtins/             # name → core + backend
  backend/
    pure.lua
    openresty.lua
```

See also: [`rego-builtins-priority.md`](./rego-builtins-priority.md), [`ir2lua-guide.md`](./ir2lua-guide.md) §8, `AGENTS.md`, catalog [`rego-builtins.md`](./rego-builtins.md).
