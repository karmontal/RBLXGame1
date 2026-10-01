--!strict
-- English/Arabic strings. The server never sends finished text: it sends a
-- message { k = key, a = args } and each client renders it in its own
-- language. Arg values may be:
--   number / plain string          -> inserted as is
--   "@some.key"                    -> translated key
--   "@monster:<Id>:<Mutation>"     -> monster name with translated mutation
--   { k = ..., a = ... }           -> nested message
--   { {k=...}, {k=...} }           -> list of messages joined with " + "

export type Msg = { k: string, a: { [string]: any }? }
export type Lang = "en" | "ar"

local Monsters = require(script.Parent.Monsters)

local Strings: { [string]: { [string]: string } } = {
	en = {
		-- generic
		["raw"] = "{text}",
		["money"] = "{amount}",
		-- rarities / mutations
		["rarity.Common"] = "Common",
		["rarity.Uncommon"] = "Uncommon",
		["rarity.Rare"] = "Rare",
		["rarity.Epic"] = "Epic",
		["rarity.Legendary"] = "Legendary",
		["rarity.Mythic"] = "Mythic",
		["rarity.Secret"] = "Secret",
		["mutation.Gold"] = "Gold",
		["mutation.Diamond"] = "Diamond",
		["mutation.Fire"] = "Fire",
		["mutation.Rainbow"] = "Rainbow",
		["monsterName"] = "{mutation} {monster}",
		-- store items
		["item.DoubleCash.name"] = "2x Cash",
		["item.DoubleCash.desc"] = "All your monsters earn double cash, forever.",
		["item.SuperLock.name"] = "Super Lock",
		["item.SuperLock.desc"] = "Base lock lasts 2 minutes with only a 15s cooldown.",
		["item.SpeedBoost.name"] = "Speed Boost",
		["item.SpeedBoost.desc"] = "Run faster, even while carrying a stolen monster.",
		["item.AutoCollect.name"] = "Auto Collect",
		["item.AutoCollect.desc"] = "Income goes straight to your cash, no pad needed.",
		["item.CashSmall.name"] = "Bag of Cash",
		["item.CashSmall.desc"] = "5 minutes of income (at least $5K).",
		["item.CashLarge.name"] = "Chest of Cash",
		["item.CashLarge.desc"] = "1 hour of income (at least $100K).",
		["item.LuckyEgg.name"] = "Lucky Egg",
		["item.LuckyEgg.desc"] = "Hatch a random Epic or better monster into your base.",
		-- world labels & prompts
		["prompt.buy"] = "Buy {amount}",
		["prompt.sell"] = "Sell {amount}",
		["prompt.steal"] = "Steal",
		["prompt.lock"] = "Lock Base",
		["prompt.rebirth"] = "Rebirth",
		["label.collect"] = "Collect {amount}",
		["label.autoCollect"] = "Auto Collect ✓",
		["label.lockActive"] = "🔒 {seconds}s",
		["label.lockReady"] = "Ready in {seconds}s",
		["label.lockIdle"] = "🔓 Lock",
		["label.rebirthCost"] = "Rebirth: {amount}",
		["label.base"] = "{player}'s Base",
		["label.emptyBase"] = "Empty Base",
		["label.machine"] = "🥚 MONSTER MACHINE",
		["label.income"] = "{income}/s",
		["label.priceIncome"] = "{price}  •  {income}/s",
		-- notifications
		["n.passUnlocked"] = "Thanks! {pass} unlocked!",
		["n.cashThanks"] = "+{amount}! Thanks for the support!",
		["n.eggHatched"] = "🥚 Lucky Egg hatched a {monster}!",
		["n.eggFull"] = "Base full! Got {amount} for your {monster} instead.",
		["n.baseFullSell"] = "Your base is full! Sell a monster first.",
		["n.baseFull"] = "Your base is full!",
		["n.notEnough"] = "Not enough cash! Need {amount}",
		["n.bought"] = "You bought {monster}!",
		["n.beltRare"] = "A {rarity} {monster} appeared on the belt!",
		["n.stole"] = "You stole {monster}!",
		["n.stolenFrom"] = "{player} stole your {monster}!",
		["n.dropped"] = "You dropped it!",
		["n.tooSlow"] = "Too slow! It ran home.",
		["n.caught"] = "Caught by {player}!",
		["n.recovered"] = "You got your {monster} back!",
		["n.runHome"] = "Run back to your base!",
		["n.beingStolen"] = "{player} is stealing your {monster}! Catch them!",
		["n.sold"] = "Sold {monster}",
		["n.collected"] = "+{amount}",
		["n.lockWait"] = "Lock ready in {seconds}s",
		["n.locked"] = "Base locked!",
		["n.rebirthNeed"] = "Rebirth needs {amount}",
		["n.rebirthStealing"] = "Can't rebirth while a monster is being stolen!",
		["n.rebirthDone"] = "REBIRTH! Income x{mult}",
		["n.adminGranted"] = "You are now an ADMIN! Open the 🛡️ panel.",
		["n.adminRemoved"] = "Your admin role was removed.",
		["n.adminCash"] = "An admin gave you {amount}!",
		["n.adminGift"] = "An admin gave you {thing}!",
		["n.announce"] = "📢 {player}: {text}",
		["n.perkEnded"] = "{pass} has ended. Get it forever in the Shop!",
		-- codes
		["code.redeemed"] = "Code redeemed: {rewards}!",
		["code.unavailable"] = "Codes are unavailable right now, try again later.",
		["code.claimed"] = "This code has been fully claimed!",
		["code.enter"] = "Enter a code.",
		["code.invalid"] = "Invalid code.",
		["code.loading"] = "Still loading, try again in a moment.",
		["code.used"] = "You already used this code.",
		["code.expired"] = "This code has expired.",
		["code.slow"] = "Slow down a little!",
		["code.error"] = "Something went wrong, try again.",
		["code.noServer"] = "Couldn't reach the server, try again.",
		["reward.eggs"] = "{count}x Lucky Egg",
		["reward.passHours"] = "{pass} ({hours}h)",
		-- admin results
		["a.noPermission"] = "You don't have permission.",
		["a.typeCommand"] = "Type a command, e.g. :help",
		["a.slow"] = "Slow down a little.",
		["a.unknown"] = "Unknown command '{name}'. Type :help",
		["a.ownerOnly"] = "Only the owner can use :{name}",
		["a.failed"] = "Command failed: {error}",
		["a.notFound"] = "Player not found (they must be in this server).",
		["a.saveFailed"] = "Couldn't save the admin list, try again.",
		["a.nowAdmin"] = "{player} is now an admin.",
		["a.removedAdmin"] = "Removed admin from {player}.",
		["a.list"] = "Admins: {list}",
		["a.noAdmins"] = "No admins yet.",
		["a.usage"] = "Usage: {usage}",
		["a.cashDone"] = "Gave {amount} to {players}",
		["a.passDone"] = "Gave {pass} to {players}",
		["a.passRemoved"] = "Removed {pass} from {players} (purchased passes are kept).",
		["a.monsterDone"] = "Gave {monster} to {players}",
		["a.baseFull"] = "Their base is full.",
		["a.eggDone"] = "Gave {count} Lucky Egg(s) to {players}",
		["a.spawned"] = "Spawned {monster} on the belt.",
		["a.announced"] = "Announcement sent.",
		["a.unlocked"] = "Unlocked {players}",
		["a.speedDone"] = "Set speed {speed} for {players}",
		["a.tpDone"] = "Teleported to {player}",
		["a.brought"] = "Brought {players}",
		["a.cantKick"] = "You can't kick that player.",
		["a.kicked"] = "Kicked {player}",
		["a.kickReason"] = "Kicked by an admin.",
		-- UI
		["ui.perSec"] = "{amount} / sec",
		["ui.rebirths"] = "⟳ {count}",
		["ui.carrying"] = "Carrying {monster} — run to your base!",
		["ui.shop"] = "SHOP",
		["ui.passes"] = "Game Passes",
		["ui.boosts"] = "Boosts",
		["ui.soon"] = "Soon",
		["ui.owned"] = "Owned ✓",
		["ui.buy"] = "Buy",
		["ui.codes"] = "CODES",
		["ui.redeemTitle"] = "REDEEM CODE",
		["ui.codePlaceholder"] = "Enter code...",
		["ui.redeem"] = "REDEEM",
		["ui.admin"] = "ADMIN",
		["ui.tabPlayers"] = "Players",
		["ui.tabMonsters"] = "Monsters",
		["ui.tabServer"] = "Server",
		["ui.everyone"] = "Everyone",
		["ui.selected"] = "Target: {name}",
		["ui.cash"] = "Cash",
		["ui.passPerks"] = "Pass perks",
		["ui.duration"] = "Duration",
		["ui.hour1"] = "1 hour",
		["ui.hour24"] = "24 hours",
		["ui.forever"] = "Forever",
		["ui.removePerks"] = "Remove free perks",
		["ui.luckyEgg"] = "Lucky Egg",
		["ui.unlockBase"] = "Unlock base",
		["ui.fast"] = "Fast (32)",
		["ui.normalSpeed"] = "Normal speed",
		["ui.teleport"] = "Go to",
		["ui.bring"] = "Bring",
		["ui.kick"] = "Kick",
		["ui.makeAdmin"] = "Make admin",
		["ui.removeAdmin"] = "Remove admin",
		["ui.players"] = "Players",
		["ui.actions"] = "Actions",
		["ui.mutation"] = "Mutation",
		["ui.none"] = "None",
		["ui.giveToTarget"] = "Give to target",
		["ui.spawnOnBelt"] = "Spawn on belt",
		["ui.announcement"] = "Announcement",
		["ui.announcePlaceholder"] = "Message to everyone...",
		["ui.send"] = "Send",
		["ui.listAdmins"] = "List admins",
		["ui.console"] = "Command (advanced)",
		["ui.run"] = "Run",
		["ui.consolePlaceholder"] = ":help   ·   :givecash me 1000",
		["ui.pickPlayer"] = "Pick a player first.",
		["ui.pickMonster"] = "Pick a monster first.",
	},
	ar = {
		["raw"] = "{text}",
		["money"] = "{amount}",
		["rarity.Common"] = "شائع",
		["rarity.Uncommon"] = "غير شائع",
		["rarity.Rare"] = "نادر",
		["rarity.Epic"] = "ملحمي",
		["rarity.Legendary"] = "أسطوري",
		["rarity.Mythic"] = "خرافي",
		["rarity.Secret"] = "سرّي",
		["mutation.Gold"] = "ذهبي",
		["mutation.Diamond"] = "ماسي",
		["mutation.Fire"] = "ناري",
		["mutation.Rainbow"] = "قوس قزح",
		["monsterName"] = "{monster} {mutation}",
		["item.DoubleCash.name"] = "مال مضاعف",
		["item.DoubleCash.desc"] = "كل وحوشك تربح ضعف المال، للأبد.",
		["item.SuperLock.name"] = "قفل خارق",
		["item.SuperLock.desc"] = "القفل يدوم دقيقتين وانتظار 15 ثانية فقط.",
		["item.SpeedBoost.name"] = "سرعة إضافية",
		["item.SpeedBoost.desc"] = "اركض أسرع، حتى وأنت تحمل وحشًا مسروقًا.",
		["item.AutoCollect.name"] = "جمع تلقائي",
		["item.AutoCollect.desc"] = "الدخل يذهب لمالك مباشرة، بدون المربع.",
		["item.CashSmall.name"] = "كيس مال",
		["item.CashSmall.desc"] = "دخل 5 دقائق (على الأقل $5K).",
		["item.CashLarge.name"] = "صندوق مال",
		["item.CashLarge.desc"] = "دخل ساعة كاملة (على الأقل $100K).",
		["item.LuckyEgg.name"] = "بيضة الحظ",
		["item.LuckyEgg.desc"] = "تفقس وحشًا ملحميًا أو أندر في قاعدتك.",
		["prompt.buy"] = "شراء {amount}",
		["prompt.sell"] = "بيع {amount}",
		["prompt.steal"] = "سرقة",
		["prompt.lock"] = "قفل القاعدة",
		["prompt.rebirth"] = "إعادة الميلاد",
		["label.collect"] = "اجمع {amount}",
		["label.autoCollect"] = "جمع تلقائي ✓",
		["label.lockActive"] = "🔒 {seconds} ث",
		["label.lockReady"] = "جاهز بعد {seconds} ث",
		["label.lockIdle"] = "🔓 قفل",
		["label.rebirthCost"] = "إعادة الميلاد: {amount}",
		["label.base"] = "قاعدة {player}",
		["label.emptyBase"] = "قاعدة فارغة",
		["label.machine"] = "🥚 آلة الوحوش",
		["label.income"] = "{income}/ث",
		["label.priceIncome"] = "{price}  •  {income}/ث",
		["n.passUnlocked"] = "شكرًا! تم فتح {pass}!",
		["n.cashThanks"] = "+{amount}! شكرًا على دعمك!",
		["n.eggHatched"] = "🥚 بيضة الحظ فقست {monster}!",
		["n.eggFull"] = "قاعدتك ممتلئة! حصلت على {amount} بدل {monster}.",
		["n.baseFullSell"] = "قاعدتك ممتلئة! بِع وحشًا أولًا.",
		["n.baseFull"] = "قاعدتك ممتلئة!",
		["n.notEnough"] = "مالك لا يكفي! تحتاج {amount}",
		["n.bought"] = "اشتريت {monster}!",
		["n.beltRare"] = "ظهر {monster} ({rarity}) على الحزام!",
		["n.stole"] = "سرقت {monster}!",
		["n.stolenFrom"] = "{player} سرق {monster} منك!",
		["n.dropped"] = "أوقعته!",
		["n.tooSlow"] = "تأخرت! هرب إلى قاعدته.",
		["n.caught"] = "أمسك بك {player}!",
		["n.recovered"] = "استرجعت {monster}!",
		["n.runHome"] = "اركض إلى قاعدتك!",
		["n.beingStolen"] = "{player} يسرق {monster}! امسكه!",
		["n.sold"] = "بعت {monster}",
		["n.collected"] = "+{amount}",
		["n.lockWait"] = "القفل جاهز بعد {seconds} ث",
		["n.locked"] = "تم قفل القاعدة!",
		["n.rebirthNeed"] = "إعادة الميلاد تحتاج {amount}",
		["n.rebirthStealing"] = "لا يمكن إعادة الميلاد أثناء سرقة وحش!",
		["n.rebirthDone"] = "إعادة ميلاد! الدخل ×{mult}",
		["n.adminGranted"] = "أصبحت أدمن! افتح لوحة 🛡️.",
		["n.adminRemoved"] = "تمت إزالة صلاحية الأدمن منك.",
		["n.adminCash"] = "الأدمن أعطاك {amount}!",
		["n.adminGift"] = "الأدمن أعطاك {thing}!",
		["n.announce"] = "📢 {player}: {text}",
		["n.perkEnded"] = "انتهت مدة {pass}. اشترِه للأبد من المتجر!",
		["code.redeemed"] = "تم تفعيل الكود: {rewards}!",
		["code.unavailable"] = "الأكواد غير متاحة الآن، حاول لاحقًا.",
		["code.claimed"] = "هذا الكود انتهت استخداماته!",
		["code.enter"] = "اكتب كودًا.",
		["code.invalid"] = "كود غير صحيح.",
		["code.loading"] = "ما زال التحميل جاريًا، حاول بعد قليل.",
		["code.used"] = "استخدمت هذا الكود من قبل.",
		["code.expired"] = "انتهت صلاحية هذا الكود.",
		["code.slow"] = "على مهلك!",
		["code.error"] = "حدث خطأ، حاول مجددًا.",
		["code.noServer"] = "تعذر الاتصال بالسيرفر، حاول مجددًا.",
		["reward.eggs"] = "{count}× بيضة حظ",
		["reward.passHours"] = "{pass} ({hours} ساعة)",
		["a.noPermission"] = "ليس لديك صلاحية.",
		["a.typeCommand"] = "اكتب أمرًا، مثل :help",
		["a.slow"] = "على مهلك.",
		["a.unknown"] = "أمر غير معروف '{name}'. اكتب :help",
		["a.ownerOnly"] = "فقط المالك يستطيع استخدام :{name}",
		["a.failed"] = "فشل الأمر: {error}",
		["a.notFound"] = "اللاعب غير موجود (يجب أن يكون في نفس السيرفر).",
		["a.saveFailed"] = "تعذر حفظ قائمة الأدمن، حاول مجددًا.",
		["a.nowAdmin"] = "{player} أصبح أدمن.",
		["a.removedAdmin"] = "تمت إزالة الأدمن من {player}.",
		["a.list"] = "الأدمن: {list}",
		["a.noAdmins"] = "لا يوجد أدمن بعد.",
		["a.usage"] = "الاستخدام: {usage}",
		["a.cashDone"] = "أعطيت {amount} لـ {players}",
		["a.passDone"] = "أعطيت {pass} لـ {players}",
		["a.passRemoved"] = "أزلت {pass} من {players} (الباسات المشتراة تبقى).",
		["a.monsterDone"] = "أعطيت {monster} لـ {players}",
		["a.baseFull"] = "قاعدته ممتلئة.",
		["a.eggDone"] = "أعطيت {count} بيضة حظ لـ {players}",
		["a.spawned"] = "نزل {monster} على الحزام.",
		["a.announced"] = "تم إرسال الإعلان.",
		["a.unlocked"] = "فُكّ قفل {players}",
		["a.speedDone"] = "السرعة {speed} لـ {players}",
		["a.tpDone"] = "انتقلت إلى {player}",
		["a.brought"] = "جلبت {players}",
		["a.cantKick"] = "لا يمكنك طرد هذا اللاعب.",
		["a.kicked"] = "طردت {player}",
		["a.kickReason"] = "طُردت من قبل الأدمن.",
		["ui.perSec"] = "{amount} / ث",
		["ui.rebirths"] = "⟳ {count}",
		["ui.carrying"] = "تحمل {monster} — اركض لقاعدتك!",
		["ui.shop"] = "المتجر",
		["ui.passes"] = "الباسات",
		["ui.boosts"] = "التعزيزات",
		["ui.soon"] = "قريبًا",
		["ui.owned"] = "مملوك ✓",
		["ui.buy"] = "شراء",
		["ui.codes"] = "أكواد",
		["ui.redeemTitle"] = "تفعيل كود",
		["ui.codePlaceholder"] = "اكتب الكود...",
		["ui.redeem"] = "تفعيل",
		["ui.admin"] = "أدمن",
		["ui.tabPlayers"] = "اللاعبين",
		["ui.tabMonsters"] = "الوحوش",
		["ui.tabServer"] = "السيرفر",
		["ui.everyone"] = "الكل",
		["ui.selected"] = "الهدف: {name}",
		["ui.cash"] = "المال",
		["ui.passPerks"] = "ميزات الباسات",
		["ui.duration"] = "المدة",
		["ui.hour1"] = "ساعة",
		["ui.hour24"] = "24 ساعة",
		["ui.forever"] = "للأبد",
		["ui.removePerks"] = "إزالة الميزات المجانية",
		["ui.luckyEgg"] = "بيضة حظ",
		["ui.unlockBase"] = "فك قفل القاعدة",
		["ui.fast"] = "سريع (32)",
		["ui.normalSpeed"] = "سرعة عادية",
		["ui.teleport"] = "انتقل إليه",
		["ui.bring"] = "اجلبه",
		["ui.kick"] = "طرد",
		["ui.makeAdmin"] = "اجعله أدمن",
		["ui.removeAdmin"] = "أزل الأدمن",
		["ui.players"] = "اللاعبين",
		["ui.actions"] = "الأوامر",
		["ui.mutation"] = "الطفرة",
		["ui.none"] = "بدون",
		["ui.giveToTarget"] = "أعطِ للهدف",
		["ui.spawnOnBelt"] = "أنزل على الحزام",
		["ui.announcement"] = "إعلان",
		["ui.announcePlaceholder"] = "رسالة للجميع...",
		["ui.send"] = "إرسال",
		["ui.listAdmins"] = "قائمة الأدمن",
		["ui.console"] = "أمر كتابي (متقدم)",
		["ui.run"] = "تنفيذ",
		["ui.consolePlaceholder"] = ":help   ·   :givecash me 1000",
		["ui.pickPlayer"] = "اختر لاعبًا أولًا.",
		["ui.pickMonster"] = "اختر وحشًا أولًا.",
	},
}

local Locale = {}

Locale.Languages = { "en", "ar" } :: { Lang }

local render: (lang: string, msg: any) -> string

local function renderValue(lang: string, value: any): string
	local kind = type(value)
	if kind == "number" then
		return tostring(value)
	elseif kind == "string" then
		if string.sub(value, 1, 9) == "@monster:" then
			local id, mutation = string.match(value, "^@monster:([^:]+):?(.*)$")
			local mutationText = if mutation and mutation ~= "" and mutation ~= "None"
				then render(lang, { k = "mutation." .. mutation })
				else ""
			local monster = Monsters.ById[id]
			local name = if monster then monster.DisplayName else id
			local text = render(lang, { k = "monsterName", a = { monster = name, mutation = mutationText } })
			local trimmed = string.gsub(text, "^%s+", "")
			return (string.gsub(trimmed, "%s+$", ""))
		elseif string.sub(value, 1, 1) == "@" then
			return render(lang, { k = string.sub(value, 2) })
		end
		return value
	elseif kind == "table" then
		if value.k then
			return render(lang, value)
		end
		local parts = {}
		for _, part in value do
			table.insert(parts, renderValue(lang, part))
		end
		return table.concat(parts, " + ")
	end
	return tostring(value)
end

render = function(lang: string, msg: any): string
	if type(msg) == "string" then
		return msg
	end
	if type(msg) ~= "table" or type(msg.k) ~= "string" then
		return ""
	end
	local template = (Strings[lang] and Strings[lang][msg.k]) or Strings.en[msg.k] or msg.k
	local args = msg.a
	if type(args) ~= "table" then
		return template
	end
	return (string.gsub(template, "{(%w+)}", function(name)
		local value = args[name]
		if value == nil then
			return ""
		end
		return renderValue(lang, value)
	end))
end

-- Renders a message (or a plain string) in the given language.
function Locale.Render(lang: string, msg: any): string
	return render(lang, msg)
end

-- Shortcut for a key with optional args.
function Locale.T(lang: string, key: string, args: { [string]: any }?): string
	return render(lang, { k = key, a = args })
end

-- True if a translation exists for key (used for optional item texts).
function Locale.Has(lang: string, key: string): boolean
	return Strings[lang] ~= nil and Strings[lang][key] ~= nil
end

function Locale.Msg(key: string, args: { [string]: any }?): Msg
	return { k = key, a = args }
end

return Locale
