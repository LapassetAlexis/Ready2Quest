-- Ready2Quest 1.27.0 : « Place au butin » (LootRoom.lua, sur le modèle de Delete
-- Cheapest Item) et « Rangs de sorts » (SpellRanks.lua).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local LR = { savedG = {} }
local saved = {
	CItemGetItemInfo = C_Item.GetItemInfo,
	PickupContainerItem = C_Container.PickupContainerItem,
}
for _, name in ipairs({ "DeleteCursorItem", "CursorHasItem", "StaticPopup_Show", "StaticPopupDialogs", "InCombatLockdown",
	"GetNumLootItems", "GetLootSlotLink", "LootSlotHasItem", "GetLootSlotInfo", "LootSlot", "Auctionator",
	"GetActionInfo", "GetSpellInfo", "GetSpellSubtext", "GetSpellTexture", "PickupSpell", "PlaceAction", "ClearCursor",
	"GetNumSpellTabs", "GetSpellTabInfo", "GetSpellBookItemInfo", "C_Spell", "C_SpellBook" }) do
	LR.savedG[name] = { value = rawget(_G, name) }
end
function LR.Restore()
	C_Item.GetItemInfo = saved.CItemGetItemInfo
	C_Container.PickupContainerItem = saved.PickupContainerItem
	for name, entry in pairs(LR.savedG) do _G[name] = entry.value end
end

local GREY, WHITE, GREEN, CLOTH, LOOT, QLOOT = 881001, 881002, 881003, 881004, 881090, 881091
function LR.Link(id)
	local d = Mock.world.itemInfo[id] or {}
	return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. tostring(d.name or id) .. "]|h|r"
end
C_Item.GetItemInfo = function(item)
	local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
	local d = Mock.world.itemInfo[id]
	if not d then return nil end
	return d.name, LR.Link(id), d.quality, 1, 1, "", "", d.maxStack or 20, nil, nil, d.sellPrice
end
C_Container.PickupContainerItem = function(bag, slot)
	local item = Mock.world.bags[bag] and Mock.world.bags[bag].items[slot]
	if item then Mock.world.cursor = { bag = bag, slot = slot, itemID = item.itemID } end
end
_G.CursorHasItem = function() return Mock.world.cursor ~= nil end
_G.DeleteCursorItem = function()
	local c = Mock.world.cursor
	if not c then return end
	Mock.world.bags[c.bag].items[c.slot] = nil
	Mock.world.deleted = (Mock.world.deleted or 0) + 1
	Mock.world.cursor = nil
end
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function(which, text)
	local dialog = { which = which, text = text }
	Mock.world.popup = dialog
	return dialog
end
_G.InCombatLockdown = function() return Mock.world.combat == true end
_G.GetNumLootItems = function() return #(Mock.world.loot or {}) end
_G.GetLootSlotLink = function(i) local l = (Mock.world.loot or {})[i]; return l and LR.Link(l.id) end
_G.LootSlotHasItem = function(i) return (Mock.world.loot or {})[i] ~= nil end
_G.GetLootSlotInfo = function(i)
	local l = (Mock.world.loot or {})[i]
	if not l then return nil end
	return "tex" .. l.id, Mock.world.itemInfo[l.id].name, l.count or 1, nil, 1, false, l.quest == true, nil, true
end
_G.LootSlot = function(i) Mock.world.looted = i end

function LR.Reset()
	ResetWorld()
	if NS.lootRoomFrame then NS.lootRoomFrame:Hide() end
	NS.lootRoom, NS.lootRoomPending = nil, nil
	Mock.world.itemInfo = {
		[GREY]  = { name = "Os brisé", quality = 0, sellPrice = 5 },
		[WHITE] = { name = "Caillou", quality = 1, sellPrice = 8 },
		[GREEN] = { name = "Anneau vert", quality = 2, sellPrice = 20 },
		[CLOTH] = { name = "Étoffe", quality = 1, sellPrice = 30, maxStack = 3 },
		[LOOT]  = { name = "Butin précieux", quality = 2, sellPrice = 50 },
		[QLOOT] = { name = "Crâne de quête", quality = 1, sellPrice = 0 },
	}
	local function Item(id, count)
		local d = Mock.world.itemInfo[id]
		return { itemID = id, stackCount = count or 1, quality = d.quality, hyperlink = LR.Link(id) }
	end
	Mock.world.bags[0] = { size = 4, items = { [1] = Item(CLOTH, 3), [2] = Item(GREEN, 1), [3] = Item(WHITE, 1), [4] = Item(GREY, 1) } }
	Mock.world.loot = { { id = LOOT, count = 1 } }
	Mock.world.deleted, Mock.world.looted, Mock.world.popup, Mock.world.combat = 0, nil, nil, false
	_G.StaticPopupDialogs = {}
	_G.Auctionator = nil
	NS:DB().bagspaceKeep = {}
end

-- 1. Place au butin ---------------------------------------------------------------------
do
	Say("-- place au butin")
	LR.Reset()
	local strings, missing = NS.LOOTROOM_STRINGS, {}
	for key in pairs(strings.fr) do if not strings.en[key] then missing[#missing + 1] = key end end
	Check("[LOOT] textes fr et en", #missing == 0, table.concat(missing, ","))
	local loot = NS:LootRoomLoot()
	Check("[LOOT] sacs pleins : le butin qui ne rentre pas, avec son prix", #loot == 1 and loot[1].itemID == LOOT
		and loot[1].value == 50)
	Mock.world.loot = { { id = LOOT }, { id = QLOOT, quest = true } }
	Check("[LOOT] un objet de quête passe en premier", NS:LootRoomLoot()[1].itemID == QLOOT)
	Mock.world.bags[0].items[1].stackCount = 2
	Mock.world.loot = { { id = CLOTH } }
	Check("[LOOT] le butin complète une pile : il rentre, rien à proposer", #NS:LootRoomLoot() == 0)
	Mock.world.bags[0].items[1].stackCount = 3
	Mock.world.loot = { { id = LOOT } }
	Mock:Fire("LOOT_OPENED")
	local frame = NS.lootRoomFrame
	Check("[LOOT] butin ouvert, sacs pleins : la fenêtre s'ouvre seule", frame and frame:IsShown())
	Check("[LOOT] en tête : le butin et son prix", frame.target.text:find("Butin précieux", 1, true) ~= nil, frame.target.text)
	local rows = NS.lootRoom.rows
	Check("[LOOT] les moins chers d'abord", rows[1].itemID == GREY and rows[2].itemID == WHITE and rows[3].itemID == GREEN)
	Check("[LOOT] plus cher que le butin : en gris (90 > 50)", rows[4].itemID == CLOTH and rows[4].dearer == true
		and frame.rows[4].alpha < 1 and not rows[1].dearer)
	Check("[LOOT] prix du marchand affiché", frame.rows[1].price.text:find("marchand", 1, true) ~= nil)
	-- jeter un gris : tout de suite, puis le butin est ramassé
	frame.rows[1].delete:Click()
	Check("[LOOT] gris : jeté au clic, sans confirmation", Mock.world.deleted == 1 and Mock.world.popup == nil
		and Mock.world.bags[0].items[4] == nil)
	Mock:Fire("BAG_UPDATE_DELAYED")
	Check("[LOOT] puis le butin est ramassé", Mock.world.looted == 1)
	-- un vert : confirmation
	LR.Reset()
	Mock:Fire("LOOT_OPENED")
	local green
	for _, row in ipairs(NS.lootRoom.rows) do if row.itemID == GREEN then green = row end end
	Check("[LOOT] vert : confirmation demandée", NS:LootRoomDelete(green) == "confirm" and Mock.world.popup
		and Mock.world.deleted == 0)
	StaticPopupDialogs.READY2QUEST_LOOTROOM_DESTROY.OnAccept(nil, green)
	Check("[LOOT] … « Détruire » : jeté", Mock.world.deleted == 1 and Mock.world.bags[0].items[2] == nil)
	LR.Reset()
	NS:DB().lootroomConfirm = false
	Mock:Fire("LOOT_OPENED")
	for _, row in ipairs(NS.lootRoom.rows) do if row.itemID == GREEN then green = row end end
	NS:LootRoomDelete(green)
	Check("[LOOT] confirmation coupée : le vert part au clic", Mock.world.deleted == 1)
	NS:DB().lootroomConfirm = true
	-- l'objet a bougé entre-temps : rien
	LR.Reset()
	Mock:Fire("LOOT_OPENED")
	local first = NS.lootRoom.rows[1]
	Mock.world.bags[0].items[first.slot] = { itemID = WHITE, stackCount = 1, quality = 1, hyperlink = LR.Link(WHITE) }
	Check("[LOOT] un autre objet à sa place : rien détruit", NS:LootRoomDestroy(first) == false and Mock.world.deleted == 0)
	-- ignorer : la liste « toujours garder » de Sac plein
	LR.Reset()
	Mock:Fire("LOOT_OPENED")
	NS.lootRoomFrame.rows[1].ignore:Click()
	Check("[LOOT] ignorer : toujours gardé, plus proposé", NS:DB().bagspaceKeep[GREY] == true
		and NS.lootRoom.rows[1].itemID ~= GREY)
	-- prix de l'hôtel des ventes
	LR.Reset()
	_G.Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(_, link)
		if link:find(tostring(WHITE), 1, true) then return 200 end
	end } } }
	Mock:Fire("LOOT_OPENED")
	local white
	for index, row in ipairs(NS.lootRoom.rows) do if row.itemID == WHITE then white = index end end
	Check("[LOOT] prix HV (Auctionator) : affiché, et compte dans la valeur", NS.lootRoom.rows[white].auction == 200
		and NS.lootRoom.rows[white].dearer == true and NS.lootRoomFrame.rows[white].price.text:find("HV", 1, true))
	NS:DB().lootroomAuction = false
	Check("[LOOT] prix HV coupé : ignoré", NS:LootRoomAuction(LR.Link(WHITE), 1) == nil)
	NS:DB().lootroomAuction = true
	_G.Auctionator = nil
	-- fermeture, ouverture à la main, module coupé
	Mock:Fire("LOOT_CLOSED")
	Check("[LOOT] butin fermé : la fenêtre aussi", not NS.lootRoomFrame:IsShown())
	Mock.world.loot = {}
	NS:HandleCommand("place")
	Check("[LOOT] /r2q place : ouverte à la main, sans butin", NS.lootRoomFrame:IsShown()
		and NS.lootRoomFrame.target.text == NS.L.LOOTROOM_NO_TARGET)
	NS.lootRoomFrame:Hide()
	LR.Reset()
	NS:DB().lootroomEnabled = false
	Mock:Fire("LOOT_OPENED")
	Check("[LOOT] module coupé : rien", not NS.lootRoomFrame:IsShown())
	NS:DB().lootroomEnabled = true
	LR.Reset()
	Mock.world.bags[0].size = 5
	Mock:Fire("LOOT_OPENED")
	Check("[LOOT] une place libre : rien", not NS.lootRoomFrame:IsShown())
end

-- 2. Rangs de sorts -----------------------------------------------------------------------------
do
	Say("-- rangs de sorts")
	local SPELLS = {
		[101] = { "Lumière sacrée", "Rang 3" }, [102] = { "Lumière sacrée", "Rang 5" }, [103] = { "Lumière sacrée", "Rang 4" },
		[201] = { "Bouclier divin", "Rang 1" }, [301] = { "Purification", nil }, [401] = { "Marteau", "Rang 2" },
		[104] = { "Lumière sacrée", "Rang 5" },
	}
	local BOOK = { 102, 103, 201, 301, 401 }
	local W = { actions = {}, placed = {} }
	function LR.SpellReset()
		ResetWorld()
		if NS.spellRanksFrame then NS.spellRanksFrame:Hide() end
		NS.spellRanksAnnounced, NS.spellRanksPending, NS.notice = nil, nil, nil
		NS.spellRanksMarkDueAt, NS.spellRanksDueAt = nil, nil
		W.actions = { [4] = 101, [5] = 102, [6] = 104, [16] = 101, [20] = 301, [30] = 401 }
		W.placed, W.picked = {}, nil
		_G.C_Spell, _G.C_SpellBook = nil, nil
		_G.GetActionInfo = function(slot) local id = W.actions[slot]; if id then return "spell", id end end
		_G.GetSpellInfo = function(id) return SPELLS[id] and SPELLS[id][1] end
		_G.GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end
		_G.GetSpellTexture = function() return "Interface\\Icons\\Spell_Holy_HolyBolt" end
		_G.GetNumSpellTabs = function() return 1 end
		_G.GetSpellTabInfo = function() return "Sacré", "", 0, #BOOK end
		_G.GetSpellBookItemInfo = function(index) return "SPELL", BOOK[index] end
		_G.PickupSpell = function(id) W.picked = id end
		_G.PlaceAction = function(slot) W.actions[slot] = W.picked; W.placed[#W.placed + 1] = slot end
		_G.ClearCursor = function() end
		_G.InCombatLockdown = function() return W.combat == true end
		W.combat = false
		NS:DB().spellranksIgnore = {}
	end
	LR.SpellReset()
	local strings, missing = NS.SPELLRANKS_STRINGS, {}
	for key in pairs(strings.fr) do if not strings.en[key] then missing[#missing + 1] = key end end
	Check("[RANK] textes fr et en", #missing == 0, table.concat(missing, ","))
	local name, rank = NS:SpellRankOf(101)
	Check("[RANK] « Rang 3 » : 3", name == "Lumière sacrée" and rank == 3)
	Check("[RANK] livre : le meilleur rang connu", NS:SpellRankBook()["Lumière sacrée"].id == 102)
	local list = NS:SpellRankScan()
	Check("[RANK] deux cases à mettre à jour (barre 1 case 4, barre 2 case 4)", #list == 2 and list[1].slot == 4
		and list[1].bestRank == 5 and list[2].bar == 2 and list[2].case == 4, #list)
	Check("[RANK] déjà au meilleur, sans rang, rang unique : rien", (function()
		for _, e in ipairs(list) do if e.slot == 5 or e.slot == 6 or e.slot == 20 or e.slot == 30 then return false end end
		return true
	end)())
	-- ignorer une case : l'autre case du même sort reste signalée
	NS:SpellRankIgnore(list[1])
	list = NS:SpellRankScan()
	Check("[RANK] case ignorée : retirée, l'autre case reste", #list == 1 and list[1].slot == 16)
	Check("[RANK] la liste complète la montre ignorée", #NS:SpellRankScan(true) == 2 and NS:SpellRankScan(true)[1].ignored)
	Check("[RANK] oublier les cases ignorées", NS:SpellRanksForget() == 1 and #NS:SpellRankScan() == 2)
	-- mettre à jour
	W.combat = true
	Check("[RANK] en combat : refusé", NS:SpellRankUpdate(NS:SpellRankScan()[1]) == false and #W.placed == 0)
	W.combat = false
	local stale = NS:SpellRankScan()[1]
	W.actions[4] = 201
	Check("[RANK] la case a changé entre-temps : rien", NS:SpellRankUpdate(stale) == false and #W.placed == 0)
	W.actions[4] = 101
	Check("[RANK] mise à jour : le meilleur rang dans la même case", NS:SpellRankUpdate(NS:SpellRankScan()[1])
		and W.actions[4] == 102 and W.placed[1] == 4)
	Check("[RANK] tout mettre à jour", NS:SpellRankUpdateAll() == 1 and W.actions[16] == 102 and #NS:SpellRankScan() == 0)
	-- annonce et fenêtre
	LR.SpellReset()
	NS:DB().reportIcon = true
	Check("[RANK] annonce : deux sorts", NS:SpellRanksCheck() == 2 and Mock:Output():find("meilleur rang", 1, true)
		and NS.notice and NS.notice.kind == "spells")
	NS.notice = nil
	NS:SpellRanksCheck()
	Check("[RANK] même chose ensuite : pas de nouvelle annonce", NS.notice == nil)
	W.combat = true
	Check("[RANK] en combat : remis à la fin du combat", NS:SpellRanksCheck() == nil and NS.spellRanksPending == true)
	W.combat = false
	NS:HandleCommand("sorts")
	local frame = NS.spellRanksFrame
	Check("[RANK] /r2q sorts : la liste", frame and frame:IsShown() and frame.rows[1].text.text:find("rang 3", 1, true)
		and frame.rows[1].where.text == "barre 1, case 4", frame and frame.rows[1].text.text)
	frame.rows[1].update:Click()
	Check("[RANK] [Mettre à jour] : la ligne disparaît", #frame.list == 1)
	frame.rows[1].ignore:Click()
	Check("[RANK] [Ignorer] : plus rien, « tout est à jour »", #frame.list == 0 and frame.empty.text == NS.L.SR_NONE)
	frame:Hide()
	-- check avant le départ
	local check
	for _, def in ipairs(NS.checks) do if def.id == "barranks" then check = def end end
	LR.SpellReset()
	local ok, detail = check.run()
	Check("[RANK] check avant le départ : 2 sorts à jour à faire", check and ok == false and detail:find("2", 1, true))
	NS:SpellRankUpdateAll()
	Check("[RANK] check : tout à jour, validé", check.run() == true)
	-- livre moderne (C_SpellBook) : même résultat
	LR.SpellReset()
	_G.Enum = _G.Enum or {}
	local savedBank = Enum.SpellBookSpellBank
	Enum.SpellBookSpellBank = { Player = 0 }
	_G.C_SpellBook = {
		GetNumSpellBookSkillLines = function() return 1 end,
		GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #BOOK } end,
		GetSpellBookItemInfo = function(index) return { spellID = BOOK[index], name = SPELLS[BOOK[index]][1] } end,
	}
	Check("[RANK] livre récent (C_SpellBook) : le même résultat", #NS:SpellRankScan() == 2)
	Enum.SpellBookSpellBank = savedBank
	_G.C_SpellBook = nil
	-- liseré rouge sur les barres
	LR.SpellReset()
	local function Button(name, fields)
		local b = CreateFrame("Frame")
		for k, v in pairs(fields) do b[k] = v end
		_G[name] = b
		return b
	end
	local b4 = Button("ActionButton4", { action = 4 })
	local b5 = Button("ActionButton5", { action = 5 })
	local bt = Button("BT4Button16", { _state_action = 16 })
	local paged = Button("MultiBarLeftButton1", { GetPagedID = function() return 20 end })
	Check("[RANK] case d'un bouton : action, Bartender, GetPagedID", NS.SpellRankButtonSlot(b4) == 4
		and NS.SpellRankButtonSlot(bt) == 16 and NS.SpellRankButtonSlot(paged) == 20 and NS.SpellRankButtonSlot({}) == nil)
	Check("[RANK] liseré : les deux cases à mettre à jour", NS:SpellRanksMark() == 2)
	local border = NS.spellRanksBorders[b4]
	Check("[RANK] liseré : sur la case 4 et la case 16 (Bartender), pas sur la 5", border and border:IsShown()
		and NS.spellRanksBorders[bt]:IsShown() and (NS.spellRanksBorders[b5] == nil or not NS.spellRanksBorders[b5]:IsShown()))
	NS:SpellRankIgnore(NS:SpellRankScan()[1])
	Check("[RANK] liseré : case ignorée, plus de liseré", NS:SpellRanksMark() == 1 and not border:IsShown())
	NS:SpellRanksForget()
	NS:DB().spellranksBorder = false
	Check("[RANK] liseré coupé dans les réglages : aucun", NS:SpellRanksMark() == 0 and not border:IsShown())
	NS:DB().spellranksBorder = true
	-- après une mise à jour, le liseré s'en va (au tour suivant)
	NS:SpellRanksMark()
	NS:SpellRankUpdateAll()
	Mock:Advance(0.5)
	Check("[RANK] mise à jour : les liserés partent d'eux-mêmes", not border:IsShown()
		and not NS.spellRanksBorders[bt]:IsShown())
	-- en combat : pas de nouveau cadre posé sur un bouton
	LR.SpellReset()
	local fresh = Button("MultiBarRightButton4", { action = 16 })
	W.combat = true
	NS:SpellRanksMark()
	Check("[RANK] en combat : pas de nouveau liseré créé", NS.spellRanksBorders[fresh] == nil)
	W.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Mock:Advance(1)
	Check("[RANK] fin du combat : le liseré arrive", NS.spellRanksBorders[fresh] and NS.spellRanksBorders[fresh]:IsShown())
	for _, name in ipairs({ "ActionButton4", "ActionButton5", "BT4Button16", "MultiBarLeftButton1", "MultiBarRightButton4" }) do
		_G[name] = nil
	end
	NS:DB().spellranksEnabled = false
	Check("[RANK] module coupé : rien d'annoncé", NS:SpellRanksCheck() == 0)
	NS:DB().spellranksEnabled = true
end

LR.Restore()
ResetWorld()
