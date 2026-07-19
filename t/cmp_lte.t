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

default lte := false

lte if {
    input.a <= input.b
}
--- ref_lua
local cmp = {}

function cmp.lte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lte = false
  if type(a) == "number" and type(b) == "number" and a <= b then
    lte = true
  end
  return lte
end

return cmp
--- out
{
    "lte": true
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

default lte := false

lte if {
    input.a <= input.b
}
--- ref_lua
local cmp = {}

function cmp.lte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lte = false
  if type(a) == "number" and type(b) == "number" and a <= b then
    lte = true
  end
  return lte
end

return cmp
--- out
{
    "lte": true
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

default lte := false

lte if {
    input.a <= input.b
}
--- ref_lua
local cmp = {}

function cmp.lte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lte = false
  if type(a) == "number" and type(b) == "number" and a <= b then
    lte = true
  end
  return lte
end

return cmp
--- out
{
    "lte": false
}



=== TEST 4: strings (not numbers)
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

default lte := false

lte if {
    input.a <= input.b
}
--- ref_lua
local cmp = {}

function cmp.lte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lte = false
  if type(a) == "number" and type(b) == "number" and a <= b then
    lte = true
  end
  return lte
end

return cmp
--- out
{
    "lte": false
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

default lte := false

lte if {
    input.a <= input.b
}
--- ref_lua
local cmp = {}

function cmp.lte(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local lte = false
  if type(a) == "number" and type(b) == "number" and a <= b then
    lte = true
  end
  return lte
end

return cmp
--- out
{
    "lte": false
}
