--!strict
-- Marketing redeem codes. Lives in ServerScriptService, so players can't
-- read the list. Codes are case-insensitive; write them in UPPER CASE here.
--
-- Rewards (any combination):
--   Cash = 10000                 -- add cash
--   LuckyEggs = 1                -- hatch N Epic+ monsters
--   Pass = "DoubleCash"          -- a Game Pass perk (key from assets/store.json)
--   PassHours = 24               -- optional: perk lasts N hours (omit = forever)
-- Limits (optional):
--   Expires = untilDate(2026, 11, 1) -- code stops working at this moment (UTC midnight)
--   MaxRedemptions = 100         -- total uses across all servers
-- Every code works once per player.

export type Code = {
	Cash: number?,
	LuckyEggs: number?,
	Pass: string?,
	PassHours: number?,
	Expires: number?,
	MaxRedemptions: number?,
}

local function untilDate(year: number, month: number, day: number): number
	return DateTime.fromUniversalTime(year, month, day).UnixTimestamp
end

local Codes: { [string]: Code } = {
	-- Launch giveaway: everyone gets a head start.
	RELEASE = { Cash = 10_000, LuckyEggs = 1, Expires = untilDate(2026, 11, 1) },
	-- Short perk tasters that make people want the real pass.
	SPEEDY = { Pass = "SpeedBoost", PassHours = 24, Expires = untilDate(2026, 12, 31) },
	DOUBLEUP = { Pass = "DoubleCash", PassHours = 1, Expires = untilDate(2026, 12, 31) },
	-- Limited drop for socials: first 100 players keep Auto Collect forever.
	MONSTER100 = { Pass = "AutoCollect", MaxRedemptions = 100 },
	-- Double cash for 1 hour, first 50 players only.
	MMK50 = { Pass = "DoubleCash", PassHours = 1, MaxRedemptions = 50 },
}

return Codes
