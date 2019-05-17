local F = "__Factorissimo2__"

require("circuit-connector-sprites")

local function blank()
	return {
		filename = F.."/graphics/nothing.png",
		priority = "high",
		width = 1,
		height = 1,
	}
end

local function ablank()
	return {
		filename = F.."/graphics/nothing.png",
		priority = "high",
		width = 1,
		height = 1,
		frame_count = 1,
	}
end

-- Pipe connectors

local function factory_pipe(name, height, order) 
	data:extend({
		{
			type = "item",
			name = name,
			icon = F.."/graphics/icon/"..name..".png",
			icon_size = 32,
			flags = {},
			subgroup = "factorissimo2",
			order = order,
			place_result = name,
			stack_size = 50,
		},
		{
			type = "storage-tank",
			name = name,
			icon = F.."/graphics/icon/"..name..".png",
			icon_size = 32,
			flags = {"placeable-player", "player-creation"},
			minable = {mining_time = 1, result = name},
			max_health = 80,
			corpse = "small-remnants",
			collision_box = {{-0.0625, -0.0625}, {0.0625, 0.0625}},
			selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
			fluid_box =
			{
				base_area = 25,
				base_level = height,
				pipe_covers = pipecoverspictures(),
				pipe_connections = {
					{ position = {0, -1} },
					{ position = {0, 1} },
				},
			},
			window_bounding_box = {{0,0}, {0,0}},
			pictures = {
				picture = {
					sheet = {
						filename = F.."/graphics/utility/"..name..".png",
						priority = "extra-high",
						frames = 2,
						width = 50,
						height = 50,
						shift = {0.15625, -0.0625}
					}
				},
				fluid_background = blank(),
				window_background = blank(),
				flow_sprite = blank(),
				gas_flow = ablank()
			},
			flow_length_in_ticks = 1,
			vehicle_impact_sound = { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
			working_sound = {
				sound = {
						filename = "__base__/sound/storage-tank.ogg",
						volume = 0.1
				},
				apparent_volume = 0.1,
				max_sounds_per_type = 3
			},
			circuit_wire_connection_points = circuit_connector_definitions["storage-tank"].points,
			circuit_connector_sprites = circuit_connector_definitions["storage-tank"].sprites,
			circuit_wire_max_distance = 0
		},
	})
end

factory_pipe("factory-input-pipe", -1, "b-a")
factory_pipe("factory-output-pipe", 1, "b-b")

-- Circuit connectors

data:extend({
	{
		type = "item",
		name = "factory-circuit-input",
		icon = F.."/graphics/icon/factory-circuit-input.png",
		icon_size = 32,
		flags = {},
		subgroup = "factorissimo2",
		order = "c-a",
		place_result = "factory-circuit-input",
		stack_size = 50,
	},
	{
		type = "pump",
		name = "factory-circuit-input",
		icon = F.."/graphics/icon/factory-circuit-input.png",
		icon_size = 32,
		flags = {"placeable-neutral", "player-creation"},
		minable = {mining_time = 1, result = "factory-circuit-input"},
		max_health = 80,
		corpse = "small-remnants",
		
		collision_box = {{-0.29, -0.29}, {0.29, 0.29}},
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
		
		fluid_box = {
			base_area = 1,
			pipe_covers = pipecoverspictures(),
			pipe_connections = {},
		},
		
		energy_source = {
			type = "electric",
			usage_priority = "secondary-input",
			emissions_per_second_per_watt = 0,
			render_no_power_icon = false,
			render_no_network_icon = false,
		},
		energy_usage = "60W",
		pumping_speed = 0,
		vehicle_impact_sound = { filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
		animations = {
			north = {
				filename = F.."/graphics/utility/factory-combinators.png",
				x = 158,
				y = 0,
				width = 79,
				height = 63,
				frame_count = 1,
				shift = {0.140625, 0.140625},
			},
			east = {
				filename = F.."/graphics/utility/factory-combinators.png",
				y = 0,
				width = 79,
				height = 63,
				frame_count = 1,
				shift = {0.140625, 0.140625},
			},
			south = {
				filename = F.."/graphics/utility/factory-combinators.png",
				x = 237,
				y = 0,
				width = 79,
				height = 63,
				frame_count = 1,
				shift = {0.140625, 0.140625},
			},
			west = {
				filename = F.."/graphics/utility/factory-combinators.png",
				x = 79,
				y = 0,
				width = 79,
				height = 63,
				frame_count = 1,
				shift = {0.140625, 0.140625},
			}
		},
		circuit_wire_connection_points = {
			{
				shadow = {
					red = {0.15625, -0.28125},
					green = {0.65625, -0.25}
				},
				wire = {
					red = {-0.28125, -0.5625},
					green = {0.21875, -0.5625},
				}
			},
			{
				shadow = {
					red = {0.75, -0.15625},
					green = {0.75, 0.25},
				},
				wire = {
					red = {0.46875, -0.5},
					green = {0.46875, -0.09375},
				}
			},
			{
				shadow = {
					red = {0.75, 0.5625},
					green = {0.21875, 0.5625}
				},
				wire = {
					red = {0.28125, 0.15625},
					green = {-0.21875, 0.15625}
				}
			},
			{
				shadow = {
					red = {-0.03125, 0.28125},
					green = {-0.03125, -0.125},
				},
				wire = {
					red = {-0.46875, 0},
					green = {-0.46875, -0.40625},
				}
			}
		},
		circuit_connector_sprites = {
			circuit_connector_definitions["chest"].sprites,
			circuit_connector_definitions["chest"].sprites,
			circuit_connector_definitions["chest"].sprites,
			circuit_connector_definitions["chest"].sprites,
		},
		circuit_wire_max_distance = 7.5
	},
	
	{
		type = "item",
		name = "factory-circuit-output",
		icon = F.."/graphics/icon/factory-circuit-output.png",
		icon_size = 32,
		flags = {},
		subgroup = "factorissimo2",
		order = "c-b",
		place_result = "factory-circuit-output",
		stack_size = 50,
	},
	{
		type = "constant-combinator",
		name = "factory-circuit-output",
		icon = F.."/graphics/icon/factory-circuit-output.png",
		icon_size = 32,
		flags = {"placeable-neutral", "player-creation"},
		minable = {hardness = 0.2, mining_time = 0.5, result = "factory-circuit-output"},
		max_health = 50,
		corpse = "small-remnants",

		collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},

		item_slot_count = 15,

		sprites = {
			north = {
				filename = F.."/graphics/utility/factory-combinators.png",
				x = 158,
				y = 63,
				width = 79,
				height = 63,
				frame_count = 1,
				shift = {0.140625, 0.140625},
			},
			east = {
				filename = F.."/graphics/utility/factory-combinators.png",
				y = 63,
				width = 79,
				height = 63,
				frame_count = 1,
				shift = {0.140625, 0.140625},
			},
			south = {
				filename = F.."/graphics/utility/factory-combinators.png",
				x = 237,
				y = 63,
				width = 79,
				height = 63,
				frame_count = 1,
				shift = {0.140625, 0.140625},
			},
			west = {
				filename = F.."/graphics/utility/factory-combinators.png",
				x = 79,
				y = 63,
				width = 79,
				height = 63,
				frame_count = 1,
				shift = {0.140625, 0.140625},
			}
		},

		activity_led_sprites = {
			north = {
				filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-N.png",
				width = 8,
				height = 6,
				frame_count = 1,
				shift = util.by_pixel(9, -12),
				
			},
			east = {
				filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-E.png",
				width = 8,
				height = 8,
				frame_count = 1,
				shift = util.by_pixel(8, 0),
				
			},
			south = {
				filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-S.png",
				width = 8,
				height = 8,
				frame_count = 1,
				shift = util.by_pixel(-9, 2),
				
			},
			west = {
				filename = "__base__/graphics/entity/combinator/activity-leds/constant-combinator-LED-W.png",
				width = 8,
				height = 8,
				frame_count = 1,
				shift = util.by_pixel(-7, -15),
				
			},
		},

		activity_led_light = {
			intensity = 0.2,
			size = 1,
		},

		activity_led_light_offsets = {
			{0.296875, -0.40625},
			{0.25, -0.03125},
			{-0.296875, -0.078125},
			{-0.21875, -0.46875}
		},

		circuit_wire_connection_points = {
			{
				shadow = {
					red = {0.15625, -0.28125},
					green = {0.65625, -0.25}
				},
				wire = {
					red = {-0.28125, -0.5625},
					green = {0.21875, -0.5625},
				}
			},
			{
				shadow = {
					red = {0.75, -0.15625},
					green = {0.75, 0.25},
				},
				wire = {
					red = {0.46875, -0.5},
					green = {0.46875, -0.09375},
				}
			},
			{
				shadow = {
					red = {0.75, 0.5625},
					green = {0.21875, 0.5625}
				},
				wire = {
					red = {0.28125, 0.15625},
					green = {-0.21875, 0.15625}
				}
			},
			{
				shadow = {
					red = {-0.03125, 0.28125},
					green = {-0.03125, -0.125},
				},
				wire = {
					red = {-0.46875, 0},
					green = {-0.46875, -0.40625},
				}
			}
		},

		circuit_wire_max_distance = 7.5
	},
	-- Factory requester chest
	{
		type = "item",
		name = "factory-requester-chest",
		icon = F.."/graphics/icon/factory-requester-chest.png",
		icon_size = 32,
		flags = {},
		subgroup = "factorissimo2",
		order = "d-a",
		place_result = "factory-requester-chest",
		stack_size = 1,
	},
	{
		type = "logistic-container",
		name = "factory-requester-chest",
		icon = F.."/graphics/icon/factory-requester-chest.png",
		icon_size = 32,
		flags = {"placeable-player", "player-creation"},
		minable = {hardness = 0.2, mining_time = 0.5, result = "factory-requester-chest"},
		max_health = 450,
		corpse = "small-remnants",
		collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
		selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
		inventory_size = 48,
		logistic_slots_count = 24,
		logistic_mode = "requester",
		open_sound = { filename = "__base__/sound/metallic-chest-open.ogg", volume=0.65 },
		close_sound = { filename = "__base__/sound/metallic-chest-close.ogg", volume = 0.7 },
		vehicle_impact_sound =	{ filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
		picture =
		{
			filename = F.."/graphics/utility/factory-requester-chest.png",
			priority = "extra-high",
			width = 38,
			height = 32,
			shift = {0.09375, 0}
		},
		circuit_wire_connection_point = circuit_connector_definitions["chest"].points,
		circuit_connector_sprites = circuit_connector_definitions["chest"].sprites,
		circuit_wire_max_distance = 7.5,
	},
})

