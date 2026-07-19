-- simple-allow.rego
--
-- package foo
--
-- default allow := false
--
-- allow if {
--     method := input.method
--     method == "GET"
-- }

local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  do
    local method = input.method
    if method == "GET" then
      allow = true
    end
  end
  return allow
end

return foo
