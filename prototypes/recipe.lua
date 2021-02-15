local easy_recipes = settings.startup["Factorissimo2-easy-recipes"].value

local multiplier = easy_recipes and 1 or 10

data:extend({

	-- Factory buildings
	{
		type = "recipe",
		name = "factory-1",
		enabled = false,
		energy_required = 30,
		ingredients = {{"stone", 50 * multiplier}, {"iron-plate", 50 * multiplier}, {"copper-plate", 10 * multiplier}},
		result = "factory-1"
	},

	{
		type = "recipe",
		name = "factory-2",
		enabled = false,
		energy_required = 46,
		ingredients = {{"stone-brick", 100 * multiplier}, {"steel-plate", 25 * multiplier}, {"big-electric-pole", 5 * multiplier}},
		result = "factory-2"
	},

	{
		type = "recipe",
		name = "factory-3",
		enabled = false,
		energy_required = 60,
		ingredients = {{"concrete", 500 * multiplier}, {"steel-plate", 200 * multiplier}, {"substation", 10 * multiplier}},
		result = "factory-3"
	},

	-- Utilities
	{
		type = "recipe",
		name = "factory-circuit-input",
		enabled = false,
		energy_required = 1,
		ingredients = {{"copper-cable", 5}, {"electronic-circuit", 2}},
		result = "factory-circuit-input"
	},
	{
		type = "recipe",
		name = "factory-circuit-output",
		enabled = false,
		energy_required = 1,
		ingredients = {{"electronic-circuit", 2}, {"copper-cable", 5}},
		result = "factory-circuit-output"
	},
	{
		type = "recipe",
		name = "factory-input-pipe",
		enabled = false,
		energy_required = 1,
		ingredients = {{"pipe", 5}},
		result = "factory-input-pipe"
	},
	{
		type = "recipe",
		name = "factory-output-pipe",
		enabled = false,
		energy_required = 1,
		ingredients = {{"pipe", 5}},
		result = "factory-output-pipe"
	},
	{
		type = "recipe",
		name = "factory-requester-chest",
		enabled = false,
		energy_required = 10,
		ingredients = {{"logistic-chest-requester", 5}},
		result = "factory-requester-chest"
	},
});
