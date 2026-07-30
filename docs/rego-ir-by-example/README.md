# Rego IR by Example

A **learning path** for OPA’s plan IR (`plan.json`), aimed at people building
evaluators or codegen (e.g. Lua). Complements the official reference:

- Official IR docs: https://www.openpolicyagent.org/docs/ir  
- This guide: **stories + runnable Rego + real plans + Lua sketches**

---

## How to read this

| Order | Doc | What you learn |
|------:|-----|----------------|
| 0 | [00-execution-model.md](./00-execution-model.md) | Locals, frames, defined/undefined, plan vs func |
| 0b | [00b-control-flow.md](./00b-control-flow.md) | Control-flow summary: blocks, undefined, Scan/Not/Block/Break/With |
| 1 | [01-spine-allow.md](./01-spine-allow.md) | End-to-end walk of a complete `allow` policy |
| 2 | [02-scan-and-arrays.md](./02-scan-and-arrays.md) | `ScanStmt`, `MakeArray`, `ArrayAppend` |
| 3 | [03-not-and-else.md](./03-not-and-else.md) | `NotStmt`, `BlockStmt`, `else` |
| 4 | [04-merge-base-virtual.md](./04-merge-base-virtual.md) | `ObjectMergeStmt` (data + rules) |
| 5 | [05-sets.md](./05-sets.md) | `MakeSetStmt`, `SetAddStmt` |
| 6 | [06-len-unify.md](./06-len-unify.md) | `LenStmt`, `IsArrayStmt`, `AssignIntStmt` |
| 7 | [07-with.md](./07-with.md) | `WithStmt` |
| 8 | [08-block-and-break.md](./08-block-and-break.md) | `BlockStmt`, `BreakStmt`, else vs multi-rule OR |
| ∞ | [99-stmt-catalog.md](./99-stmt-catalog.md) | All stmts → example, tier, Lua note |

**00 → 00b → spine (01)**, then satellites, then the catalog as an index.

---

## Design (why not one mega-policy)

- **One readable spine** covers the common path (~35–40% of stmt kinds).
- **Short satellites** unlock iteration, negation, merge, sets, length, `with`.
- Together the runnable examples hit **~82%** of IR stmt kinds (28 / 34).
- The rest are rare (`CallDynamic`, `Nop`, …) and listed in the catalog.

---

## Examples layout

```text
examples/
  01-spine-allow/   policy.rego  input.json   plan.json
  02-scan-arrays/   ...
  03-not-else/
  04-merge/         policy.rego  data.json    plan.json
  05-sets/
  06-len-unify/
  07-with/
  08-multi-allow/   # two allow if (OR) — contrast with BlockStmt
```

Regenerate a plan:

```bash
# single entrypoint
opa build -t plan -e example/allow examples/01-spine-allow/policy.rego \
  -o /tmp/b.tar.gz

# with base data
opa build -t plan -e example/config \
  examples/04-merge/policy.rego examples/04-merge/data.json \
  -o /tmp/b.tar.gz
```

Eval:

```bash
opa eval -d examples/01-spine-allow/policy.rego \
  -i examples/01-spine-allow/input.json \
  'data.example.allow' --format pretty
```

---

## Mental model in one picture

```text
Rego (declarative)
    │  opa build -t plan
    ▼
plan.json  =  static + plans + funcs
    │
    │  plans  → entrypoints → ResultSetAdd
    │  funcs  → rule bodies → ReturnLocal
    │  stmts  → ops on local slots
    ▼
Your runtime / Lua codegen
```

---

## Related

- Main implementation plan: [../ir2lua-guide.md](../ir2lua-guide.md)
- Official reference: [OPA Intermediate Representation](https://www.openpolicyagent.org/docs/ir)
