-- Zones de départ (vallées des niveaux 1-5) : une seule zone sûre, et aucune
-- alerte automatique avant d'en être sorti (le check reste à la main).
-- Munitions du chasseur : minimum selon le niveau, et projectiles rangés
-- dans les sacs mais pas équipés.
local Check, Say, ResetWorld, NS, Mock, Result = T.Check, T.Say, T.ResetWorld, T.NS, T.Mock, T.Result

local S = {}
function S.Reset(level, subzone)
	ResetWorld()
	_G.UnitFactionGroup = function() return Mock.world.faction end
	_G.IsInInstance = function() return false end
	Mock.world.faction = "Horde"
	Mock.world.level = level or 3
	Mock.world.mapID, Mock.world.subzone = 1, subzone or "Valley of Trials"
	NS:DB().popupScore = 100       -- toujours un rapport, quelle que soit la note
	NS:DB().exitDelay = 0
	NS:HideNotice()
	if NS.window then NS.window:Hide() end
	NS.expedition, NS.lastExpedition = nil, nil
end
function S.Leave(subzone)
	Mock:Fire("PLAYER_ENTERING_WORLD", true, false)
	Mock.now = Mock.now + 60
	Mock.world.subzone = subzone or "Durotar"
	Mock:Reset()
	Mock:Fire("ZONE_CHANGED")
	Mock:Advance(1)
end
function S.Done()
	_G.UnitFactionGroup, _G.IsInInstance = nil, nil
	ResetWorld()
end

-- 1. Vallées de départ dans Hubs.lua ------------------------------------------------------
do
	Say("-- zones de départ : lieux")
	local function Find(name)
		for areaID, entry in pairs(NS.HUBS) do
			if entry.name == name then return entry, areaID end
		end
	end
	local trials, id = Find("Valley of Trials")
	Check("[START] Vallée des épreuves : zone de départ de la Horde", trials and id == 363 and trials.kind == "start"
		and trials.faction == "H")
	local den = Find("The Den")
	local north = Find("Northshire Abbey")
	Check("[START] avec ses sous-zones (la Tanière, l'abbaye de Northshire…)", den and den.kind == "start"
		and north and north.kind == "start" and north.faction == "A")
	local count = 0
	for _, entry in pairs(NS.HUBS) do if entry.kind == "start" then count = count + 1 end end
	Check("[START] six vallées et leurs sous-zones", count >= 17, count)
	Check("[START] le col de Coldridge n'en fait pas partie (c'est la sortie)", Find("Coldridge Pass") == nil)
end

-- 2. Départ silencieux ---------------------------------------------------------------------
do
	Say("-- zones de départ : silence")
	S.Reset(3)
	local safe, _, reason, entry = NS:IsCurrentZoneSafe()
	Check("[START] dans la vallée : zone sûre", safe and reason == "known" and entry.kind == "start")
	Mock.world.level = 8
	local valley = NS:IsQuietDeparture({ kind = "start" }) == true
	Mock.world.level = 4
	local low = NS:IsQuietDeparture({ kind = "town" }) == true
	Mock.world.level = 6
	Check("[START] silencieux depuis une vallée (même niveau 8) ou sous le niveau 6 ; alerte normale ensuite", valley and low
		and NS:IsQuietDeparture({ kind = "town" }) == false)

	S.Reset(5)
	local fromDeparture
	NS:RegisterCallback("DEPARTURE", function(_, from) fromDeparture = from end)
	S.Leave()
	Check("[START] sortie de la vallée : ni icône, ni fenêtre, ni chat, ni expédition", not (NS.noticeFrame and NS.noticeFrame:IsShown())
		and not (NS.window and NS.window:IsShown()) and Mock:Output() == "" and NS.expedition == nil, Mock:Output())
	Check("[START] le départ est quand même signalé aux autres modules", fromDeparture and fromDeparture.quiet == true)
	NS.callbacks.DEPARTURE[#NS.callbacks.DEPARTURE] = nil
	NS:RunChecklist("manual")
	Check("[START] le check reste disponible à la main", NS.window and NS.window:IsShown())
	NS.window:Hide()

	-- resté dans sa vallée jusqu'au niveau 8 : sa sortie reste silencieuse
	S.Reset(8)
	S.Leave()
	Check("[START] niveau 8, sortie de la vallée : toujours rien", Mock:Output() == ""
		and not (NS.noticeFrame and NS.noticeFrame:IsShown()), Mock:Output())

	S.Reset(12, "Razor Hill")
	NS.HUBS[9999001] = { faction = "H", kind = "town", name = "Razor Hill" }
	NS.hubIndex = nil
	S.Leave()
	Check("[START] après la vallée (village, niveau 12) : l'icône revient", NS.noticeFrame and NS.noticeFrame:IsShown())
	NS.HUBS[9999001] = nil
	NS.hubIndex = nil
	S.Done()
end

-- 3. Munitions du chasseur ----------------------------------------------------------------
do
	Say("-- munitions du chasseur")
	ResetWorld()
	Mock.world.classToken = "HUNTER"
	local function Run(level, ammo)
		Mock.world.level, Mock.world.ammo = level, ammo
		NS:RunChecklist("manual")
		if NS.window then NS.window:Hide() end
		return Result("classreagents")
	end
	local low, mid, high = Run(5, 250).ok == true, Run(20, 500), Run(40, 800)
	Check("[AMMO] 250 suffisent au niveau 5 ; 500/600 au 20 ; il en faut 1000 au 40", low and mid.ok == false
		and mid.detail:find("500 / 600", 1, true) ~= nil and high.ok == false and high.detail:find("/ 1000", 1, true) ~= nil,
		mid.detail .. " | " .. high.detail)
	Check("[AMMO] paliers : 200, 600 dès le niveau 10, 1000 dès le niveau 30",
		NS.ReagentMinimum(NS.CLASS_REAGENTS.HUNTER[1].min, 9) == 200
		and NS.ReagentMinimum(NS.CLASS_REAGENTS.HUNTER[1].min, 10) == 600
		and NS.ReagentMinimum(NS.CLASS_REAGENTS.HUNTER[1].min, 30) == 1000)

	Mock.world.itemInfo[2512] = { name = "Flèche grossière", classID = 6, subClassID = 2 }
	Mock.world.bags[0].items[1] = { itemID = 2512, stackCount = 200, quality = 1 }
	local stored = Run(10, 0)
	Check("[AMMO] flèches dans les sacs, pas équipées : le dire", stored.ok == false
		and stored.detail:find("200 dans tes sacs", 1, true) ~= nil, stored.detail)
	Mock.world.bags[0].items[1] = nil
	local none = Run(10, 0)
	Check("[AMMO] aucune flèche : il faut en racheter", none.ok == false and none.detail:find("0 / 600", 1, true) ~= nil,
		none.detail)

	-- poids et plafond : sans munitions, pas de tir automatique
	local dry = Run(20, 0)
	Check("[AMMO] munitions : poids 40 (plus que les vivres)", dry.weight == NS.AMMO_WEIGHT and NS.AMMO_WEIGHT == 40, dry.weight)
	Check("[AMMO] à sec : bloquant (note plafonnée à 59), conseil des munitions en tête", NS.score <= NS.SCORE_CAP_BLOCKING
		and NS.score <= 59 and dry.blocking == true and NS.lastAdvice[1] and NS.lastAdvice[1].text == NS.L.ADV_AMMO, NS.score)
	-- tout le reste parfait (un contrôle fictif très lourd) : la moyenne serait
	-- « Prêt », le plafond la ramène à « Pas prêt »
	local fake = { id = "fake_ok", label = "Fictif", weight = 400, run = function() return true, "ok", 100 end }
	table.insert(NS.checks, fake)
	Run(20, 0)
	local cappedScore = NS.score
	table.remove(NS.checks, #NS.checks)
	Check("[AMMO] à sec et tout le reste parfait : plafonnée à 59", cappedScore == NS.SCORE_CAP_BLOCKING, cappedScore)
	local half = Run(20, 400)
	Check("[AMMO] au-dessus de la moitié du minimum : pas bloquant", half.ok == false and half.blocking == nil)
	Mock.world.bags[0].items[1] = { itemID = 2512, stackCount = 600, quality = 1 }
	local unequipped = Run(20, 0)
	Check("[AMMO] pas équipées : bloquant aussi", unequipped.blocking == true and NS.score <= 59, NS.score)
	Mock.world.bags[0].items[1] = nil
	local full = Run(20, 900)
	Check("[AMMO] assez de munitions : rien ne plafonne", full.ok == true and full.blocking == nil)

	Mock.world.classToken = "WARLOCK"
	Mock.world.level = 20
	NS:RunChecklist("manual")
	if NS.window then NS.window:Hide() end
	Check("[AMMO] autres classes : réactifs au poids habituel (15)", Result("classreagents").weight == 15
		and Result("classreagents").blocking == nil)

	Mock.world.classToken = nil
	Mock.world.ammo = nil
	ResetWorld()
end
