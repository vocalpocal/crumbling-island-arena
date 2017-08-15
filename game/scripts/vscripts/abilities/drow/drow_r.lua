drow_r = class({})

function drow_r:OnChannelThink(interval)
    self.channelingTime = (self.channelingTime or 0) + interval

    if interval == 0 then
        self:GetCaster().hero:EmitSound("Arena.Drow.CastR.Voice")
    end

    if not self.soundPlayed and self.channelingTime >= 0.45 then
        self:GetCaster().hero:EmitSound("Arena.Drow.PreR")
        self.soundPlayed = true
    end
end

function drow_r:OnChannelFinish(interrupted)
    self.channelingTime = 0
    self.soundPlayed = false

    if interrupted then
        return
    end

    local hero = self:GetCaster().hero
    local target = self:GetCursorPosition()
    local direction = self:GetDirection()

    ScreenShake(hero:GetPos(), 5, 150, 0.25, 3000, 0, true)
    SoftKnockback(hero, hero, -direction, 30, { decrease = 4 })

    Projectile(hero.round, {
        ability = self,
        owner = hero,
        from = hero:GetPos() + Vector(0, 0, 64),
        to = target + Vector(0, 0, 64),
        speed = 3500,
        graphics = "particles/drow_r/drow_r.vpcf",
        hitSound = "Arena.Drow.HitR",
        damage = self:GetDamage(),
        knockback = { force = 100 },
        nonBlockedHitAction = function(projectile, target)
            local pos = projectile:GetPos()
            local effect = ImmediateEffectPoint("particles/econ/items/earthshaker/earthshaker_gravelmaw/earthshaker_fissure_dust_gravelmaw.vpcf", PATTACH_ABSORIGIN, target, pos)
            ParticleManager:SetParticleControl(effect, 1, pos + direction * 300)

            effect = ImmediateEffectPoint("particles/drow_r/drow_r_bash.vpcf", PATTACH_ABSORIGIN, target, pos)
            ParticleManager:SetParticleControlForward(effect, 1, -direction)

            if instanceof(target, Hero) then
                projectile:Destroy()
            end
        end,
        destroyFunction = function(projectile)
            ScreenShake(projectile:GetPos(), 5, 150, 0.25, 3000, 0, true)
        end,
        destroyOnDamage = false,
        continueOnHit = true
    }):Activate()

    hero:StopSound("Arena.Drow.PreR")
    hero:EmitSound("Arena.Drow.CastR")
end

function drow_r:GetChannelTime()
    return 0.9
end

function drow_r:GetCastAnimation()
    return ACT_DOTA_ATTACK
end

function drow_r:GetPlaybackRateOverride()
    return 1.0
end

if IsServer() then
    Wrappers.GuidedAbility(drow_r, true)
end

if IsClient() then
    require("wrappers")
end

Wrappers.NormalAbility(drow_r)