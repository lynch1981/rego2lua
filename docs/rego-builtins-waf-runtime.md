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

Product **usage** tiers (Tier 1 / 2 / 3) still come from [`rego-builtins-waf.md`](./rego-builtins-waf.md). This file splits each into **\*.1 pure Lua** and **\*.2 OpenResty**.

```text
Tier 1  (use constantly)     →  1.1 pure Lua   +  1.2 OpenResty
Tier 2  (encoding / body)    →  2.1 pure Lua   +  2.2 OpenResty
Tier 3  (auth / time / crypto) →  3.1 pure Lua +  3.2 OpenResty
```

---

## Backend contract (sketch)

Both backends implement the same surface; core builtins call this table only.

```lua
-- backend/pure.lua  or  backend/openresty.lua
return {
  regex_match   = function(pattern, value) ... end,
  regex_is_valid = function(pattern) ... end,
  regex_replace = function(s, pattern, value) ... end,
  base64_decode = function(s) ... end,
  base64_encode = function(s) ... end,
  json_decode   = function(s) ... end,  -- often wraps cjson in both steps
  json_encode   = function(v) ... end,
  -- crypto / time only when Tier 3 ships
}
```

Dialect note: OPA regex is **RE2 / Go**-style. `ngx.re` / PCRE is close for most WAF signatures but **not** bit-identical to OPA.

---

## Dependency legend

| Dep | Step | Used for |
| --- | --- | --- |
| *(none)* | 1 & 2 | stdlib / small in-repo pure Lua |
| `bit` | 1 & 2 | LuaJIT `bit.*` (IPv4 CIDR) |
| `cjson` | 1 & 2 | JSON; already used by `t/eval_pkg.lua` |
| `ngx.re` / PCRE | **2** (or `lrexlib` in CI) | `regex.*` |
| `ngx.decode_base64` / encode | **2** | `base64.*` (optional; pure Lua OK) |
| `ngx.unescape_uri` | **2** | `urlquery` (optional; pure Lua OK) |
| `resty.openssl` / `luaossl` | **2** | hash, HMAC, RSA |
| `resty.jwt` | **2** | JWT decode / verify |
| `ngx.now` | **2** | time helpers |

---

## Tier 1 — Use constantly

WAF rules hit these every day (path, header, IP, method, query, simple payload).

### Tier 1.1 — Pure Lua (Step 1)

Implement and test on plain LuaJIT. No `ngx.*`.

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `equal` (`==`) | Easy | *(none)* | Undefined ≠ Lua `nil` |
| `neq` (`!=`) | Easy | *(none)* | |
| `gt` / `gte` / `lt` / `lte` | Easy | *(none)* | |
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
| `glob.match` | Medium | *(none)* | Delimiter-aware `**` |
| `net.cidr_contains` | Medium* | `bit` | *IPv4 first; IPv6 is Hard |
| `net.cidr_intersects` | Medium* | `bit` | |
| `net.cidr_is_valid` | Medium* | `bit` | |
| `net.cidr_contains_matches` | Medium* | `bit` | Batch wrappers |
| `count` | Easy | *(none)* | String vs collection |
| `in` | Easy–Medium | *(none)* | Needs scan / membership |
| `object.get` | Easy | *(none)* | |
| `object.keys` | Easy | *(none)* | |
| `object.filter` | Easy | *(none)* | |
| `object.remove` | Easy | *(none)* | |
| `object.subset` | Medium | *(none)* | Nested deep compare |
| `array.concat` | Easy | *(none)* | |
| `array.slice` | Easy | *(none)* | |
| `array.flatten` | Easy | *(none)* | |
| `is_string` / `is_number` / `is_array` / `is_object` / `is_boolean` / `is_null` | Easy | *(none)* | Array vs object tables |
| `type_name` | Easy | *(none)* | |
| `to_number` | Easy | *(none)* | Invalid → undefined |
| `plus` / `minus` / `mul` / `div` / `rem` | Easy | *(none)* | |
| `abs` | Easy | *(none)* | |
| `numbers.range` | Easy | *(none)* | |
| `intersection` | Medium | *(none)* | Set model + equality |
| `union` | Medium | *(none)* | |
| `and` / `or` / `minus` (sets) | Medium | *(none)* | Starter: `minus` |

**Language features (Step 1 — essential)**

| Feature | Difficulty | Notes |
| --- | --- | --- |
| `not` | Medium | Undefined / negation semantics |
| `in` | Easy–Medium | |
| `_` (scan / any) | Medium | Iteration + short-circuit |
| `:=` | Easy | Locals in generated Lua |
| `default` | Easy | Default rule values |

**Step 1 unlock order (this repo)**

1. Comparisons + `object.get` / field access  
2. `contains` / `startswith` / `endswith` / `lower`  
3. `count` + `in` / `_` scan  
4. Sets + `glob.match` + IPv4 `net.cidr_*`  

### Tier 1.2 — OpenResty (Step 2)

Same product Tier 1, but needs a **platform backend**. Core still calls the backend API; OpenResty (or optional CI `lrexlib`) provides the implementation.

| Function | Difficulty (via backend) | Backend | Notes |
| --- | --- | --- | --- |
| `regex.match` | Easy–Medium | `ngx.re.match` | Highest ROI for WAF; pure Lua = Very hard — **do not** hand-roll in Step 1 |
| `regex.is_valid` | Easy–Medium | compile-and-catch | |
| `regex.replace` | Easy–Medium | `ngx.re.gsub` | Capture syntax may differ from OPA |
| `regex.find_n` | Medium | multi-match glue | |
| `regex.split` | Medium | split via `ngx.re` | |

Optional Step 1 CI parity (not required for green pure suite):

| Option | When |
| --- | --- |
| Stub / skip `regex.*` tests on pure LuaJIT | Default until regex is needed in `t/*.t` |
| `lrexlib` / PCRE binding | Want regex tests without nginx |
| Full `ngx.re` | Step 2 product + optional OpenResty smoke |

---

## Tier 2 — Encoding & body inspection

Use when rules inspect encoded payloads, query strings, or JSON bodies.

### Tier 2.1 — Pure Lua (Step 1)

Prefer pure implementations so `prove` stays nginx-free. `cjson` is allowed as a **portable** C dep (works with plain LuaJIT; already in the harness).

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `base64.decode` / `encode` | Medium | pure-Lua or later 2.2 | Padding / invalid input |
| `base64.is_valid` | Medium | pure-Lua | |
| `base64url.decode` / `encode` | Medium | pure-Lua | URL-safe alphabet |
| `urlquery.decode` / `encode` | Medium | pure-Lua | `%xx`, `+`, invalid escapes |
| `urlquery.decode_object` | Medium | pure-Lua | Repeated keys → arrays |
| `urlquery.encode_object` | Medium | pure-Lua | |
| `hex.decode` / `encode` | Easy | *(none)* | |
| `json.is_valid` | Easy (w/ cjson) | `cjson` | `pcall(cjson.decode)`; pure JSON is Medium–Hard |
| `json.unmarshal` | Easy (w/ cjson) | `cjson` | Number / null edges |
| `json.marshal` | Easy (w/ cjson) | `cjson` | |
| `json.filter` | Medium | `cjson` + paths | Path logic still yours |
| `json.remove` | Medium | same | |
| `uri.parse` | Medium | pure-Lua | RFC-ish edge cases |
| `uri.is_valid` | Medium | pure-Lua | |
| `strings.count` | Easy | *(none)* | |
| `strings.any_prefix_match` | Easy | *(none)* | |
| `strings.any_suffix_match` | Easy | *(none)* | |
| `strings.replace_n` | Medium | *(none)* | |
| `indexof_n` | Easy | *(none)* | |
| `format_int` | Easy | *(none)* | |

**Defer in both steps unless product needs them**

| Function | Difficulty | Notes |
| --- | --- | --- |
| `json.patch` | Hard | Rare for WAF rules |
| `json.match_schema` | Very hard | Full JSON Schema |
| `json.verify_schema` | Very hard | |

**Step 1 unlock after Tier 1.1**

5. `urlquery.*` / pure `base64.*`  
6. `json.unmarshal` / `json.is_valid` (`cjson`)  

### Tier 2.2 — OpenResty (Step 2)

Optional faster / platform-native backends. Same builtin names; swap backend only.

| Function | Backend | Notes |
| --- | --- | --- |
| `base64.*` | `ngx.decode_base64` / `ngx.encode_base64` | Keep pure Lua if parity is already good |
| `urlquery.*` | `ngx.unescape_uri` (partial) | Prefer pure if OPA parity matters |
| `json.*` | `cjson` (same as Step 1) | No change required |
| `uri.*` | keep pure or small helper | |

---

## Tier 3 — Auth, time, crypto (optional)

Only if the WAF product exposes tokens, rate windows, or integrity checks.

### Tier 3.1 — Pure Lua (Step 1)

| Function | Difficulty | Dep | Notes |
| --- | --- | --- | --- |
| `io.jwt.decode` | Medium | pure + `cjson` | Split parts + JSON only; no verify |
| `time.now_ns` | Easy–Medium | *(none)* | Seconds vs ns; non-deterministic |
| `time.parse_rfc3339_ns` | Medium | pure-Lua | TZ / fractional seconds |
| `time.parse_ns` | Medium | pure-Lua | Layout language |
| `time.parse_duration_ns` | Medium | pure-Lua | Go-style `5m`, `1h` |
| `time.diff` | Medium | *(none)* | |
| `time.add_date` | Medium–Hard | pure-Lua | Calendar math |
| `units.parse_bytes` | Easy | *(none)* | |
| `units.parse` | Medium | *(none)* | |
| `trace` | Easy | *(none)* | No-op in prod OK |

Skip pure implementations of crypto / JWT **verify** — use Tier 3.2.

### Tier 3.2 — OpenResty (Step 2)

| Function | Difficulty (via backend) | Backend | Notes |
| --- | --- | --- | --- |
| `io.jwt.decode_verify` | Medium | `resty.jwt` + openssl | Claims + alg constraints |
| `io.jwt.verify_hs256` / `rs256` / … | Medium | openssl / resty.jwt | |
| `crypto.sha256` / `sha1` / `md5` | Easy | `resty.openssl` / `ngx.md5` | Prefer OpenSSL |
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
| 1 | **1.1** | Pure LuaJIT | cmp, strings, objects, arrays, types, `count` |
| 2 | **1.1** | Pure LuaJIT | `in` / `_`, sets, `glob.match`, IPv4 `net.cidr_*` |
| 3 | **2.1** | Pure + `cjson` | `urlquery.*`, `base64.*`, `json.unmarshal` |
| 4 | **1.2** | OpenResty backend | `regex.match` (+ friends) via `ngx.re` |
| 5 | **2.2** | OpenResty (optional) | platform base64/uri if useful |
| 6 | **3.1 / 3.2** | As needed | time pure; JWT verify / crypto on OpenResty |

```text
Step 1 CI (this repo):   Tier 1.1 → 2.1   [regex optional/stub]
Step 2 product:          + Tier 1.2 (regex) → 2.2 → 3.x
```

### Minimal deps per step

```text
Step 1 (develop / prove):
  bit.* (LuaJIT)     — IPv4 CIDR
  cjson              — json.*  (already in harness)
  pure Lua           — everything else in 1.1 / 2.1

Step 2 (OpenResty product):
  + ngx.re           — regex.*
  + resty.openssl    — crypto (if Tier 3)
  + resty.jwt        — JWT verify (if Tier 3)
  optional ngx.base64 / ngx.now overrides
```

---

## Layout hint

```text
runtime/
  core/              # 1.1 / 2.1 / 3.1 — portable semantics
  builtins/          # Rego names → core + backend
  backend/
    pure.lua         # Step 1
    openresty.lua    # Step 2
```

See also: [`rego-builtins-waf.md`](./rego-builtins-waf.md), [`ir2lua-guide.md`](./ir2lua-guide.md), `AGENTS.md`, full catalog [`rego-builtins.md`](./rego-builtins.md).
