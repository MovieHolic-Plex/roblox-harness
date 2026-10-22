-- Stable text dump of an Instance tree (class, name, key properties, rounded) for determinism tests.
local function r(n: number): string
	if math.abs(n) < 5e-5 then return "0.0000" end
	return string.format("%.4f", n)
end
local function v3(v): string return r(v.X) .. "," .. r(v.Y) .. "," .. r(v.Z) end
local function cf(c): string
	local t = { c:GetComponents() }
	local o = {}
	for i, x in t do o[i] = r(x) end
	return table.concat(o, ",")
end
local noPivot = false
local function walk(i, depth: number, out: { string })
	local line = string.rep(" ", depth) .. i.ClassName .. ":" .. i.Name
	if i:IsA("BasePart") then
		line ..= (" s=%s cf=%s c=%s m=%s a=%s cc=%s t=%s"):format(v3(i.Size), cf(i.CFrame), tostring(i.Color), tostring(i.Material), tostring(i.Anchored), tostring(i.CanCollide), r(i.Transparency))
	elseif i:IsA("Motor6D") or i:IsA("Weld") then
		line ..= (" p0=%s p1=%s c0=%s c1=%s"):format(i.Part0 and i.Part0.Name or "nil", i.Part1 and i.Part1.Name or "nil", cf(i.C0), cf(i.C1))
	elseif i:IsA("WeldConstraint") then
		line ..= (" p0=%s p1=%s"):format(i.Part0 and i.Part0.Name or "nil", i.Part1 and i.Part1.Name or "nil")
	elseif i:IsA("Model") then
		local ok, pv = pcall(function() return i.WorldPivot end)
		if ok and not noPivot then line ..= " pivot=" .. cf(pv) end
	elseif i:IsA("Pose") then
		line ..= (" w=%s cf=%s e=%s"):format(r(i.Weight), cf(i.CFrame), tostring(i.EasingStyle))
	elseif i:IsA("Keyframe") then
		line ..= " t=" .. r(i.Time)
	end
	local attrs = i:GetAttributes()
	local keys = {}
	for k in attrs do table.insert(keys, k) end
	table.sort(keys)
	for _, k in keys do line ..= (" @%s=%s"):format(k, tostring(attrs[k])) end
	table.insert(out, line)
	for _, c in i:GetChildren() do walk(c, depth + 1, out) end
end
return function(inst, opts: any?): string
	noPivot = opts ~= nil and opts.noPivot == true
	local out = {}
	walk(inst, 0, out)
	return table.concat(out, "\n")
end
