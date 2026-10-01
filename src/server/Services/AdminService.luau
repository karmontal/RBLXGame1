--!strict
-- Owner/Admin roles and admin commands.
--   Owner: the experience creator (or rank 255 in the owning group).
--   Admin: granted/revoked by the owner with :admin / :unadmin, stored in a
--          DataStore so it applies on every server.
-- Admins get every Game Pass perk for free and an [ADMIN] chat tag. All
-- commands run through one RemoteFunction and are permission-checked here.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Monetization = require(Shared.Monetization)
local Monsters = require(Shared.Monsters)
local Mutations = require(Shared.Mutations)
local ConveyorService = require(script.Parent.ConveyorService)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlotService = require(script.Parent.PlotService)

type Role = "Owner" | "Admin"

type Msg = { k: string, a: { [string]: any }? }

type Command = {
	Usage: string,
	Help: string,
	OwnerOnly: boolean?,
	Run: (caller: Player, args: { string }) -> Msg,
}

local function msg(key: string, args: { [string]: any }?): Msg
	return { k = key, a = args }
end

local function usage(text: string): Msg
	return msg("a.usage", { usage = text })
end

local ROLES_KEY = "admins"
local SYNC_INTERVAL = 60
local MAX_CASH_GRANT = 1e15

local AdminService = {}

local store: DataStore? = nil
local adminIds: { [string]: boolean } = {} -- tostring(userId) -> true
local lastCommand: { [Player]: number } = {}

local function isOwner(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		return ok and rank == 255
	end
	return player.UserId == game.CreatorId
end

local function roleOf(player: Player): Role?
	if isOwner(player) then
		return "Owner"
	elseif adminIds[tostring(player.UserId)] then
		return "Admin"
	end
	return nil
end

-- Admin perks: every pass while they hold a role; on removal keep only what
-- they bought or still have from a code.
local function applyRole(player: Player)
	local role = roleOf(player)
	local previous = player:GetAttribute("Role")
	player:SetAttribute("Role", role)
	if role then
		for _, pass in Monetization.GamePasses do
			MonetizationService.GrantPass(player, pass.Key)
		end
	elseif previous then
		local profile = DataService.Get(player)
		local now = os.time()
		for _, pass in Monetization.GamePasses do
			local codeExpiry = profile and profile.CodePasses[pass.Key]
			if not (codeExpiry and (codeExpiry == 0 or codeExpiry > now)) then
				MonetizationService.RevokePass(player, pass.Key)
			end
		end
	end
end

local function loadAdmins()
	if not store then
		return
	end
	local ok, data = pcall(function()
		return (store :: DataStore):GetAsync(ROLES_KEY)
	end)
	if ok then
		local fresh: { [string]: boolean } = {}
		if type(data) == "table" then
			for id, value in data do
				if value == true then
					fresh[tostring(id)] = true
				end
			end
		end
		adminIds = fresh
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Role") ~= roleOf(player) then
				applyRole(player)
			end
		end
	end
end

local function setAdmin(userId: number, enabled: boolean): boolean
	if not store then
		return false
	end
	local key = tostring(userId)
	local ok = pcall(function()
		(store :: DataStore):UpdateAsync(ROLES_KEY, function(old)
			local data = if type(old) == "table" then old else {}
			data[key] = if enabled then true else nil
			return data
		end)
	end)
	if ok then
		adminIds[key] = if enabled then true else nil
	end
	return ok
end

-- "me", "all", "others" or a (partial) username / display name.
local function findPlayers(caller: Player, query: string?): { Player }
	if not query or query == "" then
		return {}
	end
	local q = string.lower(query)
	if q == "me" then
		return { caller }
	elseif q == "all" then
		return Players:GetPlayers()
	elseif q == "others" then
		local others = {}
		for _, player in Players:GetPlayers() do
			if player ~= caller then
				table.insert(others, player)
			end
		end
		return others
	end
	for _, player in Players:GetPlayers() do
		if string.lower(player.Name) == q or string.lower(player.DisplayName) == q then
			return { player }
		end
	end
	local matches = {}
	for _, player in Players:GetPlayers() do
		if string.sub(string.lower(player.Name), 1, #q) == q or string.sub(string.lower(player.DisplayName), 1, #q) == q then
			table.insert(matches, player)
		end
	end
	return if #matches == 1 then matches else {}
end

local function names(players: { Player }): string
	local list = {}
	for _, player in players do
		table.insert(list, player.Name)
	end
	return table.concat(list, ", ")
end

local function findMonster(query: string?): string?
	if not query then
		return nil
	end
	local q = string.lower(query)
	for _, monster in Monsters.List do
		if string.lower(monster.Id) == q or string.lower(monster.DisplayName) == q then
			return monster.Id
		end
	end
	return nil
end

local function findMutation(query: string?): string?
	if not query then
		return "None"
	end
	for name in Mutations.ByName do
		if string.lower(name) == string.lower(query) then
			return name
		end
	end
	return nil
end

local function findPass(query: string?): string?
	if not query then
		return nil
	end
	local q = string.lower(query)
	for _, pass in Monetization.GamePasses do
		if string.lower(pass.Key) == q or string.lower((pass.Name:gsub("%s", ""))) == q then
			return pass.Key
		end
	end
	return nil
end

local function passKeys(): string
	local keys = {}
	for _, pass in Monetization.GamePasses do
		table.insert(keys, pass.Key)
	end
	return table.concat(keys, ", ")
end

local function monsterIds(): string
	local ids = {}
	for _, monster in Monsters.List do
		table.insert(ids, monster.Id)
	end
	return table.concat(ids, ", ")
end

local commands: { [string]: Command } = {}

commands.help = {
	Usage = ":help",
	Help = "List commands",
	Run = function(caller)
		local lines = {}
		local isOwnerCaller = roleOf(caller) == "Owner"
		for _, command in commands do
			if isOwnerCaller or not command.OwnerOnly then
				table.insert(lines, command.Usage .. "  —  " .. command.Help)
			end
		end
		table.sort(lines)
		return msg("raw", { text = table.concat(lines, "\n") })
	end,
}

commands.admin = {
	Usage = ":admin <player>",
	Help = "Make a player admin (owner only)",
	OwnerOnly = true,
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		if #targets ~= 1 then
			return msg("a.notFound")
		end
		local target = targets[1]
		if not setAdmin(target.UserId, true) then
			return msg("a.saveFailed")
		end
		applyRole(target)
		PlotService.Notify(target, "n.adminGranted", nil, "rare")
		return msg("a.nowAdmin", { player = target.Name })
	end,
}

commands.unadmin = {
	Usage = ":unadmin <player|userId>",
	Help = "Remove admin (owner only)",
	OwnerOnly = true,
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local userId = if #targets == 1 then targets[1].UserId else tonumber(args[1])
		if not userId then
			return msg("a.notFound")
		end
		if not setAdmin(userId, false) then
			return msg("a.saveFailed")
		end
		local target = Players:GetPlayerByUserId(userId)
		if target then
			applyRole(target)
			PlotService.Notify(target, "n.adminRemoved")
		end
		return msg("a.removedAdmin", { player = if target then target.Name else tostring(userId) })
	end,
}

commands.admins = {
	Usage = ":admins",
	Help = "List admin UserIds",
	Run = function()
		local ids = {}
		for id in adminIds do
			local player = Players:GetPlayerByUserId(tonumber(id) :: number)
			table.insert(ids, if player then player.Name .. " (" .. id .. ")" else id)
		end
		return if #ids > 0 then msg("a.list", { list = table.concat(ids, ", ") }) else msg("a.noAdmins")
	end,
}

commands.givecash = {
	Usage = ":givecash <player|all> <amount>",
	Help = "Add cash",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local amount = tonumber(args[2])
		if #targets == 0 or not amount or amount <= 0 or amount > MAX_CASH_GRANT then
			return usage(":givecash <player|all> <amount>")
		end
		for _, target in targets do
			PlotService.AddCash(target, amount)
			PlotService.Notify(target, "n.adminCash", { amount = Format.Money(amount) }, "cash")
		end
		return msg("a.cashDone", { amount = Format.Money(amount), players = names(targets) })
	end,
}

commands.givepass = {
	Usage = ":givepass <player|all> <pass> [hours]",
	Help = "Give a pass perk (forever or N hours)",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local key = findPass(args[2])
		local hours = tonumber(args[3])
		if #targets == 0 or not key or (args[3] and (not hours or hours <= 0)) then
			return usage(":givepass <player|all> <pass> [hours] — " .. passKeys())
		end
		for _, target in targets do
			local profile = DataService.Get(target)
			if profile then
				local now = os.time()
				local current = profile.CodePasses[key]
				if current ~= 0 then
					profile.CodePasses[key] = if hours then math.max(current or now, now) + math.floor(hours * 3600) else 0
				end
				MonetizationService.GrantPass(target, key)
				PlotService.Notify(target, "n.adminGift", { thing = "@item." .. key .. ".name" }, "rare")
			end
		end
		local pass = "@item." .. key .. ".name"
		return msg("a.passDone", {
			pass = if hours then msg("reward.passHours", { pass = pass, hours = hours }) else pass,
			players = names(targets),
		})
	end,
}

commands.removepass = {
	Usage = ":removepass <player> <pass>",
	Help = "Remove a free pass perk (not bought ones)",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local key = findPass(args[2])
		if #targets == 0 or not key then
			return usage(":removepass <player> <pass> — " .. passKeys())
		end
		for _, target in targets do
			local profile = DataService.Get(target)
			if profile then
				profile.CodePasses[key] = nil
			end
			if not target:GetAttribute("Role") then
				MonetizationService.RevokePass(target, key)
			end
		end
		return msg("a.passRemoved", { pass = "@item." .. key .. ".name", players = names(targets) })
	end,
}

commands.givemonster = {
	Usage = ":givemonster <player> <monster> [mutation]",
	Help = "Put a monster in a base",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local monsterId = findMonster(args[2])
		local mutation = findMutation(args[3])
		if #targets == 0 or not monsterId or not mutation then
			return usage(":givemonster <player> <monster> [Gold|Diamond|Fire|Rainbow] — " .. monsterIds())
		end
		local given = {}
		for _, target in targets do
			if PlotService.AddMonster(target, { Id = monsterId, Mutation = mutation }) then
				table.insert(given, target)
				PlotService.Notify(target, "n.adminGift", { thing = "@monster:" .. monsterId .. ":" .. mutation }, "rare")
			end
		end
		return if #given > 0
			then msg("a.monsterDone", { monster = "@monster:" .. monsterId .. ":" .. mutation, players = names(given) })
			else msg("a.baseFull")
	end,
}

commands.luckyegg = {
	Usage = ":luckyegg <player|all> [count]",
	Help = "Hatch Lucky Eggs",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local count = math.clamp(math.floor(tonumber(args[2]) or 1), 1, 10)
		if #targets == 0 then
			return usage(":luckyegg <player|all> [count]")
		end
		for _, target in targets do
			for _ = 1, count do
				MonetizationService.GiveLuckyEgg(target)
			end
		end
		return msg("a.eggDone", { count = count, players = names(targets) })
	end,
}

commands.spawn = {
	Usage = ":spawn <monster> [mutation]",
	Help = "Spawn a monster on the conveyor",
	Run = function(_, args)
		local monsterId = findMonster(args[1])
		local mutation = findMutation(args[2])
		if not monsterId or not mutation then
			return usage(":spawn <monster> [mutation] — " .. monsterIds())
		end
		ConveyorService.Spawn(monsterId, mutation)
		return msg("a.spawned", { monster = "@monster:" .. monsterId .. ":" .. mutation })
	end,
}

commands.announce = {
	Usage = ":announce <message>",
	Help = "Message everyone in the server",
	Run = function(caller, args)
		local message = table.concat(args, " ")
		if message == "" then
			return usage(":announce <message>")
		end
		message = string.sub(message, 1, 120)
		for _, player in Players:GetPlayers() do
			PlotService.Notify(player, "n.announce", { player = caller.DisplayName, text = message }, "rare")
		end
		return msg("a.announced")
	end,
}

commands.unlock = {
	Usage = ":unlock <player>",
	Help = "End a base lock and its cooldown",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local done = {}
		for _, target in targets do
			if PlotService.Unlock(target) then
				table.insert(done, target)
			end
		end
		return if #done > 0 then msg("a.unlocked", { players = names(done) }) else usage(":unlock <player>")
	end,
}

commands.speed = {
	Usage = ":speed <player> <walkspeed>",
	Help = "Set walk speed until respawn",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local speed = tonumber(args[2])
		if #targets == 0 or not speed then
			return usage(":speed <player> <walkspeed>")
		end
		speed = math.clamp(speed, 0, 100)
		for _, target in targets do
			local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = speed
			end
		end
		return msg("a.speedDone", { speed = speed, players = names(targets) })
	end,
}

commands.tp = {
	Usage = ":tp <player>",
	Help = "Teleport to a player",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local target = targets[1]
		local targetChar = target and target.Character
		if #targets ~= 1 or not targetChar or not caller.Character then
			return usage(":tp <player>")
		end
		(caller.Character :: Model):PivotTo(targetChar:GetPivot() * CFrame.new(0, 0, 4))
		return msg("a.tpDone", { player = target.Name })
	end,
}

commands.bring = {
	Usage = ":bring <player|all>",
	Help = "Bring players to you",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		local callerChar = caller.Character
		if #targets == 0 or not callerChar then
			return usage(":bring <player|all>")
		end
		for i, target in targets do
			if target ~= caller and target.Character then
				target.Character:PivotTo(callerChar:GetPivot() * CFrame.new(0, 0, -4 - i * 2))
			end
		end
		return msg("a.brought", { players = names(targets) })
	end,
}

commands.kick = {
	Usage = ":kick <player> [reason]",
	Help = "Kick a player (not other admins)",
	Run = function(caller, args)
		local targets = findPlayers(caller, args[1])
		if #targets ~= 1 then
			return usage(":kick <player> [reason]")
		end
		local target = targets[1]
		if target == caller or (roleOf(target) and roleOf(caller) ~= "Owner") then
			return msg("a.cantKick")
		end
		local reason = table.concat(args, " ", 2)
		target:Kick(if reason ~= "" then reason else "Kicked by an admin. / طُردت من قبل الأدمن.")
		return msg("a.kicked", { player = target.Name })
	end,
}

local function run(caller: Player, raw: unknown): Msg
	local role = roleOf(caller)
	if not role then
		return msg("a.noPermission")
	end
	if type(raw) ~= "string" or #raw == 0 or #raw > 300 then
		return msg("a.typeCommand")
	end
	local now = os.clock()
	if now - (lastCommand[caller] or 0) < 0.3 then
		return msg("a.slow")
	end
	lastCommand[caller] = now

	local args = string.split((raw:gsub("^%s+", ""):gsub("%s+$", "")), " ")
	local filtered = {}
	for _, arg in args do
		if arg ~= "" then
			table.insert(filtered, arg)
		end
	end
	local name = string.lower((table.remove(filtered, 1) or ""):gsub("^[:/;!]", ""))
	local command = commands[name]
	if not command then
		return msg("a.unknown", { name = name })
	end
	if command.OwnerOnly and role ~= "Owner" then
		return msg("a.ownerOnly", { name = name })
	end
	local ok, result = pcall(command.Run, caller, filtered)
	if not ok then
		warn("[AdminService] Command failed:", name, result)
		return msg("a.failed", { error = tostring(result) })
	end
	print(string.format("[Admin] %s (%s): %s -> %s", caller.Name, role, raw, (result :: Msg).k))
	return result
end

-- Call after passes/codes are loaded so admin perks layer on top.
function AdminService.LoadPlayer(player: Player)
	applyRole(player)
end

function AdminService.Start(remote: RemoteFunction)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("AdminRoles_v1")
	end)
	if ok then
		store = result
	end
	loadAdmins()
	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL)
			loadAdmins()
		end
	end)

	remote.OnServerInvoke = function(player: Player, raw: unknown): Msg
		return run(player, raw)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastCommand[player] = nil
	end)
end

return AdminService
