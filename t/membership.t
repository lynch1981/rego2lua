# vi:set ft=perl:

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: in - role present
--- input
{
    "roles": ["user", "admin"]
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    "admin" in input.roles
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local roles = input.roles
  if type(roles) == "table" then
    for i = 1, #roles do
      if roles[i] == "admin" then
        allow = true
        break
      end
    end
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 2: in - role absent
--- input
{
    "roles": ["user", "viewer"]
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    "admin" in input.roles
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local roles = input.roles
  if type(roles) == "table" then
    for i = 1, #roles do
      if roles[i] == "admin" then
        allow = true
        break
      end
    end
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 3: some - role present
--- input
{
    "roles": ["user", "admin"]
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.roles[_] == "admin"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local roles = input.roles
  if type(roles) == "table" then
    for i = 1, #roles do
      if roles[i] == "admin" then
        allow = true
        break
      end
    end
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 4: some - role absent
--- input
{
    "roles": ["user", "viewer"]
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.roles[_] == "admin"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local roles = input.roles
  if type(roles) == "table" then
    for i = 1, #roles do
      if roles[i] == "admin" then
        allow = true
        break
      end
    end
  end
  return allow
end

return foo
--- out
{
    "allow": false
}
