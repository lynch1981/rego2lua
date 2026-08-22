# vi:set ft=perl:

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: equal numbers
--- input
{
    "a": 3,
    "b": 3
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.a != input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if a ~= nil and b ~= nil and a ~= b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 2: unequal numbers
--- input
{
    "a": 5,
    "b": 2
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.a != input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if a ~= nil and b ~= nil and a ~= b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 3: equal strings
--- input
{
    "a": "GET",
    "b": "GET"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.a != input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if a ~= nil and b ~= nil and a ~= b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 4: unequal strings
--- input
{
    "a": "GET",
    "b": "POST"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.a != input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if a ~= nil and b ~= nil and a ~= b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 5: missing a
--- input
{
    "b": 1
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.a != input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if a ~= nil and b ~= nil and a ~= b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 6: empty input
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
    input.a != input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if a ~= nil and b ~= nil and a ~= b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}
