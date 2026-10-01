--!strict
-- Game pass ownership + Developer Product receipts.
-- Ids live in ReplicatedStorage.Shared.Monetization.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Monetization = require(Shared.Monetization)
local Monsters = require(Shared.Monsters)
local Mutations = require(Shared.Mutations)
local Rarities = require(Shared.Rarities)
local DataService = require(script.Parent.DataService)
local MonsterModels = require(script.Parent.MonsterModels)
local PlotService = require(script.Parent.PlotService)

local MAX_STORED_RECEIPTS = 50

local MonetizationService = {}

local rng = Random.new()
local passByGamePassId: { [number]: string } = {}
local productHandlers: { [number]: (player: Player) -> () } = {}

local function applySpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and PlotService.HasPass(player, "SpeedBoost") and not player:GetAttribute("Carrying") then
		humanoid.WalkSpeed = Config.SpeedBoostWalkSpeed
	end
end

local function grantPass(player: Player, key: string, announce: boolean)
	if PlotService.HasPass(player, key) then
		return
	end
	player:SetAttribute("Pass_" .. key, true)
	PlotService.Refresh(player)
	applySpeed(player)
	if announce then
		PlotService.Notify(player, "Thanks! " .. Monetization.ByKey[key].Name .. " unlocked!", "rare")
	end
end

-- Checks every configured pass once when the player's plot is ready.
function MonetizationService.LoadPasses(player: Player)
	for _, pass in Monetization.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and owns then
				grantPass(player, pass.Key, false)
			end
		end
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 5)
		applySpeed(player)
	end)
	applySpeed(player)
end

local function incomePerSecond(player: Player): number
	return (player:GetAttribute("Income") :: number?) or 0
end

local function rollLuckyMonster(): (string, string)
	local pool = {}
	local totalWeight = 0
	for _, rarity in Rarities.List do
		if rarity.Order >= Config.LuckyEggMinRarity then
			for _, monster in Monsters.ByRarity[rarity.Name] or {} do
				table.insert(pool, { Id = monster.Id, Weight = rarity.Weight })
				totalWeight += rarity.Weight
			end
		end
	end
	local roll = rng:NextNumber() * totalWeight
	for _, entry in pool do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Id, Mutations.Roll(rng).Name
		end
	end
	return pool[#pool].Id, "None"
end

local function registerProducts()
	local handlers: { [string]: (player: Player) -> () } = {
		CashSmall = function(player)
			local amount = math.max(Config.CashSmallMinimum, incomePerSecond(player) * Config.CashSmallSeconds)
			PlotService.AddCash(player, amount)
			PlotService.Notify(player, "+" .. Format.Money(amount) .. "! Thanks for the support!", "cash")
		end,
		CashLarge = function(player)
			local amount = math.max(Config.CashLargeMinimum, incomePerSecond(player) * Config.CashLargeSeconds)
			PlotService.AddCash(player, amount)
			PlotService.Notify(player, "+" .. Format.Money(amount) .. "! Thanks for the support!", "cash")
		end,
		LuckyEgg = function(player)
			local monsterId, mutation = rollLuckyMonster()
			local label = (if mutation ~= "None" then mutation .. " " else "") .. Monsters.ById[monsterId].DisplayName
			if PlotService.AddMonster(player, { Id = monsterId, Mutation = mutation }) then
				PlotService.Notify(player, "🥚 Lucky Egg hatched a " .. label .. "!", "rare")
			else
				-- Base full: pay out the monster's value so the purchase is never wasted.
				local value = MonsterModels.PriceOf(monsterId, mutation)
				PlotService.AddCash(player, value)
				PlotService.Notify(player, "Base full! Got " .. Format.Money(value) .. " for your " .. label .. " instead.", "cash")
			end
		end,
	}
	for _, product in Monetization.Products do
		if product.Id ~= 0 and handlers[product.Key] then
			productHandlers[product.Id] = handlers[product.Key]
		end
	end
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = player and DataService.Get(player)
	local handler = productHandlers[receipt.ProductId]
	if not player or not profile or not PlotService.GetPlot(player) or not handler then
		-- Player not ready (or left): Roblox retries on their next join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receipt.PurchaseId)
	if table.find(profile.Purchases, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, err = pcall(handler, player)
	if not ok then
		warn("[MonetizationService] Failed to grant product", receipt.ProductId, err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(profile.Purchases, receiptId)
	while #profile.Purchases > MAX_STORED_RECEIPTS do
		table.remove(profile.Purchases, 1)
	end
	-- Persist before acknowledging so a crash can't lose a paid grant. If the
	-- save fails, Roblox retries later and the in-memory receipt id prevents
	-- a double grant on this server.
	if not DataService.Save(player, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Start()
	for _, pass in Monetization.GamePasses do
		if pass.Id ~= 0 then
			passByGamePassId[pass.Id] = pass.Key
		end
	end
	registerProducts()

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		local key = passByGamePassId[gamePassId]
		if purchased and key then
			grantPass(player, key, true)
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
