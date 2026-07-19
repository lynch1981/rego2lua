-- Evaluate a policy module: call each rule function with input/data,
-- print one JSON object of rule name -> value (LuaJIT 5.1).
--
-- Usage:
--   luajit t/eval_pkg.lua <module.lua> <input_json> <data_json>
--
-- input_json / data_json are JSON text arguments (not file paths).
-- Test dependency: lua-cjson (Debian/Ubuntu package: lua-cjson).

local cjson = require("cjson.safe")

local function die(msg)
  io.stderr:write(msg .. "\n")
  os.exit(1)
end

local mod_path = arg[1]
local input_json = arg[2]
local data_json = arg[3]
if not mod_path or not input_json or not data_json then
  die("usage: luajit t/eval_pkg.lua <module.lua> <input_json> <data_json>")
end

local function decode_json(label, raw)
  local obj, err = cjson.decode(raw)
  if err then
    die(label .. ": " .. tostring(err))
  end
  return obj
end

local input = decode_json("input", input_json)
local data = decode_json("data", data_json)

local chunk, err = loadfile(mod_path)
if not chunk then
  die("load " .. mod_path .. ": " .. tostring(err))
end
local mod = chunk()
if type(mod) ~= "table" then
  die("module must return a table")
end

local out = {}
local names = {}
for k, v in pairs(mod) do
  if type(v) == "function" then
    names[#names + 1] = k
  end
end
table.sort(names)
for i = 1, #names do
  local k = names[i]
  out[k] = mod[k](input, data)
end

local encoded, enc_err = cjson.encode(out)
if not encoded then
  die("encode result: " .. tostring(enc_err))
end
io.write(encoded)
io.write("\n")
