--!strict
-- Redeem codes: validates a code, grants its rewards once per player, keeps
-- a global redemption counter for limited codes and expires timed perks.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Monetization = require(Shared.Monetization)
local Codes = require(script.Parent.Parent.Codes)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlotService = require(script.Parent.PlotService)

local MAX_CODE_LENGTH = 32
local COOLDOWN = 2 -- seconds between attempts per player

local CodeService = {}

local counterStore: DataStore? = nil
local busy: { [Player]: boolean } = {}
local lastAttempt: { [Player]: number } = {}

-- Atomically takes one of a limited code's redemptions. Returns ok, message.
local function claimGlobalSlot(code: string, maxRedemptions: number): (boolean, string?)
	if not counterStore then
		return false, "Codes are unavailable right now, try again later."
	end
	local claimed = false
	local ok = pcall(function()
		(counterStore :: DataStore):UpdateAsync(code, function(count)
			local used = tonumber(count) or 0
			if used >= maxRedemptions then
				return nil
			end
			claimed = true
			return used + 1
		end)
	end)
	if not ok then
		return false, "Codes are unavailable right now, try again later."
	end
	if not claimed then
		return false, "This code has been fully claimed!"
	end
	return true, nil
end

local function applyPassReward(player: Player, key: string, hours: number?)
	local profile = DataService.Get(player) :: DataService.Profile
	local now = os.time()
	local current = profile.CodePasses[key]
	if current == 0 then
		return -- already permanent
	end
	local expiresAt = if hours then math.max(current or now, now) + math.floor(hours * 3600) else 0
	profile.CodePasses[key] = expiresAt
	MonetizationService.GrantPass(player, key)
end

local function describe(reward: Codes.Code): string
	local parts = {}
	if reward.Cash then
		table.insert(parts, Format.Money(reward.Cash))
	end
	if reward.LuckyEggs then
		table.insert(parts, reward.LuckyEggs .. "x Lucky Egg")
	end
	if reward.Pass then
		local item = Monetization.ByKey[reward.Pass]
		local name = if item then item.Name else reward.Pass
		table.insert(parts, name .. (if reward.PassHours then " (" .. reward.PassHours .. "h)" else ""))
	end
	return table.concat(parts, " + ")
end

local function redeem(player: Player, rawCode: unknown): (boolean, string)
	if type(rawCode) ~= "string" or #rawCode == 0 or #rawCode > MAX_CODE_LENGTH then
		return false, "Enter a code."
	end
	local code = string.upper((rawCode:gsub("%s", "")))
	local reward = Codes[code]
	if not reward then
		return false, "Invalid code."
	end
	local profile = DataService.Get(player)
	if not profile or not PlotService.GetPlot(player) then
		return false, "Still loading, try again in a moment."
	end
	if table.find(profile.RedeemedCodes, code) then
		return false, "You already used this code."
	end
	if reward.Expires and os.time() > reward.Expires then
		return false, "This code has expired."
	end
	if reward.Pass and not Monetization.ByKey[reward.Pass] then
		warn("[CodeService] Code", code, "references unknown pass", reward.Pass)
		return false, "Invalid code."
	end
	if reward.MaxRedemptions then
		local ok, message = claimGlobalSlot(code, reward.MaxRedemptions)
		if not ok then
			return false, message :: string
		end
	end

	-- Record first so an error mid-grant can't be retried for double rewards.
	table.insert(profile.RedeemedCodes, code)
	if reward.Cash then
		PlotService.AddCash(player, reward.Cash)
	end
	if reward.Pass then
		applyPassReward(player, reward.Pass, reward.PassHours)
	end
	for _ = 1, reward.LuckyEggs or 0 do
		MonetizationService.GiveLuckyEgg(player)
	end
	task.spawn(DataService.Save, player, false)
	return true, "Code redeemed: " .. describe(reward) .. "!"
end

-- Re-applies code-granted perks that are still active (call after passes load).
function CodeService.LoadPlayer(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local now = os.time()
	for key, expiresAt in profile.CodePasses do
		if expiresAt == 0 or expiresAt > now then
			MonetizationService.GrantPass(player, key)
		else
			profile.CodePasses[key] = nil
		end
	end
end

function CodeService.Start(remote: RemoteFunction)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("CodeRedemptions_v1")
	end)
	if ok then
		counterStore = result
	end

	remote.OnServerInvoke = function(player: Player, rawCode: unknown): (boolean, string)
		local now = os.clock()
		if busy[player] or now - (lastAttempt[player] or 0) < COOLDOWN then
			return false, "Slow down a little!"
		end
		busy[player] = true
		lastAttempt[player] = now
		local success, okOrError, message = pcall(redeem, player, rawCode)
		busy[player] = nil
		if not success then
			warn("[CodeService] Redeem failed:", okOrError)
			return false, "Something went wrong, try again."
		end
		if okOrError then
			PlotService.Notify(player, message :: string, "rare")
		end
		return okOrError :: boolean, message :: string
	end

	-- Expire timed perks while players are online.
	task.spawn(function()
		while true do
			task.wait(15)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					for key, expiresAt in profile.CodePasses do
						if expiresAt ~= 0 and expiresAt <= now then
							profile.CodePasses[key] = nil
							MonetizationService.RevokePass(player, key)
							PlotService.Notify(player, (Monetization.ByKey[key] and Monetization.ByKey[key].Name or key) .. " has ended. Get it forever in the Shop!", "info")
						end
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		lastAttempt[player] = nil
	end)
end

return CodeService
