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
package cmp

default lt := false

lt if {
    input.a < input.b
}
--- ref_lua
local cmp = {}

function cmp.lt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lt = false
  if type(a) == "number" and type(b) == "number" and a < b then
    lt = true
  end
  return lt
end

return cmp
--- out
{
    "lt": true
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
package cmp

default lt := false

lt if {
    input.a < input.b
}
--- ref_lua
local cmp = {}

function cmp.lt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lt = false
  if type(a) == "number" and type(b) == "number" and a < b then
    lt = true
  end
  return lt
end

return cmp
--- out
{
    "lt": false
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
package cmp

default lt := false

lt if {
    input.a < input.b
}
--- ref_lua
local cmp = {}

function cmp.lt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lt = false
  if type(a) == "number" and type(b) == "number" and a < b then
    lt = true
  end
  return lt
end

return cmp
--- out
{
    "lt": false
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
package cmp

default lt := false

lt if {
    input.a < input.b
}
--- ref_lua
local cmp = {}

function cmp.lt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lt = false
  if type(a) == "number" and type(b) == "number" and a < b then
    lt = true
  end
  return lt
end

return cmp
--- out
{
    "lt": true
}

=== TEST 5: strings (not numbers)
--- input
{
    "a": "a",
    "b": "b"
}
--- data
{
}
--- Rego
package cmp

default lt := false

lt if {
    input.a < input.b
}
--- ref_lua
local cmp = {}

function cmp.lt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lt = false
  if type(a) == "number" and type(b) == "number" and a < b then
    lt = true
  end
  return lt
end

return cmp
--- out
{
    "lt": false
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
package cmp

default lt := false

lt if {
    input.a < input.b
}
--- ref_lua
local cmp = {}

function cmp.lt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lt = false
  if type(a) == "number" and type(b) == "number" and a < b then
    lt = true
  end
  return lt
end

return cmp
--- out
{
    "lt": false
}
