-- World.lua -- lecture du monde du jeu (socle commun)
--
-- Ce dont Ready2Quest et QuestCompanion ont besoin tous les deux pour savoir
-- où est le joueur et ce qui lui arrive, sans dépendre l'un de l'autre :
--   * carte : ns:CurrentMap, MapInfo, MapChain, CurrentSubZone, InInstance ;
--   * lieux connus (Hubs.lua) : ns:HubIndex, PlayerFaction, KnownHub ;
--   * camp de Forever : ns:AtCamp ;
--   * donjons (DungeonData.lua) : ns:IsForeverClient, DungeonIndex,
--     DetectDungeon, DungeonName, DungeonRange ;
--   * auras : ns.AuraByIndex ;
--   * consommables : ns.ConsumableKind (« food », « combat ») ;
--   * messages du jeu : ns:ParseCombatXP (gain d'XP), ns:ParseSelfLoot (butin).
--
-- Fichier du socle commun (Libs/Socle), identique dans Ready2Quest et
-- QuestCompanion : ne le modifier que dans Ready2Quest/Libs/Socle, puis
-- python3 tools/sync_socle.py.
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
function ns:MapChain(mapID)
	local chain, guard = {}, 0
	while mapID and guard < 12 do
		chain[#chain + 1] = mapID
		local info = self:MapInfo(mapID)
		local parent = info and info.parentMapID
		if not parent or parent == 0 or parent == mapID then break end
		mapID = parent
		guard = guard + 1
	end
	return chain
end


-- Sous-zone courante : sur Era, un village (Comté-de-l'Or, Long-guet…) n'a pas
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
	for _, name in ipairs({ subzone or false, zone or false }) do
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
	local forever = self:IsForeverClient()
	for key, entry in pairs(self.DUNGEONS or {}) do
		-- un donjon de Forever n'existe pas sur Era : pas de faux positif de nom
		if not entry.forever or forever then
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
	end
	self.dungeonIndex = index
	return index
end

-- Nom affiché : celui du jeu (instance en cours, sinon AreaTable), puis l'anglais
function ns:DungeonName(entry, instanceName)
	return instanceName or AreaName(entry.area) or entry.name or "?"
end

function ns:DungeonRange(entry)
	local range = (self:IsForeverClient() and entry.fo) or entry.era or entry.fo
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
		local ok, name, _, _, _, duration, _, _, _, _, spellId = pcall(UnitAura, "player", index, "HELPFUL")
		if ok and name then
			return { name = name, duration = duration, spellId = spellId }
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
	local fn = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
	if type(fn) ~= "function" then return nil end
	local ok, name = pcall(fn, itemID)
	if ok and type(name) == "string" then return name end
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

-- Renvoie xp, nommé (true = un monstre identifié) ; nil si le message n'est pas un gain d'XP
function ns:ParseCombatXP(message)
	if type(message) ~= "string" then return nil end
	for _, entry in ipairs(BuildPatterns(KILL_GLOBALS, KILL_FALLBACK)) do
		local captures = { message:match(entry.pattern) }
		if #captures > 0 then return tonumber(captures[entry.capture]), true end
	end
	for _, entry in ipairs(BuildPatterns(UNNAMED_GLOBALS, UNNAMED_FALLBACK)) do
		local captures = { message:match(entry.pattern) }
		if #captures > 0 then return tonumber(captures[entry.capture]), false end
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

local function LootPatterns()
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
