-- Module « La bonne récompense » (v1.24.0) : conseil au rendu d'une quête
-- (meilleur choix selon la spé, armures/armes mal portées, anneaux/bijoux,
-- repli « la plus chère », chat sans bouton, infobulle, module coupé, sans
-- GetItemStats).
local Check, ResetWorld, NS, Mock = T.Check, T.ResetWorld, T.NS, T.Mock

-- Globales du client absentes du harnais : posées ici, restaurées en fin de fichier
local saved = {
	GetNumQuestChoices = rawget(_G, "GetNumQuestChoices"),
	GetQuestItemLink = rawget(_G, "GetQuestItemLink"),
	GetQuestItemInfo = rawget(_G, "GetQuestItemInfo"),
	GetItemInfo = rawget(_G, "GetItemInfo"),
	GetItemStats = rawget(_G, "GetItemStats"),
	hooksecurefunc = rawget(_G, "hooksecurefunc"),
	QuestInfoRewardsFrame = rawget(_G, "QuestInfoRewardsFrame"),
	QuestFrameRewardPanel = rawget(_G, "QuestFrameRewardPanel"),
	cGetItemInfo = C_Item.GetItemInfo,
	cGetItemStats = C_Item.GetItemStats,
	SetQuestItem = GameTooltip.SetQuestItem,
	hooked = NS.rewardTooltipHooked,
}

-- GetItemInfo complet : prix de vente (11e), classe et sous-classe (12e, 13e)
local function FullItemInfo(link)
	local d = Mock.world.links and Mock.world.links[link]
	if not d then return nil end
	return d.name, link, d.quality or 2, d.itemLevel or 10, 1, "Armure", "", 1, d.equipLoc, nil,
		d.sellPrice or 0, d.classID or 4, d.subClassID
end
C_Item.GetItemInfo = FullItemInfo
-- le cœur des tests peut avoir retiré l'API (scénarios de repli) : on pose la nôtre
local function MockItemStats(link)
	local d = Mock.world.links and Mock.world.links[link]
	return d and d.stats
end
C_Item.GetItemStats = MockItemStats
_G.GetItemInfo = FullItemInfo
_G.GetNumQuestChoices = function() return #(Mock.world.rewardChoices or {}) end
_G.GetQuestItemLink = function(_, index) return (Mock.world.rewardChoices or {})[index] end
_G.GetQuestItemInfo = function(_, index)
	local link = (Mock.world.rewardChoices or {})[index]
	local d = link and Mock.world.links[link] or {}
	return d.name, nil, 1, d.quality, d.usable ~= false
end
-- hooksecurefunc(table, "méthode", fn) : appelle fn après l'original
_G.hooksecurefunc = function(target, name, fn)
	if type(target) == "string" then return end
	local original = target[name]
	target[name] = function(...) original(...); fn(...) end
end
GameTooltip.SetQuestItem = function(self) self.lines = {} end
NS.rewardTooltipHooked = nil
_G.QuestFrameRewardPanel = CreateFrame("Frame", "QuestFrameRewardPanel")

local R = {}   -- une seule locale pour les aides (limite de 200 locales)

function R.Has(text, needle) return tostring(text):find(needle, 1, true) ~= nil end

-- Boutons de récompense, nommés comme sur Classic Era
function R.Buttons(count, pattern)
	R.buttons = {}
	for i = 1, count do
		local name = string.format(pattern or "QuestInfoRewardsFrameQuestInfoItem%d", i)
		local button = CreateFrame("Button", name)
		_G[name] = button
		R.buttons[i] = button
	end
end

function R.ClearButtons()
	for _, pattern in ipairs({ "QuestInfoRewardsFrameQuestInfoItem%d", "QuestInfoItem%d", "QuestRewardItem%d" }) do
		for i = 1, 6 do _G[string.format(pattern, i)] = nil end
	end
	_G.QuestInfoRewardsFrame = nil
	R.buttons = {}
end

function R.Reset(classToken, specIndex)
	ResetWorld()
	NS:RewardOnFinished()
	R.ClearButtons()
	local db = NS:DB()
	db.rewardEnabled, db.rewardTooltip, db.rewardSellBest = true, true, true
	Mock.world.classToken = classToken or "WARRIOR"
	Mock.world.specIndex = specIndex or 1
	Mock.world.level = 20
	Mock.world.rewardChoices = {}
	QuestFrameRewardPanel:Show()
	Mock:Reset()
end

-- Un objet : lien + données (stats en clés de GetItemStats)
function R.Item(id, name, data)
	local link = "|cff1eff00|Hitem:" .. id .. "::::::::|h[" .. name .. "]|h|r"
	data.name = name
	Mock.world.links[link] = data
	return link
end

function R.Offer(...)
	Mock.world.rewardChoices = { ... }
	Mock:Fire("QUEST_COMPLETE")
end

function R.RunTimers()
	local timers = Mock.world.timers or {}
	Mock.world.timers = {}
	for _, fn in ipairs(timers) do fn() end
end

function R.Label(index)
	local button = R.buttons[index]
	local mark = button and button.r2qRewardMark
	if mark and mark.label.shown then return mark.label.text end
	return nil
end

function R.Marked()
	local list = {}
	for i, button in ipairs(R.buttons) do
		if button.r2qRewardMark and button.r2qRewardMark.glow.shown then list[#list + 1] = i end
	end
	return table.concat(list, ",")
end

function R.Best()
	local result = NS.rewardState and NS.rewardState.result
	return result and result.best and result.best.index, result and result.mode
end

function R.Tooltip(index)
	GameTooltip:SetQuestItem("choice", index)
	return table.concat(GameTooltip.lines or {}, " | ")
end

-- Le trio habituel : cuir Force, tissu Intelligence, maille Endurance
function R.Trio()
	return R.Item(9001, "Cuirasse du lutteur", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 2,
			stats = { ITEM_MOD_STRENGTH_SHORT = 5 }, sellPrice = 400 }),
		R.Item(9002, "Robe de l'érudit", { equipLoc = "INVTYPE_ROBE", classID = 4, subClassID = 1,
			stats = { ITEM_MOD_INTELLECT_SHORT = 8 }, sellPrice = 300 }),
		R.Item(9003, "Haubert du garde", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 3,
			stats = { ITEM_MOD_STAMINA_SHORT = 6 }, sellPrice = 500 })
end

-- 1. Chaînes, réglages, module -------------------------------------------------
do
	local strings = NS.REWARD_STRINGS
	local missing = {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" then missing[#missing + 1] = "en:" .. key end
		if value == "" or NS.L[key] ~= value then missing[#missing + 1] = "fr:" .. key end
	end
	for key in pairs(strings.en) do
		if strings.fr[key] == nil then missing[#missing + 1] = "fr?" .. key end
	end
	local mismatch = {}
	local function Placeholders(text)
		local list = {}
		for p in tostring(text):gsub("%%%%", ""):gmatch("%%[%d%$]*[sd]") do list[#list + 1] = p end
		return table.concat(list, ",")
	end
	for key, value in pairs(strings.fr) do
		if Placeholders(value) ~= Placeholders(strings.en[key]) then mismatch[#mismatch + 1] = key end
	end
	Check("[RWD] chaînes fr/en, mêmes placeholders, libellés demandés", #missing == 0 and #mismatch == 0
		and strings.fr.REWARD_FOR_YOU == "Pour toi" and strings.en.REWARD_FOR_YOU == "For you",
		table.concat(missing, ", ") .. " / " .. table.concat(mismatch, ", "))

	local page
	for _, def in ipairs(NS.OPTION_PAGES) do if def.id == "reward" then page = def end end
	local keys = {}
	for _, row in ipairs(page and page.rows or {}) do keys[#keys + 1] = row.key .. ":" .. row.kind end
	local db = NS:DB()
	Check("[RWD] sous-page QoL, trois interrupteurs actifs par défaut", page and page.parent == "qol" and page.group == "OPT_GROUP_QOL"
		and table.concat(keys, ",") == "rewardEnabled:bool,rewardTooltip:bool,rewardSellBest:bool"
		and db.rewardEnabled == true and db.rewardTooltip == true and db.rewardSellBest == true, table.concat(keys, ","))
	NS:HandleCommand("module recompense off")
	local off = db.rewardEnabled == false
	NS:HandleCommand("module reward on")
	Check("[RWD] /r2q module recompense off, reward on", off and db.rewardEnabled == true)
end

-- 2. Le meilleur choix selon la spé ---------------------------------------------
do
	R.Reset("WARRIOR", 1)
	R.Buttons(3)
	R.Offer(R.Trio())
	local best, mode = R.Best()
	Check("[RWD] guerrier Armes : la Force (cuir) l'emporte, marquée « Pour toi », pas de chat", best == 1 and mode == "upgrade"
		and R.Label(1) == "Pour toi" and R.Marked() == "1" and not R.Has(Mock:Output(), "Récompense conseillée"),
		tostring(best) .. " " .. tostring(mode))
	R.RunTimers()
	Check("[RWD] second passage : toujours un seul bouton marqué", R.Marked() == "1", R.Marked())

	R.Reset("WARRIOR", 3)
	R.Buttons(3)
	R.Offer(R.Trio())
	local prot = R.Best()
	R.Reset("MAGE", 1)
	R.Buttons(3)
	R.Offer(R.Trio())
	Check("[RWD] guerrier Protection : l'Endurance (maille) ; mage : l'Intelligence (tissu)", prot == 3
		and (R.Best()) == 2 and R.Label(2) == "Pour toi", tostring(prot) .. " " .. tostring((R.Best())))

	-- une seule source de vérité : la priorité vient de ns.SPEC_STATS
	R.Reset("MAGE", 1)
	local order = NS.RewardStatPriority()
	Check("[RWD] priorité = SPEC_STATS du portrait", order == NS.SPEC_STATS.MAGE[1])

	-- un choix déjà battu par l'objet porté n'est pas une amélioration
	R.Reset("WARRIOR", 1)
	R.Buttons(3)
	local trio = { R.Trio() }
	Mock.world.equipped[5] = R.Item(9010, "Plastron porté", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 3,
		stats = { ITEM_MOD_STRENGTH_SHORT = 3 } })
	R.Offer(trio[1], trio[2], trio[3])
	local result = NS.rewardState.result
	Check("[RWD] écart au porté : +5×0,8 - 3 = +1", math.abs(result.choices[1].delta - 1) < 0.01, result.choices[1].delta)
end

-- 3. Armures et armes que la classe porte mal ----------------------------------
do
	R.Reset("MAGE", 1)
	R.Buttons(2)
	local plate = R.Item(9101, "Plaques de l'arcaniste", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 4,
		stats = { ITEM_MOD_INTELLECT_SHORT = 20 } })
	local cloth = R.Item(9102, "Robe simple", { equipLoc = "INVTYPE_ROBE", classID = 4, subClassID = 1,
		stats = { ITEM_MOD_INTELLECT_SHORT = 3 } })
	R.Offer(plate, cloth)
	Check("[RWD] mage : jamais de plaques, même pleines d'Intelligence (« Pas pour toi »)", (R.Best()) == 2
		and R.Has(R.Tooltip(1), "Pas pour toi"), R.Tooltip(1))

	R.Reset("ROGUE", 1)
	R.Buttons(2)
	local shield = R.Item(9103, "Écu agile", { equipLoc = "INVTYPE_SHIELD", classID = 4, subClassID = 6,
		stats = { ITEM_MOD_AGILITY_SHORT = 10 } })
	local dagger = R.Item(9104, "Dague fine", { equipLoc = "INVTYPE_WEAPON", classID = 2, subClassID = 15,
		stats = { ITEM_MOD_AGILITY_SHORT = 2 } })
	R.Offer(shield, dagger)
	local rogue = R.Best()

	R.Reset("PRIEST", 1)
	R.Buttons(2)
	local sword = R.Item(9105, "Épée du sage", { equipLoc = "INVTYPE_WEAPON", classID = 2, subClassID = 7,
		stats = { ITEM_MOD_INTELLECT_SHORT = 9 } })
	local mace = R.Item(9106, "Masse bénie", { equipLoc = "INVTYPE_WEAPON", classID = 2, subClassID = 4,
		stats = { ITEM_MOD_INTELLECT_SHORT = 2 } })
	R.Offer(sword, mace)
	Check("[RWD] voleur : pas de bouclier ; prêtre : pas d'épée (arme non maîtrisée)", rogue == 2 and (R.Best()) == 2,
		tostring(rogue) .. " " .. tostring((R.Best())))

	-- plaques : utilisables par un guerrier dès le niveau 40 seulement
	R.Reset("WARRIOR", 1)
	local plateInfo = { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 4 }
	Check("[RWD] guerrier : plaques dès le niveau 40, tissu à éviter, cape en tissu jamais pénalisée",
		NS.RewardSuitability(plateInfo, "WARRIOR", 20) == 0 and NS.RewardSuitability(plateInfo, "WARRIOR", 40) == 1
		and NS.RewardSuitability({ equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 1 }, "WARRIOR", 40) == 0
		and NS.RewardSuitability({ equipLoc = "INVTYPE_CLOAK", classID = 4, subClassID = 1 }, "WARRIOR", 40) == 1)

	-- le jeu dit lui-même que l'objet est inutilisable (niveau, maîtrise)
	R.Reset("WARRIOR", 1)
	R.Buttons(2)
	local locked = R.Item(9107, "Hache scellée", { equipLoc = "INVTYPE_2HWEAPON", classID = 2, subClassID = 1,
		stats = { ITEM_MOD_STRENGTH_SHORT = 30 }, usable = false })
	local belt = R.Item(9108, "Ceinture", { equipLoc = "INVTYPE_WAIST", classID = 4, subClassID = 3,
		stats = { ITEM_MOD_STRENGTH_SHORT = 1 } })
	R.Offer(locked, belt)
	Check("[RWD] objet signalé inutilisable par le jeu : ignoré", (R.Best()) == 2, tostring((R.Best())))
end

-- 4. Anneaux et bijoux : comparés au plus faible des deux -----------------------
do
	R.Reset("WARRIOR", 1)
	R.Buttons(2)
	Mock.world.equipped[11] = R.Item(9201, "Anneau fort", { equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0,
		stats = { ITEM_MOD_STRENGTH_SHORT = 10 } })
	Mock.world.equipped[12] = R.Item(9202, "Anneau faible", { equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0,
		stats = { ITEM_MOD_STRENGTH_SHORT = 2 } })
	local ring = R.Item(9203, "Anneau moyen", { equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0,
		stats = { ITEM_MOD_STRENGTH_SHORT = 5 }, sellPrice = 50 })
	local cloak = R.Item(9204, "Cape", { equipLoc = "INVTYPE_CLOAK", classID = 4, subClassID = 1,
		stats = { ITEM_MOD_SPIRIT_SHORT = 5 }, sellPrice = 900 })
	R.Offer(ring, cloak)
	local result = NS.rewardState.result
	Check("[RWD] anneau +5 comparé à l'anneau faible (+2, emplacement 12) : conseillé, écart en infobulle",
		result.choices[1].replaced.slot == 12 and (R.Best()) == 1 and R.Label(1) == "Pour toi"
		and R.Has(R.Tooltip(1), "Par rapport au porté : +3 Force"), R.Tooltip(1))
	Check("[RWD] infobulle : Esprit inutile au guerrier", R.Has(R.Tooltip(2), "Pas mieux que ton équipement"), R.Tooltip(2))

	R.Reset("WARRIOR", 1)
	Mock.world.equipped[13] = R.Item(9205, "Bijou A", { equipLoc = "INVTYPE_TRINKET", stats = { ITEM_MOD_STRENGTH_SHORT = 4 } })
	local trinket = R.Item(9206, "Bijou B", { equipLoc = "INVTYPE_TRINKET", stats = { ITEM_MOD_STRENGTH_SHORT = 1 } })
	local other = R.Item(9207, "Bijou C", { equipLoc = "INVTYPE_TRINKET", stats = {} })
	R.Buttons(2)
	R.Offer(trinket, other)
	Check("[RWD] bijou : emplacement 14 vide = le plus faible", (R.Best()) == 1 and NS.rewardState.result.choices[1].replaced.slot == 14)

	-- un seul objet : donné d'office, rien à conseiller (ni bouton ni chat)
	Mock:Fire("QUEST_FINISHED")
	R.Offer(trinket)
	R.RunTimers()
	Check("[RWD] un seul choix : rien n'est marqué", R.Marked() == "" and not R.Has(Mock:Output(), "Récompense conseillée"), R.Marked())
end

-- 5. Rien de mieux : la plus chère, à vendre ------------------------------------
do
	R.Reset("WARRIOR", 1)
	R.Buttons(3)
	Mock.world.equipped[5] = R.Item(9301, "Plastron d'élite", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 3,
		stats = { ITEM_MOD_STRENGTH_SHORT = 30 } })
	local a = R.Item(9302, "Plastron A", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 3,
		stats = { ITEM_MOD_STRENGTH_SHORT = 4 }, sellPrice = 500 })
	local b = R.Item(9303, "Plastron B", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 3,
		stats = { ITEM_MOD_STRENGTH_SHORT = 2 }, sellPrice = 12000 })
	local c = R.Item(9304, "Plastron C", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 3,
		stats = {}, sellPrice = 300 })
	R.Offer(a, b, c)
	local best, mode = R.Best()
	Check("[RWD] aucune amélioration : la plus chère, « À vendre : 1 po 20 pa »", best == 2 and mode == "sell"
		and R.Label(2) == "À vendre : 1 po 20 pa", tostring(best) .. " " .. tostring(R.Label(2)))

	NS:DB().rewardSellBest = false
	Mock:Fire("QUEST_FINISHED")
	R.Offer(a, b, c)
	Check("[RWD] repli coupé : aucun bouton marqué", R.Marked() == "" and (R.Best()) == nil, R.Marked())
end

-- 6. Pas de bouton trouvé : une ligne dans le chat ------------------------------
do
	R.Reset("WARRIOR", 1)
	local trio = { R.Trio() }
	R.Offer(trio[1], trio[2], trio[3])
	local early = R.Has(Mock:Output(), "Récompense conseillée")
	R.RunTimers()
	local out = Mock:Output()
	Mock:Fire("QUEST_ITEM_UPDATE")
	local _, count = Mock:Output():gsub("Récompense conseillée", "")
	Check("[RWD] chat au second passage seulement : « Récompense conseillée : [lien] (pourquoi) », une ligne par rendu",
		not early and R.Has(out, "Récompense conseillée : " .. trio[1] .. " (+5 Force)") and count == 1, out)

	R.Reset("WARRIOR", 1)
	Mock.world.equipped[5] = R.Item(9305, "Plastron d'élite", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 3,
		stats = { ITEM_MOD_STRENGTH_SHORT = 30 } })
	R.Offer(R.Trio())
	R.RunTimers()
	Check("[RWD] chat : raison de la vente", R.Has(Mock:Output(), "rien ne t'améliore, elle vaut 5 pa"), Mock:Output())

	-- noms de boutons : table RewardButtons, puis l'interface 1.12 d'origine
	R.Reset("MAGE", 1)
	local rewards = CreateFrame("Frame", "QuestInfoRewardsFrame")
	_G.QuestInfoRewardsFrame = rewards
	rewards.RewardButtons = {}
	for i = 1, 3 do
		local button = CreateFrame("Button")
		button.type, button.GetID = (i == 1) and "reward" or "choice", function() return i == 1 and 1 or i - 1 end
		rewards.RewardButtons[i] = button
	end
	Check("[RWD] RewardButtons : choix 1 = bouton de type choice", NS:RewardButton(1) == rewards.RewardButtons[2])
	R.ClearButtons()
	R.Buttons(3, "QuestRewardItem%d")
	R.Offer(R.Trio())
	Check("[RWD] noms d'origine QuestRewardItem<i>", R.Label(2) == "Pour toi", R.Marked())
end

-- 7. Infobulle -------------------------------------------------------------------
do
	R.Reset("WARRIOR", 1)
	R.Buttons(3)
	R.Offer(R.Trio())
	Check("[RWD] accroche sur SetQuestItem : +5 Force au conseillé, tissu pas pour un guerrier", NS.rewardTooltipHooked == "SetQuestItem"
		and R.Has(R.Tooltip(1), "Par rapport au porté : +5 Force") and R.Has(R.Tooltip(2), "Pas pour toi"), R.Tooltip(1))
	NS:DB().rewardTooltip = false
	local off = R.Tooltip(1)
	NS:DB().rewardTooltip = true
	QuestFrameRewardPanel:Hide()
	Check("[RWD] infobulle coupée ou panneau fermé : pas de ligne", off == "" and R.Tooltip(1) == "", R.Tooltip(1))
	QuestFrameRewardPanel:Show()
	Mock:Fire("QUEST_FINISHED")
	Check("[RWD] après QUEST_FINISHED : pas de ligne, marques retirées", R.Tooltip(1) == "" and R.Marked() == "", R.Marked())
end

-- 8. Module coupé : rien du tout -------------------------------------------------
do
	R.Reset("WARRIOR", 1)
	R.Buttons(3)
	NS:DB().rewardEnabled = false
	R.Offer(R.Trio())
	R.RunTimers()
	Check("[RWD] module coupé : ni marque, ni chat, ni infobulle", R.Marked() == "" and not R.Has(Mock:Output(), "Récompense")
		and R.Tooltip(1) == "", Mock:Output())
	NS:DB().rewardEnabled = true
	NS:DB().enabled = false
	R.Offer(R.Trio())
	Check("[RWD] addon coupé : rien non plus", R.Marked() == "", R.Marked())
	NS:DB().enabled = true
end

-- 9. Sans GetItemStats (repli) : niveau d'objet + type d'armure ---------------
do
	R.Reset("MAGE", 1)
	R.Buttons(3)
	C_Item.GetItemStats, _G.GetItemStats = nil, nil
	Mock.world.equipped[5] = R.Item(9401, "Robe usée", { equipLoc = "INVTYPE_ROBE", classID = 4, subClassID = 1, itemLevel = 15 })
	local plate = R.Item(9402, "Plaques lourdes", { equipLoc = "INVTYPE_CHEST", classID = 4, subClassID = 4, itemLevel = 30 })
	local robe = R.Item(9403, "Robe neuve", { equipLoc = "INVTYPE_ROBE", classID = 4, subClassID = 1, itemLevel = 18 })
	local low = R.Item(9404, "Robe d'apprenti", { equipLoc = "INVTYPE_ROBE", classID = 4, subClassID = 1, itemLevel = 10, sellPrice = 99 })
	local ok = pcall(R.Offer, plate, robe, low)
	Check("[RWD] sans GetItemStats : pas d'erreur, niveau d'objet (+3 en infobulle), plaques écartées", ok and (R.Best()) == 2
		and R.Label(2) == "Pour toi" and R.Has(R.Tooltip(2), "niveau d'objet +3"), R.Tooltip(2))
	C_Item.GetItemStats = MockItemStats
end

-- Restauration
C_Item.GetItemInfo, C_Item.GetItemStats = saved.cGetItemInfo, saved.cGetItemStats
_G.GetItemInfo, _G.GetItemStats = saved.GetItemInfo, saved.GetItemStats
_G.GetNumQuestChoices, _G.GetQuestItemLink, _G.GetQuestItemInfo = saved.GetNumQuestChoices, saved.GetQuestItemLink, saved.GetQuestItemInfo
_G.hooksecurefunc = saved.hooksecurefunc
_G.QuestInfoRewardsFrame, _G.QuestFrameRewardPanel = saved.QuestInfoRewardsFrame, saved.QuestFrameRewardPanel
GameTooltip.SetQuestItem = saved.SetQuestItem
NS.rewardTooltipHooked = saved.hooked
R.ClearButtons()
NS:RewardOnFinished()
ResetWorld()
