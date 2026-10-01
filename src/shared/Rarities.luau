--!strict
-- Rarity tiers in ascending order. Weight is the relative chance of a belt
-- spawn rolling this tier; Height is the target model height in studs.

export type Rarity = {
	Name: string,
	Order: number,
	Weight: number,
	Color: Color3,
	Height: number,
}

local list: { Rarity } = {
	{ Name = "Common", Order = 1, Weight = 60, Color = Color3.fromRGB(190, 190, 190), Height = 3 },
	{ Name = "Uncommon", Order = 2, Weight = 25, Color = Color3.fromRGB(85, 200, 90), Height = 3.5 },
	{ Name = "Rare", Order = 3, Weight = 10, Color = Color3.fromRGB(60, 140, 255), Height = 4 },
	{ Name = "Epic", Order = 4, Weight = 3.5, Color = Color3.fromRGB(170, 80, 255), Height = 4.5 },
	{ Name = "Legendary", Order = 5, Weight = 1.2, Color = Color3.fromRGB(255, 180, 30), Height = 5 },
	{ Name = "Mythic", Order = 6, Weight = 0.25, Color = Color3.fromRGB(255, 60, 90), Height = 5.5 },
	{ Name = "Secret", Order = 7, Weight = 0.05, Color = Color3.fromRGB(20, 20, 20), Height = 6 },
}

local byName: { [string]: Rarity } = {}
for _, rarity in list do
	byName[rarity.Name] = rarity
end

return {
	List = list,
	ByName = byName,
}
