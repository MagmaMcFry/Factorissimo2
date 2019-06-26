


local function handle_factoriomaps()
	if remote.interfaces.factoriomaps then
		script.on_event(remote.call("factoriomaps", "get_start_capture_event_id"), function() 

			print("Starting factoriomaps-factorissimo integration script")
			
			for surface, factoryList in pairs(global.surface_factories) do
			
				remote.call("factoriomaps", "surface_set_hidden", surface, true)
				
				for _, factory in pairs(factoryList) do
					if factory.built then

						for _, marker in pairs(factory.outside_port_markers) do
							marker.destroy()
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



		end)
	end
end
script.on_init(handle_factoriomaps)
script.on_load(handle_factoriomaps)
