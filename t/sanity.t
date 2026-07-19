# vi:set ft=perl:

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: direct field - allow GET
--- input
{
    "method": "GET"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.method == "GET"
}
--- ref_lua
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
--- out
{
    "allow": true
}

=== TEST 2: direct field - deny POST
--- input
{
    "method": "POST"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.method == "GET"
}
--- ref_lua
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
--- out
{
    "allow": false
}

=== TEST 3: direct field - deny empty input
--- input
{
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.method == "GET"
}
--- ref_lua
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
--- out
{
    "allow": false
}

=== TEST 4: local binding - allow GET
--- input
{
    "method": "GET"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    method := input.method
    method == "GET"
}
--- ref_lua
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
--- out
{
    "allow": true
}

=== TEST 5: local binding - deny POST
--- input
{
    "method": "POST"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    method := input.method
    method == "GET"
}
--- ref_lua
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
--- out
{
    "allow": false
}

=== TEST 6: local binding - deny empty input
--- input
{
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    method := input.method
    method == "GET"
}
--- ref_lua
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
--- out
{
    "allow": false
}
