-- Initialize valid notify pets if not already set
if _G.Config_.ValidNotifyPets == nil then
    _G.Config_.ValidNotifyPets = {
        ["Secret"] = true
    }
end

-- Services & Modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local PetsData = require(ReplicatedStorage.Shared.Data.Pets)

local StatsUtil = require(ReplicatedStorage.Shared.Utils.Stats.StatsUtil)
local WorldUtil = require(ReplicatedStorage.Shared.Utils.WorldUtil)
local BuffUtil = require(ReplicatedStorage.Shared.Utils.Stats.BuffUtil)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Framework = Shared:WaitForChild("Framework")
local Network = Framework:WaitForChild("Network")
local Remote = Network:WaitForChild("Remote")

local RemoteEvent = Remote:WaitForChild("RemoteEvent")
local RemoteFunction = Remote:WaitForChild("RemoteFunction")

-- Wait until LocalData is ready
if not LocalData:IsReady() then
    repeat task.wait() until LocalData:IsReady()
end

-- Load webhook module
local Webhook = loadstring(game:HttpGet("https://raw.githubusercontent.com/DesyncWasHereV2/Webhook/refs/heads/main/Webhook.lua"))()
if not _G.Config_ or not _G.Config_.Webhooks then
    warn("[Webhook] ❌ _G.Config_.Webhooks not found. Script aborted.")
    return
end

local webhookURL = _G.Config_.Webhooks.Pet or _G.Config_.Webhooks.Join
if not webhookURL or webhookURL == "" then
    warn("[Webhook] ❌ No valid webhook found (Pet or Join). Script aborted.")
    return
end

local webhookInstance = Webhook.new(webhookURL, {})

-- Utility Functions
local function GetImage(assetId)
    local request = http_request or request or HttpPost
    local response = request({
        Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. assetId ..
              "&returnPolicy=PlaceHolder&size=75x75&format=Png&isCircular=false",
        Method = "GET",
        Headers = { ["Content-Type"] = "application/json" }
    })
    local data = HttpService:JSONDecode(response.Body).data[1]
    return data.imageUrl
end

local function formatWithCommas(number)
    local formatted = tostring(math.floor(number))
    while true do
        local k
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

local function formatSuffix(n)
    n = math.floor(n + 0.5)
    if n >= 1e12 then return string.format("%.0fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.0fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.0fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.0fK", n / 1e3)
    else return tostring(n)
    end
end

local function getRuffExistCount(petName)
    return RemoteFunction:InvokeServer("GetExisting", petName)
end

local function getPetColor(isMythic, isShiny)
    if isMythic and isShiny then return 0xC71585
    elseif isMythic then return 0x00FFFF
    elseif isShiny then return 0xFFD700
    else return 0xFFFFFF
    end
end

local function getFormattedPetName(name, isMythic, isShiny)
    if isMythic and isShiny then return "🌟 Shiny Mythic " .. name
    elseif isMythic then return "✨ Mythic " .. name
    elseif isShiny then return "💎 Shiny " .. name
    else return name
    end
end

local function parseChanceString(str)
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

local function getPetOdds(petName)
    local urlPetName = petName:gsub(" ", "_")
    local request = http_request or request or HttpPost
    local response = request({ Url = "https://bgs-infinity.fandom.com/wiki/" .. urlPetName, Method = "GET" })
    if not response or not response.Body then return nil, "Failed to fetch page" end

    local rawChance = response.Body:match('<span class="color%-template%-chancecolor_5m".-"><b>(.-)</b></span>')
    if not rawChance then return nil, "Could not find chance string" end

    local baseDecimal = parseChanceString(rawChance)
    if not baseDecimal then return nil, ("Could not parse base chance from: %s"):format(rawChance) end

    local multiplier = { Normal = 1, Shiny = 40, Mythic = 100, ["Shiny Mythic"] = 4000 }
    local oddsTable = {}
    for variant, mult in pairs(multiplier) do
        local dec = baseDecimal / mult
        oddsTable[variant] = { decimal = dec, odds = " 1 in " .. formatSuffix(1 / dec) }
    end
    return oddsTable
end

local function sendPetHatchWebhook(Name, Mythic, Shiny)
    local player = Players.LocalPlayer
    local Images = PetsData[Name].Images

    local StyleType = (Mythic and Shiny and "Shiny") or (Mythic and "Mythic") or (Shiny and "Shiny") or "Normal"

    local imageKey =
    (Shiny and Mythic and "MythicShiny") or
    (Mythic and "Mythic") or
    (Shiny and "Shiny") or
    "Normal"

    local PetImage = GetImage(Images[imageKey]:match("%d+"))
    local PetName = getFormattedPetName(Name, Mythic, Shiny)
    local ExistName = Name

    if Shiny and Mythic then
        ExistName = "Shiny Mythic " .. Name
    elseif Mythic then
        ExistName = "Mythic " .. Name
    elseif Shiny then
        ExistName = "Shiny " .. Name
    else
        ExistName = Name
    end

    local Exists = getRuffExistCount(ExistName)
    local color = getPetColor(Mythic, Shiny)
    local totalEggs = LocalData:Get().Stats.Hatches
    local formattedEggs = totalEggs and formatWithCommas(totalEggs) or "Unknown"

    local oddsTable = getPetOdds(Name)
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
    local world = WorldUtil:GetPlayerWorld(Players.LocalPlayer)

    local totalLuck = StatsUtil:GetLuckMultiplier(Players.LocalPlayer, d, world, true)
    local totalLuckPercent = (totalLuck - 1) * 100

    local secretLuck = StatsUtil:GetSecretLuck(d)
    BuffUtil:UseBuffs(d, "Infinity", function()
        secretLuck = secretLuck * 2
    end)

    local shinyChance = StatsUtil:GetShinyChance(d, world, true)
    local shinyOdds = math.floor(100 / shinyChance)

    local mythicChance = StatsUtil:GetMythicChance(d, world, true)
    local mythicOdds = math.floor(100 / mythicChance)

    webhookInstance:Edit({
        embeds = {{
            title = "🎉 Pet Hatched!",
            description = ("@%s just hatched a **%s**! 🐾"):format(player.Name, PetName),
            color = color,
            thumbnail = { url = PetImage },
            fields = {
                { name = "👤 Player", value = player.Name, inline = true },
                { name = "🥚 Total Eggs", value = formattedEggs, inline = true },
                { name = "🔢 Exist Count", value = tostring(Exists or "Unknown"), inline = true },
                { name = "🌈 Type", value = StyleType, inline = true },
                { name = "🎲 Odds", value = chanceText, inline = true },

                { name = "🍀 Active Luck", value = formatWithCommas(totalLuckPercent) .. "%", inline = true },
                { name = "🗝️ Secret Luck", value = string.format("%.2fx", secretLuck), inline = true },
                { name = "✨ Shiny Chance", value = " 1 / " .. shinyOdds, inline = true },
                { name = "🔥 Mythic Chance", value = " 1 / " .. mythicOdds, inline = true },
            },
            footer = { text = os.date("getionix.xyz • Hatched on %d/%m/%Y at %H:%M:%S") },
        }},
    })
    webhookInstance:Post()
end

RemoteEvent.OnClientEvent:Connect(function(eventName, eggData)
    if tostring(eventName):lower():find("hatch") then
        for _, v in pairs(eggData.Pets) do
            local pet = v.Pet
            if not v.Deleted and pet.Type == "Pet" then
                local Name, Mythic, Shiny = pet.Name, pet.Mythic, pet.Shiny
                if _G.Config_.ValidNotifyPets[PetsData[Name].Rarity] then
                    sendPetHatchWebhook(Name, Mythic, Shiny)
                end
            end
        end
    end
end)
