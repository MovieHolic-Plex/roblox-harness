--!strict
-- Turns a validated object spec into Instances. Pure function of the spec:
-- same spec (and seed) => identical tree, names, order and properties.
local Util = require(script.Parent.Parent.Util)

local Build = {}

type Ctx = { spec: any, prefabs: { [string]: any }, anchored: boolean, rng: Util.Rng, parts: number }

local DEFAULT_COLOR = { 163, 162, 165 }

local function applyCommon(p: BasePart, n: any, ctx: Ctx, cf: CFrame)
	p.CFrame = cf
	p.Color = Util.color(n.color or DEFAULT_COLOR)
	p.Material = n.material and (Enum.Material :: any)[n.material] or Enum.Material.SmoothPlastic
	p.Anchored = if n.anchored ~= nil then n.anchored else ctx.anchored
	p.CanCollide = if n.canCollide ~= nil then n.canCollide else true
	p.Transparency = n.transparency or 0
	p.Reflectance = n.reflectance or 0
	if n.castShadow ~= nil then p.CastShadow = n.castShadow end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

local function decorate(inst: Instance, n: any)
	if n.attributes then
		local keys = {}
		for k in pairs(n.attributes) do table.insert(keys, k) end
		table.sort(keys)
		for _, k in ipairs(keys) do inst:SetAttribute(k, n.attributes[k]) end
	end
	if n.tags then
		local ok = pcall(function()
			for _, t in ipairs(n.tags) do (inst :: any):AddTag(t) end
		end)
		if not ok then
			-- Lune has no CollectionService; keep tags as an attribute so they survive export.
			inst:SetAttribute("HarnessTags", table.concat(n.tags, ","))
		end
	end
end

local function newPart(className: string, name: string, size: Vector3, parent: Instance, ctx: Ctx): BasePart
	local p = Instance.new(className) :: BasePart
	p.Name = name
	p.Size = size
	p.Parent = parent
	ctx.parts += 1
	return p
end

local buildNode: (ctx: Ctx, n: any, parent: Instance, base: CFrame, idx: number) -> ()

local function nodeName(n: any, fallback: string): string
	return n.name or fallback
end

local KIND_CLASS = { part = "Part", platform = "Part", wedge = "WedgePart", cornerwedge = "CornerWedgePart" }

buildNode = function(ctx: Ctx, n: any, parent: Instance, base: CFrame, idx: number)
	local kind = n.kind or "part"
	local cf = base * Util.cframe(n.pos, n.rot)
	if KIND_CLASS[kind] then
		local size = Util.vec(n.size, Vector3.new(4, 1, 2))
		local p = newPart(KIND_CLASS[kind], nodeName(n, kind .. idx), size, parent, ctx)
		applyCommon(p, n, ctx, cf)
		if n.shape and p:IsA("Part") then
			(p :: Part).Shape = (Enum.PartType :: any)[n.shape]
		end
		decorate(p, n)
		if kind == "platform" and n.trim and n.trim > 0 then
			-- Raised border frame (4 strips) around the top edge so ledges read clearly from afar
			-- while the walkable top keeps its own colour.
			local w = n.trim * 0.25
			local h = n.trim * 0.2
			local y = size.Y / 2 + h / 2
			local trimSpec = { color = n.trimColor or n.color, material = n.material, anchored = n.anchored, canCollide = false }
			local strips = {
				{ "N", Vector3.new(size.X, h, w), Vector3.new(0, y, -size.Z / 2 + w / 2) },
				{ "S", Vector3.new(size.X, h, w), Vector3.new(0, y, size.Z / 2 - w / 2) },
				{ "W", Vector3.new(w, h, size.Z - 2 * w), Vector3.new(-size.X / 2 + w / 2, y, 0) },
				{ "E", Vector3.new(w, h, size.Z - 2 * w), Vector3.new(size.X / 2 - w / 2, y, 0) },
			}
			for _, st in ipairs(strips) do
				local t = newPart("Part", p.Name .. "_Trim" .. st[1], st[2], parent, ctx)
				applyCommon(t, trimSpec, ctx, cf * CFrame.new(st[3]))
				if n.trimColor == nil then
					local c = p.Color
					t.Color = Color3.new(c.R * 0.7, c.G * 0.7, c.B * 0.7)
				end
			end
		end
	elseif kind == "truss" then
		local h = n.height
		-- TrussPart sizes snap to multiples of 2 in Roblox; do it up front so Lune and Studio agree.
		local snapped = math.max(2, math.floor(h / 2 + 0.5) * 2)
		local t = newPart("TrussPart", nodeName(n, "Truss" .. idx), Vector3.new(2, snapped, 2), parent, ctx) :: TrussPart
		applyCommon(t, n, ctx, cf * CFrame.new(0, snapped / 2, 0))
		if n.style then t.Style = (Enum.Style :: any)[n.style] end
		decorate(t, n)
	elseif kind == "rope" then
		-- Climbable rope: an invisible TrussPart (Humanoid climbs it) plus visible cylinder segments.
		local m = Instance.new("Model")
		m.Name = nodeName(n, "Rope" .. idx)
		m.Parent = parent
		local len = n.length
		local snapped = math.max(2, math.floor(len / 2 + 0.5) * 2)
		local th = n.thickness or 0.35
		local climb = newPart("TrussPart", "Climb", Vector3.new(2, snapped, 2), m, ctx)
		applyCommon(climb, { anchored = n.anchored }, ctx, cf * CFrame.new(0, -snapped / 2, 0))
		climb.Transparency = 1
		local segs = n.segments or 1
		local sl = snapped / segs
		for i = 1, segs do
			local s = newPart("Part", ("Seg%02d"):format(i), Vector3.new(sl, th, th), m, ctx) :: Part
			s.Shape = Enum.PartType.Cylinder
			local segColor = (n.knotColor and i % 2 == 0) and n.knotColor or (n.color or { 150, 110, 70 })
			applyCommon(s, { color = segColor, material = n.material or "Fabric", anchored = n.anchored, canCollide = false }, ctx,
				cf * CFrame.new(0, -(i - 0.5) * sl, 0) * CFrame.Angles(0, 0, math.rad(90)))
		end
		m.PrimaryPart = climb
		m.WorldPivot = cf
		decorate(m, n)
	elseif kind == "ladder" then
		local m = Instance.new("Model")
		m.Name = nodeName(n, "Ladder" .. idx)
		m.Parent = parent
		local h, w, sp = n.height, n.width or 2, n.rungSpacing or 1.5
		local rail = n.railColor or n.color or { 120, 85, 55 }
		local climb = newPart("TrussPart", "Climb", Vector3.new(2, math.max(2, math.floor(h / 2 + 0.5) * 2), 2), m, ctx)
		applyCommon(climb, { anchored = n.anchored }, ctx, cf * CFrame.new(0, climb.Size.Y / 2, 0))
		climb.Transparency = 1
		for i, sx in ipairs({ -1, 1 }) do
			local r = newPart("Part", i == 1 and "RailL" or "RailR", Vector3.new(0.3, h, 0.3), m, ctx)
			applyCommon(r, { color = rail, material = n.material or "Wood", anchored = n.anchored, canCollide = false }, ctx, cf * CFrame.new(sx * w / 2, h / 2, 0))
		end
		local rungs = math.floor(h / sp)
		for i = 1, rungs do
			local r = newPart("Part", ("Rung%02d"):format(i), Vector3.new(w, 0.2, 0.25), m, ctx)
			applyCommon(r, { color = n.color or { 150, 105, 65 }, material = n.material or "Wood", anchored = n.anchored, canCollide = false }, ctx, cf * CFrame.new(0, (i - 0.5) * sp, 0))
		end
		m.PrimaryPart = climb
		m.WorldPivot = cf
		decorate(m, n)
	elseif kind == "stairs" then
		local m = Instance.new("Model")
		m.Name = nodeName(n, "Stairs" .. idx)
		m.Parent = parent
		local rise, run, w = n.rise or 1, n.run or 1.5, n.width or 4
		for i = 1, n.steps do
			local s = newPart("Part", ("Step%02d"):format(i), Vector3.new(w, rise, run), m, ctx)
			applyCommon(s, n, ctx, cf * CFrame.new(0, (i - 0.5) * rise, -(i - 0.5) * run))
		end
		m.WorldPivot = cf
		decorate(m, n)
	elseif kind == "model" then
		local m = Instance.new("Model")
		m.Name = nodeName(n, "Model" .. idx)
		m.Parent = parent
		local sub = table.clone(ctx)
		if n.anchored ~= nil then sub.anchored = n.anchored end
		for i, c in ipairs(n.children or {}) do
			buildNode(sub, c, m, cf, i)
		end
		ctx.parts = sub.parts
		m.WorldPivot = n.pivot and (cf * CFrame.new(Util.vec(n.pivot))) or cf
		if n.weld == "all" then Build.weldAll(m) end
		decorate(m, n)
	elseif kind == "array" then
		local m = Instance.new("Model")
		m.Name = nodeName(n, "Array" .. idx)
		m.Parent = parent
		local off, rs = Util.vec(n.offset, Vector3.new(4, 0, 0)), Util.vec(n.rotStep)
		for i = 1, n.count do
			local k = i - 1
			local step = CFrame.new(off * k) * CFrame.fromOrientation(math.rad(rs.X * k), math.rad(rs.Y * k), math.rad(rs.Z * k))
			local item = table.clone(n.item)
			item.name = (n.item.name or (n.item.kind or "part")) .. ("_%03d"):format(i)
			buildNode(ctx, item, m, cf * step, i)
		end
		m.WorldPivot = cf
		decorate(m, n)
	elseif kind == "scatter" then
		local m = Instance.new("Model")
		m.Name = nodeName(n, "Scatter" .. idx)
		m.Parent = parent
		-- Each scatter owns its own stream: seeded by root seed + local seed, so editing one scatter
		-- never reshuffles another.
		local rng = Util.rng((ctx.spec.seed or 0) * 7919 + (n.seed or idx))
		local a = Util.vec(n.area)
		local jr = Util.vec(n.jitterRot, Vector3.new(0, 360, 0))
		for i = 1, n.count do
			local x, y, z = rng:range(-a.X / 2, a.X / 2), rng:range(-a.Y / 2, a.Y / 2), rng:range(-a.Z / 2, a.Z / 2)
			local rx, ry, rz = rng:range(-jr.X / 2, jr.X / 2), rng:range(-jr.Y / 2, jr.Y / 2), rng:range(-jr.Z / 2, jr.Z / 2)
			local item = Util.deepCopy(n.item)
			if n.scaleRange then
				local s = rng:range(n.scaleRange[1], n.scaleRange[2])
				item = Build.scaleNode(item, s, ctx.prefabs)
			end
			item.name = (n.item.name or (n.item.kind or "part")) .. ("_%03d"):format(i)
			local at = cf * CFrame.new(x, y, z) * CFrame.fromOrientation(math.rad(rx), math.rad(ry), math.rad(rz))
			buildNode(ctx, item, m, at, i)
		end
		m.WorldPivot = cf
		decorate(m, n)
	elseif kind == "use" then
		local p = Util.deepCopy(ctx.prefabs[n.prefab])
		-- fields on the `use` node override the prefab (name, color, material...) and pos/rot compose
		local wrapped = { kind = "model", name = n.name or n.prefab, pos = n.pos, rot = n.rot, children = { p } }
		for k, v in pairs(n) do
			if k ~= "kind" and k ~= "prefab" and k ~= "pos" and k ~= "rot" and k ~= "name" then
				p[k] = v
			end
		end
		buildNode(ctx, wrapped, parent, base, idx)
	end
end

local function sv(v: { number }?, s: number): { number }?
	if v == nil then return nil end
	return { v[1] * s, v[2] * s, v[3] * s }
end

-- Uniformly scale a node (and everything under it) by s. `use` nodes are resolved first.
function Build.scaleNode(n: any, s: number, prefabs: { [string]: any }): any
	n = Util.deepCopy(n)
	if n.kind == "use" then
		local p = Util.deepCopy(prefabs[n.prefab])
		n = { kind = "model", name = n.name or n.prefab, pos = n.pos, rot = n.rot, children = { p } }
	end
	n.size = sv(n.size, s)
	n.pos = sv(n.pos, s)
	n.offset = sv(n.offset, s)
	n.area = sv(n.area, s)
	n.pivot = sv(n.pivot, s)
	for _, k in ipairs({ "height", "length", "thickness", "width", "rungSpacing", "rise", "run", "trim" }) do
		if n[k] then n[k] *= s end
	end
	if n.children then
		for i, c in ipairs(n.children) do n.children[i] = Build.scaleNode(c, s, prefabs) end
	end
	if n.item then n.item = Build.scaleNode(n.item, s, prefabs) end
	return n
end

-- Weld every BasePart in `model` to its PrimaryPart (or the first part) with WeldConstraints.
-- Deterministic order: depth-first in child order.
function Build.weldAll(model: Model): number
	local parts = {}
	local function walk(i: Instance)
		for _, c in ipairs(i:GetChildren()) do
			if c:IsA("BasePart") then table.insert(parts, c) end
			walk(c)
		end
	end
	walk(model)
	local root = model.PrimaryPart or parts[1]
	if not root then return 0 end
	model.PrimaryPart = root
	local n = 0
	for _, p in ipairs(parts) do
		if p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Name = "Weld_" .. p.Name
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
			n += 1
		end
	end
	return n
end

function Build.build(spec: any, origin: CFrame?): Model
	local prefabs = spec.prefabs or {}
	local ctx: Ctx = { spec = spec, prefabs = prefabs, anchored = if spec.anchored ~= nil then spec.anchored else true, rng = Util.rng(spec.seed or 0), parts = 0 }
	local root = Instance.new("Model")
	root.Name = spec.name or "HarnessObject"
	local base = (origin or CFrame.new()) * CFrame.new(Util.vec(spec.pivot))
	for i, c in ipairs(spec.children) do
		buildNode(ctx, c, root, base, i)
	end
	root.WorldPivot = base
	if spec.weld == "all" then Build.weldAll(root) end
	root:SetAttribute("HarnessParts", ctx.parts)
	return root
end

return Build
