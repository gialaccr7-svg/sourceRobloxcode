--!strict
-- CombatController.client.luau
-- Main PC Input Coordinator for Roblox Battleground Arena
-- Centralizes PC keybinds (M1, Q+WASD, F, Z/X/C/V, G, Space), input buffering,
-- and interfaces with ClientCombatCore, ClientSkillManager, HUDController, and CameraController.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Disable Roblox default Backpack toolbar for the custom combat HUD
task.spawn(function()
	local tries = 0
	while tries < 15 do
		local success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if success then
			break
		end
		task.wait(0.2)
		tries += 1
	end
end)

-- Remotes
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5) :: Folder?
local RemotesInit = if RemotesFolder and RemotesFolder:FindFirstChild("RemotesInit")
	then require(RemotesFolder:WaitForChild("RemotesInit"))
	else require(ReplicatedStorage.Remotes.RemotesInit)

local CombatEvent = RemotesInit.GetCombatEvent()
local SkillEvent = RemotesInit.GetSkillEvent()
local BlockEvent = RemotesInit.GetBlockEvent()
local DashEvent = RemotesInit.GetDashEvent()

-- Safe access to sibling client managers
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts") :: PlayerScripts

local function safeRequire(parent: Instance?, childName: string)
	if not parent then
		return nil
	end
	local child = parent:FindFirstChild(childName)
	if child and child:IsA("ModuleScript") then
		local success, result = pcall(require, child)
		if success then
			return result
		else
			warn(string.format("[CombatController] Failed to load %s: %s", childName, tostring(result)))
		end
	end
	return nil
end

-- A yielding require must not prevent keyboard listeners from being connected.
local ClientCombatCore
local ClientSkillManager
task.spawn(function()
	ClientCombatCore = safeRequire(PlayerScripts, "ClientCombatCore")
end)
task.spawn(function()
	ClientSkillManager = safeRequire(PlayerScripts, "ClientSkillManager")
end)

local function getClientSkillManager()
	return ClientSkillManager
end

local function getClientCombatCore()
	return ClientCombatCore
end

-- Shared modules
local Modules = ReplicatedStorage:WaitForChild("Modules", 5) :: Folder?
local RagdollHelper
local DamagePopup
task.spawn(function()
	RagdollHelper = safeRequire(Modules, "RagdollHelper")
end)
task.spawn(function()
	DamagePopup = safeRequire(Modules, "DamagePopup")
end)
task.spawn(function()
	safeRequire(Modules, "VFXHelper")
end)

-- Input debounces and buffering
local lastSpacePress = 0
local SPACE_RECOVERY_DEBOUNCE = 0.25

-- Checks if local player's character is eligible to perform actions
local function isCharacterAbleToAct(): (boolean, Model?, Humanoid?)
	local character = LocalPlayer.Character
	if not character or not character.Parent then
		return false, nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, character, humanoid
	end

	if character:GetAttribute("IsRagdolled") == true then
		return false, character, humanoid
	end

	if character:GetAttribute("IsStunned") == true then
		return false, character, humanoid
	end

	return true, character, humanoid
end

-- Key & Action Handlers

local function handleM1Attack()
	local core = getClientCombatCore()
	if core and core.PerformM1 then
		core.PerformM1()
	else
		-- Direct fallback
		local canAct, character, _ = isCharacterAbleToAct()
		if canAct and character and not character:GetAttribute("IsBlocking") then
			CombatEvent:FireServer("M1", 1)
		end
	end
end

local function handleDash()
	local core = getClientCombatCore()
	if core and core.PerformDash then
		core.PerformDash()
	else
		-- Direct fallback
		local canAct, character, _ = isCharacterAbleToAct()
		if canAct and character then
			local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local dir = if hrp then hrp.CFrame.LookVector else Vector3.new(0, 0, -1)
			DashEvent:FireServer(dir, "Front")
		end
	end
end

local function handleBlockStart()
	local core = getClientCombatCore()
	if core and core.StartBlock then
		core.StartBlock()
	else
		local canAct, character, _ = isCharacterAbleToAct()
		if canAct and character then
			character:SetAttribute("IsBlocking", true)
			BlockEvent:FireServer(true)
		end
	end
end

local function handleBlockStop()
	local character = LocalPlayer.Character
	if character then
		character:SetAttribute("IsBlocking", false)
	end

	local core = getClientCombatCore()
	if core and core.StopBlock then
		core.StopBlock()
	else
		BlockEvent:FireServer(false)
	end
end

-- UIS and CAS can report the same physical press. Deduplicate the InputObject,
-- rather than delaying a new press (including a retry after a rejected cast).
local lastSkillInputs: { [number]: InputObject } = {}
local SKILL_KEYS = {
	[Enum.KeyCode.Z] = 1,
	[Enum.KeyCode.X] = 2,
	[Enum.KeyCode.C] = 3,
	[Enum.KeyCode.V] = 4,
}
local function handleSkillKey(skillId: number, input: InputObject)
	if lastSkillInputs[skillId] == input then
		return
	end
	lastSkillInputs[skillId] = input

	local csm = getClientSkillManager()
	if csm and csm.CastSkill then
		csm.CastSkill(skillId)
	else
		-- Direct fallback
		local canAct, _, _ = isCharacterAbleToAct()
		if canAct then
			SkillEvent:FireServer("CastSkill", skillId)
		end
	end
end

local lastAwakeningPress = 0
local function handleAwakening()
	local now = os.clock()
	if now - lastAwakeningPress < 0.5 then
		return
	end
	lastAwakeningPress = now

	local csm = getClientSkillManager()
	if csm and csm.ActivateAwakening then
		csm.ActivateAwakening()
	else
		-- Direct fallback
		local character = LocalPlayer.Character
		if character then
			local rage = character:GetAttribute("Rage") or 0
			if rage >= 100 then
				SkillEvent:FireServer("Awakening")
			end
		end
	end
end

local function handleRagdollRecovery()
	local character = LocalPlayer.Character
	if not character or not character.Parent then
		return
	end

	local now = os.clock()
	if now - lastSpacePress < SPACE_RECOVERY_DEBOUNCE then
		return
	end
	lastSpacePress = now

	-- Check if player is currently in ragdoll state and touching ground
	if character:GetAttribute("IsRagdolled") == true then
		local isGrounded = false
		if RagdollHelper and RagdollHelper.IsGrounded then
			isGrounded = RagdollHelper.IsGrounded(character)
		else
			-- Fallback raycast
			local hrp = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("LowerTorso")
			if hrp and hrp:IsA("BasePart") then
				local ray = workspace:Raycast(hrp.Position, Vector3.new(0, -4.0, 0))
				isGrounded = (ray ~= nil)
			end
		end

		if isGrounded then
			CombatEvent:FireServer("RagdollRecovery")
		end
	end
end

-- Primary User Input Connections
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	-- If user is typing in a TextBox (e.g. Chat or custom GUI), do not trigger combat inputs
	if UserInputService:GetFocusedTextBox() ~= nil then
		return
	end

	-- Keys Z, X, C, V and G: NEVER drop or sink due to CoreGui or gameProcessed
	local skillId = SKILL_KEYS[input.KeyCode]
	if skillId then
		handleSkillKey(skillId, input)
		return
	elseif input.KeyCode == Enum.KeyCode.G then
		handleAwakening()
		return
	end

	-- For regular combat inputs (M1, Dash, Block, Space), respect gameProcessed
	if gameProcessed then
		return
	end

	-- Left Mouse Button (M1 Attack)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		handleM1Attack()

	-- Dash (Q)
	elseif input.KeyCode == Enum.KeyCode.Q then
		handleDash()

	-- Block (F - Hold)
	elseif input.KeyCode == Enum.KeyCode.F then
		handleBlockStart()

	-- Space (Ragdoll Recovery on Ground)
	elseif input.KeyCode == Enum.KeyCode.Space then
		handleRagdollRecovery()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	local skillId = SKILL_KEYS[input.KeyCode]
	if skillId then
		lastSkillInputs[skillId] = nil
	end
	-- Release Block (F)
	if input.KeyCode == Enum.KeyCode.F then
		handleBlockStop()
	end
end)

-- Window Focus Failsafe: Reset blocking and input state when window focus changes
-- (Prevents permanent block/combo freeze when clicking Studio Explorer or pressing F in Studio)
local function resetAllInputStates()
	table.clear(lastSkillInputs)
	handleBlockStop()
	local character = LocalPlayer.Character
	if character then
		character:SetAttribute("IsBlocking", false)
	end
end

UserInputService.WindowFocusReleased:Connect(resetAllInputStates)
UserInputService.WindowFocused:Connect(resetAllInputStates)

-- High-Priority ContextActionService Binding as Failsafe
local function onSkillAction(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject)
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		local skillNum = SKILL_KEYS[inputObject.KeyCode]
		if skillNum then lastSkillInputs[skillNum] = nil end
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		if UserInputService:GetFocusedTextBox() ~= nil then
			return Enum.ContextActionResult.Pass
		end
		local skillNum = tonumber(string.match(actionName, "(%d+)"))
		if skillNum then
			handleSkillKey(skillNum, inputObject)
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end

for keyCode, skillId in SKILL_KEYS do
	ContextActionService:BindActionAtPriority("SkillKey_" .. skillId, onSkillAction, false, Enum.ContextActionPriority.High.Value + 100, keyCode)
end

-- Remote Event Listeners for UI / Damage popups
CombatEvent.OnClientEvent:Connect(function(action: string, data: any)
	if typeof(data) ~= "table" then
		return
	end

	if action == "HitConfirm" then
		local target = data.Target :: Model?
		local damage = data.Damage or 0
		local isCrit = data.Knockback == true
		local isBlocked = data.Blocked == true

		if target and damage > 0 and DamagePopup and DamagePopup.Spawn then
			local hrp = target:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local color = if isBlocked
					then Color3.fromRGB(180, 180, 180)
					elseif isCrit then Color3.fromRGB(255, 170, 0)
					else Color3.fromRGB(255, 50, 50)
				local text = if isBlocked then string.format("-%d (Block)", math.floor(damage)) else string.format("-%d", math.floor(damage))
				pcall(function()
					DamagePopup.Spawn(hrp.Position, text, color)
				end)
			end
		end
	end
end)

print("[CombatController] Z/X/C/V input ready (skill-input-fix-2).")
