sd_a = class({})
local self = sd_a

LinkLuaModifier("modifier_sd_corruption", "abilities/sd/modifier_sd_corruption", LUA_MODIFIER_MOTION_NONE)

function sd_a:OnSpellStart()
    local hero = self:GetCaster().hero
    local target = self:GetCursorPosition()
    local stacks = 1

    DistanceCappedProjectile(hero.round, {
        ability = self,
        owner = hero,
        from = hero:GetPos() + Vector(0, 0, 64),
        to = target + Vector(0, 0, 64),
        speed = 1400,
        graphics = "particles/sd_a/sd_a.vpcf",
        distance = 900,
        hitSound = "Arena.PA.HitW.Sub",
        hitFunction = function(projectile, target)
            SDUtil.Corrupt(hero, target, self, stacks)
        end
    }):Activate()

    hero:EmitSound("Arena.PA.CastW.Sub")
end


function self:GetCastAnimation()
    return ACT_DOTA_ATTACK
end

function self:GetPlaybackRateOverride()
    return 2.0
end

if IsClient() then
    require("wrappers")
end

Wrappers.AttackAbility(self)