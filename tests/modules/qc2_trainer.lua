-- QuestCompanion 2.0, lot 5 : fiche de dresseur (TrainerCard.lua).
-- Protocole (préfixe QCTrainer, messages R/C/N/H/A/P versionnés, fiche
-- encodée, morceaux sous 255 octets) : sérialisation et texte piégé, version
-- future, messages d'addon simulés entre deux « joueurs » (ce que l'un envoie
-- est rejoué chez l'autre), débit sortant et entrant, combat, refus, absence
-- de réponse, morceaux incohérents, usurpation, découverte (groupe, guilde,
-- cible), cache des détenteurs (clés converties), menu du clic droit,
-- infobulle, fenêtre et /qc fiche.
local Check, Say, ResetWorld, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local TC = { saved = {} }
local GLOBALS = { "C_ChatInfo", "Menu", "UnitName", "UnitFullName", "UnitIsPlayer", "UnitIsFriend", "UnitFactionGroup",
	"InCombatLockdown", "UnitAffectingCombat", "IsInGroup", "IsInRaid", "IsInGuild", "issecretvalue",
	"GetPlayerInfoByGUID", "time", "GetNormalizedRealmName" }
for _, name in ipairs(GLOBALS) do TC.saved[name] = rawget(_G, name) end
TC.saved.GetUnit = GameTooltip.GetUnit
local LOT_APIS = { "TrainerTitle", "MenagerieSeals", "CompanionEffects", "CaptureStars", "JournalContinentOf" }
for _, name in ipairs(LOT_APIS) do TC.saved["ns." .. name] = rawget(QNS, name) end
local SECRET = {}

-- le client : messages d'addon envoyés (prefix, texte, canal, cible)
function TC.Reset()
	ResetWorld()
	QNS:TrainerResetSession()
	if QNS.trainerFrame then QNS.trainerFrame:Hide() end
	TC.sent, TC.prefixes = {}, {}
	TC.now = 1800000000
	TC.combat, TC.lockdown = false, false
	TC.units = {}      -- unité -> { name, realm, player, faction }
	TC.group, TC.raid, TC.guild = false, false, false
	_G.time = function() return TC.now end
	_G.C_ChatInfo = {
		RegisterAddonMessagePrefix = function(prefix) TC.prefixes[#TC.prefixes + 1] = prefix; return 0 end,
		SendAddonMessage = function(prefix, text, channel, target)
			TC.sent[#TC.sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
			return 0
		end,
		InChatMessagingLockdown = function() return TC.lockdown end,
	}
	_G.InCombatLockdown = function() return TC.combat end
	_G.UnitAffectingCombat = function() return TC.combat end
	_G.UnitName = function(unit)
		if unit == "player" then return "Testeur" end
		local u = TC.units[unit]
		if u then return u.name, u.realm end
		return nil
	end
	_G.UnitFullName = nil
	_G.UnitIsPlayer = function(unit) local u = TC.units[unit]; return u and u.player ~= false or false end
	_G.UnitIsFriend = function() return true end
	_G.UnitFactionGroup = function(unit)
		if unit == "player" then return "Alliance" end
		local u = TC.units[unit]
		return u and u.faction or "Alliance"
	end
	_G.IsInGroup = function() return TC.group end
	_G.IsInRaid = function() return TC.raid end
	_G.IsInGuild = function() return TC.guild end
	_G.GetNormalizedRealmName = function() return "Royaume" end
end

function TC.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = TC.saved[name] end
	GameTooltip.GetUnit = TC.saved.GetUnit
	for _, name in ipairs(LOT_APIS) do QNS[name] = TC.saved["ns." .. name] end
	if QNS.trainerFrame then QNS.trainerFrame:Hide() end
	QNS:TrainerResetSession()
	ResetWorld()
end

-- envoie tout ce que le débit permet (temps large : le seau est plein)
function TC.Flush()
	local before = #TC.sent
	for _ = 1, 20 do QNS:TrainerPump(10) end
	return #TC.sent - before
end

-- rejoue des messages envoyés chez « nous », comme venant de `sender`
function TC.Deliver(list, sender, channel)
	for _, msg in ipairs(list) do QNS:TrainerOnAddonMessage(msg.prefix, msg.text, channel or msg.channel, sender) end
end

function TC.Take()
	local list = TC.sent
	TC.sent = {}
	return list
end

function TC.Kinds(list)
	local kinds = {}
	for _, msg in ipairs(list or TC.sent) do kinds[#kinds + 1] = msg.text:match("^([^~]*)") end
	return table.concat(kinds, ",")
end

function TC.Captures()
	local capture = QNS:CaptureData()
	capture.creatures[7001] = { name = "Kodo", class = "normal", zoneID = 1413, at = TC.now - 86400 * 3, normal = true }
	capture.creatures[7002] = { name = "Griffe;Grise=|cffff0000", class = "rare", zoneID = 1413, at = TC.now - 86400,
		normal = true, shiny = true, shinyAt = TC.now - 3600, type = "Bête" }
	capture.creatures[7003] = { name = "Garde", class = "elite", zoneID = 1413, at = TC.now - 86400 * 10, normal = true }
	capture.count = 3
	QNS.captureAppCache = nil
end

-- 1. Sérialisation ------------------------------------------------------------------------------
do
	Say("-- fiche de dresseur : sérialisation")
	TC.Reset()
	Check("[TRN] préfixe enregistré auprès du client", QNS:TrainerRegisterPrefix() and TC.prefixes[1] == "QCTrainer"
		and #QNS.TRAINER_PREFIX <= 16)
	local text = QNS.TrainerEncode({ n = "A;b=c,d~e|f:g%h", l = { "x,y", "z" }, k = 3 })
	local back = QNS.TrainerDecode(text)
	Check("[TRN] encodage : aucun caractère réservé en clair, aller-retour d'un texte piégé", not text:find("[|~]")
		and select(2, text:gsub(";", "")) == 2 and QNS.TrainerUnescape(back.n) == "A;b=c,d~e|f:g%h", text)
	local card = QNS:TrainerParseCard("p=9;n=Bob-Royaume;zz=inconnu;sp=12;st=40;futur=1;v2=7002,1,3,rare,beast,Griffe;b=ek%3A2,xx%3A1")
	Check("[TRN] décodage tolérant (morceaux sans « = ») ; version plus récente et champs inconnus : lus quand même",
		next(QNS.TrainerDecode("n'importe;quoi")) == nil and card.proto == 9 and card.name == "Bob-Royaume"
		and card.species == 12 and card.total == 40 and card.showcase[2] and card.showcase[2].npc == 7002
		and card.showcase[2].shiny and card.showcase[2].stars == 3 and card.badges.ek == 2)
	local hostile = QNS:TrainerParseCard("n=" .. QNS.TrainerEscape("|cffff0000Méchant|r|Tinterface\\x:0|t")
		.. ";cl=" .. string.rep("x", 400) .. ";cy=99;cr=dieu")
	Check("[TRN] texte reçu désarmé (ni couleur ni icône), valeurs bornées (nom long, étoiles, rang inconnu)",
		hostile.name:find("||c", 1, true) ~= nil and not hostile.name:gsub("||", ""):find("|", 1, true)
		and #hostile.companion.name <= 48 and hostile.companion.stars == 3 and hostile.companion.class == nil, hostile.name)
	Check("[TRN] fiche vide : sans erreur", pcall(QNS.TrainerParseCard, QNS, "") and pcall(QNS.TrainerParseCard, QNS, nil))
end

-- 2. Ma fiche -----------------------------------------------------------------------------------
do
	Say("-- fiche de dresseur : ma fiche")
	TC.Reset()
	TC.Captures()
	Check("[TRN] vitrine refusée : créature non capturée, brillante pas capturée, emplacement hors limites",
		not QNS:TrainerSetShowcase(1, "cap:9999") and not QNS:TrainerSetShowcase(1, "cap:7001:s")
		and not QNS:TrainerSetShowcase(4, "cap:7001"))
	QNS:TrainerSetShowcase(1, "cap:7002:s")
	QNS:TrainerSetShowcase(3, "cap:7003")
	QNS:TrainerSetShowcase(2, "cap:7003")
	local showcase = QNS:TrainerShowcase()
	Check("[TRN] vitrine : une créature n'occupe qu'un emplacement", showcase[2] == "cap:7003" and not showcase[3])
	local card = QNS:TrainerOwnCard()
	Check("[TRN] ma fiche : nom avec royaume, première capture la plus ancienne, espèces / total, brillantes",
		card.name == "Testeur-Royaume" and card.first == TC.now - 86400 * 10 and card.species == 3 and card.total >= 3
		and card.shinies == 1 and (card.shinySeen or 0) >= 1, tostring(card.species) .. "/" .. tostring(card.total))
	Check("[TRN] vitrine : brillante et élite", card.showcase[1].npc == 7002 and card.showcase[1].shiny
		and card.showcase[1].typeKey == "beast" and card.showcase[2].npc == 7003 and card.showcase[3] == nil)
	-- version assemblée (lots 1 à 3 présents) : 3 espèces, pas encore de titre
	-- (le premier vient à 10), aucun sceau, étoiles de la vitrine lues (1 par défaut)
	Check("[TRN] pas encore de titre ni de sceau, étoiles lues ; compagnon : la mascotte, son modèle", card.title == nil
		and (card.seals or 0) == 0 and card.showcase[2].stars == 1 and card.companion and card.companion.mascot
		and card.companion.display ~= nil and card.companion.name == QNS:CompanionName(),
		tostring(card.title) .. " / " .. tostring(card.seals) .. " / " .. tostring(card.showcase[2].stars))
	-- les lots 1, 2 et 3 présents
	QNS.TrainerTitle = function() return "Maître des bêtes" end
	QNS.MenagerieSeals = function() return { 1413, 1411, 1429 } end
	QNS.JournalContinentOf = function(_, zoneID) return zoneID == 1429 and "ek" or "ka" end
	QNS.CaptureStars = function(_, npc, shiny) return shiny and 3 or 2 end
	QNS.CompanionEffects = function() return { typeKey = "beast", strength = 2.5, active = false,
		hunt = { id = "spot", value = 0.25, label = "repère les Bêtes" },
		comfort = { id = "decay_hunger", value = 0.2, label = "faim -20 %" } } end
	QNS:CompanionData().appearance = "cap:7002:s"
	card = QNS:TrainerOwnCard()
	Check("[TRN] titre, sceaux, badges par continent ; étoiles de la vitrine et du compagnon", card.title == "Maître des bêtes"
		and card.seals == 3 and card.badges.ka == 2 and card.badges.ek == 1 and card.showcase[1].stars == 3
		and card.showcase[2].stars == 2 and card.companion.stars == 3)
	Check("[TRN] compagnon capturé (brillant, rare, npcID) et ses effets", card.companion.hunt == "repère les Bêtes"
		and card.companion.comfort == "faim -20 %" and card.companion.strength == 2.5 and card.companion.active == false
		and card.companion.npc == 7002 and card.companion.shiny and card.companion.class == "rare" and not card.companion.mascot)
	local text = QNS:TrainerSerializeCard(card)
	local back = QNS:TrainerParseCard(text)
	-- effets : envoyés en identifiant + valeur, libellé refait dans la langue du destinataire
	Check("[TRN] aller-retour de la fiche entière", back.name == card.name and back.title == card.title and back.first == card.first
		and back.species == card.species and back.seals == 3 and back.badges.ka == 2 and back.companion.npc == 7002
		and back.companion.shiny and back.companion.hunt == QNS:F("EFF_spot", 25)
		and back.companion.comfort == QNS:F("EFF_decay_hunger", 20) and back.companion.active == false
		and back.showcase[1].npc == 7002 and back.showcase[2].stars == 2)
	Check("[TRN] nom piégé de la vitrine : affiché tel quel, sans code", back.showcase[1].name == "Griffe;Grise=||cffff0000",
		back.showcase[1].name)
	-- découpage : chaque message tient dans 255 octets
	local saved = QNS.TRAINER_CHUNK
	QNS.TRAINER_CHUNK = 60
	local chunks = QNS:TrainerChunks(text, 7)
	local fits = true
	for _, chunk in ipairs(chunks) do if #chunk > 255 then fits = false end end
	Check("[TRN] fiche longue : plusieurs morceaux, chacun sous 255 octets", #chunks > 1 and fits, #chunks)
	QNS.TRAINER_CHUNK = saved
	for _, name in ipairs(LOT_APIS) do QNS[name] = TC.saved["ns." .. name] end
	QNS:CompanionData().appearance = QNS.COMPANION_APPEARANCES[1].id
end

-- 3. Deux joueurs : demande, fiche, débit -------------------------------------------------------
do
	Say("-- fiche de dresseur : échange entre deux joueurs")
	TC.Reset()
	TC.Captures()
	QNS:TrainerSetShowcase(1, "cap:7001")
	-- « Bob » nous demande notre fiche
	QNS.TRAINER_CHUNK = 80
	QNS:TrainerOnAddonMessage("QCTrainer", "R~1", "WHISPER", "Bob-Royaume")
	local holder = QNS:TrainerIsHolder("Bob")
	TC.Flush()
	local answer = TC.Take()
	Check("[TRN] demande reçue : Bob détenteur, la fiche en morceaux C, en chuchotement à Bob", holder and #answer > 1
		and TC.Kinds(answer):find("^C") ~= nil and answer[1].channel == "WHISPER" and answer[1].target == "Bob-Royaume"
		and answer[1].prefix == "QCTrainer", TC.Kinds(answer))
	-- nous demandons la fiche de Bob : la réponse ci-dessus joue la sienne
	QNS:TrainerOpen("Bob")
	TC.Flush()
	local request = TC.Take()
	local f = QNS.trainerFrame
	Check("[TRN] demande envoyée : R en chuchotement, fenêtre en attente", TC.Kinds(request) == "R"
		and request[1].target == "Bob-Royaume" and f:IsShown() and f.state == "pending"
		and f.status.text:find("Bob", 1, true) ~= nil and not f.body:IsShown(), f.state)
	-- morceaux dans le désordre, un doublon
	local shuffled = { answer[#answer], answer[1] }
	for index = 2, #answer - 1 do shuffled[#shuffled + 1] = answer[index] end
	shuffled[#shuffled + 1] = answer[1]
	TC.Deliver(shuffled, "Bob-Royaume")
	local card = QNS:TrainerCard("Bob")
	Check("[TRN] fiche reçue, recollée dans le désordre (doublon compris)", card and card.name == "Testeur-Royaume"
		and card.showcase[1] and card.showcase[1].npc == 7001 and QNS:TrainerStatus("Bob") == "ok")
	-- (la fiche rejouée est la nôtre : son champ « n » dit Testeur, le titre dit qui l'a vraiment envoyée)
	Check("[TRN] fenêtre : la fiche (chiffres, vitrine), sans réglage de partage", f.state == "card" and f.body:IsShown()
		and f.header.title.text == "Bob" and not f.shareToggle:IsShown() and f.retryButton:IsShown()
		and not f.tiles[1].picker:IsShown() and f.lines[2].text:find("3", 1, true) ~= nil and f.tiles[1].name.text == "Kodo"
		and f.tiles[1].item and f.tiles[1].item.npc == 7001, f.lines[2].text .. " / " .. tostring(f.tiles[1].name.text))
	-- une seconde demande trop tôt : pas de nouvel envoi (débit par joueur)
	QNS:TrainerOnAddonMessage("QCTrainer", "R~1", "WHISPER", "Bob-Royaume")
	Check("[TRN] demandes répétées : une fiche toutes les 10 s au plus", TC.Flush() == 0)
	-- limite de débit : le seau se vide, puis un message par seconde
	QNS:TrainerResetSession()
	for index = 1, 10 do QNS:TrainerSend("P", "WHISPER", "Joueur" .. index .. "-Royaume") end
	local burst = QNS:TrainerPump(0) == 6
	local perSecond = QNS:TrainerPump(1) == 1 and QNS:TrainerPump(0.2) == 0
	Mock:Advance(1)
	Check("[TRN] débit : 6 d'affilée au plus, puis un par seconde ; l'horloge de l'addon vide la file", burst and perSecond
		and #TC.sent == 8, #TC.sent)
	-- combat, verrou de messagerie : rien ne part, la file attend
	TC.combat = true
	local combat = QNS:TrainerPump(10) == 0
	TC.combat, TC.lockdown = false, true
	local lockdown = QNS:TrainerPump(10) == 0
	TC.lockdown = false
	Check("[TRN] en combat, verrou de messagerie (rencontre) : rien ; ensuite la file repart", combat and lockdown
		and QNS:TrainerPump(10) == 2)
	Check("[TRN] message trop long : refusé", not QNS:TrainerSend("Z", "WHISPER", "Bob-Royaume", string.rep("x", 300)))
	QNS.TRAINER_CHUNK = 200
	f:Hide()
end

-- 4. Refus, absence de réponse ------------------------------------------------------------------
do
	Say("-- fiche de dresseur : refus et silence")
	TC.Reset()
	QNS:DB().trainerShare = false
	QNS:TrainerOnAddonMessage("QCTrainer", "R~1", "WHISPER", "Carl-Royaume")
	TC.Flush()
	local refusal = TC.Kinds(TC.Take()) == "N"
	QNS:TrainerOnAddonMessage("QCTrainer", "H~1", "PARTY", "Carl-Royaume")
	QNS:TrainerOnAddonMessage("QCTrainer", "P~1", "WHISPER", "Carl-Royaume")
	TC.Flush()
	Check("[TRN] partage coupé : la demande reçoit un refus N, ni accusé, ni annonce", refusal and #TC.sent == 0
		and not QNS:TrainerAnnounce("GUILD"))
	QNS:DB().trainerShare = true
	QNS:TrainerOpen("Dave-Autre Royaume")
	TC.Flush()
	local request = TC.Take()
	Check("[TRN] autre royaume : nom sans espace", request[1] and request[1].target == "Dave-AutreRoyaume", request[1] and request[1].target)
	QNS:TrainerOnAddonMessage("QCTrainer", "N~1", "WHISPER", "Dave-AutreRoyaume")
	local f = QNS.trainerFrame
	Check("[TRN] refus : la fenêtre le dit", f.state == "refused" and f.status.text:find("ne partage pas", 1, true) ~= nil
		and f.header.title.text == "Dave-AutreRoyaume", f.status.text)
	QNS:TrainerOpen("Eve")
	Mock.now = Mock.now + 5
	QNS:TrainerPump(0)
	local pending = f.state == "pending"
	Mock.now = Mock.now + 8
	QNS:TrainerPump(0)
	Check("[TRN] 5 s sans réponse : en attente ; plus : « Pas de fiche reçue »", pending and f.state == "none"
		and f.status.text:find("Pas de fiche reçue", 1, true) ~= nil and f.statusHint.text ~= "", f.status.text)
	f.retryButton:Click()
	Check("[TRN] Redemander : nouvelle demande en attente", f.state == "pending" and TC.Kinds(TC.Take()) == "R")
	f:Hide()
end

-- 5. Découverte ---------------------------------------------------------------------------------
do
	Say("-- fiche de dresseur : découverte")
	TC.Reset()
	-- annonce d'un autre : détenteur noté, accusé une fois
	QNS:TrainerOnAddonMessage("QCTrainer", "H~1", "PARTY", "Fay-Royaume")
	QNS:TrainerOnAddonMessage("QCTrainer", "H~1", "PARTY", "Fay-Royaume")
	TC.Flush()
	local sent = TC.Take()
	Check("[TRN] annonce reçue : détenteur, un seul accusé en chuchotement", QNS:TrainerIsHolder("Fay-Royaume")
		and TC.Kinds(sent) == "A" and sent[1].channel == "WHISPER" and sent[1].target == "Fay-Royaume")
	QNS:TrainerOnAddonMessage("QCTrainer", "A~1", "WHISPER", "Gus-Royaume")
	TC.Flush()
	Check("[TRN] accusé reçu : détenteur, pas de réponse (pas de ping-pong)", QNS:TrainerIsHolder("Gus") and #TC.sent == 0)
	-- messages d'ailleurs ou illisibles
	QNS:TrainerOnAddonMessage("AutreAddon", "H~1", "PARTY", "Hal-Royaume")
	QNS:TrainerOnAddonMessage("QCTrainer", "bonjour", "PARTY", "Ivy-Royaume")
	QNS:TrainerOnAddonMessage("QCTrainer", "H~1", "PARTY", "Testeur-Royaume")
	QNS:TrainerOnAddonMessage("QCTrainer", "H~1", "PARTY", SECRET)
	Check("[TRN] autre préfixe, texte illisible, soi-même, expéditeur secret : ignorés", not QNS:TrainerIsHolder("Hal")
		and not QNS:TrainerIsHolder("Ivy") and next(QNS:TrainerHolders(), nil) ~= nil and #TC.sent == 0)
	QNS:TrainerOnAddonMessage("QCTrainer", "Z~3~nouveau", "WHISPER", "Jo-Royaume")
	TC.Flush()
	Check("[TRN] type inconnu (version future) : détenteur noté, rien d'autre", QNS:TrainerIsHolder("Jo") and #TC.sent == 0)
	-- entrée en groupe, en raid, guilde
	TC.group = true
	QNS:TrainerOnEvent("GROUP_ROSTER_UPDATE")
	QNS:TrainerOnEvent("GROUP_ROSTER_UPDATE")
	TC.Flush()
	sent = TC.Take()
	local party = TC.Kinds(sent) == "H" and sent[1].channel == "PARTY"
	TC.raid = true
	QNS:TrainerOnEvent("GROUP_ROSTER_UPDATE")
	TC.guild = true
	QNS:TrainerOnEvent("PLAYER_GUILD_UPDATE")
	TC.Flush()
	sent = TC.Take()
	Check("[TRN] annonces H : une à l'entrée en groupe, une en raid, une à la guilde", party and TC.Kinds(sent) == "H,H"
		and sent[1].channel == "RAID" and sent[2].channel == "GUILD")
	QNS:TrainerOnEvent("PLAYER_GUILD_UPDATE")
	Check("[TRN] guilde : pas deux annonces dans la minute", TC.Flush() == 0)
	-- cible : une sonde par joueur et par session, hors combat
	TC.units.target = { name = "Kim", realm = nil }
	QNS:TrainerOnEvent("PLAYER_TARGET_CHANGED")
	QNS:TrainerOnEvent("PLAYER_TARGET_CHANGED")
	TC.Flush()
	sent = TC.Take()
	Check("[TRN] cible un joueur : une sonde silencieuse, une seule", TC.Kinds(sent) == "P" and sent[1].channel == "WHISPER"
		and sent[1].target == "Kim-Royaume")
	local probed = {}
	TC.units.target = { name = "Lou" }
	TC.combat = true
	if QNS:TrainerOnTarget("target") then probed[#probed + 1] = "combat" end
	TC.combat = false
	TC.units.target = { name = "Max", faction = "Horde" }
	if QNS:TrainerOnTarget("target") then probed[#probed + 1] = "autre faction" end
	TC.units.target = { name = "Ned", player = false }
	if QNS:TrainerOnTarget("target") then probed[#probed + 1] = "PNJ" end
	TC.units.target = { name = SECRET }
	_G.issecretvalue = function(v) return v == SECRET end
	local ok, res = pcall(QNS.TrainerOnTarget, QNS, "target")
	if not ok or res then probed[#probed + 1] = "nom secret" end
	_G.issecretvalue = TC.saved.issecretvalue
	Check("[TRN] pas de sonde : en combat, autre faction (chuchotement impossible), PNJ, nom secret (sans erreur)",
		#probed == 0, table.concat(probed, ", "))
	-- cache des détenteurs : oublié au bout de 14 jours
	TC.now = TC.now + 15 * 86400
	Check("[TRN] détenteur pas revu depuis 15 jours : oublié, ménage du cache", not QNS:TrainerIsHolder("Fay")
		and QNS:TrainerPruneHolders() >= 1 and next(QNS:TrainerHolders()) == nil)
	-- sans API de messages : rien, sans erreur
	_G.C_ChatInfo = nil
	Check("[TRN] sans C_ChatInfo : rien n'est envoyé, sans erreur", not QNS:TrainerSend("H", "GUILD")
		and pcall(QNS.TrainerPump, QNS, 1) and not QNS:TrainerRegisterPrefix())
end

-- 6. Menu du clic droit et infobulle ------------------------------------------------------------
do
	Say("-- fiche de dresseur : menu et infobulle")
	TC.Reset()
	local hooks = {}
	_G.Menu = { ModifyMenu = function(tag, fn) hooks[tag] = fn end }
	QNS.trainerState.menuHooked = nil
	local count = QNS:TrainerHookMenus()
	Check("[TRN] menus de joueur (groupe, raid, ami, joueur), accrochés une seule fois", count >= 4 and hooks.MENU_UNIT_PLAYER
		and hooks.MENU_UNIT_PARTY and hooks.MENU_UNIT_RAID_PLAYER and hooks.MENU_UNIT_FRIEND and QNS:TrainerHookMenus() == count)
	local function Root()
		local root = { buttons = {}, dividers = 0 }
		function root:CreateDivider() self.dividers = self.dividers + 1 end
		function root:CreateButton(text, fn) self.buttons[#self.buttons + 1] = { text = text, fn = fn } end
		return root
	end
	local root = Root()
	hooks.MENU_UNIT_PLAYER(nil, root, { name = "Oscar", server = nil })
	Check("[TRN] joueur inconnu : pas d'entrée", #root.buttons == 0)
	QNS:TrainerMarkHolder("Oscar-Royaume")
	root = Root()
	hooks.MENU_UNIT_PARTY(nil, root, { unit = "party1", name = "Oscar" })
	-- 3.0.0 : suivie de « Proposer un échange » (CaptureTrades.lua)
	Check("[TRN] détenteur connu : « Voir sa fiche de dresseur »", #root.buttons == 2
		and root.buttons[1].text == "Voir sa fiche de dresseur" and root.buttons[2].text == "Proposer un échange"
		and root.dividers == 1)
	root.buttons[1].fn()
	Check("[TRN] clic : la fiche demandée et la fenêtre ouverte", QNS.trainerFrame:IsShown()
		and QNS.trainerFrame.viewing == "Oscar-Royaume" and QNS:TrainerStatus("Oscar") == "pending")
	QNS.trainerFrame:Hide()
	TC.units.raid3 = { name = "Oscar" }
	root = Root()
	hooks.MENU_UNIT_RAID_PLAYER(nil, root, { unit = "raid3" })
	Check("[TRN] menu sans nom : lu depuis l'unité ; mal formé : sans erreur", #root.buttons == 2
		and pcall(hooks.MENU_UNIT_PLAYER, nil, {}, nil) and pcall(hooks.MENU_UNIT_PLAYER, nil, nil, { name = "Oscar" }))
	_G.Menu = { ModifyMenu = function() error("menu inconnu") end }
	QNS.trainerState.menuHooked = nil
	local failing = QNS:TrainerHookMenus() == 0
	_G.Menu = nil
	QNS.trainerState.menuHooked = nil
	Check("[TRN] ModifyMenu en erreur, ou sans Menu : rien, sans erreur", failing and QNS:TrainerHookMenus() == 0)
	-- infobulle : une ligne pour les détenteurs
	local listed = false
	for _, fn in ipairs(QNS.UNIT_TOOLTIP_LINES or {}) do if fn then listed = true end end
	TC.units.mouseover = { name = "Oscar" }
	GameTooltip.GetUnit = function() return "Oscar", "mouseover" end
	GameTooltip:ClearLines()
	for _, fn in ipairs(QNS.UNIT_TOOLTIP_LINES) do fn(QNS, GameTooltip, { guid = "Player-1-0000000A" }) end
	Check("[TRN] ligne d'infobulle inscrite auprès de Tooltips.lua : « Dresseur QuestCompanion » pour un détenteur", listed
		and GameTooltip.lines[1] == "Dresseur QuestCompanion", GameTooltip.lines[1])
	TC.units.mouseover = { name = "Paul" }
	GameTooltip.GetUnit = function() return "Paul", "mouseover" end
	GameTooltip:ClearLines()
	Check("[TRN] infobulle d'un inconnu : rien", not QNS:TrainerTooltipLine(GameTooltip, {}) and #GameTooltip.lines == 0)
	-- moteur récent : seulement le GUID
	GameTooltip.GetUnit = function() return nil end
	_G.GetPlayerInfoByGUID = function() return "Mage", "MAGE", "Humain", "Human", 2, "Oscar", "" end
	GameTooltip:ClearLines()
	Check("[TRN] infobulle par le GUID seul", QNS:TrainerTooltipLine(GameTooltip, { guid = "Player-1-0000000A" })
		and GameTooltip.lines[1] == "Dresseur QuestCompanion")
	GameTooltip.GetUnit = function() return SECRET, SECRET end
	_G.issecretvalue = function(v) return v == SECRET end
	_G.GetPlayerInfoByGUID = nil
	GameTooltip:ClearLines()
	Check("[TRN] valeurs secrètes : rien, sans erreur", pcall(QNS.TrainerTooltipLine, QNS, GameTooltip, { guid = SECRET })
		and #GameTooltip.lines == 0)
	_G.issecretvalue = TC.saved.issecretvalue
end

-- 7. Ma fiche depuis le carnet ------------------------------------------------------------------
do
	Say("-- fiche de dresseur : ma fiche dans le carnet")
	TC.Reset()
	TC.Captures()
	if QNS.journalFrame then QNS.journalFrame:Hide() end
	QNS.journalFrame = nil
	QNS:DB().journalTracker = false
	QNS:ToggleJournal(true)
	local j = QNS.journalFrame
	local button = j and j.trainerButton and j.trainerButton:GetText() == "Ma fiche de dresseur"
	j.trainerButton:Click()
	local f = QNS.trainerFrame
	Check("[TRN] carnet : « Ma fiche de dresseur » l'ouvre par-dessus, avec le réglage de partage", button and f:IsShown()
		and f.viewing == nil and f.state == "card" and f.shareToggle:IsShown() and f.shareToggle:GetChecked()
		and not f.retryButton:IsShown() and j:IsShown())
	local picker = f.tiles[1].picker
	Check("[TRN] vitrine : une liste par emplacement, les captures (et la brillante)", picker:IsShown()
		and #picker.options == 5 and picker.value == "none", #picker.options)
	-- modèle 3D : le client sait poser une créature
	for _, tile in ipairs(f.tiles) do
		if tile.model then tile.model.SetCreature = function(self, npc) self.creature = npc end end
	end
	picker:Choose("cap:7002:s")
	Check("[TRN] choix dans la liste : la vitrine change", QNS:TrainerShowcase()[1] == "cap:7002:s"
		and f.tiles[1].model.npc == 7002 and f.tiles[1].name.text:find("brillant", 1, true) ~= nil,
		tostring(QNS:TrainerShowcase()[1]) .. " / " .. tostring(f.tiles[1].model.npc) .. " / " .. tostring(f.tiles[1].name.text))
	f.shareToggle:Click()
	local off = QNS:DB().trainerShare == false and not f.shareToggle:GetChecked()
	f.shareToggle:Click()
	local row
	for _, r in ipairs(QNS.DAILY_OPTION_ROWS or {}) do if r.key == "trainerShare" then row = r end end
	Check("[TRN] interrupteur : partage coupé puis remis ; réglage dans « Au jour le jour »", off and row ~= nil
		and QNS:DB().trainerShare == true)
	f:Hide()
	QNS:HandleCommand("fiche")
	local mine = f:IsShown() and f.viewing == nil
	QNS:HandleCommand("fiche zoe")
	Check("[TRN] /qc fiche : ma fiche ; /qc fiche zoe : demande à Zoe", mine and f.viewing == "Zoe-Royaume"
		and QNS:TrainerStatus("Zoe") == "pending")
	f:Hide()
	j:Hide()
	-- textes : français et anglais, mêmes clés
	local S = QNS.TRAINER_STRINGS
	local same = S ~= nil
	for key in pairs(S and S.fr or {}) do if not S.en[key] then same = false end end
	for key in pairs(S and S.en or {}) do if not S.fr[key] then same = false end end
	Check("[TRN] textes : mêmes clés en français et en anglais", same)
end

-- 8. Relecture : coût, noms, débit entrant, morceaux, usurpation, effets ---------------------------
do
	Say("-- fiche de dresseur : relecture")
	TC.Reset()
	TC.Captures()
	local builds, own = 0, QNS.TrainerOwnCard
	QNS.TrainerOwnCard = function(...) builds = builds + 1; return own(...) end
	-- une demande en combat : rien n'est construit, rien ne part
	TC.combat = true
	QNS:TrainerOnAddonMessage("QCTrainer", "R~1", "WHISPER", "Bob-Royaume")
	TC.Flush()
	local combat = builds == 0 and #TC.sent == 0
	TC.combat = false
	TC.Flush()
	local once = builds == 1 and TC.Kinds(TC.Take()):find("^C") ~= nil
	QNS:TrainerOnAddonMessage("QCTrainer", "R~1", "WHISPER", "Cid-Royaume")
	TC.Flush()
	Check("[TRN] demande en combat : fiche pas construite ; hors combat : construite une fois, puis en cache", combat
		and once and builds == 1 and #TC.Take() > 0, builds)
	local capture = QNS:CaptureData()
	capture.serial = (tonumber(capture.serial) or 0) + 1
	QNS:TrainerOnAddonMessage("QCTrainer", "R~1", "WHISPER", "Dan-Royaume")
	TC.Flush()
	local rebuilt = builds == 2
	QNS:TrainerSetShowcase(1, "cap:7001")
	QNS:TrainerOnAddonMessage("QCTrainer", "R~1", "WHISPER", "Eli-Royaume")
	TC.Flush()
	TC.Take()
	Check("[TRN] refaite quand les captures ou la vitrine changent", rebuilt and builds == 3, builds)
	QNS.TrainerOwnCard = own

	-- première capture : la date figée du lot 1, pas `at`
	capture.firstAt = TC.now - 86400 * 30
	local frozen = QNS:TrainerOwnCard().first == TC.now - 86400 * 30
	capture.firstAt = nil
	capture.creatures[7001].firstAt = TC.now - 86400 * 20
	Check("[TRN] première capture : capture.firstAt, sinon la plus ancienne firstAt des fiches", frozen
		and QNS:TrainerOwnCard().first == TC.now - 86400 * 20)

	-- noms : casse, accents, royaume à trait d'union
	TC.Reset()
	QNS:TrainerOnAddonMessage("QCTrainer", "H~1", "PARTY", "Bob-Hyjal")
	Check("[TRN] clé : casse et accents (« Bob-hyjal », « élodie-royaume »)", QNS:TrainerIsHolder("Bob-hyjal")
		and QNS:TrainerIsHolder("bob-HYJAL") and QNS:TrainerKey("Élodie") == "élodie-royaume"
		and QNS:TrainerKey("élodie-Royaume") == "élodie-royaume", tostring(QNS:TrainerKey("Élodie")))
	Check("[TRN] menu : royaume avec trait d'union", QNS:TrainerMenuTarget({ name = "Kim", server = "Azjol-Nerub" }) == "Kim-AzjolNerub"
		and QNS:TrainerFullName("Kim-Azjol-Nerub") == "Kim-AzjolNerub")
	TC.Take()
	QNS:HandleCommand("fiche élodie")
	local f = QNS.trainerFrame
	local pending = f:IsShown() and f.state == "pending"
	QNS:TrainerOnAddonMessage("QCTrainer", "C~1~4~1~1~n=" .. QNS.TrainerEscape("Élodie-Royaume") .. ";sp=7", "WHISPER", "Élodie-Royaume")
	Check("[TRN] /qc fiche élodie : demande en cours, fiche reçue de « Élodie » affichée", pending and f.state == "card"
		and QNS:TrainerStatus("élodie") == "ok" and QNS:TrainerCard("ÉLODIE") ~= nil, f.state)
	f:Hide()
	local db = QNS:DB()
	db.trainerHolders, db.trainerHoldersV = { ["Vieux-Royaume"] = TC.now }, nil
	Check("[TRN] cache des détenteurs d'avant : clés converties", QNS:TrainerIsHolder("vieux")
		and QNS:TrainerHolders()["vieux-royaume"] == TC.now)

	-- usurpation : le titre vient de l'expéditeur, pas du champ « n »
	QNS:TrainerOpen("Fred")
	QNS:TrainerOnAddonMessage("QCTrainer", "C~1~5~1~1~n=Roi-Royaume;sp=99", "WHISPER", "Fred-Royaume")
	Check("[TRN] usurpation : le titre dit Fred, pas le nom reçu", f.state == "card" and f.header.title.text == "Fred",
		f.header.title.text)
	f:Hide()

	-- sondes et messages entrants
	TC.Reset()
	QNS:TrainerOnAddonMessage("QCTrainer", "P~1", "WHISPER", "Gil-Royaume")
	QNS:TrainerOnAddonMessage("QCTrainer", "P~1", "WHISPER", "Gil-Royaume")
	QNS:TrainerOnAddonMessage("QCTrainer", "P~1", "WHISPER", "gil-royaume")
	TC.Flush()
	Check("[TRN] sondes répétées : un seul accusé", TC.Kinds(TC.Take()) == "A")
	local accepted = 0
	for _ = 1, QNS.TRAINER_IN_MAX + 10 do
		if QNS:TrainerOnAddonMessage("QCTrainer", "A~1", "WHISPER", "Hal-Royaume") then accepted = accepted + 1 end
	end
	local capped = accepted == QNS.TRAINER_IN_MAX
	Mock.now = Mock.now + QNS.TRAINER_IN_WINDOW + 1
	Check("[TRN] rafale d'un même joueur : plafonnée, puis de nouveau écouté", capped
		and QNS:TrainerOnAddonMessage("QCTrainer", "A~1", "WHISPER", "Hal-Royaume"), accepted)

	-- morceaux incohérents : rejetés, sans erreur
	local function Feed(list)
		local ok = true
		for _, text in ipairs(list) do
			if not pcall(QNS.TrainerOnAddonMessage, QNS, "QCTrainer", text, "WHISPER", "Ian-Royaume") then ok = false end
		end
		return ok
	end
	local bad = {}
	if not (Feed({ "C~1~6~1~2~sp=1", "C~1~6~3~3~;st=2" }) and QNS:TrainerCard("Ian") == nil) then bad[#bad + 1] = "hors du total" end
	if not (Feed({ "C~1~7~2~2~;st=2", "C~1~7~1~1~sp=1" }) and QNS:TrainerCard("Ian") == nil) then bad[#bad + 1] = "total changé" end
	if not (Feed({ "C~1~8~0~1~x", "C~1~8~1~99~x", "C~1~8~1.5~2~x", "C~1~8~x~y~z" }) and QNS:TrainerCard("Ian") == nil) then
		bad[#bad + 1] = "numéros absurdes"
	end
	Check("[TRN] morceaux incohérents (hors du total, total qui change, numéros absurdes) : rejetés, sans erreur", #bad == 0,
		table.concat(bad, ", "))
	Check("[TRN] une série propre ensuite : reçue", Feed({ "C~1~9~2~2~;st=40", "C~1~9~1~2~sp=12" })
		and QNS:TrainerCard("Ian") and QNS:TrainerCard("Ian").species == 12 and QNS:TrainerCard("Ian").total == 40)

	-- effets : libellé refait ici ; ancien format (libellé) coupé sans casser l'UTF-8
	local card = QNS:TrainerParseCard("n=x;cn=7;hi=capture_named;hv=0.180;ci=pet_mood;cv=9")
	Check("[TRN] effets reçus : libellés refaits (valeur bornée au plafond)", card.companion.hunt == QNS:F("EFF_capture_named", 18)
		and card.companion.comfort == QNS:F("EFF_pet_mood", 100), tostring(card.companion.comfort))
	card = QNS:TrainerParseCard("n=x;cn=7;hi=inconnu;hv=1;ch=" .. QNS.TrainerEscape(string.rep("é", 120)))
	local hunt = card.companion.hunt
	Check("[TRN] effet inconnu : libellé reçu, coupé sur un caractère entier (jamais au milieu)", hunt and #hunt <= 160
		and #hunt % 2 == 0 and hunt:sub(-2) == "é" and QNS.TrainerUtf8Cut("aé", 2) == "a"
		and QNS.TrainerUtf8Cut("aé", 3) == "aé" and QNS.TrainerUtf8Cut("abc", 2) == "ab", hunt and #hunt)

	-- guilde : une annonce par session
	TC.Reset()
	TC.guild = true
	QNS:TrainerOnEvent("PLAYER_GUILD_UPDATE")
	TC.Flush()
	Mock.now = Mock.now + 600
	QNS:TrainerOnEvent("PLAYER_GUILD_UPDATE")
	QNS:TrainerOnEvent("PLAYER_GUILD_UPDATE")
	TC.Flush()
	local guildSent = TC.Take()
	local single = TC.Kinds(guildSent) == "H"
	TC.guild = false
	QNS:TrainerOnEvent("PLAYER_GUILD_UPDATE")
	TC.guild = true
	Mock.now = Mock.now + 120
	QNS:TrainerOnEvent("PLAYER_GUILD_UPDATE")
	TC.Flush()
	Check("[TRN] guilde : une seule annonce par session, une nouvelle pour une nouvelle guilde", single
		and TC.Kinds(TC.Take()) == "H", TC.Kinds(guildSent))

	-- UnitIsFriend secret : lu par ns.Plain, sans erreur
	_G.UnitIsFriend = function() return SECRET end
	_G.issecretvalue = function(v) return v == SECRET end
	TC.units.target = { name = "Jon" }
	Check("[TRN] UnitIsFriend secret : sans erreur", pcall(QNS.TrainerOnTarget, QNS, "target"))
	_G.issecretvalue = TC.saved.issecretvalue
end

TC.Done()
