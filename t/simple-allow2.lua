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

function foo.eval(input)
  input = input or {}

  local allow = false

  if input.method == "GET" then
    allow = true
  end

  return { allow = allow }
end

function foo.allow(input)
  return foo.eval(input).allow
end

return foo
