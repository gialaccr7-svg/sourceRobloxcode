--!strict
-- CharacterInit.client.luau
-- Runs locally on each player's Goku Character upon spawning.
-- Sets up ragdoll constraints, initializes combat attributes, manages local visual effects,
-- and listens for Space recovery input on ground.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Character = script.Parent :: Model
local Humanoid = Character:WaitForChild("Humanoid", 10) :: Humanoid?
local RootPart = Character:WaitForChild("HumanoidRootPart", 10) :: BasePart?

if not Humanoid or not RootPart then
	return
end

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RagdollHelper = require(Modules:WaitForChild("RagdollHelper"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatEvent = Remotes:WaitForChild("CombatEvent") :: RemoteEvent

-- Pre-initialize ragdoll constraints for smooth physics performance
RagdollHelper.SetupRig(Character)

-- Initialize character combat attributes
Character:SetAttribute("CharacterName", "Goku")
Character:SetAttribute("IsRagdolled", false)
Character:SetAttribute("IsStunned", false)
Character:SetAttribute("IsBlocking", false)
Character:SetAttribute("iFrames", false)
Character:SetAttribute("Rage", 0)
Character:SetAttribute("OriginalWalkSpeed", Humanoid.WalkSpeed)

-- Local Super Saiyan visual effect listener
local hairAccessory = Character:WaitForChild("GokuHair", 3)
local function onAwakeningChanged()
	local isAwakened = Character:GetAttribute("IsAwakened") == true
	local targetColor = if isAwakened then Color3.fromRGB(255, 225, 45) else Color3.fromRGB(15, 15, 20)

	if hairAccessory then
		local handle = hairAccessory:FindFirstChild("Handle") :: BasePart?
		if handle then
			local hairFolder = handle:FindFirstChild("SpikyHairMeshHierarchy")
			if hairFolder then
				for _, spike in ipairs(hairFolder:GetChildren()) do
					if spike:IsA("BasePart") then
						spike.Color = targetColor
						spike.Material = if isAwakened then Enum.Material.Neon else Enum.Material.SmoothPlastic
					end
				end
			end
		end
	end
end

local awakeningConn = Character:GetAttributeChangedSignal("IsAwakened"):Connect(onAwakeningChanged)

-- Debounce for recovery attempts
local lastRecoveryAttempt = 0
local RECOVERY_DEBOUNCE = 0.25

-- Listen for Space key to execute Ragdoll Recovery / Ragdoll Cancel when touching ground
local spaceConn: RBXScriptConnection? = nil
spaceConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Space then
		local now = os.clock()
		if now - lastRecoveryAttempt < RECOVERY_DEBOUNCE then
			return
		end

		if Character:GetAttribute("IsRagdolled") == true then
			-- Verify ground proximity
			if RagdollHelper.IsGrounded(Character) then
				lastRecoveryAttempt = now
				if CombatEvent then
					CombatEvent:FireServer("RagdollRecovery")
				end
			end
		end
	end
end)

-- Cleanup on Character removal
Character.Destroying:Connect(function()
	if spaceConn then
		spaceConn:Disconnect()
		spaceConn = nil
	end
	if awakeningConn then
		awakeningConn:Disconnect()
		awakeningConn = nil
	end
end)
