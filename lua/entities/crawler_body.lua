AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.ClassName = "crawler_body"
ENT.Spawnable = false

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/crawler/monowheel.mdl")
		self:SetUseType(SIMPLE_USE)
		self:SetMoveType(MOVETYPE_VPHYSICS)

		-- perfect combination for the player to be able to use this enter the vehicle
		-- AND to NOT block the third person vehicle camera
		do
			self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
			self:SetCollisionBounds(Vector(-18, -20, 1), Vector(18, 35, 1))
			self:SetSolid(SOLID_BBOX)
			self:PhysicsInit(SOLID_BBOX)
		end
	end
end

if CLIENT then
	local wheel_mat = Material("models/crawler/energy_wheel")

	local max_bar_height = 256 - 100
	local max_velocity = 3000

	local gizo_cam_pos = Vector(-460, -460, 650)
	local gizmo_cam_ang = Angle(45, 45, 0)
	local boost_text_col = Color(255, 0, 0)

	function ENT:Initialize()
		local num = math.random(9999)

		self.DashboardTexture = self.DashboardTexture or GetRenderTargetEx(
			"Crawler_Dashboard_" .. self:EntIndex() .. "_" .. num,
			512,
			256,
			RT_SIZE_LITERAL,
			MATERIAL_RT_DEPTH_NONE,
			16,
			CREATERENDERTARGETFLAGS_HDR,
			IMAGE_FORMAT_DEFAULT
		)
		self.DashboardMaterial = self.DashboardMaterial or CreateMaterial(
			"Crawler_Dashboard_Material_" .. self:EntIndex() .. "_" .. num,
			"VertexLitGeneric",
			{
				["$basetexture"] = self.DashboardTexture:GetName(),
				["$model"] = 1,
				["$nodecal"] = 1,
				["$selfillum"] = 1,
				["$selfillummask"] = "dev/reflectivity_30b"
			}
		)

		self.Bike = self:GetParent()

		self.GizmoModel = self.GizmoModel or ClientsideModel("models/crawler/gizmo.mdl")
	end

	function ENT:Draw()
		self:DrawDashboard()

		render.MaterialOverrideByIndex(1, self.DashboardMaterial)
			self:DrawModel()
		render.MaterialOverrideByIndex()
	end

	function ENT:DrawDashboard()
		if not IsValid(self.Bike) then return end

		render.PushRenderTarget(self.DashboardTexture)
			cam.Start2D()
				surface.SetDrawColor(self.Bike.EnergyColor.r, self.Bike.EnergyColor.g, self.Bike.EnergyColor.b, 10)
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
		if not IsValid(self.Bike) then return end

		local vel = self.Bike:GetVelocity()

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
		if not IsValid(self.Bike) then return end

		local driver = self.Bike:GetNWEntity("Driver")
		if IsValid(driver) and driver:KeyDown(IN_SPEED) then
			boost_text_col.a = RealTime() * 5 % 1 > 0.5 and 255 or 0
			draw.DrawText("BOOST", "DermaLarge", 256 + 128, 30, boost_text_col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		if not IsValid(self.GizmoModel) then return end

		self.GizmoModel:SetAngles(self.Bike:GetAngles())

		cam.Start3D(gizo_cam_pos, gizmo_cam_ang, 3.5, 256, 30, 256, 256 - 60)
			render.SuppressEngineLighting(true)
				self.GizmoModel:DrawModel()
			render.SuppressEngineLighting(false)
		cam.End3D()
	end

	function ENT:OnRemove()
		if IsValid(self.GizmoModel) then
			self.GizmoModel:Remove()
		end
	end
end