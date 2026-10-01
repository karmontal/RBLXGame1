--!strict
-- Loads, caches and saves player data with a lightweight session lock so two
-- servers never write the same profile at once (prevents monster duplication
-- through fast server hopping).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

export type OwnedMonster = {
	Id: string,
	Mutation: string,
}

export type Profile = {
	Cash: number,
	PendingCash: number,
	Rebirths: number,
	-- Slot index (as string, DataStore-safe) -> monster
	Slots: { [string]: OwnedMonster },
	-- Recent Developer Product receipt ids, so a retried receipt is never granted twice.
	Purchases: { string },
	-- Redeem codes already used (upper-case).
	RedeemedCodes: { string },
	-- Pass perks granted by codes: key -> unix expiry (0 = permanent).
	CodePasses: { [string]: number },
	-- UI language chosen by the player ("en"/"ar"); "" = auto-detect.
	Language: string,
}

local SESSION_LOCK_TIMEOUT = 30 * 60
local LOAD_ATTEMPTS = 5

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
-- Players whose profile could not be locked/loaded: never save over their data.
local readOnly: { [Player]: boolean } = {}

local function defaultProfile(): Profile
	return {
		Cash = Config.StartingCash,
		PendingCash = 0,
		Rebirths = 0,
		Slots = {},
		Purchases = {},
		RedeemedCodes = {},
		CodePasses = {},
		Language = "",
	}
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function reconcile(data: any): Profile
	local profile = defaultProfile()
	if type(data) == "table" then
		profile.Cash = tonumber(data.Cash) or profile.Cash
		profile.PendingCash = tonumber(data.PendingCash) or 0
		profile.Rebirths = tonumber(data.Rebirths) or 0
		if data.Language == "en" or data.Language == "ar" then
			profile.Language = data.Language
		end
		if type(data.RedeemedCodes) == "table" then
			for _, code in data.RedeemedCodes do
				if type(code) == "string" then
					table.insert(profile.RedeemedCodes, code)
				end
			end
		end
		if type(data.CodePasses) == "table" then
			for key, expiresAt in data.CodePasses do
				if type(key) == "string" and tonumber(expiresAt) then
					profile.CodePasses[key] = tonumber(expiresAt) :: number
				end
			end
		end
		if type(data.Purchases) == "table" then
			for _, receiptId in data.Purchases do
				if type(receiptId) == "string" then
					table.insert(profile.Purchases, receiptId)
				end
			end
		end
		if type(data.Slots) == "table" then
			for slot, monster in data.Slots do
				if type(monster) == "table" and type(monster.Id) == "string" then
					profile.Slots[tostring(slot)] = {
						Id = monster.Id,
						Mutation = type(monster.Mutation) == "string" and monster.Mutation or "None",
					}
				end
			end
		end
	end
	return profile
end

local function serialize(profile: Profile, locked: boolean): any
	return {
		Cash = profile.Cash,
		PendingCash = profile.PendingCash,
		Rebirths = profile.Rebirths,
		Slots = profile.Slots,
		Purchases = profile.Purchases,
		RedeemedCodes = profile.RedeemedCodes,
		CodePasses = profile.CodePasses,
		Language = profile.Language,
		SessionLock = if locked then { JobId = game.JobId, Time = os.time() } else nil,
	}
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not be saved:", result)
	end
end

-- Returns the profile, or nil if the player left while loading.
function DataService.Load(player: Player): Profile?
	if not store then
		readOnly[player] = true
		profiles[player] = defaultProfile()
		return profiles[player]
	end

	local loaded: any = nil
	local success = false
	for attempt = 1, LOAD_ATTEMPTS do
		local forceTakeover = attempt == LOAD_ATTEMPTS
		local lockedElsewhere = false
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(keyFor(player), function(old)
				local lock = type(old) == "table" and old.SessionLock or nil
				if
					not forceTakeover
					and type(lock) == "table"
					and lock.JobId ~= game.JobId
					and os.time() - (tonumber(lock.Time) or 0) < SESSION_LOCK_TIMEOUT
				then
					lockedElsewhere = true
					return nil -- abort write, keep the other server's lock
				end
				loaded = reconcile(old)
				return serialize(loaded, true)
			end)
		end)
		if ok and not lockedElsewhere then
			success = true
			break
		end
		if not ok then
			warn("[DataService] Load failed for", player.Name, err)
			if string.find(tostring(err), "StudioAccessToApisNotAllowed", 1, true) then
				break -- Studio without API access: use a temporary profile right away
			end
		end
		if not player.Parent then
			return nil
		end
		task.wait(if lockedElsewhere then 6 else 2)
	end

	if not player.Parent then
		if success then
			-- Left while loading: drop the session lock we just took.
			profiles[player] = loaded
			DataService.Release(player)
		end
		return nil
	end
	if not success then
		warn("[DataService] Using a temporary profile for", player.Name)
		readOnly[player] = true
		loaded = defaultProfile()
	end
	profiles[player] = loaded
	return loaded
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

-- Returns false only when a write was attempted and did not land.
function DataService.Save(player: Player, release: boolean): boolean
	local profile = profiles[player]
	if not profile or not store or readOnly[player] then
		return true
	end
	local written = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			local lock = type(old) == "table" and old.SessionLock or nil
			if type(lock) == "table" and lock.JobId ~= game.JobId then
				return nil -- another server took over; never overwrite it
			end
			written = true
			return serialize(profile, not release)
		end)
	end)
	if not ok then
		warn("[DataService] Save failed for", player.Name, err)
		return false
	end
	return written
end

function DataService.Release(player: Player)
	DataService.Save(player, true)
	profiles[player] = nil
	readOnly[player] = nil
end

function DataService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in profiles do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for _, player in Players:GetPlayers() do
			if profiles[player] then
				pending += 1
				task.spawn(function()
					DataService.Save(player, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
