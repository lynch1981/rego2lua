-- cmp_eq.rego
--
-- package cmp
--
-- default eq := false
--
-- eq if {
--     input.a == input.b
-- }

local cmp = {}

function cmp.eq(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local eq = false
  if a ~= nil and b ~= nil and a == b then
    eq = true
  end
  return eq
end

return cmp
