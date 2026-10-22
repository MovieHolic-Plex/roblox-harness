--!strict
-- Building blocks for looks. Every preset returns a list of piece tables:
--   { attach = "<BodyPart>", size = {x,y,z}, pos = {x,y,z} (local to the body part), rot = {rx,ry,rz},
--     color = ..., material = ..., shape = "Block"|"Cylinder"|"Ball"|"Wedge", name = ... }
-- Coordinates are in body-part space at scale 1: Head is 1.2^3 centred at 0, front face at z = -0.6.
local Presets = {}

type Piece = { [string]: any }

local function P(attach: string, name: string, size: { number }, pos: { number }, color: any, extra: { [string]: any }?): Piece
	local t: Piece = { attach = attach, name = name, size = size, pos = pos, color = color }
	if extra then for k, v in pairs(extra) do t[k] = v end end
	return t
end
Presets.P = P

-- Convert a CFrame (body-part space) into the pos/rot fields pieces use.
local function fromCF(cf: CFrame): ({ number }, { number })
	local rx, ry, rz = cf:ToOrientation()
	local p = cf.Position
	return { p.X, p.Y, p.Z }, { math.deg(rx), math.deg(ry), math.deg(rz) }
end
Presets.fromCF = fromCF

-- Piece whose local +Y axis points along `dir`, centred `dist` along it from `origin`.
local function along(attach: string, name: string, size: { number }, origin: Vector3, dir: Vector3, dist: number, color: any, extra: { [string]: any }?): Piece
	local d = dir.Unit
	local up = Vector3.new(0, 1, 0)
	local axis = up:Cross(d)
	local cf
	if axis.Magnitude < 1e-6 then
		cf = CFrame.new(origin + d * dist)
	else
		cf = CFrame.new(origin + d * dist) * CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(up:Dot(d), -1, 1)))
	end
	local pos, rot = fromCF(cf)
	local t = P(attach, name, size, pos, color, extra)
	t.rot = rot
	return t
end

local HF = -0.6 -- head front plane

-- FACE --------------------------------------------------------------------------------
function Presets.face(o: any, skin: any): { Piece }
	o = o or {}
	local out = {}
	local eye = o.eyeColor or { 40, 30, 25 }
	local style = o.eyes or "round"
	local ey = o.eyeY or 0.08
	for i, s in ipairs({ -1, 1 }) do
		local side = i == 1 and "L" or "R"
		local x = s * 0.24
		if style == "closed" then
			table.insert(out, P("Head", "Eye" .. side, { 0.24, 0.04, 0.02 }, { x, ey, HF - 0.01 }, eye))
		else
			local h = style == "sharp" and 0.12 or 0.2
			table.insert(out, P("Head", "EyeWhite" .. side, { 0.24, h, 0.02 }, { x, ey, HF - 0.01 }, { 250, 250, 250 }))
			table.insert(out, P("Head", "Iris" .. side, { 0.13, h * 0.9, 0.02 }, { x - s * 0.02, ey - 0.01, HF - 0.02 }, eye))
			table.insert(out, P("Head", "Pupil" .. side, { 0.06, h * 0.45, 0.02 }, { x - s * 0.02, ey - 0.015, HF - 0.03 }, { 10, 10, 12 }))
			table.insert(out, P("Head", "Shine" .. side, { 0.04, 0.04, 0.02 }, { x - s * 0.06, ey + h * 0.2, HF - 0.04 }, { 255, 255, 255 }))
		end
		local tilt = (o.browTilt or (style == "sharp" and 18 or 6)) * s
		table.insert(out, P("Head", "Brow" .. side, { 0.28, 0.05, 0.03 }, { x, ey + 0.17, HF - 0.015 }, o.browColor or { 40, 30, 25 }, { rot = { 0, 0, tilt } }))
	end
	if o.nose ~= false then
		table.insert(out, P("Head", "Nose", { 0.07, 0.09, 0.05 }, { 0, -0.1, HF - 0.02 }, o.noseColor or skin))
	end
	local mouth = o.mouth or "smile"
	local my = -0.28
	if mouth == "grin" then
		table.insert(out, P("Head", "Mouth", { 0.36, 0.12, 0.02 }, { 0, my, HF - 0.01 }, { 110, 30, 30 }))
		table.insert(out, P("Head", "Teeth", { 0.32, 0.05, 0.02 }, { 0, my + 0.03, HF - 0.02 }, { 250, 250, 250 }))
	elseif mouth == "smile" then
		table.insert(out, P("Head", "Mouth", { 0.24, 0.04, 0.02 }, { 0, my, HF - 0.01 }, { 120, 45, 40 }))
		for _, s in ipairs({ -1, 1 }) do
			table.insert(out, P("Head", s < 0 and "MouthCornerL" or "MouthCornerR", { 0.06, 0.035, 0.02 }, { s * 0.13, my + 0.02, HF - 0.01 }, { 120, 45, 40 }, { rot = { 0, 0, s * 35 } }))
		end
	elseif mouth == "frown" then
		table.insert(out, P("Head", "Mouth", { 0.24, 0.04, 0.02 }, { 0, my, HF - 0.01 }, { 120, 45, 40 }))
		for _, s in ipairs({ -1, 1 }) do
			table.insert(out, P("Head", s < 0 and "MouthCornerL" or "MouthCornerR", { 0.06, 0.035, 0.02 }, { s * 0.13, my - 0.02, HF - 0.01 }, { 120, 45, 40 }, { rot = { 0, 0, -s * 35 } }))
		end
	else -- flat
		table.insert(out, P("Head", "Mouth", { 0.22, 0.035, 0.02 }, { 0, my, HF - 0.01 }, { 120, 45, 40 }))
	end
	if o.blush then
		for _, s in ipairs({ -1, 1 }) do
			table.insert(out, P("Head", s < 0 and "BlushL" or "BlushR", { 0.16, 0.06, 0.02 }, { s * 0.34, -0.1, HF - 0.01 }, o.blush, { transparency = 0.3 }))
		end
	end
	if o.scar then
		table.insert(out, P("Head", "Scar", { 0.03, 0.26, 0.02 }, { 0.24, -0.06, HF - 0.035 }, { 150, 60, 60 }, { rot = { 0, 0, 20 } }))
	end
	if o.whiskers then
		for _, s in ipairs({ -1, 1 }) do
			for k = 0, 2 do
				table.insert(out, P("Head", ("Whisker%s%d"):format(s < 0 and "L" or "R", k), { 0.18, 0.025, 0.02 }, { s * 0.38, -0.08 - k * 0.07, HF - 0.01 }, { 60, 40, 30 }, { rot = { 0, 0, s * (k - 1) * 10 } }))
			end
		end
	end
	return out
end

-- HAIR --------------------------------------------------------------------------------
-- All styles first lay a cap so the scalp never shows through gaps.
local function cap(col: any, out: { Piece }, front: number?)
	table.insert(out, P("Head", "HairCap", { 1.3, 0.38, 1.3 }, { 0, 0.5, 0.02 }, col))
	table.insert(out, P("Head", "HairBack", { 1.3, 0.9, 0.22 }, { 0, 0.1, 0.6 }, col))
	for _, s in ipairs({ -1, 1 }) do
		table.insert(out, P("Head", s < 0 and "SideburnL" or "SideburnR", { 0.14, 0.55, 0.9 }, { s * 0.64, 0.25, 0.1 + (front or 0) }, col))
	end
end

function Presets.hair(o: any): { Piece }
	local col = o.color or { 30, 25, 20 }
	local style = o.style or "short"
	local out: { Piece } = {}
	if style == "bald" then
		return out
	end
	cap(col, out)
	if style == "short" then
		for i = -2, 2 do
			table.insert(out, P("Head", "Fringe" .. (i + 3), { 0.26, 0.22, 0.12 }, { i * 0.24, 0.45, -0.62 }, col, { rot = { 0, 0, i * 4 } }))
		end
	elseif style == "spiky" then
		-- Two rows of spikes radiating out of the crown: the silhouette must read from any angle.
		local n = o.spikes or 7
		local hk = o.height or 1
		local origin = Vector3.new(0, 0.15, 0.08)
		for row, back in ipairs({ -0.15, 0.75 }) do
			local count = row == 1 and n or math.max(3, n - 2)
			for i = 1, count do
				local a = count == 1 and 0 or ((i - 1) / (count - 1) - 0.5) -- -0.5..0.5 across the head
				local side = a * 2.6
				local dir = Vector3.new(math.sin(side), math.cos(side) + 0.25, back + (row == 2 and math.abs(a) * 0.4 or 0))
				local len = hk * (row == 1 and (0.75 + 0.35 * math.cos(a * math.pi)) or 0.85)
				table.insert(out, along("Head", ("Spike%d_%02d"):format(row, i), { 0.36, len, 0.36 }, origin, dir, 0.55 + len * 0.42, col))
			end
		end
		for i = 1, 4 do
			local x = (i - 2.5) * 0.3
			table.insert(out, P("Head", ("Bang%02d"):format(i), { 0.24, 0.4, 0.12 }, { x, 0.42, -0.64 }, col, { rot = { -10, 0, (i % 2 == 0) and 14 or -14 } }))
		end
	elseif style == "long" then
		table.insert(out, P("Head", "LongBack", { 1.32, 1.6, 0.3 }, { 0, -0.35, 0.58 }, col))
		for _, s in ipairs({ -1, 1 }) do
			table.insert(out, P("Head", s < 0 and "LockL" or "LockR", { 0.2, 1.2, 0.3 }, { s * 0.62, -0.2, -0.38 }, col))
		end
		for i = -2, 2 do
			table.insert(out, P("Head", "Fringe" .. (i + 3), { 0.27, 0.3, 0.12 }, { i * 0.24, 0.42, -0.62 }, col))
		end
	elseif style == "ponytail" then
		for i = -2, 2 do
			table.insert(out, P("Head", "Fringe" .. (i + 3), { 0.26, 0.24, 0.12 }, { i * 0.24, 0.44, -0.62 }, col))
		end
		table.insert(out, P("Head", "TailTie", { 0.3, 0.3, 0.2 }, { 0, 0.35, 0.78 }, o.tieColor or { 180, 40, 40 }, { shape = "Cylinder", rot = { 0, 90, 0 } }))
		table.insert(out, P("Head", "Tail", { 0.36, 1.2, 0.36 }, { 0, -0.3, 0.95 }, col, { rot = { 20, 0, 0 } }))
	elseif style == "afro" then
		table.insert(out, P("Head", "Afro", { 1.9, 1.9, 1.9 }, { 0, 0.55, 0.1 }, col, { shape = "Ball" }))
	end
	return out
end

-- ACCESSORIES ---------------------------------------------------------------------------
function Presets.accessory(o: any): { Piece }
	local t = o.type
	local c = o.color
	if t == "strawHat" then
		return {
			P("Head", "HatBrim", { 0.07, 2.5, 2.5 }, { 0, 0.66, 0.02 }, c or { 240, 205, 120 }, { shape = "Cylinder", rot = { 0, 0, 90 }, material = "SmoothPlastic" }),
			P("Head", "HatCrown", { 0.42, 1.36, 1.36 }, { 0, 0.88, 0.02 }, c or { 240, 205, 120 }, { shape = "Cylinder", rot = { 0, 0, 90 }, material = "SmoothPlastic" }),
			P("Head", "HatTop", { 0.12, 1.2, 1.2 }, { 0, 1.1, 0.02 }, c or { 240, 205, 120 }, { shape = "Cylinder", rot = { 0, 0, 90 }, material = "SmoothPlastic" }),
			P("Head", "HatBand", { 0.14, 1.39, 1.39 }, { 0, 0.76, 0.02 }, o.bandColor or { 200, 30, 30 }, { shape = "Cylinder", rot = { 0, 0, 90 } }),
		}
	elseif t == "headband" then
		local out = {
			P("Head", "Band", { 1.34, 0.2, 1.34 }, { 0, 0.32, 0 }, c or { 30, 40, 90 }, { material = "Fabric" }),
			P("Head", "Plate", { 0.7, 0.26, 0.05 }, { 0, 0.32, -0.69 }, o.plateColor or { 190, 195, 205 }, { material = "Metal" }),
			P("Head", "Knot", { 0.2, 0.2, 0.1 }, { 0, 0.32, 0.7 }, c or { 30, 40, 90 }),
		}
		for _, s in ipairs({ -1, 1 }) do
			table.insert(out, P("Head", s < 0 and "TailL" or "TailR", { 0.12, 0.5, 0.04 }, { s * 0.14, 0.05, 0.74 }, c or { 30, 40, 90 }, { rot = { 15, 0, s * 15 } }))
		end
		return out
	elseif t == "scarf" then
		return {
			P("UpperTorso", "ScarfRing", { 1.5, 0.3, 1.2 }, { 0, 0.75, 0 }, c or { 200, 40, 40 }, { material = "Fabric" }),
			P("UpperTorso", "ScarfTail", { 0.35, 1.0, 0.1 }, { 0.45, 0.2, 0.62 }, c or { 200, 40, 40 }, { material = "Fabric", rot = { 10, 0, -8 } }),
		}
	elseif t == "cape" then
		return {
			P("UpperTorso", "CapeClasp", { 2.1, 0.22, 0.25 }, { 0, 0.7, 0.45 }, o.claspColor or { 230, 180, 60 }, { material = "Metal" }),
			P("UpperTorso", "Cape", { 2.1, 3.1, 0.08 }, { 0, -0.8, 0.66 }, c or { 235, 235, 238 }, { material = "SmoothPlastic", rot = { -7, 0, 0 } }),
			P("UpperTorso", "CapeHem", { 2.14, 0.12, 0.1 }, { 0, -2.33, 0.86 }, o.hemColor or c or { 235, 235, 238 }, { material = "SmoothPlastic", rot = { -7, 0, 0 } }),
		}
	elseif t == "belt" then
		return {
			P("LowerTorso", "Belt", { 2.06, 0.3, 1.06 }, { 0, 0.05, 0 }, c or { 60, 40, 30 }, { material = "SmoothPlastic" }),
			P("LowerTorso", "Buckle", { 0.36, 0.26, 0.06 }, { 0, 0.05, -0.55 }, o.buckleColor or { 230, 180, 60 }, { material = "Metal" }),
		}
	elseif t == "shoulderPads" then
		local out = {}
		for _, s in ipairs({ -1, 1 }) do
			local part = s < 0 and "LeftUpperArm" or "RightUpperArm"
			table.insert(out, P(part, "Pad", { 1.25, 0.35, 1.2 }, { s * 0.05, 0.42, 0 }, c or { 120, 120, 130 }, { material = "Metal", rot = { 0, 0, -s * 12 } }))
		end
		return out
	elseif t == "glasses" then
		local out = { P("Head", "Bridge", { 0.12, 0.04, 0.02 }, { 0, 0.1, -0.64 }, c or { 30, 30, 30 }) }
		for _, s in ipairs({ -1, 1 }) do
			table.insert(out, P("Head", s < 0 and "LensL" or "LensR", { 0.32, 0.24, 0.03 }, { s * 0.24, 0.08, -0.645 }, o.lensColor or { 120, 200, 255 }, { transparency = 0.35, material = "Glass" }))
		end
		return out
	elseif t == "backpack" then
		return {
			P("UpperTorso", "Pack", { 1.4, 1.3, 0.6 }, { 0, -0.05, 0.8 }, c or { 70, 110, 60 }, { material = "Fabric" }),
			P("UpperTorso", "PackFlap", { 1.42, 0.4, 0.62 }, { 0, 0.45, 0.8 }, o.flapColor or { 50, 80, 45 }, { material = "Fabric" }),
		}
	end
	return {}
end
Presets.AccessoryTypes = { strawHat = true, headband = true, scarf = true, cape = true, belt = true, shoulderPads = true, glasses = true, backpack = true }

-- WEAPONS (held in a hand; local hand space: hand bottom at y = -0.15, blade points -Z/forward or +Y/up) --
function Presets.weapon(o: any): { Piece }
	local hand = (o.hand or "Right") .. "Hand"
	local t = o.type
	local c = o.color
	if t == "katana" then
		-- Held in the fist, blade raised forward/up 50 degrees (reads as a sword, not a stick).
		local len = o.length or 3.2
		local g = CFrame.new(0, -0.05, 0) * CFrame.Angles(math.rad(o.angle or 50), 0, 0)
		local function at(name: string, size: { number }, z: number, color: any, extra: { [string]: any }?): Piece
			local pos, rot = fromCF(g * CFrame.new(0, 0, z))
			local q = P(hand, name, size, pos, color, extra)
			q.rot = rot
			return q
		end
		return {
			at("Grip", { 0.18, 0.18, 0.9 }, 0.1, o.gripColor or { 30, 30, 35 }, { material = "Fabric" }),
			at("Pommel", { 0.22, 0.22, 0.08 }, 0.57, o.guardColor or { 200, 165, 70 }, { material = "Metal" }),
			at("Guard", { 0.5, 0.5, 0.07 }, -0.38, o.guardColor or { 200, 165, 70 }, { material = "Metal" }),
			at("Blade", { 0.06, 0.18, len }, -0.42 - len / 2, c or { 225, 230, 240 }, { material = "Metal", reflectance = 0.25 }),
			at("Edge", { 0.07, 0.04, len }, -0.42 - len / 2, { 250, 252, 255 }, { material = "Neon", transparency = 0.6 }),
		}
	elseif t == "staff" then
		local len = o.length or 5
		return {
			P(hand, "Shaft", { 0.2, len, 0.2 }, { 0, len * 0.2, 0 }, c or { 120, 80, 50 }, { material = "Wood", shape = "Block" }),
			P(hand, "CapTop", { 0.34, 0.34, 0.34 }, { 0, len * 0.7, 0 }, o.capColor or { 230, 180, 60 }, { material = "Metal", shape = "Ball" }),
		}
	elseif t == "shield" then
		return {
			P(hand, "Shield", { 0.2, 1.8, 1.8 }, { (o.hand == "Left" and -0.6 or 0.6), 0.6, 0 }, c or { 160, 40, 40 }, { shape = "Cylinder", material = "Metal" }),
			P(hand, "Boss", { 0.3, 0.5, 0.5 }, { (o.hand == "Left" and -0.75 or 0.75), 0.6, 0 }, o.bossColor or { 220, 200, 120 }, { shape = "Cylinder", material = "Metal" }),
		}
	elseif t == "hammer" then
		return {
			P(hand, "Handle", { 0.2, 2.6, 0.2 }, { 0, 0.6, 0 }, o.gripColor or { 110, 75, 45 }, { material = "Wood" }),
			P(hand, "Head", { 1.2, 0.7, 0.7 }, { 0, 2.0, 0 }, c or { 130, 130, 140 }, { material = "Metal" }),
		}
	elseif t == "kunai" then
		return {
			P(hand, "Ring", { 0.05, 0.22, 0.22 }, { 0, -0.1, 0.42 }, { 60, 60, 65 }, { shape = "Cylinder", rot = { 0, 90, 0 } }),
			P(hand, "Grip", { 0.12, 0.12, 0.5 }, { 0, -0.1, 0.1 }, o.gripColor or { 40, 40, 45 }),
			P(hand, "Blade", { 0.05, 0.22, 0.6 }, { 0, -0.1, -0.45 }, c or { 160, 165, 175 }, { material = "Metal" }),
		}
	end
	return {}
end
Presets.WeaponTypes = { katana = true, staff = true, shield = true, hammer = true, kunai = true }
Presets.HairStyles = { bald = true, short = true, spiky = true, long = true, ponytail = true, afro = true }
Presets.EyeStyles = { round = true, sharp = true, closed = true }
Presets.MouthStyles = { smile = true, grin = true, frown = true, flat = true }

return Presets
