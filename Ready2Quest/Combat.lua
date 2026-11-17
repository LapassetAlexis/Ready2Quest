-- Combat.lua -- le module Combat de Ready2Quest (1.38.0)
--
-- Une section « Combat » dans les réglages : la portée d'aggro (Aggro.lua,
-- AggroPlus.lua, AggroLink.lua) et quatre parties reprises de DoesItDiePlus
-- (Ironship, GPL-3.0 ; DoTInfo d'après Does It Die de Joe Greive, MIT), dont
-- le moteur est importé dans Ready2Quest/Combat/ par tools/sync_combat.py :
--   * portée des sorts : coche verte / croix rouge au-dessus de la cible, icônes grisées hors de
--     portée (module Range) ;
--   * DoT mortels : les dégâts que tes DoT doivent encore faire sur la barre
--     de vie de la cible, un crâne quand ils suffisent (DoTInfo) ;
--   * prédiction des sorts : les dégâts du sort en cours d'incantation sur la
--     barre de vie, une icône quand il tue (CastPrediction) ;
--   * chiffres des barres d'action : les dégâts de chaque sort sur son bouton
--     (SpellDamageInfo).
-- Chaque partie a son interrupteur ici (et le sien dans la fenêtre détaillée
-- du moteur, /r2q combat) ; un changement prend effet au /reload suivant.
-- DoesItDiePlus ou Does It Die activé : notre moteur ne se charge pas
-- (CombatBoot.lua), la page le dit ; la portée d'aggro reste à nous.
local ADDON, ns = ...
local L = ns.L

-- partie -> réglage de Ready2Quest, module du moteur
ns.COMBAT_PARTS = {
	{ key = "combatRange", module = "Range",           page = "combatRange" },
	{ key = "combatDots",  module = "DoTInfo",         page = "combatDots" },
	{ key = "combatCast",  module = "CastPrediction",  page = "combatCast" },
	{ key = "combatBars",  module = "SpellDamageInfo", page = "combatBars" },
}

ns.RegisterDefaults({ combatRange = true, combatDots = true, combatCast = true, combatBars = true })

local FR = {
	OPT_GROUP_COMBAT        = "COMBAT",
	OPT_PAGE_COMBAT         = "Combat",
	OPT_PAGE_COMBAT_SUB     = "La portée d'aggro et ce qui aide pendant le combat : portée des sorts, DoT mortels, prédiction des sorts, chiffres des barres.",
	OPT_PAGE_COMBAT_RANGE   = "Portée des sorts",
	OPT_PAGE_COMBAT_RANGE_SUB = "Une coche verte ou une croix rouge au-dessus de ta cible ; les icônes des barres se grisent hors de portée.",
	OPT_PAGE_COMBAT_DOTS    = "DoT mortels",
	OPT_PAGE_COMBAT_DOTS_SUB = "Ce que tes DoT vont encore infliger, sur la barre de vie ; un crâne s'ils tuent.",
	OPT_PAGE_COMBAT_CAST    = "Prédiction des sorts",
	OPT_PAGE_COMBAT_CAST_SUB = "Pendant l'incantation, les dégâts attendus du sort sur la barre de vie de la cible ; une icône s'il la tue.",
	OPT_PAGE_COMBAT_BARS    = "Chiffres des barres",
	OPT_PAGE_COMBAT_BARS_SUB = "Les dégâts (ou soins) de chaque sort, écrits sur son bouton de la barre d'action.",
	OPT_COMBAT_INFO_RANGE_1 = "Mesurée avec les sorts principaux de ta classe ; ça marche aussi en combat.",
	OPT_COMBAT_INFO_RANGE_2 = "Un sort de ton choix peut servir de règle : réglages détaillés.",
	OPT_COMBAT_INFO_DOTS_1  = "Sur la barre de vie : la part que tes DoT vont encore infliger. Si la vie s'arrête dans cette part, la cible est cuite.",
	OPT_COMBAT_INFO_DOTS_2  = "La taille réelle des ticks s'apprend en jouant (résistances comprises).",
	OPT_COMBAT_INFO_CAST_1  = "Une prédiction, pas une promesse : elle s'affine en jouant, les coups critiques n'y comptent pas.",
	OPT_COMBAT_INFO_BARS_1  = "Lus dans la description du sort, avec ta puissance des sorts et tes talents (Forever ne les inclut pas).",
	OPT_COMBAT_INFO_RELOAD  = "Un interrupteur prend effet au prochain /reload.",
	OPT_COMBAT_INFO_CREDIT  = "Moteur repris de DoesItDiePlus (Ironship) et Does It Die (Joe Greive). Merci à eux !",
	OPT_COMBAT_RIVAL        = "%s est installé : il s'occupe de tout ça, Ready2Quest s'efface (la portée d'aggro reste).",
	OPT_ACTION_COMBATDETAILS = "Réglages détaillés",
	OPT_ACTION_COMBATRELOAD = "Recharger l'interface",
	MSG_COMBAT_RELOAD       = "Combat : le changement prend effet au prochain /reload.",
	MSG_COMBAT_RIVAL        = "Combat : %s est installé, le module Combat de Ready2Quest reste éteint (la portée d'aggro reste).",
	MSG_COMBAT_OFF          = "Combat : module coupé (Réglages › Combat).",
	HELP_COMBAT             = "/r2q combat -- les réglages détaillés du module Combat",
}
local EN = {
	OPT_GROUP_COMBAT        = "COMBAT",
	OPT_PAGE_COMBAT         = "Combat",
	OPT_PAGE_COMBAT_SUB     = "Aggro range and what helps in a fight: spell range, lethal DoTs, spell prediction, action bar numbers.",
	OPT_PAGE_COMBAT_RANGE   = "Spell range",
	OPT_PAGE_COMBAT_RANGE_SUB = "A green check or a red cross above your target; action bar icons grey out when out of range.",
	OPT_PAGE_COMBAT_DOTS    = "Lethal DoTs",
	OPT_PAGE_COMBAT_DOTS_SUB = "What your DoTs will still deal, on the health bar; a skull if they kill.",
	OPT_PAGE_COMBAT_CAST    = "Spell prediction",
	OPT_PAGE_COMBAT_CAST_SUB = "While you cast, the spell's expected damage on the target's health bar; an icon if it kills.",
	OPT_PAGE_COMBAT_BARS    = "Action bar numbers",
	OPT_PAGE_COMBAT_BARS_SUB = "The damage (or healing) of each spell, written on its action button.",
	OPT_COMBAT_INFO_RANGE_1 = "Measured with your class's main spells; it works in combat too.",
	OPT_COMBAT_INFO_RANGE_2 = "A spell of your choice can be used instead: detailed settings.",
	OPT_COMBAT_INFO_DOTS_1  = "On the health bar: what your DoTs will still deal. If the health ends inside it, the target is done for.",
	OPT_COMBAT_INFO_DOTS_2  = "The real tick size is learned as you play (resistances included).",
	OPT_COMBAT_INFO_CAST_1  = "A prediction, not a promise: it sharpens as you play, critical hits don't count.",
	OPT_COMBAT_INFO_BARS_1  = "Read from the spell's description, with your spell power and talents (Forever leaves them out).",
	OPT_COMBAT_INFO_RELOAD  = "A switch takes effect at the next /reload.",
	OPT_COMBAT_INFO_CREDIT  = "Engine from DoesItDiePlus (Ironship) and Does It Die (Joe Greive). Thanks to them!",
	OPT_COMBAT_RIVAL        = "%s is installed: it handles all this, Ready2Quest steps aside (aggro range stays).",
	OPT_ACTION_COMBATDETAILS = "Detailed settings",
	OPT_ACTION_COMBATRELOAD = "Reload the interface",
	MSG_COMBAT_RELOAD       = "Combat: the change takes effect at the next /reload.",
	MSG_COMBAT_RIVAL        = "Combat: %s is installed, Ready2Quest's Combat module stays off (aggro range stays).",
	MSG_COMBAT_OFF          = "Combat: module switched off (Settings › Combat).",
	HELP_COMBAT             = "/r2q combat -- the Combat module's detailed settings",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.COMBAT_STRINGS = { fr = FR, en = EN } end

local RIVAL_TITLES = { UsefulPlatesAndTooltips = "DoesItDiePlus", DoesItDie = "Does It Die" }
function ns:CombatRivalTitle()
	return self.combatRival and (RIVAL_TITLES[self.combatRival] or self.combatRival) or nil
end

-- Le moteur tourne-t-il (chargé, pas de rival) ? Une partie tourne-t-elle ?
function ns:CombatEngine() return self.combat end
function ns:CombatPartOn(part)
	local db = self:DB()
	return self.combat ~= nil and db[part.key] ~= false
end

-- Notre interrupteur passe avant celui du moteur : chaque partie demande
-- BIT.ShouldRun(module) à ADDON_LOADED ; coupée chez nous, elle reste muette
local engine = ns.combat
if engine and type(engine.ShouldRun) == "function" then
	local byModule = {}
	for _, part in ipairs(ns.COMBAT_PARTS) do byModule[part.module] = part end
	local base = engine.ShouldRun
	function engine.ShouldRun(name)
		local part = byModule[name]
		if part and not ns:CombatPartOn(part) then
			engine.state[name] = "off"
			return false
		end
		return base(name)
	end
end

-- La fenêtre détaillée du moteur (sur l'onglet d'une partie)
function ns:CombatOpenDetails(module)
	local e = self.combat
	if not e then
		local rival = self:CombatRivalTitle()
		return self:Print(rival and self:F("MSG_COMBAT_RIVAL", rival) or L.MSG_COMBAT_OFF)
	end
	if type(e.OpenSettings) ~= "function" then return false end
	if self.optionsFrame and self.optionsFrame:IsShown() then self.optionsFrame:Hide() end
	local ok = pcall(e.OpenSettings, module)
	return ok
end

-- ---------------------------------------------------------------------------
-- Les pages : un groupe COMBAT après le confort de jeu
-- ---------------------------------------------------------------------------
local function Info(lines)
	local list = {}
	if ns.combatRival then list[#list + 1] = function() return ns:F("OPT_COMBAT_RIVAL", ns:CombatRivalTitle()) end end
	for _, key in ipairs(lines) do list[#list + 1] = key end
	list[#list + 1] = "OPT_COMBAT_INFO_RELOAD"
	return list
end

local PAGES = {
	{ id = "combatRange", title = "OPT_PAGE_COMBAT_RANGE", group = "OPT_GROUP_COMBAT",
		power = "combatRange", info = Info({ "OPT_COMBAT_INFO_RANGE_1", "OPT_COMBAT_INFO_RANGE_2" }),
		actions = { "combatDetails", "combatReload" }, combatModule = "Range" },
	{ id = "combatDots", title = "OPT_PAGE_COMBAT_DOTS", group = "OPT_GROUP_COMBAT",
		power = "combatDots", info = Info({ "OPT_COMBAT_INFO_DOTS_1", "OPT_COMBAT_INFO_DOTS_2" }),
		actions = { "combatDetails", "combatReload" }, combatModule = "DoTInfo" },
	{ id = "combatCast", title = "OPT_PAGE_COMBAT_CAST", group = "OPT_GROUP_COMBAT",
		power = "combatCast", info = Info({ "OPT_COMBAT_INFO_CAST_1" }),
		actions = { "combatDetails", "combatReload" }, combatModule = "CastPrediction" },
	{ id = "combatBars", title = "OPT_PAGE_COMBAT_BARS", group = "OPT_GROUP_COMBAT",
		power = "combatBars", info = Info({ "OPT_COMBAT_INFO_BARS_1", "OPT_COMBAT_INFO_CREDIT" }),
		actions = { "combatDetails", "combatReload" }, combatModule = "SpellDamageInfo" },
}

do
	local pages = ns.OPTION_PAGES or {}
	-- la portée d'aggro quitte le confort de jeu : première page du Combat
	local aggro
	for index, page in ipairs(pages) do
		if page.id == "aggro" then aggro = table.remove(pages, index); break end
	end
	if aggro then
		aggro.parent, aggro.group = nil, "OPT_GROUP_COMBAT"
		table.insert(pages, aggro)
	end
	for _, def in ipairs(PAGES) do table.insert(pages, def) end
end

ns.OPTION_ACTIONS = ns.OPTION_ACTIONS or {}
ns.OPTION_ACTIONS.combatDetails = function(self)
	local frame = self.optionsFrame
	local page = frame and frame.currentPage
	local module
	for _, def in ipairs(PAGES) do if def.id == page then module = def.combatModule end end
	self:CombatOpenDetails(module)
end
ns.OPTION_ACTIONS.combatReload = function(self)
	if self.AskReload then self:AskReload(L.OPT_PAGE_COMBAT) end
end

-- un interrupteur du Combat : prend effet au /reload
do
	local previous = ns.OnModuleToggled
	local keys = {}
	for _, part in ipairs(ns.COMBAT_PARTS) do keys[part.key] = true end
	function ns:OnModuleToggled(key, enabled)
		if previous then previous(self, key, enabled) end
		if keys[key] then self:Print(L.MSG_COMBAT_RELOAD) end
	end
end

-- ---------------------------------------------------------------------------
-- /r2q combat [portee|dots|cast|barres]
-- ---------------------------------------------------------------------------
local WORDS = { portee = "Range", range = "Range", dots = "DoTInfo", dot = "DoTInfo", cast = "CastPrediction",
	sorts = "CastPrediction", barres = "SpellDamageInfo", bars = "SpellDamageInfo" }
ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS.combat = function(self, rest)
	local word = ns.AsciiLower and ns.AsciiLower(tostring(rest or "")) or tostring(rest or ""):lower()
	return self:CombatOpenDetails(WORDS[word])
end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then table.insert(section[2], "HELP_COMBAT") end
	end
end

-- Une fois par session, à la connexion : le rival le dit
do
	local said = false
	if ns.On then
		ns.On("PLAYER_ENTERING_WORLD", "combat", function()
			if said or not ns.combatRival then return end
			said = true
			ns:Print(ns:F("MSG_COMBAT_RIVAL", ns:CombatRivalTitle()))
		end, "combat:rival")
	end
end

if ns.Mark then ns.Mark("Combat") end
