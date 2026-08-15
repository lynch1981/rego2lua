# Example `02-scan-arrays`

Chapter: [`02-scan-and-arrays.md`](../../02-scan-and-arrays.md)

```bash
opa eval -d policy.rego -i input.json 'data.example.allow' --format pretty
opa eval -d policy.rego -i input.json 'data.example.errors' --format pretty
opa build -t plan -e example/allow -e example/errors policy.rego
```
