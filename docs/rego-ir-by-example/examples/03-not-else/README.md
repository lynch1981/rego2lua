# Example `03-not-else`

Chapter: [`03-not-and-else.md`](../../03-not-and-else.md)

```bash
opa eval -d policy.rego -i input.json 'data.example.allow' --format pretty
opa eval -d policy.rego -i input.json 'data.example.role' --format pretty
opa build -t plan -e example/allow -e example/role policy.rego
```
