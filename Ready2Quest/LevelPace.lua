-- LevelPace.lua -- module QoL « Rythme de leveling » (v1.24.0)
--
-- Une petite fiche qui répond à « combien avant le prochain niveau ? » :
-- XP/h (session entière et fenêtre glissante), temps estimé, équivalent en
-- monstres et en quêtes, repos restant et ce que rapporterait une déconnexion
-- ici. Affichée au survol de la barre d'XP et par /r2q xp. Le module vit tout
-- entier dans ce fichier (API d'extension de la v1.23.0) ; la seule retouche
-- ailleurs est le point d'entrée ns.EXTRA_COMMANDS de Core.lua (HandleCommand).
--
-- Mesures, et pourquoi celles-ci :
--   * XP : UnitXP relevé à chaque PLAYER_XP_UPDATE / PLAYER_LEVEL_UP. Une XP
--     qui baisse signale un passage de niveau : on ajoute la fin du niveau
--     précédent (même idée que Expedition.lua, sans dépendre de ses locales).
--     Chaque gain est horodaté pour la fenêtre glissante.
--   * monstres : messages CHAT_MSG_COMBAT_XP_GAIN, lus avec les chaînes du
--     client (COMBATLOG_XPGAIN_*), donc dans sa langue, avec un repli fr/en.
--     Le chiffre du message inclut le bonus de repos : c'est bien ce que
--     rapporte un monstre tant que le repos dure.
--   * quêtes : QUEST_TURNED_IN donne l'XP de la récompense (Era). S'il manque
--     ou vaut 0, on retient le premier gain d'XP qui suit l'écran de
--     récompense (QUEST_COMPLETE -> QUEST_FINISHED), sauf s'il vient d'un
--     monstre.
--   * repos (warcraft.wiki.gg, « Rest ») : une bulle de 10 % d'un niveau par
--     16 h de repos à l'auberge ou en capitale, soit 5 % par 8 h ; quatre fois
--     moins vite ailleurs ; plafond de 15 bulles = 150 % du niveau, calculé
--     sur le niveau actuel.
--   * Forever : la tente de camp donne du repos (5 % d'un niveau, guide
--     camping d'icy-veins) ; simple information quand on est au camp.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local MAX_LEVEL_FALLBACK = 60
local REST_PER_HOUR_INN  = 5 / 8          -- % d'un niveau par heure, auberge / capitale
local REST_OUTSIDE_RATIO = 0.25           -- hors repos : quatre fois moins vite
local REST_CAP           = 150            -- % d'un niveau
local PROJECTION_HOURS   = 24             -- « d'ici demain »
local CAMP_REST_PCT      = 5              -- tente de camp (Forever)
local MAX_WINDOW         = 60 * 60        -- on garde au plus une heure de gains
local MIN_ELAPSED        = 60             -- en dessous d'une minute, un taux ne veut rien dire
local KEEP_KILLS         = 10             -- moyenne sur les 10 derniers monstres
local KEEP_QUESTS        = 5              -- et les 5 dernières quêtes
local KILL_GRACE         = 1.5            -- un gain d'XP à moins de 1,5 s d'un monstre lui appartient
local QUEST_GRACE        = 3              -- l'XP de quête arrive juste après la fermeture de la récompense

-- ---------------------------------------------------------------------------
-- Chaînes, réglages, page d'options, module
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_PACE        = "Rythme de leveling",
	OPT_PAGE_PACE_SUB    = "Combien avant le prochain niveau : XP/h, temps, monstres, quêtes et repos.",
	OPT_PACE_TOOLTIP     = "Au survol de la barre d'XP",
	OPT_PACE_WINDOW      = "Fenêtre récente",
	OPT_MIN_UNIT_PACE    = "min",
	HELP_PACE            = "/r2q xp -- rythme de leveling : XP/h, temps avant le prochain niveau",
	PACE_TITLE           = "Rythme de leveling",
	PACE_ROW_RATE        = "XP/h",
	PACE_RATE            = "%s (session) · %s (%d min)",
	PACE_RATE_NONE       = "pas encore assez de données",
	PACE_ROW_NEXT        = "Prochain niveau",
	PACE_NEXT            = "%s XP, ~%s",
	PACE_NEXT_NOTIME     = "%s XP",
	PACE_ROW_EQUIV       = "Soit",
	PACE_KILLS           = "~%d monstre(s)",
	PACE_QUESTS          = "~%d quête(s)",
	PACE_ROW_REST        = "Repos",
	PACE_REST            = "%s %% d'un niveau",
	PACE_REST_NONE       = "aucun",
	PACE_LOGOUT          = "Déconnecte-toi ici : +%s %% d'un niveau d'ici demain.",
	PACE_LOGOUT_INN      = "Déconnecte-toi ici : +%s %% d'un niveau d'ici demain (+%s %% à l'auberge).",
	PACE_REST_FULL       = "Repos au maximum (150 %% d'un niveau) : inutile d'attendre.",
	PACE_CAMP            = "Au camp : la tente de camp donne aussi du repos (%d %% d'un niveau).",
	PACE_MAXLEVEL        = "Niveau maximum : plus rien à mesurer.",
	PACE_OFF             = "Le rythme de leveling est coupé (/r2q module pace on).",
	PACE_DUR_MIN         = "%d min",
	PACE_DUR_HOUR        = "%d h %02d",
	PACE_DUR_LONG        = "plus de %d h",
}
local EN = {
	OPT_PAGE_PACE        = "Leveling pace",
	OPT_PAGE_PACE_SUB    = "How long until next level: XP/h, time, kills, quests and rest.",
	OPT_PACE_TOOLTIP     = "On XP bar hover",
	OPT_PACE_WINDOW      = "Recent window",
	OPT_MIN_UNIT_PACE    = "min",
	HELP_PACE            = "/r2q xp -- leveling pace: XP/h, time to next level",
	PACE_TITLE           = "Leveling pace",
	PACE_ROW_RATE        = "XP/h",
	PACE_RATE            = "%s (session) · %s (%d min)",
	PACE_RATE_NONE       = "not enough data yet",
	PACE_ROW_NEXT        = "Next level",
	PACE_NEXT            = "%s XP, ~%s",
	PACE_NEXT_NOTIME     = "%s XP",
	PACE_ROW_EQUIV       = "That is",
	PACE_KILLS           = "~%d kill(s)",
	PACE_QUESTS          = "~%d quest(s)",
	PACE_ROW_REST        = "Rested",
	PACE_REST            = "%s %% of a level",
	PACE_REST_NONE       = "none",
	PACE_LOGOUT          = "Log out here: +%s %% of a level by tomorrow.",
	PACE_LOGOUT_INN      = "Log out here: +%s %% of a level by tomorrow (+%s %% at an inn).",
	PACE_REST_FULL       = "Rested is capped (150 %% of a level): no need to wait.",
	PACE_CAMP            = "At camp: the Camp Tent also gives rested XP (%d %% of a level).",
	PACE_MAXLEVEL        = "Max level: nothing left to measure.",
	PACE_OFF             = "Leveling pace is off (/r2q module pace on).",
	PACE_DUR_MIN         = "%d min",
	PACE_DUR_HOUR        = "%d h %02d",
	PACE_DUR_LONG        = "over %d h",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests : chaque clé doit exister dans les deux langues
ns.PACE_STRINGS = { fr = FR, en = EN }

ns.RegisterDefaults({
	paceEnabled = true,
	paceTooltip = true,
	paceWindow  = 30,      -- minutes : 15, 30 ou 60
})

if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "pace", title = "OPT_PAGE_PACE", parent = "qol", group = "OPT_GROUP_QOL",
		rows = {
			{ key = "paceEnabled", label = "OPT_PAGE_PACE",    kind = "bool" },
			{ key = "paceTooltip", label = "OPT_PACE_TOOLTIP", kind = "bool" },
			-- pas de 15 : 15, 30, 45, 60 ; 45 est accepté tel quel
			{ key = "paceWindow",  label = "OPT_PACE_WINDOW",  kind = "number", min = 15, max = 60, step = 15, suffix = "OPT_MIN_UNIT_PACE" },
		},
	})
end

if ns.RegisterModule then
	ns.RegisterModule({ id = "pace", key = "paceEnabled", label = "OPT_PAGE_PACE",
		aliases = { "rythme", "xp", "pace" } })
end

-- l'aide liste la commande sous « Ouvrir », sans toucher à Core.lua
if type(ns.HELP) == "table" and type(ns.HELP[1]) == "table" and type(ns.HELP[1][2]) == "table" then
	table.insert(ns.HELP[1][2], "HELP_PACE")
end

-- ---------------------------------------------------------------------------
-- Accès robustes au client
-- ---------------------------------------------------------------------------
local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function Now() return (ns.Now and ns.Now()) or 0 end
local function XP() return tonumber(Call("UnitXP", "player")) end
local function XPMax() return tonumber(Call("UnitXPMax", "player")) end
local function Level() return tonumber(Call("UnitLevel", "player")) end

local function MaxLevel()
	local max = tonumber(Call("GetMaxPlayerLevel"))
	-- un client qui répondrait n'importe quoi ne doit pas rendre le module muet
	if not max or max < 10 then max = MAX_LEVEL_FALLBACK end
	return max
end

function ns:PaceAtMaxLevel()
	local level = Level()
	return level ~= nil and level >= MaxLevel()
end

function ns:PaceOn()
	local db = self:DB()
	return db.enabled ~= false and db.paceEnabled ~= false
end

local function WindowSeconds()
	local minutes = tonumber(ns:DB().paceWindow) or 30
	if minutes < 15 then minutes = 15 elseif minutes > 60 then minutes = 60 end
	return minutes * 60, minutes
end

-- ---------------------------------------------------------------------------
-- Messages d'XP des monstres
-- ---------------------------------------------------------------------------
-- Chaînes du client d'abord. Les variantes « (+%d bonus de groupe) » ou
-- « (%s exp %s bonus) » commencent comme COMBATLOG_XPGAIN_FIRSTPERSON : le
-- motif n'est donc ancré qu'au début, la suite du message est ignorée.
local KILL_GLOBALS = { "COMBATLOG_XPGAIN_FIRSTPERSON", "COMBATLOG_XPGAIN_EXHAUSTION1" }
local UNNAMED_GLOBALS = { "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED" }
local KILL_FALLBACK = {
	"%s dies, you gain %d experience.",
	"%s meurt, vous gagnez %d points d'expérience.",
}
local UNNAMED_FALLBACK = {
	"You gain %d experience.",
	"Vous gagnez %d points d'expérience.",
}

-- Format du client -> motif Lua + position de la capture numérique. Gère les
-- formes positionnelles (%1$s, %2$d) de certaines traductions.
local function FormatToPattern(format)
	local order, index = {}, 0
	local pattern = format:gsub("%%(%d?)%$?([sd])", function(pos, kind)
		index = index + 1
		order[#order + 1] = { pos = tonumber(pos) or index, kind = kind }
		return kind == "d" and "\2" or "\1"
	end)
	pattern = pattern:gsub("([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
	pattern = pattern:gsub("\1", "(.-)"):gsub("\2", "(%%d+)")
	-- quelle capture porte l'XP : la première %d dans l'ordre du texte
	local xpCapture
	for capture, spec in ipairs(order) do
		if spec.kind == "d" then xpCapture = capture; break end
	end
	return "^" .. pattern, xpCapture
end

local function BuildPatterns(globals, fallback)
	local list, seen = {}, {}
	local function Add(format)
		if type(format) ~= "string" or format == "" or seen[format] then return end
		seen[format] = true
		local pattern, capture = FormatToPattern(format)
		if capture then list[#list + 1] = { pattern = pattern, capture = capture } end
	end
	for _, name in ipairs(globals) do Add(rawget(_G, name)) end
	-- le repli reste actif même avec les chaînes du client : il ne coûte rien
	-- et couvre un client dont les globales seraient renommées
	for _, format in ipairs(fallback) do Add(format) end
	return list
end

-- Renvoie xp, nommé (true = un monstre identifié) ; nil si le message n'est pas un gain d'XP
function ns:ParseCombatXP(message)
	if type(message) ~= "string" then return nil end
	for _, entry in ipairs(BuildPatterns(KILL_GLOBALS, KILL_FALLBACK)) do
		local captures = { message:match(entry.pattern) }
		if #captures > 0 then return tonumber(captures[entry.capture]), true end
	end
	for _, entry in ipairs(BuildPatterns(UNNAMED_GLOBALS, UNNAMED_FALLBACK)) do
		local captures = { message:match(entry.pattern) }
		if #captures > 0 then return tonumber(captures[entry.capture]), false end
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Suivi
-- ---------------------------------------------------------------------------
function ns:PaceReset()
	local now = Now()
	self.pace = {
		startedAt = now,
		lastXP    = XP(),
		lastXPMax = XPMax(),
		total     = 0,
		gains     = {},     -- { t, xp } des dernières 60 minutes
		kills     = {},     -- XP des derniers monstres
		quests    = {},     -- XP des dernières quêtes rendues
		lastKillAt = nil,
		questUntil = nil,   -- écran de récompense ouvert : prochain gain = quête
		turnedInAt = nil,
	}
	return self.pace
end

local function State()
	return ns.pace or ns:PaceReset()
end

local function Push(list, value, keep)
	list[#list + 1] = value
	while #list > keep do table.remove(list, 1) end
end

local function Prune(state, now)
	while state.gains[1] and state.gains[1].t < now - MAX_WINDOW do table.remove(state.gains, 1) end
end

function ns:PaceOnXP()
	local state = State()
	local now, max = XP(), XPMax()
	if not now then return end
	local delta = 0
	if state.lastXP then
		if now >= state.lastXP then
			delta = now - state.lastXP
		else
			-- l'XP repart de zéro : un niveau est passé entre deux relevés
			delta = math.max(0, (state.lastXPMax or state.lastXP) - state.lastXP) + now
		end
	end
	state.lastXP, state.lastXPMax = now, max or state.lastXPMax
	if delta <= 0 then return end

	local t = Now()
	state.total = state.total + delta
	state.gains[#state.gains + 1] = { t = t, xp = delta }
	Prune(state, t)

	-- gain pendant l'écran de récompense, qui ne vient pas d'un monstre et
	-- n'a pas déjà été compté par QUEST_TURNED_IN : c'est l'XP de la quête
	if state.questUntil and t <= state.questUntil
		and not (state.lastKillAt and t - state.lastKillAt <= KILL_GRACE)
		and not (state.turnedInAt and t - state.turnedInAt <= QUEST_GRACE) then
		Push(state.quests, { xp = delta, t = t, fromDelta = true }, KEEP_QUESTS)
		state.questUntil = nil
	end
end

function ns:PaceOnCombatXP(message)
	local xp, named = self:ParseCombatXP(message)
	if not xp or xp <= 0 then return end
	local state = State()
	local t = Now()
	-- « Vous gagnez N points d'expérience » sans nom pendant une remise de
	-- quête : c'est la quête, pas un monstre
	if not named and ((state.questUntil and t <= state.questUntil)
		or (state.turnedInAt and t - state.turnedInAt <= QUEST_GRACE)) then
		return
	end
	state.lastKillAt = t
	Push(state.kills, xp, KEEP_KILLS)
end

function ns:PaceOnQuestComplete()
	-- l'écran de récompense est ouvert : on attend le clic, deux minutes au plus
	State().questUntil = Now() + 120
end

function ns:PaceOnQuestFinished()
	local state = State()
	if state.questUntil then state.questUntil = math.min(state.questUntil, Now() + QUEST_GRACE) end
end

function ns:PaceOnQuestTurnedIn(_, xpReward)
	local xp = tonumber(xpReward)
	if not xp or xp <= 0 then return end   -- pas d'info : le relevé d'XP prendra le relais
	local state = State()
	local t = Now()
	local last = state.quests[#state.quests]
	if last and last.fromDelta and t - last.t <= QUEST_GRACE then
		-- le gain d'XP est arrivé avant l'événement : la valeur exacte remplace l'estimation
		last.xp, last.fromDelta = xp, nil
	else
		Push(state.quests, { xp = xp, t = t }, KEEP_QUESTS)
	end
	state.questUntil = nil
	state.turnedInAt = t
end

-- ---------------------------------------------------------------------------
-- Calculs
-- ---------------------------------------------------------------------------
-- XP/h de la session et de la fenêtre glissante (nil si trop tôt). Exposé
-- pour d'autres modules (le Retour d'expédition pourra s'en servir).
function ns:PaceXPPerHour(windowSeconds)
	local state = State()
	local now = Now()
	local elapsed = now - (state.startedAt or now)
	if elapsed < MIN_ELAPSED then return nil, nil end
	local session = state.total / elapsed * 3600
	windowSeconds = windowSeconds or WindowSeconds()
	local span = math.min(windowSeconds, elapsed)
	local sum = 0
	for _, gain in ipairs(state.gains) do
		if gain.t >= now - windowSeconds then sum = sum + gain.xp end
	end
	return session, sum / span * 3600
end

local function Average(list, field)
	if #list == 0 then return nil end
	local sum = 0
	for _, value in ipairs(list) do sum = sum + (field and value[field] or value) end
	return sum / #list
end

-- Repos : % d'un niveau, et gain d'ici demain si l'on se déconnecte ici
function ns:PaceRest()
	local max = XPMax()
	if not max or max <= 0 then return nil end
	local rested = tonumber(Call("GetXPExhaustion")) or 0
	local pct = rested / max * 100
	local resting = Call("IsResting") and true or false
	local function Gain(rate)
		return math.max(0, math.min(rate * PROJECTION_HOURS, REST_CAP - pct))
	end
	return {
		pct      = pct,
		resting  = resting,
		gain     = Gain(resting and REST_PER_HOUR_INN or REST_PER_HOUR_INN * REST_OUTSIDE_RATIO),
		gainInn  = Gain(REST_PER_HOUR_INN),
		capped   = pct >= REST_CAP - 0.05,
	}
end

-- La fiche complète, ou nil quand le module doit se taire
function ns:PaceCard()
	if not self:PaceOn() or self:PaceAtMaxLevel() then return nil end
	local xp, max = XP(), XPMax()
	if not xp or not max or max <= 0 then return nil end
	local windowSeconds, windowMinutes = WindowSeconds()
	local session, recent = self:PaceXPPerHour(windowSeconds)
	local remaining = math.max(0, max - xp)
	-- la fenêtre récente dit mieux le rythme actuel ; la session sert de repli
	local rate = (recent and recent > 0) and recent or ((session and session > 0) and session or nil)
	local state = State()
	local kill, quest = Average(state.kills), Average(state.quests, "xp")
	return {
		session   = session,
		recent    = recent,
		window    = windowMinutes,
		remaining = remaining,
		seconds   = rate and (remaining / rate * 3600) or nil,
		kills     = kill and kill > 0 and math.ceil(remaining / kill) or nil,
		quests    = quest and quest > 0 and math.ceil(remaining / quest) or nil,
		rest      = self:PaceRest(),
		atCamp    = self.AtCamp and self:AtCamp() or false,
	}
end

-- ---------------------------------------------------------------------------
-- Mise en forme
-- ---------------------------------------------------------------------------
local function Num(value)
	value = math.floor((tonumber(value) or 0) + 0.5)
	local text = tostring(value)
	-- séparateur de milliers : 12 345 se lit mieux que 12345
	local sep = (L.PACE_TITLE == FR.PACE_TITLE) and " " or ","
	local out = text:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
	return (out:gsub("^" .. sep, ""))
end

local function Pct(value)
	local rounded = math.floor(value * 10 + 0.5) / 10
	local text = (rounded == math.floor(rounded)) and string.format("%d", rounded) or string.format("%.1f", rounded)
	if L.PACE_TITLE == FR.PACE_TITLE then text = text:gsub("%.", ",") end
	return text
end
ns.PacePct = Pct

function ns:PaceDuration(seconds)
	local minutes = math.ceil((tonumber(seconds) or 0) / 60)
	if minutes < 60 then return self:F("PACE_DUR_MIN", math.max(1, minutes)) end
	if minutes >= 100 * 60 then return self:F("PACE_DUR_LONG", 99) end
	return self:F("PACE_DUR_HOUR", math.floor(minutes / 60), minutes % 60)
end

-- Lignes de la fiche : { label, valeur } ou { text } pour une phrase entière
function ns:PaceLines(card)
	local lines = {}
	if card.session then
		lines[#lines + 1] = { label = L.PACE_ROW_RATE,
			value = self:F("PACE_RATE", Num(card.session), Num(card.recent or 0), card.window) }
	else
		lines[#lines + 1] = { label = L.PACE_ROW_RATE, value = L.PACE_RATE_NONE }
	end
	lines[#lines + 1] = { label = L.PACE_ROW_NEXT, value = card.seconds
		and self:F("PACE_NEXT", Num(card.remaining), self:PaceDuration(card.seconds))
		or self:F("PACE_NEXT_NOTIME", Num(card.remaining)) }
	local equiv = {}
	if card.kills then equiv[#equiv + 1] = self:F("PACE_KILLS", card.kills) end
	if card.quests then equiv[#equiv + 1] = self:F("PACE_QUESTS", card.quests) end
	if #equiv > 0 then lines[#lines + 1] = { label = L.PACE_ROW_EQUIV, value = table.concat(equiv, " · ") } end

	local rest = card.rest
	if rest then
		lines[#lines + 1] = { label = L.PACE_ROW_REST,
			value = rest.pct > 0 and self:F("PACE_REST", Pct(rest.pct)) or L.PACE_REST_NONE }
		if rest.capped then
			lines[#lines + 1] = { text = L.PACE_REST_FULL }
		elseif rest.resting then
			lines[#lines + 1] = { text = self:F("PACE_LOGOUT", Pct(rest.gain)) }
		else
			lines[#lines + 1] = { text = self:F("PACE_LOGOUT_INN", Pct(rest.gain), Pct(rest.gainInn)) }
		end
	end
	if card.atCamp then lines[#lines + 1] = { text = self:F("PACE_CAMP", CAMP_REST_PCT) } end
	return lines
end

local function Gold(text) return (Theme and Theme.T_GOLD or "") .. tostring(text) .. (Theme and "|r" or "") end
local function Grey(text) return (Theme and Theme.T_GREY or "") .. tostring(text) .. (Theme and "|r" or "") end

-- /r2q xp : la fiche dans le chat
function ns:PrintPace()
	if not self:PaceOn() then return self:Print(L.PACE_OFF) end
	-- demandée explicitement : une ligne vaut mieux qu'un silence incompris
	if self:PaceAtMaxLevel() then return self:Print(L.PACE_MAXLEVEL) end
	local card = self:PaceCard()
	if not card then return end
	self:Print(Gold(L.PACE_TITLE))
	for _, line in ipairs(self:PaceLines(card)) do
		if line.text then print("   " .. Grey(line.text))
		else print("   " .. Gold(line.label) .. " : " .. line.value) end
	end
end

-- ---------------------------------------------------------------------------
-- Infobulle de la barre d'XP
-- ---------------------------------------------------------------------------
function ns:PaceTooltipLines()
	if not self:PaceOn() or self:DB().paceTooltip == false then return nil end
	local card = self:PaceCard()
	return card and self:PaceLines(card) or nil
end

function ns:PaceOnBarEnter(bar)
	local lines = self:PaceTooltipLines()
	local tip = rawget(_G, "GameTooltip")
	if not lines or type(tip) ~= "table" then return end
	-- la barre a peut-être déjà ouvert sa propre infobulle (Forever, code
	-- retail) : on complète. Sinon (Era, MainMenuExpBar n'en ouvre pas) on
	-- ouvre la nôtre, et on la refermera en sortant.
	local owned = false
	if tip.IsShown and tip.GetOwner and tip:IsShown() then
		local ok, owner = pcall(tip.GetOwner, tip)
		owned = ok and owner == bar
	end
	if owned then
		tip:AddLine(" ")
		self.paceOwnsTooltip = false
	else
		pcall(tip.SetOwner, tip, bar, "ANCHOR_TOP")
		if tip.ClearLines then tip:ClearLines() end
		self.paceOwnsTooltip = true
	end
	tip:AddLine(L.PACE_TITLE, 0.91, 0.65, 0.29)
	for _, line in ipairs(lines) do
		if line.text then
			tip:AddLine(line.text, 0.7, 0.7, 0.7, true)
		elseif tip.AddDoubleLine then
			tip:AddDoubleLine(line.label, line.value, 0.85, 0.85, 0.85, 1, 1, 1)
		else
			tip:AddLine(line.label .. " : " .. line.value)
		end
	end
	tip:Show()
end

function ns:PaceOnBarLeave()
	local tip = rawget(_G, "GameTooltip")
	if self.paceOwnsTooltip and type(tip) == "table" and tip.Hide then tip:Hide() end
	self.paceOwnsTooltip = false
end

-- Barres d'XP possibles, de la plus sûre à la plus incertaine :
--   * Era 1.15 : MainMenuExpBar ;
--   * Forever (code retail 12.x) : MainStatusTrackingBarContainer et ses
--     .bars ; StatusTrackingBarManager (retail 8.x-10.x) en repli.
-- Dans un conteneur, seule la barre d'XP est accrochée (elle porte les
-- textures d'épuisement) ; sans barre reconnaissable, le conteneur lui-même.
ns.PACE_BAR_FRAMES = { "MainMenuExpBar", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
	"StatusTrackingBarManager" }
ns.paceHooked = ns.paceHooked or {}

local function IsXPBar(bar)
	if type(bar) ~= "table" then return false end
	if bar.ExhaustionTick or bar.ExhaustionLevelFillBar or bar.ExhaustionLevelBar then return true end
	local name = bar.GetName and bar:GetName()
	return type(name) == "string" and name:find("Exp") ~= nil
end

local function Hook(frame)
	if type(frame) ~= "table" or type(frame.HookScript) ~= "function" or ns.paceHooked[frame] then return false end
	local ok = pcall(frame.HookScript, frame, "OnEnter", function(self)
		local okEnter, err = pcall(ns.PaceOnBarEnter, ns, self)
		if not okEnter and ns.RecordError then ns:RecordError("pace:tooltip", err) end
	end)
	if not ok then return false end
	pcall(frame.HookScript, frame, "OnLeave", function() ns:PaceOnBarLeave() end)
	ns.paceHooked[frame] = true
	return true
end

function ns:PaceHookXPBar()
	local count = 0
	for _, name in ipairs(self.PACE_BAR_FRAMES) do
		local frame = rawget(_G, name)
		if type(frame) == "table" then
			local found = false
			local bars = rawget(frame, "bars")
			if type(bars) == "table" then
				for _, bar in pairs(bars) do
					if IsXPBar(bar) then
						found = true
						if Hook(bar) then count = count + 1 end
					end
				end
			end
			if not found and Hook(frame) then count = count + 1 end
		end
	end
	return count
end

-- ---------------------------------------------------------------------------
-- Commande et événements
-- ---------------------------------------------------------------------------
-- Point d'entrée de Core.lua (HandleCommand consulte ns.EXTRA_COMMANDS)
ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["xp"] = function(self) self:PrintPace() end
ns.EXTRA_COMMANDS["rythme"] = function(self) self:PrintPace() end

local HANDLERS = {
	PLAYER_ENTERING_WORLD    = function() ns:PaceOnXP() end,
	PLAYER_XP_UPDATE         = function() ns:PaceOnXP() end,
	PLAYER_LEVEL_UP          = function() ns:PaceOnXP() end,
	CHAT_MSG_COMBAT_XP_GAIN  = function(message) ns:PaceOnCombatXP(message) end,
	QUEST_COMPLETE           = function() ns:PaceOnQuestComplete() end,
	QUEST_FINISHED           = function() ns:PaceOnQuestFinished() end,
	QUEST_TURNED_IN          = function(questID, xpReward) ns:PaceOnQuestTurnedIn(questID, xpReward) end,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do
	-- un événement inconnu du client (QUEST_TURNED_IN sur un vieux client) ne bloque rien
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	-- les cadres de la barre d'XP peuvent naître tard : on réessaie à chaque entrée en jeu
	if event == "PLAYER_ENTERING_WORLD" then pcall(ns.PaceHookXPBar, ns) end
	-- au niveau maximum ou module coupé, plus rien n'est suivi ; le suivi
	-- repart de zéro à la reprise, sinon l'XP gagnée entre-temps serait
	-- comptée d'un bloc dans la fenêtre récente
	if not ns:PaceOn() or ns:PaceAtMaxLevel() then ns.pace = nil; return end
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("pace:" .. tostring(event), err) end
end)
ns.paceEventFrame = eventFrame

pcall(ns.PaceHookXPBar, ns)

if ns.Mark then ns.Mark("LevelPace") end
