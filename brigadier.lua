--[[
	The brigadier robot is implemented here, as a specialization of a basic_robot
]]

local PI = math.pi or 3.1415

----------------------------------------------------------------------
--+                 section for default robot pattern              +--
----------------------------------------------------------------------

local brigadier_anim = { -- it describes animations by the starting/ending frames
	reset_pose = {0, 0}, -- reset pose cycle
	
	walk_start = {73, 78}, -- start walking : make the first step
	walk_step = {78, 95}, -- make two step : a cycle to redo it in loop
	walk_stop = {95, 101}, -- stop walking : from step trasition pose to reset pose
	
	run_start = {200, 206},
	run_step = {206, 223},
	run_stop = {223, 229},
	
	jump = {139, 144},
	fall = {157, 157},
	
	attention_start = {0, 5},
	attention_step = {5, 6},
	fire_start =	{118, 124},
	fire_step  =	{124, 125},
	fire_stop  =	{125, 129},
	
	-- position of the dead robot
	dead_lay = {175, 175},
	dead_fall = {179, 179},
	die = {168, 175},
}

local brigadier_def = {
	-- entity definition
	physical = true,
	collisionbox = {-0.3, 0, -0.3,	 0.3, 1.9, 0.3},
	visual = "mesh",
	visual_size = {x=2, y=2},
	mesh = "robots_brigadier.x",
	makes_footstep_sound = true,
	--can_punch = true,
	textures = {"robots_brigadier.png"},
	hp_max = 100,
	
	animations = brigadier_anim,  -- table of keyframes for animations
	fps = 25, -- fps for animations : to ajust
	default_job = {
		loop = robots.jobs.find_ennemies,
		silent = true,
	},  --same as job, used when there is no active job (like order), it is the idle job
	
	range = 20,
	fire = function(self, target)
		local p = self.object:getpos()
		p.y = p.y+1.7
		--print("fire at "..tostring(target.x)..", "..tostring(target.y)..", "..tostring(target.z))
		self.set_animation(self, self.animations.fire_step, true)
		firearmslib.fire("firearms_guns:m4", p, target, self.object)
	end,
	
	on_punch = function(self, puncher, time_from_last_punch, tool_capability)
		if tool_capability.groupcaps and tool_capability.groupcaps.mecanic then
			local hp = self.object:get_hp()
			if (hp < self.hp_max) then
				self.object:set_hp(hp+5)
			end
			return
		end
		-- see if the puncher is a player to protect or not
		if puncher:is_player() then
			local name = puncher:get_player_name()
			local obedience = robots.list_obedience[name]
			if obedience and (obedience > 0) then
				return
			else
				for i, toprotect in pairs(robots.list_protections) do
					if (toprotect == name) then  return end
				end
			end
		end
		-- if it is an error, forgive it
		if time_from_last_punch > 10 then
			self:say("No resistance will be tolerated")
			return
		end
		-- if the function comes here, there is no reason to not fight back
		if not self.targets then 	self.targets = {puncher,}
		else						self.targets[#(self.targets)+1] = puncher
		end
		self:set_job(robots.jobs.fight)
	end,
}

local brigadier_dead = {
	-- entity definition
	physical = true,
	collisionbox = {-0.6, 0, -0.6,	 0.6, 0.5, 0.6},
	visual = "mesh",
	visual_size = {x=2, y=2},
	mesh = "robots_brigadier.x",
	--can_punch = true,
	textures = {"robots_brigadier.png"},
	hp_max = 50,
	
	-- inherited from the living robot
	animations = brigadier_anim,  -- table of keyframes for animations
	fps = 25, -- fps for animations : to ajust
	
	timer = 0,
	
	on_activate = function(self, staticdata, dtime)
		self.object:setacceleration({x=0, y=-9.81, z=0})  -- gravity
		-- doesn't use the buggy damage system
		--self.object:set_armor_groups({immortal=1})
		local anim = self.animations.dead_lay
		self.object:set_animation({x=anim[1], y=anim[2]}, self.fps, 0)
	end,
	
	on_step = function(self, dtime)
		self.timer = self.timer + dtime
		if self.timer < 2 then return end
		self.timer = 0
		
		if self.object:get_hp() <= 5 then
			self.object:remove()
			return
		end
		
		local pos = self.object:getpos()
		pos.y = pos.y-1
		local anim = self.animations.dead_lay
		if not minetest.get_node_or_nil(pos) then	anim = self.animations.dead_fall end
		self.object:set_animation({x=anim[1], y=anim[2]}, self.fps, 0)
	end,
	
	on_punch = function(self, puncher, time_from_last_punch, tool_capability)
		if not tool_capability.groupcaps then return end
		if tool_capability.groupcaps.mecanic then
			local p = self.object:getpos()
			local obj = minetest.add_entity(p, "robots:brigadier")
			obj:set_hp(5)
			if puncher and puncher:is_player() then	  obj:setyaw(puncher:get_look_horizontal() + PI) end
			self.object:set_hp(1)
			self.object:remove()
			return
		end
	end,
}



robots.register_robot("robots:brigadier", brigadier_def, brigadier_dead)

minetest.register_craftitem("robots:brigadier", {
	description = "Brigadier",
	inventory_image="robots_brigadier_item.png",
	wield_image = "robots_brigadier_item.png",
	wield_scale = {x=6, y=6, z=2},
	
	on_place = function(itemstack, placer, pointed_thing)
		pointed_thing.under.y = pointed_thing.under.y+0.5
		local obj = minetest.add_entity(pointed_thing.under, "robots:brigadier")
		if placer:is_player() then	  obj:setyaw(placer:get_look_horizontal() + PI) end
		
		if not minetest.setting_getbool("creative_mode") then
			itemstack:take_item()
		end
		return itemstack
	end,
})


technology.register_plan("BRIGADIER", "robots:brigadier", "robots_brigadier_plan.png", {
	"technic:mv_transformer",
	"technic:motor 17",
	"technic:fine_copper_wire 10",
	"technology:12V_battery",
	"technology:electronic_card",
	"technology:lamp_small",
	"default:steel_ingot 2",
	"firearms_guns:m4",
})
