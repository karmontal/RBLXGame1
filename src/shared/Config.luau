--!strict
-- Tunable gameplay constants. Everything balance-related lives here.

local Config = {
	StartingCash = 100,
	SlotsPerPlot = 10,
	MaxPlots = 8,

	-- Conveyor
	ConveyorSpeed = 16, -- studs per second along the winding belt (~95s trip)
	SpawnInterval = 3.5, -- seconds between monsters on the belt
	BuyDistance = 14,

	-- Income
	IncomeTick = 1, -- seconds
	SellRefund = 0.5, -- fraction of buy price returned when selling

	-- Stealing
	StealDistance = 12,
	StealHoldDuration = 1.5,
	CarryWalkSpeed = 12,
	CarryTimeout = 60, -- seconds before a carried monster snaps back home
	CatchDistance = 6, -- owner this close to the thief recovers the monster

	-- Base lock
	LockDuration = 60,
	LockCooldown = 30, -- after the lock expires

	-- Game pass perks
	SuperLockDuration = 120,
	SuperLockCooldown = 15,
	SpeedBoostWalkSpeed = 22, -- default Roblox walk speed is 16
	SpeedBoostCarryBonus = 4,

	-- Developer products
	CashSmallSeconds = 5 * 60, -- seconds of current income
	CashSmallMinimum = 5_000,
	CashLargeSeconds = 60 * 60,
	CashLargeMinimum = 100_000,
	LuckyEggMinRarity = 4, -- Rarity.Order: 4 = Epic

	-- Rebirth
	RebirthBaseCost = 1_000_000,
	RebirthCostGrowth = 2.5,
	RebirthIncomeBonus = 0.5, -- +50% income per rebirth

	-- Data
	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 120,
}

return Config
