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
-- Chaque partie a son interrupteur et ses réglages ici (bêta 2 : la fenêtre
-- du moteur n'est plus montrée) ; l'interrupteur prend effet au /reload.
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

ns.RegisterDefaults({ combatRange = true, combatDots = true, combatCast = true, combatBars = true, combatOneIcon = true })

local FR = {
	OPT_GROUP_COMBAT        = "COMBAT",
	OPT_PAGE_COMBAT_RANGE   = "Portée des sorts",
	OPT_PAGE_COMBAT_RANGE_SUB = "Une coche verte ou une croix rouge au-dessus de ta cible ; les icônes des barres se grisent hors de portée.",
	OPT_PAGE_COMBAT_DOTS    = "DoT mortels",
	OPT_PAGE_COMBAT_DOTS_SUB = "Ce que tes DoT vont encore infliger, sur la barre de vie ; un crâne s'ils tuent.",
	OPT_PAGE_COMBAT_CAST    = "Prédiction des sorts",
	OPT_PAGE_COMBAT_CAST_SUB = "Pendant l'incantation, les dégâts attendus du sort sur la barre de vie de la cible ; une icône s'il la tue.",
	OPT_PAGE_COMBAT_BARS    = "Chiffres des barres",
	OPT_PAGE_COMBAT_BARS_SUB = "Les dégâts (ou soins) de chaque sort, écrits sur son bouton de la barre d'action.",
	OPT_COMBAT_INFO_RANGE_1 = "Mesurée avec les sorts principaux de ta classe ; ça marche aussi en combat.",
	OPT_COMBAT_INFO_DOTS_1  = "Sur la barre de vie : la part que tes DoT vont encore infliger. Si la vie s'arrête dans cette part, la cible est cuite.",
	OPT_COMBAT_INFO_DOTS_2  = "La taille réelle des ticks s'apprend en jouant (résistances comprises).",
	OPT_COMBAT_INFO_CAST_1  = "Une prédiction, pas une promesse : elle s'affine en jouant, les coups critiques n'y comptent pas.",
	OPT_COMBAT_INFO_BARS_1  = "Lus dans la description du sort, avec ta puissance des sorts et tes talents (Forever ne les inclut pas).",
	OPT_COMBAT_INFO_RELOAD  = "Un interrupteur prend effet au rechargement : « Recharger l'interface » apparaît alors en bas.",
	OPT_COMBAT_INFO_CREDIT  = "Moteur repris de DoesItDiePlus (Ironship) et Does It Die (Joe Greive). Merci à eux !",
	OPT_COMBAT_RIVAL        = "%s est installé : il s'occupe de tout ça, Ready2Quest s'efface (la portée d'aggro reste).",
	OPT_COMBAT_SHOW_IN      = "Coche verte à portée",
	OPT_COMBAT_SHOW_OUT     = "Croix rouge hors de portée",
	OPT_COMBAT_DIM          = "Griser les icônes hors de portée",
	OPT_COMBAT_BESIDE       = "Sans barre de nom : près du cadre de cible",
	OPT_COMBAT_ICON_SIZE    = "Taille de l'icône",
	OPT_COMBAT_MARKER       = "Marqueur sur la barre de vie",
	OPT_COMBAT_SKULL        = "Crâne quand c'est mortel",
	OPT_COMBAT_SKULL_POS    = "Place du crâne",
	OPT_COMBAT_SKULL_SIZE   = "Taille du crâne",
	OPT_COMBAT_PLATES       = "Sur les barres de nom",
	OPT_COMBAT_MARGIN       = "Marge de sécurité",
	OPT_COMBAT_SWING        = "Compter un coup d'arme en plus",
	OPT_COMBAT_ONE_ICON     = "Une seule icône au-dessus du monstre",
	OPT_COMBAT_ONE_ICON_DESC = "Le crâne (ou l'arme) prend la place de la coche de portée ; hors de portée, la croix rouge revient.",
	OPT_COMBAT_INFO_DOTS_3  = "Le crâne : tes DoT suffisent. L'arme (baguette, arc, épée) : tes DoT plus un coup d'arme suffisent.",
	OPT_COMBAT_DEATH        = "Prêtre : Mot de l'ombre : Mort sans retour",
	OPT_COMBAT_DEATH_DESC   = "Son icône remplace le crâne au-dessus de la cible quand il la tue à coup sûr (sinon il te renvoie 30 % de ta vie). En recharge ou hors de portée : le crâne revient.",
	OPT_COMBAT_CAST_MARKER  = "Marqueur pendant l'incantation",
	OPT_COMBAT_KILL_ICON    = "Icône quand le sort tue",
	OPT_COMBAT_KILL_SIZE    = "Taille de l'icône",
	OPT_COMBAT_ESTIMATE     = "Dégâts prédits",
	OPT_COMBAT_LEARN        = "Apprendre des coups réels",
	OPT_COMBAT_LABEL        = "Montant écrit sur le marqueur",
	OPT_COMBAT_BUTTON       = "Chiffre sur le bouton",
	OPT_COMBAT_POSITION     = "Place du chiffre",
	OPT_COMBAT_NUM_SIZE     = "Taille du chiffre",
	OPT_COMBAT_TOOLTIP      = "Aussi dans l'infobulle du sort",
	OPT_COMBAT_TALENTS      = "Compter mes talents",
	OPT_COMBAT_POWER        = "Compter ma puissance des sorts",
	COMBAT_POS_portrait     = "Sur le portrait",
	COMBAT_POS_left         = "À gauche de la barre",
	COMBAT_POS_right        = "À droite de la barre",
	COMBAT_POS_above        = "Au-dessus de la barre",
	COMBAT_POS_below        = "Sous la barre",
	COMBAT_PLATE_off        = "Rien",
	COMBAT_PLATE_marker     = "Marqueur",
	COMBAT_PLATE_markerIcon = "Marqueur et icône",
	COMBAT_EST_average      = "Moyenne",
	COMBAT_EST_min          = "Minimum",
	COMBAT_EST_max          = "Maximum",
	COMBAT_BTN_total        = "Total (direct + DoT)",
	COMBAT_BTN_direct       = "Direct seulement",
	COMBAT_BTN_dps          = "Par seconde",
	COMBAT_BTN_off          = "Aucun",
	COMBAT_NUM_bottom       = "En bas",
	COMBAT_NUM_center       = "Au centre",
	COMBAT_NUM_top          = "En haut",
	OPT_PX_UNIT             = "px",
	MSG_COMBAT_RELOAD       = "Combat : le changement prend effet au rechargement (bouton en bas des réglages, ou /reload).",
	MSG_COMBAT_RIVAL        = "Combat : %s est installé, le module Combat de Ready2Quest reste éteint (la portée d'aggro reste).",
	MSG_COMBAT_OFF          = "Combat : module coupé (Réglages › Combat).",
	HELP_COMBAT             = "/r2q combat -- les réglages du module Combat",
}
local EN = {
	OPT_GROUP_COMBAT        = "COMBAT",
	OPT_PAGE_COMBAT_RANGE   = "Spell range",
	OPT_PAGE_COMBAT_RANGE_SUB = "A green check or a red cross above your target; action bar icons grey out when out of range.",
	OPT_PAGE_COMBAT_DOTS    = "Lethal DoTs",
	OPT_PAGE_COMBAT_DOTS_SUB = "What your DoTs will still deal, on the health bar; a skull if they kill.",
	OPT_PAGE_COMBAT_CAST    = "Spell prediction",
	OPT_PAGE_COMBAT_CAST_SUB = "While you cast, the spell's expected damage on the target's health bar; an icon if it kills.",
	OPT_PAGE_COMBAT_BARS    = "Action bar numbers",
	OPT_PAGE_COMBAT_BARS_SUB = "The damage (or healing) of each spell, written on its action button.",
	OPT_COMBAT_INFO_RANGE_1 = "Measured with your class's main spells; it works in combat too.",
	OPT_COMBAT_INFO_DOTS_1  = "On the health bar: what your DoTs will still deal. If the health ends inside it, the target is done for.",
	OPT_COMBAT_INFO_DOTS_2  = "The real tick size is learned as you play (resistances included).",
	OPT_COMBAT_INFO_CAST_1  = "A prediction, not a promise: it sharpens as you play, critical hits don't count.",
	OPT_COMBAT_INFO_BARS_1  = "Read from the spell's description, with your spell power and talents (Forever leaves them out).",
	OPT_COMBAT_INFO_RELOAD  = "A switch takes effect after a reload: \"Reload the interface\" then shows at the bottom.",
	OPT_COMBAT_INFO_CREDIT  = "Engine from DoesItDiePlus (Ironship) and Does It Die (Joe Greive). Thanks to them!",
	OPT_COMBAT_RIVAL        = "%s is installed: it handles all this, Ready2Quest steps aside (aggro range stays).",
	OPT_COMBAT_SHOW_IN      = "Green check in range",
	OPT_COMBAT_SHOW_OUT     = "Red cross out of range",
	OPT_COMBAT_DIM          = "Grey out icons out of range",
	OPT_COMBAT_BESIDE       = "No nameplate: next to the target frame",
	OPT_COMBAT_ICON_SIZE    = "Icon size",
	OPT_COMBAT_MARKER       = "Marker on the health bar",
	OPT_COMBAT_SKULL        = "Skull when it is lethal",
	OPT_COMBAT_SKULL_POS    = "Skull position",
	OPT_COMBAT_SKULL_SIZE   = "Skull size",
	OPT_COMBAT_PLATES       = "On nameplates",
	OPT_COMBAT_MARGIN       = "Safety margin",
	OPT_COMBAT_SWING        = "Count one more weapon swing",
	OPT_COMBAT_ONE_ICON     = "One icon above the monster",
	OPT_COMBAT_ONE_ICON_DESC = "The skull (or the weapon) takes the range check's place; out of range, the red cross comes back.",
	OPT_COMBAT_INFO_DOTS_3  = "The skull: your DoTs are enough. The weapon (wand, bow, sword): your DoTs plus one weapon hit are enough.",
	OPT_COMBAT_DEATH        = "Priest: Shadow Word: Death with no backlash",
	OPT_COMBAT_DEATH_DESC   = "Its icon replaces the skull above the target when it surely kills (otherwise it hits you back for 30% of your health). On cooldown or out of range: the skull comes back.",
	OPT_COMBAT_CAST_MARKER  = "Marker while casting",
	OPT_COMBAT_KILL_ICON    = "Icon when the spell kills",
	OPT_COMBAT_KILL_SIZE    = "Icon size",
	OPT_COMBAT_ESTIMATE     = "Predicted damage",
	OPT_COMBAT_LEARN        = "Learn from real hits",
	OPT_COMBAT_LABEL        = "Amount written on the marker",
	OPT_COMBAT_BUTTON       = "Number on the button",
	OPT_COMBAT_POSITION     = "Number position",
	OPT_COMBAT_NUM_SIZE     = "Number size",
	OPT_COMBAT_TOOLTIP      = "Also in the spell tooltip",
	OPT_COMBAT_TALENTS      = "Count my talents",
	OPT_COMBAT_POWER        = "Count my spell power",
	COMBAT_POS_portrait     = "On the portrait",
	COMBAT_POS_left         = "Left of the bar",
	COMBAT_POS_right        = "Right of the bar",
	COMBAT_POS_above        = "Above the bar",
	COMBAT_POS_below        = "Below the bar",
	COMBAT_PLATE_off        = "Nothing",
	COMBAT_PLATE_marker     = "Marker",
	COMBAT_PLATE_markerIcon = "Marker and icon",
	COMBAT_EST_average      = "Average",
	COMBAT_EST_min          = "Minimum",
	COMBAT_EST_max          = "Maximum",
	COMBAT_BTN_total        = "Total (direct + DoT)",
	COMBAT_BTN_direct       = "Direct only",
	COMBAT_BTN_dps          = "Per second",
	COMBAT_BTN_off          = "None",
	COMBAT_NUM_bottom       = "Bottom",
	COMBAT_NUM_center       = "Centre",
	COMBAT_NUM_top          = "Top",
	OPT_PX_UNIT             = "px",
	MSG_COMBAT_RELOAD       = "Combat: the change takes effect after a reload (button at the bottom of the settings, or /reload).",
	MSG_COMBAT_RIVAL        = "Combat: %s is installed, Ready2Quest's Combat module stays off (aggro range stays).",
	MSG_COMBAT_OFF          = "Combat: module switched off (Settings › Combat).",
	HELP_COMBAT             = "/r2q combat -- the Combat module's settings",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.COMBAT_STRINGS = { fr = FR, en = EN } end

local RIVAL_TITLES = { UsefulPlatesAndTooltips = "DoesItDiePlus", DoesItDie = "Does It Die" }
function ns:CombatRivalTitle()
	return self.combatRival and (RIVAL_TITLES[self.combatRival] or self.combatRival) or nil
end

-- Une partie du moteur tourne-t-elle ?
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
		local ok, on = pcall(ns.CombatPartOn, ns, part or {})
		if part and ok and not on then
			engine.state[name] = "off"
			return false
		end
		return base(name)
	end
end

-- ---------------------------------------------------------------------------
-- Les réglages du moteur, dans nos pages (1.38.0 bêta 2 : plus de fenêtre à
-- part). Chaque ligne lit et écrit la table du moteur (def.store, socle 3.4) ;
-- sans moteur (coupé, rival), le socle écrit dans une table jetable.
-- ---------------------------------------------------------------------------
local function EngineStore(name)
	return function()
		local e = ns.combat
		if not (e and type(e.Settings) == "function") then return nil end
		return e.Settings(name)
	end
end
local function GlobalStore(global)
	return function() local t = rawget(_G, global); return type(t) == "table" and t or nil end
end
local RANGE, CAST = EngineStore("Range"), EngineStore("CastPrediction")
local DOTS = GlobalStore("Ready2QuestCombat_DoTInfoDB")
local BARS = GlobalStore("Ready2QuestCombat_SpellDamageInfoDB")

-- les chiffres des barres se redessinent tout de suite
local function BarsRefresh()
	local m = ns.combat and ns.combat.modules and ns.combat.modules.SpellDamageInfo
	if m and type(m.Refresh) == "function" then pcall(m.Refresh) end
end

local function Choice(key, label, store, prefix, values, onChange)
	return { key = key, label = label, kind = "action",
		choices = function()
			local list = {}
			for _, v in ipairs(values) do list[#list + 1] = { value = v, label = L[prefix .. v] } end
			return list
		end,
		current = function() local t = store(); return t and t[key] end,
		choose = function(value)
			local t = store()
			if t then t[key] = value end
			if onChange then onChange(value) end
		end }
end
local function Bool(key, label, store, onChange)
	return { key = key, label = label, kind = "bool", store = store, onChange = onChange }
end
local function Num(key, label, store, min, max, step, suffix, onChange)
	return { key = key, label = label, kind = "number", store = store, min = min, max = max, step = step,
		suffix = suffix, onChange = onChange }
end

ns.COMBAT_ROWS = {
	combatRange = {
		Bool("showIn", "OPT_COMBAT_SHOW_IN", RANGE),
		Bool("showOut", "OPT_COMBAT_SHOW_OUT", RANGE),
		Bool("dimIcons", "OPT_COMBAT_DIM", RANGE),
		Bool("besideFrame", "OPT_COMBAT_BESIDE", RANGE),
		Num("size", "OPT_COMBAT_ICON_SIZE", RANGE, 16, 48, 2, "OPT_PX_UNIT"),
	},
	combatDots = {
		Bool("showMarkers", "OPT_COMBAT_MARKER", DOTS),
		Bool("showSkull", "OPT_COMBAT_SKULL", DOTS),
		Choice("skullPosition", "OPT_COMBAT_SKULL_POS", DOTS, "COMBAT_POS_", { "portrait", "left", "right", "above", "below" }),
		Num("skullSize", "OPT_COMBAT_SKULL_SIZE", DOTS, 20, 128, 4, "OPT_PX_UNIT"),
		Choice("nameplateMode", "OPT_COMBAT_PLATES", DOTS, "COMBAT_PLATE_", { "off", "marker", "markerIcon" }),
		Num("killMargin", "OPT_COMBAT_MARGIN", DOTS, 50, 100, 5, "OPT_PCT_UNIT"),
		Bool("swingKill", "OPT_COMBAT_SWING", DOTS),
		{ key = "combatOneIcon", label = "OPT_COMBAT_ONE_ICON", kind = "bool",
			describe = function() return L.OPT_COMBAT_ONE_ICON_DESC end },
		{ key = "combatDeath", label = "OPT_COMBAT_DEATH", kind = "bool",
			describe = function() return L.OPT_COMBAT_DEATH_DESC end },
	},
	combatCast = {
		Bool("showMarker", "OPT_COMBAT_CAST_MARKER", CAST),
		Bool("showKillIcon", "OPT_COMBAT_KILL_ICON", CAST),
		Num("killIconSize", "OPT_COMBAT_KILL_SIZE", CAST, 20, 80, 4, "OPT_PX_UNIT"),
		Choice("nameplateMode", "OPT_COMBAT_PLATES", CAST, "COMBAT_PLATE_", { "off", "marker", "markerIcon" }),
		Choice("estimate", "OPT_COMBAT_ESTIMATE", CAST, "COMBAT_EST_", { "average", "min", "max" }),
		Bool("learn", "OPT_COMBAT_LEARN", CAST),
		Bool("showLabel", "OPT_COMBAT_LABEL", CAST),
	},
	combatBars = {
		Choice("button", "OPT_COMBAT_BUTTON", BARS, "COMBAT_BTN_", { "total", "direct", "dps", "off" }, BarsRefresh),
		Choice("position", "OPT_COMBAT_POSITION", BARS, "COMBAT_NUM_", { "bottom", "center", "top" }, BarsRefresh),
		Num("size", "OPT_COMBAT_NUM_SIZE", BARS, 50, 200, 10, "OPT_PCT_UNIT", BarsRefresh),
		Bool("tooltip", "OPT_COMBAT_TOOLTIP", BARS, BarsRefresh),
		Bool("talents", "OPT_COMBAT_TALENTS", BARS, BarsRefresh),
		Bool("estimate", "OPT_COMBAT_POWER", BARS, BarsRefresh),
	},
}

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
		power = "combatRange", info = Info({ "OPT_COMBAT_INFO_RANGE_1" }),
		rows = ns.COMBAT_ROWS.combatRange },
	{ id = "combatDots", title = "OPT_PAGE_COMBAT_DOTS", group = "OPT_GROUP_COMBAT",
		power = "combatDots", info = Info({ "OPT_COMBAT_INFO_DOTS_1", "OPT_COMBAT_INFO_DOTS_3", "OPT_COMBAT_INFO_DOTS_2" }),
		rows = ns.COMBAT_ROWS.combatDots },
	{ id = "combatCast", title = "OPT_PAGE_COMBAT_CAST", group = "OPT_GROUP_COMBAT",
		power = "combatCast", info = Info({ "OPT_COMBAT_INFO_CAST_1" }),
		rows = ns.COMBAT_ROWS.combatCast },
	{ id = "combatBars", title = "OPT_PAGE_COMBAT_BARS", group = "OPT_GROUP_COMBAT",
		power = "combatBars", info = Info({ "OPT_COMBAT_INFO_BARS_1", "OPT_COMBAT_INFO_CREDIT" }),
		rows = ns.COMBAT_ROWS.combatBars },
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


-- Nos réglages, sur la page d'une partie (rival : le chat le dit aussi)
function ns:CombatOpenPage(page)
	if not self.combat then
		local rival = self:CombatRivalTitle()
		self:Print(rival and self:F("MSG_COMBAT_RIVAL", rival) or L.MSG_COMBAT_OFF)
	end
	if not (self.optionsFrame and self.optionsFrame:IsShown()) and self.ToggleOptions then self:ToggleOptions() end
	if self.SelectOptionsPage then self:SelectOptionsPage(page or "aggro") end
	return self.combat ~= nil
end

-- un interrupteur du Combat : prend effet au /reload
do
	local previous = ns.OnModuleToggled
	local keys = {}
	for _, part in ipairs(ns.COMBAT_PARTS) do keys[part.key] = true end
	function ns:OnModuleToggled(key, enabled)
		if previous then previous(self, key, enabled) end
		if keys[key] then
			self:Print(L.MSG_COMBAT_RELOAD)
			-- le bouton « Recharger l'interface » apparaît dans le pied des réglages
			if self.MarkReloadPending then self:MarkReloadPending() end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Une seule icône au-dessus de la cible (bêta 3) : le crâne / l'arme des DoT
-- mortels se pose à la place de la coche de portée et passe au-dessus d'elle
-- (une strate plus haut) ; hors de portée, il est masqué : la croix revient.
-- Le moment où le crâne apparaît reste décidé par la barre du jeu (vie
-- cachée) : on ne fait que le placer et le masquer.
-- ---------------------------------------------------------------------------
local STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local NEXT_STRATA = {}
for index, name in ipairs(STRATA) do NEXT_STRATA[name] = STRATA[index + 1] or name end

local function Ask(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if not ok then return nil end
	return ns.Plain and ns.Plain(a) or a
end

-- Les réglages de placement des DoT suivent ceux de la portée
function ns:CombatAlignIcons(range, dots)
	local offset, size = tonumber(range.offset) or 56, tonumber(range.size) or 26
	local want = { nameplateIconPosition = "above", plateIconOffsetX = 0, plateIconOffsetY = offset - 4,
		nameplateIconSize = size + 2 }
	local changed = false
	for key, value in pairs(want) do
		if dots[key] ~= value then dots[key] = value; changed = true end
	end
	return changed
end

-- Un passage : rend "out" (icône des DoT masquée), "in", ou nil (rien à faire)
function ns:CombatIconsTick()
	local e = self.combat
	if not e or self:DB().combatOneIcon == false then return nil end
	local modules = e.modules or {}
	local range, dotsMod = modules.Range, modules.DoTInfo
	local dots = rawget(_G, "Ready2QuestCombat_DoTInfoDB")
	local rangeSettings = type(e.Settings) == "function" and e.Settings("Range") or nil
	if type(dots) ~= "table" or type(rangeSettings) ~= "table" then return nil end
	self:CombatAlignIcons(rangeSettings, dots)
	local marker = dotsMod and dotsMod.barMarker
	local api = rawget(_G, "C_NamePlate")
	local plate = api and Ask(api.GetNamePlateForUnit, "target")
	if not (marker and type(marker.widgetsFor) == "function" and type(plate) == "table") then return nil end
	local bar = e.Plate and type(e.Plate.HealthBar) == "function" and Ask(e.Plate.HealthBar, plate) or nil
	if not bar then return nil end
	local ok, w = pcall(marker.widgetsFor, plate, bar)
	if not (ok and type(w) == "table" and w.iconWindow) then return nil end
	-- au-dessus de la coche : une strate de plus que la barre
	-- (strate illisible : la coche se replie sur LOW, le crâne passe en MEDIUM)
	local strata = Ask(bar.GetFrameStrata, bar)
	w.iconWindow:SetFrameStrata(type(strata) == "string" and NEXT_STRATA[strata] or "MEDIUM")
	local state = range and type(range.Check) == "function" and Ask(range.Check) or nil
	if state == "out" and rangeSettings.showOut ~= false then
		w.iconWindow:SetAlpha(0)
		w.r2qHidden = true
		return "out"
	elseif w.r2qHidden then
		w.iconWindow:SetAlpha(1)
		w.r2qHidden = nil
	end
	return "in"
end

if engine and ns.Every then
	ns.Every("combat:icons", 0.1, function()
		local ok, err = pcall(ns.CombatIconsTick, ns)
		if not ok and ns.RecordError then ns:RecordError("combat:icons", err) end
	end)
end

-- La fenêtre du moteur n'est plus montrée : ses portes d'entrée (/r2qc, son
-- entrée dans les options AddOns du jeu) ouvrent nos pages
local ENGINE_TABS = { Range = "combatRange", DoTInfo = "combatDots", CastPrediction = "combatCast",
	SpellDamageInfo = "combatBars" }
if engine then
	function engine.OpenSettings(name)
		return ns:CombatOpenPage(ENGINE_TABS[name] or "combatRange")
	end
end

-- ---------------------------------------------------------------------------
-- /r2q combat [aggro|portee|dots|cast|barres] : nos pages Combat
-- ---------------------------------------------------------------------------
local WORDS = { aggro = "aggro", portee = "combatRange", range = "combatRange", dots = "combatDots", dot = "combatDots",
	cast = "combatCast", sorts = "combatCast", barres = "combatBars", bars = "combatBars" }
ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS.combat = function(self, rest)
	local word = ns.AsciiLower and ns.AsciiLower(tostring(rest or "")) or tostring(rest or ""):lower()
	return self:CombatOpenPage(WORDS[word] or "combatRange")
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
