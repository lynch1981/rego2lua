# WAF Built-ins: Runtime Tiers (Pure Lua → OpenResty)

Implementer companion to [`rego-builtins-waf.md`](./rego-builtins-waf.md).

| Doc | Audience | Content |
| --- | --- | --- |
| [`rego-builtins-waf.md`](./rego-builtins-waf.md) | Product / rule authors | Which funcs WAF needs, **usage** tiers |
| **This file** | Runtime implementers | **How** to implement: pure Lua first, OpenResty adapters second |

**Difficulty scale:** Easy · Medium · Hard · Very hard

---

## Two-step model

Final product runs on **OpenResty**. This repo develops and tests on **plain LuaJIT** first.

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

Product **usage** tiers (Tier 1 / 2 / 3) still come from [`rego-builtins-waf.md`](./rego-builtins-waf.md). This file splits each into pure-Lua slices (**\*.1.x**) and OpenResty (**\*.2**):

```text
Tier 1  (use constantly)
  1.1.1  pure — compare, types, numbers
  1.1.2  pure — object.*
  1.1.3  pure — strings
  1.1.4  pure — collections, scan, sets
  1.1.5  pure — glob + CIDR
  1.2    OpenResty — regex

Tier 2  (encoding / body)
  2.1.1  pure — base64 / hex / urlquery
  2.1.2  pure + cjson — json
  2.1.3  pure — uri + string extras
  2.2    OpenResty — optional platform overrides

Tier 3  (auth / time / crypto)
  3.1    pure — jwt decode, time parse, units, trace
  3.2    OpenResty — jwt verify, crypto
```

---

## Backend contract (sketch)

Both backends implement the same surface; core builtins call this table only.

```lua
-- backend/pure.lua  or  backend/openresty.lua
return {
  regex_match    = function(pattern, value) ... end,
  regex_is_valid = function(pattern) ... end,
  regex_replace  = function(s, pattern, value) ... end,
  base64_decode  = function(s) ... end,
  base64_encode  = function(s) ... end,
  json_decode    = function(s) ... end,  -- often wraps cjson in both steps
  json_encode    = function(v) ... end,
  -- crypto / time only when Tier 3 ships
}
```

Dialect note: OPA regex is **RE2 / Go**-style. `ngx.re` / PCRE is close for most WAF signatures but **not** bit-identical to OPA.

---

## Dependency legend

| Dep | Step | Used for |
| --- | --- | --- |
| *(none)* | 1 & 2 | stdlib / small in-repo pure Lua |
| `bit` | 1 & 2 | LuaJIT `bit.*` (IPv4 CIDR) — from **1.1.5** |
| `cjson` | 1 & 2 | JSON — from **2.1.2**; already in `t/eval_pkg.lua` |
| `ngx.re` / PCRE | **2** (or `lrexlib` in CI) | `regex.*` — **1.2** |
| `ngx.decode_base64` / encode | **2** | optional **2.2** |
| `ngx.unescape_uri` | **2** | optional **2.2** |
| `resty.openssl` / `luaossl` | **2** | **3.2** crypto |
| `resty.jwt` | **2** | **3.2** JWT verify |
| `ngx.now` | **2** | optional time |

---

## Tier 1 — Use constantly

WAF rules hit these every day (path, header, IP, method, query, simple payload).

### Tier 1.1 — Pure Lua (Step 1)

Implement and test on plain LuaJIT. No `ngx.*`. One concern per slice.

IR **field access** (`input.method`, nested paths) is codegen, not `object.*`. Keep those separate: lower field access with **1.1.1**, ship the `object.*` builtins as **1.1.2**.

#### Tier 1.1.1 — Compare, types, numbers

Unlocks scalar decisions and `cmp_*.t` / parts of `sanity.t`.

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `equal` (`==`) | Easy | *(none)* | Undefined ≠ Lua `nil` |
| `neq` (`!=`) | Easy | *(none)* | |
| `gt` / `gte` / `lt` / `lte` | Easy | *(none)* | |
| `is_string` / `is_number` / `is_array` / `is_object` / `is_boolean` / `is_null` | Easy | *(none)* | Array vs object tables |
| `type_name` | Easy | *(none)* | |
| `to_number` | Easy | *(none)* | Invalid → undefined |
| `plus` / `minus` / `mul` / `div` / `rem` | Easy | *(none)* | |
| `abs` | Easy | *(none)* | |
| `numbers.range` | Easy | *(none)* | |

**Language features (with 1.1.1)**

| Feature | Difficulty | Notes |
| --- | --- | --- |
| `:=` | Easy | Locals in generated Lua |
| `default` | Easy | Default rule values |
| `not` | Medium | Can start here; full power with scan later |

#### Tier 1.1.2 — Object helpers

Safe lookup / shape ops for headers, query maps, config bags. Distinct from IR path access.

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `object.get` | Easy | *(none)* | Default when key missing (WAF headers) |
| `object.keys` | Easy | *(none)* | Key order not guaranteed |
| `object.filter` | Easy | *(none)* | Keep selected keys |
| `object.remove` | Easy | *(none)* | Drop hop-by-hop noise |
| `object.subset` | Medium | *(none)* | Nested deep compare |

#### Tier 1.1.3 — Strings

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `contains` | Easy | *(none)* | |
| `startswith` | Easy | *(none)* | |
| `endswith` | Easy | *(none)* | |
| `lower` / `upper` | Easy | *(none)* | Unicode case limited |
| `split` | Easy | *(none)* | |
| `concat` | Easy | *(none)* | |
| `substring` | Easy | *(none)* | Offset / length edge cases |
| `indexof` | Easy | *(none)* | |
| `replace` | Easy | *(none)* | All-occurrences semantics |
| `trim` / `trim_space` / `trim_prefix` / `trim_suffix` | Easy | *(none)* | Starter: `trim_space` |
| `sprintf` | Medium | *(none)* | Go `fmt` ≠ `string.format` |

#### Tier 1.1.4 — Collections, scan, sets

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `count` | Easy | *(none)* | String vs collection |
| `in` | Easy–Medium | *(none)* | Membership |
| `array.concat` | Easy | *(none)* | |
| `array.slice` | Easy | *(none)* | |
| `array.flatten` | Easy | *(none)* | |
| `intersection` | Medium | *(none)* | Set model + equality |
| `union` | Medium | *(none)* | |
| `and` / `or` / `minus` (sets) | Medium | *(none)* | Starter: `minus` |

**Language features (with 1.1.4)**

| Feature | Difficulty | Notes |
| --- | --- | --- |
| `in` | Easy–Medium | |
| `_` (scan / any) | Medium | Iteration + short-circuit |

#### Tier 1.1.5 — Glob & network (CIDR)

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `glob.match` | Medium | *(none)* | Delimiter-aware `**` |
| `net.cidr_contains` | Medium* | `bit` | *IPv4 first; full IPv6 is Hard |
| `net.cidr_intersects` | Medium* | `bit` | |
| `net.cidr_is_valid` | Medium* | `bit` | |
| `net.cidr_contains_matches` | Medium* | `bit` | Batch wrappers |

### Tier 1.2 — OpenResty (Step 2)

Platform backend for regex. Core still calls the backend API only.

| Function | Difficulty (via backend) | Backend | Notes |
| --- | --- | --- | --- |
| `regex.match` | Easy–Medium | `ngx.re.match` | Highest ROI for WAF; pure Lua = Very hard — **do not** hand-roll in Step 1 |
| `regex.is_valid` | Easy–Medium | compile-and-catch | |
| `regex.replace` | Easy–Medium | `ngx.re.gsub` | Capture syntax may differ from OPA |
| `regex.find_n` | Medium | multi-match glue | |
| `regex.split` | Medium | split via `ngx.re` | |

Optional CI without nginx:

| Option | When |
| --- | --- |
| Stub / skip `regex.*` on pure LuaJIT | Default until needed in `t/*.t` |
| `lrexlib` / PCRE | Regex tests without OpenResty |
| Full `ngx.re` | Step 2 product + optional smoke |

---

## Tier 2 — Encoding & body inspection

### Tier 2.1 — Pure Lua (Step 1)

`prove` stays nginx-free. `cjson` allowed as a portable C dep from **2.1.2**.

#### Tier 2.1.1 — Wire encoding (base64, hex, urlquery)

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `base64.decode` / `encode` | Medium | pure-Lua | Padding / invalid input |
| `base64.is_valid` | Medium | pure-Lua | |
| `base64url.decode` / `encode` | Medium | pure-Lua | URL-safe alphabet |
| `hex.decode` / `encode` | Easy | *(none)* | |
| `urlquery.decode` / `encode` | Medium | pure-Lua | `%xx`, `+`, invalid escapes |
| `urlquery.decode_object` | Medium | pure-Lua | Repeated keys → arrays |
| `urlquery.encode_object` | Medium | pure-Lua | |

#### Tier 2.1.2 — JSON (`cjson`)

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `json.is_valid` | Easy (w/ cjson) | `cjson` | `pcall(cjson.decode)` |
| `json.unmarshal` | Easy (w/ cjson) | `cjson` | Number / null edges |
| `json.marshal` | Easy (w/ cjson) | `cjson` | |
| `json.filter` | Medium | `cjson` + paths | Path logic still yours |
| `json.remove` | Medium | same | |

**Defer unless product needs them**

| Function | Difficulty | Notes |
| --- | --- | --- |
| `json.patch` | Hard | Rare for WAF |
| `json.match_schema` | Very hard | Full JSON Schema |
| `json.verify_schema` | Very hard | |

#### Tier 2.1.3 — URI & string extras

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `uri.parse` | Medium | pure-Lua | RFC-ish edge cases |
| `uri.is_valid` | Medium | pure-Lua | |
| `strings.count` | Easy | *(none)* | |
| `strings.any_prefix_match` | Easy | *(none)* | |
| `strings.any_suffix_match` | Easy | *(none)* | |
| `strings.replace_n` | Medium | *(none)* | |
| `indexof_n` | Easy | *(none)* | |
| `format_int` | Easy | *(none)* | |

### Tier 2.2 — OpenResty (Step 2)

Optional platform overrides. Same builtin names; swap backend only.

| Function | Backend | Notes |
| --- | --- | --- |
| `base64.*` | `ngx.decode_base64` / `ngx.encode_base64` | Keep pure if parity is good |
| `urlquery.*` | `ngx.unescape_uri` (partial) | Prefer pure if OPA parity matters |
| `json.*` | `cjson` (same as 2.1.2) | No change required |
| `uri.*` | keep pure or small helper | |

---

## Tier 3 — Auth, time, crypto (optional)

Only if the product exposes tokens, rate windows, or integrity checks.

### Tier 3.1 — Pure Lua (Step 1)

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `io.jwt.decode` | Medium | pure + `cjson` | No verify |
| `time.now_ns` | Easy–Medium | *(none)* | Non-deterministic |
| `time.parse_rfc3339_ns` | Medium | pure-Lua | |
| `time.parse_ns` | Medium | pure-Lua | |
| `time.parse_duration_ns` | Medium | pure-Lua | Go-style `5m`, `1h` |
| `time.diff` | Medium | *(none)* | |
| `time.add_date` | Medium–Hard | pure-Lua | Calendar math |
| `units.parse_bytes` | Easy | *(none)* | |
| `units.parse` | Medium | *(none)* | |
| `trace` | Easy | *(none)* | No-op in prod OK |

Skip pure crypto / JWT **verify** — use **3.2**.

### Tier 3.2 — OpenResty (Step 2)

| Function | Difficulty (via backend) | Backend | Notes |
| --- | --- | --- | --- |
| `io.jwt.decode_verify` | Medium | `resty.jwt` + openssl | |
| `io.jwt.verify_hs256` / `rs256` / … | Medium | openssl / resty.jwt | |
| `crypto.sha256` / `sha1` / `md5` | Easy | `resty.openssl` / `ngx.md5` | |
| `crypto.hmac.sha256` | Easy | openssl | |
| `crypto.hmac.equal` | Easy | openssl constant-time | Don’t DIY |
| `time.now_ns` | Easy | `ngx.now` | Optional override of 3.1 |

---

## Out of scope (most WAF rules)

| Category | Why skip |
| --- | --- |
| GraphQL built-ins | Only if WAF parses GraphQL |
| `http.send` | Side effects; forbid in pure rule eval |
| `net.lookup_ip_addr` | DNS at eval time is slow / flaky |
| `net.cidr_expand` | Prefer `cidr_contains` |
| Graph (`walk`, `reachable`) | Not typical HTTP request shape |
| YAML | Prefer JSON bodies |
| X.509 / mTLS suite | Edge / TLS terminator, not rule body |
| `providers.aws.*` | Not WAF |
| `opa.runtime` / `rego.metadata.*` | Runtime meta |
| `rand.intn` | Non-deterministic hurts auditability |
| `semver.*` / `uuid.*` | Rare |

---

## Build order summary

| Order | Tier | Where | What |
| --- | ---: | --- | --- |
| 1 | **1.1.1** | Pure LuaJIT | cmp, types, numbers, `:=`, `default` |
| 2 | **1.1.2** | Pure LuaJIT | `object.get` / `keys` / `filter` / `remove` / `subset` |
| 3 | **1.1.3** | Pure LuaJIT | string ops |
| 4 | **1.1.4** | Pure LuaJIT | `count`, `in` / `_`, arrays, sets |
| 5 | **1.1.5** | Pure + `bit` | `glob.match`, IPv4 `net.cidr_*` |
| 6 | **2.1.1** | Pure LuaJIT | `urlquery.*`, `base64.*`, `hex.*` |
| 7 | **2.1.2** | Pure + `cjson` | `json.unmarshal` / `is_valid` / `marshal` |
| 8 | **2.1.3** | Pure LuaJIT | `uri.*`, string extras |
| 9 | **1.2** | OpenResty | `regex.*` via `ngx.re` |
| 10 | **2.2** | OpenResty | optional base64/uri overrides |
| 11 | **3.1 / 3.2** | As needed | time pure; JWT verify / crypto on OpenResty |

```text
Step 1 CI:   1.1.1 → 1.1.2 → 1.1.3 → 1.1.4 → 1.1.5 → 2.1.1 → 2.1.2 → 2.1.3
Step 2:      + 1.2 (regex) → 2.2 → 3.x
```

### Minimal deps per step

```text
Step 1 (develop / prove):
  pure Lua           — 1.1.1–1.1.4, 2.1.1, 2.1.3
  bit.* (LuaJIT)     — 1.1.5 CIDR
  cjson              — 2.1.2 json.*

Step 2 (OpenResty product):
  + ngx.re           — 1.2 regex.*
  + resty.openssl    — 3.2 crypto (if needed)
  + resty.jwt        — 3.2 JWT verify (if needed)
```

---

## Layout hint

```text
runtime/
  core/              # 1.1.x / 2.1.x / 3.1 — portable semantics
  builtins/          # Rego names → core + backend
  backend/
    pure.lua         # Step 1
    openresty.lua    # Step 2 (1.2, 2.2, 3.2)
```

See also: [`rego-builtins-waf.md`](./rego-builtins-waf.md), [`ir2lua-guide.md`](./ir2lua-guide.md), `AGENTS.md`, full catalog [`rego-builtins.md`](./rego-builtins.md).
