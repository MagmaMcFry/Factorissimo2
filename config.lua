
function GetConfigs()
	return {
		-- Initially, each factory interior will be on its own surface, but
		-- when there are more factories than this number, Factorissimo will
		-- start reusing surfaces (with an appropriate distance between interiors).
		-- Default: 100
		max_surfaces = 100,
	}
end
