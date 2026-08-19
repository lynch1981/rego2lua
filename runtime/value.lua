
-- Copyright (c) 2026, Lei Meng

-- value.lua — Layer 1: value model + kernel helpers
--
-- What is a "Rego value" when stored in Lua?
--   undefined  →  rt.UNDEF  (unique table; use rawequal)
--   JSON null  →  rt.NULL   (cjson.null when available)
--   array/object/set → tables, preferably tagged with metatables
--
-- Lua nil is NOT a Rego value (it means "no table entry").

return function(rt, priv)
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
      NULL = {}
    end
  end
  rt.NULL = NULL
  priv.NULL = NULL

  function rt.is_undef(x)
    return rawequal(x, rt.UNDEF)
  end

  function rt.is_def(x)
    return not rawequal(x, rt.UNDEF)
  end

  -- CallStmt boolean → Lua condition.
  -- OPA 3-valued results: true | false | UNDEF.
  -- For a 3-valued *slot* (raw builtin result). CallStmt emit uses
  --   local def, v = rt.call_builtin(...); if def and v then
  -- Only exact true succeeds; false and UNDEF both fail.
  function rt.is_ok(x)
    return x == true
  end

  ------------------------------------------------------------
  -- Composite tags (MakeArray / MakeObject / MakeSet)
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
    return setmetatable({}, MT_SET)
  end

  local function tagged_kind(t)
    local mt = getmetatable(t)
    if mt then
      return mt.__rego_kind
    end
    return nil
  end

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

  priv.table_kind = table_kind

  priv.TYPE_RANK = {
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
    return t
  end

  priv.value_type = value_type
end
