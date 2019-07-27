require("config")
local Config = GetConfigs()

require("layout")
local HasLayout = HasLayout

require("connections")
local Connections = Connections

require("updates")
local Updates = Updates

require("compat.factoriomaps")

require("mod-gui")
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
	-- Map: Player index -> Whether preview is activated
	global.player_preview_active = global.player_preview_active or {}
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
	if settings.global["Factorissimo2-hide-recursion"] and settings.global["Factorissimo2-hide-recursion"].value then
		for _, force in pairs(game.forces) do
			force.technologies["factory-recursion-t1"].enabled = false
			force.technologies["factory-recursion-t2"].enabled = false
		end
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

-- Don't mess with this unless you mess with prototypes/entity/component.lua too.
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
		local layout = factory.layout
		-- Inside sender
		local new_ies = factory.inside_surface.create_entity{
			name = "factory-power-output-2-" .. factory.transfer_rate,
			position = {factory.inside_x + layout.inside_energy_x, factory.inside_y + layout.inside_energy_y},
			force = force
		}
		new_ies.destructible = false
		new_ies.operable = false
		new_ies.rotatable = false
		if factory.inside_energy_sender.valid then
			factory.inside_energy_sender.destroy()
		end
		factory.inside_energy_sender = new_ies

		-- Inside receiver
		local new_ier = factory.inside_surface.create_entity{
			name = "factory-power-input-2-" .. factory.transfer_rate,
			position = {factory.inside_x + layout.inside_energy_x, factory.inside_y + layout.inside_energy_y},
			force = force
		}
		new_ier.destructible = false
		new_ier.operable = false
		new_ier.rotatable = false
		if factory.inside_energy_receiver.valid then
			factory.inside_energy_receiver.destroy()
		end
		factory.inside_energy_receiver = new_ier

		-- Outside sender
		local new_oes = factory.outside_surface.create_entity{
			name = layout.outside_energy_sender_type .. "-" .. factory.transfer_rate,
			position = {factory.outside_x, factory.outside_y},
			force = factory.force
		}
		new_oes.destructible = false
		new_oes.operable = false
		new_oes.rotatable = false
		if factory.outside_energy_sender.valid then
			factory.outside_energy_sender.destroy()
		end
		factory.outside_energy_sender = new_oes

		-- Outside receiver
		local new_oer = factory.outside_surface.create_entity{
			name = layout.outside_energy_receiver_type .. "-" .. factory.transfer_rate,
			position = {factory.outside_x, factory.outside_y},
			force = factory.force
		}
		new_oer.destructible = false
		new_oer.operable = false
		new_oer.rotatable = false
		if factory.outside_energy_receiver.valid then
			factory.outside_energy_receiver.destroy()
		end
		factory.outside_energy_receiver = new_oer

		local e = factory.transfer_rate*16667 -- conversion factor of MW to J/U
		if factory.transfers_outside then
			factory.inside_energy_sender.energy = 0--e
			factory.inside_energy_receiver.energy = 0
			factory.outside_energy_sender.energy = 0
			factory.outside_energy_receiver.energy = 0--e
		else
			factory.inside_energy_sender.energy = 0
			factory.inside_energy_receiver.energy = 0--e
			factory.outside_energy_sender.energy = 0--e
			factory.outside_energy_receiver.energy = 0
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
-- For update 8
function update_all_power_settings()
	for _, factory in pairs(global.factories) do
		update_power_settings(factory)
	end
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

	local ier = factory.inside_surface.create_entity{name = "factory-power-input-2-10", position = {factory.inside_x + layout.inside_energy_x, factory.inside_y + layout.inside_energy_y}, force = force}
	ier.destructible = false
	ier.operable = false
	ier.rotatable = false
	factory.inside_energy_receiver = ier
	
	local ies = factory.inside_surface.create_entity{name = "factory-power-output-2-10", position = {factory.inside_x + layout.inside_energy_x, factory.inside_y + layout.inside_energy_y}, force = force}
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
		local name = "factory-fluid-dummy-connector-" .. cpos.direction_in
		local connector = factory.inside_surface.create_entity{name = name, position = {factory.inside_x + cpos.inside_x + cpos.indicator_dx, factory.inside_y + cpos.inside_y + cpos.indicator_dy}, force = force}
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
	
	local oer = factory.outside_surface.create_entity{name = layout.outside_energy_receiver_type .. "-10", position = {factory.outside_x, factory.outside_y}, force = force}
	oer.destructible = false
	oer.operable = false
	oer.rotatable = false
	factory.outside_energy_receiver = oer
	
	local oes = factory.outside_surface.create_entity{name = layout.outside_energy_sender_type .. "-10", position = {factory.outside_x, factory.outside_y}, force = force}
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
	else
		if Connections.is_connectable(entity) then
			recheck_nearby_connections(entity)
		end
		if entity.name == "factory-requester-chest" then
			init_factory_requester_chest(entity)
		end
	end
end)


-- How players pick up factories
-- Working factory buildings don't return items, so we have to manually give the player an item
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
	if event.element.name == "factory_camera_toggle_button" then
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
	if not (from.valid and to.valid) then return end
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
	local power_batch_size = settings.startup["Factorissimo2-power-batching"].value or 1
	local i = event.tick%power_batch_size + 1
	while i <= #factories do
		local factory = factories[i];
		if factory and factory.built then
			if factory.transfers_outside then
				transfer_power(factory.inside_energy_receiver, factory.outside_energy_sender)
			else
				transfer_power(factory.outside_energy_receiver, factory.inside_energy_sender)
			end
		end
		i=i+power_batch_size
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

script.on_event(defines.events.on_force_created, function(event)
	local force = event.force
	if settings.global["Factorissimo2-hide-recursion"] and settings.global["Factorissimo2-hide-recursion"].value then
		force.technologies["factory-recursion-t1"].enabled = false
		force.technologies["factory-recursion-t2"].enabled = false
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