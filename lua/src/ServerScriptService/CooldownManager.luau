--!strict
-- CooldownManager.luau
-- Server-authoritative cooldown management for skills, combat actions, and dash
-- Supports Awakening cooldown reduction modifiers (CDR) and automatic player lifecycle cleanup.

local Players = game:GetService("Players")

export type AwakeningData = {
	IsAwakened: boolean,
	ReductionMultiplier: number, -- e.g. 0.30 for 30% reduction
}

local CooldownManager = {}

-- Table structure: [Player] -> { [actionKey: string]: number (expireTimestamp) }
local playerCooldowns: { [Player]: { [string]: number } } = {}

-- Table structure: [Player] -> AwakeningData
local playerAwakening: { [Player]: AwakeningData } = {}

-- Gets or creates cooldown map for a player
local function getCooldownMap(player: Player): { [string]: number }
	local map = playerCooldowns[player]
	if not map then
		map = {}
		playerCooldowns[player] = map
	end
	return map
end

-- Sets an action cooldown for a player, applying Awakening reduction if active.
-- Returns the actual applied duration.
function CooldownManager.SetCooldown(player: Player, actionKey: string, baseDuration: number): number
	if not player or not player.Parent then
		return 0
	end

	local duration = math.max(0, baseDuration)
	local awakening = playerAwakening[player]

	if awakening and awakening.IsAwakened then
		local reduction = math.clamp(awakening.ReductionMultiplier, 0, 0.9)
		duration = duration * (1 - reduction)
	end

	local map = getCooldownMap(player)
	map[actionKey] = os.clock() + duration

	return duration
end

-- Checks if a player's action is currently on cooldown
function CooldownManager.IsOnCooldown(player: Player, actionKey: string): boolean
	local map = playerCooldowns[player]
	if not map then
		return false
	end

	local expireTime = map[actionKey]
	if not expireTime then
		return false
	end

	return os.clock() < expireTime
end

-- Returns the remaining cooldown in seconds (or 0 if ready)
function CooldownManager.GetRemainingCooldown(player: Player, actionKey: string): number
	local map = playerCooldowns[player]
	if not map then
		return 0
	end

	local expireTime = map[actionKey]
	if not expireTime then
		return 0
	end

	local remaining = expireTime - os.clock()
	return if remaining > 0 then remaining else 0
end

-- Resets a specific action cooldown for a player
function CooldownManager.ResetCooldown(player: Player, actionKey: string)
	local map = playerCooldowns[player]
	if map then
		map[actionKey] = nil
	end
end

-- Resets all cooldowns for a player
function CooldownManager.ResetAll(player: Player)
	playerCooldowns[player] = nil
end

-- Configures Awakening state and cooldown reduction fraction (e.g. 0.30 for 30% reduction)
function CooldownManager.SetAwakening(player: Player, isAwakened: boolean, reductionMultiplier: number?)
	if not player then
		return
	end

	if isAwakened then
		playerAwakening[player] = {
			IsAwakened = true,
			ReductionMultiplier = reductionMultiplier or 0.30,
		}
	else
		playerAwakening[player] = nil
	end
end

-- Returns whether player is currently awakened
function CooldownManager.IsAwakened(player: Player): boolean
	local data = playerAwakening[player]
	return data ~= nil and data.IsAwakened == true
end

-- Returns awakening CDR fraction for a player (0.0 if not awakened)
function CooldownManager.GetAwakeningDiscount(player: Player): number
	local data = playerAwakening[player]
	if data and data.IsAwakened then
		return data.ReductionMultiplier
	end
	return 0
end

-- Cleans up memory when a player leaves
function CooldownManager.OnPlayerRemoving(player: Player)
	playerCooldowns[player] = nil
	playerAwakening[player] = nil
end

-- Automatic lifecycle connection
Players.PlayerRemoving:Connect(CooldownManager.OnPlayerRemoving)

return CooldownManager
