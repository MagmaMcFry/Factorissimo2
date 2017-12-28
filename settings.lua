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
