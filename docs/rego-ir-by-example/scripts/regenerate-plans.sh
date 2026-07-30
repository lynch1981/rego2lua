#!/usr/bin/env bash
# Regenerate plan.json for each example (requires opa on PATH).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EX="$ROOT/examples"

extract_plan() {
  local tar=$1 out=$2
  python3 - "$tar" "$out" <<'PY'
import tarfile, tempfile, json, os, sys
tar_path, out_path = sys.argv[1], sys.argv[2]
td = tempfile.mkdtemp()
with tarfile.open(tar_path) as t:
    for m in t.getmembers():
        m.name = m.name.lstrip("/")
        t.extract(m, td)
for root, _, fs in os.walk(td):
    if "plan.json" in fs:
        data = json.load(open(os.path.join(root, "plan.json")))
        with open(out_path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        print("wrote", out_path)
        break
else:
    raise SystemExit("plan.json not found in " + tar_path)
PY
}

build() {
  local dir=$1; shift
  local tar="$dir/bundle.tar.gz"
  echo "==> $dir"
  opa build -t plan "$@" -o "$tar"
  extract_plan "$tar" "$dir/plan.json"
}

build "$EX/01-spine-allow" -e example/allow "$EX/01-spine-allow/policy.rego"
build "$EX/02-scan-arrays" -e example/allow -e example/errors "$EX/02-scan-arrays/policy.rego"
build "$EX/03-not-else" -e example/allow -e example/role "$EX/03-not-else/policy.rego"
build "$EX/04-merge" -e example/config "$EX/04-merge/policy.rego" "$EX/04-merge/data.json"
build "$EX/05-sets" -e example/deny "$EX/05-sets/policy.rego"
build "$EX/06-len-unify" -e example/allow "$EX/06-len-unify/policy.rego"
build "$EX/07-with" -e example/allow "$EX/07-with/policy.rego"
build "$EX/08-multi-allow" -e example/allow "$EX/08-multi-allow/policy.rego"

echo "Done."
