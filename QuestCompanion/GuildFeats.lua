-- GuildFeats.lua -- exploits de la ménagerie annoncés à la guilde (QuestCompanion 2.4)
--
-- Les membres de la guilde qui ont aussi QuestCompanion voient passer les
-- beaux moments des autres : « Dyokrion a capturé une brillante ! ». Quatre
-- sortes d'exploits :
--   s  une brillante capturée (version nouvelle, ou de meilleures étoiles)
--   n  une espèce nouvelle notable : élite, rare, rare élite ou boss
--      (pas chaque loup commun)
--   z  un sceau de zone (100 % des espèces de la zone)
--   r  un palier d'espèces (10, 25, 50, 100, 250) et son titre de dresseur
--
-- Protocole : sur le préfixe de la fiche de dresseur (TrainerCard.lua), par
-- sa file d'attente (débit limité, rien en combat ni pendant un verrou de
-- messagerie, réessai si le client refuse pour cause de débit), canal GUILD
-- seulement. Un message :
--   E~1~<sorte>~<id>~<zone>~<étoiles>~<rang>~<autres>
--     id      npcID (s, n), zoneID (z), nombre d'espèces du palier (r)
--     zone    zoneID de la capture (s, n), 0 sinon
--     étoiles 0 à 3
--     rang    normal, elite, rare, rareelite, worldboss, ou « - »
--     autres  exploits regroupés avec celui-ci (0 à 99)
-- Rien d'autre ne voyage : pas de nom de créature ni de zone. Le
-- destinataire refait tout depuis SES données (tables de zone livrées,
-- carnet, ménagerie) ; un identifiant inconnu chez lui : le message est
-- ignoré. Seul le nom de l'expéditeur (donné par le client) est affiché.
--
-- Anti-spam à l'envoi : un exploit attend GFEAT_GATHER secondes que d'autres
-- le rejoignent (une capture en série), puis part le meilleur, avec « et N
-- autres » ; au plus une annonce toutes les GFEAT_GAP secondes.
-- À la réception : seulement depuis le canal GUILD, jamais de soi ; un
-- bandeau à la fois (comme « Capture possible »), une file de 3 (un par
-- membre, le meilleur gardé), périmé au bout d'une minute, son limité à un
-- par seconde ; clic : la fiche de dresseur de ce joueur. L'expéditeur est
-- noté comme détenteur de l'addon (menu du clic droit, infobulle).
-- Réglages (page « Au jour le jour », sous le partage de la fiche) :
-- « Annoncer mes exploits à la guilde », « Voir les exploits de la guilde »
-- (tous, brillantes seulement, aucun), « Exploits de la guilde dans le chat ».
--
-- Découverte paresseuse : survoler un joueur (infobulle) hors combat lui
-- envoie la sonde silencieuse de la fiche (une fois par joueur et par
-- session, comme le ciblage), au plus une par seconde, et pas s'il a été vu
-- comme détenteur il y a moins de 10 minutes.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	GFEAT_TITLE        = "Guilde",
	GFEAT_SHINY        = "%s a capturé une brillante !",
	GFEAT_NEW_elite    = "%s a capturé une élite !",
	GFEAT_NEW_rare     = "%s a capturé un rare !",
	GFEAT_NEW_rareelite = "%s a capturé un rare élite !",
	GFEAT_NEW_worldboss = "%s a capturé un boss du monde !",
	GFEAT_SEAL         = "%s a scellé une zone !",
	GFEAT_SEAL_SUB     = "Sceau de zone : %s",
	GFEAT_RANK         = "%s a capturé %d espèces !",
	GFEAT_RANK_SUB     = "Nouveau titre : %s",
	GFEAT_MORE_1       = "et 1 autre exploit",
	GFEAT_MORE         = "et %d autres exploits",
	GFEAT_HINT         = "Clic : sa fiche de dresseur",
	GFEAT_CHAT         = "Guilde — %s %s",
	OPT_DAILY_GFEAT_SEND      = "Annoncer mes exploits à la guilde",
	OPT_DAILY_GFEAT_SEND_DESC = "Brillantes, élites et rares capturés, sceaux de zone et titres de dresseur : les membres de ta guilde qui ont QuestCompanion les voient passer. Rien n'est envoyé si tu ne partages pas ta fiche de dresseur.",
	OPT_DAILY_GFEAT_SHOW      = "Voir les exploits de la guilde",
	OPT_DAILY_GFEAT_SHOW_DESC = "Un bandeau quand un membre de ta guilde qui a QuestCompanion réussit un bel exploit. Clic : sa fiche de dresseur.",
	GFEAT_SHOW_all     = "Tous",
	GFEAT_SHOW_shiny   = "Brillantes seulement",
	GFEAT_SHOW_off     = "Aucun",
	OPT_DAILY_GFEAT_CHAT      = "Exploits de la guilde dans le chat",
}
local EN = {
	GFEAT_TITLE        = "Guild",
	GFEAT_SHINY        = "%s captured a shiny!",
	GFEAT_NEW_elite    = "%s captured an elite!",
	GFEAT_NEW_rare     = "%s captured a rare!",
	GFEAT_NEW_rareelite = "%s captured a rare elite!",
	GFEAT_NEW_worldboss = "%s captured a world boss!",
	GFEAT_SEAL         = "%s sealed a zone!",
	GFEAT_SEAL_SUB     = "Zone seal: %s",
	GFEAT_RANK         = "%s captured %d species!",
	GFEAT_RANK_SUB     = "New title: %s",
	GFEAT_MORE_1       = "and 1 more feat",
	GFEAT_MORE         = "and %d more feats",
	GFEAT_HINT         = "Click: their trainer card",
	GFEAT_CHAT         = "Guild — %s %s",
	OPT_DAILY_GFEAT_SEND      = "Announce my feats to the guild",
	OPT_DAILY_GFEAT_SEND_DESC = "Shinies, elites and rares captured, zone seals and trainer titles: your guildmates who run QuestCompanion see them. Nothing is sent if you do not share your trainer card.",
	OPT_DAILY_GFEAT_SHOW      = "Show guild feats",
	OPT_DAILY_GFEAT_SHOW_DESC = "A banner when a guildmate who runs QuestCompanion pulls off a fine feat. Click: their trainer card.",
	GFEAT_SHOW_all     = "All",
	GFEAT_SHOW_shiny   = "Shinies only",
	GFEAT_SHOW_off     = "None",
	OPT_DAILY_GFEAT_CHAT      = "Guild feats in chat",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.GFEAT_STRINGS = { fr = FR, en = EN } end

-- ---------------------------------------------------------------------------
-- Réglages et constantes
-- ---------------------------------------------------------------------------
ns.RegisterDefaults({ guildFeatsSend = true, guildFeatsShow = "all", guildFeatsChat = false })

ns.GFEAT_KIND = "E"                -- type de message sur le préfixe de la fiche
ns.GFEAT_PROTO = 1
ns.GFEAT_GATHER = 4                -- s d'attente pour regrouper une série d'exploits
ns.GFEAT_GAP = 30                  -- s au moins entre deux annonces
ns.GFEAT_MORE_MAX = 99
ns.GFEAT_TOAST_SECONDS = 6         -- s d'affichage d'un bandeau
ns.GFEAT_TOAST_QUEUE = 3           -- bandeaux en attente au plus
ns.GFEAT_TOAST_STALE = 60          -- s : un exploit plus vieux n'est plus montré
ns.GFEAT_SOUND_GAP = 1             -- s au moins entre deux sons
ns.GFEAT_SOUNDS = { shiny = 63971, ok = 17316 }   -- mêmes kits que la capture (CaptureQueue.lua)
ns.GFEAT_SHOW_CHOICES = { "all", "shiny", "off" }
ns.GFEAT_PROBE_GAP = 1             -- s entre deux sondes au survol
ns.GFEAT_PROBE_FRESH = 600         -- s : détenteur vu récemment, pas resondé

-- espèces nouvelles annoncées : les rangs notables seulement
local NOTABLE = { elite = true, rare = true, rareelite = true, worldboss = true }
ns.GFEAT_NOTABLE = NOTABLE
local CLASS_RANK = { trivial = 0, minus = 0, normal = 1, elite = 2, rare = 3, rareelite = 4, worldboss = 5 }
local KINDS = { s = true, n = true, z = true, r = true }
-- rang Questie (tables de zone) -> classification (comme Bestiary.lua)
local RANK_CLASS = ns.BESTIARY_RANK_CLASS or { [1] = "elite", [2] = "rareelite", [3] = "worldboss", [4] = "rare" }
local TOAST_W, TOAST_H, TOAST_ICON = 340, 84, 34

if type(ns.DAILY_OPTION_ROWS) == "table" then
	local present, at = false, #ns.DAILY_OPTION_ROWS + 1
	for index, row in ipairs(ns.DAILY_OPTION_ROWS) do
		if row.key == "guildFeatsSend" then present = true end
		if row.key == "trainerShare" then at = index + 1 end
	end
	if not present then
		table.insert(ns.DAILY_OPTION_ROWS, at, { key = "guildFeatsSend", label = "OPT_DAILY_GFEAT_SEND", kind = "bool",
			describe = function() return L.OPT_DAILY_GFEAT_SEND_DESC end })
		table.insert(ns.DAILY_OPTION_ROWS, at + 1, { key = "guildFeatsShow", label = "OPT_DAILY_GFEAT_SHOW", kind = "action",
			choices = function() return ns:GuildFeatsShowChoices() end,
			current = function() return ns:GuildFeatsShowMode() end,
			describe = function() return L.OPT_DAILY_GFEAT_SHOW_DESC end,
			choose = function(value) ns:GuildFeatsSetShowMode(value) end })
		table.insert(ns.DAILY_OPTION_ROWS, at + 2, { key = "guildFeatsChat", label = "OPT_DAILY_GFEAT_CHAT", kind = "bool" })
	end
end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Epoch() return tonumber(Call(G("time"))) or 0 end
local function Plain(v)
	if ns.Plain then return ns.Plain(v) end
	return v
end
local function InGuild() return Plain(Call(G("IsInGuild"))) == true end
local function InCombat()
	if Call(G("InCombatLockdown")) == true then return true end
	return Plain(Call(G("UnitAffectingCombat"), "player")) == true
end

-- État de la session
local state = {
	out = nil,         -- { feat, count, first } : exploits en attente d'annonce
	lastSent = nil,    -- instant de la dernière annonce
	toasts = {},       -- { key, sender, feat, info, score, at }
	showing = nil,     -- l'exploit du bandeau affiché
	hideAt = nil,
	lastSound = nil,
	lastProbe = nil,
}
ns.guildFeatsState = state

function ns:GuildFeatsReset()
	state.out, state.lastSent, state.toasts, state.showing, state.hideAt = nil, nil, {}, nil, nil
	state.lastSound, state.lastProbe = nil, nil
	if self.guildFeatToast then self.guildFeatToast:Hide() end
end

-- ---------------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------------
function ns:GuildFeatsSending()
	if self:DB().guildFeatsSend == false then return false end
	-- fiche non partagée : l'addon reste muet (TrainerCard.lua)
	if self.TrainerSharing and not self:TrainerSharing() then return false end
	return true
end

function ns:GuildFeatsShowMode()
	local mode = self:DB().guildFeatsShow
	if mode == "shiny" or mode == "off" then return mode end
	return "all"
end

function ns:GuildFeatsSetShowMode(mode)
	if mode ~= "all" and mode ~= "shiny" and mode ~= "off" then return nil end
	self:DB().guildFeatsShow = mode
	if mode == "off" then
		state.toasts = {}
		self:GuildFeatsHideToast()
	elseif mode == "shiny" then
		local kept = {}
		for _, item in ipairs(state.toasts) do if item.feat.kind == "s" then kept[#kept + 1] = item end end
		state.toasts = kept
	end
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
	return mode
end

function ns:GuildFeatsShowChoices()
	local list = {}
	for _, id in ipairs(ns.GFEAT_SHOW_CHOICES) do list[#list + 1] = { value = id, label = L["GFEAT_SHOW_" .. id] } end
	return list
end

-- ---------------------------------------------------------------------------
-- Valeur d'un exploit (le meilleur passe devant) : brillante > palier >
-- sceau > espèce nouvelle (selon son rang), puis les étoiles
-- ---------------------------------------------------------------------------
function ns.GuildFeatScore(feat)
	if type(feat) ~= "table" then return 0 end
	local stars = tonumber(feat.stars) or 0
	local rank = CLASS_RANK[feat.class or ""] or 0
	if feat.kind == "s" then return 1000 + stars * 10 + rank end
	if feat.kind == "r" then return 800 + (tonumber(feat.id) or 0) / 1000 end
	if feat.kind == "z" then return 700 end
	if feat.kind == "n" then return 100 + rank * 10 + stars end
	return 0
end

-- ---------------------------------------------------------------------------
-- Envoi
-- ---------------------------------------------------------------------------
-- Un exploit à annoncer (feat : { kind, id, zone, stars, class }) : il
-- attend un peu que d'autres le rejoignent. Rend true s'il est retenu.
function ns:GuildFeatNote(feat)
	if type(feat) ~= "table" or not KINDS[feat.kind or ""] or not tonumber(feat.id) then return false end
	if not self:GuildFeatsSending() or not InGuild() then return false end
	feat.score = ns.GuildFeatScore(feat)
	local out = state.out
	if not out then
		state.out = { feat = feat, count = 1, first = Clock() }
	else
		out.count = out.count + 1
		if feat.score > out.feat.score then out.feat = feat end
	end
	return true
end

-- Le message d'un exploit
function ns:GuildFeatMessage(feat, more)
	local function N(v, lo, hi)
		v = math.floor(tonumber(v) or 0)
		return math.max(lo, math.min(hi, v))
	end
	local class = CLASS_RANK[feat.class or ""] and feat.class or "-"
	return { feat.kind, N(feat.id, 0, 9999999), N(feat.zone, 0, 9999999), N(feat.stars, 0, 3), class,
		N(more, 0, ns.GFEAT_MORE_MAX) }
end

-- Appelé par l'horloge : l'annonce part quand la série est finie, l'écart
-- respecté, hors combat et hors verrou de messagerie
function ns:GuildFeatsFlush(now)
	local out = state.out
	if not out then return false end
	now = now or Clock()
	if not self:GuildFeatsSending() or not InGuild() then
		state.out = nil
		return false
	end
	if now - out.first < ns.GFEAT_GATHER then return false end
	if state.lastSent and now >= state.lastSent and now - state.lastSent < ns.GFEAT_GAP then return false end
	if self.TrainerBlocked and self:TrainerBlocked() then return false end
	if not self.TrainerSend then return false end
	local parts = self:GuildFeatMessage(out.feat, out.count - 1)
	local queued = self:TrainerSend(ns.GFEAT_KIND, "GUILD", nil, unpack(parts))
	state.out = nil
	if queued then state.lastSent = now end
	return queued and true or false
end

-- Une capture réussie : brillante, ou espèce nouvelle notable.
-- before : { fresh, hadShiny } (relevé avant la capture)
function ns:GuildFeatsOnCapture(target, rolling, before)
	if type(target) ~= "table" or not tonumber(target.npcID) then return false end
	local shiny = target.shiny and true or false
	local stars = tonumber(rolling and rolling.starsBest)
		or (self.CaptureStars and tonumber(Call(self.CaptureStars, self, target.npcID, shiny))) or 1
	local feat = { id = tonumber(target.npcID), zone = tonumber(target.zoneID) or 0, stars = stars, class = target.class }
	if shiny then
		if before and before.hadShiny and not (rolling and rolling.starsBetter) then return false end
		feat.kind = "s"
	elseif before and before.fresh and NOTABLE[target.class or ""] then
		feat.kind = "n"
	else
		return false
	end
	return self:GuildFeatNote(feat)
end

-- La capture : on relève avant (espèce nouvelle ? brillante déjà là ?), on
-- annonce après. Posé en dernier (.toc) : les autres enveloppes ont tourné.
do
	local base = ns.CaptureResolve
	if base then
		function ns:CaptureResolve(rolling, ...)
			local target = type(rolling) == "table" and rolling.target or nil
			local before
			if type(target) == "table" and target.npcID and self.CaptureData then
				local okData, data = pcall(self.CaptureData, self)
				local creatures = okData and type(data) == "table" and data.creatures or {}
				before = { fresh = creatures[target.npcID] == nil,
					hadShiny = self.CaptureHas and Call(self.CaptureHas, self, target.npcID, true) and true or false }
			end
			local result = base(self, rolling, ...)
			if before and rolling.success then
				local ok, err = pcall(self.GuildFeatsOnCapture, self, target, rolling, before)
				if not ok and self.RecordError then self:RecordError("guildfeats:capture", err) end
			end
			return result
		end
	end
end

-- Sceau de zone (MenagerieCollection.lua) : pas pendant le rattrapage silencieux
do
	local base = ns.MenagerieSealCheck
	if base then
		function ns:MenagerieSealCheck(zoneID, opts, ...)
			local sealed = base(self, zoneID, opts, ...)
			if sealed and not (type(opts) == "table" and opts.quiet) then
				pcall(self.GuildFeatNote, self, { kind = "z", id = tonumber(zoneID), zone = 0, stars = 0 })
			end
			return sealed
		end
	end
end

-- Palier d'espèces (et titre) : le plus haut franchi
do
	local base = ns.MenagerieRankCheck
	if base then
		function ns:MenagerieRankCheck(opts, ...)
			local gained = base(self, opts, ...)
			if type(gained) == "table" and #gained > 0 and not (type(opts) == "table" and opts.quiet) then
				local top
				for _, rank in ipairs(gained) do
					if type(rank) == "table" and tonumber(rank.count) and (not top or rank.count > top) then top = rank.count end
				end
				if top then pcall(self.GuildFeatNote, self, { kind = "r", id = top, zone = 0, stars = 0 }) end
			end
			return gained
		end
	end
end

-- ---------------------------------------------------------------------------
-- Réception : lecture stricte, puis tout refait depuis nos propres données
-- ---------------------------------------------------------------------------
local function Digits(value, maxLen)
	if type(value) ~= "string" or #value < 1 or #value > maxLen or not value:find("^%d+$") then return nil end
	return tonumber(value)
end

-- texte -> exploit { kind, id, zone, stars, class, more, proto }, ou nil
function ns:GuildFeatParse(text)
	if type(text) ~= "string" or #text > (ns.TRAINER_MAX_MSG or 255) then return nil end
	local fields = {}
	for field in (text .. "~"):gmatch("([^~]*)~") do
		fields[#fields + 1] = field
		if #fields > 16 then break end
	end
	if fields[1] ~= ns.GFEAT_KIND then return nil end
	local proto = Digits(fields[2], 3)
	if not proto or proto < 1 then return nil end
	local kind = fields[3]
	if not KINDS[kind or ""] then return nil end
	local id, zone, stars, more = Digits(fields[4], 7), Digits(fields[5], 7), Digits(fields[6], 1), Digits(fields[8], 3)
	local class = fields[7]
	if not (id and zone and stars and more) or id < 1 or stars > 3 then return nil end
	if class ~= "-" and not CLASS_RANK[class or ""] then return nil end
	return { proto = proto, kind = kind, id = id, zone = zone, stars = stars, class = class ~= "-" and class or nil,
		more = math.min(more, ns.GFEAT_MORE_MAX) }
end

-- Nos données sur une créature : tables livrées de la zone, carnet, ménagerie
local function CreatureInfo(self, npcID, zoneID)
	local name, class
	local all = rawget(ns, "ZONE_CREATURES")
	if zoneID and zoneID > 0 and ns.ZonePeek then
		local zone = ns.ZonePeek(all, zoneID)
		local entry = type(zone) == "table" and zone[npcID]
		if type(entry) == "table" then
			name = self.BestiaryStaticName and self:BestiaryStaticName(entry) or entry.fr or entry.en
			class = RANK_CLASS[tonumber(entry.rank) or 0] or "normal"
		end
		if not name and self.BestiaryZone then
			local learned = Call(self.BestiaryZone, self, zoneID)
			local item = type(learned) == "table" and learned[npcID]
			if type(item) == "table" and type(item.name) == "string" then name, class = item.name, item.class end
		end
	end
	if not name and self.CaptureData then
		local entry = self:CaptureData().creatures[npcID]
		if type(entry) == "table" and type(entry.name) == "string" then name, class = entry.name, entry.class end
	end
	if type(name) ~= "string" or name == "" then return nil end
	return name, CLASS_RANK[class or ""] and class or nil
end

local function SafeName(text, max)
	if type(text) ~= "string" then return nil end
	-- (contrôles ASCII seulement : %c dépend de la locale et peut toucher aux
	-- octets d'une lettre accentuée, « È » = C3 88)
	text = text:gsub("[%z\1-\31\127]", "")
	if ns.TrainerUtf8Cut then text = ns.TrainerUtf8Cut(text, max or 48) end
	text = text:gsub("|", "||")
	return text ~= "" and text or nil
end

local function StaticZone(zoneID)
	if not zoneID or zoneID < 1 or not ns.ZonePeek then return nil end
	local zone = ns.ZonePeek(rawget(ns, "ZONE_CREATURES"), zoneID)
	return type(zone) == "table" and zone or nil
end

-- exploit + expéditeur -> { line, sub, class, shiny } à afficher, ou nil si
-- un identifiant nous est inconnu
function ns:GuildFeatDescribe(feat, sender)
	if type(feat) ~= "table" then return nil end
	local who = SafeName(self.TrainerShortName and self:TrainerShortName(sender) or sender, 64)
	if not who then return nil end
	local info = { kind = feat.kind, stars = feat.stars, more = feat.more }
	if feat.kind == "s" or feat.kind == "n" then
		local name, class = CreatureInfo(self, feat.id, feat.zone)
		if not name then return nil end
		class = class or feat.class or "normal"
		if feat.kind == "n" then
			if not NOTABLE[class] then return nil end
			info.line = self:F("GFEAT_NEW_" .. class, who)
		else
			info.line = self:F("GFEAT_SHINY", who)
			info.shiny = true
		end
		info.class, info.name = class, SafeName(name, 64)
		info.stars = math.max(1, feat.stars)
	elseif feat.kind == "z" then
		if not StaticZone(feat.id) then return nil end
		local map = self.MapInfo and self:MapInfo(feat.id)
		local zoneName = type(map) == "table" and SafeName(Plain(map.name), 64)
		if not zoneName then return nil end
		info.line = self:F("GFEAT_SEAL", who)
		info.sub = self:F("GFEAT_SEAL_SUB", zoneName)
		info.stars = nil
	elseif feat.kind == "r" then
		local found
		for _, rank in ipairs(ns.TRAINER_RANKS or {}) do if rank.count == feat.id then found = rank end end
		if not found then return nil end
		local title = L["TRAINER_" .. found.key]
		if type(title) ~= "string" or title == "TRAINER_" .. found.key then title = found.key end
		info.line = self:F("GFEAT_RANK", who, found.count)
		info.sub = self:F("GFEAT_RANK_SUB", title)
		info.stars = nil
	else
		return nil
	end
	return info
end

-- Couleur de rareté (CaptureStage.lua), en code |c
local function RarityHex(class, shiny)
	local color
	if shiny then color = Theme and (Theme.GOLD_LIGHT or Theme.GOLD) end
	if not color then
		local rarity = ns.CAPTURE_RARITY and ns.CAPTURE_RARITY[class or "normal"]
		color = rarity and rarity.color or { 0.95, 0.95, 0.95 }
	end
	return string.format("|cff%02x%02x%02x", math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5),
		math.floor(color[3] * 255 + 0.5))
end

-- La sous-ligne : la créature en couleur de rareté et ses étoiles, ou le texte
function ns:GuildFeatSubLine(info, withStars)
	if info.sub then return info.sub end
	local text = RarityHex(info.class, info.shiny) .. tostring(info.name or "?") .. "|r"
	if withStars ~= false and info.stars and self.CaptureStarsText then
		local ok, stars = pcall(self.CaptureStarsText, self, info.stars, 12)
		if ok and type(stars) == "string" and stars ~= "" then text = text .. "  " .. stars end
	end
	return text
end

function ns:GuildFeatMoreText(more)
	more = tonumber(more) or 0
	if more <= 0 then return nil end
	if more == 1 then return L.GFEAT_MORE_1 end
	return self:F("GFEAT_MORE", more)
end

-- Un exploit reçu (canal et expéditeur du client). Rend true s'il est retenu.
function ns:GuildFeatsOnMessage(text, channel, sender)
	text, channel, sender = Plain(text), Plain(channel), Plain(sender)
	if channel ~= "GUILD" or type(text) ~= "string" or type(sender) ~= "string" then return false end
	local full = self.TrainerFullName and self:TrainerFullName(sender)
	local key = full and self:TrainerKey(full)
	if not key or key == self:TrainerKey(self:TrainerMe()) then return false end
	local mode = self:GuildFeatsShowMode()
	if mode == "off" then return false end
	local feat = self:GuildFeatParse(text)
	if not feat then return false end
	if mode == "shiny" and feat.kind ~= "s" then return false end
	local info = self:GuildFeatDescribe(feat, full)
	if not info then return false end
	if self:DB().guildFeatsChat == true then
		self:Print(self:F("GFEAT_CHAT", info.line, self:GuildFeatSubLine(info, false)))
	end
	return self:GuildFeatsEnqueue({ key = key, sender = full, feat = feat, info = info,
		score = ns.GuildFeatScore(feat), at = Clock() })
end

-- Sur le préfixe de la fiche : le message passe d'abord par TrainerCard.lua
-- (expéditeur noté comme détenteur, plafond par joueur, soi ignoré)
do
	local base = ns.TrainerOnAddonMessage
	if base then
		function ns:TrainerOnAddonMessage(prefix, text, channel, sender, ...)
			local handled = base(self, prefix, text, channel, sender, ...)
			if handled and type(Plain(text)) == "string" and Plain(text):sub(1, 2) == ns.GFEAT_KIND .. "~" then
				local ok, err = pcall(self.GuildFeatsOnMessage, self, text, channel, sender)
				if not ok and self.RecordError then self:RecordError("guildfeats:receive", err) end
			end
			return handled
		end
	end
end

-- ---------------------------------------------------------------------------
-- File des bandeaux : 3 au plus, un par membre (le meilleur gardé)
-- ---------------------------------------------------------------------------
function ns:GuildFeatsEnqueue(item)
	local queue = state.toasts
	for index, other in ipairs(queue) do
		if other.key == item.key then
			if item.score >= other.score then queue[index] = item end
			return item.score >= other.score
		end
	end
	if #queue < ns.GFEAT_TOAST_QUEUE then
		queue[#queue + 1] = item
		return true
	end
	local worst
	for index, other in ipairs(queue) do
		if not worst or other.score < queue[worst].score then worst = index end
	end
	if item.score > queue[worst].score then
		queue[worst] = item
		return true
	end
	return false
end

function ns:GuildFeatsQueue() return state.toasts end
function ns:GuildFeatsShowing() return state.showing end

local function PlayFeatSound(self, shiny)
	local now = Clock()
	if state.lastSound and now >= state.lastSound and now - state.lastSound < ns.GFEAT_SOUND_GAP then return false end
	if self:DB().companionCaptureSound == false then return false end
	if self.CaptureMuted and Call(self.CaptureMuted, self) then return false end
	local play = G("PlaySound")
	if type(play) ~= "function" then return false end
	state.lastSound = now
	pcall(play, shiny and ns.GFEAT_SOUNDS.shiny or ns.GFEAT_SOUNDS.ok)
	return true
end

-- Le bandeau : liseré doré, glyphe du filet, « GUILDE », la ligne, la créature
function ns:EnsureGuildFeatToast()
	if self.guildFeatToast then return self.guildFeatToast end
	-- style de l'interface (2.5.0, AzerothStyle.lua)
	local cached = self.StyleCached and self:StyleCached("guildFeatToast")
	if cached then self.guildFeatToast = cached; return cached end
	local art = ns.CAPTURE_ART
	-- Azeroth : variante « guilde » du bandeau, cadre rond à volutes ; la
	-- sous-ligne (créature, étoiles) sous le nom, l'aide en infobulle seulement
	local frame = self.AzerothOn and self:AzerothOn()
		and self:AzerothCreateBanner({ strata = "HIGH", guild = true, round = true, name = "QuestCompanionGuildFeatAzeroth" })
	if frame then
		frame.ownGlyph = art and art.icon and true or false
		frame.icon:SetTexture(frame.ownGlyph and art.icon or Theme.LOGO_SMALL)
		if frame.ownGlyph then frame.icon:SetVertexColor(Theme.GOLD_LIGHT[1], Theme.GOLD_LIGHT[2], Theme.GOLD_LIGHT[3], 1) end
		frame.info = frame.stars
		frame.hint = frame.banner:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		frame.hint:Hide()
	else
		frame = self:GuildFeatToastSobre(art)
	end
	if not frame then return nil end
	-- un bouton invisible par-dessus : clic (la fiche) et glisser
	local ok, button = pcall(CreateFrame, "Button", nil, frame)
	if ok and button then
		button:SetAllPoints(frame)
		if button.RegisterForClicks then button:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
		if button.RegisterForDrag then button:RegisterForDrag("LeftButton") end
		button:SetScript("OnClick", function(_, mouse) ns:GuildFeatsClick(mouse) end)
		button:SetScript("OnDragStart", function() if frame.StartMoving then pcall(frame.StartMoving, frame) end end)
		button:SetScript("OnDragStop", function()
			local stop = frame.GetScript and frame:GetScript("OnDragStop")
			if type(stop) == "function" then pcall(stop, frame) elseif frame.StopMovingOrSizing then pcall(frame.StopMovingOrSizing, frame) end
		end)
		frame.button = button
	end
	if self.RestorePoint then self:RestorePoint(frame, "guildFeatToastPoint", { point = "TOP", x = 0, y = -150 }) end
	frame:Hide()
	self.guildFeatToast = frame
	return frame
end

-- Le bandeau Sobre (le style d'avant 2.5.0) : liseré doré, glyphe, quatre lignes
function ns:GuildFeatToastSobre(art)
	if not (Theme and Theme.CreateToast) then return nil end
	local frame = Theme.CreateToast(UIParent, TOAST_W, TOAST_H, { strata = "HIGH", accent = Theme.GOLD,
		name = "QuestCompanionGuildFeat" })
	if not frame then return nil end
	frame.uiStyle = "sobre"
	local left = frame.contentLeft or 14
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.ownGlyph = art and art.icon and true or false
	frame.icon:SetTexture(frame.ownGlyph and art.icon or "Interface\\AddOns\\QuestCompanion\\Textures\\logo_petit")
	if frame.ownGlyph then frame.icon:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1) end
	frame.icon:SetSize(TOAST_ICON, TOAST_ICON)
	frame.icon:SetPoint("LEFT", frame, "LEFT", left, 0)
	local textLeft = left + TOAST_ICON + 10
	local textW = TOAST_W - textLeft - 12
	local function Line(font, color, y)
		local text = Theme.Text(frame, font, color)
		text:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, y)
		text:SetWidth(textW)
		text:SetJustifyH("LEFT")
		if text.SetWordWrap then text:SetWordWrap(false) end
		return text
	end
	frame.title = Line(Theme.F_CAPS, Theme.MUTED_LIGHT, -9)
	frame.text = Line(Theme.F_TITLE, Theme.PARCHMENT, -23)
	frame.info = Line(Theme.F_SMALL, Theme.PARCHMENT, -43)
	frame.hint = Line(Theme.F_SMALL, Theme.MUTED, -60)
	return frame
end

-- Clic gauche : la fiche de dresseur de l'expéditeur (demandée au besoin) ;
-- clic droit : le bandeau se ferme
function ns:GuildFeatsClick(mouse)
	local item = state.showing
	self:GuildFeatsHideToast()
	if mouse == "RightButton" or not item then return false end
	if self.TrainerOpen then self:TrainerOpen(item.sender) end
	return true
end

function ns:GuildFeatsHideToast()
	state.showing, state.hideAt = nil, nil
	if self.guildFeatToast then self.guildFeatToast:Hide() end
end

function ns:GuildFeatsShowToast(item)
	local frame = self:EnsureGuildFeatToast()
	if not frame then return nil end
	local info = item.info
	frame.title:SetText(Theme.Upper and Theme.Upper(L.GFEAT_TITLE) or L.GFEAT_TITLE)
	frame.text:SetText(info.line)
	frame.info:SetText(self:GuildFeatSubLine(info))
	local more = self:GuildFeatMoreText(info.more)
	frame.hint:SetText(more and (more .. "  ·  " .. L.GFEAT_HINT) or L.GFEAT_HINT)
	local accent = info.shiny and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.GOLD
	if frame.SetAccent then frame:SetAccent(accent) end
	if frame.ownGlyph and not frame.azeroth then frame.icon:SetVertexColor(accent[1], accent[2], accent[3], 1) end
	state.showing, state.hideAt = item, Clock() + ns.GFEAT_TOAST_SECONDS
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame, 0.2) end
	if self.StyleShown then self:StyleShown(frame, { shiny = info.shiny, play = true }) end
	PlayFeatSound(self, info.shiny)
	return frame
end

-- Horloge des bandeaux : fin d'affichage, puis le meilleur en attente (pas en
-- combat ; les périmés sortent)
function ns:GuildFeatsToastTick(now)
	now = now or Clock()
	if state.showing then
		if state.hideAt and now < state.hideAt then return false end
		self:GuildFeatsHideToast()
	end
	local queue, kept = state.toasts, {}
	for _, item in ipairs(queue) do
		if now >= item.at and now - item.at <= ns.GFEAT_TOAST_STALE then kept[#kept + 1] = item end
	end
	state.toasts = kept
	if #kept == 0 or InCombat() then return false end
	local best = 1
	for index, item in ipairs(kept) do
		if item.score > kept[best].score or (item.score == kept[best].score and item.at < kept[best].at) then best = index end
	end
	local item = table.remove(kept, best)
	return self:GuildFeatsShowToast(item) ~= nil
end

function ns:GuildFeatsTick(elapsed)
	local now = Clock()
	self:GuildFeatsFlush(now)
	self:GuildFeatsToastTick(now)
end

-- ---------------------------------------------------------------------------
-- Découverte paresseuse au survol d'un joueur (infobulle)
-- ---------------------------------------------------------------------------
function ns:GuildFeatsTooltipProbe(tooltip)
	if type(tooltip) ~= "table" or type(tooltip.GetUnit) ~= "function" or not self.TrainerOnTarget then return false end
	local now = Clock()
	if state.lastProbe and now >= state.lastProbe and now - state.lastProbe < ns.GFEAT_PROBE_GAP then return false end
	local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
	unit = ok and Plain(unit) or nil
	local name = type(unit) == "string" and self:TrainerUnitName(unit)
	if not name then return false end
	-- vu comme détenteur il y a peu : rien à apprendre
	local seen = self.TrainerHolders and self:TrainerHolders()[self:TrainerKey(name) or ""]
	if type(seen) == "number" and Epoch() - seen < ns.GFEAT_PROBE_FRESH then return false end
	if not self:TrainerOnTarget(unit) then return false end
	state.lastProbe = now
	return true
end
if type(ns.UNIT_TOOLTIP_LINES) == "table" then
	table.insert(ns.UNIT_TOOLTIP_LINES, function(self, tooltip) return self:GuildFeatsTooltipProbe(tooltip) end)
end

-- L'horloge : celle de la fiche de dresseur (ns:TrainerPump, cinq fois par
-- seconde) ; l'annonce mise en file part dans le même passage
do
	local base = ns.TrainerPump
	if base then
		function ns:TrainerPump(elapsed, ...)
			local done, err = pcall(self.GuildFeatsTick, self, elapsed)
			if not done and self.RecordError then self:RecordError("guildfeats:tick", err) end
			return base(self, elapsed, ...)
		end
	end
end

if ns.Mark then ns.Mark("GuildFeats") end
