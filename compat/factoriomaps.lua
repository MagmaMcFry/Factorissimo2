Compat = Compat or {}

local function cleanup_entities_for_factoriomaps()
	print("Starting factoriomaps-factorissimo integration script")

	for surface, factoryList in pairs(global.surface_factories) do

		remote.call("factoriomaps", "surface_set_hidden", surface, true)

		for _, factory in pairs(factoryList) do
			for _, entity in pairs(factory.inside_other_entities) do
				if entity.valid and entity.name == "factory-power-pole" then
					-- Move power pole to bottom left corner to hide it
					entity.teleport({x = factory.inside_x - 32, y = factory.inside_y + 32})
				end
			end
			for _, entity in pairs(factory.inside_overlay_controllers) do
				entity.destroy()
			end

			if factory.built then
				for _, entity in pairs(factory.outside_port_markers) do
					entity.destroy()
				end
				for _, entity in pairs(factory.outside_overlay_displays) do
					entity.destroy()
				end

				remote.call("factoriomaps", "link_renderbox_area", {
					from = {
						{ factory.outside_x - factory.layout.outside_size / 2, factory.outside_y - factory.layout.outside_size / 2 },
						{ factory.outside_x + factory.layout.outside_size / 2, factory.outside_y + factory.layout.outside_size / 2 },
						surface = factory.outside_surface.name
					},
					to = {
						{ factory.inside_x - factory.layout.inside_size / 2 - 1, factory.inside_y - factory.layout.inside_size / 2 - 1 },
						{ factory.inside_x + factory.layout.inside_size / 2 + 1, factory.inside_y + factory.layout.inside_size / 2 + 1 },
						surface = factory.inside_surface.name
					}
				})

			end
		end
	end
end

function Compat.handle_factoriomaps()
	if remote.interfaces.factoriomaps then
		script.on_event(remote.call("factoriomaps", "get_start_capture_event_id"), cleanup_entities_for_factoriomaps)
	end
end
