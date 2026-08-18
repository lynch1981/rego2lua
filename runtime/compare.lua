
-- Copyright (c) 2026, Lei Meng <lynch.meng@hotmail.com>

-- compare.lua — Layer 4: deep equality & ordering (OPA-style)
--
-- Public (kernel / EqualStmt):
--   rt.values_equal(a, b)  → boolean; derived from priv.equal (UNDEF → false)
--
-- CallStmt (priv → builtins.lua):
--   equal, neq, lt, lte, gt, gte  (UNDEF if either operand UNDEF)

return function(rt, priv)
  local NULL = priv.NULL
  local TYPE_RANK = priv.TYPE_RANK
  local value_type = priv.value_type

  local compare_values

  local function sorted_keys(t)
    local keys = {}
    for k, _ in pairs(t) do
      keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
      return compare_values(a, b) < 0
    end)
    return keys
  end

  local function set_elements(t)
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
    if rawequal(a, NULL) and rawequal(b, NULL) then
      return 0
    end

    local ta, tb = value_type(a), value_type(b)
    if ta == "undefined" or tb == "undefined" then
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

    local sa, sb = tostring(a), tostring(b)
    if sa < sb then return -1 end
    if sa > sb then return 1 end
    return 0
  end

  priv.compare = compare_values

  --- CallStmt equal: UNDEF if either operand is UNDEF, else boolean.
  function priv.equal(a, b)
    if rawequal(a, rt.UNDEF) or rawequal(b, rt.UNDEF) then
      return rt.UNDEF
    end
    return compare_values(a, b) == 0
  end

  function priv.neq(a, b)
    if rawequal(a, rt.UNDEF) or rawequal(b, rt.UNDEF) then
      return rt.UNDEF
    end
    return compare_values(a, b) ~= 0
  end

  --- EqualStmt: single UNDEF policy via priv.equal (only exact true is equal).
  function rt.values_equal(a, b)
    return priv.equal(a, b) == true
  end

  local function ord_builtin(want)
    return function(a, b)
      if rawequal(a, rt.UNDEF) or rawequal(b, rt.UNDEF) then
        return rt.UNDEF
      end
      local c = compare_values(a, b)
      if want == "lt"  then return c < 0 end
      if want == "lte" then return c <= 0 end
      if want == "gt"  then return c > 0 end
      if want == "gte" then return c >= 0 end
      return false
    end
  end

  priv.lt  = ord_builtin("lt")
  priv.lte = ord_builtin("lte")
  priv.gt  = ord_builtin("gt")
  priv.gte = ord_builtin("gte")
end
