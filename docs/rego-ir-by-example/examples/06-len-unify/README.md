# Example `06-len-unify`

Chapter: [`06-len-unify.md`](../../06-len-unify.md)

```bash
opa eval -d policy.rego -i input.json 'data.example.allow' --format pretty
opa build -t plan -e example/allow policy.rego
```
