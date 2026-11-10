-- Capture.lua -- la ménagerie : capturer les monstres abattus (QuestCompanion 1.4.0)
--
-- Retour des joueurs : débloquer chaque compagnon par des objectifs, c'est
-- lent et peu interactif. En plus des mascottes (qui restent), chaque monstre
-- abattu peut désormais être CAPTURÉ et devenir une apparence du compagnon.
--   * un monstre compté abattu (Bestiary.lua, BestiaryOnKill) ouvre une petite
--     fenêtre « Capturer ? » pendant CAPTURE_WINDOW secondes : son modèle, son
--     rang, la chance, et les aides qu'on a en poche (2.0 : plus de fenêtre
--     automatique, une file et un bouton filet, voir CaptureQueue.lua) ;
--   * un clic = un essai, un seul par monstre. Le compagnon secoue le filet
--     (une, deux, trois secousses) puis c'est gagné… ou il s'échappe, et le
--     compagnon se moque gentiment ;
--   * la chance dépend du rang (normal 50 %, élite 25 %, rare 15 %, rare élite
--     5 %, boss 2 %) et de l'écart de niveau (plus haut que toi : plus dur) ;
--   * aides (pas des balles : des objets de dresseur), gagnées au hasard des
--     complétions du carnet (tampons, paliers de zone, brillantes) :
--       Appât savoureux ×1,5 · Lasso tressé ×2,5 · Sifflet du dompteur = assuré ;
--   * une espèce déjà capturée ne se propose plus (sauf en version brillante) ;
--   * toutes les CAPTURE_GIFT_EVERY captures : un Sifflet offert.
-- Les créatures capturées rejoignent la liste des apparences (réglages,
-- Collection du carnet) : Companion.lua les lit par ns:CaptureAppearances().
-- Réglage : page « Au jour le jour » (« Capturer les monstres abattus »).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.CAPTURE_WINDOW = 12            -- s pour tenter sa chance après le coup fatal
ns.CAPTURE_SHAKE_STEP = 0.55      -- s entre deux secousses du filet
ns.CAPTURE_MAX = 0.95             -- jamais tout à fait sûr sans Sifflet
ns.CAPTURE_GIFT_EVERY = 10        -- un Sifflet offert toutes les 10 captures
-- 2.9.0 : chances relevées (« je n'attrape jamais rien ») ; avant :
-- 0,40 / 0,30 / 0,15 / 0,08 / 0,05 / 0,02
ns.CAPTURE_RATES = {
	trivial = 0.60, minus = 0.60, normal = 0.50, elite = 0.25,
	rare = 0.15, rareelite = 0.10, worldboss = 0.04,
}
-- écart de niveau : -4 % par niveau au-dessus de toi (plancher ×0,5),
-- +3 % par niveau en dessous (plafond ×1,5)
ns.CAPTURE_LEVEL_STEP = { above = 0.04, below = 0.03, floor = 0.5, ceil = 1.5 }
-- filet qui s'use la malchance : +5 points par échec d'affilée (jusqu'à +25),
-- remis à zéro à la prochaine prise (2.9.0)
ns.CAPTURE_PITY = { step = 0.05, max = 5 }

local AIDS = {
	{ id = "appat",   mult = 1.5, cap = 10, icon = "Interface\\Icons\\INV_Misc_Food_14" },
	{ id = "lasso",   mult = 2.5, cap = 5,  icon = "Interface\\Icons\\Spell_Nature_StrangleVines" },
	{ id = "sifflet", sure = true, cap = 3, icon = "Interface\\Icons\\INV_Misc_Horn_01" },
}
local AID_BY_ID = {}
for _, aid in ipairs(AIDS) do AID_BY_ID[aid.id] = aid end
ns.CAPTURE_AIDS = AIDS

-- d'où viennent les aides : tampon du carnet (sorte -> { chance, tirage })
-- `pick` : une aide fixe, ou "draw" = tirage pondéré (DRAW)
local STAMP_DROPS = {
	subzone = { chance = 0.25, pick = "appat" },
	capital = { chance = 0.25, pick = "appat" },
	zone    = { chance = 1.0,  pick = "draw" },
	rare    = { chance = 0.5,  pick = "lasso" },
	dungeon = { chance = 1.0,  pick = "lasso", bonus = { chance = 0.2, pick = "sifflet" } },
	level   = { chance = 0.3,  pick = "draw" },
}
local DRAW = { { "appat", 60 }, { "lasso", 33 }, { "sifflet", 7 } }
-- paliers de complétion d'une zone (Treats.lua) : 25 -> appât, 50 -> lasso,
-- 75 -> tirage (avec sa chance de Sifflet)
local MILESTONE_DROPS = { [25] = "appat", [50] = "lasso", [75] = "draw" }
ns.CAPTURE_STAMP_DROPS = STAMP_DROPS
ns.CAPTURE_MILESTONE_DROPS = MILESTONE_DROPS

local FR = {
	CAPTURE_aid_appat      = "Appât savoureux",
	CAPTURE_aid_lasso      = "Lasso tressé",
	CAPTURE_aid_sifflet    = "Sifflet du dompteur",
	CAPTURE_AID_DESC_appat   = "Chance de capture ×1,5.",
	CAPTURE_AID_DESC_lasso   = "Chance de capture ×2,5.",
	CAPTURE_AID_DESC_sifflet = "Capture assurée.",
	CAPTURE_TITLE          = "Capturer ?",
	CAPTURE_CHANCE         = "%s · %d %%",
	CAPTURE_SURE           = "%s · assurée",
	CAPTURE_THROW          = "Capturer",
	CAPTURE_AID_HINT       = "Clic : utiliser pour cet essai (%d en poche).",
	CAPTURE_AID_NONE       = "Aucun en poche. Les tampons et paliers du carnet en rapportent.",
	CAPTURE_SHAKING        = "Le filet bouge…",
	CAPTURE_GOT            = "Capturé !",
	CAPTURE_FLED           = "Échappé…",
	CAPTURE_MSG_OK         = "%s capturé ! Il rejoint ta collection (apparences du compagnon).",
	CAPTURE_MSG_FAIL       = "%s s'est échappé.",
	CAPTURE_MSG_ITEM       = "Tu trouves : %s (%d en poche).",
	CAPTURE_MSG_FULL       = "%s : ta besace en est pleine.",
	CAPTURE_MSG_GIFT       = "%d captures ! Ton compagnon t'offre un %s.",
	CAPTURE_MSG_SUMMARY    = "Créatures : %d capturées (%d essais). Aides : %s.",
	CAPTURE_MSG_EMPTY      = "Collection vide pour l'instant : abats un monstre, puis clique sur le filet du compagnon.",
	CAPTURE_RANK_normal    = "Normal",
	CAPTURE_RANK_trivial   = "Insignifiant",
	CAPTURE_RANK_minus     = "Insignifiant",
	CAPTURE_RANK_elite     = "Élite",
	CAPTURE_RANK_rare      = "Rare",
	CAPTURE_RANK_rareelite = "Rare élite",
	CAPTURE_RANK_worldboss = "Boss",
	CAPTURE_SHINY_TAG      = "%s (brillant)",
	CAPTURE_SRC            = "Capturé le %s",
	OPT_DAILY_CAPTURE      = "Capturer les monstres abattus",
	OPT_DAILY_CAPTURE_DESC = "Les monstres abattus qui valent le coup attendent 30 s après le combat : un filet sur le compagnon les capture (clic droit : la liste). Ils deviennent des apparences du compagnon.",
	HELP_CAPTURE           = "/qc capture -- ta collection et tes aides de capture",
}
local EN = {
	CAPTURE_aid_appat      = "Tasty bait",
	CAPTURE_aid_lasso      = "Braided lasso",
	CAPTURE_aid_sifflet    = "Tamer's whistle",
	CAPTURE_AID_DESC_appat   = "Capture chance ×1.5.",
	CAPTURE_AID_DESC_lasso   = "Capture chance ×2.5.",
	CAPTURE_AID_DESC_sifflet = "Guaranteed capture.",
	CAPTURE_TITLE          = "Capture?",
	CAPTURE_CHANCE         = "%s · %d%%",
	CAPTURE_SURE           = "%s · guaranteed",
	CAPTURE_THROW          = "Capture",
	CAPTURE_AID_HINT       = "Click: use it for this try (%d in your pack).",
	CAPTURE_AID_NONE       = "None in your pack. Journal stamps and zone milestones bring some.",
	CAPTURE_SHAKING        = "The net is moving…",
	CAPTURE_GOT            = "Captured!",
	CAPTURE_FLED           = "Got away…",
	CAPTURE_MSG_OK         = "%s captured! It joins your collection (companion looks).",
	CAPTURE_MSG_FAIL       = "%s got away.",
	CAPTURE_MSG_ITEM       = "You find: %s (%d in your pack).",
	CAPTURE_MSG_FULL       = "%s: your pack is full of them.",
	CAPTURE_MSG_GIFT       = "%d captures! Your companion gives you a %s.",
	CAPTURE_MSG_SUMMARY    = "Creatures: %d creatures captured (%d tries). Aids: %s.",
	CAPTURE_MSG_EMPTY      = "Your collection is empty: defeat a monster, then click the net on your companion.",
	CAPTURE_RANK_normal    = "Normal",
	CAPTURE_RANK_trivial   = "Trivial",
	CAPTURE_RANK_minus     = "Trivial",
	CAPTURE_RANK_elite     = "Elite",
	CAPTURE_RANK_rare      = "Rare",
	CAPTURE_RANK_rareelite = "Rare elite",
	CAPTURE_RANK_worldboss = "Boss",
	CAPTURE_SHINY_TAG      = "%s (shiny)",
	CAPTURE_SRC            = "Captured on %s",
	OPT_DAILY_CAPTURE      = "Capture defeated monsters",
	OPT_DAILY_CAPTURE_DESC = "Defeated monsters worth catching wait 30 s after combat: a net on your companion captures them (right-click: the list). They become companion looks.",
	HELP_CAPTURE           = "/qc capture -- your collection and capture aids",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CAPTURE_STRINGS = { fr = FR, en = EN } end

-- Répliques : même mécanique que les autres réservoirs (CompanionLines.lua).
-- Ton voulu par les joueurs : un compagnon taquin, qui se moque gentiment.
local P = {
	CAPTURE_PROMPT = {   -- %s = la créature
		{ "%s est KO. On l'embarque ?", "%s is down. Shall we take it home?" },
		{ "Vite, %s ne bouge plus : c'est le moment !", "Quick, %s isn't moving: now's our chance!" },
		{ "%s ferait un super compagnon… enfin, presque aussi bien que moi.", "%s would make a great companion… almost as good as me." },
		{ "Tu le laisses là, %s ? Moi je dis : filet !", "You're leaving %s there? I say: net!" },
		{ "%s, dans ma collection ? Clique, clique !", "%s, in my collection? Click, click!" },
		{ "On tente %s ? Promis, je partage ma gamelle.", "Try for %s? I promise I'll share my bowl." },
	},
	CAPTURE_OK = {   -- %s = la créature
		{ "%s est à nous ! Bienvenue dans la bande !", "%s is ours! Welcome to the crew!" },
		{ "Capturé ! %s, je te préviens : la place près du feu est à moi.", "Captured! %s, fair warning: the spot by the fire is mine." },
		{ "Et hop, %s dans la collection. Quel talent… le mien, surtout.", "And there, %s in the collection. Such talent… mostly mine." },
		{ "%s capturé ! Tu vois, quand tu m'écoutes…", "%s captured! See what happens when you listen to me…" },
		{ "Un %s tout neuf ! Je lui apprends les bonnes manières.", "A brand-new %s! I'll teach it some manners." },
		{ "Gagné ! %s fait déjà les yeux doux à mes friandises.", "Got it! %s is already eyeing my treats." },
	},
	CAPTURE_FAIL = {   -- %s = la créature
		{ "%s s'est fait la malle. Ton lancer, c'était… audacieux.", "%s ran off. That throw was… bold." },
		{ "Raté ! Même %s avait pitié de toi.", "Missed! Even %s felt sorry for you." },
		{ "%s s'échappe. Tu visais quoi, exactement ? La lune ?", "%s escapes. What were you aiming at? The moon?" },
		{ "Le filet est vide. %s te salue de loin, très loin.", "The net is empty. %s waves at you from far, far away." },
		{ "%s s'en va. Je dirai à personne. Enfin, à presque personne.", "%s is gone. I won't tell anyone. Well, almost anyone." },
		{ "%s, 1 — toi, 0. On retente sur le prochain ?", "%s 1, you 0. Try again on the next one?" },
		{ "%s était à deux doigts… les tiens étaient ailleurs.", "%s was so close… your fingers were elsewhere." },
		{ "Tu lances comme tu cours au cimetière : %s a filé.", "You throw like you run back from the graveyard: %s fled." },
	},
	CAPTURE_ITEM = {   -- %s = l'aide trouvée
		{ "Oh, un %s ! Ça va nous servir.", "Oh, a %s! That'll come in handy." },
		{ "%s trouvé ! Range-le bien, pas comme tes potions.", "Found a %s! Keep it safe, unlike your potions." },
		{ "Tiens, un %s. Le prochain monstre n'a qu'à bien se tenir.", "Look, a %s. The next monster had better behave." },
	},
	CAPTURE_SHINY = {   -- %s = la créature
		{ "Un %s BRILLANT capturé ! Je pleure. De joie. Un peu de jalousie.", "A SHINY %s captured! I'm crying. With joy. And a bit of envy." },
		{ "%s brillant dans la collection… tu vas le mettre en vitrine ?", "A shiny %s in the collection… putting it on display?" },
	},
}
-- enregistrement commun (CompanionLines.lua) ; listes de clés en test seulement
local POOLS = ns.RegisterCompanionLines(P)
ns.CAPTURE_POOLS = POOLS

ns.RegisterDefaults({ companionCapture = true })
if type(ns.DAILY_OPTION_ROWS) == "table" then
	local present = false
	for _, row in ipairs(ns.DAILY_OPTION_ROWS) do if row.key == "companionCapture" then present = true end end
	if not present then
		table.insert(ns.DAILY_OPTION_ROWS, 1, { key = "companionCapture", label = "OPT_DAILY_CAPTURE", kind = "bool",
			describe = function() return L.OPT_DAILY_CAPTURE_DESC end })
	end
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function ModuleOn() return ns.CompanionOn and ns.CompanionOn() or false end
local function Enabled() return ModuleOn() and ns:DB().companionCapture ~= false end

-- ---------------------------------------------------------------------------
-- Données (par personnage, avec le compagnon)
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Collection au compte (2.9.0, idée de Deklatis) : une seule table de capture
-- pour tous tes personnages, QuestCompanionDB.capture. Chaque personnage y
-- verse une fois sa collection d'avant (char.companion.capture, gardée telle
-- quelle) : les deux versions de chaque espèce, les meilleures étoiles, les
-- dates les plus anciennes ; les aides s'additionnent, dans la limite de la
-- besace. Le compagnon choisi reste propre à chaque personnage.
-- ---------------------------------------------------------------------------
local function Earliest(a, b)
	a, b = tonumber(a), tonumber(b)
	if a and b then return math.min(a, b) end
	return a or b
end
local function Best(a, b)
	a, b = tonumber(a), tonumber(b)
	if a and b then return math.max(a, b) end
	return a or b
end

-- fiche d'avant 1.6.0 (sans `normal`) : la brillante était la seule version
local function Legacy(entry)
	if entry.normal == nil then
		entry.normal = not entry.shiny
		if entry.shiny and not entry.shinyAt then entry.shinyAt = entry.at end
	end
	return entry
end

local function MergeEntry(into, from)
	Legacy(into)
	local hasN = (into.normal ~= false) or (from.normal ~= false)
	local hasS = (into.shiny == true) or (from.shiny == true)
	for k, v in pairs(from) do if into[k] == nil then into[k] = v end end
	into.normal, into.shiny = hasN, hasS or nil
	into.at = Earliest(into.at, from.at)
	into.shinyAt = Earliest(into.shinyAt, from.shinyAt)
	into.stars = Best(into.stars, from.stars)
	into.shinyStars = Best(into.shinyStars, from.shinyStars)
end

-- verse la collection `old` (celle d'un personnage) dans le compte
function ns.CaptureMergeInto(account, old)
	if type(old) ~= "table" then return 0 end
	local added = 0
	for npcID, entry in pairs(type(old.creatures) == "table" and old.creatures or {}) do
		if type(entry) == "table" then
			local key = tonumber(npcID) or npcID
			local mine = account.creatures[key]
			if mine == nil then
				mine = {}
				for k, v in pairs(entry) do mine[k] = v end
				account.creatures[key] = Legacy(mine)
				added = added + 1
			else
				local copy = {}
				for k, v in pairs(entry) do copy[k] = v end
				MergeEntry(mine, Legacy(copy))
			end
		end
	end
	for _, aid in ipairs(AIDS) do
		local have = tonumber(account.items[aid.id]) or 0
		local more = tonumber(type(old.items) == "table" and old.items[aid.id]) or 0
		account.items[aid.id] = math.min(aid.cap, math.max(0, math.floor(have + more)))
	end
	account.tries = (tonumber(account.tries) or 0) + (tonumber(old.tries) or 0)
	return added
end

local function CountSpecies(creatures)
	local n = 0
	for _, entry in pairs(creatures) do if type(entry) == "table" then n = n + 1 end end
	return n
end

-- La table du compte ; à sa création, tous les personnages connus y versent
-- leur collection ; un personnage jamais vu y verse la sienne à son arrivée
function ns:CaptureAccount()
	local db = self:DB()
	local account = db.capture
	if type(account) ~= "table" then
		account = { creatures = {}, items = {}, count = 0, tries = 0, mergedFrom = {} }
		db.capture = account
		for key, char in pairs(type(db.chars) == "table" and db.chars or {}) do
			local old = type(char) == "table" and type(char.companion) == "table" and char.companion.capture
			if type(old) == "table" then ns.CaptureMergeInto(account, old) end
			account.mergedFrom[key] = true
		end
		account.count = CountSpecies(account.creatures)
	end
	account.creatures = type(account.creatures) == "table" and account.creatures or {}
	account.items = type(account.items) == "table" and account.items or {}
	account.mergedFrom = type(account.mergedFrom) == "table" and account.mergedFrom or {}
	if not self.captureMergedChar then
		self.captureMergedChar = true
		local key = self:CharKey()
		if not account.mergedFrom[key] then
			account.mergedFrom[key] = true
			local char = self:CharData()
			local old = type(char.companion) == "table" and char.companion.capture
			if type(old) == "table" then
				ns.CaptureMergeInto(account, old)
				account.count = CountSpecies(account.creatures)
			end
		end
	end
	return account
end

function ns:CaptureData()
	local capture = self:CaptureAccount()
	capture.creatures = type(capture.creatures) == "table" and capture.creatures or {}
	capture.items = type(capture.items) == "table" and capture.items or {}
	for _, aid in ipairs(AIDS) do
		capture.items[aid.id] = math.max(0, math.floor(tonumber(capture.items[aid.id]) or 0))
	end
	capture.count = math.max(0, math.floor(tonumber(capture.count) or 0))
	capture.tries = math.max(0, math.floor(tonumber(capture.tries) or 0))
	-- 1.6.0 : deux versions par espèce, la normale (normal, at) et la
	-- brillante (shiny, shinyAt). Avant, capturer la brillante remplaçait la
	-- fiche : elle devient la version brillante, la normale reste à capturer.
	-- Pas à chaque lecture : CaptureData est lue dans des boucles chaudes
	-- (CaptureHas, CaptureStars). Le parcours ne se refait que si le nombre
	-- d'espèces a bougé depuis le dernier (pairN) ; les fiches écrites par
	-- l'addon ont toujours `normal`.
	if capture.pairN ~= capture.count then
		for _, entry in pairs(capture.creatures) do
			if type(entry) == "table" and entry.normal == nil then
				entry.normal = not entry.shiny
				if entry.shiny and not entry.shinyAt then entry.shinyAt = entry.at end
			end
		end
		capture.pairN = capture.count
	end
	return capture
end

-- Cette version de l'espèce est-elle capturée ? shiny : la brillante
function ns:CaptureHas(npcID, shiny)
	local entry = self:CaptureData().creatures[tonumber(npcID) or npcID]
	if type(entry) ~= "table" then return false end
	if shiny then return entry.shiny == true end
	return entry.normal ~= false
end

-- Nombre de brillantes capturées
function ns:CaptureShinyCount()
	local count = 0
	for _, entry in pairs(self:CaptureData().creatures) do
		if type(entry) == "table" and entry.shiny then count = count + 1 end
	end
	return count
end

function ns:CaptureState()
	local state = self.captureState
	if not state then
		state = {}
		self.captureState = state
	end
	return state
end

function ns:CaptureAidCount(id) return self:CaptureData().items[id] or 0 end
function ns:CaptureAidLabel(id) return L["CAPTURE_aid_" .. tostring(id)] end

function ns:CaptureIsCaptured(npcID)
	return self:CaptureData().creatures[tonumber(npcID) or npcID] ~= nil
end

-- ---------------------------------------------------------------------------
-- Chance
-- ---------------------------------------------------------------------------
-- `info` : { class, level } ; `aidID` : aide choisie (ou nil). Renvoie la
-- chance (0..1) et true si la capture est assurée.
function ns:CaptureChance(info, aidID, playerLevel)
	local aid = aidID and AID_BY_ID[aidID]
	if aid and aid.sure then return 1, true end
	local base = ns.CAPTURE_RATES[(info and info.class) or "normal"] or ns.CAPTURE_RATES.normal
	local factor = 1
	local level = tonumber(info and info.level)
	local mine = tonumber(playerLevel or ns.Plain(Call(G("UnitLevel"), "player")))
	if level and level > 0 and mine and mine > 0 then
		local diff, step = level - mine, ns.CAPTURE_LEVEL_STEP
		if diff > 0 then factor = math.max(step.floor, 1 - step.above * diff)
		elseif diff < 0 then factor = math.min(step.ceil, 1 - step.below * diff) end
	end
	local chance = base * factor * (aid and aid.mult or 1)
	return math.max(0, math.min(ns.CAPTURE_MAX, chance)), false
end

-- ---------------------------------------------------------------------------
-- Aides : gagner, dépenser
-- ---------------------------------------------------------------------------
local function Draw()
	local total = 0
	for _, entry in ipairs(DRAW) do total = total + entry[2] end
	local roll = math.random() * total
	for _, entry in ipairs(DRAW) do
		roll = roll - entry[2]
		if roll < 0 then return entry[1] end
	end
	return DRAW[1][1]
end
ns.CaptureDraw = Draw

-- Renvoie "ok" (rangée) ou "full" (besace pleine) ; opts.quiet : sans bulle
function ns:CaptureGrant(id, opts)
	opts = opts or {}
	if id == "draw" then id = Draw() end
	local aid = AID_BY_ID[id]
	if not aid then return nil end
	local items = self:CaptureData().items
	local label = self:CaptureAidLabel(id)
	if items[id] >= aid.cap then
		if not opts.silent then self:Print(self:F("CAPTURE_MSG_FULL", label)) end
		return "full", id
	end
	items[id] = items[id] + 1
	if not opts.silent then self:Print(self:F("CAPTURE_MSG_ITEM", label, items[id])) end
	if not opts.quiet then self:CompanionSay("CAPTURE_ITEM", { args = { label } }) end
	self:CaptureRefreshPrompt()
	return "ok", id
end

function ns:CaptureSpend(id)
	local items = self:CaptureData().items
	if not (id and AID_BY_ID[id]) or (items[id] or 0) <= 0 then return false end
	items[id] = items[id] - 1
	return true
end

-- Une bulle un peu plus tard : celle du tampon ou du palier passe d'abord
ns.CAPTURE_SAY_DELAY = 6
function ns:CaptureSayLater(pool, arg)
	local timer = G("C_Timer")
	if type(timer) == "table" and type(timer.After) == "function" then
		pcall(timer.After, ns.CAPTURE_SAY_DELAY, function() ns:CompanionSay(pool, { args = { arg } }) end)
	else
		self:CompanionSay(pool, { args = { arg } })
	end
end

-- Tampon du carnet : une chance d'aide selon sa sorte
function ns:CaptureOnStamp(stamp)
	if type(stamp) ~= "table" or stamp.new == false or not Enabled() then return nil end
	local drop = STAMP_DROPS[stamp.kind or ""]
	if not drop then return nil end
	local got = {}
	-- le chat suit le réglage du carnet (« Tampons dans le chat », coupé par
	-- défaut) : la bulle du compagnon suffit
	local silent = self:DB().journalChat ~= true
	if math.random() < drop.chance then
		local result, id = self:CaptureGrant(drop.pick, { quiet = true, silent = silent })
		if result == "ok" then got[#got + 1] = id end
	end
	if drop.bonus and math.random() < drop.bonus.chance then
		local result, id = self:CaptureGrant(drop.bonus.pick, { quiet = true, silent = silent })
		if result == "ok" then got[#got + 1] = id end
	end
	-- une seule bulle pour le lot, APRÈS celle du tampon (qui a la priorité)
	if #got > 0 then self:CaptureSayLater("CAPTURE_ITEM", self:CaptureAidLabel(got[#got])) end
	return got
end

ns:RegisterCallback("STAMP", function(self, stamp)
	local ok, err = pcall(self.CaptureOnStamp, self, stamp)
	if not ok and self.RecordError then self:RecordError("capture:stamp", err) end
end)

-- Paliers de complétion de zone (25, 50, 75 %) : en plus de la friandise
do
	local check = ns.TreatCheckZone
	if check then
		function ns:TreatCheckZone(zoneID, opts, ...)
			local gained = check(self, zoneID, opts, ...)
			if type(gained) == "table" and #gained > 0 and Enabled() then
				local ok, err = pcall(function()
					local last
					local silent = (opts and opts.quiet) or self:DB().journalChat ~= true
					for _, gain in ipairs(gained) do
						local pick = MILESTONE_DROPS[gain.mark]
						if pick then
							local result, id = self:CaptureGrant(pick, { quiet = true, silent = silent })
							if result == "ok" then last = id end
						end
					end
					-- rattrapage (mise à jour) : ni bulle ni chat
					if last and not (opts and opts.quiet) then self:CaptureSayLater("CAPTURE_ITEM", self:CaptureAidLabel(last)) end
				end)
				if not ok and self.RecordError then self:RecordError("capture:milestone", err) end
			end
			return gained
		end
	end
end

-- ---------------------------------------------------------------------------
-- La ménagerie comme apparences du compagnon (Companion.lua)
-- ---------------------------------------------------------------------------
-- Définitions façon catalogue : { id = "cap:<npc>", npc, label = nom, captured }
-- (L rend la clé elle-même quand elle manque : le nom s'affiche tel quel).
function ns:CaptureAppearances()
	local data = self:CaptureData()
	local cache = self.captureAppCache
	if cache and cache.count == data.count and cache.n == data.serial and cache.creatures == data.creatures then return cache.list end
	local list = {}
	-- une apparence par version capturée : « cap:<npc> » et « cap:<npc>:s »
	for npcID, entry in pairs(data.creatures) do
		-- 2.14.0 (bêta 4) : jamais le numéro quand un nom existe (rendu à la fiche)
		local name = self.CreatureName and self:CreatureName(npcID, entry) or tostring(entry.name or npcID)
		if entry.normal ~= false then
			list[#list + 1] = { id = "cap:" .. tostring(npcID), npc = tonumber(npcID), label = name,
				captured = true, class = entry.class, at = entry.at }
		end
		if entry.shiny then
			list[#list + 1] = { id = "cap:" .. tostring(npcID) .. ":s", npc = tonumber(npcID),
				label = self:F("CAPTURE_SHINY_TAG", name), captured = true, class = entry.class,
				at = entry.shinyAt or entry.at, shiny = true }
		end
	end
	table.sort(list, function(a, b)
		if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) < (b.at or 0) end
		return a.id < b.id
	end)
	self.captureAppCache = { count = data.count, n = data.serial, creatures = data.creatures, list = list }
	return list
end

-- ---------------------------------------------------------------------------
-- La ménagerie comme un Pokédex : TOUTES les créatures capturables du jeu
-- (la table des zones livrée avec l'addon, ns.ZONE_CREATURES, filtrée par
-- ta faction), plus celles apprises en route qui n'y sont pas. Numéro fixe :
-- zones par niveau, puis niveau de la créature, puis son identifiant.
-- ---------------------------------------------------------------------------
local RANK_GROUP = { normal = "normal", trivial = "normal", minus = "normal", elite = "elite",
	rare = "rare", rareelite = "rare", worldboss = "boss" }
local RANK_ORDER = { trivial = 0, minus = 0, normal = 1, elite = 2, rare = 3, rareelite = 4, worldboss = 5 }
ns.MENAGERIE_RANK_GROUP = RANK_GROUP

local function ZoneLevel(zoneID)
	local levels = ns.ZONE_LEVELS and ns.ZONE_LEVELS[zoneID]
	return levels and levels[1] or 99
end

-- Partie fixe (la table livrée), calculée une fois par faction
function ns:MenagerieCatalog()
	local faction = self.BestiaryFaction and self:BestiaryFaction() or nil
	local cache = self.menagerieStatic
	if cache and cache.faction == faction then return cache end
	local all = rawget(ns, "ZONE_CREATURES")
	local zones = {}
	for _, zoneID in ipairs(ns.ZoneIds(all)) do zones[#zones + 1] = zoneID end
	-- chaque zone lue une fois pour l'occasion (table paresseuse : rien n'est gardé)
	local byZone = {}
	ns.ZoneEach(all, function(zoneID, zone) byZone[zoneID] = zone end)
	table.sort(zones, function(a, b)
		if ZoneLevel(a) ~= ZoneLevel(b) then return ZoneLevel(a) < ZoneLevel(b) end
		return a < b
	end)
	local byNpc, list = {}, {}
	for order, zoneID in ipairs(zones) do
		for npcID, entry in pairs(byZone[zoneID] or {}) do
			local npc = tonumber(npcID)
			local f = type(entry) == "table" and entry.f
			local forYou = f == nil or (faction ~= nil and not tostring(f):find(faction, 1, true))
			if npc and type(entry) == "table" and forYou then
				local item = byNpc[npc]
				if not item then
					local lvl = type(entry.lvl) == "table" and entry.lvl or {}
					item = { npc = npc, staticName = self.BestiaryStaticName and self:BestiaryStaticName(entry) or entry.fr,
						class = (ns.BESTIARY_RANK_CLASS and ns.BESTIARY_RANK_CLASS[tonumber(entry.rank) or 0]) or "normal",
						lo = tonumber(lvl[1]), hi = tonumber(lvl[2]) or tonumber(lvl[1]), zones = {}, zoneOrder = order }
					byNpc[npc] = item
					list[#list + 1] = item
				end
				item.zones[#item.zones + 1] = zoneID
			end
		end
	end
	table.sort(list, function(a, b)
		if a.zoneOrder ~= b.zoneOrder then return a.zoneOrder < b.zoneOrder end
		if (a.lo or 0) ~= (b.lo or 0) then return (a.lo or 0) < (b.lo or 0) end
		return a.npc < b.npc
	end)
	for index, item in ipairs(list) do item.no = index end
	cache = { faction = faction, byNpc = byNpc, list = list, count = #list, zones = zones }
	self.menagerieStatic = cache
	return cache
end

-- Zones de la table, triées par niveau (liste du filtre « zone »)
function ns:MenagerieZones()
	return self:MenagerieCatalog().zones
end

local function Fold(text)
	if ns.OptionFold then return ns.OptionFold(text) end
	return string.lower(tostring(text or ""))
end

-- opts : { zone = uiMapID | "all", state = "all" | "captured" | "missing" |
-- "tokill", rank = "all" | "normal" | "elite" | "rare" | "boss", search = texte,
-- ctype = clé de type (CreatureTypes.lua) ou nil, sort = "no" | "name" |
-- "level" | "rank" | "date" | "kills" }. Rend la liste et le compte de la
-- portée (zone choisie) : { total, known, captured, killed, types }, où
-- types[clé] = { known, captured } (espèces croisées seulement : le type
-- d'une inconnue n'est jamais dit).
-- Entrées : { npc, no, name, known, class, lo, hi, level, type, zones,
-- zoneID, killed, captured, shiny, at }. Une espèce jamais croisée garde son
-- nom (name) mais `known` est faux : la fenêtre l'affiche « ??? ».
function ns:MenagerieList(opts)
	if type(opts) == "string" then opts = { state = opts, zone = "all" } end
	opts = opts or {}
	local catalog = self:MenagerieCatalog()
	local data = self:CaptureData()
	data.dexExtra = type(data.dexExtra) == "table" and data.dexExtra or {}
	data.dexExtraNext = math.max(1, math.floor(tonumber(data.dexExtraNext) or 1))
	local view = {}
	local function Item(npc, base)
		local item = view[npc]
		if item then return item end
		item = { npc = npc, killed = 0, zones = {} }
		if base then
			item.no, item.name, item.class, item.lo, item.hi = base.no, base.staticName, base.class, base.lo, base.hi
			for _, zoneID in ipairs(base.zones) do item.zones[#item.zones + 1] = zoneID end
		end
		view[npc] = item
		return item
	end
	for _, base in ipairs(catalog.list) do Item(base.npc, base) end
	-- ce que le carnet a appris en route (nom du client, type, niveau vu)
	local book = self.BestiaryData and self:BestiaryData() or {}
	for zoneID, zone in pairs(book) do
		if type(zone) == "table" then
			for npcID, species in pairs(zone) do
				local npc = tonumber(npcID)
				if npc and type(species) == "table" then
					local item = Item(npc, catalog.byNpc[npc])
					if species.name and species.name ~= tostring(npc) then item.name = species.name end
					item.type = species.type or item.type
					item.level = tonumber(species.level) or item.level
					if not catalog.byNpc[npc] then item.class = species.class or item.class end
					item.killed = item.killed + (tonumber(species.killed) or 0)
					-- une brillante abattue ici (Shiny.lua) : date gardée pour la fiche
					local shinyAt = self.ShinyFound and self:ShinyFound(zoneID, npcID)
					if shinyAt then item.shinyKilled = shinyAt end
					if species.seen or (tonumber(species.killed) or 0) > 0 then item.known = true end
					local listed = false
					for _, z in ipairs(item.zones) do if z == zoneID then listed = true end end
					if not listed then item.zones[#item.zones + 1] = zoneID end
				end
			end
		end
	end
	for npcID, known in pairs(data.creatures) do
		local npc = tonumber(npcID)
		if npc then
			local item = Item(npc, catalog.byNpc[npc])
			item.name = item.name or (self.CreatureName and self:CreatureName(npc, known)) or known.name
			item.class = item.class or known.class
			item.type = item.type or known.type
			item.level = item.level or tonumber(known.level)
			-- captured : au moins une version ; normal / shiny : chacune
			item.captured, item.known = true, true
			item.normal, item.shiny = known.normal ~= false, known.shiny == true
			item.at, item.shinyAt = known.at, known.shinyAt
			if known.zoneID and #item.zones == 0 then item.zones[1] = known.zoneID end
		end
	end
	-- numéros des espèces hors table : à la suite, et ils ne bougent plus
	local fresh = {}
	for npc, item in pairs(view) do
		if not item.no then
			local extra = data.dexExtra[npc]
			if extra then item.no = catalog.count + extra else fresh[#fresh + 1] = item end
		end
	end
	table.sort(fresh, function(a, b) return a.npc < b.npc end)
	for _, item in ipairs(fresh) do
		data.dexExtra[item.npc] = data.dexExtraNext
		item.no = catalog.count + data.dexExtraNext
		data.dexExtraNext = data.dexExtraNext + 1
	end

	local zone = opts.zone or "all"
	local state, rank = opts.state or "all", opts.rank or "all"
	local query = Fold(opts.search or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local ctype = opts.ctype ~= "all" and opts.ctype or nil
	local stats = { total = 0, known = 0, captured = 0, killed = 0, shinySeen = 0, shinies = 0, types = {} }
	local list = {}
	for _, item in pairs(view) do
		item.name = item.name or (self.CreatureName and self:CreatureName(item.npc)) or tostring(item.npc)
		item.class = item.class or "normal"
		local here = zone == "all"
		if not here then
			for _, z in ipairs(item.zones) do if z == zone then here = true end end
		end
		if here then
			item.zoneID = zone ~= "all" and zone or item.zones[1]
			stats.total = stats.total + 1
			if item.known then stats.known = stats.known + 1 end
			if item.captured then stats.captured = stats.captured + 1 end
			if item.killed > 0 then stats.killed = stats.killed + 1 end
			-- brillante reconnue (repérée, abattue ou capturée) : pas besoin de la capturer
			item.shinySeen = item.shinySeen or item.shinyKilled or (self.ShinyKnown and self:ShinyKnown(item.npc)) or (item.shiny and item.shinyAt) or nil
			if item.shinySeen then stats.shinySeen = (stats.shinySeen or 0) + 1 end
			if item.shiny then stats.shinies = (stats.shinies or 0) + 1 end
			-- type : seulement pour une espèce croisée (une inconnue ne dit rien)
			item.typeKey = item.known and self.CreatureTypeKey and self:CreatureTypeKey(item.type) or nil
			if item.typeKey then
				local count = stats.types[item.typeKey] or { known = 0, captured = 0 }
				stats.types[item.typeKey] = count
				count.known = count.known + 1
				if item.captured then count.captured = count.captured + 1 end
			end
			local keep = (state == "all") or (state == "captured" and item.captured)
				or (state == "missing" and not item.captured) or (state == "tokill" and item.killed == 0)
				or (state == "shiny" and item.shinySeen ~= nil)
			keep = keep and (rank == "all" or RANK_GROUP[item.class] == rank)
			keep = keep and (ctype == nil or item.typeKey == ctype)
			-- recherche : sur les noms connus seulement (une inconnue reste « ??? »)
			if keep and query ~= "" then keep = item.known and Fold(item.name):find(query, 1, true) ~= nil end
			if keep then list[#list + 1] = item end
		end
	end
	local sort = opts.sort or "no"
	table.sort(list, function(a, b)
		if sort == "name" then
			if a.known ~= b.known then return a.known == true end
			local fa, fb = Fold(a.name), Fold(b.name)
			if fa ~= fb then return fa < fb end
		elseif sort == "level" then
			local la, lb = a.level or a.lo or 0, b.level or b.lo or 0
			if la ~= lb then return la < lb end
		elseif sort == "rank" then
			local ra, rb = RANK_ORDER[a.class] or 1, RANK_ORDER[b.class] or 1
			if ra ~= rb then return ra > rb end
		elseif sort == "kills" then
			if (a.killed or 0) ~= (b.killed or 0) then return (a.killed or 0) > (b.killed or 0) end
		elseif sort == "date" then
			if (a.captured == true) ~= (b.captured == true) then return a.captured == true end
			if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) > (b.at or 0) end
		end
		return a.no < b.no
	end)
	return list, stats
end

-- ---------------------------------------------------------------------------
-- Le coup fatal : on propose la capture
-- ---------------------------------------------------------------------------
-- `entry` : { zoneID, npcID } (Bestiary.lua) ; `shiny` : brillante abattue
function ns:CaptureOffer(guid, entry, shiny)
	if not Enabled() or type(entry) ~= "table" or not entry.npcID then return nil end
	local state = self:CaptureState()
	if state.rolling then return nil end              -- un filet à la fois
	local npcID = tonumber(entry.npcID) or entry.npcID
	-- chaque version se capture une fois : la normale, et la brillante à part
	if self:CaptureHas(npcID, shiny and true or false) then return nil end
	local book = self.BestiaryData and self:BestiaryData()
	local species = book and book[entry.zoneID] and book[entry.zoneID][entry.npcID] or {}
	-- 2.14.0 (bêta 4) : sans nom lu, celui du carnet, de la table livrée ou du client
	local name = species.name
	if not ns.CreatureNameGood(name, npcID) and type(shiny) == "table" then name = shiny.name end
	name = self:CreatureName(npcID, { name = name })
	state.pending = {
		guid = guid, npcID = npcID, zoneID = entry.zoneID, name = name,
		class = species.class or "normal", level = species.level, type = species.type,
		family = species.family, shiny = shiny and true or nil,
		expires = Clock() + ns.CAPTURE_WINDOW,
	}
	-- l'aide choisie la dernière fois reste choisie s'il en reste
	if state.aid and self:CaptureAidCount(state.aid) <= 0 then state.aid = nil end
	self:CaptureShowPrompt()
	self:CompanionSay("CAPTURE_PROMPT", { args = { name } })
	return state.pending
end

-- Le tirage d'un essai sur `target` : l'aide dépensée (sinon l'essai se fait
-- sans), la chance, le verdict et les secousses ; un essai de plus compté.
-- Partagé par le lancer (ci-dessous) et la capture en lot (CaptureBatch.lua).
-- Renvoie le lancer { target, success, shakes, done, aid, chance }, que
-- ns:CaptureResolve tranche ensuite.
function ns:CaptureRoll(target, aid)
	if aid and not self:CaptureSpend(aid) then aid = nil end
	local chance, sure = self:CaptureChance(target, aid)
	local data = self:CaptureData()
	-- une espèce déjà à toi (cette version) : un essai de recapture compté (2.9.0)
	local owned = target and data.creatures[tonumber(target.npcID) or target.npcID]
	if type(owned) == "table" and (target.shiny and owned.shiny or (not target.shiny and owned.normal ~= false)) then
		if target.shiny then owned.shinyRetries = (tonumber(owned.shinyRetries) or 0) + 1
		else owned.retries = (tonumber(owned.retries) or 0) + 1 end
	end
	-- malchance : chaque échec d'affilée rend le filet un peu plus sûr
	local streak = math.min(ns.CAPTURE_PITY.max, tonumber(data.missStreak) or 0)
	if not sure and streak > 0 then chance = math.min(ns.CAPTURE_MAX, chance + ns.CAPTURE_PITY.step * streak) end
	local success = sure or math.random() < chance
	data.missStreak = success and 0 or (streak + 1)
	-- comme un filet qui se débat : trois secousses pour une prise, une à
	-- trois avant de céder pour un échec
	local shakes = success and 3 or math.random(1, 3)
	data.tries = data.tries + 1
	return { target = target, success = success, shakes = shakes, done = 0, aid = aid, chance = chance }
end

-- Un essai. Renvoie true si le filet est lancé.
function ns:CaptureThrow()
	local state = self:CaptureState()
	local pending = state.pending
	if not pending or state.rolling then return false end
	if Clock() > pending.expires then
		state.pending = nil
		self:CaptureHidePrompt()
		return false
	end
	local rolling = self:CaptureRoll(pending, state.aid)
	state.pending = nil
	-- scène animée (CaptureStage.lua) : le lancer du filet passe avant les secousses
	local staged = self.CaptureStageOn and self:CaptureStageOn() or false
	local now = Clock()
	rolling.start, rolling.staged = now, staged or nil
	rolling.nextAt = now + (staged and ns.CAPTURE_THROW_TIME or 0) + ns.CAPTURE_SHAKE_STEP
	state.rolling = rolling
	if staged then
		self:CaptureHidePrompt()
		self:CaptureShowStage(state.rolling)
	else
		self:CaptureRefreshPrompt()
	end
	if self.CompanionFx then self:CompanionFx("shake") end
	return true
end

function ns:CaptureResolve(rolling)
	local target = rolling.target
	local data = self:CaptureData()
	if rolling.success then
		-- une fiche par espèce, deux versions dedans (1.6.0) : une créature de
		-- plus seulement si l'espèce est nouvelle
		local fresh = data.creatures[target.npcID] == nil
		local now = Call(G("time")) or 0
		local entry = data.creatures[target.npcID] or { normal = false }
		entry.name, entry.class, entry.level = target.name, target.class, target.level or entry.level
		entry.type, entry.family = target.type or entry.type, target.family or entry.family
		entry.zoneID = entry.zoneID or target.zoneID
		if target.shiny then
			entry.shiny, entry.shinyAt = true, now
			entry.at = entry.at or now
		else
			entry.normal, entry.at = true, now
		end
		data.creatures[target.npcID] = entry
		if fresh then data.count = data.count + 1 end
		if target.shiny and self.WeeklyEvent then pcall(self.WeeklyEvent, self, "shinyCapture", 1) end
		-- missions : une capture (et une capture d'élite ou de rare)
		if self.MissionEvent then pcall(self.MissionEvent, self, "captures", 1) end
		if self.WeeklyEvent then
			pcall(self.WeeklyEvent, self, "captures", 1)
			local named = target.class == "elite" or target.class == "rare" or target.class == "rareelite" or target.class == "worldboss"
			if named then pcall(self.WeeklyEvent, self, "captureNamed", 1) end
		end
		data.serial = (tonumber(data.serial) or 0) + 1
		self.captureAppCache = nil
		-- une recapture (étoiles, CaptureQueue.lua) a son propre message : pas « il rejoint ta ménagerie »
		if not rolling.starsBefore then self:Print(self:F("CAPTURE_MSG_OK", target.name)) end
		self:CompanionSay(target.shiny and "CAPTURE_SHINY" or "CAPTURE_OK", { force = true, args = { target.name } })
		if self.CompanionFx then self:CompanionFx("bounce"); self:CompanionFx("hearts") end
		self:CompanionAdd("mood", 5)
		if fresh and data.count % ns.CAPTURE_GIFT_EVERY == 0 then
			-- besace de sifflets pleine : le message le dit (CaptureGrant)
			local result = self:CaptureGrant("sifflet", { quiet = true, silent = true })
			if result == "ok" then self:Print(self:F("CAPTURE_MSG_GIFT", data.count, self:CaptureAidLabel("sifflet")))
			else self:Print(self:F("CAPTURE_MSG_FULL", self:CaptureAidLabel("sifflet"))) end
		end
		if self.RefreshOptions then pcall(self.RefreshOptions, self) end
		if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then pcall(self.RefreshJournal, self) end
	else
		self:Print(self:F("CAPTURE_MSG_FAIL", target.name))
		self:CompanionSay("CAPTURE_FAIL", { force = true, args = { target.name } })
	end
	return rolling.success
end

-- Horloge : secousses, puis verdict ; fenêtre expirée : on la ferme
function ns:CaptureTick(now)
	local state = self.captureState
	if not state then return end
	local rolling = state.rolling
	if rolling then
		if now < rolling.nextAt then return end
		rolling.done = rolling.done + 1
		if rolling.done < rolling.shakes then
			rolling.nextAt = now + ns.CAPTURE_SHAKE_STEP
			if self.CompanionFx then self:CompanionFx("shake") end
			self:CaptureRefreshPrompt()
			return
		end
		if not rolling.result then
			-- une seule fois, même si l'annonce plante : sinon chaque tour
			-- recompterait la capture et le filet resterait bloqué
			rolling.result = rolling.success and "ok" or "fail"
			local done, err = pcall(self.CaptureResolve, self, rolling)
			if not done and self.RecordError then self:RecordError("capture:resolve", err) end
			rolling.resultAt = now
			rolling.closeAt = now + (rolling.staged and ns.CAPTURE_STAGE_HOLD or 2)
			self:CaptureRefreshPrompt()
			return
		end
		if now >= (rolling.closeAt or now) then
			state.rolling = nil
			self:CaptureHidePrompt()
			if self.CaptureHideStage then self:CaptureHideStage() end
		end
		return
	end
	local pending = state.pending
	if pending then
		if now > pending.expires then
			state.pending = nil
			self:CaptureHidePrompt()
		else
			self:CaptureRefreshTimer(now)
		end
	end
end

-- Choisir (ou reposer) une aide pour l'essai en cours
function ns:CaptureToggleAid(id)
	local state = self:CaptureState()
	if state.aid == id then state.aid = nil
	elseif AID_BY_ID[id] and self:CaptureAidCount(id) > 0 then state.aid = id end
	self:CaptureRefreshPrompt()
	return state.aid
end

-- Le coup fatal compté par le bestiaire. Chargé après Shiny.lua : la
-- brillante vivante est encore connue ici.
do
	local onKill = ns.BestiaryOnKill
	if onKill then
		function ns:BestiaryOnKill(guid, entry, ...)
			local shinyState = self.shinyState
			local shiny = shinyState and guid and shinyState.live and shinyState.live[guid]
			local result = { onKill(self, guid, entry, ...) }
			local ok, err = pcall(self.CaptureOffer, self, guid, entry, shiny)
			if not ok and self.RecordError then self:RecordError("capture:offer", err) end
			if shiny and Enabled() then pcall(self.CaptureGrant, self, "lasso", { quiet = true }) end
			return unpack(result)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Fenêtre « Capturer ? »
-- ---------------------------------------------------------------------------
local PROMPT_W, PROMPT_H, MODEL_SIZE, AID_SIZE = 304, 104, 64, 26

function ns:EnsureCapturePrompt()
	if self.capturePrompt then return self.capturePrompt end
	if not (Theme and Theme.CreateToast) then return nil end
	local frame = Theme.CreateToast(UIParent, PROMPT_W, PROMPT_H, { strata = "HIGH" })
	if not frame then return nil end
	frame:EnableMouse(true)
	self:RestorePoint(frame, "capturePoint", { point = "BOTTOM", x = 0, y = 260 })
	-- clic droit : on laisse filer
	frame:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" and not ns:CaptureState().rolling then
			ns:CaptureState().pending = nil
			ns:CaptureHidePrompt()
		end
	end)

	local pad = 12
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, frame)
	if ok and model then
		model:SetSize(MODEL_SIZE, MODEL_SIZE)
		model:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
		frame.model = model
	end
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(MODEL_SIZE - 16, MODEL_SIZE - 16)
	frame.icon:SetPoint("CENTER", frame, "TOPLEFT", pad + MODEL_SIZE / 2, -pad - MODEL_SIZE / 2)
	frame.icon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
	frame.icon:Hide()

	local left = pad + MODEL_SIZE + 10
	frame.title = Theme.Text(frame, Theme.F_SMALL, Theme.GOLD)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -pad)
	frame.title:SetText(L.CAPTURE_TITLE)
	frame.name = Theme.Text(frame, Theme.F_BODY, Theme.PARCHMENT)
	frame.name:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
	frame.name:SetWidth(PROMPT_W - left - pad)
	frame.name:SetJustifyH("LEFT")
	if frame.name.SetWordWrap then frame.name:SetWordWrap(false) end
	frame.chance = Theme.Text(frame, Theme.F_SMALL, Theme.MUTED_LIGHT)
	frame.chance:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -3)

	frame.aids = {}
	for index, aid in ipairs(AIDS) do
		local button = Theme.CreateIconButton(frame, AID_SIZE, aid.icon, function() ns:CaptureToggleAid(aid.id) end)
		button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", left + (index - 1) * (AID_SIZE + 6), pad)
		button.count = Theme.Text(button, Theme.F_SMALL, Theme.PARCHMENT)
		button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
		button.aid = aid.id
		-- infobulle : nom, effet, combien en poche
		button:SetScript("OnEnter", function(self)
			local tooltip = G("GameTooltip")
			if type(tooltip) ~= "table" or not tooltip.SetOwner then return end
			tooltip:SetOwner(self, "ANCHOR_TOP")
			local count = ns:CaptureAidCount(aid.id)
			Theme.TooltipLine(tooltip, ns:CaptureAidLabel(aid.id), Theme.PARCHMENT)
			Theme.TooltipLine(tooltip, L["CAPTURE_AID_DESC_" .. aid.id], Theme.TEXT)
			Theme.TooltipLine(tooltip, count > 0 and ns:F("CAPTURE_AID_HINT", count) or L.CAPTURE_AID_NONE, Theme.MUTED_LIGHT)
			tooltip:Show()
		end)
		button:SetScript("OnLeave", function()
			local tooltip = G("GameTooltip")
			if type(tooltip) == "table" and tooltip.Hide then tooltip:Hide() end
			ns:CaptureRefreshPrompt()
		end)
		frame.aids[index] = button
	end

	frame.throw = Theme.CreateButton(frame, 90, Theme.DIALOG_BUTTON_HEIGHT or 28, L.CAPTURE_THROW,
		function() ns:CaptureThrow() end, "primary")
	frame.throw:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad - 2)

	frame.status = Theme.Text(frame, Theme.F_BODY, Theme.GOLD)
	frame.status:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -pad, pad + 12)
	frame.status:SetJustifyH("RIGHT")
	frame.status:Hide()

	if Theme.CreateBar then
		frame.timer = Theme.CreateBar(frame, PROMPT_W - 2, 2)
		frame.timer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
	end
	frame:Hide()
	self.capturePrompt = frame
	return frame
end

function ns:CaptureShowPrompt()
	local frame = self:EnsureCapturePrompt()
	if not frame then return nil end
	local target = self:CaptureState().pending
	if target and frame.model then
		-- 2.11.0 : un seul cadrage (ns.ShowModel, profil « prompt ») ; plus de
		-- zoom « portrait » sur une créature sauvage (il visait la patte)
		local shown = ns.ShowModel(frame.model, { npc = target.npcID, display = target.display, shiny = target.shiny }, "prompt")
		if shown then
			frame.icon:Hide()
		else
			-- 2.11.0 : le portrait 2D de la créature, sinon l'icône de son type
			self:CreaturePortrait(frame.icon, target)
			frame.icon:Show(); frame.model:Hide()
		end
	end
	self:CaptureRefreshPrompt()
	frame:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, frame) end
	return frame
end

function ns:CaptureHidePrompt()
	if self.capturePrompt then self.capturePrompt:Hide() end
end

function ns:CaptureRefreshTimer(now)
	local frame, pending = self.capturePrompt, self.captureState and self.captureState.pending
	if not (frame and frame.timer and pending) then return end
	frame.timer:SetValue((pending.expires - (now or Clock())) / ns.CAPTURE_WINDOW)
end

function ns:CaptureRefreshPrompt()
	local frame = self.capturePrompt
	if not frame then return end
	local state = self:CaptureState()
	-- le lancer se joue sur la scène animée : la petite fenêtre reste fermée
	if state.rolling and state.rolling.staged then return end
	local target = state.pending or (state.rolling and state.rolling.target)
	if not target then return end
	frame.name:SetText(target.shiny and self:F("CAPTURE_SHINY_TAG", target.name) or target.name)
	local rank = L["CAPTURE_RANK_" .. tostring(target.class)]
	local chance, sure = self:CaptureChance(target, state.pending and state.aid)
	if state.rolling then chance, sure = state.rolling.chance, state.rolling.aid == "sifflet" end
	frame.chance:SetText(sure and self:F("CAPTURE_SURE", rank) or self:F("CAPTURE_CHANCE", rank, math.floor(chance * 100 + 0.5 + 1e-9)))
	for _, button in ipairs(frame.aids) do
		local count = self:CaptureAidCount(button.aid)
		button.count:SetText(count > 0 and tostring(count) or "")
		local chosen = state.aid == button.aid and state.pending ~= nil
		if button.icon.SetDesaturated then button.icon:SetDesaturated(not chosen) end
		button.icon:SetAlpha(chosen and 1 or (count > 0 and 0.6 or 0.25))
		local c = chosen and Theme.GOLD or Theme.EDGE
		if button.border and button.border.SetColor then button.border:SetColor(c[1], c[2], c[3], 1) end
		if state.rolling then button:Hide() else button:Show() end
	end
	if state.rolling then
		frame.throw:Hide()
		frame.status:Show()
		local rolling = state.rolling
		if rolling.result == "ok" then
			frame.status:SetText(L.CAPTURE_GOT)
			frame.status:SetTextColor(Theme.GREEN[1], Theme.GREEN[2], Theme.GREEN[3])
		elseif rolling.result == "fail" then
			frame.status:SetText(L.CAPTURE_FLED)
			frame.status:SetTextColor(Theme.RED[1], Theme.RED[2], Theme.RED[3])
		else
			-- une pastille par secousse
			frame.status:SetText(L.CAPTURE_SHAKING .. " " .. string.rep("• ", rolling.done + 1))
			frame.status:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
		end
		if frame.timer then frame.timer:Hide() end
	else
		frame.throw:Show()
		frame.status:Hide()
		if frame.timer then frame.timer:Show() end
		self:CaptureRefreshTimer()
	end
end

-- ---------------------------------------------------------------------------
-- /qc capture
-- ---------------------------------------------------------------------------
function ns:CaptureSummary()
	local data = self:CaptureData()
	local parts = {}
	for _, aid in ipairs(AIDS) do parts[#parts + 1] = self:CaptureAidLabel(aid.id) .. " " .. data.items[aid.id] end
	if data.count == 0 then self:Print(L.CAPTURE_MSG_EMPTY) end
	self:Print(self:F("CAPTURE_MSG_SUMMARY", data.count, data.tries, table.concat(parts, ", ")))
	return data
end

if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_CAPTURE")
		end
	end
end
if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["capture"] = function(self) self:CaptureSummary() end
	ns.EXTRA_COMMANDS["menagerie"] = ns.EXTRA_COMMANDS["capture"]
end

-- ---------------------------------------------------------------------------
-- Horloge
-- ---------------------------------------------------------------------------
ns.CAPTURE_TICK = 0.1
do
	-- 2.11.2 (fiche 25) : sur l'horloge de l'addon (plus d'OnUpdate permanent)
	ns.Every("capture", ns.CAPTURE_TICK, function()
		local done, err = pcall(ns.CaptureTick, ns, Clock())
		if not done and ns.RecordError then ns:RecordError("capture:tick", err) end
	end)
end

if ns.Mark then ns.Mark("Capture") end
