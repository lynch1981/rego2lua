# vi:set ft=perl:

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: string equal
--- input
{
    "v": "hello"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.v == "hello"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.v == "hello" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 2: string not equal
--- input
{
    "v": "world"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.v == "hello"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.v == "hello" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 3: number equal
--- input
{
    "v": 42
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.v == 42
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.v == 42 then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 4: number not equal
--- input
{
    "v": 7
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.v == 42
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.v == 42 then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 5: boolean true
--- input
{
    "v": true
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.v == true
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.v == true then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 6: boolean false
--- input
{
    "v": false
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.v == false
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.v == false then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 7: null equal
--- input
{
    "v": null
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.v == null
}
--- ref_lua
local cjson = require("cjson.safe")
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.v == cjson.null then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 8: null vs missing field
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
    input.v == null
}
--- ref_lua
local cjson = require("cjson.safe")
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.v == cjson.null then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}
