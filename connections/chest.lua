Chest = {}

Chest.color = {r = 200/255, g = 110/255, b = 38/255}
Chest.entity_types = {"container", "logistic-container"}
Chest.unlocked = function(force) return force.technologies["factory-connection-type-chest"].researched end

local blacklist = {"factory-1", "factory-overlay-controller", "factory-overlay-display"}
local blacklisted = {}
for _, name in pairs(blacklist) do blacklisted[name] = true end

Chest.connect = function(factory, cid, cpos, outside_entity, inside_entity)
	if blacklisted[outside_entity.name] or blacklisted[inside_entity.name] then return nil end
	-- Connection mode: 0 for balance, 1 for inwards, 2 for outwards 
	return {outside = outside_entity, inside = inside_entity}
end

Chest.recheck = function(conn)
	return conn.outside.valid and conn.inside.valid
end

local DELAYS = {10, 20, 60, 180, 600}
local DEFAULT_DELAY = 60
Chest.indicator_settings = {"d0", "b0"}

for _,v in pairs(DELAYS) do
	table.insert(Chest.indicator_settings, "d" .. v)
	table.insert(Chest.indicator_settings, "b" .. v)
end

local function make_valid_delay(delay)
	for _,v in pairs(DELAYS) do
		if v == delay then return v end
	end
	return 0 -- Catchall
end

Chest.direction = function(conn)
	local mode = (conn._settings.mode or 0)
	if mode == 0 then
		return "b" .. make_valid_delay(conn._settings.delay or DEFAULT_DELAY), defines.direction.north
	elseif mode == 1 then
		return "d" .. make_valid_delay(conn._settings.delay or DEFAULT_DELAY), conn._factory.layout.connections[conn._id].direction_in
	else
		return "d" .. make_valid_delay(conn._settings.delay or DEFAULT_DELAY), conn._factory.layout.connections[conn._id].direction_out
	end
end

Chest.rotate = function(conn)
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

Chest.adjust = function(conn, positive)
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

Chest.tick = function(conn)
	local outside = conn.outside
	local inside = conn.inside
	if outside.valid and inside.valid then
		local outside_inv = outside.get_inventory(defines.inventory.chest)
		local inside_inv = inside.get_inventory(defines.inventory.chest)
		local mode = conn._settings.mode or 0
		if mode == 0 then
			-- Balance
			local outside_contents = outside_inv.get_contents()
			local inside_contents = inside_inv.get_contents()
			for item, count in pairs(outside_contents) do
				local count2 = inside_contents[item] or 0
				local diff = count-count2
				if diff > 1 then
					local count2 = inside_inv.insert{name = item, count = math.floor(diff/2)}
					if count2 > 0 then
						outside_inv.remove{name = item, count = count2}
					end
				elseif diff < -1 then
					local count2 = outside_inv.insert{name = item, count = math.floor(-diff/2)}
					if count2 > 0 then
						inside_inv.remove{name = item, count = count2}
					end
				end
			end
			for item, count in pairs(inside_contents) do
				if count > 1 and not outside_contents[item] then
					local count2 = outside_inv.insert{name = item, count = math.floor(count/2)}
					if count2 > 0 then
						inside_inv.remove{name = item, count = count2}
					end
				end
			end
		elseif mode == 1 then
			-- Inwards
			local outside_contents = outside_inv.get_contents()
			for item, count in pairs(outside_contents) do
				local count2 = inside_inv.insert{name = item, count = count}
				if count2 > 0 then
					outside_inv.remove{name = item, count = count2}
				end
			end
		else
			-- Outwards
			local inside_contents = inside_inv.get_contents()
			for item, count in pairs(inside_contents) do
				local count2 = outside_inv.insert{name = item, count = count}
				if count2 > 0 then
					inside_inv.remove{name = item, count = count2}
				end
			end
		end
		return conn._settings.delay or DEFAULT_DELAY
	else
		return false
	end
end

Chest.destroy = function(conn)
end