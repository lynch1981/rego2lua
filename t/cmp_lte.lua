-- cmp_lte.rego
--
-- package cmp
--
-- default lte := false
--
-- lte if {
--     input.a <= input.b
-- }

local cmp = {}

function cmp.lte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lte = false
  if type(a) == "number" and type(b) == "number" and a <= b then
    lte = true
  end
  return lte
end

return cmp
