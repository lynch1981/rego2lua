# vi:set ft=perl:

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: less
--- input
{
    "a": 1,
    "b": 4
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.a < input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if type(a) == type(b)
     and (type(a) == "number" or type(a) == "string")
     and a < b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 2: equal
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
    input.a < input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if type(a) == type(b)
     and (type(a) == "number" or type(a) == "string")
     and a < b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 3: greater
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
    input.a < input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if type(a) == type(b)
     and (type(a) == "number" or type(a) == "string")
     and a < b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 4: negative and zero
--- input
{
    "a": -1,
    "b": 0
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.a < input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if type(a) == type(b)
     and (type(a) == "number" or type(a) == "string")
     and a < b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 5: strings
--- input
{
    "a": "a",
    "b": "b"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.a < input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if type(a) == type(b)
     and (type(a) == "number" or type(a) == "string")
     and a < b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 6: missing a
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
    input.a < input.b
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local allow = false
  if type(a) == type(b)
     and (type(a) == "number" or type(a) == "string")
     and a < b then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}
