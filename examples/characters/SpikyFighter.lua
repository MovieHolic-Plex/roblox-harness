--!nonstrict
-- Parody archetype: spiky-haired martial artist in an orange gi.
return {
	name = "SpikyFighter",
	skin = "#f1c9a0",
	outfit = { shirt = "#f07d1a", pants = "#f07d1a", shoes = "#1f3a8a", gloves = "#f1c9a0", sleeves = "none" },
	face = { eyes = "sharp", mouth = "smile", browTilt = 15 },
	hair = { style = "spiky", color = "#161616", spikes = 9, height = 1.2 },
	accessories = { { type = "belt", color = "#1f3a8a", buckleColor = "#1f3a8a" } },
	pieces = {
		{ attach = "UpperTorso", name = "Undershirt", size = { 0.9, 0.7, 0.05 }, pos = { 0, 0.42, -0.51 }, color = "#1f3a8a" },
		{ attach = "LeftLowerArm", name = "Wristband", size = { 1.06, 0.25, 1.06 }, pos = { 0, -0.28, 0 }, color = "#1f3a8a" },
		{ attach = "RightLowerArm", name = "Wristband", size = { 1.06, 0.25, 1.06 }, pos = { 0, -0.28, 0 }, color = "#1f3a8a" },
	},
}
