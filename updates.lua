Updates = {}

Updates.init = function()
	global.update_version = 3
end

Updates.run = function()
	if global.update_version <= 1 then
		-- Remove all factory port markers because they're placed wrong
		for _, factory in pairs(global.factories) do
			for _, entity in pairs(factory.outside_port_markers) do entity.destroy() end
			factory.outside_port_markers = {}
		end
		-- Issue where deconstructing factory building Mk3s would return a factory building Mk1
		-- Is fixed, but we gotta give players back their lost factories
		local player = game.players[1]
		if player and player.valid then
			for i=10,99 do
				local savename = "factory-3-s" .. i
				if global.saved_factories[savename] then
					player.insert{name=savename, count=1} -- Insert to player 1's inventory
				end
			end
		end
	end
	if global.update_version <= 2 then
		-- Change fluid connection base_area to capacity
		for _, tick_conns in pairs(global.connections) do
			for _, conn in pairs(tick_conns) do
			if conn and conn._type == "fluid" then
					if conn.outside.valid then conn.outside_capacity = conn.outside.fluidbox.get_capacity(1) end
					if conn.inside.valid then conn.inside_capacity = conn.inside.fluidbox.get_capacity(1) end
				end
			end
		end
		for _, factory in pairs(global.factories) do
			for _, conn in pairs(factory.connections) do
				if conn and conn._type == "fluid" then
					if conn.outside.valid then conn.outside_capacity = conn.outside.fluidbox.get_capacity(1) end
					if conn.inside.valid then conn.inside_capacity = conn.inside.fluidbox.get_capacity(1) end
				end
			end
		end
	end
	global.update_version = 3
end