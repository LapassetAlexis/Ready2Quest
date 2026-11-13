-- Passe perf de Ready2Quest (docs/AUDIT-PERF-R2Q.md) :
--   * abonnements à la demande (ns.FrameGate, Core.lua) : un module coupé, un
--     événement qui ne sert qu'en voyage, fenêtre ouverte ou hors combat, n'est
--     plus abonné ; chaque chemin de retour est joué (réglage, commande,
--     sortie de combat, /reload en combat, filet) ;
--   * chemins fréquents sans table ni chaîne refaite (marques d'aggro, liserés
--     des rangs de sorts, messages d'erreur, zone sûre, sonde du portrait), et
--     chaque raccourci rend ce que rendait l'ancien chemin.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock

-- Globales du client remplacées ici, restaurées en fin de fichier
local NAMES = { "InCombatLockdown", "UnitAffectingCombat", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitCanAttack",
	"UnitCreatureType", "UnitReaction", "UnitLevel", "UnitGUID", "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown",
	"C_NamePlate", "CheckInteractDistance", "GetActionInfo", "GetSpellInfo", "GetSpellSubtext", "GetNumSpellTabs",
	"GetSpellTabInfo", "GetSpellBookItemInfo", "C_Spell", "C_SpellBook", "ERR_INV_FULL", "ERR_BAG_FULL", "IsResting",
	"UnitIsPVPSanctuary", "ActionButton1", "ActionButton2" }
local saved = {}
for _, name in ipairs(NAMES) do saved[name] = rawget(_G, name) end
saved.inRange = C_Item.IsItemInRange

local P = { W = { combat = false } }   -- une seule locale pour les aides

local failed = {}
local function Want(label, ok, extra)
	if not ok then failed[#failed + 1] = label .. (extra ~= nil and (" (" .. tostring(extra) .. ")") or "") end
	return ok
end
local function Verdict(name) Check(name, #failed == 0, table.concat(failed, " | ")); failed = {} end

-- abonné ? (la maquette range les événements du cadre dans frame.events)
function P.On(frame, event) return frame ~= nil and frame.events ~= nil and frame.events[event] == true end
function P.Job(key)
	local count, list = NS.ClockJobs()
	for i = 1, count do if list[i] == key then return true end end
	return false
end
function P.Reset()
	ResetWorld()
	P.W.combat = false
	_G.InCombatLockdown = function() return P.W.combat == true end
	_G.UnitAffectingCombat = function(unit) return unit == "player" and P.W.combat == true end
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
end
-- allocations (Ko) de n appels de fn, ramasse-miettes arrêté
function P.Kb(n, fn)
	collectgarbage("collect"); collectgarbage("stop")
	local before = collectgarbage("count")
	for _ = 1, n do fn() end
	local kb = collectgarbage("count") - before
	collectgarbage("restart")
	return kb
end

-- 1. La mécanique : abonné au chargement, synchro, horloge, want en erreur ---------------------------
do
	Say("-- R2Q perf : abonnements à la demande (mécanique)")
	P.Reset()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("R2Q_TEST_A")
	frame:RegisterEvent("R2Q_TEST_B")
	local state, ticks, paused, resumed = true, 0, 0, 0
	NS.FrameGate("test:gate", {
		frame = frame, events = { "R2Q_TEST_A" },
		clock = { "test:gate", 1, function() ticks = ticks + 1 end },
		want = function() return state end,
		onPause = function() paused = paused + 1 end,
		onResume = function() resumed = resumed + 1 end,
	})
	NS:SyncEventGate("test:gate")
	Want("état voulu inchangé : rien ne bouge", P.On(frame, "R2Q_TEST_A") and paused == 0 and resumed == 0)
	state = false
	NS:SyncEventGates()
	Want("coupée : désabonnée, horloge retirée, onPause une fois", not P.On(frame, "R2Q_TEST_A")
		and P.On(frame, "R2Q_TEST_B") and not P.Job("test:gate") and paused == 1)
	NS:SyncEventGates()
	Want("seconde synchro sans changement : onPause pas rejoué", paused == 1)
	state = true
	NS:SyncEventGates()
	Mock:Advance(1.05)
	Want("rouverte : réabonnée, horloge reposée et qui tourne, onResume une fois", P.On(frame, "R2Q_TEST_A")
		and P.Job("test:gate") and ticks >= 1 and resumed == 1, ticks)
	state = false
	NS:SyncEventGates()
	NS:ResetEventGates()
	Want("ResetEventGates : tout réabonné (état du chargement), hors combat", P.On(frame, "R2Q_TEST_A")
		and P.Job("test:gate") and NS.gateCombat == nil)
	-- want en erreur : dans le doute, on écoute ; l'erreur est notée
	local errors = #NS.errors
	NS.eventGates["test:gate"].want = function() error("boum") end
	NS.eventGates["test:gate"].on = false
	NS:SyncEventGate("test:gate")
	Want("want en erreur : abonné, erreur notée", P.On(frame, "R2Q_TEST_A") and #NS.errors == errors + 1)
	for i = #NS.errors, errors + 1, -1 do table.remove(NS.errors, i) end
	-- retirée pour la suite
	NS.eventGates["test:gate"] = nil
	for i = #NS.eventGateOrder, 1, -1 do
		if NS.eventGateOrder[i] == "test:gate" then table.remove(NS.eventGateOrder, i) end
	end
	NS.Cancel("test:gate")
	Verdict("[R2Q PERF] EventGate : synchro au changement seulement, horloge suivie, état du chargement, want en erreur = abonné")
end

-- 2. Module coupé : plus abonné ; chaque chemin de retour ----------------------------------------------
do
	Say("-- R2Q perf : modules coupés")
	P.Reset()
	-- [module] = { clé, cadre, événements, tâche d'horloge éventuelle }
	local MODULES = {
		{ "aggro", "aggroEnabled", NS.aggroEventFrame, { "NAME_PLATE_UNIT_ADDED", "MODIFIER_STATE_CHANGED", "GET_ITEM_INFO_RECEIVED" }, "aggro" },
		{ "bagspace", "bagspaceEnabled", NS.bagspaceEventFrame, { "UI_ERROR_MESSAGE", "LOOT_OPENED" } },
		{ "lootroom", "lootroomEnabled", NS.lootRoomEventFrame, { "LOOT_OPENED", "UI_ERROR_MESSAGE" } },
		{ "pace", "paceEnabled", NS.paceEventFrame, { "PLAYER_XP_UPDATE", "CHAT_MSG_COMBAT_XP_GAIN", "QUEST_TURNED_IN" } },
		{ "spellranks", "spellranksEnabled", NS.spellRanksEventFrame, { "ACTIONBAR_SLOT_CHANGED", "UPDATE_SHAPESHIFT_FORM",
			"SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" } },
		{ "camp", "campEnabled", NS.campEventFrame, { "UNIT_AURA" }, "camp" },
	}
	local function State(m)
		for _, event in ipairs(m[4]) do if not P.On(m[3], event) then return false end end
		if m[5] and not P.Job(m[5]) then return false end
		return true
	end
	local function Off(m)
		for _, event in ipairs(m[4]) do if P.On(m[3], event) then return false end end
		if m[5] and P.Job(m[5]) then return false end
		return true
	end
	for _, m in ipairs(MODULES) do Want(m[1] .. " : abonné, module actif", State(m)) end
	-- /r2q module <id> off|on (commande)
	for _, m in ipairs(MODULES) do
		NS:HandleCommand("module " .. m[1] .. " off")
		Want(m[1] .. " : /r2q module off -> désabonné", Off(m))
		NS:HandleCommand("module " .. m[1] .. " on")
		Want(m[1] .. " : /r2q module on -> réabonné", State(m))
	end
	-- interrupteur des réglages (ToggleModuleKey), puis carte « bool » (écriture + RefreshOptions)
	for _, m in ipairs(MODULES) do
		NS:ToggleModuleKey(m[2])
		local off = Off(m)
		NS:ToggleModuleKey(m[2])
		Want(m[1] .. " : interrupteur des réglages, aller-retour", off and State(m))
		NS:DB()[m[2]] = false
		NS:RefreshOptions()
		off = Off(m)
		NS:DB()[m[2]] = true
		NS:RefreshOptions()
		Want(m[1] .. " : carte de réglage (RefreshOptions), aller-retour", off and State(m))
	end
	-- /r2q off coupe tout ce qui dépend de l'interrupteur général
	NS:HandleCommand("off")
	local allOff = true
	for _, m in ipairs(MODULES) do if m[1] ~= "aggro" and not Off(m) then allOff = false end end
	NS:HandleCommand("on")
	local allOn = true
	for _, m in ipairs(MODULES) do if not State(m) then allOn = false end end
	Want("/r2q off puis on : modules suivis, puis rouverts", allOff and allOn)
	-- filet : un réglage changé sans passer par une synchro est rattrapé
	NS:DB().paceEnabled = false
	Mock:Advance(NS.GATE_SAFETY + 0.1)
	local caught = not P.On(NS.paceEventFrame, "CHAT_MSG_COMBAT_XP_GAIN")
	NS:DB().paceEnabled = true
	Mock:Advance(NS.GATE_SAFETY + 0.1)
	Want("filet : réglage changé en douce, rattrapé dans les GATE_SAFETY s", caught
		and P.On(NS.paceEventFrame, "CHAT_MSG_COMBAT_XP_GAIN"))
	Verdict("[R2Q PERF] module coupé : désabonné ; commande, interrupteur, carte de réglage, /r2q on|off et filet le rouvrent")

	-- ce que faisait le premier événement reçu module coupé est fait à l'arrêt
	P.Reset()
	NS:PaceOnXP()
	local tracked = NS.pace ~= nil
	NS:HandleCommand("module pace off")
	Want("rythme : suivi oublié à l'arrêt", tracked and NS.pace == nil)
	NS:HandleCommand("module pace on")
	NS:DB().campCountdown = true
	local camp = NS:EnsureCampFrame()
	if camp then camp:Show() end
	NS.campArrivedAt = 5
	NS:HandleCommand("module camp off")
	Want("camp : cadre rangé, arrivée oubliée", (not camp or not camp:IsShown()) and NS.campArrivedAt == nil)
	NS:HandleCommand("module camp on")
	NS:DB().campCountdown = false
	NS:RefreshOptions()
	Want("camp : décompte coupé seul -> plus d'UNIT_AURA ni de tâche", not P.On(NS.campEventFrame, "UNIT_AURA")
		and not P.Job("camp"))
	NS:DB().campCountdown = true
	NS:RefreshOptions()
	Want("camp : décompte rallumé -> rouvert", P.On(NS.campEventFrame, "UNIT_AURA") and P.Job("camp"))
	Verdict("[R2Q PERF] arrêt d'un module : rythme oublié, cadre du camp rangé, décompte suivi seul")
end

-- 3. Combat : aggro et UNIT_AURA du camp coupés ; retours (sortie, /reload en combat, filet) ------------
do
	Say("-- R2Q perf : combat")
	P.Reset()
	local aggro, camp = NS.aggroEventFrame, NS.campEventFrame
	Want("hors combat : aggro et camp abonnés", P.On(aggro, "NAME_PLATE_UNIT_ADDED") and P.Job("aggro")
		and P.On(camp, "UNIT_AURA") and P.Job("camp"))
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Want("en combat : barres de nom, touches, objets et horloge de l'aggro coupés", not P.On(aggro, "NAME_PLATE_UNIT_ADDED")
		and not P.On(aggro, "NAME_PLATE_UNIT_REMOVED") and not P.On(aggro, "MODIFIER_STATE_CHANGED")
		and not P.On(aggro, "GET_ITEM_INFO_RECEIVED") and not P.Job("aggro"))
	Want("en combat : les événements de combat restent", P.On(aggro, "PLAYER_REGEN_ENABLED") and P.On(aggro, "PLAYER_ENTERING_WORLD"))
	Want("en combat : UNIT_AURA du camp coupé, son horloge tourne", not P.On(camp, "UNIT_AURA") and P.Job("camp"))
	Want("en combat : ce qui sert en combat reste (cœur, rythme, sacs pleins)", P.On(NS.eventFrame, "UNIT_AURA")
		and P.On(NS.paceEventFrame, "CHAT_MSG_COMBAT_XP_GAIN") and P.On(NS.bagspaceEventFrame, "UI_ERROR_MESSAGE"))
	local diag = NS:GateDiagLine()
	Want("/r2q diag : portes en pause et combat nommés", diag:find("aggro", 1, true) and diag:find("camp:aura", 1, true)
		and diag:find(NS.L.MSG_DIAG_GATES_COMBAT, 1, true), diag)
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Want("sortie de combat : tout rouvert", P.On(aggro, "NAME_PLATE_UNIT_ADDED") and P.Job("aggro")
		and P.On(camp, "UNIT_AURA"))
	Verdict("[R2Q PERF] combat : aggro et UNIT_AURA du camp coupés à l'entrée, rouverts à la sortie")

	-- /reload en combat : l'entrée en jeu lit le combat ; la sortie rouvre
	P.Reset()
	P.W.combat = true
	Mock:Fire("PLAYER_ENTERING_WORLD", false, true)
	local closed = not P.On(aggro, "NAME_PLATE_UNIT_ADDED") and not P.Job("aggro")
	P.W.combat = false
	Mock:Fire("PLAYER_REGEN_ENABLED")
	Want("/reload en combat : fermé, puis rouvert à la sortie", closed and P.On(aggro, "NAME_PLATE_UNIT_ADDED") and P.Job("aggro"))
	-- PLAYER_REGEN_ENABLED perdu : le filet relit le client, garde fermé tant
	-- qu'il est en combat, rouvre ensuite
	P.W.combat = true
	Mock:Fire("PLAYER_REGEN_DISABLED")
	Mock:Advance(NS.GATE_SAFETY + 0.1)
	local heldInCombat = not P.On(aggro, "NAME_PLATE_UNIT_ADDED") and NS.gateCombat == true
	P.W.combat = false
	Mock:Advance(NS.GATE_SAFETY + 0.1)
	Want("fin de combat manquée : fermé tant que le client est en combat, puis rouvert par le filet", heldInCombat
		and P.On(aggro, "NAME_PLATE_UNIT_ADDED") and NS.gateCombat == false)
	Verdict("[R2Q PERF] /reload en combat et PLAYER_REGEN_ENABLED perdu : rouverts")
end

-- 4. Événements d'un moment : voyage, récompense, série d'équipement, fenêtres -----------------------------
do
	Say("-- R2Q perf : événements d'un moment")
	P.Reset()
	local exp = NS.expeditionEventFrame
	Want("hors voyage : ni butin, ni argent, ni XP", not P.On(exp, "CHAT_MSG_LOOT") and not P.On(exp, "PLAYER_MONEY")
		and not P.On(exp, "PLAYER_XP_UPDATE"))
	NS:FireCallback("DEPARTURE", { name = "Village", source = "known" })
	Want("départ : voyage suivi, abonné", NS.expedition ~= nil and P.On(exp, "CHAT_MSG_LOOT") and P.On(exp, "PLAYER_MONEY"))
	NS:FireCallback("RETURN", { name = "Village" })
	Want("retour : voyage refermé, désabonné", NS.expedition == nil and not P.On(exp, "CHAT_MSG_LOOT"))
	NS:FireCallback("DEPARTURE", { name = "Vallée", kind = "start", quiet = true })
	Want("départ silencieux (vallée de départ) : rien d'abonné", NS.expedition == nil and not P.On(exp, "CHAT_MSG_LOOT"))
	NS:ExpeditionStart({ name = "Village" })
	NS.expedition = nil                                   -- voyage oublié par un autre chemin
	Mock:Fire("CHAT_MSG_LOOT", "rien")
	Want("voyage oublié ailleurs : désabonné au premier événement", not P.On(exp, "CHAT_MSG_LOOT"))
	Verdict("[R2Q PERF] retour d'expédition : abonné pendant le voyage seulement")

	local reward = NS.rewardEventFrame
	Want("récompense fermée : ni GET_ITEM_INFO_RECEIVED ni QUEST_ITEM_UPDATE", not P.On(reward, "GET_ITEM_INFO_RECEIVED")
		and not P.On(reward, "QUEST_ITEM_UPDATE") and P.On(reward, "QUEST_COMPLETE"))
	Mock:Fire("QUEST_COMPLETE")
	Want("récompense ouverte : abonnés", P.On(reward, "GET_ITEM_INFO_RECEIVED") and P.On(reward, "QUEST_ITEM_UPDATE"))
	Mock:Fire("QUEST_FINISHED")
	Want("récompense refermée : désabonnés", not P.On(reward, "GET_ITEM_INFO_RECEIVED"))
	Verdict("[R2Q PERF] récompense de quête : objets reçus écoutés pendant l'écran de récompense seulement")

	local stats = NS.statsEventFrame
	Want("pas de série d'équipement : UNIT_STATS coupé", not P.On(stats, "UNIT_STATS")
		and not P.On(stats, "PLAYER_AVG_ITEM_LEVEL_UPDATE"))
	Mock:Fire("PLAYER_EQUIPMENT_CHANGED", 5)
	Want("pièce changée : UNIT_STATS du joueur seulement", NS.gearPending ~= nil and P.On(stats, "UNIT_STATS")
		and stats.unitFilter and stats.unitFilter.UNIT_STATS and stats.unitFilter.UNIT_STATS.player == true)
	NS.gearPending = nil
	Mock:Fire("UNIT_STATS", "player")
	Want("série close : rendu au premier UNIT_STATS", not P.On(stats, "UNIT_STATS"))
	Verdict("[R2Q PERF] résumé de stuff : UNIT_STATS pendant une série de changements seulement")

	-- sacs : seulement fenêtre ouverte (Sac plein, Place au butin)
	local bag, loot = NS.bagspaceEventFrame, NS.lootRoomEventFrame
	Want("fenêtres fermées : ni BAG_UPDATE ni BAG_UPDATE_DELAYED", not P.On(bag, "BAG_UPDATE")
		and not P.On(bag, "BAG_UPDATE_DELAYED") and not P.On(loot, "BAG_UPDATE_DELAYED") and P.On(loot, "LOOT_CLOSED"))
	NS:LootRoomOpen(true)
	Want("Place au butin ouverte (à la main) : sacs suivis", P.On(loot, "BAG_UPDATE_DELAYED"))
	Mock:Fire("LOOT_CLOSED")
	Want("butin fermé : rendus", not P.On(loot, "BAG_UPDATE_DELAYED"))
	NS.lootRoomPending = 1
	NS:SyncEventGate("lootroom:bags")
	Want("ramassage en attente, fenêtre fermée : sacs suivis", P.On(loot, "BAG_UPDATE_DELAYED"))
	NS.lootRoomPending = nil
	Mock:Fire("BAG_UPDATE_DELAYED")
	Want("rien en attente : rendus au premier mouvement", not P.On(loot, "BAG_UPDATE_DELAYED"))
	local frame = NS:EnsureBagSpaceFrame()
	if frame then
		NS.bagspace = { list = { { bag = 0, slot = 1, itemID = 1, count = 1, value = 0, link = "x", quality = 0 } }, index = 1 }
		NS:ShowBagSpaceFrame()
		local shown = P.On(bag, "BAG_UPDATE") and P.On(bag, "BAG_UPDATE_DELAYED")
		frame:Hide()                                   -- fermée sans passer par HideBagSpaceFrame (Échap)
		Mock:Fire("BAG_UPDATE", 0)
		Want("Sac plein : sacs suivis cadre ouvert, rendus au premier mouvement cadre fermé", shown
			and not P.On(bag, "BAG_UPDATE") and not P.On(bag, "BAG_UPDATE_DELAYED"))
		NS.bagspace = nil
	end
	Verdict("[R2Q PERF] sacs : BAG_UPDATE* écoutés fenêtre ouverte (ou ramassage en attente) seulement")

	local fav = NS.favoritesEventFrame
	local before = NS:DB().favoriteClick
	local supported = NS.favoritesGlobalClick == true
	NS:SetFavoriteClick("off")
	local off = not P.On(fav, "GLOBAL_MOUSE_UP")
	NS:SetFavoriteClick("alt")
	Want("raccourci des favoris « désactivé » : plus de GLOBAL_MOUSE_UP ; remis : rouvert", off
		and P.On(fav, "GLOBAL_MOUSE_UP") == supported)
	NS:DB().favoriteClick = before
	Verdict("[R2Q PERF] favoris : clic global écouté seulement avec un raccourci")
end

-- 5. Chemins fréquents sans déchets, résultats identiques -------------------------------------------------
do
	Say("-- R2Q perf : chemins fréquents")
	P.Reset()
	-- 5.1 marques d'aggro : un mode par passage, aucune fiche par barre
	local W = { units = {}, plates = {} }
	_G.UnitExists = function(unit) return unit == "player" or W.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitCanAttack = function(_, unit) return W.units[unit] ~= nil end
	_G.UnitCreatureType = function() return "Humanoïde" end
	_G.UnitReaction = function() return 2 end
	_G.UnitLevel = function(unit) if unit == "player" then return 20 end return W.units[unit] and W.units[unit].level end
	_G.UnitGUID = function(unit) return W.units[unit] and W.units[unit].guid end
	_G.IsShiftKeyDown = function() return true end
	_G.IsControlKeyDown = function() return false end
	_G.IsAltKeyDown = function() return false end
	_G.CheckInteractDistance = function() return nil end
	local ranges = {}
	for _, step in ipairs(NS.AGGRO_RANGE_ITEMS) do for _, itemID in ipairs(step[2]) do ranges[itemID] = step[1] end end
	C_Item.IsItemInRange = function(itemID, unit)
		local u, range = W.units[unit], ranges[itemID]
		if not u or not range then return nil end
		return u.dist <= range
	end
	_G.C_NamePlate = {
		GetNamePlateForUnit = function(unit) return W.plates[unit] end,
		GetNamePlates = function() local list = {} for _, p in pairs(W.plates) do list[#list + 1] = p end return list end,
	}
	NS:DB().aggroKey, NS:DB().aggroKeySchema = "shift", 2
	NS.aggroPlates, NS.aggroScanned, NS.aggroDistCache = {}, nil, nil
	for i = 1, 8 do
		local unit = "nameplate" .. i
		W.units[unit] = { level = 18 + i % 4, dist = 4 * i, guid = "Creature-0-1-1-1-" .. (100 + i) .. "-0" }
		local plate = CreateFrame("Frame")
		plate.namePlateUnitToken = unit
		W.plates[unit] = plate
		Mock:Fire("NAME_PLATE_UNIT_ADDED", unit)
	end
	local evaluate, mode = NS.AggroEvaluate, NS.AggroMode
	local evalCalls, modeCalls = 0, 0
	NS.AggroEvaluate = function(...) evalCalls = evalCalls + 1; return evaluate(...) end
	NS.AggroMode = function(...) modeCalls = modeCalls + 1; return mode(...) end
	NS:AggroTick()
	NS.AggroEvaluate, NS.AggroMode = evaluate, mode
	local bad = {}
	for unit, plate in pairs(W.plates) do
		local ring = NS.aggroRings[plate]
		local eval = NS:AggroEvaluate(unit)
		local want = eval and eval.verdict
		if (ring and ring:IsShown() and ring.verdict or nil) ~= want then bad[#bad + 1] = unit .. "=" .. tostring(want) end
	end
	Want("marques : le verdict d'AggroEvaluate, barre par barre", #bad == 0, table.concat(bad, ","))
	Want("un passage : AggroMode lu une fois (2 avant : une fois par barre en plus), aucune fiche AggroEvaluate",
		modeCalls == 1 and evalCalls == 0, modeCalls .. "/" .. evalCalls)
	Say(string.format("   aggro, 8 barres : %.2f Ko par passage (maquette comprise)", P.Kb(50, function() NS:AggroTick() end) / 50))
	Verdict("[R2Q PERF] marques d'aggro : même verdict, un mode par passage, aucune table par barre")

	-- 5.2 liserés des rangs de sorts : noms des boutons faits une fois, livre gardé en combat
	local SPELLS = { [101] = { "Soin", "Rang 1" }, [102] = { "Soin", "Rang 2" } }
	local BOOK = { 102 }
	local bookReads = 0
	_G.C_Spell, _G.C_SpellBook = nil, nil
	_G.GetActionInfo = function(slot) if slot == 1 then return "spell", 101 end if slot == 2 then return "spell", 102 end end
	_G.GetSpellInfo = function(id) return SPELLS[id] and SPELLS[id][1] end
	_G.GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end
	_G.GetNumSpellTabs = function() return 1 end
	_G.GetSpellTabInfo = function() return "Sacré", "", 0, #BOOK end
	_G.GetSpellBookItemInfo = function(index) bookReads = bookReads + 1; return "SPELL", BOOK[index] end
	local b1 = CreateFrame("Frame"); b1.action = 1; _G.ActionButton1 = b1
	local b2 = CreateFrame("Frame"); b2.action = 2; _G.ActionButton2 = b2
	NS:DB().spellranksIgnore, NS:DB().spellranksBorder = {}, true
	local first = NS:SpellRanksMark()
	local format, formats = string.format, 0
	string.format = function(...) formats = formats + 1; return format(...) end
	local second = NS:SpellRanksMark()
	string.format = format
	Want("liserés : même résultat (case 1 marquée, case 2 à jour)", first == 1 and second == 1
		and NS.spellRanksBorders[b1]:IsShown() and not (NS.spellRanksBorders[b2] and NS.spellRanksBorders[b2]:IsShown()))
	Want("noms des boutons faits une fois (plus de string.format par passage)", formats == 0, formats)
	P.W.combat = true
	bookReads = 0
	NS:SpellRanksMark()
	local inCombat1 = bookReads
	NS:SpellRanksMark()
	NS:SpellRanksMark()
	local inCombat3 = bookReads
	Mock:Fire("SPELLS_CHANGED")
	NS:SpellRanksMark()
	local afterChange = bookReads
	P.W.combat = false
	NS:SpellRanksMark()
	Want("en combat : livre lu une fois pour trois passages ; relu après SPELLS_CHANGED et hors combat",
		inCombat1 == #BOOK and inCombat3 == inCombat1 and afterChange == inCombat1 + #BOOK and bookReads == afterChange + #BOOK,
		inCombat1 .. "/" .. inCombat3 .. "/" .. afterChange .. "/" .. bookReads)
	BOOK[2] = 999
	SPELLS[999] = { "Soin", "Rang 3" }
	Want("hors combat : livre relu (nouveau rang appris)", NS:SpellRanksMark() == 2)
	_G.ActionButton1, _G.ActionButton2 = saved.ActionButton1, saved.ActionButton2
	Verdict("[R2Q PERF] liserés des rangs : même résultat, noms des boutons gardés, livre gardé le temps d'un combat")

	-- 5.3 messages d'erreur (Sac plein, Place au butin) : même réponse, sans chaînes refaites
	_G.ERR_INV_FULL, _G.ERR_BAG_FULL = "L'inventaire est plein.", "Ce sac est plein."
	local cases = {
		{ "L'inventaire est plein.", true }, { "|cffff0000L’inventaire est plein !|r", true }, { "  Ce sac est plein ", true },
		{ "Hors de portée.", false }, { "Pas assez de rage", false }, { "", false }, { "inventory is full", true },
	}
	bad = {}
	for _, c in ipairs(cases) do
		if NS:IsBagFullError(nil, c[1]) ~= c[2] then bad[#bad + 1] = c[1] end
		if NS:IsBagFullError(c[1]) ~= c[2] then bad[#bad + 1] = "ancien:" .. c[1] end
	end
	Want("réponses identiques (couleurs, apostrophe, ponctuation, repli fr/en)", #bad == 0, table.concat(bad, " / "))
	_G.ERR_INV_FULL = "Inventaire saturé."
	Want("globale du client changée : relue", NS:IsBagFullError(nil, "Inventaire saturé") == true)
	local kb = P.Kb(1000, function() NS:IsBagFullError(nil, "Hors de portée.") end)
	Want("message déjà vu : rien d'alloué (1 000 messages)", kb < 1, string.format("%.2f Ko", kb))
	for i = 1, 300 do NS:IsBagFullError(nil, "message " .. i) end
	Want("textes gardés bornés", NS.BagSpaceNormalizedCount() <= NS.BAGSPACE_NORMALIZED_MAX, NS.BagSpaceNormalizedCount())
	Say(string.format("   UI_ERROR_MESSAGE répété : %.3f Ko pour 1 000", kb))
	Verdict("[R2Q PERF] messages d'erreur : même réponse, rien d'alloué pour un message déjà vu, cache borné")

	-- 5.4 zone sûre : le premier signal vivant, sans sa table
	local resting, sanctuary = false, false
	_G.IsResting = function() return resting end
	_G.UnitIsPVPSanctuary = function() return sanctuary end
	local listed = NS.LiveSafeSignals
	local listCalls = 0
	NS.LiveSafeSignals = function(...) listCalls = listCalls + 1; return listed(...) end
	Mock.world.mapID, Mock.world.subzone = 20, "Plaine"
	bad = {}
	for _, c in ipairs({ { false, false }, { true, false }, { false, true }, { true, true } }) do
		resting, sanctuary = c[1], c[2]
		local safe, _, why = NS:IsCurrentZoneSafe()
		local signals = listed(NS)
		if safe ~= (#signals > 0) or why ~= signals[1] then bad[#bad + 1] = tostring(c[1]) .. "/" .. tostring(c[2]) end
	end
	Want("même réponse que LiveSafeSignals (repos, sanctuaire, les deux, aucun)", #bad == 0, table.concat(bad, ","))
	Want("plus de liste de signaux construite par IsCurrentZoneSafe", listCalls == 0, listCalls)
	NS.LiveSafeSignals = listed
	Verdict("[R2Q PERF] zone sûre : premier signal vivant sans table, même réponse")

	-- 5.5 sonde du portrait : champ .unit lu sans fermeture neuve
	local plain = { unit = "player" }
	Want("champ .unit lu", NS.PortraitFrameUnit(plain) == "player" and NS.PortraitFrameUnit({}) == nil)
	kb = P.Kb(1000, function() NS.PortraitFrameUnit(plain) end)
	Want("1 000 lectures : rien d'alloué", kb < 1, string.format("%.2f Ko", kb))
	Verdict("[R2Q PERF] sonde du portrait : unité lue sans fermeture par cadre")
end

-- Restauration ---------------------------------------------------------------------------------------------
for _, name in ipairs(NAMES) do _G[name] = saved[name] end
C_Item.IsItemInRange = saved.inRange
ResetWorld()
