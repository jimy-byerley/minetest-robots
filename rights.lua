
-- load protection list
local here = minetest.get_worldpath()
local PROTECTIONS_FILE 	= here.."/robots_protections.txt"
local TARGETS_FILE 		= here.."/robots_targets.txt"
local OBEDIENCE_FILE 	= here.."/robots_obedience.txt"

robots.reload_protections = function()
	local f = io.open(PROTECTIONS_FILE, 'r')
	if f == nil then
		print("robot configuration: file \""..PROTECTIONS_FILE.."\" not found.")
		return
	end
	io.close(f)
	
	local list = {}
	for line in io.lines(PROTECTIONS_FILE) do
		local priority, player = string.match(line, "^([0-9]+) +(.+)$")
		if player and priority then
			list[player] = tonumber(prority)
		end
	end
	robots.list_protections = list
	
	print("robots: protections list reloaded from file.")
end

robots.reload_obedience = function()
	local f = io.open(OBEDIENCE_FILE, 'r')
	if f == nil then
		print("robot configuration: file \""..OBEDIENCE_FILE.."\" not found.")
		return
	end
	io.close(f)
	
	local list = {}
	for line in io.lines(OBEDIENCE_FILE) do
		local priority, player = string.match(line, "^([0-9]+) +(.+)$")
		if player and priority then
			list[player] = tonumber(priority)
		end
	end
	robots.list_obedience = list
	
	print("robots: obedience priorities list reloaded from file.")
end

robots.reload_targets = function()
	local f = io.open(TARGETS_FILE, 'r')
	if f == nil then
		print("robot configuration: file \""..TARGETS_FILE.."\" not found.")
		return
	end
	io.close(f)
	
	local list = {}
	local i = 0
	for line in io.lines(TARGETS_FILE) do
		list[i] = line
		i = i+1
	end
	robots.list_ennemies = list
	
	print("robots: targets list reloaded from file.")
end


robots.reload_obedience()
robots.reload_protections()
robots.reload_targets()
