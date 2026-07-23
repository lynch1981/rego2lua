# Learning Tokenization for Rego

> **Educational only — not the production path.**  
> Production **rego2lua** starts from **OPA plan IR (JSON)** and emits Lua; OPA already lexes/parses Rego. Do **not** implement a project lexer/parser unless the charter explicitly pivots.  
> Production docs: [`ir2lua-guide.md`](./ir2lua-guide.md), [`AGENTS.md`](../AGENTS.md). Companion learning note: [`learning-ast.md`](./learning-ast.md).

> Study note: how a Rego lexer would turn source into a token stream before parsing — for compiler learning only.

---

## 1. Why study a lexer (even though production skips it)

In a **classic** source-to-source compiler the pipeline looks like:

```text
Rego source  →  Lexer  →  Tokens  →  Parser  →  AST  →  Lua
```

**rego2lua production pipeline** (what agents implement) is shorter:

```text
Rego source  →  OPA (`opa build -t plan`)  →  plan.json (IR)  →  IR→Lua codegen  →  Lua
```

This note still describes the lexer’s job so the learning path makes sense:

1. Read characters from the Rego module (the `--- Rego` section of our tests).
2. Emit a sequence of **tokens** (kind + text + location).
3. Skip comments and insignificant whitespace (or keep newlines if you want position accuracy).

It does **not** understand packages, rules, or precedence. That is the parser’s job (see `learning-ast.md`).
---

## 2. What we tokenize (v0.1 subset)

Aligned with the current test suite (`sanity`, `scalars`, `access`, `membership`, `cmp_*`):

### Keywords

| Keyword | Example |
|---------|---------|
| `package` | `package foo` |
| `default` | `default allow := false` |
| `if` | `allow if { ... }` |
| `not` | `not input.method == "POST"` |
| `in` | `"admin" in input.roles` |
| `true` / `false` / `null` | scalar literals |

Treat these as **keyword tokens** when spelled exactly; otherwise the same spelling as an identifier is a normal `Ident` (Rego is case-sensitive).

### Identifiers

```text
allow  input  method  user  roles  foo
```

Pattern: letter or `_`, then letters, digits, `_`.

### Numbers

```text
42  3.14  0  -1
```

For v0.1, integers and simple decimals are enough (same as our scalar/comparison tests). Scientific notation can wait.

### Strings

```text
"GET"  "alice"  "hello"
```

Double-quoted only for v0.1. Inside the string, support at least `\"` and `\\` if you need escapes later; tests mostly use plain strings.

### Operators and punctuators (longest match matters)

| Token | Spelling | Notes |
|-------|----------|--------|
| `Assign` | `:=` | rule default / local bind |
| `Equal` | `==` | comparison |
| `NotEqual` | `!=` | comparison |
| `Gte` / `Lte` | `>=` `<=` | comparison |
| `Gt` / `Lt` | `>` `<` | comparison |
| `Dot` | `.` | `input.method` |
| `LBrack` / `RBrack` | `[` `]` | arrays, `roles[0]`, `roles[_]` |
| `LBrace` / `RBrace` | `{` `}` | rule body |
| `LParen` / `RParen` | `(` `)` | grouping (later) |
| `Comma` | `,` | (later) |
| `Underscore` | `_` | `input.roles[_]` |

### Comments (skip)

```rego
# line comment to end of line
```

Rego uses `#` line comments. They are separators, not tokens.

---

## 3. Why “split on spaces” is not enough

Rego (like C) glues tokens together:

```rego
input.method=="GET"
default allow:=false
input.roles[_]=="admin"
```

There is often **no** space between `method`, `==`, and `"GET"`.

So the lexer must scan **character by character** and decide the next token with rules, not `strsplit`.

---

## 4. Longest match (maximal munch)

When several operator patterns fit at the current position, take the **longest** legal one.

| Input | Correct | Wrong |
|-------|---------|--------|
| `:=` | one `Assign` | `:` + `=` (if you ever allow bare `:`) |
| `==` | one `Equal` | two `=` |
| `!=` | one `NotEqual` | `!` + `=` |
| `>=` | one `Gte` | `>` + `=` |
| `<=` | one `Lte` | `<` + `=` |

Algorithm sketch for operators:

1. At current position, try multi-character ops first (`:=`, `==`, `!=`, `>=`, `<=`).
2. Else try single-character ops (`.`, `[`, `]`, `{`, `}`, `>`, `<`, …).

Regex “greedy” on one big pattern is **not** the same as testing a **set of token rules** and picking the longest; implement the latter.

---

## 5. Recommended toy Rego lexer shape

### Token

```c
typedef enum {
    TOK_EOF,
    TOK_IDENT,
    TOK_KEYWORD,   /* or separate TOK_PACKAGE, TOK_DEFAULT, ... */
    TOK_NUMBER,
    TOK_STRING,
    TOK_ASSIGN,    /* := */
    TOK_EQ,        /* == */
    TOK_NE,        /* != */
    TOK_GT, TOK_GE, TOK_LT, TOK_LE,
    TOK_DOT,
    TOK_LBRACK, TOK_RBRACK,
    TOK_LBRACE, TOK_RBRACE,
    TOK_UNDER,     /* _ */
    /* ... */
} TokenKind;

typedef struct {
    TokenKind kind;
    const char *start;  /* pointer into source */
    int length;
    int line;
    int col;
} Token;
```

### `next_token()`

```text
skip whitespace and # comments
if EOF → TOK_EOF
if letter/_ → read ident; if keyword table hit → keyword else TOK_IDENT
if digit → read number
if " → read string to closing "
if starts with operator → longest match among := == != >= <= . [ ] { } _ etc.
else → error (illegal character)
```

### Keyword table

After reading an identifier, look it up:

```text
package default if not in true false null
```

Everything else stays `TOK_IDENT` (`allow`, `input`, `eq`, …).

---

## 6. Walkthrough: a real policy from our tests

Source (`sanity` / membership style):

```rego
package foo

default allow := false

allow if {
    "admin" in input.roles
}
```

Approximate token stream:

```text
PACKAGE   "package"
IDENT     "foo"
DEFAULT   "default"
IDENT     "allow"
ASSIGN    ":="
FALSE     "false"      # or IDENT if you special-case later
IDENT     "allow"
IF        "if"
LBRACE    "{"
STRING    "admin"
IN        "in"
IDENT     "input"
DOT       "."
IDENT     "roles"
RBRACE    "}"
EOF
```

Another snippet (array access):

```rego
input.roles[0] == "admin"
```

```text
IDENT input  DOT  IDENT roles  LBRACK  NUMBER 0  RBRACK  EQ  STRING "admin"
```

And some:

```rego
input.roles[_] == "admin"
```

```text
IDENT input  DOT  IDENT roles  LBRACK  UNDER  RBRACK  EQ  STRING "admin"
```

---

## 7. Mistakes to avoid

| Mistake | Why it hurts Rego |
|---------|-------------------|
| Split only on whitespace | Breaks `input.method=="GET"` |
| Prefer short ops | `==` becomes two `=` |
| Treat `_` only as ident char | Need a dedicated token for `roles[_]` |
| Forget `#` comments | Tokens absorb comment text |
| Emit `:` and `=` separately for `:=` | Parser cannot see assignment cleanly |
| Lowercase-fold keywords | Rego is case-sensitive |

---

## 8. Implementation order (practical)

1. `Token` + `next_token` over a string buffer.
2. Whitespace + `#` comments.
3. Identifiers + keyword table.
4. Numbers + strings.
5. Operators with longest match (`:=`, `==`, `!=`, `>=`, `<=`, then singles).
6. Drive with fixtures from `t/*.t` `--- Rego` sections (print tokens, no parse yet).
7. Hand off stream to the recursive-descent parser in `learning-ast.md`.

---

## 9. Relation to the rest of rego2lua

| Stage | Doc / code | Role |
|-------|------------|------|
| Behavioral contract | `t/*.t` (`--- out`) | What decisions must match |
| **Production frontend** | OPA plan IR | Lex/parse/compile — **not** in this repo |
| **Production backend** | [`ir2lua-guide.md`](./ir2lua-guide.md) | IR → Lua (Python codegen + runtime) |
| Learning: lexer | this note | Optional study only |
| Learning: AST + parser | [`learning-ast.md`](./learning-ast.md) | Optional study only |
| Bootstrap reference | `--- ref_lua` | Hand Lua until IR→Lua is trusted |

Once `next_token()` is stable **as a learning exercise**, a toy parser can consume tokens instead of raw characters. That work is **not** on the production critical path.

---

## 10. Status checklist

You should be able to:

- [ ] List v0.1 Rego token kinds used by current tests
- [ ] Explain why space-splitting fails on Rego
- [ ] Apply longest match to `:=` / `==` / `!=` / `>=` / `<=`
- [ ] Sketch `next_token()` for ident, number, string, ops
- [ ] Hand-tokenize a small policy from `t/sanity.t` or `t/membership.t`

**Optional practice (learning only):** sketch or implement a toy lexer against `--- Rego` samples, then read [`learning-ast.md`](./learning-ast.md).

**For product work:** follow [`ir2lua-guide.md`](./ir2lua-guide.md) and `AGENTS.md` (OPA IR → Lua). Do not land a production lexer here.
