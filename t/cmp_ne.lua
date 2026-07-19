-- cmp_ne.rego
--
-- package cmp
--
-- default ne := false
--
-- ne if {
--     input.a != input.b
-- }

local cmp = {}

function cmp.ne(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local ne = false
  if a ~= nil and b ~= nil and a ~= b then
    ne = true
  end
  return ne
end

return cmp
