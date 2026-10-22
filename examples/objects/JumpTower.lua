--!nonstrict
-- A vertical jump-climb stage piece: spiral platforms, a truss, a hanging rope and a checkpoint.
return {
	name = "JumpTower",
	seed = 7,
	prefabs = {
		Ledge = { kind = "platform", size = { 6, 1, 6 }, color = "#7a5c3a", material = "WoodPlanks", trim = 1, trimColor = "#4a3520" },
	},
	children = {
		{ kind = "part", name = "Base", size = { 24, 2, 24 }, pos = { 0, 1, 0 }, color = "#5c8a3c", material = "Grass" },
		{ kind = "part", name = "Core", shape = "Cylinder", size = { 40, 6, 6 }, pos = { 0, 22, 0 }, rot = { 0, 0, 90 }, color = "#8a7f72", material = "Slate" },
		{
			kind = "array", name = "Spiral", count = 9, offset = { 0, 4.5, 0 }, rotStep = { 0, 45, 0 },
			item = { kind = "model", name = "Step", children = { { kind = "use", prefab = "Ledge", pos = { 7, 4, 0 } } } },
		},
		{ kind = "truss", name = "Truss", height = 14, pos = { -4, 2, -6 } },
		{ kind = "part", name = "RopeArm", size = { 1.2, 1.2, 6 }, pos = { 0, 38.6, -5.5 }, color = "#5a3d22", material = "Wood" },
		{ kind = "rope", name = "Rope", length = 12, segments = 6, thickness = 0.4, pos = { 0, 38, -8 }, color = "#b08a55", knotColor = "#8a6a40" },
		{
			kind = "platform", name = "Checkpoint", size = { 8, 1, 8 }, pos = { 0, 42.5, 0 }, color = "#2f6fd6", material = "Neon",
			attributes = { Checkpoint = 1 }, tags = { "Checkpoint" },
		},
	},
}
