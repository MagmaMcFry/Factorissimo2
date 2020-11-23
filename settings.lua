data:extend({
	-- Startup

	{
		type = "bool-setting",
		name = "Factorissimo2-easy-research",
		setting_type = "startup",
		default_value = false,
		order = "a-a"
	},
	{
		type = "int-setting",
		name = "Factorissimo2-power-batching",
		setting_type = "startup",
		minimum_value = 1,
		default_value = 1,
		maximum_value = 60,
		order = "a-b"
	},

	-- Global

	{
		type = "bool-setting",
		name = "Factorissimo2-free-recursion",
		setting_type = "runtime-global",
		default_value = false,
		order = "a-a",
	},
	{
		type = "bool-setting",
		name = "Factorissimo2-hide-recursion",
		setting_type = "runtime-global",
		default_value = false,
		order = "a-b",
	},
	{
		type = "bool-setting",
		name = "Factorissimo2-hide-recursion-2",
		setting_type = "runtime-global",
		default_value = false,
		order = "a-b-a",
	},
	{
		type = "bool-setting",
		name = "Factorissimo2-better-recursion-2",
		setting_type = "runtime-global",
		default_value = false,
		order = "a-c",
	},
	{
		type = "int-setting",
		name = "Factorissimo2-max-surfaces",
		setting_type = "runtime-global",
		minimum_value = 0,
		default_value = 100,
		order = "a-d",
	},
	{
		type = "bool-setting",
		name = "Factorissimo2-indestructible-buildings",
		setting_type = "runtime-global",
		default_value = false,
		order = "a-e",
	},
	{
		type = "bool-setting",
		name = "Factorissimo2-enemy-players-may-enter",
		setting_type = "runtime-global",
		default_value = true,
		order = "a-f",
	},

	-- Per user

	-- {
		-- type = "bool-setting",
		-- name = "Factorissimo2-preview-enabled",
		-- setting_type = "runtime-per-user",
		-- default_value = true,
		-- order = "a-a",
	-- },
	{
		type = "int-setting",
		name = "Factorissimo2-preview-size",
		setting_type = "runtime-per-user",
		minimum_value = 50,
		default_value = 300,
		maximum_value = 1000,
		order = "a-b",
	},
	{
		type = "double-setting",
		name = "Factorissimo2-preview-zoom",
		setting_type = "runtime-per-user",
		minimum_value = 0.2,
		default_value = 1,
		maximum_value = 2,
		order = "a-c",
	},
})
