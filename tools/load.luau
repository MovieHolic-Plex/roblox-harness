-- Lune loader: runs the Roblox-style modules in src/ (which use `require(script.Parent.X)`)
-- under Lune by giving each module a virtual `script` that maps onto the file tree.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local M = {}
local cache = {}

local function resolve(path: string): string?
	if fs.isFile(path .. ".lua") then return path .. ".lua" end
	if fs.isFile(path .. ".luau") then return path .. ".luau" end
	if fs.isDir(path) and fs.isFile(path .. "/init.lua") then return path .. "/init.lua" end
	if fs.isDir(path) and fs.isFile(path .. "/init.luau") then return path .. "/init.luau" end
	return nil
end

local nodeMT = {}
local function node(path: string)
	return setmetatable({ __path = path }, nodeMT)
end
nodeMT.__index = function(self, k)
	local path = rawget(self, "__path")
	if k == "Parent" then return node((string.match(path, "^(.*)/[^/]+$"))) end
	if k == "Name" then return string.match(path, "([^/]+)$") end
	return node(path .. "/" .. k)
end

local baseEnv = {}
for k, v in roblox do baseEnv[k] = v end
for _, k in { "Enum", "Instance", "Vector3", "CFrame", "Color3", "BrickColor", "Vector2", "UDim2", "NumberRange", "NumberSequence", "ColorSequence" } do
	baseEnv[k] = (roblox :: any)[k]
end
for _, k in { "print", "pairs", "ipairs", "table", "math", "string", "type", "typeof", "tostring", "tonumber",
	"setmetatable", "getmetatable", "select", "error", "pcall", "xpcall", "assert", "rawget", "rawset", "rawequal",
	"next", "os", "bit32", "buffer", "utf8", "unpack" } do
	baseEnv[k] = (getfenv(1) :: any)[k]
end
baseEnv.warn = function(...) print("[warn]", ...) end
baseEnv.task = require("@lune/task")

function M.require(target)
	local path = type(target) == "table" and rawget(target, "__path") or target
	assert(type(path) == "string", "load.require: expected virtual script node or path")
	if cache[path] ~= nil then return cache[path] end
	local file = resolve(path)
	assert(file, "module not found: " .. path)
	local env = table.clone(baseEnv)
	env.script = node(path)
	env.require = M.require
	local fn = luau.load(fs.readFile(file), { debugName = file, environment = env })
	local r = fn()
	cache[path] = r
	return r
end

-- Root of the harness tree, e.g. load.harness("src/Harness")
function M.harness(root: string?)
	return M.require(root or "src/Harness")
end

M.roblox = roblox
return M
