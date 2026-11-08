-- Compagnon : « Tout capturer » (QuestCompanion 2.4.0, 2.5.0) : le filet sur
-- toute la file d'un coup. Les entrées (liste, bandeau, /qc filet tout), les
-- verdicts enregistrés d'emblée par le chemin d'un lancer seul, l'ordre de
-- la file, l'aide qui manque, la volée (scènes de capture en parallèle, les
-- brillantes en dernier), Arrêter, Échap, jamais en combat ; le choix au
-- clic sur le filet (2.5.0) et le compte à rebours en pause dès le clic.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local LOT = { saved = {}, random = math.random, units = {}, sounds = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound", "IsShiftKeyDown", "IsControlKeyDown" }
for _, name in ipairs(GLOBALS) do LOT.saved[name] = rawget(_G, name) end
LOT.savedShiny = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"

function LOT.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function LOT.Install()
	local w = LOT
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
	_G.UnitLevel = function() return 20 end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return w.combat == true end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.PlaySound = function(id) w.sounds[#w.sounds + 1] = id; return true end
end
function LOT.Reset()
	ResetWorld()
	if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
	if NS.captureChooser then NS.captureChooser:Hide() end
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
		"captureQueueList", "captureNetButton", "captureToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch = nil, nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	LOT.units, LOT.combat, LOT.sounds = {}, false, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	LOT.Install()
	NS.SHINY_CHANCE = 0
	math.random = LOT.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = true
	NS:DB().captureMuteUntil = nil
	NS:DB().companionCaptureSound = true
	NS:DB().companionCaptureToast = true
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CompanionUpdateVisibility()
end
function LOT.Roll(value)
	math.random = function(a, b)
		if a and b then return LOT.random(a, b) end
		if a then return LOT.random(a) end
		return value
	end
end
function LOT.SeeKill(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or LOT.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	LOT.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, fields.guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, fields.guid, 0)
	return fields.guid
end
-- une brillante dans le filet (la chance de brillant est à 0 pendant les tests)
function LOT.OfferShiny(npcID, name)
	return NS:CaptureOffer(LOT.Guid(npcID, "0000005H1N"), { zoneID = 1413, npcID = npcID }, { name = name })
end
-- les messages du chat, retenus
function LOT.Collect()
	local printed = {}
	local old = NS.Print
	NS.Print = function(_, msg) printed[#printed + 1] = tostring(msg) end
	return printed, function() NS.Print = old end
end
local function Count(list, id) local n = 0; for _, v in ipairs(list) do if v == id then n = n + 1 end end return n end
local function Find(list, text) for _, line in ipairs(list) do if line:find(text, 1, true) then return true end end return false end
-- fait tourner la scène pas à pas jusqu'à `seconds`
local function Run(seconds, step)
	step = step or 0.02
	local t = 0
	while t < seconds do
		-- (l'horloge seule : Mock:Advance jouerait l'OnUpdate de tous les cadres)
		Mock.now = Mock.now + step
		NS:CaptureBatchUpdate(NS.Now())
		t = t + step
	end
end

-- 1. Les entrées : bandeau, liste, commande ------------------------------------------------
do
	Say("-- tout capturer : les entrées")
	LOT.Reset()
	LOT.SeeKill(6100, { name = "Raptor A" })
	local toast = NS.captureToast
	Check("[LOT] un seul candidat : pas de « Tout capturer » sur le bandeau", toast and toast:IsShown() and toast.all
		and not toast.all:IsShown())
	LOT.SeeKill(6101, { name = "Raptor B" })
	Check("[LOT] deux candidats : « Tout capturer » sur le bandeau", toast:IsShown() and toast.all:IsShown()
		and toast.all:GetText() == NS.L.CAPTURE_BATCH_ACTION)
	do
		-- rangée du bas : Tout capturer, Ignorer, Sourdine, chaînés de droite à gauche,
		-- sans chevaucher l'icône ni le texte ; l'aide garde sa ligne au-dessus
		local p = toast.all.lastPoint
		Check("[LOT] bandeau : à gauche d'Ignorer, même rangée", p and p.point == "RIGHT" and p.relTo == toast.ignore
			and p.relPoint == "LEFT" and toast.all:GetHeight() == toast.ignore:GetHeight())
		local textLeft = (toast.contentLeft or 14) + 34 + 10
		local row = toast.all:GetWidth() + 6 + toast.ignore:GetWidth() + 6 + toast.mute:GetWidth() + 8
		Check("[LOT] bandeau : la rangée tient à droite du texte", row <= toast:GetWidth() - textLeft, row)
		local _, _, _, _, hintY = toast.hint:GetPoint(1)
		Check("[LOT] bandeau : l'aide reste sur sa ligne (y=-57)", hintY == -57, hintY)
		Check("[LOT] bandeau : la rangée de sourdine passe par-dessus", toast.muteRow:GetFrameLevel() > toast.all:GetFrameLevel())
	end
	-- la liste du clic droit
	NS.captureNetButton:Click("RightButton")
	local list = NS.captureQueueList
	Check("[LOT] liste : « Tout capturer » en haut, à gauche du ×", list and list.all and list.all:IsShown()
		and list.all.lastPoint.relTo == list.close and list.all.lastPoint.point == "RIGHT")
	Check("[LOT] liste : le bouton ne déborde pas sur le titre",
		list.all:GetWidth() + 6 + 18 + 8 + 12 + #list.title:GetText() * 6.4 <= list:GetWidth(), list.all:GetWidth())
	LOT.Roll(0)
	list.all:Click()
	Check("[LOT] clic dans la liste : tout part, la liste se ferme", not list:IsShown() and #NS:CaptureQueue() == 0
		and NS.captureBatch and NS.captureBatch.tried == 2)
	NS:CaptureBatchStop(true)
	-- un seul candidat : la liste ne le propose pas
	LOT.SeeKill(6102, { name = "Raptor C" })
	NS:CaptureShowQueueList()
	Check("[LOT] liste avec un seul candidat : pas de « Tout capturer »", not list.all:IsShown())
	NS:CaptureHideQueueList()
	-- le bandeau aussi
	LOT.SeeKill(6103, { name = "Raptor D" })
	toast.all:Click()
	Check("[LOT] clic sur le bandeau : tout part, le bandeau s'efface", not toast:IsShown() and #NS:CaptureQueue() == 0
		and NS.captureBatch.tried == 2)
	NS:CaptureBatchStop(true)
	-- /qc filet tout
	LOT.SeeKill(6104, { name = "Raptor E" })
	LOT.SeeKill(6105, { name = "Raptor F" })
	NS.EXTRA_COMMANDS["filet"](NS, "tout")
	Check("[LOT] /qc filet tout", #NS:CaptureQueue() == 0 and NS.captureBatch.tried == 2)
	NS:CaptureBatchStop(true)
	LOT.SeeKill(6106, { name = "Raptor G" })
	NS.EXTRA_COMMANDS["net"](NS, "all")
	Check("[LOT] /qc net all (alias)", #NS:CaptureQueue() == 0 and NS.captureBatch.tried == 1)
	NS:CaptureBatchStop(true)
	-- le reste de la commande ne change pas
	LOT.SeeKill(6107, { name = "Raptor H" })
	NS.EXTRA_COMMANDS["filet"](NS, "")
	Check("[LOT] /qc filet : toujours un lancer seul", NS:CaptureState().rolling ~= nil)
	NS.captureStage:Hide()
	NS:CaptureState().rolling = nil
	local printed, restore = LOT.Collect()
	NS.EXTRA_COMMANDS["filet"](NS, "tout")
	restore()
	Check("[LOT] /qc filet tout, filet vide : rien à capturer", printed[1] == NS.L.CAPTURE_Q_NOTHING, printed[1])
	local missing = {}
	for key in pairs(NS.CAPTURE_BATCH_STRINGS.fr) do
		if not NS.CAPTURE_BATCH_STRINGS.en[key] then missing[#missing + 1] = key end
	end
	Check("[LOT] textes fr et en", #missing == 0, table.concat(missing, ", "))
end

-- 2. Verdicts enregistrés d'emblée, par le chemin d'un lancer seul ------------------------------
do
	Say("-- tout capturer : verdicts enregistrés d'emblée")
	LOT.Reset()
	LOT.SeeKill(6200, { name = "Loup A" })
	LOT.SeeKill(6201, { name = "Loup B" })
	LOT.SeeKill(6202, { name = "Loup C" })
	local tries = NS:CaptureData().tries
	local resolved = 0
	local resolve = NS.CaptureResolve
	NS.CaptureResolve = function(self, rolling, ...) resolved = resolved + 1; return resolve(self, rolling, ...) end
	LOT.sounds = {}
	local printed, restore = LOT.Collect()
	LOT.Roll(0)
	local batch = NS:CaptureBatch()
	NS.CaptureResolve = resolve
	local data = NS:CaptureData()
	Check("[LOT] trois essais, chacun par ns:CaptureResolve", batch and batch.tried == 3 and resolved == 3, resolved)
	Check("[LOT] enregistrés avant le moindre filet posé", data.creatures[6200] and data.creatures[6201]
		and data.creatures[6202] and data.tries == tries + 3 and NS.captureBatchFrame:IsShown()
		and NS.captureBatchFrame.tiles[1].verdict == nil)
	Check("[LOT] étoiles tirées par l'enveloppe de la file", data.creatures[6200].stars ~= nil and batch.results[1].stars ~= nil)
	Check("[LOT] pendant le tirage : ni musique de réussite ni fanfare", Count(LOT.sounds, NS.CAPTURE_SOUNDS.ok) == 0
		and Count(LOT.sounds, NS.CAPTURE_SOUNDS.shiny) == 0 and Count(LOT.sounds, NS.CAPTURE_SOUNDS.throw) == 1)
	Check("[LOT] le chat ne gâche pas la surprise", #printed == 0, printed[1])
	Check("[LOT] « Captures : 0 » au départ", NS.captureBatchFrame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 0))
	Run(8)
	restore()
	Check("[LOT] fin de la scène : tous les verdicts, compteur à 3", batch.done and batch.resolved == 3
		and NS.captureBatchFrame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 3))
	Check("[LOT] … puis le chat reçoit tout, et le bilan", Find(printed, "Loup A") and Find(printed, "Loup C")
		and printed[#printed] == NS:F("CAPTURE_BATCH_SUMMARY", 3, 3), printed[#printed])
	Check("[LOT] le bouton devient « Fermer »", NS.captureBatchFrame.stop:GetText() == NS.L.CAPTURE_BATCH_CLOSE)
	NS.captureBatchFrame.stop:Click()
	Check("[LOT] Fermer : la scène se ferme", not NS.captureBatchFrame:IsShown())
	-- une face : le nom en couleur de rareté et les étoiles ; un échec : « échappée »
	LOT.Reset()
	LOT.SeeKill(6210, { name = "Ours élite", class = "elite" })
	LOT.SeeKill(6211, { name = "Ours" })
	LOT.Roll(0.4)   -- 40 % : le normal (50 %) passe, l'élite (25 %) s'échappe
	batch = NS:CaptureBatch()
	NS:CaptureBatchStop(true)
	local tiles = NS.captureBatchFrame.tiles
	Check("[LOT] l'élite d'abord (ordre de la file), échappée", batch.results[1].target.npcID == 6210
		and not batch.results[1].success and tiles[1].stars:GetText() == NS.L.CAPTURE_BATCH_FLED
		and NS:CaptureData().creatures[6210] == nil)
	local rarity = NS:CaptureRarity({ class = "normal" })
	Check("[LOT] capturé : nom en couleur de rareté, étoiles", batch.results[2].success and tiles[2].name:GetText() == "Ours"
		and tiles[2].name.textColor[1] == rarity.color[1] and tiles[2].stars:GetText() == NS:CaptureStarsText(batch.results[2].stars, 14))
end

-- 3. Ordre de la file ---------------------------------------------------------------------------
do
	Say("-- tout capturer : ordre de priorité")
	LOT.Reset()
	LOT.SeeKill(6300, { name = "Normal" })
	LOT.SeeKill(6301, { name = "Élite", class = "elite" })
	LOT.OfferShiny(6302, "Brillant")
	local expected = {}
	for index, candidate in ipairs(NS:CaptureQueue()) do expected[index] = candidate.npcID end
	LOT.Roll(0)
	local batch = NS:CaptureBatch()
	local got = {}
	for index, result in ipairs(batch.results) do got[index] = result.target.npcID end
	Check("[LOT] brillante > élite > normal, comme la file", table.concat(got, ",") == "6302,6301,6300"
		and table.concat(got, ",") == table.concat(expected, ","), table.concat(got, ","))
	NS:CaptureBatchStop(true)
	-- deux fois la même espèce : la seconde devient une tentative d'étoiles…
	LOT.Reset()
	LOT.SeeKill(6310, { name = "Kodo", spawn = "0000000001" })
	LOT.SeeKill(6310, { name = "Kodo", spawn = "0000000002" })
	LOT.Roll(0)
	local stars = NS.CaptureRollStars   -- 3 étoiles du premier coup
	NS.CaptureRollStars = function() return 3 end
	batch = NS:CaptureBatch()
	NS.CaptureRollStars = stars
	Check("[LOT] même espèce déjà à 3 étoiles dans le lot : la seconde sort sans essai", batch.tried == 1
		and #NS:CaptureQueue() == 0, batch.tried)
	NS:CaptureBatchStop(true)
end

-- 4. L'aide manque ------------------------------------------------------------------------------
do
	Say("-- tout capturer : l'aide manque")
	LOT.Reset()
	for npc = 6400, 6403 do LOT.SeeKill(npc, { name = "Bête " .. npc }) end
	local data = NS:CaptureData()
	data.items.lasso = 2
	NS:CaptureState().aid = "lasso"
	local printed, restore = LOT.Collect()
	LOT.Roll(0)
	local batch = NS:CaptureBatch()
	Check("[LOT] deux lassos pour quatre : deux essais, deux restent dans le filet", batch.tried == 2 and batch.short
		and #NS:CaptureQueue() == 2 and data.items.lasso == 0, batch.tried)
	Check("[LOT] les deux premiers de la file, avec l'aide", batch.results[1].target.npcID == 6400
		and batch.results[2].target.npcID == 6401 and batch.results[1].aid == "lasso" and batch.results[2].aid == "lasso")
	NS:CaptureBatchStop(true)
	restore()
	Check("[LOT] c'est dit dans le chat", Find(printed, NS:F("CAPTURE_BATCH_SHORT", NS:CaptureAidLabel("lasso"), 2, 4)),
		table.concat(printed, " | "))
	Check("[LOT] l'aide montrée dans la scène", NS.captureBatchFrame.aidText:GetText() == NS:CaptureAidLabel("lasso"))
	-- sans aide choisie : pas de limite
	NS:CaptureState().aid = nil
	batch = NS:CaptureBatch()
	Check("[LOT] sans aide : tout le reste part", batch.tried == 2 and not batch.short and #NS:CaptureQueue() == 0)
	NS:CaptureBatchStop(true)
end

-- 5. La volée : des scènes de capture en parallèle, les brillantes en dernier ----------------------
do
	Say("-- tout capturer : la volée")
	LOT.Reset()
	-- B : espèce déjà capturée (1 étoile) -> amélioration
	NS:CaptureData().creatures[6501] = { name = "Connu", class = "normal", normal = true, stars = 1, at = 1 }
	NS:CaptureData().count = (NS:CaptureData().count or 0) + 1
	LOT.SeeKill(6500, { name = "Nouveau rare", class = "rare" })     -- nouvelle espèce, capturée : avec la volée
	LOT.SeeKill(6501, { name = "Connu" })
	LOT.SeeKill(6502, { name = "Fuyard", class = "elite" })        -- échappée
	LOT.SeeKill(6503, { name = "Nouveau" })                         -- nouvelle espèce, capturée : avec la volée
	LOT.OfferShiny(6504, "Brillant")                                -- brillante : la toute dernière
	local chance = NS.CaptureChance
	NS.CaptureChance = function(self, info, aid, ...)
		if info and info.npcID == 6502 then return 0, false end
		return 0.95, false
	end
	LOT.Roll(0.5)
	LOT.sounds = {}
	local batch = NS:CaptureBatch()
	NS.CaptureChance = chance
	local frame = NS.captureBatchFrame
	local n = #batch.cards
	-- (les cases suivent l'ordre de la file : la brillante en tête de grille)
	local byNpc = {}
	for _, card in ipairs(batch.cards) do byNpc[card.result.target.npcID] = card end
	local shinyCard = byNpc[6504]
	-- la volée : tous les filets partent dans la fenêtre du décalage
	local firstDrop, lastDrop, maxGap = math.huge, 0, 0
	local drops = {}
	for _, card in ipairs(batch.cards) do
		firstDrop = math.min(firstDrop, card.dropAt); lastDrop = math.max(lastDrop, card.dropAt)
		drops[#drops + 1] = card.dropAt
	end
	table.sort(drops)
	for index = 2, #drops do maxGap = math.max(maxGap, drops[index] - drops[index - 1]) end
	Check("[LOT] volée : tous les filets partent dans la fenêtre du décalage", n == 5 and lastDrop - firstDrop <= (n - 1) * NS.CAPTURE_BATCH_STAGGER + 1e-6
		and maxGap >= 0.08 - 1e-6 and maxGap <= 0.15 + 1e-6 and firstDrop == NS.CAPTURE_BATCH_LEAD, lastDrop .. " / " .. maxGap)
	-- chaque case montre les secousses de son tirage ; la brillante, au moins autant
	local capsOk = true
	for _, card in ipairs(batch.cards) do
		if card.special then
			if card.cap < card.result.shakes then capsOk = false end
		elseif card.cap ~= card.result.shakes then capsOk = false end
	end
	Check("[LOT] secousses : celles du tirage (rolling.shakes) ; la brillante au moins autant", capsOk)
	local order = {}
	for _, card in ipairs(batch.order) do order[#order + 1] = card.result.target.npcID end
	Check("[LOT] la brillante tombe en dernier", order[#order] == 6504 and batch.order[#order].special
		and not batch.order[1].special, table.concat(order, ","))
	local lastOrdinary, shinyAt = 0, 0
	for _, card in ipairs(batch.cards) do
		if card.special then shinyAt = card.resultAt else lastOrdinary = math.max(lastOrdinary, card.resultAt) end
	end
	Check("[LOT] … après une pause, en se débattant plus longtemps", shinyAt >= lastOrdinary + NS.CAPTURE_BATCH_PAUSE - 1e-6
		and shinyCard.cap > shinyCard.result.shakes, lastOrdinary .. " / " .. shinyAt)
	-- avant la volée : les créatures seules, aucun verdict
	Check("[LOT] départ : créatures au repos, ni filet ni verdict", not frame.tiles[1].net:IsShown()
		and frame.tiles[1].verdict == nil and frame.tiles[1].fallback:IsShown() and frame.tiles[1].stars:GetText() == "")
	Check("[LOT] la brillante est dans la volée (même départ), pas à part", shinyCard.dropAt == NS.CAPTURE_BATCH_LEAD)
	-- tous les filets posés avant le premier verdict : elles se jouent en même temps
	Run(lastDrop + 0.05, 0.01)
	local allNets, anyVerdict = true, false
	for _, card in ipairs(batch.cards) do
		if not card.tile.net:IsShown() then allNets = false end
		if card.resolved then anyVerdict = true end
	end
	Check("[LOT] en même temps : les cinq filets posés, aucun verdict encore", allNets and not anyVerdict)
	Check("[LOT] le filet qui tombe : la texture du filet, entière", frame.tiles[1].net.texture == NS.CAPTURE_ART.net
		and frame.tiles[1].net.texCoord[2] == NS.CAPTURE_COORDS.netWhole[2])
	-- jusqu'à juste avant la brillante : toutes les autres sont tombées
	Run(shinyAt - 0.03 - (NS.Now() - batch.startedAt), 0.01)
	local others = true
	for _, card in ipairs(batch.cards) do if not card.special and not card.resolved then others = false end end
	Check("[LOT] juste avant la brillante : toutes les autres ont leur verdict, elle se débat encore", others
		and not shinyCard.resolved and shinyCard.tile.net:IsShown())
	local fled = byNpc[6502]
	Check("[LOT] échappée : filet déchiré, « échappée »", fled.result.target.npcID == 6502 and fled.tile.verdict == "fail"
		and fled.tile.net.texCoord[1] == NS.CAPTURE_COORDS.netTorn[1] and fled.tile.stars:GetText() == NS.L.CAPTURE_BATCH_FLED)
	Run(8, 0.01)
	Check("[LOT] tout est tombé, la brillante en dernier", batch.done and batch.resolved == 5 and shinyCard.settled)
	local shook = true
	for _, card in ipairs(batch.cards) do if card.shook ~= card.cap then shook = false end end
	Check("[LOT] chaque filet s'est secoué le nombre prévu", shook)
	Check("[LOT] la brillante : fanfare (une), halo doré", Count(LOT.sounds, NS.CAPTURE_SOUNDS.shiny) == 1
		and shinyCard.tile.halo:IsShown(), table.concat(LOT.sounds, ","))
	local fresh = byNpc[6503]
	Check("[LOT] l'échappée a filé (créature effacée), les prises restent", not fled.tile.fallback:IsShown()
		and fresh.tile.fallback:IsShown() and not fresh.tile.net:IsShown())
	Check("[LOT] capturée : étoiles et étiquette « Nouvelle »", fresh.tile.stars:IsShown()
		and fresh.tile.tag:GetText() == (NS.Theme.Upper and NS.Theme.Upper(NS.L.CAPTURE_BATCH_NEW) or NS.L.CAPTURE_BATCH_NEW))
	-- douze cases : grille 4 × 3, bruits de filet espacés, réussites groupées, modèles plafonnés
	LOT.Reset()
	for npc = 6510, 6521 do
		NS:CaptureData().creatures[npc] = { name = "Connu " .. npc, class = "normal", normal = true, stars = 1, at = 1 }
		LOT.SeeKill(npc, { name = "Connu " .. npc })
	end
	LOT.Roll(0)
	LOT.sounds = {}
	local netTimes, okTimes = {}, {}
	_G.PlaySound = function(id)
		LOT.sounds[#LOT.sounds + 1] = id
		if id == NS.CAPTURE_SOUNDS.net then netTimes[#netTimes + 1] = NS.Now() end
		if id == NS.CAPTURE_SOUNDS.ok then okTimes[#okTimes + 1] = NS.Now() end
		return true
	end
	batch = NS:CaptureBatch()
	frame = NS.captureBatchFrame
	Check("[LOT] douze cases : grille de 4 × 3", #batch.cards == 12 and select(2, NS:CaptureBatchGrid(12)) == 3
		and frame:GetWidth() >= 4 * 104)
	Check("[LOT] modèles 3D pour les 8 premières seulement", frame.tiles[8].model ~= nil and frame.tiles[9].model == nil
		and frame.tiles[12].model == nil)
	Run(6, 0.005)
	local minGap, okGap = math.huge, math.huge
	for index = 2, #netTimes do minGap = math.min(minGap, netTimes[index] - netTimes[index - 1]) end
	for index = 2, #okTimes do okGap = math.min(okGap, okTimes[index] - okTimes[index - 1]) end
	Check("[LOT] bruit de filet : au plus un toutes les 0,06 s", #netTimes >= 2 and minGap >= NS.CAPTURE_BATCH_SOUND_GAP - 1e-6,
		#netTimes .. " / " .. minGap)
	Check("[LOT] douze réussites : musiques groupées", #okTimes >= 1 and #okTimes < 12
		and (#okTimes < 2 or okGap >= NS.CAPTURE_BATCH_OK_GAP - 1e-6), #okTimes .. " / " .. okGap)
	Check("[LOT] douze verdicts, compteur à 12", batch.done and frame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 12))
	LOT.Install()
	-- les cases resservent : un lot plus petit garde les mêmes cadres
	local first = frame.tiles[1]
	frame:Hide()
	LOT.SeeKill(6530, { name = "Petit A" })
	LOT.SeeKill(6531, { name = "Petit B" })
	batch = NS:CaptureBatch()
	Check("[LOT] cases réutilisées, les autres cachées", frame.tiles[1] == first and #frame.tiles == 12
		and frame.tiles[2]:IsShown() and not frame.tiles[3]:IsShown())
	NS:CaptureBatchStop(true)
	frame:Hide()
end

-- 6. Arrêter, Échap ---------------------------------------------------------------------------
do
	Say("-- tout capturer : Arrêter et Échap")
	LOT.Reset()
	LOT.SeeKill(6600, { name = "Hyène A" })
	LOT.SeeKill(6601, { name = "Hyène B" })
	LOT.OfferShiny(6602, "Hyène dorée")
	LOT.Roll(0)
	local printed, restore = LOT.Collect()
	LOT.sounds = {}
	local batch = NS:CaptureBatch()
	local frame = NS.captureBatchFrame
	Check("[LOT] « Arrêter » pendant la scène", frame.stop:GetText() == NS.L.CAPTURE_BATCH_STOP and frame.footer:GetText() == NS.L.CAPTURE_BATCH_RUNNING)
	Run(NS.CAPTURE_BATCH_LEAD + 0.2)
	frame.stop:Click()
	local all = true
	for _, card in ipairs(batch.cards) do
		if not (card.resolved and card.settled and not card.tile.net:IsShown() and card.tile.verdict == "ok") then all = false end
	end
	Check("[LOT] Arrêter : tous les verdicts d'un coup, filets rangés", all and batch.done and batch.resolved == 3)
	Check("[LOT] … compteur à jour, fanfare une fois, résultats déjà là", frame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 3)
		and Count(LOT.sounds, NS.CAPTURE_SOUNDS.shiny) == 1 and NS:CaptureData().creatures[6602].shiny == true)
	restore()
	Check("[LOT] … et le bilan dans le chat", printed[#printed] == NS:F("CAPTURE_BATCH_SUMMARY_SHINY", 3, 3, 1), printed[#printed])
	Check("[LOT] le bouton ferme ensuite", frame.stop:GetText() == NS.L.CAPTURE_BATCH_CLOSE)
	-- figé : l'horloge ne rejoue rien
	local shook = batch.cards[1].shook
	Run(3)
	Check("[LOT] après Arrêter : plus rien ne bouge", batch.cards[1].shook == shook and not batch.cards[1].tile.net:IsShown())
	frame.stop:Click()
	Check("[LOT] fermé", not frame:IsShown())
	-- Échap : la scène est inscrite sous son nom ; cachée, tout se termine
	local registered = false
	for _, name in ipairs(UISpecialFrames) do if name == "QuestCompanionCaptureBatch" then registered = true end end
	Check("[LOT] inscrite pour Échap", registered and frame:GetName() == "QuestCompanionCaptureBatch")
	LOT.SeeKill(6610, { name = "Chacal A" })
	LOT.SeeKill(6611, { name = "Chacal B" })
	printed, restore = LOT.Collect()
	LOT.sounds = {}
	batch = NS:CaptureBatch()
	frame:Hide()
	frame:GetScript("OnHide")(frame)
	restore()
	Check("[LOT] Échap : fermé, lot terminé sans bruit, messages livrés", not frame:IsShown() and batch.done
		and batch.resolved == 2 and Count(LOT.sounds, NS.CAPTURE_SOUNDS.ok) == 0
		and printed[#printed] == NS:F("CAPTURE_BATCH_SUMMARY", 2, 2), printed[#printed])
	-- le × aussi
	LOT.SeeKill(6620, { name = "Chacal C" })
	LOT.SeeKill(6621, { name = "Chacal D" })
	batch = NS:CaptureBatch()
	frame.close:Click()
	frame:GetScript("OnHide")(frame)
	Check("[LOT] × : fermé, lot terminé", not frame:IsShown() and batch.done)
	-- capture animée coupée : les verdicts d'emblée, sans animation
	NS:DB().companionCaptureAnim = false
	LOT.SeeKill(6630, { name = "Chacal E" })
	LOT.SeeKill(6631, { name = "Chacal F" })
	batch = NS:CaptureBatch()
	local settled = true
	for _, card in ipairs(batch.cards) do if not (card.settled and card.shook == 0 and not card.tile.net:IsShown()) then settled = false end end
	Check("[LOT] capture animée coupée : les verdicts d'emblée, sans filet ni secousse", batch.done and batch.resolved == 2
		and settled and frame:IsShown())
	NS:DB().companionCaptureAnim = true
	frame:Hide()
end

-- 6b. Deux abattus en combat : à la fin du combat, le bandeau propose « Tout capturer » -----------
do
	Say("-- tout capturer : après un combat")
	LOT.Reset()
	LOT.combat = true
	LOT.SeeKill(6710, { name = "Raptor A" })
	LOT.SeeKill(6711, { name = "Raptor B" })
	LOT.combat = false
	NS:CaptureTick(NS.Now() + 0.5)
	local toast = NS.captureToast
	Check("[LOT] fin de combat, deux candidats : bandeau avec « Tout capturer »", toast and toast:IsShown()
		and toast.all and toast.all:IsShown(), toast and tostring(toast:IsShown()) .. "/" .. tostring(toast.all and toast.all:IsShown()))
	NS:CaptureToggleQueueList()
	local list = NS.captureQueueList
	Check("[LOT] fin de combat : la liste propose « Tout capturer »", list and list.all and list.all:IsShown())
end

-- 7. Jamais en combat ; le tutoriel suit ------------------------------------------------------
do
	Say("-- tout capturer : combat et tutoriel")
	LOT.Reset()
	LOT.SeeKill(6700, { name = "Sanglier A" })
	LOT.SeeKill(6701, { name = "Sanglier B" })
	LOT.combat = true
	local printed, restore = LOT.Collect()
	local batch, why = NS:CaptureBatch()
	restore()
	Check("[LOT] en combat : refusé, rien ne part", batch == nil and why == "combat" and #NS:CaptureQueue() == 2
		and NS:CaptureData().creatures[6700] == nil and printed[1] == NS.L.CAPTURE_BATCH_COMBAT, printed[1])
	Check("[LOT] en combat : pas de scène", not (NS.captureBatchFrame and NS.captureBatchFrame:IsShown()))
	LOT.combat = false
	-- un lancer seul en cours (avant son verdict) : on attend
	LOT.Roll(0)
	NS:CaptureThrow()
	printed, restore = LOT.Collect()
	batch, why = NS:CaptureBatch()
	restore()
	Check("[LOT] un filet déjà lancé : on attend son verdict", batch == nil and why == "busy" and printed[1] == NS.L.CAPTURE_BATCH_BUSY)
	for _ = 1, 12 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	NS:CaptureState().rolling = nil
	if NS.captureStage then NS.captureStage:Hide() end
	-- le tutoriel de la ménagerie : « filet lancé », puis « scène refermée » avec le verdict
	LOT.SeeKill(6710, { name = "Sanglier C" })
	LOT.SeeKill(6711, { name = "Sanglier D" })
	local calls = {}
	local advance = NS.CompanionSequenceAdvance
	NS.CompanionSequenceAdvance = function(self, tag, info) calls[#calls + 1] = tag .. (info and (info.ok and ":ok" or ":fail") or "") end
	batch = NS:CaptureBatch()
	local before = table.concat(calls, ",")
	NS:CaptureBatchStop(true)
	NS.CompanionSequenceAdvance = advance
	Check("[LOT] tutoriel : « net » au lancer, « stage » à la fin", before == "net" and table.concat(calls, ",") == "net,stage:ok",
		table.concat(calls, ","))
	-- capture coupée : rien
	NS:DB().companionCapture = false
	batch, why = NS:CaptureBatch()
	NS:DB().companionCapture = true
	Check("[LOT] capture coupée : rien", batch == nil and why == "off")
	NS.captureBatchFrame:Hide()
end

-- 8. Le choix au clic sur le filet (2.5.0) -----------------------------------------------------
-- le lancer seul en cours va jusqu'au bout (scène refermée)
function LOT.Settle()
	for _ = 1, 14 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	NS:CaptureState().rolling = nil
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CaptureTick(NS.Now())
end
do
	Say("-- tout capturer : le choix au clic sur le filet")
	LOT.Reset()
	LOT.Roll(0)
	-- un seul candidat : le clic capture directement, comme avant
	LOT.SeeKill(6800, { name = "Seul" })
	NS.captureNetButton:Click("LeftButton")
	Check("[LOT] un candidat : le clic capture directement", NS:CaptureState().rolling ~= nil
		and NS:CaptureState().rolling.target.npcID == 6800 and not (NS.captureChooser and NS.captureChooser:IsShown()))
	LOT.Settle()
	-- deux candidats : le choix, près du filet, rien ne part
	LOT.SeeKill(6801, { name = "Raptor élite", class = "elite" })
	LOT.SeeKill(6802, { name = "Raptor" })
	local net = NS.captureNetButton
	net:Click("LeftButton")
	local chooser = NS.captureChooser
	Check("[LOT] deux candidats : le choix s'ouvre, rien ne part", chooser and chooser:IsShown()
		and NS:CaptureState().rolling == nil and #NS:CaptureQueue() == 2 and not (NS.captureBatch and not NS.captureBatch.done))
	Check("[LOT] choix : ancré au-dessus du filet", chooser.lastPoint and chooser.lastPoint.relTo == net
		and chooser.lastPoint.point == "BOTTOM" and chooser.lastPoint.relPoint == "TOP")
	Check("[LOT] choix : « Capturer : le meilleur » et « Tout capturer (2) »",
		chooser.single:GetText() == NS:F("CAPTURE_CHOOSE_ONE", "Raptor élite") and chooser.all:GetText() == NS:F("CAPTURE_CHOOSE_ALL", 2),
		chooser.single:GetText() .. " / " .. chooser.all:GetText())
	Check("[LOT] choix : panneau du thème (bandeau), nommé", chooser.chrome == "toast"
		and chooser:GetName() == "QuestCompanionCaptureChooser" and chooser.strata == "DIALOG")
	local registered = false
	for _, name in ipairs(UISpecialFrames) do if name == "QuestCompanionCaptureChooser" then registered = true end end
	Check("[LOT] choix : Échap le referme (UISpecialFrames)", registered)
	Check("[LOT] choix : les boutons tiennent dans le panneau", chooser.single:GetWidth() + (chooser.contentLeft or 14) + 10
		<= chooser:GetWidth() + 1e-6 and chooser.all.lastPoint.y < chooser.single.lastPoint.y - chooser.single:GetHeight())
	-- un second clic sur le filet le referme
	net:Click("LeftButton")
	Check("[LOT] second clic sur le filet : le choix se referme, rien ne part", not chooser:IsShown()
		and NS:CaptureState().rolling == nil and #NS:CaptureQueue() == 2)
	-- « Capturer : … » : le meilleur seul
	net:Click("LeftButton")
	chooser.single:Click()
	Check("[LOT] « Capturer : … » : le meilleur part seul, le choix se ferme", not chooser:IsShown()
		and NS:CaptureState().rolling and NS:CaptureState().rolling.target.npcID == 6801 and #NS:CaptureQueue() == 1)
	LOT.Settle()
	-- « Tout capturer (N) »
	LOT.SeeKill(6803, { name = "Raptor B" })
	net:Click("LeftButton")
	Check("[LOT] le choix revient avec le nouveau venu", chooser:IsShown() and chooser.all:GetText() == NS:F("CAPTURE_CHOOSE_ALL", 2))
	chooser.all:Click()
	Check("[LOT] « Tout capturer » : tout part, le choix se ferme", not chooser:IsShown() and NS.captureBatch
		and NS.captureBatch.tried == 2 and #NS:CaptureQueue() == 0)
	NS:CaptureBatchStop(true)
	NS.captureBatchFrame:Hide()
	-- une brillante en tête : marquée sur le bouton
	LOT.SeeKill(6804, { name = "Raptor C" })
	LOT.OfferShiny(6805, "Raptor doré")
	net:Click("LeftButton")
	Check("[LOT] brillante en tête : « Capturer : Raptor doré (brillant) »",
		chooser.single:GetText() == NS:F("CAPTURE_CHOOSE_ONE", NS:F("CAPTURE_SHINY_TAG", "Raptor doré")), chooser.single:GetText())
	-- clic droit, choix ouvert : le choix se ferme, la liste s'ouvre
	net:Click("RightButton")
	Check("[LOT] clic droit : la liste, le choix fermé", not chooser:IsShown() and NS.captureQueueList:IsShown())
	NS:CaptureHideQueueList()
	-- Maj+clic : le meilleur tout de suite
	_G.IsShiftKeyDown = function() return true end
	net:Click("LeftButton")
	_G.IsShiftKeyDown = nil
	Check("[LOT] Maj+clic : le meilleur tout de suite, sans le choix", not chooser:IsShown()
		and NS:CaptureState().rolling and NS:CaptureState().rolling.target.npcID == 6805)
	LOT.Settle()
	-- Ctrl+clic : tout tout de suite
	LOT.SeeKill(6806, { name = "Raptor D" })
	_G.IsControlKeyDown = function() return true end
	net:Click("LeftButton")
	_G.IsControlKeyDown = nil
	Check("[LOT] Ctrl+clic : tout tout de suite", not chooser:IsShown() and NS.captureBatch.tried == 2 and #NS:CaptureQueue() == 0)
	NS:CaptureBatchStop(true)
	NS.captureBatchFrame:Hide()
	-- il se referme seul : file sous deux, combat, Échap, clic ailleurs
	LOT.SeeKill(6807, { name = "Raptor E" })
	LOT.SeeKill(6808, { name = "Raptor F" })
	net:Click("LeftButton")
	NS:CaptureQueueRemove(NS:CaptureQueue()[1])
	Check("[LOT] file retombée à un : le choix se referme", not chooser:IsShown())
	LOT.SeeKill(6809, { name = "Raptor G" })
	net:Click("LeftButton")
	Check("[LOT] (rouvert)", chooser:IsShown())
	LOT.combat = true
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Check("[LOT] le combat commence : le choix se referme", not chooser:IsShown())
	LOT.combat = false
	net:Click("LeftButton")
	LOT.combat = true
	Mock:Advance(0.2)
	Check("[LOT] en combat (relevé) : le choix se referme aussi", not chooser:IsShown())
	net:Click("LeftButton")
	Check("[LOT] en combat : pas de choix (le filet seul, comme avant)", not chooser:IsShown())
	LOT.combat = false
	LOT.Settle()
	LOT.SeeKill(6810, { name = "Raptor H" })
	LOT.SeeKill(6811, { name = "Raptor I" })
	net:Click("LeftButton")
	chooser:Hide()
	Check("[LOT] Échap : refermé, rien ne part", not chooser:IsShown() and NS:CaptureState().rolling == nil)
	net:Click("LeftButton")
	Mock:Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
	Check("[LOT] clic ailleurs : refermé", not chooser:IsShown() and NS:CaptureState().rolling == nil)
	-- l'infobulle du filet dit le choix et ses raccourcis
	local lines = {}
	local saved = rawget(_G, "GameTooltip")
	_G.GameTooltip = { SetOwner = function() end, AddLine = function(_, text) lines[#lines + 1] = text end, Show = function() end,
		Hide = function() end, AddDoubleLine = function(_, text) lines[#lines + 1] = text end }
	net:GetScript("OnEnter")(net)
	_G.GameTooltip = saved
	local all = table.concat(lines, "\n")
	local count = #NS:CaptureQueue()
	Check("[LOT] infobulle : clic = choisir, Maj+clic, Ctrl+clic", all:find(NS.L.CAPTURE_Q_CLICK_CHOOSE:sub(1, 8), 1, true) ~= nil
		and all:find(NS:F("CAPTURE_Q_CTRL", count), 1, true) ~= nil and all:find(NS.L.CAPTURE_Q_SHIFT:sub(1, 8), 1, true) ~= nil, all)
	-- le bandeau : son clic ouvre le même choix (près du filet) ; « Tout capturer » reste
	NS:CaptureToastShow()
	local toast = NS.captureToast
	Check("[LOT] bandeau à deux candidats : « Clic : choisir »", toast:IsShown() and toast.all:IsShown()
		and toast.hint:GetText():find(NS.L.CAPTURE_TOAST_HINT_CHOOSE, 1, true) ~= nil, toast.hint:GetText())
	local _, _, _, _, hintY = toast.hint:GetPoint(1)
	Check("[LOT] bandeau : l'aide toujours sur sa ligne (y=-57)", hintY == -57)
	toast.button:Click("LeftButton")
	Check("[LOT] clic sur le bandeau : le choix, près du filet ; bandeau effacé, rien ne part", chooser:IsShown()
		and chooser.lastPoint.relTo == net and not toast:IsShown() and NS:CaptureState().rolling == nil and #NS:CaptureQueue() == count)
	chooser.single:Click()
	Check("[LOT] … puis « Capturer : … » : le meilleur", NS:CaptureState().rolling ~= nil and #NS:CaptureQueue() == count - 1)
	LOT.Settle()
	-- textes fr et en du choix
	local missing = {}
	for key in pairs(NS.CAPTURE_BATCH_STRINGS.fr) do
		if not NS.CAPTURE_BATCH_STRINGS.en[key] then missing[#missing + 1] = key end
	end
	Check("[LOT] choix : textes fr et en", #missing == 0, table.concat(missing, ", "))
end

-- 8b. Le tutoriel de la ménagerie avance quel que soit le bouton choisi ------------------------
do
	Say("-- tout capturer : le choix et le tutoriel")
	LOT.Reset()
	LOT.Roll(0)
	local calls = {}
	local advance = NS.CompanionSequenceAdvance
	NS.CompanionSequenceAdvance = function(self, tag) calls[#calls + 1] = tag end
	LOT.SeeKill(6820, { name = "Tuto A" })
	LOT.SeeKill(6821, { name = "Tuto B" })
	NS.captureNetButton:Click("LeftButton")
	local opened = #calls
	NS.captureChooser.single:Click()
	local single = table.concat(calls, ",")
	LOT.Settle()
	calls = {}
	LOT.SeeKill(6822, { name = "Tuto C" })
	NS.captureNetButton:Click("LeftButton")
	NS.captureChooser.all:Click()
	NS:CaptureBatchStop(true)
	NS.CompanionSequenceAdvance = advance
	Check("[LOT] tutoriel : ouvrir le choix n'avance rien", opened == 0)
	Check("[LOT] tutoriel : « Capturer : … » avance « net »", single:find("net", 1, true) == 1, single)
	Check("[LOT] tutoriel : « Tout capturer » avance « net » puis « stage »", calls[1] == "net" and calls[#calls] == "stage",
		table.concat(calls, ","))
	NS.captureBatchFrame:Hide()
end

-- 9. Le compte à rebours en pause dès le clic ----------------------------------------------------
do
	Say("-- tout capturer : le compte à rebours en pause")
	LOT.Reset()
	LOT.Roll(0)
	LOT.SeeKill(6900, { name = "Lynx élite", class = "elite" })
	LOT.SeeKill(6901, { name = "Lynx" })
	Mock:Advance(5); NS:CaptureTick(NS.Now())
	local other = NS:CaptureQueue()[2]
	local left0 = other.expires - NS.Now()
	Check("[LOT] le compte tourne avant le clic", left0 > 24 and left0 < 26 and not NS:CaptureQueuePaused(), left0)
	NS.captureNetButton:Click("LeftButton")
	Check("[LOT] clic sur le filet : le compte s'arrête", NS:CaptureQueuePaused())
	for _ = 1, 8 do Mock:Advance(5); NS:CaptureTick(NS.Now()) end
	Check("[LOT] 40 s plus tard, choix ouvert : les deux attendent toujours", #NS:CaptureQueue() == 2 and NS.captureChooser:IsShown())
	NS:CaptureShowQueueList()
	Check("[LOT] la liste montre un temps figé", NS.captureQueueList.rows[2].detail:GetText():find(NS:F("CAPTURE_Q_LEFT", math.ceil(left0)), 1, true) ~= nil,
		NS.captureQueueList.rows[2].detail:GetText())
	-- (la liste ouverte referme le choix ? non : on rouvre au besoin)
	if not NS.captureChooser:IsShown() then NS.captureNetButton:Click("LeftButton") end
	NS:CaptureHideQueueList()
	-- un nouveau venu pendant la pause garde ses 30 s pour la reprise
	LOT.SeeKill(6902, { name = "Lynx B" })
	local newcomer
	for _, c in ipairs(NS:CaptureQueue()) do if c.npcID == 6902 then newcomer = c end end
	Check("[LOT] nouveau venu pendant la pause : ses 30 s gardées", newcomer and math.abs(newcomer.expires - NS:CaptureQueueClock() - NS.CAPTURE_QUEUE_TIME) < 1e-6)
	NS:CaptureQueueRemove(newcomer)
	-- choix abandonné : le compte reprend avec le temps qui restait
	NS:CaptureChooserHide()
	Check("[LOT] choix refermé sans choisir : le compte reprend…", not NS:CaptureQueuePaused())
	Check("[LOT] … avec le temps qui restait (pas 30 s)", math.abs((other.expires - NS.Now()) - left0) < 0.01, other.expires - NS.Now())
	Mock:Advance(3); NS:CaptureTick(NS.Now())
	Check("[LOT] … et il redescend", math.abs((other.expires - NS.Now()) - (left0 - 3)) < 0.01)
	-- abandon par Échap (OnHide seul) : pareil
	local before = other.expires - NS.Now()
	NS.captureNetButton:Click("LeftButton")
	Mock:Advance(10)
	NS.captureChooser:Hide()
	NS.captureChooser:GetScript("OnHide")(NS.captureChooser)
	Check("[LOT] Échap sur le choix : reprise au même temps", not NS:CaptureQueuePaused()
		and math.abs((other.expires - NS.Now()) - before) < 0.01)
	-- capture du meilleur : l'autre attend toute la scène, puis reprend
	before = other.expires - NS.Now()
	NS.captureNetButton:Click("LeftButton")
	NS.captureChooser.single:Click()
	Check("[LOT] lancer seul : le compte reste en pause", NS:CaptureQueuePaused() and NS:CaptureState().rolling ~= nil)
	local ended
	for _ = 1, 40 do
		Mock:Advance(0.5); NS:CaptureTick(NS.Now())
		if not ended and NS:CaptureState().rolling == nil then ended = NS.Now() end
	end
	Check("[LOT] la scène finie : l'autre est toujours là, le compte a repris", ended and #NS:CaptureQueue() == 1
		and not NS:CaptureQueuePaused())
	local expected = before - (NS.Now() - ended)
	Check("[LOT] … avec le temps qui restait au clic", math.abs((other.expires - NS.Now()) - expected) < 0.11,
		(other.expires - NS.Now()) .. " / " .. expected)
	-- « Tout capturer » qui en laisse (aide qui manque) : pause jusqu'à la fin de la scène
	LOT.Reset()
	LOT.Roll(0)
	for npc = 6910, 6913 do LOT.SeeKill(npc, { name = "Bête " .. npc }) end
	NS:CaptureData().items.lasso = 2
	NS:CaptureState().aid = "lasso"
	local rest = NS:CaptureQueue()[4]
	before = rest.expires - NS.Now()
	NS.captureNetButton:Click("LeftButton")
	NS.captureChooser.all:Click()
	local batch = NS.captureBatch
	Check("[LOT] lot en cours : pause, deux restent", NS:CaptureQueuePaused() and batch.short and #NS:CaptureQueue() == 2)
	Run(1)
	NS:CaptureTick(NS.Now())
	Check("[LOT] pendant la scène : toujours en pause", NS:CaptureQueuePaused() and not batch.done)
	local doneAt
	for _ = 1, 600 do
		Run(0.02, 0.02)
		if batch.done then doneAt = NS.Now(); break end
	end
	NS:CaptureTick(NS.Now())
	Check("[LOT] la scène finie : reprise avec le temps qui restait", doneAt and not NS:CaptureQueuePaused()
		and math.abs((rest.expires - NS.Now()) - before) < 0.01, rest.expires - NS.Now())
	Run(2)
	Check("[LOT] … puis il redescend", math.abs((rest.expires - NS.Now()) - (before - 2)) < 0.03)
	NS:CaptureBatchStop(true)
	NS.captureBatchFrame:Hide()
	NS:CaptureState().aid = nil
end

for _, name in ipairs(GLOBALS) do _G[name] = LOT.saved[name] end
math.random = LOT.random
NS.SHINY_CHANCE = LOT.savedShiny
NS:DB().captureMuteUntil = nil
NS.captureBatch = nil
ResetWorld()
