
require("prototypes.factory")
require("prototypes.component")
require("prototypes.utility")
require("prototypes.recipe")
require("prototypes.technology")
require("prototypes.tile")

data:extend({

	{
		type = "item-subgroup",
		name = "factorissimo2",
		group = "logistics",
		order = "e-e"
	},
	{
		type = "custom-input",
		name = "factory-rotate",
		key_sequence = "R",
	},
	{
		type = "custom-input",
		name = "factory-increase",
		key_sequence = "SHIFT + R",
	},
	{
		type = "custom-input",
		name = "factory-decrease",
		key_sequence = "CONTROL + R",
	},
})