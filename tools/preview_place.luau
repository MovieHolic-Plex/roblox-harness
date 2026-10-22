-- Builds out/harness_preview.rbxlx: every example laid out, posed animation samples, and a
-- LocalScript that flies a scripted camera through fixed shots (press Play in Studio).
-- Used for visual QA; screenshots of these shots live in docs/img/.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local L = require("./load")
local H = L.harness("src/Harness")
local CF, V3, I = roblox.CFrame, roblox.Vector3, roblox.Instance

local function sorted(dir: string, pat: string): { string }
	local t = {}
	for _, f in fs.readDir(dir) do if string.match(f, pat) then table.insert(t, f) end end
	table.sort(t)
	return t
end
local function loadSpec(path: string): any
	if string.match(path, "%.json$") then return serde.decode("json", fs.readFile(path)) end
	return L.require((string.gsub(path, "%.luau?$", "")))
end

local game = I.new("DataModel")
local ws = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
lighting.ClockTime = 14.5
lighting.Technology = roblox.Enum.Technology.ShadowMap
lighting.Brightness = 2.5
lighting.Ambient = roblox.Color3.fromRGB(110, 110, 120)
lighting.OutdoorAmbient = roblox.Color3.fromRGB(150, 150, 160)
game:GetService("Players").CharacterAutoLoads = false

local shots = {}
local function shot(name: string, eye, target)
	table.insert(shots, ("{%q, Vector3.new(%g,%g,%g), Vector3.new(%g,%g,%g)}"):format(name, eye.X, eye.Y, eye.Z, target.X, target.Y, target.Z))
end

-- objects: one every 80 studs along X
local ox = 0
local objectFiles = sorted("examples/objects", "%.[lj][us][ao]n?$")
for _, f in objectFiles do
	local spec = loadSpec("examples/objects/" .. f)
	local m = H.Object.build(spec, ws, { origin = CF.new(ox, 0, 0) })
	local name = m.Name
	if name == "JumpTower" then shot("obj_" .. name, V3.new(ox + 42, 34, 50), V3.new(ox, 22, 0))
	elseif name == "BambooGrove" then shot("obj_" .. name, V3.new(ox + 30, 22, 36), V3.new(ox, 4, 0))
	elseif name == "PirateDock" then shot("obj_" .. name, V3.new(ox + 26, 18, 30), V3.new(ox, 5, 0))
	else shot("obj_" .. name, V3.new(ox + 10, 9, 14), V3.new(ox, 3, 0)) end
	ox += 80
end

-- characters: lineup facing +Z at z = -80
local charFiles = sorted("examples/characters", "%.lua$")
local n = #charFiles
local gap = 7
local x0 = -(n - 1) * gap / 2
local folder = I.new("Folder"); folder.Name = "Characters"; folder.Parent = ws
for i, f in charFiles do
	local spec = loadSpec("examples/characters/" .. f)
	local x = x0 + (i - 1) * gap
	local c = H.Character.build(spec, { origin = CF.new(x, 0, -80) * CF.Angles(0, math.pi, 0) })
	c.Parent = folder
	shot("char_" .. spec.name, V3.new(x + 2.6, 4.6, -80 + 7), V3.new(x, 3.0, -80))
	shot("face_" .. spec.name, V3.new(x + 1.1, 5.0, -80 + 3.9), V3.new(x, 4.75, -80))
	-- back view twin
	local b = H.Character.build(spec, { origin = CF.new(x, 0, -110) })
	b.Parent = folder
end
shot("lineup_front", V3.new(0, 5.5, -80 + 24), V3.new(0, 3, -80))
shot("lineup_back", V3.new(0, 5.5, -110 + 24), V3.new(0, 3, -110))

-- animation samples: SwordRonin posed by Slash / FoxNinja by JumpClimb / RubberPirate by Wave
local poses = {
	{ "SwordRonin", "Slash", 0.2 }, { "SwordRonin", "Slash", 0.35 },
	{ "FoxNinja", "JumpClimb", 0.45 }, { "RubberPirate", "Wave", 0.3 },
}
for i, p in poses do
	local spec = loadSpec("examples/characters/" .. p[1] .. ".lua")
	local anim = loadSpec("examples/anims/" .. p[2] .. ".lua")
	local x = (i - 2.5) * 6
	local c = H.Character.build(spec, { origin = CF.new(x, 0, -140) * CF.Angles(0, math.pi, 0) })
	c.Name = p[1] .. "_" .. p[2] .. "_" .. p[3]
	H.Anim.apply(c, anim, p[3], "C0")
	c.Parent = folder
end
shot("anim_poses", V3.new(4, 5.5, -140 + 16), V3.new(0, 3, -140))

local floor = I.new("Part")
floor.Name = "Floor"; floor.Anchored = true; floor.Size = V3.new(600, 1, 300); floor.CFrame = CF.new(150, -0.6, -60)
floor.Color = roblox.Color3.fromRGB(205, 205, 210); floor.Material = roblox.Enum.Material.SmoothPlastic
floor.Parent = ws

local ls = I.new("LocalScript")
ls.Name = "HarnessShots"
ls.Source = ([[
local shots = { %s }
local StarterGui = game:GetService("StarterGui")
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
pcall(function() game:GetService("TextChatService").ChatWindowConfiguration.Enabled = false end)
pcall(function() game:GetService("TextChatService").ChatInputBarConfiguration.Enabled = false end)
pcall(function() StarterGui:SetCore("TopbarEnabled", false) end)
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 50
task.wait(%d)
for i, s in ipairs(shots) do
	cam.CFrame = CFrame.lookAt(s[2], s[3])
	print(("[HarnessShot] %%d %%s"):format(i, s[1]))
	task.wait(%g)
end
print("[HarnessShot] done")
]]):format(table.concat(shots, ",\n\t"), 6, 3)
local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts") or I.new("StarterPlayerScripts")
sps.Parent = game:GetService("StarterPlayer")
ls.Parent = sps
if not fs.isDir("out") then fs.writeDir("out") end
fs.writeFile("out/harness_preview.rbxlx", roblox.serializePlace(game))
local names = {}
for i, s in shots do names[i] = string.match(s, '^{"([^"]+)"') end
fs.writeFile("out/shots.txt", table.concat(names, "\n"))
print(("preview place with %d shots"):format(#shots))
