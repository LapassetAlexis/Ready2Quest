-- QuestCompanion 2.7.0, intégration des hauts faits : encodage compact du
-- catalogue (lignes décodées à la demande, mêmes ids, codes, points, portées,
-- critères et récompenses qu'avant : empreinte du catalogue), registre des
-- titres unique (FeatsTitles.lua), « le Malchanceux », dédoublonnage des
-- annonces de guilde, statistiques du diagnostic.
local Check, Say, NS = T.Check, T.Say, T.QNS

local I = {}

-- Sérialisation stable d'une valeur (clés triées)
function I.Ser(value)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do keys[#keys + 1] = key end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		local parts = {}
		for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. I.Ser(value[key]) end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	if kind == "function" then return "fn" end
	return tostring(value)
end

-- Empreinte 32 bits (djb2) d'une chaîne
function I.Hash(text)
	local h = 5381
	for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
	return string.format("%08x", h)
end

-- Lignes rendues grisées avant le relevé des statistiques en jeu (2026-11-07)
I.UNPENDED = { char_hearth_50 = true, char_gold_looted = true, char_epic = true, char_camp_25 = true, dng_runs_50 = true,
	pvp_hk_100 = true, fun_respec = true, zone_visit_all = true, zone_forever_new = true }

-- before = true : le catalogue tel qu'avant l'intégration (ces lignes grisées,
-- sans « La poisse », « Héros d'Azeroth » sans cadre de fiche) ; sinon tel quel
function I.Catalogue(before)
	local defs = {}
	for _, def in ipairs(NS:FeatDefs()) do
		if not (before and def.id == "fun_unlucky") then defs[#defs + 1] = def end
	end
	table.sort(defs, function(a, b) return a.n < b.n end)
	local lines = {}
	for _, def in ipairs(defs) do
		local pending = def.pending == true or (before and I.UNPENDED[def.id]) or false
		local reward = def.reward
		-- cadre de fiche de « Héros d'Azeroth » mis en attente à l'intégration
		if before and def.id == "meta_hero" then reward = { title = reward.title } end
		lines[#lines + 1] = table.concat({ def.id, def.n, def.cat, def.pts, def.scope, I.Ser(def.crit), I.Ser(reward),
			tostring(def.desc), tostring(pending), type(def.paid) }, "|")
	end
	return table.concat(lines, "\n"), #defs
end

-- 1. Catalogue décodé : identique ligne à ligne ------------------------------------------------------------
do
	Say("-- qc27 hauts faits : intégration (catalogue compact)")
	local text, count = I.Catalogue(true)
	local hash = I.Hash(text)
	Check("[HF-I] catalogue décodé : empreinte d'avant l'encodage compact (ids, codes, points, portées, critères, récompenses)",
		hash == "beba8d94" and count == 173, "empreinte " .. hash .. " (" .. count .. " lignes)")
	text, count = I.Catalogue(false)
	hash = I.Hash(text)
	Check("[HF-I] catalogue actuel : 174 lignes (173 numérotées + « La poisse »), empreinte",
		hash == "f98fd517" and count == 174, "empreinte " .. hash .. " (" .. count .. " lignes)")
	local def = NS:FeatDef("men_species_10")
	Check("[HF-I] définition compacte : lue par ses noms, champs absents à nil, écriture d'un champ connu",
		getmetatable(def) == NS.FEAT_DEF_MT and def.id == "men_species_10" and def.n == 2 and def.pts == 10
		and def.scope == "account" and def.desc == nil and def.pending == nil and type(def.paid) == "function"
		and def.crit[1] == "count" and def.reward.title == 1 and #def.topicList > 0)
	local added = NS.FeatAdd({ id = "test_compact", n = 990, cat = "fun", pts = 5, scope = "account",
		crit = { "flag", "x" }, extra = "gardé" })
	Check("[HF-I] ligne à clés : compactée, champ inconnu gardé", added.id == "test_compact" and added.n == 990
		and added.extra == "gardé" and NS:FeatDef("test_compact") == added)
	for index = #NS.FEAT_DEFS, 1, -1 do if NS.FEAT_DEFS[index].id == "test_compact" then table.remove(NS.FEAT_DEFS, index) end end
	NS.featIndexDirty = true
	Check("[HF-I] sources et listes des catalogues présentes (construites avec le catalogue)",
		NS.FEAT_SOURCES.elite and NS.FEAT_SOURCES.goldMax and NS.FEAT_SOURCES.boss_ony and NS.FEAT_LISTS.sealsEk
		and NS.FEAT_LISTS.dngTier1 and NS.FEAT_SOURCES.inconnue == nil)
	Check("[HF-I] boss : chaîne lue par champ", table.concat(NS.FeatBossField("sm", 1), ",") == "3977,3976"
		and table.concat(NS.FeatBossField("sm", 3), ",") == "6786,1093" and NS.FeatBossField("alcaz", 4) == "alcaz"
		and #NS.FeatBossField("mc", 3) == 0 and NS.FeatBossField("ony", 4) == nil)
end

-- 2. « La poisse » et le registre des titres ---------------------------------------------------------------
do
	Say("-- qc27 hauts faits : intégration (titres)")
	local def = NS:FeatDef("fun_unlucky")
	Check("[HF-I] « La poisse » : Insolite, compte, 5 points, titre T39, méta des quatre morts",
		def and def.cat == "fun" and def.scope == "account" and def.pts == 5 and def.n == 174 and def.reward.title == 39
		and def.crit[1] == "meta" and table.concat(def.crit[2], ",") == "char_deaths_1,fun_drown,fun_fall,fun_lava"
		and NS:FeatTitleText(39, nil, "f") == "Malchanceuse")
	-- chaque titre d'une ligne existe une fois au registre, et chaque titre a sa ligne
	local used, missing, orphans = {}, {}, {}
	for _, d in ipairs(NS:FeatDefs()) do
		local code = type(d.reward) == "table" and d.reward.title
		if code then
			if used[code] then missing[#missing + 1] = "T" .. code .. " deux fois" end
			used[code] = d.id
			if not NS.FEAT_TITLES[code] then missing[#missing + 1] = "T" .. code end
		end
	end
	for code, t in pairs(NS.FEAT_TITLES) do
		if used[code] ~= t.src then orphans[#orphans + 1] = "T" .. code .. " (" .. tostring(t.src) .. ")" end
	end
	Check("[HF-I] titres : les 40 au registre, un par ligne, source = ligne qui le donne", #missing == 0 and #orphans == 0,
		table.concat(missing, ", ") .. " / " .. table.concat(orphans, ", "))
	-- un seul registre : les catalogues n'en déclarent plus
	local ROOT = rawget(_G, "ADDON_ROOT") or "."
	local dup = {}
	for _, file in ipairs({ "FeatsData.lua", "FeatsCatMenagerie.lua", "FeatsCatJeu.lua", "Feats.lua" }) do
		local h = io.open(ROOT .. "/QuestCompanion/" .. file, "rb")
		local text = h and h:read("*a") or ""
		if h then h:close() end
		if text:find("FEAT_TITLES%[") or text:find("FEAT_TITLES%s*=") then dup[#dup + 1] = file end
	end
	Check("[HF-I] titres définis seulement dans FeatsTitles.lua", #dup == 0, table.concat(dup, ", "))
end

-- 3. Annonces de guilde et diagnostic ----------------------------------------------------------------------
do
	Say("-- qc27 hauts faits : intégration (guilde, diagnostic)")
	local notes = {}
	local base = NS.GuildFeatNote
	NS.GuildFeatNote = function(_, feat) notes[#notes + 1] = feat; return true end
	for _, id in ipairs({ "men_species_10", "men_species_25", "men_species_50", "men_species_100", "men_species_250",
		"men_species_500" }) do
		local def = NS:FeatDef(id)
		NS:GuildFeatsOnFeat({ id = id, n = def.n, pts = def.pts, announce = true, retro = false })
	end
	NS.GuildFeatNote = base
	Check("[HF-I] paliers d'espèces : annoncés une fois (sorte r), pas en h ; 500 espèces en h",
		#notes == 1 and notes[1].kind == "h" and notes[1].id == 7)
	if NS.FeatJeuInit then NS:FeatJeuInit() end
	local set, absent = {}, {}
	for _, id in ipairs(NS:FeatStatIDs()) do set[id] = true end
	for _, d in ipairs(NS:FeatDefs()) do
		if (d.crit or {})[1] == "stat" then
			for _, id in ipairs(d.crit[2]) do if not set[id] then absent[#absent + 1] = d.id .. ":" .. id end end
		end
	end
	for key in pairs(NS.FEAT_BOSSES) do
		for _, id in ipairs(NS.FeatBossField(key, 3)) do if not set[id] then absent[#absent + 1] = key .. ":" .. id end end
	end
	for _, id in ipairs({ 334, 1524, 1519, 281, 1527, 1537 }) do if not set[id] then absent[#absent + 1] = tostring(id) end end
	Check("[HF-I] /qc hf diag : chaque statistique d'une ligne, d'un boss ou d'un repli", #absent == 0 and set[107],
		table.concat(absent, ", "))
end

-- 3 bis. Le Guide parle des titres des hauts faits
do
	local found = false
	for _, block in ipairs(NS:JournalGuideBlocks("titles")) do
		if block.text and block.text:find("/qc titre", 1, true) and block.text:find("40 titres", 1, true) then found = true end
	end
	Check("[HF-I] Guide : les 40 titres des hauts faits et /qc titre (section Titres)", found)
end

-- 4. Statistiques du client : formes relevées sur Forever ----------------------------------------------------
do
	Say("-- qc27 hauts faits : intégration (statistiques de Forever)")
	local P = NS.FeatParseStat
	local G, S, C = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t", "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
		"|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
	Check("[HF-I] or en icônes : 1 po 87 pa 88 pc", P("1" .. G .. " 87" .. S .. " 88" .. C) == 18788)
	Check("[HF-I] or sans pièces d'or : 36 pa 69 pc", P("36" .. S .. " 69" .. C) == 3669)
	Check("[HF-I] or : pièces d'or seules, cuivre seul", P("12" .. G) == 120000 and P("5" .. C) == 5)
	Check("[HF-I] « -- » = 0 ; nombres simples", P("--") == 0 and P("10") == 10 and P("117") == 117 and P(" 6 ") == 6)
end
