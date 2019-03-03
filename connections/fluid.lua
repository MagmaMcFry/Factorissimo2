Fluid = {}

Fluid.color = {r = 167/255, g = 229/255, b = 255/255}
Fluid.entity_types = {"pipe", "pipe-to-ground", "storage-tank"}
Fluid.unlocked = function(force) return force.technologies["factory-connection-type-fluid"].researched end

local DX = {
	[defines.direction.north] = 0,
	[defines.direction.east] = 1,
	[defines.direction.south] = 0,
	[defines.direction.west] = -1,
}
local DY = {
	[defines.direction.north] = -1,
	[defines.direction.east] = 0,
	[defines.direction.south] = 1,
	[defines.direction.west] = 0,
}

local blacklist = {
	"factory-fluid-dummy-connector-" .. defines.direction.north,	"factory-fluid-dummy-connector-" .. defines.direction.east,	"factory-fluid-dummy-connector-" .. defines.direction.south,	"factory-fluid-dummy-connector-" .. defines.direction.west,
}
local blacklisted = {}
for _,name in pairs(blacklist) do blacklisted[name] = true end

local function is_inside_connected(factory, cid, entity)
	if blacklisted[entity.name] then return false end
	for _, e2 in pairs(factory.inside_fluid_dummy_connectors[cid].neighbours[1]) do
		if e2.unit_number == entity.unit_number then return true end
	end
end

local function is_outside_connected(factory, cid, entity)
	if blacklisted[entity.name] then return false end
	for _, e2 in pairs(factory.outside_fluid_dummy_connectors[cid].neighbours[1]) do
		if e2.unit_number == entity.unit_number then return true end
	end
end

Fluid.connect = function(factory, cid, cpos, outside_entity, inside_entity)	
	if is_inside_connected(factory, cid, inside_entity) and is_outside_connected(factory, cid, outside_entity) and outside_entity.fluidbox.get_capacity(1) > 0 and inside_entity.fluidbox.get_capacity(1) > 0 then
		return {
			outside = outside_entity, inside = inside_entity,
			outside_capacity = outside_entity.fluidbox.get_capacity(1),
			inside_capacity = inside_entity.fluidbox.get_capacity(1),
		}
	end
	return nil
end

Fluid.recheck = function (conn)
	local cpos = conn._factory.layout.connections[conn._id]
	return conn.outside.valid and conn.inside.valid
	and is_outside_connected(conn._factory, conn._id, conn.outside) and is_inside_connected(conn._factory, conn._id, conn.inside)
end

local DELAYS = {1, 4, 10, 30, 120}
local DEFAULT_DELAY = 10

Fluid.indicator_settings = {"d0", "b0"}

for _,v in pairs(DELAYS) do
	table.insert(Fluid.indicator_settings, "d" .. v)
	table.insert(Fluid.indicator_settings, "b" .. v)
end

local function make_valid_delay(delay)
	for _,v in pairs(DELAYS) do
		if v == delay then return v end
	end
	return 0 -- Catchall
end

Fluid.direction = function (conn)
	local mode = (conn._settings.mode or 0)
	if mode == 0 then
		return "b" .. make_valid_delay(conn._settings.delay or DEFAULT_DELAY), defines.direction.north
	elseif mode == 1 then
		return "d" .. make_valid_delay(conn._settings.delay or DEFAULT_DELAY), conn._factory.layout.connections[conn._id].direction_in
	else
		return "d" .. make_valid_delay(conn._settings.delay or DEFAULT_DELAY), conn._factory.layout.connections[conn._id].direction_out
	end
	
end

Fluid.rotate = function (conn)
	conn._settings.mode = ((conn._settings.mode or 0)+1)%3
	local mode = conn._settings.mode
	if mode == 0 then
		return {"factory-connection-text.balance-mode"}
	elseif mode == 1 then
		return {"factory-connection-text.input-mode"}
	else
		return {"factory-connection-text.output-mode"}
	end
end

Fluid.adjust = function (conn, positive)
	local delay = conn._settings.delay or DEFAULT_DELAY
	if positive then
		for i = #DELAYS,1,-1 do
			if DELAYS[i] < delay then
				delay = DELAYS[i]
				break
			end
		end
		conn._settings.delay = delay
		return {"factory-connection-text.update-faster", delay}
	else
		for i = 1,#DELAYS do
			if DELAYS[i] > delay then
				delay = DELAYS[i]
				break
			end
		end
		conn._settings.delay = delay
		return {"factory-connection-text.update-slower", delay}
	end
end

local function transfer(from, to, from_cap, to_cap)
	local from_boxes = from.fluidbox
	local from_box = from_boxes[1]
	local to_boxes = to.fluidbox
	local to_box = to_boxes[1]
	if from_box ~= nil then
		if to_box == nil then 
			if from_box.amount <= to_cap then
				from_boxes[1] = nil
				to_boxes[1] = from_box
			else
				from_box.amount = from_box.amount - to_cap
				from_boxes[1] = from_box
				from_box.amount = to_cap
				to_boxes[1] = from_box
			end
		elseif to_box.name == from_box.name then
			local total = from_box.amount + to_box.amount
			if total <= to_cap then
				from_boxes[1] = nil
				to_box.temperature = (from_box.amount*from_box.temperature + to_box.amount*to_box.temperature)/total
				to_box.amount = total
				to_boxes[1] = to_box
			else
				to_box.temperature = (to_box.amount*to_box.temperature + (to_cap-to_box.amount)*from_box.temperature)/to_cap
				to_box.amount = to_cap
				to_boxes[1] = to_box
				from_box.amount = total - to_cap
				from_boxes[1] = from_box
			end
		end
	end
end

local function balance(from, to, from_cap, to_cap)
	local from_boxes = from.fluidbox
	local from_box = from_boxes[1]
	local to_boxes = to.fluidbox
	local to_box = to_boxes[1]
	if from_box ~= nil and to_box ~= nil then
		if from_box.name == to_box.name then
			local from_amount = from_box.amount
			local to_amount = to_box.amount
			local both_fill = (from_amount+to_amount)/(from_cap+to_cap)
			local transfer_amount = (from_amount+to_amount)*to_cap/(from_cap+to_cap)-to_amount
			if transfer_amount > 0 then
				to_box.temperature = (to_amount*to_box.temperature + transfer_amount*from_box.temperature)/(to_amount+transfer_amount)
			else
				from_box.temperature = (from_amount*from_box.temperature - transfer_amount*to_box.temperature)/(from_amount-transfer_amount)
			end
			from_box.amount = from_amount-transfer_amount
			to_box.amount = to_amount+transfer_amount
			from_boxes[1] = from_box
			to_boxes[1] = to_box
		end
	elseif from_box ~= nil then
		local from_amount = from_box.amount
		local transfer_amount = from_amount * to_cap / (from_cap + to_cap)
		from_box.amount = from_amount - transfer_amount
		from_boxes[1] = from_box
		from_box.amount = transfer_amount
		to_boxes[1] = from_box
	elseif to_box ~= nil then
		local to_amount = to_box.amount
		local transfer_amount = to_amount * from_cap / (from_cap + to_cap)
		to_box.amount = to_amount - transfer_amount
		to_boxes[1] = to_box
		to_box.amount = transfer_amount
		from_boxes[1] = to_box
	end
end

Fluid.tick = function(conn)
	local outside = conn.outside
	local inside = conn.inside
	local outside_cap = conn.outside_capacity
	local inside_cap = conn.inside_capacity
	if outside.valid and inside.valid then
		local mode = conn._settings.mode or 0
		if mode == 0 then
			-- Balance
			balance(outside, inside, outside_cap, inside_cap)
		elseif mode == 1 then
			-- Input
			transfer(outside, inside, outside_cap, inside_cap)
		else
			-- Output
			transfer(inside, outside, inside_cap, outside_cap)
		end
		return conn._settings.delay or DEFAULT_DELAY
	else
		return false
	end
end

Fluid.destroy = function(conn)
end