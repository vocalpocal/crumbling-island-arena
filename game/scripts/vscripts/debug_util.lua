Debug = Debug or {
    enableEndCheck = false,
    displayDebug = true,
    debugHero = nil,
    wtfStatus = false
}

function Debug.OnTestEverything()
    for name, data in pairs(GameRules.GameMode.AvailableHeroes) do
        if not data.disabled then
            Debug.OnCreateTestHero(nil, { name = name })
        end
    end
end

function Debug.OnTakeDamage(eventSourceIndex, args)
    GameRules.GameMode.Players[args.PlayerID].hero:Damage(GameRules.GameMode.Players[args.PlayerID].hero)
end

function Debug.OnHealHealth(eventSourceIndex, args)
    GameRules.GameMode.Players[args.PlayerID].hero:Heal()
end

function Debug.OnCheckEnd()
    GameRules.GameMode.round:CheckEndConditions()
end

function Debug.OnHealDebugHero()
    Debug.debugHero.unit:SetHealth(15)
end

function Debug.OnResetLevel(eventSourceIndex, args)
    GameRules.GameMode.level:Reset()
end

function Debug.OnToggleWTF()
    wtfStatus = not wtfStatus
    SendToServerConsole("dota_ability_debug "..(wtfStatus and "1" or "0"))
end

function Debug.OnCreateTestHero(eventSourceIndex, args)
    args.enemy = args.enemy == 1

    local round = GameRules.GameMode.round
    local hero = round:LoadHeroClass(args.name)
    local team = args.enemy and DOTA_TEAM_CUSTOM_2 or DOTA_TEAM_GOODGUYS
    local playerId = args.enemy and 2 or 0

    hero:SetUnit(CreateUnitByName(args.name, Vector(0, 0, 0), true, nil, nil, team))
    hero:Setup()
    hero:SetOwner({ id = playerId, hero = hero, team = team, score = 0, IsConnected = function() return true end })
    round:LoadHeroMixins(args.name, hero)

    local _, first = next(round.players)
    hero.unit:SetControllableByPlayer(first.id, true)

    Debug.debugHero = hero

    round.spells:AddDynamicEntity(hero)
end

function InjectFreeSelection()
    Hero.SetOwner = function(self, owner)
        self.owner = owner
        self.unit:SetControllableByPlayer(owner.id, true)
        self:AddNewModifier(self, nil, "modifier_player_id", {}):SetStackCount(self.owner.id)

        if #self.wearables == 0 then
            self:LoadWearables()
        end
    end
end

function InjectEndCheck(round)
    local original = round.CheckEndConditions
    local new =
    function()
        if enableEndCheck then
            original(round)
        end
    end

    round.CheckEndConditions = new
end

function InjectProjectileDebug()
    local original = Spells.ThinkFunction
    local new =
    function(dt)
        if displayDebug then
            for _, projectile in ipairs(Projectiles) do
                DebugDrawCircle(projectile.position, Vector(0, 255, 0), 255, projectile.radius, false, THINK_PERIOD)
            end
        end

        return original(dt)
    end

    Spells.ThinkFunction = new
end

function InjectAreaDebug()
    local original = Spells.AreaDamage
    local new =
    function(self, hero, point, area, action)
        if displayDebug then
            DebugDrawCircle(point, Vector(0, 255, 0), 255, area, false, 1)
        end

        return original(nil, hero, point, area, action)
    end

    Spells.AreaDamage = new
end

function CheckLocalizationFile(sourcePath, targetPath, pattern)
    local source = LoadKeyValues(sourcePath)["Tokens"]
    local target = LoadKeyValues(targetPath)["Tokens"]
    PrintTable(target)

    for key, _ in pairs(source) do
        local value = target[key]

        if not value then
            ---print("["..targetPath.."] missing key "..key)
        elseif not string.find(value, pattern) then
            --print("["..targetPath.."]: "..key.." key doesn't match the pattern")
        end
    end
end

function CheckAndEnableDebug()
    local cheatsEnabled = IsInToolsMode()

    CustomNetTables:SetTableValue("main", "debug", { enabled = cheatsEnabled })

    if not cheatsEnabled then
        return
    end

    GameRules.GameMode.gameSetup.timer = 20000
    GameRules.GameMode.heroSelection.SelectionTimerTime = (PlayerResource:GetPlayerCount() > 1) and 3 or 20000
    GameRules.GameMode.heroSelection.PreGameTime = 0
    GameRules.GameMode:UpdateGameInfo()

    --InjectHero(GameRules.GameMode.round)
    --InjectEndCheck(GameRules.GameMode.round)

    CustomGameEventManager:RegisterListener("debug_take_damage", Debug.OnTakeDamage)
    CustomGameEventManager:RegisterListener("debug_heal_health", Debug.OnHealHealth)
    CustomGameEventManager:RegisterListener("debug_heal_debug_hero", Debug.OnHealDebugHero)
    CustomGameEventManager:RegisterListener("debug_switch_end_check", function() Debug.enableEndCheck = not Debug.enableEndCheck end)
    CustomGameEventManager:RegisterListener("debug_switch_debug_display", function() Debug.displayDebug = not Debug.displayDebug end)
    CustomGameEventManager:RegisterListener("debug_check_end", Debug.OnCheckEnd)
    CustomGameEventManager:RegisterListener("debug_reset_level", Debug.OnResetLevel)
    CustomGameEventManager:RegisterListener("debug_create_test_hero", Debug.OnCreateTestHero)
    CustomGameEventManager:RegisterListener("debug_toggle_wtf", Debug.OnToggleWTF)
    CustomGameEventManager:RegisterListener("debug_test_everything", Debug.OnTestEverything)

    --InjectProjectileDebug()
    --InjectAreaDebug()
    ULTS_TIME = 1

    --[[
    Statistics.stats[1] = {}
    Statistics.stats[2] = {}
    Statistics.stats[3] = {}

    Statistics.AddPlayedHero({ id=1 }, "npc_dota_hero_sven")
    Statistics.AddPlayedHero({ id=1 }, "npc_dota_hero_phoenix")
    Statistics.AddPlayedHero({ id=1 }, "npc_dota_hero_sniper")
    Statistics.AddPlayedHero({ id=1 }, "npc_dota_hero_pugna")
    Statistics.AddPlayedHero({ id=1 }, "npc_dota_hero_phantom_assassin")
    Statistics.AddPlayedHero({ id=1 }, "npc_dota_hero_sand_king")
    Statistics.AddPlayedHero({ id=1 }, "npc_dota_hero_storm_spirit")

    Statistics.AddPlayedHero({ id=2 }, "npc_dota_hero_sniper")
    Statistics.AddPlayedHero({ id=2 }, "npc_dota_hero_phoenix")
    Statistics.AddPlayedHero({ id=2 }, "npc_dota_hero_pugna")
    Statistics.AddPlayedHero({ id=2 }, "npc_dota_hero_phantom_assassin")
    Statistics.AddPlayedHero({ id=2 }, "npc_dota_hero_sand_king")

    Statistics.AddPlayedHero({ id=3 }, "npc_dota_hero_earth_spirit")
    Statistics.AddPlayedHero({ id=3 }, "npc_dota_hero_lycan")
    Statistics.AddPlayedHero({ id=3 }, "npc_dota_hero_crystal_maiden")
    Statistics.IncreaseDamageDealt({ id = 3 })
    ]]
end

if IsInToolsMode() then
    InjectFreeSelection()

    --CheckLocalizationFile("panorama/localization/addon_english.txt", "panorama/localization/addon_russian.txt", "[а-яА-Я][а-яА-Я]+")
end