-- QuestCompanion 2.7.0, lot A des hauts faits : moteur (Feats.lua), données
-- (FeatsData.lua), page du carnet (JournalFeats.lua). Définitions valides,
-- portée compte / personnage sur deux personnages, obtention par événement,
-- lecture de GetStatistic et repli, rattrapage silencieux à la connexion,
-- regroupement des bandeaux, conversion des tampons, page, commandes,
-- réglages, ligne du Guide.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local HF = { saved = {}, stats = {}, earned = {} }
local GLOBALS = { "UnitName", "UnitLevel", "GetStatistic", "InCombatLockdown", "UnitAffectingCombat", "PlaySound",
	"issecretvalue", "date", "UnitFactionGroup" }
for _, name in ipairs(GLOBALS) do HF.saved[name] = rawget(_G, name) end
HF.savedDormant = NS.featsDormant

function HF.Read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end

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
function HF.Run(seconds)
	for _ = 1, math.max(1, math.floor(seconds or 1)) do Mock:Advance(1) end
end

if not HF.registered then
	NS:RegisterCallback("FEAT_EARNED", function(_, info) HF.earned[#HF.earned + 1] = info end)
	HF.registered = true
end

-- 1. Définitions --------------------------------------------------------------------------------------
do
	Say("-- qc27 hauts faits : définitions")
	local defs, ids, codes, bad = NS:FeatDefs(), {}, {}, {}
	local catScope = {}
	for _, cat in ipairs(NS.FEAT_CATEGORIES) do catScope[cat.id] = cat.scope end
	local fr, en = NS.FEAT_DATA_STRINGS.fr, NS.FEAT_DATA_STRINGS.en
	local aidIds = {}
	for _, aid in ipairs(NS.CAPTURE_AIDS or {}) do aidIds[aid.id] = true end
	for _, def in ipairs(defs) do
		local function Bad(why) bad[#bad + 1] = def.id .. " (" .. why .. ")" end
		if ids[def.id] then Bad("id en double") end
		ids[def.id] = true
		if codes[def.n] then Bad("code en double") end
		codes[def.n] = true
		if type(def.n) ~= "number" or def.n < 1 or def.n > 999 then Bad("code") end
		if not NS.FEAT_POINTS[def.pts] then Bad("points") end
		if def.scope ~= "account" and def.scope ~= "char" then Bad("portée") end
		if catScope[def.cat] == nil then Bad("catégorie") end
		if catScope[def.cat] ~= def.scope then Bad("portée ≠ règle de la catégorie") end
		if not (fr["FEAT_" .. def.id] and en["FEAT_" .. def.id]) then Bad("nom FR/EN") end
		local desc = NS:FeatDescription(def)
		if desc == "" or desc:find("^FEATD_") then Bad("description") end
		local crit = def.crit or {}
		if crit[1] == "count" and not NS.FEAT_SOURCES[crit[2]] then Bad("source") end
		if crit[1] == "stat" and crit.alt and not NS.FEAT_SOURCES[crit.alt] then Bad("repli") end
		if crit[1] == "list" and not NS.FEAT_LISTS[crit[2]] then Bad("liste") end
		if #(def.topicList or {}) == 0 then Bad("aucun sujet") end
		for id in pairs(type(def.reward) == "table" and def.reward.aids or {}) do
			if not aidIds[id] then Bad("aide " .. id) end
		end
		local title = type(def.reward) == "table" and def.reward.title
		if title and not (NS.FEAT_TITLES[title] and NS.FEAT_TITLES[title].m and NS.FEAT_TITLES[title].en) then Bad("titre") end
	end
	Check("[HF] catalogue : ids et codes uniques, points 5/10/25/50, portée et catégorie, noms FR/EN, sources",
		#bad == 0, table.concat(bad, ", "))
	Check("[HF] catalogue de départ : plus de 30 lignes, les deux portées", #defs >= 30
		and NS:FeatDef("men_first").scope == "account" and NS:FeatDef("char_level_10").scope == "char")
	-- les codes suivent le catalogue du document (rang dans §2), pour les lots suivants
	local doc = HF.Read("docs/QC-HAUTS-FAITS.md") or ""
	local catalogue = doc:sub(doc:find("## 2. Catalogue", 1, true) or 1, doc:find("### 2.12", 1, true) or #doc)
	local rank, order = 0, {}
	for line in catalogue:gmatch("[^\n]+") do
		local id = line:match("^| `([%w_]+)` |")
		if id then rank = rank + 1; order[id] = rank end
	end
	local off = {}
	for _, def in ipairs(defs) do if order[def.id] ~= def.n then off[#off + 1] = def.id end end
	Check("[HF] codes n = rang dans le catalogue du document (173 lignes)", rank == 173 and #off == 0, table.concat(off, ", "))
	local parity = {}
	for _, set in ipairs({ NS.FEAT_STRINGS, NS.FEAT_DATA_STRINGS, NS.JOURNAL_FEATS_STRINGS }) do
		for key in pairs(set.fr) do if set.en[key] == nil then parity[#parity + 1] = key end end
		for key in pairs(set.en) do if set.fr[key] == nil then parity[#parity + 1] = key end end
	end
	Check("[HF] chaînes : mêmes clés en français et en anglais", #parity == 0, table.concat(parity, ", "))
	Check("[HF] titres : rendu nu et avec le nom, genre", NS:FeatTitleText(19, nil, "m") == "Traqueur"
		and NS:FeatTitleText(19, nil, "f") == "Traqueuse" and NS:FeatTitleText(35, nil, "m") == "Seigneur de la ménagerie"
		and NS:FeatTitleText(2, "Dyokrion", "m") == "Dresseur Dyokrion" and NS:FeatTitleText(21, nil, "f") == "Aventurière",
		tostring(NS:FeatTitleText(21, nil, "f")))
	Check("[HF] .toc : données, moteur et page après les crochets existants", (function()
		local toc = HF.Read("QuestCompanion/QuestCompanion.toc") or ""
		local a, b, c, d = toc:find("AzerothStyle.lua", 1, true), toc:find("FeatsData.lua", 1, true),
			toc:find("\nFeats.lua", 1, true), toc:find("JournalFeats.lua", 1, true)
		return a and b and c and d and a < b and b < c and c < d
	end)())
end

-- 2. Portée : compte et personnage, sur deux personnages --------------------------------------------------
do
	Say("-- qc27 hauts faits : compte et personnage")
	HF.Reset(20)
	local db = NS:DB()
	db.chars["Autre-Royaume"] = { companion = { capture = { creatures = {
		[101] = { name = "Zhévra", normal = true }, [102] = { name = "Brillant", normal = false, shiny = true },
		[103] = "abîmée" } } } }
	db.chars["Vide-Royaume"] = 7
	local mine = NS:CaptureData().creatures
	mine[101] = { name = "Zhévra", normal = true }
	mine[104] = { name = "Loup", normal = true }
	NS:CaptureData().count = 2
	NS:FeatCacheReset()
	local cur = NS:FeatProgress("men_first")
	local sp = NS.FEAT_SOURCES.species
	Check("[HF] espèces de compte : union des captures de tous les personnages (101, 102, 104)",
		sp.get(NS, "account") == 3 and sp.get(NS, "char") == 2 and cur == 1, tostring(sp.get(NS, "account")))
	NS:FeatCacheReset()
	Check("[HF] brillantes de compte : union aussi", NS.FEAT_SOURCES.shinyCap.get(NS, "account") == 1)
	Check("[HF] FeatAward : compte dans db.feats, personnage dans CharData().feats",
		NS:FeatAward("men_first", { silent = true }) and NS:FeatAward("char_level_10", { silent = true })
		and db.feats.got.men_first ~= nil and NS:CharData().feats.got.char_level_10 ~= nil
		and NS:CharData().feats.got.men_first == nil and db.feats.got.char_level_10 == nil)
	Check("[HF] points : compte et personnage exposés (ns:AchievementPoints)", NS:AchievementPoints("account") == 5
		and NS:AchievementPoints("char") == 5 and NS:FeatPoints() == 10)
	Check("[HF] une seconde fois : rien", NS:FeatAward("men_first") == false)
	-- l'autre personnage se connecte
	HF.name = "Autre"
	Check("[HF] autre personnage : le haut fait de compte reste, celui du personnage non",
		NS:FeatGot("men_first") ~= nil and NS:FeatGot("char_level_10") == nil
		and NS:AchievementPoints("account") == 5 and NS:AchievementPoints("char") == 0)
	Check("[HF] … ses données de personnage à lui", NS:CharData() == db.chars["Autre-Royaume"])
	HF.name = nil
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
	for index = #NS.FEAT_DEFS, 1, -1 do if NS.FEAT_DEFS[index].id == "test_account_cosm" then table.remove(NS.FEAT_DEFS, index) end end
	NS.featIndexDirty = true
	-- sauvegarde abîmée : lue sans erreur
	db.feats = { got = { a = 5, b = true, c = "x" }, ctr = 3 }
	local store = NS:FeatStore("account")
	Check("[HF] sauvegarde abîmée réparée sans rien perdre de lisible", type(store.got.a) == "table" and store.got.a.at == 5
		and store.got.b ~= nil and store.got.c == nil and type(store.ctr) == "table")
end

-- 3. Obtention par événement, bandeau, chat, combat, sourdine ----------------------------------------------
do
	Say("-- qc27 hauts faits : obtention par événement")
	HF.Reset(5)
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	HF.earned = {}
	NS:CaptureResolve({ success = true, target = { npcID = 7001, name = "Raptor", class = "normal", zoneID = 1413 } })
	Check("[HF] capture réussie : le sujet « capture » est marqué, passe groupée plus tard",
		NS.featDirty.capture == true and NS.featEvalAt ~= nil and NS:FeatGot("men_first") == nil)
	HF.Run(1)
	Check("[HF] … passe : « Premier filet » obtenu (compte), FEAT_EARNED émis", NS:FeatGot("men_first") ~= nil
		and HF.earned[1] and HF.earned[1].id == "men_first" and HF.earned[1].announce == false and HF.earned[1].retro == false)
	Check("[HF] … sa récompense : un appât", NS:CaptureAidCount("appat") >= 1)
	HF.Run(2)
	local toast = NS.journalToast
	Check("[HF] bandeau « Haut fait obtenu » : nom, points dans le bouclier, icône de la catégorie",
		toast and toast:IsShown() and toast.text:GetText() == NS:FeatName("men_first")
		and toast.title:GetText():find("HAUT FAIT OBTENU", 1, true) == 1 and toast.featPoints and toast.featPoints:GetText() == "5"
		and toast.shieldKind == "gold" and toast.icon.texture == NS.FEAT_CATEGORIES[1].icon,
		toast and toast.title:GetText())
	Check("[HF] … fanfare jouée, pas de chat par défaut", (function()
			for _, id in ipairs(HF.sounds) do if id == NS.FEAT_SOUND then return true end end
		end)()
		and not Mock:Output():find("Haut fait obtenu", 1, true))
	HF.Run(5)
	-- combat : l'obtention se fait, l'annonce attend
	NS:DB().featChat = true
	Mock:Reset()
	HF.combat = true
	NS:FeatAward("char_level_20")
	HF.Run(3)
	Check("[HF] en combat : obtenu, mais ni bandeau ni chat", NS:FeatGot("char_level_20") ~= nil
		and #NS.featPending == 1 and not toast:IsShown() and not Mock:Output():find("Sur la route", 1, true))
	HF.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	HF.Run(1)
	Check("[HF] sortie de combat : bandeau et ligne de chat", toast:IsShown() and toast.text:GetText() == "Sur la route"
		and Mock:Output():find("Haut fait obtenu : Sur la route (+5 points).", 1, true), Mock:Output())
	HF.Run(5)
	-- sourdine de capture : l'annonce attend la fin
	NS:DB().captureMuteUntil = (time() or 0) + 600
	NS:FeatAward("char_level_30")
	HF.Run(3)
	Check("[HF] sourdine : l'annonce attend", #NS.featPending == 1 and not toast:IsShown())
	NS:DB().captureMuteUntil = nil
	HF.Run(2)
	Check("[HF] … puis passe", #NS.featPending == 0 and toast:IsShown() and toast.text:GetText() == "À mi-chemin")
	HF.Run(5)
	-- titre et 25 points : annonce de guilde possible, nouveau titre en sous-ligne
	HF.earned = {}
	NS:FeatAward("char_level_60")
	HF.Run(3)
	Check("[HF] titre : sous-ligne « Nouveau titre », annonce de guilde permise", HF.earned[1].announce == true
		and HF.earned[1].title == 21 and toast.stars:GetText() == "Nouveau titre : Aventurier", toast.stars:GetText())
	HF.Run(5)
	-- réglages coupés
	NS:DB().featToast, NS:DB().featChat = false, false
	Mock:Reset()
	NS:FeatAward("char_level_40")
	HF.Run(3)
	Check("[HF] bandeau coupé : rien d'affiché, rien dans le chat", not toast:IsShown() and #NS.journalToasts == 0
		and not Mock:Output():find("En selle", 1, true))
	NS:DB().featToast = true
	-- le moteur ne tourne que pour les sujets touchés
	HF.Reset(5)
	NS:FeatTouch("mission")
	HF.Run(1)
	Check("[HF] sujet sans rapport : rien d'évalué", NS:FeatGot("men_first") == nil)
	-- un relevé de lieu (tampon) : sujet « place »
	NS:JournalEarn("rare", 4242, "Rare de test")
	HF.Run(1)
	Check("[HF] tampon de rare : « Tête mise à prix » (personnage)", NS:FeatGot("day_rare_1") ~= nil
		and NS:CharData().feats.got.day_rare_1 ~= nil)
	HF.Run(5)
	-- moteur endormi (les autres tests) : aucun crochet ne le réveille
	NS.featsDormant = true
	NS:FeatTouch("capture")
	Check("[HF] endormi : FeatTouch ne marque rien", NS.featDirty.capture == nil)
	NS.featsDormant = false
end

-- 4. GetStatistic : lecture défensive et repli -------------------------------------------------------------
do
	Say("-- qc27 hauts faits : statistiques du client")
	local P = NS.FeatParseStat
	local gold = "12|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t 34|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t 5|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
	Check("[HF] stat : « -- », vide et nil valent 0", P("--") == 0 and P("") == 0 and P(nil) == 0 and P("  ") == 0)
	Check("[HF] stat : nombres « 780 », « 1 234 », « 1,234 », espace insécable, nombre", P("780") == 780
		and P("1 234") == 1234 and P("1,234") == 1234 and P("1\194\160234") == 1234 and P(56) == 56 and P(" 780 ") == 780)
	Check("[HF] stat : or « 12g 34s 5c », « 12 po 34 pa 5 pc », icônes du client", P("12g 34s 5c") == 123405
		and P("12 po 34 pa 5 pc") == 123405 and P(gold) == 123405 and P("|cffffffff1 234|r po") == 12340000
		and P("5c") == 5, tostring(P(gold)))
	Check("[HF] stat : forme illisible → nil", P("abc") == nil and P("12 lapins") == nil and P({}) == nil)
	_G.issecretvalue = function(v) return v == "SECRET" end
	Check("[HF] stat : valeur secrète → illisible", P("SECRET") == nil and P("780") == 780)
	_G.issecretvalue = HF.saved.issecretvalue

	HF.Reset(20)
	HF.stats[107] = "1 500"
	Check("[HF] sonde 107 lisible : statistiques en service", NS:FeatStatsOK() == true and NS:FeatStat(107) == 1500)
	NS:FeatCacheReset()
	local cur, max, state = NS:FeatProgress("char_kills_1000")
	Check("[HF] « Mille adversaires » par la statistique 107", cur == 1000 and max == 1000 and state == "open")
	Check("[HF] relecture au plus une fois par minute", (function()
		HF.stats[107] = "1 600"
		local cached = NS:FeatStat(107)
		Mock.now = Mock.now + 61
		return cached == 1500 and NS:FeatStat(107) == 1600
	end)())
	-- repli : statistiques illisibles, le bestiaire prend le relais
	HF.Reset(20)
	HF.stats[107] = nil
	NS:BestiaryData()[1413] = { [7001] = { name = "Raptor", killed = 600 }, [7002] = { name = "Loup", killed = 450 }, [7003] = "abîmé" }
	Check("[HF] sonde illisible : statistiques hors service", NS:FeatStatsOK() == false and NS:FeatStat(107) == nil)
	NS:FeatCacheReset()
	cur, max, state = NS:FeatProgress("char_kills_1000")
	Check("[HF] repli : les abattus du bestiaire (1050 ≥ 1000)", cur == 1000 and state == "open", tostring(cur))
	NS:FeatTouch("kill")
	HF.Run(1)
	Check("[HF] … et l'obtention par le repli", NS:FeatGot("char_kills_1000") ~= nil)
	HF.statsBroken = true
	NS:FeatStatReset()
	Check("[HF] GetStatistic en erreur : illisible, sans erreur", NS:FeatStatsOK() == false)
	HF.statsBroken = false
	-- réglage coupé : les statistiques ne sont plus lues
	HF.stats[107] = "99999"
	NS:DB().featStats = false
	NS:FeatStatReset()
	Check("[HF] réglage « statistiques » coupé : rien n'est lu", NS:FeatStatsOK() == false and NS:FeatStat(107) == nil)
	NS:DB().featStats = true
	-- haut fait marqué « à vérifier » : grisé, jamais obtenu
	HF.stats[353] = "80"
	NS:FeatStatReset()
	local _, _, hearth = NS:FeatProgress("char_hearth_50")
	NS:FeatEvaluate(nil)
	Check("[HF] haut fait « à vérifier » : grisé et jamais attribué", hearth == "pending" and NS:FeatGot("char_hearth_50") == nil)
	-- statistique sans repli et illisible : grisée aussi
	local probe = NS.FeatAdd({ "test_stat_noalt", 901, "char", 10, "char", crit = { "stat", { 9999 }, 5 }, desc = "FEATD_kills" })
	HF.stats[107] = nil
	NS:FeatStatReset()
	local _, _, noalt = NS:FeatProgress(probe)
	Check("[HF] statistique illisible sans repli : grisée", noalt == "pending")
	for index = #NS.FEAT_DEFS, 1, -1 do if NS.FEAT_DEFS[index].id == "test_stat_noalt" then table.remove(NS.FEAT_DEFS, index) end end
	NS.featIndexDirty = true
	-- /qc hf diag
	HF.stats[107] = "780"
	HF.stats[353] = "--"
	Mock:Reset()
	NS:HandleCommand("hf diag")
	local out = Mock:Output()
	-- lignes « à vérifier » : celles du catalogue chargé (les lots en ajoutent)
	local waiting = 0
	for _, def in ipairs(NS:FeatDefs()) do if def.pending then waiting = waiting + 1 end end
	Check("[HF] /qc hf diag : sonde lisible, chaque statistique avec sa valeur et sa forme brute",
		out:find("lisibles (107 = 780)", 1, true) and out:find("stat 107 : 780 (brut « 780 »)", 1, true)
		and out:find("stat 353 : 0 (brut « -- »)", 1, true) and waiting >= 1
			and out:find("en attente : " .. waiting .. " ", 1, true), out)
end

-- 5. Rattrapage à la connexion, migration des tampons --------------------------------------------------------
do
	Say("-- qc27 hauts faits : migration des tampons et rattrapage")
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
	Check("[HF] migration : paliers de niveau à la date et au niveau du tampon", got.char_level_10 and got.char_level_10.at == 50000
		and got.char_level_10.lvl == 10 and got.char_level_20 and got.char_level_20.at == 60000 and got.char_level_10.r == true)
	Check("[HF] migration : « Bourlingueur » à la date du 10e relevé de zone", got.zone_visit_10 and got.zone_visit_10.at == 100100
		and got.zone_visit_10.lvl == 10, got.zone_visit_10 and got.zone_visit_10.at)
	Check("[HF] migration : « Tour des capitales » à la date de la dernière des 6", got.zone_capitals
		and got.zone_capitals.at == 200006)
	Check("[HF] migration : rare, à sa date", got.day_rare_1 and got.day_rare_1.at == 300000)
	Check("[HF] migration : palier d'espèces de compte daté par collection.ranks", NS:DB().feats.got.men_species_10
		and NS:DB().feats.got.men_species_10.at == 40000)
	Check("[HF] migration : silencieuse (aucun bandeau), chat du carnet repris", #NS.featPending == 0
		and #NS.journalToasts == 0 and NS:DB().featChat == true and #migrated >= 6 and HF.earned[1].retro == true)
	local after = 0
	for _ in pairs(NS:JournalData().stamps) do after = after + 1 end
	Check("[HF] migration : journal.stamps intact (retour en 2.6 possible)", NS:JournalData().stamps == stamps
		and after == before and stamps["zone:9999"] == "abîmé")
	Check("[HF] migration : une seule fois (marques v)", NS:DB().feats.v == 1 and NS:CharData().feats.v == 1
		and #NS:FeatMigrate() == 0 and got.char_level_10.at == 50000)
	NS:DB().featChat = false
	-- sauvegarde cassée : jamais d'erreur
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
	Check("[HF] connexion : rien avant 3 s", NS:FeatGot("char_level_10") == nil)
	HF.Run(2)
	local lines = 0
	for line in (Mock:Output() .. "\n"):gmatch("([^\n]*)\n") do if line:find("Hauts faits :", 1, true) then lines = lines + 1 end end
	Check("[HF] connexion : tout ce qui est acquis est obtenu (tampons migrés et niveau rattrapé)",
		NS:FeatGot("char_level_10") and NS:FeatGot("char_level_20") and NS:FeatGot("zone_visit_10")
		and NS:CharData().feats.got.zone_visit_10.at <= 1011)
	Check("[HF] … une seule ligne de chat récapitulative", lines == 1, Mock:Output())
	HF.Run(2)
	local toast = NS.journalToast
	Check("[HF] … un seul bandeau, groupé", toast and toast:IsShown() and toast.text:GetText():find("hauts faits", 1, true)
		and #NS.journalToasts == 0 and #NS.featPending == 0, toast and toast.text:GetText())
	Check("[HF] … obtentions marquées « rattrapées » (pas d'annonce de guilde)", (function()
		for _, info in ipairs(HF.earned) do if not info.retro or info.announce then return false end end
		return #HF.earned >= 3
	end)())
	HF.Run(5)
	Mock:Reset()
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	HF.Run(5)
	Check("[HF] rechargement de l'interface : pas de second rattrapage", not Mock:Output():find("Hauts faits :", 1, true)
		and not toast:IsShown())
	-- connexion en combat : on attend la sortie
	HF.Reset(25)
	HF.combat = true
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	HF.Run(5)
	Check("[HF] connexion en combat : le rattrapage attend", NS:FeatGot("char_level_10") == nil and not NS.featLoginDone)
	HF.combat = false
	HF.Run(2)
	Check("[HF] … puis se fait hors combat", NS:FeatGot("char_level_10") ~= nil and NS.featLoginDone == true)
	HF.Run(5)
end

-- 6. Regroupement des bandeaux -------------------------------------------------------------------------------
do
	Say("-- qc27 hauts faits : regroupement")
	HF.Reset(60)
	NS:FeatAward("char_level_10"); NS:FeatAward("char_level_20")
	HF.Run(2)
	local toast = NS.journalToast
	Check("[HF] deux obtentions : deux bandeaux, l'un après l'autre", toast:IsShown() and toast.text:GetText() == "Premiers pas"
		and #NS.journalToasts == 1)
	HF.Run(5)
	Check("[HF] … puis le second", toast:IsShown() and toast.text:GetText() == "Sur la route")
	HF.Run(5)
	NS:FeatAward("char_level_30"); NS:FeatAward("char_level_40"); NS:FeatAward("char_level_50")
	HF.Run(2)
	Check("[HF] trois d'un coup : un seul bandeau « 3 hauts faits · +30 points »", toast:IsShown()
		and toast.text:GetText() == "3 hauts faits · +30 points" and toast.featPoints:GetText() == "30" and #NS.journalToasts == 0,
		toast.text:GetText())
	HF.Run(5)
	-- un palier débloque un méta dans la même passe (points)
	HF.Reset(60)
	local meta = NS.FeatAdd({ "test_meta_pts", 902, "meta", 10, "account", crit = { "points", 10 } })
	NS:FeatAward("char_level_10", { silent = true })
	NS:FeatAward("char_level_20", { silent = true })
	local earned = NS:FeatEvaluate({ level = true })
	Check("[HF] méta de points : obtenu dans la même passe que ce qu'il compte", NS:FeatGot(meta) ~= nil)
	local catMeta = NS.FeatAdd({ "test_meta_cat", 903, "meta", 10, "account", crit = { "meta", "char", 2 } })
	Check("[HF] méta de catégorie : progression = hauts faits obtenus de la catégorie", select(1, NS:FeatProgress(catMeta)) == 2)
	for index = #NS.FEAT_DEFS, 1, -1 do
		local id = NS.FEAT_DEFS[index].id
		if id == "test_meta_pts" or id == "test_meta_cat" then table.remove(NS.FEAT_DEFS, index) end
	end
	NS.featIndexDirty = true
	-- faits ponctuels et compteurs (lots B et C)
	local flag = NS.FeatAdd({ "test_flag", 904, "fun", 5, "account", crit = { "flag", "volee" } })
	local streak = NS.FeatAdd({ "test_streak", 905, "men", 5, "account", crit = { "streak", "rates", 3 } })
	NS:FeatFlag("volee", "account")
	NS:FeatCount("rates", 2, "account")
	NS:FeatEvaluate({ flag = true })
	Check("[HF] fait ponctuel et compteur : obtenus au seuil, compteur en route", NS:FeatGot(flag) ~= nil
		and NS:FeatGot(streak) == nil and select(1, NS:FeatProgress(streak)) == 2)
	NS:FeatCount("rates", 1, "account")
	NS:FeatEvaluate({ flag = true })
	Check("[HF] … puis le compteur atteint", NS:FeatGot(streak) ~= nil)
	for index = #NS.FEAT_DEFS, 1, -1 do
		local id = NS.FEAT_DEFS[index].id
		if id == "test_flag" or id == "test_streak" then table.remove(NS.FEAT_DEFS, index) end
	end
	NS.featIndexDirty = true
	HF.Run(5)
end

-- 7. Page du carnet, commandes, réglages, Guide --------------------------------------------------------------
do
	Say("-- qc27 hauts faits : page du carnet")
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
	Check("[HF] /qc hf : le carnet s'ouvre sur la page Hauts faits", f and f:IsShown() and f.kind == "feats"
		and pane and pane:IsShown() and f.header.title.text == NS.L.JRN_SEC_feats and f.sections.feats ~= nil)
	Check("[HF] nav : « Hauts faits » juste après la Ménagerie", f.sections.feats and f.sections.menagerie
		and select(5, f.sections.feats:GetPoint(1)) < select(5, f.sections.menagerie:GetPoint(1)))
	Check("[HF] sous-titre du carnet : les points", f.subtitle.text:find("15 points de hauts faits", 1, true), f.subtitle.text)
	Check("[HF] totaux : compte et personnage", pane.totals.text == "Compte : 5 points · Personnage : 10 points"
		and pane.count.text:find("3 / " .. #NS:FeatDefs(), 1, true), pane.totals.text)
	Check("[HF] catégories : « Toutes » puis une par catégorie, avec obtenus et points", #pane.cats == 1 + #NS:FeatCategories()
		and pane.cats[1].label.text == "Toutes" and pane.cats[2].label.text == "Ménagerie"
		and pane.cats[2].value.text == "1/" .. select(2, NS:FeatCategoryStats("men")) .. " · 5", pane.cats[2].value.text)
	local first = pane.rows[1]
	Check("[HF] liste : non obtenus d'abord, barre de progression", first:IsShown() and first.entry and not first.entry.got)
	local rows, firstGot = pane.list, nil
	for index, entry in ipairs(rows) do if entry.got and not firstGot then firstGot = index end end
	Check("[HF] liste : obtenus à la fin, du plus récent au plus ancien", rows[#rows].got and firstGot == #rows - 2
		and rows[firstGot].def.id == "men_first")
	-- trouver des lignes précises (pagination)
	local function Find(id)
		for offset = 0, #pane.list, pane.perPage do
			f.featsOffset = offset
			NS:RefreshJournal()
			for _, row in ipairs(pane.rows) do if row.def and row.def.id == id and row:IsShown() then return row end end
		end
	end
	local pending = Find("char_hearth_50")
	Check("[HF] ligne « à vérifier » grisée, « détection bientôt disponible »", pending and pending.alpha == 0.45
		and pending.desc.text:find("détection bientôt disponible", 1, true) and not pending.bar:IsShown(),
		pending and pending.desc.text)
	local account = Find("men_species_10")
	Check("[HF] marque de portée : Compte (bleu) ; barre et compte x/n ; récompense", account
		and account.scope.label.text == "COMPTE" and account.bar:IsShown() and account.count.text == "0 / 10"
		and account.reward.text:find("titre « Apprenti dresseur »", 1, true), account and account.reward.text)
	local earned = Find("char_level_10")
	Check("[HF] ligne obtenue : marque Perso, date, accent doré, pas de barre", earned and earned.scope.label.text == "PERSO"
		and earned.date.text == "Obtenu le 07/11/2026" and not earned.bar:IsShown() and earned.accentColor == NS.Theme.GOLD)
	Check("[HF] style Sobre : losange et points", earned and earned.diamond:IsShown() and not earned.shield:IsShown()
		and earned.pts.text == "5")
	Mock.InstallAtlas(true)
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = "azeroth"
	earned = Find("char_level_10")
	Check("[HF] style Azeroth : bouclier doré des hauts faits sous les points", earned and earned.shield:IsShown()
		and earned.shield.atlas == "ui-achievement-shield-1" and not earned.diamond:IsShown())
	-- filtres
	pane.filterChips.got:Click()
	Check("[HF] filtre « Obtenus » : seulement les obtenus (gardé)", #pane.list == 3 and NS:DB().featsFilter == "got")
	pane.filterChips.open:Click()
	Check("[HF] filtre « En cours » : aucun obtenu", #pane.list == #NS:FeatDefs() - 3 and not pane.list[1].got)
	pane.filterChips.all:Click()
	-- catégorie
	pane.cats[2]:Click()
	Check("[HF] clic sur une catégorie : sa liste", f.featsCat == "men" and (function()
		for _, entry in ipairs(pane.list) do if entry.def.cat ~= "men" then return false end end
		return #pane.list > 0
	end)())
	-- molette et pagination
	NS:JournalFeatsPick("all")
	NS:ScrollJournal(-1)
	Check("[HF] molette : une ligne plus bas, pagination à jour", f.featsOffset == 1 and pane.pager.position.text ~= "")
	-- infobulle
	NS:JournalFeatsTip(pane.rows[1])
	Check("[HF] infobulle d'une ligne sans erreur", true)
	f:Hide()
	-- options
	NS.optionsFrame = nil
	local keys = {}
	for _, page in ipairs(NS.OPTION_PAGES) do
		if page.id == "journal" then for _, row in ipairs(page.rows) do if row.key then keys[row.key] = true end end end
	end
	Check("[HF] réglages : bandeau, chat, fanfare et statistiques (page Carnet de voyage)", keys.featToast and keys.featChat
		and keys.featSound and keys.featStats and NS.DEFAULTS.featToast == true and NS.DEFAULTS.featChat == false)
	-- Guide
	local found = false
	for _, block in ipairs(NS:JournalGuideBlocks("settings")) do
		if block.text and block.text:find("/qc hf", 1, true) then found = true end
	end
	Check("[HF] Guide : une ligne pour les hauts faits", found)
	Check("[HF] aide de /qc : la commande hf", (function()
		for _, section in ipairs(NS.HELP) do
			for _, key in ipairs(section[2] or {}) do if key == "HELP_FEATS" then return true end end
		end
	end)())
end

-- remise en état pour les modules suivants (ils testent le style Sobre, sans atlas)
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
NS:DB().companionStyle = nil
ResetWorld()
