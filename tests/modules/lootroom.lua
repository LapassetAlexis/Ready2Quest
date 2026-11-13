-- « Place au butin » (LootRoom.lua, 1.27.0, sur le modèle de Delete Cheapest
-- Item) : butin qui ne rentre pas, le moins cher d'abord, destruction (gris au
-- clic, sinon confirmée), prix HV ; 1.32.2 : ce que l'on garde n'est plus
-- proposé (outils, camp, artisanat, caisses, bandages), la liste défile.
-- « Rangs de sorts » (SpellRanks.lua) : cases à mettre à jour, liserés.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local LR = { savedG = {} }
local saved = {
	CItemGetItemInfo = C_Item.GetItemInfo,
	PickupContainerItem = C_Container.PickupContainerItem,
}
for _, name in ipairs({ "DeleteCursorItem", "CursorHasItem", "StaticPopup_Show", "StaticPopupDialogs", "InCombatLockdown",
	"GetNumLootItems", "GetLootSlotLink", "LootSlotHasItem", "GetLootSlotInfo", "LootSlot", "Auctionator",
	"GetActionInfo", "GetSpellInfo", "GetSpellSubtext", "GetSpellTexture", "PickupSpell", "PlaceAction", "ClearCursor",
	"GetNumSpellTabs", "GetSpellTabInfo", "GetSpellBookItemInfo", "C_Spell", "C_SpellBook", "GetNumSkillLines",
	"GetSkillLineInfo", "IsPassiveSpell", "HasAction", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
	"MultiBarLeft" }) do
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
	NS:DB().favorites = {}
end

-- 1. Place au butin ---------------------------------------------------------------------
do
	Say("-- place au butin")
	LR.Reset()
	local strings, missing = NS.LOOTROOM_STRINGS, {}
	for key in pairs(strings.fr) do if not strings.en[key] then missing[#missing + 1] = key end end
	Check("[LOOT] textes fr et en", #missing == 0, table.concat(missing, ","))
	local loot = NS:LootRoomLoot()
	Mock.world.loot = { { id = LOOT }, { id = QLOOT, quest = true } }
	local quest = NS:LootRoomLoot()[1].itemID == QLOOT
	Mock.world.bags[0].items[1].stackCount = 2
	Mock.world.loot = { { id = CLOTH } }
	Check("[LOOT] sacs pleins : le butin qui ne rentre pas (avec son prix, la quête d'abord) ; qui complète une pile : rien",
		#loot == 1 and loot[1].itemID == LOOT and loot[1].value == 50 and quest and #NS:LootRoomLoot() == 0)
	Mock.world.bags[0].items[1].stackCount = 3
	Mock.world.loot = { { id = LOOT } }
	Mock:Fire("LOOT_OPENED")
	local frame = NS.lootRoomFrame
	Check("[LOOT] butin ouvert, sacs pleins : la fenêtre s'ouvre seule, le butin en tête", frame and frame:IsShown()
		and frame.target.text:find("Butin précieux", 1, true) ~= nil, frame and frame.target.text)
	local rows = NS.lootRoom.rows
	Check("[LOOT] les moins chers d'abord, prix du marchand ; plus cher que le butin : en gris (90 > 50)", rows[1].itemID == GREY
		and rows[2].itemID == WHITE and rows[3].itemID == GREEN and rows[4].itemID == CLOTH and rows[4].dearer == true
		and frame.rows[4].alpha < 1 and not rows[1].dearer and frame.rows[1].price.text:find("marchand", 1, true) ~= nil)
	-- jeter un gris : tout de suite, puis le butin est ramassé
	frame.rows[1].delete:Click()
	local thrown = Mock.world.deleted == 1 and Mock.world.popup == nil and Mock.world.bags[0].items[4] == nil
	Mock:Fire("BAG_UPDATE_DELAYED")
	Check("[LOOT] gris : jeté au clic, sans confirmation, puis le butin est ramassé", thrown and Mock.world.looted == 1)
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
	Check("[LOOT] ignorer : toujours gardé, plus proposé", type(NS:DB().favorites[GREY]) == "string"
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
	local closed = not NS.lootRoomFrame:IsShown()
	Mock.world.loot = {}
	NS:HandleCommand("place")
	Check("[LOOT] butin fermé : la fenêtre aussi ; /r2q place : ouverte à la main, sans butin", closed
		and NS.lootRoomFrame:IsShown() and NS.lootRoomFrame.target.text == NS.L.LOOTROOM_NO_TARGET)
	NS.lootRoomFrame:Hide()
	LR.Reset()
	NS:DB().lootroomEnabled = false
	Mock:Fire("LOOT_OPENED")
	local off = not NS.lootRoomFrame:IsShown()
	NS:DB().lootroomEnabled = true
	LR.Reset()
	Mock.world.bags[0].size = 5
	Mock:Fire("LOOT_OPENED")
	Check("[LOOT] module coupé, ou une place libre : rien", off and not NS.lootRoomFrame:IsShown())
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
	Check("[RANK] « Rang 3 » : 3 ; livre : le meilleur rang connu", name == "Lumière sacrée" and rank == 3
		and NS:SpellRankBook()["Lumière sacrée"].id == 102)
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
	Check("[RANK] case ignorée : retirée, l'autre case reste, la liste complète la montre ignorée", #list == 1
		and list[1].slot == 16 and #NS:SpellRankScan(true) == 2 and NS:SpellRankScan(true)[1].ignored)
	Check("[RANK] oublier les cases ignorées", NS:SpellRanksForget() == 1 and #NS:SpellRankScan() == 2)
	-- mettre à jour
	W.combat = true
	local inCombat = NS:SpellRankUpdate(NS:SpellRankScan()[1]) == false
	W.combat = false
	local stale = NS:SpellRankScan()[1]
	W.actions[4] = 201
	Check("[RANK] en combat, ou case changée entre-temps : rien", inCombat and NS:SpellRankUpdate(stale) == false
		and #W.placed == 0)
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
	local once = NS.notice == nil
	W.combat = true
	Check("[RANK] même chose ensuite : pas de nouvelle annonce ; en combat : remis à la fin du combat", once
		and NS:SpellRanksCheck() == nil and NS.spellRanksPending == true)
	W.combat = false
	NS:HandleCommand("sorts")
	local frame = NS.spellRanksFrame
	Check("[RANK] /r2q sorts : la liste", frame and frame:IsShown() and frame.rows[1].text.text:find("rang 3", 1, true)
		and frame.rows[1].where.text == "barre 1, case 4", frame and frame.rows[1].text.text)
	frame.rows[1].update:Click()
	local updated = #frame.list == 1
	frame.rows[1].ignore:Click()
	Check("[RANK] [Mettre à jour] puis [Ignorer] : plus rien, « tout est à jour »", updated and #frame.list == 0
		and frame.empty.text == NS.L.SR_NONE)
	frame:Hide()
	-- check avant le départ
	local check
	for _, def in ipairs(NS.checks) do if def.id == "barranks" then check = def end end
	LR.SpellReset()
	local ok, detail = check.run()
	NS:SpellRankUpdateAll()
	Check("[RANK] check avant le départ : 2 sorts à mettre à jour, puis validé", check and ok == false
		and detail:find("2", 1, true) and check.run() == true, detail)
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
	local marked = NS:SpellRanksMark()
	local border = NS.spellRanksBorders[b4]
	Check("[RANK] liseré : sur la case 4 et la case 16 (Bartender), pas sur la 5", marked == 2 and border and border:IsShown()
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
	local none = NS.spellRanksBorders[fresh] == nil
	W.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Mock:Advance(1)
	Check("[RANK] en combat : pas de nouveau liseré ; à la fin du combat, il arrive", none and NS.spellRanksBorders[fresh]
		and NS.spellRanksBorders[fresh]:IsShown())
	for _, name in ipairs({ "ActionButton4", "ActionButton5", "BT4Button16", "MultiBarLeftButton1", "MultiBarRightButton4" }) do
		_G[name] = nil
	end
	NS:DB().spellranksEnabled = false
	Check("[RANK] module coupé : rien d'annoncé", NS:SpellRanksCheck() == 0)
	NS:DB().spellranksEnabled = true
end

-- 3. 1.32.2 : ce que l'on garde n'est pas proposé, la liste défile ---------------------
do
	Say("-- place au butin : objets gardés, défilement (1.32.2)")
	local JUNK, PICK, KIT, WHEEL, ORE, WOOD, CRATE, BANDAGE, RECIPE, REAGENT, NAMEDPICK, KCLOTH, KLOOT =
		990001, 2901, 279981, 279944, 990005, 990006, 990007, 990008, 990009, 990010, 990011, 990012, 990099
	local skills = {}
	_G.GetNumSkillLines = function() return #skills end
	_G.GetSkillLineInfo = function(index)
		local sk = skills[index]
		if sk then return sk[1], false, true, sk[2] end
	end
	C_Item.GetItemInfo = function(item)
		local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
		local d = Mock.world.itemInfo[id]
		if not d then return nil end
		return d.name, LR.Link(id), d.quality or 1, 1, 1, "", "", d.maxStack or 20, nil, nil, d.sellPrice or 1
	end
	local function Bags(list)
		local items = {}
		for slot, spec in ipairs(list) do
			items[slot] = { itemID = spec[1], stackCount = 1, quality = 1, hyperlink = LR.Link(spec[1]), hasLoot = spec.hasLoot }
		end
		Mock.world.bags[0] = { size = #items, items = items }
	end
	local function Reset()
		LR.Reset()
		NS.lootRoomOffset = nil
		Mock.world.itemInfo = {
			[JUNK] = { name = "Os brisé", classID = 15, subClassID = 0, sellPrice = 1, quality = 0 },
			[PICK] = { name = "Pioche de mineur", classID = 7, subClassID = 0 },
			[KIT] = { name = "Kit de feu de camp basique", classID = 0, subClassID = 0 },
			[WHEEL] = { name = "Meule à aiguiser", classID = 15, subClassID = 0 },
			[ORE] = { name = "Magnétite", classID = 7, subClassID = 7 },
			[WOOD] = { name = "Bois simple", classID = 7, subClassID = 0 },
			[CRATE] = { name = "Caisse détournée : textiles d'apprenti", classID = 15, subClassID = 0 },
			[BANDAGE] = { name = "Bandage en lin", classID = 0, subClassID = 7 },
			[RECIPE] = { name = "Recette : ragoût", classID = 9, subClassID = 5 },
			[REAGENT] = { name = "Plume légère", classID = 5, subClassID = 0 },
			[NAMEDPICK] = { name = "Pioche de mineur", classID = 2, subClassID = 0 },
			[KCLOTH] = { name = "Étoffe de laine", classID = 7, subClassID = 5, sellPrice = 2 },
			[KLOOT] = { name = "Butin", classID = 4, subClassID = 0, sellPrice = 50 },
		}
		for i = 1, 12 do Mock.world.itemInfo[991000 + i] = { name = "Babiole " .. i, classID = 15, subClassID = 0, sellPrice = i } end
		Mock.world.loot = { { id = KLOOT } }
		skills = { { "Minage", 50 }, { "Forge", 40 } }
		NS:DB().favorites, NS:DB().bagspaceDiscard = {}, {}
	end

	Reset()
	Bags({ { JUNK }, { PICK }, { KIT }, { WHEEL }, { ORE }, { WOOD }, { CRATE, hasLoot = true }, { BANDAGE },
		{ RECIPE }, { REAGENT }, { NAMEDPICK }, { KCLOTH } })
	local rows = NS:LootRoomRows(nil)
	local ids = {}
	for _, row in ipairs(rows) do ids[row.itemID] = true end
	Check("[LOOT] gardés : seuls l'os et l'étoffe (métier inconnu) restent proposés", #rows == 2 and ids[JUNK] and ids[KCLOTH],
		#rows)
	local ctx = NS:LootRoomKeepContext()
	local function Why(id, slot) return NS:LootRoomKeepReason({ itemID = id, bag = 0, slot = slot or 1, link = LR.Link(id) }, ctx) end
	local bad = {}
	for _, c in ipairs({ { PICK, "tool" }, { NAMEDPICK, "tool" }, { KIT, "camp" }, { WHEEL, "camp" }, { ORE, "trade" },
		{ WOOD, "trade" }, { REAGENT, "trade" }, { RECIPE, "recipe" }, { CRATE, "open", 7 }, { BANDAGE, "care" } }) do
		local why = Why(c[1], c[3])
		if why ~= c[2] then bad[#bad + 1] = Mock.world.itemInfo[c[1]].name .. "=" .. tostring(why) end
	end
	Check("[LOOT] raisons : outils (numéro et nom), camp, artisanat d'un métier connu, recette, caisse, bandage", #bad == 0,
		table.concat(bad, ", "))
	local plain = Why(KCLOTH)
	skills = { { "Secourisme", 10 } }
	local firstAid = NS:LootRoomKeepReason({ itemID = KCLOTH, bag = 0, slot = 12 }, NS:LootRoomKeepContext())
	skills = {}
	Check("[LOOT] tissu proposé sans couture ni secourisme, gardé avec ; aucun métier : bois proposé", plain == nil
		and firstAid == "trade" and NS:LootRoomKeepReason({ itemID = WOOD, bag = 0, slot = 6 }, NS:LootRoomKeepContext()) == nil)
	NS:DB().bagspaceDiscard[PICK] = true
	ids = {}
	for _, row in ipairs(NS:LootRoomRows(nil)) do ids[row.itemID] = true end
	Check("[LOOT] « toujours jeter » l'emporte", ids[PICK] == true)

	Reset()
	local list = {}
	for i = 1, 12 do list[i] = { 991000 + i } end
	Bags(list)
	Mock:Fire("LOOT_OPENED")
	local frame = NS.lootRoomFrame
	Check("[LOOT] 12 candidats, 8 lignes visibles, glissière, « 1 à 8 sur 12 »", frame and frame:IsShown()
		and #NS.lootRoom.rows == 12 and frame.rows[8].data == NS.lootRoom.rows[8] and frame.thumb:IsShown()
		and frame.hint.text:find("1 à 8 sur 12", 1, true) ~= nil, frame and frame.hint.text)
	NS:LootRoomScroll(-1)
	local oneDown = NS.lootRoom.offset == 1 and frame.rows[1].data == NS.lootRoom.rows[2]
	NS:LootRoomScroll(-20)
	Check("[LOOT] molette : une ligne plus bas, butée en bas", oneDown and NS.lootRoom.offset == 4
		and frame.rows[8].data.itemID == 991012)
	frame.rows[8].ignore:Click()
	Check("[LOOT] ignorer une ligne défilée : la bonne", type(NS:DB().favorites[991012]) == "string" and #NS.lootRoom.rows == 11
		and NS.lootRoom.offset == 3)
	NS:LootRoomScroll(20)
	local top = NS.lootRoom.offset == 0
	Mock:Fire("LOOT_CLOSED")
	NS.lootRoomOffset = 3
	Mock:Fire("LOOT_OPENED")
	Check("[LOOT] butée en haut ; rouverte : en haut de la liste", top and NS.lootRoom.offset == 0)
	Mock:Fire("LOOT_CLOSED")
	Bags({ { 991001 }, { 991002 } })
	NS:LootRoomOpen(true)
	Check("[LOOT] liste courte : pas de glissière, aide normale", not frame.thumb:IsShown() and frame.hint.text == NS.L.LOOTROOM_HINT)
	frame:Hide()
end


-- 4. 1.35.0 : nouveaux sorts sur aucune barre (Rangs de sorts) --------------------------
do
	Say("-- rangs de sorts : nouveaux sorts (1.35.0)")
	local function Steps()
		local st = { bad = {} }
		function st.ok(label, cond, extra)
			if not cond then st.bad[#st.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
		end
		function st.check(name) Check(name, #st.bad == 0, table.concat(st.bad, " ; ")) end
		return st
	end
	-- livre : onglet Général (métier, monture) puis onglet de la classe
	local SPELLS = {
		[900] = { "Cuisine" }, [901] = { "Destrier" }, [902] = { "Secourisme" },
		[101] = { "Lumière sacrée", "Rang 3" }, [102] = { "Lumière sacrée", "Rang 5" }, [301] = { "Purification" },
		[501] = { "Consécration", "Rang 1" }, [502] = { "Aura de dévotion" }, [503] = { "Bénédiction de puissance", "Rang 1" },
		[504] = { "Exorcisme", "Rang 2" },
	}
	local W = {}
	local function Install()
		ResetWorld()
		if NS.spellRanksFrame then NS.spellRanksFrame:Hide() end
		NS.spellRanksAnnounced, NS.newSpellsAnnounced, NS.spellRanksPending, NS.notice = nil, nil, nil, nil
		W.general = { 900, 901 }
		W.class = { 101, 102, 301 }
		W.passive = { [502] = true }
		W.actions = { [4] = 102, [5] = 301 }
		W.picked, W.placed, W.combat, W.cleared = nil, {}, false, 0
		_G.C_Spell, _G.C_SpellBook, _G.HasAction = nil, nil, nil
		_G.GetActionInfo = function(slot) local id = W.actions[slot]; if id then return "spell", id end end
		_G.GetSpellInfo = function(id) return SPELLS[id] and SPELLS[id][1] end
		_G.GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end
		_G.GetSpellTexture = function() return "Interface\\Icons\\Spell_Holy_HolyBolt" end
		_G.IsPassiveSpell = function(id) return W.passive[id] == true end
		_G.GetNumSpellTabs = function() return 2 end
		_G.GetSpellTabInfo = function(tab)
			if tab == 1 then return "Général", "", 0, #W.general end
			return "Sacré", "", #W.general, #W.class
		end
		_G.GetSpellBookItemInfo = function(index)
			local id = index <= #W.general and W.general[index] or W.class[index - #W.general]
			return "SPELL", id
		end
		_G.PickupSpell = function(id) W.picked = id end
		_G.PlaceAction = function(slot) W.actions[slot] = W.picked; W.placed[#W.placed + 1] = slot end
		_G.ClearCursor = function() W.picked = nil; W.cleared = W.cleared + 1 end
		_G.InCombatLockdown = function() return W.combat == true end
		for _, name in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }) do _G[name] = nil end
	end
	local function Learn(id) W.class[#W.class + 1] = id end
	local function Names(list) local t = {} for i, e in ipairs(list) do t[i] = e.name end return table.concat(t, ",") end

	-- photo du livre, puis seulement les nouveaux
	local s = Steps()
	Install()
	s.ok("premier passage : la photo, rien de proposé", #NS:NewSpellsScan() == 0 and NS:CharData().newSpellsBase
		and NS:CharData().newSpellsBase["Lumière sacrée"] == true and NS:CharData().newSpellsBase["Purification"] == true)
	s.ok("ni l'onglet Général dans la photo (métiers, montures)", NS:CharData().newSpellsBase["Cuisine"] == nil)
	Learn(501); Learn(502); Learn(503); Learn(504)
	W.general[#W.general + 1] = 902               -- un nouveau métier (Général)
	W.actions[7] = 503                            -- déjà posé sur une barre
	local list = NS:NewSpellsScan()
	s.ok("nouveau sort actif hors des barres : proposé ; passif, métier, déjà sur une barre : non", Names(list) == "Consécration,Exorcisme",
		Names(list))
	s.ok("posé une fois : connu pour de bon (retiré des barres, pas reproposé)", (function()
		W.actions[7] = nil
		local again = Names(NS:NewSpellsScan())
		return again == "Consécration,Exorcisme"
	end)())
	-- un livre pas encore lu à la connexion : pas de photo vide
	Install()
	_G.GetNumSpellTabs = function() return 0 end
	NS:NewSpellsScan()
	s.ok("livre vide : pas de photo (tout serait proposé ensuite)", NS:CharData().newSpellsBase == nil)
	s.check("[NEW] nouveaux sorts : photo d'abord, puis seulement les sorts actifs appris hors des barres (ni passif, ni métier, ni monture)")

	-- annonce, check, fenêtre
	s = Steps()
	Install()
	NS:NewSpellsScan()
	Learn(501)
	NS:DB().reportIcon = true
	Mock:Reset()
	NS:SpellRanksCheck()
	s.ok("annonce : chat et icône", Mock:Output():find("Nouveaux sorts sur aucune de tes barres : 1", 1, true) ~= nil
		and NS.notice and NS.notice.kind == "spells", Mock:Output())
	local check
	for _, def in ipairs(NS.checks) do if def.id == "barranks" then check = def end end
	local ok, detail = check.run()
	s.ok("check avant le départ : compté", ok == false and detail:find("1 nouveau", 1, true) ~= nil, detail)
	NS:HandleCommand("sorts")
	local frame = NS.spellRanksFrame
	local row = frame.newRows[1]
	s.ok("fenêtre : section et ligne", frame:IsShown() and frame.newSection:IsShown() and row:IsShown()
		and row.text.text == "Consécration (rang 1)" and row.where.text == "Sur aucune de tes barres", row.text.text)
	s.ok("sans rang à mettre à jour : pas de « Tout mettre à jour », pas de « tout est à jour »",
		not frame.all:IsShown() and frame.empty.text == "")
	row.place:Click()
	s.ok("[Placer] : la première case vide de la barre 1", W.actions[1] == 501 and W.placed[1] == 1 and W.picked == nil
		and #frame.newList == 0 and not frame.newSection:IsShown())
	s.ok("check validé ensuite", check.run() == true)
	frame:Hide()
	s.check("[NEW] annonce, ligne du check, fenêtre : section « Nouveaux sorts », [Placer] dans une case vide")

	-- cases pleines, autres barres, combat, curseur
	s = Steps()
	Install()
	NS:NewSpellsScan()
	Learn(504)
	for slot = 1, 12 do W.actions[slot] = W.actions[slot] or 301 end
	W.combat = true
	local entry = NS:NewSpellsScan()[1]
	s.ok("en combat : rien", NS:NewSpellPlace(entry) == false and #W.placed == 0 and W.picked == nil)
	W.combat = false
	_G.MultiBarBottomLeft = { IsShown = function() return true end }
	s.ok("barre 1 pleine : la barre en bas à gauche affichée (case 61)", NS:NewSpellPlace(entry) == 61 and W.actions[61] == 504)
	W.actions[61] = nil
	_G.MultiBarBottomLeft = { IsShown = function() return false end }
	Mock:Reset()
	s.ok("aucune case vide (autres barres cachées) : sur le curseur, un mot dans le chat", NS:NewSpellPlace(entry) == "cursor"
		and W.picked == 504 and #W.placed == 1 and Mock:Output():find("sur ton curseur", 1, true) ~= nil, Mock:Output())
	s.check("[NEW] [Placer] : barre 1, puis les autres barres affichées, sinon le curseur ; jamais en combat")

	-- ignorer, réglages, reproposer
	s = Steps()
	Install()
	NS:NewSpellsScan()
	Learn(501); Learn(504)
	NS:NewSpellIgnore(NS:NewSpellsScan()[1])
	s.ok("[Ignorer] : plus proposé, gardé par personnage", Names(NS:NewSpellsScan()) == "Exorcisme"
		and NS:CharData().newSpellsIgnore["Consécration"] == true)
	local choices = NS:NewSpellsIgnoredChoices()
	s.ok("réglages : la liste des ignorés", #choices == 1 and choices[1].value == "Consécration")
	local rowDef
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		for _, r in ipairs(page.rows or {}) do if r.key == "newspellsIgnored" then rowDef = r end end
	end
	s.ok("réglage dans la page Rangs de sorts", rowDef ~= nil and rowDef.choices ~= nil)
	rowDef.choose("Consécration")
	s.ok("le choisir : reproposé", Names(NS:NewSpellsScan()) == "Consécration,Exorcisme"
		and NS:NewSpellsIgnoredChoices()[1].disabled == true)
	s.check("[NEW] [Ignorer] : retenu par personnage ; la liste des réglages le repropose")

	-- livre récent, textes, contraste
	s = Steps()
	Install()
	_G.Enum = _G.Enum or {}
	local savedBank = Enum.SpellBookSpellBank
	Enum.SpellBookSpellBank = { Player = 0 }
	local lines = { { 900, 901 }, { 101, 102, 301 } }
	_G.C_SpellBook = {
		GetNumSpellBookSkillLines = function() return #lines end,
		GetSpellBookSkillLineInfo = function(line)
			local offset = 0
			for i = 1, line - 1 do offset = offset + #lines[i] end
			return { itemIndexOffset = offset, numSpellBookItems = #lines[line] }
		end,
		GetSpellBookItemInfo = function(index)
			for _, l in ipairs(lines) do
				if index <= #l then local id = l[index]; return { spellID = id, name = SPELLS[id][1], isPassive = W.passive[id] } end
				index = index - #l
			end
		end,
	}
	NS:NewSpellsScan()
	table.insert(lines[2], 501); table.insert(lines[2], 502); table.insert(lines[1], 902)
	s.ok("livre récent (C_SpellBook) : le même tri", Names(NS:NewSpellsScan()) == "Consécration")
	Enum.SpellBookSpellBank = savedBank
	_G.C_SpellBook = nil
	local strings, missing = NS.SPELLRANKS_STRINGS, {}
	for key in pairs(strings.fr) do if not strings.en[key] then missing[#missing + 1] = key end end
	for key in pairs(strings.en) do if not strings.fr[key] then missing[#missing + 1] = key end end
	s.ok("textes FR et EN", #missing == 0, table.concat(missing, ","))
	local Theme = NS.Theme
	s.ok("intertitre lisible (MUTED clair sur la fenêtre ≥ 4,5:1)", Theme.Contrast(Theme.MUTED_LIGHT, Theme.WINDOW) >= 4.5)
	s.check("[NEW] livre récent, textes FR/EN, contraste de l'intertitre")
	_G.MultiBarBottomLeft = nil
end

LR.Restore()
ResetWorld()
