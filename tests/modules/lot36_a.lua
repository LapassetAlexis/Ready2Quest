-- QC 3.6.0 (docs/audit-pokemon-like-3.5/PLAN.md, lot 1, chantier A) : les
-- paillettes d'un gros joueur et les effets de jeu de la maîtrise.
-- Arrivage hors de sa semaine (×1,5), mécénat (points, hauts faits, titres),
-- relance de commande payante, relâcher à moitié prix passé 100 paillettes
-- dans la journée (lots compris, fiche du spécimen), méfiance d'une espèce
-- maîtrisée (+0,10) et sa ligne d'étude, paillettes des sceaux d'un biome.
local Check, Say, ResetWorld, NS = T.Check, T.Say, T.ResetWorld, T.QNS

local function Fresh()
	ResetWorld()
	local capture = NS:CaptureData()
	capture.specimens, capture.codex, capture.creatures = {}, {}, {}
	capture.specNext, capture.specDirty, capture.specV = 1, nil, NS.SPECIMEN_SCHEMA
	capture.traitV = NS.SPECIMEN_TRAIT_SCHEMA
	capture.paillettes, capture.study, capture.orders, capture.shopOwned = 0, nil, nil, nil
	capture.studyV, capture.studyShinyV, capture.patron, capture.releaseDay = nil, nil, nil, nil
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

-- 1. Arrivage hors de sa semaine ----------------------------------------------------------
do
	Say("-- 3.6 : arrivage hors de sa semaine")
	local capture = Fresh()
	local arrivals = NS:ShopArrivals()
	local away = NS:ShopAwayList()
	local pool = 0
	for _, item in ipairs(NS.PAILLETTES_SHOP) do if item.arrival then pool = pool + 1 end end
	local clean = #away == pool - #arrivals
	for _, item in ipairs(away) do
		if item == arrivals[1] or item == arrivals[2] then clean = false end
		if NS:ShopPrice(item) ~= math.floor(item.price * 1.5 + 0.5) then clean = false end
	end
	Check("[L36A] hors de leur semaine : les cosmétiques ni de la semaine ni possédés, une fois et demie le prix", clean
		and NS:ShopPrice(arrivals[1]) == arrivals[1].price, #away .. "/" .. pool)
	local ordered = true
	for index = 2, #away do
		if (NS:ShopAwayWeeks(away[index]) or 99) < (NS:ShopAwayWeeks(away[index - 1]) or 99) then ordered = false end
	end
	local back = NS:ShopAwayWeeks(away[1])
	Check("[L36A] le premier revient le plus tôt (1 à 8 semaines)", ordered and back and back >= 1 and back <= 8, tostring(back))
	local item = away[1]
	local price = NS:ShopPrice(item)
	NS:PaillettesAdd(price - 1, "test")
	Check("[L36A] solde court d'une paillette : « short »", NS:ShopState(item) == "short")
	NS:PaillettesAdd(1, "test")
	local ok = NS:ShopBuy(item.id)
	Check("[L36A] acheté hors de sa semaine : prix ×1,5 payé, le cosmétique est à toi, il quitte la liste", ok and NS:Paillettes() == 0
		and NS:ShopCosmeticOwned(item.cosId) and #NS:ShopAwayList() == #away - 1)
	capture.shopOwned = {}
	for _, it in ipairs(NS.PAILLETTES_SHOP) do if it.arrival then capture.shopOwned[it.cosId] = true end end
	Check("[L36A] tout possédé : la liste est vide", #NS:ShopAwayList() == 0)
end

-- 2. Mécénat ---------------------------------------------------------------------------------
do
	Say("-- 3.6 : mécénat")
	local capture = Fresh()
	NS:PaillettesAdd(250, "test")
	local item = NS:ShopItem("patron")
	local ok1 = NS:ShopBuy("patron")
	local ok2 = NS:ShopBuy("patron")
	local ok3 = NS:ShopBuy("patron")
	Check("[L36A] 100 paillettes = 1 point de mécène, sans rien d'autre ; trop court : refusé", item and item.price == 100
		and ok1 and ok2 and not ok3 and NS:ShopPatronPoints() == 2 and NS:Paillettes() == 50 and NS:ShopState("patron") == "short")
	local def = NS:FeatDef("men_patron_10")
	capture.patron = 9
	local cur, max = NS:FeatProgress(def)
	capture.patron = 10
	local cur2 = NS:FeatProgress(def)
	Check("[L36A] haut fait « Mécène » à 10 points (compte), puis 50 et 100, avec leurs titres", def and cur == 9 and max == 10
		and cur2 == 10 and def.scope == "account" and def.reward.title == 61 and NS:FeatDef("men_patron_50").reward.title == 62
		and NS:FeatDef("men_patron_100").reward.title == 63 and NS.FEAT_TITLES[61].src == "men_patron_10"
		and NS.FEAT_TITLES[63].src == "men_patron_100")
	local earned = NS:FeatEvaluate(nil, { silent = true })
	local got = false
	for _, d in ipairs(earned) do if d.id == "men_patron_10" then got = true end end
	Check("[L36A] le moteur l'accorde (10 points)", got or NS:FeatGot("men_patron_10") ~= nil)
end

-- 3. Relance de commande payante ----------------------------------------------------------------
do
	Say("-- 3.6 : relance de commande")
	Fresh()
	for i = 1, 6 do Add(980 + i, 2, { trait = "zen", size = "large", zone = 1413 }) end
	local orders = NS:ShopOrders()
	local can, price = NS:ShopOrdersCanReroll()
	local free = can and price == 0 and NS:ShopOrdersReroll()
	local can2, why, missing = NS:ShopOrdersCanReroll()
	Check("[L36A] la première relance est gratuite, la suivante coûte 10 (solde 0 : « short », il en manque 10)", free
		and not can2 and why == "short" and missing == 10 and NS:ShopOrdersRerollPrice() == 10)
	NS:PaillettesAdd(15, "test")
	local before = orders.list[1]
	local paid = NS:ShopOrdersReroll()
	Check("[L36A] relance payante : −10, trois nouvelles demandes, encore possible ensuite", paid and NS:Paillettes() == 5
		and NS:ShopOrders().list[1] ~= before and #NS:ShopOrders().list == 3 and orders.rerolls == 2)
	NS:ShopOrders().list[1].done = true
	Check("[L36A] une commande livrée : plus de relance (« started »)", select(2, NS:ShopOrdersCanReroll()) == "started")
end

-- 4. Relâcher à moitié prix passé 100 paillettes dans la journée -----------------------------------
do
	Say("-- 3.6 : relâcher au demi-tarif")
	Fresh()
	Add(990, 3)
	local specs = {}
	for i = 1, 14 do specs[i] = Add(990, 3) end
	local first = NS:SpecimenReleaseValue(specs[1])
	local gained = 0
	for i = 1, 10 do gained = gained + (NS:SpecimenRelease(specs[i], true) or 0) end
	Check("[L36A] plein tarif jusqu'à 100 paillettes de relâcher dans la journée", first == 10 and gained == 100
		and NS:ReleaseToday() == 100 and NS:ReleaseHalfToday())
	local half = NS:SpecimenReleaseValue(specs[11])
	local got = NS:SpecimenRelease(specs[11], true)
	Check("[L36A] au-delà : moitié (arrondie au-dessus : 10 -> 5, brillant 25 -> 13), et ça compte encore", half == 5 and got == 5
		and NS:ReleaseToday() == 105 and NS:SpecimenReleaseValue({ shiny = true, stars = 1 }) == 13
		and NS:SpecimenReleaseBase(specs[12]) == 10)
	NS:CaptureData().releaseDay.day = "hier"
	Check("[L36A] un nouveau jour : plein tarif", NS:SpecimenReleaseValue(specs[12]) == 10 and NS:ReleaseToday() == 0)
	NS:CaptureData().releaseDay = { day = NS.CaptureDayKey(), n = 95 }
	local lot = { NS:SpecimenGet(specs[12]), NS:SpecimenGet(specs[13]), NS:SpecimenGet(specs[14]) }
	Check("[L36A] un lot qui franchit le seuil : 10 + 5 + 5 (95 -> 105 au premier)", NS:SpecimenReleaseTotal(lot) == 20)
	local _, gain = NS:ReserveTidyCandidates(3)
	Check("[L36A] « Faire de la place » compte le demi-tarif", gain == 20, gain)
end

-- 4 bis. La fiche du spécimen dit « demi-tarif aujourd'hui » ------------------------------------------
do
	Say("-- 3.6 : fiche au demi-tarif")
	Fresh()
	Add(991, 1)
	local id = Add(991, 1)
	NS:CaptureData().releaseDay = { day = NS.CaptureDayKey(), n = 120 }
	local frame = NS:OpenReserve("reserve")
	NS:ReservePick(id)
	local rv = frame.res.reserve
	-- juste sous le lien (6e ligne), avant la référence et l'origine : la fiche
	-- cache ses dernières lignes quand la place manque (le banc d'essai compte
	-- les étoiles en atlas comme du texte : on vérifie le rang, pas l'affichage)
	local found, shown = false, false
	for index, line in ipairs(rv.preview.lines) do
		if (line:GetText() or ""):find("demi-tarif aujourd'hui", 1, true) then found = true; shown = index == 6 end
	end
	NS:ReserveRelease(id)
	local confirm = rv.confirm:IsShown() and (rv.confirm:GetText() or ""):find("Demi-tarif", 1, true) ~= nil
	NS:ReserveCancelConfirm()
	Check("[L36A] fiche : « Relâcher : demi-tarif aujourd'hui » (sous le lien), et la confirmation le redit", found and shown and confirm,
		tostring(found) .. "/" .. tostring(shown) .. "/" .. tostring(confirm))
end

-- 5. Espèce maîtrisée : moins méfiante en chasse ; sa ligne d'étude le dit ----------------------------
do
	Say("-- 3.6 : espèce maîtrisée et méfiance")
	local capture = Fresh()
	NS:SpecimenStudyRetro()
	capture.study = { [700] = { n = 6, z = 7, t = 7, s3 = true, paid = 63 }, [701] = { n = 2, z = 1, t = 1, paid = 1 } }
	capture.wary = { day = NS.CaptureDayKey(), n = { [700] = 10, [701] = 10 } }
	NS:HuntStart(30)
	local base = NS:CompanionWaryFloor()
	local plain = NS:CaptureWariness(701)
	local mastered, count = NS:CaptureWariness(700)
	Check("[L36A] méfiance au plus bas : plancher du compagnon, +0,10 pour une espèce maîtrisée", math.abs(plain - base) < 1e-9
		and math.abs(mastered - (base + 0.10)) < 1e-9 and count == 10 and NS:SpecimenStudyIsMastered(700)
		and not NS:SpecimenStudyIsMastered(701), plain .. " / " .. mastered)
	capture.wary.n[700] = 1
	Check("[L36A] une capture seulement : la méfiance ordinaire (au-dessus des deux planchers)",
		math.abs(NS:CaptureWariness(700) - (1 - NS.CAPTURE_WARINESS.step)) < 1e-9)
	NS:HuntStop()
	Check("[L36A] hors chasse : aucune méfiance", NS:CaptureWariness(700) == 1)
	local line = NS:SpecimenStudyLine(700)
	Check("[L36A] fiche de l'espèce (page Créatures) : « Espèce maîtrisée · en chasse, elle se méfie moins (plancher +10 %) »",
		line:find("se méfie moins", 1, true) ~= nil and line:find("+10 %", 1, true) ~= nil
		and not NS:SpecimenStudyLine(701):find("méfie", 1, true), line)
end

-- 6. Sceaux : 15 paillettes à partir du troisième d'un biome ---------------------------------------------
do
	Say("-- 3.6 : sceaux et paillettes")
	Fresh()
	-- le biome qui compte le plus de zones
	local by = {}
	for zoneID, biome in pairs(NS.MENAGERIE_ZONE_BIOME) do by[biome] = by[biome] or {}; table.insert(by[biome], zoneID) end
	local zones = {}
	for _, list in pairs(by) do if #list > #zones then zones = list end end
	table.sort(zones)
	local coll = NS:MenagerieCollectionData()
	coll.seals = {}
	local saved = NS.MenagerieSealProgress
	NS.MenagerieSealProgress = function() return 4, 4 end
	local gains = {}
	for index = 1, math.min(4, #zones) do
		local before = NS:Paillettes()
		NS:MenagerieSealCheck(zones[index], { quiet = index ~= 3 })
		gains[index] = NS:Paillettes() - before
	end
	NS.MenagerieSealProgress = saved
	Check("[L36A] sceaux d'un biome : rien pour les deux premiers (cadre, fond), puis 15 paillettes chacun", #zones >= 4
		and gains[1] == 0 and gains[2] == 0 and gains[3] == 15 and gains[4] == 15,
		table.concat(gains, ","))
end

-- 7. L'Échoppe : hors de leur semaine (ligne qui défile), mécénat, relance payante ----------------------
do
	Say("-- 3.6 : page Échoppe")
	Fresh()
	NS:PaillettesAdd(300, "test")
	for i = 1, 6 do Add(980 + i, 2, { trait = "zen", size = "large", zone = 1413 }) end
	local frame = NS:OpenReserve("shop")
	local sv = frame.shopPane
	local away = NS:ShopAwayList()
	local row = sv.awayRow
	local first = row.item
	sv.awayPager.down:GetScript("OnClick")(sv.awayPager.down)
	local second = row.item
	row:GetScript("OnMouseWheel")(row, 1)
	Check("[L36A] « Hors de leur semaine » : un cosmétique à la fois, flèches et molette, prix ×1,5 affiché",
		first == away[1] and second == away[2] and row.item == away[1] and sv.awayRow:IsShown()
		and (row.price:GetText() or ""):find(tostring(NS:ShopPrice(away[1])), 1, true) ~= nil
		and sv.awayPager.position:GetText() == ("1 / " .. #away))
	local patron = sv.patronRow
	patron.buy:GetScript("OnClick")(patron.buy)
	patron.yes:GetScript("OnClick")(patron.yes)
	Check("[L36A] « Mécénat » : Donner, confirmer : un point, −100, la ligne le dit", NS:ShopPatronPoints() == 1
		and NS:Paillettes() == 200 and patron.name:GetText() == "Points de mécène : 1" and patron.buy:GetText() == "Donner")
	NS:ShopOrdersReroll()
	NS:RefreshJournal()
	Check("[L36A] relance après la gratuite : « Relancer · 10 », la section dit « relance gratuite utilisée »",
		sv.reroll:IsShown() and sv.reroll:GetText() == "Relancer · 10" and sv.reroll.qcEnabled ~= false
		and (sv.ordersHead.detail:GetText() or ""):find("relance gratuite utilisée", 1, true) ~= nil)
	NS:CaptureData().shopOwned = {}
	for _, it in ipairs(NS.PAILLETTES_SHOP) do if it.arrival then NS:CaptureData().shopOwned[it.cosId] = true end end
	NS:RefreshJournal()
	Check("[L36A] tout l'arrivage possédé : la ligne laisse place à une phrase", not sv.awayRow:IsShown() and sv.awayEmpty:IsShown())
	Check("[L36A] aucune erreur", next(NS.errors or {}) == nil, next(NS.errors or {}))
end

-- 8. Contrastes des nouveaux textes, dans les deux styles ------------------------------------------------
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- 3.6 : contrastes (" .. style .. ")")
	Fresh()
	NS:DB().companionStyle = style
	NS:ApplyUIStyle()
	local Theme = NS.Theme
	local bad = {}
	for _, item in ipairs({
		{ "fiche : demi-tarif (orange)", Theme.ORANGE, Theme.NAV, 4.5 },
		{ "Échoppe : retour d'un cosmétique, mécénat (description)", Theme.MUTED_LIGHT, Theme.ROW, 4.5 },
		{ "Échoppe : prix ×1,5 (or)", Theme.GOLD, Theme.ROW, 4.5 },
		{ "Échoppe : nom de la ligne", Theme.LABEL, Theme.ROW, 4.5 },
		{ "Échoppe : tout possédé (phrase)", Theme.MUTED_LIGHT, Theme.WINDOW, 4.5 },
		{ "Échoppe : position de la ligne qui défile", Theme.MUTED_LIGHT, Theme.WINDOW, 4.5 },
		{ "Échoppe : détail de section (prix ×1,5, relance utilisée)", Theme.MUTED, Theme.WINDOW, 4.5 },
	}) do
		local c = Theme.Contrast(item[2], item[3])
		if c < item[4] then bad[#bad + 1] = item[1] .. string.format(" %.2f", c) end
	end
	Check("[L36A] " .. style .. " : contrastes des nouveaux textes (≥ 4,5, détail de section compris)", #bad == 0,
		table.concat(bad, ", "))
end
NS:DB().companionStyle = nil
NS:ApplyUIStyle()
