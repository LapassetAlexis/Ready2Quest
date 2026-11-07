-- FeatsTitles.lua -- titres des hauts faits de QuestCompanion (2.7.0, lot D)
--
-- Conception : docs/QC-HAUTS-FAITS.md §1.9 et §4.1. Chargé après Feats.lua
-- (moteur) et JournalFeats.lua (page) : registre des 40 titres, rendu
-- (préfixe, suffixe, apposé en phrase, nu), forme masculine ou féminine,
-- choix du titre affiché, /qc titre, réglage « Forme des titres », bandeau
-- à grand effet pour les gros hauts faits.
--
-- Un titre est gagné si son haut fait l'est : rien à stocker. Le choix vit
-- dans la sauvegarde du personnage (CharData().feats) :
--   title = nil  automatique : le titre du plus haut palier d'espèces
--                (comportement d'avant les hauts faits) ;
--   title = 0    aucun titre ;
--   title = code un titre gagné (un code qui n'est plus disponible, titre de
--                personnage vu d'un autre personnage par exemple : automatique).
--   form  = "auto" (UnitSex : 3 = féminin, sinon masculin) | "m" | "f".
--
-- Registre ns.FEAT_TITLES[code] : { m, f, en, enf, pos, src }
--   * m / f   : modèles français masculin et féminin (f absent = épicène) ;
--   * en / enf: modèle anglais (enf seulement si l'anglais distingue :
--               Lord / Lady, Hero / Heroine) ;
--   * pos     : "pre" (préfixe : « Dresseur %s ») ou "suf" (suffixe :
--               « %s le Traqueur », « %s, Maître des brillantes ») ;
--   * src     : haut fait source (pour la liste des titres pas encore gagnés).
-- Les codes (1 à 255) voyagent dans la fiche de dresseur et les exploits de
-- guilde : jamais renumérotés, jamais réutilisés.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.FEAT_TITLES = {
	[1]  = { pos = "pre", src = "men_species_10",  m = "Apprenti dresseur %s", f = "Apprentie dresseuse %s", en = "Apprentice Trainer %s" },
	[2]  = { pos = "pre", src = "men_species_25",  m = "Dresseur %s", f = "Dresseuse %s", en = "Trainer %s" },
	[3]  = { pos = "pre", src = "men_species_50",  m = "Dresseur confirmé %s", f = "Dresseuse confirmée %s", en = "Seasoned Trainer %s" },
	[4]  = { pos = "pre", src = "men_species_100", m = "Maître dresseur %s", f = "Maîtresse dresseuse %s", en = "Master Trainer %s" },
	[5]  = { pos = "pre", src = "men_species_250", m = "Grand maître dresseur %s", f = "Grande maîtresse dresseuse %s", en = "Grand Master Trainer %s" },
	[6]  = { pos = "suf", src = "men_species_500", m = "%s l'Arpenteur des bêtes", f = "%s l'Arpenteuse des bêtes", en = "%s the Beastwalker" },
	[7]  = { pos = "suf", src = "men_rare_10",     m = "%s le Collectionneur", f = "%s la Collectionneuse", en = "%s the Collector" },
	[8]  = { pos = "suf", src = "men_type_dragonkin", m = "%s le Dompteur de dragons", f = "%s la Dompteuse de dragons", en = "%s the Dragon Tamer" },
	[9]  = { pos = "suf", src = "men_type_demon",  m = "%s le Lieur de démons", f = "%s la Lieuse de démons", en = "%s the Demonbinder" },
	[10] = { pos = "suf", src = "men_types_master", m = "%s, Maître des huit familles", f = "%s, Maîtresse des huit familles", en = "%s, Master of the Eight Families" },
	[11] = { pos = "suf", src = "men_stars3_100",  m = "%s l'Esthète", en = "%s the Connoisseur" },
	[12] = { pos = "suf", src = "shiny_found_50",  m = "%s le Chasseur de brillantes", f = "%s la Chasseuse de brillantes", en = "%s the Shiny Hunter" },
	[13] = { pos = "suf", src = "shiny_cap_25",    m = "%s, Maître des brillantes", f = "%s, Maîtresse des brillantes", en = "%s, Master of Shinies" },
	[14] = { pos = "suf", src = "zone_seal_15",    m = "%s le Gardien des sceaux", f = "%s la Gardienne des sceaux", en = "%s the Seal Keeper" },
	[15] = { pos = "suf", src = "zone_all_biomes", m = "%s le Globe-trotteur", f = "%s la Globe-trotteuse", en = "%s the Globetrotter" },
	[16] = { pos = "suf", src = "zone_visit_all",  m = "%s l'Arpenteur", f = "%s l'Arpenteuse", en = "%s the Wayfarer" },
	[17] = { pos = "pre", src = "zone_capitals",   m = "Ambassadeur %s", f = "Ambassadrice %s", en = "Ambassador %s" },
	[18] = { pos = "suf", src = "day_mission_100", m = "%s l'Infatigable", en = "%s the Tireless" },
	[19] = { pos = "suf", src = "day_rare_50",     m = "%s le Traqueur", f = "%s la Traqueuse", en = "%s the Tracker" },
	[20] = { pos = "suf", src = "day_days_365",    m = "%s, Ami fidèle", f = "%s, Amie fidèle", en = "%s, Faithful Friend" },
	[21] = { pos = "suf", src = "char_level_60",   m = "%s l'Aventurier", f = "%s l'Aventurière", en = "%s the Adventurer" },
	[22] = { pos = "suf", src = "char_gold_1000",  m = "%s le Fortuné", f = "%s la Fortunée", en = "%s the Wealthy" },
	[23] = { pos = "suf", src = "char_deaths_100", m = "%s le Revenant", f = "%s la Revenante", en = "%s the Revenant" },
	[24] = { pos = "suf", src = "dng_visit_all",   m = "%s l'Explorateur des abîmes", f = "%s l'Exploratrice des abîmes", en = "%s the Deepdelver" },
	[25] = { pos = "suf", src = "dng_raid_naxx",   m = "%s, Briseur de nécropole", f = "%s, Briseuse de nécropole", en = "%s the Necropolis Breaker" },
	[26] = { pos = "suf", src = "prof_300",        m = "%s aux mains d'or", en = "%s the Goldhanded" },
	[27] = { pos = "suf", src = "prof_double_300", m = "%s le Polyvalent", f = "%s la Polyvalente", en = "%s the Versatile" },
	[28] = { pos = "pre", src = "prof_cook_300",   m = "Chef %s", en = "Chef %s" },
	[29] = { pos = "suf", src = "prof_fish_300",   m = "%s le Pêcheur", f = "%s la Pêcheuse", en = "%s the Fisher" },
	[30] = { pos = "suf", src = "quest_1000",      m = "%s, Mémoire des chemins", en = "%s, Keeper of Paths" },
	[31] = { pos = "suf", src = "rep_exalted_5",   m = "%s le Bienvenu", f = "%s la Bienvenue", en = "%s the Welcome" },
	[32] = { pos = "suf", src = "fun_hogger_capture", m = "%s, Dompteur de Lardeur", f = "%s, Dompteuse de Lardeur", en = "%s, Hogger's Handler" },
	[33] = { pos = "suf", src = "fun_murlocs",     m = "%s, Ami des murlocs", f = "%s, Amie des murlocs", en = "%s, Friend of Murlocs" },
	[34] = { pos = "suf", src = "fun_night_owl",   m = "%s le Noctambule", f = "%s la Noctambule", en = "%s the Night Owl" },
	[35] = { pos = "suf", src = "meta_menagerie",  m = "%s, Seigneur de la ménagerie", f = "%s, Dame de la ménagerie",
		en = "%s, Lord of the Menagerie", enf = "%s, Lady of the Menagerie" },
	[36] = { pos = "suf", src = "meta_dungeons",   m = "%s, Terreur des cachots", en = "%s, Dread of the Dungeons" },
	[37] = { pos = "suf", src = "meta_hero",       m = "%s, Héros d'Azeroth", f = "%s, Héroïne d'Azeroth",
		en = "%s, Hero of Azeroth", enf = "%s, Heroine of Azeroth" },
	[38] = { pos = "suf", src = "meta_trainer",    m = "%s le Légendaire", f = "%s la Légendaire", en = "%s the Legendary" },
	-- T39 : petit méta caché d'Insolite (char_deaths_1 + fun_drown + fun_fall + fun_lava)
	[39] = { pos = "suf", src = "fun_unlucky",     m = "%s le Malchanceux", f = "%s la Malchanceuse", en = "%s the Unlucky" },
	[40] = { pos = "suf", src = "men_bad_luck",    m = "%s, Bredouille", en = "%s the Empty-Handed" },
}
ns.FEAT_TITLE_MAX = 255
ns.FEAT_TITLE_FORMS = { "auto", "m", "f" }
-- titre automatique : palier d'espèces (TRAINER_RANKS, MenagerieCollection.lua) -> code
ns.FEAT_RANK_TITLES = { apprentice = 1, trainer = 2, seasoned = 3, master = 4, grandmaster = 5 }

local FR = {
	OPT_FEAT_TITLE_FORM      = "Forme des titres",
	OPT_FEAT_TITLE_FORM_DESC = "Automatique : selon ton personnage. Masculin ou féminin : au choix (ce personnage seulement). Les autres joueurs voient la même forme.",
	FEAT_FORM_auto           = "Automatique",
	FEAT_FORM_m              = "Masculin",
	FEAT_FORM_f              = "Féminin",
	FEAT_TITLE_AUTO          = "Automatique",
	FEAT_TITLE_AUTO_IS       = "Automatique (%s)",
	FEAT_TITLE_NONE          = "Aucun titre",
	FEAT_TITLE_PICK          = "Titre affiché",
	FEAT_TITLE_CURRENT       = "Titre affiché : %s",
	FEAT_TITLE_SET           = "Titre affiché : %s.",
	FEAT_TITLE_SET_NONE      = "Plus de titre affiché.",
	FEAT_TITLE_SET_AUTO      = "Titre automatique : %s.",
	FEAT_TITLE_UNKNOWN       = "Titre inconnu ou pas encore gagné : « %s ». /qc titre pour la liste.",
	FEAT_TITLE_LIST          = "Titres gagnés (%d) :",
	FEAT_TITLE_LIST_NONE     = "Aucun titre gagné pour l'instant (le premier vient à 10 espèces capturées).",
	FEAT_TITLE_LIST_ROW      = "  %d — %s",
	FEAT_TITLE_LIST_HINT     = "/qc titre <numéro|nom|auto|aucun>",
	HELP_TITLE               = "/qc titre [numéro|nom|auto|aucun] — le titre affiché sur ta fiche de dresseur",
}
local EN = {
	OPT_FEAT_TITLE_FORM      = "Title form",
	OPT_FEAT_TITLE_FORM_DESC = "Automatic: from your character. Masculine or feminine: your pick (this character only). Other players see the same form.",
	FEAT_FORM_auto           = "Automatic",
	FEAT_FORM_m              = "Masculine",
	FEAT_FORM_f              = "Feminine",
	FEAT_TITLE_AUTO          = "Automatic",
	FEAT_TITLE_AUTO_IS       = "Automatic (%s)",
	FEAT_TITLE_NONE          = "No title",
	FEAT_TITLE_PICK          = "Displayed title",
	FEAT_TITLE_CURRENT       = "Displayed title: %s",
	FEAT_TITLE_SET           = "Displayed title: %s.",
	FEAT_TITLE_SET_NONE      = "No title displayed any more.",
	FEAT_TITLE_SET_AUTO      = "Automatic title: %s.",
	FEAT_TITLE_UNKNOWN       = "Unknown or not yet earned title: \"%s\". /qc title for the list.",
	FEAT_TITLE_LIST          = "Titles earned (%d):",
	FEAT_TITLE_LIST_NONE     = "No title earned yet (the first one comes at 10 species captured).",
	FEAT_TITLE_LIST_ROW      = "  %d — %s",
	FEAT_TITLE_LIST_HINT     = "/qc title <number|name|auto|none>",
	HELP_TITLE               = "/qc title [number|name|auto|none] — the title shown on your trainer card",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.FEAT_TITLE_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function Plain(v)
	if ns.Plain then return ns.Plain(v) end
	return v
end
local function English()
	local locale = Call(G("GetLocale")) or "frFR"
	return not (locale == "frFR" or locale == "fr")
end

-- ---------------------------------------------------------------------------
-- Forme (genre) des titres
-- ---------------------------------------------------------------------------
function ns:FeatTitleForm()
	local form = self:FeatStore("char").form
	if form == "m" or form == "f" then return form end
	return "auto"
end

function ns:FeatSetTitleForm(form)
	if form ~= "auto" and form ~= "m" and form ~= "f" then return nil end
	self:FeatStore("char").form = form ~= "auto" and form or nil
	self:FeatTitlesChanged()
	return form
end

-- "m" ou "f" : le réglage l'emporte ; sinon UnitSex (2 = masculin, 3 =
-- féminin, 1 ou illisible = masculin)
function ns:FeatTitleGender()
	local form = self:FeatTitleForm()
	if form ~= "auto" then return form end
	return tonumber(Plain(Call(G("UnitSex"), "player"))) == 3 and "f" or "m"
end

function ns:FeatTitleFormChoices()
	local list = {}
	for _, id in ipairs(ns.FEAT_TITLE_FORMS) do list[#list + 1] = { value = id, label = L["FEAT_FORM_" .. id] } end
	return list
end

-- ---------------------------------------------------------------------------
-- Rendu : avec le nom (« Dresseur Dyokrion », « Dyokrion le Traqueur »),
-- apposé au milieu d'une phrase (opts.inline : virgule fermante après un
-- suffixe apposé), ou nu (name = nil : « Traqueur »). Langue du client,
-- forme `gender` ("m" | "f" ; nil = la mienne).
-- ---------------------------------------------------------------------------
function ns:FeatTitleText(code, name, gender, opts)
	local title = ns.FEAT_TITLES[tonumber(code) or code]
	if type(title) ~= "table" then return nil end
	gender = (gender == "f" or gender == "m") and gender or self:FeatTitleGender()
	local fmt
	if English() then fmt = (gender == "f" and title.enf) or title.en
	else fmt = (gender == "f" and title.f) or title.m end
	fmt = fmt or title.m or title.en
	if type(fmt) ~= "string" then return nil end
	if name then
		local text = fmt:gsub("%%s", function() return tostring(name) end)
		if type(opts) == "table" and opts.inline and fmt:find("^%%s,") then text = text .. "," end
		return text
	end
	local bare = fmt:gsub("%%s", ""):gsub("^%s*,%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
	bare = bare:gsub("^[Ll]e ", ""):gsub("^[Ll]a ", ""):gsub("^[Ll]'", ""):gsub("^[Tt]he ", "")
	return (bare:gsub("^%l", string.upper))
end

-- Le nom d'un joueur avec son titre (ou le nom seul si le code est inconnu ici)
function ns:FeatTitleWho(name, code, gender, inline)
	return self:FeatTitleText(code, name, gender, inline and { inline = true } or nil) or name
end

-- ---------------------------------------------------------------------------
-- Titres gagnés et choix du titre affiché
-- ---------------------------------------------------------------------------
-- Titre automatique : celui du plus haut palier d'espèces atteint (ou nil)
function ns:FeatTitleAuto()
	if not self.TrainerRank then return nil end
	local ok, rank = pcall(self.TrainerRank, self)
	return ok and type(rank) == "table" and ns.FEAT_RANK_TITLES[rank.key] or nil
end

-- Codes des titres gagnés, triés : un titre de compte sert sur tous les
-- personnages, un titre de personnage sur celui-ci (FeatGot lit la bonne
-- table) ; le titre du palier d'espèces compte toujours (MenagerieRankCheck)
function ns:FeatTitlesEarned()
	local set, codes = {}, {}
	for _, def in ipairs(self:FeatDefs()) do
		local code = type(def.reward) == "table" and tonumber(def.reward.title)
		if code and ns.FEAT_TITLES[code] and self:FeatGot(def) then set[code] = true end
	end
	local auto = self:FeatTitleAuto()
	if auto then set[auto] = true end
	for code in pairs(set) do codes[#codes + 1] = code end
	table.sort(codes)
	return codes
end

function ns:FeatTitleEarned(code)
	code = tonumber(code)
	if not code then return false end
	for _, earned in ipairs(self:FeatTitlesEarned()) do if earned == code then return true end end
	return false
end

-- Le choix enregistré : nil (automatique), 0 (aucun) ou un code
function ns:FeatTitleChoice()
	local value = self:FeatStore("char").title
	if value == 0 then return 0 end
	return tonumber(value)
end

-- Le titre affiché, effectif : un code, ou nil (aucun titre)
function ns:FeatTitleCode()
	local choice = self:FeatTitleChoice()
	if choice == 0 then return nil end
	if choice and ns.FEAT_TITLES[choice] and self:FeatTitleEarned(choice) then return choice end
	return self:FeatTitleAuto()
end

-- value : un code gagné, 0 / "none" (aucun) ou nil / "auto". Rend true si posé.
function ns:FeatSetTitle(value)
	local store = self:FeatStore("char")
	if value == nil or value == "auto" then
		store.title = nil
	elseif value == 0 or value == "0" or value == "none" then
		store.title = 0
	else
		local code = tonumber(value)
		if not (code and ns.FEAT_TITLES[code] and self:FeatTitleEarned(code)) then return false end
		store.title = code
	end
	self:FeatTitlesChanged()
	return true
end

-- Après un changement de titre ou de forme : fiche et page à jour
function ns:FeatTitlesChanged()
	-- le haut fait « Nom de scène » (titre choisi) se réévalue
	if self.FeatTouch then pcall(self.FeatTouch, self, "card") end
	if self.trainerState then self.trainerState.ownText = nil end
	if self.TrainerRefreshWindow then pcall(self.TrainerRefreshWindow, self) end
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then pcall(self.RefreshJournal, self) end
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
end

-- Options du sélecteur (fiche de dresseur) : Automatique, Aucun, puis les
-- titres gagnés rendus avec mon nom, dans l'ordre des codes
function ns:FeatTitleOptions(name)
	local auto = self:FeatTitleAuto()
	local autoText = auto and self:FeatTitleText(auto) or L.FEAT_TITLE_NONE
	local options = {
		{ value = "auto", label = self:F("FEAT_TITLE_AUTO_IS", autoText) },
		{ value = "none", label = L.FEAT_TITLE_NONE },
	}
	for _, code in ipairs(self:FeatTitlesEarned()) do
		options[#options + 1] = { value = tostring(code), label = self:FeatTitleText(code, name) or tostring(code) }
	end
	return options
end

-- Valeur du sélecteur pour le choix enregistré
function ns:FeatTitleOptionValue()
	local choice = self:FeatTitleChoice()
	if choice == 0 then return "none" end
	if choice and self:FeatTitleEarned(choice) then return tostring(choice) end
	return "auto"
end

function ns:FeatTitlePick(value)
	if value == "auto" then return self:FeatSetTitle(nil) end
	if value == "none" then return self:FeatSetTitle(0) end
	return self:FeatSetTitle(tonumber(value))
end

-- Compatibilité : ns:TrainerTitle() (sous-titre, nu) suit le choix ; en
-- automatique, il ne change pas (palier d'espèces, MenagerieCollection.lua)
do
	local base = ns.TrainerTitle
	if base then
		function ns:TrainerTitle(...)
			local choice = self:FeatTitleChoice()
			if choice == 0 then return nil end
			if choice then
				local code = self:FeatTitleCode()
				if code and code == choice then return self:FeatTitleText(code) end
			end
			return base(self, ...)
		end
	end
end

-- Un haut fait par son code numérique (n), pour les messages reçus
function ns:FeatDefByCode(n)
	n = tonumber(n)
	if not n then return nil end
	for _, def in ipairs(self:FeatDefs()) do if def.n == n then return def end end
	return nil
end

-- Un « gros » haut fait (titre ou 25 points et plus) : grand effet au bandeau
function ns:FeatIsBig(def)
	if type(def) ~= "table" then return false end
	local titled = type(def.reward) == "table" and def.reward.title ~= nil
	return titled or (tonumber(def.pts) or 0) >= ns.FEAT_GUILD_MIN
end

do
	local push = ns.JournalToastPush
	if push then
		function ns:JournalToastPush(entry, ...)
			if type(entry) == "table" and entry.kind == "feat" and entry.id and self:FeatIsBig(self:FeatDef(entry.id)) then
				-- AzerothStyle.lua pose ailes et éclat (ns:AzerothRewardFX) à l'affichage
				entry.big = true
			end
			return push(self, entry, ...)
		end
	end
end

-- ---------------------------------------------------------------------------
-- /qc titre [numéro|nom|auto|aucun]
-- ---------------------------------------------------------------------------
local function Fold(text)
	text = tostring(text or "")
	if ns.AsciiLower then text = ns.AsciiLower(text) end
	-- lettres accentuées courantes (UTF-8) ramenées à leur base
	local map = { ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
		["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c",
		["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["À"] = "a", ["Â"] = "a", ["Î"] = "i", ["Ô"] = "o", ["Û"] = "u", ["Ç"] = "c" }
	text = text:gsub("[\195][\128-\191]", function(c) return map[c] or c end)
	text = text:gsub("[A-Z]", function(c) return string.char(c:byte() + 32) end)
	return (text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " "))
end

-- Un texte tapé -> "auto" | 0 | code gagné | nil
function ns:FeatTitleResolve(text)
	local word = Fold(text)
	if word == "" then return nil end
	if word == "auto" or word == "automatique" or word == "automatic" then return "auto" end
	if word == "aucun" or word == "none" or word == "0" or word == "rien" then return 0 end
	local code = tonumber(word)
	if code then return self:FeatTitleEarned(code) and code or nil end
	local exact, partial, count = nil, nil, 0
	for _, earned in ipairs(self:FeatTitlesEarned()) do
		local title = ns.FEAT_TITLES[earned]
		local names = {}
		for _, gender in ipairs({ "m", "f" }) do names[#names + 1] = Fold(self:FeatTitleText(earned, nil, gender)) end
		for _, key in ipairs({ "m", "f", "en", "enf" }) do
			if title[key] then
				local bare = title[key]:gsub("%%s", ""):gsub("^%s*,%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
				names[#names + 1] = Fold(bare)
			end
		end
		local hit = false
		for _, name in ipairs(names) do
			if name == word then exact = exact or earned end
			if name:find(word, 1, true) then hit = true end
		end
		if hit then partial, count = earned, count + 1 end
	end
	if exact then return exact end
	if count == 1 then return partial end
	return nil
end

function ns:FeatTitleCommand(rest)
	rest = tostring(rest or "")
	if rest:find("^%s*$") then
		local earned = self:FeatTitlesEarned()
		local code = self:FeatTitleCode()
		self:Print(self:F("FEAT_TITLE_CURRENT", code and self:FeatTitleText(code) or L.FEAT_TITLE_NONE))
		if #earned == 0 then print("   " .. L.FEAT_TITLE_LIST_NONE) return earned end
		print("   " .. self:F("FEAT_TITLE_LIST", #earned))
		for _, item in ipairs(earned) do print("   " .. self:F("FEAT_TITLE_LIST_ROW", item, self:FeatTitleText(item) or "?")) end
		print("   " .. L.FEAT_TITLE_LIST_HINT)
		return earned
	end
	local value = self:FeatTitleResolve(rest)
	if value == nil then
		self:Print(self:F("FEAT_TITLE_UNKNOWN", (rest:gsub("^%s+", ""):gsub("%s+$", ""):gsub("|", "||"))))
		return false
	end
	if value == "auto" then
		self:FeatSetTitle(nil)
		local code = self:FeatTitleCode()
		self:Print(self:F("FEAT_TITLE_SET_AUTO", code and self:FeatTitleText(code) or L.FEAT_TITLE_NONE))
	elseif value == 0 then
		self:FeatSetTitle(0)
		self:Print(L.FEAT_TITLE_SET_NONE)
	else
		self:FeatSetTitle(value)
		self:Print(self:F("FEAT_TITLE_SET", self:FeatTitleText(value) or tostring(value)))
	end
	return true
end
ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["titre"] = function(self, rest) return self:FeatTitleCommand(rest) end
ns.EXTRA_COMMANDS["title"] = ns.EXTRA_COMMANDS["titre"]
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then table.insert(section[2], "HELP_TITLE") end
	end
end

-- ---------------------------------------------------------------------------
-- Réglage « Forme des titres » : page Carnet de voyage, section Hauts faits
-- ---------------------------------------------------------------------------
do
	for _, page in ipairs(ns.OPTION_PAGES or {}) do
		if page.id == "journal" and type(page.rows) == "table" then
			local at, present = nil, false
			for index, row in ipairs(page.rows) do
				if row.key == "featStats" then at = index + 1 end
				if row.key == "featTitleForm" then present = true end
			end
			if at and not present then
				table.insert(page.rows, at, { key = "featTitleForm", label = "OPT_FEAT_TITLE_FORM", kind = "action",
					choices = function() return ns:FeatTitleFormChoices() end,
					current = function() return ns:FeatTitleForm() end,
					describe = function() return L.OPT_FEAT_TITLE_FORM_DESC end,
					choose = function(value) ns:FeatSetTitleForm(value) end })
			end
		end
	end
end

if ns.Mark then ns.Mark("FeatsTitles") end
