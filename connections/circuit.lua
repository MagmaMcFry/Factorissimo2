Circuit = {}

Circuit.color = {r = 255/255, g = 61/255, b = 61/255}
Circuit.entity_types = {"pump", "constant-combinator"}
Circuit.unlocked = function(force) return force.technologies["factory-connection-type-circuit"].researched end

Circuit.connect = function(factory, cid, cpos, outside_entity, inside_entity)
	if outside_entity.name == "factory-circuit-input" and inside_entity.name == "factory-circuit-output" then
		return {from = outside_entity, to = inside_entity, facing = cpos.direction_in}
	elseif outside_entity.name == "factory-circuit-output" and inside_entity.name == "factory-circuit-input" then
		return {from = inside_entity, to = outside_entity, facing = cpos.direction_out}
	end
	return nil
end

Circuit.recheck = function(conn)
	return conn.from.valid and conn.to.valid
end

local DELAYS = {1, 10, 60, 180, 600}
local DEFAULT_DELAY = 60

Circuit.indicator_settings = {"d0", "b0"}

for _,v in pairs(DELAYS) do
	table.insert(Circuit.indicator_settings, "d" .. v)
	table.insert(Circuit.indicator_settings, "b" .. v)
end

local function make_valid_delay(delay)
	for _,v in pairs(DELAYS) do
		if v == delay then return v end
	end
	return 0 -- Catchall
end

Circuit.direction = function(conn)
	return "d" .. make_valid_delay(conn._settings.delay or DEFAULT_DELAY), conn.facing
end

Circuit.rotate = ConnectionLib.beep

Circuit.adjust = function(conn, positive)
	local delay = conn._settings.delay or DEFAULT_DELAY
	if positive then
		for i = #DELAYS,1,-1 do
			if DELAYS[i] < delay then
				delay = DELAYS[i]
				break
			end
		end
		conn._settings.delay = delay
		return {"factory-connection-text.update-faster", delay}
	else
		for i = 1,#DELAYS do
			if DELAYS[i] > delay then
				delay = DELAYS[i]
				break
			end
		end
		conn._settings.delay = delay
		return {"factory-connection-text.update-slower", delay}
	end
end

Circuit.tick = function(conn)
	local from = conn.from -- This is a lamp entity
	local to = conn.to -- This is a constant-combinator entity
	if from.valid and to.valid then
		local control_behavior = to.get_or_create_control_behavior()
		if control_behavior.enabled then
			local red_network = from.get_circuit_network(defines.wire_type.red)
			local red_signals = (red_network and red_network.signals) or {}
			local green_network = from.get_circuit_network(defines.wire_type.green)
			local green_signals = (green_network and green_network.signals) or {}
			local i = #red_signals
			for _, signal in pairs(green_signals) do
				i = i+1
				red_signals[i] = signal
			end
			local transferred_signals = {}
			for j=1,math.min(15,i) do --15 is the constant combinator slot count
				local signal = red_signals[j]
				signal.index = j
				transferred_signals[j] = signal
			end
			
			-- This call is ridiculously slow, it takes up to 0.1 ms PER SIGNAL. Nothing we can do about that
			control_behavior.parameters = {parameters = transferred_signals}
		end
		return conn._settings.delay or DEFAULT_DELAY
	else
		return false
	end
end

Circuit.destroy = function(conn)
end