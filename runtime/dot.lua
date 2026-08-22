
-- Copyright (c) 2026, Lei Meng

-- dot.lua — Layer 2: field / index access (IR DotStmt)
--
-- Rego: missing key or bad source → undefined (not Lua nil, not error).
-- Arrays are 0-based in Rego and 1-based in Lua / lua-cjson / make_array.

return function(rt, priv)
  function rt.dot(source, key)
    if rawequal(source, rt.UNDEF) then
      return rt.UNDEF
    end
    if type(source) ~= "table" then
      return rt.UNDEF
    end
    local k = key
    if type(key) == "number" and key >= 0 and key == math.floor(key)
        and priv.table_kind(source) == "array" then
      k = key + 1
    end
    local v = source[k]
    if v == nil then
      return rt.UNDEF
    end
    return v
  end
end
