-- Services
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local dataStoreService = game:GetService("DataStoreService")
local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")
local dataStore = dataStoreService:GetDataStore("Example_Serialize_System")

local serializeE = replicatedStorage.remotes.events.serialize

local location = workspace.Plot.plane.itemHolder

local dataLoaded = false
local tries = 5

local rad = math.rad
local cframe = CFrame.new
local angles = CFrame.fromEulerAnglesXYZ
local vector3 = Vector3.new
local color = Color3.new

local function waitForRequestBudget(requestType)
	local currentBudget = dataStoreService:GetRequestBudgetForRequestType(requestType)
	
	while currentBudget < 1 do
		currentBudget = dataStoreService:GetRequestBudgetForRequestType(requestType)
		
		wait(5)
	end
end

local function safeCall(plrName, func, requestType, ...)
	local success, ret
	
	repeat
		if requestType then
			waitForRequestBudget(requestType)
		end
		
		success, ret = pcall(func, dataStore, ...)
		
		if not success  then
			warn(ret)
		end
	until success or plrName and not players:FindFirstChild(plrName)
	
	return success, ret
end

-- Saves models currently placed on the plane/plot
local function serialize(plr, pause)
	if dataLoaded then
		local key = plr.UserId
		local data = {}
		
		-- Saves properties from all objects
		for _, objs in pairs(location:GetChildren()) do
			for i, obj in pairs(objs:GetDescendants()) do
				if obj:IsA("BasePart") then
					table.insert(data, {
						-- p = position
						["p"] = {obj.CFrame.X, obj.CFrame.Y, obj.CFrame.Z, obj.Orientation.X, obj.Orientation.Y, obj.Orientation.Z};
						["s"] = {obj.Size.X, obj.Size.Y, obj.Size.Z}; -- s = size
						["c"] = {obj.Color.R, obj.Color.G, obj.Color.B}; -- c = color
						["n"] = obj.Name; -- n = name
						["t"] = obj.Transparency;
						["mdlN"] = objs.Name; -- t = transparency
						["m"] = string.sub(tostring(obj.Material), 15, string.len(tostring(obj.Material))); -- m = material
						["isPri"] = objs.PrimaryPart == obj; -- isPri = isPrimaryPart
						["f"] = objs:GetDescendants()[1] == obj -- f = firstObject
					})
				end
			end
		end
		
		-- To prevent errors and data loss
		safeCall()
	end
end

-- Loads the data back into the game
local function deserialize(plr)
	local key = plr.UserId
	local serializedData
	
	local success, err
	
	repeat
		waitForRequestBudget(Enum.DataStoreRequestType.GetAsync)
		
		success, err = pcall(function()
			serializedData = dataStore:GetAsync(key)
		end)
	until success or not players:FindFirstChild(plr)
	
	if not success then
		warn("Failed to read data: Error code " .. tostring(err))
		
		return
	end
	
	if serializedData then
		local model
		
		-- Loads data
		for i, data in ipairs(serializedData) do
			-- Makes sure a model is created only per model
			if data.f then
				model = Instance.new("Model")
				model.Name = data.mdlN
				
				model.Parent = location
			end
			
			local part = Instance.new("Part")
			part.Anchored = true
			part.CFrame = cframe(data.p[1], data.p[2], data.p[3])*angles(rad(data.p[4]), rad(data.p[5]), rad(data.p[6]))
			part.Size = vector3(data.s[1], data.s[2], data.s[3])
			part.Color = color(data.c[1], data.c[2], data.c[3])
			part.TopSurface = Enum.SurfaceType.SmoothNoOutlines
			part.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
			part.LeftSurface = Enum.SurfaceType.SmoothNoOutlines
			part.RightSurface = Enum.SurfaceType.SmoothNoOutlines
			part.Name = data.n
			part.Material = Enum.Material[data.m]
			part.Transparency = data.t
			part.Parent = model
			
			-- Handles primary parts
			if data.isPri and model then
				model.PrimaryPart = part
				model.PrimaryPart.CanCollide = false
			end
			
			wait(0.1) -- this can be removed
		end
		
		dataLoaded = true
	else
		dataLoaded = true
		
		serialize(plr)
	end
end

-- calls
players.PlayerAdded:Connect(deserialize)
players.PlayerRemoving:Connect(serialize)
serializeE.OnServerEvent:Connect(serialize)

game:BindToClose(function()
	if runService:IsStudio() then
		wait(1)
	else
		for _, plr in ipairs(players:GetPlayers()) do
			coroutine.wrap(serialize)(plr, true)
		end
	end
end)