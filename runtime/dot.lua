
-- Copyright (c) 2026, Lei Meng

-- dot.lua — Layer 2: field / index access (IR DotStmt)
--
-- Rego: missing key or bad source → undefined (not Lua nil, not error).

return function(rt, _priv)
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
end
