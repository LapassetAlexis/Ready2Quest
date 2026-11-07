-- QuestCompanion 2.8.1 / Ready2Quest 1.29.5 : passe d'optimisation (mémoire,
-- processeur, code mort). Ces tests gardent les chemins paresseux : la
-- première lecture construit exactement ce que l'ancien chargement donnait.
local Check, Say, NS = T.Check, T.Say, T.QNS
local ROOT = rawget(_G, "ADDON_ROOT") or "."

-- 1. Tables de zones en chaînes compactes ----------------------------------------------------------
do
	Say("-- 2.8.1 : zones en chaînes compactes")
	local built = 0
	local t = NS.LazyZones({ [7] = "texte", [3] = function() return { "fn" } end },
		function(text) built = built + 1; return { text } end)
	Check("[OPT] zone en chaîne : rien construit au chargement", built == 0 and rawget(t, 7) == nil)
	Check("[OPT] zone en chaîne : construite à la lecture, puis gardée", t[7][1] == "texte" and t[7][1] == "texte" and built == 1)
	Check("[OPT] zone en fonction : toujours acceptée", t[3][1] == "fn")
	Check("[OPT] zone inconnue / clé nil : nil", t[99] == nil and t[nil] == nil)
	Check("[OPT] ZonePeek sans garder", NS.ZonePeek(NS.LazyZones({ [1] = "x" }, function(x) return { x } end), 1)[1] == "x")
	-- les tables livrées : une créature et une quête relues champ par champ
	local boar = NS.ZONE_CREATURES[1411] and NS.ZONE_CREATURES[1411][3098]
	Check("[OPT] créature livrée : niveaux, rang, noms", type(boar) == "table" and boar.lvl[1] == 1 and boar.lvl[2] == 2
		and boar.rank == 0 and boar.fr == "Sanglier tacheté" and boar.en == "Mottled Boar" and boar.f == nil)
	local withF, sameName, withEx, sameQuest = nil, nil, nil, nil
	NS.ZoneEach(NS.ZONE_CREATURES, function(_, zone)
		for _, c in pairs(zone) do
			if c.f and not withF then withF = c end
			if c.fr == c.en and not sameName then sameName = c end
		end
	end)
	NS.ZoneEach(NS.ZONE_QUESTS, function(_, zone)
		for _, q in pairs(zone) do
			if q.ex and not withEx then withEx = q end
			if q.fr == q.en and not sameQuest then sameQuest = q end
		end
	end)
	Check("[OPT] créature amicale envers une faction : f gardé", withF and (withF.f == "A" or withF.f == "H"))
	Check("[OPT] nom identique dans les deux langues : fr = en", sameName and sameName.fr == sameName.en and sameName.fr ~= "")
	-- les lecteurs des deux fichiers, sur des lignes faites à la main
	local builders = {}
	for _, file in ipairs({ "ZoneCreatures_Forever", "ZoneQuests_Forever" }) do
		local fake = { IsForeverClient = function() return true end,
			LazyZones = function(_, build) builders[file] = build; return {} end }
		assert(loadfile(ROOT .. "/QuestCompanion/" .. file .. ".lua"))("QuestCompanion", fake)
	end
	local c = builders.ZoneCreatures_Forever("5\t-1\t3\t4\t\tSame\tH\n6\t2\t2\t0\tFr\tEn\n")
	Check("[OPT] lecteur des créatures : niveaux négatifs, nom fr vide, f", c[5].lvl[1] == -1 and c[5].lvl[2] == 3
		and c[5].rank == 4 and c[5].fr == "Same" and c[5].en == "Same" and c[5].f == "H"
		and c[6].fr == "Fr" and c[6].en == "En" and c[6].f == nil)
	local q = builders.ZoneQuests_Forever("9\t-1\t-1\t8589934592\t0\t\tName\t3,40\n10\t5\t3\t0\t4\tNom\tName\n")
	Check("[OPT] lecteur des quêtes : -1, grands masques, ex", q[9].lvl == -1 and q[9].req == -1 and q[9].races == 8589934592
		and q[9].classes == 0 and q[9].fr == "Name" and q[9].ex[1] == 3 and q[9].ex[2] == 40 and #q[9].ex == 2
		and q[10].ex == nil and q[10].classes == 4 and q[10].fr == "Nom")
	Check("[OPT] quête fermée par d'autres : liste de nombres", withEx and type(withEx.ex[1]) == "number" and withEx.ex[1] > 0)
	Check("[OPT] quête au nom identique : fr = en", sameQuest and sameQuest.fr == sameQuest.en)
end

-- 2. Répliques du compagnon : textes de la langue du client, clés à la lecture ---------------------
do
	Say("-- 2.8.1 : répliques sur le client")
	local savedLocale, savedTesting = _G.GetLocale, rawget(_G, "ADDON_TESTING")
	local function LoadLines(locale)
		_G.GetLocale = function() return locale end
		_G.ADDON_TESTING = nil
		local fake = { Mark = function() end }
		local ok, err = pcall(function()
			assert(loadfile(ROOT .. "/QuestCompanion/Libs/Socle/Strings.lua"))("QuestCompanion", fake)
			for _, file in ipairs({ "CompanionLines", "PersonalityLines" }) do
				assert(loadfile(ROOT .. "/QuestCompanion/" .. file .. ".lua"))("QuestCompanion", fake)
			end
		end)
		_G.GetLocale, _G.ADDON_TESTING = savedLocale, savedTesting
		assert(ok, err)
		return fake
	end
	local shared = NS.COMPANION_LINE_STRINGS
	for _, case in ipairs({ { "frFR", "fr" }, { "enUS", "en" } }) do
		local fake = LoadLines(case[1])
		Check("[OPT] " .. case[1] .. " : ni clés ni tables sources gardées", fake.KEEP_STRINGS == false
			and fake.COMPANION_LINE_STRINGS == nil and fake.PERSONALITY_POOLS == nil
			and rawget(fake.COMPANION_POOLS, "HELLO") == nil)
		local pools, lines, bad = 0, 0, {}
		for name, keys in pairs(NS.COMPANION_POOLS) do
			local lazy = fake.COMPANION_POOLS[name]
			if lazy then
				pools = pools + 1
				if #lazy ~= #keys then bad[#bad + 1] = name .. "#" end
				for index, key in ipairs(keys) do
					lines = lines + 1
					local want = shared[case[2]][key]
					if want == nil then want = shared.fr[key] end
					if lazy[index] ~= key or fake.L[key] ~= want then bad[#bad + 1] = key end
				end
			end
		end
		Check("[OPT] " .. case[1] .. " : mêmes réservoirs, mêmes clés, mêmes textes qu'en déclarant tout",
			#bad == 0 and pools > 300 and lines > 2000, table.concat(bad, ",", 1, math.min(#bad, 8)) .. " / " .. pools .. " / " .. lines)
		Check("[OPT] " .. case[1] .. " : liste gardée après sa première lecture",
			rawget(fake.COMPANION_POOLS, "HELLO") ~= nil and fake.COMPANION_POOLS.HELLO == fake.COMPANION_POOLS.HELLO)
		Check("[OPT] " .. case[1] .. " : clé hors réservoir rendue telle quelle",
			fake.L.COMP_SAY_HELLO_1 == "COMP_SAY_HELLO_1" and fake.L.COMP_SAY_HELLO_02 == "COMP_SAY_HELLO_02"
			and fake.L.COMP_SAY_HELLO_999 == "COMP_SAY_HELLO_999" and fake.L.COMP_SAY_NOPE == "COMP_SAY_NOPE"
			and fake.COMPANION_POOLS.NOPE == nil)
	end
	-- toutes les répliques de l'addon (tous les fichiers) : une clé désigne un seul réservoir
	local function Has(name) return rawget(NS.COMPANION_POOLS, name) ~= nil end
	local wrong = {}
	for name, keys in pairs(NS.COMPANION_POOLS) do
		for index, key in ipairs(keys) do
			local n, i = NS.CompanionLineParse(key, Has)
			if n ~= name or i ~= index then wrong[#wrong + 1] = key end
		end
	end
	Check("[OPT] chaque clé de réplique se relit en son réservoir et son rang", #wrong == 0, table.concat(wrong, ","))
	-- aucune réplique n'est aussi déclarée comme texte ordinaire (le client lit
	-- d'abord les textes déclarés)
	local twice = {}
	for _, source in pairs({ NS.COMPANION_STRINGS, NS.QC_STRINGS, NS.CAPTURE_STRINGS, NS.DAILY_STRINGS, NS.SHINY_STRINGS,
		NS.WEEKLY_STRINGS, NS.NOTIFY_STRINGS }) do
		for key in pairs(source and source.fr or {}) do
			if type(key) == "string" and key:find("^COMP_SAY_") then twice[#twice + 1] = key end
		end
	end
	Check("[OPT] aucune réplique déclarée aussi en texte ordinaire", #twice == 0, table.concat(twice, ","))
end
