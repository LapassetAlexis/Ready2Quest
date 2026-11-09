-- 2.11.1 / 1.32.1 : deux raccourcis de performance, même résultat qu'avant.
--   * infobulle d'unité : une espèce lue (BestiarySpeciesOne), plus toute la zone ;
--   * ns:AtCamp : une lecture du client par image (GetTime), pas trois par UNIT_AURA.
local Check, Say, NS, QNS, Mock = T.Check, T.Say, T.NS, T.QNS, T.Mock

local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do if b[k] ~= v then return false end end
	for k, v in pairs(b) do if a[k] ~= v then return false end end
	return true
end

-- 1. Infobulle : une espèce ----------------------------------------------------------------------
do
	Say("-- 2.11.1 : infobulle du bestiaire, une espèce lue")
	local ZONE = 990001
	local savedAll = rawget(QNS, "ZONE_CREATURES")
	local savedOn, savedZone, savedFaction = rawget(QNS, "CompanionOn"), rawget(QNS, "JournalZone"), rawget(QNS, "BestiaryFaction")
	-- zone livrée de 208 espèces (la plus grosse, Les Tarides) : amicales A, H, AH, neutres
	local zone, factions = {}, { nil, "A", "H", "AH" }
	for i = 1, 208 do
		zone[5000 + i] = { en = "Mob " .. i, fr = "Bête " .. i, rank = i % 7 == 0 and 1 or 0,
			lvl = { 10, 12 }, f = factions[i % 4 + 1] }
	end
	QNS.ZONE_CREATURES = { [ZONE] = zone }
	-- apprises : une de la table (rang livré prioritaire), une amicale filtrée, une hors table
	QNS:BestiaryData()[ZONE] = {
		[5007] = { name = "Vu", class = "normal", type = "Bête", seen = true, killed = 3, level = 11 },
		[5002] = { name = "Ami", class = "normal", type = "Humanoïde", seen = true, level = 10 },
		[9999] = { name = "Hors table", class = "rare", type = "Bête", seen = true, killed = 1, level = 14 },
	}
	local ids = { 5001, 5002, 5003, 5004, 5007, 5014, 9999, 424242 }
	for _, faction in ipairs({ "A", "H", false }) do
		QNS.BestiaryFaction = function() return faction or nil end
		local all, ok, bad = QNS:BestiarySpecies(ZONE), true, nil
		for _, npcID in ipairs(ids) do
			if not Same(QNS:BestiarySpeciesOne(ZONE, npcID), all[npcID]) then ok, bad = false, npcID end
		end
		for npcID in pairs(zone) do
			if not Same(QNS:BestiarySpeciesOne(ZONE, npcID), all[npcID]) then ok, bad = false, npcID end
		end
		Check("[PERF 2.11.1] BestiarySpeciesOne = BestiarySpecies[npc] (faction " .. tostring(faction) .. ")", ok, tostring(bad))
	end
	QNS.BestiaryFaction = function() return "A" end
	local one = QNS:BestiarySpeciesOne(ZONE, 5007)
	Check("[PERF 2.11.1] fusion : rang livré, mises à mort apprises", one and one.class == "elite" and one.killed == 3
		and one.static == true and one.name == "Vu", one and one.class)
	Check("[PERF 2.11.1] amicale pour toi, jamais vue : rien", QNS:BestiarySpeciesOne(ZONE, 5003) == nil)
	Check("[PERF 2.11.1] sans zone ni npc : rien", QNS:BestiarySpeciesOne(nil, 5001) == nil
		and QNS:BestiarySpeciesOne(ZONE, nil) == nil)

	-- allocations par survol (200 survols, ramasse-miettes arrêté)
	QNS.CompanionOn = function() return true end
	QNS.JournalZone = function() return ZONE end
	local guid = "Creature-0-4378-1-12-5004-00001A2B3C"
	local function Measure()
		collectgarbage("collect"); collectgarbage("stop")
		local before = collectgarbage("count")
		for _ = 1, 200 do QNS:BestiaryTooltipLine(guid, 11) end
		local kb = (collectgarbage("count") - before) / 200
		collectgarbage("restart")
		return kb
	end
	local lineAfter = QNS:BestiaryTooltipLine(guid, 11)
	local after = Measure()
	local fast = QNS.BestiarySpeciesOne
	QNS.BestiarySpeciesOne = function(self, z, n) return self:BestiarySpecies(z)[n] end   -- l'ancien chemin
	local lineBefore = QNS:BestiaryTooltipLine(guid, 11)
	local before = Measure()
	QNS.BestiarySpeciesOne = fast
	Say(string.format("   allocations par survol : avant %.2f Ko, après %.2f Ko", before, after))
	Check("[PERF 2.11.1] infobulle : même ligne qu'avant", lineAfter ~= nil and lineAfter == lineBefore, tostring(lineAfter))
	Check("[PERF 2.11.1] infobulle : moins de 5 Ko par survol (zone de 208 espèces)", after < 5, string.format("%.2f", after))
	Check("[PERF 2.11.1] infobulle : au moins 10 fois moins alloué qu'avant", after * 10 < before,
		string.format("%.2f / %.2f", after, before))

	QNS:BestiaryData()[ZONE] = nil
	QNS.ZONE_CREATURES, QNS.CompanionOn, QNS.JournalZone, QNS.BestiaryFaction = savedAll, savedOn, savedZone, savedFaction
end

-- 2. AtCamp : une lecture par image -------------------------------------------------------------
do
	Say("-- 2.11.1 : AtCamp lu une fois par image")
	local CAMP = NS.CAMP_AURAS[1]
	local savedRead, savedAura = C_UnitAuras.GetPlayerAuraBySpellID, Mock.world.auras[CAMP]
	local reads = 0
	C_UnitAuras.GetPlayerAuraBySpellID = function(id, ...) if id == CAMP then reads = reads + 1 end return savedRead(id, ...) end
	Mock.world.auras[CAMP] = { name = "Campfire Nearby", duration = 0 }
	Mock:Advance(1)
	local a, b, c = NS:AtCamp(), NS:AtCamp(), NS:AtCamp()
	Check("[PERF 1.32.1] AtCamp trois fois, même image : une lecture", a == true and b == true and c == true and reads == 1,
		tostring(reads))
	Mock.world.auras[CAMP] = nil
	Check("[PERF 1.32.1] même image : valeur gardée", NS:AtCamp() == true and reads == 1)
	Mock:Advance(0.05)
	Check("[PERF 1.32.1] image suivante : relue", NS:AtCamp() == false and reads == 2, tostring(reads))
	Mock.world.auras[CAMP] = { name = "Campfire Nearby", duration = 0 }
	NS.atCampAt = nil
	Check("[PERF 1.32.1] atCampAt = nil : relue tout de suite", NS:AtCamp() == true and reads == 3)
	Check("[PERF 1.32.1] QC : cache à lui", QNS:AtCamp() == true and reads == 4 and QNS:AtCamp() == true and reads == 4)
	-- un UNIT_AURA du joueur : Core, cadre du camp, zone sûre… une seule lecture pour R2Q
	Mock:Advance(1)
	NS.wasAtCamp, NS.atCampAt, QNS.atCampAt = false, nil, nil
	reads = 0
	local savedHook = Mock.OnNewFrame
	Mock.OnNewFrame = nil
	Mock:Fire("UNIT_AURA", "player")
	Mock.OnNewFrame = savedHook
	local afterReads = reads
	-- l'ancien AtCamp (sans cache), pour la mesure « avant »
	local cached = NS.AtCamp
	NS.AtCamp = function(self)
		for _, spellID in ipairs(self.CAMP_AURAS) do
			local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
			if ok and aura then return true end
		end
		return false
	end
	Mock:Advance(1)
	NS.wasAtCamp, QNS.atCampAt = false, nil
	reads = 0
	Mock.OnNewFrame = nil
	Mock:Fire("UNIT_AURA", "player")
	Mock.OnNewFrame = savedHook
	NS.AtCamp = cached
	Say(string.format("   lectures de l'aura du camp par UNIT_AURA (R2Q + QC) : avant %d, après %d", reads, afterReads))
	Check("[PERF 1.32.1] UNIT_AURA du joueur : au plus une lecture par addon", afterReads >= 1 and afterReads <= 2
		and afterReads < reads, afterReads .. " / " .. reads)
	Mock.world.auras[CAMP] = savedAura
	C_UnitAuras.GetPlayerAuraBySpellID = savedRead
	NS.atCampAt, QNS.atCampAt = nil, nil
	Mock:Fire("UNIT_AURA", "player")
end
