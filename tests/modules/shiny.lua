-- Compagnon : créatures brillantes (Shiny.lua) et leur version capturable
-- (1.6.0). Tirage une fois par monstre (1/150, ×3 élite ou rare, chasse qui
-- monte avec les abattus), repérée (bulle, « ! », jamais de marque de raid :
-- fonction protégée), abattue (friandise, Festin au tirage bas), cadeaux
-- 5 / 15 / 30 / 50, carnet, coffre révélé objet par objet ; deux versions par
-- espèce (migration des anciennes fiches), capture de la brillante à côté de
-- la normale, mission de la semaine, lumière dorée, Créatures (marques,
-- fiche normale / brillante, équiper), losange sur la barre de nom.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local SH = { saved = {}, random = math.random, units = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"CreateVector3D", "CreateColor", "C_NamePlate" }
for _, name in ipairs(GLOBALS) do SH.saved[name] = rawget(_G, name) end
SH.savedChance = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"

function SH.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function SH.Install()
	local w = SH
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function(unit) local u = w.units[unit]; return u and u.dead == true or false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = w.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function(unit) local u = w.units[unit]; return u and u.type or "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function(unit) if unit == "player" or unit == nil then return 20 end return 18 end
	_G.GetRaidTargetIndex = function(unit) local u = w.units[unit]; return u and u.icon end
	_G.SetRaidTarget = function(unit, icon) local u = w.units[unit]; if u then u.icon = icon end; w.marked = (w.marked or 0) + 1 end
	_G.IsInGroup = function() return w.group == true end
	_G.UnitIsGroupLeader = function() return w.leader == true end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
end
function SH.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText = nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
-- variants : banc des captures (chance nulle par défaut, filet sans animation,
-- minuteries immédiates)
function SH.Reset(variants)
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "chestFrame",
		"capturePrompt", "captureQueueList" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.chestReveal = nil, nil, nil, nil, nil
	NS.captureState, NS.captureAppCache = nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	SH.units, SH.group, SH.leader, SH.marked = {}, false, false, 0
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	SH.Install()
	_G.C_Timer = SH.saved.C_Timer
	NS.SHINY_CHANCE = 1 / 150
	if variants then
		_G.C_Timer = { After = function(_, fn) fn() end }
		NS.SHINY_CHANCE = 0
		NS:DB().companionCaptureAnim = false
		if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	end
	math.random = SH.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
	SH.Quiet()
end
-- une créature sous la cible, vue
function SH.See(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or SH.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	SH.units.target = fields
	return NS:BestiarySeeUnit("target"), fields.guid
end
function SH.Kill(guid)
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
end
function SH.SeeKill(npcID, spawn)
	local _, guid = SH.See(npcID, { spawn = spawn, name = "Kodo " .. npcID })
	SH.Kill(guid)
	return guid
end
-- le tirage (math.random() sans argument) est imposé ; les tirages entiers
-- (choix d'une réplique) restent ceux du jeu
function SH.Roll(value)
	math.random = function(a, b)
		if a and b then return SH.random(a, b) end
		if a then return SH.random(a) end
		return value
	end
end
-- le filet part et réussit (tirage 0)
function SH.Capture()
	SH.Roll(0)
	local thrown = NS:CaptureThrow()
	for _ = 1, 12 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	return thrown
end

-- 1. Tirage ---------------------------------------------------------------------------------
do
	Say("-- brillantes : tirage")
	SH.Reset()
	Check("[SHINY] chance : 1 sur 150, ×3 élite ou rare", math.abs(NS.SHINY_CHANCE - 1 / 150) < 1e-9 and NS.SHINY_RANK_MULT == 3)
	SH.Roll(0.5)
	local species, guid = SH.See(3100)
	local missed = species and not NS:ShinyState().live[guid] and NS.companionBubbleKey == nil
	SH.Roll(0)
	SH.See(3100)
	Check("[SHINY] tirage raté : rien ; même monstre revu : pas de second tirage", missed and not NS:ShinyState().live[guid])
	SH.Roll(1 / 150 * 2)
	local _, normal = SH.See(3101)
	local _, elite = SH.See(3102, { class = "elite" })
	Check("[SHINY] tirage à 2× la chance : rien pour un normal, brillant pour un élite (×3)",
		not NS:ShinyState().live[normal] and NS:ShinyState().live[elite] ~= nil)
	SH.Reset()
	NS.SHINY_CHANCE = 0
	SH.Roll(0)
	local _, none = SH.See(3103)
	NS.SHINY_CHANCE = 1 / 150
	SH.units.target = { guid = SH.Guid(3104), name = "Mort", dead = true }
	Check("[SHINY] chance nulle : jamais ; monstre mort : pas au bestiaire, pas de tirage", not NS:ShinyState().live[none]
		and NS:BestiarySeeUnit("target") == nil and not NS:ShinyState().rolled[SH.Guid(3104)])
	-- chasse : la chance monte avec les abattus de l'espèce, plafonnée, le ×3 gardé
	Check("[SHINY] chasse : 1/150 sans abattu, 1/40 après 50, plafonnée, élite ×3",
		math.abs(NS:ShinyChance("normal", 0) - 1 / 150) < 1e-9 and math.abs(NS:ShinyChance("normal", 50) - 1 / 40) < 1e-9
		and NS:ShinyChance("normal", 500) == NS:ShinyChance("normal", 50)
		and math.abs(NS:ShinyChance("elite", 50) - 3 / 40) < 1e-9)
end

-- 2. Repérée : alerte, jamais de marque de raid ---------------------------------------------------
do
	Say("-- brillantes : repérée")
	SH.Reset()
	SH.Roll(0)
	local _, guid = SH.See(3200, { name = "Loup des plaines" })
	local live = NS:ShinyState().live[guid]
	Check("[SHINY] repérée : retenue (zone, espèce), la créature l'annonce, le « ! »", live and live.zoneID == 1413
		and live.npcID == 3200 and NS.companionBubbleKey == "SHINY_SPOTTED"
		and NS.companionBubbleText:find("Loup des plaines", 1, true) and NS.companionFrame.alert
		and NS.companionFrame.alert:IsShown(), NS.companionBubbleText)
	-- SetRaidTarget est protégé sur Forever : jamais appelé d'office (2.8.3)
	local solo = SH.units.target.icon == nil and live.marked == false
	SH.group, SH.leader = true, true
	SH.See(3202)
	SH.group, SH.leader = false, false
	local src = io.open((ADDON_ROOT or ".") .. "/QuestCompanion/Shiny.lua"):read("*a")
	Check("[SHINY] aucune marque de raid (seul ou chef), le code n'appelle plus SetRaidTarget", solo
		and SH.units.target.icon == nil and (SH.marked or 0) == 0 and not src:find('"SetRaidTarget"', 1, true))
end

-- 3. Abattue -----------------------------------------------------------------------------------------
do
	Say("-- brillantes : abattue")
	SH.Reset()
	SH.Roll(0)
	local _, guid = SH.See(3300, { name = "Kodo brillant" })
	SH.Quiet()
	SH.Roll(0.5)
	SH.Kill(guid)
	local shiny = NS:ShinyData()
	Check("[SHINY] abattue : comptée (zone comprise), plus vivante, une friandise, sa bulle, pas de souvenir (album retiré en 2.6.0)",
		shiny.count == 1 and NS:ShinyFound(1413, 3300) ~= nil and NS:ShinyZoneCount(1413) == 1
		and NS:ShinyState().live[guid] == nil and NS:TreatTotal() == 1 and NS:TreatCount("festin") == 0
		and NS.companionBubbleKey == "SHINY_KILLED" and NS.companionBubbleText:find("Kodo brillant", 1, true)
		and NS:CompanionData().memories == nil, NS.companionBubbleText)
	SH.Roll(0)
	local _, second = SH.See(3301)
	SH.Kill(second)
	Check("[SHINY] tirage bas : un Festin", NS:TreatCount("festin") == 1)
	-- une brillante tuée par un autre (pas comptée au bestiaire) : rien
	SH.Roll(0)
	local _, lost = SH.See(3302)
	NS:BestiaryCombat("UNIT_DIED", nil, 0, lost, 0)
	Check("[SHINY] morte sans nous : oubliée, pas comptée", NS:ShinyData().count == 2 and NS:ShinyState().live[lost] == nil)
end

-- 4. Cadeaux des brillantes --------------------------------------------------------------------------
do
	Say("-- brillantes : cadeaux")
	SH.Reset()
	local unlocked = NS:CompanionData().unlocked
	NS:ShinyData().count = 4
	local next5 = NS:ShinyNextReward().count == 5
	SH.Roll(0)
	local _, guid = SH.See(3400)
	SH.Kill(guid)
	Check("[SHINY] prochain cadeau 5 ; 5 brillantes : cadre Étincelant annoncé, équipable", next5 and unlocked["frame:sparkle"] == true
		and Mock:Output():find("Étincelant", 1, true) and NS:CompanionSetStyle("frame", "sparkle") ~= nil, Mock:Output())
	NS:ShinyData().count = 15
	NS:ShinyCheckRewards()
	local stardust = unlocked["bg:stardust"] == true and NS:CompanionSetStyle("bg", "stardust")
	NS:ShinyData().count = 30
	NS:ShinyCheckRewards()
	Check("[SHINY] 15 : fond Poussière d'étoiles ; 30 : l'aura, portée", stardust and unlocked["orn:aura"] == true
		and NS:CompanionOrnamentShown(NS:ShinyAuraDef()))
	local next50 = NS:ShinyNextReward().count == 50 and NS:ShinyNextReward().def.id == "hippogryph"
	NS:ShinyData().count = 50
	NS:ShinyCheckRewards()
	Check("[SHINY] 50 : le bébé hippogriffe ; ensuite plus de prochain cadeau, pas deux fois", next50
		and unlocked["app:hippogryph"] == true and NS:CompanionIsUnlocked("app", NS:CompanionAppearanceDef("hippogryph"))
		and NS:ShinyNextReward() == nil and #NS:ShinyCheckRewards() == 0)
	local listed = false
	for _, item in ipairs(NS:CompanionNextUnlocks()) do if item.id == "aura" or item.id == "sparkle" then listed = true end end
	Check("[SHINY] condition lisible, pas d'objectif au compteur pour eux", NS:CompanionRequirement({ shiny = 15 }) == "15 brillantes"
		and not listed)
	-- l'aura : des étincelles de temps en temps
	NS.companionFx = nil
	NS:ShinyState().auraAt = 0
	local sparks = NS:ShinyAuraTick(100) == true and NS:ShinyAuraTick(100.5) == false
	NS:DB().companionOrnAura = false
	Check("[SHINY] aura : étincelles, pas à chaque image, rien si enlevée", sparks and NS:ShinyAuraTick(200) == false)
	NS:DB().companionOrnAura = true
end

-- 5. Carnet : Créatures, Compagnon --------------------------------------------------------------------
do
	Say("-- brillantes : carnet")
	SH.Reset()
	-- une zone sans table livrée : seules nos créatures au bestiaire
	Mock.world.maps[9800] = { mapID = 9800, name = "Val doré", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID = 9800
	SH.Roll(0)
	local _, guid = SH.See(3500, { name = "Hyène dorée" })
	SH.Kill(guid)
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	NS:OpenMenagerieZone(9800)
	local card
	for _, c in ipairs(f.men.items) do if c.entry and c.entry.npc == 3500 then card = c end end
	card.scripts.OnEnter(card)
	local said = {}
	for _, line in ipairs(f.men.preview.lines) do said[#said + 1] = line.text or "" end
	Check("[SHINY] Créatures : étoile de la brillante abattue, aperçu « Brillante repérée le … »", card and card.star:IsShown()
		and table.concat(said, " "):find("Brillante repérée le", 1, true), table.concat(said, " "))
	f.sections.evolution:Click()
	Check("[SHINY] Compagnon : le compteur de brillantes", f.evo.stats.shiny.value.text == "1", f.evo.stats.shiny.value.text)
	f:Hide()
end

-- 6. Ouverture de coffre animée ----------------------------------------------------------------------------
do
	Say("-- coffre : ouverture animée")
	SH.Reset()
	NS:ChestData()[1413] = { tier = 1, name = "Les Tarides", at = 0 }
	local frame = NS:OpenChest(1413)
	local buttons = {}
	for _, b in ipairs(frame.options) do if b.reward and b:IsShown() then buttons[#buttons + 1] = b end end
	local hidden = #buttons > 1 and buttons[1].alpha == 0 and NS.chestReveal ~= nil
	Mock:Advance(NS.CHEST_REVEAL_STEP + 0.05)
	local oneByOne = buttons[1].alpha == 1 and buttons[2].alpha == 0
	for _ = 2, #buttons do Mock:Advance(NS.CHEST_REVEAL_STEP + 0.05) end
	Check("[CHESTFX] objets cachés à l'ouverture, révélés un par un, fin au dernier", hidden and oneByOne
		and buttons[#buttons].alpha == 1 and NS.chestReveal == nil)
	frame:Hide()
	NS:DB().companionChestAnim = false
	frame = NS:OpenChest(1413)
	local instant = frame.options[1].alpha ~= 0 and NS.chestReveal == nil
	frame:Hide()
	NS:DB().companionChestAnim = true
	frame = NS:OpenChest(1413)
	frame:Hide()
	Mock:Advance(1)
	Check("[CHESTFX] réglage coupé : tout de suite ; fermé en cours : tout remis visible", instant
		and frame.options[1].alpha == 1 and NS.chestReveal == nil)
end

-- 7. Réglages, textes --------------------------------------------------------------------------------------
do
	Say("-- brillantes : réglages")
	local page
	for _, p in ipairs(NS.OPTION_PAGES) do if p.id == "companionDaily" then page = p end end
	Check("[SHINY] page « Au jour le jour », par défaut : étoile et coffre animé", page and page.parent == "companion"
		and #page.rows >= 2 and NS:DB().companionShinyMark == true and NS:DB().companionChestAnim == true)
	local missing = {}
	for key in pairs(NS.SHINY_STRINGS.fr) do if not NS.SHINY_STRINGS.en[key] then missing[#missing + 1] = key end end
	for name, keys in pairs(NS.SHINY_POOLS) do
		if NS.COMPANION_POOLS[name] ~= keys then missing[#missing + 1] = "réservoir " .. name end
	end
	Check("[SHINY] textes fr et en, répliques enregistrées", #missing == 0, table.concat(missing, ", "))
end

-- 8. Deux versions par espèce : anciennes fiches migrées --------------------------------------------
do
	Say("-- brillantes : deux versions par espèce")
	SH.Reset(true)
	local data = NS:CompanionData()
	NS:DB().capture, NS.captureMergedChar = nil, nil; data.capture = { creatures = {
		[11] = { name = "Ancien brillant", at = 500, shiny = true },
		[12] = { name = "Ancien normal", at = 300 },
	}, count = 2 }
	local capture = NS:CaptureData()
	Check("[SHV] migration : l'ancien brillant devient la version brillante, la normale reste à capturer",
		capture.creatures[11].normal == false and capture.creatures[11].shinyAt == 500
		and NS:CaptureHas(11, true) and not NS:CaptureHas(11, false))
	Check("[SHV] migration : l'ancien normal reste normal", capture.creatures[12].normal == true
		and NS:CaptureHas(12, false) and not NS:CaptureHas(12, true))
	local ids = {}
	for _, def in ipairs(NS:CaptureAppearances()) do ids[def.id] = def end
	Check("[SHV] apparences : une par version capturée, une brillante comptée", ids["cap:11:s"] and ids["cap:11:s"].shiny
		and ids["cap:11"] == nil and ids["cap:12"] and ids["cap:12:s"] == nil and NS:CaptureShinyCount() == 1)
end

-- 9. Capturer la normale, puis la brillante --------------------------------------------------------
do
	Say("-- brillantes : capturer les deux versions")
	SH.Reset(true)
	SH.SeeKill(3100, "AAAA")
	local proposed = NS:CaptureQueueBest() ~= nil
	SH.Capture()
	Check("[SHV] normale abattue : proposée, capturée (la normale seule)", proposed and NS:CaptureHas(3100, false)
		and not NS:CaptureHas(3100, true))
	-- 2.0 : déjà capturée à 3 étoiles, elle ne se propose plus
	NS:CaptureData().creatures[3100].stars = 3
	SH.SeeKill(3100, "BBBB")
	Check("[SHV] normale déjà capturée (3 étoiles) : plus proposée", NS:CaptureQueueBest() == nil)
	-- une brillante de la même espèce : proposée, et capturée À CÔTÉ
	NS:WeeklyData().week = NS:WeeklyId()
	NS:WeeklyData().missions = { { kind = "shinyCapture", need = 1, have = 0, source = "week" } }
	NS.SHINY_CHANCE = 1
	SH.Roll(0)
	local guid = SH.SeeKill(3100, "CCCC")
	Check("[SHV] brillante de l'espèce : proposée malgré la normale", NS:CaptureQueueBest() and NS:CaptureQueueBest().shiny)
	NS.SHINY_CHANCE = 0
	SH.Capture()
	local entry = NS:CaptureData().creatures[3100]
	Check("[SHV] brillante capturée à côté (une espèce, deux versions), mission « capture une brillante » faite, reconnue",
		entry.normal == true and entry.shiny == true and entry.shinyAt ~= nil and NS:CaptureData().count == 1
		and NS:WeeklyData().missions[1].done == true and NS:ShinyKnown(3100) ~= nil and guid ~= nil)
	local ids = {}
	for _, def in ipairs(NS:CaptureAppearances()) do ids[def.id] = true end
	NS:CompanionData().appearance = "cap:3100:s"
	Check("[SHV] deux apparences ; compagnon brillant : il garde le nom de l'espèce", ids["cap:3100"] and ids["cap:3100:s"]
		and NS:CompanionName() == "Kodo 3100", NS:CompanionName())
	NS:CompanionData().appearance = NS.COMPANION_APPEARANCES[1].id
end

-- 10. Reconnue sans capture, semaine ------------------------------------------------------------------
do
	Say("-- brillantes : reconnue, semaine")
	SH.Reset(true)
	NS.SHINY_CHANCE = 1
	SH.Roll(0)
	SH.units.target = { guid = SH.Guid(3200), name = "Loup" }
	NS:BestiarySeeUnit("target")
	NS.SHINY_CHANCE = 0
	local found
	for _, item in ipairs(NS:MenagerieList({ zone = "all", state = "shiny" })) do if item.npc == 3200 then found = item end end
	Check("[SHV] repérée sans être abattue ni capturée : reconnue, dans le filtre « Brillantes »", NS:ShinyKnown(3200) ~= nil
		and not NS:CaptureHas(3200, true) and found and found.shinySeen ~= nil and not found.shiny)
	SH.Reset(true)
	local ok = true
	for _ = 1, 20 do
		local shiny = false
		for _, mission in ipairs(NS:WeeklyDraw(true)) do
			if NS.WEEKLY_SHINY_KINDS[mission.kind] then shiny = true end
		end
		if not shiny then ok = false end
	end
	Check("[SHV] chaque semaine : une mission « brillante » (abattre ou capturer), libellés", ok
		and NS.L.WK_shinyKill == "Abats une créature brillante" and NS.L.WK_shinyCapture == "Capture une créature brillante")
	NS:WeeklyData().missions = { { kind = "shinyKill", need = 1, have = 0, source = "week" } }
	NS:WeeklyData().week = NS:WeeklyId()
	NS.SHINY_CHANCE = 1
	SH.Roll(0)
	SH.SeeKill(3300)
	NS.SHINY_CHANCE = 0
	Check("[SHV] abattre une brillante : la mission avance", NS:WeeklyData().missions[1].done == true)
end

-- 11. Lumière dorée ------------------------------------------------------------------------------------
do
	Say("-- brillantes : lumière dorée")
	local calls = {}
	local model = {
		GetLight = function() return true, "origine" end,
		SetLight = function(_, ...) calls[#calls + 1] = { ... } end,
	}
	_G.CreateVector3D = function(x, y, z) return { x = x, y = y, z = z } end
	_G.CreateColor = function(r, g, b) return { r = r, g = g, b = b } end
	local gold = NS.ModelShinyLight(model, true) and #calls == 1 and type(calls[1][2]) == "table" and calls[1][2].ambientColor.g < 1
	NS.ModelShinyLight(model, true)
	local once = #calls == 1
	NS.ModelShinyLight(model, false)
	Check("[SHV] lumière dorée posée (API récente), une fois, la lumière d'origine revient", gold and once and #calls == 2
		and calls[2][2] == "origine")
	_G.CreateVector3D, _G.CreateColor = nil, nil
	local old = { GetLight = function() return nil end, SetLight = function(_, ...) calls[#calls + 1] = { ... } end }
	Check("[SHV] client historique : la liste d'arguments ; modèle sans lumière : sans erreur",
		NS.ModelShinyLight(old, true) and #calls[#calls] == 13 and NS.ModelShinyLight({}, true) == false)
end

-- 12. Créatures : marques, fiche normale / brillante, équiper -------------------------------------------
do
	Say("-- brillantes : Créatures")
	SH.Reset(true)
	NS:CaptureData().creatures[3400] = { name = "Lion", class = "normal", normal = true, at = 100, shiny = true, shinyAt = 200 }
	NS:CaptureData().count = 1
	NS.captureAppCache = nil
	NS:BestiaryData()[1413] = { [3400] = { name = "Lion", seen = true, killed = 2, class = "normal" } }
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.menZone, f.menState, f.menRank, f.menSearch, f.menSort = "all", "all", "all", "lion", "no"
	f.sections.menagerie:Click()
	local pane, row = f.men, nil
	for _, cell in ipairs(pane.items) do if cell.entry and cell.entry.npc == 3400 then row = cell end end
	Check("[SHV] ligne : liseré vert (normale), losange doré (brillante capturée) ; puce « Brillantes »", row
		and row.caught:IsShown() and row.star:IsShown() and row.star.clientRole == "diamond" and pane.states.shiny ~= nil)
	row.scripts.OnEnter(row)
	local preview = pane.preview
	local normalFirst = preview.shiny == false and preview.variant:IsShown() and preview.variant.text.text == "Version brillante"
	preview.variant:Click()
	Check("[SHV] fiche : la normale d'abord, le bouton passe à la brillante", normalFirst and preview.shiny == true
		and preview.title.text:find("Lion", 1, true) and preview.variant.text.text == "Version normale")
	-- 2.0 : une confirmation qui compare les effets, puis « Emmener »
	row:Click()
	NS:CompanionConfirmAnswer(true)
	local shinyEquipped = NS:CompanionData().appearance == "cap:3400:s"
	preview.variant:Click()
	row:Click()
	NS:CompanionConfirmAnswer(true)
	Check("[SHV] clic sur la ligne : la version montrée devient le compagnon (brillante, puis normale)", shinyEquipped
		and NS:CompanionData().appearance == "cap:3400", NS:CompanionData().appearance)
	f:Hide()
end

-- 13. Losange doré sur la barre de nom d'une brillante vivante ----------------------------------------
do
	Say("-- brillantes : repère sur la barre de nom")
	SH.Reset(true)
	local plates = {}
	_G.C_NamePlate = {
		GetNamePlateForUnit = function(unit) return plates[unit] end,
		GetNamePlates = function() local list = {} for _, p in pairs(plates) do list[#list + 1] = p end return list end,
	}
	local plate = CreateFrame("Frame")
	plate.namePlateUnitToken = "nameplate1"
	plates.nameplate1 = plate
	NS.shinyPlates = {}
	local guid = SH.Guid(3500, "00000ABCDE")
	SH.units.nameplate1 = { guid = guid, name = "Kodo" }
	NS:ShinyPlatesRefresh()
	local mark = NS.shinyPlateMarks[plate]
	local none = mark == nil or not mark:IsShown()
	NS.SHINY_CHANCE = 1
	SH.Roll(0)
	SH.units.target = { guid = guid, name = "Kodo" }
	NS:BestiarySeeUnit("target")
	NS.SHINY_CHANCE = 0
	mark = NS.shinyPlateMarks[plate]
	Check("[SHV] normal : pas de losange ; brillante repérée : losange sur sa barre, tout de suite, au-dessus du nom, qui scintille",
		none and mark and mark:IsShown() and mark.guid == guid and mark:GetParent() == plate and mark.lastPoint
		and mark.lastPoint.point == "BOTTOM" and mark.lastPoint.relPoint == "TOP" and mark.scripts.OnUpdate ~= nil)
	pcall(mark.scripts.OnUpdate, mark)
	NS:DB().companionShinyPlate = false
	NS:ShinyPlatesRefresh()
	local hidden = not mark:IsShown()
	NS:DB().companionShinyPlate = true
	NS:ShinyPlatesRefresh()
	Check("[SHV] réglage coupé : losange caché ; remis : de retour", hidden and mark:IsShown())
	SH.Kill(guid)
	local gone = not mark:IsShown() and mark.guid == nil
	-- barre retirée puis reprise par une autre unité : rien ne traîne
	NS:ShinyState().live[guid] = { npcID = 3500 }
	NS:ShinyPlatesRefresh()
	NS.shinyPlateFrame:GetScript("OnEvent")(NS.shinyPlateFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
	Check("[SHV] brillante abattue ou barre retirée : losange parti", gone and not mark:IsShown())
	NS:ShinyState().live[guid] = nil
	NS.shinyPlates = {}
end

-- fin
for _, name in ipairs(GLOBALS) do _G[name] = SH.saved[name] end
math.random = SH.random
NS.SHINY_CHANCE = SH.savedChance
NS:CompanionData().appearance = NS.COMPANION_APPEARANCES[1].id
ResetWorld()
