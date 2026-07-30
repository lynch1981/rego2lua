# Example `01-spine-allow`

See the chapter in [`../../`](../../) matching this folder.

```bash
# eval (adjust -i / -d as needed)
opa eval -d policy.rego -i input.json 'data.example.allow' --format pretty 2>/dev/null || true

# plan already generated as plan.json; rebuild with:
# opa build -t plan -e <entrypoint> policy.rego [-d data.json]
```
