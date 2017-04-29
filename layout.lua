local north = defines.direction.north
local east = defines.direction.east
local south = defines.direction.south
local west = defines.direction.west

local opposite = {[north] = south, [east] = west, [south] = north, [west] = east}
local DX = {[north] = 0, [east] = 1, [south] = 0, [west] = -1}
local DY = {[north] = -1, [east] = 0, [south] = 1, [west] = 0}

local make_connection = function(id, outside_x, outside_y, inside_x, inside_y, direction_out)
	return {
		id = id,
		outside_x = outside_x,
		outside_y = outside_y,
		inside_x = inside_x,
		inside_y = inside_y,
		indicator_dx = DX[direction_out],
		indicator_dy = DY[direction_out],
		direction_in = opposite[direction_out],
		direction_out = direction_out,
	}
end

local layout_generators = {
	["factory-1"] = function() 
		return {
			name = "factory-1",
			tier = 1,
			inside_size = 30,
			outside_size = 8,
			default_power_transfer_rate = 10,
			inside_door_x = 0,
			inside_door_y = 16,
			outside_door_x = 0,
			outside_door_y = 4,
			outside_energy_receiver_type = "factory-power-input-8",
			outside_energy_sender_type = "factory-power-output-8",
			inside_energy_x = -4,
			inside_energy_y = 17,
			energy_indicator_x = -3.5,
			energy_indicator_y = 18.5,
			overlay_name = "factory-1-overlay",
			overlay_x = 0,
			overlay_y = 3,
			rectangles = {
				{
					x1 = -18, x2 = 18, y1 = -18, y2 = 18, tile = "out-of-factory"
				},
				{
					x1 = -16, x2 = 16, y1 = -16, y2 = 16, tile = "factory-wall-1"
				},
				{
					x1 = -15, x2 = 15, y1 = -15, y2 = 15, tile = "factory-floor-1"
				},
				{
					x1 = -3, x2 = 3, y1 = 15, y2 = 18, tile = "factory-wall-1"
				},
				{
					x1 = -2, x2 = 2, y1 = 15, y2 = 18, tile = "factory-entrance-1"
				},
			},
			mosaics = {
				{	x1 = -6, x2 = 6, y1 = -4, y2 = 4, tile = "factory-pattern-1",
					pattern = {
						" ++++    ++ ",
						"++  ++  +++ ",
						"++  ++ + ++ ",
						"++ +++   ++ ",
						"+++ ++   ++ ",
						"++  ++   ++ ",
						"++  ++   ++ ",
						" ++++  +++++",
					}
				},
			},
			lights = {
				{x = -7.5, y = -7.5},
				{x = -7.5, y = 7.5},
				{x = 7.5, y = -7.5},
				{x = 7.5, y = 7.5},
			},
			connection_tile = "factory-floor-1",
			connections = {
				w1 = make_connection("w1", -4.5,-2.5, -15.5,-9.5, west),
				w2 = make_connection("w2", -4.5,-1.5, -15.5,-5.5, west),
				w3 = make_connection("w3", -4.5,1.5, -15.5,5.5, west),
				w4 = make_connection("w4", -4.5,2.5, -15.5,9.5, west),
				
				e1 = make_connection("e1", 4.5,-2.5, 15.5,-9.5, east),
				e2 = make_connection("e2", 4.5,-1.5, 15.5,-5.5, east),
				e3 = make_connection("e3", 4.5,1.5, 15.5,5.5, east),
				e4 = make_connection("e4", 4.5,2.5, 15.5,9.5, east),
				
				n1 = make_connection("n1", -2.5,-4.5, -9.5,-15.5, north),
				n2 = make_connection("n2", -1.5,-4.5, -5.5,-15.5, north),
				n3 = make_connection("n3", 1.5,-4.5, 5.5,-15.5, north),
				n4 = make_connection("n4", 2.5,-4.5, 9.5,-15.5, north),
				
				s1 = make_connection("s1", -2.5,4.5, -9.5,15.5, south),
				s2 = make_connection("s2", -1.5,4.5, -5.5,15.5, south),
				s3 = make_connection("s3", 1.5,4.5, 5.5,15.5, south),
				s4 = make_connection("s4", 2.5,4.5, 9.5,15.5, south),
				
			},
			overlays = {
				nw = {
					outside_x = -2,
					outside_y = -1,
					inside_x = 3.5,
					inside_y = 16.5,
				},
				ne = {
					outside_x = 2,
					outside_y = -1,
					inside_x = 4.5,
					inside_y = 16.5,
				},
			},
		}
	end,
	["factory-2"] = function()
		return {
			name = "factory-2",
			tier = 2,
			inside_size = 46,
			outside_size = 12,
			default_power_transfer_rate = 20,
			inside_door_x = 0,
			inside_door_y = 24,
			outside_door_x = 0,
			outside_door_y = 6,
			outside_energy_receiver_type = "factory-power-input-12",
			outside_energy_sender_type = "factory-power-output-12",
			inside_energy_x = -4,
			inside_energy_y = 25,
			energy_indicator_x = -3.5,
			energy_indicator_y = 26.5,
			overlay_name = "factory-2-overlay",
			overlay_x = 0,
			overlay_y = 5,
			rectangles = {
				{
					x1 = -26, x2 = 26, y1 = -26, y2 = 26, tile = "out-of-factory"
				},
				{
					x1 = -24, x2 = 24, y1 = -24, y2 = 24, tile = "factory-wall-2"
				},
				{
					x1 = -23, x2 = 23, y1 = -23, y2 = 23, tile = "factory-floor-2"
				},
				{
					x1 = -3, x2 = 3, y1 = 23, y2 = 26, tile = "factory-wall-2"
				},
				{
					x1 = -2, x2 = 2, y1 = 23, y2 = 26, tile = "factory-entrance-2"
				},
			},
			mosaics = {
				{	x1 = -6, x2 = 6, y1 = -4, y2 = 4, tile = "factory-pattern-2",
					pattern = {
						" ++++   +++ ",
						"++  ++ ++ ++",
						"++  ++    ++",
						"++ +++   ++ ",
						"+++ ++  ++  ",
						"++  ++ ++   ",
						"++  ++ ++ ++",
						" ++++  +++++",
					}
				},
			},
			lights = {
				{x = -5.5, y = -5.5},
				{x = -5.5, y = 5.5},
				{x = 5.5, y = -5.5},
				{x = 5.5, y = 5.5},
				{x = -17.5, y = -5.5},
				{x = -17.5, y = 5.5},
				{x = 17.5, y = -5.5},
				{x = 17.5, y = 5.5},
				{x = -5.5, y = -17.5},
				{x = -5.5, y = 17.5},
				{x = 5.5, y = -17.5},
				{x = 5.5, y = 17.5},
				{x = -17.5, y = -17.5},
				{x = -17.5, y = 17.5},
				{x = 17.5, y = -17.5},
				{x = 17.5, y = 17.5},
			},
			connection_tile = "factory-floor-2",
			connections = {
				w1 = make_connection("w1", -6.5,-4.5, -23.5,-18.5, west),
				w2 = make_connection("w2", -6.5,-3.5, -23.5,-13.5, west),
				w3 = make_connection("w3", -6.5,-2.5, -23.5,-8.5, west),
				w4 = make_connection("w4", -6.5,2.5, -23.5,8.5, west),
				w5 = make_connection("w5", -6.5,3.5, -23.5,13.5, west),
				w6 = make_connection("w6", -6.5,4.5, -23.5,18.5, west),
				
				e1 = make_connection("e1", 6.5,-4.5, 23.5,-18.5, east),
				e2 = make_connection("e2", 6.5,-3.5, 23.5,-13.5, east),
				e3 = make_connection("e3", 6.5,-2.5, 23.5,-8.5, east),
				e4 = make_connection("e4", 6.5,2.5, 23.5,8.5, east),
				e5 = make_connection("e5", 6.5,3.5, 23.5,13.5, east),
				e6 = make_connection("e6", 6.5,4.5, 23.5,18.5, east),
				
				n1 = make_connection("n1", -4.5,-6.5, -18.5,-23.5, north),
				n2 = make_connection("n2", -3.5,-6.5, -13.5,-23.5, north),
				n3 = make_connection("n3", -2.5,-6.5, -8.5,-23.5, north),
				n4 = make_connection("n4", 2.5,-6.5, 8.5,-23.5, north),
				n5 = make_connection("n5", 3.5,-6.5, 13.5,-23.5, north),
				n6 = make_connection("n6", 4.5,-6.5, 18.5,-23.5, north),
				
				s1 = make_connection("s1", -4.5,6.5, -18.5,23.5, south),
				s2 = make_connection("s2", -3.5,6.5, -13.5,23.5, south),
				s3 = make_connection("s3", -2.5,6.5, -8.5,23.5, south),
				s4 = make_connection("s4", 2.5,6.5, 8.5,23.5, south),
				s5 = make_connection("s5", 3.5,6.5, 13.5,23.5, south),
				s6 = make_connection("s6", 4.5,6.5, 18.5,23.5, south),
			},
			overlays = {
				nw = {
					outside_x = -3,
					outside_y = -3,
					inside_x = 3.5,
					inside_y = 24.5,
				},
				ne = {
					outside_x = 3,
					outside_y = -3,
					inside_x = 4.5,
					inside_y = 24.5,
				},
				
				sw = {
					outside_x = -3,
					outside_y = 1,
					inside_x = 3.5,
					inside_y = 25.5,
				},
				se = {
					outside_x = 3,
					outside_y = 1,
					inside_x = 4.5,
					inside_y = 25.5,
				},
			},
		}
	end,
	["factory-3"] = function()
		return {
			name = "factory-3",
			tier = 3,
			inside_size = 60,
			outside_size = 16,
			default_power_transfer_rate = 50,
			inside_door_x = 0,
			inside_door_y = 31,
			outside_door_x = 0,
			outside_door_y = 8,
			outside_energy_receiver_type = "factory-power-input-16",
			outside_energy_sender_type = "factory-power-output-16",
			inside_energy_x = -4,
			inside_energy_y = 32,
			energy_indicator_x = -3.5,
			energy_indicator_y = 33.5,
			overlay_name = "factory-3-overlay",
			overlay_x = 0,
			overlay_y = 7,
			rectangles = {
				{
					x1 = -33, x2 = 33, y1 = -33, y2 = 33, tile = "out-of-factory"
				},
				{
					x1 = -31, x2 = 31, y1 = -31, y2 = 31, tile = "factory-wall-3"
				},
				{
					x1 = -30, x2 = 30, y1 = -30, y2 = 30, tile = "factory-floor-3"
				},
				{
					x1 = -3, x2 = 3, y1 = 30, y2 = 33, tile = "factory-wall-3"
				},
				{
					x1 = -2, x2 = 2, y1 = 30, y2 = 33, tile = "factory-entrance-3"
				},
			},
			mosaics = {
				{	x1 = -6, x2 = 6, y1 = -4, y2 = 4, tile = "factory-pattern-3",
					pattern = {
						" ++++   +++ ",
						"++  ++ ++ ++",
						"++  ++    ++",
						"++ +++   ++ ",
						"+++ ++    ++",
						"++  ++    ++",
						"++  ++ ++ ++",
						" ++++   +++ ",
					}
				},
			},
			lights = {
				{x = -7.5, y = -7.5},
				{x = -7.5, y = 7.5},
				{x = 7.5, y = -7.5},
				{x = 7.5, y = 7.5},
				{x = -22.5, y = -7.5},
				{x = -22.5, y = 7.5},
				{x = 22.5, y = -7.5},
				{x = 22.5, y = 7.5},
				{x = -7.5, y = -22.5},
				{x = -7.5, y = 22.5},
				{x = 7.5, y = -22.5},
				{x = 7.5, y = 22.5},
				{x = -22.5, y = -22.5},
				{x = -22.5, y = 22.5},
				{x = 22.5, y = -22.5},
				{x = 22.5, y = 22.5},
			},
			connection_tile = "factory-floor-3",
			connections = {
				w1 = make_connection("w1", -8.5,-5.5, -30.5,-24.5, west),
				w2 = make_connection("w2", -8.5,-4.5, -30.5,-20.5, west),
				w3 = make_connection("w3", -8.5,-3.5, -30.5,-9.5, west),
				w4 = make_connection("w4", -8.5,-2.5, -30.5,-5.5, west),
				w5 = make_connection("w5", -8.5,2.5, -30.5,5.5, west),
				w6 = make_connection("w6", -8.5,3.5, -30.5,9.5, west),
				w7 = make_connection("w7", -8.5,4.5, -30.5,20.5, west),
				w8 = make_connection("w8", -8.5,5.5, -30.5,24.5, west),
				
				e1 = make_connection("e1", 8.5,-5.5, 30.5,-24.5, east),
				e2 = make_connection("e2", 8.5,-4.5, 30.5,-20.5, east),
				e3 = make_connection("e3", 8.5,-3.5, 30.5,-9.5, east),
				e4 = make_connection("e4", 8.5,-2.5, 30.5,-5.5, east),
				e5 = make_connection("e5", 8.5,2.5, 30.5,5.5, east),
				e6 = make_connection("e6", 8.5,3.5, 30.5,9.5, east),
				e7 = make_connection("e7", 8.5,4.5, 30.5,20.5, east),
				e8 = make_connection("e8", 8.5,5.5, 30.5,24.5, east),
				
				n1 = make_connection("n1", -5.5,-8.5, -24.5,-30.5, north),
				n2 = make_connection("n2", -4.5,-8.5, -20.5,-30.5, north),
				n3 = make_connection("n3", -3.5,-8.5, -9.5,-30.5, north),
				n4 = make_connection("n4", -2.5,-8.5, -5.5,-30.5, north),
				n5 = make_connection("n5", 2.5,-8.5, 5.5,-30.5, north),
				n6 = make_connection("n6", 3.5,-8.5, 9.5,-30.5, north),
				n7 = make_connection("n7", 4.5,-8.5, 20.5,-30.5, north),
				n8 = make_connection("n8", 5.5,-8.5, 24.5,-30.5, north),
				
				s1 = make_connection("s1", -5.5,8.5, -24.5,30.5, south),
				s2 = make_connection("s2", -4.5,8.5, -20.5,30.5, south),
				s3 = make_connection("s3", -3.5,8.5, -9.5,30.5, south),
				s4 = make_connection("s4", -2.5,8.5, -5.5,30.5, south),
				s5 = make_connection("s5", 2.5,8.5, 5.5,30.5, south),
				s6 = make_connection("s6", 3.5,8.5, 9.5,30.5, south),
				s7 = make_connection("s7", 4.5,8.5, 20.5,30.5, south),
				s8 = make_connection("s8", 5.5,8.5, 24.5,30.5, south),
			},
			overlays = {
				nw = {
					outside_x = -4,
					outside_y = -4,
					inside_x = 3.5,
					inside_y = 31.5,
				},
				ne = {
					outside_x = 4,
					outside_y = -4,
					inside_x = 4.5,
					inside_y = 31.5,
				},
				
				sw = {
					outside_x = -4,
					outside_y = 2,
					inside_x = 3.5,
					inside_y = 32.5,
				},
				se = {
					outside_x = 4,
					outside_y = 2,
					inside_x = 4.5,
					inside_y = 32.5,
				},
			},
		}
	end,
}

function HasLayout(name)
	return layout_generators[name] ~= nil
end

function CreateLayout(name)
	if layout_generators[name] then
		return layout_generators[name]()
	else
		return nil
	end
end