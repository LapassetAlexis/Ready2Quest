-- FeatsCosmetics.lua -- cosmétiques gagnés par les hauts faits (2.7.0, lot E)
--
-- Catalogue docs/QC-HAUTS-FAITS.md §4.2 (compagnon) : deux cadres, deux fonds,
-- sept ornements. Ils rejoignent les listes du compagnon (COMPANION_FRAMES,
-- COMPANION_BACKGROUNDS, COMPANION_ORNAMENTS) avec `unlock = { feat = id }` et
-- `tier = 0` : jamais au coffre, jamais au compteur ; seul le haut fait les
-- donne (ns:FeatGrant pose CompanionData().unlocked["kind:id"]).
--
-- Chargé juste après Feats.lua : les lignes du catalogue qui attendaient
-- (reward.soon) passent en reward.cosmetic dès que le cosmétique existe ici
-- (ns.FeatResolveSoon). Les cosmétiques de la fiche de dresseur (cardbg /
-- cardframe) sont reportés : la récompense s'affiche « fond de fiche (à
-- venir) », jamais un identifiant brut.
--
-- Images : UNIQUEMENT celles du client (aucune texture livrée), par chemin
-- (icônes, carte du monde, minicarte) ou nom d'atlas, relevées dans le
-- listfile et les tables UiTextureAtlas* de Forever (wago.tools). Présence
-- vérifiée en jeu : GetFileIDFromPath pour un fichier (repli sur l'icône
-- suivante de la liste), C_Texture.GetAtlasInfo pour un atlas (pièce sautée).
-- Rendu dans les deux styles : en Sobre, les décors suivent le cadre carré ;
-- en Azeroth (anneau rond, ns.AZEROTH_RING), ils se posent autour de l'anneau
-- et le fond est arrondi par le masque du style (AzerothStyle.lua). Tout est
-- créé à la demande (premier cosmétique porté), rien au chargement.
local ADDON, ns = ...
if ns.blocked then return end

local L = ns.L
local Theme = ns.Theme

local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local GOLD_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border"
local ICONS = "Interface\\Icons\\"
-- pièces du client communes aux ornements : la bordure ronde des boutons de
-- la minicarte (anneau d'or), son disque de fond, le masque rond des portraits
local RING_BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local RING_BACK = "Interface\\Minimap\\UI-Minimap-Background"
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local GLOW_ATLAS = { "BonusChest-CircleGlow", "garrlanding-circleglow" }

-- ---------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------
-- cadres : `deco` = décor en plus (icônes des huit familles, filet et halo
-- arc-en-ciel) ; filets et bordure du client comme les autres cadres
local FRAMES = {
	{ id = "feat_eight", label = "COMP_FRAME_FEAT_EIGHT", tier = 0, unlock = { feat = "men_types_master" },
		edge = { 0.91, 0.65, 0.29, 1 }, inner = { 0.91, 0.65, 0.29, 0.6 }, deco = "eight",
		backdrop = { file = GOLD_BORDER, size = 16, color = { 1, 1, 1 } } },
	{ id = "feat_prism", label = "COMP_FRAME_FEAT_PRISM", tier = 0, unlock = { feat = "meta_shiny" },
		edge = { 1, 1, 1, 0.9 }, inner = { 1, 1, 1, 0.45 }, deco = "prism",
		backdrop = { file = TOOLTIP_BORDER, size = 14, color = { 1, 1, 1 } } },
}
-- fonds : l'Atlas = une case de la carte du monde d'origine (Royaumes de
-- l'Est) ; le Feu de camp = nuit étoilée en dégradé, halo orangé (atlas) et
-- flamme (icône du sort, en ADD : son fond noir disparaît) aux pieds du compagnon
local BACKGROUNDS = {
	{ id = "feat_atlas", label = "COMP_BG_FEAT_ATLAS", tier = 0, unlock = { feat = "zone_100_10" },
		texture = "Interface\\WorldMap\\Azeroth\\Azeroth6", color = { 0.92, 0.90, 0.86, 1 }, coords = { 0.06, 0.94, 0, 1 } },
	{ id = "feat_campfire", label = "COMP_BG_FEAT_CAMPFIRE", tier = 0, unlock = { feat = "char_camp_25" },
		color = { 0.10, 0.06, 0.10, 0.92 }, stars = true, campfire = true,
		gradient = { top = { 0.02, 0.03, 0.10, 0.92 }, bottom = { 0.30, 0.11, 0.04, 0.92 } } },
}
-- ornements : `icons` = icônes du client par ordre de préférence (la
-- première présente gagne) dans l'anneau d'un bouton de minicarte ; `look` :
-- "stars" (trois étoiles des marqueurs de raid), "compass" (minicarte et sa
-- flèche) ; `spin` = halo dont la teinte tourne ; `at` = ancrage (point,
-- point du cadre, x, y)
local ORNAMENTS = {
	{ id = "feat_chain", key = "companionOrnFeatChain", label = "COMP_ORN_FEAT_CHAIN", tier = 0,
		unlock = { feat = "men_boss_1" }, icons = { "Spell_Frost_ChainsOfIce", "Spell_Nature_StrangleVines" },
		size = 24, at = { "BOTTOMLEFT", "BOTTOMLEFT", -8, -8 } },
	{ id = "feat_goldstars", key = "companionOrnFeatGoldstars", label = "COMP_ORN_FEAT_GOLDSTARS", tier = 0,
		unlock = { feat = "men_stars3_100" }, look = "stars", size = 30, at = { "TOP", "BOTTOM", 0, 8 } },
	{ id = "feat_prism_orn", key = "companionOrnFeatPrism", label = "COMP_ORN_FEAT_PRISM", tier = 0,
		unlock = { feat = "shiny_3stars" }, icons = { "INV_Enchant_PrismaticSphere", "INV_Misc_Gem_Diamond_02" },
		size = 22, at = { "TOPLEFT", "TOPLEFT", -9, -14 }, spin = true },
	{ id = "feat_compass", key = "companionOrnFeatCompass", label = "COMP_ORN_FEAT_COMPASS", tier = 0,
		unlock = { feat = "day_travel_1000" }, look = "compass", size = 24, at = { "BOTTOMRIGHT", "BOTTOMRIGHT", 8, -8 } },
	{ id = "feat_anniversary", key = "companionOrnFeatAnniversary", label = "COMP_ORN_FEAT_ANNIVERSARY", tier = 0,
		unlock = { feat = "day_days_365" }, icons = { "INV_Misc_Ribbon_01", "INV_Misc_Gift_01" },
		size = 24, at = { "RIGHT", "RIGHT", 10, -16 } },
	{ id = "feat_eye", key = "companionOrnFeatEye", label = "COMP_ORN_FEAT_EYE", tier = 0,
		unlock = { feat = "dng_raid_aq40" }, icons = { "Achievement_Boss_CThun", "INV_Misc_Eye_01" },
		size = 24, at = { "LEFT", "LEFT", -10, -16 } },
	{ id = "feat_wildcrown", key = "companionOrnFeatWildcrown", label = "COMP_ORN_FEAT_WILDCROWN", tier = 0,
		unlock = { feat = "dng_raid_hyjal" }, icons = { "INV_Crown_14", "INV_Crown_02" },
		size = 24, at = { "BOTTOM", "TOP", 27, -10 } },
}
ns.FEAT_COSMETICS = { frame = FRAMES, bg = BACKGROUNDS, orn = ORNAMENTS }
-- icônes des huit familles (les mêmes que la page Ménagerie du carnet)
local FAMILY_ICONS = {
	beast = "Ability_Hunter_Pet_Wolf", humanoid = "INV_Misc_Head_Human_01", undead = "Spell_Shadow_RaiseDead",
	elemental = "Spell_Fire_Fire", dragonkin = "INV_Misc_Head_Dragon_01", demon = "Spell_Shadow_SummonImp",
	giant = "Spell_Nature_Earthquake", mechanical = "INV_Misc_Gear_01",
}
ns.FEAT_FAMILY_ICONS = FAMILY_ICONS
-- toutes les images du client qu'on appelle (tests : relevées dans le listfile)
ns.FEAT_COSMETIC_CLIENT_FILES = { RING_BORDER, RING_BACK, ROUND_MASK, "Interface\\WorldMap\\Azeroth\\Azeroth6",
	"Interface\\Minimap\\MinimapArrow", "Interface\\Minimap\\CompassNorthTag", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",
	ICONS .. "Spell_Fire_Fire", GOLD_BORDER, TOOLTIP_BORDER }
ns.FEAT_COSMETIC_ATLASES = GLOW_ATLAS

local function Append(list, defs)
	if type(list) ~= "table" then return end
	for _, def in ipairs(defs) do
		local present = false
		for _, have in ipairs(list) do if have.id == def.id then present = true end end
		if not present then list[#list + 1] = def end
	end
end
Append(ns.COMPANION_FRAMES, FRAMES)
Append(ns.COMPANION_BACKGROUNDS, BACKGROUNDS)
Append(ns.COMPANION_ORNAMENTS, ORNAMENTS)

-- ---------------------------------------------------------------------------
-- Chaînes
-- ---------------------------------------------------------------------------
local FR = {
	COMP_FRAME_FEAT_EIGHT     = "Cadre des huit familles",
	COMP_FRAME_FEAT_PRISM     = "Cadre prismatique",
	COMP_BG_FEAT_ATLAS        = "Atlas",
	COMP_BG_FEAT_CAMPFIRE     = "Feu de camp",
	COMP_ORN_FEAT_CHAIN       = "Chaîne du colosse",
	COMP_ORN_FEAT_GOLDSTARS   = "Trois étoiles d'or",
	COMP_ORN_FEAT_PRISM       = "Prisme",
	COMP_ORN_FEAT_COMPASS     = "Boussole",
	COMP_ORN_FEAT_ANNIVERSARY = "Ruban d'anniversaire",
	COMP_ORN_FEAT_EYE         = "Œil clos",
	COMP_ORN_FEAT_WILDCROWN   = "Couronne sauvage",
	COMP_REQ_feat             = "Haut fait : %s",
	FEAT_SOON_cardbg          = "fond de fiche (à venir)",
	FEAT_SOON_cardframe       = "cadre de fiche (à venir)",
	FEAT_SOON_any             = "récompense à venir",
}
local EN = {
	COMP_FRAME_FEAT_EIGHT     = "Frame of the Eight Families",
	COMP_FRAME_FEAT_PRISM     = "Prismatic Frame",
	COMP_BG_FEAT_ATLAS        = "Atlas",
	COMP_BG_FEAT_CAMPFIRE     = "Campfire",
	COMP_ORN_FEAT_CHAIN       = "Colossus Chain",
	COMP_ORN_FEAT_GOLDSTARS   = "Three Gold Stars",
	COMP_ORN_FEAT_PRISM       = "Prism",
	COMP_ORN_FEAT_COMPASS     = "Compass",
	COMP_ORN_FEAT_ANNIVERSARY = "Anniversary Ribbon",
	COMP_ORN_FEAT_EYE         = "Closed Eye",
	COMP_ORN_FEAT_WILDCROWN   = "Wild Crown",
	COMP_REQ_feat             = "Achievement: %s",
	FEAT_SOON_cardbg          = "card background (coming soon)",
	FEAT_SOON_cardframe       = "card frame (coming soon)",
	FEAT_SOON_any             = "reward coming soon",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.FEAT_COSMETIC_STRINGS = { fr = FR, en = EN } end
-- libellés du catalogue : même registre que les autres cosmétiques
if type(ns.COMPANION_STRINGS) == "table" then
	for key in pairs(FR) do
		if key:find("^COMP_") then ns.COMPANION_STRINGS.fr[key], ns.COMPANION_STRINGS.en[key] = FR[key], EN[key] end
	end
end

-- ornements : interrupteurs (affichés par défaut une fois gagnés) et leur
-- ligne dans la sous-page « Ornements » (verrou tant que non gagnés)
do
	local defaults = {}
	for _, def in ipairs(ORNAMENTS) do defaults[def.key] = true end
	ns.RegisterDefaults(defaults)
	for _, page in ipairs(ns.OPTION_PAGES or {}) do
		if page.id == "companionOrnaments" and type(page.rows) == "table" then
			for _, def in ipairs(ORNAMENTS) do
				local present = false
				for _, row in ipairs(page.rows) do if row.key == def.key then present = true end end
				if not present then page.rows[#page.rows + 1] = { key = def.key, label = def.label, kind = "bool" } end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Récompenses des hauts faits : ce qui attendait existe maintenant
-- ---------------------------------------------------------------------------
if ns.FeatResolveSoon then ns.FeatResolveSoon() end

local KNOWN = { frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS", orn = "COMPANION_ORNAMENTS", app = "COMPANION_APPEARANCES" }
local function CosmeticKnown(pair)
	if type(pair) ~= "table" then return false end
	for _, def in ipairs(ns[KNOWN[pair[1]] or ""] or {}) do if def.id == pair[2] then return true end end
	return false
end
function ns:FeatSoonLabel(pair)
	local kind = type(pair) == "table" and pair[1]
	local key = "FEAT_SOON_" .. tostring(kind)
	local text = L[key]
	if text == nil or text == key then text = L.FEAT_SOON_any end
	return text
end

-- Texte de récompense : un cosmétique pas encore fabriqué (reward.soon, ou
-- un id absent du catalogue) se lit « … (à venir) », jamais son id brut
do
	local base = ns.FeatRewardText
	if base then
		function ns:FeatRewardText(def)
			local reward = def and def.reward
			if type(reward) ~= "table" then return base(self, def) end
			local missing = reward.cosmetic ~= nil and not CosmeticKnown(reward.cosmetic)
			if not (reward.soon or missing) then return base(self, def) end
			local copy = {}
			for k, v in pairs(reward) do copy[k] = v end
			copy.soon = nil
			if missing then copy.cosmetic = nil end
			local text = base(self, { id = def.id, reward = copy })
			local soon = self:FeatSoonLabel(reward.soon or reward.cosmetic)
			return text ~= "" and (text .. ", " .. soon) or soon
		end
	end
end

-- Condition lisible (réglages, carnet) : « Haut fait : Les huit familles »
do
	local previous = ns.CompanionRequirement
	function ns:CompanionRequirement(unlock, ...)
		if type(unlock) == "table" and unlock.feat then
			local name = self.FeatName and self:FeatName(unlock.feat)
			if type(name) ~= "string" or name:find("^FEAT_") then name = tostring(unlock.feat) end
			return self:F("COMP_REQ_feat", name)
		end
		if previous then return previous(self, unlock, ...) end
		return ""
	end
end

-- ---------------------------------------------------------------------------
-- Rendu
-- ---------------------------------------------------------------------------
local function Method(object, name, ...)
	if type(object) ~= "table" and type(object) ~= "userdata" then return false end
	local fn = object[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, object, ...)
end
local function Now() return (ns.Now and tonumber(ns.Now())) or 0 end

-- Le fichier existe-t-il dans le client ? (GetFileIDFromPath ; sans l'API, on
-- fait confiance au relevé du listfile)
local fileCache = {}
function ns.FeatClientFile(path)
	if fileCache[path] == nil then
		local api = rawget(_G, "GetFileIDFromPath")
		if type(api) ~= "function" then
			fileCache[path] = true
		else
			local ok, id = pcall(api, path)
			fileCache[path] = ok and id ~= nil and id ~= false and id ~= 0
		end
	end
	return fileCache[path]
end
function ns.FeatFileReset() fileCache = {} end

-- première icône présente d'une liste (nil : aucune, l'ornement se cache)
function ns.FeatPickIcon(list)
	for _, name in ipairs(list or {}) do
		local path = ICONS .. name
		if ns.FeatClientFile(path) then return path end
	end
	return nil
end

local function HasAtlas(name)
	if ns.AzerothHasAtlas then return ns.AzerothHasAtlas(name) end
	local api = rawget(_G, "C_Texture")
	if type(api) ~= "table" or type(api.GetAtlasInfo) ~= "function" then return false end
	local ok, info = pcall(api.GetAtlasInfo, name)
	return ok and info ~= nil
end
-- halo rond du client (premier atlas présent) ; nil s'il n'y en a aucun
local function Glow(parent, layer)
	for _, name in ipairs(GLOW_ATLAS) do
		if HasAtlas(name) then
			local tex = parent:CreateTexture(nil, layer or "ARTWORK")
			if pcall(tex.SetAtlas, tex, name) then
				Method(tex, "SetBlendMode", "ADD")
				tex.atlasName = name
				return tex
			end
			tex:Hide()
		end
	end
	return nil
end

-- teinte (0..1) -> r, g, b, saturée mais claire
local function Hue(h)
	h = (h % 1) * 6
	local i = math.floor(h)
	local f = h - i
	local q, t = 1 - f, f
	local r, g, b
	if i == 0 then r, g, b = 1, t, 0
	elseif i == 1 then r, g, b = q, 1, 0
	elseif i == 2 then r, g, b = 0, 1, t
	elseif i == 3 then r, g, b = 0, q, 1
	elseif i == 4 then r, g, b = t, 0, 1
	else r, g, b = 1, 0, q end
	return 0.45 + 0.55 * r, 0.45 + 0.55 * g, 0.45 + 0.55 * b
end
ns.FeatCosmeticHue = Hue
local SPIN_HZ = 0.1          -- un tour de teinte en 10 s (docs §4.2)
local SPIN_STEP = 0.05       -- s entre deux teintes

local TYPES = ns.CREATURE_TYPES or { "beast", "humanoid", "undead", "elemental", "dragonkin", "demon", "giant", "mechanical" }
-- Sobre : coins et milieux des côtés ; Azeroth : autour de l'anneau
local EIGHT_SOBRE = { "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT", "LEFT" }
local EIGHT_SIZE = 13

local function Azeroth(frame) return frame and frame.uiStyle == "azeroth" end
local function Ring() return ns.AZEROTH_RING or { w = 108, h = 104, y = -45 } end

local function DecoHolder(frame)
	if frame.featDeco then return frame.featDeco end
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetAllPoints(frame)
	Method(holder, "EnableMouse", false)
	-- au-dessus de l'habillage Azeroth (anneau et plaque : niveau + 4)
	local ok, level = Method(frame, "GetFrameLevel")
	if ok and tonumber(level) then Method(holder, "SetFrameLevel", level + 6) end
	frame.featDeco = holder
	return holder
end

-- icône ronde : masque rond si le client en a, sinon recadrée (bord d'icône ôté)
local function RoundIcon(parent, path, layer)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK")
	pcall(tex.SetTexture, tex, path)
	if tex.SetTexCoord then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
	if parent.CreateMaskTexture then
		local ok, mask = pcall(parent.CreateMaskTexture, parent)
		if ok and mask then
			pcall(mask.SetTexture, mask, ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints(tex)
			Method(tex, "AddMaskTexture", mask)
			tex.mask = mask
		end
	end
	return tex
end

local function PaintPrism(frame, holder)
	local t = Now() * SPIN_HZ
	if Azeroth(frame) then
		if holder.halo then holder.halo:SetVertexColor(Hue(t)) end
		return
	end
	-- un côté par quart de tour : le filet entier passe par l'arc-en-ciel
	for index, edge in ipairs({ frame.top, frame.rightEdge, frame.bottom, frame.leftEdge }) do
		if edge and edge.SetVertexColor then
			local r, g, b = Hue(t + (index - 1) * 0.25)
			edge:SetVertexColor(r, g, b, 1)
		end
	end
	if frame.styleBorder and frame.frameBackdrop then
		local r, g, b = Hue(t + 0.5)
		Method(frame.styleBorder, "SetBackdropBorderColor", r, g, b, 1)
	end
end

-- Décor du cadre porté (après CompanionApplyFrame, dans les deux styles)
function ns:FeatApplyFrameDeco()
	local frame = self.companionFrame
	if not frame then return nil end
	local def = self.CompanionCurrentStyle and self:CompanionCurrentStyle("frame")
	local deco = def and def.deco
	if not deco and not frame.featDeco then return nil end
	local holder = DecoHolder(frame)
	local az = Azeroth(frame)
	-- huit icônes de familles (celles du client)
	if deco == "eight" then
		holder.eight = holder.eight or {}
		local ring = Ring()
		for index, key in ipairs(TYPES) do
			local icon = holder.eight[index]
			if not icon then
				icon = RoundIcon(holder, ICONS .. (FAMILY_ICONS[key] or "INV_Misc_QuestionMark"), "OVERLAY")
				icon.family = key
				holder.eight[index] = icon
			end
			icon:SetSize(EIGHT_SIZE, EIGHT_SIZE)
			icon:ClearAllPoints()
			if az then
				local a = math.rad(22.5 + 45 * (index - 1))
				local r = ring.w / 2 - 3
				icon:SetPoint("CENTER", frame, "TOP", r * math.cos(a), ring.y - r * math.sin(a))
			else
				icon:SetPoint("CENTER", frame, EIGHT_SOBRE[index], 0, 0)
			end
			icon:Show()
		end
	elseif holder.eight then
		for _, icon in ipairs(holder.eight) do icon:Hide() end
	end
	-- filet arc-en-ciel (Sobre) ou halo du client qui tourne autour de l'anneau (Azeroth)
	if deco == "prism" then
		if az and holder.halo == nil then holder.halo = Glow(holder, "ARTWORK") or false end
		if holder.halo then
			local ring = Ring()
			holder.halo:ClearAllPoints()
			holder.halo:SetSize(ring.w + 26, ring.w + 26)
			holder.halo:SetPoint("CENTER", frame, "TOP", 0, ring.y)
			if az then holder.halo:Show() else holder.halo:Hide() end
		end
		holder.prismAt = nil
		holder:SetScript("OnUpdate", function(h)
			local now = Now()
			if h.prismAt and now - h.prismAt < SPIN_STEP then return end
			h.prismAt = now
			PaintPrism(frame, h)
		end)
		PaintPrism(frame, holder)
	else
		if holder.halo then holder.halo:Hide() end
		holder:SetScript("OnUpdate", nil)
	end
	holder.deco = deco
	holder:Show()
	return deco
end

-- Un ornement : bouton rond de minicarte (anneau d'or, disque, icône), ou
-- trois étoiles, ou une petite boussole (minicarte, flèche, nord)
local function BuildOrnament(frame, def)
	local holder = DecoHolder(frame)
	local o = CreateFrame("Frame", nil, holder)
	Method(o, "EnableMouse", false)
	local s = def.size
	o:SetSize(s, s)
	o:SetPoint(def.at[1], frame, def.at[2], def.at[3], def.at[4])
	if def.look == "stars" then
		o.stars = {}
		for index, spec in ipairs({ { -10, -2, 11 }, { 0, 2, 14 }, { 10, -2, 11 } }) do
			local star = o:CreateTexture(nil, "OVERLAY")
			pcall(star.SetTexture, star, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
			star:SetSize(spec[3], spec[3])
			star:SetPoint("CENTER", o, "CENTER", spec[1], spec[2])
			o.stars[index] = star
		end
		return o
	end
	local path = def.look ~= "compass" and ns.FeatPickIcon(def.icons) or nil
	if def.look ~= "compass" and not path then return nil end   -- aucune icône dans ce client
	-- géométrie d'un bouton de minicarte (31 px : disque 20 à 7,-5 ; anneau 53)
	local k = s / 31
	if def.spin then
		o.glow = Glow(o, "BACKGROUND")
		if o.glow then
			o.glow:SetSize(s * 1.5, s * 1.5)
			o.glow:SetPoint("CENTER", o, "TOPLEFT", 17 * k, -15 * k)
		end
	end
	o.back = o:CreateTexture(nil, "BACKGROUND")
	pcall(o.back.SetTexture, o.back, RING_BACK)
	o.back:SetSize(20 * k, 20 * k)
	o.back:SetPoint("TOPLEFT", o, "TOPLEFT", 7 * k, -5 * k)
	if def.look == "compass" then
		o.icon = o:CreateTexture(nil, "ARTWORK")
		pcall(o.icon.SetTexture, o.icon, "Interface\\Minimap\\MinimapArrow")
		o.icon:SetSize(16 * k, 16 * k)
		o.icon:SetPoint("CENTER", o.back, "CENTER", 0, 0)
		o.north = o:CreateTexture(nil, "OVERLAY")
		pcall(o.north.SetTexture, o.north, "Interface\\Minimap\\CompassNorthTag")
		o.north:SetSize(9 * k, 9 * k)
		o.north:SetPoint("CENTER", o.back, "TOP", 0, 0)
	else
		o.icon = RoundIcon(o, path, "ARTWORK")
		o.icon:SetSize(18 * k, 18 * k)
		o.icon:SetPoint("CENTER", o.back, "CENTER", 0, 0)
	end
	o.border = o:CreateTexture(nil, "OVERLAY")
	pcall(o.border.SetTexture, o.border, RING_BORDER)
	o.border:SetSize(53 * k, 53 * k)
	o.border:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 0)
	if def.spin and o.glow then
		o:SetScript("OnUpdate", function(f)
			local now = Now()
			if f.at and now - f.at < SPIN_STEP then return end
			f.at = now
			f.glow:SetVertexColor(Hue(now * SPIN_HZ))
		end)
		o.glow:SetVertexColor(Hue(Now() * SPIN_HZ))
	end
	return o
end

-- Ornements des hauts faits
function ns:FeatApplyOrnaments()
	local frame = self.companionFrame
	if not frame then return 0 end
	local shown = 0
	frame.featOrn = frame.featOrn or {}
	for _, def in ipairs(ORNAMENTS) do
		local on = self:CompanionOrnamentShown(def)
		local o = frame.featOrn[def.id]
		if on and o == nil then
			o = BuildOrnament(frame, def) or false
			frame.featOrn[def.id] = o
		end
		if o then
			if on then o:Show(); shown = shown + 1 else o:Hide() end
		end
	end
	if frame.featDeco then frame.featDeco:Show() end
	return shown
end

-- Feu de camp : halo orangé et flamme aux pieds du compagnon, sur le cadre
-- lui-même (sous l'habillage Azeroth, arrondis par son masque s'il existe)
function ns:FeatApplyBackgroundDeco()
	local frame = self.companionFrame
	if not frame then return nil end
	local def = self.CompanionCurrentStyle and self:CompanionCurrentStyle("bg")
	local on = def and def.campfire
	if on and not frame.featFire then
		local fire = {}
		fire.glow = Glow(frame, "BORDER")
		if fire.glow then
			fire.glow:SetSize(78, 60)
			fire.glow:SetPoint("CENTER", frame, "TOP", 0, -74)
			fire.glow:SetVertexColor(1, 0.55, 0.18, 0.9)
		end
		fire.flame = frame:CreateTexture(nil, "BORDER")
		pcall(fire.flame.SetTexture, fire.flame, ICONS .. "Spell_Fire_Fire")
		if fire.flame.SetTexCoord then fire.flame:SetTexCoord(0.1, 0.9, 0.1, 0.9) end
		Method(fire.flame, "SetBlendMode", "ADD")
		fire.flame:SetSize(26, 26)
		fire.flame:SetPoint("CENTER", frame, "TOP", 0, -72)
		frame.featFire = fire
	end
	local fire = frame.featFire
	if not fire then return nil end
	local mask = frame.azSkin and frame.azSkin.mask
	for _, tex in pairs(fire) do
		if on then tex:Show() else tex:Hide() end
		if mask and Azeroth(frame) and not tex.azMasked then
			if Method(tex, "AddMaskTexture", mask) then tex.azMasked = true end
		elseif tex.azMasked and not Azeroth(frame) then
			Method(tex, "RemoveMaskTexture", mask)
			tex.azMasked = nil
		end
	end
	return on
end

-- Accroches : cadre, fond, ornements et passage d'un style à l'autre
do
	local applyFrame = ns.CompanionApplyFrame
	if applyFrame then
		function ns:CompanionApplyFrame(...)
			local a, b = applyFrame(self, ...)
			pcall(self.FeatApplyFrameDeco, self)
			return a, b
		end
	end
	local applyBg = ns.CompanionApplyBackground
	if applyBg then
		function ns:CompanionApplyBackground(...)
			local a, b = applyBg(self, ...)
			pcall(self.FeatApplyBackgroundDeco, self)
			return a, b
		end
	end
	local applyOrn = ns.CompanionApplyOrnaments
	if applyOrn then
		function ns:CompanionApplyOrnaments(...)
			local a, b = applyOrn(self, ...)
			pcall(self.FeatApplyOrnaments, self)
			return a, b
		end
	end
	local applyStyle = ns.CompanionApplyUIStyle
	if applyStyle then
		function ns:CompanionApplyUIStyle(...)
			local a, b = applyStyle(self, ...)
			pcall(self.FeatApplyFrameDeco, self)
			pcall(self.FeatApplyBackgroundDeco, self)
			return a, b
		end
	end
end

if ns.Mark then ns.Mark("FeatsCosmetics") end
