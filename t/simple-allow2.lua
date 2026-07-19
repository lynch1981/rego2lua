-- simple-allow2.rego
--
-- package foo
--
-- default allow := false
--
-- allow if {
--     input.method == "GET"
-- }

local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.method == "GET" then
    allow = true
  end
  return allow
end

return foo
