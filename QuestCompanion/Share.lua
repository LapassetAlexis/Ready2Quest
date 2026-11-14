-- Share.lua -- « Partager » : un beau moment dans le chat (QuestCompanion 3.1.0)
--
-- But : le bouche-à-oreille. Un joueur sans l'addon voit passer « [Quest
-- Companion] Dyokrion a capturé un Raptor brillant (3 étoiles, Grand) ! ».
--   * Où : un petit bouton (l'icône de chat du client, infobulle) sur les
--     bandeaux du haut quand le moment vaut d'être raconté : « Capturé ! »
--     (brillante, 3 étoiles, élite / rare / boss, espèce nouvelle ; en
--     Azeroth, la scène de capture qui montre elle-même ce verdict), « Haut
--     fait obtenu » (seul ou groupé), sceau de zone, titre de dresseur. Plus
--     tard : la fiche d'un spécimen de la Réserve (même bouton, dans le coin
--     du modèle) et le clic droit sur un haut fait obtenu (page Hauts faits).
--     Un bouton par bandeau, créé une fois sur le cadre réutilisé
--     (Banners.lua : la file ne change pas).
--   * Quoi : UNIQUEMENT au clic du joueur (règle de Blizzard :
--     SendChatMessage veut un événement matériel ; rien d'automatique). Le
--     clic ouvre un petit menu des canaux disponibles : Guilde (en guilde),
--     Raid / Groupe (groupé), Dire, et « Copier » (le texte dans la zone de
--     saisie du chat, à relire avant Entrée : le choix sûr pour les canaux
--     publics, jamais d'envoi direct vers Général, Commerce ou la recherche
--     de groupe). Hors instance, le jeu réserve « Dire » au joueur : le texte
--     l'attend alors dans la saisie, en mode Dire.
--   * Le texte : une ligne, dans la langue du client, nom de la créature (pas
--     un identifiant), nom et points du haut fait ; jamais d'étoile ★ (la
--     police du jeu ne l'a pas : « 3 étoiles ») ; aucun code |c…, |T…, |H…
--     hors un vrai lien d'objet ; 255 caractères au plus.
--   * Anti-spam : un partage toutes les 10 s, et pas deux fois la même chose
--     au même canal en 60 s (une ligne de chat le dit).
--   * Réglage « Bouton Partager sur les bandeaux » (page Carnet de voyage,
--     actif par défaut) : il ne cache que le bouton des bandeaux.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.SHARE_PREFIX = "[Quest Companion]"
ns.SHARE_MAX = 255           -- octets d'une ligne de chat
ns.SHARE_GAP = 10            -- s entre deux partages
ns.SHARE_REPEAT = 60         -- s avant de repartager la même chose au même canal
-- 3.1.0 bêta 3 (retour en jeu : « l'infobulle disparaît trop vite, trop
-- petite ») : bouton plus grand, bandeau en pause sous la souris et tant que
-- le menu est ouvert, quelques secondes de plus quand il porte le bouton
ns.SHARE_RESUME = 3          -- s au moins quand la souris quitte le bandeau (ou le menu se ferme)
ns.SHARE_EXTRA = 3           -- s de plus pour un bandeau qui porte le bouton
-- l'icône de chat du client, par référence (jamais d'image à nous)
ns.SHARE_ICON = { atlases = { "communities-icon-chat" }, fallback = "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up" }
ns.SHARE_BUTTON = { size = Theme.BUTTON_SIZES and Theme.BUTTON_SIZES.sm or 24, icon = 18, labelGap = 4, labelPad = 8,
	azeroth = { x = -36, y = 6 }, stage = { x = -8, y = -12 },
	reserve = { x = -6, y = -6 }, sobreGap = 10, featGap = 36,
	-- 3.1.0 : bandeau forgé : en bas à droite (les points vont au médaillon)
	forge = { x = -10, y = 8 } }
-- 3.1.0 : libellé « Partager » sur la petite plaque forgée (neutre ; bronze
-- au survol) : l'encre des libellés (tests/modules/forge_bandeaux.lua, ≥ 4,5:1)
ns.SHARE_FORGE_INK = Theme.LABEL
ns.SHARE_MENU = { w = 160, row = 22, pad = 6, title = 18, rows = 5 }
-- les rangs qui valent un partage (le Capturé ! d'un monstre normal : non)
ns.SHARE_NAMED = { elite = true, rare = true, rareelite = true, worldboss = true }
-- canaux d'envoi direct, dans l'ordre du menu ; « COPY » ferme la liste
ns.SHARE_CHANNELS = { "GUILD", "RAID", "PARTY", "INSTANCE_CHAT", "SAY", "COPY" }

local FR = {
	SHARE_TIP            = "Partager dans le chat",
	SHARE_LABEL          = "Partager",
	SHARE_TIP_DETAIL     = "Choisis le canal : rien ne part sans ton clic.",
	SHARE_MENU_TITLE     = "Partager dans",
	SHARE_CH_GUILD       = "Guilde",
	SHARE_CH_RAID        = "Raid",
	SHARE_CH_PARTY       = "Groupe",
	SHARE_CH_INSTANCE_CHAT = "Groupe",
	SHARE_CH_SAY         = "Dire",
	SHARE_CH_COPY        = "Copier",
	SHARE_COPY_TIP       = "Le texte va dans ta zone de saisie du chat : relis-le, choisis ton canal, puis Entrée.",
	SHARE_SAY_OUTSIDE    = "Hors instance, le jeu te laisse envoyer « Dire » toi-même : le texte t'attend dans le chat, appuie sur Entrée.",
	SHARE_COPY_FALLBACK  = "À copier : %s",
	SHARE_WAIT_ONE       = "Doucement : attends encore %d seconde avant de partager à nouveau.",
	SHARE_WAIT_MANY      = "Doucement : attends encore %d secondes avant de partager à nouveau.",
	SHARE_AGAIN          = "Déjà partagé dans ce canal il y a moins d'une minute.",
	SHARE_ROW_HINT       = "Clic droit : partager dans le chat",
	OPT_SHARE_BANNER     = "Bouton Partager sur les bandeaux",
	OPT_SHARE_BANNER_DESC = "Un petit bouton sur les bandeaux des beaux moments (brillante, 3 étoiles, élite, espèce nouvelle, haut fait, sceau, titre) pour les partager dans le chat. La Réserve et les Hauts faits gardent leur entrée.",
	-- le texte partagé (une ligne, langue du client)
	SHARE_SOMEONE        = "Un dresseur",
	SHARE_MSG_CAPTURE    = "%s a capturé %s !",
	SHARE_A              = "un %s",
	SHARE_AN             = "un %s",
	SHARE_SHINY          = "un %s brillant",
	SHARE_DETAILS        = "%s (%s)",
	SHARE_SEP            = ", ",
	SHARE_STARS_ONE      = "%d étoile",
	SHARE_STARS_MANY     = "%d étoiles",
	SHARE_RANK_elite     = "élite",
	SHARE_RANK_rare      = "rare",
	SHARE_RANK_rareelite = "élite rare",
	SHARE_RANK_worldboss = "boss",
	SHARE_NEW            = "nouvelle espèce",
	SHARE_MSG_FEAT       = "%s a obtenu le haut fait « %s » (%s) !",
	SHARE_POINTS_ONE     = "%d point",
	SHARE_POINTS_MANY    = "%d points",
	SHARE_MSG_FEATS      = "%s a obtenu %d hauts faits (%s) !",
	SHARE_MSG_FEATS_NAMED = "%s a obtenu %d hauts faits (%s) : %s !",
	SHARE_FEAT_NAME      = "« %s »",
	SHARE_MORE           = "%s…",
	SHARE_MSG_SEAL       = "%s a scellé la zone %s !",
	SHARE_MSG_TITLE      = "%s porte maintenant le titre « %s » !",
	-- annonce automatique (brillante, 3 étoiles) : un lot de « Tout capturer »
	SHARE_MSG_BATCH      = "%s a capturé %d spécimens : %s !",
	SHARE_BATCH_SHINY    = "%s brillant",
	OPT_ANNOUNCE_GROUP   = "Annoncer au groupe mes brillantes et 3 étoiles",
	OPT_ANNOUNCE_GROUP_DESC = "Une ligne dans le chat du groupe (ou du raid) quand tu captures une brillante ou un spécimen 3 étoiles. Seul : rien. Jamais en combat (elle part à la fin du combat), au plus une toutes les 30 secondes.",
	OPT_ANNOUNCE_GUILD   = "Annoncer aussi à la guilde",
	OPT_ANNOUNCE_GUILD_DESC = "La même ligne dans le chat de ta guilde.",
}
local EN = {
	SHARE_TIP            = "Share in chat",
	SHARE_LABEL          = "Share",
	SHARE_TIP_DETAIL     = "Pick the channel: nothing is sent without your click.",
	SHARE_MENU_TITLE     = "Share in",
	SHARE_CH_GUILD       = "Guild",
	SHARE_CH_RAID        = "Raid",
	SHARE_CH_PARTY       = "Party",
	SHARE_CH_INSTANCE_CHAT = "Group",
	SHARE_CH_SAY         = "Say",
	SHARE_CH_COPY        = "Copy",
	SHARE_COPY_TIP       = "The text goes to your chat input box: read it, pick your channel, then press Enter.",
	SHARE_SAY_OUTSIDE    = "Outside instances, the game lets you send \"Say\" yourself: the text waits in your chat box, press Enter.",
	SHARE_COPY_FALLBACK  = "To copy: %s",
	SHARE_WAIT_ONE       = "Easy: wait %d more second before sharing again.",
	SHARE_WAIT_MANY      = "Easy: wait %d more seconds before sharing again.",
	SHARE_AGAIN          = "Already shared in this channel less than a minute ago.",
	SHARE_ROW_HINT       = "Right-click: share in chat",
	OPT_SHARE_BANNER     = "Share button on banners",
	OPT_SHARE_BANNER_DESC = "A small button on the banners of great moments (shiny, 3 stars, elite, new species, achievement, seal, title) to share them in chat. The Reserve and Achievements keep their entry.",
	SHARE_SOMEONE        = "A trainer",
	SHARE_MSG_CAPTURE    = "%s captured %s!",
	SHARE_A              = "a %s",
	SHARE_AN             = "an %s",
	SHARE_SHINY          = "a shiny %s",
	SHARE_DETAILS        = "%s (%s)",
	SHARE_SEP            = ", ",
	SHARE_STARS_ONE      = "%d star",
	SHARE_STARS_MANY     = "%d stars",
	SHARE_RANK_elite     = "elite",
	SHARE_RANK_rare      = "rare",
	SHARE_RANK_rareelite = "rare elite",
	SHARE_RANK_worldboss = "boss",
	SHARE_NEW            = "new species",
	SHARE_MSG_FEAT       = "%s earned the achievement \"%s\" (%s)!",
	SHARE_POINTS_ONE     = "%d point",
	SHARE_POINTS_MANY    = "%d points",
	SHARE_MSG_FEATS      = "%s earned %d achievements (%s)!",
	SHARE_MSG_FEATS_NAMED = "%s earned %d achievements (%s): %s!",
	SHARE_FEAT_NAME      = "\"%s\"",
	SHARE_MORE           = "%s…",
	SHARE_MSG_SEAL       = "%s sealed the zone %s!",
	SHARE_MSG_TITLE      = "%s now bears the title \"%s\"!",
	SHARE_MSG_BATCH      = "%s captured %d specimens: %s!",
	SHARE_BATCH_SHINY    = "shiny %s",
	OPT_ANNOUNCE_GROUP   = "Announce my shinies and 3-star captures to the group",
	OPT_ANNOUNCE_GROUP_DESC = "A line in your party (or raid) chat when you capture a shiny or a 3-star specimen. Solo: nothing. Never in combat (it goes out when combat ends), at most one every 30 seconds.",
	OPT_ANNOUNCE_GUILD   = "Also announce to the guild",
	OPT_ANNOUNCE_GUILD_DESC = "The same line in your guild chat.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.SHARE_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ shareBanner = true, announceGroup = true, announceGuild = false })

-- 3.1.0 : le menu en Azeroth, sur l'aplat du bois sombre (survol compris) :
-- rôles mesurés (tests/modules/azeroth_style.lua recalcule chaque ratio)
if ns.AZEROTH_CONTRAST and ns.AZEROTH_INK and ns.AZEROTH_INK.woodBg and Theme.Luminance and Theme.Over then
	local worst = Theme.Luminance(Theme.Over(ns.AZEROTH_INK.woodBg, Theme.WHITE, Theme.HOVER_ALPHA))
	ns.AZEROTH_CONTRAST["share.title"] = { "goldHead", worst, 4.5, 10 }
	ns.AZEROTH_CONTRAST["share.entry"] = { "lightSoft", worst, 4.5, 12 }
	-- libellé « Partager » du bouton : sur sa plaque opaque (NAV), survol compris
	ns.AZEROTH_CONTRAST["share.label"] = { "lightSoft", Theme.Luminance(Theme.Over(Theme.NAV, Theme.WHITE, Theme.HOVER_ALPHA)), 4.5, 11 }
end

local function G(name) return rawget(_G, name) end
local function Call(name, ...)
	local fn = G(name)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end
local function Now() return (ns.Now and ns.Now()) or 0 end

-- ---------------------------------------------------------------------------
-- Le texte
-- ---------------------------------------------------------------------------
-- Textes d'une langue donnée (tests : fr / en) ; sinon ceux du client
local function S(lang, key)
	local all = lang and ns.SHARE_STRINGS and ns.SHARE_STRINGS[lang]
	local value = all and all[key]
	if value == nil and lang then
		local traits = ns.SPECIMEN_TRAIT_STRINGS and ns.SPECIMEN_TRAIT_STRINGS[lang]
		value = traits and traits[key]
	end
	if value == nil then value = L[key] end
	return value
end
local function French(lang)
	if lang then return lang == "fr" end
	return ns.STRINGS_FRENCH and true or false
end
local function Fmt(lang, key, ...)
	local fmt = S(lang, key)
	local ok, out = pcall(string.format, tostring(fmt), ...)
	return ok and out or tostring(fmt)
end
local function Plural(lang, key, n)
	n = tonumber(n) or 0
	local one
	if French(lang) then one = n <= 1 and n >= -1 else one = n == 1 end
	return Fmt(lang, key .. (one and "_ONE" or "_MANY"), n)
end

-- Rien qui casse le chat : codes d'échappement retirés (couleur, texture,
-- atlas, lien autre qu'un objet), barres isolées, caractères de contrôle ;
-- un vrai lien d'objet (|cff…|Hitem:…|h[…]|h|r) est gardé tel quel.
local ITEM_LINK = "|c%x%x%x%x%x%x%x%x|Hitem:[^|]+|h%[[^%]|]+%]|h|r"
function ns.ShareClean(text)
	-- (ni %c ni %s : selon la locale C, ils mordent dans l'UTF-8, « à » finit par 0xA0)
	text = tostring(text or ""):gsub("[%z\1-\31\127]", " ")
	local links = {}
	text = text:gsub(ITEM_LINK, function(link)
		links[#links + 1] = link
		return "\1" .. #links .. "\1"
	end)
	text = text:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "")
		:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " ")
		:gsub("|", "")
	text = text:gsub("\1(%d+)\1", function(index) return links[tonumber(index)] or "" end)
	return (text:gsub("  +", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- Coupe à `max` octets sans casser un caractère UTF-8 ; « ... » au bout
function ns.ShareCut(text, max)
	max = max or ns.SHARE_MAX
	if #text <= max then return text end
	local cut = max - 3
	while cut > 0 do
		local byte = text:byte(cut + 1)
		if not byte or byte < 128 or byte >= 192 then break end
		cut = cut - 1
	end
	return text:sub(1, cut) .. "..."
end

local function Player()
	local name = ns.Plain and ns.Plain(Call("UnitName", "player")) or Call("UnitName", "player")
	if type(name) ~= "string" or name == "" then return nil end
	return name
end

local function Vowel(text) return tostring(text or ""):find("^[AEIOUaeiou]") ~= nil end

local function CaptureBody(lang, item, who)
	local name = ns.ShareClean(item.name)
	local phrase
	if item.shiny then phrase = Fmt(lang, "SHARE_SHINY", name)
	else phrase = Fmt(lang, Vowel(name) and "SHARE_AN" or "SHARE_A", name) end
	local details = {}
	local stars = tonumber(item.stars)
	if stars and stars > 0 then details[#details + 1] = Plural(lang, "SHARE_STARS", stars) end
	if item.size and item.size ~= "normal" and S(lang, "SPEC_SIZE_" .. item.size) ~= "SPEC_SIZE_" .. item.size then
		details[#details + 1] = S(lang, "SPEC_SIZE_" .. item.size)
	end
	if item.class and ns.SHARE_NAMED[item.class] then details[#details + 1] = S(lang, "SHARE_RANK_" .. item.class) end
	if item.fresh then details[#details + 1] = S(lang, "SHARE_NEW") end
	if #details > 0 then phrase = Fmt(lang, "SHARE_DETAILS", phrase, table.concat(details, S(lang, "SHARE_SEP"))) end
	return Fmt(lang, "SHARE_MSG_CAPTURE", who, phrase)
end

-- Hauts faits groupés : les noms tant que la ligne tient, puis « … »
local function FeatsBody(lang, item, who, room)
	local count, points = tonumber(item.count) or 0, Plural(lang, "SHARE_POINTS", item.points)
	local names = type(item.names) == "table" and item.names or {}
	local plain = Fmt(lang, "SHARE_MSG_FEATS", who, count, points)
	if #names == 0 then return plain end
	local list = {}
	local best = plain
	for index, name in ipairs(names) do
		list[index] = Fmt(lang, "SHARE_FEAT_NAME", ns.ShareClean(name))
		local joined = table.concat(list, S(lang, "SHARE_SEP"))
		if index < #names then joined = Fmt(lang, "SHARE_MORE", joined) end
		local line = Fmt(lang, "SHARE_MSG_FEATS_NAMED", who, count, points, joined)
		if #line > room then break end
		best = line
	end
	return best
end

-- La ligne à partager. item : { kind = "capture" | "feat" | "feats" | "seal"
-- | "title", name, … } ; `lang` (tests) : "fr" / "en", sinon le client.
function ns:ShareText(item, lang)
	if type(item) ~= "table" then return nil end
	local who = ns.ShareClean(item.who or Player() or S(lang, "SHARE_SOMEONE"))
	local prefix = ns.SHARE_PREFIX .. " "
	local body
	if item.kind == "capture" then
		body = CaptureBody(lang, item, who)
	elseif item.kind == "feat" then
		body = Fmt(lang, "SHARE_MSG_FEAT", who, ns.ShareClean(item.name), Plural(lang, "SHARE_POINTS", item.points))
	elseif item.kind == "feats" then
		body = FeatsBody(lang, item, who, ns.SHARE_MAX - #prefix)
	elseif item.kind == "seal" then
		body = Fmt(lang, "SHARE_MSG_SEAL", who, ns.ShareClean(item.name))
	elseif item.kind == "title" then
		body = Fmt(lang, "SHARE_MSG_TITLE", who, ns.ShareClean(item.name))
	else
		return nil
	end
	return ns.ShareCut(ns.ShareClean(prefix .. body), ns.SHARE_MAX)
end

-- ---------------------------------------------------------------------------
-- De quoi partager : un résultat de capture, un spécimen, un bandeau du carnet
-- ---------------------------------------------------------------------------
-- Le moment vaut-il un partage ? brillante, 3 étoiles, élite / rare / boss, espèce nouvelle
function ns:ShareNotable(result)
	if type(result) ~= "table" then return false end
	return result.shiny == true or (tonumber(result.stars) or 0) >= (ns.CAPTURE_STAR_MAX or 3)
		or (result.class ~= nil and ns.SHARE_NAMED[result.class] == true) or result.fresh == true
end

function ns:ShareItemFromResult(result)
	if not self:ShareNotable(result) then return nil end
	local spec = result.specimen and self.SpecimenGet and self:SpecimenGet(result.specimen)
	local name = self.CreatureName and result.npcID and self:CreatureName(result.npcID, { name = result.name }) or result.name
	return { kind = "capture", name = name, shiny = result.shiny and true or false, stars = result.stars,
		size = spec and spec.size or nil, class = result.class, fresh = result.fresh and true or false,
		key = "cap:" .. tostring(result.specimen or (tostring(result.npcID or result.name) .. ":" .. tostring(result.stars)
			.. ":" .. tostring(result.shiny))) }
end

function ns:ShareItemFromSpecimen(spec)
	if type(spec) ~= "table" then return nil end
	local entry = self.CaptureData and self:CaptureData().creatures[spec.npc]
	local name = self.CreatureName and self:CreatureName(spec.npc, { name = spec.name }) or spec.name
	return { kind = "capture", name = name, shiny = spec.shiny and true or false, stars = spec.stars, size = spec.size,
		class = type(entry) == "table" and entry.class or nil, key = "cap:" .. tostring(spec.id) }
end

function ns:ShareItemFromFeat(def)
	if type(def) ~= "table" and self.FeatDef then def = self:FeatDef(def) end
	if type(def) ~= "table" then return nil end
	return { kind = "feat", name = self:FeatName(def), points = tonumber(def.pts) or 0, key = "feat:" .. tostring(def.id) }
end

-- Un bandeau du carnet (Journal.lua) : haut fait seul ou groupé, sceau, titre
function ns:ShareItemFromEntry(entry)
	if type(entry) ~= "table" then return nil end
	if entry.kind == "feat" then
		if entry.count then
			local first = type(entry.names) == "table" and entry.names[1] or ""
			return { kind = "feats", count = entry.count, points = tonumber(entry.points) or 0, names = entry.names,
				key = "feats:" .. tostring(entry.count) .. ":" .. tostring(entry.points) .. ":" .. tostring(first) }
		end
		local def = entry.id and self.FeatDef and self:FeatDef(entry.id)
		return { kind = "feat", name = entry.name or (def and self:FeatName(def)), points = tonumber(entry.points)
			or (def and tonumber(def.pts)) or 0, key = "feat:" .. tostring(entry.id or entry.name) }
	elseif entry.kind == "seal" then
		return { kind = "seal", name = entry.name, key = "seal:" .. tostring(entry.name) }
	elseif entry.kind == "rank" then
		return { kind = "title", name = entry.name, key = "title:" .. tostring(entry.name) }
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Canaux, envoi, copie, anti-spam
-- ---------------------------------------------------------------------------
-- Les canaux disponibles maintenant, dans l'ordre du menu (« COPY » toujours)
function ns:ShareChannels()
	local list = {}
	if Call("IsInGuild") then list[#list + 1] = "GUILD" end
	local home, instance = G("LE_PARTY_CATEGORY_HOME") or 1, G("LE_PARTY_CATEGORY_INSTANCE") or 2
	if Call("IsInRaid") then
		list[#list + 1] = "RAID"
	elseif Call("IsInGroup", home) then
		list[#list + 1] = "PARTY"
	elseif Call("IsInGroup", instance) then
		list[#list + 1] = "INSTANCE_CHAT"
	end
	list[#list + 1] = "SAY"
	list[#list + 1] = "COPY"
	return list
end

ns.shareLog = ns.shareLog or { last = nil, sent = {} }

-- Un partage vers `channel` est-il permis ? true | false, "wait", secondes | false, "again"
function ns:ShareAllowed(item, channel)
	local log, now = self.shareLog, Now()
	if log.last and now - log.last < ns.SHARE_GAP then
		return false, "wait", math.max(1, math.ceil(ns.SHARE_GAP - (now - log.last)))
	end
	local at = item and item.key and log.sent[item.key .. "|" .. tostring(channel)]
	if at and now - at < ns.SHARE_REPEAT then return false, "again" end
	return true
end

local function InInstance()
	local inside = Call("IsInInstance")
	return inside and true or false
end

-- Le texte dans la zone de saisie du chat, sans l'envoyer. `say` : en mode Dire.
function ns:ShareCopy(text, say)
	if type(text) ~= "string" or text == "" then return false end
	local active = Call("ChatEdit_GetActiveWindow")
	if active and not say then
		local insert = G("ChatEdit_InsertLink")
		if type(insert) == "function" then
			local ok, done = pcall(insert, text)
			if ok and done ~= false then return true end
		end
	end
	local open = G("ChatFrame_OpenChat")
	local util = G("ChatFrameUtil")
	if type(open) ~= "function" and type(util) == "table" then open = util.OpenChat end
	if type(open) == "function" then
		local ok = pcall(open, say and ("/s " .. text) or text)
		if ok then return true end
	end
	self:Print(self:F("SHARE_COPY_FALLBACK", text))
	return false
end

-- Envoi, depuis le clic d'une entrée du menu SEULEMENT (événement matériel)
function ns:ShareSend(item, channel)
	local text = self:ShareText(item)
	if not text then return false end
	if channel == "COPY" then return self:ShareCopy(text) end
	local ok, why, wait = self:ShareAllowed(item, channel)
	if not ok then
		if why == "wait" then self:Print(self:FP("SHARE_WAIT", wait)) else self:Print(L.SHARE_AGAIN) end
		return false, why
	end
	-- hors instance, « Dire » n'est permis qu'au joueur : le texte attend dans la saisie
	if channel == "SAY" and not InInstance() then
		self:Print(L.SHARE_SAY_OUTSIDE)
		return self:ShareCopy(text, true), "say"
	end
	local send = G("SendChatMessage")
	local info = G("C_ChatInfo")
	if type(send) ~= "function" and type(info) == "table" then send = info.SendChatMessage end
	if type(send) ~= "function" then return false, "api" end
	local sent, err = pcall(send, text, channel)
	if not sent then
		if self.RecordError then self:RecordError("share:send", err) end
		return false, "api"
	end
	local log, now = self.shareLog, Now()
	log.last = now
	if item.key then log.sent[item.key .. "|" .. channel] = now end
	return true
end

-- ---------------------------------------------------------------------------
-- Le menu des canaux (un seul cadre, construit une fois)
-- ---------------------------------------------------------------------------
local function Over(frame)
	if type(frame) ~= "table" or type(frame.IsMouseOver) ~= "function" then return false end
	local ok, over = pcall(frame.IsMouseOver, frame)
	return ok and over and true or false
end

local function Tooltip() local tip = G("GameTooltip"); return type(tip) == "table" and tip.SetOwner and tip or nil end

function ns:ShareMenu()
	if self.shareMenu then return self.shareMenu end
	local M = ns.SHARE_MENU
	local menu = CreateFrame("Frame", "QuestCompanionShareMenu", UIParent)
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:SetWidth(M.w)
	menu.bg = Theme.Solid(menu, "BACKGROUND", Theme.NAV, 1)
	menu.bg:SetAllPoints()
	menu.edge = Theme.Border(menu, Theme.EDGE, 1)
	menu.title = Theme.Text(menu, Theme.F_CAPS, Theme.MUTED_LIGHT)
	menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", M.pad + 4, -M.pad)
	menu.title:SetWidth(M.w - 2 * M.pad - 8)
	menu.title:SetJustifyH("LEFT")
	menu.rows = {}
	for index = 1, M.rows do
		local row = CreateFrame("Button", nil, menu)
		row:SetSize(M.w - 2 * M.pad, M.row)
		row:SetPoint("TOPLEFT", menu, "TOPLEFT", M.pad, -M.pad - M.title - (index - 1) * M.row)
		row.hover = Theme.Solid(row, "ARTWORK", Theme.WHITE, Theme.HOVER_ALPHA)
		row.hover:SetAllPoints()
		row.hover:Hide()
		row.text = Theme.Text(row, Theme.F_LABEL, Theme.LABEL)
		row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
		row.text:SetWidth(M.w - 2 * M.pad - 8)
		row.text:SetJustifyH("LEFT")
		row:SetScript("OnEnter", function(r)
			r.hover:Show()
			if r.channel == "COPY" then
				local tip = Tooltip()
				if tip then
					tip:SetOwner(r, "ANCHOR_RIGHT")
					Theme.TooltipLine(tip, L.SHARE_COPY_TIP, Theme.PARCHMENT, true)
					tip:Show()
				end
			end
		end)
		row:SetScript("OnLeave", function(r)
			r.hover:Hide()
			local tip = Tooltip()
			if tip and tip.Hide then tip:Hide() end
		end)
		-- LE clic : seul chemin vers SendChatMessage
		row:SetScript("OnClick", function(r) ns:ShareMenuPick(r.channel) end)
		row:Hide()
		menu.rows[index] = row
	end
	-- un clic ailleurs le referme (événement écouté seulement menu ouvert)
	menu:SetScript("OnEvent", function(m)
		if not (Over(m) or Over(m.owner)) then m:Hide() end
	end)
	menu:SetScript("OnShow", function(m) pcall(m.RegisterEvent, m, "GLOBAL_MOUSE_DOWN") end)
	menu:SetScript("OnHide", function(m)
		pcall(m.UnregisterEvent, m, "GLOBAL_MOUSE_DOWN")
		m.owner, m.item = nil, nil
	end)
	if Theme.RegisterEscapeClose then Theme.RegisterEscapeClose(menu) end
	menu:Hide()
	self.shareMenu = menu
	return menu
end

-- Habit du menu : bois sombre et Friz Quadrata en Azeroth, socle en Sobre
local function PaintMenu(self, menu)
	local az = self.AzerothOn and self:AzerothOn() and ns.AZEROTH_INK and ns.AZEROTH_CONTRAST
		and ns.AZEROTH_CONTRAST["share.entry"] and true or false
	menu.azeroth = az
	local INK = ns.AZEROTH_INK
	local bg = az and INK.woodBg or Theme.NAV
	menu.bg:SetVertexColor(bg[1], bg[2], bg[3], 1)
	local edge = az and ns.AZEROTH_BUTTONS and ns.AZEROTH_BUTTONS.gold.edge or Theme.EDGE
	menu.edge:SetColor(edge[1], edge[2], edge[3], 1)
	-- (3.1.0 : thème forgé : le titre du menu en couleur d'identité)
	local forged = not az and ns.QCForged and ns.QCForged()
	local titleInk = az and INK[ns.AZEROTH_CONTRAST["share.title"][1]] or (forged and Theme.IDENTITY_LIGHT) or Theme.MUTED_LIGHT
	local entryInk = az and INK[ns.AZEROTH_CONTRAST["share.entry"][1]] or Theme.LABEL
	if az and ns.AzerothFont then
		ns.AzerothFont(menu.title, ns.AZEROTH_CONTRAST["share.title"][4])
	elseif menu.title.SetFontObject then
		menu.title:SetFontObject(Theme.F_CAPS)
	end
	menu.title:SetTextColor(titleInk[1], titleInk[2], titleInk[3], 1)
	for _, row in ipairs(menu.rows) do
		if az and ns.AzerothFont then
			ns.AzerothFont(row.text, ns.AZEROTH_CONTRAST["share.entry"][4])
		elseif row.text.SetFontObject then
			row.text:SetFontObject(Theme.F_LABEL)
		end
		row.text:SetTextColor(entryInk[1], entryInk[2], entryInk[3], 1)
	end
end

-- Ouvre (ou referme, second clic) le menu sous `owner` pour `item`
function ns:ShareOpen(owner, item)
	if type(item) ~= "table" then return nil end
	local menu = self:ShareMenu()
	if menu:IsShown() and menu.owner == owner then menu:Hide(); return nil end
	PaintMenu(self, menu)
	local M = ns.SHARE_MENU
	menu.title:SetText(Theme.Upper and Theme.Upper(L.SHARE_MENU_TITLE) or L.SHARE_MENU_TITLE)
	local channels = self:ShareChannels()
	local shown = 0
	for index, row in ipairs(menu.rows) do
		local channel = channels[index]
		row.channel = channel
		if channel then
			row.text:SetText(L["SHARE_CH_" .. channel])
			row:Show()
			shown = shown + 1
		else
			row:Hide()
		end
	end
	menu:SetHeight(2 * M.pad + M.title + shown * M.row)
	-- 3.1.0 : l'habillage du socle (ombre et cadre d'orfèvre en thème forgé,
	-- rien en Sobre ni sur le bois de l'ancien habillage : menu.azeroth),
	-- comme un bandeau ; le filet d'un pixel est le sien
	if Theme.DressWindow then
		menu.chrome, menu.border = "toast", menu.edge
		pcall(Theme.DressWindow, menu)
	end
	menu:ClearAllPoints()
	if owner then menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
	else menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
	menu.owner, menu.item = owner, item
	menu:Show()
	-- le bandeau d'où il vient reste tant que le menu est ouvert (ns:ShareHold)
	return menu
end

-- Une entrée choisie (clic) : le menu se ferme, le partage part
function ns:ShareMenuPick(channel)
	local menu = self.shareMenu
	local item = menu and menu.item
	if menu then menu:Hide() end
	if not (item and channel) then return false end
	return self:ShareSend(item, channel)
end

-- ---------------------------------------------------------------------------
-- Le bouton (un par cadre, créé une fois)
-- ---------------------------------------------------------------------------
local function ButtonLook(button, hot)
	-- 3.1.0 : petite plaque forgée (neutre, bronze au survol), sans filet
	if button.forge and button.forgeLook then
		button.forgeLook(button, hot and "hover" or "rest")
		if button.icon.SetDesaturated then button.icon:SetDesaturated(false) end
		button.icon:SetAlpha(hot and 1 or 0.9)
		return
	end
	local az = button.azeroth
	local edge = hot and Theme.GOLD or (az and ns.AZEROTH_BUTTONS and ns.AZEROTH_BUTTONS.gold.edge) or Theme.EDGE
	button.edge:SetColor(edge[1], edge[2], edge[3], 1)
	if button.icon.SetDesaturated then button.icon:SetDesaturated(false) end
	button.icon:SetAlpha(hot and 1 or 0.9)
	if hot then button.hover:Show() else button.hover:Hide() end
end

-- Le libellé « Partager » à côté de l'icône (bandeaux Azeroth, où il y a la
-- place) : le bouton s'élargit à son texte
local function ButtonLabel(button, on)
	local B = ns.SHARE_BUTTON
	if on then
		if button.forge then
			-- 3.1.0 : sur la plaque forgée, l'encre des boutons secondaires
			-- (mesurée sur la plaque neutre et sur le bronze du survol)
			local ink = ns.SHARE_FORGE_INK
			button.label:SetTextColor(ink[1], ink[2], ink[3], 1)
		else
			local role = ns.AZEROTH_CONTRAST and ns.AZEROTH_CONTRAST["share.label"]
			local ink = (role and ns.AZEROTH_INK and ns.AZEROTH_INK[role[1]]) or Theme.LABEL
			if ns.AzerothFont and role then ns.AzerothFont(button.label, role[4]) end
			button.label:SetTextColor(ink[1], ink[2], ink[3], 1)
		end
		button.label:SetText(L.SHARE_LABEL)
		local measure = button.label.GetUnboundedStringWidth or button.label.GetStringWidth
		local w = math.ceil(tonumber(measure and measure(button.label)) or 50)
		button:SetWidth(B.size + B.labelGap + w + B.labelPad)
		button.label:Show()
	else
		button.label:SetText("")
		button.label:Hide()
		button:SetWidth(B.size)
	end
	button.labelled = on and true or false
end

function ns:ShareButton(parent, where)
	local B = ns.SHARE_BUTTON
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(B.size, B.size)
	button.shareBanner = where
	-- plaque opaque : l'icône et le libellé se lisent sur n'importe quel bandeau
	button.plate = Theme.Solid(button, "BACKGROUND", Theme.NAV, 1)
	button.plate:SetAllPoints()
	button.hover = Theme.Solid(button, "BORDER", Theme.WHITE, Theme.HOVER_ALPHA)
	button.hover:SetAllPoints()
	button.hover:Hide()
	button.edge = Theme.Border(button, Theme.EDGE, 1)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetSize(B.icon, B.icon)
	button.icon:SetPoint("LEFT", button, "LEFT", math.floor((B.size - B.icon) / 2), 0)
	Theme.PaintClient(button.icon, ns.SHARE_ICON)
	button.label = Theme.Text(button, Theme.F_SMALL, Theme.LABEL)
	button.label:SetPoint("LEFT", button.icon, "RIGHT", B.labelGap, 0)
	button.label:SetJustifyH("LEFT")
	button.label:Hide()
	-- 3.1.0 : sous le thème forgé, une petite plaque forgée (décidé à la
	-- création) ; la plaque opaque et le filet du Sobre sont cachés
	if ns.QCForged and ns.QCForged() and Theme.ForgeSmallPlate then
		button.plate:Hide()
		button.border = button.edge
		Theme.ForgeSmallPlate(button)
		button.forge = true
	end
	ButtonLook(button, false)
	button:SetScript("OnEnter", function(b)
		ButtonLook(b, true)
		local tip = Tooltip()
		if not tip then return end
		tip:SetOwner(b, "ANCHOR_TOP")
		Theme.TooltipTitle(tip, L.SHARE_TIP)
		Theme.TooltipHint(tip, L.SHARE_TIP_DETAIL, true)
		tip:Show()
	end)
	button:SetScript("OnLeave", function(b)
		ButtonLook(b, false)
		local tip = Tooltip()
		if tip and tip.Hide then tip:Hide() end
	end)
	button:SetScript("OnClick", function(b) ns:ShareOpen(b, b.item) end)
	button:Hide()
	return button
end

-- Le bouton d'un bandeau (journal, result) ou de la scène (stage) : créé une
-- fois, au-dessus du bouton invisible du bandeau
local function Attach(self, frame, where)
	if type(frame) ~= "table" then return nil end
	if frame.shareButton then return frame.shareButton end
	local button = self:ShareButton(frame, where)
	local base = (frame.button and frame.button.GetFrameLevel and frame.button:GetFrameLevel())
		or (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
	button:SetFrameLevel(base + 4)
	button.azeroth = frame.azeroth and true or false
	ButtonLook(button, false)
	-- largeurs d'origine des textes (Sobre : ils s'écartent du bouton)
	frame.shareWidths = {}
	for _, key in ipairs({ "title", "text", "stars" }) do
		local fs = frame[key]
		if fs and fs.GetWidth then frame.shareWidths[key] = fs:GetWidth() end
	end
	frame.shareButton = button
	return button
end

local function Place(self, frame, button, on)
	local B = ns.SHARE_BUTTON
	button:ClearAllPoints()
	if button.shareBanner == "stage" then
		button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", B.stage.x, B.stage.y)
		return
	end
	if frame.azeroth then
		button:SetPoint("BOTTOMRIGHT", frame.banner or frame, "BOTTOMRIGHT", B.azeroth.x, B.azeroth.y)
		return
	end
	-- 3.1.0 : bandeau forgé : en bas à droite, libellé écrit ; les textes
	-- s'écartent de la largeur du bouton (les points sont au médaillon)
	if frame.forgeBanner then
		button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", B.forge.x, B.forge.y)
		local reserve = on and ((tonumber(button:GetWidth()) or B.size) + B.sobreGap) or 0
		for key, width in pairs(frame.shareWidths or {}) do
			local fs = frame[key]
			if fs and fs.SetWidth and tonumber(width) then fs:SetWidth(math.max(40, width - reserve)) end
		end
		return
	end
	-- Sobre : à droite, centré, avant les points d'un haut fait ; les textes s'écartent
	local points = frame.featPoints and frame.featPoints.IsShown and frame.featPoints:IsShown()
	button:SetPoint("RIGHT", frame, "RIGHT", -(points and B.featGap or B.sobreGap), 0)
	local reserve = on and (B.size + B.sobreGap + (points and B.featGap - B.sobreGap or 0)) or 0
	for key, width in pairs(frame.shareWidths or {}) do
		local fs = frame[key]
		if fs and fs.SetWidth and tonumber(width) then fs:SetWidth(math.max(40, width - reserve)) end
	end
end

-- Pose (ou cache) le bouton d'un cadre pour `item` (nil : rien à partager)
function ns:ShareSync(frame, item, where)
	if type(frame) ~= "table" then return nil end
	local on = item ~= nil and self:DB().shareBanner ~= false
	local button = frame.shareButton
	if not button and not on then return nil end
	button = button or Attach(self, frame, where)
	if not button then return nil end
	button.item = on and item or nil
	button.azeroth = frame.azeroth and true or false
	ButtonLook(button, false)
	-- (3.1.0 : écrit aussi sur un bandeau forgé, où la place est réservée)
	ButtonLabel(button, on and (frame.azeroth or (frame.forgeBanner and button.forge)) and where ~= "stage")
	Place(self, frame, button, on)
	if on then button:Show() else button:Hide() end
	if not on and self.shareMenu and self.shareMenu.owner == button then self.shareMenu:Hide() end
	-- un bandeau qui porte le bouton reste un peu plus longtemps
	if on then
		local now = Now()
		if where == "journal" and self.journalToastHideAt then
			self.journalToastHideAt = self.journalToastHideAt + ns.SHARE_EXTRA
		elseif where == "result" and self.captureResultHideAt then
			self.captureResultHideAt = self.captureResultHideAt + ns.SHARE_EXTRA
		end
		button.shownAt = now
	end
	return on and button or nil
end

-- ---------------------------------------------------------------------------
-- Pause : un bandeau ne part pas sous la souris (bandeau, bouton, menu), ni
-- tant que son menu est ouvert ; ensuite, au moins SHARE_RESUME secondes
-- ---------------------------------------------------------------------------
local function Hovered(frame)
	if type(frame) ~= "table" or not (frame.IsShown and frame:IsShown()) then return false end
	return Over(frame) or Over(frame.button) or Over(frame.shareButton)
end

-- Le bandeau `frame` doit-il rester ? (souris dessus, ou son menu ouvert)
function ns:ShareHeld(frame)
	if type(frame) ~= "table" or not (frame.IsShown and frame:IsShown()) then return false end
	local menu = self.shareMenu
	if menu and menu:IsShown() and menu.owner ~= nil and menu.owner == frame.shareButton then return true end
	if menu and menu:IsShown() and Over(menu) and menu.owner == frame.shareButton then return true end
	return Hovered(frame)
end

-- Repousse l'échéance `at` (s) d'un bandeau tenu : jamais moins de SHARE_RESUME devant
function ns:ShareHold(frame, at)
	if not at then return at end
	if not self:ShareHeld(frame) then return at end
	return math.max(at, Now() + ns.SHARE_RESUME)
end

do
	local base = ns.UpdateJournalToast
	if base then
		function ns:UpdateJournalToast(now, ...)
			if self.journalToastHideAt then self.journalToastHideAt = self:ShareHold(self.journalToast, self.journalToastHideAt) end
			return base(self, now, ...)
		end
	end
end
do
	local base = ns.CaptureResultTick
	if base then
		function ns:CaptureResultTick(now, ...)
			if self.captureResultHideAt then self.captureResultHideAt = self:ShareHold(self.captureResult, self.captureResultHideAt) end
			return base(self, now, ...)
		end
	end
end
do
	-- la scène de capture (Azeroth) : son verdict reste tant qu'on le partage
	local base = ns.CaptureTick
	if base then
		function ns:CaptureTick(now, ...)
			local rolling = self.captureState and self.captureState.rolling
			local stage = self.captureStage
			if rolling and rolling.closeAt and stage and stage.shareButton and stage.shareButton:IsShown() then
				rolling.closeAt = self:ShareHold(stage, rolling.closeAt)
			end
			return base(self, now, ...)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Branchements : bandeaux, scène de capture, Réserve, Hauts faits
-- ---------------------------------------------------------------------------
-- Bandeau du carnet (Journal.lua) : l'entrée affichée décide
do
	local base = ns.ShowNextJournalToast
	if base then
		function ns:ShowNextJournalToast(...)
			-- un lot de tampons ne pose pas d'entrée : on part de rien
			if self.journalToast and not self.journalToastHideAt then self.journalToast.entry = nil end
			local frame = base(self, ...)
			if frame then
				local ok, err = pcall(self.ShareSync, self, frame, self:ShareItemFromEntry(frame.entry), "journal")
				if not ok and self.RecordError then self:RecordError("share:journal", err) end
			end
			return frame
		end
	end
end

-- Bandeau « Capturé ! » (AzerothStyle.lua)
do
	local base = ns.CaptureResultShow
	if base then
		function ns:CaptureResultShow(result, ...)
			local frame = base(self, result, ...)
			if frame then
				local ok, err = pcall(self.ShareSync, self, frame, self:ShareItemFromResult(result), "result")
				if not ok and self.RecordError then self:RecordError("share:result", err) end
			end
			return frame
		end
	end
end

-- Scène Azeroth : elle montre elle-même le verdict (pas de bandeau
-- « Capturé ! » en double) ; le bouton va dans son coin (AzerothStyle.lua)
function ns:ShareStageVerdict(rolling, result)
	local frame = self.captureStage
	if not (frame and frame.IsShown and frame:IsShown()) then return nil end
	return self:ShareSync(frame, self:ShareItemFromResult(result), "stage")
end
do
	local base = ns.CaptureShowStage
	if base then
		function ns:CaptureShowStage(...)
			local frame = self.captureStage
			if frame and frame.shareButton then self:ShareSync(frame, nil, "stage") end
			return base(self, ...)
		end
	end
end

-- Réserve : le bouton dans le coin du modèle de la fiche
do
	local panes = ns.JOURNAL_PANES
	local pane = panes and panes.reserve
	if pane then
		local build, refresh = pane.build, pane.refresh
		pane.build = function(self, frame, content, ui, ...)
			local result = build(self, frame, content, ui, ...)
			local rv = frame.res and frame.res.reserve
			local p = rv and rv.preview
			if p and not p.shareButton then
				local B = ns.SHARE_BUTTON
				local button = self:ShareButton(p, "reserve")
				button:SetPoint("TOPRIGHT", p, "TOPRIGHT", B.reserve.x, B.reserve.y)
				button:SetFrameLevel(((p.model and p.model.GetFrameLevel and p.model:GetFrameLevel()) or 1) + 4)
				p.shareButton = button
			end
			return result
		end
		pane.refresh = function(self, frame, ...)
			local result = refresh(self, frame, ...)
			local p = frame.res and frame.res.reserve and frame.res.reserve.preview
			local button = p and p.shareButton
			if button then
				local spec = frame.resPick and self.SpecimenGet and self:SpecimenGet(frame.resPick)
				local confirm = spec and frame.resConfirm == spec.id
				button.item = (spec and not confirm) and self:ShareItemFromSpecimen(spec) or nil
				if button.item then button:Show() else button:Hide() end
			end
			return result
		end
	end
end

-- Hauts faits : clic droit sur un haut fait obtenu ; l'infobulle le dit
do
	local panes = ns.JOURNAL_PANES
	local pane = panes and panes.feats
	if pane then
		local build = pane.build
		pane.build = function(self, frame, content, ui, ...)
			local result = build(self, frame, content, ui, ...)
			for _, row in ipairs((frame.feats and frame.feats.rows) or {}) do
				if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
				row:SetScript("OnClick", function(r, mouse)
					if mouse ~= "RightButton" or not (r.entry and r.entry.got and r.def) then return end
					ns:ShareOpen(r, ns:ShareItemFromFeat(r.def))
				end)
			end
			return result
		end
	end
	local tipBase = ns.JournalFeatsTip
	if tipBase then
		function ns:JournalFeatsTip(row, ...)
			local result = tipBase(self, row, ...)
			local tip = Tooltip()
			if tip and row and row.entry and row.entry.got and row.def then
				Theme.TooltipHint(tip, L.SHARE_ROW_HINT, true)
				tip:Show()
			end
			return result
		end
	end
end

-- ---------------------------------------------------------------------------
-- Annonce automatique (3.1.0) : brillante ou spécimen 3 étoiles, dans le chat
-- du groupe (comme le message de groupe de Questie)
-- ---------------------------------------------------------------------------
-- Réglages « Annoncer au groupe mes brillantes et 3 étoiles » (actif) et
-- « Annoncer aussi à la guilde » (coupé). Groupe : INSTANCE_CHAT, RAID ou
-- PARTY ; seul : rien. Jamais Dire, Crier ni un canal public. Ces canaux ne
-- demandent pas d'événement matériel, mais Forever restreint les addons en
-- combat : rien ne part en combat, l'annonce attend PLAYER_REGEN_ENABLED (et
-- les prises du combat partent ensemble, une ligne). Envoi protégé (pcall) ;
-- refusé (ADDON_ACTION_BLOCKED) ou en erreur : abandonné sans un mot, noté
-- une fois au journal des erreurs. Au plus une annonce par canal toutes les
-- 30 s ; un spécimen déjà partagé à la main dans ce canal depuis moins d'une
-- minute n'est pas annoncé (et l'inverse : ns.shareLog.sent).
ns.ANNOUNCE_GAP = 30          -- s entre deux annonces automatiques d'un même canal
ns.announceQueue = ns.announceQueue or {}
ns.announceLog = ns.announceLog or {}

local function Notable(stars, shiny)
	return shiny == true or (tonumber(stars) or 0) >= (ns.CAPTURE_STAR_MAX or 3)
end

-- Une erreur d'annonce, notée une fois, sans rien dire dans le chat
local function QuietError(self, where, message)
	if self.announceErrorNoted then return end
	self.announceErrorNoted = true
	local errors = self.errors
	if type(errors) ~= "table" then return end
	if #errors >= (ns.ERRORS_MAX or 50) then self.errorsDropped = (self.errorsDropped or 0) + 1; return end
	errors[#errors + 1] = { where = where, message = tostring(message) }
end

function ns:AnnounceInCombat()
	return Call("InCombatLockdown") and true or (Call("UnitAffectingCombat", "player") and true or false)
end

-- Canaux de l'annonce, maintenant (jamais SAY, YELL ni un canal public)
function ns:AnnounceChannels()
	local db, list = self:DB(), {}
	if db.announceGroup ~= false then
		local home, instance = G("LE_PARTY_CATEGORY_HOME") or 1, G("LE_PARTY_CATEGORY_INSTANCE") or 2
		if Call("IsInGroup", instance) then list[#list + 1] = "INSTANCE_CHAT"
		elseif Call("IsInRaid") then list[#list + 1] = "RAID"
		elseif Call("IsInGroup", home) then list[#list + 1] = "PARTY" end
	end
	if db.announceGuild == true and Call("IsInGuild") then list[#list + 1] = "GUILD" end
	return list
end

-- Libellé court d'une prise dans un lot : « Raptor brillant », « Loup (3 étoiles) »
local function BatchLabel(lang, item)
	local label = ns.ShareClean(item.name)
	if item.shiny then label = Fmt(lang, "SHARE_BATCH_SHINY", label) end
	if (tonumber(item.stars) or 0) >= (ns.CAPTURE_STAR_MAX or 3) then
		label = Fmt(lang, "SHARE_DETAILS", label, Plural(lang, "SHARE_STARS", item.stars))
	end
	return label
end

-- La ligne d'une annonce : une prise, le texte du partage ; plusieurs, une
-- liste tant qu'elle tient (255), puis « … »
function ns:AnnounceText(items, lang)
	if type(items) ~= "table" or #items == 0 then return nil end
	if #items == 1 then return self:ShareText(items[1], lang) end
	local who = ns.ShareClean(items.who or Player() or S(lang, "SHARE_SOMEONE"))
	local prefix = ns.SHARE_PREFIX .. " "
	local room = ns.SHARE_MAX - #prefix
	local list, best = {}, nil
	for index, item in ipairs(items) do
		list[index] = BatchLabel(lang, item)
		local joined = table.concat(list, S(lang, "SHARE_SEP"))
		if index < #items then joined = Fmt(lang, "SHARE_MORE", joined) end
		local line = Fmt(lang, "SHARE_MSG_BATCH", who, #items, joined)
		if #line > room and best then break end
		best = line
	end
	return ns.ShareCut(ns.ShareClean(prefix .. best), ns.SHARE_MAX)
end

local function Send(self, text, channel)
	local send = G("SendChatMessage")
	local info = G("C_ChatInfo")
	if type(send) ~= "function" and type(info) == "table" then send = info.SendChatMessage end
	if type(send) ~= "function" then return false end
	local ok, err = pcall(send, text, channel)
	if not ok then QuietError(self, "share:announce", err); return false end
	return true
end

-- Annonce maintenant (hors combat) ; rend le nombre de lignes envoyées
function ns:AnnounceFlush()
	local queue = self.announceQueue
	if #queue == 0 or self:AnnounceInCombat() then return 0 end
	self.announceQueue = {}
	local log, now, sent = self.shareLog, Now(), 0
	for _, channel in ipairs(self:AnnounceChannels()) do
		local last = self.announceLog[channel]
		if not (last and now - last < ns.ANNOUNCE_GAP) then
			-- les prises déjà partagées à la main dans ce canal (moins d'une minute) restent dehors
			local items = {}
			for _, item in ipairs(queue) do
				local at = item.key and log.sent[item.key .. "|" .. channel]
				if not (at and now - at < ns.SHARE_REPEAT) then items[#items + 1] = item end
			end
			local text = #items > 0 and self:AnnounceText(items)
			if text and Send(self, text, channel) then
				sent = sent + 1
				self.announceLog[channel] = now
				for _, item in ipairs(items) do
					if item.key then log.sent[item.key .. "|" .. channel] = now end
				end
			end
		end
	end
	return sent
end

-- Une prise (ou un lot) à annoncer : en combat, elle attend la fin
function ns:AnnounceCaptures(items)
	if type(items) ~= "table" or #items == 0 then return false end
	local db = self:DB()
	if db.announceGroup == false and db.announceGuild ~= true then return false end
	for _, item in ipairs(items) do self.announceQueue[#self.announceQueue + 1] = item end
	return self:AnnounceFlush() > 0
end

local function CaptureItem(self, result)
	if not (type(result) == "table" and Notable(result.stars, result.shiny)) then return nil end
	local item = self:ShareItemFromResult(result)
	return item
end

-- Lancer seul : le verdict (AzerothStyle.lua a posé rolling.shareResult)
do
	local base = ns.CaptureResolve
	if base then
		function ns:CaptureResolve(rolling, ...)
			local result = base(self, rolling, ...)
			if rolling and rolling.success and not rolling.batch and not self.captureBatchResolving then
				local ok, err = pcall(function()
					local item = CaptureItem(self, rolling.shareResult)
					if item then self:AnnounceCaptures({ item }) end
				end)
				if not ok then QuietError(self, "share:announce", err) end
			end
			return result
		end
	end
end

-- Tout capturer : les brillantes et 3 étoiles du lot, en une ligne
do
	local base = ns.CaptureBatchFlush
	if base then
		function ns:CaptureBatchFlush(batch, ...)
			local fresh = batch and not batch.flushed
			local result = base(self, batch, ...)
			if fresh then
				local ok, err = pcall(function()
					local items = {}
					for _, res in ipairs(batch.results or {}) do
						local target = res.target or {}
						if res.success then
							local item = CaptureItem(self, { name = target.name, shiny = target.shiny and true or false,
								stars = res.stars, npcID = target.npcID, class = target.class, fresh = res.fresh,
								specimen = res.specimen })
							if item then items[#items + 1] = item end
						end
					end
					self:AnnounceCaptures(items)
				end)
				if not ok then QuietError(self, "share:announce", err) end
			end
			return result
		end
	end
end

-- Fin du combat : la file part ; un envoi refusé par le client : noté une fois
do
	local ok, events = pcall(CreateFrame, "Frame")
	if ok and events then
		pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
		pcall(events.RegisterEvent, events, "ADDON_ACTION_BLOCKED")
		events:SetScript("OnEvent", function(_, event, addon, fn)
			if event == "PLAYER_REGEN_ENABLED" then
				local done, err = pcall(ns.AnnounceFlush, ns)
				if not done then QuietError(ns, "share:announce", err) end
			elseif event == "ADDON_ACTION_BLOCKED" and addon == ADDON then
				QuietError(ns, "share:blocked", tostring(fn))
			end
		end)
		ns.announceEvents = events
	end
end

if ns.Mark then ns.Mark("Share") end
