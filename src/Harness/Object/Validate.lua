--!strict
-- Validates object specs. Collects *all* problems instead of stopping at the first.
local Util = require(script.Parent.Parent.Util)

local Validate = {}

Validate.Limits = { maxParts = 20000, maxDepth = 32, maxCount = 2000 }

local COMMON = {
	kind = true, name = true, pos = true, rot = true, color = true, material = true, anchored = true,
	canCollide = true, transparency = true, reflectance = true, castShadow = true, attributes = true, tags = true,
}
local function with(extra: { [string]: boolean }): { [string]: boolean }
	local t = table.clone(COMMON)
	for k, v in pairs(extra) do
		t[k] = v
	end
	return t
end

Validate.Kinds = {
	part = with({ size = true, shape = true }),
	wedge = with({ size = true }),
	cornerwedge = with({ size = true }),
	platform = with({ size = true, shape = true, trim = true, trimColor = true }),
	truss = with({ height = true, style = true }),
	rope = with({ length = true, thickness = true, segments = true, knotColor = true }),
	ladder = with({ height = true, width = true, rungSpacing = true, railColor = true }),
	stairs = with({ steps = true, rise = true, run = true, width = true }),
	model = with({ children = true, pivot = true, weld = true }),
	array = with({ count = true, offset = true, rotStep = true, item = true }),
	scatter = with({ count = true, area = true, item = true, seed = true, jitterRot = true, scaleRange = true }),
	use = with({ prefab = true }),
}

local ROOT_KEYS = { name = true, seed = true, prefabs = true, children = true, pivot = true, anchored = true, weld = true, limits = true, version = true }

type Ctx = { errs: Util.Errors, parts: number, memo: { [string]: number }, prefabs: { [string]: any }, stack: { [string]: boolean }, limits: any }

local SHAPES = { Block = true, Cylinder = true, Ball = true }

local nodeCheck: (ctx: Ctx, path: string, n: any, depth: number) -> number

local function count(ctx: Ctx, path: string, v: any, name: string): number?
	if type(v) ~= "number" or v ~= math.floor(v) or v < 1 then
		Util.err(ctx.errs, path, name .. " must be an integer >= 1")
		return nil
	end
	if v > ctx.limits.maxCount then
		Util.err(ctx.errs, path, ("%s %d exceeds limit %d"):format(name, v, ctx.limits.maxCount))
		return nil
	end
	return v
end

local function posNum(ctx: Ctx, path: string, v: any, name: string, required: boolean): boolean
	if v == nil then
		if required then
			Util.err(ctx.errs, path, name .. " is required")
		end
		return not required
	end
	if not Util.isFiniteNumber(v) or v <= 0 then
		Util.err(ctx.errs, path, name .. " must be a finite number > 0")
		return false
	end
	return true
end

local function checkCommon(ctx: Ctx, path: string, n: any)
	local e = ctx.errs
	if n.name ~= nil and (type(n.name) ~= "string" or n.name == "" or #n.name > 100) then
		Util.err(e, path .. ".name", "must be a non-empty string (<=100 chars)")
	end
	if n.pos ~= nil then Util.checkVec3(e, path .. ".pos", n.pos) end
	if n.rot ~= nil then Util.checkVec3(e, path .. ".rot", n.rot) end
	if n.color ~= nil then Util.checkColor(e, path .. ".color", n.color) end
	if n.material ~= nil and not Util.enumHas(Enum.Material, n.material) then
		Util.err(e, path .. ".material", ("unknown material %q"):format(tostring(n.material)))
	end
	for _, b in ipairs({ "anchored", "canCollide", "castShadow" }) do
		if n[b] ~= nil and type(n[b]) ~= "boolean" then
			Util.err(e, path .. "." .. b, "must be a boolean")
		end
	end
	for _, f in ipairs({ "transparency", "reflectance" }) do
		local v = n[f]
		if v ~= nil and (not Util.isFiniteNumber(v) or v < 0 or v > 1) then
			Util.err(e, path .. "." .. f, "must be a number in 0..1")
		end
	end
	if n.attributes ~= nil then
		if type(n.attributes) ~= "table" then
			Util.err(e, path .. ".attributes", "must be a table")
		else
			for k, v in pairs(n.attributes) do
				local tv = type(v)
				if type(k) ~= "string" or not (tv == "string" or tv == "number" or tv == "boolean") then
					Util.err(e, path .. ".attributes", "keys must be strings, values string/number/boolean")
					break
				end
			end
		end
	end
	if n.tags ~= nil then
		if type(n.tags) ~= "table" then
			Util.err(e, path .. ".tags", "must be a list of strings")
		else
			for i, t in ipairs(n.tags) do
				if type(t) ~= "string" then Util.err(e, ("%s.tags[%d]"):format(path, i), "must be a string") end
			end
		end
	end
end

local function children(ctx: Ctx, path: string, list: any, depth: number): number
	if type(list) ~= "table" then
		Util.err(ctx.errs, path, "children must be a list")
		return 0
	end
	local n = 0
	for k in pairs(list) do
		if type(k) ~= "number" or k < 1 or k > #list or k ~= math.floor(k) then
			Util.err(ctx.errs, path, "children must be a dense list (found key " .. tostring(k) .. ")")
			return 0
		end
	end
	for i, c in ipairs(list) do
		n += nodeCheck(ctx, ("%s[%d]"):format(path, i), c, depth + 1)
	end
	return n
end

local function checkWeld(ctx: Ctx, path: string, w: any)
	if w == nil then return end
	if w == "none" or w == "all" then return end
	Util.err(ctx.errs, path, 'weld must be "all" or "none"')
end

-- Returns the number of BaseParts this node will produce.
nodeCheck = function(ctx: Ctx, path: string, n: any, depth: number): number
	local e = ctx.errs
	if depth > ctx.limits.maxDepth then
		Util.err(e, path, ("nesting deeper than %d"):format(ctx.limits.maxDepth))
		return 0
	end
	if type(n) ~= "table" then
		Util.err(e, path, "node must be a table, got " .. typeof(n))
		return 0
	end
	local kind = n.kind or "part"
	local allowed = Validate.Kinds[kind]
	if not allowed then
		Util.err(e, path .. ".kind", ("unknown kind %q"):format(tostring(kind)))
		return 0
	end
	Util.checkKeys(e, path, n, allowed)
	checkCommon(ctx, path, n)
	local produced = 1
	if kind == "part" or kind == "wedge" or kind == "cornerwedge" or kind == "platform" then
		if n.size == nil then
			if kind ~= "part" then Util.err(e, path .. ".size", "is required") end
		else
			Util.checkVec3(e, path .. ".size", n.size, { positive = true })
		end
		if n.shape ~= nil and not SHAPES[n.shape] then
			Util.err(e, path .. ".shape", "must be Block, Cylinder or Ball")
		end
		if kind == "platform" then
			if n.trim ~= nil and (not Util.isFiniteNumber(n.trim) or n.trim < 0 or n.trim > 5) then
				Util.err(e, path .. ".trim", "must be a number in 0..5")
			elseif n.trim and n.trim > 0 then
				produced = 2
			end
			if n.trimColor ~= nil then Util.checkColor(e, path .. ".trimColor", n.trimColor) end
		end
	elseif kind == "truss" then
		posNum(ctx, path .. ".height", n.height, "height", true)
		if n.style ~= nil and not Util.enumHas(Enum.Style, n.style) then
			Util.err(e, path .. ".style", "unknown truss style")
		end
		produced = 1
	elseif kind == "rope" then
		posNum(ctx, path .. ".length", n.length, "length", true)
		posNum(ctx, path .. ".thickness", n.thickness, "thickness", false)
		local seg = n.segments and count(ctx, path .. ".segments", n.segments, "segments") or 1
		if n.knotColor ~= nil then Util.checkColor(e, path .. ".knotColor", n.knotColor) end
		produced = 1 + (seg or 1) -- climb truss + visual segments
	elseif kind == "ladder" then
		posNum(ctx, path .. ".height", n.height, "height", true)
		posNum(ctx, path .. ".width", n.width, "width", false)
		posNum(ctx, path .. ".rungSpacing", n.rungSpacing, "rungSpacing", false)
		if n.railColor ~= nil then Util.checkColor(e, path .. ".railColor", n.railColor) end
		local h = Util.isFiniteNumber(n.height) and n.height or 0
		local sp = Util.isFiniteNumber(n.rungSpacing) and n.rungSpacing > 0 and n.rungSpacing or 1.5
		local rungs = math.floor(h / sp)
		if rungs > ctx.limits.maxCount then
			Util.err(e, path, ("ladder would create %d rungs (limit %d)"):format(rungs, ctx.limits.maxCount))
			rungs = 0
		end
		produced = 3 + rungs
	elseif kind == "stairs" then
		local s = count(ctx, path .. ".steps", n.steps, "steps") or 0
		posNum(ctx, path .. ".rise", n.rise, "rise", false)
		posNum(ctx, path .. ".run", n.run, "run", false)
		posNum(ctx, path .. ".width", n.width, "width", false)
		produced = s
	elseif kind == "model" then
		checkWeld(ctx, path .. ".weld", n.weld)
		if n.pivot ~= nil then Util.checkVec3(e, path .. ".pivot", n.pivot) end
		produced = n.children == nil and 0 or children(ctx, path .. ".children", n.children, depth)
	elseif kind == "array" or kind == "scatter" then
		local c = count(ctx, path .. ".count", n.count, "count") or 0
		if kind == "array" then
			if n.offset ~= nil then Util.checkVec3(e, path .. ".offset", n.offset) end
			if n.rotStep ~= nil then Util.checkVec3(e, path .. ".rotStep", n.rotStep) end
		else
			if n.area == nil then
				Util.err(e, path .. ".area", "is required ({x, y, z} extents)")
			else
				Util.checkVec3(e, path .. ".area", n.area, { nonneg = true })
			end
			if n.seed ~= nil and not Util.isFiniteNumber(n.seed) then Util.err(e, path .. ".seed", "must be a number") end
			if n.jitterRot ~= nil then Util.checkVec3(e, path .. ".jitterRot", n.jitterRot, { nonneg = true }) end
			if n.scaleRange ~= nil then
				local sr = n.scaleRange
				if type(sr) ~= "table" or not Util.isFiniteNumber(sr[1]) or not Util.isFiniteNumber(sr[2]) or sr[1] <= 0 or sr[2] < sr[1] then
					Util.err(e, path .. ".scaleRange", "must be {min, max} with 0 < min <= max")
				end
			end
		end
		if n.item == nil then
			Util.err(e, path .. ".item", "is required")
			produced = 0
		else
			produced = c * nodeCheck(ctx, path .. ".item", n.item, depth + 1)
		end
	elseif kind == "use" then
		local name = n.prefab
		if type(name) ~= "string" or ctx.prefabs[name] == nil then
			Util.err(e, path .. ".prefab", ("unknown prefab %q"):format(tostring(name)))
			produced = 0
		elseif ctx.stack[name] then
			Util.err(e, path .. ".prefab", ("prefab cycle through %q"):format(name))
			produced = 0
		elseif ctx.memo[name] ~= nil then
			produced = ctx.memo[name]
		else
			ctx.stack[name] = true
			produced = nodeCheck(ctx, "prefabs." .. name, ctx.prefabs[name], depth + 1)
			ctx.stack[name] = nil
			ctx.memo[name] = produced
		end
	end
	return produced
end

-- Validate a whole object spec. Returns ok, errors, estimatedPartCount.
function Validate.spec(spec: any): (boolean, Util.Errors, number)
	local errs: Util.Errors = {}
	if type(spec) ~= "table" then
		return false, { "spec: must be a table" }, 0
	end
	Util.checkKeys(errs, "spec", spec, ROOT_KEYS)
	local limits = table.clone(Validate.Limits)
	if spec.limits ~= nil then
		if type(spec.limits) ~= "table" then
			Util.err(errs, "spec.limits", "must be a table")
		else
			for k, v in pairs(spec.limits) do
				if limits[k] == nil or not Util.isFiniteNumber(v) or v < 1 then
					Util.err(errs, "spec.limits." .. tostring(k), "unknown limit or bad value")
				else
					limits[k] = v
				end
			end
		end
	end
	if spec.name ~= nil and (type(spec.name) ~= "string" or spec.name == "") then
		Util.err(errs, "spec.name", "must be a non-empty string")
	end
	if spec.seed ~= nil and not Util.isFiniteNumber(spec.seed) then
		Util.err(errs, "spec.seed", "must be a finite number")
	end
	if spec.pivot ~= nil then Util.checkVec3(errs, "spec.pivot", spec.pivot) end
	if spec.anchored ~= nil and type(spec.anchored) ~= "boolean" then Util.err(errs, "spec.anchored", "must be a boolean") end
	checkWeld({ errs = errs } :: any, "spec.weld", spec.weld)
	local prefabs = {}
	if spec.prefabs ~= nil then
		if type(spec.prefabs) ~= "table" then
			Util.err(errs, "spec.prefabs", "must be a map of name -> node")
		else
			for k, v in pairs(spec.prefabs) do
				if type(k) ~= "string" then
					Util.err(errs, "spec.prefabs", "prefab names must be strings")
				else
					prefabs[k] = v
				end
			end
		end
	end
	local ctx: Ctx = { errs = errs, parts = 0, memo = {}, prefabs = prefabs, stack = {}, limits = limits }
	local total = 0
	if spec.children == nil then
		Util.err(errs, "spec.children", "is required")
	else
		total = children(ctx, "spec.children", spec.children, 0)
	end
	-- prefabs that are never used still get validated so typos surface early
	local names = {}
	for k in pairs(prefabs) do table.insert(names, k) end
	table.sort(names)
	for _, k in ipairs(names) do
		if ctx.memo[k] == nil then
			ctx.stack[k] = true
			ctx.memo[k] = nodeCheck(ctx, "prefabs." .. k, prefabs[k], 1)
			ctx.stack[k] = nil
		end
	end
	if total > limits.maxParts then
		Util.err(errs, "spec", ("would create %d parts (limit %d; raise spec.limits.maxParts)"):format(total, limits.maxParts))
	end
	-- dedupe (prefabs used several times report the same problem once)
	local seen, out = {}, {}
	for _, m in ipairs(errs) do
		if not seen[m] then seen[m] = true; table.insert(out, m) end
	end
	return #out == 0, out, total
end

return Validate
