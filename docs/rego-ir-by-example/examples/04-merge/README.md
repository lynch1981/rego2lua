# Example `04-merge`

Chapter: [`04-merge-base-virtual.md`](../../04-merge-base-virtual.md)

```bash
opa eval -d policy.rego -d data.json 'data.example.config' --format pretty
opa build -t plan -e example/config policy.rego data.json
```
