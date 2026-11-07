-- QuestReward.lua -- module QoL « La bonne récompense » (v1.24.0)
--
-- Au rendu d'une quête à choix (QUEST_COMPLETE), met en avant la récompense
-- qui sert le joueur : surlignage ambre et libellé « Pour toi » sur son
-- bouton, ou « À vendre : 1 po 20 » si aucune n'améliore l'équipement. Si le
-- bouton est introuvable (interface remplacée), une ligne dans le chat.
-- Chaque choix reçoit aussi, dans son infobulle, l'écart avec l'objet porté.
--
-- Le module ne s'appuie que sur l'API d'extension et sur ce qu'exposent déjà
-- Stats.lua (SPEC_STATS, SpecIndex, IsBearForm, FERAL_TANK_ORDER) et Equip.lua
-- (ItemLinkForSlot). Il ne modifie aucun fichier commun.
--
-- Notation, et pourquoi celle-ci :
--   * les attributs comptent selon la priorité de la spé (SPEC_STATS, même
--     source que le panneau du portrait) : le premier pèse 1, puis 0,6, 0,4…
--     Un attribut absent de la liste ne vaut rien (l'Esprit d'un guerrier).
--     Une seule source de vérité : changer une priorité dans Stats.lua change
--     aussi le conseil ici ;
--   * un objet que la classe porte mal (plaques pour un mage, bouclier pour
--     un voleur, arme non maîtrisée) vaut 0 : le conseiller serait pire que
--     ne rien dire. Le jeu signale aussi lui-même un objet inutilisable
--     (5e retour de GetQuestItemInfo) : on le respecte ;
--   * on compare à l'objet porté au même emplacement. Anneaux et bijoux ont
--     deux emplacements : on compare au plus faible, celui qu'on remplacerait ;
--   * sans API de statistiques (certains clients Era), on retombe sur le
--     niveau d'objet, toujours filtré par l'aptitude au type d'armure.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local EPSILON = 0.05
-- poids des attributs selon leur rang dans la priorité de la spé
local RANK_WEIGHTS = { 1.0, 0.6, 0.4, 0.25, 0.15 }
-- un cran d'armure sous le meilleur que la classe porte : encore correct,
-- mais moins bien (un chasseur de niveau 45 en cuir)
local LOWER_TIER_FACTOR = 0.8
local ARMOR_LEVEL = 40     -- maille (chasseur, chaman) et plaques (guerrier, paladin)
local CHAT_RETRY = 0.1     -- secondes : laisser l'interface créer ses boutons

-- ---------------------------------------------------------------------------
-- Chaînes, réglages, page d'options, module
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_REWARD      = "La bonne récompense",
	OPT_PAGE_REWARD_SUB  = "Au rendu d'une quête, la récompense qui te sert est mise en avant.",
	OPT_REWARD_ENABLED   = "Conseiller une récompense",
	OPT_REWARD_TOOLTIP   = "Montrer dans l'infobulle",
	OPT_REWARD_SELL      = "Repli : la plus chère",
	REWARD_FOR_YOU       = "Pour toi",
	REWARD_SELL_PRICE    = "À vendre : %s",
	REWARD_CHAT          = "Récompense conseillée : %s (%s)",
	REWARD_WHY_SELL      = "rien ne t'améliore, elle vaut %s",
	REWARD_TT_DELTA      = "Par rapport au porté : %s",
	REWARD_TT_UNUSABLE   = "Pas pour toi",
	REWARD_TT_SAME       = "Pas mieux que ton équipement",
	REWARD_TT_UPGRADE    = "Ready2Quest : amélioration",
	REWARD_TT_UPGRADE_DELTA = "Ready2Quest : amélioration (%s)",
	REWARD_ILVL          = "niveau d'objet %s",
	REWARD_DPS           = "DPS",
}
local EN = {
	OPT_PAGE_REWARD      = "The right reward",
	OPT_PAGE_REWARD_SUB  = "When you turn in a quest, the reward that suits you stands out.",
	OPT_REWARD_ENABLED   = "Suggest a reward",
	OPT_REWARD_TOOLTIP   = "Show in the tooltip",
	OPT_REWARD_SELL      = "Fallback: the priciest",
	REWARD_FOR_YOU       = "For you",
	REWARD_SELL_PRICE    = "To sell: %s",
	REWARD_CHAT          = "Suggested reward: %s (%s)",
	REWARD_WHY_SELL      = "nothing upgrades you, it's worth %s",
	REWARD_TT_DELTA      = "Compared to equipped: %s",
	REWARD_TT_UNUSABLE   = "Not for you",
	REWARD_TT_SAME       = "No better than your gear",
	REWARD_TT_UPGRADE    = "Ready2Quest: upgrade",
	REWARD_TT_UPGRADE_DELTA = "Ready2Quest: upgrade (%s)",
	REWARD_ILVL          = "item level %s",
	REWARD_DPS           = "DPS",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests : chaque clé doit exister dans les deux langues
if ns.KEEP_STRINGS then ns.REWARD_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({
	rewardEnabled  = true,
	rewardTooltip  = true,
	rewardSellBest = true,
})

if ns.AddOptionPage then
	-- sous-page QoL : l'interrupteur du module est une ligne de la page, comme
	-- Marchand (le QoL n'a pas d'interrupteur dans la navigation)
	ns.AddOptionPage({
		id = "reward", title = "OPT_PAGE_REWARD", parent = "qol", group = "OPT_GROUP_QOL",
		rows = {
			{ key = "rewardEnabled",  label = "OPT_REWARD_ENABLED", kind = "bool" },
			{ key = "rewardTooltip",  label = "OPT_REWARD_TOOLTIP", kind = "bool" },
			{ key = "rewardSellBest", label = "OPT_REWARD_SELL",    kind = "bool" },
		},
	})
end

if ns.RegisterModule then
	ns.RegisterModule({ id = "reward", key = "rewardEnabled", label = "OPT_PAGE_REWARD",
		aliases = { "recompense", "reward" } })
end

function ns:RewardEnabled()
	local db = self:DB()
	return db.enabled ~= false and db.rewardEnabled ~= false
end

-- ---------------------------------------------------------------------------
-- Appels défensifs
-- ---------------------------------------------------------------------------
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local r = { pcall(fn, ...) }
	if not r[1] then return nil end
	return unpack(r, 2, table.maxn(r))
end

local function PlayerClass()
	local _, classFile = Call(rawget(_G, "UnitClass"), "player")
	return type(classFile) == "string" and string.upper(classFile) or nil
end

local function PlayerLevel()
	return tonumber((Call(rawget(_G, "UnitLevel"), "player"))) or 1
end

-- ---------------------------------------------------------------------------
-- Priorité des attributs : même choix que le panneau du portrait
-- ---------------------------------------------------------------------------
-- Reprend la logique de StatsForPlayer (Stats.lua, locale) à partir de ce que
-- ce fichier expose déjà, plutôt que d'ouvrir une fonction de plus là-bas.
local FALLBACK_ORDER = { "STR", "AGI", "INT", "SPI", "STA" }

function ns.RewardStatPriority()
	local classFile = PlayerClass()
	local bySpec = classFile and type(ns.SPEC_STATS) == "table" and ns.SPEC_STATS[classFile]
	if type(bySpec) ~= "table" then return FALLBACK_ORDER end
	local index = (ns.SpecIndex and Call(ns.SpecIndex)) or 0
	if classFile == "DRUID" and index == 2 and ns.IsBearForm and Call(ns.IsBearForm) and ns.FERAL_TANK_ORDER then
		return ns.FERAL_TANK_ORDER
	end
	return bySpec[index] or bySpec[1] or FALLBACK_ORDER
end

-- Poids de chaque statistique pour la spé. Les spés physiques (Force ou
-- Agilité dans les deux premières) comptent le DPS de l'arme et la puissance
-- d'attaque ; les autres, la puissance des sorts. L'armure pèse peu, sauf
-- pour un tank (Endurance en tête).
local function Weights()
	local order = ns.RewardStatPriority()
	local w = {}
	for rank, key in ipairs(order) do w[key] = RANK_WEIGHTS[rank] or 0.1 end
	local physical = false
	for rank = 1, 2 do
		if order[rank] == "STR" or order[rank] == "AGI" then physical = true end
	end
	w.DPS = physical and 1.0 or 0
	w.AP = physical and 0.3 or 0
	w.SP = physical and 0 or 0.8
	w.ARMOR = (order[1] == "STA") and 0.05 or 0.01
	return w, order
end

-- clés renvoyées par GetItemStats -> clés courtes
local STAT_KEYS = {
	ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_STRENGTH = "STR",
	ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_AGILITY = "AGI",
	ITEM_MOD_INTELLECT_SHORT = "INT", ITEM_MOD_INTELLECT = "INT",
	ITEM_MOD_SPIRIT_SHORT = "SPI", ITEM_MOD_SPIRIT = "SPI",
	ITEM_MOD_STAMINA_SHORT = "STA", ITEM_MOD_STAMINA = "STA",
	RESISTANCE0_NAME = "ARMOR", ITEM_MOD_ARMOR = "ARMOR",
	ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "DPS",
	ITEM_MOD_ATTACK_POWER_SHORT = "AP", ITEM_MOD_ATTACK_POWER = "AP",
	ITEM_MOD_SPELL_POWER_SHORT = "SP", ITEM_MOD_SPELL_POWER = "SP",
}

local function StatsApi()
	local c = rawget(_G, "C_Item")
	if type(c) == "table" and type(c.GetItemStats) == "function" then return c.GetItemStats end
	local g = rawget(_G, "GetItemStats")
	if type(g) == "function" then return g end
	return nil
end

-- Statistiques d'un objet en clés courtes, ou nil si l'API manque (Era)
local function ItemStats(link)
	local api = StatsApi()
	if not api or not link then return nil end
	local raw = Call(api, link)
	local out = {}
	if type(raw) == "table" then
		for key, value in pairs(raw) do
			local short = STAT_KEYS[key]
			if short and type(value) == "number" then out[short] = (out[short] or 0) + value end
		end
	end
	return out
end

-- GetItemInfo complet : la notice d'Equip.lua ne lit ni le prix de vente
-- (11e retour) ni la classe/sous-classe (12e, 13e), dont on a besoin ici.
local function ItemInfo(link)
	if not link then return nil end
	local c = rawget(_G, "C_Item")
	local name, _, quality, itemLevel, minLevel, _, _, _, equipLoc, _, sellPrice, classID, subClassID = ns.ItemInfo(link)
	if not name then return nil end
	if classID == nil then
		-- certains clients ne renvoient pas la classe : GetItemInfoInstant la donne
		local instant = (type(c) == "table" and c.GetItemInfoInstant) or rawget(_G, "GetItemInfoInstant")
		local _, _, _, _, _, cid, sid = Call(instant, link)
		classID, subClassID = cid, sid
	end
	return {
		name = name, quality = quality, itemLevel = tonumber(itemLevel) or 0, minLevel = tonumber(minLevel),
		equipLoc = equipLoc, sellPrice = tonumber(sellPrice) or 0,
		classID = tonumber(classID), subClassID = tonumber(subClassID),
	}
end

-- ---------------------------------------------------------------------------
-- Ce que chaque classe porte bien (Classic : maîtrises d'armes et d'armures)
-- ---------------------------------------------------------------------------
-- Armure (classID 4) : 1 tissu, 2 cuir, 3 maille, 4 plaques, 6 bouclier,
-- 7 libram, 8 idole, 9 totem. `tier` = meilleur type porté, `late` = celui
-- qu'on apprend au niveau 40.
-- Armes (classID 2) : 0/1 hache 1M/2M, 2 arc, 3 fusil, 4/5 masse 1M/2M,
-- 6 arme d'hast, 7/8 épée 1M/2M, 10 bâton, 13 pugilat, 14 divers,
-- 15 dague, 16 de jet, 18 arbalète, 19 baguette, 20 canne à pêche.
local function Set(...)
	local t = {}
	for i = 1, select("#", ...) do t[select(i, ...)] = true end
	return t
end

local PROFICIENCY = {
	WARRIOR = { tier = 3, late = 4, shield = true, dual = true,
		weapons = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18) },
	PALADIN = { tier = 3, late = 4, shield = true, relic = 7,
		weapons = Set(0, 1, 4, 5, 6, 7, 8) },
	HUNTER  = { tier = 2, late = 3, dual = true, noHoldable = true,
		weapons = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18) },
	SHAMAN  = { tier = 2, late = 3, shield = true, relic = 9,
		weapons = Set(0, 1, 4, 5, 10, 13, 15) },
	ROGUE   = { tier = 2, dual = true, noHoldable = true,
		weapons = Set(2, 3, 4, 7, 13, 15, 16, 18) },
	DRUID   = { tier = 2, relic = 8,
		weapons = Set(4, 5, 6, 10, 13, 15) },
	MAGE    = { tier = 1, weapons = Set(7, 10, 15, 19) },
	PRIEST  = { tier = 1, weapons = Set(4, 10, 15, 19) },
	WARLOCK = { tier = 1, weapons = Set(7, 10, 15, 19) },
}
ns.REWARD_PROFICIENCY = PROFICIENCY

-- emplacements où le type d'armure compte (pas cape, cou, anneaux, bijoux)
local ARMOR_SLOTS = Set("INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE",
	"INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_WRIST", "INVTYPE_HAND")

-- Facteur d'aptitude : 1 = bien, 0,8 = un cran d'armure en dessous, 0 = à
-- ne jamais conseiller. Une classe inconnue ou un objet sans classe lisible
-- passe (1) : mieux vaut un conseil sur les stats qu'aucun.
local function Suitability(info, classFile, level)
	local prof = classFile and PROFICIENCY[classFile]
	if not prof or not info then return 1 end
	local loc, cid, sid = info.equipLoc, info.classID, info.subClassID
	if loc == "INVTYPE_HOLDABLE" and prof.noHoldable then return 0 end
	if cid == 4 and sid then
		if sid == 6 or loc == "INVTYPE_SHIELD" then return prof.shield and 1 or 0 end
		if sid >= 7 and sid <= 9 then return prof.relic == sid and 1 or 0 end
		if ARMOR_SLOTS[loc] and sid >= 1 and sid <= 4 then
			local best = (prof.late and level >= ARMOR_LEVEL) and prof.late or prof.tier
			if sid > best then return 0 end
			if sid == best then return 1 end
			if sid == best - 1 then return LOWER_TIER_FACTOR end
			return 0
		end
		return 1
	end
	if cid == 2 and sid then
		if sid == 14 or sid == 20 then return 1 end
		return prof.weapons[sid] and 1 or 0
	end
	return 1
end
ns.RewardSuitability = Suitability

-- ---------------------------------------------------------------------------
-- Notation
-- ---------------------------------------------------------------------------
local function RawScore(stats, info, weights)
	if stats then
		local total = 0
		for key, value in pairs(stats) do total = total + value * (weights[key] or 0) end
		return total
	end
	-- repli sans API de statistiques : le niveau d'objet
	return info and info.itemLevel or 0
end

-- Note d'un objet porté (pas de filtre d'aptitude : c'est ce qu'il porte)
local function EquippedEntry(slot, weights)
	local link = ns.ItemLinkForSlot and ns.ItemLinkForSlot(slot)
	if not link then return { slot = slot, score = 0, stats = {}, itemLevel = 0 } end
	local info = ItemInfo(link)
	local stats = ItemStats(link)
	return { slot = slot, link = link, info = info, stats = stats or {},
		itemLevel = info and info.itemLevel or 0, score = RawScore(stats, info, weights) }
end

local SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
	INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
	INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
	INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
	INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

-- Ce que l'objet remplacerait. Deux emplacements (anneaux, bijoux, arme à
-- une main d'une classe qui en tient deux) : le plus faible, puisque c'est
-- lui qu'on enlèverait. Arme à deux mains : la main droite ET la gauche.
local function Replaced(equipLoc, classFile, weights)
	local slots = SLOTS[equipLoc]
	if not slots then return nil end
	if equipLoc == "INVTYPE_2HWEAPON" then
		local main, off = EquippedEntry(16, weights), EquippedEntry(17, weights)
		local merged = {}
		for _, e in ipairs({ main, off }) do
			for k, v in pairs(e.stats) do merged[k] = (merged[k] or 0) + v end
		end
		return { slot = 16, link = main.link, stats = merged, score = main.score + off.score,
			itemLevel = math.max(main.itemLevel, off.itemLevel) }
	end
	local candidates = { slots[1], slots[2] }
	if equipLoc == "INVTYPE_WEAPON" and classFile and PROFICIENCY[classFile] and PROFICIENCY[classFile].dual then
		local offLink = ns.ItemLinkForSlot and ns.ItemLinkForSlot(17)
		local offInfo = offLink and ItemInfo(offLink)
		if offInfo and (offInfo.equipLoc == "INVTYPE_WEAPON" or offInfo.equipLoc == "INVTYPE_WEAPONOFFHAND") then
			candidates = { 16, 17 }
		end
	end
	local weakest
	for _, slot in ipairs(candidates) do
		local e = EquippedEntry(slot, weights)
		if not weakest or e.score < weakest.score then weakest = e end
	end
	return weakest
end

-- Lien et infos de chaque choix de la récompense
local function QuestChoices()
	local count = tonumber((Call(rawget(_G, "GetNumQuestChoices")))) or 0
	local out = {}
	for index = 1, count do
		local link = Call(rawget(_G, "GetQuestItemLink"), "choice", index)
		local _, _, _, _, isUsable = Call(rawget(_G, "GetQuestItemInfo"), "choice", index)
		out[#out + 1] = { index = index, link = type(link) == "string" and link or nil, usable = isUsable }
	end
	return out
end

-- Analyse complète : chaque choix noté, et le conseil.
-- mode = "upgrade" (une amélioration), "sell" (la plus chère) ou nil.
function ns:RewardAnalyze()
	local weights, order = Weights()
	local classFile, level = PlayerClass(), PlayerLevel()
	local hasStats = StatsApi() ~= nil
	local result = { choices = QuestChoices(), order = order, hasStats = hasStats, pending = false }
	local bestDelta, best = EPSILON, nil
	for _, choice in ipairs(result.choices) do
		local info = ItemInfo(choice.link)
		choice.info = info
		if not info then
			-- objet pas encore en cache : on réessaiera à GET_ITEM_INFO_RECEIVED
			result.pending = result.pending or choice.link ~= nil
			choice.delta, choice.suit = 0, 0
		else
			choice.stats = ItemStats(choice.link)
			choice.sellPrice = info.sellPrice
			choice.suit = (choice.usable == false or choice.usable == 0) and 0 or Suitability(info, classFile, level)
			choice.replaced = Replaced(info.equipLoc, classFile, weights)
			if choice.replaced and choice.suit > 0 then
				choice.score = RawScore(choice.stats, info, weights) * choice.suit
				choice.delta = choice.score - choice.replaced.score
			else
				choice.score, choice.delta = 0, 0
			end
			if choice.delta > bestDelta then bestDelta, best = choice.delta, choice end
		end
	end
	if best then
		result.best, result.mode = best, "upgrade"
	elseif self:DB().rewardSellBest ~= false then
		local priciest
		for _, choice in ipairs(result.choices) do
			if (choice.sellPrice or 0) > 0 and (not priciest or choice.sellPrice > priciest.sellPrice) then
				priciest = choice
			end
		end
		if priciest then result.best, result.mode = priciest, "sell" end
	end
	return result
end

-- ---------------------------------------------------------------------------
-- Textes : écart de stats, raison du conseil
-- ---------------------------------------------------------------------------
local function Signed(value)
	value = math.floor(value + (value >= 0 and 0.5 or -0.5))
	return (value >= 0 and "+" or "") .. tostring(value)
end

-- « +5 Force, -2 Endurance » : seulement les attributs qui comptent pour la
-- spé, dans son ordre ; sans API de stats, l'écart de niveau d'objet.
function ns:RewardDeltaText(choice, result)
	if not choice or not choice.info or not choice.replaced then return nil end
	if not result.hasStats then
		local diff = (choice.info.itemLevel or 0) - (choice.replaced.itemLevel or 0)
		if diff == 0 then return nil end
		return self:F("REWARD_ILVL", Signed(diff))
	end
	local parts = {}
	local new, old = choice.stats or {}, choice.replaced.stats or {}
	for _, key in ipairs(result.order or {}) do
		local diff = (new[key] or 0) - (old[key] or 0)
		if math.abs(diff) >= 0.5 then parts[#parts + 1] = Signed(diff) .. " " .. (L["STAT_" .. key] or key) end
	end
	local dps = (new.DPS or 0) - (old.DPS or 0)
	if math.abs(dps) >= 0.1 and (choice.info.classID == 2) then
		parts[#parts + 1] = string.format("%s%.1f %s", dps >= 0 and "+" or "", dps, L.REWARD_DPS)
	end
	if #parts == 0 then return nil end
	return table.concat(parts, ", ")
end

function ns:RewardTooltipLine(choice, result)
	if not choice or not choice.info then return nil end
	if (choice.suit or 0) <= 0 or not choice.replaced then return L.REWARD_TT_UNUSABLE end
	local text = self:RewardDeltaText(choice, result)
	if not text or (choice.delta or 0) <= EPSILON then
		-- pas mieux : on montre quand même l'écart s'il existe (un gain d'une
		-- stat peut cacher une perte de la principale)
		if text then return self:F("REWARD_TT_DELTA", text) end
		return L.REWARD_TT_SAME
	end
	return self:F("REWARD_TT_DELTA", text)
end

function ns:RewardReason(result)
	local best = result and result.best
	if not best then return nil end
	if result.mode == "sell" then return self:F("REWARD_WHY_SELL", self:FormatMoney(best.sellPrice)) end
	return self:RewardDeltaText(best, result) or L.REWARD_FOR_YOU
end

-- ---------------------------------------------------------------------------
-- Boutons de récompense : surlignage ambre et libellé
-- ---------------------------------------------------------------------------
-- Selon le client, les boutons de choix s'appellent :
--   * QuestInfoRewardsFrameQuestInfoItem<i> (Classic moderne, Era 1.15) ;
--   * QuestInfoItem<i> (anciens QuestInfo) ;
--   * QuestRewardItem<i> (interface 1.12 d'origine, Forever).
-- On lit d'abord la table RewardButtons (type = "choice", GetID = index), qui
-- ne dépend d'aucun nom. Les choix occupent toujours les premiers boutons.
local BUTTON_PATTERNS = { "QuestInfoRewardsFrameQuestInfoItem%d", "QuestInfoItem%d", "QuestRewardItem%d" }

local function IsFrame(value)
	return type(value) == "table" and type(value.CreateTexture) == "function"
end

function ns:RewardButton(index)
	local rewards = rawget(_G, "QuestInfoRewardsFrame")
	if type(rewards) == "table" and type(rewards.RewardButtons) == "table" then
		for _, button in ipairs(rewards.RewardButtons) do
			local id = type(button) == "table" and Call(button.GetID, button)
			if IsFrame(button) and button.type == "choice" and id == index then return button end
		end
	end
	for _, pattern in ipairs(BUTTON_PATTERNS) do
		local button = rawget(_G, string.format(pattern, index))
		if IsFrame(button) and (button.type == nil or button.type == "choice") then return button end
	end
	return nil
end

local marked = {}

function ns:RewardClearMarks()
	for button in pairs(marked) do
		local mark = button.r2qRewardMark
		if mark then
			if mark.glow then mark.glow:Hide() end
			if mark.label then mark.label:Hide() end
			if mark.edge then for _, side in ipairs({ "top", "bottom", "left", "right" }) do mark.edge[side]:Hide() end end
		end
		marked[button] = nil
	end
end

local function MarkButton(button, text)
	local mark = button.r2qRewardMark
	if not mark then
		mark = {}
		mark.glow = button:CreateTexture(nil, "OVERLAY")
		mark.glow:SetAllPoints(button)
		-- docs/UI.md : la récompense conseillée est cernée d'ambre (filet 1 px,
		-- fond ambre léger), son étiquette en F_LABEL ambre
		local c = Theme.GOLD
		mark.glow:SetTexture(Theme.SOLID)
		mark.glow:SetVertexColor(c[1], c[2], c[3], 0.12)
		mark.edge = Theme.Border(button, c, 1, "OVERLAY")
		mark.label = Theme.Text(button, Theme.F_LABEL, c)
		mark.label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 4)
		button.r2qRewardMark = mark
	end
	mark.label:SetText(text)
	mark.glow:Show()
	mark.label:Show()
	for _, side in ipairs({ "top", "bottom", "left", "right" }) do mark.edge[side]:Show() end
	marked[button] = true
end

-- Applique le conseil. `final` : dernière tentative, le chat sert de repli.
function ns:RewardApply(final)
	self:RewardClearMarks()
	local state = self.rewardState
	if not state or not state.active or not self:RewardEnabled() then return end
	local result = self:RewardAnalyze()
	state.result = result
	-- un seul « choix » est donné d'office : rien à conseiller
	if #result.choices < 2 then return end
	local best = result.best
	if not best or not best.link then return end
	local label = result.mode == "sell"
		and self:F("REWARD_SELL_PRICE", self:FormatMoney(best.sellPrice))
		or L.REWARD_FOR_YOU
	local button = self:RewardButton(best.index)
	if button then
		local ok = pcall(MarkButton, button, label)
		if ok then state.shown = best.link; return end
	end
	if final and state.printed ~= best.link then
		state.printed = best.link
		self:Print(self:F("REWARD_CHAT", best.link, self:RewardReason(result) or label))
	end
end

-- ---------------------------------------------------------------------------
-- Infobulle : une ligne par choix, tant que la récompense est affichée
-- ---------------------------------------------------------------------------
function ns:RewardFrameShown()
	local state = self.rewardState
	if not state or not state.active then return false end
	-- le panneau peut avoir été fermé sans QUEST_FINISHED (interface remplacée)
	for _, name in ipairs({ "QuestFrameRewardPanel", "QuestFrame" }) do
		local frame = rawget(_G, name)
		if type(frame) == "table" and type(frame.IsShown) == "function" then
			return Call(frame.IsShown, frame) and true or false
		end
	end
	return true
end

function ns:RewardAddTooltip(tooltip, index, link)
	if not self:RewardEnabled() or self:DB().rewardTooltip == false then return end
	if not self:RewardFrameShown() then return end
	local state = self.rewardState
	local result = state.result or self:RewardAnalyze()
	state.result = result
	local choice
	for _, c in ipairs(result.choices or {}) do
		if (index and c.index == index) or (not index and link and c.link == link) then choice = c end
	end
	local line = self:RewardTooltipLine(choice, result)
	if not line or type(tooltip) ~= "table" or type(tooltip.AddLine) ~= "function" then return end
	local c = Theme and Theme.GOLD or { 0.91, 0.65, 0.29 }
	pcall(tooltip.AddLine, tooltip, line, c[1], c[2], c[3], true)
	if type(tooltip.Show) == "function" then pcall(tooltip.Show, tooltip) end   -- recalcule la taille
end

-- Accroche posée une seule fois, au premier rendu de quête : hooksecurefunc
-- sur SetQuestItem (appelé par les boutons de récompense) ne touche pas au
-- code protégé. À défaut, OnTooltipSetItem, reconnu par le lien.
function ns:RewardHookTooltip()
	if self.rewardTooltipHooked then return end
	local tooltip = rawget(_G, "GameTooltip")
	if type(tooltip) ~= "table" then return end
	local hook = rawget(_G, "hooksecurefunc")
	if type(hook) == "function" and type(tooltip.SetQuestItem) == "function" then
		local ok = pcall(hook, tooltip, "SetQuestItem", function(tt, kind, index)
			if kind ~= "choice" then return end
			local fine, err = pcall(ns.RewardAddTooltip, ns, tt, index)
			if not fine and ns.RecordError then ns:RecordError("reward:tooltip", err) end
		end)
		if ok then self.rewardTooltipHooked = "SetQuestItem"; return end
	end
	if type(tooltip.HookScript) == "function" then
		local ok = pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(tt)
			local _, link = Call(tt.GetItem, tt)
			if not link then return end
			local fine, err = pcall(ns.RewardAddTooltip, ns, tt, nil, link)
			if not fine and ns.RecordError then ns:RecordError("reward:tooltip", err) end
		end)
		if ok then self.rewardTooltipHooked = "OnTooltipSetItem" end
	end
end

-- ---------------------------------------------------------------------------
-- Survol de n'importe quel objet (sacs, butin, marchand…) : la même notation
-- que les récompenses. Une ligne seulement quand l'objet améliore le porté ;
-- rien sinon (ni « pas mieux », ni prix : le jeu affiche déjà le sien).
-- ---------------------------------------------------------------------------
function ns:RewardItemUpgradeLine(link)
	if not self:RewardEnabled() or self:DB().rewardTooltip == false then return nil end
	link = ns.Plain(link)
	if type(link) ~= "string" then return nil end
	-- fenêtre de récompense ouverte : ses choix ont déjà leur ligne (RewardAddTooltip)
	if self.rewardState and self.rewardState.active then return nil end
	local info = ItemInfo(link)
	local slots = info and SLOTS[info.equipLoc]
	if not slots then return nil end
	-- l'objet porté lui-même (un anneau comparé à l'autre anneau) : rien
	for _, slot in ipairs(slots) do
		if ns.ItemLinkForSlot and ns.ItemLinkForSlot(slot) == link then return nil end
	end
	local weights, order = Weights()
	local classFile, level = PlayerClass(), PlayerLevel()
	if info.minLevel and info.minLevel > level then return nil end   -- pas encore portable
	local suit = Suitability(info, classFile, level)
	if suit <= 0 then return nil end
	local replaced = Replaced(info.equipLoc, classFile, weights)
	if not replaced then return nil end
	local stats = ItemStats(link)
	if RawScore(stats, info, weights) * suit - replaced.score <= EPSILON then return nil end
	local text = self:RewardDeltaText({ info = info, stats = stats, replaced = replaced },
		{ order = order, hasStats = StatsApi() ~= nil })
	return text and self:F("REWARD_TT_UPGRADE_DELTA", text) or L.REWARD_TT_UPGRADE
end

function ns:RewardOnItemTooltip(tooltip)
	if type(tooltip.GetItem) ~= "function" then return false end
	local ok, _, link = pcall(tooltip.GetItem, tooltip)
	if not ok then return false end
	local line = self:RewardItemUpgradeLine(link)
	if not line then return false end
	local c = Theme and Theme.GREEN or { 0.44, 0.81, 0.48 }
	tooltip:AddLine(line, c[1], c[2], c[3])
	return true
end

function ns:RewardHookItemTooltip()
	if not self.HookTooltip then return nil end
	return self:HookTooltip("Item", function(tooltip, data)
		if ns:RewardOnItemTooltip(tooltip) and data == nil and type(tooltip.Show) == "function" then
			pcall(tooltip.Show, tooltip)   -- OnTooltipSetItem : le cadre reprend sa taille
		end
	end)
end
ns:RewardHookItemTooltip()

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
function ns:RewardOnComplete()
	self.rewardState = { active = true }
	if not self:RewardEnabled() then return end
	self:RewardHookTooltip()
	-- Notre cadre peut recevoir QUEST_COMPLETE avant celui de la quête, qui
	-- crée ses boutons à l'affichage : on marque tout de suite si possible,
	-- puis on repasse un instant après, et c'est alors seulement que le chat
	-- prend le relais.
	local timer = rawget(_G, "C_Timer")
	if type(timer) == "table" and type(timer.After) == "function" then
		self:RewardApply(false)
		pcall(timer.After, CHAT_RETRY, function()
			if ns.rewardState and ns.rewardState.active then ns:RewardApply(true) end
		end)
	else
		self:RewardApply(true)
	end
end

function ns:RewardOnFinished()
	self:RewardClearMarks()
	self.rewardState = nil
end

local HANDLERS = {
	QUEST_COMPLETE = function() ns:RewardOnComplete() end,
	QUEST_FINISHED = function() ns:RewardOnFinished() end,
	-- objet arrivé en cache après coup : on recalcule
	QUEST_ITEM_UPDATE = function()
		if ns.rewardState and ns.rewardState.active then ns:RewardApply(true) end
	end,
	GET_ITEM_INFO_RECEIVED = function()
		local state = ns.rewardState
		if state and state.active and state.result and state.result.pending then ns:RewardApply(true) end
	end,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("reward:" .. tostring(event), err) end
end)
ns.rewardEventFrame = eventFrame

if ns.Mark then ns.Mark("QuestReward") end
