-- API récentes, exploitées seulement quand le client les expose (lot 2) :
--   * fiche d'objet sûre (socle, ns.ItemInfo) : C_Item.GetItemInfo puis la
--     globale, demande de chargement et rappel quand l'objet arrive ;
--   * tranche de niveaux des zones selon le jeu (C_Map.GetMapLevels, socle
--     ns:MapLevelRange, QC ns:ZoneLevelRange) ;
--   * niveaux des donjons selon le jeu (GetLFGDungeonInfo, socle
--     ns:DungeonLfgRange / ns:DungeonRange) ;
--   * quêtes proposées sur la carte (C_QuestLine, C_TaskQuest : QC
--     ns:ZoneLiveQuests et l'onglet Quêtes du carnet).
-- Chaque fois : l'API présente l'emporte sur les tables ; absente, en erreur,
-- vide, à zéro ou secrète, le repli est exactement l'ancien comportement.
local Check, Say, ResetWorld, NS, QNS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.QNS, T.Mock

local L2 = { saved = {}, globals = { "GetItemInfo", "Item", "issecretvalue", "GetLFGDungeonInfo",
	"GetMaxLevelForPlayerExpansion", "C_QuestLine", "C_TaskQuest" } }
for _, name in ipairs(L2.globals) do L2.saved[name] = rawget(_G, name) end
L2.saved.cItem = {}
for key, value in pairs(C_Item) do L2.saved.cItem[key] = value end
L2.saved.GetMapLevels = C_Map.GetMapLevels
L2.saved.Flagged = C_QuestLog.IsQuestFlaggedCompleted
L2.saved.GetTitle = C_QuestLog.GetTitleForQuestID
L2.saved.ZONE_QUESTS = rawget(QNS, "ZONE_QUESTS")

local SECRET = {}
_G.issecretvalue = function(value) return value == SECRET end
local unpack = unpack or table.unpack

-- ---------------------------------------------------------------------------
-- 1. Fiche d'objet sûre (ns.ItemInfo)
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes (lot 2) : fiche d'objet sûre")
	ResetWorld()
	Check("[ITEM] ns.ItemInfo dans les deux socles", type(NS.ItemInfo) == "function" and type(QNS.ItemInfo) == "function")

	-- 13 retours, dont des nil au milieu : tous rendus, sans troncature
	local FULL = { n = 13, "Épée", "|cff1eff00|Hitem:42|h[Épée]|h|r", 2, 20, 15, "Arme", "Épées", 1, "INVTYPE_WEAPON",
		"Interface\\Icons\\Sword", 1234, nil, 7 }
	local W = { cCalls = 0, gCalls = 0, requested = {} }
	C_Item.GetItemInfo = function(item)
		W.cCalls = W.cCalls + 1
		if item == 42 or item == FULL[2] then return unpack(FULL, 1, FULL.n) end
		return nil
	end
	_G.GetItemInfo = function(item)
		W.gCalls = W.gCalls + 1
		if item == 77 then return "Globale", nil, 3 end
		return nil
	end
	local r = { n = select("#", NS.ItemInfo(42)), NS.ItemInfo(42) }
	Check("[ITEM] C_Item d'abord, 13 retours intacts", r.n == 13 and r[1] == "Épée" and r[11] == 1234
		and r[12] == nil and r[13] == 7 and W.gCalls == 0, tostring(r.n))
	Check("[ITEM] un lien marche aussi", (NS.ItemInfo(FULL[2])) == "Épée")
	C_Item.GetItemInfo = nil
	local name, _, quality = NS.ItemInfo(77)
	Check("[ITEM] sans C_Item.GetItemInfo : la globale", name == "Globale" and quality == 3 and W.gCalls == 1)
	_G.GetItemInfo = nil
	local ok, none = pcall(NS.ItemInfo, 77)
	Check("[ITEM] ni l'une ni l'autre : nil, sans erreur", ok and none == nil)
	C_Item.GetItemInfo = function() error("item API refused") end
	ok, none = pcall(NS.ItemInfo, 42)
	Check("[ITEM] API en erreur : nil, sans erreur", ok and none == nil)
	ok, none = pcall(NS.ItemInfo, nil)
	Check("[ITEM] objet nil : nil", ok and none == nil)

	-- pas encore en cache : demande de chargement, rappel une fois chargé
	C_Item.GetItemInfo = function(item) if W.loaded then return "Chargé" end return nil end
	C_Item.RequestLoadItemDataByID = function(id) W.requested[#W.requested + 1] = id end
	local pending = {}
	_G.Item = { CreateFromItemID = function(_, id)
		return { ContinueOnItemLoad = function(_, cb) pending[#pending + 1] = { id = id, cb = cb } end }
	end }
	Check("[ITEM] pas en cache : nil", NS.ItemInfo("|cffffffff|Hitem:555::::|h[x]|h|r") == nil)
	Check("[ITEM] pas en cache : chargement demandé (id tiré du lien)", W.requested[1] == 555, tostring(W.requested[1]))
	Check("[ITEM] sans rappel : pas d'attente", #pending == 0)
	-- rafraîchissements répétés : une demande au serveur, pas une par appel
	local asked = #W.requested
	NS.ItemInfo(555); NS.ItemInfo(555)
	Check("[ITEM] demandes répétées : pas de relance immédiate", #W.requested == asked)
	Mock.now = Mock.now + 6
	NS.ItemInfo(555)
	Check("[ITEM] demandes répétées : relance après quelques secondes", #W.requested == asked + 1)
	local hits = 0
	local function OnLoad() hits = hits + 1 end
	NS.ItemInfo(556, OnLoad)
	NS.ItemInfo(556, OnLoad)
	Check("[ITEM] avec rappel : une seule attente par objet", #pending == 1 and pending[1].id == 556)
	W.loaded = true
	pending[1].cb()
	Check("[ITEM] objet chargé : rappel une fois", hits == 1 and NS.itemWaits[556] == nil)
	Check("[ITEM] objet chargé : la fiche répond", NS.ItemInfo(556) == "Chargé")
	-- Item sans ContinueOnItemLoad, ou en erreur : rien ne casse
	W.loaded = false
	_G.Item = { CreateFromItemID = function() error("no item mixin") end }
	ok = pcall(NS.ItemInfo, 557, OnLoad)
	Check("[ITEM] Item en erreur : sans plantage, pas d'attente", ok and NS.itemWaits[557] == nil)
	_G.Item, C_Item.RequestLoadItemDataByID = nil, nil
	ok = pcall(NS.ItemInfo, 558, OnLoad)
	Check("[ITEM] sans API de chargement : sans plantage", ok)

	-- les appelants : C_Item d'abord, la globale en repli, mêmes résultats
	for key, value in pairs(L2.saved.cItem) do C_Item[key] = value end
	_G.GetItemInfo = L2.saved.GetItemInfo
	Mock.world.links = Mock.world.links or {}
	Mock.world.links["item:900"] = { name = "Heaume", quality = 3, itemLevel = 25, equipLoc = "INVTYPE_HEAD", texture = "T900" }
	local data = NS.ItemData("item:900")
	Check("[ITEM] Equip : notice par C_Item", data and data.name == "Heaume" and data.quality == 3 and data.texture == "T900")
	local cInfo = C_Item.GetItemInfo
	C_Item.GetItemInfo = nil
	_G.GetItemInfo = cInfo   -- celle du mock passe par C_Item : une vraie globale
	data = NS.ItemData("item:900")
	Check("[ITEM] Equip : sans C_Item, par la globale", data and data.itemLevel == 25)
	C_Item.GetItemInfo, _G.GetItemInfo = cInfo, L2.saved.GetItemInfo

	-- plus aucun appel direct à GetItemInfo hors du socle (Compat.lua)
	local direct = {}
	local root = rawget(_G, "ADDON_ROOT") or "."
	for _, file in ipairs(_G.TOC_FILES or {}) do
		if not file:find("/Libs/Socle/Compat%.lua$") then
			local handle = io.open(root .. "/" .. file, "r")
			if handle then
				local number = 0
				for line in handle:lines() do
					number = number + 1
					local code = line:gsub("%-%-.*$", "")
					local at = code:find("GetItemInfo", 1, true)
					while at do
						if code:sub(at + 11, at + 17) ~= "Instant" then direct[#direct + 1] = file .. ":" .. number; break end
						at = code:find("GetItemInfo", at + 1, true)
					end
				end
				handle:close()
			end
		end
	end
	Check("[ITEM] tous les appels passent par ns.ItemInfo", #direct == 0 and #(_G.TOC_FILES or {}) > 0,
		table.concat(direct, ", "))
end

-- ---------------------------------------------------------------------------
-- 2. Tranche de niveaux des zones (C_Map.GetMapLevels)
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes (lot 2) : niveaux des zones")
	ResetWorld()
	local function Forget() for _, ns in ipairs({ NS, QNS }) do for k in pairs(ns.mapLevelCache) do ns.mapLevelCache[k] = nil end end end
	local function Same(range, a, b) return type(range) == "table" and range[1] == a and range[2] == b end

	C_Map.GetMapLevels = nil
	Forget()
	Check("[ZLVL] sans l'API : pas de tranche du jeu", NS:MapLevelRange(1413) == nil)
	Check("[ZLVL] sans l'API : la table (Les Tarides 10-25)", Same(QNS:ZoneLevelRange(1413), 10, 25))
	local unknown = QNS:ZoneLevelRange(424242)
	Check("[ZLVL] sans l'API : zone inconnue, rien", unknown == nil)

	local W = { calls = 0, levels = {} }
	C_Map.GetMapLevels = function(mapID)
		W.calls = W.calls + 1
		if W.error then error("map levels refused") end
		local v = W.levels[mapID]
		if v then return v[1], v[2], 0, 0 end
		return nil
	end
	W.levels[1413] = { 12, 22 }
	W.levels[424242] = { 30, 35 }
	Forget()
	Check("[ZLVL] avec l'API : la table établie l'emporte sur le jeu", Same(QNS:ZoneLevelRange(1413), 10, 25))
	Check("[ZLVL] avec l'API : zone absente des tables", Same(QNS:ZoneLevelRange(424242), 30, 35))
	local before = W.calls
	QNS:ZoneLevelRange(424242); QNS:ZoneLevelRange(424242); QNS:MapLevelRange(424242)
	Check("[ZLVL] mise en cache par carte", W.calls == before)
	Check("[ZLVL] R2Q : même source (socle)", Same(NS:MapLevelRange(1413), 12, 22))
	-- réponse vide : pas mise en cache, redemandée ensuite
	W.levels[515151] = nil
	Check("[ZLVL] réponse vide : rien", NS:MapLevelRange(515151) == nil)
	W.levels[515151] = { 40, 45 }
	Check("[ZLVL] réponse vide : redemandée plus tard", Same(NS:MapLevelRange(515151), 40, 45))
	Check("[ZLVL] palier d'après le jeu", QNS:ZoneTier(424242) == 2)

	-- valeurs inexploitables : la table, comme avant
	for label, value in pairs({ ["0/0"] = { 0, 0 }, ["secrètes"] = { SECRET, SECRET }, ["incohérentes"] = { 20, 10 },
		["non numériques"] = { "a", "b" } }) do
		W.levels[1413] = value
		Forget()
		Check("[ZLVL] " .. label .. " : la table", Same(QNS:ZoneLevelRange(1413), 10, 25))
	end
	W.levels[1413] = nil
	Forget()
	Check("[ZLVL] nil : la table", Same(QNS:ZoneLevelRange(1413), 10, 25))
	W.error = true
	Forget()
	local ok, range = pcall(QNS.ZoneLevelRange, QNS, 1413)
	Check("[ZLVL] API en erreur : la table, sans plantage", ok and Same(range, 10, 25))
	C_Map.GetMapLevels = L2.saved.GetMapLevels
	Forget()
end

-- ---------------------------------------------------------------------------
-- 3. Niveaux des donjons (GetLFGDungeonInfo)
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes (lot 2) : niveaux des donjons")
	ResetWorld()
	local function Forget() NS.lfgDungeonCache.ranges, QNS.lfgDungeonCache.ranges = nil, nil end
	local D = NS.DUNGEONS
	_G.GetLFGDungeonInfo = nil
	Forget()
	local low, high = NS:DungeonRange(D.dm)
	Check("[LFG] sans l'API : DungeonData (Mortemines 17-26)", low == 17 and high == 26)
	Check("[LFG] sans l'API : verdict inchangé", NS:DungeonVerdict(D.dm, 17) == "ok")

	-- une fiche GetLFGDungeonInfo : 22 retours
	local function Row(name, typeID, minL, maxL, minRec, maxRec, mapID, extra)
		extra = extra or {}
		local r = { n = 22 }
		r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] = name, typeID, 0, minL, maxL, minRec, minRec, maxRec
		r[12] = extra.difficulty or 1
		r[15], r[18], r[22] = extra.holiday or false, extra.timewalker or false, mapID
		return r
	end
	local W = { calls = 0, rows = {} }
	W.rows[10] = Row("Les Mortemines", 1, 10, 60, 18, 23, 36)
	W.rows[11] = Row("Les Mortemines", 1, 85, 90, 85, 90, 36, { difficulty = 2 })  -- héroïque : écarté
	W.rows[20] = Row("Monastère : Cimetière", 1, 20, 60, 28, 38, 189)              -- ailes : union
	W.rows[21] = Row("Monastère : Cathédrale", 1, 20, 60, 34, 45, 189)
	W.rows[30] = Row("The Drowned City", 1, 30, 60, 36, 41, 0)                     -- sans map : par le nom
	W.rows[40] = Row("Cavernes des Lamentations", 1, 10, 60, 10, 60, 43)           -- à l'échelle : écarté
	W.rows[50] = Row("Ombrecroc", 1, 10, 60, 20, 30, 33, { holiday = true })      -- événement : écarté
	W.rows[60] = Row("Gnomeregan", 2, 10, 60, 30, 35, 90)                          -- raid : écarté
	W.rows[70] = Row("Uldaman", 1, 0, 0, 0, 0, 70)                                 -- zéros : écarté
	W.rows[80] = Row(SECRET, SECRET, SECRET, SECRET, SECRET, SECRET, SECRET)        -- secret : écarté
	W.rows[2999] = Row("Hautbrande", 1, 30, 60, 32, 48, 47)                         -- Kraal, au bout de la plage
	_G.GetMaxLevelForPlayerExpansion = function() return 60 end
	_G.GetLFGDungeonInfo = function(id)
		W.calls = W.calls + 1
		if W.error then error("lfg refused") end
		local r = W.rows[id]
		if r then return unpack(r, 1, r.n) end
		return nil
	end
	Forget()
	low, high = NS:DungeonRange(D.dm)
	Check("[LFG] avec l'API : le jeu l'emporte (Mortemines 18-23)", low == 18 and high == 23, tostring(low) .. "-" .. tostring(high))
	Check("[LFG] une seule passe, bornée", W.calls == 3000, tostring(W.calls))
	NS:DungeonRange(D.sm); NS:DungeonRange(D.dm)
	Check("[LFG] passe gardée en cache", W.calls == 3000)
	low, high = NS:DungeonRange(D.sm)
	Check("[LFG] ailes d'un même donjon : leur union", low == 28 and high == 45)
	low, high = NS:DungeonRange(D.drowned)
	Check("[LFG] donjon sans map : relié par son nom", low == 36 and high == 41)
	low, high = NS:DungeonRange(D.rfk)
	Check("[LFG] dernier id de la plage lu", low == 32 and high == 48)
	for _, case in ipairs({ { "wc", 15, 24, "tranche à l'échelle" }, { "sfk", 20, 30, "événement" },
		{ "gnomer", 29, 38, "raid" }, { "ulda", 41, 51, "zéros" }, { "brd", 52, 60, "absent" } }) do
		low, high = NS:DungeonRange(D[case[1]])
		Check("[LFG] " .. case[4] .. " : DungeonData", low == case[2] and high == case[3], tostring(low) .. "-" .. tostring(high))
	end
	Check("[LFG] verdict d'après le jeu", NS:DungeonVerdict(D.dm, 17) == "low" and NS:DungeonVerdict(D.dm, 24) == "grey")
	low = QNS:DungeonRange(D.dm)
	Check("[LFG] QC : même source (socle)", low == 18)

	-- au-dessus du niveau maximum : écarté
	W.rows[10] = Row("Les Mortemines", 1, 10, 60, 55, 65, 36)
	Forget()
	low = NS:DungeonRange(D.dm)
	Check("[LFG] au-delà du niveau maximum : DungeonData", low == 17)

	-- rien d'exploitable : DungeonData, nouvel essai au plus toutes les minutes
	local rows = W.rows
	W.rows = {}
	Forget()
	low = NS:DungeonRange(D.dm)
	Check("[LFG] l'API ne rend rien : DungeonData", low == 17)
	W.rows = rows
	W.rows[10] = Row("Les Mortemines", 1, 10, 60, 18, 23, 36)
	Mock.now = Mock.now + 30
	Check("[LFG] avant une minute : pas de nouvel essai", NS:DungeonRange(D.dm) == 17)
	Mock.now = Mock.now + 31
	Check("[LFG] après une minute : nouvel essai", NS:DungeonRange(D.dm) == 18)

	-- balayages vides répétés : trois essais au plus, puis on s'arrête
	W.rows = {}
	Forget()
	NS.lfgDungeonCache.tries = 0
	local scans = 0
	local realInfo = _G.GetLFGDungeonInfo
	_G.GetLFGDungeonInfo = function(...) if select(1, ...) == 1 then scans = scans + 1 end return realInfo(...) end
	for _ = 1, 6 do NS:DungeonRange(D.dm); Mock.now = Mock.now + 61 end
	Check("[LFG] balayages vides : trois essais au plus", scans == 3, tostring(scans))
	_G.GetLFGDungeonInfo = realInfo
	W.rows = rows
	NS.lfgDungeonCache.tries = 0

	W.error = true
	Forget()
	local ok, value = pcall(NS.DungeonRange, NS, D.dm)
	Check("[LFG] API en erreur : DungeonData, sans plantage", ok and value == 17)
	_G.GetLFGDungeonInfo = nil
	Forget()
end

-- ---------------------------------------------------------------------------
-- 4. Quêtes proposées sur la carte (C_QuestLine, C_TaskQuest)
-- ---------------------------------------------------------------------------
do
	Say("-- API récentes (lot 2) : quêtes proposées sur la carte")
	local ZONE = 1413
	local W = { done = {}, requests = 0 }
	local function Reset()
		ResetWorld()
		Mock.world.maps[ZONE] = { mapID = ZONE, name = "Les Tarides", parentMapID = 0, mapType = 3 }
		Mock.world.mapID = ZONE
		QNS.ZONE_QUESTS = { [ZONE] = { [100] = { en = "Static A", fr = "Statique A", lvl = 10 },
			[101] = { en = "Static B", fr = "Statique B", lvl = 12 } } }
		local state = QNS.zoneQuests
		state.done, state.lists, state.live, state.requested, state.dirty = {}, {}, {}, {}, false
		QNS:DB().companionEnabled, QNS:DB().enabled = nil, nil
		W.done, W.requests = {}, 0
	end
	C_QuestLog.IsQuestFlaggedCompleted = function(id) return W.done[id] == true end
	C_QuestLog.GetTitleForQuestID = function(id) return id == 301 and "Titre du journal" or nil end
	local function LiveHead(rows)
		for _, row in ipairs(rows) do if row.header and row.live then return row end end
		return nil
	end

	Reset()
	_G.C_QuestLine, _G.C_TaskQuest = nil, nil
	local baseline = QNS:JournalActivityRows(ZONE, "quests")
	Check("[QMAP] sans l'API : aucune quête du jeu", #QNS:ZoneLiveQuests(ZONE) == 0)
	Check("[QMAP] sans l'API : onglet Quêtes inchangé (en-tête + 2)", #baseline == 3 and LiveHead(baseline) == nil, #baseline)

	-- avec l'API
	W.lines = {
		{ questID = 100, questName = "Static A" },        -- déjà dans la table
		{ questID = 200, questName = "Nouvelle B" },
		{ questID = 201, questName = "Faite" },           -- déjà faite
		{ questID = SECRET, questName = "Secrète" },      -- secrète
		{ questID = 0, questName = "Zéro" },
		"pas une table",
	}
	W.tasks = { { questId = 300 }, { questID = 200 }, { questID = 301 } }
	W.done[201] = true
	_G.C_QuestLine = {
		RequestQuestLinesForMap = function(mapID) W.requests = W.requests + 1; W.requestedMap = mapID end,
		GetAvailableQuestLines = function(mapID)
			if W.error then error("questline refused") end
			return mapID == ZONE and W.lines or nil
		end,
	}
	_G.C_TaskQuest = {
		GetQuestsOnMap = function(mapID)
			if W.error then error("task refused") end
			return mapID == ZONE and W.tasks or nil
		end,
		GetQuestInfoByQuestID = function(id) return id == 300 and "Tâche C" or nil end,
	}
	local state = QNS.zoneQuests
	state.live, state.requested = {}, {}
	local live = QNS:ZoneLiveQuests(ZONE)
	local ids = {}
	for _, quest in ipairs(live) do ids[quest.id] = quest.name end
	Check("[QMAP] quêtes du jeu absentes de la table, pas faites", #live == 3 and ids[200] == "Nouvelle B"
		and ids[300] == "Tâche C" and ids[301] == "Titre du journal", #live)
	Check("[QMAP] ni doublon de la table, ni faite, ni secrète", ids[100] == nil and ids[201] == nil)
	Check("[QMAP] lignes demandées pour la carte, une fois", W.requests == 1 and W.requestedMap == ZONE)
	QNS:ZoneLiveQuests(ZONE)
	Check("[QMAP] liste gardée en cache", W.requests == 1 and QNS:ZoneLiveQuests(ZONE) == live)

	local rows = QNS:JournalActivityRows(ZONE, "quests")
	local head = LiveHead(rows)
	Check("[QMAP] onglet Quêtes : en-tête « sur la carte » et ses quêtes", head ~= nil and #rows == #baseline + 4
		and head.name == QNS:F("ZQ_LIVE_HEAD", 3), head and head.name)
	Check("[QMAP] la table reste la référence du compte", rows[1].name == baseline[1].name
		and QNS:ZoneQuestsPart(ZONE).need == 2)
	Check("[QMAP] marquées « sur la carte », à faire", live[1].live == true and live[1].done == false
		and live[1].detail == QNS.L.ZQ_LIVE)

	Check("[QMAP] autre onglet : jamais de quêtes du jeu", LiveHead(QNS:JournalActivityRows(ZONE, "explore")) == nil)

	-- QUESTLINE_UPDATE : relue
	W.lines[#W.lines + 1] = { questID = 202, questName = "Arrivée" }
	Mock:Fire("QUESTLINE_UPDATE")
	Check("[QMAP] QUESTLINE_UPDATE : liste relue", #QNS:ZoneLiveQuests(ZONE) == 4 and W.requests == 1)
	-- rendue : ne compte plus
	W.done[200] = true
	Mock:Fire("QUEST_TURNED_IN", 200)
	Check("[QMAP] quête rendue : retirée", #QNS:ZoneLiveQuests(ZONE) == 3)

	-- zone sans table : les quêtes du jeu quand même
	QNS.ZONE_QUESTS = nil
	state.live = {}
	Check("[QMAP] client sans table : quêtes du jeu listées", #QNS:ZoneLiveQuests(ZONE) == 4)

	-- module coupé : rien
	QNS:DB().companionEnabled = false
	state.live = {}
	Check("[QMAP] compagnon coupé : rien", #QNS:ZoneLiveQuests(ZONE) == 0)

	-- API vide, nil ou en erreur : comme sans l'API
	Reset()
	W.lines, W.tasks = {}, nil
	Check("[QMAP] API vide : rien, onglet inchangé", #QNS:ZoneLiveQuests(ZONE) == 0
		and #QNS:JournalActivityRows(ZONE, "quests") == #baseline)
	Reset()
	W.error = true
	local ok, list = pcall(QNS.ZoneLiveQuests, QNS, ZONE)
	Check("[QMAP] API en erreur : rien, sans plantage", ok and #list == 0)
	ok, rows = pcall(QNS.JournalActivityRows, QNS, ZONE, "quests")
	Check("[QMAP] API en erreur : onglet inchangé", ok and #rows == #baseline)
end

-- ---------------------------------------------------------------------------
-- Restauration
-- ---------------------------------------------------------------------------
for _, name in ipairs(L2.globals) do _G[name] = L2.saved[name] end
for key in pairs(C_Item) do C_Item[key] = nil end
for key, value in pairs(L2.saved.cItem) do C_Item[key] = value end
C_Map.GetMapLevels = L2.saved.GetMapLevels
C_QuestLog.IsQuestFlaggedCompleted, C_QuestLog.GetTitleForQuestID = L2.saved.Flagged, L2.saved.GetTitle
QNS.ZONE_QUESTS = L2.saved.ZONE_QUESTS
QNS.zoneQuests.done, QNS.zoneQuests.lists, QNS.zoneQuests.live, QNS.zoneQuests.requested = {}, {}, {}, {}
NS.lfgDungeonCache.ranges, QNS.lfgDungeonCache.ranges = nil, nil
for _, ns in ipairs({ NS, QNS }) do for k in pairs(ns.mapLevelCache) do ns.mapLevelCache[k] = nil end end
ResetWorld()
