--!nonstrict
-- Crouch -> double-jump tuck pose; legs mirrored from the right side with Anim.mirror in tests.
return {
	name = "JumpClimb", length = 0.9, priority = "Movement",
	keys = {
		{ t = 0, poses = { LowerTorso = { pos = { 0, 0, 0 } }, LeftUpperLeg = { rot = { 0, 0, 0 } }, RightUpperLeg = { rot = { 0, 0, 0 } } } },
		{ t = 0.2, ease = "Cubic", dir = "Out", poses = { LowerTorso = { pos = { 0, -0.5, 0 } }, LeftUpperLeg = { rot = { 40, 0, 0 } }, RightUpperLeg = { rot = { 40, 0, 0 } }, LeftLowerLeg = { rot = { -70, 0, 0 } }, RightLowerLeg = { rot = { -70, 0, 0 } } } },
		{ t = 0.45, ease = "Cubic", dir = "Out", poses = { LowerTorso = { pos = { 0, 0.4, 0 } }, LeftUpperLeg = { rot = { 70, 0, 0 } }, RightUpperLeg = { rot = { 20, 0, 0 } }, LeftLowerLeg = { rot = { -90, 0, 0 } }, RightLowerLeg = { rot = { -30, 0, 0 } }, LeftUpperArm = { rot = { 150, 0, 0 } }, RightUpperArm = { rot = { 150, 0, 0 } } } },
		{ t = 0.9, ease = "Bounce", dir = "Out", poses = { LowerTorso = { pos = { 0, 0, 0 } }, LeftUpperLeg = { rot = { 0, 0, 0 } }, RightUpperLeg = { rot = { 0, 0, 0 } }, LeftLowerLeg = { rot = { 0, 0, 0 } }, RightLowerLeg = { rot = { 0, 0, 0 } }, LeftUpperArm = { rot = { 0, 0, 0 } }, RightUpperArm = { rot = { 0, 0, 0 } } } },
	},
}
