# vi:set ft=perl:

use lib '.';
use t::Rego 'no_plan';

run_tests;

__DATA__

=== TEST 1: object field access
--- input
{
    "user": {
        "name": "alice"
    }
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.user.name == "alice"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local user = input.user
  if type(user) == "table" and user.name == "alice" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 2: object field mismatch
--- input
{
    "user": {
        "name": "bob"
    }
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.user.name == "alice"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local user = input.user
  if type(user) == "table" and user.name == "alice" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 3: nested object access
--- input
{
    "request": {
        "http": {
            "method": "GET"
        }
    }
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.request.http.method == "GET"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local request = input.request
  if type(request) == "table" then
    local http = request.http
    if type(http) == "table" and http.method == "GET" then
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



=== TEST 4: missing nested field
--- input
{
    "request": {
        "http": {}
    }
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.request.http.method == "GET"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local request = input.request
  if type(request) == "table" then
    local http = request.http
    if type(http) == "table" and http.method == "GET" then
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



=== TEST 5: array index access (first element)
--- input
{
    "roles": ["admin", "user"]
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.roles[0] == "admin"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local roles = input.roles
  if type(roles) == "table" and roles[1] == "admin" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 6: array index access (second element)
--- input
{
    "roles": ["user", "admin"]
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.roles[1] == "admin"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local roles = input.roles
  if type(roles) == "table" and roles[2] == "admin" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": true
}



=== TEST 7: array index out of range
--- input
{
    "roles": ["user"]
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.roles[1] == "admin"
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local roles = input.roles
  if type(roles) == "table" and roles[2] == "admin" then
    allow = true
  end
  return allow
end

return foo
--- out
{
    "allow": false
}



=== TEST 8: mixed object and array access
--- input
{
    "servers": [
        {
            "name": "web",
            "port": 80
        },
        {
            "name": "api",
            "port": 8080
        }
    ]
}
--- data
{
}
--- Rego
package foo

default allow := false

allow if {
    input.servers[1].name == "api"
    input.servers[1].port == 8080
}
--- ref_lua
local foo = {}

function foo.allow(input)
  input = input or {}
  local allow = false
  local servers = input.servers
  if type(servers) == "table" then
    local s = servers[2]
    if type(s) == "table" and s.name == "api" and s.port == 8080 then
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
