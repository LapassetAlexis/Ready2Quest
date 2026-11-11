-- API récentes, exploitées seulement quand le client les expose :
--   * rares signalés en direct (C_VignetteInfo, QC LiveRares.lua) ;
--   * infobulles enrichies (TooltipDataProcessor ou OnTooltipSet*, accroche du
--     socle ns:HookTooltip) : bestiaire au survol d'une créature (QC
--     Tooltips.lua), amélioration au survol d'un objet (R2Q QuestReward.lua) ;
--   * animations du compagnon aux grands moments (PlayerModel:SetAnimation) ;
--   * fiche d'objet sûre (socle ns.ItemInfo) ; niveaux des zones
--     (C_Map.GetMapLevels) et des donjons (GetLFGDungeonInfo) ; quêtes
--     proposées sur la carte (C_QuestLine, C_TaskQuest) ;
--   * entrée dans Échap > Options > AddOns (Settings), bouton des addons de
--     la minicarte (AddonCompartmentFrame), boucles espacées (ns.Throttle et
--     horloge de chaque addon).
-- Chaque fois : l'API présente fait son effet ; absente, en erreur, vide, à
-- zéro ou rendant des valeurs secrètes, rien ne casse et l'ancien
-- comportement reste.
local Check, Say, ResetWorld, NS, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.QNS, T.Mock
local unpack = unpack or table.unpack

local failed = {}
local function Want(label, ok) if not ok then failed[#failed + 1] = label end return ok end
local function Verdict(name) Check(name, #failed == 0, table.concat(failed, " | ")); failed = {} end

local SECRET = {}            -- une valeur « secrète » : issecretvalue la reconnaît
local LA = { saved = {}, W = {}, globals = { "C_VignetteInfo", "TooltipDataProcessor", "UnitGUID", "IsInInstance",
	"issecretvalue", "CombatLogGetCurrentEventInfo", "InCombatLockdown", "ItemRefTooltip", "GetItemInfo", "Item",
	"GetLFGDungeonInfo", "GetMaxLevelForPlayerExpansion", "C_QuestLine", "C_TaskQuest", "Settings", "SettingsPanel",
	"AddonCompartmentFrame" } }
for _, name in ipairs(LA.globals) do LA.saved[name] = rawget(_G, name) end
LA.saved.unitType = Enum.TooltipDataType.Unit
LA.saved.itemType = Enum.TooltipDataType.Item
LA.saved.ZONE_CREATURES = rawget(QNS, "ZONE_CREATURES")
LA.saved.ZONE_QUESTS = rawget(QNS, "ZONE_QUESTS")
LA.saved.GetUnit, LA.saved.GetItem = GameTooltip.GetUnit, GameTooltip.GetItem
LA.saved.CreateFrame = _G.CreateFrame
LA.saved.cItem = {}
for key, value in pairs(C_Item) do LA.saved.cItem[key] = value end
LA.saved.GetMapLevels = C_Map.GetMapLevels
LA.saved.Flagged = C_QuestLog.IsQuestFlaggedCompleted
LA.saved.GetTitle = C_QuestLog.GetTitleForQuestID
LA.saved.qcHooks, LA.saved.r2qHooks = QNS.tooltipHooks, NS.tooltipHooks

local ZONE = 1413
local PLAYER_GUID = "Player-1-00000001"
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
	local order = {}
	for index, file in ipairs(_G.TOC_FILES or {}) do order[file] = index end
	Check("[LIVE] LiveRares.lua chargé ; .toc : LiveRares et Tooltips après Bestiary et Notify", QNS.Loaded and QNS.Loaded.LiveRares
		and order["QuestCompanion/LiveRares.lua"] and order["QuestCompanion/LiveRares.lua"] > order["QuestCompanion/Notify.lua"]
		and order["QuestCompanion/Tooltips.lua"] and order["QuestCompanion/Tooltips.lua"] > order["QuestCompanion/Bestiary.lua"])
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
	Check("[LIVE] chaînes et répliques en français et en anglais, mêmes paramètres", #missing == 0
		and #(QNS.COMPANION_POOLS.RARE_LIVE or {}) >= 2, table.concat(missing, ", "))

	-- sans l'API : rien n'écoute, rien ne parle, rien ne casse
	Want("pas d'écoute", QNS:LiveRareListen() == false and not (QNS.liveRareFrame and QNS.liveRareFrame.events.VIGNETTES_UPDATED))
	Mock:Fire("VIGNETTES_UPDATED")
	Want("scan neutre", QNS:LiveRareScan() == 0 and QNS:LiveRareCheck("v1") == false and QNS.companionBubbleKey == nil)
	local row = false
	for _, r in ipairs(QNS.DAILY_OPTION_ROWS or {}) do if r.key == "companionRareAlert" then row = true end end
	Want("pas d'interrupteur", not row)
	Verdict("[LIVE] sans C_VignetteInfo : ni écoute, ni alerte, ni interrupteur dans les réglages")

	-- avec l'API : un rare de la table apparaît sur la minicarte
	LA.InstallVignettes()
	Want("écoute posée", QNS:LiveRareListen() == true and QNS.liveRareFrame.events.VIGNETTES_UPDATED
		and QNS.liveRareFrame.events.VIGNETTE_MINIMAP_UPDATED)
	local rareGUID = LA.Guid(5001)
	LA.Vignette("v-rare", { name = "Griffe-Grise", objectGUID = rareGUID, vignetteID = 1, atlasName = "VignetteKill", type = 0 })
	Mock:Fire("VIGNETTES_UPDATED")
	Want("le compagnon le signale", QNS.companionBubbleKey == "RARE_LIVE"
		and tostring(QNS.companionBubbleText):find("Griffe-Grise", 1, true) ~= nil)
	local species = QNS:BestiaryData()[ZONE] and QNS:BestiaryData()[ZONE][5001]
	Want("vu au bestiaire", species and species.seen == true and species.name == "Griffe-Grise")
	Want("retenu par le carnet", QNS.journalRares[rareGUID] ~= nil and QNS.journalRares[rareGUID].name == "Griffe-Grise")
	Want("relié au journal de combat", QNS.bestiaryUnits[rareGUID] ~= nil and QNS.bestiaryUnits[rareGUID].npcID == 5001)
	Verdict("[LIVE] rare apparu : écoute posée, bulle, bestiaire, carnet, journal de combat")

	-- une fois par créature toutes les 10 min
	LA.Quiet()
	Mock:Fire("VIGNETTES_UPDATED")
	Mock:Fire("VIGNETTE_MINIMAP_UPDATED", "v-rare", true)
	Want("pas de seconde alerte", QNS.companionBubbleKey == nil)
	Mock.now = Mock.now + QNS.RARE_ALERT_GAP - 5
	LA.Quiet()
	Mock:Fire("VIGNETTES_UPDATED")
	Want("avant 10 min : rien", QNS.companionBubbleKey == nil)
	Mock.now = Mock.now + 10
	LA.Quiet()
	Mock:Fire("VIGNETTE_MINIMAP_UPDATED", "v-rare", true)
	Want("après 10 min : signalé", QNS.companionBubbleKey == "RARE_LIVE")
	Verdict("[LIVE] même rare : une alerte par créature toutes les 10 min")

	-- engagé puis mort : le tampon « rare » du carnet, comme un rare ciblé
	LA.W.cleu = { 1000, "SWING_DAMAGE", false, PLAYER_GUID, "moi", 0x511, 0, rareGUID, "rare", 0x10a48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	LA.W.cleu = { 1000, "UNIT_DIED", false, nil, nil, 0, 0, rareGUID, "rare", 0x10a48, 0 }
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	Check("[LIVE] rare signalé puis abattu : tampon au carnet, compté au bestiaire", QNS:HasStamp("rare:5001") == true
		and (tonumber(species.killed) or 0) == 1, species.killed)
end

do
	Say("-- API récentes : rare ou pas, valeurs inattendues")
	LA.ResetQC()
	LA.InstallVignettes()
	LA.Vignette("v-wolf", { name = "Loup des plaines", objectGUID = LA.Guid(5002), atlasName = "VignetteKill" })   -- table : normal
	LA.Vignette("v-loot", { name = "Coffre", objectGUID = LA.Guid(7777), atlasName = "VignetteLoot" })            -- icône : pas un rare
	LA.Vignette("v-object", { name = "Trésor", objectGUID = "GameObject-0-4378-1-12-9999-0000ABCD", atlasName = "VignetteKill" })
	LA.Vignette("v-far", { name = "Lointain", objectGUID = LA.Guid(8888), atlasName = "VignetteKill", onMinimap = false })
	LA.Vignette("v-secret", { name = SECRET, objectGUID = SECRET, atlasName = SECRET })
	LA.W.vignettes[#LA.W.vignettes + 1] = "v-nil"   -- vignette sans fiche
	local ok, count = pcall(QNS.LiveRareScan, QNS)
	Check("[LIVE] ni normal, ni objet, ni lointain, ni secret, ni sans fiche : aucune alerte, le loup pas au bestiaire",
		ok and count == 0 and QNS.companionBubbleKey == nil and not (QNS:BestiaryData()[ZONE] or {})[5002], tostring(count))

	LA.Quiet()
	LA.Vignette("v-new", { name = "Inconnu", objectGUID = LA.Guid(6666), atlasName = "VignetteKillElite" })
	Want("inconnu, icône VignetteKill : rare", QNS:LiveRareScan() == 1 and QNS.companionBubbleKey == "RARE_LIVE")
	Want("appris comme rare", ((QNS:BestiaryData()[ZONE] or {})[6666] or {}).class == "rare")
	-- appris rare en jeu (cible), absent de la table : rare même sans icône
	LA.ResetQC()
	LA.InstallVignettes()
	QNS:BestiaryData()[ZONE] = { [4444] = { name = "Croc", class = "rareelite", seen = true, killed = 0 } }
	LA.Vignette("v-learned", { name = "Croc", objectGUID = LA.Guid(4444), atlasName = "" })
	Want("rang appris en jeu", QNS:LiveRareScan() == 1)
	Verdict("[LIVE] hors table : l'icône décide, ou le rang appris en jeu")

	LA.ResetQC()
	LA.InstallVignettes()
	LA.Vignette("v-rare", { name = "Griffe-Grise", objectGUID = LA.Guid(5001), atlasName = "VignetteKill" })
	LA.W.vignetteError = true
	ok = pcall(Mock.Fire, Mock, "VIGNETTES_UPDATED")
	Want("GetVignetteInfo en erreur", ok and QNS.companionBubbleKey == nil)
	LA.W.vignetteError = nil
	_G.C_VignetteInfo.GetVignettes = function() error("boom") end
	Want("GetVignettes en erreur", QNS:LiveRareScan() == 0)
	Verdict("[LIVE] API en erreur : sans plantage ni alerte")
	LA.InstallVignettes()

	QNS:DB().companionRareAlert = false
	Want("alerte coupée", QNS:LiveRareScan() == 0 and QNS.companionBubbleKey == nil and not (QNS:BestiaryData()[ZONE] or {})[5001])
	QNS:DB().companionRareAlert = nil
	QNS:DB().companionEnabled = false
	Want("module coupé", QNS:LiveRareScan() == 0 and QNS.companionBubbleKey == nil)
	QNS:DB().companionEnabled = nil
	_G.IsInInstance = function() return true, "party" end
	Want("en instance", QNS:LiveRareScan() == 0)
	_G.IsInInstance = function() return false, "none" end
	Want("de retour dehors : signalé", QNS:LiveRareScan() == 1)
	Verdict("[LIVE] alerte coupée, module coupé, en instance : rien ; dehors : signalé")
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
function LA.Hover(guid)
	GameTooltip:ClearLines()
	LA.PostCall(2, GameTooltip, { guid = guid })
	return LA.Lines()
end

do
	Say("-- API récentes : infobulle des créatures (bestiaire)")
	LA.ResetQC()
	-- au chargement, le harnais n'a pas de type « Unit » : repli OnTooltipSetUnit
	LA.HoverUnit(LA.Guid(5001))
	local hooked = LA.saved.qcHooks.Unit == "script" and type(GameTooltip.hooks and GameTooltip.hooks.OnTooltipSetUnit) == "function"
	if hooked then GameTooltip.hooks.OnTooltipSetUnit(GameTooltip) end
	Check("[TT] sans type Unit : repli OnTooltipSetUnit, rare de la zone « à capturer · 15 % · rare »", hooked
		and LA.Lines():find("Créatures : à capturer · 15 %", 1, true) and LA.Lines():find("rare", 1, true), LA.Lines())

	-- moteur récent : TooltipDataProcessor, le GUID dans data.guid
	QNS.tooltipHooks = {}
	LA.InstallProcessor()
	local how = QNS:BestiaryHookTooltip()
	QNS:BestiaryHookTooltip()
	Check("[TT] TooltipDataProcessor : accroche par le processeur, une seule fois", how == "processor"
		and #(LA.W.postCalls[2] or {}) == 1)
	GameTooltip.GetUnit = nil
	local line = LA.Hover(LA.Guid(5002))
	Want("loup normal « à capturer · 50 % » : " .. line, line == "Créatures : à capturer · 50 %")
	Want("élite : son rang", LA.Hover(LA.Guid(5003)):find("élite", 1, true) ~= nil)
	LA.HoverUnit(LA.Guid(5001))
	LA.PostCall(2, GameTooltip, {})
	Want("sans data.guid : GetUnit", LA.Lines():find("rare", 1, true) ~= nil)
	QNS:DB().companionCapture = false
	QNS:BestiaryData()[ZONE] = { [5002] = { name = "Loup des plaines", seen = true, killed = 3, class = "normal" } }
	line = LA.Hover(LA.Guid(5002))
	Want("capture coupée : « Bestiaire : abattu (3) » : " .. line, line == "Bestiaire : abattu (3)")
	QNS:DB().companionCapture = true
	Verdict("[TT] créature : à capturer avec la chance, rang, lue par GetUnit sans data.guid ; capture coupée : la ligne du bestiaire")

	QNS:CaptureData().creatures[5002] = { name = "Loup des plaines", class = "normal" }
	line = LA.Hover(LA.Guid(5002))
	-- 2.14.0 : ses étoiles ; 2.15.0 : le filet reviendra pour un meilleur spécimen
	Want("1 étoile : amélioration possible : " .. line, line:find("^Créatures : capturé ") ~= nil
		and line:find("amélioration possible si tu trouves mieux", 1, true) ~= nil)
	QNS:CaptureData().creatures[5002].stars = 3
	Want("3 étoiles : complète", LA.Hover(LA.Guid(5002)):find("· complète", 1, true) ~= nil)
	QNS:CaptureData().creatures[5002].stars = 1
	QNS:HuntPin(5002, true)
	Want("épinglée", LA.Hover(LA.Guid(5002)):find("épinglée", 1, true) ~= nil)
	QNS:HuntPin(5002, false)
	-- 1.6.0 : la brillante repérée sous la souris parle de SA version
	QNS:ShinyState().live[LA.Guid(5002)] = { npcID = 5002, zoneID = ZONE, name = "Loup des plaines" }
	line = LA.Hover(LA.Guid(5002))
	Want("brillante à capturer : " .. line, line == "Créatures : BRILLANTE · à capturer · 50 %")
	QNS:CaptureData().creatures[5002].shiny = true
	Want("brillante capturée", LA.Hover(LA.Guid(5002)):find("^Créatures : BRILLANTE · capturée ") ~= nil)
	QNS:ShinyState().live[LA.Guid(5002)] = nil
	QNS:CaptureData().creatures[5002] = nil
	Verdict("[TT] créature capturée : étoiles (amélioration possible, complète), épinglée, brillante à capturer ou capturée")

	-- rien pour : un joueur, une créature hors zone, une autre infobulle, une valeur secrète…
	GameTooltip:ClearLines()
	LA.PostCall(2, GameTooltip, { guid = PLAYER_GUID })
	LA.PostCall(2, GameTooltip, { guid = LA.Guid(99999) })
	Want("joueur ou hors bestiaire", LA.Lines() == "")
	local other = CreateFrame("GameTooltip", "ItemRefTooltip")
	function other:AddLine(text) self.added = text end
	LA.PostCall(2, other, { guid = LA.Guid(5001) })
	Want("autre infobulle jamais touchée", other.added == nil)
	GameTooltip:ClearLines()
	GameTooltip.GetUnit = function() return SECRET, SECRET end
	local ok = pcall(LA.PostCall, 2, GameTooltip, { guid = SECRET })
	Want("valeurs secrètes", ok and LA.Lines() == "")
	GameTooltip.GetUnit = function() error("no unit") end
	ok = pcall(LA.PostCall, 2, GameTooltip, nil)
	Want("GetUnit en erreur", ok and LA.Lines() == "")
	QNS:DB().companionEnabled = false
	LA.PostCall(2, GameTooltip, { guid = LA.Guid(5001) })
	Want("module coupé", LA.Lines() == "")
	QNS:DB().companionEnabled = nil
	_G.IsInInstance = function() return true, "party" end
	LA.PostCall(2, GameTooltip, { guid = LA.Guid(5001) })
	Want("en instance", LA.Lines() == "")
	_G.IsInInstance = function() return false, "none" end
	Verdict("[TT] rien (sans plantage) : joueur, hors bestiaire, autre infobulle, secret, GetUnit en erreur, module coupé, instance")

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
		["[Bon anneau]"] = { name = "Bon anneau", equipLoc = "INVTYPE_FINGER", stats = { ITEM_MOD_STRENGTH_SHORT = 8 } },
		["[Petit anneau]"] = { name = "Petit anneau", equipLoc = "INVTYPE_FINGER", stats = { ITEM_MOD_STRENGTH_SHORT = 1 } },
	}
	Mock.world.equipped = { [6] = "[Vieille ceinture]", [11] = "[Bon anneau]", [12] = "[Petit anneau]" }

	local line = NS:RewardItemUpgradeLine("[Belle ceinture]")
	Check("[TT] objet meilleur que le porté : « amélioration » avec l'écart ; chaînes FR et EN", line
		and line:find("Ready2Quest : amélioration", 1, true) and line:find("+4", 1, true)
		and NS.REWARD_STRINGS.en.REWARD_TT_UPGRADE_DELTA ~= nil and NS.REWARD_STRINGS.fr.REWARD_TT_UPGRADE ~= nil, tostring(line))
	local bad = {}
	for _, link in ipairs({ "[Ceinture usée]", "[Vieille ceinture]", "[Bon anneau]", "[Robe de mage]", "[Ceinture du 40]", "[Pain]" }) do
		if NS:RewardItemUpgradeLine(link) ~= nil then bad[#bad + 1] = link end
	end
	if NS:RewardItemUpgradeLine(SECRET) ~= nil or NS:RewardItemUpgradeLine(nil) ~= nil then bad[#bad + 1] = "secret/nil" end
	Check("[TT] rien pour : moins bon, porté, meilleur anneau porté, armure mal portée, niveau requis, non équipable, secret",
		#bad == 0, table.concat(bad, ", "))
	NS:DB().rewardTooltip = false
	Want("« Montrer dans l'infobulle » coupé", NS:RewardItemUpgradeLine("[Belle ceinture]") == nil)
	NS:DB().rewardTooltip = nil
	NS:DB().rewardEnabled = false
	Want("module coupé", NS:RewardItemUpgradeLine("[Belle ceinture]") == nil)
	NS:DB().rewardEnabled = nil
	NS.rewardState = { active = true }
	Want("fenêtre de récompense ouverte", NS:RewardItemUpgradeLine("[Belle ceinture]") == nil)
	NS.rewardState = nil
	Verdict("[TT] réglage coupé, module coupé, fenêtre de récompense ouverte : rien")

	-- accroche : processeur (moteur récent), puis repli OnTooltipSetItem
	NS.tooltipHooks = {}
	LA.InstallProcessor()
	Want("accroche par le processeur", NS:RewardHookItemTooltip() == "processor")
	NS:RewardHookItemTooltip()
	Want("une seule", #(LA.W.postCalls[0] or {}) == 1)
	Mock.world.hoveredLink = "[Belle ceinture]"
	GameTooltip:ClearLines()
	LA.PostCall(0, GameTooltip, {})
	Want("la ligne au survol", LA.Lines():find("amélioration", 1, true) ~= nil)
	Mock.world.hoveredLink = "[Ceinture usée]"
	GameTooltip:ClearLines()
	LA.PostCall(0, GameTooltip, {})
	Want("moins bon : inchangée", LA.Lines() == "")
	GameTooltip.GetItem = function() error("no item") end
	local ok = pcall(LA.PostCall, 0, GameTooltip, {})
	Want("GetItem en erreur", ok and LA.Lines() == "")
	GameTooltip.GetItem = LA.saved.GetItem
	Verdict("[TT] objets : une accroche par le processeur, la ligne au survol, rien sinon, sans plantage")
	NS.tooltipHooks = {}
	_G.TooltipDataProcessor = nil
	local how = NS:RewardHookItemTooltip()
	Mock.world.hoveredLink = "[Belle ceinture]"
	GameTooltip:ClearLines()
	if GameTooltip.hooks.OnTooltipSetItem then GameTooltip.hooks.OnTooltipSetItem(GameTooltip) end
	Check("[TT] objets sans processeur : repli OnTooltipSetItem, la ligne aussi", how == "script"
		and LA.Lines():find("amélioration", 1, true) ~= nil, LA.Lines())

	NS.tooltipHooks = LA.saved.r2qHooks
	_G.TooltipDataProcessor = LA.saved.TooltipDataProcessor
	Enum.TooltipDataType.Item = LA.saved.itemType
	for key, value in pairs(LA.saved.cItem) do C_Item[key] = value end
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
	local frame = LA.ResetModel()
	local model = frame.model
	Check("[ANIM] modèle animable détecté, au repos ; numéros du client nommés", QNS:CompanionModelAnimates() == true
		and model.anim == anims.idle and anims.idle == 0 and anims.talk == 60 and anims.cheer == 68 and anims.dance == 69
		and anims.sit == 97 and anims.sleep == 100)
	local said = LA.Say("KILL") and model.anim == anims.talk
	Mock:Advance(QNS.COMPANION_TALK_TIME + 0.1)
	Check("[ANIM] une bulle : il parle, puis revient au repos", said and model.anim == anims.idle and QNS.companionAnimUntil == nil)

	LA.Say("MISSION_DONE", {})
	Want("mission faite : joie", model.anim == anims.cheer)
	LA.Say("KILL")
	Want("bulle pendant la joie : la joie continue", model.anim == anims.cheer)
	Mock:Advance(3)
	Want("fin de la joie : repos", model.anim == anims.idle)
	LA.Say("SHINY_KILLED")
	Want("brillante abattue : danse", model.anim == anims.dance)
	Mock:Advance(3.1)
	LA.Say("TREAT_GOLDEN", {})
	Want("coffre doré : danse", model.anim == anims.dance)
	Mock:Advance(3.1)
	QNS:CompanionOnLevel(21)
	Want("niveau gagné : joie", model.anim == anims.cheer)
	Mock:Advance(3.1)
	LA.Say("IDLE", {})
	Want("long repos : assis", model.anim == anims.sit)
	LA.Say("MISSION_ALL", {})
	Want("un grand moment le relève", model.anim == anims.cheer)
	Mock:Advance(3.1)
	Verdict("[ANIM] grands moments : joie (mission, niveau), danse (brillante, coffre doré), assis au long repos, relevé")

	-- il dort : pas de « talk » qui le ferait parler en dormant
	QNS:CompanionData().sleepy, QNS:CompanionData().sleepyLeft = true, 600
	QNS:CompanionAnimate()
	LA.Say("KILL")
	Want("il dort : il continue de dormir", model.anim == anims.sleep)
	QNS:CompanionData().sleepy, QNS:CompanionData().sleepyLeft = nil, nil
	QNS:CompanionAnimate()
	-- animation coupée pour cette apparence (/qc compagnon anim non talk) : immobile
	QNS:CompanionAnimOff().talk = true
	LA.Say("KILL")
	Want("« talk » coupée pour l'apparence : immobile", model.anim == anims.idle)
	QNS:CompanionAnimOff().talk = nil
	Mock:Advance(2)
	Verdict("[ANIM] endormi : il dort ; animation coupée pour l'apparence : immobile")

	LA.ResetModel("error")
	local ok, spoke = pcall(LA.Say, "MISSION_DONE", {})
	local ok2 = pcall(Mock.Advance, Mock, 3)
	Check("[ANIM] SetAnimation en erreur : bulle dite, retour au repos, sans plantage", ok and spoke == true and ok2)
	frame = LA.ResetModel("noanim")
	Check("[ANIM] modèle sans SetAnimation : non animable, bulle dite, animation inchangée", QNS:CompanionModelAnimates() == false
		and LA.Say("MISSION_DONE", {}) == true and frame.animation == "idle" and QNS.companionAnimUntil == nil)
	frame = LA.ResetModel("fallback")
	Check("[ANIM] boussole de repli : non animable, bulles sans animation", frame.usesFallback == true
		and QNS:CompanionModelAnimates() == false and LA.Say("SHINY_KILLED") == true and frame.animation == "idle"
		and QNS.companionAnimUntil == nil)
	_G.CreateFrame = LA.saved.CreateFrame
end

-- ---------------------------------------------------------------------------
-- 4. Fiche d'objet sûre (ns.ItemInfo)
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes : fiche d'objet sûre")
	ResetWorld()
	-- 13 retours, dont des nil au milieu : tous rendus, sans troncature
	local FULL = { n = 13, "Épée", "|cff1eff00|Hitem:42|h[Épée]|h|r", 2, 20, 15, "Arme", "Épées", 1, "INVTYPE_WEAPON",
		"Interface\\Icons\\Sword", 1234, nil, 7 }
	local W = { cCalls = 0, gCalls = 0, requested = {} }
	C_Item.GetItemInfo = function(item)
		W.cCalls = W.cCalls + 1
		if item == 42 or item == FULL[2] then return unpack(FULL, 1, FULL.n) end
		return nil
	end
	_G.GetItemInfo = function(item)
		W.gCalls = W.gCalls + 1
		if item == 77 then return "Globale", nil, 3 end
		return nil
	end
	local r = { n = select("#", NS.ItemInfo(42)), NS.ItemInfo(42) }
	Check("[ITEM] ns.ItemInfo dans les deux socles ; C_Item d'abord, 13 retours intacts, lien accepté",
		type(NS.ItemInfo) == "function" and type(QNS.ItemInfo) == "function" and r.n == 13 and r[1] == "Épée"
		and r[11] == 1234 and r[12] == nil and r[13] == 7 and W.gCalls == 0 and (NS.ItemInfo(FULL[2])) == "Épée", tostring(r.n))
	C_Item.GetItemInfo = nil
	local name, _, quality = NS.ItemInfo(77)
	Want("sans C_Item : la globale", name == "Globale" and quality == 3 and W.gCalls == 1)
	_G.GetItemInfo = nil
	local ok, none = pcall(NS.ItemInfo, 77)
	Want("ni l'une ni l'autre", ok and none == nil)
	C_Item.GetItemInfo = function() error("item API refused") end
	ok, none = pcall(NS.ItemInfo, 42)
	Want("API en erreur", ok and none == nil)
	ok, none = pcall(NS.ItemInfo, nil)
	Want("objet nil", ok and none == nil)
	Verdict("[ITEM] repli sur la globale ; absente, en erreur ou objet nil : nil sans erreur")

	-- pas encore en cache : demande de chargement, rappel une fois chargé
	C_Item.GetItemInfo = function() if W.loaded then return "Chargé" end return nil end
	C_Item.RequestLoadItemDataByID = function(id) W.requested[#W.requested + 1] = id end
	local pending = {}
	_G.Item = { CreateFromItemID = function(_, id)
		return { ContinueOnItemLoad = function(_, cb) pending[#pending + 1] = { id = id, cb = cb } end }
	end }
	Want("nil", NS.ItemInfo("|cffffffff|Hitem:555::::|h[x]|h|r") == nil)
	Want("chargement demandé (id du lien)", W.requested[1] == 555)
	Want("sans rappel : pas d'attente", #pending == 0)
	local asked = #W.requested
	NS.ItemInfo(555); NS.ItemInfo(555)
	Want("pas de relance immédiate", #W.requested == asked)
	Mock.now = Mock.now + 6
	NS.ItemInfo(555)
	Want("relance après quelques secondes", #W.requested == asked + 1)
	Verdict("[ITEM] pas en cache : nil, une demande de chargement, relancée après quelques secondes seulement")
	local hits = 0
	local function OnLoad() hits = hits + 1 end
	NS.ItemInfo(556, OnLoad)
	NS.ItemInfo(556, OnLoad)
	local waits = #pending == 1 and pending[1].id == 556
	W.loaded = true
	pending[1].cb()
	Check("[ITEM] avec rappel : une attente par objet, rappel une fois chargé, la fiche répond", waits and hits == 1
		and NS.itemWaits[556] == nil and NS.ItemInfo(556) == "Chargé")
	W.loaded = false
	_G.Item = { CreateFromItemID = function() error("no item mixin") end }
	ok = pcall(NS.ItemInfo, 557, OnLoad)
	local noWait = NS.itemWaits[557] == nil
	_G.Item, C_Item.RequestLoadItemDataByID = nil, nil
	local ok2 = pcall(NS.ItemInfo, 558, OnLoad)
	Check("[ITEM] Item en erreur ou sans API de chargement : sans plantage, pas d'attente", ok and noWait and ok2)

	-- les appelants : C_Item d'abord, la globale en repli, mêmes résultats
	for key, value in pairs(LA.saved.cItem) do C_Item[key] = value end
	_G.GetItemInfo = LA.saved.GetItemInfo
	Mock.world.links = Mock.world.links or {}
	Mock.world.links["item:900"] = { name = "Heaume", quality = 3, itemLevel = 25, equipLoc = "INVTYPE_HEAD", texture = "T900" }
	local data = NS.ItemData("item:900")
	local byC = data and data.name == "Heaume" and data.quality == 3 and data.texture == "T900"
	local cInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = nil
	_G.GetItemInfo = cInfo   -- celle du mock passe par C_Item : une vraie globale
	data = NS.ItemData("item:900")
	Check("[ITEM] Equip : notice par C_Item, ou par la globale sans C_Item", byC and data and data.itemLevel == 25)
	C_Item.GetItemInfo, _G.GetItemInfo = cInfo, LA.saved.GetItemInfo

	-- plus aucun appel direct à GetItemInfo hors du socle (Compat.lua)
	local direct = {}
	local root = rawget(_G, "ADDON_ROOT") or "."
	for _, file in ipairs(_G.TOC_FILES or {}) do
		if not file:find("/Libs/Socle/Compat%.lua$") then
			local handle = io.open(root .. "/" .. file, "r")
			if handle then
				local number = 0
				for text in handle:lines() do
					number = number + 1
					local code = text:gsub("%-%-.*$", "")
					local at = code:find("GetItemInfo", 1, true)
					while at do
						if code:sub(at + 11, at + 17) ~= "Instant" then direct[#direct + 1] = file .. ":" .. number; break end
						at = code:find("GetItemInfo", at + 1, true)
					end
				end
				handle:close()
			end
		end
	end
	Check("[ITEM] tous les appels passent par ns.ItemInfo", #direct == 0 and #(_G.TOC_FILES or {}) > 0, table.concat(direct, ", "))
end

-- ---------------------------------------------------------------------------
-- 5. Tranche de niveaux des zones (C_Map.GetMapLevels)
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes : niveaux des zones")
	ResetWorld()
	local function Forget() for _, ns in ipairs({ NS, QNS }) do for k in pairs(ns.mapLevelCache) do ns.mapLevelCache[k] = nil end end end
	local function Same(range, a, b) return type(range) == "table" and range[1] == a and range[2] == b end
	C_Map.GetMapLevels = nil
	Forget()
	Check("[ZLVL] sans l'API : pas de tranche du jeu, la table (Les Tarides 10-25), zone inconnue rien",
		NS:MapLevelRange(1413) == nil and Same(QNS:ZoneLevelRange(1413), 10, 25) and QNS:ZoneLevelRange(424242) == nil)

	local W = { calls = 0, levels = {} }
	C_Map.GetMapLevels = function(mapID)
		W.calls = W.calls + 1
		if W.error then error("map levels refused") end
		local v = W.levels[mapID]
		if v then return v[1], v[2], 0, 0 end
		return nil
	end
	W.levels[1413] = { 12, 22 }
	W.levels[424242] = { 30, 35 }
	Forget()
	Want("la table établie l'emporte", Same(QNS:ZoneLevelRange(1413), 10, 25))
	Want("zone absente des tables : le jeu", Same(QNS:ZoneLevelRange(424242), 30, 35))
	local before = W.calls
	QNS:ZoneLevelRange(424242); QNS:ZoneLevelRange(424242); QNS:MapLevelRange(424242)
	Want("mise en cache par carte", W.calls == before)
	Want("R2Q : même source", Same(NS:MapLevelRange(1413), 12, 22))
	Want("réponse vide : rien", NS:MapLevelRange(515151) == nil)
	W.levels[515151] = { 40, 45 }
	Want("réponse vide : redemandée", Same(NS:MapLevelRange(515151), 40, 45))
	Want("palier d'après le jeu", QNS:ZoneTier(424242) == 2)
	Verdict("[ZLVL] avec l'API : table d'abord, le jeu pour les zones absentes, cache par carte (pas les réponses vides), palier")

	local bad = {}
	for label, value in pairs({ ["0/0"] = { 0, 0 }, ["secrètes"] = { SECRET, SECRET }, ["incohérentes"] = { 20, 10 },
		["non numériques"] = { "a", "b" }, ["nil"] = false }) do
		W.levels[1413] = value or nil
		Forget()
		if not Same(QNS:ZoneLevelRange(1413), 10, 25) then bad[#bad + 1] = label end
	end
	W.error = true
	Forget()
	local ok, range = pcall(QNS.ZoneLevelRange, QNS, 1413)
	if not (ok and Same(range, 10, 25)) then bad[#bad + 1] = "erreur" end
	Check("[ZLVL] valeurs inexploitables (0/0, secrètes, incohérentes, non numériques, nil, erreur) : la table", #bad == 0,
		table.concat(bad, ", "))
	C_Map.GetMapLevels = LA.saved.GetMapLevels
	Forget()
end

-- ---------------------------------------------------------------------------
-- 6. Niveaux des donjons (GetLFGDungeonInfo)
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes : niveaux des donjons")
	ResetWorld()
	local function Forget() NS.lfgDungeonCache.ranges, QNS.lfgDungeonCache.ranges = nil, nil end
	local D = NS.DUNGEONS
	_G.GetLFGDungeonInfo = nil
	Forget()
	local low, high = NS:DungeonRange(D.dm)
	Check("[LFG] sans l'API : DungeonData (Mortemines 17-26), verdict inchangé", low == 17 and high == 26
		and NS:DungeonVerdict(D.dm, 17) == "ok")

	-- une fiche GetLFGDungeonInfo : 22 retours
	local function Row(name, typeID, minL, maxL, minRec, maxRec, mapID, extra)
		extra = extra or {}
		local r = { n = 22 }
		r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] = name, typeID, 0, minL, maxL, minRec, minRec, maxRec
		r[12] = extra.difficulty or 1
		r[15], r[18], r[22] = extra.holiday or false, extra.timewalker or false, mapID
		return r
	end
	local W = { calls = 0, rows = {} }
	W.rows[10] = Row("Les Mortemines", 1, 10, 60, 18, 23, 36)
	W.rows[11] = Row("Les Mortemines", 1, 85, 90, 85, 90, 36, { difficulty = 2 })  -- héroïque : écarté
	W.rows[20] = Row("Monastère : Cimetière", 1, 20, 60, 28, 38, 189)              -- ailes : union
	W.rows[21] = Row("Monastère : Cathédrale", 1, 20, 60, 34, 45, 189)
	W.rows[30] = Row("The Drowned City", 1, 30, 60, 36, 41, 0)                     -- sans map : par le nom
	W.rows[40] = Row("Cavernes des Lamentations", 1, 10, 60, 10, 60, 43)           -- à l'échelle : écarté
	W.rows[50] = Row("Ombrecroc", 1, 10, 60, 20, 30, 33, { holiday = true })      -- événement : écarté
	W.rows[60] = Row("Gnomeregan", 2, 10, 60, 30, 35, 90)                          -- raid : écarté
	W.rows[70] = Row("Uldaman", 1, 0, 0, 0, 0, 70)                                 -- zéros : écarté
	W.rows[80] = Row(SECRET, SECRET, SECRET, SECRET, SECRET, SECRET, SECRET)        -- secret : écarté
	W.rows[2999] = Row("Hautbrande", 1, 30, 60, 32, 48, 47)                         -- Kraal, au bout de la plage
	_G.GetMaxLevelForPlayerExpansion = function() return 60 end
	_G.GetLFGDungeonInfo = function(id)
		W.calls = W.calls + 1
		if W.error then error("lfg refused") end
		local r = W.rows[id]
		if r then return unpack(r, 1, r.n) end
		return nil
	end
	Forget()
	low, high = NS:DungeonRange(D.dm)
	local calls = W.calls
	NS:DungeonRange(D.sm); NS:DungeonRange(D.dm)
	Check("[LFG] avec l'API : le jeu l'emporte (Mortemines 18-23), une seule passe bornée, gardée en cache", low == 18 and high == 23
		and calls == 3000 and W.calls == 3000, tostring(low) .. "-" .. tostring(high) .. " / " .. calls)
	low, high = NS:DungeonRange(D.sm)
	Want("ailes : union", low == 28 and high == 45)
	low, high = NS:DungeonRange(D.drowned)
	Want("sans map : par le nom", low == 36 and high == 41)
	low, high = NS:DungeonRange(D.rfk)
	Want("dernier id de la plage", low == 32 and high == 48)
	Want("verdict d'après le jeu", NS:DungeonVerdict(D.dm, 17) == "low" and NS:DungeonVerdict(D.dm, 24) == "grey")
	Want("QC : même source", QNS:DungeonRange(D.dm) == 18)
	Verdict("[LFG] ailes réunies, donjon relié par son nom, plage lue jusqu'au bout, verdict et QC d'après le jeu")
	local bad = {}
	for _, case in ipairs({ { "wc", 15, 24, "à l'échelle" }, { "sfk", 20, 30, "événement" },
		{ "gnomer", 29, 38, "raid" }, { "ulda", 41, 51, "zéros" }, { "brd", 52, 60, "absent" } }) do
		low, high = NS:DungeonRange(D[case[1]])
		if not (low == case[2] and high == case[3]) then bad[#bad + 1] = case[4] .. "=" .. tostring(low) .. "-" .. tostring(high) end
	end
	W.rows[10] = Row("Les Mortemines", 1, 10, 60, 55, 65, 36)
	Forget()
	if NS:DungeonRange(D.dm) ~= 17 then bad[#bad + 1] = "au-delà du niveau maximum" end
	Check("[LFG] écartés (héroïque, à l'échelle, événement, raid, zéros, secret, au-delà du max) : DungeonData", #bad == 0,
		table.concat(bad, ", "))

	-- rien d'exploitable : DungeonData, nouvel essai au plus toutes les minutes
	local rows = W.rows
	W.rows = {}
	Forget()
	Want("l'API ne rend rien", NS:DungeonRange(D.dm) == 17)
	W.rows = rows
	W.rows[10] = Row("Les Mortemines", 1, 10, 60, 18, 23, 36)
	Mock.now = Mock.now + 30
	Want("avant une minute : pas de nouvel essai", NS:DungeonRange(D.dm) == 17)
	Mock.now = Mock.now + 31
	Want("après une minute : nouvel essai", NS:DungeonRange(D.dm) == 18)
	-- balayages vides répétés : trois essais au plus, puis on s'arrête
	W.rows = {}
	Forget()
	NS.lfgDungeonCache.tries = 0
	local scans = 0
	local realInfo = _G.GetLFGDungeonInfo
	_G.GetLFGDungeonInfo = function(...) if select(1, ...) == 1 then scans = scans + 1 end return realInfo(...) end
	for _ = 1, 6 do NS:DungeonRange(D.dm); Mock.now = Mock.now + 61 end
	Want("balayages vides : trois essais au plus (" .. scans .. ")", scans == 3)
	_G.GetLFGDungeonInfo = realInfo
	W.rows = rows
	NS.lfgDungeonCache.tries = 0
	W.error = true
	Forget()
	local ok, value = pcall(NS.DungeonRange, NS, D.dm)
	Want("API en erreur", ok and value == 17)
	Verdict("[LFG] rien d'exploitable ou erreur : DungeonData, nouvel essai par minute, trois balayages vides au plus")
	_G.GetLFGDungeonInfo = nil
	Forget()
end

-- ---------------------------------------------------------------------------
-- 7. Quêtes proposées sur la carte (C_QuestLine, C_TaskQuest)
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes : quêtes proposées sur la carte")
	local W = { done = {}, requests = 0 }
	local function Reset()
		ResetWorld()
		Mock.world.maps[ZONE] = { mapID = ZONE, name = "Les Tarides", parentMapID = 0, mapType = 3 }
		Mock.world.mapID = ZONE
		QNS.ZONE_QUESTS = { [ZONE] = { [100] = { en = "Static A", fr = "Statique A", lvl = 10 },
			[101] = { en = "Static B", fr = "Statique B", lvl = 12 } } }
		local state = QNS.zoneQuests
		state.done, state.lists, state.live, state.requested, state.dirty = {}, {}, {}, {}, false
		QNS:DB().companionEnabled, QNS:DB().enabled = nil, nil
		W.done, W.requests = {}, 0
	end
	C_QuestLog.IsQuestFlaggedCompleted = function(id) return W.done[id] == true end
	C_QuestLog.GetTitleForQuestID = function(id) return id == 301 and "Titre du journal" or nil end
	local function LiveHead(rows)
		for _, row in ipairs(rows) do if row.header and row.live then return row end end
		return nil
	end

	Reset()
	_G.C_QuestLine, _G.C_TaskQuest = nil, nil
	local baseline = QNS:JournalActivityRows(ZONE, "quests")
	Check("[QMAP] sans l'API : aucune quête du jeu, onglet Quêtes inchangé (en-tête + 2)", #QNS:ZoneLiveQuests(ZONE) == 0
		and #baseline == 3 and LiveHead(baseline) == nil, #baseline)

	W.lines = {
		{ questID = 100, questName = "Static A" },        -- déjà dans la table
		{ questID = 200, questName = "Nouvelle B" },
		{ questID = 201, questName = "Faite" },           -- déjà faite
		{ questID = SECRET, questName = "Secrète" },      -- secrète
		{ questID = 0, questName = "Zéro" },
		"pas une table",
	}
	W.tasks = { { questId = 300 }, { questID = 200 }, { questID = 301 } }
	W.done[201] = true
	_G.C_QuestLine = {
		RequestQuestLinesForMap = function(mapID) W.requests = W.requests + 1; W.requestedMap = mapID end,
		GetAvailableQuestLines = function(mapID)
			if W.error then error("questline refused") end
			return mapID == ZONE and W.lines or nil
		end,
	}
	_G.C_TaskQuest = {
		GetQuestsOnMap = function(mapID)
			if W.error then error("task refused") end
			return mapID == ZONE and W.tasks or nil
		end,
		GetQuestInfoByQuestID = function(id) return id == 300 and "Tâche C" or nil end,
	}
	local state = QNS.zoneQuests
	state.live, state.requested = {}, {}
	local live = QNS:ZoneLiveQuests(ZONE)
	local ids = {}
	for _, quest in ipairs(live) do ids[quest.id] = quest.name end
	Want("absentes de la table, pas faites (" .. #live .. ")", #live == 3 and ids[200] == "Nouvelle B" and ids[300] == "Tâche C"
		and ids[301] == "Titre du journal")
	Want("ni doublon, ni faite, ni secrète", ids[100] == nil and ids[201] == nil)
	Want("marquées « sur la carte », à faire", live[1].live == true and live[1].done == false and live[1].detail == QNS.L.ZQ_LIVE)
	QNS:ZoneLiveQuests(ZONE)
	Want("demandées une fois pour la carte, liste en cache", W.requests == 1 and W.requestedMap == ZONE
		and QNS:ZoneLiveQuests(ZONE) == live)
	Verdict("[QMAP] quêtes du jeu : absentes de la table, ni faites ni secrètes, demandées une fois, en cache")
	local rows = QNS:JournalActivityRows(ZONE, "quests")
	local head = LiveHead(rows)
	Check("[QMAP] onglet Quêtes : en-tête « sur la carte » et ses quêtes, la table reste la référence, pas dans un autre onglet",
		head ~= nil and #rows == #baseline + 4 and head.name == QNS:F("ZQ_LIVE_HEAD", 3) and rows[1].name == baseline[1].name
		and QNS:ZoneQuestsPart(ZONE).need == 2 and LiveHead(QNS:JournalActivityRows(ZONE, "explore")) == nil, head and head.name)
	W.lines[#W.lines + 1] = { questID = 202, questName = "Arrivée" }
	Mock:Fire("QUESTLINE_UPDATE")
	Want("QUESTLINE_UPDATE : relue", #QNS:ZoneLiveQuests(ZONE) == 4 and W.requests == 1)
	W.done[200] = true
	Mock:Fire("QUEST_TURNED_IN", 200)
	Want("rendue : retirée", #QNS:ZoneLiveQuests(ZONE) == 3)
	QNS.ZONE_QUESTS = nil
	state.live = {}
	Want("client sans table : listées", #QNS:ZoneLiveQuests(ZONE) == 4)
	QNS:DB().companionEnabled = false
	state.live = {}
	Want("compagnon coupé : rien", #QNS:ZoneLiveQuests(ZONE) == 0)
	Verdict("[QMAP] relue à QUESTLINE_UPDATE, rendue retirée, sans table listée, compagnon coupé rien")

	Reset()
	W.lines, W.tasks = {}, nil
	Want("API vide", #QNS:ZoneLiveQuests(ZONE) == 0 and #QNS:JournalActivityRows(ZONE, "quests") == #baseline)
	Reset()
	W.error = true
	local ok, list = pcall(QNS.ZoneLiveQuests, QNS, ZONE)
	Want("API en erreur : rien", ok and #list == 0)
	ok, rows = pcall(QNS.JournalActivityRows, QNS, ZONE, "quests")
	Want("API en erreur : onglet inchangé", ok and #rows == #baseline)
	Verdict("[QMAP] API vide ou en erreur : comme sans l'API")
end

-- ---------------------------------------------------------------------------
-- 8. Échap > Options > AddOns, bouton des addons de la minicarte
-- ---------------------------------------------------------------------------
-- Remet les deux addons « avant connexion » : rien d'inscrit
function LA.ResetLogin()
	for _, ns in ipairs({ NS, QNS }) do
		ns.settingsTried, ns.settingsCategory, ns.settingsCanvas, ns.compartmentEntry = nil, nil, nil, nil
	end
	_G.Settings, _G.SettingsPanel, _G.AddonCompartmentFrame = nil, nil, nil
end
function LA.InstallSettings(fail)
	local W = { categories = {}, added = {} }
	_G.Settings = {
		RegisterCanvasLayoutCategory = function(frame, name)
			if fail then error("settings refused") end
			local category = { frame = frame, name = name, id = 100 + #W.categories }
			function category:GetID() return self.id end
			W.categories[#W.categories + 1] = category
			return category
		end,
		RegisterAddOnCategory = function(category) W.added[#W.added + 1] = category end,
	}
	_G.SettingsPanel = { shown = true }
	function SettingsPanel:Hide() self.shown = false end
	return W
end
function LA.InstallCompartment(fail)
	local W = { entries = {} }
	_G.AddonCompartmentFrame = {
		RegisterAddon = function(self, info)
			if fail then error("compartment refused") end
			W.self = self
			W.entries[#W.entries + 1] = info
		end,
	}
	return W
end

do
	Say("-- API récentes : entrée dans les options du jeu")
	ResetWorld()
	LA.ResetLogin()
	Check("[SET] chaînes en français et en anglais", NS.L.SETTINGS_OPEN == "Ouvrir les réglages"
		and type(NS.L.SETTINGS_HINT) == "string" and NS.L.SETTINGS_HINT ~= "SETTINGS_HINT"
		and NS.L.SETTINGS_VERSION:find("%s", 1, true) ~= nil)
	local ok = pcall(Mock.Fire, Mock, "PLAYER_LOGIN")
	Check("[SET] sans Settings : connexion sans erreur, rien d'inscrit", ok and NS.settingsCategory == nil
		and QNS.settingsCategory == nil and NS:RegisterSettingsCategory() == nil)

	local W = LA.InstallSettings()
	Mock:Fire("PLAYER_LOGIN")
	Mock:Fire("PLAYER_LOGIN")
	NS:RegisterSettingsCategory()
	QNS:RegisterSettingsCategory()
	Check("[SET] connexion : une catégorie par addon, à son nom, inscrite une seule fois et gardée", #W.categories == 2 and #W.added == 2
		and NS.settingsCategory and NS.settingsCategory.name == "Ready2Quest" and QNS.settingsCategory
		and QNS.settingsCategory.name == "QuestCompanion" and W.added[1] == W.categories[1] and W.added[2] == W.categories[2]
		and NS.settingsCategory:GetID() == NS.settingsCategory.id, #W.categories)
	local canvas = NS.settingsCanvas
	Check("[SET] page native (pas le grand panneau) : titre, version, une ligne, le bouton ; QC son titre", canvas
		and canvas ~= NS.optionsFrame and W.categories[1].frame == canvas and canvas.title.text == NS.APP.brand
		and canvas.version.text == string.format(NS.L.SETTINGS_VERSION, NS.APP.version) and canvas.hint.text == NS.L.SETTINGS_HINT
		and canvas.open ~= nil and QNS.settingsCanvas.title.text == (QNS.APP.brand or "QuestCompanion"))

	if NS.optionsFrame then NS.optionsFrame:Hide() end
	canvas.open:Click()
	Want("options du jeu fermées, nos réglages ouverts", SettingsPanel.shown == false and NS.optionsFrame and NS.optionsFrame:IsShown() == true)
	SettingsPanel.shown = true
	canvas.open:Click()
	Want("second clic : restent ouverts", NS.optionsFrame:IsShown() == true and SettingsPanel.shown == false)
	NS.optionsFrame:Hide()
	QNS.settingsCanvas.open:Click()
	Want("QC : ses propres réglages", QNS.optionsFrame and QNS.optionsFrame:IsShown() == true and not NS.optionsFrame:IsShown())
	QNS.optionsFrame:Hide()
	_G.SettingsPanel = nil
	ok = pcall(canvas.open.Click, canvas.open)
	Want("sans SettingsPanel : ouvre", ok and NS.optionsFrame:IsShown() == true)
	NS.optionsFrame:Hide()
	Verdict("[SET] bouton : ferme les options du jeu, ouvre les réglages de son addon")

	LA.ResetLogin()
	local errors = #NS.errors
	W = LA.InstallSettings(true)
	ok = pcall(Mock.Fire, Mock, "PLAYER_LOGIN")
	Check("[SET] API en erreur : rien d'inscrit, sans erreur", ok and NS.settingsCategory == nil and #W.added == 0 and #NS.errors == errors)
	LA.ResetLogin()
end

do
	Say("-- API récentes : bouton des addons de la minicarte")
	ResetWorld()
	LA.ResetLogin()
	local ok = pcall(Mock.Fire, Mock, "PLAYER_LOGIN")
	Check("[CMP] sans AddonCompartmentFrame : rien, sans erreur", ok and NS.compartmentEntry == nil
		and QNS:RegisterAddonCompartment() == nil)

	local W = LA.InstallCompartment()
	Mock:Fire("PLAYER_LOGIN")
	Mock:Fire("PLAYER_LOGIN")
	NS:RegisterAddonCompartment()
	local r2q, qc = W.entries[1], W.entries[2]
	if r2q and r2q.text ~= "Ready2Quest" then r2q, qc = qc, r2q end
	Check("[CMP] une entrée par addon, une seule fois, à son nom, icône de la minicarte, non cochable", #W.entries == 2
		and W.self == AddonCompartmentFrame and r2q.text == "Ready2Quest" and qc.text == "QuestCompanion"
		and r2q.icon == NS.Theme.LOGO_SMALL and r2q.icon == NS:EnsureMinimapButton().icon.texture
		and r2q.notCheckable == true and qc.notCheckable == true, #W.entries)

	local calls = {}
	local defaults = { NS.DefaultCommand, QNS.DefaultCommand }
	NS.DefaultCommand = function() calls[#calls + 1] = "r2q" end
	QNS.DefaultCommand = function() calls[#calls + 1] = "qc" end
	r2q.func()
	qc.func()
	NS.minimapDragMoved = nil
	NS:EnsureMinimapButton():Click("LeftButton")
	Check("[CMP] clic : même action que le clic gauche de la minicarte", calls[1] == "r2q" and calls[2] == "qc"
		and calls[3] == "r2q", table.concat(calls, ","))
	NS.DefaultCommand, QNS.DefaultCommand = defaults[1], defaults[2]

	-- infobulle : nom, lignes de l'addon, clic gauche ; pas celles du bouton
	local setOwner, owner = GameTooltip.SetOwner, nil
	GameTooltip.SetOwner = function(_, o) owner = o end
	NS.score = 88
	GameTooltip.lines = {}
	local hover = CreateFrame("Button")
	r2q.funcOnEnter(hover)
	local text = table.concat(GameTooltip.lines, "\n")
	Want("au nom de l'addon", GameTooltip.shown == true and owner == hover and GameTooltip.lines[1] == NS.L.ADDON_NAME)
	Want("lignes de l'addon et clic gauche", text:find("88", 1, true) ~= nil and text:find(NS.L.MINIMAP_LEFT, 1, true) ~= nil)
	Want("sans glisser ni clic droit", text:find(NS.L.MINIMAP_DRAG, 1, true) == nil and text:find(NS.L.MINIMAP_RIGHT, 1, true) == nil)
	r2q.funcOnLeave(hover)
	Want("sortie : masquée", GameTooltip.shown == false)
	GameTooltip.lines = {}
	qc.funcOnEnter()
	Want("sans cadre : ancrée au bouton des addons", owner == AddonCompartmentFrame and GameTooltip.lines[1] == QNS.L.ADDON_NAME)
	GameTooltip.lines = {}
	NS:EnsureMinimapButton().scripts.OnEnter(NS.minimapButton)
	text = table.concat(GameTooltip.lines, "\n")
	Want("bouton de minicarte : infobulle inchangée", text:find(NS.L.MINIMAP_DRAG, 1, true) ~= nil
		and text:find(NS.L.MINIMAP_RIGHT, 1, true) ~= nil and owner == NS.minimapButton)
	Verdict("[CMP] infobulle : nom et lignes de l'addon, clic gauche seulement ; celle de la minicarte inchangée")
	GameTooltip.SetOwner = setOwner
	GameTooltip:Hide()

	LA.ResetLogin()
	W = LA.InstallCompartment(true)
	ok = pcall(Mock.Fire, Mock, "PLAYER_LOGIN")
	Check("[CMP] API en erreur : rien, sans erreur, pas de nouvel essai", ok and NS.compartmentEntry == false
		and NS:RegisterAddonCompartment() == nil)
	LA.ResetLogin()
end

-- ---------------------------------------------------------------------------
-- 9. Boucles OnUpdate espacées
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes : boucles OnUpdate espacées")
	ResetWorld()
	local runs = {}
	Want("dans les deux socles", type(NS.Throttle) == "function" and type(QNS.Throttle) == "function")
	local handler = NS.Throttle(0.2, function(frame, step, extra) runs[#runs + 1] = { frame = frame, step = step, extra = extra } end)
	local me = {}
	handler(me, 0.05)
	handler(me, 0.1)
	Want("rien avant l'intervalle", #runs == 0)
	handler(me, 0.05, "x")
	Want("intervalle atteint : un passage", #runs == 1 and runs[1].frame == me and runs[1].extra == "x")
	Want("temps cumulé", runs[1] and math.abs(runs[1].step - 0.2) < 1e-9)
	handler(me, 0.19)
	Want("cumul remis à zéro", #runs == 1)
	handler(me, 1.5)
	Want("grand écart : un passage", #runs == 2 and math.abs(runs[2].step - 1.69) < 1e-9)
	handler(me, nil)
	handler(me, "?")
	Want("écart illisible : zéro", #runs == 2)
	for _ = 1, 60 do handler(me, 1 / 60) end
	Want("60 images : 4 à 5 passages (" .. (#runs - 2) .. ")", #runs - 2 <= 5 and #runs - 2 >= 4)
	Verdict("[THR] ns.Throttle (deux socles) : un passage par intervalle avec le temps cumulé, écart illisible compté zéro")

	-- Boucles réelles, sur l'horloge de chaque addon (fiche 25) : au plus un
	-- passage par intervalle à 60 images/s (un premier grand écart vide le cumul)
	local function Tick(clock, seconds) clock.scripts.OnUpdate(clock, seconds) end
	local exitCalls, placeCalls, campCalls = 0, 0, 0
	local update, place, pending, camp = NS.UpdatePendingExit, NS.CheckPlaceMove, NS.pendingExit, NS.UpdateCampFrame
	NS.UpdatePendingExit = function() exitCalls = exitCalls + 1 end
	NS.CheckPlaceMove = function() placeCalls = placeCalls + 1 end
	NS.UpdateCampFrame = function() campCalls = campCalls + 1 end
	NS.pendingExit = { at = 0 }
	Tick(NS.clockFrame, 1)
	exitCalls, placeCalls, campCalls = 0, 0, 0
	for _ = 1, 60 do Tick(NS.clockFrame, 1 / 60) end
	Check("[THR] R2Q : sortie en attente et lieux au plus 10 par seconde (EXIT_TICK), camp au plus 4", exitCalls >= 8
		and exitCalls <= 10 and placeCalls == exitCalls and NS.EXIT_TICK == 0.1 and campCalls >= 3 and campCalls <= 4,
		exitCalls .. "/" .. placeCalls .. "/" .. campCalls)
	NS.UpdatePendingExit, NS.CheckPlaceMove, NS.pendingExit, NS.UpdateCampFrame = update, place, pending, camp

	-- QC : brillants (0,1 s), annonces (0,2 s), éclat (chaque image, tant qu'il luit)
	local counts = { shiny = 0, aura = 0, flush = 0, glow = 0 }
	local saved = { QNS.ChestRevealStep, QNS.ShinyAuraTick, QNS.NotifyFlush, QNS.GlowUpdate }
	local glowing = 0.5
	QNS.ChestRevealStep = function() counts.shiny = counts.shiny + 1 end
	QNS.ShinyAuraTick = function() counts.aura = counts.aura + 1 end
	QNS.NotifyFlush = function() counts.flush = counts.flush + 1 end
	QNS.GlowUpdate = function() counts.glow = counts.glow + 1; return glowing end
	QNS:NotifyGlowArm()
	Tick(QNS.clockFrame, 1)
	for key in pairs(counts) do counts[key] = 0 end
	for _ = 1, 60 do Tick(QNS.clockFrame, 1 / 60) end
	Check("[THR] QC : coffre et aura au plus 10 par seconde, annonces au plus 5, éclat à chaque image tant qu'il luit",
		counts.shiny >= 8 and counts.shiny <= 10 and counts.aura == counts.shiny and counts.flush >= 4 and counts.flush <= 5
		and counts.glow == 60, counts.shiny .. "/" .. counts.flush .. "/" .. counts.glow)
	glowing = 0
	Tick(QNS.clockFrame, 1 / 60)
	counts.glow = 0
	for _ = 1, 10 do Tick(QNS.clockFrame, 1 / 60) end
	local retired = counts.glow == 0
	QNS.ChestRevealStep, QNS.ShinyAuraTick, QNS.NotifyFlush, QNS.GlowUpdate = saved[1], saved[2], saved[3], saved[4]
	-- éclat éteint et déjà caché : on ne touche plus aux bords
	local hides = 0
	local function Edge() return { Hide = function() hides = hides + 1 end, Show = function() end, SetAlpha = function() end } end
	local frame, until_ = QNS.companionFrame, QNS.companionBubbleUntil
	QNS.companionFrame = { glow = { Edge(), Edge(), Edge(), Edge() }, glowAlpha = 0.4 }
	QNS.companionBubbleUntil = nil
	QNS:GlowUpdate(Mock.now)
	local once = hides == 4 and QNS.companionFrame.glowAlpha == 0
	QNS:GlowUpdate(Mock.now)
	QNS:GlowUpdate(Mock.now)
	Check("[THR] éclat éteint : la tâche se retire, bords cachés une fois puis plus rien", retired and once and hides == 4, hides)
	QNS.companionFrame, QNS.companionBubbleUntil = frame, until_
end

-- ---------------------------------------------------------------------------
-- Restauration
-- ---------------------------------------------------------------------------
for _, name in ipairs(LA.globals) do _G[name] = LA.saved[name] end
_G.CreateFrame = LA.saved.CreateFrame
QNS.ZONE_CREATURES, QNS.ZONE_QUESTS = LA.saved.ZONE_CREATURES, LA.saved.ZONE_QUESTS
QNS.tooltipHooks, NS.tooltipHooks = LA.saved.qcHooks, LA.saved.r2qHooks
GameTooltip.GetUnit, GameTooltip.GetItem = LA.saved.GetUnit, LA.saved.GetItem
Enum.TooltipDataType.Unit, Enum.TooltipDataType.Item = LA.saved.unitType, LA.saved.itemType
for key in pairs(C_Item) do C_Item[key] = nil end
for key, value in pairs(LA.saved.cItem) do C_Item[key] = value end
C_Map.GetMapLevels = LA.saved.GetMapLevels
C_QuestLog.IsQuestFlaggedCompleted, C_QuestLog.GetTitleForQuestID = LA.saved.Flagged, LA.saved.GetTitle
QNS.zoneQuests.done, QNS.zoneQuests.lists, QNS.zoneQuests.live, QNS.zoneQuests.requested = {}, {}, {}, {}
NS.lfgDungeonCache.ranges, QNS.lfgDungeonCache.ranges = nil, nil
for _, ns in ipairs({ NS, QNS }) do for k in pairs(ns.mapLevelCache) do ns.mapLevelCache[k] = nil end end
QNS:DB().companionRareAlert = nil
ResetWorld()
