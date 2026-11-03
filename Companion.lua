-- Companion.lua -- module « Compagnon de route » (v1.25.0)
--
-- Une petite créature voyage avec le joueur et réagit à son aventure : elle
-- mange quand il mange, se repose à l'auberge ou au feu de camp, se réjouit
-- d'une quête rendue, s'émerveille d'une zone nouvelle. Elle grandit avec le
-- niveau du joueur et débloque des apparences et des ornements au fil des
-- tampons du Carnet de voyage.
--
-- Ton : bienveillant, jamais punitif. Elle ne meurt pas, ne régresse pas,
-- n'est jamais « malade ». Ses besoins sont cosmétiques : ils baissent
-- doucement pendant le jeu seulement, jamais sous un plancher, et une longue
-- absence la rend juste somnolente au retour (« Tu m'as manqué ! »). Aucune
-- culpabilité : on ne compte pas les jours d'absence contre le joueur.
--
-- Contrat avec le Carnet de voyage (autre module, peut être absent) :
--   * ns:FireCallback("STAMP", { id, kind, name, new }) à chaque tampon ;
--   * ns:JournalCounts() -> { zone, subzone, dungeon, rare, level, total }.
-- Sans lui, tout marche : les compteurs valent zéro, seules les conditions
-- de niveau débloquent des cosmétiques.
--
-- Modèle 3D : CreateFrame("PlayerModel") + SetDisplayInfo (numéros vérifiés
-- dans les deux clients, voir CompanionData.lua). Si l'API manque, la
-- boussole de l'addon prend la place : le compagnon reste là, sans modèle.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local NEED_KEYS  = { "hunger", "energy", "mood", "curiosity" }
local NEED_MAX   = 100
local NEED_FLOOR = 15        -- plancher : jamais vide, jamais « en détresse »
local NEED_START = 80
-- baisse par minute de JEU (rien hors connexion)
local DECAY = { hunger = 0.6, energy = 0.4, mood = 0.3, curiosity = 0.5 }
local REST_GAIN   = 4        -- énergie par minute au repos (auberge, ville, camp)
local EAT_GAIN    = 6        -- faim par minute pendant le repas
local TICK        = 10       -- s entre deux mises à jour des besoins
local MAX_STEP    = 60       -- s comptées au plus par image (écran de chargement)
local BUBBLE_GAP  = 20       -- s minimum entre deux bulles ordinaires
local BUBBLE_TIME = 6        -- s d'affichage d'une bulle
local PET_COOLDOWN = 15      -- s entre deux caresses qui comptent
local SLEEPY_AFTER = 2 * 3600  -- absence au-delà de laquelle il somnole
local SLEEPY_MIN, SLEEPY_MAX = 60, 600   -- s de jeu pour se réveiller (plafond)
local SLEEPY_PER_HOUR = 20   -- s de somnolence par heure d'absence
local NAME_MAX = 24

ns.COMPANION_RULES = {
	floor = NEED_FLOOR, max = NEED_MAX, decay = DECAY, restGain = REST_GAIN, bubbleGap = BUBBLE_GAP,
	petCooldown = PET_COOLDOWN, sleepyAfter = SLEEPY_AFTER, sleepyMin = SLEEPY_MIN, sleepyMax = SLEEPY_MAX,
}

-- ---------------------------------------------------------------------------
-- Textes (tutoiement, chaleureux, courts)
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_COMPANION     = "Compagnon de route",
	OPT_PAGE_COMPANION_SUB = "Une petite créature qui voyage avec toi et réagit à ton aventure.",
	OPT_COMP_SHOW          = "Afficher le compagnon",
	OPT_COMP_BUBBLES       = "Bulles de dialogue",
	OPT_COMP_APPEARANCE    = "Apparence (clic pour changer)",
	OPT_COMP_ORNAMENTS     = "ORNEMENTS",
	OPT_COMP_LOCKED        = "%s (à débloquer : %s)",
	COMP_DEFAULT_NAME      = "Brindille",
	COMP_NEED_hunger       = "Faim",
	COMP_NEED_energy       = "Énergie",
	COMP_NEED_mood         = "Moral",
	COMP_NEED_curiosity    = "Curiosité",
	COMP_MOOD_radiant      = "radieux",
	COMP_MOOD_happy        = "content",
	COMP_MOOD_dreamy       = "rêveur",
	COMP_MOOD_sleepy       = "somnolent",
	COMP_STAGE_1           = "Nouveau-né",
	COMP_STAGE_2           = "Jeune",
	COMP_STAGE_3           = "Aguerri",
	COMP_STAGE_4           = "Vaillant",
	COMP_STAGE_5           = "Légendaire",
	COMP_APP_WHELP_GREEN   = "Dragonnet émeraude",
	COMP_APP_FROG          = "Rainette",
	COMP_APP_WHELP_RED     = "Dragonnet cramoisi",
	COMP_APP_OWL           = "Chouette grise",
	COMP_APP_WISP          = "Feu follet",
	COMP_APP_SPRITE        = "Dragon féerique",
	COMP_APP_WHELP_BLUE    = "Dragonnet azur",
	COMP_APP_WHELP_BRONZE  = "Dragonnet de bronze",
	COMP_APP_WHELP_BLACK   = "Dragonnet sombre",
	COMP_ORN_RIBBON        = "Ruban de voyage",
	COMP_ORN_LANTERN       = "Lanterne",
	COMP_ORN_MEDAL         = "Médaille",
	COMP_ORN_GOLD          = "Cadre doré",
	COMP_REQ_LEVEL         = "niveau %d",
	COMP_REQ_zone          = "%d zones",
	COMP_REQ_subzone       = "%d lieux",
	COMP_REQ_dungeon       = "%d donjons",
	COMP_REQ_rare          = "%d rares",
	COMP_REQ_level         = "%d tampons de niveau",
	COMP_REQ_total         = "%d tampons",
	COMP_HOVER_HINT        = "Clic : un câlin · glisser : déplacer",
	-- bulles
	COMP_SAY_HELLO         = "Salut ! Moi c'est %s. On part à l'aventure ?",
	COMP_SAY_MISSED        = "Tu m'as manqué ! Zzz… je me réveille doucement.",
	COMP_SAY_AWAKE         = "Me revoilà en pleine forme !",
	COMP_SAY_NOFOOD        = "On part sans rien à grignoter ? Pense à moi au prochain marchand !",
	COMP_SAY_DEPART        = "En route ! J'ai vu le goûter dans ton sac.",
	COMP_SAY_RETURN        = "Ouf, on est rentrés ! Bien joué.",
	COMP_SAY_DEAD          = "Aïe… Je t'attends, prends ton temps.",
	COMP_SAY_LEVEL         = "Niveau %d ! Bravo, toi !",
	COMP_SAY_EVOLVE        = "Je grandis ! Me voilà %s !",
	COMP_SAY_VIEW          = "Quelle vue !",
	COMP_SAY_QUEST         = "Mission accomplie !",
	COMP_SAY_CAMP          = "On se réchauffe ?",
	COMP_SAY_INN           = "Une auberge… petite sieste ?",
	COMP_SAY_EAT           = "Miam ! Merci pour le partage.",
	COMP_SAY_LOOT          = "Oh, ça brille !",
	COMP_SAY_STAMP         = "Un tampon de plus : %s !",
	COMP_SAY_UNLOCK        = "Regarde : %s !",
	COMP_SAY_PET_radiant   = "Youpi ! Encore !",
	COMP_SAY_PET_happy     = "Hihi, ça chatouille !",
	COMP_SAY_PET_dreamy    = "Mmh… merci, ça fait du bien.",
	COMP_SAY_PET_sleepy    = "Hein ? Oh, c'est toi ! Bonjour !",
	-- chat et commandes
	COMP_MSG_UNLOCK_APP    = "Compagnon : nouvelle apparence débloquée, %s. Choisis-la dans les réglages.",
	COMP_MSG_UNLOCK_ORN    = "Compagnon : nouvel ornement débloqué, %s.",
	COMP_MSG_EVOLVE        = "Compagnon : %s devient %s !",
	COMP_MSG_STATUS        = "%s (%s, %s) — %s",
	COMP_MSG_NEEDS         = "Faim %d · Énergie %d · Moral %d · Curiosité %d",
	COMP_MSG_COLLECTION    = "Apparences %d/%d · Ornements %d/%d",
	COMP_MSG_RENAMED       = "Ton compagnon s'appelle maintenant %s.",
	COMP_MSG_NAME_BAD      = "Donne-lui un nom : /r2q compagnon nom <nom>",
	COMP_MSG_OFF           = "Le compagnon est coupé (/r2q module compagnon on).",
	COMP_MSG_APPEARANCE    = "Apparence : %s.",
	COMP_MSG_MUTE          = "Bulles du compagnon : %s.",
	COMP_MSG_FALLBACK      = "Modèle 3D indisponible sur ce client : la boussole le remplace.",
	HELP_COMPANION         = "/r2q compagnon [nom <nom> | caresse | apparence | muet] — ton compagnon de route",
}
local EN = {
	OPT_PAGE_COMPANION     = "Road companion",
	OPT_PAGE_COMPANION_SUB = "A little creature that travels with you and reacts to your adventure.",
	OPT_COMP_SHOW          = "Show the companion",
	OPT_COMP_BUBBLES       = "Speech bubbles",
	OPT_COMP_APPEARANCE    = "Appearance (click to change)",
	OPT_COMP_ORNAMENTS     = "ORNAMENTS",
	OPT_COMP_LOCKED        = "%s (unlock: %s)",
	COMP_DEFAULT_NAME      = "Sprig",
	COMP_NEED_hunger       = "Hunger",
	COMP_NEED_energy       = "Energy",
	COMP_NEED_mood         = "Mood",
	COMP_NEED_curiosity    = "Curiosity",
	COMP_MOOD_radiant      = "radiant",
	COMP_MOOD_happy        = "happy",
	COMP_MOOD_dreamy       = "dreamy",
	COMP_MOOD_sleepy       = "sleepy",
	COMP_STAGE_1           = "Hatchling",
	COMP_STAGE_2           = "Youngling",
	COMP_STAGE_3           = "Seasoned",
	COMP_STAGE_4           = "Valiant",
	COMP_STAGE_5           = "Legendary",
	COMP_APP_WHELP_GREEN   = "Emerald whelpling",
	COMP_APP_FROG          = "Tree frog",
	COMP_APP_WHELP_RED     = "Crimson whelpling",
	COMP_APP_OWL           = "Grey owlet",
	COMP_APP_WISP          = "Wisp",
	COMP_APP_SPRITE        = "Sprite darter",
	COMP_APP_WHELP_BLUE    = "Azure whelpling",
	COMP_APP_WHELP_BRONZE  = "Bronze whelpling",
	COMP_APP_WHELP_BLACK   = "Dark whelpling",
	COMP_ORN_RIBBON        = "Travel ribbon",
	COMP_ORN_LANTERN       = "Lantern",
	COMP_ORN_MEDAL         = "Medal",
	COMP_ORN_GOLD          = "Golden frame",
	COMP_REQ_LEVEL         = "level %d",
	COMP_REQ_zone          = "%d zones",
	COMP_REQ_subzone       = "%d places",
	COMP_REQ_dungeon       = "%d dungeons",
	COMP_REQ_rare          = "%d rares",
	COMP_REQ_level         = "%d level stamps",
	COMP_REQ_total         = "%d stamps",
	COMP_HOVER_HINT        = "Click: a cuddle · drag: move",
	COMP_SAY_HELLO         = "Hi! I'm %s. Off on an adventure?",
	COMP_SAY_MISSED        = "I missed you! Zzz… waking up slowly.",
	COMP_SAY_AWAKE         = "Wide awake again!",
	COMP_SAY_NOFOOD        = "Leaving without a snack? Think of me at the next vendor!",
	COMP_SAY_DEPART        = "Off we go! I saw the snacks in your bag.",
	COMP_SAY_RETURN        = "Phew, we're back! Well done.",
	COMP_SAY_DEAD          = "Ouch… I'll wait for you, take your time.",
	COMP_SAY_LEVEL         = "Level %d! Go you!",
	COMP_SAY_EVOLVE        = "I'm growing! Now I'm %s!",
	COMP_SAY_VIEW          = "What a view!",
	COMP_SAY_QUEST         = "Mission complete!",
	COMP_SAY_CAMP          = "Shall we warm up?",
	COMP_SAY_INN           = "An inn… little nap?",
	COMP_SAY_EAT           = "Yum! Thanks for sharing.",
	COMP_SAY_LOOT          = "Ooh, shiny!",
	COMP_SAY_STAMP         = "One more stamp: %s!",
	COMP_SAY_UNLOCK        = "Look: %s!",
	COMP_SAY_PET_radiant   = "Yay! Again!",
	COMP_SAY_PET_happy     = "Hehe, that tickles!",
	COMP_SAY_PET_dreamy    = "Mmh… thanks, that's nice.",
	COMP_SAY_PET_sleepy    = "Huh? Oh, it's you! Hello!",
	COMP_MSG_UNLOCK_APP    = "Companion: new appearance unlocked, %s. Pick it in the settings.",
	COMP_MSG_UNLOCK_ORN    = "Companion: new ornament unlocked, %s.",
	COMP_MSG_EVOLVE        = "Companion: %s becomes %s!",
	COMP_MSG_STATUS        = "%s (%s, %s) — %s",
	COMP_MSG_NEEDS         = "Hunger %d · Energy %d · Mood %d · Curiosity %d",
	COMP_MSG_COLLECTION    = "Appearances %d/%d · Ornaments %d/%d",
	COMP_MSG_RENAMED       = "Your companion is now called %s.",
	COMP_MSG_NAME_BAD      = "Give it a name: /r2q compagnon nom <name>",
	COMP_MSG_OFF           = "The companion is off (/r2q module compagnon on).",
	COMP_MSG_APPEARANCE    = "Appearance: %s.",
	COMP_MSG_MUTE          = "Companion bubbles: %s.",
	COMP_MSG_FALLBACK      = "3D model unavailable on this client: the compass stands in.",
	HELP_COMPANION         = "/r2q compagnon [nom <name> | caresse | apparence | muet] — your road companion",
}
ns.RegisterStrings(FR, EN)
ns.COMPANION_STRINGS = { fr = FR, en = EN }   -- exposé aux tests (parité fr/en)

ns.RegisterDefaults({
	companionEnabled    = true,
	companionShow       = true,
	companionBubbles    = true,
	companionPoint      = { point = "CENTER", x = 330, y = -170 },
	companionOrnRibbon  = true,
	companionOrnLantern = true,
	companionOrnMedal   = true,
	companionOrnGold    = true,
})

ns.AddOptionPage({
	id = "companion", title = "OPT_PAGE_COMPANION", group = "OPT_GROUP_MODULES", power = "companionEnabled",
	rows = {
		{ key = "companionShow",       label = "OPT_COMP_SHOW",       kind = "bool" },
		{ key = "companionBubbles",    label = "OPT_COMP_BUBBLES",    kind = "bool" },
		{ key = "companionAppearance", label = "OPT_COMP_APPEARANCE", kind = "action" },
		{ header = "OPT_COMP_ORNAMENTS" },
		{ key = "companionOrnRibbon",  label = "COMP_ORN_RIBBON",     kind = "bool" },
		{ key = "companionOrnLantern", label = "COMP_ORN_LANTERN",    kind = "bool" },
		{ key = "companionOrnMedal",   label = "COMP_ORN_MEDAL",      kind = "bool" },
		{ key = "companionOrnGold",    label = "COMP_ORN_GOLD",       kind = "bool" },
	},
})
-- « pet » et « compagnon » : ni un contrôle du check, ni un autre module
ns.RegisterModule({ id = "companion", key = "companionEnabled", label = "OPT_PAGE_COMPANION", aliases = { "compagnon", "pet" } })

if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_QUICK" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_COMPANION")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Lectures défensives
-- ---------------------------------------------------------------------------
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end
local function Method(object, name, ...)
	if type(object) ~= "table" and type(object) ~= "userdata" then return false end
	local fn = object[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, object, ...)
end
local function Clock() return (ns.Now and ns.Now()) or 0 end                 -- temps de jeu (GetTime)
local function Wall() return tonumber(Call(rawget(_G, "time"))) or 0 end      -- heure réelle (absence)
local function PlayerLevel() return tonumber((Call(rawget(_G, "UnitLevel"), "player"))) or 1 end
local function Clamp(v, lo, hi) if v < lo then return lo end if v > hi then return hi end return v end

local function ModuleOn()
	local db = ns:DB()
	return db.enabled ~= false and db.companionEnabled ~= false
end
ns.CompanionOn = function() return ModuleOn() end

-- ---------------------------------------------------------------------------
-- État par personnage
-- ---------------------------------------------------------------------------
function ns:CompanionData()
	local char = self:CharData()
	local data = char.companion
	if type(data) ~= "table" then
		data = {}
		char.companion = data
	end
	if type(data.needs) ~= "table" then data.needs = {} end
	for _, key in ipairs(NEED_KEYS) do
		local v = tonumber(data.needs[key])
		data.needs[key] = v and Clamp(v, NEED_FLOOR, NEED_MAX) or NEED_START
	end
	data.unlocked = type(data.unlocked) == "table" and data.unlocked or {}
	data.seenZones = type(data.seenZones) == "table" and data.seenZones or {}
	data.seenSub = type(data.seenSub) == "table" and data.seenSub or {}
	data.appearance = data.appearance or ns.COMPANION_APPEARANCES[1].id
	return data
end

function ns:CompanionName()
	local name = self:CompanionData().name
	if type(name) == "string" and name ~= "" then return name end
	return L.COMP_DEFAULT_NAME
end

-- Un besoin ne passe jamais sous le plancher ni au-dessus de 100
function ns:CompanionAdd(key, amount)
	local needs = self:CompanionData().needs
	if needs[key] == nil then return end
	needs[key] = Clamp(needs[key] + (tonumber(amount) or 0), NEED_FLOOR, NEED_MAX)
	self:CompanionRefreshHover()
end

function ns:CompanionMood()
	local data = self:CompanionData()
	if data.sleepy then return "sleepy" end
	local sum = 0
	for _, key in ipairs(NEED_KEYS) do sum = sum + data.needs[key] end
	local avg = sum / #NEED_KEYS
	-- pas d'humeur « triste » : le bas de l'échelle est juste rêveur
	if avg >= 75 then return "radiant" end
	if avg >= 50 then return "happy" end
	return "dreamy"
end

-- ---------------------------------------------------------------------------
-- Stades d'évolution (niveau du joueur)
-- ---------------------------------------------------------------------------
function ns:CompanionStageFor(level)
	level = tonumber(level) or 1
	local stage = 1
	for index, def in ipairs(ns.COMPANION_STAGES) do
		if level >= def.level then stage = index end
	end
	return stage
end

function ns:CompanionStage()
	local data = self:CompanionData()
	return data.stage or self:CompanionStageFor(PlayerLevel())
end

function ns:CompanionStageLabel(stage)
	local def = ns.COMPANION_STAGES[stage or self:CompanionStage()] or ns.COMPANION_STAGES[1]
	return L[def.label]
end

-- `celebrate` = false au tout premier relevé : un joueur qui installe
-- l'addon au niveau 45 ne voit pas trois évolutions d'affilée
function ns:CompanionCheckStage(level, celebrate)
	local data = self:CompanionData()
	local target = self:CompanionStageFor(level or PlayerLevel())
	if data.stage == nil then
		data.stage = target
		self:CompanionApplyModel()
		return false
	end
	if target <= data.stage then return false end   -- jamais de retour en arrière
	data.stage = target
	self:CompanionApplyModel()
	if celebrate ~= false then self:CompanionCelebrate() end
	return true
end

function ns:CompanionCelebrate()
	local label = self:CompanionStageLabel()
	self:Print(self:F("COMP_MSG_EVOLVE", self:CompanionName(), label))
	self:CompanionSay("EVOLVE", { force = true, args = { label } })
	self:CompanionAnimate("dance", 3)
end

-- ---------------------------------------------------------------------------
-- Cosmétiques : apparences et ornements
-- ---------------------------------------------------------------------------
function ns:CompanionCounts()
	local counts = { zone = 0, subzone = 0, dungeon = 0, rare = 0, level = 0, total = 0 }
	if type(self.JournalCounts) == "function" then
		local ok, result = pcall(self.JournalCounts, self)
		if ok and type(result) == "table" then
			for key in pairs(counts) do counts[key] = tonumber(result[key]) or 0 end
		end
	end
	return counts
end

function ns:CompanionMeets(unlock, counts, level)
	if not unlock then return true end
	if unlock.level then return (level or PlayerLevel()) >= unlock.level end
	if unlock.stamp then return ((counts or self:CompanionCounts())[unlock.stamp] or 0) >= (unlock.count or 1) end
	return false
end

function ns:CompanionRequirement(unlock)
	if not unlock then return "" end
	if unlock.level then return self:F("COMP_REQ_LEVEL", unlock.level) end
	return self:F("COMP_REQ_" .. tostring(unlock.stamp), unlock.count or 1)
end

local function CosmeticKey(kind, id) return kind .. ":" .. id end

function ns:CompanionIsUnlocked(kind, def)
	if not def then return false end
	if not def.unlock then return true end
	return self:CompanionData().unlocked[CosmeticKey(kind, def.id)] == true
end

function ns:CompanionAppearanceDef(id)
	for _, def in ipairs(ns.COMPANION_APPEARANCES) do
		if def.id == id then return def end
	end
	return nil
end

-- Revérifie tout le catalogue. Un déblocage est définitif : la créature ne
-- perd jamais ce qu'elle a gagné, même si le Carnet est coupé ensuite.
-- `silent` : rien d'annoncé (premier relevé) ; `noBubble` : le chat seul,
-- quand une bulle plus importante occupe déjà la place (évolution)
function ns:CompanionCheckUnlocks(level, silent, noBubble)
	local data = self:CompanionData()
	-- premier relevé de ce personnage, d'où qu'il vienne (connexion, module
	-- activé en cours de partie, tampon) : silencieux. Sinon un joueur qui
	-- installe l'addon au niveau 45 reçoit une rafale de « débloqué ! ».
	if not data.unlockBaseline then
		silent = true
		data.unlockBaseline = true
	end
	local counts = self:CompanionCounts()
	local fresh = {}
	local function Scan(kind, list)
		for _, def in ipairs(list) do
			local key = CosmeticKey(kind, def.id)
			if def.unlock and not data.unlocked[key] and self:CompanionMeets(def.unlock, counts, level) then
				data.unlocked[key] = true
				fresh[#fresh + 1] = { kind = kind, def = def }
			end
		end
	end
	Scan("app", ns.COMPANION_APPEARANCES)
	Scan("orn", ns.COMPANION_ORNAMENTS)
	if #fresh == 0 then return fresh end
	if not silent then
		for _, item in ipairs(fresh) do
			self:Print(self:F(item.kind == "app" and "COMP_MSG_UNLOCK_APP" or "COMP_MSG_UNLOCK_ORN", L[item.def.label]))
		end
		-- une bulle pour le lot (la dernière nouveauté), pas une rafale
		if not noBubble then self:CompanionSay("UNLOCK", { force = true, args = { L[fresh[#fresh].def.label] } }) end
	end
	self:CompanionApplyOrnaments()
	if self.RefreshOptions then self:RefreshOptions() end
	return fresh
end

function ns:CompanionUnlockedAppearances()
	local list = {}
	for _, def in ipairs(ns.COMPANION_APPEARANCES) do
		if self:CompanionIsUnlocked("app", def) then list[#list + 1] = def end
	end
	return list
end

function ns:CompanionCurrentAppearance()
	local data = self:CompanionData()
	local def = self:CompanionAppearanceDef(data.appearance)
	if not (def and self:CompanionIsUnlocked("app", def)) then
		def = ns.COMPANION_APPEARANCES[1]
		data.appearance = def.id
	end
	return def
end

-- Choix d'apparence : passe à la suivante parmi celles débloquées
function ns:CompanionCycleAppearance()
	local list = self:CompanionUnlockedAppearances()
	local current = self:CompanionCurrentAppearance()
	local nextDef = list[1]
	for index, def in ipairs(list) do
		if def.id == current.id then nextDef = list[(index % #list) + 1] end
	end
	self:CompanionData().appearance = nextDef.id
	self:CompanionApplyModel()
	if self.RefreshOptions then self:RefreshOptions() end
	return nextDef
end

function ns:CompanionOrnamentShown(def)
	local db = self:DB()
	return self:CompanionIsUnlocked("orn", def) and db[def.key] ~= false
end

-- ---------------------------------------------------------------------------
-- Bulles : limitées dans le temps, coupables dans les réglages
-- ---------------------------------------------------------------------------
-- opts.force : passe outre l'écart minimal (évolution, déblocage, retour,
-- caresse demandée par le joueur). Jamais outre la sourdine.
function ns:CompanionSay(key, opts)
	opts = opts or {}
	if not ModuleOn() then return false end
	local db = self:DB()
	if db.companionBubbles == false or db.companionShow == false then return false end
	local now = Clock()
	if not opts.force and self.companionLastBubble and now - self.companionLastBubble < BUBBLE_GAP then
		return false
	end
	local text = self:F("COMP_SAY_" .. key, unpack(opts.args or {}))
	-- la bulle part du cadre : il doit être affiché
	if not self:CompanionUpdateVisibility() then return false end
	local bubble = self:EnsureCompanionBubble()
	if not bubble then return false end
	self.companionLastBubble = now
	self.companionBubbleKey, self.companionBubbleText = key, text
	self.companionBubbleUntil = now + BUBBLE_TIME
	bubble.text:SetText(text)
	bubble:SetHeight(math.max(26, math.ceil(#text / 30) * 13 + 14))
	bubble:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, bubble) end
	return true
end

function ns:CompanionHideBubble()
	self.companionBubbleUntil = nil
	if self.companionBubble then self.companionBubble:Hide() end
end

-- ---------------------------------------------------------------------------
-- Cadre : modèle 3D (ou boussole), nom, ornements, bulle, survol
-- ---------------------------------------------------------------------------
local FRAME_W, FRAME_H = 104, 118
local MODEL_H = 82

-- Un PlayerModel (ou Model) n'est gardé que s'il sait afficher une créature
local function CreateModel(parent)
	for _, kind in ipairs({ "PlayerModel", "Model" }) do
		local ok, model = pcall(CreateFrame, kind, nil, parent)
		if ok and model then
			if type(model.SetDisplayInfo) == "function" or type(model.SetCreature) == "function" then
				return model
			end
			if model.Hide then model:Hide() end
		end
	end
	return nil
end

local function BuildOrnaments(frame)
	local orn = {}
	-- ruban : bandeau bleu de nuit en travers du coin haut gauche, et sa queue
	orn.ribbon = CreateFrame("Frame", nil, frame)
	orn.ribbon:SetSize(34, 10)
	orn.ribbon:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
	orn.ribbon.band = Theme.Solid(orn.ribbon, "OVERLAY", Theme.BLUE, 0.95)
	orn.ribbon.band:SetPoint("TOPLEFT", orn.ribbon, "TOPLEFT", 0, 0)
	orn.ribbon.band:SetSize(34, 5)
	orn.ribbon.tail = Theme.Solid(orn.ribbon, "OVERLAY", Theme.BLUE, 0.75)
	orn.ribbon.tail:SetPoint("TOPLEFT", orn.ribbon, "TOPLEFT", 4, -5)
	orn.ribbon.tail:SetSize(5, 8)
	-- lanterne : un fil, un corps ambre et un halo doux, en haut à droite
	orn.lantern = CreateFrame("Frame", nil, frame)
	orn.lantern:SetSize(14, 24)
	orn.lantern:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 6)
	orn.lantern.wire = Theme.Solid(orn.lantern, "ARTWORK", Theme.GOLD_SOFT, 1)
	orn.lantern.wire:SetPoint("TOP", orn.lantern, "TOP", 0, 0)
	orn.lantern.wire:SetSize(1, 8)
	orn.lantern.glow = Theme.Solid(orn.lantern, "ARTWORK", Theme.GOLD, 0.25)
	orn.lantern.glow:SetPoint("TOP", orn.lantern, "TOP", 0, -6)
	orn.lantern.glow:SetSize(14, 16)
	orn.lantern.body = Theme.Solid(orn.lantern, "OVERLAY", Theme.GOLD, 1)
	orn.lantern.body:SetPoint("TOP", orn.lantern, "TOP", 0, -9)
	orn.lantern.body:SetSize(7, 10)
	-- médaille : losange doré sur un ruban, en bas à gauche
	orn.medal = CreateFrame("Frame", nil, frame)
	orn.medal:SetSize(16, 22)
	orn.medal:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 4, 18)
	orn.medal.strap = Theme.Solid(orn.medal, "ARTWORK", Theme.RED, 0.9)
	orn.medal.strap:SetPoint("TOP", orn.medal, "TOP", 0, 0)
	orn.medal.strap:SetSize(6, 9)
	orn.medal.disc = Theme.CreateDiamond(orn.medal, 14)
	orn.medal.disc:SetPoint("TOP", orn.medal, "TOP", 0, -7)
	orn.medal.disc:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
	-- cadre doré : double liseré ambre autour du cadre
	orn.gold = CreateFrame("Frame", nil, frame)
	orn.gold:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
	orn.gold:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
	orn.gold.outer = Theme.Border(orn.gold, Theme.GOLD, 1, "OVERLAY")
	orn.gold.corner = { Theme.CornerAccent(frame) }
	for _, o in pairs(orn) do o:Hide() end
	return orn
end

function ns:EnsureCompanionFrame()
	if self.companionFrame then return self.companionFrame end
	if not (Theme and Theme.CreateDiscreet) then return nil end
	local frame = Theme.CreateDiscreet(UIParent, FRAME_W, FRAME_H)
	if not frame then return nil end
	frame:EnableMouse(true)
	if self.RestorePoint then self:RestorePoint(frame, "companionPoint", { point = "CENTER", x = 330, y = -170 }) end

	frame.model = CreateModel(frame)
	if frame.model then
		frame.model:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
		frame.model:SetSize(FRAME_W - 8, MODEL_H)
	end
	-- repli : la boussole de l'addon, si le client n'offre pas de modèle
	frame.fallback = frame:CreateTexture(nil, "ARTWORK")
	frame.fallback:SetTexture(Theme.LOGO_SMALL)
	frame.fallback:SetSize(56, 56)
	frame.fallback:SetPoint("TOP", frame, "TOP", 0, -14)
	frame.fallback:Hide()

	frame.zzz = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.zzz:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
	frame.zzz:SetText("Zz")
	frame.zzz:SetTextColor(Theme.BLUE[1], Theme.BLUE[2], Theme.BLUE[3])
	frame.zzz:Hide()

	frame.name = frame:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	frame.name:SetPoint("BOTTOM", frame, "BOTTOM", 0, 18)
	frame.name:SetWidth(FRAME_W - 8)
	frame.name:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
	frame.mood = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.mood:SetPoint("BOTTOM", frame, "BOTTOM", 0, 5)
	frame.mood:SetWidth(FRAME_W - 8)

	frame.ornaments = BuildOrnaments(frame)

	-- clic = caresse, glisser = déplacer. Le clic n'est compté que si la
	-- souris n'a presque pas bougé : l'ordre OnDragStop/OnMouseUp varie.
	frame:SetScript("OnMouseDown", function(f)
		f.downX, f.downY = Call(rawget(_G, "GetCursorPosition"))
	end)
	frame:SetScript("OnMouseUp", function(f, button)
		if button and button ~= "LeftButton" then return end
		local x, y = Call(rawget(_G, "GetCursorPosition"))
		if f.downX and x and (math.abs(x - f.downX) > 4 or math.abs((y or 0) - (f.downY or 0)) > 4) then return end
		ns:CompanionPet()
	end)
	frame:SetScript("OnEnter", function() ns:CompanionShowHover() end)
	frame:SetScript("OnLeave", function() ns:CompanionHideHover() end)

	self.companionFrame = frame
	self:CompanionApplyModel()
	self:CompanionApplyOrnaments()
	return frame
end

function ns:EnsureCompanionBubble()
	if self.companionBubble then return self.companionBubble end
	local frame = self.companionFrame
	if not frame then return nil end
	local bubble = Theme.CreateDiscreet(UIParent, 190, 28)
	if not bubble then return nil end
	bubble:SetFrameStrata("HIGH")
	bubble:SetPoint("BOTTOM", frame, "TOP", 0, 8)
	bubble.bg:SetVertexColor(Theme.SURFACE[1], Theme.SURFACE[2], Theme.SURFACE[3], 0.92)
	bubble.tail = Theme.CreateDiamond(bubble, 10)
	bubble.tail:SetPoint("TOP", bubble, "BOTTOM", 0, 5)
	bubble.tail:SetVertexColor(Theme.SURFACE[1], Theme.SURFACE[2], Theme.SURFACE[3], 0.92)
	bubble.text = bubble:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	bubble.text:SetPoint("TOPLEFT", bubble, "TOPLEFT", 8, -6)
	bubble.text:SetWidth(174)
	bubble.text:SetJustifyH("CENTER")
	bubble.text:SetWordWrap(true)
	bubble:Hide()
	self.companionBubble = bubble
	return bubble
end

-- Survol : quatre petites barres de besoins, le stade et l'humeur
function ns:EnsureCompanionHover()
	if self.companionHover then return self.companionHover end
	local frame = self.companionFrame
	if not frame then return nil end
	local hover = Theme.CreateDiscreet(UIParent, 168, 118)
	if not hover then return nil end
	hover:SetFrameStrata("TOOLTIP")
	hover:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -6, 0)
	hover.title = Theme.CreateTitle(hover, 13)
	hover.title:SetPoint("TOPLEFT", hover, "TOPLEFT", 8, -6)
	hover.sub = hover:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	hover.sub:SetPoint("TOPLEFT", hover, "TOPLEFT", 8, -22)
	hover.bars = {}
	for index, key in ipairs(NEED_KEYS) do
		local y = -38 - (index - 1) * 15
		local label = hover:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		label:SetPoint("TOPLEFT", hover, "TOPLEFT", 8, y)
		label:SetText(L["COMP_NEED_" .. key])
		local bar = Theme.CreateBar(hover, 80, 6)
		bar:SetPoint("TOPRIGHT", hover, "TOPRIGHT", -8, y - 3)
		bar.label = label
		hover.bars[key] = bar
	end
	hover.hint = hover:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	hover.hint:SetPoint("BOTTOMLEFT", hover, "BOTTOMLEFT", 8, 6)
	hover.hint:SetWidth(152)
	hover.hint:SetText(L.COMP_HOVER_HINT)
	hover.hint:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	hover:Hide()
	self.companionHover = hover
	return hover
end

function ns:CompanionRefreshHover()
	local hover = self.companionHover
	if not hover then return end
	local data = self:CompanionData()
	hover.title:SetText(self:CompanionName())
	hover.sub:SetText(Theme.T_GOLD .. self:CompanionStageLabel() .. "|r · " .. tostring(L["COMP_MOOD_" .. self:CompanionMood()]))
	for _, key in ipairs(NEED_KEYS) do
		local bar = hover.bars[key]
		bar:SetValue(data.needs[key] / NEED_MAX)
	end
end

function ns:CompanionShowHover()
	local hover = self:EnsureCompanionHover()
	if not hover then return end
	self:CompanionRefreshHover()
	hover:Show()
end

function ns:CompanionHideHover()
	if self.companionHover then self.companionHover:Hide() end
end

-- Modèle : apparence, échelle du stade, animation de l'humeur. Sans
-- SetDisplayInfo (ou s'il refuse), la boussole prend la place.
function ns:CompanionApplyModel()
	local frame = self.companionFrame
	if not frame then return end
	local app = self:CompanionCurrentAppearance()
	local stageDef = ns.COMPANION_STAGES[self:CompanionStage()] or ns.COMPANION_STAGES[1]
	local model, shown = frame.model, false
	if model then
		if app.display and type(model.SetDisplayInfo) == "function" then
			shown = pcall(model.SetDisplayInfo, model, app.display)
		end
		if not shown and app.npc and type(model.SetCreature) == "function" then
			shown = pcall(model.SetCreature, model, app.npc)
		end
	end
	frame.usesFallback = not shown
	frame.displayID = shown and app.display or nil
	if shown then
		Method(model, "SetModelScale", stageDef.scale)
		Method(model, "SetCamDistanceScale", 1.6)
		model:Show()
		frame.fallback:Hide()
	else
		if model and model.Hide then model:Hide() end
		frame.fallback:Show()
		-- la boussole grandit aussi avec le stade
		frame.fallback:SetSize(48 * stageDef.scale + 8, 48 * stageDef.scale + 8)
	end
	frame.scale = stageDef.scale
	self:CompanionAnimate()
	self:CompanionRefreshLabels()
end

-- Sans `name` : l'animation de l'humeur (sommeil ou repos)
function ns:CompanionAnimate(name, duration)
	local frame = self.companionFrame
	if not frame then return end
	local anims = ns.COMPANION_ANIMS
	if not name then
		name = self:CompanionData().sleepy and "sleep" or "idle"
		self.companionAnimUntil = nil
	elseif duration then
		self.companionAnimUntil = Clock() + duration
	end
	frame.animation = name
	if frame.usesFallback then
		-- repli : un petit fondu remplace la danse ; la boussole pâlit en dormant
		frame.fallback:SetAlpha(name == "sleep" and 0.6 or 1)
		if name ~= "idle" and name ~= "sleep" and Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	elseif frame.model then
		Method(frame.model, "SetAnimation", anims[name] or anims.idle)
	end
	if name == "sleep" then frame.zzz:Show() else frame.zzz:Hide() end
end

function ns:CompanionRefreshLabels()
	local frame = self.companionFrame
	if not frame then return end
	frame.name:SetText(self:CompanionName())
	frame.mood:SetText(Theme.T_GREY .. tostring(L["COMP_MOOD_" .. self:CompanionMood()]) .. "|r")
end

function ns:CompanionApplyOrnaments()
	local frame = self.companionFrame
	if not frame then return end
	for _, def in ipairs(ns.COMPANION_ORNAMENTS) do
		local o = frame.ornaments[def.id]
		if o then
			local shown = self:CompanionOrnamentShown(def)
			if shown then o:Show() else o:Hide() end
			if def.id == "gold" and o.corner then
				for _, tex in ipairs(o.corner) do if shown then tex:Show() else tex:Hide() end end
			end
		end
	end
end

-- Affiche ou cache selon le module et le réglage « Afficher »
function ns:CompanionUpdateVisibility()
	local db = self:DB()
	if not ModuleOn() or db.companionShow == false then
		if self.companionFrame then self.companionFrame:Hide() end
		self:CompanionHideBubble()
		self:CompanionHideHover()
		return false
	end
	local frame = self:EnsureCompanionFrame()
	if not frame then return false end
	self:CompanionApplyOrnaments()
	self:CompanionRefreshLabels()
	frame:Show()
	return true
end

-- ---------------------------------------------------------------------------
-- Besoins : baisse douce en jeu, gains sur les bons moments
-- ---------------------------------------------------------------------------
local EAT_AURAS = {
	["food"] = true, ["drink"] = true, ["food & drink"] = true, ["refreshment"] = true,
	["nourriture"] = true, ["boisson"] = true, ["nourriture et boisson"] = true, ["rafraîchissement"] = true,
}
local FED_AURAS = { ["well fed"] = true, ["bien nourri"] = true, ["repu"] = true }

function ns:CompanionAuraState()
	local eating, fed = false, false
	local read = self.AuraByIndex
	if type(read) ~= "function" then return false, false end
	for index = 1, 40 do
		local aura = read(index)
		if not aura then break end
		local name = type(aura.name) == "string" and self.AsciiLower(aura.name) or nil
		if name and EAT_AURAS[name] then eating = true end
		if name and FED_AURAS[name] then fed = true end
	end
	return eating, fed
end

-- Repas : un gros coup de faim comblé au début, puis un peu chaque minute
function ns:CompanionCheckAuras()
	local eating, fed = self:CompanionAuraState()
	if eating and not self.companionEating then
		self:CompanionAdd("hunger", 35)
		self:CompanionSay("EAT")
	end
	if fed and not self.companionFed then self:CompanionAdd("hunger", 15) end
	self.companionEating, self.companionFed = eating, fed
	local atCamp = self.AtCamp and self:AtCamp() or false
	if atCamp and not self.companionAtCamp then
		self:CompanionAdd("energy", 10)
		self:CompanionSay("CAMP")
	end
	self.companionAtCamp = atCamp
end

function ns:CompanionResting()
	if Call(rawget(_G, "IsResting")) then return true end
	return self.AtCamp and self:AtCamp() or false
end

-- `seconds` de jeu écoulées : baisse douce, sauf ce qui remonte
function ns:CompanionTick(seconds)
	if not ModuleOn() then return end
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then return end
	local data = self:CompanionData()
	local minutes = seconds / 60
	local resting = self:CompanionResting()
	for _, key in ipairs(NEED_KEYS) do
		local delta = -DECAY[key] * minutes
		if key == "energy" and resting then delta = REST_GAIN * minutes end
		if key == "hunger" and self.companionEating then delta = EAT_GAIN * minutes end
		data.needs[key] = Clamp(data.needs[key] + delta, NEED_FLOOR, NEED_MAX)
	end
	-- somnolence : il se réveille en jouant, pas en attendant
	if data.sleepy then
		data.sleepyLeft = (tonumber(data.sleepyLeft) or 0) - seconds
		if data.sleepyLeft <= 0 then self:CompanionWake(true) end
	end
	data.lastSeen = Wall()
	self:CompanionRefreshLabels()
	self:CompanionRefreshHover()
end

function ns:CompanionWake(say)
	local data = self:CompanionData()
	if not data.sleepy then return false end
	data.sleepy, data.sleepyLeft = nil, nil
	self:CompanionAnimate()
	self:CompanionRefreshLabels()
	if say then self:CompanionSay("AWAKE", { force = true }) end
	return true
end

-- Connexion : une absence le rend somnolent, sans rien retirer à ses besoins
function ns:CompanionLogin()
	local data = self:CompanionData()
	local now = Wall()
	local first = data.lastSeen == nil
	local away = first and 0 or math.max(0, now - (tonumber(data.lastSeen) or now))
	data.lastSeen = now
	-- zone de connexion : connue d'emblée, pas de « Quelle vue ! » au chargement
	local mapID = self.CurrentMap and self:CurrentMap()
	if mapID then data.seenZones[mapID] = true end
	self:CompanionCheckStage(PlayerLevel(), not first)
	self:CompanionCheckUnlocks(nil, first)
	self.companionLastBubble = nil
	if first then
		self:CompanionSay("HELLO", { force = true, args = { self:CompanionName() } })
	elseif away >= SLEEPY_AFTER then
		data.sleepy = true
		data.sleepyLeft = Clamp(math.floor(away / 3600 * SLEEPY_PER_HOUR), SLEEPY_MIN, SLEEPY_MAX)
		self:CompanionAnimate()
		self:CompanionSay("MISSED", { force = true })
	end
	self:CompanionRefreshLabels()
	return away
end

-- Caresse : un peu de moral, une bulle mignonne, puis une petite pause
function ns:CompanionPet()
	if not ModuleOn() then return false end
	local now = Clock()
	if self.companionLastPet and now - self.companionLastPet < PET_COOLDOWN then return false end
	self.companionLastPet = now
	local mood = self:CompanionMood()
	self:CompanionWake(false)
	self:CompanionAdd("mood", 8)
	self:CompanionSay("PET_" .. mood, { force = true })
	self:CompanionAnimate("cheer", 2)
	return true
end

-- ---------------------------------------------------------------------------
-- Réactions
-- ---------------------------------------------------------------------------
function ns:CompanionFoodInBags()
	local kindOf = self.ConsumableKind
	if type(kindOf) ~= "function" or not C_Container then return 0 end
	local count = 0
	for bag = 0, 4 do
		local slots = tonumber((Call(C_Container.GetContainerNumSlots, bag))) or 0
		for slot = 1, slots do
			local info = Call(C_Container.GetContainerItemInfo, bag, slot)
			if type(info) == "table" and info.itemID and kindOf(info.itemID) == "food" then
				count = count + (info.stackCount or 1)
			end
		end
	end
	return count
end

local LINK_COLORS = { ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5 }
local function LinkQuality(link)
	local _, _, quality = Call(rawget(_G, "GetItemInfo"), link)
	if type(quality) == "number" then return quality end
	local iq = link:match("|cnIQ(%d+):")
	if iq then return tonumber(iq) end
	local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
	return hex and LINK_COLORS[hex:lower()] or 0
end

function ns:CompanionOnLoot(message)
	if type(self.ParseSelfLoot) ~= "function" then return end
	local link = self:ParseSelfLoot(message)
	if link and LinkQuality(link) >= 3 then   -- rare ou mieux : un vrai moment
		self:CompanionAdd("mood", 10)
		self:CompanionSay("LOOT")
	end
end

function ns:CompanionOnZone(newArea)
	local data = self:CompanionData()
	local mapID = self.CurrentMap and self:CurrentMap()
	if newArea then
		if mapID and not data.seenZones[mapID] then
			data.seenZones[mapID] = true
			self:CompanionAdd("curiosity", 15)
			self:CompanionSay("VIEW")
		end
		return
	end
	local sub = self.CurrentSubZone and self:CurrentSubZone()
	if mapID and sub then
		local key = tostring(mapID) .. ":" .. sub
		if not data.seenSub[key] then
			data.seenSub[key] = true
			self:CompanionAdd("curiosity", 4)   -- sans bulle : il y en aurait trop
		end
	end
end

function ns:CompanionOnLevel(level)
	level = tonumber(level) or PlayerLevel()
	self:CompanionAdd("mood", 25)
	self:CompanionWake(false)
	local evolved = self:CompanionCheckStage(level, true)
	-- l'évolution garde sa bulle ; un déblocage du même niveau passe au chat
	local fresh = self:CompanionCheckUnlocks(level, false, evolved)
	if not evolved and #fresh == 0 then self:CompanionSay("LEVEL", { args = { level } }) end
end

function ns:CompanionOnStamp(stamp)
	if type(stamp) ~= "table" or stamp.new == false then return end
	self:CompanionAdd("curiosity", stamp.kind == "rare" and 15 or 10)
	local fresh = self:CompanionCheckUnlocks()
	-- la bulle du déblocage a priorité sur celle du tampon
	if #fresh == 0 then self:CompanionSay("STAMP", { args = { tostring(stamp.name or "?") } }) end
end

ns:RegisterCallback("DEPARTURE", function(self)
	if not ModuleOn() then return end
	if self:CompanionFoodInBags() > 0 then
		self:CompanionAdd("hunger", 10)
		self:CompanionSay("DEPART")
	else
		self:CompanionSay("NOFOOD")
	end
end)
ns:RegisterCallback("RETURN", function(self)
	if not ModuleOn() then return end
	self:CompanionAdd("energy", 5)
	self:CompanionSay("RETURN")
end)
ns:RegisterCallback("STAMP", function(self, stamp)
	if not ModuleOn() then return end
	self:CompanionOnStamp(stamp)
end)

-- ---------------------------------------------------------------------------
-- Réglages : apparence, verrous, visibilité
-- ---------------------------------------------------------------------------
if type(ns.RunOptionAction) == "function" then
	local baseAction = ns.RunOptionAction
	function ns:RunOptionAction(key, ...)
		if key == "companionAppearance" then return self:CompanionCycleAppearance() end
		return baseAction(self, key, ...)
	end
end
if type(ns.ApplyDisplayOptions) == "function" then
	local baseApply = ns.ApplyDisplayOptions
	function ns:ApplyDisplayOptions(...)
		baseApply(self, ...)
		local ok, err = pcall(self.CompanionUpdateVisibility, self)
		if not ok and self.RecordError then self:RecordError("companion:display", err) end
	end
end

function ns:CompanionRefreshPage()
	local frame = self.optionsFrame
	if not (frame and frame.rows) then return end
	for _, row in ipairs(frame.rows) do
		local key = row.def and row.def.key
		if key == "companionAppearance" then
			row.value:SetWidth(170)
			row.value:SetText(Theme.T_GOLD .. tostring(L[self:CompanionCurrentAppearance().label]) .. "|r")
		elseif key then
			for _, def in ipairs(ns.COMPANION_ORNAMENTS) do
				if def.key == key then
					if self:CompanionIsUnlocked("orn", def) then
						row.label:SetText(L[def.label])
						row.label:SetTextColor(0.86, 0.84, 0.78)
						if row.toggle then row.toggle:SetAlpha(1) end
					else
						row.label:SetText(self:F("OPT_COMP_LOCKED", L[def.label], self:CompanionRequirement(def.unlock)))
						row.label:SetTextColor(0.45, 0.45, 0.45)
						-- verrouillé : l'interrupteur n'a pas à paraître allumé (il ne
						-- montre rien tant que l'ornement n'est pas gagné) — vu sur un rendu
						if row.toggle then
							row.toggle:SetChecked(false)
							row.toggle:SetAlpha(0.35)
						end
					end
				end
			end
		end
	end
end

if type(ns.RefreshOptions) == "function" then
	local baseRefresh = ns.RefreshOptions
	function ns:RefreshOptions(...)
		baseRefresh(self, ...)
		local ok, err = pcall(self.CompanionRefreshPage, self)
		if not ok and self.RecordError then self:RecordError("companion:options", err) end
		-- « /r2q module compagnon off » passe par ici : le cadre suit
		ok, err = pcall(self.CompanionUpdateVisibility, self)
		if not ok and self.RecordError then self:RecordError("companion:display", err) end
	end
end

-- ---------------------------------------------------------------------------
-- Commande : /r2q compagnon [nom <nom> | caresse | apparence | muet]
-- ---------------------------------------------------------------------------
function ns:CompanionStatusLine()
	local data = self:CompanionData()
	local apps, orns = 0, 0
	for _, def in ipairs(ns.COMPANION_APPEARANCES) do if self:CompanionIsUnlocked("app", def) then apps = apps + 1 end end
	for _, def in ipairs(ns.COMPANION_ORNAMENTS) do if self:CompanionIsUnlocked("orn", def) then orns = orns + 1 end end
	local n = data.needs
	return self:F("COMP_MSG_STATUS", self:CompanionName(), L[self:CompanionCurrentAppearance().label],
			self:CompanionStageLabel(), L["COMP_MOOD_" .. self:CompanionMood()]),
		self:F("COMP_MSG_NEEDS", math.floor(n.hunger + 0.5), math.floor(n.energy + 0.5), math.floor(n.mood + 0.5), math.floor(n.curiosity + 0.5)),
		self:F("COMP_MSG_COLLECTION", apps, #ns.COMPANION_APPEARANCES, orns, #ns.COMPANION_ORNAMENTS)
end

-- Nom : pas de code de couleur ni de lien (« | »), espaces repliés, 24 car.
function ns:CompanionSanitizeName(text)
	if type(text) ~= "string" then return nil end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", ""):gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
	if text == "" then return nil end
	if #text > NAME_MAX then
		text = text:sub(1, NAME_MAX)
		-- ne pas couper un caractère UTF-8 en deux
		while #text > 0 and text:byte(#text) >= 0x80 and text:byte(#text) < 0xC0 do text = text:sub(1, -2) end
		if #text > 0 and text:byte(#text) >= 0xC0 then text = text:sub(1, -2) end
	end
	return text
end

function ns:CompanionCommand(rest)
	if not ModuleOn() then return self:Print(L.COMP_MSG_OFF) end
	local sub, arg = tostring(rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
	sub = (sub or ""):lower()
	if sub == "nom" or sub == "name" then
		local name = self:CompanionSanitizeName(arg)
		if not name then return self:Print(L.COMP_MSG_NAME_BAD) end
		self:CompanionData().name = name
		self:CompanionRefreshLabels()
		self:CompanionRefreshHover()
		return self:Print(self:F("COMP_MSG_RENAMED", name))
	elseif sub == "caresse" or sub == "pet" then
		self:CompanionUpdateVisibility()
		self:CompanionPet()
		return
	elseif sub == "apparence" or sub == "look" then
		local def = self:CompanionCycleAppearance()
		return self:Print(self:F("COMP_MSG_APPEARANCE", L[def.label]))
	elseif sub == "muet" or sub == "mute" then
		local db = self:DB()
		db.companionBubbles = not (db.companionBubbles ~= false)
		if db.companionBubbles == false then self:CompanionHideBubble() end
		return self:Print(self:F("COMP_MSG_MUTE", db.companionBubbles and L.MODULE_ON or L.MODULE_OFF))
	end
	self:CompanionCheckUnlocks()
	local line1, line2, line3 = self:CompanionStatusLine()
	self:Print(line1)
	print("   " .. line2)
	print("   " .. line3)
	if self.companionFrame and self.companionFrame.usesFallback then print("   " .. L.COMP_MSG_FALLBACK) end
end

ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["compagnon"] = function(self, rest) self:CompanionCommand(rest) end
ns.EXTRA_COMMANDS["companion"] = ns.EXTRA_COMMANDS["compagnon"]

-- ---------------------------------------------------------------------------
-- Événements propres au module
-- ---------------------------------------------------------------------------
local HANDLERS = {
	PLAYER_ENTERING_WORLD = function(isLogin, isReload)
		-- un seul relevé d'absence par session (pas à chaque écran de chargement)
		if not ns.companionSession then
			ns.companionSession = true
			ns:CompanionUpdateVisibility()
			ns:CompanionLogin()
		else
			ns:CompanionOnZone(true)
		end
		ns:CompanionCheckAuras()
	end,
	PLAYER_LOGOUT          = function() ns:CompanionData().lastSeen = Wall() end,
	PLAYER_LEVEL_UP        = function(level) ns:CompanionOnLevel(level) end,
	PLAYER_DEAD            = function() ns:CompanionSay("DEAD") end,
	QUEST_TURNED_IN        = function()
		ns:CompanionAdd("mood", 12)
		ns:CompanionWake(false)
		ns:CompanionSay("QUEST")
	end,
	CHAT_MSG_LOOT          = function(message) ns:CompanionOnLoot(message) end,
	ZONE_CHANGED_NEW_AREA  = function() ns:CompanionOnZone(true) end,
	ZONE_CHANGED           = function() ns:CompanionOnZone(false) end,
	ZONE_CHANGED_INDOORS   = function() ns:CompanionOnZone(false) end,
	UNIT_AURA              = function(unit) if unit == "player" then ns:CompanionCheckAuras() end end,
	PLAYER_UPDATE_RESTING  = function()
		if Call(rawget(_G, "IsResting")) and not ns:CompanionData().sleepy then ns:CompanionSay("INN") end
	end,
}

local events = CreateFrame("Frame")
for event in pairs(HANDLERS) do
	-- un événement inconnu du client ne doit pas bloquer les autres
	pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, ...)
	if not ModuleOn() then return end
	local handler = HANDLERS[event]
	if not handler then return end
	local ok, err = pcall(handler, ...)
	if not ok and ns.RecordError then ns:RecordError("companion:" .. tostring(event), err) end
end)

-- Horloge : besoins toutes les TICK s, fin de bulle, fin d'animation,
-- léger balancement du modèle
local pending, sway = 0, 0
events:SetScript("OnUpdate", function(_, delta)
	if not ModuleOn() then return end
	delta = math.min(tonumber(delta) or 0, MAX_STEP)
	pending = pending + delta
	sway = sway + delta
	local now = Clock()
	if ns.companionBubbleUntil and now >= ns.companionBubbleUntil then ns:CompanionHideBubble() end
	if ns.companionAnimUntil and now >= ns.companionAnimUntil then ns:CompanionAnimate() end
	local frame = ns.companionFrame
	if frame and frame.model and not frame.usesFallback and frame:IsShown() then
		Method(frame.model, "SetRotation", 0.35 * math.sin(sway * 0.5))
	end
	if pending < TICK then return end
	local step = pending
	pending = 0
	local ok, err = pcall(ns.CompanionTick, ns, step)
	if not ok and ns.RecordError then ns:RecordError("companion:tick", err) end
end)
ns.companionEvents = events

if ns.Mark then ns.Mark("Companion") end
