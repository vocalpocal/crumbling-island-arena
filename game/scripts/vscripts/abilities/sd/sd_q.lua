sd_q = class({})
local self = sd_q

function sd_q:OnSpellStart()
    Wrappers.DirectionalAbility(self, 1000)
    local hero = self:GetCaster().hero
    local target = self:GetCursorPosition()
    local realTarget = target

    local blank = not Spells.TestCircle(target, 16)
    if blank then
        realTarget = target - Vector(0, 0, MAP_HEIGHT / 2)
    end

    local cursor = self:GetCursorPosition()

    CreateEntityAOEMarker(cursor, 200, 0.7, { 153, 0, 76 }, 0.5, true)
    local index =  ParticleManager:CreateParticle("particles/sd_q/sd_q.vpcf", PATTACH_ABSORIGIN, self:GetCaster())
    ParticleManager:SetParticleControl(index, 2, realTarget+Vector(0,0,40))
    ParticleManager:ReleaseParticleIndex(index)

    TimedEntity(0.5, function()
        blank = not Spells.TestCircle(target, 16)

        hero:StopSound("Arena.Invoker.CastQ")
        hero:EmitSound("Arena.Invoker.HitQ", realTarget)

        if blank then
            realTarget = target - Vector(0, 0, MAP_HEIGHT / 2)
        else
            hero:AreaEffect({
                ability = self,
                filter = Filters.Area(target, 200),
                filterProjectiles = true,
                action = function(victim)
                    SDUtil.Corrupt(hero, victim, self, 0)

                end
            })

            ScreenShake(target, 5, 150, 0.25, 2000, 0, true)
        end

        
    end):Activate()

    hero:EmitSound("Arena.Invoker.CastQ", realTarget)
end

function sd_q:GetCastAnimation()
    return ACT_DOTA_CAST_ABILITY_1
end

if IsClient() then
    require("wrappers")
end

Wrappers.NormalAbility(sd_q)