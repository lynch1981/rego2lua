# vi:set ft=perl:

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: greater
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

default gte := false

gte if {
    input.a >= input.b
}
--- ref_lua
local cmp = {}

function cmp.gte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gte = false
  if type(a) == "number" and type(b) == "number" and a >= b then
    gte = true
  end
  return gte
end

return cmp
--- out
{
    "gte": true
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

default gte := false

gte if {
    input.a >= input.b
}
--- ref_lua
local cmp = {}

function cmp.gte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gte = false
  if type(a) == "number" and type(b) == "number" and a >= b then
    gte = true
  end
  return gte
end

return cmp
--- out
{
    "gte": true
}



=== TEST 3: less
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

default gte := false

gte if {
    input.a >= input.b
}
--- ref_lua
local cmp = {}

function cmp.gte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gte = false
  if type(a) == "number" and type(b) == "number" and a >= b then
    gte = true
  end
  return gte
end

return cmp
--- out
{
    "gte": false
}



=== TEST 4: strings (not numbers)
--- input
{
    "a": "b",
    "b": "a"
}
--- data
{
}
--- Rego
package cmp

default gte := false

gte if {
    input.a >= input.b
}
--- ref_lua
local cmp = {}

function cmp.gte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gte = false
  if type(a) == "number" and type(b) == "number" and a >= b then
    gte = true
  end
  return gte
end

return cmp
--- out
{
    "gte": false
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

default gte := false

gte if {
    input.a >= input.b
}
--- ref_lua
local cmp = {}

function cmp.gte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gte = false
  if type(a) == "number" and type(b) == "number" and a >= b then
    gte = true
  end
  return gte
end

return cmp
--- out
{
    "gte": false
}
