AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local CVAR_FASTDL = CreateConVar("prop_vehicle_crawler_fastdl", "1", FCVAR_ARCHIVE, "Should clients download content for crawlers on join or not")
local Ride_Height = 33
local tag = "prop_vehicle_crawler"

--FastDL
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
        if CPPI then
            self.Trails[i]:CPPISetOwner(self:GetCreator())
            self.Trails[i]:SetOwner(self:GetCreator())
        end
    end
end

function ENT:UpdateTrailColors()
    for _, v in ipairs(self.Trails) do
        if not IsValid(v) then self.SetupTrails() break end

        v:Input("Color", nil, nil, string.format("%i %i %i", self.EnergyColor.r, self.EnergyColor.g, self.EnergyColor.b))
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
    self.phys:SetMass(1000)
    self.phys:SetMaterial("metalvehicle")
    self.phys:Wake()

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
    self.Gravity =  -physenv.GetGravity() * engine.TickInterval()
    self.Tick_Adjust = 66 * engine.TickInterval()

    self:DeleteOnRemove(self.Seat)

    local owner = self:GetCreator()
        if IsValid(owner) then

        if CPPI then
            self.Seat:CPPISetOwner(owner)
        end

        self.Seat:SetOwner(owner)
        self.Seat:SetCreator(owner)
    end

    self:SetupTrails()
    self:SetupSounds()

    self.Forward = 0
    self.Backward = 0
    self.Left = 0
    self.Right = 0
    self.Turbo = 0
    self.WS = 0
    self.AD = 0
    self._Derivative = 0
    self._Cross = Vector(0, 0, 0)
    self.Cross = Vector(0, 0, 0)

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
    self:SetSteering(self.AD)
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

    crawler:SetDriver(ply)

    crawler.Sounds.EngineLoop:PlayEx(0, 100)
    crawler.Sounds.WheelLoop:PlayEx(0, 100)
end)

hook.Add("PlayerLeaveVehicle", "prop_vehicle_crawler", function(ply, veh)
    local crawler = veh.Crawler
    if not IsValid(crawler) then return end

    crawler:SetDriver(NULL)

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
        if not IsValid(crawler) then return end

        crawler.Sounds.EngineLoop:Stop()
        crawler.Sounds.WheelLoop:Stop()
    end)

end)

function ENT:Use(ply, activator)
    if ply ~= activator then return end
    if not IsValid(self.Seat) then return end

    ply:EnterVehicle(self.Seat)
end

local MIN_VEL_FOR_SOUND = 500
function ENT:HandleSounds(velfwd)
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

local Trace_Offsets = {
    Vector(50, 20, 0),
    Vector(50, -20, 0),
    Vector(-60, -20, 0),
    Vector(-60, 20, 0),
    Vector(0, 0, 0)
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

local Ride_Height_Functional = Ride_Height + 30
function ENT:PhysicsUpdate(phys)
    self.vel_local = phys:WorldToLocalVector(self:GetVelocity()) --composite not needed as its not e2
    local velfwd = math.abs(self.vel_local.x)

    self:HandleSounds(velfwd)

    local mass = phys:GetMass()
    local Distance_Average = 0
    local Up_Average = Vector(0, 0, 0)

    --5 Traces, 4 in the corners, 1 in the middle
    local tr_corner = {}
    local Any_Trace_Hit = false
    for i, v in ipairs(Trace_Offsets) do
        tr_corner[i] = util.TraceHull({
            start = self:LocalToWorld(v),
            endpos = self:LocalToWorld(v + self.vel_local * 0.2 - Vector(0, 0, Ride_Height_Functional)),
            filter = self.Filter,
            mins = Vector(-3, -3, -3),
            maxs = Vector(3, 3, 3),
            mask = MASK_SOLID,
            collisiongroup = COLLISION_GROUP_WEAPON
        })
        if tr_corner[i].HitSky then
            Distance_Average = Distance_Average + 1
            tr_corner[i].HitPos = self:LocalToWorld(v + self.vel_local * 0.2 - Vector(0, 0, Ride_Height_Functional))
            continue
        end
        Any_Trace_Hit = Any_Trace_Hit or (tr_corner[i].Hit and not tr_corner[i].HitSky)
        Distance_Average = Distance_Average + tr_corner[i].Fraction
    end

    if not Any_Trace_Hit then return end

    --Get 4 cross products
    local middle_pos = tr_corner[5].HitPos
    local normal1 = -(tr_corner[1].HitPos - middle_pos):GetNormalized():Cross((tr_corner[2].HitPos - middle_pos):GetNormalized())
    local normal2 = -(tr_corner[2].HitPos - middle_pos):GetNormalized():Cross((tr_corner[3].HitPos - middle_pos):GetNormalized())
    local normal3 = -(tr_corner[3].HitPos - middle_pos):GetNormalized():Cross((tr_corner[4].HitPos - middle_pos):GetNormalized())
    local normal4 = -(tr_corner[4].HitPos - middle_pos):GetNormalized():Cross((tr_corner[1].HitPos - middle_pos):GetNormalized())

    --Average it out into 1
    Up_Average = ((normal1 + normal2 + normal3 + normal4) * 0.25):GetNormalized()

    --Calculate lean based on angular velocity
    Up_Average = rotate_around_axis(Up_Average, self:GetForward(), math.Clamp(-phys:GetAngleVelocity()[3] * 0.1, -20, 20))

    --Movement Force
    Distance_Average = (Distance_Average / #Trace_Offsets)  * Ride_Height_Functional
    local Up = Up_Average * self:CalculatePD(PD_Settings, Ride_Height - Distance_Average, mass)
    local MoveForce = self:GetForward() * 20 * self.WS * (1 + self.Turbo) * self.Tick_Adjust
    self.Force = (self.Gravity + Up + MoveForce - phys:GetVelocity() * 0.02) * mass

    phys:ApplyForceCenter(self.Force)

    --Angle Force
    self._Cross = self.Cross
    self.Cross = Up_Average:Cross(self:GetUp()) * 500
    self._Cross =  self.Cross - self._Cross

    local AngVel = self:LocalToWorld(phys:GetAngleVelocity() * 0.8 - Vector(0, 0, self.AD * 170)) - self:GetPos()
    self.AngForce = (self.Cross + self._Cross * 5 + AngVel) * mass / 28.5 * self.Tick_Adjust
    phys:ApplyTorqueCenter(-self.AngForce)

    return true
end

function ENT:OnRemove()
    for k, v in pairs(self.Sounds) do
        if not v then continue end

        v:Stop()
        v = nil
    end
end