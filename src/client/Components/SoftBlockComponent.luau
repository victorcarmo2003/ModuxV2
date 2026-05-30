--!strict
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Modux = require(game.ReplicatedStorage.Shared.Modux)

type SquishyBlockModel = Model & {
	default: MeshPart,
}

type SquishyBlockInstance = SquishyBlockModel | MeshPart

type VertexState = {
	Id: number,
	Origin: Vector3,
	OriginPart: Vector3,
	CurrentDepth: number,
	VerticalWeight: number,
	TopWeight: number,
}

type MeshBounds = {
	Min: Vector3,
	Max: Vector3,
	Size: Vector3,
}

local LOCAL_PLAYER = Players.LocalPlayer

local BounceState = {
	Active = false,
	QueuedVelocity = 0,
	QueuedTime = 0,
	PendingVelocity = 0,
	RunningSince = nil :: number?,
	LastSource = nil :: Instance?,
}

local function setBounceActive(active: boolean)
	BounceState.Active = active
	LOCAL_PLAYER:SetAttribute("SquishyBounceActive", active)
end

local function meshToPartLocal(meshPosition: Vector3, bounds: MeshBounds, partSize: Vector3): Vector3
	local x = ((meshPosition.X - bounds.Min.X) / bounds.Size.X) * partSize.X - partSize.X * 0.5
	local y = ((meshPosition.Y - bounds.Min.Y) / bounds.Size.Y) * partSize.Y - partSize.Y * 0.5
	local z = ((meshPosition.Z - bounds.Min.Z) / bounds.Size.Z) * partSize.Z - partSize.Z * 0.5

	return Vector3.new(x, y, z)
end

local function partDepthToMeshDepth(depth: number, bounds: MeshBounds, partSize: Vector3): number
	return depth * (bounds.Size.Y / partSize.Y)
end

local function clampInside(value: number, halfSize: number, margin: number): number
	if halfSize <= margin then
		return 0
	end

	return math.clamp(value, -halfSize + margin, halfSize - margin)
end

local SoftBlockComponent = Modux.Component("SoftBlockComponent")
	:Tag("SoftBlock")
	:ClassName("Instance")
	:AttributeDefaults({
		Radius = 50,
		MaxDepth = 5,
		FalloffPower = 2,
		TopBand = 0.18,
		SideDeformDepth = 0.45,
		SpringSpeed = 1,
		ReturnSpeed = 4,
		FootHeight = 5,
		FakeCollision = true,
		CollisionSize = 3.5,
		CollisionGrid = 3,
		CollisionThickness = 0.25,
		SurfaceSampleRadius = 1.5,
		SurfacePadding = 0.12,
		ImpactVelocity = 42,
		ImpactDepth = 0.9,
		ImpactReturnSpeed = 8,
		BounceEnabled = true,
		BounceStrength = 1,
		BounceCooldown = 0.25,
		BounceMinVelocity = 0,
		BounceMaxVelocity = 150,
		BounceReleaseSpeed = 14,
		BounceSquashRatio = 0.35,
		BounceSquashDelay = 0.1,
	})

local function getCollider(instance: Instance): MeshPart?
	if instance:IsA("MeshPart") then
		return instance
	end

	if instance:IsA("Model") then
		local default = instance:FindFirstChild("default")
		if default and default:IsA("MeshPart") then
			return default
		end
	end

	return nil
end

local function getVisualParent(instance: Instance, collider: MeshPart): Instance?
	return if instance:IsA("Model") then instance else collider.Parent
end

local function copyMeshPartProperties(from: MeshPart, to: MeshPart)
	to.Name = `{from.Name}_visual`
	to.Anchored = true
	to.CanCollide = false
	to.CanQuery = false
	to.CanTouch = false
	to.CFrame = from.CFrame
	to.Size = from.Size
	to.Color = from.Color
	to.Material = from.Material
	to.Transparency = from.Transparency
	to.Reflectance = from.Reflectance
	to.CastShadow = from.CastShadow
end

local function getCharacterParts(): (Model?, Humanoid?, BasePart?, { BasePart })
	local character = LOCAL_PLAYER.Character
	if not character then
		return nil, nil, nil, {}
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root then
		return character, humanoid, nil, {}
	end

	local feet = {}
	local leftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
	local rightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg")

	if leftFoot and leftFoot:IsA("BasePart") then
		table.insert(feet, leftFoot)
	end

	if rightFoot and rightFoot:IsA("BasePart") then
		table.insert(feet, rightFoot)
	end

	return character, humanoid, root, feet
end

local function isOverBlock(meshPart: MeshPart, root: BasePart, footHeight: number): boolean
	local localRoot = meshPart.CFrame:PointToObjectSpace(root.Position)
	local halfSize = meshPart.Size * 0.5

	return localRoot.Y >= halfSize.Y - 1
		and localRoot.Y <= halfSize.Y + footHeight
		and math.abs(localRoot.X) <= halfSize.X
		and math.abs(localRoot.Z) <= halfSize.Z
end

local function getContactPoints(meshPart: MeshPart, root: BasePart, feet: { BasePart }, footHeight: number): { Vector3 }
	if not isOverBlock(meshPart, root, footHeight) then
		return {}
	end

	local contacts = {}

	for _, foot in feet do
		table.insert(contacts, meshPart.CFrame:PointToObjectSpace(foot.Position))
	end

	if #contacts == 0 then
		local halfSize = meshPart.Size * 0.5
		local localRoot = meshPart.CFrame:PointToObjectSpace(root.Position)
		table.insert(contacts, Vector3.new(localRoot.X, halfSize.Y, localRoot.Z))
	end

	return contacts
end

local function getCurrentDepthAtPoint(point: Vector3, topVertices: { VertexState }, sampleRadius: number): number
	local weightedDepth = 0
	local totalWeight = 0
	local nearestDepth = 0
	local nearestDistance = math.huge

	for _, vertex in topVertices do
		local distanceXZ = (Vector2.new(vertex.OriginPart.X, vertex.OriginPart.Z) - Vector2.new(point.X, point.Z)).Magnitude

		if distanceXZ < nearestDistance then
			nearestDistance = distanceXZ
			nearestDepth = vertex.CurrentDepth
		end

		if distanceXZ <= sampleRadius then
			if distanceXZ < 0.001 then
				return vertex.CurrentDepth
			end

			local weight = 1 / (distanceXZ * distanceXZ)
			weightedDepth += vertex.CurrentDepth * weight
			totalWeight += weight
		end
	end

	if totalWeight > 0 then
		return weightedDepth / totalWeight
	end

	return nearestDepth
end

local function createFakeCollisionPart(collider: MeshPart, index: number): Part
	local part = Instance.new("Part")
	part.Name = `{collider.Name}_fakeCollision_{index}`
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(3.5, 0.25, 3.5)
	part.CFrame = collider.CFrame * CFrame.new(0, -collider.Size.Y * 2, 0)
	part.Parent = workspace
	return part
end

local function setFakeCollisionEnabled(parts: { Part }, enabled: boolean, hiddenCFrame: CFrame)
	for _, part in parts do
		part.CanCollide = enabled

		if not enabled then
			part.CFrame = hiddenCFrame
		end
	end
end

local function getBounceVelocity(downwardSpeed: number, springSpeed: number, returnSpeed: number, attributes: { [string]: any }): number
	if attributes.BounceEnabled ~= true then
		return 0
	end

	local minVelocity = attributes.BounceMinVelocity :: number
	if downwardSpeed < minVelocity then
		return 0
	end

	local maxVelocity = attributes.BounceMaxVelocity :: number
	local strength = attributes.BounceStrength :: number
	local response = springSpeed * 0.35 + returnSpeed * 0.65

	return math.clamp((downwardSpeed + response * 4) * strength, minVelocity, maxVelocity)
end

local function applyGradualBounce(root: BasePart, bounceVelocity: number, dt: number, releaseSpeed: number): number
	if bounceVelocity <= 0 then
		return 0
	end

	local alpha = 1 - math.exp(-releaseSpeed * dt)
	local releasedVelocity = bounceVelocity * alpha
	local currentVelocity = root.AssemblyLinearVelocity

	root.AssemblyLinearVelocity = Vector3.new(
		currentVelocity.X,
		math.max(currentVelocity.Y, currentVelocity.Y + releasedVelocity),
		currentVelocity.Z
	)

	return bounceVelocity - releasedVelocity
end

local function isRunningOnGround(humanoid: Humanoid?): boolean
	if not humanoid then
		return false
	end

	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
end

local function updateBounceState(source: Instance, humanoid: Humanoid?, root: BasePart?, dt: number, releaseSpeed: number)
	if not BounceState.Active or BounceState.LastSource ~= source then
		return
	end

	if isRunningOnGround(humanoid) then
		BounceState.RunningSince = BounceState.RunningSince or os.clock()
		BounceState.QueuedVelocity = 0
		BounceState.PendingVelocity = 0

		if os.clock() - BounceState.RunningSince >= 1 then
			setBounceActive(false)
			BounceState.RunningSince = nil
			BounceState.LastSource = nil
		end

		return
	end

	BounceState.RunningSince = nil

	if root and BounceState.PendingVelocity > 0 then
		BounceState.PendingVelocity = applyGradualBounce(root, BounceState.PendingVelocity, dt, releaseSpeed)
	end

	if BounceState.QueuedVelocity <= 0 and BounceState.PendingVelocity <= 0.05 then
		BounceState.PendingVelocity = 0
	end
end

SoftBlockComponent:OnStart(function(self)
	local instance = self.Instance :: SquishyBlockInstance
	local collider = getCollider(instance)

	if not collider then
		warn(`[SoftBlockComponent] {instance:GetFullName()} must be a MeshPart or a Model with a MeshPart named "default"`)
		return
	end

	local visualParent = getVisualParent(instance, collider)
	if not visualParent then
		return
	end

	local originalTransparency = collider.Transparency
	local originalCanCollide = collider.CanCollide

	local editableMeshSuccess, editableMeshResult = pcall(function()
		return AssetService:CreateEditableMeshAsync(collider.MeshContent, {
			FixedSize = true,
		})
	end)

	if not editableMeshSuccess or not editableMeshResult then
		warn(`[SoftBlockComponent] Could not create EditableMesh for {instance:GetFullName()}: {editableMeshResult}`)
		return
	end

	local editableMesh = editableMeshResult

	local visualSuccess, visualResult = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
		})
	end)

	if not visualSuccess then
		warn(`[SoftBlockComponent] Could not create visual MeshPart for {instance:GetFullName()}: {visualResult}`)
		editableMesh:Destroy()
		return
	end

	local visual = visualResult :: MeshPart
	copyMeshPartProperties(collider, visual)
	visual.Parent = visualParent

	local collisionGrid = math.max(math.floor(self.Attributes.CollisionGrid :: number), 1)
	local fakeCollisions = {}

	for index = 1, collisionGrid * collisionGrid do
		local fakeCollision = createFakeCollisionPart(collider, index)
		fakeCollision.Parent = visualParent
		table.insert(fakeCollisions, fakeCollision)
	end

	collider.Anchored = true
	collider.Transparency = 1
	collider.CanCollide = false

	local vertices = {}
	local topVertices = {}
	local minX = math.huge
	local maxY = -math.huge
	local minY = math.huge
	local maxX = -math.huge
	local minZ = math.huge
	local maxZ = -math.huge

	for _, vertexId in editableMesh:GetVertices() do
		local position = editableMesh:GetPosition(vertexId)
		minX = math.min(minX, position.X)
		maxX = math.max(maxX, position.X)
		maxY = math.max(maxY, position.Y)
		minY = math.min(minY, position.Y)
		minZ = math.min(minZ, position.Z)
		maxZ = math.max(maxZ, position.Z)
	end

	local bounds = {
		Min = Vector3.new(minX, minY, minZ),
		Max = Vector3.new(maxX, maxY, maxZ),
		Size = Vector3.new(math.max(maxX - minX, 0.001), math.max(maxY - minY, 0.001), math.max(maxZ - minZ, 0.001)),
	} :: MeshBounds

	local height = bounds.Size.Y
	local topBand = self.Attributes.TopBand :: number
	local sideDeformDepth = self.Attributes.SideDeformDepth :: number

	for _, vertexId in editableMesh:GetVertices() do
		local origin = editableMesh:GetPosition(vertexId)
		local originPart = meshToPartLocal(origin, bounds, collider.Size)
		local distanceFromTop = maxY - origin.Y
		local normalizedHeight = math.clamp((origin.Y - minY) / height, 0, 1)
		local topWeight = math.clamp(1 - distanceFromTop / math.max(topBand, 0.001), 0, 1)

		table.insert(vertices, {
			Id = vertexId,
			Origin = origin,
			OriginPart = originPart,
			CurrentDepth = 0,
			VerticalWeight = math.max(topWeight, normalizedHeight ^ math.max(sideDeformDepth, 0.001)),
			TopWeight = topWeight,
		} :: VertexState)

		if topWeight > 0.95 then
			table.insert(topVertices, vertices[#vertices])
		end
	end

	local impactDepth = 0
	local wasOverBlock = false
	local lastBounceTime = 0

	local connection = RunService.RenderStepped:Connect(function(dt)
		if not instance.Parent or not collider.Parent or not visual.Parent then
			return
		end

		visual.CFrame = collider.CFrame
		visual.Size = collider.Size

		local _, humanoid, root, feet = getCharacterParts()
		local contacts = {} :: {[number]: Vector3}
		local rootLocalPosition = Vector3.zero
		local overBlock = false
		local enteredBlock = false
		local impactDownwardSpeed = 0

		if root then
			overBlock = isOverBlock(collider, root, self.Attributes.FootHeight :: number)
			enteredBlock = overBlock and not wasOverBlock
			rootLocalPosition = collider.CFrame:PointToObjectSpace(root.Position)
			contacts = getContactPoints(collider, root, feet, self.Attributes.FootHeight :: number)

			if enteredBlock then
				impactDownwardSpeed = math.max(-root.AssemblyLinearVelocity.Y, 0)
				local impactVelocity = self.Attributes.ImpactVelocity :: number
				local impactMaxDepth = self.Attributes.ImpactDepth :: number
				impactDepth = math.max(impactDepth, math.clamp(impactDownwardSpeed / impactVelocity, 0, 1) * impactMaxDepth)
			end
		end

		local radius = self.Attributes.Radius :: number
		local maxDepth = self.Attributes.MaxDepth :: number
		local falloffPower = self.Attributes.FalloffPower :: number
		local springSpeed = self.Attributes.SpringSpeed :: number
		local returnSpeed = self.Attributes.ReturnSpeed :: number
		local impactReturnSpeed = self.Attributes.ImpactReturnSpeed :: number

		impactDepth += (0 - impactDepth) * (1 - math.exp(-impactReturnSpeed * dt))

		if root and enteredBlock then
			local now = os.clock()
			local bounceCooldown = self.Attributes.BounceCooldown :: number

			if now - lastBounceTime >= bounceCooldown then
				setBounceActive(true)
				BounceState.RunningSince = nil
				BounceState.LastSource = collider
				BounceState.QueuedVelocity = math.max(
					BounceState.QueuedVelocity,
					getBounceVelocity(impactDownwardSpeed, springSpeed, returnSpeed, self.Attributes)
				)
				BounceState.QueuedTime = now
				lastBounceTime = now
			end
		end

		wasOverBlock = overBlock

		for _, vertex in vertices do
			local targetDepth = 0

			for _, contact in contacts do
				local distanceXZ = (Vector2.new(vertex.OriginPart.X, vertex.OriginPart.Z) - Vector2.new(contact.X, contact.Z)).Magnitude
				local influence = math.clamp(1 - distanceXZ / radius, 0, 1)
				targetDepth = math.max(targetDepth, (maxDepth + impactDepth) * influence ^ falloffPower * vertex.VerticalWeight)
			end

			local speed = if targetDepth > vertex.CurrentDepth then springSpeed else returnSpeed
			vertex.CurrentDepth += (targetDepth - vertex.CurrentDepth) * (1 - math.exp(-speed * dt))

			editableMesh:SetPosition(vertex.Id, vertex.Origin - Vector3.yAxis * partDepthToMeshDepth(vertex.CurrentDepth, bounds, collider.Size))
		end

		if root and BounceState.Active and BounceState.LastSource == collider and BounceState.QueuedVelocity > 0 then
			local surfaceDepth = getCurrentDepthAtPoint(rootLocalPosition, topVertices, self.Attributes.SurfaceSampleRadius :: number)
			local triggerDepth = maxDepth * (self.Attributes.BounceSquashRatio :: number)
			local waitedLongEnough = os.clock() - BounceState.QueuedTime >= (self.Attributes.BounceSquashDelay :: number)

			if surfaceDepth >= triggerDepth or waitedLongEnough or not overBlock then
				BounceState.PendingVelocity = math.max(BounceState.PendingVelocity, BounceState.QueuedVelocity)
				BounceState.QueuedVelocity = 0
			end
		end

		updateBounceState(collider, humanoid, root, dt, self.Attributes.BounceReleaseSpeed :: number)

		local fakeCollisionEnabled = self.Attributes.FakeCollision == true

		if fakeCollisionEnabled and root and overBlock then
			local halfSize = collider.Size * 0.5
			local collisionSize = self.Attributes.CollisionSize :: number
			local collisionThickness = self.Attributes.CollisionThickness :: number
			local surfaceSampleRadius = self.Attributes.SurfaceSampleRadius :: number
			local cellSize = collisionSize / collisionGrid
			local startOffset = -collisionSize * 0.5 + cellSize * 0.5
			local partIndex = 1

			for row = 1, collisionGrid do
				for column = 1, collisionGrid do
					local fakeCollision = fakeCollisions[partIndex]
					local offsetX = startOffset + (column - 1) * cellSize
					local offsetZ = startOffset + (row - 1) * cellSize
					local sampleX = clampInside(rootLocalPosition.X + offsetX, halfSize.X, cellSize * 0.5)
					local sampleZ = clampInside(rootLocalPosition.Z + offsetZ, halfSize.Z, cellSize * 0.5)
					local surfaceDepth = getCurrentDepthAtPoint(Vector3.new(sampleX, halfSize.Y, sampleZ), topVertices, surfaceSampleRadius)
					local surfaceLocalY = halfSize.Y - surfaceDepth + (self.Attributes.SurfacePadding :: number)

					fakeCollision.Size = Vector3.new(cellSize, collisionThickness, cellSize)
					fakeCollision.CFrame = collider.CFrame * CFrame.new(sampleX, surfaceLocalY - collisionThickness * 0.5, sampleZ)
					fakeCollision.CanCollide = true

					partIndex += 1
				end
			end
		else
			setFakeCollisionEnabled(fakeCollisions, false, collider.CFrame * CFrame.new(0, -collider.Size.Y * 2, 0))
		end
	end)

	self:Cleanup(connection)
	self:Cleanup(visual)
	for _, fakeCollision in fakeCollisions do
		self:Cleanup(fakeCollision)
	end
	self:Cleanup(function()
		if BounceState.LastSource == collider then
			setBounceActive(false)
			BounceState.QueuedVelocity = 0
			BounceState.PendingVelocity = 0
			BounceState.RunningSince = nil
			BounceState.LastSource = nil
		end

		collider.Transparency = originalTransparency
		collider.CanCollide = originalCanCollide
		editableMesh:Destroy()
	end)
end)

return SoftBlockComponent
