modifier_sd_e = class({})

if IsServer() then
	function modifier_sd_e:OnCreated()
		local hero = self:GetParent():GetParentEntity()
		hero:SetHidden(true)
		local index = FX("particles/sd_e/satyr_hellcaller.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent(), {
						    cp0 = self:GetCaster():GetAbsOrigin() + Vector(0, 0, 200),
						    cp1 = self:GetCaster():GetAbsOrigin() --+ self:GetCaster():GetForwardVector()*1.1
						})

		self:AddParticle(index, false, true, 1, false, false)
		self:StartIntervalThink(0.5)
	end

	function modifier_sd_e:OnIntervalThink()
        local hero = self:GetParent():GetParentEntity()

        hero:AreaEffect({
            ability = self:GetAbility(),
            filter = Filters.Area(hero:GetPos(), 300),
            action = function(target)
            SDUtil.Corrupt(hero, target, ability, 1)
        	end
        })
    end

	function modifier_sd_e:OnDestroy()
		local hero = self:GetParent():GetParentEntity()
		hero:SetHidden(false)
	end

end


function modifier_sd_e:CheckState()
    local state = {
        [MODIFIER_STATE_OUT_OF_GAME] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
        [MODIFIER_STATE_SILENCED] = true
    }

    return state
end

-- Make so that passing through enemies with corruption extends the duration. Add the ability to cancel the effect.


function modifier_sd_e:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_MOVESPEED_MAX
    }

    return funcs
end


function modifier_sd_e:GetModifierMoveSpeedOverride(params)
    return 1000
end

function modifier_sd_e:GetModifierMoveSpeedBonus_Percentage(params)
    return 80
end


function modifier_sd_e:IsInvulnerable()
    return true
end

function modifier_sd_e:Airborne()
    return true
end