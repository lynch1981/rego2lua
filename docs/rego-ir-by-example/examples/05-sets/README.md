# Example `05-sets`

Chapter: [`05-sets.md`](../../05-sets.md)

```bash
opa eval -d policy.rego -i input.json 'data.example.deny' --format pretty
opa build -t plan -e example/deny policy.rego
```
