Updates = {}

Updates.init = function()
	global.update_version = 11
end

Updates.run = function()
	if global.update_version < 11 then
		error("This save is too old to be reloaded in this version of Factorissimo2. "
			.. "To run this save, you will need to load and resave this map with Factorissimo2 version 2.4.5 or 2.4.6.")
	end
	if global.update_version < 12 then
		-- Begin overlay display rework
		for _, surface in pairs(game.surfaces) do
			for _, e in pairs(surface.find_entities_filtered{name = "factory-overlay-controller"}) do
				e.destroy()
			end
		end
		for _, factory in pairs(global.factories)  do
			for _, entity in pairs(factory.outside_overlay_displays) do
				if entity.valid then entity.destroy() end
			end
			factory.outside_overlay_displays = {}

			for _, entity in pairs(factory.inside_overlay_controllers) do
				if entity.valid then entity.destroy() end
			end
			factory.inside_overlay_controllers = nil

			factory.upgrades.display = nil
			factory.layout.overlays = {
				inside_x = factory.layout.overlays.nw.inside_x,
				inside_y = factory.layout.overlays.nw.inside_y,
				outside_x = 0,
				outside_y = -1,
				outside_w = factory.layout.outside_size,
				outside_h = factory.layout.outside_size - 2,
			}
			build_display_upgrade(factory)
			update_overlay(factory)
		end
		-- End overlay display rework
	end
	global.update_version = 12
end
