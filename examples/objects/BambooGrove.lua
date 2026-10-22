--!nonstrict
-- Deterministic prop scatter: bamboo stalks with leaves and rocks. Same seed => same layout.
return {
	name = "BambooGrove",
	seed = 2026,
	prefabs = {
		Stalk = {
			kind = "model", name = "Bamboo", weld = "all",
			children = {
				{ kind = "part", name = "Stem", shape = "Cylinder", size = { 12, 0.7, 0.7 }, pos = { 0, 6, 0 }, rot = { 0, 0, 90 }, color = "#6f9a3b", material = "Wood" },
				{ kind = "array", name = "Nodes", count = 4, offset = { 0, 2.8, 0 }, item = { kind = "part", name = "Node", shape = "Cylinder", size = { 0.25, 0.8, 0.8 }, pos = { 0, 2, 0 }, rot = { 0, 0, 90 }, color = "#4f7a2a", material = "Wood" } },
				{ kind = "wedge", name = "Leaf", size = { 0.1, 1.2, 2.2 }, pos = { 0.6, 11.2, 0 }, rot = { 20, 0, -30 }, color = "#86c04a", material = "Grass", canCollide = false },
				{ kind = "wedge", name = "Leaf", size = { 0.1, 1.2, 2.2 }, pos = { -0.6, 10.4, 0.2 }, rot = { -20, 180, 30 }, color = "#79b043", material = "Grass", canCollide = false },
			},
		},
		Rock = { kind = "part", name = "Rock", shape = "Ball", size = { 2, 2, 2 }, color = "#8d8a80", material = "Rock" },
	},
	children = {
		{ kind = "part", name = "Ground", size = { 40, 1, 40 }, pos = { 0, -0.5, 0 }, color = "#4d7a34", material = "Grass" },
		{ kind = "scatter", name = "Stalks", count = 40, area = { 34, 0, 34 }, seed = 1, scaleRange = { 0.7, 1.3 }, item = { kind = "use", prefab = "Stalk" } },
		{ kind = "scatter", name = "Rocks", count = 12, area = { 36, 0, 36 }, seed = 2, jitterRot = { 30, 360, 30 }, scaleRange = { 0.5, 1.6 }, item = { kind = "use", prefab = "Rock" } },
	},
}
