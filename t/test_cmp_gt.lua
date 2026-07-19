-- >
-- Run: luajit t/test_cmp_gt.lua

local m = assert(loadfile("t/cmp_gt.lua"))()
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

local cases = {
  { name = "greater",       input = { a = 5, b = 2 },     want = true },
  { name = "equal",         input = { a = 3, b = 3 },     want = false },
  { name = "less",          input = { a = 1, b = 4 },     want = false },
  { name = "negative zero", input = { a = -1, b = 0 },    want = false },
  { name = "strings",       input = { a = "b", b = "a" }, want = false },
  { name = "missing a",     input = { b = 1 },            want = false },
  { name = "nil input",     input = nil,                  want = false },
}

for i = 1, #cases do
  local c = cases[i]
  check(c.name, m.gt(c.input), c.want)
end

if failures > 0 then os.exit(1) end
print("all passed")
