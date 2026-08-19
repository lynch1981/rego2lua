# Rego Built-ins Priority

Which OPA Rego built-ins **rego2lua cares about**, and in what order to tackle them.

Full catalog: [`rego-builtins.md`](./rego-builtins.md) · Official docs: [Rego Built-ins](https://www.openpolicyagent.org/docs/policy-reference/builtins)

Implement plan (pure Lua → OpenResty, deps, backends): [`rego-builtins-runtime.md`](./rego-builtins-runtime.md)

---

## How priority works

Priority is **not** “how often policies use it” alone. We score two axes, then derive **work order**.

| Axis | Values | Meaning |
| --- | --- | --- |
| **Need** | High · Med · Low | How often real policies want this for match / inspect / transform / decide |
| **Cost** | Easy · Medium · Hard · Platform · Very hard | How hard for *our* LuaJIT / OpenResty path |

**Cost notes**

| Cost | Meaning |
| --- | --- |
| **Easy** | Small pure Lua (or trivial op) |
| **Medium** | Non-trivial pure Lua, edge cases, or portable dep (`bit`, `cjson`) |
| **Hard** | Large pure-Lua surface or calendar/crypto-ish logic |
| **Platform** | Prefer OpenResty / C lib backend; do **not** hand-roll in Step 1 CI |
| **Very hard** | Full engines (RE2-by-hand, JSON Schema, …) — avoid or use a library |

### Need × Cost → P0–P3

| Need \ Cost | Easy | Medium | Hard / Platform | Very hard |
| --- | --- | --- | --- | --- |
| **High** | **P0** | **P1** | **P2** (backend / after pure) | out / library only |
| **Med** | **P1** | **P2** | **P3** | out of scope |
| **Low** | **P2** | **P3** | out / later | out of scope |

```text
P0  High + Easy     — ship first; unlocks most policies + early t/*.t
P1  High + Medium, Med + Easy — high value, still CI-friendly
P2  High + Platform, Med + Medium, Low + Easy — next wave; ship Platform families together
P3  Med + Platform/Hard, Low + Medium, optional product (time, JWT verify, crypto, schema)
```

When a **Platform** family has at least one High-need member (e.g. `regex.match`), ship the related siblings in the same P-band even if their solo Need is Med.

**Canonical “do next” list** is the **P0–P3** section below.  
**Deep slices, backends, deps** stay in [`rego-builtins-runtime.md`](./rego-builtins-runtime.md).

Example: `regex.match` is **High + Platform** → **P2** (important, not pure-Lua first).

---

## Build next (P0–P3)

### P0 — High need, easy cost

Core decisions without platform deps.

```text
# compare
==  !=  >  >=  <  <=

# types / numbers
is_string  is_number  is_array  is_object  is_boolean  is_null
type_name  to_number
+  -  *  /  %  abs

# strings (common)
contains  startswith  endswith  lower  upper
split  concat  substring  replace  trim_space
indexof

# object / array (common)
object.get  object.keys  object.filter  object.remove
array.concat  array.slice

# aggregates
count
```

**Language (codegen / IR — not named builtins):** `:=` · `default` · `not` (basic)

### P1 — High+Medium or Med+Easy

Still pure / portable; richer policies.

```text
# strings
trim  trim_prefix  trim_suffix
strings.count  strings.any_prefix_match  strings.any_suffix_match

# collections / sets / membership
in   (syntax)
_    (scan — language)
array.flatten
intersection  union  minus   # High need (allow/deny lists)

# numbers
numbers.range

# glob + net (IPv4 first)
glob.match
net.cidr_contains  net.cidr_is_valid

# encoding / body (portable)
hex.decode  hex.encode
urlquery.decode  urlquery.encode  urlquery.decode_object
base64.decode  base64.encode  base64.is_valid
json.is_valid  json.unmarshal  json.marshal   # cjson OK
```

### P2 — Platform-high or medium wave

```text
# regex — High need, Platform cost (ngx.re / backend; not pure Step 1)
regex.match  regex.is_valid  regex.replace
regex.find_n  regex.split    # Med need; ship with regex family

# net batch / extra
net.cidr_intersects  net.cidr_contains_matches

# Med + Medium
sprintf
object.subset
base64url.decode  base64url.encode
urlquery.encode_object
uri.parse  uri.is_valid
json.filter  json.remove
io.jwt.decode

# Low + Easy
indexof_n  format_int
```

### P3 — Optional / product-specific

```text
# time
time.now_ns  time.parse_rfc3339_ns  time.parse_ns
time.parse_duration_ns  time.diff  time.add_date

# jwt verify + crypto (OpenResty backends)
io.jwt.decode_verify  io.jwt.verify_*
crypto.sha256  crypto.sha1  crypto.md5
crypto.hmac.sha256  crypto.hmac.equal

# units / debug
units.parse_bytes  units.parse  trace

# Low + Medium / rare
strings.replace_n
json.patch
```

---

## Catalog by need (with cost)

Signatures and “why we care.” **P** = derived work band.

### Comparison

| Function | Signature | Need | Cost | P | Why we care |
| --- | --- | --- | --- | --- | --- |
| `equal` | `x == y` | High | Easy | P0 | Exact match |
| `neq` | `x != y` | High | Easy | P0 | Inequality |
| `gt` / `gte` / `lt` / `lte` | `x > y`, … | High | Easy | P0 | Limits, ranges |

### Strings

| Function | Signature | Need | Cost | P | Why we care |
| --- | --- | --- | --- | --- | --- |
| `contains` | `contains(haystack, needle)` | High | Easy | P0 | Substring match |
| `startswith` | `startswith(search, base)` | High | Easy | P0 | Path / prefix |
| `endswith` | `endswith(search, base)` | High | Easy | P0 | Extension / suffix |
| `lower` / `upper` | `lower(x)` / `upper(x)` | High | Easy | P0 | Case fold |
| `split` | `split(x, delimiter)` | High | Easy | P0 | Segments |
| `concat` | `concat(delimiter, collection)` | High | Easy | P0 | Join |
| `substring` | `substring(value, offset, length)` | High | Easy | P0 | Windows |
| `indexof` | `indexof(haystack, needle)` | High | Easy | P0 | Position |
| `replace` | `replace(x, old, new)` | High | Easy | P0 | Normalize |
| `trim_space` | `trim_space(x)` | High | Easy | P0 | Whitespace |
| `trim` / `trim_prefix` / `trim_suffix` | various | Med | Easy | P1 | Normalize |
| `sprintf` | `sprintf(format, values)` | Med | Medium | P2 | Messages (Go `fmt` ≠ `string.format`) |
| `strings.count` | `strings.count(search, substring)` | Med | Easy | P1 | Token counts |
| `strings.any_prefix_match` | `strings.any_prefix_match(search, prefixes)` | Med | Easy | P1 | Any-of prefixes |
| `strings.any_suffix_match` | `strings.any_suffix_match(search, suffixes)` | Med | Easy | P1 | Any-of suffixes |
| `strings.replace_n` | `strings.replace_n(patterns, value)` | Low | Medium | P3 | Multi-pattern |
| `indexof_n` | `indexof_n(haystack, needle)` | Low | Easy | P2 | All positions |
| `format_int` | `format_int(number, base)` | Low | Easy | P2 | Diagnostics |

### Regex

| Function | Signature | Need | Cost | P | Why we care |
| --- | --- | --- | --- | --- | --- |
| `regex.match` | `regex.match(pattern, value)` | High | Platform | P2 | Signatures; backend `ngx.re` |
| `regex.is_valid` | `regex.is_valid(pattern)` | High | Platform | P2 | Safe user patterns |
| `regex.replace` | `regex.replace(s, pattern, value)` | High | Platform | P2 | Normalize |
| `regex.find_n` | `regex.find_n(pattern, value, number)` | Med | Platform | P2 | Extract hits (ship with `regex.*`) |
| `regex.split` | `regex.split(pattern, value)` | Med | Platform | P2 | Complex split (ship with `regex.*`) |

Pure Lua RE2 is **Very hard** — do not hand-roll in Step 1. Details: runtime doc.

### Glob & network

| Function | Signature | Need | Cost | P | Why we care |
| --- | --- | --- | --- | --- | --- |
| `glob.match` | `glob.match(pattern, delimiters, match)` | High | Medium | P1 | Path / host globs |
| `net.cidr_contains` | `net.cidr_contains(cidr, ip_or_cidr)` | High | Medium | P1 | Allow/deny IP (IPv4 first) |
| `net.cidr_is_valid` | `net.cidr_is_valid(cidr)` | High | Medium | P1 | Validate CIDRs |
| `net.cidr_intersects` | `net.cidr_intersects(a, b)` | Med | Medium | P2 | Range overlap |
| `net.cidr_contains_matches` | `net.cidr_contains_matches(cidrs, ips)` | Med | Medium | P2 | Batch membership |

Example:

```rego
glob.match("/admin/**", ["/"], input.path)
```

Full IPv6 CIDR is harder than IPv4; start IPv4.

### Aggregates, membership, arrays, objects

| Function | Signature | Need | Cost | P | Why we care |
| --- | --- | --- | --- | --- | --- |
| `count` | `count(collection)` | High | Easy | P0 | Length / size |
| *(syntax)* `in` | `"x" in arr` | High | Medium | P1 | Membership |
| `object.get` | `object.get(object, key, default)` | High | Easy | P0 | Safe lookup |
| `object.keys` | `object.keys(object)` | High | Easy | P0 | Enumerate keys |
| `object.filter` | `object.filter(object, keys)` | High | Easy | P0 | Keep keys |
| `object.remove` | `object.remove(object, keys)` | High | Easy | P0 | Drop keys |
| `object.subset` | `object.subset(super, sub)` | Med | Medium | P2 | Required bag |
| `array.concat` | `array.concat(x, y)` | High | Easy | P0 | Merge lists |
| `array.slice` | `array.slice(arr, start, stop)` | High | Easy | P0 | Window |
| `array.flatten` | `array.flatten(arr)` | Med | Easy | P1 | Nested lists |
| `intersection` | `intersection(xs)` | High | Medium | P1 | Allow/deny set overlap |
| `union` | `union(xs)` | High | Medium | P1 | Merge allowlists |
| `and` / `or` / `minus` | `x & y`, `x \| y`, `x - y` | High | Medium | P1 | Set algebra on tags/hosts |

IR **field access** (`input.method`, nested paths) is codegen, not `object.*`.

### Types & numbers

| Function | Signature | Need | Cost | P | Why we care |
| --- | --- | --- | --- | --- | --- |
| `is_*` | `is_string(x)`, … | High | Easy | P0 | Guards |
| `type_name` | `type_name(x)` | High | Easy | P0 | Defensive |
| `to_number` | `to_number(x)` | High | Easy | P0 | Parse lengths / ports |
| `plus` / `minus` / `mul` / `div` / `rem` | `+ - * / %` | High | Easy | P0 | Arithmetic |
| `abs` | `abs(x)` | High | Easy | P0 | Absolute |
| `numbers.range` | `numbers.range(a, b)` | Med | Easy | P1 | Small ranges |

### Encoding, JSON, URI

| Function | Signature | Need | Cost | P | Why we care |
| --- | --- | --- | --- | --- | --- |
| `hex.decode` / `hex.encode` | `hex.*(x)` | Med | Easy | P1 | Obfuscated payloads |
| `urlquery.decode` / `encode` | `urlquery.*(x)` | High | Medium | P1 | `%xx` traffic |
| `urlquery.decode_object` | `urlquery.decode_object(x)` | High | Medium | P1 | Query → object |
| `urlquery.encode_object` | `urlquery.encode_object(object)` | Med | Medium | P2 | Rebuild query |
| `base64.decode` / `encode` | `base64.*(x)` | High | Medium | P1 | Blobs |
| `base64.is_valid` | `base64.is_valid(x)` | High | Medium | P1 | Detect base64 |
| `base64url.*` | `base64url.*(x)` | Med | Medium | P2 | URL-safe / JWT-ish |
| `json.is_valid` | `json.is_valid(x)` | High | Easy* | P1 | *via `cjson` |
| `json.unmarshal` | `json.unmarshal(x)` | High | Easy* | P1 | Parse body |
| `json.marshal` | `json.marshal(x)` | Med | Easy* | P1 | Serialize |
| `json.filter` / `json.remove` | path helpers | Med | Medium | P2 | Shape body |
| `json.patch` | `json.patch(target, patches)` | Low | Hard | P3 | Rare |
| `json.match_schema` / `verify_schema` | schema | Low | Very hard | out | Library only (matrix: Very hard) |
| `uri.parse` / `uri.is_valid` | `uri.*(x)` | Med | Medium | P2 | Split / validate URL |

### Auth, time, crypto, units, debug

| Function | Signature | Need | Cost | P | Why we care |
| --- | --- | --- | --- | --- | --- |
| `io.jwt.decode` | `io.jwt.decode(jwt)` | Med | Medium | P2 | Claims without verify |
| `io.jwt.decode_verify` / `verify_*` | various | Low–Med | Platform | P3 | Verify (OpenResty) |
| `time.now_ns` | `time.now_ns()` | Low–Med | Easy–Medium | P3 | Non-deterministic |
| `time.parse_*` / `diff` / `add_date` | various | Low–Med | Medium–Hard | P3 | Expiry / windows |
| `crypto.sha*` / `hmac.*` | various | Low–Med | Platform | P3 | Fingerprint / MAC |
| `units.parse_bytes` / `parse` | various | Low | Easy–Medium | P3 | Size strings |
| `trace` | `trace(note)` | Low | Easy | P3 | Dev only |

---

## Language features (essential, not builtins)

| Feature | Need | Cost | P | Notes |
| --- | --- | --- | --- | --- |
| `:=` | High | Easy | P0 | Locals in generated Lua |
| `default` | High | Easy | P0 | Default rule values |
| `not` | High | Medium | P0–P1 | Full power with scan |
| `in` | High | Medium | P1 | Membership |
| `_` (scan / any) | High | Medium | P1 | Iteration + short-circuit |

---

## Out of scope (for now)

| Category | Why |
| --- | --- |
| GraphQL built-ins | Niche parser surface |
| `http.send` | Side effects; forbid in pure rule eval |
| `net.lookup_ip_addr` | DNS at eval time is slow / flaky |
| `net.cidr_expand` | Huge expansions; prefer `cidr_contains` |
| Graph (`walk`, `reachable`) | Not typical request policy shape |
| YAML | Prefer JSON bodies |
| X.509 / mTLS suite | Edge / TLS terminator, not rule body |
| `providers.aws.*` | Not our product surface |
| `opa.runtime` / `rego.metadata.*` | Runtime meta |
| `rand.intn` | Non-deterministic hurts auditability |
| `semver.*` / `uuid.*` | Rare unless product requires |
| `json.match_schema` / `json.verify_schema` | Very hard (full JSON Schema); library only |

---

## Example policies (sketch)

Typical `input` fields (illustrative):

```text
input.method, input.path, input.query, input.headers, input.body,
input.client_ip, input.uri, ...
```

```rego
package example

import rego.v1

default allow := false

# P0: string + default
deny contains "admin path" if {
	startswith(lower(input.path), "/admin")
}

# P1: CIDR
allow if {
	net.cidr_contains("10.0.0.0/8", input.client_ip)
}

# P0: object.get + contains
deny contains "bad ua" if {
	ua := object.get(input.headers, "user-agent", "")
	contains(lower(ua), "sqlmap")
}

# P2: regex (High need, Platform cost)
deny contains "sqli" if {
	some k, v in input.query
	regex.match(`(?i)union\s+select`, v)
}

# P0: count
deny contains "body too large" if {
	is_string(input.body)
	count(input.body) > 1048576
}
```

---

## Layers (do not mix)

| Layer | What | Where |
| --- | --- | --- |
| **IR / tests** | Unlock `t/*.t` (sanity → not → scalars → access → membership → cmp) | [`ir2lua-guide.md`](./ir2lua-guide.md), `AGENTS.md`, `./go` |
| **Builtins priority** | Need × Cost → **P0–P3** (this file) | **This file** |
| **Builtins runtime** | Pure vs OpenResty, deps, slice order, backends | [`rego-builtins-runtime.md`](./rego-builtins-runtime.md) |

1. Core IR + P0 builtins so early tests and simple policies work.  
2. P1 pure / portable.  
3. P2 platform (`regex.*`) + remaining medium.  
4. P3 only if the product needs auth / time / crypto / schema.

If **priority** and **runtime** disagree on order: **P0–P3 here** is the product “what matters”; **runtime** owns CI constraints (e.g. nginx-free Step 1) and may schedule a High-need Platform item after pure slices.

See also: `AGENTS.md`, full catalog [`rego-builtins.md`](./rego-builtins.md).
