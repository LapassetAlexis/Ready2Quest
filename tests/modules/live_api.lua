-- API récentes, exploitées seulement quand le client les expose (lot 1) :
--   * rares signalés en direct (C_VignetteInfo, QuestCompanion/LiveRares.lua) ;
--   * infobulles enrichies (TooltipDataProcessor ou OnTooltipSet*, accroche du
--     socle ns:HookTooltip) : bestiaire au survol d'une créature (QC,
--     Tooltips.lua), amélioration au survol d'un objet (R2Q, QuestReward.lua) ;
--   * animations du compagnon aux grands moments (PlayerModel:SetAnimation,
--     CompanionFx.lua).
-- Chaque fois : l'API présente fait son effet ; absente, en erreur ou rendant
-- des valeurs secrètes, rien ne casse et l'ancien comportement reste.
local Check, Say, ResetWorld, NS, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.QNS, T.Mock

local LA = { saved = {}, W = {}, globals = { "C_VignetteInfo", "TooltipDataProcessor", "UnitGUID", "IsInInstance",
	"issecretvalue", "CombatLogGetCurrentEventInfo", "InCombatLockdown", "ItemRefTooltip", "GetItemInfo" } }
for _, name in ipairs(LA.globals) do LA.saved[name] = rawget(_G, name) end
LA.saved.unitType = Enum.TooltipDataType.Unit
LA.saved.itemType = Enum.TooltipDataType.Item
LA.saved.ZONE_CREATURES = rawget(QNS, "ZONE_CREATURES")
LA.saved.GetUnit, LA.saved.GetItem = GameTooltip.GetUnit, GameTooltip.GetItem
LA.saved.CreateFrame = _G.CreateFrame
LA.saved.cGetItemInfo, LA.saved.cGetItemStats = C_Item.GetItemInfo, C_Item.GetItemStats
LA.saved.qcHooks, LA.saved.r2qHooks = QNS.tooltipHooks, NS.tooltipHooks

local ZONE = 1413
local PLAYER_GUID = "Player-1-00000001"
local SECRET = {}            -- une valeur « secrète » : issecretvalue la reconnaît
function LA.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end

_G.IsInInstance = function() return false, "none" end
_G.InCombatLockdown = function() return false end
_G.UnitGUID = function(unit)
	if unit == "player" then return PLAYER_GUID end
	return LA.W.units and LA.W.units[unit]
end
_G.CombatLogGetCurrentEventInfo = function() return unpack(LA.W.cleu or {}) end
_G.issecretvalue = function(value) return value == SECRET end

-- une zone livrée : un rare (rang 4), un loup normal, un élite
function LA.Zone()
	QNS.ZONE_CREATURES = { [ZONE] = {
		[5001] = { lvl = { 20, 20 }, rank = 4, fr = "Griffe-Grise", en = "Greyclaw" },
		[5002] = { lvl = { 18, 19 }, rank = 0, fr = "Loup des plaines", en = "Plains Wolf" },
		[5003] = { lvl = { 21, 21 }, rank = 1, fr = "Garde élite", en = "Elite Guard" },
	} }
end

function LA.ResetQC()
	ResetWorld()
	LA.W = { units = {}, vignettes = {}, infos = {} }
	Mock.world.maps[ZONE] = { mapID = ZONE, name = "Les Tarides", parentMapID = 0, mapType = 3 }
	Mock.world.mapID = ZONE
	Mock.world.level = 20
	LA.Zone()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if QNS[field] then QNS[field]:Hide() end
		QNS[field] = nil
	end
	QNS.companionRT, QNS.companionSession, QNS.companionAnimTest, QNS.companionAnimUntil = nil, nil, nil, nil
	QNS.companionLastBubble, QNS.companionBubbleUntil, QNS.companionBubbleKey, QNS.companionBubblePrio = nil, nil, nil, nil
	QNS.bestiaryUnits, QNS.bestiaryPrunedAt, QNS.journalRares, QNS.liveRareAlerts = {}, nil, {}, nil
	QNS.journalToasts, QNS.journalChats, QNS.journalToastHideAt = {}, {}, nil
	QNS:CompanionData().tutoDone = true
	QNS:TreatData().treatsInit = true
	QNS:CompanionUpdateVisibility()
end
-- la prochaine bulle peut partir tout de suite
function LA.Quiet()
	QNS.companionLastBubble, QNS.companionBubbleUntil, QNS.companionBubbleKey, QNS.companionBubblePrio = nil, nil, nil, nil
	if QNS.companionRT then QNS.companionRT.cool = {} end
end

-- C_VignetteInfo du moteur récent : une liste de vignettes, une fiche par vignette
function LA.InstallVignettes()
	_G.C_VignetteInfo = {
		GetVignettes = function() return LA.W.vignettes end,
		GetVignetteInfo = function(id)
			if LA.W.vignetteError then error("vignette API refused") end
			return LA.W.infos[id]
		end,
	}
end
function LA.Vignette(id, info)
	LA.W.vignettes[#LA.W.vignettes + 1] = id
	info.onMinimap = info.onMinimap == nil and true or info.onMinimap
	LA.W.infos[id] = info
end

-- ---------------------------------------------------------------------------
-- 1. Rares en direct (C_VignetteInfo)
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes : rares signalés en direct")
	LA.ResetQC()
	_G.C_VignetteInfo = nil
	Check("[LIVE] LiveRares.lua chargé", QNS.Loaded and QNS.Loaded.LiveRares)
	local order = {}
	for index, file in ipairs(_G.TOC_FILES or {}) do order[file] = index end
	Check("[LIVE] .toc : LiveRares et Tooltips après Bestiary et Notify",
		order["QuestCompanion/LiveRares.lua"] and order["QuestCompanion/LiveRares.lua"] > order["QuestCompanion/Notify.lua"]
		and order["QuestCompanion/Tooltips.lua"] and order["QuestCompanion/Tooltips.lua"] > order["QuestCompanion/Bestiary.lua"])
	-- chaînes et répliques : les deux langues, mêmes paramètres
	local missing = {}
	for _, set in ipairs({ QNS.LIVE_RARE_STRINGS, QNS.TOOLTIP_STRINGS }) do
		for key, value in pairs(set.fr) do
			if type(set.en[key]) ~= "string" or set.en[key] == "" or QNS.L[key] ~= value then missing[#missing + 1] = key end
		end
	end
	for _, key in ipairs(QNS.COMPANION_POOLS.RARE_LIVE or {}) do
		local fr, en = QNS.COMPANION_LINE_STRINGS.fr[key], QNS.COMPANION_LINE_STRINGS.en[key]
		if not (fr and en and fr:find("%s", 1, true) and en:find("%s", 1, true)) then missing[#missing + 1] = key end
	end
	Check("[LIVE] chaînes et répliques en français et en anglais", #missing == 0 and #(QNS.COMPANION_POOLS.RARE_LIVE or {}) >= 2,
		table.concat(missing, ", "))

	-- sans l'API : rien n'écoute, rien ne parle, rien ne casse
	Check("[LIVE] sans C_VignetteInfo : pas d'écoute", QNS:LiveRareListen() == false
		and not (QNS.liveRareFrame and QNS.liveRareFrame.events.VIGNETTES_UPDATED))
	Mock:Fire("VIGNETTES_UPDATED")
	Check("[LIVE] sans C_VignetteInfo : scan neutre", QNS:LiveRareScan() == 0 and QNS:LiveRareCheck("v1") == false
		and QNS.companionBubbleKey == nil)
	Check("[LIVE] sans C_VignetteInfo : pas d'interrupteur dans les réglages", (function()
		for _, row in ipairs(QNS.DAILY_OPTION_ROWS or {}) do if row.key == "companionRareAlert" then return false end end
		return true
	end)())

	-- avec l'API : un rare de la table apparaît sur la minicarte
	LA.InstallVignettes()
	Check("[LIVE] avec C_VignetteInfo : écoute posée", QNS:LiveRareListen() == true
		and QNS.liveRareFrame.events.VIGNETTES_UPDATED and QNS.liveRareFrame.events.VIGNETTE_MINIMAP_UPDATED)
	local rareGUID = LA.Guid(5001)
	LA.Vignette("v-rare", { name = "Griffe-Grise", objectGUID = rareGUID, vignetteID = 1, atlasName = "VignetteKill", type = 0 })
	Mock:Fire("VIGNETTES_UPDATED")
	Check("[LIVE] rare apparu : le compagnon le signale", QNS.companionBubbleKey == "RARE_LIVE"
		and tostring(QNS.companionBubbleText):find("Griffe-Grise", 1, true) ~= nil, QNS.companionBubbleKey)
	local species = QNS:BestiaryData()[ZONE] and QNS:BestiaryData()[ZONE][5001]
	Check("[LIVE] rare apparu : vu au bestiaire", species and species.seen == true and species.name == "Griffe-Grise")
	Check("[LIVE] rare apparu : retenu par le carnet", QNS.journalRares[rareGUID] ~= nil
		and QNS.journalRares[rareGUID].name == "Griffe-Grise")
	Check("[LIVE] rare apparu : relié au journal de combat", QNS.bestiaryUnits[rareGUID] ~= nil
		and QNS.bestiaryUnits[rareGUID].npcID == 5001)

	-- une fois par créature toutes les 10 min
	LA.Quiet()
	Mock:Fire("VIGNETTES_UPDATED")
	Mock:Fire("VIGNETTE_MINIMAP_UPDATED", "v-rare", true)
	Check("[LIVE] même rare : pas de seconde alerte", QNS.companionBubbleKey == nil)
	Mock.now = Mock.now + QNS.RARE_ALERT_GAP - 5
	LA.Quiet()
	Mock:Fire("VIGNETTES_UPDATED")
	Check("[LIVE] même rare avant 10 min : toujours rien", QNS.companionBubbleKey == nil)
	Mock.now = Mock.now + 10
	LA.Quiet()
	Mock:Fire("VIGNETTE_MINIMAP_UPDATED", "v-rare", true)
	Check("[LIVE] même rare après 10 min : de nouveau signalé", QNS.companionBubbleKey == "RARE_LIVE")

	-- engagé puis mort : le tampon « rare » du carnet, comme un rare ciblé
	LA.W.cleu = { 1000, "SWING_DAMAGE", false, PLAYER_GUID, "moi", 0x511, 0, rareGUID, "rare", 0x10a48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	LA.W.cleu = { 1000, "UNIT_DIED", false, nil, nil, 0, 0, rareGUID, "rare", 0x10a48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	Check("[LIVE] rare signalé puis abattu : tampon au carnet", QNS:HasStamp("rare:5001") == true)
	Check("[LIVE] rare signalé puis abattu : compté au bestiaire", (tonumber(species.killed) or 0) == 1, species.killed)
end

do
	Say("-- API récentes : rare ou pas, valeurs inattendues")
	LA.ResetQC()
	LA.InstallVignettes()
	-- la table dit « normal » : l'icône ne suffit pas
	LA.Vignette("v-wolf", { name = "Loup des plaines", objectGUID = LA.Guid(5002), atlasName = "VignetteKill" })
	-- inconnu de la table : l'icône décide
	LA.Vignette("v-loot", { name = "Coffre", objectGUID = LA.Guid(7777), atlasName = "VignetteLoot" })
	-- pas une créature (trésor) : ignoré
	LA.Vignette("v-object", { name = "Trésor", objectGUID = "GameObject-0-4378-1-12-9999-0000ABCD", atlasName = "VignetteKill" })
	-- hors minicarte : pas encore là
	LA.Vignette("v-far", { name = "Lointain", objectGUID = LA.Guid(8888), atlasName = "VignetteKill", onMinimap = false })
	-- valeurs secrètes : comme si on ne savait pas
	LA.Vignette("v-secret", { name = SECRET, objectGUID = SECRET, atlasName = SECRET })
	-- vignette sans fiche
	LA.W.vignettes[#LA.W.vignettes + 1] = "v-nil"
	local ok, count = pcall(QNS.LiveRareScan, QNS)
	Check("[LIVE] ni normal, ni objet, ni lointain, ni secret : aucune alerte", ok and count == 0
		and QNS.companionBubbleKey == nil, tostring(count))
	Check("[LIVE] le loup normal n'entre pas au bestiaire par la vignette", not (QNS:BestiaryData()[ZONE] or {})[5002])

	LA.Quiet()
	LA.Vignette("v-new", { name = "Inconnu", objectGUID = LA.Guid(6666), atlasName = "VignetteKillElite" })
	Check("[LIVE] inconnu de la table, icône VignetteKill : rare", QNS:LiveRareScan() == 1
		and QNS.companionBubbleKey == "RARE_LIVE")
	Check("[LIVE] inconnu : appris comme rare", ((QNS:BestiaryData()[ZONE] or {})[6666] or {}).class == "rare")

	-- appris rare en jeu (cible), absent de la table : rare même sans icône
	LA.ResetQC()
	LA.InstallVignettes()
	QNS:BestiaryData()[ZONE] = { [4444] = { name = "Croc", class = "rareelite", seen = true, killed = 0 } }
	LA.Vignette("v-learned", { name = "Croc", objectGUID = LA.Guid(4444), atlasName = "" })
	Check("[LIVE] rang appris en jeu : rare", QNS:LiveRareScan() == 1)

	-- l'API en erreur : rien ne casse
	LA.ResetQC()
	LA.InstallVignettes()
	LA.Vignette("v-rare", { name = "Griffe-Grise", objectGUID = LA.Guid(5001), atlasName = "VignetteKill" })
	LA.W.vignetteError = true
	ok = pcall(Mock.Fire, Mock, "VIGNETTES_UPDATED")
	Check("[LIVE] GetVignetteInfo en erreur : sans plantage ni alerte", ok and QNS.companionBubbleKey == nil)
	LA.W.vignetteError = nil
	_G.C_VignetteInfo.GetVignettes = function() error("boom") end
	Check("[LIVE] GetVignettes en erreur : 0", QNS:LiveRareScan() == 0)
	LA.InstallVignettes()

	-- réglages : l'interrupteur, et celui du module
	QNS:DB().companionRareAlert = false
	Check("[LIVE] alerte coupée : rien", QNS:LiveRareScan() == 0 and QNS.companionBubbleKey == nil
		and not (QNS:BestiaryData()[ZONE] or {})[5001])
	QNS:DB().companionRareAlert = nil
	QNS:DB().companionEnabled = false
	Check("[LIVE] module coupé : rien", QNS:LiveRareScan() == 0 and QNS.companionBubbleKey == nil)
	QNS:DB().companionEnabled = nil
	-- en instance : pas de bestiaire de zone, pas d'alerte
	_G.IsInInstance = function() return true, "party" end
	Check("[LIVE] en instance : rien", QNS:LiveRareScan() == 0)
	_G.IsInInstance = function() return false, "none" end
	Check("[LIVE] de retour dehors : signalé", QNS:LiveRareScan() == 1)
end

-- ---------------------------------------------------------------------------
-- 2. Infobulles enrichies
-- ---------------------------------------------------------------------------
-- TooltipDataProcessor du moteur récent : une fonction par sorte de donnée
function LA.InstallProcessor()
	LA.W.postCalls = {}
	Enum.TooltipDataType.Unit, Enum.TooltipDataType.Item = 2, 0
	_G.TooltipDataProcessor = {
		AddTooltipPostCall = function(dataType, fn)
			LA.W.postCalls[dataType] = LA.W.postCalls[dataType] or {}
			table.insert(LA.W.postCalls[dataType], fn)
		end,
	}
end
function LA.PostCall(dataType, tooltip, data)
	for _, fn in ipairs(LA.W.postCalls[dataType] or {}) do fn(tooltip, data) end
end
function LA.Lines() return table.concat(GameTooltip.lines or {}, "|") end
function LA.HoverUnit(guid)
	LA.W.units.mouseover = guid
	GameTooltip.GetUnit = function() return "Créature", "mouseover" end
	GameTooltip:ClearLines()
end

do
	Say("-- API récentes : infobulle des créatures (bestiaire)")
	LA.ResetQC()
	-- au chargement, le harnais n'a pas de type « Unit » : repli OnTooltipSetUnit
	Check("[TT] sans type Unit : repli OnTooltipSetUnit", LA.saved.qcHooks.Unit == "script"
		and type(GameTooltip.hooks and GameTooltip.hooks.OnTooltipSetUnit) == "function")
	LA.HoverUnit(LA.Guid(5001))
	GameTooltip.hooks.OnTooltipSetUnit(GameTooltip)
	Check("[TT] repli : rare de la zone « à abattre · rare »", LA.Lines():find("Bestiaire : à abattre", 1, true)
		and LA.Lines():find("rare", 1, true), LA.Lines())

	-- moteur récent : TooltipDataProcessor, le GUID dans data.guid
	QNS.tooltipHooks = {}
	LA.InstallProcessor()
	Check("[TT] TooltipDataProcessor : accroche par le processeur", QNS:BestiaryHookTooltip() == "processor")
	QNS:BestiaryHookTooltip()
	Check("[TT] accroche posée une seule fois", #(LA.W.postCalls[2] or {}) == 1)
	GameTooltip:ClearLines()
	GameTooltip.GetUnit = nil
	LA.PostCall(2, GameTooltip, { guid = LA.Guid(5002) })
	Check("[TT] processeur : loup normal « à abattre », sans rang", LA.Lines() == "Bestiaire : à abattre", LA.Lines())
	QNS:BestiaryData()[ZONE] = { [5002] = { name = "Loup des plaines", seen = true, killed = 3, class = "normal" } }
	GameTooltip:ClearLines()
	LA.PostCall(2, GameTooltip, { guid = LA.Guid(5002) })
	Check("[TT] déjà abattu : « abattu (3) »", LA.Lines() == "Bestiaire : abattu (3)", LA.Lines())
	GameTooltip:ClearLines()
	LA.PostCall(2, GameTooltip, { guid = LA.Guid(5003) })
	Check("[TT] élite : son rang", LA.Lines():find("élite", 1, true) ~= nil, LA.Lines())
	-- sans data.guid : tooltip:GetUnit()
	LA.HoverUnit(LA.Guid(5001))
	LA.PostCall(2, GameTooltip, {})
	Check("[TT] sans data.guid : lu par GetUnit", LA.Lines():find("rare", 1, true) ~= nil, LA.Lines())

	-- rien pour : un joueur, une créature hors zone, une autre infobulle, une valeur secrète
	GameTooltip:ClearLines()
	LA.PostCall(2, GameTooltip, { guid = PLAYER_GUID })
	LA.PostCall(2, GameTooltip, { guid = LA.Guid(99999) })
	Check("[TT] joueur ou créature hors bestiaire : rien", LA.Lines() == "", LA.Lines())
	local other = CreateFrame("GameTooltip", "ItemRefTooltip")
	function other:AddLine(text) self.added = text end
	LA.PostCall(2, other, { guid = LA.Guid(5001) })
	Check("[TT] autre infobulle que GameTooltip : jamais touchée", other.added == nil)
	GameTooltip:ClearLines()
	GameTooltip.GetUnit = function() return SECRET, SECRET end
	local ok = pcall(LA.PostCall, 2, GameTooltip, { guid = SECRET })
	Check("[TT] valeurs secrètes : sans plantage, rien", ok and LA.Lines() == "", LA.Lines())
	GameTooltip.GetUnit = function() error("no unit") end
	ok = pcall(LA.PostCall, 2, GameTooltip, nil)
	Check("[TT] GetUnit en erreur : sans plantage", ok and LA.Lines() == "")
	QNS:DB().companionEnabled = false
	LA.PostCall(2, GameTooltip, { guid = LA.Guid(5001) })
	Check("[TT] module coupé : rien", LA.Lines() == "")
	QNS:DB().companionEnabled = nil
	_G.IsInInstance = function() return true, "party" end
	LA.PostCall(2, GameTooltip, { guid = LA.Guid(5001) })
	Check("[TT] en instance : rien", LA.Lines() == "")
	_G.IsInInstance = function() return false, "none" end

	-- ni processeur, ni HookScript : aucune accroche, aucune erreur
	QNS.tooltipHooks = {}
	_G.TooltipDataProcessor = nil
	local hook = GameTooltip.HookScript
	GameTooltip.HookScript = nil
	ok = pcall(QNS.BestiaryHookTooltip, QNS)
	Check("[TT] aucune API d'infobulle : rien, sans erreur", ok and QNS.tooltipHooks.Unit == nil)
	GameTooltip.HookScript = hook
	GameTooltip.GetUnit = LA.saved.GetUnit
	Enum.TooltipDataType.Unit = LA.saved.unitType
	QNS.tooltipHooks = LA.saved.qcHooks
	_G.TooltipDataProcessor = LA.saved.TooltipDataProcessor
end

-- R2Q : GetItemInfo complet (classe, sous-classe) et stats, comme reward.lua
local function FullItemInfo(link)
	local d = Mock.world.links and Mock.world.links[link]
	if not d then return nil end
	return d.name, link, d.quality or 2, d.itemLevel or 10, d.minLevel or 1, "Armure", "", 1, d.equipLoc, nil,
		d.sellPrice or 0, d.classID or 4, d.subClassID
end

do
	Say("-- API récentes : infobulle des objets (Ready2Quest)")
	ResetWorld()
	C_Item.GetItemInfo, _G.GetItemInfo = FullItemInfo, FullItemInfo
	C_Item.GetItemStats = function(link) local d = Mock.world.links[link]; return d and d.stats end
	Mock.world.classToken = "WARRIOR"
	Mock.world.level = 20
	Mock.world.links = {
		["[Vieille ceinture]"] = { name = "Vieille ceinture", equipLoc = "INVTYPE_WAIST", subClassID = 3,
			stats = { ITEM_MOD_STRENGTH_SHORT = 2 } },
		["[Belle ceinture]"] = { name = "Belle ceinture", equipLoc = "INVTYPE_WAIST", subClassID = 3,
			stats = { ITEM_MOD_STRENGTH_SHORT = 6 } },
		["[Ceinture usée]"] = { name = "Ceinture usée", equipLoc = "INVTYPE_WAIST", subClassID = 3,
			stats = { ITEM_MOD_STRENGTH_SHORT = 1 } },
		["[Robe de mage]"] = { name = "Robe de mage", equipLoc = "INVTYPE_WAIST", subClassID = 1,
			stats = { ITEM_MOD_INTELLECT_SHORT = 9 } },
		["[Ceinture du 40]"] = { name = "Ceinture du 40", equipLoc = "INVTYPE_WAIST", subClassID = 3, minLevel = 40,
			stats = { ITEM_MOD_STRENGTH_SHORT = 20 } },
		["[Pain]"] = { name = "Pain", classID = 0 },
	}
	Mock.world.equipped = { [6] = "[Vieille ceinture]" }

	local line = NS:RewardItemUpgradeLine("[Belle ceinture]")
	Check("[TT] objet meilleur que le porté : « amélioration » avec l'écart", line
		and line:find("Ready2Quest : amélioration", 1, true) and line:find("+4", 1, true), tostring(line))
	Check("[TT] objet moins bon : rien", NS:RewardItemUpgradeLine("[Ceinture usée]") == nil)
	Check("[TT] l'objet porté lui-même : rien", NS:RewardItemUpgradeLine("[Vieille ceinture]") == nil)
	-- deux anneaux portés : le meilleur, survolé, n'est pas « mieux » que l'autre
	Mock.world.links["[Bon anneau]"] = { name = "Bon anneau", equipLoc = "INVTYPE_FINGER", stats = { ITEM_MOD_STRENGTH_SHORT = 8 } }
	Mock.world.links["[Petit anneau]"] = { name = "Petit anneau", equipLoc = "INVTYPE_FINGER", stats = { ITEM_MOD_STRENGTH_SHORT = 1 } }
	Mock.world.equipped[11], Mock.world.equipped[12] = "[Bon anneau]", "[Petit anneau]"
	Check("[TT] anneau porté, meilleur que l'autre anneau : rien", NS:RewardItemUpgradeLine("[Bon anneau]") == nil)
	Check("[TT] armure que la classe porte mal : rien", NS:RewardItemUpgradeLine("[Robe de mage]") == nil)
	Check("[TT] niveau requis pas atteint : rien", NS:RewardItemUpgradeLine("[Ceinture du 40]") == nil)
	Check("[TT] objet non équipable : rien", NS:RewardItemUpgradeLine("[Pain]") == nil)
	Check("[TT] lien secret ou absent : rien", NS:RewardItemUpgradeLine(SECRET) == nil and NS:RewardItemUpgradeLine(nil) == nil)
	NS:DB().rewardTooltip = false
	Check("[TT] « Montrer dans l'infobulle » coupé : rien", NS:RewardItemUpgradeLine("[Belle ceinture]") == nil)
	NS:DB().rewardTooltip = nil
	NS:DB().rewardEnabled = false
	Check("[TT] module récompense coupé : rien", NS:RewardItemUpgradeLine("[Belle ceinture]") == nil)
	NS:DB().rewardEnabled = nil
	NS.rewardState = { active = true }
	Check("[TT] fenêtre de récompense ouverte : sa propre ligne suffit", NS:RewardItemUpgradeLine("[Belle ceinture]") == nil)
	NS.rewardState = nil
	Check("[TT] chaînes R2Q dans les deux langues", NS.REWARD_STRINGS.en.REWARD_TT_UPGRADE_DELTA ~= nil
		and NS.REWARD_STRINGS.fr.REWARD_TT_UPGRADE ~= nil)

	-- accroche : processeur (moteur récent), puis repli OnTooltipSetItem
	NS.tooltipHooks = {}
	LA.InstallProcessor()
	Check("[TT] objets : accroche par le processeur", NS:RewardHookItemTooltip() == "processor")
	NS:RewardHookItemTooltip()
	Check("[TT] objets : une seule accroche", #(LA.W.postCalls[0] or {}) == 1)
	Mock.world.hoveredLink = "[Belle ceinture]"
	GameTooltip:ClearLines()
	LA.PostCall(0, GameTooltip, {})
	Check("[TT] survol de l'objet : la ligne dans GameTooltip", LA.Lines():find("amélioration", 1, true) ~= nil, LA.Lines())
	Mock.world.hoveredLink = "[Ceinture usée]"
	GameTooltip:ClearLines()
	LA.PostCall(0, GameTooltip, {})
	Check("[TT] survol d'un objet moins bon : infobulle inchangée", LA.Lines() == "", LA.Lines())
	GameTooltip.GetItem = function() error("no item") end
	local ok = pcall(LA.PostCall, 0, GameTooltip, {})
	Check("[TT] GetItem en erreur : sans plantage", ok and LA.Lines() == "")
	GameTooltip.GetItem = LA.saved.GetItem

	NS.tooltipHooks = {}
	_G.TooltipDataProcessor = nil
	Check("[TT] objets sans processeur : repli OnTooltipSetItem", NS:RewardHookItemTooltip() == "script"
		and type(GameTooltip.hooks.OnTooltipSetItem) == "function")
	Mock.world.hoveredLink = "[Belle ceinture]"
	GameTooltip:ClearLines()
	GameTooltip.hooks.OnTooltipSetItem(GameTooltip)
	Check("[TT] repli : la ligne aussi", LA.Lines():find("amélioration", 1, true) ~= nil, LA.Lines())

	NS.tooltipHooks = LA.saved.r2qHooks
	_G.TooltipDataProcessor = LA.saved.TooltipDataProcessor
	Enum.TooltipDataType.Item = LA.saved.itemType
	C_Item.GetItemInfo, C_Item.GetItemStats = LA.saved.cGetItemInfo, LA.saved.cGetItemStats
	_G.GetItemInfo = LA.saved.GetItemInfo
	Mock.world.hoveredLink = nil
	ResetWorld()
end

-- ---------------------------------------------------------------------------
-- 3. Animations du compagnon
-- ---------------------------------------------------------------------------
-- modèle 3D du moteur récent ; `mode` : nil (SetAnimation), "noanim" (sans la
-- méthode), "error" (SetAnimation en erreur)
function LA.InstallModel(mode)
	_G.CreateFrame = function(kind, ...)
		local frame = LA.saved.CreateFrame(kind, ...)
		if kind == "PlayerModel" or kind == "Model" then
			function frame:SetDisplayInfo(id) self.display = id end
			function frame:SetModelScale(s) self.modelScale = s end
			function frame:SetRotation(r) self.rotation = r end
			function frame:SetCamDistanceScale(s) self.cam = s end
			if mode == "error" then
				function frame:SetAnimation() error("animation refused") end
			elseif mode ~= "noanim" then
				function frame:SetAnimation(id) self.anim = id; self.anims = (self.anims or 0) + 1 end
			end
		end
		return frame
	end
end
function LA.ResetModel(mode)
	LA.ResetQC()
	_G.CreateFrame = LA.saved.CreateFrame
	if mode ~= "fallback" then LA.InstallModel(mode) end
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover" }) do
		if QNS[field] then QNS[field]:Hide() end
		QNS[field] = nil
	end
	QNS:CompanionData().animOff = nil
	QNS:CompanionData().sleepy, QNS:CompanionData().sleepyLeft = nil, nil
	QNS:CompanionUpdateVisibility()
	local frame = QNS:EnsureCompanionFrame()
	QNS:CompanionAnimate()
	return frame
end
function LA.Say(pool, args)
	LA.Quiet()
	return QNS:CompanionSay(pool, { force = true, category = "event", args = args or { "X" } })
end

do
	Say("-- API récentes : animations du compagnon")
	local anims = QNS.COMPANION_ANIMS
	Check("[ANIM] numéros nommés : talk 60, cheer 68, dance 69, sit 97, sleep 100, repos 0",
		anims.idle == 0 and anims.talk == 60 and anims.cheer == 68 and anims.dance == 69 and anims.sit == 97 and anims.sleep == 100)
	local frame = LA.ResetModel()
	local model = frame.model
	Check("[ANIM] modèle animable détecté", QNS:CompanionModelAnimates() == true and model.anim == anims.idle)

	Check("[ANIM] une bulle : il parle", LA.Say("KILL") and model.anim == anims.talk)
	Mock:Advance(QNS.COMPANION_TALK_TIME + 0.1)
	Check("[ANIM] … puis revient au repos", model.anim == anims.idle and QNS.companionAnimUntil == nil)

	LA.Say("MISSION_DONE", {})
	Check("[ANIM] mission faite : joie", model.anim == anims.cheer)
	LA.Say("KILL")
	Check("[ANIM] une bulle pendant la joie : la joie continue", model.anim == anims.cheer)
	Mock:Advance(3)
	Check("[ANIM] fin de la joie : repos", model.anim == anims.idle)

	LA.Say("SHINY_KILLED")
	Check("[ANIM] brillante abattue : danse", model.anim == anims.dance)
	Mock:Advance(3.1)
	LA.Say("TREAT_GOLDEN", {})
	Check("[ANIM] coffre doré (friandises) : danse", model.anim == anims.dance)
	Mock:Advance(3.1)

	QNS:CompanionOnLevel(21)
	Check("[ANIM] niveau gagné : joie", model.anim == anims.cheer, model.anim)
	Mock:Advance(3.1)

	LA.Say("IDLE", {})
	Check("[ANIM] long repos (bavardage IDLE) : assis", model.anim == anims.sit)
	LA.Say("MISSION_ALL", {})
	Check("[ANIM] un grand moment le relève", model.anim == anims.cheer)
	Mock:Advance(3.1)

	-- il dort : pas de « talk » qui le ferait parler en dormant
	QNS:CompanionData().sleepy, QNS:CompanionData().sleepyLeft = true, 600
	QNS:CompanionAnimate()
	LA.Say("KILL")
	Check("[ANIM] il dort : il continue de dormir", model.anim == anims.sleep)
	QNS:CompanionData().sleepy, QNS:CompanionData().sleepyLeft = nil, nil
	QNS:CompanionAnimate()

	-- animation coupée pour cette apparence (/qc compagnon anim non talk) : immobile
	QNS:CompanionAnimOff().talk = true
	LA.Say("KILL")
	Check("[ANIM] « talk » coupée pour l'apparence : immobile", model.anim == anims.idle)
	QNS:CompanionAnimOff().talk = nil
	Mock:Advance(2)

	-- SetAnimation en erreur : les bulles passent, rien ne casse
	LA.ResetModel("error")
	local ok, said = pcall(LA.Say, "MISSION_DONE", {})
	Check("[ANIM] SetAnimation en erreur : bulle dite, sans plantage", ok and said == true)
	ok = pcall(Mock.Advance, Mock, 3)
	Check("[ANIM] SetAnimation en erreur : retour au repos sans plantage", ok)

	-- modèle sans SetAnimation : aucune animation tentée, comme avant
	frame = LA.ResetModel("noanim")
	Check("[ANIM] modèle sans SetAnimation : non animable", QNS:CompanionModelAnimates() == false)
	Check("[ANIM] sans SetAnimation : bulle dite, animation inchangée", LA.Say("MISSION_DONE", {}) == true
		and frame.animation == "idle" and QNS.companionAnimUntil == nil)

	-- boussole de repli : aucun fondu de plus à chaque bulle
	frame = LA.ResetModel("fallback")
	Check("[ANIM] boussole de repli", frame.usesFallback == true and QNS:CompanionModelAnimates() == false)
	Check("[ANIM] boussole : bulles sans animation", LA.Say("SHINY_KILLED") == true and frame.animation == "idle"
		and QNS.companionAnimUntil == nil)
	_G.CreateFrame = LA.saved.CreateFrame
end

-- ---------------------------------------------------------------------------
-- Restauration
-- ---------------------------------------------------------------------------
for _, name in ipairs(LA.globals) do _G[name] = LA.saved[name] end
_G.CreateFrame = LA.saved.CreateFrame
QNS.ZONE_CREATURES = LA.saved.ZONE_CREATURES
QNS.tooltipHooks, NS.tooltipHooks = LA.saved.qcHooks, LA.saved.r2qHooks
GameTooltip.GetUnit, GameTooltip.GetItem = LA.saved.GetUnit, LA.saved.GetItem
Enum.TooltipDataType.Unit, Enum.TooltipDataType.Item = LA.saved.unitType, LA.saved.itemType
C_Item.GetItemInfo, C_Item.GetItemStats = LA.saved.cGetItemInfo, LA.saved.cGetItemStats
QNS:DB().companionRareAlert = nil
ResetWorld()
