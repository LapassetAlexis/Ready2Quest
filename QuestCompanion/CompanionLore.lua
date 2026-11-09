-- CompanionLore.lua -- le compagnon raconte l'histoire des lieux (QuestCompanion 2.13.0)
--
-- 2.13.0 : une phrase d'histoire (LoreData.lua : Warcraft Wiki, CC BY-SA 4.0,
-- via Spoken de Rusty Key) dite en bulle :
--   * à la première arrivée dans une zone (une fois par personnage et par
--     zone), puis rarement aux visites suivantes (LORE_REVISIT, LORE_AGAIN) ;
--   * à l'entrée d'une sous-zone notable (une fois par personnage) ;
--   * de temps en temps au repos, parmi les bavardages (LORE_IDLE).
-- Jamais en combat (barrière de ns:CompanionSay, et on attend la fin) ; la
-- réglette « Bavardage » s'applique (catégories tip / chatter : crans Bavard
-- et Moulin à paroles). Réglage « Le compagnon raconte l'histoire des lieux »
-- (db.companionLore, page du compagnon), activé par défaut.
-- Spoken_Places chargé : silence sur l'histoire (il la raconte déjà, à voix
-- haute) ; le réglage le dit.
-- Rien n'est fait à chaque image : tout part des changements de zone et du
-- relevé périodique des bavardages ; une seule minuterie à la fois.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

local LORE_DELAY   = 8       -- s après l'arrivée (la bulle « Vue » passe d'abord)
local LORE_RETRY   = 12      -- s entre deux essais quand la place est prise
local LORE_TRIES   = 4       -- essais avant d'abandonner (redit à la prochaine entrée)
local LORE_GAP     = 90      -- s de jeu au moins entre deux récits
local LORE_REVISIT = 6 * 3600   -- s réelles avant de reparler d'une zone déjà racontée
local LORE_AGAIN   = 0.2     -- chance d'en reparler, passé ce délai
local LORE_IDLE    = 900     -- s de bavardage sans récit avant d'en tenter un
local LORE_IDLE_CHANCE = 0.5
local LORE_MAX     = 260     -- octets au plus dans la bulle (220 px de large)
local LORE_MIN_CUT = 60      -- une phrase coupée garde au moins ceci
ns.LORE_LIMITS = { max = LORE_MAX, gap = LORE_GAP, revisit = LORE_REVISIT, again = LORE_AGAIN,
	delay = LORE_DELAY, retry = LORE_RETRY, tries = LORE_TRIES, idle = LORE_IDLE }

-- ---------------------------------------------------------------------------
-- Textes : réglage et amorces du compagnon (réservoirs LORE / LORE_PLACE)
-- ---------------------------------------------------------------------------
ns.RegisterStrings({
	OPT_COMP_LORE      = "Le compagnon raconte l'histoire des lieux",
	OPT_COMP_LORE_DESC = "Une phrase d'histoire à ta première arrivée dans une zone ou un lieu notable, parfois au repos. Jamais en combat ; suit la réglette Bavardage. Muet si l'addon Spoken Places est chargé (il la raconte déjà). Textes : Warcraft Wiki (CC BY-SA 4.0), via Spoken de Rusty Key.",
}, {
	OPT_COMP_LORE      = "Companion tells the story of places",
	OPT_COMP_LORE_DESC = "One line of lore on your first arrival in a zone or a notable place, sometimes while resting. Never in combat; follows the Chattiness slider. Silent when the Spoken Places addon is loaded (it already tells it). Text: Warcraft Wiki (CC BY-SA 4.0), via Spoken by Rusty Key.",
})

-- Amorces génériques (les voix pourront en ajouter par personnalité)
local P = {
	LORE = {
		{ "Tu savais ? %s", "Did you know? %s" },
		{ "On raconte ceci : %s", "They say this: %s" },
		{ "Écoute un peu… %s", "Listen… %s" },
		{ "Un vieux récit dit ceci : %s", "An old tale goes like this: %s" },
		{ "Ici, regarde bien. %s", "Look closely here. %s" },
	},
	LORE_PLACE = {
		{ "%s… Tu savais ? %s", "%s… Did you know? %s" },
		{ "%s. On raconte ceci : %s", "%s. They say this: %s" },
		{ "Ici, %s. %s", "Here, %s. %s" },
		{ "%s ! Écoute un peu… %s", "%s! Listen… %s" },
	},
}
ns.LORE_POOLS = ns.RegisterCompanionLines and ns.RegisterCompanionLines(P, true) or nil

ns.RegisterDefaults({ companionLore = true })

-- la ligne dans la page du compagnon, sous la réglette « Bavardage »
for _, page in ipairs(ns.OPTION_PAGES or {}) do
	if page.id == "companionMain" and type(page.rows) == "table" then
		local at, present = #page.rows + 1, false
		for index, row in ipairs(page.rows) do
			if row.key == "companionLore" then present = true end
			if row.key == "companionChatter" then at = index + 1 end
		end
		if not present then
			table.insert(page.rows, at, { key = "companionLore", label = "OPT_COMP_LORE", kind = "bool",
				describe = function() return L.OPT_COMP_LORE_DESC end })
		end
	end
end

-- ---------------------------------------------------------------------------
-- Lectures défensives
-- ---------------------------------------------------------------------------
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Wall() return tonumber((Call(rawget(_G, "time")))) or 0 end

local function InCombat()
	local fighting = ns.companionFighting
	if fighting and Clock() - fighting >= 0 and Clock() - fighting < (ns.COMPANION_FIGHT_GRACE or 5) then return true end
	if Call(rawget(_G, "InCombatLockdown")) then return true end
	return Call(rawget(_G, "UnitAffectingCombat"), "player") and true or false
end

-- Spoken_Places (ou l'addon Spoken entier) raconte déjà les lieux
function ns.LoreSpokenLoaded()
	local api = rawget(_G, "C_AddOns")
	local fn = (type(api) == "table" and api.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
	return Call(fn, "Spoken_Places") and true or false
end

-- ---------------------------------------------------------------------------
-- Données : la chaîne de la langue du client, lue à la demande
-- ---------------------------------------------------------------------------
local function Raw()
	local raw = ns.LORE_RAW
	if type(raw) ~= "table" then return nil end
	local lang = ns.loreLang or (ns.STRINGS_FRENCH ~= false and "fr" or "en")
	return raw[lang] or raw.fr or raw.en
end

-- Comme SpokenPlaces:NormaliseAreaKey (et tools/gen_lore.py)
function ns.LoreNormalise(name)
	if type(name) ~= "string" then return "" end
	local s = name:lower():gsub("^the%s+", ""):gsub("'", ""):gsub("\226\128\153", "")
	s = s:gsub("[^a-z0-9]+", " "):gsub("^ +", ""):gsub(" +$", "")
	return s
end

-- Phrase d'une zone : texte, page du wiki
function ns:LoreZone(mapID)
	local raw = Raw()
	if not raw or not mapID then return nil end
	return raw:match("\nZ\t" .. tostring(mapID) .. "\t([^\t\n]+)\t([^\t\n]+)")
end

-- Sous-zones de la zone courante : relues à chaque changement de zone seulement
local subCache = { map = false, list = {} }
local function SubList(mapID)
	if subCache.map == mapID then return subCache.list end
	local list = {}
	local raw = Raw()
	if raw and mapID then
		for names, text, src in raw:gmatch("\nS\t" .. tostring(mapID) .. "\t([^\t\n]+)\t([^\t\n]+)\t([^\t\n]+)") do
			list[#list + 1] = { names = names, text = text, src = src }
		end
	end
	subCache.map, subCache.list = mapID, list
	return list
end
function ns:LoreForgetCache() subCache.map, subCache.list = false, {} end

-- Phrase d'une sous-zone (nom donné par le client) : texte, page du wiki
function ns:LoreSubzone(mapID, name)
	if type(name) ~= "string" or name == "" then return nil end
	local key = ns.LoreNormalise(name)
	for _, entry in ipairs(SubList(mapID)) do
		for candidate in entry.names:gmatch("[^|]+") do
			if candidate == name or candidate == key or ns.LoreNormalise(candidate) == key then
				return entry.text, entry.src
			end
		end
	end
	return nil
end

-- Coupe sûre pour la bulle : une phrase entière qui tient, sinon au mot (« … »)
function ns.LoreFit(text, limit)
	limit = limit or LORE_MAX
	if type(text) ~= "string" or #text <= limit then return text end
	local best
	for pos in text:gmatch("[%.!%?]()%s") do
		if pos - 1 <= limit then best = pos - 1 end
	end
	if best and best >= LORE_MIN_CUT then return text:sub(1, best) end
	local head = text:sub(1, limit - 3)
	local space = head:match(".*() ")
	if space and space > limit / 2 then head = head:sub(1, space - 1) end
	head = head:gsub("[%s,;:%-]+$", "")
	return head .. "…"
end

-- ---------------------------------------------------------------------------
-- État par personnage : zones racontées (heure réelle), sous-zones (page)
-- ---------------------------------------------------------------------------
local function State(self)
	local char = self:CharData()
	local lore = char.lore
	if type(lore) ~= "table" then lore = {}; char.lore = lore end
	if type(lore.z) ~= "table" then lore.z = {} end
	if type(lore.s) ~= "table" then lore.s = {} end
	return lore
end
ns.LoreState = State

local function LoreOn(self)
	local db = self:DB()
	if db.companionLore == false then return false end
	if ns.CompanionOn and not ns.CompanionOn() then return false end
	if ns.LoreSpokenLoaded() then return false end
	return Raw() ~= nil
end
ns.LoreOn = LoreOn

-- Une bulle : `place` = nom de la sous-zone (amorce qui le nomme) ou nil
local rt = { lastTold = nil, idle = 0 }
function ns:LoreTell(text, place, category)
	local fitted = ns.LoreFit(text)
	local opts = { category = category or "tip", duration = math.min(14, 6 + math.floor(#fitted / 30)) }
	if place then
		opts.args = { place, fitted }
		return self:CompanionSay("LORE_PLACE", opts)
	end
	opts.args = { fitted }
	return self:CompanionSay("LORE", opts)
end

-- ---------------------------------------------------------------------------
-- File d'un seul récit, essayé après un délai (une minuterie à la fois)
-- ---------------------------------------------------------------------------
local pending = {}   -- kind ("z"/"s"), map, id, text, place, tries
local armed = false
local Attempt

local function Arm(delay)
	if armed then return end
	local timer = rawget(_G, "C_Timer")
	if type(timer) ~= "table" or type(timer.After) ~= "function" then return end
	armed = true
	timer.After(delay, Attempt)
end

local function Clear() pending.kind, pending.text, pending.place, pending.id = nil, nil, nil, nil end

Attempt = function()
	armed = false
	local self = ns
	if not pending.kind then return end
	if not LoreOn(self) or self:CurrentMap() ~= pending.map then Clear(); return end
	if pending.kind == "s" and self:CurrentSubZone() ~= pending.place then Clear(); return end
	-- en combat : on attend la fin, sans compter d'essai
	if InCombat() or (rt.lastTold and Clock() - rt.lastTold < LORE_GAP) then Arm(LORE_RETRY); return end
	local ok, why = self:LoreTell(pending.text, pending.place)
	if ok then
		local state = State(self)
		if pending.kind == "z" then state.z[pending.id] = Wall() else state.s[pending.id] = true end
		rt.lastTold, rt.idle = Clock(), 0
		Clear()
	elseif why == "busy" or why == "combat" then
		pending.tries = (pending.tries or 0) + 1
		if pending.tries < LORE_TRIES then Arm(LORE_RETRY) else Clear() end
	else
		Clear()   -- muet, cran trop bas, compagnon caché : rien de noté
	end
end
ns.LoreAttempt = Attempt
function ns:LorePending() return pending.kind and pending or nil end

local function Queue(kind, map, id, text, place)
	-- une zone passe avant une sous-zone (redite à la prochaine entrée)
	if pending.kind == "z" and kind == "s" and pending.map == map then return end
	pending.kind, pending.map, pending.id, pending.text, pending.place, pending.tries = kind, map, id, text, place, 0
	Arm(LORE_DELAY)
end

function ns:CompanionLoreOnZone(newArea)
	if not LoreOn(self) then return end
	local mapID = self:CurrentMap()
	if not mapID then return end
	local state = State(self)
	if newArea then
		local text = self:LoreZone(mapID)
		if text then
			local told = tonumber(state.z[mapID])
			if not told then
				Queue("z", mapID, mapID, text)
			elseif Wall() - told >= LORE_REVISIT and math.random() < LORE_AGAIN then
				state.z[mapID] = Wall()   -- au plus un essai par délai
				Queue("z", mapID, mapID, text)
			end
		end
	end
	local sub = self:CurrentSubZone()
	if sub then
		local text, src = self:LoreSubzone(mapID, sub)
		if text and not state.s[src] then Queue("s", mapID, src, text, sub) end
	end
end

-- Bavardage : de temps en temps, l'histoire du lieu où l'on est
function ns:CompanionLoreIdle(seconds)
	rt.idle = rt.idle + (tonumber(seconds) or 0)
	if rt.idle < LORE_IDLE then return false end
	rt.idle = 0
	if not LoreOn(self) or InCombat() or math.random() >= LORE_IDLE_CHANCE then return false end
	local mapID = self:CurrentMap()
	if not mapID then return false end
	local sub = self:CurrentSubZone()
	local text, src = self:LoreSubzone(mapID, sub)
	local place = text and sub or nil
	if not text then text = self:LoreZone(mapID) end
	if not text then return false end
	if not self:LoreTell(text, place, "chatter") then return false end
	if src then State(self).s[src] = true end
	rt.lastTold = Clock()
	return true
end

function ns:LoreReset()
	Clear()
	armed = false
	rt.lastTold, rt.idle = nil, 0
	ns:LoreForgetCache()
end

-- ---------------------------------------------------------------------------
-- Branchements (sans toucher Companion.lua) : après ses propres réactions
-- ---------------------------------------------------------------------------
local baseOnZone = ns.CompanionOnZone
if type(baseOnZone) == "function" then
	function ns:CompanionOnZone(newArea)
		baseOnZone(self, newArea)
		self:CompanionLoreOnZone(newArea)
	end
end
local baseIdle = ns.CompanionTryIdle
if type(baseIdle) == "function" then
	function ns:CompanionTryIdle(seconds)
		if baseIdle(self, seconds) then return true end
		return self:CompanionLoreIdle(seconds)
	end
end
