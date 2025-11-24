local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local EggsModule

local module = {}
module._lists = {}

local IONIX_ASSET_ID = 114227916703045

local DEFAULTS = {
	SmartBarOpen  = UDim2.new(0.5, 0, 1, -12),
	SmartBarClosed= UDim2.new(0.5, 0, 1, 70),
	TweenInfo     = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local state = {
	GUI = nil,
	SmartBar = nil,
	Toggle = nil,
	toggled = false,
	connections = {},
}

local function disconnect(conn)
	if typeof(conn) == "RBXScriptConnection" then
		conn:Disconnect()
	elseif conn and conn.Disconnect then
		conn:Disconnect()
	end
end

local function insertIonix(playerGui)
	local existing =
		(gethui and gethui():FindFirstChild("Ionix"))
		or (game:GetService("CoreGui"):FindFirstChild("Ionix"))
		or (playerGui and playerGui:FindFirstChild("Ionix"))
	if existing then
		pcall(function() existing:Destroy() end)
	end

	local ok, assets = pcall(function()
		return game:GetObjects("rbxassetid://" .. IONIX_ASSET_ID)
	end)
	if not ok or not assets or #assets == 0 then
		warn("[Ionix] game:GetObjects failed for asset:", IONIX_ASSET_ID)
		return nil
	end

	local root = Instance.new("ScreenGui")
	root.Name = "Ionix"
	root.ResetOnSpawn = false
	root.IgnoreGuiInset = true

	local CoreGui = game:GetService("CoreGui")
	if gethui then
		root.Parent = gethui()
	elseif CoreGui:FindFirstChild("RobloxGui") then
		root.Parent = CoreGui.RobloxGui
	else
		root.Parent = CoreGui
	end

	local model = assets[1]
	for _, inst in ipairs(model:GetChildren()) do
		inst.Parent = root
	end

	return root
end

local function getFormattedTime()
	local currentTime = os.date("*t")
	local hour = currentTime.hour
	local minute = currentTime.min
	local period = "AM"

	if hour >= 12 then
		period = "PM"
	end

	hour = hour % 12
	if hour == 0 then
		hour = 12
	end

	local formattedTime = string.format("%02d:%02d %s", hour, minute, period)
	return formattedTime
end


function module:Init()
	local player = Players.LocalPlayer
	if not player then
		warn("[Ionix] LocalPlayer not available.")
		return nil
	end

	local playerGui = player:WaitForChild("PlayerGui", 5)
	if not playerGui then
		warn("[Ionix] PlayerGui not found.")
		return nil
	end

	local gui = insertIonix(playerGui)
	if not gui then
		warn("[Ionix] Failed to locate or insert Ionix GUI.")
		return nil
	end

	local smartBar = gui:FindFirstChild("SmartBar", true)
	local toggle = gui:FindFirstChild("Toggle", true)

	if not (smartBar and toggle) then
		warn("[Ionix] GUI missing SmartBar/Toggle.")
		return nil
	end

	state.GUI = gui
	state.SmartBar = smartBar
	state.Toggle = toggle

	for _, c in pairs(state.connections) do
		disconnect(c)
	end
	state.connections = {}

	local function anySectionVisible()
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "SmartBar" and child.Name ~= "Toggle" then
				if child.Visible then
					return true
				end
			end
		end
		return false
	end

	local function fadeOutVisibleSections()
		local gui = state.GUI
		if not gui then return end

		local fadeTime = 0.25
		local moveOffset = 20
		local BASE_POSITION = UDim2.new(0.5, 0, 1, -90)

		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "SmartBar" and child.Name ~= "Toggle" then
				if child.Visible then
					local tweenOut = TweenService:Create(
						child,
						TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{
							BackgroundTransparency = 1,
							Position = BASE_POSITION + UDim2.new(0, 0, 0, moveOffset)
						}
					)
					tweenOut:Play()
					task.delay(fadeTime, function()
						child.Visible = false
					end)
				end
			end
		end
	end

	local toggleButton = toggle:FindFirstChildWhichIsA("ImageButton", true)
		or toggle:FindFirstChildWhichIsA("TextButton", true)
		or toggle

	if not toggleButton then
		warn("[Ionix] Toggle has no clickable child (no ImageButton/TextButton)")
		return gui
	end

	local enterConn = toggleButton.MouseEnter:Connect(function()
		if not state.toggled and not anySectionVisible() then
			TweenService:Create(smartBar, DEFAULTS.TweenInfo, { Position = DEFAULTS.SmartBarOpen }):Play()
		end
	end)

	local leaveConn = toggleButton.MouseLeave:Connect(function()
		if not state.toggled and not anySectionVisible() then
			TweenService:Create(smartBar, DEFAULTS.TweenInfo, { Position = DEFAULTS.SmartBarClosed }):Play()
		end
	end)

	table.insert(state.connections, enterConn)
	table.insert(state.connections, leaveConn)

	task.spawn(function()
		local idleTime = 0
		while task.wait(1) do
			if not state.toggled then
				if anySectionVisible() then
					idleTime = 0
				else
					idleTime += 1
					if idleTime >= 5 then
						TweenService:Create(smartBar, DEFAULTS.TweenInfo, { Position = DEFAULTS.SmartBarClosed }):Play()
						idleTime = 0
					end
				end
			else
				idleTime = 0
			end
		end
	end)

    local keyConn = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.Delete then
			fadeOutVisibleSections()
			local open = smartBar.Position ~= DEFAULTS.SmartBarOpen
			local target = open and DEFAULTS.SmartBarOpen or DEFAULTS.SmartBarClosed
			TweenService:Create(smartBar, DEFAULTS.TweenInfo, { Position = target }):Play()
		end
	end)
	table.insert(state.connections, keyConn)

	local keyConn2 = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.Insert then
			if state.GUI.Enabled then
				state.GUI.Enabled = false
			else
				state.GUI.Enabled = true
			end

			local open = smartBar.Position ~= DEFAULTS.SmartBarOpen
			local target = open and DEFAULTS.SmartBarOpen or DEFAULTS.SmartBarClosed
			TweenService:Create(smartBar, DEFAULTS.TweenInfo, { Position = target }):Play()
		end
	end)
	table.insert(state.connections, keyConn2)

	task.spawn(function()
		while true do
			state.SmartBar.Time.Text = getFormattedTime()
			task.wait(1)
		end
	end)
	return gui
end

function module.SetupButtons(buttonConfig)
	local gui = state.GUI
	if not gui then
		warn("[Ionix] GUI not initialized. Run :Init() first.")
		return
	end

	for name, info in pairs(buttonConfig) do
		local path = info.Path
		local callback = info.Callback
		local option = info.Option
		local toggleFrameName = info.ToggleFrameName or "Toggle"

		if not path or type(path) ~= "string" then
			warn("[Ionix] Invalid path for", name)
			continue
		end

		local parts = string.split(path, ".")
		local current = gui
		for _, part in ipairs(parts) do
			current = current:FindFirstChild(part)
			if not current then
				warn("[Ionix] Missing path:", path)
				break
			end
		end

		if not current or (not current:IsA("TextButton") and not current:IsA("ImageButton")) then
			warn("[Ionix] No valid button found for:", path)
			continue
		end

		if option == "Button" then
			current.MouseButton1Click:Connect(function()
				if callback then
					task.spawn(callback)
				end
			end)
		elseif option == "Toggle" then
			local toggleFrame = current:FindFirstAncestor(toggleFrameName)
				or current.Parent:FindFirstChild(toggleFrameName)
				or current.Parent
			if not toggleFrame then
				warn("[Ionix] Could not find ToggleFrame:", toggleFrameName)
				continue
			end

			local enabledValue = toggleFrame:FindFirstChild("Enabled")
			local disabledValue = toggleFrame:FindFirstChild("Disabled")
			if not (enabledValue and disabledValue and enabledValue:IsA("Color3Value") and disabledValue:IsA("Color3Value")) then
				warn("[Ionix] Missing Enabled/Disabled Color3Values in:", toggleFrame.Name)
				continue
			end

			local isEnabled = info.DefualtValue or false

			local parent = toggleFrame.Parent.Parent
			local stateLabel = parent:FindFirstChild("State")

			if stateLabel then
				stateLabel.Text = "Current State: " .. (isEnabled and "Enabled" or "Disabled")
			end

			local function updateState()
				local goalColor = isEnabled and enabledValue.Value or disabledValue.Value
				TweenService:Create(toggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundColor3 = goalColor,
				}):Play()

				if toggleFrame.Parent.Parent.Name == "EggSwap" and not isEnabled and _G.Ionix_.Config_ then
					if _G.Ionix_.Config_.EggList and #_G.Ionix_.Config_.EggList > 1 then
						local keep = _G.Ionix_.Config_.EggList[1]
						_G.Ionix_.Config_.EggList = { keep }
						_G.Ionix_.Config_.SelectedEgg = keep

						local gui = state.GUI or game.Players.LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Ionix")
						if gui then
							local eggDropdown = gui:FindFirstChild("EggDropdown", true)
							if eggDropdown then
								local label = eggDropdown:FindFirstChild("CurrentEgg", true)
									or eggDropdown:FindFirstChild("CurrentItem", true)
								if label and label:IsA("TextLabel") then
									label.Text = "Current: " .. keep
								end

								local eggListFrame = gui:FindFirstChild("EggList", true)
								if eggListFrame then
									for _, child in ipairs(eggListFrame:GetDescendants()) do
										if child.Name == "Toggle" and (child:IsA("TextButton") or child:IsA("ImageButton")) then
											local frame = child.Parent
											local enVal = frame:FindFirstChild("Enabled")
											local disVal = frame:FindFirstChild("Disabled")
											if enVal and disVal then
												local goal = (frame.Parent.Name == keep) and enVal.Value or disVal.Value
												TweenService:Create(frame, TweenInfo.new(0.25), { BackgroundColor3 = goal }):Play()
											end
										end
									end
								end
							end
						end
					end
				end

				if toggleFrame.Parent.Parent.Name == "EggHatch" then
					toggleFrame.Parent.Parent.Icon.Image = isEnabled and "rbxassetid://129913260974533" or "rbxassetid://101221898814339"
				end

				if stateLabel then
					stateLabel.Text = "Current State: " .. (isEnabled and "Enabled" or "Disabled")
				end
			end

			updateState()

			current.MouseButton1Click:Connect(function()
				isEnabled = not isEnabled
				updateState()

				if callback then
					task.spawn(callback, isEnabled)
				end
			end)

		elseif option == "Dropdown" then
			local isDropDown = false
			local dropdownData = info.Data
			local listName = info.List or "List"
			local labelTarget = info.Label or "CurrentItem"

			local canMultiSelect = info.CanMultiSelect
			local multiSelectReason = info.MultiSelectReason

			local labelObj
			if multiSelectReason == "Eggs" then
				local eggHatchFrame = gui:FindFirstChild("EggDropdown", true)
				if eggHatchFrame then
					labelObj = eggHatchFrame:FindFirstChild("CurrentEgg", true)
				end
			else
				labelObj = gui:FindFirstChild(labelTarget, true)
			end

			if not labelObj or not labelObj:IsA("TextLabel") then
				warn("[Ionix] Could not find label for dropdown:", labelTarget)
				return
			end

			if canMultiSelect and multiSelectReason == "Eggs" and _G.Ionix_.Config_ and _G.Ionix_.Config_.EggSwapEnabled then
				if #_G.Ionix_.Config_.EggList > 0 then
					labelObj.Text = "Current: " .. table.concat(_G.Ionix_.Config_.EggList, ", ")
				else
					labelObj.Text = "Current: None"
				end
			else
				labelObj.Text = "Current: " .. _G.Ionix_.Config_.SelectedEgg
			end

			current.MouseButton1Click:Connect(function()
				isDropDown = not isDropDown

				local iconArrow = current.Parent:FindFirstChild("Icon") or current.Parent:FindFirstChild("Arrow")
				if iconArrow and iconArrow:IsA("ImageLabel") then
					local goalRotation = isDropDown and 180 or 0
					TweenService:Create(iconArrow, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Rotation = goalRotation
					}):Play()
				end

				local container = current:FindFirstAncestorWhichIsA("Frame")
				local foundList, foundInteractions = nil, nil
				while container do
					local interactions = container:FindFirstChild("Interactions")
					if interactions then
						local listCandidate = interactions:FindFirstChild(listName)
						if listCandidate then
							foundList = listCandidate
							foundInteractions = interactions
							break
						end
					end
					container = container.Parent
				end

				if not foundList then
					warn("[Ionix] Missing dropdown list:", listName)
					return
				end

				local listFrame = foundList
				local interactions = foundInteractions
				local ignoreList = info.Ignore or {}
				local ignoreLookup = {}
				for _, v in ipairs(ignoreList) do
					ignoreLookup[v] = true
				end

				listFrame.Visible = isDropDown
				for _, obj in ipairs(interactions:GetChildren()) do
					if obj:IsA("Frame")
						and obj ~= listFrame
						and obj ~= current.Parent
						and not ignoreLookup[obj.Name] then
						obj.Visible = not isDropDown
					end
				end

				if isDropDown and dropdownData and typeof(dropdownData) == "table" then
					for _, child in ipairs(listFrame:GetChildren()) do
						if child:IsA("Frame") and child.Name ~= "Template" then
							child:Destroy()
						end
					end

					local template = listFrame:FindFirstChild("Template")
					if not template then
						warn("[Ionix] No Template found inside:", listName)
						return
					end

					for i, itemName in ipairs(dropdownData) do
						local clone = template:Clone()
						clone.Name = itemName
						clone.Visible = true
						clone.LayoutOrder = i
						clone.Parent = listFrame

						local label = clone:FindFirstChild("ItemName", true)
						if label then label.Text = itemName end

						task.defer(function()
							local icon = clone:FindFirstChild("Avatar") or clone:FindFirstChild("Icon")
							if not icon then
								return
							end

							local ImageUrl = ""
							if string.find(string.lower(itemName), "egg") then
								local success, result = pcall(function()
									return require(game.ReplicatedStorage.Shared.Data.Eggs)
								end)
								if success and result then
									local EggsModule = result
									local eggData = EggsModule[itemName] or EggsModule[itemName:gsub(" ", "")]
									if eggData and eggData.Image then
										ImageUrl = eggData.Image
									end
								end
							end

							if itemName == "Infinity Egg" then
								ImageUrl = "rbxassetid://125556495712431"
							end

							if ImageUrl ~= "" then
								icon.Image = ImageUrl
								icon.Visible = true
								icon.ImageTransparency = 0
								icon.ImageColor3 = Color3.new(1, 1, 1)
								game:GetService("ContentProvider"):PreloadAsync({icon})
							end
						end)

						local interactionsContainer = clone:FindFirstChild("Interactions", true)
						if interactionsContainer then
							for _, sub in pairs(interactionsContainer:GetDescendants()) do
								if sub.Name == "Toggle" then
									local toggleFrame = sub.Parent
									local enabledValue = toggleFrame:FindFirstChild("Enabled")
									local disabledValue = toggleFrame:FindFirstChild("Disabled")
									if not (enabledValue and disabledValue and enabledValue:IsA("Color3Value") and disabledValue:IsA("Color3Value")) then
										warn("[Ionix] Missing Enabled/Disabled Color3Values in:", toggleFrame.Name)
										continue
									end

									local isEnabled = false
									if _G.Ionix_.Config_ then
										if _G.Ionix_.Config_.EggSwapEnabled and _G.Ionix_.Config_.EggList then
											isEnabled = table.find(_G.Ionix_.Config_.EggList, itemName) and true or false
										elseif _G.Ionix_.Config_.SelectedEgg == itemName then
											isEnabled = true
										end
									end

									local function updateState()
										local goalColor = isEnabled and enabledValue.Value or disabledValue.Value
										TweenService:Create(toggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
											BackgroundColor3 = goalColor,
										}):Play()
									end

									updateState()

									sub.MouseButton1Click:Connect(function()
										local labelObj
										if multiSelectReason == "Eggs" then
											local eggHatchFrame = gui:FindFirstChild("EggDropdown", true)
											if eggHatchFrame then
												labelObj = eggHatchFrame:FindFirstChild("CurrentEgg", true)
											end
										else
											labelObj = gui:FindFirstChild(labelTarget, true)
										end

										if not labelObj or not labelObj:IsA("TextLabel") then
											warn("[Ionix] Could not find label for dropdown:", labelTarget)
											return
										end

										isEnabled = not isEnabled
										updateState()

										if canMultiSelect and multiSelectReason == "Eggs" and _G.Ionix_.Config_ and _G.Ionix_.Config_.EggSwapEnabled then
											_G.Ionix_.Config_.EggList = _G.Ionix_.Config_.EggList or {}
											local foundIndex = table.find(_G.Ionix_.Config_.EggList, itemName)
											if foundIndex then
												table.remove(_G.Ionix_.Config_.EggList, foundIndex)
											else
												table.insert(_G.Ionix_.Config_.EggList, itemName)
											end

											if #_G.Ionix_.Config_.EggList > 0 then
												labelObj.Text = "Current: " .. table.concat(_G.Ionix_.Config_.EggList, ", ")
											else
												labelObj.Text = "Current: None"
											end

											if callback then
												task.spawn(callback, _G.Ionix_.Config_.EggList)
											end
										elseif multiSelectReason == "Eggs" then
											_G.Ionix_.Config_.EggList = { itemName }

											for _, other in ipairs(listFrame:GetDescendants()) do
												if other:IsA("TextButton") or other:IsA("ImageButton") then
													if other.Name == "Toggle" and other ~= sub then
														local frame = other.Parent
														local disVal = frame and frame:FindFirstChild("Disabled")
														if disVal then
															TweenService:Create(frame, TweenInfo.new(0.25), {
																BackgroundColor3 = disVal.Value
															}):Play()
														end
													end
												end
											end

											if enabledValue then
												TweenService:Create(toggleFrame, TweenInfo.new(0.25), {
													BackgroundColor3 = enabledValue.Value
												}):Play()
											end

											labelObj.Text = "Current: " .. itemName
											if callback then
												task.spawn(callback, itemName)
											end
										else
											labelObj.Text = "Current: " .. itemName
											if callback then
												task.spawn(callback, itemName)
											end
										end
									end)
								end
							end
						end
					end
				end
			end)

		elseif option == "Time" then
			local Time = info.Time
			local frame = current:FindFirstAncestor(toggleFrameName)
				or current.Parent:FindFirstChild(toggleFrameName)
				or current.Parent
			if not frame then
				warn("[Ionix] Could not find ToggleFrame:", toggleFrameName)
				continue
			end

			task.spawn(function()
				while true do
					frame.Parent.Parent.State.Text = info.Text
					task.spawn(callback, frame.Parent.Parent.State)
					task.wait(Time)
				end
			end)
		elseif option == "Input" then
			local frame = current:FindFirstAncestor(toggleFrameName)
				or current.Parent:FindFirstChild(toggleFrameName)
				or current.Parent
			if not frame then
				warn("[Ionix] Could not find ToggleFrame:", toggleFrameName)
				continue
			end

			local requiredType = info.RequiredInput or "Time"
			local lastValid = nil

			local function parseTime(str)
				str = string.lower(str)
				local num, unit = string.match(str, "^(%d+)([smh]?)$")
				num = tonumber(num)
				if not num then return nil end

				if unit == "s" or unit == "" then
					if (unit == "" and num > 0) or (num >= 1 and num <= 60) then
						return num
					end
				elseif unit == "m" and num >= 1 and num <= 60 then
					return num * 60
				elseif unit == "h" and num >= 1 and num <= 24 then
					return num * 3600
				end
				return nil
			end

			local function validateWebhook(url)
				if type(url) ~= "string" then return false end
				return string.match(url, "^https://discord%.com/api/webhooks/%d+/%S+$")
					or string.match(url, "^https://canary%.discord%.com/api/webhooks/%d+/%S+$")
					or string.match(url, "^https://ptb%.discord%.com/api/webhooks/%d+/%S+$")
			end

			local function trim(s: string): string
				return (s:match("^%s*(.-)%s*$"))
			end


			local InputBox = frame:FindFirstChild("InteractBox")
			if InputBox then

				local DefualtValue = info.DefualtValue

				if requiredType == "Time" then
					local seconds = parseTime(DefualtValue)
					frame.Parent.Parent.State.Text = tostring("Current State: ".. string.format("%ds", seconds))
					InputBox.PlaceholderText = string.format("%ds", seconds)
				elseif requiredType == "Discord" then
					if validateWebhook(DefualtValue) then
						InputBox.TextColor3 = Color3.fromRGB(120, 255, 120)
						InputBox.PlaceholderText = "✅ Valid Discord Webhook"
						if DefualtValue ~= lastValid then
							lastValid = DefualtValue
							task.spawn(callback, DefualtValue)
						end
					else
						InputBox.TextColor3 = Color3.fromRGB(255, 120, 120)
						InputBox.PlaceholderText = "❌ Invalid Webhook URL"
						lastValid = nil
					end
				end

				InputBox:GetPropertyChangedSignal("Text"):Connect(function()
					local text = trim(InputBox.Text)

					if requiredType == "Time" then
						local seconds = parseTime(text)
						if seconds then
							InputBox.TextColor3 = Color3.fromRGB(120, 255, 120)
							InputBox.PlaceholderText = string.format("%ds", seconds)
							if seconds ~= lastValid then
								lastValid = seconds
								task.spawn(callback, seconds)
							end
						else
							InputBox.TextColor3 = Color3.fromRGB(255, 120, 120)
							InputBox.PlaceholderText = "Invalid time"
							lastValid = nil
						end
						frame.Parent.Parent.State.Text = tostring("Current State: ".. InputBox.PlaceholderText)
					elseif requiredType == "Discord" then
						if validateWebhook(text) then
							InputBox.TextColor3 = Color3.fromRGB(120, 255, 120)
							InputBox.PlaceholderText = "✅ Valid Discord Webhook"
							if text ~= lastValid then
								lastValid = text
								task.spawn(callback, text)
							end
						else
							InputBox.TextColor3 = Color3.fromRGB(255, 120, 120)
							InputBox.PlaceholderText = "❌ Invalid Webhook URL"
							lastValid = nil
						end
					end
				end)
			end
		end
	end
end

function module.MonitorStatus()
	local gui = state.GUI
	if not gui then
		warn("[Ionix] GUI not initialized. Run :Init() first.")
		return
	end

	local Settings = gui:WaitForChild("Settings")
	local Interactions = Settings:WaitForChild("Interactions")
	local SystemVersion = Interactions:WaitForChild("SystemVersion")
	local ActiveUsers = Interactions:WaitForChild("ActiveUsers")

	local IonixSystemData = loadstring(game:HttpGet("https://desyncwashere.net/scripts/SystemData"))()
	local VersionBefore = IonixSystemData.Version

	task.spawn(function()
		while true do
			local ok, NewData = pcall(function()
				return loadstring(game:HttpGet("https://desyncwashere.net/scripts/SystemData"))()
			end)

			if ok and NewData and NewData.Version then
				if NewData.Version ~= VersionBefore then
					SystemVersion.State.Text = VersionBefore .. " - Please rejoin and re-execute (version mismatch)"
					warn("[Ionix] ⚠️ Version mismatch detected! Current:", VersionBefore, "Latest:", NewData.Version)
				else
					SystemVersion.State.Text = VersionBefore
				end
			else
				warn("[Ionix] ⚠️ Failed to fetch version data, keeping current version display.")
				SystemVersion.State.Text = VersionBefore
			end

			ActiveUsers.State.Text = "Current: "..tostring(math.random(100, 1000))
			task.wait(60)
		end
	end)
end

function module.SmartButtons()
	local gui = state.GUI
	if not gui then
		warn("[Ionix] GUI not initialized. Run :Init() first.")
		return
	end

	local buttonsContainer = gui:WaitForChild("SmartBar"):WaitForChild("Buttons")
	local allSections = { "Auto", "Automation", "Chat", "Eggs", "Settings", "Webhooks", "Minigames" }

	local fadeTime = 0.25
	local moveOffset = 20
	local activeSection = nil

	local BASE_POSITION = UDim2.new(0.5, 0, 1, -90)

	local function showSection(name)
		for _, sectionName in ipairs(allSections) do
			local section = gui:FindFirstChild(sectionName)
			if section and section:IsA("Frame") then
				local targetVisible = (sectionName == name)

				if targetVisible then
					if activeSection == name then
						local tweenOut = TweenService:Create(section, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
							BackgroundTransparency = 1,
							Position = BASE_POSITION + UDim2.new(0, 0, 0, moveOffset)
						})
						tweenOut:Play()
						task.delay(fadeTime, function()
							section.Visible = false
							activeSection = nil
						end)
						return
					end

					for _, other in ipairs(allSections) do
						if other ~= name then
							local otherFrame = gui:FindFirstChild(other)
							if otherFrame and otherFrame:IsA("Frame") then
								otherFrame.Visible = false
								otherFrame.BackgroundTransparency = 1
								otherFrame.Position = BASE_POSITION
							end
						end
					end

					activeSection = name
					section.Visible = true
					section.Position = BASE_POSITION + UDim2.new(0, 0, 0, moveOffset)
					section.BackgroundTransparency = 1

					local tweenIn = TweenService:Create(section, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = 0,
						Position = BASE_POSITION
					})
					tweenIn:Play()
				else
					section.Visible = false
					section.Position = BASE_POSITION
				end
			end
		end
	end

	for _, btnFrame in ipairs(buttonsContainer:GetChildren()) do
		if btnFrame:IsA("Frame") then
			local interact = btnFrame:FindFirstChild("Interact")
			if interact and (interact:IsA("ImageButton") or interact:IsA("TextButton")) then
				interact.MouseButton1Click:Connect(function()
					local targetName = btnFrame.Name
					showSection(targetName)
				end)
			end
		end
	end
end

function module.ChatInit(callback)
	local gui = state.GUI
	if not gui then
		warn("[Ionix] GUI not initialized. Run :Init() first.")
		return
	end

	local ChatSystem = {
		ActiveMessages = 0,
		MaxMessages = 35
	}

	--// References
	local ChatFrame = gui:WaitForChild("Chat")
	local ChatBG = ChatFrame:WaitForChild("BG")
	local ChatHolder = ChatBG:WaitForChild("Chat")
	local ChatBox = ChatBG:WaitForChild("SendMessage")
	local Interactions = ChatHolder:WaitForChild("Interactions") -- ScrollingFrame
	local InputContainer = ChatBox:WaitForChild("Input")

	local ChatTemplate = Interactions:WaitForChild("ChatTemplate")
	local ChatInput = InputContainer:WaitForChild("InteractBox")
	local SendMessage = ChatBox:WaitForChild("Send")

	--// Sending messages
	SendMessage.Interact.MouseButton1Click:Connect(function()
		local rawText = ChatInput.Text or ""
		local text = string.gsub(rawText, "^%s*(.-)%s*$", "%1")

		if text == "" then
			ChatInput.PlaceholderText = "Cannot send empty message."
			ChatInput.TextColor3 = Color3.fromRGB(255, 120, 120)
			task.delay(1.5, function()
				ChatInput.PlaceholderText = "Type a message..."
				ChatInput.TextColor3 = Color3.fromRGB(255, 255, 255)
			end)
			return
		end

		local data = {
			User = game.Players.LocalPlayer.Name,
			Chat = rawText,
		}

		task.spawn(callback, data)
		ChatInput.Text = ""
	end)

	--// Displaying messages
	function ChatSystem.NewChat(data)
		local newMessage = ChatTemplate:Clone()
		newMessage.Name = string.format("%05d-%05d", math.random(0, 99999), math.random(0, 99999))

		ChatSystem.ActiveMessages += 1
		newMessage.LayoutOrder = ChatSystem.ActiveMessages
		newMessage.Visible = true

		-- hidden/anon handling
		if data.User == "Hidden" then
			local prefixes = {"User", "Anon", "Entity"}
			local prefix = prefixes[math.random(1, #prefixes)]
			data.User = prefix .. "-" .. math.random(1000, 99999)
			data.Avatar = "rbxassetid://76138324468798"
		end

		newMessage.Info.Text = data.User or "Unknown"
		newMessage.Chat.Text = data.Chat or ""

		if newMessage:FindFirstChild("Icon") then
			newMessage.Icon.Image = data.Avatar or "rbxassetid://76138324468798"
		end

		-- parent message
		newMessage.Parent = Interactions

		-- auto-scroll to bottom like Discord
		task.wait()
		local absSize = Interactions.AbsoluteCanvasSize.Y
		Interactions.CanvasPosition = Vector2.new(0, absSize)

		-- remove oldest messages beyond limit
		if #Interactions:GetChildren() > ChatSystem.MaxMessages then
			local oldest, lowest = nil, math.huge
			for _, v in ipairs(Interactions:GetChildren()) do
				if v:IsA("Frame") and v.LayoutOrder < lowest then
					oldest, lowest = v, v.LayoutOrder
				end
			end
			if oldest then oldest:Destroy() end
		end
	end

	return ChatSystem
end

return module
