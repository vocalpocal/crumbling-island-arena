modifier_tinker_portal_cd_sub = class({})
local self = modifier_tinker_portal_cd_sub

function self:OnCreated()
	self:SetDuration(3, true)
end

function self:DestroyOnExpire()
	return false
end


function self:GetTexture()
	if self:GetRemainingTime() >= 0 then
		return "phoenix_supernova"
	else
		return "tinker_e_sub"
	end
end

function self:GetPriority()
	return 2
end

function self:GetAttributes()
	return 2 -- MODIFIER_ATTRIBUTE_MULTIPLE
end