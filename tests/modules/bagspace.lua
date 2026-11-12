-- Module « Sac plein » (v1.24.0) : choix de l'objet le moins coûteux à jeter
-- (exclusions, listes garder/jeter), déclenchement, destruction toujours
-- confirmée et revérifiée, combat, commandes, page de réglages.
local Check, ResetWorld, NS, Mock = T.Check, T.ResetWorld, T.NS, T.Mock

-- Globales du client absentes du harnais : posées ici, restaurées en fin de fichier
local saved = {
	CItemGetItemInfo = C_Item.GetItemInfo,
	PickupContainerItem = C_Container.PickupContainerItem,
	GetContainerNumFreeSlots = C_Container.GetContainerNumFreeSlots,
}
local savedG = {}
for _, name in ipairs({ "DeleteCursorItem", "GetCursorInfo", "ClearCursor", "StaticPopup_Show", "StaticPopupDialogs",
	"InCombatLockdown", "ERR_INV_FULL", "ERR_BAG_FULL", "GetNumLootItems", "GetLootSlotLink", "LootSlotHasItem",
	"LE_GAME_ERR_INV_FULL" }) do
	savedG[name] = { value = rawget(_G, name) }
end

local B = {}   -- une seule locale pour les aides (limite de 200 locales)

-- GetItemInfo du harnais : 10 retours ; il faut ici le 8e (pile max) et le
-- 11e (prix de vente)
C_Item.GetItemInfo = function(item)
	local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
	local d = Mock.world.itemInfo[id]
	if not d then return nil end
	return d.name, B.Link(id), d.quality, 1, 1, "", "", d.maxStack or 20, nil, nil, d.sellPrice
end
-- curseur et destruction
_G.GetCursorInfo = function()
	local c = Mock.world.cursor
	if c then return "item", c.itemID end
	return nil
end
_G.ClearCursor = function() Mock.world.cursor = nil end
C_Container.PickupContainerItem = function(bag, slot)
	local b = Mock.world.bags[bag]
	local item = b and b.items[slot]
	if item and not Mock.world.cursor then Mock.world.cursor = { bag = bag, slot = slot, itemID = item.itemID } end
end
_G.DeleteCursorItem = function()
	local c = Mock.world.cursor
	if not c then return end
	Mock.world.bags[c.bag].items[c.slot] = nil
	Mock.world.deleted = Mock.world.deleted or {}
	Mock.world.deleted[#Mock.world.deleted + 1] = c.bag .. ":" .. c.slot .. ":" .. c.itemID
	Mock.world.cursor = nil
end
_G.StaticPopupDialogs = {}
_G.StaticPopup_Show = function(which, a1, a2, data)
	local dialog = { which = which, text_arg1 = a1, text_arg2 = a2, data = data }
	Mock.world.popup = dialog
	return dialog
end
_G.InCombatLockdown = function() return Mock.world.combat == true end
_G.ERR_INV_FULL = "L'inventaire est plein."
_G.ERR_BAG_FULL = "Ce sac est plein."
_G.LE_GAME_ERR_INV_FULL = 51
_G.GetNumLootItems = function() return #(Mock.world.loot or {}) end
_G.GetLootSlotLink = function(i) return (Mock.world.loot or {})[i] end
_G.LootSlotHasItem = function(i) return (Mock.world.loot or {})[i] ~= nil end

function B.Link(id)
	local d = Mock.world.itemInfo[id] or {}
	return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. tostring(d.name or id) .. "]|h|r"
end

-- Identifiants propres au fichier : Checks.lua met en cache la classe des
-- objets par identifiant, pour toute la session de test
local GREY, WHITE, CLOTH, QUEST, FOOD, SHARD, HEARTH, NEWLOOT = 880001, 880006, 880002, 880003, 880004, 6265, 6948, 880099

function B.Reset()
	ResetWorld()
	if NS.bagspaceFrame then NS.bagspaceFrame:Hide() end
	NS.bagspace, NS.bagspaceChatAt, NS.bagspacePending = nil, nil, nil
	NS.inSafe = false
	Mock.world.itemInfo = {
		[GREY]   = { name = "Os brisé", classID = 15, quality = 0, sellPrice = 5 },
		[WHITE]  = { name = "Caillou", classID = 7, quality = 1, sellPrice = 5 },
		[CLOTH]  = { name = "Étoffe", classID = 7, quality = 1, sellPrice = 10 },
		[QUEST]  = { name = "Crâne de quête", classID = 12, quality = 1, sellPrice = 0 },
		[FOOD]   = { name = "Pain", classID = 0, subClassID = 5, quality = 1, sellPrice = 1 },
		[SHARD]  = { name = "Fragment d'âme", classID = 15, quality = 1, sellPrice = 0 },
		[HEARTH] = { name = "Pierre de foyer", classID = 15, quality = 1, sellPrice = 0 },
		[NEWLOOT] = { name = "Butin neuf", classID = 7, quality = 1, sellPrice = 3, maxStack = 20 },
	}
	local function Item(id, count, extra)
		local d = Mock.world.itemInfo[id]
		local item = { itemID = id, stackCount = count or 1, quality = d.quality, hyperlink = B.Link(id) }
		for k, v in pairs(extra or {}) do item[k] = v end
		return item
	end
	-- sac plein : 7 emplacements, 7 objets
	Mock.world.bags[0] = { size = 7, items = {
		[1] = Item(CLOTH, 3),
		[2] = Item(QUEST, 1, { hasNoValue = true }),
		[3] = Item(HEARTH, 1, { hasNoValue = true }),
		[4] = Item(WHITE, 1),
		[5] = Item(FOOD, 2),
		[6] = Item(SHARD, 1, { hasNoValue = true }),
		[7] = Item(GREY, 1),
	} }
	Mock.world.classToken = "WARLOCK"
	Mock.world.level = 20
	StaticPopupDialogs = {}
end

function B.Output() return Mock:Output() end
function B.Has(needle) return tostring(Mock:Output()):find(needle, 1, true) ~= nil end
function B.First() local c = NS:BagSpaceCandidates()[1]; return c and c.itemID end
function B.Shown() return NS.bagspaceFrame ~= nil and NS.bagspaceFrame:IsShown() end
function B.Full() Mock:Fire("UI_ERROR_MESSAGE", 51, "L'inventaire est plein.") end
function B.Ids()
	local ids = {}
	for _, c in ipairs(NS:BagSpaceCandidates()) do ids[#ids + 1] = c.itemID end
	return table.concat(ids, ",")
end

-- 1. Chaînes ------------------------------------------------------------------
do
	local strings = NS.BAGSPACE_STRINGS
	local missing = {}
	for key, value in pairs(strings.fr) do
		if type(strings.en[key]) ~= "string" or strings.en[key] == "" or value == "" then missing[#missing + 1] = key end
	end
	for key in pairs(strings.en) do if strings.fr[key] == nil then missing[#missing + 1] = key end end
	Check("[BAG] chaînes fr + en complètes, client fr en français", #missing == 0 and NS.L.BAG_BTN_DESTROY == "Jeter"
		and strings.en.BAG_BTN_KEEP == "Favorite", table.concat(missing, ","))
end

-- 2. Choix : le moins coûteux par emplacement, exclusions ---------------------
do
	B.Reset()
	Check("[BAG] gris à 5 pc avant blanc à 5 pc (égalité)", B.First() == GREY, B.Ids())
	local ids = "," .. B.Ids() .. ","
	local bad = {}
	for _, id in ipairs({ QUEST, HEARTH, SHARD, FOOD }) do
		if ids:find("," .. id .. ",", 1, true) then bad[#bad + 1] = id end
	end
	Check("[BAG] protégés : quête, foyer, fragments du démoniste, dernière nourriture", #bad == 0, ids)
	Check("[BAG] pile de 3 à 10 pc = 30 pc, en dernier", NS:BagSpaceCandidates()[3].itemID == CLOTH
		and NS:BagSpaceCandidates()[3].value == 30, B.Ids())

	NS:DB().vivresThreshold = 0
	Check("[BAG] seuil des vivres à 0 : la nourriture (2 pc) passe en tête", B.First() == FOOD, B.Ids())

	B.Reset()
	Mock.world.classToken = "WARRIOR"
	Check("[BAG] guerrier : le fragment (sans valeur) est proposé", B.First() == SHARD, B.Ids())

	B.Reset()
	Mock.world.itemInfo[WHITE].sellPrice = nil
	Check("[BAG] prix inconnu : jamais proposé", not ("," .. B.Ids() .. ","):find("," .. WHITE .. ",", 1, true), B.Ids())

	B.Reset()
	NS:DB().favorites[GREY] = "Os brisé"
	Check("[BAG] liste « toujours garder » respectée", B.First() == WHITE, B.Ids())
	NS:DB().bagspaceDiscard[CLOTH] = "Étoffe"
	Check("[BAG] liste « toujours jeter » en premier, même plus chère", B.First() == CLOTH, B.Ids())
end

-- 3. Déclenchement --------------------------------------------------------------
do
	B.Reset()
	Mock:Fire("UI_ERROR_MESSAGE", 51, "L'inventaire est plein.")
	Check("[BAG] erreur (type, message) : cadre « Sac plein — jette » affiché", B.Shown()
		and NS.bagspaceFrame.text.text:find("Sac plein — jette : ", 1, true) ~= nil
		and NS.bagspaceFrame.text.text:find("[Os brisé]", 1, true) ~= nil and NS.bagspaceFrame.text.text:find("×1 (5 pc)", 1, true) ~= nil,
		NS.bagspaceFrame and NS.bagspaceFrame.text.text)

	-- formes de l'erreur : message seul (anciens clients), numéro seul
	local shown = {}
	B.Reset(); Mock:Fire("UI_ERROR_MESSAGE", "L'inventaire est plein."); shown[1] = B.Shown()
	B.Reset(); Mock:Fire("UI_ERROR_MESSAGE", 51, ""); shown[2] = B.Shown()
	Check("[BAG] erreur reconnue à son message seul ou à son numéro seul", shown[1] and shown[2])

	B.Reset()
	Mock:Fire("UI_ERROR_MESSAGE", 3, "Pas assez de mana")
	Check("[BAG] autre erreur : rien", not B.Shown() and B.Output() == "", B.Output())

	B.Reset()
	Mock.world.bags[0].size = 8
	B.Full()
	Check("[BAG] une place libre : rien", not B.Shown())

	B.Reset()
	-- sac d'âmes avec de la place : il ne reçoit pas le butin ordinaire
	C_Container.GetContainerNumFreeSlots = function(bag)
		if bag == 1 then return 4, 8 end
		return saved.GetContainerNumFreeSlots(bag)
	end
	B.Full()
	Check("[BAG] places libres d'un sac spécialisé ignorées", B.Shown())
	C_Container.GetContainerNumFreeSlots = saved.GetContainerNumFreeSlots

	B.Reset()
	NS.inSafe = true
	B.Full()
	Check("[BAG] en zone sûre : rien (on vend)", not B.Shown())

	B.Reset()
	Mock.world.loot = { B.Link(NEWLOOT) }
	NS:DB().lootroomEnabled = false
	Mock:Fire("LOOT_OPENED")
	Check("[BAG] butin qui ne rentre pas, « Place au butin » coupé : cadre affiché", B.Shown())
	NS:DB().lootroomEnabled = true
	B.Reset()
	Mock.world.loot = { B.Link(NEWLOOT) }
	Mock:Fire("LOOT_OPENED")
	Check("[BAG] butin qui ne rentre pas : « Place au butin » prend le relais", not B.Shown()
		and NS.lootRoomFrame and NS.lootRoomFrame:IsShown())
	NS.lootRoomFrame:Hide()

	B.Reset()
	Mock.world.loot = { B.Link(CLOTH) }   -- pile de 3 sur 20 : il rentre
	Mock:Fire("LOOT_OPENED")
	Check("[BAG] butin qui complète une pile : rien", not B.Shown())

	B.Reset()
	B.Full()
	Mock.world.bags[0].items[4] = nil
	Mock:Fire("BAG_UPDATE", 0)
	Check("[BAG] une place se libère : le cadre se ferme", not B.Shown())
end

-- 4. [Autre], [Garder toujours] -------------------------------------------------
do
	B.Reset()
	B.Full()
	local first = NS:BagSpaceCurrent().itemID
	NS.bagspaceFrame.nextButton:Click()
	Check("[BAG] [Autre] : candidat suivant, le cadre suit", first == GREY and NS:BagSpaceCurrent().itemID == WHITE
		and NS.bagspaceFrame.text.text:find("[Caillou]", 1, true) ~= nil, NS.bagspaceFrame.text.text)
	NS.bagspaceFrame.nextButton:Click()
	NS.bagspaceFrame.nextButton:Click()
	Check("[BAG] [Autre] : retour au premier après le dernier", NS:BagSpaceCurrent().itemID == GREY)
	NS.bagspaceFrame.nextButton:Click()
	B.Full()
	Check("[BAG] nouvelle erreur : le choix [Autre] est conservé", NS:BagSpaceCurrent().itemID == WHITE)

	NS.bagspaceFrame.keepButton:Click()
	Check("[BAG] [Favori] : ajouté aux favoris, plus proposé", NS:DB().favorites[WHITE] == "Caillou"
		and NS:BagSpaceCurrent().itemID == GREY and not ("," .. B.Ids() .. ","):find("," .. WHITE .. ",", 1, true))
end

-- 5. [Jeter] : confirmation obligatoire ----------------------------------------
do
	B.Reset()
	B.Full()
	NS.bagspaceFrame.nextButton:Click()                 -- le blanc, sac 0 case 4
	NS.bagspaceFrame.destroyButton:Click()
	local popup = Mock.world.popup
	local def = StaticPopupDialogs["READY2QUEST_BAGSPACE_DESTROY"]
	Check("[BAG] [Jeter] : confirmation qui nomme l'objet, rien détruit avant", popup and popup.which == "READY2QUEST_BAGSPACE_DESTROY"
		and tostring(popup.text_arg1):find("[Caillou]", 1, true) ~= nil and popup.text_arg2 == 1
		and Mock.world.deleted == nil and Mock.world.bags[0].items[4] ~= nil)
	Check("[BAG] popup déclarée, texte et boutons traduits", def and def.text:find("Détruire", 1, true) and def.button1 == "Détruire"
		and def.button2 == "Annuler" and def.timeout == 0)

	def.OnCancel(popup, popup.data)
	Check("[BAG] annuler : rien détruit", Mock.world.deleted == nil and Mock.world.bags[0].items[4] ~= nil)

	NS.bagspaceFrame.destroyButton:Click()
	popup = Mock.world.popup
	def.OnAccept(popup, popup.data)
	Check("[BAG] confirmé : un seul objet, le bon sac et la bonne case", Mock.world.deleted and #Mock.world.deleted == 1
		and Mock.world.deleted[1] == "0:4:" .. WHITE, Mock.world.deleted and table.concat(Mock.world.deleted, ","))
	Check("[BAG] confirmé : message dans le chat, cadre fermé", B.Has("Détruit : ") and not B.Shown())

	-- l'objet bouge entre le clic et la confirmation
	B.Reset()
	B.Full()
	NS.bagspaceFrame.destroyButton:Click()
	popup = Mock.world.popup
	Mock.world.bags[0].items[7] = { itemID = CLOTH, stackCount = 5, quality = 1, hyperlink = B.Link(CLOTH) }
	StaticPopupDialogs["READY2QUEST_BAGSPACE_DESTROY"].OnAccept(popup, popup.data)
	Check("[BAG] objet déplacé avant confirmation : rien détruit, le joueur est prévenu", Mock.world.deleted == nil
		and Mock.world.bags[0].items[7].itemID == CLOTH and B.Has("rien n'a été détruit"))

	-- même objet, mais la pile a changé (fusion) : ce n'est plus ce qui a été confirmé
	B.Reset()
	B.Full()
	NS.bagspaceFrame.destroyButton:Click()
	popup = Mock.world.popup
	Mock.world.bags[0].items[7].stackCount = 4
	StaticPopupDialogs["READY2QUEST_BAGSPACE_DESTROY"].OnAccept(popup, popup.data)
	Check("[BAG] pile modifiée avant confirmation : rien détruit", Mock.world.deleted == nil)

	-- curseur déjà occupé : vidé, puis on prend le bon objet
	B.Reset()
	B.Full()
	NS.bagspaceFrame.destroyButton:Click()
	popup = Mock.world.popup
	Mock.world.cursor = { bag = 0, slot = 1, itemID = CLOTH }
	StaticPopupDialogs["READY2QUEST_BAGSPACE_DESTROY"].OnAccept(popup, popup.data)
	Check("[BAG] curseur occupé : vidé, c'est le gris qui part", Mock.world.deleted and Mock.world.deleted[1] == "0:7:" .. GREY
		and Mock.world.bags[0].items[1] ~= nil)

	-- l'API de destruction manque : suggestion dans le chat seulement
	B.Reset()
	B.Full()
	local delete = DeleteCursorItem
	DeleteCursorItem = nil
	Mock.world.popup = nil
	NS.bagspaceFrame.destroyButton:Click()
	Check("[BAG] API absente : rien détruit, à jeter à la main (sac 1, case 7)", Mock.world.popup == nil
		and Mock.world.bags[0].items[7] ~= nil and B.Has("à la main") and B.Has("sac 1, case 7"), B.Output())
	DeleteCursorItem = delete
end

-- 6. Combat, chat seul ----------------------------------------------------------
do
	B.Reset()
	Mock.world.combat = true
	B.Full()
	Check("[BAG] combat : pas de cadre, suggestion dans le chat", not B.Shown() and B.Has("Sac plein — jette : ")
		and B.Has("[Os brisé]"), B.Output())
	Mock:Reset()
	B.Full()
	Check("[BAG] chat : pas de répétition à chaque erreur", B.Output() == "", B.Output())

	-- cadre ouvert, puis le combat commence : [Jeter] ne fait que conseiller
	B.Reset()
	B.Full()
	Mock.world.combat = true
	Mock.world.popup = nil
	NS.bagspaceFrame.destroyButton:Click()
	Check("[BAG] [Jeter] en combat : ni confirmation ni destruction, conseil", Mock.world.popup == nil
		and Mock.world.deleted == nil and B.Has("En combat"), B.Output())
	-- confirmation ouverte avant le combat, acceptée pendant
	Mock.world.combat = false
	NS.bagspaceFrame.destroyButton:Click()
	local popup = Mock.world.popup
	Mock.world.combat = true
	StaticPopupDialogs["READY2QUEST_BAGSPACE_DESTROY"].OnAccept(popup, popup.data)
	Check("[BAG] confirmation acceptée en combat : rien détruit", Mock.world.deleted == nil)

	B.Reset()
	NS:DB().bagspaceFrame = false
	B.Full()
	Check("[BAG] cadre coupé : chat seul", not B.Shown() and B.Has("[Os brisé]"), B.Output())
end

-- 7. Commandes ------------------------------------------------------------------
do
	B.Reset()
	NS:HandleCommand("jeter")
	local jeter = B.Has("Le moins coûteux à jeter : ") and B.Has("[Os brisé]") and B.Has("Places libres : 0")
	Mock:Reset()
	NS:HandleCommand("sac")
	Check("[BAG] /r2q jeter et /r2q sac : suggestion, rien détruit", jeter and B.Has("[Os brisé]") and Mock.world.deleted == nil,
		B.Output())

	NS:HandleCommand("garder " .. B.Link(GREY))
	local added = NS:DB().favorites[GREY] == "Os brisé"
	NS:HandleCommand("garder " .. B.Link(GREY))
	Check("[BAG] /r2q garder [lien] : ajouté, puis retiré une 2e fois", added and NS:DB().favorites[GREY] == nil)
	NS:HandleCommand("jeter-toujours " .. B.Link(CLOTH))
	added = NS:DB().bagspaceDiscard[CLOTH] == "Étoffe"
	NS:HandleCommand("garder " .. B.Link(CLOTH))
	Check("[BAG] /r2q jeter-toujours [lien] ; garder le retire de « toujours jeter »", added
		and NS:DB().favorites[CLOTH] ~= nil and NS:DB().bagspaceDiscard[CLOTH] == nil)
	Mock:Reset()
	NS:HandleCommand("garder")
	Check("[BAG] /r2q garder sans objet : aide", B.Has("Indique un objet"), B.Output())

	Mock:Reset()
	NS:HandleCommand("modules")
	local listed = B.Has("bagspace")
	NS:HandleCommand("module sac off")
	Mock:Reset()
	NS:HandleCommand("jeter")
	Check("[BAG] /r2q modules liste le module, « module sac off » le coupe, la commande le dit", listed
		and NS:DB().bagspaceEnabled == false and B.Has("coupé"), B.Output())
	Check("[BAG] aide : la commande est listée", (function()
		for _, section in ipairs(NS.HELP) do
			for _, key in ipairs(section[2]) do if key == "HELP_BAGSPACE" then return true end end
		end
		return false
	end)())
end

-- 8. Module coupé : rien --------------------------------------------------------
do
	B.Reset()
	NS:DB().bagspaceEnabled = false
	B.Full()
	Mock.world.loot = { B.Link(NEWLOOT) }
	Mock:Fire("LOOT_OPENED")
	Check("[BAG] module coupé : ni cadre ni chat, l'alerte directe ne fait rien", not B.Shown() and B.Output() == ""
		and NS:BagSpaceAlert() == nil and not B.Shown(), B.Output())
	B.Reset()
	NS:DB().enabled = false
	B.Full()
	Check("[BAG] addon coupé : rien", not B.Shown() and B.Output() == "")
end

-- 9. Page de réglages -----------------------------------------------------------
do
	B.Reset()
	NS:DB().favorites[GREY] = "Os brisé"
	NS.optionsFrame = nil
	NS:ToggleOptions()
	local frame = NS.optionsFrame
	local def
	for _, d in ipairs(NS.OPTION_PAGES) do if d.id == "bagspace" then def = d end end
	local page = frame.pages.bagspace
	local notes = page and page.notes or {}
	Check("[BAG] page : sous-page du QoL, listes affichées", def and def.parent == "qol" and def.group == "OPT_GROUP_QOL"
		and notes.favorites ~= nil and notes.favorites.text.text:find("Os brisé", 1, true) ~= nil
		and notes.bagspaceDiscard.text.text:find("(vide)", 1, true) ~= nil
		and notes.bagspaceConfirm.text.text:find("toujours", 1, true) ~= nil)
	NS:DB().favorites[GREY] = true
	Check("[BAG] page : ancienne entrée `true` affichée par son nom", NS:BagSpaceListText("favorites"):find("true", 1, true) == nil, NS:BagSpaceListText("favorites"))
	NS:DB().favorites[GREY] = "Os brisé"
	NS:HandleCommand("jeter-toujours " .. B.Link(CLOTH))
	Check("[BAG] page : rafraîchie après une commande", notes.bagspaceDiscard.text.text:find("Étoffe", 1, true) ~= nil)
	NS:SelectOptionsPage("bagspace")
	for _ = 1, 10 do NS:ScrollOptions(-1) end
	Check("[BAG] page : l'aide du bas se voit (défilement)", notes.bagspaceHint:IsShown() == true)
	local sections = 0
	for _, item in ipairs(page.items) do if item.kind == "section" then sections = sections + 1 end end
	local rowKeys = {}
	for _, row in ipairs(page.rows) do rowKeys[#rowKeys + 1] = row.def and row.def.key end
	Check("[BAG] page : trois sections, interrupteurs module et cadre, raccourci des favoris", sections == 3
		and table.concat(rowKeys, ",") == "bagspaceEnabled,bagspaceFrame,favoriteClick,favoriteAutoBuyback", sections .. " " .. table.concat(rowKeys, ","))
	frame:Hide()
	NS.optionsFrame = nil
end

-- restauration des globales
C_Item.GetItemInfo = saved.CItemGetItemInfo
C_Container.PickupContainerItem = saved.PickupContainerItem
C_Container.GetContainerNumFreeSlots = saved.GetContainerNumFreeSlots
for name, entry in pairs(savedG) do _G[name] = entry.value end
if NS.bagspaceFrame then NS.bagspaceFrame:Hide() end
Mock.world.classToken = nil
