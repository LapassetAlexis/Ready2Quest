-- QuestCompanion 3.7.0, étape 3, chantier S2 : code de dresseur
-- (TrainerCode.lua), dresseurs connus, onglet « Dresseurs » de la page
-- Communauté et parrainage (TrainerKnown.lua). Le code aller et retour
-- (fiche vide, fiche pleine, taille), le copier-coller abîmé, chaque raison
-- de refus, un code d'une version future ; les dresseurs connus (origine,
-- plafond, filtres, retrait, autre royaume, autre faction, rien d'autre de
-- gardé ni d'envoyé) ; une fiche par code indicative ; l'onglet (champs,
-- compteurs, lignes, clavier) ; le sixième salon ; le parrainage (14 jours,
-- une fois, soi-même et ses personnages, message reçu deux fois, parrain hors
-- ligne puis croisé, réponse) ; les contrastes ; les textes.
local Check, Say, ResetWorld, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local NS = QNS
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local function Shown(region) return region ~= nil and region.IsShown and region:IsShown() and true or false end

local saved = { InCombatLockdown = rawget(_G, "InCombatLockdown"), UnitAffectingCombat = rawget(_G, "UnitAffectingCombat"),
	time = rawget(_G, "time"), UnitFactionGroup = rawget(_G, "UnitFactionGroup"), C_ChatInfo = rawget(_G, "C_ChatInfo"),
	SendChatMessage = rawget(_G, "SendChatMessage"), TallyAdd = rawget(NS, "TallyAdd"), TallyGet = rawget(NS, "TallyGet"),
	TallyMark = rawget(NS, "TallyMark"), dormant = NS.featsDormant }
local now = 1800000000
local faction = "Alliance"
local sent = {}

local function Reset(style)
	ResetWorld()
	NS:TrainerResetSession()
	NS:TrainerKnownResetSession()
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	if NS.trainerCompareFrame then NS.trainerCompareFrame:Hide() end
	NS.trainerFrame = nil
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame, NS.uiStyleCache = nil, {}
	NS:DB().journalTab, NS:DB().journalState = nil, nil
	NS:DB().community, NS:DB().trainerKnown, NS:DB().trainerMentor = nil, nil, nil
	if style == "azeroth" then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:DB().companionStyle = style or "sobre"
	NS:ApplyUIStyle()
	NS:CompanionData().tutoDone = true
	now = 1800000000
	faction = "Alliance"
	_G.time = function() return now end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.UnitFactionGroup = function() return faction end
	sent = {}
	_G.C_ChatInfo = { SendAddonMessage = function(prefix, text, channel, target)
			sent[#sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
			return true
		end,
		InChatMessagingLockdown = function() return false end, RegisterAddonMessagePrefix = function() return true end }
	_G.SendChatMessage = function() sent[#sent + 1] = { chat = true } end
	NS.TallyAdd, NS.TallyGet, NS.TallyMark = saved.TallyAdd, saved.TallyGet, saved.TallyMark
end

local function Done()
	if NS.journalFrame then NS.journalFrame:Hide() end
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	if NS.trainerCompareFrame then NS.trainerCompareFrame:Hide() end
	NS.journalFrame, NS.trainerFrame, NS.uiStyleCache = nil, nil, {}
	for _, name in ipairs({ "InCombatLockdown", "UnitAffectingCombat", "time", "UnitFactionGroup", "C_ChatInfo", "SendChatMessage" }) do
		_G[name] = saved[name]
	end
	NS.TallyAdd, NS.TallyGet, NS.TallyMark = saved.TallyAdd, saved.TallyGet, saved.TallyMark
	NS.featsDormant = saved.dormant
	Mock.InstallAtlas(nil)
	NS:DB().companionStyle = nil
	NS:ApplyUIStyle()
	ResetWorld()
end

local function Pump() for _ = 1, 10 do NS:TrainerPump(10) end end

-- la fiche `text` reçue de `sender`, vu d'abord sur `channel` (annonce)
local function Receive(text, sender, channel)
	if channel then NS:TrainerOnAddonMessage("QCTrainer", "H~1", channel, sender) end
	for _, chunk in ipairs(NS:TrainerChunks(text, 7)) do NS:TrainerOnAddonMessage("QCTrainer", chunk, "WHISPER", sender) end
	return NS:TrainerCard(sender)
end

local function OpenJournal(tab)
	NS:ToggleJournal(true)
	NS:SelectJournalKind("community")
	if tab then NS:CommunitySelectTab(tab) end
	return NS.journalFrame
end

-- une fiche pleine (tous les champs au maximum, comme tests/modules/trainer_37.lua)
local function FullCard()
	local codes = {}
	for n = 1, 450 do codes[n] = true end
	local full = { proto = 1, name = "Abcdefghijkl-Royaumeimmense", title = string.rep("é", 30),
		titleCode = 200, gender = "f", first = 1790000000, species = 3128, total = 3128, shinies = 999, shinySeen = 999, seals = 120,
		feats = { account = 99999, char = 99999, count = 450 }, showcase = {}, badges = { ek = 60, ka = 55, other = 5 },
		companion = { name = string.rep("n", 48), npc = 123456, display = 123456, class = "rareelite", shiny = true, stars = 3,
			typeKey = "elemental", strength = 0.125, huntId = "capture_all", huntValue = 0.06, comfortId = "decay_slow", comfortValue = 0.12 },
		featShowcase = {}, featCats = { men = 999, shiny = 999, zone = 999, char = 999 }, styleBg = "card_directory",
		styleFrame = "card_rank_glow", mastered = 99999, medals = {}, featBits = NS:FeatBits(codes) }
	for slot = 1, 3 do
		full.showcase[slot] = { npc = 123450 + slot, shiny = true, stars = 3, class = "rareelite", typeKey = "elemental",
			name = string.rep("m", 48) }
		full.featShowcase[slot] = { n = 440 + slot, at = 1799999999 }
	end
	for _, key in ipairs(NS.CREATURE_TYPES) do full.medals[key] = 5 end
	return full
end

local function Utf8Len(text)
	local n = 0
	for _ in tostring(text):gmatch("[^\128-\191]") do n = n + 1 end
	return n
end

-- 1. Le code, aller et retour -------------------------------------------------------------------
do
	Say("-- S2 : code de dresseur")
	Reset()
	local s = Steps()
	-- fiche vide
	local empty = { name = "Zed-Royaume", showcase = {}, badges = {}, featBits = "" }
	local code = NS:TrainerCodeOf(empty, "H")
	local back, reason, info = NS:TrainerCodeRead(code)
	s.ok("fiche vide : « QC1: … :<8 hex> »", code:find("^QC1:[^:]+:%x%x%x%x%x%x%x%x$") ~= nil, code)
	s.ok("fiche vide relue : nom, bits vides, faction", back and back.name == "Zed-Royaume" and back.featBits == "" and info.faction == "H", reason)
	-- fiche pleine : moins de 1 000 caractères
	local full = FullCard()
	local fullCode = NS:TrainerCodeOf(full, "A")
	local fullBack, why = NS:TrainerCodeRead(fullCode)
	s.ok("fiche pleine : moins de 1 000 caractères", Utf8Len(fullCode) < 1000, Utf8Len(fullCode))
	s.ok("fiche pleine relue à l'identique", fullBack and fullBack.name == full.name and fullBack.species == 3128
		and fullBack.featBits == full.featBits and fullBack.companion and fullBack.companion.npc == 123456
		and fullBack.showcase[3] and fullBack.showcase[3].name == string.rep("m", 48) and fullBack.feats.account == 99999, why)
	-- ma fiche : TrainerCodeMake, avec ma faction
	NS:FeatAward("men_first", { silent = true })
	local mine = NS:TrainerCodeMake()
	local own, _, ownInfo = NS:TrainerCodeRead(mine)
	s.ok("mon code : ma fiche, ma faction (Alliance = A)", own and NS:TrainerKey(own.name) == NS:TrainerKey(NS:TrainerMe())
		and ownInfo.faction == "A" and own.featBits == NS:FeatBits(), mine)
	-- espaces, « + » et « _ » dans les textes : transportés, rendus tels quels
	local tricky = { name = "Kéa-Royaume", title = "le + grand_chasseur des plaines", showcase = {}, badges = {},
		featBits = "_A_B-_" }
	local trickyCode = NS:TrainerCodeOf(tricky, nil)
	local trickyBack = NS:TrainerCodeRead(trickyCode)
	local bang = { name = "Kéa!-Royaume", title = "Ouah ! 100 %", showcase = {}, badges = {}, featBits = "____" }
	local bangBack = NS:TrainerCodeRead(NS:TrainerCodeOf(bang, nil))
	s.ok("ni espace ni « _ » dans le code (Discord), relu tel quel", not trickyCode:find("[ _]") and trickyBack
		and trickyBack.title == "le + grand_chasseur des plaines" and trickyBack.featBits == "_A_B-_", trickyCode)
	s.ok("« ! » et « % » d'un texte relus tels quels", bangBack and bangBack.name == "Kéa!-Royaume" and bangBack.title == "Ouah ! 100 %"
		and bangBack.featBits == "____")
	s.ok("somme : djb2 de « QC1:<corps> »", NS.TrainerCodeSum("abc") == "0b885c8b", NS.TrainerCodeSum("abc"))
	Say(string.format("   code d'une fiche pleine : %d caractères (%d octets) ; fiche sérialisée %d octets ; code d'une fiche vide : %d",
		Utf8Len(fullCode), #fullCode, #NS:TrainerSerializeCard(full), #code))
	s.check("[S2-CODE] aller et retour : fiche vide, fiche pleine (< 1 000 caractères), ma fiche et ma faction, espaces et « _ » transportés")
	Done()
end

-- 2. Copier-coller abîmé, refus, version future -------------------------------------------------
do
	Reset()
	local s = Steps()
	local card = { name = "Xan-Royaume", title = "Maîtresse des brillantes", species = 287, shinies = 9, showcase = {}, badges = {},
		feats = { account = 1000, char = 105, count = 90 }, featBits = "AB" }
	local code = NS:TrainerCodeOf(card, "A")
	local function Reads(label, text)
		local back, reason = NS:TrainerCodeRead(text)
		s.ok(label, back and back.name == "Xan-Royaume" and back.title == "Maîtresse des brillantes", reason)
	end
	Reads("espaces ajoutés", code:sub(1, 30) .. "   " .. code:sub(31, 80) .. " " .. code:sub(81))
	Reads("retours à la ligne (\\n, \\r\\n) et tabulations", code:sub(1, 50) .. "\n" .. code:sub(51, 120) .. "\r\n\t" .. code:sub(121))
	Reads("guillemets autour", "\"" .. code .. "\"")
	Reads("guillemets français et typographiques", "« " .. code .. " »")
	Reads("“ … ”", "\226\128\156" .. code .. "\226\128\157")
	Reads("bloc de code Discord", "```\n" .. code .. "\n```")
	Reads("accent grave et gras", "**`" .. code .. "`**")
	Reads("espace insécable et largeur nulle", code:sub(1, 40) .. "\194\160" .. code:sub(41, 90) .. "\226\128\139" .. code:sub(91))
	Reads("préfixe en minuscules", "qc1:" .. code:sub(5))
	-- refus, chacun avec sa raison
	local function Refused(label, text, want)
		local back, reason = NS:TrainerCodeRead(text)
		s.ok(label, back == nil and reason == want, tostring(reason))
	end
	Refused("vide", "", "empty")
	Refused("blancs seulement", "  \n\t ", "empty")
	Refused("guillemets seuls", "\"\"", "empty")
	Refused("trop long", "QC1:" .. string.rep("a", NS.TRAINER_CODE_MAX) .. ":00000000", "long")
	Refused("préfixe inconnu", "Bonjour tout le monde", "prefix")
	Refused("autre préfixe", "XY1:" .. code:sub(5), "prefix")
	Refused("version future (QC2)", "QC2:" .. code:sub(5), "newer")
	Refused("QC0", "QC0:" .. code:sub(5), "prefix")
	local flipped = code:sub(1, 20) .. (code:sub(21, 21) == "a" and "b" or "a") .. code:sub(22)
	Refused("un caractère changé : somme fausse", flipped, "sum")
	Refused("tronqué : somme fausse", code:sub(1, #code - 30), "sum")
	Refused("sans somme", code:sub(1, #code - 9), "sum")
	local bare = "QC1:p=1%3Bsp=3"
	Refused("somme juste, pas de fiche (pas de nom)", bare .. ":" .. NS.TrainerCodeSum(bare), "card")
	-- chaque raison a sa phrase, en français et en anglais
	local phrases = true
	for _, why in ipairs(NS.TRAINER_CODE_REASONS) do
		local key = "TRAINER_CODE_ERR_" .. why
		phrases = phrases and NS.TRAINER_CODE_STRINGS.fr[key] ~= nil and NS.TRAINER_CODE_STRINGS.en[key] ~= nil
			and NS:TrainerCodeReason(why) == NS.L[key]
	end
	s.ok("une phrase par raison (FR, EN)", phrases)
	-- une version future qui ajoute des champs au corps (même préfixe) : lus sans erreur, ignorés
	local body = NS:TrainerSerializeCard(card) .. ";zz=nouveau;qq=1,2,3"
	local future = "QC1:" .. body:gsub(" ", "+")
	future = future .. ":" .. NS.TrainerCodeSum(future)
	local fb, freason = NS:TrainerCodeRead(future)
	s.ok("champs inconnus d'une version future : ignorés", fb and fb.name == "Xan-Royaume" and fb.species == 287, freason)
	s.ok("jamais d'erreur sur n'importe quoi", pcall(NS.TrainerCodeRead, NS, nil) and pcall(NS.TrainerCodeRead, NS, 42)
		and pcall(NS.TrainerCodeRead, NS, string.rep(":", 50)) and pcall(NS.TrainerCodeRead, NS, "QC1:::"))
	s.check("[S2-CODE] tolérant au copier-coller (blancs, guillemets, blocs Discord), chaque refus a sa raison, version future sans casse")
	Done()
end

-- 3. Dresseurs connus ---------------------------------------------------------------------------
do
	Say("-- S2 : dresseurs connus")
	Reset()
	local s = Steps()
	Receive("p=1;n=Xan;t=Maîtresse des brillantes;sp=287;sy=9;ap=1000;aq=105;ac=90;fb=AB", "Xan-Royaume", "GUILD")
	Receive("p=1;n=Bob;sp=12;sy=0", "Bob-Royaume", "PARTY")
	Receive("p=1;n=Cid;sp=3;sy=1", "Cid-Royaume")
	local list = NS:TrainerKnownList()
	local origins = {}
	for _, v in ipairs(list) do origins[v.key] = v.origin end
	s.ok("trois fiches reçues en jeu, gardées", #list == 3 and NS:TrainerKnownCount() == 3)
	s.ok("origine : guilde, groupe, ciblé", origins["xan-royaume"] == "guild" and origins["bob-royaume"] == "group"
		and origins["cid-royaume"] == "target", tostring(origins["xan-royaume"]) .. "," .. tostring(origins["bob-royaume"]))
	s.ok("dans la sauvegarde du compte (db.trainerKnown)", _G.QuestCompanionDB.trainerKnown and #_G.QuestCompanionDB.trainerKnown.list == 3)
	-- la session perdue (déconnexion) : la fiche reste
	NS:TrainerResetSession()
	NS:TrainerKnownResetSession()
	local kept = NS:TrainerCard("Xan-Royaume")
	s.ok("après déconnexion : la fiche gardée répond", kept and kept.species == 287 and kept.title == "Maîtresse des brillantes")
	-- une fiche plus récente remplace, pas de doublon
	now = now + 100
	Receive("p=1;n=Xan;sp=300;sy=9;fb=AB", "Xan-Royaume", "GUILD")
	s.ok("même dresseur : une entrée, la fiche la plus récente", NS:TrainerKnownCount() == 3 and NS:TrainerKnownGet("xan-royaume").card.species == 300)
	-- ligne : nom et titre, rang · points · espèces · brillantes, origine et date
	local xan = NS:TrainerKnownList()[1]
	s.ok("la plus récente en tête", xan.key == "xan-royaume")
	local view = NS:TrainerKnownGet("xan-royaume")
	view.card.feats = { account = 1000, char = 105, count = 90 }
	s.ok("ligne : « <rang> · <points> points · <espèces> espèces · <brillantes> brillantes »",
		NS:TrainerKnownLine(view.card) == NS.L.FEAT_RANK_4 .. " · 1 105 points · 300 espèces · 9 brillantes", NS:TrainerKnownLine(view.card))
	s.ok("sans points : espèces et brillantes ; singulier", NS:TrainerKnownLine({ species = 1, shinies = 1 }) == "1 espèce · 1 brillante")
	s.ok("origine et date : « rencontre en guilde · jj/mm »", NS:TrainerKnownSeen(xan) == "rencontre en guilde · " .. os.date("%d/%m", now),
		NS:TrainerKnownSeen(xan))
	-- par code, d'un autre royaume, de l'autre faction
	local other = NS:TrainerCodeOf({ name = "Brakmar-Hyjal", species = 512, shinies = 31, showcase = {}, badges = {} }, "A")
	local zug = NS:TrainerCodeOf({ name = "Zugzug-Royaume", species = 301, shinies = 12, showcase = {}, badges = {}, featBits = "" }, "H")
	s.ok("deux codes ouverts", NS:TrainerKnownOpenCode(other) == "ok" and NS:TrainerKnownOpenCode(zug) == "ok")
	local brak, zz = NS:TrainerKnownGet("brakmar-hyjal"), NS:TrainerKnownGet("zugzug-royaume")
	s.ok("marqués « reçu par code », autre royaume / autre faction", brak.code and brak.otherRealm and not brak.otherFaction
		and zz.code and zz.otherFaction and not zz.otherRealm
		and NS:TrainerKnownSeen(brak):find("^reçu par code · autre royaume · ") and NS:TrainerKnownSeen(zz):find("^reçu par code · autre faction · "))
	s.ok("en jeu : même faction (jamais « autre faction »)", not NS:TrainerKnownGet("bob-royaume").otherFaction)
	-- filtres
	local function Keys(filter)
		local out = {}
		for _, v in ipairs(NS:TrainerKnownList(filter)) do out[#out + 1] = v.key end
		table.sort(out)
		return table.concat(out, ",")
	end
	s.ok("filtre « Croisés en jeu »", Keys("game") == "bob-royaume,cid-royaume,xan-royaume", Keys("game"))
	s.ok("filtre « Reçus par code »", Keys("code") == "brakmar-hyjal,zugzug-royaume", Keys("code"))
	s.ok("filtre « Tous »", #NS:TrainerKnownList("all") == 5)
	-- retrait
	s.ok("retrait", NS:TrainerKnownRemove("cid-royaume") and NS:TrainerKnownGet("cid-royaume") == nil and NS:TrainerKnownCount() == 4
		and not NS:TrainerKnownRemove("cid-royaume"))
	-- plafond : 50, les plus anciennes sorties d'abord
	NS:DB().trainerKnown = nil
	for i = 1, 55 do
		now = 1800000000 + i
		NS:TrainerKnownAdd({ name = "Dresseur" .. i .. "-Royaume", species = i, showcase = {}, badges = {} }, "group")
	end
	local all = NS:TrainerKnownList()
	s.ok("plafond : 50 au compte", NS:TrainerKnownCount() == 50 and NS.TRAINER_KNOWN_MAX == 50)
	s.ok("les cinq plus anciennes sorties", NS:TrainerKnownGet("dresseur1-royaume") == nil and NS:TrainerKnownGet("dresseur5-royaume") == nil
		and NS:TrainerKnownGet("dresseur6-royaume") ~= nil and all[1].key == "dresseur55-royaume")
	-- moi : jamais rangé
	s.ok("ma propre fiche : jamais rangée", NS:TrainerKnownAdd(NS:TrainerOwnCard(), "group") == nil)
	-- rien d'autre de gardé : clés de l'entrée
	local entry = _G.QuestCompanionDB.trainerKnown.list[1]
	local keys = {}
	for key in pairs(entry) do keys[#keys + 1] = key end
	table.sort(keys)
	s.ok("une entrée : clé, nom, fiche, origine, date (et faction d'un code)", table.concat(keys, ",") == "at,c,k,n,o", table.concat(keys, ","))
	-- sauvegarde retouchée : écartée sans erreur
	_G.QuestCompanionDB.trainerKnown.list[#_G.QuestCompanionDB.trainerKnown.list + 1] = { k = 3 }
	s.ok("entrée illisible écartée", NS:TrainerKnownCount() == 50)
	s.check("[S2-KNOWN] fiches reçues gardées (origine), une par dresseur, codes marqués, autre royaume / faction, filtres, retrait, plafond 50")
	Done()
end

-- 4. Une fiche par code est indicative ----------------------------------------------------------
do
	Reset()
	local s = Steps()
	NS.featsDormant = false
	local adds, marks = {}, {}
	NS.TallyAdd = function(_, key) adds[#adds + 1] = key; return #adds end
	NS.TallyMark = function(_, key, member) marks[#marks + 1] = key .. ":" .. tostring(member); return #marks end
	local code = NS:TrainerCodeOf({ name = "Deklatis-Royaume", species = 96, shinies = 2, showcase = {}, badges = {}, featBits = "" }, "A")
	local holders = 0
	for _ in pairs(NS:TrainerHolders()) do holders = holders + 1 end
	local state, view, isNew = NS:TrainerKnownOpenCode(code)
	Pump()
	s.ok("ouverte et rangée", state == "ok" and isNew and view.code)
	s.ok("la fenêtre de fiche s'ouvre sur elle", NS.trainerFrame and NS.trainerFrame:IsShown() and NS.trainerFrame.state == "card"
		and NS:TrainerKey(NS.trainerFrame.viewing) == "deklatis-royaume")
	s.ok("marquée : « Reçue par code le … · indicative »", (NS.trainerFrame.received.text or ""):find("^Reçue par code le .+ · indicative$") ~= nil,
		NS.trainerFrame.received.text)
	s.ok("compte : codeOpen une fois", #adds == 1 and adds[1] == "codeOpen", table.concat(adds, ","))
	local cards = NS:FeatStore("account").cards
	s.ok("compte pour les fiches consultées (haut fait des fiches différentes)", type(cards) == "table" and cards["deklatis-royaume"] == true)
	local after = 0
	for _ in pairs(NS:TrainerHolders()) do after = after + 1 end
	s.ok("jamais autre chose : pas de détenteur noté, aucun ensemble marqué", after == holders and #marks == 0, table.concat(marks, ","))
	s.ok("aucune demande envoyée à son dresseur (ni message, ni chat)", #sent == 0, #sent)
	-- le même code rouvert : pas un dresseur nouveau
	NS:TrainerKnownOpenCode(code)
	s.ok("rouvert : pas compté deux fois", #adds == 1)
	-- un personnage de mon compte : rangé, pas compté
	NS:DB().chars["Alt-Royaume"] = {}
	NS:TrainerKnownOpenCode(NS:TrainerCodeOf({ name = "Alt-Royaume", showcase = {}, badges = {} }, "A"))
	s.ok("un de mes personnages : pas compté", #adds == 1)
	-- mon propre code : ma fiche, rien de rangé ni de compté
	local before = NS:TrainerKnownCount()
	s.ok("mon propre code : « self », rien de rangé", NS:TrainerKnownOpenCode(NS:TrainerCodeMake()) == "self"
		and NS:TrainerKnownCount() == before and #adds == 1 and NS.trainerFrame.viewing == nil)
	-- croisé en jeu ensuite (même royaume) : la vraie fiche remplace, plus « par code »
	Receive("p=1;n=Deklatis;sp=97;sy=2;fb=", "Deklatis-Royaume", "PARTY")
	s.ok("croisé en jeu ensuite : la fiche de jeu remplace", not NS:TrainerKnownGet("deklatis-royaume").code
		and NS:TrainerKnownGet("deklatis-royaume").card.species == 97)
	-- fiche de jeu gardée, rouverte plus tard depuis la liste : pas de demande s'il n'est pas vu
	NS:TrainerResetSession()
	NS:TrainerKnownResetSession()
	sent = {}
	NS:TrainerKnownOpen("deklatis-royaume")
	Pump()
	s.ok("ouverte depuis la liste, pas vue depuis longtemps : aucune demande", #sent == 0 and NS.trainerFrame.state == "card"
		and (NS.trainerFrame.received.text or ""):find("^Fiche gardée du ") ~= nil, NS.trainerFrame.received.text)
	s.check("[S2-INDIC] fiche par code : rangée et marquée, codeOpen par dresseur nouveau, fiches consultées, jamais autre chose, rien envoyé")
	Done()
end

-- 5. L'onglet Dresseurs -------------------------------------------------------------------------
do
	Say("-- S2 : onglet Dresseurs")
	Reset("azeroth")
	local s = Steps()
	local adds, tally = {}, {}
	NS.TallyAdd = function(_, key) adds[#adds + 1] = key; tally[key] = (tally[key] or 0) + 1 end
	NS.TallyGet = function(_, key) return tally[key] or 0 end
	-- liste vide d'abord
	local f = OpenJournal()
	local pane = f.community
	s.ok("en tête des onglets, Discord ouvert par défaut", pane.tabs.chips[1].id == "dresseurs" and pane.tabs.chips[1].text:GetText() == "Dresseurs"
		and pane.tab == "discord")
	NS:CommunitySelectTab("dresseurs")
	local view = pane.views.dresseurs
	s.ok("compteur à droite des onglets : « 0 dresseur connu sur 50 »", pane.tabNote:GetText() == "0 dresseur connu sur 50", pane.tabNote:GetText())
	s.ok("liste vide : une phrase, aucune ligne", Shown(view.empty) and view.empty:GetText():find("^Aucun dresseur connu") and not Shown(view.rows[1]))
	-- mon code
	local box = view.mine.box
	s.ok("mon code dans le champ (QC1:…)", box:GetText():find("^QC1:") ~= nil and box:GetText() == NS:TrainerCodeMake())
	s.ok("champ : pas de focus d'office, lecture seule", box.autoFocus == false and not box:HasFocus())
	box:SetText("zzz")
	box.scripts.OnTextChanged(box)
	s.ok("lecture seule : le code revient", box:GetText() == NS:TrainerCodeMake())
	box.HighlightText = function(self) self.highlighted = true end
	view.mine.button:Click()
	s.ok("« Copier » : focus, tout sélectionné, consigne", box:HasFocus() and box.highlighted == true and Shown(view.mine.status)
		and view.mine.status:GetText():find("Ctrl+C", 1, true) ~= nil)
	s.ok("« Copier » : codeCopy la première fois", adds[1] == "codeCopy" and #adds == 1)
	view.mine.button:Click()
	s.ok("deuxième copie : pas de second compteur", #adds == 1)
	-- ouvrir un code
	local open = view.open
	s.ok("« Ouvrir » grisé tant que rien n'est collé", open.button.inactive == true and Shown(open.box.placeholder)
		and open.box.placeholder:GetText() == "Colle un code ici…")
	open.box:SetText("n'importe quoi")
	open.box.scripts.OnTextChanged(open.box)
	s.ok("collé : actif", not open.button.inactive)
	open.button:Click()
	s.ok("code faux : une phrase à la place de l'intertitre", Shown(open.status) and not Shown(open.head)
		and open.status:GetText() == NS.L.TRAINER_CODE_ERR_prefix and open.status.comInk == Theme.LABEL)
	open.box:SetText(NS:TrainerCodeOf({ name = "Brakmar-Hyjal", species = 512, shinies = 31, showcase = {}, badges = {},
		feats = { account = 2000, char = 40, count = 200 } }, "A"))
	open.box.scripts.OnTextChanged(open.box)
	s.ok("retapé : la phrase s'efface", not Shown(open.status) and Shown(open.head))
	open.box.scripts.OnEnterPressed(open.box)
	s.ok("bon code (Entrée) : ouvert, rangé, phrase verte, champ vidé", open.status:GetText() == "Fiche de Brakmar ouverte et rangée."
		and open.status.comInk == Theme.GREEN and open.box:GetText() == "" and NS:TrainerKnownGet("brakmar-hyjal") ~= nil
		and NS.trainerFrame and NS.trainerFrame:IsShown(), open.status:GetText())
	s.ok("codeOpen compté", adds[2] == "codeOpen")
	-- des fiches de jeu
	now = now + 10
	Receive("p=1;n=Xan;t=Maîtresse des brillantes;sp=287;sy=9;ap=1000;aq=105;ac=90;fb=AB", "Xan-Royaume", "GUILD")
	NS:CommunityTrainersPaint()
	s.ok("compteur : « 2 dresseurs connus sur 50 »", pane.tabNote:GetText() == "2 dresseurs connus sur 50", pane.tabNote:GetText())
	local row1, row2 = view.rows[1], view.rows[2]
	s.ok("ligne : nom et titre, chiffres, origine et date", row1.name:GetText() == "Xan, Maîtresse des brillantes"
		and row1.line:GetText() == NS.L.FEAT_RANK_4 .. " · 1 105 points · 287 espèces · 9 brillantes"
		and row1.seen:GetText():find("^rencontre en guilde · ") ~= nil, row1.name:GetText() .. " | " .. tostring(row1.line:GetText()))
	s.ok("ligne d'un code : « reçu par code · autre royaume · … »", row2.name:GetText() == "Brakmar"
		and row2.seen:GetText():find("^reçu par code · autre royaume · ") ~= nil, row2.seen:GetText())
	s.ok("« Comparer » grisé sans champ de comparaison, actif avec", row2.compareButton.inactive == true and not row1.compareButton.inactive
		and row2.compareButton.disabledTip == NS.L.TRAINER_COMPARE_OLD)
	s.ok("« Fiche », « Comparer » à leur place", row1.cardButton.lastPoint.x == 538 and row1.compareButton.lastPoint.x == 610
		and row1.cardButton:GetText() == "Fiche" and row1.compareButton:GetText() == "Comparer")
	NS.trainerFrame:Hide()
	row1.cardButton:Click()
	s.ok("« Fiche » : sa fiche", NS.trainerFrame:IsShown() and NS:TrainerKey(NS.trainerFrame.viewing) == "xan-royaume")
	row1.compareButton:Click()
	s.ok("« Comparer » : la comparaison", NS.trainerCompareFrame and NS.trainerCompareFrame:IsShown())
	if NS.trainerCompareFrame then NS.trainerCompareFrame:Hide() end
	-- filtres
	view.filters.chips[3]:Click()
	s.ok("filtre « Reçus par code »", pane.trainersFilter == "code" and view.rows[1].key == "brakmar-hyjal" and not Shown(view.rows[2]))
	view.filters.chips[2]:Click()
	s.ok("filtre « Croisés en jeu »", view.rows[1].key == "xan-royaume" and not Shown(view.rows[2]))
	view.filters.chips[1]:Click()
	-- clic droit : retirer
	view.rows[2]:Click("RightButton")
	s.ok("clic droit : retiré", NS:TrainerKnownGet("brakmar-hyjal") == nil and not Shown(view.rows[2])
		and pane.tabNote:GetText() == "1 dresseur connu sur 50")
	view.rows[1]:Click("LeftButton")
	s.ok("clic gauche hors parrainage : rien", NS:TrainerKnownGet("xan-royaume") ~= nil)
	-- beaucoup de dresseurs : 4 lignes (encadré du parrainage) puis la molette
	for i = 1, 9 do
		now = now + 1
		NS:TrainerKnownAdd({ name = "Dresseur" .. i .. "-Royaume", species = i, showcase = {}, badges = {} }, "group")
	end
	NS:CommunityTrainersPaint()
	local visible = 0
	for _, row in ipairs(view.rows) do if Shown(row) then visible = visible + 1 end end
	s.ok("encadré du parrainage là : 4 lignes", visible == 4 and Shown(view.mentor), visible)
	local top = view.rows[1].key
	view.scripts.OnMouseWheel(view, -1)
	s.ok("molette : la liste défile", view.rows[1].key ~= top and pane.trainersOffset == 1)
	view.scripts.OnMouseWheel(view, 50)
	s.ok("molette bornée", pane.trainersOffset == 0)
	-- tout tient : lignes au-dessus de l'encadré, encadré au-dessus de la note
	local LAY = NS.JOURNAL_TRAINERS_LAYOUT
	s.ok("4 lignes au-dessus de l'encadré, 5 au-dessus de la note", LAY.rowY + 3 * LAY.rowStep + LAY.rowH <= LAY.mentorY
		and LAY.rowY + 4 * LAY.rowStep + LAY.rowH <= LAY.noteY and LAY.mentorY + LAY.mentorH <= LAY.noteY)
	local room = -(NS.JournalUI.PAGER_Y - NS.JournalUI.TOP) + 24
	s.ok("note du bas dans la page", LAY.noteY + 2 * 15 <= room)
	s.ok("filtres à droite, sans toucher l'intertitre", view.filters.used <= NS.JournalUI.INNER - LAY.knownHeadW)
	s.ok("compteur et onglets sur la même rangée sans se toucher", pane.tabs.used + 8 + pane.tabNote:GetStringWidth() <= NS.JournalUI.INNER)
	s.check("[S2-TAB] onglet Dresseurs : mon code (Copier, codeCopy), ouvrir un code (phrase), lignes, Fiche, Comparer, filtres, retrait, molette")
	Done()
end

-- 6. Le clavier ---------------------------------------------------------------------------------
do
	Reset("azeroth")
	local s = Steps()
	local f = OpenJournal("dresseurs")
	local view = f.community.views.dresseurs
	local mine, open = view.mine.box, view.open.box
	s.ok("aucun champ ne prend le clavier d'office", mine.autoFocus == false and open.autoFocus == false
		and not mine:HasFocus() and not open:HasFocus())
	open:SetFocus()
	open.scripts.OnEscapePressed(open)
	s.ok("Échap : rendu", not open:HasFocus() and f:IsShown())
	mine.scripts.OnMouseUp(mine)
	s.ok("clic : le clavier", mine:HasFocus())
	mine.scripts.OnEscapePressed(mine)
	s.ok("Échap dans mon code : rendu", not mine:HasFocus())
	open:SetFocus()
	NS:CommunitySelectTab("discord")
	s.ok("changer d'onglet : rendu", not open:HasFocus())
	NS:CommunitySelectTab("dresseurs")
	mine:SetFocus()
	f.community.scripts.OnHide(f.community)
	s.ok("page quittée : rendu", not mine:HasFocus())
	s.check("[S2-TAB] clavier : jamais d'office, au clic ; rendu à Échap, au changement d'onglet et à la fermeture")
	Done()
end

-- 7. Le sixième salon ---------------------------------------------------------------------------
do
	Reset("sobre")
	local s = Steps()
	local f = OpenJournal("discord")
	local names = {}
	for _, tile in ipairs(f.community.views.discord.salons) do names[#names + 1] = tile.name:GetText() end
	s.ok("salon des fiches pas encore créé : cinq salons", #names == 5 and not table.concat(names, ","):find("fiches", 1, true))
	Done()
	local entry
	for _, salon in ipairs(NS.COMMUNITY_SALONS) do if salon.id == "dresseurs" then entry = salon end end
	s.ok("l'entrée de la table attend (open = false)", entry and entry.open == false and entry.name == "fiches-de-dresseur")
	entry.open = true
	Reset("sobre")
	f = OpenJournal("discord")
	local salons = f.community.views.discord.salons
	local sixth
	for _, tile in ipairs(salons) do if tile.salon == entry then sixth = tile end end
	s.ok("passée à vrai : la sixième ligne apparaît", #salons == 6 and sixth and sixth.name:GetText() == "fiches-de-dresseur"
		and sixth.text:GetText() == "Colle ton code de dresseur, ouvre celui des autres.")
	entry.open = false
	s.check("[S2-SALON] sixième salon : masqué tant que COMMUNITY_SALONS le dit fermé, la ligne de la maquette quand il s'ouvre")
	Done()
end

-- 8. Parrainage ---------------------------------------------------------------------------------
do
	Say("-- S2 : parrainage")
	Reset("azeroth")
	local s = Steps()
	local marks, tallyMarks = {}, {}
	NS.TallyMark = function(_, key, member)
		marks[#marks + 1] = key .. ":" .. tostring(member)
		tallyMarks[key] = tallyMarks[key] or {}
		tallyMarks[key][member] = true
		local n = 0
		for _ in pairs(tallyMarks[key]) do n = n + 1 end
		return n
	end
	-- fenêtre de 14 jours après la première capture du compte
	s.ok("sans capture : ouvert", NS:TrainerMentorOpen())
	NS:CaptureData().firstAt = now - 13 * 86400
	s.ok("13 jours après la première capture : ouvert", NS:TrainerMentorOpen())
	NS:CaptureData().firstAt = now - 15 * 86400
	s.ok("15 jours après : fermé", not NS:TrainerMentorOpen())
	local f = OpenJournal("dresseurs")
	local view = f.community.views.dresseurs
	s.ok("fermé : pas d'encadré, 5 lignes possibles", not Shown(view.mentor))
	NS:CaptureData().firstAt = now - 2 * 86400
	NS:CommunityTrainersPaint()
	s.ok("ouvert : l'encadré doré de la maquette", Shown(view.mentor) and view.mentor.selected == true
		and view.mentor.title:GetText() == "Quelqu'un t'a fait découvrir Quest Companion ?"
		and view.mentor.button:GetText() == "Désigner mon parrain")
	s.ok("il ne promet pas plus que l'addon : « quand vos addons se croisent en jeu »",
		view.mentor.text:GetText():find("quand vos addons se croisent en jeu", 1, true) ~= nil)
	-- des dresseurs connus : un en jeu, un par code, un d'un autre royaume, un de mes personnages
	Receive("p=1;n=Mentor;sp=500;sy=20;fb=", "Mentor-Royaume", "GUILD")
	NS:TrainerKnownOpenCode(NS:TrainerCodeOf({ name = "Codeux-Royaume", species = 5, showcase = {}, badges = {} }, "A"))
	NS:TrainerKnownOpenCode(NS:TrainerCodeOf({ name = "Loin-Hyjal", species = 5, showcase = {}, badges = {} }, "A"))
	NS:DB().chars["Alt-Royaume"] = {}
	NS:TrainerKnownAdd({ name = "Alt-Royaume", species = 1, showcase = {}, badges = {} }, "group")
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	NS:CommunityTrainersPaint()
	local function RowOf(key)
		for i, row in ipairs(view.rows) do if row.key == key then return i, row end end
	end
	-- choix : clic sur le bouton, puis sur une ligne
	view.mentor.button:Click()
	s.ok("« Désigner » : on choisit dans la liste (ou son code d'abord)", f.community.mentorState == "pick"
		and view.mentor.text:GetText():find("Ouvre-le d'abord", 1, true) ~= nil and Shown(view.mentor.cancel))
	local altIndex = RowOf("alt-royaume")
	view.rows[altIndex]:Click("LeftButton")
	s.ok("un de mes personnages : refusé", f.community.mentorState == "pick" and view.mentor.text:GetText() == NS.L.COM_TR_MENTOR_SELF)
	s.ok("soi-même ou un personnage du compte : refusé par la fonction", select(2, NS:TrainerMentorDesignate("alt-royaume")) == "self"
		and NS:TrainerMentorData().key == nil)
	-- ce que l'encadré dit avant de confirmer, selon qu'on peut prévenir ou non
	local reach = {}
	for _, key in ipairs({ "mentor-royaume", "codeux-royaume", "loin-hyjal" }) do
		f.community.mentorState = "pick"
		local i = RowOf(key)
		view.rows[i]:Click("LeftButton")
		reach[key] = view.mentor.text:GetText()
	end
	s.ok("en jeu : « la prochaine fois que vous vous croiserez »", reach["mentor-royaume"] == NS.L.COM_TR_MENTOR_REACH_game)
	s.ok("par code : ne peut pas prévenir d'ici", reach["codeux-royaume"] == NS.L.COM_TR_MENTOR_REACH_maybe)
	s.ok("autre royaume : jamais prévenu, dis-le-lui", reach["loin-hyjal"] == NS.L.COM_TR_MENTOR_REACH_never)
	view.mentor.cancel:Click()
	s.ok("« Annuler » : retour à l'offre", f.community.mentorState == nil and view.mentor.button:GetText() == "Désigner mon parrain")
	-- le parrain n'a pas été vu depuis longtemps (hors ligne) : rien ne part, le message attend
	Pump()
	NS:TrainerKnownResetSession()
	sent = {}
	local items = NS:CaptureData().items
	local lasso, sifflet = items.lasso or 0, items.sifflet or 0
	view.mentor.button:Click()
	view.rows[RowOf("mentor-royaume")]:Click("LeftButton")
	view.mentor.button:Click()
	Pump()
	s.ok("désigné une fois : le parrain gardé, l'encadré disparaît", NS:TrainerMentorData().key == "mentor-royaume"
		and not NS:TrainerMentorOpen() and not Shown(view.mentor))
	s.ok("le filleul reçoit 2 lassos et 1 sifflet", (items.lasso or 0) == math.min(lasso + 2, 5) and (items.sifflet or 0) == math.min(sifflet + 1, 3),
		tostring(items.lasso) .. "/" .. tostring(items.sifflet))
	s.ok("parrain hors ligne : aucun message envoyé", #sent == 0, #sent)
	s.ok("une seule fois : pas de deuxième désignation", select(2, NS:TrainerMentorDesignate("codeux-royaume")) == "closed"
		and NS:TrainerMentorData().key == "mentor-royaume")
	-- il revient (un message de son addon) : le message part, une fois
	NS:TrainerOnAddonMessage("QCTrainer", "H~1", "GUILD", "Mentor-Royaume")
	Pump()
	local asks = {}
	for _, msg in ipairs(sent) do if msg.text == "M~1~ask" then asks[#asks + 1] = msg end end
	s.ok("croisé ensuite : « M~1~ask » en chuchotement invisible", #asks == 1 and asks[1].prefix == "QCTrainer" and asks[1].channel == "WHISPER"
		and asks[1].target == "Mentor-Royaume")
	NS:TrainerOnAddonMessage("QCTrainer", "A~1", "WHISPER", "Mentor-Royaume")
	Pump()
	local again = 0
	for _, msg in ipairs(sent) do if msg.text == "M~1~ask" then again = again + 1 end end
	s.ok("pas renvoyé à chaque message (une minute au moins)", again == 1)
	-- sa réponse : prévenu, plus rien ne part
	NS:TrainerOnAddonMessage("QCTrainer", "M~1~ok", "WHISPER", "Mentor-Royaume")
	s.ok("« M~1~ok » : parrain prévenu", NS:TrainerMentorData().ok == true)
	now = now + 3600
	Mock.now = Mock.now + 3600
	NS:TrainerOnAddonMessage("QCTrainer", "H~1", "GUILD", "Mentor-Royaume")
	Pump()
	local after = 0
	for _, msg in ipairs(sent) do if msg.text == "M~1~ask" then after = after + 1 end end
	s.ok("prévenu : plus jamais renvoyé", after == 1)
	-- côté parrain : un filleul, compté une fois même reçu deux fois ; réponse
	sent = {}
	NS:TrainerOnAddonMessage("QCTrainer", "M~1~ask", "WHISPER", "Filleul-Royaume")
	NS:TrainerOnAddonMessage("QCTrainer", "M~1~ask", "WHISPER", "Filleul-Royaume")
	Pump()
	local oks = 0
	for _, msg in ipairs(sent) do if msg.text == "M~1~ok" and msg.target == "Filleul-Royaume" then oks = oks + 1 end end
	local mentees = {}
	for _, mark in ipairs(marks) do if mark:find("^mentees:") then mentees[#mentees + 1] = mark end end
	s.ok("parrain : ns:TallyMark(\"mentees\", clé du filleul)", mentees[1] == "mentees:filleul-royaume", table.concat(mentees, ","))
	s.ok("reçu deux fois : un seul filleul", tallyMarks.mentees and next(tallyMarks.mentees) == "filleul-royaume"
		and next(tallyMarks.mentees, "filleul-royaume") == nil)
	s.ok("réponse « M~1~ok », une seule", oks == 1, oks)
	-- un de mes personnages ne me parraine pas
	NS:TrainerOnAddonMessage("QCTrainer", "M~1~ask", "WHISPER", "Alt-Royaume")
	s.ok("un personnage du compte : pas de filleul", not (tallyMarks.mentees and tallyMarks.mentees["alt-royaume"]))
	-- un message M inconnu ou mal formé : rien, sans erreur
	s.ok("message mal formé : sans erreur", pcall(NS.TrainerOnAddonMessage, NS, "QCTrainer", "M~1", "WHISPER", "X-Royaume")
		and pcall(NS.TrainerOnAddonMessage, NS, "QCTrainer", "M~1~zzz~1", "WHISPER", "X-Royaume"))
	-- le message tient dans un message d'addon ; un type inconnu d'une 3.6 n'y fait rien (« A et tout type
	-- inconnu : le détenteur est noté, rien d'autre » dans TrainerCard.lua de la 3.6)
	s.ok("message court (≤ 255 octets)", #"M~1~ask" <= NS.TRAINER_MAX_MSG)
	s.check("[S2-MENTOR] parrainage : 14 jours, une fois, jamais soi-même ni ses personnages, encadré honnête, attente puis envoi, reçu deux fois = un")
	Done()
end

-- 9. Parrain par code, autre royaume ; partage coupé -------------------------------------------
do
	Reset()
	local s = Steps()
	NS:TrainerKnownOpenCode(NS:TrainerCodeOf({ name = "Loin-Hyjal", species = 5, showcase = {}, badges = {} }, "A"))
	local ok, reach = NS:TrainerMentorDesignate("loin-hyjal")
	NS:TrainerOnAddonMessage("QCTrainer", "H~1", "GUILD", "Loin-Hyjal")
	Pump()
	local asks = 0
	for _, msg in ipairs(sent) do if msg.text == "M~1~ask" then asks = asks + 1 end end
	s.ok("autre royaume : désigné, jamais de message", ok and reach == "never" and asks == 0)
	-- partage coupé : l'addon reste muet
	Reset()
	Receive("p=1;n=Mentor;sp=5;fb=", "Mentor-Royaume", "GUILD")
	NS:DB().trainerShare = false
	sent = {}
	NS:TrainerMentorDesignate("mentor-royaume")
	NS:TrainerOnAddonMessage("QCTrainer", "H~1", "GUILD", "Mentor-Royaume")
	Pump()
	asks = 0
	for _, msg in ipairs(sent) do if msg.text == "M~1~ask" then asks = asks + 1 end end
	s.ok("partage de fiche coupé : rien ne part (en attente)", asks == 0 and NS:TrainerMentorData().ok == nil)
	NS:DB().trainerShare = nil
	s.check("[S2-MENTOR] autre royaume : jamais de message ; partage coupé : muet")
	Done()
end

-- 10. Contrastes sur le vrai fond ---------------------------------------------------------------
do
	for _, style in ipairs({ "sobre", "azeroth" }) do
		Reset(style)
		local s = Steps()
		Receive("p=1;n=Xan;t=Maîtresse des brillantes;sp=287;sy=9;ap=1000;aq=105;ac=90;fb=AB", "Xan-Royaume", "GUILD")
		NS:TrainerKnownOpenCode(NS:TrainerCodeOf({ name = "Brakmar-Hyjal", species = 512, shinies = 31, showcase = {}, badges = {} }, "A"))
		if NS.trainerFrame then NS.trainerFrame:Hide() end
		local f = OpenJournal("dresseurs")
		local pane = f.community
		local view = pane.views.dresseurs
		local forged = Theme.Forged()
		local K = Theme.FORGE_CARD
		local tile = forged and { Theme.Over(Theme.ROW, Theme.WHITE, K.light), Theme.Over(Theme.ROW, Theme.SHADOW, K.dark) } or { Theme.ROW }
		-- ligne paire : son fond un peu plus clair
		local alt = Theme.Over(Theme.ROW, Theme.WHITE, 0.02)
		tile[#tile + 1] = forged and Theme.Over(alt, Theme.WHITE, K.light) or alt
		local grounds = {
			page = { Theme.WINDOW }, tile = tile,
			field = forged and { Theme.ForgeSurface(Theme.EDGE, Theme.FORGE.insetFill), Theme.ForgeSurface(Theme.ACTIVE, Theme.FORGE.insetFill),
				{ 0, 0, 0 } } or { Theme.FIELD },
			chip = { Theme.WINDOW, Theme.Over(Theme.WINDOW, Theme.SELECT, forged and Theme.SelectAlpha(Theme.FORGE_CHIP.from) or 0.12) },
		}
		local worst, where = math.huge, ""
		local function Probe(name, ink, list, need)
			for _, bg in ipairs(list) do
				local c = Theme.Contrast(ink, bg)
				if c < need then s.ok(name, false, string.format("%.2f", c)) end
				if c < worst then worst, where = c, string.format("%s %.2f", name, c) end
			end
		end
		-- les textes de l'onglet (lignes, encadré, note, champs, filtres)
		local mine = {}
		for _, region in ipairs({ view.empty, view.note, view.mine.status, view.open.status, view.mentor.title, view.mentor.text,
			view.mine.box, view.open.box, view.open.box.placeholder }) do mine[#mine + 1] = region end
		for _, row in ipairs(view.rows) do
			mine[#mine + 1] = row.name; mine[#mine + 1] = row.line; mine[#mine + 1] = row.seen
		end
		for _, chip in ipairs(view.filters.chips) do mine[#mine + 1] = chip.text end
		local count = 0
		for _, text in ipairs(mine) do
			local ink = text.comInk
			if ink and grounds[text.comGround] then
				count = count + 1
				Probe(text.comGround .. " « " .. tostring(text:GetText() or ""):sub(1, 24) .. " »", ink, grounds[text.comGround], 4.5)
			end
		end
		-- les phrases d'état (vert, libellé) et les titres (≥ 3) sur la tuile
		Probe("phrase verte", Theme.GREEN, grounds.tile, 4.5)
		Probe("phrase d'erreur", Theme.LABEL, grounds.tile, 4.5)
		Probe("titre de l'encadré", Theme.PARCHMENT, grounds.tile, 3)
		-- intertitres : celui de la page, et ceux des deux tuiles (sur la tuile)
		Probe("intertitre « dresseurs connus »", { view.knownHead.label:GetTextColor() }, grounds.page, 4.5)
		Probe("intertitre « mon code »", { view.mine.head.label:GetTextColor() }, grounds.tile, 4.5)
		Probe("intertitre « ouvrir un code »", { view.open.head.label:GetTextColor() }, grounds.tile, 4.5)
		Probe("compteur", pane.tabNote.comInk, grounds.page, 4.5)
		s.ok("les textes de l'onglet mesurés", count >= 20, count)
		Say("-- dresseurs, contraste le plus faible (" .. style .. ") : " .. where)
		s.check("[S2-CONTRAST] " .. style .. " : contrastes de l'onglet Dresseurs sur leur vrai fond (≥ 4,5 texte, ≥ 3 titres)")
		Done()
	end
end

-- 11. Textes, rien ne sort ----------------------------------------------------------------------
do
	local s = Steps()
	local missing, glyphs = {}, {}
	for _, pack in ipairs({ NS.TRAINER_CODE_STRINGS, NS.TRAINER_KNOWN_STRINGS }) do
		for key, value in pairs(pack.fr) do
			if type(pack.en[key]) ~= "string" or pack.en[key] == "" or value == "" then missing[#missing + 1] = key end
		end
		for key in pairs(pack.en) do if pack.fr[key] == nil then missing[#missing + 1] = key end end
		for _, lang in ipairs({ "fr", "en" }) do
			for key, value in pairs(pack[lang]) do
				for _, glyph in ipairs({ "\226\152\133", "\226\152\134", "\226\156\147", "\226\156\148", "\226\156\151", "\226\156\152" }) do
					if value:find(glyph, 1, true) then glyphs[#glyphs + 1] = lang .. ":" .. key end
				end
			end
		end
	end
	s.ok("chaque texte en français et en anglais", #missing == 0, table.concat(missing, ","))
	s.ok("jamais ★ ☆ ✓ ✗", #glyphs == 0, table.concat(glyphs, ","))
	local function Source(path)
		local handle = io.open(ROOT .. "/" .. path, "r")
		local text = handle and handle:read("*a") or ""
		if handle then handle:close() end
		return text
	end
	local code, known = Source("QuestCompanion/TrainerCode.lua"), Source("QuestCompanion/TrainerKnown.lua")
	s.ok("le code ne s'envoie nulle part (aucune fonction d'envoi dans TrainerCode.lua)", code ~= ""
		and not code:find("SendChatMessage", 1, true) and not code:find("SendAddonMessage", 1, true) and not code:find("TrainerSend", 1, true))
	s.ok("TrainerKnown.lua : seul le parrainage envoie (TrainerSend « M »), jamais de chat", known ~= ""
		and not known:find("SendChatMessage", 1, true) and not known:find("SendAddonMessage", 1, true)
		and select(2, known:gsub("TrainerSend%(\"M\"", "")) == 2)
	s.ok("aucune couleur codée en dur", not code:find("|c%x%x%x%x%x%x%x%x") and not known:find("|c%x%x%x%x%x%x%x%x")
		and not known:find("SetTextColor%(%s*[%d%.]") and not known:find("SetVertexColor%(%s*[%d%.]"))
	s.ok("le bouton « Code de dresseur » du pied existe (ns.TrainerCodeShow)", type(NS.TrainerCodeShow) == "function")
	s.check("[S2-TEXT] textes FR/EN sans glyphe ; rien ne sort du code ; seul le parrainage parle aux autres addons")
end

-- 12. Le pied de ma fiche : « Code de dresseur » ouvre l'onglet ----------------------------------
do
	Reset("azeroth")
	local s = Steps()
	local f = NS:TrainerOpen(nil)
	s.ok("pied de ma fiche : « Code de dresseur » visible", Shown(f.codeButton) and f.codeButton:GetText() == "Code de dresseur")
	f.codeButton:Click()
	s.ok("clic : la page Communauté, onglet Dresseurs", NS.journalFrame and NS.journalFrame:IsShown() and NS.journalFrame.kind == "community"
		and NS.journalFrame.community.tab == "dresseurs" and not f:IsShown())
	s.check("[S2-FOOT] « Code de dresseur » au pied de ma fiche : la page Communauté sur l'onglet Dresseurs")
	Done()
end
