-- TrainerCardStyle.lua -- 3.6.0 : fonds et cadres de la fiche de dresseur,
-- médailles de type et espèces maîtrisées (docs/audit-pokemon-like-3.5,
-- PLAN, lot 1B « Des buts longs »).
--
-- Deux sortes de cosmétiques neuves, gagnées par les hauts faits (les sept
-- récompenses « à venir » des hauts faits de la 2.7 deviennent réelles) :
--   * cardbg    : fond de la fiche (ns.TRAINER_CARD_BACKGROUNDS) ;
--   * cardframe : cadre de la fiche (ns.TRAINER_CARD_FRAMES).
-- Images : nos textures, générées par tools/gen_ui_assets.py (motifs et
-- dégradés, aucune image du jeu) dans Libs/Socle/Media. Fonds sombres et
-- opaques : le texte de la fiche y garde un contraste ≥ 4,5 (point le plus
-- clair de chaque fond mesuré, tests/modules/lot36_b.lua).
--
-- Déblocage : comme les cosmétiques du compagnon, ns:FeatGrant pose
-- CompanionData().unlocked["cardbg:<id>"] (ou "cardframe:<id>") ; un haut
-- fait de compte suit sur chaque personnage (ns:FeatSyncAccountRewards).
-- Choix (par personnage) : CompanionData().cardStyle = { bg = id, frame = id }
-- (absent : la fiche d'avant, sans fond ni cadre). Deux listes sur ma fiche,
-- « Fond : … » et « Cadre : … », sur la rangée du titre affiché.
--
-- Partage : deux champs facultatifs de la fiche, cb (fond) et cf (cadre),
-- un identifiant de ce catalogue ; ignorés des versions d'avant (le
-- protocole ignore les clés inconnues), lus ici sur liste blanche (un id
-- inconnu est écarté). Les autres joueurs à jour voient donc ton fond et ton
-- cadre ; ceux d'avant la 3.6 voient la fiche d'avant.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local MEDIA = (Theme and Theme.SOCLE_MEDIA) or ("Interface\\AddOns\\" .. tostring(ADDON) .. "\\Libs\\Socle\\Media\\")

-- ---------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------
-- label : texte de récompense (« Fond de fiche : … ») ; name : nom court des listes
ns.TRAINER_CARD_BACKGROUNDS = {
	{ id = "card_census",   label = "CARD_BG_census",   name = "CARD_BGN_census",   file = MEDIA .. "fiche_registre",
		tex = "fiche_registre", unlock = { feat = "men_species_500" } },
	{ id = "card_atlas",    label = "CARD_BG_atlas",    name = "CARD_BGN_atlas",    file = MEDIA .. "fiche_atlas",
		tex = "fiche_atlas", unlock = { feat = "meta_zones" } },
	{ id = "card_renown",   label = "CARD_BG_renown",   name = "CARD_BGN_renown",   file = MEDIA .. "fiche_renom",
		tex = "fiche_renom", unlock = { feat = "meta_points_1500" } },
	{ id = "card_pantheon", label = "CARD_BG_pantheon", name = "CARD_BGN_pantheon", file = MEDIA .. "fiche_pantheon",
		tex = "fiche_pantheon", unlock = { feat = "meta_trainer" } },
}
ns.TRAINER_CARD_FRAMES = {
	{ id = "card_crest_ek", label = "CARD_FRAME_crest_ek", name = "CARD_FRAMEN_crest_ek", file = MEDIA .. "fiche_blason_est",
		tex = "fiche_blason_est", unlock = { feat = "zone_seal_ek" } },
	{ id = "card_crest_ka", label = "CARD_FRAME_crest_ka", name = "CARD_FRAMEN_crest_ka", file = MEDIA .. "fiche_blason_kalimdor",
		tex = "fiche_blason_kalimdor", unlock = { feat = "zone_seal_ka" } },
	{ id = "card_laurels",  label = "CARD_FRAME_laurels",  name = "CARD_FRAMEN_laurels",  file = MEDIA .. "fiche_lauriers",
		tex = "fiche_lauriers", unlock = { feat = "meta_hero" } },
}
-- découpe en 9 tranches des cadres (texture 64 px, coins de 24 px rendus tels quels)
ns.TRAINER_CARD_FRAME_ART = { size = 64, margin = 24 }
-- où se posent fond et cadre : sous l'en-tête de la fiche, jusqu'au pied
ns.TRAINER_CARD_STYLE_TOP = -58
-- médailles de type : teinte (jeton du thème) et losange plein ou au trait, par palier
ns.TRAINER_MEDAL_LOOK = {
	[0] = { "MUTED", true }, [1] = { "GOLD_SOFT", true }, [2] = { "GOLD_SOFT", true },
	[3] = { "GOLD_SOFT", false }, [4] = { "PARCHMENT", false }, [5] = { "GOLD_LIGHT", false },
}
ns.TRAINER_MEDAL_MAX = 5

local KINDS = { cardbg = ns.TRAINER_CARD_BACKGROUNDS, cardframe = ns.TRAINER_CARD_FRAMES }

-- ---------------------------------------------------------------------------
-- Chaînes
-- ---------------------------------------------------------------------------
local FR = {
	CARD_BG_census        = "Fond de fiche : Registre des espèces",
	CARD_BG_atlas         = "Fond de fiche : Atlas des sceaux",
	CARD_BG_renown        = "Fond de fiche : Bannière de renom",
	CARD_BG_pantheon      = "Fond de fiche : Panthéon",
	CARD_FRAME_crest_ek   = "Cadre de fiche : Blason de l'Est",
	CARD_FRAME_crest_ka   = "Cadre de fiche : Blason de Kalimdor",
	CARD_FRAME_laurels    = "Cadre de fiche : Lauriers",
	CARD_BGN_census       = "Registre des espèces",
	CARD_BGN_atlas        = "Atlas des sceaux",
	CARD_BGN_renown       = "Bannière de renom",
	CARD_BGN_pantheon     = "Panthéon",
	CARD_FRAMEN_crest_ek  = "Blason de l'Est",
	CARD_FRAMEN_crest_ka  = "Blason de Kalimdor",
	CARD_FRAMEN_laurels   = "Lauriers",
	TRAINER_STYLE_BG      = "Fond : %s",
	TRAINER_STYLE_FRAME   = "Cadre : %s",
	TRAINER_STYLE_NONE    = "aucun",
	TRAINER_SPECIES_MASTERED = "Espèces : %d / %d · maîtrisées : %d",
	TRAINER_MEDALS        = "Médailles de type",
	TRAINER_MEDAL_NONE    = "%s : pas encore de médaille (%d espèces)",
	TRAINER_MEDAL_NEXT    = "Prochaine à %d espèces.",
}
local EN = {
	CARD_BG_census        = "Card background: Species Ledger",
	CARD_BG_atlas         = "Card background: Atlas of Seals",
	CARD_BG_renown        = "Card background: Banner of Renown",
	CARD_BG_pantheon      = "Card background: Pantheon",
	CARD_FRAME_crest_ek   = "Card frame: Eastern Crest",
	CARD_FRAME_crest_ka   = "Card frame: Kalimdor Crest",
	CARD_FRAME_laurels    = "Card frame: Laurels",
	CARD_BGN_census       = "Species Ledger",
	CARD_BGN_atlas        = "Atlas of Seals",
	CARD_BGN_renown       = "Banner of Renown",
	CARD_BGN_pantheon     = "Pantheon",
	CARD_FRAMEN_crest_ek  = "Eastern Crest",
	CARD_FRAMEN_crest_ka  = "Kalimdor Crest",
	CARD_FRAMEN_laurels   = "Laurels",
	TRAINER_STYLE_BG      = "Background: %s",
	TRAINER_STYLE_FRAME   = "Frame: %s",
	TRAINER_STYLE_NONE    = "none",
	TRAINER_SPECIES_MASTERED = "Species: %d / %d · mastered: %d",
	TRAINER_MEDALS        = "Type medals",
	TRAINER_MEDAL_NONE    = "%s: no medal yet (%d species)",
	TRAINER_MEDAL_NEXT    = "Next at %d species.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TRAINER_STYLE_STRINGS = { fr = FR, en = EN } end

-- ---------------------------------------------------------------------------
-- Catalogue, possession, choix
-- ---------------------------------------------------------------------------
function ns.TrainerCardStyleDef(kind, id)
	for _, def in ipairs(KINDS[kind] or {}) do
		if def.id == id then return def end
	end
	return nil
end

-- Gagné ? (déblocage posé par le haut fait ; le haut fait lui-même suffit)
function ns:TrainerCardStyleOwned(kind, id)
	local def = ns.TrainerCardStyleDef(kind, id)
	if not def then return false end
	local unlocked = self.CompanionData and self:CompanionData().unlocked
	if type(unlocked) == "table" and unlocked[kind .. ":" .. id] then return true end
	local feat = def.unlock and def.unlock.feat
	return feat ~= nil and self.FeatGot ~= nil and self:FeatGot(feat) and true or false
end

local function Store(self)
	local data = self:CompanionData()
	if type(data.cardStyle) ~= "table" then data.cardStyle = {} end
	return data.cardStyle
end

-- Fond et cadre portés (gagnés seulement ; nil = la fiche d'avant)
function ns:TrainerCardStyle()
	local data = self.CompanionData and self:CompanionData()
	local style = data and type(data.cardStyle) == "table" and data.cardStyle or {}
	local bg = style.bg and self:TrainerCardStyleOwned("cardbg", style.bg) and style.bg or nil
	local frame = style.frame and self:TrainerCardStyleOwned("cardframe", style.frame) and style.frame or nil
	return bg, frame
end

-- kind : "cardbg" | "cardframe" ; id : un id gagné, ou "none"
function ns:TrainerCardStyleSet(kind, id)
	if not KINDS[kind] then return false end
	local field = kind == "cardbg" and "bg" or "frame"
	if id == nil or id == "none" then
		Store(self)[field] = nil
	elseif self:TrainerCardStyleOwned(kind, id) then
		Store(self)[field] = id
	else
		return false
	end
	if self.TrainerRefreshWindow then self:TrainerRefreshWindow() end
	return true
end

-- Choix de la liste : « Fond : aucun », puis chaque fond (grisé, avec sa
-- condition, tant qu'il n'est pas gagné)
function ns:TrainerCardStyleOptions(kind)
	local fmt = kind == "cardbg" and "TRAINER_STYLE_BG" or "TRAINER_STYLE_FRAME"
	local options = { { value = "none", label = self:F(fmt, L.TRAINER_STYLE_NONE) } }
	for _, def in ipairs(KINDS[kind] or {}) do
		local owned = self:TrainerCardStyleOwned(kind, def.id)
		local hint
		if not owned and self.CompanionRequirement then
			local ok, text = pcall(self.CompanionRequirement, self, def.unlock)
			hint = ok and type(text) == "string" and text ~= "" and text or nil
		end
		options[#options + 1] = { value = def.id, label = self:F(fmt, L[def.name]), disabled = not owned, hint = hint }
	end
	return options
end

-- Lecture d'une fiche reçue : un id du catalogue, sinon rien
function ns.TrainerCardStyleValid(kind, id)
	return type(id) == "string" and ns.TrainerCardStyleDef(kind, id) ~= nil and id or nil
end

-- ---------------------------------------------------------------------------
-- Médailles et espèces maîtrisées (ma fiche)
-- ---------------------------------------------------------------------------
-- { [clé de type] = médaille 1..5 } (les types sans médaille absents)
function ns:TrainerOwnMedals()
	local medals = {}
	if not self.MenagerieMedals then return medals end
	local ok, all = pcall(self.MenagerieMedals, self)
	if not ok or type(all) ~= "table" then return medals end
	for key, tier in pairs(all) do
		if tonumber(tier) and tier > 0 then medals[key] = math.min(ns.TRAINER_MEDAL_MAX, math.floor(tier)) end
	end
	return medals
end

function ns:TrainerOwnMastered()
	if not self.SpecimenStudyMastered then return nil end
	local ok, n = pcall(self.SpecimenStudyMastered, self)
	return ok and tonumber(n) or nil
end

-- ---------------------------------------------------------------------------
-- Rendu : fond (sous tout le contenu de la fiche), cadre (9 tranches, au-dessus)
-- ---------------------------------------------------------------------------
local function EnsureLayers(frame)
	if frame.cardStyle then return frame.cardStyle end
	local content = frame.content or frame
	local top = ns.TRAINER_CARD_STYLE_TOP
	local layers = {}
	layers.bg = content:CreateTexture(nil, "BACKGROUND", nil, 2)
	layers.bg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
	layers.bg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
	layers.bg:Hide()
	-- le cadre, sur un cadre à lui, au-dessus des cartes et des listes, sans souris
	local holder = CreateFrame("Frame", nil, content)
	holder:SetPoint("TOPLEFT", content, "TOPLEFT", 0, top)
	holder:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
	if holder.SetFrameLevel and content.GetFrameLevel then holder:SetFrameLevel((tonumber(content:GetFrameLevel()) or 1) + 20) end
	if holder.EnableMouse then holder:EnableMouse(false) end
	layers.holder = holder
	layers.slices = {}
	frame.cardStyle = layers
	return layers
end

-- bgId / frameId : ids du catalogue, ou nil (rien de posé)
function ns:TrainerCardStyleApply(frame, bgId, frameId)
	if not frame then return false end
	local bgDef = bgId and ns.TrainerCardStyleDef("cardbg", bgId)
	local frameDef = frameId and ns.TrainerCardStyleDef("cardframe", frameId)
	if not (bgDef or frameDef or frame.cardStyle) then return false end
	local layers = EnsureLayers(frame)
	if bgDef then
		layers.bg:SetTexture(bgDef.file)
		layers.bg:Show()
	else
		layers.bg:Hide()
	end
	for id, slice in pairs(layers.slices) do slice:SetShown(frameDef ~= nil and id == frameDef.id) end
	if frameDef and not layers.slices[frameDef.id] then
		local art = ns.TRAINER_CARD_FRAME_ART
		layers.slices[frameDef.id] = Theme.Slice(layers.holder, { file = frameDef.file, size = art.size, margin = art.margin },
			{ layer = "OVERLAY", fill = false })
	end
	frame.cardStyleBg, frame.cardStyleFrame = bgDef and bgDef.id or nil, frameDef and frameDef.id or nil
	return true
end

if ns.Mark then ns.Mark("TrainerCardStyle") end
