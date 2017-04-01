ConnectionLib = {}

local beeps = {"Beep", "Boop", "Beep", "Boop", "Beeple"}

ConnectionLib.beep = function()
	local t = game.tick
	return beeps[t%5+1]
end