--!strict
-- Shared helpers: spec errors, colors, vectors, CFrames, deterministic RNG.
-- Works in Roblox (Studio/runtime) and in Lune (via the @lune/roblox globals).
local Util = {}

-- Roblox clamps BasePart sizes to 2048 studs per axis.
Util.MAX_PART_SIZE = 2048

export type Errors = { string }

local HEX = "^#?(%x%x)(%x%x)(%x%x)$"

Util.Palette = {
	white = { 245, 245, 245 }, black = { 20, 20, 24 }, red = { 196, 40, 28 }, green = { 75, 151, 75 },
	blue = { 13, 105, 172 }, yellow = { 245, 205, 48 }, orange = { 218, 133, 65 }, brown = { 105, 64, 40 },
	grey = { 120, 120, 125 }, gray = { 120, 120, 125 }, wood = { 160, 110, 70 }, stone = { 130, 128, 120 },
	grass = { 92, 140, 60 }, snow = { 235, 240, 250 }, gold = { 230, 180, 60 }, skin = { 234, 184, 146 },
	purple = { 110, 60, 160 }, pink = { 240, 150, 180 }, navy = { 30, 40, 90 }, teal = { 30, 140, 140 },
}

local function isFiniteNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end
Util.isFiniteNumber = isFiniteNumber

function Util.err(errs: Errors, path: string, msg: string)
	table.insert(errs, path .. ": " .. msg)
end

-- Validate a 3-vector given as {x,y,z}. Returns true when valid.
function Util.checkVec3(errs: Errors, path: string, v: any, opts: { positive: boolean?, nonneg: boolean?, max: number? }?): boolean
	if type(v) ~= "table" or #v ~= 3 then
		Util.err(errs, path, "expected {x, y, z}, got " .. typeof(v))
		return false
	end
	for i = 1, 3 do
		if not isFiniteNumber(v[i]) then
			Util.err(errs, path, ("component %d must be a finite number"):format(i))
			return false
		end
		if opts and opts.positive and v[i] <= 0 then
			Util.err(errs, path, ("component %d must be > 0"):format(i))
			return false
		end
		if opts and opts.max and v[i] > opts.max then
			Util.err(errs, path, ("component %d exceeds %g (Roblox part size limit)"):format(i, opts.max))
			return false
		end
		if opts and opts.nonneg and v[i] < 0 then
			Util.err(errs, path, ("component %d must be >= 0"):format(i))
			return false
		end
	end
	return true
end

function Util.checkColor(errs: Errors, path: string, c: any): boolean
	if type(c) == "string" then
		if Util.Palette[string.lower(c)] or string.match(c, HEX) then
			return true
		end
		Util.err(errs, path, ("unknown color %q (use #rrggbb, a palette name or {r,g,b} 0-255)"):format(c))
		return false
	elseif type(c) == "table" and #c == 3 then
		for i = 1, 3 do
			if not isFiniteNumber(c[i]) or c[i] < 0 or c[i] > 255 then
				Util.err(errs, path, "rgb components must be numbers in 0..255")
				return false
			end
		end
		return true
	end
	Util.err(errs, path, "expected color (#rrggbb, palette name or {r,g,b})")
	return false
end

function Util.color(c: any): Color3
	if type(c) == "string" then
		local p = Util.Palette[string.lower(c)]
		if p then
			return Color3.fromRGB(p[1], p[2], p[3])
		end
		local r, g, b = string.match(c, HEX)
		return Color3.fromRGB(tonumber(r, 16) :: number, tonumber(g, 16) :: number, tonumber(b, 16) :: number)
	end
	return Color3.fromRGB(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5))
end

function Util.vec(v: { number }?, default: Vector3?): Vector3
	if v == nil then
		return default or Vector3.zero
	end
	return Vector3.new(v[1], v[2], v[3])
end

-- pos {x,y,z} + rot {rx,ry,rz} in degrees (applied Y, X, Z like CFrame.fromOrientation)
function Util.cframe(pos: { number }?, rot: { number }?): CFrame
	local cf = CFrame.new(Util.vec(pos))
	if rot then
		cf = cf * CFrame.fromOrientation(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
	end
	return cf
end

-- Reject keys that are not in `allowed` (catches typos like `colour` or `szie`).
function Util.checkKeys(errs: Errors, path: string, t: { [any]: any }, allowed: { [string]: boolean })
	local bad = {}
	for k in pairs(t) do
		if type(k) ~= "string" or not allowed[k] then
			table.insert(bad, tostring(k))
		end
	end
	table.sort(bad)
	for _, k in ipairs(bad) do
		Util.err(errs, path, ("unknown field %q"):format(k))
	end
end

function Util.enumHas(enumType: any, name: any): boolean
	if type(name) ~= "string" then
		return false
	end
	local ok, item = pcall(function()
		return enumType[name]
	end)
	return ok and item ~= nil
end

-- Deterministic PRNG (xorshift32). Same seed => same sequence on every platform,
-- independent of Roblox's Random implementation.
export type Rng = { next: (self: Rng) -> number, range: (self: Rng, a: number, b: number) -> number, s: number }
local RngMT = {}
RngMT.__index = RngMT
function RngMT.next(self: any): number
	local x = self.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.s = x
	return x / 4294967296
end
function RngMT.range(self: any, a: number, b: number): number
	return a + (b - a) * self:next()
end
function Util.rng(seed: number): Rng
	local s = bit32.band((((math.floor(math.abs(seed)) % 4294967296) * 2654435761) % 4294967296) + 1, 0xFFFFFFFF)
	if s == 0 then
		s = 0x9E3779B9
	end
	return setmetatable({ s = s }, RngMT) :: any
end

function Util.deepCopy<T>(t: T): T
	if type(t) ~= "table" then
		return t
	end
	local o = {}
	for k, v in pairs(t :: any) do
		o[k] = Util.deepCopy(v)
	end
	return o :: any
end

-- Raise a single error listing every validation problem.
function Util.raise(kind: string, errs: Errors)
	error(("%s spec invalid (%d problem%s):\n  %s"):format(kind, #errs, #errs == 1 and "" or "s", table.concat(errs, "\n  ")), 0)
end

return Util
