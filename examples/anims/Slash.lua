--!nonstrict
-- Wind-up -> strike -> recover, with a "Hit" marker the game can listen to.
return {
	name = "Slash", length = 0.8, priority = "Action",
	keys = {
		{ t = 0, poses = { UpperTorso = { rot = { 0, 0, 0 } }, RightUpperArm = { rot = { 0, 0, 0 } } } },
		{ t = 0.2, ease = "Cubic", dir = "Out", poses = { UpperTorso = { rot = { 0, 35, 0 } }, RightUpperArm = { rot = { 160, 0, 20 } }, RightLowerArm = { rot = { 30, 0, 0 } } } },
		{ t = 0.35, ease = "Linear", poses = { UpperTorso = { rot = { 0, -40, 0 } }, RightUpperArm = { rot = { 60, 0, -30 } }, RightLowerArm = { rot = { 0, 0, 0 } } } },
		{ t = 0.8, ease = "Cubic", dir = "InOut", poses = { UpperTorso = { rot = { 0, 0, 0 } }, RightUpperArm = { rot = { 0, 0, 0 } }, RightLowerArm = { rot = { 0, 0, 0 } } } },
	},
	markers = { { t = 0.3, name = "Hit", value = "slash" } },
}
