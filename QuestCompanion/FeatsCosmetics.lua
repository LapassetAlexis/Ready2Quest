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
-- (ns.FeatResolveSoon, FeatsCatMenagerie.lua). Les cosmétiques de la fiche de
-- dresseur (cardbg / cardframe) sont reportés : ils restent en attente et la
-- récompense s'affiche « fond de fiche (à venir) », jamais un identifiant brut.
--
-- Textures : tools/gen_feat_cosmetics.py (déterministe) -> Textures/feat_atlas,
-- feat_campfire (fonds, 256x256) et feat_ornaments (512x64, huit cases de 64 px).
-- Rendu : les deux styles. En Sobre, les décors suivent le cadre carré ; en
-- Azeroth (anneau rond, ns.AZEROTH_RING), ils se posent autour de l'anneau et
-- le fond est arrondi par le masque du style (AzerothStyle.lua). Tout est créé
-- à la demande (premier cosmétique porté), rien au chargement.
local ADDON, ns = ...
if ns.blocked then return end

local L = ns.L
local Theme = ns.Theme

local TEX = "Interface\\AddOns\\" .. tostring(ADDON or "QuestCompanion") .. "\\Textures\\"
local SHEET = TEX .. "feat_ornaments"
local SHEET_CELLS = 8
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local GOLD_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border"
ns.FEAT_COSMETIC_TEXTURES = { "feat_atlas", "feat_campfire", "feat_ornaments" }

-- ---------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------
-- cadres : `deco` = décor dessiné en plus (losanges des huit familles, filet
-- arc-en-ciel) ; filets et bordure du client comme les autres cadres
local FRAMES = {
	{ id = "feat_eight", label = "COMP_FRAME_FEAT_EIGHT", tier = 0, unlock = { feat = "men_types_master" },
		edge = { 0.91, 0.65, 0.29, 1 }, inner = { 0.91, 0.65, 0.29, 0.6 }, deco = "eight",
		backdrop = { file = GOLD_BORDER, size = 16, color = { 1, 1, 1 } } },
	{ id = "feat_prism", label = "COMP_FRAME_FEAT_PRISM", tier = 0, unlock = { feat = "meta_shiny" },
		edge = { 1, 1, 1, 0.9 }, inner = { 1, 1, 1, 0.45 }, deco = "prism",
		backdrop = { file = TOOLTIP_BORDER, size = 14, color = { 1, 1, 1 } } },
}
-- fonds : nos textures, recadrées au format du cadre (104x118)
local BACKGROUNDS = {
	{ id = "feat_atlas", label = "COMP_BG_FEAT_ATLAS", tier = 0, unlock = { feat = "zone_100_10" },
		texture = TEX .. "feat_atlas", color = { 1, 1, 1, 0.96 }, coords = { 0.06, 0.94, 0, 1 } },
	{ id = "feat_campfire", label = "COMP_BG_FEAT_CAMPFIRE", tier = 0, unlock = { feat = "char_camp_25" },
		texture = TEX .. "feat_campfire", color = { 1, 1, 1, 0.96 }, coords = { 0.06, 0.94, 0, 1 } },
}
-- ornements : `cell` = case de la feuille ; `at` = ancrage (point, point du
-- cadre, x, y) et taille ; `spin` = teinte qui tourne (prisme)
local ORNAMENTS = {
	{ id = "feat_chain", key = "companionOrnFeatChain", label = "COMP_ORN_FEAT_CHAIN", tier = 0,
		unlock = { feat = "men_boss_1" }, cell = 0, size = 26, at = { "BOTTOMLEFT", "BOTTOMLEFT", -8, -8 } },
	{ id = "feat_goldstars", key = "companionOrnFeatGoldstars", label = "COMP_ORN_FEAT_GOLDSTARS", tier = 0,
		unlock = { feat = "men_stars3_100" }, cell = 1, size = 30, at = { "TOP", "BOTTOM", 0, 9 } },
	{ id = "feat_prism_orn", key = "companionOrnFeatPrism", label = "COMP_ORN_FEAT_PRISM", tier = 0,
		unlock = { feat = "shiny_3stars" }, cell = 6, size = 22, at = { "TOPLEFT", "TOPLEFT", -9, -14 }, spin = true },
	{ id = "feat_compass", key = "companionOrnFeatCompass", label = "COMP_ORN_FEAT_COMPASS", tier = 0,
		unlock = { feat = "day_travel_1000" }, cell = 4, size = 24, at = { "BOTTOMRIGHT", "BOTTOMRIGHT", 8, -8 } },
	{ id = "feat_anniversary", key = "companionOrnFeatAnniversary", label = "COMP_ORN_FEAT_ANNIVERSARY", tier = 0,
		unlock = { feat = "day_days_365" }, cell = 5, size = 24, at = { "RIGHT", "RIGHT", 10, -16 } },
	{ id = "feat_eye", key = "companionOrnFeatEye", label = "COMP_ORN_FEAT_EYE", tier = 0,
		unlock = { feat = "dng_raid_aq40" }, cell = 2, size = 24, at = { "LEFT", "LEFT", -10, -16 } },
	{ id = "feat_wildcrown", key = "companionOrnFeatWildcrown", label = "COMP_ORN_FEAT_WILDCROWN", tier = 0,
		unlock = { feat = "dng_raid_hyjal" }, cell = 3, size = 26, at = { "BOTTOM", "TOP", 27, -8 } },
}
local HALO_CELL = 7
ns.FEAT_COSMETICS = { frame = FRAMES, bg = BACKGROUNDS, orn = ORNAMENTS }

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

-- teinte (0..1) -> r, g, b, saturée mais claire (le prisme reste lumineux)
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

local function Cell(tex, index)
	pcall(tex.SetTexture, tex, SHEET)
	if tex.SetTexCoord then tex:SetTexCoord(index / SHEET_CELLS, (index + 1) / SHEET_CELLS, 0, 1) end
end

-- couleurs des huit familles (ordre de ns.CREATURE_TYPES)
local FAMILY = {
	beast = { 0.80, 0.55, 0.28 }, humanoid = { 0.92, 0.82, 0.60 }, undead = { 0.60, 0.85, 0.55 },
	elemental = { 0.45, 0.80, 1.00 }, dragonkin = { 0.95, 0.35, 0.25 }, demon = { 0.70, 0.40, 0.95 },
	giant = { 0.62, 0.66, 0.76 }, mechanical = { 0.85, 0.60, 0.35 },
}
ns.FEAT_FAMILY_COLORS = FAMILY
local TYPES = ns.CREATURE_TYPES or { "beast", "humanoid", "undead", "elemental", "dragonkin", "demon", "giant", "mechanical" }
-- Sobre : coins et milieux des côtés ; Azeroth : autour de l'anneau
local EIGHT_SOBRE = { { "TOPLEFT", 0, 0 }, { "TOP", 0, 0 }, { "TOPRIGHT", 0, 0 }, { "RIGHT", 0, 0 },
	{ "BOTTOMRIGHT", 0, 0 }, { "BOTTOM", 0, 0 }, { "BOTTOMLEFT", 0, 0 }, { "LEFT", 0, 0 } }

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

local function PaintPrism(self, frame, holder)
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
	-- huit losanges aux couleurs des familles
	if deco == "eight" then
		holder.eight = holder.eight or {}
		local ring = Ring()
		for index, key in ipairs(TYPES) do
			local d = holder.eight[index]
			if not d then
				d = Theme.CreateDiamond(holder, 9)
				holder.eight[index] = d
			end
			local c = FAMILY[key] or Theme.GOLD
			d:SetVertexColor(c[1], c[2], c[3], 1)
			d:ClearAllPoints()
			if az then
				local a = math.rad(22.5 + 45 * (index - 1))
				local r = ring.w / 2 - 3
				d:SetSize(10, 10)
				d:SetPoint("CENTER", frame, "TOP", r * math.cos(a), ring.y - r * math.sin(a))
			else
				local p = EIGHT_SOBRE[index]
				d:SetSize(9, 9)
				d:SetPoint("CENTER", frame, p[1], p[2], p[3])
			end
			d:Show()
		end
	elseif holder.eight then
		for _, d in ipairs(holder.eight) do d:Hide() end
	end
	-- filet arc-en-ciel (Sobre) ou halo qui tourne autour de l'anneau (Azeroth)
	if deco == "prism" then
		if az and not holder.halo then
			holder.halo = holder:CreateTexture(nil, "ARTWORK")
			Cell(holder.halo, HALO_CELL)
			Method(holder.halo, "SetBlendMode", "ADD")
		end
		if holder.halo then
			local ring = Ring()
			holder.halo:ClearAllPoints()
			holder.halo:SetSize(ring.w + 16, ring.w + 16)
			holder.halo:SetPoint("CENTER", frame, "TOP", 0, ring.y)
			if az then holder.halo:Show() else holder.halo:Hide() end
		end
		holder.prismAt = nil
		holder:SetScript("OnUpdate", function(h)
			local now = Now()
			if h.prismAt and now - h.prismAt < SPIN_STEP then return end
			h.prismAt = now
			PaintPrism(ns, frame, h)
		end)
		PaintPrism(self, frame, holder)
	else
		if holder.halo then holder.halo:Hide() end
		holder:SetScript("OnUpdate", nil)
	end
	holder.deco = deco
	holder:Show()
	return deco
end

-- Ornements des hauts faits : une texture de la feuille chacun
function ns:FeatApplyOrnaments()
	local frame = self.companionFrame
	if not frame then return 0 end
	local shown = 0
	for _, def in ipairs(ORNAMENTS) do
		local on = self:CompanionOrnamentShown(def)
		frame.featOrn = frame.featOrn or {}
		local o = frame.featOrn[def.id]
		if on and not o then
			local holder = DecoHolder(frame)
			o = CreateFrame("Frame", nil, holder)
			Method(o, "EnableMouse", false)
			o:SetSize(def.size, def.size)
			o:SetPoint(def.at[1], frame, def.at[2], def.at[3], def.at[4])
			o.tex = o:CreateTexture(nil, "OVERLAY")
			o.tex:SetAllPoints(o)
			Cell(o.tex, def.cell)
			if def.spin then
				o:SetScript("OnUpdate", function(f)
					local now = Now()
					if f.at and now - f.at < SPIN_STEP then return end
					f.at = now
					f.tex:SetVertexColor(Hue(now * SPIN_HZ))
				end)
				o.tex:SetVertexColor(Hue(Now() * SPIN_HZ))
			end
			frame.featOrn[def.id] = o
		end
		if o then
			if on then o:Show(); shown = shown + 1 else o:Hide() end
		end
	end
	if frame.featDeco then frame.featDeco:Show() end
	return shown
end

-- Accroches : cadre, ornements et passage d'un style à l'autre
do
	local applyFrame = ns.CompanionApplyFrame
	if applyFrame then
		function ns:CompanionApplyFrame(...)
			local a, b = applyFrame(self, ...)
			pcall(self.FeatApplyFrameDeco, self)
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
			return a, b
		end
	end
end

if ns.Mark then ns.Mark("FeatsCosmetics") end
