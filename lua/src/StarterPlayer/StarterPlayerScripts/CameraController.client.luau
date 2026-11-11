--!strict
-- CameraController.client.luau
-- Client-side camera management featuring dynamic 6DOF screen shake, trauma decay,
-- FOV kick impulses, and automated combat event listeners.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera or workspace:WaitForChild("Camera") :: Camera

-- Forward reference to ScreenShake module
local Modules = ReplicatedStorage:WaitForChild("Modules", 5) :: Folder?
local ScreenShake = if Modules and Modules:FindFirstChild("ScreenShake")
	then require(Modules:WaitForChild("ScreenShake"))
	else require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ScreenShake"))

-- Active Shake State
type ShakeInstance = {
	Intensity: number,
	Duration: number,
	Frequency: number,
	StartTime: number,
	RotationalRatio: number,
	TraumaExponent: number,
	NoiseSeed: number,
}

local activeShakes: { ShakeInstance } = {}
local trauma = 0.0
local defaultFOV = Camera.FieldOfView
local targetFOVOffset = 0.0
local currentFOVOffset = 0.0

-- Ensure camera reference is kept fresh
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCam = workspace.CurrentCamera
	if newCam then
		Camera = newCam
		defaultFOV = Camera.FieldOfView
	end
end)

-- Adds an active shake instance
local function addShake(intensity: number, duration: number, frequency: number, options: any?)
	local rotRatio = if options and options.RotationalRatio then options.RotationalRatio else 1.0
	local exponent = if options and options.TraumaExponent then options.TraumaExponent else 2.0

	table.insert(activeShakes, {
		Intensity = intensity,
		Duration = duration,
		Frequency = frequency,
		StartTime = os.clock(),
		RotationalRatio = rotRatio,
		TraumaExponent = exponent,
		NoiseSeed = math.random() * 1000,
	})

	-- Add to generalized trauma
	local addedTrauma = math.clamp(intensity * 0.4, 0, 1)
	trauma = math.clamp(trauma + addedTrauma, 0, 1)
end

-- Hook into ScreenShake module
ScreenShake.SetHandler(addShake)

-- Dynamic FOV punch
local function kickFOV(amount: number, returnDuration: number?)
	if not Camera then return end
	local duration = returnDuration or 0.25
	local punchTween = TweenService:Create(
		Camera,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = defaultFOV + amount }
	)
	local returnTween = TweenService:Create(
		Camera,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = defaultFOV }
	)

	punchTween:Play()
	punchTween.Completed:Connect(function()
		returnTween:Play()
	end)
end

-- 6DOF Camera Shake Calculation on RenderStepped
local function onCameraStep(dt: number)
	if not Camera then
		Camera = workspace.CurrentCamera
		if not Camera then return end
	end

	local now = os.clock()
	local totalPosOffset = Vector3.zero
	local totalRotPitch = 0.0
	local totalRotYaw = 0.0
	local totalRotRoll = 0.0

	-- Decay general trauma
	if trauma > 0 then
		trauma = math.max(0, trauma - (dt * 1.6))
	end

	local generalShake = trauma * trauma

	-- Process discrete shake instances
	local i = 1
	while i <= #activeShakes do
		local shake = activeShakes[i]
		local elapsed = now - shake.StartTime

		if elapsed >= shake.Duration then
			table.remove(activeShakes, i)
		else
			local progress = elapsed / shake.Duration
			-- Smooth decay envelope: (1 - progress)^exponent
			local decay = math.pow(1 - progress, shake.TraumaExponent)
			local currentAmp = shake.Intensity * decay

			local t = elapsed * shake.Frequency
			local seed = shake.NoiseSeed

			-- Translational offsets via smooth continuous Perlin noise
			local nx = math.noise(seed, t, 0)
			local ny = math.noise(seed + 10.5, t, 0)
			local nz = math.noise(seed + 20.5, t, 0)

			-- Rotational offsets (in radians)
			local rx = math.noise(seed + 30.5, t, 0) * 0.035 * shake.RotationalRatio
			local ry = math.noise(seed + 40.5, t, 0) * 0.035 * shake.RotationalRatio
			local rz = math.noise(seed + 50.5, t, 0) * 0.025 * shake.RotationalRatio

			totalPosOffset += Vector3.new(nx, ny, nz) * (currentAmp * 0.22)
			totalRotPitch += rx * currentAmp
			totalRotYaw += ry * currentAmp
			totalRotRoll += rz * currentAmp

			i += 1
		end
	end

	-- Add general trauma ambient noise if active
	if generalShake > 0.01 then
		local t = now * 25
		local gSeed = 99.1
		local gnx = math.noise(gSeed, t, 0) * 0.15 * generalShake
		local gny = math.noise(gSeed + 12.3, t, 0) * 0.15 * generalShake
		local gnz = math.noise(gSeed + 24.6, t, 0) * 0.15 * generalShake

		local grx = math.noise(gSeed + 36.9, t, 0) * 0.02 * generalShake
		local gry = math.noise(gSeed + 48.2, t, 0) * 0.02 * generalShake
		local grz = math.noise(gSeed + 60.5, t, 0) * 0.015 * generalShake

		totalPosOffset += Vector3.new(gnx, gny, gnz)
		totalRotPitch += grx
		totalRotYaw += gry
		totalRotRoll += grz
	end

	-- Apply CFrame offset to Camera
	if totalPosOffset.Magnitude > 0.0001 or math.abs(totalRotPitch) > 0.0001 or math.abs(totalRotYaw) > 0.0001 or math.abs(totalRotRoll) > 0.0001 then
		local offsetCFrame = CFrame.new(totalPosOffset) * CFrame.Angles(totalRotPitch, totalRotYaw, totalRotRoll)
		Camera.CFrame = Camera.CFrame * offsetCFrame
	end
end

-- Bind immediately after Roblox Camera update
RunService:BindToRenderStep("BattlegroundCameraShake", Enum.RenderPriority.Camera.Value + 1, onCameraStep)

-- Setup Remote Event Listeners for Automatic Camera Shake & Audio-visual Immersion
local function setupRemoteListeners()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes", 8) :: Folder?
	if not Remotes then
		return
	end

	-- 1. CombatEvent (M1 hits, Knockbacks, Wall Splats)
	local combatEvent = Remotes:WaitForChild("CombatEvent", 5) :: RemoteEvent?
	if combatEvent then
		combatEvent.OnClientEvent:Connect(function(action: string, data: any)
			if typeof(data) ~= "table" then return end

			local myChar = LocalPlayer.Character
			local isMeAttacker = (data.Attacker == myChar)
			local isMeTarget = (data.Target == myChar)

			if action == "HitConfirm" then
				if isMeTarget then
					-- Local player took a hit
					if data.Knockback then
						ScreenShake.Heavy()
						kickFOV(-4, 0.3)
					elseif data.Blocked then
						ScreenShake.Light()
					else
						ScreenShake.Medium()
						kickFOV(-2, 0.15)
					end
				elseif isMeAttacker then
					-- Local player struck an opponent
					if data.Knockback then
						ScreenShake.Medium()
						kickFOV(-3, 0.25)
					else
						ScreenShake.Light()
					end
				else
					-- Distant combat hit
					if data.Target and data.Target:FindFirstChild("HumanoidRootPart") then
						local pos = data.Target.HumanoidRootPart.Position
						if data.Knockback then
							ScreenShake.ShakeAtPosition(pos, 90, 1.2, 0.35, 24)
						end
					end
				end
			elseif action == "WallSplat" then
				if isMeTarget then
					ScreenShake.WallSplat()
					kickFOV(-6, 0.4)
				elseif isMeAttacker then
					ScreenShake.Heavy()
					kickFOV(-3, 0.3)
				else
					if data.Target and data.Target:FindFirstChild("HumanoidRootPart") then
						ScreenShake.ShakeAtPosition(data.Target.HumanoidRootPart.Position, 100, 1.5, 0.4, 25)
					end
				end
			end
		end)
	end

	-- 2. SkillEvent (Skill casts, Awakening transformation)
	local skillEvent = Remotes:WaitForChild("SkillEvent", 5) :: RemoteEvent?
	if skillEvent then
		skillEvent.OnClientEvent:Connect(function(action: string, data: any)
			if typeof(data) ~= "table" then return end

			local myChar = LocalPlayer.Character
			local isMe = (data.User == myChar or data.Player == LocalPlayer)

			if action == "SkillFired" then
				local skillId = data.SkillId
				if isMe then
					if skillId == 1 then -- Consecutive Punches
						ScreenShake.Medium({ Duration = 0.3, Frequency = 34 })
					elseif skillId == 2 then -- Heavy Punch
						ScreenShake.Heavy()
						kickFOV(-5, 0.35)
					elseif skillId == 3 then -- Ground Slam
						ScreenShake.Explosion()
						kickFOV(-7, 0.4)
					elseif skillId == 4 then -- Flash Dash / Counter
						ScreenShake.Light()
						kickFOV(4, 0.2)
					end
				else
					if data.Position then
						ScreenShake.ShakeAtPosition(data.Position, 120, 1.8, 0.5, 22)
					end
				end
			elseif action == "AwakeningState" then
				if isMe and data.Active == true then
					ScreenShake.Awakening()
					kickFOV(-10, 0.8)
				elseif data.Active == true and data.Position then
					ScreenShake.ShakeAtPosition(data.Position, 150, 2.0, 1.0, 20)
				end
			end
		end)
	end

	-- 3. BlockEvent (Guard Break)
	local blockEvent = Remotes:WaitForChild("BlockEvent", 5) :: RemoteEvent?
	if blockEvent then
		blockEvent.OnClientEvent:Connect(function(targetChar: Model, isBlocking: boolean, guardBroken: boolean)
			if targetChar == LocalPlayer.Character and guardBroken then
				ScreenShake.GuardBreak()
				kickFOV(-8, 0.5)
			end
		end)
	end

	-- 4. DashEvent (Dash feel)
	local dashEvent = Remotes:WaitForChild("DashEvent", 5) :: RemoteEvent?
	if dashEvent then
		dashEvent.OnClientEvent:Connect(function(targetChar: Model, direction: Vector3, isLocal: boolean)
			if targetChar == LocalPlayer.Character then
				kickFOV(3, 0.2)
			end
		end)
	end
end

task.spawn(setupRemoteListeners)

print("[CameraController] Loaded and active.")
