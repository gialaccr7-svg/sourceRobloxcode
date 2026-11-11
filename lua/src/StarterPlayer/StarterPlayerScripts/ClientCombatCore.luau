--!strict
-- ClientCombatCore.luau
-- Client controller for M1 Combo inputs, F Block stance, Q 4-directional Dash with i-frames,
-- and Dash Cancel combo extension mechanics.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local RagdollHelper = require(Modules:WaitForChild("RagdollHelper"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5) :: Folder
local CombatEvent = Remotes:WaitForChild("CombatEvent") :: RemoteEvent
local BlockEvent = Remotes:WaitForChild("BlockEvent") :: RemoteEvent
local DashEvent = Remotes:WaitForChild("DashEvent") :: RemoteEvent

-- Local state
local comboStep = 1
local lastM1Time = 0
local lastDashTime = 0
local isBlocking = false
local isM1Cooldown = false

local AnimationManager = require(Modules:WaitForChild("AnimationManager"))

local function playProceduralM1(character: Model, step: number)
 AnimationManager.PlayAnimation(character, "M1_" .. tostring(step))
end
local function setBlockPose(character: Model, active: boolean)
 if active then AnimationManager.PlayAnimation(character, "Block")
 else AnimationManager.StopAnimation(character, "Block", 0.12) end
end

-- Screen shake trigger helper for heavy hits
local function triggerScreenShake(intensity: number)
	if not Camera then
		return
	end
	task.spawn(function()
		local duration = 0.2
		local startTime = os.clock()
		while os.clock() - startTime < duration do
			local offset = Vector3.new(
				(math.random() - 0.5) * intensity,
				(math.random() - 0.5) * intensity,
				(math.random() - 0.5) * intensity
			)
			Camera.CFrame = Camera.CFrame * CFrame.new(offset)
			task.wait()
		end
	end)
end

-- Checks if local player can perform actions
local function canAct(): boolean
	local character = LocalPlayer.Character
	if not character or not character.Parent then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if RagdollHelper.IsRagdolled(character) then
		return false
	end
	if character:GetAttribute("IsStunned") == true then
		return false
	end
	return true
end

-- Handle M1 Attack Click
local function performM1()
	if not canAct() or isBlocking or isM1Cooldown or (LocalPlayer.Character and LocalPlayer.Character:GetAttribute("IsAttacking") == true) then
		return
	end

	local character = LocalPlayer.Character
	if not character then
		return
	end

	local now = os.clock()
	if now - lastM1Time > CombatConfig.ComboResetTime then
		comboStep = 1
	end

	local currentStep = comboStep
	local stepConfig = CombatConfig.M1[currentStep]
	if not stepConfig then
		comboStep = 1
		stepConfig = CombatConfig.M1[1]
		currentStep = 1
	end

	isM1Cooldown = true
	lastM1Time = now

	-- Play client-side prediction visual and sound
	playProceduralM1(character, currentStep)

	-- Advance local combo step
	if currentStep >= CombatConfig.MaxComboSteps then
		comboStep = 1
	else
		comboStep = currentStep + 1
	end

	-- Fire attack to server
	CombatEvent:FireServer("M1", currentStep)

	-- Reset attack cooldown
	task.delay(stepConfig.Cooldown, function()
		isM1Cooldown = false
	end)
end

-- Determine 4-directional Dash Vector
local function getDashDirection(): (Vector3, string)
	local isW = UserInputService:IsKeyDown(Enum.KeyCode.W)
	local isS = UserInputService:IsKeyDown(Enum.KeyCode.S)
	local isA = UserInputService:IsKeyDown(Enum.KeyCode.A)
	local isD = UserInputService:IsKeyDown(Enum.KeyCode.D)

	local x = 0
	local z = 0

	if isW then z -= 1 end
	if isS then z += 1 end
	if isA then x -= 1 end
	if isD then x += 1 end

	local moveInput = Vector3.new(x, 0, z)
	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	local dashType = "Front"
	if z > 0 then
		dashType = "Back"
	elseif x < 0 then
		dashType = "Left"
	elseif x > 0 then
		dashType = "Right"
	end

	if not hrp then
		return Vector3.new(0, 0, -1), dashType
	end

	if moveInput.Magnitude < 0.1 then
		-- Default to facing forward
		return hrp.CFrame.LookVector, "Front"
	end

	-- Transform local movement direction relative to camera/character orientation
	local cameraCFrame = Camera and Camera.CFrame or hrp.CFrame
	local flatLook = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z)
	local flatCameraLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else (if hrp then hrp.CFrame.LookVector else Vector3.new(0, 0, -1))
	local flatRight = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)
	local flatCameraRight = if flatRight.Magnitude > 0.01 then flatRight.Unit else Vector3.new(1, 0, 0)
	local rawDir = flatCameraRight * moveInput.X + flatCameraLook * (-moveInput.Z)
	local worldDir = if rawDir.Magnitude > 0.01 then rawDir.Unit else (if hrp then hrp.CFrame.LookVector else Vector3.new(0, 0, -1))
	return worldDir, dashType
end

-- Handle Dash (Q) and Dash Cancel
local function performDash()
	if not canAct() then
		return
	end

	local character = LocalPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	local now = os.clock()
	local isDashCancel = (now - lastM1Time <= CombatConfig.DashCancelWindow)

	-- Cooldown validation
	if not isDashCancel and (now - lastDashTime < CombatConfig.DashCooldown) then
		return
	end

	lastDashTime = now

	-- If dash cancel was triggered, instantly cancel M1 lock
	if isDashCancel then
		isM1Cooldown = false
	end

	local dir, dashType = getDashDirection()

	-- Client prediction impulse
	hrp.AssemblyLinearVelocity = dir * CombatConfig.DashSpeed
	character:SetAttribute("iFrames", true)
	task.delay(CombatConfig.iFrameDuration, function()
		if character and character.Parent then
			character:SetAttribute("iFrames", false)
		end
	end)

	-- Send to server
	DashEvent:FireServer(dir, dashType)
end

-- Handle Block start and end (F key)
local function startBlock()
	if not canAct() or isBlocking then
		return
	end

	local character = LocalPlayer.Character
	if not character then
		return
	end

	isBlocking = true
	setBlockPose(character, true)
	BlockEvent:FireServer(true)
end

local function stopBlock()
	if not isBlocking then
		return
	end

	local character = LocalPlayer.Character
	if character then
		setBlockPose(character, false)
	end

	isBlocking = false
	BlockEvent:FireServer(false)
end

-- CombatController owns input dispatch, preventing duplicate action requests.

-- Server Event Listeners for VFX, Camera Shake, and Sounds
CombatEvent.OnClientEvent:Connect(function(action: string, data: any)
	if action == "HitConfirm" and typeof(data) == "table" then
		local shakeIntensity = 0.15
		if data.Knockback then
			shakeIntensity = 0.5
		end

		if data.Target == LocalPlayer.Character then
			-- Local player took damage
			triggerScreenShake(shakeIntensity)
		elseif data.Attacker == LocalPlayer.Character then
			-- Local player landed hit
			if data.Knockback then
				triggerScreenShake(0.25)
			end
		end
	elseif action == "WallSplat" and typeof(data) == "table" then
		if data.Target == LocalPlayer.Character then
			triggerScreenShake(0.7)
		else
			triggerScreenShake(0.3)
		end
	end
end)

BlockEvent.OnClientEvent:Connect(function(targetChar: Model, isTargetBlocking: boolean, guardBroken: boolean)
	if targetChar == LocalPlayer.Character then
		if guardBroken then
			stopBlock()
			triggerScreenShake(0.4)
		end
	end
end)

return {
	PerformM1 = performM1,
	PerformDash = performDash,
	StartBlock = startBlock,
	StopBlock = stopBlock,
}
