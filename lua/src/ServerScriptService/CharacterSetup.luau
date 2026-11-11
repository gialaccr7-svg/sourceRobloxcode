--!strict
-- CharacterSetup.luau
-- Authoritative Server-side Goku Character & Appearance Manager
-- Ensures every player spawns as Goku with:
-- 1. Standard R15 rig (16 parts, 15 Motor6D joints, canonical attachment points).
-- 2. Goku's iconic Turtle School Gi (Orange gi, blue undershirt, blue belt/sash, blue wristbands, dark blue boots with red laces).
-- 3. Spiky Goku hair (UGC accessory mesh + 3D spiky hair geometry).
-- 4. Goku anime face decal and Humanoid properties.
-- 5. Seamless compatibility with RagdollHelper, AnimationManager, and Super Saiyan Awakening transformation.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Locate GokuCharacter builder module safely
local GokuCharacter: any = nil

local function getGokuCharacterModule()
	-- Try StarterPlayer.StarterCharacter.GokuCharacter
	local sp = StarterPlayer:FindFirstChild("StarterCharacter")
	if not sp then
		sp = StarterPlayer:WaitForChild("StarterCharacter", 2)
	end
	if sp then
		local mod = sp:FindFirstChild("GokuCharacter")
		if mod and mod:IsA("ModuleScript") then
			local success, res = pcall(require, mod)
			if success and res then
				return res
			end
		end

		local initMod = sp:FindFirstChild("init")
		if initMod and initMod:IsA("ModuleScript") then
			local success, res = pcall(require, initMod)
			if success and res then
				return res
			end
		end

		if sp:IsA("ModuleScript") then
			local success, res = pcall(require, sp)
			if success and res then
				return res
			end
		end
	end

	-- Try ReplicatedStorage or other locations
	local rs = ReplicatedStorage:FindFirstChild("GokuCharacter")
	if rs and rs:IsA("ModuleScript") then
		local success, res = pcall(require, rs)
		if success and res then
			return res
		end
	end

	return nil
end

local function getGokuCharacter(): any
	if GokuCharacter then
		return GokuCharacter
	end
	GokuCharacter = getGokuCharacterModule()
	return GokuCharacter
end

GokuCharacter = getGokuCharacterModule()

-- Safely require RagdollHelper for ragdoll constraint initialization
local function getRagdollHelper()
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	if modules then
		local rh = modules:FindFirstChild("RagdollHelper")
		if rh and rh:IsA("ModuleScript") then
			local success, res = pcall(require, rh)
			if success then
				return res
			end
		end
	end
	return nil
end

local RagdollHelper = getRagdollHelper()

local CharacterSetup = {}

-- Applies Goku's complete appearance and setup to a given character model
function CharacterSetup.SetupGoku(character: Model)
	if not character or not character.Parent then
		return
	end

	if character:GetAttribute("GokuSetupCompleted") == true then
		return
	end
	character:SetAttribute("GokuSetupCompleted", true)

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?

	if not humanoid or not hrp then
		warn("[CharacterSetup] Character missing Humanoid or HumanoidRootPart.")
		return
	end

	-- Ensure Goku appearance is applied
	local goku = getGokuCharacter()
	if goku and goku.ApplyGokuAppearance then
		goku.ApplyGokuAppearance(character)
	else
		-- Fallback direct appearance setup if module not loaded
		humanoid.DisplayName = "Goku"
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.MaxHealth = 100.0
		humanoid.Health = 100.0
		humanoid.WalkSpeed = 16.0
		humanoid.HipHeight = 2.0

		-- BodyColors
		local bodyColors = character:FindFirstChildOfClass("BodyColors")
		if not bodyColors then
			bodyColors = Instance.new("BodyColors")
			bodyColors.Parent = character
		end
		bodyColors.HeadColor3 = Color3.fromRGB(255, 218, 185)
		bodyColors.LeftArmColor3 = Color3.fromRGB(255, 218, 185)
		bodyColors.RightArmColor3 = Color3.fromRGB(255, 218, 185)
		bodyColors.TorsoColor3 = Color3.fromRGB(235, 100, 20)
		bodyColors.LeftLegColor3 = Color3.fromRGB(235, 100, 20)
		bodyColors.RightLegColor3 = Color3.fromRGB(235, 100, 20)

		-- Shirt
		local shirt = character:FindFirstChildOfClass("Shirt")
		if not shirt then
			shirt = Instance.new("Shirt")
			shirt.Name = "GokuGiShirt"
			shirt.Parent = character
		end
		shirt.ShirtTemplate = "rbxassetid://144076326"

		-- Pants
		local pants = character:FindFirstChildOfClass("Pants")
		if not pants then
			pants = Instance.new("Pants")
			pants.Name = "GokuGiPants"
			pants.Parent = character
		end
		pants.PantsTemplate = "rbxassetid://144076760"

		-- Face
		local head = character:FindFirstChild("Head") :: BasePart?
		if head then
			local face = head:FindFirstChild("face") :: Decal?
			if not face then
				face = Instance.new("Decal")
				face.Name = "face"
				face.Face = Enum.NormalId.Front
				face.Parent = head
			end
			face.Texture = "rbxassetid://221085025"
		end
	end

	-- Pre-initialize ragdoll constraints for physics stability
	if RagdollHelper and RagdollHelper.SetupRig then
		pcall(function()
			RagdollHelper.SetupRig(character)
		end)
	end

	-- Configure default combat attributes
	character:SetAttribute("CharacterName", "Goku")
	character:SetAttribute("Rage", 0)
	character:SetAttribute("IsBlocking", false)
	character:SetAttribute("IsStunned", false)
	character:SetAttribute("IsRagdolled", false)
	character:SetAttribute("iFrames", false)
	character:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)

	-- Listen for Super Saiyan Awakening transformation state
	local attrConn: RBXScriptConnection? = nil
	attrConn = character:GetAttributeChangedSignal("IsAwakened"):Connect(function()
		local isAwakened = character:GetAttribute("IsAwakened") == true
		local goku = getGokuCharacter()
		if goku and goku.TransformSuperSaiyan then
			goku.TransformSuperSaiyan(character, isAwakened)
		end
	end)

	character.Destroying:Connect(function()
		if attrConn then
			attrConn:Disconnect()
			attrConn = nil
		end
	end)

	print(string.format("[CharacterSetup] Successfully configured Goku character for %s", character.Name))
end

-- Constructs the authoritative Goku R15 character model
function CharacterSetup.BuildGokuRig(): Model
	local goku = getGokuCharacter()
	if goku and goku.BuildGokuModel then
		return goku.BuildGokuModel()
	end
	error("[CharacterSetup] GokuCharacter module is not available to build rig.")
end

-- Validates that an R15 character rig has all 16 parts and 15 Motor6D joints
function CharacterSetup.ValidateRig(character: Model): (boolean, { string })
	local goku = getGokuCharacter()
	if goku and goku.ValidateRig then
		return goku.ValidateRig(character)
	end

	local missing: { string } = {}
	local requiredLimbs = {
		"HumanoidRootPart", "LowerTorso", "UpperTorso", "Head",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot",
	}
	for _, limb in ipairs(requiredLimbs) do
		if not character:FindFirstChild(limb) then
			table.insert(missing, "Part:" .. limb)
		end
	end
	return #missing == 0, missing
end

-- Ensures StarterPlayer has an authentic Goku StarterCharacter Model
function CharacterSetup.EnsureStarterCharacter()
	local goku = getGokuCharacter()
	local existingStarterChar = StarterPlayer:FindFirstChild("StarterCharacter")
	if existingStarterChar and not existingStarterChar:IsA("Model") then
		if goku and goku.BuildGokuModel then
			local success, model = pcall(function()
				return goku.BuildGokuModel()
			end)
			if success and model then
				for _, child in ipairs(existingStarterChar:GetChildren()) do
					if child:IsA("ModuleScript") and not model:FindFirstChild(child.Name) then
						child.Parent = model
					end
				end
				existingStarterChar:Destroy()
				model.Name = "StarterCharacter"
				model.Parent = StarterPlayer
				print("[CharacterSetup] Replaced StarterCharacter Folder with authentic Goku R15 Model")
			end
		end
	elseif not existingStarterChar then
		if goku and goku.BuildGokuModel then
			local success, model = pcall(function()
				return goku.BuildGokuModel()
			end)
			if success and model then
				model.Name = "StarterCharacter"
				model.Parent = StarterPlayer
				print("[CharacterSetup] Instantiated authentic Goku R15 Model as StarterPlayer.StarterCharacter")
			end
		end
	end
end

-- Checks if character is not a Model or lacks Humanoid, and auto-recovers by building Goku R15
function CharacterSetup.RepairBrokenCharacter(player: Player, character: Instance?): Model?
	local isBroken = false
	if not character or not character:IsA("Model") then
		isBroken = true
	else
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			humanoid = character:WaitForChild("Humanoid", 1) :: Humanoid?
			if not humanoid then
				isBroken = true
			end
		end
	end

	if isBroken then
		warn(string.format("[CharacterSetup] Detected broken character (Folder or missing Humanoid) for player %s. Auto-recovering Goku R15 Model...", player.Name))

		local goku = getGokuCharacter()
		local newModel: Model? = nil
		if goku and goku.BuildGokuModel then
			local success, res = pcall(goku.BuildGokuModel)
			if success and res and res:IsA("Model") then
				newModel = res
			else
				warn("[CharacterSetup] Error invoking GokuCharacter.BuildGokuModel: " .. tostring(res))
			end
		end

		if newModel then
			if character and character.Parent and character ~= newModel then
				pcall(function()
					character:Destroy()
				end)
			end

			newModel.Name = player.Name
			newModel.Parent = workspace
			player.Character = newModel
			CharacterSetup.SetupGoku(newModel)
			return newModel
		else
			warn(string.format("[CharacterSetup] Failed to auto-recover Goku Model for player %s", player.Name))
		end
	end

	return if character and character:IsA("Model") then character else nil
end

-- Initializes player lifecycle hooks
local initialized = false
function CharacterSetup.Init()
	if initialized then
		return
	end
	initialized = true

	-- Ensure StarterPlayer has the StarterCharacter template
	CharacterSetup.EnsureStarterCharacter()

	-- Hook Player spawning
	local function onPlayerAdded(player: Player)
		if player.Character then
			task.spawn(function()
				local repaired = CharacterSetup.RepairBrokenCharacter(player, player.Character)
				if repaired then
					CharacterSetup.SetupGoku(repaired)
				end
			end)
		end
		player.CharacterAdded:Connect(function(char)
			local repaired = CharacterSetup.RepairBrokenCharacter(player, char)
			if repaired then
				CharacterSetup.SetupGoku(repaired)
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	print("[CharacterSetup] Authoritative Goku Character & Appearance system initialized.")
end

-- Auto-initialize on server load
CharacterSetup.Init()

return CharacterSetup
