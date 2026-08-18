
-- Copyright (c) 2026, Lei Meng <lynch.meng@hotmail.com>

-- numbers.lua — Layer 5: arithmetic & number builtins (priv only)
--
-- Non-numbers / div-by-zero / bad rem → UNDEF (no exceptions).
-- Codegen: local def, v = rt.call_builtin("plus", a, b)

return function(rt, priv)
  local NULL = priv.NULL

  local function is_integer(n)
    return type(n) == "number" and n == n and n == math.floor(n)
  end

  local function require_numbers(a, b)
    if rawequal(a, rt.UNDEF) or rawequal(b, rt.UNDEF) then
      return false
    end
    return type(a) == "number" and type(b) == "number"
  end

  function priv.plus(a, b)
    if not require_numbers(a, b) then return rt.UNDEF end
    return a + b
  end

  function priv.minus(a, b)
    if not require_numbers(a, b) then return rt.UNDEF end
    return a - b
  end

  function priv.mul(a, b)
    if not require_numbers(a, b) then return rt.UNDEF end
    return a * b
  end

  function priv.div(a, b)
    if not require_numbers(a, b) then return rt.UNDEF end
    if b == 0 then return rt.UNDEF end
    return a / b
  end

  function priv.rem(a, b)
    if not require_numbers(a, b) then return rt.UNDEF end
    if b == 0 then return rt.UNDEF end
    if not is_integer(a) or not is_integer(b) then return rt.UNDEF end
    return math.fmod(a, b)
  end

  function priv.abs(x)
    if rawequal(x, rt.UNDEF) then return rt.UNDEF end
    if type(x) ~= "number" then return rt.UNDEF end
    if x < 0 then return -x end
    return x
  end

  -- JSON-number grammar for to_number on strings:
  --   -?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?
  local function parse_json_number(s)
    if type(s) ~= "string" then
      return nil
    end
    local i = 1
    local len = #s
    if len == 0 then return nil end
    if s:sub(i, i) == "-" then
      i = i + 1
      if i > len then return nil end
    end
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
    if i <= len and s:sub(i, i) == "." then
      i = i + 1
      if i > len or not s:sub(i, i):match("%d") then
        return nil
      end
      while i <= len and s:sub(i, i):match("%d") do
        i = i + 1
      end
    end
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

  function priv.to_number(x)
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

  function priv.numbers_range(a, b)
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
end
