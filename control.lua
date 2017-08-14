require("config")
local Config = GetConfigs()

require("layout")
local HasLayout = HasLayout

require("connections")
local Connections = Connections

require("updates")
local Updates = Updates

require("constants")

local BlueprintString = require("blueprintstring.blueprintstring")
local serpent = require "blueprintstring.serpent0272"

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
	+outside_energy_sender = *,
	+outside_energy_receiver = *,
	+outside_overlay_displays = {*},
	+outside_fluid_dummy_connectors = {*},
	+outside_port_markers = {*},
	(+)outside_other_entities = {*},
	
	+inside_energy_sender = *,
	+inside_energy_receiver = *,
	+inside_overlay_controllers = {*},
	+inside_fluid_dummy_connectors = {*},
	(+)inside_other_entities = {*},
	+energy_indicator = *,
	
	+transfer_rate = *,
	+transfers_outside = *,
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
	-- List of all construction-requester chests
	global.construction_requester_chests = global.construction_requester_chests or {}
end

local prepare_gui = 0  -- Will be set to a function lower in the file

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
end)

script.on_configuration_changed(function(config_changed_data)
	init_globals()
	Updates.run()
	init_gui()
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

-- Don't mess with this unless you mess with prototypes/entity/component.lua too (in the place marked <E>).
-- Every number needs to correspond to a valid indicator entity name
local VALID_POWER_TRANSFER_RATES = {1,2,5,10,20,50,100,200,500,1000,2000,5000,10000,20000,50000,100000} -- MW

local function make_valid_transfer_rate(rate)
	for _,v in pairs(VALID_POWER_TRANSFER_RATES) do
		if v == rate then return v end
	end
	return 0 -- Catchall
end

local function update_power_settings(factory)
	if factory.built then
		local e = factory.transfer_rate*16667 -- conversion factor of MW to J/U
		if factory.transfers_outside then
			if factory.inside_energy_receiver then
				factory.inside_energy_receiver.electric_buffer_size = e
				factory.inside_energy_receiver.electric_input_flow_limit = e
				factory.inside_energy_receiver.electric_output_flow_limit = 0 -- Should fix bugs
				factory.inside_energy_receiver.energy = 0
			end
			if factory.inside_energy_sender then
				factory.inside_energy_sender.electric_buffer_size = e
				factory.inside_energy_sender.electric_input_flow_limit = 0 -- Should fix bugs
				factory.inside_energy_sender.electric_output_flow_limit = 0
				factory.inside_energy_sender.energy = e
			end
			if factory.outside_energy_receiver then
				factory.outside_energy_receiver.electric_buffer_size = e
				factory.outside_energy_receiver.electric_input_flow_limit = 0
				factory.outside_energy_receiver.energy = e
			end
			if factory.outside_energy_sender then
				factory.outside_energy_sender.electric_buffer_size = e
				factory.outside_energy_sender.electric_output_flow_limit = e
				factory.outside_energy_sender.energy = 0
			end
		else
			if factory.inside_energy_receiver then
				factory.inside_energy_receiver.electric_buffer_size = e
				factory.inside_energy_receiver.electric_input_flow_limit = 0
				factory.inside_energy_receiver.electric_output_flow_limit = 0 -- Should fix bugs
				factory.inside_energy_receiver.energy = e
			end
			if factory.inside_energy_sender then
				factory.inside_energy_sender.electric_buffer_size = e
				factory.inside_energy_sender.electric_input_flow_limit = 0 -- Should fix bugs
				factory.inside_energy_sender.electric_output_flow_limit = e
				factory.inside_energy_sender.energy = 0
			end
			if factory.outside_energy_receiver then
				factory.outside_energy_receiver.electric_buffer_size = e
				factory.outside_energy_receiver.electric_input_flow_limit = e
				factory.outside_energy_receiver.energy = 0
			end
			if factory.outside_energy_sender then
				factory.outside_energy_sender.electric_buffer_size = e
				factory.outside_energy_sender.electric_output_flow_limit = 0
				factory.outside_energy_sender.energy = e
			end
		end
	end
	if factory.energy_indicator and factory.energy_indicator.valid then
		factory.energy_indicator.destroy()
		factory.energy_indicator = nil
	end
	local direction = (factory.transfers_outside and defines.direction.south) or defines.direction.north
	local energy_indicator = factory.inside_surface.create_entity{
		name = "factory-connection-indicator-energy-d" .. make_valid_transfer_rate(factory.transfer_rate),
		direction = direction, force = factory.force,
		position = {x = factory.inside_x + factory.layout.energy_indicator_x, y = factory.inside_y + factory.layout.energy_indicator_y}
	}
	energy_indicator.destructible = false
	factory.energy_indicator = energy_indicator
end

local function adjust_power_transfer_rate(factory, positive)
	local transfer_rate = factory.transfer_rate
	if positive then
		for i = 1,#VALID_POWER_TRANSFER_RATES do
			if transfer_rate < VALID_POWER_TRANSFER_RATES[i] then
				transfer_rate = VALID_POWER_TRANSFER_RATES[i]
				break
			end
		end
		if transfer_rate > VALID_POWER_TRANSFER_RATES[#VALID_POWER_TRANSFER_RATES] then
			transfer_rate = VALID_POWER_TRANSFER_RATES[#VALID_POWER_TRANSFER_RATES]
		end
	else
		for i = #VALID_POWER_TRANSFER_RATES,1,-1 do
			if transfer_rate > VALID_POWER_TRANSFER_RATES[i] then
				transfer_rate = VALID_POWER_TRANSFER_RATES[i]
				break
			end
		end
		if transfer_rate < VALID_POWER_TRANSFER_RATES[1] then
			transfer_rate = VALID_POWER_TRANSFER_RATES[1]
		end
	end
	factory.transfer_rate = transfer_rate
	local power_string, transfer_text = "",""
	if transfer_rate >= 1000 then
		power_string = (transfer_rate / 1000) .. "GW"
	else
		power_string = transfer_rate .. "MW"
	end
	if positive then
		transfer_text = "factory-connection-text.power-transfer-increased"
	else
		transfer_text = "factory-connection-text.power-transfer-decreased"
	end
	factory.inside_surface.create_entity{
		name = "flying-text",
		position = {x = factory.inside_x + factory.layout.energy_indicator_x, y = factory.inside_y + factory.layout.energy_indicator_y}, color = {r = 228/255, g = 236/255, b = 0},
		text = {transfer_text, power_string}
	}
	update_power_settings(factory)
end

-- FACTORY UPGRADES --

--[[
local function build_power_upgrade(factory)
	if factory.upgrades.power then return end
	factory.upgrades.power = true
	local iet = factory.inside_surface.create_entity{name = "factory-power-pole", position = {factory.inside_x + factory.layout.inside_energy_x, factory.inside_y + factory.layout.inside_energy_y}, force = factory.force}
	iet.destructible = false
	table.insert(factory.inside_other_entities, iet)
end
]]--

local function build_lights_upgrade(factory)
	if factory.upgrades.lights then return end
	factory.upgrades.lights = true
	for _, pos in pairs(factory.layout.lights) do
		local light = factory.inside_surface.create_entity{name = "factory-ceiling-light", position = {factory.inside_x + pos.x, factory.inside_y + pos.y}, force = factory.force}
		light.destructible = false
		light.operable = false
		light.rotatable = false
		table.insert(factory.inside_other_entities, light)
	end
end

local function build_display_upgrade(factory)
	if factory.upgrades.display then return end
	factory.upgrades.display = true
	for id, pos in pairs(factory.layout.overlays) do
		local controller = factory.inside_surface.create_entity{name = "factory-overlay-controller", position = {factory.inside_x + pos.inside_x, factory.inside_y + pos.inside_y}, force = factory.force}
		controller.destructible = false
		controller.rotatable = false
		factory.inside_overlay_controllers[id] = controller
	end
end

-- OVERLAY MANAGEMENT --

local function update_overlay(factory)
	if factory.built then
		-- Do it this way because the controllers might not exist yet
		for id, controller in pairs(factory.inside_overlay_controllers) do
			local display = factory.outside_overlay_displays[id]
			if controller.valid and display and display.valid then
				local controller_inv = controller.get_inventory(defines.inventory.chest)
				local display_inv = display.get_inventory(defines.inventory.chest)
				display_inv.clear()
				for i =1,4 do
					local slot = controller_inv[i]
					if slot.valid_for_read then display_inv.insert(slot) end
				end
			end
		end
	end
end

-- FACTORY GENERATION --

local function create_factory_position()
	global.next_factory_surface = global.next_factory_surface + 1
	if (global.next_factory_surface > Config.max_surfaces) then
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
	
	-- To make void chunks show up on the map, you need to tell them they've finished generating.
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

	local ier = factory.inside_surface.create_entity{name = "factory-power-input-2", position = {factory.inside_x + layout.inside_energy_x, factory.inside_y + layout.inside_energy_y}, force = force}
	ier.destructible = false
	ier.operable = false
	ier.rotatable = false
	factory.inside_energy_receiver = ier
	
	local ies = factory.inside_surface.create_entity{name = "factory-power-output-2", position = {factory.inside_x + layout.inside_energy_x, factory.inside_y + layout.inside_energy_y}, force = force}
	ies.destructible = false
	ies.operable = false
	ies.rotatable = false
	factory.inside_energy_sender = ies
	
	local iet = factory.inside_surface.create_entity{name = "factory-power-pole", position = {factory.inside_x + layout.inside_energy_x, factory.inside_y + layout.inside_energy_y}, force = force}
	iet.destructible = false
	
	factory.inside_other_entities = {iet}
	
	--if force.technologies["factory-interior-upgrade-power"].researched then
	--	build_power_upgrade(factory)
	--end
	
	if force.technologies["factory-interior-upgrade-lights"].researched then
		build_lights_upgrade(factory)
	end
	
	factory.inside_overlay_controllers = {}
	
	if force.technologies["factory-interior-upgrade-display"].researched then
		build_display_upgrade(factory)
	end
	
	factory.inside_fluid_dummy_connectors = {}
	
	for id, cpos in pairs(layout.connections) do
		local connector = factory.inside_surface.create_entity{name = "factory-fluid-dummy-connector", position = {factory.inside_x + cpos.inside_x + cpos.indicator_dx, factory.inside_y + cpos.inside_y + cpos.indicator_dy}, force = force, direction = cpos.direction_in}
		connector.destructible = false
		connector.operable = false
		connector.rotatable = false
		factory.inside_fluid_dummy_connectors[id] = connector
	end
	
	factory.transfer_rate = factory.layout.default_power_transfer_rate or 10 -- MW
	factory.transfers_outside = false
	
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
	
	local oes = factory.outside_surface.create_entity{name = layout.outside_energy_sender_type, position = {factory.outside_x, factory.outside_y}, force = force}
	oes.destructible = false
	oes.operable = false
	oes.rotatable = false
	factory.outside_energy_sender = oes
	
	factory.outside_overlay_displays = {}
	
	for id, pos in pairs(layout.overlays) do
		local display = factory.outside_surface.create_entity{name = "factory-overlay-display", position = {factory.outside_x + pos.outside_x, factory.outside_y + pos.outside_y}, force = force}
		display.destructible = false
		display.operable = false
		display.rotatable = false
		factory.outside_overlay_displays[id] = display
	end
	
	factory.outside_fluid_dummy_connectors = {}
	
	for id, cpos in pairs(layout.connections) do
		local name = ((cpos.direction_out == defines.direction.south and "factory-fluid-dummy-connector-south") or "factory-fluid-dummy-connector")
		local connector = factory.outside_surface.create_entity{name = name, position = {factory.outside_x + cpos.outside_x - cpos.indicator_dx, factory.outside_y + cpos.outside_y - cpos.indicator_dy}, force = force, direction = cpos.direction_out}
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
	
	update_power_settings(factory)
	Connections.recheck_factory(factory, nil, nil)
	update_overlay(factory)
	return factory
end

local function toggle_port_markers(factory)
	if not factory.built then return end
	if #(factory.outside_port_markers) == 0 then
		for id, cpos in pairs(factory.layout.connections) do
			local marker = factory.outside_surface.create_entity{name = "factory-port-marker", position = {
			factory.outside_x + cpos.outside_x-cpos.indicator_dx, factory.outside_y + cpos.outside_y-cpos.indicator_dy}, force = factory.force, direction = cpos.direction_out}
			marker.destructible = false
			marker.operable = false
			marker.rotatable = false
			marker.active = false
			table.insert(factory.outside_port_markers, marker)
		end
	else
		for _, entity in pairs(factory.outside_port_markers) do entity.destroy() end
		factory.outside_port_markers = {}
	end
end

local function cleanup_factory_exterior(factory, building)
	Connections.disconnect_factory(factory)
	factory.outside_energy_sender.destroy()
	factory.outside_energy_receiver.destroy()
	for _, entity in pairs(factory.outside_overlay_displays) do entity.destroy() end
	factory.outside_overlay_displays = {}
	for _, entity in pairs(factory.outside_fluid_dummy_connectors) do entity.destroy() end
	factory.outside_fluid_dummy_connectors = {}
	for _, entity in pairs(factory.outside_port_markers) do entity.destroy() end
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
	for n = Constants.factory_id_min,Constants.factory_id_max do
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
	local n = entity.request_slot_count
	if n == 0 then return end
	local last_slot = entity.get_request_slot(n)
	local begin_after = last_slot and last_slot.name
	local saved_factories = global.saved_factories
	if not(begin_after and saved_factories[begin_after] and next(saved_factories,begin_after)) then begin_after = nil end
	local i = 0
	for sf,_ in next, saved_factories,begin_after do
		i = i+1
		entity.set_request_slot({name=sf,count=1},i)
		if i >= n then return end		
	end
	for j=i+1,n do
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
	local main_inventory = player.get_inventory(defines.inventory.player_main)
	local quickbar = player.get_inventory(defines.inventory.player_quickbar)
	for save_name,_ in pairs(global.saved_factories) do
		if main_inventory.get_item_count(save_name) + quickbar.get_item_count(save_name) == 0 and not (player.cursor_stack and player.cursor_stack.valid_for_read and player.cursor_stack.name == save_name) then
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
	if outer_tier >= tier and (factory.force.technologies["factory-recursion-t2"].researched or settings.global["Factorissimo2-free-recursion"].value) then return true end
	if outer_tier > tier then
		surface.create_entity{name="flying-text", position=position, text={"factory-connection-text.invalid-placement-recursion-1"}}
	elseif outer_tier >= tier then
		surface.create_entity{name="flying-text", position=position, text={"factory-connection-text.invalid-placement-recursion-2"}}
	else
		surface.create_entity{name="flying-text", position=position, text={"factory-connection-text.invalid-placement"}}
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

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
	local entity = event.created_entity
	on_entity_built(entity)
end)

function on_entity_built(entity)
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
		
		-- Look for adjacent factory-contents-markers and ghosts thereof. If
		-- found, unpack its blueprint, delete it, and put a
		-- factory-construction-requester-chest in its place.
		local content_marker_ghost = find_factory_content_marker_near(entity)
		if content_marker_ghost ~= nil then
			-- Revive the factory-contents-marker show we can get the alert
			-- message (abused to contain a blueprint string) out of it.
			collisions,content_marker = content_marker_ghost.revive()
			blueprint_string = content_marker.alert_parameters.alert_message
			
			-- Replace the factory-contents-marker with a factory-construction-
			-- requester-chest.
			local position = content_marker.position
			local surface = content_marker.surface
			local force = content_marker.force
			content_marker.destroy()
			local construction_chest = surface.create_entity{
				name="factory-construction-requester-chest",
				position=position,
				force=force
			}
			
			-- Apply the blueprint to the factory, filling it with ghosts
			local factory = get_factory_by_entity(entity)
			apply_blueprint_to_factory(factory, entity.force, blueprint_string,
				entity.orientation)
			
			-- Initialize the newly-created requester chest
			init_construction_chest(construction_chest)
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
	elseif entity.name == "factory-construction-requester-chest" then
		init_construction_chest(entity)
	else
		if Connections.is_connectable(entity) then
			recheck_nearby_connections(entity)
		end
		if entity.name == "factory-requester-chest" then
			init_factory_requester_chest(entity)
		end
	end
end

function find_factory_content_marker_near(entity)
	local search_area = neighbor_area_from_collision_box(entity.position, entity.prototype.collision_box)
	
	local nearby = entity.surface.find_entities(search_area)
	
	for _,ghost in pairs(nearby) do
		if ghost.name == "entity-ghost" and ghost.ghost_name == "factory-contents-marker" then
			return ghost
		end
	end
	return nil
end

-- Return an area that includes all tiles that would touch an object that's at
-- the given position and has the given collision box.
function neighbor_area_from_collision_box(position, collision_box)
	return {
		left_top = {
			x = position.x + collision_box.left_top.x - 1,
			y = position.y + collision_box.left_top.y - 1,
		},
		right_bottom = {
			x = position.x + collision_box.right_bottom.x + 1,
			y = position.y + collision_box.right_bottom.y + 1,
		}
	}
end

function list_to_index(list)
	index = {}
	for _,v in pairs(list) do
		index[v] = true
	end
	return index
end

local entities_ignored_when_copying = list_to_index({
	"factory-ceiling-light", "factory-fluid-dummy-connector",
	"factory-overlay-controller"})

script.on_event({defines.events.on_entity_settings_pasted}, function(event)
	if event.source.name==event.destination.name and HasLayout(event.source.name) then
		-- "Paste settings" from one factory to another. Create ghosts in the
		-- destination factory to match buildings in the source factory.
		local player = game.players[event.player_index]

		local source_factory = get_factory_by_entity(event.source)
		local dest_factory = get_factory_by_entity(event.destination)
		
		local blueprint_string = factory_to_blueprint_string(source_factory, player.force)
		apply_blueprint_to_factory(dest_factory, player.force, blueprint_string,
			defines.direction.north)
	end
end)

function factory_to_blueprint_string(factory, force)
	-- Create a blueprint covering the contents of a factory floor
	local blueprint = factory.inside_surface.create_entity{
		name = "item-on-ground",
		position = {0,0},
		stack = { name="blueprint" },
	}
	
	local bounds_markers = place_bounds_markers(
		factory.inside_surface, force, get_factory_inside_area(factory))
	
	local topleft_x = factory.inside_x - factory.layout.inside_size/2
	local topleft_y = factory.inside_y - factory.layout.inside_size/2
	local inside_area = get_factory_inside_area(factory)
	blueprint.stack.create_blueprint{
		surface=factory.inside_surface,
		force=force,
		area=inside_area,
	}
	
	-- Modify the blueprint to filter out entities with skipped types
	filter_blueprint_entities(blueprint.stack, entities_ignored_when_copying)
	
	-- Modify the blueprint to record the contents of any nested factories
	blueprint_record_factory_contents(blueprint.stack, inside_area, factory.inside_surface, force)
	
	local blueprint_table = {
		entities = blueprint.stack.get_blueprint_entities(),
		tiles = blueprint.stack.get_blueprint_tiles(),
		icons = blueprint.stack.blueprint_icons,
		name = "Factory blueprint",
	}
	
	-- Serialize
	local blueprintString = BlueprintString.toString(blueprint_table)
	
	-- Clean up the temporary blueprint object and bounds markers
	blueprint.destroy()
	remove_bounds_markers(factory.inside_surface, get_factory_inside_area(factory))
	
	return blueprintString
end

function get_factory_inside_area(factory)
	-- FIXME: This (a) assumes factories are always square, and (b) probably has
	-- an off-by-one-half or worse
	local size = factory.layout.inside_size+1
	local topleft_x = factory.inside_x - size/2
	local topleft_y = factory.inside_y - size/2
	return {
		left_top = {
			x = factory.inside_x - size/2,
			y = factory.inside_y - size/2,
		},
		right_bottom = {
			x = factory.inside_x + size/2,
			y = factory.inside_y + size/2,
		}
	}
end

function apply_blueprint_to_factory(factory, force, blueprint_string, direction)
	-- Unpack the blueprint
	local blueprint = factory.inside_surface.create_entity{
		name = "item-on-ground",
		position = {0,0},
		stack = { name="blueprint" },
	}
	
	local blueprint_table = BlueprintString.fromString(blueprint_string)
	blueprint.stack.set_blueprint_entities(blueprint_table.entities)
	blueprint.stack.set_blueprint_tiles(blueprint_table.tiles)
	blueprint.stack.blueprint_icons = blueprint_table.icons
	blueprint.stack.label = blueprint_table.name or ""
	
	local build_x = factory.inside_x
	local build_y = factory.inside_y
	
	local compass_dir = nil
	
	if direction == 0 then
		compass_dir = defines.direction.west
		build_y = build_y - 1
	elseif direction == 0.25 then
		compass_dir = defines.direction.north
	elseif direction == 0.5 then
		compass_dir = defines.direction.east
		build_x = build_x - 1
	elseif direction == 0.75 then
		compass_dir = defines.direction.south
		build_x = build_x - 1
		build_y = build_y - 1
	else
		game.print("ERROR: Trying to place factory in invalid orientation: "..direction)
		blueprint.destroy()
		return
	end
	
	local build_result = blueprint.stack.build_blueprint{
		surface=factory.inside_surface,
		force=force,
		position={build_x,build_y},
		force_build=true,
		direction = compass_dir,
	}
	
	-- Clean up the temporary blueprint object and bounds markers
	blueprint.destroy()
	remove_bounds_marker_ghosts(factory.inside_surface, get_factory_inside_area(factory))
end

function place_bounds_markers(surface, force, rect)
	return {
		place_bound_marker_at(surface, force, rect.left_top    .x, rect.left_top    .y),
		place_bound_marker_at(surface, force, rect.right_bottom.x, rect.left_top    .y),
		place_bound_marker_at(surface, force, rect.left_top    .x, rect.right_bottom.y),
		place_bound_marker_at(surface, force, rect.right_bottom.x, rect.right_bottom.y),
	}
end

function remove_bounds_markers(surface, rect)
	local to_remove = surface.find_entities_filtered{
		area = rect,
		name = "factory-bounds-marker",
	}
	for _,v in pairs(to_remove) do
		v.destroy()
	end
end

function remove_bounds_marker_ghosts(surface, rect)
	local to_remove = surface.find_entities_filtered{
		area = rect,
		name = "entity-ghost",
	}
	for _,v in pairs(to_remove) do
		if v.ghost_name == "factory-bounds-marker" then
			v.destroy()
		end
	end
end

function place_bound_marker_at(surface, force, x, y)
	return surface.create_entity{
		name = "factory-bounds-marker",
		position = {x,y},
		force = force,
	}
end

-- Given a blueprint, modify it to remove any entities that appear in
-- skipped_entity_types, a dict from entity type-names to true.
function filter_blueprint_entities(blueprint, skipped_entity_types)
	local blueprint_entities = blueprint.get_blueprint_entities()
	local filtered_blueprint_entities = {}
	for _,v in pairs(blueprint_entities) do
		if not skipped_entity_types[v.name] then
			table.insert(filtered_blueprint_entities, v)
		end
	end
	blueprint.set_blueprint_entities(filtered_blueprint_entities)
end

function init_construction_chest(construction_requester_chest)
	update_construction_chest(construction_requester_chest)
	table.insert(global.construction_requester_chests, construction_requester_chest)
end

function update_all_construction_requester_chests(tick)
	local num_chests = #global.construction_requester_chests
	local offset = (23*game.tick)%60+1
	while offset <= num_chests do
		local chest = global.construction_requester_chests[i]
		if chest and chest.valid then
			update_construction_chest(chest)
		else
			table.remove(global.construction_requester_chests, offset)
		end
		offset = offset + 60
	end
end

function update_construction_chest(construction_requester_chest)
	-- Find the factory this chest goes with
	local surface = construction_requester_chest.surface
	local position = construction_requester_chest.position
	local nearby_entities = surface.find_entities({
		left_top = {position.x-1, position.y-1},
		right_bottom = {position.x+1, position.y+1},
	})
	local factory = nil
	for _,nearby_entity in pairs(nearby_entities) do
		if HasLayout(nearby_entity.name) then
			factory = get_factory_by_entity(nearby_entity)
		end
	end
	
	
	if factory == nil then
		return
	end
	
	-- Get list of ghosts inside that factory
	local area = get_factory_inside_area(factory)
	local ghosts = factory.inside_surface.find_entities_filtered{
		area = area,
		name = "entity-ghost"
	}
	
	-- Count up items in the chest, available for construction
	local items_in_chest = construction_requester_chest.get_inventory(defines.inventory.chest).get_contents()
	local items_spent = {}
	
	-- Count up items requested for ghosts
	local unsatisfied_requests = {}
	local items_spent = {}
	for _,ghost in pairs(ghosts) do
		if ghost and ghost.valid and ghost.ghost_prototype and ghost.ghost_prototype.items_to_place_this then
			local item_needed = ghost.ghost_prototype.items_to_place_this
			local requests = {}
			for k,v in pairs(item_needed) do
				-- TODO: Handle alternatives? This only makes sense if a ghost can
				-- only be revived with one particular item type.
				-- (Which is how it normally works, but the API says there could
				-- be multiple things here.)
				requests[k] = 1
			end
			
			-- Can this request be satisfied?
			if request_is_satisfied(requests, items_in_chest) then
				collisions,revived = ghost.revive()
				if revived and revived.valid then
					for item,num in pairs(requests) do
						incr_default_0(items_spent, item, num)
						incr_default_0(items_in_chest, item, -num)
					end
					
					on_entity_built(revived)
				end
			else
				-- Add to the list of unsatisfied requests
				for item,num in pairs(requests) do
					incr_default_0(unsatisfied_requests, item, num)
				end
			end
		end
	end
	
	-- Look for construction-requester-chests inside, in order to build
	-- recursive factories.
	local recursive_chests = factory.inside_surface.find_entities_filtered{
		area = area,
		name = "factory-construction-requester-chest"
	}
	for _,chest in pairs(recursive_chests) do
		local chest_requests = get_chest_requests(chest)
		for item,num in pairs(chest_requests) do
			local items_to_transfer = 0
			if items_in_chest[item] ~= nil and items_in_chest[item] > 0 then
				-- We have an item that can satisfy this request
				items_to_transfer = math.min(num, items_in_chest[item])
				chest.insert({ name=item, count=items_to_transfer })
				incr_default_0(items_spent, item, items_to_transfer)
				incr_default_0(items_in_chest, item, -items_to_transfer)
			end
			if items_to_transfer < num then
				incr_default_0(unsatisfied_requests, item, num-items_to_transfer)
			end
		end
	end
	
	-- Remove spent items
	for item,num in pairs(items_spent) do
		construction_requester_chest.remove_item({
			name = item,
			count = num
		})
	end
	
	-- Apply item requests to requester-chest settings
	local num_request_slots = construction_requester_chest.request_slot_count
	local request_slot_index = 1
	for item,num in pairs(unsatisfied_requests) do
		local request = { name = item, count = num }
		construction_requester_chest.set_request_slot(request, request_slot_index)
		request_slot_index = request_slot_index+1
		if request_slot_index >= num_request_slots then
			break
		end
	end
	for i = request_slot_index,num_request_slots do
		construction_requester_chest.clear_request_slot(i)
	end
end

function get_chest_requests(chest)
	local requests = {}
	local num_request_slots = chest.request_slot_count
	for i=1,num_request_slots do
		local request = chest.get_request_slot(i)
		if request == nil then break end
		incr_default_0(requests, request.name, request.count)
	end
	return requests
end

function incr_default_0(dict, k, n)
	if dict[k] ~= nil then
		dict[k] = dict[k]+n
	else
		dict[k] = n
	end
	return dict
end

function request_is_satisfied(request, available)
	for k,v in pairs(request) do
		if available[k] == nil or available[k] < request[k] then
			return false
		end
	end
	return true
end

local pending_blueprints_by_player = {}

script.on_event(defines.events.on_player_setup_blueprint, function(event)
	local player_index = event.player_index
	local area = event.area
	local item = event.item
	local alt = event.alt
	
	local player = game.players[player_index]
	
	pending_blueprints_by_player[player_index] = {
		area = event.area,
		item = event.item,
		alt = event.alt,
		surface = player.surface,
	}
end)

script.on_event(defines.events.on_player_configured_blueprint, function(event)
	local player_index = event.player_index
	local area = pending_blueprints_by_player[player_index].area
	local player = game.players[player_index]
	local blueprint = player.cursor_stack
	local force = player.force
	
	-- Look at the surface the player was on when they set up the blueprint,
	-- not the surface they're on when they confirm it. (Otherwise this would
	-- go wrong if you entered/left a factory building while the blueprint
	-- dialog was up.)
	local surface = pending_blueprints_by_player[player_index].surface
	
	blueprint_record_factory_contents(blueprint, area, surface, force)
end)

function blueprint_record_factory_contents(blueprint, area, surface, force)
	-- Check whether the blueprint contains any factory buildings. If not, skip the
	-- rest of this.
	if not blueprint_contains_factories(blueprint) then
		return
	end
	
	-- Find the relation between world-coords and blueprint-coords.
	-- Find the factory with the lexicographically-first coordinates in each.
	-- They are the same factory; the difference between their positions is the
	-- blueprint offset.
	local ents_in_area = surface.find_entities(area)
	local blueprint_entities = blueprint.get_blueprint_entities()
	BlueprintString.remove_useless_fields(blueprint_entities)
	
	local first_blueprint_factory = lexicographically_first_factory_in(blueprint_entities)
	local first_world_factory = lexicographically_first_factory_in(ents_in_area)
	local blueprint_offset = {
		x = first_world_factory.position.x - first_blueprint_factory.position.x,
		y = first_world_factory.position.y - first_blueprint_factory.position.y,
	}
	
	-- Replace factory-construction-requester-chests in the blueprint with
	-- factory-contents-markers that hold the factory's blueprint
	-- To do this, we use BlueprintString's remove_useless_fields to reduce
	-- it to something manageable, then make the change there, then change it
	-- back.
	for i,entity in pairs(blueprint_entities) do
		if entity.name == "factory-construction-requester-chest" then
			-- Find the factory this chest touches (if any)
			local factory = nil
			for _,neighbor in pairs(ents_in_area) do
				if HasLayout(neighbor.name) then
					local dx = neighbor.position.x - blueprint_offset.x - entity.position.x
					local dy = neighbor.position.y - blueprint_offset.y - entity.position.y
					local collision_box = neighbor.prototype.collision_box
					
					if dx >= collision_box.left_top.x - 1 and
					   dx <= collision_box.right_bottom.x + 1 and
					   dy >= collision_box.left_top.y - 1 and
					   dy <= collision_box.right_bottom.y + 1
					then
						factory = get_factory_by_building(neighbor)
					end
				end
			end
			
			-- If the chest touches a factory, replace it with a factory-contents-marker
			if factory ~= nil then
				local blueprint_string = factory_to_blueprint_string(factory, force)
				entity.name = "factory-contents-marker"
				entity.parameters={
					playback_volume=0,
					playback_globally=false,
					allow_polyphony=false,
				}
				entity.alert_parameters={
					show_alert=true,
					show_on_map=false,
					alert_message=blueprint_string
				}
			end
		end
	end
	
	BlueprintString.fix_entities(blueprint_entities)
	blueprint.set_blueprint_entities(blueprint_entities)
end

function lexicographically_first_factory_in(entity_list)
	local first = true
	local first_entity = nil
	local first_position = nil
	for _,entity in pairs(entity_list) do
		if HasLayout(entity.name) then
			if first then
				first = false
				first_entity = entity
				first_position = entity.position
			else
				if entity.position.y < first_position.y or entity.position.y == first_position.y and entity.position.x < first_position.x then
					first_entity = entity
					first_position = entity.position
				end
			end
		end
	end
	return first_entity
end

-- Returns whether the given blueprint contains at least one factory building
function blueprint_contains_factories(blueprint)
	local entities = blueprint.get_blueprint_entities()
	for _,entity in pairs(entities) do
		if HasLayout(entity.name) then
			return true
		end
	end
	return false
end


-- How players pick up factories
-- Working factory buildings don't return items, so we have to manually give the player an item
script.on_event(defines.events.on_preplayer_mined_item, function(event)
	local entity = event.entity
	if HasLayout(entity.name) then
		local factory = get_factory_by_building(entity)
		if factory then
			local save = save_factory(factory)
			if save then
				cleanup_factory_exterior(factory, entity)
				local player = game.players[event.player_index]
				if player.can_insert{name = save, count = 1} then
					player.insert{name = save, count = 1}
				else
					player.print{"inventory-restriction.player-inventory-full", {"entity-name."..save}}
					player.surface.spill_item_stack({x=factory.outside_x, y=factory.outside_y}, {name = save, count = 1})
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
	end
end)

-- How robots pick up factories
-- Since you can't insert items into construction robots, we'll have to swap out factories for fake placeholder factories
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
				-- Don't cancel deconstruction (it'd cause another event), instead simply replace with new building
				local newbuilding = entity.surface.create_entity{name=entity.name, position=entity.position, force=factory.force}
				entity.destroy()
				set_entity_to_factory(newbuilding, factory)
				factory.building = newbuilding
				entity.surface.print("Could not pick up factory, too many factories picked up at once")			
			end
		end
	end
end)

-- Factories also need to start working again once they are unmarked
script.on_event(defines.events.on_canceled_deconstruction, function(event)
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
	end
end)

script.on_event(defines.events.on_robot_mined, function(event)
	local item = event.item
end)
-- How biters pick up factories
-- Too bad they don't have hands
script.on_event(defines.events.on_entity_died, function(event)
	local entity = event.entity
	if HasLayout(entity.name) then
		local factory = get_factory_by_building(entity)
		if factory then
			cleanup_factory_exterior(factory, entity)
			-- Don't save it. It will be inaccessible from now on.
			--save_factory(factory)
		end
	elseif Connections.is_connectable(entity) then
		recheck_nearby_connections(entity, true) -- Delay
	end
end)

-- GUI --

local function get_camera_parent(player)
	local parent = player.gui.top.factory_camera_placeholder
	if not parent then
		parent = player.gui.top.add{type="flow", name="factory_camera_placeholder"}
		parent.style.visible = false
	end
	return parent
end

-- prepare_gui was declared waaay above
prepare_gui = function(player)
	get_camera_parent(player)
end

local function set_camera(player, factory, inside)
	if not player.force.technologies["factory-preview"].researched then return end

	local ps = settings.get_player_settings(player)
	local ps_preview_enabled = ps["Factorissimo2-preview-enabled"]
	if ps_preview_enabled and not ps_preview_enabled.value then return end

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
	local gui = get_camera_parent(player)
	local camera_frame = gui.factory_camera_frame
	if camera_frame then
		local camera = camera_frame.factory_camera
		camera.position = position
		camera.surface_index = surface_index
		camera.zoom = zoom
	else
		gui.style.visible = true
		local camera_frame = gui.add{type = "frame", name = "factory_camera_frame", style = "captionless_frame_style"}
		local camera = camera_frame.add{type = "camera", name = "factory_camera", position = position, surface_index = surface_index, zoom = zoom}
		camera.style.minimal_width = preview_size
		camera.style.minimal_height = preview_size
	end
end

local function unset_camera(player)
	local gui = get_camera_parent(player)
	local camera_frame = gui.factory_camera_frame
	if camera_frame then
		camera_frame.destroy()
		gui.style.visible = false
	end
end

local function update_camera(player)
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

-- TRAVEL --

local function enter_factory(player, factory)
	player.teleport({factory.inside_door_x, factory.inside_door_y},factory.inside_surface)
	global.last_player_teleport[player.index] = game.tick
	update_camera(player)
end

local function leave_factory(player, factory)
	player.teleport({factory.outside_door_x, factory.outside_door_y},factory.outside_surface)
	global.last_player_teleport[player.index] = game.tick
	update_camera(player)
	update_overlay(factory)
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
							enter_factory(player, factory)
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

-- POWER MANAGEMENT --

local function transfer_power(from, to)
	local energy = from.energy+to.energy
	local ebs = to.electric_buffer_size
	if energy > ebs then
		to.energy = ebs
		from.energy = energy - ebs
	else
		to.energy = energy
		from.energy = 0
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
	-- Transfer power
	for _, factory in pairs(factories) do
		if factory.built then
			if factory.transfers_outside then
				transfer_power(factory.inside_energy_receiver, factory.outside_energy_sender)
			else
				transfer_power(factory.outside_energy_receiver, factory.inside_energy_sender)
			end
		end
	end
	
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
	
	update_all_construction_requester_chests()
end)

-- CONNECTION SETTINGS --

local CONNECTION_INDICATOR_NAMES = {}
for _,name in pairs(Connections.indicator_names) do
	CONNECTION_INDICATOR_NAMES["factory-connection-indicator-" .. name] = true
end

CONNECTION_INDICATOR_NAMES["factory-connection-indicator-energy-d0"] = true
for _,rate in pairs(VALID_POWER_TRANSFER_RATES) do
	CONNECTION_INDICATOR_NAMES["factory-connection-indicator-energy-d" .. rate] = true
end

script.on_event(defines.events.on_player_rotated_entity, function(event)
	--game.print("Rotated!")
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
			if factory.energy_indicator and factory.energy_indicator.valid and factory.energy_indicator.unit_number == entity.unit_number then
				factory.transfers_outside = not factory.transfers_outside
				factory.inside_surface.create_entity{
					name = "flying-text",
					position = entity.position,
					color = {r = 228/255, g = 236/255, b = 0},
					text = (factory.transfers_outside and {"factory-connection-text.output-mode"}) or {"factory-connection-text.input-mode"}
				}
				update_power_settings(factory)
			else
				Connections.rotate(factory, entity)
			end
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
			if factory.energy_indicator and factory.energy_indicator.valid and factory.energy_indicator.unit_number == entity.unit_number then
				adjust_power_transfer_rate(factory, true)
			else
				Connections.adjust(factory, entity, true)
			end
		end
	end
end)

script.on_event("factory-decrease", function(event)
	local entity = game.players[event.player_index].selected
	if not entity then return end
	if CONNECTION_INDICATOR_NAMES[entity.name] then
		local factory = find_surrounding_factory(entity.surface, entity.position)
		if factory then
			if factory.energy_indicator and factory.energy_indicator.valid and factory.energy_indicator.unit_number == entity.unit_number then
				adjust_power_transfer_rate(factory, false)
			else
				Connections.adjust(factory, entity, false)
			end
		end
	end
end)

-- MISC --

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
	local setting = event.setting
	if setting == "Factorissimo2-hide-recursion" then
		if settings.global["Factorissimo2-hide-recursion"] and settings.global["Factorissimo2-hide-recursion"].value then
			for _, force in pairs(game.forces) do
				force.technologies["factory-recursion-t1"].enabled = false
				force.technologies["factory-recursion-t2"].enabled = false
			end
		else
			for _, force in pairs(game.forces) do
				force.technologies["factory-recursion-t1"].enabled = true
				force.technologies["factory-recursion-t2"].enabled = true
			end
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
	end
end) 
