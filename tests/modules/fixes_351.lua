-- QC 3.5.1 (docs/audit-pokemon-like-3.5, lot 0) : les correctifs d'après la 3.5.
-- Caresse renforcée une fois par état, brillante en file 10 minutes, une ligne
-- de chat par capture, commandes (bonus, profils, relance), arrivage par
-- paquet, surnom porté, tâche d'étude « brillante », sceaux sans niveau 9999.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local function Fresh()
	ResetWorld()
	local capture = NS:CaptureData()
	capture.specimens, capture.codex, capture.creatures = {}, {}, {}
	capture.specNext, capture.specDirty, capture.specV = 1, nil, NS.SPECIMEN_SCHEMA
	capture.traitV = NS.SPECIMEN_TRAIT_SCHEMA
	capture.paillettes, capture.study, capture.orders, capture.shopOwned = 0, nil, nil, nil
	capture.studyV, capture.studyShinyV = nil, nil
	NS.reserveFacetCache, NS.effectCache, NS.shopArrivalCache = nil, nil, nil
	return capture
end

local function Add(npc, stars, opts)
	opts = opts or {}
	local capture = NS:CaptureData()
	capture.creatures[npc] = capture.creatures[npc] or { name = opts.name or ("Bête " .. npc), normal = true, stars = stars,
		class = "normal", type = opts.type or "Bête" }
	return NS:SpecimenAdd({ npc = npc, stars = stars, shiny = opts.shiny, name = opts.name or ("Bête " .. npc),
		origin = opts.origin or "capture", trait = opts.trait, size = opts.size, at = opts.at, zone = opts.zone })
end

-- 1. La caresse renforcée : une fois par état ------------------------------------------
do
	Say("-- 3.5.1 : caresse renforcée, une fois par état")
	Fresh()
	local data = NS:CompanionData()
	data.extended = nil
	local S = NS.COMPANION_STATE
	data.needs.hunger, data.needs.energy, data.needs.curiosity = S.full, S.full, S.on + 3
	local first = NS:CompanionStateExtend(0.5)
	local again = NS:CompanionStateExtend(0.5)
	local third = NS:CompanionStateExtend(0.5)
	local fourth = NS:CompanionStateExtend(0.5)
	Check("[F351] caresse : l'état le plus court, puis le suivant ; chacun une seule fois", first == "curiosity"
		and again ~= "curiosity" and again ~= nil and third ~= nil and third ~= again and fourth == nil,
		tostring(first) .. "/" .. tostring(again) .. "/" .. tostring(third) .. "/" .. tostring(fourth))
	data.needs.curiosity = S.on
	NS:CompanionGrant("curiosity")
	Check("[F351] regagné (déclencheur) : la caresse peut de nouveau l'allonger", NS:CompanionStateExtend(0.5) == "curiosity")
end

-- 2. Une brillante en file attend 10 minutes, et jamais n'expire en combat --------------
do
	Say("-- 3.5.1 : brillante en file")
	Check("[F351] brillante : 600 s en file (les autres : 30 s)", NS.CAPTURE_QUEUE_SHINY_TIME == 600 and NS.CAPTURE_QUEUE_TIME == 30)
end

-- 6, 7. Commandes et arrivage ------------------------------------------------------------
do
	Say("-- 3.5.1 : commandes et arrivage")
	local capture = Fresh()
	for i = 1, 6 do Add(980 + i, 1, { trait = "zen", size = "large", zone = 1413 }) end
	for i = 1, 6 do Add(980 + i, 2, { trait = "zen", size = "large", zone = 1413 }) end
	local orders = NS:ShopOrders()
	local rare = false
	for _, order in ipairs(orders.list) do if order.kind == "traitStars" and NS.SPECIMEN_TRAIT_RARE[order.trait] then rare = true end end
	Check("[F351] commande de caractère : jamais un caractère rare (Zen, Espiègle)", not rare)
	-- 3.6.0 : la suivante coûte 10 paillettes (solde à 0 ici : « short »)
	Check("[F351] relance : une gratuite, tant qu'aucune n'est livrée", NS:ShopOrdersCanReroll() == true and NS:ShopOrdersReroll() == true
		and NS:ShopOrdersCanReroll() == false and select(2, NS:ShopOrdersCanReroll()) == "short")
	-- les trois livrées, les deux arrivages déjà à toi : 30 paillettes
	capture.shopOwned = {}
	for _, item in ipairs(NS:ShopArrivals()) do capture.shopOwned[item.cosId] = true end
	local zoneOrder = { kind = "zone", zone = 1413, reward = 12 }
	orders.list = { { kind = "zone", zone = 1413, reward = 12, done = true }, { kind = "zone", zone = 1413, reward = 12, done = true }, zoneOrder }
	local target
	for _, spec in ipairs(NS:SpecimenList({ where = "reserve" })) do if NS:SpecimenCanRelease(spec.id) then target = spec.id; break end end
	local before = NS:Paillettes()
	local ok = target and NS:ShopOrderDeliver(3, target)
	Check("[F351] trois livrées, arrivages possédés : +12 puis +30 paillettes", ok and NS:Paillettes() == before + 12 + NS.ORDER_BONUS_GLITTER
		and orders.bonus == "glitter", NS:Paillettes() - before)
	-- l'arrivage par paquet : 4 semaines, les 8 une fois
	local savedWeekly = NS.WeeklyId
	local seen, n, dup = {}, 0, false
	for w = 400, 403 do
		NS.WeeklyId = function() return "r" .. w end
		NS.shopArrivalCache = nil
		for _, item in ipairs(NS:ShopArrivals()) do
			if seen[item.id] then dup = true end
			seen[item.id] = true; n = n + 1
		end
	end
	NS.WeeklyId = savedWeekly
	NS.shopArrivalCache = nil
	local pool = 0
	for _, item in ipairs(NS.PAILLETTES_SHOP) do if item.arrival then pool = pool + 1 end end
	Check("[F351] arrivage : sur un cycle de 4 semaines, chaque cosmétique passe une fois", not dup and n == pool, n .. "/" .. pool)
end

-- 8. Le surnom de l'exemplaire porté ----------------------------------------------------
do
	Say("-- 3.5.1 : surnom porté")
	Fresh()
	local id = Add(990, 3)
	NS:CompanionData().appearance = "cap:990"
	local plain = NS:CompanionName()
	NS:SpecimenSetNick(id, "Bob")
	Check("[F351] le compagnon porte le surnom de son exemplaire", plain ~= "Bob" and NS:CompanionName() == "Bob", NS:CompanionName())
	NS:SpecimenSetNick(id, nil)
	NS:CompanionData().appearance = nil
end

-- 10. La tâche d'étude « brillante » ----------------------------------------------------
do
	Say("-- 3.5.1 : étude, brillante")
	local capture = Fresh()
	NS.studyDormant = false
	NS:SpecimenStudy(995)          -- la rétro passe (rien encore)
	local before = NS:Paillettes()
	Add(995, 1, { shiny = true, trait = "lazy", size = "normal" })
	local gained = NS:Paillettes() - before
	local st = NS:SpecimenStudy(995)
	Check("[F351] brillante capturée : la tâche « brillante » payée (5) avec « capturée » (2), pas « maîtrisée »",
		st.shiny and not st.mastered and gained == NS.STUDY_REWARD.task + NS.STUDY_REWARD.shiny, gained)
	before = NS:Paillettes()
	Add(995, 1, { shiny = true, trait = "lazy", size = "normal" })
	Check("[F351] … payée une seule fois", NS:Paillettes() == before)
	NS.studyDormant = true
end

-- 11. Sceaux : les lignes de niveau 9999 ne comptent pas -----------------------------------
do
	Say("-- 3.5.1 : sceaux sans les lignes de niveau 9999")
	Fresh()
	local savedStatic, savedSpecies = NS.BestiaryStaticZone, NS.BestiarySpecies
	NS.BestiaryStaticZone = function() return {} end
	NS.BestiarySpecies = function()
		return { [1] = { class = "normal", lvl = { 10, 12 } }, [2] = { class = "normal", lvl = { 9999, 9999 } },
			[3] = { class = "worldboss", lvl = { 63, 63 } } }
	end
	local have, need = NS:MenagerieSealProgress(1413)
	NS.BestiaryStaticZone, NS.BestiarySpecies = savedStatic, savedSpecies
	Check("[F351] sceau : ni le boss du monde ni la ligne de niveau 9999", need == 1 and have == 0, have .. "/" .. need)
end
