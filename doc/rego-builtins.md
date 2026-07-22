# Rego Built-in Functions

Catalog of built-in functions in the OPA Rego policy language.

Source: [Rego Built-ins | Open Policy Agent](https://www.openpolicyagent.org/docs/policy-reference/builtins)

There are roughly **187 built-ins** across **32 categories** in current OPA docs.

Not all are available everywhere:

- **Wasm** — available in Wasm-compiled policies
- **SDK-dependent** — need full OPA / SDK (not Wasm-only)

Some operators are dual-purpose (e.g. `minus` / `-` for numbers and sets). Membership `in` and keywords like `not` are language syntax, not named built-in functions.

---

## Aggregates

| Function | Signature |
| --- | --- |
| `count` | `n := count(collection)` |
| `max` | `n := max(collection)` |
| `min` | `n := min(collection)` |
| `product` | `n := product(collection)` |
| `sort` | `n := sort(collection)` |
| `sum` | `n := sum(collection)` |

## Array

| Function | Signature |
| --- | --- |
| `array.concat` | `z := array.concat(x, y)` |
| `array.flatten` | `flattened := array.flatten(arr)` |
| `array.reverse` | `rev := array.reverse(arr)` |
| `array.slice` | `slice := array.slice(arr, start, stop)` |

## Bits

| Function | Signature |
| --- | --- |
| `bits.and` | `z := bits.and(x, y)` |
| `bits.lsh` | `z := bits.lsh(x, s)` |
| `bits.negate` | `z := bits.negate(x)` |
| `bits.or` | `z := bits.or(x, y)` |
| `bits.rsh` | `z := bits.rsh(x, s)` |
| `bits.xor` | `z := bits.xor(x, y)` |

## Comparison

| Function | Signature |
| --- | --- |
| `equal` | `x == y` |
| `gt` | `x > y` |
| `gte` | `x >= y` |
| `lt` | `x < y` |
| `lte` | `x <= y` |
| `neq` | `x != y` |

## Conversions

| Function | Signature |
| --- | --- |
| `to_number` | `num := to_number(x)` |

## Crypto

| Function | Signature |
| --- | --- |
| `crypto.hmac.equal` | `result := crypto.hmac.equal(mac1, mac2)` |
| `crypto.hmac.md5` | `y := crypto.hmac.md5(x, key)` |
| `crypto.hmac.sha1` | `y := crypto.hmac.sha1(x, key)` |
| `crypto.hmac.sha256` | `y := crypto.hmac.sha256(x, key)` |
| `crypto.hmac.sha512` | `y := crypto.hmac.sha512(x, key)` |
| `crypto.md5` | `y := crypto.md5(x)` |
| `crypto.parse_private_keys` | `output := crypto.parse_private_keys(keys)` |
| `crypto.sha1` | `y := crypto.sha1(x)` |
| `crypto.sha256` | `y := crypto.sha256(x)` |
| `crypto.x509.parse_and_verify_certificates` | `output := crypto.x509.parse_and_verify_certificates(certs)` |
| `crypto.x509.parse_and_verify_certificates_with_options` | `output := crypto.x509.parse_and_verify_certificates_with_options(certs, options)` |
| `crypto.x509.parse_certificate_request` | `output := crypto.x509.parse_certificate_request(csr)` |
| `crypto.x509.parse_certificates` | `output := crypto.x509.parse_certificates(certs)` |
| `crypto.x509.parse_keypair` | `output := crypto.x509.parse_keypair(cert, pem)` |
| `crypto.x509.parse_rsa_private_key` | `output := crypto.x509.parse_rsa_private_key(pem)` |

## Encoding

| Function | Signature |
| --- | --- |
| `base64.decode` | `y := base64.decode(x)` |
| `base64.encode` | `y := base64.encode(x)` |
| `base64.is_valid` | `result := base64.is_valid(x)` |
| `base64url.decode` | `y := base64url.decode(x)` |
| `base64url.encode` | `y := base64url.encode(x)` |
| `base64url.encode_no_pad` | `y := base64url.encode_no_pad(x)` |
| `hex.decode` | `y := hex.decode(x)` |
| `hex.encode` | `y := hex.encode(x)` |
| `json.is_valid` | `result := json.is_valid(x)` |
| `json.marshal` | `y := json.marshal(x)` |
| `json.marshal_with_options` | `y := json.marshal_with_options(x, opts)` |
| `json.unmarshal` | `y := json.unmarshal(x)` |
| `urlquery.decode` | `y := urlquery.decode(x)` |
| `urlquery.decode_object` | `object := urlquery.decode_object(x)` |
| `urlquery.encode` | `y := urlquery.encode(x)` |
| `urlquery.encode_object` | `y := urlquery.encode_object(object)` |
| `yaml.is_valid` | `result := yaml.is_valid(x)` |
| `yaml.marshal` | `y := yaml.marshal(x)` |
| `yaml.unmarshal` | `y := yaml.unmarshal(x)` |

## Glob

| Function | Signature |
| --- | --- |
| `glob.match` | `result := glob.match(pattern, delimiters, match)` |
| `glob.quote_meta` | `output := glob.quote_meta(pattern)` |

## Graph

| Function | Signature |
| --- | --- |
| `graph.reachable` | `output := graph.reachable(graph, initial)` |
| `graph.reachable_paths` | `output := graph.reachable_paths(graph, initial)` |
| `walk` | `walk(x, output)` |

## GraphQL

| Function | Signature |
| --- | --- |
| `graphql.is_valid` | `output := graphql.is_valid(query, schema)` |
| `graphql.parse` | `output := graphql.parse(query, schema)` |
| `graphql.parse_and_verify` | `output := graphql.parse_and_verify(query, schema)` |
| `graphql.parse_query` | `output := graphql.parse_query(query)` |
| `graphql.parse_schema` | `output := graphql.parse_schema(schema)` |
| `graphql.schema_is_valid` | `output := graphql.schema_is_valid(schema)` |

## HTTP

| Function | Signature |
| --- | --- |
| `http.send` | `response := http.send(request)` |

## Net

| Function | Signature |
| --- | --- |
| `net.cidr_contains` | `result := net.cidr_contains(cidr, cidr_or_ip)` |
| `net.cidr_contains_matches` | `output := net.cidr_contains_matches(cidrs, cidrs_or_ips)` |
| `net.cidr_expand` | `hosts := net.cidr_expand(cidr)` |
| `net.cidr_intersects` | `result := net.cidr_intersects(cidr1, cidr2)` |
| `net.cidr_is_valid` | `result := net.cidr_is_valid(cidr)` |
| `net.cidr_merge` | `output := net.cidr_merge(addrs)` |
| `net.lookup_ip_addr` | `addrs := net.lookup_ip_addr(name)` |

## Numbers

| Function | Signature |
| --- | --- |
| `abs` | `y := abs(x)` |
| `ceil` | `y := ceil(x)` |
| `div` | `x / y` |
| `floor` | `y := floor(x)` |
| `minus` | `x - y` |
| `mul` | `x * y` |
| `numbers.range` | `range := numbers.range(a, b)` |
| `numbers.range_step` | `range := numbers.range_step(a, b, step)` |
| `plus` | `x + y` |
| `rand.intn` | `y := rand.intn(str, n)` |
| `rem` | `x % y` |
| `round` | `y := round(x)` |

## Object / JSON

| Function | Signature |
| --- | --- |
| `json.filter` | `filtered := json.filter(object, paths)` |
| `json.match_schema` | `output := json.match_schema(document, schema)` |
| `json.patch` | `output := json.patch(target, patches)` |
| `json.remove` | `output := json.remove(object, paths)` |
| `json.verify_schema` | `output := json.verify_schema(schema)` |
| `object.filter` | `filtered := object.filter(object, keys)` |
| `object.get` | `value := object.get(object, key, default)` |
| `object.keys` | `value := object.keys(object)` |
| `object.remove` | `output := object.remove(object, keys)` |
| `object.subset` | `result := object.subset(super, sub)` |
| `object.union` | `output := object.union(a, b)` |
| `object.union_n` | `output := object.union_n(objects)` |

## OPA

| Function | Signature |
| --- | --- |
| `opa.runtime` | `output := opa.runtime()` |

## Providers (AWS)

| Function | Signature |
| --- | --- |
| `providers.aws.sign_req` | `signed_request := providers.aws.sign_req(request, aws_config, time_ns)` |

## Regex

| Function | Signature |
| --- | --- |
| `regex.find_all_string_submatch_n` | `output := regex.find_all_string_submatch_n(pattern, value, number)` |
| `regex.find_n` | `output := regex.find_n(pattern, value, number)` |
| `regex.globs_match` | `result := regex.globs_match(glob1, glob2)` |
| `regex.is_valid` | `result := regex.is_valid(pattern)` |
| `regex.match` | `result := regex.match(pattern, value)` |
| `regex.replace` | `output := regex.replace(s, pattern, value)` |
| `regex.split` | `output := regex.split(pattern, value)` |
| `regex.template_match` | `result := regex.template_match(template, value, delimiter_start, delimiter_end)` |

## Rego

| Function | Signature |
| --- | --- |
| `rego.metadata.chain` | `chain := rego.metadata.chain()` |
| `rego.metadata.rule` | `output := rego.metadata.rule()` |
| `rego.parse_module` | `output := rego.parse_module(filename, rego)` |

## Semver

| Function | Signature |
| --- | --- |
| `semver.compare` | `result := semver.compare(a, b)` |
| `semver.is_valid` | `result := semver.is_valid(vsn)` |

## Sets

| Function | Signature |
| --- | --- |
| `and` | `x & y` |
| `intersection` | `y := intersection(xs)` |
| `minus` | `x - y` (set difference) |
| `or` | `x \| y` |
| `union` | `y := union(xs)` |

## Strings

| Function | Signature |
| --- | --- |
| `concat` | `output := concat(delimiter, collection)` |
| `contains` | `result := contains(haystack, needle)` |
| `endswith` | `result := endswith(search, base)` |
| `format_int` | `output := format_int(number, base)` |
| `indexof` | `output := indexof(haystack, needle)` |
| `indexof_n` | `output := indexof_n(haystack, needle)` |
| `lower` | `y := lower(x)` |
| `replace` | `y := replace(x, old, new)` |
| `split` | `ys := split(x, delimiter)` |
| `sprintf` | `output := sprintf(format, values)` |
| `startswith` | `result := startswith(search, base)` |
| `strings.any_prefix_match` | `result := strings.any_prefix_match(search, base)` |
| `strings.any_suffix_match` | `result := strings.any_suffix_match(search, base)` |
| `strings.count` | `output := strings.count(search, substring)` |
| `strings.render_template` | `result := strings.render_template(value, vars)` |
| `strings.replace_n` | `output := strings.replace_n(patterns, value)` |
| `strings.reverse` | `y := strings.reverse(x)` |
| `substring` | `output := substring(value, offset, length)` |
| `trim` | `output := trim(value, cutset)` |
| `trim_left` | `output := trim_left(value, cutset)` |
| `trim_prefix` | `output := trim_prefix(value, prefix)` |
| `trim_right` | `output := trim_right(value, cutset)` |
| `trim_space` | `output := trim_space(value)` |
| `trim_suffix` | `output := trim_suffix(value, suffix)` |
| `upper` | `y := upper(x)` |

## Time

| Function | Signature |
| --- | --- |
| `time.add_date` | `output := time.add_date(ns, years, months, days)` |
| `time.clock` | `output := time.clock(x)` |
| `time.date` | `date := time.date(x)` |
| `time.diff` | `output := time.diff(ns1, ns2)` |
| `time.format` | `formatted := time.format(x)` |
| `time.now_ns` | `now := time.now_ns()` |
| `time.parse_duration_ns` | `ns := time.parse_duration_ns(duration)` |
| `time.parse_ns` | `ns := time.parse_ns(layout, value)` |
| `time.parse_rfc3339_ns` | `ns := time.parse_rfc3339_ns(value)` |
| `time.weekday` | `day := time.weekday(x)` |

## Tokens (JWT)

| Function | Signature |
| --- | --- |
| `io.jwt.decode` | `output := io.jwt.decode(jwt)` |
| `io.jwt.decode_verify` | `output := io.jwt.decode_verify(jwt, constraints)` |
| `io.jwt.verify_eddsa` | `result := io.jwt.verify_eddsa(jwt, certificate)` |
| `io.jwt.verify_es256` | `result := io.jwt.verify_es256(jwt, certificate)` |
| `io.jwt.verify_es384` | `result := io.jwt.verify_es384(jwt, certificate)` |
| `io.jwt.verify_es512` | `result := io.jwt.verify_es512(jwt, certificate)` |
| `io.jwt.verify_hs256` | `result := io.jwt.verify_hs256(jwt, secret)` |
| `io.jwt.verify_hs384` | `result := io.jwt.verify_hs384(jwt, secret)` |
| `io.jwt.verify_hs512` | `result := io.jwt.verify_hs512(jwt, secret)` |
| `io.jwt.verify_ps256` | `result := io.jwt.verify_ps256(jwt, certificate)` |
| `io.jwt.verify_ps384` | `result := io.jwt.verify_ps384(jwt, certificate)` |
| `io.jwt.verify_ps512` | `result := io.jwt.verify_ps512(jwt, certificate)` |
| `io.jwt.verify_rs256` | `result := io.jwt.verify_rs256(jwt, certificate)` |
| `io.jwt.verify_rs384` | `result := io.jwt.verify_rs384(jwt, certificate)` |
| `io.jwt.verify_rs512` | `result := io.jwt.verify_rs512(jwt, certificate)` |

## Token signing

| Function | Signature |
| --- | --- |
| `io.jwt.encode_sign` | `output := io.jwt.encode_sign(headers, payload, key)` |
| `io.jwt.encode_sign_raw` | `output := io.jwt.encode_sign_raw(headers, payload, key)` |

## Tracing

| Function | Signature |
| --- | --- |
| `trace` | `result := trace(note)` |

## Types

| Function | Signature |
| --- | --- |
| `is_array` | `result := is_array(x)` |
| `is_boolean` | `result := is_boolean(x)` |
| `is_null` | `result := is_null(x)` |
| `is_number` | `result := is_number(x)` |
| `is_object` | `result := is_object(x)` |
| `is_set` | `result := is_set(x)` |
| `is_string` | `result := is_string(x)` |
| `type_name` | `type := type_name(x)` |

## Units

| Function | Signature |
| --- | --- |
| `units.parse` | `y := units.parse(x)` |
| `units.parse_bytes` | `y := units.parse_bytes(x)` |

## URI

| Function | Signature |
| --- | --- |
| `uri.is_valid` | `result := uri.is_valid(x)` |
| `uri.parse` | `output := uri.parse(x)` |

## UUID

| Function | Signature |
| --- | --- |
| `uuid.parse` | `output := uuid.parse(uuid)` |
| `uuid.rfc4122` | `output := uuid.rfc4122(str)` |

---

## See also

- Full signatures, args, and examples: https://www.openpolicyagent.org/docs/policy-reference/builtins
- Category pages under: https://www.openpolicyagent.org/docs/policy-reference/builtins/
