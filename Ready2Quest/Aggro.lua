-- Aggro.lua -- module QoL « Portée d'aggro »
--
-- Un addon ne peut rien dessiner au sol. À la place, tant que le joueur tient
-- la touche choisie (Maj par défaut, ou « toujours »), et hors combat :
--   * au survol d'un PNJ hostile, l'infobulle dit sa portée d'aggro estimée,
--     la distance qui nous en sépare et le verdict
--     (« Aggro ~17 m · tu es à 20-25 m · hors de portée ») ; « ~ » et non
--     « ≈ » : la police des infobulles s'arrête au Latin-1 (« ± », « · » y sont)
--   * une marque colorée sur la barre de nom de chaque PNJ hostile visible :
--     rouge = dans sa portée, ambre = à moins de 5 m de plus, vert =
--     tranquille. Trois styles (réglage « Marque ») : pastille (un losange à
--     gauche de la barre, qui bat quand c'est rouge ; par défaut depuis la
--     1.29.1), trait (une ligne fine sous la barre) ou anneau (le grand halo
--     d'avant). La marque est accrochée au cadre de base de la barre de nom
--     (C_NamePlate), pas à son habillage : elle suit aussi les barres d'un
--     addon (EllesmereUI, Plater…).
--
-- Portée (règles classiques, estimation) : 20 m à niveau égal, 1 m de moins
-- par niveau du joueur au-dessus du monstre, 1 m de plus par niveau en
-- dessous, bornée à [5, 45]. Un neutre (réaction ≥ 4), une bestiole ou un
-- joueur n'a pas d'anneau.
--
-- Distance : aucune position pour une unité hostile. Hors combat, on teste
-- la portée d'objets dont on connaît la portée (C_Item.IsItemInRange, même
-- méthode que LibRangeCheck-2.0), plus CheckInteractDistance en repli : on en
-- tire une fourchette « entre 20 et 25 m ». Tout est sous pcall : le client
-- peut refuser. Sans réponse, l'infobulle ne donne que la portée, sans anneau.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

local AGGRO_BASE   = 20     -- yards, à niveau égal
local AGGRO_MIN    = 5
local AGGRO_MAX    = 45
-- 1.30.0 : un avertissement, pas un constat : le rouge s'allume quelques
-- mètres AVANT la portée estimée (AGGRO_WARN), l'ambre plus loin encore
local AGGRO_WARN   = 5      -- rouge : dès 5 m avant d'entrer dans la portée
local AGGRO_MARGIN = 12     -- ambre : jusqu'à 12 m au-delà de la portée
ns.AGGRO_WARN, ns.AGGRO_MARGIN = AGGRO_WARN, AGGRO_MARGIN
local SKULL_GAP    = 10     -- niveau « ?? » : au moins dix niveaux de plus
ns.AGGRO_TICK = 0.2
ns.AGGRO_RING_SIZE = 96
ns.AGGRO_DOT_SIZE = 16          -- pastille (losange)
ns.AGGRO_DOT_INSET = 14         -- bord droit de la pastille, depuis le bord gauche de la barre : tout près du nom
ns.AGGRO_BAR_W, ns.AGGRO_BAR_H, ns.AGGRO_BAR_Y = 70, 3, 10   -- trait sous la barre
-- anneau livré avec l'addon (Textures/aggro_ring.tga) : présent à coup sûr
ns.AGGRO_RING_TEXTURE = ns.Theme.MEDIA .. "Textures\\aggro_ring"
ns.AGGRO_RING_FALLBACK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- ---------------------------------------------------------------------------
-- Chaînes, réglages, page d'options, module
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_AGGRO       = "Portée d'aggro",
	OPT_AGGRO_KEY        = "Afficher en tenant",
	OPT_AGGRO_TOOLTIP    = "Dans l'infobulle des monstres",
	OPT_AGGRO_RINGS      = "Marque sur les barres de nom",
	OPT_AGGRO_STYLE      = "Marque",
	AGGRO_STYLE_dot      = "Pastille (discrète)",
	AGGRO_STYLE_bar      = "Trait sous la barre",
	AGGRO_STYLE_ring     = "Anneau (grand halo)",
	AGGRO_KEY_shift      = "Maj",
	AGGRO_KEY_ctrl       = "Ctrl",
	AGGRO_KEY_alt        = "Alt",
	AGGRO_KEY_always     = "Toujours (sans touche)",
	AGGRO_UNIT           = "m",
	AGGRO_LINE           = "Aggro ~%s %s · %s · %s",
	AGGRO_LINE_RADIUS    = "Aggro ~%s %s",
	AGGRO_DIST_BAND      = "tu es à %s-%s %s",
	AGGRO_DIST_BELOW     = "tu es à moins de %s %s",
	AGGRO_DIST_BEYOND    = "tu es à plus de %s %s",
	AGGRO_VERDICT_red    = "danger, trop près",
	AGGRO_VERDICT_amber  = "à la limite",
	AGGRO_VERDICT_green  = "hors de portée",
	AGGRO_NEUTRAL        = "Aggro : neutre, n'attaque pas",
	AGGRO_ESTIMATE       = "Estimation : %s %s à niveau égal, ±1 par niveau d'écart.",
	MSG_DIAG_AGGRO_OFF   = "  aggro : module désactivé",
	MSG_DIAG_AGGRO       = "  aggro : touche %s, %s, %d barre(s) de nom, %d anneau(x) ; portée mesurée : %s",
	MSG_DIAG_AGGRO_ON    = "actif",
	MSG_DIAG_AGGRO_IDLE  = "en veille",
	MSG_DIAG_AGGRO_COMBAT = "en combat (masqué)",
	MSG_DIAG_AGGRO_YES   = "oui",
	MSG_DIAG_AGGRO_NO    = "non (aucune réponse)",
	MSG_DIAG_AGGRO_NEVER = "pas encore essayé",
}
local EN = {
	OPT_PAGE_AGGRO       = "Aggro range",
	OPT_AGGRO_KEY        = "Show while holding",
	OPT_AGGRO_TOOLTIP    = "In monster tooltips",
	OPT_AGGRO_RINGS      = "Mark on nameplates",
	OPT_AGGRO_STYLE      = "Mark",
	AGGRO_STYLE_dot      = "Dot (subtle)",
	AGGRO_STYLE_bar      = "Line under the bar",
	AGGRO_STYLE_ring     = "Ring (big glow)",
	AGGRO_KEY_shift      = "Shift",
	AGGRO_KEY_ctrl       = "Ctrl",
	AGGRO_KEY_alt        = "Alt",
	AGGRO_KEY_always     = "Always (no key)",
	AGGRO_UNIT           = "yd",
	AGGRO_LINE           = "Aggro ~%s %s · %s · %s",
	AGGRO_LINE_RADIUS    = "Aggro ~%s %s",
	AGGRO_DIST_BAND      = "you are %s-%s %s away",
	AGGRO_DIST_BELOW     = "you are within %s %s",
	AGGRO_DIST_BEYOND    = "you are over %s %s away",
	AGGRO_VERDICT_red    = "danger, too close",
	AGGRO_VERDICT_amber  = "borderline",
	AGGRO_VERDICT_green  = "out of range",
	AGGRO_NEUTRAL        = "Aggro: neutral, won't attack",
	AGGRO_ESTIMATE       = "Estimate: %s %s at equal level, ±1 per level of difference.",
	MSG_DIAG_AGGRO_OFF   = "  aggro: module disabled",
	MSG_DIAG_AGGRO       = "  aggro: key %s, %s, %d nameplate(s), %d ring(s); range measured: %s",
	MSG_DIAG_AGGRO_ON    = "active",
	MSG_DIAG_AGGRO_IDLE  = "idle",
	MSG_DIAG_AGGRO_COMBAT = "in combat (hidden)",
	MSG_DIAG_AGGRO_YES   = "yes",
	MSG_DIAG_AGGRO_NO    = "no (no answer)",
	MSG_DIAG_AGGRO_NEVER = "not tried yet",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests : chaque clé doit exister dans les deux langues
if ns.KEEP_STRINGS then ns.AGGRO_STRINGS = { fr = FR, en = EN } end

ns.RegisterDefaults({
	aggroEnabled = true,
	aggroKey     = "shift",   -- shift, ctrl, alt ou always
	aggroTooltip = true,
	aggroRings   = true,
	aggroStyle   = "dot",     -- dot, bar ou ring
})
ns.AGGRO_STYLES = { "dot", "bar", "ring" }

ns.AGGRO_KEYS = { "shift", "ctrl", "alt", "always" }
local KEY_TEST = { shift = "IsShiftKeyDown", ctrl = "IsControlKeyDown", alt = "IsAltKeyDown" }

if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "aggro", title = "OPT_PAGE_AGGRO", parent = "qol", group = "OPT_GROUP_QOL",
		rows = {
			{ key = "aggroEnabled", label = "OPT_PAGE_AGGRO",    kind = "bool" },
			{ key = "aggroKey",     label = "OPT_AGGRO_KEY",     kind = "action",
				choices = function() return ns:AggroKeyChoices() end,
				current = function() return ns:AggroKey() end,
				choose = function(value) ns:AggroSetKey(value) end },
			{ key = "aggroTooltip", label = "OPT_AGGRO_TOOLTIP", kind = "bool" },
			{ key = "aggroRings",   label = "OPT_AGGRO_RINGS",   kind = "bool" },
			{ key = "aggroStyle",   label = "OPT_AGGRO_STYLE",   kind = "action",
				choices = function() return ns:AggroStyleChoices() end,
				current = function() return ns:AggroStyle() end,
				choose = function(value) ns:AggroSetStyle(value) end },
		},
	})
end

if ns.RegisterModule then
	ns.RegisterModule({ id = "aggro", key = "aggroEnabled", label = "OPT_PAGE_AGGRO",
		aliases = { "aggro", "portee" } })
end

-- ---------------------------------------------------------------------------
-- Accès robustes au client
-- ---------------------------------------------------------------------------
local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return ns.Plain(a), ns.Plain(b) end
	return nil
end

local function Num(value) return tonumber(ns.Plain(value)) end

function ns:AggroOn()
	return self:DB().aggroEnabled ~= false
end

function ns:AggroKey()
	local key = self:DB().aggroKey
	if KEY_TEST[key] or key == "always" then return key end
	return "shift"
end

function ns:AggroSetKey(value)
	if KEY_TEST[value] or value == "always" then self:DB().aggroKey = value end
	self:AggroRefresh()
end

function ns:AggroStyle()
	local style = self:DB().aggroStyle
	for _, key in ipairs(self.AGGRO_STYLES) do if key == style then return style end end
	return "dot"
end

function ns:AggroSetStyle(value)
	for _, key in ipairs(self.AGGRO_STYLES) do if key == value then self:DB().aggroStyle = value end end
	for _, ring in pairs(self.aggroRings or {}) do ring.style = nil end
	self:AggroRefresh()
end

function ns:AggroStyleChoices()
	local list = {}
	for _, key in ipairs(self.AGGRO_STYLES) do list[#list + 1] = { value = key, label = L["AGGRO_STYLE_" .. key] } end
	return list
end

function ns:AggroKeyChoices()
	local list = {}
	for _, key in ipairs(self.AGGRO_KEYS) do list[#list + 1] = { value = key, label = L["AGGRO_KEY_" .. key] } end
	return list
end

function ns:AggroKeyHeld()
	local key = self:AggroKey()
	if key == "always" then return true end
	return Call(KEY_TEST[key]) and true or false
end

function ns:AggroInCombat()
	if Call("UnitAffectingCombat", "player") then return true end
	return Call("InCombatLockdown") and true or false
end

-- Module actif, touche tenue, hors combat
function ns:AggroActive()
	return self:AggroOn() and not self:AggroInCombat() and self:AggroKeyHeld()
end

-- ---------------------------------------------------------------------------
-- Portée estimée et verdict
-- ---------------------------------------------------------------------------
-- Portée d'aggro (yards) d'un monstre de niveau mobLevel pour un joueur de
-- niveau playerLevel. Niveau « ?? » (-1) : dix niveaux de plus que le joueur.
function ns.AggroRadius(playerLevel, mobLevel)
	playerLevel, mobLevel = Num(playerLevel), Num(mobLevel)
	if not playerLevel or not mobLevel then return nil end
	if mobLevel <= 0 then mobLevel = playerLevel + SKULL_GAP end
	local radius = AGGRO_BASE + (mobLevel - playerLevel)
	if radius < AGGRO_MIN then radius = AGGRO_MIN end
	if radius > AGGRO_MAX then radius = AGGRO_MAX end
	return radius
end

-- Verdict d'une fourchette de distance [low, high] (high nil : au-delà de
-- la dernière mesure) : "red" dans la portée ou à moins de AGGRO_WARN de son
-- bord (1.30.0 : on prévient avant), "amber" à moins de AGGRO_MARGIN au-delà,
-- "green" plus loin ; nil sans mesure.
function ns.AggroVerdict(radius, low, high)
	radius, low, high = Num(radius), Num(low), Num(high)
	if not radius or (not low and not high) then return nil end
	low = low or 0
	if high and high <= radius + AGGRO_WARN then return "red" end
	if low < radius + AGGRO_MARGIN then return "amber" end
	return "green"
end

ns.AGGRO_COLORS = { red = Theme.RED, amber = Theme.ORANGE, green = Theme.GREEN }

-- ---------------------------------------------------------------------------
-- Distance par paliers (approche de LibRangeCheck-2.0, contrôles « hostiles »)
-- Chaque palier : une portée en yards et des objets de cette portée ; le
-- premier qui répond suffit. Les objets des extensions suivantes peuvent
-- manquer au client classique : ils ne répondent pas, le palier est sauté.
-- ---------------------------------------------------------------------------
ns.AGGRO_RANGE_ITEMS = {
	{ 5,  { 8149 } },                    -- Charme vaudou
	{ 8,  { 34368, 33278 } },            -- Noyaux de cristal harmonisés, Torche ardente
	{ 10, { 32321 } },                   -- Filet d'épervier
	{ 15, { 33069 } },                   -- Corde solide
	{ 20, { 10645 } },                   -- Rayon de la mort gnome
	{ 25, { 24268, 41509, 31463 } },     -- Filet en tisse-néant, Filet en tisse-givre, Éclat de Zezzak
	{ 30, { 835, 7734, 34191 } },        -- Grand filet en corde, Sac aux six démons, Poignée de flocons
	{ 35, { 24269, 18904 } },            -- Filet en tisse-néant lourd, Ultra-rapetisseur de Zorbin
	{ 40, { 28767 } },                   -- Le Décapiteur
	{ 45, { 23836 } },                   -- Lance-roquettes gobelin
	{ 60, { 32825, 37887 } },            -- Canon à âmes, Graines de colère de la nature
	{ 80, { 35278 } },                   -- Filet renforcé
}
-- CheckInteractDistance : 3 = duel (~10 m), 4 = suivre (~28 m)
ns.AGGRO_INTERACT = { { 10, 3 }, { 28, 4 } }

local function ItemInRange(itemID, unit)
	local api = rawget(_G, "C_Item")
	local fn = (type(api) == "table" and type(api.IsItemInRange) == "function" and api.IsItemInRange)
		or rawget(_G, "IsItemInRange")
	if type(fn) ~= "function" then return nil end
	local ok, result = pcall(fn, itemID, unit)
	if not ok then return nil end
	result = ns.Plain(result)
	if result == nil then
		-- objet pas encore en cache : on le demande, une fois
		ns.aggroItemAsked = ns.aggroItemAsked or {}
		if ns.ItemInfo and not ns.aggroItemAsked[itemID] then
			ns.aggroItemAsked[itemID] = true
			pcall(ns.ItemInfo, itemID)
		end
		return nil
	end
	return result == true or result == 1
end

local function InteractInRange(index, unit)
	local fn = rawget(_G, "CheckInteractDistance")
	if type(fn) ~= "function" then return nil end
	local ok, result = pcall(fn, unit, index)
	if not ok then return nil end
	result = ns.Plain(result)
	if result == nil then return nil end
	return result == true or result == 1
end

-- Paliers (portée, test) triés, objets et interaction mêlés
local function Ladder()
	if ns.aggroLadder then return ns.aggroLadder end
	local ladder = {}
	for _, step in ipairs(ns.AGGRO_RANGE_ITEMS) do
		local items = step[2]
		ladder[#ladder + 1] = { range = step[1], test = function(unit)
			for _, itemID in ipairs(items) do
				local result = ItemInRange(itemID, unit)
				if result ~= nil then return result end
			end
			return nil
		end }
	end
	for _, step in ipairs(ns.AGGRO_INTERACT) do
		local index = step[2]
		ladder[#ladder + 1] = { range = step[1], test = function(unit) return InteractInRange(index, unit) end }
	end
	table.sort(ladder, function(a, b) return a.range < b.range end)
	ns.aggroLadder = ladder
	return ladder
end

-- Fourchette de distance d'une unité : low, high (high nil : au-delà du
-- dernier palier). nil, nil : aucune mesure (client fermé, unité absente).
ns.AGGRO_DISTANCE_CACHE = 0.5   -- s : une mesure par unité, pas une par image
function ns:AggroDistance(unit)
	local now = (ns.Now and ns.Now()) or 0
	local guid = ns.Plain(rawget(_G, "UnitGUID") and select(2, pcall(UnitGUID, unit)))
	self.aggroDistCache = self.aggroDistCache or {}
	local cached = self.aggroDistCache[unit]
	if cached and cached.guid == guid and guid ~= nil and now >= cached.at and now - cached.at < ns.AGGRO_DISTANCE_CACHE then
		return cached.low, cached.high
	end
	local low, high = self:AggroMeasure(unit)
	self.aggroDistCache[unit] = { guid = guid, at = now, low = low, high = high }
	return low, high
end

function ns:AggroMeasure(unit)
	local low, high, answered = 0, nil, false
	for _, step in ipairs(Ladder()) do
		local ok, inRange = pcall(step.test, unit)
		if ok and inRange ~= nil then
			answered = true
			if inRange then high = step.range; break end
			if step.range > low then low = step.range end
		end
	end
	-- pour /r2q diag : le client a-t-il déjà répondu une fois ?
	if answered then self.aggroMeasured = true elseif self.aggroMeasured ~= true then self.aggroMeasured = false end
	if not answered then return nil, nil end
	return low, high
end

-- ---------------------------------------------------------------------------
-- Quelles unités : PNJ hostile, attaquable, vivant, pas une bestiole
-- ---------------------------------------------------------------------------
local CRITTER = { Critter = true, Bestiole = true, ["Non-combat Pet"] = true, ["Mascotte"] = true }

-- "hostile", "neutral" ou nil (rien à dire : joueur, ami, bestiole, mort…)
function ns:AggroUnitKind(unit)
	if type(unit) ~= "string" then return nil end
	if not Call("UnitExists", unit) then return nil end
	if Call("UnitIsPlayer", unit) then return nil end
	if Call("UnitIsDead", unit) then return nil end
	if not Call("UnitCanAttack", "player", unit) then return nil end
	local creature = Call("UnitCreatureType", unit)
	if creature and CRITTER[creature] then return nil end
	local reaction = Num((Call("UnitReaction", unit, "player")))
	if reaction and reaction >= 4 then return "neutral" end
	return "hostile"
end

-- Portée, fourchette et verdict d'une unité hostile
function ns:AggroEvaluate(unit)
	local radius = ns.AggroRadius(Call("UnitLevel", "player"), Call("UnitLevel", unit))
	if not radius then return nil end
	local low, high = self:AggroDistance(unit)
	return { radius = radius, low = low, high = high, verdict = ns.AggroVerdict(radius, low, high) }
end

local function Yards(value) return tostring(math.floor((tonumber(value) or 0) + 0.5)) end

-- Texte de l'infobulle et sa couleur (table rgb) ; nil si rien à dire
function ns:AggroTooltipText(unit)
	local kind = self:AggroUnitKind(unit)
	if not kind then return nil end
	if kind == "neutral" then return L.AGGRO_NEUTRAL, Theme.MUTED end
	local eval = self:AggroEvaluate(unit)
	if not eval then return nil end
	local u = L.AGGRO_UNIT
	if not eval.verdict then
		return self:F("AGGRO_LINE_RADIUS", Yards(eval.radius), u), Theme.GOLD
	end
	local distance
	if eval.high == nil then
		distance = self:F("AGGRO_DIST_BEYOND", Yards(eval.low), u)
	elseif (eval.low or 0) <= 0 then
		distance = self:F("AGGRO_DIST_BELOW", Yards(eval.high), u)
	else
		distance = self:F("AGGRO_DIST_BAND", Yards(eval.low), Yards(eval.high), u)
	end
	local text = self:F("AGGRO_LINE", Yards(eval.radius), u, distance, L["AGGRO_VERDICT_" .. eval.verdict])
	return text, self.AGGRO_COLORS[eval.verdict]
end

-- ---------------------------------------------------------------------------
-- Infobulle
-- ---------------------------------------------------------------------------
local function TooltipUnit(tooltip)
	if type(tooltip) == "table" and type(tooltip.GetUnit) == "function" then
		local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
		unit = ok and ns.Plain(unit) or nil
		if type(unit) == "string" then return unit end
	end
	return "mouseover"
end

function ns:AggroOnTooltip(tooltip, data)
	if not self:AggroActive() or self:DB().aggroTooltip == false then return false end
	local text, color = self:AggroTooltipText(TooltipUnit(tooltip))
	if not text then return false end
	tooltip:AddLine(text, color[1], color[2], color[3])
	if text ~= L.AGGRO_NEUTRAL then
		local m = Theme.MUTED
		tooltip:AddLine(self:F("AGGRO_ESTIMATE", tostring(AGGRO_BASE), L.AGGRO_UNIT), m[1], m[2], m[3], true)
	end
	-- accroche OnTooltipSetUnit (pas de data) : le cadre reprend sa taille
	if data == nil and type(tooltip.Show) == "function" then pcall(tooltip.Show, tooltip) end
	return true
end

if ns.HookTooltip then
	ns:HookTooltip("Unit", function(tooltip, data) ns:AggroOnTooltip(tooltip, data) end)
end

-- Touche pressée ou relâchée sur un monstre déjà survolé : l'infobulle est
-- reconstruite, sinon la ligne n'apparaîtrait qu'au survol suivant
function ns:AggroRefreshTooltip()
	local tooltip = rawget(_G, "GameTooltip")
	if type(tooltip) ~= "table" or type(tooltip.SetUnit) ~= "function" then return end
	if not (type(tooltip.IsShown) == "function" and tooltip:IsShown()) then return end
	-- touche sans effet ici (module coupé, « toujours ») : on ne touche à rien
	if not self:AggroOn() or self:DB().aggroTooltip == false or self:AggroKey() == "always" then return end
	if not Call("UnitExists", "mouseover") or self:AggroInCombat() then return end
	if not self:AggroUnitKind("mouseover") then return end
	if TooltipUnit(tooltip) ~= "mouseover" then return end
	pcall(tooltip.SetUnit, tooltip, "mouseover")
end

-- ---------------------------------------------------------------------------
-- Anneaux sur les barres de nom
-- ---------------------------------------------------------------------------
ns.aggroPlates = ns.aggroPlates or {}   -- unité -> cadre de base de la barre
ns.aggroRings = ns.aggroRings or {}     -- cadre de base -> anneau

local function PlateForUnit(unit)
	local api = rawget(_G, "C_NamePlate")
	if type(api) ~= "table" or type(api.GetNamePlateForUnit) ~= "function" then return nil end
	local ok, plate = pcall(api.GetNamePlateForUnit, unit)
	if not ok or type(plate) ~= "table" then return nil end
	-- barre interdite aux addons (amis en instance) : on n'y touche pas
	if type(plate.IsForbidden) == "function" then
		local okF, forbidden = pcall(plate.IsForbidden, plate)
		if okF and forbidden then return nil end
	end
	return plate
end

local function RingFor(plate)
	local ring = ns.aggroRings[plate]
	if ring then return ring end
	local ok, frame = pcall(CreateFrame, "Frame", nil, plate)
	if not ok or not frame then return nil end
	local size = ns.AGGRO_RING_SIZE
	frame:SetSize(size, size)
	frame:SetPoint("CENTER", plate, "CENTER", 0, 0)
	if frame.SetFrameLevel and plate.GetFrameLevel then
		frame.plateLevel = tonumber(plate:GetFrameLevel()) or 1
		pcall(frame.SetFrameLevel, frame, math.max(0, frame.plateLevel - 1))
	end
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints(frame)
	-- anneau livré avec l'addon ; si le client le refuse, un disque translucide
	local okSet, set = pcall(texture.SetTexture, texture, ns.AGGRO_RING_TEXTURE)
	if not okSet or set == false then texture:SetTexture(ns.AGGRO_RING_FALLBACK); frame.fallback = true end
	if texture.SetBlendMode then pcall(texture.SetBlendMode, texture, "ADD") end
	frame.ringTexture = texture
	-- pastille : un losange à gauche de la barre, avec un liseré sombre
	frame.dotBack = frame:CreateTexture(nil, "ARTWORK")
	frame.dotBack:SetTexture(Theme.DIAMOND)
	frame.dotBack:SetSize(ns.AGGRO_DOT_SIZE + 4, ns.AGGRO_DOT_SIZE + 4)
	frame.dotBack:SetPoint("RIGHT", plate, "LEFT", ns.AGGRO_DOT_INSET, 0)
	frame.dotBack:SetVertexColor(0, 0, 0, 0.8)
	frame.dot = frame:CreateTexture(nil, "OVERLAY")
	frame.dot:SetTexture(Theme.DIAMOND)
	frame.dot:SetSize(ns.AGGRO_DOT_SIZE, ns.AGGRO_DOT_SIZE)
	frame.dot:SetPoint("CENTER", frame.dotBack, "CENTER", 0, 0)
	-- trait : une ligne fine sous la barre
	frame.bar = frame:CreateTexture(nil, "OVERLAY")
	frame.bar:SetTexture(Theme.SOLID or "Interface\\Buttons\\WHITE8X8")
	frame.bar:SetSize(ns.AGGRO_BAR_W, ns.AGGRO_BAR_H)
	frame.bar:SetPoint("TOP", plate, "BOTTOM", 0, ns.AGGRO_BAR_Y)
	frame.texture = texture
	frame:Hide()
	ns.aggroRings[plate] = frame
	return frame
end

function ns:AggroHideRing(unit)
	local plate = self.aggroPlates[unit]
	local ring = plate and self.aggroRings[plate]
	if ring then ring:Hide(); ring.verdict = nil end
end

function ns:AggroHideAll()
	for _, ring in pairs(self.aggroRings) do ring:Hide(); ring.verdict = nil end
end

-- Pose (ou retire) l'anneau d'une unité ; rend le verdict affiché ou nil
function ns:AggroUpdatePlate(unit)
	local plate = self.aggroPlates[unit] or PlateForUnit(unit)
	if not plate then return nil end
	self.aggroPlates[unit] = plate
	local verdict
	if self:AggroUnitKind(unit) == "hostile" then
		local eval = self:AggroEvaluate(unit)
		verdict = eval and eval.verdict
	end
	if not verdict then
		self:AggroHideRing(unit)
		return nil
	end
	local ring = RingFor(plate)
	if not ring then return nil end
	local color = self.AGGRO_COLORS[verdict]
	local style = self:AggroStyle()
	if ring.style ~= style then
		ring.style = style
		-- l'anneau occupe tout le cadre ; pastille et trait se tiennent à la barre
		local isRing = style == "ring"
		ring:SetSize(isRing and ns.AGGRO_RING_SIZE or 1, isRing and ns.AGGRO_RING_SIZE or 1)
		if isRing then ring.ringTexture:Show() else ring.ringTexture:Hide() end
		if style == "dot" then ring.dot:Show(); ring.dotBack:Show() else ring.dot:Hide(); ring.dotBack:Hide() end
		if style == "bar" then ring.bar:Show() else ring.bar:Hide() end
		-- l'anneau passe sous la barre ; pastille et trait au-dessus d'elle
		if ring.SetFrameLevel and ring.plateLevel then
			pcall(ring.SetFrameLevel, ring, math.max(0, ring.plateLevel + (isRing and -1 or 5)))
		end
	end
	ring.texture = (style == "dot" and ring.dot) or (style == "bar" and ring.bar) or ring.ringTexture
	ring.texture:SetVertexColor(color[1], color[2], color[3])
	if style == "ring" then
		ring:SetAlpha(verdict == "green" and 0.45 or (ring.fallback and 0.35 or 0.9))
	elseif verdict == "red" then
		-- rouge : la marque bat (un battement par seconde, au rythme du tick)
		local now = (ns.Now and ns.Now()) or 0
		ring:SetAlpha(0.6 + 0.4 * math.abs(math.sin(now * math.pi)))
	else
		ring:SetAlpha(verdict == "green" and 0.6 or 1)
	end
	ring.verdict = verdict
	ring:Show()
	return verdict
end

-- Une passe : tout masquer hors état actif, sinon chaque barre connue
function ns:AggroTick()
	local active = self:AggroActive()
	if not active or self:DB().aggroRings == false then
		if self.aggroShowing then self:AggroHideAll() end
		self.aggroShowing = nil
		return
	end
	self.aggroShowing = true
	-- barres déjà là avant le premier passage (ou avant /reload)
	local api = rawget(_G, "C_NamePlate")
	if not self.aggroScanned and type(api) == "table" and type(api.GetNamePlates) == "function" then
		self.aggroScanned = true
		local ok, plates = pcall(api.GetNamePlates)
		for _, plate in ipairs(ok and type(plates) == "table" and plates or {}) do
			local unit = ns.Plain(plate.namePlateUnitToken)
			if type(unit) == "string" then self.aggroPlates[unit] = plate end
		end
	end
	for unit in pairs(self.aggroPlates) do
		local ok, err = pcall(self.AggroUpdatePlate, self, unit)
		if not ok and self.RecordError then self:RecordError("aggro:plate", err) end
	end
end

function ns:AggroRefresh()
	self:AggroTick()
	self:AggroRefreshTooltip()
end

function ns:AggroDiagLine()
	if not self:AggroOn() then return L.MSG_DIAG_AGGRO_OFF end
	local state = (self:AggroInCombat() and L.MSG_DIAG_AGGRO_COMBAT)
		or (self:AggroKeyHeld() and L.MSG_DIAG_AGGRO_ON) or L.MSG_DIAG_AGGRO_IDLE
	local plates, rings = 0, 0
	for _ in pairs(self.aggroPlates) do plates = plates + 1 end
	for _, ring in pairs(self.aggroRings) do if ring:IsShown() then rings = rings + 1 end end
	local measured = (self.aggroMeasured == true and L.MSG_DIAG_AGGRO_YES)
		or (self.aggroMeasured == false and L.MSG_DIAG_AGGRO_NO) or L.MSG_DIAG_AGGRO_NEVER
	return self:F("MSG_DIAG_AGGRO", tostring(L["AGGRO_KEY_" .. self:AggroKey()]), state, plates, rings, measured)
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
local HANDLERS = {
	NAME_PLATE_UNIT_ADDED = function(unit)
		unit = ns.Plain(unit)
		if type(unit) ~= "string" then return end
		ns.aggroPlates[unit] = PlateForUnit(unit)
		if ns.aggroShowing then ns:AggroUpdatePlate(unit) end
	end,
	NAME_PLATE_UNIT_REMOVED = function(unit)
		unit = ns.Plain(unit)
		if type(unit) ~= "string" then return end
		ns:AggroHideRing(unit)
		ns.aggroPlates[unit] = nil
	end,
	MODIFIER_STATE_CHANGED = function() ns:AggroRefresh() end,
	PLAYER_REGEN_DISABLED  = function() ns:AggroHideAll(); ns.aggroShowing = nil end,
	PLAYER_REGEN_ENABLED   = function() ns:AggroTick() end,
	PLAYER_ENTERING_WORLD  = function()
		ns.aggroPlates, ns.aggroScanned = {}, nil
		ns:AggroHideAll()
		ns.aggroShowing = nil
	end,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("aggro:" .. tostring(event), err) end
end)
-- rafraîchissement tant que la touche est tenue (le joueur bouge)
eventFrame:SetScript("OnUpdate", ns.Throttle(ns.AGGRO_TICK, function()
	local ok, err = pcall(ns.AggroTick, ns)
	if not ok and ns.RecordError then ns:RecordError("aggro:tick", err) end
end))
ns.aggroEventFrame = eventFrame

if ns.Mark then ns.Mark("Aggro") end
