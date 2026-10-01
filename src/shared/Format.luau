--!strict
-- Short money formatting: 1234 -> "1.23K", 5600000 -> "5.6M".

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }

local function money(value: number): string
	local negative = value < 0
	value = math.abs(value)
	local index = 1
	while value >= 1000 and index < #suffixes do
		value /= 1000
		index += 1
	end
	local text
	if index == 1 then
		text = tostring(math.floor(value))
	else
		text = string.format("%.2f", value):gsub("%.?0+$", "") .. suffixes[index]
	end
	return (negative and "-$" or "$") .. text
end

return {
	Money = money,
}
