-- QuestCompanion 2.0, lot 1 : la capture discrète (CaptureQueue.lua). Plus de
-- fenêtre automatique : une file des monstres abattus qui valent le coup, un
-- bouton filet sur le compagnon (compteur, doré pour une brillante), clic =
-- le meilleur candidat, clic droit = la liste ; étoiles 1 à 3 tirées à la
-- capture, meilleur spécimen gardé.
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
function Q.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt", "captureQueueList", "captureNetButton", "captureToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureAppCache = nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
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
function Q.Net() return NS.companionFrame and NS.companionFrame.captureNet end
function Q.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = Q.saved[name] end
	math.random = Q.random
	NS.SHINY_CHANCE = Q.savedShiny
	ResetWorld()
end

-- 1. Étoiles : lecture, anciennes fiches, tirage ---------------------------------------------------
do
	Say("-- qc2 capture : étoiles")
	Q.Reset()
	NS:CompanionData().capture = { creatures = {
		[11] = { name = "Ancien", at = 100, normal = true },
		[12] = { name = "Ancien brillant", at = 200, normal = false, shiny = true, shinyAt = 200 },
	}, count = 2 }
	local data = NS:CaptureData()
	Check("[QC2CAP] anciennes fiches : 1 étoile", data.creatures[11].stars == 1 and data.creatures[12].shinyStars == 1
		and data.creatures[12].stars == nil)
	Check("[QC2CAP] CaptureStars : version capturée -> 1..3, sinon nil", NS:CaptureStars(11, false) == 1
		and NS:CaptureStars(11, true) == nil and NS:CaptureStars(12, true) == 1 and NS:CaptureStars(12, false) == nil
		and NS:CaptureStars(999, false) == nil)
	data.creatures[11].stars = 7
	Check("[QC2CAP] CaptureStars : borné à 3", NS:CaptureStars(11) == 3)
	Q.Roll(0); local a = NS:CaptureRollStars()
	Q.Roll(0.7); local b = NS:CaptureRollStars()
	Q.Roll(0.95); local c = NS:CaptureRollStars()
	Check("[QC2CAP] tirage 60 / 30 / 10 : 1, 2, 3 étoiles", a == 1 and b == 2 and c == 3)
	local total = 0
	for _, w in ipairs(NS.CAPTURE_STAR_ODDS) do total = total + w end
	Check("[QC2CAP] probabilités : 3 étoiles la plus rare, total 100", total == 100
		and NS.CAPTURE_STAR_ODDS[3] < NS.CAPTURE_STAR_ODDS[2] and NS.CAPTURE_STAR_ODDS[2] < NS.CAPTURE_STAR_ODDS[1])
	local _, icons = NS:CaptureStarsText(2):gsub("|T", "")
	Check("[QC2CAP] texte : trois étoiles (pleines et vides)", icons == 3 and NS:CaptureStarsText(nil) == "")
end

-- 2. La file : packs, fin du combat, 30 s --------------------------------------------------------------
do
	Say("-- qc2 capture : file d'attente")
	Q.Reset()
	Check("[QC2CAP] file vide : pas de filet", not (Q.Net() and Q.Net():IsShown()))
	Q.combat = true
	Q.SeeKill(4100, { name = "Loup A" })
	Q.SeeKill(4101, { name = "Loup B", class = "elite" })
	Q.SeeKill(4102, { name = "Loup C" })
	local queue = NS:CaptureQueue()
	Check("[QC2CAP] un pack : trois candidats", #queue == 3)
	Check("[QC2CAP] en combat : le compte n'a pas commencé", queue[1].expires == nil and queue[3].expires == nil)
	Check("[QC2CAP] aucune fenêtre automatique", not (NS.capturePrompt and NS.capturePrompt:IsShown()))
	Check("[QC2CAP] filet visible, compteur 3", Q.Net() and Q.Net():IsShown() and Q.Net().count:GetText() == "3")
	Check("[QC2CAP] contrat : guid, npcID, name, class, type, shiny, reason", queue[1].guid and queue[1].npcID == 4101
		and queue[1].name == "Loup B" and queue[1].class == "elite" and queue[1].type == "Bête" and queue[1].reason == "new"
		and not queue[1].shiny)
	Check("[QC2CAP] le même monstre une seule fois", NS:CaptureOffer(Q.Guid(4100), { zoneID = 1413, npcID = 4100 }) == nil
		and #NS:CaptureQueue() == 3)
	Mock:Advance(60); NS:CaptureTick(NS.Now())
	Check("[QC2CAP] combat long : personne ne sort", #NS:CaptureQueue() == 3)
	Q.combat = false
	NS:CaptureTick(NS.Now())
	local started = NS:CaptureQueue()[1].expires
	Check("[QC2CAP] fin du combat : 30 s chacun à partir de là", started and math.abs(started - (NS.Now() + 30)) < 0.01)
	Mock:Advance(20); NS:CaptureTick(NS.Now())
	Check("[QC2CAP] 20 s plus tard : toujours là", #NS:CaptureQueue() == 3)
	Mock:Advance(11); NS:CaptureTick(NS.Now())
	Check("[QC2CAP] 31 s : sortis, filet caché", #NS:CaptureQueue() == 0 and not Q.Net():IsShown())
	-- hors combat : le compte part tout de suite
	Q.SeeKill(4103)
	Check("[QC2CAP] hors combat : compte immédiat", NS:CaptureQueue()[1].expires ~= nil)
	-- plafond
	NS:CaptureQueueClear()
	for npc = 4200, 4200 + NS.CAPTURE_QUEUE_MAX + 3 do Q.SeeKill(npc) end
	Check("[QC2CAP] plafond de la file", #NS:CaptureQueue() == NS.CAPTURE_QUEUE_MAX)
	NS:CaptureQueueClear()
	Check("[QC2CAP] tout ignorer : file vide, filet caché", #NS:CaptureQueue() == 0 and not Q.Net():IsShown())
end

-- 3. Ce qui vaut le coup, et dans quel ordre --------------------------------------------------------------
do
	Say("-- qc2 capture : tri")
	Q.Reset()
	local creatures = NS:CaptureData().creatures
	creatures[4300] = { name = "Trois", class = "normal", normal = true, at = 1, stars = 3 }
	creatures[4301] = { name = "Une", class = "normal", normal = true, at = 1, stars = 1 }
	creatures[4302] = { name = "Deux", class = "normal", normal = true, at = 1, stars = 2 }
	Q.SeeKill(4300, { name = "Trois" })
	Check("[QC2CAP] déjà à 3 étoiles : pas dans la file", #NS:CaptureQueue() == 0)
	Q.SeeKill(4302, { name = "Deux" })
	Q.SeeKill(4301, { name = "Une" })
	Q.SeeKill(4303, { name = "Nouveau" })
	Q.SeeKill(4304, { name = "Rare nouveau", class = "rare" })
	NS.SHINY_CHANCE = 1
	Q.Roll(0)
	Q.SeeKill(4300, { name = "Trois", spawn = "5A1A1" })
	NS.SHINY_CHANCE = 0
	math.random = Q.random
	local order = {}
	for _, c in ipairs(NS:CaptureQueue()) do order[#order + 1] = c.npcID end
	Check("[QC2CAP] brillante > nouvelle (plus rare d'abord) > étoiles (moins d'étoiles d'abord)",
		table.concat(order, ",") == "4300,4304,4303,4301,4302", table.concat(order, ","))
	local best = NS:CaptureQueueBest()
	Check("[QC2CAP] brillante : raison « shiny »", best.shiny and best.reason == "shiny")
	Check("[QC2CAP] filet doré quand une brillante attend", Q.Net().shiny == true)
	Q.Net():GetScript("OnUpdate")(Q.Net())
	Check("[QC2CAP] … et il scintille", (Q.Net().glow.alpha or 0) > 0)
	local stars = NS:CaptureQueue()[4]
	Check("[QC2CAP] amélioration : raison « stars », étoiles actuelles", stars.reason == "stars" and stars.have == 1
		and NS:CaptureQueueLine(stars):find("|T", 1, true) ~= nil)
end

-- 4. Clic : le meilleur ; clic droit : la liste ------------------------------------------------------------
do
	Say("-- qc2 capture : bouton et liste")
	Q.Reset()
	Q.SeeKill(4400, { name = "Ours" })
	Q.SeeKill(4401, { name = "Ours élite", class = "elite" })
	Q.SeeKill(4402, { name = "Sanglier" })
	Q.Roll(0)
	local hooked
	local resolve = NS.CaptureResolve
	NS.CaptureResolve = function(self, rolling) hooked = rolling.target; return resolve(self, rolling) end
	-- trois candidats : le clic propose le choix (2.5.0) ; « Capturer : … » = le meilleur
	Q.Net():Click("LeftButton")
	Check("[QC2CAP] clic à trois candidats : le choix, rien ne part encore", NS.captureChooser
		and NS.captureChooser:IsShown() and NS:CaptureState().rolling == nil)
	NS.captureChooser.single:Click()
	Check("[QC2CAP] clic : le filet part sur le meilleur (élite)", NS:CaptureState().rolling
		and NS:CaptureState().rolling.target.npcID == 4401)
	Check("[QC2CAP] … sorti de la file, compteur 2", #NS:CaptureQueue() == 2 and Q.Net().count:GetText() == "2")
	Check("[QC2CAP] … sans scène animée : la petite fenêtre montre les secousses", NS.capturePrompt and NS.capturePrompt:IsShown()
		and NS.capturePrompt.status:IsShown())
	Check("[QC2CAP] un filet à la fois", Q.Net():Click("LeftButton") == nil and #NS:CaptureQueue() == 2)
	Q.Settle()
	NS.CaptureResolve = resolve
	Check("[QC2CAP] capturé ; CaptureResolve garde rolling.target (npcID, class, type, shiny)", hooked and hooked.npcID == 4401
		and hooked.class == "elite" and hooked.type == "Bête" and hooked.shiny == nil and NS:CaptureHas(4401))
	Check("[QC2CAP] … avec ses étoiles", NS:CaptureStars(4401) == 1 and NS:CaptureData().creatures[4401].stars == 1)
	Check("[QC2CAP] … fenêtre refermée", not NS.capturePrompt:IsShown())
	-- clic droit : la liste
	Q.Net():Click("RightButton")
	local list = NS.captureQueueList
	Check("[QC2CAP] clic droit : la liste, une ligne par candidat", list and list:IsShown() and list.rows[1]:IsShown()
		and list.rows[2]:IsShown() and not list.rows[3]:IsShown())
	Check("[QC2CAP] … nom, raison, chance, temps", list.rows[1].text:GetText():find("Ours", 1, true)
		and list.rows[1].detail:GetText():find(NS.L.CAPTURE_Q_REASON_new, 1, true)
		and list.rows[1].detail:GetText():find("%d+ s") ~= nil, list.rows[1].detail:GetText())
	NS:CaptureGrant("lasso", { quiet = true, silent = true })
	list.aids[2]:Click()
	Check("[QC2CAP] … choisir une aide dans la liste", NS:CaptureState().aid == "lasso"
		and list.rows[1].detail:GetText():find("95", 1, true) ~= nil, list.rows[1].detail:GetText())
	local pick = list.rows[2].candidate
	list.rows[2]:Click()
	Check("[QC2CAP] clic sur une ligne : ce candidat-là, avec l'aide", NS:CaptureState().rolling
		and NS:CaptureState().rolling.target.npcID == pick.npcID and NS:CaptureState().rolling.aid == "lasso"
		and NS:CaptureData().items.lasso == 0)
	Check("[QC2CAP] … la liste se referme", not list:IsShown())
	Q.Settle()
	Q.Net():Click("RightButton")
	Check("[QC2CAP] liste rouverte", list:IsShown())
	Q.Net():Click("RightButton")
	Check("[QC2CAP] reclic droit : refermée", not list:IsShown())
	Q.Net():Click("RightButton")
	list.ignore:Click()
	Check("[QC2CAP] « Tout ignorer » : vide, liste et filet cachés", #NS:CaptureQueue() == 0 and not list:IsShown()
		and not Q.Net():IsShown())
	-- infobulle du filet
	Q.SeeKill(4403, { name = "Hibou" })
	local lines = {}
	local saved = rawget(_G, "GameTooltip")
	_G.GameTooltip = { SetOwner = function() end, AddLine = function(_, text) lines[#lines + 1] = text end, Show = function() end,
		Hide = function() end, AddDoubleLine = function(_, text) lines[#lines + 1] = text end }
	Q.Net():GetScript("OnEnter")(Q.Net())
	_G.GameTooltip = saved
	local all = table.concat(lines, "\n")
	Check("[QC2CAP] infobulle : le meilleur, clic, clic droit", all:find("Hibou", 1, true) ~= nil
		and all:find(NS.L.CAPTURE_Q_RIGHT, 1, true) ~= nil, all)
	-- réglage coupé : rien
	NS:CaptureQueueClear()
	NS:DB().companionCapture = false
	Q.SeeKill(4404)
	Check("[QC2CAP] réglage coupé : rien dans la file", #NS:CaptureQueue() == 0 and not Q.Net():IsShown())
	NS:DB().companionCapture = true
end

-- 5. Recapture : le meilleur spécimen est gardé ------------------------------------------------------------
do
	Say("-- qc2 capture : recapture")
	Q.Reset()
	local creatures = NS:CaptureData().creatures
	Q.SeeKill(4500, { name = "Cerf", spawn = "A1" })
	Q.Roll(0)
	NS:CaptureThrow()
	Q.Settle()
	local entry = creatures[4500]
	local at = entry.at
	Check("[QC2CAP] première capture : 1 étoile", entry.stars == 1 and NS:CaptureData().count == 1)
	-- une meilleure (sifflet : capture assurée, tirage haut = 3 étoiles)
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	Q.SeeKill(4500, { name = "Cerf", spawn = "A2" })
	Check("[QC2CAP] recapture proposée (amélioration)", NS:CaptureQueueBest() and NS:CaptureQueueBest().reason == "stars")
	Q.Roll(0.97)
	Mock:Reset()
	Mock:Advance(5)
	NS:CaptureThrow()
	Q.Settle()
	Check("[QC2CAP] 3 étoiles : gardées, toujours une seule espèce", entry.stars == 3 and NS:CaptureData().count == 1
		and entry.at ~= at)
	Check("[QC2CAP] … « meilleur spécimen » dans le chat", Mock:Output():find("meilleur spécimen", 1, true) ~= nil, Mock:Output())
	Q.SeeKill(4500, { name = "Cerf", spawn = "A3" })
	Check("[QC2CAP] à 3 étoiles : plus proposée", #NS:CaptureQueue() == 0)
	-- une moins bonne : la meilleure reste, avec sa date
	entry.stars = 2
	local kept = entry.at
	Q.SeeKill(4500, { name = "Cerf", spawn = "A4" })
	Q.Roll(0)
	Mock:Reset()
	Mock:Advance(5)
	NS:CaptureThrow()
	Q.Settle()
	Check("[QC2CAP] moins bonne : la meilleure reste, sa date aussi", entry.stars == 2 and entry.at == kept)
	Check("[QC2CAP] … dit dans le chat", Mock:Output():find("2 étoiles reste", 1, true) ~= nil, Mock:Output())
	-- version brillante : ses propres étoiles
	NS.SHINY_CHANCE = 1
	Q.Roll(0.7)
	Q.SeeKill(4500, { name = "Cerf", spawn = "A5" })
	NS.SHINY_CHANCE = 0
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	NS:CaptureThrow()
	Q.Settle()
	Check("[QC2CAP] brillante : ses étoiles à part", entry.shiny and entry.shinyStars == 2 and entry.stars == 2
		and NS:CaptureStars(4500, true) == 2)
end

-- 6. La scène : les étoiles sous la rareté --------------------------------------------------------------------
do
	Say("-- qc2 capture : scène")
	Q.Reset()
	NS:DB().companionCaptureAnim = true
	Q.SeeKill(4600, { name = "Ours gris", class = "rare" })
	Q.Roll(0.95)
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	Q.Net():Click("LeftButton")
	local stage, rolling = NS.captureStage, NS:CaptureState().rolling
	Check("[QC2CAP] clic sur le filet : la scène se joue", stage and stage:IsShown() and rolling ~= nil)
	NS:CaptureStageUpdate(rolling.start + 0.1)
	Check("[QC2CAP] pendant le lancer : pas d'étoiles", not stage.starSlots[1]:IsShown())
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[QC2CAP] capturé : 3 étoiles tirées", rolling.result == "ok" and rolling.stars == 3)
	Check("[QC2CAP] … affichées une à une sous la rareté (la troisième après 0,8 s), pleines",
		NS:CaptureStageUpdate(rolling.resultAt + 0.5) == "ok" and stage.starSlots[1]:IsShown() and not stage.starSlots[3]:IsShown()
		and NS:CaptureStageUpdate(rolling.resultAt + 1.0) == "ok" and stage.starSlots[3]:IsShown()
		and stage.starSlots[3].texCoord[1] == 0 and stage.starSlots[3].texCoord[2] == 0.5 and stage.starSpark:IsShown())
	Check("[QC2CAP] … le texte des étoiles découpe notre feuille (pleine à gauche, vide à droite)",
		NS:CaptureStarsText(2, 12):find(":0:0:128:64:0:64:0:64:", 1, true) ~= nil
		and NS:CaptureStarsText(2, 12):find(":0:0:128:64:64:128:0:64:", 1, true) ~= nil)
	stage:GetScript("OnMouseUp")(stage)
	NS:CaptureTick(NS.Now())
	NS:DB().companionCaptureAnim = false
end

-- 7. Ménagerie : ligne et fiche ------------------------------------------------------------------------------
do
	Say("-- qc2 capture : Ménagerie")
	Q.Reset()
	NS:CaptureData().creatures[4700] = { name = "Lion", class = "normal", normal = true, at = 100, stars = 2 }
	NS:CaptureData().count = 1
	NS.captureAppCache = nil
	NS:BestiaryData()[1413] = { [4700] = { name = "Lion", seen = true, killed = 2, class = "normal", type = "Bête" } }
	local item
	for _, e in ipairs(NS:MenagerieList({ zone = "all", state = "captured" })) do if e.npc == 4700 then item = e end end
	Check("[QC2CAP] MenagerieList : étoiles de l'espèce", item and item.stars == 2 and item.shinyStars == nil)
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	f.menZone, f.menState, f.menRank, f.menSearch, f.menSort = "all", "all", "all", "lion", "no"
	f.sections.menagerie:Click()
	local row
	for _, cell in ipairs(f.men.items) do if cell.entry and cell.entry.npc == 4700 then row = cell end end
	Check("[QC2CAP] ligne : les étoiles avant le type", row and select(2, row.detail:GetText():gsub("|T", "")) == 3
		and row.detail:GetText():find("Bête", 1, true) ~= nil, row and row.detail:GetText())
	row.scripts.OnEnter(row)
	local text = {}
	for _, line in ipairs(f.men.preview.lines) do text[#text + 1] = line:GetText() or "" end
	local joined = table.concat(text, "\n")
	Check("[QC2CAP] fiche : la qualité du spécimen (avec la date, ou seule)", (joined:find("Capturée le", 1, true) ~= nil
		or joined:find("Qualité", 1, true) ~= nil) and select(2, joined:gsub("|T", "")) == 3, joined)
	f:Hide()
end

-- 7 bis. Compagnon masqué : le filet reste, seul à l'écran ; /qc filet ---------------------------------------
do
	Say("-- qc2 capture : compagnon masqué")
	Q.Reset()
	Q.SeeKill(4300, { name = "Loup seul" })
	local net = NS.captureNetButton
	Check("[QC2CAP] compagnon affiché : le filet est posé sur lui", net and net:IsShown() and not net.alone
		and net:GetParent() ~= nil)
	NS.companionFrame:Hide()
	NS:CapturePlaceNet()
	Check("[QC2CAP] compagnon masqué : le filet reste, seul à l'écran", net:IsShown() and net.alone == true
		and net.lastPoint and net.lastPoint.relTo == UIParent)
	NS.companionFrame:Show()
	NS:CapturePlaceNet()
	Check("[QC2CAP] compagnon de retour : le filet revient sur lui", net.alone == false
		and net.lastPoint.relTo == NS.companionFrame)
	Q.Roll(0)
	NS.EXTRA_COMMANDS["filet"](NS)
	Check("[QC2CAP] /qc filet : lance la capture du meilleur candidat", NS:CaptureState().rolling ~= nil)
	Q.Settle()
	NS:CaptureQueueClear()
	local printed = {}
	local oldPrint = NS.Print
	NS.Print = function(_, msg) printed[#printed + 1] = msg end
	NS.EXTRA_COMMANDS["filet"](NS)
	NS.Print = oldPrint
	Check("[QC2CAP] /qc filet sans rien : le dit", printed[1] == NS.L.CAPTURE_Q_NOTHING, printed[1])
end

-- 7 quater. Filet visible : gros, à côté du compagnon, à sa taille ; bandeau « Capture possible » ------------
do
	Say("-- qc2 capture : filet visible et bandeau")
	Q.Reset()
	NS.captureToastHideAt = nil
	NS:DB().companionSize = 2
	NS:CompanionApplySize()
	Q.SeeKill(4400, { name = "Raptor" })
	local net = NS.captureNetButton
	Check("[QC2CAP] filet : 44 px, icône 36 px, visible au repos", net and net.width == 44 and NS.CAPTURE_NET_SIZE == 44
		and net.icon.width == 36 and net.icon.alpha == 1, net and net.width)
	Check("[QC2CAP] filet : à côté du compagnon (à sa droite), pas sur son portrait", net.side == "right"
		and net.lastPoint.point == "LEFT" and net.lastPoint.relTo == NS.companionFrame and net.lastPoint.relPoint == "RIGHT"
		and net.lastPoint.x == NS.CAPTURE_NET_GAP, tostring(net.lastPoint.point) .. "/" .. tostring(net.lastPoint.relPoint))
	Check("[QC2CAP] filet : compteur sur fond sombre", net.countBack and net.count:GetText() == "1")
	Check("[QC2CAP] filet : il bat quelques secondes à l'arrivée", net.pulseUntil and net.pulseUntil > NS.Now())
	net.scripts.OnUpdate(net)
	Check("[QC2CAP] … le halo s'allume pendant le battement", (net.glow.alpha or 0) > 0)

	-- le bandeau : hors combat, tout de suite
	local toast = NS.captureToast
	Check("[QC2CAP] bandeau « Capture possible » montré, nom de la créature", toast and toast:IsShown()
		and toast.title:GetText() == NS.Theme.Upper(NS.L.CAPTURE_TOAST_TITLE) and toast.text:GetText() == "Raptor"
		and toast.hint:GetText() == NS.L.CAPTURE_TOAST_HINT and NS.captureToastHideAt ~= nil, toast and toast.text:GetText())
	local hideAt = NS.captureToastHideAt
	Q.SeeKill(4401, { name = "Raptor B" })
	Check("[QC2CAP] un deuxième : « et 1 de plus »", toast.hint:GetText():find("et 1 de plus", 1, true) ~= nil, toast.hint:GetText())
	Check("[QC2CAP] … sans prolonger le bandeau (mêlée, 2.9.0)", NS.captureToastHideAt == hideAt)
	Mock:Advance(NS.CAPTURE_TOAST_SECONDS + 1); NS:CaptureTick(NS.Now())
	Check("[QC2CAP] bandeau : s'efface seul au bout de " .. NS.CAPTURE_TOAST_SECONDS .. " s", not toast:IsShown() and NS.captureToastHideAt == nil)
	net.scripts.OnUpdate(net)
	Check("[QC2CAP] filet : le battement s'éteint", net.pulseUntil == nil and net.glow.alpha == 0)

	-- il suit la taille du compagnon
	NS:DB().companionSize = 4
	NS:CompanionApplySize()
	Check("[QC2CAP] filet : à la taille du compagnon (Très grand = ×1,6)", net:GetScale() == NS.COMPANION_SIZES[4], net:GetScale())
	NS:DB().companionSize = 2
	NS:CompanionApplySize()
	Check("[QC2CAP] … et de retour à ×1", net:GetScale() == 1)
	-- au bord droit de l'écran : il passe à gauche
	NS.companionFrame.GetRight = function() return (UIParent:GetWidth() or 1024) - 10 end
	NS:CapturePlaceNet()
	Check("[QC2CAP] compagnon au bord droit : le filet passe à sa gauche", net.side == "left"
		and net.lastPoint.point == "RIGHT" and net.lastPoint.relPoint == "LEFT")
	NS.companionFrame.GetRight = nil
	NS:CapturePlaceNet()
	Check("[QC2CAP] … sinon à droite", net.side == "right")

	-- en combat : le bandeau attend la fin du combat
	NS:CaptureQueueClear()
	Q.combat = true
	Q.SeeKill(4402, { name = "Raptor C" })
	Check("[QC2CAP] en combat : pas de bandeau", not toast:IsShown())
	Q.combat = false
	NS:CaptureTick(NS.Now())
	Check("[QC2CAP] fin du combat : le bandeau", toast:IsShown() and toast.text:GetText() == "Raptor C")
	-- clic : le filet ; le bandeau s'efface
	Q.Roll(0)
	toast.button:Click("LeftButton")
	Check("[QC2CAP] clic sur le bandeau : capture lancée, bandeau effacé", NS:CaptureState().rolling ~= nil and not toast:IsShown())
	Q.Settle()
	-- clic droit : la liste
	Q.SeeKill(4403, { name = "Raptor D" })
	toast.button:Click("RightButton")
	Check("[QC2CAP] clic droit : la liste, bandeau effacé", NS.captureQueueList and NS.captureQueueList:IsShown() and not toast:IsShown())
	NS:CaptureHideQueueList()
	-- brillante : nom marqué
	NS:CaptureQueueClear()
	NS.SHINY_CHANCE = 1
	Q.Roll(0)
	Q.SeeKill(4404, { name = "Raptor doré" })
	NS.SHINY_CHANCE = 0
	Check("[QC2CAP] brillante : le bandeau le dit", toast:IsShown() and toast.text:GetText():find("Raptor doré", 1, true)
		and toast.text:GetText() ~= "Raptor doré", toast.text:GetText())
	-- réglage coupé : plus de bandeau, le filet reste
	NS:CaptureQueueClear()
	NS:DB().companionCaptureToast = false
	Q.SeeKill(4405, { name = "Raptor E" })
	Check("[QC2CAP] réglage coupé : pas de bandeau, le filet reste", not toast:IsShown() and net:IsShown())
	NS:DB().companionCaptureToast = true
	local row
	for _, def in ipairs(NS.DAILY_OPTION_ROWS) do if def.key == "companionCaptureToast" then row = def end end
	Check("[QC2CAP] réglage « bandeau » dans la page Au jour le jour", row and row.kind == "bool" and row.describe() == NS.L.OPT_DAILY_CAPTURE_TOAST_DESC)
	-- plus rien dans la file : bandeau et filet s'effacent
	NS:CaptureQueueClear()
	Check("[QC2CAP] file vidée : bandeau et filet effacés", not toast:IsShown() and not net:IsShown())
end

-- 7 ter. Coût : lectures des captures, horloge de la file -----------------------------------------------------
do
	Say("-- qc2 capture : coût des lectures")
	Q.Reset()
	NS:CompanionData().capture = { creatures = { [21] = { name = "Ancienne brillante", at = 5, shiny = true } }, count = 1 }
	local data = NS:CaptureData()
	Check("[QC2CAP] migration 1.6.0 faite une fois, repère posé", data.creatures[21].normal == false and data.pairN == 1)
	data.creatures[22] = { name = "Sans version", at = 6 }
	NS:CaptureData()
	Check("[QC2CAP] … pas refaite à chaque lecture", data.creatures[22].normal == nil)
	data.count = 2
	NS:CaptureData()
	Check("[QC2CAP] … refaite quand le nombre d'espèces bouge", data.creatures[22].normal == true)
	-- la Ménagerie lit les fiches directement (pas un CaptureStars par espèce)
	local calls, stars = 0, NS.CaptureStars
	NS.CaptureStars = function(...) calls = calls + 1; return stars(...) end
	NS:MenagerieList({ zone = "all" })
	NS.CaptureStars = stars
	Check("[QC2CAP] MenagerieList : étoiles sans CaptureStars par espèce", calls == 0, calls)
	-- horloge : le tri ne se refait pas dix fois par seconde
	Q.Reset()
	Q.SeeKill(4900, { name = "Lièvre" })
	Q.SeeKill(4901, { name = "Renard" })
	local prunes, prune = 0, NS.CaptureQueuePrune
	NS.CaptureQueuePrune = function(...) prunes = prunes + 1; return prune(...) end
	local t0 = NS.Now()
	NS:CaptureTick(t0)
	prunes = 0
	for step = 1, 9 do NS:CaptureTick(t0 + step * 0.1) end
	Check("[QC2CAP] horloge : pas de tri à chaque passage sans changement", prunes == 0, prunes)
	NS:CaptureTick(t0 + 1.05)
	Check("[QC2CAP] … une fois par seconde au plus", prunes == 1, prunes)
	local capture = NS:CaptureData()
	capture.serial = (tonumber(capture.serial) or 0) + 1
	NS:CaptureTick(t0 + 1.1)
	Check("[QC2CAP] … et dès que les captures changent", prunes == 2, prunes)
	local expires = NS:CaptureQueueState()[1].expires
	NS:CaptureTick(expires + 0.05)
	NS.CaptureQueuePrune = prune
	Check("[QC2CAP] … un candidat au bout de son temps sort tout de suite", #NS:CaptureQueueState() == 0)
end

-- 7 quater. Date de première capture : figée --------------------------------------------------------------------
do
	Say("-- qc2 capture : première capture")
	Q.Reset()
	Mock:Reset()
	Q.SeeKill(4950, { name = "Biche", spawn = "B1" })
	Q.Roll(0)
	NS:CaptureThrow()
	Q.Settle()
	local capture = NS:CaptureData()
	local entry = capture.creatures[4950]
	local first = entry.firstAt
	Check("[QC2CAP] première capture : date gardée (espèce et ménagerie)", first ~= nil and first == entry.at
		and capture.firstAt == first)
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	Mock:Advance(500)
	Q.SeeKill(4950, { name = "Biche", spawn = "B2" })
	Q.Roll(0.97)
	NS:CaptureThrow()
	Q.Settle()
	Check("[QC2CAP] recapture meilleure : at bouge, la première date non", entry.stars == 3 and entry.at ~= first
		and entry.firstAt == first and capture.firstAt == first and NS:CaptureEarliestAt() == first,
		tostring(entry.stars) .. " " .. tostring(entry.at) .. " " .. tostring(first) .. " " .. tostring(entry.firstAt) .. " " .. tostring(capture.firstAt))
end

-- 8. Textes, réglage ----------------------------------------------------------------------------------------
do
	Say("-- qc2 capture : textes")
	local missing = {}
	for key in pairs(NS.CAPTURE_QUEUE_STRINGS.fr) do if not NS.CAPTURE_QUEUE_STRINGS.en[key] then missing[#missing + 1] = key end end
	for key in pairs(NS.CAPTURE_QUEUE_STRINGS.en) do if not NS.CAPTURE_QUEUE_STRINGS.fr[key] then missing[#missing + 1] = key end end
	Check("[QC2CAP] textes fr et en", #missing == 0, table.concat(missing, ", "))
	Check("[QC2CAP] réglage : la description parle du filet, plus de fenêtre",
		NS.CAPTURE_STRINGS.fr.OPT_DAILY_CAPTURE_DESC:find("filet", 1, true) ~= nil
		and NS.CAPTURE_STRINGS.en.OPT_DAILY_CAPTURE_DESC:find("net", 1, true) ~= nil)
end

Q.Done()
