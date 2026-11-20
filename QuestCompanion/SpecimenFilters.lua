-- SpecimenFilters.lua -- trier la Réserve : filtres, vues, tris, protéger, surnom (QuestCompanion 3.4.0)
--
-- 3.4.0 (docs/design-reserve-3.4) : la Réserve se trie finement.
--   * Schéma des spécimens v2, champs écrits seulement s'ils ne valent pas
--     le défaut : `lock` (protégé : jamais relâché, jamais pris dans un lot,
--     jamais proposé par « Faire de la place », jamais échangé), `nick`
--     (surnom, 24 octets au plus), `zi` (indice de taille, 75 à 125, dans le
--     cran de sa taille ; tiré à la capture, dérivé de l'id pour l'existant).
--   * Filtre = { q = texte, sets = { groupe = { [valeur] = true } } } :
--     l'une ou l'autre valeur dans un groupe (OU), tous les groupes (ET) ;
--     les ÉTATS se cumulent (ET). Groupes : étoiles, version, taille,
--     caractère, type, rang, zone, date de capture, lien, état.
--   * Compteur de chaque puce : ce qui resterait avec cette valeur dans son
--     groupe, les autres groupes comme ils sont (gardé sur specSerial et le
--     filtre).
--   * Vues : Tout, Doublons, Relâchables, Meilleurs que le Codex, Récents,
--     Protégés, et « Ma vue » (une seule, gardée au compte).
--   * Tris : étoiles, date, nom, taille, lien, doublons, valeur au relâcher ;
--     deux sens.
--
-- API
--   ns:SpecimenSizeIndex(spec|id) -> 75..125 ; ns:SpecimenSizeBand(size) -> lo, hi
--   ns:SpecimenProtected(id) -> bool ; ns:SpecimenProtect(id, on) -> bool
--   ns:SpecimenNick(id) -> texte|nil ; ns:SpecimenSetNick(id, texte|nil) -> texte|nil
--   ns:SpecimenDisplayName(spec) -> surnom, sinon le nom (avec « (brillant) »)
--   ns.RESERVE_FILTER_GROUPS, ns:ReserveFilterValues(group) -> { valeur, … }
--   ns:ReserveFilterNew() ; ns:ReserveFilterCopy(f) ; ns:ReserveFilterToggle(f, group, value)
--   ns:ReserveFilterActive(f) -> nombre de groupes actifs (recherche comprise)
--   ns:ReserveMatch(spec, f, ctx) -> bool ; ns:ReserveQuery(f, sort, desc, where) -> { spec, … }
--   ns:ReserveFacetCounts(f, where) -> counts[group][value]
--   ns.RESERVE_VIEW_ORDER, ns:ReserveView2(id) -> filtre (Ma vue : la tienne)
--   ns:ReserveSaveMyView(f)
--   ns.RESERVE_SORT_ORDER
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

-- crans de l'indice de taille (bornes comprises)
ns.SPECIMEN_SIZE_INDEX = {
	tiny = { 75, 81 }, small = { 82, 93 }, normal = { 94, 106 }, large = { 107, 118 }, giant = { 119, 125 },
}
ns.SPECIMEN_NICK_MAX = 24
ns.RESERVE_RECENT_DAYS = 7

local FR = {
	RES_FG_stars    = "Étoiles",
	RES_FG_version  = "Version",
	RES_FG_size     = "Taille",
	RES_FG_trait    = "Caractère",
	RES_FG_type     = "Type",
	RES_FG_rank     = "Rang",
	RES_FG_zone     = "Zone",
	RES_FG_age      = "Capturé",
	RES_FG_bond     = "Lien",
	RES_FG_state    = "État",
	RES_FV_stars_1  = "1 étoile",
	RES_FV_stars_2  = "2 étoiles",
	RES_FV_stars_3  = "3 étoiles",
	RES_FV_normal   = "Normale",
	RES_FV_shiny    = "Brillante",
	RES_FV_rank_normal = "Normal",
	RES_FV_rank_elite  = "Élite",
	RES_FV_rank_rare   = "Rare",
	RES_FV_age_1    = "Aujourd'hui",
	RES_FV_age_7    = "7 jours",
	RES_FV_age_30   = "30 jours",
	RES_FV_age_old  = "Plus ancien",
	RES_FV_better     = "Meilleur que le Codex",
	RES_FV_dup        = "Doublon",
	RES_FV_protected  = "Protégé",
	RES_FV_releasable = "Relâchable",
	RES_FV_tradable   = "Échangeable",
	RES_FV_received   = "Reçu en échange",
	RES_FV_zone_any   = "Toutes les zones",
	RES_VIEW2_all        = "Tout",
	RES_VIEW2_dup        = "Doublons",
	RES_VIEW2_releasable = "Relâchables",
	RES_VIEW2_better     = "Meilleurs que le Codex",
	RES_VIEW2_recent     = "Récents",
	RES_VIEW2_protected  = "Protégés",
	RES_VIEW2_mine       = "Ma vue",
	RES_SORT_size   = "Tri : taille",
	RES_SORT_bond   = "Tri : lien",
	RES_SORT_dups   = "Tri : doublons",
	RES_SORT_value  = "Tri : valeur",
	SPEC_PROTECTED  = "Protégé : jamais relâché, échangé ni pris dans un lot.",
	SPEC_PROTECT_ON  = "%s est protégé.",
	SPEC_PROTECT_OFF = "%s n'est plus protégé.",
	SPEC_WHY_protected = "Protégé : enlève le cadenas d'abord.",
	SPEC_NICK_SET   = "%s s'appelle maintenant « %s ».",
	SPEC_NICK_CLEAR = "%s a perdu son surnom.",
}
local EN = {
	RES_FG_stars    = "Stars",
	RES_FG_version  = "Version",
	RES_FG_size     = "Size",
	RES_FG_trait    = "Personality",
	RES_FG_type     = "Type",
	RES_FG_rank     = "Rank",
	RES_FG_zone     = "Zone",
	RES_FG_age      = "Caught",
	RES_FG_bond     = "Bond",
	RES_FG_state    = "State",
	RES_FV_stars_1  = "1 star",
	RES_FV_stars_2  = "2 stars",
	RES_FV_stars_3  = "3 stars",
	RES_FV_normal   = "Normal",
	RES_FV_shiny    = "Shiny",
	RES_FV_rank_normal = "Normal",
	RES_FV_rank_elite  = "Elite",
	RES_FV_rank_rare   = "Rare",
	RES_FV_age_1    = "Today",
	RES_FV_age_7    = "7 days",
	RES_FV_age_30   = "30 days",
	RES_FV_age_old  = "Older",
	RES_FV_better     = "Better than Codex",
	RES_FV_dup        = "Duplicate",
	RES_FV_protected  = "Protected",
	RES_FV_releasable = "Releasable",
	RES_FV_tradable   = "Tradable",
	RES_FV_received   = "Received in trade",
	RES_FV_zone_any   = "All zones",
	RES_VIEW2_all        = "All",
	RES_VIEW2_dup        = "Duplicates",
	RES_VIEW2_releasable = "Releasable",
	RES_VIEW2_better     = "Better than Codex",
	RES_VIEW2_recent     = "Recent",
	RES_VIEW2_protected  = "Protected",
	RES_VIEW2_mine       = "My view",
	RES_SORT_size   = "Sort: size",
	RES_SORT_bond   = "Sort: bond",
	RES_SORT_dups   = "Sort: duplicates",
	RES_SORT_value  = "Sort: value",
	SPEC_PROTECTED  = "Protected: never released, traded or picked in a batch.",
	SPEC_PROTECT_ON  = "%s is protected.",
	SPEC_PROTECT_OFF = "%s is no longer protected.",
	SPEC_WHY_protected = "Protected: remove the lock first.",
	SPEC_NICK_SET   = "%s is now called \"%s\".",
	SPEC_NICK_CLEAR = "%s lost its nickname.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.SPECIMEN_FILTER_STRINGS = { fr = FR, en = EN } end

local function Store(self) return ns.SpecimenStore and ns.SpecimenStore(self) or self:CaptureData() end
local function Touch(capture) if ns.SpecimenTouch then ns.SpecimenTouch(capture) end end
local function Now() return (ns.RealTime and ns.RealTime()) or (rawget(_G, "time") and time()) or 0 end
local function Fire(event, ...) if ns.FireCallback then ns:FireCallback(event, ...) end end
local function Spec(self, spec)
	if type(spec) == "table" then return spec end
	return self:SpecimenGet(spec)
end

-- ---------------------------------------------------------------------------
-- Indice de taille
-- ---------------------------------------------------------------------------
function ns:SpecimenSizeBand(size)
	local band = ns.SPECIMEN_SIZE_INDEX[size or "normal"] or ns.SPECIMEN_SIZE_INDEX.normal
	return band[1], band[2]
end

function ns:SpecimenSizeIndex(spec)
	spec = Spec(self, spec)
	if type(spec) ~= "table" then return 100 end
	local lo, hi = self:SpecimenSizeBand(spec.size)
	local zi = tonumber(spec.zi)
	if zi and zi >= lo and zi <= hi then return zi end
	-- l'existant : tiré de l'id, toujours le même, dans son cran
	local id = math.floor(tonumber(spec.id) or 0)
	return lo + ((id * 37 + 13) % (hi - lo + 1))
end

-- à la capture : un indice tiré dans le cran (les autres le dérivent de l'id)
if ns.RegisterCallback then
	ns:RegisterCallback("SPECIMENS", function(self, what, id)
		if what ~= "add" then return end
		local spec = self:SpecimenGet(id)
		if not spec or spec.origin ~= "capture" or spec.zi then return end
		local lo, hi = self:SpecimenSizeBand(spec.size)
		spec.zi = lo + math.floor(math.random() * (hi - lo + 1))
		if spec.zi > hi then spec.zi = hi end
	end)
end

-- ---------------------------------------------------------------------------
-- Protéger, surnom
-- ---------------------------------------------------------------------------
function ns:SpecimenProtected(id)
	local spec = Spec(self, id)
	return type(spec) == "table" and spec.lock == true
end

function ns:SpecimenProtect(id, on)
	local spec = Spec(self, id)
	if type(spec) ~= "table" then return false end
	on = on and true or false
	if (spec.lock == true) == on then return on end
	spec.lock = on or nil
	Touch(Store(self))
	Fire("SPECIMENS", "protect", spec.id)
	return on
end

local function CleanNick(text)
	if type(text) ~= "string" then return nil end
	text = text:gsub("[|%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then return nil end
	if #text > ns.SPECIMEN_NICK_MAX then
		text = text:sub(1, ns.SPECIMEN_NICK_MAX)
		-- jamais un caractère UTF-8 coupé en deux
		while #text > 0 and text:byte(#text) >= 0x80 and text:byte(#text) < 0xC0 do text = text:sub(1, -2) end
		if #text > 0 and text:byte(#text) >= 0xC0 then text = text:sub(1, -2) end
	end
	return text
end
ns.SpecimenCleanNick = CleanNick

function ns:SpecimenNick(id)
	local spec = Spec(self, id)
	return type(spec) == "table" and spec.nick or nil
end

function ns:SpecimenSetNick(id, text)
	local spec = Spec(self, id)
	if type(spec) ~= "table" then return nil end
	spec.nick = CleanNick(text)
	Touch(Store(self))
	Fire("SPECIMENS", "nick", spec.id)
	return spec.nick
end

function ns:SpecimenDisplayName(spec)
	spec = Spec(self, spec)
	if type(spec) ~= "table" then return "" end
	if spec.nick then return spec.nick end
	return self:SpecimenLabel(spec)
end

-- protégé : ni relâché, ni échangé (les deux s'enveloppent : CaptureTrades
-- est chargé avant ce fichier)
do
	local canRelease = ns.SpecimenCanRelease
	function ns:SpecimenCanRelease(id, ...)
		local ok, why = canRelease(self, id, ...)
		if ok and self:SpecimenProtected(tonumber(id) or id) then return false, "protected" end
		return ok, why
	end
	local canTrade = ns.SpecimenCanTrade
	if canTrade then
		function ns:SpecimenCanTrade(id, ...)
			local ok, why = canTrade(self, id, ...)
			if ok and self:SpecimenProtected(tonumber(id) or id) then return false, "protected" end
			return ok, why
		end
	end
end

-- ---------------------------------------------------------------------------
-- Groupes et valeurs
-- ---------------------------------------------------------------------------
ns.RESERVE_FILTER_GROUPS = { "stars", "version", "size", "trait", "type", "rank", "zone", "age", "bond", "state" }
-- les états se cumulent (ET) ; les autres groupes : l'une ou l'autre (OU)
ns.RESERVE_FILTER_AND = { state = true }
ns.RESERVE_STATES = { "better", "dup", "protected", "releasable", "tradable", "received" }
ns.RESERVE_AGES = { "1", "7", "30", "old" }

local RANK_OF = ns.CAPTURE_QUALITY_GROUP or {}

local function Creature(capture, npc)
	local entry = capture.creatures and capture.creatures[npc]
	return type(entry) == "table" and entry or nil
end

local function RankOf(capture, spec)
	local entry = Creature(capture, spec.npc)
	local class = entry and entry.class
	return RANK_OF[class or "normal"] or "normal"
end

local function TypeOf(self, capture, spec)
	local entry = Creature(capture, spec.npc)
	if not entry then return nil end
	if entry.typeKey then return entry.typeKey end
	return self.CreatureTypeKey and self:CreatureTypeKey(entry.type) or nil
end

-- la sorte et le rang d'un spécimen (fiche de la Réserve)
function ns:SpecimenTypeKey(spec)
	spec = Spec(self, spec)
	return spec and TypeOf(self, Store(self), spec) or nil
end
function ns:SpecimenRankKey(spec)
	spec = Spec(self, spec)
	return spec and RankOf(Store(self), spec) or "normal"
end

local function BondOf(self, spec)
	return self.SpecimenBondLevel and self:SpecimenBondLevel(spec) or 1
end

local function AgeOf(spec, now)
	local at = tonumber(spec.at)
	if not at or at <= 0 then return "old" end
	local days = (now - at) / 86400
	if days < 1 then return "1" end
	if days < 7 then return "7" end
	if days < 30 then return "30" end
	return "old"
end

-- une valeur d'âge englobe les plus récentes (« 7 jours » comprend aujourd'hui)
local AGE_RANK = { ["1"] = 1, ["7"] = 2, ["30"] = 3, old = 4 }

function ns:ReserveFilterValues(group)
	if group == "stars" then return { 1, 2, 3 } end
	if group == "version" then return { "normal", "shiny" } end
	if group == "size" then
		local list = {}
		for _, def in ipairs(ns.SPECIMEN_SIZES or {}) do list[#list + 1] = def.id end
		return list
	end
	if group == "trait" then
		-- les 8 tirés, puis les 6 exclusifs seulement si un spécimen les porte
		local list, seen = {}, {}
		for _, pair in ipairs(ns.SPECIMEN_TRAIT_WEIGHTS or {}) do list[#list + 1] = pair[1]; seen[pair[1]] = true end
		local present = {}
		for _, spec in pairs(Store(self).specimens or {}) do if spec.trait then present[spec.trait] = true end end
		for _, id in ipairs(ns.PERSONALITY_ORDER or {}) do
			if not seen[id] and present[id] then list[#list + 1] = id end
		end
		return list
	end
	if group == "type" then return ns.CREATURE_TYPES or {} end
	if group == "rank" then return { "normal", "elite", "rare" } end
	if group == "age" then return ns.RESERVE_AGES end
	if group == "bond" then return { 1, 2, 3, 4, 5 } end
	if group == "state" then return ns.RESERVE_STATES end
	if group == "zone" then
		local seen, list = {}, {}
		for _, spec in pairs(Store(self).specimens or {}) do
			local zone = tonumber(spec.zone)
			if zone and not seen[zone] then seen[zone] = true; list[#list + 1] = zone end
		end
		table.sort(list)
		return list
	end
	return {}
end

-- libellé d'une valeur de filtre
local zoneNames = {}
function ns:ReserveZoneName(zone)
	zone = tonumber(zone)
	if not zone then return "" end
	if zoneNames[zone] then return zoneNames[zone] end
	local name
	local api = rawget(_G, "C_Map")
	if type(api) == "table" and type(api.GetMapInfo) == "function" then
		local ok, info = pcall(api.GetMapInfo, zone)
		if ok and type(info) == "table" then
			name = info.name
			if ns.Plain then name = ns.Plain(name) end
		end
	end
	zoneNames[zone] = type(name) == "string" and name or tostring(zone)
	return zoneNames[zone]
end

function ns:ReserveFilterLabel(group, value)
	if group == "stars" then return L["RES_FV_stars_" .. math.max(1, math.min(3, math.floor(tonumber(value) or 1)))] end
	if group == "version" then return L["RES_FV_" .. tostring(value)] end
	if group == "size" then return self:SpecimenSizeLabel(value) end
	if group == "trait" then return self.PersonaLabel and self:PersonaLabel(value) or tostring(value) end
	if group == "type" then return self:CreatureTypeLabel(value) end
	if group == "rank" then return L["RES_FV_rank_" .. tostring(value)] end
	if group == "age" then return L["RES_FV_age_" .. tostring(value)] end
	if group == "bond" then return self.SpecimenBondName and self:SpecimenBondName(value) or tostring(value) end
	if group == "state" then return L["RES_FV_" .. tostring(value)] end
	if group == "zone" then return self:ReserveZoneName(value) end
	return tostring(value)
end

-- ---------------------------------------------------------------------------
-- Filtre
-- ---------------------------------------------------------------------------
function ns:ReserveFilterNew() return { q = nil, sets = {} } end

function ns:ReserveFilterCopy(f)
	local copy = { q = f and f.q or nil, sets = {} }
	for group, set in pairs(f and f.sets or {}) do
		local c = {}
		for value, on in pairs(set) do if on then c[value] = true end end
		if next(c) then copy.sets[group] = c end
	end
	return copy
end

-- une valeur de plus ou de moins ; la zone et l'âge : une seule à la fois
function ns:ReserveFilterToggle(f, group, value)
	f.sets = f.sets or {}
	local set = f.sets[group] or {}
	if group == "zone" or group == "age" then
		local was = set[value]
		set = {}
		if not was and value ~= nil then set[value] = true end
	elseif set[value] then set[value] = nil
	else set[value] = true end
	f.sets[group] = next(set) and set or nil
	return f
end

function ns:ReserveFilterActive(f)
	local n = (f and f.q and f.q ~= "") and 1 or 0
	for _, set in pairs(f and f.sets or {}) do if next(set) then n = n + 1 end end
	return n
end

-- contexte d'une requête : doublons par espèce et version, maintenant
local function Context(self, capture)
	local per = {}
	for _, spec in pairs(capture.specimens) do
		local key = tostring(spec.npc) .. (spec.shiny and ":s" or "")
		per[key] = (per[key] or 0) + 1
	end
	return { per = per, now = Now(), capture = capture }
end

local function Fold(text)
	if ns.OptionFold then return ns.OptionFold(text) end
	return tostring(text or ""):lower()
end

local function StateOf(self, ctx, spec, state)
	if state == "better" then return self:SpecimenBetterThanCodex(spec.id) end
	if state == "dup" then return (ctx.per[tostring(spec.npc) .. (spec.shiny and ":s" or "")] or 0) > 1 end
	if state == "protected" then return spec.lock == true end
	if state == "releasable" then return (self:SpecimenCanRelease(spec.id)) == true end
	if state == "tradable" then return self.SpecimenCanTrade ~= nil and (self:SpecimenCanTrade(spec.id)) == true end
	if state == "received" then return spec.origin == "trade" or spec.tradedFrom ~= nil end
	return false
end

-- Valeur du spécimen pour un groupe (comparée aux valeurs cochées)
local function GroupHit(self, ctx, spec, group, set)
	if group == "stars" then return set[spec.stars] == true end
	if group == "version" then return set[spec.shiny and "shiny" or "normal"] == true end
	if group == "size" then return set[spec.size or "normal"] == true end
	if group == "trait" then return spec.trait ~= nil and set[spec.trait] == true end
	if group == "type" then local t = TypeOf(self, ctx.capture, spec); return t ~= nil and set[t] == true end
	if group == "rank" then return set[RankOf(ctx.capture, spec)] == true end
	if group == "zone" then return set[tonumber(spec.zone)] == true end
	if group == "age" then
		local rank = AGE_RANK[AgeOf(spec, ctx.now)]
		for value in pairs(set) do
			if value == "old" then if rank == 4 then return true end
			elseif rank <= (AGE_RANK[value] or 0) then return true end
		end
		return false
	end
	if group == "bond" then return set[BondOf(self, spec)] == true end
	if group == "state" then
		for value in pairs(set) do
			if not StateOf(self, ctx, spec, value) then return false end
		end
		return true
	end
	return true
end

local function SearchHit(self, spec, words)
	if not words then return true end
	local hay = Fold(self:SpecimenLabel(spec) .. " " .. tostring(spec.nick or "") .. " "
		.. (spec.zone and self:ReserveZoneName(spec.zone) or ""))
	for _, word in ipairs(words) do
		if not hay:find(word, 1, true) then return false end
	end
	return true
end

local function Words(q)
	if not q or q == "" then return nil end
	local words = {}
	for word in Fold(q):gmatch("%S+") do words[#words + 1] = word end
	return #words > 0 and words or nil
end

-- `skip` : un groupe laissé de côté (compteurs des puces)
function ns:ReserveMatch(spec, f, ctx, skip, words)
	ctx = ctx or Context(self, Store(self))
	if not SearchHit(self, spec, words or Words(f and f.q)) then return false end
	for group, set in pairs(f and f.sets or {}) do
		if group ~= skip and next(set) and not GroupHit(self, ctx, spec, group, set) then return false end
	end
	return true
end

-- ---------------------------------------------------------------------------
-- Tris
-- ---------------------------------------------------------------------------
ns.RESERVE_SORT_ORDER = { "stars", "date", "name", "size", "bond", "dups", "value" }

local function Primary(self, ctx, sort, spec)
	if sort == "stars" then return (spec.stars or 1) * 2 + (spec.shiny and 1 or 0) end
	if sort == "date" then return tonumber(spec.at) or 0 end
	if sort == "size" then return self:SpecimenSizeIndex(spec) end
	if sort == "bond" then
		return BondOf(self, spec) * 1000 + (self.SpecimenBondPoints and self:SpecimenBondPoints(spec) or 0)
	end
	if sort == "dups" then return ctx.per[tostring(spec.npc) .. (spec.shiny and ":s" or "")] or 0 end
	if sort == "value" then return self:SpecimenReleaseBase(spec) end
	return 0
end

local function Sorter(self, ctx, sort, desc)
	if sort == "name" then
		local names = {}
		return function(a, b)
			local x = names[a] or Fold(self:SpecimenDisplayName(a)); names[a] = x
			local y = names[b] or Fold(self:SpecimenDisplayName(b)); names[b] = y
			if x ~= y then if desc then return x > y end return x < y end
			return a.id < b.id
		end
	end
	local keys = {}
	return function(a, b)
		local x = keys[a] or Primary(self, ctx, sort, a); keys[a] = x
		local y = keys[b] or Primary(self, ctx, sort, b); keys[b] = y
		if x ~= y then if desc then return x > y end return x < y end
		return a.id > b.id
	end
end

-- La Réserve (ou tout, ou le Codex) filtrée et triée : table neuve.
-- Par défaut : étoiles décroissantes (comme avant).
function ns:ReserveQuery(f, sort, desc, where)
	local capture = Store(self)
	local ctx = Context(self, capture)
	local words = Words(f and f.q)
	local list = {}
	for _, spec in ipairs(self:SpecimenList({ where = where or "reserve", sort = "id" })) do
		if self:ReserveMatch(spec, f, ctx, nil, words) then list[#list + 1] = spec end
	end
	sort = sort or "stars"
	if desc == nil then desc = sort ~= "name" end
	table.sort(list, Sorter(self, ctx, sort, desc))
	return list
end

-- Compteurs des puces, gardés tant que ni les spécimens ni le filtre ne bougent
local function FilterKey(f, where)
	local parts = { tostring(where or "reserve"), tostring(f and f.q or "") }
	for _, group in ipairs(ns.RESERVE_FILTER_GROUPS) do
		local set = f and f.sets and f.sets[group]
		if set then
			local values = {}
			for value in pairs(set) do values[#values + 1] = tostring(value) end
			table.sort(values)
			parts[#parts + 1] = group .. "=" .. table.concat(values, ",")
		end
	end
	return table.concat(parts, ";")
end

function ns:ReserveFacetCounts(f, where)
	local capture = Store(self)
	local key = FilterKey(f, where)
	local cache = self.reserveFacetCache
	if cache and cache.serial == capture.specSerial and cache.key == key then return cache.counts end
	local ctx = Context(self, capture)
	local words = Words(f and f.q)
	local all = self:SpecimenList({ where = where or "reserve", sort = "id" })
	local counts = {}
	for _, group in ipairs(ns.RESERVE_FILTER_GROUPS) do
		local c = {}
		counts[group] = c
		for _, value in ipairs(self:ReserveFilterValues(group)) do c[value] = 0 end
		for _, spec in ipairs(all) do
			-- ce groupe laissé de côté ; les états : avec les autres états cochés
			local skip = ns.RESERVE_FILTER_AND[group] and "__none" or group
			if self:ReserveMatch(spec, f, ctx, skip, words) then
				for value in pairs(c) do
					local set = { [value] = true }
					if ns.RESERVE_FILTER_AND[group] then
						if StateOf(self, ctx, spec, value) then c[value] = c[value] + 1 end
					elseif GroupHit(self, ctx, spec, group, set) then
						c[value] = c[value] + 1
					end
				end
			end
		end
	end
	self.reserveFacetCache = { serial = capture.specSerial, key = key, counts = counts }
	return counts
end

-- ---------------------------------------------------------------------------
-- Vues
-- ---------------------------------------------------------------------------
ns.RESERVE_VIEW_ORDER = { "all", "dup", "releasable", "better", "recent", "protected", "mine" }
local VIEWS = {
	all = {},
	dup = { state = { dup = true } },
	releasable = { state = { releasable = true } },
	better = { state = { better = true } },
	recent = { age = { ["7"] = true } },
	protected = { state = { protected = true } },
}

function ns:ReserveView2(id)
	if id == "mine" then
		local mine = self:CaptureData().resMyView
		return self:ReserveFilterCopy(type(mine) == "table" and mine or nil)
	end
	local f = self:ReserveFilterNew()
	for group, set in pairs(VIEWS[id] or {}) do
		f.sets[group] = {}
		for value in pairs(set) do f.sets[group][value] = true end
	end
	return f
end

function ns:ReserveSaveMyView(f)
	local copy = self:ReserveFilterCopy(f)
	copy.q = nil
	self:CaptureData().resMyView = copy
	return copy
end

if ns.Mark then ns.Mark("SpecimenFilters") end
