require("level_piece")

MAP_HEIGHT = 7000
FINISHING_DISTANCE = 1000

local function bigTransformer(x, y)
    return x, -y
end

local function smallTransformer(x, y)
    return y, x
end

MAPS = {
    ["unranked"] = { pieces = 919, prefab = "arena_big", transformer = bigTransformer, startingDistance = 3000 },
    ["ranked_3v3"] = { pieces = 919, prefab = "arena_big", transformer = bigTransformer, startingDistance = 3000 },
    ["ranked_2v2"] = { pieces = 579, prefab = "arena_small", transformer = smallTransformer, startingDistance = 2300 },
    ["ranked_1v1"] = { pieces = 579, prefab = "arena_small", transformer = smallTransformer, startingDistance = 2300 },
}

if Level == nil then
    Level = class({})
end

function Level.LoadMap(map)
    local prefab = MAPS[map].prefab
    local pieces = require("levels/prefabs/"..prefab)
    local currentIndex = nil
    local loaded = 0

    local function LoadNext()
        local key, value = next(pieces, currentIndex)

        if key == nil then
            return nil
        end

        currentIndex = key

        return {
            classname = "prop_dynamic",
            model = "maps/prefabs/"..prefab.."/entities/"..key,
            origin = value - Vector(0, 0, 32),
            targetname = "map_part",
            name = "map_part",
            target = "map_part"
        }
    end

    local function ReportProgress(list)
        loaded = loaded + #list

        CustomGameEventManager:Send_ServerToAllClients("setup_level_loading", { progress = loaded / MAPS[map].pieces })
    end

    local function LoadingFinished()
        GameRules.GameMode.gameSetup.levelLoaded = true
    end

    Timers:CreateTimer(function()
        local list = {}

        for i = 1, 30 do
            local n = LoadNext()

            if n == nil then
                SpawnEntityListFromTableAsynchronous(list, function()
                    ReportProgress(list)
                    LoadingFinished()
                end)
                
                return 
            end

            table.insert(list, n)
        end

        SpawnEntityListFromTableAsynchronous(list, function() ReportProgress(list) end)

        return 0.35
    end)
end

function Level:constructor()
    self.parts = Entities:FindAllByName("map_part")
    self.distance = self:GetStartingDistance()
    self.shakingParts = {}
    self.fallingParts = {}
    self.indexedParts = {}
    self.particles = {}
    self.running = true
    self.pulsePosition = 0
    self.pulseDirection = 1
    self.tick = 0
    self.slowFactor = 1
    self.enableRegeneration = false
    self.finishingDistance = FINISHING_DISTANCE
    self.lastRegenerationAt = nil

    self:BuildIndex()
    self:SetupBackground()
end

function Level:ThanksValve()
    for _, part in pairs(self.parts) do
        part.defaultZ = part.defaultZ - 32
    end
end

function Level:Hide()
    for _, part in ipairs(self.parts) do
        part:AddEffects(EF_NODRAW)
    end
end

function Level:Show()
    for _, part in ipairs(self.parts) do
        part:RemoveEffects(EF_NODRAW)
    end
end

function Level:SetSlowFactor(factor)
    self.slowFactor = factor
end

function Level:EnableRegeneration(timeBase, timeScaling)
    self.enableRegeneration = true
    self.regenerationTimeBase = timeBase
    self.regenerationTimeScaling = timeScaling
end

function Level:GetStartingDistance()
    return MAPS[GetMapName()].startingDistance
end

function Level:SetFinishingDistance(d)
    self.finishingDistance = d
end

function Level:BuildIndex()
    for _, part in ipairs(self.parts) do
        local position = part:GetAbsOrigin()
        part.x = position.x
        part.y = position.y
        part.z = position.z
        part.defaultZ = part.z
        part.velocity = 0
        part.angles = part:GetAnglesAsVector()
        part.angleVel = Vector(0, 0, 0)
        part.health = 100

        part.offsetX = 0
        part.offsetY = 0
        part.offsetZ = 0

        local id = math.floor(position:Length2D())
        local index = self.indexedParts[id]

        if not index then
            index = {}
            self.indexedParts[id] = index
        end

        table.insert(index, part)
    end
end

function Level:DamageGroundInRadius(point, radius, source, suppressParticles, damageFactor)
    -- TODO index points with cluster grid
    local damageQueue = {}
    local justParts = {}
    for _, part in ipairs(self.parts) do
        if part.velocity == 0 and part.health > 0 and not part.launched then
            local distance = (part:GetAbsOrigin() - point):Length2D()

            if distance <= radius then
                table.insert(damageQueue, { part, distance })
                table.insert(justParts, part)
            end
        end
    end

    if not suppressParticles then
        local amount = math.floor(radius / 100)

        for i = 1, RandomInt(amount, amount + 2) do
            ArcProjectile(nil, {
                from = point + RandomVector(RandomInt(0, radius / 2)),
                to = point + RandomVector(RandomInt(radius, radius * 3)),
                speed = 1200,
                arc = RandomInt(300, 600),
                graphics = "particles/debris/debris.vpcf"
            }):Activate()
        end
    end

    local function compare(a, b)
        return a[2] < b[2]
    end

    table.sort(damageQueue, compare)

    if not damageFactor then
        damageFactor = 1
    end

    for i, d in ipairs(damageQueue) do
        --Timers:CreateTimer(i * 0.003, function()
        local proportion = 1 - d[2] / radius
        self:DamageGround(d[1], 100 * proportion * damageFactor, source, point, radius)
        --end)
    end

    if not self.enableRegeneration then
        local particle = ParticleManager:CreateParticle("particles/cracks.vpcf", PATTACH_ABSORIGIN, GameRules:GetGameModeEntity())
        ParticleManager:SetParticleControl(particle, 0, point)
        ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))

        table.insert(self.particles, particle)
    end

    return justParts
end

function Level:DamageGround(part, damage, source, point, radius)
    if part.launched then
        return
    end

    part.health = part.health - damage

    if part.health <= 50 then
        table.insert(self.shakingParts, part)
    end

    if part.health <= 50 and not part.launched then
        part.z = part.defaultZ + (part.health / 50 - 1) * 18 - 8
        self:UpdatePartPosition(part)
    end

    if part.health <= 0 then
        self:LaunchPart(part, source, point, radius)
    end
end

function Level:Reset()
    self.running = true
    self.fallingParts = {}
    self.shakingParts = {}
    self.regeneratingParts = {}
    self.distance = self:GetStartingDistance()
    self.pulsePosition = 0
    self.pulseDirection = 1
    self.lastRegenerationAt = nil

    for _, part in ipairs(self.parts) do
        part:SetAbsOrigin(Vector(part.x, part.y, part.defaultZ))
        part:SetAngles(0, 0, 0)
        part.velocity = 0
        part.health = 100
        part.z = part.defaultZ
        part.offsetX = 0
        part.offsetY = 0
        part.offsetZ = 0
        part.angles = Vector(0, 0, 0)
        part.angleVel = Vector(0, 0, 0)
        part.launched = false
        part.launchedBy = nil
        part.launchedAt = 0
        part.regeneratesAt = nil
        part:SetRenderColor(255, 255, 255)
        part:RemoveEffects(EF_NODRAW)
    end

    for _, particle in ipairs(self.particles) do
        ParticleManager:DestroyParticle(particle, false)
        ParticleManager:ReleaseParticleIndex(0)
    end

    GridNav:RegrowAllTrees()
end

function Level:LaunchPart(part, by, point, radius)
    local dist
    local dir

    if point == nil then
        dir = Vector(part.x, part.y, 0):Normalized()
        radius = RandomInt(200, 500)
        dist = RandomInt(0, radius)
    else
        dist = (point * Vector(1, 1, 0) - Vector(part.x, part.y, 0))
        dir = dist:Normalized()
        dist = dist:Length2D()
    end

    -- No idea how I figured this out
    local anx = -Vector(dir.y, -dir.x):Dot(Vector(0, 1, 0)) * 6
    local anz = -Vector(dir.y, -dir.x):Dot(Vector(1, 0, 0)) * 6

    table.insert(self.fallingParts, part)
    part.angleVel = Vector(anx, 0, anz)
    part.launched = true
    part.launchedBy = by
    part.launchedAt = GameRules:GetGameTime()
    part.velocity = math.max(-50, (radius / 10 - dist / 3))

    for _, child in pairs(part:GetChildren()) do
        if child.GetParentEntity then
            local ent = child:GetParentEntity()

            if ent.OnLaunched then
                ent:OnLaunched(part)
            end
        end
    end

    if by and self.enableRegeneration then
        table.insert(self.regeneratingParts, part)
    end
end

function Level:Update()
    local currentIndex = self.indexedParts[self.distance]

    if currentIndex and self.running then
        for _, part in ipairs(currentIndex) do
            if not part.launched then
                self:LaunchPart(part, nil, Vector(part.x, part.y) * 1.01, 0)
            end
        end
    end

    if self.distance - 64 > self.finishingDistance then
        local shakingIndex = self.indexedParts[self.distance - 64]

        if shakingIndex then
            for _, part in ipairs(shakingIndex) do
                table.insert(self.shakingParts, part)
            end
        end
    end

    local time = GameRules:GetGameTime()

    if self.enableRegeneration then
        for i = #self.regeneratingParts, 1, -1 do
            local part = self.regeneratingParts[i]
            local timeDiff = time - part.launchedAt
            local timeScaled = self.distance / self:GetStartingDistance() * self.regenerationTimeScaling

            if timeDiff > self.regenerationTimeBase + timeScaled then
                if part.regeneratesAt == nil then
                    if self.lastRegenerationAt and self.lastRegenerationAt >= time then
                        part.regeneratesAt = self.lastRegenerationAt + 0.1
                    else
                        part.regeneratesAt = time
                    end

                    part.regenerateFromAngles = Vector(part.angles.x, part.angles.y, part.angles.z)
                end

                self.lastRegenerationAt = part.regeneratesAt

                if part.regeneratesAt ~= nil and time > part.regeneratesAt then
                    local progress = EaseOutCircular(math.min(time - part.regeneratesAt, 1.5), 0, 1, 1.5)

                    part.velocity = part.velocity + 2
                    part.z = math.min(part.z + part.velocity, part.defaultZ)
                    part.z = progress * MAP_HEIGHT - MAP_HEIGHT
                    part.angles = SplineVectors(part.regenerateFromAngles, Vector(0, 0, 0), progress)--part.angles - part.angleVel / 3
                    part:SetAngles(part.angles.x, part.angles.y, part.angles.z)
                    part:RemoveEffects(EF_NODRAW)
                    self:UpdatePartPosition(part)

                    if time - part.regeneratesAt >= 1.5 then
                        table.remove(self.regeneratingParts, i)
                        part.launched = false
                        part.launchedAt = 0
                        part.launchedBy = nil
                        part.health = 100
                        part.velocity = 0
                        part:SetRenderColor(255, 255, 255)
                        part:SetAngles(0, 0, 0)
                        part.angleVel = Vector(0, 0, 0)
                        part.regeneratesAt = nil
                    end
                end
            end
        end

        local copy = vlua.clone(self.parts)
        table.sort(copy, function(a, b)
            local alen = math.sqrt(a.offsetX * a.offsetX + a.offsetY * a.offsetY)
            local blen = math.sqrt(b.offsetX * b.offsetX + b.offsetY * b.offsetY)
            return alen > blen
        end)

        local i = 0

        for _, part in ipairs(copy) do
            if not part.launched and (part.offsetX ~= 0 or part.offsetY ~= 0) then
                local speed = 0.2
                local newX = part.offsetX
                local newY = part.offsetY

                if part.offsetX > 0 then
                    newX = math.max(0, part.offsetX - speed)
                elseif part.offsetX < 0 then
                    newX = math.min(0, part.offsetX + speed)
                end

                if part.offsetY > 0 then
                    newY = math.max(0, part.offsetY - speed)
                elseif part.offsetY < 0 then
                    newY = math.min(0, part.offsetY + speed)
                end

                self:SetPartOffset(part, newX, newY)
                self:UpdatePartPosition(part)

                i = i + 1

                if i == 10 then
                    break
                end
            end
        end
    end

    self.tick = self.tick + 1

    if self.tick % 3 == 0 then
        for _, part in ipairs(self.shakingParts) do
            if part.velocity == 0 then
                local pulseBound = (100 - part.health) * 0.8
                local pulsePosition = self.pulsePosition / 100 * pulseBound

                part:SetRenderColor(255, 255 - pulsePosition, 255 - pulsePosition)

                local amplitude = 0.8

                if part.health ~= 100 then
                    amplitude = 1 - part.health / 80
                end

                local yaw = RandomFloat(-amplitude, amplitude)
                local pitch = RandomFloat(-amplitude, amplitude)
                local roll = RandomFloat(-amplitude, amplitude)

                part:SetAngles(yaw, pitch, roll)
            end
        end
    end

    for i = #self.fallingParts, 1, -1 do
        local part = self.fallingParts[i]
        part.velocity = part.velocity + 3
        part.z = part.z - part.velocity
        part.angles = part.angles + part.angleVel
        part:SetAngles(part.angles.x, part.angles.y, part.angles.z)
        part:SetAbsOrigin(Vector(part.x + part.offsetX, part.y + part.offsetY, part.z + part.offsetZ))

        if part.z <= -MAP_HEIGHT - 200 then
            table.remove(self.fallingParts, i)
            part.velocity = 0
            part.offsetX = 0
            part.offsetY = 0
            part.offsetZ = 0
        end
    end

    for i = #self.shakingParts, 1, -1 do
        local part = self.shakingParts[i]

        if part.z <= -MAP_HEIGHT then
            --SplashEffect(part:GetAbsOrigin())
            part:AddEffects(EF_NODRAW)

            table.remove(self.shakingParts, i)
        end
    end

    if self.distance > self.finishingDistance then
        if not IsInToolsMode() then
            if self.tick % self.slowFactor == 0 then
                self.distance = self.distance - 1
            end
        end
    else
        self.running = false
    end

    self.pulsePosition = self.pulsePosition + self.pulseDirection * 3

    if self.pulsePosition <= 0 and self.pulseDirection == -1 then
        self.pulsePosition = 0
        self.pulseDirection = 1
    end

    if self.pulsePosition >= 100 and self.pulseDirection == 1 then
        self.pulsePosition = 100
        self.pulseDirection = -1
    end
end

function Level:GroundAction(action)
    for _, part in ipairs(self.parts) do
        if not part.launched then
            action(part)
        end
    end
end

function Level:UpdatePartPosition(part)
    part:SetAbsOrigin(Vector(part.x + part.offsetX, part.y + part.offsetY, part.z + part.offsetZ))
end

function Level:FindReasonForFalling(hero)
    local pos = hero:GetPos()
    local time = GameRules:GetGameTime()
    local closestReason = nil
    local maxTime = -1

    for _, part in ipairs(self.parts) do
        if part.launched and part.launchedAt and part.launchedBy then
            local len = (Vector(part.x + part.offsetX, part.y + part.offsetY, 0) - pos):Length2D()
            if time - part.launchedAt <= 3 and len < 350 then
                if part.launchedAt > maxTime then
                    maxTime = part.launchedAt
                    closestReason = part.launchedBy
                end
            end
        end
    end

    return closestReason
end

function Level:SetPartOffset(part, offsetX, offsetY)
    part.offsetX = offsetX
    part.offsetY = offsetY
    self:UpdatePartPosition(part)
end

function Level:AddPartChild(part, child)
    child:GetUnit():SetParent(part, nil)
    child:GetUnit():SetOrigin(child:GetPos())
end

function Level.CreateCreep(name, spawn, team, goal)
    CreateUnitByNameAsync(name, spawn, true, nil, nil, team, function(unit)
        unit:AddNewModifier(u, nil, "modifier_creep", {})
        unit:SetInitialGoalEntity(goal)
    end)
end

function Level:SetupBackground()
    local ancient = Entities:FindByName(nil, "ancient_effect")

    if not ancient then
        return
    end

    --local effect = ParticleManager:CreateParticle("particles/dire_fx/bad_ancient_ambient.vpcf", PATTACH_ABSORIGIN, GameRules:GetGameModeEntity())
    --ParticleManager:SetParticleControl(effect, 0, ancient:GetAbsOrigin())
    --ParticleManager:ReleaseParticleIndex(effect)

    for _, ent in pairs(Entities:FindAllByClassname("npc_dota_tower")) do
        ent:AddNewModifier(ent, nil, "modifier_tower", {})
    end

    Timers:CreateTimer(function()
        local goodSpawn = Entities:FindByName(nil, "good_creeps_start"):GetAbsOrigin()
        local badSpawn = Entities:FindByName(nil, "bad_creeps_start"):GetAbsOrigin()

        local goodGoal = Entities:FindByName(nil, "p_good_1")
        local badGoal = Entities:FindByName(nil, "p_bad_1")

        for i = 1, 3 do
            Level.CreateCreep("npc_dota_creep_badguys_melee", badSpawn, DOTA_TEAM_CUSTOM_7, badGoal)
            Level.CreateCreep("npc_dota_creep_goodguys_melee", goodSpawn, DOTA_TEAM_CUSTOM_8, goodGoal)
        end

        Level.CreateCreep("npc_dota_creep_badguys_ranged", badSpawn, DOTA_TEAM_CUSTOM_7, badGoal)
        Level.CreateCreep("npc_dota_creep_goodguys_ranged", goodSpawn, DOTA_TEAM_CUSTOM_8, goodGoal)

        return 30
    end)
end

function Level.KillCreepsInRadius(target, radius)
    for _, c in pairs(Entities:FindAllByClassnameWithin("npc_dota_creep_lane", target, radius)) do
        c:ForceKill(false)
    end
end