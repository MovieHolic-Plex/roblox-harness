--!strict
-- Character generation harness: spec -> blocky R15 Model with a welded look.
--   local Character = require(Harness.Character)
--   local model = Character.build(spec, { origin = CFrame.new(0, 0, 0) })
-- Spec fields:
--   name, scale (0.25..4), skin,
--   outfit = { shirt, pants, shoes, gloves, sleeves = "none"|"short"|"long", legs = "long"|"shorts" },
--   face = { eyes, eyeColor, browColor, browTilt, mouth, blush, scar, whiskers, nose },
--   hair = { style, color, spikes, height, tieColor },
--   accessories = { { type, color, ... } }, weapons = { { type, hand, color, length, ... } },
--   pieces = { { attach, size, pos, rot, color, material, shape, name, transparency } }  -- custom parts
local Util = require(script.Parent.Util)
local Rig = require(script.Rig)
local Presets = require(script.Presets)

local Character = {}
Character.Rig = Rig
Character.Presets = Presets
Character.Limits = { maxPieces = 1500 }

local ROOT = { name = true, scale = true, skin = true, outfit = true, face = true, hair = true, accessories = true, weapons = true, pieces = true, version = true }
local OUTFIT = { shirt = true, pants = true, shoes = true, gloves = true, sleeves = true, legs = true }
local FACE = { eyes = true, eyeColor = true, browColor = true, browTilt = true, mouth = true, blush = true, scar = true, whiskers = true, nose = true, noseColor = true, eyeY = true }
local HAIR = { style = true, color = true, spikes = true, height = true, tieColor = true }
local PIECE = { attach = true, size = true, pos = true, rot = true, color = true, material = true, shape = true, name = true, transparency = true, reflectance = true }
local SHAPES = { Block = true, Cylinder = true, Ball = true, Wedge = true }

local function checkPiece(errs: Util.Errors, path: string, p: any)
	if type(p) ~= "table" then Util.err(errs, path, "piece must be a table"); return end
	Util.checkKeys(errs, path, p, PIECE)
	if not Rig.isBodyPart(p.attach) then
		Util.err(errs, path .. ".attach", ("unknown body part %q"):format(tostring(p.attach)))
	end
	Util.checkVec3(errs, path .. ".size", p.size, { positive = true, max = 64 })
	if p.pos ~= nil then Util.checkVec3(errs, path .. ".pos", p.pos) end
	if p.rot ~= nil then Util.checkVec3(errs, path .. ".rot", p.rot) end
	if p.color == nil then Util.err(errs, path .. ".color", "is required") else Util.checkColor(errs, path .. ".color", p.color) end
	if p.material ~= nil and not Util.enumHas(Enum.Material, p.material) then Util.err(errs, path .. ".material", "unknown material") end
	if p.shape ~= nil and not SHAPES[p.shape] then Util.err(errs, path .. ".shape", "must be Block, Cylinder, Ball or Wedge") end
	if p.name ~= nil and (type(p.name) ~= "string" or p.name == "") then Util.err(errs, path .. ".name", "must be a non-empty string") end
	for _, f in ipairs({ "transparency", "reflectance" }) do
		if p[f] ~= nil and (not Util.isFiniteNumber(p[f]) or p[f] < 0 or p[f] > 1) then Util.err(errs, path .. "." .. f, "must be in 0..1") end
	end
	if p.pos and type(p.pos) == "table" then
		for i = 1, 3 do
			if Util.isFiniteNumber(p.pos[i]) and math.abs(p.pos[i]) > 20 then
				Util.err(errs, path .. ".pos", "offset more than 20 studs from its body part (typo?)")
				break
			end
		end
	end
end

local function enumField(errs: Util.Errors, path: string, v: any, set: { [string]: boolean })
	if v ~= nil and (type(v) ~= "string" or not set[v]) then
		local names = {}
		for k in pairs(set) do table.insert(names, k) end
		table.sort(names)
		Util.err(errs, path, ("must be one of %s"):format(table.concat(names, ", ")))
	end
end

local function list(errs: Util.Errors, path: string, v: any, each: (string, any) -> ())
	if v == nil then return end
	if type(v) ~= "table" then Util.err(errs, path, "must be a list"); return end
	for k in pairs(v) do
		if type(k) ~= "number" then Util.err(errs, path, "must be a list (found key " .. tostring(k) .. ")"); return end
	end
	for i, x in ipairs(v) do each(("%s[%d]"):format(path, i), x) end
end

function Character.validate(spec: any): (boolean, { string })
	local errs: Util.Errors = {}
	if type(spec) ~= "table" then return false, { "spec: must be a table" } end
	Util.checkKeys(errs, "spec", spec, ROOT)
	if type(spec.name) ~= "string" or spec.name == "" then Util.err(errs, "spec.name", "is required (non-empty string)") end
	if spec.scale ~= nil and (not Util.isFiniteNumber(spec.scale) or spec.scale < 0.25 or spec.scale > 4) then
		Util.err(errs, "spec.scale", "must be in 0.25..4")
	end
	if spec.skin ~= nil then Util.checkColor(errs, "spec.skin", spec.skin) end
	if spec.outfit ~= nil then
		local o = spec.outfit
		if type(o) ~= "table" then Util.err(errs, "spec.outfit", "must be a table") else
			Util.checkKeys(errs, "spec.outfit", o, OUTFIT)
			for _, k in ipairs({ "shirt", "pants", "shoes", "gloves" }) do
				if o[k] ~= nil then Util.checkColor(errs, "spec.outfit." .. k, o[k]) end
			end
			enumField(errs, "spec.outfit.sleeves", o.sleeves, { none = true, short = true, long = true })
			enumField(errs, "spec.outfit.legs", o.legs, { long = true, shorts = true })
		end
	end
	if spec.face ~= nil then
		local f = spec.face
		if type(f) ~= "table" then Util.err(errs, "spec.face", "must be a table") else
			Util.checkKeys(errs, "spec.face", f, FACE)
			enumField(errs, "spec.face.eyes", f.eyes, Presets.EyeStyles)
			enumField(errs, "spec.face.mouth", f.mouth, Presets.MouthStyles)
			for _, k in ipairs({ "eyeColor", "browColor", "noseColor" }) do
				if f[k] ~= nil then Util.checkColor(errs, "spec.face." .. k, f[k]) end
			end
			if f.blush ~= nil then Util.checkColor(errs, "spec.face.blush", f.blush) end
			if f.browTilt ~= nil and (not Util.isFiniteNumber(f.browTilt) or math.abs(f.browTilt) > 45) then Util.err(errs, "spec.face.browTilt", "must be in -45..45") end
			if f.eyeY ~= nil and (not Util.isFiniteNumber(f.eyeY) or math.abs(f.eyeY) > 0.4) then Util.err(errs, "spec.face.eyeY", "must be in -0.4..0.4") end
			for _, k in ipairs({ "scar", "whiskers" }) do
				if f[k] ~= nil and type(f[k]) ~= "boolean" then Util.err(errs, "spec.face." .. k, "must be a boolean") end
			end
			if f.nose ~= nil and f.nose ~= false then Util.err(errs, "spec.face.nose", "only `false` (hide nose) is accepted") end
		end
	end
	if spec.hair ~= nil then
		local h = spec.hair
		if type(h) ~= "table" then Util.err(errs, "spec.hair", "must be a table") else
			Util.checkKeys(errs, "spec.hair", h, HAIR)
			enumField(errs, "spec.hair.style", h.style, Presets.HairStyles)
			if h.color ~= nil then Util.checkColor(errs, "spec.hair.color", h.color) end
			if h.tieColor ~= nil then Util.checkColor(errs, "spec.hair.tieColor", h.tieColor) end
			if h.spikes ~= nil and (type(h.spikes) ~= "number" or h.spikes ~= math.floor(h.spikes) or h.spikes < 1 or h.spikes > 24) then Util.err(errs, "spec.hair.spikes", "must be an integer 1..24") end
			if h.height ~= nil and (not Util.isFiniteNumber(h.height) or h.height <= 0 or h.height > 4) then Util.err(errs, "spec.hair.height", "must be in (0, 4]") end
		end
	end
	list(errs, "spec.accessories", spec.accessories, function(path, a)
		if type(a) ~= "table" then Util.err(errs, path, "must be a table"); return end
		enumField(errs, path .. ".type", a.type, Presets.AccessoryTypes)
		if a.type == nil then Util.err(errs, path .. ".type", "is required") end
		for k, v in pairs(a) do
			if type(k) == "string" and string.find(k, "[Cc]olor$") then Util.checkColor(errs, path .. "." .. k, v) end
		end
	end)
	list(errs, "spec.weapons", spec.weapons, function(path, w)
		if type(w) ~= "table" then Util.err(errs, path, "must be a table"); return end
		enumField(errs, path .. ".type", w.type, Presets.WeaponTypes)
		if w.type == nil then Util.err(errs, path .. ".type", "is required") end
		enumField(errs, path .. ".hand", w.hand, { Left = true, Right = true })
		if w.length ~= nil and (not Util.isFiniteNumber(w.length) or w.length <= 0 or w.length > 12) then Util.err(errs, path .. ".length", "must be in (0, 12]") end
		for k, v in pairs(w) do
			if type(k) == "string" and string.find(k, "[Cc]olor$") then Util.checkColor(errs, path .. "." .. k, v) end
		end
	end)
	local nPieces = 0
	list(errs, "spec.pieces", spec.pieces, function(path, p)
		nPieces += 1
		checkPiece(errs, path, p)
	end)
	if nPieces > Character.Limits.maxPieces then
		Util.err(errs, "spec.pieces", ("%d custom pieces exceeds limit %d"):format(nPieces, Character.Limits.maxPieces))
	end
	return #errs == 0, errs
end

-- Expand a spec into the flat, ordered list of look pieces (pure data; handy for tests and tools).
function Character.pieces(spec: any): { { [string]: any } }
	local out = {}
	local skin = spec.skin or "skin"
	local function add(items: { any }, group: string)
		for _, p in ipairs(items) do
			local q = table.clone(p)
			q.group = group
			table.insert(out, q)
		end
	end
	add(Presets.face(spec.face, skin), "Face")
	if spec.hair then add(Presets.hair(spec.hair), "Hair") end
	for i, a in ipairs(spec.accessories or {}) do add(Presets.accessory(a), ("Acc%02d_%s"):format(i, a.type)) end
	for i, w in ipairs(spec.weapons or {}) do add(Presets.weapon(w), ("Weapon%02d_%s"):format(i, w.type)) end
	add(spec.pieces or {}, "Custom")
	return out
end

local function bodyColors(spec: any): { [string]: any }
	local o = spec.outfit or {}
	local skin = spec.skin or "skin"
	local shirt, pants = o.shirt or { 200, 200, 200 }, o.pants or { 60, 70, 110 }
	local c: { [string]: any } = { Head = skin, UpperTorso = shirt, LowerTorso = pants }
	local sleeves, legs = o.sleeves or "short", o.legs or "long"
	if sleeves == "none" then shirt = skin end
	for _, s in ipairs({ "Left", "Right" }) do
		c[s .. "UpperArm"] = (sleeves == "none") and skin or shirt
		c[s .. "LowerArm"] = (sleeves == "long") and shirt or skin
		c[s .. "Hand"] = o.gloves or skin
		c[s .. "UpperLeg"] = pants
		c[s .. "LowerLeg"] = (legs == "shorts") and skin or pants
		c[s .. "Foot"] = o.shoes or { 40, 35, 35 }
	end
	return c
end

export type BuildOpts = { origin: CFrame?, anchored: boolean? }

function Character.build(spec: any, opts: BuildOpts?): Model
	local ok, errs = Character.validate(spec)
	if not ok then Util.raise("character", errs) end
	local scale = spec.scale or 1
	local o: BuildOpts = opts or ({} :: BuildOpts)
	local model, parts = Rig.build(spec.name, scale, o.origin)
	local colors = bodyColors(spec)
	for name, col in pairs(colors) do
		local bp = parts[name]
		if bp then bp.Color = Util.color(col) end
	end
	local look = Instance.new("Folder")
	look.Name = "Look"
	look.Parent = model
	local groups: { [string]: Instance } = {}
	local used: { [string]: number } = {}
	local count = 0
	for _, p in ipairs(Character.pieces(spec)) do
		local g: Instance? = groups[p.group]
		if g == nil then
			local f = Instance.new("Folder")
			f.Name = p.group
			f.Parent = look
			groups[p.group] = f
			g = f
		end
		local bp = parts[p.attach]
		local cls = p.shape == "Wedge" and "WedgePart" or "Part"
		local part = Instance.new(cls) :: BasePart
		local base = p.name or "Piece"
		used[p.group .. base] = (used[p.group .. base] or 0) + 1
		part.Name = used[p.group .. base] > 1 and (base .. used[p.group .. base]) or base
		part.Size = Util.vec(p.size) * scale
		if cls == "Part" and p.shape and p.shape ~= "Block" then (part :: Part).Shape = (Enum.PartType :: any)[p.shape] end
		part.Color = Util.color(p.color)
		part.Material = p.material and (Enum.Material :: any)[p.material] or Enum.Material.SmoothPlastic
		part.Transparency = p.transparency or 0
		part.Reflectance = p.reflectance or 0
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = false
		part.CastShadow = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local rel = CFrame.new(Util.vec(p.pos) * scale)
		if p.rot then rel = rel * CFrame.fromOrientation(math.rad(p.rot[1]), math.rad(p.rot[2]), math.rad(p.rot[3])) end
		part.CFrame = bp.CFrame * rel
		local w = Instance.new("Weld")
		w.Name = "LookWeld"
		w.Part0 = bp
		w.Part1 = part
		w.C0 = rel
		w.C1 = CFrame.new()
		w.Parent = part
		part:SetAttribute("Attach", p.attach)
		part.Parent = g :: Instance
		count += 1
	end
	model:SetAttribute("LookPieces", count)
	model:SetAttribute("HarnessScale", scale)
	if o.anchored then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then d.Anchored = true end
		end
	end
	return model
end

return Character
