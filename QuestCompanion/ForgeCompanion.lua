-- ForgeCompanion.lua -- le médaillon forgé du compagnon (QuestCompanion 3.1.0)
--
-- Sous le thème forgé (l'ancien habillage coupé : ns.AZEROTH_LEGACY faux), le
-- cadre du compagnon garde la géométrie de la maquette validée (2026-11-14) :
-- un anneau d'or rond centré sur le portrait, la plaque du nom dessous
-- (nom à l'encre des titres, ligne « stade · niveau »), l'étiquette d'humeur
-- glissée sous la plaque, teintée selon l'humeur. Tout en NOS matières :
-- Theme.ART.ring (tools/gen_ui_assets.py), Theme.Slice "plate" ; seul le
-- masque rond du portrait vient du client (il arrondit le fond gagné, ce
-- n'est pas une illustration). Même centre et même emprise que l'anneau du
-- client (ns.FORGE_RING, AzerothStyle.lua) : le filet et ses pastilles ne
-- bougent pas.
--
-- Branché par ns:CompanionApplyUIStyle (AzerothStyle.lua) : appelé quand
-- ns:CompanionRingOn() est vrai hors ancien habillage. Le compagnon est
-- rhabillé sur place à chaque bascule (pas de cache) : l'habit est construit
-- une fois, à la première bascule vers le thème forgé, puis montré ou
-- caché ; le cadre carré du Sobre revient tel quel.
local ADDON, ns = ...
if ns.blocked then return end

local L = ns.L
local Theme = ns.Theme

local FR = {
	COMP_PLATE_SUB = "%s · niveau %d",
}
local EN = {
	COMP_PLATE_SUB = "%s · level %d",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.FORGE_COMPANION_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

-- La plaque du nom (px du cadre) : hauteur, débord de chaque côté du cadre,
-- recouvrement sous la bande d'or (la plaque commence où finit l'anneau, sa
-- pointe basse seule passe dessus, comme la maquette), centre du nom et de
-- la ligne « stade · niveau » depuis le bas de la plaque, marge du texte,
-- tailles de la police des titres (le nom rapetisse s'il est long)
-- (out ≤ 6 : à 8 px, le filet et la fiche au survol gardent leur écart)
ns.FORGE_COMPANION_PLATE = { height = 42, out = 6, overlap = 4, nameY = 26, subY = 12, pad = 7, nameMax = 13,
	nameMin = 9, subMax = 11, subMin = 9 }
-- Rayon extérieur de la bande d'or d'anneau.tga (part du demi-côté)
ns.FORGE_RING_BAND = 0.94

-- Haut de la plaque, depuis le haut du cadre (sous la bande d'or)
function ns.ForgeCompanionPlateTop()
	local F, P = ns.FORGE_RING, ns.FORGE_COMPANION_PLATE
	return F.y - math.floor(F.h / 2 * ns.FORGE_RING_BAND) + P.overlap
end
-- Ce que l'habit forgé dépasse sous le cadre (plaque et étiquette d'humeur) :
-- la souris y garde le cadre
function ns.ForgeCompanionBelow(frameH)
	local P, M = ns.FORGE_COMPANION_PLATE, ns.FORGE_MOOD_TAB
	local bottom = ns.ForgeCompanionPlateTop() - P.height - (M.h - M.tuck)
	return math.max(0, math.ceil(-bottom - (frameH or 118)))
end
-- Ce que l'habit déborde de chaque côté du cadre (0 : le cadre carré)
function ns.CompanionSideOverhang(frame)
	if frame and frame.ring == "forge" then return ns.FORGE_COMPANION_PLATE.out end
	return 0
end

-- Les ornements sur l'anneau (le cadre carré les pose à ses coins, qui
-- tombent dans le vide autour d'un médaillon rond) : point de l'ornement,
-- angle sur le bord de l'anneau (degrés, 0 à droite, sens trigonométrique),
-- décalage. Mêmes décalages que sur le carré pour ceux du bord.
ns.FORGE_ORNAMENTS = {
	ribbon  = { point = "TOPLEFT",  angle = 135, x = -4, y = 4 },
	lantern = { point = "TOPRIGHT", angle = 45,  x = 4,  y = 6 },
	crown   = { point = "BOTTOM",   angle = 90,  x = 0,  y = -4 },
	pennant = { point = "LEFT",     angle = 180, x = -6, y = 0 },
	crystal = { point = "RIGHT",    angle = 0,   x = 7,  y = 0 },
	-- accrochés sur la bande, au-dessus de la plaque du nom
	medal   = { point = "CENTER",   angle = 218, x = 0,  y = 0 },
	flower  = { point = "CENTER",   angle = 322, x = 0,  y = 0 },
}
-- Le niveau d'un PLAYER_LEVEL_UP, cru (s) avant que UnitLevel ne le rende
ns.FORGE_LEVEL_SEEN_S = 30
-- L'étiquette d'humeur : hauteur, part glissée sous la plaque, marge du mot
ns.FORGE_MOOD_TAB = { h = 16, tuck = 3, pad = 9 }
-- humeur -> plaque (Theme.FORGE_PLATE) et encre ; encre ≥ 7:1 sur les
-- niveaux de la plaque sous un libellé (tests/modules/companion_forge.lua)
ns.FORGE_MOOD_TINTS = {
	radiant = { plate = "green",    ink = function() return Theme.FORGE_INK.green end },
	happy   = { plate = "bronze",   ink = function() return Theme.PARCHMENT end },
	dreamy  = { plate = "arcane",   ink = function() return Theme.FORGE_INK.arcane end },
	sleepy  = { plate = "disabled", ink = function() return Theme.TEXT end },
}

local function Kit() return ns.AzerothCompanionKit or {} end

local function Measure(fs)
	local measure = Kit().Measure
	if measure then return measure(fs) end
	local ok, w = pcall(fs.GetStringWidth, fs)
	return (ok and tonumber(w)) or 0
end

-- L'habit : anneau, plaque, ligne « stade · niveau », étiquette d'humeur,
-- masque du fond (construit une fois)
local function BuildForgeSkin(frame)
	local F, P, M = ns.FORGE_RING, ns.FORGE_COMPANION_PLATE, ns.FORGE_MOOD_TAB
	local skin = CreateFrame("Frame", nil, frame)
	skin:SetAllPoints(frame)
	skin:SetFrameLevel((frame:GetFrameLevel() or 1) + 4)
	skin:EnableMouse(false)
	skin.forge = true
	-- l'anneau d'or (au-dessus de la plaque : il la chevauche un peu)
	skin.ring = skin:CreateTexture(nil, "ARTWORK")
	skin.ring:SetTexture(Theme.ART.ring.file)
	skin.ring:SetSize(F.w, F.h)
	skin.ring:SetPoint("CENTER", frame, "TOP", F.x, F.y)
	-- la plaque du nom (plaque en relief, teinte d'une carte sombre)
	local w = math.floor((frame:GetWidth() or 104) + 2 * P.out)
	skin.plateBox = CreateFrame("Frame", nil, skin)
	skin.plateBox:SetSize(w, P.height)
	skin.plateBox:SetPoint("TOP", frame, "TOP", 0, ns.ForgeCompanionPlateTop())
	skin.plateBox:EnableMouse(false)
	skin.plate = Theme.Slice(skin, "plate", { around = skin.plateBox, layer = "BACKGROUND", sub = 1,
		margin = Theme.FORGE.margin, color = Theme.FORGE_PLATE.card })
	-- la ligne « stade · niveau »
	skin.stage = skin:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	skin.stage:SetPoint("CENTER", skin.plateBox, "BOTTOM", 0, P.subY)
	skin.stage:SetWidth(w - 2 * P.pad)
	skin.stage:SetJustifyH("CENTER")
	if skin.stage.SetWordWrap then skin.stage:SetWordWrap(false) end
	Theme.TextShadow(skin.stage, 0.8)
	-- l'étiquette d'humeur, sous la plaque (cadre plus bas : la plaque la recouvre)
	local tab = CreateFrame("Frame", nil, skin)
	tab:SetSize(60, M.h)
	tab:SetPoint("TOP", skin.plateBox, "BOTTOM", 0, M.tuck)
	tab:SetFrameLevel(math.max(0, (skin:GetFrameLevel() or 1) - 1))
	tab:EnableMouse(false)
	tab.slice = Theme.Slice(tab, "plate", { layer = "BACKGROUND", sub = 0, margin = Theme.FORGE.marginSmall,
		color = Theme.FORGE_PLATE.bronze })
	skin.moodTab = tab
	-- le fond gagné, en disque sous la bande d'or (masque du client, s'il existe)
	local mask = Kit().MASK
	if frame.CreateMaskTexture and mask then
		local ok, m = pcall(frame.CreateMaskTexture, frame)
		if ok and m then
			pcall(m.SetTexture, m, mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			m:SetSize(F.disc, F.disc)
			m:SetPoint("CENTER", frame, "TOP", F.x, F.y)
			skin.mask = m
		end
	end
	skin:Hide()
	return skin
end

-- Le fond gagné sous l'anneau : disque (masque), sinon carré sous la bande ;
-- false : le fond du Sobre, plein cadre
local function PlaceBackground(frame, skin, on)
	local bg = frame.bg
	if not bg then return end
	bg:ClearAllPoints()
	if on then
		local F = ns.FORGE_RING
		local side = skin.mask and F.disc or F.square
		bg:SetSize(side, side)
		bg:SetPoint("CENTER", frame, "TOP", F.x, F.y)
		bg.forgePlaced = true
	else
		bg:SetAllPoints(frame)
		bg.forgePlaced = nil
	end
end

-- La ligne « stade · niveau » de la plaque
function ns:CompanionForgeStageLine()
	local stage = self.CompanionStageLabel and self:CompanionStageLabel() or ""
	local level = tonumber(Call(G("UnitLevel"), "player")) or 1
	-- (le niveau d'un PLAYER_LEVEL_UP qui vient d'arriver, si UnitLevel retarde :
	-- cru quelques secondes, le temps que le client se mette à jour)
	local seen = self.companionLevelSeen
	local now = (ns.Now and ns.Now()) or 0
	if type(seen) == "table" and tonumber(seen.level) and now - (tonumber(seen.at) or 0) <= ns.FORGE_LEVEL_SEEN_S
		and seen.level > level then
		level = seen.level
	end
	return self:F("COMP_PLATE_SUB", tostring(stage), level)
end

-- Étiquette d'humeur : teinte, encre, largeur au mot ; nom ajusté ; ligne
-- « stade · niveau » à jour. Rend l'humeur posée.
function ns:CompanionForgeMoodTab()
	local frame = self.companionFrame
	local skin = frame and frame.forgeSkin
	if not (skin and frame.ring == "forge") then return nil end
	local P, M = ns.FORGE_COMPANION_PLATE, ns.FORGE_MOOD_TAB
	if frame.name and ns.AzerothFit then
		ns.AzerothFit(frame.name, (skin.plateBox:GetWidth() or 112) - 2 * P.pad, P.nameMax, P.nameMin)
		local c = Theme.TITLE
		frame.name:SetTextColor(c[1], c[2], c[3], 1)
	end
	local muted = Theme.MUTED_LIGHT
	skin.stage:SetText(self:CompanionForgeStageLine())
	if ns.AzerothFit then
		ns.AzerothFit(skin.stage, (skin.plateBox:GetWidth() or 124) - 2 * P.pad, P.subMax, P.subMin)
	end
	skin.stage:SetTextColor(muted[1], muted[2], muted[3], 1)
	local tab = skin.moodTab
	if not frame.mood then return nil end
	local mood = self.CompanionMood and self:CompanionMood() or "happy"
	local spec = ns.FORGE_MOOD_TINTS[mood] or ns.FORGE_MOOD_TINTS.happy
	local tint = Theme.FORGE_PLATE[spec.plate] or Theme.FORGE_PLATE.neutral
	tab.slice:SetColor(tint[1], tint[2], tint[3], 1)
	local ink = spec.ink()
	frame.mood:SetTextColor(ink[1], ink[2], ink[3], 1)
	tab:SetWidth(math.floor(Measure(frame.mood) + 2 * M.pad + 0.5))
	tab.mood, tab.plate = mood, spec.plate
	return mood
end

local function Method(obj, name, ...)
	local fn = obj and obj[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, obj, ...)
end

-- Les ornements posés sur l'anneau (on) ou remis aux coins du carré ; le
-- double liseré carré (« cadre doré ») n'a rien à border autour du médaillon
function ns:CompanionForgeOrnaments(frame, on)
	local orn = frame and frame.ornaments
	if not orn then return nil end
	local F = ns.FORGE_RING
	local r = F.w / 2
	-- au-dessus de l'anneau (un ruban passe en travers de la bande d'or)
	local skin = frame.forgeSkin
	local over = ((skin and skin:GetFrameLevel()) or ((frame:GetFrameLevel() or 1) + 4)) + 1
	for id, spec in pairs(ns.FORGE_ORNAMENTS) do
		local o = orn[id]
		if o and o.home then
			o:ClearAllPoints()
			if o.homeLevel == nil then o.homeLevel = o:GetFrameLevel() or false end
			if on then
				o:SetFrameLevel(over)
			elseif o.homeLevel then
				o:SetFrameLevel(o.homeLevel)
			end
			if on then
				local a = math.rad(spec.angle)
				o:SetPoint(spec.point, frame, "TOP", math.floor(F.x + r * math.cos(a) + spec.x + 0.5),
					math.floor(F.y + r * math.sin(a) + spec.y + 0.5))
				o.forgePlaced = true
			else
				local h = o.home
				o:SetPoint(h[1], h[2], h[3], h[4], h[5])
				o.forgePlaced = nil
			end
		end
	end
	local gold = orn.gold
	if gold then
		local shown = false
		if not on then
			for _, def in ipairs(ns.COMPANION_ORNAMENTS or {}) do
				if def.id == "gold" then shown = self:CompanionOrnamentShown(def) and true or false end
			end
		end
		if shown then gold:Show() else gold:Hide() end
		for _, tex in ipairs(gold.corner or {}) do if shown then tex:Show() else tex:Hide() end end
	end
	return on
end

-- Pose le médaillon forgé (appelé par ns:CompanionApplyUIStyle)
function ns:CompanionApplyForgeSkin(frame)
	frame = frame or self.companionFrame
	if not frame then return nil end
	local kit = Kit()
	if not frame.forgeSkin then frame.forgeSkin = BuildForgeSkin(frame) end
	local skin = frame.forgeSkin
	skin:Show()
	if kit.EdgesShown then kit.EdgesShown(frame, false) end
	if frame.plate then frame.plate:Hide() end
	if kit.Masked then
		if frame.azSkin then kit.Masked(frame, false, frame.azSkin) end
		kit.Masked(frame, true, skin)
	end
	PlaceBackground(frame, skin, true)
	-- le portrait au centre de l'anneau, sous lui (niveau du cadre + 1 < habit + 4)
	frame.modelBase = ns.ForgeCompanionModelBase(frame.GetWidth and frame:GetWidth() or nil)
	if frame.model then
		if frame.model.SetFrameLevel then frame.model:SetFrameLevel((frame:GetFrameLevel() or 1) + 1) end
		if self.CompanionPlaceModel then
			self:CompanionPlaceModel(frame.fxOffset and frame.fxOffset[1], frame.fxOffset and frame.fxOffset[2])
		end
	end
	if frame.fallback then
		frame.fallback:ClearAllPoints()
		frame.fallback:SetPoint("CENTER", frame, "TOP", ns.FORGE_RING.x, ns.FORGE_RING.y)
	end
	-- le nom sur la plaque, l'humeur dans son étiquette
	if frame.name then
		if frame.name.SetParent then frame.name:SetParent(skin) end
		frame.name:ClearAllPoints()
		frame.name:SetPoint("CENTER", skin.plateBox, "BOTTOM", 0, ns.FORGE_COMPANION_PLATE.nameY)
		frame.name:SetJustifyH("CENTER")
		Theme.TextShadow(frame.name)
	end
	if frame.mood then
		if frame.mood.SetParent then frame.mood:SetParent(skin.moodTab) end
		frame.mood:ClearAllPoints()
		frame.mood:SetPoint("CENTER", skin.moodTab, "CENTER", 0, -ns.FORGE_MOOD_TAB.tuck / 2)
		Theme.NoShadow(frame.mood)
	end
	frame.ring = "forge"
	-- la plaque et l'étiquette d'humeur dépassent sous le cadre : la souris
	-- (survol, glisser, clic droit) les garde
	frame.forgeHitBelow = ns.ForgeCompanionBelow(frame:GetHeight())
	Method(frame, "SetHitRectInsets", 0, 0, 0, -frame.forgeHitBelow)
	self:CompanionForgeOrnaments(frame, true)
	self:CompanionForgeMoodTab()
	return skin
end

-- Quitte le médaillon forgé (bascule vers le Sobre ou l'ancien habillage) :
-- habit caché, fond libéré et remis plein cadre, polices du Sobre
function ns:CompanionLeaveForgeSkin(frame)
	frame = frame or self.companionFrame
	local skin = frame and frame.forgeSkin
	if not skin then return nil end
	skin:Hide()
	frame.forgeHitBelow = nil
	Method(frame, "SetHitRectInsets", 0, 0, 0, 0)
	self:CompanionForgeOrnaments(frame, false)
	local kit = Kit()
	if kit.Masked then kit.Masked(frame, false, skin) end
	PlaceBackground(frame, skin, false)
	if frame.fallback then
		frame.fallback:ClearAllPoints()
		frame.fallback:SetPoint("TOP", frame, "TOP", 0, -14)
	end
	-- les polices et la largeur de la création (Companion.lua)
	local w = math.floor((frame:GetWidth() or 104) - 8)
	if frame.name then
		if frame.name.SetFontObject then frame.name:SetFontObject(Theme.F_LABEL) end
		frame.name:SetWidth(w)
		frame.name.fitSize = nil
	end
	if frame.mood and frame.mood.SetFontObject then frame.mood:SetFontObject(Theme.F_SMALL) end
	return true
end
