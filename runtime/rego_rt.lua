
-- Copyright (c) 2026, Lei Meng <lynch.meng@hotmail.com>

-- rego_rt.lua — facade: assemble the Rego runtime for IR → Lua.
--
-- Public entry (codegen / tests):
--   local rt = assert(loadfile("runtime/rego_rt.lua"))()
--
-- Public kernel:
--   rt.UNDEF, rt.is_undef, rt.is_def, rt.is_ok, rt.NULL
--   rt.dot
--   rt.values_equal          -- EqualStmt (boolean; UNDEF → false)
--   rt.make_array / make_object / make_set
--   rt.call_builtin(name, …) -- CallStmt: local def, v = rt.call_builtin(...)
--   rt.builtins              -- raw 3-valued registry (not for codegen)
--
-- Never: local x = rt.call_builtin("plus", a, b)  -- x is the defined flag
-- Never: if rt.call_builtin(...) then             -- discards the value
--
-- Named OPA builtins live on priv; codegen uses call_builtin only.
-- Read order: value → dot → types → compare → numbers → builtins
-- See runtime/README.md.

local rt = {}
local priv = {}

local function this_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then
    return src:sub(2):match("(.*/)") or "./"
  end
  return "./"
end

local DIR = this_dir()

local function load_layer(name)
  local path = DIR .. name .. ".lua"
  local chunk, err = loadfile(path)
  assert(chunk, err or ("runtime: missing " .. path))
  local install = chunk()
  assert(type(install) == "function", "runtime: " .. name .. " must return install(rt, priv)")
  install(rt, priv)
end

load_layer("value")     -- UNDEF, NULL, is_ok, make_*, priv.table_kind / value_type
load_layer("dot")       -- rt.dot
load_layer("types")     -- priv.is_* / type_name
load_layer("compare")   -- rt.values_equal; priv.equal / neq / lt…
load_layer("numbers")   -- priv.plus … numbers_range
load_layer("builtins")  -- rt.builtins, call_builtin

return rt
