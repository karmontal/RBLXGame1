--!strict
-- Mutations multiply a monster's price and income. Chance is per belt spawn,
-- checked from rarest to most common; "None" is the fallback.

export type Mutation = {
	Name: string,
	Multiplier: number,
	Chance: number,
	Color: Color3?,
}

local list: { Mutation } = {
	{ Name = "Rainbow", Multiplier = 10, Chance = 0.002, Color = Color3.fromRGB(255, 255, 255) },
	{ Name = "Fire", Multiplier = 4, Chance = 0.01, Color = Color3.fromRGB(255, 110, 20) },
	{ Name = "Diamond", Multiplier = 3, Chance = 0.025, Color = Color3.fromRGB(120, 230, 255) },
	{ Name = "Gold", Multiplier = 2, Chance = 0.06, Color = Color3.fromRGB(255, 210, 50) },
}

local none: Mutation = { Name = "None", Multiplier = 1, Chance = 0 }

local byName: { [string]: Mutation } = { None = none }
for _, mutation in list do
	byName[mutation.Name] = mutation
end

local function roll(rng: Random): Mutation
	for _, mutation in list do
		if rng:NextNumber() < mutation.Chance then
			return mutation
		end
	end
	return none
end

return {
	List = list,
	ByName = byName,
	None = none,
	Roll = roll,
}
