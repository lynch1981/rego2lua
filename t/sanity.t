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



=== TEST 4: implicit AND - both expressions true
--- input
{
    "method": "GET",
    "user": "alice"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.method == "GET"
    input.user == "alice"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.method == "GET" and input.user == "alice" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 5: implicit AND - first expression false
--- input
{
    "method": "POST",
    "user": "alice"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.method == "GET"
    input.user == "alice"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.method == "GET" and input.user == "alice" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 6: implicit AND - second expression false
--- input
{
    "method": "GET",
    "user": "bob"
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.method == "GET"
    input.user == "alice"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if input.method == "GET" and input.user == "alice" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 7: not - expression false, not succeeds
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
    not input.method == "POST"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if not (input.method == "POST") then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 8: not - expression true, not fails
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
    not input.method == "POST"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  if not (input.method == "POST") then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 9: local binding - allow GET
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



=== TEST 10: local binding - deny POST
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



=== TEST 11: local binding - deny empty input
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
