# Example `01-spine-allow`

Chapter: [`01-spine-allow.md`](../../01-spine-allow.md)

```bash
opa eval -d policy.rego -i input.json 'data.example.allow' --format pretty
opa build -t plan -e example/allow policy.rego
```
