// Run with: node tests/skill-input.cjs [path/to/luau.exe]
// Execute the actual modules against minimal Roblox service doubles.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const source = `
local function signal()
 local callbacks = {}
 return {
  Connect = function(_, callback) table.insert(callbacks, callback) end,
  Fire = function(_, ...) for _, callback in callbacks do callback(...) end end,
 }
end
local now = 10
local os = { clock = function() return now end }
local task = { spawn = function(callback) callback() end, delay = function() end }
local attrs = {}
local humanoid = { Health = 100 }
local character = {
 Parent = true,
 GetAttribute = function(_, key) return attrs[key] end,
 SetAttribute = function(_, key, value) attrs[key] = value end,
 FindFirstChildOfClass = function() return humanoid end,
 FindFirstChild = function() return nil end,
}
local player = { Character = character, CharacterAdded = signal() }
local requests, order = {}, {}
local event = {
 OnClientEvent = signal(),
 FireServer = function(_, action, slot)
  table.insert(requests, { action, slot })
  table.insert(order, 'request')
 end,
}
local folder = {
 FindFirstChild = function() return event end,
 WaitForChild = function() return event end,
}
local moves = {
 GetSkill = function(slot) if slot >= 1 and slot <= 4 then return { AnimationName = 'Skill', WindupTime = 0.1 } end return nil end,
 GetCooldown = function() return 10 end,
 AwakeningConfig = { RequiredRageMeter = 100 },
}
local animationFails = false
local animation = { PlayAnimation = function()
 table.insert(order, 'animation')
 if animationFails then error('simulated visual failure') end
end }
local stoppedBlock = 0
local core = { StopBlock = function() stoppedBlock += 1 end }
local modules = { MovesetData = moves, AnimationManager = animation }
function modules:FindFirstChild(name) return self[name] end
function modules:WaitForChild(name) return self[name] end
local replicated = {
 FindFirstChild = function(_, name) if name == 'Modules' then return modules end return folder end,
 WaitForChild = function(_, name) if name == 'Modules' then return modules end return folder end,
}
local userInput = {
 InputBegan = signal(), InputEnded = signal(), WindowFocused = signal(), WindowFocusReleased = signal(),
 GetFocusedTextBox = function() return nil end,
}
local bindings = {}
local boundKeys = {}
local services = {
 Players = { LocalPlayer = player }, ReplicatedStorage = replicated,
 RunService = { IsClient = function() return true end, IsServer = function() return false end },
 UserInputService = userInput,
 StarterGui = { SetCoreGuiEnabled = function() end },
 ContextActionService = { BindActionAtPriority = function(_, name, callback, _, _, key)
  bindings[name] = callback
  boundKeys[name] = key
 end },
}
local game = { GetService = function(_, name)
 assert(services[name], 'Invalid service: ' .. name)
 return services[name]
end }
local require = function(value) return value end
local script = { Parent = { WaitForChild = function() return core end } }
local remotes = (function()
${read('src/ReplicatedStorage/Remotes/RemotesInit.luau')}
end)()
assert(remotes.GetSkillEvent() == event, 'Remotes must initialize on the client')
services.RunService.IsServer = function() return true end
assert(remotes.InitServer() == folder, 'Remotes must initialize on the server')
services.RunService.IsServer = function() return false end
local manager = (function()
${read('src/StarterPlayer/StarterPlayerScripts/ClientSkillManager.luau')}
end)()
for slot = 1, 4 do
 attrs.IsAttacking = true
 attrs.IsBlocking = true
 local before = #requests
 table.clear(order)
 manager.CastSkill(slot)
 assert(#requests == before + 1 and requests[#requests][2] == slot, 'Skill must cast during M1: ' .. slot)
 assert(order[1] == 'request' and order[2] == 'animation', 'Request must precede visuals')
 assert(attrs.IsBlocking == false, 'Skill must release block')
 manager.CastSkill(slot)
 assert(#requests == before + 1, 'Cooldown must reject repeat casts')
end
assert(stoppedBlock == 4, 'Must release the local block controller')
now += 11
for _, lock in { 'IsStunned', 'IsRagdolled', 'IsCountering' } do
 attrs[lock] = true
 local before = #requests
 manager.CastSkill(1)
 assert(#requests == before, 'Must respect state lock: ' .. lock)
 attrs[lock] = false
end
humanoid.Health = 0
local before = #requests
manager.CastSkill(1)
assert(#requests == before, 'Dead characters cannot cast')
humanoid.Health = 100
animationFails = true
local ok = pcall(manager.CastSkill, 1)
assert(not ok and #requests == before + 1, 'Visual failure must not swallow server intent')
animationFails = false
player.CharacterAdded:Fire(character)
assert(manager.GetRemainingCooldown(1) == 0, 'Respawn must clear cooldown')

-- Load the entire input coordinator to exercise both UIS and CAS entry points.
local casts = {}
local inputManager = { CastSkill = function(slot) table.insert(casts, slot) end }
local function module(value)
 return { IsA = function() return true end, value = value }
end
local children = { ClientCombatCore = module(core), ClientSkillManager = module(inputManager) }
local scripts = { FindFirstChild = function(_, name) return children[name] end }
function player:WaitForChild() return scripts end
folder.FindFirstChild = function(_, name) if name == 'RemotesInit' then return module(remotes) end return event end
folder.WaitForChild = folder.FindFirstChild
require = function(value) return value.value or value end
local Enum = {
 CoreGuiType = { Backpack = 1 }, KeyCode = { Z = 1, X = 2, C = 3, V = 4, G = 5, One = 11, Two = 12, Three = 13, Four = 14 },
 UserInputState = { Begin = 1, End = 2 }, ContextActionResult = { Pass = 1, Sink = 2 },
 ContextActionPriority = { High = { Value = 100 } },
}
(function()
${read('src/StarterPlayer/StarterPlayerScripts/CombatController.client.luau')}
end)()
for slot = 1, 4 do
 assert(boundKeys['SkillKey_' .. slot] == slot, 'CAS must bind Z/X/C/V to the matching slot')
 local input = { KeyCode = slot }
 local before = #casts
 userInput.InputBegan:Fire(input, true)
 bindings['SkillKey_' .. slot]('SkillKey_' .. slot, Enum.UserInputState.Begin, input)
 assert(#casts == before + 1 and casts[#casts] == slot, 'UIS/CAS must dispatch once per press')
 -- A new physical press at the exact same clock time must work immediately.
 local nextInput = { KeyCode = slot }
 bindings['SkillKey_' .. slot]('SkillKey_' .. slot, Enum.UserInputState.Begin, nextInput)
 userInput.InputBegan:Fire(nextInput, true)
 assert(#casts == before + 2, 'Fast retry must not be throttled')
 userInput.InputEnded:Fire(nextInput)
 userInput.InputBegan:Fire(nextInput, true)
 assert(#casts == before + 3, 'Reused keyboard InputObjects must work after release')
 bindings['SkillKey_' .. slot]('SkillKey_' .. slot, Enum.UserInputState.End, nextInput)
 bindings['SkillKey_' .. slot]('SkillKey_' .. slot, Enum.UserInputState.Begin, nextInput)
 assert(#casts == before + 4, 'CAS release must rearm a reused InputObject')
end
local beforeNumbers = #casts
for _, key in { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four } do
 userInput.InputBegan:Fire({ KeyCode = key }, true)
end
assert(#casts == beforeNumbers, 'Number keys must no longer cast skills')
userInput.GetFocusedTextBox = function() return {} end
local before = #casts
userInput.InputBegan:Fire({ KeyCode = 1 }, false)
bindings.SkillKey_1('SkillKey_1', Enum.UserInputState.Begin, { KeyCode = 1 })
assert(#casts == before, 'Typing in chat must not cast skills')
-- Regression: hanging dependencies used to prevent ALL keyboard registration.
userInput.InputBegan = signal()
userInput.InputEnded = signal()
userInput.GetFocusedTextBox = function() return nil end
task.spawn = function(callback)
 local thread = coroutine.create(callback)
 local ok, err = coroutine.resume(thread)
 assert(ok, err)
end
local normalRequire = require
require = function(value)
 if value.value == core or value.value == inputManager then coroutine.yield() end
 return normalRequire(value)
end
(function()
${read('src/StarterPlayer/StarterPlayerScripts/CombatController.client.luau')}
end)()
for slot = 1, 4 do
 local before = #requests
 local input = { KeyCode = slot }
 userInput.InputBegan:Fire(input, true)
 bindings['SkillKey_' .. slot]('SkillKey_' .. slot, Enum.UserInputState.Begin, input)
 assert(#requests == before + 1 and requests[#requests][2] == slot, 'Stalled modules must not block skill intent')
end
print('PASS: remotes startup; all four skills; M1/block; cooldown/state/death guards; visual failure; respawn; dual input dispatch; fast retries; chat focus')
`;
const output = path.join(root, '.tools', 'skill-input.generated.luau');
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, source);
const result = spawnSync(process.argv[2] || path.join(root, '.tools', 'luau', 'luau.exe'), [output], { stdio: 'inherit' });
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
