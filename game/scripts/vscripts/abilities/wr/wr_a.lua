wr_a = class({})
LinkLuaModifier("modifier_wr_a", "abilities/wr/modifier_wr_a", LUA_MODIFIER_MOTION_NONE)

function wr_a:OnSpellStart()
    local hero = self:GetCaster().hero
    local target = self:GetCursorPosition()

    DistanceCappedProjectile(hero.round, {
        ability = self,
        owner = hero,
        from = hero:GetPos() + Vector(0, 0, 128),
        to = target + Vector(0, 0, 128),
        speed = 1450,
        radius = 48,
        graphics = "particles/wr_a/wr_a.vpcf",
        distance = 1200,
        hitSound = "Arena.Drow.HitA",
        hitFunction = function(projectile, target)
            target:Damage(projectile, self:GetDamage(), true)

            local hero = projectile:GetTrueHero()

            print(target, hero)

            if instanceof(target, Hero) then
                local haste = hero:FindModifier("modifier_wr_a")

                if not haste then
                    haste = hero:AddNewModifier(hero, self, "modifier_wr_a", {})
                end

                if haste then
                    haste:SetStackCount(haste:GetStackCount() + 60)
                end
            end
        end,
        isPhysical = true
    }):Activate()

    hero:EmitSound("Arena.WR.CastA")
end

function wr_a:GetCastAnimation()
    return ACT_DOTA_ATTACK
end

function wr_a:GetPlaybackRateOverride()
    return 2
end

if IsClient() then
    require("wrappers")
end

Wrappers.AttackAbility(wr_a)