-- Run: luajit t/test_simple_allow.lua

local allow2 = assert(loadfile("t/simple-allow2.lua"))()
local allow1 = assert(loadfile("t/simple-allow.lua"))()

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

check("allow2 GET", allow2.allow({ method = "GET" }), true)
check("allow2 POST", allow2.allow({ method = "POST" }), false)
check("allow2 empty", allow2.allow({}), false)
check("allow2 nil input", allow2.allow(nil), false)
check("allow2 eval shape", allow2.eval({ method = "GET" }).allow, true)

check("allow1 GET", allow1.allow({ method = "GET" }), true)
check("allow1 POST", allow1.allow({ method = "POST" }), false)
check("allow1 empty", allow1.allow({}), false)
check("allow1 nil input", allow1.allow(nil), false)
check("allow1 eval shape", allow1.eval({ method = "GET" }).allow, true)

if failures > 0 then
  os.exit(1)
end
print("all passed")
