--!strict
-- Blocky R15 rig: 15 parts + HumanoidRootPart, Motor6D joints with the standard R15 names,
-- feet on y = 0, facing -Z. All numbers are multiplied by `scale`.
local Rig = {}

-- name -> { size, center } in studs at scale 1
Rig.Parts = {
	HumanoidRootPart = { { 2, 2, 1 }, { 0, 3, 0 } },
	LowerTorso = { { 2, 0.4, 1 }, { 0, 2.2, 0 } },
	UpperTorso = { { 2, 1.6, 1 }, { 0, 3.2, 0 } },
	Head = { { 1.2, 1.2, 1.2 }, { 0, 4.6, 0 } },
	LeftUpperArm = { { 1, 0.9, 1 }, { -1.5, 3.55, 0 } },
	LeftLowerArm = { { 1, 0.8, 1 }, { -1.5, 2.7, 0 } },
	LeftHand = { { 1, 0.3, 1 }, { -1.5, 2.15, 0 } },
	RightUpperArm = { { 1, 0.9, 1 }, { 1.5, 3.55, 0 } },
	RightLowerArm = { { 1, 0.8, 1 }, { 1.5, 2.7, 0 } },
	RightHand = { { 1, 0.3, 1 }, { 1.5, 2.15, 0 } },
	LeftUpperLeg = { { 1, 0.9, 1 }, { -0.5, 1.55, 0 } },
	LeftLowerLeg = { { 1, 0.8, 1 }, { -0.5, 0.7, 0 } },
	LeftFoot = { { 1, 0.3, 1 }, { -0.5, 0.15, 0 } },
	RightUpperLeg = { { 1, 0.9, 1 }, { 0.5, 1.55, 0 } },
	RightLowerLeg = { { 1, 0.8, 1 }, { 0.5, 0.7, 0 } },
	RightFoot = { { 1, 0.3, 1 }, { 0.5, 0.15, 0 } },
}

-- Build order (parents before children) — also the deterministic child order of the Model.
Rig.Order = {
	"HumanoidRootPart", "LowerTorso", "UpperTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

-- joint name, part0, part1, joint point (world, scale 1). Motor lives in part1 as in Roblox rigs.
export type Joint = { name: string, part0: string, part1: string, at: { number } }
local function J(name: string, p0: string, p1: string, x: number, y: number, z: number): Joint
	return { name = name, part0 = p0, part1 = p1, at = { x, y, z } }
end
Rig.Joints = {
	J("Root", "HumanoidRootPart", "LowerTorso", 0, 2.2, 0),
	J("Waist", "LowerTorso", "UpperTorso", 0, 2.4, 0),
	J("Neck", "UpperTorso", "Head", 0, 4.0, 0),
	J("LeftShoulder", "UpperTorso", "LeftUpperArm", -1.5, 3.8, 0),
	J("LeftElbow", "LeftUpperArm", "LeftLowerArm", -1.5, 3.1, 0),
	J("LeftWrist", "LeftLowerArm", "LeftHand", -1.5, 2.3, 0),
	J("RightShoulder", "UpperTorso", "RightUpperArm", 1.5, 3.8, 0),
	J("RightElbow", "RightUpperArm", "RightLowerArm", 1.5, 3.1, 0),
	J("RightWrist", "RightLowerArm", "RightHand", 1.5, 2.3, 0),
	J("LeftHip", "LowerTorso", "LeftUpperLeg", -0.5, 2.0, 0),
	J("LeftKnee", "LeftUpperLeg", "LeftLowerLeg", -0.5, 1.1, 0),
	J("LeftAnkle", "LeftLowerLeg", "LeftFoot", -0.5, 0.3, 0),
	J("RightHip", "LowerTorso", "RightUpperLeg", 0.5, 2.0, 0),
	J("RightKnee", "RightUpperLeg", "RightLowerLeg", 0.5, 1.1, 0),
	J("RightAnkle", "RightLowerLeg", "RightFoot", 0.5, 0.3, 0),
} :: { Joint }

-- part name -> parent part name (pose hierarchy for KeyframeSequences)
Rig.ParentOf = {} :: { [string]: string }
for _, j in ipairs(Rig.Joints) do
	Rig.ParentOf[j.part1] = j.part0
end

function Rig.isBodyPart(name: any): boolean
	return type(name) == "string" and Rig.Parts[name] ~= nil and name ~= "HumanoidRootPart"
end

-- Returns model, parts map. `origin` places the feet (default origin).
function Rig.build(name: string, scale: number, origin: CFrame?): (Model, { [string]: BasePart })
	local o = origin or CFrame.new()
	local m = Instance.new("Model")
	m.Name = name
	local parts: { [string]: BasePart } = {}
	for _, pn in ipairs(Rig.Order) do
		local d = Rig.Parts[pn]
		local p = Instance.new("Part")
		p.Name = pn
		p.Size = Vector3.new(d[1][1], d[1][2], d[1][3]) * scale
		p.CFrame = o * CFrame.new(Vector3.new(d[2][1], d[2][2], d[2][3]) * scale)
		p.Anchored = pn == "HumanoidRootPart"
		p.CanCollide = pn == "HumanoidRootPart"
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		if pn == "HumanoidRootPart" then p.Transparency = 1 end
		p.Parent = m
		parts[pn] = p
	end
	for _, j in ipairs(Rig.Joints) do
		local p0, p1 = parts[j.part0], parts[j.part1]
		local at = o * CFrame.new(Vector3.new(j.at[1], j.at[2], j.at[3]) * scale)
		local mt = Instance.new("Motor6D")
		mt.Name = j.name
		mt.Part0 = p0
		mt.Part1 = p1
		mt.C0 = p0.CFrame:Inverse() * at
		mt.C1 = p1.CFrame:Inverse() * at
		mt.Parent = p1
	end
	local h = Instance.new("Humanoid")
	h.RigType = Enum.HumanoidRigType.R15
	h.HipHeight = 2 * scale
	-- no floating name/health tag over generated rigs (games opt back in)
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.Parent = m
	m.PrimaryPart = parts.HumanoidRootPart
	m.WorldPivot = parts.HumanoidRootPart.CFrame
	return m, parts
end

return Rig
