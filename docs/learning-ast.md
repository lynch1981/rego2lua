# Learning Abstract Syntax Trees (AST)

> **Educational only — not the production path.**  
> Production **rego2lua** does **not** parse Rego into an AST in-tree. OPA emits **plan IR (JSON)**; this project lowers IR → Lua. Do **not** implement a project parser/AST unless the charter explicitly pivots.  
> Production docs: [`ir2lua-guide.md`](./ir2lua-guide.md), [`AGENTS.md`](../AGENTS.md). Companion learning note: [`learning-tokenize.md`](./learning-tokenize.md).

> Study note: how ASTs work in a classic source-to-source compiler (Rego → Lua) — for learning only.

---

## 1. Background

In a **classic** compiler course project you might build a full frontend that converts a subset of **OPA Rego** into **Lua** via lexer → parser → AST → codegen.

**rego2lua production path** skips that frontend:

```text
Rego source  →  OPA (`opa build -t plan`)  →  plan.json (IR)  →  IR→Lua  →  Lua
```

The AST is still the most important intermediate structure for **understanding** compilers. This document records how ASTs are built and read — as study material, not as the repo implementation plan.

---

## 2. What is an AST?

An **Abstract Syntax Tree** is a tree data structure that represents the **structure and meaning** of source code.

It removes unnecessary details such as:
- Whitespace
- Comments
- Parentheses used only for grouping

### Example

Source code:
```rego
3 + 4 * 5
```

AST:
```
      +
     / \
    3   *
       / \
      4   5
```

The shape of the tree already encodes operator precedence.

---

## 3. Why Do We Need an AST?

- Raw source code is difficult to analyze
- A flat list of tokens is still hard to process
- The AST makes the program structure explicit
- It becomes much easier to:
  - Perform semantic checks
  - Transform the code
  - Generate target code (Lua in our case)

Typical compiler pipeline:

```
Source Code
    ↓
Lexer
    ↓
Tokens
    ↓
Parser
    ↓
AST
    ↓
Code Generator
    ↓
Target Code (Lua)
```

---

## 4. Representing AST Nodes in C

We use the classic **tagged union** style:

```c
typedef enum {
    NODE_NUMBER,
    NODE_BINARY,
    NODE_ASSIGN,
    // Future nodes: NODE_NOT, NODE_COMPARE, NODE_MEMBERSHIP, etc.
} NodeKind;

typedef struct AstNode AstNode;

struct AstNode {
    NodeKind kind;

    union {
        // NODE_NUMBER
        struct {
            double value;
        } number;

        // NODE_BINARY
        struct {
            char* op;           // "+", "-", "*", "/"
            AstNode* left;
            AstNode* right;
        } binary;

        // NODE_ASSIGN
        struct {
            char* name;
            AstNode* value;
        } assign;
    } as;
};
```

---

## 5. Helper Functions (Very Important)

Instead of writing `malloc` everywhere, we create constructor functions:

```c
#include <stdlib.h>
#include <string.h>

AstNode* make_number(double value) {
    AstNode* node = calloc(1, sizeof(AstNode));
    node->kind = NODE_NUMBER;
    node->as.number.value = value;
    return node;
}

AstNode* make_binary(const char* op, AstNode* left, AstNode* right) {
    AstNode* node = calloc(1, sizeof(AstNode));
    node->kind = NODE_BINARY;
    node->as.binary.op = strdup(op);
    node->as.binary.left = left;
    node->as.binary.right = right;
    return node;
}

AstNode* make_assign(const char* name, AstNode* value) {
    AstNode* node = calloc(1, sizeof(AstNode));
    node->kind = NODE_ASSIGN;
    node->as.assign.name = strdup(name);
    node->as.assign.value = value;
    return node;
}
```

**Usage example:**

```c
AstNode* tree = make_assign("x",
    make_binary("+",
        make_number(10),
        make_binary("*",
            make_number(20),
            make_number(3)
        )
    )
);
```

---

## 6. Progressive Examples

### 6.1 Just a number
```rego
42
```
```
Number(42)
```

### 6.2 Simple binary operation
```rego
10 + 20
```
```
Binary(+)
├── Number(10)
└── Number(20)
```

### 6.3 Assignment
```rego
x := 10 + 20
```
```
Assign
├── name: "x"
└── value: Binary(+)
           ├── Number(10)
           └── Number(20)
```

### 6.4 Nested expression with precedence
```rego
x := 10 + 20 * 3
```
```
Assign
└── Binary(+)
    ├── Number(10)
    └── Binary(*)
        ├── Number(20)
        └── Number(3)
```

---

## 7. How the Parser Builds the AST

### Parser helper: `expect`

The parser walks a **token stream** from the lexer (see `learning-tokenize.md`). A common helper asserts the next token kind and advances:

```c
/* Require current token to be `type`, then consume it; otherwise syntax error. */
void expect(TokenType type) {
    if (current() == type) {
        consume();
    } else {
        error("unexpected token");
    }
}
```

We use **Recursive Descent Parsing** with layered functions to handle operator precedence.

| Function              | Responsibility                  | Operators     |
|-----------------------|---------------------------------|---------------|
| `parse_statement()`   | Full statements                 | `:=`          |
| `parse_expression()`  | Lowest precedence               | `+` `-`       |
| `parse_term()`        | Higher precedence               | `*` `/`       |
| `parse_factor()`      | Highest priority (atoms)        | numbers, `()` |

Higher precedence functions are called by lower precedence functions.
This design **naturally solves operator precedence**.

The tree is always built **from the bottom up**.

---

## 8. Full Call Stack Example

Code:
```rego
result := 8 - 3 * 2 + 4
```

Call stack:

```
parse_statement()
└── parse_expression()
    ├── parse_term()
    │   └── parse_factor() → Number(8)
    ├── consume '-'
    ├── parse_term()
    │   ├── parse_factor() → Number(3)
    │   ├── consume '*'
    │   └── parse_factor() → Number(2)
    │   └── create Binary(*)
    ├── create Binary(-)
    ├── consume '+'
    └── parse_term()
        └── parse_factor() → Number(4)
    └── create Binary(+)
└── create Assign
```

Final AST:
```
Assign("result")
└── Binary(+)
    ├── Binary(-)
    │   ├── Number(8)
    │   └── Binary(*)
    │       ├── Number(3)
    │       └── Number(2)
    └── Number(4)
```

This correctly represents: `(8 - (3 * 2)) + 4`

---

## 9. Core Pseudocode

```c
AstNode* parse_statement() {
    char* name = expect(Ident);         // "result"
    expect(Assign);                     // ":="
    AstNode* value = parse_expression();
    return make_assign(name, value);
}

AstNode* parse_expression() {           // handles + and -
    AstNode* left = parse_term();

    while (current() == Plus || current() == Minus) {
        char* op = consume();
        AstNode* right = parse_term();
        left = make_binary(op, left, right);
    }
    return left;
}

AstNode* parse_term() {                 // handles * and /
    AstNode* left = parse_factor();

    while (current() == Star || current() == Slash) {
        char* op = consume();
        AstNode* right = parse_factor();
        left = make_binary(op, left, right);
    }
    return left;
}

AstNode* parse_factor() {
    if (current() == Number) {
        return make_number(consume_number());
    }

    if (current() == LParen) {          // '('
        consume();
        AstNode* expr = parse_expression();
        expect(RParen);                 // ')'
        return expr;
    }

    error("Expected number or '('");
    return NULL;
}
```

---

## 10. Other Methods to Handle Precedence

While learning, we also briefly discussed two other classic approaches:

1. **Precedence Climbing**
2. **Shunting Yard Algorithm** (Dijkstra)

We decided to fully master **Recursive Descent** first, because it is the most educational and easiest to debug.

---

## 11. Connection to the Rego → Lua project

AST fluency helps you reason about compilers, but **it is not the production intermediate** for this repo. Production walks **OPA plan IR** (statements, locals, blocks), not a hand-built Rego AST. See [`ir2lua-guide.md`](./ir2lua-guide.md).

Earlier learning designs (for study only) included:
- A formal grammar for a practical v0.1 subset of Rego
- A detailed C-style AST for Rego constructs (`Module`, `Package`, `DefaultRule`, `CompleteRule`, `Query`, expressions, references, etc.)

Those designs remain useful background. They are **not** a backlog item for agents implementing rego2lua.

---

## 12. Current Learning Status

You now understand:

- What an AST is and why it is needed
- How to read and draw ASTs
- How to represent nodes in C (tagged union)
- How to write constructor helpers (`make_*`)
- How a recursive descent parser builds the tree
- How operator precedence is handled by function layering
- The complete call stack behavior
- The core pseudocode pattern

---

**Optional practice (learning only):**
1. Practice drawing more ASTs by hand
2. Sketch a basic expression AST + recursive-descent parser (any language)
3. Optionally extend the toy AST — still outside the production path

**For product work:** implement IR → Lua per [`ir2lua-guide.md`](./ir2lua-guide.md) and `AGENTS.md`. Do not land a production Rego parser/AST here.
