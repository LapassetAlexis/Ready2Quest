-- Compagnon : volume et cohérence des répliques (CompanionLines.lua,
-- PersonalityLines.lua). Chaque réservoir garde les mêmes « %s » / « %d »
-- que sa première ligne (là où le nom est facultatif — PNJ, ville… — une
-- ligne peut s'en passer, jamais en demander plus) ; pas de doublon ; des
-- bulles courtes ; assez de lignes pour ne pas tourner en rond.
local Check, Say, NS = T.Check, T.Say, T.QNS

local function Specs(text)
	local list = {}
	for spec in tostring(text or ""):gsub("%%%%", ""):gmatch("%%[sd]") do list[#list + 1] = spec end
	return table.concat(list, ",")
end

-- longueur en caractères (UTF-8), pas en octets
local function Chars(text)
	return select(2, tostring(text or ""):gsub("[^\128-\191]", ""))
end

-- réservoirs dont l'argument EST le message (niveau, stade, tampon…) : toutes
-- les lignes le reprennent, comme la première
local STRICT = { HELLO = true, LEVEL = true, READY = true, CHEST = true, EVOLVE = true, UNLOCK = true,
	STAMP = true, RECALL = true, ANNIV = true, GOAL = true, GOAL_STAGE = true }
local function Strict(pool)
	return STRICT[pool] or pool:find("^ADVICE_") ~= nil or pool:find("^GROUP_") ~= nil
end

do
	Say("-- répliques : arguments, doublons, longueur, volume")
	local fr, en = NS.COMPANION_LINE_STRINGS.fr, NS.COMPANION_LINE_STRINGS.en
	local bad, long, dupes, seen = {}, {}, {}, {}
	for pool, keys in pairs(NS.COMPANION_POOLS) do
		local base, trait = pool:match("^(.-)__(.+)$")
		local ref = Specs(fr[keys[1]])
		local widest = ref
		for _, key in ipairs(keys) do
			if #Specs(fr[key]) > #widest then widest = Specs(fr[key]) end
		end
		for _, key in ipairs(keys) do
			local spec = Specs(fr[key])
			local ok
			if base == "NOTICE" then
				-- remarque de caractère : au plus les arguments de la première
				ok = ref:sub(1, #spec) == spec
			elseif base then
				-- version d'un caractère : sans argument, ou ceux du réservoir commun
				local shared = NS.COMPANION_POOLS[base]
				ok = spec == "" or (shared ~= nil and spec == Specs(fr[shared[1]]))
			elseif Strict(pool) then
				ok = spec == ref
			else
				-- argument facultatif (nom du PNJ, de la ville, 1re bulle du
				-- tutoriel…) : jamais plus, ni d'autres, que la ligne la plus fournie
				ok = widest:sub(1, #spec) == spec
			end
			if not ok then bad[#bad + 1] = key end
			if Specs(en[key]) ~= spec then bad[#bad + 1] = key .. " (fr/en)" end
			-- astuces et tutoriels (TUTO, TUTO_MENAGERIE…) : 130
			local limit = (pool == "TIP" or pool:find("^TUTO") ~= nil) and 130 or 100
			if Chars(fr[key]) > limit or Chars(en[key]) > limit then long[#long + 1] = key end
			local text = fr[key]
			if text and seen[text] and seen[text] ~= key then dupes[#dupes + 1] = key .. "=" .. seen[text] end
			if text then seen[text] = seen[text] or key end
		end
	end
	table.sort(bad)
	table.sort(long)
	table.sort(dupes)
	Check("[LINES] chaque ligne garde les arguments de son réservoir", #bad == 0, table.concat(bad, ", "))
	Check("[LINES] bulles courtes (100 caractères, 130 pour astuces et tutoriel)", #long == 0, table.concat(long, ", "))
	Check("[LINES] aucune réplique en double", #dupes == 0, table.concat(dupes, ", "))

	-- volume : les situations fréquentes ont de quoi varier toute une soirée
	local frequent = { KILL = 20, DEAD = 12, REZ = 12, IDLE = 15, LOOT = 12, QUEST = 12, LEVEL = 10, EAT = 10, VIEW = 10 }
	local short = {}
	for pool, n in pairs(frequent) do
		if #(NS.COMPANION_POOLS[pool] or {}) < n then short[#short + 1] = pool .. "=" .. #(NS.COMPANION_POOLS[pool] or {}) end
	end
	-- chaque caractère : au moins 4 versions par situation (sauf l'annonce)
	for name, keys in pairs(NS.PERSONALITY_POOLS) do
		if not name:find("^FORMED__") and #keys < 4 then short[#short + 1] = name .. "=" .. #keys end
	end
	table.sort(short)
	Check("[LINES] assez de répliques par situation et par caractère", #short == 0, table.concat(short, ", "))
	local total = 0
	for _, keys in pairs(NS.PERSONALITY_POOLS) do total = total + #keys end
	Check("[LINES] répliques de caractère : 1000 et plus", total >= 1000, total)

	-- tirage : sur 40 bulles d'affilée, beaucoup de lignes différentes
	NS.companionRT = nil
	local distinct, n = {}, 0
	for _ = 1, 40 do
		local key = NS:CompanionPick("KILL")
		if key and not distinct[key] then distinct[key] = true; n = n + 1 end
	end
	Check("[LINES] 40 victoires : au moins 12 répliques différentes", n >= 12, n)
	NS.companionRT = nil
end
