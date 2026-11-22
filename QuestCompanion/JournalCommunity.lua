-- JournalCommunity.lua -- page « Communauté » du carnet (QuestCompanion 3.7.0)
--
-- La dernière entrée de la colonne, sous « Addons liés ». Ce que l'addon dit
-- de son Discord, et de quoi donner son avis. Rien ne sort du jeu : l'addon
-- ne peut ni ouvrir un lien ni écrire dans le presse-papiers ; le joueur
-- copie lui-même un texte (champ tout sélectionné au clic, puis Ctrl+C).
--   * Pastille dorée à droite de « Communauté » dans la colonne tant que la
--     page n'a jamais été ouverte (au compte : db.community.seen).
--   * Onglets (une rangée de puces, comme la Réserve) : « Discord » (par
--     défaut) et « Ton avis ». L'onglet « Dresseurs » (3.7, étape suivante)
--     viendra en tête de COMMUNITY_TABS : la rangée se recalcule seule.
--   * Discord : l'invitation à copier, les salons qui existent
--     (COMMUNITY_SALONS : un salon pas encore ouvert n'est pas listé), le mot
--     de la version, la tuile « Cette semaine », la note du bas.
--   * Ton avis : trois questions à choix unique (aucune réponse d'office), un
--     champ libre (600 caractères), ce qui est joint tout seul ; « Composer et
--     copier » écrit l'avis dans la zone à copier et le sélectionne ;
--     « Copier le diagnostic (bug) » y met le texte de /qc diag, précédé
--     d'une ligne de contexte. Les réponses restent le temps de la session.
--   * Le mot de la version : l'addon ne garde que son empreinte
--     (ns.COMMUNITY_WORDS, djb2 sur 32 bits de « qc-word:<version>:<mot> »,
--     ns.CommunityWordHash). Seul le mot de la version en cours se valide,
--     une fois par compte (db.community.words). À partir du deuxième mot
--     validé sur le compte : 25 paillettes.
--   * Deux astuces du compagnon, dans la rotation des astuces de découverte
--     (Discovery.lua, chargé après ce fichier : posées à la première astuce
--     tentée ou à l'entrée dans le monde).
-- Sauvegardé (compte) : db.community = { seen, words }. Rien d'autre : aucune
-- réponse gardée, aucun message, aucune ligne de chat.
-- Page externe du carnet : ns.JOURNAL_PANES.community (JournalWindow.lua).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

-- ---------------------------------------------------------------------------
-- Données écrites à la main (à revoir à chaque version)
-- ---------------------------------------------------------------------------
ns.COMMUNITY_INVITE = "https://discord.gg/b9mYCUhxRb"
-- les salons du Discord, dans l'ordre de la grille (deux colonnes, rangée
-- par rangée). `open = false` : salon pas encore créé, pas affiché.
ns.COMMUNITY_SALONS = {
	{ id = "annonces", name = "addons-annonces" },
	{ id = "captures", name = "captures-brillantes" },
	{ id = "idees", name = "addons-idées" },
	{ id = "bugs", name = "addons-bugs" },
	{ id = "dresseurs", name = "fiches-de-dresseur", open = false },   -- avec le code de dresseur (3.7, étape 3)
	{ id = "english", name = "addons-english" },
}
-- « Vos idées, déjà dans le jeu » : une entrée = un titre, une ligne de
-- source. Aucun nom de joueur.
ns.COMMUNITY_IDEAS = {
	{ fr = "La collection commune à tout le compte", en = "The collection shared by the whole account",
		srcFr = "demandée sur le Discord, livrée en 2.9", srcEn = "asked for on the Discord, shipped in 2.9" },
	{ fr = "« Tout capturer » d'un clic", en = "\"Capture all\" in one click",
		srcFr = "retours de joueurs, livré en 2.4", srcEn = "player feedback, shipped in 2.4" },
	{ fr = "Une page pour la communauté", en = "A page for the community",
		srcFr = "demandée, livrée en 3.7", srcEn = "asked for, shipped in 3.7" },
}
-- l'empreinte du mot de chaque version mineure (le mot en clair n'est
-- nulle part) : ns.CommunityWordHash("3.8", "<mot>") prépare la suivante
ns.COMMUNITY_WORDS = {
	["3.7"] = "df21dabd",
}
ns.COMMUNITY_WORD_PAILLETTES = 25
ns.COMMUNITY_FREE_MAX = 600
-- les onglets, dans l'ordre ; le premier est ouvert par défaut… sauf
-- COMMUNITY_TAB_DEFAULT (l'onglet « Dresseurs » se posera en tête)
ns.COMMUNITY_TABS = { "discord", "avis" }
ns.COMMUNITY_TAB_DEFAULT = "discord"
-- les trois questions (réponses : COM_A_<question>_<n>)
ns.COMMUNITY_QUESTIONS = {
	{ id = "love", answers = 3 },
	{ id = "talk", answers = 3 },
	{ id = "fav", answers = 3 },
}
-- astuces du compagnon : jamais avant ce jour de jeu du compte (1 = le premier)
ns.COMMUNITY_TIP_DAYS = { community = 2, communityAvis = 5 }

local IDEAS = ns.COMMUNITY_IDEAS
local CLICK_FR, CLICK_EN = " Clique sur la bulle pour voir.", " Click the bubble to see."

local FR = {
	JRN_SEC_community     = "Communauté",
	JRN_SUB_community     = "Le Discord, les dresseurs que tu connais, et ton avis sur l'addon.",
	COM_TAB_discord       = "Discord",
	COM_TAB_avis          = "Ton avis",
	COM_TAB_NOTE_discord  = "Rien ne part d'ici : le lien se copie, c'est tout",
	COM_TAB_NOTE_avis     = "Rien n'est envoyé d'ici : tu composes, tu copies, tu colles",
	-- Discord
	COM_DISCORD_TITLE     = "Les Explorateurs De Mondes : le Discord des dresseurs",
	COM_DISCORD_TEXT      = "On y montre ses brillantes, on compare ses fiches de dresseur, on propose des idées et on signale les bugs. Les deux addons y ont leurs salons, en français et en anglais.",
	COM_DISCORD_HINT      = "Clique le lien, puis Ctrl+C, et colle-le dans ton navigateur.\nÀ l'arrivée, choisis « Addons WoW Forever » pour voir les salons.",
	COM_SALONS_HEAD       = "Ce que tu y trouves",
	COM_SALON_annonces    = "Les nouveautés et les bêtas. Le mot de la version y est épinglé.",
	COM_SALON_captures    = "Tes plus belles prises et tes cartes souvenir.",
	COM_SALON_idees       = "Propose, réagis aux idées des autres. « Ton avis » se colle ici.",
	COM_SALON_bugs        = "Un souci ? Dis-le ici, avec le diagnostic copié.",
	COM_SALON_dresseurs   = "Colle ton code de dresseur, ouvre celui des autres.",
	COM_SALON_english     = "The same, in English.",
	COM_WORD_HEAD         = "Le mot de la version",
	COM_WORD_TEXT         = "Un mot est épinglé dans le salon des annonces à chaque version. Le premier donne l'ornement « Explorateur des mondes », les suivants 25 paillettes.",
	COM_WORD_PLACEHOLDER  = "Tape le mot ici…",
	COM_WORD_OK           = "Valider",
	COM_WORD_DONE_FIRST   = "Mot juste, merci de ta visite ! Le mot de la %s est validé.",
	COM_WORD_DONE_MORE    = "Mot juste, merci de ta visite ! Le mot de la %s est validé : +%d paillettes.",
	COM_WORD_ALREADY      = "Le mot de la %s est validé. Le prochain sera épinglé avec la prochaine version.",
	COM_WORD_WRONG        = "Pas tout à fait. Le mot est épinglé dans addons-annonces : réessaie quand tu veux.",
	COM_WORD_NONE         = "Pas encore de mot pour la %s : il sera épinglé dans addons-annonces.",
	COM_WEEK_HEAD         = "Cette semaine",
	COM_WEEK_TITLE        = "Montre ta plus belle prise",
	COM_WEEK_TEXT         = "Poste-la dans captures-brillantes : une capture d'écran suffit.",
	COM_DISCORD_NOTE      = "L'addon ne peut ni ouvrir un lien ni envoyer un message hors du jeu, et il ne sait pas qui est sur Discord : le mot de la version est la seule preuve d'une visite. Un mot manqué ne coûte que ses paillettes.",
	-- Ton avis
	COM_AVIS_INTRO        = "Dis ce que tu aimes, ce qui t'agace, ce que tu ajouterais. Ton texte se colle ensuite dans le salon des idées du Discord, ou en commentaire sur CurseForge.",
	COM_FEEL_HEAD         = "Ton ressenti",
	COM_Q_love            = "Quest Companion, pour toi :",
	COM_A_love_1          = "J'adore",
	COM_A_love_2          = "J'aime bien",
	COM_A_love_3          = "Bof",
	COM_Q_talk            = "Le compagnon parle :",
	COM_A_talk_1          = "trop",
	COM_A_talk_2          = "juste bien",
	COM_A_talk_3          = "pas assez",
	COM_Q_fav             = "Ce que tu préfères :",
	COM_A_fav_1           = "la capture",
	COM_A_fav_2           = "le compagnon",
	COM_A_fav_3           = "les hauts faits",
	COM_FREE_HEAD         = "Ce que tu changerais ou ajouterais",
	COM_FREE_PLACEHOLDER  = "Une idée, un agacement, ce qui te manque… (600 caractères au plus)",
	COM_JOINED            = "Joint tout seul : %s",
	COM_COMPOSE           = "Composer et copier",
	COM_COMPOSE_TIP       = "Réponds à une question ou écris quelques mots d'abord.",
	COM_DIAG              = "Copier le diagnostic (bug)",
	COM_IDEAS_HEAD        = "Vos idées, déjà dans le jeu",
	COM_IDEAS_NOTE        = "Quelques lignes écrites à la main à chaque version. Les idées reprises sont citées ici à la version suivante.",
	COM_COPY_HEAD_AVIS    = "Ce que « Composer et copier » met dans la zone à copier",
	COM_COPY_HEAD_DIAG    = "Le diagnostic, à coller dans addons-bugs",
	COM_COPY_EMPTY        = "Réponds à une question ou écris quelques mots : ton texte s'écrit ici.",
	COM_AVIS_NOTE         = "Tu vois le texte avant de le copier. L'addon ne collecte rien et n'envoie rien : c'est toi qui le colles où tu veux.",
	-- le texte composé (dans la langue du joueur)
	COM_ADDON             = "Quest Companion %s",
	COM_LEVEL             = "niveau %d",
	COM_SPECIES_ONE       = "%d espèce",
	COM_SPECIES_MANY      = "%d espèces",
	COM_DAYS_ONE          = "%d jour",
	COM_DAYS_MANY         = "%d jours",
	COM_DAYS_TOGETHER_ONE = "%d jour ensemble",
	COM_DAYS_TOGETHER_MANY = "%d jours ensemble",
	COM_OUT_HEAD          = "**Avis sur Quest Companion %s** (%s)",
	COM_OUT_FEEL          = "Ressenti : %s",
	COM_OUT_love_1        = "j'adore",
	COM_OUT_love_2        = "j'aime bien",
	COM_OUT_love_3        = "bof",
	COM_OUT_talk_1        = "le compagnon parle trop",
	COM_OUT_talk_2        = "le compagnon parle juste bien",
	COM_OUT_talk_3        = "le compagnon ne parle pas assez",
	COM_OUT_fav_1         = "je préfère la capture",
	COM_OUT_fav_2         = "je préfère le compagnon",
	COM_OUT_fav_3         = "je préfère les hauts faits",
	COM_DIAG_HEAD         = "**Diagnostic Quest Companion %s** (%s)",
	COM_DIAG_CLIENT       = "client %s, interface %s",
	COM_DIAG_CLASS        = "%s niveau %d",
	COM_DIAG_R2Q_ON       = "Ready2Quest %s actif",
	COM_DIAG_R2Q_OFF      = "Ready2Quest désactivé",
	COM_DIAG_R2Q_NONE     = "sans Ready2Quest",
	-- astuces du compagnon (rotation de Discovery.lua)
	DISC_community        = "Les dresseurs ont un Discord. Regarde la page Communauté." .. CLICK_FR,
	DISC_communityAvis    = "Une idée pour moi ? Page Communauté, onglet Ton avis." .. CLICK_FR,
}
local EN = {
	JRN_SEC_community     = "Community",
	JRN_SUB_community     = "The Discord, the trainers you know, and what you think of the addon.",
	COM_TAB_discord       = "Discord",
	COM_TAB_avis          = "Your feedback",
	COM_TAB_NOTE_discord  = "Nothing leaves from here: you copy the link, that's all",
	COM_TAB_NOTE_avis     = "Nothing is sent from here: you write, you copy, you paste",
	COM_DISCORD_TITLE     = "Les Explorateurs De Mondes: the trainers' Discord",
	COM_DISCORD_TEXT      = "Show off your shinies, compare trainer cards, suggest ideas and report bugs. Both addons have their channels there, in French and in English.",
	COM_DISCORD_HINT      = "Click the link, then Ctrl+C, and paste it in your browser.\nOnce there, pick \"Addons WoW Forever\" to see the channels.",
	COM_SALONS_HEAD       = "What you'll find there",
	COM_SALON_annonces    = "News and betas. The version word is pinned there.",
	COM_SALON_captures    = "Your best catches and your souvenir cards.",
	COM_SALON_idees       = "Suggest, react to other people's ideas. \"Your feedback\" goes here.",
	COM_SALON_bugs        = "Something wrong? Say it here, with the copied diagnostics.",
	COM_SALON_dresseurs   = "Paste your trainer code, open other people's.",
	COM_SALON_english     = "The same, in English.",
	COM_WORD_HEAD         = "The version word",
	COM_WORD_TEXT         = "A word is pinned in the announcements channel with each version. The first one gives the \"World Explorer\" ornament, the next ones 25 glitter.",
	COM_WORD_PLACEHOLDER  = "Type the word here…",
	COM_WORD_OK           = "Confirm",
	COM_WORD_DONE_FIRST   = "That's the word, thanks for visiting! The %s word is confirmed.",
	COM_WORD_DONE_MORE    = "That's the word, thanks for visiting! The %s word is confirmed: +%d glitter.",
	COM_WORD_ALREADY      = "The %s word is confirmed. The next one will be pinned with the next version.",
	COM_WORD_WRONG        = "Not quite. The word is pinned in addons-annonces: try again whenever you like.",
	COM_WORD_NONE         = "No word for %s yet: it will be pinned in addons-annonces.",
	COM_WEEK_HEAD         = "This week",
	COM_WEEK_TITLE        = "Show your finest catch",
	COM_WEEK_TEXT         = "Post it in captures-brillantes: a screenshot is enough.",
	COM_DISCORD_NOTE      = "The addon can't open a link or send a message outside the game, and it doesn't know who is on Discord: the version word is the only proof of a visit. A missed word only costs its glitter.",
	COM_AVIS_INTRO        = "Say what you like, what annoys you, what you'd add. Your text then goes in the Discord ideas channel, or as a comment on CurseForge.",
	COM_FEEL_HEAD         = "How you feel",
	COM_Q_love            = "Quest Companion, to you:",
	COM_A_love_1          = "I love it",
	COM_A_love_2          = "I like it",
	COM_A_love_3          = "Meh",
	COM_Q_talk            = "The companion talks:",
	COM_A_talk_1          = "too much",
	COM_A_talk_2          = "just right",
	COM_A_talk_3          = "not enough",
	COM_Q_fav             = "What you like best:",
	COM_A_fav_1           = "capturing",
	COM_A_fav_2           = "the companion",
	COM_A_fav_3           = "achievements",
	COM_FREE_HEAD         = "What you would change or add",
	COM_FREE_PLACEHOLDER  = "An idea, an annoyance, something you miss… (600 characters at most)",
	COM_JOINED            = "Added for you: %s",
	COM_COMPOSE           = "Write and copy",
	COM_COMPOSE_TIP       = "Answer a question or write a few words first.",
	COM_DIAG              = "Copy diagnostics (bug)",
	COM_IDEAS_HEAD        = "Your ideas, already in the game",
	COM_IDEAS_NOTE        = "A few lines written by hand for each version. Ideas that make it in are listed here in the next version.",
	COM_COPY_HEAD_AVIS    = "What \"Write and copy\" puts in the copy box",
	COM_COPY_HEAD_DIAG    = "The diagnostics, to paste in addons-bugs",
	COM_COPY_EMPTY        = "Answer a question or write a few words: your text appears here.",
	COM_AVIS_NOTE         = "You see the text before you copy it. The addon collects nothing and sends nothing: you paste it wherever you want.",
	COM_ADDON             = "Quest Companion %s",
	COM_LEVEL             = "level %d",
	COM_SPECIES_ONE       = "%d species",
	COM_SPECIES_MANY      = "%d species",
	COM_DAYS_ONE          = "%d day",
	COM_DAYS_MANY         = "%d days",
	COM_DAYS_TOGETHER_ONE = "%d day together",
	COM_DAYS_TOGETHER_MANY = "%d days together",
	COM_OUT_HEAD          = "**Feedback on Quest Companion %s** (%s)",
	COM_OUT_FEEL          = "Feeling: %s",
	COM_OUT_love_1        = "I love it",
	COM_OUT_love_2        = "I like it",
	COM_OUT_love_3        = "meh",
	COM_OUT_talk_1        = "the companion talks too much",
	COM_OUT_talk_2        = "the companion talks just right",
	COM_OUT_talk_3        = "the companion doesn't talk enough",
	COM_OUT_fav_1         = "I like capturing best",
	COM_OUT_fav_2         = "I like the companion best",
	COM_OUT_fav_3         = "I like achievements best",
	COM_DIAG_HEAD         = "**Quest Companion %s diagnostics** (%s)",
	COM_DIAG_CLIENT       = "client %s, interface %s",
	COM_DIAG_CLASS        = "%s level %d",
	COM_DIAG_R2Q_ON       = "Ready2Quest %s enabled",
	COM_DIAG_R2Q_OFF      = "Ready2Quest disabled",
	COM_DIAG_R2Q_NONE     = "no Ready2Quest",
	DISC_community        = "Trainers have a Discord. Have a look at the Community page." .. CLICK_EN,
	DISC_communityAvis    = "An idea for me? Community page, Your feedback tab." .. CLICK_EN,
}
for index, idea in ipairs(IDEAS) do
	FR["COM_IDEA_" .. index], EN["COM_IDEA_" .. index] = idea.fr, idea.en
	FR["COM_IDEA_" .. index .. "_SRC"], EN["COM_IDEA_" .. index .. "_SRC"] = idea.srcFr, idea.srcEn
end
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.JOURNAL_COMMUNITY_STRINGS = { fr = FR, en = EN } end

-- le nom de la langue du client, dans sa langue (le texte composé la cite)
local LANGUAGES = {
	frFR = "français", enUS = "English", enGB = "English", esES = "español", esMX = "español",
	deDE = "Deutsch", itIT = "italiano", ptBR = "português", ruRU = "русский",
	koKR = "한국어", zhCN = "简体中文", zhTW = "繁體中文",
}

-- mise en page (cotes de la maquette : y depuis le haut du contenu, ui.TOP)
local LAY = {
	tabsY = 0, tabH = 24, tabGap = 4,
	-- Discord
	headY = 36, headH = 100, headTitleY = 10, headTextY = 29, linkY = 66, linkW = 232, hintX = 254, hintY = 64,
	salonsHeadY = 150, salonY = 168, salonStep = 50, salonW = 347, salonH = 46, salonX2 = 363,
	wordHeadY = 330, tileY = 348, tileW = 347, tileH = 92, fieldY = 58, fieldW = 232, buttonX = 250, buttonW = 87,
	discordNoteY = 452,
	-- Ton avis
	introY = 34, feelHeadY = 74, colW = 440, qY = 92, qStep = 28, qLabelW = 164, chipH = 22,
	freeHeadY = 184, freeY = 202, freeH = 78, joinedY = 286, buttonsY = 308,
	ideasX = 456, ideasW = 254, ideasY = 94, ideaStep = 39, ideasNoteY = 226,
	copyHeadY = 348, copyY = 366, copyH = 92, avisNoteY = 468,
}
ns.JOURNAL_COMMUNITY_LAYOUT = LAY
-- pastille de la colonne (Theme.ART.dot teint de l'or clair)
local NAV_DOT = { size = 30, x = 12 }
ns.JOURNAL_COMMUNITY_DOT = NAV_DOT

-- ---------------------------------------------------------------------------
-- Sauvegarde (compte)
-- ---------------------------------------------------------------------------
function ns:CommunityData()
	local db = self:DB()
	local data = db.community
	if type(data) ~= "table" then
		data = {}
		db.community = data
	end
	if type(data.words) ~= "table" then data.words = {} end
	return data
end

function ns:CommunitySeen() return self:CommunityData().seen == true end

-- ---------------------------------------------------------------------------
-- Le mot de la version
-- ---------------------------------------------------------------------------
-- djb2 sur 32 bits (départ 5381, h = h * 33 + octet, modulo 2^32) de
-- « qc-word:<version>:<mot> », le mot en minuscules et sans espaces autour ;
-- rendu en 8 chiffres hexadécimaux (en deux moitiés : %x d'un nombre de plus
-- de 31 bits n'est pas sûr partout)
function ns.CommunityWordNormalize(word)
	return ns.AsciiLower(tostring(word or "")) or ""
end
function ns.CommunityWordHash(version, word)
	local text = "qc-word:" .. tostring(version or "") .. ":" .. ns.CommunityWordNormalize(word)
	local h = 5381
	for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
	return string.format("%04x%04x", math.floor(h / 65536), h % 65536)
end

-- majeure.mineure de l'addon (« 3.7 »)
function ns:CommunityVersion()
	return tostring(ns.version or ""):match("^(%d+%.%d+)") or tostring(ns.version or "?")
end

function ns:CommunityWordDone(version)
	return self:CommunityData().words[version or self:CommunityVersion()] == true
end

local function WordCount(data)
	local n = 0
	for _, done in pairs(data.words) do if done == true then n = n + 1 end end
	return n
end

-- Rend un état : "ok" (mot juste, compté), "already", "wrong", "none" (pas
-- de mot pour cette version), "empty" ; et les paillettes données
function ns:CommunityWordSubmit(word)
	local version = self:CommunityVersion()
	local data = self:CommunityData()
	if data.words[version] == true then return "already", 0 end
	local expected = ns.COMMUNITY_WORDS[version]
	if not expected then return "none", 0 end
	if ns.CommunityWordNormalize(word) == "" then return "empty", 0 end
	if ns.CommunityWordHash(version, word) ~= expected then return "wrong", 0 end
	data.words[version] = true
	if type(self.TallyAdd) == "function" then pcall(self.TallyAdd, self, "discordWord") end
	local gift = 0
	if WordCount(data) >= 2 and type(self.PaillettesAdd) == "function" then
		gift = ns.COMMUNITY_WORD_PAILLETTES
		self:PaillettesAdd(gift, "discord")
	end
	return "ok", gift
end

-- ---------------------------------------------------------------------------
-- Ton avis : réponses (session seulement), texte composé, diagnostic
-- ---------------------------------------------------------------------------
local session = { answers = {}, free = "" }
ns.communitySession = session

function ns:CommunityAnswer(question, index)
	session.answers[question] = tonumber(index)
end
function ns:CommunitySetFree(text)
	text = tostring(text or "")
	if #text > ns.COMMUNITY_FREE_MAX then text = text:sub(1, ns.COMMUNITY_FREE_MAX) end
	session.free = text
end
function ns:CommunityResetAnswers()
	session.answers, session.free, session.mode = {}, "", nil
end

local function Trim(text) return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function ns:CommunityCanCompose()
	for _, q in ipairs(ns.COMMUNITY_QUESTIONS) do if session.answers[q.id] then return true end end
	return Trim(session.free) ~= ""
end

local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return ns.Plain(a), ns.Plain(b), ns.Plain(c) end
	return nil
end

-- ce que le texte cite : langue, niveau, espèces capturées, jours ensemble
function ns:CommunityContext()
	local locale = Call("GetLocale") or "frFR"
	local level = tonumber((Call("UnitLevel", "player"))) or 1
	local species = 0
	if self.CaptureData then
		local ok, data = pcall(self.CaptureData, self)
		species = ok and type(data) == "table" and tonumber(data.count) or 0
	end
	local days = 1
	if self.CompanionDaysTogether then
		local ok, value = pcall(self.CompanionDaysTogether, self)
		days = ok and tonumber(value) or 1
	end
	return { version = tostring(ns.version or "?"), language = LANGUAGES[locale] or tostring(locale),
		level = math.max(1, math.floor(level)), species = math.max(0, math.floor(species)), days = math.max(1, math.floor(days)) }
end

function ns:CommunityJoinedLine()
	local c = self:CommunityContext()
	return self:F("COM_JOINED", table.concat({ self:F("COM_ADDON", c.version), c.language, self:F("COM_LEVEL", c.level),
		self:FP("COM_SPECIES", c.species), self:FP("COM_DAYS_TOGETHER", c.days) }, " · "))
end

-- l'avis, prêt à coller : titre en gras Discord et contexte, « Ressenti »
-- (les questions répondues seulement), le texte libre. nil : rien à dire.
function ns:CommunityCompose()
	if not self:CommunityCanCompose() then return nil end
	local c = self:CommunityContext()
	local lines = { self:F("COM_OUT_HEAD", c.version, table.concat({ c.language, self:F("COM_LEVEL", c.level),
		self:FP("COM_SPECIES", c.species), self:FP("COM_DAYS", c.days) }, ", ")) }
	local feel = {}
	for _, q in ipairs(ns.COMMUNITY_QUESTIONS) do
		local pick = session.answers[q.id]
		if pick then feel[#feel + 1] = L["COM_OUT_" .. q.id .. "_" .. pick] end
	end
	if #feel > 0 then lines[#lines + 1] = self:F("COM_OUT_FEEL", table.concat(feel, " · ")) end
	local free = Trim(session.free)
	if free ~= "" then lines[#lines + 1] = free end
	return table.concat(lines, "\n")
end

-- texte brut d'une ligne de chat (couleurs, retours, textures retirés)
local function Plain(text)
	text = tostring(text or "")
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", "\n"):gsub("|T.-|t", ""):gsub("|H.-|h", ""):gsub("|h", "")
	return text
end

-- le diagnostic : une ligne de contexte (version, client, langue, classe et
-- niveau, Ready2Quest), puis ce que /qc diag écrit dans le chat (client,
-- capacités, socle, modules, erreurs, actions refusées par le jeu, bestiaire),
-- recueilli sans rien écrire dans le chat
function ns:CommunityDiagText()
	local c = self:CommunityContext()
	local info, flavour
	if self.BuildInfo then
		local ok, value = pcall(self.BuildInfo, self)
		info = ok and type(value) == "table" and value or nil
	end
	if self.ClientFlavour then
		local ok, value = pcall(self.ClientFlavour, self)
		flavour = ok and value or nil
	end
	local client = self:F("COM_DIAG_CLIENT", tostring(flavour or "?") .. (type(info) == "table" and info.version and (" " .. tostring(info.version)) or ""),
		tostring(type(info) == "table" and info.toc or "?"))
	local className = Call("UnitClass", "player")
	local r2q, version = "missing", nil
	if self.AddonsR2QStatus then
		local ok, status, v = pcall(self.AddonsR2QStatus, self)
		if ok then r2q, version = status, v end
	end
	local r2qText = r2q == "loaded" and self:F("COM_DIAG_R2Q_ON", tostring(version or "?"))
		or (r2q == "disabled" and L.COM_DIAG_R2Q_OFF or L.COM_DIAG_R2Q_NONE)
	local lines = { self:F("COM_DIAG_HEAD", c.version, table.concat({ client, c.language,
		self:F("COM_DIAG_CLASS", tostring(className or "?"), c.level), r2qText }, ", ")) }
	local print = rawget(self, "Print")
	self.Print = function(_, ...)
		local parts = {}
		for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
		lines[#lines + 1] = Plain(table.concat(parts, " "))
	end
	local ok, err = pcall(self.HandleCommand, self, "diag")
	self.Print = print
	if not ok and self.RecordError then self:RecordError("community:diag", err) end
	return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
local function Paint(region, color)
	if region and region.SetTextColor then region:SetTextColor(color[1], color[2], color[3], 1) end
end

-- un texte de la page, rangé avec le fond qu'il a dessous (contrastes mesurés)
local function Label(pane, parent, font, color, width, ground)
	local text = Theme.Text(parent, font, color)
	text:SetJustifyH("LEFT")
	if width then text:SetWidth(width) end
	text.comGround = ground or "page"
	text.comInk = color
	pane.texts[#pane.texts + 1] = text
	return text
end
local function Recolor(text, color)
	text.comInk = color
	Paint(text, color)
end

local function Place(region, parent, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
	return region
end

-- champ du lien : lecture seule, tout sélectionné au clic (JournalAddons.lua)
local function LinkBox(parent, width, url)
	local box = Theme.CreateSearchBox(parent, width, "", nil)
	if box.SetMaxLetters then box:SetMaxLetters(200) end
	ns.CopyBoxLock(box, url)
	box:SetScript("OnTextChanged", function(self)
		if self:GetText() ~= self.copyURL then ns.CopyBoxLock(self, self.copyURL) end
		if self.Refresh then self:Refresh() end
	end)
	box:SetScript("OnEditFocusGained", function(self)
		if self.HighlightText then self:HighlightText() end
	end)
	box:SetScript("OnMouseUp", function(self)
		if self.SetFocus then self:SetFocus() end
		if self.HighlightText then self:HighlightText() end
	end)
	-- le lien se voit : filet doré clair, au repos comme au focus
	local edge = Theme.GOLD_LIGHT
	if box.inset then box.inset:SetColor(edge[1], edge[2], edge[3], 1)
	elseif box.border then box.border:SetColor(edge[1], edge[2], edge[3], 1) end
	box:SetScript("OnEditFocusLost", function() end)
	return box
end

-- zone de texte sur plusieurs lignes : creux du thème, défilement à la
-- molette, focus au clic seulement. opts = { readOnly, maxLetters,
-- placeholder, onChange(text) }
local function Area(pane, parent, width, height, opts)
	opts = opts or {}
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, height)
	holder.bg = Theme.Solid(holder, "BACKGROUND", Theme.FIELD, 1)
	holder.bg:SetAllPoints()
	holder.border = Theme.Border(holder, Theme.EDGE, 1)
	if Theme.Forged() then
		holder.bg:SetVertexColor(Theme.FIELD[1], Theme.FIELD[2], Theme.FIELD[3], 0)
		holder.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 0)
		holder.inset = Theme.ForgeSlice(holder, "inset", Theme.EDGE)
	end
	local scroll = CreateFrame("ScrollFrame", nil, holder)
	scroll:SetPoint("TOPLEFT", holder, "TOPLEFT", 9, -7)
	scroll:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -9, 7)
	if scroll.EnableMouseWheel then scroll:EnableMouseWheel(true) end
	local edit = CreateFrame("EditBox", nil, scroll)
	if edit.SetMultiLine then edit:SetMultiLine(true) end
	if edit.SetAutoFocus then edit:SetAutoFocus(false) end
	edit:SetFontObject(opts.font or Theme.F_BODY)
	edit:SetWidth(width - 18)
	edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
	if edit.SetMaxLetters then edit:SetMaxLetters(opts.maxLetters or 4000) end
	if edit.SetTextColor then edit:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3], 1) end
	edit.comGround, edit.comInk = "field", Theme.TEXT
	pane.texts[#pane.texts + 1] = edit
	if scroll.SetScrollChild then scroll:SetScrollChild(edit) end
	holder.placeholder = Label(pane, holder, Theme.F_BODY, Theme.MUTED, width - 18, "field")
	holder.placeholder:SetPoint("TOPLEFT", holder, "TOPLEFT", 9, -7)
	holder.placeholder:SetText(opts.placeholder or "")
	holder.scroll, holder.edit = scroll, edit

	local function Scroll(value)
		if not (scroll.SetVerticalScroll and scroll.GetHeight) then return end
		local max = math.max(0, (tonumber(edit:GetHeight()) or 0) - (tonumber(scroll:GetHeight()) or 0))
		scroll:SetVerticalScroll(math.min(math.max(value, 0), max))
	end
	function holder:SetText(text)
		self.value = tostring(text or "")
		edit:SetText(self.value)
		if edit.SetCursorPosition then edit:SetCursorPosition(0) end
		Scroll(0)
		self:Refresh()
	end
	function holder:GetText() return edit:GetText() or "" end
	function holder:Refresh()
		if (edit:GetText() or "") == "" then self.placeholder:Show() else self.placeholder:Hide() end
	end
	-- copier : focus et tout sélectionné (le joueur fait Ctrl+C)
	function holder:Select()
		if edit.SetFocus then edit:SetFocus() end
		if edit.HighlightText then edit:HighlightText() end
	end
	function holder:Release()
		if edit.ClearFocus then edit:ClearFocus() end
	end
	edit:SetScript("OnTextChanged", function(self, userInput)
		if opts.readOnly then
			if userInput and (self:GetText() or "") ~= (holder.value or "") then self:SetText(holder.value or "") end
			if userInput and self.HighlightText then self:HighlightText() end
		elseif opts.onChange then
			opts.onChange(self:GetText() or "")
		end
		holder:Refresh()
	end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEditFocusGained", function(self)
		if holder.inset then holder.inset:SetColor(Theme.ACTIVE[1], Theme.ACTIVE[2], Theme.ACTIVE[3], 1)
		else holder.border:SetColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1) end
		if opts.readOnly and self.HighlightText then self:HighlightText() end
	end)
	edit:SetScript("OnEditFocusLost", function()
		if holder.inset then holder.inset:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1)
		else holder.border:SetColor(Theme.EDGE[1], Theme.EDGE[2], Theme.EDGE[3], 1) end
	end)
	edit:SetScript("OnCursorChanged", function(_, _, y, _, h)
		if not (scroll.GetVerticalScroll and scroll.GetHeight) then return end
		local top, size = -(tonumber(y) or 0), tonumber(h) or 0
		local current, view = tonumber(scroll:GetVerticalScroll()) or 0, tonumber(scroll:GetHeight()) or 0
		if top < current then Scroll(top) elseif top + size > current + view then Scroll(top + size - view) end
	end)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		local current = scroll.GetVerticalScroll and tonumber(scroll:GetVerticalScroll()) or 0
		Scroll(current - (tonumber(delta) or 0) * 30)
	end)
	-- un clic dans le creux (hors du texte) : le focus, et tout sélectionné en lecture seule
	holder:EnableMouse(true)
	holder:SetScript("OnMouseDown", function()
		if opts.readOnly then holder:Select() elseif edit.SetFocus then edit:SetFocus() end
	end)
	holder.value = ""
	holder:Refresh()
	pane.edits[#pane.edits + 1] = edit
	return holder
end

-- intertitre : la cote de la maquette est le haut de son texte (10 px) ; la
-- brique a 20 px de haut, texte centré
local SECTION_LIFT = 5
local function Section(pane, parent, key, x, y, width)
	local section = Theme.CreateSection(parent, L[key])
	Place(section, parent, x, y - SECTION_LIFT)
	section:SetWidth(width)
	section.comKey = key
	pane.sections[#pane.sections + 1] = section
	return section
end

local function BuildDiscord(self, pane, view)
	local W = ns.JournalUI.INNER
	-- tuile de tête : le serveur et l'invitation
	local head = Theme.CreateTile(view, W, LAY.headH, { kind = "Frame", accent = false })
	Place(head, view, 0, LAY.headY)
	head:SetSelected(true)
	view.head = head
	head.title = Label(pane, head, Theme.F_HEADING, Theme.PARCHMENT, W - 24, "tile")
	Place(head.title, head, 12, LAY.headTitleY)
	head.title:SetText(L.COM_DISCORD_TITLE)
	if head.title.SetWordWrap then head.title:SetWordWrap(false) end
	head.text = Label(pane, head, Theme.F_SMALL, Theme.MUTED_LIGHT, W - 24, "tile")
	Place(head.text, head, 12, LAY.headTextY)
	head.text:SetText(L.COM_DISCORD_TEXT)
	head.link = LinkBox(head, LAY.linkW, ns.COMMUNITY_INVITE)
	Place(head.link, head, 12, LAY.linkY)
	head.link.comGround, head.link.comInk = "field", Theme.LABEL
	pane.texts[#pane.texts + 1] = head.link
	pane.edits[#pane.edits + 1] = head.link
	head.hint = Label(pane, head, Theme.F_SMALL, Theme.MUTED, W - LAY.hintX - 12, "tile")
	Place(head.hint, head, LAY.hintX, LAY.hintY)
	head.hint:SetText(L.COM_DISCORD_HINT)

	-- les salons
	Section(pane, view, "COM_SALONS_HEAD", 0, LAY.salonsHeadY, W)
	view.salons = {}
	for _, salon in ipairs(ns.COMMUNITY_SALONS) do
		if salon.open ~= false then
			local index = #view.salons
			local tile = Theme.CreateTile(view, LAY.salonW, LAY.salonH, { kind = "Frame", accent = false })
			Place(tile, view, (index % 2) * LAY.salonX2, LAY.salonY + math.floor(index / 2) * LAY.salonStep)
			tile.salon = salon
			tile.name = Label(pane, tile, Theme.F_LABEL, Theme.ARCANE_LIGHT, LAY.salonW - 20, "tile")
			Place(tile.name, tile, 10, 6)
			tile.name:SetText(salon.name)
			tile.text = Label(pane, tile, Theme.F_SMALL, Theme.MUTED_LIGHT, LAY.salonW - 14, "tile")
			Place(tile.text, tile, 10, 23)
			if tile.text.SetWordWrap then tile.text:SetWordWrap(false) end
			tile.text:SetText(L["COM_SALON_" .. salon.id])
			view.salons[#view.salons + 1] = tile
		end
	end

	-- le mot de la version
	Section(pane, view, "COM_WORD_HEAD", 0, LAY.wordHeadY, LAY.tileW)
	local word = Theme.CreateTile(view, LAY.tileW, LAY.tileH, { kind = "Frame", accent = false })
	Place(word, view, 0, LAY.tileY)
	view.word = word
	word.text = Label(pane, word, Theme.F_SMALL, Theme.MUTED_LIGHT, LAY.tileW - 20, "tile")
	Place(word.text, word, 10, 6)
	word.box = Theme.CreateSearchBox(word, LAY.fieldW, L.COM_WORD_PLACEHOLDER, function() ns:CommunityWordPaint() end)
	if word.box.SetMaxLetters then word.box:SetMaxLetters(40) end
	Place(word.box, word, 10, LAY.fieldY)
	word.box:SetScript("OnEnterPressed", function() ns:CommunityWordClick() end)
	word.box.comGround, word.box.comInk = "field", Theme.LABEL
	word.box.placeholder.comGround, word.box.placeholder.comInk = "field", Theme.MUTED
	pane.texts[#pane.texts + 1] = word.box
	pane.texts[#pane.texts + 1] = word.box.placeholder
	pane.edits[#pane.edits + 1] = word.box
	word.button = Theme.CreateButton(word, LAY.buttonW, "sm", L.COM_WORD_OK, function() ns:CommunityWordClick() end, "outline")
	Place(word.button, word, LAY.buttonX, LAY.fieldY)

	-- cette semaine (l'étape 4 y posera la créature de la semaine)
	Section(pane, view, "COM_WEEK_HEAD", LAY.salonX2, LAY.wordHeadY, LAY.tileW)
	local week = Theme.CreateTile(view, LAY.tileW, LAY.tileH, { kind = "Frame", accent = false })
	Place(week, view, LAY.salonX2, LAY.tileY)
	view.week = week
	week.title = Label(pane, week, Theme.F_LABEL, Theme.PARCHMENT, LAY.tileW - 20, "tile")
	Place(week.title, week, 10, 8)
	week.title:SetText(L.COM_WEEK_TITLE)
	week.text = Label(pane, week, Theme.F_SMALL, Theme.MUTED_LIGHT, LAY.tileW - 20, "tile")
	Place(week.text, week, 10, 25)
	week.text:SetText(L.COM_WEEK_TEXT)

	view.note = Label(pane, view, Theme.F_SMALL, Theme.MUTED, W, "page")
	Place(view.note, view, 0, LAY.discordNoteY)
	view.note:SetText(L.COM_DISCORD_NOTE)
end

-- puces resserrées comme la maquette (10 px de part et d'autre du mot) ;
-- `maxWidth` : la rangée tient dans cette largeur (marge réduite jusqu'à 5)
local CHIP_PAD, CHIP_PAD_MIN = 20, 10
local function Tighten(row, gap, maxWidth)
	local widths, total = {}, 0
	for i, chip in ipairs(row.chips) do
		widths[i] = math.ceil(tonumber(chip.text:GetStringWidth()) or 0)
		total = total + widths[i]
	end
	local n = #row.chips
	local pad = CHIP_PAD
	if maxWidth and n > 0 and total + n * pad + (n - 1) * gap > maxWidth then
		pad = math.max(CHIP_PAD_MIN, math.floor((maxWidth - total - (n - 1) * gap) / n))
	end
	local x = 0
	for i, chip in ipairs(row.chips) do
		chip:SetWidth(widths[i] + pad)
		chip:ClearAllPoints()
		chip:SetPoint("LEFT", row, "LEFT", x, 0)
		x = x + widths[i] + pad + gap
	end
	row.used = math.max(0, x - gap)
	row:SetWidth(math.max(1, row.used))
	return row.used
end
ns.CommunityTightenChips = Tighten

-- une rangée de puces à choix unique, rien de choisi au départ
local NONE = "none"
local function QuestionRow(pane, view, q, y)
	local label = Label(pane, view, Theme.F_BODY, Theme.LABEL, LAY.qLabelW, "page")
	Place(label, view, 0, y + 4)
	if label.SetWordWrap then label:SetWordWrap(false) end
	label:SetText(L["COM_Q_" .. q.id])
	local defs = {}
	for i = 1, q.answers do defs[i] = { id = i, label = L["COM_A_" .. q.id .. "_" .. i] } end
	local row = Theme.CreateChips(view, defs, function(id)
		ns:CommunityAnswer(q.id, id)
		ns:CommunityAvisPaint()
	end, { height = LAY.chipH, gap = 4 })
	-- aucune réponse d'office : une entrée « personne » que Select accepte
	-- (les puces peintes, aucune choisie)
	row.byId[NONE] = row
	row:Select(NONE, true)
	-- la rangée s'arrête avant la colonne de droite (« Vos idées »)
	Tighten(row, 4, LAY.ideasX - 10 - LAY.qLabelW - 4)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", view, "TOPLEFT", LAY.qLabelW + 4, -y)
	row.question, row.label = q, label
	for _, chip in ipairs(row.chips) do
		chip.text.comGround, chip.text.comInk = "chip", Theme.MUTED_LIGHT
		pane.texts[#pane.texts + 1] = chip.text
	end
	return row
end

local function BuildAvis(self, pane, view)
	local W = ns.JournalUI.INNER
	view.intro = Label(pane, view, Theme.F_SMALL, Theme.MUTED_LIGHT, W, "page")
	Place(view.intro, view, 0, LAY.introY)
	view.intro:SetText(L.COM_AVIS_INTRO)

	Section(pane, view, "COM_FEEL_HEAD", 0, LAY.feelHeadY, LAY.colW)
	view.questions = {}
	for index, q in ipairs(ns.COMMUNITY_QUESTIONS) do
		view.questions[q.id] = QuestionRow(pane, view, q, LAY.qY + (index - 1) * LAY.qStep)
		view.questions[index] = view.questions[q.id]
	end

	Section(pane, view, "COM_FREE_HEAD", 0, LAY.freeHeadY, LAY.colW)
	view.free = Area(pane, view, LAY.colW, LAY.freeH, { maxLetters = ns.COMMUNITY_FREE_MAX, placeholder = L.COM_FREE_PLACEHOLDER,
		onChange = function(text)
			ns:CommunitySetFree(text)
			ns:CommunityAvisPaint()
		end })
	Place(view.free, view, 0, LAY.freeY)

	view.joined = Label(pane, view, Theme.F_SMALL, Theme.MUTED, W, "page")
	Place(view.joined, view, 0, LAY.joinedY)
	if view.joined.SetWordWrap then view.joined:SetWordWrap(false) end

	view.compose = Theme.CreateButton(view, "auto", "sm", L.COM_COMPOSE, function() ns:CommunityComposeClick() end, "primary")
	Place(view.compose, view, 0, LAY.buttonsY)
	view.diag = Theme.CreateButton(view, "auto", "sm", L.COM_DIAG, function() ns:CommunityDiagClick() end, "outline")
	view.diag:ClearAllPoints()
	view.diag:SetPoint("LEFT", view.compose, "RIGHT", 6, 0)

	-- colonne de droite : vos idées
	Section(pane, view, "COM_IDEAS_HEAD", LAY.ideasX, LAY.feelHeadY, LAY.ideasW)
	view.ideas = {}
	for index = 1, #IDEAS do
		local y = LAY.ideasY + (index - 1) * LAY.ideaStep
		local title = Label(pane, view, Theme.F_BODY, Theme.PARCHMENT, LAY.ideasW, "page")
		Place(title, view, LAY.ideasX, y)
		if title.SetWordWrap then title:SetWordWrap(false) end
		title:SetText(L["COM_IDEA_" .. index])
		local source = Label(pane, view, Theme.F_SMALL, Theme.MUTED_LIGHT, LAY.ideasW, "page")
		Place(source, view, LAY.ideasX, y + 16)
		if source.SetWordWrap then source:SetWordWrap(false) end
		source:SetText(L["COM_IDEA_" .. index .. "_SRC"])
		view.ideas[index] = { title = title, source = source }
	end
	view.ideasNote = Label(pane, view, Theme.F_SMALL, Theme.MUTED, LAY.ideasW, "page")
	Place(view.ideasNote, view, LAY.ideasX, LAY.ideasNoteY)
	view.ideasNote:SetText(L.COM_IDEAS_NOTE)

	-- la zone à copier
	view.copyHead = Section(pane, view, "COM_COPY_HEAD_AVIS", 0, LAY.copyHeadY, W)
	view.copy = Area(pane, view, W, LAY.copyH, { readOnly = true, font = Theme.F_SMALL, placeholder = L.COM_COPY_EMPTY })
	Place(view.copy, view, 0, LAY.copyY)

	view.note = Label(pane, view, Theme.F_SMALL, Theme.MUTED, W, "page")
	Place(view.note, view, 0, LAY.avisNoteY)
	view.note:SetText(L.COM_AVIS_NOTE)
end

local function Build(self, frame, content, ui)
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.community = pane
	pane.texts, pane.edits, pane.sections = {}, {}, {}
	-- l'origine du contenu de la page (cotes de la maquette)
	local body = CreateFrame("Frame", nil, pane)
	body:SetSize(ui.INNER, -(ui.PAGER_Y - ui.TOP) + 24)
	body:SetPoint("TOPLEFT", content, "TOPLEFT", ui.PAD, ui.TOP)
	pane.body = body

	-- onglets et phrase de l'onglet
	local defs = {}
	for i, id in ipairs(ns.COMMUNITY_TABS) do defs[i] = { id = id, label = L["COM_TAB_" .. id] } end
	pane.tabs = Theme.CreateChips(body, defs, function(id) ns:CommunitySelectTab(id) end,
		{ height = LAY.tabH, gap = LAY.tabGap, selected = ns.COMMUNITY_TAB_DEFAULT })
	Tighten(pane.tabs, LAY.tabGap)
	pane.tabs:ClearAllPoints()
	pane.tabs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -LAY.tabsY)
	for _, chip in ipairs(pane.tabs.chips) do
		chip.text.comGround, chip.text.comInk = "chip", Theme.MUTED_LIGHT
		pane.texts[#pane.texts + 1] = chip.text
	end
	pane.tabNote = Label(pane, body, Theme.F_SMALL, Theme.MUTED_LIGHT, nil, "page")
	pane.tabNote:SetPoint("RIGHT", body, "TOPRIGHT", 0, -LAY.tabsY - LAY.tabH / 2)
	pane.tabNote:SetJustifyH("RIGHT")

	pane.views = {}
	for _, id in ipairs(ns.COMMUNITY_TABS) do
		local view = CreateFrame("Frame", nil, body)
		view:SetAllPoints(body)
		view:Hide()
		pane.views[id] = view
	end
	BuildDiscord(self, pane, pane.views.discord)
	BuildAvis(self, pane, pane.views.avis)
	pane.tab = ns.COMMUNITY_TAB_DEFAULT

	-- page quittée (autre page, carnet fermé) : le clavier rendu au jeu
	pane:SetScript("OnHide", function() ns:CommunityReleaseKeyboard() end)

	-- la pastille de la colonne : à droite du mot, tant que la page n'a jamais été ouverte
	local item = frame.sections and frame.sections.community
	if item then
		local dot = Theme.ArtTexture(item, "dot", "OVERLAY", 1, Theme.GOLD_LIGHT, 1)
		-- le point lumineux des intertitres, plus grand : un cœur plein de 6 px
		-- environ (le sixième de la texture) dans sa lueur, centré à 12 px du mot
		dot:SetSize(NAV_DOT.size, NAV_DOT.size)
		dot:SetPoint("CENTER", item.label, "RIGHT", NAV_DOT.x, 0)
		item.newDot = dot
		if self:CommunitySeen() then dot:Hide() else dot:Show() end
	end
	pane:Hide()
end

-- ---------------------------------------------------------------------------
-- États et actions
-- ---------------------------------------------------------------------------
local function Pane(self)
	local frame = self.journalFrame
	return frame and frame.community
end

function ns:CommunityReleaseKeyboard()
	local pane = Pane(self)
	if not pane then return end
	for _, edit in ipairs(pane.edits) do
		if edit.ClearFocus then edit:ClearFocus() end
	end
end

function ns:CommunityWordPaint()
	local pane = Pane(self)
	local view = pane and pane.views.discord
	if not view then return end
	local word = view.word
	local version = self:CommunityVersion()
	local done = self:CommunityWordDone(version)
	local state = pane.wordState
	local text, color = L.COM_WORD_TEXT, Theme.MUTED_LIGHT
	if done then
		text = pane.wordGift and pane.wordGift > 0 and self:F("COM_WORD_DONE_MORE", version, pane.wordGift)
			or (state == "ok" and self:F("COM_WORD_DONE_FIRST", version) or self:F("COM_WORD_ALREADY", version))
		color = Theme.GREEN
	elseif state == "wrong" then
		text, color = L.COM_WORD_WRONG, Theme.LABEL
	elseif state == "none" then
		text, color = self:F("COM_WORD_NONE", version), Theme.LABEL
	end
	word.text:SetText(text)
	Recolor(word.text, color)
	local typed = ns.CommunityWordNormalize(word.box:GetText()) ~= ""
	if done then
		word.box:Hide(); word.button:Hide()
	else
		word.box:Show(); word.button:Show()
		if word.button.SetInactive then word.button:SetInactive(not typed) end
	end
end

function ns:CommunityWordClick()
	local pane = Pane(self)
	local view = pane and pane.views.discord
	if not view then return nil end
	local state, gift = self:CommunityWordSubmit(view.word.box:GetText())
	if state == "empty" then return state end
	pane.wordState, pane.wordGift = state, gift
	if state == "ok" then
		view.word.box:SetText("")
		if view.word.box.ClearFocus then view.word.box:ClearFocus() end
	end
	self:CommunityWordPaint()
	return state, gift
end

function ns:CommunityAvisPaint()
	local pane = Pane(self)
	local view = pane and pane.views.avis
	if not view then return end
	for _, q in ipairs(ns.COMMUNITY_QUESTIONS) do
		local row = view.questions[q.id]
		local pick = session.answers[q.id]
		if row and row.selected ~= (pick or NONE) then row:Select(pick or NONE, true) end
		if row then
			for _, chip in ipairs(row.chips) do chip.text.comInk = chip.id == pick and Theme.PARCHMENT or Theme.MUTED_LIGHT end
		end
	end
	if (view.free:GetText() or "") ~= session.free then view.free:SetText(session.free) end
	view.joined:SetText(self:CommunityJoinedLine())
	local can = self:CommunityCanCompose()
	if view.compose.SetInactive then view.compose:SetInactive(not can, L.COM_COMPOSE_TIP) end
	-- la zone à copier montre l'avis tel qu'il partira (sauf le diagnostic demandé)
	if session.mode ~= "diag" then
		view.copyHead:SetText(L.COM_COPY_HEAD_AVIS)
		view.copy:SetText(self:CommunityCompose() or "")
	end
end

-- « Composer et copier » : l'avis dans la zone à copier, tout sélectionné
function ns:CommunityComposeClick()
	local pane = Pane(self)
	local view = pane and pane.views.avis
	local text = self:CommunityCompose()
	if not (view and text) then return nil end
	session.mode = "avis"
	view.copyHead:SetText(L.COM_COPY_HEAD_AVIS)
	view.copy:SetText(text)
	view.copy:Select()
	-- le premier avis composé sur le compte (compteur des hauts faits, s'il existe)
	if type(self.TallyAdd) == "function" then
		local first = true
		if type(self.TallyGet) == "function" then
			local ok, n = pcall(self.TallyGet, self, "feedback")
			first = not (ok and (tonumber(n) or 0) > 0)
		end
		if first then pcall(self.TallyAdd, self, "feedback") end
	end
	return text
end

function ns:CommunityDiagClick()
	local pane = Pane(self)
	local view = pane and pane.views.avis
	if not view then return nil end
	local text = self:CommunityDiagText()
	session.mode = "diag"
	view.copyHead:SetText(L.COM_COPY_HEAD_DIAG)
	view.copy:SetText(text)
	view.copy:Select()
	return text
end

function ns:CommunitySelectTab(id)
	local pane = Pane(self)
	if not (pane and pane.views[id]) then return false end
	self:CommunityReleaseKeyboard()
	pane.tab = id
	if pane.tabs.selected ~= id then pane.tabs:Select(id, true) end
	for key, view in pairs(pane.views) do if key == id then view:Show() else view:Hide() end end
	for _, chip in ipairs(pane.tabs.chips) do chip.text.comInk = chip.id == id and Theme.PARCHMENT or Theme.MUTED_LIGHT end
	pane.tabNote:SetText(L["COM_TAB_NOTE_" .. id] or "")
	if id == "avis" then
		-- l'astuce « Ton avis » n'a plus lieu d'être
		if self.DiscoveryUse then pcall(self.DiscoveryUse, self, "community_avis") end
		self:CommunityAvisPaint()
	else
		self:CommunityWordPaint()
	end
	return true
end

local function Refresh(self, frame)
	local pane = frame.community
	if not pane then return end
	-- première ouverture : la pastille s'éteint pour de bon (au compte)
	local data = self:CommunityData()
	data.seen = true
	local item = frame.sections and frame.sections.community
	if item and item.newDot then item.newDot:Hide() end
	self:CommunitySelectTab(pane.tab or ns.COMMUNITY_TAB_DEFAULT)
end

-- /qc … ou une astuce : le carnet sur la page, l'onglet voulu
function ns:CommunityOpen(tab)
	if not self.ToggleJournal then return nil end
	local frame = self:ToggleJournal(true)
	if not frame then return nil end
	self:SelectJournalKind("community")
	if tab and frame.community then self:CommunitySelectTab(tab) end
	return frame
end

ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.community = {
	field = "community", title = "JRN_SEC_community", subtitle = "JRN_SUB_community",
	build = Build, refresh = Refresh,
}

-- ---------------------------------------------------------------------------
-- Astuces du compagnon : deux de plus dans la rotation de Discovery.lua (une
-- fois par compte chacune, même créneau, mêmes règles), avec une condition de
-- jour de jeu du compte ; la seconde jamais le jour où la première a été dite.
-- Discovery.lua se charge après ce fichier : posées au premier besoin.
-- ---------------------------------------------------------------------------
local function Today()
	local now = tonumber((Call("time"))) or 0
	return math.floor(now / 86400)
end

-- le premier jour de jeu du compte : le plus ancien compagnon de ses
-- personnages (CompanionData().since) ; à défaut, aujourd'hui
function ns:CommunityAccountDay()
	local db = self:DB()
	local first
	for _, char in pairs(type(db.chars) == "table" and db.chars or {}) do
		local since = type(char) == "table" and type(char.companion) == "table" and tonumber(char.companion.since)
		if since and since > 0 and (not first or since < first) then first = since end
	end
	local today = Today()
	-- aucun encore : le compteur « jours ensemble » de ce personnage part d'aujourd'hui
	if not first and self.CompanionSince then
		local ok, since = pcall(self.CompanionSince, self)
		first = ok and tonumber(since) and tonumber(since) > 0 and tonumber(since) or nil
	end
	if not first then return 1 end
	return math.max(1, today - math.floor(first / 86400) + 1)
end

local function TipDayOK(self, id)
	return self:CommunityAccountDay() >= (ns.COMMUNITY_TIP_DAYS[id] or 1)
end
local function SeenDay(self, id)
	local data = self.DiscoveryData and self:DiscoveryData()
	return data and type(data.seenDay) == "table" and data.seenDay[id] or nil
end
local function Used(self, key)
	local data = self.DiscoveryData and self:DiscoveryData()
	return data and data.used and data.used[key] == true or false
end

ns.COMMUNITY_DISCOVERY = {
	{ id = "community", line = "DISC_community", after = "guide",
		learned = function(self) return Used(self, "page_community") or self:CommunitySeen() end,
		eligible = function(self) return TipDayOK(self, "community") end,
		open = function(self) self:CommunityOpen("discord") end },
	{ id = "communityAvis", line = "DISC_communityAvis", after = "community",
		learned = function(self) return Used(self, "community_avis") end,
		eligible = function(self)
			if not TipDayOK(self, "communityAvis") then return false end
			local first = SeenDay(self, "community")
			return first == nil or first ~= Today()
		end,
		open = function(self) self:CommunityOpen("avis") end },
}

function ns:CommunityTipsInstall()
	local list, byId = ns.DISCOVERY_TIPS, ns.DISCOVERY_BY_ID
	if type(list) ~= "table" or type(byId) ~= "table" then return false end
	for _, tip in ipairs(ns.COMMUNITY_DISCOVERY) do
		if not byId[tip.id] then
			local at = #list + 1
			for index, other in ipairs(list) do if other.id == tip.after then at = index + 1 end end
			table.insert(list, at, tip)
			byId[tip.id] = tip
		end
	end
	-- le jour où chaque astuce de la page a été dite (au compte, avec les astuces)
	if not ns.communityShownHooked and type(ns.DiscoveryShown) == "function" then
		ns.communityShownHooked = true
		local base = ns.DiscoveryShown
		function ns:DiscoveryShown(tip, ...)
			local result = base(self, tip, ...)
			if type(tip) == "table" and ns.COMMUNITY_TIP_DAYS[tip.id] then
				local data = self:DiscoveryData()
				if type(data.seenDay) ~= "table" then data.seenDay = {} end
				data.seenDay[tip.id] = Today()
			end
			return result
		end
	end
	return true
end

do
	local base = ns.CompanionTryTip
	if base then
		function ns:CompanionTryTip(...)
			if not ns.communityTipsReady then ns.communityTipsReady = self:CommunityTipsInstall() end
			return base(self, ...)
		end
	end
end
if ns.On then
	ns.On("PLAYER_ENTERING_WORLD", "community", function()
		if not ns.communityTipsReady then ns.communityTipsReady = ns:CommunityTipsInstall() end
	end, "community:PLAYER_ENTERING_WORLD")
end

if ns.Mark then ns.Mark("JournalCommunity") end
