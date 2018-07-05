sd_e = class({})


LinkLuaModifier("modifier_sd_e", "abilities/sd/modifier_sd_e", LUA_MODIFIER_MOTION_NONE)


function sd_e:OnSpellStart()
	local hero = self:GetCaster().hero
	hero:AddNewModifier(hero, self, "modifier_sd_e", { duration = 1.0 })
end


if IsClient() then
    require("wrappers")
end

Wrappers.NormalAbility(sd_e)