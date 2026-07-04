ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Crawler"
ENT.Name = "Crawler"
ENT.Author = "Earu"
ENT.Information = "Highly adaptable monowheel vehicle"
ENT.Category = "Earu"

ENT.Class = "prop_vehicle_crawler"
ENT.Spawnable = false
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Model = "models/crawler/monowheel.mdl"
ENT.EnergyColor = ENT.EnergyColor or Color(0, 255, 255)

list.Set("Vehicles", "prop_vehicle_crawler", ENT)
tag = "prop_vehicle_crawler"

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Steering")
    self:NetworkVar("Vector", 0, "EnergyColor")
    self:NetworkVar("Entity", 0 , "Driver")

    self:NetworkVarNotify("EnergyColor", function(_, _, _, rgb)
        self.EnergyColor.r = rgb.x
        self.EnergyColor.g = rgb.y
        self.EnergyColor.b = rgb.z

        if CLIENT then
            if not IsValid(self.Wheel) then self:SetupWheel() return end

            self.Wheel:SetColor(self.EnergyColor)
        end
        if SERVER then
            timer.Simple(0, function()
                self:UpdateTrailColors()
            end)
        end
    end)
end

properties.Add("energy_color", {
    MenuLabel = "Energy Color",
    Order = 2e9,
    MenuIcon = "icon16/color_wheel.png",
    Filter = function( self, ent, ply )
        if not IsValid(ent) then return false end
        if ent:IsPlayer() then return false end

        if ent:GetClass() ~= tag then return false end
        if not gamemode.Call("CanProperty", ply, "energy_color", ent) then return false end

        return true
    end,
    Action = function(self, ent)
        local frame = vgui.Create("DFrame")
        local rgb = ent.EnergyColor
        frame:SetSize(250, 200)
        frame:Center()
        frame:MakePopup()
        frame:SetTitle(tostring(ent))
        frame.OnClose = function()
            if not IsValid(ent) then return end

            ent.EnergyColor = rgb
            self:MsgStart()
            net.WriteEntity(ent)
            net.WriteVector(Vector(rgb.r, rgb.g, rgb.b))
            self:MsgEnd()
        end

        local color_combo = vgui.Create("DColorCombo", frame)
        color_combo:Dock(FILL)
        color_combo:SetColor(ent.EnergyColor)
        function color_combo:OnValueChanged(rgb)
            ent:SetEnergyColor(Vector(rgb.r, rgb.g, rgb.b))
        end
    end,
    Receive = function(self, length, ply)
        local ent = net.ReadEntity()
        local rgb = net.ReadVector()

        if not properties.CanBeTargeted(ent, ply) then return end
        ent:SetEnergyColor(rgb)
    end
})