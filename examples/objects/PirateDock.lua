--!nonstrict
-- Stage piece with mixed parts: dock, stairs, ladder, an unanchored crate stack welded together.
return {
	name = "PirateDock",
	children = {
		{ kind = "part", name = "Water", size = { 50, 1, 50 }, pos = { 0, -1, 0 }, color = "#2a6f9e", material = "Glass", transparency = 0.3, canCollide = false },
		{ kind = "array", name = "Planks", count = 10, offset = { 0, 0, 2.05 }, item = { kind = "part", name = "Plank", size = { 12, 0.6, 2 }, pos = { 0, 2, -9 }, color = "#8b5a2b", material = "WoodPlanks" } },
		{ kind = "array", name = "Posts", count = 4, offset = { 0, 0, 6.5 }, item = { kind = "part", name = "Post", shape = "Cylinder", size = { 5, 1, 1 }, pos = { 6.2, 0.5, -9.5 }, rot = { 0, 0, 90 }, color = "#5a3a1e", material = "Wood" } },
		{ kind = "stairs", name = "Stairs", steps = 6, rise = 1, run = 1.6, width = 5, pos = { -3, 2.3, -10 }, color = "#a0703c", material = "WoodPlanks" },
		{ kind = "part", name = "Deck", size = { 10, 1, 8 }, pos = { -3, 7.8, -23.6 }, color = "#7a4e26", material = "WoodPlanks" },
		{ kind = "ladder", name = "Ladder", height = 9.5, width = 2, pos = { 4, 2.3, 9.6 }, color = "#c08850", railColor = "#6b4423" },
		{
			kind = "array", name = "LookoutPostsL", count = 2, offset = { 0, 0, 5 },
			item = { kind = "part", name = "LPost", size = { 0.8, 12.3, 0.8 }, pos = { 1.6, 5.15, 10.5 }, color = "#5a3a1e", material = "Wood" },
		},
		{
			kind = "array", name = "LookoutPostsR", count = 2, offset = { 0, 0, 5 },
			item = { kind = "part", name = "RPost", size = { 0.8, 12.3, 0.8 }, pos = { 6.4, 5.15, 10.5 }, color = "#5a3a1e", material = "Wood" },
		},
		{
			kind = "array", name = "DeckPosts", count = 2, offset = { 9, 0, 0 },
			item = { kind = "part", name = "DPost", size = { 0.8, 8.3, 0.8 }, pos = { -7.5, 3.15, -26.8 }, color = "#5a3a1e", material = "Wood" },
		},
		{ kind = "part", name = "Lookout", size = { 6, 1, 6 }, pos = { 4, 11.8, 13 }, color = "#7a4e26", material = "WoodPlanks" },
		{
			kind = "model", name = "CrateStack", anchored = false, weld = "all", pos = { -2.5, 2.3, 4 },
			children = {
				{ kind = "part", name = "CrateA", size = { 3, 3, 3 }, pos = { 0, 1.5, 0 }, color = "#b5824a", material = "WoodPlanks" },
				{ kind = "part", name = "CrateB", size = { 2.5, 2.5, 2.5 }, pos = { 0.2, 4.25, 0.1 }, rot = { 0, 20, 0 }, color = "#a8763e", material = "WoodPlanks" },
				{ kind = "part", name = "Barrel", shape = "Cylinder", size = { 2.6, 2, 2 }, pos = { 2.6, 1.3, 0.5 }, rot = { 0, 0, 90 }, color = "#6e4422", material = "Wood" },
			},
		},
		{ kind = "part", name = "Flag", size = { 0.1, 2, 3 }, pos = { 4, 15, 14.6 }, color = "#141414", material = "Fabric" },
		{ kind = "part", name = "Mast", shape = "Cylinder", size = { 5, 0.3, 0.3 }, pos = { 4, 14.3, 13 }, rot = { 0, 0, 90 }, color = "#5a3a1e", material = "Wood" },
	},
}
