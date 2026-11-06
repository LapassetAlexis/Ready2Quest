-- Tooltips.lua -- le bestiaire dans l'infobulle des créatures (QuestCompanion)
--
-- Au survol d'une créature de la zone, une ligne dit où elle en est dans la
-- ménagerie (1.5.3) : « capturé » (vert, doré si brillant) ou « à capturer »
-- avec ta chance du moment, et son rang si c'est un nommé (rare, élite…).
-- Capture coupée dans les réglages : la ligne du bestiaire d'avant
-- (« à abattre » ou « abattu (n) »). Mêmes libellés et couleurs que le carnet
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
	MEN_TOOLTIP        = "Ménagerie : %s",
	MEN_TIP_CAUGHT     = "capturé",
	MEN_TIP_SHINY_CAUGHT = "capturée",
	MEN_TIP_TODO       = "à capturer · %d %%",
	MEN_TIP_SHINY      = "BRILLANTE · %s",
}
local EN = {
	BST_TOOLTIP        = "Bestiary: %s",
	MEN_TOOLTIP        = "Menagerie: %s",
	MEN_TIP_CAUGHT     = "captured",
	MEN_TIP_SHINY_CAUGHT = "captured",
	MEN_TIP_TODO       = "to capture · %d%%",
	MEN_TIP_SHINY      = "SHINY · %s",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TOOLTIP_STRINGS = { fr = FR, en = EN } end

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

local function Hex(c)
	return string.format("|cff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
		math.floor(c[3] * 255 + 0.5))
end

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
	local species = self:BestiarySpecies(zoneID)[npcID]
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

function ns:BestiaryOnTooltip(tooltip, data)
	local text, color = self:BestiaryTooltipLine(HoveredGUID(tooltip, data))
	if not text then return false end
	tooltip:AddLine(text, color[1], color[2], color[3])
	-- accroche OnTooltipSetUnit (pas de data) : le cadre reprend sa taille
	if data == nil and type(tooltip.Show) == "function" then pcall(tooltip.Show, tooltip) end
	return true
end

function ns:BestiaryHookTooltip()
	return self:HookTooltip("Unit", function(tooltip, data) ns:BestiaryOnTooltip(tooltip, data) end)
end
ns:BestiaryHookTooltip()

if ns.Mark then ns.Mark("Tooltips") end
