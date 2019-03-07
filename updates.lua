Updates = {}

Updates.init = function()
	global.update_version = 10
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
		-- We have new dummy connectors, so we should rebuild them in each factory building
		for _, factory in pairs(global.factories) do
			for id, cpos in pairs(factory.layout.connections) do
				local name = "factory-fluid-dummy-connector-" .. cpos.direction_in
				local connector = factory.inside_surface.create_entity{name = name, position = {factory.inside_x + cpos.inside_x + cpos.indicator_dx, factory.inside_y + cpos.inside_y + cpos.indicator_dy}, force = force}
				connector.destructible = false
				connector.operable = false
				connector.rotatable = false
				factory.inside_fluid_dummy_connectors[id] = connector
			end
			if factory.built then
				for id, cpos in pairs(factory.layout.connections) do
					local name = "factory-fluid-dummy-connector-" .. cpos.direction_out
					local connector = factory.outside_surface.create_entity{name = name, position = {factory.outside_x + cpos.outside_x - cpos.indicator_dx, factory.outside_y + cpos.outside_y - cpos.indicator_dy}, force = force}
					connector.destructible = false
					connector.operable = false
					connector.rotatable = false
					factory.outside_fluid_dummy_connectors[id] = connector
				end
			end
		end
	end
	if global.update_version <= 9 then
		for _, factory in pairs(global.factories) do
			factory.inside_surface.destroy_decoratives{
				area = {
					{factory.inside_x - 64, factory.inside_y - 64},
					{factory.inside_x + 64, factory.inside_y + 64}
				},
				force = "neutral"
			}
		end
	end
	global.update_version = 10
end