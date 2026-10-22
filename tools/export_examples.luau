-- Builds every example into out/: one .rbxm each, plus out/Examples.rbxm with everything
-- and out/preview.rbxlx — a place with all examples laid out for visual QA in Studio.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local L = require("./load")
local H = L.harness("src/Harness")

local function sorted(dir: string, pat: string): { string }
	local t = {}
	for _, f in fs.readDir(dir) do
		if string.match(f, pat) then table.insert(t, f) end
	end
	table.sort(t)
	return t
end

local function loadSpec(path: string): any
	if string.match(path, "%.json$") then return serde.decode("json", fs.readFile(path)) end
	return L.require((string.gsub(path, "%.luau?$", "")))
end

if not fs.isDir("out") then fs.writeDir("out") end
local objects, chars, anims = {}, {}, {}
local ox = 0
for _, f in sorted("examples/objects", "%.[lj][us][ao]n?$") do
	local m = H.Object.build(loadSpec("examples/objects/" .. f), nil, { origin = roblox.CFrame.new(ox, 0, 0) })
	table.insert(objects, m)
	ox += 60
end
for _, f in sorted("examples/characters", "%.lua$") do
	table.insert(chars, H.Character.build(loadSpec("examples/characters/" .. f)))
end
for _, f in sorted("examples/anims", "%.lua$") do
	table.insert(anims, H.Anim.toKeyframeSequence(loadSpec("examples/anims/" .. f)))
end
for _, i in objects do fs.writeFile("out/" .. i.Name .. ".rbxm", roblox.serializeModel({ i })) end
for _, i in chars do fs.writeFile("out/" .. i.Name .. ".rbxm", roblox.serializeModel({ i })) end
for _, i in anims do fs.writeFile("out/" .. i.Name .. ".rbxm", roblox.serializeModel({ i })) end

-- Preview place ------------------------------------------------------------------------
local game = roblox.Instance.new("DataModel")
local ws = game:GetService("Workspace")
local root = roblox.Instance.new("Folder")
root.Name = "HarnessPreview"
root.Parent = ws
local CF, V3 = roblox.CFrame, roblox.Vector3
for _, m in objects do
	m.Parent = root
end
local cx = 0
local cf = roblox.Instance.new("Folder")
cf.Name = "Characters"
cf.Parent = root
for i, c in chars do
	-- rebuild at a position so the rig and look stay consistent
	local spec = loadSpec("examples/characters/" .. sorted("examples/characters", "%.lua$")[i])
	local placed = H.Character.build(spec, { origin = CF.new(cx, 0, -60) * CF.Angles(0, math.pi, 0), anchored = true })
	placed.Parent = cf
	c:Destroy()
	cx += 6
end
local floor = roblox.Instance.new("Part")
floor.Name = "Floor"; floor.Anchored = true; floor.Size = V3.new(400, 1, 200); floor.CFrame = CF.new(100, -0.5, -40)
floor.Color = roblox.Color3.fromRGB(200, 200, 205); floor.Material = roblox.Enum.Material.SmoothPlastic
floor.Parent = ws
fs.writeFile("out/preview.rbxlx", roblox.serializePlace(game))
print(("exported %d objects, %d characters, %d animations"):format(#objects, #chars, #anims))
