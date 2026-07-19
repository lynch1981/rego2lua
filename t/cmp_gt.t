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

default gt := false

gt if {
    input.a > input.b
}
--- ref_lua
local cmp = {}

function cmp.gt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gt = false
  if type(a) == "number" and type(b) == "number" and a > b then
    gt = true
  end
  return gt
end

return cmp
--- out
{
    "gt": true
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

default gt := false

gt if {
    input.a > input.b
}
--- ref_lua
local cmp = {}

function cmp.gt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gt = false
  if type(a) == "number" and type(b) == "number" and a > b then
    gt = true
  end
  return gt
end

return cmp
--- out
{
    "gt": false
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

default gt := false

gt if {
    input.a > input.b
}
--- ref_lua
local cmp = {}

function cmp.gt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gt = false
  if type(a) == "number" and type(b) == "number" and a > b then
    gt = true
  end
  return gt
end

return cmp
--- out
{
    "gt": false
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

default gt := false

gt if {
    input.a > input.b
}
--- ref_lua
local cmp = {}

function cmp.gt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gt = false
  if type(a) == "number" and type(b) == "number" and a > b then
    gt = true
  end
  return gt
end

return cmp
--- out
{
    "gt": false
}

=== TEST 5: strings (not numbers)
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

default gt := false

gt if {
    input.a > input.b
}
--- ref_lua
local cmp = {}

function cmp.gt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gt = false
  if type(a) == "number" and type(b) == "number" and a > b then
    gt = true
  end
  return gt
end

return cmp
--- out
{
    "gt": false
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

default gt := false

gt if {
    input.a > input.b
}
--- ref_lua
local cmp = {}

function cmp.gt(input)
  input = input or {}
  local a = input.a
  local b = input.b
  local gt = false
  if type(a) == "number" and type(b) == "number" and a > b then
    gt = true
  end
  return gt
end

return cmp
--- out
{
    "gt": false
}
