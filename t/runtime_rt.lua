-- Unit tests for runtime/rego_rt.lua (invoked by t/runtime.t).
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

------------------------------------------------------------
-- UNDEF / null / dot (foundation)
------------------------------------------------------------

check("UNDEF is a table", type(rt.UNDEF) == "table")
check("is_undef(UNDEF)", rt.is_undef(rt.UNDEF))
check("not is_def(UNDEF)", not rt.is_def(rt.UNDEF))
check("is_def(false)", rt.is_def(false))
check("is_def(0)", rt.is_def(0))
check("is_def(\"\")", rt.is_def(""))
check("not is_undef(nil)", not rt.is_undef(nil))
check("is_def(NULL)", rt.is_def(rt.NULL))
check("is_null(NULL)", rt.is_null(rt.NULL) == true)
check("not is_null(0)", rt.is_null(0) == false)
check("not is_null(false)", rt.is_null(false) == false)

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
-- equal / neq (scalars + deep)
------------------------------------------------------------

check("equal numbers", rt.equal(1, 1) == true)
check("equal 1 and 1.0", rt.equal(1, 1.0) == true)
check("neq numbers", rt.equal(1, 2) == false)
check("equal strings", rt.equal("a", "a") == true)
check("neq string/number", rt.equal(1, "1") == false)
check("equal nulls", rt.equal(rt.NULL, rt.NULL) == true)
check("null != false", rt.equal(rt.NULL, false) == false)
check("equal bools", rt.equal(true, true) == true)
check("equal arrays", rt.equal({1, 2}, {1, 2}) == true)
check("neq arrays", rt.equal({1}, {1, 2}) == false)
check("equal nested arrays", rt.equal({1, {2}}, {1, {2}}) == true)
check("equal objects", rt.equal({a = 1, b = 2}, {b = 2, a = 1}) == true)
check("neq objects", rt.equal({a = 1}, {a = 1, b = 2}) == false)
check("equal UNDEF arg", is_undef(rt.equal(rt.UNDEF, 1)))
check("neq builtin", rt.neq(1, 2) == true)
check("neq equal", rt.neq(1, 1) == false)
check("builtins.equal", rt.builtins.equal(10, 10) == true)
check("builtins.neq", rt.builtins.neq("a", "b") == true)

------------------------------------------------------------
-- ordering gt/gte/lt/lte
------------------------------------------------------------

check("lt numbers", rt.lt(1, 2) == true)
check("lte equal", rt.lte(2, 2) == true)
check("gt numbers", rt.gt(3, 1) == true)
check("gte equal", rt.gte(3, 3) == true)
check("lt false", rt.lt(5, 1) == false)
check("string lt", rt.lt("a", "b") == true)
check("string gt lex", rt.gt("10", "2") == false)  -- "1" < "2"
check("bool order false < true", rt.lt(false, true) == true)
check("null < false", rt.lt(rt.NULL, false) == true)
check("true < 0 (type rank)", rt.lt(true, 0) == true)
check("number < string", rt.lt(999, "") == true)
check("array lex", rt.lt({1, 2}, {1, 3}) == true)
check("object key order", rt.lt({a = 1}, {b = 1}) == true)
check("cross-type 1 > \"x\"", rt.gt(1, "x") == false)
check("gt UNDEF", is_undef(rt.gt(rt.UNDEF, 1)))
check("builtins.gt", rt.builtins.gt(5, 2) == true)
check("builtins.lte", rt.builtins.lte(2, 2) == true)

------------------------------------------------------------
-- types
------------------------------------------------------------

check("is_string", rt.is_string("hi") == true)
check("not is_string number", rt.is_string(1) == false)
check("is_number", rt.is_number(3.5) == true)
check("is_boolean", rt.is_boolean(false) == true)
check("is_array dense", rt.is_array({10, 20}) == true)
check("is_object map", rt.is_object({a = 1}) == true)
check("empty untagged is object", rt.is_object({}) == true)
check("empty untagged not array", rt.is_array({}) == false)
check("make_array is_array", rt.is_array(rt.make_array()) == true)
check("make_object is_object", rt.is_object(rt.make_object()) == true)
check("make_array not object", rt.is_object(rt.make_array()) == false)
check("type_name number", rt.type_name(1) == "number")
check("type_name string", rt.type_name("a") == "string")
check("type_name boolean", rt.type_name(true) == "boolean")
check("type_name null", rt.type_name(rt.NULL) == "null")
check("type_name array", rt.type_name({1, 2}) == "array")
check("type_name object", rt.type_name({k = 1}) == "object")
check("type_name UNDEF", is_undef(rt.type_name(rt.UNDEF)))
check("builtins.is_array", rt.builtins.is_array({1}) == true)
check("builtins.type_name", rt.builtins.type_name(false) == "boolean")

------------------------------------------------------------
-- to_number
------------------------------------------------------------

check("to_number null", rt.to_number(rt.NULL) == 0)
check("to_number false", rt.to_number(false) == 0)
check("to_number true", rt.to_number(true) == 1)
check("to_number number", rt.to_number(3.5) == 3.5)
check("to_number \"42\"", rt.to_number("42") == 42)
check("to_number \"-2.5\"", rt.to_number("-2.5") == -2.5)
check("to_number \"3e2\"", rt.to_number("3e2") == 300)
check("to_number \"3E+2\"", rt.to_number("3E+2") == 300)
check("to_number \"1e-2\"", rt.to_number("1e-2") == 0.01)
check("to_number reject +3", is_undef(rt.to_number("+3")))
check("to_number reject spaces", is_undef(rt.to_number(" 3")))
check("to_number reject 00", is_undef(rt.to_number("00")))
check("to_number reject 3.", is_undef(rt.to_number("3.")))
check("to_number reject .5", is_undef(rt.to_number(".5")))
check("to_number reject hex", is_undef(rt.to_number("0x10")))
check("to_number reject array", is_undef(rt.to_number({})))
check("builtins.to_number", rt.builtins.to_number("10") == 10)

------------------------------------------------------------
-- arithmetic
------------------------------------------------------------

check("plus", rt.plus(1, 2) == 3)
check("minus", rt.minus(10, 3) == 7)
check("mul", rt.mul(3, 4) == 12)
check("div", rt.div(10, 4) == 2.5)
check("div by zero", is_undef(rt.div(1, 0)))
check("plus type err", is_undef(rt.plus("1", 2)))
check("plus null", is_undef(rt.plus(1, rt.NULL)))
check("rem 5%2", rt.rem(5, 2) == 1)
check("rem -5%2 Go-style", rt.rem(-5, 2) == -1)
check("rem 5%-2", rt.rem(5, -2) == 1)
check("rem integer-valued float", rt.rem(4.0, 2.0) == 0)
check("rem non-integer", is_undef(rt.rem(5.5, 2)))
check("abs -3", rt.abs(-3) == 3)
check("abs 3.5", rt.abs(3.5) == 3.5)
check("abs string", is_undef(rt.abs("x")))
check("builtins.plus", rt.builtins.plus(2, 3) == 5)
check("builtins.rem", rt.builtins.rem(7, 4) == 3)
check("builtins.abs", rt.builtins.abs(-9) == 9)

------------------------------------------------------------
-- numbers.range
------------------------------------------------------------

local function arr_eq(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

check("range 1..3", arr_eq(rt.numbers_range(1, 3), {1, 2, 3}))
check("range 3..1", arr_eq(rt.numbers_range(3, 1), {3, 2, 1}))
check("range singleton", arr_eq(rt.numbers_range(1, 1), {1}))
check("range negative", arr_eq(rt.numbers_range(-1, 2), {-1, 0, 1, 2}))
check("range non-int", is_undef(rt.numbers_range(1.5, 3)))
check("range is array", rt.is_array(rt.numbers_range(1, 2)) == true)
check("builtins numbers.range", arr_eq(rt.builtins["numbers.range"](0, 2), {0, 1, 2}))
check("call_builtin numbers.range", arr_eq(rt.call_builtin("numbers.range", 1, 2), {1, 2}))
check("call_builtin unknown", is_undef(rt.call_builtin("nope")))

------------------------------------------------------------
-- values_equal helper (EqualStmt-friendly)
------------------------------------------------------------

check("values_equal true", rt.values_equal({a = 1}, {a = 1}) == true)
check("values_equal false", rt.values_equal(1, 2) == false)
check("values_equal UNDEF is false", rt.values_equal(rt.UNDEF, rt.UNDEF) == false)

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
