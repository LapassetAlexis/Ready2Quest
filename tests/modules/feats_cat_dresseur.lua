-- QuestCompanion 3.7.0, étape 1, chantier B2a : le catalogue de la famille
-- « dresseur » (FeatsCatDresseur.lua) : Initiation, Créatures, Spécimens,
-- Brillantes, Réserve et Échoppe. 99 lignes : présence, code, points,
-- catégorie, noms et descriptions FR/EN/ES, récompenses, séries ; chaque
-- source nouvelle sur une sauvegarde fabriquée (zéro, juste sous le seuil, au
-- seuil) et le rattrapage ; chaque ligne sur compteur ; lignes « état » en
-- direct ; relevés posés ici ; coût (relevés gardés).
local Check, Say, NS = T.Check, T.Say, T.QNS

-- id = { code, points, catégorie }
local ROWS = {
	init_meet = { 244, 5, "init" }, init_net = { 245, 5, "init" }, init_partner = { 246, 5, "init" },
	init_journal = { 247, 5, "init" }, init_study = { 248, 5, "init" }, init_radiant = { 249, 5, "init" },
	init_wish = { 250, 5, "init" }, init_treat = { 251, 5, "init" }, init_hunt = { 252, 5, "init" },
	init_release = { 253, 5, "init" }, init_shop = { 254, 5, "init" }, init_order = { 255, 5, "init" },
	init_aid = { 256, 5, "init" }, init_pin = { 257, 5, "init" }, init_follow = { 258, 5, "init" },
	init_all = { 259, 10, "init" },
	men_caught_100 = { 260, 5, "men" }, men_caught_500 = { 261, 10, "men" }, men_caught_2000 = { 262, 10, "men" },
	men_caught_5000 = { 263, 25, "men" }, men_caught_10000 = { 264, 25, "men" }, men_elite_10 = { 265, 10, "men" },
	men_elite_50 = { 266, 25, "men" }, men_elite_150 = { 267, 50, "men" }, men_rare_25 = { 268, 25, "men" },
	men_rare_50 = { 269, 50, "men" }, men_rareelite_1 = { 270, 10, "men" }, men_medal4_1 = { 271, 10, "men" },
	men_medal4_all = { 272, 25, "men" }, men_medal5_1 = { 273, 25, "men" }, men_medal5_all = { 274, 50, "men" },
	men_zones_10 = { 275, 10, "men" }, men_zones_25 = { 276, 25, "men" }, men_zones_all = { 277, 25, "men" },
	men_level60 = { 278, 10, "men" }, men_streak_10 = { 279, 10, "men" }, men_streak_25 = { 280, 25, "men" },
	men_batch_10 = { 281, 25, "men" }, men_hunt_100 = { 282, 10, "men" }, men_hunt_1000 = { 283, 25, "men" },
	men_aid_50 = { 284, 5, "men" }, men_whistle_10 = { 285, 10, "men" }, men_noaid_rare = { 286, 10, "men" },
	men_fail_100 = { 287, 5, "men" },
	spec_stars3_250 = { 288, 50, "spec" }, spec_giant_10 = { 289, 25, "spec" }, spec_tiny_10 = { 290, 25, "spec" },
	spec_sizes_species = { 291, 25, "spec" }, spec_twins = { 292, 10, "spec" }, spec_index_max = { 293, 10, "spec" },
	spec_index_min = { 294, 10, "spec" }, spec_trait_rare = { 295, 5, "spec" }, spec_traits_species = { 296, 25, "spec" },
	spec_contest = { 297, 25, "spec" }, spec_tasks_50 = { 298, 5, "spec" }, spec_study_250 = { 299, 50, "spec" },
	spec_study_500 = { 300, 50, "spec" }, spec_study_zone = { 301, 25, "spec" }, spec_bond_3 = { 302, 25, "spec" },
	spec_bond_10 = { 303, 50, "spec" }, spec_bond_1000 = { 304, 10, "spec" }, spec_nick_1 = { 305, 5, "spec" },
	spec_nick_10 = { 306, 10, "spec" }, spec_lock_10 = { 307, 5, "spec" }, spec_same_25 = { 308, 10, "spec" },
	spec_same_100 = { 309, 25, "spec" },
	shiny_seen_25 = { 310, 5, "shiny" }, shiny_seen_100 = { 311, 10, "shiny" }, shiny_found_100 = { 312, 25, "shiny" },
	shiny_found_250 = { 313, 50, "shiny" }, shiny_cap_50 = { 314, 50, "shiny" }, shiny_cap_100 = { 315, 50, "shiny" },
	shiny_types = { 316, 25, "shiny" }, shiny_zone_5 = { 317, 10, "shiny" }, shiny_day_2 = { 318, 10, "shiny" },
	shiny_chain = { 319, 10, "shiny" }, shiny_zones_25 = { 320, 25, "shiny" }, shiny_partner = { 321, 5, "shiny" },
	shiny_rare_size = { 322, 25, "shiny" }, shiny_study_10 = { 323, 10, "shiny" },
	shop_slots_max = { 378, 25, "shop" }, shop_full = { 379, 5, "shop" }, shop_release_50 = { 380, 5, "shop" },
	shop_release_500 = { 381, 10, "shop" }, shop_release_2500 = { 382, 25, "shop" }, shop_tidy = { 383, 5, "shop" },
	shop_glitter_500 = { 384, 5, "shop" }, shop_glitter_5000 = { 385, 10, "shop" }, shop_glitter_25000 = { 386, 25, "shop" },
	shop_glitter_100000 = { 387, 50, "shop" }, shop_spent_1000 = { 388, 10, "shop" }, shop_spent_10000 = { 389, 25, "shop" },
	shop_order_10 = { 390, 10, "shop" }, shop_order_50 = { 391, 25, "shop" }, shop_order_150 = { 392, 50, "shop" },
	shop_order_week = { 393, 10, "shop" }, shop_order_week_10 = { 394, 25, "shop" }, shop_arrivals_all = { 395, 25, "shop" },
	shop_aids_100 = { 396, 10, "shop" },
}
-- récompenses : titres, aides, cosmétiques promis (contrat B2)
local TITLES = { init_all = 50, men_caught_10000 = 51, men_elite_150 = 52, men_medal5_all = 53, spec_study_250 = 54,
	spec_bond_10 = 55, shiny_found_250 = 56, shiny_cap_100 = 57, shop_order_150 = 58 }
local AIDS = { init_net = "appat:2", init_all = "lasso:2", men_caught_500 = "lasso:1", men_caught_2000 = "sifflet:1",
	men_elite_10 = "lasso:1", men_rare_25 = "sifflet:1" }
local SOON = { men_rare_50 = "orn:feat_rarities", men_medal4_all = "cardframe:card_eight", spec_stars3_250 = "frame:feat_starry",
	spec_contest = "orn:feat_contest", spec_study_500 = "cardbg:card_zoology", shiny_found_100 = "bg:feat_sparkle",
	shiny_cap_50 = "cardframe:card_prism", shiny_rare_size = "orn:feat_rare_size", shop_glitter_100000 = "orn:feat_glitter" }

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local savedDormant = NS.featsDormant
-- une sauvegarde neuve : compagnon, capture du compte, hauts faits, compteurs
local function Fresh()
	T.ResetWorld()
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt = {}, {}, nil, nil
	local db = NS:DB()
	db.feats, db.tally, db.tour30, db.capture = nil, nil, nil, nil
	NS:CharData().feats, NS:CharData().tally = nil, nil
	local companion = NS:CompanionData()
	companion.tutoDone, companion.appearance = nil, nil
	local c = NS:CaptureData()
	c.creatures, c.specimens, c.codex, c.study, c.pins = {}, {}, {}, {}, {}
	c.specV, c.traitV, c.studyV, c.studyShinyV = NS.SPECIMEN_SCHEMA, NS.SPECIMEN_TRAIT_SCHEMA, NS.STUDY_SCHEMA, 1
	c.caught, c.paillettesEarned, c.reserveBonus, c.slotBuys, c.patron, c.shopOwned, c.shopDay = 0, 0, 0, 0, 0, nil, nil
	NS:FeatDresseurReset()
	NS:FeatCacheReset()
	return c
end
local function Eval() NS:FeatDresseurReset(); return NS:FeatEvaluate(nil) end
local function Got(id) return NS:FeatGot(id) ~= nil end
local function Value(source) NS:FeatDresseurReset(); NS:FeatCacheReset(); return NS.FEAT_SOURCES[source].get(NS, "account") end

-- 1. Les lignes ---------------------------------------------------------------------------------------------
do
	Say("-- hauts faits 3.7, famille dresseur : les lignes")
	local s = Steps()
	local fr, en = NS.FEAT_DRESSEUR_STRINGS.fr, NS.FEAT_DRESSEUR_STRINGS.en
	local es = NS.STRINGS_TABLES and NS.STRINGS_TABLES.es or {}
	local count, points, countable = 0, 0, 0
	for id, want in pairs(ROWS) do
		local def = NS:FeatDef(id)
		count = count + 1
		if not def then s.ok(id .. " absente", false) else
			points = points + def.pts
			if NS:FeatCountable(def) then countable = countable + 1 end
			s.ok(id .. " code", def.n == want[1], def.n)
			s.ok(id .. " points", def.pts == want[2], def.pts)
			s.ok(id .. " catégorie", def.cat == want[3], def.cat)
			s.ok(id .. " portée", def.scope == "account")
			s.ok(id .. " nom FR/EN/ES", fr["FEAT_" .. id] and en["FEAT_" .. id] and es["FEAT_" .. id])
			s.ok(id .. " description FR/EN/ES", fr["FEATD_" .. id] and en["FEATD_" .. id] and es["FEATD_" .. id]
				and def.desc == "FEATD_" .. id)
			local text = NS:FeatDescription(def)
			s.ok(id .. " description rendue", text ~= "" and not text:find("FEATD_", 1, true) and not text:find("%%"), text)
			s.ok(id .. " pas en attente", not def.pending and not def.hidden)
			local reward = def.reward or {}
			s.ok(id .. " titre", reward.title == TITLES[id], reward.title)
			local aids = nil
			for aid, n in pairs(reward.aids or {}) do aids = aid .. ":" .. n end
			s.ok(id .. " aides", aids == AIDS[id], aids)
			-- à venir (reward.soon), ou déjà fabriqué : le moteur l'a alors changé en reward.cosmetic
			local pair = reward.soon or reward.cosmetic
			local soon = pair and (pair[1] .. ":" .. pair[2]) or nil
			s.ok(id .. " cosmétique promis", soon == SOON[id], soon)
			for _, glyph in ipairs({ "\226\152\133", "\226\152\134", "\226\156\147", "\226\156\151" }) do
				s.ok(id .. " glyphe", not (fr["FEAT_" .. id] .. fr["FEATD_" .. id] .. en["FEAT_" .. id] .. en["FEATD_" .. id]):find(glyph, 1, true))
			end
		end
	end
	s.ok("99 lignes, 1 780 points, toutes comptables", count == 99 and points == 1780 and countable == 99
		and #NS.FEAT_DRESSEUR_IDS == 99, count .. " / " .. points .. " / " .. countable)
	-- noms anglais distincts des noms existants (pas deux « David and Goliath »)
	local names, dup = {}, {}
	for _, def in ipairs(NS:FeatDefs()) do
		local name = NS.FEAT_DATA_STRINGS.en["FEAT_" .. def.id]
		if name then
			if names[name] then dup[#dup + 1] = name end
			names[name] = true
		end
	end
	s.ok("noms anglais uniques", #dup == 0, table.concat(dup, ", "))
	s.check("[B2a] 99 lignes : code, points, catégorie, portée, noms et descriptions FR/EN/ES, titres, aides, cosmétiques promis")

	s = Steps()
	for _, code in ipairs({ 50, 51, 52, 53, 54, 55, 56, 57, 58 }) do
		local t = NS.FEAT_TITLES[code]
		s.ok("T" .. code, t and t.m and t.en and NS:FeatDef(t.src) and NS:FeatDef(t.src).reward.title == code)
		s.ok("T" .. code .. " ES", NS.FEAT_TITLES_ES and NS.FEAT_TITLES_ES[code] and NS.FEAT_TITLES_ES[code].f)
	end
	s.ok("T50 préfixe, féminin", NS.FEAT_TITLES[50].pos == "pre" and NS:FeatTitleText(50, nil, "f") == "Dresseuse en herbe")
	s.ok("T51 épicène", NS.FEAT_TITLES[51].f == nil)
	s.check("[B2a] titres T50 à T58 : registre, source, formes, espagnol")

	-- séries : échelles nouvelles et prolongées ; premier palier existant rattaché
	s = Steps()
	local function Keys(key)
		local ids = {}
		for _, def in ipairs(NS:FeatSeries(key) or {}) do ids[#ids + 1] = def.id end
		return table.concat(ids, ",")
	end
	s.ok("prises", Keys("caught") == "men_caught_100,men_caught_500,men_caught_2000,men_caught_5000,men_caught_10000")
	s.ok("élites (avec men_elite_1)", Keys("elite") == "men_elite_1,men_elite_10,men_elite_50,men_elite_150", Keys("elite"))
	s.ok("rares prolongés", Keys("rare") == "men_rare_1,men_rare_10,men_rare_25,men_rare_50")
	s.ok("3 étoiles prolongés", Keys("stars3") == "men_stars3_1,men_stars3_25,men_stars3_100,spec_stars3_250")
	s.ok("étude prolongée", Keys("study") == "men_study_10,men_study_50,men_study_100,spec_study_250,spec_study_500")
	s.ok("brillantes trouvées", Keys("shinyFound"):find("shiny_found_50,shiny_found_100,shiny_found_250$") ~= nil)
	s.ok("brillantes capturées", Keys("shinyCap") == "shiny_cap_1,shiny_cap_10,shiny_cap_25,shiny_cap_50,shiny_cap_100")
	s.ok("repérées (avec shiny_seen_1)", Keys("shinySeen") == "shiny_seen_1,shiny_seen_25,shiny_seen_100")
	s.ok("zones de brillantes", Keys("shinyZones") == "shiny_zones_10,shiny_zones_25")
	s.ok("relâchers", Keys("release") == "shop_release_50,shop_release_500,shop_release_2500")
	s.ok("ligne existante inchangée", NS:FeatDef("men_elite_1").n == 8 and NS:FeatDef("men_elite_1").pts == 5)
	s.check("[B2a] séries : échelles nouvelles, prolongement des échelles déclarées, premier palier existant rattaché")
end

-- 2. Sources : zéro, juste sous le seuil, au seuil ; rattrapage --------------------------------------------
do
	Say("-- hauts faits 3.7, famille dresseur : sources")
	local s = Steps()
	local c = Fresh()
	-- tout à zéro : aucune ligne de la famille obtenue
	Eval()
	local any = {}
	for id in pairs(ROWS) do if Got(id) then any[#any + 1] = id end end
	s.ok("sauvegarde vide : rien", #any == 0, table.concat(any, ","))

	c.caught = 99
	s.ok("prises 99", Value("caught") == 99 and Eval() and not Got("men_caught_100"))
	c.caught = 100
	Eval()
	s.ok("prises 100", Got("men_caught_100") and not Got("men_caught_500"))

	c.creatures[1] = { name = "A", class = "rare", level = 59, zoneID = 1 }
	s.ok("rare élite 0, niveau 59", Value("rareElite") == 0 and Value("level60") == 0)
	c.creatures[2] = { name = "B", class = "rareelite", level = 60, zoneID = 2 }
	c.serial = 1
	Eval()
	s.ok("rare élite, niveau 60", Value("rareElite") == 1 and Value("level60") == 1 and Got("men_rareelite_1") and Got("men_level60"))

	-- zones : preuves (fiches, spécimens) et relevé, sans double compte
	for z = 3, 9 do c.creatures[100 + z] = { name = "Z", class = "normal", zoneID = z } end
	c.serial = 2
	s.ok("9 zones", Value("captureZones") == 9 and not Got("men_zones_10"))
	NS:TallyMark("captureZones", 9, "account")
	s.ok("zone déjà prouvée : pas deux fois", Value("captureZones") == 9)
	NS:TallyMark("captureZones", 10, "account")
	Eval()
	s.ok("10 zones (relevé)", Value("captureZones") == 10 and Got("men_zones_10"))
	local savedZones = NS.ZONE_CREATURES
	NS.ZONE_CREATURES = { [1] = {}, [2] = {}, [77] = {} }
	s.ok("zones à sceau : 2 sur 3", Value("captureSealZones") == 2 and Eval() and not Got("men_zones_all")
		and NS:FeatDescription("men_zones_all") == "Capturer des créatures dans les 3 zones à sceau")
	NS:TallyMark("captureZones", 77, "account")
	Eval()
	s.ok("zones à sceau : toutes", Got("men_zones_all"))
	NS.ZONE_CREATURES = savedZones

	-- médailles 4 et 5 (MenagerieCollection.lua, faussée ici)
	local medals = NS.MenagerieMedals
	NS.MenagerieMedals = function() return { beast = 4, undead = 3 } end
	c.serial = 3
	Eval()
	s.ok("médaille 4", Got("men_medal4_1") and not Got("men_medal5_1") and Value("medal4") == 1)
	NS.MenagerieMedals = function()
		local m = {}
		for _, key in ipairs(NS.CREATURE_TYPES) do m[key] = 5 end
		return m
	end
	c.serial = 4
	Eval()
	s.ok("médailles 5 partout", Got("men_medal5_all") and Got("men_medal4_all") and Value("medal5") == 8)
	NS.MenagerieMedals = medals
	s.check("[B2a] sources des Créatures : prises, rare élite, niveau 60, zones (preuves + relevé), zones à sceau, médailles")

	-- fiches d'étude
	s = Steps()
	c = Fresh()
	local zen
	for index, id in ipairs(NS.PERSONALITY_ORDER) do if id == "zen" then zen = index end end
	for npc = 1, 9 do c.study[npc] = { n = 1, z = 16, t = 0, paid = 0 } end   -- géant (5e taille)
	s.ok("9 géants", Value("studyGiant") == 9 and Eval() and not Got("spec_giant_10"))
	c.study[10] = { n = 1, z = 16 + 1, t = 2 ^ (zen - 1), paid = 0, hi = 125, lo = 75 }
	c.specSerial = 1
	Eval()
	s.ok("10 géants, jumeaux, indices, perle rare", Got("spec_giant_10") and Got("spec_twins") and Got("spec_index_max")
		and Got("spec_index_min") and Got("spec_trait_rare") and not Got("spec_tiny_10") and not Got("spec_sizes_species"))
	s.ok("une tâche : Première leçon", Got("init_study") and Value("studyTasks") == 10)
	c.study[11] = { n = 24, z = 31, t = 0, paid = 0 }
	c.specSerial = 2
	Eval()
	s.ok("5 tailles, 24 captures", Got("spec_sizes_species") and not Got("spec_same_25") and Value("studySame") == 24)
	c.study[11].n = 25
	local all = 0
	for _, pair in ipairs(NS.SPECIMEN_TRAIT_WEIGHTS) do
		for index, id in ipairs(NS.PERSONALITY_ORDER) do if id == pair[1] then all = all + 2 ^ (index - 1) end end
	end
	c.study[12] = { n = 1, z = 4, t = all, paid = 0 }
	c.specSerial = 3
	Eval()
	s.ok("25 captures, 8 caractères", Got("spec_same_25") and Got("spec_traits_species"))
	-- maîtrise par zone (zone de la première capture) et brillantes étudiées
	c = Fresh()
	for npc = 1, 24 do
		c.study[npc] = { n = 5, s3 = true, z = 7, t = 7, sh = npc <= 9, paid = 0 }
		c.creatures[npc] = { name = "M", class = "normal", zoneID = 42 }
	end
	s.ok("24 maîtrisées dans la zone, 9 brillantes étudiées", Value("studyZone") == 24 and Value("studyShiny") == 9
		and Eval() and not Got("spec_study_zone"))
	s.ok("tâches : 5 par espèce maîtrisée", Value("studyTasks") == 120 and Got("spec_tasks_50"))
	c.study[25] = { n = 5, s3 = true, z = 7, t = 7, sh = true, paid = 0 }
	c.creatures[25] = { name = "M", class = "normal", zoneID = 42 }
	c.specSerial = 9
	Eval()
	s.ok("25 maîtrisées, 10 brillantes", Got("spec_study_zone") and Got("shiny_study_10"))
	s.check("[B2a] sources des fiches d'étude : géants, minuscules, tailles, jumeaux, indices, caractères, tâches, même espèce, maîtrise par zone, brillantes")

	-- spécimens possédés : lien, surnoms, protection, brillantes par zone et par jour
	s = Steps()
	c = Fresh()
	local function Spec(id, fields)
		local spec = { id = id, npc = 1000 + id, stars = 3, origin = "capture" }
		for k, v in pairs(fields or {}) do spec[k] = v end
		c.specimens[id] = spec
		return spec
	end
	for i = 1, 2 do Spec(i, { bond = { p = 180 } }) end
	Spec(3, { stars = 2, bond = { p = 180 } })   -- 2 étoiles : lien 4 au plus
	s.ok("2 inséparables", Value("bond5") == 2 and Eval() and not Got("spec_bond_3"))
	Spec(4, { bond = { p = 180 }, nick = "Pom", lock = true })
	c.specSerial = 1
	Eval()
	s.ok("3 inséparables, un surnom", Got("spec_bond_3") and Got("spec_nick_1") and not Got("spec_nick_10") and Value("locks") == 1)
	for i = 5, 13 do Spec(i, { lock = true, nick = "N" .. i }) end
	c.specSerial = 2
	Eval()
	s.ok("10 surnoms, 10 protégés", Got("spec_nick_10") and Got("spec_lock_10") and not Got("spec_bond_10"))
	for i = 20, 23 do Spec(i, { shiny = true, zone = 5, at = 1000000 + i * 100000 }) end
	Spec(24, { shiny = true, zone = 5, origin = "migration" })   -- zone de l'espèce : ne compte pas par zone
	s.ok("4 brillantes dans la zone", Value("shinyZoneBest") == 4 and not Got("shiny_zone_5"))
	s.ok("un jour, une brillante", Value("shinyDayBest") == 1)
	Spec(25, { shiny = true, zone = 5, at = 1000000 + 20 * 100000 + 60 })
	c.specSerial = 3
	Eval()
	s.ok("5 brillantes dans la zone, 2 le même jour", Got("shiny_zone_5") and Got("shiny_day_2"))
	s.check("[B2a] sources des spécimens : lien Inséparable (selon les étoiles), surnoms, protégés, brillantes par zone (captures) et par jour")

	-- brillantes par type
	s = Steps()
	c = Fresh()
	local names = { beast = "Beast", humanoid = "Humanoid", undead = "Undead", elemental = "Elemental", dragonkin = "Dragonkin",
		demon = "Demon", giant = "Giant", mechanical = "Mechanical" }
	for i, key in ipairs(NS.CREATURE_TYPES) do
		if i < #NS.CREATURE_TYPES then c.creatures[i] = { name = "S", class = "normal", shiny = true, type = names[key] } end
	end
	c.creatures[50] = { name = "N", class = "normal", type = names.mechanical }   -- pas brillante
	Eval()
	local list = NS:FeatChecklist("shiny_types")
	s.ok("7 types sur 8", not Got("shiny_types") and #list == 8 and list[1].done and not list[8].done
		and list[1].label == NS:CreatureTypeLabel("beast"), list and list[1] and list[1].label)
	c.creatures[50].shiny = true
	c.serial = 5
	Eval()
	s.ok("8 types", Got("shiny_types") and NS:FeatDescription("shiny_types") == "Capturer une brillante de chacun des 8 types")
	s.check("[B2a] brillantes par type : liste cochée des 8 types (nom du type), obtenue au huitième")

	-- Initiation, Réserve et Échoppe : états et données de la sauvegarde
	s = Steps()
	c = Fresh()
	s.ok("rien d'avance", Value("tourMeet") + Value("tourCapture") + Value("tourJournal") + Value("partnerCaptured")
		+ Value("shopBought") + Value("huntPins") == 0)
	NS:CompanionData().tutoDone = true
	NS:DB().tour30 = { capture = true, journal = true }
	NS:CompanionData().appearance = "cap:123:s"
	c.slotBuys = 1
	c.pins[42] = true
	c.reserveBonus = 99
	Eval()
	s.ok("visites, tutoriel, partenaire brillant, achat, épingle", Got("init_meet") and Got("init_net") and Got("init_journal")
		and Got("init_partner") and Got("shiny_partner") and Got("init_shop") and Got("init_pin"))
	-- (chaque haut fait obtenu paie des paillettes : le seuil se lit sans passe)
	c.paillettesEarned = 499
	local cur, max, state = NS:FeatProgress("shop_glitter_500")
	s.ok("149 places, 499 paillettes", Value("reserveSlots") == 149 and not Got("shop_slots_max") and cur == 499 and max == 500
		and state == "open")
	c.reserveBonus, c.paillettesEarned = 100, 500
	Eval()
	s.ok("150 places, 500 paillettes", Got("shop_slots_max") and Got("shop_glitter_500") and not Got("shop_glitter_5000"))
	c.shopOwned = {}
	local arrivals = 0
	for _, item in ipairs(NS.PAILLETTES_SHOP) do
		if item.arrival then
			arrivals = arrivals + 1
			if arrivals < 8 then c.shopOwned[item.cosId] = true end
		end
	end
	s.ok("7 arrivages sur 8", arrivals == 8 and Value("arrivalsOwned") == 7 and Eval() and not Got("shop_arrivals_all"))
	for _, item in ipairs(NS.PAILLETTES_SHOP) do if item.arrival then c.shopOwned[item.cosId] = true end end
	Eval()
	s.ok("8 arrivages", Got("shop_arrivals_all"))
	local full = NS.ReserveFull
	NS.ReserveFull = function() return false end
	s.ok("Réserve pas pleine", Value("reserveFull") == 0)
	NS.ReserveFull = function() return true end
	Eval()
	s.ok("Réserve pleine", Got("shop_full"))
	NS.ReserveFull = full
	s.check("[B2a] Initiation, Réserve et Échoppe : visites, tutoriel, partenaire, achat, épingle, places, paillettes, arrivages, Réserve pleine")

	-- rattrapage : les lignes rétroactives et « état » en silence, jamais celles sur compteur
	s = Steps()
	c = Fresh()
	NS:CompanionData().tutoDone = true
	c.caught = 600
	NS:TallyAdd("release", 60, "account")
	local found = NS:FeatRetroScan()
	local ids = {}
	for _, def in ipairs(found) do ids[def.id] = true end
	s.ok("rétroactifs obtenus en silence", ids.init_meet and ids.men_caught_100 and ids.men_caught_500
		and NS:DB().feats.got.men_caught_500.r == true)
	s.ok("compteurs non rétroactifs", not ids.init_release and not ids.shop_release_50 and not NS.FeatRetro(NS:FeatDef("shop_release_50")))
	s.ok("état rétroactif", NS.FeatRetro(NS:FeatDef("init_pin")) and NS.FeatRetro(NS:FeatDef("shop_full")))
	s.check("[B2a] rattrapage : lignes rétroactives et « état » obtenues en silence, lignes sur compteur jamais")
end

-- 3. Lignes sur compteur : pas avant le seuil, obtenues au seuil ---------------------------------------------
do
	Say("-- hauts faits 3.7, famille dresseur : compteurs")
	local s = Steps()
	Fresh()
	local kinds = 0
	for id in pairs(ROWS) do
		local def = NS:FeatDef(id)
		local crit = def.crit
		local kind = crit[1]
		if kind == "tally" or kind == "tallymax" then
			kinds = kinds + 1
			local key, n, scope = crit[2], crit[3], crit[4] == "char" and "char" or "account"
			local store = scope == "char" and NS:CharData() or NS:DB()
			store.tally = nil
			local function Set(v)
				if kind == "tally" then NS:TallyAdd(key, v - NS:TallyGet(key, scope), scope)
				else NS:TallyMax(key, v, scope) end
			end
			NS:FeatStore("account").got[id] = nil
			if n > 1 then Set(n - 1) end
			NS:FeatEvaluate({ tally = true })
			local before = Got(id)
			Set(n)
			NS:FeatEvaluate({ tally = true })
			s.ok(id, not before and Got(id), tostring(before))
			s.ok(id .. " sujet tally seul", #def.topicList == 1 and def.topicList[1] == "tally")
		end
	end
	s.ok("33 lignes sur compteur", kinds == 33, kinds)
	s.ok("init_follow suit le moteur, pas en attente", NS:FeatDef("init_follow").crit[2] == "follow" and not NS:FeatDef("init_follow").pending)
	s.check("[B2a] lignes sur compteur (tally, tallymax, au compte ou au personnage) : pas avant le seuil, obtenues au seuil")
	-- Initiation complète : le grand haut fait, son titre
	s = Steps()
	for _, id in ipairs(NS:FeatDef("init_all").crit[2]) do NS:FeatAward(id, { silent = true }) end
	NS:FeatEvaluate({ feat = true })
	s.ok("init_all", Got("init_all") and #NS:FeatChecklist("init_all") == 15)
	s.check("[B2a] « Dresseur diplômé » : les 15 autres lignes d'Initiation, liste cochée")
end

-- 4. En direct : les événements touchent leur sujet ; relevés posés ici ---------------------------------------
do
	Say("-- hauts faits 3.7, famille dresseur : en direct")
	local s = Steps()
	local c = Fresh()
	NS.featDirty = {}
	NS:HuntPin(321, true)
	s.ok("épingle : sujet spec", NS.featDirty.spec)
	NS:FeatEvaluate(NS.featDirty)
	s.ok("épingle : obtenu en direct", Got("init_pin"))
	NS.featDirty = {}
	NS:CompanionSetAppearance(NS.COMPANION_APPEARANCES[1].id)
	s.ok("apparence : sujet companion", NS.featDirty.companion)
	NS.featDirty = {}
	NS:TourFinish()
	s.ok("visite : sujet tour", NS.featDirty.tour)
	NS.featDirty = {}
	NS:ShopCosmeticGrant("shop_ember")
	s.ok("cosmétique de l'Échoppe : sujet shop", NS.featDirty.shop)
	NS.featDirty = {}
	NS:FireCallback("BOND", "level", 1, 5)
	s.ok("lien : sujet spec", NS.featDirty.spec)
	NS.featDirty = {}
	NS:PaillettesAdd(3, "test")
	s.ok("paillettes : sujet shop", NS.featDirty.shop)
	-- relevés : une capture de brillante (zone, jour)
	c.specimens[90] = { id = 90, npc = 9, stars = 1, shiny = true, zone = 61, at = 1700000000, origin = "capture" }
	c.specimens[91] = { id = 91, npc = 9, stars = 1, shiny = true, zone = 61, at = 1700000100, origin = "capture" }
	c.specimens[92] = { id = 92, npc = 9, stars = 1, shiny = false, zone = 62, origin = "trade" }
	NS:FireCallback("SPECIMENS", "add", 90)
	NS:FireCallback("SPECIMENS", "add", 91)
	NS:FireCallback("SPECIMENS", "add", 92)
	s.ok("zones de capture", NS:TallyHas("captureZones", 61, "account") and not NS:TallyHas("captureZones", 62, "account"))
	s.ok("brillantes par zone", NS:TallyGet("shinyCapZone:61", "account") == 2 and NS:TallyBest("shinyZoneBest", "account") == 2)
	s.ok("brillantes du jour", NS:TallyBest("shinyDayBest", "account") == 2 and NS:DB().feats.dresseurShinyDay.n == 2)
	-- le moteur endormi : aucun relevé, aucun sujet
	NS.featsDormant = true
	NS.featDirty = {}
	NS:FireCallback("SPECIMENS", "add", 90)
	s.ok("moteur endormi : rien", NS:TallyGet("shinyCapZone:61", "account") == 2 and next(NS.featDirty) == nil)
	NS.featsDormant = false
	s.check("[B2a] en direct : épingle, apparence, visite, cosmétique, lien, paillettes touchent leur sujet ; relevés de zone et de brillantes")
end

-- 5. Coût : relevés gardés, refaits seulement quand leur domaine bouge ------------------------------------------
do
	Say("-- hauts faits 3.7, famille dresseur : coût")
	local s = Steps()
	local c = Fresh()
	c.study[1] = { n = 1, z = 16, t = 0, paid = 0 }
	local a = NS:FeatDresseurStudy()
	local b = NS:FeatDresseurStudy()
	s.ok("fiches d'étude : gardées", a == b)
	NS:FireCallback("SPECIMENS", "nick", 1)
	s.ok("fiches d'étude : refaites après un événement des spécimens", NS:FeatDresseurStudy() ~= a)
	local x = NS:FeatDresseurCreatures()
	s.ok("créatures : gardées", NS:FeatDresseurCreatures() == x)
	c.serial = (tonumber(c.serial) or 0) + 1
	s.ok("créatures : refaites quand la capture bouge", NS:FeatDresseurCreatures() ~= x)
	local y = NS:FeatDresseurSpecimens()
	s.ok("spécimens : gardés", NS:FeatDresseurSpecimens() == y)
	-- une ligne obtenue n'est plus évaluée : plus rien ne balaie
	for _, id in ipairs(NS.FEAT_DRESSEUR_IDS) do NS:FeatAward(id, { silent = true }) end
	local seen = 0
	local scan = NS.FeatDresseurReset
	NS:FeatDresseurReset()
	local progress = NS.FeatProgress
	NS.FeatProgress = function(self, def, ...)
		if def.n >= 244 and def.n <= 396 and ROWS[def.id] then seen = seen + 1 end
		return progress(self, def, ...)
	end
	NS:FeatEvaluate({ capture = true, spec = true, shop = true, tally = true, companion = true, tour = true, minute = true })
	NS.FeatProgress = progress
	s.ok("tout obtenu : aucune ligne de la famille relue", seen == 0, seen)
	s.ok("remise à zéro exposée", type(scan) == "function")
	s.check("[B2a] coût : relevés par domaine gardés, refaits quand leur domaine bouge ; une ligne obtenue n'est plus relue")
end

NS.featsDormant = savedDormant
NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt = {}, {}, nil, nil
