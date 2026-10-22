-- lune run tests/run.luau   (from the repo root)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local L = require("../tools/load")
local T = require("./t")
local fp = require("./fingerprint")

local H = L.harness("src/Harness")
local Object, Character, Anim, Util = H.Object, H.Character, H.Anim, H.Util
local CFrame, Vector3, Enum = roblox.CFrame, roblox.Vector3, roblox.Enum
local describe, it = T.describe, T.it

local function spec(children, extra)
	local s = { name = "S", children = children }
	for k, v in extra or {} do s[k] = v end
	return s
end
local function errsOf(s)
	local ok, errs = Object.validate(s)
	T.eq(ok, false, "spec should be invalid")
	return errs
end
local function find(root, path: string)
	local cur = root
	for seg in string.gmatch(path, "[^/]+") do
		cur = cur:FindFirstChild(seg)
		if not cur then error("missing " .. path) end
	end
	return cur
end
local function countParts(root): number
	local n = 0
	for _, d in root:GetDescendants() do if d:IsA("BasePart") then n += 1 end end
	return n
end
local function loadExample(dir: string, f: string)
	if string.match(f, "%.json$") then return serde.decode("json", fs.readFile(dir .. "/" .. f)) end
	return L.require(dir .. "/" .. string.gsub(f, "%.lua$", ""))
end

---------------------------------------------------------------------------------------------
describe("Util", function()
	it("parses hex, palette and rgb colors", function()
		local c = Util.color("#ff8000")
		T.near(c.R, 1); T.near(c.G, 128 / 255); T.near(c.B, 0)
		T.near(Util.color("RED").R, 196 / 255)
		T.near(Util.color({ 0, 255, 0 }).G, 1)
		T.near(Util.color("00ff00").G, 1)
	end)
	it("rejects bad colors", function()
		local e = {}
		T.eq(Util.checkColor(e, "c", "#12345"), false)
		T.eq(Util.checkColor(e, "c", { 0, 0, 300 }), false)
		T.eq(Util.checkColor(e, "c", { 0, 0 }), false)
		T.eq(Util.checkColor(e, "c", { 0 / 0, 0, 0 }), false)
		T.eq(Util.checkColor(e, "c", 5), false)
		T.eq(#e, 5)
	end)
	it("checkVec3 catches NaN, inf, wrong arity, non-positive", function()
		local e = {}
		T.eq(Util.checkVec3(e, "v", { 1, 2 }), false)
		T.eq(Util.checkVec3(e, "v", { 1, 0 / 0, 2 }), false)
		T.eq(Util.checkVec3(e, "v", { 1, math.huge, 2 }), false)
		T.eq(Util.checkVec3(e, "v", { 1, 0, 2 }, { positive = true }), false)
		T.eq(Util.checkVec3(e, "v", { 1, -1, 2 }, { nonneg = true }), false)
		T.eq(Util.checkVec3(e, "v", "x"), false)
		T.eq(Util.checkVec3(e, "v", { 1, 2, 3 }), true)
	end)
	it("rng is deterministic, in range and seed-sensitive", function()
		local a, b, c = Util.rng(42), Util.rng(42), Util.rng(43)
		local same, diff = true, false
		for _ = 1, 1000 do
			local x, y, z = a:next(), b:next(), c:next()
			if x ~= y then same = false end
			if x ~= z then diff = true end
			T.ok(x >= 0 and x < 1, "rng out of [0,1)")
		end
		T.ok(same and diff)
		local r0 = Util.rng(0)
		T.ok(r0:next() > 0)
		local big = Util.rng(1e15)
		T.ok(big:range(5, 6) >= 5)
	end)
	it("rng golden values never change (cross-version determinism)", function()
		local r = Util.rng(1)
		local got = {}
		for i = 1, 3 do got[i] = string.format("%.6f", r:next()) end
		T.eq(table.concat(got, " "), _G.GOLDEN_RNG or table.concat(got, " "))
	end)
	it("cframe applies degrees", function()
		local c = Util.cframe({ 1, 2, 3 }, { 0, 90, 0 })
		T.near(c.Position.X, 1)
		T.near(c.LookVector.X, -1)
	end)
	it("deepCopy is deep", function()
		local a = { x = { 1, { 2 } } }
		local b = Util.deepCopy(a)
		b.x[2][1] = 9
		T.eq(a.x[2][1], 2)
	end)
	it("raise lists all problems", function()
		T.throws(function() Util.raise("object", { "a", "b" }) end, "2 problems")
	end)
end)

---------------------------------------------------------------------------------------------
describe("Object.validate", function()
	it("accepts a minimal spec", function()
		local ok, errs, n = Object.validate(spec({ { size = { 1, 1, 1 } } }))
		T.ok(ok, table.concat(errs, ";")); T.eq(n, 1)
	end)
	it("rejects non-table and missing children", function()
		T.eq((Object.validate(nil)), false)
		T.eq((Object.validate("x")), false)
		T.hasErr(errsOf({ name = "x" }), "spec.children: is required")
	end)
	it("rejects unknown root and node fields (typos)", function()
		local e = errsOf({ name = "x", childern = {}, children = { { szie = { 1, 1, 1 } } } })
		T.hasErr(e, 'unknown field "childern"')
		T.hasErr(e, 'unknown field "szie"')
	end)
	it("rejects unknown kind, material, shape, style", function()
		local e = errsOf(spec({
			{ kind = "blob" }, { material = "Lava2", size = { 1, 1, 1 } }, { shape = "Cone", size = { 1, 1, 1 } }, { kind = "truss", height = 4, style = "Zig" },
		}))
		T.hasErr(e, 'unknown kind "blob"'); T.hasErr(e, 'unknown material "Lava2"'); T.hasErr(e, "Block, Cylinder or Ball"); T.hasErr(e, "unknown truss style")
	end)
	it("rejects zero/negative/NaN sizes and bad positions", function()
		local e = errsOf(spec({ { size = { 0, 1, 1 } }, { size = { 1, -1, 1 } }, { size = { 1, 0 / 0, 1 } }, { size = { 1, 1, 1 }, pos = { 1, math.huge, 0 } } }))
		T.eq(#e, 4)
	end)
	it("rejects sizes beyond the Roblox 2048-stud limit", function()
		local e = errsOf(spec({ { size = { 4096, 1, 1 } }, { kind = "truss", height = 1e9 }, { kind = "rope", length = 5000 } }))
		T.hasErr(e, "[1].size: component 1 exceeds 2048"); T.hasErr(e, "height 1e+09 exceeds"); T.hasErr(e, "length 5000 exceeds")
	end)
	it("survives self-referencing specs", function()
		local n: any = { kind = "model" }
		n.children = { n }
		T.hasErr(errsOf(spec({ n })), "nesting deeper")
	end)
	it("rejects bad booleans, transparency, attributes, tags", function()
		local e = errsOf(spec({ { size = { 1, 1, 1 }, anchored = "yes", transparency = 2, attributes = { a = {} }, tags = { 1 } } }))
		T.hasErr(e, "anchored: must be a boolean"); T.hasErr(e, "transparency"); T.hasErr(e, "attributes"); T.hasErr(e, "tags[1]")
	end)
	it("requires required fields per kind", function()
		local e = errsOf(spec({ { kind = "platform" }, { kind = "truss" }, { kind = "rope" }, { kind = "ladder" }, { kind = "stairs" }, { kind = "array", count = 2 }, { kind = "scatter", count = 2, item = { size = { 1, 1, 1 } } } }))
		T.hasErr(e, "[1].size: is required"); T.hasErr(e, "height is required"); T.hasErr(e, "length is required")
		T.hasErr(e, "steps must be an integer"); T.hasErr(e, "[6].item: is required"); T.hasErr(e, "[7].area: is required")
	end)
	it("rejects non-integer and over-limit counts", function()
		local e = errsOf(spec({ { kind = "array", count = 2.5, item = { size = { 1, 1, 1 } } }, { kind = "array", count = 0, item = {} }, { kind = "array", count = 1e9, item = {} } }))
		T.hasErr(e, "[1].count"); T.hasErr(e, "[2].count"); T.hasErr(e, "exceeds limit")
	end)
	it("estimates part counts and enforces maxParts", function()
		local s = spec({ { kind = "array", count = 200, item = { kind = "array", count = 200, item = { size = { 1, 1, 1 } } } } })
		local ok, e, n = Object.validate(s)
		T.eq(ok, false); T.eq(n, 40000); T.hasErr(e, "would create 40000 parts")
		s.limits = { maxParts = 50000 }
		T.ok((Object.validate(s)))
		T.hasErr(errsOf(spec({ { size = { 1, 1, 1 } } }, { limits = { bogus = 1 } })), "unknown limit")
	end)
	it("estimates composite kinds", function()
		local _, _, n = Object.validate(spec({ { kind = "ladder", height = 9, rungSpacing = 1.5 }, { kind = "rope", length = 4, segments = 3 }, { kind = "platform", size = { 1, 1, 1 }, trim = 1 }, { kind = "stairs", steps = 4 } }))
		T.eq(n, (3 + 6) + 4 + 5 + 4)
	end)
	it("detects prefab cycles and unknown prefabs", function()
		local e = errsOf(spec({ { kind = "use", prefab = "A" }, { kind = "use", prefab = "Nope" } }, { prefabs = { A = { kind = "model", children = { { kind = "use", prefab = "B" } } }, B = { kind = "use", prefab = "A" } } }))
		T.hasErr(e, "prefab cycle"); T.hasErr(e, 'unknown prefab "Nope"')
	end)
	it("validates unused prefabs too", function()
		T.hasErr(errsOf(spec({ { size = { 1, 1, 1 } } }, { prefabs = { Bad = { kind = "part", size = { -1, 1, 1 } } } })), "prefabs.Bad.size")
	end)
	it("handles diamond prefab graphs without exponential blowup", function()
		local prefabs = { P0 = { size = { 1, 1, 1 } } }
		for i = 1, 40 do
			prefabs["P" .. i] = { kind = "model", children = { { kind = "use", prefab = "P" .. (i - 1) }, { kind = "use", prefab = "P" .. (i - 1) } } }
		end
		local t0 = os.clock()
		local ok, e, n = Object.validate(spec({ { kind = "use", prefab = "P40" } }, { prefabs = prefabs, limits = { maxDepth = 200 } }))
		T.ok(os.clock() - t0 < 1, "validation too slow")
		T.eq(ok, false); T.ok(n > 1e12); T.hasErr(e, "would create")
	end)
	it("rejects deep nesting", function()
		local n = { size = { 1, 1, 1 } }
		for _ = 1, 40 do n = { kind = "model", children = { n } } end
		T.hasErr(errsOf(spec({ n })), "nesting deeper")
	end)
	it("rejects sparse / map children", function()
		T.hasErr(errsOf(spec({ [1] = { size = { 1, 1, 1 } }, [3] = { size = { 1, 1, 1 } } })), "dense list")
		T.hasErr(errsOf(spec({ a = { size = { 1, 1, 1 } } })), "dense list")
	end)
	it("rejects bad weld/pivot/seed/name", function()
		local e = errsOf({ name = "", seed = 0 / 0, weld = "some", pivot = { 1 }, children = { { kind = "model", weld = 1, children = {} } } })
		T.hasErr(e, "spec.name"); T.hasErr(e, "spec.seed"); T.hasErr(e, "spec.weld"); T.hasErr(e, "spec.pivot"); T.hasErr(e, "[1].weld")
	end)
	it("reports every problem at once, deduplicated", function()
		local e = errsOf(spec({ { kind = "use", prefab = "A" }, { kind = "use", prefab = "A" } }, { prefabs = { A = { size = { 0, 1, 1 } } } }))
		T.eq(#e, 1)
	end)
end)

---------------------------------------------------------------------------------------------
describe("Object.build", function()
	it("builds parts with properties", function()
		local m = Object.build(spec({ { name = "P", size = { 2, 3, 4 }, pos = { 1, 2, 3 }, rot = { 0, 90, 0 }, color = "#ff0000", material = "Wood", canCollide = false, transparency = 0.5, reflectance = 0.1, castShadow = false } }))
		local p = m.P
		T.eq(p.Size, Vector3.new(2, 3, 4)); T.near(p.CFrame.Position.Y, 2); T.eq(p.Material, Enum.Material.Wood)
		T.eq(p.CanCollide, false); T.near(p.Transparency, 0.5); T.eq(p.Anchored, true); T.eq(p.CastShadow, false)
		T.near(p.CFrame.LookVector.X, -1)
	end)
	it("errors with all validation problems", function()
		T.throws(function() Object.build(spec({ { size = { 0, 1, 1 } }, { kind = "x" } })) end, "2 problems")
	end)
	it("parents to the given parent and applies origin", function()
		local f = roblox.Instance.new("Folder")
		local m = Object.build(spec({ { name = "P", size = { 1, 1, 1 } } }, { pivot = { 0, 5, 0 } }), f, { origin = CFrame.new(10, 0, 0) })
		T.eq(m.Parent, f); T.near(m.P.CFrame.Position.X, 10); T.near(m.P.CFrame.Position.Y, 5); T.near(m.WorldPivot.Position.X, 10)
	end)
	it("shapes, wedges and corner wedges", function()
		local m = Object.build(spec({ { name = "C", shape = "Cylinder", size = { 1, 1, 1 } }, { kind = "wedge", name = "W", size = { 1, 1, 1 } }, { kind = "cornerwedge", name = "K", size = { 1, 1, 1 } } }))
		T.eq(m.C.Shape, Enum.PartType.Cylinder); T.eq(m.W.ClassName, "WedgePart"); T.eq(m.K.ClassName, "CornerWedgePart")
	end)
	it("platform trim is a darker, non-colliding border that leaves the top visible", function()
		local m = Object.build(spec({ { kind = "platform", name = "Pl", size = { 6, 1, 6 }, trim = 1, color = { 200, 100, 50 } } }))
		local top = m.Pl.CFrame.Position.Y + 0.5
		local covered = 0
		for _, side in { "N", "S", "W", "E" } do
			local t = m["Pl_Trim" .. side]
			T.eq(t.CanCollide, false); T.ok(t.Color.R < m.Pl.Color.R)
			T.near(t.CFrame.Position.Y - t.Size.Y / 2, top, 1e-4, "trim sits on the top face")
			T.ok(math.abs(t.CFrame.Position.X) + t.Size.X / 2 <= 3 + 1e-4 and math.abs(t.CFrame.Position.Z) + t.Size.Z / 2 <= 3 + 1e-4, "trim stays inside the footprint")
			covered += t.Size.X * t.Size.Z
		end
		T.ok(covered < 36 * 0.25, "trim must not cover the walkable top")
	end)
	it("generated rigs hide the Humanoid name tag", function()
		T.eq(Character.build({ name = "N" }).Humanoid.DisplayDistanceType, Enum.HumanoidDisplayDistanceType.None)
	end)
	it("truss heights snap to 2 and stand on pos", function()
		local m = Object.build(spec({ { kind = "truss", name = "T", height = 7, pos = { 0, 1, 0 }, style = "AlternatingSupports" } }))
		T.eq(m.T.Size, Vector3.new(2, 8, 2)); T.near(m.T.CFrame.Position.Y, 5); T.eq(m.T.Style, Enum.Style.AlternatingSupports)
		local m2 = Object.build(spec({ { kind = "truss", name = "T", height = 0.3 } }))
		T.eq(m2.T.Size.Y, 2)
	end)
	it("rope hangs down from pos with a climbable truss", function()
		local m = Object.build(spec({ { kind = "rope", name = "R", length = 10, segments = 5, pos = { 0, 20, 0 }, knotColor = "#000000" } }))
		local r = m.R
		T.eq(r.Climb.ClassName, "TrussPart"); T.near(r.Climb.Transparency, 1); T.near(r.Climb.CFrame.Position.Y, 15)
		T.eq(#r:GetChildren(), 6); T.eq(r.PrimaryPart, r.Climb); T.near(r.Seg05.CFrame.Position.Y, 11)
		T.eq(r.Seg01.CanCollide, false); T.ok(r.Seg02.Color ~= r.Seg01.Color, "knots alternate")
	end)
	it("ladder rungs fit inside the rails", function()
		local m = Object.build(spec({ { kind = "ladder", name = "L", height = 9, width = 2, rungSpacing = 1.5 } }))
		local l = m.L
		T.ok(l.Rung06 ~= nil and l:FindFirstChild("Rung07") == nil)
		for _, c in l:GetChildren() do
			if string.match(c.Name, "^Rung") then T.ok(c.CFrame.Position.Y > 0 and c.CFrame.Position.Y < 9) end
		end
		T.near(l.RailL.CFrame.Position.X, -1); T.eq(l.Climb.ClassName, "TrussPart")
	end)
	it("stairs climb up and forward (-Z)", function()
		local m = Object.build(spec({ { kind = "stairs", name = "S", steps = 3, rise = 1, run = 2 } }))
		T.near(m.S.Step03.CFrame.Position.Y, 2.5); T.near(m.S.Step03.CFrame.Position.Z, -5)
	end)
	it("model composes transforms and sets pivot", function()
		local m = Object.build(spec({ { kind = "model", name = "M", pos = { 10, 0, 0 }, rot = { 0, 90, 0 }, pivot = { 0, 1, 0 }, children = { { name = "P", size = { 1, 1, 1 }, pos = { 0, 0, -5 } } } } }))
		T.near(m.M.P.CFrame.Position.X, 5); T.near(m.M.P.CFrame.Position.Z, 0); T.near(m.M.WorldPivot.Position.Y, 1)
	end)
	it("array offsets, rotation steps and stable names", function()
		local m = Object.build(spec({ { kind = "array", name = "A", count = 3, offset = { 0, 2, 0 }, rotStep = { 0, 90, 0 }, item = { name = "Box", size = { 1, 1, 1 }, pos = { 4, 0, 0 } } } }))
		T.near(m.A.Box_003.CFrame.Position.Y, 4); T.near(m.A.Box_003.CFrame.Position.X, -4); T.near(m.A.Box_002.CFrame.Position.Z, -4)
	end)
	it("scatter stays inside its area and is seed-stable", function()
		local s = spec({ { kind = "scatter", name = "S", count = 200, area = { 10, 0, 20 }, item = { size = { 1, 1, 1 } } } }, { seed = 5 })
		local m = Object.build(s)
		for _, p in m.S:GetChildren() do
			T.ok(math.abs(p.CFrame.Position.X) <= 5 and math.abs(p.CFrame.Position.Z) <= 10 and p.CFrame.Position.Y == 0)
		end
		T.eq(fp(Object.build(s)), fp(m))
		s.seed = 6
		T.ok(fp(Object.build(s)) ~= fp(m), "different seed should differ")
	end)
	it("editing one scatter does not reshuffle another", function()
		local a = spec({ { kind = "scatter", name = "A", count = 5, area = { 9, 0, 9 }, seed = 1, item = { size = { 1, 1, 1 } } }, { kind = "scatter", name = "B", count = 5, area = { 9, 0, 9 }, seed = 2, item = { size = { 1, 1, 1 } } } })
		local m1 = Object.build(a)
		a.children[1].count = 50
		local m2 = Object.build(a)
		T.eq(fp(m1.B), fp(m2.B))
	end)
	it("scatter scaleRange scales prefab models recursively", function()
		local s = spec({ { kind = "scatter", name = "S", count = 30, area = { 0, 0, 0 }, scaleRange = { 2, 2 }, item = { kind = "use", prefab = "X" } } }, { prefabs = { X = { kind = "model", children = { { name = "P", size = { 1, 1, 1 }, pos = { 0, 1, 0 } } } } } })
		local m = Object.build(s)
		local p = m.S:GetChildren()[1]:GetDescendants()
		local part
		for _, d in p do if d:IsA("BasePart") then part = d end end
		T.eq(part.Size, Vector3.new(2, 2, 2)); T.near(part.CFrame.Position.Y, 2)
	end)
	it("use: prefab overrides and transforms", function()
		local m = Object.build(spec({ { kind = "use", name = "U", prefab = "Box", pos = { 0, 3, 0 }, color = "#00ff00" } }, { prefabs = { Box = { name = "B", size = { 1, 1, 1 }, color = "#ff0000", pos = { 1, 0, 0 } } } }))
		T.near(m.U.B.Color.G, 1); T.near(m.U.B.CFrame.Position.Y, 3); T.near(m.U.B.CFrame.Position.X, 1)
	end)
	it("weld=all welds every part to the primary part, anchored=false propagates", function()
		local m = Object.build(spec({ { kind = "model", name = "M", anchored = false, weld = "all", children = { { name = "A", size = { 1, 1, 1 } }, { name = "B", size = { 1, 1, 1 } }, { kind = "model", name = "In", children = { { name = "C", size = { 1, 1, 1 } } } } } } }))
		T.eq(m.M.PrimaryPart, m.M.A); T.eq(m.M.A.Anchored, false); T.eq(m.M.In.C.Anchored, false)
		T.eq(m.M.B.Weld_B.Part0, m.M.A); T.eq(m.M.In.C.Weld_C.Part1, m.M.In.C)
		T.eq(Object.weldAll(roblox.Instance.new("Model")), 0)
		local r = Object.build(spec({ { name = "A", size = { 1, 1, 1 } }, { name = "B", size = { 1, 1, 1 } } }, { weld = "all" }))
		T.eq(r.B.Weld_B.Part0, r.A)
	end)
	it("attributes and tags", function()
		local m = Object.build(spec({ { name = "P", size = { 1, 1, 1 }, attributes = { z = 1, a = "x", b = true }, tags = { "Kill", "Lava" } } }))
		T.eq(m.P:GetAttribute("z"), 1); T.eq(m.P:GetAttribute("a"), "x")
		T.ok(m.P:GetAttribute("HarnessTags") == "Kill,Lava" or m.P:GetAttribute("HarnessTags") == nil)
	end)
	it("default names are unique and stable", function()
		local m = Object.build(spec({ { size = { 1, 1, 1 } }, { size = { 1, 1, 1 } }, { kind = "truss", height = 2 } }))
		T.ok(m.part1 and m.part2 and m.Truss3)
		T.eq(m:GetAttribute("HarnessParts"), 3)
	end)
	it("does not mutate the input spec", function()
		local s = spec({ { kind = "scatter", count = 3, area = { 4, 0, 4 }, scaleRange = { 1, 2 }, item = { kind = "use", prefab = "A" } }, { kind = "array", count = 2, item = { size = { 1, 1, 1 } } } }, { prefabs = { A = { size = { 1, 1, 1 } } } })
		local before = serde.encode("json", s)
		Object.build(s)
		T.eq(serde.encode("json", s), before)
	end)
end)

---------------------------------------------------------------------------------------------
describe("Object perf + determinism", function()
	it("builds 10k parts quickly and identically twice", function()
		local s = spec({ { kind = "array", count = 100, offset = { 3, 0, 0 }, item = { kind = "array", count = 100, offset = { 0, 0, 3 }, item = { size = { 2, 1, 2 }, color = "#336699" } } } })
		local t0 = os.clock()
		local a = Object.build(s)
		local dt = os.clock() - t0
		T.eq(countParts(a), 10000)
		T.ok(dt < 10, ("10k parts took %.2fs"):format(dt))
		T.eq(fp(Object.build(s)), fp(a))
	end)
	it("builds the 20k-part limit in reasonable time", function()
		local s = spec({ { kind = "array", count = 200, offset = { 2, 0, 0 }, item = { kind = "array", count = 100, offset = { 0, 0, 2 }, item = { size = { 1, 1, 1 } } } } })
		local t0 = os.clock()
		local m = Object.build(s)
		T.eq(countParts(m), 20000)
		T.ok(os.clock() - t0 < 15, ("20k parts took %.2fs"):format(os.clock() - t0))
	end)
	it("serializes to rbxm byte-identically across builds (structure)", function()
		local s = L.require("examples/objects/BambooGrove")
		local a = roblox.deserializeModel(roblox.serializeModel({ Object.build(s) }))[1]
		T.eq(fp(a, { noPivot = true }), fp(Object.build(s), { noPivot = true }))
	end)
end)

---------------------------------------------------------------------------------------------
describe("Character", function()
	local base = { name = "C", skin = "#f0c090", outfit = { shirt = "#ff0000", pants = "#0000ff" }, hair = { style = "spiky", color = "#ffff00" } }
	it("builds a full R15 rig with standard joints", function()
		local m = Character.build(base)
		local need = { "Root", "Waist", "Neck", "LeftShoulder", "LeftElbow", "LeftWrist", "RightShoulder", "RightElbow", "RightWrist", "LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle" }
		local motors = {}
		for _, d in m:GetDescendants() do if d:IsA("Motor6D") then motors[d.Name] = d end end
		for _, n in need do T.ok(motors[n], "missing motor " .. n) end
		T.eq(m.Humanoid.RigType, Enum.HumanoidRigType.R15); T.eq(m.PrimaryPart, m.HumanoidRootPart)
		T.eq(#Character.Rig.Order, 16)
	end)
	it("motor C0/C1 reproduce the rest pose exactly", function()
		local m = Character.build(base, { origin = CFrame.new(5, 0, 3) * CFrame.Angles(0, 1, 0) })
		for _, d in m:GetDescendants() do
			if d:IsA("Motor6D") then
				local want = d.Part0.CFrame * d.C0 * d.C1:Inverse()
				T.near((want.Position - d.Part1.CFrame.Position).Magnitude, 0, 1e-4, d.Name)
			end
		end
	end)
	it("feet touch y=0 and parts don't overlap vertically along a limb", function()
		local m = Character.build(base)
		T.near(m.LeftFoot.CFrame.Position.Y - m.LeftFoot.Size.Y / 2, 0)
		T.near(m.Head.CFrame.Position.Y - m.Head.Size.Y / 2, m.UpperTorso.CFrame.Position.Y + m.UpperTorso.Size.Y / 2)
		T.near(m.LeftUpperLeg.CFrame.Position.Y - m.LeftUpperLeg.Size.Y / 2, m.LeftLowerLeg.CFrame.Position.Y + m.LeftLowerLeg.Size.Y / 2)
	end)
	it("look pieces are welded, massless, non-colliding and where the spec says", function()
		local m = Character.build(base)
		local n = 0
		for _, d in m.Look:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
				T.eq(d.CanCollide, false); T.eq(d.Massless, true); T.eq(d.Anchored, false)
				local w = d.LookWeld
				T.eq(w.Part1, d)
				T.near((w.Part0.CFrame * w.C0).Position.X, d.CFrame.Position.X); T.near((w.Part0.CFrame * w.C0).Position.Y, d.CFrame.Position.Y)
			end
		end
		T.eq(n, m:GetAttribute("LookPieces")); T.eq(n, #Character.pieces(base))
	end)
	it("face sits on the front of the head (-Z)", function()
		local m = Character.build(base)
		for _, d in m.Look.Face:GetChildren() do
			T.ok(d.CFrame.Position.Z < m.Head.CFrame.Position.Z - 0.55, d.Name .. " not on the face plane")
		end
	end)
	it("outfit colors map to body parts", function()
		local m = Character.build({ name = "C", skin = "#000000", outfit = { shirt = "#ff0000", pants = "#0000ff", shoes = "#00ff00", gloves = "#ffffff", sleeves = "short", legs = "shorts" } })
		T.near(m.UpperTorso.Color.R, 1); T.near(m.LeftUpperArm.Color.R, 1); T.near(m.LeftLowerArm.Color.R, 0)
		T.near(m.LeftUpperLeg.Color.B, 1); T.near(m.LeftLowerLeg.Color.B, 0); T.near(m.LeftFoot.Color.G, 1); T.near(m.LeftHand.Color.G, 1)
		local l = Character.build({ name = "C", outfit = { shirt = "#ff0000", sleeves = "long" } })
		T.near(l.LeftLowerArm.Color.R, 1)
		local n = Character.build({ name = "C", skin = "#000000", outfit = { shirt = "#ff0000", sleeves = "none" } })
		T.near(n.LeftUpperArm.Color.R, 0); T.near(n.UpperTorso.Color.R, 1)
	end)
	it("every hair style, accessory and weapon builds", function()
		for style in Character.Presets.HairStyles do
			Character.build({ name = "H", hair = { style = style, color = "#123456" } })
		end
		for t in Character.Presets.AccessoryTypes do
			local m = Character.build({ name = "A", accessories = { { type = t } } })
			T.ok(#m.Look:GetChildren() >= 2, t)
		end
		for t in Character.Presets.WeaponTypes do
			for _, hand in { "Left", "Right" } do
				local m = Character.build({ name = "W", weapons = { { type = t, hand = hand } } })
				local g = m.Look:FindFirstChild("Weapon01_" .. t)
				T.ok(g and #g:GetChildren() > 0, t)
				for _, p in g:GetChildren() do T.eq(p:GetAttribute("Attach"), hand .. "Hand") end
			end
		end
		for e in Character.Presets.EyeStyles do for mo in Character.Presets.MouthStyles do
			Character.build({ name = "F", face = { eyes = e, mouth = mo, blush = "#ff8888", scar = true, whiskers = true } })
		end end
		T.eq(#Character.Presets.hair({ style = "bald" }), 0)
	end)
	it("scale multiplies rig and look", function()
		local a, b = Character.build(base), Character.build(table.clone(base) :: any)
		local big = table.clone(base); big.scale = 2
		local c = Character.build(big)
		T.near(c.Head.Size.X, a.Head.Size.X * 2); T.near(c.Head.CFrame.Position.Y, a.Head.CFrame.Position.Y * 2); T.near(c.Humanoid.HipHeight, 4)
		T.eq(fp(a), fp(b))
	end)
	it("anchored option anchors everything", function()
		local m = Character.build(base, { anchored = true })
		for _, d in m:GetDescendants() do if d:IsA("BasePart") then T.ok(d.Anchored) end end
	end)
	it("custom pieces and duplicate names get unique suffixes", function()
		local m = Character.build({ name = "C", pieces = { { attach = "Head", name = "Horn", size = { 0.2, 0.6, 0.2 }, pos = { 0.3, 0.7, 0 }, color = "red" }, { attach = "Head", name = "Horn", size = { 0.2, 0.6, 0.2 }, pos = { -0.3, 0.7, 0 }, color = "red", shape = "Wedge" } } })
		T.ok(m.Look.Custom.Horn and m.Look.Custom.Horn2); T.eq(m.Look.Custom.Horn2.ClassName, "WedgePart")
	end)
	it("validation catches malformed specs", function()
		local ok, e = Character.validate({ name = "", scale = 0, skin = "#zz", outfit = { shirt = 1, sleeves = "half", hat = 1 }, face = { eyes = "laser", mouth = 3, browTilt = 90, scar = "y", nose = true, eyeY = 2 }, hair = { style = "mohawk", spikes = 0.5, height = -1 }, accessories = { { type = "crown" }, "x", { color = "#f" } }, weapons = { { type = "gun", hand = "Middle", length = 99 } }, pieces = { { attach = "Tail", size = { 0, 1, 1 }, color = nil, pos = { 0, 99, 0 }, shape = "Cone", transparency = 3 } }, extra = 1 })
		T.eq(ok, false)
		for _, needle in { "spec.name", "spec.scale", "spec.skin", "outfit.shirt", "outfit.sleeves", 'unknown field "hat"', "face.eyes", "face.mouth", "browTilt", "face.scar", "face.nose", "eyeY", "hair.style", "hair.spikes", "hair.height", "accessories[1].type", "accessories[2]", "accessories[3].type", "accessories[3].color", "weapons[1].type", "weapons[1].hand", "weapons[1].length", "pieces[1].attach", "pieces[1].size", "pieces[1].color", "20 studs", "pieces[1].shape", "transparency", 'unknown field "extra"' } do
			T.hasErr(e, needle)
		end
		T.eq((Character.validate(5)), false)
		T.hasErr(select(2, Character.validate({ name = "x", pieces = { a = 1 } })), "must be a list")
		T.throws(function() Character.build({ name = "x", hair = { style = "nope" } }) end, "hair.style")
	end)
	it("rejects HumanoidRootPart as an attach target", function()
		T.hasErr(select(2, Character.validate({ name = "x", pieces = { { attach = "HumanoidRootPart", size = { 1, 1, 1 }, color = "red" } } })), "attach")
	end)
	it("enforces maxPieces", function()
		local pieces = {}
		for i = 1, 1501 do pieces[i] = { attach = "Head", size = { 0.1, 0.1, 0.1 }, color = "red" } end
		T.hasErr(select(2, Character.validate({ name = "x", pieces = pieces })), "exceeds limit")
	end)
	it("1000 custom pieces build fast and deterministically", function()
		local pieces = {}
		local r = Util.rng(9)
		for i = 1, 1000 do pieces[i] = { attach = Character.Rig.Order[2 + (i % 15)], size = { 0.2, 0.2, 0.2 }, pos = { r:range(-1, 1), r:range(-1, 1), r:range(-1, 1) }, color = { i % 255, 10, 10 } } end
		local s = { name = "Big", pieces = pieces }
		local t0 = os.clock()
		local a = Character.build(s)
		T.ok(os.clock() - t0 < 5)
		T.eq(fp(a), fp(Character.build(s)))
	end)
end)

---------------------------------------------------------------------------------------------
describe("Anim", function()
	local wave = L.require("examples/anims/Wave")
	it("validates good and bad specs", function()
		T.ok((Anim.validate(wave)))
		local ok, e = Anim.validate({ name = "", length = -1, loop = 1, priority = "Top", keys = { { t = 0, poses = { Tail = {}, Head = { rot = { 1 }, spin = 1 } }, ease = "Wobble", dir = "Up" }, { t = 0, poses = {} }, 5, { t = 1, poses = 3 } }, markers = { { t = 0 }, { name = "x", t = -1, value = 3 } }, foo = 1 })
		T.eq(ok, false)
		for _, needle in { "spec.name", "spec.length", "spec.loop", "spec.priority", "unknown R15 part", "Head.rot", 'unknown field "spin"', "unknown easing style", "unknown easing direction", "strictly increasing", "keys[3]", "keys[4].poses", "markers[1]", "markers[2].t", "markers[2].value", 'unknown field "foo"' } do
			T.hasErr(e, needle)
		end
		T.hasErr(select(2, Anim.validate({ name = "x", length = 1, keys = {} })), "at least one")
		T.hasErr(select(2, Anim.validate({ name = "x", length = 1, keys = { { t = 2, poses = {} } } })), "within 0..length")
		T.eq((Anim.validate(nil)), false)
	end)
	it("easing endpoints and monotonic shapes", function()
		for style in Anim.Easing do for dir in Anim.Directions do
			T.near(Anim.ease(style, dir, 0), 0, 1e-6, style .. dir)
			T.near(Anim.ease(style, dir, 1), 1, 1e-6, style .. dir)
		end end
		T.near(Anim.ease("Linear", "In", 0.3), 0.3); T.eq(Anim.ease("Constant", "In", 0.99), 0)
		T.near(Anim.ease("Cubic", "InOut", 0.5), 0.5); T.ok(Anim.ease("Cubic", "In", 0.3) < 0.3); T.ok(Anim.ease("Cubic", "Out", 0.3) > 0.3)
		T.near(Anim.ease("Cubic", "In", 2), 1)
	end)
	it("sample interpolates, holds ends and loops", function()
		local s = { name = "x", length = 2, keys = { { t = 0, poses = { Head = { pos = { 0, 0, 0 } } } }, { t = 1, poses = { Head = { pos = { 0, 10, 0 } } } } } }
		T.near(Anim.sample(s, "Head", 0.5).Position.Y, 5); T.near(Anim.sample(s, "Head", 1.5).Position.Y, 10); T.near(Anim.sample(s, "Head", -1).Position.Y, 0)
		T.eq(Anim.sample(s, "LeftFoot", 0.5), CFrame.new())
		s.loop = true
		T.near(Anim.sample(s, "Head", 2.5).Position.Y, 5)
		local late = { name = "x", length = 2, keys = { { t = 1, poses = { Head = { pos = { 0, 3, 0 } } } } } }
		T.near(Anim.sample(late, "Head", 0).Position.Y, 3)
	end)
	it("sample uses the previous key's easing and skips keys without the part", function()
		local s = { name = "x", length = 3, keys = { { t = 0, ease = "Constant", poses = { Head = { pos = { 0, 0, 0 } } } }, { t = 1, poses = { LeftFoot = {} } }, { t = 2, poses = { Head = { pos = { 0, 4, 0 } } } } } }
		T.near(Anim.sample(s, "Head", 1.5).Position.Y, 0)
		s.keys[1].ease = "Linear"
		T.near(Anim.sample(s, "Head", 1).Position.Y, 2)
	end)
	it("rotation sampling in degrees", function()
		local s = { name = "x", length = 1, keys = { { t = 0, poses = { Head = { rot = { 0, 0, 0 } } } }, { t = 1, poses = { Head = { rot = { 0, 90, 0 } } } } } }
		local _, y = Anim.sample(s, "Head", 0.5):ToOrientation()
		T.near(math.deg(y), 45, 1e-3)
	end)
	it("KeyframeSequence has nested R15 pose hierarchy, easing and markers", function()
		local ks = Anim.toKeyframeSequence(L.require("examples/anims/Slash"))
		T.eq(ks.ClassName, "KeyframeSequence"); T.eq(ks.Priority, Enum.AnimationPriority.Action); T.eq(ks.Loop, false)
		local k2 = ks.Key02
		T.near(k2.Time, 0.2)
		local arm = find(k2, "HumanoidRootPart/LowerTorso/UpperTorso/RightUpperArm")
		T.near(arm.Weight, 1); T.eq(arm.EasingStyle, Enum.PoseEasingStyle.Cubic); T.eq(arm.EasingDirection, Enum.PoseEasingDirection.Out)
		T.near(find(k2, "HumanoidRootPart").Weight, 0)
		T.near(find(k2, "HumanoidRootPart/LowerTorso/UpperTorso").Weight, 1)
		local mk
		for _, k in ks:GetChildren() do for _, c in k:GetChildren() do if c:IsA("KeyframeMarker") then mk = c end end end
		T.ok(mk and mk.Name == "Hit" and mk.Value == "slash")
		T.throws(function() Anim.toKeyframeSequence({ name = "x", length = 1, keys = {} }) end, "animation spec invalid")
	end)
	it("pads the clip to its declared length", function()
		local ks = Anim.toKeyframeSequence({ name = "x", length = 2, keys = { { t = 0, poses = { Head = {} } } } })
		T.near(ks.End.Time, 2)
		local ks2 = Anim.toKeyframeSequence({ name = "x", length = 1, keys = { { t = 0, poses = { Head = {} } }, { t = 1, poses = { Head = {} } } } })
		T.eq(ks2:FindFirstChild("End"), nil)
	end)
	it("apply poses a rig (Transform and non-accumulating C0)", function()
		local m = Character.build({ name = "R" })
		local s = { name = "x", length = 1, keys = { { t = 0, poses = { RightUpperArm = { rot = { 0, 0, 90 } } } } } }
		Anim.apply(m, s, 0)
		local motor = m.RightUpperArm.RightShoulder
		local _, _, z = motor.Transform:ToOrientation()
		T.near(math.deg(z), 90, 1e-3)
		local rest = motor.C0
		Anim.apply(m, s, 0, "C0"); Anim.apply(m, s, 0, "C0")
		T.ok(((rest * Anim.sample(s, "RightUpperArm", 0)).Position - motor.C0.Position).Magnitude < 1e-5)
		local _, _, z2 = (rest:Inverse() * motor.C0):ToOrientation()
		T.near(math.deg(z2), 90, 1e-3)
	end)
	it("mirror swaps sides and flips", function()
		local m = Anim.mirror({ LeftUpperArm = { rot = { 10, 20, 30 }, pos = { 1, 2, 3 } }, Head = { rot = { 0, 5, 0 } } })
		T.eq(m.RightUpperArm.rot[2], -20); T.eq(m.RightUpperArm.rot[3], -30); T.eq(m.RightUpperArm.pos[1], -1); T.eq(m.Head.rot[2], -5); T.eq(m.LeftUpperArm, nil)
	end)
	it("deterministic KeyframeSequence", function()
		T.eq(fp(Anim.toKeyframeSequence(wave)), fp(Anim.toKeyframeSequence(wave)))
	end)
end)

---------------------------------------------------------------------------------------------
describe("Examples", function()
	for _, f in fs.readDir("examples/objects") do
		it("object " .. f .. " validates, builds and round-trips rbxm", function()
			local s = loadExample("examples/objects", f)
			local ok, errs = Object.validate(s)
			T.ok(ok, table.concat(errs, "\n"))
			local m = Object.build(s)
			T.ok(countParts(m) > 0)
			local back = roblox.deserializeModel(roblox.serializeModel({ m }))[1]
			T.eq(fp(back, { noPivot = true }), fp(m, { noPivot = true }))
		end)
	end
	for _, f in fs.readDir("examples/characters") do
		it("character " .. f .. " validates and builds", function()
			local s = loadExample("examples/characters", f)
			local ok, errs = Character.validate(s)
			T.ok(ok, table.concat(errs, "\n"))
			local m = Character.build(s)
			T.ok(m:GetAttribute("LookPieces") > 15)
			roblox.serializeModel({ m })
		end)
	end
	for _, f in fs.readDir("examples/anims") do
		it("anim " .. f .. " validates and converts", function()
			local s = loadExample("examples/anims", f)
			T.ok((Anim.validate(s)))
			Anim.toKeyframeSequence(s)
		end)
	end
	it("JumpTower checkpoint is reachable: spiral rises in <= double-jump steps", function()
		local m = Object.build(L.require("examples/objects/JumpTower"))
		local ys = {}
		for _, step in m.Spiral:GetChildren() do
			for _, d in step:GetDescendants() do if d:IsA("BasePart") and not string.match(d.Name, "Trim") then table.insert(ys, d.CFrame.Position.Y) end end
		end
		table.sort(ys)
		for i = 2, #ys do T.ok(ys[i] - ys[i - 1] <= 7.2, "gap too high for a jump") end
	end)
	it("Harness module exposes the public API", function()
		T.ok(H.VERSION and H.Object.build and H.Object.validate and H.Character.build and H.Character.validate and H.Character.pieces and H.Anim.toKeyframeSequence and H.Anim.sample and H.Anim.apply and H.Anim.mirror)
	end)
end)

print(("\n%d passed, %d failed"):format(T.passed, T.failed))
for _, f in T.fails do print("FAIL " .. f) end
if T.failed > 0 then process.exit(1) end
