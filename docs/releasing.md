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
| `v0.0.1-dev` | This snapshot (translator exists; `sanity.t` 9/11) |
| `v0.0.1` | `prove t/sanity.t` fully green (`NotStmt`) |
| `v0.0.2` | Next unlocked suite (scalars or remaining access) |
| `v0.1.0` | First advertised usable subset (`./go` green, or a written subset note) |

Stay on GitHub **pre-releases** until `v0.1.0`. Never retag; bump `VERSION` in a commit, then tag that commit.

## This snapshot (`0.0.1-dev`)

1. Docs + license + version land on `main`.
2. `prove t/runtime.t t/sanity.t t/cmp_eq.t` (expect sanity 9/11 until `NotStmt`).
3. Annotated tag:

   ```bash
   git tag -a v0.0.1-dev -m "rego2lua 0.0.1-dev: first IR→Lua developer snapshot"
   ```

4. `git push origin main --tags`.
5. GitHub → Releases → draft from the tag → mark **pre-release** → paste the matching [`CHANGELOG.md`](../CHANGELOG.md) section. Source zip/tarball is enough.

## Not published yet

| Channel | Why later |
|---------|-----------|
| PyPI / `pip install` | No `pyproject.toml`; the product is a repo script + `runtime/`. |
| LuaRocks | Generated modules `loadfile` the in-tree runtime; no rockspec. |
| Docker / binary | Needs OPA + Python + LuaJIT; a container is a convenience wrap. |
| GitHub Actions | Useful next; not required to publish a source tag. |

## Next tags (not this snapshot)

One user-visible capability per tag. Same commit prefixes (`doc:`, `feature:`, `bugfix:`, `tests:`).
