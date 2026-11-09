-- Ready2Quest 1.32.2 : « Place au butin » ne propose plus ce que l'on garde
-- (outils, objets de camp, composants, caisses, bandages) et défile ; buffs
-- réclamés par défaut (classe seulement) avec migration ; plus de flèche « → ».
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

local savedG = {}
for _, name in ipairs({ "GetNumLootItems", "GetLootSlotLink", "LootSlotHasItem", "GetLootSlotInfo", "LootSlot",
	"GetNumSkillLines", "GetSkillLineInfo", "UnitClass", "IsPlayerSpell", "IsSpellKnown", "GetSpellInfo", "C_Spell" }) do
	savedG[name] = { value = rawget(_G, name) }
end
local savedItemInfo = C_Item.GetItemInfo

local function Link(id)
	local d = Mock.world.itemInfo[id] or {}
	return "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. tostring(d.name or id) .. "]|h|r"
end
C_Item.GetItemInfo = function(item)
	local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)"))
	local d = Mock.world.itemInfo[id]
	if not d then return nil end
	return d.name, Link(id), d.quality or 1, 1, 1, "", "", d.maxStack or 20, nil, nil, d.sellPrice or 1
end
local skills = {}
_G.GetNumSkillLines = function() return #skills end
_G.GetSkillLineInfo = function(index)
	local s = skills[index]
	if s then return s[1], false, true, s[2] end
end
_G.GetNumLootItems = function() return #(Mock.world.loot or {}) end
_G.GetLootSlotLink = function(i) local l = (Mock.world.loot or {})[i]; return l and Link(l.id) end
_G.LootSlotHasItem = function(i) return (Mock.world.loot or {})[i] ~= nil end
_G.GetLootSlotInfo = function(i)
	local l = (Mock.world.loot or {})[i]
	if l then return "tex", Mock.world.itemInfo[l.id].name, 1, nil, 1, false, false, nil, true end
end
_G.LootSlot = function() end

local JUNK, PICK, KIT, WHEEL, ORE, WOOD, CRATE, BANDAGE, RECIPE, REAGENT, NAMEDPICK, CLOTH, LOOT =
	990001, 2901, 279981, 279944, 990005, 990006, 990007, 990008, 990009, 990010, 990011, 990012, 990099

local function Bags(list)
	local items = {}
	for slot, spec in ipairs(list) do
		items[slot] = { itemID = spec[1], stackCount = 1, quality = 1, hyperlink = Link(spec[1]), hasLoot = spec.hasLoot }
	end
	Mock.world.bags[0] = { size = #items, items = items }
end

local function Reset()
	ResetWorld()
	if NS.lootRoomFrame then NS.lootRoomFrame:Hide() end
	NS.lootRoom, NS.lootRoomPending, NS.lootRoomOffset = nil, nil, nil
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
		[CLOTH] = { name = "Étoffe de laine", classID = 7, subClassID = 5, sellPrice = 2 },
		[LOOT] = { name = "Butin", classID = 4, subClassID = 0, sellPrice = 50 },
	}
	for i = 1, 12 do Mock.world.itemInfo[991000 + i] = { name = "Babiole " .. i, classID = 15, subClassID = 0, sellPrice = i } end
	Mock.world.loot = { { id = LOOT } }
	skills = { { "Minage", 50 }, { "Forge", 40 } }
	NS:DB().bagspaceKeep, NS:DB().bagspaceDiscard = {}, {}
end

-- 1. Place au butin : objets gardés ----------------------------------------------------------
do
	Say("-- R2Q 1.32.2 : place au butin, objets gardés")
	Reset()
	Bags({ { JUNK }, { PICK }, { KIT }, { WHEEL }, { ORE }, { WOOD }, { CRATE, hasLoot = true }, { BANDAGE },
		{ RECIPE }, { REAGENT }, { NAMEDPICK }, { CLOTH } })
	local rows = NS:LootRoomRows(nil)
	local ids = {}
	for _, row in ipairs(rows) do ids[row.itemID] = true end
	Check("[1322] butin : seuls l'os et l'étoffe (métier inconnu) restent proposés", #rows == 2 and ids[JUNK] and ids[CLOTH],
		#rows)
	local ctx = NS:LootRoomKeepContext()
	local function Why(id, slot) return NS:LootRoomKeepReason({ itemID = id, bag = 0, slot = slot or 1, link = Link(id) }, ctx) end
	Check("[1322] outils : pioche (numéro et nom)", Why(PICK) == "tool" and Why(NAMEDPICK) == "tool")
	Check("[1322] camp : kit de feu et meule", Why(KIT) == "camp" and Why(WHEEL) == "camp")
	Check("[1322] artisanat d'un métier connu, composant, recette", Why(ORE) == "trade" and Why(WOOD) == "trade"
		and Why(REAGENT) == "trade" and Why(RECIPE) == "recipe")
	Check("[1322] caisse qui s'ouvre, bandage", Why(CRATE, 7) == "open" and Why(BANDAGE) == "care")
	Check("[1322] tissu sans couture ni secourisme : proposé", Why(CLOTH) == nil)
	skills = { { "Secourisme", 10 } }
	Check("[1322] … avec secourisme : gardé", Why(CLOTH) == nil and NS:LootRoomKeepReason({ itemID = CLOTH, bag = 0, slot = 12 },
		NS:LootRoomKeepContext()) == "trade")
	skills = {}
	Check("[1322] aucun métier : le bois générique est proposé", NS:LootRoomKeepReason({ itemID = WOOD, bag = 0, slot = 6 },
		NS:LootRoomKeepContext()) == nil)
	NS:DB().bagspaceDiscard[PICK] = true
	ids = {}
	for _, row in ipairs(NS:LootRoomRows(nil)) do ids[row.itemID] = true end
	Check("[1322] « toujours jeter » l'emporte", ids[PICK] == true)
	local strings, missing = NS.LOOTROOM_STRINGS, {}
	for key in pairs(strings.fr) do if not strings.en[key] then missing[#missing + 1] = key end end
	Check("[1322] textes fr et en", #missing == 0, table.concat(missing, ","))
end

-- 2. Place au butin : la liste défile -----------------------------------------------------------
do
	Say("-- R2Q 1.32.2 : place au butin, défilement")
	Reset()
	local list = {}
	for i = 1, 12 do list[i] = { 991000 + i } end
	Bags(list)
	Mock:Fire("LOOT_OPENED")
	local frame = NS.lootRoomFrame
	Check("[1322] 12 candidats, 8 lignes visibles", frame and frame:IsShown() and #NS.lootRoom.rows == 12
		and frame.rows[8].data == NS.lootRoom.rows[8] and frame.thumb:IsShown())
	Check("[1322] aide : position dans la liste", frame.hint.text:find("1 à 8 sur 12", 1, true) ~= nil, frame.hint.text)
	NS:LootRoomScroll(-1)
	Check("[1322] molette : une ligne plus bas", NS.lootRoom.offset == 1 and frame.rows[1].data == NS.lootRoom.rows[2])
	NS:LootRoomScroll(-20)
	Check("[1322] butée en bas", NS.lootRoom.offset == 4 and frame.rows[8].data.itemID == 991012)
	frame.rows[8].ignore:Click()
	Check("[1322] ignorer une ligne défilée : la bonne", type(NS:DB().bagspaceKeep[991012]) == "string" and #NS.lootRoom.rows == 11
		and NS.lootRoom.offset == 3)
	NS:LootRoomScroll(20)
	Check("[1322] butée en haut", NS.lootRoom.offset == 0)
	Mock:Fire("LOOT_CLOSED")
	NS.lootRoomOffset = 3
	Mock:Fire("LOOT_OPENED")
	Check("[1322] rouverte : en haut de la liste", NS.lootRoom.offset == 0)
	Mock:Fire("LOOT_CLOSED")
	Bags({ { 991001 }, { 991002 } })
	NS:LootRoomOpen(true)
	Check("[1322] liste courte : pas de glissière, aide normale", not frame.thumb:IsShown() and frame.hint.text == NS.L.LOOTROOM_HINT)
	frame:Hide()
end

-- 3. Buffs : réclamés par défaut, migration -----------------------------------------------------
do
	Say("-- R2Q 1.32.2 : buffs par défaut")
	ResetWorld()
	_G.UnitClass = function(unit) if unit == "player" then return "Paladin", "PALADIN", 2 end end
	_G.IsPlayerSpell = function() return false end
	_G.IsSpellKnown = function() return false end
	_G.C_Spell = nil
	_G.GetSpellInfo = function() return nil end
	local Kind = NS.BuffKind
	Check("[1322] parchemins : consommables", Kind(1, { name = "Force" }) == "consumable" and Kind(1, { name = "Agility" }) == "consumable"
		and Kind(1, { name = "Esprit" }) == "consumable" and Kind(1, { name = "Élixir de la mangouste" }) == "consumable")
	Check("[1322] postures : Fureur vertueuse, aura, sceau, aspect, forme, camouflage", Kind(1, { name = "Fureur vertueuse" }) == "toggle"
		and Kind(1, { name = "Aura de dévotion" }) == "toggle" and Kind(1, { name = "Sceau de piété" }) == "toggle"
		and Kind(1, { name = "Aspect du faucon" }) == "toggle" and Kind(1, { name = "Forme d'ours" }) == "toggle"
		and Kind(1, { name = "Stealth" }) == "toggle")
	Check("[1322] buffs de classe", Kind(1, { name = "Bénédiction de puissance" }) == "class"
		and Kind(1, { name = "Mot de pouvoir : Robustesse" }) == "class" and Kind(1, { name = "Esprit divin" }) == "class"
		and Kind(1, { name = "Feu intérieur" }) == "class")
	Check("[1322] posé par soi sans connaître le sort : objet", Kind(7, { name = "Peau de pierre", self = true }) == "consumable"
		and Kind(7, { name = "Peau de pierre" }) == "other")
	local db = NS:DB()
	db.buffsSchema = nil
	db.buffs = {
		[101] = { name = "Force", enabled = true, learned = true, chars = { [NS:CharKey()] = true } },
		[102] = { name = "Fureur vertueuse", enabled = true, learned = true },
		[103] = { name = "Bénédiction de puissance", enabled = true, learned = true, self = true },
		[104] = { name = "Mot de pouvoir : Robustesse", enabled = false, learned = true },
		[105] = { name = "Agilité", enabled = false, learned = true },
	}
	Check("[1322] migration : faite une fois", NS:MigrateBuffs(db) == true and db.buffsSchema == 2 and NS:MigrateBuffs(db) == false)
	Check("[1322] migration : « coupé » reste un choix du joueur", db.buffs[104].userSet == true and db.buffs[105].userSet == true
		and db.buffs[101].userSet == nil and db.buffs[101].enabled == nil)
	local E = NS.BuffEnabled
	Check("[1322] par défaut : seule la bénédiction est réclamée", not E(db.buffs[101], 101) and not E(db.buffs[102], 102)
		and E(db.buffs[103], 103) and not E(db.buffs[104], 104))
	_G.IsPlayerSpell = function(id) return id == 103 end
	local missing = NS:EvaluateBuffs()
	Check("[1322] avant le départ : ni « Force » ni « Fureur vertueuse »", #missing == 1 and missing[1] == "Bénédiction de puissance",
		table.concat(missing, ","))
	Check("[1322] activer un consommable (à la main)", NS:BuffToggle(101) == true and db.buffs[101].userSet == true)
	missing = NS:EvaluateBuffs()
	Check("[1322] … alors il est réclamé", #missing == 2, table.concat(missing, ","))
	Check("[1322] couper un buff de classe : retenu", NS:BuffToggle(103) == false and not E(db.buffs[103], 103))
	-- la liste des réglages : la raison d'un buff à activer
	local items = NS.OPTION_LISTS.buffs.items()
	local fury
	for _, item in ipairs(items) do if item.text == "Fureur vertueuse" then fury = item end end
	Check("[1322] réglages : raison « posture du moment »", fury and fury.value:find(NS.L.BUFF_WHY_OPTIN_TOGGLE, 1, true) ~= nil,
		fury and fury.value)
	fury.onToggle()
	Check("[1322] réglages : bascule retenue", db.buffs[102].userSet == true and E(db.buffs[102], 102))
	-- /r2q buff <n> bascule la fiche enregistrée
	local list = NS:TrackedBuffs()
	local index
	for i, entry in ipairs(list) do if entry.spellId == 104 then index = i end end
	NS:HandleCommand("buff " .. index)
	Check("[1322] /r2q buff : fiche enregistrée basculée", db.buffs[104].enabled == true and E(db.buffs[104], 104))
	missing = {}
	for _, key in ipairs({ "BUFF_WHY_OPTIN_CONSUMABLE", "BUFF_WHY_OPTIN_TOGGLE", "BUFF_WHY_OPTIN_OTHER" }) do
		if type(NS.L[key]) ~= "string" or NS.L[key] == key then missing[#missing + 1] = key end
	end
	Check("[1322] raisons fr/en", #missing == 0, table.concat(missing, ","))
	db.buffs = {}
end

-- 4. Flèche -------------------------------------------------------------------------------------
do
	Say("-- R2Q 1.32.2 : flèche")
	Check("[1322] Theme.ARROW en ASCII", NS.Theme.ARROW == "->" and T.QNS.Theme.ARROW == "->")
	Check("[1322] sorts : « niv. 18 à 20 »", NS:F("CHK_SPELLS_DETAIL", 18, 20) == "niv. 18 à 20 : à apprendre")
	local bad = {}
	for _, key in ipairs({ "CHK_SPELLS_DETAIL", "SR_LINE", "DEATH_CHAT" }) do
		if tostring(NS.L[key]):find("\226\134\146", 1, true) then bad[#bad + 1] = key end
	end
	Check("[1322] plus de « → » dans les textes affichés", #bad == 0, table.concat(bad, ","))
end

C_Item.GetItemInfo = savedItemInfo
for name, entry in pairs(savedG) do _G[name] = entry.value end
