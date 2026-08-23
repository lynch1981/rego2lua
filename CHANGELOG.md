# Changelog

All notable user-facing changes are listed here.

Version strings follow SemVer (`MAJOR.MINOR.PATCH`). Git tags add a `v` prefix.
Pre-releases use a SemVer suffix (`-dev`). See [`docs/releasing.md`](docs/releasing.md).

## Unreleased

### Added

- CLI `--dump-plan` / `-d FILE` writes the OPA plan IR JSON before codegen.

### Fixed

- Array index via `rt.dot` is Rego 0-based (`input.roles[0]` is the first element).

### Tests

- [`./ci`](ci) now includes `t/access.t`.

## [0.0.1] — 2026-08-22

`prove t/sanity.t t/not.t` is green (the original `v0.0.1` bar). Also green: `t/scalars.t` and all `t/cmp_*.t`. Still a developer preview; GitHub release is a **pre-release**.

### Added

- IR statements: `NotStmt`, `CallStmt`, `NotEqualStmt`, `BlockStmt`, `ScanStmt`, `MakeNumberRefStmt`, `MakeNullStmt`.
- GitHub Actions CI on pull requests ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)): Ubuntu 24.04, OPA 1.18.2. `./ci` / `./go` run `prove -j "$(nproc)"`.

### Supported language (this tag)

`package`, `default <rule> := false`, `if` body with field access, `==` / `!=` / order compares, implicit AND, `local :=`, `not`, scalars (string / number / boolean / null).

### Tests

| Suite | This tag |
|-------|----------|
| `t/runtime.t` | pass |
| `t/sanity.t` | pass |
| `t/not.t` | pass |
| `t/scalars.t` | pass |
| `t/cmp_*.t` | pass |
| `t/access.t` | fail (array index) |
| `t/membership.t` | fail (`in` / scan) |

Required bar [`./ci`](ci): `t/runtime.t`, `t/sanity.t`, `t/not.t`, `t/scalars.t`, `t/cmp_*.t`. [`./go`](go) is **not** green.

### Known limitations

- Generated Lua loads the runtime with `loadfile("runtime/rego_rt.lua")`. Evaluate from the **repo root** (or make that path resolve).
- Unknown IR statement types fail at generate time (fail closed).
- Not an OPA replacement: no array index, `in` / `some` / working scan, or a full builtin catalog.

## [0.0.1-dev] — 2026-08-17

First tagged **developer snapshot**. Not a complete Rego compiler. `prove t/sanity.t` is **9/11** (the two `not` cases fail).

### Added

- Pipeline: Rego → OPA (`opa build -t plan`) → plan IR → LuaJIT module.
- CLI: `./rego2lua <policy.rego>` writes Lua to stdout. Requires `opa` on `PATH`.
- Runtime slice **1.1.1** (`runtime/rego_rt.lua`): undefined, `dot`, compare, types, numbers.
- IR statements: `AssignVarStmt`, `AssignVarOnceStmt`, `ResetLocalStmt`, `DotStmt`, `EqualStmt`, `IsDefinedStmt`, `IsUndefinedStmt`, `ReturnLocalStmt`.

### Supported language (this tag)

`package`, `default <rule> := false`, `if` body with `input.field == …`, implicit AND, `local :=`, nested object field access.

### Tests

| Suite | This tag |
|-------|----------|
| `t/runtime.t` | 141/141 pass |
| `t/sanity.t` | 9/11 pass (`not` → missing `NotStmt`) |
| `t/cmp_eq.t` | 6/6 pass |
| `t/scalars.t` | 4/8 fail (`MakeNumberRefStmt`, `MakeNullStmt`) |
| `t/access.t` | 4/8 fail (array index → `MakeNumberRefStmt`) |
| `t/membership.t` | 0/4 (`CallStmt`, `ScanStmt`) |
| `t/cmp_ne.t` / `gt` / `gte` / `lt` / `lte` | all fail (`!=` / order) |

### Known limitations

- Generated Lua loads the runtime with `loadfile("runtime/rego_rt.lua")`. Evaluate from the **repo root** (or make that path resolve).
- Unknown IR statement types fail at generate time (fail closed).
- Not an OPA replacement: no `not`, `!=` / order compares, number/null IR constants, array index, `in` / `some` / scan, or planned `CallStmt`.

[0.0.1]: https://github.com/lynch1981/rego2lua/releases/tag/v0.0.1
[0.0.1-dev]: https://github.com/lynch1981/rego2lua/releases/tag/v0.0.1-dev
