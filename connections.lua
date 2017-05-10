require("connections.lib")
require("connections.belt")
require("connections.chest")
require("connections.fluid")
require("connections.circuit")
Connections = {}

-- Connection types --

local type_map = {}

-- Not using metatables, for..... reasons
local c_unlocked = {}
local c_color = {}
local c_connect = {}
local c_recheck = {}
local c_direction = {}
local c_rotate = {}
local c_adjust = {}
local c_tick = {}
local c_destroy = {}
local indicator_names = {}
Connections.indicator_names = indicator_names

local function register_connection_type(ctype, class)
	for _, etype in pairs(class.entity_types) do
		type_map[etype] = ctype
	end
	c_unlocked[ctype] = class.unlocked
	c_color[ctype] = class.color
	c_connect[ctype] = class.connect
	c_recheck[ctype] = class.recheck
	c_direction[ctype] = class.direction
	c_rotate[ctype] = class.rotate
	c_adjust[ctype] = class.adjust
	c_tick[ctype] = class.tick
	c_destroy[ctype] = class.destroy
	for _, name in pairs(class.indicator_settings) do
		table.insert(indicator_names, ctype .. "-" .. name)
	end
end

register_connection_type("belt", Belt)
register_connection_type("chest", Chest)
register_connection_type("fluid", Fluid)
register_connection_type("circuit", Circuit)

local function is_connectable(entity)
	return type_map[entity.type]
end
Connections.is_connectable = is_connectable

-- Connection data structure --

local CYCLIC_BUFFER_SIZE = 600
local function init_data_structure()
	global.connections = global.connections or {}
	global.delayed_connection_checks = global.delayed_connection_checks or {}
	for i = 1, CYCLIC_BUFFER_SIZE do
		global.connections[i] = global.connections[i] or {}
	end
end
Connections.init_data_structure = init_data_structure

local function add_connection_to_queue(conn)
	local current_pos = (game.tick+1)%CYCLIC_BUFFER_SIZE + 1
	table.insert(global.connections[current_pos], conn)
end

-- Connection settings --

local function get_connection_settings(factory, cid, ctype)
	factory.connection_settings[cid] = factory.connection_settings[cid] or {}
	factory.connection_settings[cid][ctype] = factory.connection_settings[cid][ctype] or {}
	return factory.connection_settings[cid][ctype]
end

-- Connection indicators --

local function set_connection_indicator(factory, cid, ctype, setting, dir)
	local old_indicator = factory.connection_indicators[cid]
	if old_indicator and old_indicator.valid then old_indicator.destroy() end
	local cpos = factory.layout.connections[cid]
	local new_indicator = factory.inside_surface.create_entity{
		name = "factory-connection-indicator-" .. ctype .. "-" .. setting,
		direction = dir, force = factory.force,
		position = {x = factory.inside_x + cpos.inside_x + cpos.indicator_dx, y = factory.inside_y + cpos.inside_y + cpos.indicator_dy}
	}
	new_indicator.destructible = false
	factory.connection_indicators[cid] = new_indicator
end

local function delete_connection_indicator(factory, cid, ctype)
	local old_indicator = factory.connection_indicators[cid]
	if old_indicator and old_indicator.valid then old_indicator.destroy() end
end

local function refresh_connection_indicator(conn) -- Used in update 5
	if conn and conn._valid then
		local setting, dir = c_direction[conn._type](conn)
		set_connection_indicator(conn._factory, conn._id, conn._type, setting, dir)
	end
end

Connections.refresh_connection_indicator = refresh_connection_indicator
-- Connection changes --

local function register_connection(factory, cid, ctype, conn)
	conn._id = cid
	conn._type = ctype
	conn._factory = factory
	conn._settings = get_connection_settings(factory, cid, ctype)
	conn._valid = true
	factory.connections[cid] = conn
	add_connection_to_queue(conn)
	local setting, dir = c_direction[ctype](conn)
	set_connection_indicator(factory, cid, ctype, setting, dir)
end

local function init_connection(factory, cid, cpos) -- Only call this when factory.connections[cid] == nil!
	local outside_entities = factory.outside_surface.find_entities_filtered{
		position = {cpos.outside_x + factory.outside_x, cpos.outside_y + factory.outside_y},
		force = factory.force
	}
	if (outside_entities == nil or next(outside_entities) == nil) then return end
	local inside_entities = factory.inside_surface.find_entities_filtered{
		position = {cpos.inside_x + factory.inside_x, cpos.inside_y + factory.inside_y},
		force = factory.force
	}
	if (inside_entities == nil or next(inside_entities) == nil) then return end
	for _, outside_entity in pairs(outside_entities) do
		local oet = outside_entity.type
		local oct = type_map[oet]
		if oct ~= nil then
			for _, inside_entity in pairs(inside_entities) do
				local iet = inside_entity.type
				local ict = type_map[iet]
				if (oct == ict and c_unlocked[oct](factory.force)) then
					local conn = c_connect[oct](factory, cid, cpos, outside_entity, inside_entity)
					if conn then
						register_connection(factory, cid, oct, conn)
						return
					end
				end
			end
		end
	end
end

local function destroy_connection(conn)
	if conn._valid then
		c_destroy[conn._type](conn)
		conn._valid = false -- _valid should be true iff conn._factory.connections[conn._id] == conn
		conn._factory.connections[conn._id] = nil -- Lua can handle this
		delete_connection_indicator(conn._factory, conn._id, conn._type)
	end
end

local function in_area(x, y, area)
	return (x >= area.left_top.x and x <= area.right_bottom.x and y >= area.left_top.y and y <= area.right_bottom.y)
end

local function recheck_factory(factory, outside_area, inside_area) -- Areas are optional
	if (not factory.built) then return end
	for cid, cpos in pairs(factory.layout.connections) do 
		if (outside_area == nil or in_area(cpos.outside_x+factory.outside_x, cpos.outside_y+factory.outside_y, outside_area))
		and (inside_area == nil or in_area(cpos.inside_x+factory.inside_x, cpos.inside_y+factory.inside_y, inside_area)) then
			local conn = factory.connections[cid]
			if conn then
				if c_recheck[conn._type](conn) then
					-- Everything is fine
				else
					destroy_connection(conn)
					init_connection(factory, cid, cpos)
				end
			else
				init_connection(factory, cid, cpos)			
			end
		end
	end
end
Connections.recheck_factory = recheck_factory

-- During deconstruction events of an entity that is part of a connection, the entity is still valid and built, so recheck_factory would not destroy the connection involved.
-- Delaying the recheck causes these connections to be properly deconstructed immediately, instead of having to wait until the connection ticks again.
local function recheck_factory_delayed(factory, outside_area, inside_area)
	-- Note that connections should still be designed such that absolutely nothing would break even if this function was empty!
	global.delayed_connection_checks[1+#(global.delayed_connection_checks)] = {
		factory = factory,
		outside_area = outside_area, 
		inside_area = inside_area
	}
end
Connections.recheck_factory_delayed = recheck_factory_delayed

local function disconnect_factory(factory)
	for cid, conn in pairs(factory.connections) do
		destroy_connection(conn)
	end
end
Connections.disconnect_factory = disconnect_factory

-- Connection effects --

local function update()
	-- First let's run all them delayed connection checks
	for _, check in ipairs(global.delayed_connection_checks) do
		recheck_factory(check.factory, check.outside_area, check.inside_area)
	end
	global.delayed_connection_checks = {}
	
	local current_pos = game.tick % CYCLIC_BUFFER_SIZE + 1
	local connections = global.connections
	local current_slot = connections[current_pos] or {}
	connections[current_pos] = {}
	for _, conn in pairs(current_slot) do
		local delay = (conn._valid and c_tick[conn._type](conn))
		if delay then
			-- Reinsert connection after delay
			-- Not checking for inappropriate delays, so keep your delays civil
			local queue_pos = (current_pos + delay - 1) % CYCLIC_BUFFER_SIZE + 1
			local new_slot = connections[queue_pos]
			new_slot[1+#new_slot] = conn
		elseif conn._valid then
			destroy_connection(conn)
			init_connection(conn._factory, conn._id, conn._factory.layout.connections[conn._id])
		end
	end
end
Connections.update = update

local function rotate(factory, indicator)
	for cid, ind2 in pairs(factory.connection_indicators) do
		if ind2 and ind2.valid then
			if (ind2.unit_number == indicator.unit_number) then
				local conn = factory.connections[cid]
				local text = c_rotate[conn._type](conn)
				factory.inside_surface.create_entity{name="flying-text", position=indicator.position, color=c_color[conn._type], text=text}
				local setting, dir = c_direction[conn._type](conn)
				set_connection_indicator(factory, cid, conn._type, setting, dir)
				return
			end
		end
	end
end
Connections.rotate = rotate

local function adjust(factory, indicator, positive)
	for cid, ind2 in pairs(factory.connection_indicators) do
		if ind2 and ind2.valid then
			if (ind2.unit_number == indicator.unit_number) then
				local conn = factory.connections[cid]
				local text = c_adjust[conn._type](conn, positive)
				factory.inside_surface.create_entity{name="flying-text", position=indicator.position, color=c_color[conn._type], text=text}
				local setting, dir = c_direction[conn._type](conn)
				set_connection_indicator(factory, cid, conn._type, setting, dir)
				return
			end
		end
	end
end
Connections.adjust = adjust