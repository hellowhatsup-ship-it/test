local game, workspace = game, workspace
local getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick = getrawmetatable, getmetatable, setmetatable, pcall, getgenv, next, tick
local Vector2new, Vector3zero, Vector3new, CFramenew, Color3fromRGB, Color3fromHSV, Drawingnew, TweenInfonew = Vector2.new, Vector3.zero, Vector3.new, CFrame.new, Color3.fromRGB, Color3.fromHSV, Drawing.new, TweenInfo.new
local getupvalue, mousemoverel, tablefind, tableremove, stringlower, stringsub, mathclamp, mathabs, mathsqrt, mathsin, mathcos, mathrad = debug.getupvalue, mousemoverel or (Input and Input.MouseMove), table.find, table.remove, string.lower, string.sub, math.clamp, math.abs, math.sqrt, math.sin, math.cos, math.rad

local GameMetatable = getrawmetatable and getrawmetatable(game) or {
	__index = function(self, Index)
		return self[Index]
	end,

	__newindex = function(self, Index, Value)
		self[Index] = Value
	end
}

local __index = GameMetatable.__index
local __newindex = GameMetatable.__newindex

local getrenderproperty, setrenderproperty = getrenderproperty or __index, setrenderproperty or __newindex

local GetService = __index(game, "GetService")

local RunService = GetService(game, "RunService")
local UserInputService = GetService(game, "UserInputService")
local TweenService = GetService(game, "TweenService")
local Players = GetService(game, "Players")

local LocalPlayer = __index(Players, "LocalPlayer")
local Camera = __index(workspace, "CurrentCamera")

local FindFirstChild, FindFirstChildOfClass = __index(game, "FindFirstChild"), __index(game, "FindFirstChildOfClass")
local GetDescendants = __index(game, "GetDescendants")
local WorldToViewportPoint = __index(Camera, "WorldToViewportPoint")
local GetPartsObscuringTarget = __index(Camera, "GetPartsObscuringTarget")
local GetMouseLocation = __index(UserInputService, "GetMouseLocation")
local GetPlayers = __index(Players, "GetPlayers")

local RequiredDistance, Typing, Running, ServiceConnections, Animation, OriginalSensitivity = 2000, false, false, {}, nil, nil
local Connect, Disconnect = __index(game, "DescendantAdded").Connect
local PredictionData = {LastPosition = nil, LastTick = 0, Velocity = Vector3zero, VerticalVelocity = 0}

if ExunysDeveloperAimbot and ExunysDeveloperAimbot.Exit then
	ExunysDeveloperAimbot:Exit()
end

getgenv().ExunysDeveloperAimbot = {
	DeveloperSettings = {
		UpdateMode = "RenderStepped",
		TeamCheckOption = "TeamColor",
		RainbowSpeed = 1
	},

	Settings = {
		Enabled = true,

		TeamCheck = false,
		AliveCheck = true,
		WallCheck = false,

		OffsetToMoveDirection = false,
		OffsetIncrement = 15,

		Sensitivity = 0,
		Sensitivity2 = 2.5,

		LockMode = 1,
		LockPart = "Head",

		TriggerKey = Enum.UserInputType.MouseButton2,
		Toggle = false,
		
		PredictionEnabled = true,
		PredictionMultiplier = 0.135,
		VerticalPredictionMultiplier = 1.8,
		ShakeReduction = true,
		ShakeReductionAmount = 0.92,
		AimSmoothing = false,
		SmoothingFactor = 0.45,
		InstantVerticalSnap = true,
		AdaptiveSpeed = true,
		MaxTrackingDistance = 500
	},

	FOVSettings = {
		Enabled = true,
		Visible = true,

		Radius = 90,
		NumSides = 60,

		Thickness = 1,
		Transparency = 1,
		Filled = false,

		RainbowColor = false,
		RainbowOutlineColor = false,
		Color = Color3fromRGB(255, 255, 255),
		OutlineColor = Color3fromRGB(0, 0, 0),
		LockedColor = Color3fromRGB(255, 150, 150)
	},

	Blacklisted = {},
	FOVCircleOutline = Drawingnew("Circle"),
	FOVCircle = Drawingnew("Circle")
}

local Environment = getgenv().ExunysDeveloperAimbot

setrenderproperty(Environment.FOVCircle, "Visible", false)
setrenderproperty(Environment.FOVCircleOutline, "Visible", false)

local FixUsername = function(String)
	local Result

	for _, Value in next, GetPlayers(Players) do
		local Name = __index(Value, "Name")

		if stringsub(stringlower(Name), 1, #String) == stringlower(String) then
			Result = Name
		end
	end

	return Result
end

local GetRainbowColor = function()
	local RainbowSpeed = Environment.DeveloperSettings.RainbowSpeed

	return Color3fromHSV(tick() % RainbowSpeed / RainbowSpeed, 1, 1)
end

local ConvertVector = function(Vector)
	return Vector2new(Vector.X, Vector.Y)
end

local CancelLock = function()
	Environment.Locked = nil
	PredictionData.LastPosition = nil
	PredictionData.LastTick = 0
	PredictionData.Velocity = Vector3zero
	PredictionData.VerticalVelocity = 0

	local FOVCircle = Environment.FOVCircle

	setrenderproperty(FOVCircle, "Color", Environment.FOVSettings.Color)
	__newindex(UserInputService, "MouseDeltaSensitivity", OriginalSensitivity)

	if Animation then
		Animation:Cancel()
	end
end

local GetPredictedPosition = function(TargetPart)
	local Settings = Environment.Settings
	
	if not Settings.PredictionEnabled then
		return __index(TargetPart, "Position")
	end
	
	local CurrentPosition = __index(TargetPart, "Position")
	local CurrentTick = tick()
	
	if PredictionData.LastPosition then
		local TimeDelta = CurrentTick - PredictionData.LastTick
		if TimeDelta > 0 and TimeDelta < 0.5 then
			local NewVelocity = (CurrentPosition - PredictionData.LastPosition) / TimeDelta
			PredictionData.Velocity = NewVelocity
			PredictionData.VerticalVelocity = NewVelocity.Y
		end
	end
	
	PredictionData.LastPosition = CurrentPosition
	PredictionData.LastTick = CurrentTick
	
	local HorizontalVelocity = Vector3new(PredictionData.Velocity.X, 0, PredictionData.Velocity.Z)
	local VerticalVelocity = Vector3new(0, PredictionData.VerticalVelocity, 0)
	
	local HorizontalPrediction = HorizontalVelocity * Settings.PredictionMultiplier
	local VerticalPrediction = VerticalVelocity * (Settings.PredictionMultiplier * Settings.VerticalPredictionMultiplier)
	
	local PredictedPosition = CurrentPosition + HorizontalPrediction + VerticalPrediction
	
	return PredictedPosition
end

local GetClosestPlayer = function()
	local Settings = Environment.Settings
	local LockPart = Settings.LockPart

	if not Environment.Locked then
		RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Radius or 2000

		for _, Value in next, GetPlayers(Players) do
			local Character = __index(Value, "Character")
			local Humanoid = Character and FindFirstChildOfClass(Character, "Humanoid")

			if Value ~= LocalPlayer and not tablefind(Environment.Blacklisted, __index(Value, "Name")) and Character and FindFirstChild(Character, LockPart) and Humanoid then
				local PartPosition, TeamCheckOption = __index(Character[LockPart], "Position"), Environment.DeveloperSettings.TeamCheckOption

				if Settings.TeamCheck and __index(Value, TeamCheckOption) == __index(LocalPlayer, TeamCheckOption) then
					continue
				end

				if Settings.AliveCheck and __index(Humanoid, "Health") <= 0 then
					continue
				end

				if Settings.WallCheck then
					local BlacklistTable = GetDescendants(__index(LocalPlayer, "Character"))

					for _, Value in next, GetDescendants(Character) do
						BlacklistTable[#BlacklistTable + 1] = Value
					end

					if #GetPartsObscuringTarget(Camera, {PartPosition}, BlacklistTable) > 0 then
						continue
					end
				end

				local Vector, OnScreen, Distance = WorldToViewportPoint(Camera, PartPosition)
				Vector = ConvertVector(Vector)
				Distance = (GetMouseLocation(UserInputService) - Vector).Magnitude

				if Distance < RequiredDistance and OnScreen then
					RequiredDistance, Environment.Locked = Distance, Value
					PredictionData.LastPosition = nil
					PredictionData.LastTick = 0
					PredictionData.Velocity = Vector3zero
					PredictionData.VerticalVelocity = 0
				end
			end
		end
	elseif (GetMouseLocation(UserInputService) - ConvertVector(WorldToViewportPoint(Camera, __index(__index(__index(Environment.Locked, "Character"), LockPart), "Position")))).Magnitude > RequiredDistance then
		CancelLock()
	end
end

local Load = function()
	OriginalSensitivity = __index(UserInputService, "MouseDeltaSensitivity")

	local Settings, FOVCircle, FOVCircleOutline, FOVSettings, Offset = Environment.Settings, Environment.FOVCircle, Environment.FOVCircleOutline, Environment.FOVSettings

	ServiceConnections.RenderSteppedConnection = Connect(__index(RunService, Environment.DeveloperSettings.UpdateMode), function()
		local OffsetToMoveDirection, LockPart = Settings.OffsetToMoveDirection, Settings.LockPart

		if FOVSettings.Enabled and Settings.Enabled then
			for Index, Value in next, FOVSettings do
				if Index == "Color" then
					continue
				end

				if pcall(getrenderproperty, FOVCircle, Index) then
					setrenderproperty(FOVCircle, Index, Value)
					setrenderproperty(FOVCircleOutline, Index, Value)
				end
			end

			setrenderproperty(FOVCircle, "Color", (Environment.Locked and FOVSettings.LockedColor) or FOVSettings.RainbowColor and GetRainbowColor() or FOVSettings.Color)
			setrenderproperty(FOVCircleOutline, "Color", FOVSettings.RainbowOutlineColor and GetRainbowColor() or FOVSettings.OutlineColor)

			setrenderproperty(FOVCircleOutline, "Thickness", FOVSettings.Thickness + 1)
			setrenderproperty(FOVCircle, "Position", GetMouseLocation(UserInputService))
			setrenderproperty(FOVCircleOutline, "Position", GetMouseLocation(UserInputService))
		else
			setrenderproperty(FOVCircle, "Visible", false)
			setrenderproperty(FOVCircleOutline, "Visible", false)
		end

		if Running and Settings.Enabled then
			GetClosestPlayer()

			Offset = OffsetToMoveDirection and __index(FindFirstChildOfClass(__index(Environment.Locked, "Character"), "Humanoid"), "MoveDirection") * (mathclamp(Settings.OffsetIncrement, 1, 30) / 10) or Vector3zero

			if Environment.Locked then
				local TargetCharacter = __index(Environment.Locked, "Character")
				local TargetPart = TargetCharacter and TargetCharacter[LockPart]
				
				if TargetPart then
					local PredictedPosition = GetPredictedPosition(TargetPart)
					local FinalPosition = PredictedPosition + Offset
					
					local DistanceToTarget = (Camera.CFrame.Position - FinalPosition).Magnitude
					local SpeedMultiplier = 1
					
					if Settings.AdaptiveSpeed and DistanceToTarget < Settings.MaxTrackingDistance then
						SpeedMultiplier = 1 + (DistanceToTarget / Settings.MaxTrackingDistance) * 0.8
					end
					
					if Settings.ShakeReduction then
						local CurrentCFrame = Camera.CFrame
						local TargetCFrame = CFramenew(CurrentCFrame.Position, FinalPosition)
						local LerpAmount = Settings.ShakeReductionAmount
						
						if mathabs(PredictionData.VerticalVelocity) > 5 and Settings.InstantVerticalSnap then
							LerpAmount = 0.98
						end
						
						local LerpedCFrame = CurrentCFrame:Lerp(TargetCFrame, LerpAmount)
						FinalPosition = LerpedCFrame.LookVector * (FinalPosition - CurrentCFrame.Position).Magnitude + CurrentCFrame.Position
					end
					
					local LockedPosition = WorldToViewportPoint(Camera, FinalPosition)

					if Environment.Settings.LockMode == 2 then
						local MousePos = GetMouseLocation(UserInputService)
						local DeltaX = (LockedPosition.X - MousePos.X) / (Settings.Sensitivity2 / SpeedMultiplier)
						local DeltaY = (LockedPosition.Y - MousePos.Y) / (Settings.Sensitivity2 / SpeedMultiplier)
						
						if Settings.AimSmoothing then
							DeltaX = DeltaX * Settings.SmoothingFactor
							DeltaY = DeltaY * Settings.SmoothingFactor
						end
						
						if mathabs(PredictionData.VerticalVelocity) > 5 and Settings.InstantVerticalSnap then
							DeltaY = DeltaY * 1.5
						end
						
						mousemoverel(DeltaX, DeltaY)
					else
						if Settings.Sensitivity > 0 then
							local TweenSpeed = Settings.Sensitivity
							
							if mathabs(PredictionData.VerticalVelocity) > 5 and Settings.InstantVerticalSnap then
								TweenSpeed = TweenSpeed * 0.4
							end
							
							Animation = TweenService:Create(Camera, TweenInfonew(TweenSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, FinalPosition)})
							Animation:Play()
						else
							if Settings.AimSmoothing then
								local CurrentCFrame = Camera.CFrame
								local TargetCFrame = CFramenew(CurrentCFrame.Position, FinalPosition)
								local LerpAmount = Settings.SmoothingFactor
								
								if mathabs(PredictionData.VerticalVelocity) > 5 and Settings.InstantVerticalSnap then
									LerpAmount = mathclamp(LerpAmount * 1.8, 0, 1)
								end
								
								__newindex(Camera, "CFrame", CurrentCFrame:Lerp(TargetCFrame, LerpAmount))
							else
								__newindex(Camera, "CFrame", CFramenew(Camera.CFrame.Position, FinalPosition))
							end
						end

						__newindex(UserInputService, "MouseDeltaSensitivity", 0)
					end

					setrenderproperty(FOVCircle, "Color", FOVSettings.LockedColor)
				end
			end
		end
	end)

	ServiceConnections.InputBeganConnection = Connect(__index(UserInputService, "InputBegan"), function(Input)
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle

		if Typing then
			return
		end

		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			if Toggle then
				Running = not Running

				if not Running then
					CancelLock()
				end
			else
				Running = true
			end
		end
	end)

	ServiceConnections.InputEndedConnection = Connect(__index(UserInputService, "InputEnded"), function(Input)
		local TriggerKey, Toggle = Settings.TriggerKey, Settings.Toggle

		if Toggle or Typing then
			return
		end

		if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == TriggerKey or Input.UserInputType == TriggerKey then
			Running = false
			CancelLock()
		end
	end)
end

ServiceConnections.TypingStartedConnection = Connect(__index(UserInputService, "TextBoxFocused"), function()
	Typing = true
end)

ServiceConnections.TypingEndedConnection = Connect(__index(UserInputService, "TextBoxFocusReleased"), function()
	Typing = false
end)

function Environment.Exit(self)
	assert(self, "EXUNYS_AIMBOT-V3.Exit: Missing parameter #1 \"self\" <table>.")

	for Index, _ in next, ServiceConnections do
		Disconnect(ServiceConnections[Index])
	end

	Load = nil; ConvertVector = nil; CancelLock = nil; GetClosestPlayer = nil; GetRainbowColor = nil; FixUsername = nil; GetPredictedPosition = nil

	self.FOVCircle:Remove()
	self.FOVCircleOutline:Remove()
	getgenv().ExunysDeveloperAimbot = nil
end

function Environment.Restart()
	for Index, _ in next, ServiceConnections do
		Disconnect(ServiceConnections[Index])
	end

	Load()
end

function Environment.Blacklist(self, Username)
	assert(self, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Blacklist: Missing parameter #2 \"Username\" <string>.")

	Username = FixUsername(Username)

	assert(self, "EXUNYS_AIMBOT-V3.Blacklist: User "..Username.." couldn't be found.")

	self.Blacklisted[#self.Blacklisted + 1] = Username
end

function Environment.Whitelist(self, Username)
	assert(self, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #1 \"self\" <table>.")
	assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: Missing parameter #2 \"Username\" <string>.")

	Username = FixUsername(Username)

	assert(Username, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." is not blacklisted.")

	local Index = tablefind(self.Blacklisted, Username)

	assert(Index, "EXUNYS_AIMBOT-V3.Whitelist: User "..Username.." is not blacklisted.")

	tableremove(self.Blacklisted, Index)
end

function Environment.GetClosestPlayer()
	GetClosestPlayer()
	local Value = Environment.Locked
	CancelLock()

	return Value
end

Environment.Load = Load

setmetatable(Environment, {__call = Load})

return Environment
