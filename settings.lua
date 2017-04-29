data:extend({
	{
		type = "bool-setting",
		name = "Factorissimo2-free-recursion",
		setting_type = "runtime-global",
		default_value = false
	},
	{
		type = "bool-setting",
		name = "Factorissimo2-easy-research",
		setting_type = "startup",
		default_value = false,
	},
	{
		type = "bool-setting",
		name = "Factorissimo2-preview-enabled",
		setting_type = "runtime-per-user",
		default_value = true,
	},
	{
		type = "int-setting",
		name = "Factorissimo2-preview-size",
		setting_type = "runtime-per-user",
		minimum_value = 50,
		default_value = 300,
		maximum_value = 1000,
	},
	{
		type = "double-setting",
		name = "Factorissimo2-preview-zoom",
		setting_type = "runtime-per-user",
		minimum_value = 0.2,
		default_value = 1,
		maximum_value = 2,
	},
})