-- Studio/runtime demo: builds every example spec into Workspace.HarnessExamples using the
-- in-engine library (the same code path Lune uses). JSON specs arrive as StringValues via Rojo.
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Harness = require(RS:WaitForChild("Harness"))
local ex = RS:WaitForChild("HarnessExamples")

local out = Instance.new("Folder")
out.Name = "HarnessExamples"
out.Parent = workspace

local function sortedChildren(f: Instance): { Instance }
	local t = f:GetChildren()
	table.sort(t, function(a, b) return a.Name < b.Name end)
	return t
end

local function load(m: Instance): any
	if m:IsA("ModuleScript") then return require(m) :: any end
	if m:IsA("StringValue") then return HttpService:JSONDecode(m.Value) end
	return nil
end

local x = 0
for _, m in ipairs(sortedChildren(ex.objects)) do
	local spec = load(m)
	if spec then
		Harness.Object.build(spec, out, { origin = CFrame.new(x, 0, 0) })
		x += 60
	end
end
local cx = 0
for _, m in ipairs(sortedChildren(ex.characters)) do
	local c = Harness.Character.build(load(m), { origin = CFrame.new(cx, 0, -60) * CFrame.Angles(0, math.pi, 0), anchored = true })
	c.Parent = out
	cx += 6
end
print(("[Harness] built %d example objects/characters"):format(#out:GetChildren()))
