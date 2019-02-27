Updates = {}

Updates.init = function()
	global.update_version = 9
end

Updates.run = function()
	if global.update_version <= 7 then
		error("This save is too old to be reloaded in Factorissimo2 version 2.3.0+. To run this save in 0.17, you need to load and save this map once, using Factorissimo2 version 2.2.3 in Factorio 0.16")
	end
	if global.update_version <= 8 then
		-- Since belt item distance has changed in 0.17, we need to reset belt update rates
		local recalc_delays = function(speed1, speed2)
			local speed = math.min(speed1, speed2)
			local arraysize = math.ceil(32*speed)
			local delays = {}
			for i=1,arraysize do
				delays[i] = math.ceil(i*0.25/speed) - math.ceil((i-1)*0.25/speed)
			end
			return delays
		end
		for _, connection_list in pairs(global.connections) do
			for _, conn in pairs(connection_list) do
				if conn._type == "belt" then
					if conn.from.valid and conn.to.valid then
						conn.delays = recalc_delays(conn.from.prototype.belt_speed, conn.to.prototype.belt_speed)
						conn.offset = 0
					end
				end
			end
		end
	end
	global.update_version = 9
end