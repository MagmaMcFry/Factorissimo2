Compat = Compat or {}

local function cleanup_entities_for_factoriomaps()
	print("Starting factoriomaps-factorissimo integration script")

	for surface, factoryList in pairs(global.surface_factories) do

		remote.call("factoriomaps", "surface_set_hidden", surface, true)

		for _, pole in pairs(game.surfaces[surface].find_entities_filtered{name = "factory-power-pole"}) do
			-- Move power pole two spaces down to hide it
			local new_position = {x = pole.position.x, y = pole.position.y + 2}
			pole.teleport(new_position)
		end
		for _, factory in pairs(factoryList) do
			if factory.built then

				for _, entity in pairs(factory.inside_overlay_controllers) do
					entity.destroy()
				end
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
