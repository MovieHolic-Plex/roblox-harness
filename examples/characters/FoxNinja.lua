--!nonstrict
-- Parody archetype: blond ninja with a forehead protector, whiskers and kunai.
return {
	name = "FoxNinja",
	skin = "#f2c79b",
	outfit = { shirt = "#f0791b", pants = "#f0791b", shoes = "#24305e", sleeves = "long" },
	face = { eyes = "round", eyeColor = "#2a7fd4", mouth = "grin", whiskers = true },
	hair = { style = "spiky", color = "#f5d33a", spikes = 11, height = 0.8 },
	accessories = { { type = "headband", color = "#24305e" } },
	weapons = { { type = "kunai", hand = "Right" } },
	pieces = {
		{ attach = "UpperTorso", name = "Collar", size = { 1.6, 0.3, 1.1 }, pos = { 0, 0.72, 0 }, color = "#24305e" },
		{ attach = "UpperTorso", name = "Zip", size = { 0.08, 1.5, 0.04 }, pos = { 0, 0, -0.52 }, color = "#f2f2f2" },
	},
}
