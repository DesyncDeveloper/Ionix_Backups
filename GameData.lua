local GameData = {
    OGCFrame = Vector3.new(68.521904, 8.59998798, 26.2358398),
    ThanksGivingCFrame = Vector3.new(197.734268, 9.59999943, 186.453949),
    OverworldEggAreaCFrame = {[1] = Vector3.new(-0.5828266143798828, 9.559693336486816, -21.460693359375), [2] = Vector3.new(-82.8704605, 9.19629288, -27.1242962)},

    Perm = {
        "Infinity Egg",
        "Chance Egg",
        "Common Egg",
        "Spotted Egg",
        "Iceshard Egg",
        "Inferno Egg",
        "Spikey Egg",
        "Magma Egg",
        "Crystal Egg",
        "Lunar Egg",
        "Void Egg",
        "Hell Egg",
        "Nightmare Egg",
        "Rainbow Egg",
        "Showman Egg",
        "Mining Egg",
        "Cyber Egg",
        "Neon Egg",
        "Icy Egg",
        "Vine Egg",
        "Lava Egg",
        "Secret Egg",
        "Atlantis Egg",
        "Classic Egg"
    },

    EggPlacement = {
        ["Infinity Egg"] = Vector3.new(-99.884392, 5.942852, -24.176849),
        ["Common Egg"] = Vector3.new(-83.5116577, 7.129426, 2.19293237),
        ["Spotted Egg"] = Vector3.new(-93.7220459, 7.129426, 8.14954662),
        ["Iceshard Egg"] = Vector3.new(-117.494141, 7.12944984, 9.676651),
        ["Inferno Egg"] = Vector3.new(94.236649, -21.696722, -10.273431),
        ["Spikey Egg"] = Vector3.new(-125.451027, 6.709450, 9.467079),
        ["Magma Egg"] = Vector3.new(-136.582703, 7.199440, -3.108365),
        ["Crystal Egg"] = Vector3.new(-143.888062, 6.199431, -10.429835),
        ["Lunar Egg"] = Vector3.new(-144.900955, 6.569431, -18.860899),
        ["Void Egg"] = Vector3.new(-145.912933, 6.529440, -26.960863),
        ["Hell Egg"] = Vector3.new(-141.126968, 6.929440, -37.468544),
        ["Nightmare Egg"] = Vector3.new(-140.080414, 6.979431, -45.270275),
        ["Rainbow Egg"] = Vector3.new(-136.840363, 6.279431, -48.611351),
        ["Showman Egg"] = Vector3.new(-130.416962, 6.259440, -55.135723),
        ["Mining Egg"] = Vector3.new(-123.458405, 6.979440, -65.952682),
        ["Cyber Egg"] = Vector3.new(-90.261902, 7.649427, -63.352390),
        ["Neon Egg"] = Vector3.new(-87.808128, 7.049427, -57.148247),
        ["Icy Egg"] = Vector3.new(-55.192982, 9.155189, -0.402438),
        ["Vine Egg"] = Vector3.new(-66.886223, 10.135189, 10.190548),
        ["Lava Egg"] = Vector3.new(-75.896500, 10.265189, 18.828331),
        ["Secret Egg"] = Vector3.new(-19437.0762, 8.45155239, 18837.0801),
        ["Atlantis Egg"] = Vector3.new(-83.027412, 10.795189, 20.237711),
        ["Classic Egg"] = Vector3.new(-86.627144, 10.455189, 25.488277),
    },

    Event = {
        OG = {
            "OG Egg",
            "Super OG Egg",
        },

        ThanksGiving = {
            "Corn Egg",
        },
    },

    ActiveEvent = { "OG", "ThanksGiving" },

    AreaToTeleport = {
        ["Secret Egg"] = "Workspace.Worlds.Seven Seas.Areas.Poison Jungle.IslandTeleport.Spawn"
    },

    ValidShops = {
        "alien-shop",
        "shard-shop",
        "dice-shop",
        "traveling-merchant",
        "festival-shop",
        "fishing-shop"
    },

    AllEggs = {
        "Infinity Egg",
        "Corn Egg",
        "OG Egg",
        "Super OG Egg",
        "Food Egg",
        "Super Aura Egg",
        "Chance Egg",
        "Common Egg",
        "Spotted Egg",
        "Iceshard Egg",
        "Inferno Egg",
        "Spikey Egg",
        "Magma Egg",
        "Crystal Egg",
        "Lunar Egg",
        "Void Egg",
        "Hell Egg",
        "Nightmare Egg",
        "Rainbow Egg",
        "Showman Egg",
        "Mining Egg",
        "Cyber Egg",
        "Neon Egg",
        "Icy Egg",
        "Vine Egg",
        "Lava Egg",
        "Secret Egg",
        "Atlantis Egg",
        "Classic Egg",
        
        "Season 1 Egg",
        "Series 1 Egg",
        "Inferno Egg",
        "Season 2 Egg",
        "Series 2 Egg",
        "Season 3 Egg",
        "Pirate Egg",
        "Season 4 Egg",
        "Season 5 Egg",
        "Season 6 Egg",
        "Season 7 Egg",
        "Stellaris Egg",
        "Season 8 Egg",
        "Spooky Egg",
        "Season 9 Egg",
    },
    PowerupEggs = {
        ["Season 1 Egg"] = true,
        ["Series 1 Egg"] = true,
        ["Inferno Egg"] = true,
        ["Season 2 Egg"] = true,
        ["Series 2 Egg"] = true,
        ["Season 3 Egg"] = true,
        ["Pirate Egg"] = true,
        ["Season 4 Egg"] = true,
        ["Season 5 Egg"] = true,
        ["Season 6 Egg"] = true,
        ["Season 7 Egg"] = true,
        ["Stellaris Egg"] = true,
        ["Season 8 Egg"] = true,
        ["Spooky Egg"] = true,
        ["Season 9 Egg"] = true,
    },
}

GameData.GetEggPlacement = function(eggName)
    if not eggName or type(eggName) ~= "string" then
        warn("[Ionix DEBUG] ❌ Invalid egg name provided to GetEggPlacement:", eggName)
        return nil
    end

    local stored = GameData.EggPlacement[eggName]
    if stored then
        if typeof(stored) == "Vector3" then
            return stored
        else
            warn("[Ionix DEBUG] ⚠️ EggPlacement value for", eggName, "is not a Vector3.")
        end
    end

    local primary, model = GameData.GetEggInstance(eggName)
    if primary and primary:IsA("BasePart") then
        return primary.Position
    elseif model then
        warn("[Ionix DEBUG] ⚠️ EggInstance found but no valid PrimaryPart for egg:", eggName)
    end

    local category = GameData.GetEggCategory(eggName)

    if category then
        local placement = GameData.GetEventCFrame(category)
        if placement then
            return placement
        else
            warn("[Ionix DEBUG] ⚠️ Event category found ('" .. category .. "') but no CFrame stored for that event.")
        end
    else
        warn("[Ionix DEBUG] ⚠️ Egg does not belong to Perm or any active event:", eggName)
    end

    warn("[Ionix DEBUG] ❌ No placement found for egg:", eggName)
    return nil
end


GameData.GetEggInstance = function(eggName)
    for _, obj in ipairs(workspace.Rendered:GetDescendants()) do
        if obj:IsA("Model") and obj.Parent and obj.Parent.Name == "Chunker" then
            if obj.Name == eggName then
                local eggPrimary = obj.PrimaryPart or obj:FindFirstChild("Plate")
                if eggPrimary then
                    return eggPrimary, obj
                end
            end
        end
    end
end

GameData.GetEventCFrame = function(eventName)
    if not eventName or type(eventName) ~= "string" then
        return nil
    end

    local key = eventName .. "CFrame"

    local value = GameData[key]
    if value and typeof(value) == "Vector3" then
        return value
    end

    return nil
end

GameData.GetEggCategory = function(selectedEgg)
    for _, egg in ipairs(GameData.Perm) do
        if egg == selectedEgg then
            return "Perm"
        end
    end

    local active = GameData.ActiveEvent
    if typeof(active) == "string" then
        active = { active }
    end

    if typeof(active) == "table" then
        for _, eventName in ipairs(active) do
            local list = GameData.Event[eventName]
            if list then
                for _, egg in ipairs(list) do
                    if egg == selectedEgg then
                        return eventName
                    end
                end
            end
        end
    end

    return nil
end


for _, egg in ipairs(GameData.Perm) do
    GameData.AreaToTeleport[egg] = "Workspace.Worlds.The Overworld.FastTravel.Spawn"
end

local active = GameData.ActiveEvent
if typeof(active) == "string" then
    active = { active }
end

if typeof(active) == "table" then
    for _, eventName in ipairs(active) do
        local list = GameData.Event[eventName]
        if list then
            for _, egg in ipairs(list) do
                GameData.AreaToTeleport[egg] = "Workspace.Worlds.The Overworld.FastTravel.Spawn"
            end
        end
    end
end

return GameData
