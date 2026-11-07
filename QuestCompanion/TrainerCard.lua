-- TrainerCard.lua -- Lot 5 : fiche de dresseur partagée entre joueurs (QuestCompanion 2.0)
--
-- Chaque détenteur de l'addon a une fiche de dresseur : son nom, son titre de
-- dresseur, la date de sa première capture, le compagnon qu'il emmène
-- (modèle 3D, rareté, brillant, effets), une vitrine de 3 créatures qu'il
-- choisit, ses chiffres (espèces, brillantes, sceaux) et ses sceaux par
-- continent. Rien de privé : ni position, ni or, ni sacs.
--
-- Échange par messages d'addon invisibles (C_ChatInfo), préfixe « QCTrainer ».
-- Protocole versionné et tolérant : un message est « type~version~… » ; un
-- type ou un champ inconnu est ignoré, une version plus récente est lue quand
-- même (ce qu'on comprend). Types :
--   H  bonjour : annonce au groupe, au raid, à la guilde (« j'ai l'addon »)
--   A  accusé : réponse en chuchotement à H ou à P (« moi aussi »)
--   P  sonde : chuchotement silencieux quand on cible un joueur
--   R  demande de la fiche (chuchotement)
--   N  refus (fiche non partagée)
--   C  fiche : C~1~<série>~<morceau>~<total>~<texte>, découpée en morceaux
--      de 200 octets au plus (limite du client : 255 par message)
--   E  exploit annoncé à la guilde (GuildFeats.lua)
-- La fiche est une liste « clé=valeur » séparée par « ; », les listes par
-- « , » ; les caractères réservés sont échappés en %XX. Pas de bibliothèque.
-- Titres et hauts faits (2.7.0, champs facultatifs, ignorés des versions
-- d'avant) : ti = code du titre affiché (1 à 255, registre ns.FEAT_TITLES),
-- tg = forme « m » ou « f », ap / aq = points de hauts faits du compte et du
-- personnage, ac = hauts faits obtenus. Le champ t (titre déjà rendu, nu,
-- dans la langue de l'expéditeur) reste envoyé pour les versions d'avant ;
-- le destinataire rend ti dans sa langue, et retombe sur t si le code lui
-- est inconnu.
--
-- Envoi : file d'attente avec limite de débit (seau de 6 messages, un de plus
-- par seconde), jamais en combat ni pendant un verrou de messagerie (moteur
-- récent : rencontres) ; un message refusé par le client (débit, codes 3 et 8)
-- est réessayé une seconde plus tard, 5 fois au plus. Sans réponse au bout de 12 s : « Pas de fiche reçue ».
-- Découverte : annonce à l'entrée en groupe / raid / guilde, sonde quand on
-- cible un joueur hors combat (une fois par joueur et par session) ; cache
-- des détenteurs dans la sauvegarde, oublié au bout de 14 jours.
-- Affichage : « Voir sa fiche de dresseur » dans le menu du clic droit sur un
-- joueur (Menu.ModifyMenu), seulement pour les détenteurs connus ; une ligne
-- « Dresseur QuestCompanion » dans leur infobulle (Tooltips.lua) ; la fenêtre
-- de fiche ; sa propre fiche depuis le carnet (bouton du pied) ou /qc fiche.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	TRAINER_TITLE          = "Fiche de dresseur",
	TRAINER_MINE           = "Ma fiche de dresseur",
	TRAINER_MENU           = "Voir sa fiche de dresseur",
	TRAINER_TOOLTIP        = "Dresseur QuestCompanion",
	TRAINER_DEFAULT_TITLE  = "Dresseur QuestCompanion",
	TRAINER_PENDING        = "Demande de la fiche de %s…",
	TRAINER_NONE           = "Pas de fiche reçue de %s.",
	TRAINER_NONE_HINT      = "Hors ligne, en combat ou en rencontre ? Réessaie plus tard.",
	TRAINER_REFUSED        = "%s ne partage pas sa fiche de dresseur.",
	TRAINER_RETRY          = "Redemander",
	TRAINER_SHARE          = "Partager ma fiche",
	TRAINER_SHARE_DESC     = "Les autres joueurs qui ont QuestCompanion peuvent voir ta fiche de dresseur (compagnon, vitrine, chiffres). Coupé : ta fiche n'est envoyée à personne et l'addon reste muet.",
	TRAINER_FIRST          = "Première capture : %s",
	TRAINER_FIRST_NONE     = "Pas encore de capture",
	TRAINER_SPECIES        = "Espèces capturées : %d / %d",
	TRAINER_SHINIES        = "Brillantes capturées : %d",
	TRAINER_SHINY_SEEN     = "Brillantes reconnues : %d",
	TRAINER_SEALS          = "Sceaux de zone : %d",
	TRAINER_COMPANION      = "Compagnon",
	TRAINER_SHOWCASE       = "Vitrine",
	TRAINER_SHOWCASE_EMPTY = "Vide",
	TRAINER_SHOWCASE_NONE  = "— vide —",
	TRAINER_BADGES         = "Sceaux par continent",
	TRAINER_BADGES_NONE    = "Aucun sceau pour l'instant",
	TRAINER_STARS          = "%d/3 étoiles",
	TRAINER_SHINY          = "brillant",
	TRAINER_MASCOT         = "mascotte",
	TRAINER_HUNT           = "Chasse : %s",
	TRAINER_COMFORT        = "Confort : %s",
	TRAINER_FX_WAIT        = "(effets bientôt actifs)",
	TRAINER_CONT_ek        = "Royaumes de l'Est",
	TRAINER_CONT_ka        = "Kalimdor",
	TRAINER_CONT_other     = "Ailleurs",
	TRAINER_RECEIVED       = "Fiche reçue %s",
	TRAINER_NOW            = "à l'instant",
	TRAINER_AGO            = "il y a %d min",
	TRAINER_MSG_SHARE      = "Fiche de dresseur partagée : %s.",
	TRAINER_ON             = "oui",
	TRAINER_OFF            = "non",
	TRAINER_MSG_UNKNOWN    = "%s n'est pas connu comme dresseur QuestCompanion : demande envoyée quand même.",
	TRAINER_FEATS          = "Hauts faits : %d · %d points",
	TRAINER_FEATS_SPLIT    = "Hauts faits : %d · %d points (compte %d, perso %d)",
	TRAINER_TITLE_FORM     = "Forme",
	OPT_DAILY_TRAINER      = "Partager ma fiche de dresseur",
	HELP_TRAINER           = "/qc fiche [nom] — ta fiche de dresseur, ou celle d'un autre joueur",
}
local EN = {
	TRAINER_TITLE          = "Trainer card",
	TRAINER_MINE           = "My trainer card",
	TRAINER_MENU           = "View trainer card",
	TRAINER_TOOLTIP        = "QuestCompanion trainer",
	TRAINER_DEFAULT_TITLE  = "QuestCompanion trainer",
	TRAINER_PENDING        = "Asking %s for their card…",
	TRAINER_NONE           = "No card received from %s.",
	TRAINER_NONE_HINT      = "Offline, in combat or in an encounter? Try again later.",
	TRAINER_REFUSED        = "%s does not share their trainer card.",
	TRAINER_RETRY          = "Ask again",
	TRAINER_SHARE          = "Share my card",
	TRAINER_SHARE_DESC     = "Other players with QuestCompanion can see your trainer card (companion, showcase, numbers). Off: your card is sent to no one and the addon stays silent.",
	TRAINER_FIRST          = "First capture: %s",
	TRAINER_FIRST_NONE     = "No capture yet",
	TRAINER_SPECIES        = "Species captured: %d / %d",
	TRAINER_SHINIES        = "Shinies captured: %d",
	TRAINER_SHINY_SEEN     = "Shinies spotted: %d",
	TRAINER_SEALS          = "Zone seals: %d",
	TRAINER_COMPANION      = "Companion",
	TRAINER_SHOWCASE       = "Showcase",
	TRAINER_SHOWCASE_EMPTY = "Empty",
	TRAINER_SHOWCASE_NONE  = "— empty —",
	TRAINER_BADGES         = "Seals by continent",
	TRAINER_BADGES_NONE    = "No seal yet",
	TRAINER_STARS          = "%d/3 stars",
	TRAINER_SHINY          = "shiny",
	TRAINER_MASCOT         = "mascot",
	TRAINER_HUNT           = "Hunt: %s",
	TRAINER_COMFORT        = "Comfort: %s",
	TRAINER_FX_WAIT        = "(effects active soon)",
	TRAINER_CONT_ek        = "Eastern Kingdoms",
	TRAINER_CONT_ka        = "Kalimdor",
	TRAINER_CONT_other     = "Elsewhere",
	TRAINER_RECEIVED       = "Card received %s",
	TRAINER_NOW            = "just now",
	TRAINER_AGO            = "%d min ago",
	TRAINER_MSG_SHARE      = "Trainer card sharing: %s.",
	TRAINER_ON             = "on",
	TRAINER_OFF            = "off",
	TRAINER_MSG_UNKNOWN    = "%s is not known as a QuestCompanion trainer: request sent anyway.",
	TRAINER_FEATS          = "Achievements: %d · %d points",
	TRAINER_FEATS_SPLIT    = "Achievements: %d · %d points (account %d, character %d)",
	TRAINER_TITLE_FORM     = "Form",
	OPT_DAILY_TRAINER      = "Share my trainer card",
	HELP_TRAINER           = "/qc fiche [name] — your trainer card, or another player's",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRAINER_STRINGS = { fr = FR, en = EN } end

-- ---------------------------------------------------------------------------
-- Réglages et constantes
-- ---------------------------------------------------------------------------
ns.RegisterDefaults({ trainerShare = true })
if type(ns.DAILY_OPTION_ROWS) == "table" then
	local present = false
	for _, row in ipairs(ns.DAILY_OPTION_ROWS) do if row.key == "trainerShare" then present = true end end
	if not present then
		table.insert(ns.DAILY_OPTION_ROWS, { key = "trainerShare", label = "OPT_DAILY_TRAINER", kind = "bool",
			describe = function() return L.TRAINER_SHARE_DESC end,
			onChange = function() ns:TrainerRefreshWindow() end })
	end
end

ns.TRAINER_PREFIX = "QCTrainer"     -- 16 caractères au plus
ns.TRAINER_PROTO = 1
ns.TRAINER_CHUNK = 200              -- octets de fiche par message (255 en tout)
ns.TRAINER_MAX_MSG = 255
ns.TRAINER_BURST = 6                -- messages d'affilée au plus
ns.TRAINER_RATE = 1                 -- messages regagnés par seconde
ns.TRAINER_QUEUE_MAX = 40
ns.TRAINER_QUEUE_TTL = 60           -- s : un message trop vieux n'est plus envoyé
ns.TRAINER_RETRY_MAX = 5            -- essais d'un message refusé par le client (débit)
ns.TRAINER_RETRY_DELAY = 1          -- s avant de réessayer
ns.TRAINER_TIMEOUT = 12             -- s sans fiche : « Pas de fiche reçue »
ns.TRAINER_ANSWER_GAP = 10          -- s entre deux envois de fiche au même joueur
ns.TRAINER_ACK_GAP = 300            -- s entre deux accusés au même joueur
ns.TRAINER_ANNOUNCE_GAP = 60        -- s entre deux annonces sur un même canal
ns.TRAINER_HOLDER_TTL = 14 * 86400  -- un détenteur pas revu depuis 14 jours est oublié
ns.TRAINER_CARD_FRESH = 60          -- s : fiche reçue récente, pas redemandée
ns.TRAINER_INBOX_TTL = 30           -- s pour recevoir tous les morceaux d'une fiche
ns.TRAINER_IN_WINDOW = 10           -- s : fenêtre du plafond de messages reçus par joueur
ns.TRAINER_IN_MAX = 40              -- messages reçus d'un même joueur par fenêtre (une fiche : 20 au plus)
ns.TRAINER_OWN_TTL = 300            -- s : ma fiche sérialisée gardée (en plus de sa clé)
ns.TRAINER_SHOWCASE_SIZE = 3
ns.TRAINER_CONTINENTS = { "ek", "ka", "other" }
-- menus du clic droit sur un joueur (moteur récent, Menu.ModifyMenu)
ns.TRAINER_MENUS = { "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID",
	"MENU_UNIT_FRIEND", "MENU_UNIT_GUILD", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_COMMUNITIES_MEMBER",
	"MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS" }

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g = pcall(fn, ...)
	if ok then return a, b, c, d, e, f, g end
	return nil
end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Epoch() return tonumber(Call(G("time"))) or 0 end
-- (pas « ns.Plain(v) or v » : une valeur secrète reviendrait telle quelle)
local function Plain(v)
	if ns.Plain then return ns.Plain(v) end
	return v
end
local function Str(v)
	v = Plain(v)
	if type(v) == "string" and v ~= "" then return v end
	return nil
end

-- État de la session (rien de tout ça n'est sauvegardé)
local state = {
	queue = {}, tokens = ns.TRAINER_BURST, seq = 0,
	inbox = {},      -- expéditeur -> { seq, total, parts, got, at }
	cards = {},      -- expéditeur -> { card, at }
	pending = {},    -- joueur demandé -> { at, status = "pending" | "none" | "refused" | "ok" }
	probed = {},     -- joueur sondé cette session
	answered = {},   -- joueur -> instant du dernier envoi de fiche
	acked = {},      -- joueur -> instant du dernier accusé
	announced = {},  -- canal -> instant de la dernière annonce
	incoming = {},   -- expéditeur -> { at, n } : plafond des messages reçus
}
-- Toutes ces tables (et le cache des détenteurs) sont indexées par la clé
-- d'un joueur (ns:TrainerKey : minuscules, royaume sans espaces ni traits
-- d'union) : « Élodie », « élodie », « Bob-Hyjal » et « bob-hyjal » sont les mêmes.
ns.trainerState = state

-- remise à zéro (tests, /reload simulé)
function ns:TrainerResetSession()
	state.queue, state.tokens, state.seq = {}, ns.TRAINER_BURST, 0
	state.inbox, state.cards, state.pending, state.probed = {}, {}, {}, {}
	state.answered, state.acked, state.announced, state.incoming = {}, {}, {}, {}
	state.inGroup, state.guildAnnounced, state.ownText, state.holdUntil = nil, nil, nil, nil
end

function ns:TrainerSharing()
	return self:DB().trainerShare ~= false
end

function ns:TrainerSetSharing(on)
	self:DB().trainerShare = on and true or false
	self:Print(self:F("TRAINER_MSG_SHARE", on and L.TRAINER_ON or L.TRAINER_OFF))
	self:TrainerRefreshWindow()
end

-- ---------------------------------------------------------------------------
-- Noms : toujours « Nom-Royaume » (royaume sans espaces), comme l'expéditeur
-- d'un message d'addon
-- ---------------------------------------------------------------------------
local function MyRealm()
	local realm = Str(Call(G("GetNormalizedRealmName")))
	if not realm then realm = Str(Call(G("GetRealmName"))) end
	return realm and (realm:gsub("[%s%-]", "")) or "?"
end

-- Minuscules, lettres accentuées comprises (À..Þ en UTF-8, sauf ×). Pas de
-- string.lower : selon la locale du client, il touche aussi aux octets > 127
-- et casserait l'UTF-8.
local function Lower(text)
	text = text:gsub("\195([\128-\158])", function(c)
		if c == "\151" then return nil end
		return "\195" .. string.char(c:byte() + 32)
	end)
	return (text:gsub("[A-Z]", function(c) return string.char(c:byte() + 32) end))
end

-- Royaume : sans espaces ni traits d'union (« Azjol-Nerub » -> « AzjolNerub »),
-- comme l'expéditeur d'un message d'addon et le menu (contextData.server)
function ns:TrainerFullName(name, realm)
	name, realm = Str(name), Str(realm)
	if not name then return nil end
	if not realm then
		local n, r = name:match("^([^%-]+)%-(.+)$")
		if n then name, realm = n, r end
	end
	realm = realm and (realm:gsub("[%s%-]", "")) or MyRealm()
	if realm == "" then realm = MyRealm() end
	return name .. "-" .. realm
end

-- Clé d'un joueur (tables de session, cache des détenteurs) : insensible à la casse
function ns:TrainerKey(name)
	local full = self:TrainerFullName(name)
	return full and Lower(full) or nil
end

local function IsMe(self, key)
	return key ~= nil and key == self:TrainerKey(self:TrainerMe())
end

function ns:TrainerMe()
	local name, realm = Call(G("UnitFullName"), "player")
	if not Str(name) then name, realm = Call(G("UnitName"), "player") end
	return self:TrainerFullName(name, realm)
end

-- Nom affiché : sans le royaume s'il est le nôtre
function ns:TrainerShortName(full)
	full = tostring(full or "?")
	local name, realm = full:match("^([^%-]+)%-(.+)$")
	if name and Lower(realm) == Lower(MyRealm()) then return name end
	return full
end

-- Nom complet d'une unité joueur (cible, survol, groupe), ou nil
function ns:TrainerUnitName(unit)
	if type(unit) ~= "string" then return nil end
	if not Plain(Call(G("UnitIsPlayer"), unit)) then return nil end
	local name, realm = Call(G("UnitFullName"), unit)
	if not Str(name) then name, realm = Call(G("UnitName"), unit) end
	return self:TrainerFullName(name, realm)
end

-- ---------------------------------------------------------------------------
-- Cache des détenteurs (sauvegarde du compte, avec expiration)
-- ---------------------------------------------------------------------------
function ns:TrainerHolders()
	local db = self:DB()
	if type(db.trainerHolders) ~= "table" then db.trainerHolders = {} end
	-- clés d'avant (« Nom-Royaume » avec la casse) : passées en clés de joueur, une fois
	if db.trainerHoldersV ~= 1 then
		local old = db.trainerHolders
		db.trainerHolders = {}
		for name, seen in pairs(old) do
			local key = type(name) == "string" and self:TrainerKey(name)
			if key and type(seen) == "number" and seen > (db.trainerHolders[key] or 0) then db.trainerHolders[key] = seen end
		end
		db.trainerHoldersV = 1
	end
	return db.trainerHolders
end

function ns:TrainerPruneHolders(now)
	now = now or Epoch()
	local holders = self:TrainerHolders()
	local removed = 0
	for name, seen in pairs(holders) do
		if type(seen) ~= "number" or now - seen > ns.TRAINER_HOLDER_TTL then
			holders[name] = nil
			removed = removed + 1
		end
	end
	return removed
end

function ns:TrainerMarkHolder(name)
	local key = self:TrainerKey(name)
	if not key or IsMe(self, key) then return end
	self:TrainerHolders()[key] = Epoch()
end

function ns:TrainerIsHolder(name)
	local key = self:TrainerKey(name)
	if not key or IsMe(self, key) then return false end
	local seen = self:TrainerHolders()[key]
	return type(seen) == "number" and Epoch() - seen <= ns.TRAINER_HOLDER_TTL
end

-- ---------------------------------------------------------------------------
-- Sérialisation : « clé=valeur;clé=valeur », listes « a,b,c », caractères
-- réservés échappés en %XX
-- ---------------------------------------------------------------------------
local RESERVED = "[%%;=,~|:\r\n%z]"
local function Escape(value)
	return (tostring(value):gsub(RESERVED, function(c) return string.format("%%%02X", c:byte()) end))
end
local function Unescape(value)
	return (tostring(value):gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end
ns.TrainerEscape, ns.TrainerUnescape = Escape, Unescape

-- fields : { clé = valeur | { éléments } } -> texte (clés triées : sortie stable)
function ns.TrainerEncode(fields)
	local keys = {}
	for key, value in pairs(fields or {}) do
		if value ~= nil and value ~= false then keys[#keys + 1] = key end
	end
	table.sort(keys)
	local parts = {}
	for _, key in ipairs(keys) do
		local value = fields[key]
		if type(value) == "table" then
			local items = {}
			for index, item in ipairs(value) do items[index] = Escape(item) end
			value = table.concat(items, ",")
		elseif value == true then
			value = "1"
		else
			value = Escape(value)
		end
		parts[#parts + 1] = Escape(key) .. "=" .. value
	end
	return table.concat(parts, ";")
end

-- texte -> { clé = texte brut (listes non découpées) } ; tolérant : un
-- morceau sans « = » est ignoré
function ns.TrainerDecode(text)
	local fields = {}
	if type(text) ~= "string" then return fields end
	for pair in text:gmatch("[^;]+") do
		local key, value = pair:match("^([^=]+)=(.*)$")
		if key then fields[Unescape(key)] = value end
	end
	return fields
end

local function ListOf(raw)
	local list = {}
	if type(raw) ~= "string" or raw == "" then return list end
	for item in (raw .. ","):gmatch("([^,]*),") do list[#list + 1] = Unescape(item) end
	return list
end

-- coupe à `max` octets au plus sans couper un caractère UTF-8 en deux
local function Utf8Cut(value, max)
	if #value <= max then return value end
	local cut = max
	-- l'octet qui suit la coupe doit commencer un caractère (pas 10xxxxxx)
	while cut > 0 do
		local b = value:byte(cut + 1)
		if not b or b < 128 or b >= 192 then break end
		cut = cut - 1
	end
	return value:sub(1, cut)
end
ns.TrainerUtf8Cut = Utf8Cut

-- texte reçu d'un autre joueur, sûr à afficher : pas de codes |c, |T, |H
-- (un « | » s'écrit « || »), longueur bornée
local function SafeText(value, max)
	if type(value) ~= "string" then return nil end
	value = value:gsub("[%c]", "")
	value = Utf8Cut(value, max or 48)
	value = value:gsub("|", "||")
	if value == "" then return nil end
	return value
end
-- des chiffres seulement, maxLen au plus (« 12a », « -3 », « 1e3 » refusés)
local function Digits(value, maxLen)
	if type(value) ~= "string" or #value < 1 or #value > maxLen or not value:find("^%d+$") then return nil end
	return tonumber(value)
end
local function Int(value, lo, hi)
	local n = tonumber(value)
	if not n then return nil end
	n = math.floor(n)
	if lo and n < lo then n = lo end
	if hi and n > hi then n = hi end
	return n
end

-- ---------------------------------------------------------------------------
-- Ma fiche : ce que j'envoie (et ce que je vois de moi)
-- ---------------------------------------------------------------------------
local function TypeKey(self, text)
	if not text then return nil end
	if ns.CREATURE_TYPES and ns.CREATURE_TYPES[text] then return text end
	return self.CreatureTypeKey and self:CreatureTypeKey(text) or nil
end

local function Stars(self, npc, shiny)
	if not self.CaptureStars then return nil end
	local ok, stars = pcall(self.CaptureStars, self, npc, shiny)
	return ok and tonumber(stars) or nil
end

-- vitrine : 3 emplacements, chacun « cap:<npc> » ou « cap:<npc>:s » (ou nil)
function ns:TrainerShowcase()
	local data = self:CompanionData()
	data.trainer = type(data.trainer) == "table" and data.trainer or {}
	data.trainer.showcase = type(data.trainer.showcase) == "table" and data.trainer.showcase or {}
	return data.trainer.showcase
end

local function ParseCapId(id)
	if type(id) ~= "string" then return nil end
	local npc, shiny = id:match("^cap:(%d+)(:?s?)$")
	if not npc then return nil end
	return tonumber(npc), shiny == ":s"
end

-- Ne garde que des versions vraiment capturées
function ns:TrainerSetShowcase(slot, id)
	slot = tonumber(slot)
	if not slot or slot < 1 or slot > ns.TRAINER_SHOWCASE_SIZE then return false end
	local showcase = self:TrainerShowcase()
	if id == nil or id == "" or id == "none" then
		showcase[slot] = false
		self:TrainerRefreshWindow()
		return true
	end
	local npc, shiny = ParseCapId(id)
	if not npc or not (self.CaptureHas and self:CaptureHas(npc, shiny)) then return false end
	-- une même créature n'occupe qu'un emplacement
	for index = 1, ns.TRAINER_SHOWCASE_SIZE do
		if index ~= slot and showcase[index] == id then showcase[index] = false end
	end
	showcase[slot] = id
	self:TrainerRefreshWindow()
	return true
end

local function Continent(self, zoneID)
	if self.JournalContinentOf then
		local ok, key = pcall(self.JournalContinentOf, self, zoneID)
		if ok and type(key) == "string" then return key end
	end
	return "other"
end

-- Ma fiche, en table (même forme que celle reçue d'un autre joueur)
function ns:TrainerOwnCard()
	local card = { proto = ns.TRAINER_PROTO, name = self:TrainerMe() or "?", showcase = {}, badges = {} }
	if self.TrainerTitle then
		local ok, title = pcall(self.TrainerTitle, self)
		if ok and type(title) == "string" and title ~= "" then card.title = title end
	end
	-- titre des hauts faits (FeatsTitles.lua) : code et forme ; le texte nu
	-- (champ t) suit, pour les versions d'avant
	if self.FeatTitleCode then
		local ok, code = pcall(self.FeatTitleCode, self)
		if ok and code then
			card.titleCode, card.gender = code, Call(self.FeatTitleGender, self) or "m"
			card.title = Call(self.FeatTitleText, self, code, nil, card.gender) or card.title
		end
	end
	if self.FeatPoints then
		local account, count = Call(self.FeatPoints, self, "account")
		local char, charCount = Call(self.FeatPoints, self, "char")
		if account and char then
			card.feats = { account = account, char = char, count = (count or 0) + (charCount or 0) }
		end
	end
	local capture = self.CaptureData and self:CaptureData() or { creatures = {} }
	-- première capture : la date figée (lot 1 : capture.firstAt, firstAt par
	-- fiche), pas `at` qu'une recapture meilleure remplace
	local first = self.CaptureEarliestAt and Call(self.CaptureEarliestAt, self) or nil
	if not first then
		for _, entry in pairs(capture.creatures or {}) do
			if type(entry) == "table" then
				for _, at in ipairs({ tonumber(entry.firstAt) or false, tonumber(entry.at) or false, tonumber(entry.shinyAt) or false }) do
					if at and at > 0 and (not first or at < first) then first = at end
				end
			end
		end
	end
	card.first = first
	-- chiffres : la ménagerie entière
	if self.MenagerieList then
		local ok, _, stats = pcall(self.MenagerieList, self, { zone = "all" })
		if ok and type(stats) == "table" then
			card.species, card.total = stats.captured or 0, stats.total or 0
			card.shinies, card.shinySeen = stats.shinies or 0, stats.shinySeen or 0
		end
	end
	card.shinies = card.shinies or (self.CaptureShinyCount and self:CaptureShinyCount()) or 0
	if self.MenagerieSeals then
		local ok, seals = pcall(self.MenagerieSeals, self)
		if ok and type(seals) == "table" then
			card.seals = #seals
			for _, zoneID in ipairs(seals) do
				local key = Continent(self, zoneID)
				card.badges[key] = (card.badges[key] or 0) + 1
			end
		end
	end
	-- compagnon en cours
	local app = self.CompanionCurrentAppearance and self:CompanionCurrentAppearance()
	if type(app) == "table" then
		local comp = { name = self.CompanionName and self:CompanionName() or nil, display = tonumber(app.display),
			npc = tonumber(app.npc), shiny = app.shiny and true or false, mascot = not app.captured }
		if app.captured and comp.npc then
			local entry = capture.creatures and capture.creatures[comp.npc]
			comp.class = (type(entry) == "table" and entry.class) or app.class
			comp.typeKey = TypeKey(self, type(entry) == "table" and entry.type or nil)
			comp.stars = Stars(self, comp.npc, comp.shiny)
		end
		if self.CompanionEffects then
			local ok, fx = pcall(self.CompanionEffects, self)
			if ok and type(fx) == "table" then
				comp.typeKey = fx.typeKey or comp.typeKey
				comp.strength = tonumber(fx.strength)
				comp.active = fx.active and true or false
				comp.hunt = type(fx.hunt) == "table" and fx.hunt.label or nil
				comp.comfort = type(fx.comfort) == "table" and fx.comfort.label or nil
				-- envoyés en identifiant + valeur : le libellé se refait chez l'autre
				comp.huntId = type(fx.hunt) == "table" and fx.hunt.id or nil
				comp.huntValue = type(fx.hunt) == "table" and tonumber(fx.hunt.value) or nil
				comp.comfortId = type(fx.comfort) == "table" and fx.comfort.id or nil
				comp.comfortValue = type(fx.comfort) == "table" and tonumber(fx.comfort.value) or nil
			end
		end
		card.companion = comp
	end
	-- vitrine
	for slot = 1, ns.TRAINER_SHOWCASE_SIZE do
		local npc, shiny = ParseCapId(self:TrainerShowcase()[slot])
		local entry = npc and capture.creatures and capture.creatures[npc]
		if npc and type(entry) == "table" and self:CaptureHas(npc, shiny) then
			card.showcase[slot] = { npc = npc, shiny = shiny, class = entry.class, typeKey = TypeKey(self, entry.type),
				stars = Stars(self, npc, shiny), name = entry.name }
		end
	end
	return card
end

-- table -> texte
function ns:TrainerSerializeCard(card)
	local f = { p = card.proto or ns.TRAINER_PROTO, n = card.name, t = card.title, f = card.first,
		sp = card.species, st = card.total, sy = card.shinies, sr = card.shinySeen, se = card.seals }
	if card.titleCode then f.ti, f.tg = card.titleCode, card.gender == "f" and "f" or "m" end
	if card.feats then f.ap, f.aq, f.ac = card.feats.account, card.feats.char, card.feats.count end
	local comp = card.companion
	if comp then
		f.cl, f.cn, f.cd, f.cr = comp.name, comp.npc, comp.display, comp.class
		f.cs = comp.shiny and 1 or nil
		f.cm = comp.mascot and 1 or nil
		f.cy, f.ct, f.cp = comp.stars, comp.typeKey, comp.strength
		f.ca = comp.active == false and 0 or nil
		-- effets : identifiant et valeur (le libellé, long et traduit, se refait
		-- chez le destinataire) ; le libellé seulement s'il n'y a pas d'identifiant
		local function Value(v) return v and string.format("%.3f", v) or nil end
		if comp.huntId then f.hi, f.hv = comp.huntId, Value(comp.huntValue) else f.ch = comp.hunt end
		if comp.comfortId then f.ci, f.cv = comp.comfortId, Value(comp.comfortValue) else f.cc = comp.comfort end
	end
	for slot = 1, ns.TRAINER_SHOWCASE_SIZE do
		local item = card.showcase and card.showcase[slot]
		if item then
			f["v" .. slot] = { item.npc, item.shiny and 1 or 0, item.stars or "", item.class or "", item.typeKey or "",
				item.name or "" }
		end
	end
	local badges = {}
	for _, key in ipairs(ns.TRAINER_CONTINENTS) do
		local count = card.badges and tonumber(card.badges[key])
		if count and count > 0 then badges[#badges + 1] = key .. ":" .. count end
	end
	if #badges > 0 then f.b = badges end
	return ns.TrainerEncode(f)
end

local CLASSES = { normal = true, trivial = true, minus = true, elite = true, rare = true, rareelite = true, worldboss = true }

-- Libellé d'un effet reçu (identifiant du lot 2 + valeur), dans ma langue ;
-- nil si l'effet est inconnu ici
local function EffectLabel(self, id, value)
	local defs = ns.COMPANION_EFFECTS
	local def = type(id) == "string" and type(defs) == "table" and defs[id]
	value = tonumber(value)
	if not (def and value) then return nil end
	value = math.max(0, math.min(value, tonumber(def.cap) or value))
	local key = "EFF_" .. id
	if L[key] == nil or L[key] == key then return nil end
	local ok, text = pcall(self.F, self, key, math.floor(value * 100 + 0.5 + 1e-9))
	return ok and type(text) == "string" and text or nil
end

-- texte -> table, champs inconnus ignorés, valeurs bornées et sûres
function ns:TrainerParseCard(text)
	local f = ns.TrainerDecode(text)
	local function S(key, max) return SafeText(f[key] and Unescape(f[key]), max) end
	local card = { proto = Int(f.p, 0) or 1, name = S("n", 64), title = S("t", 64), first = Int(f.f, 0),
		species = Int(f.sp, 0, 100000), total = Int(f.st, 0, 100000), shinies = Int(f.sy, 0, 100000),
		shinySeen = Int(f.sr, 0, 100000), seals = Int(f.se, 0, 10000), showcase = {}, badges = {} }
	if f.cl or f.cn or f.cd then
		local class = S("cr", 16)
		local typeKey = S("ct", 16)
		card.companion = { name = S("cl", 48), npc = Int(f.cn, 1), display = Int(f.cd, 1), class = CLASSES[class or ""] and class or nil,
			shiny = f.cs == "1", mascot = f.cm == "1", stars = Int(f.cy, 1, 3), typeKey = typeKey,
			strength = tonumber(f.cp), active = f.ca ~= "0",
			hunt = EffectLabel(self, f.hi, f.hv) or S("ch", 160), comfort = EffectLabel(self, f.ci, f.cv) or S("cc", 160) }
	end
	for slot = 1, ns.TRAINER_SHOWCASE_SIZE do
		local list = ListOf(f["v" .. slot])
		local npc = Int(list[1], 1)
		if npc then
			local class = SafeText(list[4], 16)
			card.showcase[slot] = { npc = npc, shiny = list[2] == "1", stars = Int(list[3], 1, 3),
				class = CLASSES[class or ""] and class or nil, typeKey = SafeText(list[5], 16), name = SafeText(list[6], 48) }
		end
	end
	for _, item in ipairs(ListOf(f.b)) do
		local key, count = item:match("^(%w+):(%d+)$")
		if key then card.badges[key] = Int(count, 0, 10000) end
	end
	-- titre : un code connu ici (sinon le texte t), forme m ou f
	local code = Digits(f.ti, 3)
	if code and code >= 1 and code <= (ns.FEAT_TITLE_MAX or 255) and type(ns.FEAT_TITLES) == "table"
		and ns.FEAT_TITLES[code] then
		card.titleCode = code
		card.gender = f.tg == "f" and "f" or "m"
	end
	-- points : les trois champs, tous lisibles, ou rien
	local account, char, count = Digits(f.ap, 5), Digits(f.aq, 5), Digits(f.ac, 3)
	if account and char and count then card.feats = { account = account, char = char, count = count } end
	return card
end

-- ---------------------------------------------------------------------------
-- Transport : file d'attente, limite de débit, découpage
-- ---------------------------------------------------------------------------
local function ChatApi()
	local api = G("C_ChatInfo")
	if type(api) == "table" and type(api.SendAddonMessage) == "function" then return api end
	return nil
end

function ns:TrainerRegisterPrefix()
pcall(ns.TrainerHookMenus, ns)
	local api = G("C_ChatInfo")
	local fn = type(api) == "table" and api.RegisterAddonMessagePrefix or G("RegisterAddonMessagePrefix")
	if type(fn) ~= "function" then return false end
	local ok, result = pcall(fn, ns.TRAINER_PREFIX)
	-- moteur récent : un code (0 = réussi) ; ancien : un booléen
	state.prefixOk = ok and (result == nil or result == true or result == 0 or result == 1)
	return state.prefixOk and true or false
end

-- combat ou verrou de messagerie (rencontre, moteur récent) : on attend
function ns:TrainerBlocked()
	if Call(G("InCombatLockdown")) == true or Plain(Call(G("UnitAffectingCombat"), "player")) == true then return true end
	local api = G("C_ChatInfo")
	if type(api) == "table" and type(api.InChatMessagingLockdown) == "function" then
		local locked = Plain(Call(api.InChatMessagingLockdown))
		if locked == true then return true end
	end
	return false
end

local function Queue(text, channel, target)
	if #text > ns.TRAINER_MAX_MSG then return false end
	local queue = state.queue
	if #queue >= ns.TRAINER_QUEUE_MAX then table.remove(queue, 1) end
	queue[#queue + 1] = { text = text, channel = channel, target = target, at = Clock() }
	return true
end

-- Un message court : « type~version[~…] »
function ns:TrainerSend(kind, channel, target, ...)
	if not ChatApi() then return false end
	local parts = { kind, tostring(ns.TRAINER_PROTO) }
	for index = 1, select("#", ...) do parts[#parts + 1] = tostring((select(index, ...))) end
	return Queue(table.concat(parts, "~"), channel, target)
end

-- La fiche, en morceaux : C~1~<série>~<i>~<n>~<texte>
function ns:TrainerChunks(text, seq)
	local chunks, size = {}, ns.TRAINER_CHUNK
	local total = math.max(1, math.ceil(#text / size))
	for index = 1, total do
		local piece = text:sub((index - 1) * size + 1, index * size)
		chunks[index] = string.format("C~%d~%d~%d~%d~%s", ns.TRAINER_PROTO, seq, index, total, piece)
	end
	return chunks
end

-- Ma fiche en texte, gardée tant que rien ne change (captures, compagnon,
-- vitrine, effets) et au plus TRAINER_OWN_TTL secondes : une demande reçue
-- ne reconstruit pas toute la Ménagerie
local function OwnCardKey(self)
	local capture = self.CaptureData and self:CaptureData() or {}
	local data = self:CompanionData()
	local showcase = self:TrainerShowcase()
	local parts = { tostring(capture.serial), tostring(capture.count), tostring(data.appearance),
		tostring(showcase[1]), tostring(showcase[2]), tostring(showcase[3]),
		tostring(self.CompanionName and Call(self.CompanionName, self)), tostring(self:TrainerMe()) }
	if self.CompanionEffects then
		local ok, fx = pcall(self.CompanionEffects, self)
		if ok and type(fx) == "table" then parts[#parts + 1] = tostring(fx.active) .. ":" .. tostring(fx.strength) end
	end
	if self.FeatTitleCode then
		local ok, code = pcall(self.FeatTitleCode, self)
		parts[#parts + 1] = tostring(ok and code) .. ":" .. tostring(Call(self.FeatTitleGender, self))
			.. ":" .. tostring(Call(self.FeatPoints, self, nil))
	end
	return table.concat(parts, "|")
end

function ns:TrainerOwnCardText()
	local key, now = OwnCardKey(self), Clock()
	local cache = state.ownText
	if cache and cache.key == key and now >= cache.at and now - cache.at < ns.TRAINER_OWN_TTL then return cache.text end
	local text = self:TrainerSerializeCard(self:TrainerOwnCard())
	state.ownText = { key = key, text = text, at = now }
	return text
end

-- La fiche n'est pas construite ici (une demande peut arriver en combat, ou
-- en rafale) : une place dans la file, remplie au moment de l'envoi
function ns:TrainerSendCard(target)
	if not ChatApi() then return false end
	for _, msg in ipairs(state.queue) do
		if msg.card and msg.target == target then return true end
	end
	local queue = state.queue
	if #queue >= ns.TRAINER_QUEUE_MAX then table.remove(queue, 1) end
	queue[#queue + 1] = { card = true, channel = "WHISPER", target = target, at = Clock() }
	return true
end

-- Une place « fiche » en tête de file : remplacée par ses morceaux
local function ExpandCard(self, msg)
	state.seq = (state.seq % 999) + 1
	local ok, text = pcall(self.TrainerOwnCardText, self)
	if not ok or type(text) ~= "string" then return end
	for index, chunk in ipairs(self:TrainerChunks(text, state.seq)) do
		table.insert(state.queue, index, { text = chunk, channel = msg.channel, target = msg.target, at = Clock() })
	end
end

-- Envoie ce que le débit permet ; appelé par l'horloge (elapsed : s écoulées)
function ns:TrainerPump(elapsed)
	state.tokens = math.min(ns.TRAINER_BURST, state.tokens + (tonumber(elapsed) or 0) * ns.TRAINER_RATE)
	local now = Clock()
	self:TrainerCheckTimeouts(now)
	local queue = state.queue
	if #queue == 0 or self:TrainerBlocked() then return 0 end
	if state.holdUntil and now < state.holdUntil then return 0 end
	state.holdUntil = nil
	local api, sent = ChatApi(), 0
	while #queue > 0 and state.tokens >= 1 do
		local msg = table.remove(queue, 1)
		local fresh = now - (msg.at or now) <= ns.TRAINER_QUEUE_TTL
		if msg.card then
			if fresh then ExpandCard(self, msg) end
		elseif fresh and api then
			local ok, result = pcall(api.SendAddonMessage, ns.TRAINER_PREFIX, msg.text, msg.channel, msg.target)
			-- moteur récent : le client refuse un message de trop (codes 3 et 8,
			-- débit de l'addon ou du canal) ; il repart un peu plus tard, en tête
			if ok and (result == 3 or result == 8) and (msg.tries or 0) < ns.TRAINER_RETRY_MAX then
				msg.tries = (msg.tries or 0) + 1
				table.insert(queue, 1, msg)
				state.holdUntil = now + ns.TRAINER_RETRY_DELAY
				break
			end
			state.tokens = state.tokens - 1
			sent = sent + 1
		end
	end
	return sent
end

-- ---------------------------------------------------------------------------
-- Réception
-- ---------------------------------------------------------------------------
local function Split(text)
	local fields = {}
	for field in (text .. "~"):gmatch("([^~]*)~") do fields[#fields + 1] = field end
	return fields
end

-- key : clé du joueur (ns:TrainerKey)
local function Resolve(self, key, status)
	local pending = state.pending[key]
	if pending then pending.status = status end
	local frame = self.trainerFrame
	if frame and frame.viewing and self:TrainerKey(frame.viewing) == key then self:TrainerRefreshWindow() end
end

-- Un morceau de fiche ; une série incohérente (numéro hors du total, total
-- qui change en route) est rejetée, jamais d'erreur
local function OnCardChunk(self, sender, key, fields)
	local seq, index, total = Int(fields[3], 0), tonumber(fields[4]), tonumber(fields[5])
	if not (seq and index and total) or index ~= math.floor(index) or total ~= math.floor(total) then return end
	if total < 1 or total > 20 or index < 1 or index > total then return end
	-- le texte peut contenir « ~ » échappé seulement : le reste du message est le morceau
	local piece = table.concat(fields, "~", 6)
	local box = state.inbox[key]
	if not box or box.seq ~= seq or Clock() - box.at > ns.TRAINER_INBOX_TTL then
		box = { seq = seq, total = total, parts = {}, got = 0, at = Clock() }
		state.inbox[key] = box
	end
	if total ~= box.total or index > box.total then return end
	if box.parts[index] == nil then
		box.parts[index] = piece
		box.got = box.got + 1
	end
	if box.got < box.total then return end
	state.inbox[key] = nil
	local ok, card = pcall(function()
		local parts = {}
		for i = 1, box.total do
			if type(box.parts[i]) ~= "string" then error("morceau manquant") end
			parts[i] = box.parts[i]
		end
		return self:TrainerParseCard(table.concat(parts))
	end)
	if not ok or type(card) ~= "table" then return end
	card.sender = sender
	state.cards[key] = { card = card, at = Clock() }
	Resolve(self, key, "ok")
end

-- Plafond des messages reçus d'un même joueur : au-delà, ignorés
local function Flooded(key, now)
	local box = state.incoming[key]
	if not box or now < box.at or now - box.at >= ns.TRAINER_IN_WINDOW then
		box = { at = now, n = 0 }
		state.incoming[key] = box
	end
	box.n = box.n + 1
	return box.n > ns.TRAINER_IN_MAX
end

-- prefix, texte, canal, expéditeur : les arguments de CHAT_MSG_ADDON
function ns:TrainerOnAddonMessage(prefix, text, channel, sender)
	prefix, text, channel, sender = Plain(prefix), Plain(text), Plain(channel), Plain(sender)
	if prefix ~= ns.TRAINER_PREFIX or type(text) ~= "string" or type(sender) ~= "string" then return false end
	sender = self:TrainerFullName(sender)
	local key = sender and self:TrainerKey(sender)
	if not key or IsMe(self, key) then return false end
	local now = Clock()
	if Flooded(key, now) then return false end
	local fields = Split(text)
	local kind = fields[1]
	-- version illisible : ce n'est pas un message de QC
	if not tonumber(fields[2]) then return false end
	self:TrainerMarkHolder(sender)
	local sharing = self:TrainerSharing()
	if kind == "H" or kind == "P" then
		-- accusé (annonce ou sonde), au plus une fois toutes les 5 min par
		-- joueur ; muet si non partagé
		local last = state.acked[key]
		if sharing and (not last or now < last or now - last >= ns.TRAINER_ACK_GAP) then
			state.acked[key] = now
			self:TrainerSend("A", "WHISPER", sender)
		end
	elseif kind == "R" then
		if not sharing then
			self:TrainerSend("N", "WHISPER", sender)
		else
			local last = state.answered[key]
			if not last or now < last or now - last >= ns.TRAINER_ANSWER_GAP then
				state.answered[key] = now
				self:TrainerSendCard(sender)
			end
		end
	elseif kind == "N" then
		Resolve(self, key, "refused")
	elseif kind == "C" then
		OnCardChunk(self, sender, key, fields)
	end
	-- A et tout type inconnu : le détenteur est noté, rien d'autre
	return true
end

-- ---------------------------------------------------------------------------
-- Demandes
-- ---------------------------------------------------------------------------
function ns:TrainerRequest(name)
	name = self:TrainerFullName(name)
	local key = name and self:TrainerKey(name)
	if not key or IsMe(self, key) then return false end
	state.pending[key] = { at = Clock(), status = "pending" }
	self:TrainerSend("R", "WHISPER", name)
	return true
end

function ns:TrainerCheckTimeouts(now)
	now = now or Clock()
	for name, pending in pairs(state.pending) do
		if pending.status == "pending" and now - pending.at >= ns.TRAINER_TIMEOUT then
			Resolve(self, name, "none")
		end
	end
	for sender, box in pairs(state.inbox) do
		if now - box.at > ns.TRAINER_INBOX_TTL then state.inbox[sender] = nil end
	end
	for sender, box in pairs(state.incoming) do
		if now < box.at or now - box.at >= ns.TRAINER_IN_WINDOW then state.incoming[sender] = nil end
	end
end

-- La fiche reçue d'un joueur (table) et son âge, ou nil
function ns:TrainerCard(name)
	local entry = state.cards[self:TrainerKey(name) or ""]
	if not entry then return nil end
	return entry.card, Clock() - entry.at
end

function ns:TrainerStatus(name)
	local pending = state.pending[self:TrainerKey(name) or ""]
	return pending and pending.status or nil
end

-- ---------------------------------------------------------------------------
-- Découverte
-- ---------------------------------------------------------------------------
local function GroupChannel()
	local instance = G("LE_PARTY_CATEGORY_INSTANCE")
	local home = G("LE_PARTY_CATEGORY_HOME")
	if instance and Plain(Call(G("IsInGroup"), instance)) and not (home and Plain(Call(G("IsInGroup"), home))) then
		return "INSTANCE_CHAT"
	end
	if Plain(Call(G("IsInRaid"))) then return "RAID" end
	if Plain(Call(G("IsInGroup"))) then return "PARTY" end
	return nil
end

function ns:TrainerAnnounce(channel)
	if not channel or not self:TrainerSharing() then return false end
	local now, last = Clock(), state.announced[channel]
	if last and now - last < ns.TRAINER_ANNOUNCE_GAP then return false end
	state.announced[channel] = now
	return self:TrainerSend("H", channel)
end

-- Entrée dans un groupe (ou passage en raid) : une annonce
function ns:TrainerOnRoster()
	local channel = GroupChannel()
	local was = state.inGroup
	state.inGroup = channel
	if channel and channel ~= was then return self:TrainerAnnounce(channel) end
	return false
end

-- Guilde : une annonce par session (PLAYER_GUILD_UPDATE tombe souvent) ;
-- une nouvelle seulement après être sorti d'une guilde
function ns:TrainerOnGuild()
	if Plain(Call(G("IsInGuild"))) ~= true then
		state.guildAnnounced = nil
		return false
	end
	if state.guildAnnounced then return false end
	local sent = self:TrainerAnnounce("GUILD")
	if sent then state.guildAnnounced = true end
	return sent
end

-- Cible un joueur hors combat : une sonde silencieuse, une fois par session
function ns:TrainerOnTarget(unit)
	unit = unit or "target"
	if not self:TrainerSharing() or self:TrainerBlocked() then return false end
	local name = self:TrainerUnitName(unit)
	local key = name and self:TrainerKey(name)
	if not key or IsMe(self, key) or state.probed[key] then return false end
	-- chuchotement impossible vers l'autre faction
	if Plain(Call(G("UnitIsFriend"), "player", unit)) == false then return false end
	local mine, theirs = Plain(Call(G("UnitFactionGroup"), "player")), Plain(Call(G("UnitFactionGroup"), unit))
	if mine and theirs and mine ~= theirs then return false end
	state.probed[key] = true
	return self:TrainerSend("P", "WHISPER", name)
end

-- ---------------------------------------------------------------------------
-- Menu du clic droit et infobulle
-- ---------------------------------------------------------------------------
-- contextData du menu : name, server, unit (selon le menu)
function ns:TrainerMenuTarget(contextData)
	if type(contextData) ~= "table" then return nil end
	local name = Str(contextData.name)
	if name then return self:TrainerFullName(name, contextData.server) end
	return self:TrainerUnitName(contextData.unit)
end

function ns:TrainerMenuAdd(rootDescription, contextData)
	local name = self:TrainerMenuTarget(contextData)
	if not name or not self:TrainerIsHolder(name) then return false end
	if type(rootDescription) ~= "table" or type(rootDescription.CreateButton) ~= "function" then return false end
	if type(rootDescription.CreateDivider) == "function" then pcall(rootDescription.CreateDivider, rootDescription) end
	pcall(rootDescription.CreateButton, rootDescription, L.TRAINER_MENU, function() ns:TrainerOpen(name) end)
	return true
end

function ns:TrainerHookMenus()
	-- posées une fois ; sans Menu (pas encore chargé) on réessaiera à l'entrée en jeu
	if state.menuHooked then return state.menuHooked end
	local menu = G("Menu")
	if type(menu) ~= "table" or type(menu.ModifyMenu) ~= "function" then return 0 end
	local count = 0
	for _, tag in ipairs(ns.TRAINER_MENUS) do
		local ok = pcall(menu.ModifyMenu, tag, function(_, rootDescription, contextData)
			local done, err = pcall(ns.TrainerMenuAdd, ns, rootDescription, contextData)
			if not done and ns.RecordError then ns:RecordError("trainer:menu", err) end
		end)
		if ok then count = count + 1 end
	end
	if count > 0 then state.menuHooked = count end
	return count
end

-- Ligne de l'infobulle d'un joueur détenteur (Tooltips.lua, ns.UNIT_TOOLTIP_LINES)
function ns:TrainerTooltipLine(tooltip, data)
	local name
	if type(tooltip) == "table" and type(tooltip.GetUnit) == "function" then
		local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
		name = ok and self:TrainerUnitName(Plain(unit)) or nil
	end
	if not name and type(data) == "table" then
		local guid = Str(data.guid)
		if guid and guid:find("^Player%-") then
			local _, _, _, _, _, n, realm = Call(G("GetPlayerInfoByGUID"), guid)
			name = self:TrainerFullName(n, realm)
		end
	end
	if not name or not self:TrainerIsHolder(name) then return false end
	local text = L.TRAINER_TOOLTIP
	local card = self:TrainerCard(name)
	local title = card and card.titleCode and self.FeatTitleText and self:FeatTitleText(card.titleCode, nil, card.gender)
	title = title or (card and card.title)
	if title then text = text .. " · " .. title end
	tooltip:AddLine(text, Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	if data == nil and type(tooltip.Show) == "function" then pcall(tooltip.Show, tooltip) end
	return true
end
if type(ns.UNIT_TOOLTIP_LINES) == "table" then
	table.insert(ns.UNIT_TOOLTIP_LINES, function(self, tooltip, data) return self:TrainerTooltipLine(tooltip, data) end)
end

-- ---------------------------------------------------------------------------
-- Fenêtre de fiche
-- ---------------------------------------------------------------------------
local WIN_W, WIN_H, FOOT_H, PAD = 620, 530, 52, 20
local MODEL_W, MODEL_H = 200, 210
local COL_X = PAD + MODEL_W + 20
local COL_W = WIN_W - COL_X - PAD
local TILE_W, TILE_H, TILE_GAP = 180, 64, 10
local SHOW_Y = -356
ns.TRAINER_LAYOUT = { width = WIN_W, height = WIN_H, footer = FOOT_H }

local function Line(parent, font, color, width)
	local text = Theme.Text(parent, font or Theme.F_BODY, color or Theme.TEXT)
	text:SetJustifyH("LEFT")
	if width then text:SetWidth(width) end
	if text.SetWordWrap then text:SetWordWrap(false) end
	return text
end

local function NewModel(parent, w, h)
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, parent)
	if not ok or not model then return nil end
	model:SetSize(w, h)
	return model
end

-- un modèle : displayID d'abord (mascotte), sinon la créature (npcID)
local function ShowModel(model, display, npc, shiny, distance)
	if not model then return false end
	local shown = false
	if display and type(model.SetDisplayInfo) == "function" then shown = pcall(model.SetDisplayInfo, model, display) end
	if not shown and npc and type(model.SetCreature) == "function" then shown = pcall(model.SetCreature, model, npc) end
	if shown then
		if distance and type(model.SetCamDistanceScale) == "function" then pcall(model.SetCamDistanceScale, model, distance) end
		if ns.ModelShinyLight then ns.ModelShinyLight(model, shiny) end
		model.npc, model.display = npc, display
		model:Show()
	else
		if type(model.ClearModel) == "function" then pcall(model.ClearModel, model) end
		model.npc, model.display = nil, nil
		model:Hide()
	end
	return shown
end

local function FormatDate(ts)
	ts = tonumber(ts)
	if not ts or ts <= 0 then return nil end
	local fmt = (Call(G("GetLocale")) == "frFR") and "%d/%m/%Y" or "%Y-%m-%d"
	local dateFn = G("date") or (os and os.date)
	local ok, text = pcall(dateFn, fmt, ts)
	return ok and text or nil
end

local function ClassLabel(class)
	if not class or class == "normal" or class == "trivial" or class == "minus" then return nil end
	local key = "BST_CLASS_" .. class
	local text = L[key]
	return text ~= key and text or class
end

local function TypeLabel(self, key)
	if not key then return nil end
	if self.CreatureTypeLabel then
		local ok, text = pcall(self.CreatureTypeLabel, self, key)
		if ok and type(text) == "string" then return text end
	end
	return key
end

local function BuildTile(self, parent, x, slot)
	local tile = Theme.CreateTile(parent, TILE_W, TILE_H, { kind = "Frame", accent = "left" })
	tile:SetPoint("TOPLEFT", parent, "TOPLEFT", x, SHOW_Y - 22)
	tile.model = NewModel(tile, TILE_H - 8, TILE_H - 8)
	if tile.model then tile.model:SetPoint("LEFT", tile, "LEFT", 6, 0) end
	tile.name = Line(tile, Theme.F_LABEL, Theme.LABEL, TILE_W - TILE_H - 8)
	tile.name:SetPoint("TOPLEFT", tile, "TOPLEFT", TILE_H + 2, -10)
	tile.detail = Line(tile, Theme.F_SMALL, Theme.MUTED_LIGHT, TILE_W - TILE_H - 8)
	tile.detail:SetPoint("TOPLEFT", tile, "TOPLEFT", TILE_H + 2, -28)
	tile.stars = Line(tile, Theme.F_SMALL, Theme.GOLD, TILE_W - TILE_H - 8)
	tile.stars:SetPoint("TOPLEFT", tile, "TOPLEFT", TILE_H + 2, -44)
	-- ma fiche : une liste pour choisir la créature de l'emplacement
	tile.picker = Theme.CreateDropdown(parent, TILE_W, function(value) ns:TrainerSetShowcase(slot, value) end,
		{ listWidth = 240, maxRows = 10 })
	tile.picker:SetPoint("TOPLEFT", tile, "BOTTOMLEFT", 0, -6)
	tile.picker:Hide()
	tile.slot = slot
	return tile
end

function ns:EnsureTrainerWindow()
	if self.trainerFrame then return self.trainerFrame end
	if not (Theme and Theme.CreateWindow) then return nil end
	local frame = Theme.CreateWindow(UIParent, WIN_W, WIN_H, { name = "QuestCompanionTrainerFrame", footer = FOOT_H,
		strata = "FULLSCREEN" })
	if not frame then return nil end
	frame.chrome = "trainer"
	-- pas une fenêtre exclusive : ma fiche s'ouvre par-dessus le carnet (strate plus haute)
	if self.RestorePoint then self:RestorePoint(frame, "trainerPoint", { point = "CENTER", x = 0, y = 40 }) end
	local content = frame.content
	frame.header = Theme.CreatePageHeader(content, WIN_W - 2, { compact = true })
	frame.header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
	-- à droite de l'en-tête (ma fiche) : le choix du titre
	frame.titlePicker = Theme.CreateDropdown(content, 220, function(value)
		if ns.FeatTitlePick then ns:FeatTitlePick(value) end
	end, { listWidth = 300, maxRows = 12 })
	frame.titlePicker:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, -22)
	frame.titlePicker:Hide()

	-- message à la place de la fiche (demande en cours, rien reçu, refus)
	frame.status = Theme.Text(content, Theme.F_TITLE, Theme.PARCHMENT)
	frame.status:SetPoint("TOP", content, "TOP", 0, -170)
	frame.status:SetWidth(WIN_W - 80)
	frame.statusHint = Theme.Text(content, Theme.F_BODY, Theme.MUTED_LIGHT)
	frame.statusHint:SetPoint("TOP", frame.status, "BOTTOM", 0, -10)
	frame.statusHint:SetWidth(WIN_W - 80)

	local body = CreateFrame("Frame", nil, content)
	body:SetAllPoints()
	frame.body = body
	-- compagnon : grand modèle, nom, étiquettes, étoiles
	frame.compSection = Theme.CreateSection(body, L.TRAINER_COMPANION)
	frame.compSection:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -72)
	local stage = CreateFrame("Frame", nil, body)
	stage:SetSize(MODEL_W, MODEL_H)
	stage:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -94)
	stage.bg = Theme.Solid(stage, "BACKGROUND", Theme.NAV, 1)
	stage.bg:SetAllPoints()
	stage.border = Theme.Border(stage, Theme.EDGE_SOFT, 1)
	frame.stage = stage
	frame.model = NewModel(stage, MODEL_W - 8, MODEL_H - 8)
	if frame.model then frame.model:SetPoint("CENTER", stage, "CENTER", 0, 0) end
	frame.fallback = stage:CreateTexture(nil, "ARTWORK")
	frame.fallback:SetTexture(Theme.LOGO_SMALL)
	frame.fallback:SetSize(96, 96)
	frame.fallback:SetPoint("CENTER", stage, "CENTER", 0, 0)
	frame.compName = Line(body, Theme.F_TITLE, Theme.PARCHMENT, MODEL_W)
	frame.compName:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -8)
	frame.rankTag = Theme.CreateTag(body, "", Theme.BLUE)
	frame.rankTag:SetPoint("TOPLEFT", frame.compName, "BOTTOMLEFT", 0, -6)
	frame.shinyTag = Theme.CreateTag(body, "", Theme.GOLD_LIGHT)
	frame.shinyTag:SetPoint("LEFT", frame.rankTag, "RIGHT", 6, 0)

	-- colonne de droite : chiffres, effets, sceaux
	frame.infoSection = Theme.CreateSection(body, L.TRAINER_TITLE)
	frame.infoSection:SetPoint("TOPLEFT", body, "TOPLEFT", COL_X, -72)
	frame.lines = {}
	for index = 1, 8 do
		local line = Line(body, index <= 5 and Theme.F_BODY or Theme.F_SMALL, index <= 5 and Theme.TEXT or Theme.MUTED_LIGHT, COL_W)
		line:SetPoint("TOPLEFT", body, "TOPLEFT", COL_X, -96 - (index - 1) * 20)
		frame.lines[index] = line
	end
	frame.badgeSection = Theme.CreateSection(body, L.TRAINER_BADGES)
	frame.badgeSection:SetPoint("TOPLEFT", body, "TOPLEFT", COL_X, -262)
	frame.badges = {}
	for index, key in ipairs(ns.TRAINER_CONTINENTS) do
		local tag = Theme.CreateTag(body, "", Theme.GOLD)
		tag.key = key
		frame.badges[index] = tag
	end
	frame.badgeNone = Line(body, Theme.F_SMALL, Theme.MUTED, COL_W)
	frame.badgeNone:SetPoint("TOPLEFT", body, "TOPLEFT", COL_X, -286)

	-- vitrine : trois tuiles
	frame.showSection = Theme.CreateSection(body, L.TRAINER_SHOWCASE)
	frame.showSection:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, SHOW_Y)
	frame.tiles = {}
	for slot = 1, ns.TRAINER_SHOWCASE_SIZE do
		frame.tiles[slot] = BuildTile(self, body, PAD + (slot - 1) * (TILE_W + TILE_GAP), slot)
	end

	-- pied : partage (ma fiche), redemander (une autre), fermer
	local foot = frame.footer
	frame.shareToggle = Theme.CreateToggle(foot, 32, 15, "Button")
	frame.shareToggle:SetPoint("LEFT", foot, "LEFT", PAD, 0)
	frame.shareToggle:SetScript("OnClick", function() ns:TrainerSetSharing(not ns:TrainerSharing()) end)
	frame.shareLabel = Line(foot, Theme.F_LABEL, Theme.LABEL)
	frame.shareLabel:SetPoint("LEFT", frame.shareToggle, "RIGHT", 8, 0)
	frame.shareLabel:SetText(L.TRAINER_SHARE)
	-- forme des titres (ma fiche) : automatique, masculin, féminin
	frame.formLabel = Line(foot, Theme.F_LABEL, Theme.LABEL)
	frame.formLabel:SetPoint("LEFT", frame.shareLabel, "RIGHT", 24, 0)
	frame.formLabel:SetText(L.TRAINER_TITLE_FORM)
	frame.formPicker = Theme.CreateDropdown(foot, 120, function(value)
		if ns.FeatSetTitleForm then ns:FeatSetTitleForm(value) end
	end, { listWidth = 140 })
	frame.formPicker:SetPoint("LEFT", frame.formLabel, "RIGHT", 8, 0)
	-- au pied de la fenêtre : la liste s'ouvre vers le haut
	frame.formPicker:SetScript("OnClick", function(picker) if picker:IsOpen() then picker:Close() else picker:Open(true) end end)
	frame.received = Line(foot, Theme.F_SMALL, Theme.MUTED)
	frame.received:SetPoint("LEFT", foot, "LEFT", PAD, 0)
	frame.closeButton = Theme.CreateButton(foot, "auto", 28, L.OPT_CLOSE, function() frame:Hide() end, "accent")
	frame.closeButton:SetPoint("RIGHT", foot, "RIGHT", -PAD, 0)
	frame.retryButton = Theme.CreateButton(foot, "auto", 28, L.TRAINER_RETRY, function()
		if frame.viewing then ns:TrainerRequest(frame.viewing); ns:TrainerRefreshWindow() end
	end)
	frame.retryButton:SetPoint("RIGHT", frame.closeButton, "LEFT", -10, 0)
	frame:Hide()
	self.trainerFrame = frame
	return frame
end

-- liste des versions capturées pour la vitrine
function ns:TrainerShowcaseOptions()
	local options = { { value = "none", label = L.TRAINER_SHOWCASE_NONE } }
	local list = self.CaptureAppearances and self:CaptureAppearances() or {}
	local sorted = {}
	for _, def in ipairs(list) do sorted[#sorted + 1] = def end
	table.sort(sorted, function(a, b)
		local la, lb = tostring(a.label), tostring(b.label)
		if la ~= lb then return la < lb end
		return a.id < b.id
	end)
	for _, def in ipairs(sorted) do options[#options + 1] = { value = def.id, label = def.label } end
	return options
end

local function PaintTile(self, tile, item, own)
	if item then
		local name = item.name or ("#" .. tostring(item.npc))
		tile.name:SetText(item.shiny and self:F("CAPTURE_SHINY_TAG", name) or name)
		local parts = {}
		local rank = ClassLabel(item.class)
		if rank then parts[#parts + 1] = rank end
		local typeText = TypeLabel(self, item.typeKey)
		if typeText then parts[#parts + 1] = typeText end
		tile.detail:SetText(table.concat(parts, " · "))
		tile.stars:SetText(item.stars and self:F("TRAINER_STARS", item.stars) or "")
		tile:SetAccent(item.shiny and Theme.GOLD_LIGHT or Theme.GOLD)
		ShowModel(tile.model, nil, item.npc, item.shiny, 1.8)
	else
		tile.name:SetText(L.TRAINER_SHOWCASE_EMPTY)
		tile.detail:SetText("")
		tile.stars:SetText("")
		tile:SetAccent(nil)
		ShowModel(tile.model, nil, nil)
	end
	tile.item = item
	if own then
		tile.picker:SetOptions(self:TrainerShowcaseOptions())
		local value = self:TrainerShowcase()[tile.slot]
		tile.picker:SetValue(type(value) == "string" and value or "none")
		tile.picker:Show()
	else
		tile.picker:Hide()
	end
end

-- « Hauts faits : 64 · 615 points (compte 400, perso 215) », ou vide (aucun point)
function ns:TrainerCardFeatsText(card)
	local feats = card.feats
	if type(feats) ~= "table" then return "" end
	local account, char = tonumber(feats.account) or 0, tonumber(feats.char) or 0
	local count = tonumber(feats.count) or 0
	if account + char <= 0 then return "" end
	if account > 0 and char > 0 then return self:F("TRAINER_FEATS_SPLIT", count, account + char, account, char) end
	return self:F("TRAINER_FEATS", count, account + char)
end

-- Nom et titre de l'en-tête : un code connu ici est rendu dans ma langue et
-- à la bonne place (« Dresseur Dyokrion », « Dyokrion, Maître des
-- brillantes ») ; sinon le nom, et le texte reçu en sous-titre. Les points
-- de hauts faits suivent en sous-titre.
function ns:TrainerCardHeading(card, name)
	local titled = card.titleCode and self.FeatTitleText and self:FeatTitleText(card.titleCode, name, card.gender)
	local heading, subtitle = name, card.title
	if titled then heading, subtitle = titled, nil end
	local feats = self:TrainerCardFeatsText(card)
	if feats ~= "" then subtitle = subtitle and (subtitle .. "  ·  " .. feats) or feats end
	return heading, subtitle or L.TRAINER_DEFAULT_TITLE
end

local function PaintCard(self, frame, card, own)
	-- le nom vient de l'expéditeur réel, jamais du champ `n` reçu (usurpation)
	local name = self:TrainerShortName(own and card.name or card.sender or frame.viewing)
	local heading, subtitle = self:TrainerCardHeading(card, name)
	frame.header:SetTitle(heading)
	frame.header:SetSubtitle(subtitle)
	if own and self.FeatTitleOptions then
		frame.titlePicker:SetOptions(self:FeatTitleOptions(name))
		frame.titlePicker:SetValue(self:FeatTitleOptionValue())
		frame.titlePicker:Show()
		frame.formPicker:SetOptions(self:FeatTitleFormChoices())
		frame.formPicker:SetValue(self:FeatTitleForm())
	else
		frame.titlePicker:Hide()
	end
	local comp = card.companion
	if comp then
		local shown = ShowModel(frame.model, comp.display, comp.npc, comp.shiny, comp.mascot and 1.6 or 2.4)
		if shown then frame.fallback:Hide() else frame.fallback:Show() end
		frame.compName:SetText(comp.name or "?")
		frame.rankTag:SetTag(comp.mascot and L.TRAINER_MASCOT or ClassLabel(comp.class) or "", Theme.BLUE)
		frame.shinyTag:SetTag(comp.shiny and L.TRAINER_SHINY or "", Theme.GOLD_LIGHT)
	else
		ShowModel(frame.model, nil, nil)
		frame.fallback:Show()
		frame.compName:SetText("")
		frame.rankTag:SetTag("")
		frame.shinyTag:SetTag("")
	end
	local lines = {}
	local first = FormatDate(card.first)
	lines[#lines + 1] = first and self:F("TRAINER_FIRST", first) or L.TRAINER_FIRST_NONE
	if card.species then lines[#lines + 1] = self:F("TRAINER_SPECIES", card.species, card.total or card.species) end
	if card.shinies then lines[#lines + 1] = self:F("TRAINER_SHINIES", card.shinies) end
	if card.shinySeen then lines[#lines + 1] = self:F("TRAINER_SHINY_SEEN", card.shinySeen) end
	if card.seals then lines[#lines + 1] = self:F("TRAINER_SEALS", card.seals) end
	while #lines < 5 do lines[#lines + 1] = "" end
	-- effets du compagnon (lot 2), étoiles
	if comp then
		local typeText = TypeLabel(self, comp.typeKey)
		local head = {}
		if typeText then head[#head + 1] = typeText end
		if comp.stars then head[#head + 1] = self:F("TRAINER_STARS", comp.stars) end
		if #head > 0 then lines[#lines + 1] = table.concat(head, " · ") end
		if comp.hunt then lines[#lines + 1] = self:F("TRAINER_HUNT", comp.hunt) end
		if comp.comfort then lines[#lines + 1] = self:F("TRAINER_COMFORT", comp.comfort) end
		if (comp.hunt or comp.comfort) and comp.active == false then
			lines[#lines] = lines[#lines] .. " " .. L.TRAINER_FX_WAIT
		end
	end
	for index, line in ipairs(frame.lines) do line:SetText(lines[index] or "") end
	-- sceaux par continent
	local x, any = COL_X, false
	for _, tag in ipairs(frame.badges) do
		local count = card.badges and card.badges[tag.key]
		if count and count > 0 then
			tag:SetTag(L["TRAINER_CONT_" .. tag.key] .. " " .. count, Theme.GOLD)
			tag:ClearAllPoints()
			tag:SetPoint("TOPLEFT", frame.body, "TOPLEFT", x, -286)
			x = x + (tonumber(tag:GetWidth()) or 80) + 6
			any = true
		else
			tag:SetTag("")
		end
	end
	frame.badgeNone:SetText(any and "" or L.TRAINER_BADGES_NONE)
	for slot, tile in ipairs(frame.tiles) do PaintTile(self, tile, card.showcase and card.showcase[slot], own) end
end

function ns:TrainerRefreshWindow()
	local frame = self.trainerFrame
	if not (frame and frame:IsShown()) then return end
	local own = frame.viewing == nil
	if own then
		frame.shareToggle:SetChecked(self:TrainerSharing())
		frame.shareToggle:Show(); frame.shareLabel:Show()
		frame.received:Hide(); frame.retryButton:Hide()
		if self.FeatTitleForm then frame.formLabel:Show(); frame.formPicker:Show() end
	else
		frame.shareToggle:Hide(); frame.shareLabel:Hide()
		frame.received:Show(); frame.retryButton:Show()
		frame.formLabel:Hide(); frame.formPicker:Hide()
	end
	local card, age
	if own then
		card = self:TrainerOwnCard()
	else
		card, age = self:TrainerCard(frame.viewing)
	end
	local status = not own and self:TrainerStatus(frame.viewing) or nil
	local who = self:TrainerShortName(frame.viewing)
	if card then
		frame.status:SetText("")
		frame.statusHint:SetText("")
		frame.body:Show()
		PaintCard(self, frame, card, own)
		if age then
			local minutes = math.floor(age / 60)
			frame.received:SetText(self:F("TRAINER_RECEIVED", minutes < 1 and L.TRAINER_NOW or self:F("TRAINER_AGO", minutes)))
		end
	else
		frame.body:Hide()
		frame.header:SetTitle(who)
		frame.header:SetSubtitle(L.TRAINER_TITLE)
		frame.titlePicker:Hide()
		frame.received:SetText("")
		if status == "refused" then
			frame.status:SetText(self:F("TRAINER_REFUSED", who))
			frame.statusHint:SetText("")
		elseif status == "pending" then
			frame.status:SetText(self:F("TRAINER_PENDING", who))
			frame.statusHint:SetText("")
		else
			frame.status:SetText(self:F("TRAINER_NONE", who))
			frame.statusHint:SetText(L.TRAINER_NONE_HINT)
		end
	end
	frame.state = card and "card" or (status or "none")
end

-- name nil (ou moi) : ma fiche ; sinon celle d'un autre joueur, demandée
-- si on ne l'a pas reçue depuis une minute
function ns:TrainerOpen(name)
	local frame = self:EnsureTrainerWindow()
	if not frame then return nil end
	local full = name and self:TrainerFullName(name) or nil
	if full and IsMe(self, self:TrainerKey(full)) then full = nil end
	frame.viewing = full
	if full then
		local _, age = self:TrainerCard(full)
		local pending = state.pending[self:TrainerKey(full)]
		if not age or age > ns.TRAINER_CARD_FRESH then
			if not (pending and pending.status == "pending") then self:TrainerRequest(full) end
		end
	end
	frame:Show()
	self:TrainerRefreshWindow()
	return frame
end

-- /qc fiche [nom]
function ns:TrainerCommand(rest)
	rest = type(rest) == "string" and rest:gsub("^%s+", ""):gsub("%s+$", "") or ""
	if rest == "" then return self:TrainerOpen(nil) end
	local full = self:TrainerFullName(rest:sub(1, 1):upper() .. rest:sub(2))
	if full and not self:TrainerIsHolder(full) and not IsMe(self, self:TrainerKey(full)) then
		self:Print(self:F("TRAINER_MSG_UNKNOWN", self:TrainerShortName(full)))
	end
	return self:TrainerOpen(full)
end
if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["fiche"] = function(self, rest) self:TrainerCommand(rest) end
	ns.EXTRA_COMMANDS["trainer"] = ns.EXTRA_COMMANDS["fiche"]
	ns.EXTRA_COMMANDS["dresseur"] = ns.EXTRA_COMMANDS["fiche"]
end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_TRAINER")
		end
	end
end

-- Carnet : un bouton « Ma fiche de dresseur » dans le pied, à gauche de Fermer
do
	local ensure = ns.EnsureJournalWindow
	if type(ensure) == "function" then
		function ns:EnsureJournalWindow(...)
			local had = self.journalFrame
			local frame = ensure(self, ...)
			if frame and not had and frame.footer and not frame.trainerButton then
				local ok, button = pcall(Theme.CreateButton, frame.footer, "auto", 28, L.TRAINER_MINE,
					function() ns:TrainerOpen(nil) end)
				if ok and button then
					if frame.closeButton then
						button:SetPoint("RIGHT", frame.closeButton, "LEFT", -10, 0)
					else
						button:SetPoint("RIGHT", frame.footer, "RIGHT", -24, 0)
					end
					frame.trainerButton = button
				end
			end
			return frame
		end
	end
end

-- ---------------------------------------------------------------------------
-- Événements et horloge
-- ---------------------------------------------------------------------------
ns.TRAINER_TICK = 0.2
ns.TRAINER_LOGIN_DELAY = 8   -- s après l'entrée en jeu avant l'annonce à la guilde

function ns:TrainerOnEvent(event, ...)
	if event == "CHAT_MSG_ADDON" then
		return self:TrainerOnAddonMessage(...)
	elseif event == "GROUP_ROSTER_UPDATE" then
		return self:TrainerOnRoster()
	elseif event == "PLAYER_GUILD_UPDATE" then
		return self:TrainerOnGuild()
	elseif event == "PLAYER_TARGET_CHANGED" then
		return self:TrainerOnTarget("target")
	elseif event == "PLAYER_ENTERING_WORLD" then
		if state.entered then return false end
		state.entered = true
		self:TrainerPruneHolders()
		self:TrainerHookMenus()
		local function Later()
			ns:TrainerOnGuild()
			ns:TrainerOnRoster()
		end
		local timer = G("C_Timer")
		if type(timer) == "table" and type(timer.After) == "function" then
			pcall(timer.After, ns.TRAINER_LOGIN_DELAY, Later)
		else
			Later()
		end
		return true
	end
	return false
end

ns:TrainerRegisterPrefix()
pcall(ns.TrainerHookMenus, ns)
do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and frame then
		for _, event in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE",
			"PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD" }) do
			pcall(frame.RegisterEvent, frame, event)
		end
		frame:SetScript("OnEvent", function(_, event, ...)
			local done, err = pcall(ns.TrainerOnEvent, ns, event, ...)
			if not done and ns.RecordError then ns:RecordError("trainer:" .. tostring(event), err) end
		end)
		frame:SetScript("OnUpdate", ns.Throttle(ns.TRAINER_TICK, function(_, elapsed)
			local done, err = pcall(ns.TrainerPump, ns, elapsed)
			if not done and ns.RecordError then ns:RecordError("trainer:pump", err) end
		end))
		ns.trainerEventFrame = frame
	end
end

if ns.Mark then ns.Mark("TrainerCard") end
