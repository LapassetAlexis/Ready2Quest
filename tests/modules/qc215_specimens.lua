-- QuestCompanion 2.15.0 : refonte de la capture (CaptureSpecimens.lua,
-- CaptureQueue.lua) : spécimens (Codex, Réserve), migration, qualité tirée
-- au coup fatal, chance selon la qualité, règles du filet, épingles, mode
-- chasse, méfiance, Réserve pleine, « Mettre au Codex », relâcher contre des
-- paillettes, réplique du compagnon sur un 3 étoiles ou une brillante.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local Q = { saved = {}, random = math.random, units = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"UnitAffectingCombat", "InCombatLockdown" }
for _, name in ipairs(GLOBALS) do Q.saved[name] = rawget(_G, name) end
Q.savedShiny = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"

function Q.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function Q.Install()
	local w = Q
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = w.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function(unit)
		if unit == "player" or unit == nil then return 20 end
		local u = w.units[unit]; return u and u.level or 20
	end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return w.combat == true end
end
function Q.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText = nil
	if NS.companionRT then NS.companionRT.cool = {}; NS.companionRT.combat = nil end
	if NS.notifyState then NS.notifyState.at = -math.huge end
end
function Q.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt", "captureQueueList", "captureNetButton", "captureToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureAppCache, NS.specimenCountCache = nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	NS:DB().capture, NS.captureMergedChar = nil, nil
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
	Q.units, Q.combat = {}, false
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	Q.Install()
	NS.SHINY_CHANCE = 0
	math.random = Q.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = false
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CompanionUpdateVisibility()
	Q.Quiet()
	Mock:Reset()
end
function Q.Roll(value)
	math.random = function(a, b)
		if a and b then return Q.random(a, b) end
		if a then return Q.random(a) end
		return value
	end
end
function Q.SeeKill(npcID, fields)
	fields = fields or {}
	local guid = Q.Guid(npcID, fields.spawn)
	fields.guid = guid
	fields.name = fields.name or ("Bête " .. npcID)
	Q.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	return guid
end
function Q.Settle()
	for _ = 1, 12 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
end
function Q.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = Q.saved[name] end
	math.random = Q.random
	NS.SHINY_CHANCE = Q.savedShiny
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
	NS:DB().capture, NS.captureMergedChar = nil, nil
	ResetWorld()
end
local function Ids(list)
	local out = {}
	for index, item in ipairs(list) do out[index] = tostring(item.id) end
	return table.concat(out, ",")
end
local function Near(a, b) return math.abs((a or -1) - b) < 1e-6 end

-- 1. Migration ---------------------------------------------------------------------------------------
do
	Say("-- qc215 : migration des espèces en spécimens")
	Q.Reset()
	local data = NS:CaptureData()
	data.creatures[11] = { name = "Kodo", normal = true, stars = 2, at = 100, zoneID = 1413, class = "normal" }
	data.creatures[12] = { name = "Raptor", normal = true, stars = 3, at = 110, shiny = true, shinyStars = 1, shinyAt = 200 }
	data.creatures[13] = { name = "Ours", normal = false, shiny = true, shinyStars = 2, shinyAt = 300 }
	data.count = 3
	data.creatures[12].retries = 4   -- ancien compteur de recaptures : ignoré
	local appBefore = Ids(NS:CaptureAppearances())
	local shinyBefore, speciesBefore = NS:CaptureShinyCount(), data.count
	local all = NS:SpecimenList({ sort = "id" })
	Check("[SPEC] migration : une référence par version possédée (4)", #all == 4, #all)
	local origins, refs = 0, 0
	for _, spec in ipairs(all) do
		if spec.origin == "migration" then origins = origins + 1 end
		if NS:SpecimenIsReference(spec.id) then refs = refs + 1 end
	end
	Check("[SPEC] … origine « migration », toutes au Codex, Réserve vide", origins == 4 and refs == 4
		and NS:SpecimenReserveCount() == 0 and #NS:SpecimenReserve() == 0)
	local kodo, raptorS = NS:SpecimenReference(11, false), NS:SpecimenReference(12, true)
	Check("[SPEC] … étoiles, zone et date gardées", kodo and kodo.stars == 2 and kodo.zone == 1413 and kodo.at == 100
		and raptorS and raptorS.stars == 1 and raptorS.shiny == true and raptorS.at == 200
		and NS:SpecimenReference(12, false).stars == 3 and NS:SpecimenReference(13, true).stars == 2
		and NS:SpecimenReference(13, false) == nil)
	Check("[SPEC] … captures comptées (spécimens), espèces inchangées", NS:CaptureCaughtCount() == 4
		and data.count == speciesBefore and NS:CaptureShinyCount() == shinyBefore)
	Check("[SPEC] … apparences identiques", Ids(NS:CaptureAppearances()) == appBefore, appBefore)
	Check("[SPEC] … vue par espèce intacte (étoiles des hauts faits)", NS:CaptureStars(11) == 2 and NS:CaptureStars(12) == 3
		and NS:CaptureStars(12, true) == 1 and NS:CaptureStars(13, true) == 2 and NS:CaptureStars(13) == nil)
	Check("[SPEC] migration idempotente", NS:SpecimenMigrate() == 0 and #NS:SpecimenList() == 4 and NS:CaptureCaughtCount() == 4)
	-- une collection de personnage versée plus tard : le Codex suit
	NS.CaptureMergeInto(NS:CaptureAccount(), { creatures = { [14] = { name = "Loup", normal = true, stars = 1, at = 400 } } })
	Check("[SPEC] collection versée au compte : sa référence apparaît", NS:SpecimenReference(14, false) ~= nil
		and #NS:SpecimenList() == 5 and NS:CaptureCaughtCount() == 5)
	Check("[SPEC] hauts faits : espèces lues comme avant (vue par espèce)", NS:MenagerieSpeciesCount() == 4
		and NS:CaptureShinyCount() == 2)
end

-- 2. Qualité au coup fatal ----------------------------------------------------------------------------
do
	Say("-- qc215 : qualité tirée au coup fatal")
	Q.Reset()
	local odds = NS.CAPTURE_QUALITY_ODDS
	local function Sum(t) return t[1] + t[2] + t[3] end
	Check("[QUAL] tables : 65/28/7, 50/35/15, 30/45/25", odds.normal[1] == 65 and odds.normal[3] == 7
		and odds.elite[1] == 50 and odds.elite[3] == 15 and odds.rare[1] == 30 and odds.rare[2] == 45 and odds.rare[3] == 25
		and Sum(odds.normal) == 100 and Sum(odds.elite) == 100 and Sum(odds.rare) == 100)
	Check("[QUAL] rangs : rare, rare élite, boss = « rare » ; insignifiant = « normal »", NS.CAPTURE_QUALITY_GROUP.rareelite == "rare"
		and NS.CAPTURE_QUALITY_GROUP.worldboss == "rare" and NS.CAPTURE_QUALITY_GROUP.trivial == "normal")
	local function R(v, class) Q.Roll(v); local s = NS:CaptureRollQuality(class); math.random = Q.random; return s end
	Check("[QUAL] normal : 0,64 -> 1, 0,66 -> 2, 0,94 -> 3", R(0.64, "normal") == 1 and R(0.66, "normal") == 2 and R(0.94, "normal") == 3)
	Check("[QUAL] élite : 0,49 -> 1, 0,84 -> 2, 0,86 -> 3", R(0.49, "elite") == 1 and R(0.84, "elite") == 2 and R(0.86, "elite") == 3)
	Check("[QUAL] boss : 0,29 -> 1, 0,74 -> 2, 0,76 -> 3", R(0.29, "worldboss") == 1 and R(0.74, "worldboss") == 2 and R(0.76, "worldboss") == 3)
	Check("[QUAL] plus de tirage après la capture", NS.CaptureRollStars == nil)
	-- au coup fatal : le candidat porte sa qualité
	Q.Roll(0.99)
	Q.SeeKill(5100, { name = "Ours élite", class = "elite" })
	math.random = Q.random
	local candidate = NS:CaptureQueue()[1]
	Check("[QUAL] candidat : qualité tirée au coup fatal", candidate and candidate.stars == 3 and candidate.reason == "new")
	-- la capture garde la qualité du candidat, quel que soit le tirage du lancer
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	Q.Roll(0)
	NS:CaptureThrow()
	Q.Settle()
	math.random = Q.random
	local ref = NS:SpecimenReference(5100, false)
	Check("[QUAL] spécimen capturé : 3 étoiles, origine capture, dresseur, zone", ref and ref.stars == 3
		and ref.origin == "capture" and ref.by == "Testeur" and ref.zone == 1413 and ref.at ~= nil
		and NS:CaptureStars(5100) == 3)
	Check("[QUAL] une capture de plus au compteur", NS:CaptureCaughtCount() == 1)
end

-- 3. Chance selon la qualité -----------------------------------------------------------------------------
do
	Say("-- qc215 : chance selon la qualité")
	Q.Reset()
	local base = NS.CaptureChanceBase or NS.CaptureChance
	local c1 = base(NS, { class = "normal", level = 20, stars = 1 }, nil, 20)
	local c2 = base(NS, { class = "normal", level = 20, stars = 2 }, nil, 20)
	local c3 = base(NS, { class = "normal", level = 20, stars = 3 }, nil, 20)
	local cnil = base(NS, { class = "normal", level = 20 }, nil, 20)
	Check("[CHANCE] facteurs 1 / 0,8 / 0,6", NS.CAPTURE_QUALITY_FACTOR[1] == 1 and NS.CAPTURE_QUALITY_FACTOR[2] == 0.8
		and NS.CAPTURE_QUALITY_FACTOR[3] == 0.6)
	Check("[CHANCE] normal 50 % : 50 / 40 / 30 (sans qualité : comme 1 étoile)", Near(c1, 0.5) and Near(c2, 0.4)
		and Near(c3, 0.3) and Near(cnil, 0.5), tostring(c1) .. "/" .. tostring(c2) .. "/" .. tostring(c3))
	local e3 = base(NS, { class = "elite", level = 20, stars = 3 }, "appat", 20)
	Check("[CHANCE] élite 3 étoiles, appât : 25 % × 0,6 × 1,5", Near(e3, 0.25 * 0.6 * 1.5))
	local sure = select(2, base(NS, { class = "worldboss", stars = 3 }, "sifflet", 20))
	Check("[CHANCE] le sifflet reste assuré", sure == true)
end

-- 4. Règles du filet ------------------------------------------------------------------------------------
do
	Say("-- qc215 : quand le filet apparaît")
	Q.Reset()
	local data = NS:CaptureData()
	data.creatures[500] = { name = "Harpie", normal = true, stars = 2 }
	data.count = 1
	Check("[NET] espèce nouvelle : « new »", NS:CaptureQueueReason({ npcID = 501, stars = 1 }) == "new")
	Check("[NET] brillante : toujours (même possédée)", NS:CaptureQueueReason({ npcID = 500, stars = 1, shiny = true }) == "shiny")
	Check("[NET] qualité meilleure que ta meilleure : « stars »", NS:CaptureQueueReason({ npcID = 500, stars = 3 }) == "stars")
	Check("[NET] qualité égale ou moindre : silence", NS:CaptureQueueReason({ npcID = 500, stars = 2 }) == nil
		and NS:CaptureQueueReason({ npcID = 500, stars = 1 }) == nil)
	NS:HuntPin(500, true)
	Check("[NET] espèce épinglée : « pinned », même sans amélioration", NS:CaptureQueueReason({ npcID = 500, stars = 1 }) == "pinned")
	NS:HuntPin(500, false)
	Check("[NET] candidat abattu en chasse : « hunt »", NS:CaptureQueueReason({ npcID = 500, stars = 1, hunt = true }) == "hunt")
	-- au coup fatal : un 1 étoile d'une espèce à 2 étoiles ne fait rien
	Q.Roll(0)
	Q.SeeKill(500, { name = "Harpie" })
	math.random = Q.random
	Check("[NET] coup fatal sans intérêt : pas de filet", #NS:CaptureQueue() == 0)
	Q.Roll(0.99)
	Q.SeeKill(500, { name = "Harpie", spawn = "B2" })
	math.random = Q.random
	local best = NS:CaptureQueueBest()
	Check("[NET] coup fatal 3 étoiles : au filet, raison et qualité", best and best.reason == "stars" and best.stars == 3
		and NS:CaptureQueueLine(best):find("|A:", 1, true) ~= nil)
	Check("[NET] plus de réglages « Recaptures »", (function()
		for _, row in ipairs(NS.DAILY_OPTION_ROWS or {}) do if tostring(row.key):find("^companionRetry") then return false end end
		return true
	end)())
	-- tri : nouvelle > meilleur spécimen > épinglée > chasse
	local order = { { reason = "hunt", stars = 3, serial = 1 }, { reason = "pinned", stars = 1, serial = 2 },
		{ reason = "stars", stars = 2, serial = 3 }, { reason = "new", stars = 1, serial = 4 } }
	Check("[NET] rangs des raisons", NS.CAPTURE_REASON_RANK.new > NS.CAPTURE_REASON_RANK.stars
		and NS.CAPTURE_REASON_RANK.stars > NS.CAPTURE_REASON_RANK.pinned and NS.CAPTURE_REASON_RANK.pinned > NS.CAPTURE_REASON_RANK.hunt
		and #order == 4)
end

-- 5. Épingles --------------------------------------------------------------------------------------------
do
	Say("-- qc215 : liste de chasse")
	Q.Reset()
	Check("[PIN] épingler / lire", NS:HuntPin(600, true) == true and NS:HuntPinned(600) and NS:HuntPinned("600")
		and not NS:HuntPinned(601))
	NS:HuntPin(601, true)
	local pins = NS:HuntPins()
	Check("[PIN] la liste, au compte", #pins == 2 and NS:CaptureAccount().pins[601] == true)
	Check("[PIN] bascule sans valeur", NS:HuntPin(601) == false and not NS:HuntPinned(601))
	NS:CaptureSkipSpecies(602, "Écartée")
	Check("[PIN] épingler lève « Ne plus proposer »", NS:CaptureSkipped(602) and NS:HuntPin(602, true) and not NS:CaptureSkipped(602))
	-- infobulle : « épinglée »
	local data = NS:CaptureData()
	data.creatures[600] = { name = "Kodo", normal = true, stars = 1 }
	Check("[PIN] chaînes d'infobulle 2.15", NS.L.MEN_TIP_PINNED and NS.L.MEN_TIP_FULL:find("complète", 1, true)
		and NS.L.MEN_TIP_MORE:find("amélioration", 1, true) and rawget(NS.L, "MEN_TIP_NOTRY") == nil)
end

-- 6. Mode chasse -------------------------------------------------------------------------------------------
do
	Say("-- qc215 : mode chasse")
	Q.Reset()
	Check("[HUNT] durées comme la sourdine", table.concat(NS.HUNT_CHOICES, ",") == "5,15,30,60")
	Check("[HUNT] inactif au départ", NS:HuntActive() == false and NS:HuntRemaining() == nil and NS:HuntText() == nil)
	NS:HuntStart(15)
	Check("[HUNT] 15 min : active, temps restant", NS:HuntActive() and NS:HuntRemaining() == 900
		and NS:HuntText():find("15", 1, true) ~= nil)
	Check("[HUNT] … annoncée dans le chat", Mock:Output():find(NS:F("HUNT_MSG_START_FOR", "15 min"), 1, true) ~= nil, Mock:Output())
	-- /reload : l'état vit dans les réglages
	NS.captureState = nil
	Mock:Advance(600)
	Check("[HUNT] après un rechargement : toujours active", NS:HuntActive() and NS:HuntRemaining() == 300)
	-- chaque monstre est proposé
	local data = NS:CaptureData()
	data.creatures[700] = { name = "Loup", normal = true, stars = 3 }
	Q.Roll(0)
	Q.SeeKill(700, { name = "Loup" })
	math.random = Q.random
	local c = NS:CaptureQueue()[1]
	Check("[HUNT] espèce complète, 1 étoile : proposée en chasse", c and c.reason == "hunt" and c.hunt == true)
	Mock:Reset()
	Mock:Advance(301)
	NS:CaptureTick(NS.Now())
	Check("[HUNT] fin du temps : terminée et annoncée", not NS:HuntActive() and NS:DB().captureHuntOn == nil
		and Mock:Output():find(NS.L.HUNT_MSG_END, 1, true) ~= nil, Mock:Output())
	Check("[HUNT] le candidat abattu en chasse garde sa raison après la chasse", NS:CaptureQueueReason(c) == "hunt")
	NS:CaptureQueueClear()
	Q.Roll(0)
	Q.SeeKill(700, { name = "Loup", spawn = "C3" })
	math.random = Q.random
	Check("[HUNT] après la chasse : silence de nouveau", #NS:CaptureQueue() == 0)
	-- jusqu'à l'arrêt
	NS:HuntStart(nil)
	Mock:Advance(100000)
	NS:CaptureTick(NS.Now())
	Check("[HUNT] jusqu'à l'arrêt : ne s'arrête pas seule", NS:HuntActive() and NS:HuntRemaining() == -1
		and NS:HuntText() == NS.L.HUNT_TEXT_ON)
	Mock:Reset()
	Check("[HUNT] arrêt", NS:HuntStop() == true and not NS:HuntActive() and NS:HuntStop() == false
		and Mock:Output():find(NS.L.HUNT_MSG_STOP, 1, true) ~= nil)
	-- commande
	local cmd = NS.EXTRA_COMMANDS
	cmd.chasse(NS, "30")
	Check("[HUNT] /qc chasse 30", NS:HuntActive() and NS:HuntRemaining() == 1800)
	cmd.chasse(NS, "stop")
	Check("[HUNT] /qc chasse stop", not NS:HuntActive())
	cmd.hunt(NS, "on")
	Check("[HUNT] /qc hunt on : jusqu'à l'arrêt", NS:HuntActive() and NS:HuntRemaining() == -1)
	cmd.chasse(NS, "")
	Check("[HUNT] /qc chasse sans argument : bascule", not NS:HuntActive())
	cmd.chasse(NS, "")
	Check("[HUNT] … et rebascule", NS:HuntActive())
	NS:HuntStop()
	-- raccourci
	Check("[HUNT] raccourci « Mode chasse »", NS.BINDINGS.hunt == "QUESTCOMPANION_HUNT"
		and type(_G.BINDING_NAME_QUESTCOMPANION_HUNT) == "string" and type(_G.QuestCompanion_ToggleHunt) == "function")
	_G.QuestCompanion_ToggleHunt()
	Check("[HUNT] … le raccourci lance la chasse", NS:HuntActive())
	_G.QuestCompanion_ToggleHunt()
	Check("[HUNT] … et l'arrête", not NS:HuntActive())
end

-- 7. Méfiance ------------------------------------------------------------------------------------------------
do
	Say("-- qc215 : méfiance (mode chasse)")
	Q.Reset()
	local f0, n0 = NS:CaptureWariness(800)
	Check("[WARY] personne n'est méfiant au départ", f0 == 1 and n0 == 0)
	NS:CaptureWaryNote(800); NS:CaptureWaryNote(800)
	Check("[WARY] hors chasse : pas de méfiance", NS:CaptureWariness(800) == 1)
	NS:HuntStart(60)
	local f2, n2 = NS:CaptureWariness(800)
	Check("[WARY] en chasse, deux captures aujourd'hui : ×0,7", Near(f2, 0.7) and n2 == 2)
	local base = NS.CaptureChanceBase or NS.CaptureChance
	Check("[WARY] la chance en tient compte", Near(base(NS, { class = "normal", level = 20, stars = 1, npcID = 800 }, nil, 20), 0.35))
	Check("[WARY] une autre espèce : pas méfiante", NS:CaptureWariness(801) == 1)
	for _ = 1, 6 do NS:CaptureWaryNote(800) end
	Check("[WARY] plancher ×0,4", Near(NS:CaptureWariness(800), 0.4))
	Mock:Advance(86400)
	NS:HuntStart(60)
	local fd, nd = NS:CaptureWariness(800)
	Check("[WARY] nouveau jour : remise à zéro", fd == 1 and nd == 0)
	NS:HuntStop()
	-- une capture réussie compte
	Q.SeeKill(810, { name = "Sanglier" })
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	NS:CaptureThrow()
	Q.Settle()
	Check("[WARY] capture réussie : notée pour la journée", select(2, NS:CaptureWariness(810)) == 1)
end

-- 8. Réserve pleine -----------------------------------------------------------------------------------------
do
	Say("-- qc215 : Réserve")
	Q.Reset()
	Check("[RES] 20 places au départ", NS.CAPTURE_RESERVE_BASE == 20 and NS:ReserveCapacity() == 20 and not NS:ReserveFull())
	local first, place = NS:SpecimenAdd({ npc = 900, stars = 1, name = "Crabe" })
	NS:CaptureData().creatures[900] = NS:CaptureData().creatures[900] or { name = "Crabe", normal = true, stars = 1 }
	Check("[RES] premier spécimen : au Codex", place == "codex" and NS:SpecimenIsReference(first))
	for _ = 1, 20 do NS:SpecimenAdd({ npc = 900, stars = 1, name = "Crabe" }) end
	Check("[RES] vingt de plus : Réserve pleine", NS:SpecimenReserveCount() == 20 and NS:ReserveFull())
	Check("[RES] candidat d'une espèce au Codex : bloqué", NS:CaptureBlockedReason({ npcID = 900 }) == "reserveFull")
	Check("[RES] espèce nouvelle ou brillante nouvelle : jamais bloquée", NS:CaptureBlockedReason({ npcID = 901 }) == nil
		and NS:CaptureBlockedReason({ npcID = 900, shiny = true }) == nil)
	-- le lancer est refusé, le candidat reste au filet
	NS:CaptureData().creatures[900] = { name = "Crabe", normal = true, stars = 1 }
	NS:HuntStart(nil)
	Q.SeeKill(900, { name = "Crabe" })
	Mock:Reset()
	Check("[RES] lancer refusé, il reste au filet", NS:CaptureThrow() == false and #NS:CaptureQueue() == 1
		and Mock:Output():find("Réserve pleine", 1, true) ~= nil, Mock:Output())
	NS:HuntStop()
	Check("[RES] places en plus (boutique)", NS:ReserveAddSlots(5) == 25 and not NS:ReserveFull()
		and NS:CaptureBlockedReason({ npcID = 900 }) == nil)
	NS:CaptureQueueClear()
end

-- 9. Mettre au Codex, relâcher, paillettes ---------------------------------------------------------------------
do
	Say("-- qc215 : Codex, relâcher, paillettes")
	Q.Reset()
	local data = NS:CaptureData()
	data.creatures[950] = { name = "Raptor", normal = true, stars = 1 }
	data.count = 1
	local one = NS:SpecimenReference(950, false).id
	local three, p3, old = NS:SpecimenAdd({ npc = 950, stars = 3, name = "Raptor" })
	Check("[CODEX] meilleur spécimen : au Codex, l'ancien en Réserve", p3 == "codex" and old == one
		and NS:SpecimenIsReference(three) and not NS:SpecimenIsReference(one) and data.creatures[950].stars == 3)
	local two, p2 = NS:SpecimenAdd({ npc = 950, stars = 2, name = "Raptor" })
	Check("[CODEX] moins bon : en Réserve", p2 == "reserve" and NS:SpecimenReserveCount() == 2)
	Check("[CODEX] Mettre au Codex", NS:SpecimenSetReference(two) == true and NS:SpecimenIsReference(two)
		and not NS:SpecimenIsReference(three) and NS:SpecimenBetterThanCodex(three))
	Check("[CODEX] … la vue par espèce garde la meilleure qualité possédée", data.creatures[950].stars == 3)
	local again, why = NS:SpecimenSetReference(two)
	Check("[CODEX] déjà au Codex : refusé", again == false and why == "already")
	Check("[CODEX] valeurs : 1 / 3 / 8, brillant 20", NS:SpecimenReleaseValue({ stars = 1 }) == 1
		and NS:SpecimenReleaseValue({ stars = 2 }) == 3 and NS:SpecimenReleaseValue({ stars = 3 }) == 8
		and NS:SpecimenReleaseValue({ stars = 1, shiny = true }) == 20)
	-- 2.15.0 (journal) : relâcher ne fait jamais baisser tes étoiles
	local better, betterWhy = NS:SpecimenRelease(three)
	Check("[REL] meilleur que la référence du Codex : « better », gardé", better == false and betterWhy == "better"
		and NS:SpecimenGet(three) ~= nil and NS:Paillettes() == 0)
	NS:SpecimenSetReference(three)
	local gain = NS:SpecimenRelease(two)
	Check("[REL] relâcher un 2 étoiles de Réserve : +3 paillettes", gain == 3 and NS:Paillettes() == 3
		and NS:SpecimenGet(two) == nil and data.creatures[950].stars == 3)
	local no, reason = NS:SpecimenRelease(three)
	Check("[REL] la référence du Codex : interdit", no == false and reason == "reference" and NS:SpecimenGet(three) ~= nil)
	NS:CompanionData().appearance = "cap:950"
	local _, worn = NS:SpecimenCanRelease(three)
	Check("[REL] l'apparence portée : interdit", worn == "worn" and NS:SpecimenWorn(three))
	NS:CompanionData().appearance = nil
	local missing = select(2, NS:SpecimenRelease(99999))
	Check("[REL] spécimen inconnu : « missing »", missing == "missing")
	local shinyId = NS:SpecimenAdd({ npc = 950, stars = 1, shiny = true })
	local shinyRes = NS:SpecimenAdd({ npc = 950, stars = 1, shiny = true })
	Check("[REL] brillant de Réserve : +20", NS:SpecimenIsReference(shinyId) and NS:SpecimenRelease(shinyRes) == 20
		and NS:Paillettes() == 23)
	Check("[PAIL] dépenser", select(1, NS:PaillettesSpend(5, "test")) == true and NS:Paillettes() == 18)
	local ok, short = NS:PaillettesSpend(100, "test")
	Check("[PAIL] pas assez : refusé, solde intact", ok == false and short == "short" and NS:Paillettes() == 18)
	Check("[PAIL] gagner", NS:PaillettesAdd(7, "mission") == 25 and NS:CaptureData().paillettesEarned == 30)
	local list = NS:SpecimenList({ npc = 950, where = "codex" })
	Check("[LIST] filtre Codex d'une espèce : normale + brillante", #list == 2)
	Check("[LIST] Réserve triée par étoiles", #NS:SpecimenReserve() == 1 and NS:SpecimenReserve()[1].id == one)
end

-- 10. Réplique au coup fatal --------------------------------------------------------------------------------------
do
	Say("-- qc215 : le compagnon remarque un 3 étoiles ou une brillante")
	Q.Reset()
	NS:NotifyState().at = NS.Now()   -- (la bulle « Au carnet » attend son tour)
	Q.Roll(0.99)
	Q.SeeKill(5200, { name = "Kodo magnifique" })
	math.random = Q.random
	Check("[LINE] 3 étoiles : « magnifique »", NS.companionBubbleKey == "CAPTURE_GREAT", tostring(NS.companionBubbleKey))
	Q.Quiet()
	Check("[LINE] brillante : sa réplique", NS:CaptureGreatLine({ name = "Loup", stars = 1, shiny = true }) == true
		and NS.companionBubbleKey == "CAPTURE_GREAT_SHINY")
	Q.Quiet()
	Check("[LINE] 2 étoiles : rien", NS:CaptureGreatLine({ name = "Loup", stars = 2 }) == false)
	Q.combat = true
	Q.Quiet()
	local said = NS:CaptureGreatLine({ name = "Loup", stars = 3 })
	local c = NS.companionRT and NS.companionRT.combat
	Check("[LINE] en combat : gardée pour après le combat", said == false and c and c.best and c.best.pool == "CAPTURE_GREAT")
	Q.combat = false
	local S = NS.CAPTURE_SPECIMEN_STRINGS
	local missing = {}
	for key in pairs(S.fr) do if S.en[key] == nil then missing[#missing + 1] = key end end
	for key in pairs(S.en) do if S.fr[key] == nil then missing[#missing + 1] = key end end
	Check("[LINE] chaînes : parité fr/en", #missing == 0, table.concat(missing, ","))
end

Q.Done()
