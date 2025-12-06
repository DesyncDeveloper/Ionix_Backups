repeat
    task.wait(0.1)
until game:IsLoaded() and game:GetService("Players") and game:GetService("Players").LocalPlayer

if false == true then
    loadstringUrl = "https://getionix.xyz/scripts/GameData"
else
    loadstringUrl = "https://raw.githubusercontent.com/DesyncDeveloper/Ionix_Backups/refs/heads/main/GameData.lua"
end

local IonixGameData = loadstring(game:HttpGet(loadstringUrl))()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Framework = Shared:WaitForChild("Framework")
local Network = Framework:WaitForChild("Network")
local Remote = Network:WaitForChild("Remote")
local RemoteEvent = Remote:WaitForChild("RemoteEvent")
local RemoteFunction = Remote:WaitForChild("RemoteFunction")

local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local PetsData = require(ReplicatedStorage.Shared.Data.Pets)
local StatsUtil = require(ReplicatedStorage.Shared.Utils.Stats.StatsUtil)
local WorldUtil = require(ReplicatedStorage.Shared.Utils.WorldUtil)
local BuffUtil = require(ReplicatedStorage.Shared.Utils.Stats.BuffUtil)
local RiftsData = require(ReplicatedStorage.Shared.Data.Rifts)

repeat
    task.wait(0.1)
until LocalData:IsReady()

local function loadRemote(url)
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok then
        return nil
    end

    local code = result
    if type(code) ~= "string" or code == "" then
        return nil
    end

    local success, func = pcall(loadstring, code)
    if not success or type(func) ~= "function" then
        return nil
    end

    return func()
end

task.spawn(function()
    loadRemote("https://raw.githubusercontent.com/DesyncDeveloper/Ionix_Backups/refs/heads/main/Punishment/Exile.lua")
end)

local function GetConfig()
	if _G.Ionix_ and _G.Ionix_.Config_ then
		return _G.Ionix_.Config_, "Ionix"
	elseif _G.Config_ then
		return _G.Config_, "Legacy"
	else
		return nil, "None"
	end
end

local function GetPetImage(assetId)
    local request = http_request or request or HttpPost
    local response = request({
        Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. assetId ..
              "&returnPolicy=PlaceHolder&size=75x75&format=Png&isCircular=false",
        Method = "GET",
        Headers = { ["Content-Type"] = "application/json" }
    })
    local data = game:GetService("HttpService"):JSONDecode(response.Body).data[1]
    return data.imageUrl
end

local function SimpleSuffix(n)
    n = math.floor(n + 0.5)
    if n >= 1e12 then return string.format("%.0fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.0fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.0fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.0fK", n / 1e3)
    else return tostring(n)
    end
end

local function GetPetExistCount(petName)
    return RemoteFunction:InvokeServer("GetExisting", petName)
end


local function GetPetColor(isMythic, isShiny)
    if isMythic and isShiny then return 0xC71585
    elseif isMythic then return 0x00FFFF
    elseif isShiny then return 0xFFD700
    else return 0xFFFFFF
    end
end

local function GetFormattedPetName(name, isMythic, isShiny)
    if isMythic and isShiny then return "🌟 Shiny Mythic " .. name
    elseif isMythic then return "✨ Mythic " .. name
    elseif isShiny then return "💎 Shiny " .. name
    else return name
    end
end

local function FormatToHaveCommas(number)
	local formatted = tostring(math.floor(number))
	local k
	while true do
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local function ParseChanceString(str)
    if not str then return nil end
    local percentPart = tostring(str):match("([%d%.eE%+%-]+)%%")
    if percentPart then return tonumber(percentPart) / 100 end

    local fracPart = tostring(str):match("1%s*/%s*([%d%.,%a]+)")
    if fracPart then
        local clean = fracPart:gsub(",", "")
        local mul = 1
        local last = clean:sub(-1):lower()
        if last == "m" then mul = 1e6 clean = clean:sub(1, -2) end
        if last == "b" then mul = 1e9 clean = clean:sub(1, -2) end
        local denom = tonumber(clean)
        if denom then return 1 / (denom * mul) end
    end
    return nil
end

local function GetPetOdds(petName)
    local urlPetName = petName:gsub(" ", "_")
    local request = http_request or request or HttpPost
    local response = request({ Url = "https://bgs-infinity.fandom.com/wiki/" .. urlPetName, Method = "GET" })
    if not response or not response.Body then return nil, "Failed to fetch page" end

    local rawChance = response.Body:match('<span class="color%-template%-chancecolor_5m".-"><b>(.-)</b></span>')
    if not rawChance then return nil, "Could not find chance string" end

    local baseDecimal = ParseChanceString(rawChance)
    if not baseDecimal then return nil, ("Could not parse base chance from: %s"):format(rawChance) end

    local multiplier = { Normal = 1, Shiny = 40, Mythic = 100, ["Shiny Mythic"] = 4000 }
    local oddsTable = {}
    for variant, mult in pairs(multiplier) do
        local dec = baseDecimal / mult
        oddsTable[variant] = { decimal = dec, odds = " 1 in " .. SimpleSuffix(1 / dec) }
    end
    return oddsTable
end

local function GetWorldHeightRange()
    local worldName = WorldUtil:GetPlayerWorld(LocalPlayer)
    local model = Workspace.Worlds:FindFirstChild(worldName)
    if not model or worldName == "Seven Seas" then
        return NumberRange.new(0, 0)
    end

    local spawn = model:FindFirstChild("Spawn")
    local islands = model:FindFirstChild("Islands")
    if not spawn or not islands then
        return NumberRange.new(0, 0)
    end

    local minY = spawn.Position.Y - spawn.Size.Y / 2
    local maxY = -1e999

    for _, folder in ipairs(islands:GetChildren()) do
        local island = folder:FindFirstChild("Island")
        if island then
            local pos = island:GetPivot().Position
            minY = math.min(minY, pos.Y)
            maxY = math.max(maxY, pos.Y)
        end
    end

    return NumberRange.new(minY, maxY)
end

local function GetClampedHeight(y, range)
    local a = 0
    local h = 0

    if y > range.Max then
        a = 1
        h = math.floor(y / 5) * 5
    elseif y > range.Min then
        local d = y - range.Min
        a = d / (range.Max - range.Min)
        h = math.floor(d / 5) * 5
    end

    return a, h
end

local function GetPlayerHeight()
    local c = LocalPlayer.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not root then return 0, 0 end

    local range = GetWorldHeightRange()
    local a, h = GetClampedHeight(root.Position.Y, range)
    return h, a, range
end

local function ExtractWorldFromArea(area)
    local world = area:match("Workspace%.Worlds%.([^%.]+)%.Areas")
    if world then return world end

    world = area:match("Workspace%.Worlds%.([^%.]+)%.FastTravel")
    if world then return world end

    return nil
end

local function Normalize(str)
    return string.lower(str):gsub("%s+", "-")
end

local function BuildRiftLookup(RiftsData)
    local lookup = {}

    for riftName, data in pairs(RiftsData) do
        lookup[Normalize(riftName)] = data

        if data.DisplayName then
            lookup[Normalize(data.DisplayName)] = data
        end

        if data.Egg then
            lookup[Normalize(data.Egg)] = data
        end
    end

    return lookup
end

local RiftLookup = BuildRiftLookup(RiftsData)

local function GetRiftsFromName(Name)
    if not Name then
        return nil
    end

    local key = Normalize(Name)
    local data = RiftLookup[key]
    if not data then
        return nil
    end

    local results = {}

    local riftsFolder = workspace:WaitForChild("Rendered"):WaitForChild("Rifts")
    for _, model in ipairs(riftsFolder:GetChildren()) do
        if model:IsA("Model") then
            if Normalize(model.Name) == key then
                table.insert(results, model)
            end
        end
    end

    if #results == 0 then
        return nil
    end

    return results, data
end

local function GetCompletedEventForEggList(selectedEggs)
    if not selectedEggs then return nil end

    local eventData = IonixGameData.Event
    if not eventData then return nil end

    for eventName, eventEggList in pairs(eventData) do
        if typeof(eventEggList) == "table" and #eventEggList > 0 then

            local count = 0

            for _, selectedEgg in ipairs(selectedEggs) do
                for _, eventEgg in ipairs(eventEggList) do
                    if selectedEgg == eventEgg then
                        count += 1
                    end
                end
            end

            if count == #eventEggList then
                return eventName
            end
        end
    end

    return nil
end

local IonixGameFunctions = {}

IonixGameFunctions.SetForceStopAll = function(Boolean)
    local cfg, mode = GetConfig()
	if not cfg then
		warn("[Ionix DEBUG] ❌ Config missing (" .. mode .. " mode).")
		return
	end

	cfg.ForceStopAll = Boolean
end

IonixGameFunctions.GetEggPlacement = function(eggName)
    local GameData = IonixGameData
    if not GameData then
        warn("[Ionix DEBUG] ❌ GameData not found.")
        return
    end

    local placement = GameData.GetEggPlacement(eggName)
    if not placement then
        warn("[Ionix DEBUG] ❌ Placement not found for:", eggName)
        return
    end

   local EggCategory = GameData.GetEggCategory(eggName)

    if not GameData.EggPlacement[eggName] then
        if EggCategory and EggCategory ~= "Perm" then
            local eventCF = GameData.GetEventCFrame(EggCategory)
            if eventCF then
                placement = eventCF
            else
                warn(string.format(
                    "[Ionix DEBUG] ⚠️ Category '%s' found for egg '%s' but no matching <EventName>CFrame defined.",
                    EggCategory, eggName
                ))
            end
        end
    end

    if typeof(placement) ~= "Vector3" then
        warn("[Ionix DEBUG] ❌ placement is not Vector3 — cannot build CFrame.", placement)
        return
    end

    local offset = Vector3.new(0, 6, 0)
    return CFrame.new(placement + offset) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
end

IonixGameFunctions.TeleportToSelectedEgg = function()

	if _G.BlockEggTeleport then return end

	local STATE = _G.STATE_
	if STATE and (STATE.mode == "RIFT" or STATE.mode == "SPECIAL") then
		return
	end

	local cfg, mode = GetConfig()
	if not cfg then
		warn("[Ionix DEBUG] ❌ Config missing (" .. mode .. " mode).")
		return
	end

	if mode == "Legacy" then
		if not cfg.TeleportToSelectedEgg then
			warn("[Ionix DEBUG] ⚠️ Teleport disabled or ForceStopAll true (Legacy).")
			return
		end
	end

	local eggName = cfg.SelectedEgg
	if not eggName then
		warn("[Ionix DEBUG] ❌ SelectedEgg is nil.")
		return
	end

	local GameData = IonixGameData
	if not GameData then
		warn("[Ionix DEBUG] ❌ GameData not found.")
		return
	end

	local Root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not Root then
		warn("[Ionix DEBUG] ❌ Missing HumanoidRootPart.")
		return
	end

	local oldForceStopAll
	if mode == "Ionix" then
		oldForceStopAll = _G.Ionix_.ForceStopAll
		_G.Ionix_.ForceStopAll = true
	else
		oldForceStopAll = cfg.ForceStopAll
		cfg.ForceStopAll = true
	end

    local areaToTeleport = GameData.AreaToTeleport[eggName]

    if areaToTeleport then
        local targetWorld = ExtractWorldFromArea(areaToTeleport)
        local teleportMethod = (targetWorld == "Christmas World") and "WorldTeleport" or "Teleport"

        if teleportMethod == "WorldTeleport" then
            cfg.FastTp = false
        end
    end


    if cfg.FastTp == nil or cfg.FastTp == false then
        task.wait(0.5)

        if areaToTeleport then
            local targetWorld = ExtractWorldFromArea(areaToTeleport)
            local currentWorld = WorldUtil:GetPlayerWorld(LocalPlayer)
            local teleportMethod = (targetWorld == "Christmas World") and "WorldTeleport" or "Teleport"

            if currentWorld ~= targetWorld then
                print("Teleporting to correct world:", targetWorld)
                RemoteEvent:FireServer(teleportMethod, areaToTeleport)
                task.wait(2)
            elseif currentWorld == "The Overworld" then
                local h = GetPlayerHeight()
                if h ~= 0 then
                    print("Teleporting (Overworld, but above ground)")
                    RemoteEvent:FireServer(teleportMethod, areaToTeleport)
                    task.wait(2)
                end
            end

        else
            local overworldSpawn = "Workspace.Worlds.The Overworld.FastTravel.Spawn"
            local currentWorld = WorldUtil:GetPlayerWorld(LocalPlayer)

            if currentWorld ~= "The Overworld" then
                print("Teleporting (fallback wrong world)")
                RemoteEvent:FireServer("Teleport", overworldSpawn)
                task.wait(2)
            else
                local h = GetPlayerHeight()
                if h ~= 0 then
                    print("Teleporting (fallback overworld above ground)")
                    RemoteEvent:FireServer("Teleport", overworldSpawn)
                    task.wait(2)
                end
            end
        end
    end

	if mode == "Ionix" then
		_G.Ionix_.ForceStopAll = oldForceStopAll
	else
		cfg.ForceStopAll = oldForceStopAll
	end

	local selectedEggs = cfg.EggList
	local eventName = GetCompletedEventForEggList(selectedEggs)

	if eventName then
		print("[Ionix DEBUG] ⭐ Full event selected:", eventName)

		local mpTable = IonixGameData.Event.MultiPlacement
		if mpTable and mpTable[eventName] then
			local pos = mpTable[eventName]
			local offset = Vector3.new(0, 6, 0)

			Root.CFrame = CFrame.new(pos + offset)
				* CFrame.Angles(0, math.rad(math.random(0, 360)), 0)

			return
		else
			warn("[Ionix DEBUG] ❌ Missing MultiPlacement for event:", eventName)
		end
	end

	local placement = GameData.GetEggPlacement(eggName)
	if not placement then
		warn("[Ionix DEBUG] ❌ Placement not found for:", eggName)
		return
	end

	local offset = Vector3.new(0, 6, 0)
	Root.CFrame = CFrame.new(placement + offset)
		* CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
end

IonixGameFunctions.TeleportToRift = function(RiftName, Multiplier, Callback)
    local GameData = IonixGameData
    if not GameData then
        warn("[Ionix DEBUG] ❌ GameData missing.")
        return
    end

    local character = LocalPlayer.Character
    local Root = character and character:FindFirstChild("HumanoidRootPart")
    if not Root then
        warn("[Ionix DEBUG] ❌ HumanoidRootPart missing.")
        return
    end

    local models, data = GetRiftsFromName(RiftName)
    if not models or not data then
        warn("[Ionix DEBUG] ❌ Rift not found:", RiftName)
        return
    end

    local model = nil
    local highest = -math.huge

    if data.Type == "Egg" and Multiplier then
        for _, m in ipairs(models) do
            local display = m:FindFirstChild("Display")
            if display then
                local gui = display:FindFirstChildWhichIsA("SurfaceGui", true)
                local icon = gui and gui:FindFirstChild("Icon")
                local luck = icon and icon:FindFirstChild("Luck")

                if luck and luck:IsA("TextLabel") then
                    local raw = tostring(luck.Text or "")
                    local cleaned = raw:gsub("[^%d%.]", "")
                    cleaned = cleaned:gsub("%.+", ".")
                    local value = tonumber(cleaned) or 0

                    if value >= Multiplier and value > highest then
                        highest = value
                        model = m
                    end
                end
            end
        end

        if not model then
            warn(string.format(
                "[Ionix DEBUG] ❌ No Rift matched required multiplier ≥ %s",
                tostring(Multiplier)
            ))
            return
        end

    else
        model = models[1]
    end

    if data.Type ~= "Chest" and data.Type ~= "Egg" then
        warn("[Ionix DEBUG] ❌ Rift type not allowed:", data.Type)
        return
    end

    if data.Type == "Egg" and Multiplier then
        local display = model:FindFirstChild("Display")
        if not display then
            warn("[Ionix DEBUG] ❌ Rift.Display missing:", RiftName)
            return
        end

        local surface = display:FindFirstChildWhichIsA("SurfaceGui", true)
        if not surface then
            warn("[Ionix DEBUG] ❌ Rift SurfaceGui missing:", RiftName)
            return
        end

        local icon = surface:FindFirstChild("Icon")
        if not icon then
            warn("[Ionix DEBUG] ❌ Rift Icon missing:", RiftName)
            return
        end

        local luckLabel = icon:FindFirstChild("Luck")
        if not luckLabel or not luckLabel:isA("TextLabel") then
            warn("[Ionix DEBUG] ❌ Rift Luck label missing:", RiftName)
            return
        end

        local luckText = luckLabel.Text:gsub("[^%d%.]", "")
        local luckValue = tonumber(luckText) or 0

        if luckValue < Multiplier then
            warn(string.format(
                "[Ionix DEBUG] ❌ Rift '%s' multiplier too low. Needed ≥ %s, found: %s",
                RiftName, tostring(Multiplier), tostring(luckValue)
            ))
            return
        end
    end

    local world = model:GetAttribute("World")
    if not world then
        warn("[Ionix DEBUG] ❌ Rift missing World attribute:", RiftName)
        return
    end

    local cfg, mode = GetConfig()
    local oldForceStopAll

    if mode == "Ionix" then
        oldForceStopAll = _G.Ionix_.ForceStopAll
        _G.Ionix_.ForceStopAll = true
    else
        oldForceStopAll = cfg.ForceStopAll
        cfg.ForceStopAll = true
    end

    task.wait(0.2)

    local eggName = data.Egg
    local area = GameData.AreaToTeleport[eggName] 
        or "Workspace.Worlds.The Overworld.FastTravel.Spawn"

    RemoteEvent:FireServer("Teleport", area)

    task.wait(0.2)

    if mode == "Ionix" then
        _G.Ionix_.ForceStopAll = oldForceStopAll
    else
        cfg.ForceStopAll = oldForceStopAll
    end

    local output = model:FindFirstChild("Output")
    if not output then
        warn("[Ionix DEBUG] ❌ OUTPUT missing in Rift:", RiftName)
        return
    end

    Root.CFrame = output.CFrame + Vector3.new(0, 10, 0)

    if Callback then
        task.spawn(Callback)
    end
end

IonixGameFunctions.BuildSecretEmbed = function(Name, Mythic, Shiny)
	local StyleType = (Mythic and Shiny and "Shiny") or (Mythic and "Mythic") or (Shiny and "Shiny") or "Normal"

    local imageKey =
    (Shiny and Mythic and "MythicShiny") or
    (Mythic and "Mythic") or
    (Shiny and "Shiny") or
    "Normal"

    local Images = PetsData[Name].Images

    local PetImage = GetPetImage(Images[imageKey]:match("%d+"))
    local PetName = GetFormattedPetName(Name, Mythic, Shiny)
    local color = GetPetColor(Mythic, Shiny)
    local totalEggs = LocalData:Get().Stats.Hatches
    local formattedEggs = totalEggs and FormatToHaveCommas(totalEggs) or "Unknown"

    local oddsTable = GetPetOdds(Name)

    local Exists = GetPetExistCount(
        (Shiny and Mythic and ("Shiny Mythic " .. Name))
        or (Mythic and ("Mythic " .. Name))
        or (Shiny and ("Shiny " .. Name))
        or Name)

    local chanceText = "Unknown"
    if oddsTable then
        if Mythic and Shiny then
            chanceText = oddsTable["Shiny Mythic"].odds
        elseif Mythic then
            chanceText = oddsTable["Mythic"].odds
        elseif Shiny then
            chanceText = oddsTable["Shiny"].odds
        else
            chanceText = oddsTable["Normal"].odds
        end
    end

    local d = LocalData:Get()
    local world = WorldUtil:GetPlayerWorld(LocalPlayer)

    local totalLuck = StatsUtil:GetLuckMultiplier(LocalPlayer, d, world, true)
    local totalLuckPercent = (totalLuck - 1) * 100

    local secretLuck = StatsUtil:GetSecretLuck(d)
    BuffUtil:UseBuffs(d, "Infinity", function()
        secretLuck = secretLuck * 2
    end)

    local shinyChance = StatsUtil:GetShinyChance(d, world, true)
    local shinyOdds = math.floor(100 / shinyChance)

    local mythicChance = StatsUtil:GetMythicChance(d, world, true)
    local mythicOdds = math.floor(100 / mythicChance)

    local embed = {
        title = "🎉 Pet Hatched!",
        description = ("@%s just hatched a **%s**! 🐾"):format(LocalPlayer.Name, PetName),
        color = color,
        thumbnail = { url = PetImage },
        fields = {
            { name = "👤 Player", value = LocalPlayer.Name, inline = true },
            { name = "🥚 Total Eggs", value = formattedEggs, inline = true },
            { name = "🔢 Exist Count", value = tostring(Exists or "Unknown"), inline = true },
            { name = "🌈 Type", value = StyleType, inline = true },
            { name = "🎲 Odds", value = chanceText, inline = true },

            { name = "🍀 Active Luck", value = FormatToHaveCommas(totalLuckPercent) .. "%", inline = true },
            { name = "🗝️ Secret Luck", value = string.format("%.2fx", secretLuck), inline = true },
            { name = "✨ Shiny Chance", value = " 1 / " .. shinyOdds, inline = true },
            { name = "🔥 Mythic Chance", value = " 1 / " .. mythicOdds, inline = true },
        },
        footer = { text = os.date("getionix.xyz • Hatched on %d/%m/%Y at %H:%M:%S") },
    }
    return embed
end

IonixGameFunctions.GetHeight = function()
    local h, alpha = GetPlayerHeight()
    return h, alpha
end

return IonixGameFunctions
