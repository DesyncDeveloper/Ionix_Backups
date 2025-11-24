-- Developer Only

local VALID_PLACE_ID = 85896571713843
local VALID_GAME_ID  = 6504986360

if game.PlaceId ~= VALID_PLACE_ID or game.GameId ~= VALID_GAME_ID then
    warn("[Loader] ⚠️ Not a valid game. Loader stopped.")
    return
end

_G.Config_ = _G.Config_ or {}

_G.Config_.Debug = _G.Config_.Debug or false
_G.Config_.AutoBubbleEnabledMaxThreads = _G.Config_.AutoBubbleEnabledMaxThreads or false
_G.Config_.AutoHatchEnabledMaxThreads = _G.Config_.AutoHatchEnabledMaxThreads or false
_G.Config_.AtSpecialEgg = false
_G.Running = _G.Running or false

_G.Config_.ForceStopBubble = false
_G.Config_.ForceStopEgg = false

if type(_G.Config_.EggDistanceThreshold) ~= "number" then
    _G.Config_.EggDistanceThreshold = 15
end

local Webhook = loadstring(game:HttpGet("https://raw.githubusercontent.com/DesyncWasHereV2/Webhook/refs/heads/main/Webhook.lua"))()
local webhookInstance2 = Webhook.new(_G.Config_.Webhooks.Crash, {})

local function ValidateConfig()
    if not _G.Config_ then error("[Loader] ❌ _G.Config missing!") end
    if type(_G.Config_.SelectedEgg) ~= "string" then
        warn("[Loader] ⚠️ SelectedEgg invalid, resetting to default.")
        _G.Config_.SelectedEgg = "Common Egg"
    end
    if type(_G.Config_.EggList) ~= "table" then
        _G.Config_.EggList = { _G.Config_.SelectedEgg }
        warn("[Loader] ⚠️ EggList missing, using SelectedEgg only.")
    end
    if type(_G.Config_.EggChangeTime) ~= "number" or _G.Config_.EggChangeTime <= 0 then
        _G.Config_.EggChangeTime = 300
        warn("[Loader] ⚠️ Invalid EggChangeTime, defaulted to 300s.")
    end
end

local function noDataLoadEmbed(player, webhookInstance2)
    local imageUrl = "https://media.discordapp.net/attachments/1434584392415580293/1434584447289786419/standard_3.gif?width=230&height=230"
    local url = ("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%s&size=420x420&format=Png&isCircular=false"):format(player.UserId)

    pcall(function()
        local res = request({
            Url = url,
            Method = "GET"
        })

        if res and res.Success and res.Body then
            local body = res.Body:gsub("\\/", "/")
            local urlMatch = body:match('"imageUrl"%s*:%s*"(https?://[^"]+)"')
            if urlMatch and urlMatch:find("rbxcdn", 1, true) then
                imageUrl = urlMatch
            end
        end
    end)

    local embed = {
        title = "💀 User Kicked",
        description = string.format("```%s was removed from the session.```", player.Name),
        color = 16711680,
        fields = {
            {
                name = "🧾 Reason",
                value = "Data Not Loaded",
                inline = false
            }
        },
        author = {
            name = player.Name,
            icon_url = imageUrl
        },
        footer = {
            text = "getionix.xyz"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        thumbnail = {
            url = imageUrl
        }
    }

    pcall(function()
        webhookInstance2:Edit({
            embeds = {embed}
        })
        webhookInstance2:Post()
    end)
end

ValidateConfig()

task.spawn(function()
    while task.wait(30) do
        local player = game.Players.LocalPlayer
        if player:FindFirstChild("leaderstats") == nil then
            noDataLoadEmbed(player, webhookInstance2)
            player:Kick("Data Not Loaded")
            break
        end
    end
end)

if _G.Running then
    return
end

_G.Running = true

-- Services

task.spawn(function()
    game:GetService("Players").LocalPlayer.Idled:Connect(function()
        game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
        task.wait(1)
        game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
    end)
end)

local OldForceStop = _G.Config_.ForceStopAll

_G.Config_.ForceStopAll = true

repeat
    task.wait(0.1)
    print("Awating game to load.")
until game:IsLoaded() and game:GetService("Players") and game:GetService("Players").LocalPlayer

print("Game Loaded — Secondary Wait Running")

for i = 10, 1, -1 do
    print("Starting in " .. i .. "...")
    task.wait(1)
end

print("Script Running!")

local STATE = {
    mode = "IDLE",
    engagedRift = nil,
    engagedRiftLuck = 0,
    savedEgg = nil,
    savedEggSwap = nil,
    savedMoveSpecial = nil,
    savedForceStop = nil,
    savedCanProceedSpecial = nil,
    savedCanProceedRift = nil,
    lastSpecialModel = nil,
}

if _G.STATE_ == nil then
    _G.STATE_ = STATE
end

local GameData = loadstring(game:HttpGet("https://raw.githubusercontent.com/DesyncDeveloper/Ionix_Backups/refs/heads/main/GameData.lua"))()
local IonixGameFunctions = loadstring(game:HttpGet("https://raw.githubusercontent.com/DesyncDeveloper/Ionix_Backups/refs/heads/main/IonixGameFunctions.lua"))()
local PetHatchWebhook = loadstring(game:HttpGet("https://raw.githubusercontent.com/DesyncDeveloper/Ionix_Backups/refs/heads/main/PetHatch.lua"))()

local webhookInstance = Webhook.new(_G.Config_.Webhooks.Join, {})

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Root = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local StatsUtil = require(ReplicatedStorage.Shared.Utils.Stats.StatsUtil)
local FormatSuffix = require(ReplicatedStorage.Shared.Framework.Utilities.String.FormatSuffix)
local EggRendering = require(ReplicatedStorage.Client.Effects.HatchEgg)
local AFKReport = require(ReplicatedStorage.Client.AFKReport)

local Rendered = Workspace:WaitForChild("Rendered")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Framework = Shared:WaitForChild("Framework")
local Network = Framework:WaitForChild("Network")
local Remote = Network:WaitForChild("Remote")
local RemoteEvent = Remote:WaitForChild("RemoteEvent")

local function waitForLocalData(LocalData, webhookInstance2)
    local player = game.Players.LocalPlayer
    local timeout = 30
    local start = tick()

    print("Awaiting game data to load...")

    repeat
        task.wait(1)
        if LocalData:IsReady() then
            print("✅ LocalData loaded successfully.")
            return true
        end
    until tick() - start > timeout

    warn("[Ionix DEBUG] ❌ LocalData failed to load within timeout.")
    noDataLoadEmbed(player, webhookInstance2)
    player:Kick("LocalData failed to load (Timeout)")
    return false
end

waitForLocalData(LocalData, webhookInstance2)

local data = LocalData:Get()
local teams = data and data.Teams

local hatchingTeam = teams and teams[_G.Config_.HatchingTeam]
local bubblingTeam = teams and teams[_G.Config_.BubblingTeam]

-- Flags
local bubbleThreadsActive = false
local eggThreadsActive = false

local Playtime = data.Stats.Playtime
local Bubbles =  data.Stats.Bubbles
local Hatches =  data.Stats.Hatches

local CanProceedMoveToSpecialEgg = false
local CanProceedMoveToRiftEgg = false

if not (hatchingTeam and hatchingTeam.Pets and bubblingTeam and bubblingTeam.Pets) then
	warn("Missing team or pet data")
	return
end

-- ===============================
-- Utility Functions
-- ===============================

local function formatWithCommas(number)
	local formatted = tostring(math.floor(number))
	local k
	while true do
		formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local function shortSuffix(num)
	if num >= 1e12 then
		return string.format("%.1fT", num / 1e12)
	elseif num >= 1e9 then
		return string.format("%.1fB", num / 1e9)
	elseif num >= 1e6 then
		return string.format("%.1fM", num / 1e6)
	elseif num >= 1e3 then
		return string.format("%.1fK", num / 1e3)
	else
		return tostring(num)
	end
end

local function formatPlaytime(seconds)
	local timeUnits = {
		{name = "Months", value = 30*24*3600},
		{name = "Days", value = 24*3600},
		{name = "Hours", value = 3600},
		{name = "Mins", value = 60},
		{name = "Secs", value = 1}
	}
	local result = {}
	for _, unit in ipairs(timeUnits) do
		local amount = math.floor(seconds / unit.value)
		if amount > 0 then
			table.insert(result, string.format("%d %s", amount, unit.name))
			seconds -= amount * unit.value
		end
	end
	return #result == 0 and " 0 Secs" or table.concat(result, " ")
end

local function sendWebhook(userId, playerName, playtime, bubbles, eggs)
	local imageUrl = "https://media.discordapp.net/attachments/1434584392415580293/1434584447289786419/standard_3.gif?width=230&height=230"

    local url = ("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%s&size=420x420&format=Png&isCircular=false"):format(userId)

    local res = request({
		Url = url,
		Method = "GET"
	})

    if res then
		if res.Success and res.Body then
			local body = res.Body:gsub("\\/", "/")
			local urlMatch = body:match('"imageUrl"%s*:%s*"(https?://[^"]+)"')

			if urlMatch and urlMatch:find("rbxcdn", 1, true) then
				imageUrl = urlMatch
			end
		end
	end

	local embed = {
		title = "🧠 Script Joined Server",
		description = "```The script has started in a new server.```",
		color = 13455046,
		fields = {
			{
				name = "🫧 Total Bubbles",
				value = string.format("**%s** (`%s`)", formatWithCommas(bubbles), FormatSuffix(bubbles)),
				inline = true
			},
			{
				name = "🥚 Total Eggs",
				value = string.format("**%s** (`%s`)", formatWithCommas(eggs), shortSuffix(eggs)),
				inline = true
			},
			{
				name = "⏱️ Playtime",
				value = "**" .. formatPlaytime(playtime) .. "**"
			}
		},
		author = {
			name = playerName .. " joined a new server!",
			icon_url = imageUrl
		},
		footer = {
			text = "getionix.xyz"
		},
		timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
		thumbnail = {
			url = imageUrl
		}
	}

	webhookInstance:Edit({
		embeds = {embed}
	})
	webhookInstance:Post()
end

local function equipTeam(teamIndex)
    if teamIndex == _G.Config_.HatchingTeam then
        RemoteEvent:FireServer("EquipTeam", _G.Config_.HatchingTeam)
    elseif teamIndex == _G.Config_.BubblingTeam then
        RemoteEvent:FireServer("EquipTeam", _G.Config_.BubblingTeam)
    end
end

local function getClosestSpecialEgg()
    if not Root then return end

    local closestEgg = nil
    local closestDistance = math.huge

    for _, obj in ipairs(Rendered:GetDescendants()) do
        if obj:IsA("Model") and obj.Parent and obj.Parent.Name == "Chunker" then
            local eggPrimary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if eggPrimary then
                local distance = (Root.Position - eggPrimary.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestEgg = obj
                end
            end
        end
    end

    if closestEgg and closestDistance <= _G.Config_.EggDistanceThreshold then
        _G.Config_.SelectedEgg = closestEgg.Name
        warn("[ClosestSpecialEgg] SelectedEgg set to:", closestEgg.Name)
        return closestEgg, closestDistance
    else
        warn("[ClosestSpecialEgg] No egg found within threshold")
        return nil, closestDistance
    end
end

local function getClosestEgg(eggName, IgnoreDistance)
    if not Root then return nil end

    local closestEgg = nil
    local closestDistance = math.huge

    for _, obj in ipairs(Rendered:GetDescendants()) do
        if obj:IsA("Model") and obj.Name == eggName and obj.Parent and obj.Parent.Name == "Chunker" then
            local eggPrimary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if eggPrimary then
                local distance = (Root.Position - eggPrimary.Position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestEgg = obj
                end
            end
        end
    end

    if IgnoreDistance == true then
        if closestEgg then
            return closestEgg, closestDistance
        else
            return nil, closestDistance
        end
    else
        if closestEgg and closestDistance <= _G.Config_.EggDistanceThreshold then
            return closestEgg, closestDistance
        else
            return nil, closestDistance
        end
    end
end

local function canHatchEgg(egg)
    if not egg then return false, "No egg model" end

    local eggPrimary = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
    if not eggPrimary then
        return false, "No valid PrimaryPart"
    end

    local distance = (Root.Position - eggPrimary.Position).Magnitude
    if distance > _G.Config_.EggDistanceThreshold then
        return false, ("Too far (%.2f studs)"):format(distance)
    end

    return true
end

function autoTeleportToEgg(Why)
    if _G.BlockEggTeleport then return end

    if _G.STATE_.mode ~= "IDLE" or _G.BlockTeleport then
        return
    end

    local oldForceStopAll = _G.Config_.ForceStopAll
    _G.Config_.ForceStopAll = true
    task.wait(0.2)
    IonixGameFunctions.TeleportToSelectedEgg()
    task.wait(0.2)
    if oldForceStopAll == true then
        oldForceStopAll = false
    end
    _G.Config_.ForceStopAll = oldForceStopAll
end


-- ===============================
-- BUBBLE FUNCTIONS
-- ===============================
local function startBubbling()
    if bubbleThreadsActive then return end

    bubbleThreadsActive = true
    _G.Config_.AutoBubbleEnabledMaxThreads = true

   equipTeam(_G.Config_.BubblingTeam)

    for i = 1, _G.Config_.BubbleThreadCount or 1 do
        task.spawn(function()
            while bubbleThreadsActive and not _G.Config_.ForceStopAll and not _G.Config_.ForceStopBubble do
                RemoteEvent:FireServer("BlowBubble")
                task.wait(0.1)
            end
        end)
    end
end

local function stopBubbling()
    bubbleThreadsActive = false
    _G.Config_.ForceStopBubble = false
    _G.Config_.AutoBubbleEnabledMaxThreads = false
end

-- ===============================
-- HATCHING FUNCTIONS
-- ===============================

local function stopHatching()
    eggThreadsActive = false
    _G.Config_.ForceStopEgg = false
    _G.Config_.AutoHatchEnabledMaxThreads = false
end

local function startHatching()
    if eggThreadsActive then return end

    eggThreadsActive = true
    _G.Config_.AutoHatchEnabledMaxThreads = true

    local egg = getClosestEgg(_G.Config_.SelectedEgg)
    local canHatch, lol = false, ""

    if egg then
        canHatch, lol = canHatchEgg(egg)
    end

    if canHatch then
        equipTeam(_G.Config_.HatchingTeam)

        for i = 1, _G.Config_.EggThreadCount or 1 do
            task.spawn(function()
                while eggThreadsActive and not _G.Config_.ForceStopAll and not _G.Config_.ForceStopEgg do
                    RemoteEvent:FireServer("HatchEgg", _G.Config_.SelectedEgg, StatsUtil:GetMaxEggHatches(LocalData:Get()))
                    task.wait(0.1)
                end
            end)
        end
    else
        stopHatching()
    end
end

-- ===============================
-- UPDATE TEAM / MODE LOGIC
-- ===============================
local function updateMode()
    local egg = getClosestEgg(_G.Config_.SelectedEgg)
    local canHatch = false
    local reason = "Unknown"

    if egg then
        canHatch, reason = canHatchEgg(egg)
    else
        reason = "Egg not found"
    end

    if egg and canHatch then
        if not eggThreadsActive then
            if _G.Config_.Debug then print("[MODE] Switching to HATCHING") end
            startHatching()
        else
            equipTeam(_G.Config_.HatchingTeam)
        end

    else
        if not bubbleThreadsActive then
            if _G.Config_.Debug then print("[MODE] Switching to BUBBLING (".. tostring(reason) ..")") end
            stopHatching()
            startBubbling()
        else
            stopHatching()
            equipTeam(_G.Config_.BubblingTeam)
        end
    end
end


-- ===============================
-- EGG CHECK LOOP
-- ===============================
task.spawn(function()
    while true do
        task.wait(1)

        if not _G.Config_.ForceStopAll then
            updateMode()
        end
    end
end)

local oldPlay = EggRendering.Play
local oldDisplay = EggRendering.DisplayPetOnce

task.spawn(function()
    while true do
        if _G.Config_.HideEggs or _G.Config_.HideEgg then
            EggRendering.Play = function() end
            EggRendering.DisplayPetOnce = function() end
        else
            EggRendering.Play = oldPlay
            EggRendering.DisplayPetOnce = oldDisplay
        end
        task.wait(0.1)
    end
end)

local oldLoad = AFKReport.Load
local oldGet = AFKReport.Get
local oldAddPet = AFKReport.AddPet

local disabled = function() end

task.spawn(function()
	while true do
		if _G.Config_.HideRevealScreen then
			AFKReport.Load   = disabled
			AFKReport.Get    = function() return {} end
			AFKReport.AddPet = disabled
		else
			AFKReport.Load   = oldLoad
			AFKReport.Get    = oldGet
			AFKReport.AddPet = oldAddPet
		end
		task.wait(0.1)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local cfg = _G.Config_
		if not cfg then
			warn("[Ionix] Config missing, skipping HideRevealScreen check.")
			continue
		end

		local gui = LocalPlayer:FindFirstChild("PlayerGui")
		if not gui then continue end

		local screenGui = gui:FindFirstChild("ScreenGui")
		if not screenGui then continue end

		local reveal = screenGui:FindFirstChild("AFKReveal")
		if not reveal then continue end

		if cfg.HideRevealScreen then
			reveal.Visible = false
		end
	end
end)


local defaultEgg = _G.Config_.SelectedEgg
local lastSelected = defaultEgg

-- ===== Utils =====
local function safeTonumber(v)
    local n = tonumber(v)
    return n or 0
end

local function formatName(rawName)
    local words = {}
    for part in string.gmatch(rawName or "", "[^%-]+") do
        table.insert(words, part:sub(1,1):upper() .. part:sub(2):lower())
    end
    return table.concat(words, " ")
end

local function normalize(str)
    return (str or ""):gsub("[%s%-_]", ""):lower()
end

local EventEggsToNames = {
    ["Developer Rift"] = "dev-rift",
    ["Dev Rift"] = "dev-rift",
}

local function resolveRiftTarget(input)
    if not input then return nil end
    local norm = normalize(input)
    for event, egg in pairs(EventEggsToNames) do
        if normalize(event) == norm or normalize(egg) == norm then
            return event
        end
    end
    return input
end

local function riftMatchesName(riftModel, resolvedTarget)
    local rn = normalize(riftModel.Name)
    local tn = normalize(resolvedTarget)
    return rn:find(tn) or tn:find(rn)
end

local function getRiftLuck(riftModel)
    local disp = riftModel:FindFirstChild("Display", true)
    local luckLabel = disp and disp:FindFirstChild("SurfaceGui") and disp.SurfaceGui:FindFirstChild("Icon") and disp.SurfaceGui.Icon:FindFirstChild("Luck")
    if luckLabel and luckLabel:IsA("TextLabel") then
        local num = string.match(luckLabel.Text, "[Xx]%s*([%d%.]+)") or string.match(luckLabel.Text, "([%d%.]+)%s*[Xx]")
        return num and tonumber(num) or nil
    end
    return nil
end

local function findMatchingRift(resolvedTarget, requiredMultiplier)
    local Rifts = workspace:FindFirstChild("Rendered") and workspace.Rendered:FindFirstChild("Rifts")
    if not Rifts then return nil, 0 end
    local best, bestLuck = nil, 0
    for _, r in ipairs(Rifts:GetChildren()) do
        if r:FindFirstChild("Output") and riftMatchesName(r, resolvedTarget) then
            local l = getRiftLuck(r) or 0
            if l >= requiredMultiplier and l >= bestLuck then
                best, bestLuck = r, l
            end
        end
    end
    return best, bestLuck
end

local function riftIsStillValid(riftModel, resolvedTarget, requiredMultiplier)
    if not riftModel then
        return false
    end

    if not riftModel.Parent then
        return false
    end

    if not riftModel:FindFirstChild("Output") then
        return false
    end

    if not riftMatchesName(riftModel, resolvedTarget) then
        return false
    end

    local luck = getRiftLuck(riftModel) or 0
    if luck < requiredMultiplier then
        return false
    end

    return true
end

local function teleportWorld(world)
    if world == "The Overworld" then
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.The Overworld.FastTravel.Spawn")
    elseif world == "Minigame Paradise" then
        RemoteEvent:FireServer("Teleport", "Workspace.Worlds.Minigame Paradise.FastTravel.Spawn")
    end
end

local function saveAndQuiesceSystems(newMode)
    if _G.STATE_.mode == newMode then return end
    if _G.STATE_.savedEgg == nil then
        _G.STATE_.savedEgg = _G.Config_.SelectedEgg
        _G.STATE_.savedEggSwap = _G.Config_.EggSwapEnabled
        _G.STATE_.savedMoveSpecial = _G.Config_.MoveToSpecialEggs
        _G.STATE_.savedForceStop = _G.Config_.ForceStopAll
        _G.STATE_.savedCanProceedSpecial = CanProceedMoveToSpecialEgg
        _G.STATE_.savedCanProceedRift = CanProceedMoveToRiftEgg
    end

    _G.BlockEggTeleport = true
    _G.Config_.EggSwapEnabled = false
    _G.Config_.MoveToSpecialEggs = (newMode == "SPECIAL")
    CanProceedMoveToSpecialEgg = (newMode == "SPECIAL")
    CanProceedMoveToRiftEgg = (newMode == "RIFT")
    _G.Config_.ForceStopAll = false
    _G.STATE_.mode = newMode
end

local function restoreAll(Why)
    if _G.STATE_.savedEgg ~= nil then
        _G.Config_.SelectedEgg = _G.STATE_.savedEgg
        _G.Config_.EggSwapEnabled = _G.STATE_.savedEggSwap or false
        _G.Config_.MoveToSpecialEggs = _G.STATE_.savedMoveSpecial or false
        _G.Config_.ForceStopAll = _G.STATE_.savedForceStop or false
        CanProceedMoveToSpecialEgg = _G.STATE_.savedCanProceedSpecial or false
        CanProceedMoveToRiftEgg = _G.STATE_.savedCanProceedRift or false
    end

    _G.BlockEggTeleport = false

    _G.STATE_.savedEgg = nil
    _G.STATE_.savedEggSwap = nil
    _G.STATE_.savedMoveSpecial = nil
    _G.STATE_.savedForceStop = nil
    _G.STATE_.savedCanProceedSpecial = nil
    _G.STATE_.savedCanProceedRift = nil

    _G.STATE_.engagedRift = nil
    _G.STATE_.engagedRiftLuck = 0
    _G.STATE_.lastSpecialModel = nil
    _G.STATE_.mode = "IDLE"

    _G.Config_.ForceStopAll = false
    task.wait(0.2)
    if typeof(autoTeleportToEgg) == "function" then
        autoTeleportToEgg("Called Restore")
    else
        warn("[Ionix] autoTeleportToEgg() missing.")
    end
end

-- ===============================
-- Default-Egg tracker (when user manually changes)
-- ===============================
task.spawn(function()
	while true do
		local current = _G.Config_.SelectedEgg

		if current and _G.Config_.Egglist then
			local found = false
			for _, egg in ipairs(_G.Config_.Egglist) do
				if egg == current then
					found = true
					break
				end
			end

			if not found then
				warn(string.format("[Ionix] ⚠️ '%s' not found in Egglist — disabling EggSwap.", current))
				_G.Config_.EggSwapEnabled = false
			end
		end

		if current ~= lastSelected then
			if not _G.Config_.EggSwapEnabled
				and not _G.Config_.ForceStopAll
				and _G.STATE_.mode == "IDLE"
			then
				defaultEgg = current
				warn("[EggSwap] Default updated to:", defaultEgg)
			end

			lastSelected = current
		end

		task.wait(0.5)
	end
end)

-- ===============================
-- Auto Swapper (disabled during SPECIAL/RIFT)
-- ===============================
task.spawn(function()
    local index = 1
    while true do
        if _G.STATE_.mode == "IDLE"
        and not _G.Config_.ForceStopAll
        and _G.Config_.EggSwapEnabled
        then
            if _G.Config_.SelectedEgg ~= defaultEgg then
                _G.Config_.SelectedEgg = defaultEgg
                warn("[EggSwap] Started swapping from default:", defaultEgg)
            end

            if _G.Config_.EggList and #_G.Config_.EggList > 0 then
                _G.Config_.SelectedEgg = _G.Config_.EggList[index]
                warn("[EggSwap] Swapped eggs ->", _G.Config_.SelectedEgg)
                index += 1
                if index > #_G.Config_.EggList then index = 1 end
            else
                _G.Config_.SelectedEgg = defaultEgg
                warn("[EggSwap] No EggList; reverted to default:", defaultEgg)
            end

            task.wait(_G.Config_.EggChangeTime)
        else
            index = 1
            task.wait(0.2)
        end
    end
end)

-- ===============================
-- Special Egg Handler (Race-Safe)
-- ===============================
task.spawn(function()
    while true do
        if _G.STATE_.mode ~= "RIFT"
        and not _G.Config_.ForceStopAll
        and _G.Config_.MoveToSpecialEggs
        and CanProceedMoveToSpecialEgg
        then
            local SpecialEgg = workspace:FindFirstChild("SummonedEgg")
            local EggPlatform = SpecialEgg and SpecialEgg:FindFirstChild("EggPlatformSpawn")

            if SpecialEgg and EggPlatform and Humanoid and Root then
                if _G.STATE_.mode ~= "SPECIAL" then
                    saveAndQuiesceSystems("SPECIAL")
                    warn("[Ionix] 🎯 Entered SPECIAL mode")
                    task.wait(0.35)
                end

                _G.STATE_.lastSpecialModel = SpecialEgg
                local EggPlatform = SpecialEgg:FindFirstChild("EggPlatformSpawn")

                if EggPlatform then
                    local cf, size = EggPlatform:GetBoundingBox()
                    local radius = math.max(size.X, size.Z) * 0.5 + 5
                    local distance = (Root.Position - cf.Position).Magnitude

                    if distance > radius then
                        local rx = (math.random() * size.X) - (size.X / 2)
                        local rz = (math.random() * size.Z) - (size.Z / 2)
                        local targetPos = Vector3.new(cf.Position.X + rx, cf.Position.Y + 10, cf.Position.Z + rz)

                        local rayOrigin = targetPos + Vector3.new(0, 100, 0)
                        local rayDir = Vector3.new(0, -200, 0)
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {EggPlatform}
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude

                        local result = workspace:Raycast(rayOrigin, rayDir, rayParams)
                        if result then
                            targetPos = Vector3.new(targetPos.X, result.Position.Y + 5, targetPos.Z)
                        else
                            targetPos += Vector3.new(0, 5, 0)
                        end

                        if Root and Root:IsA("BasePart") then
                            Root.CFrame = CFrame.new(targetPos)
                            task.wait(0.2)
                        else
                            warn("[Ionix] ⚠️ Root missing or invalid; cannot set CFrame.")
                        end

                        local newDist = (Root.Position - cf.Position).Magnitude
                        _G.Config_.AtSpecialEgg = (newDist <= radius)

                        if not _G.Config_.AtSpecialEgg then
                            warn(("[Ionix] ⚠️ After teleport, still outside platform radius (%.1f studs)."):format(newDist))
                        end
                    else
                        _G.Config_.AtSpecialEgg = true
                    end
                else
                    warn("[Ionix] ⚠️ EggPlatform missing, restoring systems.")
                    _G.Config_.AtSpecialEgg = false
                    restoreAll("EggPlatform missing, restoring systems.")
                end

                if typeof(getClosestSpecialEgg) == "function" then
                    local success, closestEgg, dist = pcall(getClosestSpecialEgg)

                    if success then
                        if not closestEgg then
                            warn("[Ionix] ❌ No nearby egg found — restoring to default egg.")
                            _G.Config_.AtSpecialEgg = false
                            restoreAll("No nearby special egg found — restoring to default egg.")
                        else
                            warn(string.format("[Ionix] 🥚 Tracking closest egg '%s' (%.1f studs)", closestEgg.Name, dist))
                        end
                    else
                        warn("[Ionix] ⚠️ getClosestSpecialEgg() errored during call.")
                    end
                end

            else
                if _G.STATE_.mode == "SPECIAL" or _G.STATE_.savedEgg then
                    warn("[Ionix] 🌀 Special Egg ended or vanished — restoring defaults.")
                    _G.Config_.AtSpecialEgg = false
                    restoreAll("🌀 Special Egg ended or vanished — restoring defaults.")
                else
                    _G.Config_.AtSpecialEgg = false
                end
            end

            task.wait(0.2)
        else
            if _G.STATE_.mode == "SPECIAL" and not workspace:FindFirstChild("SummonedEgg") then
                warn("[Ionix] 🧹 Cleanup fallback — restoring (egg gone, still in SPECIAL).")
                restoreAll("🧹 Cleanup fallback — restoring (egg gone, still in SPECIAL).")
            end

            _G.Config_.AtSpecialEgg = false
            task.wait(0.2)
        end
    end
end)

-- ===============================
-- Rift Handler (Priority over Special)
-- ===============================

local lastRiftTP = 0
local RIFT_TP_COOLDOWN = 1.0

task.spawn(function()
	while true do

		if CanProceedMoveToRiftEgg 
		and not _G.Config_.ForceStopAll 
		and _G.Config_.MoveToRifts 
		then

			local requiredMultiplier = math.max(1, safeTonumber(_G.Config_.Multiplier))
			local resolvedTarget = resolveRiftTarget(_G.Config_.RiftName)

			if _G.STATE_.mode == "RIFT" and _G.STATE_.engagedRift then
				
				local engagedName = formatName(_G.STATE_.engagedRift.Name)
				local realEggName = EventEggsToNames[engagedName] or engagedName

				if _G.Config_.SelectedEgg ~= realEggName then
					_G.Config_.SelectedEgg = realEggName
					if typeof(startHatching) == "function" then
						startHatching()
					end
				end

				local valid, reason = riftIsStillValid(_G.STATE_.engagedRift, resolvedTarget, requiredMultiplier)

				if not valid then
                    restoreAll("Rift invalid")
                else
                    local rootPos = Root.Position
                    local riftPos = _G.STATE_.engagedRift.Output.Position
                    local dist = (rootPos - riftPos).Magnitude

                    if dist > 50 and (time() - lastRiftTP) > RIFT_TP_COOLDOWN then
                        lastRiftTP = time()
                        warn("⭐ FORCE TELEPORTING TO RIFT (valid but not near)")
                        
                        local world = _G.STATE_.engagedRift:GetAttribute("World")
                        if world then teleportWorld(world) end

                        Root.CFrame = _G.STATE_.engagedRift.Output.CFrame + Vector3.new(0, 15, 0)
                    end

                    _G.STATE_.engagedRiftLuck = getRiftLuck(_G.STATE_.engagedRift) or _G.STATE_.engagedRiftLuck
                end

			elseif _G.STATE_.mode ~= "SPECIAL" then

				local match, luck = findMatchingRift(resolvedTarget, requiredMultiplier)

				if not match then
					local folder = workspace:FindFirstChild("Rendered") and workspace.Rendered:FindFirstChild("Rifts")
					if folder then
						for _, r in ipairs(folder:GetChildren()) do
							local ok = riftIsStillValid(r, resolvedTarget, requiredMultiplier)
							if ok then
								warn("⭐ Forcing teleport (VALID rift found):", r.Name)
								match = r
								luck = getRiftLuck(r) or 0
								break
							end
						end
					end
				end

				-- ⭐ TELEPORT IF ANY VALID RIFT FOUND
				if match then

					saveAndQuiesceSystems("RIFT")

					local world = match:GetAttribute("World")
					if world then teleportWorld(world) end

					local output = match:FindFirstChild("Output")
					if output then
						Root.CFrame = output.CFrame + Vector3.new(0, 15, 0)
					end

					local formatted = formatName(match.Name)
					local realEggName = EventEggsToNames[formatted] or formatted
					_G.Config_.SelectedEgg = realEggName

					_G.STATE_.engagedRift = match
					_G.STATE_.engagedRiftLuck = luck or 0

					if typeof(startHatching) == "function" then
						startHatching()
					end
				end
			end

		else
			if _G.STATE_.mode == "RIFT" then
				restoreAll("Rift fallback restore")
			end
			task.wait(0.8)
		end

		task.wait(0.4)
	end
end)

task.spawn(function()
    while true do
        if _G.STATE_.mode == "SPECIAL" and not workspace:FindFirstChild("SummonedEgg") then
            warn("[Ionix Watchdog] 🧭 Forcing restore due to missing egg.")
            restoreAll("[Ionix Watchdog] 🧭 Forcing restore due to missing egg.")
        end
        task.wait(60)
    end
end)

task.spawn(function()
    while true do
        
        if _G.Config_.ForceTeleport then
            local character = LocalPlayer.Character
            local Root = character and character:FindFirstChild("HumanoidRootPart")

            if Root then
                local targetEggName = _G.Config_.SelectedEgg
                if targetEggName then

                    local targetCFrame = IonixGameFunctions.GetEggPlacement(targetEggName)

                    if targetCFrame then
                        local targetPos = targetCFrame.Position
                        local dist = (Root.Position - targetPos).Magnitude

                        if dist > 15 then
                            warn("[Ionix WATCHDOG] ⚠️ Distance too high ("..math.floor(dist).."). Forcing teleport.")
                            autoTeleportToEgg("Watchdog Teleport")
                        end
                    else
                        warn("[Ionix WATCHDOG] ❌ No placement returned for egg:", targetEggName)
                    end
                end
            end
        end

        if _G.Config_.ForceTeleportTimer ~= nil then
            task.wait(_G.Config_.ForceTeleportTimer)
        else
            task.wait(0.1)
        end
    end
end)


-- ===============================
-- GLOBAL FORCE STOP
-- ===============================
task.spawn(function()
    while true do
        if _G.Config_.ForceStopAll then
            stopHatching()
            stopBubbling()
        end

        if _G.Config_.ForceStopEgg then
            stopHatching()
        end

        if _G.Config_.ForceStopBubble then
            stopBubbling()
        end
        task.wait(0.1)
    end
end)

-- ===============================
-- INITIAL START
-- ===============================
local Player = game:GetService("Players").LocalPlayer
repeat task.wait() until Player:FindFirstChild("PlayerGui")

local PlayerGui = Player:WaitForChild("PlayerGui")
local ScreenGui = PlayerGui:WaitForChild("ScreenGui")
local HUD = ScreenGui:WaitForChild("HUD")
local Height = HUD:WaitForChild("Height")
local Label = Height:WaitForChild("Label")

repeat task.wait() until HUD:FindFirstChild("Left")
repeat task.wait() until HUD.Left:FindFirstChild("Currency")
repeat task.wait() until HUD.Left.Currency:FindFirstChild("Bubble")
repeat task.wait() until HUD.Left.Currency.Bubble:FindFirstChild("Frame")
repeat task.wait() until HUD.Left.Currency.Bubble.Frame:FindFirstChild("AutoBubble")
repeat task.wait() until HUD.Left.Currency.Bubble.Frame.AutoBubble:FindFirstChild("Button")
repeat task.wait() until HUD.Left.Currency.Bubble.Frame:FindFirstChild("AutoBubble")

Label.TextColor3 = Color3.fromRGB(255, 0, 0)

sendWebhook(
	game.Players.LocalPlayer.UserId,
	game.Players.LocalPlayer.Name,
	Playtime,
	Bubbles,
	Hatches
)

local function safeWaitForPath(path, timeout)
	local start = os.clock()
	repeat
		local obj = path()
		if obj then return obj end
		task.wait()
	until (os.clock() - start) > (timeout or 10)
	return nil
end

local Signals = {"Activated", "MouseButton1Down", "MouseButton2Down", "MouseButton1Click", "MouseButton2Click"}

local function fireAllSignals(button)
    if button then
        task.spawn(function() 
            for i,Signal in pairs(Signals) do
                firesignal(button[Signal])
                task.wait(0.1)
            end
        end)
        task.spawn(function()
            for i,Signal in pairs(Signals) do
                firesignal(button[Signal])
                task.wait(0.1)
            end
        end)
    end
end

local intro = safeWaitForPath(function()
	return PlayerGui:FindFirstChild("Intro")
end, 15)

if _G.Config_.AutoLoadGame == true and intro then
	local playButton = safeWaitForPath(function()
		local play = intro:FindFirstChild("Play")
		return play and play:FindFirstChild("Button")
	end, 15)

	local graphicsButton = safeWaitForPath(function()
		local g = intro:FindFirstChild("Graphics")
		if not g then return nil end
		local content = g:FindFirstChild("Content")
		if not content then return nil end
		local low = content:FindFirstChild("Low")
		if not low then return nil end
		local action = low:FindFirstChild("Action")
		if not action then return nil end
		return action:FindFirstChild("Button")
	end, 15)

	if playButton then
		fireAllSignals(playButton)
		task.wait(1)
	end

	if graphicsButton then
		fireAllSignals(graphicsButton)
	end
end

for i = 5, 1, -1 do
    print("Finalizing script " .. i .. "...")
    task.wait(1)
end

CanProceedMoveToSpecialEgg = false
CanProceedMoveToRiftEgg = false
_G.Config_.ForceStopAll = false
autoTeleportToEgg("System Started")
CanProceedMoveToSpecialEgg = true
CanProceedMoveToRiftEgg = true
_G.Config_.ForceStopAll = OldForceStop
