--!strict
-- GokuCharacter.luau
-- Authentic Goku R15 Character Rig & Appearance Specification
-- Provides 100% compliant R15 model construction with:
-- 1. 16 Standard R15 Parts with exact canonical sizes & materials.
-- 2. 15 Standard Motor6D Joints with exact C0/C1 spatial matrices.
-- 3. Standard R15 Attachments for all accessories, hair, tools, and effects.
-- 4. Iconic Turtle School Gi (Orange gi, dark blue undershirt, blue sash belt, blue wristbands, dark blue boots with red laces).
-- 5. Spiky black Goku hair accessory (UGC mesh + procedural 3D spiky hair silhouette).
-- 6. Anime Goku face decal and Humanoid configuration.
-- 7. Super Saiyan Awakening transformation visual state handler.

local GokuCharacter = {}

-- Asset IDs & Visual Configuration
GokuCharacter.Config = {
	-- Classic Goku Gi Shirt & Pants Asset IDs
	ShirtAssetId = "rbxassetid://144076326",
	ShirtFallbackIds = {
		"rbxassetid://6145560225",
		"rbxassetid://398633812",
		"rbxassetid://125079982446823",
	},
	PantsAssetId = "rbxassetid://144076760",
	PantsFallbackIds = {
		"rbxassetid://398634177",
		"rbxassetid://607706385",
	},

	-- Face & Hair Asset IDs
	FaceDecalId = "rbxassetid://221085025",
	FaceFallbackIds = {
		"rbxassetid://144075659",
		"rbxassetid://405232675",
	},
	GokuHairMeshId = "rbxassetid://17893462157",
	GokuHairTextureId = "rbxassetid://17893462200",
	SuperSaiyanHairMeshId = "rbxassetid://17334220453",

	-- Color Palette
	SkinColor = Color3.fromRGB(255, 218, 185), -- Peach anime flesh tone
	GiOrangeColor = Color3.fromRGB(235, 100, 20), -- Vibrant Turtle School gi orange
	GiBlueNavyColor = Color3.fromRGB(20, 35, 95), -- Martial arts undershirt/belt/wristband dark blue
	BootRedColor = Color3.fromRGB(210, 35, 35), -- Boot lace red piping
	HairBlackColor = Color3.fromRGB(15, 15, 20), -- Base Saiyan raven black
	SuperSaiyanHairColor = Color3.fromRGB(255, 225, 45), -- Super Saiyan golden aura
	SuperSaiyanAuraColor = Color3.fromRGB(255, 240, 80),

	-- Humanoid Configuration
	DisplayName = "Goku",
	MaxHealth = 100.0,
	Health = 100.0,
	WalkSpeed = 16.0,
	JumpPower = 50.0,
	HipHeight = 2.0,
}

-- Standard R15 Part Specifications (16 Parts)
local PartSpecs = {
	{ Name = "HumanoidRootPart", Size = Vector3.new(2, 2, 1), Transparency = 1, CanCollide = false },
	{ Name = "LowerTorso", Size = Vector3.new(1.8, 0.8, 1), Transparency = 0, CanCollide = false },
	{ Name = "UpperTorso", Size = Vector3.new(2, 1.6, 1), Transparency = 0, CanCollide = false },
	{ Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), Transparency = 0, CanCollide = true },
	{ Name = "LeftUpperArm", Size = Vector3.new(0.8, 1.17, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "LeftLowerArm", Size = Vector3.new(0.8, 1.05, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "LeftHand", Size = Vector3.new(0.8, 0.53, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "RightUpperArm", Size = Vector3.new(0.8, 1.17, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "RightLowerArm", Size = Vector3.new(0.8, 1.05, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "RightHand", Size = Vector3.new(0.8, 0.53, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "LeftUpperLeg", Size = Vector3.new(0.8, 1.14, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "LeftLowerLeg", Size = Vector3.new(0.8, 1.19, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "LeftFoot", Size = Vector3.new(0.8, 0.44, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "RightUpperLeg", Size = Vector3.new(0.8, 1.14, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "RightLowerLeg", Size = Vector3.new(0.8, 1.19, 0.8), Transparency = 0, CanCollide = false },
	{ Name = "RightFoot", Size = Vector3.new(0.8, 0.44, 0.8), Transparency = 0, CanCollide = false },
}

-- Standard R15 Motor6D Joint Specifications (15 Joints)
local JointSpecs = {
	{
		Name = "Root",
		Part0 = "HumanoidRootPart",
		Part1 = "LowerTorso",
		C0 = CFrame.new(0, 0, 0),
		C1 = CFrame.new(0, 0, 0),
	},
	{
		Name = "Waist",
		Part0 = "LowerTorso",
		Part1 = "UpperTorso",
		C0 = CFrame.new(0, 0.78, 0),
		C1 = CFrame.new(0, -0.78, 0),
	},
	{
		Name = "Neck",
		Part0 = "UpperTorso",
		Part1 = "Head",
		C0 = CFrame.new(0, 0.8, 0),
		C1 = CFrame.new(0, -0.6, 0),
	},
	{
		Name = "LeftShoulder",
		Part0 = "UpperTorso",
		Part1 = "LeftUpperArm",
		C0 = CFrame.new(-1.25, 0.5, 0),
		C1 = CFrame.new(0.25, 0.5, 0),
	},
	{
		Name = "RightShoulder",
		Part0 = "UpperTorso",
		Part1 = "RightUpperArm",
		C0 = CFrame.new(1.25, 0.5, 0),
		C1 = CFrame.new(-0.25, 0.5, 0),
	},
	{
		Name = "LeftElbow",
		Part0 = "LeftUpperArm",
		Part1 = "LeftLowerArm",
		C0 = CFrame.new(0, -0.585, 0),
		C1 = CFrame.new(0, 0.525, 0),
	},
	{
		Name = "RightElbow",
		Part0 = "RightUpperArm",
		Part1 = "RightLowerArm",
		C0 = CFrame.new(0, -0.585, 0),
		C1 = CFrame.new(0, 0.525, 0),
	},
	{
		Name = "LeftWrist",
		Part0 = "LeftLowerArm",
		Part1 = "LeftHand",
		C0 = CFrame.new(0, -0.525, 0),
		C1 = CFrame.new(0, 0.265, 0),
	},
	{
		Name = "RightWrist",
		Part0 = "RightLowerArm",
		Part1 = "RightHand",
		C0 = CFrame.new(0, -0.525, 0),
		C1 = CFrame.new(0, 0.265, 0),
	},
	{
		Name = "LeftHip",
		Part0 = "LowerTorso",
		Part1 = "LeftUpperLeg",
		C0 = CFrame.new(-0.5, -0.4, 0),
		C1 = CFrame.new(0, 0.57, 0),
	},
	{
		Name = "RightHip",
		Part0 = "LowerTorso",
		Part1 = "RightUpperLeg",
		C0 = CFrame.new(0.5, -0.4, 0),
		C1 = CFrame.new(0, 0.57, 0),
	},
	{
		Name = "LeftKnee",
		Part0 = "LeftUpperLeg",
		Part1 = "LeftLowerLeg",
		C0 = CFrame.new(0, -0.57, 0),
		C1 = CFrame.new(0, 0.595, 0),
	},
	{
		Name = "RightKnee",
		Part0 = "RightUpperLeg",
		Part1 = "RightLowerLeg",
		C0 = CFrame.new(0, -0.57, 0),
		C1 = CFrame.new(0, 0.595, 0),
	},
	{
		Name = "LeftAnkle",
		Part0 = "LeftLowerLeg",
		Part1 = "LeftFoot",
		C0 = CFrame.new(0, -0.595, 0),
		C1 = CFrame.new(0, 0.22, 0),
	},
	{
		Name = "RightAnkle",
		Part0 = "RightLowerLeg",
		Part1 = "RightFoot",
		C0 = CFrame.new(0, -0.595, 0),
		C1 = CFrame.new(0, 0.22, 0),
	},
}

-- Standard R15 Attachment Specifications
local AttachmentSpecs: { [string]: { { Name: string, CFrame: CFrame } } } = {
	["Head"] = {
		{ Name = "HairAttachment", CFrame = CFrame.new(0, 0.6, 0) },
		{ Name = "HatAttachment", CFrame = CFrame.new(0, 0.6, 0) },
		{ Name = "FaceCenterAttachment", CFrame = CFrame.new(0, 0, 0) },
		{ Name = "FaceFrontAttachment", CFrame = CFrame.new(0, 0, -0.6) },
	},
	["UpperTorso"] = {
		{ Name = "NeckAttachment", CFrame = CFrame.new(0, 0.8, 0) },
		{ Name = "BodyFrontAttachment", CFrame = CFrame.new(0, 0, -0.5) },
		{ Name = "BodyBackAttachment", CFrame = CFrame.new(0, 0, 0.5) },
		{ Name = "LeftCollarAttachment", CFrame = CFrame.new(-1, 0.6, 0) },
		{ Name = "RightCollarAttachment", CFrame = CFrame.new(1, 0.6, 0) },
		{ Name = "WaistCenterAttachment", CFrame = CFrame.new(0, -0.8, 0) },
	},
	["LowerTorso"] = {
		{ Name = "WaistCenterAttachment", CFrame = CFrame.new(0, 0.4, 0) },
		{ Name = "RootRigAttachment", CFrame = CFrame.new(0, 0, 0) },
	},
	["LeftUpperArm"] = {
		{ Name = "LeftShoulderAttachment", CFrame = CFrame.new(0, 0.585, 0) },
	},
	["LeftLowerArm"] = {
		{ Name = "LeftElbowAttachment", CFrame = CFrame.new(0, 0.525, 0) },
	},
	["LeftHand"] = {
		{ Name = "LeftGripAttachment", CFrame = CFrame.new(0, -0.265, 0) },
		{ Name = "LeftWristAttachment", CFrame = CFrame.new(0, 0.265, 0) },
	},
	["RightUpperArm"] = {
		{ Name = "RightShoulderAttachment", CFrame = CFrame.new(0, 0.585, 0) },
	},
	["RightLowerArm"] = {
		{ Name = "RightElbowAttachment", CFrame = CFrame.new(0, 0.525, 0) },
	},
	["RightHand"] = {
		{ Name = "RightGripAttachment", CFrame = CFrame.new(0, -0.265, 0) },
		{ Name = "RightWristAttachment", CFrame = CFrame.new(0, 0.265, 0) },
	},
	["LeftUpperLeg"] = {
		{ Name = "LeftHipAttachment", CFrame = CFrame.new(0, 0.57, 0) },
	},
	["LeftLowerLeg"] = {
		{ Name = "LeftKneeAttachment", CFrame = CFrame.new(0, 0.595, 0) },
	},
	["LeftFoot"] = {
		{ Name = "LeftAnkleAttachment", CFrame = CFrame.new(0, 0.22, 0) },
	},
	["RightUpperLeg"] = {
		{ Name = "RightHipAttachment", CFrame = CFrame.new(0, 0.57, 0) },
	},
	["RightLowerLeg"] = {
		{ Name = "RightKneeAttachment", CFrame = CFrame.new(0, 0.595, 0) },
	},
	["RightFoot"] = {
		{ Name = "RightAnkleAttachment", CFrame = CFrame.new(0, 0.22, 0) },
	},
	["HumanoidRootPart"] = {
		{ Name = "RootAttachment", CFrame = CFrame.new(0, 0, 0) },
	},
}

-- Creates a standard R15 part
local function createPart(name: string, size: Vector3, transparency: number, canCollide: boolean): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Transparency = transparency
	part.CanCollide = canCollide
	part.CastShadow = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	-- Special head mesh
	if name == "Head" then
		local mesh = Instance.new("SpecialMesh")
		mesh.Name = "Mesh"
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		mesh.Parent = part
	end

	return part
end

-- Builds authentic procedural 3D Spiky Goku Hair with iconic silhouettes
local function buildProceduralSpikyHair(parentHandle: BasePart): Folder
	local hairFolder = Instance.new("Folder")
	hairFolder.Name = "SpikyHairMeshHierarchy"
	hairFolder.Parent = parentHandle

	-- Hair Spike Specifications: (Position relative to head top, Rotation angles, Size)
	-- Iconic Goku hair consists of 7 major sweeping spikes + 4 forehead bangs:
	local hairSpikeData = {
		-- 1. Center Crown Spike (tallest, angling backward & upward)
		{ Offset = Vector3.new(0, 0.75, 0.15), Angles = Vector3.new(22, 0, 0), Size = Vector3.new(0.65, 1.35, 0.65) },
		-- 2. Left Crest Spike (sweeping up and left)
		{ Offset = Vector3.new(-0.55, 0.65, 0.05), Angles = Vector3.new(15, 0, 32), Size = Vector3.new(0.55, 1.15, 0.55) },
		-- 3. Left Major Sweep Spike (wide outward lateral flare)
		{ Offset = Vector3.new(-0.85, 0.35, -0.10), Angles = Vector3.new(5, -10, 48), Size = Vector3.new(0.58, 1.25, 0.58) },
		-- 4. Left Low Flare Spike
		{ Offset = Vector3.new(-0.70, -0.05, -0.20), Angles = Vector3.new(-10, -15, 55), Size = Vector3.new(0.50, 1.05, 0.50) },
		-- 5. Right Crest Spike (sweeping up and right)
		{ Offset = Vector3.new(0.55, 0.65, 0.05), Angles = Vector3.new(15, 0, -32), Size = Vector3.new(0.55, 1.15, 0.55) },
		-- 6. Right Major Sweep Spike (wide outward lateral flare)
		{ Offset = Vector3.new(0.85, 0.35, -0.10), Angles = Vector3.new(5, 10, -48), Size = Vector3.new(0.58, 1.25, 0.58) },
		-- 7. Right Low Flare Spike
		{ Offset = Vector3.new(0.70, -0.05, -0.20), Angles = Vector3.new(-10, 15, -55), Size = Vector3.new(0.50, 1.05, 0.50) },
		-- Forehead Bang 1 (Center-left diagonal point)
		{ Offset = Vector3.new(-0.22, 0.35, -0.62), Angles = Vector3.new(-35, 12, -18), Size = Vector3.new(0.32, 0.72, 0.32) },
		-- Forehead Bang 2 (Center-right point)
		{ Offset = Vector3.new(0.20, 0.32, -0.60), Angles = Vector3.new(-38, -10, 15), Size = Vector3.new(0.30, 0.68, 0.30) },
		-- Forehead Bang 3 (Left side tuft)
		{ Offset = Vector3.new(-0.48, 0.22, -0.55), Angles = Vector3.new(-25, 20, 25), Size = Vector3.new(0.28, 0.62, 0.28) },
		-- Forehead Bang 4 (Right side tuft)
		{ Offset = Vector3.new(0.48, 0.22, -0.55), Angles = Vector3.new(-25, -20, -25), Size = Vector3.new(0.28, 0.62, 0.28) },
		-- Back Skull Volume Cap
		{ Offset = Vector3.new(0, 0.25, 0.40), Angles = Vector3.new(20, 0, 0), Size = Vector3.new(1.15, 1.05, 0.85) },
	}

	for i, data in ipairs(hairSpikeData) do
		local spike = Instance.new("WedgePart")
		spike.Name = "GokuSpike_" .. tostring(i)
		spike.Size = data.Size
		spike.Color = GokuCharacter.Config.HairBlackColor
		spike.Material = Enum.Material.SmoothPlastic
		spike.CanCollide = false
		spike.CastShadow = true
		spike.Massless = true

		-- Align and Weld to parent Handle
		local cframeOffset = CFrame.new(data.Offset)
			* CFrame.Angles(math.rad(data.Angles.X), math.rad(data.Angles.Y), math.rad(data.Angles.Z))
		spike.CFrame = parentHandle.CFrame * cframeOffset

		local weld = Instance.new("WeldConstraint")
		weld.Name = "SpikeWeld_" .. tostring(i)
		weld.Part0 = parentHandle
		weld.Part1 = spike
		weld.Parent = spike

		spike.Parent = hairFolder
	end

	return hairFolder
end

-- Builds the Goku Spiky Hair Accessory
function GokuCharacter.CreateHairAccessory(): Accessory
	local accessory = Instance.new("Accessory")
	accessory.Name = "GokuHair"
	accessory.AccessoryType = Enum.AccessoryType.Hair

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.2, 1.2, 1.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = accessory

	local hairAttachment = Instance.new("Attachment")
	hairAttachment.Name = "HairAttachment"
	hairAttachment.CFrame = CFrame.new(0, 0.6, 0)
	hairAttachment.Parent = handle

	-- Online UGC Goku Hair SpecialMesh
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "GokuHairMesh"
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = GokuCharacter.Config.GokuHairMeshId
	mesh.TextureId = GokuCharacter.Config.GokuHairTextureId
	mesh.Scale = Vector3.new(1.05, 1.05, 1.05)
	mesh.Parent = handle

	-- Procedural 3D Hair Structure fallback (active offline & guarantees spiky hair geometry)
	buildProceduralSpikyHair(handle)

	return accessory
end

-- Builds 3D Martial Arts Gi Accents (Belt/Sash, Wristbands, Boot Accents)
function GokuCharacter.ApplyGiPhysicalAccents(character: Model)
	local upperTorso = character:FindFirstChild("UpperTorso") :: BasePart?
	local lowerTorso = character:FindFirstChild("LowerTorso") :: BasePart?
	local leftHand = character:FindFirstChild("LeftHand") :: BasePart?
	local rightHand = character:FindFirstChild("RightHand") :: BasePart?
	local leftFoot = character:FindFirstChild("LeftFoot") :: BasePart?
	local rightFoot = character:FindFirstChild("RightFoot") :: BasePart?

	-- Remove old accents if re-applying
	local existingAccents = character:FindFirstChild("GokuGiAccents")
	if existingAccents then
		existingAccents:Destroy()
	end

	local accentsFolder = Instance.new("Folder")
	accentsFolder.Name = "GokuGiAccents"
	accentsFolder.Parent = character

	-- 1. Dark Blue Sash Belt around Waist
	if lowerTorso then
		local belt = Instance.new("Part")
		belt.Name = "GokuSashBelt"
		belt.Size = Vector3.new(1.9, 0.35, 1.08)
		belt.Color = GokuCharacter.Config.GiBlueNavyColor
		belt.Material = Enum.Material.SmoothPlastic
		belt.CanCollide = false
		belt.Massless = true
		belt.CFrame = lowerTorso.CFrame * CFrame.new(0, 0.25, 0)

		local beltWeld = Instance.new("WeldConstraint")
		beltWeld.Part0 = lowerTorso
		beltWeld.Part1 = belt
		beltWeld.Parent = belt
		belt.Parent = accentsFolder

		-- Hanging Sash Knot on left hip
		local sashKnot = Instance.new("Part")
		sashKnot.Name = "GokuSashKnot"
		sashKnot.Size = Vector3.new(0.3, 0.65, 0.25)
		sashKnot.Color = GokuCharacter.Config.GiBlueNavyColor
		sashKnot.Material = Enum.Material.SmoothPlastic
		sashKnot.CanCollide = false
		sashKnot.Massless = true
		sashKnot.CFrame = lowerTorso.CFrame * CFrame.new(-0.85, -0.15, -0.45) * CFrame.Angles(0, 0, math.rad(15))

		local knotWeld = Instance.new("WeldConstraint")
		knotWeld.Part0 = lowerTorso
		knotWeld.Part1 = sashKnot
		knotWeld.Parent = sashKnot
		sashKnot.Parent = accentsFolder
	end

	-- 2. Blue Wristbands on Left and Right Hands/Wrists
	if leftHand then
		local wristbandL = Instance.new("Part")
		wristbandL.Name = "WristbandLeft"
		wristbandL.Size = Vector3.new(0.85, 0.30, 0.85)
		wristbandL.Color = GokuCharacter.Config.GiBlueNavyColor
		wristbandL.Material = Enum.Material.SmoothPlastic
		wristbandL.CanCollide = false
		wristbandL.Massless = true
		wristbandL.CFrame = leftHand.CFrame * CFrame.new(0, 0.15, 0)

		local weldL = Instance.new("WeldConstraint")
		weldL.Part0 = leftHand
		weldL.Part1 = wristbandL
		weldL.Parent = wristbandL
		wristbandL.Parent = accentsFolder
	end

	if rightHand then
		local wristbandR = Instance.new("Part")
		wristbandR.Name = "WristbandRight"
		wristbandR.Size = Vector3.new(0.85, 0.30, 0.85)
		wristbandR.Color = GokuCharacter.Config.GiBlueNavyColor
		wristbandR.Material = Enum.Material.SmoothPlastic
		wristbandR.CanCollide = false
		wristbandR.Massless = true
		wristbandR.CFrame = rightHand.CFrame * CFrame.new(0, 0.15, 0)

		local weldR = Instance.new("WeldConstraint")
		weldR.Part0 = rightHand
		weldR.Part1 = wristbandR
		weldR.Parent = wristbandR
		wristbandR.Parent = accentsFolder
	end

	-- 3. Dark Blue Boots with Red Laces Trim on Feet
	local function attachBootTrim(footPart: BasePart?, name: string)
		if not footPart then
			return
		end
		local bootTrim = Instance.new("Part")
		bootTrim.Name = name .. "_BootTrim"
		bootTrim.Size = Vector3.new(0.86, 0.42, 0.86)
		bootTrim.Color = GokuCharacter.Config.GiBlueNavyColor
		bootTrim.Material = Enum.Material.SmoothPlastic
		bootTrim.CanCollide = false
		bootTrim.Massless = true
		bootTrim.CFrame = footPart.CFrame

		local bootWeld = Instance.new("WeldConstraint")
		bootWeld.Part0 = footPart
		bootWeld.Part1 = bootTrim
		bootWeld.Parent = bootTrim
		bootTrim.Parent = accentsFolder

		-- Red vertical lace piping
		local redLace = Instance.new("Part")
		redLace.Name = name .. "_RedLace"
		redLace.Size = Vector3.new(0.12, 0.38, 0.08)
		redLace.Color = GokuCharacter.Config.BootRedColor
		redLace.Material = Enum.Material.Neon
		redLace.CanCollide = false
		redLace.Massless = true
		redLace.CFrame = footPart.CFrame * CFrame.new(0, 0.02, -0.42)

		local laceWeld = Instance.new("WeldConstraint")
		laceWeld.Part0 = footPart
		laceWeld.Part1 = redLace
		laceWeld.Parent = redLace
		redLace.Parent = accentsFolder
	end

	attachBootTrim(leftFoot, "Left")
	attachBootTrim(rightFoot, "Right")
end

-- Applies Goku's complete appearance: BodyColors, Shirt, Pants, Hair, Face, and 3D Accents
function GokuCharacter.ApplyGokuAppearance(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head") :: BasePart?

	-- 1. Configure Humanoid properties
	if humanoid then
		humanoid.DisplayName = GokuCharacter.Config.DisplayName
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
		humanoid.MaxHealth = GokuCharacter.Config.MaxHealth
		humanoid.Health = GokuCharacter.Config.Health
		humanoid.WalkSpeed = GokuCharacter.Config.WalkSpeed
		humanoid.JumpPower = GokuCharacter.Config.JumpPower
		humanoid.HipHeight = GokuCharacter.Config.HipHeight
	end

	-- 2. Configure BodyColors
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = character
	end
	bodyColors.HeadColor3 = GokuCharacter.Config.SkinColor
	bodyColors.LeftArmColor3 = GokuCharacter.Config.SkinColor
	bodyColors.RightArmColor3 = GokuCharacter.Config.SkinColor
	bodyColors.TorsoColor3 = GokuCharacter.Config.GiOrangeColor
	bodyColors.LeftLegColor3 = GokuCharacter.Config.GiOrangeColor
	bodyColors.RightLegColor3 = GokuCharacter.Config.GiOrangeColor

	-- 3. Configure Goku Turtle School Gi Shirt
	local shirt = character:FindFirstChildOfClass("Shirt")
	if not shirt then
		shirt = Instance.new("Shirt")
		shirt.Name = "GokuGiShirt"
		shirt.Parent = character
	end
	shirt.ShirtTemplate = GokuCharacter.Config.ShirtAssetId

	-- 4. Configure Goku Turtle School Gi Pants
	local pants = character:FindFirstChildOfClass("Pants")
	if not pants then
		pants = Instance.new("Pants")
		pants.Name = "GokuGiPants"
		pants.Parent = character
	end
	pants.PantsTemplate = GokuCharacter.Config.PantsAssetId

	-- 5. Configure Face Decal on Head
	if head then
		local existingFace = head:FindFirstChild("face") :: Decal?
		if not existingFace then
			existingFace = Instance.new("Decal")
			existingFace.Name = "face"
			existingFace.Face = Enum.NormalId.Front
			existingFace.Parent = head
		end
		existingFace.Texture = GokuCharacter.Config.FaceDecalId
		existingFace.Transparency = 0
	end

	-- 6. Equip Goku Spiky Hair Accessory
	local existingHair = character:FindFirstChild("GokuHair")
	if not existingHair then
		local hairAccessory = GokuCharacter.CreateHairAccessory()
		hairAccessory.Parent = character

		-- Ensure attachment weld to head
		if head then
			local headAtt = head:FindFirstChild("HairAttachment") :: Attachment?
			local handle = hairAccessory:FindFirstChild("Handle") :: BasePart?
			if headAtt and handle then
				local handleAtt = handle:FindFirstChild("HairAttachment") :: Attachment?
				if handleAtt then
					local weld = Instance.new("Weld")
					weld.Name = "AccessoryWeld"
					weld.Part0 = handle
					weld.Part1 = head
					weld.C0 = handleAtt.CFrame
					weld.C1 = headAtt.CFrame
					weld.Parent = handle
				end
			end
		end
	end

	-- 7. Apply Physical 3D Gi Accents (Belt, Wristbands, Boots)
	GokuCharacter.ApplyGiPhysicalAccents(character)

	-- 8. Apply Combat Attributes
	character:SetAttribute("CharacterName", "Goku")
	character:SetAttribute("Rage", 0)
	character:SetAttribute("IsBlocking", false)
	character:SetAttribute("IsStunned", false)
	character:SetAttribute("IsRagdolled", false)
	character:SetAttribute("iFrames", false)
	character:SetAttribute("OriginalWalkSpeed", GokuCharacter.Config.WalkSpeed)
end

-- Transforms character appearance between Base Goku and Super Saiyan (Awakening)
function GokuCharacter.TransformSuperSaiyan(character: Model, awakened: boolean)
	local hairAccessory = character:FindFirstChild("GokuHair")
	local head = character:FindFirstChild("Head") :: BasePart?
	local upperTorso = character:FindFirstChild("UpperTorso") :: BasePart?

	local targetHairColor = if awakened then GokuCharacter.Config.SuperSaiyanHairColor else GokuCharacter.Config.HairBlackColor

	if hairAccessory then
		local handle = hairAccessory:FindFirstChild("Handle") :: BasePart?
		if handle then
			-- Update procedural spikes
			local hairFolder = handle:FindFirstChild("SpikyHairMeshHierarchy")
			if hairFolder then
				for _, part in ipairs(hairFolder:GetChildren()) do
					if part:IsA("BasePart") then
						part.Color = targetHairColor
						part.Material = if awakened then Enum.Material.Neon else Enum.Material.SmoothPlastic
					end
				end
			end
		end
	end

	-- Super Saiyan Aura effect on UpperTorso
	if upperTorso then
		local auraEmitter = upperTorso:FindFirstChild("SuperSaiyanAura") :: ParticleEmitter?
		if awakened and not auraEmitter then
			auraEmitter = Instance.new("ParticleEmitter")
			auraEmitter.Name = "SuperSaiyanAura"
			auraEmitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, GokuCharacter.Config.SuperSaiyanAuraColor),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 0)),
			})
			auraEmitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.2),
				NumberSequenceKeypoint.new(0.5, 2.5),
				NumberSequenceKeypoint.new(1, 0),
			})
			auraEmitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(0.7, 0.2),
				NumberSequenceKeypoint.new(1, 1.0),
			})
			auraEmitter.LightEmission = 0.95
			auraEmitter.LightInfluence = 0
			auraEmitter.Rate = 35
			auraEmitter.Lifetime = NumberRange.new(0.35, 0.65)
			auraEmitter.Speed = NumberRange.new(5.0, 9.0)
			auraEmitter.SpreadAngle = Vector2.new(20, 20)
			auraEmitter.EmissionDirection = Enum.NormalId.Top
			auraEmitter.Parent = upperTorso
		elseif not awakened and auraEmitter then
			auraEmitter:Destroy()
		end
	end
end

-- Validates that all 15 Motor6D joints and 16 R15 parts are intact
function GokuCharacter.ValidateRig(character: Model): (boolean, { string })
	local missing: { string } = {}

	for _, spec in ipairs(PartSpecs) do
		local part = character:FindFirstChild(spec.Name)
		if not part or not part:IsA("BasePart") then
			table.insert(missing, "Part:" .. spec.Name)
		end
	end

	for _, jspec in ipairs(JointSpecs) do
		local found = false
		for _, desc in ipairs(character:GetDescendants()) do
			if desc:IsA("Motor6D") and desc.Name == jspec.Name then
				found = true
				break
			end
		end
		if not found then
			table.insert(missing, "Joint:" .. jspec.Name)
		end
	end

	return #missing == 0, missing
end

-- Constructs the complete, authoritative Goku R15 Character Model
function GokuCharacter.BuildGokuModel(): Model
	local model = Instance.new("Model")
	model.Name = "StarterCharacter"

	local createdParts: { [string]: BasePart } = {}

	-- 1. Create all 16 Parts
	for _, spec in ipairs(PartSpecs) do
		local part = createPart(spec.Name, spec.Size, spec.Transparency, spec.CanCollide)
		part.Parent = model
		createdParts[spec.Name] = part
	end

	-- Set PrimaryPart to HumanoidRootPart
	model.PrimaryPart = createdParts["HumanoidRootPart"]

	-- 2. Create all standard R15 Attachments
	for partName, attList in pairs(AttachmentSpecs) do
		local part = createdParts[partName]
		if part then
			for _, attData in ipairs(attList) do
				local att = Instance.new("Attachment")
				att.Name = attData.Name
				att.CFrame = attData.CFrame
				att.Parent = part
			end
		end
	end

	-- 3. Create all 15 Motor6D Joints
	for _, jspec in ipairs(JointSpecs) do
		local p0 = createdParts[jspec.Part0]
		local p1 = createdParts[jspec.Part1]
		if p0 and p1 then
			local motor = Instance.new("Motor6D")
			motor.Name = jspec.Name
			motor.Part0 = p0
			motor.Part1 = p1
			motor.C0 = jspec.C0
			motor.C1 = jspec.C1
			-- Motor6Ds are traditionally parented to Part1 in R15
			motor.Parent = p1
		end
	end

	-- 4. Create Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.DisplayName = GokuCharacter.Config.DisplayName
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.MaxHealth = GokuCharacter.Config.MaxHealth
	humanoid.Health = GokuCharacter.Config.Health
	humanoid.WalkSpeed = GokuCharacter.Config.WalkSpeed
	humanoid.JumpPower = GokuCharacter.Config.JumpPower
	humanoid.HipHeight = GokuCharacter.Config.HipHeight
	humanoid.Parent = model

	-- Standard R15 Scaling values inside Humanoid
	local scaleNames = {
		"BodyHeightScale", "BodyWidthScale", "BodyDepthScale",
		"HeadScale", "BodyProportionScale", "BodyTypeScale",
	}
	for _, scaleName in ipairs(scaleNames) do
		local val = Instance.new("NumberValue")
		val.Name = scaleName
		val.Value = if scaleName:find("Proportion") or scaleName:find("Type") then 0.0 else 1.0
		val.Parent = humanoid
	end

	-- 5. Apply complete Goku appearance (Skin, Shirt, Pants, Hair, Face, Accents)
	GokuCharacter.ApplyGokuAppearance(model)

	return model
end

return GokuCharacter
