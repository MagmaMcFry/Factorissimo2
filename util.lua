local F = "__Factorissimo2__";

function centered_square(size)
	local r = size/2
	return {{-r,-r},{r,r}}
end

-- A blank sprite
function blank()
	return {
		filename = F.."/graphics/nothing.png",
		priority = "high",
		width = 1,
		height = 1,
	}
end

-- A blank animation
function ablank()
	return {
		filename = F.."/graphics/nothing.png",
		priority = "high",
		width = 1,
		height = 1,
		frame_count = 1,
	}
end
