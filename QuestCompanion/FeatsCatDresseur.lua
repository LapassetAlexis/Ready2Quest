-- FeatsCatDresseur.lua -- hauts faits 3.7.0, chantier B2a : la famille
-- « dresseur » (Initiation, Créatures, Spécimens, Brillantes, Réserve et
-- Échoppe). 99 lignes, codes 244 à 323 et 378 à 396 ; titres T50 à T58.
-- Catalogue : docs/QC-HAUTS-FAITS.md §7.1.
--
-- Chargé après FeatsCatJeu.lua, avant Feats.lua : on remplit ns.FEAT_SOURCES
-- et ns.FEAT_LISTS (à la première lecture du catalogue, ns.FeatCatalog) et on
-- écoute les modules du jeu sans les toucher :
--   * événements internes (ns:RegisterCallback) : SPECIMENS (capture,
--     relâcher, surnom, protection, épingle, places), BOND (niveau de lien),
--     PAILLETTES (gain, dépense) ;
--   * enveloppes posées à ADDON_LOADED (les modules d'après ce fichier sont
--     alors chargés) : fin d'une visite guidée, fin du tutoriel du compagnon,
--     choix d'apparence, cosmétique de l'Échoppe obtenu.
-- Les lignes « état » s'obtiennent au rattrapage et en direct (sujet touché
-- quand l'état change) ; rien ne bouge tant que le moteur dort (harnais).
--
-- Coût : les sources qui balaient les créatures, les spécimens ou les fiches
-- d'étude se calculent à la demande (une passe du moteur), d'un seul
-- parcours par domaine, gardé tant que la signature du domaine ne bouge pas
-- (numéros de série de la capture, compteur local remonté par les
-- événements). Une ligne obtenue n'est plus évaluée : plus rien ne balaie.
--
-- Données qui manquaient à la sauvegarde (relevés posés ici, sur Tally.lua) :
--   * captureZones (ensemble, compte) : zones où une capture a été faite ;
--     la source y ajoute les zones déjà prouvées (fiche de l'espèce,
--     spécimens possédés) ;
--   * shinyCapZone:<zone> (compte) et shinyZoneBest (maximum) : brillantes
--     capturées par zone ; la source y ajoute les brillantes possédées ;
--   * shinyDayBest (maximum) : brillantes capturées le même jour (le jour en
--     cours est gardé dans db.feats.dresseurShinyDay) ; la source y ajoute les
--     brillantes possédées, datées.
local ADDON, ns = ...
if ns.blocked then return end

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Awake() return not ns.featsDormant end
local function Num(value) return tonumber(value) or 0 end
local function Sub(t, key) return type(t) == "table" and type(t[key]) == "table" and t[key] or nil end
local function Time() return Num(Call(G("time"))) end

ns.FEAT_SOURCES = ns.FEAT_SOURCES or {}
ns.FEAT_LISTS = ns.FEAT_LISTS or {}
local SOURCES, LISTS = ns.FEAT_SOURCES, ns.FEAT_LISTS
local A = "account"

-- Seuils lus par les sources (le reste est dans les lignes)
ns.FEAT_DRESSEUR = {
	level = 60,          -- men_level60 : niveau de la créature
	bond = 5,            -- spec_bond_* : lien Inséparable
	tally = "account",
}

-- Le jour d'une date (clé AAAAMMJJ)
local function Day(at)
	local text = Call(G("date"), "%Y%m%d", at)
	if type(text) == "string" and text:find("^%d%d%d%d%d%d%d%d$") then return text end
	return tostring(math.floor(Num(at) / 86400))
end

-- Bits des fiches d'étude (SpecimenStudy.lua)
local function Has(bits, index) return math.floor(Num(bits) / 2 ^ (index - 1)) % 2 == 1 end
local function Count(bits)
	local n, b = 0, math.floor(Num(bits))
	while b > 0 do n = n + (b % 2); b = math.floor(b / 2) end
	return n
end

-- Compteurs locaux des domaines : remontés par les événements, ils
-- invalident les relevés gardés
local bump = { creatures = 0, spec = 0 }

-- ---------------------------------------------------------------------------
-- Données
-- ---------------------------------------------------------------------------
local function Capture(self) return self.CaptureData and self:CaptureData() or {} end

-- La collection du compte, puis les anciennes collections des personnages
-- (pas encore versées au compte)
local function EachCollection(self, fn)
	local account = Capture(self)
	fn(account, "@account")
	local db = self:DB()
	for key, char in pairs(type(db.chars) == "table" and db.chars or {}) do
		local c = type(char) == "table" and Sub(char.companion, "capture")
		if c and c ~= account then fn(c, key) end
	end
end

-- Chaque compagnon du compte (celui du personnage connecté d'abord)
local function EachCompanion(self, fn)
	local mine = self.CompanionData and self:CompanionData()
	if type(mine) == "table" and fn(mine) then return true end
	local db = self:DB()
	for _, char in pairs(type(db.chars) == "table" and db.chars or {}) do
		local companion = type(char) == "table" and char.companion
		if type(companion) == "table" and companion ~= mine and fn(companion) then return true end
	end
	return false
end

-- Types appris au bestiaire de ce personnage (fiche sans type)
local function TypeIndex(self)
	local index = {}
	for _, zone in pairs(self.BestiaryData and self:BestiaryData() or {}) do
		if type(zone) == "table" then
			for npcID, species in pairs(zone) do
				if type(species) == "table" and species.type then index[tonumber(npcID) or npcID] = species.type end
			end
		end
	end
	return index
end

-- 1. Créatures (fiches par espèce) : rares élites, niveau, zones, brillantes
-- par type, médailles de type 4 et 5
local creatureScan, creatureKey
local function CreatureSignature(self)
	local parts = {}
	EachCollection(self, function(c, key)
		parts[#parts + 1] = table.concat({ tostring(key), tostring(c.serial), tostring(c.count) }, ":")
	end)
	table.sort(parts)
	return table.concat(parts, "|") .. "#" .. bump.creatures
end

local function ScanCreatures(self)
	local key = CreatureSignature(self)
	if creatureScan and creatureKey == key then return creatureScan end
	local s = { rareElite = 0, level60 = 0, medal4 = 0, medal5 = 0, zones = {}, shinyTypes = {} }
	local seenElite, seenLevel, index = {}, {}, nil
	EachCollection(self, function(c)
		for npcID, e in pairs(Sub(c, "creatures") or {}) do
			if type(e) == "table" then
				local id = tonumber(npcID) or npcID
				if e.class == "rareelite" and not seenElite[id] then seenElite[id] = true; s.rareElite = s.rareElite + 1 end
				local level = tonumber(ns.Plain and ns.Plain(e.level) or e.level)
				if level and level >= ns.FEAT_DRESSEUR.level and not seenLevel[id] then
					seenLevel[id] = true
					s.level60 = s.level60 + 1
				end
				local zone = tonumber(e.zoneID)
				if zone then s.zones[zone] = true end
				if e.shiny == true then
					local text = e.type
					if not text then
						index = index or TypeIndex(self)
						text = index[id]
					end
					local typeKey = self.CreatureTypeKey and self:CreatureTypeKey(text)
					if typeKey then s.shinyTypes[typeKey] = true end
				end
			end
		end
	end)
	if self.MenagerieMedals then
		local ok, medals = pcall(self.MenagerieMedals, self)
		for _, medal in pairs(ok and type(medals) == "table" and medals or {}) do
			if Num(medal) >= 4 then s.medal4 = s.medal4 + 1 end
			if Num(medal) >= 5 then s.medal5 = s.medal5 + 1 end
		end
	end
	creatureScan, creatureKey = s, key
	return s
end
function ns:FeatDresseurCreatures() return ScanCreatures(self) end

-- 2. Spécimens possédés : liens, surnoms, protections, zones, brillantes par
-- zone et par jour (preuves déjà dans la sauvegarde)
local specScan, specKey
local function ScanSpecimens(self)
	local capture = Capture(self)
	local key = tostring(capture.specSerial) .. ":" .. tostring(capture.serial) .. "#" .. bump.spec
	if specScan and specKey == key then return specScan end
	local s = { bond5 = 0, nicks = 0, locks = 0, zones = {}, shinyZoneBest = 0, shinyDayBest = 0 }
	local byZone, byDay = {}, {}
	local level = self.SpecimenBondLevel
	for _, spec in pairs(Sub(capture, "specimens") or {}) do
		if type(spec) == "table" then
			if level and Num(Call(level, self, spec)) >= ns.FEAT_DRESSEUR.bond then s.bond5 = s.bond5 + 1 end
			if type(spec.nick) == "string" and spec.nick ~= "" then s.nicks = s.nicks + 1 end
			if spec.lock == true then s.locks = s.locks + 1 end
			local origin = spec.origin or "capture"
			local zone = tonumber(spec.zone)
			if zone and (origin == "capture" or origin == "migration") then s.zones[zone] = true end
			if spec.shiny then
				-- par zone : une capture de la 3.0 ou plus (une fiche migrée porte
				-- la zone de l'espèce, pas celle de la brillante)
				if zone and origin == "capture" then
					byZone[zone] = (byZone[zone] or 0) + 1
					if byZone[zone] > s.shinyZoneBest then s.shinyZoneBest = byZone[zone] end
				end
				local at = tonumber(spec.at)
				if at and at > 0 and (origin == "capture" or origin == "migration") then
					local day = Day(at)
					byDay[day] = (byDay[day] or 0) + 1
					if byDay[day] > s.shinyDayBest then s.shinyDayBest = byDay[day] end
				end
			end
		end
	end
	specScan, specKey = s, key
	return s
end
function ns:FeatDresseurSpecimens() return ScanSpecimens(self) end

-- 3. Fiches d'étude (SpecimenStudy.lua) : tailles et caractères par espèce,
-- records de taille, tâches, captures d'une même espèce, maîtrise par zone
local studyScan, studyKey
local function SizeIndex(id)
	for index, def in ipairs(ns.SPECIMEN_SIZES or {}) do if def.id == id then return index end end
	return nil
end
local function TaskCount(row)
	local need = ns.STUDY_NEED or { five = 5, sizes = 3, traits = 3 }
	local n = 0
	if Num(row.n) >= 1 then n = n + 1 end
	if row.s3 == true then n = n + 1 end
	if Num(row.n) >= need.five then n = n + 1 end
	if Count(row.z) >= need.sizes then n = n + 1 end
	if Count(row.t) >= need.traits then n = n + 1 end
	return n
end

local function ScanStudy(self)
	if self.SpecimenStudyRetro then pcall(self.SpecimenStudyRetro, self) end
	local capture = Capture(self)
	local study = Sub(capture, "study") or {}
	local key = tostring(study) .. ":" .. tostring(capture.specSerial) .. ":" .. tostring(capture.serial) .. "#" .. bump.spec
	if studyScan and studyKey == key then return studyScan end
	local s = { giant = 0, tiny = 0, allSizes = 0, twins = 0, indexMax = 0, indexMin = 0, traitRare = 0, allTraits = 0,
		tasks = 0, same = 0, shiny = 0, zoneMastered = 0 }
	local tiny, giant, sizes = SizeIndex("tiny"), SizeIndex("giant"), #(ns.SPECIMEN_SIZES or {})
	-- caractères des spécimens : leur rang dans PERSONALITY_ORDER (bits de t)
	local traitBits, rareBits = {}, {}
	local order = {}
	for index, id in ipairs(ns.PERSONALITY_ORDER or {}) do order[id] = index end
	for _, pair in ipairs(ns.SPECIMEN_TRAIT_WEIGHTS or {}) do
		local index = order[pair[1]]
		if index then
			traitBits[#traitBits + 1] = index
			if (ns.SPECIMEN_TRAIT_RARE or {})[pair[1]] then rareBits[#rareBits + 1] = index end
		end
	end
	local band = ns.SPECIMEN_SIZE_INDEX or {}
	local lowest = band.tiny and band.tiny[1] or 75
	local highest = band.giant and band.giant[2] or 125
	local creatures, byZone = Sub(capture, "creatures") or {}, {}
	for npc, row in pairs(study) do
		if type(row) == "table" then
			local z = row.z
			if giant and Has(z, giant) then s.giant = s.giant + 1 end
			if tiny and Has(z, tiny) then s.tiny = s.tiny + 1 end
			if sizes > 0 and Count(z) >= sizes then s.allSizes = 1 end
			if tiny and giant and Has(z, tiny) and Has(z, giant) then s.twins = 1 end
			if Num(row.hi) >= highest then s.indexMax = 1 end
			if row.lo ~= nil and Num(row.lo) <= lowest then s.indexMin = 1 end
			for _, bit in ipairs(rareBits) do if Has(row.t, bit) then s.traitRare = 1 end end
			local all = #traitBits > 0
			for _, bit in ipairs(traitBits) do if not Has(row.t, bit) then all = false; break end end
			if all then s.allTraits = 1 end
			local done = TaskCount(row)
			s.tasks = s.tasks + done
			if Num(row.n) > s.same then s.same = Num(row.n) end
			if row.sh == true then s.shiny = s.shiny + 1 end
			-- maîtrisée : comptée dans la zone de sa première capture (fiche de l'espèce)
			if done >= #(ns.STUDY_TASKS or { 1, 2, 3, 4, 5 }) then
				local entry = creatures[tonumber(npc) or npc]
				local zone = type(entry) == "table" and tonumber(entry.zoneID)
				if zone then
					byZone[zone] = (byZone[zone] or 0) + 1
					if byZone[zone] > s.zoneMastered then s.zoneMastered = byZone[zone] end
				end
			end
		end
	end
	studyScan, studyKey = s, key
	return s
end
function ns:FeatDresseurStudy() return ScanStudy(self) end

-- Les relevés gardés oubliés (tests)
function ns:FeatDresseurReset()
	creatureScan, creatureKey, specScan, specKey, studyScan, studyKey = nil, nil, nil, nil, nil, nil
end

-- Zones de capture : les preuves (fiches, spécimens) et le relevé captureZones
local function Tally(self, fn, key)
	local read = self[fn]
	if type(read) ~= "function" then return 0 end
	return Num(Call(read, self, key, A))
end
local function CaptureZones(self)
	local zones = {}
	for zone in pairs(ScanCreatures(self).zones) do zones[zone] = true end
	for zone in pairs(ScanSpecimens(self).zones) do zones[zone] = true end
	local n, extra = 0, 0
	for zone in pairs(zones) do
		n = n + 1
		if self.TallyHas and Call(self.TallyHas, self, "captureZones", zone, A) then extra = extra + 1 end
	end
	-- le relevé : ses zones qui ne sont pas déjà dans les preuves
	return zones, n + math.max(0, Tally(self, "TallySize", "captureZones") - extra)
end

-- Zones à sceau (avec une liste d'espèces) : gardées par table
local sealable, sealableOf
local function SealableZones()
	local t = ns.ZONE_CREATURES
	if sealableOf ~= t then
		sealable, sealableOf = {}, t
		for _, zone in ipairs(type(t) == "table" and ns.ZoneIds and ns.ZoneIds(t) or {}) do
			if tonumber(zone) then sealable[#sealable + 1] = tonumber(zone) end
		end
		table.sort(sealable)
	end
	return sealable
end
ns.FeatDresseurSealable = SealableZones

-- ---------------------------------------------------------------------------
-- Sources et listes
-- ---------------------------------------------------------------------------
local CAP = ns.FeatTopics("capture", "spec")
local SPEC = ns.FeatTopics("spec")
local SHOP = ns.FeatTopics("shop", "spec")
local function From(scan, field, topics)
	return { topics = topics or CAP, get = function(self) return Num(scan(self)[field]) end }
end

ns.FeatCatalog(function()
	-- Initiation : visites et tutoriel (rétroactifs)
	SOURCES.tourMeet = { topics = ns.FeatTopics("tour", "companion"), get = function(self)
		return EachCompanion(self, function(data) return data.tutoDone == true end) and 1 or 0
	end }
	for source, tour in pairs({ tourCapture = "capture", tourJournal = "journal" }) do
		SOURCES[source] = { topics = ns.FeatTopics("tour"), get = function(self)
			return (self.TourDone and Call(self.TourDone, self, tour) == true) and 1 or 0
		end }
	end
	-- partir avec une créature capturée (brillante : « :s ») : état, lu sur
	-- chaque personnage du compte
	local function Partner(shinyOnly)
		local pattern = shinyOnly and "^cap:%d+:s$" or "^cap:%d+"
		return { topics = ns.FeatTopics("companion", "minute"), get = function(self)
			return EachCompanion(self, function(data)
				return type(data.appearance) == "string" and data.appearance:find(pattern) ~= nil
			end) and 1 or 0
		end }
	end
	SOURCES.partnerCaptured, SOURCES.partnerShiny = Partner(false), Partner(true)
	-- un achat à l'Échoppe : état (le relevé shopBuy depuis la 3.7, et ce que
	-- la sauvegarde garde déjà : places, mécénat, cosmétiques, stock du jour)
	SOURCES.shopBought = { topics = ns.FeatTopics("shop", "tally"), get = function(self)
		if Tally(self, "TallyGet", "shopBuy") > 0 then return 1 end
		local c = Capture(self)
		if Num(c.slotBuys) > 0 or Num(c.reserveBonus) > 0 or Num(c.patron) > 0 then return 1 end
		if type(c.shopOwned) == "table" and next(c.shopOwned) ~= nil then return 1 end
		local day = Sub(c, "shopDay")
		if day and Num(day.appat) + Num(day.lasso) + Num(day.sifflet) > 0 then return 1 end
		return 0
	end }
	SOURCES.huntPins = { topics = SPEC, get = function(self)
		local pins = Sub(Capture(self), "pins")
		for _, on in pairs(pins or {}) do if on == true then return 1 end end
		return 0
	end }
	SOURCES.studyTasks = From(ScanStudy, "tasks")

	-- Créatures
	SOURCES.caught = { topics = CAP, get = function(self) return math.max(0, math.floor(Num(Capture(self).caught))) end }
	SOURCES.rareElite = From(ScanCreatures, "rareElite")
	SOURCES.level60 = From(ScanCreatures, "level60")
	SOURCES.medal4 = From(ScanCreatures, "medal4", ns.FeatTopics("capture", "seal"))
	SOURCES.medal5 = From(ScanCreatures, "medal5", ns.FeatTopics("capture", "seal"))
	SOURCES.captureZones = { topics = ns.FeatTopics("capture", "spec", "tally"), get = function(self)
		local _, n = CaptureZones(self)
		return n
	end }
	SOURCES.captureSealZones = { topics = ns.FeatTopics("capture", "spec", "tally"), get = function(self)
		local zones, n = CaptureZones(self), 0
		for _, zone in ipairs(SealableZones()) do
			if zones[zone] or (self.TallyHas and Call(self.TallyHas, self, "captureZones", zone, A)) then n = n + 1 end
		end
		return n
	end }
	-- les zones à sceau : élément i = au moins i zones (barre x/y)
	LISTS.captureSealZones = { topics = SOURCES.captureSealZones.topics, items = function()
		local items = {}
		for i = 1, #SealableZones() do items[i] = { "captureSealZones", i } end
		return items
	end }

	-- Spécimens (fiches d'étude, spécimens possédés)
	for _, field in ipairs({ "giant", "tiny", "allSizes", "twins", "indexMax", "indexMin", "traitRare", "allTraits", "same" }) do
		SOURCES["study" .. field:sub(1, 1):upper() .. field:sub(2)] = From(ScanStudy, field)
	end
	SOURCES.studyZone = From(ScanStudy, "zoneMastered")
	SOURCES.bond5 = From(ScanSpecimens, "bond5", SPEC)
	SOURCES.nicks = From(ScanSpecimens, "nicks", SPEC)
	SOURCES.locks = From(ScanSpecimens, "locks", SPEC)

	-- Brillantes
	for _, typeKey in ipairs(ns.CREATURE_TYPES or {}) do
		SOURCES["shinyType_" .. typeKey] = { topics = ns.FeatTopics("capture", "shiny"), get = function(self)
			return ScanCreatures(self).shinyTypes[typeKey] and 1 or 0
		end }
	end
	LISTS.shinyTypes = { topics = ns.FeatTopics("capture", "shiny"),
		items = function()
			local items = {}
			for i, typeKey in ipairs(ns.CREATURE_TYPES or {}) do items[i] = { "shinyType_" .. typeKey, 1 } end
			return items
		end,
		label = function(self, item)
			local typeKey = tostring(item[1]):match("^shinyType_(.+)$")
			return typeKey and self.CreatureTypeLabel and self:CreatureTypeLabel(typeKey) or nil
		end }
	local SHINY_TALLY = ns.FeatTopics("capture", "spec", "tally")
	SOURCES.shinyZoneBest = { topics = SHINY_TALLY, get = function(self)
		return math.max(ScanSpecimens(self).shinyZoneBest, Tally(self, "TallyBest", "shinyZoneBest"))
	end }
	SOURCES.shinyDayBest = { topics = SHINY_TALLY, get = function(self)
		return math.max(ScanSpecimens(self).shinyDayBest, Tally(self, "TallyBest", "shinyDayBest"))
	end }
	SOURCES.studyShiny = From(ScanStudy, "shiny")

	-- Réserve et Échoppe
	SOURCES.reserveSlots = { topics = SPEC, get = function(self)
		return self.ReserveCapacity and Num(Call(self.ReserveCapacity, self)) or 0
	end }
	SOURCES.reserveFull = { topics = SPEC, get = function(self)
		return (self.ReserveFull and Call(self.ReserveFull, self) == true) and 1 or 0
	end }
	SOURCES.glitterEarned = { topics = SHOP, get = function(self)
		return math.max(0, math.floor(Num(Capture(self).paillettesEarned)))
	end }
	SOURCES.arrivalsOwned = { topics = SHOP, get = function(self)
		local n = 0
		for _, item in ipairs(ns.PAILLETTES_SHOP or {}) do
			if item.arrival and self.ShopCosmeticOwned and Call(self.ShopCosmeticOwned, self, item.cosId) == true then n = n + 1 end
		end
		return n
	end }
end)

-- ---------------------------------------------------------------------------
-- Catalogue (codes définitifs : catalogue-lot.tsv)
-- ---------------------------------------------------------------------------
-- aides : tables partagées (lecture seule) pour les dons d'une unité
local ONE = {}
local function Aids(id, n)
	if n and n ~= 1 then return { [id] = n } end
	ONE[id] = ONE[id] or { [id] = 1 }
	return ONE[id]
end

-- Les autres lignes d'Initiation (init_all)
local INIT = { "init_meet", "init_net", "init_partner", "init_journal", "init_study", "init_radiant", "init_wish",
	"init_treat", "init_hunt", "init_release", "init_shop", "init_order", "init_aid", "init_pin", "init_follow" }

-- Séries : nouvelles échelles, ou prolongement d'une échelle déclarée
-- (ns.FEAT_SERIES : rare, stars3, study, shinyFound, shinyCap)
local SERIES = {
	caught = { "men_caught_100", "men_caught_500", "men_caught_2000", "men_caught_5000", "men_caught_10000" },
	elite = { "men_elite_10", "men_elite_50", "men_elite_150" },
	rare = { "men_rare_25", "men_rare_50" },
	medal4 = { "men_medal4_1", "men_medal4_all" },
	medal5 = { "men_medal5_1", "men_medal5_all" },
	captureZones = { "men_zones_10", "men_zones_25" },
	captureStreak = { "men_streak_10", "men_streak_25" },
	captureHunt = { "men_hunt_100", "men_hunt_1000" },
	stars3 = { "spec_stars3_250" },
	study = { "spec_study_250", "spec_study_500" },
	bond5 = { "spec_bond_3", "spec_bond_10" },
	nicks = { "spec_nick_1", "spec_nick_10" },
	studySame = { "spec_same_25", "spec_same_100" },
	shinySeen = { "shiny_seen_25", "shiny_seen_100" },
	shinyFound = { "shiny_found_100", "shiny_found_250" },
	shinyCap = { "shiny_cap_50", "shiny_cap_100" },
	shinyZones = { "shiny_zones_25" },
	release = { "shop_release_50", "shop_release_500", "shop_release_2500" },
	glitter = { "shop_glitter_500", "shop_glitter_5000", "shop_glitter_25000", "shop_glitter_100000" },
	glitterSpent = { "shop_spent_1000", "shop_spent_10000" },
	orders = { "shop_order_10", "shop_order_50", "shop_order_150" },
	orderWeek = { "shop_order_week", "shop_order_week_10" },
}
-- premier palier d'une échelle nouvelle, déjà au catalogue (identifiant,
-- code et points inchangés : il rejoint seulement le groupe à l'écran)
ns.FEAT_DRESSEUR_ATTACH = { men_elite_1 = "elite", shiny_seen_1 = "shinySeen", shiny_zones_10 = "shinyZones" }

ns.FEAT_DRESSEUR_IDS = {}
ns.FeatCatalog(function()
	local ROWS = {
		-- Initiation
		{ "init_meet",     244, "init", 5,  A, crit = { "count", "tourMeet", 1 } },
		{ "init_net",      245, "init", 5,  A, crit = { "count", "tourCapture", 1 }, reward = { aids = Aids("appat", 2) } },
		{ "init_partner",  246, "init", 5,  A, crit = { "count", "partnerCaptured", 1 } },
		{ "init_journal",  247, "init", 5,  A, crit = { "count", "tourJournal", 1 } },
		{ "init_study",    248, "init", 5,  A, crit = { "count", "studyTasks", 1 } },
		{ "init_radiant",  249, "init", 5,  A, crit = { "tally", "radiant", 1, "char" } },
		{ "init_wish",     250, "init", 5,  A, crit = { "tally", "wish", 1, "char" } },
		{ "init_treat",    251, "init", 5,  A, crit = { "tally", "treat", 1, "char" } },
		{ "init_hunt",     252, "init", 5,  A, crit = { "tally", "huntStart", 1 } },
		{ "init_release",  253, "init", 5,  A, crit = { "tally", "release", 1 } },
		{ "init_shop",     254, "init", 5,  A, crit = { "count", "shopBought", 1 } },
		{ "init_order",    255, "init", 5,  A, crit = { "tally", "orderDone", 1 } },
		{ "init_aid",      256, "init", 5,  A, crit = { "tally", "captureAided", 1 } },
		{ "init_pin",      257, "init", 5,  A, crit = { "count", "huntPins", 1 } },
		-- le moteur pose le compteur au premier suivi (Feats.lua, ns:FeatFollow)
		{ "init_follow",   258, "init", 5,  A, crit = { "tally", "follow", 1 } },
		{ "init_all",      259, "init", 10, A, crit = { "meta", INIT }, reward = { title = 50, aids = Aids("lasso", 2) } },
		-- Créatures
		{ "men_caught_100",   260, "men", 5,  A, crit = { "count", "caught", 100 } },
		{ "men_caught_500",   261, "men", 10, A, crit = { "count", "caught", 500 },   reward = { aids = Aids("lasso") } },
		{ "men_caught_2000",  262, "men", 10, A, crit = { "count", "caught", 2000 },  reward = { aids = Aids("sifflet") } },
		{ "men_caught_5000",  263, "men", 25, A, crit = { "count", "caught", 5000 } },
		{ "men_caught_10000", 264, "men", 25, A, crit = { "count", "caught", 10000 }, reward = { title = 51 } },
		{ "men_elite_10",     265, "men", 10, A, crit = { "count", "elite", 10 },     reward = { aids = Aids("lasso") } },
		{ "men_elite_50",     266, "men", 25, A, crit = { "count", "elite", 50 } },
		{ "men_elite_150",    267, "men", 50, A, crit = { "count", "elite", 150 },    reward = { title = 52 } },
		{ "men_rare_25",      268, "men", 25, A, crit = { "count", "rare", 25 },      reward = { aids = Aids("sifflet") } },
		{ "men_rare_50",      269, "men", 50, A, crit = { "count", "rare", 50 },      reward = { soon = { "orn", "feat_rarities" } } },
		{ "men_rareelite_1",  270, "men", 10, A, crit = { "count", "rareElite", 1 } },
		{ "men_medal4_1",     271, "men", 10, A, crit = { "count", "medal4", 1 } },
		{ "men_medal4_all",   272, "men", 25, A, crit = { "count", "medal4", 8 },     reward = { soon = { "cardframe", "card_eight" } } },
		{ "men_medal5_1",     273, "men", 25, A, crit = { "count", "medal5", 1 } },
		{ "men_medal5_all",   274, "men", 50, A, crit = { "count", "medal5", 8 },     reward = { title = 53 } },
		{ "men_zones_10",     275, "men", 10, A, crit = { "count", "captureZones", 10 } },
		{ "men_zones_25",     276, "men", 25, A, crit = { "count", "captureZones", 25 } },
		{ "men_zones_all",    277, "men", 25, A, crit = { "list", "captureSealZones" } },
		{ "men_level60",      278, "men", 10, A, crit = { "count", "level60", 1 } },
		{ "men_streak_10",    279, "men", 10, A, crit = { "tallymax", "captureStreak", 10 } },
		{ "men_streak_25",    280, "men", 25, A, crit = { "tallymax", "captureStreak", 25 } },
		{ "men_batch_10",     281, "men", 25, A, crit = { "tallymax", "batch", 10 } },
		{ "men_hunt_100",     282, "men", 10, A, crit = { "tally", "captureHunt", 100 } },
		{ "men_hunt_1000",    283, "men", 25, A, crit = { "tally", "captureHunt", 1000 } },
		{ "men_aid_50",       284, "men", 5,  A, crit = { "tally", "aidUsed", 50 } },
		{ "men_whistle_10",   285, "men", 10, A, crit = { "tally", "captureWhistle", 10 } },
		{ "men_noaid_rare",   286, "men", 10, A, crit = { "tally", "rareNoAid", 1 } },
		{ "men_fail_100",     287, "men", 5,  A, crit = { "tally", "captureFail", 100 } },
		-- Spécimens
		{ "spec_stars3_250",    288, "spec", 50, A, crit = { "count", "stars3", 250 }, reward = { soon = { "frame", "feat_starry" } } },
		{ "spec_giant_10",      289, "spec", 25, A, crit = { "count", "studyGiant", 10 } },
		{ "spec_tiny_10",       290, "spec", 25, A, crit = { "count", "studyTiny", 10 } },
		{ "spec_sizes_species", 291, "spec", 25, A, crit = { "count", "studyAllSizes", 1 } },
		{ "spec_twins",         292, "spec", 10, A, crit = { "count", "studyTwins", 1 } },
		{ "spec_index_max",     293, "spec", 10, A, crit = { "count", "studyIndexMax", 1 } },
		{ "spec_index_min",     294, "spec", 10, A, crit = { "count", "studyIndexMin", 1 } },
		{ "spec_trait_rare",    295, "spec", 5,  A, crit = { "count", "studyTraitRare", 1 } },
		{ "spec_traits_species", 296, "spec", 25, A, crit = { "count", "studyAllTraits", 1 } },
		{ "spec_contest",       297, "spec", 25, A, crit = { "tally", "contest", 1 }, reward = { soon = { "orn", "feat_contest" } } },
		{ "spec_tasks_50",      298, "spec", 5,  A, crit = { "count", "studyTasks", 50 } },
		{ "spec_study_250",     299, "spec", 50, A, crit = { "count", "studyMastered", 250 }, reward = { title = 54 } },
		{ "spec_study_500",     300, "spec", 50, A, crit = { "count", "studyMastered", 500 }, reward = { soon = { "cardbg", "card_zoology" } } },
		{ "spec_study_zone",    301, "spec", 25, A, crit = { "count", "studyZone", 25 } },
		{ "spec_bond_3",        302, "spec", 25, A, crit = { "count", "bond5", 3 } },
		{ "spec_bond_10",       303, "spec", 50, A, crit = { "count", "bond5", 10 }, reward = { title = 55 } },
		{ "spec_bond_1000",     304, "spec", 10, A, crit = { "tally", "bondPoints", 1000 } },
		{ "spec_nick_1",        305, "spec", 5,  A, crit = { "count", "nicks", 1 } },
		{ "spec_nick_10",       306, "spec", 10, A, crit = { "count", "nicks", 10 } },
		{ "spec_lock_10",       307, "spec", 5,  A, crit = { "count", "locks", 10 } },
		{ "spec_same_25",       308, "spec", 10, A, crit = { "count", "studySame", 25 } },
		{ "spec_same_100",      309, "spec", 25, A, crit = { "count", "studySame", 100 } },
		-- Brillantes
		{ "shiny_seen_25",   310, "shiny", 5,  A, crit = { "count", "shinySeen", 25 } },
		{ "shiny_seen_100",  311, "shiny", 10, A, crit = { "count", "shinySeen", 100 } },
		{ "shiny_found_100", 312, "shiny", 25, A, crit = { "count", "shinyFound", 100 }, reward = { soon = { "bg", "feat_sparkle" } } },
		{ "shiny_found_250", 313, "shiny", 50, A, crit = { "count", "shinyFound", 250 }, reward = { title = 56 } },
		{ "shiny_cap_50",    314, "shiny", 50, A, crit = { "count", "shinyCap", 50 },    reward = { soon = { "cardframe", "card_prism" } } },
		{ "shiny_cap_100",   315, "shiny", 50, A, crit = { "count", "shinyCap", 100 },   reward = { title = 57 } },
		{ "shiny_types",     316, "shiny", 25, A, crit = { "list", "shinyTypes" } },
		{ "shiny_zone_5",    317, "shiny", 10, A, crit = { "count", "shinyZoneBest", 5 } },
		{ "shiny_day_2",     318, "shiny", 10, A, crit = { "count", "shinyDayBest", 2 } },
		{ "shiny_chain",     319, "shiny", 10, A, crit = { "tallymax", "shinyChain", 50 } },
		{ "shiny_zones_25",  320, "shiny", 25, A, crit = { "count", "shinyZones", 25 } },
		{ "shiny_partner",   321, "shiny", 5,  A, crit = { "count", "partnerShiny", 1 } },
		{ "shiny_rare_size", 322, "shiny", 25, A, crit = { "tally", "shinyRareSize", 1 }, reward = { soon = { "orn", "feat_rare_size" } } },
		{ "shiny_study_10",  323, "shiny", 10, A, crit = { "count", "studyShiny", 10 } },
		-- Réserve et Échoppe
		{ "shop_slots_max",      378, "shop", 25, A, crit = { "count", "reserveSlots", 150 } },
		{ "shop_full",           379, "shop", 5,  A, crit = { "count", "reserveFull", 1 } },
		{ "shop_release_50",     380, "shop", 5,  A, crit = { "tally", "release", 50 } },
		{ "shop_release_500",    381, "shop", 10, A, crit = { "tally", "release", 500 } },
		{ "shop_release_2500",   382, "shop", 25, A, crit = { "tally", "release", 2500 } },
		{ "shop_tidy",           383, "shop", 5,  A, crit = { "tallymax", "releaseBatch", 10 } },
		{ "shop_glitter_500",    384, "shop", 5,  A, crit = { "count", "glitterEarned", 500 } },
		{ "shop_glitter_5000",   385, "shop", 10, A, crit = { "count", "glitterEarned", 5000 } },
		{ "shop_glitter_25000",  386, "shop", 25, A, crit = { "count", "glitterEarned", 25000 } },
		{ "shop_glitter_100000", 387, "shop", 50, A, crit = { "count", "glitterEarned", 100000 }, reward = { soon = { "orn", "feat_glitter" } } },
		{ "shop_spent_1000",     388, "shop", 10, A, crit = { "tally", "glitterSpent", 1000 } },
		{ "shop_spent_10000",    389, "shop", 25, A, crit = { "tally", "glitterSpent", 10000 } },
		{ "shop_order_10",       390, "shop", 10, A, crit = { "tally", "orderDone", 10 } },
		{ "shop_order_50",       391, "shop", 25, A, crit = { "tally", "orderDone", 50 } },
		{ "shop_order_150",      392, "shop", 50, A, crit = { "tally", "orderDone", 150 }, reward = { title = 58 } },
		{ "shop_order_week",     393, "shop", 10, A, crit = { "tally", "orderWeek", 1 } },
		{ "shop_order_week_10",  394, "shop", 25, A, crit = { "tally", "orderWeek", 10 } },
		{ "shop_arrivals_all",   395, "shop", 25, A, crit = { "count", "arrivalsOwned", 8 } },
		{ "shop_aids_100",       396, "shop", 10, A, crit = { "tally", "aidBought", 100 } },
	}
	local seriesOf = {}
	for key, ids in pairs(SERIES) do for _, id in ipairs(ids) do seriesOf[id] = key end end
	for _, row in ipairs(ROWS) do
		row.desc = row.desc or ("FEATD_" .. row[1])
		row.series = row.series or seriesOf[row[1]]
		ns.FeatAdd(row)
		ns.FEAT_DRESSEUR_IDS[#ns.FEAT_DRESSEUR_IDS + 1] = row[1]
	end
	for _, def in ipairs(ns.FEAT_DEFS) do
		local key = ns.FEAT_DRESSEUR_ATTACH[def.id]
		if key and def.series == nil then def.series = key end
	end
	-- cosmétiques à venir (étape 2) : reward.soon, changés dès qu'ils existent
	if ns.FeatResolveSoon then ns.FeatResolveSoon() end
end)

-- ---------------------------------------------------------------------------
-- Événements : relevés manquants et sujets des lignes « état »
-- ---------------------------------------------------------------------------
local function Touch(self, topic)
	if Awake() and self.FeatTouch then self:FeatTouch(topic) end
end

-- Une capture (spécimen « capture ») : sa zone, ses brillantes par zone et
-- par jour (relevés de ce fichier, sur Tally.lua)
function ns:FeatDresseurNote(spec)
	if type(spec) ~= "table" or (spec.origin or "capture") ~= "capture" then return false end
	local zone = tonumber(spec.zone)
	if zone and self.TallyMark then self:TallyMark("captureZones", zone, A, 200) end
	if spec.shiny then
		if zone and self.TallyAdd and self.TallyMax then
			self:TallyMax("shinyZoneBest", self:TallyAdd("shinyCapZone:" .. zone, 1, A), A)
		end
		local store = self:FeatStore(A)
		local today = Day(tonumber(spec.at) or Time())
		local seen = type(store.dresseurShinyDay) == "table" and store.dresseurShinyDay or {}
		if seen.d ~= today then seen = { d = today, n = 0 } end
		seen.n = Num(seen.n) + 1
		store.dresseurShinyDay = seen
		if self.TallyMax then self:TallyMax("shinyDayBest", seen.n, A) end
	end
	return true
end

if ns.RegisterCallback then
	ns:RegisterCallback("SPECIMENS", function(self, what, id)
		bump.spec = bump.spec + 1
		if not Awake() then return end
		if what == "add" and self.SpecimenGet then self:FeatDresseurNote(self:SpecimenGet(id)) end
		Touch(self, "spec")
	end)
	ns:RegisterCallback("BOND", function(self)
		bump.spec = bump.spec + 1
		Touch(self, "spec")
	end)
	ns:RegisterCallback("PAILLETTES", function(self) Touch(self, "shop") end)
end

-- Enveloppes : la fonction d'origine, puis le sujet (retours intacts)
local function Pass(topic, ...)
	Touch(ns, topic)
	return ...
end
local function WrapTouch(name, topic)
	local base = ns[name]
	if type(base) ~= "function" then return false end
	ns[name] = function(self, ...) return Pass(topic, base(self, ...)) end
	return true
end

local hooked = false
function ns:FeatDresseurHook()
	if hooked then return false end
	hooked = true
	WrapTouch("TourFinish", "tour")                  -- visite guidée vue (GuidedTour.lua)
	WrapTouch("CompanionFinishTutorial", "tour")     -- tutoriel du compagnon fini (Companion.lua)
	WrapTouch("CompanionSetAppearance", "companion") -- apparence choisie
	WrapTouch("ShopCosmeticGrant", "shop")           -- cosmétique de l'Échoppe (achat, commandes)
	return true
end

do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and frame then
		frame:RegisterEvent("ADDON_LOADED")
		frame:SetScript("OnEvent", function(f, _, name)
			if name ~= ADDON then return end
			if f.UnregisterEvent then f:UnregisterEvent("ADDON_LOADED") end
			local done, err = pcall(ns.FeatDresseurHook, ns)
			if not done and ns.RecordError then ns:RecordError("feats:dresseur", err) end
		end)
		ns.featDresseurFrame = frame
	end
end

-- ---------------------------------------------------------------------------
-- Chaînes : noms (FEAT_<id>) et descriptions (FEATD_<id>)
-- ---------------------------------------------------------------------------
local FR = {
	FEAT_init_meet         = "Faisons connaissance",
	FEAT_init_net          = "Leçon de filet",
	FEAT_init_partner      = "En route ensemble",
	FEAT_init_journal      = "Carnet ouvert",
	FEAT_init_study        = "Première leçon",
	FEAT_init_radiant      = "Rayonnant !",
	FEAT_init_wish         = "À tes souhaits",
	FEAT_init_treat        = "Petite douceur",
	FEAT_init_hunt         = "Ouverture de la chasse",
	FEAT_init_release      = "Rendu à la nature",
	FEAT_init_shop         = "Premier achat",
	FEAT_init_order        = "Bon de livraison",
	FEAT_init_aid          = "Coup de pouce",
	FEAT_init_pin          = "Avis de recherche",
	FEAT_init_follow       = "Cap fixé",
	FEAT_init_all          = "Dresseur diplômé",
	FEAT_men_caught_100    = "Cent prises",
	FEAT_men_caught_500    = "Cinq cents prises",
	FEAT_men_caught_2000   = "Deux mille prises",
	FEAT_men_caught_5000   = "Le filet ne chôme pas",
	FEAT_men_caught_10000  = "Dix mille prises",
	FEAT_men_elite_10      = "Dix gros gibiers",
	FEAT_men_elite_50      = "Tableau de chasse",
	FEAT_men_elite_150     = "La fine fleur",
	FEAT_men_rare_25       = "Galerie des raretés",
	FEAT_men_rare_50       = "L'œil du collectionneur",
	FEAT_men_rareelite_1   = "Rare et coriace",
	FEAT_men_medal4_1      = "Spécialiste",
	FEAT_men_medal4_all    = "Huit spécialités",
	FEAT_men_medal5_1      = "Sommité",
	FEAT_men_medal5_all    = "Les huit sommets",
	FEAT_men_zones_10      = "Dix terrains de chasse",
	FEAT_men_zones_25      = "Chasseur itinérant",
	FEAT_men_zones_all     = "Partout chez soi",
	FEAT_men_level60       = "Gibier de taille",
	FEAT_men_streak_10     = "Main chaude",
	FEAT_men_streak_25     = "Rien ne m'échappe",
	FEAT_men_batch_10      = "Grande volée",
	FEAT_men_hunt_100      = "Saison de chasse",
	FEAT_men_hunt_1000     = "Grand veneur",
	FEAT_men_aid_50        = "Trousse bien remplie",
	FEAT_men_whistle_10    = "Maître siffleur",
	FEAT_men_noaid_rare    = "À mains nues",
	FEAT_men_fail_100      = "Persévérant",
	FEAT_spec_stars3_250   = "Voûte étoilée",
	FEAT_spec_giant_10     = "Dix géants",
	FEAT_spec_tiny_10      = "Dix minuscules",
	FEAT_spec_sizes_species = "La gamme complète",
	FEAT_spec_twins        = "David et Goliath",
	FEAT_spec_index_max    = "Hors gabarit",
	FEAT_spec_index_min    = "Poids plume",
	FEAT_spec_trait_rare   = "Perle rare",
	FEAT_spec_traits_species = "Tous les tempéraments",
	FEAT_spec_contest      = "Bête de concours",
	FEAT_spec_tasks_50     = "Bon élève",
	FEAT_spec_study_250    = "Bibliothèque vivante",
	FEAT_spec_study_500    = "Somme zoologique",
	FEAT_spec_study_zone   = "Monographie",
	FEAT_spec_bond_3       = "Trois inséparables",
	FEAT_spec_bond_10      = "Cercle d'amis",
	FEAT_spec_bond_1000    = "Kilomètres d'amitié",
	FEAT_spec_nick_1       = "Petit nom",
	FEAT_spec_nick_10      = "Chacun son nom",
	FEAT_spec_lock_10      = "Sous bonne garde",
	FEAT_spec_same_25      = "Idée fixe",
	FEAT_spec_same_100     = "Monomanie",
	FEAT_shiny_seen_25     = "Œil exercé",
	FEAT_shiny_seen_100    = "Rien ne t'échappe",
	FEAT_shiny_found_100   = "Cent éclats",
	FEAT_shiny_found_250   = "Pluie d'étoiles",
	FEAT_shiny_cap_50      = "Salle du trésor",
	FEAT_shiny_cap_100     = "Cent trésors",
	FEAT_shiny_types       = "Huit éclats",
	FEAT_shiny_zone_5      = "Filon",
	FEAT_shiny_day_2       = "Jour de chance",
	FEAT_shiny_chain       = "Au bout de la série",
	FEAT_shiny_zones_25    = "Azeroth scintille",
	FEAT_shiny_partner     = "Compagnon de gala",
	FEAT_shiny_rare_size   = "Brillante hors norme",
	FEAT_shiny_study_10    = "Étude en or",
	FEAT_shop_slots_max    = "Réserve comble",
	FEAT_shop_full         = "Plus une place",
	FEAT_shop_release_50   = "Retour aux champs",
	FEAT_shop_release_500  = "Grand lâcher",
	FEAT_shop_release_2500 = "Repeupleur d'Azeroth",
	FEAT_shop_tidy         = "Grand ménage",
	FEAT_shop_glitter_500  = "Premières paillettes",
	FEAT_shop_glitter_5000 = "Bourse scintillante",
	FEAT_shop_glitter_25000 = "Coffre scintillant",
	FEAT_shop_glitter_100000 = "Pluie de paillettes",
	FEAT_shop_spent_1000   = "Panier percé",
	FEAT_shop_spent_10000  = "Grand train",
	FEAT_shop_order_10     = "Dix livraisons",
	FEAT_shop_order_50     = "Cinquante livraisons",
	FEAT_shop_order_150    = "Cent cinquante livraisons",
	FEAT_shop_order_week   = "Semaine pleine",
	FEAT_shop_order_week_10 = "Dix semaines pleines",
	FEAT_shop_arrivals_all = "Client fidèle",
	FEAT_shop_aids_100     = "Bon client",
	FEATD_init_meet        = "Finir la présentation du compagnon",
	FEATD_init_net         = "Finir la visite de la capture",
	FEATD_init_partner     = "Partir avec une créature que tu as capturée",
	FEATD_init_journal     = "Finir la visite du carnet",
	FEATD_init_study       = "Finir une tâche d'étude",
	FEATD_init_radiant     = "Rendre ton compagnon Rayonnant",
	FEATD_init_wish        = "Combler une envie du compagnon",
	FEATD_init_treat       = "Donner une friandise",
	FEATD_init_hunt        = "Lancer le mode chasse",
	FEATD_init_release     = "Relâcher un spécimen",
	FEATD_init_shop        = "Acheter un article à l'Échoppe",
	FEATD_init_order       = "Livrer une commande",
	FEATD_init_aid         = "Capturer une créature avec une aide",
	FEATD_init_pin         = "Ajouter une espèce à ta liste de chasse",
	FEATD_init_follow      = "Suivre un haut fait à l'écran",
	FEATD_init_all         = "Obtenir tous les hauts faits d'Initiation",
	FEATD_men_caught_100   = "Capturer 100 créatures (tous spécimens)",
	FEATD_men_caught_500   = "Capturer 500 créatures",
	FEATD_men_caught_2000  = "Capturer 2 000 créatures",
	FEATD_men_caught_5000  = "Capturer 5 000 créatures",
	FEATD_men_caught_10000 = "Capturer 10 000 créatures",
	FEATD_men_elite_10     = "Capturer 10 élites différentes",
	FEATD_men_elite_50     = "Capturer 50 élites différentes",
	FEATD_men_elite_150    = "Capturer 150 élites différentes",
	FEATD_men_rare_25      = "Capturer 25 rares ou rares élites",
	FEATD_men_rare_50      = "Capturer 50 rares ou rares élites",
	FEATD_men_rareelite_1  = "Capturer une rare élite",
	FEATD_men_medal4_1     = "Atteindre le palier 4 dans un type de créature",
	FEATD_men_medal4_all   = "Atteindre le palier 4 dans les 8 types",
	FEATD_men_medal5_1     = "Atteindre le palier 5 dans un type de créature",
	FEATD_men_medal5_all   = "Atteindre le palier 5 dans les 8 types",
	FEATD_men_zones_10     = "Capturer des créatures dans 10 zones différentes",
	FEATD_men_zones_25     = "Capturer des créatures dans 25 zones différentes",
	FEATD_men_zones_all    = "Capturer des créatures dans les %d zones à sceau",
	FEATD_men_level60      = "Capturer une créature de niveau 60 ou plus",
	FEATD_men_streak_10    = "Réussir 10 captures de suite",
	FEATD_men_streak_25    = "Réussir 25 captures de suite",
	FEATD_men_batch_10     = "Prendre 10 créatures en une seule volée « Tout capturer »",
	FEATD_men_hunt_100     = "Capturer 100 créatures en mode chasse",
	FEATD_men_hunt_1000    = "Capturer 1 000 créatures en mode chasse",
	FEATD_men_aid_50       = "Utiliser 50 aides de capture",
	FEATD_men_whistle_10   = "Capturer 10 créatures au Sifflet",
	FEATD_men_noaid_rare   = "Capturer une rare ou une rare élite sans aide",
	FEATD_men_fail_100     = "Rater 100 captures (au total)",
	FEATD_spec_stars3_250  = "Avoir 250 espèces capturées à 3 étoiles",
	FEATD_spec_giant_10    = "Capturer un Géant de 10 espèces différentes",
	FEATD_spec_tiny_10     = "Capturer un Minuscule de 10 espèces différentes",
	FEATD_spec_sizes_species = "Capturer les 5 tailles d'une même espèce",
	FEATD_spec_twins       = "Capturer un Minuscule et un Géant de la même espèce",
	FEATD_spec_index_max   = "Capturer un spécimen d'indice de taille 125",
	FEATD_spec_index_min   = "Capturer un spécimen d'indice de taille 75",
	FEATD_spec_trait_rare  = "Capturer un Zen ou un Espiègle (1 sur 10)",
	FEATD_spec_traits_species = "Capturer les 8 caractères d'une même espèce",
	FEATD_spec_contest     = "Un spécimen à 3 étoiles et de taille rare (1 sur 357)",
	FEATD_spec_tasks_50    = "Finir 50 tâches d'étude",
	FEATD_spec_study_250   = "Maîtriser l'étude de 250 espèces",
	FEATD_spec_study_500   = "Maîtriser l'étude de 500 espèces",
	FEATD_spec_study_zone  = "Maîtriser 25 espèces d'une même zone",
	FEATD_spec_bond_3      = "Avoir 3 spécimens au lien Inséparable",
	FEATD_spec_bond_10     = "Avoir 10 spécimens au lien Inséparable",
	FEATD_spec_bond_1000   = "Gagner 1 000 points de lien (au total)",
	FEATD_spec_nick_1      = "Donner un surnom à un spécimen",
	FEATD_spec_nick_10     = "Avoir 10 spécimens surnommés",
	FEATD_spec_lock_10     = "Protéger 10 spécimens",
	FEATD_spec_same_25     = "Capturer 25 fois la même espèce",
	FEATD_spec_same_100    = "Capturer 100 fois la même espèce",
	FEATD_shiny_seen_25    = "Repérer 25 brillantes",
	FEATD_shiny_seen_100   = "Repérer 100 brillantes",
	FEATD_shiny_found_100  = "Trouver 100 brillantes",
	FEATD_shiny_found_250  = "Trouver 250 brillantes",
	FEATD_shiny_cap_50     = "Capturer 50 brillantes",
	FEATD_shiny_cap_100    = "Capturer 100 brillantes",
	FEATD_shiny_types      = "Capturer une brillante de chacun des %d types",
	FEATD_shiny_zone_5     = "Capturer 5 brillantes dans une même zone",
	FEATD_shiny_day_2      = "Capturer 2 brillantes le même jour",
	FEATD_shiny_chain      = "Trouver une brillante avec la série de chasse au maximum (50 abattus)",
	FEATD_shiny_zones_25   = "Trouver des brillantes dans 25 zones différentes",
	FEATD_shiny_partner    = "Partir avec une créature brillante",
	FEATD_shiny_rare_size  = "Capturer une brillante Géante ou Minuscule (1 sur 3 750)",
	FEATD_shiny_study_10   = "Finir la tâche « brillante » de 10 espèces",
	FEATD_shop_slots_max   = "Agrandir la Réserve jusqu'à 150 places",
	FEATD_shop_full        = "Remplir la Réserve",
	FEATD_shop_release_50  = "Relâcher 50 spécimens",
	FEATD_shop_release_500 = "Relâcher 500 spécimens",
	FEATD_shop_release_2500 = "Relâcher 2 500 spécimens",
	FEATD_shop_tidy        = "Relâcher 10 spécimens d'un coup",
	FEATD_shop_glitter_500 = "Gagner 500 paillettes (au total)",
	FEATD_shop_glitter_5000 = "Gagner 5 000 paillettes",
	FEATD_shop_glitter_25000 = "Gagner 25 000 paillettes",
	FEATD_shop_glitter_100000 = "Gagner 100 000 paillettes",
	FEATD_shop_spent_1000  = "Dépenser 1 000 paillettes",
	FEATD_shop_spent_10000 = "Dépenser 10 000 paillettes",
	FEATD_shop_order_10    = "Livrer 10 commandes",
	FEATD_shop_order_50    = "Livrer 50 commandes",
	FEATD_shop_order_150   = "Livrer 150 commandes",
	FEATD_shop_order_week  = "Livrer les 3 commandes d'une même semaine",
	FEATD_shop_order_week_10 = "Livrer les 3 commandes de 10 semaines",
	FEATD_shop_arrivals_all = "Posséder les 8 cosmétiques d'arrivage",
	FEATD_shop_aids_100    = "Acheter 100 aides à l'Échoppe",
}
local EN = {
	FEAT_init_meet         = "Nice to Meet You",
	FEAT_init_net          = "Net Practice",
	FEAT_init_partner      = "Off We Go",
	FEAT_init_journal      = "Open Book",
	FEAT_init_study        = "First Lesson",
	FEAT_init_radiant      = "All Aglow!",
	FEAT_init_wish         = "Wish Granted",
	FEAT_init_treat        = "Sweet Tooth",
	FEAT_init_hunt         = "Open Season",
	FEAT_init_release      = "Back to the Wild",
	FEAT_init_shop         = "First Purchase",
	FEAT_init_order        = "Special Delivery",
	FEAT_init_aid          = "A Helping Hand",
	FEAT_init_pin          = "Wanted Poster",
	FEAT_init_follow       = "Eyes on the Prize",
	FEAT_init_all          = "Graduate Trainer",
	FEAT_men_caught_100    = "A Hundred Catches",
	FEAT_men_caught_500    = "Five Hundred Catches",
	FEAT_men_caught_2000   = "Two Thousand Catches",
	FEAT_men_caught_5000   = "The Net Never Rests",
	FEAT_men_caught_10000  = "Ten Thousand Catches",
	FEAT_men_elite_10      = "Ten Trophies",
	FEAT_men_elite_50      = "Trophy Wall",
	FEAT_men_elite_150     = "Cream of the Crop",
	FEAT_men_rare_25       = "Gallery of Rarities",
	FEAT_men_rare_50       = "A Collector's Eye",
	FEAT_men_rareelite_1   = "Rare and Tough",
	FEAT_men_medal4_1      = "Specialist",
	FEAT_men_medal4_all    = "Eight Specialties",
	FEAT_men_medal5_1      = "Leading Authority",
	FEAT_men_medal5_all    = "The Eight Summits",
	FEAT_men_zones_10      = "Ten Hunting Grounds",
	FEAT_men_zones_25      = "Roaming Hunter",
	FEAT_men_zones_all     = "At Home Everywhere",
	FEAT_men_level60       = "Prime Quarry",
	FEAT_men_streak_10     = "Hot Hand",
	FEAT_men_streak_25     = "Nothing Gets Away",
	FEAT_men_batch_10      = "Mighty Haul",
	FEAT_men_hunt_100      = "Hunting Season",
	FEAT_men_hunt_1000     = "Master of the Hunt",
	FEAT_men_aid_50        = "Well-Stocked Kit",
	FEAT_men_whistle_10    = "Whistle Master",
	FEAT_men_noaid_rare    = "Bare-Handed",
	FEAT_men_fail_100      = "If at First You Don't Succeed",
	FEAT_spec_stars3_250   = "Starry Vault",
	FEAT_spec_giant_10     = "Ten Giants",
	FEAT_spec_tiny_10      = "Ten Tiny Ones",
	FEAT_spec_sizes_species = "The Full Range",
	FEAT_spec_twins        = "Little and Large",
	FEAT_spec_index_max    = "Off the Charts",
	FEAT_spec_index_min    = "Featherweight",
	FEAT_spec_trait_rare   = "A Rare Gem",
	FEAT_spec_traits_species = "Every Temperament",
	FEAT_spec_contest      = "Best in Show",
	FEAT_spec_tasks_50     = "Star Pupil",
	FEAT_spec_study_250    = "Living Library",
	FEAT_spec_study_500    = "Zoological Compendium",
	FEAT_spec_study_zone   = "Monograph",
	FEAT_spec_bond_3       = "Three Inseparables",
	FEAT_spec_bond_10      = "Circle of Friends",
	FEAT_spec_bond_1000    = "Miles of Friendship",
	FEAT_spec_nick_1       = "Pet Name",
	FEAT_spec_nick_10      = "A Name for Everyone",
	FEAT_spec_lock_10      = "Under Lock and Key",
	FEAT_spec_same_25      = "One-Track Mind",
	FEAT_spec_same_100     = "Obsession",
	FEAT_shiny_seen_25     = "Trained Eye",
	FEAT_shiny_seen_100    = "Hawk-Eyed",
	FEAT_shiny_found_100   = "A Hundred Sparkles",
	FEAT_shiny_found_250   = "Shower of Stars",
	FEAT_shiny_cap_50      = "Treasure Room",
	FEAT_shiny_cap_100     = "A Hundred Treasures",
	FEAT_shiny_types       = "Eight Gleams",
	FEAT_shiny_zone_5      = "Mother Lode",
	FEAT_shiny_day_2       = "Lucky Day",
	FEAT_shiny_chain       = "End of the Chain",
	FEAT_shiny_zones_25    = "Azeroth Sparkles",
	FEAT_shiny_partner     = "Dressed to Dazzle",
	FEAT_shiny_rare_size   = "Sparkling Oddity",
	FEAT_shiny_study_10    = "A Study in Gold",
	FEAT_shop_slots_max    = "Packed to the Rafters",
	FEAT_shop_full         = "No Vacancy",
	FEAT_shop_release_50   = "Back to the Fields",
	FEAT_shop_release_500  = "The Great Release",
	FEAT_shop_release_2500 = "Repopulating Azeroth",
	FEAT_shop_tidy         = "Spring Cleaning",
	FEAT_shop_glitter_500  = "First Glitter",
	FEAT_shop_glitter_5000 = "Glittering Purse",
	FEAT_shop_glitter_25000 = "Glittering Chest",
	FEAT_shop_glitter_100000 = "Raining Glitter",
	FEAT_shop_spent_1000   = "Spendthrift",
	FEAT_shop_spent_10000  = "Living Large",
	FEAT_shop_order_10     = "Ten Deliveries",
	FEAT_shop_order_50     = "Fifty Deliveries",
	FEAT_shop_order_150    = "A Hundred and Fifty Deliveries",
	FEAT_shop_order_week   = "A Week's Work",
	FEAT_shop_order_week_10 = "Ten Weeks' Work",
	FEAT_shop_arrivals_all = "Loyal Customer",
	FEAT_shop_aids_100     = "Valued Customer",
	FEATD_init_meet        = "Finish your companion's introduction",
	FEATD_init_net         = "Finish the capture tour",
	FEATD_init_partner     = "Set out with a creature you captured",
	FEATD_init_journal     = "Finish the journal tour",
	FEATD_init_study       = "Finish a study task",
	FEATD_init_radiant     = "Make your companion Radiant",
	FEATD_init_wish        = "Grant one of your companion's wishes",
	FEATD_init_treat       = "Give a treat",
	FEATD_init_hunt        = "Start hunt mode",
	FEATD_init_release     = "Release a specimen",
	FEATD_init_shop        = "Buy an item at the Trainer's Stall",
	FEATD_init_order       = "Deliver an order",
	FEATD_init_aid         = "Capture a creature with a capture aid",
	FEATD_init_pin         = "Add a species to your hunt list",
	FEATD_init_follow      = "Track an achievement on screen",
	FEATD_init_all         = "Earn every Getting Started achievement",
	FEATD_men_caught_100   = "Capture 100 creatures (every specimen counts)",
	FEATD_men_caught_500   = "Capture 500 creatures",
	FEATD_men_caught_2000  = "Capture 2,000 creatures",
	FEATD_men_caught_5000  = "Capture 5,000 creatures",
	FEATD_men_caught_10000 = "Capture 10,000 creatures",
	FEATD_men_elite_10     = "Capture 10 different elites",
	FEATD_men_elite_50     = "Capture 50 different elites",
	FEATD_men_elite_150    = "Capture 150 different elites",
	FEATD_men_rare_25      = "Capture 25 rares or rare elites",
	FEATD_men_rare_50      = "Capture 50 rares or rare elites",
	FEATD_men_rareelite_1  = "Capture a rare elite",
	FEATD_men_medal4_1     = "Reach tier 4 in a creature type",
	FEATD_men_medal4_all   = "Reach tier 4 in all 8 types",
	FEATD_men_medal5_1     = "Reach tier 5 in a creature type",
	FEATD_men_medal5_all   = "Reach tier 5 in all 8 types",
	FEATD_men_zones_10     = "Capture creatures in 10 different zones",
	FEATD_men_zones_25     = "Capture creatures in 25 different zones",
	FEATD_men_zones_all    = "Capture creatures in all %d sealable zones",
	FEATD_men_level60      = "Capture a creature of level 60 or higher",
	FEATD_men_streak_10    = "Land 10 captures in a row",
	FEATD_men_streak_25    = "Land 25 captures in a row",
	FEATD_men_batch_10     = "Catch 10 creatures in a single \"Capture all\" volley",
	FEATD_men_hunt_100     = "Capture 100 creatures in hunt mode",
	FEATD_men_hunt_1000    = "Capture 1,000 creatures in hunt mode",
	FEATD_men_aid_50       = "Use 50 capture aids",
	FEATD_men_whistle_10   = "Capture 10 creatures with the Tamer's whistle",
	FEATD_men_noaid_rare   = "Capture a rare or a rare elite without any aid",
	FEATD_men_fail_100     = "Fail 100 captures (in total)",
	FEATD_spec_stars3_250  = "Have 250 species captured at 3 stars",
	FEATD_spec_giant_10    = "Capture a Giant of 10 different species",
	FEATD_spec_tiny_10     = "Capture a Tiny of 10 different species",
	FEATD_spec_sizes_species = "Capture all 5 sizes of the same species",
	FEATD_spec_twins       = "Capture a Tiny and a Giant of the same species",
	FEATD_spec_index_max   = "Capture a specimen with a size index of 125",
	FEATD_spec_index_min   = "Capture a specimen with a size index of 75",
	FEATD_spec_trait_rare  = "Capture a Zen or a Mischievous specimen (1 in 10)",
	FEATD_spec_traits_species = "Capture all 8 personalities of the same species",
	FEATD_spec_contest     = "A 3-star specimen of a rare size (1 in 357)",
	FEATD_spec_tasks_50    = "Finish 50 study tasks",
	FEATD_spec_study_250   = "Master the study of 250 species",
	FEATD_spec_study_500   = "Master the study of 500 species",
	FEATD_spec_study_zone  = "Master 25 species from the same zone",
	FEATD_spec_bond_3      = "Have 3 specimens at the Inseparable bond",
	FEATD_spec_bond_10     = "Have 10 specimens at the Inseparable bond",
	FEATD_spec_bond_1000   = "Earn 1,000 bond points (in total)",
	FEATD_spec_nick_1      = "Give a specimen a nickname",
	FEATD_spec_nick_10     = "Have 10 nicknamed specimens",
	FEATD_spec_lock_10     = "Protect 10 specimens",
	FEATD_spec_same_25     = "Capture the same species 25 times",
	FEATD_spec_same_100    = "Capture the same species 100 times",
	FEATD_shiny_seen_25    = "Spot 25 shiny creatures",
	FEATD_shiny_seen_100   = "Spot 100 shiny creatures",
	FEATD_shiny_found_100  = "Find 100 shiny creatures",
	FEATD_shiny_found_250  = "Find 250 shiny creatures",
	FEATD_shiny_cap_50     = "Capture 50 shiny creatures",
	FEATD_shiny_cap_100    = "Capture 100 shiny creatures",
	FEATD_shiny_types      = "Capture a shiny of each of the %d types",
	FEATD_shiny_zone_5     = "Capture 5 shiny creatures in the same zone",
	FEATD_shiny_day_2      = "Capture 2 shiny creatures on the same day",
	FEATD_shiny_chain      = "Find a shiny with your hunting streak maxed out (50 defeated)",
	FEATD_shiny_zones_25   = "Find shiny creatures in 25 different zones",
	FEATD_shiny_partner    = "Set out with a shiny creature",
	FEATD_shiny_rare_size  = "Capture a Giant or Tiny shiny (1 in 3,750)",
	FEATD_shiny_study_10   = "Finish the \"Shiny\" study task for 10 species",
	FEATD_shop_slots_max   = "Expand the Reserve to 150 slots",
	FEATD_shop_full        = "Fill the Reserve",
	FEATD_shop_release_50  = "Release 50 specimens",
	FEATD_shop_release_500 = "Release 500 specimens",
	FEATD_shop_release_2500 = "Release 2,500 specimens",
	FEATD_shop_tidy        = "Release 10 specimens at once",
	FEATD_shop_glitter_500 = "Earn 500 glitter (in total)",
	FEATD_shop_glitter_5000 = "Earn 5,000 glitter",
	FEATD_shop_glitter_25000 = "Earn 25,000 glitter",
	FEATD_shop_glitter_100000 = "Earn 100,000 glitter",
	FEATD_shop_spent_1000  = "Spend 1,000 glitter",
	FEATD_shop_spent_10000 = "Spend 10,000 glitter",
	FEATD_shop_order_10    = "Deliver 10 orders",
	FEATD_shop_order_50    = "Deliver 50 orders",
	FEATD_shop_order_150   = "Deliver 150 orders",
	FEATD_shop_order_week  = "Deliver all 3 orders of the same week",
	FEATD_shop_order_week_10 = "Deliver all 3 orders in 10 different weeks",
	FEATD_shop_arrivals_all = "Own all 8 arrival cosmetics",
	FEATD_shop_aids_100    = "Buy 100 capture aids at the Trainer's Stall",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests, et versées dans les chaînes du catalogue (chaque nom
-- doit exister dans les deux langues)
if ns.KEEP_STRINGS then
	ns.FEAT_DRESSEUR_STRINGS = { fr = FR, en = EN }
	local data = ns.FEAT_DATA_STRINGS
	if data then
		for key, text in pairs(FR) do data.fr[key] = text end
		for key, text in pairs(EN) do data.en[key] = text end
	end
end

if ns.Mark then ns.Mark("FeatsCatDresseur") end
