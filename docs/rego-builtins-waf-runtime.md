# WAF Built-ins: Priority, Difficulty & Dependencies

Implementer companion to [`rego-builtins-waf.md`](./rego-builtins-waf.md).

| Doc | Audience | Content |
| --- | --- | --- |
| [`rego-builtins-waf.md`](./rego-builtins-waf.md) | Product / rule authors | Which funcs WAF needs, usage tiers, starter set |
| **This file** | Runtime implementers | Pure-Lua difficulty, deps that help, build order |

**Priority** = product usage tier from the WAF subset doc (plus rego2lua unlock order).  
**Difficulty** = implement in pure Lua / LuaJIT with **no** C libraries.  
**With deps** = same func when a realistic OpenResty / LuaJIT dependency is allowed.

**Difficulty scale:** Easy · Medium · Hard · Very hard

---

## Dependency legend

Typical stack for this project’s target (LuaJIT 2.1 / OpenResty):

| Dep | Used for |
| --- | --- |
| *(none)* | stdlib or a small pure-Lua helper in-repo |
| `cjson` | JSON (`lua-cjson`; already used by `t/eval_pkg.lua`) |
| `PCRE` / `lrexlib` / `ngx.re` | Real regex (OpenResty provides `ngx.re`) |
| `bit` | LuaJIT `bit.*` for IPv4 CIDR math |
| `openssl` / `resty.openssl` / `luaossl` | Hash, HMAC, RSA/ECDSA |
| `resty.jwt` (or similar) | JWT decode / verify |
| pure-Lua lib | Optional vendored helper (base64, URI, date, …) |

Dialect note: OPA regex is **RE2 / Go**-style. `ngx.re` / PCRE is close enough for most WAF signatures but is **not** bit-identical to OPA.

---

## Tier 1 — Use constantly

| Function | Priority | Pure Lua | With deps | Suggested dep | Notes |
| --- | --- | --- | --- | --- | --- |
| `equal` (`==`) | T1 · impl #1 | Easy | Easy | *(none)* | Rego undefined vs Lua `nil` |
| `neq` (`!=`) | T1 · impl #1 | Easy | Easy | *(none)* | |
| `gt` / `gte` / `lt` / `lte` | T1 · impl #1 | Easy | Easy | *(none)* | Number/string compare edge cases |
| `contains` | T1 · impl #2 | Easy | Easy | *(none)* | |
| `startswith` | T1 · impl #2 | Easy | Easy | *(none)* | |
| `endswith` | T1 · impl #2 | Easy | Easy | *(none)* | |
| `lower` / `upper` | T1 · impl #2 | Easy | Easy | *(none)* | Unicode case limited in pure Lua |
| `split` | T1 · starter | Easy | Easy | *(none)* | |
| `concat` | T1 · starter | Easy | Easy | *(none)* | |
| `substring` | T1 · starter | Easy | Easy | *(none)* | Negative offset / length rules |
| `indexof` | T1 | Easy | Easy | *(none)* | |
| `replace` | T1 · starter | Easy | Easy | *(none)* | All-occurrences semantics |
| `trim` / `trim_space` / `trim_prefix` / `trim_suffix` | T1 · starter | Easy | Easy | *(none)* | Starter emphasizes `trim_space` |
| `sprintf` | T1 · starter | Medium | Easy–Medium | *(none)* or tiny fmt helper | Go `fmt` verbs ≠ `string.format` |
| `regex.match` | T1 · impl #4 | **Very hard** | **Easy–Medium** | `ngx.re` / `lrexlib` / PCRE | Highest ROI dependency for WAF |
| `regex.is_valid` | T1 · starter | **Hard** | **Easy–Medium** | same | Compile-and-catch |
| `regex.replace` | T1 · starter | **Very hard** | **Easy–Medium** | same | Capture / replace syntax differ |
| `regex.find_n` | T1 | **Very hard** | **Medium** | same | Multi-match API glue |
| `regex.split` | T1 | **Very hard** | **Medium** | same | |
| `glob.match` | T1 · starter | Medium | Medium | *(none)* or small glob lib | Delimiter-aware `**`; deps rarely worth it |
| `net.cidr_contains` | T1 · impl #5 | Medium* | Easy–Medium | `bit` (IPv4); optional IPv6 helper | *Hard pure Lua if full IPv6 parity |
| `net.cidr_intersects` | T1 | Medium* | Easy–Medium | `bit` | |
| `net.cidr_is_valid` | T1 · starter | Medium* | Easy–Medium | `bit` | |
| `net.cidr_contains_matches` | T1 | Medium* | Medium | `bit` | Batch wrappers |
| `count` | T1 · impl #3 | Easy | Easy | *(none)* | String length vs collection size |
| `in` (membership) | T1 · impl #3 | Easy–Medium | Easy–Medium | *(none)* | Array / object / set; needs scan |
| `object.get` | T1 · impl #1 | Easy | Easy | *(none)* | |
| `object.keys` | T1 · starter | Easy | Easy | *(none)* | Key order not guaranteed |
| `object.filter` | T1 | Easy | Easy | *(none)* | |
| `object.remove` | T1 | Easy | Easy | *(none)* | |
| `object.subset` | T1 | Medium | Medium | *(none)* | Nested deep compare |
| `array.concat` | T1 · starter | Easy | Easy | *(none)* | |
| `array.slice` | T1 · starter | Easy | Easy | *(none)* | Bounds / half-open range |
| `array.flatten` | T1 | Easy | Easy | *(none)* | One-level vs deep |
| `is_string` / `is_number` / `is_array` / `is_object` / `is_boolean` / `is_null` | T1 · starter | Easy | Easy | *(none)* | Arrays vs objects in Lua tables |
| `type_name` | T1 | Easy | Easy | *(none)* | |
| `to_number` | T1 · starter | Easy | Easy | *(none)* | Invalid → undefined |
| `plus` / `minus` / `mul` / `div` / `rem` | T1 | Easy | Easy | *(none)* | Div/rem by zero → undefined |
| `abs` | T1 | Easy | Easy | *(none)* | |
| `numbers.range` | T1 | Easy | Easy | *(none)* | Large ranges |
| `intersection` | T1 · starter | Medium | Medium | *(none)* | Set model + deep equality |
| `union` | T1 · starter | Medium | Medium | *(none)* | |
| `and` / `or` / `minus` (sets) | T1 · starter | Medium | Medium | *(none)* | Starter emphasizes `minus` |

\*CIDR: **Medium** with IPv4-first; **Hard** pure Lua for full IPv6 parity with OPA.

---

## Tier 2 — Encoding & body inspection

| Function | Priority | Pure Lua | With deps | Suggested dep | Notes |
| --- | --- | --- | --- | --- | --- |
| `base64.decode` / `base64.encode` | T2 · impl #6 | Medium | **Easy** | `ngx.decode_base64` / openssl / pure-Lua | Prefer platform decode on OpenResty |
| `base64.is_valid` | T2 · starter | Medium | **Easy** | same | Padding / alphabet |
| `base64url.decode` / `base64url.encode` | T2 | Medium | **Easy** | openssl or small helper | URL-safe alphabet |
| `urlquery.decode` / `urlquery.encode` | T2 · impl #6 | Medium | **Easy–Medium** | `ngx.unescape_uri` / pure-Lua | Align with OPA/Go quirks |
| `urlquery.decode_object` | T2 · starter | Medium | **Easy–Medium** | same | Repeated keys → arrays |
| `urlquery.encode_object` | T2 | Medium | **Easy–Medium** | same | Escape + key order |
| `hex.decode` / `hex.encode` | T2 | Easy | Easy | *(none)* or openssl | |
| `json.is_valid` | T2 · starter | Medium–Hard | **Easy** | `cjson` | `pcall(cjson.decode)` |
| `json.unmarshal` | T2 · impl #6 | Medium–Hard | **Easy** | `cjson` | Number / null edge cases |
| `json.marshal` | T2 | Medium–Hard | **Easy** | `cjson` | Key order / sparse arrays |
| `json.filter` | T2 | Medium | Medium | `cjson` + path logic | Paths still custom |
| `json.remove` | T2 | Medium | Medium | same | |
| `json.patch` | T2 | Hard | Medium | `cjson` + patch lib (rare) | |
| `json.match_schema` | T2 | **Very hard** | **Hard** | schema lib (few mature Lua ones) | Large surface; skip if possible |
| `json.verify_schema` | T2 | **Very hard** | **Hard** | same | |
| `uri.parse` | T2 | Medium | **Easy–Medium** | pure-Lua URI / `socket.url` | RFC-ish edge cases |
| `uri.is_valid` | T2 | Medium | **Easy–Medium** | same | |
| `strings.count` | T2 | Easy | Easy | *(none)* | |
| `strings.any_prefix_match` | T2 | Easy | Easy | *(none)* | |
| `strings.any_suffix_match` | T2 | Easy | Easy | *(none)* | |
| `strings.replace_n` | T2 | Medium | Medium | *(none)* | Multi-pattern map |
| `indexof_n` | T2 | Easy | Easy | *(none)* | |
| `format_int` | T2 | Easy | Easy | *(none)* | Bases 2–36 |

---

## Tier 3 — Auth, time, crypto (optional)

| Function | Priority | Pure Lua | With deps | Suggested dep | Notes |
| --- | --- | --- | --- | --- | --- |
| `io.jwt.decode` | T3 | Medium | **Easy** | `resty.jwt` / manual + cjson | No crypto |
| `io.jwt.decode_verify` | T3 | **Very hard** | **Medium** | `resty.jwt` + openssl | Claims + algs still product work |
| `io.jwt.verify_hs256` / `rs256` / … | T3 | **Very hard** | **Medium** | openssl / resty.jwt | |
| `time.now_ns` | T3 | Easy–Medium | Easy | *(none)*; `ngx.now` on OpenResty | Seconds vs ns; non-deterministic |
| `time.parse_rfc3339_ns` | T3 | Medium | Easy–Medium | pure-Lua or date lib | TZ / fractional seconds |
| `time.parse_ns` | T3 | Medium | Medium | date lib | Layout language |
| `time.parse_duration_ns` | T3 | Medium | Easy–Medium | *(none)* or small parser | Go-style `5m`, `1h` |
| `time.diff` | T3 | Medium | Easy–Medium | *(none)* | |
| `time.add_date` | T3 | Medium–Hard | Medium | date lib | Calendar math |
| `crypto.sha256` / `sha1` / `md5` | T3 | Hard | **Easy** | `resty.openssl` / `ngx.md5` (md5) | Prefer OpenSSL |
| `crypto.hmac.sha256` | T3 | Hard | **Easy** | openssl | |
| `crypto.hmac.equal` | T3 | Hard | **Easy** | openssl constant-time compare | Don’t DIY |
| `units.parse_bytes` | T3 | Easy | Easy | *(none)* | |
| `units.parse` | T3 | Medium | Easy–Medium | *(none)* | SI units |
| `trace` | T3 | Easy | Easy | *(none)* | Dev-time; no-op in prod OK |

---

## Out of scope (most WAF rules)

| Function / category | Priority | Pure Lua | With deps | Suggested dep | Notes |
| --- | --- | --- | --- | --- | --- |
| GraphQL built-ins | Out | Hard | Hard | GraphQL parser | Only if WAF parses GraphQL |
| `http.send` | Out | Hard | Medium | `resty.http` | Side effects; usually forbid in pure rule eval |
| `net.lookup_ip_addr` | Out | n/a | Medium | OS resolver / cosocket | Slow / flaky at eval time |
| `net.cidr_expand` | Out | Medium | Medium | `bit` | Prefer `cidr_contains` |
| Graph (`walk`, `reachable`) | Out | Hard | Hard | *(none)* | Not typical HTTP request shape |
| YAML | Out | Hard | Medium | `lyaml` (libyaml) | Prefer JSON for bodies |
| X.509 / mTLS suite | Out | **Very hard** | Medium–Hard | openssl | Edge / TLS terminator concern |
| `providers.aws.*` | Out | Hard | Hard | AWS SDK | Not WAF |
| `opa.runtime` / `rego.metadata.*` | Out | Easy–Medium | Easy | *(none)* | Runtime meta, not request policy |
| `rand.intn` | Out | Easy | Easy | *(none)* / `resty.random` | Non-deterministic hurts auditability |
| `semver.*` | Out | Medium | Easy–Medium | tiny pure-Lua | Rare |
| `uuid.*` | Out | Easy–Medium | Easy | pure-Lua / openssl | Only if validating UUID-shaped IDs |

---

## Language features (not functions)

| Feature | Priority | Pure Lua | With deps | Suggested dep | Notes |
| --- | --- | --- | --- | --- | --- |
| `not` | Essential | Medium | Medium | *(none)* | Comprehension / undefined semantics |
| `in` | Essential · impl #3 | Easy–Medium | Easy–Medium | *(none)* | |
| `_` (scan / any) | Essential · impl #3 | Medium | Medium | *(none)* | Iteration + short-circuit |
| `:=` | Essential | Easy | Easy | *(none)* | Locals in generated Lua |
| `default` | Essential | Easy | Easy | *(none)* | Default rule values |

---

## Compact view (priority × difficulty)

|  | Easy pure Lua | Medium pure Lua | Hard / Very hard pure Lua |
| --- | --- | --- | --- |
| **T1 first** | `==` `!=` cmp, string ops, `count`, `object.get`/`keys`, arrays, `is_*`, `to_number` | `sprintf`, `glob.match`, `net.cidr_*` (v4), sets, `in`/`_`, `object.subset` | **`regex.*`**; full IPv6 CIDR |
| **T2 next** | `hex.*`, string extras | `urlquery.*`, `base64.*`, `uri.*`, pure-Lua JSON | `json.patch`, **`json.*_schema`** |
| **T3 later** | `units.parse_bytes`, `trace` | `time.parse_*`, `io.jwt.decode` | **JWT verify**, **crypto.*** |

With deps, the same grid shifts:

| Group | Pure Lua | With deps | Worth a dep? |
| --- | --- | --- | --- |
| **`regex.*`** | Very hard | Easy–Medium | **Yes — highest ROI** (`ngx.re` / PCRE) |
| **`json.unmarshal` / `is_valid` / `marshal`** | Medium–Hard | Easy | **Yes** (`cjson`) |
| **`crypto.*` / JWT verify** | Very hard | Easy–Medium | **Yes** if Tier 3 ships |
| **`base64.*` / url / uri** | Medium | Easy | Nice on OpenResty; pure Lua OK |
| **`net.cidr_*`** | Medium (v4) | Easy–Medium | `bit` only; no heavy lib |
| **Most T1 string/object/compare** | Easy | Easy | **No dep** |
| **`json.*_schema`** | Very hard | Hard | Avoid unless product needs schema |

---

## Minimal recommended dep set

For a WAF-oriented rego2lua runtime:

```text
must-have for hard bits:   PCRE / ngx.re     (regex.match)
already natural:           cjson             (json.*)
optional later:            openssl + resty.jwt   (crypto / JWT)
stdlib only:               bit.* (LuaJIT) for IPv4 CIDR
```

With that set, almost all **Tier 1 starter** funcs land in **Easy–Medium**. Remaining hard parts are Rego semantics (sets, undefined, scan) and RE2-vs-PCRE dialect parity—not missing libraries.

---

## Suggested pure-Lua + deps build order

Aligns with [`rego-builtins-waf.md`](./rego-builtins-waf.md) “Mapping to rego2lua priorities”:

1. Easy T1 — comparisons, strings, objects/arrays, types, `count` *(no deps)*  
2. Medium T1 — `in` / scan, sets, `glob.match`, IPv4 `net.cidr_*` *(`bit`)*  
3. Medium T2 — `urlquery.*`, `base64.*`, `json.unmarshal` *(`cjson`)*  
4. **`regex.match`** — take the PCRE/`ngx.re` dep rather than a pure-Lua engine  
5. Defer — JWT verify, crypto, JSON Schema, full IPv6 until product rules need them  

See also: `AGENTS.md`, [`ir2lua-guide.md`](./ir2lua-guide.md), full catalog in [`rego-builtins.md`](./rego-builtins.md).
