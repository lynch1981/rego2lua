-- rego_rt.lua — Rego runtime helpers for IR → Lua (LuaJIT 2.1 / OpenResty).
--
-- Slice 1.1.1: undefined, DotStmt, compare, types, numbers.
-- See docs/rego-builtins-runtime.md

local rt = {}

------------------------------------------------------------
-- Undefined & null
------------------------------------------------------------

-- Unique table identity. Never put fields on this table.
--   undefined  ≠  JSON null  ≠  Lua nil
rt.UNDEF = {}

local NULL
do
  local ok, cjson = pcall(require, "cjson.safe")
  if ok and cjson and cjson.null ~= nil then
    NULL = cjson.null
  else
    -- Fallback when cjson is absent; still distinct from UNDEF / nil.
    NULL = {}
  end
end
rt.NULL = NULL

function rt.is_undef(x)
  return rawequal(x, rt.UNDEF)
end

function rt.is_def(x)
  return not rawequal(x, rt.UNDEF)
end

------------------------------------------------------------
-- Composite tags (MakeArray / MakeObject / future sets)
------------------------------------------------------------

local MT_ARRAY  = { __rego_kind = "array" }
local MT_OBJECT = { __rego_kind = "object" }
local MT_SET    = { __rego_kind = "set" }

function rt.make_array(_capacity)
  return setmetatable({}, MT_ARRAY)
end

function rt.make_object()
  return setmetatable({}, MT_OBJECT)
end

function rt.make_set()
  -- Set representation (1.1.4): keys are elements, value = true.
  return setmetatable({}, MT_SET)
end

local function tagged_kind(t)
  local mt = getmetatable(t)
  if mt then
    return mt.__rego_kind
  end
  return nil
end

-- Classify a Lua table as array | object | set.
-- Untagged empty tables count as object (JSON {} / cjson default).
local function table_kind(t)
  local kind = tagged_kind(t)
  if kind then
    return kind
  end
  local maxn, count = 0, 0
  local has_non_array_key = false
  for k, _ in pairs(t) do
    count = count + 1
    if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
      has_non_array_key = true
    elseif k > maxn then
      maxn = k
    end
  end
  if count == 0 then
    return "object"
  end
  if has_non_array_key then
    return "object"
  end
  if maxn == count then
    return "array"
  end
  return "object"
end

------------------------------------------------------------
-- DotStmt
------------------------------------------------------------

function rt.dot(source, key)
  if rawequal(source, rt.UNDEF) then
    return rt.UNDEF
  end
  if type(source) ~= "table" then
    return rt.UNDEF
  end
  local v = source[key]
  if v == nil then
    return rt.UNDEF
  end
  return v
end

------------------------------------------------------------
-- Type predicates & type_name
------------------------------------------------------------

-- Order used by OPA value comparison (lower first).
local TYPE_RANK = {
  null    = 1,
  boolean = 2,
  number  = 3,
  string  = 4,
  array   = 5,
  object  = 6,
  set     = 7,
}

local function value_type(x)
  if rawequal(x, rt.UNDEF) then
    return "undefined"
  end
  if rawequal(x, NULL) then
    return "null"
  end
  local t = type(x)
  if t == "boolean" or t == "number" or t == "string" then
    return t
  end
  if t == "table" then
    return table_kind(x)
  end
  -- light userdata etc. — treat unknown as null-like only if it is cjson.null
  return t
end

function rt.type_name(x)
  if rawequal(x, rt.UNDEF) then
    return rt.UNDEF
  end
  local vt = value_type(x)
  if vt == "undefined" then
    return rt.UNDEF
  end
  return vt
end

function rt.is_null(x)
  if rawequal(x, rt.UNDEF) then return rt.UNDEF end
  return rawequal(x, NULL)
end

function rt.is_boolean(x)
  if rawequal(x, rt.UNDEF) then return rt.UNDEF end
  return type(x) == "boolean"
end

function rt.is_number(x)
  if rawequal(x, rt.UNDEF) then return rt.UNDEF end
  return type(x) == "number"
end

function rt.is_string(x)
  if rawequal(x, rt.UNDEF) then return rt.UNDEF end
  return type(x) == "string"
end

function rt.is_array(x)
  if rawequal(x, rt.UNDEF) then return rt.UNDEF end
  return type(x) == "table" and table_kind(x) == "array"
end

function rt.is_object(x)
  if rawequal(x, rt.UNDEF) then return rt.UNDEF end
  return type(x) == "table" and table_kind(x) == "object"
end

function rt.is_set(x)
  if rawequal(x, rt.UNDEF) then return rt.UNDEF end
  return type(x) == "table" and table_kind(x) == "set"
end

------------------------------------------------------------
-- Deep equality & ordering (OPA-style)
------------------------------------------------------------

local compare_values

local function sorted_keys(t)
  local keys = {}
  for k, _ in pairs(t) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    local ca = compare_values(a, b)
    return ca < 0
  end)
  return keys
end

local function set_elements(t)
  -- set: keys are members (value ignored)
  local elems = {}
  for k, _ in pairs(t) do
    elems[#elems + 1] = k
  end
  table.sort(elems, function(a, b)
    return compare_values(a, b) < 0
  end)
  return elems
end

compare_values = function(a, b)
  if rawequal(a, b) then
    return 0
  end
  -- Both null?
  if rawequal(a, NULL) and rawequal(b, NULL) then
    return 0
  end

  local ta, tb = value_type(a), value_type(b)
  if ta == "undefined" or tb == "undefined" then
    -- callers should not order UNDEF; treat as non-equal incomparable
    if ta == tb then return 0 end
    return (ta < tb) and -1 or 1
  end

  if ta ~= tb then
    local ra, rb = TYPE_RANK[ta], TYPE_RANK[tb]
    if ra and rb then
      if ra < rb then return -1 end
      if ra > rb then return 1 end
    end
    if ta < tb then return -1 end
    if ta > tb then return 1 end
    return 0
  end

  if ta == "null" then
    return 0
  end
  if ta == "boolean" then
    -- false < true
    if a == b then return 0 end
    return (a == false) and -1 or 1
  end
  if ta == "number" then
    if a < b then return -1 end
    if a > b then return 1 end
    return 0
  end
  if ta == "string" then
    if a < b then return -1 end
    if a > b then return 1 end
    return 0
  end
  if ta == "array" then
    local na, nb = #a, #b
    local n = (na < nb) and na or nb
    for i = 1, n do
      local c = compare_values(a[i], b[i])
      if c ~= 0 then return c end
    end
    if na < nb then return -1 end
    if na > nb then return 1 end
    return 0
  end
  if ta == "object" then
    local ka, kb = sorted_keys(a), sorted_keys(b)
    local na, nb = #ka, #kb
    local n = (na < nb) and na or nb
    for i = 1, n do
      local c = compare_values(ka[i], kb[i])
      if c ~= 0 then return c end
      c = compare_values(a[ka[i]], b[kb[i]])
      if c ~= 0 then return c end
    end
    if na < nb then return -1 end
    if na > nb then return 1 end
    return 0
  end
  if ta == "set" then
    local ea, eb = set_elements(a), set_elements(b)
    local na, nb = #ea, #eb
    local n = (na < nb) and na or nb
    for i = 1, n do
      local c = compare_values(ea[i], eb[i])
      if c ~= 0 then return c end
    end
    if na < nb then return -1 end
    if na > nb then return 1 end
    return 0
  end

  -- fallback: tostring
  local sa, sb = tostring(a), tostring(b)
  if sa < sb then return -1 end
  if sa > sb then return 1 end
  return 0
end

rt.compare = compare_values

--- Deep equality for defined values. Does not accept UNDEF (returns false).
function rt.values_equal(a, b)
  if rawequal(a, rt.UNDEF) or rawequal(b, rt.UNDEF) then
    return false
  end
  return compare_values(a, b) == 0
end

--- Builtin-style equal: UNDEF if either operand is UNDEF, else boolean.
function rt.equal(a, b)
  if rawequal(a, rt.UNDEF) or rawequal(b, rt.UNDEF) then
    return rt.UNDEF
  end
  return compare_values(a, b) == 0
end

function rt.neq(a, b)
  if rawequal(a, rt.UNDEF) or rawequal(b, rt.UNDEF) then
    return rt.UNDEF
  end
  return compare_values(a, b) ~= 0
end

local function ord_builtin(cmp_want)
  return function(a, b)
    if rawequal(a, rt.UNDEF) or rawequal(b, rt.UNDEF) then
      return rt.UNDEF
    end
    local c = compare_values(a, b)
    if cmp_want == "lt"  then return c < 0 end
    if cmp_want == "lte" then return c <= 0 end
    if cmp_want == "gt"  then return c > 0 end
    if cmp_want == "gte" then return c >= 0 end
    return false
  end
end

rt.lt  = ord_builtin("lt")
rt.lte = ord_builtin("lte")
rt.gt  = ord_builtin("gt")
rt.gte = ord_builtin("gte")

-- Short aliases used by ir2lua-guide sketches
rt.eq  = rt.equal

------------------------------------------------------------
-- Numbers
------------------------------------------------------------

local function is_integer(n)
  return type(n) == "number" and n == math.floor(n) and n == n -- not NaN
end

local function require_numbers(a, b)
  if rawequal(a, rt.UNDEF) or rawequal(b, rt.UNDEF) then
    return false
  end
  return type(a) == "number" and type(b) == "number"
end

function rt.plus(a, b)
  if not require_numbers(a, b) then return rt.UNDEF end
  return a + b
end

function rt.minus(a, b)
  if not require_numbers(a, b) then return rt.UNDEF end
  return a - b
end

function rt.mul(a, b)
  if not require_numbers(a, b) then return rt.UNDEF end
  return a * b
end

function rt.div(a, b)
  if not require_numbers(a, b) then return rt.UNDEF end
  if b == 0 then return rt.UNDEF end
  return a / b
end

function rt.rem(a, b)
  if not require_numbers(a, b) then return rt.UNDEF end
  if b == 0 then return rt.UNDEF end
  if not is_integer(a) or not is_integer(b) then return rt.UNDEF end
  -- Go/OPA remainder (toward zero): math.fmod
  return math.fmod(a, b)
end

function rt.abs(x)
  if rawequal(x, rt.UNDEF) then return rt.UNDEF end
  if type(x) ~= "number" then return rt.UNDEF end
  if x < 0 then return -x end
  return x
end

-- JSON-number grammar (OPA to_number on strings):
--   -?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?
local function parse_json_number(s)
  if type(s) ~= "string" then
    return nil
  end
  -- Full pattern without Lua's limited regex: use multi-step.
  local i = 1
  local len = #s
  if len == 0 then return nil end
  if s:sub(i, i) == "-" then
    i = i + 1
    if i > len then return nil end
  end
  -- integer part
  if s:sub(i, i) == "0" then
    i = i + 1
  elseif s:sub(i, i):match("[1-9]") then
    i = i + 1
    while i <= len and s:sub(i, i):match("%d") do
      i = i + 1
    end
  else
    return nil
  end
  -- fraction
  if i <= len and s:sub(i, i) == "." then
    i = i + 1
    if i > len or not s:sub(i, i):match("%d") then
      return nil
    end
    while i <= len and s:sub(i, i):match("%d") do
      i = i + 1
    end
  end
  -- exponent
  if i <= len and (s:sub(i, i) == "e" or s:sub(i, i) == "E") then
    i = i + 1
    if i <= len and (s:sub(i, i) == "+" or s:sub(i, i) == "-") then
      i = i + 1
    end
    if i > len or not s:sub(i, i):match("%d") then
      return nil
    end
    while i <= len and s:sub(i, i):match("%d") do
      i = i + 1
    end
  end
  if i <= len then
    return nil
  end
  return tonumber(s)
end

function rt.to_number(x)
  if rawequal(x, rt.UNDEF) then return rt.UNDEF end
  if rawequal(x, NULL) then return 0 end
  if type(x) == "boolean" then
    return x and 1 or 0
  end
  if type(x) == "number" then
    return x
  end
  if type(x) == "string" then
    local n = parse_json_number(x)
    if n == nil then return rt.UNDEF end
    return n
  end
  return rt.UNDEF
end

function rt.numbers_range(a, b)
  if not require_numbers(a, b) then return rt.UNDEF end
  if not is_integer(a) or not is_integer(b) then return rt.UNDEF end
  local out = rt.make_array()
  if a <= b then
    for i = a, b do
      out[#out + 1] = i
    end
  else
    for i = a, b, -1 do
      out[#out + 1] = i
    end
  end
  return out
end

------------------------------------------------------------
-- Builtin table (CallStmt names as produced by OPA plan IR)
------------------------------------------------------------

rt.builtins = {
  equal   = function(a, b) return rt.equal(a, b) end,
  neq     = function(a, b) return rt.neq(a, b) end,
  gt      = function(a, b) return rt.gt(a, b) end,
  gte     = function(a, b) return rt.gte(a, b) end,
  lt      = function(a, b) return rt.lt(a, b) end,
  lte     = function(a, b) return rt.lte(a, b) end,

  is_string  = function(x) return rt.is_string(x) end,
  is_number  = function(x) return rt.is_number(x) end,
  is_boolean = function(x) return rt.is_boolean(x) end,
  is_null    = function(x) return rt.is_null(x) end,
  is_array   = function(x) return rt.is_array(x) end,
  is_object  = function(x) return rt.is_object(x) end,
  is_set     = function(x) return rt.is_set(x) end,
  type_name  = function(x) return rt.type_name(x) end,

  to_number = function(x) return rt.to_number(x) end,
  plus      = function(a, b) return rt.plus(a, b) end,
  minus     = function(a, b) return rt.minus(a, b) end,
  mul       = function(a, b) return rt.mul(a, b) end,
  div       = function(a, b) return rt.div(a, b) end,
  rem       = function(a, b) return rt.rem(a, b) end,
  abs       = function(x) return rt.abs(x) end,
  ["numbers.range"] = function(a, b) return rt.numbers_range(a, b) end,
}

--- Call a builtin by IR name. Missing name or UNDEF result propagation is
--- the caller's concern; unknown names return UNDEF.
function rt.call_builtin(name, ...)
  local fn = rt.builtins[name]
  if not fn then
    return rt.UNDEF
  end
  return fn(...)
end

return rt
