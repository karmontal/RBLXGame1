--!strict
-- Builds monster models. Uses the uploaded Higgsfield mesh when the monster
-- has an AssetId, otherwise a simple part-built placeholder so the game is
-- always playable. Every model has an invisible anchored "Root" part at its
-- feet (PrimaryPart) that prompts and billboards attach to.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Monsters = require(Shared.Monsters)
local Mutations = require(Shared.Mutations)
local Rarities = require(Shared.Rarities)

local MonsterModels = {}

local templateCache: { [number]: Model | false } = {}

local function loadAssetTemplate(assetId: number): Model?
	local cached = templateCache[assetId]
	if cached ~= nil then
		return if cached then cached else nil
	end
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		warn("[MonsterModels] Could not load asset", assetId, result)
		templateCache[assetId] = false
		return nil
	end
	local container = result :: Model
	local template = Instance.new("Model")
	for _, child in container:GetChildren() do
		child.Parent = template
	end
	container:Destroy()
	templateCache[assetId] = template
	return template
end

local function buildPlaceholder(color: Color3, height: number): Model
	local model = Instance.new("Model")
	local bodySize = height * 0.8

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.one * bodySize
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = CFrame.new(0, bodySize / 2, 0)
	body.Parent = model

	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.one * bodySize * 0.28
		eye.Color = Color3.new(1, 1, 1)
		eye.Material = Enum.Material.SmoothPlastic
		eye.CFrame = CFrame.new(side * bodySize * 0.18, bodySize * 0.62, -bodySize * 0.4)
		eye.Parent = model

		local pupil = Instance.new("Part")
		pupil.Name = "Pupil"
		pupil.Shape = Enum.PartType.Ball
		pupil.Size = Vector3.one * bodySize * 0.14
		pupil.Color = Color3.new(0.05, 0.05, 0.05)
		pupil.Material = Enum.Material.SmoothPlastic
		pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -bodySize * 0.09)
		pupil.Parent = model
	end

	for _, side in { -1, 1 } do
		local foot = Instance.new("Part")
		foot.Name = "Foot"
		foot.Size = Vector3.new(bodySize * 0.25, bodySize * 0.15, bodySize * 0.3)
		foot.Color = color:Lerp(Color3.new(0, 0, 0), 0.25)
		foot.Material = Enum.Material.SmoothPlastic
		foot.CFrame = CFrame.new(side * bodySize * 0.22, bodySize * 0.075, -bodySize * 0.1)
		foot.Parent = model
	end

	return model
end

local function applyMutation(model: Model, root: BasePart, mutationName: string)
	local mutation = Mutations.ByName[mutationName]
	if not mutation or mutation.Name == "None" then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = mutation.Color or Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = mutation.Color or Color3.new(1, 1, 1)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	if mutation.Name == "Fire" then
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 6
		fire.Parent = root
	elseif mutation.Name == "Diamond" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = mutation.Color :: Color3
		sparkles.Parent = root
	elseif mutation.Name == "Rainbow" then
		highlight:SetAttribute("Rainbow", true)
		local sparkles = Instance.new("Sparkles")
		sparkles.Parent = root
	end
end

local function makeBillboard(root: BasePart, height: number): (TextLabel, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(200, 72)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 1.8, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Parent = root

	local function label(name: string, order: number, size: number): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, 0, 0, size)
		text.Position = UDim2.fromOffset(0, order)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.2
		text.Parent = gui
		return text
	end

	return label("Title", 0, 26), label("Rarity", 26, 20), label("Stats", 46, 22)
end

export type BuildOptions = {
	Price: number?, -- shown on the belt
	IncomeMultiplier: number?,
}

-- Builds a fresh, anchored, non-colliding monster model.
function MonsterModels.Build(monsterId: string, mutationName: string, options: BuildOptions?): Model
	local monster = Monsters.ById[monsterId]
	assert(monster, "Unknown monster " .. tostring(monsterId))
	local rarity = Rarities.ByName[monster.Rarity]
	local mutation = Mutations.ByName[mutationName] or Mutations.None
	local height = rarity.Height

	local model = Instance.new("Model")
	model.Name = monster.Id

	local visual: Model? = nil
	if monster.AssetId then
		local template = loadAssetTemplate(monster.AssetId)
		if template then
			visual = template:Clone()
		end
	end
	if visual then
		local _, extents = visual:GetBoundingBox()
		if extents.Y > 0 then
			visual:ScaleTo(visual:GetScale() * height / extents.Y)
		end
		-- Put the bottom center of the mesh at the origin.
		local cf, size = visual:GetBoundingBox()
		local bottomCenter = cf.Position - Vector3.new(0, size.Y / 2, 0)
		visual:PivotTo(CFrame.new(-bottomCenter) * visual:GetPivot())
	else
		visual = buildPlaceholder(monster.Color, height)
	end
	local visualModel = visual :: Model
	visualModel.Name = "Visual"
	visualModel.Parent = model

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 0.2, 2)
	root.Transparency = 1
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CastShadow = descendant ~= root
		end
	end
	-- Keep the root queryable so prompts parented to it are clickable.
	root.CanQuery = true

	applyMutation(model, root, mutation.Name)

	local title, rarityLabel, stats = makeBillboard(root, height)
	local prefix = if mutation.Name ~= "None" then mutation.Name .. " " else ""
	title.Text = prefix .. monster.DisplayName
	title.TextColor3 = mutation.Color or Color3.new(1, 1, 1)
	rarityLabel.Text = monster.Rarity
	rarityLabel.TextColor3 = rarity.Color
	local income = monster.Income * mutation.Multiplier * ((options and options.IncomeMultiplier) or 1)
	local statsText = Format.Money(income) .. "/s"
	if options and options.Price then
		statsText = Format.Money(options.Price) .. "  •  " .. statsText
	end
	stats.Text = statsText
	stats.TextColor3 = Color3.fromRGB(120, 255, 120)

	model:SetAttribute("MonsterId", monster.Id)
	model:SetAttribute("Mutation", mutation.Name)
	return model
end

-- A light, unanchored copy that gets welded above a thief's head.
function MonsterModels.BuildCarry(monsterId: string, mutationName: string): Model
	local model = MonsterModels.Build(monsterId, mutationName)
	local root = model.PrimaryPart :: BasePart
	local info = root:FindFirstChild("Info")
	if info then
		info:Destroy()
	end
	model:ScaleTo(0.6)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			if descendant ~= root then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	return model
end

function MonsterModels.IncomeOf(monsterId: string, mutationName: string): number
	local monster = Monsters.ById[monsterId]
	if not monster then
		return 0
	end
	local mutation = Mutations.ByName[mutationName] or Mutations.None
	return monster.Income * mutation.Multiplier
end

function MonsterModels.PriceOf(monsterId: string, mutationName: string): number
	local monster = Monsters.ById[monsterId]
	if not monster then
		return 0
	end
	local mutation = Mutations.ByName[mutationName] or Mutations.None
	return monster.Price * mutation.Multiplier
end

return MonsterModels
