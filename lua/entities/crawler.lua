AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Author = "Earu"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.PrintName = "Crawler"
ENT.ClassName = "crawler"
ENT.Category = "Half-Life 2"
ENT.Model = "models/sprops/rectangles/size_4/rect_36x72x3.mdl"
ENT.Information = "Highly adaptable monowheel vehicle"
ENT.Name = "Crawler"
ENT.Class = "crawler"
ENT.AdminSpawnable = false
ENT.Forward = false
ENT.Backward = false
ENT.Left = false
ENT.Right = false
ENT.LastComputedRollTime = 0
ENT.CurrentRollVariation = 0
ENT.WheelLoopStopTime = 0

for _, f in pairs(file.Find("sound/crawler/*", "GAME")) do
	util.PrecacheSound("sound/crawler/" .. f)
end

list.Set("Vehicles", "crawler", ENT)

if SERVER then
	local CVAR_FASTDL = CreateConVar("crawler_fastdl", "0", FCVAR_ARCHIVE, "Should clients download content for crawlers on join or not")

	local function add_resource_dir(dir)
		for _,f in pairs(file.Find(dir .. "/*","GAME")) do
			local path = dir .. "/" .. f
			resource.AddFile(path)
		end
	end

	if CVAR_FASTDL:GetBool() then
		add_resource_dir("sound/crawler")
	end

	function ENT:Initialize()
		self:SetModel("models/sprops/rectangles/size_4/rect_36x72x3.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetPos(self:GetPos() + Vector(0, 0, 40))

		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:SetMass(24)
			phys:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
			phys:SetMaterial("gmod_silent")
			phys:Wake()
		end

		self.Seat = ents.Create("prop_vehicle_prisoner_pod")
		self.Seat:SetModel("models/nova/jalopy_seat.mdl")
		self.Seat:SetPos(self:GetPos() + Vector(0, 0, 5) + self:GetForward() * -5)
		self.Seat:SetAngles(self:GetAngles() - Angle(0, 90, 0))
		self.Seat:SetParent(self)
		self.Seat:Spawn()

		self.Wheel = ents.Create("prop_physics")
		self.Wheel:SetModel("models/hunter/tubes/tube2x2x025.mdl")
		self.Wheel:SetMaterial("models/props_combine/portalball001_sheet")
		self.Wheel:SetPos(self:GetPos() + Vector(0, 0, 20))
		self.Wheel:SetAngles(self:GetAngles() + Angle(90, 90, 0))
		self.Wheel:SetUseType(SIMPLE_USE)
		self.Wheel:Spawn()

		local old_bounds = self.Wheel:OBBMaxs()
		self.Wheel:PhysicsInitSphere(50)
		self.Wheel:SetCollisionBounds(-old_bounds, old_bounds)
		self.Wheel:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

		self.Wheel:SetRenderMode(RENDERMODE_TRANSALPHA)
		self.Wheel:SetColor(Color(0, 255, 255, 100))
		self:DeleteOnRemove(self.Wheel)

		local phys_wheel = self.Wheel:GetPhysicsObject()
		if IsValid(phys_wheel) then
			phys_wheel:SetMass(1)
			phys_wheel:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
			phys_wheel:SetMaterial("gmod_silent")
			phys_wheel:Wake()
		end

		-- this is necessary because if its done too early it crashes the game
		-- reason being that the spawnmenu, and some other entity spawning code set the pos
		-- of the entity after spawning it which causes the constraint to literreally shit itself
		timer.Simple(0.1, function()
			if not IsValid(self) then return end
			if not IsValid(self.Wheel) then return end

			self.Wheel:SetPos(self:GetPos() + Vector(0, 0, 20))
			self.Wheel:SetAngles(self:GetAngles() + Angle(90, 90, 0))
			constraint.Axis(self.Wheel, self, 0, 0, Vector(0, 0, 1), Vector(0, 0, 20), 0, 0, 0, 1)
		end)

		self.Filter = { self, self.Seat, self.Wheel }

		local function key_handler(ply, key, pressed)
			if ply ~= self:GetDriver() then return end

			if key == IN_FORWARD then
				self.Forward = pressed
			end

			if key == IN_BACK then
				self.Backward = pressed
			end

			if key == IN_MOVELEFT then
				self.Left = pressed
			end

			if key == IN_MOVERIGHT then
				self.Right = pressed
			end
		end

		hook.Add("KeyPress", self, function(_, ply, key) key_handler(ply, key, true) end)
		hook.Add("KeyRelease", self, function(_, ply, key) key_handler(ply, key, false) end)

		hook.Add("PlayerEnteredVehicle", self, function(_, ply, veh)
			if veh ~= self.Seat then return end
			table.insert(self.Filter, ply)
		end)

		hook.Add("PlayerLeaveVehicle", self, function(_, ply, veh)
			if veh ~= self.Seat then return end
			table.remove(self.Filter, 4)
			key_handler(ply, IN_FORWARD, false)
			key_handler(ply, IN_BACK, false)
			key_handler(ply, IN_MOVELEFT, false)
			key_handler(ply, IN_MOVERIGHT, false)
		end)

		hook.Add("PlayerUse", self, function(_, ply, ent)
			if (ent == self.Wheel or ent == self) and IsValid(self.Seat) then
				ply:EnterVehicle(self.Seat)
			end
		end)

		hook.Add("EntityEmitSound", self, function(_, data)
			if data.Entity == self.Wheel then return false end
		end)
	end

	local MAX_ROLL_VARIATION = 30
	local ROLL_VARIATION = MAX_ROLL_VARIATION * MAX_ROLL_VARIATION
	function ENT:ComputeTurningRoll()
		local now = CurTime()
		local delta = now - self.LastComputedRollTime

		if not self:InWater() then
			if (self.Right and self.Left) or (not self.Right and not self.Left) then
				if self.CurrentRollVariation > 0 then
					self.CurrentRollVariation = math.max(self.CurrentRollVariation - (ROLL_VARIATION * delta), 0)
				elseif self.CurrentRollVariation < 0 then
					self.CurrentRollVariation = math.min(self.CurrentRollVariation + (ROLL_VARIATION * delta), 0)
				else
					self.CurrentRollVariation = 0
				end
			else
				if self.Right then
					self.CurrentRollVariation = math.min(self.CurrentRollVariation + (ROLL_VARIATION * delta), MAX_ROLL_VARIATION)
				end

				if self.Left then
					self.CurrentRollVariation = math.max(self.CurrentRollVariation - (ROLL_VARIATION * delta), -MAX_ROLL_VARIATION)
				end
			end
		else
			self.CurrentRollVariation = 0
		end

		self.LastComputedRollTime = now
		return self.CurrentRollVariation
	end

	function ENT:ComputeAngularVelocity(phys, target_ang)
		local ang_vel = Vector(0, 0, 0)
		local cur_ang = phys:GetAngles()
		local cur_forward = cur_ang:Forward()
		local cur_right = cur_ang:Right()
		local target_right = target_ang:Right()
		local target_up = target_ang:Up()
		local pitch_vel = math.asin(cur_forward:Dot(target_up)) * 180 / math.pi
		local yaw_vel = math.asin(cur_forward:Dot(target_right)) * 180 / math.pi
		local roll_vel = math.asin(cur_right:Dot(target_up)) * 180 / math.pi
		ang_vel.y = ang_vel.y + pitch_vel
		ang_vel.z = ang_vel.z + yaw_vel
		ang_vel.x = ang_vel.x + roll_vel + self:ComputeTurningRoll()

		return ang_vel
	end

	local trace_line = util.TraceLine
	-- Technically we could only do two traces, but adding more fallbacks allows the bike to be more adaptable
	local TRACE_LENGTH = 200
	local PLATE_FORWARD_LENGTH = 36
	local PLATE_SIDE_LENGTH = 20
	function ENT:ExecuteTraces()
		local tr_front, tr_back, tr_right, tr_left
		local vector_down = -self:GetUp() * TRACE_LENGTH
		local vector_forward = self:GetForward() * TRACE_LENGTH
		local struct = { filter = self.Filter }

		do -- FRONT
			local tr_front_pos = self:GetPos() + self:GetForward() * PLATE_FORWARD_LENGTH

			-- TRACE FORWARD TO FURTHER FORWARD
			struct.start = tr_front_pos
			struct.endpos = tr_front_pos + vector_down + vector_forward
			tr_front = trace_line(struct)

			-- TRACE FORWARD TO BELOW
			if not tr_front.Hit then
				struct.endpos = tr_front_pos + vector_down
				tr_front = trace_line(struct)
			end

			-- TRACE FORWARD TO BACKWARD
			if not tr_front.Hit then
				struct.endpos = tr_front_pos + vector_down + -vector_forward
				tr_front = trace_line(struct)
			end
		end

		do -- BACK
			local tr_back_pos = self:GetPos() + -self:GetForward() * PLATE_FORWARD_LENGTH

			-- TRACE BACKWARD TO FURTHER BACKWARD
			struct.start = tr_back_pos
			struct.endpos = tr_back_pos + vector_down + -vector_forward
			tr_back = trace_line(struct)

			-- TRACE BACKWARD TO BELOW
			if not tr_back.Hit then
				struct.endpos = tr_back_pos + vector_down
				tr_back = trace_line(struct)
			end

			-- TRACE BACKWARD TO FORWARD
			if not tr_back.Hit then
				struct.endpos = tr_back_pos + vector_down + vector_forward
				tr_back = trace_line(struct)
			end
		end

		do -- RIGHT
			local tr_right_pos = self:GetPos() + self:GetRight() * PLATE_SIDE_LENGTH
			struct.start = tr_right_pos
			struct.endpos = tr_right_pos + vector_down
			tr_right = trace_line(struct)
		end

		do -- LEFT
			local tr_left_pos = self:GetPos() + -self:GetRight() * PLATE_SIDE_LENGTH
			struct.start = tr_left_pos
			struct.endpos = tr_left_pos + vector_down
			tr_left = trace_line(struct)
		end

		return tr_front, tr_back, tr_right, tr_left
	end

	local DAMP_FACTOR = 1.00001
	local VECTOR_UP = Vector(0, 0, 1)
	local ANGLE_VEL_MULT = 100
	local VEL_MULT = 500
	local DOWNWARD_FORCE = -600
	local MIN_VEL_FOR_SOUND = 10
	function ENT:Think()
		if not IsValid(self.Wheel) then return end

		local phys = self:GetPhysicsObject()
		local phys_wheel = self.Wheel:GetPhysicsObject()
		if not IsValid(phys) or not IsValid(phys_wheel) then return end

		-- enable back gravity for jumping, falling etc
		if not self:IsOnSurface() then
			phys:EnableGravity(true)
			phys_wheel:EnableGravity(true)
			return
		end

		do -- base related stuff
			phys:EnableGravity(false)
			local target_ang = Angle(0, 0, 0)

			if self:InWater() then
				local cur_ang = self:GetAngles()
				target_ang = Angle(0, cur_ang.yaw, cur_ang.roll)
			else
				local tr_front, tr_back, tr_right, tr_left = self:ExecuteTraces()
				if tr_front.Hit and tr_back.Hit then
					-- Rotation matrix, will work with ceilings, sky etc but not with walls -> gimbal lock
					local diff_ang = (tr_back.HitPos - tr_front.HitPos):Angle()
					if tr_right.Hit and tr_left.Hit then
						local side_diff_ang = (tr_left.HitPos - tr_right.HitPos):Angle()
						diff_ang.roll = side_diff_ang.pitch
					end

					local m = Matrix()
					m:Rotate(diff_ang)
					m:SetUp(self:GetUp())

					if self:OnWall() then
						m:SetRight(self.Wheel:GetUp())
					end

					target_ang = m:GetAngles()
				end
			end

			local ang_vel = self:ComputeAngularVelocity(phys, target_ang)
			ang_vel:Mul(20)
			ang_vel:Sub(phys:GetAngleVelocity())
			phys:AddAngleVelocity(ang_vel)
		end

		do -- wheel related stuff
			phys_wheel:EnableGravity(false)
			phys_wheel:AddVelocity(self:GetUp() * DOWNWARD_FORCE) -- stick to surface below

			if self.Forward then
				phys_wheel:AddAngleVelocity(VECTOR_UP * ANGLE_VEL_MULT)
				phys_wheel:AddVelocity(self:GetForward() * VEL_MULT)

				-- this should push harder on walls when going up or down
				if self:OnWall() then
					phys_wheel:AddVelocity(self:GetForward() * VEL_MULT / 2)
				end
			end

			if self.Backward then
				phys_wheel:AddAngleVelocity(VECTOR_UP * -ANGLE_VEL_MULT)
				phys_wheel:AddVelocity(self:GetForward() * -VEL_MULT)
			end

			if self.Right then
				phys_wheel:ApplyForceOffset(-self.Wheel:GetUp() * VEL_MULT * 1.5, self:GetPos() + self:GetForward() * PLATE_FORWARD_LENGTH)
			end

			if self.Left then
				phys_wheel:ApplyForceOffset(self.Wheel:GetUp() * VEL_MULT * 1.5, self:GetPos() + self:GetForward() * PLATE_FORWARD_LENGTH)
			end

			local going_left = self.Left and 1 or 0
			local going_right = self.Right and 1 or 0
			local going_forward = self.Forward and 1 or 0
			local going_backward = self.Backward and 1 or 0
			if (going_left - going_right) == 0 then
				local cur_ang_vel = phys_wheel:GetAngleVelocity()
				phys_wheel:AddAngleVelocity(-cur_ang_vel / 2 * DAMP_FACTOR)
			end

			if (going_forward - going_backward) == 0 then
				local cur_vel = phys_wheel:GetVelocity()
				phys_wheel:AddVelocity(-cur_vel / 2 * DAMP_FACTOR)
			end

			local final_ang_vel = phys_wheel:GetAngleVelocity()
			if math.abs(final_ang_vel.z) > MIN_VEL_FOR_SOUND then
				if not self.WheelLoop then
					self.WheelLoop = CreateSound(self,"crawler/wheel_loop.wav")
					self.WheelLoop:Play()
				end

				self.WheelLoopStopTime = nil
				self.WheelLoop:ChangePitch(20 + math.min(math.abs(final_ang_vel.z) / 200, 200))
			end

			if self.WheelLoop and math.abs(final_ang_vel.z) < MIN_VEL_FOR_SOUND then
				if not self.WheelLoopStopTime then
					self.WheelLoopStopTime = CurTime() + 0.5
				elseif self.WheelLoopStopTime >= CurTime() then
					self.WheelLoop:Stop()
					self.WheelLoop = nil
				end
			end
		end

		self:NextThink(CurTime())

		return true
	end

	function ENT:OnRemove()
		if self.WheelLoop then
			self.WheelLoop:Stop()
			self.WheelLoop = nil
		end
	end

	function ENT:GetDriver()
		return self.Seat:GetDriver()
	end

	function ENT:InWater()
		if self:WaterLevel() > 0 then return true end
		if IsValid(self.Wheel) and self.Wheel:WaterLevel() > 0 then return true end
		if IsValid(self.Seat) and self.Seat:WaterLevel() > 0 then return true end

		return false
	end

	local MIN_WALL_PITCH = 50
	function ENT:OnWall()
		return math.abs(self:GetAngles().pitch) > MIN_WALL_PITCH
	end

	function ENT:IsOnSurface()
		if self:InWater() then return true end

		local tr = util.TraceLine({
			start = self:GetPos(),
			endpos = self:GetPos() + self:GetUp() * -TRACE_LENGTH,
			filter = self.Filter,
		})

		return tr.Hit == true
	end

	local impact_sounds = {
		"physics/metal/metal_solid_impact_soft1.wav",
		"physics/metal/metal_solid_impact_soft2.wav",
		"physics/metal/metal_solid_impact_soft3.wav",
		"physics/metal/metal_solid_impact_hard1.wav",
		"physics/metal/metal_solid_impact_hard2.wav",
		"physics/metal/metal_solid_impact_hard3.wav",
		"physics/metal/metal_solid_impact_hard4.wav",
		"physics/metal/metal_solid_impact_hard5.wav",
	}
	function ENT:PhysicsCollide(data, collider)
		if not IsValid(data.HitEntity) then return end
		if data.HitEntity == self or data.HitEntity == self.Seat then
			local vel = data.OurOldVelocity:Length()
			local impact_sound = vel <= 1000 and impact_sounds[math.random(1, 3)] or impact_sounds[math.random(4, #impact_sounds)]
			self:EmitSound(impact_sound)
		end
	end
end

if CLIENT then
	language.Add("crawler", "Crawler")
end