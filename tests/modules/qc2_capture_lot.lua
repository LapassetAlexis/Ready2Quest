-- Compagnon : « Tout capturer » (QuestCompanion 2.4.0) : le filet sur toute
-- la file d'un coup. Les entrées (liste, bandeau, /qc filet tout), les
-- verdicts enregistrés d'emblée par le chemin d'un lancer seul, l'ordre de
-- la file, l'aide qui manque, la vague (les cartes gardées à la fin),
-- Arrêter, Échap, jamais en combat.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local LOT = { saved = {}, random = math.random, units = {}, sounds = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound" }
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
	Check("[LOT] enregistrés avant la moindre carte retournée", data.creatures[6200] and data.creatures[6201]
		and data.creatures[6202] and data.tries == tries + 3 and NS.captureBatchFrame:IsShown()
		and NS.captureBatchFrame.tiles[1].facing == "back")
	Check("[LOT] étoiles tirées par l'enveloppe de la file", data.creatures[6200].stars ~= nil and batch.results[1].stars ~= nil)
	Check("[LOT] pendant le tirage : ni musique de réussite ni fanfare", Count(LOT.sounds, NS.CAPTURE_SOUNDS.ok) == 0
		and Count(LOT.sounds, NS.CAPTURE_SOUNDS.shiny) == 0 and Count(LOT.sounds, NS.CAPTURE_SOUNDS.throw) == 1)
	Check("[LOT] le chat ne gâche pas la surprise", #printed == 0, printed[1])
	Check("[LOT] « Captures : 0 » au départ", NS.captureBatchFrame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 0))
	Run(8)
	restore()
	Check("[LOT] fin de la scène : tout retourné, compteur à 3", batch.done and batch.revealed == 3
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
	LOT.Roll(0.2)   -- 20 % : le normal (30 %) passe, l'élite (15 %) s'échappe
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

-- 5. La vague : cartes gardées pour la fin ------------------------------------------------------
do
	Say("-- tout capturer : la vague")
	LOT.Reset()
	-- B : espèce déjà capturée (1 étoile) -> amélioration, pas gardée
	NS:CaptureData().creatures[6501] = { name = "Connu", class = "normal", normal = true, stars = 1, at = 1 }
	NS:CaptureData().count = (NS:CaptureData().count or 0) + 1
	LOT.SeeKill(6500, { name = "Nouveau rare", class = "rare" })     -- nouvelle espèce, capturée : gardée
	LOT.SeeKill(6501, { name = "Connu" })
	LOT.SeeKill(6502, { name = "Fuyard", class = "elite" })        -- échappée
	LOT.SeeKill(6503, { name = "Nouveau" })                         -- nouvelle espèce, capturée : gardée
	LOT.OfferShiny(6504, "Brillant")                                -- brillante : la toute dernière
	local chance = NS.CaptureChance
	NS.CaptureChance = function(self, info, aid, ...)
		if info and info.npcID == 6502 then return 0, false end
		return 0.95, false
	end
	LOT.Roll(0.5)
	local batch = NS:CaptureBatch()
	NS.CaptureChance = chance
	local order = {}
	for _, card in ipairs(batch.order) do order[#order + 1] = card.result.target.npcID end
	Check("[LOT] ordinaires d'abord, puis les gardées, de la plus modeste à la plus belle",
		table.concat(order, ",") == "6501,6502,6503,6500,6504", table.concat(order, ","))
	local lastWave, firstSpecial = 0, math.huge
	for _, card in ipairs(batch.order) do
		if card.special then firstSpecial = math.min(firstSpecial, card.flipAt) else lastWave = math.max(lastWave, card.flipAt) end
	end
	Check("[LOT] la vague tient en 1,5 s, les gardées après", lastWave <= NS.CAPTURE_BATCH_LEAD + NS.CAPTURE_BATCH_WAVE + 1e-6
		and firstSpecial > lastWave + NS.CAPTURE_BATCH_FLIP, lastWave .. " / " .. firstSpecial)
	-- pas à pas : une carte en train de tourner rétrécit, change de face à mi-course
	LOT.sounds = {}
	local first = batch.order[1]
	Run(first.flipAt + NS.CAPTURE_BATCH_FLIP * 0.3, 0.01)
	Check("[LOT] mi-retournement : la carte rétrécit, encore de dos", first.tile:GetWidth() < 96 and first.tile.facing == "back",
		first.tile:GetWidth())
	Run(NS.CAPTURE_BATCH_FLIP * 0.4, 0.01)
	Check("[LOT] passé la moitié : la face", first.tile.facing == "front" and not first.revealed)
	Run(NS.CAPTURE_BATCH_FLIP, 0.01)
	Check("[LOT] retournée : pleine largeur", first.revealed and first.tile:GetWidth() == 96)
	local seenSpecial = false
	for _, card in ipairs(batch.order) do if card.special and card.faced then seenSpecial = true end end
	Check("[LOT] les gardées attendent la fin de la vague", not seenSpecial)
	-- jusqu'à juste avant la première gardée
	Run(firstSpecial - 0.03 - (NS.Now() - batch.startedAt), 0.01)
	local waveDone = true
	for _, card in ipairs(batch.order) do if not card.special and not card.revealed then waveDone = false end end
	Check("[LOT] la vague finie, toujours aucune gardée retournée", waveDone and not batch.order[3].faced)
	Run(12, 0.01)
	Check("[LOT] tout est retourné, la brillante en dernier", batch.done and batch.order[5].revealed
		and batch.order[5].result.target.shiny)
	Check("[LOT] gardées : leur musique (fanfare pour la brillante)", Count(LOT.sounds, NS.CAPTURE_SOUNDS.shiny) == 1
		and Count(LOT.sounds, NS.CAPTURE_SOUNDS.ok) == 2, table.concat(LOT.sounds, ","))
	Check("[LOT] la brillante : halo doré", batch.order[5].tile.halo:IsShown())
	-- le bruit des cartes : pas plus d'un toutes les 0,06 s
	LOT.Reset()
	for npc = 6510, 6521 do
		NS:CaptureData().creatures[npc] = { name = "Connu " .. npc, class = "normal", normal = true, stars = 1, at = 1 }
		LOT.SeeKill(npc, { name = "Connu " .. npc })
	end
	LOT.Roll(0)
	LOT.sounds = {}
	local flipTimes = {}
	_G.PlaySound = function(id)
		LOT.sounds[#LOT.sounds + 1] = id
		if id == NS.CAPTURE_SOUNDS.flip then flipTimes[#flipTimes + 1] = NS.Now() end
		return true
	end
	batch = NS:CaptureBatch()
	Check("[LOT] douze cartes : grille de 4 × 3", #batch.cards == 12 and select(2, NS:CaptureBatchGrid(12)) == 3
		and NS.captureBatchFrame:GetWidth() >= 4 * 96)
	Run(4, 0.005)
	local flips = Count(LOT.sounds, NS.CAPTURE_SOUNDS.flip)
	local minGap = math.huge
	for index = 2, #flipTimes do minGap = math.min(minGap, flipTimes[index] - flipTimes[index - 1]) end
	Check("[LOT] bruit de carte : au plus un toutes les 0,06 s", flips >= 2 and flips <= 12
		and minGap >= NS.CAPTURE_BATCH_SOUND_GAP - 1e-6, flips .. " / " .. minGap)
	Check("[LOT] diagonale : la première carte avant la dernière, la rangée pèse plus que la colonne",
		batch.cards[1].flipAt < batch.cards[12].flipAt and batch.cards[2].flipAt < batch.cards[5].flipAt
		and math.abs(batch.cards[12].flipAt - (NS.CAPTURE_BATCH_LEAD + NS.CAPTURE_BATCH_WAVE)) < 1e-6)
	LOT.Install()
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
	Mock:Advance(0.1)
	frame.stop:Click()
	local all = true
	for _, card in ipairs(batch.cards) do if not (card.revealed and card.tile.facing == "front" and card.tile:GetWidth() == 96) then all = false end end
	Check("[LOT] Arrêter : toutes les cartes retournées d'un coup", all and batch.done and batch.revealed == 3)
	Check("[LOT] … compteur à jour, fanfare une fois, résultats déjà là", frame.counter:GetText() == NS:F("CAPTURE_BATCH_COUNT", 3)
		and Count(LOT.sounds, NS.CAPTURE_SOUNDS.shiny) == 1 and NS:CaptureData().creatures[6602].shiny == true)
	restore()
	Check("[LOT] … et le bilan dans le chat", printed[#printed] == NS:F("CAPTURE_BATCH_SUMMARY_SHINY", 3, 3, 1), printed[#printed])
	Check("[LOT] le bouton ferme ensuite", frame.stop:GetText() == NS.L.CAPTURE_BATCH_CLOSE)
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
		and batch.revealed == 2 and Count(LOT.sounds, NS.CAPTURE_SOUNDS.ok) == 0
		and printed[#printed] == NS:F("CAPTURE_BATCH_SUMMARY", 2, 2), printed[#printed])
	-- le × aussi
	LOT.SeeKill(6620, { name = "Chacal C" })
	LOT.SeeKill(6621, { name = "Chacal D" })
	batch = NS:CaptureBatch()
	frame.close:Click()
	frame:GetScript("OnHide")(frame)
	Check("[LOT] × : fermé, lot terminé", not frame:IsShown() and batch.done)
	-- capture animée coupée : tout se montre d'emblée
	NS:DB().companionCaptureAnim = false
	LOT.SeeKill(6630, { name = "Chacal E" })
	LOT.SeeKill(6631, { name = "Chacal F" })
	batch = NS:CaptureBatch()
	Check("[LOT] capture animée coupée : tout retourné d'emblée", batch.done and batch.revealed == 2 and frame:IsShown())
	NS:DB().companionCaptureAnim = true
	frame:Hide()
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

for _, name in ipairs(GLOBALS) do _G[name] = LOT.saved[name] end
math.random = LOT.random
NS.SHINY_CHANCE = LOT.savedShiny
NS:DB().captureMuteUntil = nil
NS.captureBatch = nil
ResetWorld()
