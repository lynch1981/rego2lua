-- Run every suite listed below.
-- Usage: luajit t/run_all.lua

local tests = {
  "t/test_simple_allow.lua",
  "t/test_cmp_eq.lua",
  "t/test_cmp_ne.lua",
  "t/test_cmp_gt.lua",
  "t/test_cmp_gte.lua",
  "t/test_cmp_lt.lua",
  "t/test_cmp_lte.lua",
}

local function execute_ok(cmd)
  local r = os.execute(cmd)
  -- Lua 5.1: exit status number (0 = success)
  -- LuaJIT / 5.2+: boolean true on success
  if type(r) == "boolean" then
    return r
  end
  if type(r) == "number" then
    return r == 0
  end
  return false
end

local failed = 0

for i = 1, #tests do
  local path = tests[i]
  io.stdout:write("==== " .. path .. " ====\n")
  io.stdout:flush()
  if not execute_ok("luajit " .. path) then
    failed = failed + 1
  end
  io.stdout:write("\n")
  io.stdout:flush()
end

if failed > 0 then
  io.stderr:write(string.format("%d suite(s) failed\n", failed))
  os.exit(1)
end
print("all suites passed")
