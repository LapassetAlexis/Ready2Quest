-- QuestCompanion 2.7.0, lot B des hauts faits (FeatsCatMenagerie.lua) :
-- Ménagerie, Brillantes, Zones et sceaux, Au jour le jour, Guilde et
-- entraide, Insolite (ménagerie, compagnon, carnet), grands hauts faits liés.
-- Lignes du document, une obtention par sorte de critère, récompenses
-- déplacées de TRAINER_RANKS / SHINY_REWARDS (sans double don, rattrapage
-- silencieux), union du compte sur deux personnages.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local HM = { saved = {}, earned = {} }
local GLOBALS = { "UnitName", "UnitLevel", "InCombatLockdown", "UnitAffectingCombat", "date", "IsInGroup", "GetStatistic" }
for _, name in ipairs(GLOBALS) do HM.saved[name] = rawget(_G, name) end
HM.savedDormant = NS.featsDormant

function HM.Install()
	_G.UnitName = function(unit) if unit == "player" then return HM.name or "Testeur" end return nil end
	_G.UnitLevel = function() return HM.level or 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.GetStatistic = function() return nil end
	_G.IsInGroup = function() return HM.group == true end
	-- date(fmt, t) : heure réglable, jour = t // 86400
	_G.date = function(fmt, t)
		t = t or time()
		if fmt == "%H" then return HM.hour or "14" end
		if fmt == "%Y%m%d" then return string.format("2026%04d", math.floor(t / 86400) % 10000) end
		if fmt == "%m%d" then return string.format("%04d", math.floor(t / 86400) % 365) end
		return "07/11/2026"
	end
end

function HM.Reset()
	ResetWorld()
	HM.name, HM.level, HM.group, HM.hour = nil, 20, false, nil
	HM.Install()
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = nil
	NS:FeatStatReset()
	NS:FeatMenagerieScanReset()
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS:CompanionData().tutoDone = true
	HM.earned = {}
	Mock:Reset()
end

local function Got(id) return NS:FeatGot(id) ~= nil end
local function Eval() NS:FeatMenagerieScanReset(); return NS:FeatEvaluate(nil) end
local function Creatures() return NS:CaptureData().creatures end
local function Aid(id) return NS:CaptureAidCount(id) end

if not HM.registered then
	NS:RegisterCallback("FEAT_EARNED", function(_, info) HM.earned[#HM.earned + 1] = info end)
	HM.registered = true
end

-- 1. Lignes du document ----------------------------------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot B : catalogue")
	local handle = io.open(ROOT .. "/docs/QC-HAUTS-FAITS.md", "rb")
	local doc = handle and handle:read("*a") or ""
	if handle then handle:close() end
	local catalogue = doc:sub(doc:find("## 2. Catalogue", 1, true) or 1, doc:find("### 2.12", 1, true) or #doc)
	local rows, rank = {}, 0
	for line in catalogue:gmatch("[^\n]+") do
		local id = line:match("^| `([%w_]+)` |")
		if id then
			rank = rank + 1
			local cells = {}
			for cell in line:gmatch("|([^|]*)") do cells[#cells + 1] = cell:gsub("^%s+", ""):gsub("%s+$", "") end
			rows[#rows + 1] = { id = id, n = rank, pts = tonumber(cells[7]), feas = cells[6], reward = cells[8] or "" }
		end
	end
	-- titres du §4.1 (T40 vient de men_bad_luck sans figurer au catalogue)
	local titleOf = {}
	for code, id in doc:gmatch("\n| T(%d+) | `([%w_]+)` |") do titleOf[id] = code end
	-- les catégories entières de ce lot, et ce qu'il prend d'Insolite et des grands hauts faits
	local WHOLE = { men = 29, shiny = 12, zone = 23, day = 14, soc = 7 }
	local FUN = { fun_name = true, fun_dance = true, fun_hogger_kill = true, fun_hogger_capture = true, fun_murlocs = true,
		fun_critter = true, fun_night_owl = true, fun_birthday = true }
	local META = { meta_menagerie = true, meta_shiny = true, meta_zones = true, meta_points_500 = true,
		meta_points_1500 = true, meta_trainer = true }
	local bad, counts, expected = {}, {}, {}
	local fr, en = NS.FEAT_DATA_STRINGS.fr, NS.FEAT_DATA_STRINGS.en
	local aidIds = {}
	for _, aid in ipairs(NS.CAPTURE_AIDS or {}) do aidIds[aid.id] = true end
	for _, row in ipairs(rows) do
		local cat = row.id:match("^(%a+)_")
		if WHOLE[cat] or FUN[row.id] or META[row.id] then
			expected[cat] = (expected[cat] or 0) + 1
			local def = NS:FeatDef(row.id)
			local function Bad(why) bad[#bad + 1] = row.id .. " (" .. why .. ")" end
			if not def then Bad("absent")
			else
				counts[cat] = (counts[cat] or 0) + 1
				if def.n ~= row.n then Bad("code " .. tostring(def.n) .. " ≠ " .. row.n) end
				if def.pts ~= row.pts then Bad("points") end
				if def.cat ~= cat then Bad("catégorie") end
				if def.scope ~= ((cat == "zone" or cat == "day") and "char" or "account") then Bad("portée") end
				if not (fr["FEAT_" .. row.id] and en["FEAT_" .. row.id]) then Bad("nom FR/EN") end
				local desc = NS:FeatDescription(def)
				if desc == "" or desc:find("^FEATD_") then Bad("description") end
				if (def.pending == true) ~= (row.feas:find("⚠", 1, true) ~= nil) then Bad("à vérifier") end
				local reward = def.reward or {}
				local title = row.reward:match("titre T(%d+)") or titleOf[row.id]
				if tonumber(title) ~= reward.title then Bad("titre") end
				if reward.title and not (NS.FEAT_TITLES[reward.title] and NS.FEAT_TITLES[reward.title].m
					and NS.FEAT_TITLES[reward.title].en) then Bad("titre sans formes") end
				for id in pairs(reward.aids or {}) do if not aidIds[id] then Bad("aide " .. id) end end
				local wantAids = 0
				for n in row.reward:gmatch("×(%d+)") do wantAids = wantAids + tonumber(n) end
				local haveAids = 0
				for _, n in pairs(reward.aids or {}) do haveAids = haveAids + n end
				if wantAids ~= haveAids then Bad("aides " .. haveAids .. " ≠ " .. wantAids) end
				local cosm = reward.cosmetic or reward.soon or (reward.appearance and { "app", reward.appearance })
				local want = row.reward:match("`(%l[%w_]*)`")
				if row.id == "shiny_3stars" then want = "feat_prism_orn" end   -- l'ornement (§4.2)
				if want and row.id ~= "day_perfect_10" and not (cosm and cosm[2] == want) then Bad("cosmétique " .. want) end
			end
		end
	end
	Check("[HF-B] chaque ligne du document : présente, code, points, portée, noms, description, titre, aides, cosmétique",
		#bad == 0, table.concat(bad, ", "))
	local off = {}
	for cat, n in pairs(WHOLE) do if counts[cat] ~= n or expected[cat] ~= n then off[#off + 1] = cat end end
	Check("[HF-B] comptes par catégorie : Créatures 29, Brillantes 12, Zones 23, Jour 14, Guilde 7", #off == 0,
		table.concat(off, ", "))
	Check("[HF-B] Insolite : les 8 lignes de la collection et du compagnon ; grands hauts faits : 6",
		counts.fun == 8 and counts.meta == 6)
	local fewer = 0
	for _, id in ipairs(NS.FEAT_MENAGERIE_IDS) do if NS:FeatDef(id) then fewer = fewer + 1 end end
	-- 2.14.0 : + « Joyeux Voile d'hiver » (fun_winter_veil, hors du document de départ)
	Check("[HF-B] lignes du lot : 84, sans doublon avec les lignes de départ", #NS.FEAT_MENAGERIE_IDS == 84 and fewer == 84)
	-- récompenses déplacées : mêmes aides et cosmétiques qu'avant
	local same = true
	for _, rank in ipairs(NS.TRAINER_RANKS) do
		local def = NS:FeatDef("men_species_" .. rank.count)
		local aids = {}
		for _, id in ipairs(rank.aids or {}) do aids[id] = (aids[id] or 0) + 1 end
		for id, n in pairs(aids) do if (def.reward.aids or {})[id] ~= n then same = false end end
		if rank.cosmetic and not (def.reward.cosmetic and def.reward.cosmetic[1] == rank.cosmetic.kind
			and def.reward.cosmetic[2] == rank.cosmetic.id) then same = false end
		if type(def.paid) ~= "function" then same = false end
	end
	for _, reward in ipairs(NS.SHINY_REWARDS) do
		local def = NS:FeatDef("shiny_found_" .. reward.count)
		local cosm = def.reward.cosmetic or { "app", def.reward.appearance }
		if cosm[1] ~= reward.kind or cosm[2] ~= reward.def.id then same = false end
	end
	Check("[HF-B] paliers d'espèces et de brillantes : mêmes aides et cosmétiques qu'avant, payés par le haut fait", same)
	local titles = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 32, 33, 34, 38, 40 }
	local missing = {}
	for _, code in ipairs(titles) do if not (NS.FEAT_TITLES[code] and NS.FEAT_TITLES[code].en) then missing[#missing + 1] = code end end
	Check("[HF-B] titres du lot au registre (formes FR et EN)", #missing == 0 and NS:FeatTitleText(12, nil, "f") == "Chasseuse de brillantes"
		and NS:FeatTitleText(13, "Dyokrion", "m") == "Dyokrion, Maître des brillantes", table.concat(missing, ", "))
	local parity = {}
	local set = NS.FEAT_MENAGERIE_STRINGS
	for key in pairs(set.fr) do if set.en[key] == nil then parity[#parity + 1] = key end end
	for key in pairs(set.en) do if set.fr[key] == nil then parity[#parity + 1] = key end end
	Check("[HF-B] chaînes : mêmes clés en français et en anglais", #parity == 0, table.concat(parity, ", "))
	Check("[HF-B] .toc : chargé juste après FeatsData.lua", (function()
		local h = io.open(ROOT .. "/QuestCompanion/QuestCompanion.toc", "rb")
		local toc = h and h:read("*a") or ""
		if h then h:close() end
		-- les catalogues (ménagerie, puis jeu) entre les données et le moteur
		return toc:find("FeatsData.lua\nFeatsCatMenagerie.lua\n", 1, true) ~= nil
			and toc:find("FeatsCatMenagerie.lua\n[%w_\n.]-Feats.lua\n") ~= nil
	end)())
	-- lot E : les cosmétiques du compagnon existent (FeatsCosmetics.lua) ; la fiche de dresseur attend encore
	Check("[HF-B] cosmétiques pas encore fabriqués : en attente (reward.soon), pas de déblocage fantôme",
		NS:FeatDef("men_boss_1").reward.cosmetic[2] == "feat_chain" and NS:FeatDef("men_boss_1").reward.soon == nil
		and NS:FeatDef("men_species_500").reward.cosmetic == nil and NS:FeatDef("men_species_500").reward.soon[2] == "card_census")
end

-- 2. Une obtention par sorte de critère --------------------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot B : critères")
	HM.Reset()
	local c = Creatures()
	-- étoiles : 25 espèces à 3 étoiles ; types : 40 bêtes
	for i = 1, 40 do c[5000 + i] = { name = "Loup " .. i, normal = true, class = "normal", type = "Bête", stars = (i <= 25) and 3 or 1 } end
	NS:CaptureData().count, NS:CaptureData().serial = 40, 1
	local appat = Aid("appat")
	Eval()
	Check("[HF-B] étoiles : « Spécimen parfait » et « Galerie trois étoiles » (25), deux appâts",
		Got("men_stars3_1") and Got("men_stars3_25") and not Got("men_stars3_100") and Aid("appat") >= appat + 2)
	Check("[HF-B] types : bêtes au palier 3 (40) ; pas encore les huit types", Got("men_type_beast")
		and not Got("men_type_humanoid") and not Got("men_types_t1"))
	-- palier 1 partout : 10 par type courant, 5 par type rare
	local n = 6000
	for _, key in ipairs(NS.CREATURE_TYPES) do
		for _ = 1, NS:MenagerieTypeTiers(key)[1] do
			n = n + 1
			c[n] = { name = "Bête " .. n, normal = true, type = NS:CreatureTypeLabel(key) }
		end
	end
	NS:CaptureData().serial = 2
	Eval()
	Check("[HF-B] types : palier 1 dans les huit (« Touche-à-tout »)", Got("men_types_t1"))
	-- rangs : élite, rare, boss du monde
	c[7001] = { name = "Gros", normal = true, class = "elite" }
	c[7002] = { name = "Rare", normal = true, class = "rareelite" }
	c[7003] = { name = "Colosse", normal = true, class = "worldboss" }
	NS:CaptureData().serial = 3
	Eval()
	Check("[HF-B] rangs : élite, rare, boss du monde capturés", Got("men_elite_1") and Got("men_rare_1") and Got("men_boss_1")
		and not Got("men_rare_10"))
	-- Insolite : Lardeur, murlocs, bestiole
	c[NS.FEAT_HOGGER] = { name = "Lardeur", normal = true, class = "elite" }
	for i = 1, 5 do c[7100 + i] = { name = "Murloc côtier " .. i, normal = true } end
	c[7200] = { name = "Lapin", normal = true, class = "trivial" }
	NS:CaptureData().serial = 4
	Eval()
	Check("[HF-B] Insolite : Lardeur en laisse, 5 murlocs, une bestiole", Got("fun_hogger_capture") and Got("fun_murlocs")
		and Got("fun_critter"))
	-- brillantes : trouvées (compteur), repérées, capturée élite à 3 étoiles, zones
	local shiny = NS:ShinyData()
	shiny.count = 5
	shiny.seen[5001] = 1
	for z = 1, 10 do shiny.zones[1400 + z] = { [1] = 1 } end
	c[7001].shiny, c[7001].shinyStars = true, 3
	NS:CaptureData().serial = 5
	Eval()
	Check("[HF-B] brillantes : repérée, 5 trouvées (cadre étincelant), élite brillante à 3 étoiles, 10 zones",
		Got("shiny_seen_1") and Got("shiny_found_5") and NS:CompanionData().unlocked["frame:sparkle"] == true
		and Got("shiny_elite") and Got("shiny_3stars") and Got("shiny_zones_10") and Got("shiny_cap_1"))
	-- sceaux : 5 zones, puis tout l'Est, puis un par biome
	local seals = NS:MenagerieCollectionData().seals
	local ek = NS.FeatContinentZones(NS, "ek", true)
	for i = 1, 5 do seals[ek[i]] = 1 end
	Eval()
	Check("[HF-B] sceaux : 5 zones (sifflet), pas encore tout l'Est", Got("zone_seal_5") and not Got("zone_seal_ek"))
	local cur, max = NS:FeatProgress("zone_seal_ek")
	Check("[HF-B] … « Sceaux de l'Est » : barre x/y sur les zones à sceau de l'Est", cur == 5 and max == #ek and max >= 15,
		cur .. "/" .. max)
	for _, z in ipairs(ek) do seals[z] = 1 end
	for zoneID, biome in pairs(NS.MENAGERIE_ZONE_BIOME) do
		if NS:MenagerieBiomeSeals(biome) == 0 then seals[zoneID] = 1 end
	end
	Eval()
	Check("[HF-B] sceaux : toutes les zones de l'Est, les dix biomes, 15 zones", Got("zone_seal_ek") and Got("zone_all_biomes")
		and Got("zone_seal_15") and not Got("zone_seal_ka"))
	-- zones à 100 % : paliers de friandises
	local marks = NS:CompanionData()
	marks.milestones = {}
	for _, z in ipairs(NS.FeatContinentZones(NS, "ek")) do marks.milestones[z] = 100 end
	marks.milestones[1411] = 75
	Eval()
	Check("[HF-B] zones à 100 % : une, dix, tout l'Est ; 25 paliers franchis ; pas Kalimdor", Got("zone_100_1")
		and Got("zone_100_10") and Got("zone_ek_100") and Got("zone_milestones_25") and not Got("zone_ka_100"))
	-- coffres
	local chests = NS:ChestData()
	chests[1429] = { opened = true, golden = true }
	for i = 1, 10 do chests[2000 + i] = { opened = true } end
	Eval()
	Check("[HF-B] coffres : une zone dorée, 10 coffres ouverts", Got("zone_golden") and Got("zone_chests_10"))
	-- missions, jours parfaits, auberge, kilomètres, jours ensemble
	local data = NS:CompanionData()
	Mock.now = 400 * 86400
	data.missionsDone, data.travel, data.since = 100, 120000, time() - 40 * 86400
	local daily, inn = NS:DailyData()
	daily.perfect, inn.total = 10, 30
	Eval()
	local why = {}
	for _, id in ipairs({ "day_mission_25", "day_mission_100", "day_perfect_10", "day_inn_30", "day_travel_100", "day_days_30" }) do
		if not Got(id) then local a, b, st = NS:FeatProgress(id); why[#why + 1] = id .. "=" .. a .. "/" .. b .. st end
	end
	Check("[HF-B] au jour le jour : 100 missions (titre), jours parfaits, auberge, 100 km, un mois ensemble",
		Got("day_mission_25") and Got("day_mission_100") and Got("day_perfect_10") and Got("day_inn_30")
		and Got("day_travel_100") and not Got("day_travel_1000") and Got("day_days_30") and not Got("day_days_365"), table.concat(why, " "))
	-- grands hauts faits : 15 de Zones (quelques relevés en plus)
	for _, id in ipairs({ "zone_visit_10", "zone_visit_25", "zone_villages_10", "zone_villages_25" }) do NS:FeatAward(id, { silent = true }) end
	Eval()
	Check("[HF-B] grands hauts faits : « Sceaux et chemins » (15 de Zones)", Got("meta_zones"))
	local mcur, mmax = NS:FeatProgress("meta_trainer")
	Check("[HF-B] « Dresseur de légende » : liste cochée (3 métas + 1000 points)", mmax == 4 and mcur >= 1 and not Got("meta_trainer"),
		mcur .. "/" .. mmax)
end

-- 3. Crochets : volée, série d'échecs, écart de niveau, groupe, nuit, guilde, fiches, continents -------------
do
	Say("-- qc27 hauts faits, lot B : crochets")
	HM.Reset()
	local function Resolve(success, target)
		target = target or {}
		target.npcID, target.name, target.class = target.npcID or 9001, target.name or "Raptor", target.class or "normal"
		return NS:CaptureResolve({ success = success, target = target })
	end
	for _ = 1, 9 do Resolve(false) end
	Check("[HF-B] échecs de suite : compteur de compte (9)", NS:FeatCount("capFail", nil, "account") == 9)
	Resolve(true, { npcID = 9002 })
	Check("[HF-B] … une réussite remet la série à zéro", NS:FeatCount("capFail", nil, "account") == 0)
	for _ = 1, 10 do Resolve(false) end
	HM.level, HM.group, HM.hour = 20, true, "03"
	Resolve(true, { npcID = 9003, level = 26 })
	Eval()
	Check("[HF-B] 10 échecs : « Il s'est encore échappé » (titre Bredouille, 3 appâts)", Got("men_bad_luck"))
	Check("[HF-B] capture 6 niveaux au-dessus, en groupe, à 3 h : trois faits ponctuels",
		Got("men_level_gap") and Got("soc_group_capture") and Got("fun_night_owl"))
	-- volée « Tout capturer »
	local results = {}
	for i = 1, 5 do results[i] = { success = true, target = { npcID = 9100 + i, name = "B" .. i } } end
	NS:CaptureBatchFlush({ messages = {}, results = results, tried = 5 })
	Eval()
	Check("[HF-B] volée de 5 prises : « Coup de filet »", Got("men_batch_5"))
	-- exploits de guilde vus, fiches d'autres dresseurs
	for i = 1, 25 do NS:GuildFeatsEnqueue({ key = "m" .. i, score = 1 }) end
	for i = 1, 11 do NS:TrainerOpen("Ami" .. i .. "-Royaume") end
	NS:TrainerOpen(nil)
	Eval()
	Check("[HF-B] guilde : 25 exploits vus ; 10 fiches différentes (11 ouvertes, la mienne ignorée)",
		Got("soc_guild_cheer") and Got("soc_card_1") and Got("soc_card_10") and NS:FeatCount("cards", nil, "account") == 10)
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	-- deux continents le même jour
	NS:FeatNoteContinent(1429)
	Check("[HF-B] continents : l'Est seul ne suffit pas", NS:FeatStore("char").flag.twoCont == nil)
	NS:FeatNoteContinent(1411)
	Eval()
	Check("[HF-B] … puis Kalimdor le même jour : « Deux continents en un jour »", Got("zone_two_continents"))
	-- caresses, semaine bouclée, brillante en zone scellée
	NS:MissionGrant("allWeekly")
	NS:MenagerieCollectionData().seals[1429] = 1
	NS:ShinyKill("guid-1", { zoneID = 1429, npcID = 9200, name = "Brille" })
	Eval()
	Check("[HF-B] semaine bouclée ; brillante abattue dans une zone scellée", Got("day_weekly_all") and Got("shiny_sealed"))
	-- compagnon emmené : effet actif d'un boss du monde
	local store = NS:FeatStore("account")
	store.ctypes = { beast = true, humanoid = true, undead = true, elemental = true, dragonkin = true, demon = true, giant = true }
	Eval()
	Check("[HF-B] compagnons emmenés : 7 types sur 8, pas encore", not Got("men_companion_types"))
	store.ctypes.mechanical = true
	Eval()
	Check("[HF-B] … le huitième : « Tour de la collection »", Got("men_companion_types"))
	-- relevés du carnet : deux continents datés le même jour (migration)
	HM.Reset()
	local journal = NS:CharData().journal or {}
	NS:CharData().journal = journal
	journal.stamps = journal.stamps or {}
	journal.stamps["zone:1429"] = { kind = "zone", at = 86400 * 100 + 10 }
	journal.stamps["zone:1411"] = { kind = "zone", at = 86400 * 100 + 5000 }
	Check("[HF-B] relevés « zone » des deux continents le même jour : acquis d'après le carnet",
		NS.FEAT_SOURCES.twoContinents.get(NS) == 1)
	-- le moteur endormi : les crochets ne touchent à rien
	NS.featsDormant = true
	Resolve(false)
	Check("[HF-B] moteur endormi : les crochets ne comptent rien", NS:FeatCount("capFail", nil, "account") == 0)
	NS.featsDormant = false
end

-- 4. Récompenses déplacées : un seul don, rien de perdu ---------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot B : récompenses déplacées")
	-- joueur de la 2.6 : paliers 10 et 25 payés par l'ancien système
	HM.Reset()
	local c = Creatures()
	for i = 1, 30 do c[8000 + i] = { name = "E" .. i, normal = true } end
	NS:CaptureData().count = 30
	local coll = NS:MenagerieCollectionData()
	coll.ranks[10], coll.ranks[25], coll.init = 40000, 50000, true
	NS:CompanionData().unlocked["frame:trainer"] = true
	NS:ShinyData().count = 6
	NS:CompanionData().unlocked["frame:sparkle"] = true
	local appat, lasso = Aid("appat"), Aid("lasso")
	local found = NS:FeatLogin()
	local got10, got25 = NS:FeatGot("men_species_10"), NS:FeatGot("men_species_25")
	Check("[HF-B] 2.6 → 2.7 : paliers payés obtenus en silence (r), à la date du palier", got10 and got10.r and got10.at == 40000
		and got25 and got25.r and got25.at == 50000 and #found >= 3)
	Check("[HF-B] … aucune aide redonnée (palier déjà payé)", Aid("lasso") == lasso and Aid("appat") <= appat + 1,
		Aid("appat") .. "/" .. appat)
	Check("[HF-B] … cosmétiques gardés, brillantes : « Œil de pie » sans rien doubler", NS:CompanionData().unlocked["frame:trainer"]
		and Got("shiny_found_5") and NS:CompanionData().unlocked["frame:sparkle"] == true)
	local announced = false
	for _, info in ipairs(HM.earned) do if info.announce then announced = true end end
	Check("[HF-B] … rattrapage silencieux : aucune annonce, un seul bandeau groupé au plus", not announced
		and #NS.featPending <= 1)
	-- palier franchi en 2.7 : l'ancien système note le palier sans rien donner, le haut fait paie une fois
	for i = 31, 50 do c[8000 + i] = { name = "E" .. i, normal = true } end
	NS:CaptureData().count = 50
	local sifflet = Aid("sifflet")
	Mock:Reset()
	local gained = NS:MenagerieRankCheck()
	Check("[HF-B] palier 50 franchi : noté (annonce de guilde), marqué payé par le haut fait, rien donné ici",
		#gained == 1 and coll.ranks[50] ~= nil and coll.featRanks[50] == true and Aid("sifflet") == sifflet
		and not NS:CompanionData().unlocked["bg:menagerie"] and not Mock:Output():find("espèces capturées : te voilà", 1, true))
	Eval()
	Check("[HF-B] … « Enclos animés » paie : un sifflet et le fond de la collection", Got("men_species_50")
		and Aid("sifflet") == sifflet + 1 and NS:CompanionData().unlocked["bg:menagerie"] == true)
	NS:FeatCacheReset()
	Eval()
	NS:MenagerieRankCheck()
	Check("[HF-B] … une seconde passe : rien de plus", Aid("sifflet") == sifflet + 1)
	-- brillantes : l'ancien déblocage ne passe plus, le haut fait si
	NS:ShinyData().count = 15
	Check("[HF-B] 15 brillantes : ShinyCheckRewards laisse le haut fait débloquer", #NS:ShinyCheckRewards() == 0
		and not NS:CompanionData().unlocked["bg:stardust"])
	Eval()
	Check("[HF-B] … « Poussière d'étoiles » débloque le fond", Got("shiny_found_15") and NS:CompanionData().unlocked["bg:stardust"])
	-- moteur endormi (ou absent) : l'ancien système paie comme avant
	HM.Reset()
	NS.featsDormant = true
	for i = 1, 10 do Creatures()[8500 + i] = { name = "D" .. i, normal = true } end
	local before = Aid("lasso")
	NS:MenagerieRankCheck({ quiet = true })
	Check("[HF-B] moteur endormi : le palier 10 paie comme avant (appât, lasso), sans marque",
		Aid("lasso") == before + 1 and NS:MenagerieCollectionData().featRanks == nil)
	NS.featsDormant = false
	local paid = NS:FeatDef("men_species_10").paid(NS)
	Check("[HF-B] … et compte comme déjà payé pour le haut fait", paid == true)
end

-- 5. Union du compte : deux personnages ----------------------------------------------------------------------
do
	Say("-- qc27 hauts faits, lot B : union du compte")
	HM.Reset()
	local db = NS:DB()
	db.chars["Autre-Royaume"] = { companion = {
		capture = { serial = 9, count = 6, creatures = {
			[1] = { name = "Rare A", normal = true, class = "rare" }, [2] = { name = "Rare B", normal = true, class = "rare" },
			[3] = { name = "Rare C", normal = true, class = "rare" }, [4] = { name = "Rare D", normal = true, class = "rare" },
			[5] = { name = "Rare E", normal = true, class = "rare", stars = 3 },
			[6] = { name = "Partagé", normal = true, class = "rare" } } },
		shiny = { count = 3, seen = { [1] = 1 }, zones = { [1411] = {} } } } }
	-- 2.9.0 : collection au compte, recréée en versant l'autre personnage
	db.capture, NS.captureMergedChar = nil, nil
	local c = Creatures()
	for i = 6, 10 do c[i] = { name = "Rare " .. i, normal = true, class = "rare" } end
	NS:CaptureData().serial = 1
	NS:ShinyData().count = 2
	Eval()
	local scan = NS:FeatMenagerieScan()
	Check("[HF-B] rares : union des deux personnages (1 à 10, le 6 compté une fois)", scan.rare == 10 and Got("men_rare_10"),
		tostring(scan.rare))
	Check("[HF-B] brillantes trouvées : somme des deux (3 + 2 = 5)", scan.shinyFound == 5 and Got("shiny_found_5"))
	Check("[HF-B] étoiles et repérées : celles de l'autre personnage comptent", Got("men_stars3_1") and Got("shiny_seen_1"))
	-- l'autre personnage se connecte : les hauts faits de compte le suivent
	HM.name = "Autre"
	Check("[HF-B] l'autre personnage : mêmes hauts faits de compte", Got("men_rare_10") and Got("shiny_found_5"))
	HM.name = nil
	-- palier payé sur l'autre personnage en 2.6 : pas de double don sur celui-ci
	db.chars["Autre-Royaume"].companion.collection = { ranks = { [10] = 30000 } }
	Check("[HF-B] palier payé sur un autre personnage : déjà payé pour le compte", NS:FeatDef("men_species_10").paid(NS) == true)
	db.chars["Autre-Royaume"].companion.collection.featRanks = { [10] = true }
	Check("[HF-B] … sauf s'il a été noté en 2.7 (le haut fait paie)", NS:FeatDef("men_species_10").paid(NS) == false)
end

-- remise en état pour les modules suivants
for name, fn in pairs(HM.saved) do _G[name] = fn end
NS.featsDormant = HM.savedDormant
NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
NS.featLoginDone = nil
NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
if NS.journalToast then NS.journalToast:Hide() end
if NS.trainerFrame then NS.trainerFrame:Hide() end
NS:FeatStatReset()
NS:FeatMenagerieScanReset()
ResetWorld()
