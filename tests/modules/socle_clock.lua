-- Socle 2.11.2 / 1.32.2 (fiche 25) : une horloge par addon (ns.Every,
-- ns.Soon, ns.Cancel) au lieu d'une vingtaine d'OnUpdate permanents.
local Check, Say, NS, QNS, Mock = T.Check, T.Say, T.NS, T.QNS, T.Mock

Say("-- fiche 25 : horloge unique")
local clock = NS.clockFrame
local function Tick(seconds, frames)
	for _ = 1, frames or 1 do
		Mock.now = Mock.now + seconds
		clock.scripts.OnUpdate(clock, seconds)
	end
end

Check("[CLK] une horloge par addon", clock ~= nil and QNS.clockFrame ~= nil and QNS.clockFrame ~= clock
	and type(NS.Every) == "function" and type(QNS.Every) == "function")

-- Every : cadence et temps écoulé (comme ns.Throttle)
do
	local runs, steps = 0, {}
	NS.Every("test:every", 0.5, function(step) runs = runs + 1; steps[#steps + 1] = step end)
	Tick(1 / 60, 125)   -- un peu plus de 2 s (somme de flottants)
	Check("[CLK] Every 0,5 s : 4 passages en 2 s à 60 images/s", runs == 4, runs)
	Check("[CLK] Every : temps écoulé depuis le passage précédent", math.abs((steps[2] or 0) - 0.5) < 0.02, steps[2])
	Tick(10)
	Check("[CLK] grand écart (écran de chargement) : un seul passage", runs == 5 and math.abs(steps[5] - 10) < 0.6, runs)
	NS.Cancel("test:every")
	Tick(1, 3)
	Check("[CLK] Cancel : plus de passage", runs == 5)
end

-- Soon : une fois, avancée si déjà posée plus tard
do
	local runs, at = 0, nil
	local start = Mock.now
	NS.Soon("test:soon", 1, function() runs = runs + 1; at = Mock.now - start end)
	NS.Soon("test:soon", 0.2)
	NS.Soon("test:soon", 0.8)
	Tick(0.05, 40)
	Check("[CLK] Soon : un seul passage, à la plus proche échéance", runs == 1 and at and math.abs(at - 0.2) < 0.06, at)
	local n, keys = NS.ClockJobs()
	local listed = false
	for i = 1, n do if keys[i] == "test:soon" then listed = true end end
	Check("[CLK] Soon : retirée après son passage", not listed)
end

-- fn rend false : se retire ; fn rend un nombre : prochain passage
do
	local runs = 0
	NS.Every("test:until", 0, function() runs = runs + 1; return runs < 3 end)
	Tick(1 / 60, 10)
	Check("[CLK] fn rend false : la tâche se retire", runs == 3, runs)
	local beats = 0
	NS.Every("test:adaptive", 1, function() beats = beats + 1; return beats < 4 and 0 or 1 end)
	Tick(1 / 60, 70)
	Check("[CLK] fn rend 0 : chaque image (battement), puis repos", beats == 4, beats)
	NS.Cancel("test:adaptive")
end

-- erreur dans une tâche : notée une fois, les autres tournent
do
	local runs = 0
	local errors = #NS.errors
	NS.Every("test:boom", 0, function() error("boum") end)
	NS.Every("test:after", 0, function() runs = runs + 1 end)
	Tick(1 / 60, 5)
	local noted = 0
	for i = errors + 1, #NS.errors do if NS.errors[i].where == "clock:test:boom" then noted = noted + 1 end end
	Check("[CLK] erreur : notée une fois (clock:clé), les autres tâches tournent", noted == 1 and runs == 5, noted .. "/" .. runs)
	NS.Cancel("test:boom")
	NS.Cancel("test:after")
	for i = #NS.errors, errors + 1, -1 do table.remove(NS.errors, i) end
end

-- coût : rien de dû, une seule fonction Lua par image (l'horloge) et rien
-- d'alloué. Mesuré sur une horloge neuve (Base.lua chargé pour un faux
-- addon), pour ne compter que la sienne.
do
	local ROOT = rawget(_G, "ADDON_ROOT") or "."
	local chunk = loadfile(ROOT .. "/Ready2Quest/Libs/Socle/Base.lua")
	local fake = { APP = { id = "ClockTest", version = "0", slash = {}, coreFiles = {} } }
	local loaded = chunk and pcall(chunk, "ClockTest", fake)
	local own = loaded and fake.Every and fake.Every("idle", 3600, function() end) and fake.clockFrame
	local calls = 0
	if own then
		local function Hook() calls = calls + 1 end
		for _ = 1, 20 do own.scripts.OnUpdate(own, 1 / 60) end
		collectgarbage("collect"); collectgarbage("stop")
		local before = collectgarbage("count")
		debug.sethook(Hook, "c")
		for _ = 1, 600 do own.scripts.OnUpdate(own, 1 / 60) end
		debug.sethook()
		local kb = collectgarbage("count") - before
		collectgarbage("restart")
		Check("[CLK] au repos : un appel par image, rien d'alloué", calls - 1 <= 600 and kb < 0.5,   -- (- 1 : debug.sethook)
			string.format("%d appels, %.2f Ko", calls - 1, kb))
		fake.Cancel("idle")
		Check("[CLK] plus rien de posé : horloge cachée", own.shown == false)
	else
		Check("[CLK] horloge neuve chargée", false)
	end
end

-- les anciennes boucles permanentes passent par l'horloge
do
	local function Has(ns, key)
		local n, keys = ns.ClockJobs()
		for i = 1, n do if keys[i] == key then return true end end
		return false
	end
	-- la sonde du portrait se pose à l'entrée en jeu : on la joue ici (le
	-- module tourne seul, sans les scénarios du cœur qui l'avaient faite)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	local r2q = { "core:exit", "portrait", "camp", "death", "aggro" }
	local qc = { "companion", "companion:aggro", "travel", "advice", "group", "shiny", "capture", "effects",
		"daily", "notify", "trainer", "feats:minute" }
	local missing = {}
	for _, key in ipairs(r2q) do if not Has(NS, key) then missing[#missing + 1] = "R2Q " .. key end end
	for _, key in ipairs(qc) do if not Has(QNS, key) then missing[#missing + 1] = "QC " .. key end end
	Check("[CLK] vérifications espacées : tâches de l'horloge", #missing == 0, table.concat(missing, ", "))
	local permanent = {}
	for _, name in ipairs({ "eventFrame", "campEventFrame", "aggroEventFrame", "deathEvents", "spellRanksEventFrame" }) do
		local f = NS[name]
		if f and f.scripts and f.scripts.OnUpdate then permanent[#permanent + 1] = "R2Q " .. name end
	end
	for _, name in ipairs({ "adviceEventFrame", "groupEventFrame", "dailyEventFrame", "journalEventFrame",
		"notifyEventFrame", "trainerEventFrame", "featEventFrame" }) do
		local f = QNS[name]
		if f and f.scripts and f.scripts.OnUpdate then permanent[#permanent + 1] = "QC " .. name end
	end
	Check("[CLK] plus d'OnUpdate sur les cadres d'événements", #permanent == 0, table.concat(permanent, ", "))
end

-- échéances posées à la demande : sorts (R2Q), bandeau du carnet (QC)
do
	local checks, saved = 0, NS.SpellRanksCheck
	NS.SpellRanksCheck = function() checks = checks + 1 end
	NS.spellRanksDueAt = nil
	NS.spellRanksEventFrame.script(NS.spellRanksEventFrame, "LEARNED_SPELL_IN_TAB")
	Tick(0.25, 3)
	Check("[CLK] sorts : rien avant l'échéance", checks == 0)
	Tick(0.25, 2)
	Check("[CLK] sorts : vérifiés une fois à l'échéance", checks == 1 and NS.spellRanksDueAt == nil, checks)
	NS.SpellRanksCheck = saved
end
