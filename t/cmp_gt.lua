-- cmp_gt.rego
--
-- package cmp
--
-- default gt := false
--
-- gt if {
--     input.a > input.b
-- }

local cmp = {}

function cmp.gt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gt = false
  if type(a) == "number" and type(b) == "number" and a > b then
    gt = true
  end
  return gt
end

return cmp
