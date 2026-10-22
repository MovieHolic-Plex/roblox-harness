-- Minimal test framework for Lune.
local T = { passed = 0, failed = 0, fails = {} }
local current = ""
function T.describe(name: string, fn: () -> ())
	current = name
	fn()
end
function T.it(name: string, fn: () -> ())
	local ok, e = pcall(fn)
	if ok then
		T.passed += 1
	else
		T.failed += 1
		table.insert(T.fails, ("%s > %s\n    %s"):format(current, name, tostring(e)))
	end
end
function T.eq(a: any, b: any, msg: string?)
	if a ~= b then error(("%sexpected %s, got %s"):format(msg and (msg .. ": ") or "", tostring(b), tostring(a)), 2) end
end
function T.ok(v: any, msg: string?)
	if not v then error(msg or "expected truthy", 2) end
end
function T.near(a: number, b: number, eps: number?, msg: string?)
	if math.abs(a - b) > (eps or 1e-4) then error(("%sexpected %.5f ~ %.5f"):format(msg and (msg .. ": ") or "", a, b), 2) end
end
function T.throws(fn: () -> (), pattern: string?)
	local ok, e = pcall(fn)
	if ok then error("expected an error", 2) end
	if pattern and not string.find(tostring(e), pattern, 1, true) then
		error(("error %q does not contain %q"):format(tostring(e), pattern), 2)
	end
end
-- assert that one of the validation errors contains `needle`
function T.hasErr(errs: { string }, needle: string)
	for _, e in errs do
		if string.find(e, needle, 1, true) then return end
	end
	error(("no error containing %q in:\n      %s"):format(needle, table.concat(errs, "\n      ")), 2)
end
return T
