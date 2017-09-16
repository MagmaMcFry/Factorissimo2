require("util")
require("constants")
local Constants = Constants

local F = "__Factorissimo2__";

local function cwc0()
	return {shadow = {red = {0,0},green = {0,0}}, wire = {red = {0,0},green = {0,0}}}
end
local function cc0()
	return get_circuit_connector_sprites({0,0},nil,1)
end


function factory_base(params, suffix, result_suffix, visible, count, properties)
	local name = params.name .. suffix
	local result_name = params.name .. result_suffix
	local item_flags
	if visible then item_flags = {"goes-to-quickbar"} else item_flags = {"hidden"} end
	
	return merge_properties({
		name = name,
		type = "storage-tank",
		icon = params.icon,
		max_health = params.max_health,
		flags = {"player-creation"},
		minable = {mining_time = 5, result = result_name, count = count},
		allow_copy_paste = true,
		additional_pastable_entities = {"storage-tank"},
		vehicle_impact_sound = { filename = "__base__/sound/car-stone-impact.ogg", volume = 1.0 },
		corpse = "big-remnants",
		window_bounding_box = centered_square(0),
		selection_box = properties.collision_box,
		fluid_box = {
			base_area = 1,
			pipe_covers = pipecoverspictures(),
			pipe_connections = {},
		},
		flow_length_in_ticks = 1,
		circuit_wire_connection_points = {cwc0(), cwc0(), cwc0(), cwc0()},
		circuit_connector_sprites = {cc0(), cc0(), cc0(), cc0()},
		circuit_wire_max_distance = 0,
		map_color = {r = 0.8, g = 0.7, b = 0.55},
	}, properties)
end

function factory_item_base(params, suffix, visible, properties)
	local name = params.name .. suffix
	local item_flags
	if visible then item_flags = {"goes-to-quickbar"} else item_flags = {"hidden"} end
	
	return merge_properties({
		name = name,
		type = "item",
		subgroup = "factorissimo2",
		icon = params.icon,
		order = params.order,
		flags = item_flags,
		place_result = name,
		stack_size = 1,
	}, properties)
end

function factory_overlay_base(properties)
	return merge_properties({
		type = "simple-entity",
		flags = {"not-on-map"},
		minable = nil,
		max_health = 1,
		corpse = "big-remnants",
		selection_box = properties.collision_box,
		collision_mask = {},
		selectable_in_game = false,
		render_layer = "object",
	}, properties)
end

local factory_1 = function(params, suffix, result_suffix, visible, count, sprite)
	return {
		factory_base(params, suffix, result_suffix, visible, count, {
			collision_box = centered_square(7.6),
			pictures = {
				picture = {
					sheet = {
						filename = sprite,
						frames = 1,
						width = 416,
						height = 320,
						shift = {1.5, 0},
					},
				},
				fluid_background = blank(),
				window_background = blank(),
				flow_sprite = blank(),
				gas_flow = ablank(),
			},
		}),
		factory_item_base(params, suffix, visible, { })
	};
end

local factory_2 = function(params, suffix, result_suffix, visible, count, sprite)
	return {
		factory_base(params, suffix, result_suffix, visible, count, {
			collision_box = centered_square(11.6),
			pictures = {
				picture = {
					sheet = {
						filename = sprite,
						frames = 1,
						width = 544,
						height = 448,
						shift = {1.5, 0},
					},
				},
				fluid_background = blank(),
				window_background = blank(),
				flow_sprite = blank(),
				gas_flow = ablank(),
			},
		}),
		factory_item_base(params, suffix, visible, { })
	};
end

local factory_3 = function(params, suffix, result_suffix, visible, count, sprite)
	return {
		factory_base(params, suffix, result_suffix, visible, count, {
			collision_box = centered_square(15.6),
			pictures = {
				picture = {
					sheet = {
						filename = sprite,
						frames = 1,
						width = 704,
						height = 608,
						shift = {2, -0.09375},
					},
				},
				fluid_background = blank(),
				window_background = blank(),
				flow_sprite = blank(),
				gas_flow = ablank(),
			},
		}),
		factory_item_base(params, suffix, visible, { })
	};
end

function create_factory_entities(func, params)
	-- Craftable factory object, with no corresponding interior generated
	data:extend(func(params, "", "", true, 0, params.image))
	
	-- Inactive factory object, for when the player put down a factory building
	-- but it was invalid in some way (eg recursion without the technology
	-- being researched).
	data:extend(func(params, "-i", "", false, 1, params.combined_image))
	
	-- Saved factory entities - that is, for when the player placed a factory,
	-- populated it, and then picked it back up. There's a set of special
	-- entities for these (since entity-type-name is the only property that
	-- gets reliably preserved when in inventory), and that's the maximum
	-- number of factories you can have picked up.
	for i=Constants.factory_id_min,Constants.factory_id_max do
		data:extend(func(params, "-s" .. i, "-s" .. i, false, 1, params.combined_image))
	end
	
	-- Factory overlay entity
	data:extend({
		factory_overlay_base({
			name = params.name.."-overlay",
			collision_box = params.overlay_collision_box,
			picture = params.overlay_picture,
		})
	})
	
	-- Crafting recipe
	data:extend({
		{
			type = "recipe",
			name = params.name,
			enabled = false,
			result = params.name,
			
			energy_required = params.energy_required,
			ingredients = params.ingredients
		}
	})
end


create_factory_entities(factory_1, {
	name = "factory-1",
	image = F.."/graphics/factory/factory-1.png",
	combined_image = F.."/graphics/factory/factory-1-combined.png",
	icon = F.."/graphics/icon/factory-1.png",
	max_health = 2000,
	order = "a-a",
	
	energy_required = 30,
	ingredients = {{"stone", 500}, {"iron-plate", 500}, {"copper-plate", 100}},
	
	overlay_collision_box = shift_bounds_by(0, -3, centered_square(7.6)),
	overlay_picture = {
		filename = F.."/graphics/factory/factory-1-combined.png",
		width = 416,
		height = 320,
		shift = {1.5, -3}
	},
})
create_factory_entities(factory_2, {
	name = "factory-2",
	image = F.."/graphics/factory/factory-2.png",
	combined_image = F.."/graphics/factory/factory-2-combined.png",
	icon = F.."/graphics/icon/factory-2.png",
	max_health = 3500,
	order = "a-b",
	
	energy_required = 46,
	ingredients = {{"stone-brick", 1000}, {"steel-plate", 250}, {"big-electric-pole", 50}},
	
	overlay_collision_box = shift_bounds_by(0, -5, centered_square(11.6)),
	overlay_picture = {
		filename = F.."/graphics/factory/factory-2-combined.png",
		width = 544,
		height = 448,
		shift = {1.5, -5},
	},
})
create_factory_entities(factory_3, {
	name = "factory-3",
	image = F.."/graphics/factory/factory-3.png",
	combined_image = F.."/graphics/factory/factory-3-combined.png",
	icon = F.."/graphics/icon/factory-3.png",
	max_health = 5000,
	order = "a-c",
	
	energy_required = 60,
	ingredients = {{"concrete", 5000}, {"steel-plate", 2000}, {"substation", 100}},
	
	overlay_collision_box = shift_bounds_by(0, -7, centered_square(15.6)),
	overlay_picture = {
		filename = F.."/graphics/factory/factory-3-combined.png",
		width = 704,
		height = 608,
		shift = {2, -7.09375},
	},
})
