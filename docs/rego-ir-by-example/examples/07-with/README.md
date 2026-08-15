# Example `07-with`

Chapter: [`07-with.md`](../../07-with.md)

No `input.json`: the policy sets `input` via `with`.

```bash
opa eval -d policy.rego 'data.example.allow' --format pretty
opa build -t plan -e example/allow policy.rego
```
