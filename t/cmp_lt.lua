-- cmp_lt.rego
--
-- package cmp
--
-- default lt := false
--
-- lt if {
--     input.a < input.b
-- }

local cmp = {}

function cmp.lt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lt = false
  if type(a) == "number" and type(b) == "number" and a < b then
    lt = true
  end
  return lt
end

return cmp
