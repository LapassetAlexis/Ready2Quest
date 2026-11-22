-- QuestCompanion 3.7.0 : intégration du lot (les chantiers réunis). Le
-- catalogue complet (lignes, codes, lignes encore en attente, seuils
-- atteignables), puis les chaînes de bout en bout : un relevé de jeu fait
-- bouger un compteur, le compteur donne un haut fait, le haut fait donne sa
-- récompense.
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.QNS

local function Steps()
	local s = { bad = {} }
	function s.ok(label, cond, extra)
		if not cond then s.bad[#s.bad + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	end
	function s.check(name) Check(name, #s.bad == 0, table.concat(s.bad, " ; ")) end
	return s
end

-- Lignes du lot encore en attente : chacune sort de cette table quand l'étape
-- qui livre sa fonction est fusionnée (le haut fait devient alors visible).
local STILL_PENDING = {
	day_week_1 = true, day_week_10 = true, day_week_52 = true, day_swarm_10 = true,     -- étape 4 : le monde bouge
	soc_photo_1 = true,                                                                  -- étape 3 : carte souvenir
	soc_code_1 = true, soc_code_5 = true,                                                -- étape 3 : code de dresseur
	soc_mentor_1 = true, soc_mentor_5 = true, soc_mentor_10 = true,                      -- étape 3 : parrainage
}
local FIRST, LAST, RESERVED = 244, 447, 413    -- codes de la deuxième édition ; 413 : « Chasse en meute », hors du lot

local SAVED = {}
for _, name in ipairs({ "UnitName", "UnitLevel", "date", "InCombatLockdown", "UnitAffectingCombat", "PlaySound" }) do
	SAVED[name] = rawget(_G, name)
end
local SAVED_DORMANT, SAVED_WORDS, SAVED_VERSION = NS.featsDormant, NS.COMMUNITY_WORDS, NS.CommunityVersion

local function Reset()
	ResetWorld()
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end return nil end
	_G.UnitLevel = function() return 20 end
	_G.date = os.date
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.PlaySound = function() return true end
	NS.featsDormant = false
	NS.featPending, NS.featDirty, NS.featEvalAt, NS.featLoginAt, NS.featFlushAt = {}, {}, nil, nil, nil
	NS.featLoginDone = nil
	NS.journalToasts, NS.journalChats = {}, {}
	NS:CompanionData().tutoDone = true
end
local function Restore()
	for name, fn in pairs(SAVED) do _G[name] = fn end
	NS.featsDormant = SAVED_DORMANT
	NS.COMMUNITY_WORDS, NS.CommunityVersion = SAVED_WORDS, SAVED_VERSION
	ResetWorld()
end
local function Got(id) return NS:FeatGot(NS:FeatDef(id)) ~= nil end

-- 1. Le catalogue réuni ----------------------------------------------------------------------------------
do
	Say("-- lot 3.7 : le catalogue réuni")
	Reset()
	local s = Steps()
	local defs = NS:FeatDefs()
	local byCode, new, pending, perCat = {}, 0, {}, {}
	for _, def in ipairs(defs) do
		if byCode[def.n] then s.ok("code " .. def.n .. " en double", false, def.id .. " / " .. byCode[def.n]) end
		byCode[def.n] = def.id
		if def.n >= FIRST then
			new = new + 1
			if def.pending then pending[def.id] = true end
		end
		if not def.pending and def.cat ~= NS.FEAT_FOS then perCat[def.cat] = (perCat[def.cat] or 0) + 1 end
	end
	s.ok("400 lignes : 197 d'avant, 203 de la deuxième édition", #defs == 400 and new == 203, #defs .. " / " .. new)
	for n = FIRST, LAST do
		if n == RESERVED then s.ok("code 413 réservé", byCode[n] == nil, byCode[n])
		elseif not byCode[n] then s.ok("code " .. n .. " absent", false) end
	end
	for id in pairs(STILL_PENDING) do s.ok(id .. " devrait être en attente", pending[id] == true) end
	for id in pairs(pending) do s.ok(id .. " en attente sans raison connue", STILL_PENDING[id] == true) end
	-- chaque catégorie des 16 a des lignes ; les tours de force valent 0 point
	for _, cat in ipairs(NS.FEAT_CATEGORIES) do
		local any = false
		for _, def in ipairs(defs) do if def.cat == cat.id then any = true end end
		s.ok("catégorie " .. cat.id .. " vide", any)
	end
	for _, def in ipairs(defs) do
		if def.cat == NS.FEAT_FOS then s.ok(def.id .. " : 0 point", def.pts == 0) else s.ok(def.id .. " : des points", def.pts > 0) end
	end
	-- tous les cosmétiques promis existent : plus aucune récompense « à venir »
	for _, def in ipairs(defs) do
		local soon = type(def.reward) == "table" and def.reward.soon
		s.ok(def.id .. " : cosmétique encore à venir", not soon, soon and (tostring(soon[1]) .. ":" .. tostring(soon[2])))
	end
	Check("[L37] catalogue : 400 lignes, codes 244 à 447 sans le 413, 16 catégories garnies, lignes en attente = celles des étapes à venir",
		#s.bad == 0, table.concat(s.bad, " ; "))

	-- seuils atteignables : un grand haut fait ne demande jamais plus que ce que la catégorie offre,
	-- une liste ne cite que des lignes visibles, le plus haut palier de points tient dans le total
	s = Steps()
	local total = 0
	for _, def in ipairs(defs) do
		if not def.pending and def.cat ~= NS.FEAT_FOS then total = total + def.pts end
	end
	for _, def in ipairs(defs) do
		local crit = def.crit or {}
		if not def.pending and crit[1] == "meta" then
			if type(crit[2]) == "table" then
				for _, id in ipairs(crit[2]) do
					local member = NS:FeatDef(id)
					s.ok(def.id .. " cite " .. tostring(id), member ~= nil and not member.pending)
				end
			else
				-- (la ligne elle-même ne compte pas pour son propre seuil)
				local have = (perCat[crit[2]] or 0) - (def.cat == crit[2] and 1 or 0)
				s.ok(def.id .. " : " .. tostring(crit[3]) .. " de « " .. tostring(crit[2]) .. " »", (tonumber(crit[3]) or 0) <= have, have)
			end
		elseif not def.pending and crit[1] == "points" then
			s.ok(def.id .. " : " .. tostring(crit[2]) .. " points", (tonumber(crit[2]) or 0) <= total - def.pts, total)
		end
	end
	s.ok("total des points visibles", total >= 6500, total)
	Check("[L37] seuils atteignables : grands hauts faits de catégorie, listes, paliers de points (5 000 au plus haut)",
		#s.bad == 0, table.concat(s.bad, " ; "))
end

-- 2. Du relevé au haut fait ------------------------------------------------------------------------------
do
	Say("-- lot 3.7 : du compteur au haut fait")
	Reset()
	local s = Steps()
	local before = NS:Paillettes()
	s.ok("avant : rien", not Got("init_release") and NS:TallyGet("release") == 0)
	NS:TallyAdd("release")
	NS:FeatEvaluate({ tally = true })
	s.ok("un spécimen relâché : « Rendu à la nature »", Got("init_release"))
	s.ok("ses paillettes (2 pour 5 points)", NS:Paillettes() - before == 2, NS:Paillettes() - before)
	s.ok("et le compteur des paillettes gagnées par les hauts faits", NS:TallyGet("glitter:feat") == 2, NS:TallyGet("glitter:feat"))
	-- un compteur par personnage donne un haut fait du compte
	NS:TallyAdd("wish", 1, "char")
	NS:FeatEvaluate({ tally = true })
	s.ok("une envie comblée : « À tes souhaits »", Got("init_wish"))
	-- un maximum : la série de réussites
	NS:TallyMax("captureStreak", 9)
	NS:FeatEvaluate({ tally = true })
	s.ok("9 de suite : pas encore", not Got("men_streak_10"))
	NS:TallyMax("captureStreak", 10)
	NS:FeatEvaluate({ tally = true })
	s.ok("10 de suite : « Main chaude »", Got("men_streak_10"))
	-- un ensemble : les sortes de friandises
	for _, kind in ipairs({ "a", "b", "c", "d" }) do NS:TallyMark("treatKinds", kind, "char", 5) end
	NS:FeatEvaluate({ tally = true })
	s.ok("4 sortes : pas encore", not Got("comp_treat_all"))
	NS:TallyMark("treatKinds", "e", "char", 5)
	NS:FeatEvaluate({ tally = true })
	s.ok("5 sortes : « Menu dégustation »", Got("comp_treat_all"))
	s.check("[L37] chaîne compteur -> haut fait -> paillettes : nombre, maximum, ensemble, compteur de personnage pour un haut fait de compte")
end

-- 3. La page Communauté donne ses deux hauts faits -------------------------------------------------------
do
	Say("-- lot 3.7 : la page Communauté et ses hauts faits")
	Reset()
	local s = Steps()
	NS.CommunityVersion = function() return "9.9" end
	NS.COMMUNITY_WORDS = { ["9.9"] = NS.CommunityWordHash("9.9", "essai") }
	s.ok("mot faux : rien", (NS:CommunityWordSubmit("autre")) == "wrong" and NS:TallyGet("discordWord") == 0)
	s.ok("mot juste", (NS:CommunityWordSubmit("Essai ")) == "ok" and NS:TallyGet("discordWord") == 1)
	NS:FeatEvaluate({ tally = true })
	s.ok("« Porte ouverte » obtenu", Got("soc_discord"))
	local reward = NS:FeatDef("soc_discord").reward or {}
	local pair = reward.cosmetic
	s.ok("son ornement existe", type(pair) == "table" and pair[1] == "orn" and pair[2] == "feat_worlds", pair and pair[2])
	s.ok("et il est débloqué", NS:CompanionData().unlocked["orn:feat_worlds"] ~= nil)
	NS:TallyAdd("feedback")
	NS:FeatEvaluate({ tally = true })
	s.ok("« Mon grain de sel » obtenu", Got("soc_feedback"))
	s.check("[L37] page Communauté : le mot de la version donne « Porte ouverte » et son ornement, un avis composé donne « Mon grain de sel »")
	NS.COMMUNITY_WORDS, NS.CommunityVersion = SAVED_WORDS, SAVED_VERSION
end

-- 4. Une médaille de zone donne son haut fait ; le compagnon lâche l'indice d'un vrai secret ---------------
do
	Say("-- lot 3.7 : médaille de zone et indice de secret")
	Reset()
	local s = Steps()
	local savedZones, savedMedals, savedResting = rawget(NS, "ZONE_CREATURES"), NS.zoneMedalsDormant, rawget(_G, "IsResting")
	-- une petite zone de 4 espèces : la première capture vaut le bronze (25 %)
	local zones = { [1412] = {} }
	for index = 1, 4 do zones[1412][6000 + index] = { lvl = { 5, 6 }, rank = 0, fr = "Kodo " .. index, en = "Kodo " .. index } end
	NS.ZONE_CREATURES = zones
	NS.menagerieStatic = nil
	NS.zoneMedalsDormant = nil
	NS.ZoneMedalReset()
	NS:FeatCompagnonCacheReset()
	s.ok("avant : aucune zone médaillée", NS:ZoneMedalCounts()[1] == 0 and not Got("zone_medal_bronze_1"))
	local capture = NS:CaptureData()
	capture.creatures[6001] = { name = "Kodo 1", class = "normal", zoneID = 1412, normal = true, at = 1 }
	capture.count = (tonumber(capture.count) or 0) + 1
	capture.serial = (tonumber(capture.serial) or 0) + 1
	NS.ZoneMedalReset()
	-- (comme à la capture : la médaille gagnée est notée et payée)
	local before = NS:Paillettes()
	NS:ZoneMedalCheck(1412, { quiet = true })
	NS:FeatCompagnonCacheReset()
	local level = NS:ZoneMedal(1412)
	s.ok("1 espèce sur 4 : bronze, noté, 3 paillettes", level == 1 and NS:ZoneMedalCounts()[1] == 1 and NS:Paillettes() - before == 3,
		level .. " / " .. NS:ZoneMedalCounts()[1] .. " / " .. (NS:Paillettes() - before))
	NS:FeatEvaluate(nil)
	s.ok("« Premier bronze » obtenu", Got("zone_medal_bronze_1"))
	NS.ZONE_CREATURES, NS.zoneMedalsDormant = savedZones, savedMedals
	NS.menagerieStatic = nil
	NS.ZoneMedalReset()
	-- l'indice d'un secret du catalogue, au repos, dans le créneau des astuces
	_G.IsResting = function() return true end
	NS:DB().companionDiscovery = false
	NS:DB().quiet = false
	NS:DB().quietHintAt = nil
	local tip = NS:DiscoveryPick()
	local line = tip and tip.hint and tip.line or nil
	s.ok("au repos : l'indice d'un vrai secret", type(line) == "string" and line:find("^FEATH_fun_") ~= nil and NS:F(line) ~= line, line)
	NS:DB().quiet = true
	NS:DB().quietHintAt = nil
	local hushed = NS:DiscoveryPick()
	s.ok("mode discret : pas d'indice", not (hushed and hushed.hint))
	NS:DB().quiet, NS:DB().companionDiscovery = false, true
	_G.IsResting = savedResting
	s.check("[L37] médaille de zone -> « Premier bronze » ; indice d'un secret du catalogue au repos, coupé par le mode discret")
	Restore()
end
