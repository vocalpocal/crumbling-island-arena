SECOND_STAGE_OBSTRUCTOR = "Layer2Obstructor"
THIRD_STAGE_OBSTRUCTOR = "Layer3Obstructor"

STARTING_DISTANCE = 2300
FINISHING_DISTANCE = 900

if Level == nil then
    Level = class({})
end

function Level:constructor()
    self.parts = Entities:FindAllByName("map_part")
    self.distance = STARTING_DISTANCE
    self.shakingParts = {}
    self.fallingParts = {}
    self.indexedParts = {}
    self.particles = {}
    self.running = true

    self:BuildIndex()
end

function Level:BuildIndex()
    for _, part in ipairs(self.parts) do
        local position = part:GetAbsOrigin()
        part.x = position.x
        part.y = position.y
        part.z = position.z
        part.velocity = 0
        part.angles = part:GetAnglesAsVector()
        part.angleVel = Vector(0, 0, 0)
        part.health = 100

        local id = math.floor(position:Length2D())
        local index = self.indexedParts[id]

        if not index then
            index = {}
            self.indexedParts[id] = index
        end

        table.insert(index, part)
    end
end

function Level:DamageGroundInRadius(point, radius)
    -- TODO index points with cluster grid
    for _, part in ipairs(self.parts) do
        if part.velocity == 0 and part.health > 0 then
            local distance = (part:GetAbsOrigin() - point):Length2D()

            if distance <= radius then
                local proportion = 1 - distance / radius

                self:DamageGround(part, 60 * proportion)
            end
        end
    end

    local particle = ParticleManager:CreateParticle("particles/cracks.vpcf", PATTACH_ABSORIGIN, GameRules:GetGameModeEntity())
    ParticleManager:SetParticleControl(particle, 0, point)
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))

    table.insert(self.particles, particle)
end

function Level:DamageGround(part, damage)
    part.health = part.health - damage

    if part.health <= 50 then
        table.insert(self.shakingParts, part)
    end

    if part.health <= 0 then
        self:LaunchPart(part)
    end
end

function Level:Reset()
    self.fallingParts = {}
    self.shakingParts = {}
    self.distance = STARTING_DISTANCE

    for _, part in ipairs(self.parts) do
        part:SetAbsOrigin(Vector(part.x, part.y, 0))
        part:SetAngles(Vector(0, 0, 0))
        part.velocity = 0
        part.health = 100
        part.z = 0
        part.angles = Vector(0, 0, 0)
        part.angleVel = Vector(0, 0, 0)
    end

    for _, particle in ipairs(self.particles) do
        ParticleManager:DestroyParticle(particle, false)
        ParticleManager:ReleaseParticleIndex(0)
    end

    GridNav:RegrowAllTrees()
end

function Level:LaunchPart(part)
    table.insert(self.fallingParts, part)
    part.angleVel = Vector(RandomFloat(0, 2), RandomFloat(0, 2), 0)
end

function Level:Update()
    local currentIndex = self.indexedParts[self.distance]

    if currentIndex and self.running then
        for _, part in ipairs(currentIndex) do
            self:LaunchPart(part)
        end
    end

    if self.distance - 64 > FINISHING_DISTANCE then
        local shakingIndex = self.indexedParts[self.distance - 64]

        if shakingIndex then
            for _, part in ipairs(shakingIndex) do
                table.insert(self.shakingParts, part)
            end
        end
    end

    for _, part in ipairs(self.shakingParts) do
        if part.velocity == 0 then
            local amplitude = 0.5

            if part.health ~= 100 then
                amplitude = 1 - part.health / 50
            end

            local yaw = RandomFloat(-amplitude, amplitude)
            local pitch = RandomFloat(-amplitude, amplitude)
            local roll = RandomFloat(-amplitude, amplitude)

            part:SetAngles(yaw, pitch, roll)
        end
    end

    for i = #self.fallingParts, 1, -1 do
        local part = self.fallingParts[i]
        part.velocity = part.velocity + 6
        part.z = part.z - part.velocity
        part.angles = part.angles + part.angleVel
        part:SetAngles(part.angles.x, part.angles.y, part.angles.z)
        part:SetAbsOrigin(Vector(part.x, part.y, part.z))

        if part.z <= -4096 then
            table.remove(self.fallingParts, i)
        end
    end

    if self.distance > FINISHING_DISTANCE then
        self.distance = self.distance - 1
    else
        self.running = false
    end
end