--[[
the structure 'robots' contains all global variable necessary to robots' system

a job is a structure of type
{
	start = func(self, param),
	loop =	func(self, dtime),
	end =   func(self),
}
where self is the LuaEntity the routines are working on.


Each ennemy should die by itself when his HP get bellow 0 (so correct creatures or mobs mod if necessary)

]]



----------------------------------------------------------------------
--+               core functions for the robot system              +--
----------------------------------------------------------------------

robots = { -- robot's namespace
	current_new_unit = 0,
	
	registered_orders = {}, -- possible orders are registered in
	
	register_order = function(patterns, job)
		for i = 1,#robots.registered_orders+1 do -- search for an empty definition (removed)
			if robots.registered_orders[i] == nil then -- definition is empty
				robots.registered_orders[i] = {patterns=patterns, job=job} -- assign it
				return i -- return index of order definition in database
			end
		end
	end,
	
	unregister_order = function(pattern)
		for i = 1,#robots.registered_orders do
			if robots.registered_orders[i] then -- a registered value can be deleted
				local existing_value = false
				for j = 1,#robots.registered_orders[i].patterns do
					if robots.registered_orders[i].patterns[j] then -- a pattern can be deleted
						existing_value = true -- check if ther is more than one existing pattern
						-- if an order contains pattern, remove pattern from definition.
						if robots.registered_orders[i].patterns[j] == pattern then
							robots.registered_orders[i].patterns[i] = nil -- delete pattern
						end
					end
				end
				-- it there is no more pattern for definition, remove definition
				if existing_value == false then
					robots.registered_orders[i] = nil -- delete definition
				end
			end
		end
	end,
	
	register_robot = function(name, def, def_dead) -- simply register the corresponding LUAEntity and the dead entity
		for key, param in pairs(robots.default_def) do
			if not def[key] then	def[key] = param 	end
		end
		-- store the dead entity name in the entity def
		local name_dead = name.."_dead"
		if def_dead then 
			def.dead_name = name_dead 
			minetest.register_entity(name_dead, def_dead)
		end
		minetest.register_entity(name, def)
	end,
	
	default_priority = 0,
	-- priorities works as a hierarchy:
	--   the more the number is high, the highest is the priority of the player
	--   if there is no record, player's priority is robots.default_priority
	--   negative value means the player is not allowed to order to robots
	list_protections = {},	-- protection priority for each player, indexed by player name
	list_targets = {},		-- list of players to eliminate
	list_obedience = {},	-- priority to obey to players, indexed by player name
	list_ennemies = {		-- list of entities to consider as danger, so to eliminate on sight
		"creatures:zombie",
		"creatures:ghost",
		"creatures:oerrki",
	},
	
	jobs = {},  -- list of standard jobs
}



----------------------------------------------------------------------
--+                 section for default robot pattern              +--
----------------------------------------------------------------------



local PI = 3.141519


robots.default_def = { -- U-87 definition, entity definition and methods
	-- INCOMPLETE DEFINITION (with default parameters, that can be overwritten by a new def) --
	physical = true,
	collisionbox = {-0.3, 0, -0.3,	 0.3, 1.9, 0.3},
	visual = "mesh",
	visual_size = {x=2, y=2},
	can_punch = true,
	hp_max = 100,
	
	fps = 25, 			-- fps for animations : to ajust
	animations = false,	-- set of keyframe pairs for animations
	default_job = false,	--same as job, used when there is no active job (like order), it is the idle job
	range = 20,		-- range to fire
	fire = false,	-- function to fire something

	-- INTERNAL VARIABLES (not in def) --
	
	-- current tasks: start short routine, routine to call in loop, routine to finish
	job = {
		start = nil,
		loop = nil,     -- called if job_start returns true, returns true to end the loop
		finish = nil,   -- called when loop returns true
	},
	job_timer = 0,
	
	number = nil,	-- number of the robot, its identity
	user = nil, -- name of the ordering player
	-- for animation
	end_time = 0, -- if set to 0, animation is in loop
	end_frame = 0,
	-- for movements
	jump = false,
	jump_date = 0,
	
	dead = nil,		-- name of entity to replace by, when the robot is dead
	
	timer = 0,
	lock = false,
	
	
	-- called when entity is loaded into the game
	on_activate = function(self, staticdata, dtime_s)
		--print("load robot ...")
		-- standby animation
		self.set_animation(self, self.animations.reset_pose, 0, true)
		-- gravity
		self.object:setacceleration({x=0, y=-9.81, z=0})
		-- doesn't use the buggy damage system
		self.object:set_armor_groups({immortal=1})
		
		if staticdata then
			local num = string.match(staticdata, "^([0-9]+)")
			self.number = tonumber(num)
		end
		if self.number == nil then
			robots.current_new_unit = robots.current_new_unit +1
			self.number = robots.current_new_unit
		elseif (self.number > robots.current_new_unit) then 
			robots.current_new_unit = self.number
		end
		
		self.object:set_properties({nametag="R-"..tostring(self.number)})
		--print("         loaded")
	end,
	
	-- called multiple times in the game (more than 1 times per second if no lag)
	on_step = function(self, dtime)
		if (self.lock == true) then return end  -- make this function works synchronously
		--self.timer = self.timer + dtime
		--if (self.timer < 0.1) then return end
		--self.timer = 0
		self.lock = true
		-- die when it have no more HP
		if self.object:get_hp() <= 0 then
			local anim = self.animations.die
			self:set_animation(anim, false)
			local p = self.object:getpos()
			local y = self.object:getyaw()
			minetest.after((anim[2]-anim[1])/self.fps, function()
				if self.dead_name then    
					local obj = minetest.add_entity(p, self.dead_name) 
					obj:setyaw(y)
				end
				self.object:remove()
			end)
			return
		end
	
		-- update job
		if self.job and self.job.loop then
			if self.job.loop(self, dtime) == true then
				if self.job.finish then self.job.finish(self) end
				if not self.job.silent then self:say("at your service") end
				self.job = nil
			end
		elseif self.default_job then
			--print("start default job")
			self:set_job(self.default_job)
			self.user = nil
		end
		self:set_animation()
		
		self.lock = false
	end,
	
	-- called when LUAEntity is disabled
	get_staticdata = function(self)
		return tostring(self.number)
	end,
	
	-- set animation utility
	-- becareful: if the animation given has the same ending frame than the current executing animation, the new will not be executed
	set_animation = function(self, animation, looping)
		local dtime = os.clock()
		if animation == nil then
			if (self.end_time < dtime) and (self.end_time > 0)  then
				self.object:set_animation({x=self.animations.reset_pose[1], y=self.animations.reset_pose[2]}, self.fps, 0)
				self.end_frame = 0
				self.end_time = 0
			end
		elseif (self.end_frame == animation[2]) then
			return
		elseif (dtime > self.end_time) or (self.end_time == 0) then
			self.object:set_animation({x=animation[1], y=animation[2]}, self.fps, 0)
			if looping then
				self.end_time = 0
			else
				self.end_time = (animation[2]-animation[1])/self.fps + dtime
			end
			self.end_frame = animation[2]
		end
	end,
	
	-- set linear velocity
	set_velocity = function(self, v)
		local yaw = self.object:getyaw()
		if self.drawtype == "side" then
			yaw = yaw+(math.pi/2)
		end
		local x = math.sin(yaw) * -v
		local z = math.cos(yaw) * v
		local p = self.object:getpos()
		-- follow the grid (for obstacle avoidance)
		--[[
		if math.abs(x)<0.8 and math.abs(z)>0.8 then
			x = math.floor(p.x)-p.x
		elseif math.abs(x)>0.8 and math.abs(z)<0.8 then
			z = math.floor(p.z)-p.z
		end
		]]
		self.object:setvelocity({x=x, y=self.object:getvelocity().y, z=z})
	end,
	
	walk = function(self, v)
		local p = self.object:getpos()
		local node = minetest.get_node({x=p.x, y=p.y-1, z=p.z}).name
		if node == "air" or minetest.registered_nodes[node].walkable == false then
			self.set_animation(self, self.animations.fall, true)
			self.set_velocity(self, v)
		end
		local y = self.object:getyaw()
		local jump
		p = {x=p.x-math.sin(y), y=p.y+self.collisionbox[2], z=p.z+math.cos(y)}
		node = minetest.get_node(p).name
		--print(node.."   walkable: "..tostring(minetest.registered_nodes[node].walkable))
		if (v > 0) and node ~= "air" and (not node:find("_b")) and minetest.registered_nodes[node].walkable then
			jump = true
		--else
			--p.y = p.y-1
			--node = minetest.get_node(p).name
			-- detect holes
			--if (not node) or (node == "air") or (minetest.registered_nodes[node].walkable == false) then -- stop if there is void in front
				--v = 0
			--end
		end
		self.set_jump(self, jump)
		self.set_velocity(self, v)
		if (v ~= 0) and (self.jump == false) then
			if v < 3 then   self.set_animation(self, self.animations.walk_step, true)
			else            self.set_animation(self, self.animations.run_step,  true)
			end
		elseif v == 0 then
			self.set_animation(self, self.animations.reset_pose, true)
		end
	end,
			
	set_jump = function(self, j)
		local t = os.clock()
		local pos = self.object:getpos()
		pos.y = pos.y+self.collisionbox[2]-0.02
		local under = minetest.get_node(pos).name
		if j and self.jump_date < t and minetest.registered_nodes[under].walkable then
			self.jump_date = t + (self.animations.jump[2]-self.animations.jump[1])*1/self.fps + 0.1
			self.set_animation(self, self.animations.jump, false)
			local v = self.object:getvelocity()
			v.y = v.y + 6
			self.object:setvelocity(v)
			self.jump = true
		else
			self.jump = false
		end
	end,
	
	-- calculate linear velocity
	get_velocity = function(self) 
		local v = self.object:getvelocity()
		return (v.x^2 + v.z^2)^(0.5)
	end,
	
	set_job = function(self, job, param)
		-- check if the routine was already active
		if job == self.job then return end
		-- terminate the previous routine
		if self.job and self.job.loop and self.job.finish then self.job.finish(self) end
		self.job = false
		if job then
			if job.start then	job.start(self, param) end -- start it
			if job.loop then	self.job = job end -- set the new one
		end
	end,
	
	say = function(self, message)
		minetest.chat_send_all("<unit "..tostring(self.number).."> "..message)
	end,
	
}




----------------------------------------------------------------------
--+                      some useful functions                     +--
----------------------------------------------------------------------

function distance(a, b)
	return math.sqrt(math.sqrt((a.x - b.x)^2 + (a.z - b.z)^2)^2 + (a.y - b.y)^2)
end

function distance2d(a, b)
	return math.sqrt((a.x - b.x)^2 + (a.z - b.z)^2)
end

function min(x, y)
	if x < y then return x else return y end
end

function angle2d(pos, obj)
	if obj.x < pos.x then
		return math.acos((obj.z-pos.z)/distance2d(obj,pos))
	else
		return -math.acos((obj.z-pos.z)/distance2d(obj,pos))
	end
end

function inside(x, inter)
	if x > inter[1] and x < inter[2] then return true else return false end
end

function line_of_sight(pos, target)  -- test if there is nothing on the line between pos and target positions
	local diff_x = target.x-pos.x
	local diff_y = target.y-pos.y
	local diff_z = target.z-pos.z
	
	if (math.abs(diff_y/diff_z) > 1) and (math.abs(diff_y/diff_x) > 1) then return false end
	
	local vec_x = diff_x/diff_z
	if (vec_x < -1) or (1 < vec_x) then   -- if it is relevant to use z as variable
		local vec_z = diff_z/diff_x
		local vec_y = diff_y/diff_x
		local x = 0
		local x_max = diff_x
		
		if target.x > pos.x then
			--print("tx>x")
			while x < x_max do
				x = x+1
				--print("test "..tostring(pos.x+x)..", "..tostring(pos.z+vec_z*x))
				local node = minetest.get_node_or_nil({x=pos.x+x, y=pos.y+vec_y*x, z=pos.z+vec_z*x})
				if node and (node.name ~= "air") and (minetest.registered_nodes[node.name].drawtype ~= "nodebox") then   return false end
			end
		else
			--print("tx<x")
			while x > x_max do
				x = x-1
				--print("test "..tostring(pos.x+x)..", "..tostring(pos.z+vec_z*x))
				local node = minetest.get_node_or_nil({x=pos.x+x, y=pos.y+vec_y*x, z=pos.z+vec_z*x})
				if node and (node.name ~= "air") and (minetest.registered_nodes[node.name].drawtype ~= "nodebox") then   return false end
			end
		end
	else  -- then prefer z
		local vec_y = diff_y/diff_z
		local z = 0
		local z_max = diff_z
		
		if target.z > pos.z then
			--print("tz>z")
			while z<z_max do
				z = z+1
				--print("test "..tostring(pos.x+vec_x*z)..", "..tostring(pos.y+vec_y*z)..", "..tostring(pos.z+z))
				local node = minetest.get_node_or_nil({x=pos.x+vec_x*z, y=pos.y+vec_y*z, z=pos.z+z})
				if  node and (node.name ~= "air") and (minetest.registered_nodes[node.name].drawtype ~= "nodebox") then   return false end
			end
		else
			--print("tz<z")
			while z>z_max do
				z = z-1
				--print("test "..tostring(pos.x+vec_x*z)..", "..tostring(pos.z+z))
				local node = minetest.get_node_or_nil({x=pos.x+vec_x*z, y=pos.y+vec_y*z, z=pos.z+z})
				if  node and (node.name ~= "air") and (minetest.registered_nodes[node.name].drawtype ~= "nodebox") then   return false end
			end
		end
	end
	return true
end


----------------------------------------------------------------------
--+                    section for standard jobs                   +--
----------------------------------------------------------------------


-- possible job, select an ennemy then fire it
robots.jobs.fight = {
	loop = function(self, dtime)
		-- don't execute this routine too often
		self.job_timer = self.job_timer+dtime
		if self.job_timer < 0.4 then   return false  end
		self.job_timer = 0
		if not self.targets then  return true end
		local pos = self.object:getpos()
		pos.y = pos.y+1.5
		-- remove dead ennemies
		for i, ennemy in ipairs(self.targets) do
			if (not ennemy) or (not ennemy.get_hp) or (ennemy:get_hp()<= 0)  then  
				table.remove(self.targets, i) 
			end
		end
		-- fire the first ennemy in target
		local num_targets = #(self.targets)
		if num_targets > 0 then
			-- find an ennemy to fight
			local i=1
			local targetpos = self.targets[i]:getpos()
			if not targetpos then return false end
			targetpos.y = targetpos.y+1
			while (i<= num_targets) and (line_of_sight(pos, targetpos) == false) do
				i = i+1 
			end
			-- fire if it is possible
			if i <= num_targets then
				self.object:setyaw(angle2d(pos, targetpos))
				--print("robot is at  "..tostring(pos.x)..", "..tostring(pos.y)..", "..tostring(pos.z))
				--print("target is at "..tostring(dir.x)..", "..tostring(dir.y)..", "..tostring(dir.z))
				--print("fire ennemy "..tostring(self.targets[i]))
				self:fire({x = (targetpos.x-pos.x),      y = (targetpos.y-pos.y),    z = (targetpos.z-pos.z)})
				return false
			end
		else
			self:say("all targets down")
			return true  -- if there is no target, the fight is over
		end
		return false
	end,
	

	finish = function(self)
		self:set_animation(self.animations.fire_stop, false)
	end,
	
	silent = true,
}

-- possible job: find all ennemies in the perimeter, if there is some switch to fight
local find_ennemies_timer = 0
robots.jobs.find_ennemies = function(self, dtime)
	-- don't execute this routine too often
	self.job_timer = self.job_timer+dtime
	if self.job_timer < 1 then   return false  end
	self.job_timer = 0
	self.targets = {}
	local pos = self.object:getpos()
	
	-- if there is no ennemy to fight, search for one
	local objects = minetest.get_objects_inside_radius(pos, self.range) -- get entities in the range
	local detected = false
	for k, object in pairs(objects) do
		local entity = object:get_luaentity()
		if object:get_hp()>0 then
			-- search for a player target
			if object:is_player() then
				local name = object:get_player_name()
				for i, ennemy in pairs(robots.list_targets) do
					if ennemy == name then
						local index = #(self.targets)+1
						self.targets[index] = object
						detected = true
						break
					end
				end
			-- search for a monster
			elseif entity and object:get_hp()>0 then
				for i, ennemy in pairs(robots.list_ennemies) do
					if ennemy == entity.name then
						local index = #(self.targets)+1
						self.targets[index] = object
						detected = true
						break
					end
				end
			end
		end
	end
	if detected == true then
		self:say("threat detected")
		self:set_job(robots.jobs.fight)
	end
	
	return false
end


-- robots are listening for orders
minetest.register_on_chat_message(function(name, message)
	-- find player's priority for ordering
	local priority = robots.default_priority
	if robots.list_obedience[name] then 	priority = robots.list_obedience[name] end
	if priority <= 0 then 
		minetest.chat_send_all("permission denied")
		return 
	end

	-- find robots to order to
	local finish = false
	local order = ""
	local reg = {}
	for i = 1,#robots.registered_orders do -- scan all possible orders in all orders definition
		reg  = robots.registered_orders[i]
		for j = 1,#reg.patterns do
			-- if order match
			order = reg.patterns[j]
			if message:find(order) then 
				finish = true
				break 
			end
		end
		if finish then break end
	end
	
	if not order then return end
	-- decode the order:   [unit] [number1, number2, ...] order
	local r_number = string.match(message, "^([0-9]+) .*")
	r_number = tonumber(r_number)
	-- find robots to receive order
	local sender = minetest.get_player_by_name(name)
	if sender == nil then return end
	local objects = minetest.get_objects_inside_radius(sender:getpos(), 10)
	
	-- check for brigadiers inside the zone
	for k, object in pairs(objects) do
		local entity = object:get_luaentity()
		if entity and entity.name == "robots:brigadier" then
			-- the player must have sufficient rights to order to the robot
			local allowed = true
			if entity.job and entity.user and robots.list_obedience[entity.user]
				and robots.list_obedience[entity.user] > priority then
					allowed = false
			end
			-- if allowed
			if allowed then
				if r_number then -- check if the order is for one robot in particular or for each one
					if r_number == entity.number then
						entity.set_job(entity, reg.job, message)
						entity.user = name
						break
					end
				else
					entity.set_job(entity, reg.job, message)
					entity.user = name
				end
			else
				entity:say("your level is not sufficient")
			end
		end
	end
end)

local here = minetest.get_modpath("robots")
dofile(here.."/rights.lua") -- load players' permissions to order to robots
dofile(here.."/orders.lua") -- register default orders
dofile(here.."/brigadier.lua")
