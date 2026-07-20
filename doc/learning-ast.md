# Learning Abstract Syntax Trees (AST)

> A detailed study note from learning how to build a source-to-source compiler (Rego → Lua)

---

## 1. Background

The goal is to implement a **source-to-source compiler** (transpiler) that converts a subset of **OPA Rego** into **Lua**.

To build any compiler, the most important intermediate structure is the **Abstract Syntax Tree (AST)**.
This document records the step-by-step learning process of understanding and building ASTs.

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

/**
 * @brief Ensures the current token matches the expected type and consumes it.
 *
 * The next token must be := (type).
 * If it is, consume it and continue.
 * If it is not, then report a syntax error
 */
void expect(TokenType type) {
    if (current() == type) {
        consume();          // move to the next token
    } else {
        error("Expected token, but got something else");
    }
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

## 11. Connection to the Rego → Lua Project

All the knowledge above is preparation for the real project.

Previously we already designed:
- A formal grammar for a practical v0.1 subset of Rego
- A detailed C-style AST for Rego constructs (`Module`, `Package`, `DefaultRule`, `CompleteRule`, `Query`, expressions, references, etc.)

Once comfortable with basic expression ASTs, the next step is to implement the real Rego AST nodes and parser.

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

**Next recommended steps:**
1. Practice drawing more ASTs by hand
2. Implement the basic expression AST + parser in C/C++
3. Return to the Rego AST design and start implementing it
```
