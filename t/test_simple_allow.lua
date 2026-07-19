-- First-step behavioral tests for hand-translated policies.
-- Run from repo root: luajit t/test_simple_allow.lua

local failures = 0

local function check(name, got, want)
  if got ~= want then
    io.stderr:write(string.format("FAIL %s: got %s, want %s\n",
      name, tostring(got), tostring(want)))
    failures = failures + 1
  else
    print(string.format("ok   %s", name))
  end
end

print(string.format("interpreter: %s", _VERSION))
if type(jit) == "table" and jit.version then
  print(string.format("jit: %s", jit.version))
end

local policies = {
  {
    name = "simple-allow",
    mod = assert(loadfile("t/simple-allow.lua"))(),
  },
  {
    name = "simple-allow2",
    mod = assert(loadfile("t/simple-allow2.lua"))(),
  },
}

local inputs = {
  { label = "GET",   input = { method = "GET" },  want = true },
  { label = "POST",  input = { method = "POST" }, want = false },
  { label = "empty", input = {},                  want = false },
  { label = "nil",   input = nil,                 want = false },
}

for i = 1, #policies do
  local p = policies[i]
  for j = 1, #inputs do
    local c = inputs[j]
    check(p.name .. " " .. c.label, p.mod.allow(c.input), c.want)
  end
end

if failures > 0 then
  os.exit(1)
end
print("all passed")
