--!strict
-- Start skill handling independently of character setup and M1/dash modules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local RemotesInit = require(remotes:WaitForChild("RemotesInit"))
RemotesInit.InitServer()

local SkillServer = require(script.Parent:WaitForChild("SkillServer"))
SkillServer.Init()
print("[SkillInit] Z/X/C/V skill server ready.")
