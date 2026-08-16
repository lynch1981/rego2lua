-- builtins.lua — Layer 6: CallStmt name → priv implementations
--
-- rt.builtins[name]  — raw 3-valued impl (true | false | UNDEF | value)
-- rt.call_builtin    — codegen: local def, v = rt.call_builtin(name, ...)
--                      def is a boolean; v is the result only when def.

return function(rt, priv)
  local reg = {
    equal = priv.equal,
    neq   = priv.neq,
    gt    = priv.gt,
    gte   = priv.gte,
    lt    = priv.lt,
    lte   = priv.lte,

    is_string  = priv.is_string,
    is_number  = priv.is_number,
    is_boolean = priv.is_boolean,
    is_null    = priv.is_null,
    is_array   = priv.is_array,
    is_object  = priv.is_object,
    is_set     = priv.is_set,
    type_name  = priv.type_name,

    to_number = priv.to_number,
    plus      = priv.plus,
    minus     = priv.minus,
    mul       = priv.mul,
    div       = priv.div,
    rem       = priv.rem,
    abs       = priv.abs,
    ["numbers.range"] = priv.numbers_range,
  }

  for name, fn in pairs(reg) do
    assert(type(fn) == "function",
      "runtime: missing priv impl for builtin " .. tostring(name))
  end

  rt.builtins = reg

  --- CallStmt dispatch: (defined, value).
  --- defined == false → unknown name or impl UNDEF; second return is nil.
  function rt.call_builtin(name, ...)
    local fn = rt.builtins[name]
    if not fn then
      return false
    end
    local v = fn(...)
    if rawequal(v, rt.UNDEF) then
      return false
    end
    return true, v
  end
end
