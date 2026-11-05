-- Tooltips.lua -- le bestiaire dans l'infobulle des créatures (QuestCompanion)
--
-- Au survol d'une créature de la zone, une ligne dit où elle en est dans le
-- bestiaire : « à abattre » ou « abattu (n) », avec son rang si c'est un
-- nommé (rare, élite…). Mêmes libellés et couleurs que le carnet
-- (JournalWindow.lua). Une créature hors bestiaire (amicale, bestiole, en
-- instance) : rien.
-- Accroche commune du socle (ns:HookTooltip, Libs/Socle/Compat.lua) :
-- TooltipDataProcessor sur le moteur récent, OnTooltipSetUnit sinon.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = { BST_TOOLTIP = "Bestiaire : %s" }
local EN = { BST_TOOLTIP = "Bestiary: %s" }
ns.RegisterStrings(FR, EN)
ns.TOOLTIP_STRINGS = { fr = FR, en = EN }

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

-- GUID de l'unité survolée : data.guid (moteur récent), sinon tooltip:GetUnit()
local function HoveredGUID(tooltip, data)
	local guid = type(data) == "table" and ns.Plain(data.guid) or nil
	if type(guid) == "string" then return guid end
	if type(tooltip.GetUnit) ~= "function" then return nil end
	local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
	unit = ok and ns.Plain(unit) or nil
	if type(unit) ~= "string" then return nil end
	guid = ns.Plain(Call(rawget(_G, "UnitGUID"), unit))
	return type(guid) == "string" and guid or nil
end

-- Texte et couleur de la ligne, ou nil : l'espèce de ce GUID dans la zone
function ns:BestiaryTooltipLine(guid)
	if not (ns.CompanionOn and ns.CompanionOn()) then return nil end
	local npcID = ns.BestiaryNpcID and ns.BestiaryNpcID(guid)
	if not npcID then return nil end
	local zoneID = self.JournalZone and self:JournalZone()
	if not zoneID then return nil end
	local species = self:BestiarySpecies(zoneID)[npcID]
	if type(species) ~= "table" then return nil end
	local killed = tonumber(species.killed) or 0
	local status = killed > 0 and self:F("JRN_ITEM_KILLED", killed) or L.JRN_ITEM_TO_KILL
	local text = self:F("BST_TOOLTIP", status)
	local class = species.class
	if self:BestiaryIsNamed(species) then
		local color = (ns.BESTIARY_RANK_COLOR or {})[class] or Theme.GOLD
		text = text .. " · " .. Hex(color) .. tostring(L["BST_CLASS_" .. class]) .. "|r"
	end
	-- carnet : abattu en ambre, encore à faire en gris
	return text, killed > 0 and Theme.GOLD or Theme.MUTED
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
