Updates = {}

Updates.init = function()
	global.update_version = 13
end

local function fix_common_issues()
	for _, factory in pairs(global.factories) do
		-- Fix issues when forces are deleted
		if not factory.force.valid then
			factory.force = game.forces["player"]
		end
	end
end

Updates.run = function()
	fix_common_issues()
	if global.update_version < 12 then
		error("This save is too old to be reloaded in this version of Factorissimo2. "
			.. "To run this save, you will need to load and resave this map with Factorissimo2 version 2.5.3")
	end
	if global.update_version < 13 then
		for _, factory in pairs(global.factories) do
			if factory.built then
				local oer = factory.outside_surface.create_entity{name = factory.layout.outside_energy_receiver_type, position = {factory.outside_x, factory.outside_y}, force = factory.force}
				oer.destructible = false
				oer.operable = false
				oer.rotatable = false
				factory.outside_energy_receiver = oer
			end
			factory.inside_power_poles = {factory.inside_other_entities[1]}
			if factory.upgrades.lights then factory.inside_surface.daytime = 1 end
		end
		for _, factory in pairs(global.factories) do
			if factory.built then update_power_connection(factory) end
		end
	end
	global.update_version = 13
end
