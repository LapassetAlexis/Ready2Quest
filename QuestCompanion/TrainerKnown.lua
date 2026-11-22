-- TrainerKnown.lua -- 3.7.0 : dresseurs connus, onglet « Dresseurs » de la
-- page Communauté, parrainage « Passeur » (docs/qc-gameplay-viral, étape 3,
-- chantier S2, points 2 à 7)
--
-- Dresseurs connus (ns:TrainerKnown*) : 50 fiches au plus, au compte
-- (db.trainerKnown = { v = 1, list = { { k, n, c, o, at, fa } } } : clé du
-- joueur, nom complet, fiche sérialisée, origine, date, faction lue dans un
-- code). Y entrent :
--   * les fiches reçues en jeu (jusqu'ici perdues à la déconnexion), avec
--     leur origine : « group » (vu sur le canal du groupe, du raid ou de
--     l'instance), « guild » (canal de la guilde), « target » (chuchotements
--     seulement : une sonde de ciblage) ;
--   * celles ouvertes par code (« code »), indicatives : elles comptent pour
--     les fiches consultées (le haut fait des fiches différentes, le compteur
--     codeOpen), jamais pour autre chose (pas de détenteur noté, aucune
--     demande envoyée à leur dresseur sauf s'il est croisé en jeu).
-- Une même clé n'a qu'une entrée : la fiche la plus récente la remplace (et
-- son origine). Au-delà de 50, la plus ancienne sort. Rien d'autre n'est
-- gardé, rien n'est envoyé. « Autre royaume » : le royaume du nom complet
-- n'est pas le mien ; « autre faction » : la faction lue dans le code n'est
-- pas la mienne (une fiche reçue en jeu vient toujours de ma faction).
-- Sans fiche de session (TrainerCard.lua), ns:TrainerCard rend la fiche
-- gardée : la fenêtre de fiche et la comparaison s'ouvrent sur elle.
--
-- Parrainage (honorifique, falsifiable : rien d'autre n'est bâti dessus) :
-- l'encadré n'existe que pendant les 14 jours qui suivent la première
-- capture du compte (ns:CaptureEarliestAt ; sans capture : ouvert) et tant
-- qu'aucun parrain n'est désigné. On choisit un dresseur connu (un code
-- s'ouvre d'abord) ; jamais soi-même ni un personnage du même compte. Le
-- filleul reçoit 2 lassos et 1 sifflet, une fois (db.trainerMentor).
-- Le parrain est prévenu par un message d'addon invisible « M~1~ask »
-- (préfixe QCTrainer, chuchotement), seulement quand on a reçu un message de
-- son addon depuis moins de 5 minutes (il est en ligne, même royaume, même
-- faction) ; sinon le message attend la prochaine rencontre. Il répond
-- « M~1~ok » et compte son filleul une fois (ns:TallyMark("mentees", clé) :
-- un ensemble, un message reçu deux fois ne compte qu'une fois). Une 3.6 ne
-- connaît pas « M » : elle note le détenteur, rien d'autre, sans erreur.
-- Un dresseur d'un autre royaume ou de l'autre faction ne peut jamais être
-- prévenu ; un dresseur connu par code seulement ne l'est que si vos addons
-- se croisent un jour : l'encadré le dit avant la confirmation.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	COM_TAB_dresseurs      = "Dresseurs",
	COM_TR_COUNT_ONE       = "%s dresseur connu sur %d",
	COM_TR_COUNT_MANY      = "%s dresseurs connus sur %d",
	COM_TR_MY_HEAD         = "Mon code de dresseur",
	COM_TR_OPEN_HEAD       = "Ouvrir un code reçu",
	COM_TR_COPY            = "Copier",
	COM_TR_COPY_DONE       = "Code sélectionné : Ctrl+C, puis colle-le où tu veux.",
	COM_TR_PASTE           = "Colle un code ici…",
	COM_TR_OPEN            = "Ouvrir",
	COM_TR_OPEN_TIP        = "Colle d'abord un code de dresseur.",
	COM_TR_OPENED_NEW      = "Fiche de %s ouverte et rangée.",
	COM_TR_OPENED_AGAIN    = "Fiche de %s ouverte et mise à jour.",
	COM_TR_OPENED_SELF     = "C'est ton propre code : voici ta fiche.",
	COM_TR_KNOWN_HEAD      = "Dresseurs connus",
	COM_TR_FILTER_all      = "Tous",
	COM_TR_FILTER_game     = "Croisés en jeu",
	COM_TR_FILTER_code     = "Reçus par code",
	COM_TR_EMPTY           = "Aucun dresseur connu pour l'instant. Les fiches que tu reçois en jeu et les codes que tu ouvres se rangent ici, 50 au plus.",
	COM_TR_EMPTY_FILTER    = "Aucun dresseur dans ce filtre.",
	COM_TR_CARD            = "Fiche",
	COM_TR_COMPARE         = "Comparer",
	COM_TR_POINTS          = "%s points",
	COM_TR_SPECIES_ONE     = "%s espèce",
	COM_TR_SPECIES_MANY    = "%s espèces",
	COM_TR_SHINIES_ONE     = "%s brillante",
	COM_TR_SHINIES_MANY    = "%s brillantes",
	COM_TR_ORIGIN_group    = "rencontre en groupe",
	COM_TR_ORIGIN_guild    = "rencontre en guilde",
	COM_TR_ORIGIN_target   = "rencontre en jeu",
	COM_TR_ORIGIN_code     = "reçu par code",
	COM_TR_OTHER_REALM     = "autre royaume",
	COM_TR_OTHER_FACTION   = "autre faction",
	COM_TR_DATE            = "%d/%m",
	COM_TR_NOTE            = "Une fiche reçue par code vient d'un texte copié : elle est indicative et ne compte pour aucun concours. Clic droit sur une ligne : retirer ce dresseur.",
	COM_TR_REMOVED         = "%s retiré des dresseurs connus.",
	-- la fenêtre de fiche, pour une fiche gardée
	COM_TR_KEPT_CODE       = "Reçue par code le %s · indicative",
	COM_TR_KEPT_GAME       = "Fiche gardée du %s",
	-- parrainage
	COM_TR_MENTOR_TITLE    = "Quelqu'un t'a fait découvrir Quest Companion ?",
	COM_TR_MENTOR_TEXT     = "Désigne cette personne une fois : tu reçois 2 lassos et 1 sifflet, et son addon compte un filleul quand vos addons se croisent en jeu. Possible pendant tes 14 premiers jours.",
	COM_TR_MENTOR_BUTTON   = "Désigner mon parrain",
	COM_TR_MENTOR_PICK     = "Clique sur sa ligne dans la liste. Tu as son code ? Ouvre-le d'abord ci-dessus : sa fiche s'y range.",
	COM_TR_MENTOR_CANCEL   = "Annuler",
	COM_TR_MENTOR_CONFIRM  = "Confirmer",
	COM_TR_MENTOR_ASK      = "Désigner %s ?",
	COM_TR_MENTOR_REACH_game  = "Son addon (3.7 ou plus récent) comptera ce filleul la prochaine fois que vous vous croiserez en jeu.",
	COM_TR_MENTOR_REACH_maybe = "Fiche reçue par code : l'addon ne peut pas prévenir cette personne d'ici. Si vos addons se croisent un jour en jeu, son filleul sera compté ; sinon, dis-le-lui toi-même.",
	COM_TR_MENTOR_REACH_never = "Autre royaume ou autre faction : l'addon ne pourra jamais prévenir cette personne. Dis-le-lui toi-même ; tes aides te sont données quand même.",
	COM_TR_MENTOR_SELF     = "Pas toi-même, ni un de tes personnages : choisis la personne qui t'a fait découvrir l'addon.",
	COM_TR_MENTOR_DONE     = "Parrain désigné : %s. Merci pour la transmission !",
}
local EN = {
	COM_TAB_dresseurs      = "Trainers",
	COM_TR_COUNT_ONE       = "%s known trainer out of %d",
	COM_TR_COUNT_MANY      = "%s known trainers out of %d",
	COM_TR_MY_HEAD         = "My trainer code",
	COM_TR_OPEN_HEAD       = "Open a code you received",
	COM_TR_COPY            = "Copy",
	COM_TR_COPY_DONE       = "Code selected: Ctrl+C, then paste it wherever you want.",
	COM_TR_PASTE           = "Paste a code here…",
	COM_TR_OPEN            = "Open",
	COM_TR_OPEN_TIP        = "Paste a trainer code first.",
	COM_TR_OPENED_NEW      = "%s's card opened and saved.",
	COM_TR_OPENED_AGAIN    = "%s's card opened and updated.",
	COM_TR_OPENED_SELF     = "That's your own code: here is your card.",
	COM_TR_KNOWN_HEAD      = "Known trainers",
	COM_TR_FILTER_all      = "All",
	COM_TR_FILTER_game     = "Met in game",
	COM_TR_FILTER_code     = "Received by code",
	COM_TR_EMPTY           = "No known trainer yet. The cards you receive in game and the codes you open are kept here, 50 at most.",
	COM_TR_EMPTY_FILTER    = "No trainer in this filter.",
	COM_TR_CARD            = "Card",
	COM_TR_COMPARE         = "Compare",
	COM_TR_POINTS          = "%s points",
	COM_TR_SPECIES_ONE     = "%s species",
	COM_TR_SPECIES_MANY    = "%s species",
	COM_TR_SHINIES_ONE     = "%s shiny",
	COM_TR_SHINIES_MANY    = "%s shinies",
	COM_TR_ORIGIN_group    = "met in a group",
	COM_TR_ORIGIN_guild    = "met in the guild",
	COM_TR_ORIGIN_target   = "met in game",
	COM_TR_ORIGIN_code     = "received by code",
	COM_TR_OTHER_REALM     = "other realm",
	COM_TR_OTHER_FACTION   = "other faction",
	COM_TR_DATE            = "%m/%d",
	COM_TR_NOTE            = "A card received by code comes from copied text: it is for information only and counts for no contest. Right-click a row: remove this trainer.",
	COM_TR_REMOVED         = "%s removed from known trainers.",
	COM_TR_KEPT_CODE       = "Received by code on %s · for information only",
	COM_TR_KEPT_GAME       = "Card kept from %s",
	COM_TR_MENTOR_TITLE    = "Did someone introduce you to Quest Companion?",
	COM_TR_MENTOR_TEXT     = "Name them once: you get 2 lassos and 1 whistle, and their addon counts a protégé when your addons meet in game. Possible during your first 14 days.",
	COM_TR_MENTOR_BUTTON   = "Name my mentor",
	COM_TR_MENTOR_PICK     = "Click their row in the list. You have their code? Open it above first: their card is saved there.",
	COM_TR_MENTOR_CANCEL   = "Cancel",
	COM_TR_MENTOR_CONFIRM  = "Confirm",
	COM_TR_MENTOR_ASK      = "Name %s?",
	COM_TR_MENTOR_REACH_game  = "Their addon (3.7 or newer) will count this protégé the next time you meet in game.",
	COM_TR_MENTOR_REACH_maybe = "Card received by code: the addon can't reach this person from here. If your addons meet in game one day, the protégé will be counted; otherwise, tell them yourself.",
	COM_TR_MENTOR_REACH_never = "Other realm or other faction: the addon will never be able to reach this person. Tell them yourself; you still get your aids.",
	COM_TR_MENTOR_SELF     = "Not yourself, nor one of your characters: pick the person who introduced you to the addon.",
	COM_TR_MENTOR_DONE     = "Mentor named: %s. Thanks for passing it on!",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRAINER_KNOWN_STRINGS = { fr = FR, en = EN } end

ns.TRAINER_KNOWN_MAX = 50
ns.TRAINER_KNOWN_ORIGINS = { group = true, guild = true, target = true, code = true }
ns.TRAINER_KNOWN_FILTERS = { "all", "game", "code" }
ns.TRAINER_MENTOR_DAYS = 14
ns.TRAINER_MENTOR_GIFT = { { "lasso", 2 }, { "sifflet", 1 } }
ns.TRAINER_MENTOR_SEEN = 300      -- s : un message de son addon depuis moins de 5 min = joignable
ns.TRAINER_MENTOR_RETRY = 60      -- s entre deux envois au parrain
ns.TRAINER_MENTOR_REPLY = 300     -- s entre deux réponses du parrain au même filleul

-- l'onglet, en tête de la page Communauté (l'onglet par défaut reste Discord)
if type(ns.COMMUNITY_TABS) == "table" then
	local present = false
	for _, id in ipairs(ns.COMMUNITY_TABS) do if id == "dresseurs" then present = true end end
	if not present then table.insert(ns.COMMUNITY_TABS, 1, "dresseurs") end
end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function Plain(v) if ns.Plain then return ns.Plain(v) end return v end
local function Epoch() return tonumber(Call(G("time"))) or 0 end
local function Clock() return (ns.Now and ns.Now()) or 0 end

-- ---------------------------------------------------------------------------
-- Sauvegarde (compte) et session
-- ---------------------------------------------------------------------------
local session = { parsed = {}, ctx = {}, seen = {}, sentAt = {}, replied = {} }
ns.trainerKnownSession = session

function ns:TrainerKnownResetSession()
	session.parsed, session.ctx, session.seen, session.sentAt, session.replied = {}, {}, {}, {}, {}
	session.opening = nil
end

function ns:TrainerKnownData()
	local db = self:DB()
	local data = db.trainerKnown
	if type(data) ~= "table" then
		data = { v = 1, list = {} }
		db.trainerKnown = data
	end
	if type(data.list) ~= "table" then data.list = {} end
	-- entrées illisibles écartées (sauvegarde retouchée à la main)
	for index = #data.list, 1, -1 do
		local entry = data.list[index]
		if type(entry) ~= "table" or type(entry.k) ~= "string" or type(entry.c) ~= "string"
			or not ns.TRAINER_KNOWN_ORIGINS[entry.o or ""] then
			table.remove(data.list, index)
		end
	end
	return data
end

local function Find(self, key)
	for index, entry in ipairs(self:TrainerKnownData().list) do
		if entry.k == key then return entry, index end
	end
	return nil
end

-- royaume d'une clé de joueur (« nom-royaume », en minuscules)
local function RealmOf(key) return type(key) == "string" and key:match("^[^%-]+%-(.+)$") or nil end
local function MyKey(self) return self.TrainerMe and self:TrainerKey(self:TrainerMe()) or nil end

-- un personnage de ce compte (la sauvegarde est commune au compte)
function ns:TrainerIsOwnCharacter(key)
	if not key then return false end
	if key == MyKey(self) then return true end
	local chars = self:DB().chars
	if type(chars) ~= "table" then return false end
	for charKey in pairs(chars) do
		if type(charKey) == "string" and self:TrainerKey(charKey) == key then return true end
	end
	return false
end

-- l'entrée vue de l'écran : fiche relue (cache de session), drapeaux
local function View(self, entry)
	local card = session.parsed[entry.k]
	if not card then
		local ok, value = pcall(self.TrainerParseCard, self, entry.c)
		card = ok and type(value) == "table" and value or { showcase = {}, badges = {} }
		session.parsed[entry.k] = card
	end
	local mine = RealmOf(MyKey(self))
	local realm = RealmOf(entry.k)
	local faction = self.TrainerFaction and self:TrainerFaction() or nil
	return { key = entry.k, name = entry.n, card = card, origin = entry.o, at = tonumber(entry.at) or 0,
		code = entry.o == "code", faction = entry.fa,
		otherRealm = (realm ~= nil and mine ~= nil and realm ~= mine) or false,
		otherFaction = (entry.fa ~= nil and faction ~= nil and entry.fa ~= faction) or false }
end

function ns:TrainerKnownCount() return #self:TrainerKnownData().list end

function ns:TrainerKnownGet(key)
	local entry = key and Find(self, key)
	return entry and View(self, entry) or nil
end

-- filtre "all" (défaut), "game" ou "code" ; les plus récentes d'abord
function ns:TrainerKnownList(filter)
	local out = {}
	for _, entry in ipairs(self:TrainerKnownData().list) do
		local code = entry.o == "code"
		if filter == nil or filter == "all" or (filter == "code" and code) or (filter == "game" and not code) then
			out[#out + 1] = View(self, entry)
		end
	end
	table.sort(out, function(a, b)
		if a.at ~= b.at then return a.at > b.at end
		return a.key < b.key
	end)
	return out
end

-- Range une fiche (table relue). origin : "group", "guild", "target",
-- "code" ; info.faction (code). Rend la vue de l'entrée et true si le
-- dresseur n'était pas connu ; nil pour soi-même ou une fiche sans nom.
function ns:TrainerKnownAdd(card, origin, info)
	if type(card) ~= "table" or not ns.TRAINER_KNOWN_ORIGINS[origin or ""] then return nil end
	local full = card.name and self:TrainerFullName(card.name)
	local key = full and self:TrainerKey(full)
	if not key or key == MyKey(self) then return nil end
	local ok, text = pcall(self.TrainerSerializeCard, self, card)
	if not ok or type(text) ~= "string" then return nil end
	local data = self:TrainerKnownData()
	local entry, index = Find(self, key)
	local isNew = entry == nil
	if entry then table.remove(data.list, index) end
	entry = { k = key, n = full, c = text, o = origin, at = Epoch(),
		fa = origin == "code" and info and (info.faction == "A" or info.faction == "H") and info.faction or nil }
	data.list[#data.list + 1] = entry
	-- au-delà du plafond : les plus anciennes sortent
	while #data.list > ns.TRAINER_KNOWN_MAX do
		local oldest, at = 1, math.huge
		for i, other in ipairs(data.list) do
			if other ~= entry and (tonumber(other.at) or 0) < at then oldest, at = i, tonumber(other.at) or 0 end
		end
		session.parsed[data.list[oldest].k] = nil
		table.remove(data.list, oldest)
	end
	session.parsed[key] = nil
	-- l'onglet à l'écran se met à jour (sinon il se peint à son ouverture)
	local pane = self.journalFrame and self.journalFrame.community
	if pane and pane.tab == "dresseurs" and pane.IsShown and pane:IsShown() and self.CommunityTrainersPaint then
		pcall(self.CommunityTrainersPaint, self)
	end
	return View(self, entry), isNew
end

function ns:TrainerKnownRemove(key)
	local entry, index = Find(self, key)
	if not entry then return false end
	table.remove(self:TrainerKnownData().list, index)
	session.parsed[key] = nil
	return true
end

-- ---------------------------------------------------------------------------
-- Accroches sur la fiche de dresseur (TrainerCard.lua), sans la modifier
-- ---------------------------------------------------------------------------
local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }
local RANK = { target = 1, group = 2, guild = 3 }

local function Split(text)
	local fields = {}
	for field in (text .. "~"):gmatch("([^~]*)~") do fields[#fields + 1] = field end
	return fields
end

do
	-- messages d'addon : où le dresseur a été vu (origine), quand (joignable),
	-- la fiche complète reçue (gardée), le parrainage
	local base = ns.TrainerOnAddonMessage
	if type(base) == "function" then
		function ns:TrainerOnAddonMessage(prefix, text, channel, sender, ...)
			local key
			local name = Plain(sender)
			if Plain(prefix) == ns.TRAINER_PREFIX and type(name) == "string" then
				local full = self:TrainerFullName(name)
				key = full and self:TrainerKey(full)
			end
			local state = ns.trainerState
			local before = key and state and state.cards[key]
			local result = base(self, prefix, text, channel, sender, ...)
			if result ~= true or not key then return result end
			local ok, err = pcall(function()
				channel = Plain(channel)
				local origin = channel == "GUILD" and "guild" or (GROUP_CHANNELS[channel] and "group" or "target")
				if (RANK[origin] or 0) > (RANK[session.ctx[key]] or 0) then session.ctx[key] = origin end
				session.seen[key] = Clock()
				local after = state and state.cards[key]
				if after and after ~= before and type(after.card) == "table" then
					self:TrainerKnownAdd(after.card, session.ctx[key] or "target")
				end
				local fields = Split(tostring(Plain(text) or ""))
				if fields[1] == "M" then self:TrainerMentorOnMessage(self:TrainerFullName(name), key, fields[3]) end
				self:TrainerMentorTry(key)
			end)
			if not ok and self.RecordError then self:RecordError("trainerKnown:message", err) end
			return result
		end
	end

	-- sans fiche de session : la fiche gardée (fenêtre de fiche, comparaison)
	local card = ns.TrainerCard
	if type(card) == "function" then
		function ns:TrainerCard(name, ...)
			local found, age = card(self, name, ...)
			if found then return found, age end
			local key = name and self:TrainerKey(name)
			local entry = key and Find(self, key)
			if not entry then return nil end
			return View(self, entry).card, nil
		end
	end

	-- pas de demande vers un dresseur qu'on ne peut pas joindre : connu par
	-- code, d'un autre royaume ou de l'autre faction (sauf s'il est croisé en
	-- jeu) ; ouvert depuis la liste, seulement s'il a été vu il y a peu
	local request = ns.TrainerRequest
	if type(request) == "function" then
		function ns:TrainerRequest(name, ...)
			local key = name and self:TrainerKey(name)
			local entry = key and Find(self, key)
			if entry then
				local view = View(self, entry)
				local holder = self.TrainerIsHolder and self:TrainerIsHolder(name)
				if (view.code or view.otherRealm or view.otherFaction) and not holder then return false end
				if session.opening == key and not self:TrainerKnownReachable(key) then return false end
			end
			return request(self, name, ...)
		end
	end

	-- la fenêtre de fiche : la date d'une fiche gardée, « indicative » si par code
	local refresh = ns.TrainerRefreshWindow
	if type(refresh) == "function" then
		function ns:TrainerRefreshWindow(...)
			local result = refresh(self, ...)
			local frame = self.trainerFrame
			if frame and frame.viewing and frame.received and frame:IsShown() then
				local key = self:TrainerKey(frame.viewing)
				local state = ns.trainerState
				local entry = key and not (state and state.cards[key]) and Find(self, key)
				if entry then
					local when = ns.TrainerFormatDate and ns.TrainerFormatDate(entry.at) or "?"
					frame.received:SetText(self:F(entry.o == "code" and "COM_TR_KEPT_CODE" or "COM_TR_KEPT_GAME", when))
				end
			end
			return result
		end
	end
end

-- reçu un message de son addon il y a peu (en ligne, joignable)
function ns:TrainerKnownReachable(key)
	local at = session.seen[key]
	local now = Clock()
	return at ~= nil and now >= at and now - at <= ns.TRAINER_MENTOR_SEEN
end

-- « Fiche » d'une ligne : la fenêtre de fiche sur la fiche gardée
function ns:TrainerKnownOpen(key)
	local view = self:TrainerKnownGet(key)
	if not view or not self.TrainerOpen then return nil end
	session.opening = key
	local ok, frame = pcall(self.TrainerOpen, self, view.name)
	session.opening = nil
	return ok and frame or nil
end

-- « Comparer » d'une ligne (sa fiche porte le champ de comparaison)
function ns:TrainerKnownCompare(key)
	local view = self:TrainerKnownGet(key)
	if not (view and type(view.card.featBits) == "string" and self.TrainerCompareOpen) then return nil end
	return self:TrainerCompareOpen(view.name)
end

-- Ouvre un code collé : la fiche s'ouvre et se range. Rend "ok", la vue, true
-- si le dresseur est nouveau ; "self" ; ou "error", la raison.
function ns:TrainerKnownOpenCode(text)
	local card, reason, info = self:TrainerCodeRead(text)
	if not card then return "error", reason end
	local key = self:TrainerKey(self:TrainerFullName(card.name) or "")
	if key and key == MyKey(self) then
		if self.TrainerOpen then pcall(self.TrainerOpen, self, nil) end
		return "self"
	end
	local own = self:TrainerIsOwnCharacter(key)
	local view, isNew = self:TrainerKnownAdd(card, "code", info)
	if not view then return "error", "card" end
	-- indicative : compte pour les fiches consultées (codeOpen, et la fiche
	-- ouverte compte pour le haut fait des fiches différentes), rien d'autre
	if isNew and not own and type(self.TallyAdd) == "function" then pcall(self.TallyAdd, self, "codeOpen") end
	self:TrainerKnownOpen(view.key)
	return "ok", view, isNew
end

-- ---------------------------------------------------------------------------
-- Parrainage
-- ---------------------------------------------------------------------------
function ns:TrainerMentorData()
	local db = self:DB()
	if type(db.trainerMentor) ~= "table" then db.trainerMentor = {} end
	return db.trainerMentor
end

-- l'encadré : 14 jours après la première capture du compte, tant qu'aucun
-- parrain n'est désigné
function ns:TrainerMentorOpen(now)
	if self:TrainerMentorData().key then return false end
	local first = self.CaptureEarliestAt and Call(self.CaptureEarliestAt, self) or nil
	first = tonumber(first)
	if not first or first <= 0 then return true end
	now = now or Epoch()
	return now - first <= ns.TRAINER_MENTOR_DAYS * 86400
end

-- "game" : prévenu à la prochaine rencontre ; "maybe" : connu par code, prévenu
-- seulement si vos addons se croisent ; "never" : autre royaume ou faction
function ns:TrainerMentorReach(view)
	if not view then return "never" end
	if view.otherRealm or view.otherFaction then return "never" end
	if view.code then return "maybe" end
	return "game"
end

-- Désigne le parrain parmi les dresseurs connus. Rend true, la portée ; ou
-- false et la raison ("closed", "unknown", "self").
function ns:TrainerMentorDesignate(key)
	if not self:TrainerMentorOpen() then return false, "closed" end
	local view = self:TrainerKnownGet(key)
	if not view then return false, "unknown" end
	if self:TrainerIsOwnCharacter(key) then return false, "self" end
	local reach = self:TrainerMentorReach(view)
	local data = self:TrainerMentorData()
	data.key, data.name, data.at, data.reach, data.ok = key, view.name, Epoch(), reach, nil
	-- le cadeau du filleul, une fois
	if not data.gift and self.CaptureGrant then
		data.gift = true
		for _, pair in ipairs(ns.TRAINER_MENTOR_GIFT) do
			for _ = 1, pair[2] do pcall(self.CaptureGrant, self, pair[1], { quiet = true }) end
		end
	end
	if type(self.Print) == "function" then
		self:Print(self:F("COM_TR_MENTOR_DONE", self:TrainerShortName(view.name)))
	end
	self:TrainerMentorTry(key)
	return true, reach
end

-- le message au parrain, s'il est joignable maintenant (sinon il attend)
function ns:TrainerMentorTry(key)
	local data = self:TrainerMentorData()
	if not data.key or data.ok or data.reach == "never" or (key and key ~= data.key) then return false end
	if self.TrainerSharing and not self:TrainerSharing() then return false end
	if not self:TrainerKnownReachable(data.key) then return false end
	local now, last = Clock(), session.sentAt[data.key]
	if last and now >= last and now - last < ns.TRAINER_MENTOR_RETRY then return false end
	session.sentAt[data.key] = now
	return self:TrainerSend("M", "WHISPER", data.name, "ask") and true or false
end

-- « M~1~ask » : un filleul (compté une fois) ; « M~1~ok » : mon parrain prévenu
function ns:TrainerMentorOnMessage(sender, key, what)
	if not (sender and key) then return false end
	if what == "ask" then
		if self:TrainerIsOwnCharacter(key) then return false end
		if type(self.TallyMark) == "function" then pcall(self.TallyMark, self, "mentees", key) end
		local now, last = Clock(), session.replied[key]
		if (not self.TrainerSharing or self:TrainerSharing()) and (not last or now < last or now - last >= ns.TRAINER_MENTOR_REPLY) then
			session.replied[key] = now
			self:TrainerSend("M", "WHISPER", sender, "ok")
		end
		return true
	elseif what == "ok" then
		local data = self:TrainerMentorData()
		if data.key == key then data.ok = true end
		return true
	end
	return false
end

-- ---------------------------------------------------------------------------
-- Onglet « Dresseurs » de la page Communauté (JournalCommunity.lua)
-- ---------------------------------------------------------------------------
-- cotes de la maquette (y depuis le haut du contenu, les onglets en 0)
local LAY = {
	tileY = 36, tileW = 347, tileH = 66, tileX2 = 363, headY = 9, fieldY = 30, fieldW = 246, buttonX = 262, buttonW = 75,
	knownHeadY = 120, knownHeadW = 330, chipsY = 112, rowY = 144, rowStep = 54, rowH = 50, rows = 5,
	portrait = 36, nameX = 54, nameY = 8, lineY = 25, seenRight = 526, seenY = 18, cardX = 538, cardW = 66,
	compareX = 610, compareW = 90, buttonY = 12,
	mentorY = 368, mentorH = 66, mentorTextW = 520, mentorButtonX = 552, mentorButtonW = 146, mentorButtonY = 21,
	noteY = 446,
}
ns.JOURNAL_TRAINERS_LAYOUT = LAY

local function Thousands(n)
	if ns.TrainerThousands then return ns.TrainerThousands(n) end
	return tostring(math.floor(tonumber(n) or 0))
end
local function Plural(self, key, n, ...)
	n = tonumber(n) or 0
	local one
	if ns.STRINGS_FRENCH then one = n <= 1 else one = n == 1 end
	return self:F(key .. (one and "_ONE" or "_MANY"), Thousands(n), ...)
end

-- « 4 dresseurs connus sur 50 » (à droite des onglets)
function ns:TrainerKnownCountText()
	return Plural(self, "COM_TR_COUNT", self:TrainerKnownCount(), ns.TRAINER_KNOWN_MAX)
end

-- « <rang> · <points> points · <espèces> espèces · <brillantes> brillantes »
function ns:TrainerKnownLine(card)
	local parts = {}
	local feats = type(card) == "table" and card.feats
	if type(feats) == "table" then
		local points = (tonumber(feats.account) or 0) + (tonumber(feats.char) or 0)
		if points > 0 then
			local rank = self.FeatRank and select(2, Call(self.FeatRank, self, points)) or nil
			if type(rank) == "string" then parts[#parts + 1] = rank end
			parts[#parts + 1] = self:F("COM_TR_POINTS", Thousands(points))
		end
	end
	parts[#parts + 1] = Plural(self, "COM_TR_SPECIES", card and card.species or 0)
	parts[#parts + 1] = Plural(self, "COM_TR_SHINIES", card and card.shinies or 0)
	return table.concat(parts, " · ")
end

-- nom et titre : « Xan, Maîtresse des brillantes » (le titre rendu ici si
-- son code est connu, sinon le texte reçu)
function ns:TrainerKnownHeading(view)
	local short = tostring(view.name or "?"):match("^([^%-]+)") or tostring(view.name)
	local card = view.card
	local titled = card.titleCode and self.FeatTitleText and Call(self.FeatTitleText, self, card.titleCode, short, card.gender)
	if type(titled) == "string" and titled ~= "" then return titled end
	if type(card.title) == "string" and card.title ~= "" then return short .. ", " .. card.title end
	return short
end

-- « reçu par code · autre royaume · 18/11 »
function ns:TrainerKnownSeen(view)
	local parts = { L["COM_TR_ORIGIN_" .. view.origin] or view.origin }
	if view.otherRealm then parts[#parts + 1] = L.COM_TR_OTHER_REALM end
	if view.otherFaction then parts[#parts + 1] = L.COM_TR_OTHER_FACTION end
	local dateFn = G("date") or (os and os.date)
	local ok, day = pcall(dateFn, L.COM_TR_DATE, view.at)
	if ok and type(day) == "string" and view.at > 0 then parts[#parts + 1] = day end
	return table.concat(parts, " · ")
end

local function Pane(self)
	local frame = self.journalFrame
	return frame and frame.community
end

-- champ du code : lecture seule, tout sélectionné au clic, focus au clic seulement
local function CodeBox(pane, parent, width)
	local box = Theme.CreateSearchBox(parent, width, "", nil)
	if box.SetMaxLetters then box:SetMaxLetters(ns.TRAINER_CODE_MAX) end
	box.codeText = ""
	box:SetScript("OnTextChanged", function(self)
		if (self:GetText() or "") ~= self.codeText then
			self:SetText(self.codeText)
			if self.HighlightText then self:HighlightText() end
		end
		if self.Refresh then self:Refresh() end
	end)
	box:SetScript("OnEditFocusGained", function(self) if self.HighlightText then self:HighlightText() end end)
	box:SetScript("OnMouseUp", function(self)
		if self.SetFocus then self:SetFocus() end
		if self.HighlightText then self:HighlightText() end
	end)
	box:SetScript("OnEnterPressed", function(self) if self.ClearFocus then self:ClearFocus() end end)
	function box:SetCode(text)
		self.codeText = tostring(text or "")
		self:SetText(self.codeText)
		if self.SetCursorPosition then self:SetCursorPosition(0) end
	end
	box.comGround, box.comInk = "field", Theme.LABEL
	pane.texts[#pane.texts + 1] = box
	pane.edits[#pane.edits + 1] = box
	return box
end

local function Status(kit, pane, tile, width)
	local text = kit.Label(pane, tile, Theme.F_SMALL, Theme.MUTED_LIGHT, width, "tile")
	kit.Place(text, tile, 10, 6)
	if text.SetWordWrap then text:SetWordWrap(false) end
	text:Hide()
	return text
end

local function BuildRow(self, kit, pane, view, index)
	local W = ns.JournalUI.INNER
	local row = Theme.CreateTile(view, W, LAY.rowH, { kind = "Button", accent = false })
	if index % 2 == 0 and row.SetFill then row:SetFill(Theme.Over and Theme.Over(Theme.ROW, Theme.WHITE, 0.02) or Theme.ROW) end
	if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	row.portrait = Theme.CreateIcon(row, LAY.portrait, nil, 1)
	kit.Place(row.portrait, row, 8, 6)
	row.name = kit.Label(pane, row, Theme.F_LABEL, Theme.PARCHMENT, LAY.seenRight - LAY.nameX - 200, "tile")
	kit.Place(row.name, row, LAY.nameX, LAY.nameY)
	if row.name.SetWordWrap then row.name:SetWordWrap(false) end
	row.line = kit.Label(pane, row, Theme.F_SMALL, Theme.MUTED_LIGHT, LAY.seenRight - LAY.nameX - 140, "tile")
	kit.Place(row.line, row, LAY.nameX, LAY.lineY)
	if row.line.SetWordWrap then row.line:SetWordWrap(false) end
	row.seen = kit.Label(pane, row, Theme.F_SMALL, Theme.MUTED, nil, "tile")
	row.seen:ClearAllPoints()
	row.seen:SetPoint("TOPRIGHT", row, "TOPLEFT", LAY.seenRight, -LAY.seenY)
	row.seen:SetJustifyH("RIGHT")
	if row.seen.SetWordWrap then row.seen:SetWordWrap(false) end
	row.cardButton = Theme.CreateButton(row, LAY.cardW, "sm", L.COM_TR_CARD, function()
		if row.key then ns:TrainerKnownOpen(row.key) end
	end, "outline")
	kit.Place(row.cardButton, row, LAY.cardX, LAY.buttonY)
	row.compareButton = Theme.CreateButton(row, LAY.compareW, "sm", L.COM_TR_COMPARE, function()
		if row.key and not row.compareButton.inactive then ns:TrainerKnownCompare(row.key) end
	end, "outline")
	kit.Place(row.compareButton, row, LAY.compareX, LAY.buttonY)
	row:SetScript("OnClick", function(_, mouse) ns:CommunityTrainersRowClick(index, mouse) end)
	row:Hide()
	return row
end

-- construit l'onglet (appelé par la page à sa construction)
function ns:CommunityBuildTrainers(pane, view)
	local kit = ns.CommunityKit
	if not (kit and pane and view) then return end
	local W = ns.JournalUI.INNER
	view.trainers = true
	pane.trainersFilter = pane.trainersFilter or "all"
	pane.trainersOffset = 0

	-- mon code
	local mine = Theme.CreateTile(view, LAY.tileW, LAY.tileH, { kind = "Frame", accent = false })
	kit.Place(mine, view, 0, LAY.tileY)
	view.mine = mine
	mine.head = Theme.CreateSection(mine, L.COM_TR_MY_HEAD)
	kit.Place(mine.head, mine, 10, LAY.headY - 5)
	mine.head:SetWidth(LAY.tileW - 20)
	mine.status = Status(kit, pane, mine, LAY.tileW - 20)
	mine.box = CodeBox(pane, mine, LAY.fieldW)
	kit.Place(mine.box, mine, 10, LAY.fieldY)
	mine.button = Theme.CreateButton(mine, LAY.buttonW, "sm", L.COM_TR_COPY, function() ns:CommunityTrainersCopy() end, "outline")
	kit.Place(mine.button, mine, LAY.buttonX, LAY.fieldY)

	-- ouvrir un code reçu
	local open = Theme.CreateTile(view, LAY.tileW, LAY.tileH, { kind = "Frame", accent = false })
	kit.Place(open, view, LAY.tileX2, LAY.tileY)
	view.open = open
	open.head = Theme.CreateSection(open, L.COM_TR_OPEN_HEAD)
	kit.Place(open.head, open, 10, LAY.headY - 5)
	open.head:SetWidth(LAY.tileW - 20)
	open.status = Status(kit, pane, open, LAY.tileW - 20)
	open.box = Theme.CreateSearchBox(open, LAY.fieldW, L.COM_TR_PASTE, function()
		pane.trainersMessage = nil
		ns:CommunityTrainersPaintTop()
	end)
	if open.box.SetMaxLetters then open.box:SetMaxLetters(ns.TRAINER_CODE_MAX + 500) end
	kit.Place(open.box, open, 10, LAY.fieldY)
	open.box:SetScript("OnEnterPressed", function() ns:CommunityTrainersOpenClick() end)
	open.box.comGround, open.box.comInk = "field", Theme.LABEL
	open.box.placeholder.comGround, open.box.placeholder.comInk = "field", Theme.MUTED
	pane.texts[#pane.texts + 1] = open.box
	pane.texts[#pane.texts + 1] = open.box.placeholder
	pane.edits[#pane.edits + 1] = open.box
	open.button = Theme.CreateButton(open, LAY.buttonW, "sm", L.COM_TR_OPEN, function() ns:CommunityTrainersOpenClick() end, "outline")
	kit.Place(open.button, open, LAY.buttonX, LAY.fieldY)

	-- dresseurs connus : intertitre, filtres, lignes
	view.knownHead = kit.Section(pane, view, "COM_TR_KNOWN_HEAD", 0, LAY.knownHeadY, LAY.knownHeadW)
	local defs = {}
	for i, id in ipairs(ns.TRAINER_KNOWN_FILTERS) do defs[i] = { id = id, label = L["COM_TR_FILTER_" .. id] } end
	view.filters = Theme.CreateChips(view, defs, function(id) ns:CommunityTrainersFilter(id) end,
		{ height = 24, gap = 4, selected = pane.trainersFilter })
	kit.Tighten(view.filters, 4)
	view.filters:ClearAllPoints()
	view.filters:SetPoint("TOPRIGHT", view, "TOPLEFT", W, -LAY.chipsY)
	for _, chip in ipairs(view.filters.chips) do
		chip.text.comGround, chip.text.comInk = "chip", Theme.MUTED_LIGHT
		pane.texts[#pane.texts + 1] = chip.text
	end
	view.rows = {}
	for index = 1, LAY.rows do
		local row = BuildRow(self, kit, pane, view, index)
		kit.Place(row, view, 0, LAY.rowY + (index - 1) * LAY.rowStep)
		view.rows[index] = row
	end
	view.empty = kit.Label(pane, view, Theme.F_SMALL, Theme.MUTED_LIGHT, W, "page")
	kit.Place(view.empty, view, 0, LAY.rowY + 6)
	-- la molette fait défiler la liste
	if view.EnableMouseWheel then view:EnableMouseWheel(true) end
	view:SetScript("OnMouseWheel", function(_, delta) ns:CommunityTrainersScroll(delta) end)

	-- parrainage
	local mentor = Theme.CreateTile(view, W, LAY.mentorH, { kind = "Frame", accent = false })
	kit.Place(mentor, view, 0, LAY.mentorY)
	mentor:SetSelected(true)
	view.mentor = mentor
	mentor.title = kit.Label(pane, mentor, Theme.F_LABEL, Theme.PARCHMENT, LAY.mentorTextW, "tile")
	kit.Place(mentor.title, mentor, 12, 8)
	if mentor.title.SetWordWrap then mentor.title:SetWordWrap(false) end
	mentor.text = kit.Label(pane, mentor, Theme.F_SMALL, Theme.MUTED_LIGHT, LAY.mentorTextW, "tile")
	kit.Place(mentor.text, mentor, 12, 25)
	mentor.button = Theme.CreateButton(mentor, LAY.mentorButtonW, "sm", L.COM_TR_MENTOR_BUTTON, function() ns:CommunityMentorClick() end, "accent")
	kit.Place(mentor.button, mentor, LAY.mentorButtonX, LAY.mentorButtonY)
	mentor.cancel = Theme.CreateButton(mentor, LAY.mentorButtonW, "sm", L.COM_TR_MENTOR_CANCEL, function() ns:CommunityMentorCancel() end, "outline")
	kit.Place(mentor.cancel, mentor, LAY.mentorButtonX, LAY.mentorButtonY + 13)
	mentor.cancel:Hide()

	view.note = kit.Label(pane, view, Theme.F_SMALL, Theme.MUTED, W, "page")
	kit.Place(view.note, view, 0, LAY.noteY)
	view.note:SetText(L.COM_TR_NOTE)
end

local function TrainersView(self)
	local pane = Pane(self)
	local view = pane and pane.views and pane.views.dresseurs
	if not (view and view.trainers) then return nil end
	return pane, view
end

-- le haut : mon code, le champ à ouvrir, la phrase qui remplace l'intertitre
function ns:CommunityTrainersPaintTop()
	local pane, view = TrainersView(self)
	if not pane then return end
	local kit = ns.CommunityKit
	local mine, open = view.mine, view.open
	local ok, code = pcall(self.TrainerCodeMake, self)
	if ok and type(code) == "string" and code ~= mine.box.codeText then mine.box:SetCode(code) end
	local copied = pane.trainersCopied
	mine.status:SetText(copied and L.COM_TR_COPY_DONE or "")
	kit.Recolor(mine.status, Theme.GREEN)
	if copied then mine.status:Show(); mine.head:Hide() else mine.status:Hide(); mine.head:Show() end
	local message = pane.trainersMessage
	if message then
		open.status:SetText(message.text)
		kit.Recolor(open.status, message.ok and Theme.GREEN or Theme.LABEL)
		open.status:Show(); open.head:Hide()
	else
		open.status:Hide(); open.head:Show()
	end
	local typed = ns.TrainerCodeClean(open.box:GetText()) ~= ""
	if open.button.SetInactive then open.button:SetInactive(not typed, L.COM_TR_OPEN_TIP) end
end

-- combien de lignes tiennent : 5, ou 4 quand l'encadré du parrainage est là
local function Slots(self)
	return self:TrainerMentorOpen() and 4 or LAY.rows
end

function ns:CommunityTrainersPaint()
	local pane, view = TrainersView(self)
	if not pane then return end
	local kit = ns.CommunityKit
	self:CommunityTrainersPaintTop()
	-- le compteur à droite des onglets
	if pane.tab == "dresseurs" and pane.tabNote then
		pane.tabNote:SetText(self:TrainerKnownCountText())
	end
	local filter = pane.trainersFilter or "all"
	if view.filters.selected ~= filter then view.filters:Select(filter, true) end
	for _, chip in ipairs(view.filters.chips) do chip.text.comInk = chip.id == filter and Theme.PARCHMENT or Theme.MUTED_LIGHT end
	local list = self:TrainerKnownList(filter)
	pane.trainersList = list
	local slots = Slots(self)
	local maxOffset = math.max(0, #list - slots)
	pane.trainersOffset = math.max(0, math.min(pane.trainersOffset or 0, maxOffset))
	local picking = pane.mentorState == "pick"
	for index, row in ipairs(view.rows) do
		local item = index <= slots and list[index + pane.trainersOffset] or nil
		row.item, row.key = item, item and item.key or nil
		if item then
			row.name:SetText(self:TrainerKnownHeading(item))
			row.line:SetText(self:TrainerKnownLine(item.card))
			row.seen:SetText(self:TrainerKnownSeen(item))
			local comp = item.card.companion
			if self.CreaturePortrait and type(comp) == "table" then
				pcall(self.CreaturePortrait, self, row.portrait.tex, { display = comp.display, npc = comp.npc, type = nil })
			elseif row.portrait.SetItem then
				row.portrait:SetItem(ns.CREATURE_PORTRAIT_ICON or "Interface\\Icons\\Ability_Hunter_BeastTaming", 1)
			end
			local ready = type(item.card.featBits) == "string"
			row.compareButton:SetInactive(not ready, not ready and L.TRAINER_COMPARE_OLD or nil)
			row:SetSelected(picking and pane.mentorKey == item.key)
			row:Show()
		else
			row:Hide()
		end
	end
	if #list == 0 then
		view.empty:SetText(self:TrainerKnownCount() == 0 and L.COM_TR_EMPTY or L.COM_TR_EMPTY_FILTER)
		view.empty:Show()
	else
		view.empty:Hide()
	end
	self:CommunityMentorPaint()
end

function ns:CommunityMentorPaint()
	local pane, view = TrainersView(self)
	if not pane then return end
	local mentor = view.mentor
	if not self:TrainerMentorOpen() then
		pane.mentorState, pane.mentorKey = nil, nil
		mentor:Hide()
		return
	end
	mentor:Show()
	local state = pane.mentorState
	mentor.title:SetText(L.COM_TR_MENTOR_TITLE)
	mentor.button:ClearAllPoints()
	ns.CommunityKit.Place(mentor.button, mentor, LAY.mentorButtonX, LAY.mentorButtonY)
	if state == "pick" then
		mentor.text:SetText(pane.mentorError or L.COM_TR_MENTOR_PICK)
		mentor.button:Hide()
		mentor.cancel:ClearAllPoints()
		ns.CommunityKit.Place(mentor.cancel, mentor, LAY.mentorButtonX, LAY.mentorButtonY)
		mentor.cancel:Show()
	elseif state == "confirm" then
		local view2 = self:TrainerKnownGet(pane.mentorKey)
		local reach = self:TrainerMentorReach(view2)
		mentor.title:SetText(self:F("COM_TR_MENTOR_ASK", view2 and self:TrainerKnownHeading(view2) or "?"))
		mentor.text:SetText(L["COM_TR_MENTOR_REACH_" .. reach])
		mentor.button:SetText(L.COM_TR_MENTOR_CONFIRM)
		mentor.button:ClearAllPoints()
		ns.CommunityKit.Place(mentor.button, mentor, LAY.mentorButtonX, 8)
		mentor.button:Show()
		mentor.cancel:ClearAllPoints()
		ns.CommunityKit.Place(mentor.cancel, mentor, LAY.mentorButtonX, 8 + 26)
		mentor.cancel:Show()
	else
		mentor.text:SetText(L.COM_TR_MENTOR_TEXT)
		mentor.button:SetText(L.COM_TR_MENTOR_BUTTON)
		mentor.button:Show()
		mentor.cancel:Hide()
	end
end

function ns:CommunityTrainersFilter(id)
	local pane = TrainersView(self)
	if not pane then return end
	pane.trainersFilter, pane.trainersOffset = id, 0
	self:CommunityTrainersPaint()
end

function ns:CommunityTrainersScroll(delta)
	local pane = TrainersView(self)
	if not pane then return end
	pane.trainersOffset = (pane.trainersOffset or 0) - (tonumber(delta) or 0)
	self:CommunityTrainersPaint()
end

-- « Copier » : le code sélectionné (le joueur fait Ctrl+C) ; compteur au premier
function ns:CommunityTrainersCopy()
	local pane, view = TrainersView(self)
	if not pane then return nil end
	self:CommunityTrainersPaintTop()
	local box = view.mine.box
	if box.SetFocus then box:SetFocus() end
	if box.HighlightText then box:HighlightText() end
	pane.trainersCopied = true
	self:CommunityTrainersPaintTop()
	if type(self.TallyAdd) == "function" then
		local first = true
		if type(self.TallyGet) == "function" then
			local ok, n = pcall(self.TallyGet, self, "codeCopy")
			first = not (ok and (tonumber(n) or 0) > 0)
		end
		if first then pcall(self.TallyAdd, self, "codeCopy") end
	end
	return box.codeText
end

-- « Ouvrir » (ou Entrée) : la fiche du code s'ouvre et se range ; un code
-- faux le dit en une phrase
function ns:CommunityTrainersOpenClick()
	local pane, view = TrainersView(self)
	if not pane then return nil end
	local box = view.open.box
	local state, a, isNew = self:TrainerKnownOpenCode(box:GetText())
	if state == "error" then
		if a == "empty" then
			pane.trainersMessage = nil
		else
			pane.trainersMessage = { ok = false, text = self:TrainerCodeReason(a) }
		end
	else
		box:SetText("")
		pane.trainersMessage = nil
		if state == "self" then
			pane.trainersMessage = { ok = true, text = L.COM_TR_OPENED_SELF }
		else
			local short = tostring(a.name):match("^([^%-]+)") or a.name
			pane.trainersMessage = { ok = true, text = self:F(isNew and "COM_TR_OPENED_NEW" or "COM_TR_OPENED_AGAIN", short) }
			pane.trainersOffset = 0
		end
	end
	if box.ClearFocus then box:ClearFocus() end
	self:CommunityTrainersPaint()
	return state, a
end

-- clic sur une ligne : droit, retirer ; gauche pendant le choix du parrain : le choisir
function ns:CommunityTrainersRowClick(index, mouse)
	local pane, view = TrainersView(self)
	if not pane then return nil end
	local row = view.rows[index]
	local key = row and row.key
	if not key then return nil end
	if mouse == "RightButton" then
		local item = row.item
		if self:TrainerKnownRemove(key) then
			if pane.mentorKey == key then pane.mentorState, pane.mentorKey = nil, nil end
			if type(self.Print) == "function" then
				self:Print(self:F("COM_TR_REMOVED", tostring(item and item.name or key):match("^([^%-]+)") or key))
			end
			self:CommunityTrainersPaint()
			return "removed"
		end
		return nil
	end
	if pane.mentorState == "pick" then
		if self:TrainerIsOwnCharacter(key) then
			pane.mentorError = L.COM_TR_MENTOR_SELF
		else
			pane.mentorError = nil
			pane.mentorState, pane.mentorKey = "confirm", key
		end
		self:CommunityTrainersPaint()
		return pane.mentorState
	end
	return nil
end

function ns:CommunityMentorClick()
	local pane = TrainersView(self)
	if not pane then return nil end
	if pane.mentorState == "confirm" then
		local ok, reason = self:TrainerMentorDesignate(pane.mentorKey)
		if ok then
			pane.mentorState, pane.mentorKey, pane.mentorError = nil, nil, nil
		elseif reason == "self" then
			pane.mentorState, pane.mentorError = "pick", L.COM_TR_MENTOR_SELF
		else
			pane.mentorState, pane.mentorKey = nil, nil
		end
		self:CommunityTrainersPaint()
		return ok, reason
	end
	pane.mentorState, pane.mentorKey, pane.mentorError = "pick", nil, nil
	self:CommunityTrainersPaint()
	return "pick"
end

function ns:CommunityMentorCancel()
	local pane = TrainersView(self)
	if not pane then return end
	pane.mentorState, pane.mentorKey, pane.mentorError = nil, nil, nil
	self:CommunityTrainersPaint()
end

if ns.Mark then ns.Mark("TrainerKnown") end
