-- Equip.lua -- lecture de l'équipement
--
-- Deux accès aux API d'inventaire : le lien de l'objet porté dans un
-- emplacement (QuestReward.lua) et ses données (LootRoom.lua). Le panneau
-- flottant (retiré en 1.16.0) puis le résumé de stuff (retiré en 1.37.0)
-- s'en servaient aussi.
local ADDON, ns = ...

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

if ns.Mark then ns.Mark("Equip") end
