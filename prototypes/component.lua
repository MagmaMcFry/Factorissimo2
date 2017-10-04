require("util")
require("constants")
local F = "__Factorissimo2__";

local function cwc0()
	return {shadow = {red = {0,0},green = {0,0}}, wire = {red = {0,0},green = {0,0}}}
end
local function cwc0c()
	return {shadow = {red = {0,0},green = {0,0},copper = {0,0}}, wire = {red = {0,0},green = {0,0},copper = {0,0}}}
end
local function cc0()
	return get_circuit_connector_sprites({0,0},nil,1)
end

local function ps()
	return {
		filename = F.."/graphics/component/pipe-connection-south.png",
		priority = "extra-high",
		width = 44,
		height = 32
	}
end

local function sprite_entity_info()
	return {
		filename = "__core__/graphics/entity-info-dark-background.png",
		priority = "high",
		width = 53,
		height = 53,
		scale = 0.5
	}
end

local function repeat_count(count, entry)
	local result = {}
	for i=1,count do
		table.insert(result, entry)
	end
	return result
end
local function repeat_nesw(entry)
	return {
		north = entry,
		east = entry,
		south = entry,
		west = entry
	}
end

local function blankpipepictures()
	return {
		straight_vertical_single = blank(),
		straight_vertical = blank(),
		straight_vertical_window = blank(),
		straight_horizontal_window = blank(),
		straight_horizontal = blank(),
		corner_up_right = blank(),
		corner_up_left = blank(),
		corner_down_right = blank(),
		corner_down_left = blank(),
		t_up = blank(),
		t_down = blank(),
		t_right = blank(),
		t_left = blank(),
		cross = blank(),
		ending_up = blank(),
		ending_down = blank(),
		ending_right = blank(),
		ending_left = blank(),
		horizontal_window_background = blank(),
		vertical_window_background = blank(),
		fluid_background = blank(),
		low_temperature_flow = blank(),
		middle_temperature_flow = blank(),
		high_temperature_flow = blank(),
		gas_flow = ablank(),
	}
end

local function southpipepictures()
	return {
		straight_vertical_single = blank(),
		straight_vertical = ps(),
		straight_vertical_window = ps(),
		straight_horizontal_window = blank(),
		straight_horizontal = blank(),
		corner_up_right = blank(),
		corner_up_left = blank(),
		corner_down_right = ps(),
		corner_down_left = ps(),
		t_up = blank(),
		t_down = ps(),
		t_right = ps(),
		t_left = ps(),
		cross = ps(),
		ending_up = blank(),
		ending_down = ps(),
		ending_right = blank(),
		ending_left = blank(),
		horizontal_window_background = blank(),
		vertical_window_background = blank(),
		fluid_background = blank(),
		low_temperature_flow = blank(),
		middle_temperature_flow = blank(),
		high_temperature_flow = blank(),
		gas_flow = ablank(),
	}
end

function overlay_controller_picture()
	return {
		filename = "__base__/graphics/entity/iron-chest/iron-chest.png",
		priority = "extra-high",
		width = 48,
		height = 34,
		shift = {0.1875, 0}
	}
end

-- Factory power I/O

function make_energy_interfaces(size,passive_input,passive_output,icon)
	local selection_size = size-0.6;
	local input_priority = (passive_input and "terciary") or "secondary-input"
	local output_priority = (passive_output and "terciary") or "secondary-output"
	-- I wish I could make only the input entity passive, so accumulators inside could charge, but there's a bug that prevents this from 
	data:extend({
		{
			type = "electric-energy-interface",
			name = "factory-power-input-" .. size,
			icon = icon,
			flags = {"not-on-map"},
			minable = nil,
			max_health = 1,
			selectable_in_game = false,
			energy_source = {
				type = "electric",
				usage_priority = input_priority,
				input_flow_limit = "60MW",
				output_flow_limit = "0MW",
				buffer_capacity = "1MJ",
				render_no_power_icon = false,
			},
			energy_usage = "0MW",
			energy_production = "0MW",
			selection_box = centered_square(selection_size),
			collision_box = centered_square(selection_size),
			collision_mask = {},
		},
		{
			type = "electric-energy-interface",
			name = "factory-power-output-" .. size,
			icon = icon,
			flags = {"not-on-map"},
			minable = nil,
			max_health = 1,
			selectable_in_game = false,
			energy_source = {
				type = "electric",
				usage_priority = output_priority,
				input_flow_limit = "0MW",
				output_flow_limit = "60MW",
				buffer_capacity = "1MJ",
				render_no_power_icon = false,
			},
			energy_usage = "0MW",
			energy_production = "0MW",
			selection_box = centered_square(selection_size),
			collision_box = centered_square(selection_size),
			collision_mask = {},
		},
	})
end
make_energy_interfaces(2,true,true,"__base__/graphics/icons/substation.png")
-- true,false would be optimal, but due to a bug it doesn't work. Maybe it'll be fixed.
-- In the meantime we'll have to settle for true,true because that's how Factorissimo1 worked.

make_energy_interfaces(8,false,false,F.."/graphics/icon/factory-1.png")
make_energy_interfaces(12,false,false,F.."/graphics/icon/factory-2.png")
make_energy_interfaces(16,false,false,F.."/graphics/icon/factory-3.png")

-- Connection indicators

local function create_indicator(ctype, suffix, image)
	data:extend({
		{
			type = "storage-tank",
			name = "factory-connection-indicator-" .. ctype .. "-" .. suffix,
			--icon = 
			flags = {"not-on-map"},
			minable = nil,
			max_health = 500,
			selection_box = centered_square(0.8),
			collision_box = centered_square(0.8),
			collision_mask = {},
			fluid_box = {
				base_area = 1,
				pipe_connections = {},
			},
			two_direction_only = false,
			window_bounding_box = centered_square(0),
			pictures = {
				picture = {
					sheet = {
						filename = F.."/graphics/indicator/" .. image .. ".png",
						priority = "extra-high",
						frames = 4,
						width = 32,
						height = 32
					},
				},
				fluid_background = blank(),
				window_background = blank(),
				flow_sprite = blank(),
				gas_flow = ablank(),
			},
			flow_length_in_ticks = 100,
			vehicle_impact_sound = {filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65},
			--working_sound = silent,
			circuit_wire_connection_points = {cwc0(), cwc0(), cwc0(), cwc0()},
			circuit_connector_sprites = {cc0(), cc0(), cc0(), cc0()},
			circuit_wire_max_distance = 0,
		}
	})
end

create_indicator("belt", "d0", "green-dir")

create_indicator("chest", "d0", "brown-dir") -- 0 is catchall for "There isn't an entity for this exact value"
create_indicator("chest", "d10", "brown-dir")
create_indicator("chest", "d20", "brown-dir")
create_indicator("chest", "d60", "brown-dir")
create_indicator("chest", "d180", "brown-dir")
create_indicator("chest", "d600", "brown-dir")

create_indicator("chest", "b0", "brown-dot")
create_indicator("chest", "b10", "brown-dot")
create_indicator("chest", "b20", "brown-dot")
create_indicator("chest", "b60", "brown-dot")
create_indicator("chest", "b180", "brown-dot")
create_indicator("chest", "b600", "brown-dot")

create_indicator("fluid", "d0", "blue-dir")
create_indicator("fluid", "d1", "blue-dir")
create_indicator("fluid", "d4", "blue-dir")
create_indicator("fluid", "d10", "blue-dir")
create_indicator("fluid", "d30", "blue-dir")
create_indicator("fluid", "d120", "blue-dir")

create_indicator("fluid", "b0", "blue-dot")
create_indicator("fluid", "b1", "blue-dot")
create_indicator("fluid", "b4", "blue-dot")
create_indicator("fluid", "b10", "blue-dot")
create_indicator("fluid", "b30", "blue-dot")
create_indicator("fluid", "b120", "blue-dot")

create_indicator("circuit", "d0", "red-dir")
create_indicator("circuit", "d1", "red-dir")
create_indicator("circuit", "d10", "red-dir")
create_indicator("circuit", "d60", "red-dir")
create_indicator("circuit", "d180", "red-dir")
create_indicator("circuit", "d600", "red-dir")

-- <E>

create_indicator("energy", "d0", "yellow-dir")
create_indicator("energy", "d1", "yellow-dir")
create_indicator("energy", "d2", "yellow-dir")
create_indicator("energy", "d5", "yellow-dir")
create_indicator("energy", "d10", "yellow-dir")
create_indicator("energy", "d20", "yellow-dir")
create_indicator("energy", "d50", "yellow-dir")
create_indicator("energy", "d100", "yellow-dir")
create_indicator("energy", "d200", "yellow-dir")
create_indicator("energy", "d500", "yellow-dir")
create_indicator("energy", "d1000", "yellow-dir")
create_indicator("energy", "d2000", "yellow-dir")
create_indicator("energy", "d5000", "yellow-dir")
create_indicator("energy", "d10000", "yellow-dir")
create_indicator("energy", "d20000", "yellow-dir")
create_indicator("energy", "d50000", "yellow-dir")
create_indicator("energy", "d100000", "yellow-dir")

-- Other auxiliary entities

data:extend({
	{
		type = "electric-pole",
		name = "factory-power-pole",
		minable = nil,
		max_health = 1,
		selection_box = centered_square(1.99),
		collision_box = centered_square(1.99),
		collision_mask = {},
		maximum_wire_distance = 0,
		supply_area_distance = 63,
		pictures = {
			filename = "__base__/graphics/entity/substation/substation.png",
			priority = "high",
			width = 132,
			height = 144,
			direction_count = 4,
			shift = {0.9, -1}
		},
		radius_visualisation_picture = {
			filename = "__base__/graphics/entity/small-electric-pole/electric-pole-radius-visualization.png",
			width = 12,
			height = 12,
			priority = "extra-high-no-scale"
		},
		connection_points = {cwc0c(), cwc0c(), cwc0c(), cwc0c()},
	},
	{
		type = "lamp",
		name = "factory-ceiling-light",
		icon = "__base__/graphics/icons/small-lamp.png",
		flags = {"not-on-map"},
		minable = nil,
		max_health = 55,
		corpse = "small-remnants",
		collision_box = centered_square(0.3),
		collision_mask = {},
		selection_box = centered_square(1.0),
		selectable_in_game = false,
		vehicle_impact_sound =	{ filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
		energy_source =
		{
			type = "electric",
			usage_priority = "secondary-input",
			render_no_power_icon = false,
		},
		energy_usage_per_tick = "5KW",
		light = {intensity = 1, size = 50},
		light_when_colored = {intensity = 1, size = 6},
		glow_size = 6,
		glow_color_intensity = 0.135,
		picture_off = blank(),
		picture_on = blank(),
		signal_to_color_mapping = {},

		circuit_wire_connection_point = cwc0(),
		circuit_connector_sprites = cc0(),
		circuit_wire_max_distance = 0,
	},
	
	{
		type = "constant-combinator",
		name = "factory-overlay-controller",
		icon = "__base__/graphics/icons/iron-chest.png",
		item_slot_count = Constants.overlay_slot_count,
		
		sprites = repeat_nesw(overlay_controller_picture()),
		activity_led_sprites = repeat_nesw(blank()),
		activity_led_light_offsets = repeat_count(4, {x=0,y=0}),
		circuit_wire_connection_points = repeat_count(4, {wire={}, shadow={}}),
		
		flags = {},
		minable = nil,
		max_health = 100,
		corpse = "small-remnants",
		resistances = {},
		collision_box = centered_square(0.7),
		selection_box = centered_square(1.0),
		vehicle_impact_sound =	{ filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
	},

	{
		type = "item",
		name = "factory-overlay-display-1-item",
		icon = "__core__/graphics/entity-info-dark-background.png",
		flags = {"hidden"},
		subgroup = "factorissimo2",
		place_result = "blueprint-factory-overlay-display-1",
		stack_size = 10
	},
	{
		type = "item",
		name = "factory-overlay-display-2-item",
		icon = "__core__/graphics/entity-info-dark-background.png",
		flags = {"hidden"},
		subgroup = "factorissimo2",
		place_result = "blueprint-factory-overlay-display-2",
		stack_size = 10
	},
	{
		type = "constant-combinator",
		name = "factory-overlay-display-1",
		icon = F.."/graphics/icon/blank-icon.png",
		item_slot_count = Constants.overlay_slot_count,
		
		sprites = repeat_nesw(blank()),
		activity_led_sprites = repeat_nesw(blank()),
		activity_led_light_offsets = repeat_count(4, {x=0,y=0}),
		circuit_wire_connection_points = repeat_count(4, {wire={}, shadow={}}),
		
		flags = {"not-on-map"},
		minable = nil,
		max_health = 100,
		corpse = "small-remnants",
		resistances = {},
		collision_box = centered_square(1),
		collision_mask = {},
		selection_box = centered_square(1),
		selectable_in_game = false,
		scale_info_icons = true,
		vehicle_impact_sound =	{ filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
	},
	{
		type = "constant-combinator",
		name = "blueprint-factory-overlay-display-1",
		icon = "__core__/graphics/entity-info-dark-background.png",
		item_slot_count = Constants.overlay_slot_count,
		
		sprites = repeat_nesw(sprite_entity_info()),
		activity_led_sprites = repeat_nesw(blank()),
		activity_led_light_offsets = repeat_count(4, {x=0,y=0}),
		circuit_wire_connection_points = repeat_count(4, {wire={}, shadow={}}),
		
		flags = {"not-on-map", "player-creation"},
		minable = {
			mining_time = 1,
			result = "factory-overlay-display-1-item"
		},
		max_health = 100,
		corpse = "small-remnants",
		resistances = {},
		collision_box = centered_square(1),
		collision_mask = {},
		selection_box = centered_square(1),
		selectable_in_game = false,
		scale_info_icons = true,
		vehicle_impact_sound =	{ filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
	},
	{
		type = "constant-combinator",
		name = "factory-overlay-display-2",
		icon = F.."/graphics/icon/blank-icon.png",
		item_slot_count = Constants.overlay_slot_count,
		
		sprites = repeat_nesw(blank()),
		activity_led_sprites = repeat_nesw(blank()),
		activity_led_light_offsets = repeat_count(4, {x=0,y=0}),
		circuit_wire_connection_points = repeat_count(4, {wire={}, shadow={}}),
		
		flags = {"not-on-map"},
		minable = nil,
		max_health = 100,
		corpse = "small-remnants",
		resistances = {},
		collision_box = centered_square(3.7),
		collision_mask = {},
		selection_box = centered_square(4),
		selectable_in_game = false,
		scale_info_icons = true,
		vehicle_impact_sound =	{ filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
	},
	{
		type = "constant-combinator",
		name = "blueprint-factory-overlay-display-2",
		icon = "__core__/graphics/entity-info-dark-background.png",
		item_slot_count = Constants.overlay_slot_count,
		
		sprites = repeat_nesw(sprite_entity_info()),
		activity_led_sprites = repeat_nesw(blank()),
		activity_led_light_offsets = repeat_count(4, {x=0,y=0}),
		circuit_wire_connection_points = repeat_count(4, {wire={}, shadow={}}),
		
		flags = {"not-on-map", "player-creation"},
		minable = {
			mining_time = 1,
			result = "factory-overlay-display-1-item"
		},
		max_health = 100,
		corpse = "small-remnants",
		resistances = {},
		collision_box = centered_square(3.7),
		collision_mask = {},
		selection_box = centered_square(4),
		selectable_in_game = false,
		scale_info_icons = true,
		vehicle_impact_sound =	{ filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65 },
	},
	{
		type = "pipe",
		name = "factory-fluid-dummy-connector",
		flags = {"not-on-map"},
		minable = nil,
		max_health = 500,
		selection_box = centered_square(0.8),
		selectable_in_game = false,
		collision_box = centered_square(0.8),
		collision_mask = {},
		fluid_box = {
			base_area = 0, -- Important, because fluid displacement on deconstruction ignores connection type
			pipe_connections = {
				{position = {0, -1}, type = "output"},
				{position = {1, 0}, type = "output"},
				{position = {0, 1}, type = "output"},
				{position = {-1, 0}, type = "output"},
			},
		},
		horizontal_window_bounding_box = centered_square(0),
		vertical_window_bounding_box = centered_square(0),
		pictures = blankpipepictures(),
		vehicle_impact_sound = {filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65},
	},
	{
		type = "pipe",
		name = "factory-fluid-dummy-connector-south",
		flags = {"not-on-map"},
		minable = nil,
		max_health = 500,
		selection_box = centered_square(0.8),
		selectable_in_game = false,
		collision_box = centered_square(0.8),
		collision_mask = {},
		fluid_box = {
			base_area = 0, -- Important, because fluid displacement on deconstruction ignores connection type
			pipe_connections = {
				{position = {0, -1}, type = "output"},
				{position = {1, 0}, type = "output"},
				{position = {0, 1}, type = "output"},
				{position = {-1, 0}, type = "output"},
			},
		},
		horizontal_window_bounding_box = centered_square(0),
		vertical_window_bounding_box = centered_square(0),
		pictures = southpipepictures(),
		vehicle_impact_sound = {filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65},
	},
	{
		type = "mining-drill",
		name = "factory-port-marker",
		icon = "__base__/graphics/icons/electric-mining-drill.png",
		flags = {"not-on-map"},
		minable = nil,
		max_health = 40,
		resource_categories = {"basic-solid"},
		selection_box = centered_square(0.8),
		selectable_in_game = false,
		collision_box = centered_square(0.8),
		collision_mask = {},
		energy_source = {
			type = "electric",
			usage_priority = "secondary-output",
			render_no_power_icon = false,
			render_no_network_icon = false,
		},
		vehicle_impact_sound = {filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65},
		animations = {
			north = ablank(),
			east = ablank(),
			south = ablank(),
			west = ablank(),
		},
		mining_speed = 0.0001,
		energy_usage = "1000MW",
		mining_power = 3,
		resource_searching_radius = 0.9,
		vector_to_place_result = {0,-0.8},
	},
})
