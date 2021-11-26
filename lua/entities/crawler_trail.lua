AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.Author = "Earu"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.PrintName = "Crawler's Engine"
ENT.ClassName = "crawler_trail"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetModelScale(1)

		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:Wake()
		end

		self.Trail = NULL
	end

	function ENT:SetTrail(startwidth, endwidth, lifetime, color)
		if self.Trail:IsValid() then
			self.Trail:Remove()
		end

		local res = 1 / (startwidth + endwidth) * 0.5
		self.Trail = util.SpriteTrail(self, 0, color, true, startwidth, endwidth, lifetime, res, "trails/laser.vmt")
		self.Trail.StartWidth = startwidth
		self.Trail.EndWidth = endwidth
		self.Trail.Lifetime = lifetime
	end

	function ENT:GetTrail()
		return self.Trail
	end
end

if CLIENT then
	language.Add("crawler_trail", "Crawler's Engine")

	function ENT:Draw() end
end