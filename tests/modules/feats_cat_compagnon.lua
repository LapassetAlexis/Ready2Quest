-- QuestCompanion 3.7.0, étape 1, chantier B2b : le catalogue de la deuxième
-- édition, Zones et sceaux, Au jour le jour, Compagnon, Entre dresseurs,
-- Insolite, Tours de force et Grands hauts faits (FeatsCatCompagnon.lua).
-- Chaque ligne (code, points, catégorie, portée, textes FR/EN), les titres,
-- les secrets et leurs indices, les lignes en attente, chaque source neuve sur
-- une sauvegarde fabriquée (zéro, juste sous le seuil, au seuil) et son
-- rattrapage, les lignes sur compteur, les états signalés en direct, le
-- cache des sources qui balaient la collection, les grands hauts faits.
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.QNS

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

local SAVED = {}
for _, name in ipairs({ "UnitName", "UnitLevel", "date", "InCombatLockdown", "UnitAffectingCombat", "PlaySound" }) do
	SAVED[name] = rawget(_G, name)
end
local SAVED_NS = {}
for _, name in ipairs({ "ZoneMedalCounts", "CaptureEarliestAt", "CompanionWinterKey" }) do SAVED_NS[name] = rawget(NS, name) end
local SAVED_DORMANT = NS.featsDormant

local function Reset()
	ResetWorld()
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return nil end
	_G.UnitLevel = function() return 20 end
	_G.date = os.date
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.PlaySound = function() return true end
	for name, fn in pairs(SAVED_NS) do NS[name] = fn end
	NS.CompanionWinterKey = function() return nil end
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = nil
	NS.journalToasts, NS.journalChats = {}, {}
	NS:CompanionData().tutoDone = true
	NS:FeatCompagnonCacheReset()
end
local function Def(id) return NS:FeatDef(id) end
local function Prog(id) NS:FeatCacheReset(); return NS:FeatProgress(Def(id)) end
local function Done(id) local cur, max, state = Prog(id); return state == "open" and max > 0 and cur >= max end
local function Retro() return NS:FeatEvaluate(nil, { silent = true, retroOnly = true }) end
local function Got(id) return NS:FeatGot(id) ~= nil end

-- id = { code, catégorie, points, calcul (r, e, c, f), secret }
local ROWS = [[
zone_medal_bronze_1 324 zone 5 r|zone_medal_silver_5 325 zone 10 r|zone_medal_gold_5 326 zone 25 r|zone_medal_gold_20 327 zone 50 r
zone_seal_25 328 zone 50 r|zone_seal_all 329 zone 50 r|zone_chests_25 330 zone 25 r|zone_golden_5 331 zone 25 r|zone_100_25 332 zone 50 r
zone_lore_10 333 zone 5 r|zone_lore_all 334 zone 25 r|zone_milestones_100 335 zone 25 r
day_mission_250 336 day 25 r|day_mission_500 337 day 50 r|day_perfect_30 338 day 25 r|day_perfect_100 339 day 50 r
day_weekly_10 340 day 25 c|day_weekly_25 341 day 50 c|day_inn_100 342 day 25 r|day_inn_cards_10 343 day 10 r|day_rare_100 344 day 25 r
day_played_30 345 day 10 c|day_played_100 346 day 25 c|day_played_365 347 day 50 c|day_week_1 348 day 5 f|day_week_10 349 day 10 f
day_week_52 350 day 50 f|day_swarm_10 351 day 10 f
comp_stage_2 352 comp 5 r|comp_stage_3 353 comp 5 r|comp_stage_4 354 comp 10 r|comp_stage_5 355 comp 25 r|comp_persona 356 comp 10 r
comp_radiant_60 357 comp 10 c|comp_radiant_600 358 comp 25 c|comp_radiant_3000 359 comp 50 c|comp_wish_10 360 comp 5 c
comp_wish_50 361 comp 10 c|comp_wish_250 362 comp 25 c|comp_treat_25 363 comp 5 c|comp_treat_100 364 comp 10 c|comp_treat_500 365 comp 25 c
comp_treat_all 366 comp 10 c|comp_pets_500 367 comp 25 r|comp_partners_10 368 comp 10 c|comp_partners_50 369 comp 25 c
comp_wardrobe_10 370 comp 5 r|comp_wardrobe_25 371 comp 10 r|comp_wardrobe_50 372 comp 25 r|comp_wardrobe_100 373 comp 50 r
comp_juke_fav_10 374 comp 5 e|comp_juke_list 375 comp 5 e|comp_juke_100 376 comp 10 c|comp_jokes_25 377 comp 5 c
soc_share_1 397 soc 5 c|soc_share_25 398 soc 10 c|soc_trade_25 399 soc 25 r|soc_trade_partners_5 400 soc 10 c|soc_guild_feat_10 401 soc 10 c
soc_guild_cheer_100 402 soc 10 r|soc_group_50 403 soc 10 c|soc_holders_10 404 soc 5 c|soc_card_25 405 soc 25 c|soc_photo_1 406 soc 5 f
soc_code_1 407 soc 5 f|soc_code_5 408 soc 10 f|soc_compare 409 soc 5 c|soc_mentor_1 410 soc 5 f|soc_mentor_5 411 soc 10 f
soc_mentor_10 412 soc 25 f|soc_discord 414 soc 10 c|soc_feedback 415 soc 5 c
fun_critters_10 416 fun 10 r|fun_murlocs_10 417 fun 10 r|fun_dance_100 418 fun 5 r|fun_winter_all 419 fun 10 c
fun_hogger_partner 420 fun 10 e s|fun_hogger_shiny 421 fun 25 r s|fun_namesake 422 fun 5 e s|fun_clones 423 fun 5 e s
fun_close_call 424 fun 10 c s|fun_boss_miss 425 fun 5 c s|fun_winter_song 426 fun 5 c s|fun_small_game 427 fun 5 c s|fun_wake 428 fun 5 c s
fun_full_bag 429 fun 5 e s|fos_pioneer 430 fos 0 r|fos_first_veil 431 fos 0 r|fos_unfindable 432 fos 0 c|fos_golden_legend 433 fos 0 r
meta_points_100 434 meta 5 r|meta_points_250 435 meta 5 r|meta_points_1000 436 meta 10 r|meta_points_2000 437 meta 25 r
meta_points_3000 438 meta 25 r|meta_points_4000 439 meta 50 r|meta_points_5000 440 meta 50 r|meta_spec 441 meta 25 r|meta_comp 442 meta 25 r
meta_shop 443 meta 25 r|meta_soc 444 meta 25 r|meta_fun 445 meta 25 r|meta_secrets 446 meta 25 r|meta_all 447 meta 50 r
]]
local LIST = {}
for chunk in ROWS:gmatch("[^|\n]+") do
	local id, code, cat, pts, calc, secret = chunk:match("^(%S+) (%d+) (%a+) (%d+) (%a)%s*(%a?)")
	if id then LIST[#LIST + 1] = { id = id, n = tonumber(code), cat = cat, pts = tonumber(pts), calc = calc, secret = secret == "s" } end
end
local SCOPE = { zone = "char", day = "char", comp = "char", soc = "account", fun = "account", fos = "account", meta = "account" }

-- 1. Les lignes ---------------------------------------------------------------------------------------------
do
	Say("-- hauts faits 3.7 (B2b) : les 104 lignes")
	Reset()
	local s = Steps()
	local fr, en = NS.FEAT_COMPAGNON_STRINGS.fr, NS.FEAT_COMPAGNON_STRINGS.en
	local lang = NS.L
	local pts, countable, pending, secrets = 0, 0, 0, 0
	for _, row in ipairs(LIST) do
		local def = Def(row.id)
		if not def then s.ok(row.id .. " absent", false)
		else
			s.ok(row.id .. " code", def.n == row.n, def.n)
			s.ok(row.id .. " catégorie", def.cat == row.cat, def.cat)
			s.ok(row.id .. " points", def.pts == row.pts, def.pts)
			s.ok(row.id .. " portée", def.scope == SCOPE[row.cat], def.scope)
			s.ok(row.id .. " nom FR/EN", type(fr["FEAT_" .. row.id]) == "string" and type(en["FEAT_" .. row.id]) == "string")
			local key = def.desc
			if key then s.ok(row.id .. " description FR/EN", type(fr[key]) == "string" and type(en[key]) == "string") end
			local text = NS:FeatDescription({ id = def.id, crit = def.crit, desc = def.desc })
			s.ok(row.id .. " description lisible", text ~= "" and not text:find("FEATD_", 1, true), text)
			s.ok(row.id .. " en attente si « fonction »", (def.pending == true) == (row.calc == "f"))
			s.ok(row.id .. " secret", (def.hidden == true) == row.secret)
			local kind = def.crit[1]
			if row.calc == "c" then
				s.ok(row.id .. " critère sur compteur", NS.FEAT_TALLY_KINDS[kind] ~= nil or (kind == "streak" and def.crit[2] == "cards"), kind)
			end
			if row.calc == "r" or row.calc == "e" then
				s.ok(row.id .. " rattrapable", NS.FeatRetro(def) or kind == "streak", kind)
			end
			pts = pts + def.pts
			if def.pending then pending = pending + 1 end
			if def.hidden then secrets = secrets + 1 end
			if not def.pending and def.cat ~= "fos" and not def.hidden then countable = countable + 1 end
		end
	end
	local codes = {}
	for _, def in ipairs(NS:FeatDefs()) do codes[def.n] = def.id end
	s.ok("104 lignes, code 413 réservé", #LIST == 104 and #NS.FEAT_COMPAGNON_IDS == 104 and codes[413] == nil)
	-- (la page Communauté et la comparaison sont là : « Porte ouverte », « Mon grain de sel » et « Jeu des différences » ne sont plus en attente)
	s.ok("totaux : 10 en attente, 10 secrets, 4 tours de force", pending == 10 and secrets == 10, pending .. "/" .. secrets)
	s.ok("points : 1 870 en tout", pts == 1870, pts)
	s.ok("lignes comptables : 80", countable == 80, countable)
	local glyph = false
	for _, set in ipairs({ fr, en }) do
		for _, text in pairs(set) do if text:find("★", 1, true) or text:find("☆", 1, true) or text:find("✓", 1, true) or text:find("✗", 1, true) then glyph = true end end
	end
	s.ok("aucun glyphe ★ ☆ ✓ ✗", not glyph)
	local parity = {}
	for key in pairs(fr) do if en[key] == nil then parity[#parity + 1] = key end end
	for key in pairs(en) do if fr[key] == nil then parity[#parity + 1] = key end end
	s.ok("mêmes clés en français et en anglais", #parity == 0, table.concat(parity, ", "))
	s.ok("textes versés au catalogue", NS.FEAT_DATA_STRINGS.fr.FEAT_meta_all == "Dresseur accompli" and lang.FEAT_zone_seal_all == "Azeroth scellé")
	s.check("[B2b] 104 lignes : code, catégorie, points, portée, noms et descriptions FR/EN, en attente, secrets, critère selon le calcul")
end

-- 2. Titres, récompenses, séries ----------------------------------------------------------------------------
do
	Say("-- hauts faits 3.7 (B2b) : titres, récompenses, séries")
	Reset()
	local s = Steps()
	local WANT = { [59] = "zone_seal_all", [60] = "comp_radiant_3000", [64] = "comp_wish_250", [65] = "comp_wardrobe_100",
		[66] = "soc_trade_25", [67] = "soc_mentor_10", [68] = "fos_pioneer", [69] = "meta_points_5000", [70] = "meta_soc",
		[71] = "meta_fun", [72] = "meta_all" }
	for code, id in pairs(WANT) do
		local t = NS.FEAT_TITLES[code]
		s.ok("T" .. code, t and t.src == id and t.m and t.f and t.en and Def(id).reward.title == code)
		local es = NS.FEAT_TITLES_ES and NS.FEAT_TITLES_ES[code]
		s.ok("T" .. code .. " espagnol", es and es.m and es.f)
	end
	s.ok("T72 en préfixe, féminin", NS.FEAT_TITLES[72].pos == "pre" and NS:FeatTitleText(72, nil, "f") == "Dresseuse accomplie")
	local SOON = { zone_medal_gold_20 = "card_gold_zones", day_mission_500 = "feat_volunteer", day_perfect_100 = "feat_perfect",
		soc_card_25 = "card_directory", soc_discord = "feat_worlds", fos_unfindable = "feat_unfindable",
		meta_points_1000 = "card_rank_silver", meta_points_2000 = "card_rank_gold", meta_points_4000 = "card_rank_glow",
		meta_points_500 = "card_rank_bronze" }
	for id, cosm in pairs(SOON) do
		local r = Def(id).reward
		local c = r and (r.soon or r.cosmetic)
		s.ok(id .. " " .. cosm, c and c[2] == cosm)
	end
	s.ok("meta_points_500 : id, code, points inchangés", Def("meta_points_500").n == 171 and Def("meta_points_500").pts == 10)
	-- séries : clés prolongées, échelles nouvelles, paliers de points
	s.ok("échelles prolongées", Def("zone_seal_25").series == "seals" and Def("zone_seal_all").series == "seals"
		and Def("day_mission_500").series == "missions" and Def("day_rare_100").series == "rares" and Def("soc_trade_25").series == "trades"
		and Def("soc_card_25").series == "cards" and Def("zone_100_25").series == "zones100")
	s.ok("lignes d'avant dans les échelles nouvelles", Def("day_pets_100").series == "pets" and Def("zone_golden").series == "golden"
		and Def("fun_murlocs").series == "murlocs" and Def("soc_guild_cheer").series == "guildSeen")
	local points = NS:FeatSeries("points") or {}
	s.ok("paliers de points : une série de 9, seuils croissants", #points == 9 and points[1].id == "meta_points_100"
		and points[3].id == "meta_points_500" and points[9].id == "meta_points_5000")
	s.ok("Azeroth scellé : toutes les zones à espèces (44)", Def("zone_seal_all").crit[3] == 44 and NS.FEAT_SEAL_ALL == 44)
	s.check("[B2b] titres T59, T60, T64 à T72 (FR m/f, EN, espagnol), cosmétiques à venir, séries")
end

-- 3. Secrets, lignes en attente, tours de force -------------------------------------------------------------
do
	Say("-- hauts faits 3.7 (B2b) : secrets, en attente, tours de force")
	Reset()
	local s = Steps()
	for _, row in ipairs(LIST) do
		if row.secret then
			local def = Def(row.id)
			s.ok(row.id .. " caché", NS:FeatName(def) == NS.L.FEAT_SECRET_NAME and not NS:FeatCountable(def))
			local fr, en = NS.FEAT_COMPAGNON_STRINGS.fr["FEATH_" .. row.id], NS.FEAT_COMPAGNON_STRINGS.en["FEATH_" .. row.id]
			s.ok(row.id .. " indice FR/EN", type(fr) == "string" and type(en) == "string" and fr ~= NS.FEAT_COMPAGNON_STRINGS.fr["FEATD_" .. row.id])
		end
	end
	NS:FeatStore("account").hints = { fun_wake = 1 }
	s.ok("indice révélé : la description le dit", NS:FeatDescription("fun_wake") == NS.L.FEATH_fun_wake)
	NS:FeatAward("fun_wake", { silent = true })
	s.ok("obtenu : vrai nom, comptable", NS:FeatName("fun_wake") == "Debout là-dedans !" and NS:FeatCountable("fun_wake"))
	local listed = {}
	for _, item in ipairs(NS:FeatSeriesList("all", "all")) do
		listed[item.def.id] = true
		for _, d in ipairs(item.defs or {}) do listed[d.id] = true end
	end
	for _, row in ipairs(LIST) do
		if row.calc == "f" then s.ok(row.id .. " invisible et hors total", not listed[row.id] and not NS:FeatCountable(row.id)) end
	end
	NS:FeatAward("fos_golden_legend", { silent = true })
	local total = NS:FeatPoints(nil)
	s.ok("tour de force : 0 point, hors total", Got("fos_golden_legend") and total == 5 and not NS:FeatCountable("fos_golden_legend"), total)
	s.check("[B2b] dix secrets cachés avec leur indice, 10 lignes en attente invisibles, tours de force hors total")
end

-- 4. Sources neuves : zéro, sous le seuil, au seuil, rattrapage ----------------------------------------------
do
	Say("-- hauts faits 3.7 (B2b) : sources")
	local s = Steps()
	-- médailles de zone (fonction d'un autre chantier : une fausse ici)
	Reset()
	NS.ZoneMedalCounts = nil
	s.ok("médailles : sans la fonction, 0", select(1, Prog("zone_medal_bronze_1")) == 0)
	local medals = { 0, 4, 19 }
	local calls = 0
	NS.ZoneMedalCounts = function() calls = calls + 1; return medals end
	s.ok("médailles : zéro, sous le seuil", not Done("zone_medal_bronze_1") and not Done("zone_medal_silver_5") and not Done("zone_medal_gold_20"))
	NS:FeatCompagnonCacheReset()
	medals = { 1, 5, 20 }
	local data = NS:CaptureData()
	data.serial = (tonumber(data.serial) or 0) + 1
	s.ok("médailles : au seuil", Done("zone_medal_bronze_1") and Done("zone_medal_silver_5") and Done("zone_medal_gold_5") and Done("zone_medal_gold_20"))
	local before = calls
	for _ = 1, 5 do Prog("zone_medal_gold_5") end
	s.ok("médailles : gardées tant que les captures ne bougent pas", calls == before, calls - before)
	Retro()
	s.ok("médailles : rattrapées", Got("zone_medal_gold_20") and Got("zone_medal_bronze_1"))
	-- histoire des lieux
	Reset()
	local zones = NS.FeatLoreZones()
	s.ok("histoire : des zones racontées connues", #zones >= 10)
	local told = {}
	NS:CharData().lore = { z = told, s = {} }
	for i = 1, 9 do told[zones[i]] = 100 end
	told[999999] = 100   -- zone sans histoire : ne compte pas
	s.ok("histoire : 9 zones, sous le seuil", select(1, Prog("zone_lore_10")) == 9 and not Done("zone_lore_10"))
	told[zones[10]] = 100
	s.ok("histoire : 10 zones", Done("zone_lore_10") and not Done("zone_lore_all"))
	for _, z in ipairs(zones) do told[z] = 100 end
	local cur, max = Prog("zone_lore_all")
	s.ok("histoire : toutes", Done("zone_lore_all") and max == #zones and cur == #zones, cur .. "/" .. max)
	Retro()
	s.ok("histoire : rattrapée", Got("zone_lore_10") and Got("zone_lore_all"))
	-- cartes d'auberge
	Reset()
	local _, inn = NS:DailyData()
	inn.full = 9
	s.ok("auberge : 9 cartes", not Done("day_inn_cards_10"))
	inn.full = 10
	Retro()
	s.ok("auberge : 10 cartes, rattrapées", Got("day_inn_cards_10"))
	-- stades et caractère
	Reset()
	local comp = NS:CompanionData()
	comp.stage = nil
	s.ok("stade : pas encore relevé", not Done("comp_stage_2"))
	comp.stage = 3
	Retro()
	s.ok("stade 3 : stades 2 et 3, pas 4", Got("comp_stage_2") and Got("comp_stage_3") and not Got("comp_stage_4"))
	comp.persona = { scores = {} }
	s.ok("caractère : pas formé", not Done("comp_persona"))
	comp.persona.formed = "curious"
	s.ok("caractère : formé", Done("comp_persona"))
	-- garde-robe
	Reset()
	comp = NS:CompanionData()
	comp.unlocked = { ["cardbg:card_census"] = true, ["app:x0"] = false }
	for i = 1, 9 do comp.unlocked["orn:o" .. i] = true end
	s.ok("garde-robe : 9 (les fiches ne comptent pas)", select(1, Prog("comp_wardrobe_10")) == 9)
	comp.unlocked["frame:f1"] = true
	Retro()
	s.ok("garde-robe : 10, rattrapée", Got("comp_wardrobe_10") and not Got("comp_wardrobe_25"))
	-- juke-box
	Reset()
	NS:DB().juke = { fav = {}, lists = { {}, {}, {} } }
	for i = 1, 9 do NS:DB().juke.fav[i] = true end
	s.ok("juke-box : 9 favoris, aucune liste", not Done("comp_juke_fav_10") and not Done("comp_juke_list"))
	NS:DB().juke.fav[10] = true
	NS:DB().juke.lists[2] = { 5 }
	s.ok("juke-box : 10 favoris, une liste", Done("comp_juke_fav_10") and Done("comp_juke_list"))
	-- Lardeur
	Reset()
	comp = NS:CompanionData()
	comp.appearance = "cap:449"
	s.ok("Lardeur : une autre créature", not Done("fun_hogger_partner"))
	comp.appearance = "cap:" .. NS.FEAT_HOGGER
	s.ok("Lardeur : emmené", Done("fun_hogger_partner"))
	NS.CompanionWinterKey = function() return "gfw" end
	s.ok("Lardeur : un compagnon de saison passe devant", not Done("fun_hogger_partner"))
	NS.CompanionWinterKey = function() return nil end
	data = NS:CaptureData()
	data.creatures[NS.FEAT_HOGGER] = { normal = true, class = "elite" }
	data.serial = (tonumber(data.serial) or 0) + 1
	s.ok("Lardeur brillant : capturé en normal seulement", not Done("fun_hogger_shiny"))
	data.creatures[NS.FEAT_HOGGER].shiny = true
	data.serial = data.serial + 1
	s.ok("Lardeur brillant : capturé", Done("fun_hogger_shiny"))
	-- boss du monde brillant
	data.creatures[12397] = { normal = true, class = "worldboss" }
	data.serial = data.serial + 1
	s.ok("légende dorée : boss normal", not Done("fos_golden_legend"))
	data.creatures[12397].shiny = true
	data.serial = data.serial + 1
	Retro()
	s.ok("légende dorée : boss brillant, rattrapé", Got("fos_golden_legend") and Got("fun_hogger_shiny"))
	-- spécimens : jumeaux, surnom
	Reset()
	data = NS:CaptureData()
	data.specimens = {
		[1] = { id = 1, npc = 300, stars = 2, size = "normal", trait = "curious" },
		[2] = { id = 2, npc = 300, stars = 2, size = "large", trait = "curious" },
	}
	data.specSerial = 1
	s.ok("jumeaux : tailles différentes", not Done("fun_clones"))
	data.specimens[3] = { id = 3, npc = 300, stars = 2, size = "large", trait = "curious" }
	s.ok("jumeaux : relus seulement quand le numéro de série change", not Done("fun_clones"))
	data.specSerial = 2
	s.ok("jumeaux : identiques", Done("fun_clones"))
	data.specimens[2].nick = "Bob"
	data.specSerial = 3
	s.ok("mon double : un autre nom", not Done("fun_namesake"))
	data.specimens[2].nick = " testeur "
	data.specSerial = 4
	s.ok("mon double : le nom du joueur", Done("fun_namesake"))
	-- besace pleine
	Reset()
	data = NS:CaptureData()
	data.items.appat, data.items.lasso, data.items.sifflet = 10, 5, 2
	s.ok("besace : il manque un sifflet", not Done("fun_full_bag"))
	data.items.sifflet = 3
	s.ok("besace : pleine", Done("fun_full_bag"))
	-- pionnier
	Reset()
	NS.CaptureEarliestAt = function() return nil end
	s.ok("pionnier : aucune capture", not Done("fos_pioneer"))
	NS.CaptureEarliestAt = function() return os.time({ year = 2027, month = 1, day = 2, hour = 12 }) end
	s.ok("pionnier : en 2027, non", not Done("fos_pioneer"))
	NS.CaptureEarliestAt = function() return os.time({ year = 2026, month = 12, day = 31, hour = 12 }) end
	Retro()
	s.ok("pionnier : en 2026, rattrapé, titre T68", Got("fos_pioneer") and NS.FEAT_TITLES[68].src == "fos_pioneer")
	-- premier Voile d'hiver
	Reset()
	local flag = NS:FeatStore("account").flag
	flag.winterVeil = os.time({ year = 2027, month = 12, day = 20, hour = 12 })
	s.ok("premier Voile : en 2027, non", not Done("fos_first_veil"))
	flag.winterVeil = os.time({ year = 2026, month = 12, day = 14, hour = 12 })
	s.ok("premier Voile : avant la saison, non", not Done("fos_first_veil"))
	flag.winterVeil = os.time({ year = 2027, month = 1, day = 2, hour = 12 })
	s.ok("premier Voile : le 2 janvier 2027, oui", Done("fos_first_veil"))
	flag.winterVeil = os.time({ year = 2026, month = 12, day = 15, hour = 12 })
	Retro()
	s.ok("premier Voile : le 15 décembre 2026, rattrapé", Got("fos_first_veil"))
	-- secrets découverts
	Reset()
	local ids = { "fun_wake", "fun_clones", "fun_namesake", "fun_boss_miss" }
	for _, id in ipairs(ids) do NS:FeatAward(id, { silent = true }) end
	s.ok("secrets : 4", select(1, Prog("meta_secrets")) == 4 and not Done("meta_secrets"))
	NS:FeatAward("fun_small_game", { silent = true })
	Retro()
	s.ok("secrets : 5, rattrapé", Got("meta_secrets"))
	s.check("[B2b] sources neuves : médailles (fausse ZoneMedalCounts, cache), histoire, cartes d'auberge, stades, caractère, "
		.. "garde-robe, juke-box, Lardeur, spécimens (cache sur le numéro de série), besace, pionnier, premier Voile, secrets ; rattrapage")
end

-- 5. Lignes sur compteur : pas avant, au seuil ; compteurs du moteur rattrapés ---------------------------------
do
	Say("-- hauts faits 3.7 (B2b) : compteurs")
	local s = Steps()
	Reset()
	for _, row in ipairs(LIST) do
		local def = Def(row.id)
		local kind = def.crit[1]
		if NS.FEAT_TALLY_KINDS[kind] and not def.pending then
			local key, n, scope = def.crit[2], def.crit[3], def.crit[4] == "char" and "char" or "account"
			local function Set(value)
				if kind == "tally" then
					local cur = NS:TallyGet(key, scope)
					NS:TallyAdd(key, value - cur, scope)
				elseif kind == "tallymax" then NS:TallyMax(key, value, scope)
				else for i = NS:TallySize(key, scope) + 1, value do NS:TallyMark(key, "m" .. i, scope, 1000) end end
			end
			Set(n - 1)
			s.ok(row.id .. " sous le seuil", not Done(row.id))
			s.ok(row.id .. " jamais rattrapé", not NS.FeatRetro(def))
			Set(n)
			NS:FeatEvaluate({ tally = true }, { silent = true })
			s.ok(row.id .. " au seuil", Got(row.id))
		end
	end
	s.check("[B2b] lignes sur compteur (Tally.lua) : pas obtenues sous le seuil, obtenues au seuil, jamais rattrapées")

	-- compteurs du moteur déjà tenus (streak) : rattrapés en silence à la connexion
	s = Steps()
	Reset()
	NS:FeatStore("char").ctr.pets = 499
	NS:FeatStore("account").ctr.trades = 25
	NS:FeatStore("account").ctr.guildSeen = 100
	NS:FeatStore("account").ctr.cards = 25
	NS:FeatStore("account").ctr.dances = 100
	NS:FeatLogin()
	s.ok("rattrapés", Got("soc_trade_25") and Got("soc_guild_cheer_100") and Got("soc_card_25") and Got("fun_dance_100"))
	s.ok("en silence", NS:FeatGot("soc_trade_25").r == true)
	s.ok("caresses : 499, pas encore", not Got("comp_pets_500"))
	NS.featLoginDone = nil
	NS:FeatStore("char").ctr.pets = 500
	NS:FeatLogin()
	s.ok("caresses : 500", Got("comp_pets_500"))
	s.check("[B2b] compteurs du moteur (caresses, échanges, exploits vus, fiches, danses) : rattrapés en silence à la connexion")
end

-- 6. En direct : les états signalent leur sujet --------------------------------------------------------------
do
	Say("-- hauts faits 3.7 (B2b) : en direct")
	local s = Steps()
	Reset()
	local function Dirty(topic) return NS.featDirty[topic] == true end
	NS:DB().juke = nil
	local track = NS:MusicCatalog().list[1]
	NS.featDirty = {}
	NS:JukeToggleFav(track.id)
	s.ok("favori du juke-box : sujet « juke »", Dirty("juke"))
	NS.featDirty = {}
	NS:JukeListToggle(1, track.id)
	s.ok("liste du juke-box : sujet « juke »", Dirty("juke"))
	NS.featDirty = {}
	NS:CaptureData().items.appat = 0
	NS:CaptureGrant("appat", { quiet = true, silent = true })
	s.ok("aide rangée : sujet « aids »", Dirty("aids"))
	local data = NS:CaptureData()
	data.specimens = data.specimens or {}
	data.specimens[77] = { id = 77, npc = 300, stars = 1, size = "normal" }
	NS.featDirty = {}
	NS:SpecimenSetNick(77, "Testeur")
	s.ok("surnom : sujet « specimen »", Dirty("specimen"))
	NS.featDirty = {}
	NS:CompanionCheckStage(20, false)
	s.ok("stade relevé : sujet « companion »", Dirty("companion"))
	NS.featDirty = {}
	NS.featEvalAt = nil
	-- un état vrai : attribué par la passe suivante, sans attendre la connexion
	data.items.appat, data.items.lasso, data.items.sifflet = 9, 5, 3
	NS.featLoginDone, NS.featLoginAt = true, nil
	NS:CaptureGrant("appat", { quiet = true, silent = true })
	NS:FeatEvaluate(NS.featDirty)
	s.ok("besace pleine : attribuée en direct", Got("fun_full_bag"))
	NS.featDirty = {}
	NS.featsDormant = true
	NS:JukeToggleFav(track.id)
	s.ok("moteur endormi : rien", not Dirty("juke"))
	NS.featsDormant = false
	s.check("[B2b] en direct : juke-box, aides, surnom, stade signalent leur sujet ; un état vrai est attribué sans attendre la connexion")
end

-- 7. Grands hauts faits ----------------------------------------------------------------------------------------
do
	Say("-- hauts faits 3.7 (B2b) : grands hauts faits")
	local s = Steps()
	Reset()
	s.ok("critères", Def("meta_spec").crit[2] == "spec" and Def("meta_spec").crit[3] == 15 and Def("meta_shop").crit[2] == "shop"
		and Def("meta_shop").crit[3] == 10 and Def("meta_comp").crit[3] == 15 and Def("meta_soc").crit[3] == 10 and Def("meta_fun").crit[3] == 15)
	-- branchement (les lignes nouvelles de spec et shop sont dans l'autre chantier) : chaque ligne obtenue compte
	NS:FeatAward("men_stars3_1", { silent = true })
	NS:FeatAward("men_patron_10", { silent = true })
	NS:FeatAward("men_size_giant", { silent = true })
	s.ok("Spécimens : branché", select(1, Prog("meta_spec")) == 2)
	s.ok("Réserve et Échoppe : branché", select(1, Prog("meta_shop")) == 1)
	local n = 0
	for _, def in ipairs(NS:FeatDefs()) do
		if def.cat == "comp" and n < 15 then NS:FeatAward(def, { silent = true }); n = n + 1 end
	end
	Retro()
	s.ok("Compagnon : 15 lignes du personnage", Got("meta_comp"))
	local all = Def("meta_all").crit[2]
	s.ok("tous les grands hauts faits de dresseur", table.concat(all, ",") == "meta_menagerie,meta_shiny,meta_spec,meta_shop,meta_soc,meta_fun")
	for _, id in ipairs(all) do if id ~= "meta_fun" then NS:FeatAward(id, { silent = true }) end end
	Retro()
	s.ok("dresseur accompli : il en manque un", not Got("meta_all"))
	NS:FeatAward("meta_fun", { silent = true })
	Retro()
	s.ok("dresseur accompli : tous", Got("meta_all") and #NS:FeatChecklist("meta_all") == 6)
	Reset()
	NS:FeatAward("men_species_500", { silent = true })
	NS:FeatAward("men_species_250", { silent = true })
	NS:FeatAward("men_boss_1", { silent = true })
	Retro()
	s.ok("points : 125 → 100, pas 250", Got("meta_points_100") and not Got("meta_points_250"))
	s.check("[B2b] grands hauts faits : Spécimens et Échoppe branchés, Compagnon, dresseur accompli (liste des six), paliers de points")
end

-- rangement
for name, fn in pairs(SAVED) do _G[name] = fn end
for name, fn in pairs(SAVED_NS) do NS[name] = fn end
NS.featsDormant = SAVED_DORMANT
