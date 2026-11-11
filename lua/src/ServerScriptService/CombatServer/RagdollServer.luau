--!strict
-- RagdollServer.luau
-- Server authority for R15 ragdoll activation, knockdown handling, and Space recovery requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local CombatConfig = require(Modules:WaitForChild("CombatConfig"))
local RagdollHelper = require(Modules:WaitForChild("RagdollHelper"))

type RagdollState = {
	Character: Model,
	StartTime: number,
	EndTime: number,
	RecoveryAllowedTime: number,
}

local RagdollServer = {}
local activeRagdolls: { [Model]: RagdollState } = {}

-- Safely retrieves or waits for CombatEvent remote
local function getCombatRemote(): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
	if not remotes then
		return nil
	end
	return remotes:FindFirstChild("CombatEvent") :: RemoteEvent?
end

-- Server entry point for activating ragdoll on a character
function RagdollServer.RagdollCharacter(character: Model, duration: number?)
	local dur = duration or CombatConfig.KnockdownDuration
	local now = os.clock()

	activeRagdolls[character] = {
		Character = character,
		StartTime = now,
		EndTime = now + dur,
		RecoveryAllowedTime = now + CombatConfig.RagdollMinRecoveryTime,
	}

	RagdollHelper.Ragdoll(character)

	local combatEvent = getCombatRemote()
	if combatEvent then
		combatEvent:FireAllClients("RagdollActive", {
			Target = character,
			Duration = dur,
		})
	end
end

-- Checks if a character is currently managed in ragdoll state
function RagdollServer.IsRagdolled(character: Model): boolean
	return activeRagdolls[character] ~= nil or RagdollHelper.IsRagdolled(character)
end

-- Force unragdolls character immediately
function RagdollServer.UnragdollCharacter(character: Model)
	activeRagdolls[character] = nil
	RagdollHelper.Unragdoll(character)

	local combatEvent = getCombatRemote()
	if combatEvent then
		combatEvent:FireAllClients("RagdollEnded", {
			Target = character,
		})
	end
end

-- Handles space-bar ground recovery request from client
function RagdollServer.AttemptRecovery(player: Player): boolean
	local character = player.Character
	if not character or not RagdollServer.IsRagdolled(character) then
		return false
	end

	local state = activeRagdolls[character]
	local now = os.clock()
	if state and now < state.RecoveryAllowedTime then
		-- Recovery lock is still active (cannot instant-cancel before touching ground)
		return false
	end

	-- Ground raycast verification
	if not RagdollHelper.IsGrounded(character) then
		return false
	end

	-- Successfully grounded: cancel ragdoll
	activeRagdolls[character] = nil
	RagdollHelper.Unragdoll(character)

	-- Apply recovery invulnerability window
	character:SetAttribute("iFrames", true)
	task.delay(CombatConfig.RecoveryiFrames, function()
		if character and character.Parent then
			character:SetAttribute("iFrames", false)
		end
	end)

	-- Notify clients for recovery roll animation/sound
	local combatEvent = getCombatRemote()
	if combatEvent then
		combatEvent:FireAllClients("RagdollRecovery", {
			Target = character,
		})
	end

	return true
end

-- Periodic heartbeat check for expired ragdoll timers
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for character, state in pairs(activeRagdolls) do
		if not character.Parent then
			activeRagdolls[character] = nil
		elseif now >= state.EndTime then
			-- Timer expired: if grounded, stand up; if in midair, wait until touching ground
			if RagdollHelper.IsGrounded(character) or (now - state.EndTime > 2.0) then
				RagdollServer.UnragdollCharacter(character)
			end
		end
	end
end)

-- Character cleanup on removal
Players.PlayerRemoving:Connect(function(player)
	if player.Character and activeRagdolls[player.Character] then
		activeRagdolls[player.Character] = nil
	end
end)

return RagdollServer
