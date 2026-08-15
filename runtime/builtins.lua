-- builtins.lua — Layer 6: CallStmt name → priv implementations
--
-- Public: rt.builtins[name], rt.call_builtin(name, ...)
-- Prefer call_builtin in codegen. Every registration must be a function.

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

  --- Call a builtin by IR name. Unknown names return UNDEF.
  function rt.call_builtin(name, ...)
    local fn = rt.builtins[name]
    if not fn then
      return rt.UNDEF
    end
    return fn(...)
  end
end
