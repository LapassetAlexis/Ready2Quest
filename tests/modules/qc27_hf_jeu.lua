-- QuestCompanion 2.7.x, lot C des hauts faits : le jeu lui-même
-- (FeatsCatJeu.lua). Lignes et comptes par catégorie (document §2.6 à §2.11),
-- statistiques du client par sorte de ligne, replis de notre propre suivi
-- (niveau, plus haut solde, métiers, réputations, boss en instance, quêtes,
-- morts, vols, montures, émotes), lignes « à vérifier » jamais attribuées,
-- rattrapage silencieux depuis les chiffres de toute la vie, portée par
-- personnage, diagnostic.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local J = { saved = {}, stats = {}, earned = {}, reads = 0 }
local GLOBALS = { "UnitName", "UnitLevel", "GetStatistic", "InCombatLockdown", "UnitAffectingCombat", "PlaySound",
	"issecretvalue", "date", "UnitFactionGroup", "IsInInstance", "GetInstanceInfo", "C_CombatLog",
	"CombatLogGetCurrentEventInfo", "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
	"GetNumFactions", "GetFactionInfo", "C_Reputation", "IsMounted", "GetUnitSpeed", "IsFlying", "hooksecurefunc",
	"DoEmote", "GetMoney" }
for _, name in ipairs(GLOBALS) do J.saved[name] = rawget(_G, name) end
J.savedDormant = NS.featsDormant

function J.Install()
	_G.UnitName = function(unit) if unit == "player" then return J.name or "Testeur" end return nil end
	_G.UnitLevel = function() return J.level or 20 end
	_G.GetStatistic = function(id)
		J.reads = J.reads + 1
		return J.stats[id]
	end
	_G.InCombatLockdown = function() return J.combat == true end
	_G.UnitAffectingCombat = function() return J.combat == true end
	_G.PlaySound = function() return true end
	_G.date = function() return "07/11/2026" end
	_G.UnitFactionGroup = function() return "Alliance" end
	_G.IsInInstance = function() return J.instance ~= nil, J.instance end
	_G.GetInstanceInfo = function() return "Instance", J.instance or "none" end
	_G.GetProfessions, _G.GetProfessionInfo, _G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil, nil, nil
	_G.GetNumFactions, _G.GetFactionInfo, _G.C_Reputation = nil, nil, nil
	_G.IsMounted = function() return J.mounted == true end
	_G.GetUnitSpeed = function() return J.speed or 0 end
	_G.IsFlying = function() return false end
end

function J.Reset(level)
	ResetWorld()
	J.name, J.level, J.combat, J.stats, J.instance, J.mounted, J.speed = nil, level or 20, false, {}, nil, nil, nil
	J.Install()
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = true          -- pas de rattrapage parasite (testé à part)
	NS:FeatStatReset()
	NS:FeatBossKillReset()
	NS:FeatJeuMemoReset()
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	if NS.journalToast then NS.journalToast:Hide() end
	NS:DB().captureMuteUntil = nil
	NS:CompanionData().tutoDone = true
	NS:FeatJeuZone()                 -- hors instance : morts de boss non écoutées
	Mock:Reset()
end

function J.Run(seconds)
	for _ = 1, math.max(1, math.floor(seconds or 1)) do Mock:Advance(1) end
end

local function Got(id) return NS:FeatGot(id) ~= nil end
local function State(id) NS:FeatCacheReset(); return select(3, NS:FeatProgress(id)) end
local function Cur(id) NS:FeatCacheReset(); return (NS:FeatProgress(id)) end

if not J.registered then
	NS:RegisterCallback("FEAT_EARNED", function(_, info) J.earned[#J.earned + 1] = info end)
	J.registered = true
end

-- 1. Lignes du lot C --------------------------------------------------------------------------------------
do
	Say("-- qc27 hauts faits du jeu : lignes")
	local counts, points, scopes = {}, {}, {}
	for _, def in ipairs(NS:FeatDefs()) do
		counts[def.cat] = (counts[def.cat] or 0) + 1
		points[def.cat] = (points[def.cat] or 0) + def.pts
		if def.cat == "char" or def.cat == "dng" or def.cat == "prof" or def.cat == "quest" then
			if def.scope ~= "char" then scopes[#scopes + 1] = def.id end
		end
	end
	Check("[HFJ] comptes du document : Personnage 21, Donjons et raids 21, Métiers 12, Quêtes 11",
		counts.char == 21 and counts.dng == 21 and counts.prof == 12 and counts.quest == 11,
		string.format("%s/%s/%s/%s", tostring(counts.char), tostring(counts.dng), tostring(counts.prof), tostring(counts.quest)))
	Check("[HFJ] points du document : 255, 490, 155, 185", points.char == 255 and points.dng == 490
		and points.prof == 155 and points.quest == 185,
		string.format("%s/%s/%s/%s", tostring(points.char), tostring(points.dng), tostring(points.prof), tostring(points.quest)))
	Check("[HFJ] portée : toutes ces catégories par personnage", #scopes == 0, table.concat(scopes, ", "))
	local fun = { "fun_hogger_death", "fun_critters_kill", "fun_drown", "fun_fall", "fun_lava", "fun_emotes", "fun_respec" }
	local missing = {}
	for _, id in ipairs(fun) do
		local def = NS:FeatDef(id)
		if not (def and def.scope == "account" and (def.crit or {})[1] == "stat") then missing[#missing + 1] = id end
	end
	for _, id in ipairs({ "meta_dungeons", "meta_hero" }) do
		if not (NS:FeatDef(id) and NS:FeatDef(id).scope == "account") then missing[#missing + 1] = id end
	end
	Check("[HFJ] Insolite (statistiques, compte) et métas des catégories du jeu", #missing == 0, table.concat(missing, ", "))
	local pending = {}
	for _, def in ipairs(NS:FeatDefs()) do
		if def.pending and (def.cat == "char" or def.cat == "dng" or def.cat == "prof" or def.cat == "quest" or def.cat == "fun") then
			pending[#pending + 1] = def.id
		end
	end
	table.sort(pending)
	local expected = { "char_camp_25", "char_epic", "char_food_500", "char_gold_looted", "char_hearth_50", "char_mount_epic",
		"char_potions_100", "dng_raid_barrow", "dng_raid_hyjal", "dng_runs_50", "fun_critters_kill", "fun_drown", "fun_fall",
		"fun_hogger_death", "fun_lava", "fun_respec", "prof_fish_250", "pvp_bg_win", "pvp_duel_10", "pvp_hk_100", "quest_valthalak" }
	table.sort(expected)
	Check("[HFJ] lignes « à vérifier » : seulement les statistiques sans repli (21)",
		table.concat(pending, ",") == table.concat(expected, ","), table.concat(pending, ","))
	local titles = {}
	for _, code in ipairs({ 22, 23, 25, 26, 27, 28, 29, 30, 31, 36, 37 }) do
		local t = NS.FEAT_TITLES[code]
		if not (t and t.m and t.en) then titles[#titles + 1] = code end
	end
	Check("[HFJ] titres de ces hauts faits au registre", #titles == 0, table.concat(titles, ","))
	Check("[HFJ] descriptions : seuils lisibles", NS:FeatDescription("char_gold_1000") == "Avoir possédé 1000 pièces d'or"
		and NS:FeatDescription("dng_tier1"):find("^Vaincre le dernier boss de 8 donjons") ~= nil
		and NS:FeatDescription("meta_dungeons") == "Obtenir les 4 paliers de donjons"
		and NS:FeatDescription("quest_500") == "Rendre 500 quêtes", NS:FeatDescription("dng_tier1"))
	Check("[HFJ] chaînes du lot : mêmes clés en français et en anglais", (function()
		local s = NS.FEAT_JEU_STRINGS
		for key in pairs(s.fr) do if s.en[key] == nil then return false end end
		for key in pairs(s.en) do if s.fr[key] == nil then return false end end
		return true
	end)())
end

-- 2. Statistiques : lecture par sorte de ligne ------------------------------------------------------------
do
	Say("-- qc27 hauts faits du jeu : statistiques")
	J.Reset(20)
	J.stats[107] = "780"
	J.stats[98] = "1 234"
	J.stats[60] = "--"
	J.stats[334] = "1500|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t 12|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
	J.stats[377] = "2"
	J.stats[1098] = "3"
	J.stats[1527] = "275"
	Check("[HFJ] compteur « 1 234 » : quêtes (stat 98)", Cur("quest_1000") == 1000 and Cur("quest_500") == 500)
	Check("[HFJ] « -- » : 0 mort, la ligne reste ouverte", Cur("char_deaths_1") == 0 and State("char_deaths_1") == "open")
	Check("[HFJ] montant d'argent (stat 334, icônes) : en pièces d'or", Cur("char_gold_1000") == 1000
		and NS.FEAT_SOURCES.goldMax.get(NS) == 1500)
	Check("[HFJ] boss par statistique de victoires (Onyxia, 1098)", NS.FEAT_SOURCES.boss_ony.get(NS) == 3)
	Check("[HFJ] métier par la plus haute compétence (stat 1527)", NS.FEAT_SOURCES.profBest.get(NS) == 275)
	Check("[HFJ] réputations : statistique sans API de factions", Cur("rep_exalted_5") == 2 and State("rep_exalted_5") == "open")
	-- illisible : le repli prend le relais
	J.stats[98] = "beaucoup"
	NS:FeatStatReset()
	NS:FeatCount("quests", 7)
	Check("[HFJ] forme illisible : notre compteur de quêtes (7)", Cur("quest_10") == 7, tostring(Cur("quest_10")))
	_G.issecretvalue = function(v) return v == "SECRET" end
	J.stats[60] = "SECRET"
	NS:FeatStatReset()
	NS:FeatCount("deaths", 1)
	Check("[HFJ] valeur secrète : notre compteur de morts", Cur("char_deaths_1") == 1)
	_G.issecretvalue = J.saved.issecretvalue
	-- sonde illisible : plus aucune statistique, les replis seuls
	J.stats[107] = nil
	NS:FeatStatReset()
	Check("[HFJ] statistiques hors service : Onyxia retombe à notre suivi (0), réputations grisées",
		NS.FEAT_SOURCES.boss_ony.get(NS) == 0 and State("rep_exalted_1") == "pending" and State("char_deaths_1") == "open")
	-- en combat : aucune lecture neuve
	J.stats[107] = "780"
	NS:FeatStatReset()
	NS:FeatStatsOK()
	J.combat, J.reads = true, 0
	NS:FeatEvaluate(nil)
	NS:FeatCacheReset()
	NS.FEAT_SOURCES.goldMax.get(NS)
	NS.FEAT_SOURCES.boss_ony.get(NS)
	Check("[HFJ] en combat : aucune statistique lue", J.reads == 0, J.reads)
	J.combat = false
end

-- 3. Replis : notre propre suivi ---------------------------------------------------------------------------
do
	Say("-- qc27 hauts faits du jeu : replis")
	J.Reset(59)
	J.level = 60
	NS:FeatTouch("level")
	J.Run(1)
	Check("[HFJ] niveau 60 (UnitLevel) : « Au sommet »", Got("char_level_60"))
	-- plus haut solde vu
	Mock.world.money = 150 * 10000
	Mock:Fire("PLAYER_MONEY")
	Mock.world.money = 3
	Mock:Fire("PLAYER_MONEY")
	J.Run(1)
	Check("[HFJ] or : le plus haut solde vu compte (150 po), pas le solde actuel", Got("char_gold_100")
		and not Got("char_gold_1000") and NS:FeatStore("char").ctr.goldMax == 1500000)
	-- morts, quêtes
	Mock:Fire("PLAYER_DEAD")
	for _ = 1, 10 do Mock:Fire("QUEST_TURNED_IN", 100) end
	J.Run(1)
	Check("[HFJ] PLAYER_DEAD et QUEST_TURNED_IN : « Ça arrive à tout le monde », « Petits services »",
		Got("char_deaths_1") and Got("quest_10") and not Got("quest_100") and NS:FeatStore("char").ctr.quests == 10)
	-- vol : passage à « en vol » après la carte des vols
	Mock.world.onTaxi = false
	Mock:Fire("PLAYER_ENTERING_WORLD", false, true)
	Mock:Fire("TAXIMAP_CLOSED")
	Mock.world.onTaxi = true
	J.Run(2)
	Mock:Fire("PLAYER_CONTROL_GAINED")
	Check("[HFJ] vol de griffon compté une fois (UnitOnTaxi)", NS:FeatStore("char").ctr.taxi == 1, NS:FeatStore("char").ctr.taxi)
	Mock.world.onTaxi = false
	-- monture vue, monture rapide (en attente : drapeau posé, jamais attribué)
	J.mounted, J.speed = true, 14
	Mock:Fire("UNIT_AURA", "player")
	J.Run(2)
	Check("[HFJ] monture vue : « Au galop » ; monture rapide notée sans être attribuée", Got("char_mount")
		and NS:FeatStore("char").flag.mountEpic ~= nil and not Got("char_mount_epic"))
	J.mounted = nil
	J.Run(2)
	-- émotes (hooksecurefunc sur DoEmote)
	_G.DoEmote = function() return true end
	_G.hooksecurefunc = function(name, fn)
		local base = _G[name]
		_G[name] = function(...) local r = base(...); fn(...); return r end
	end
	NS:FeatJeuInit()
	for _ = 1, 60 do DoEmote("HUG") end
	for _ = 1, 39 do DoEmote("wave") end
	DoEmote("DANCE")
	J.Run(1)
	Check("[HFJ] 99 émotes comptées (la danse non) : pas encore « Expressif »", NS:FeatCount("emotes", nil, "account") == 99
		and not Got("fun_emotes"))
	DoEmote("VIOLIN")
	J.Run(1)
	Check("[HFJ] … la 100e : « Expressif » (compte)", Got("fun_emotes") and NS:FeatStore("account").got.fun_emotes ~= nil)
	-- métiers
	local PROFS = { [1] = { "Alchimie", 300, 171 }, [2] = { "Minage", 300, 186 }, [3] = { "Cuisine", 300, 185 },
		[4] = { "Pêche", 300, 356 }, [5] = { "Secourisme", 300, 129 } }
	_G.GetProfessions = function() return 1, 2, nil, 4, 3, 5 end
	_G.GetProfessionInfo = function(index)
		local p = PROFS[index]
		return p[1], "icon", p[2], 300, 4, 0, p[3], 0
	end
	Mock:Fire("SKILL_LINES_CHANGED")
	J.Run(1)
	Check("[HFJ] métiers lus (GetProfessions) : premier métier, 150, 225, 300, deux à 300",
		Got("prof_first") and Got("prof_150") and Got("prof_225") and Got("prof_300") and Got("prof_double_300"))
	Check("[HFJ] … cuisine, pêche, secourisme à 300 et « Bon à tout » dans la même passe",
		Got("prof_cook_300") and Got("prof_fish_300") and Got("prof_aid_300") and Got("prof_secondary_all"))
	-- récoltes
	NS:GatheringData()[2770] = { count = 60 }
	NS:GatheringData()[2447] = { count = 45 }
	NS:FeatTouch("prof")
	J.Run(1)
	Check("[HFJ] 105 récoltes : « Panier plein »", Got("prof_gather_100") and not Got("prof_gather_1000"))
	-- réputations (GetFactionInfo) : 10 à Honoré ou mieux dont 5 exaltées, une catégorie sans réputation
	local FACTIONS = { { "Alliance", 0, true }, { "Hurlevent", 8 }, { "Forgefer", 8 }, { "Darnassus", 8 }, { "Gnomeregan", 8 },
		{ "Argent", 8 }, { "Cénarien", 7 }, { "Bois-brisé", 6 }, { "Thorium", 6 }, { "Zandalar", 6 }, { "Hydraxiens", 7 },
		{ "Gelkis", 4 } }
	_G.GetNumFactions = function() return #FACTIONS end
	_G.GetFactionInfo = function(index)
		local f = FACTIONS[index]
		return f[1], "", f[2], 0, 0, 0, false, false, f[3] == true, false, false, false, false, index
	end
	Mock:Fire("UPDATE_FACTION")
	J.Run(1)
	Check("[HFJ] réputations lues : « Bonne réputation », « Ami pour la vie », « Le bienvenu »",
		Got("rep_honored_10") and Got("rep_exalted_1") and Got("rep_exalted_5"))
	-- boss du monde, capture en instance
	NS:BestiaryOnKill("Creature-0-1-2-3-4-6109-00000A", { npcID = 6109, zoneID = 1416 }, "log")
	J.Run(1)
	Check("[HFJ] boss du monde abattu (bestiaire) : « Plus gros que moi »", Got("dng_world_boss"))
	J.instance = "party"
	NS:CaptureResolve({ success = true, target = { npcID = 7102, name = "Gnoll", class = "normal", zoneID = 1 } })
	J.Run(1)
	Check("[HFJ] capture réussie en instance : « Souvenir de donjon »", Got("dng_capture_inside"))
	J.instance = "raid"
	NS:FeatJeuZone()
	J.Run(1)
	Check("[HFJ] entrée dans un raid (GetInstanceInfo) : « Quarante en file »", Got("dng_raid_enter"))
	J.instance = nil
	NS:FeatJeuZone()
	J.Run(5)
end

-- 4. Boss en instance : UNIT_DIED / PARTY_KILL (moteur 12.0) et journal de combat ---------------------------
do
	Say("-- qc27 hauts faits du jeu : boss en instance")
	J.Reset(40)
	_G.C_CombatLog = { IsCombatLogRestricted = function() return true end }
	local function Guid(npcID) return "Creature-0-4170-36-1234-" .. npcID .. "-0000ABCDEF" end
	Mock:Fire("UNIT_DIED", Guid(639))
	Check("[HFJ] hors instance : mort de VanCleef ignorée", NS:FeatStore("char").ctr.boss_dm == nil)
	J.instance = "party"
	NS:FeatJeuZone()
	Mock:Fire("PARTY_KILL", "Player-1-0001", Guid(639))
	Mock:Fire("UNIT_DIED", Guid(639))
	Check("[HFJ] en instance : VanCleef compté une fois (PARTY_KILL puis UNIT_DIED)", NS:FeatStore("char").ctr.boss_dm == 1)
	for _, npcID in ipairs({ 11519, 3654, 4275, 1716, 4829 }) do Mock:Fire("UNIT_DIED", Guid(npcID)) end
	Mock:Fire("UNIT_DIED", Guid(99999))
	J.Run(1)
	Check("[HFJ] six boss sur huit : palier 1 pas encore (Thanes et Lordaeron sans npcID)", not Got("dng_tier1")
		and Cur("dng_tier1") == 6, Cur("dng_tier1"))
	Mock:Fire("ENCOUNTER_END", 3496, "Durgen Dirgehammer", 1, 5, 0)
	Check("[HFJ] rencontre ratée : rien", NS:FeatStore("char").ctr.boss_thanes == nil)
	Mock:Fire("ENCOUNTER_END", 3496, "Durgen Dirgehammer", 1, 5, 1)
	Mock:Fire("ENCOUNTER_END", 3354, "Rath'mael", 1, 5, 1)
	J.Run(1)
	Check("[HFJ] rencontres réussies (ENCOUNTER_END) : « Premières profondeurs », avec ses lassos", Got("dng_tier1")
		and NS:CaptureAidCount("lasso") >= 2)
	-- raid : Ragnaros
	J.instance = "raid"
	NS:FeatJeuZone()
	Mock:Fire("UNIT_DIED", Guid(11502))
	J.Run(1)
	Check("[HFJ] Ragnaros vaincu en raid : « Éteindre le Seigneur du feu »", Got("dng_raid_mc"))
	-- sortie : plus écouté
	J.instance = nil
	NS:FeatJeuZone()
	Mock:Fire("UNIT_DIED", Guid(11583))
	Check("[HFJ] sortie d'instance : Nefarian dehors ignoré", NS:FeatStore("char").ctr.boss_bwl == nil)
	-- journal de combat ouvert (client sans restriction)
	_G.C_CombatLog = nil
	_G.CombatLogGetCurrentEventInfo = function() return 0, "UNIT_DIED", false, "", "", 0, 0, Guid(11583) end
	J.instance = "raid"
	NS:FeatJeuZone()
	Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
	J.Run(1)
	Check("[HFJ] journal de combat ouvert : Nefarian par UNIT_DIED du journal", Got("dng_raid_bwl"))
	_G.CombatLogGetCurrentEventInfo = J.saved.CombatLogGetCurrentEventInfo
	J.instance = nil
	NS:FeatJeuZone()
	-- entrée seule : donjons sans boss connu, et Prison d'Alcaz sans statistique lisible
	local stamps = NS:JournalData().stamps
	stamps["dungeon:alcaz"] = { kind = "dungeon", at = 5000 }
	Check("[HFJ] Blazeroar : statistiques illisibles, repli sur l'entrée (relevé)", NS.FEAT_SOURCES.boss_alcaz.get(NS) == 1)
	J.stats[107], J.stats[63575] = "780", "0"
	NS:FeatStatReset()
	Check("[HFJ] … statistique lisible à 0 : pas encore vaincu", NS.FEAT_SOURCES.boss_alcaz.get(NS) == 0)
	J.stats[63575] = "1"
	NS:FeatStatReset()
	for _, key in ipairs({ "ulda", "zf", "mara", "st" }) do NS:FeatCount("boss_" .. key, 1) end
	stamps["dungeon:kroldok"] = { kind = "dungeon", at = 5001 }
	NS:FeatTouch("boss")
	J.Run(1)
	Check("[HFJ] palier 3 : quatre boss, Blazeroar par sa statistique, Krol'dok par l'entrée", Got("dng_tier3"))
	-- métas : paliers, héros
	for _, id in ipairs({ "dng_tier2", "dng_tier4" }) do NS:FeatAward(id, { silent = true }) end
	NS:FeatEvaluate({ feat = true })
	Check("[HFJ] les 4 paliers : « Terreur des cachots » (compte)", Got("meta_dungeons") and NS:FeatStore("account").got.meta_dungeons ~= nil)
	Check("[HFJ] héros d'Azeroth : pas avant le niveau 60", not Got("meta_hero"))
	J.level = 60
	for _, id in ipairs({ "prof_first", "prof_150", "prof_225", "quest_10", "quest_100", "rep_exalted_1" }) do
		NS:FeatAward(id, { silent = true })
	end
	NS:FeatEvaluate({ level = true })
	Check("[HFJ] niveau 60, 5 donjons, 3 métiers, 3 quêtes : « Héros d'Azeroth » (titre 37)", Got("meta_hero")
		and Cur("meta_hero") == 4)
	J.Run(5)
end

-- 5. Lignes « à vérifier » : grisées, jamais attribuées ---------------------------------------------------
do
	Say("-- qc27 hauts faits du jeu : à vérifier")
	J.Reset(60)
	J.stats = { [107] = "780", [333] = "999g", [64222] = "99", [588] = "5000", [840] = "12", [319] = "40", [594] = "3",
		[108] = "500", [112] = "2", [114] = "2", [115] = "2", [1149] = "4", [932] = "300", [63580] = "1", [63581] = "1",
		[1518] = "900", [346] = "900", [347] = "900", [345] = "500", [341] = "3", [353] = "80" }
	NS:FeatFlag("mountEpic")
	NS:FeatEvaluate(nil)
	NS:FeatLogin()
	local wrong, grey = {}, {}
	for _, def in ipairs(NS:FeatDefs()) do
		if def.pending then
			if Got(def) then wrong[#wrong + 1] = def.id end
			if State(def.id) ~= "pending" then grey[#grey + 1] = def.id end
		end
	end
	Check("[HFJ] statistiques au plafond : aucune ligne « à vérifier » attribuée", #wrong == 0, table.concat(wrong, ", "))
	Check("[HFJ] … toutes grisées (état pending)", #grey == 0, table.concat(grey, ", "))
end

-- 6. Rattrapage à la connexion : chiffres de toute la vie, en silence --------------------------------------
do
	Say("-- qc27 hauts faits du jeu : rattrapage")
	J.Reset(60)
	NS.featLoginDone = nil
	J.stats = { [107] = "12 000", [60] = "150", [98] = "1 200", [334] = "1500g 0s 0c", [1098] = "2", [349] = "40",
		[339] = "2", [529] = "12", [377] = "6", [1524] = "300" }
	J.earned = {}
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	J.Run(4)
	local want = { "char_kills_10000", "char_deaths_100", "quest_1000", "char_gold_1000", "dng_raid_ony", "char_flight_25",
		"char_mount", "rep_honored_10", "rep_exalted_5", "prof_cook_300", "char_level_60" }
	local miss = {}
	for _, id in ipairs(want) do if not Got(id) then miss[#miss + 1] = id end end
	Check("[HFJ] connexion : lignes de statistiques attribuées d'après toute la vie du personnage", #miss == 0,
		table.concat(miss, ", "))
	local loud = {}
	for _, info in ipairs(J.earned) do if not info.retro or info.announce then loud[#loud + 1] = info.id end end
	Check("[HFJ] … en silence (rattrapées, pas d'annonce de guilde), r = true", #loud == 0 and #J.earned >= #want
		and NS:FeatStore("char").got.quest_1000.r == true, table.concat(loud, ", "))
	local lines = 0
	for line in (Mock:Output() .. "\n"):gmatch("([^\n]*)\n") do if line:find("Hauts faits :", 1, true) then lines = lines + 1 end end
	J.Run(2)
	Check("[HFJ] … une seule ligne de chat et un seul bandeau groupé", lines == 1 and NS.journalToast
		and NS.journalToast:IsShown() and NS.journalToast.text:GetText():find("hauts faits", 1, true) ~= nil and #NS.journalToasts == 0,
		Mock:Output())
	J.Run(5)
	Check("[HFJ] … et pas d'Onyxia sans statistique : Ragnaros (sans stat) non attribué", not Got("dng_raid_mc"))
end

-- 7. Portée par personnage : un second personnage n'hérite de rien ------------------------------------------
do
	Say("-- qc27 hauts faits du jeu : portée")
	J.Reset(60)
	Mock:Fire("PLAYER_DEAD")
	NS:FeatCount("emotes", 100, "account")
	NS:FeatEvaluate(nil)
	Check("[HFJ] premier personnage : mort et émotes", Got("char_deaths_1") and Got("fun_emotes"))
	J.name, J.level = "Autre", 12
	NS:FeatCacheReset()
	Check("[HFJ] second personnage : ni sa mort ni ses compteurs, mais le haut fait de compte", not Got("char_deaths_1")
		and NS:FeatCount("deaths") == 0 and Got("fun_emotes") and not Got("char_level_60"))
	NS:FeatEvaluate(nil)
	Check("[HFJ] … rien attribué à sa place", not Got("char_deaths_1") and not Got("char_level_60") and not Got("char_gold_100"))
	J.name = nil
end

-- 8. Diagnostic : les statistiques du lot ----------------------------------------------------------------------
do
	Say("-- qc27 hauts faits du jeu : diagnostic")
	J.Reset(20)
	NS:FeatJeuInit()
	J.stats = { [107] = "780", [98] = "42", [15027] = "1" }
	local ids, set = NS:FeatStatIDs(), {}
	for _, id in ipairs(ids) do set[id] = true end
	Check("[HFJ] /qc hf diag : statistiques des critères et des sources (boss, métiers, or)", set[98] and set[60]
		and set[15027] and set[63574] and set[1098] and set[334] and set[1527] and set[1201] and set[588] and set[1149]
		and (function() for i = 2, #ids do if ids[i] <= ids[i - 1] then return false end end return true end)())
	NS:HandleCommand("hf diag")
	Check("[HFJ] … imprimées avec leur valeur", Mock:Output():find("stat 15027 : 1 (brut « 1 »)", 1, true)
		and Mock:Output():find("stat 98 : 42", 1, true), Mock:Output())
end

-- remise en état
for name, fn in pairs(J.saved) do _G[name] = fn end
NS.featsDormant = J.savedDormant
NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
NS.featLoginDone = nil
NS:FeatStatReset()
NS:FeatBossKillReset()
NS:FeatJeuMemoReset()
-- le bandeau a été bâti dans le style du moment : les modules suivants le rebâtissent
for _, field in ipairs({ "journalToast", "journalFrame" }) do
	if NS[field] then NS[field]:Hide() end
	NS[field] = nil
end
NS.uiStyleCache = {}
NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
ResetWorld()
