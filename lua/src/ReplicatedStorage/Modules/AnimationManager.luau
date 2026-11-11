--!strict
-- Render poses after Animator evaluation; never change bind-pose C0/C1.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sequences = require(script.Parent:WaitForChild("GokuChoreography"))
local AnimationManager = {}
type Pose = { [string]: CFrame }
type State = { name: string, motors: { [string]: Motor6D }, pose: Pose, from: Pose, index: number, elapsed: number, speed: number, stopping: boolean, fade: number, onStep: ((number) -> ())?, onComplete: (() -> ())? }
local states: { [Model]: State } = {}
local assets: { [string]: string } = {}
local tracks: { [Model]: { [string]: AnimationTrack } } = {}
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AnimationEvent") :: RemoteEvent

local function begin(character: Model, name: string, speed: number?, onStep: ((number) -> ())?, onComplete: (() -> ())?)
 if not Sequences[name] then return end
 local motors: { [string]: Motor6D } = {}
 local pose: Pose = {}
 local previous = states[character]
 for _, joint in character:GetDescendants() do
  if joint:IsA("Motor6D") then
   motors[joint.Name] = joint
   pose[joint.Name] = if previous then previous.pose[joint.Name] or CFrame.identity else joint.Transform
  end
 end
 states[character] = { name = name, motors = motors, pose = pose, from = table.clone(pose), index = 1, elapsed = 0, speed = math.max(speed or 1, 0.05), stopping = false, fade = 0.12, onStep = onStep, onComplete = onComplete }
 if onStep then onStep(1) end
end
local function stop(character: Model, name: string?, fade: number?)
 local state = states[character]
 if state and (not name or state.name == name) then
  state.stopping = true
  state.elapsed = 0
  state.fade = math.max(fade or 0.12, 0.001)
  state.from = table.clone(state.pose)
 end
end
if RunService:IsClient() then
 RunService.PreSimulation:Connect(function(dt)
  for character, state in states do
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if not character.Parent or not humanoid or humanoid.Health <= 0 or character:GetAttribute("IsRagdolled") then
    for _, joint in state.motors do if joint.Parent then joint.Transform = CFrame.identity end end
    states[character] = nil
    continue
   end
   if character:GetAttribute("IsStunned") and state.name ~= "Hitstun" and not state.stopping then stop(character, nil, 0.08) end
   state.elapsed += dt * state.speed
   local sequence = Sequences[state.name]
   if not state.stopping then
    -- Consume completed segments without frame-rate-dependent timing drift.
    while state.elapsed >= sequence.Keyframes[state.index].Duration do
     local frame = sequence.Keyframes[state.index]
     state.elapsed -= frame.Duration
     for jointName in state.motors do state.from[jointName] = frame.Pose[jointName] or CFrame.identity end
     state.index += 1
     if state.index > #sequence.Keyframes then
      if sequence.Loop then state.index = 1 else state.stopping = true state.elapsed = 0 break end
     end
     if state.onStep then state.onStep(state.index) end
    end
   end
   local frame = sequence.Keyframes[math.min(state.index, #sequence.Keyframes)]
   local duration = if state.stopping then state.fade else frame.Duration
   local alpha = TweenService:GetValue(math.clamp(state.elapsed / duration, 0, 1), if state.stopping then Enum.EasingStyle.Sine else frame.EasingStyle or Enum.EasingStyle.Sine, frame.EasingDirection or Enum.EasingDirection.InOut)
   for name, joint in state.motors do
    local target = if state.stopping then CFrame.identity else frame.Pose[name] or CFrame.identity
    state.pose[name] = (state.from[name] or CFrame.identity):Lerp(target, alpha)
    if joint.Parent then joint.Transform = state.pose[name] end
   end
   if state.stopping and state.elapsed >= state.fade then
    states[character] = nil
    if state.onComplete then state.onComplete() end
   end
  end
 end)
 remote.OnClientEvent:Connect(function(action: string, character: Model, name: string, value: number?)
  if not character or not character:IsA("Model") then return end
  if action == "Play" then
   if character == Players.LocalPlayer.Character and AnimationManager.IsPlaying(character, name) then return end
   begin(character, name, value)
  elseif action == "Stop" then stop(character, name, value)
  elseif action == "StopAll" then stop(character, nil, value) end
 end)
end
function AnimationManager.RegisterAnimation(name: string, assetId: string) assets[name] = assetId end
function AnimationManager.PlayProceduralSequence(character: Model, name: string, onStep: ((number) -> ())?, onComplete: (() -> ())?)
 if RunService:IsServer() then remote:FireAllClients("Play", character, name, 1) else begin(character, name, 1, onStep, onComplete) end
end
function AnimationManager.CreateProceduralPose(character: Model, pose: Pose, duration: number?, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
 local name = "CustomPose"
 Sequences[name] = { Loop = false, Keyframes = { { Pose = pose, Duration = duration or 0.15, EasingStyle = style, EasingDirection = direction } } }
 begin(character, name)
end
function AnimationManager.PlayAnimation(character: Model, name: string, fade: number?, speed: number?, weight: number?): (AnimationTrack?, boolean)
 if RunService:IsServer() then remote:FireAllClients("Play", character, name, speed or 1) return nil, false end
 local humanoid = character:FindFirstChildOfClass("Humanoid")
 if not humanoid then return nil, false end
 local asset = assets[name]
 if asset and asset ~= "" and asset ~= "rbxassetid://0" then
  local animator = humanoid:FindFirstChildOfClass("Animator")
  if animator then
   local animation = Instance.new("Animation")
   animation.AnimationId = asset
   local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
   animation:Destroy()
   if ok then
    stop(character)
    tracks[character] = tracks[character] or {}
    if tracks[character][name] then tracks[character][name]:Destroy() end
    tracks[character][name] = track
    track.Priority = Enum.AnimationPriority.Action4
    track:Play(fade or 0.1, weight or 1, speed or 1)
    return track, true
   end
  end
 end
 begin(character, name, speed)
 return nil, false
end
function AnimationManager.StopAnimation(character: Model, name: string, fade: number?)
 if RunService:IsServer() then remote:FireAllClients("Stop", character, name, fade) return end
 if tracks[character] and tracks[character][name] then tracks[character][name]:Stop(fade or 0.12) end
 stop(character, name, fade)
end
function AnimationManager.StopAllAnimations(character: Model, fade: number?)
 if RunService:IsServer() then remote:FireAllClients("StopAll", character, "", fade) return end
 if tracks[character] then
  for _, track in tracks[character] do track:Stop(fade or 0.12) track:Destroy() end
  tracks[character] = nil
 end
 stop(character, nil, fade)
end
function AnimationManager.IsPlaying(character: Model, name: string): boolean
 local state = states[character]
 return (state ~= nil and state.name == name and not state.stopping) or (tracks[character] ~= nil and tracks[character][name] ~= nil and tracks[character][name].IsPlaying)
end
Players.PlayerRemoving:Connect(function(player)
 if player.Character then states[player.Character] = nil tracks[player.Character] = nil end
end)
return AnimationManager
