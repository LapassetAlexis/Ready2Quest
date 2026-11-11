-- SpecimenTraits.lua -- caractère et taille des spécimens (QuestCompanion 3.1.0)
--
-- 3.1.0 : chaque spécimen (CaptureSpecimens.lua) reçoit, à la capture :
--   * un CARACTÈRE : un des caractères du compagnon (Personality.lua,
--     ns.PERSONALITY_TRAITS : mêmes ids, noms, répliques, voix teintées) ;
--     tirés au poids (ns.SPECIMEN_TRAIT_WEIGHTS) : les six caractères
--     « formés » sont communs (×3), Zen et Espiègle, dont les répliques
--     conviennent à toute créature, sont rares (×1). Les autres caractères
--     d'apparence (chouette, ara, serpent…) parlent de leur animal : jamais
--     tirés (sauf migration : voir plus bas) ;
--   * une TAILLE (ns.SPECIMEN_SIZES) : minuscule 2 %, petit 18 %, normal
--     60 %, grand 18 %, géant 2 %. Un facteur d'échelle du modèle dans le
--     cadre du compagnon, rapproché selon le cadrage (portrait, buste) et
--     compensé par la caméra au-dessus de 1 : la créature reste dans son
--     cadre. Minuscule et géant : deux hauts faits (men_size_tiny,
--     men_size_giant, FeatsCatMenagerie.lua).
-- Le caractère et la taille font partie du spécimen (échanges de la 3.2).
--
-- Le spécimen porté (référence du Codex de l'apparence « cap:<npc>[:s] ») :
--   * donne son caractère au compagnon quand le réglage « Caractère » est
--     sur « Apparence » (le défaut) : bulles, voix teintée, étiquette de la
--     page Compagnon ; un caractère formé (ou choisi) reste celui des
--     mascottes et des compagnons de saison ; « Le sien » garde le sien ;
--   * donne un petit EFFET de caractère (CompanionEffects.lua,
--     ns.COMPANION_TRAIT_EFFECTS), quel que soit ce réglage ;
--   * donne sa taille au modèle du cadre (ns:CompanionSizeScale).
--
-- Migration 3.0 -> 3.1 (capture.traitV, idempotente) : les spécimens sans
-- caractère en reçoivent un, tiré ; ceux que porte un personnage du compte
-- reçoivent le caractère qu'avait ce compagnon (rien ne change pour le
-- joueur ; un compagnon pas encore formé, lui, en reçoit un tiré) ; taille
-- « normal » (pas de taille rare rétroactive). Les spécimens refaits plus
-- tard depuis la vue par espèce (capture.traitDirty) passent par le même
-- chemin. Les copies du cadeau de la 3.0 : caractère tiré, taille normale.
--
-- API
--   ns:SpecimenRollTrait() -> id ; ns:SpecimenRollSize() -> id
--   ns:SpecimenSizeDef(id) -> { id, weight, scale, rare } (normal par défaut)
--   ns:SpecimenSizeLabel(id), ns:SpecimenSizeColor(id), ns:SpecimenTraitColor(trait)
--   ns:SpecimenTagsShort(spec|id) -> « Grand · Curieux » (« » sans spécimen)
--   ns:SpecimenSizeLine(spec), ns:SpecimenTraitLine(spec, withEffect)
--   ns:CompanionWornSpecimen() -> spec|nil (gardé : rien n'est alloué)
--   ns:CompanionTraitBase() -> le caractère d'avant la 3.1 (formé, choisi, apparence)
--   ns:CompanionSizeScale(framing) -> échelle du modèle, facteur de caméra
--   ns.SpecimenTraitsFill(self, capture) -> spécimens complétés (migration)
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

ns.SPECIMEN_TRAIT_SCHEMA = 1
-- caractères tirés à la capture : { id, poids } (communs ×3, rares ×1)
ns.SPECIMEN_TRAIT_WEIGHTS = {
	{ "curious", 3 }, { "glutton", 3 }, { "daring", 3 }, { "lazy", 3 }, { "teasing", 3 }, { "cuddly", 3 },
	{ "zen", 1 }, { "mischievous", 1 },
}
ns.SPECIMEN_TRAIT_RARE = { zen = true, mischievous = true }
-- tailles, dans l'ordre d'affichage ; le tirage suit SPECIMEN_SIZE_ROLL
ns.SPECIMEN_SIZES = {
	{ id = "tiny",   weight = 2,  scale = 0.75, rare = true },
	{ id = "small",  weight = 18, scale = 0.88 },
	{ id = "normal", weight = 60, scale = 1 },
	{ id = "large",  weight = 18, scale = 1.12 },
	{ id = "giant",  weight = 2,  scale = 1.25, rare = true },
}
ns.SPECIMEN_SIZE_ROLL = { "normal", "small", "large", "tiny", "giant" }
-- part de l'écart d'échelle gardée selon le cadrage du compagnon (un
-- portrait serré n'a pas la place d'un géant entier)
ns.SPECIMEN_SIZE_FRAMING = { pied = 1, buste = 0.6, portrait = 0.4 }
-- au-dessus de 1 : la caméra recule de cette part de l'écart (il grandit
-- à l'œil, sans sortir du cadre)
ns.SPECIMEN_SIZE_CAM_ROOM = 0.5
ns.SPECIMEN_SIZE_SCALE_MIN, ns.SPECIMEN_SIZE_SCALE_MAX = 0.75, 1.25
-- couleur d'un caractère : celle de son envie préférée ; rare : ambre clair
ns.SPECIMEN_TRAIT_COLOR_NEED = { curiosity = "BLUE", hunger = "GREEN", mood = "GOLD", energy = "LABEL" }
ns.SPECIMEN_SIZE_COLOR = { tiny = "GOLD_LIGHT", small = "LABEL", normal = "MUTED_LIGHT", large = "LABEL", giant = "GOLD_LIGHT" }

local SIZE_BY_ID = {}
for _, def in ipairs(ns.SPECIMEN_SIZES) do SIZE_BY_ID[def.id] = def end
ns.SPECIMEN_SIZE_BY_ID = SIZE_BY_ID

local FR = {
	SPEC_SIZE_tiny       = "Minuscule",
	SPEC_SIZE_small      = "Petit",
	SPEC_SIZE_normal     = "Normal",
	SPEC_SIZE_large      = "Grand",
	SPEC_SIZE_giant      = "Géant",
	SPEC_SIZE_SHORT_tiny  = "XS",
	SPEC_SIZE_SHORT_small = "S",
	SPEC_SIZE_SHORT_large = "L",
	SPEC_SIZE_SHORT_giant = "XL",
	SPEC_SIZE_LINE       = "Taille : %s",
	SPEC_TRAIT_LINE      = "Caractère : %s",
	SPEC_TRAIT_LINE_EFF  = "Caractère : %s (%s)",
	SPEC_TAGS_SEP        = " · ",
	TRAIT_DESC_SPEC_zen         = "Il respire, ne se presse jamais, t'apaise après un combat. Aime le calme : énergie +50 %%.",
	TRAIT_DESC_SPEC_mischievous = "Il fait des farces et met des paillettes partout. Aime jouer : moral +50 %%.",
}
local EN = {
	SPEC_SIZE_tiny       = "Tiny",
	SPEC_SIZE_small      = "Small",
	SPEC_SIZE_normal     = "Normal",
	SPEC_SIZE_large      = "Large",
	SPEC_SIZE_giant      = "Giant",
	SPEC_SIZE_SHORT_tiny  = "XS",
	SPEC_SIZE_SHORT_small = "S",
	SPEC_SIZE_SHORT_large = "L",
	SPEC_SIZE_SHORT_giant = "XL",
	SPEC_SIZE_LINE       = "Size: %s",
	SPEC_TRAIT_LINE      = "Character: %s",
	SPEC_TRAIT_LINE_EFF  = "Character: %s (%s)",
	SPEC_TAGS_SEP        = " · ",
	TRAIT_DESC_SPEC_zen         = "Breathes, never hurries, calms you after a fight. Loves calm: energy +50 %%.",
	TRAIT_DESC_SPEC_mischievous = "Plays pranks and puts sparkles everywhere. Loves to play: mood +50 %%.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.SPECIMEN_TRAIT_STRINGS = { fr = FR, en = EN } end
-- descriptions sans l'animal d'origine (tortue, dragon féerique) pour un spécimen
local SPEC_DESC = { zen = true, mischievous = true }

local TRAITS = ns.PERSONALITY_TRAITS or {}

local function Roll(list, weightOf)
	local total = 0
	for _, item in ipairs(list) do total = total + weightOf(item) end
	local roll = math.random() * total
	for _, item in ipairs(list) do
		roll = roll - weightOf(item)
		if roll < 0 then return item end
	end
	return list[#list]
end
local function TraitWeight(item) return item[2] end
local function SizeWeight(id) return SIZE_BY_ID[id].weight end

function ns:SpecimenRollTrait()
	return Roll(ns.SPECIMEN_TRAIT_WEIGHTS, TraitWeight)[1]
end

function ns:SpecimenRollSize()
	return Roll(ns.SPECIMEN_SIZE_ROLL, SizeWeight)
end

function ns:SpecimenSizeDef(id) return SIZE_BY_ID[id or "normal"] or SIZE_BY_ID.normal end
function ns:SpecimenSizeLabel(id) return L["SPEC_SIZE_" .. (SIZE_BY_ID[id or ""] and id or "normal")] end
function ns:SpecimenSizeColor(id) return Theme[ns.SPECIMEN_SIZE_COLOR[id or ""] or "MUTED_LIGHT"] or Theme.LABEL end
function ns:SpecimenTraitColor(trait)
	if ns.SPECIMEN_TRAIT_RARE[trait or ""] then return Theme.GOLD_LIGHT end
	local def = TRAITS[trait or ""]
	return def and Theme[ns.SPECIMEN_TRAIT_COLOR_NEED[def.need] or "GOLD"] or Theme.GOLD
end

local function Spec(self, spec)
	if type(spec) ~= "table" and spec ~= nil and self.SpecimenGet then spec = self:SpecimenGet(spec) end
	return type(spec) == "table" and spec or nil
end

-- « Grand · Curieux »
function ns:SpecimenTagsShort(spec)
	spec = Spec(self, spec)
	if not spec then return "" end
	local size = self:SpecimenSizeLabel(spec.size)
	local trait = spec.trait and TRAITS[spec.trait] and self.PersonaLabel and self:PersonaLabel(spec.trait)
	if trait then return size .. L.SPEC_TAGS_SEP .. trait end
	return size
end

function ns:SpecimenSizeLine(spec)
	spec = Spec(self, spec)
	return spec and self:F("SPEC_SIZE_LINE", self:SpecimenSizeLabel(spec.size)) or ""
end

-- « Caractère : Curieux » ; withEffect : « Caractère : Curieux (la curiosité baisse 10 % moins vite) »
function ns:SpecimenTraitLine(spec, withEffect)
	spec = Spec(self, spec)
	if not (spec and spec.trait and TRAITS[spec.trait]) then return "" end
	local label = self:PersonaLabel(spec.trait)
	local effect = withEffect and self.CompanionTraitEffect and self:CompanionTraitEffect(spec.trait)
	if effect then return self:F("SPEC_TRAIT_LINE_EFF", label, effect.label) end
	return self:F("SPEC_TRAIT_LINE", label)
end

-- ---------------------------------------------------------------------------
-- Le spécimen porté, et le caractère d'avant la 3.1
-- ---------------------------------------------------------------------------
local worn = {}
function ns:CompanionWornSpecimen()
	if not (self.SpecimenStore and self.CompanionData) then return nil end
	if self.CompanionWinterSpec and self:CompanionWinterSpec() then return nil end
	local app = self:CompanionData().appearance
	local capture = self.SpecimenStore(self)
	if worn.app == app and worn.serial == capture.specSerial and worn.specimens == capture.specimens and worn.codex == capture.codex then
		return worn.spec or nil
	end
	local spec
	if type(app) == "string" then
		local npc, suffix = app:match("^cap:(%d+)(.*)$")
		npc = tonumber(npc)
		local codex = npc and capture.codex[npc]
		local id = codex and codex[suffix == ":s" and "bestShiny" or "best"]
		spec = id and capture.specimens[id] or nil
	end
	worn.app, worn.serial, worn.specimens, worn.codex, worn.spec = app, capture.specSerial, capture.specimens, capture.codex,
		spec or false
	return spec
end
function ns:CompanionWornForget() worn.app = nil end

local baseTrait = ns.CompanionTrait
ns.CompanionTraitBase = baseTrait

-- Réglage « Caractère : Apparence » (défaut) : le spécimen porté donne le sien
if baseTrait then
	function ns:CompanionTrait()
		if (tonumber(self:DB().companionTraitSource) or 1) == 1 then
			local spec = self:CompanionWornSpecimen()
			local trait = spec and spec.trait
			if trait and TRAITS[trait] then
				-- un caractère d'apparence porté reste au choix dans les réglages
				if TRAITS[trait].exclusive then
					local persona = self:PersonaData()
					if not persona.unlocked[trait] then persona.unlocked[trait] = true end
				end
				return trait
			end
		end
		return baseTrait(self)
	end
end

-- Réglages, page Caractère : un Zen ou un Espiègle capturé n'est pas une tortue
do
	local describe = ns.PersonaDescribe
	if describe then
		function ns:PersonaDescribe(...)
			local trait = self:CompanionTrait()
			local spec = trait and SPEC_DESC[trait] and self:CompanionWornSpecimen()
			if spec and spec.trait == trait then
				return self:F("OPT_TRAIT_NOW", self:PersonaLabel(trait), self:F("TRAIT_DESC_SPEC_" .. trait))
			end
			return describe(self, ...)
		end
	end
end

-- Le caractère qu'avait un compagnon (données d'un personnage) avant la
-- 3.1, pour une apparence capturée : choisi (s'il est disponible), sinon formé
local function OldTraitOf(self, companion)
	if type(companion) ~= "table" then return nil end
	local persona = type(companion.persona) == "table" and companion.persona or {}
	local unlocked = type(persona.unlocked) == "table" and persona.unlocked or {}
	local pick = (ns.PERSONALITY_ORDER or {})[tonumber(self:DB().companionTraitPick) or 0]
	if pick and TRAITS[pick] and (not TRAITS[pick].exclusive or unlocked[pick] == true) then return pick end
	return TRAITS[persona.formed or ""] and persona.formed or nil
end

-- Migration : un caractère pour chaque spécimen qui n'en a pas, la taille
-- normale pour ceux qui n'en ont pas. Rend le nombre de spécimens complétés.
function ns.SpecimenTraitsFill(self, capture)
	if type(capture) ~= "table" or type(capture.specimens) ~= "table" then return 0 end
	local codex = type(capture.codex) == "table" and capture.codex or {}
	local keep = {}
	local function Note(companion, trait)
		local app = type(companion) == "table" and companion.appearance
		if not (trait and type(app) == "string") then return end
		local npc, suffix = app:match("^cap:(%d+)(.*)$")
		npc = tonumber(npc)
		local refs = npc and codex[npc]
		local id = refs and refs[suffix == ":s" and "bestShiny" or "best"]
		if id and keep[id] == nil then keep[id] = trait end
	end
	-- le personnage connecté d'abord, puis les autres du compte
	if self.CompanionData and baseTrait then
		local ok, trait = pcall(baseTrait, self)
		Note(self:CompanionData(), ok and trait or nil)
	end
	local db = self:DB()
	for _, char in pairs(type(db.chars) == "table" and db.chars or {}) do
		local companion = type(char) == "table" and char.companion
		Note(companion, OldTraitOf(self, companion))
	end
	local done = 0
	for id, spec in pairs(capture.specimens) do
		if type(spec) == "table" then
			local changed = false
			if not TRAITS[spec.trait or ""] then
				spec.trait = keep[id] or self:SpecimenRollTrait()
				changed = true
			end
			if not SIZE_BY_ID[spec.size or ""] then
				spec.size = "normal"
				changed = true
			end
			if changed then done = done + 1 end
		end
	end
	capture.traitV = ns.SPECIMEN_TRAIT_SCHEMA
	capture.traitDirty = nil
	if done > 0 then
		capture.specSerial = (tonumber(capture.specSerial) or 0) + 1
		capture.serial = (tonumber(capture.serial) or 0) + 1
	end
	return done
end

-- Un spécimen capturé d'une taille rare : son haut fait
function ns:SpecimenSizeFeat(spec)
	if type(spec) ~= "table" or not (self.FeatFlag and not ns.featsDormant) then return false end
	if spec.size == "giant" then self:FeatFlag("sizeGiant", "account"); return true end
	if spec.size == "tiny" then self:FeatFlag("sizeTiny", "account"); return true end
	return false
end

-- ---------------------------------------------------------------------------
-- Taille dans le cadre du compagnon (Companion.lua, CompanionApplyModel)
-- ---------------------------------------------------------------------------
function ns:CompanionSizeScale(framing)
	local spec = self:CompanionWornSpecimen()
	local def = spec and SIZE_BY_ID[spec.size or ""]
	local scale = def and def.scale or 1
	local keep = ns.SPECIMEN_SIZE_FRAMING[framing or (self.CompanionFraming and self:CompanionFraming()) or "pied"] or 1
	local eff = 1 + (scale - 1) * keep
	eff = math.max(ns.SPECIMEN_SIZE_SCALE_MIN, math.min(ns.SPECIMEN_SIZE_SCALE_MAX, eff))
	local cam = eff > 1 and (1 + (eff - 1) * ns.SPECIMEN_SIZE_CAM_ROOM) or 1
	return eff, cam
end

-- Le spécimen porté change (Mettre au Codex, migration) : le cadre suit
if ns.RegisterCallback then
	ns:RegisterCallback("SPECIMENS", function(self, what)
		if what ~= "reference" and what ~= "release" then return end
		if self.companionFrame and self.CompanionApplyModel then pcall(self.CompanionApplyModel, self) end
	end)
end

-- ---------------------------------------------------------------------------
-- Scène de capture : « Grand · Curieux » sous le verdict, une fois résolue.
-- Le texte n'est écrit qu'au changement de spécimen (rien par image).
-- ---------------------------------------------------------------------------
do
	local base = ns.CaptureStageUpdate
	if base then
		function ns:CaptureStageUpdate(now, ...)
			local phase = base(self, now, ...)
			local frame = self.captureStage
			local tags = frame and frame.specTags
			if tags then
				local rolling = frame.rolling
				local want = (phase == "ok" and type(rolling) == "table" and rolling.specimen) or false
				if want ~= frame.specTagsFor then
					frame.specTagsFor = want
					if want then
						tags:SetText(self:SpecimenTagsShort(want))
						tags:Show()
					else
						tags:SetText("")
						tags:Hide()
					end
				end
			end
			return phase
		end
	end
end

if ns.Mark then ns.Mark("SpecimenTraits") end
