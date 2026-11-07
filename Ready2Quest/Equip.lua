-- Equip.lua -- lecture de l'équipement
--
-- Ne contient plus qu'un accès aux API d'inventaire, utilisé par Stats.lua
-- pour le résumé de changement de stuff. Le panneau flottant de 17
-- emplacements a été supprimé (v1.16.0) : il affichait surtout son propre
-- vide, avec neuf lignes « Vide » pendant la majeure partie du leveling, et
-- les informations utiles (moyenne, pièces à changer) tenaient en une ligne
-- déjà fournie par le résumé.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

-- en dessous de (moyenne - WEAK_MARGIN) = pièce à changer
local WEAK_MARGIN  = 3

local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local EQUIP_LOC_SLOTS = {
	INVTYPE_HEAD           = { 1 },
	INVTYPE_NECK           = { 2 },
	INVTYPE_SHOULDER       = { 3 },
	INVTYPE_BODY           = { 4 },
	INVTYPE_CHEST          = { 5 },
	INVTYPE_ROBE           = { 5 },
	INVTYPE_WAIST          = { 6 },
	INVTYPE_LEGS           = { 7 },
	INVTYPE_FEET           = { 8 },
	INVTYPE_WRIST          = { 9 },
	INVTYPE_HAND           = { 10 },
	INVTYPE_FINGER         = { 11, 12 },
	INVTYPE_TRINKET        = { 13, 14 },
	INVTYPE_CLOAK          = { 15 },
	INVTYPE_WEAPON         = { 16, 17 },
	INVTYPE_WEAPONMAINHAND = { 16 },
	INVTYPE_WEAPONOFFHAND  = { 17 },
	INVTYPE_2HWEAPON       = { 16 },
	INVTYPE_SHIELD         = { 17 },
	INVTYPE_HOLDABLE       = { 17 },
	INVTYPE_RANGED         = { 18 },
	INVTYPE_RANGEDRIGHT    = { 18 },
	INVTYPE_THROWN         = { 18 },
	INVTYPE_RELIC          = { 18 },
	INVTYPE_TABARD         = { 19 },
}

-- ---------------------------------------------------------------------------
-- Lecture de l'équipement
-- ---------------------------------------------------------------------------
local function ItemLinkForSlot(slot)
	if type(GetInventoryItemLink) ~= "function" then return nil end
	local ok, link = pcall(GetInventoryItemLink, "player", slot)
	if ok and type(link) == "string" then return link end
	return nil
end
ns.ItemLinkForSlot = ItemLinkForSlot

local function ItemData(link)
	if not link then return nil end
	-- C_Item.GetItemInfo, sinon la globale (socle, ns.ItemInfo)
	local name, _, quality, itemLevel, _, _, _, _, itemEquipLoc, texture = ns.ItemInfo(link)
	if not name then return nil end
	return {
		name = name,
		quality = quality or 1,
		itemLevel = itemLevel or 0,
		equipLoc = itemEquipLoc,
		texture = texture,
	}
end
ns.ItemData = ItemData

function ns:AverageItemLevel()
	local total, count = 0, 0
	for _, slot in ipairs(SLOTS) do
		local data = ItemData(ItemLinkForSlot(slot))
		if data and data.itemLevel and data.itemLevel > 0 then
			total = total + data.itemLevel
			count = count + 1
		end
	end
	if count == 0 then return 0 end
	return math.floor((total / count) + 0.5)
end

-- Nombre de pièces nettement sous la moyenne
function ns:WeakSlotCount()
	local average = self:AverageItemLevel()
	if average <= 0 then return 0 end
	local threshold = average - WEAK_MARGIN
	local weak = 0
	for _, slot in ipairs(SLOTS) do
		local data = ItemData(ItemLinkForSlot(slot))
		if data and data.itemLevel > 0 and data.itemLevel < threshold then
			weak = weak + 1
		end
	end
	return weak
end

if ns.Mark then ns.Mark("Equip") end
