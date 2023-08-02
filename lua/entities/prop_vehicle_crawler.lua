AddCSLuaFile()
local tag = "prop_vehicle_crawler"

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Author = "Earu"
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.PrintName = "Crawler"
ENT.ClassName = "prop_vehicle_crawler"
ENT.Category = "Half-Life 2"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = "models/crawler/monowheel.mdl"
ENT.Information = "Highly adaptable monowheel vehicle"
ENT.Name = "Crawler"
ENT.Class = "prop_vehicle_crawler"
ENT.AdminSpawnable = false
ENT.EnergyColor = Color(0, 255, 255)

for _, f in pairs(file.Find("sound/crawler/*", "GAME")) do
	util.PrecacheSound("sound/crawler/" .. f)
end


list.Set("Vehicles", "prop_vehicle_crawler", ENT)


function ENT:GetDriver()
	return self:GetNWEntity("Driver")
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
		if parent:GetClass() ~= tag then return false end
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
	ENT.LastComputedRollTime = 0
	ENT.CurrentRollVariation = 0
	ENT.WheelLoopStopTime = 0
	ENT.LatestVelLen = 0
	ENT.LatestVelDiff = 0
	
	local CVAR_FASTDL = CreateConVar("prop_vehicle_crawler_fastdl", "1", FCVAR_ARCHIVE, "Should clients download content for crawlers on join or not")
	
	local function add_resource_dir(dir)
		for _, f in pairs(file.Find(dir .. "/*","GAME")) do
			local path = dir .. "/" .. f
			resource.AddSingleFile(path)
		end
	end
	
	if CVAR_FASTDL:GetBool() then
		resource.AddSingleFile("materials/entities/prop_vehicle_crawler.png")
		
		add_resource_dir("sound/crawler")
		add_resource_dir("materials/models/crawler")
		add_resource_dir("models/crawler")
	end
	
	function ENT:SetupTrails()
		self.Trails = self.Trails or {}
		for i = 1, 4 do
			if IsValid(self.Trails[i]) then SafeRemoveEntity(self.Trails[i]) end
			
			self.Trails[i] = util.SpriteTrail(self, i, self.EnergyColor, true, 32, 0, 0.1, 0.015625, "trails/laser.vmt")
		end
	end
	
	function ENT:SetupSounds()
		self.Sounds = self.Sounds or {}
		self.Sounds.EngineLoop = CreateSound(self, "crawler/engine_loop.wav")
		self.Sounds.WheelLoop = CreateSound(self, "crawler/wheel_loop.wav")
	end
	
	function ENT:Initialize()
		self:SetModel("models/crawler/monowheel.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetPos(self:GetPos() + Vector(0, 0, 47))
		self:SetRenderMode( RENDERMODE_TRANSALPHA )
		self:AddFlags( FL_OBJECT )
		
		self.phys = self:GetPhysicsObject()
		if not IsValid(self.phys) then return end
		
		self.mass = self.phys:GetMass()
		self.phys:EnableMotion(true)
		self.phys:EnableDrag(false)
		self.phys:SetMass(1000)
		self.phys:Wake()
		construct.SetPhysProp(nil, self, 0, self.phys, { GravityToggle = true, Material = "metal_vehicle" })
		--self.phys:SetMaterial("metal_vehicle")
		
		if IsValid(self.Seat) then SafeRemoveEntity(self.Seat) end
		self.Seat = ents.Create("prop_vehicle_prisoner_pod")
		if not IsValid(self.Seat) then return end
		
		self.Seat:SetModel("models/nova/airboat_seat.mdl")
		self.Seat:SetMoveType( MOVETYPE_NONE )
		
		self.Seat:SetPos(self:LocalToWorld(Vector(-29, 0, -9)))
		self.Seat:SetAngles(self:LocalToWorldAngles(Angle(0, -90, 0)))
		self.Seat:SetUseType(SIMPLE_USE)
		self.Seat:Spawn()
		self.Seat:Activate()
		self.Seat:SetNoDraw(true)
		self.Seat:SetParent(self)
		self.Seat:SetVehicleClass("phx_seat3")
		self.Seat:SetKeyValue("vehiclescript","scripts/vehicles/prisoner_pod.txt")
		self.Seat:SetKeyValue("limitview", 0)
		self.Seat.Crawler = self
		
		self:SetNW2Entity("Seat", self.Seat)
		self.Seat:GetPhysicsObject():EnableDrag( false ) 
		self.Seat:GetPhysicsObject():EnableMotion( false )
		
		self:SetupTrails()
		self:SetupSounds()
		
		self:DeleteOnRemove(self.Seat)
		
		local function apply_ownership()
			local owner = self:GetCreator()
			if not IsValid(owner) then return end
			
			if self.Seat.CPPISetOwner then
				self.Seat:CPPISetOwner(owner)
			end
			
			self.Seat:SetOwner(owner)
			self.Seat:SetCreator(owner)
		end
		
		self.Forward = 0
		self.Backward = 0
		self.Left = 0
		self.Right = 0
		self.Turbo = 0
		self.WS = 0
		self.AD = 0
		self._Derivative = 0
		self._Integral = 0
		self._Cross = Vector(0, 0, 0)
		self.Cross = Vector(0, 0, 0)
		self.Prop_Gravity = -physenv.GetGravity() * engine.TickInterval()
		self.Tick_Adjust = 66.66 / (1 / engine.TickInterval())
		
		self.Filter = { self, self.Seat }
	end
	
	function ENT:ControlHandler(ply, key, pressed)
		local process_input = pressed and 1 or 0	
		
		if key == IN_FORWARD then self.Forward = process_input end
		if key == IN_BACK then self.Backward = process_input end
		if key == IN_MOVELEFT then self.Left = process_input end
		if key == IN_MOVERIGHT then self.Right = process_input end
		if key == IN_SPEED then self.Turbo = process_input * 1.5 end
		
		self.WS = self.Forward - self.Backward
		self.AD = self.Left - self.Right
	end
	
	local function handle_keys(ply, key, pressed)
		local vhy = ply:GetVehicle()
		if not IsValid(vhy) then return end
		if not IsValid(vhy.Crawler) then return end
		
		vhy.Crawler:ControlHandler(ply, key, pressed)
	end
	
	hook.Add("KeyPress", tag, function(ply, key) handle_keys(ply, key, true) end)
	hook.Add("KeyRelease", tag, function(ply, key) handle_keys(ply, key, false) end)
	
	hook.Add("PlayerEnteredVehicle", "prop_vehicle_crawler", function(ply, veh)
		local crawler = veh.Crawler
		if not IsValid(crawler) then return end

		crawler:SetNWEntity("Driver", ply)
		
		crawler.Sounds.EngineLoop:PlayEx(0, 100)
		crawler.Sounds.WheelLoop:PlayEx(0, 100)
	end)
	
	hook.Add("PlayerLeaveVehicle", "prop_vehicle_crawler", function(ply, veh)
		local crawler = veh.Crawler
		if not IsValid(crawler) then return end
		
		crawler:SetNWEntity("Driver", NULL)
		
		crawler.Forward = 0
		crawler.Backward = 0
		crawler.Left = 0
		crawler.Right = 0
		crawler.Turbo = 0
		crawler.WS = 0
		crawler.AD = 0
		
		crawler.Sounds.EngineLoop:ChangeVolume(0, 0.5)
		crawler.Sounds.WheelLoop:ChangeVolume(0, 0.5)
		timer.Simple(0.5, function()
			crawler.Sounds.EngineLoop:Stop()
			crawler.Sounds.WheelLoop:Stop()
		end)
		
	end)
	
	function ENT:Use(ply, activator)
		if ply ~= activator then return end
		if not IsValid(self.Seat) then return end
		
		ply:EnterVehicle(self.Seat)
	end
	
	--10 degree roll max
	
	local trace_line = util.TraceLine
	-- Technically we could only do two traces, but adding more fallbacks allows the bike to be more adaptable
	local TRACE_LENGTH = 200
	local PLATE_FORWARD_LENGTH = 36
	local PLATE_SIDE_LENGTH = 20
	
	local DAMP_FACTOR = 1.00001
	local VECTOR_UP = Vector(0, 0, 1)
	local ANGLE_VEL_MULT = 100
	local VEL_MULT = 300
	local DOWNWARD_FORCE = -600
	local MIN_VEL_FOR_SOUND = 500
	
	function ENT:HandleSounds(velfwd)
		local velfwd = math.abs(velfwd)
		
		self.Sounds.WheelLoop:ChangeVolume(math.min(velfwd / MIN_VEL_FOR_SOUND, 1), 0.1)
		self.Sounds.WheelLoop:ChangePitch(20 + math.min(velfwd * 0.005, 200))
		
		self.Sounds.EngineLoop:ChangeVolume(math.ease.InExpo(math.Clamp((velfwd - 500) * 0.005 , 0, 1)), 0.1)
		self.Sounds.EngineLoop:ChangePitch(100 + math.min(velfwd / 15, 130))
	end
	
	local PD_Settings = { P = 1, D = 3 }
	function ENT:CalculatePD(PD, err, minmax)
		self._Derivative = (err - self._Derivative) * PD.D
		
		local result = math.Clamp(err * PD.P + self._Derivative, -minmax, minmax)
		self._Derivative = err
		
		return result * self.Tick_Adjust
	end
	
	
	local Ride_Height = 40
	local Trace_Offsets = {
	
		Vector(48.5, 18, 0),
		Vector(-60, -18, 0),
		Vector(48.5, -18, 0),
		Vector(-60, 18, 0)
	}
	local deg2rad = math.pi / 180
	local function rotate_around_axis(this, axis, degrees) --thank you wiremod
		local ca, sa = math.cos(degrees*deg2rad), math.sin(degrees*deg2rad)
		local x,y,z = axis[1], axis[2], axis[3]
		local length = (x*x+y*y+z*z)^0.5
		x,y,z = x/length, y/length, z/length

		return Vector((ca + (x^2)*(1-ca)) * this[1] + (x*y*(1-ca) - z*sa) * this[2] + (x*z*(1-ca) + y*sa) * this[3],
				(y*x*(1-ca) + z*sa) * this[1] + (ca + (y^2)*(1-ca)) * this[2] + (y*z*(1-ca) - x*sa) * this[3],
				(z*x*(1-ca) - y*sa) * this[1] + (z*y*(1-ca) + x*sa) * this[2] + (ca + (z^2)*(1-ca)) * this[3])
	end
	
	function ENT:PhysicsUpdate(phys)
		
		self.vel_local = phys:WorldToLocalVector(self:GetVelocity()) --composite not needed as its not e2
		self:HandleSounds(self.vel_local.x)
		
		--Traces
		local Predictive_Swap = util.TraceHull({
			start = self:GetPos(),
			endpos = self:LocalToWorld(self.vel_local * 0.2),
			filter = self.Filter,
			mins = Vector(-2, -2, -2),
			maxs = Vector(2, 2, 2),
			mask = MASK_SOLID,
			collisiongroup = COLLISION_GROUP_WEAPON
		})
		local Distance_Average = 0
		local Up_Average = Vector(0, 0, 0)
		local Should_Swap = Predictive_Swap.Hit and not Predictive_Swap.HitSky
		
		--If look ahead hits terrain, don't bother with the corners
		if Should_Swap then
			Distance_Average = Predictive_Swap.Fraction * Predictive_Swap.HitPos:Distance(self:GetPos())
			Up_Average = Predictive_Swap.HitNormal
			print("swapping to terrain ", Up_Average)
			else
			local Trace_Corners = {}
			local Any_Trace_Hit = false
			
			for i, v in ipairs(Trace_Offsets) do
				Trace_Corners[i] = util.TraceHull({
					start = self:LocalToWorld(v),
					endpos = self:LocalToWorld(v + self.vel_local * 0.2 - Vector(0, 0, Ride_Height + 10)),
					filter = self.Filter,
					mins = Vector(-2, -2, -2),
					maxs = Vector(2, 2, 2),
					mask = MASK_SOLID,
					collisiongroup = COLLISION_GROUP_WEAPON
				})
				Any_Trace_Hit = Any_Trace_Hit or (Trace_Corners[i].Hit and not Trace_Corners[i].HitSky)
				Distance_Average = Distance_Average + Trace_Corners[i].Fraction
			end
			
			if not Any_Trace_Hit then 
				self._Derivative = 0
				self._Integral = 0
				return 
			end
			Distance_Average = Distance_Average  * 14.25
			--2 crossed direction normals cross product = up normal of terrain, no more jank of the 4 offset forces
			Up_Average = (Trace_Corners[3].HitPos - Trace_Corners[4].HitPos):GetNormalized():Cross((Trace_Corners[1].HitPos - Trace_Corners[2].HitPos):GetNormalized())
			
			--Calculate lean based on angular velocity
			Up_Average = rotate_around_axis(Up_Average, self:GetForward(), math.Clamp(-phys:GetAngleVelocity()[3] * 0.075, -15, 15))
		end

		--Movement Force
		local Up = Up_Average * self:CalculatePD(PD_Settings, Ride_Height - Distance_Average, self.mass)
		local MoveForce = self:GetForward() * 20 * self.WS * (1 + self.Turbo) * self.Tick_Adjust
		self.Force = (self.Prop_Gravity + Up + MoveForce - phys:GetVelocity() * 0.02) * self.mass
		
		phys:ApplyForceCenter(self.Force)
		
		--Angle Force
		self._Cross = self.Cross
		self.Cross = Up_Average:Cross(self:GetUp()) * 1000
		self._Cross =  self.Cross - self._Cross
		
		local AngVel = self:LocalToWorld(phys:GetAngleVelocity() - Vector(0, 0, self.AD * 300)) - self:GetPos()
		self.AngForce = (self.Cross + self._Cross * 10 + AngVel) * phys:GetInertia() / 28.5 * self.Tick_Adjust
		phys:ApplyTorqueCenter(-self.AngForce)
		
		self:NextThink(CurTime())
		return true
	end
	
	function ENT:OnRemove()
		for k, v in pairs(self.Sounds) do
			if not v then continue end
			
			v:Stop()
			v = nil
		end
	end
end

if not CLIENT then return end

language.Add(tag, "Crawler")
local wheel_mat = Material("models/crawler/energy_wheel")

local max_bar_height = 256 - 100
local max_velocity = 3000

local gizo_cam_pos = Vector(-460, -460, 650)
local gizmo_cam_ang = Angle(45, 45, 0)
local boost_text_col = Color(255, 0, 0)
local WHEEL_OFFSET = Vector(0, 0, 10)

function ENT:Initialize()
	self.vel_increment = 0
	
	self.Wheel = ClientsideModel("models/crawler/energy_wheel.mdl", RENDERGROUP_BOTH)
	
	self.Wheel:SetPos(self:LocalToWorld(WHEEL_OFFSET))
	self.Wheel.RenderGroup = RENDERGROUP_BOTH
	self.Wheel:SetAngles(self:LocalToWorldAngles(Angle(0, 0, 0)))
	self.Wheel:Spawn()
	self.Wheel:SetParent(self)
	
	self.Wheel:SetColor(self.EnergyColor)
	--Wheel size 50? --dude it's 47...
	
	self.DashboardTexture = self.DashboardTexture or GetRenderTargetEx(
		"Crawler_Dashboard_" .. self:EntIndex(),
		512,
		256,
		RT_SIZE_LITERAL,
		MATERIAL_RT_DEPTH_NONE,
		16,
		CREATERENDERTARGETFLAGS_HDR,
		IMAGE_FORMAT_DEFAULT
	)
	self.DashboardMaterial = self.DashboardMaterial or CreateMaterial(
		"Crawler_Dashboard_Material_" .. self:EntIndex(),
		"VertexLitGeneric",
		{
			["$basetexture"] = self.DashboardTexture:GetName(),
			["$model"] = 1,
			["$nodecal"] = 1,
			["$selfillum"] = 1,
			["$selfillummask"] = "dev/reflectivity_30b"
		}
	)
	
	self.GizmoModel = self.GizmoModel or ClientsideModel("models/crawler/gizmo.mdl")
	self.GizmoModel:SetNoDraw(true)
end

function ENT:Think()
	self.vel_local = self:WorldToLocal(self:GetPos() + self:GetVelocity())
	self.vel_increment = self.vel_increment  + self.vel_local[1] / 295.30970943744 -- number is circumference of the wheel
	
	self.Wheel:SetAngles(self:LocalToWorldAngles(Angle(self.vel_increment, 0, 0)))
end

function ENT:DrawDashboard()
	if not IsValid(self) then return end
	
	render.PushRenderTarget(self.DashboardTexture)
	cam.Start2D()
	surface.SetDrawColor(self.EnergyColor.r, self.EnergyColor.g, self.EnergyColor.b, 10)
	surface.DrawRect(0, 0, 512, 256)
	
	surface.SetMaterial(wheel_mat)
	surface.SetDrawColor(255, 255, 255)
	surface.DrawTexturedRectUV(0, 0, 512, 256, 0, 0.02, 1.0, 0.5)
	
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(10, 20, 256 - 10, 256 - 40, 1)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawOutlinedRect(10, 20, 256 - 10, 256 - 40, 3)
	
	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(256 + 10, 20, 256 - 20, 256 - 40, 1)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawOutlinedRect(256 + 10, 20, 256 - 20, 256 - 40, 3)
	
	self:DrawVelocityBars()
	self:DrawGizmo()
	cam.End2D()
	render.PopRenderTarget()
end

function ENT:DrawVelocityBars()
	local vel = self:GetVelocity()
	
	local vel_x = math.abs(vel.x)
	local vel_y = math.abs(vel.y)
	local vel_z = math.abs(vel.z)
	
	local x_height = (math.Clamp(vel_x, 0, max_velocity) / max_velocity) * -max_bar_height
	surface.SetDrawColor(HSVToColor(0, math.Clamp(vel_x, 0, max_velocity) / max_velocity, 1))
	surface.DrawRect(30, 256 - 30, 40, x_height)
	
	local y_height = (math.Clamp(vel_y, 0, max_velocity) / max_velocity) * -max_bar_height
	surface.SetDrawColor(HSVToColor(0, math.Clamp(vel_y, 0, max_velocity) / max_velocity, 1))
	surface.DrawRect(115, 256 - 30, 40, y_height)
	
	local z_height = (math.Clamp(vel_z, 0, max_velocity) / max_velocity) * -max_bar_height
	surface.SetDrawColor(HSVToColor(0, math.Clamp(vel_z, 0, max_velocity) / max_velocity, 1))
	surface.DrawRect(200, 256 - 30, 40, z_height)
	
	draw.DrawText(math.floor(vel_x), "DermaLarge", 50, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.DrawText(math.floor(vel_y), "DermaLarge", 136, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.DrawText(math.floor(vel_z), "DermaLarge", 220, 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function ENT:DrawGizmo()
	local driver = self:GetNWEntity("Driver")
	if IsValid(driver) and driver:KeyDown(IN_SPEED) then
		boost_text_col.a = RealTime() * 5 % 1 > 0.5 and 255 or 0
		draw.DrawText("BOOST", "DermaLarge", 256 + 128, 30, boost_text_col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	
	if not IsValid(self.GizmoModel) then return end
	
	self.GizmoModel:SetAngles(-self:GetAngles() - Angle(0, 45, 0))
	
	cam.Start3D(gizo_cam_pos, gizmo_cam_ang, 3.5, 256, 30, 256, 256 - 60)
	render.SuppressEngineLighting(true)
	self.GizmoModel:DrawModel()
	render.SuppressEngineLighting(false)
	cam.End3D()
end

local Trails_Offsets = {
	Vector(-43, 22, 0),
	Vector(-40, 19, 5),
	Vector(-43, -22, 0),
	Vector(-40, -19, 5)
}

local sprite_mat = Material("sprites/glow04_noz")
function ENT:DrawTranslucent()
	self:DrawDashboard()
	
	render.MaterialOverrideByIndex(1, self.DashboardMaterial)
	self:DrawModel()
	render.MaterialOverrideByIndex()
	
	local size = (self:GetVelocity():Length()) * 2 / 100
	
	render.SetMaterial(sprite_mat)
	for i = 1, 4 do
		render.DrawSprite(self:GetAttachment(i).Pos, size, size, self.EnergyColor)
	end
end

function ENT:OnRemove()
	if IsValid(self.GizmoModel) then
		self.GizmoModel:Remove()
	end
	
	if IsValid(self.GizmoModel) then
		self.GizmoModel:Remove()
	end
	
	self.Wheel:Remove()
end		