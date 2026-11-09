-- Audit de performance (docs/AUDIT-PERF.md) : les raccourcis ajoutés rendent
-- exactement ce que l'ancien chemin rendait, et se refont quand il le faut.
local Check, Say, NS, QNS, Mock = T.Check, T.Say, T.NS, T.QNS, T.Mock

-- 1. Événements d'unité filtrés à la source ---------------------------------------------------------
do
	Say("-- audit perf : UNIT_AURA du joueur seulement")
	local seen = {}
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(_, event, unit) seen[#seen + 1] = event .. ":" .. tostring(unit) end)
	Check("[PERF] RegisterGameEvent : UNIT_AURA accepté", NS.RegisterGameEvent(frame, "UNIT_AURA") == true
		and frame.events.UNIT_AURA == true)
	Mock:Fire("UNIT_AURA", "target")
	Mock:Fire("UNIT_AURA", "nameplate4")
	Mock:Fire("UNIT_AURA", "player")
	Check("[PERF] UNIT_AURA : seul le joueur arrive", #seen == 1 and seen[1] == "UNIT_AURA:player", table.concat(seen, ","))
	frame:UnregisterEvent("UNIT_AURA")
	Mock:Fire("UNIT_AURA", "player")
	Check("[PERF] désabonné : plus rien", #seen == 1)
	-- client sans RegisterUnitEvent : repli sur RegisterEvent, le filtre reste aux gestionnaires
	local old = frame.RegisterUnitEvent
	frame.RegisterUnitEvent = nil
	Check("[PERF] repli RegisterEvent", NS.RegisterGameEvent(frame, "UNIT_AURA") == true and frame.events.UNIT_AURA == true
		and not (frame.unitFilter and frame.unitFilter.UNIT_AURA))
	frame.RegisterUnitEvent = old
	frame:UnregisterEvent("UNIT_AURA")
	Check("[PERF] autre événement : RegisterEvent ordinaire", NS.RegisterGameEvent(frame, "PLAYER_LOGIN") == true
		and not (frame.unitFilter and frame.unitFilter.PLAYER_LOGIN))
	Check("[PERF] R2Q : UNIT_AURA du joueur seulement", NS.eventFrame.unitFilter
		and NS.eventFrame.unitFilter.UNIT_AURA and NS.eventFrame.unitFilter.UNIT_AURA.player == true)
	Check("[PERF] camp, stats : idem", NS.campEventFrame.unitFilter.UNIT_AURA.player == true
		and NS.statsEventFrame.unitFilter.UNIT_STATS.player == true)
	local hub = QNS.featEventFrame
	Check("[PERF] QC hauts faits : idem (si abonnés)", not hub.events.UNIT_AURA or hub.unitFilter.UNIT_AURA.player == true)
end

-- 2. Chaînes ---------------------------------------------------------------------------------------
do
	Say("-- audit perf : AsciiLower par table")
	local cases = {
		{ "Bénédiction De PUISSANCE", "bénédiction de puissance" },
		{ "  Well   Fed\t", "well fed" },
		{ "Aura\194\160de Dévotion", "aura de dévotion" },
		{ "ÉLAN", "Élan" },
		{ "", "" },
	}
	local ok = true
	for _, case in ipairs(cases) do
		if NS.AsciiLower(case[1]) ~= case[2] then ok = false; Say("   " .. case[1] .. " -> " .. NS.AsciiLower(case[1])) end
	end
	Check("[PERF] AsciiLower : mêmes résultats", ok)
	Check("[PERF] AsciiLower : non-chaîne rendue telle quelle", NS.AsciiLower(nil) == nil and NS.AsciiLower(5) == 5)
	Check("[PERF] famille de buff gardée et stable", NS.BuffFamily("Bénédiction de puissance")
		== NS.BuffFamily("Bénédiction de puissance") and NS.BuffFamily(nil) == nil)
end

-- 3. Cartes ----------------------------------------------------------------------------------------
do
	Say("-- audit perf : chaîne de cartes gardée")
	Mock.world.maps[97001] = { mapID = 97001, name = "Sous-carte", parentMapID = 97002 }
	Mock.world.maps[97002] = { mapID = 97002, name = "Zone", parentMapID = 0 }
	local a = NS:MapChain(97001)
	Check("[PERF] MapChain : carte puis parent", #a == 2 and a[1] == 97001 and a[2] == 97002)
	Check("[PERF] MapChain : gardée (même table)", NS:MapChain(97001) == a)
	-- carte dont le client n'a pas encore les infos : pas gardée
	local b = NS:MapChain(97003)
	Mock.world.maps[97003] = { mapID = 97003, name = "Tardive", parentMapID = 97002 }
	local c = NS:MapChain(97003)
	Check("[PERF] MapChain : incomplète relue", #b == 1 and #c == 2 and c[2] == 97002)
	Mock.world.maps[97001], Mock.world.maps[97002], Mock.world.maps[97003] = nil, nil, nil
end

-- 4. Motifs gardés tant que les chaînes du client ne bougent pas ----------------------------------
do
	Say("-- audit perf : MemoGlobals")
	local builds = 0
	_G.QC_PERF_FORMAT = "a"
	local get = NS.MemoGlobals({ "QC_PERF_FORMAT" }, function() builds = builds + 1; return { _G.QC_PERF_FORMAT } end)
	local first = get()
	Check("[PERF] construit une fois", get() == first and builds == 1 and first[1] == "a")
	_G.QC_PERF_FORMAT = "b"
	Check("[PERF] globale changée : reconstruit", get()[1] == "b" and builds == 2)
	_G.QC_PERF_FORMAT = nil
	Check("[PERF] globale retirée : reconstruit", get()[1] == nil and builds == 3)
	local xp, named = NS:ParseCombatXP("Gnoll meurt, vous gagnez 45 points d'expérience.")
	local xp2 = NS:ParseCombatXP("Gnoll meurt, vous gagnez 46 points d'expérience.")
	Check("[PERF] ParseCombatXP : deux messages de suite", xp == 45 and named == true and xp2 == 46,
		tostring(xp) .. "/" .. tostring(xp2))
	Check("[PERF] ParseCombatXP : autre texte, nil", NS:ParseCombatXP("Bonjour") == nil)
end

-- 5. Erreurs bornées -------------------------------------------------------------------------------
do
	Say("-- audit perf : RecordError bornée")
	local saved, savedPrint = NS.errors, _G.print
	NS.errors, NS.errorsDropped = {}, nil
	_G.print = function() end
	for i = 1, NS.ERRORS_MAX + 7 do NS:RecordError("perf", "erreur " .. i) end
	NS:RecordError("perf", "erreur 1")
	Check("[PERF] erreurs : au plus ERRORS_MAX, le reste compté", #NS.errors == NS.ERRORS_MAX and NS.errorsDropped == 7)
	NS.errors, NS.errorsDropped, _G.print = saved, nil, savedPrint
end

-- 6. Carnet : la molette ----------------------------------------------------------------------------
do
	Say("-- audit perf : molette du carnet")
	local frame = QNS.EnsureJournalWindow and QNS:EnsureJournalWindow()
	if frame then
		local during
		local refresh = QNS.RefreshJournal
		QNS.RefreshJournal = function(self) during = frame.scrollOnly end
		QNS:ScrollJournal(-1)
		QNS.RefreshJournal = refresh
		Check("[PERF] ScrollJournal : scrollOnly pendant, effacé après", during == true and frame.scrollOnly == nil)
		QNS.RefreshJournal = function() error("boum") end
		local ok = pcall(QNS.ScrollJournal, QNS, 1)
		QNS.RefreshJournal = refresh
		Check("[PERF] ScrollJournal : effacé même sur erreur", not ok and frame.scrollOnly == nil)
	end
end

-- 7. Conseils : rafales regroupées ----------------------------------------------------------------
do
	Say("-- audit perf : conseils en rafale")
	local calls = 0
	local evaluate = QNS.AdviceEvaluate
	QNS.AdviceEvaluate = function() calls = calls + 1 end
	QNS.adviceNextAt = Mock.now + 100
	for _ = 1, 5 do QNS.ADVICE_HANDLERS.QUEST_LOG_UPDATE() end
	QNS.ADVICE_HANDLERS.BAG_UPDATE_DELAYED()
	Check("[PERF] QUEST_LOG_UPDATE : pas d'examen immédiat, poll avancé", calls == 0
		and math.abs(QNS.adviceNextAt - (Mock.now + QNS.ADVICE_SOON)) < 1e-6)
	QNS.ADVICE_HANDLERS.PLAYER_REGEN_ENABLED()
	Check("[PERF] fin de combat : examen direct", calls == 1)
	QNS.AdviceEvaluate = evaluate
	QNS.adviceNextAt = nil
end
