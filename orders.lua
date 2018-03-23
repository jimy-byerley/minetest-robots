-- fonction to test if there is an not walkable and not walkable obstacle in direction dir at distance dist of position pos
local test_way = function(pos, dir, dist)
	pos = {x=pos.x-dist*math.sin(dir), y=pos.y+1, z=pos.z+dist*math.cos(dir)}
	local node1 = minetest.get_node(pos).name
	--print(dir.."    "..node1)
	
	if node1 ~= "air" and (not node1:find("_b")) and minetest.registered_nodes[node1].walkable then -- "_b" is the end of the name of opened doors
		return false
	else
		return true
	end
end

robots.register_order({"follow me", "come on", "come"}, {
	loop = function(self, dtime)
		--if not self.timer then self.timer = 0 end
		--self.timer = self.timer+dtime
		--if self.timer < 0.2 then return end
		--self.timer = 0
		
		local player = minetest.get_player_by_name(self.user)
		local velocity = 0
		local jump = false
		local yaw_to = angle2d(self.object:getpos(), player:getpos())
	
		-- reaction changes with distance of separation
		local distance_to = distance(self.object:getpos(), player:getpos())
		if distance_to > 100 then -- if player teleport himself, the u87 can't know where is the player, but if the cylon can see the player, he can continue his task
			velocity = 0
			return false
		elseif distance_to < 2 then
			velocity = 0
		elseif distance_to > 3 then -- is distance is too big, the robot runs
			velocity = 4.5
		else
			velocity = 2
		end
		-- avoidance alogorithm
		local p = self.object:getpos()
		self.avoidance = self.avoidance or 0
		
		if test_way(p, yaw_to, 1) == false then
			local i=0
			local increment = math.pi/8
			if self.avoidance < 0 then increment = -increment end
			while (i< 8 and test_way(p, self.avoidance+yaw_to, 0.5) == false) do
				if self.avoidance > 0 then 
					print("change sign")
					self.avoidance = -self.avoidance
				else
					print("add")
					self.avoidance = self.avoidance + increment
				end
				--print(self.avoidance)
				i = i+1
			end
			--[[
			local y = self.object:getyaw()
			if not test_way(p, yaw_to, 1) or math.abs(y-yaw_to) > 2*math.pi/3 then
				local left = test_way(p, yaw_to+math.pi/2, 1)
				local right = test_way(p, yaw_to-math.pi/2, 1)
				if not left and not right then
					yaw_to = yaw_to + math.pi
				elseif left then
					yaw_to = yaw_to + math.pi/2
				elseif right then
					yaw_to = yaw_to - math.pi/2
				elseif test_way(p, y, 1) then
					yaw_to = y
				end
			end
			]]
			yaw_to = self.avoidance + yaw_to
		end
		-- walk and turn
		self.walk(self, velocity)
		if distance_to > 2 then
			-- set yaw of the robot
			self.object:setyaw(yaw_to)
		end
			
		return false
	end})

robots.register_order({"stop", "keep out", "don't move"}, {
	start = function(self, dtime)
		self:set_velocity(0)
		self:set_animation(self.animations.reset_pose, true)
		return true
	end})

robots.register_order({"walk", "go"}, { 
	start = function(self, message)
		self.move_time = 0
		local speed = 3
		local distance = string.match(message, " ([+-]?[0-9]+)m")
		if distance 
		then distance = tonumber(distance)
		else distance = 10
		end
		if distance < 0 or message:find("back") then speed = -speed end
		self.move_time_target = distance/speed
		self.walk(self, speed)
		return true
	end,
	loop = function(self, dtime)
		self.move_time  = self.move_time + dtime
		if self.move_time > self.move_time_target then
			self.walk(self, 0)
			self.move_time = nil
			self.move_time_target = nil
			return true
		end
		return false
	end})

robots.register_order({"attention", "take care of yourself", "straight"}, {
	start = function(self, message)
		local start_anim = self.animations.attention_start
		self:set_animation(start_anim, true)
		minetest.after((start_anim[2] - start_anim[1])/self.fps, 
			function() self:set_animation(self.animations.attention_step, true) end
		)
	end})
