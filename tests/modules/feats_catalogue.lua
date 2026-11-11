-- QuestCompanion 2.7+ : intégrité du catalogue des hauts faits (FeatsData.lua,
-- FeatsCatMenagerie.lua, FeatsCatJeu.lua, FeatsTitles.lua, FeatsCosmetics.lua).
-- Ids et codes uniques, codes = rang dans le document, points, portées,
-- catégories et leurs comptes, noms et descriptions FR/EN, sources et listes ;
-- encodage compact décodé ligne à ligne (empreintes) ; lignes du document
-- (lot B) ; lignes « à vérifier » ; registre des 40 titres (document §4.1, un
-- par ligne, un seul fichier) ; cosmétiques des hauts faits faits d'images du
-- client seulement ; textes de récompense sans identifiant brut ; ordre du .toc.
local Check, Say, NS = T.Check, T.Say, T.QNS
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local function Read(path)
	local handle = io.open(ROOT .. "/" .. path, "rb")
	if not handle then return nil end
	local text = handle:read("*a")
	handle:close()
	return text
end
local DOC = Read("docs/QC-HAUTS-FAITS.md") or ""
local CATALOGUE = DOC:sub(DOC:find("## 2. Catalogue", 1, true) or 1, DOC:find("### 2.12", 1, true) or #DOC)

-- 1. Définitions ----------------------------------------------------------------------------------------
do
	Say("-- hauts faits : catalogue, définitions")
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
	if not (NS:FeatDef("men_first").scope == "account" and NS:FeatDef("char_level_10").scope == "char") then
		bad[#bad + 1] = "les deux portées"
	end
	Check("[HF] catalogue : ids et codes uniques, points 5/10/25/50, portée et catégorie, noms FR/EN, descriptions, "
		.. "sources, listes, aides et titres existants", #bad == 0 and #defs >= 30, table.concat(bad, ", "))
	-- les codes suivent le catalogue du document (rang dans §2)
	local rank, order = 0, {}
	for line in CATALOGUE:gmatch("[^\n]+") do
		local id = line:match("^| `([%w_]+)` |")
		if id then rank = rank + 1; order[id] = rank end
	end
	local off = {}
	-- au-delà de 173 : lignes hors numérotation, citées dans le document
	for _, def in ipairs(defs) do
		local extra = def.n > 173 and DOC:find("`" .. def.id .. "` (code " .. def.n .. ")", 1, true)
		if order[def.id] ~= def.n and not extra then off[#off + 1] = def.id end
	end
	Check("[HF] codes n = rang dans le catalogue du document (173 lignes), les suivants cités avec leur code",
		rank == 173 and #off == 0, table.concat(off, ", "))
	local parity = {}
	for _, name in ipairs({ "FEAT_STRINGS", "FEAT_DATA_STRINGS", "JOURNAL_FEATS_STRINGS", "FEAT_MENAGERIE_STRINGS",
		"FEAT_JEU_STRINGS", "FEAT_TITLE_STRINGS", "TRAINER_STRINGS", "GFEAT_STRINGS", "FEAT_COSMETIC_STRINGS" }) do
		local set = NS[name]
		if not set then parity[#parity + 1] = name .. " absent"
		else
			for key in pairs(set.fr) do if set.en[key] == nil then parity[#parity + 1] = key end end
			for key in pairs(set.en) do if set.fr[key] == nil then parity[#parity + 1] = key end end
		end
	end
	Check("[HF] chaînes des hauts faits, titres, fiche, guilde, cosmétiques : mêmes clés en français et en anglais",
		#parity == 0, table.concat(parity, ", "))
	local toc = Read("QuestCompanion/QuestCompanion.toc") or ""
	local function At(name) return toc:find("\n" .. name .. "\r?\n") end
	local seq = { "AzerothStyle.lua", "FeatsData.lua", "FeatsCatMenagerie.lua", "FeatsCatJeu.lua", "Feats.lua",
		"FeatsCosmetics.lua", "JournalFeats.lua", "FeatsTitles.lua" }
	local tocOk = true
	for i = 1, #seq do
		if not At(seq[i]) or (i > 1 and At(seq[i]) < At(seq[i - 1])) then tocOk = false end
	end
	Check("[HF] .toc : données, catalogues, moteur, cosmétiques, page puis titres, dans cet ordre", tocOk
		and toc:find("FeatsData.lua\r?\nFeatsCatMenagerie.lua\r?\n") ~= nil and toc:find("\nFeats.lua\r?\nFeatsCosmetics.lua\r?\n") ~= nil)
end

-- 2. Encodage compact : décodé identique ligne à ligne -------------------------------------------------
do
	Say("-- hauts faits : catalogue compact")
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
	I.LOT_E = { feat_chain = true, feat_eight = true, feat_goldstars = true, feat_prism_orn = true, feat_atlas = true,
		feat_compass = true, feat_anniversary = true, feat_prism = true }
	-- before = true : le catalogue tel qu'avant l'intégration (ces lignes grisées,
	-- sans « La poisse », « Héros d'Azeroth » sans cadre de fiche) ; sinon tel quel
	function I.Catalogue(before)
		local defs = {}
		for _, def in ipairs(NS:FeatDefs()) do
			-- 2.14.0 : « Joyeux Voile d'hiver » (code 175) ; 3.1.0 : tailles rares (176, 177) ;
			-- 3.0.0 : échanges de spécimens (178 à 180), venus après l'intégration
			if not (before and (def.id == "fun_unlucky" or def.id == "fun_winter_veil" or def.id == "men_size_giant"
				or def.id == "men_size_tiny" or def.id == "soc_trade_1" or def.id == "soc_trade_10"
				or def.id == "soc_trade_new")) then defs[#defs + 1] = def end
		end
		table.sort(defs, function(a, b) return a.n < b.n end)
		local lines = {}
		for _, def in ipairs(defs) do
			local pending = def.pending == true or (before and I.UNPENDED[def.id]) or false
			local reward = def.reward
			if before and def.id == "meta_hero" then reward = { title = reward.title } end
			-- 3.0.0 (bêta 6) : « Au galop » ne lit plus la statistique 339 (collection du compte)
			local crit = def.crit
			if before and def.id == "char_mount" then crit = { "stat", { 339 }, 1, alt = "mountSeen" } end
			-- lot E (FeatsCosmetics.lua) : ces cosmétiques attendaient (reward.soon) ; même ligne, relue en attente
			if type(reward) == "table" and reward.cosmetic and I.LOT_E[reward.cosmetic[2]] then
				local copy = {}
				for key, value in pairs(reward) do copy[key] = value end
				copy.soon, copy.cosmetic = copy.cosmetic, nil
				reward = copy
			end
			lines[#lines + 1] = table.concat({ def.id, def.n, def.cat, def.pts, def.scope, I.Ser(crit), I.Ser(reward),
				tostring(def.desc), tostring(pending), type(def.paid) }, "|")
		end
		return table.concat(lines, "\n"), #defs
	end
	local text, count = I.Catalogue(true)
	local hash = I.Hash(text)
	Check("[HF] catalogue décodé : empreinte d'avant l'encodage compact (ids, codes, points, portées, critères, récompenses)",
		hash == "beba8d94" and count == 173, "empreinte " .. hash .. " (" .. count .. " lignes)")
	text, count = I.Catalogue(false)
	hash = I.Hash(text)
	-- 3.0.0 (bêta 6) : « Au galop » sur IsMounted hors taxi (ea095038 avant)
	Check("[HF] catalogue actuel : 180 lignes (173 + « La poisse » + « Joyeux Voile d'hiver » + tailles 3.1 + échanges 3.0), empreinte",
		hash == "67fd0476" and count == 180, "empreinte " .. hash .. " (" .. count .. " lignes)")
	local def = NS:FeatDef("men_species_10")
	local added = NS.FeatAdd({ id = "test_compact", n = 990, cat = "fun", pts = 5, scope = "account",
		crit = { "flag", "x" }, extra = "gardé" })
	Check("[HF] définition compacte : lue par ses noms, champs absents à nil ; ligne à clés compactée, champ inconnu gardé",
		getmetatable(def) == NS.FEAT_DEF_MT and def.id == "men_species_10" and def.n == 2 and def.pts == 10
		and def.scope == "account" and def.desc == nil and def.pending == nil and type(def.paid) == "function"
		and def.crit[1] == "count" and def.reward.title == 1 and #def.topicList > 0
		and added.id == "test_compact" and added.n == 990 and added.extra == "gardé" and NS:FeatDef("test_compact") == added)
	for index = #NS.FEAT_DEFS, 1, -1 do if NS.FEAT_DEFS[index].id == "test_compact" then table.remove(NS.FEAT_DEFS, index) end end
	NS.featIndexDirty = true
	Check("[HF] sources, listes et boss construits avec le catalogue ; chaîne de boss lue par champ",
		NS.FEAT_SOURCES.elite and NS.FEAT_SOURCES.goldMax and NS.FEAT_SOURCES.boss_ony and NS.FEAT_LISTS.sealsEk
		and NS.FEAT_LISTS.dngTier1 and NS.FEAT_SOURCES.inconnue == nil
		and table.concat(NS.FeatBossField("sm", 1), ",") == "3977,3976" and table.concat(NS.FeatBossField("sm", 3), ",") == "6786,1093"
		and NS.FeatBossField("alcaz", 4) == "alcaz" and #NS.FeatBossField("mc", 3) == 0 and NS.FeatBossField("ony", 4) == nil)
end

-- 3. Lignes du document (lot B) et comptes par catégorie -------------------------------------------------
do
	Say("-- hauts faits : lignes du document, comptes")
	local rows, rank = {}, 0
	for line in CATALOGUE:gmatch("[^\n]+") do
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
	for code, id in DOC:gmatch("\n| T(%d+) | `([%w_]+)` |") do titleOf[id] = code end
	local WHOLE = { men = 29, shiny = 12, zone = 23, day = 14, soc = 7 }
	local FUN = { fun_name = true, fun_dance = true, fun_hogger_kill = true, fun_hogger_capture = true, fun_murlocs = true,
		fun_critter = true, fun_night_owl = true, fun_birthday = true }
	local META = { meta_menagerie = true, meta_shiny = true, meta_zones = true, meta_points_500 = true,
		meta_points_1500 = true, meta_trainer = true }
	local bad, counts, expected = {}, {}, {}
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
				if def.pts ~= row.pts then Bad("points") end
				if def.cat ~= cat then Bad("catégorie") end
				if def.scope ~= ((cat == "zone" or cat == "day") and "char" or "account") then Bad("portée") end
				if (def.pending == true) ~= (row.feas:find("⚠", 1, true) ~= nil) then Bad("à vérifier") end
				local reward = def.reward or {}
				local title = row.reward:match("titre T(%d+)") or titleOf[row.id]
				if tonumber(title) ~= reward.title then Bad("titre") end
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
	Check("[HF] lot B : chaque ligne du document présente, points, portée, « à vérifier », titre, aides, cosmétique",
		#bad == 0, table.concat(bad, ", "))
	-- comptes et points par catégorie (document), portée des catégories du jeu
	local off = {}
	for cat, n in pairs(WHOLE) do if counts[cat] ~= n or expected[cat] ~= n then off[#off + 1] = cat end end
	if not (counts.fun == 8 and counts.meta == 6) then off[#off + 1] = "fun/meta du lot B" end
	local fewer = 0
	for _, id in ipairs(NS.FEAT_MENAGERIE_IDS) do if NS:FeatDef(id) then fewer = fewer + 1 end end
	-- 2.14.0 : + fun_winter_veil ; 3.1.0 : + tailles rares ; 3.0.0 : + échanges de spécimens
	if not (#NS.FEAT_MENAGERIE_IDS == 89 and fewer == 89) then off[#off + 1] = "lot B : " .. #NS.FEAT_MENAGERIE_IDS end
	local all, points = {}, {}
	for _, def in ipairs(NS:FeatDefs()) do
		all[def.cat] = (all[def.cat] or 0) + 1
		points[def.cat] = (points[def.cat] or 0) + def.pts
		if (def.cat == "char" or def.cat == "dng" or def.cat == "prof" or def.cat == "quest") and def.scope ~= "char" then
			off[#off + 1] = def.id .. " portée"
		end
	end
	for cat, want in pairs({ char = { 21, 255 }, dng = { 21, 490 }, prof = { 12, 155 }, quest = { 11, 185 } }) do
		if all[cat] ~= want[1] or points[cat] ~= want[2] then
			off[#off + 1] = string.format("%s %s/%s", cat, tostring(all[cat]), tostring(points[cat]))
		end
	end
	for _, id in ipairs({ "fun_hogger_death", "fun_critters_kill", "fun_drown", "fun_fall", "fun_lava", "fun_emotes", "fun_respec" }) do
		local def = NS:FeatDef(id)
		if not (def and def.scope == "account" and (def.crit or {})[1] == "stat") then off[#off + 1] = id end
	end
	for _, id in ipairs({ "meta_dungeons", "meta_hero" }) do
		if not (NS:FeatDef(id) and NS:FeatDef(id).scope == "account") then off[#off + 1] = id end
	end
	Check("[HF] comptes par catégorie : Créatures 29, Brillantes 12, Zones 23, Jour 14, Guilde 7, Personnage 21 (255 pts), "
		.. "Donjons 21 (490), Métiers 12 (155), Quêtes 11 (185) ; Insolite et métas du jeu au compte", #off == 0,
		table.concat(off, ", "))
	-- récompenses déplacées de TRAINER_RANKS / SHINY_REWARDS : mêmes aides et cosmétiques qu'avant
	local moved = {}
	for _, rankDef in ipairs(NS.TRAINER_RANKS) do
		local def = NS:FeatDef("men_species_" .. rankDef.count)
		local aids = {}
		for _, id in ipairs(rankDef.aids or {}) do aids[id] = (aids[id] or 0) + 1 end
		for id, n in pairs(aids) do if (def.reward.aids or {})[id] ~= n then moved[#moved + 1] = def.id .. " " .. id end end
		if rankDef.cosmetic and not (def.reward.cosmetic and def.reward.cosmetic[1] == rankDef.cosmetic.kind
			and def.reward.cosmetic[2] == rankDef.cosmetic.id) then moved[#moved + 1] = def.id .. " cosmétique" end
		if type(def.paid) ~= "function" then moved[#moved + 1] = def.id .. " paid" end
	end
	for _, reward in ipairs(NS.SHINY_REWARDS) do
		local def = NS:FeatDef("shiny_found_" .. reward.count)
		local cosm = def.reward.cosmetic or { "app", def.reward.appearance }
		if cosm[1] ~= reward.kind or cosm[2] ~= reward.def.id then moved[#moved + 1] = def.id end
	end
	Check("[HF] paliers d'espèces et de brillantes : mêmes aides et cosmétiques qu'avant, payés par le haut fait", #moved == 0,
		table.concat(moved, ", "))
	-- lignes « à vérifier » : seulement les statistiques pas encore lues sur Forever
	local pending = {}
	for _, def in ipairs(NS:FeatDefs()) do
		if def.pending and (def.cat == "char" or def.cat == "dng" or def.cat == "prof" or def.cat == "quest" or def.cat == "fun") then
			pending[#pending + 1] = def.id
		end
	end
	table.sort(pending)
	local want = { "char_food_500", "char_mount_epic", "char_potions_100", "dng_raid_barrow", "dng_raid_hyjal",
		"fun_critters_kill", "fun_drown", "fun_fall", "fun_hogger_death", "fun_lava", "fun_unlucky", "prof_fish_250",
		"pvp_bg_win", "pvp_duel_10", "quest_valthalak" }
	table.sort(want)
	Check("[HF] lignes « à vérifier » : les 15 statistiques pas encore lues sur Forever", table.concat(pending, ",")
		== table.concat(want, ","), table.concat(pending, ","))
	Check("[HF] descriptions : seuils lisibles", NS:FeatDescription("char_gold_1000") == "Avoir possédé 1000 pièces d'or"
		and NS:FeatDescription("dng_tier1"):find("^Vaincre le dernier boss de 8 donjons") ~= nil
		and NS:FeatDescription("meta_dungeons") == "Obtenir les 4 paliers de donjons"
		and NS:FeatDescription("quest_500") == "Rendre 500 quêtes", NS:FeatDescription("dng_tier1"))
	-- toutes les statistiques d'une ligne, d'un boss ou d'un repli sont lues par /qc hf diag
	if NS.FeatJeuInit then NS:FeatJeuInit() end
	local ids, set, absent = NS:FeatStatIDs(), {}, {}
	for _, id in ipairs(ids) do set[id] = true end
	for i = 2, #ids do if ids[i] <= ids[i - 1] then absent[#absent + 1] = "ordre " .. ids[i] end end
	for _, d in ipairs(NS:FeatDefs()) do
		if (d.crit or {})[1] == "stat" then
			for _, id in ipairs(d.crit[2]) do if not set[id] then absent[#absent + 1] = d.id .. ":" .. id end end
		end
	end
	for key in pairs(NS.FEAT_BOSSES) do
		for _, id in ipairs(NS.FeatBossField(key, 3)) do if not set[id] then absent[#absent + 1] = key .. ":" .. id end end
	end
	for _, id in ipairs({ 107, 334, 1524, 1519, 281, 1527, 1537, 98, 60, 15027, 63574, 1098, 1201, 588, 1149 }) do
		if not set[id] then absent[#absent + 1] = tostring(id) end
	end
	Check("[HF] /qc hf diag : chaque statistique d'une ligne, d'un boss ou d'un repli, triées", #absent == 0,
		table.concat(absent, ", "))
end

-- 4. Registre des titres --------------------------------------------------------------------------------
do
	Say("-- hauts faits : registre des titres")
	local T_ = NS.FEAT_TITLES
	local section = DOC:sub(DOC:find("### 4.1 Titres", 1, true) or 1, DOC:find("### 4.2", 1, true) or #DOC)
	local rows, bad = 0, {}
	for line in section:gmatch("[^\n]+") do
		local code, _, m, f, en, ps = line:match("^| T(%d+) | (.-) | (.-) | (.-) | (.-) | ([PS]) |$")
		if code then
			rows = rows + 1
			code = tonumber(code)
			local t = T_[code]
			local enm, enf = en:match("^(.-) / (.+)$")
			if not enm then enm = en end
			if not t then bad[#bad + 1] = "T" .. code .. " absent"
			else
				if t.m ~= m then bad[#bad + 1] = "T" .. code .. " m" end
				if (f == "—" and t.f ~= nil) or (f ~= "—" and t.f ~= f) then bad[#bad + 1] = "T" .. code .. " f" end
				if t.en ~= enm or t.enf ~= enf then bad[#bad + 1] = "T" .. code .. " en" end
				if (ps == "P") ~= (t.pos == "pre") then bad[#bad + 1] = "T" .. code .. " P/S" end
			end
		end
	end
	Check("[TIT] 40 titres, formes FR m/f et EN conformes au document (§4.1)", rows == 40 and #bad == 0,
		rows .. " lignes ; " .. table.concat(bad, ", "))
	local count, shape = 0, {}
	for code, t in pairs(T_) do
		count = count + 1
		if type(code) ~= "number" or code < 1 or code > NS.FEAT_TITLE_MAX then shape[#shape + 1] = tostring(code) .. " code" end
		for _, key in ipairs({ "m", "f", "en", "enf" }) do
			local fmt = t[key]
			if fmt ~= nil then
				local _, n = fmt:gsub("%%s", "")
				if n ~= 1 then shape[#shape + 1] = code .. " " .. key .. " %s" end
				if (t.pos == "pre") == (fmt:find("^%%s") ~= nil) then shape[#shape + 1] = code .. " " .. key .. " place" end
			end
		end
		if not (t.m and t.en and (t.pos == "pre" or t.pos == "suf")) then shape[#shape + 1] = code .. " incomplet" end
		if not (type(t.src) == "string" and DOC:find("`" .. t.src .. "`", 1, true)) then shape[#shape + 1] = code .. " source" end
		-- anglais genré seulement pour Seigneur / Dame et Héros / Héroïne
		if t.enf and code ~= 35 and code ~= 37 then shape[#shape + 1] = code .. " enf" end
	end
	Check("[TIT] codes 1 à 40 uniques, un seul %s par forme, place cohérente, source citée, anglais genré pour 35 et 37 seulement",
		count == 40 and #shape == 0 and T_[35].enf and T_[37].enf, table.concat(shape, ", "))
	-- chaque titre d'une ligne existe une fois au registre, et chaque titre a sa ligne (sa source)
	local used, missing = {}, {}
	for _, d in ipairs(NS:FeatDefs()) do
		local code = type(d.reward) == "table" and d.reward.title
		if code then
			if used[code] then missing[#missing + 1] = "T" .. code .. " deux fois" end
			used[code] = d.id
			if not T_[code] then missing[#missing + 1] = "T" .. code end
		end
	end
	for code, t in pairs(T_) do
		if used[code] ~= t.src then missing[#missing + 1] = "T" .. code .. " (" .. tostring(t.src) .. ")" end
	end
	local unlucky = NS:FeatDef("fun_unlucky")
	Check("[TIT] titres : un par ligne, source = ligne qui le donne ; « La poisse » (174) donne T39, méta des quatre morts",
		#missing == 0 and unlucky and unlucky.cat == "fun" and unlucky.scope == "account" and unlucky.pts == 5
		and unlucky.n == 174 and unlucky.reward.title == 39 and unlucky.crit[1] == "meta"
		and table.concat(unlucky.crit[2], ",") == "char_deaths_1,fun_drown,fun_fall,fun_lava"
		and NS:FeatTitleText(39, nil, "f") == "Malchanceuse", table.concat(missing, ", "))
	local dup = {}
	for _, file in ipairs({ "FeatsData.lua", "FeatsCatMenagerie.lua", "FeatsCatJeu.lua", "Feats.lua" }) do
		local text = Read("QuestCompanion/" .. file) or ""
		if text:find("FEAT_TITLES%[") or text:find("FEAT_TITLES%s*=") then dup[#dup + 1] = file end
	end
	Check("[TIT] titres définis seulement dans FeatsTitles.lua", #dup == 0, table.concat(dup, ", "))
end

-- 5. Cosmétiques des hauts faits : images du client seulement ---------------------------------------------
do
	Say("-- hauts faits : cosmétiques, images du client")
	-- images du client relevées (wago.tools : listfile global et tables
	-- UiTextureAtlas* de Forever, novembre 2026) : chemin -> FileDataID
	local LISTFILE = {
		["interface/icons/spell_frost_chainsofice"] = 135834, ["interface/icons/spell_nature_stranglevines"] = 136100,
		["interface/icons/inv_enchant_prismaticsphere"] = 132872, ["interface/icons/inv_misc_gem_diamond_02"] = 134095,
		["interface/icons/inv_misc_ribbon_01"] = 134411, ["interface/icons/inv_misc_gift_01"] = 134140,
		["interface/icons/achievement_boss_cthun"] = 236407, ["interface/icons/inv_misc_eye_01"] = 133884,
		["interface/icons/inv_crown_14"] = 132770, ["interface/icons/inv_crown_02"] = 132768,
		["interface/icons/spell_fire_fire"] = 135805, ["interface/icons/ability_hunter_pet_wolf"] = 132203,
		["interface/icons/inv_misc_head_dragon_01"] = 134153,
		["interface/worldmap/azeroth/azeroth6"] = 270458, ["interface/minimap/minimap-trackingborder"] = 136430,
		["interface/minimap/ui-minimap-background"] = 136467, ["interface/minimap/minimaparrow"] = 136431,
		["interface/minimap/compassnorthtag"] = 136427,
	}
	local ATLASES = { ["BonusChest-CircleGlow"] = 99, ["garrlanding-circleglow"] = 46 }
	-- sols des sceaux : FileDataID -> chemin du listfile
	local GROUNDS = {
		forest = 187124, nightforest = 188474, canyon = 186915, savanna = 186908, snow = 189051,
		swamp = 188851, desert = 188872, blight = 188688, jungle = 188829, volcanic = 186959,
	}
	local EXPECTED = {
		{ "frame", "feat_eight", "men_types_master" }, { "frame", "feat_prism", "meta_shiny" },
		{ "bg", "feat_atlas", "zone_100_10" }, { "bg", "feat_campfire", "char_camp_25" },
		{ "orn", "feat_chain", "men_boss_1" }, { "orn", "feat_goldstars", "men_stars3_100" },
		{ "orn", "feat_prism_orn", "shiny_3stars" }, { "orn", "feat_compass", "day_travel_1000" },
		{ "orn", "feat_anniversary", "day_days_365" }, { "orn", "feat_eye", "dng_raid_aq40" },
		{ "orn", "feat_wildcrown", "dng_raid_hyjal" },
	}
	local LISTS = { frame = "COMPANION_FRAMES", bg = "COMPANION_BACKGROUNDS", orn = "COMPANION_ORNAMENTS" }
	local function Def(kind, id)
		for _, def in ipairs(NS[LISTS[kind]] or {}) do if def.id == id then return def end end
		return nil
	end
	local fr, en = NS.FEAT_COSMETIC_STRINGS.fr, NS.FEAT_COSMETIC_STRINGS.en
	local chest = {}
	for _, reward in ipairs(NS.COMPANION_REWARDS or {}) do chest[reward.kind .. ":" .. reward.id] = true end
	local bad = {}
	for _, row in ipairs(EXPECTED) do
		local kind, id, feat = row[1], row[2], row[3]
		local def = Def(kind, id)
		local function Bad(why) bad[#bad + 1] = kind .. ":" .. id .. " " .. why end
		if not def then Bad("absent") else
			if def.tier ~= 0 then Bad("palier") end
			if not (def.unlock and def.unlock.feat == feat) then Bad("condition") end
			if not (fr[def.label] and en[def.label] and NS.COMPANION_STRINGS.fr[def.label]) then Bad("libellé") end
			local fd = NS:FeatDef(feat)
			local c = fd and fd.reward and fd.reward.cosmetic
			if not (c and c[1] == kind and c[2] == id) then Bad("haut fait " .. feat) end
			if fd and fd.reward.soon then Bad("encore en attente") end
			if kind == "orn" and not (def.key and NS:DB()[def.key] ~= nil and def.at and (def.icons or def.look)) then Bad("ornement") end
			if chest[kind .. ":" .. id] then Bad("au coffre de zone") end
		end
	end
	local rows = {}
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		if page.id == "companionOrnaments" then for _, r in ipairs(page.rows) do rows[r.key] = true end end
	end
	for _, def in ipairs(NS.FEAT_COSMETICS.orn) do if not rows[def.key] then bad[#bad + 1] = def.id .. " sans réglage" end end
	Check("[HF-E] 11 cosmétiques : catalogue, palier 0, libellés FR/EN, donnés par leur haut fait seulement (jamais au coffre), "
		.. "un réglage par ornement", #bad == 0, table.concat(bad, ", "))
	-- chaque image appelée existe dans le client (relevé du listfile), aucune n'est livrée
	local unknown = {}
	local function Want(path)
		if LISTFILE[tostring(path):gsub("\\", "/"):lower()] == nil then unknown[#unknown + 1] = tostring(path) end
	end
	for _, def in ipairs(NS.FEAT_COSMETICS.orn) do
		for _, name in ipairs(def.icons or {}) do Want("Interface\\Icons\\" .. name) end
	end
	for _, name in pairs(NS.FEAT_FAMILY_ICONS) do
		if name == "Ability_Hunter_Pet_Wolf" or name == "INV_Misc_Head_Dragon_01" then Want("Interface\\Icons\\" .. name) end
	end
	Want(Def("bg", "feat_atlas").texture)
	for _, path in ipairs(NS.FEAT_COSMETIC_CLIENT_FILES) do
		local p = tostring(path):lower()
		if not (p:find("tooltip") or p:find("dialogbox") or p:find("raidtargeting") or p:find("tempportrait")) then Want(path) end
	end
	for _, name in ipairs(NS.FEAT_COSMETIC_ATLASES) do if not ATLASES[name] then unknown[#unknown + 1] = name end end
	local src = Read("QuestCompanion/FeatsCosmetics.lua") or ""
	Check("[HF-E] images : toutes relevées dans le listfile et les atlas du client, aucune texture livrée", #unknown == 0
		and #NS.FEAT_COSMETIC_ATLASES == 2 and not src:find("AddOns\\", 1, true) and not src:find("%.tga")
		and Read("QuestCompanion/Textures/feat_ornaments.tga") == nil and Read("tools/gen_feat_cosmetics.py") == nil,
		table.concat(unknown, ", "))
	local seals = {}
	for _, biome in ipairs(NS.MENAGERIE_BIOMES) do
		local def
		for _, d in ipairs(NS.COMPANION_BACKGROUNDS) do if d.id == "seal_" .. biome then def = d end end
		if not (def and def.texture == GROUNDS[biome] and def.unlock and def.unlock.seal == biome and def.unlock.count == 2
			and def.color and def.color[1] < 0.9) then seals[#seals + 1] = biome end
		if Read("QuestCompanion/Textures/scene_" .. biome .. ".tga") then seals[#seals + 1] = biome .. " (paysage peint)" end
	end
	Check("[HF-E] 10 fonds de sceau : un sol du client (FileDataID), assombri ; paysages peints et leur outil retirés",
		#seals == 0 and Read("tools/gen_seal_scenes.py") == nil and NS.MENAGERIE_SCENE_TEXTURE == nil, table.concat(seals, ", "))
end

-- 6. Textes de récompense : jamais d'identifiant brut ------------------------------------------------------
do
	Say("-- hauts faits : textes de récompense")
	local raw = {}
	for _, def in ipairs(NS:FeatDefs()) do
		local text = NS:FeatRewardText(def)
		if text:find("feat_", 1, true) or text:find("card_", 1, true) or text:find("COMP_", 1, true)
			or text:find("FEAT_", 1, true) then raw[#raw + 1] = def.id .. "=" .. text end
	end
	local function R(id) return NS:FeatRewardText(NS:FeatDef(id)) end
	Check("[HF-E] récompenses : aucun id brut ; fiche reportée « (à venir) » après le titre ; cosmétique par son nom",
		#raw == 0 and R("men_species_500"):find("fond de fiche (à venir)", 1, true) ~= nil
		and R("men_species_500"):find("titre", 1, true) ~= nil and R("zone_seal_ek") == "cadre de fiche (à venir)"
		and R("meta_hero"):find("cadre de fiche (à venir)", 1, true) ~= nil and not R("meta_hero"):find("laurels", 1, true)
		and R("men_boss_1") == "Chaîne du colosse" and R("meta_shiny") == "Cadre prismatique",
		table.concat(raw, " | ") .. " / " .. R("men_species_500"))
	local pending, kinds = 0, true
	for _, def in ipairs(NS:FeatDefs()) do
		if def.reward and def.reward.soon then
			pending = pending + 1
			if def.reward.soon[1] ~= "cardbg" and def.reward.soon[1] ~= "cardframe" then kinds = false end
		end
	end
	local unknown = NS:FeatRewardText({ id = "x", reward = { cosmetic = { "orn", "feat_inconnu" } } })
	Check("[HF-E] en attente : seules les 7 récompenses de fiche (dont les lauriers, la fiche de dresseur) ; id inconnu : "
		.. "« récompense à venir » ; rien en attente : texte d'origine", pending == 7 and kinds
		and NS:FeatDef("men_species_500").reward.cosmetic == nil and NS:FeatDef("men_species_500").reward.soon[2] == "card_census"
		and unknown == "récompense à venir"
		and NS:FeatRewardText({ id = "x", reward = { cosmetic = { "frame", "gilded" } } }) == NS.L.COMP_FRAME_GILDED,
		pending .. " / " .. unknown)
end
