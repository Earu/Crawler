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
		if parent:GetClass() ~= "crawler" then return false end
		if not gamemode.Call("CanProperty", ply, "energy_color", parent) then return false end

		return true
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
})



if SERVER then
	ENT.Forward = false
	ENT.Backward = false
	ENT.Left = false
	ENT.Right = false
	ENT.Turbo = false
	ENT.Drop = false
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
		self.Trails = self.Trails or {}
		
		for i = 1, 4 do
			if IsValid(self.Trails[i]) then SafeRemoveEntity(self.Trails[i]) end
			
			self.Trails[i] = util.SpriteTrail(self.BikeModel, i, self.EnergyColor, true, 32, 0, 0.1, 0.015625, "trails/laser.vmt")
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
		self.Seat.Crawler = self

		self.BikeModel = ents.Create("crawler_body")
		self.BikeModel:SetPos(self:GetPos())
		self.BikeModel:SetAngles(self:GetAngles())
		self.BikeModel:SetParent(self)
		self.BikeModel:Spawn()
		self.BikeModel.Crawler = self

		local bike_phys = self.BikeModel:GetPhysicsObject()
		if IsValid(bike_phys) then
			bike_phys:SetMass(1)
			bike_phys:SetMaterial("gmod_silent")
			--bike_phys:AddGameFlag(FVPHYSICS_NO_PLAYER_PICKUP)
		end

		self:SetupTrails()

		local function apply_ownership()
			local owner = self:GetCreator()
			if not IsValid(owner) then return end

			for _, ent in ipairs({ self.BikeModel, self.Seat }) do
				if not IsValid(ent) then continue end

				if ent.CPPISetOwner then
					ent:CPPISetOwner(owner)
				end

				ent:SetOwner(owner)
				ent:SetCreator(owner)
			end
		end

		self.Forward = 0
		self.Backward = 0
		self.Left = 0
		self.Right = 0
		self.Turbo = 0
		self.Filter = { self, self.Seat, self.BikeModel }
	end

	function ENT:ControlHandler(ply, key, pressed)
		if ply ~= self:GetDriver() then return end
		
		do
			 local process_input = pressed and 1 or 0
			print(process_input)
			return 
		end
		
		if key == IN_FORWARD then self.Forward = process_input end
		if key == IN_BACK then self.Backward = process_input end
		if key == IN_MOVELEFT then self.Left =process_input end
		if key == IN_MOVERIGHT then self.Right = process_input end
		if key == IN_SPEED then self.Turbo = process_input end
		
		self.WS = self.Forward - self.Backward
		self.AD = self.Left - self.Right
		print(WS)
		print(AD)
	end

	local function handle_keys(ply, key, pressed)
		if not ply:InVehicle() then return end

		local veh = ply:GetVehicle()
		if not IsValid(veh.Crawler) then return end

		veh.Crawler:ControlHandler(ply, key, pressed)
	end

	hook.Add("KeyPress", "crawler", handle_keys)
	hook.Add("KeyRelease", "crawler", handle_keys)

	hook.Add("PlayerEnteredVehicle", "crawler", function(ply, veh)
		if not IsValid(veh.Crawler) then return end

		local crawler = veh.Crawler
		table.insert(crawler.Filter, ply)
		crawler:SetNWEntity("Driver", ply)

		crawler.EngineLoop = CreateSound(crawler, "crawler/engine_loop.wav")
		crawler.EngineLoop:ChangeVolume(10)
		crawler.EngineLoop:ChangePitch(180)
		crawler.EngineLoop:Play()
	end)

	hook.Add("PlayerLeaveVehicle", "crawler", function(ply, veh)
		if not IsValid(veh.Crawler) then return end

		local crawler = veh.Crawler
		table.remove(crawler.Filter, #crawler.Filter)
		crawler:SetNWEntity("Driver", NULL)

		crawler.Forward = 0
		crawler.Backward = 0
		crawler.Left = 0
		crawler.Right = 0
		crawler.Turbo = 0

		timer.Simple(0.1, function()
			if not crawler:IsValid() or not ply:IsValid() then return end
			ply:ExitVehicle()
			ply:SetPos(crawler:FindSpace(ply))
			ply:SetEyeAngles((crawler:GetPos() + crawler:GetForward() * 400 - ply:EyePos()):Angle())

			if crawler.EngineLoop then
				crawler.EngineLoop:Stop()
				crawler.EngineLoop = nil
			end
		end)
	end)

	function ENT:Use(ply, activator)
		if ply ~= activator then return end
		if not IsValid(self.Seat) then return end
		
		ply:EnterVehicle(self.Seat)
	end

	hook.Add("GravGunPickupAllowed", "crawler", function(_, ent)
		if ent:GetClass() == "crawler" or IsValid(ent.Crawler) then return false end
	end)

	hook.Add("EntityEmitSound", "crawler", function(data)
		if IsValid(data.Entity) and IsValid(data.Entity.Crawler) and data.Entity.Crawler.Wheel == data.Entity then return false end
	end)

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
	local ROLL_VARIATION = 1
	function ENT:ComputeTurningRoll()
		local now = CurTime()
		local delta = now - self.LastComputedRollTime

		if not self:InWater() then
			if (self.Right and self.Left) or (not self.Right and not self.Left) then
				if self.CurrentRollVariation > 0 then
					self.CurrentRollVariation = math.max(self.CurrentRollVariation - (ROLL_VARIATION / delta), 0)
				elseif self.CurrentRollVariation < 0 then
					self.CurrentRollVariation = math.min(self.CurrentRollVariation + (ROLL_VARIATION / delta), 0)
				else
					self.CurrentRollVariation = 0
				end
			else
				if self.Right then
					self.CurrentRollVariation = math.min(self.CurrentRollVariation + (ROLL_VARIATION / delta), MAX_ROLL_VARIATION)
				end

				if self.Left then
					self.CurrentRollVariation = math.max(self.CurrentRollVariation - (ROLL_VARIATION / delta), -MAX_ROLL_VARIATION)
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

		-- in the air or on walls, prevents jittering
		if not self:IsOnWall() or not self:IsOnSurface() then
			ang_vel.x = ang_vel.x + roll_vel + self:ComputeTurningRoll()
		end

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
	local VEL_MULT = 300
	local DOWNWARD_FORCE = -600
	local MIN_VEL_FOR_SOUND = 10
	function ENT:Think()
		local phys = self:GetPhysicsObject()
		if not IsValid(phys) then return end
		
		self.vel_local = phys:WorldToLocalVector(self:GetVelocity())
		
		--IOU hover code
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
	function ENT:IsOnWall()
		local cur_ang = self:GetAngles()
		local pitch,roll = math.abs(cur_ang.pitch), math.abs(cur_ang.roll)
		if pitch > MIN_WALL_PITCH then return true end
		if roll > 85 and roll < 115 then return true end

		return false
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
		self.Wheel = ClientsideModel("models/crawler/energy_wheel.mdl", RENDERGROUP_TRANSLUCENT)

		self.Wheel:SetPos(self:LocalToWorld(WHEEL_OFFSET))
		self.Wheel.RenderGroup = RENDERGROUP_BOTH
		self.Wheel:SetAngles(self:LocalToWorldAngles(WHEEL_ANGLE_OFFSET))
		self.Wheel:Spawn()
		self.Wheel:SetParent(self)
		
		self.Wheel:SetColor(self.EnergyColor)
		
		--Wheel size 50?
	end

	local Trails_Offsets = {
		Vector(-43, 22, 0),
		Vector(-40, 19, 5),
		Vector(-43, -22, 0),
		Vector(-40, -19, 5)
	}

	local sprite_mat = Material("sprites/glow04_noz")
	function ENT:Draw()
		local size = (self:GetVelocity():Length()) * 2 / 100

		render.SetMaterial(sprite_mat)
		for _, v in ipairs(Trails_Offsets) do
			render.DrawSprite(self:LocalToWorld(v), size, size, self.EnergyColor)
		end
	end

	local DRAW_WHEEL_OFFSET = 3
	function ENT:Think()
		self.vel_local = self:WorldToLocal(self:GetPos() + self:GetVelocity())
		
	self.Wheel:SetAngles(self:LocalToWorldAngles(Angle(CurTime() * 2, 0, 0)))
	end
	
	function ENT:OnRemove()
		self.Wheel:Remove()
	end
end