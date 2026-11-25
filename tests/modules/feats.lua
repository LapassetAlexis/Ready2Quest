-- QuestCompanion 2.7+ : le moteur des hauts faits et leurs critères.
-- Moteur (Feats.lua) : portée compte / personnage sur deux personnages,
-- obtention par événement (bandeau, chat, combat, sourdine), lecture
-- défensive de GetStatistic et replis, migration des tampons du carnet et
-- rattrapage silencieux à la connexion, regroupement des bandeaux, métas,
-- page du carnet (JournalFeats.lua), commandes, réglages, Guide.
-- Ménagerie (FeatsCatMenagerie.lua) : une obtention par sorte de critère,
-- crochets, récompenses déplacées (2.6 → 2.7 sans double don), union du compte.
-- Jeu (FeatsCatJeu.lua) : statistiques par sorte de ligne, replis de notre
-- suivi, boss en instance, lignes « à vérifier » jamais attribuées, chiffres
-- de toute la vie rattrapés en silence, portée par personnage, diagnostic.
-- Le catalogue lui-même : feats_catalogue.lua.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- plusieurs étapes d'un même sujet : un contrôle, les étapes ratées nommées
local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end
local function DropDefs(set)
	for index = #NS.FEAT_DEFS, 1, -1 do if set[NS.FEAT_DEFS[index].id] then table.remove(NS.FEAT_DEFS, index) end end
	NS.featIndexDirty = true
end

-- ============================================================================================
-- I. Le moteur
-- ============================================================================================
do
	local HF = { saved = {}, stats = {}, earned = {} }
	local GLOBALS = { "UnitName", "UnitLevel", "GetStatistic", "InCombatLockdown", "UnitAffectingCombat", "PlaySound",
		"issecretvalue", "date", "UnitFactionGroup" }
	for _, name in ipairs(GLOBALS) do HF.saved[name] = rawget(_G, name) end
	HF.savedDormant = NS.featsDormant

	function HF.Install()
		_G.UnitName = function(unit) if unit == "player" then return HF.name or "Testeur" end return nil end
		_G.UnitLevel = function() return HF.level or 20 end
		_G.GetStatistic = function(id)
			if HF.statsBroken then error("pas de statistiques") end
			return HF.stats[id]
		end
		_G.InCombatLockdown = function() return HF.combat == true end
		_G.UnitAffectingCombat = function() return HF.combat == true end
		_G.PlaySound = function(id) HF.sounds[#HF.sounds + 1] = id; return true end
		_G.date = function() return "07/11/2026" end
		_G.UnitFactionGroup = function() return "Alliance" end
	end
	function HF.Reset(level)
		ResetWorld()
		HF.name, HF.level, HF.combat, HF.statsBroken, HF.sounds, HF.stats = nil, level or 20, false, false, {}, {}
		HF.Install()
		NS.featsDormant = false
		NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
		NS.featLoginDone = nil
		NS:FeatStatReset()
		NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
		if NS.journalToast then NS.journalToast:Hide() end
		if NS.journalFrame then NS.journalFrame:Hide() end
		NS:DB().captureMuteUntil = nil
		NS:CompanionData().tutoDone = true
		Mock:Reset()
	end
	-- toutes les horloges du moteur et du carnet, `seconds` secondes
	-- lignes en attente, lignes comptables du catalogue (3.7.0)
	function HF.Pending()
		local n = 0
		for _, def in ipairs(NS:FeatDefs()) do if def.pending then n = n + 1 end end
		return n
	end
	function HF.Countable()
		local n = 0
		for _, def in ipairs(NS:FeatDefs()) do if NS:FeatCountable(def) then n = n + 1 end end
		return n
	end
	function HF.Run(seconds)
		for _ = 1, math.max(1, math.floor(seconds or 1)) do Mock:Advance(1) end
	end
	NS:RegisterCallback("FEAT_EARNED", function(_, info) HF.earned[#HF.earned + 1] = info end)

	-- 1. Portée : compte et personnage, sur deux personnages ------------------------------------------
	do
		Say("-- hauts faits : compte et personnage")
		HF.Reset(20)
		local db = NS:DB()
		db.chars["Autre-Royaume"] = { companion = { capture = { creatures = {
			[101] = { name = "Zhévra", normal = true }, [102] = { name = "Brillant", normal = false, shiny = true },
			[103] = "abîmée" } } } }
		db.chars["Vide-Royaume"] = 7
		-- 2.9.0 : collection au compte, recréée ici en versant les deux personnages
		db.capture, NS.captureMergedChar = nil, nil
		local mine = NS:CaptureData().creatures
		mine[101] = { name = "Zhévra", normal = true }
		mine[104] = { name = "Loup", normal = true }
		NS:CaptureData().count = 2
		NS:FeatCacheReset()
		local cur = NS:FeatProgress("men_first")
		local sp = NS.FEAT_SOURCES.species
		local account = sp.get(NS, "account")
		NS:FeatCacheReset()
		Check("[HF] espèces et brillantes de compte : union des captures de tous les personnages (sauvegardes abîmées ignorées)",
			account == 3 and sp.get(NS, "char") == 3 and cur == 1 and NS.FEAT_SOURCES.shinyCap.get(NS, "account") == 1,
			tostring(account))
		local s = Steps()
		s.ok("compte dans db.feats, personnage dans CharData().feats", NS:FeatAward("men_first", { silent = true })
			and NS:FeatAward("char_level_10", { silent = true }) and db.feats.got.men_first ~= nil
			and NS:CharData().feats.got.char_level_10 ~= nil and NS:CharData().feats.got.men_first == nil
			and db.feats.got.char_level_10 == nil)
		s.ok("points exposés", NS:AchievementPoints("account") == 5 and NS:AchievementPoints("char") == 5 and NS:FeatPoints() == 10)
		s.ok("une seconde fois : rien", NS:FeatAward("men_first") == false)
		HF.name = "Autre"
		s.ok("autre personnage : le compte reste, pas le personnage", NS:FeatGot("men_first") ~= nil
			and NS:FeatGot("char_level_10") == nil and NS:AchievementPoints("account") == 5 and NS:AchievementPoints("char") == 0)
		s.ok("ses données à lui", NS:CharData() == db.chars["Autre-Royaume"])
		HF.name = nil
		s.check("[HF] FeatAward : compte et personnage rangés à part, points exposés, une fois ; l'autre personnage voit le compte seul")
		-- titres de compte : valables partout ; cosmétique de compte : suit sur chaque personnage
		local titled = NS.FeatAdd({ "test_account_cosm", 900, "men", 10, "account", crit = { "count", "species", 1 },
			reward = { cosmetic = { "frame", "trainer" }, title = 2 } })
		NS:FeatAward(titled, { silent = true })
		HF.name = "Autre"
		NS:CompanionData().unlocked = {}
		local synced = NS:FeatSyncAccountRewards()
		Check("[HF] cosmétique d'un haut fait de compte : débloqué sur l'autre personnage, titre gagné partout",
			synced == 1 and NS:CompanionData().unlocked["frame:trainer"] == true and (function()
				for _, code in ipairs(NS:FeatTitlesEarned()) do if code == 2 then return true end end
			end)())
		HF.name = nil
		DropDefs({ test_account_cosm = true })
		db.feats = { got = { a = 5, b = true, c = "x" }, ctr = 3 }
		local store = NS:FeatStore("account")
		Check("[HF] sauvegarde abîmée réparée sans rien perdre de lisible", type(store.got.a) == "table" and store.got.a.at == 5
			and store.got.b ~= nil and store.got.c == nil and type(store.ctr) == "table")
	end

	-- 2. Obtention par événement, bandeau, chat, combat, sourdine -------------------------------------------
	do
		Say("-- hauts faits : obtention par événement")
		HF.Reset(5)
		Mock.InstallAtlas(true)
		NS:AzerothAtlasOK(true)
		HF.earned = {}
		-- taille fixe : un « géant » tiré au hasard débloquait en plus « Un géant
		-- parmi les bêtes », et son bandeau passait avant ceux qu'on attend ici
		local savedSize = NS.SpecimenRollSize
		NS.SpecimenRollSize = function() return "normal" end
		NS:CaptureResolve({ success = true, target = { npcID = 7001, name = "Raptor", class = "normal", zoneID = 1413 } })
		NS.SpecimenRollSize = savedSize
		local s = Steps()
		s.ok("sujet marqué, passe groupée plus tard", NS.featDirty.capture == true and NS.featEvalAt ~= nil
			and NS:FeatGot("men_first") == nil)
		HF.Run(1)
		s.ok("passe : obtenu, FEAT_EARNED", NS:FeatGot("men_first") ~= nil and HF.earned[1] and HF.earned[1].id == "men_first"
			and HF.earned[1].announce == false and HF.earned[1].retro == false)
		s.ok("sa récompense : un appât", NS:CaptureAidCount("appat") >= 1)
		s.check("[HF] capture réussie : « Premier filet » obtenu à la passe groupée suivante, avec sa récompense")
		-- 3.0.1 : le bandeau « Capturé ! » passe d'abord (Banners.lua) ; il se ferme
		if NS.CaptureResultHide then NS:CaptureResultHide() end
		HF.Run(2)
		-- 3.7.0 : un haut fait à 5 points n'a plus de bandeau, mais une pastille (Quiet.lua)
		local toast = NS:EnsureJournalToast()
		HF.Run(5)
		-- combat : l'obtention se fait, l'annonce attend
		NS:DB().featChat = true
		Mock:Reset()
		HF.combat = true
		NS:FeatAward("char_level_20")
		HF.Run(3)
		s = Steps()
		s.ok("en combat : obtenu, ni bandeau ni chat", NS:FeatGot("char_level_20") ~= nil and #NS.featPending == 1
			and not toast:IsShown() and not Mock:Output():find("Sur la route", 1, true))
		HF.combat = false
		Mock:Fire("PLAYER_REGEN_ENABLED")
		HF.Run(1)
		s.ok("sortie de combat : pastille et chat", not toast:IsShown() and NS.featPill and NS.featPill:IsShown()
			and NS.featPill.text:GetText() == "Haut fait : Sur la route"
			and Mock:Output():find("Haut fait obtenu : Sur la route (+5 points).", 1, true), Mock:Output())
		HF.Run(5)
		NS:DB().captureMuteUntil = (time() or 0) + 600
		NS:FeatAward("char_level_30")
		HF.Run(3)
		s.ok("sourdine : l'annonce attend", #NS.featPending == 1 and not toast:IsShown())
		NS:DB().captureMuteUntil = nil
		HF.Run(2)
		s.ok("… puis passe", #NS.featPending == 0 and toast:IsShown() and toast.text:GetText() == "À mi-chemin")
		s.check("[HF] annonce retenue en combat et pendant la sourdine de capture, faite ensuite (bandeau et chat)")
		HF.Run(5)
		HF.earned = {}
		NS:FeatAward("char_level_60")
		HF.Run(3)
		Check("[HF] titre : sous-ligne « Nouveau titre » et ses paillettes, annonce de guilde permise", HF.earned[1].announce == true
			and HF.earned[1].title == 21 and toast.stars:GetText() == "Nouveau titre : Aventurier · 15 paillettes", toast.stars:GetText())
		HF.Run(5)
		NS:DB().featToast, NS:DB().featChat = false, false
		Mock:Reset()
		NS:FeatAward("char_level_40")
		HF.Run(3)
		Check("[HF] bandeau et chat coupés : rien d'affiché", not toast:IsShown() and #NS.journalToasts == 0
			and not Mock:Output():find("En selle", 1, true))
		NS:DB().featToast = true
		HF.Reset(5)
		s = Steps()
		NS:FeatTouch("mission")
		HF.Run(1)
		s.ok("sujet sans rapport : rien d'évalué", NS:FeatGot("men_first") == nil)
		NS:JournalEarn("rare", 4242, "Rare de test")
		HF.Run(1)
		s.ok("tampon de rare : « Tête mise à prix » (personnage)", NS:FeatGot("day_rare_1") ~= nil
			and NS:CharData().feats.got.day_rare_1 ~= nil)
		HF.Run(5)
		NS.featsDormant = true
		NS:FeatTouch("capture")
		s.ok("endormi : FeatTouch ne marque rien", NS.featDirty.capture == nil)
		NS.featsDormant = false
		s.check("[HF] sujets : seuls les sujets touchés sont évalués (tampon du carnet compris), rien quand le moteur dort")
	end

	-- 3. GetStatistic : lecture défensive et repli -----------------------------------------------------------
	do
		Say("-- hauts faits : statistiques du client")
		local P = NS.FeatParseStat
		local G, S, C = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
			"|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
		Check("[HF] stat : « -- », vide et nil valent 0 ; nombres « 780 », « 1 234 », « 1,234 », espace insécable, nombre",
			P("--") == 0 and P("") == 0 and P(nil) == 0 and P("  ") == 0 and P("780") == 780 and P("1 234") == 1234
			and P("1,234") == 1234 and P("1\194\160234") == 1234 and P(56) == 56 and P(" 780 ") == 780 and P(" 6 ") == 6)
		-- formes relevées sur Forever : icônes du client, sans pièces d'or, or seul, cuivre seul
		Check("[HF] stat : or « 12g 34s 5c », « 12 po 34 pa 5 pc », icônes du client (avec ou sans pièces d'or)",
			P("12g 34s 5c") == 123405 and P("12 po 34 pa 5 pc") == 123405 and P("12" .. G .. " 34" .. S .. " 5" .. C) == 123405
			and P("|cffffffff1 234|r po") == 12340000 and P("5c") == 5 and P("1" .. G .. " 87" .. S .. " 88" .. C) == 18788
			and P("36" .. S .. " 69" .. C) == 3669 and P("12" .. G) == 120000 and P("5" .. C) == 5)
		_G.issecretvalue = function(v) return v == "SECRET" end
		Check("[HF] stat : forme illisible ou valeur secrète → nil", P("abc") == nil and P("12 lapins") == nil and P({}) == nil
			and P("SECRET") == nil and P("780") == 780)
		_G.issecretvalue = HF.saved.issecretvalue

		HF.Reset(20)
		HF.stats[107] = "1 500"
		local s = Steps()
		s.ok("sonde 107 lisible", NS:FeatStatsOK() == true and NS:FeatStat(107) == 1500)
		NS:FeatCacheReset()
		local cur, max, state = NS:FeatProgress("char_kills_1000")
		s.ok("« Mille adversaires » par la stat 107", cur == 1000 and max == 1000 and state == "open")
		HF.stats[107] = "1 600"
		local cached = NS:FeatStat(107)
		Mock.now = Mock.now + 61
		s.ok("relecture au plus une fois par minute", cached == 1500 and NS:FeatStat(107) == 1600)
		s.check("[HF] statistiques en service (sonde 107 lisible), lues au plus une fois par minute")
		-- repli : statistiques illisibles, le bestiaire prend le relais
		HF.Reset(20)
		HF.stats[107] = nil
		NS:BestiaryData()[1413] = { [7001] = { name = "Raptor", killed = 600 }, [7002] = { name = "Loup", killed = 450 }, [7003] = "abîmé" }
		s = Steps()
		s.ok("sonde illisible : hors service", NS:FeatStatsOK() == false and NS:FeatStat(107) == nil)
		NS:FeatCacheReset()
		cur, max, state = NS:FeatProgress("char_kills_1000")
		s.ok("repli : abattus du bestiaire", cur == 1000 and state == "open", cur)
		NS:FeatTouch("kill")
		HF.Run(1)
		s.ok("obtention par le repli", NS:FeatGot("char_kills_1000") ~= nil)
		HF.statsBroken = true
		NS:FeatStatReset()
		s.ok("GetStatistic en erreur : illisible sans erreur", NS:FeatStatsOK() == false)
		HF.statsBroken = false
		HF.stats[107] = "99999"
		NS:DB().featStats = false
		NS:FeatStatReset()
		s.ok("réglage coupé : rien n'est lu", NS:FeatStatsOK() == false and NS:FeatStat(107) == nil)
		NS:DB().featStats = true
		s.check("[HF] statistiques illisibles, en erreur ou coupées : hors service, le bestiaire prend le relais")
		HF.stats[353] = "80"
		NS:FeatStatReset()
		local _, _, hearth = NS:FeatProgress("char_food_500")
		NS:FeatEvaluate(nil)
		local probe = NS.FeatAdd({ "test_stat_noalt", 901, "char", 10, "char", crit = { "stat", { 9999 }, 5 }, desc = "FEATD_kills" })
		HF.stats[107] = nil
		NS:FeatStatReset()
		local _, _, noalt = NS:FeatProgress(probe)
		Check("[HF] « à vérifier » : grisé et jamais attribué ; statistique illisible sans repli : grisée", hearth == "pending"
			and NS:FeatGot("char_food_500") == nil and noalt == "pending")
		DropDefs({ test_stat_noalt = true })
		HF.stats[107] = "780"
		HF.stats[353] = "--"
		Mock:Reset()
		NS:HandleCommand("hf diag")
		local out = Mock:Output()
		local waiting = 0
		for _, def in ipairs(NS:FeatDefs()) do if def.pending then waiting = waiting + 1 end end
		Check("[HF] /qc hf diag : sonde lisible, chaque statistique avec sa valeur et sa forme brute, lignes en attente",
			out:find("lisibles (107 = 780)", 1, true) and out:find("stat 107 : 780 (brut « 780 »)", 1, true)
			and out:find("stat 353 : 0 (brut « -- »)", 1, true) and waiting >= 1
			and out:find("en attente : " .. waiting .. " ", 1, true), out)
	end

	-- 4. Migration des tampons, rattrapage à la connexion ------------------------------------------------------
	do
		Say("-- hauts faits : migration des tampons et rattrapage")
		HF.Reset(25)
		local journal = NS:JournalData()
		local stamps = journal.stamps
		for i = 1, 12 do
			stamps["zone:" .. (1000 + i)] = { id = "zone:" .. (1000 + i), kind = "zone", name = "Z" .. i, at = 100000 + i * 10, level = i }
		end
		stamps["level:10"] = { id = "level:10", kind = "level", name = "Niveau 10", at = 50000, level = 10 }
		stamps["level:20"] = { id = "level:20", kind = "level", name = "Niveau 20", at = 60000, level = 20, retro = true }
		for i, areaID in ipairs(NS.FEAT_CAPITALS) do
			stamps["capital:" .. areaID] = { id = "capital:" .. areaID, kind = "capital", name = "C" .. i, at = 200000 + i }
		end
		stamps["rare:77"] = { id = "rare:77", kind = "rare", name = "Rare", at = 300000 }
		stamps["zone:9999"] = "abîmé"
		stamps["subzone:1"] = { kind = "subzone" }   -- sans date
		local before = 0
		for _ in pairs(stamps) do before = before + 1 end
		-- un palier d'espèces déjà payé sur un autre personnage : sa date
		NS:DB().chars["Autre-Royaume"] = { companion = { capture = { creatures = {} },
			collection = { ranks = { [10] = 40000 } } } }
		for i = 1, 10 do NS:DB().chars["Autre-Royaume"].companion.capture.creatures[500 + i] = { name = "E" .. i } end
		NS:DB().journalChat = true
		HF.earned = {}
		local migrated = NS:FeatMigrate()
		local got = NS:CharData().feats.got
		local s = Steps()
		s.ok("paliers de niveau", got.char_level_10 and got.char_level_10.at == 50000 and got.char_level_10.lvl == 10
			and got.char_level_20 and got.char_level_20.at == 60000 and got.char_level_10.r == true)
		s.ok("« Bourlingueur » au 10e relevé", got.zone_visit_10 and got.zone_visit_10.at == 100100 and got.zone_visit_10.lvl == 10,
			got.zone_visit_10 and got.zone_visit_10.at)
		s.ok("« Tour des capitales » à la dernière des 6", got.zone_capitals and got.zone_capitals.at == 200006)
		s.ok("rare", got.day_rare_1 and got.day_rare_1.at == 300000)
		s.ok("palier d'espèces de compte par collection.ranks", NS:DB().feats.got.men_species_10
			and NS:DB().feats.got.men_species_10.at == 40000)
		s.check("[HF] migration des tampons : chaque haut fait daté (et au niveau) du tampon qui l'a valu")
		local after = 0
		for _ in pairs(NS:JournalData().stamps) do after = after + 1 end
		Check("[HF] migration : silencieuse (aucun bandeau, rattrapée), chat du carnet repris", #NS.featPending == 0
			and #NS.journalToasts == 0 and NS:DB().featChat == true and #migrated >= 6 and HF.earned[1].retro == true)
		Check("[HF] migration : journal.stamps intact (retour en 2.6 possible), une seule fois (marques v)",
			NS:JournalData().stamps == stamps and after == before and stamps["zone:9999"] == "abîmé"
			and NS:DB().feats.v == 1 and NS:CharData().feats.v == 1 and #NS:FeatMigrate() == 0 and got.char_level_10.at == 50000)
		NS:DB().featChat = false
		HF.Reset(25)
		NS:CharData().journal = "pas une table"
		NS:DB().chars["Casse-Royaume"] = { companion = { collection = "x", capture = 4 } }
		local ok, result = pcall(NS.FeatMigrate, NS)
		Check("[HF] migration d'une sauvegarde cassée : sans erreur", ok and type(result) == "table", tostring(result))

		-- rattrapage à la connexion : silencieux, une ligne, un bandeau au plus
		HF.Reset(25)
		for i = 1, 11 do NS:JournalData().stamps["zone:" .. (2000 + i)] = { kind = "zone", at = 1000 + i } end
		NS:JournalData().stamps["level:10"] = { kind = "level", at = 900, level = 10 }
		NS:JournalData().stamps["level:20"] = { kind = "level", at = 950, level = 20 }
		HF.earned = {}
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		HF.Run(2)
		local early = NS:FeatGot("char_level_10") == nil
		HF.Run(2)
		local lines = 0
		for line in (Mock:Output() .. "\n"):gmatch("([^\n]*)\n") do if line:find("Hauts faits :", 1, true) then lines = lines + 1 end end
		Check("[HF] connexion : après 3 s, tout ce qui est acquis est obtenu (tampons migrés, niveau rattrapé)", early
			and NS:FeatGot("char_level_10") and NS:FeatGot("char_level_20") and NS:FeatGot("zone_visit_10")
			and NS:CharData().feats.got.zone_visit_10.at <= 1011)
		HF.Run(2)
		local toast = NS.journalToast
		Check("[HF] connexion : une ligne de chat, un seul bandeau groupé, obtentions « rattrapées » sans annonce de guilde",
			lines == 1 and toast and toast:IsShown() and toast.text:GetText():find("hauts faits", 1, true)
			and #NS.journalToasts == 0 and #NS.featPending == 0 and (function()
				for _, info in ipairs(HF.earned) do if not info.retro or info.announce then return false end end
				return #HF.earned >= 3
			end)(), Mock:Output())
		HF.Run(5)
		Mock:Reset()
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		HF.Run(5)
		Check("[HF] rechargement de l'interface : pas de second rattrapage", not Mock:Output():find("Hauts faits :", 1, true)
			and not toast:IsShown())
		HF.Reset(25)
		HF.combat = true
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		HF.Run(5)
		local waited = NS:FeatGot("char_level_10") == nil and not NS.featLoginDone
		HF.combat = false
		HF.Run(2)
		Check("[HF] connexion en combat : le rattrapage attend la sortie", waited and NS:FeatGot("char_level_10") ~= nil
			and NS.featLoginDone == true)
		HF.Run(5)
	end

	-- 5. Regroupement des bandeaux, métas, faits ponctuels -------------------------------------------------
	do
		Say("-- hauts faits : regroupement")
		HF.Reset(60)
		NS:FeatAward("char_level_10"); NS:FeatAward("char_level_20")
		HF.Run(2)
		-- 3.7.0 : deux petits (5 points) : deux pastilles l'une après l'autre, aucun bandeau (Quiet.lua)
		local toast = NS:EnsureJournalToast()
		local pill = NS.featPill
		local s = Steps()
		s.ok("deux : la première pastille", pill and pill:IsShown() and pill.text:GetText() == "Haut fait : Premiers pas"
			and #NS.featPills == 1 and not toast:IsShown() and #NS.journalToasts == 0)
		HF.Run(2)
		s.ok("… puis la seconde", pill:IsShown() and pill.text:GetText() == "Haut fait : Sur la route")
		HF.Run(5)
		NS:FeatAward("char_level_30"); NS:FeatAward("char_level_40"); NS:FeatAward("char_level_50")
		HF.Run(2)
		-- 3.0.1 : le bandeau groupé nomme ses hauts faits (compte dans le titre, points dans le bouclier)
		s.ok("trois d'un coup : un seul, qui les nomme", toast:IsShown() and toast.text:GetText() == "À mi-chemin · En selle · Vétéran"
			and toast.title:GetText():find("3 HAUTS FAITS OBTENUS", 1, true) == 1
			and toast.medal.badge.text:GetText() == "30" and #NS.journalToasts == 0, toast.text:GetText())
		s.ok("une ligne de chat qui les nomme", Mock:Output():find("Hauts faits obtenus : À mi-chemin, En selle, Vétéran (30 points).", 1, true) ~= nil,
			Mock:Output())
		s.check("[HF] fêtes : deux petits en deux pastilles l'une après l'autre, trois d'un coup en un seul bandeau qui les nomme")
		HF.Run(5)
		HF.Reset(60)
		local meta = NS.FeatAdd({ "test_meta_pts", 902, "meta", 10, "account", crit = { "points", 10 } })
		NS:FeatAward("char_level_10", { silent = true })
		NS:FeatAward("char_level_20", { silent = true })
		NS:FeatEvaluate({ level = true })
		local catMeta = NS.FeatAdd({ "test_meta_cat", 903, "meta", 10, "account", crit = { "meta", "char", 2 } })
		Check("[HF] métas : celui de points obtenu dans la même passe ; celui de catégorie compte ses obtenus",
			NS:FeatGot(meta) ~= nil and select(1, NS:FeatProgress(catMeta)) == 2)
		DropDefs({ test_meta_pts = true, test_meta_cat = true })
		local flag = NS.FeatAdd({ "test_flag", 904, "fun", 5, "account", crit = { "flag", "volee" } })
		local streak = NS.FeatAdd({ "test_streak", 905, "men", 5, "account", crit = { "streak", "rates", 3 } })
		NS:FeatFlag("volee", "account")
		NS:FeatCount("rates", 2, "account")
		NS:FeatEvaluate({ flag = true })
		local mid = NS:FeatGot(flag) ~= nil and NS:FeatGot(streak) == nil and select(1, NS:FeatProgress(streak)) == 2
		NS:FeatCount("rates", 1, "account")
		NS:FeatEvaluate({ flag = true })
		Check("[HF] fait ponctuel obtenu au drapeau, compteur obtenu à son seuil", mid and NS:FeatGot(streak) ~= nil)
		DropDefs({ test_flag = true, test_streak = true })
		HF.Run(5)
	end

	-- 6. Page du carnet, commandes, réglages, Guide ------------------------------------------------------------
	do
		Say("-- hauts faits : page du carnet")
		HF.Reset(25)
		Mock.InstallAtlas(nil)
		NS:AzerothAtlasOK(true)
		NS:DB().featsFilter = "all"
		NS:FeatAward("men_first", { silent = true, at = 1700000000 })
		NS:FeatAward("char_level_10", { silent = true })
		NS:FeatAward("char_level_20", { silent = true })
		NS:HandleCommand("hf")
		local f = NS.journalFrame
		local pane = f and f.feats
		-- 3.7.0 : page refaite (tests/modules/journal_feats.lua pour le détail)
		Check("[HF] /qc hf : le carnet ouvert sur « Hauts faits » (juste après Créatures), points sur la plaque, Aperçu, compte des comptables",
			f and f:IsShown() and f.kind == "feats" and pane and pane:IsShown() and f.header.title.text == NS.L.JRN_SEC_feats
			and f.sections.feats and f.sections.menagerie
			and select(5, f.sections.feats:GetPoint(1)) < select(5, f.sections.menagerie:GetPoint(1))
			and ((f.featPlate and f.featPlate.text.text) or f.subtitle.text):find("15 points", 1, true)
			and f.featsTab == "overview" and pane.views.overview:IsShown()
			and pane.gotText.text == "3 sur " .. select(2, NS:FeatCategoryStats("all")) .. " obtenus"
			and select(2, NS:FeatCategoryStats("all")) == HF.Countable(), pane and pane.gotText.text)
		local s = Steps()
		NS:OpenJournalFeats("char")
		local list = pane.list
		s.ok("catégorie Personnage : onglet Aventure, sa liste", f.featsTab == "aventure" and list:IsShown() and list.cat == "char"
			and #list.items > 0)
		s.ok("une ligne en attente n'est pas listée", (function()
			for _, item in ipairs(list.items) do if (item.def or {}).pending then return false end end
			return true
		end)())
		local levels
		for _, row in ipairs(list.rows) do if row:IsShown() and row.item and row.item.key == "level" then levels = row end end
		s.ok("série des niveaux : une ligne, deux paliers obtenus, palier 3 sur 6", levels and levels.item.done == 2
			and levels.tags[1].label.text == "SÉRIE · PALIER 3 SUR 6", levels and levels.tags[1].label.text)
		list.filterChips.got:Click()
		s.ok("Obtenus (gardé)", NS:DB().featsFilter == "got" and #list.items == 0, #list.items)
		list.filterChips.all:Click()
		NS:ScrollJournal(-1)
		s.ok("molette : une ligne", f.featsOffset == 1 and list.position.text:find("^2 à ") ~= nil, list.position.text)
		NS:JournalFeatsTip(list.rows[1])
		s.check("[HF] listes : catégorie et sa famille, pas de ligne en attente, une ligne par série, filtre gardé, molette, infobulle sans erreur")
		f:Hide()
		NS.optionsFrame = nil
		local keys = {}
		for _, page in ipairs(NS.OPTION_PAGES) do
			if page.id == "journal" then for _, row in ipairs(page.rows) do if row.key then keys[row.key] = true end end end
		end
		local guide, titles = false, false
		for _, block in ipairs(NS:JournalGuideBlocks("settings")) do
			if block.text and block.text:find("/qc hf", 1, true) then guide = true end
		end
		for _, block in ipairs(NS:JournalGuideBlocks("titles")) do
			-- 3.6.0 : le compte suit le registre (52 avec les rangs, l'étude, le lien et le mécénat)
			local n = 0
			for _ in pairs(NS.FEAT_TITLES) do n = n + 1 end
			if block.text and block.text:find("/qc titre", 1, true) and block.text:find(n .. " titres", 1, true) then titles = true end
		end
		Check("[HF] réglages (bandeau, chat, fanfare, statistiques ; bandeau oui, chat non par défaut), Guide (/qc hf, "
			.. "n titres et /qc titre), aide de /qc", keys.featToast and keys.featChat and keys.featSound and keys.featStats
			and NS.DEFAULTS.featToast == true and NS.DEFAULTS.featChat == false and guide and titles and (function()
				for _, section in ipairs(NS.HELP) do
					for _, key in ipairs(section[2] or {}) do if key == "HELP_FEATS" then return true end end
				end
			end)())
	end

	-- rangement
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = nil
	NS:ApplyUIStyle()
	for _, field in ipairs({ "journalToast", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	for name, fn in pairs(HF.saved) do _G[name] = fn end
	NS.featsDormant = HF.savedDormant
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS:FeatStatReset()
	HF.earned = {}
	ResetWorld()
end

-- ============================================================================================
-- II. Les critères de la ménagerie (lot B)
-- ============================================================================================
do
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
	NS:RegisterCallback("FEAT_EARNED", function(_, info) HM.earned[#HM.earned + 1] = info end)

	-- 1. Une obtention par sorte de critère ------------------------------------------------------------------
	do
		Say("-- hauts faits, ménagerie : critères")
		HM.Reset()
		local c = Creatures()
		-- étoiles : 25 espèces à 3 étoiles ; types : 40 bêtes
		for i = 1, 40 do c[5000 + i] = { name = "Loup " .. i, normal = true, class = "normal", type = "Bête", stars = (i <= 25) and 3 or 1 } end
		NS:CaptureData().count, NS:CaptureData().serial = 40, 1
		local appat = Aid("appat")
		Eval()
		local s = Steps()
		s.ok("étoiles 1 et 25, deux appâts", Got("men_stars3_1") and Got("men_stars3_25") and not Got("men_stars3_100")
			and Aid("appat") >= appat + 2)
		s.ok("bêtes au palier 3, pas les huit types", Got("men_type_beast") and not Got("men_type_humanoid") and not Got("men_types_t1"))
		local n = 6000
		for _, key in ipairs(NS.CREATURE_TYPES) do
			for _ = 1, NS:MenagerieTypeTiers(key)[1] do
				n = n + 1
				c[n] = { name = "Bête " .. n, normal = true, type = NS:CreatureTypeLabel(key) }
			end
		end
		NS:CaptureData().serial = 2
		Eval()
		s.ok("palier 1 dans les huit", Got("men_types_t1"))
		s.check("[HF-B] étoiles et types : paliers obtenus avec leurs aides, « Touche-à-tout » aux huit types")
		s = Steps()
		c[7001] = { name = "Gros", normal = true, class = "elite" }
		c[7002] = { name = "Rare", normal = true, class = "rareelite" }
		c[7003] = { name = "Colosse", normal = true, class = "worldboss" }
		NS:CaptureData().serial = 3
		Eval()
		s.ok("élite, rare, boss du monde", Got("men_elite_1") and Got("men_rare_1") and Got("men_boss_1") and not Got("men_rare_10"))
		c[NS.FEAT_HOGGER] = { name = "Lardeur", normal = true, class = "elite" }
		for i = 1, 5 do c[7100 + i] = { name = "Murloc côtier " .. i, normal = true } end
		c[7200] = { name = "Lapin", normal = true, class = "trivial" }
		NS:CaptureData().serial = 4
		Eval()
		s.ok("Lardeur, 5 murlocs, bestiole", Got("fun_hogger_capture") and Got("fun_murlocs") and Got("fun_critter"))
		s.check("[HF-B] rangs (élite, rare, boss du monde) et Insolite (Lardeur, murlocs, bestiole)")
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
		s = Steps()
		local seals = NS:MenagerieCollectionData().seals
		local ek = NS.FeatContinentZones(NS, "ek", true)
		for i = 1, 5 do seals[ek[i]] = 1 end
		Eval()
		s.ok("5 zones, pas tout l'Est", Got("zone_seal_5") and not Got("zone_seal_ek"))
		local cur, max = NS:FeatProgress("zone_seal_ek")
		s.ok("barre x/y sur les zones à sceau de l'Est", cur == 5 and max == #ek and max >= 15, cur .. "/" .. max)
		for _, z in ipairs(ek) do seals[z] = 1 end
		for zoneID, biome in pairs(NS.MENAGERIE_ZONE_BIOME) do
			if NS:MenagerieBiomeSeals(biome) == 0 then seals[zoneID] = 1 end
		end
		Eval()
		s.ok("tout l'Est, dix biomes, 15 zones", Got("zone_seal_ek") and Got("zone_all_biomes") and Got("zone_seal_15")
			and not Got("zone_seal_ka"))
		s.check("[HF-B] sceaux : paliers, « Sceaux de l'Est » avec sa barre, dix biomes")
		s = Steps()
		local marks = NS:CompanionData()
		marks.milestones = {}
		for _, z in ipairs(NS.FeatContinentZones(NS, "ek")) do marks.milestones[z] = 100 end
		marks.milestones[1411] = 75
		Eval()
		s.ok("zones à 100 %", Got("zone_100_1") and Got("zone_100_10") and Got("zone_ek_100") and Got("zone_milestones_25")
			and not Got("zone_ka_100"))
		local chests = NS:ChestData()
		chests[1429] = { opened = true, golden = true }
		for i = 1, 10 do chests[2000 + i] = { opened = true } end
		Eval()
		s.ok("coffres", Got("zone_golden") and Got("zone_chests_10"))
		s.check("[HF-B] zones à 100 % (une, dix, l'Est, 25 paliers ; pas Kalimdor) et coffres (zone dorée, 10 ouverts)")
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
		Check("[HF-B] au jour le jour : 100 missions, jours parfaits, auberge, 100 km, un mois ensemble", #why == 0
			and not Got("day_travel_1000") and not Got("day_days_365"), table.concat(why, " "))
		for _, id in ipairs({ "zone_visit_10", "zone_visit_25", "zone_villages_10", "zone_villages_25" }) do NS:FeatAward(id, { silent = true }) end
		Eval()
		local mcur, mmax = NS:FeatProgress("meta_trainer")
		Check("[HF-B] grands hauts faits : « Sceaux et chemins » (15 de Zones) ; « Dresseur de légende » en liste cochée",
			Got("meta_zones") and mmax == 4 and mcur >= 1 and not Got("meta_trainer"), mcur .. "/" .. mmax)
	end

	-- 2. Crochets : volée, série d'échecs, écart de niveau, groupe, nuit, guilde, fiches, continents -------------
	do
		Say("-- hauts faits, ménagerie : crochets")
		HM.Reset()
		local function Resolve(success, target)
			target = target or {}
			target.npcID, target.name, target.class = target.npcID or 9001, target.name or "Raptor", target.class or "normal"
			return NS:CaptureResolve({ success = success, target = target })
		end
		local s = Steps()
		for _ = 1, 9 do Resolve(false) end
		s.ok("9 échecs comptés", NS:FeatCount("capFail", nil, "account") == 9)
		Resolve(true, { npcID = 9002 })
		s.ok("une réussite remet à zéro", NS:FeatCount("capFail", nil, "account") == 0)
		for _ = 1, 10 do Resolve(false) end
		HM.level, HM.group, HM.hour = 20, true, "03"
		Resolve(true, { npcID = 9003, level = 26 })
		Eval()
		s.ok("10 échecs : « Il s'est encore échappé »", Got("men_bad_luck"))
		s.check("[HF-B] série d'échecs de capture : compteur de compte remis à zéro par une réussite, haut fait à 10")
		local results = {}
		for i = 1, 5 do results[i] = { success = true, target = { npcID = 9100 + i, name = "B" .. i } } end
		NS:CaptureBatchFlush({ messages = {}, results = results, tried = 5 })
		Eval()
		Check("[HF-B] faits ponctuels : 6 niveaux au-dessus, en groupe, à 3 h ; volée de 5 prises (« Coup de filet »)",
			Got("men_level_gap") and Got("soc_group_capture") and Got("fun_night_owl") and Got("men_batch_5"))
		for i = 1, 25 do NS:GuildFeatsEnqueue({ key = "m" .. i, score = 1 }) end
		-- 3.7.0 : 50 fiches gardées au plus (10 avant)
		for i = 1, 51 do NS:TrainerOpen("Ami" .. i .. "-Royaume") end
		NS:TrainerOpen(nil)
		Eval()
		Check("[HF-B] guilde : 25 exploits vus ; 50 fiches différentes au plus (51 ouvertes, la mienne ignorée)",
			Got("soc_guild_cheer") and Got("soc_card_1") and Got("soc_card_10") and NS:FeatCount("cards", nil, "account") == 50
			and NS.FEAT_CARDS_MAX == 50)
		if NS.trainerFrame then NS.trainerFrame:Hide() end
		s = Steps()
		NS:FeatNoteContinent(1429)
		s.ok("l'Est seul ne suffit pas", NS:FeatStore("char").flag.twoCont == nil)
		NS:FeatNoteContinent(1411)
		Eval()
		s.ok("Kalimdor le même jour", Got("zone_two_continents"))
		NS:MissionGrant("allWeekly")
		NS:MenagerieCollectionData().seals[1429] = 1
		NS:ShinyKill("guid-1", { zoneID = 1429, npcID = 9200, name = "Brille" })
		Eval()
		s.ok("semaine bouclée, brillante en zone scellée", Got("day_weekly_all") and Got("shiny_sealed"))
		local store = NS:FeatStore("account")
		store.ctypes = { beast = true, humanoid = true, undead = true, elemental = true, dragonkin = true, demon = true, giant = true }
		Eval()
		s.ok("7 types emmenés : pas encore", not Got("men_companion_types"))
		store.ctypes.mechanical = true
		Eval()
		s.ok("le huitième", Got("men_companion_types"))
		s.check("[HF-B] deux continents le même jour, semaine bouclée, brillante en zone scellée, huit types emmenés")
		HM.Reset()
		local journal = NS:CharData().journal or {}
		NS:CharData().journal = journal
		journal.stamps = journal.stamps or {}
		journal.stamps["zone:1429"] = { kind = "zone", at = 86400 * 100 + 10 }
		journal.stamps["zone:1411"] = { kind = "zone", at = 86400 * 100 + 5000 }
		local fromJournal = NS.FEAT_SOURCES.twoContinents.get(NS) == 1
		NS.featsDormant = true
		Resolve(false)
		Check("[HF-B] deux continents acquis d'après les relevés du carnet ; moteur endormi : les crochets ne comptent rien",
			fromJournal and NS:FeatCount("capFail", nil, "account") == 0)
		NS.featsDormant = false
	end

	-- 3. Récompenses déplacées : un seul don, rien de perdu ---------------------------------------------------------
	do
		Say("-- hauts faits, ménagerie : récompenses déplacées")
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
		local announced = false
		for _, info in ipairs(HM.earned) do if info.announce then announced = true end end
		Check("[HF-B] 2.6 → 2.7 : aucune aide redonnée, cosmétiques gardés, « Œil de pie » sans rien doubler, aucune annonce",
			Aid("lasso") == lasso and Aid("appat") <= appat + 1 and NS:CompanionData().unlocked["frame:trainer"]
			and Got("shiny_found_5") and NS:CompanionData().unlocked["frame:sparkle"] == true and not announced
			and #NS.featPending <= 1, Aid("appat") .. "/" .. appat)
		-- palier franchi en 2.7 : l'ancien système note le palier sans rien donner, le haut fait paie une fois
		for i = 31, 50 do c[8000 + i] = { name = "E" .. i, normal = true } end
		NS:CaptureData().count = 50
		local sifflet = Aid("sifflet")
		Mock:Reset()
		local gained = NS:MenagerieRankCheck()
		local s = Steps()
		s.ok("noté, marqué payé par le haut fait, rien donné", #gained == 1 and coll.ranks[50] ~= nil and coll.featRanks[50] == true
			and Aid("sifflet") == sifflet and not NS:CompanionData().unlocked["bg:menagerie"]
			and not Mock:Output():find("espèces capturées : te voilà", 1, true))
		Eval()
		s.ok("le haut fait paie", Got("men_species_50") and Aid("sifflet") == sifflet + 1
			and NS:CompanionData().unlocked["bg:menagerie"] == true)
		NS:FeatCacheReset()
		Eval()
		NS:MenagerieRankCheck()
		s.ok("seconde passe : rien de plus", Aid("sifflet") == sifflet + 1)
		s.check("[HF-B] palier 50 franchi en 2.7 : noté par l'ancien système, payé une seule fois par « Enclos animés »")
		NS:ShinyData().count = 15
		local old = #NS:ShinyCheckRewards() == 0 and not NS:CompanionData().unlocked["bg:stardust"]
		Eval()
		Check("[HF-B] 15 brillantes : l'ancien déblocage ne passe plus, « Poussière d'étoiles » débloque le fond", old
			and Got("shiny_found_15") and NS:CompanionData().unlocked["bg:stardust"])
		-- moteur endormi (ou absent) : l'ancien système paie comme avant
		HM.Reset()
		NS.featsDormant = true
		for i = 1, 10 do Creatures()[8500 + i] = { name = "D" .. i, normal = true } end
		local before = Aid("lasso")
		NS:MenagerieRankCheck({ quiet = true })
		local paidOld = Aid("lasso") == before + 1 and NS:MenagerieCollectionData().featRanks == nil
		NS.featsDormant = false
		Check("[HF-B] moteur endormi : le palier 10 paie comme avant, sans marque, et compte comme déjà payé pour le haut fait",
			paidOld and NS:FeatDef("men_species_10").paid(NS) == true)
	end

	-- 4. Union du compte : deux personnages ----------------------------------------------------------------------
	do
		Say("-- hauts faits, ménagerie : union du compte")
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
		local s = Steps()
		s.ok("rares : union (le 6 une fois)", scan.rare == 10 and Got("men_rare_10"), scan.rare)
		s.ok("brillantes : somme", scan.shinyFound == 5 and Got("shiny_found_5"))
		s.ok("étoiles et repérées de l'autre", Got("men_stars3_1") and Got("shiny_seen_1"))
		HM.name = "Autre"
		s.ok("l'autre personnage : mêmes hauts faits", Got("men_rare_10") and Got("shiny_found_5"))
		HM.name = nil
		s.check("[HF-B] union du compte : rares, brillantes, étoiles des deux personnages ; hauts faits partagés")
		db.chars["Autre-Royaume"].companion.collection = { ranks = { [10] = 30000 } }
		local paid = NS:FeatDef("men_species_10").paid(NS) == true
		db.chars["Autre-Royaume"].companion.collection.featRanks = { [10] = true }
		Check("[HF-B] palier payé en 2.6 sur un autre personnage : déjà payé pour le compte, sauf noté en 2.7 (le haut fait paie)",
			paid and NS:FeatDef("men_species_10").paid(NS) == false)
	end

	-- rangement
	for name, fn in pairs(HM.saved) do _G[name] = fn end
	NS.featsDormant = HM.savedDormant
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	if NS.journalToast then NS.journalToast:Hide() end
	if NS.trainerFrame then NS.trainerFrame:Hide() end
	NS:FeatStatReset()
	NS:FeatMenagerieScanReset()
	HM.earned = {}
	ResetWorld()
end

-- ============================================================================================
-- III. Les critères du jeu (lot C)
-- ============================================================================================
do
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
	NS:RegisterCallback("FEAT_EARNED", function(_, info) J.earned[#J.earned + 1] = info end)

	-- 1. Statistiques : lecture par sorte de ligne ------------------------------------------------------------
	do
		Say("-- hauts faits du jeu : statistiques")
		J.Reset(20)
		J.stats[107] = "780"
		J.stats[98] = "1 234"
		J.stats[60] = "--"
		J.stats[334] = "1500|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t 12|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
		J.stats[377] = "2"
		J.stats[1098] = "3"
		J.stats[1527] = "275"
		local s = Steps()
		s.ok("quêtes « 1 234 » (98)", Cur("quest_1000") == 1000 and Cur("quest_500") == 500)
		s.ok("« -- » : 0 mort, ligne ouverte", Cur("char_deaths_1") == 0 and State("char_deaths_1") == "open")
		s.ok("or en icônes (334)", Cur("char_gold_1000") == 1000 and NS.FEAT_SOURCES.goldMax.get(NS) == 1500)
		s.ok("Onyxia (1098)", NS.FEAT_SOURCES.boss_ony.get(NS) == 3)
		s.ok("métier (1527)", NS.FEAT_SOURCES.profBest.get(NS) == 275)
		s.ok("réputations sans API de factions", Cur("rep_exalted_5") == 2 and State("rep_exalted_5") == "open")
		s.check("[HFJ] statistiques par sorte de ligne : compteurs, « -- », or, victoires de boss, métier, réputations")
		s = Steps()
		J.stats[98] = "beaucoup"
		NS:FeatStatReset()
		NS:FeatCount("quests", 7)
		s.ok("forme illisible : notre compteur de quêtes", Cur("quest_10") == 7, Cur("quest_10"))
		_G.issecretvalue = function(v) return v == "SECRET" end
		J.stats[60] = "SECRET"
		NS:FeatStatReset()
		NS:FeatCount("deaths", 1)
		s.ok("valeur secrète : notre compteur de morts", Cur("char_deaths_1") == 1)
		_G.issecretvalue = J.saved.issecretvalue
		J.stats[107] = nil
		NS:FeatStatReset()
		s.ok("hors service : Onyxia à notre suivi, réputations grisées", NS.FEAT_SOURCES.boss_ony.get(NS) == 0
			and State("rep_exalted_1") == "pending" and State("char_deaths_1") == "open")
		s.check("[HFJ] statistique illisible, secrète ou hors service : nos propres compteurs, sinon la ligne grisée")
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

	-- 2. Replis : notre propre suivi ---------------------------------------------------------------------------
	do
		Say("-- hauts faits du jeu : replis")
		J.Reset(59)
		J.level = 60
		NS:FeatTouch("level")
		J.Run(1)
		local s = Steps()
		s.ok("niveau 60", Got("char_level_60"))
		Mock.world.money = 150 * 10000
		Mock:Fire("PLAYER_MONEY")
		Mock.world.money = 3
		Mock:Fire("PLAYER_MONEY")
		J.Run(1)
		s.ok("or : le plus haut solde vu", Got("char_gold_100") and not Got("char_gold_1000")
			and NS:FeatStore("char").ctr.goldMax == 1500000)
		Mock:Fire("PLAYER_DEAD")
		for _ = 1, 10 do Mock:Fire("QUEST_TURNED_IN", 100) end
		J.Run(1)
		s.ok("morts et quêtes", Got("char_deaths_1") and Got("quest_10") and not Got("quest_100")
			and NS:FeatStore("char").ctr.quests == 10)
		Mock.world.onTaxi = false
		Mock:Fire("PLAYER_ENTERING_WORLD", false, true)
		Mock:Fire("TAXIMAP_CLOSED")
		Mock.world.onTaxi = true
		J.Run(2)
		Mock:Fire("PLAYER_CONTROL_GAINED")
		s.ok("vol de griffon compté une fois", NS:FeatStore("char").ctr.taxi == 1, NS:FeatStore("char").ctr.taxi)
		-- 3.0.0 (bêta 6) : en taxi ou en véhicule, IsMounted ne compte pas
		J.mounted = true
		Mock:Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
		J.Run(2)
		local taxi = not Got("char_mount") and (NS:FeatStore("char").ctr.mounted or 0) == 0
		Mock.world.onTaxi = false
		local vehicle = rawget(_G, "UnitInVehicle")
		_G.UnitInVehicle = function(unit) return unit == "player" end
		Mock:Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
		J.Run(2)
		taxi = taxi and not Got("char_mount")
		_G.UnitInVehicle = vehicle
		s.ok("en selle en taxi ou en véhicule : rien", taxi)
		J.mounted, J.speed = true, 14
		Mock:Fire("UNIT_AURA", "player")
		J.Run(2)
		s.ok("monture vue ; rapide notée sans être attribuée", Got("char_mount") and NS:FeatStore("char").flag.mountEpic ~= nil
			and not Got("char_mount_epic"))
		J.mounted = nil
		J.Run(2)
		s.check("[HFJ] notre suivi : niveau, plus haut solde vu, morts, quêtes, vols, montures")
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
		local ninetyNine = NS:FeatCount("emotes", nil, "account") == 99 and not Got("fun_emotes")
		DoEmote("VIOLIN")
		J.Run(1)
		Check("[HFJ] émotes comptées (pas la danse) : « Expressif » à la 100e, au compte", ninetyNine and Got("fun_emotes")
			and NS:FeatStore("account").got.fun_emotes ~= nil)
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
		NS:GatheringData()[2770] = { count = 60 }
		NS:GatheringData()[2447] = { count = 45 }
		NS:FeatTouch("prof")
		J.Run(1)
		Check("[HFJ] métiers lus (GetProfessions) : paliers, deux à 300, secondaires et « Bon à tout » ; 105 récoltes",
			Got("prof_first") and Got("prof_150") and Got("prof_225") and Got("prof_300") and Got("prof_double_300")
			and Got("prof_cook_300") and Got("prof_fish_300") and Got("prof_aid_300") and Got("prof_secondary_all")
			and Got("prof_gather_100") and not Got("prof_gather_1000"))
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
		Check("[HFJ] réputations lues (GetFactionInfo) : « Bonne réputation », « Ami pour la vie », « Le bienvenu »",
			Got("rep_honored_10") and Got("rep_exalted_1") and Got("rep_exalted_5"))
		s = Steps()
		NS:BestiaryOnKill("Creature-0-1-2-3-4-6109-00000A", { npcID = 6109, zoneID = 1416 }, "log")
		J.Run(1)
		s.ok("boss du monde abattu", Got("dng_world_boss"))
		J.instance = "party"
		NS:CaptureResolve({ success = true, target = { npcID = 7102, name = "Gnoll", class = "normal", zoneID = 1 } })
		J.Run(1)
		s.ok("capture en instance", Got("dng_capture_inside"))
		J.instance = "raid"
		NS:FeatJeuZone()
		J.Run(1)
		s.ok("entrée dans un raid", Got("dng_raid_enter"))
		s.check("[HFJ] boss du monde (bestiaire), capture en instance, entrée en raid (GetInstanceInfo)")
		J.instance = nil
		NS:FeatJeuZone()
		J.Run(5)
	end

	-- 3. Boss en instance : UNIT_DIED / PARTY_KILL et journal de combat ---------------------------
	do
		Say("-- hauts faits du jeu : boss en instance")
		J.Reset(40)
		_G.C_CombatLog = { IsCombatLogRestricted = function() return true end }
		local function Guid(npcID) return "Creature-0-4170-36-1234-" .. npcID .. "-0000ABCDEF" end
		local s = Steps()
		Mock:Fire("UNIT_DIED", Guid(639))
		s.ok("hors instance : ignoré", NS:FeatStore("char").ctr.boss_dm == nil)
		J.instance = "party"
		NS:FeatJeuZone()
		Mock:Fire("PARTY_KILL", "Player-1-0001", Guid(639))
		Mock:Fire("UNIT_DIED", Guid(639))
		s.ok("en instance : compté une fois (PARTY_KILL puis UNIT_DIED)", NS:FeatStore("char").ctr.boss_dm == 1)
		for _, npcID in ipairs({ 11519, 3654, 4275, 1716, 4829 }) do Mock:Fire("UNIT_DIED", Guid(npcID)) end
		Mock:Fire("UNIT_DIED", Guid(99999))
		J.Run(1)
		s.ok("six boss sur huit", not Got("dng_tier1") and Cur("dng_tier1") == 6, Cur("dng_tier1"))
		Mock:Fire("ENCOUNTER_END", 3496, "Durgen Dirgehammer", 1, 5, 0)
		s.ok("rencontre ratée : rien", NS:FeatStore("char").ctr.boss_thanes == nil)
		Mock:Fire("ENCOUNTER_END", 3496, "Durgen Dirgehammer", 1, 5, 1)
		Mock:Fire("ENCOUNTER_END", 3354, "Rath'mael", 1, 5, 1)
		J.Run(1)
		s.ok("rencontres réussies : palier 1 et ses lassos", Got("dng_tier1") and NS:CaptureAidCount("lasso") >= 2)
		s.check("[HFJ] boss de donjon : comptés en instance seulement, une fois, par mort ou rencontre réussie (ENCOUNTER_END)")
		s = Steps()
		J.instance = "raid"
		NS:FeatJeuZone()
		Mock:Fire("UNIT_DIED", Guid(11502))
		J.Run(1)
		s.ok("Ragnaros en raid", Got("dng_raid_mc"))
		J.instance = nil
		NS:FeatJeuZone()
		Mock:Fire("UNIT_DIED", Guid(11583))
		s.ok("sortie d'instance : Nefarian ignoré", NS:FeatStore("char").ctr.boss_bwl == nil)
		_G.C_CombatLog = nil
		_G.CombatLogGetCurrentEventInfo = function() return 0, "UNIT_DIED", false, "", "", 0, 0, Guid(11583) end
		J.instance = "raid"
		NS:FeatJeuZone()
		Mock:Fire("COMBAT_LOG_EVENT_UNFILTERED")
		J.Run(1)
		s.ok("journal de combat ouvert : Nefarian", Got("dng_raid_bwl"))
		_G.CombatLogGetCurrentEventInfo = J.saved.CombatLogGetCurrentEventInfo
		J.instance = nil
		NS:FeatJeuZone()
		s.check("[HFJ] boss de raid : Ragnaros, Nefarian par le journal de combat quand il est ouvert ; plus écoutés dehors")
		s = Steps()
		local stamps = NS:JournalData().stamps
		stamps["dungeon:alcaz"] = { kind = "dungeon", at = 5000 }
		s.ok("Blazeroar : repli sur l'entrée", NS.FEAT_SOURCES.boss_alcaz.get(NS) == 1)
		J.stats[107], J.stats[63575] = "780", "0"
		NS:FeatStatReset()
		s.ok("statistique lisible à 0 : pas vaincu", NS.FEAT_SOURCES.boss_alcaz.get(NS) == 0)
		J.stats[63575] = "1"
		NS:FeatStatReset()
		for _, key in ipairs({ "ulda", "zf", "mara", "st" }) do NS:FeatCount("boss_" .. key, 1) end
		stamps["dungeon:kroldok"] = { kind = "dungeon", at = 5001 }
		NS:FeatTouch("boss")
		J.Run(1)
		s.ok("palier 3 : statistique et entrée", Got("dng_tier3"))
		s.check("[HFJ] donjons sans boss connu : la statistique si lisible, sinon l'entrée (relevé du carnet)")
		for _, id in ipairs({ "dng_tier2", "dng_tier4" }) do NS:FeatAward(id, { silent = true }) end
		NS:FeatEvaluate({ feat = true })
		local s2 = Steps()
		s2.ok("4 paliers : « Terreur des cachots » (compte)", Got("meta_dungeons") and NS:FeatStore("account").got.meta_dungeons ~= nil)
		s2.ok("héros : pas avant 60", not Got("meta_hero"))
		J.level = 60
		for _, id in ipairs({ "prof_first", "prof_150", "prof_225", "quest_10", "quest_100", "rep_exalted_1" }) do
			NS:FeatAward(id, { silent = true })
		end
		NS:FeatEvaluate({ level = true })
		s2.ok("« Héros d'Azeroth »", Got("meta_hero") and Cur("meta_hero") == 4)
		s2.check("[HFJ] métas : les 4 paliers de donjons ; « Héros d'Azeroth » au niveau 60 avec donjons, métiers, quêtes")
		J.Run(5)
	end

	-- 4. Lignes « à vérifier », rattrapage, portée, diagnostic --------------------------------------
	do
		Say("-- hauts faits du jeu : à vérifier")
		J.Reset(60)
		J.stats = { [107] = "780", [333] = "999g", [64222] = "99", [588] = "5000", [840] = "12", [319] = "40", [594] = "3",
			[108] = "500", [112] = "2", [114] = "2", [115] = "2", [1149] = "4", [932] = "300", [63580] = "1", [63581] = "1",
			[1518] = "900", [346] = "900", [347] = "900", [345] = "500", [341] = "3", [353] = "80" }
		NS:FeatFlag("mountEpic")
		NS:FeatEvaluate(nil)
		NS:FeatLogin()
		local wrong = {}
		for _, def in ipairs(NS:FeatDefs()) do
			if def.pending then
				if Got(def) then wrong[#wrong + 1] = def.id .. " attribuée" end
				if State(def.id) ~= "pending" then wrong[#wrong + 1] = def.id .. " pas grisée" end
			end
		end
		Check("[HFJ] statistiques au plafond : aucune ligne « à vérifier » attribuée, toutes grisées", #wrong == 0,
			table.concat(wrong, ", "))

		Say("-- hauts faits du jeu : rattrapage")
		J.Reset(60)
		NS.featLoginDone = nil
		J.stats = { [107] = "12 000", [60] = "150", [98] = "1 200", [334] = "1500g 0s 0c", [1098] = "2", [349] = "40",
			[339] = "2", [529] = "12", [377] = "6", [1524] = "300" }
		J.earned = {}
		-- un « Capturé ! » d'un test précédent ne tient pas la place (3.1.0 : +3 s avec le bouton Partager)
		NS.captureResultPending = nil
		NS:CaptureResultHide()
		Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
		J.Run(4)
		local want = { "char_kills_10000", "char_deaths_100", "quest_1000", "char_gold_1000", "dng_raid_ony", "char_flight_25",
			"rep_honored_10", "rep_exalted_5", "prof_cook_300", "char_level_60" }
		local miss = {}
		for _, id in ipairs(want) do if not Got(id) then miss[#miss + 1] = id end end
		-- 3.0.0 (bêta 6) : « montures possédées » (339) compte la collection du compte : plus lue
		Check("[HFJ] connexion : lignes de statistiques attribuées d'après toute la vie du personnage ; Ragnaros (sans stat) "
			.. "et « Au galop » (stat 339 du compte, jamais vu en selle) non",
			#miss == 0 and not Got("dng_raid_mc") and not Got("char_mount"), table.concat(miss, ", "))
		-- obtenu avec l'ancienne règle (stat 339) : gardé
		NS:FeatStore("char").got.char_mount = { at = 1793000000, r = true }
		NS:FeatEvaluate(nil)
		NS:FeatLogin()
		Check("[HFJ] « Au galop » obtenu avant la bêta 6 (stat 339) : jamais retiré", Got("char_mount")
			and State("char_mount") == "done")
		local loud = {}
		for _, info in ipairs(J.earned) do if not info.retro or info.announce then loud[#loud + 1] = info.id end end
		local lines = 0
		for line in (Mock:Output() .. "\n"):gmatch("([^\n]*)\n") do if line:find("Hauts faits :", 1, true) then lines = lines + 1 end end
		J.Run(2)
		Check("[HFJ] … en silence (r = true, pas d'annonce de guilde), une ligne de chat, un bandeau groupé", #loud == 0
			and #J.earned >= #want and NS:FeatStore("char").got.quest_1000.r == true and lines == 1 and NS.journalToast
			and NS.journalToast:IsShown() and NS.journalToast.text:GetText():find("hauts faits", 1, true) ~= nil
			and #NS.journalToasts == 0, table.concat(loud, ", ") .. " / " .. Mock:Output())
		J.Run(5)

		Say("-- hauts faits du jeu : portée")
		J.Reset(60)
		Mock:Fire("PLAYER_DEAD")
		NS:FeatCount("emotes", 100, "account")
		NS:FeatEvaluate(nil)
		local first = Got("char_deaths_1") and Got("fun_emotes")
		J.name, J.level = "Autre", 12
		NS:FeatCacheReset()
		local inherited = not Got("char_deaths_1") and NS:FeatCount("deaths") == 0 and Got("fun_emotes") and not Got("char_level_60")
		NS:FeatEvaluate(nil)
		Check("[HFJ] second personnage : ni la mort ni les compteurs du premier, rien attribué à sa place ; le compte le suit",
			first and inherited and not Got("char_deaths_1") and not Got("char_level_60") and not Got("char_gold_100"))
		J.name = nil

		J.Reset(20)
		NS:FeatJeuInit()
		J.stats = { [107] = "780", [98] = "42", [15027] = "1" }
		NS:HandleCommand("hf diag")
		Check("[HFJ] /qc hf diag : les statistiques du lot imprimées avec leur valeur",
			Mock:Output():find("stat 15027 : 1 (brut « 1 »)", 1, true) and Mock:Output():find("stat 98 : 42", 1, true), Mock:Output())
	end

	-- rangement
	for name, fn in pairs(J.saved) do _G[name] = fn end
	NS.featsDormant = J.savedDormant
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = nil
	NS:FeatStatReset()
	NS:FeatBossKillReset()
	NS:FeatJeuMemoReset()
	for _, field in ipairs({ "journalToast", "journalFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache = {}
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	ResetWorld()
end

-- ============================================================================================
-- IV. La deuxième édition (3.7.0) : catégories et familles, lignes hors total, tours de force,
-- secrets, séries, critères sur compteurs, paillettes, taille de la fête, rangs, comparaison,
-- suivi, « à portée de main », liste cochée, coût par sujet
-- ============================================================================================
do
	local H = { saved = {}, sounds = {} }
	local GLOBALS = { "UnitName", "UnitLevel", "InCombatLockdown", "UnitAffectingCombat", "PlaySound", "GetStatistic" }
	for _, name in ipairs(GLOBALS) do H.saved[name] = rawget(_G, name) end
	H.savedDormant = NS.featsDormant
	local TALLY = { "TallyGet", "TallyBest", "TallySize", "TallyAdd" }
	H.savedTally = {}
	for _, name in ipairs(TALLY) do H.savedTally[name] = rawget(NS, name) end
	local added = {}

	function H.Reset()
		ResetWorld()
		_G.UnitName = function(unit) if unit == "player" then return H.name or "Testeur" end return nil end
		_G.UnitLevel = function() return 20 end
		_G.InCombatLockdown = function() return false end
		_G.UnitAffectingCombat = function() return false end
		_G.GetStatistic = function() return nil end
		_G.PlaySound = function(id) H.sounds[#H.sounds + 1] = id; return true end
		H.name, H.sounds = nil, {}
		NS.featsDormant = false
		NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
		NS.featLoginDone = nil
		NS:FeatStatReset()
		NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
		NS:CompanionData().tutoDone = true
		-- compteurs : absents par défaut (Tally.lua n'est pas forcément chargé)
		for _, name in ipairs(TALLY) do NS[name] = nil end
		Mock:Reset()
	end
	-- une ligne de test (retirée à la fin)
	function H.Add(row)
		local def = NS.FeatAdd(row)
		added[def.id] = true
		return def
	end
	function H.Drop()
		DropDefs(added)
		added = {}
	end
	-- un faux magasin de compteurs (API du chantier A)
	function H.FakeTally()
		local store = { account = { n = {}, m = {}, s = {} }, char = { n = {}, m = {}, s = {} } }
		local function S(scope) return store[scope == "char" and "char" or "account"] end
		NS.TallyGet = function(_, key, scope) return S(scope).n[key] or 0 end
		NS.TallyBest = function(_, key, scope) return S(scope).m[key] or 0 end
		NS.TallySize = function(_, key, scope) return S(scope).s[key] or 0 end
		NS.TallyAdd = function(self, key, delta, scope)
			local t = S(scope)
			t.n[key] = (t.n[key] or 0) + (delta or 1)
			if self.FeatTouch then self:FeatTouch("tally") end
			return t.n[key]
		end
		return store
	end

	-- 1. Catégories et familles ------------------------------------------------------------------------
	do
		Say("-- hauts faits 3.7 : catégories et familles")
		H.Reset()
		local s = Steps()
		local want = { init = "account", men = "account", spec = "account", shiny = "account", shop = "account", soc = "account",
			fun = "account", meta = "account", fos = "account", comp = "char", zone = "char", day = "char", char = "char",
			dng = "char", prof = "char", quest = "char" }
		local family = { init = "dresseur", men = "dresseur", spec = "dresseur", shiny = "dresseur", shop = "dresseur",
			soc = "dresseur", fun = "dresseur", meta = "dresseur", fos = "dresseur", comp = "voyage", zone = "voyage",
			day = "voyage", char = "aventure", dng = "aventure", prof = "aventure", quest = "aventure" }
		local fr, en = NS.FEAT_DATA_STRINGS.fr, NS.FEAT_DATA_STRINGS.en
		local count, last = 0, 0
		local order = { dresseur = 1, voyage = 2, aventure = 3 }
		for _, cat in ipairs(NS.FEAT_CATEGORIES) do
			count = count + 1
			s.ok(cat.id .. " portée", want[cat.id] == cat.scope)
			s.ok(cat.id .. " famille", family[cat.id] == cat.family)
			s.ok(cat.id .. " icône du client", type(cat.icon) == "string" and cat.icon:find("^Interface\\Icons\\") ~= nil)
			s.ok(cat.id .. " nom FR/EN", fr["FEATC_" .. cat.id] and en["FEATC_" .. cat.id])
			s.ok(cat.id .. " familles dans l'ordre", (order[cat.family] or 0) >= last)
			last = order[cat.family] or 0
		end
		for _, f in ipairs(NS.FEAT_FAMILIES) do s.ok(f .. " nom FR/EN", fr["FEATF_" .. f] and en["FEATF_" .. f]) end
		s.ok("16 catégories, 3 familles", count == 16 and #NS.FEAT_FAMILIES == 3)
		s.ok("« Entre dresseurs » (soc)", NS.L.FEATC_soc == "Entre dresseurs" and NS:FeatCategory("soc").scope == "account")
		s.ok("catégorie vide non listée", (function()
			-- (3.7.0 : chaque catégorie listée a au moins une ligne ; init et fos se remplissent avec la deuxième édition)
			local used = {}
			for _, def in ipairs(NS:FeatDefs()) do used[def.cat] = true end
			for _, id in ipairs(NS:FeatCategories()) do if not used[id] then return false end end
			for _, cat in ipairs(NS.FEAT_CATEGORIES) do
				local listed = false
				for _, id in ipairs(NS:FeatCategories()) do if id == cat.id then listed = true end end
				if used[cat.id] ~= listed and not (used[cat.id] == nil and not listed) then return false end
			end
			return true
		end)())
		s.check("[HF37] 16 catégories en trois familles (dresseur, compagnon et voyage, aventure) : portée, icône du client, noms FR/EN")
		-- ce qui est obtenu reste obtenu : une sauvegarde 3.6 avec des lignes déplacées
		NS:DB().feats = { v = 1, got = { men_stars3_1 = { at = 100 }, men_patron_10 = { at = 200 }, meta_menagerie = { at = 300 } },
			ctr = {}, flag = {} }
		NS:CharData().feats = { v = 1, got = { day_days_30 = { at = 400 } }, ctr = {}, flag = {} }
		NS:FeatEvaluate(nil)
		local meta = NS:FeatDef("meta_menagerie")
		Check("[HF37] lignes déplacées : obtenues comme avant (même id, code, points), grand haut fait de Créatures gardé, seuil inchangé",
			NS:FeatGot("men_stars3_1").at == 100 and NS:FeatDef("men_stars3_1").cat == "spec" and NS:FeatGot("men_patron_10").at == 200
			and NS:FeatDef("men_patron_10").cat == "shop" and NS:FeatGot("day_days_30").at == 400
			and NS:FeatDef("day_days_30").cat == "comp" and NS:FeatGot(meta) and meta.crit[2] == "men" and meta.crit[3] == 20
			and select(1, NS:FeatPoints(nil)) >= 5 + 10 + 50 + 10)
	end

	-- 2. Lignes hors total, tours de force, secrets ---------------------------------------------------------
	do
		Say("-- hauts faits 3.7 : lignes hors total, tours de force, secrets")
		H.Reset()
		local fos = H.Add({ "test_fos", 960, "fos", 0, "account", crit = { "flag", "testFos" } })
		local secret = H.Add({ id = "test_secret", n = 961, cat = "fun", pts = 5, scope = "account", crit = { "flag", "testSecret" },
			hidden = true })
		local plain = H.Add({ "test_plain", 962, "fun", 10, "account", crit = { "flag", "testPlain" } })
		local wrong = H.Add({ "test_zero", 963, "fun", 0, "account", crit = { "flag", "x" } })
		local s = Steps()
		s.ok("0 point : tour de force seulement", NS.FeatPointsOK(fos) and not NS.FeatPointsOK(wrong) and NS.FeatPointsOK(plain))
		s.ok("comptable : ligne ordinaire", NS:FeatCountable(plain))
		s.ok("pas comptable : en attente, tour de force, secret caché", not NS:FeatCountable("char_food_500")
			and not NS:FeatCountable(fos) and not NS:FeatCountable(secret))
		local _, total0 = NS:FeatCategoryStats("all")
		local _, funTotal0 = NS:FeatCategoryStats("fun")
		NS:FeatFlag("testFos", "account"); NS:FeatFlag("testSecret", "account")
		NS:FeatEvaluate({ flag = true })
		local got, total1, pts = NS:FeatCategoryStats("all")
		local _, funTotal1 = NS:FeatCategoryStats("fun")
		local fosGot, fosTotal = NS:FeatCategoryStats("fos")
		local points, count = NS:FeatPoints(nil)
		s.ok("secret obtenu : comptable", NS:FeatCountable(secret) and total1 == total0 + 1 and funTotal1 == funTotal0 + 1, total1 - total0)
		s.ok("tour de force obtenu : ni dans le total, ni dans les points, ni dans le nombre obtenu",
			NS:FeatGot(fos) and fosGot == 0 and fosTotal == 0 and got == 1 and pts == 5 and points == 5 and count == 1, count)
		local listed = {}
		for _, entry in ipairs(NS:FeatRows("all", "all")) do listed[entry.def.id] = true end
		s.ok("liste : en attente jamais, tour de force et secret oui", not listed.char_food_500 and listed.test_fos and listed.test_secret)
		s.check("[HF37] lignes hors total : en attente, tours de force (0 point admis pour fos seulement), secrets cachés ; "
			.. "totaux, comptes par catégorie et points sur les seules lignes comptables")
		H.Drop()

		-- secrets : nom et description cachés, indices révélés au compte
		H.Reset()
		local a = H.Add({ id = "test_hid_a", n = 964, cat = "fun", pts = 5, scope = "account", crit = { "flag", "hidA" }, hidden = true })
		local b = H.Add({ id = "test_hid_b", n = 965, cat = "fun", pts = 5, scope = "account", crit = { "flag", "hidB" }, hidden = true })
		NS.RegisterStrings({ FEAT_test_hid_a = "Secret A", FEATH_test_hid_a = "Indice A", FEATH_test_hid_b = "Indice B" },
			{ FEAT_test_hid_a = "Secret A", FEATH_test_hid_a = "Hint A", FEATH_test_hid_b = "Hint B" })
		s = Steps()
		s.ok("caché : nom d'attente, phrase d'attente", NS:FeatName(a) == "Un secret du compagnon"
			and NS:FeatDescription(a) == NS.L.FEAT_SECRET_WAIT and not NS:FeatHintKnown("test_hid_a"))
		s.ok("pas de liste cochée, pas de suivi", NS:FeatChecklist(a) == nil and NS:FeatFollow("test_hid_a") == false)
		local savedRandom = math.random
		math.random = function(n) return n end
		-- (3.7.0 : les secrets du catalogue mis de côté, indices déjà révélés : restent les deux du test)
		local hintStore = NS:FeatStore("account")
		hintStore.hints = hintStore.hints or {}
		for _, d in ipairs(NS:FeatDefs()) do if d.hidden and not d.id:find("^test_") then hintStore.hints[d.id] = 1 end end
		local hint1, id1 = NS:FeatHintNext()
		local hint2, id2 = NS:FeatHintNext()
		local none = NS:FeatHintNext()
		math.random = savedRandom
		s.ok("FeatHintNext : un secret qui reste, au hasard, puis l'autre, puis rien", id1 == "test_hid_b" and hint1 == "Indice B"
			and id2 == "test_hid_a" and hint2 == "Indice A" and none == nil, tostring(id1) .. "/" .. tostring(id2))
		s.ok("indice révélé : la description le dit", NS:FeatHintKnown("test_hid_a") and NS:FeatDescription(a) == "Indice A"
			and NS:DB().feats.hints.test_hid_a ~= nil)
		H.name = "Autre"
		s.ok("indices au compte : vus de l'autre personnage", NS:FeatHintKnown("test_hid_b"))
		H.name = nil
		NS:FeatAward(a, { silent = true })
		s.ok("obtenu : son vrai nom et sa condition", NS:FeatName(a) == "Secret A" and NS:FeatDescription(a) ~= "Indice A"
			and NS:FeatName(b) == "Un secret du compagnon")
		s.check("[HF37] secrets : « Un secret du compagnon », indice révélé au hasard (FeatHintNext, rien quand il n'en reste pas), "
			.. "gardé au compte (FeatHintKnown), vrai nom une fois obtenu")
		H.Drop()
	end

	-- 3. Séries ----------------------------------------------------------------------------------------
	do
		Say("-- hauts faits 3.7 : séries")
		H.Reset()
		local bad = {}
		for key, ids in pairs(NS.FEAT_SERIES) do
			local members = NS:FeatSeries(key) or {}
			-- 3.7.0 : une échelle déclarée peut être prolongée par une ligne nouvelle (code 244 ou plus)
			local declared = {}
			for _, id in ipairs(ids) do declared[id] = true end
			local own = 0
			for _, def in ipairs(members) do
				if declared[def.id] then own = own + 1 elseif def.n < 244 then bad[#bad + 1] = def.id .. " hors série" end
			end
			if own ~= #ids then bad[#bad + 1] = key .. " : " .. own .. "/" .. #ids end
			local first = members[1]
			for i, def in ipairs(members) do
				if def.series ~= key then bad[#bad + 1] = def.id .. " clé" end
				if def.cat ~= first.cat then bad[#bad + 1] = def.id .. " catégorie" end
				local function Src(d) return type(d.crit[2]) == "table" and table.concat(d.crit[2], ",") or tostring(d.crit[2]) end
				if def.crit[1] ~= first.crit[1] or Src(def) ~= Src(first) then bad[#bad + 1] = def.id .. " critère" end
				if i > 1 and NS.FeatThreshold(def) <= NS.FeatThreshold(members[i - 1]) then bad[#bad + 1] = def.id .. " seuil" end
			end
		end
		Check("[HF37] séries déclarées : chaque palier existe, même catégorie, même critère et même source, seuils croissants",
			#bad == 0 and NS:FeatDef("men_species_10").series == "species" and NS:FeatDef("men_species_all").series == nil,
			table.concat(bad, ", "))
		NS:FeatAward("char_level_10", { silent = true })
		NS:FeatAward("char_level_20", { silent = true })
		local list = NS:FeatSeriesList("char", "all")
		local level, plain, ids = nil, nil, {}
		for _, item in ipairs(list) do
			if item.key == "level" then level = item end
			if item.def.id == "char_mount" then plain = item end
			ids[item.def.id] = (ids[item.def.id] or 0) + 1
		end
		local s = Steps()
		s.ok("une seule ligne pour la série", level and #level.defs == 6 and level.defs[1].id == "char_level_10"
			and level.defs[6].id == "char_level_60" and ids.char_level_10 == nil)
		s.ok("palier en cours : le premier non obtenu, sa progression", level and level.index == 3 and level.def.id == "char_level_30"
			and level.done == 2 and level.cur == 20 and level.max == 30 and not level.got)
		s.ok("ligne sans série telle quelle", plain and plain.key == nil and plain.defs == nil and plain.max == 1)
		s.ok("en attente jamais listée", ids.char_food_500 == nil)
		local got = NS:FeatSeriesList("char", "got")
		s.ok("filtre Obtenus : une série seulement si tous ses paliers le sont", (function()
			for _, item in ipairs(got) do if item.key == "level" then return false end end
			return true
		end)())
		for _, id in ipairs({ "char_level_30", "char_level_40", "char_level_50", "char_level_60" }) do NS:FeatAward(id, { silent = true }) end
		local done
		for _, item in ipairs(NS:FeatSeriesList("char", "got")) do if item.key == "level" then done = item end end
		s.ok("série finie : dernier palier, obtenue", done and done.index == 6 and done.got and done.done == 6)
		s.check("[HF37] FeatSeriesList : une série = un groupe (paliers par seuil, palier en cours, cur/max), les autres lignes telles quelles, filtres")
	end

	-- 4. Critères sur compteurs ---------------------------------------------------------------------------
	do
		Say("-- hauts faits 3.7 : critères sur compteurs")
		H.Reset()
		local t1 = H.Add({ "test_tally", 966, "shop", 10, "account", crit = { "tally", "release", 3 } })
		local t2 = H.Add({ "test_tallymax", 967, "men", 10, "account", crit = { "tallymax", "captureStreak", 10 } })
		local t3 = H.Add({ "test_tallyset", 968, "comp", 10, "char", crit = { "tallyset", "treatKinds", 5, "char" } })
		NS.RegisterStrings({ FEATD_tally_release = "Relâcher %d spécimens" }, { FEATD_tally_release = "Release %d specimens" })
		local s = Steps()
		local ok, err = pcall(function()
			local _, max, state = NS:FeatProgress(t1)
			s.ok("sans Tally.lua : en attente", state == "pending" and max == 3)
			NS:FeatEvaluate(nil)
			s.ok("… et jamais attribué", NS:FeatGot(t1) == nil)
		end)
		s.ok("sans Tally.lua : aucune erreur", ok, err)
		s.ok("sujet tally, description par gabarit", t1.topicList[1] == "tally" and #t1.topicList == 1
			and NS:FeatDescription(t1) == "Relâcher 3 spécimens")
		local store = H.FakeTally()
		store.account.n.release, store.account.m.captureStreak, store.char.s.treatKinds = 5, 12, 5
		s.ok("lus : compte, maximum, ensemble du personnage", select(1, NS:FeatProgress(t1)) == 3 and select(3, NS:FeatProgress(t1)) == "open"
			and select(1, NS:FeatProgress(t2)) == 10 and select(1, NS:FeatProgress(t3)) == 5)
		NS:FeatRetroScan()
		s.ok("pas rétroactifs : le rattrapage ne les donne pas", NS:FeatGot(t1) == nil and NS:FeatGot(t2) == nil
			and NS:FeatGot(t3) == nil and NS.FeatRetro(t1) == false)
		NS:TallyAdd("release")
		Mock:Advance(1)
		s.ok("une écriture du compteur (sujet tally) : obtenus", NS:FeatGot(t1) and NS:FeatGot(t2) and NS:FeatGot(t3)
			and NS:CharData().feats.got.test_tallyset ~= nil)
		s.check("[HF37] critères tally / tallymax / tallyset : en attente sans Tally.lua, lus sinon (compte ou personnage), "
			.. "non rétroactifs, obtenus au sujet tally, description FEATD_tally_<clé>")
		H.Drop()
	end

	-- 5. Paillettes et rattrapage ---------------------------------------------------------------------------
	do
		Say("-- hauts faits 3.7 : paillettes")
		H.Reset()
		local s = Steps()
		local reasons = {}
		local base = NS.PaillettesAdd
		NS.PaillettesAdd = function(self, n, reason) reasons[#reasons + 1] = reason; return base(self, n, reason) end
		local before = NS:Paillettes()
		NS:FeatAward("char_level_10", { silent = true })      -- 5 points
		s.ok("5 points : 2 paillettes, raison feat", NS:Paillettes() - before == 2 and reasons[1] == "feat"
			and NS:FeatGot("char_level_10").g == 2)
		before = NS:Paillettes()
		NS:FeatAward("char_level_30", { silent = true }); NS:FeatAward("char_level_60", { silent = true })
		NS:FeatAward("meta_points_500", { silent = true })
		local fifty = H.Add({ "test_fifty", 969, "meta", 50, "account", crit = { "flag", "f50" } })
		NS:FeatAward(fifty, { silent = true })
		local fos = H.Add({ "test_fos2", 970, "fos", 0, "account", crit = { "flag", "f0" } })
		NS:FeatAward(fos, { silent = true })
		s.ok("10 : 5, 25 : 15, 50 : 40, tour de force : 0", NS:Paillettes() - before == 5 + 15 + 5 + 40
			and NS:FeatGot(fos).g == 0, NS:Paillettes() - before)
		s.check("[HF37] paillettes à l'obtention : 2 / 5 / 15 / 40 selon les points, 0 pour un tour de force, marque g dans got")
		NS.PaillettesAdd = base
		H.Drop()
		-- rattrapage : une sauvegarde d'avant (sans marque), deux personnages, plusieurs connexions
		H.Reset()
		NS:DB().feats = { v = 1, got = { men_first = { at = 10 }, meta_menagerie = 12345, inconnu = { at = 1 },
			men_species_10 = { at = 20, g = 5 } }, ctr = {}, flag = {} }
		NS:CharData().feats = { v = 1, got = { char_level_10 = { at = 30 }, char_level_30 = { at = 40 } }, ctr = {}, flag = {} }
		NS:DB().chars["Autre-Royaume"] = { feats = { v = 1, got = { char_level_60 = { at = 50 } }, ctr = {}, flag = {} } }
		before = NS:Paillettes()
		Mock:Reset()
		NS:FeatLogin()
		local lines = 0
		for line in (Mock:Output() .. "\n"):gmatch("([^\n]*)\n") do if line:find("paillettes", 1, true) then lines = lines + 1 end end
		local catchup = NS:Paillettes() - before
		s = Steps()
		s.ok("une seule ligne de chat, compte et personnage connecté payés une fois (ligne d'avant la marque comprise)", lines == 1
			and Mock:Output():find("+49 paillettes pour 4 haut(s) fait(s)", 1, true), Mock:Output())
		s.ok("déjà marqué : pas repayé ; inconnu : ignoré", NS:DB().feats.got.men_species_10.g == 5 and NS:DB().feats.got.inconnu.g == nil
			and NS:DB().feats.got.meta_menagerie.g == 40)
		NS.featLoginDone = nil
		before = NS:Paillettes()
		Mock:Reset()
		NS:FeatLogin()
		s.ok("deuxième connexion : rien", NS:Paillettes() == before and not Mock:Output():find("paillettes pour", 1, true))
		H.name = "Autre"
		NS.featLoginDone = nil
		NS:FeatLogin()
		s.ok("autre personnage : ses hauts faits à lui, pas le compte une seconde fois", NS:FeatGot("char_level_60").g == 15
			and NS:DB().feats.got.men_first.g == 2 and catchup >= 49)
		H.name = nil
		s.check("[HF37] rattrapage des paillettes : chaque haut fait passé payé une seule fois (compte, personnage à sa connexion, "
			.. "sauvegarde ancienne), une ligne de chat")
	end

	-- 6. Taille de la fête ----------------------------------------------------------------------------------
	do
		Say("-- hauts faits 3.7 : taille de la fête")
		H.Reset()
		local pushed = {}
		local push = NS.JournalToastPush
		NS.JournalToastPush = function(_, entry) pushed[#pushed + 1] = entry; return true end
		local fos = H.Add({ "test_fos3", 971, "fos", 0, "account", crit = { "flag", "f3" } })
		local s = Steps()
		s.ok("tailles : 5 petite, 10 moyenne, 25 / 50 / titre / tour de force grande", NS:FeatSize("char_level_10") == "small"
			and NS:FeatSize("char_level_30") == "medium" and NS:FeatSize("char_kills_10000") == "big"
			and NS:FeatSize("men_species_250") == "big" and NS:FeatSize("men_species_10") == "big" and NS:FeatSize(fos) == "big")
		local function Play(id)
			pushed, H.sounds = {}, {}
			NS:FeatAward(id)
			NS:FeatFlush(true)
			local entry = pushed[1]
			if entry and entry.onShow then entry.onShow() end
			return entry, H.sounds
		end
		local e5, s5 = Play("char_level_10")
		local e10, s10 = Play("char_level_30")
		local e25, s25 = Play("char_kills_10000")
		s.ok("petite : pas de son", e5 and e5.size == "small" and #s5 == 0)
		s.ok("moyenne : son court", e10 and e10.size == "medium" and #s10 == 1 and s10[1] == NS.FEAT_SOUND_FALLBACK)
		s.ok("grande : fanfare", e25 and e25.size == "big" and #s25 == 1 and s25[1] == NS.FEAT_SOUND)
		pushed, H.sounds = {}, {}
		NS:FeatAward("char_level_20"); NS:FeatAward("char_level_40"); NS:FeatAward("char_level_50")
		NS:FeatFlush(true)
		s.ok("trois d'un coup : un bandeau groupé, à la taille du plus gros", #pushed == 1 and pushed[1].count == 3
			and pushed[1].size == "medium")
		NS:DB().featSound = false
		H.sounds = {}
		NS:FeatPlaySize("big")
		s.ok("fanfare coupée : rien", #H.sounds == 0)
		NS:DB().featSound = true
		s.check("[HF37] taille de la fête : petite sans son, moyenne au son court, grande à la fanfare ; taille transmise au bandeau, "
			.. "regroupement à partir de 3 inchangé")
		NS.JournalToastPush = push
		H.Drop()
	end

	-- 7. Rangs, comparaison ---------------------------------------------------------------------------
	do
		Say("-- hauts faits 3.7 : rangs et comparaison")
		H.Reset()
		local s = Steps()
		s.ok("seuils", table.concat(NS.FEAT_RANKS, ",") == "100,250,500,1000,1500,2000,3000,4000")
		local i, name, nextAt, nextName = NS:FeatRank(0)
		s.ok("0 point : aucun rang, le premier en vue", i == 0 and name == nil and nextAt == 100 and nextName == "Connu au village")
		i, name, nextAt, nextName = NS:FeatRank(1200)
		s.ok("1 200 : Réputé, puis 1 500", i == 4 and name == "Réputé" and nextAt == 1500 and nextName == "De grande renommée")
		i, name, nextAt = NS:FeatRank(4000)
		s.ok("4 000 : Légende vivante, plus rien après", i == 8 and name == "Légende vivante" and nextAt == nil)
		local names = true
		for k = 1, 8 do if not (NS.FEAT_STRINGS.fr["FEAT_RANK_" .. k] and NS.FEAT_STRINGS.en["FEAT_RANK_" .. k]) then names = false end end
		NS:FeatAward("char_level_60", { silent = true })
		local cur, _, _, _, points = NS:FeatRank()
		s.ok("noms FR/EN ; sans argument : les points du compte et du personnage", names and points == 25 and cur == 0)
		s.check("[HF37] rangs de renommée : 8 seuils et leurs noms, FeatRank rend rang, nom, seuil suivant et son nom")
		s = Steps()
		local set = { [1] = true, [6] = true, [7] = true, [173] = true, [243] = true, [450] = true }
		local text = NS:FeatBits(set)
		local back = NS:FeatBitsDecode(text)
		local same = true
		for n in pairs(set) do if not back[n] then same = false end end
		for n in pairs(back) do if not set[n] then same = false end end
		s.ok("aller-retour", same, text)
		s.ok("caractères sûrs, 6 bits par caractère", text:find("^[A-Za-z0-9_%-]+$") ~= nil and #text == 75, #text)
		s.ok("rien : texte vide", NS:FeatBits({}) == "" and next(NS:FeatBitsDecode("")) == nil)
		local odd = NS:FeatBitsDecode("|C")
		s.ok("caractère inconnu ignoré (vaut zéro)", odd[8] == true and odd[1] == nil and odd[2] == nil)
		NS:FeatAward("men_first", { silent = true })
		local mine = NS:FeatBitsDecode(NS:FeatBits())
		s.ok("mes hauts faits obtenus (compte et personnage)", mine[1] and mine[91] and not mine[2])
		s.check("[HF37] comparaison : FeatBits (un bit par code, caractères sûrs) et FeatBitsDecode (l'ensemble des codes)")
	end

	-- 8. Suivre, à portée de main, liste cochée ------------------------------------------------------------
	do
		Say("-- hauts faits 3.7 : suivi, à portée de main, liste cochée")
		H.Reset()
		local follows = 0
		H.FakeTally()
		local add = NS.TallyAdd
		NS.TallyAdd = function(self, key, ...) if key == "follow" then follows = follows + 1 end return add(self, key, ...) end
		local s = Steps()
		s.ok("suivre trois", NS:FeatFollow("men_species_10", true) and NS:FeatFollow("char_level_30", true)
			and NS:FeatFollow("zone_seal_5", true))
		local ok4, why4 = NS:FeatFollow("zone_seal_15", true)
		s.ok("pas un quatrième", ok4 == false and why4 == "full" and #NS:FeatFollowed() == 3)
		s.ok("premier suivi : compteur follow, une fois", follows == 1)
		s.ok("ni en attente ni inconnu", NS:FeatFollow("char_food_500", true) == false and NS:FeatFollow("nope", true) == false)
		NS:FeatAward("char_level_30", { silent = true })
		local list = NS:FeatFollowed()
		s.ok("obtenu : sort du suivi", #list == 2 and list[1] == "men_species_10" and list[2] == "zone_seal_5")
		local okGot, whyGot = NS:FeatFollow("char_level_30", true)
		s.ok("déjà obtenu : refusé", okGot == false and whyGot == "done")
		s.ok("ne plus suivre ; bascule", NS:FeatFollow("men_species_10", false) and NS:FeatFollow("zone_seal_5") and #NS:FeatFollowed() == 0
			and NS:FeatFollow("zone_seal_5") and #NS:FeatFollowed() == 1)
		H.name = "Autre"
		s.ok("par personnage", #NS:FeatFollowed() == 0)
		H.name = nil
		s.check("[HF37] suivre : 3 au plus par personnage, ni obtenus, ni en attente, ni secrets ; premier suivi : TallyAdd(\"follow\")")
		NS.TallyAdd = add
		for _, name in ipairs(TALLY) do NS[name] = nil end

		-- à portée de main
		H.Reset()
		local near1 = H.Add({ "test_near_a", 972, "fun", 10, "account", crit = { "streak", "na", 10 } })
		local near2 = H.Add({ "test_near_b", 973, "fun", 5, "account", crit = { "streak", "nb", 10 } })
		local near3 = H.Add({ "test_near_c", 974, "fun", 5, "account", crit = { "streak", "nc", 4 } })
		local hidden = H.Add({ id = "test_near_h", n = 975, cat = "fun", pts = 5, scope = "account", crit = { "streak", "nh", 10 }, hidden = true })
		local fos = H.Add({ "test_near_f", 976, "fos", 0, "account", crit = { "streak", "nf", 10 } })
		NS:FeatCount("na", 9, "account"); NS:FeatCount("nb", 9, "account"); NS:FeatCount("nc", 3, "account")
		NS:FeatCount("nh", 9, "account"); NS:FeatCount("nf", 9, "account")
		-- (ce qui est déjà atteint, attribué à la passe suivante, n'est pas « à portée »)
		NS:FeatEvaluate(nil)
		local nearest = NS:FeatNearest(3)
		s = Steps()
		s.ok("les plus proches : rapport décroissant, à égalité le moins de points", #nearest == 3 and nearest[1].def == near2
			and nearest[2].def == near1 and nearest[3].def == near3 and nearest[1].cur == 9 and nearest[1].max == 10, (function()
				local out = {}
				for _, e in ipairs(nearest) do out[#out + 1] = e.def.id end
				return table.concat(out, ",")
			end)())
		s.ok("ni secret, ni tour de force, ni en attente", (function()
			for _, e in ipairs(NS:FeatNearest(50)) do if e.def == hidden or e.def == fos or e.def.pending then return false end end
			return true
		end)())
		s.check("[HF37] FeatNearest : comptables, non obtenus, non secrets, les plus proches du but (cur/max ; à égalité le moins de points)")
		H.Drop()

		-- liste cochée
		H.Reset()
		local stamps = NS:JournalData().stamps
		stamps["capital:" .. NS.FEAT_CAPITALS[1]] = { kind = "capital", name = "Hurlevent", at = 1 }
		NS:FeatAward("men_type_beast", { silent = true })
		local capitals = NS:FeatChecklist("zone_capitals")
		local types = NS:FeatChecklist("men_types_master")
		s = Steps()
		s.ok("liste : un élément par capitale, dans l'ordre, nom et coche", capitals and #capitals == #NS.FEAT_CAPITALS
			and capitals[1].label == "Hurlevent" and capitals[1].done == true and capitals[2].done == false
			and type(capitals[2].label) == "string" and capitals[2].label ~= "")
		s.ok("méta d'identifiants : le nom de chaque haut fait", types and #types == 8 and types[1].label == NS:FeatName("men_type_beast")
			and types[1].done and not types[2].done)
		s.ok("autres critères : rien", NS:FeatChecklist("men_species_10") == nil and NS:FeatChecklist("meta_menagerie") == nil)
		local ladder = NS:FeatChecklist("zone_seal_ek")
		s.ok("liste « toutes les zones » : un élément par zone, libellé lisible", ladder and #ladder > 0
			and not ladder[1].label:find("sealsEk", 1, true), ladder and ladder[1] and ladder[1].label)
		s.check("[HF37] FeatChecklist : critères list et meta (identifiants), { label, done } dans l'ordre ; rien pour les autres")
	end

	-- 9. Coût : une passe ne lit que les lignes abonnées aux sujets touchés ---------------------------------
	do
		Say("-- hauts faits 3.7 : coût par sujet")
		H.Reset()
		local seen = {}
		local progress = NS.FeatProgress
		NS.FeatProgress = function(self, def, ...) seen[#seen + 1] = def; return progress(self, def, ...) end
		NS:FeatEvaluate({ tally = true })
		-- (3.7.0 : le catalogue a des lignes sur compteurs : la passe « tally » ne lit qu'elles)
		local tallyOnly = 0
		for _, def in ipairs(seen) do
			local sub = false
			for _, topic in ipairs(def.topicList) do if topic == "tally" or topic == "feat" then sub = true end end
			if not sub then tallyOnly = tallyOnly + 1 end
		end
		seen = {}
		NS:FeatEvaluate({ mission = true })
		local wrong = {}
		for _, def in ipairs(seen) do
			local sub = false
			for _, topic in ipairs(def.topicList) do if topic == "mission" or topic == "feat" then sub = true end end
			if not sub then wrong[#wrong + 1] = def.id end
		end
		NS.FeatProgress = progress
		Check("[HF37] coût : une passe ne lit que les lignes abonnées au sujet (index sujet -> lignes) ; la passe « tally » ne lit que les lignes sur compteurs",
			tallyOnly == 0 and #seen > 0 and #wrong == 0, table.concat(wrong, ", "))
	end

	-- rangement
	for name, fn in pairs(H.saved) do _G[name] = fn end
	for _, name in ipairs(TALLY) do NS[name] = H.savedTally[name] end
	NS.featsDormant = H.savedDormant
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = nil
	NS:FeatStatReset()
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	H.Drop()
	ResetWorld()
end
