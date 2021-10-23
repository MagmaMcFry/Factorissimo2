require("layout")
local HasLayout = HasLayout

require("connections")
local Connections = Connections

require("updates")
local Updates = Updates

require("compat.factoriomaps")

local mod_gui = require("mod-gui")
-- DATA STRUCTURE --

-- Factory buildings are entities of type "storage-tank" internally, because reasons
local BUILDING_TYPE = "storage-tank"

--[[
factory = {
	+outside_surface = *,
	+outside_x = *,
	+outside_y = *,
	+outside_door_x = *,
	+outside_door_y = *,

	+inside_surface = *,
	+inside_x = *,
	+inside_y = *,
	+inside_door_x = *,
	+inside_door_y = *,

	+force = *,
	+layout = *,
	+building = *,
	+outside_energy_receiver = *,
	+outside_overlay_displays = {*},
	+outside_fluid_dummy_connectors = {*},
	+outside_port_markers = {*},
	(+)outside_other_entities = {*},

	+inside_overlay_controller = *,
	+inside_fluid_dummy_connectors = {*},
	+inside_power_poles = {*},
	(+)outside_power_pole = *,

	(+)middleman_id = *,
	(+)direct_connection = *,

	+stored_pollution = *,

	+connections = {*},
	+connection_settings = {{*}*},
	+connection_indicators = {*},

	+upgrades = {},
}
]]--

-- INITIALIZATION --

local function init_globals()
	-- List of all factories
	global.factories = global.factories or {}
	-- Map: Save name -> Factory it is currently saving
	global.saved_factories = global.saved_factories or {}
	-- Map: Player or robot -> Save name to give him on the next relevant event
	global.pending_saves = global.pending_saves or {}
	-- Map: Entity unit number -> Factory it is a part of
	global.factories_by_entity = global.factories_by_entity or {}
	-- Map: Surface name -> list of factories on it
	global.surface_factories = global.surface_factories or {}
	-- Map: Surface name -> number of used factory spots on it
	global.surface_factory_counters = global.surface_factory_counters or {}
	-- Scalar
	global.next_factory_surface = global.next_factory_surface or 0
	-- Map: Player index -> Last teleport time
	global.last_player_teleport = global.last_player_teleport or {}
	-- Map: Player index -> Whether preview is activated
	global.player_preview_active = global.player_preview_active or {}
	-- List of all factory power pole middlemen
	global.middleman_power_poles = global.middleman_power_poles or {}
end

local prepare_gui = 0  -- Function stub
local update_hidden_techs = 0 -- Function stub
local power_middleman_surface = 0 -- Function stub
local cancel_creation = 0 -- Function stub

local function init_gui()
	for _, player in pairs(game.players) do
		prepare_gui(player)
	end
end

script.on_init(function()
	init_globals()
	Connections.init_data_structure()
	Updates.init()
	init_gui()
	power_middleman_surface()
	for _, force in pairs(game.forces) do
		update_hidden_techs(force)
	end
	Compat.handle_factoriomaps()
end)

script.on_load(function()
	Compat.handle_factoriomaps()
end)

script.on_configuration_changed(function(config_changed_data)
	init_globals()
	Updates.run()
	init_gui()
	power_middleman_surface()
	for surface_name, _ in pairs(global.surface_factories or {}) do
		if remote.interfaces["RSO"] then -- RSO compatibility
			pcall(remote.call, "RSO", "ignoreSurface", surface_name)
		end
	end
end)

-- DATA MANAGEMENT --

local function set_entity_to_factory(entity, factory)
	global.factories_by_entity[entity.unit_number] = factory
end

local function get_factory_by_entity(entity)
	if entity == nil then return nil end
	return global.factories_by_entity[entity.unit_number]
end

local function get_factory_by_building(entity)
	local factory = global.factories_by_entity[entity.unit_number]
	if factory == nil then
		game.print("ERROR: Unbound factory building: " .. entity.name .. "@" .. entity.surface.name .. "(" .. entity.position.x .. ", " .. entity.position.y .. ")")
	end
	return factory
end

local function find_factory_by_building(surface, area)
	local candidates = surface.find_entities_filtered{area=area, type=BUILDING_TYPE}
	for _,entity in pairs(candidates) do
		if HasLayout(entity.name) then return get_factory_by_building(entity) end
	end
	return nil
end

local function find_surrounding_factory(surface, position)
	local factories = global.surface_factories[surface.name]
	if factories == nil then return nil end
	local x = math.floor(0.5+position.x/(16*32))
	local y = math.floor(0.5+position.y/(16*32))
	if (x > 7 or x < 0) then return nil end
	return factories[8*y+x+1]
end

-- POWER MANAGEMENT --

function power_middleman_surface()
	if game.surfaces["factory-power-connection"] then
		return game.surfaces["factory-power-connection"]
	end
	
	if #game.surfaces == 256 then
		error("Unfortunately you have no available surfaces left for Factorissimo2. You cannot use Factorissimo2 on this map.")
	end
	
	local map_gen_settings = {height=1, width=1, property_expression_names={}}
	map_gen_settings.autoplace_settings = {
		["decorative"] = {treat_missing_as_default=false, settings={}},
		["entity"] = {treat_missing_as_default=false, settings={}},
		["tile"] = {treat_missing_as_default=false, settings={["out-of-map"]={}}},
	}
	
	local surface = game.create_surface("factory-power-connection", map_gen_settings)
	surface.set_chunk_generated_status({0, 0}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({-1, 0}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({0, -1}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({-1, -1}, defines.chunk_generated_status.entities)
	
	return surface
end

local function remove_direct_connection(factory)
	local dc = factory.direct_connection
	if not dc or not dc.valid then return end
	
	for _, pole in pairs(factory.inside_power_poles) do
		for _, neighbour in pairs(pole.neighbours.copper) do
			if neighbour == dc then
				local old = {}
				for _, neighbour in ipairs(dc.neighbours.copper) do
					if neighbour ~= pole then old[#old+1] = neighbour end
				end
				dc.disconnect_neighbour()
				for _, neighbour in ipairs(old) do
					dc.connect_neighbour(neighbour)
				end
				factory.direct_connection = nil
				return
			end
		end
	end
end

local function delete_middleman(i)
	local pole = global.middleman_power_poles[i]
	if pole == 0 then return end
	global.middleman_power_poles[i] = i < #global.middleman_power_poles and 0 or nil
	pole.destroy()
end

local function cleanup_middlemen()
	for i, pole in ipairs(global.middleman_power_poles) do
		if pole ~= 0 and #pole.neighbours.copper<2 then delete_middleman(i) end
	end
end

-- power poles can only connect to 5 other power poles. give priority to factory poles
local our_poles = {["factory-power-connection"] = true, ["factory-power-pole"] = true, ["factory-overflow-pole"] = true}
local function reduce_neighbours(pole)
	local neighbours = pole.neighbours.copper
	if #neighbours < 5 or #neighbours == 0 then return true end
	
	local n
	for i, neighbour in ipairs(neighbours) do
		if not our_poles[neighbour.name] and neighbour.surface == pole.surface then n = i break end
	end
	
	if n == nil then
		pole.surface.create_entity{name="flying-text", position=pole.position, text={"electric-pole-wire-limit-reached"}}
		return false
	end
	
	pole.disconnect_neighbour(neighbours[n])
	return true
end

local function available_pole(factory)
	local poles = factory.inside_power_poles
	for i, pole in ipairs(poles) do
		local next = poles[i+1]
		if next then
			next.connect_neighbour(pole)
		end
	end
	
	for i, pole in ipairs(poles) do
		if #pole.neighbours.copper < (i == #poles and 4 or 5) then return pole end
	end
	
	local layout = factory.layout
	local pole = factory.inside_surface.create_entity{name="factory-overflow-pole", position=poles[1].position, force=poles[1].force}
	pole.destructible = false
	pole.disconnect_neighbour()
	pole.connect_neighbour(poles[#poles])
	table.insert(poles, pole)
	return pole
end

local function connect_power(factory, pole)
	if not reduce_neighbours(pole) then return end
	factory.outside_power_pole = pole
	
	if factory.inside_surface.name ~= pole.surface.name then
		available_pole(factory).connect_neighbour(pole)
		factory.direct_connection = pole
		return
	end
	
	local n
	for i, pole in ipairs(global.middleman_power_poles) do
		if pole == 0 then n = i break end
	end
	n = n or #global.middleman_power_poles + 1
	
	local surface = power_middleman_surface()
	local middleman = surface.create_entity{name = "factory-power-connection", position = {2*(n%32), 2*math.floor(n/32)}, force = "neutral"}
	middleman.destructible = false
	global.middleman_power_poles[n] = middleman
	
	middleman.connect_neighbour(available_pole(factory))
	middleman.connect_neighbour(pole)
	
	factory.middleman_id = n
end

function update_power_connection(factory, pole) -- pole parameter is optional
	local electric_network = factory.outside_energy_receiver.electric_network_id
	if electric_network == nil then return end
	local surface = factory.outside_surface
	local x = factory.outside_x
	local y = factory.outside_y
	
	if not script.active_mods['factorissimo-power-pole-addon'] and global.surface_factory_counters[surface.name] then
		local surrounding = find_surrounding_factory(surface, {x=x, y=y})
		if surrounding then
			connect_power(factory, available_pole(surrounding))
			return
		end
	end
	
	-- find the nearest connected power pole
	local D = game.max_electric_pole_supply_area_distance + factory.layout.outside_size / 2
	local canidates = {}
	for _, entity in ipairs(surface.find_entities_filtered{type="electric-pole", area={{x-D, y-D}, {x+D,y+D}}}) do
		if entity.electric_network_id == electric_network and entity ~= pole then
			canidates[#canidates+1] = entity
		end
	end
	
	if #canidates == 0 then return end
	connect_power(factory, surface.get_closest({x, y}, canidates))
end

local function power_pole_placed(pole)
	local D = pole.prototype.supply_area_distance + 10
	local position = pole.position
	local x = position.x
	local y = position.y
	
	for _, entity in ipairs(pole.surface.find_entities_filtered{type=BUILDING_TYPE, area={{x-D, y-D}, {x+D,y+D}}}) do
		if not HasLayout(entity.name) then goto continue end
		factory = get_factory_by_building(entity)
		local electric_network = factory.outside_energy_receiver.electric_network_id
		if electric_network == nil or electric_network ~= pole.electric_network_id then goto continue end
		if electric_network == factory.inside_power_poles[1].electric_network_id then goto continue end
		
		connect_power(factory, pole)
		
		::continue::
	end
end

local function power_pole_destroyed(pole)
	pole.disconnect_neighbour()
	
	for _, factory in pairs(global.factories) do
		if factory.built and factory.outside_power_pole and factory.outside_power_pole.valid and factory.outside_power_pole == pole then
			update_power_connection(factory, pole)
		end
	end
	
	cleanup_middlemen()
end

-- FACTORY UPGRADES --

local function build_lights_upgrade(factory)
	if factory.upgrades.lights then return end
	factory.upgrades.lights = true
	factory.inside_surface.daytime = 1
end

function build_display_upgrade(factory)
	if not factory.force.technologies["factory-interior-upgrade-display"].researched then return end
	if factory.inside_overlay_controller and factory.inside_overlay_controller.valid then return end

	pos = factory.layout.overlays
	local controller = factory.inside_surface.create_entity{
		name = "factory-overlay-controller",
		position = {
			factory.inside_x + pos.inside_x,
			factory.inside_y + pos.inside_y
		},
		force = factory.force
	}
	controller.minable = false
	controller.destructible = false
	controller.rotatable = false
	factory.inside_overlay_controller = controller
end

-- OVERLAY MANAGEMENT --

local sprite_path_translation = {
	item = "item",
	fluid = "fluid",
	virtual = "virtual-signal",
}
local function draw_overlay_sprite(signal, target_entity, offset, scale, id_table)

	local sprite_name = sprite_path_translation[signal.type] .. "/" .. signal.name
	if target_entity.valid then
		local sprite_data = {
			sprite = sprite_name,
			x_scale = scale,
			y_scale = scale,
			target = target_entity,
			surface = target_entity.surface,
			only_in_alt_mode = true,
			render_layer = "entity-info-icon",
		}
		-- Fake shadows
		local shadow_radius = 0.07 * scale
		for _, shadow_offset in pairs({{0,shadow_radius}, {0, -shadow_radius}, {shadow_radius, 0}, {-shadow_radius, 0}}) do
			sprite_data.tint = {0, 0, 0, 0.5} -- Transparent black
			sprite_data.target_offset = {offset[1] + shadow_offset[1], offset[2] + shadow_offset[2]}
			table.insert(id_table, rendering.draw_sprite(sprite_data))
		end
		-- Proper sprite
		sprite_data.tint = nil
		sprite_data.target_offset = offset
		table.insert(id_table, rendering.draw_sprite(sprite_data))
	end
end

local function get_nice_overlay_arrangement(width, height, amount)
	-- Computes a nice arrangement of square sprites within a rectangle of given size
	-- Returned coordinates are relative to the center of the rectangle
	if amount <= 0 then return {} end
	local opt_rows = 1
	local opt_cols = 1
	local opt_scale = 0
	-- Determine the optimal number of rows to use
	-- This assumes width >= height
	for rows = 1, math.ceil(math.sqrt(amount)) do
		local cols = math.ceil(amount/rows)
		local scale = math.min(width/cols, height/rows)
		if scale > opt_scale then
			opt_rows = rows
			opt_cols = cols
			opt_scale = scale
		end
	end
	-- Adjust scale to ensure that sprites do not become too big
	opt_scale = math.pow(opt_scale, 0.8) * math.pow(1.5, 0.8 - 1)
	-- Create evenly spaced coordinates
	local result = {}
	for i = 0, amount-1 do
		local col = i % opt_cols
		local row = math.floor(i / opt_cols)
		local cols_in_row = (row < opt_rows - 1 and opt_cols or (amount - 1) % opt_cols + 1)
		table.insert(result, {
			x = (2 * col + 1 - cols_in_row) * width / (2 * opt_cols),
			y = (2 * row + 1 - opt_rows) * height / (2 * opt_rows),
			scale = opt_scale
		})
	end
	return result
end

function update_overlay(factory)
	for _, id in pairs(factory.outside_overlay_displays) do
		rendering.destroy(id)
	end
	factory.outside_overlay_displays = {}
	if factory.built and factory.inside_overlay_controller and factory.inside_overlay_controller.valid then
		local params = factory.inside_overlay_controller.get_or_create_control_behavior().parameters
		local nonempty_params = {}
		for _, param in pairs(params) do
			if param and param.signal and param.signal.name then
				table.insert(nonempty_params, param)
			end
		end
		local sprite_positions = get_nice_overlay_arrangement(
			factory.layout.overlays.outside_w,
			factory.layout.overlays.outside_h,
			#nonempty_params
		)
		local i = 0
		for _, param in pairs(nonempty_params) do
			i = i + 1
			draw_overlay_sprite(param.signal, factory.building,
				{
					sprite_positions[i].x + factory.layout.overlays.outside_x,
					sprite_positions[i].y + factory.layout.overlays.outside_y,
				},
				sprite_positions[i].scale,
			factory.outside_overlay_displays)
		end
	end
end

-- FACTORY GENERATION --

local function update_destructible(factory)
	if factory.built and factory.building.valid then
		factory.building.destructible = not settings.global["Factorissimo2-indestructible-buildings"].value
	end
end

local function create_factory_position()
	global.next_factory_surface = global.next_factory_surface + 1
	local max_surface_id = settings.global["Factorissimo2-max-surfaces"].value
	if (max_surface_id > 0 and global.next_factory_surface > max_surface_id) then
		global.next_factory_surface = 1
	end
	local surface_name = "Factory floor " .. global.next_factory_surface
	local surface = game.surfaces[surface_name]
	if surface == nil then
		if #(game.surfaces) < 256 then
			surface = game.create_surface(surface_name, {width = 2, height = 2})
			surface.daytime = 0.5
			surface.freeze_daytime = true
			if remote.interfaces["RSO"] then -- RSO compatibility
				pcall(remote.call, "RSO", "ignoreSurface", surface_name)
			end
		else
			global.next_factory_surface = 1
			surface_name = "Factory floor 1"
			surface = game.surfaces[surface_name]
			if surface == nil then
				error("Unfortunately you have no available surfaces left for Factorissimo2. You cannot use Factorissimo2 on this map.")
			end
		end
	end
	local n = global.surface_factory_counters[surface_name] or 0
	global.surface_factory_counters[surface_name] = n+1
	local cx = 16*(n % 8)
	local cy = 16*math.floor(n / 8)

	-- To make void chunks show up on the map, you need to tell them they"ve finished generating.
	surface.set_chunk_generated_status({cx-2, cy-2}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx-1, cy-2}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx+0, cy-2}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx+1, cy-2}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx-2, cy-1}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx-1, cy-1}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx+0, cy-1}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx+1, cy-1}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx-2, cy+0}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx-1, cy+0}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx+0, cy+0}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx+1, cy+0}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx-2, cy+1}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx-1, cy+1}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx+0, cy+1}, defines.chunk_generated_status.entities)
	surface.set_chunk_generated_status({cx+1, cy+1}, defines.chunk_generated_status.entities)
	surface.destroy_decoratives{area={{32*(cx-2),32*(cy-2)},{32*(cx+2),32*(cy+2)}}}

	local factory = {}
	factory.inside_surface = surface
	factory.inside_x = 32*cx
	factory.inside_y = 32*cy
	factory.stored_pollution = 0
	factory.upgrades = {}

	global.surface_factories[surface_name] = global.surface_factories[surface_name] or {}
	global.surface_factories[surface_name][n+1] = factory
	local fn = #(global.factories)+1
	global.factories[fn] = factory
	factory.id = fn

	return factory
end

local function add_tile_rect(tiles, tile_name, xmin, ymin, xmax, ymax) -- tiles is rw
	local i = #tiles
	for x = xmin, xmax-1 do
		for y = ymin, ymax-1 do
			i = i + 1
			tiles[i] = {name = tile_name, position = {x, y}}
		end
	end
end

local function add_tile_mosaic(tiles, tile_name, xmin, ymin, xmax, ymax, pattern) -- tiles is rw
	local i = #tiles
	for x = 0, xmax-xmin-1 do
		for y = 0, ymax-ymin-1 do
			if (string.sub(pattern[y+1],x+1, x+1) == "+") then
				i = i + 1
				tiles[i] = {name = tile_name, position = {x+xmin, y+ymin}}
			end
		end
	end
end

local function create_factory_interior(layout, force)
	local factory = create_factory_position()
	factory.layout = layout
	factory.force = force
	factory.inside_door_x = layout.inside_door_x + factory.inside_x
	factory.inside_door_y = layout.inside_door_y + factory.inside_y
	local tiles = {}
	for _, rect in pairs(layout.rectangles) do
		add_tile_rect(tiles, rect.tile, rect.x1 + factory.inside_x, rect.y1 + factory.inside_y, rect.x2 + factory.inside_x, rect.y2 + factory.inside_y)
	end
	for _, mosaic in pairs(layout.mosaics) do
		add_tile_mosaic(tiles, mosaic.tile, mosaic.x1 + factory.inside_x, mosaic.y1 + factory.inside_y, mosaic.x2 + factory.inside_x, mosaic.y2 + factory.inside_y, mosaic.pattern)
	end
	for _, cpos in pairs(layout.connections) do
		table.insert(tiles, {name = layout.connection_tile, position = {factory.inside_x + cpos.inside_x, factory.inside_y + cpos.inside_y}})
	end
	factory.inside_surface.set_tiles(tiles)

	local power_pole = factory.inside_surface.create_entity{name = "factory-power-pole", position = {factory.inside_x + layout.inside_energy_x, factory.inside_y + layout.inside_energy_y}, force = force}
	power_pole.destructible = false
	factory.inside_power_poles = {power_pole}

	if force.technologies["factory-interior-upgrade-lights"].researched then
		build_lights_upgrade(factory)
	end

	factory.inside_overlay_controllers = {}

	if force.technologies["factory-interior-upgrade-display"].researched then
		build_display_upgrade(factory)
	end

	factory.inside_fluid_dummy_connectors = {}

	for id, cpos in pairs(layout.connections) do
		local name = "factory-fluid-dummy-connector-" .. cpos.direction_in
		local connector = factory.inside_surface.create_entity{name = name, position = {factory.inside_x + cpos.inside_x + cpos.indicator_dx, factory.inside_y + cpos.inside_y + cpos.indicator_dy}, force = force}
		connector.destructible = false
		connector.operable = false
		connector.rotatable = false
		factory.inside_fluid_dummy_connectors[id] = connector
	end

	factory.connections = {}
	factory.connection_settings = {}
	factory.connection_indicators = {}

	return factory
end

local function create_factory_exterior(factory, building)
	local layout = factory.layout
	local force = factory.force
	factory.outside_x = building.position.x
	factory.outside_y = building.position.y
	factory.outside_door_x = factory.outside_x + layout.outside_door_x
	factory.outside_door_y = factory.outside_y + layout.outside_door_y
	factory.outside_surface = building.surface

	local oer = factory.outside_surface.create_entity{name = layout.outside_energy_receiver_type, position = {factory.outside_x, factory.outside_y}, force = force}
	oer.destructible = false
	oer.operable = false
	oer.rotatable = false
	factory.outside_energy_receiver = oer

	factory.outside_overlay_displays = {}

	factory.outside_fluid_dummy_connectors = {}

	for id, cpos in pairs(layout.connections) do
		local name = "factory-fluid-dummy-connector-" .. cpos.direction_out
		local connector = factory.outside_surface.create_entity{name = name, position = {factory.outside_x + cpos.outside_x - cpos.indicator_dx, factory.outside_y + cpos.outside_y - cpos.indicator_dy}, force = force}
		connector.destructible = false
		connector.operable = false
		connector.rotatable = false
		factory.outside_fluid_dummy_connectors[id] = connector
	end

	local overlay = factory.outside_surface.create_entity{name = factory.layout.overlay_name, position = {factory.outside_x + factory.layout.overlay_x, factory.outside_y + factory.layout.overlay_y}, force = force}
	overlay.destructible = false
	overlay.operable = false
	overlay.rotatable = false

	factory.outside_other_entities = {overlay}

	factory.outside_port_markers = {}

	set_entity_to_factory(building, factory)
	factory.building = building
	factory.built = true

	Connections.recheck_factory(factory, nil, nil)
	update_power_connection(factory)
	update_overlay(factory)
	update_destructible(factory)
	return factory
end

local function toggle_port_markers(factory)
	if not factory.built then return end
	if #(factory.outside_port_markers) == 0 then
		for id, cpos in pairs(factory.layout.connections) do
			local sprite_data = {
				sprite = "utility/indication_arrow",
				orientation = cpos.direction_out/8,
				target = factory.building,
				surface = factory.building.surface,
				target_offset = {cpos.outside_x - 0.5 * cpos.indicator_dx, cpos.outside_y - 0.5 * cpos.indicator_dy},
				only_in_alt_mode = true,
				render_layer = "entity-info-icon",
			}
			table.insert(factory.outside_port_markers, rendering.draw_sprite(sprite_data))
		end
	else
		for _, sprite in pairs(factory.outside_port_markers) do rendering.destroy(sprite) end
		factory.outside_port_markers = {}
	end
end

local function cleanup_factory_exterior(factory, building)
	factory.outside_energy_receiver.destroy()
	if factory.middleman_id then delete_middleman(factory.middleman_id) factory.middleman_id = nil end
	remove_direct_connection(factory)
	
	Connections.disconnect_factory(factory)
	for _, render_id in pairs(factory.outside_overlay_displays) do rendering.destroy(render_id) end
	factory.outside_overlay_displays = {}
	for _, entity in pairs(factory.outside_fluid_dummy_connectors) do entity.destroy() end
	factory.outside_fluid_dummy_connectors = {}
	for _, render_id in pairs(factory.outside_port_markers) do rendering.destroy(render_id) end
	factory.outside_port_markers = {}
	for _, entity in pairs(factory.outside_other_entities) do entity.destroy() end
	factory.outside_other_entities = {}
	factory.building = nil
	factory.built = false
end

-- FACTORY SAVING AND LOADING --

local SAVE_NAMES = {} -- Set of all valid factory save names
local SAVE_ITEMS = {}
for _,f in ipairs({"factory-1", "factory-2", "factory-3"}) do
	SAVE_ITEMS[f] = {}
	for n = 10,99 do
		SAVE_NAMES[f .. "-s" .. n] = true
		SAVE_ITEMS[f][n] = f .. "-s" .. n
	end
end

local function save_factory(factory)
	for _,sf in pairs(SAVE_ITEMS[factory.layout.name] or {}) do
		if global.saved_factories[sf] then
		else
			global.saved_factories[sf] = factory
			return sf
		end
	end
	--game.print("Could not save factory!")
	return nil
end

local function is_invalid_save_slot(name)
	return SAVE_NAMES[name] and not global.saved_factories[name]
end

local function init_factory_requester_chest(entity)
	local saved_factories = global.saved_factories
	local i = 0
	for sf,_ in pairs(saved_factories) do
		i = i+1
		entity.set_request_slot({name=sf,count=1},i)
	end
	for j=i+1,entity.request_slot_count do
		entity.clear_request_slot(j)
	end
end

commands.add_command("give-lost-factory-buildings", {"command-help-message.give-lost-factory-buildings"}, function(event)
	--game.print(serpent.line(event))
	local player = game.players[event.player_index]
	if not (player and player.connected and player.admin) then return end
	if event.parameter == "destroyed" then
		for _,factory in pairs(global.factories) do
			local saved_or_built = factory.built
			for _,saved_factory in pairs(global.saved_factories) do
				if saved_factory.id == factory.id then
					saved_or_built = true
					break
				end
			end
			if not saved_or_built then
				save_factory(factory)
			end
		end
	end
	local main_inventory =
		player.get_inventory(defines.inventory.player_main or defines.inventory.character_main)
		or player.get_inventory(defines.inventory.god_main)
	for save_name,_ in pairs(global.saved_factories) do
		if main_inventory.get_item_count(save_name) == 0 and not (player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == save_name) then
			player.insert{name = save_name, count = 1}
		end
	end
end)
-- FACTORY PLACEMENT AND DESTRUCTION --

local function can_place_factory_here(tier, surface, position)
	local factory = find_surrounding_factory(surface, position)
	if not factory then return true end
	local outer_tier = factory.layout.tier
	if outer_tier > tier and (factory.force.technologies["factory-recursion-t1"].researched or settings.global["Factorissimo2-free-recursion"].value) then return true end
	if (outer_tier >= tier or settings.global["Factorissimo2-better-recursion-2"].value)
		and (factory.force.technologies["factory-recursion-t2"].researched or settings.global["Factorissimo2-free-recursion"].value) then return true end
	if outer_tier > tier then
		surface.create_entity{name="flying-text", position=position, text={"factory-connection-text.invalid-placement-recursion-1"}, force = factory.force}
	elseif (outer_tier >= tier or settings.global["Factorissimo2-better-recursion-2"].value) then
		surface.create_entity{name="flying-text", position=position, text={"factory-connection-text.invalid-placement-recursion-2"}, force = factory.force}
	else
		surface.create_entity{name="flying-text", position=position, text={"factory-connection-text.invalid-placement"}, force = factory.force}
	end
	return false
end

local function recheck_nearby_connections(entity, delayed)
	local surface = entity.surface
	-- Find nearby factory buildings
	local bbox = entity.bounding_box
	-- Expand box by one tile to catch factories and also avoid illegal zero-area finds
	local bbox2 = {
		left_top = {x = bbox.left_top.x - 1.5, y = bbox.left_top.y - 1.5},
		right_bottom = {x = bbox.right_bottom.x + 1.5, y = bbox.right_bottom.y + 1.5}
	}
	local building_candidates = surface.find_entities_filtered{area = bbox2, type = BUILDING_TYPE}
	for _,candidate in pairs(building_candidates) do
		if candidate ~= entity and HasLayout(candidate.name) then
			local factory = get_factory_by_building(candidate)
			if factory then
				if delayed then
					Connections.recheck_factory_delayed(factory, bbox2, nil)
				else
					Connections.recheck_factory(factory, bbox2, nil)
				end
			end
		end
	end
	local surrounding_factory = find_surrounding_factory(surface, entity.position)
	if surrounding_factory then
		if delayed then
			Connections.recheck_factory_delayed(surrounding_factory, nil, bbox2)
		else
			Connections.recheck_factory(surrounding_factory, nil, bbox2)
		end
	end
end

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity, defines.events.script_raised_built, defines.events.script_raised_revive}, function(event)
	local entity = event.created_entity or event.entity
	--if BUILDING_TYPE ~= entity.type then return nil end
	if HasLayout(entity.name) then
		-- This is a fresh factory, we need to create it
		local layout = CreateLayout(entity.name)
		if can_place_factory_here(layout.tier, entity.surface, entity.position) then
			local factory = create_factory_interior(layout, entity.force)
			create_factory_exterior(factory, entity)
		else
			entity.surface.create_entity{name=entity.name .. "-i", position=entity.position, force=entity.force}
			entity.destroy()
		end
	elseif global.saved_factories[entity.name] then
		-- This is a saved factory, we need to unpack it
		local factory = global.saved_factories[entity.name]
		if can_place_factory_here(factory.layout.tier, entity.surface, entity.position) then
			global.saved_factories[entity.name] = nil
			local newbuilding = entity.surface.create_entity{name=factory.layout.name, position=entity.position, force=factory.force}
			newbuilding.last_user = entity.last_user
			create_factory_exterior(factory, newbuilding)
			entity.destroy()
		end
	elseif is_invalid_save_slot(entity.name) then
		entity.surface.create_entity{name="flying-text", position=entity.position, text={"factory-connection-text.invalid-factory-data"}}
		entity.destroy()
	elseif Connections.is_connectable(entity) then
		recheck_nearby_connections(entity)
	elseif entity.type == "electric-pole" then
		power_pole_placed(entity)
	elseif entity.type == "solar-panel" then
		if global.surface_factory_counters[entity.surface.name] then
			cancel_creation(entity, event.player_index, {"factory-connection-text.invalid-placement"})
		else
			entity.force.technologies["factory-interior-upgrade-lights"].researched = true
		end
	elseif entity.name == "factory-requester-chest" then
		init_factory_requester_chest(entity)
	end
end)


-- How players pick up factories
-- Working factory buildings don"t return items, so we have to manually give the player an item
script.on_event(defines.events.on_pre_player_mined_item, function(event)
	local entity = event.entity
	if HasLayout(entity.name) then
		local factory = get_factory_by_building(entity)
		if factory then
			local save = save_factory(factory)
			if save then
				cleanup_factory_exterior(factory, entity)
				local player = game.players[event.player_index]
				if player.insert{name = save, count = 1} < 1 then
					player.print{"inventory-restriction.player-inventory-full", {"entity-name."..save}}
					player.surface.spill_item_stack(player.position, {name = save, count = 1})
				end
			else
				local newbuilding = entity.surface.create_entity{name=entity.name, position=entity.position, force=factory.force}
				newbuilding.last_user = entity.last_user
				entity.destroy()
				set_entity_to_factory(newbuilding, factory)
				factory.building = newbuilding
				game.players[event.player_index].print("Could not pick up factory, too many factories picked up at once")
			end
		end
	elseif Connections.is_connectable(entity) then
		recheck_nearby_connections(entity, true) -- Delay
	elseif entity.type == 'electric-pole' then
		power_pole_destroyed(entity)
	end
end)

-- How robots pick up factories
-- Since you can"t insert items into construction robots, we"ll have to swap out factories for fake placeholder factories
-- as soon as they are marked for deconstruction, and swap them back should they be unmarked.
script.on_event(defines.events.on_marked_for_deconstruction, function(event)
	local entity = event.entity
	if HasLayout(entity.name) then
		local factory = get_factory_by_building(entity)
		if factory then
			local save = save_factory(factory)
			if save then
				-- Replace by placeholder
				cleanup_factory_exterior(factory, entity)
				local placeholder = entity.surface.create_entity{name=save, position=entity.position, force=factory.force}
				placeholder.order_deconstruction(factory.force)
				entity.destroy()
			else
				-- Not saved, so put it back
				-- Don"t cancel deconstruction (it"d cause another event), instead simply replace with new building
				local newbuilding = entity.surface.create_entity{name=entity.name, position=entity.position, force=factory.force}
				entity.destroy()
				set_entity_to_factory(newbuilding, factory)
				factory.building = newbuilding
				newbuilding.surface.print("Could not pick up factory, too many factories picked up at once. Place some down before you pick up more.")
			end
		end
	end
end)

-- Factories also need to start working again once they are unmarked
script.on_event(defines.events.on_cancelled_deconstruction, function(event)
	local entity = event.entity
	if global.saved_factories[entity.name] then
		-- Rebuild factory from save
		local factory = global.saved_factories[entity.name]
		if can_place_factory_here(factory.layout.tier, entity.surface, entity.position) then
			global.saved_factories[entity.name] = nil
			local newbuilding = entity.surface.create_entity{name=factory.layout.name, position=entity.position, force=factory.force}
			create_factory_exterior(factory, newbuilding)
			entity.destroy()
		end
	end
end)

-- We need to check when a robot mines a piece of a connection
script.on_event(defines.events.on_robot_pre_mined, function(event)
	local entity = event.entity
	if Connections.is_connectable(entity) then
		recheck_nearby_connections(entity, true) -- Delay
	elseif entity.type == 'electric-pole' then
		power_pole_destroyed(entity)
	end
end)

-- How biters pick up factories
-- Too bad they don"t have hands
script.on_event({defines.events.on_entity_died, defines.events.script_raised_destroy}, function(event)
	local entity = event.entity
	if HasLayout(entity.name) then
		local factory = get_factory_by_building(entity)
		if factory then
			cleanup_factory_exterior(factory, entity)
			-- Don"t save it. It will be inaccessible from now on.
			--save_factory(factory)
		end
	elseif Connections.is_connectable(entity) then
		recheck_nearby_connections(entity, true) -- Delay
	elseif entity.type == 'electric-pole' then
		power_pole_destroyed(entity)
	end
end)

-- How to clone your factory
-- This implementation will not actually clone factory buildings, but move them to where they were cloned.
local clone_forbidden_prefixes = {
	"factory-1-",
	"factory-2-",
	"factory-3-",
	"factory-power-input-",
	"factory-connection-indicator-",
	"factory-power-pole",
	"factory-ceiling-light",
	"factory-overlay-controller",
	"factory-overlay-display",
	"factory-port-marker",
	"factory-fluid-dummy-connector"
}

local function is_entity_clone_forbidden(name)
	for _, prefix in pairs(clone_forbidden_prefixes) do
		if name:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

script.on_event(defines.events.on_entity_cloned, function(event)
	local src_entity = event.source
	local dst_entity = event.destination
	if is_entity_clone_forbidden(dst_entity.name) then
		dst_entity.destroy()
	elseif HasLayout(src_entity.name) then
		local factory = get_factory_by_building(src_entity)
		cleanup_factory_exterior(factory, src_entity)
		if src_entity.valid then src_entity.destroy() end
		create_factory_exterior(factory, dst_entity)
	end
end)

-- GUI --

local function get_camera_toggle_button(player)
	local buttonflow = mod_gui.get_button_flow(player)
	local button = buttonflow.factory_camera_toggle_button or buttonflow.add{type="sprite-button", name="factory_camera_toggle_button", sprite="technology/factory-architecture-t1"}
	button.visible = player.force.technologies["factory-preview"].researched
	return button
end

local function get_camera_frame(player)
	local frameflow = mod_gui.get_frame_flow(player)
	local camera_frame = frameflow.factory_camera_frame
	if not camera_frame then
		camera_frame = frameflow.add{type = "frame", name = "factory_camera_frame", style = "captionless_frame"}
		camera_frame.visible = false
	end
	return camera_frame
end

-- prepare_gui was declared waaay above
prepare_gui = function(player)
	get_camera_toggle_button(player)
	get_camera_frame(player)
end

local function set_camera(player, factory, inside)
	if not player.force.technologies["factory-preview"].researched then return end

	local ps = settings.get_player_settings(player)
	local ps_preview_size = ps["Factorissimo2-preview-size"]
	local preview_size = ps_preview_size and ps_preview_size.value or 300
	local ps_preview_zoom = ps["Factorissimo2-preview-zoom"]
	local preview_zoom = ps_preview_zoom and ps_preview_zoom.value or 1
	local position, surface_index, zoom
	if not inside then
		position = {x = factory.outside_x, y = factory.outside_y}
		surface_index = factory.outside_surface.index
		zoom = (preview_size/(32/preview_zoom))/(8+factory.layout.outside_size)
	else
		position = {x = factory.inside_x, y = factory.inside_y}
		surface_index = factory.inside_surface.index
		zoom = (preview_size/(32/preview_zoom))/(5+factory.layout.inside_size)
	end
	local camera_frame = get_camera_frame(player)
	local camera = camera_frame.factory_camera
	if camera then
		camera.position = position
		camera.surface_index = surface_index
		camera.zoom = zoom
		camera.style.minimal_width = preview_size
		camera.style.minimal_height = preview_size
	else
		local camera = camera_frame.add{type = "camera", name = "factory_camera", position = position, surface_index = surface_index, zoom = zoom}
		camera.style.minimal_width = preview_size
		camera.style.minimal_height = preview_size
	end
	camera_frame.visible = true
end

local function unset_camera(player)
	get_camera_frame(player).visible = false
end

local function update_camera(player)
	if not global.player_preview_active[player.index] then return end
	if not player.force.technologies["factory-preview"].researched then return end
	local cursor_stack = player.cursor_stack
	if cursor_stack and cursor_stack.valid_for_read and global.saved_factories[cursor_stack.name] then
		set_camera(player, global.saved_factories[cursor_stack.name], true)
		return
	end
	local selected = player.selected
	if selected then
		local factory = get_factory_by_entity(player.selected)
		if factory then
			set_camera(player, factory, true)
			return
		elseif selected.name == "factory-power-pole" then
			local factory = find_surrounding_factory(player.surface, player.position)
			if factory then
				set_camera(player, factory, false)
				return
			end
		end
	end
	unset_camera(player)
end

script.on_event(defines.events.on_selected_entity_changed, function(event)
	update_camera(game.players[event.player_index])
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
	update_camera(game.players[event.player_index])
end)

script.on_event(defines.events.on_player_created, function(event)
	prepare_gui(game.players[event.player_index])
end)

script.on_event(defines.events.on_gui_click, function(event)
	local player = game.players[event.player_index]
	if event.element.valid and event.element.name == "factory_camera_toggle_button" then
		if global.player_preview_active[player.index] then
			get_camera_toggle_button(player).sprite = "technology/factory-architecture-t1"
			global.player_preview_active[player.index] = false
		else
			get_camera_toggle_button(player).sprite = "technology/factory-preview"
			global.player_preview_active[player.index] = true
		end
	end
end)

-- TRAVEL --

local function teleport_player_safely(player, surface, position)
	if player and player.character then
		position = surface.find_non_colliding_position(
			player.character.name, position, 5, 0.5, false
		) or position
	end
	player.teleport(position, surface)
	global.last_player_teleport[player.index] = game.tick
	update_camera(player)
end

local function enter_factory(player, factory)
	teleport_player_safely(
		player, factory.inside_surface,
		{factory.inside_door_x, factory.inside_door_y}
	)
end

local function leave_factory(player, factory)
	teleport_player_safely(
		player, factory.outside_surface,
		{factory.outside_door_x, factory.outside_door_y}
	)
	update_camera(player)
	update_overlay(factory)
end

local function player_may_enter_factory(player, factory)
	return player.force.name == factory.force.name
			or (player.force.get_friend(factory.force) and settings.global["Factorissimo2-allied-players-may-enter"].value)
			or settings.global["Factorissimo2-enemy-players-may-enter"].value
end

local function teleport_players()
	local tick = game.tick
	for player_index, player in pairs(game.players) do
		if player.connected and not player.driving and tick - (global.last_player_teleport[player_index] or 0) >= 45 then
			local walking_state = player.walking_state
			if walking_state.walking then
				if walking_state.direction == defines.direction.north
				or walking_state.direction == defines.direction.northeast
				or walking_state.direction == defines.direction.northwest then
					-- Enter factory
					local factory = find_factory_by_building(player.surface, {{player.position.x-0.2, player.position.y-0.3},{player.position.x+0.2, player.position.y}})
					if factory ~= nil then
						if math.abs(player.position.x-factory.outside_x)<0.6 then
							if player_may_enter_factory(player, factory) then
								enter_factory(player, factory)
							end
						end
					end
				elseif walking_state.direction == defines.direction.south
				or walking_state.direction == defines.direction.southeast
				or walking_state.direction == defines.direction.southwest then
					local factory = find_surrounding_factory(player.surface, player.position)
					if factory ~= nil then
						if player.position.y > factory.inside_door_y+1 then
							leave_factory(player, factory)
						end
					end
				end
			end
		end
	end
end

-- POLLUTION MANAGEMENT --

local function update_pollution(factory)
	local inside_surface = factory.inside_surface
	local pollution, cp = 0, 0
	local inside_x, inside_y = factory.inside_x, factory.inside_y

	cp = inside_surface.get_pollution({inside_x-16,inside_y-16})
	inside_surface.pollute({inside_x-16,inside_y-16},-cp)
	pollution = pollution + cp
	cp = inside_surface.get_pollution({inside_x+16,inside_y-16})
	inside_surface.pollute({inside_x+16,inside_y-16},-cp)
	pollution = pollution + cp
	cp = inside_surface.get_pollution({inside_x-16,inside_y+16})
	inside_surface.pollute({inside_x-16,inside_y+16},-cp)
	pollution = pollution + cp
	cp = inside_surface.get_pollution({inside_x+16,inside_y+16})
	inside_surface.pollute({inside_x+16,inside_y+16},-cp)
	pollution = pollution + cp
	if factory.built then
		factory.outside_surface.pollute({factory.outside_x, factory.outside_y}, pollution + factory.stored_pollution)
		factory.stored_pollution = 0
	else
		factory.stored_pollution = factory.stored_pollution + pollution
	end
end

-- ON TICK --

script.on_event(defines.events.on_tick, function(event)
	local factories = global.factories

	-- Transfer pollution
	local fn = #factories
	local offset = (23*event.tick)%60+1
	while offset <= fn do
		local factory = factories[offset]
		if factory ~= nil then update_pollution(factory) end
		offset = offset + 60
	end

	-- Update connections
	Connections.update() -- Duh

	-- Teleport players
	teleport_players() -- What did you expect
end)

-- CONNECTION SETTINGS --

local CONNECTION_INDICATOR_NAMES = {}
for _,name in pairs(Connections.indicator_names) do
	CONNECTION_INDICATOR_NAMES["factory-connection-indicator-" .. name] = true
end

script.on_event(defines.events.on_player_rotated_entity, function(event)
	local entity = event.entity
	if CONNECTION_INDICATOR_NAMES[entity.name] then
		-- Skip
	elseif Connections.is_connectable(entity) then
		recheck_nearby_connections(entity)
		if entity.type == "underground-belt" then
			local neighbour = entity.neighbours
			if neighbour then
				recheck_nearby_connections(neighbour)
			end
		end
	end
end)

script.on_event("factory-rotate", function(event)
	local entity = game.players[event.player_index].selected
	if not entity then return end
	if HasLayout(entity.name) then
		local factory = get_factory_by_building(entity)
		if factory then
			toggle_port_markers(factory)
		end
	elseif CONNECTION_INDICATOR_NAMES[entity.name] then
		local factory = find_surrounding_factory(entity.surface, entity.position)
		if factory then
			Connections.rotate(factory, entity)
		end
	elseif entity.name == "factory-requester-chest" then
		init_factory_requester_chest(entity)
	end
end)

script.on_event("factory-increase", function(event)
	local entity = game.players[event.player_index].selected
	if not entity then return end
	if CONNECTION_INDICATOR_NAMES[entity.name] then
		local factory = find_surrounding_factory(entity.surface, entity.position)
		if factory then
			Connections.adjust(factory, entity, true)
		end
	end
end)

script.on_event("factory-decrease", function(event)
	local entity = game.players[event.player_index].selected
	if not entity then return end
	if CONNECTION_INDICATOR_NAMES[entity.name] then
		local factory = find_surrounding_factory(entity.surface, entity.position)
		if factory then
			Connections.adjust(factory, entity, false)
		end
	end
end)

-- MISC --

function cancel_creation(entity, player_index, message)
	local inserted = 0
	local item_to_place = entity.prototype.items_to_place_this[1]
	local surface = entity.surface
	local position = entity.position
	local force = entity.force
	
	if player_index then
		local player = game.get_player(player_index)
		if player.mine_entity(entity, false) then
			inserted = 1
		elseif item_to_place then
			inserted = player.insert(item_to_place)
		end
	end
	
	entity.destroy{raise_destroy = true}
	
	if inserted == 0 and item_to_place then
		surface.spill_item_stack{
			enable_looted  = true,
			force = force,
			allow_belts = false,
			position = position,
			items = item_to_place
		}
	end
	
	if message then
		surface.create_entity{
			name = "flying-text",
			position = position,
			text = message,
			render_player_index = player_index
		}
	end
end

update_hidden_techs = function(force)
	if settings.global["Factorissimo2-hide-recursion"] and settings.global["Factorissimo2-hide-recursion"].value then
		force.technologies["factory-recursion-t1"].enabled = false
		force.technologies["factory-recursion-t2"].enabled = false
	elseif settings.global["Factorissimo2-hide-recursion-2"] and settings.global["Factorissimo2-hide-recursion-2"].value then
		force.technologies["factory-recursion-t1"].enabled = true
		force.technologies["factory-recursion-t2"].enabled = false
	else
		force.technologies["factory-recursion-t1"].enabled = true
		force.technologies["factory-recursion-t2"].enabled = true
	end
end

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	local setting = event.setting
	if setting == "Factorissimo2-hide-recursion" or setting == "Factorissimo2-hide-recursion-2" then
		for _, force in pairs(game.forces) do
			update_hidden_techs(force)
		end
	elseif setting == "Factorissimo2-indestructible-buildings" then
		for _, factory in pairs(global.factories) do
			update_destructible(factory)
		end
	end
end)

script.on_event(defines.events.on_force_created, function(event)
	local force = event.force
	update_hidden_techs(force)
end)

script.on_event(defines.events.on_forces_merging, function(event)
	for _, factory in pairs(global.factories) do
		if not factory.force.valid then
			factory.force = game.forces["player"]
		end
		if factory.force.name == event.source.name then
			factory.force = event.destination
		end
	end
end)

script.on_event(defines.events.on_research_finished, function(event)
	if not global.factories then return end -- In case any mod or scenario script calls LuaForce.research_all_technologies() during its on_init
	local research = event.research
	local name = research.name
	if name == "factory-connection-type-fluid" or name == "factory-connection-type-chest" or name == "factory-connection-type-circuit" then
		for _, factory in pairs(global.factories) do
			if factory.built then Connections.recheck_factory(factory, nil, nil) end
		end
	--elseif name == "factory-interior-upgrade-power" then
	--	for _, factory in pairs(global.factories) do build_power_upgrade(factory) end
	elseif name == "factory-interior-upgrade-lights" then
		for _, factory in pairs(global.factories) do build_lights_upgrade(factory) end
	elseif name == "factory-interior-upgrade-display" then
		for _, factory in pairs(global.factories) do build_display_upgrade(factory) end
	elseif name == "factory-interior-upgrade-roboport" then
		for _, factory in pairs(global.factories) do build_roboport_upgrade(factory) end
	-- elseif name == "factory-recursion-t1" or name == "factory-recursion-t2" then
		-- Nothing happens, because implementing stuff here would be horrible.
		-- You just gotta pick up and replace your invalid factories manually for them to work with the newly researched recursion.
	elseif name == "factory-preview" then
		for _, player in pairs(game.players) do get_camera_toggle_button(player) end
	end
end)
