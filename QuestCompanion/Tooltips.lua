-- Tooltips.lua -- le bestiaire dans l'infobulle des créatures (QuestCompanion)
--
-- Au survol d'une créature de la zone, une ligne dit où elle en est dans la
-- ménagerie (1.5.3) : « capturé » (vert, doré si brillant) ou « à capturer »
-- avec ta chance du moment, et son rang si c'est un nommé (rare, élite…).
-- Capture coupée dans les réglages : la ligne du bestiaire d'avant
-- (« à abattre » ou « abattu (n) »). 2.15.0 : en mode chasse, une ligne
-- de méfiance sous celle-ci (ns:BestiaryTooltipWary). Mêmes libellés et couleurs que le carnet
-- (JournalWindow.lua). Une créature hors bestiaire (amicale, bestiole, en
-- instance) : rien.
-- Accroche commune du socle (ns:HookTooltip, Libs/Socle/Compat.lua) :
-- TooltipDataProcessor sur le moteur récent, OnTooltipSetUnit sinon.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	BST_TOOLTIP        = "Bestiaire : %s",
	MEN_TOOLTIP        = "Créatures : %s",
	MEN_TIP_CAUGHT     = "capturé",
	MEN_TIP_SHINY_CAUGHT = "capturée",
	MEN_TIP_TODO       = "à capturer · %d %%",
	MEN_TIP_SHINY      = "BRILLANTE · %s",
	-- 2.14.0 : où en est l'espèce ; 2.15.0 : le filet ne revient que pour mieux
	MEN_TIP_FULL       = "%s %s · complète",
	MEN_TIP_MORE       = "%s %s · amélioration possible si tu trouves mieux",
	MEN_TIP_PINNED     = "%s %s · épinglée",
}
local EN = {
	BST_TOOLTIP        = "Bestiary: %s",
	MEN_TOOLTIP        = "Creatures: %s",
	MEN_TIP_CAUGHT     = "captured",
	MEN_TIP_SHINY_CAUGHT = "captured",
	MEN_TIP_TODO       = "to capture · %d%%",
	MEN_TIP_SHINY      = "SHINY · %s",
	MEN_TIP_FULL       = "%s %s · complete",
	MEN_TIP_MORE       = "%s %s · can improve if you find a better one",
	MEN_TIP_PINNED     = "%s %s · pinned",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TOOLTIP_STRINGS = { fr = FR, en = EN } end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

-- 2.11.0 (fiche 28) : le code couleur vient du socle (Theme.Hex)
local function Hex(c) return Theme.Hex(c) end

-- GUID de l'unité survolée : data.guid (moteur récent), sinon
-- tooltip:GetUnit() ; second retour : son niveau, si on le lit
local function HoveredGUID(tooltip, data)
	local unit
	if type(tooltip.GetUnit) == "function" then
		local ok, _, u = pcall(tooltip.GetUnit, tooltip)
		unit = ok and ns.Plain(u) or nil
		if type(unit) ~= "string" then unit = nil end
	end
	local level = unit and tonumber(ns.Plain(Call(rawget(_G, "UnitLevel"), unit))) or nil
	local guid = type(data) == "table" and ns.Plain(data.guid) or nil
	if type(guid) == "string" then return guid, level end
	if not unit then return nil end
	guid = ns.Plain(Call(rawget(_G, "UnitGUID"), unit))
	return type(guid) == "string" and guid or nil, level
end

-- Texte et couleur de la ligne, ou nil : l'espèce de ce GUID dans la zone.
-- level : niveau de la créature survolée (chance de capture)
function ns:BestiaryTooltipLine(guid, level)
	if not (ns.CompanionOn and ns.CompanionOn()) then return nil end
	local npcID = ns.BestiaryNpcID and ns.BestiaryNpcID(guid)
	if not npcID then return nil end
	local zoneID = self.JournalZone and self:JournalZone()
	if not zoneID then return nil end
	-- 2.11.1 : une seule espèce lue, plus toute la zone (même fusion, même filtre de faction)
	local species = self:BestiarySpeciesOne(zoneID, npcID)
	if type(species) ~= "table" then return nil end
	local killed = tonumber(species.killed) or 0
	local class = species.class
	local text, color
	local capture = self.CaptureChance and self.CaptureData and self:DB().companionCapture ~= false
	-- cette créature-ci est-elle une brillante repérée ? (Shiny.lua)
	local live = self.shinyState and self.shinyState.live and self.shinyState.live[guid]
	if capture then
		-- la version qu'on a sous les yeux : la brillante, ou la normale
		local has = self.CaptureHas and self:CaptureHas(npcID, live and true or false)
		local status
		if has then
			status = live and L.MEN_TIP_SHINY_CAUGHT or L.MEN_TIP_CAUGHT
			color = live and (Theme.GOLD_LIGHT or Theme.GOLD) or Theme.GREEN
			-- 2.14.0 : ses étoiles ; 2.15.0 : épinglée (toujours proposée),
			-- complète (3 étoiles), ou le filet reviendra pour un meilleur spécimen
			local stars = self.CaptureStars and self:CaptureStars(npcID, live and true or false)
			if stars and self.CaptureStarsText then
				local starText = self:CaptureStarsText(stars, 12)
				local key = "MEN_TIP_MORE"
				if self.HuntPinned and self:HuntPinned(npcID) then
					key = "MEN_TIP_PINNED"
				elseif stars >= (ns.CAPTURE_STAR_MAX or 3) then
					key = "MEN_TIP_FULL"
				end
				status = self:F(key, status, starText)
			end
		else
			-- type et espèce : les effets du compagnon (CompanionEffects.lua) en tiennent compte
			local info = { class = class or "normal", level = level or species.level, type = species.type, npcID = npcID,
				shiny = live and true or nil }
			local chance = self:CaptureChance(info)
			local pct = math.floor(chance * 100 + 0.5 + 1e-9)
			local base = self.CaptureChanceBase and math.floor(self:CaptureChanceBase(info) * 100 + 0.5 + 1e-9) or pct
			if pct > base and L.MEN_TIP_TODO_BONUS then
				status = self:F("MEN_TIP_TODO_BONUS", pct, pct - base)
			else
				status = self:F("MEN_TIP_TODO", pct)
			end
			color = live and (Theme.GOLD_LIGHT or Theme.GOLD) or (Theme.MUTED_LIGHT or Theme.MUTED)
		end
		if live then status = self:F("MEN_TIP_SHINY", status) end
		text = self:F("MEN_TOOLTIP", status)
	else
		-- carnet : abattu en ambre, encore à faire en gris
		text = self:F("BST_TOOLTIP", killed > 0 and self:F("JRN_ITEM_KILLED", killed) or L.JRN_ITEM_TO_KILL)
		color = killed > 0 and Theme.GOLD or Theme.MUTED
	end
	if self:BestiaryIsNamed(species) then
		local color = (ns.BESTIARY_RANK_COLOR or {})[class] or Theme.GOLD
		text = text .. " · " .. Hex(color) .. tostring(L["BST_CLASS_" .. class]) .. "|r"
	end
	return text, color
end

-- 2.15.0 : en mode chasse, la méfiance de l'espèce survolée : « Méfiant ·
-- 2 capture(s) aujourd'hui (−30 %) » (CaptureSpecimens.lua, ns:CaptureWariness) ;
-- nil hors chasse, ou sans capture de l'espèce aujourd'hui
function ns:BestiaryTooltipWary(guid)
	if not (self.CaptureWariness and self.HuntActive and self:HuntActive()) then return nil end
	if self:DB().companionCapture == false or not (ns.CompanionOn and ns.CompanionOn()) then return nil end
	local npcID = ns.BestiaryNpcID and ns.BestiaryNpcID(guid)
	if not npcID then return nil end
	local factor, count = self:CaptureWariness(npcID)
	if not count or count <= 0 then return nil end
	return self:F("CAPTURE_WARY", count, math.floor((1 - factor) * 100 + 0.5 + 1e-9))
end

function ns:BestiaryOnTooltip(tooltip, data)
	local guid, level = HoveredGUID(tooltip, data)
	local text, color = self:BestiaryTooltipLine(guid, level)
	if not text then return false end
	tooltip:AddLine(text, color[1], color[2], color[3])
	local wary = self:BestiaryTooltipWary(guid)
	if wary then
		local c = Theme.ORANGE or Theme.GOLD
		tooltip:AddLine(wary, c[1], c[2], c[3])
	end
	-- accroche OnTooltipSetUnit (pas de data) : le cadre reprend sa taille
	if data == nil and type(tooltip.Show) == "function" then pcall(tooltip.Show, tooltip) end
	return true
end

-- Autres lignes d'infobulle d'unité (fiche de dresseur, TrainerCard.lua) :
-- le socle ne pose qu'une accroche par sorte, elles passent par celle-ci.
-- fn(ns, tooltip, data), chacune protégée.
ns.UNIT_TOOLTIP_LINES = ns.UNIT_TOOLTIP_LINES or {}
function ns:BestiaryHookTooltip()
	return self:HookTooltip("Unit", function(tooltip, data)
		ns:BestiaryOnTooltip(tooltip, data)
		for _, fn in ipairs(ns.UNIT_TOOLTIP_LINES) do
			local ok, err = pcall(fn, ns, tooltip, data)
			if not ok and ns.RecordError then ns:RecordError("tooltip:unit", err) end
		end
	end)
end
ns:BestiaryHookTooltip()

if ns.Mark then ns.Mark("Tooltips") end
