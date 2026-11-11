--!strict
-- RemotesInit.luau
-- Authoritative RemoteEvent & RemoteFunction infrastructure for Server-Client communication
-- Provides clean accessors and automated lazy/eager initializers for all core remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemotesCollection = {
	CombatEvent: RemoteEvent,
	SkillEvent: RemoteEvent,
	BlockEvent: RemoteEvent,
	DashEvent: RemoteEvent,
}

local RemotesInit = {}

local REQUIRED_REMOTE_EVENTS = {
	"CombatEvent",
	"SkillEvent",
	"BlockEvent",
	"DashEvent",
	"AnimationEvent",
}

-- Returns the Remotes folder, creating it on server or waiting for it on client
function RemotesInit.GetRemotesFolder(): Folder
	local isServer = RunService:IsServer()
	local folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?

	if not folder then
		if isServer then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		else
			folder = ReplicatedStorage:WaitForChild("Remotes", 10) :: Folder?
			if not folder then
				error("[RemotesInit] Client timed out waiting for ReplicatedStorage.Remotes folder")
			end
		end
	end

	return folder
end

-- Server-side initialization of all remote events
function RemotesInit.InitServer(): Folder
	local folder = RemotesInit.GetRemotesFolder()

	for _, remoteName in REQUIRED_REMOTE_EVENTS do
		local existing = folder:FindFirstChild(remoteName)
		if not existing then
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = remoteName
			newRemote.Parent = folder
		end
	end

	return folder
end

-- Retrieves a specific remote event safely
function RemotesInit.GetRemoteEvent(name: string): RemoteEvent
	local folder = RemotesInit.GetRemotesFolder()
	local remote = folder:FindFirstChild(name) :: RemoteEvent?

	if not remote then
		if RunService:IsServer() then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		else
			remote = folder:WaitForChild(name, 10) :: RemoteEvent?
			if not remote then
				error(string.format("[RemotesInit] Client timed out waiting for RemoteEvent: %s", name))
			end
		end
	end

	return remote
end

-- Specific typed getters for convenience
function RemotesInit.GetCombatEvent(): RemoteEvent
	return RemotesInit.GetRemoteEvent("CombatEvent")
end

function RemotesInit.GetSkillEvent(): RemoteEvent
	return RemotesInit.GetRemoteEvent("SkillEvent")
end

function RemotesInit.GetBlockEvent(): RemoteEvent
	return RemotesInit.GetRemoteEvent("BlockEvent")
end

function RemotesInit.GetDashEvent(): RemoteEvent
	return RemotesInit.GetRemoteEvent("DashEvent")
end

-- Returns all core remotes as a dictionary
function RemotesInit.GetRemotes(): RemotesCollection
	return {
		CombatEvent = RemotesInit.GetCombatEvent(),
		SkillEvent = RemotesInit.GetSkillEvent(),
		BlockEvent = RemotesInit.GetBlockEvent(),
		DashEvent = RemotesInit.GetDashEvent(),
	}
end

-- Auto-initialize if running on server during require
if RunService:IsServer() then
	RemotesInit.InitServer()
end

return RemotesInit
