# Releasing

How tags and GitHub pre-releases work for this repo.

## Version numbers

Product version is SemVer (`MAJOR.MINOR.PATCH`). The **git tag** adds a `v` prefix. Pre-releases use `-dev` so `0.0.1-dev` sorts **before** `0.0.1`.

| Place | Example |
|-------|---------|
| [`VERSION`](../VERSION), `ir2lua.__version__`, `rego2lua --version` | `0.0.1-dev` |
| Annotated git tag / GitHub Release | `v0.0.1-dev` |

### Planned sequence

| Tag | Meaning |
|-----|---------|
| `v0.0.1-dev` | This snapshot (translator exists; `sanity.t` 9/11 at tag time) |
| `v0.0.1` | `prove t/sanity.t t/not.t` green |
| `v0.0.2` | Next unlocked suite (scalars or remaining access) |
| `v0.1.0` | First advertised usable subset (`./go` green, or a written subset note) |

Stay on GitHub **pre-releases** until `v0.1.0`. Never retag; bump `VERSION` in a commit, then tag that commit.

## This snapshot (`0.0.1-dev`)

1. Docs + license + version land on `main`.
2. `prove t/runtime.t t/sanity.t t/cmp_eq.t` (green). `prove t/not.t` fails until `NotStmt`.
3. Annotated tag:

   ```bash
   git tag -a v0.0.1-dev -m "rego2lua 0.0.1-dev: first IR→Lua developer snapshot"
   ```

4. `git push origin main --tags`.
5. GitHub → Releases → draft from the tag → mark **pre-release** → paste the matching [`CHANGELOG.md`](../CHANGELOG.md) section. Source zip/tarball is enough.

## CI

Pull requests run [`.github/workflows/ci.yml`](../.github/workflows/ci.yml). Direct pushes to `main` do not.

The job installs the same Debian packages as local development (`luajit`, `lua-cjson`, `libtest-base-perl`), then installs the official OPA CLI with [`open-policy-agent/setup-opa@v2`](https://github.com/open-policy-agent/setup-opa) pinned to **1.18.2**. That puts `opa` on `PATH` so `./rego2lua` can run `opa build -t plan` — the same frontend as a developer laptop. System `python3` runs the translator. The pin exists because plan JSON is the compiler interface; do not float `latest`.

The required bar is [`./ci`](../ci) (`prove t/runtime.t t/sanity.t t/not.t t/scalars.t t/cmp_*.t`). [`./go`](../go) is the full suite and is **not** the gate until it is green. When a suite goes fully green, add it to `./ci` and mention it in the README.

## Not published yet

| Channel | Why later |
|---------|-----------|
| PyPI / `pip install` | No `pyproject.toml`; the product is a repo script + `runtime/`. |
| LuaRocks | Generated modules `loadfile` the in-tree runtime; no rockspec. |
| Docker / binary | Needs OPA + Python + LuaJIT; a container is a convenience wrap. |

## Next tags (not this snapshot)

One user-visible capability per tag. Same commit prefixes (`doc:`, `feature:`, `bugfix:`, `tests:`).
