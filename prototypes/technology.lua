local F = "__Factorissimo2__"
local pf = "p-q-"
local easy_research = settings.startup["Factorissimo2-easy-research"].value


data:extend({
	-- Factory buildings
	{
		type = "technology",
		name = "factory-architecture-t1",
		icon = F.."/graphics/technology/factory-architecture-1.png",
		icon_size = 128,
		prerequisites = {"stone-walls", "logistics"},
		effects = {
			{type = "unlock-recipe", recipe = "factory-1"},
		},
		unit = {
			count = easy_research and 30 or 200,
			ingredients = {{"automation-science-pack", 1}},
			time = 30
		},
		order = pf.."a-a",
	},
	{
		type = "technology",
		name = "factory-architecture-t2",
		icon = F.."/graphics/technology/factory-architecture-2.png",
		icon_size = 128,
		prerequisites = {"factory-architecture-t1", "steel-processing", "electric-energy-distribution-1"},
		effects = {
			{
				type = "unlock-recipe",
				recipe = "factory-2",
			}
		},
		unit = {
			count = easy_research and 100 or 600,
			ingredients = {{"automation-science-pack", 1},{"logistic-science-pack", 1}},
			time = 45
		},
		order = pf.."a-b",
	},
	{
		type = "technology",
		name = "factory-architecture-t3",
		icon = F.."/graphics/technology/factory-architecture-3.png",
		icon_size = 128,
		prerequisites = {"factory-architecture-t2", "concrete", "electric-energy-distribution-2"},
		effects = {
			{
				type = "unlock-recipe",
				recipe = "factory-3",
			}
		},
		unit = {
			count = easy_research and 300 or 2000,
			ingredients = {{"automation-science-pack", 1},{"logistic-science-pack", 1},{"chemical-science-pack", 1}},
			time = 60
		},
		order = pf.."a-c",
	},
	
	-- Connection types
	{
		type = "technology",
		name = "factory-connection-type-fluid",
		icon = F.."/graphics/technology/factory-connection-type-fluid.png",
		icon_size = 128,
		prerequisites = {"factory-architecture-t1"}, -- "fluid-handling"
		effects = {
			{type = "unlock-recipe", recipe = "factory-input-pipe"},
			{type = "unlock-recipe", recipe = "factory-output-pipe"},
		},
		unit = {
			count = easy_research and 10 or 100,
			ingredients = {{"automation-science-pack", 1}},
			time = 30
		},
		order = pf.."b-a",
	},
	{
		type = "technology",
		name = "factory-connection-type-chest",
		icon = F.."/graphics/technology/factory-connection-type-chest.png",
		icon_size = 128,
		prerequisites = {"factory-architecture-t1", "logistics-2"},
		effects = {},
		unit = {
			count = easy_research and 20 or 200,
			ingredients = {{"automation-science-pack", 1},{"logistic-science-pack", 1}},
			time = 30
		},
		order = pf.."b-b",
	},
	{
		type = "technology",
		name = "factory-connection-type-circuit",
		icon = F.."/graphics/technology/factory-connection-type-circuit.png",
		icon_size = 128,
		prerequisites = {"factory-architecture-t1", "circuit-network"},
		effects = {
			{type = "unlock-recipe", recipe = "factory-circuit-input"},
			{type = "unlock-recipe", recipe = "factory-circuit-output"},
		},
		unit = {
			count = easy_research and 30 or 300,
			ingredients = {{"automation-science-pack", 1},{"logistic-science-pack", 1},{"chemical-science-pack", 1}},
			time = 30
		},
		order = pf.."b-c",
	},
	
	-- Interior upgrades
	
	{
		type = "technology",
		name = "factory-interior-upgrade-lights",
		icon = F.."/graphics/technology/factory-interior-upgrade-lights.png",
		icon_size = 128,
		prerequisites = {"factory-architecture-t1", "optics"},
		effects = {},
		unit = {
			count = easy_research and 5 or 50,
			ingredients = {{"automation-science-pack", 1}},
			time = 30
		},
		order = pf.."c-a",
	},
	{
		type = "technology",
		name = "factory-interior-upgrade-display",
		icon = F.."/graphics/technology/factory-interior-upgrade-display.png",
		icon_size = 128,
		prerequisites = {"factory-architecture-t1", "optics"},
		effects = {},
		unit = {
			count = easy_research and 10 or 100,
			ingredients = {{"automation-science-pack", 1},{"logistic-science-pack", 1}},
			time = 30
		},
		order = pf.."c-b",
	},
	-- Misc utilities
	
	{
		type = "technology",
		name = "factory-preview",
		icon = F.."/graphics/technology/factory-preview.png",
		icon_size = 128,
		prerequisites = {"factory-interior-upgrade-lights"},
		effects = {},
		unit = {
			count = easy_research and 20 or 200,
			ingredients = {{"automation-science-pack", 1},{"logistic-science-pack", 1}},
			time = 30
		},
		order = pf.."d-a",
	},
		{
		type = "technology",
		name = "factory-requester-chest",
		icon = F.."/graphics/technology/factory-requester-chest.png",
		icon_size = 128,
		prerequisites = {"factory-architecture-t1", "logistic-system"},
		effects = {
			{type = "unlock-recipe", recipe = "factory-requester-chest"},
		},
		unit = {
			count = easy_research and 20 or 100,
			ingredients = {{"automation-science-pack", 1},{"logistic-science-pack", 1},{"chemical-science-pack", 1}},
			time = 30
		},
		order = pf.."d-b",
	},
	
	-- Recursion!
	
	{
		type = "technology",
		name = "factory-recursion-t1",
		icon = F.."/graphics/technology/factory-recursion-1.png",
		icon_size = 128,
		prerequisites = {"factory-architecture-t2", "logistics-2"},
		effects = {},
		unit = {
			count = easy_research and 200 or 2000,
			ingredients = {{"automation-science-pack", 1},{"logistic-science-pack", 1}},
			time = 60
		},
		order = pf.."e-a",
	},
	{
		type = "technology",
		name = "factory-recursion-t2",
		icon = F.."/graphics/technology/factory-recursion-2.png",
		icon_size = 128,
		prerequisites = {"factory-recursion-t1", "factory-architecture-t3"},
		effects = {},
		unit = {
			count = easy_research and 500 or 5000,
			ingredients = {{"automation-science-pack", 1},{"logistic-science-pack", 1},{"chemical-science-pack", 1}},
			time = 60
		},
		order = pf.."e-b",
	},
})