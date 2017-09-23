local F = "__Factorissimo2__";

function centered_square(size)
	local r = size/2
	return {{-r,-r},{r,r}}
end

function shift_bounds_by(dx, dy, bounds)
	return {
		{
			bounds[1][1]+dx,
			bounds[1][2]+dy
		},
		{
			bounds[2][1]+dx,
			bounds[2][2]+dy
		}
	}
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

-- Given a list of x-coords and y-coords, returns a grid of points; or, more
-- abstractly, returns the cross-product of two lists.
function grid_of(x_list, y_list)
	local result = {}
	for _,xi in ipairs(x_list) do
	for _,yi in ipairs(y_list) do
		table.insert(result, {x=xi,y=yi})
	end end
	return result
end

function merge_properties(a,b)
	local result = {}
	for k,v in pairs(a) do
		result[k] = v
	end
	for k,v in pairs(b)  do
		result[k] = v
	end
	return result
end

-- Given a list {a,b,c,...} returns a dictionary from items that were in the
-- list to true, {a:true, b:true, c:true, ...}
function list_to_index(list)
	local result = {}
	for _,v in ipairs(list) do
		result[v] = true
	end
	return result
end
