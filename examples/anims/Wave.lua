--!nonstrict
return {
	name = "Wave", length = 1.2, loop = true, priority = "Action",
	keys = {
		{ t = 0, ease = "Cubic", dir = "InOut", poses = { RightUpperArm = { rot = { 0, 0, 150 } }, RightLowerArm = { rot = { 0, 0, 10 } } } },
		{ t = 0.3, ease = "Cubic", dir = "InOut", poses = { RightLowerArm = { rot = { 0, 0, 40 } } } },
		{ t = 0.6, ease = "Cubic", dir = "InOut", poses = { RightUpperArm = { rot = { 0, 0, 150 } }, RightLowerArm = { rot = { 0, 0, -20 } } } },
		{ t = 1.2, poses = { RightUpperArm = { rot = { 0, 0, 150 } }, RightLowerArm = { rot = { 0, 0, 10 } } } },
	},
}
