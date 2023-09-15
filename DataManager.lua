--[[

	Author: @zblox164
	Purpose: Handle saving and loading plot data
	Last Updated: 2023-09-13

]]

--Services----------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

--Modules----------
local DataTemplate = require(script.DataTemplate)

--Variables----------
local DataVersion = tostring(script:GetAttribute("Version"))
local DataStore = DataStoreService:GetDataStore("ObjectSerializer" .. DataVersion)
local KeyPrefix = "PlayerData-"
local LoadedData = {}

local SerializePlot = ReplicatedStorage.Signals.Events.SerializePlot
local ItemHolder = workspace.Plot.ItemHolder
local Round = math.round
local Cframe = CFrame.new
local Angles = CFrame.fromEulerAnglesXYZ
local PreCalc = math.pi/180

--Functions----------

--Waits for enough request budget----------
local function WaitForRequestBudget(RequestType)
	local currentBudget = DataStoreService:GetRequestBudgetForRequestType(RequestType)
	
	while currentBudget < 1 do
		currentBudget = DataStoreService:GetRequestBudgetForRequestType(RequestType)
		task.wait(5)
	end
end

--Returns player data----------
local function GetData(Player)
	local Data = LoadedData[Player]
	if not Data then return end

	return Data
end

--Load plot data onto plot----------
local function RestorePlot(Player)
	local PlayerData = GetData(Player)
	if not PlayerData then return end
	
	local Data = PlayerData.PlotData
	if not Data or #Data == 0 then return end
	
	local Model
	for i = 1, #Data, 17 do
		--Check if model needs to be created----------
		if Data[i + 14] then
			Model = Instance.new("Model")
			Model.Name = tostring(Data[i + 16])
			Model.Parent = ItemHolder
		end
		
		local Part = Instance.new("Part")
		Part.Anchored = true
		Part.TopSurface = Enum.SurfaceType.SmoothNoOutlines
		Part.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
		Part.LeftSurface = Enum.SurfaceType.SmoothNoOutlines
		Part.RightSurface = Enum.SurfaceType.SmoothNoOutlines
		
		Part.CFrame = Cframe(Data[i]*0.001, Data[i + 1]*0.001, Data[i + 2]*0.001)
		Part.CFrame *= Angles((Data[i + 6]*0.001)*PreCalc, (Data[i + 7]*0.001)*PreCalc, (Data[i + 8]*0.001)*PreCalc)
		Part.Size = Vector3.new(Data[i + 3]*0.001, Data[i + 4]*0.001, Data[i + 5]*0.001)
		Part.Color = Color3.new(Data[i + 9], Data[i + 10], Data[i + 11])
		Part.Transparency = Data[i + 12]
		Part.Material = Enum.Material[Data[i + 13]]
		Part.Name = tostring(Data[i + 16])
		Part.Parent = Model
		
		--Return primary part----------
		if Data[1 + 15] then Model.PrimaryPart = Part; Part.CanCollide = false end
		
		task.wait(0.1)
	end
end

--Converts placed items into a serialized format and updates the players data----------
local function UpdatePlotData(Player)
	local Data = {}
	
	--Saves properties from all objects----------
	for model, Models in ipairs(ItemHolder:GetChildren()) do
		if not Models:IsA("Model") then continue end
		
		local Descendants = Models:GetDescendants()

		for instance, Object in ipairs(Descendants) do
			if not Object:IsA("BasePart") then continue end
			
			--CFrame----------
			table.insert(Data, Round(Object.CFrame.X*1000))  -- 0 --
			table.insert(Data, Round(Object.CFrame.Y*1000))
			table.insert(Data, Round(Object.CFrame.Z*1000))
			table.insert(Data, Round(Object.Size.X*1000))
			table.insert(Data, Round(Object.Size.Y*1000))
			table.insert(Data, Round(Object.Size.Z*1000))
			table.insert(Data, Round(Object.Orientation.X*1000))
			table.insert(Data, Round(Object.Orientation.Y*1000))
			table.insert(Data, Round(Object.Orientation.Z*1000))
			
			--Appearance----------
			table.insert(Data, Object.Color.R)
			table.insert(Data, Object.Color.G)
			table.insert(Data, Object.Color.B)
			table.insert(Data, Object.Transparency)
			table.insert(Data, Object.Material.Name)
			
			--Data----------
			table.insert(Data, Descendants[1] == Object)
			table.insert(Data, (Models.PrimaryPart == Object) or false) 
			table.insert(Data, Models.Name) -- 16 --
		end
	end
	
	LoadedData[Player].PlotData = Data
end

--Saves player data for a given player----------
local function Save(Player, OnShutdown)
	local Key = KeyPrefix .. tostring(Player.UserId)
	local Success, Error
	local Data = GetData(Player)

	--Check if data is not valid----------
	if not Data then return end

	--Updates player data----------
	repeat
		if not OnShutdown then WaitForRequestBudget(Enum.DataStoreRequestType.UpdateAsync) end

		Success, Error = pcall(function()
			DataStore:UpdateAsync(Key, function(PreviousData)
				return Data
			end)
		end)
	until Success

	--Error handling----------
	if not Success then
		warn("Failed to save data: " .. tostring(Error))
		return false
	end

	return true
end

--Loads player data for a given player----------
local function Load(Player)
	local Key = KeyPrefix .. tostring(Player.UserId)
	local Data
	local Success, Error

	--Loads player data----------
	repeat
		WaitForRequestBudget(Enum.DataStoreRequestType.GetAsync)

		Success, Error = pcall(function()
			Data = DataStore:GetAsync(Key)
		end)
	until Success or not Players:FindFirstChild(tostring(Player))

	--Error handling----------
	if not Success then
		warn("Failed to load data: " .. tostring(Error))
		Player:Kick("Failed to load data. Please rejoin.")

		return false
	end

	if not Data then Data = DataTemplate end

	LoadedData[Player] = Data
	RestorePlot(Player)
	
	return true
end

--Handles players leaving----------
local function OnLeave(Player)
	UpdatePlotData(Player)
	Save(Player)
	LoadedData[Player] = nil
	return true
end

--Save all player data when the game closes----------
local function OnGameClose()
	if RunService:IsStudio() then task.wait(2); return end

	local AllPlayersSaved = Instance.new("BindableEvent")
	local AllPlayers = Players:GetPlayers()
	local RemainingPlayers = #AllPlayers

	--Save all player data and fire event when all players have been saved----------
	for index, Player in ipairs(AllPlayers) do
		task.spawn(function()
			UpdatePlotData(Player)
			Save(Player, true)
			RemainingPlayers -= 1

			if RemainingPlayers < 1 then AllPlayersSaved:Fire() end
		end)
	end

	--Wait for all players to be saved----------
	AllPlayersSaved.Event:Wait()
end

--Signals----------
Players.PlayerAdded:Connect(Load)
Players.PlayerRemoving:Connect(OnLeave)
SerializePlot.OnServerEvent:Connect(UpdatePlotData)

game:BindToClose(OnGameClose)
