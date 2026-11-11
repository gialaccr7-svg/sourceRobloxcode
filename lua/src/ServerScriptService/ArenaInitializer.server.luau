--!strict
-- ArenaInitializer.server.luau
-- Tags arena parts with CollectionService for Wall Splat and Destructible systems
local CollectionService = game:GetService('CollectionService')
local arena = workspace:WaitForChild("BattleArena")

local walls = arena:FindFirstChild('Walls')
if walls then
    for _, part in ipairs(walls:GetChildren()) do
        if part:IsA('BasePart') then
            CollectionService:AddTag(part, 'WallSplatSurface')
        end
    end
end

local destructibles = arena:FindFirstChild('Destructibles')
if destructibles then
    for _, part in ipairs(destructibles:GetChildren()) do
        if part:IsA('BasePart') then
            CollectionService:AddTag(part, 'Destructible')
        end
    end
end
print('[ArenaInitializer] Tenkaichi Budokai Arena tags initialized successfully.')
