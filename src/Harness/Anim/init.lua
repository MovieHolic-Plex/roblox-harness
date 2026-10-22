--!strict
-- Keyframe animation authoring helper.
--   spec = { name = "Wave", length = 1.2, loop = true, priority = "Action",
--            keys = { { t = 0, poses = { RightUpperArm = { rot = {0, 0, 120} } } },
--                     { t = 0.6, ease = "Cubic", dir = "InOut", poses = { ... } } },
--            markers = { { t = 0.3, name = "Hit", value = "fist" } } }
--   Anim.validate(spec) -> ok, errs
--   Anim.toKeyframeSequence(spec) -> KeyframeSequence (save it, or upload with the Animation Editor)
--   Anim.sample(spec, "RightUpperArm", t) -> CFrame (pure; same easing maths as Roblox for the
--                                              supported styles) — use for tests and previews
--   Anim.apply(model, spec, t, mode) -> poses a rig built by Harness.Character (mode "Transform"|"C0")
--   Anim.mirror(poses) -> left/right swapped copy of a poses table
local Util = require(script.Parent.Util)
local Rig = require(script.Parent.Character.Rig)

local Anim = {}

Anim.Easing = { Linear = true, Constant = true, Cubic = true, Bounce = true, Elastic = true }
Anim.Directions = { In = true, Out = true, InOut = true }
local PRIORITIES = { Core = true, Idle = true, Movement = true, Action = true, Action2 = true, Action3 = true, Action4 = true }
local ROOT = { name = true, length = true, loop = true, priority = true, keys = true, markers = true }
local KEY = { t = true, ease = true, dir = true, poses = true, name = true }
local POSE = { rot = true, pos = true, ease = true, dir = true }

function Anim.validate(spec: any): (boolean, { string })
	local errs: Util.Errors = {}
	if type(spec) ~= "table" then return false, { "spec: must be a table" } end
	Util.checkKeys(errs, "spec", spec, ROOT)
	if type(spec.name) ~= "string" or spec.name == "" then Util.err(errs, "spec.name", "is required") end
	local len = spec.length
	if not Util.isFiniteNumber(len) or len <= 0 or len > 60 then
		Util.err(errs, "spec.length", "must be a number in (0, 60]")
		len = math.huge
	end
	if spec.loop ~= nil and type(spec.loop) ~= "boolean" then Util.err(errs, "spec.loop", "must be a boolean") end
	if spec.priority ~= nil and not PRIORITIES[spec.priority] then Util.err(errs, "spec.priority", "unknown AnimationPriority") end
	if type(spec.keys) ~= "table" or #spec.keys == 0 then
		Util.err(errs, "spec.keys", "needs at least one keyframe")
		return false, errs
	end
	local last = -1
	for i, k in ipairs(spec.keys) do
		local p = ("spec.keys[%d]"):format(i)
		if type(k) ~= "table" then Util.err(errs, p, "must be a table"); continue end
		Util.checkKeys(errs, p, k, KEY)
		if not Util.isFiniteNumber(k.t) or k.t < 0 or k.t > len then
			Util.err(errs, p .. ".t", "must be within 0..length")
		elseif k.t <= last then
			Util.err(errs, p .. ".t", ("keys must be strictly increasing in time (%.3f after %.3f)"):format(k.t, last))
		else
			last = k.t
		end
		if k.ease ~= nil and not Anim.Easing[k.ease] then Util.err(errs, p .. ".ease", "unknown easing style") end
		if k.dir ~= nil and not Anim.Directions[k.dir] then Util.err(errs, p .. ".dir", "unknown easing direction") end
		if type(k.poses) ~= "table" then Util.err(errs, p .. ".poses", "must be a table of part -> pose"); continue end
		for part, pose in pairs(k.poses) do
			local pp = p .. ".poses." .. tostring(part)
			if not Rig.Parts[part :: any] then Util.err(errs, pp, "unknown R15 part"); continue end
			if type(pose) ~= "table" then Util.err(errs, pp, "must be { rot =, pos = }"); continue end
			Util.checkKeys(errs, pp, pose, POSE)
			if pose.rot ~= nil then Util.checkVec3(errs, pp .. ".rot", pose.rot) end
			if pose.pos ~= nil then Util.checkVec3(errs, pp .. ".pos", pose.pos) end
			if pose.ease ~= nil and not Anim.Easing[pose.ease] then Util.err(errs, pp .. ".ease", "unknown easing style") end
			if pose.dir ~= nil and not Anim.Directions[pose.dir] then Util.err(errs, pp .. ".dir", "unknown easing direction") end
		end
	end
	if spec.markers ~= nil then
		if type(spec.markers) ~= "table" then Util.err(errs, "spec.markers", "must be a list") else
			for i, m in ipairs(spec.markers) do
				local p = ("spec.markers[%d]"):format(i)
				if type(m) ~= "table" or type(m.name) ~= "string" or m.name == "" then Util.err(errs, p, "needs a name"); continue end
				if not Util.isFiniteNumber(m.t) or m.t < 0 or m.t > len then Util.err(errs, p .. ".t", "must be within 0..length") end
				if m.value ~= nil and type(m.value) ~= "string" then Util.err(errs, p .. ".value", "must be a string") end
			end
		end
	end
	return #errs == 0, errs
end

local function poseCF(pose: any): CFrame
	local cf = CFrame.new(Util.vec(pose.pos))
	if pose.rot then
		cf = cf * CFrame.fromOrientation(math.rad(pose.rot[1]), math.rad(pose.rot[2]), math.rad(pose.rot[3]))
	end
	return cf
end
Anim.poseCFrame = poseCF

-- Easing (alpha 0..1 -> 0..1). Matches the shapes Roblox uses for PoseEasingStyle.
local function bounceOut(x: number): number
	local n, d = 7.5625, 2.75
	if x < 1 / d then return n * x * x
	elseif x < 2 / d then x -= 1.5 / d; return n * x * x + 0.75
	elseif x < 2.5 / d then x -= 2.25 / d; return n * x * x + 0.9375
	else x -= 2.625 / d; return n * x * x + 0.984375 end
end
local function elasticOut(x: number): number
	if x == 0 or x == 1 then return x end
	return 2 ^ (-10 * x) * math.sin((x * 10 - 0.75) * (2 * math.pi) / 3) + 1
end
local OUT = {
	Linear = function(x: number) return x end,
	Constant = function(x: number) return x >= 1 and 1 or 0 end,
	Cubic = function(x: number) return 1 - (1 - x) ^ 3 end,
	Bounce = bounceOut,
	Elastic = elasticOut,
}
function Anim.ease(style: string, dir: string, x: number): number
	x = math.clamp(x, 0, 1)
	if style == "Linear" or style == "Constant" then return OUT[style](x) end
	local f = OUT[style] or OUT.Linear
	if dir == "Out" then return f(x)
	elseif dir == "In" then return 1 - f(1 - x)
	else
		if x < 0.5 then return (1 - f(1 - 2 * x)) / 2 end
		return (1 + f(2 * x - 1)) / 2
	end
end

-- Pure sampling of one part's pose at time t. Keys without that part are skipped
-- (like Roblox, which interpolates between the keyframes that contain a Pose for it).
function Anim.sample(spec: any, part: string, t: number): CFrame
	local keys = spec.keys
	local len = spec.length
	if spec.loop and len > 0 then
		t = t % len
	else
		t = math.clamp(t, 0, len)
	end
	local prev, nxt
	for _, k in ipairs(keys) do
		local p = k.poses[part]
		if p then
			if k.t <= t then prev = k else nxt = k; break end
		end
	end
	if not prev and not nxt then return CFrame.new() end
	if not prev then return poseCF((nxt :: any).poses[part]) end
	if not nxt then return poseCF(prev.poses[part]) end
	local pp = prev.poses[part]
	-- Roblox semantics: the easing of the *previous* keyframe's pose controls the segment.
	local style = pp.ease or prev.ease or "Linear"
	local dir = pp.dir or prev.dir or "InOut"
	local a = Anim.ease(style, dir, (t - prev.t) / (nxt.t - prev.t))
	return poseCF(pp):Lerp(poseCF(nxt.poses[part]), a)
end

local EASE_DIR = { In = "In", Out = "Out", InOut = "InOut" }

function Anim.toKeyframeSequence(spec: any): KeyframeSequence
	local ok, errs = Anim.validate(spec)
	if not ok then Util.raise("animation", errs) end
	local ks = Instance.new("KeyframeSequence")
	ks.Name = spec.name
	ks.Loop = spec.loop == true
	ks.Priority = (Enum.AnimationPriority :: any)[spec.priority or "Action"]
	for i, k in ipairs(spec.keys) do
		local kf = Instance.new("Keyframe")
		kf.Name = k.name or ("Key%02d"):format(i)
		kf.Time = k.t
		local made: { [string]: Pose } = {}
		local function ensure(part: string): Instance
			if made[part] then return made[part] end
			local parentName = Rig.ParentOf[part]
			local parent: Instance = parentName and ensure(parentName) or kf
			local pose = Instance.new("Pose")
			pose.Name = part
			pose.Weight = 0 -- structural; real poses below set weight 1
			pose.Parent = parent
			made[part] = pose
			return pose
		end
		-- deterministic creation order: R15 order, not pairs()
		for _, part in ipairs(Rig.Order) do
			local pd = k.poses[part]
			if pd then
				local pose = ensure(part) :: Pose
				pose.Weight = 1
				pose.CFrame = poseCF(pd)
				pose.EasingStyle = (Enum.PoseEasingStyle :: any)[pd.ease or k.ease or "Linear"]
				pose.EasingDirection = (Enum.PoseEasingDirection :: any)[EASE_DIR[pd.dir or k.dir or "InOut"]]
			end
		end
		kf.Parent = ks
	end
	if spec.length > spec.keys[#spec.keys].t then
		-- Roblox derives the clip length from the last keyframe: pad with an empty one.
		local endk = Instance.new("Keyframe")
		endk.Name = "End"
		endk.Time = spec.length
		endk.Parent = ks
	end
	for i, m in ipairs(spec.markers or {}) do
		local kf = Instance.new("Keyframe")
		kf.Name = ("Marker%02d_%s"):format(i, m.name)
		kf.Time = m.t
		local mk = Instance.new("KeyframeMarker")
		mk.Name = m.name
		mk.Value = m.value or ""
		mk.Parent = kf
		kf.Parent = ks
	end
	return ks
end

local function findMotor(model: Instance, part: string): Motor6D?
	local p = model:FindFirstChild(part)
	if not p then return nil end
	for _, c in ipairs(p:GetChildren()) do
		if c:IsA("Motor6D") and c.Part1 == p then return c end
	end
	return nil
end

-- Pose a rig at time t. mode "Transform" (runtime, default) or "C0" (edit-mode previews; stores
-- the rest C0 in an attribute so repeated calls never accumulate).
function Anim.apply(model: Instance, spec: any, t: number, mode: string?)
	for _, part in ipairs(Rig.Order) do
		local m = findMotor(model, part)
		if m then
			local cf = Anim.sample(spec, part, t)
			if mode == "C0" then
				local rest = m:GetAttribute("RestC0") :: CFrame?
				if rest == nil then
					rest = m.C0
					m:SetAttribute("RestC0", rest)
				end
				m.C0 = (rest :: CFrame) * cf
			else
				m.Transform = cf
			end
		end
	end
end

-- Swap Left*/Right* and mirror across the YZ plane (negate Y and Z rotation, X position).
function Anim.mirror(poses: { [string]: any }): { [string]: any }
	local out = {}
	for part, p in pairs(poses) do
		local name = part
		if string.sub(part, 1, 4) == "Left" then name = "Right" .. string.sub(part, 5)
		elseif string.sub(part, 1, 5) == "Right" then name = "Left" .. string.sub(part, 6) end
		local q = table.clone(p)
		if p.rot then q.rot = { p.rot[1], -p.rot[2], -p.rot[3] } end
		if p.pos then q.pos = { -p.pos[1], p.pos[2], p.pos[3] } end
		out[name] = q
	end
	return out
end

return Anim
