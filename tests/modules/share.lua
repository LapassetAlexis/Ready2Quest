-- « Partager » (QuestCompanion 3.1.0, Share.lua) : un beau moment dans le
-- chat, au clic du joueur seulement. Bouton sur les bandeaux (« Capturé ! »
-- notable, haut fait seul ou groupé, sceau, titre) et la scène Azeroth ;
-- entrée sur la fiche de la Réserve et au clic droit d'un haut fait obtenu ;
-- menu des seuls canaux disponibles ; textes FR / EN, 255 caractères, sans
-- étoile ★ ni code d'échappement ; anti-spam ; réglage qui cache le bouton
-- des bandeaux ; file des bandeaux intacte ; « Copier » remplit la saisie
-- sans envoyer.
-- 3.1.0 : affirme l'ancien habillage (carnet en parchemin, scènes en bois, bandeaux
-- dorés, anneau) : le drapeau QNS.AZEROTH_LEGACY rallumé pour tout le module
-- (remis à la valeur du produit à sa fin, tests/run_tests.lua)
T.Legacy(true)
local Check, Say, ResetWorld, Mock = T.Check, T.Say, T.ResetWorld, T.Mock
local NS = T.QNS
local Theme = NS.Theme

local SH = { saved = {}, sends = {}, opened = {}, inserted = {} }
-- même couleur, les trois composantes
local function Same(a, b)
	return type(a) == "table" and type(b) == "table" and math.abs(a[1] - b[1]) < 1e-6
		and math.abs(a[2] - b[2]) < 1e-6 and math.abs(a[3] - b[3]) < 1e-6
end
local GLOBALS = { "SendChatMessage", "IsInGuild", "IsInRaid", "IsInGroup", "IsInInstance", "ChatFrame_OpenChat",
	"ChatEdit_GetActiveWindow", "ChatEdit_InsertLink", "C_ChatInfo", "ChatFrameUtil", "InCombatLockdown", "UnitAffectingCombat" }
for _, name in ipairs(GLOBALS) do SH.saved[name] = rawget(_G, name) end
SH.rollSize = NS.SpecimenRollSize

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

-- le monde : guilde, groupe, raid, instance, zone de saisie ouverte
function SH.World(opts)
	opts = opts or {}
	SH.sends, SH.opened, SH.inserted = {}, {}, {}
	_G.SendChatMessage = function(text, channel) SH.sends[#SH.sends + 1] = { text = text, channel = channel } end
	_G.C_ChatInfo = nil
	_G.ChatFrameUtil = nil
	_G.IsInGuild = function() return opts.guild == true end
	_G.IsInRaid = function() return opts.raid == true end
	_G.IsInGroup = function(category)
		if category == 2 then return opts.instance == true end
		return opts.party == true or opts.raid == true
	end
	_G.IsInInstance = function() return opts.inside == true, opts.inside and "party" or "none" end
	_G.ChatFrame_OpenChat = function(text) SH.opened[#SH.opened + 1] = text end
	_G.ChatEdit_GetActiveWindow = function() return opts.box and {} or nil end
	_G.ChatEdit_InsertLink = function(text) SH.inserted[#SH.inserted + 1] = text; return true end
	_G.InCombatLockdown = function() return SH.combat == true end
	_G.UnitAffectingCombat = function() return SH.combat == true end
end

function SH.Reset(opts)
	ResetWorld()
	SH.World(opts)
	NS.journalToasts, NS.journalToastHideAt = {}, nil
	if NS.journalToast then NS.journalToast:Hide() end
	NS:GuildFeatsReset()
	NS.captureResultPending = nil
	NS:CaptureResultHide()
	if NS.captureToast then NS.captureToast:Hide() end
	NS.bannerLane.showing, NS.bannerLane.frame, NS.bannerLane.waiting = nil, nil, {}
	if NS.shareMenu then NS.shareMenu:Hide() end
	NS.shareLog = { last = nil, sent = {} }
	NS.announceQueue, NS.announceLog, NS.announceErrorNoted = {}, {}, nil
	SH.combat = false
	Mock:Reset()
end

function SH.Restore()
	for _, name in ipairs(GLOBALS) do _G[name] = SH.saved[name] end
	NS.SpecimenRollSize = SH.rollSize
end

function SH.Step(dt)
	Mock.now = Mock.now + (dt or 0)
	NS:UpdateJournalToast(NS.Now())
	NS:GuildFeatsToastTick(NS.Now())
	NS:CaptureResultTick(NS.Now())
end

-- les entrées du menu ouvert, dans l'ordre
function SH.Menu()
	local list, menu = {}, NS.shareMenu
	if not (menu and menu:IsShown()) then return list end
	for _, row in ipairs(menu.rows) do if row:IsShown() then list[#list + 1] = row.channel end end
	return list
end
function SH.Pick(channel)
	for _, row in ipairs((NS.shareMenu and NS.shareMenu.rows) or {}) do
		if row:IsShown() and row.channel == channel then row:Click("LeftButton"); return true end
	end
	return false
end
local function Shown(button) return button ~= nil and button:IsShown() end

function SH.Feat(name, pts) return { kind = "feat", id = "men_first", title = "Haut fait obtenu", name = name, points = pts or 5 } end
local STAR = "\226\152\133"
local HOLLOW = "\226\152\134"

-- 1. Jamais d'envoi sans clic --------------------------------------------------------------
do
	local s = Steps()
	SH.Reset({ guild = true, party = true })
	NS:JournalToastPush(SH.Feat("Premier filet"))
	NS:JournalToastPush({ kind = "seal", name = "Durotar" })
	NS:JournalToastPush({ kind = "rank", name = "Dresseur" })
	NS:CaptureResultQueue({ name = "Raptor", shiny = true, stars = 3, npcID = 7001, class = "normal" })
	NS:GuildFeatsEnqueue({ key = "bob", sender = "bob", feat = { kind = "n" }, info = { kind = "n", line = "Bob !", sub = "Raptor" },
		score = 1, at = Mock.now })
	local seen = {}
	for _ = 1, 240 do
		SH.Step(0.25)
		local j, r = NS.journalToast, NS.captureResult
		if j and j:IsShown() and Shown(j.shareButton) and j.entry then seen[j.entry.kind] = true end
		if r and r:IsShown() and Shown(r.shareButton) then seen.result = true end
	end
	s.ok("bouton sur le haut fait, le sceau, le titre, le « Capturé ! »", seen.feat and seen.seal and seen.rank and seen.result,
		(seen.feat and "f" or "") .. (seen.seal and "s" or "") .. (seen.rank and "r" or "") .. (seen.result and "c" or ""))
	s.ok("aucun envoi pendant les bandeaux", #SH.sends == 0, #SH.sends)
	-- un clic sur le bouton : le menu, toujours rien d'envoyé
	NS:JournalToastPush(SH.Feat("Premier filet"))
	local button = NS.journalToast and NS.journalToast.shareButton
	s.ok("bouton affiché", Shown(button))
	if button then button:Click("LeftButton") end
	s.ok("clic : le menu, sans envoi", NS.shareMenu and NS.shareMenu:IsShown() and #SH.sends == 0)
	s.ok("une entrée choisie : un envoi", SH.Pick("GUILD") and #SH.sends == 1 and SH.sends[1].channel == "GUILD")
	s.ok("le texte", SH.sends[1] and SH.sends[1].text == "[Quest Companion] Testeur a obtenu le haut fait « Premier filet » (5 points) !",
		SH.sends[1] and SH.sends[1].text)
	s.ok("menu refermé", not NS.shareMenu:IsShown())
	-- second clic sur le bouton : le menu se referme, rien ne part
	SH.Step(11)
	button:Click("LeftButton"); button:Click("LeftButton")
	s.ok("second clic : menu refermé, rien de plus", not NS.shareMenu:IsShown() and #SH.sends == 1)
	-- un « Capturé ! » ordinaire : pas de bouton
	SH.Reset({ guild = true })
	NS:CaptureResultQueue({ name = "Loup", stars = 1, npcID = 7002, class = "normal" })
	SH.Step(0)
	local r = NS.captureResult
	s.ok("capture ordinaire : pas de bouton", r and r:IsShown() and not Shown(r.shareButton))
	-- un lot de tampons (sans entrée) : pas de bouton
	SH.Reset()
	for i = 1, 6 do NS:JournalNotify({ kind = "zone", name = "Zone " .. i, id = "zone:" .. i }) end
	s.ok("lot de tampons : pas de bouton", NS.journalToast:IsShown() and not Shown(NS.journalToast.shareButton))
	SH.Reset()
	s.check("[SHARE] aucun SendChatMessage sans clic : bandeaux, bouton, menu ; un envoi par entrée choisie")
end

-- 2. Le menu : les seuls canaux disponibles ------------------------------------------------
do
	local s = Steps()
	local function Channels(opts)
		SH.Reset(opts)
		NS:ShareOpen(nil, { kind = "seal", name = "Durotar", key = "seal:Durotar" })
		local list = table.concat(SH.Menu(), ",")
		NS.shareMenu:Hide()
		return list
	end
	s.ok("seul, sans guilde : Dire, Copier", Channels({}) == "SAY,COPY", Channels({}))
	s.ok("en guilde : Guilde d'abord", Channels({ guild = true }) == "GUILD,SAY,COPY", Channels({ guild = true }))
	s.ok("en groupe : Groupe", Channels({ party = true }) == "PARTY,SAY,COPY", Channels({ party = true }))
	s.ok("en raid : Raid, pas Groupe", Channels({ guild = true, raid = true }) == "GUILD,RAID,SAY,COPY",
		Channels({ guild = true, raid = true }))
	s.ok("groupe d'instance seulement", Channels({ instance = true }) == "INSTANCE_CHAT,SAY,COPY", Channels({ instance = true }))
	local labels = {}
	SH.Reset({ guild = true, party = true })
	NS:ShareOpen(nil, { kind = "seal", name = "Durotar" })
	for _, row in ipairs(NS.shareMenu.rows) do if row:IsShown() then labels[#labels + 1] = row.text:GetText() end end
	s.ok("libellés", table.concat(labels, ",") == "Guilde,Groupe,Dire,Copier", table.concat(labels, ","))
	s.ok("jamais Général, Commerce ni recherche de groupe", not table.concat(NS.SHARE_CHANNELS, ","):find("CHANNEL", 1, true))
	SH.Reset()
	s.check("[SHARE] menu : seuls les canaux disponibles (Guilde, Raid ou Groupe, Dire, Copier)")
end

-- 3. Textes FR / EN ---------------------------------------------------------------------
do
	local s = Steps()
	SH.Reset()
	local function Same(label, item, lang, want)
		item.who = "Dyokrion"
		local text = NS:ShareText(item, lang)
		s.ok(label .. " " .. lang, text == want, text)
		return text
	end
	local cases = {}
	local shiny = { kind = "capture", name = "Raptor", shiny = true, stars = 3, size = "large" }
	cases[#cases + 1] = Same("brillant 3 étoiles", shiny, "fr", "[Quest Companion] Dyokrion a capturé un Raptor brillant (3 étoiles, Grand) !")
	cases[#cases + 1] = Same("brillant 3 étoiles", shiny, "en", "[Quest Companion] Dyokrion captured a shiny Raptor (3 stars, Large)!")
	local fresh = { kind = "capture", name = "Ourson", stars = 1, class = "elite", fresh = true, size = "normal" }
	cases[#cases + 1] = Same("espèce nouvelle", fresh, "fr", "[Quest Companion] Dyokrion a capturé un Ourson (1 étoile, élite, nouvelle espèce) !")
	fresh.name = "Owlkin"
	cases[#cases + 1] = Same("espèce nouvelle", fresh, "en", "[Quest Companion] Dyokrion captured an Owlkin (1 star, elite, new species)!")
	local feat = { kind = "feat", name = "Marchand de créatures", points = 10 }
	cases[#cases + 1] = Same("haut fait", feat, "fr", "[Quest Companion] Dyokrion a obtenu le haut fait « Marchand de créatures » (10 points) !")
	feat.name = "Creature dealer"
	cases[#cases + 1] = Same("haut fait", feat, "en", "[Quest Companion] Dyokrion earned the achievement \"Creature dealer\" (10 points)!")
	local one = { kind = "feat", name = "Premier filet", points = 1 }
	cases[#cases + 1] = Same("haut fait à 1 point", one, "fr", "[Quest Companion] Dyokrion a obtenu le haut fait « Premier filet » (1 point) !")
	local many = { kind = "feats", count = 3, points = 25, names = { "Premiers pas", "Sur la route", "Vétéran" } }
	cases[#cases + 1] = Same("groupés", many, "fr",
		"[Quest Companion] Dyokrion a obtenu 3 hauts faits (25 points) : « Premiers pas », « Sur la route », « Vétéran » !")
	cases[#cases + 1] = Same("groupés", many, "en",
		"[Quest Companion] Dyokrion earned 3 achievements (25 points): \"Premiers pas\", \"Sur la route\", \"Vétéran\"!")
	local catchup = { kind = "feats", count = 4, points = 20 }
	cases[#cases + 1] = Same("rattrapage sans noms", catchup, "fr", "[Quest Companion] Dyokrion a obtenu 4 hauts faits (20 points) !")
	cases[#cases + 1] = Same("sceau", { kind = "seal", name = "Durotar" }, "fr", "[Quest Companion] Dyokrion a scellé la zone Durotar !")
	cases[#cases + 1] = Same("sceau", { kind = "seal", name = "Durotar" }, "en", "[Quest Companion] Dyokrion sealed the zone Durotar!")
	cases[#cases + 1] = Same("titre", { kind = "title", name = "Dresseur" }, "fr", "[Quest Companion] Dyokrion porte maintenant le titre « Dresseur » !")
	cases[#cases + 1] = Same("titre", { kind = "title", name = "Trainer" }, "en", "[Quest Companion] Dyokrion now bears the title \"Trainer\"!")
	-- un lot interminable : coupé avant 255, toujours une phrase finie
	local long = { kind = "feats", count = 40, points = 400, names = {} }
	for i = 1, 40 do long.names[i] = "Haut fait au nom très long " .. i end
	for _, lang in ipairs({ "fr", "en" }) do
		long.who = "Dyokrion"
		local text = NS:ShareText(long, lang)
		cases[#cases + 1] = text
		s.ok("lot long " .. lang .. " : ≤ 255 et fini par « … »", #text <= 255 and text:find("…", 1, true) ~= nil
			and text:find(lang == "fr" and " !$" or "!$") ~= nil, #text .. " " .. text)
	end
	-- nom piégé : codes retirés, nom gardé ; un vrai lien d'objet reste
	local dirty = { kind = "capture", name = "|cffff0000Raptor|r|TInterface\\Icons\\X:0|t|Hunit:1|h|h", stars = 2, who = "Dyo|rkrion" }
	local clean = NS:ShareText(dirty, "fr")
	cases[#cases + 1] = clean
	s.ok("codes retirés", clean == "[Quest Companion] Dyokrion a capturé un Raptor (2 étoiles) !", clean)
	local link = "|cff1eff00|Hitem:2589::::::::20:::::::|h[Étoffe de lin]|h|r"
	s.ok("vrai lien d'objet gardé", NS.ShareClean("Avec " .. link .. " |cffffffffsans|r") == "Avec " .. link .. " sans",
		NS.ShareClean("Avec " .. link))
	-- chaque texte : ≤ 255, sans étoile ★ / ☆, sans barre (hors lien d'objet), une ligne
	local bad = {}
	for index, text in ipairs(cases) do
		if type(text) ~= "string" or #text > 255 or text:find(STAR, 1, true) or text:find(HOLLOW, 1, true)
			or text:find("|", 1, true) or text:find("\n", 1, true) then bad[#bad + 1] = tostring(index) end
	end
	s.ok("≤ 255, sans ★, sans |, une ligne", #bad == 0, table.concat(bad, ","))
	-- textes FR / EN complets, tutoiement
	local missing = {}
	local strings = NS.SHARE_STRINGS
	for key in pairs(strings.fr) do if not strings.en[key] then missing[#missing + 1] = "en:" .. key end end
	for key in pairs(strings.en) do if not strings.fr[key] then missing[#missing + 1] = "fr:" .. key end end
	s.ok("FR et EN complets", #missing == 0, table.concat(missing, ","))
	local vous = {}
	for key, text in pairs(strings.fr) do
		if text:find("vous", 1, true) or text:find("Vous", 1, true) or text:find("votre", 1, true) then vous[#vous + 1] = key end
	end
	s.ok("tutoiement", #vous == 0, table.concat(vous, ","))
	-- le client français : le texte du joueur, en français
	s.ok("langue du client", NS:ShareText({ kind = "seal", name = "Durotar" }) == "[Quest Companion] Testeur a scellé la zone Durotar !",
		NS:ShareText({ kind = "seal", name = "Durotar" }))
	s.check("[SHARE] textes : brillant, 3 étoiles, espèce nouvelle, haut fait seul et groupé, sceau, titre ; FR et EN ; ≤ 255 ; sans ★ ni code")
end

-- 4. Anti-spam ----------------------------------------------------------------------------
do
	local s = Steps()
	SH.Reset({ guild = true, inside = true })
	local item = { kind = "seal", name = "Durotar", key = "seal:Durotar" }
	local other = { kind = "title", name = "Dresseur", key = "title:Dresseur" }
	local function Share(it, channel) NS:ShareOpen(nil, it); return SH.Pick(channel) end
	Share(item, "GUILD")
	s.ok("premier partage", #SH.sends == 1)
	Mock:Reset()
	Share(other, "SAY")
	s.ok("moins de 10 s après : bloqué, dit dans le chat", #SH.sends == 1 and Mock:Output():find("Doucement", 1, true) ~= nil, Mock:Output())
	SH.Step(11)
	Mock:Reset()
	Share(item, "GUILD")
	s.ok("même chose, même canal, moins d'une minute : bloqué, dit", #SH.sends == 1
		and Mock:Output():find("Déjà partagé dans ce canal", 1, true) ~= nil, Mock:Output())
	Share(item, "SAY")
	s.ok("même chose, autre canal : permis", #SH.sends == 2 and SH.sends[2].channel == "SAY")
	SH.Step(11)
	Share(other, "GUILD")
	s.ok("autre chose, même canal, 10 s après : permis", #SH.sends == 3)
	SH.Step(61)
	Share(item, "GUILD")
	s.ok("une minute après : de nouveau permis", #SH.sends == 4)
	-- « Copier » n'envoie rien : jamais bloqué
	Share(item, "COPY")
	s.ok("Copier : pas d'envoi, pas de blocage", #SH.sends == 4 and #SH.opened == 1)
	SH.Reset()
	s.check("[SHARE] anti-spam : un partage par 10 s, la même chose au même canal une fois par minute, un mot dans le chat")
end

-- 5. Le réglage cache le bouton des bandeaux, pas les autres entrées --------------------
do
	local s = Steps()
	SH.Reset({ guild = true })
	NS:DB().shareBanner = false
	NS:JournalToastPush(SH.Feat("Premier filet"))
	local j = NS.journalToast
	s.ok("bandeau là, bouton caché", j:IsShown() and not Shown(j.shareButton))
	SH.Step(10)
	NS:CaptureResultQueue({ name = "Raptor", shiny = true, stars = 3, npcID = 7001, class = "normal" })
	SH.Step(0)
	local r = NS.captureResult
	s.ok("« Capturé ! » brillant : bouton caché", r:IsShown() and not Shown(r.shareButton))
	-- Réserve : l'entrée reste
	NS.SpecimenRollSize = function() return "large" end
	NS:CaptureData().creatures[950] = { name = "Raptor", normal = true, class = "elite" }
	NS:SpecimenAdd({ npc = 950, stars = 3, name = "Raptor", origin = "capture" })
	local res = NS:SpecimenAdd({ npc = 950, stars = 2, name = "Raptor", origin = "capture" })
	local f = NS:OpenReserve()
	NS:ReservePick(res)
	local p = f.res.reserve.preview
	s.ok("Réserve : bouton de la fiche", Shown(p.shareButton) and p.shareButton.item and p.shareButton.item.key == "cap:" .. tostring(res))
	p.shareButton:Click("LeftButton")
	s.ok("Réserve : menu, puis envoi au clic", NS.shareMenu:IsShown() and SH.Pick("GUILD") and #SH.sends == 1
		and SH.sends[1].text == "[Quest Companion] Testeur a capturé un Raptor (2 étoiles, Grand, élite) !", SH.sends[1] and SH.sends[1].text)
	NS:ReserveRelease(res)
	s.ok("Réserve : confirmation « Relâcher » à l'écran, pas de bouton", f.resConfirm == res and not Shown(p.shareButton))
	NS:ReserveCancelConfirm()
	s.ok("Réserve : confirmation annulée, le bouton revient", Shown(p.shareButton))
	-- Hauts faits : clic droit sur un obtenu
	NS:FeatAward("men_first", { silent = true })
	NS:DB().featsFilter = "got"
	local jf = NS:OpenJournalFeats("all")
	local row
	for _, candidate in ipairs(jf.feats.rows) do
		if candidate:IsShown() and candidate.def and candidate.def.id == "men_first" then row = candidate end
	end
	s.ok("Hauts faits : la ligne obtenue", row ~= nil)
	if row then
		row:Click("LeftButton")
		s.ok("clic gauche : rien", not NS.shareMenu:IsShown())
		row:Click("RightButton")
		local name = NS:FeatName("men_first")
		s.ok("clic droit : le menu, le haut fait", NS.shareMenu:IsShown() and NS.shareMenu.item and NS.shareMenu.item.name == name)
		SH.Step(11)
		s.ok("envoi au clic", SH.Pick("GUILD") and #SH.sends == 2 and SH.sends[2].text:find("« " .. name .. " »", 1, true) ~= nil,
			SH.sends[2] and SH.sends[2].text)
		-- l'infobulle le dit
		local lines = {}
		local savedLine = Theme.TooltipLine
		Theme.TooltipLine = function(_, text) lines[#lines + 1] = text end
		NS:JournalFeatsTip(row)
		Theme.TooltipLine = savedLine
		s.ok("infobulle : « Clic droit : partager »", table.concat(lines, "|"):find("Clic droit : partager", 1, true) ~= nil)
	end
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS:DB().shareBanner = nil
	NS:DB().featsFilter = nil
	-- réglage rallumé : le bouton revient
	NS:JournalToastPush(SH.Feat("Sur la route"))
	SH.Step(30)
	NS:JournalToastPush(SH.Feat("Sur la route"))
	s.ok("réglage rallumé : bouton de retour", j:IsShown() and Shown(j.shareButton))
	local row2 = nil
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "journal" then for _, r2 in ipairs(page.rows or {}) do if r2.key == "shareBanner" then row2 = r2 end end end
	end
	SH.Reset()
	s.ok("défaut actif ; réglage sur la page Carnet de voyage, libellé FR et EN", NS:DB().shareBanner == true and row2 ~= nil
		and row2.label == "OPT_SHARE_BANNER" and NS.SHARE_STRINGS.fr.OPT_SHARE_BANNER == "Bouton Partager sur les bandeaux"
		and NS.SHARE_STRINGS.en.OPT_SHARE_BANNER ~= nil)
	SH.Reset()
	SH.Restore()
	s.check("[SHARE] réglage « Bouton Partager sur les bandeaux » : cache le bouton des bandeaux ; Réserve et Hauts faits gardent leur entrée")
end

-- 6. La file des bandeaux tient ; un bouton par cadre, jamais un de plus -----------------
do
	local s = Steps()
	SH.Reset({ guild = true })
	local function Play(seconds)
		local order, most, last = {}, 0, nil
		for _ = 1, math.floor(seconds / 0.25) do
			local list = {}
			if NS.journalToast and NS.journalToast:IsShown() then list[#list + 1] = "journal" end
			if NS.guildFeatToast and NS.guildFeatToast:IsShown() then list[#list + 1] = "guild" end
			if NS.captureResult and NS.captureResult:IsShown() then list[#list + 1] = "result" end
			most = math.max(most, #list)
			if list[1] and list[1] ~= last then order[#order + 1] = list[1] end
			last = list[1]
			SH.Step(0.25)
		end
		return order, most
	end
	local function Round(n)
		NS:JournalToastPush(SH.Feat("Un " .. n))
		NS:GuildFeatsEnqueue({ key = "g" .. n, sender = "g" .. n, feat = { kind = "n" }, info = { kind = "n", line = "G !", sub = "Raptor" },
			score = 1, at = Mock.now })
		NS:CaptureResultQueue({ name = "Raptor", shiny = true, stars = 3, npcID = 7001, class = "normal" })
		return Play(40)
	end
	local order, most = Round(0)
	s.ok("un seul à la fois", most == 1, most)
	s.ok("ordre gardé : carnet, résultat, guilde", table.concat(order, ",") == "journal,result,guild", table.concat(order, ","))
	s.ok("place rendue", NS:BannerShowing() == nil)
	local frames = #Mock.frames
	local buttons = { NS.journalToast.shareButton, NS.captureResult.shareButton }
	for round = 1, 3 do Round(round) end
	s.ok("aucun cadre de plus", #Mock.frames == frames, #Mock.frames - frames)
	s.ok("mêmes boutons", NS.journalToast.shareButton == buttons[1] and NS.captureResult.shareButton == buttons[2] and buttons[1] ~= nil)
	-- menu ouvert : le bandeau reste un peu plus, puis la file reprend
	NS:JournalToastPush(SH.Feat("Encore"))
	SH.Step(0)
	NS.journalToast.shareButton:Click("LeftButton")
	SH.Step(30)
	s.ok("menu ouvert : le bandeau tient (même 30 s)", NS.journalToast:IsShown())
	NS.shareMenu:Hide()
	NS:CaptureResultQueue({ name = "Raptor", shiny = true, stars = 3, npcID = 7001, class = "normal" })
	local left = NS.journalToastHideAt and NS.journalToastHideAt - NS.Now()
	s.ok("menu fermé : encore 3 s au moins", NS.journalToast:IsShown() and left and left >= NS.SHARE_RESUME - 0.3, left)
	local order2 = Play(40)
	s.ok("puis la file reprend", table.concat(order2, ",") == "journal,result", table.concat(order2, ","))
	-- ouvrir le menu deux fois : un seul cadre de menu
	local before = #Mock.frames
	for _ = 1, 3 do NS:ShareOpen(nil, { kind = "seal", name = "X" }); NS.shareMenu:Hide() end
	s.ok("menu construit une fois", #Mock.frames == before)
	SH.Reset()
	s.check("[SHARE] file des bandeaux intacte avec le bouton ; un bouton par cadre réutilisé, un seul menu")
end

-- 7. « Copier » remplit la saisie sans envoyer ; « Dire » hors instance aussi ---------------
do
	local s = Steps()
	SH.Reset({ guild = true })
	local item = { kind = "seal", name = "Durotar", key = "seal:Durotar" }
	NS:ShareOpen(nil, item); SH.Pick("COPY")
	s.ok("saisie fermée : ChatFrame_OpenChat avec le texte", #SH.opened == 1
		and SH.opened[1] == "[Quest Companion] Testeur a scellé la zone Durotar !" and #SH.sends == 0, SH.opened[1])
	SH.World({ guild = true, box = true })
	NS:ShareOpen(nil, item); SH.Pick("COPY")
	s.ok("saisie ouverte : inséré à la suite, rien d'envoyé", #SH.inserted == 1 and #SH.opened == 0 and #SH.sends == 0)
	-- client sans ChatFrame_OpenChat : ChatFrameUtil.OpenChat
	SH.World({})
	_G.ChatFrame_OpenChat = nil
	local util = {}
	_G.ChatFrameUtil = { OpenChat = function(text) util[#util + 1] = text end }
	NS:ShareOpen(nil, item); SH.Pick("COPY")
	s.ok("repli ChatFrameUtil.OpenChat", #util == 1 and #SH.sends == 0)
	-- « Dire » hors instance : le jeu le réserve au joueur, le texte attend en mode Dire
	SH.World({ inside = false })
	Mock:Reset()
	NS:ShareOpen(nil, item); SH.Pick("SAY")
	s.ok("Dire hors instance : pas d'envoi, saisie en /s", #SH.sends == 0 and SH.opened[1] and SH.opened[1]:find("^/s %[Quest Companion%]") ~= nil
		and Mock:Output():find("Hors instance", 1, true) ~= nil, SH.opened[1])
	SH.World({ inside = true })
	NS:ShareOpen(nil, item); SH.Pick("SAY")
	s.ok("Dire en instance : envoyé", #SH.sends == 1 and SH.sends[1].channel == "SAY")
	SH.Reset()
	SH.Restore()
	s.check("[SHARE] « Copier » remplit la zone de saisie sans envoyer ; « Dire » hors instance aussi")
end

-- 8. Les deux styles : bouton, scène Azeroth, menu habillé, contrastes mesurés -----------
do
	local s = Steps()
	-- Sobre : textes du menu lisibles (pire cas : survol)
	local hover = Theme.Over(Theme.NAV, Theme.WHITE, Theme.HOVER_ALPHA)
	s.ok("Sobre : entrée LABEL ≥ 4,5:1 au survol", Theme.Contrast(Theme.LABEL, hover) >= 4.5, Theme.Contrast(Theme.LABEL, hover))
	s.ok("Sobre : titre MUTED_LIGHT ≥ 4,5:1", Theme.Contrast(Theme.MUTED_LIGHT, Theme.NAV) >= 4.5)
	local C = NS.AZEROTH_CONTRAST
	s.ok("Azeroth : rôles share.* mesurés", C["share.title"] and C["share.entry"]
		and Theme.Contrast(NS.AZEROTH_INK[C["share.entry"][1]], C["share.entry"][2]) >= 4.5
		and Theme.Contrast(NS.AZEROTH_INK[C["share.title"][1]], C["share.title"][2]) >= 4.5)
	-- Azeroth : bandeaux dorés, bouton posé sous le bouclier, menu sur le bois
	SH.Reset({ guild = true })
	for _, field in ipairs({ "journalToast", "captureResult" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	NS:JournalToastPush(SH.Feat("Premier filet"))
	local j = NS.journalToast
	local b = j and j.shareButton
	s.ok("Azeroth : bandeau doré et bouton", j and j.azeroth and Shown(b))
	-- (le thème du socle suit le choix, donc forgé : le bois garde l'aplat et le filet d'or)
	s.ok("Azeroth : bouton à l'aplat de l'ancien habillage, jamais la petite plaque forgée", b and NS.QCForged()
		and not b.forge and not (b.plate and b.plate.parts), b and (tostring(NS.QCForged()) .. "/" .. tostring(b.forge)))
	local point = b and b.lastPoint
	s.ok("Azeroth : sous le bouclier, dans le bandeau", point and point.point == "BOTTOMRIGHT" and point.relTo == j.banner,
		point and point.point)
	s.ok("icône du client (atlas ou fichier de repli)", b and (b.icon.atlas == "communities-icon-chat"
		or b.icon.texture == NS.SHARE_ICON.fallback))
	b:Click("LeftButton")
	s.ok("Azeroth : menu sur le bois, encres des rôles", NS.shareMenu.azeroth == true
		and NS.shareMenu.rows[1].text.textColor and NS.shareMenu.rows[1].text.textColor[1] == NS.AZEROTH_INK.lightSoft[1])
	NS.shareMenu:Hide()
	-- scène Azeroth : elle montre le verdict, le bouton va dans son coin
	local saved = NS.captureStage
	local stage = CreateFrame("Frame", nil, UIParent)
	stage.azeroth = true
	stage:Show()
	NS.captureStage = stage
	NS:ShareStageVerdict({}, { name = "Raptor", shiny = true, stars = 3, npcID = 7001 })
	s.ok("scène : bouton dans le coin", Shown(stage.shareButton) and stage.shareButton.lastPoint.point == "TOPRIGHT")
	NS:ShareStageVerdict({}, { name = "Loup", stars = 1, npcID = 7002, class = "normal" })
	s.ok("scène : capture ordinaire, pas de bouton", not Shown(stage.shareButton))
	NS.captureStage = saved
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	for _, field in ipairs({ "journalToast", "captureResult" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	-- 3.1.0 : sans les atlas, le thème forgé : bandeau à médaillon, petite
	-- plaque forgée en bas à droite, « Partager » écrit, les textes s'écartent
	SH.Reset({ guild = true })
	NS:JournalToastPush(SH.Feat("Premier filet"))
	local fj = NS.journalToast
	local fb = fj and fj.shareButton
	s.ok("forgé : bandeau à médaillon, plaque forgée en bas à droite", fj and fj.forgeBanner and not fj.azeroth and Shown(fb)
		and fb.forge and fb.plate and fb.plate.parts and fb.lastPoint.point == "BOTTOMRIGHT")
	s.ok("forgé : « Partager » écrit, bouton élargi", fb and fb.labelled and fb.label:GetText() == NS.L.SHARE_LABEL
		and fb.width > NS.SHARE_BUTTON.size)
	s.ok("forgé : le bouton a sa rangée, le nom et la sous-ligne gardent leur largeur", fj and fj.text:GetWidth() == fj.shareWidths.text
		and fj.stars:GetWidth() == fj.shareWidths.stars and fj.forgeBottomReserve == fb:GetHeight() + NS.SHARE_BUTTON.forge.y)
	fb:Click("LeftButton")
	s.ok("forgé : menu habillé par le socle, titre en couleur d'identité", NS.shareMenu.skinDressed == true
		and NS.shareMenu.azeroth == false and Same(NS.shareMenu.title.textColor, Theme.IDENTITY_LIGHT))
	NS.shareMenu:Hide()
	-- Sobre (choix du joueur) : à droite, avant les points, les textes s'écartent
	SH.Reset({ guild = true })
	if NS.journalToast then NS.journalToast:Hide() end
	NS.journalToast, NS.uiStyleCache = nil, {}
	NS:DB().companionStyle = "sobre"
	NS:ApplyUIStyle()
	NS:JournalToastPush(SH.Feat("Premier filet"))
	local sj = NS.journalToast
	s.ok("Sobre : bouton à droite, avant les points", sj and not sj.azeroth and not sj.forgeBanner and Shown(sj.shareButton)
		and not sj.shareButton.forge and not sj.shareButton.labelled
		and sj.shareButton.lastPoint.point == "RIGHT" and sj.shareButton.lastPoint.x == -NS.SHARE_BUTTON.featGap)
	s.ok("Sobre : le nom s'écarte du bouton", sj and sj.text:GetWidth() < sj.shareWidths.text)
	sj.shareButton:Click("LeftButton")
	s.ok("Sobre : menu sans habillage forgé, titre MUTED_LIGHT", NS.shareMenu.skinDressed == false
		and Same(NS.shareMenu.title.textColor, Theme.MUTED_LIGHT))
	NS.shareMenu:Hide()
	if NS.journalToast then NS.journalToast:Hide() end
	NS.journalToast, NS.uiStyleCache = nil, {}
	NS:DB().companionStyle = nil
	NS:ApplyUIStyle()
	SH.Reset()
	SH.Restore()
	s.check("[SHARE] deux styles : bouton placé (Azeroth sous le bouclier, Sobre à droite), scène Azeroth, menu habillé, contrastes mesurés")
end

-- 9. Le verdict d'une vraie capture porte de quoi partager -------------------------------
do
	local s = Steps()
	SH.Reset({ guild = true })
	NS.SpecimenRollSize = function() return "large" end
	NS.captureStage = nil
	NS:CaptureResolve({ success = true, stars = 3, target = { npcID = 7301, name = "Raptor", class = "elite", zoneID = 1413 } })
	local pending = NS.captureResultPending
	s.ok("résultat : rang, espèce nouvelle, spécimen", pending and pending.class == "elite" and pending.fresh == true
		and pending.specimen ~= nil)
	SH.Step(0)
	local r = NS.captureResult
	s.ok("bouton sur le « Capturé ! »", r and r:IsShown() and Shown(r.shareButton))
	s.ok("texte complet", NS:ShareText(r.shareButton.item) == "[Quest Companion] Testeur a capturé un Raptor (3 étoiles, Grand, élite, nouvelle espèce) !",
		NS:ShareText(r.shareButton.item))
	s.ok("toujours rien d'envoyé", #SH.sends == 0)
	SH.Reset()
	SH.Restore()
	s.check("[SHARE] capture réelle : le résultat porte rang, espèce nouvelle et spécimen ; bouton au bandeau, rien d'envoyé")
end

-- 10. Annonce automatique au groupe : brillante et 3 étoiles ---------------------------------
do
	local s = Steps()
	local npc = 7500
	local function Capture(stars, shiny, name)
		npc = npc + 1
		NS.captureStage = nil
		NS:CaptureResolve({ success = true, stars = stars, target = { npcID = npc, name = name or "Raptor", class = "normal",
			shiny = shiny, zoneID = 1413 } })
	end
	NS.SpecimenRollSize = function() return "large" end
	-- en groupe : une brillante, puis un 3 étoiles (30 s plus tard), une ligne chacun
	SH.Reset({ party = true })
	NS.SpecimenRollSize = function() return "large" end
	Capture(1, true)
	s.ok("brillante en groupe : une ligne PARTY, le texte du partage", #SH.sends == 1 and SH.sends[1].channel == "PARTY"
		and SH.sends[1].text == "[Quest Companion] Testeur a capturé un Raptor brillant (1 étoile, Grand, nouvelle espèce) !",
		SH.sends[1] and SH.sends[1].text)
	SH.Step(31)
	Capture(3, false, "Loup")
	s.ok("3 étoiles : une ligne", #SH.sends == 2 and SH.sends[2].text:find("Loup (3 étoiles", 1, true) ~= nil, SH.sends[2] and SH.sends[2].text)
	SH.Step(31)
	Capture(2, false, "Lapin")
	Capture(1, false, "Crabe")
	s.ok("1 ou 2 étoiles, pas brillant : rien", #SH.sends == 2)
	-- raid, groupe d'instance
	SH.Reset({ raid = true })
	Capture(3, false)
	s.ok("raid : RAID", #SH.sends == 1 and SH.sends[1].channel == "RAID")
	SH.Reset({ instance = true, party = true })
	Capture(3, false)
	s.ok("groupe d'instance : INSTANCE_CHAT", #SH.sends == 1 and SH.sends[1].channel == "INSTANCE_CHAT")
	-- seul : rien ; jamais SAY
	SH.Reset({ guild = true })
	Capture(1, true)
	s.ok("seul, guilde sans le second réglage : rien", #SH.sends == 0)
	-- réglages
	SH.Reset({ party = true })
	NS:DB().announceGroup = false
	Capture(1, true)
	s.ok("réglage coupé : rien", #SH.sends == 0)
	SH.Reset({ guild = true })
	NS:DB().announceGuild = true
	Capture(1, true)
	s.ok("second réglage : la guilde", #SH.sends == 1 and SH.sends[1].channel == "GUILD")
	SH.Reset({ guild = true, party = true })
	NS:DB().announceGuild = true
	Capture(3, false)
	s.ok("groupe et guilde : deux lignes", #SH.sends == 2 and SH.sends[1].channel == "PARTY" and SH.sends[2].channel == "GUILD")
	SH.Reset()
	s.ok("défauts : groupe actif, guilde coupée", NS:DB().announceGroup == true and NS:DB().announceGuild == false)
	-- combat : en file, envoyé à la fin, les prises du combat en une ligne
	SH.Reset({ party = true })
	SH.combat = true
	Capture(1, true, "Raptor")
	Capture(3, false, "Loup")
	s.ok("en combat : rien, en file", #SH.sends == 0 and #NS.announceQueue == 2)
	SH.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	s.ok("fin du combat : une ligne pour les deux", #SH.sends == 1
		and SH.sends[1].text == "[Quest Companion] Testeur a capturé 2 spécimens : Raptor brillant, Loup (3 étoiles) !",
		SH.sends[1] and SH.sends[1].text)
	-- limite : une annonce par canal toutes les 30 s
	SH.Reset({ party = true })
	Capture(1, true)
	SH.Step(5)
	Capture(1, true)
	s.ok("moins de 30 s : pas de seconde ligne", #SH.sends == 1)
	SH.Step(31)
	Capture(1, true)
	s.ok("30 s après : de nouveau", #SH.sends == 2)
	SH.Reset()
	SH.Restore()
	s.check("[ANN] annonce auto : brillante et 3 étoiles une fois au groupe (PARTY / RAID / INSTANCE_CHAT), rien seul ni pour 1-2 étoiles ; réglages ; combat ; 30 s")
end

-- 11. Lot de « Tout capturer », doublons avec le partage, envoi refusé -----------------------
do
	local s = Steps()
	SH.Reset({ party = true })
	local batch = { messages = {}, tried = 4, results = {
		{ success = true, stars = 3, target = { name = "Loup", npcID = 7601, class = "normal" } },
		{ success = true, stars = 1, target = { name = "Raptor", npcID = 7602, class = "normal", shiny = true } },
		{ success = true, stars = 1, target = { name = "Lapin", npcID = 7603, class = "normal" } },
		{ success = false, stars = 3, target = { name = "Ours", npcID = 7604, class = "normal" } },
	} }
	NS:CaptureBatchFlush(batch)
	s.ok("lot : une seule ligne, les deux prises notables", #SH.sends == 1
		and SH.sends[1].text == "[Quest Companion] Testeur a capturé 2 spécimens : Loup (3 étoiles), Raptor brillant !", SH.sends[1] and SH.sends[1].text)
	NS:CaptureBatchFlush(batch)
	s.ok("lot déjà annoncé : rien de plus", #SH.sends == 1)
	local en = NS:AnnounceText({ { name = "Raptor", shiny = true, stars = 1 }, { name = "Wolf", stars = 3 }, who = "Dyokrion" }, "en")
	s.ok("anglais", en == "[Quest Companion] Dyokrion captured 2 specimens: shiny Raptor, Wolf (3 stars)!", en)
	local long = { who = "Dyokrion" }
	for i = 1, 30 do long[i] = { name = "Créature au long nom " .. i, shiny = true, stars = 3 } end
	local text = NS:AnnounceText(long, "fr")
	s.ok("long lot : ≤ 255, coupé par « … »", #text <= 255 and text:find("… !$") ~= nil and not text:find("|", 1, true), #text .. " " .. text)
	-- doublons : partagé à la main, pas d'annonce ; annoncé, le partage manuel le dit
	SH.Reset({ party = true })
	local item = { kind = "capture", name = "Raptor", shiny = true, stars = 1, key = "cap:4242" }
	NS:ShareOpen(nil, item); SH.Pick("PARTY")
	SH.Step(1)
	NS:AnnounceCaptures({ item })
	s.ok("partagé à la main il y a 1 s : pas d'annonce", #SH.sends == 1)
	SH.Reset({ party = true })
	NS:AnnounceCaptures({ item })
	SH.Step(11)
	Mock:Reset()
	NS:ShareOpen(nil, item); SH.Pick("PARTY")
	s.ok("annoncé : le partage manuel au même canal est retenu", #SH.sends == 1
		and Mock:Output():find("Déjà partagé dans ce canal", 1, true) ~= nil)
	-- envoi refusé : aucune erreur, noté une fois sans un mot
	SH.Reset({ party = true })
	_G.SendChatMessage = function() error("Interface action failed because of an AddOn") end
	NS.errors = {}
	Mock:Reset()
	local ok1 = pcall(NS.AnnounceCaptures, NS, { { kind = "capture", name = "A", shiny = true, key = "cap:1" } })
	SH.Step(31)
	local ok2 = pcall(NS.AnnounceCaptures, NS, { { kind = "capture", name = "B", shiny = true, key = "cap:2" } })
	local ok3 = pcall(Mock.Fire, Mock, "ADDON_ACTION_BLOCKED", "QuestCompanion", "SendChatMessage")
	local noted = 0
	for _, e in ipairs(NS.errors) do if tostring(e.where):find("^share:") then noted = noted + 1 end end
	s.ok("refusé : pas d'erreur Lua", ok1 and ok2 and ok3)
	s.ok("noté une fois, rien dans le chat", noted == 1 and Mock:Output() == "", noted .. " / " .. Mock:Output())
	SH.Reset()
	SH.Restore()
	s.check("[ANN] lot en une ligne (≤ 255) ; pas de doublon avec le partage manuel ; envoi refusé sans erreur, noté une fois")
end

-- 12. Retour en jeu (bêta 2) : bouton plus grand, bandeau en pause sous la souris ----------
do
	local s = Steps()
	SH.Reset({ guild = true })
	-- durée d'un bandeau sans bouton (un tampon), puis avec
	NS:JournalNotify({ kind = "zone", name = "Clairière", id = "zone:1" })
	local plain = NS.journalToastHideAt - NS.Now()
	SH.Step(plain + 0.5)
	NS:JournalToastPush(SH.Feat("Premier filet"))
	local j = NS.journalToast
	local b = j.shareButton
	s.ok("bouton : 24 px au moins (taille « sm »)", b and b.width >= 24 and b.height >= 24 and b.height >= NS.Theme.BUTTON_SIZES.sm,
		b and (b.width .. "x" .. b.height))
	local with = NS.journalToastHideAt - NS.Now()
	s.ok("bandeau avec bouton : 3 s de plus", math.abs(with - plain - NS.SHARE_EXTRA) < 0.01, plain .. " / " .. with)
	-- souris sur le bandeau : il ne part pas
	j.IsMouseOver = function() return true end
	SH.Step(20)
	s.ok("survolé 20 s : toujours là", j:IsShown())
	-- souris partie : au moins 3 s, puis il part
	j.IsMouseOver = nil
	SH.Step(0)
	local left = NS.journalToastHideAt - NS.Now()
	s.ok("souris partie : au moins 3 s", j:IsShown() and left >= NS.SHARE_RESUME - 0.01, left)
	-- sur le bouton seul : pareil
	b.IsMouseOver = function() return true end
	SH.Step(15)
	s.ok("survol du bouton : toujours là", j:IsShown())
	b.IsMouseOver = nil
	SH.Step(NS.SHARE_RESUME + 0.5)
	s.ok("puis il part", not j:IsShown())
	-- « Capturé ! » : même pause, et la file avance ensuite
	NS:CaptureResultQueue({ name = "Raptor", shiny = true, stars = 3, npcID = 7001, class = "normal" })
	SH.Step(0)
	NS:JournalToastPush(SH.Feat("Sur la route"))
	local r = NS.captureResult
	s.ok("résultat affiché", r and r:IsShown())
	r.IsMouseOver = function() return true end
	SH.Step(30)
	s.ok("résultat survolé : il reste, le carnet attend", r:IsShown() and not j:IsShown())
	r.IsMouseOver = nil
	SH.Step(NS.SHARE_RESUME + 0.5)
	SH.Step(0.25)
	s.ok("puis la file avance : le carnet", not r:IsShown() and j:IsShown())
	-- Azeroth : le libellé « Partager » à côté de l'icône
	SH.Reset({ guild = true })
	for _, field in ipairs({ "journalToast", "captureResult" }) do if NS[field] then NS[field]:Hide() end NS[field] = nil end
	NS.uiStyleCache = {}
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	NS:JournalToastPush(SH.Feat("Premier filet"))
	local ab = NS.journalToast.shareButton
	s.ok("Azeroth : « Partager » écrit, bouton élargi", ab and ab.labelled and ab.label:GetText() == "Partager" and ab.width > 24
		and ab.height >= 24)
	s.ok("libellé mesuré (rôle share.label ≥ 4,5:1)", NS.AZEROTH_CONTRAST["share.label"]
		and NS.Theme.Contrast(NS.AZEROTH_INK.lightSoft, NS.AZEROTH_CONTRAST["share.label"][2]) >= 4.5)
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	for _, field in ipairs({ "journalToast", "captureResult" }) do if NS[field] then NS[field]:Hide() end NS[field] = nil end
	NS.uiStyleCache = {}
	SH.Reset()
	SH.Restore()
	s.check("[SHARE] bêta 2 : bouton 24 px (Azeroth : « Partager »), +3 s, pause sous la souris puis 3 s, la file avance ensuite")
end
