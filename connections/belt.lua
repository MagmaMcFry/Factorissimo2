Belt = {}

Belt.color = {r = 0, g = 183/255, b = 0}
Belt.entity_types = {"transport-belt", "underground-belt"}
Belt.unlocked = function(force) return true end

Belt.indicator_settings = {"d0"}

local function calc_delays(speed1, speed2)
	-- Belt connections will transfer a maximum of 1 item per tick per lane
	local speed = math.min(8, math.min(speed1, speed2))
	local arraysize = math.ceil(32*speed)
	local delays = {}
	for i=1,arraysize do
		delays[i] = math.ceil(i*0.25/speed) - math.ceil((i-1)*0.25/speed)
	end
	return delays
end

local INSERT_POS = {
	["transport-belt"] = 0.75, -- 1 - 8/32
	["underground-belt"] = 0.25, -- 0.5 - 8/32
}


local opposite = {
	[defines.direction.north] = defines.direction.south, [defines.direction.south] = defines.direction.north,
	[defines.direction.east] = defines.direction.west, [defines.direction.west] = defines.direction.east,
}

local function get_conn_facing(outside_entity, inside_entity, direction_out, direction_in)
	local outside_dir, inside_dir, ot, it = 0, 0, outside_entity.type, inside_entity.type
	if ot == "transport-belt" then
		outside_dir = outside_entity.direction
	elseif ot == "underground-belt" then
		outside_dir = outside_entity.direction
		if outside_entity.belt_to_ground_type == "input" then
			if direction_out ~= outside_dir then return nil end
		else
			if direction_in ~= outside_dir then return nil end
		end
	end
	if it == "transport-belt" then
		inside_dir = inside_entity.direction
	elseif it == "underground-belt" then
		inside_dir = inside_entity.direction
		if inside_entity.belt_to_ground_type == "input" then
			if direction_in ~= inside_dir then return nil end
		else
			if direction_out ~= inside_dir then return nil end
		end
	end
	if outside_dir ~= inside_dir then return nil end
	--game.print("Direction: " .. outside_dir)
	return outside_dir
end

Belt.connect = function (factory, cid, cpos, outside_entity, inside_entity)
	local conn_facing = get_conn_facing(outside_entity, inside_entity, cpos.direction_out, cpos.direction_in)
	if conn_facing == cpos.direction_in then
		local connection = {
			from = outside_entity,
			from_line_1 = outside_entity.get_transport_line(1),
			from_line_2 = outside_entity.get_transport_line(2),
			to = inside_entity,
			to_line_1 = inside_entity.get_transport_line(1),
			to_line_2 = inside_entity.get_transport_line(2),
			facing = cpos.direction_in,
			delays = calc_delays(outside_entity.prototype.belt_speed, inside_entity.prototype.belt_speed),
			offset = 0,
			insert_pos = INSERT_POS[inside_entity.type]}
		--game.print("Connection created at " .. cid .. ", to the inside!")
		return connection
	elseif conn_facing == cpos.direction_out then
		local connection = {
			from = inside_entity,
			from_line_1 = inside_entity.get_transport_line(1),
			from_line_2 = inside_entity.get_transport_line(2),
			to = outside_entity,
			to_line_1 = outside_entity.get_transport_line(1),
			to_line_2 = outside_entity.get_transport_line(2),
			facing = cpos.direction_out,
			delays = calc_delays(outside_entity.prototype.belt_speed, inside_entity.prototype.belt_speed),
			offset = 0,
			insert_pos = INSERT_POS[outside_entity.type]}
		--game.print("Connection created at " .. cid .. ", to the outside!")
		return connection
	end
	return nil
end

Belt.recheck = function (conn)
	return (conn.from.valid and conn.to.valid and conn.facing == get_conn_facing(conn.from, conn.to, opposite[conn.facing], conn.facing))
end

Belt.direction = function (conn)
	return "d0", conn.facing
end

Belt.rotate = ConnectionLib.beep

Belt.adjust = ConnectionLib.beep


Belt.tick = function (conn)
	local from = conn.from
	local to = conn.to
	if from.valid and to.valid then
		--game.print("Belt ticking! Tick: " .. game.tick)
		local f1 = conn.from_line_1
		local t1 = conn.to_line_1
		local contents = f1.get_contents()
		local t = next(contents)
		if t ~= nil then
			local c = contents[t]
			if t1.insert_at(conn.insert_pos, {name = t, count = 1}) then
				f1.remove_item{name = t, count = 1}
			end
		end
		local f2 = conn.from_line_2
		local t2 = conn.to_line_2
		contents = f2.get_contents()
		t = next(contents)
		if t ~= nil then
			local c = contents[t]
			if t2.insert_at(conn.insert_pos, {name = t, count = 1}) then
				f2.remove_item{name = t, count = 1}
			end
		end
		conn.offset = (conn.offset % #(conn.delays)) + 1
		return conn.delays[conn.offset]
	else
		return false
	end
end

Belt.destroy = function (conn)
end