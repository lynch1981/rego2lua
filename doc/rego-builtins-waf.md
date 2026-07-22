# Rego Built-ins for WAF Custom Rules

A **practical subset** of OPA Rego built-ins for Web Application Firewall user custom rules.

Full catalog: [`rego-builtins.md`](./rego-builtins.md) · Official docs: [Rego Built-ins](https://www.openpolicyagent.org/docs/policy-reference/builtins)

Typical WAF inputs look like:

```text
input.method, input.path, input.query, input.headers, input.body,
input.client_ip, input.uri, input.cookies, input.args, ...
```

Focus on **match / inspect / transform / decide**. Skip GraphQL, AWS signing, graph walk, YAML, most crypto/X.509 unless your product needs them.

---

## Tier 1 — Use constantly

These cover almost all custom WAF rules: block/allow by path, header, IP, method, query, and simple payload checks.

### Comparison

| Function | Signature | WAF use |
| --- | --- | --- |
| `equal` | `x == y` | Exact match (method, status, header value) |
| `neq` | `x != y` | Deny unless value differs |
| `gt` / `gte` / `lt` / `lte` | `x > y`, etc. | Length limits, status ranges, version numbers |

### Strings

| Function | Signature | WAF use |
| --- | --- | --- |
| `contains` | `contains(haystack, needle)` | Substring in path/body/header (SQLi/XSS snippets) |
| `startswith` | `startswith(search, base)` | Path prefix (`/admin`, `/api/v1`) |
| `endswith` | `endswith(search, base)` | File extension (`.php`, `.env`) |
| `lower` / `upper` | `lower(x)` / `upper(x)` | Case-insensitive matching |
| `split` | `split(x, delimiter)` | Path segments, CSV headers, cookie pairs |
| `concat` | `concat(delimiter, collection)` | Rebuild paths / log messages |
| `substring` | `substring(value, offset, length)` | Slice path or body window |
| `indexof` | `indexof(haystack, needle)` | Position of marker |
| `replace` | `replace(x, old, new)` | Normalize before match |
| `trim` / `trim_space` / `trim_prefix` / `trim_suffix` | various | Normalize whitespace / prefixes |
| `sprintf` | `sprintf(format, values)` | Decision messages / rule IDs |

### Regex

| Function | Signature | WAF use |
| --- | --- | --- |
| `regex.match` | `regex.match(pattern, value)` | Primary signature engine |
| `regex.is_valid` | `regex.is_valid(pattern)` | Validate user-supplied patterns safely |
| `regex.replace` | `regex.replace(s, pattern, value)` | Normalize (strip comments, collapse spaces) |
| `regex.find_n` | `regex.find_n(pattern, value, number)` | Extract first N hits |
| `regex.split` | `regex.split(pattern, value)` | Split on complex delimiters |

### Glob (path / host patterns)

| Function | Signature | WAF use |
| --- | --- | --- |
| `glob.match` | `glob.match(pattern, delimiters, match)` | `/api/*/users`, host wildcards |

Example: path glob with `/` delimiters:

```rego
glob.match("/admin/**", ["/"], input.path)
```

### Network / IP

| Function | Signature | WAF use |
| --- | --- | --- |
| `net.cidr_contains` | `net.cidr_contains(cidr, ip_or_cidr)` | Allow/deny lists, trusted proxies |
| `net.cidr_intersects` | `net.cidr_intersects(a, b)` | Overlap of two ranges |
| `net.cidr_is_valid` | `net.cidr_is_valid(cidr)` | Validate admin-configured CIDRs |
| `net.cidr_contains_matches` | `net.cidr_contains_matches(cidrs, ips)` | Batch IP ∈ any CIDR |

### Aggregates & membership

| Function | Signature | WAF use |
| --- | --- | --- |
| `count` | `count(collection)` | Header count, array length, set size |
| *(syntax)* `in` | `"x" in arr` / `key in obj` | Membership in allow/deny lists |

### Object / array access helpers

| Function | Signature | WAF use |
| --- | --- | --- |
| `object.get` | `object.get(object, key, default)` | Safe header lookup with default |
| `object.keys` | `object.keys(object)` | Enumerate headers / query keys |
| `object.filter` | `object.filter(object, keys)` | Keep only interesting headers |
| `object.remove` | `object.remove(object, keys)` | Drop hop-by-hop headers before inspect |
| `object.subset` | `object.subset(super, sub)` | Required header bag present? |
| `array.concat` | `array.concat(x, y)` | Merge deny lists |
| `array.slice` | `array.slice(arr, start, stop)` | Cap scan window |
| `array.flatten` | `array.flatten(arr)` | Flatten multi-value headers/query |

### Types & conversion

| Function | Signature | WAF use |
| --- | --- | --- |
| `is_string` / `is_number` / `is_array` / `is_object` / `is_boolean` / `is_null` | `is_*(x)` | Guard before string/regex ops |
| `type_name` | `type_name(x)` | Debug / defensive checks |
| `to_number` | `to_number(x)` | Parse Content-Length, ports, status |

### Numbers (limits)

| Function | Signature | WAF use |
| --- | --- | --- |
| `plus` / `minus` / `mul` / `div` / `rem` | `+ - * / %` | Thresholds, size math |
| `abs` | `abs(x)` | Absolute deltas |
| `numbers.range` | `numbers.range(a, b)` | Generate small integer ranges if needed |

### Sets (allow / deny lists)

| Function | Signature | WAF use |
| --- | --- | --- |
| `intersection` | `intersection(xs)` | Overlap of tag sets / roles |
| `union` | `union(xs)` | Merge allowlists |
| `and` / `or` / `minus` | `x & y`, `x \| y`, `x - y` | Set algebra on methods, tags, hosts |

---

## Tier 2 — Encoding & body inspection

Use when rules inspect encoded payloads, query strings, or JSON bodies.

### Encoding

| Function | Signature | WAF use |
| --- | --- | --- |
| `base64.decode` / `base64.encode` | `base64.*(x)` | Decode auth/payload blobs |
| `base64.is_valid` | `base64.is_valid(x)` | Detect base64-looking fields |
| `base64url.decode` / `base64url.encode` | `base64url.*(x)` | JWT-ish / URL-safe blobs |
| `urlquery.decode` / `urlquery.encode` | `urlquery.*(x)` | Decode `%xx` attack traffic |
| `urlquery.decode_object` | `urlquery.decode_object(x)` | Parse full query string → object |
| `urlquery.encode_object` | `urlquery.encode_object(object)` | Rebuild query for logging |
| `hex.decode` / `hex.encode` | `hex.*(x)` | Binary / obfuscated payloads |
| `json.is_valid` | `json.is_valid(x)` | Body looks like JSON? |
| `json.unmarshal` | `json.unmarshal(x)` | Parse JSON body for field rules |
| `json.marshal` | `json.marshal(x)` | Serialize for logs / comparisons |

### JSON path-ish helpers

| Function | Signature | WAF use |
| --- | --- | --- |
| `json.filter` | `json.filter(object, paths)` | Keep only sensitive paths |
| `json.remove` | `json.remove(object, paths)` | Drop noise before rules |
| `json.patch` | `json.patch(target, patches)` | Rare; rewrite for test fixtures |
| `json.match_schema` | `json.match_schema(document, schema)` | Schema validation of body |
| `json.verify_schema` | `json.verify_schema(schema)` | Validate admin-supplied schema |

### URI

| Function | Signature | WAF use |
| --- | --- | --- |
| `uri.parse` | `uri.parse(x)` | Split scheme/host/path/query |
| `uri.is_valid` | `uri.is_valid(x)` | Reject malformed URLs |

### String extras

| Function | Signature | WAF use |
| --- | --- | --- |
| `strings.count` | `strings.count(search, substring)` | Count occurrences of a token |
| `strings.any_prefix_match` | `strings.any_prefix_match(search, prefixes)` | Path starts with any of N prefixes |
| `strings.any_suffix_match` | `strings.any_suffix_match(search, suffixes)` | Extension in deny list |
| `strings.replace_n` | `strings.replace_n(patterns, value)` | Multi-pattern normalize |
| `indexof_n` | `indexof_n(haystack, needle)` | All match positions |
| `format_int` | `format_int(number, base)` | Hex dumps / rule diagnostics |

---

## Tier 3 — Auth, time, crypto (optional)

Only if your WAF product exposes auth tokens, rate windows, or integrity checks.

### JWT / tokens

| Function | Signature | WAF use |
| --- | --- | --- |
| `io.jwt.decode` | `io.jwt.decode(jwt)` | Inspect claims without verify |
| `io.jwt.decode_verify` | `io.jwt.decode_verify(jwt, constraints)` | Verify + claims checks |
| `io.jwt.verify_hs256` / `rs256` / … | `io.jwt.verify_*(jwt, key)` | Algorithm-specific verify |

### Time (rate / expiry style rules)

| Function | Signature | WAF use |
| --- | --- | --- |
| `time.now_ns` | `time.now_ns()` | Current time (non-deterministic; careful in tests) |
| `time.parse_rfc3339_ns` | `time.parse_rfc3339_ns(value)` | Parse token / header expiry |
| `time.parse_ns` | `time.parse_ns(layout, value)` | Custom date layouts |
| `time.parse_duration_ns` | `time.parse_duration_ns(duration)` | `"5m"`, `"1h"` windows |
| `time.diff` | `time.diff(ns1, ns2)` | Age of token / session |
| `time.add_date` | `time.add_date(ns, y, m, d)` | Expiry arithmetic |

### Light crypto / fingerprinting

| Function | Signature | WAF use |
| --- | --- | --- |
| `crypto.sha256` / `crypto.sha1` / `crypto.md5` | `crypto.*(x)` | Fingerprint body/UA (md5/sha1 only if required) |
| `crypto.hmac.sha256` | `crypto.hmac.sha256(x, key)` | Signed request / webhook checks |
| `crypto.hmac.equal` | `crypto.hmac.equal(a, b)` | Constant-time MAC compare |

### Units

| Function | Signature | WAF use |
| --- | --- | --- |
| `units.parse_bytes` | `units.parse_bytes(x)` | `"10MB"` body size limits from config |
| `units.parse` | `units.parse(x)` | General SI unit strings |

### Debugging

| Function | Signature | WAF use |
| --- | --- | --- |
| `trace` | `trace(note)` | Dev-time rule debugging |

---

## Deliberately **out of scope** for most WAF rules

Skip these unless product requirements demand them:

| Category | Why skip for WAF |
| --- | --- |
| GraphQL built-ins | Only if you parse GraphQL at the WAF |
| `http.send` | Side-effecting; usually forbidden in pure rule eval |
| `net.lookup_ip_addr` | DNS at eval time is slow / flaky |
| `net.cidr_expand` | Huge expansions; prefer `cidr_contains` |
| Graph (`walk`, `reachable`) | Not typical HTTP request shape |
| YAML | Prefer JSON for request bodies |
| X.509 / mTLS parse suite | Edge/TLS terminator concern, not rule body |
| `providers.aws.*` | Not WAF |
| `opa.runtime` / `rego.metadata.*` | Runtime meta, not request policy |
| `rand.intn` | Non-deterministic decisions hurt auditability |
| `semver.*` | Rare unless versioning APIs in rules |
| `uuid.*` | Only if you validate UUID-shaped IDs |

---

## Suggested starter set (implement first)

If you only ship a **small runtime** (e.g. rego2lua for WAF), implement these first:

```text
# compare
==  !=  >  >=  <  <=

# string
contains  startswith  endswith  lower  upper
split  concat  substring  replace  trim_space
sprintf

# regex / glob
regex.match  regex.is_valid  regex.replace
glob.match

# net
net.cidr_contains  net.cidr_is_valid

# collections
count  object.get  object.keys
array.concat  array.slice

# types
is_string  is_number  is_array  is_object  is_boolean  is_null
to_number

# encoding (body / query)
urlquery.decode  urlquery.decode_object
base64.decode  base64.is_valid
json.is_valid  json.unmarshal

# sets (allow/deny)
intersection  union  minus
```

Language features you will also need (not “functions” but essential):

```text
not          # negation
in           # membership
_            # iteration / “any element”
:=           # assignment
default      # default rule value
```

---

## Example WAF-style rules (sketch)

```rego
package waf

import rego.v1

default allow := false

# Block path prefix (case-insensitive)
deny contains "admin path" if {
	startswith(lower(input.path), "/admin")
}

# IP allowlist
allow if {
	net.cidr_contains("10.0.0.0/8", input.client_ip)
}

# Header exact match
deny contains "bad ua" if {
	ua := object.get(input.headers, "user-agent", "")
	contains(lower(ua), "sqlmap")
}

# Regex on query
deny contains "sqli" if {
	some k, v in input.query
	regex.match(`(?i)union\s+select`, v)
}

# Body size via string length (if body is string)
deny contains "body too large" if {
	is_string(input.body)
	count(input.body) > 1048576
}
```

---

## Mapping to rego2lua priorities

For this repo’s IR → Lua path, unlock tests roughly in this order:

1. Comparisons + `object.get` / field access  
2. `contains` / `startswith` / `endswith` / `lower`  
3. `count` + `in` / scan  
4. `regex.match`  
5. `net.cidr_contains`  
6. `urlquery.*` / `base64.*` / `json.unmarshal`  
7. Everything else as needed by product rules  

See also: project goal in `AGENTS.md` and implementation notes in the IR guide.
