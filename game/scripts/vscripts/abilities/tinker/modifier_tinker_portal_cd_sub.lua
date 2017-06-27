modifier_tinker_portal_cd_sub = class({})
local self = modifier_tinker_portal_cd_sub

function self:OnCreated()
	self:SetDuration(3, true) --On hero spawn the duration matches the global 3 sec CD
end

function self:DestroyOnExpire()
	return false
end

function self:GetPriority()
	return 2
end

-- I wanted it to have texture which changed when the CD was fully refreshed. It worked well before I started using GetIntrinsicModifierName() in hero_util.lua
--[[function self:GetTexture()
	if self:GetRemainingTime() > 0 then
		return "tinker_e"
	else
		return "phoenix_supernova"
	end
end
]]


-- I wanted to use the same modifier twice, but don't know how to do that so I just made two portal cd
--[[function self:GetAttributes()
	return 2 -- MODIFIER_ATTRIBUTE_MULTIPLE
end
]]