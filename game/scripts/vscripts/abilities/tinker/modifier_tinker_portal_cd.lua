modifier_tinker_portal_cd = class({})
local self = modifier_tinker_portal_cd

function self:DestroyOnExpire()
	return false
end

function self:OnCreated()
	self:SetDuration(3, true)
end


function self:GetTexture()
	if self:GetRemainingTime() >= 0 then
		return "tinker_e"
	else
		return "phoenix_supernova"
	end
end

function self:GetPriority()
	return 2
end

function self:GetAttributes()
	return 2 -- MODIFIER_ATTRIBUTE_MULTIPLE
end