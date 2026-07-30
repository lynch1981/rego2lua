# 99 — Stmt catalog

Index of all OPA Rego IR statement kinds.  
Official parameter tables: https://www.openpolicyagent.org/docs/ir  

**Tiers**

| Tier | Meaning |
|------|---------|
| **must** | Implement for a useful plan runner / Lua backend |
| **common** | Appears in normal policies |
| **rare** | Edge / planner-internal / skip until needed |
| **skip** | Debug-only or almost never in real plans |

**Examples** refer to folders under [`examples/`](./examples/).

Coverage from the runnable suite: **28 / 34** kinds (~**82%**). Missing are marked below.

---

## Catalog

| Stmt | Tier | Example | One-line | Lua note |
|------|------|---------|----------|----------|
| **CallStmt** | must | 01 | Named call → `result` local | `L[r]=f(args)` new frame for planned funcs |
| **CallDynamicStmt** | rare | — | Call by path | resolve path then call |
| **ReturnLocalStmt** | must | 01 | Return local from func | `return L[source]` only |
| **ResultSetAddStmt** | must | 01 | Add solution object to plan result set | `rs[#rs+1]=L[v]` |
| **AssignVarStmt** | must | 01 | Copy operand → local | `L[t]=src` rewrite OK |
| **AssignVarOnceStmt** | must | 01 | Write-once; conflict if different | first bind / same OK / else error |
| **AssignIntStmt** | common | 06 | Local := int64 | index temps |
| **ResetLocalStmt** | must | 01 | Local := undefined | sentinel `UNDEF` if ≠ null |
| **DotStmt** | must | 01 | `source[key]` → target | undefined if missing |
| **EqualStmt** | must | 01 | `a==b` or undefined | block fail if not equal |
| **NotEqualStmt** | common | 03,05 | `a!=b` or undefined | |
| **IsDefinedStmt** | must | 01 | Bare local must be defined | slot binding test |
| **IsUndefinedStmt** | must | 01 | Bare local must be undefined | |
| **IsArrayStmt** | common | 06 | Type guard array | |
| **IsObjectStmt** | rare | —* | Type guard object | same pattern as IsArray |
| **IsSetStmt** | rare | —* | Type guard set | same pattern |
| **LenStmt** | common | 06 | `target:=len(source)` | not the same as `count()` builtin |
| **MakeObjectStmt** | must | 01 | `{}` | `L[t]={}` |
| **ObjectInsertStmt** | must | 01 | `obj[k]=v` overwrite OK | |
| **ObjectInsertOnceStmt** | rare | —* | Insert; conflict if different | like AssignVarOnce for keys |
| **ObjectMergeStmt** | common | 04 | Deep merge a,b → target | see 04 for win policy |
| **MakeArrayStmt** | common | 02 | `[]` + capacity hint | ignore capacity |
| **ArrayAppendStmt** | common | 02 | Append at end | `t[#t+1]=v` |
| **MakeSetStmt** | common | 05 | Empty set | |
| **SetAddStmt** | common | 05 | Add element | |
| **MakeNullStmt** | rare | —* | `target:=null` | `L[t]=nil` |
| **MakeNumberIntStmt** | common | 06 | Number from int64 | |
| **MakeNumberRefStmt** | common | 04,06 | Number from `static.strings[i]` | parse decimal text |
| **ScanStmt** | must | 02 | Only loop; block per element | `for` key/value |
| **BlockStmt** | common | 03,04, **08** | Nested blocks | else / planner structure — see [08](./08-block-and-break.md) |
| **BreakStmt** | common | 04, **08** | Jump out N blocks | try/success/fallback — see [08](./08-block-and-break.md) |
| **NotStmt** | common | 03,05 | Succeed if block fails | negation-as-failure |
| **WithStmt** | common | 07 | Temp mutate local, run block | save/restore |
| **NopStmt** | skip | — | No-op | ignore |

\*Not emitted by the suite; implement when you see them (same patterns as neighbors).

---

## By example

| Example | Stmts (union of kinds in its `plan.json`) |
|---------|-------------------------------------------|
| **01-spine-allow** | Call, AssignVar, AssignVarOnce, Reset, Dot, Equal, IsDefined, IsUndefined, MakeObject, ObjectInsert, ResultSetAdd, Return |
| **02-scan-arrays** | + Scan, MakeArray, ArrayAppend, Block |
| **03-not-else** | + Not, NotEqual, Block |
| **04-merge** | + ObjectMerge, Break, MakeNumberRef, Block |
| **05-sets** | + MakeSet, SetAdd, Not |
| **06-len-unify** | + Len, IsArray, AssignInt, MakeNumberInt |
| **07-with** | + With |

---

## Must-implement checklist (Lua backend v1)

- [ ] CallStmt (planned funcs + builtins)
- [ ] ReturnLocalStmt / ResultSetAddStmt
- [ ] AssignVar / AssignVarOnce / ResetLocal
- [ ] Dot / Equal / NotEqual
- [ ] IsDefined / IsUndefined
- [ ] MakeObject / ObjectInsert
- [ ] ScanStmt
- [ ] MakeArray / ArrayAppend
- [ ] NotStmt / BlockStmt
- [ ] frames: input/data args, dynamic `L` table

Then: ObjectMerge, sets, With, Len/IsArray, number makes.

---

## Missing from suite (6)

| Stmt | How to get it later |
|------|---------------------|
| CallDynamicStmt | dynamic data function call paths |
| IsObjectStmt / IsSetStmt | unify with object/set literals (like 06) |
| ObjectInsertOnceStmt | multi-definition object construction |
| MakeNullStmt | explicit null in rule body |
| NopStmt | ignore |

---

## Related reading

- [00-execution-model.md](./00-execution-model.md)
- [00b-control-flow.md](./00b-control-flow.md)
- Official IR: https://www.openpolicyagent.org/docs/ir
