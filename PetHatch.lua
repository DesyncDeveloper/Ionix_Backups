if _G.Config_.ValidNotifyPets == nil then
    _G.Config_.ValidNotifyPets = {
        ["Secret"] = true
    }
end

-- Services & Modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetsData = require(ReplicatedStorage.Shared.Data.Pets)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Framework = Shared:WaitForChild("Framework")
local Network = Framework:WaitForChild("Network")
local Remote = Network:WaitForChild("Remote")

local RemoteEvent = Remote:WaitForChild("RemoteEvent")

-- Load webhook module
local Webhook = loadstring(game:HttpGet("https://raw.githubusercontent.com/DesyncWasHereV2/Webhook/refs/heads/main/Webhook.lua"))()
if not _G.Config_ or not _G.Config_.Webhooks then
    warn("[Webhook] ❌ _G.Config_.Webhooks not found. Script aborted.")
    return
end

local IonixGameFunctions = loadstring(game:HttpGet("https://raw.githubusercontent.com/DesyncDeveloper/Ionix_Backups/refs/heads/main/IonixGameFunctions.lua"))()

local webhookURL = _G.Config_.Webhooks.Pet or _G.Config_.Webhooks.Join
if not webhookURL or webhookURL == "" then
    warn("[Webhook] ❌ No valid webhook found (Pet or Join). Script aborted.")
    return
end

local webhookInstance = Webhook.new(webhookURL, {})

local function sendPetHatchWebhook(embed)
    webhookInstance:Edit({
        embeds = { embed }
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
                    sendPetHatchWebhook(IonixGameFunctions.BuildSecretEmbed(Name, Mythic, Shiny))
                end
            end
        end
    end
end)
