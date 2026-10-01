--!strict
-- Game Passes and Developer Products. Create each one in Creator Hub
-- (Monetization > Passes / Developer Products), then paste its id here.
-- Items with Id = 0 show as "Coming soon" in the shop and can't be bought.

export type Item = {
	Key: string,
	Id: number,
	Name: string,
	Description: string,
	SuggestedPrice: number, -- Robux, used only as a hint in docs
}

local GamePasses: { Item } = {
	{
		Key = "DoubleCash",
		Id = 0,
		Name = "2x Cash",
		Description = "All your monsters earn double cash, forever.",
		SuggestedPrice = 199,
	},
	{
		Key = "SuperLock",
		Id = 0,
		Name = "Super Lock",
		Description = "Base lock lasts 2 minutes with only a 15s cooldown.",
		SuggestedPrice = 149,
	},
	{
		Key = "SpeedBoost",
		Id = 0,
		Name = "Speed Boost",
		Description = "Run faster, even while carrying a stolen monster.",
		SuggestedPrice = 99,
	},
	{
		Key = "AutoCollect",
		Id = 0,
		Name = "Auto Collect",
		Description = "Income goes straight to your cash, no pad needed.",
		SuggestedPrice = 79,
	},
}

local Products: { Item } = {
	{
		Key = "CashSmall",
		Id = 0,
		Name = "Bag of Cash",
		Description = "5 minutes of income (at least $5K).",
		SuggestedPrice = 25,
	},
	{
		Key = "CashLarge",
		Id = 0,
		Name = "Chest of Cash",
		Description = "1 hour of income (at least $100K).",
		SuggestedPrice = 149,
	},
	{
		Key = "LuckyEgg",
		Id = 0,
		Name = "Lucky Egg",
		Description = "Hatch a random Epic or better monster into your base.",
		SuggestedPrice = 99,
	},
}

local byKey: { [string]: Item } = {}
for _, item in GamePasses do
	byKey[item.Key] = item
end
for _, item in Products do
	byKey[item.Key] = item
end

return {
	GamePasses = GamePasses,
	Products = Products,
	ByKey = byKey,
}
