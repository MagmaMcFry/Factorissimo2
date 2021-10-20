local F = "__Factorissimo2__";

require("circuit-connector-sprites")

local function cwc0c()
	return {shadow = {red = {0,0}, green = {0,0}, copper = {0,0}}, wire = {red = {0,0}, green = {0,0}, copper = {0,0}}}
end

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

local function rblank()
	return {
		filename = F.."/graphics/nothing.png",
		priority = "high",
		width = 1,
		height = 1,
		direction_count = 1,
	}
end

local function ps()
	return {
		filename = F.."/graphics/component/pipe-connection-south.png",
		priority = "extra-high",
		width = 44,
		height = 32
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

-- Factory power I/O

local function create_energy_interfaces(size, icon)
	local j = size/2-0.3
	data:extend{
		{
			type = "electric-energy-interface",
			name = "factory-power-input-" .. size,
			icon = icon,
			icon_size = 32,
			flags = {"not-on-map"},
			minable = nil,
			max_health = 1,
			selectable_in_game = false,
			energy_source = {
				type = "electric",
				usage_priority = "tertiary",
				input_flow_limit = "0W",
				output_flow_limit = "0W",
				buffer_capacity = "0J",
				render_no_power_icon = false,
			},
			energy_usage = "0MW",
			energy_production = "0MW",
			selection_box = {{-j,-j},{j,j}},
			collision_box = {{-j,-j},{j,j}},
			collision_mask = {},
			localised_name = '',
		}
	}
end

create_energy_interfaces(8,F.."/graphics/icon/factory-1.png")
create_energy_interfaces(12,F.."/graphics/icon/factory-2.png")
create_energy_interfaces(16,F.."/graphics/icon/factory-3.png")

-- Connection indicators

local function create_indicator(ctype, suffix, image)
	data:extend({
		{
			type = "storage-tank",
			name = "factory-connection-indicator-" .. ctype .. "-" .. suffix,
			localised_name = {"entity-name.factory-connection-indicator-" .. ctype},
			flags = {"not-on-map"},
			minable = nil,
			max_health = 500,
			selection_box = {{-0.4,-0.4},{0.4,0.4}},
			collision_box = {{-0.4,-0.4},{0.4,0.4}},
			collision_mask = {},
			fluid_box = {
				base_area = 1,
				pipe_connections = {},
			},
			two_direction_only = false,
			window_bounding_box = {{0,0},{0,0}},
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
			circuit_wire_connection_points = circuit_connector_definitions["storage-tank"].points,
			circuit_connector_sprites = circuit_connector_definitions["storage-tank"].sprites,
			circuit_wire_max_distance = 0,
		}
	})
end

create_indicator("belt", "d0", "green-dir")

create_indicator("chest", "d0", "brown-dir") -- 0 is catchall for "There isn"t an entity for this exact value"
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

-- Other auxiliary entities

local j = 0.99
data:extend({
	{
		type = "electric-pole",
		name = "factory-power-pole",
		minable = nil,
		max_health = 1,
		selection_box = {{-j,-j}, {j,j}},
		collision_box = {{-j,-j}, {j,j}},
		collision_mask = {},
		flags = {"not-on-map", "hidden"},
		maximum_wire_distance = 1,
		supply_area_distance = 63,
		pictures = table.deepcopy(data.raw["electric-pole"]["substation"].pictures),
		drawing_box = table.deepcopy(data.raw["electric-pole"]["substation"].drawing_box),
		radius_visualisation_picture = blank(),
		connection_points = {cwc0c(), cwc0c(), cwc0c(), cwc0c()},
	},
	{
		type = "electric-pole",
		name = "factory-overflow-pole",
		minable = nil,
		max_health = 1,
		selection_box = {{-j,-j}, {j,j}},
		collision_box = {{-j,-j}, {j,j}},
		collision_mask = {},
		flags = {"not-on-map", "hidden"},
		maximum_wire_distance = 1,
		supply_area_distance = 63,
		pictures = rblank(),
		radius_visualisation_picture = blank(),
		connection_points = {cwc0c()},
		localised_name = "",
		selectable_in_game = false,
	},
	{
		type = "electric-pole",
		name = "factory-power-connection",
		pictures = table.deepcopy(data.raw["electric-pole"]["small-electric-pole"].pictures),
		supply_area_distance = 0,
		connection_points = {cwc0c(), cwc0c(), cwc0c(), cwc0c()},
		draw_copper_wires = false,
		maximum_wire_distance = 1,
		collision_box = table.deepcopy(data.raw["electric-pole"]["small-electric-pole"].collision_box),
		selection_box = table.deepcopy(data.raw["electric-pole"]["small-electric-pole"].selection_box),
		collision_mask = {},
		flags = {"not-on-map", "hidden"},
		max_health = 1,
		radius_visualisation_picture = blank(),
		localised_name = "",
	},
})

local overlay_controller = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
overlay_controller.name = "factory-overlay-controller"
overlay_controller.circuit_wire_max_distance = 0
data:extend({
	overlay_controller
})

local function create_dummy_connector(dir, dx, dy, pictures)
	data:extend({
		{
			type = "pipe",
			name = "factory-fluid-dummy-connector-" .. dir,
			flags = {"not-on-map", "hide-alt-info"},
			minable = nil,
			max_health = 500,
			selection_box = {{-0.4,-0.4},{0.4,0.4}},
			selectable_in_game = false,
			collision_box = {{-0.4,-0.4},{0.4,0.4}},
			collision_mask = {},
			fluid_box = {
				base_area = 1, -- Heresy
				pipe_connections = {
					{position = {dx, dy}, type = "output"},
				},
			},
			horizontal_window_bounding_box = {{0,0},{0,0}},
			vertical_window_bounding_box = {{0,0},{0,0}},
			pictures = pictures,
			vehicle_impact_sound = {filename = "__base__/sound/car-metal-impact.ogg", volume = 0.65},
		},
	})
end

-- Connectors are named by the direction they are facing,
-- so that their names can be generated using cpos.direction_in or cpos.direction_out
create_dummy_connector(defines.direction.south, 0, 1, southpipepictures())
create_dummy_connector(defines.direction.north, 0, -1, blankpipepictures())
create_dummy_connector(defines.direction.east, 1, 0, blankpipepictures())
create_dummy_connector(defines.direction.west, -1, 0, blankpipepictures())
