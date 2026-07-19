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

function foo.eval(input)
  input = input or {}

  local allow = false

  do
    local method = input.method
    if method == "GET" then
      allow = true
    end
  end

  return { allow = allow }
end

function foo.allow(input)
  return foo.eval(input).allow
end

return foo
