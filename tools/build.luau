-- lune run tools/build.luau <object|character|anim> <spec.lua|spec.json> <out.rbxm>
-- Builds one spec and writes it as a binary model (drag into Studio, or `rojo build` it in).
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local L = require("./load")

local H = L.harness("src/Harness")

local kind, input, out = process.args[1], process.args[2], process.args[3]
if not (kind and input and out) then
	print("usage: lune run tools/build.luau <object|character|anim> <spec.lua|spec.json> <out.rbxm>")
	process.exit(2)
end

local function loadSpec(path: string): any
	if string.match(path, "%.json$") then return serde.decode("json", fs.readFile(path)) end
	return L.require((string.gsub(path, "%.luau?$", "")))
end

local spec = loadSpec(input)
local inst
if kind == "object" then
	inst = H.Object.build(spec)
elseif kind == "character" then
	inst = H.Character.build(spec)
elseif kind == "anim" then
	inst = H.Anim.toKeyframeSequence(spec)
else
	error("unknown kind " .. kind)
end
fs.writeFile(out, roblox.serializeModel({ inst }))
print(("wrote %s (%s)"):format(out, inst.Name))
