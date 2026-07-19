-- !=
-- Run: luajit t/test_cmp_ne.lua

local m = assert(loadfile("t/cmp_ne.lua"))()
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
  { name = "numbers equal",   input = { a = 3, b = 3 },         want = false },
  { name = "numbers unequal", input = { a = 5, b = 2 },         want = true },
  { name = "strings equal",   input = { a = "GET", b = "GET" }, want = false },
  { name = "strings unequal", input = { a = "GET", b = "POST" }, want = true },
  { name = "missing a",       input = { b = 1 },                want = false },
  { name = "missing both",    input = {},                       want = false },
  { name = "nil input",       input = nil,                      want = false },
}

for i = 1, #cases do
  local c = cases[i]
  check(c.name, m.ne(c.input), c.want)
end

if failures > 0 then os.exit(1) end
print("all passed")
