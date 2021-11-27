AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Author = "Earu"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.PrintName = "Crawler"
ENT.ClassName = "crawler"
ENT.Category = "Half-Life 2"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = "models/crawler/monowheel.mdl"
ENT.Information = "Highly adaptable monowheel vehicle"
ENT.Name = "Crawler"
ENT.Class = "crawler"
ENT.AdminSpawnable = false
ENT.EnergyColor = Color(0, 255, 255)

for _, f in pairs(file.Find("sound/crawler/*", "GAME")) do
	util.PrecacheSound("sound/crawler/" .. f)
end

list.Set("Vehicles", "crawler", ENT)
local WHEEL_OFFSET = Vector(0, 0, 10)
local WHEEL_ANGLE_OFFSET = Angle(90, 90, 0)

function ENT:GetDriver()
	return self:GetNWEntity("Driver", NULL)
end

properties.Add("energy_color", {
	MenuLabel = "Energy Color",
	Order = 2e9,
	MenuIcon = "icon16/color_wheel.png",
	Filter = function( self, ent, ply )
		if not IsValid(ent) then return false end
		if ent:IsPlayer() then return false end

		local parent = ent:GetParent()
		if not IsValid(parent) then return false end
		return parent:GetClass() == "crawler"
	end,
	Action = function(self, ent)
		local parent = ent:GetParent()
		local col = parent.EnergyColor

		local frame = vgui.Create("DFrame")
		frame:SetSize(250, 200)
		frame:Center()
		frame:MakePopup()
		frame:SetTitle(tostring(parent))
		frame.OnClose = function()
			if not IsValid(ent) then return end

			parent.EnergyColor = col
			self:MsgStart()
				net.WriteEntity(ent)
				net.WriteTable(col)
			self:MsgEnd()
		end

		local color_combo = vgui.Create("DColorCombo", frame)
		color_combo:Dock(FILL)
		color_combo:SetColor(col)
		function color_combo:OnValueChanged(c)
			col = Color(c.r, c.g, c.b, c.a)
		end
	end,
	Receive = function(self, length, ply)
		local ent = net.ReadEntity()
		local col = net.ReadTable()

		if not properties.CanBeTargeted(ent, ply) then return end
		if not self:Filter(ent, ply) then return end

		local parent = ent:GetParent()
		parent.EnergyColor = col
		parent.Wheel:SetColor(col)
		parent:SetupTrails()
	end
} )

if SERVER then
	ENT.Forward = false
	ENT.Backward = false
	ENT.Left = false
	ENT.Right = false
	ENT.Turbo = false
	ENT.LastComputedRollTime = 0
	ENT.CurrentRollVariation = 0
	ENT.WheelLoopStopTime = 0
	ENT.LatestVelLen = 0
	ENT.LatestVelDiff = 0

	local CVAR_FASTDL = CreateConVar("crawler_fastdl", "1", FCVAR_ARCHIVE, "Should clients download content for crawlers on join or not")

	local function add_resource_dir(dir)
		for _, f in pairs(file.Find(dir .. "/*","GAME")) do
			local path = dir .. "/" .. f
			resource.AddSingleFile(path)
		end
	end

	if CVAR_FASTDL:GetBool() then
		resource.AddSingleFile("materials/entities/crawler.png")

		add_resource_dir("sound/crawler")
		add_resource_dir("materials/models/crawler")
		add_resource_dir("models/crawler")
	end

	function ENT:SetupTrails()
		if self.Trails and #self.Trails > 0 then
			for _, trail in ipairs(self.Trails) do
				SafeRemoveEntity(trail)
			end
		end

		self.Trails = {}
		local pos = self:GetPos()
		local trail_offsets = {
			pos + -self:GetForward() * 43 + self:GetRight() * 22,
			pos + -self:GetForward() * 40 + self:GetRight() * 19 + self:GetUp() * 5,
			pos + -self:GetForward() * 45 + -self:GetRight() * 22,
			pos + -self:GetForward() * 43 + -self:GetRight() * 19 + self:GetUp() * 5
		}

		for _, offset in ipairs(trail_offsets) do
			local trail = ents.Create("crawler_trail")
			trail:SetPos(offset)
			trail:SetParent(self)
			trail:Spawn()
			trail:SetTrail(32, 0, 0.1, self.EnergyColor)

			table.insert(self.Trails, trail)
		end
	end

	function ENT:Initialize()
		self:SetModel("models/crawler/base.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetPos(self:GetPos() + Vector(0, 0, 40))

		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:SetMass(24)
			phys:SetMaterial("gmod_silent")
			phys:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
			phys:SetBuoyancyRatio(1)
			phys:Wake()
		end

		self.Seat = ents.Create("prop_vehicle_prisoner_pod")
		self.Seat:SetModel("models/nova/airboat_seat.mdl")
		self.Seat:SetPos(self:GetPos() + self:GetForward() * -29 + Vector(0, 0, -9))
		self.Seat:SetAngles(self:GetAngles() - Angle(0, 90, 0))
		self.Seat:SetUseType(SIMPLE_USE)
		self.Seat:SetParent(self)
		self.Seat:Spawn()
		self.Seat:SetNoDraw(true)
		self.Seat:SetVehicleClass("phx_seat3")

		self.BikeModel = ents.Create("crawler_body")
		self.BikeModel:SetPos(self:GetPos())
		self.BikeModel:SetAngles(self:GetAngles())
		self.BikeModel:SetParent(self)
		self.BikeModel:Spawn()

		local bike_phys = self.BikeModel:GetPhysicsObject()
		if IsValid(bike_phys) then
			bike_phys:SetMass(1)
			bike_phys:SetMaterial("gmod_silent")
			--bike_phys:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
		end

		self.Wheel = ents.Create("prop_physics")
		self.Wheel:SetModel("models/crawler/energy_wheel.mdl")
		--self.Wheel:SetMaterial("models/props_combine/portalball001_sheet")
		self.Wheel:SetPos(self:GetPos() + WHEEL_OFFSET)
		self.Wheel:SetAngles(self:GetAngles() + WHEEL_ANGLE_OFFSET)
		self.Wheel:Spawn()
		self.Wheel:SetColor(self.EnergyColor)
		self:SetNWEntity("Wheel", self.Wheel)

		local old_bounds = self.Wheel:OBBMaxs()
		self.Wheel:PhysicsInitSphere(50)
		self.Wheel:SetCollisionBounds(-old_bounds, old_bounds)
		self.Wheel:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		self:DeleteOnRemove(self.Wheel)

		local phys_wheel = self.Wheel:GetPhysicsObject()
		if IsValid(phys_wheel) then
			phys_wheel:SetMass(1)
			phys_wheel:SetMaterial("gmod_silent")
			phys_wheel:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
			phys_wheel:Wake()
		end

		self:SetupTrails()

		local function apply_ownership()
			local owner = self.CPPIGetOwner and self:CPPIGetOwner() or self:GetOwner()
			if not IsValid(owner) then owner = self:GetCreator() end
			if not IsValid(owner) then return end

			local bike_ents = { self.Wheel, self.BikeModel, self.Seat }
			for _, ent in ipairs(bike_ents) do
				if not IsValid(ent) then continue end

				if ent.CPPISetOwner then
					ent:CPPISetOwner(owner)
				end

				ent:SetOwner(owner)
				ent:SetCreator(owner)
			end
		end

		-- this is necessary because if its done too early it crashes the game
		-- reason being that the spawnmenu, and some other entity spawning code set the pos
		-- of the entity after spawning it which causes the constraint to literreally shit itself
		timer.Simple(0.1, function()
			if not IsValid(self) then return end
			if not IsValid(self.Wheel) then return end

			apply_ownership()

			self.Wheel:SetPos(self:GetPos() + WHEEL_OFFSET)
			self.Wheel:SetAngles(self:GetAngles() + WHEEL_ANGLE_OFFSET)
			constraint.Axis(self.Wheel, self, 0, 0, Vector(0, 0, 1), WHEEL_OFFSET, 0, 0, 0, 1)
		end)

		self.Filter = { self, self.Seat, self.Wheel, self.BikeModel }

		local function key_handler(ply, key, pressed)
			if ply ~= self:GetDriver() then return end

			if key == IN_FORWARD then self.Forward = pressed end
			if key == IN_BACK then self.Backward = pressed end
			if key == IN_MOVELEFT then self.Left = pressed end
			if key == IN_MOVERIGHT then self.Right = pressed end
			if key == IN_SPEED then self.Turbo = pressed end
		end

		hook.Add("KeyPress", self, function(_, ply, key) key_handler(ply, key, true) end)
		hook.Add("KeyRelease", self, function(_, ply, key) key_handler(ply, key, false) end)

		hook.Add("PlayerEnteredVehicle", self, function(_, ply, veh)
			if veh ~= self.Seat then return end
			table.insert(self.Filter, ply)
			self:SetNWEntity("Driver", ply)

			self.EngineLoop = CreateSound(self, "crawler/engine_loop.wav")
			self.EngineLoop:ChangeVolume(10)
			self.EngineLoop:ChangePitch(180)
			self.EngineLoop:Play()
		end)

		hook.Add("PlayerLeaveVehicle", self, function(_, ply, veh)
			if veh ~= self.Seat then return end

			table.remove(self.Filter, #self.Filter)
			self:SetNWEntity("Driver", NULL)

			self.Forward = false
			self.Backward = false
			self.Left = false
			self.Right = false
			self.Turbo = false

			timer.Simple(0.1, function()
				if not self:IsValid() or not ply:IsValid() then return end
				ply:ExitVehicle()
				ply:SetPos(self:FindSpace(ply))
				ply:SetEyeAngles((self:GetPos() + self:GetForward() * 400 - ply:EyePos()):Angle())

				if self.EngineLoop then
					self.EngineLoop:Stop()
					self.EngineLoop = nil
				end
			end)
		end)

		hook.Add("PlayerUse", self, function(_, ply, ent)
			if ent == self.BikeModel or ent == self.Wheel or ent == self and IsValid(self.Seat) and not ply:InVehicle() then
				ply:EnterVehicle(self.Seat)
			end
		end)

		hook.Add("EntityEmitSound", self, function(_, data)
			if data.Entity == self.Wheel then return false end
		end)

		hook.Add("GravGunPickupAllowed", self, function(_, ent)
			if ent == self or ent == self.Wheel or ent == self.Seat or ent == self.BikeModel then return false end
		end)
	end

	function ENT:IsFreeSpace(vec, ply)
		local maxs = ply:OBBMaxs()
		local tr = util.TraceHull({
			start = vec,
			endpos = vec + Vector(0, 0, maxs.z or 60),
			filter = self.Filter,
			mins = Vector(-maxs.y, -maxs.y, 0),
			maxs = Vector(maxs.y, maxs.y, 1)
		})

		return not tr.Hit
	end

	function ENT:FindSpace(ply)
		local pos, maxs = self:GetPos(), ply:OBBMaxs()
		local left = pos + self:GetRight() * -60
		local right = pos + self:GetRight() * 60

		if self:IsFreeSpace(left, ply) then
			return left
		elseif self:IsFreeSpace(right, ply) then
			return right
		else
			return pos + Vector(0, 0, maxs.z)
		end
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
		local struct = { filter = self.Filter, }

		do -- FRONT
			local tr_front_pos = self:GetPos() + self:GetForward() * PLATE_FORWARD_LENGTH

			-- TRACE FORWARD TO FURTHER FORWARD
			struct.start = tr_front_pos
			struct.endpos = tr_front_pos + vector_down + vector_forward
			tr_front = trace_line(struct)

			-- TRACE FORWARD TO BELOW
			if not tr_front.Hit or tr_front.HitSky then
				struct.endpos = tr_front_pos + vector_down
				tr_front = trace_line(struct)
			end

			-- TRACE FORWARD TO BACKWARD
			if not tr_front.Hit or tr_front.HitSky then
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
			if not tr_back.Hit or tr_back.HitSky then
				struct.endpos = tr_back_pos + vector_down
				tr_back = trace_line(struct)
			end

			-- TRACE BACKWARD TO FORWARD
			if not tr_back.Hit or tr_back.HitSky then
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
	local VEL_MULT = 400
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
			phys:SetMass(500)
			phys_wheel:EnableGravity(true)

			-- this stabilizes the vehicle when jumping or falling, preventing the vomit inducing rotations
			local ang = self:GetAngles()
			ang.pitch = self:GetForward():Angle().pitch

			local ang_vel = self:ComputeAngularVelocity(phys, ang)
			ang_vel:Mul(20)
			ang_vel:Sub(phys:GetAngleVelocity())
			phys:AddAngleVelocity(ang_vel)
			return
		end

		do -- base related stuff
			phys:EnableGravity(false)
			phys:SetMass(24)
			local target_ang = Angle(0, 0, 0)

			if self:InWater() then
				local cur_ang = self:GetAngles()
				local tr_front, tr_back = self:ExecuteTraces()
				cur_ang.pitch = 0
				if (tr_front.Hit and not tr_front.HitSky) and (tr_back.Hit and not tr_back.HitSky) then
					cur_ang.pitch = (tr_front.HitPos - tr_back.HitPos):Angle().pitch
				end

				cur_ang.roll = 0
				target_ang = cur_ang
			else
				local tr_front, tr_back, tr_right, tr_left = self:ExecuteTraces()
				if (tr_front.Hit and not tr_front.HitSky) and (tr_back.Hit and not tr_back.HitSky) then
					-- Rotation matrix, will work with ceilings, sky etc but not with walls -> gimbal lock
					local diff_ang = (tr_back.HitPos - tr_front.HitPos):Angle()
					if (tr_right.Hit and not tr_right.HitSky) and (tr_left.Hit and not tr_left.HitSky) then
						local side_diff_ang = (tr_left.HitPos - tr_right.HitPos):Angle()
						diff_ang.roll = side_diff_ang.pitch
					end

					local m = Matrix()
					m:Rotate(diff_ang)

					if self:OnWall() then
						m:SetRight(self.Wheel:GetUp())
						m:SetForward(-self:GetForward()) -- this makes it less shaky when going up and down
					end

					m:SetUp(self:GetUp())
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

			local final_linear_vel_mult = VEL_MULT
			if self.Turbo then final_linear_vel_mult = VEL_MULT + 200 end -- add extra velocity for turbo

			if self.Forward then
				phys_wheel:AddAngleVelocity(VECTOR_UP * ANGLE_VEL_MULT)
				phys_wheel:AddVelocity(self:GetForward() * final_linear_vel_mult)

				-- this should push harder on walls when going up or down
				if self:OnWall() then
					phys_wheel:AddVelocity(self:GetForward() * final_linear_vel_mult * 0.8)
				end
			end

			if self.Backward then
				phys_wheel:AddAngleVelocity(VECTOR_UP * -ANGLE_VEL_MULT)
				phys_wheel:AddVelocity(self:GetForward() * -final_linear_vel_mult)
			end

			if self.Right then
				phys_wheel:ApplyForceOffset(-self.Wheel:GetUp() * VEL_MULT * 1.5, self:GetPos() + self:GetForward() * PLATE_FORWARD_LENGTH)
			end

			if self.Left then
				phys_wheel:ApplyForceOffset(self.Wheel:GetUp() * VEL_MULT * 1.5, self:GetPos() + self:GetForward() * PLATE_FORWARD_LENGTH)
			end

			local going_left = self.Left and 1 or 0
			local going_right = self.Right and 1 or 0
			if (going_left - going_right) == 0 then
				local cur_ang_vel = phys_wheel:GetAngleVelocity()
				phys_wheel:AddAngleVelocity(-cur_ang_vel / 2 * DAMP_FACTOR)
			end

			local going_forward = self.Forward and 1 or 0
			local going_backward = self.Backward and 1 or 0
			if (going_forward - going_backward) == 0 then
				local cur_vel = phys_wheel:GetVelocity()
				phys_wheel:AddVelocity(-cur_vel / 2 * DAMP_FACTOR)
			end

			self:ProcessSounds(phys_wheel)
		end

		self:NextThink(CurTime())

		return true
	end

	function ENT:ProcessSounds(phys_wheel)
		local final_ang_vel = phys_wheel:GetAngleVelocity()
		if math.abs(final_ang_vel.z) > MIN_VEL_FOR_SOUND then
			if not self.WheelLoop then
				self.WheelLoop = CreateSound(self, "crawler/wheel_loop.wav")
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

		local len = phys_wheel:GetVelocity():Length()
		if self.EngineLoop then
			self.EngineLoop:ChangePitch(100 + math.min(len / 20, 100))
			self.EngineLoop:ChangeVolume(0.1 + math.max((len - 300) / 250 / 10, 0), 0)
		end
	end

	function ENT:OnRemove()
		if self.WheelLoop then
			self.WheelLoop:Stop()
			self.WheelLoop = nil
		end

		if self.EngineLoop then
			self.EngineLoop:Stop()
			self.EngineLoop = nil
		end
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

		return tr.Hit and not tr.HitSky
	end
end

if CLIENT then
	language.Add("crawler", "Crawler")

	function ENT:Initialize()
	end

	local sprite_mat = Material("sprites/glow04_noz")
	function ENT:Draw()
		local pos = self:GetPos()
		local size = (self:GetVelocity():Length()) * 2 / 100

		render.SetMaterial(sprite_mat)
		render.DrawSprite(pos + -self:GetForward() * 43 + self:GetRight() * 22, size, size, self.EnergyColor)
		render.DrawSprite(pos + -self:GetForward() * 40 + self:GetRight() * 19 + self:GetUp() * 5, size, size, self.EnergyColor)

		render.DrawSprite(pos + -self:GetForward() * 45 + -self:GetRight() * 22, size, size, self.EnergyColor)
		render.DrawSprite(pos + -self:GetForward() * 43 + -self:GetRight() * 19 + self:GetUp() * 5, size, size, self.EnergyColor)
	end

	local DRAW_WHEEL_OFFSET = 3
	function ENT:Think()
		local wheel = self:GetNWEntity("Wheel")
		if not IsValid(wheel) then return end

		-- this makes the wheel way more stable looking
		wheel:SetRenderOrigin(self:GetPos() + self:GetUp() * (WHEEL_OFFSET.z + DRAW_WHEEL_OFFSET))
	end
end