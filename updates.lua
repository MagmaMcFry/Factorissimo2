Updates = {}

Updates.init = function()
	global.update_version = 5
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
	if global.update_version <= 3 then
		for _, factory in pairs(global.factories) do
			local layout = factory.layout
			if layout.name == "factory-1" then
				layout.inside_size = 30
				layout.outside_size = 8
			elseif layout.name == "factory-2" then
				layout.inside_size = 46
				layout.outside_size = 12
			elseif layout.name == "factory-3" then
				layout.inside_size = 60
				layout.outside_size = 16
			else -- Some other factory, maybe someone fiddled with the mod
				layout.inside_size = 30
				layout.outside_size = 8
			end
		end
	end
	if global.update_version <= 4 then
		for _,player in pairs(game.players) do
			local gui = player.gui.top.factory_camera_placeholder
			if gui then
				local camera_frame = gui.factory_camera_frame
				if camera_frame then
					camera_frame.destroy()
					gui.style.visible = false
				end
			end
		end
	end
	global.update_version = 5
end