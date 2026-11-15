-- Compagnon : la capture (Capture.lua, CaptureQueue.lua, CaptureStage.lua).
-- Chance (rang, niveau, aides, malchance), la file du filet au coup fatal
-- (combat, 30 s, plafond, tri), le lancer (réussite, échec, recapture du
-- meilleur spécimen, dates figées), les aides (besace, tampons, paliers), les
-- apparences, le bouton filet (liste, compagnon masqué, placement, taille),
-- le bandeau « Capture possible » (infos, Ignorer, Sourdine), les sons, la
-- scène animée, la page Créatures, le coût des lectures, le cadrage du
-- compagnon, la migration 1.6.0 des fiches, textes et réglages.
-- (« Tout capturer » et le choix au clic : capture_lot.lua ; la carte de
-- préparation : capture_preparation.lua ; les spécimens : specimens.lua.)
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local C = { saved = {}, random = math.random, units = {}, sounds = {}, savedCreateFrame = _G.CreateFrame }
C.rollQuality = NS.CaptureRollQuality   -- 2.15.0 : rendue à la fin du module
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"InCombatLockdown", "UnitAffectingCombat", "PlaySound", "GameTooltip" }
for _, name in ipairs(GLOBALS) do C.saved[name] = rawget(_G, name) end
C.savedShiny = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"

function C.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function C.Install()
	local w = C
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
		if unit == "player" or unit == nil then return w.playerLevel or 20 end
		local u = w.units[unit]; return u and u.level or 20
	end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	-- les bulles différées partent tout de suite (et sont comptées)
	w.later = {}
	_G.C_Timer = { After = function(_, fn) w.later[#w.later + 1] = fn; fn() end }
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return w.combat == true end
	_G.PlaySound = function(id) w.sounds[#w.sounds + 1] = id; return true end
end
function C.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText = nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
-- 3.1.0 : le harnais tourne au thème forgé (le choix par défaut) ; ces
-- sous-cas épinglent le filet et le bandeau du thème Sobre, inchangés
function C.Sobre()
	NS:DB().companionStyle = "sobre"
	NS:ApplyUIStyle()
end
-- anim : la scène animée (sinon la petite fenêtre)
function C.Reset(anim)
	ResetWorld()
	-- 3.1.0 : le Voile d'hiver suit le thème forgé (choix par défaut) et
	-- l'horloge du harnais (1970-01-01) tombe en saison : décor coupé, la
	-- boule de neige remplacerait le filet (winter_veil.lua le teste)
	NS:DB().winterVeil = "off"
	-- 2.15.0 : qualité tirée au coup fatal figée à 1 étoile (sauf C.quality) :
	-- les chances attendues restent celles du rang
	C.quality = nil
	NS.CaptureRollQuality = function() return C.quality or 1 end
	if NS.captureBatchFrame then NS.captureBatchFrame:Hide() end
	if NS.captureChooser then NS.captureChooser:Hide() end
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt",
		"captureQueueList", "captureNetButton", "captureToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureToastHideAt, NS.captureAppCache, NS.captureBatch = nil, nil, nil
	-- annonces du carnet (« Au carnet : … ») retenues : elles ont leurs tests
	-- (companion_notify.lua) et recouvriraient la bulle de capture
	NS.notifyState = { at = math.huge, pending = 0 }
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	C.units, C.playerLevel, C.combat, C.sounds = {}, 20, false, {}
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	C.Install()
	NS.SHINY_CHANCE = 0
	math.random = C.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = anim == true
	-- 2.15.0 : le lancer d'un clic (réglage « Lancer directement au clic ») ; la carte
	-- de préparation a ses tests (capture_preparation.lua)
	NS:DB().companionCaptureDirect = true
	NS:DB().captureMuteUntil = nil
	NS:DB().companionCaptureSound = true
	NS:DB().companionCaptureToast = true
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CompanionUpdateVisibility()
	C.Quiet()
end
function C.See(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or C.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	C.units.target = fields
	return NS:BestiarySeeUnit("target"), fields.guid
end
function C.SeeKill(npcID, fields)
	local _, guid = C.See(npcID, fields)
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	return guid
end
function C.Roll(value)
	math.random = function(a, b)
		if a and b then return C.random(a, b) end
		if a then return C.random(a) end
		return value
	end
end
-- fait tourner l'horloge jusqu'au verdict (secousses, puis fermeture)
function C.Settle()
	for _ = 1, 12 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
end
function C.Net() return NS.companionFrame and NS.companionFrame.captureNet end
function C.Tooltip(frame)
	local lines = {}
	_G.GameTooltip = { SetOwner = function() end, AddLine = function(_, text) lines[#lines + 1] = text end, Show = function() end,
		Hide = function() end, AddDoubleLine = function(_, text) lines[#lines + 1] = text end }
	frame:GetScript("OnEnter")(frame)
	_G.GameTooltip = C.saved.GameTooltip
	return table.concat(lines, "\n")
end
local function Has(list, id) for _, v in ipairs(list) do if v == id then return true end end return false end
local function Count(list, id) local n = 0; for _, v in ipairs(list) do if v == id then n = n + 1 end end return n end
local function Find(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end

-- 1. Chance --------------------------------------------------------------------------------------
do
	Say("-- capture : chance")
	C.Reset()
	local function Pct(info, aid, level) return math.floor(NS:CaptureChance(info, aid, level) * 100 + 0.5 + 1e-9) end
	Check("[CAP] normal 50 % (rang inconnu aussi), élite 25 %, rare 15 %, rare élite 10 %, boss 4 %",
		Pct({ class = "normal", level = 20 }, nil, 20) == 50 and Pct({ class = "??", level = 20 }, nil, 20) == 50
		and Pct({ class = "elite", level = 20 }, nil, 20) == 25 and Pct({ class = "rare", level = 20 }, nil, 20) == 15
		and Pct({ class = "rareelite", level = 20 }, nil, 20) == 10 and Pct({ class = "worldboss", level = 20 }, nil, 20) == 4)
	Check("[CAP] niveau : 5 au-dessus ×0,8, très au-dessus plancher ×0,5, en dessous +3 % par niveau (plafond ×1,5)",
		Pct({ class = "normal", level = 25 }, nil, 20) == 40 and Pct({ class = "normal", level = 60 }, nil, 20) == 25
		and Pct({ class = "normal", level = 15 }, nil, 20) == 58 and Pct({ class = "normal", level = 1 }, nil, 60) == 75)
	Check("[CAP] appât ×1,5, lasso ×2,5 (plafonné)", Pct({ class = "normal", level = 20 }, "appat", 20) == 75
		and Pct({ class = "elite", level = 20 }, "lasso", 20) == 63)
	Check("[CAP] plafond 95 % sans sifflet", Pct({ class = "normal", level = 1 }, "lasso", 60) == 95)
	local chance, sure = NS:CaptureChance({ class = "worldboss", level = 63 }, "sifflet", 20)
	Check("[CAP] sifflet : assurée, même un boss", chance == 1 and sure == true)
	-- malchance : +5 points par échec d'affilée, jusqu'à +25, remis à zéro par une prise
	local data = NS:CaptureData()
	data.missStreak = 0
	math.random = function(a) if a then return a end return 0.99 end
	local r1 = NS:CaptureRoll({ class = "normal", level = 20 })
	local r2 = NS:CaptureRoll({ class = "normal", level = 20 })
	Check("[CAP] malchance : un échec rend le suivant plus sûr (+5)", r1.success == false and data.missStreak == 2
		and math.floor(r2.chance * 100 + 0.5) == math.floor(r1.chance * 100 + 0.5) + 5)
	data.missStreak = 9
	local r3 = NS:CaptureRoll({ class = "normal", level = 20 })
	Check("[CAP] malchance plafonnée à +25", math.floor(r3.chance * 100 + 0.5) <= math.floor(r1.chance * 100 + 0.5) + 25)
	math.random = function(a) if a then return a end return 0 end
	NS:CaptureRoll({ class = "normal", level = 20 })
	Check("[CAP] une prise remet la malchance à zéro", data.missStreak == 0)
	math.random = C.random
	data.missStreak = 0
end

-- 2. Le coup fatal : la file du filet (2.0 : plus de fenêtre automatique) ------------------------------
do
	Say("-- capture : la file au coup fatal")
	C.Reset()
	Check("[CAP] file vide : pas de filet", not (C.Net() and C.Net():IsShown()))
	C.SeeKill(3100, { name = "Loup des plaines", level = 19 })
	local queue = NS:CaptureQueue()
	Check("[CAP] abattu : candidat au filet (contrat : guid, npcID, name, class, type, reason), compteur, pas de fenêtre",
		queue[1] and queue[1].guid and queue[1].npcID == 3100 and queue[1].name == "Loup des plaines"
		and queue[1].class == "normal" and queue[1].type == "Bête" and queue[1].reason == "new" and not queue[1].shiny
		and C.Net():IsShown() and C.Net().count:GetText() == "1" and not (NS.capturePrompt and NS.capturePrompt:IsShown()))
	Check("[CAP] … le compagnon pousse à tenter", NS.companionBubbleKey == "CAPTURE_PROMPT"
		and Find(NS.companionBubbleText, "Loup des plaines"), NS.companionBubbleText)
	Check("[CAP] … chance affichée (normal, 1 niveau dessous : 52 %)", Find(NS:CaptureQueueLine(queue[1]), "52"),
		NS:CaptureQueueLine(queue[1]))
	Check("[CAP] le même monstre une seule fois", NS:CaptureOffer(C.Guid(3100), { zoneID = 1413, npcID = 3100 }) == nil
		and #NS:CaptureQueue() == 1)
	Mock:Advance(NS.CAPTURE_QUEUE_TIME + 1)
	NS:CaptureTick(NS.Now())
	Check("[CAP] temps écoulé : sorti de la file, filet caché, plus d'essai", #NS:CaptureQueue() == 0
		and not C.Net():IsShown() and NS:CaptureThrow() == false)
	-- un pack en combat : le compte attend la fin du combat, 30 s chacun ensuite
	C.Reset()
	C.combat = true
	C.SeeKill(4100, { name = "Loup A" })
	C.SeeKill(4101, { name = "Loup B", class = "elite" })
	C.SeeKill(4102, { name = "Loup C" })
	Check("[CAP] un pack en combat : trois candidats, le compte n'a pas commencé", #NS:CaptureQueue() == 3
		and NS:CaptureQueue()[1].expires == nil and C.Net().count:GetText() == "3")
	Mock:Advance(60); NS:CaptureTick(NS.Now())
	local long = #NS:CaptureQueue() == 3
	C.combat = false
	NS:CaptureTick(NS.Now())
	local started = NS:CaptureQueue()[1].expires
	Check("[CAP] combat long : personne ne sort ; fin du combat : 30 s chacun à partir de là", long and started
		and math.abs(started - (NS.Now() + 30)) < 0.01)
	Mock:Advance(20); NS:CaptureTick(NS.Now())
	local at20 = #NS:CaptureQueue()
	Mock:Advance(11); NS:CaptureTick(NS.Now())
	Check("[CAP] 20 s plus tard toujours là, 31 s : sortis, filet caché", at20 == 3 and #NS:CaptureQueue() == 0
		and not C.Net():IsShown())
	C.SeeKill(4103)
	Check("[CAP] hors combat : compte immédiat", NS:CaptureQueue()[1].expires ~= nil)
	NS:CaptureQueueClear()
	for npc = 4200, 4200 + NS.CAPTURE_QUEUE_MAX + 3 do C.SeeKill(npc) end
	local capped = #NS:CaptureQueue() == NS.CAPTURE_QUEUE_MAX
	NS:CaptureQueueClear()
	Check("[CAP] plafond de la file ; tout ignorer : file vide, filet caché", capped and #NS:CaptureQueue() == 0
		and not C.Net():IsShown())
	-- réglage coupé, compagnon coupé : rien
	NS:DB().companionCapture = false
	C.SeeKill(3101)
	local off = #NS:CaptureQueue() == 0 and not C.Net():IsShown()
	NS:DB().companionCapture = true
	C.Reset()
	NS:DB().companionEnabled = false
	C.SeeKill(3102)
	Check("[CAP] réglage coupé ou compagnon coupé : rien proposé", off and (NS.captureState == nil or #NS:CaptureQueue() == 0))
	NS:DB().companionEnabled = true
end

-- 3. Ce qui vaut le coup, et dans quel ordre --------------------------------------------------------
do
	Say("-- capture : tri de la file")
	C.Reset()
	C.Sobre()
	local creatures = NS:CaptureData().creatures
	creatures[4300] = { name = "Trois", class = "normal", normal = true, at = 1, stars = 3 }
	creatures[4301] = { name = "Une", class = "normal", normal = true, at = 1, stars = 1 }
	creatures[4302] = { name = "Deux", class = "normal", normal = true, at = 1, stars = 2 }
	C.SeeKill(4300, { name = "Trois" })
	Check("[CAP] déjà à 3 étoiles : pas dans la file", #NS:CaptureQueue() == 0)
	C.quality = 3   -- 2.15.0 : des spécimens à 3 étoiles, meilleurs que les tiens
	C.SeeKill(4302, { name = "Deux" })
	C.SeeKill(4301, { name = "Une" })
	C.SeeKill(4303, { name = "Nouveau" })
	C.SeeKill(4304, { name = "Rare nouveau", class = "rare" })
	NS.SHINY_CHANCE = 1
	C.Roll(0)
	C.SeeKill(4300, { name = "Trois", spawn = "5A1A1" })
	NS.SHINY_CHANCE = 0
	math.random = C.random
	local order = {}
	for _, c in ipairs(NS:CaptureQueue()) do order[#order + 1] = c.npcID end
	Check("[CAP] brillante > nouvelle (plus rare d'abord) > étoiles (moins d'étoiles d'abord)",
		table.concat(order, ",") == "4300,4304,4303,4301,4302", table.concat(order, ","))
	local best = NS:CaptureQueueBest()
	C.Net():GetScript("OnUpdate")(C.Net())
	Check("[CAP] brillante : raison « shiny », filet doré qui scintille", best.shiny and best.reason == "shiny"
		and C.Net().shiny == true and (C.Net().glow.alpha or 0) > 0)
	local stars = NS:CaptureQueue()[4]
	Check("[CAP] amélioration : raison « stars », étoiles actuelles", stars.reason == "stars" and stars.have == 1
		and Find(NS:CaptureQueueLine(stars), "|A:auctionhouse-icon-favorite"))
end

-- 4. Lancer : réussite, échec ----------------------------------------------------------------------
do
	Say("-- capture : lancer")
	C.Reset()
	C.SeeKill(3200, { name = "Kodo", level = 20 })
	C.Roll(0.1)
	Check("[CAP] clic : filet lancé, un seul à la fois, les secousses dans la petite fenêtre", NS:CaptureThrow() == true
		and NS:CaptureState().rolling ~= nil and NS:CaptureThrow() == false
		and NS.capturePrompt.status:IsShown() and not NS.capturePrompt.throw:IsShown())
	Mock:Reset()
	C.Settle()
	local data = NS:CaptureData()
	local kodo = data.creatures[3200]
	Check("[CAP] réussite : dans la collection (zone), essai compté, fenêtre refermée", kodo and kodo.name == "Kodo"
		and kodo.zoneID == 1413 and data.count == 1 and data.tries == 1 and not NS.capturePrompt:IsShown()
		and NS:CaptureState().rolling == nil)
	Check("[CAP] … annoncée dans le chat, le compagnon s'en réjouit", Find(Mock:Output(), "Kodo capturé")
		and NS.companionBubbleKey == "CAPTURE_OK", Mock:Output())
	C.Quiet()
	C.SeeKill(3201, { name = "Hyène", level = 20 })
	C.Roll(0.99)
	NS:CaptureThrow()
	Mock:Reset()
	C.Settle()
	Check("[CAP] échec : pas dans la collection, essai compté", data.creatures[3201] == nil and data.count == 1 and data.tries == 2)
	Check("[CAP] … le compagnon se moque, le chat le dit", NS.companionBubbleKey == "CAPTURE_FAIL"
		and Find(NS.companionBubbleText, "Hyène") and Find(Mock:Output(), "Hyène s'est échappé"), Mock:Output())
	C.Quiet()
	C.SeeKill(3201, { name = "Hyène", spawn = "00003C" })
	Check("[CAP] espèce ratée : se repropose au prochain", NS:CaptureQueue()[1] and NS:CaptureQueue()[1].npcID == 3201)
end

-- 5. Étoiles : anciennes fiches, recapture du meilleur spécimen, dates -----------------------------------
do
	Say("-- capture : étoiles et recapture")
	C.Reset()
	NS:DB().capture, NS.captureMergedChar = nil, nil; NS:CompanionData().capture = { creatures = {
		[11] = { name = "Ancien", at = 100, normal = true },
		[12] = { name = "Ancien brillant", at = 200, normal = false, shiny = true, shinyAt = 200 },
	}, count = 2 }
	local data = NS:CaptureData()
	Check("[CAP] anciennes fiches : 1 étoile (version possédée seulement)", data.creatures[11].stars == 1
		and data.creatures[12].shinyStars == 1 and data.creatures[12].stars == nil)
	local read = NS:CaptureStars(11, false) == 1 and NS:CaptureStars(11, true) == nil and NS:CaptureStars(12, true) == 1
		and NS:CaptureStars(12, false) == nil and NS:CaptureStars(999, false) == nil
	data.creatures[11].stars = 7
	Check("[CAP] CaptureStars : version capturée -> 1..3 (borné), sinon nil", read and NS:CaptureStars(11) == 3)
	-- 2.12.1 : balises d'atlas du client, l'étoile pleine puis la variante « -off »
	Check("[CAP] texte des étoiles : atlas du client (pleine, vide « -off »), rien sans étoiles",
		NS:CaptureStarsText(2, 12) == "|A:auctionhouse-icon-favorite:12:12|a|A:auctionhouse-icon-favorite:12:12|a"
			.. "|A:auctionhouse-icon-favorite-off:12:12|a" and NS:CaptureStarsText(nil) == "", NS:CaptureStarsText(2, 12))
	-- recapture
	C.Reset()
	local creatures = NS:CaptureData().creatures
	C.SeeKill(4500, { name = "Cerf", spawn = "A1" })
	C.Roll(0)
	NS:CaptureThrow()
	C.Settle()
	local entry = creatures[4500]
	local first = entry.at
	Check("[CAP] première capture : 1 étoile, date de première capture gardée (espèce et collection)", entry.stars == 1
		and NS:CaptureData().count == 1 and entry.firstAt == first and NS:CaptureData().firstAt == first)
	C.quality = 2   -- 2.15.0 : un spécimen meilleur que le tien
	C.SeeKill(4500, { name = "Cerf", spawn = "A1b" })
	Check("[CAP] espèce déjà capturée (1 étoile) : proposée pour un meilleur spécimen",
		NS:CaptureQueueBest() and NS:CaptureQueueBest().reason == "stars")
	NS:CaptureQueueClear()
	-- une meilleure (sifflet : capture assurée)
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	C.quality = 3
	C.SeeKill(4500, { name = "Cerf", spawn = "A2" })
	C.Roll(0.97)
	Mock:Reset()
	Mock:Advance(5)
	NS:CaptureThrow()
	C.Settle()
	Check("[CAP] 3 étoiles : gardées, une seule espèce, at bouge, la première date non", entry.stars == 3
		and NS:CaptureData().count == 1 and entry.at ~= first and entry.firstAt == first
		and NS:CaptureData().firstAt == first and NS:CaptureEarliestAt() == first)
	Check("[CAP] … « meilleur spécimen » dans le chat", Find(Mock:Output(), "meilleur spécimen"), Mock:Output())
	C.SeeKill(4500, { name = "Cerf", spawn = "A3" })
	Check("[CAP] à 3 étoiles : plus proposée", #NS:CaptureQueue() == 0)
	-- une moins bonne (proposée en mode chasse, 2.15.0) : la meilleure reste, avec sa date
	local kept = entry.at
	C.quality = 1
	NS:HuntStart(nil)
	C.SeeKill(4500, { name = "Cerf", spawn = "A4" })
	C.Roll(0)
	Mock:Reset()
	Mock:Advance(5)
	NS:CaptureThrow()
	C.Settle()
	NS:HuntStop()
	Check("[CAP] moins bonne : la meilleure reste, sa date aussi ; dit dans le chat (rangée en Réserve)", entry.stars == 3
		and entry.at == kept and Find(Mock:Output(), "3 étoiles reste"), Mock:Output())
	-- version brillante : ses propres étoiles
	NS.SHINY_CHANCE = 1
	C.Roll(0.7)
	C.quality = 2
	C.SeeKill(4500, { name = "Cerf", spawn = "A5" })
	NS.SHINY_CHANCE = 0
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	NS:CaptureThrow()
	C.Settle()
	Check("[CAP] brillante : ses étoiles à part", entry.shiny and entry.shinyStars == 2 and entry.stars == 3
		and NS:CaptureStars(4500, true) == 2)
end

-- 6. Aides --------------------------------------------------------------------------------------
do
	Say("-- capture : aides")
	C.Reset()
	local items = NS:CaptureData().items
	Check("[CAP] besace vide au départ, gagner un appât", items.appat == 0 and items.lasso == 0 and items.sifflet == 0
		and NS:CaptureGrant("appat", { quiet = true }) == "ok" and items.appat == 1)
	for _ = 1, 12 do NS:CaptureGrant("appat", { quiet = true, silent = true }) end
	Check("[CAP] plafond : 10 appâts", items.appat == 10 and NS:CaptureGrant("appat", { quiet = true }) == "full")
	C.SeeKill(3300, { name = "Raptor", class = "elite", level = 20 })
	Check("[CAP] choisir l'appât : la chance suit (38 %)", NS:CaptureToggleAid("appat") == "appat"
		and Find(NS:CaptureQueueLine(NS:CaptureQueueBest()), "38"), NS:CaptureQueueLine(NS:CaptureQueueBest()))
	Check("[CAP] sans sifflet en poche : pas choisissable ; reclic : reposé", NS:CaptureToggleAid("sifflet") == "appat"
		and NS:CaptureToggleAid("appat") == nil)
	NS:CaptureToggleAid("appat")
	C.Roll(0.99)
	NS:CaptureThrow()
	Check("[CAP] l'aide est dépensée au lancer", items.appat == 9)
	C.Settle()
	NS:CaptureGrant("sifflet", { quiet = true })
	C.SeeKill(3301, { name = "Seigneur", class = "worldboss", level = 63 })
	NS:CaptureToggleAid("sifflet")
	local line = NS:CaptureQueueLine(NS:CaptureQueueBest())
	C.Roll(0.999)
	NS:CaptureThrow()
	C.Settle()
	Check("[CAP] sifflet : « assurée » affiché, boss capturé à coup sûr", Find(line, NS.L.CAPTURE_SURE:gsub("%%s · ", ""))
		and NS:CaptureData().creatures[3301] ~= nil and items.sifflet == 0, line)
	-- l'aide gardée d'une fois sur l'autre… tant qu'il en reste
	C.SeeKill(3302)
	Check("[CAP] sifflet épuisé : plus choisi", NS:CaptureState().aid == nil)
end

-- 7. D'où viennent les aides -------------------------------------------------------------------
do
	Say("-- capture : tampons et paliers")
	C.Reset()
	local items = NS:CaptureData().items
	C.Roll(0)
	Mock:Reset()
	NS:CaptureOnStamp({ kind = "rare", name = "Rare", new = true })
	Check("[CAP] tampon de rare : un lasso, sans chat par défaut, une bulle après celle du tampon", items.lasso == 1
		and Mock:Output() == "" and #C.later == 1, Mock:Output())
	NS:CaptureOnStamp({ kind = "dungeon", name = "Donjon", new = true })
	NS:CaptureOnStamp({ kind = "subzone", name = "Village", new = true })
	Check("[CAP] tampon de donjon : lasso, et la chance d'un sifflet ; de lieu : un appât (1 sur 4)", items.lasso == 2
		and items.sifflet == 1 and items.appat == 1)
	C.Roll(0.9)
	NS:CaptureOnStamp({ kind = "subzone", name = "Village 2", new = true })
	NS:CaptureOnStamp({ kind = "rare", name = "Rare", new = false })
	Check("[CAP] tirage raté, tampon déjà connu : rien", items.appat == 1 and items.lasso == 2)
	NS:DB().journalChat = true
	C.Roll(0)
	Mock:Reset()
	NS:CaptureOnStamp({ kind = "rare", name = "Rare 2", new = true })
	Check("[CAP] chat du carnet allumé : l'aide y est dite", Find(Mock:Output(), "Lasso tressé"), Mock:Output())
	NS:DB().journalChat = false
	-- tirage pondéré : 60 / 33 / 7
	C.Roll(0); local a = NS.CaptureDraw()
	C.Roll(0.7); local b = NS.CaptureDraw()
	C.Roll(0.97); local c = NS.CaptureDraw()
	Check("[CAP] tirage pondéré 60 / 33 / 7 : appât, lasso, sifflet ; paliers de zone : 25 appât, 50 lasso, 75 tirage",
		a == "appat" and b == "lasso" and c == "sifflet" and NS.CAPTURE_MILESTONE_DROPS[25] == "appat"
		and NS.CAPTURE_MILESTONE_DROPS[50] == "lasso" and NS.CAPTURE_MILESTONE_DROPS[75] == "draw")
	-- brillante abattue : un lasso en prime
	C.Reset()
	NS.SHINY_CHANCE = 1
	C.Roll(0)
	local guid = C.SeeKill(3400, { name = "Loup brillant" })
	Check("[CAP] brillante abattue : un lasso et la capture proposée", NS:CaptureData().items.lasso == 1
		and NS:CaptureQueueBest() and NS:CaptureQueueBest().shiny == true, tostring(guid))
	NS:CaptureThrow()
	C.Settle()
	Check("[CAP] brillante capturée : marquée", NS:CaptureData().creatures[3400].shiny == true)
	NS.SHINY_CHANCE = 0
end

-- 8. Les capturés deviennent des apparences ------------------------------------------------------
do
	Say("-- capture : apparences")
	C.Reset()
	local before = #NS:CompanionUnlockedAppearances()
	C.Roll(0)
	C.SeeKill(3500, { name = "Ourson" })
	NS:CaptureThrow()
	C.Settle()
	local list = NS:CompanionUnlockedAppearances()
	local found
	for _, choice in ipairs(NS:CompanionChoices("app")) do if choice.value == "cap:3500" then found = choice end end
	Check("[CAP] une apparence de plus, dans la liste des réglages sous son nom", #list == before + 1
		and list[#list].id == "cap:3500" and list[#list].npc == 3500 and found and found.label == "Ourson" and not found.disabled)
	-- le simulacre n'a pas de PlayerModel : un cadre qui sait SetCreature
	local model = CreateFrame("Frame", nil, NS.companionFrame)
	model.SetCreature = function(self, id) self.creature = id end
	NS.companionFrame.model = model
	local chosen = NS:CompanionSetAppearance("cap:3500") ~= nil and NS:CompanionCurrentAppearance().id == "cap:3500"
	NS:CompanionApplyModel()
	Check("[CAP] la choisir : le modèle de la créature (SetCreature)", chosen and model.creature == 3500, tostring(model.creature))
	local coll
	for _, entry in ipairs(NS:JournalCollection("app")) do if entry.def.id == "cap:3500" then coll = entry end end
	local men
	for _, entry in ipairs(NS:MenagerieList({ zone = "all", state = "captured" })) do if entry.npc == 3500 then men = entry end end
	Check("[CAP] pas dans la Collection : dans la page Créatures, capturée", coll == nil and men ~= nil and men.captured and men.known)
	-- dix captures : un sifflet offert
	local data = NS:CaptureData()
	for npc = 3501, 3509 do
		C.SeeKill(npc)
		NS:CaptureThrow()
		C.Settle()
	end
	Check("[CAP] 10 captures : un sifflet offert", data.count == 10 and data.items.sifflet == 1)
end

-- 9. Le bouton filet : clic, liste du clic droit, infobulle ---------------------------------------------
do
	Say("-- capture : bouton et liste")
	C.Reset()
	C.SeeKill(4400, { name = "Ours" })
	C.SeeKill(4401, { name = "Ours élite", class = "elite" })
	C.SeeKill(4402, { name = "Sanglier" })
	C.Roll(0)
	local hooked
	local resolve = NS.CaptureResolve
	NS.CaptureResolve = function(self, rolling) hooked = rolling.target; return resolve(self, rolling) end
	-- trois candidats : le clic propose le choix (2.5.0, capture_lot.lua) ; « Capturer : … » = le meilleur
	C.Net():Click("LeftButton")
	NS.captureChooser.single:Click()
	Check("[CAP] « Capturer : … » : le filet part sur le meilleur (élite), sorti de la file, compteur 2",
		NS:CaptureState().rolling and NS:CaptureState().rolling.target.npcID == 4401
		and #NS:CaptureQueue() == 2 and C.Net().count:GetText() == "2")
	Check("[CAP] un filet à la fois", C.Net():Click("LeftButton") == nil and #NS:CaptureQueue() == 2)
	C.Settle()
	NS.CaptureResolve = resolve
	Check("[CAP] capturé ; CaptureResolve garde rolling.target (npcID, class, type, shiny), avec ses étoiles",
		hooked and hooked.npcID == 4401 and hooked.class == "elite" and hooked.type == "Bête" and hooked.shiny == nil
		and NS:CaptureHas(4401) and NS:CaptureStars(4401) == 1)
	-- clic droit : la liste
	C.Net():Click("RightButton")
	local list = NS.captureQueueList
	Check("[CAP] clic droit : la liste, une ligne par candidat (nom, raison courte, temps)", list and list:IsShown()
		and list.rows[2]:IsShown() and not list.rows[3]:IsShown() and Find(list.rows[1].text:GetText(), "Ours")
		and Find(list.rows[1].detail:GetText(), NS.L.CAPTURE_Q_TAG_new) and list.rows[1].detail:GetText():find("%d+ s") ~= nil,
		list.rows[1].detail:GetText())
	NS:CaptureGrant("lasso", { quiet = true, silent = true })
	list.aids[2]:Click()
	Check("[CAP] … choisir une aide dans la liste", NS:CaptureState().aid == "lasso"
		and Find(list.rows[1].detail:GetText(), "95"), list.rows[1].detail:GetText())
	local pick = list.rows[2].candidate
	list.rows[2]:Click()
	Check("[CAP] clic sur une ligne : ce candidat-là, avec l'aide ; la liste se referme", NS:CaptureState().rolling
		and NS:CaptureState().rolling.target.npcID == pick.npcID and NS:CaptureState().rolling.aid == "lasso"
		and NS:CaptureData().items.lasso == 0 and not list:IsShown())
	C.Settle()
	C.Net():Click("RightButton")
	local opened = list:IsShown()
	C.Net():Click("RightButton")
	Check("[CAP] clic droit : ouvre, reclic : referme", opened and not list:IsShown())
	C.Net():Click("RightButton")
	list.ignore:Click()
	Check("[CAP] « Tout ignorer » : vide, liste et filet cachés", #NS:CaptureQueue() == 0 and not list:IsShown()
		and not C.Net():IsShown())
	C.SeeKill(4403, { name = "Hibou" })
	local all = C.Tooltip(C.Net())
	Check("[CAP] infobulle : le meilleur, clic, clic droit", Find(all, "Hibou") and Find(all, NS.L.CAPTURE_Q_RIGHT), all)
end

-- 10. Le filet : compagnon masqué, à côté du compagnon, à sa taille ; /qc filet --------------------------
do
	Say("-- capture : le filet à l'écran")
	C.Reset()
	C.Sobre()
	NS:DB().companionSize = 2
	NS:CompanionApplySize()
	C.SeeKill(4300, { name = "Loup seul" })
	local net = NS.captureNetButton
	Check("[CAP] filet : à côté du compagnon (à sa droite), pas sur son portrait, visible au repos", net and net:IsShown()
		and not net.alone and net.side == "right" and net.lastPoint.relTo == NS.companionFrame
		and net.lastPoint.point == "LEFT" and net.lastPoint.relPoint == "RIGHT" and net.icon.alpha == 1)
	Check("[CAP] filet lisible sur sol clair (2.3.1) : plaque sombre, ombre, liseré, compteur en pastille",
		net.plate and net.shadow and net.ring and net.border and net.countBack and net.count:GetText() == "1")
	net.scripts.OnUpdate(net)
	Check("[CAP] filet : il bat quelques secondes à l'arrivée (halo allumé)", net.pulseUntil and net.pulseUntil > NS.Now()
		and (net.glow.alpha or 0) > 0)
	NS.companionFrame:Hide()
	NS:CapturePlaceNet()
	local alone = net:IsShown() and net.alone == true and net.lastPoint and net.lastPoint.relTo == UIParent
	NS.companionFrame:Show()
	NS:CapturePlaceNet()
	Check("[CAP] compagnon masqué : le filet reste, seul à l'écran ; de retour : le filet revient sur lui", alone
		and net.alone == false and net.lastPoint.relTo == NS.companionFrame)
	NS:DB().companionSize = 4
	NS:CompanionApplySize()
	local big = net:GetScale()
	NS:DB().companionSize = 2
	NS:CompanionApplySize()
	Check("[CAP] filet : à la taille du compagnon (Très grand ×1,6, puis ×1)", big == NS.COMPANION_SIZES[4] and net:GetScale() == 1, big)
	NS.companionFrame.GetRight = function() return (UIParent:GetWidth() or 1024) - 10 end
	NS:CapturePlaceNet()
	local left = net.side == "left" and net.lastPoint.point == "RIGHT" and net.lastPoint.relPoint == "LEFT"
	NS.companionFrame.GetRight = nil
	NS:CapturePlaceNet()
	Check("[CAP] compagnon au bord droit : le filet passe à sa gauche, sinon à droite", left and net.side == "right")
	C.Roll(0)
	NS.EXTRA_COMMANDS["filet"](NS)
	Check("[CAP] /qc filet : lance la capture du meilleur candidat", NS:CaptureState().rolling ~= nil)
	C.Settle()
	NS:CaptureQueueClear()
	local printed = {}
	local oldPrint = NS.Print
	NS.Print = function(_, msg) printed[#printed + 1] = msg end
	NS.EXTRA_COMMANDS["filet"](NS)
	NS.Print = oldPrint
	Check("[CAP] /qc filet sans rien : le dit", printed[1] == NS.L.CAPTURE_Q_NOTHING, printed[1])
end

-- 11. Le bandeau « Capture possible » : infos, temps, combat, clics -----------------------------------
do
	Say("-- capture : bandeau")
	C.Reset()
	C.Sobre()
	C.SeeKill(4400, { name = "Raptor" })
	local toast, net = NS.captureToast, NS.captureNetButton
	Check("[CAP] bandeau montré : titre, nom, aide ; « Jamais capturée · 50 % de chance » en doré", toast and toast:IsShown()
		and toast.title:GetText() == NS.Theme.Upper(NS.L.CAPTURE_TOAST_TITLE) and toast.text:GetText() == "Raptor"
		and toast.hint:GetText() == NS.L.CAPTURE_TOAST_HINT
		and toast.info:GetText() == NS.L.CAPTURE_TOAST_NEW .. " · " .. NS:F("CAPTURE_TOAST_CHANCE", 50)
		and toast.info.textColor[1] == NS.Theme.GOLD[1], toast and toast.info:GetText())
	local hideAt = NS.captureToastHideAt
	C.SeeKill(4401, { name = "Raptor B" })
	Check("[CAP] un deuxième : « et 1 de plus », sans prolonger le bandeau (mêlée, 2.9.0)",
		Find(toast.hint:GetText(), "et 1 de plus") and hideAt ~= nil and NS.captureToastHideAt == hideAt, toast.hint:GetText())
	Mock:Advance(NS.CAPTURE_TOAST_SECONDS + 1); NS:CaptureTick(NS.Now())
	net.scripts.OnUpdate(net)
	Check("[CAP] bandeau : s'efface seul au bout de " .. NS.CAPTURE_TOAST_SECONDS .. " s, le battement du filet aussi",
		not toast:IsShown() and NS.captureToastHideAt == nil and net.pulseUntil == nil and net.glow.alpha == 0)
	-- en combat : le bandeau attend la fin du combat
	NS:CaptureQueueClear()
	C.combat = true
	C.SeeKill(4402, { name = "Raptor C" })
	local during = toast:IsShown()
	C.combat = false
	NS:CaptureTick(NS.Now())
	Check("[CAP] en combat : pas de bandeau ; à la fin du combat, le bandeau", not during and toast:IsShown()
		and toast.text:GetText() == "Raptor C")
	C.Roll(0)
	toast.button:Click("LeftButton")
	local thrown = NS:CaptureState().rolling ~= nil and not toast:IsShown()
	C.Settle()
	C.SeeKill(4403, { name = "Raptor D" })
	toast.button:Click("RightButton")
	Check("[CAP] clic sur le bandeau : capture lancée ; clic droit : la liste ; le bandeau s'efface", thrown
		and NS.captureQueueList and NS.captureQueueList:IsShown() and not toast:IsShown())
	NS:CaptureHideQueueList()
	NS:CaptureQueueClear()
	NS.SHINY_CHANCE = 1
	C.Roll(0)
	C.SeeKill(4404, { name = "Raptor doré" })
	NS.SHINY_CHANCE = 0
	Check("[CAP] brillante : le bandeau le dit", toast:IsShown() and Find(toast.text:GetText(), "Raptor doré")
		and toast.text:GetText() ~= "Raptor doré", toast.text:GetText())
	NS:CaptureQueueClear()
	NS:DB().companionCaptureToast = false
	C.SeeKill(4405, { name = "Raptor E" })
	local kept = not toast:IsShown() and net:IsShown()
	NS:DB().companionCaptureToast = true
	NS:CaptureQueueClear()
	Check("[CAP] réglage coupé : pas de bandeau, le filet reste ; file vidée : bandeau et filet effacés", kept
		and not toast:IsShown() and not net:IsShown())
	-- déjà capturée, 2 étoiles : le bandeau le dit, et « peut faire mieux » ; la brillante possédée
	C.Reset()
	C.SeeKill(5100, { name = "Raptor" })
	toast = NS.captureToast
	C.Roll(0)
	NS:CaptureThrow()
	C.Settle()
	NS:CaptureData().creatures[5100].stars = 2
	NS:CaptureData().serial = (NS:CaptureData().serial or 0) + 1
	C.quality = 3
	C.SeeKill(5100, { name = "Raptor", spawn = "0000000002" })
	Check("[CAP] déjà capturée : ses étoiles et « peut faire mieux »", toast:IsShown()
		and Find(toast.info:GetText(), NS.L.CAPTURE_TOAST_BETTER) and Find(toast.info:GetText(), "Déjà capturée")
		and Find(toast.info:GetText(), NS:CaptureStarsText(2, 10)), toast.info:GetText())
	NS:CaptureData().creatures[5100].shiny, NS:CaptureData().creatures[5100].shinyStars = true, 1
	NS:CaptureToastShow()
	Check("[CAP] … et la brillante possédée", Find(toast.info:GetText(), "brillante"), toast.info:GetText())
end

-- 12. Bandeau : Ignorer, Sourdine --------------------------------------------------------------------
do
	Say("-- capture : ignorer et sourdine")
	C.Reset()
	C.SeeKill(5200, { name = "Loup A" })
	C.SeeKill(5201, { name = "Loup B" })
	local toast = NS.captureToast
	toast.ignore:Click()
	Check("[CAP] Ignorer : le premier sort du filet, le bandeau passe au suivant", #NS:CaptureQueue() == 1
		and toast:IsShown() and toast.text:GetText() == "Loup B", toast.text:GetText())
	toast.ignore:Click()
	Check("[CAP] Ignorer le dernier : filet vide, bandeau effacé", #NS:CaptureQueue() == 0 and not toast:IsShown()
		and not NS.captureNetButton:IsShown())
	C.SeeKill(5300, { name = "Kodo" })
	toast.mute:Click()
	local total = toast.muteRow.cancel:GetWidth() + 8
	for _, c in ipairs(toast.muteRow.choices) do total = total + c:GetWidth() + 4 end
	Check("[CAP] Sourdine : 5, 15, 30 min, 1 h et Annuler, la rangée tient dans le bandeau (2.3.1)", toast.muteRow:IsShown()
		and #toast.muteRow.choices == 4 and toast.muteRow.choices[4].minutes == 60
		and toast.muteRow.choices[4].text:GetText() == NS.L.CAPTURE_TOAST_MUTE_HOUR and total <= toast:GetWidth() - 12, total)
	toast.muteRow.cancel:Click()
	Check("[CAP] … Annuler : la rangée se cache", not toast.muteRow:IsShown())
	toast.mute:Click()
	local printed = {}
	local oldPrint = NS.Print
	NS.Print = function(_, msg) printed[#printed + 1] = msg end
	toast.muteRow.choices[2]:Click()
	NS.Print = oldPrint
	C.sounds = {}
	Check("[CAP] 15 min : sourdine posée, bandeau effacé, annoncé", NS:DB().captureMuteUntil ~= nil
		and math.abs(NS:CaptureMuted() - 15 * 60) <= 1 and not toast:IsShown() and printed[1] and Find(printed[1], "15 min"))
	C.SeeKill(5301, { name = "Kodo B" })
	Check("[CAP] en sourdine : pas de bandeau ni de son, mais le filet", not toast:IsShown() and #C.sounds == 0
		and NS.captureNetButton:IsShown(), #C.sounds)
	Check("[CAP] texte de durée", NS:CaptureMuteText(90) == "2 min" and NS:CaptureMuteText(3600) == "1 h"
		and NS:CaptureMuteText(3900) == "1 h 05" and NS:CaptureMuteText(40) == "40 s")
	Mock:Advance(16 * 60)
	local over = NS:CaptureMuted() == nil
	C.SeeKill(5302, { name = "Kodo C" })
	Check("[CAP] au bout du temps : plus de sourdine, le bandeau revient", over and toast:IsShown() and toast.text:GetText() == "Kodo C")
	NS:CaptureQueueClear()
	NS.EXTRA_COMMANDS["filet"](NS, "sourdine 5")
	local five = NS:CaptureMuted() and NS:CaptureMuted() <= 5 * 60
	NS.EXTRA_COMMANDS["filet"](NS, "sourdine off")
	local off = NS:CaptureMuted() == nil
	NS.EXTRA_COMMANDS["filet"](NS, "sourdine")
	Check("[CAP] /qc filet sourdine 5 | off | (15 min par défaut)", five and off and NS:CaptureMuted() and NS:CaptureMuted() > 14 * 60)
	NS:CaptureUnmute()
end

-- 13. Sons ---------------------------------------------------------------------------------------------
do
	Say("-- capture : sons")
	C.Reset()
	C.SeeKill(5400, { name = "Ours" })
	NS:CaptureToastShow()
	Check("[CAP] capture possible : le carillon (piège prêt des mascottes), une fois", Has(C.sounds, NS.CAPTURE_SOUNDS.ready)
		and #C.sounds == 1, table.concat(C.sounds, ","))
	C.Roll(0)
	NS:CaptureThrow()
	C.Settle()
	Check("[CAP] lancer, puis capturé : son du lancer, la petite musique de récompense", Has(C.sounds, NS.CAPTURE_SOUNDS.throw)
		and Has(C.sounds, NS.CAPTURE_SOUNDS.ok) and not Has(C.sounds, NS.CAPTURE_SOUNDS.fail))
	C.sounds = {}
	C.Roll(0.99)
	C.SeeKill(5401, { name = "Ours B" })
	NS:CaptureThrow()
	C.Settle()
	Check("[CAP] échappé : son d'échec", Has(C.sounds, NS.CAPTURE_SOUNDS.fail) and not Has(C.sounds, NS.CAPTURE_SOUNDS.ok))
	C.sounds = {}
	NS.SHINY_CHANCE = 1
	C.Roll(0)
	C.SeeKill(5402, { name = "Ours doré" })
	NS.SHINY_CHANCE = 0
	NS:CaptureThrow()
	C.Settle()
	Check("[CAP] brillante capturée : la fanfare", Has(C.sounds, NS.CAPTURE_SOUNDS.shiny))
	C.sounds = {}
	NS:DB().companionCaptureSound = false
	C.Roll(0)
	C.SeeKill(5403, { name = "Ours C" })
	NS:CaptureThrow()
	C.Settle()
	local silent = #C.sounds == 0
	NS:DB().companionCaptureSound = true
	_G.PlaySound = nil
	local ok = NS:CapturePlaySound("ok")
	C.Install()
	Check("[CAP] réglage « Sons de capture » coupé : silence ; sans PlaySound (client) : rien ne casse", silent and ok == false)
	-- la scène ne joue plus ses propres kits (plus de doublon)
	C.sounds = {}
	NS:DB().companionCaptureAnim = true
	C.Roll(0)
	C.SeeKill(5404, { name = "Ours D" })
	NS:CaptureThrow()
	C.Settle()
	Check("[CAP] scène animée : une seule musique de réussite", Count(C.sounds, NS.CAPTURE_SOUNDS.ok) == 1)
	NS:DB().companionCaptureAnim = false
end

-- 14. La scène animée -------------------------------------------------------------------------------
do
	Say("-- capture : scène animée")
	C.Reset(true)
	C.SeeKill(3600, { name = "Ours gris", class = "rare", level = 20 })
	C.Roll(0)
	Check("[CAPFX] clic : la scène remplace la petite fenêtre", NS:CaptureThrow() == true
		and NS.captureStage and NS.captureStage:IsShown() and not (NS.capturePrompt and NS.capturePrompt:IsShown()))
	local stage, rolling = NS.captureStage, NS:CaptureState().rolling
	-- 2.14.0 (bêta 3) : le rang dans le titre (plus de losanges de rareté)
	Check("[CAPFX] rareté : « CAPTURE · RARE » en titre, le nom à la couleur de la rareté", stage.rarity == NS.CAPTURE_RARITY.rare
		and stage.title:GetText() == "CAPTURE · RARE" and stage.name:GetText() == "Ours gris"
		and stage.name.textColor[1] == NS.CAPTURE_RARITY.rare.text[1], stage.title:GetText())
	local art = NS.CAPTURE_ART
	Check("[CAPFX] nos textures (Textures/, tools/gen_capture_assets.py) : filet, paquet, halo, rayons, ruban, étoiles, cordes",
		stage.net.texture == art.net and stage.bundle.texture == art.bundle and stage.halo.texture == art.halo
		and stage.rays.texture == art.rays and stage.ribbonPanel.texture == art.ribbon and stage.starSlots[1].texture == art.stars
		and stage.ropes[1].texture == art.rope)
	Check("[CAPFX] le vol : paquet lancé qui tourne, filet replié, puis ouvert (entier) à l'apogée",
		NS:CaptureStageUpdate(rolling.start + 0.3) == "throw" and (stage.bundle.rotation or 0) > 0 and not stage.net:IsShown()
		and not stage.starSlots[1]:IsShown()
		and NS:CaptureStageUpdate(rolling.start + NS.CAPTURE_THROW_TIME - 0.05) == "throw" and stage.net:IsShown()
		and stage.net.texCoord[1] == 0 and stage.net.texCoord[2] == 0.5)
	Check("[CAPFX] après le vol : les secousses (la première retardée par le vol)",
		NS:CaptureStageUpdate(rolling.start + NS.CAPTURE_THROW_TIME + 0.05) == "shake" and stage.shakeDots[1]:IsShown()
		and not stage.bundle:IsShown()
		and rolling.nextAt >= rolling.start + NS.CAPTURE_THROW_TIME + NS.CAPTURE_SHAKE_STEP - 1e-6)
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[CAPFX] verdict : capturé, ruban « Capturé ! », rayons, gerbe", rolling.result == "ok" and stage:IsShown()
		and NS:CaptureStageUpdate(rolling.resultAt + 0.2) == "ok" and stage.banner:IsShown()
		and stage.bannerText:GetText() == NS.L.CAPTURE_GOT and stage.rays:IsShown() and stage.burst[1]:IsShown())
	Check("[CAPFX] … la gerbe s'éteint, le filet s'efface ; pas de motes : pas une brillante",
		NS:CaptureStageUpdate(rolling.resultAt + 1.5) == "ok" and not stage.burst[1]:IsShown() and not stage.net:IsShown()
		and not stage.motes[1]:IsShown() and not stage.rays2:IsShown())
	stage:GetScript("OnMouseUp")(stage)
	NS:CaptureTick(NS.Now())
	Check("[CAPFX] un clic ferme la scène", not stage:IsShown() and NS:CaptureState().rolling == nil)
	-- échec
	C.SeeKill(3601, { name = "Loup", level = 20 })
	C.Roll(0.99)
	NS:CaptureThrow()
	rolling = NS:CaptureState().rolling
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[CAPFX] échec : « Échappé », le filet déchiré (moitié droite) tombe, ses cordes volent", rolling.result == "fail"
		and NS:CaptureStageUpdate(rolling.resultAt + 0.3) == "fail" and stage.bannerText:GetText() == NS.L.CAPTURE_FLED
		and stage.net.texCoord[1] == 0.5 and stage.net:IsShown() and stage.ropes[1]:IsShown() and not stage.starSlots[1]:IsShown()
		and stage.footer:GetText() == NS.L.CAPTURE_STAGE_FAIL)
	local fallen = NS:CaptureStageUpdate(rolling.resultAt + 1.5) == "fail" and not stage.net:IsShown() and not stage.ropes[1]:IsShown()
	for _ = 1, 5 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[CAPFX] … tout retombe, la scène se ferme seule après le temps d'affichage", fallen and not stage:IsShown())
	-- brillante : dorée, deux gerbes de rayons, motes
	NS.SHINY_CHANCE = 1
	C.SeeKill(3602, { name = "Cerf", level = 20 })
	NS.SHINY_CHANCE = 0
	C.Roll(0)
	NS:CaptureThrow()
	rolling = NS:CaptureState().rolling
	Check("[CAPFX] brillante : dorée, le nom le dit", NS:CaptureRarity({ class = "normal", shiny = true }).color == NS.Theme.GOLD_LIGHT
		and rolling.target.shiny == true and stage.name:GetText() == NS:F("CAPTURE_SHINY_TAG", "Cerf"))
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[CAPFX] … capturée : deuxième gerbe à contresens, motes dorées, pied « Brillante ! »",
		NS:CaptureStageUpdate(rolling.resultAt + 0.5) == "ok" and stage.rays2:IsShown() and (stage.rays2.rotation or 0) < 0
		and stage.motes[1]:IsShown() and stage.footer:GetText() == NS.L.CAPTURE_STAGE_SHINY)
	stage:GetScript("OnMouseUp")(stage)
	NS:CaptureTick(NS.Now())
	-- les étoiles tirées, sous la rareté, une à une
	C.Reset(true)
	C.quality = 3
	C.SeeKill(4600, { name = "Ours gris", class = "rare" })
	C.Roll(0.95)
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	C.Net():Click("LeftButton")
	stage, rolling = NS.captureStage, NS:CaptureState().rolling
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[CAPFX] 3 étoiles : affichées une à une sous la rareté (la troisième après 0,8 s), pleines",
		rolling.result == "ok" and rolling.stars == 3
		and NS:CaptureStageUpdate(rolling.resultAt + 0.5) == "ok" and stage.starSlots[1]:IsShown() and not stage.starSlots[3]:IsShown()
		and NS:CaptureStageUpdate(rolling.resultAt + 1.0) == "ok" and stage.starSlots[3]:IsShown() and stage.starSpark:IsShown())
	stage:GetScript("OnMouseUp")(stage)
	NS:CaptureTick(NS.Now())
end

-- 15. Page Créatures : ligne et fiche ------------------------------------------------------------------
do
	Say("-- capture : page Créatures")
	C.Reset()
	NS:CaptureData().creatures[4700] = { name = "Lion", class = "normal", normal = true, at = 100, stars = 2 }
	NS:CaptureData().count = 1
	NS.captureAppCache = nil
	NS:BestiaryData()[1413] = { [4700] = { name = "Lion", seen = true, killed = 2, class = "normal", type = "Bête" } }
	local item
	for _, e in ipairs(NS:MenagerieList({ zone = "all", state = "captured" })) do if e.npc == 4700 then item = e end end
	Check("[CAP] CreaturesList : étoiles de l'espèce", item and item.stars == 2 and item.shinyStars == nil)
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.menZone, f.menState, f.menRank, f.menSearch, f.menSort = "all", "all", "all", "lion", "no"
	f.sections.menagerie:Click()
	local row
	for _, cell in ipairs(f.men.items) do if cell.entry and cell.entry.npc == 4700 then row = cell end end
	-- 2.11.0 : étoiles dessinées (atlas du jeu) à gauche du type, plus en texte
	Check("[CAP] ligne : les étoiles avant le type", row and row.stars and #row.stars == 3 and row.stars[1].star:IsShown()
		and row.detail:GetText() == "Bête", row and row.detail:GetText())
	row.scripts.OnEnter(row)
	local text = {}
	for _, line in ipairs(f.men.preview.lines) do text[#text + 1] = line:GetText() or "" end
	local joined = table.concat(text, "\n")
	Check("[CAP] fiche : la qualité du spécimen (avec la date, ou seule)", (Find(joined, "Capturée le") or Find(joined, "Qualité"))
		and select(2, joined:gsub("|A:auctionhouse%-icon%-favorite", "")) == 3, joined)
	f:Hide()
end

-- 16. Coût : migration 1.6.0 une fois, lectures, horloge de la file --------------------------------------
do
	Say("-- capture : coût des lectures")
	C.Reset()
	NS:DB().capture, NS.captureMergedChar = nil, nil; NS:CompanionData().capture = { creatures = { [21] = { name = "Ancienne brillante", at = 5, shiny = true } }, count = 1 }
	local data = NS:CaptureData()
	Check("[CAP] migration 1.6.0 faite une fois, repère posé", data.creatures[21].normal == false and data.pairN == 1)
	data.creatures[22] = { name = "Sans version", at = 6 }
	NS:CaptureData()
	Check("[CAP] … pas refaite à chaque lecture", data.creatures[22].normal == nil)
	data.count = 2
	NS:CaptureData()
	Check("[CAP] … refaite quand le nombre d'espèces bouge", data.creatures[22].normal == true)
	-- la Ménagerie lit les fiches directement (pas un CaptureStars par espèce)
	local calls, stars = 0, NS.CaptureStars
	NS.CaptureStars = function(...) calls = calls + 1; return stars(...) end
	NS:MenagerieList({ zone = "all" })
	NS.CaptureStars = stars
	Check("[CAP] CreaturesList : étoiles sans CaptureStars par espèce", calls == 0, calls)
	-- horloge : le tri ne se refait pas dix fois par seconde
	C.Reset()
	C.SeeKill(4900, { name = "Lièvre" })
	C.SeeKill(4901, { name = "Renard" })
	local prunes, prune = 0, NS.CaptureQueuePrune
	NS.CaptureQueuePrune = function(...) prunes = prunes + 1; return prune(...) end
	local t0 = NS.Now()
	NS:CaptureTick(t0)
	prunes = 0
	for step = 1, 9 do NS:CaptureTick(t0 + step * 0.1) end
	local still = prunes
	NS:CaptureTick(t0 + 1.05)
	Check("[CAP] horloge : pas de tri à chaque passage sans changement, une fois par seconde au plus", still == 0 and prunes == 1,
		still .. "/" .. prunes)
	local capture = NS:CaptureData()
	capture.serial = (tonumber(capture.serial) or 0) + 1
	NS:CaptureTick(t0 + 1.1)
	local changed = prunes == 2
	local expires = NS:CaptureQueueState()[1].expires
	NS:CaptureTick(expires + 0.05)
	NS.CaptureQueuePrune = prune
	Check("[CAP] … mais dès que les captures changent, et un candidat au bout de son temps sort tout de suite", changed
		and #NS:CaptureQueueState() == 0, prunes)
end

-- 17. Cadrage du compagnon --------------------------------------------------------------------------------
do
	Say("-- compagnon : cadrage")
	-- un faux modèle 3D qui retient ce qu'on lui demande (comme companion_fx.lua)
	_G.CreateFrame = function(kind, ...)
		local frame = C.savedCreateFrame(kind, ...)
		if kind == "PlayerModel" or kind == "Model" then
			function frame:SetDisplayInfo(id) self.display = id end
			function frame:SetCreature(id) self.creature = id end
			function frame:SetAnimation(id) self.anim = id end
			function frame:SetModelScale(s) self.modelScale = s end
			function frame:SetRotation(r) self.rotation = r end
			function frame:SetCamDistanceScale(s) self.cam = s end
			function frame:SetPortraitZoom(z) self.portrait = z end
		end
		return frame
	end
	C.Reset()
	local frame = NS:EnsureCompanionFrame()
	local model = frame and frame.model
	Check("[CAP] cadrage par défaut : buste (2.9.0, la créature tient dans son cadre)", NS:CompanionFraming() == "buste")
	NS:DB().companionFramingV29 = nil
	NS:DB().companionFraming = "portrait"
	local migrated = NS:CompanionFraming() == "buste"
	NS:DB().companionFraming = "portrait"
	Check("[CAP] ancien défaut « portrait » : repassé une fois en buste, puis un « portrait » choisi est gardé",
		migrated and NS:CompanionFraming() == "portrait")
	if model then NS:CompanionApplyModel() end
	Check("[CAP] portrait : caméra « portrait » à fond, distance 1, échelle du stade gardée", model and model.portrait == 1
		and model.cam == 1 and model.modelScale == NS.COMPANION_STAGES[NS:CompanionStage()].scale)
	if model then
		NS:CompanionSetFraming("buste")
		local buste = model.portrait == NS.COMPANION_FRAMING_ZOOM.buste and model.cam == 1
		NS:CompanionSetFraming("pied")
		Check("[CAP] buste : caméra à mi-hauteur ; en pied : pas de zoom, caméra reculée", buste and model.portrait == 0 and model.cam == 1.6)
		Check("[CAP] cadrage inconnu : refusé", NS:CompanionSetFraming("plafond") == nil and NS:CompanionFraming() == "pied")
		NS:CompanionSetFraming("portrait")
	end
	_G.CreateFrame = C.savedCreateFrame
	local choices = NS:CompanionFramingChoices()
	local row = false
	for _, def in ipairs(NS.COMPANION_OPTION_ROWS or {}) do if def.key == "companionFraming" then row = true end end
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		for _, def in ipairs(page.rows or {}) do if def.key == "companionFraming" then row = true end end
	end
	Check("[CAP] trois cadrages proposés, libellés courts, réglage dans la page du compagnon", #choices == 3
		and choices[1].value == "portrait" and #NS.L.COMP_FRAMING_portrait <= 24 and NS.L.COMP_FRAMING_pied == "En pied" and row)
end

-- 18. Commande, textes, réglages ; plus de recaptures limitées (2.15.0) ---------------------------------
do
	Say("-- capture : commande, textes, réglages")
	C.Reset()
	Mock:Reset()
	NS.EXTRA_COMMANDS["capture"](NS)
	Check("[CAP] /qc capture : créatures vide expliquée", Find(Mock:Output(), "Créatures"), Mock:Output())
	local missing = {}
	for _, name in ipairs({ "CAPTURE_STRINGS", "CAPTURE_STAGE_STRINGS", "CAPTURE_QUEUE_STRINGS", "CAPTURE_BATCH_STRINGS" }) do
		local S = NS[name]
		for key in pairs(S.fr) do if not S.en[key] then missing[#missing + 1] = name .. ".en." .. key end end
		for key in pairs(S.en) do if not S.fr[key] then missing[#missing + 1] = name .. ".fr." .. key end end
	end
	Check("[CAP] textes fr et en (capture, scène, file, lot)", #missing == 0, table.concat(missing, ", "))
	local bad = {}
	for name, keys in pairs(NS.CAPTURE_POOLS) do
		if NS.COMPANION_POOLS[name] ~= keys or #keys < 2 then bad[#bad + 1] = name end
	end
	Check("[CAP] répliques de capture enregistrées (au moins deux chacune)", #bad == 0, table.concat(bad, ", "))
	local rows = {}
	for _, r in ipairs(NS.DAILY_OPTION_ROWS) do rows[r.key] = r end
	local absent = {}
	for _, key in ipairs({ "companionCapture", "companionCaptureAnim", "companionCaptureToast", "companionCaptureSound" }) do
		if not (rows[key] and rows[key].kind == "bool") then absent[#absent + 1] = key end
	end
	Check("[CAP] réglages sur la page « Au jour le jour » (capture, animée, bandeau, sons), capture allumée par défaut",
		#absent == 0 and NS:DB().companionCapture == true
		and rows.companionCaptureToast.describe() == NS.L.OPT_DAILY_CAPTURE_TOAST_DESC, table.concat(absent, ", "))
	Check("[CAP] réglage : la description parle du filet, plus de fenêtre",
		Find(NS.CAPTURE_STRINGS.fr.OPT_DAILY_CAPTURE_DESC, "filet") and Find(NS.CAPTURE_STRINGS.en.OPT_DAILY_CAPTURE_DESC, "net"))
	-- 2.15.0 : plus de limites de recapture (le filet ne revient que pour un meilleur spécimen,
	-- specimens.lua) ; les anciens réglages restent dans la sauvegarde, ignorés
	local retry = 0
	for key in pairs(rows) do if tostring(key):find("^companionRetry") then retry = retry + 1 end end
	Check("[CAP] plus de CaptureRetryLeft ni de réglages « Recaptures »", NS.CaptureRetryLeft == nil and retry == 0)
end

for _, name in ipairs(GLOBALS) do _G[name] = C.saved[name] end
_G.CreateFrame = C.savedCreateFrame
math.random = C.random
NS.SHINY_CHANCE = C.savedShiny
NS:DB().captureMuteUntil = nil
ResetWorld()
NS.CaptureRollQuality = C.rollQuality
