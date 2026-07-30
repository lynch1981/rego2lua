# Example `08-multi-allow`

Two `allow if` rules (OR). See [08-block-and-break.md](../../08-block-and-break.md).

```bash
opa eval -d policy.rego -i input.json 'data.example.allow' --format pretty
opa build -t plan -e example/allow policy.rego
```

Contrast with `else` in `03-not-else` (uses `BlockStmt`).
