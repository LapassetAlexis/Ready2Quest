-- World.lua -- lecture du monde du jeu (socle commun)
--
-- Ce dont Ready2Quest et QuestCompanion ont besoin tous les deux pour savoir
-- où est le joueur et ce qui lui arrive, sans dépendre l'un de l'autre :
--   * carte : ns:CurrentMap, MapInfo, MapChain, MapLevelRange, CurrentSubZone,
--     InInstance ;
--   * lieux connus (Hubs.lua) : ns:HubIndex, PlayerFaction, KnownHub ;
--   * lieux repérés par leurs PNJ de service (Places.lua) : ns:KnownPlace,
--     MapHasPlaces ;
--   * camp de Forever : ns:AtCamp ;
--   * donjons (DungeonData.lua) : ns:IsForeverClient, DungeonIndex,
--     DetectDungeon, DungeonName, DungeonRange (DungeonLfgRange d'abord) ;
--   * auras : ns.AuraByIndex ;
--   * consommables : ns.ConsumableKind (« food », « combat ») ;
--   * messages du jeu : ns:ParseCombatXP (gain d'XP), ns:ParseSelfLoot (butin).
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
-- socle 2.11.0 : corps du fichier dans une fabrique, compilée une fois quand
-- les deux addons ont le même socle (Base.lua, ns.SocleFile). Rien de propre
-- à l'addon au niveau du fichier : tout passe par ADDON et ns, ci-dessous.
local SOCLE_ADDON, SOCLE_NS = ...
;(SOCLE_NS.SocleFile or function(_, factory) return factory end)("World", function(...)
local ADDON, ns = ...

-- ===========================================================================
-- Carte et lieux
-- ===========================================================================
-- ---------------------------------------------------------------------------
-- Lecture de la carte (API non restreinte)
-- ---------------------------------------------------------------------------
function ns:CurrentMap()
	if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
	local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
	if ok and type(mapID) == "number" then return mapID end
	return nil
end

function ns:MapInfo(mapID)
	if not mapID or not (C_Map and C_Map.GetMapInfo) then return nil end
	local ok, info = pcall(C_Map.GetMapInfo, mapID)
	if ok then return info end
	return nil
end

-- Chaîne carte courante -> parents (une zone est "sûre" si elle ou un parent l'est)
-- La hiérarchie des cartes ne change pas en jeu : la chaîne est gardée par
-- carte (lue toutes les PLACE_CHECK secondes, R2Q Core.lua). Gardée seulement
-- complète (la dernière carte a ses infos) : une carte dont le client n'a pas
-- encore les infos sera relue. Chaîne partagée : ne pas la modifier.
local mapChains = {}
ns.mapChainCache = mapChains
function ns:MapChain(mapID)
	local cached = mapID and mapChains[mapID]
	if cached then return cached end
	local first = mapID
	local chain, guard, complete = {}, 0, false
	while mapID and guard < 12 do
		chain[#chain + 1] = mapID
		local info = self:MapInfo(mapID)
		local parent = info and info.parentMapID
		if not parent or parent == 0 or parent == mapID then complete = info ~= nil; break end
		mapID = parent
		guard = guard + 1
	end
	if complete and first then mapChains[first] = chain end
	return chain
end

-- Tranche de niveaux d'une carte selon le jeu (C_Map.GetMapLevels(uiMapID) :
-- playerMinLevel, playerMaxLevel, …). { bas, haut }, ou nil si l'API manque,
-- échoue ou rend des valeurs vides (nil, 0, secrètes, incohérentes) : les
-- appelants gardent alors leurs tables. Gardée en cache par carte.
local mapLevels = {}
ns.mapLevelCache = mapLevels
function ns:MapLevelRange(mapID)
	mapID = tonumber(mapID)
	if not mapID then return nil end
	if mapLevels[mapID] ~= nil then return mapLevels[mapID] or nil end
	local api = rawget(_G, "C_Map")
	if type(api) ~= "table" or type(api.GetMapLevels) ~= "function" then return nil end
	local ok, low, high = pcall(api.GetMapLevels, mapID)
	low, high = tonumber(ok and ns.Plain(low) or nil), tonumber(ok and ns.Plain(high) or nil)
	-- réponse vide (données de carte pas encore chargées ?) : pas de cache,
	-- on redemandera au prochain appel
	if not (low and high and low >= 1 and high >= low) then return nil end
	local range = { low, high }
	mapLevels[mapID] = range
	return range
end

-- Sous-zone courante : un village (Comté-de-l'Or, Long-guet…) n'a pas
-- de mapID propre, c'est une sous-zone de la carte de zone.
function ns:CurrentSubZone()
	local fn = rawget(_G, "GetSubZoneText")
	if type(fn) ~= "function" then return nil end
	local ok, text = pcall(fn)
	if ok and type(text) == "string" and text ~= "" then return text end
	return nil
end


-- ---------------------------------------------------------------------------
-- Base livrée (Hubs.lua) : capitales, villages, hubs, auberges-sous-zones.
-- Les noms sont traduits par le jeu (C_Map.GetAreaInfo), la base vaut donc
-- dans toutes les langues ; repli sur le nom anglais si l'API manque.
-- ---------------------------------------------------------------------------
function ns:HubIndex()
	if self.hubIndex then return self.hubIndex end
	local index = {}
	local getInfo = C_Map and C_Map.GetAreaInfo
	for areaID, entry in pairs(self.HUBS or {}) do
		local name
		if type(getInfo) == "function" then
			local ok, localized = pcall(getInfo, areaID)
			if ok and type(localized) == "string" and localized ~= "" then name = localized end
		end
		name = name or entry.name
		if name then
			index[name] = index[name] or {}
			table.insert(index[name], entry)
		end
	end
	self.hubIndex = index
	return index
end

function ns:PlayerFaction()
	local fn = rawget(_G, "UnitFactionGroup")
	if type(fn) ~= "function" then return nil end
	local ok, faction = pcall(fn, "player")
	if not ok then return nil end
	if faction == "Alliance" then return "A" end
	if faction == "Horde" then return "H" end
	return nil
end

local function HubFriendly(entry, faction)
	return entry.faction == "N" or faction == nil or entry.faction == faction
end

-- Lieu connu sous le joueur : capitale (nom de la zone) ou village / hub /
-- auberge (nom de la sous-zone). Renvoie l'entrée et son nom, ou nil.
-- Un lieu de l'autre faction n'est jamais sûr (Southshore pour un Horde).
function ns:KnownHub()
	local index, faction = self:HubIndex(), self:PlayerFaction()
	local subzone = self:CurrentSubZone()
	local zoneFn = rawget(_G, "GetRealZoneText") or rawget(_G, "GetZoneText")
	local zone
	if type(zoneFn) == "function" then
		local ok, text = pcall(zoneFn)
		if ok and type(text) == "string" and text ~= "" then zone = text end
	end
	-- sous-zone puis zone, sans table temporaire (appelé à chaque évaluation)
	for pass = 1, 2 do
		local name = (pass == 1 and subzone) or (pass == 2 and zone) or nil
		if name and index[name] then
			for _, entry in ipairs(index[name]) do
				-- la zone ne compte que pour une capitale (« Hurlevent »), pas pour
				-- un village homonyme de sa région
				if (name == subzone or entry.kind == "capital") then
					if HubFriendly(entry, faction) then return entry, name end
					return nil, name, true      -- connu, mais hostile
				end
			end
		end
	end
	return nil
end

-- Donjon, raid, champ de bataille : jamais une zone de départ
function ns:InInstance()
	local fn = rawget(_G, "IsInInstance")
	if type(fn) ~= "function" then return false end
	local ok, inInstance = pcall(fn)
	return ok and (inInstance == true or inInstance == 1)
end

-- Forever : le campement (feu de camp) pose l'aura « Campfire Nearby ». On la
-- lit par numéro de sort, valable dans toutes les langues. Un camp est une
-- zone de départ temporaire : on n'en apprend jamais l'emplacement.
ns.CAMP_AURAS = { 1283391 }    -- Campfire Nearby (Forever 1.60.1)
function ns:AtCamp()
	if not (C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function") then return false end
	for _, spellID in ipairs(self.CAMP_AURAS) do
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
		if ok and aura then return true end
	end
	return false
end


-- ===========================================================================
-- Lieux repérés par leurs PNJ de service (Places.lua, tools/gen_places.py)
-- ===========================================================================
-- Hubs.lua reconnaît un lieu au nom de sa sous-zone. Places.lua ajoute les
-- camps sans sous-zone à eux : un point (x, y en % de la carte de zone) et un
-- rayon en mètres, comparés à la position du joueur sur cette carte.
function ns:PlaceTable()
	local data = self.PLACE_DATA
	if type(data) ~= "table" then return nil end
	return data.forever
end

-- Position du joueur sur une carte, en % (nil en instance ou sans API)
local function PlayerPercent(mapID)
	if not (C_Map and type(C_Map.GetPlayerMapPosition) == "function") then return nil end
	local ok, position = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
	if not ok or type(position) ~= "table" then return nil end
	local x, y
	if type(position.GetXY) == "function" then
		x, y = position:GetXY()
	else
		x, y = position.x, position.y
	end
	if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return nil end
	return x * 100, y * 100
end
ns.PlayerPercent = PlayerPercent

-- Carte (ou carte parente) qui a des lieux repérés : sa liste et son échelle
function ns:PlaceMap()
	local data = self:PlaceTable()
	local mapID = data and self:CurrentMap()
	if not mapID then return nil end
	for _, id in ipairs(self:MapChain(mapID)) do
		if data.places[id] and data.scale[id] then return id, data.places[id], data.scale[id] end
	end
	return nil
end

function ns:MapHasPlaces()
	return self:PlaceMap() ~= nil
end

-- Lieu sous le joueur : renvoie le lieu { x, y, rayon, faction, services }
-- et sa carte ; ou nil, carte, true si le lieu est de l'autre faction.
function ns:KnownPlace()
	if self:InInstance() then return nil end
	local mapID, places, scale = self:PlaceMap()
	if not mapID then return nil end
	local x, y = PlayerPercent(mapID)
	if not x then return nil end
	local faction = self:PlayerFaction()
	for _, place in ipairs(places) do
		local dx, dy = (x - place[1]) * scale[1], (y - place[2]) * scale[2]
		if dx * dx + dy * dy <= place[3] * place[3] then
			if place[4] == "N" or faction == nil or place[4] == faction then return place, mapID end
			return nil, mapID, true
		end
	end
	return nil
end

-- ===========================================================================
-- Donjons
-- ===========================================================================
-- Comparaison tolérante : casse ASCII, article de tête (« The Deadmines » /
-- « Les Mortemines » face à un en-tête de journal « Mortemines »).
local function Normalize(text)
	if type(text) ~= "string" or text == "" then return nil end
	local s = ns.AsciiLower and ns.AsciiLower(text) or text:lower()
	s = s:gsub("^the ", ""):gsub("^les ", ""):gsub("^le ", ""):gsub("^la ", ""):gsub("^l'", "")
	if s == "" then return nil end
	return s
end
ns.DungeonNormalize = Normalize

local function AreaName(areaID)
	if not areaID or not (C_Map and type(C_Map.GetAreaInfo) == "function") then return nil end
	local ok, name = pcall(C_Map.GetAreaInfo, areaID)
	if ok and type(name) == "string" and name ~= "" then return name end
	return nil
end

function ns:IsForeverClient()
	return self.ClientFlavour ~= nil and self:ClientFlavour() == "Forever"
end

function ns:DungeonIndex()
	if self.dungeonIndex then return self.dungeonIndex end
	local index = { byMap = {}, byName = {}, byEntrance = {} }
	for key, entry in pairs(self.DUNGEONS or {}) do
		entry.key = key
		if entry.map then index.byMap[entry.map] = entry end
		for _, name in ipairs({ AreaName(entry.area) or false, entry.name or false }) do
			local n = name and Normalize(name)
			if n then index.byName[n] = entry end
		end
		for _, areaID in ipairs(entry.entrances or {}) do
			local n = Normalize(AreaName(areaID))
			if n then index.byEntrance[n] = entry end
		end
	end
	self.dungeonIndex = index
	return index
end

-- Nom affiché : celui du jeu (instance en cours, sinon AreaTable), puis l'anglais
function ns:DungeonName(entry, instanceName)
	return instanceName or AreaName(entry.area) or entry.name or "?"
end

-- Niveaux recommandés par le jeu (GetLFGDungeonInfo, outil de recherche de
-- groupe). Retours utiles (warcraft.wiki.gg, API_GetLFGDungeonInfo) :
-- 1 nom, 2 typeID (1 = donjon), 4/5 minLevel/maxLevel (portail), 7/8
-- minRecLevel/maxRecLevel (recommandés), 12 difficulty (normal seulement), 15 isHoliday, 18 isTimeWalker,
-- 22 lfgMapID (mapID d'instance, depuis 8.3.0). Une seule passe, paresseuse et
-- bornée (ids 1..LFG_SCAN_MAX) : chaque donjon de DungeonData est relié par son
-- mapID d'instance, ou à défaut (donjons sans map) par son nom traduit. Les
-- ailes d'un même donjon (Monastère, Hache-Tripes…) partagent le mapID : leur
-- union. Une tranche plus large que LFG_MAX_SPAN niveaux (donjon « à
-- l'échelle » du moteur récent) ou au-delà du niveau maximum est écartée :
-- DungeonData (fo) reste alors la référence.
local LFG_SCAN_MAX, LFG_MAX_SPAN, LFG_RETRY, LFG_TRIES = 3000, 20, 60, 3
local lfg = { ranges = nil, at = nil, tries = 0 }
ns.lfgDungeonCache = lfg

local function LevelCap()
	for _, name in ipairs({ "GetMaxLevelForPlayerExpansion", "GetMaxPlayerLevel" }) do
		local fn = rawget(_G, name)
		if type(fn) == "function" then
			local ok, cap = pcall(fn)
			cap = ok and tonumber(ns.Plain(cap)) or nil
			if cap and cap > 0 then return cap end
		end
	end
	return tonumber(rawget(_G, "MAX_PLAYER_LEVEL")) or nil
end

local function LfgLevels(minLevel, maxLevel, minRec, maxRec)
	for _, pair in ipairs({ { minRec, maxRec }, { minLevel, maxLevel } }) do
		local low, high = tonumber(ns.Plain(pair[1])), tonumber(ns.Plain(pair[2]))
		if low and high and low >= 1 and high >= low then return low, high end
	end
	return nil
end

local function ScanLfg(self)
	local fn = rawget(_G, "GetLFGDungeonInfo")
	if type(fn) ~= "function" then return nil end
	local byMap, byName = {}, {}
	for key, entry in pairs(self.DUNGEONS or {}) do
		if entry.map then byMap[entry.map] = key
		else
			for _, name in ipairs({ AreaName(entry.area) or false, entry.name or false }) do
				local n = name and Normalize(name)
				if n then byName[n] = key end
			end
		end
	end
	local found, cap = {}, LevelCap()
	for id = 1, LFG_SCAN_MAX do
		local ok, name, typeID, _, minLevel, maxLevel, _, minRec, maxRec, _, _, _, difficulty, _, _,
			isHoliday, _, _, isTimeWalker, _, _, _, lfgMapID = pcall(fn, id)
		difficulty = ok and tonumber(ns.Plain(difficulty)) or nil
		if ok and ns.Plain(typeID) == 1 and isHoliday ~= true and isTimeWalker ~= true
			and (difficulty == nil or difficulty <= 1) then
			local mapID = tonumber(ns.Plain(lfgMapID))
			local key = (mapID and mapID > 0 and byMap[mapID])
				or byName[Normalize(ns.Plain(name)) or ""]
			local low, high = LfgLevels(minLevel, maxLevel, minRec, maxRec)
			if key and low then
				local range = found[key]
				if range then low, high = math.min(low, range[1]), math.max(high, range[2]) end
				found[key] = { low, high }
			end
		end
	end
	for key, range in pairs(found) do
		if range[2] - range[1] > LFG_MAX_SPAN or (cap and range[2] > cap) then found[key] = nil end
	end
	return found
end

-- Tranche du jeu pour ce donjon, ou nil. Rien trouvé du tout (données de
-- recherche de groupe pas encore là ?) : nouvel essai au plus toutes les minutes.
function ns:DungeonLfgRange(entry)
	if type(entry) ~= "table" or type(rawget(_G, "GetLFGDungeonInfo")) ~= "function" then return nil end
	local now = (ns.Now and ns.Now()) or 0
	-- balayage vide : au plus LFG_TRIES essais de suite par session, espacés
	-- d'une minute (le suivi appelle ceci à chaque rafraîchissement)
	if not lfg.ranges or (next(lfg.ranges) == nil and lfg.tries < LFG_TRIES
		and now - (lfg.at or 0) >= LFG_RETRY) then
		local ok, ranges = pcall(ScanLfg, self)
		lfg.ranges, lfg.at = (ok and type(ranges) == "table") and ranges or {}, now
		-- essais vides consécutifs seulement (un balayage fructueux remet à zéro)
		lfg.tries = next(lfg.ranges) == nil and lfg.tries + 1 or 0
		if not ok and self.RecordError then self:RecordError("dungeon:lfg", ranges) end
	end
	local key = entry.key
	if not key then
		for k, e in pairs(self.DUNGEONS or {}) do if e == entry then key = k end end
	end
	local range = key and lfg.ranges[key]
	if range then return range[1], range[2] end
	return nil
end

function ns:DungeonRange(entry)
	if type(entry) ~= "table" then return nil end
	local low, high = self:DungeonLfgRange(entry)
	if low then return low, high end
	local range = entry.fo
	if type(range) ~= "table" then return nil end
	return range[1], range[2]
end


-- Donjon sous le joueur : renvoie entrée, "instance"|"entrance", nom d'instance
function ns:DetectDungeon()
	local index = self:DungeonIndex()
	if self:InInstance() then
		if type(GetInstanceInfo) ~= "function" then return nil end
		local ok, name, instanceType, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
		if not ok or instanceType ~= "party" then return nil end
		local entry = index.byMap[tonumber(instanceID) or -1] or index.byName[Normalize(name) or ""]
		if entry then return entry, "instance", (type(name) == "string" and name ~= "") and name or nil end
		return nil
	end
	local subzone = Normalize(self:CurrentSubZone())
	local entry = subzone and index.byEntrance[subzone]
	if entry then return entry, "entrance" end
	return nil
end
ns.AreaName = AreaName

-- ===========================================================================
-- Auras
-- ===========================================================================
-- Lit une aura du joueur par index. Retourne nil si l'API manque ou si la
-- valeur est secrète (restriction de type SecretWhenUnitAuraRestricted).
local function AuraByIndex(index)
	if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
		if ok then return aura end
		-- repli : l'API namespacée existe mais a refusé l'appel
	end
	if type(UnitAura) == "function" then
		-- name, icon, count, dispelType, duration, expirationTime, source,
		-- isStealable, nameplateShowPersonal, spellId : le spellId est le 10e
		local ok, name, _, _, _, duration, _, source, _, _, spellId = pcall(UnitAura, "player", index, "HELPFUL")
		if ok and name then
			return { name = name, duration = duration, spellId = spellId, sourceUnit = source }
		end
	end
	return nil
end
ns.AuraByIndex = AuraByIndex


-- ===========================================================================
-- Consommables
-- ===========================================================================
local instantCache = {}

local function ItemIdentity(itemID)
	if not itemID then return nil end
	local cached = instantCache[itemID]
	if cached then return cached end
	-- Era : la fonction globale existe toujours, la version C_Item pas forcément
	local fn = (C_Item and C_Item.GetItemInfoInstant) or rawget(_G, "GetItemInfoInstant")
	if type(fn) ~= "function" then return nil end

	local ok, _, itemType, itemSubType, _, _, classID, subClassID = pcall(fn, itemID)
	if not ok or not classID then return nil end

	local data = { classID = classID, subClassID = subClassID, itemType = itemType, itemSubType = itemSubType }
	instantCache[itemID] = data
	return data
end


local CONSUMABLE = 0
local SUBCLASS_FOODDRINK = 5
local SUBCLASS_COMBAT = { [1] = true, [2] = true, [3] = true, [4] = true }

-- Sur Classic Era, les consommables gardent la sous-classe générique 0 de
-- vanilla : nourriture, boissons et potions n'ont pas de sous-classe propre.
-- On les reconnaît alors au sort qu'ils lancent (« Nourriture », « Boisson »)
-- ou, pour les potions, au mot « Potion » dans leur nom.
local FOOD_SPELLS = {
	["nourriture"] = true, ["boisson"] = true, ["food"] = true, ["drink"] = true,
	["refreshment"] = true, ["rafraîchissement"] = true,
	["food & drink"] = true, ["nourriture et boisson"] = true,
}
local kindCache = {}

local function ItemSpellName(itemID)
	local fn = (C_Item and C_Item.GetItemSpell) or rawget(_G, "GetItemSpell")
	if type(fn) ~= "function" then return nil end
	local ok, name = pcall(fn, itemID)
	if ok and type(name) == "string" then return name end
	return nil
end

local function ItemName(itemID)
	local name = ns.ItemInfo(itemID)
	if type(name) == "string" then return name end
	return nil
end

-- "food", "combat" ou nil. Le résultat n'est mis en cache que s'il est sûr :
-- un objet pas encore en cache client sera réexaminé au prochain check.
local function ConsumableKind(itemID)
	if kindCache[itemID] ~= nil then return kindCache[itemID] or nil end
	local data = ItemIdentity(itemID)
	if not data or data.classID ~= CONSUMABLE then return nil end
	local sub = data.subClassID
	if sub == SUBCLASS_FOODDRINK then kindCache[itemID] = "food"; return "food" end
	if SUBCLASS_COMBAT[sub] then kindCache[itemID] = "combat"; return "combat" end
	if sub ~= 0 and sub ~= nil then kindCache[itemID] = false; return nil end

	local spell = ItemSpellName(itemID)
	if spell and FOOD_SPELLS[ns.AsciiLower(spell)] then kindCache[itemID] = "food"; return "food" end
	local name = ItemName(itemID)
	if name and ns.AsciiLower(name):find("potion", 1, true) then kindCache[itemID] = "combat"; return "combat" end
	if spell or name then kindCache[itemID] = false end
	return nil
end
ns.ConsumableKind = ConsumableKind


-- ===========================================================================
-- Messages d'XP
-- ===========================================================================
-- ---------------------------------------------------------------------------
-- Messages d'XP des monstres
-- ---------------------------------------------------------------------------
-- Chaînes du client d'abord. Les variantes « (+%d bonus de groupe) » ou
-- « (%s exp %s bonus) » commencent comme COMBATLOG_XPGAIN_FIRSTPERSON : le
-- motif n'est donc ancré qu'au début, la suite du message est ignorée.
local KILL_GLOBALS = { "COMBATLOG_XPGAIN_FIRSTPERSON", "COMBATLOG_XPGAIN_EXHAUSTION1" }
local UNNAMED_GLOBALS = { "COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED" }
local KILL_FALLBACK = {
	"%s dies, you gain %d experience.",
	"%s meurt, vous gagnez %d points d'expérience.",
}
local UNNAMED_FALLBACK = {
	"You gain %d experience.",
	"Vous gagnez %d points d'expérience.",
}

-- Format du client -> motif Lua + position de la capture numérique. Gère les
-- formes positionnelles (%1$s, %2$d) de certaines traductions.
local function FormatToPattern(format)
	local order, index = {}, 0
	local pattern = format:gsub("%%(%d?)%$?([sd])", function(pos, kind)
		index = index + 1
		order[#order + 1] = { pos = tonumber(pos) or index, kind = kind }
		return kind == "d" and "\2" or "\1"
	end)
	pattern = pattern:gsub("([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
	pattern = pattern:gsub("\1", "(.-)"):gsub("\2", "(%%d+)")
	-- quelle capture porte l'XP : la première %d dans l'ordre du texte
	local xpCapture
	for capture, spec in ipairs(order) do
		if spec.kind == "d" then xpCapture = capture; break end
	end
	return "^" .. pattern, xpCapture
end

local function BuildPatterns(globals, fallback)
	local list, seen = {}, {}
	local function Add(format)
		if type(format) ~= "string" or format == "" or seen[format] then return end
		seen[format] = true
		local pattern, capture = FormatToPattern(format)
		if capture then list[#list + 1] = { pattern = pattern, capture = capture } end
	end
	for _, name in ipairs(globals) do Add(rawget(_G, name)) end
	-- le repli reste actif même avec les chaînes du client : il ne coûte rien
	-- et couvre un client dont les globales seraient renommées
	for _, format in ipairs(fallback) do Add(format) end
	return list
end

-- Motifs gardés (ns.MemoGlobals) : reconstruits seulement si une chaîne du
-- client change, pas à chaque message
local KillPatterns = ns.MemoGlobals(KILL_GLOBALS, function() return BuildPatterns(KILL_GLOBALS, KILL_FALLBACK) end)
local UnnamedPatterns = ns.MemoGlobals(UNNAMED_GLOBALS, function() return BuildPatterns(UNNAMED_GLOBALS, UNNAMED_FALLBACK) end)

-- Renvoie xp, nommé (true = un monstre identifié) ; nil si le message n'est pas un gain d'XP
-- (la capture de l'XP est prise par son rang, sans table de captures)
function ns:ParseCombatXP(message)
	if type(message) ~= "string" then return nil end
	for _, entry in ipairs(KillPatterns()) do
		local value = select(entry.capture, message:match(entry.pattern))
		if value ~= nil then return tonumber(value), true end
	end
	for _, entry in ipairs(UnnamedPatterns()) do
		local value = select(entry.capture, message:match(entry.pattern))
		if value ~= nil then return tonumber(value), false end
	end
	return nil
end


-- ===========================================================================
-- Butin
-- ===========================================================================
local LOOT_GLOBALS = {
	"LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
	"LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF",
}
-- Repli si le client n'expose pas ces globales (anglais et français)
local LOOT_FALLBACK = {
	"You receive loot: %sx%d.", "You receive item: %sx%d.",
	"You receive loot: %s.", "You receive item: %s.",
	"Vous recevez le butin : %sx%d.", "Vous recevez l'objet : %sx%d.",
	"Vous recevez le butin : %s.", "Vous recevez l'objet : %s.",
}

local function LootFormatToPattern(format)
	local pattern = format:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
	-- formes positionnelles (%1$s, devenu %1%$s ci-dessus) de certaines
	-- langues, puis %s / %d. Marqueurs \1 / \2 d'abord : remplacer %d par
	-- (%d+) puis rechercher %d recapturerait le motif déjà posé.
	pattern = pattern:gsub("%%%d%%%$s", "\1"):gsub("%%%d%%%$d", "\2")
	pattern = pattern:gsub("%%s", "\1"):gsub("%%d", "\2")
	pattern = pattern:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
	return "^" .. pattern .. "$"
end

local function BuildLootPatterns()
	local patterns = {}
	for _, name in ipairs(LOOT_GLOBALS) do
		local format = rawget(_G, name)
		if type(format) == "string" and format ~= "" then patterns[#patterns + 1] = LootFormatToPattern(format) end
	end
	if #patterns == 0 then
		for _, format in ipairs(LOOT_FALLBACK) do patterns[#patterns + 1] = LootFormatToPattern(format) end
	end
	return patterns
end
-- gardés tant que les chaînes du client ne changent pas (ns.MemoGlobals)
local LootPatterns = ns.MemoGlobals(LOOT_GLOBALS, BuildLootPatterns)
ns.LootPatterns = LootPatterns
ns.ExpeditionLootPatterns = LootPatterns   -- ancien nom


-- Renvoie lien, quantité si le message est un butin du joueur, sinon nil
function ns:ParseSelfLoot(message)
	if type(message) ~= "string" then return nil end
	for _, pattern in ipairs(LootPatterns()) do
		local item, count = message:match(pattern)
		if item then
			local link = item:match("(|c.-|H.-|h.-|h|r)") or item:match("(|H.-|h.-|h)")
			if link then return link, tonumber(count) or 1 end
		end
	end
	return nil
end


if ns.Mark then ns.Mark("World") end
end)(SOCLE_ADDON, SOCLE_NS)
