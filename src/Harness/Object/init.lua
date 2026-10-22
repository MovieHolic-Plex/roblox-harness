--!strict
-- Object generation harness: declarative spec -> Model.
--   local Object = require(Harness.Object)
--   local model = Object.build(spec)      -- validates first, errors list every problem
--   local ok, errs = Object.validate(spec)
local Validate = require(script.Validate)
local Build = require(script.Build)
local Util = require(script.Parent.Util)

local Object = {}
Object.Kinds = Validate.Kinds
Object.Limits = Validate.Limits

function Object.validate(spec: any): (boolean, { string }, number)
	return Validate.spec(spec)
end

-- opts.origin: CFrame applied on top of spec.pivot (works in Lune, which has no PivotTo).
function Object.build(spec: any, parent: Instance?, opts: { origin: CFrame? }?): Model
	local ok, errs = Validate.spec(spec)
	if not ok then Util.raise("object", errs) end
	local m = Build.build(spec, opts and opts.origin)
	if parent then m.Parent = parent end
	return m
end

Object.weldAll = Build.weldAll

return Object
