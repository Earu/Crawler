include("shared.lua")
local tag = "prop_vehicle_crawler"
local Ride_Height = 33

language.Add(tag, "Crawler")
local wheel_mat = Material("models/crawler/energy_wheel")

local max_bar_height = 256 - 100
local max_velocity = 3000

local gizo_cam_pos = Vector(-460, -460, 650)
local gizmo_cam_ang = Angle(45, 45, 0)
local boost_text_col = Color(255, 0, 0)
local WHEEL_OFFSET = Vector(0, 0, 10)

hook.Add("CalcVehicleView", tag, function(veh, ply, view)
	local crawler = veh:GetParent()

	if not IsValid(crawler) then return end
	if crawler:GetClass() ~= tag then return end
	if not veh:GetThirdPersonMode() then return end

	local tr = util.TraceHull( {
		start = view.origin,
		endpos = view.origin - view.angles:Forward() * (50 + veh:GetCameraDistance() * 50),
		filter = {crawler, veh, ply},
		mins = Vector(-4, -4, -4),
		maxs = Vector(4, 4, 4),
	} )

	view.drawviewer = true
	view.origin = tr.HitPos
	return view
end)

function ENT:SetupWheel()
	self.Wheel = ClientsideModel("models/crawler/energy_wheel.mdl", RENDERGROUP_BOTH)
	self.Wheel:SetPos(self:LocalToWorld(WHEEL_OFFSET))
    self.Wheel:SetAngles(self:LocalToWorldAngles(Angle(0, 0, 0)))
    self.Wheel:SetColor(self.EnergyColor)
	self.Wheel.RenderGroup = RENDERGROUP_BOTH
    self.Wheel:SetParent(self)
	self.Wheel:Spawn()
end

function ENT:Initialize()
	self.vel_increment = 0
	self.steering_wheel_angle = 0

	self:SetupWheel()

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

local Ride_Height_Visual = Ride_Height + 11
function ENT:Think()
	if IsValid(self.Wheel) then
		--Wheel spin
		self.vel_local = self:WorldToLocal(self:GetPos() + self:GetVelocity() * 180 * FrameTime())
		self.vel_increment = self.vel_increment  + (self.vel_local[1] / 295.30970943744) --circumference of the wheel
		self.Wheel:SetAngles(self:LocalToWorldAngles(Angle(self.vel_increment, 0, 0)))

		--Wheel suspension
		local Terrain_Distance = util.TraceHull({
			start = self:LocalToWorld(WHEEL_OFFSET),
			endpos = self:LocalToWorld(WHEEL_OFFSET - Vector(0, 0, Ride_Height_Visual)),
			filter = self,
			mins = Vector(-2, -2, -2),
			maxs = Vector(2, 2, 2),
			mask = MASK_SOLID,
			collisiongroup = COLLISION_GROUP_WEAPON
		})
		self.Wheel:SetPos(self:LocalToWorld(WHEEL_OFFSET + Vector(0, 0, Ride_Height_Visual- Terrain_Distance.Fraction * Ride_Height_Visual)))
	else
		self:SetupWheel()
	end

	--Steering Wheel
	local AD = self:GetSteering()
	self.steering_wheel_angle = self.steering_wheel_angle + math.Clamp((AD * 20 - self.steering_wheel_angle) *0.035, -2, 2) * 150 * FrameTime()
	self:ManipulateBoneAngles(1, Angle(self.steering_wheel_angle, 0, 0), false)
	if IsValid(self:GetDriver()) then
		self:GetDriver():SetPoseParameter("vehicle_steer", -self.steering_wheel_angle / 25)
	end
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

	self.GizmoModel:SetAngles(-self:LocalToWorldAngles(Angle(0, 45, 0)))

	cam.Start3D(gizo_cam_pos, gizmo_cam_ang, 3.5, 256, 30, 256, 256 - 60)
	render.SuppressEngineLighting(true)
	self.GizmoModel:DrawModel()
	render.SuppressEngineLighting(false)
	cam.End3D()
end

local sprite_mat = Material("sprites/glow04_noz")
function ENT:DrawTranslucent()
	self:DrawDashboard()

	render.MaterialOverrideByIndex(1, self.DashboardMaterial)
	self:DrawModel()
	render.MaterialOverrideByIndex()

	local size = (self:GetVelocity():Length()) * 2 / 100

	render.SetMaterial(sprite_mat)
	for i = 1, 4 do
		local attachment = self:GetAttachment(i)
		if not attachment then continue end
		render.DrawSprite(attachment.Pos, size, size, self.EnergyColor)
	end
end

function ENT:OnRemove()
	if IsValid(self.GizmoModel) then
		self.GizmoModel:Remove()
	end

	if IsValid(self.Wheel) then
		self.Wheel:Remove()
	end
end