-- types.lua — Layer 3: type predicates & type_name (CallStmt builtins)
--
-- Installed on priv only. Codegen: rt.call_builtin("is_string", x).
-- UNDEF propagates: is_string(UNDEF) → UNDEF (not false).

return function(rt, priv)
  local table_kind = priv.table_kind
  local value_type = priv.value_type
  local NULL = priv.NULL

  -- Shared UNDEF guard for is_* predicates.
  local function guard(pred)
    return function(x)
      if rawequal(x, rt.UNDEF) then
        return rt.UNDEF
      end
      return pred(x)
    end
  end

  function priv.type_name(x)
    if rawequal(x, rt.UNDEF) then
      return rt.UNDEF
    end
    local vt = value_type(x)
    if vt == "undefined" then
      return rt.UNDEF
    end
    return vt
  end

  priv.is_null    = guard(function(x) return rawequal(x, NULL) end)
  priv.is_boolean = guard(function(x) return type(x) == "boolean" end)
  priv.is_number  = guard(function(x) return type(x) == "number" end)
  priv.is_string  = guard(function(x) return type(x) == "string" end)
  priv.is_array   = guard(function(x)
    return type(x) == "table" and table_kind(x) == "array"
  end)
  priv.is_object  = guard(function(x)
    return type(x) == "table" and table_kind(x) == "object"
  end)
  priv.is_set     = guard(function(x)
    return type(x) == "table" and table_kind(x) == "set"
  end)
end
