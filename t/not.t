# vi:set ft=perl:

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: not - expression false, not succeeds
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



=== TEST 2: not - expression true, not fails
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
