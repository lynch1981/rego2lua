# vi:set ft=perl:

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: unequal numbers
--- input
{
    "a": 10,
    "b": 11
}
--- data
{
}
--- Rego
package cmp

default eq := false

eq if {
    input.a == input.b
}
--- ref_lua
local cmp = {}

function cmp.eq(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local eq = false
  if a ~= nil and b ~= nil and a == b then
    eq = true
  end
  return eq
end

return cmp
--- out
{
    "eq": false
}



=== TEST 2: equal numbers
--- input
{
    "a": 10,
    "b": 10
}
--- data
{
}
--- Rego
package cmp

default eq := false

eq if {
    input.a == input.b
}
--- ref_lua
local cmp = {}

function cmp.eq(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local eq = false
  if a ~= nil and b ~= nil and a == b then
    eq = true
  end
  return eq
end

return cmp
--- out
{
    "eq": true
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
package cmp

default eq := false

eq if {
    input.a == input.b
}
--- ref_lua
local cmp = {}

function cmp.eq(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local eq = false
  if a ~= nil and b ~= nil and a == b then
    eq = true
  end
  return eq
end

return cmp
--- out
{
    "eq": true
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
package cmp

default eq := false

eq if {
    input.a == input.b
}
--- ref_lua
local cmp = {}

function cmp.eq(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local eq = false
  if a ~= nil and b ~= nil and a == b then
    eq = true
  end
  return eq
end

return cmp
--- out
{
    "eq": false
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
package cmp

default eq := false

eq if {
    input.a == input.b
}
--- ref_lua
local cmp = {}

function cmp.eq(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local eq = false
  if a ~= nil and b ~= nil and a == b then
    eq = true
  end
  return eq
end

return cmp
--- out
{
    "eq": false
}



=== TEST 6: empty input
--- input
{
}
--- data
{
}
--- Rego
package cmp

default eq := false

eq if {
    input.a == input.b
}
--- ref_lua
local cmp = {}

function cmp.eq(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local eq = false
  if a ~= nil and b ~= nil and a == b then
    eq = true
  end
  return eq
end

return cmp
--- out
{
    "eq": false
}
