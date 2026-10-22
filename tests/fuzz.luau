-- Adversarial fuzzing: random (mostly malformed) specs must never crash validate(), and any spec
-- validate() accepts must build without error. lune run tests/fuzz.luau [iterations]
local process = require("@lune/process")
local L = require("../tools/load")
local H = L.harness("src/Harness")
local Util = H.Util

local N = tonumber(process.args[1]) or 3000
local r = Util.rng(12345)
local function pick(t) return t[1 + math.floor(r:next() * #t)] end
local weird = { 0, -1, 1, 0.5, 1e9, -1e9, 0 / 0, math.huge, "x", "", true, false, {}, { 1 }, { 1, 2, 3 }, { 0, 0, 0 }, { -1, 2, 3 }, { "a", "b", "c" } }
local goodVec = function() return { r:range(-20, 20), r:range(-20, 20), r:range(-20, 20) } end
local posVec = function() return { r:range(0.1, 8), r:range(0.1, 8), r:range(0.1, 8) } end
local kinds = { "part", "wedge", "cornerwedge", "platform", "truss", "rope", "ladder", "stairs", "model", "array", "scatter", "use", "part", "model" }
local materials = { "Wood", "Grass", "Neon", "Plastic", "Slate", "Wood", "Nope" }
local colors = { "#ff0000", "red", { 1, 2, 3 }, "#00ff00", "blue", "#zzz" }

local function maybe(v) if r:next() < 0.93 then return v end return pick(weird) end

local function node(depth: number): any
	local k = pick(kinds)
	local n: any = { kind = k }
	if r:next() < 0.7 then n.size = maybe(posVec()) end
	if r:next() < 0.5 then n.pos = maybe(goodVec()) end
	if r:next() < 0.3 then n.rot = maybe(goodVec()) end
	if r:next() < 0.3 then n.material = pick(materials) end
	if r:next() < 0.3 then n.color = pick(colors) end
	if r:next() < 0.1 then n.anchored = maybe(false) end
	if r:next() < 0.05 then n.typo = 1 end
	n.height = maybe(r:range(1, 20)); n.length = maybe(r:range(1, 20)); n.steps = maybe(1 + math.floor(r:next() * 5))
	n.count = maybe(1 + math.floor(r:next() * 4)); n.area = maybe(posVec()); n.segments = maybe(1 + math.floor(r:next() * 4))
	if k == "model" and depth < 4 then n.children = { node(depth + 1), node(depth + 1) } end
	if (k == "array" or k == "scatter") and depth < 4 then n.item = node(depth + 1) end
	if k == "use" then n.prefab = pick({ "A", "B", "Missing" }) end
	if k ~= "platform" then n.trim = nil end
	-- strip fields the kind does not accept most of the time so some specs are valid
	if r:next() < 0.95 and H.Object.Kinds[k] then
		for _, f in ipairs({ "size", "height", "length", "steps", "count", "area", "segments", "item", "children", "prefab" }) do
			if not H.Object.Kinds[k][f] then n[f] = nil end
		end
	end
	return n
end

local valid, invalid = 0, 0
for i = 1, N do
	local spec = { name = "F" .. i, seed = r:next() * 1000, children = { node(0), node(0), node(0) },
		prefabs = { A = node(2), B = { kind = "use", prefab = (r:next() < 0.9) and "A" or "B" } } }
	local ok, res, errs = pcall(H.Object.validate, spec)
	if not ok then
		print("VALIDATE CRASH", i, res); process.exit(1)
	end
	if res then
		valid += 1
		local bok, berr = pcall(H.Object.build, spec)
		if not bok then print("BUILD CRASH on valid spec", i, berr); process.exit(1) end
	else
		invalid += 1
		local bok, berr = pcall(H.Object.build, spec)
		if bok or not string.find(tostring(berr), "spec invalid", 1, true) then print("BUILD did not reject invalid spec", i, berr); process.exit(1) end
	end
	-- character + anim fuzz
	local cs: any = { name = maybe("C"), scale = maybe(r:range(0.3, 3)), skin = pick(colors),
		hair = { style = pick({ "spiky", "long", "x", "afro" }), color = pick(colors), spikes = maybe(3) },
		face = { eyes = pick({ "round", "sharp", "zz" }), mouth = pick({ "grin", "flat", 3 }) },
		accessories = { { type = pick({ "cape", "strawHat", "nope" }), color = pick(colors) } },
		weapons = { { type = pick({ "katana", "staff", "gun" }), hand = pick({ "Left", "Right", "Both" }) } },
		pieces = { { attach = pick({ "Head", "LeftFoot", "Tail" }), size = maybe(posVec()), pos = maybe(goodVec()), color = pick(colors) } } }
	local cok, cres = pcall(H.Character.validate, cs)
	if not cok then print("CHAR VALIDATE CRASH", i, cres); process.exit(1) end
	if cres then
		local bok, berr = pcall(H.Character.build, cs)
		if not bok then print("CHAR BUILD CRASH", i, berr); process.exit(1) end
	end
	local as: any = { name = "A", length = maybe(r:range(0.1, 3)), loop = maybe(true), keys = { { t = maybe(0), poses = { Head = { rot = maybe(goodVec()) } } }, { t = maybe(r:range(0, 3)), ease = pick({ "Cubic", "Bounce", "Foo" }), poses = { [pick({ "LeftHand", "Nope" })] = { pos = maybe(goodVec()) } } } } }
	local aok, ares = pcall(H.Anim.validate, as)
	if not aok then print("ANIM VALIDATE CRASH", i, ares); process.exit(1) end
	if ares then
		local bok, berr = pcall(H.Anim.toKeyframeSequence, as)
		if not bok then print("ANIM BUILD CRASH", i, berr); process.exit(1) end
		for _, t in { -1, 0, 0.5, 99 } do H.Anim.sample(as, "Head", t) end
	end
end
print(("fuzz ok: %d object specs (%d valid, %d invalid) + character + anim"):format(N, valid, invalid))
