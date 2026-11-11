--!strict
-- RagdollHelper.luau
-- Shared R15 Ragdoll physics management module for Core Combat & Physics
-- Configures BallSocketConstraints, joint limits, NoCollisionConstraints, and state transitions.

local Workspace = game:GetService("Workspace")

export type JointLimit = {
	UpperAngle: number,
	TwistLowerAngle: number,
	TwistUpperAngle: number,
}

local JointLimits: { [string]: JointLimit } = {
	["Neck"] = { UpperAngle = 45, TwistLowerAngle = -40, TwistUpperAngle = 40 },
	["Waist"] = { UpperAngle = 40, TwistLowerAngle = -35, TwistUpperAngle = 35 },
	["Root"] = { UpperAngle = 25, TwistLowerAngle = -20, TwistUpperAngle = 20 },
	["LeftShoulder"] = { UpperAngle = 85, TwistLowerAngle = -60, TwistUpperAngle = 60 },
	["RightShoulder"] = { UpperAngle = 85, TwistLowerAngle = -60, TwistUpperAngle = 60 },
	["LeftElbow"] = { UpperAngle = 90, TwistLowerAngle = -10, TwistUpperAngle = 10 },
	["RightElbow"] = { UpperAngle = 90, TwistLowerAngle = -10, TwistUpperAngle = 10 },
	["LeftWrist"] = { UpperAngle = 30, TwistLowerAngle = -25, TwistUpperAngle = 25 },
	["RightWrist"] = { UpperAngle = 30, TwistLowerAngle = -25, TwistUpperAngle = 25 },
	["LeftHip"] = { UpperAngle = 65, TwistLowerAngle = -35, TwistUpperAngle = 35 },
	["RightHip"] = { UpperAngle = 65, TwistLowerAngle = -35, TwistUpperAngle = 35 },
	["LeftKnee"] = { UpperAngle = 80, TwistLowerAngle = -10, TwistUpperAngle = 10 },
	["RightKnee"] = { UpperAngle = 80, TwistLowerAngle = -10, TwistUpperAngle = 10 },
	["LeftAnkle"] = { UpperAngle = 35, TwistLowerAngle = -20, TwistUpperAngle = 20 },
	["RightAnkle"] = { UpperAngle = 35, TwistLowerAngle = -20, TwistUpperAngle = 20 },
}

local RagdollHelper = {}

-- Sets up BallSocketConstraints and NoCollisionConstraints for an R15 character rig.
function RagdollHelper.SetupRig(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	local ragdollFolder = character:FindFirstChild("RagdollConstraints")
	if ragdollFolder then
		return -- Rig already configured
	end

	ragdollFolder = Instance.new("Folder")
	ragdollFolder.Name = "RagdollConstraints"
	ragdollFolder.Parent = character

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name ~= "Root" then
			local motor = descendant
			local part0 = motor.Part0
			local part1 = motor.Part1

			if part0 and part1 then
				-- Attachment 0 on Part0 matching Motor6D.C0
				local att0 = Instance.new("Attachment")
				att0.Name = "RagdollAtt0_" .. motor.Name
				att0.CFrame = motor.C0
				att0.Parent = part0

				-- Attachment 1 on Part1 matching Motor6D.C1
				local att1 = Instance.new("Attachment")
				att1.Name = "RagdollAtt1_" .. motor.Name
				att1.CFrame = motor.C1
				att1.Parent = part1

				-- BallSocketConstraint
				local socket = Instance.new("BallSocketConstraint")
				socket.Name = "Socket_" .. motor.Name
				socket.Attachment0 = att0
				socket.Attachment1 = att1
				socket.LimitsEnabled = true
				socket.TwistLimitsEnabled = true

				local limits = JointLimits[motor.Name] or { UpperAngle = 50, TwistLowerAngle = -30, TwistUpperAngle = 30 }
				socket.UpperAngle = limits.UpperAngle
				socket.TwistLowerAngle = limits.TwistLowerAngle
				socket.TwistUpperAngle = limits.TwistUpperAngle
				socket.Restitution = 0.05
				socket.Enabled = false
				socket.Parent = ragdollFolder

				-- NoCollisionConstraint between adjacent parts
				local noCollision = Instance.new("NoCollisionConstraint")
				noCollision.Name = "NoCollision_" .. part0.Name .. "_" .. part1.Name
				noCollision.Part0 = part0
				noCollision.Part1 = part1
				noCollision.Parent = ragdollFolder
			end
		end
	end
end

-- Checks if a character is currently in a ragdoll state
function RagdollHelper.IsRagdolled(character: Model): boolean
	return character:GetAttribute("IsRagdolled") == true
end

-- Activates ragdoll state on character
function RagdollHelper.Ragdoll(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	RagdollHelper.SetupRig(character)

	character:SetAttribute("IsRagdolled", true)
	character:SetAttribute("RagdollStartTime", os.clock())

	-- Humanoid state suppression to prevent standing up / walking animations
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	-- Disable Motor6Ds except Root
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name ~= "Root" then
			descendant.Enabled = false
		end
	end

	-- Enable BallSocketConstraints
	local ragdollFolder = character:FindFirstChild("RagdollConstraints")
	if ragdollFolder then
		for _, descendant in ragdollFolder:GetChildren() do
			if descendant:IsA("BallSocketConstraint") then
				descendant.Enabled = true
			end
		end
	end

	-- Adjust collision masks
	if hrp then
		hrp.CanCollide = false
	end

	local collidableParts = {
		"Head", "UpperTorso", "LowerTorso",
		"LeftUpperArm", "LeftLowerArm", "LeftHand",
		"RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
		"RightUpperLeg", "RightLowerLeg", "RightFoot",
	}

	for _, partName in collidableParts do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			part.CanCollide = true
		end
	end
end

-- Deactivates ragdoll state and restores normal character posture
function RagdollHelper.Unragdoll(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local lowerTorso = character:FindFirstChild("LowerTorso") :: BasePart?
	if not humanoid then
		return
	end

	-- Disable BallSocketConstraints
	local ragdollFolder = character:FindFirstChild("RagdollConstraints")
	if ragdollFolder then
		for _, descendant in ragdollFolder:GetChildren() do
			if descendant:IsA("BallSocketConstraint") then
				descendant.Enabled = false
			end
		end
	end

	-- Re-enable Motor6Ds
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			descendant.Enabled = true
		end
	end

	-- Reposition HumanoidRootPart upright over LowerTorso to avoid clipping into ground
	if hrp and lowerTorso then
		local groundRay = RagdollHelper.RaycastGround(character, 5)
		local groundY = lowerTorso.Position.Y + 2.0
		if groundRay then
			groundY = groundRay.Position.Y + 3.0
		end
		local currentLook = lowerTorso.CFrame.LookVector
		local flatLook = Vector3.new(currentLook.X, 0, currentLook.Z)
		if flatLook.Magnitude < 0.1 then
			flatLook = hrp.CFrame.LookVector
		else
			flatLook = flatLook.Unit
		end

		hrp.CFrame = CFrame.lookAt(Vector3.new(lowerTorso.Position.X, groundY, lowerTorso.Position.Z), Vector3.new(lowerTorso.Position.X + flatLook.X, groundY, lowerTorso.Position.Z + flatLook.Z))
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CanCollide = true
	end

	-- Restore Humanoid state
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	character:SetAttribute("IsRagdolled", false)
end

-- Raycasts down to check ground contact for recovery
function RagdollHelper.RaycastGround(character: Model, distance: number?): RaycastResult?
	local checkDist = distance or 4.0
	local refPart = character:FindFirstChild("LowerTorso") or character:FindFirstChild("HumanoidRootPart")
	if not refPart or not refPart:IsA("BasePart") then
		return nil
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true

	local origin = refPart.Position
	local direction = Vector3.new(0, -checkDist, 0)

	return Workspace:Raycast(origin, direction, raycastParams)
end

-- Checks if character is grounded
function RagdollHelper.IsGrounded(character: Model): boolean
	local hit = RagdollHelper.RaycastGround(character, 3.8)
	return hit ~= nil
end

return RagdollHelper
