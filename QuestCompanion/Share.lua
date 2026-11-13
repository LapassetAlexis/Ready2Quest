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
ns.SHARE_HOLD = 10           -- s de plus pour le bandeau dont le menu est ouvert
-- l'icône de chat du client, par référence (jamais d'image à nous)
ns.SHARE_ICON = { atlases = { "communities-icon-chat" }, fallback = "Interface\\ChatFrame\\UI-ChatIcon-Chat-Up" }
ns.SHARE_BUTTON = { size = 20, icon = 16, azeroth = { x = -40, y = 14 }, stage = { x = -8, y = -12 },
	reserve = { x = -6, y = -6 }, sobreGap = 10, featGap = 36 }
ns.SHARE_MENU = { w = 160, row = 22, pad = 6, title = 18, rows = 5 }
-- les rangs qui valent un partage (le Capturé ! d'un monstre normal : non)
ns.SHARE_NAMED = { elite = true, rare = true, rareelite = true, worldboss = true }
-- canaux d'envoi direct, dans l'ordre du menu ; « COPY » ferme la liste
ns.SHARE_CHANNELS = { "GUILD", "RAID", "PARTY", "INSTANCE_CHAT", "SAY", "COPY" }

local FR = {
	SHARE_TIP            = "Partager dans le chat",
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
}
local EN = {
	SHARE_TIP            = "Share in chat",
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
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.SHARE_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({ shareBanner = true })

-- 3.1.0 : le menu en Azeroth, sur l'aplat du bois sombre (survol compris) :
-- rôles mesurés (tests/modules/azeroth_style.lua recalcule chaque ratio)
if ns.AZEROTH_CONTRAST and ns.AZEROTH_INK and ns.AZEROTH_INK.woodBg and Theme.Luminance and Theme.Over then
	local worst = Theme.Luminance(Theme.Over(ns.AZEROTH_INK.woodBg, Theme.WHITE, Theme.HOVER_ALPHA))
	ns.AZEROTH_CONTRAST["share.title"] = { "goldHead", worst, 4.5, 10 }
	ns.AZEROTH_CONTRAST["share.entry"] = { "lightSoft", worst, 4.5, 12 }
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
		class = type(entry) == "table" and entry.class or nil, key = "spec:" .. tostring(spec.id) }
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
	local titleInk = az and INK[ns.AZEROTH_CONTRAST["share.title"][1]] or Theme.MUTED_LIGHT
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
	menu:ClearAllPoints()
	if owner then menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
	else menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
	menu.owner, menu.item = owner, item
	menu:Show()
	-- le bandeau d'où il vient reste un peu plus longtemps
	local now = Now()
	local banner = owner and owner.shareBanner
	if banner == "journal" and self.journalToastHideAt then
		self.journalToastHideAt = math.max(self.journalToastHideAt, now + ns.SHARE_HOLD)
	elseif banner == "result" and self.captureResultHideAt then
		self.captureResultHideAt = math.max(self.captureResultHideAt, now + ns.SHARE_HOLD)
	elseif banner == "stage" then
		local rolling = self.captureState and self.captureState.rolling
		if rolling and rolling.closeAt then rolling.closeAt = math.max(rolling.closeAt, now + ns.SHARE_HOLD) end
	end
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
	local az = button.azeroth
	local edge = hot and Theme.GOLD or (az and ns.AZEROTH_BUTTONS and ns.AZEROTH_BUTTONS.gold.edge) or Theme.EDGE
	button.edge:SetColor(edge[1], edge[2], edge[3], 1)
	if button.icon.SetDesaturated then button.icon:SetDesaturated(not hot) end
	button.icon:SetAlpha(hot and 1 or 0.85)
end

function ns:ShareButton(parent, where)
	local B = ns.SHARE_BUTTON
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(B.size, B.size)
	button.shareBanner = where
	button.plate = Theme.Solid(button, "BACKGROUND", Theme.NAV, 0.9)
	button.plate:SetAllPoints()
	button.edge = Theme.Border(button, Theme.EDGE, 1)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetSize(B.icon, B.icon)
	button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
	Theme.PaintClient(button.icon, ns.SHARE_ICON)
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
	Place(self, frame, button, on)
	if on then button:Show() else button:Hide() end
	if not on and self.shareMenu and self.shareMenu.owner == button then self.shareMenu:Hide() end
	return on and button or nil
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

if ns.Mark then ns.Mark("Share") end
