-- Astuces de découverte du compagnon (QuestCompanion 3.1.0, Discovery.lua) :
-- un catalogue d'astuces sur les fonctions de l'addon, dites sur le canal
-- des astuces (CompanionTryTip), au plus une toutes les 20 min, jamais en
-- combat, en instance, pendant une capture ou une visite, pas dans les 10
-- premières minutes du jour ; une fois par compte ; jamais celle d'une
-- fonction déjà utilisée ; clic sur la bulle : la page ; réglage et
-- /qc astuces on|off|reset ; Ready2Quest seulement s'il n'est pas là.
local Check, ResetWorld, Mock = T.Check, T.ResetWorld, T.Mock
local NS = T.QNS

local X = { saved = {} }
local GLOBALS = { "InCombatLockdown", "IsInInstance", "Ready2Quest", "IsInGuild", "IsInGroup", "IsInRaid" }
for _, name in ipairs(GLOBALS) do X.saved[name] = rawget(_G, name) end
X.savedFns = { TourActive = NS.TourActive, CapturePrepShown = NS.CapturePrepShown, AddonsR2QStatus = NS.AddonsR2QStatus,
	WinterVeilSeason = NS.WinterVeilSeason }

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

function X.Reset()
	ResetWorld()
	for _, frame in ipairs({ NS.companionFrame, NS.companionBubble, NS.companionHover, NS.journalFrame }) do
		if frame then frame:Hide() end
	end
	NS.companionFrame, NS.companionBubble, NS.companionHover = nil, nil, nil
	NS.companionSession, NS.companionLastBubble, NS.companionBubbleKey, NS.companionBubbleText = nil, nil, nil, nil
	NS.companionBubbleUntil, NS.companionRT, NS.companionBubblePrio, NS.companionBubbleLine = nil, nil, nil, nil
	NS.discoveryLastAt, NS.discoveryBubble = nil, nil
	Mock.world.level, Mock.world.mapID = 11, 20
	X.combat, X.inside = false, false
	_G.InCombatLockdown = function() return X.combat == true end
	_G.IsInInstance = function() return X.inside == true, X.inside and "party" or "none" end
	_G.IsInGuild = function() return false end
	_G.IsInGroup = function() return false end
	_G.IsInRaid = function() return false end
	NS.TourActive, NS.CapturePrepShown = X.savedFns.TourActive, X.savedFns.CapturePrepShown
	NS.AddonsR2QStatus, NS.WinterVeilSeason = X.savedFns.AddonsR2QStatus, function() return false end
	NS:CompanionData().tutoDone = true
	NS.companionSession = nil
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
end
function X.Restore()
	for _, name in ipairs(GLOBALS) do _G[name] = X.saved[name] end
	for name, fn in pairs(X.savedFns) do NS[name] = fn end
end
-- Le temps passe sans faire tourner les horloges (pas d'autre bulle)
function X.Wait(seconds) Mock.now = Mock.now + seconds end
function X.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio = nil, nil, nil
	if NS.companionRT then NS.companionRT.cool, NS.companionRT.seq, NS.companionRT.tipAt = {}, nil, 0 end
end
-- Une tentative d'astuce : la ligne dite, ou nil
function X.Tip()
	X.Quiet()
	local before = NS.companionBubbleLine
	if NS:CompanionTryTip(true) and NS.companionBubbleLine ~= before or NS.companionBubbleKey == "TIP" then
		return NS.companionBubbleLine
	end
	return nil
end
function X.Disc() local line = X.Tip(); return line and line:match("^DISC_(.+)$") or nil end
-- Tout vu sauf `keep`
function X.OnlyLeft(keep)
	local seen = NS:DiscoveryData().seen
	for _, tip in ipairs(NS.DISCOVERY_TIPS) do seen[tip.id] = tip.id ~= keep or nil end
end

-- 1. Le catalogue ----------------------------------------------------------------------
do
	local s = Steps()
	local tips, strings = NS.DISCOVERY_TIPS, NS.DISCOVERY_STRINGS
	s.ok("25 à 35 astuces", #tips >= 25 and #tips <= 35, #tips)
	local ids, bad, long, vous, glyph = {}, {}, {}, {}, {}
	for _, tip in ipairs(tips) do
		if ids[tip.id] then bad[#bad + 1] = "doublon " .. tip.id end
		ids[tip.id] = true
		if type(tip.learned) ~= "function" then bad[#bad + 1] = "learned " .. tip.id end
		for _, lang in ipairs({ "fr", "en" }) do
			local text = strings[lang][tip.line]
			if type(text) ~= "string" or text == "" then bad[#bad + 1] = lang .. ":" .. tip.id
			else
				if #text > NS.DISCOVERY_MAX_BYTES then long[#long + 1] = lang .. ":" .. tip.id .. "=" .. #text end
				if text:find("\226\152\133", 1, true) or text:find("\226\152\134", 1, true) then glyph[#glyph + 1] = tip.id end
				if lang == "fr" and (text:find("[Vv]ous") or text:find("[Vv]otre")) then vous[#vous + 1] = tip.id end
				local ok = pcall(string.format, text)
				if not ok then bad[#bad + 1] = "format " .. lang .. ":" .. tip.id end
			end
		end
	end
	for key in pairs(strings.fr) do if not strings.en[key] then bad[#bad + 1] = "en manque " .. key end end
	for key in pairs(strings.en) do if not strings.fr[key] then bad[#bad + 1] = "fr manque " .. key end end
	s.ok("ids uniques, learned, FR et EN, formatables", #bad == 0, table.concat(bad, ","))
	s.ok("une bulle (≤ 200 octets)", #long == 0, table.concat(long, ","))
	s.ok("sans ★", #glyph == 0, table.concat(glyph, ","))
	s.ok("tutoiement", #vous == 0, table.concat(vous, ","))
	-- les commandes et gestes nommés existent
	local cmds = NS.EXTRA_COMMANDS
	s.ok("commandes citées : astuces, juke, titre, fiche, echange, filet, style, noel, tuto",
		cmds.astuces and cmds.juke and cmds.titre and cmds.fiche and cmds.echange and cmds.filet and cmds.style and cmds.noel and cmds.tuto)
	s.ok("pages ouvertes : carnet, Réserve, Échoppe, juke-box, Créatures, fiche, menu, allure",
		NS.ToggleJournal and NS.OpenReserve and NS.OpenShop and NS.OpenJournalJuke and NS.OpenMenagerieTodo and NS.TrainerOpen
		and NS.CompanionMenuShow and NS.AllureOpen and NS.TreatMenuToggle)
	s.check("[DISC] catalogue : 25 à 35 astuces, FR/EN, une bulle, sans ★, tutoiement, gestes et commandes qui existent")
end

-- 2. « Appris » : chaque astuce se tait une fois la fonction utilisée ------------------------
do
	local s = Steps()
	X.Reset()
	-- tout est éligible pour ce contrôle
	local eligible = {}
	for _, tip in ipairs(NS.DISCOVERY_TIPS) do eligible[tip.id] = tip.eligible; tip.eligible = nil end
	local before = {}
	for _, tip in ipairs(NS.DISCOVERY_TIPS) do
		if tip.learned(NS) then before[#before + 1] = tip.id end
	end
	s.ok("personnage neuf : rien d'appris", #before == 0, table.concat(before, ","))
	-- de vrais gestes, quand le banc les joue
	NS:CompanionPet()
	NS:CompanionShowHover()
	NS:CompanionOpenJournal()
	NS:CompanionMenuShow(); NS:CompanionMenuHide()
	NS:HuntStart(5)
	for _ = 1, 5 do NS:ToggleJournal(true) end
	NS:SelectJournalKind("guide")
	NS:SelectJournalKind("day")
	NS:SelectJournalKind("progress")
	NS:SelectJournalKind("evolution")
	NS:SelectJournalKind("addons")
	NS:OpenJournalJuke()
	NS:SetUIStyle("sobre")
	NS:TrainerOpen()
	NS:ShareOpen(nil, { kind = "seal", name = "X" }); if NS.shareMenu then NS.shareMenu:Hide() end
	NS:CaptureData().pins[7001] = true
	NS:DB().companionCaptureDirect = true
	NS:DB().companionSize = (NS.COMPANION_SIZE_DEFAULT or 2) + 1
	table.insert(NS:TradeLog(), { tid = "t1" })
	NS:CaptureData().wary = { day = 1, n = { [7001] = 3 } }
	NS:DB().announceGroup = false
	local real = { pet = true, needs = true, journal = true, menu = true, hunt = true, keys = true, guide = true, missions = true,
		chests = true, personality = true, r2q = true, juke = true, style = true, trainer = true, share = true, pins = true,
		direct = true, size = true, trade = true, wary = true, announce = true }
	local missed = {}
	for _, tip in ipairs(NS.DISCOVERY_TIPS) do
		if real[tip.id] and not tip.learned(NS) then missed[#missed + 1] = tip.id end
	end
	s.ok("gestes joués : appris", #missed == 0, table.concat(missed, ","))
	-- les autres : le drapeau posé par leur fonction (enveloppée)
	local FLAG = { look = "look", frame = "frame", pantry = "pantry", aids = "aid", batch = "batch", locate = "locate",
		release = "release", codex = "codex", shop = "shop", titles = "title", guild = "guildFeat", noel = "noel" }
	for id, flag in pairs(FLAG) do NS:DiscoveryUse(flag) end
	local still = {}
	for _, tip in ipairs(NS.DISCOVERY_TIPS) do if not tip.learned(NS) then still[#still + 1] = tip.id end end
	s.ok("chaque astuce a sa condition « appris »", #still == 0, table.concat(still, ","))
	-- les fonctions enveloppées posent bien leur drapeau
	local wrapped = { "CompanionSetAppearance", "CompanionSetStyle", "TreatMenuToggle", "CaptureToggleAid", "CaptureBatch",
		"LocateSpecies", "SpecimenRelease", "SpecimenSetReference", "ShopBuy", "FeatSetTitle", "GuildFeatsEnqueue", "WinterVeilCommand" }
	local lost = {}
	for _, name in ipairs(wrapped) do if type(NS[name]) ~= "function" then lost[#lost + 1] = name end end
	s.ok("fonctions enveloppées présentes", #lost == 0, table.concat(lost, ","))
	X.Reset()
	NS:TreatMenuToggle()
	s.ok("garde-manger ouvert : appris", NS.DISCOVERY_BY_ID.pantry.learned(NS))
	NS:CaptureToggleAid("appat")
	s.ok("aide choisie : appris", NS.DISCOVERY_BY_ID.aids.learned(NS))
	-- le compte, pas le personnage
	s.ok("au compte (QuestCompanionDB.discovery)", _G.QuestCompanionDB.discovery and _G.QuestCompanionDB.discovery.used.pantry == true)
	for _, tip in ipairs(NS.DISCOVERY_TIPS) do tip.eligible = eligible[tip.id] end
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS:HuntStop()
	X.Restore()
	s.check("[DISC] « appris » : rien sur un compte neuf ; chaque astuce se tait une fois sa fonction utilisée (gestes réels ou drapeau)")
end

-- 3. Rythme ---------------------------------------------------------------------------------
do
	local s = Steps()
	X.Reset()
	s.ok("dans les 10 premières minutes du jour : astuce ordinaire", X.Disc() == nil and NS.companionBubbleKey == "TIP")
	X.Wait(NS.DISCOVERY_FIRST + 1)
	local first = X.Disc()
	s.ok("après 10 min : une astuce de découverte", first ~= nil, NS.companionBubbleLine)
	X.Wait(300)
	s.ok("5 min après : pas de seconde (astuce ordinaire)", X.Disc() == nil and NS.companionBubbleKey == "TIP")
	X.Wait(NS.DISCOVERY_GAP)
	local second = X.Disc()
	s.ok("20 min après : la suivante, une autre", second ~= nil and second ~= first, tostring(second))
	X.Wait(NS.DISCOVERY_GAP + 1)
	X.combat = true
	X.Quiet()
	s.ok("en combat : rien", NS:CompanionTryTip(true) == false)
	X.combat = false
	X.inside = true
	s.ok("en instance : pas de découverte", NS:DiscoveryPick() == nil and NS:DiscoveryBusy() == "instance")
	X.inside = false
	NS.TourActive = function() return true end
	s.ok("visite guidée : pas de découverte", NS:DiscoveryPick() == nil)
	NS.TourActive = X.savedFns.TourActive
	NS.CapturePrepShown = function() return true end
	s.ok("carte de capture : pas de découverte", NS:DiscoveryPick() == nil)
	NS.CapturePrepShown = X.savedFns.CapturePrepShown
	s.ok("libre : de nouveau", NS:DiscoveryPick() ~= nil)
	-- jour suivant : de nouveau 10 min d'attente
	X.Wait(86400)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	NS.discoveryLastAt = nil
	s.ok("nouveau jour : 10 min d'abord", NS:DiscoveryPick() == nil)
	X.Wait(NS.DISCOVERY_FIRST + 1)
	s.ok("puis de nouveau", NS:DiscoveryPick() ~= nil)
	X.Restore()
	s.check("[DISC] rythme : pas avant 10 min dans la journée, une par 20 min, jamais en combat, instance, capture ni visite")
end

-- 4. Une fois par compte, puis plus rien ; réglage ; reset ------------------------------------
do
	local s = Steps()
	X.Reset()
	X.Wait(NS.DISCOVERY_FIRST + 1)
	local said, dup = {}, {}
	for _ = 1, 60 do
		NS.discoveryLastAt = nil
		local id = X.Disc()
		if id then
			if said[id] then dup[#dup + 1] = id end
			said[id] = true
		end
	end
	local n = 0
	for _ in pairs(said) do n = n + 1 end
	s.ok("chacune une fois", #dup == 0 and n >= 8, n .. " " .. table.concat(dup, ","))
	NS.discoveryLastAt = nil
	s.ok("toutes vues (les éligibles) : plus rien", NS:DiscoveryPick() == nil)
	-- un autre personnage du compte : déjà vues
	NS:CharData().companion = nil
	s.ok("autre personnage : toujours vues (au compte)", NS:DiscoveryPick() == nil)
	-- reset
	Mock:Reset()
	NS:DiscoveryCommand("reset")
	s.ok("/qc astuces reset : elles reviennent", NS:DiscoveryPick() ~= nil and Mock:Output():find("redites", 1, true) ~= nil)
	-- réglage coupé
	NS:DiscoveryCommand("off")
	s.ok("/qc astuces off : plus rien, réglage coupé", NS:DB().companionDiscovery == false and NS:DiscoveryPick() == nil
		and X.Disc() == nil)
	NS:DiscoveryCommand("on")
	NS.discoveryLastAt = nil
	s.ok("/qc astuces on : de retour", NS:DiscoveryPick() ~= nil)
	local row
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		for _, r in ipairs(page.rows or {}) do if r.key == "companionDiscovery" then row = r end end
	end
	X.Reset()
	s.ok("réglage dans les options, actif par défaut", row ~= nil and NS:DB().companionDiscovery == true)
	X.Restore()
	s.check("[DISC] une fois par compte puis plus rien ; réglage et /qc astuces on|off|reset")
end

-- 5. Clic sur la bulle : la page ---------------------------------------------------------------
do
	local s = Steps()
	local function Click(id)
		X.Reset()
		X.Wait(NS.DISCOVERY_FIRST + 1)
		X.OnlyLeft(id)
		local said = X.Disc()
		local bubble = NS.companionBubble
		local clickable = bubble and bubble.mouseEnabled == true
		if bubble and bubble.scripts.OnMouseUp then bubble.scripts.OnMouseUp(bubble, "LeftButton") end
		return said, clickable
	end
	local said, clickable = Click("juke")
	s.ok("juke-box : bulle cliquable, la page", said == "juke" and clickable and NS.journalFrame and NS.journalFrame:IsShown()
		and NS.journalFrame.kind == "juke", NS.journalFrame and NS.journalFrame.kind)
	s.ok("bulle fermée après le clic", not NS.companionBubble:IsShown())
	said = Click("guide")
	s.ok("Guide : la page", said == "guide" and NS.journalFrame.kind == "guide", NS.journalFrame.kind)
	X.Reset()
	NS:PaillettesAdd(20, "test")
	X.Wait(NS.DISCOVERY_FIRST + 1)
	X.OnlyLeft("shop")
	said = X.Disc()
	NS.companionBubble.scripts.OnMouseUp(NS.companionBubble, "LeftButton")
	s.ok("Échoppe : l'onglet", said == "shop" and NS.journalFrame.kind == "shop", NS.journalFrame.kind)
	-- une astuce sans page : la bulle reste transparente ; une bulle ordinaire aussi
	said, clickable = Click("pet")
	s.ok("sans page : pas cliquable", said == "pet" and not clickable)
	NS.discoveryLastAt = Mock.now
	X.Tip()
	s.ok("astuce ordinaire : pas cliquable, le clic ne fait rien", NS.companionBubbleKey == "TIP" and NS.companionBubble.mouseEnabled == false
		and NS:DiscoveryClick() == false)
	if NS.journalFrame then NS.journalFrame:Hide() end
	X.Restore()
	s.check("[DISC] clic sur la bulle : juke-box, Guide, Échoppe ; une bulle sans page (ou ordinaire) n'est pas cliquable")
end

-- 6. Ready2Quest : seulement s'il n'est pas là, une fois ---------------------------------------
do
	local s = Steps()
	X.Reset()
	X.Wait(NS.DISCOVERY_FIRST + 1)
	X.OnlyLeft("r2q")
	s.ok("Ready2Quest chargé : jamais", NS:DiscoveryPick() == nil)
	_G.Ready2Quest = nil
	NS.AddonsR2QStatus = function() return "missing" end
	s.ok("absent : l'astuce", X.Disc() == "r2q")
	X.Wait(NS.DISCOVERY_GAP + 1)
	NS.discoveryLastAt = nil
	s.ok("une seule fois", NS:DiscoveryPick() == nil)
	X.Restore()
	s.check("[DISC] Ready2Quest : seulement s'il est absent, et une seule fois")
end
