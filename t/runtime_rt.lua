-- Unit tests for runtime/ (invoked by t/runtime.t).
-- Loads facade runtime/rego_rt.lua only; layers load underneath.
-- Public API: kernel + call_builtin. Named builtins via call_builtin only.
-- Slice 1.1.1: UNDEF, dot, compare, types, numbers.

local script_dir = (arg[0] and arg[0]:match("(.*/)") ) or "./"
local rt = assert(loadfile(script_dir .. "../runtime/rego_rt.lua"))()

local tests = {}
local function check(name, cond)
  tests[#tests + 1] = { name = name, ok = not not cond }
end

local function is_undef(x)
  return rt.is_undef(x)
end

-- CallStmt path: unwrap (defined, value). Undefined → UNDEF for is_undef checks.
local function b(name, ...)
  local def, v = rt.call_builtin(name, ...)
  if not def then
    return rt.UNDEF
  end
  return v
end

------------------------------------------------------------
-- Kernel: UNDEF / null / dot
------------------------------------------------------------

check("UNDEF is a table", type(rt.UNDEF) == "table")
check("is_undef(UNDEF)", rt.is_undef(rt.UNDEF))
check("not is_def(UNDEF)", not rt.is_def(rt.UNDEF))
check("is_def(false)", rt.is_def(false))
check("is_def(0)", rt.is_def(0))
check("is_def(\"\")", rt.is_def(""))
check("not is_undef(nil)", not rt.is_undef(nil))
check("is_def(NULL)", rt.is_def(rt.NULL))
check("is_null via builtin", b("is_null", rt.NULL) == true)
check("not is_null(0)", b("is_null", 0) == false)
check("not is_null(false)", b("is_null", false) == false)

local input = { method = "GET", user = { name = "alice" } }
check("dot field hit", rt.dot(input, "method") == "GET")
check("dot nested", rt.dot(rt.dot(input, "user"), "name") == "alice")
check("dot missing key", is_undef(rt.dot(input, "nope")))
check("dot on UNDEF", is_undef(rt.dot(rt.UNDEF, "x")))
check("dot on number", is_undef(rt.dot(42, "x")))
check("dot chain through miss", is_undef(rt.dot(rt.dot(input, "nope"), "name")))

local obj_null = { x = rt.NULL }
check("dot returns NULL as defined", rawequal(rt.dot(obj_null, "x"), rt.NULL))

------------------------------------------------------------
-- equal / neq via call_builtin
------------------------------------------------------------

check("equal numbers", b("equal", 1, 1) == true)
check("equal 1 and 1.0", b("equal", 1, 1.0) == true)
check("neq numbers", b("equal", 1, 2) == false)
check("equal strings", b("equal", "a", "a") == true)
check("neq string/number", b("equal", 1, "1") == false)
check("equal nulls", b("equal", rt.NULL, rt.NULL) == true)
check("null != false", b("equal", rt.NULL, false) == false)
check("equal bools", b("equal", true, true) == true)
check("equal arrays", b("equal", {1, 2}, {1, 2}) == true)
check("neq arrays", b("equal", {1}, {1, 2}) == false)
check("equal nested arrays", b("equal", {1, {2}}, {1, {2}}) == true)
check("equal objects", b("equal", {a = 1, b = 2}, {b = 2, a = 1}) == true)
check("neq objects", b("equal", {a = 1}, {a = 1, b = 2}) == false)
check("equal UNDEF arg", is_undef(b("equal", rt.UNDEF, 1)))
check("neq builtin", b("neq", 1, 2) == true)
check("neq equal", b("neq", 1, 1) == false)
check("builtins.equal table", rt.builtins.equal(10, 10) == true)
check("builtins.neq table", rt.builtins.neq("a", "b") == true)

------------------------------------------------------------
-- ordering via call_builtin
------------------------------------------------------------

check("lt numbers", b("lt", 1, 2) == true)
check("lte equal", b("lte", 2, 2) == true)
check("gt numbers", b("gt", 3, 1) == true)
check("gte equal", b("gte", 3, 3) == true)
check("lt false", b("lt", 5, 1) == false)
check("string lt", b("lt", "a", "b") == true)
check("string gt lex", b("gt", "10", "2") == false)
check("bool order false < true", b("lt", false, true) == true)
check("null < false", b("lt", rt.NULL, false) == true)
check("true < 0 (type rank)", b("lt", true, 0) == true)
check("number < string", b("lt", 999, "") == true)
check("array lex", b("lt", {1, 2}, {1, 3}) == true)
check("object key order", b("lt", {a = 1}, {b = 1}) == true)
check("cross-type 1 > \"x\"", b("gt", 1, "x") == false)
check("gt UNDEF", is_undef(b("gt", rt.UNDEF, 1)))
check("builtins.gt", rt.builtins.gt(5, 2) == true)
check("builtins.lte", rt.builtins.lte(2, 2) == true)

------------------------------------------------------------
-- types via call_builtin; make_* is kernel
------------------------------------------------------------

check("is_string", b("is_string", "hi") == true)
check("not is_string number", b("is_string", 1) == false)
check("is_number", b("is_number", 3.5) == true)
check("is_boolean", b("is_boolean", false) == true)
check("is_array dense", b("is_array", {10, 20}) == true)
check("is_object map", b("is_object", {a = 1}) == true)
check("empty untagged is object", b("is_object", {}) == true)
check("empty untagged not array", b("is_array", {}) == false)
check("make_array is_array", b("is_array", rt.make_array()) == true)
check("make_object is_object", b("is_object", rt.make_object()) == true)
check("make_array not object", b("is_object", rt.make_array()) == false)
check("type_name number", b("type_name", 1) == "number")
check("type_name string", b("type_name", "a") == "string")
check("type_name boolean", b("type_name", true) == "boolean")
check("type_name null", b("type_name", rt.NULL) == "null")
check("type_name array", b("type_name", {1, 2}) == "array")
check("type_name object", b("type_name", {k = 1}) == "object")
check("type_name UNDEF", is_undef(b("type_name", rt.UNDEF)))
check("builtins.is_array", rt.builtins.is_array({1}) == true)
check("builtins.type_name", rt.builtins.type_name(false) == "boolean")

------------------------------------------------------------
-- to_number via call_builtin
------------------------------------------------------------

check("to_number null", b("to_number", rt.NULL) == 0)
check("to_number false", b("to_number", false) == 0)
check("to_number true", b("to_number", true) == 1)
check("to_number number", b("to_number", 3.5) == 3.5)
check("to_number \"42\"", b("to_number", "42") == 42)
check("to_number \"-2.5\"", b("to_number", "-2.5") == -2.5)
check("to_number \"3e2\"", b("to_number", "3e2") == 300)
check("to_number \"3E+2\"", b("to_number", "3E+2") == 300)
check("to_number \"1e-2\"", b("to_number", "1e-2") == 0.01)
check("to_number reject +3", is_undef(b("to_number", "+3")))
check("to_number reject spaces", is_undef(b("to_number", " 3")))
check("to_number reject 00", is_undef(b("to_number", "00")))
check("to_number reject 3.", is_undef(b("to_number", "3.")))
check("to_number reject .5", is_undef(b("to_number", ".5")))
check("to_number reject hex", is_undef(b("to_number", "0x10")))
check("to_number reject array", is_undef(b("to_number", {})))
check("builtins.to_number", rt.builtins.to_number("10") == 10)

------------------------------------------------------------
-- arithmetic via call_builtin
------------------------------------------------------------

check("plus", b("plus", 1, 2) == 3)
check("minus", b("minus", 10, 3) == 7)
check("mul", b("mul", 3, 4) == 12)
check("div", b("div", 10, 4) == 2.5)
check("div by zero", is_undef(b("div", 1, 0)))
check("plus type err", is_undef(b("plus", "1", 2)))
check("plus null", is_undef(b("plus", 1, rt.NULL)))
check("rem 5%2", b("rem", 5, 2) == 1)
check("rem -5%2 Go-style", b("rem", -5, 2) == -1)
check("rem 5%-2", b("rem", 5, -2) == 1)
check("rem integer-valued float", b("rem", 4.0, 2.0) == 0)
check("rem non-integer", is_undef(b("rem", 5.5, 2)))
check("abs -3", b("abs", -3) == 3)
check("abs 3.5", b("abs", 3.5) == 3.5)
check("abs string", is_undef(b("abs", "x")))
check("builtins.plus", rt.builtins.plus(2, 3) == 5)
check("builtins.rem", rt.builtins.rem(7, 4) == 3)
check("builtins.abs", rt.builtins.abs(-9) == 9)

------------------------------------------------------------
-- numbers.range via call_builtin
------------------------------------------------------------

local function arr_eq(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

check("range 1..3", arr_eq(b("numbers.range", 1, 3), {1, 2, 3}))
check("range 3..1", arr_eq(b("numbers.range", 3, 1), {3, 2, 1}))
check("range singleton", arr_eq(b("numbers.range", 1, 1), {1}))
check("range negative", arr_eq(b("numbers.range", -1, 2), {-1, 0, 1, 2}))
check("range non-int", is_undef(b("numbers.range", 1.5, 3)))
check("range is array", b("is_array", b("numbers.range", 1, 2)) == true)
check("builtins numbers.range", arr_eq(rt.builtins["numbers.range"](0, 2), {0, 1, 2}))
do
  local def, v = rt.call_builtin("nope")
  check("call_builtin unknown def", def == false)
  check("call_builtin unknown val", v == nil)
end
do
  local def, v = rt.call_builtin("plus", 2, 3)
  check("call_builtin plus def", def == true)
  check("call_builtin plus val", v == 5)
end
do
  local def, ok = rt.call_builtin("equal", 1, 2)
  check("call_builtin equal miss def", def == true)
  check("call_builtin equal miss ok", ok == false)
end
do
  local def, ok = rt.call_builtin("equal", rt.UNDEF, 1)
  check("call_builtin equal UNDEF def", def == false)
  check("call_builtin equal UNDEF val", ok == nil)
end

------------------------------------------------------------
-- Kernel: values_equal (EqualStmt)
------------------------------------------------------------

check("values_equal true", rt.values_equal({a = 1}, {a = 1}) == true)
check("values_equal false", rt.values_equal(1, 2) == false)
check("values_equal UNDEF is false", rt.values_equal(rt.UNDEF, rt.UNDEF) == false)
check("values_equal one UNDEF", rt.values_equal(rt.UNDEF, 1) == false)

------------------------------------------------------------
-- is_ok: CallStmt 3-value → Lua condition (UNDEF is truthy; do not use raw if)
------------------------------------------------------------

check("is_ok true", rt.is_ok(true) == true)
check("is_ok false", rt.is_ok(false) == false)
check("is_ok UNDEF", rt.is_ok(rt.UNDEF) == false)
check("is_ok 0", rt.is_ok(0) == false)
check("is_ok raw equal hit", rt.is_ok(rt.builtins.equal(1, 1)) == true)
check("is_ok raw equal miss", rt.is_ok(rt.builtins.equal(1, 2)) == false)
check("is_ok raw equal UNDEF", rt.is_ok(rt.builtins.equal(rt.UNDEF, 1)) == false)
check("raw UNDEF is truthy (why is_ok exists)", not not rt.UNDEF == true)

------------------------------------------------------------
-- Public surface: no free-floating builtin names on rt
------------------------------------------------------------

check("no rt.equal", rt.equal == nil)
check("no rt.plus", rt.plus == nil)
check("no rt.is_string", rt.is_string == nil)
check("no rt.to_number", rt.to_number == nil)
check("no rt.lt", rt.lt == nil)

-- TAP for prove / t/runtime.t
io.write("1.." .. #tests .. "\n")
local failed = 0
for i = 1, #tests do
  local t = tests[i]
  if t.ok then
    io.write("ok " .. i .. " - " .. t.name .. "\n")
  else
    io.write("not ok " .. i .. " - " .. t.name .. "\n")
    failed = failed + 1
  end
end

if failed > 0 then
  os.exit(1)
end
