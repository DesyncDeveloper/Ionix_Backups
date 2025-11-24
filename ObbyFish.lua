
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Framework = Shared:WaitForChild("Framework")
local Network = Framework:WaitForChild("Network")
local Remote = Network:WaitForChild("Remote")
local RemoteEvent = Remote:WaitForChild("RemoteEvent")

local LocalData = require(ReplicatedStorage.Client.Framework.Services.LocalData)
local Time = require(ReplicatedStorage.Shared.Framework.Utilities.Math.Time)
local FishingWorldAutoFish = require(ReplicatedStorage.Client.Gui.Frames.Fishing.FishingWorldAutoFish)


if not LocalData:IsReady() then
	repeat task.wait() print("Awaiting game data to load.") until LocalData:IsReady()
end

local data = LocalData:Get()

local function TeleportToFishSpot()
	local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local HRP = Character:WaitForChild("HumanoidRootPart", 5)
	if HRP then
		HRP.CFrame = CFrame.new(
			-41492.0859, 8.07556152, -20471.377,
			-0.721212745, -7.3984876e-09, -0.692713618,
			-2.59595424e-07, 1, 2.59595083e-07,
			0.692713618, 3.67048585e-07, -0.721212745
		)
	end
end

local function ResetRod()
	local args1 = {"UnequipRod"}
	RemoteEvent:FireServer(unpack(args1))
	task.wait(0.1)
	local args2 = {"EquipRod"}
	RemoteEvent:FireServer(unpack(args2))
end

local function ClickAutoFish()
	local AutoFishButton = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("ScreenGui"):WaitForChild("HUD"):WaitForChild("AutoFish"):WaitForChild("Button")
	local Signals = {"Activated", "MouseButton1Down", "MouseButton2Down", "MouseButton1Click", "MouseButton2Click"}

	if not AutoFishButton then
		warn("[Ionix DEBUG] AutoFish button not found.")
		return
	end

	local function fireAllSignals(button)
		for _, Signal in ipairs(Signals) do
			pcall(firesignal, button[Signal])
			task.wait(0.05)
		end
	end

	task.spawn(function()
		fireAllSignals(AutoFishButton)
		task.wait(0.1)
		fireAllSignals(AutoFishButton)
	end)
end

TeleportToFishSpot()
task.wait(0.5)
ResetRod()
task.wait(0.5)

if FishingWorldAutoFish.IsEnabled() == false then
    FishingWorldAutoFish:Toggle()
end

while _G.AutoFishObby == true do
	for i, v in pairs(data.ObbyCooldowns) do
		local CurrentTime = Time.now()
		if v and v < CurrentTime then
			if _G.Config_ then
                _G.Config_.ForceStopAll = true
            end

            if _G.Ionix_ then
                _G.Ionix_.ForceStopAll = true
            end
            FishingWorldAutoFish:Toggle()
			task.wait(2)
			RemoteEvent:FireServer("StartObby", i)
			task.wait(0.2)
			RemoteEvent:FireServer("CompleteObby")
			task.wait(0.2)

			TeleportToFishSpot()
			task.wait(0.5)
			ResetRod()
			task.wait(0.5)
			FishingWorldAutoFish:Toggle()
        end
	end

    if FishingWorldAutoFish.IsEnabled() == false then
        FishingWorldAutoFish:Toggle()
    end


	task.wait(0.1)
end
