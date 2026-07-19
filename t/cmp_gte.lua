-- cmp_gte.rego
--
-- package cmp
--
-- default gte := false
--
-- gte if {
--     input.a >= input.b
-- }

local cmp = {}

function cmp.gte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gte = false
  if type(a) == "number" and type(b) == "number" and a >= b then
    gte = true
  end
  return gte
end

return cmp
