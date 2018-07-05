modifier_sd_corruption = class({})


function modifier_sd_corruption:GetTexture()
    return "shadow_demon_shadow_poison"
end

function modifier_sd_corruption:IsDebuff()
    return true
end

if IsServer() then
    function modifier_sd_corruption:CreateCounter()
        healthCounter = ParticleManager:CreateParticle("particles/generic_counter.vpcf", PATTACH_CUSTOMORIGIN, nil)
        ParticleManager:SetParticleControlEnt(healthCounter, 0, target, PATTACH_ABSORIGIN_FOLLOW, nil, target, true)
        ParticleManager:SetParticleControl(healthCounter, 1, Vector(0, self:GetParent():GetParentEntity():GetStacks(), 0))
        ParticleManager:SetParticleControl(healthCounter, 2, Vector(0, 170, 0))
    end

    function modifier_sd_corruption:OnCreated()
        self.CreateCounter()
    end
end
--[[
function modifier_sd_corruption:GetEffectName()
    return "particles/sd_a/sd_poison_stack.vpcf"
end]]

function modifier_sd_corruption:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end



function modifier_sd_corruption:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE
    }

    return funcs
end


function modifier_sd_corruption:GetModifierMoveSpeedBonus_Percentage(params)
    return -5*self:GetStackCount()
end