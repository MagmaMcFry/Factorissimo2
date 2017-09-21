data:extend({

	-- Utilities
	{
		type = "recipe",
		name = "factory-construction-requester-chest",
		enabled = false,
		energy_required = 1,
		ingredients = {{"steel-chest", 1}, {"electronic-circuit", 5}},
		result = "factory-construction-requester-chest"
	},
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