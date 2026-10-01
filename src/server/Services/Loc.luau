--!strict
-- Server side of localization: world labels and prompts carry a message as
-- JSON attributes ("LocText" / "LocAction") that each client renders in its
-- own language (see client Lang.luau). Nothing here sends finished text.

local HttpService = game:GetService("HttpService")

local Loc = {}

local function set(instance: Instance, attribute: string, key: string, args: { [string]: any }?)
	local encoded = HttpService:JSONEncode({ k = key, a = args })
	if instance:GetAttribute(attribute) ~= encoded then
		instance:SetAttribute(attribute, encoded)
	end
end

-- A TextLabel whose text is rendered client-side.
function Loc.Label(label: TextLabel, key: string, args: { [string]: any }?)
	set(label, "LocText", key, args)
end

-- A ProximityPrompt whose ActionText is rendered client-side.
function Loc.Prompt(prompt: ProximityPrompt, key: string, args: { [string]: any }?)
	set(prompt, "LocAction", key, args)
end

function Loc.Clear(label: TextLabel)
	label:SetAttribute("LocText", nil)
	label.Text = ""
end

return Loc
