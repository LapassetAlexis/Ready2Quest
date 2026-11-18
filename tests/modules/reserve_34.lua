-- QC 3.4.0 (docs/design-reserve-3.4) : Réserve triée finement, profil et lien
-- du spécimen porté. SpecimenFilters.lua (protégé, surnom, indice de taille,
-- filtres OU / ET, compteurs, vues, tris), SpecimenBond.lua (points, plafonds
-- par jour, niveaux, potentiel, Codex non remplacé, migration),
-- CompanionEffects.lua (atout ×lien, revers et taille dès le lien 2, valeurs
-- signées, plancher de méfiance, paillettes de palier), échanges (clé x).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local function Fresh()
	ResetWorld()
	local capture = NS:CaptureData()
	capture.specimens, capture.codex, capture.creatures = {}, {}, {}
	capture.specNext, capture.specDirty, capture.specV = 1, nil, NS.SPECIMEN_SCHEMA
	capture.traitV = NS.SPECIMEN_TRAIT_SCHEMA
	capture.paillettes, capture.study, capture.resMyView = 0, nil, nil
	NS.reserveFacetCache, NS.effectCache = nil, nil
	return capture
end

local function Add(npc, stars, opts)
	opts = opts or {}
	local capture = NS:CaptureData()
	capture.creatures[npc] = capture.creatures[npc] or { name = opts.name or ("Bête " .. npc), normal = true, stars = stars,
		class = opts.class or "normal", type = opts.type or "Bête" }
	return NS:SpecimenAdd({ npc = npc, stars = stars, shiny = opts.shiny, name = opts.name or ("Bête " .. npc),
		origin = opts.origin or "capture", trait = opts.trait, size = opts.size, at = opts.at, zone = opts.zone })
end

-- 1. Protéger, surnom, indice de taille ------------------------------------------
do
	Say("-- 3.4 : protéger, surnom, indice de taille")
	Fresh()
	local ref = Add(900, 1, { trait = "curious", size = "normal" })
	local a = Add(900, 1, { trait = "lazy", size = "giant" })
	Check("[R34] protégé : jamais relâché ni échangé, raison dite", NS:SpecimenProtect(a, true) == true
		and select(2, NS:SpecimenCanRelease(a)) == "protected" and select(2, NS:SpecimenCanTrade(a)) == "protected"
		and NS:SpecimenProtect(a, false) == false and NS:SpecimenCanRelease(a) == true)
	local nick = NS:SpecimenSetNick(a, "  Bob|cffff0000 le grand " .. string.rep("é", 20))
	Check("[R34] surnom : nettoyé, 24 octets au plus, jamais un caractère coupé", nick ~= nil and #nick <= 24
		and not nick:find("|", 1, true) and nick:sub(1, 3) == "Bob" and NS:SpecimenDisplayName(a) == nick
		and NS:SpecimenSetNick(a, "   ") == nil and NS:SpecimenNick(a) == nil)
	local zi = NS:SpecimenSizeIndex(a)
	local derived = NS:SpecimenSizeIndex({ id = 7, size = "small" })
	Check("[R34] indice de taille : dans son cran (géant 119-125), tiré à la capture ; dérivé de l'id sinon, stable",
		zi >= 119 and zi <= 125 and NS:SpecimenGet(a).zi == zi and derived >= 82 and derived <= 93
		and derived == NS:SpecimenSizeIndex({ id = 7, size = "small" }) and NS:SpecimenSizeIndex({ id = 8 }) >= 94)
	Check("[R34] « Faire de la place » ne propose jamais un protégé", (function()
		NS:SpecimenProtect(a, true)
		for _, spec in ipairs(NS:ReserveTidyRanked()) do if spec.id == a then return false end end
		return true
	end)())
end

-- 2. Filtres OU / ET, compteurs, vues, tris ----------------------------------------
do
	Say("-- 3.4 : filtres, compteurs, vues, tris")
	Fresh()
	Add(900, 1, { trait = "glutton", size = "normal" }); Add(901, 1, { trait = "glutton", size = "normal" })   -- références
	Add(901, 1, { trait = "glutton", size = "normal", shiny = true })                                    -- référence brillante
	local a = Add(900, 1, { trait = "curious", size = "giant", at = 1000 })
	local b = Add(900, 2, { trait = "lazy", size = "normal", at = 2000 })   -- 2 étoiles : passe au Codex
	local c = Add(901, 1, { trait = "curious", size = "small", at = 3000 })
	local d = Add(901, 1, { trait = "zen", size = "giant", shiny = true, at = 4000 })
	local all = NS:ReserveQuery(nil)
	local f = NS:ReserveFilterNew()
	NS:ReserveFilterToggle(f, "trait", "curious")
	local curious = NS:ReserveQuery(f)
	NS:ReserveFilterToggle(f, "trait", "zen")
	local either = NS:ReserveQuery(f)
	NS:ReserveFilterToggle(f, "size", "giant")
	local both = NS:ReserveQuery(f)
	local ids = {}
	for _, spec in ipairs(both) do ids[spec.id] = true end
	Check("[R34] OU dans un groupe, ET entre groupes", #curious >= 2 and #either == #curious + 1
		and #both == 2 and ids[a] and ids[d] and not ids[c], #curious .. " " .. #either .. " " .. #both)
	local counts = NS:ReserveFacetCounts(f)
	Check("[R34] compteur d'une puce : ce qui resterait avec elle dans son groupe", counts.size.giant == #both
		and counts.trait.curious >= 1 and counts.version.shiny == 1, tostring(counts.size.giant))
	Check("[R34] compteurs gardés tant que rien ne bouge", NS:ReserveFacetCounts(f) == counts)
	local g = NS:ReserveFilterNew()
	g.q = "BETE 901"
	Check("[R34] recherche : nom sans accents ni casse", #NS:ReserveQuery(g) >= 1 and (function()
		for _, spec in ipairs(NS:ReserveQuery(g)) do if spec.npc ~= 901 then return false end end
		return true
	end)())
	local dup = NS:ReserveQuery(NS:ReserveView2("dup"))
	NS:SpecimenProtect(c, true)
	local protected = NS:ReserveQuery(NS:ReserveView2("protected"))
	Check("[R34] vues : doublons, protégés", #dup >= 3 and #protected == 1 and protected[1].id == c)
	local mine = NS:ReserveFilterNew()
	NS:ReserveFilterToggle(mine, "size", "giant")
	NS:ReserveSaveMyView(mine)
	Check("[R34] Ma vue : gardée au compte", #NS:ReserveQuery(NS:ReserveView2("mine")) == #NS:ReserveQuery(mine))
	local bySize = NS:ReserveQuery(nil, "size", true)
	local byDateUp = NS:ReserveQuery(nil, "date", false)
	Check("[R34] tris : taille (décroissant), date (croissant)", bySize[1].size == "giant"
		and (byDateUp[1].at or 0) <= (byDateUp[#byDateUp].at or 0) and #all == #bySize)
	local age = NS:ReserveFilterNew()
	NS:ReserveFilterToggle(age, "age", "7")
	NS:ReserveFilterToggle(age, "age", "30")
	Check("[R34] date de capture : une seule valeur à la fois", age.sets.age["30"] and not age.sets.age["7"])
end

-- 3. Lien : points, plafonds, niveaux, potentiel ------------------------------------
do
	Say("-- 3.4 : lien du spécimen porté")
	Fresh()
	local one = Add(950, 1, { trait = "daring", size = "giant" })
	NS:CompanionData().appearance = "cap:950"
	Check("[R34] le spécimen porté : la référence du Codex de l'apparence", NS:SpecimenWornHere() and NS:SpecimenWornHere().id == one)
	local got = 0
	for _ = 1, 10 do got = got + NS:SpecimenBondAdd("pet", 1) end
	Check("[R34] caresses : 2 points par jour au plus", got == 2 and NS:SpecimenBondPoints(one) == 2)
	for _ = 1, 10 do NS:SpecimenBondAdd("treat", 1); NS:SpecimenBondAdd("quest", 1); NS:SpecimenBondAdd("cap", 1) end
	NS:SpecimenBondAdd("route", 5)
	Check("[R34] 10 points par jour au plus", NS:SpecimenBondPoints(one) == 10, NS:SpecimenBondPoints(one))
	Check("[R34] lien 2 (Familier) à 10 points", NS:SpecimenBondLevel(one) == 2 and NS:SpecimenBondName(2) == NS.L.BOND_2)
	local spec = NS:SpecimenGet(one)
	spec.bond.p = 500
	Check("[R34] potentiel : 1 étoile, lien 3 au plus ; 3 étoiles, lien 5", NS:SpecimenBondLevel(one) == 3
		and NS:SpecimenBondPotential({ stars = 3 }) == 5 and NS:SpecimenBondPotential({ stars = 2 }) == 4
		and NS:SpecimenBondNext(one) == nil)
	spec.bond.day = "hier"
	local back = NS:SpecimenBondAdd("pet", 1)
	Check("[R34] un nouveau jour : les plafonds repartent", back == 1)
	NS:CompanionData().appearance = "cap:999"
	Check("[R34] pas porté : aucun point", NS:SpecimenBondAdd("pet", 1) == 0)
	-- Codex non remplacé : exemplaire lié
	NS:CompanionData().appearance = "cap:950"
	local better, place = Add(950, 3, { trait = "zen" })
	Check("[R34] exemplaire lié : un meilleur va en Réserve, relâchable et échangeable (avec confirmation)",
		place == "reserve" and NS:SpecimenIsReference(one) and NS:SpecimenBetterThanCodex(better)
		and NS:SpecimenCanRelease(better) == true and NS:SpecimenBetterLocked(better) == false)
	-- changer d'exemplaire porté en combat : refusé
	local savedCombat = rawget(_G, "InCombatLockdown")
	_G.InCombatLockdown = function() return true end
	local refused, why = NS:SpecimenSetReference(better)
	_G.InCombatLockdown = savedCombat
	Check("[R34] changer d'exemplaire porté : refusé en combat", refused == false and why == "combat" and NS:SpecimenIsReference(one))
end

-- 4. Profil : atout ×lien, revers et taille dès le lien 2 ---------------------------
do
	Say("-- 3.4 : profil (caractère, taille, lien)")
	Fresh()
	local spec = { trait = "curious", size = "giant", stars = 1 }
	local at1, at5 = NS:CompanionTraitEffect("curious", 1), NS:CompanionTraitEffect("curious", 5)
	Check("[R34] atout : la valeur d'avant au lien 1, ×2 au lien 5", math.abs(at1.value - 0.10) < 1e-9 and math.abs(at5.value - 0.20) < 1e-9)
	local e1, e2 = NS:CompanionProfileExtras(spec, 1), NS:CompanionProfileExtras(spec, 2)
	local kinds = {}
	for _, item in ipairs(e2) do kinds[item.id] = item end
	Check("[R34] lien 1 : seulement le second atout (Curieux) ; lien 2 : revers et effets de taille", #e1 == 1
		and e1[1].id == "plus_curious" and kinds.minus_curious and kinds.size_giant_named and kinds.size_giant_wary
		and kinds.minus_curious.value < 0 and kinds.size_giant_named.value > 0)
	local later = NS:CompanionProfileExtras(spec, 1, true)
	Check("[R34] fiche au lien 1 : revers montrés mais inactifs", #later == 5 and later[2].active == false)
	Check("[R34] Zen et Espiègle : pas de revers", #NS:CompanionProfileExtras({ trait = "zen" }, 5) == 0
		and #NS:CompanionProfileExtras({ trait = "mischievous" }, 5) == 0)
	Check("[R34] plancher de méfiance borné à [0,25 ; 0,60]", NS.CAPTURE_WARY_FLOOR_RANGE[1] == 0.25
		and NS.CAPTURE_WARY_FLOOR_RANGE[2] == 0.60 and NS:CompanionWaryFloor() == NS.CAPTURE_WARINESS.floor)
end

-- 5. Échange : l'indice voyage, pas le lien ----------------------------------------
do
	Say("-- 3.4 : échange")
	Fresh()
	Add(960, 1)
	local id = Add(960, 1, { size = "tiny", trait = "zen", name = string.rep("N", 48) })
	local spec = NS:SpecimenGet(id)
	spec.by, spec.nick, spec.lock, spec.bond = string.rep("B", 48), "Toto", true, { p = 40 }
	local text = NS:TradeEncodeSpec(id)
	local back = NS:TradeDecodeSpec(text)
	Check("[R34] échange : indice de taille transmis (clé x), ni surnom, ni cadenas, ni lien ; message ≤ 250",
		text and #text <= 250 and back and back.zi == NS:SpecimenSizeIndex(id) and not text:find("Toto", 1, true)
		and back.nick == nil and back.lock == nil and back.bond == nil, text and #text)
	local old = NS:TradeDecodeSpec(text:gsub(";?x=%d+", ""))
	Check("[R34] client 3.3 (sans x) : pas d'indice, le milieu du cran à l'arrivée", old and old.zi == nil)
end

-- 6. Étude d'espèce : pas de paiement rétroactif, captures seulement --------------
do
	Say("-- 3.4 : étude d'espèce")
	local capture = Fresh()
	capture.studyV = nil
	Add(970, 3, { trait = "zen", size = "tiny" })               -- avant la mise à jour (étude endormie)
	NS.studyDormant = false                                     -- la rétro passe à la première lecture
	local before = NS:Paillettes()
	local study = NS:SpecimenStudy(970)
	Check("[R34] rétro : capturée et trois étoiles cochées, rien payé", study.done.caught and study.done.stars3
		and NS:Paillettes() == before)
	local line = NS:SpecimenStudyLine(970)
	Check("[R34] fiche des Créatures : « Étude 2 / 5, reste : 5 captures, 3 tailles, 3 caractères · Records »",
		line:find("Étude 2 / 5, reste : 5 captures, 3 tailles, 3 caractères", 1, true) == 1 and line:find("Records : ", 1, true) ~= nil, line)
	for i, size in ipairs({ "small", "giant", "normal", "large" }) do
		Add(970, 1, { trait = i % 2 == 0 and "lazy" or "curious", size = size })
	end
	study = NS:SpecimenStudy(970)
	Check("[R34] étude : 5 captures, 3 tailles, 3 caractères : maîtrisée, payée après la mise à jour (3 × 2 + 5)",
		study.mastered and study.n == 5 and NS:Paillettes() == before + 3 * 2 + 5 and NS:SpecimenStudyMastered() == 1,
		NS:Paillettes() - before)
	Check("[R34] records : plus petit et plus grand indice de tes captures", study.lo and study.hi and study.lo <= 81 and study.hi >= 119)
	Check("[R34] maîtrisée : la fiche le dit", NS:SpecimenStudyLine(970):find("Espèce maîtrisée", 1, true) == 1)
	local paid = NS:Paillettes()
	Add(970, 1, { origin = "trade", trait = "daring", size = "giant" })
	Check("[R34] un spécimen reçu ne compte pas", NS:SpecimenStudy(970).n == 5 and NS:Paillettes() == paid)
	NS.studyDormant = true
end

-- 7. Échoppe : stock du jour, prix des places, plafond, surnom, commandes ------------
do
	Say("-- 3.4 : échoppe")
	local capture = Fresh()
	capture.paillettes, capture.slotBuys, capture.reserveBonus, capture.shopDay = 2000, nil, 20, nil
	Check("[R34] migration : 20 places achetées = 2 achats ; prochain : 40 + 20 × 2", NS:ShopSlotBuys() == 2 and NS:ShopSlotPrice() == 80)
	NS:CaptureData().items = {}
	local bought = 0
	for _ = 1, 3 do if NS:ShopBuy("lasso") then bought = bought + 1 end end
	Check("[R34] stock du jour : 2 lassos, le troisième refusé (« stock »)", bought == 2 and NS:ShopState("lasso") == "stock")
	capture.shopDay.day = "hier"
	Check("[R34] un nouveau jour : le stock revient", NS:ShopState("lasso") == "ok")
	local before = NS:Paillettes()
	NS:ShopBuy("slots")
	Check("[R34] places : +10 pour 80, puis 100", NS:ReserveCapacity() == NS.CAPTURE_RESERVE_BASE + 30
		and NS:Paillettes() == before - 80 and NS:ShopSlotPrice() == 100)
	capture.reserveBonus = 100
	Check("[R34] 150 places au plus : « max »", NS:ShopState("slots") == "max")
	local arrivals = NS:ShopArrivals()
	Check("[R34] arrivage : 2 cosmétiques de la semaine, les autres « absents »", #arrivals == 2
		and NS:ShopState(arrivals[1]) ~= "away" and (function()
			for _, item in ipairs(NS.PAILLETTES_SHOP) do
				if item.arrival and item ~= arrivals[1] and item ~= arrivals[2] and NS:ShopState(item) ~= "away" then return false end
			end
			return true
		end)())
	Add(980, 1, { trait = "zen", size = "large", zone = 1413 })
	local spec = Add(980, 1, { trait = "zen", size = "large", zone = 1413 })
	local nickOk = NS:ShopNickBuy(spec, "Gros Lard")
	Check("[R34] surnom : 15 paillettes", nickOk and NS:SpecimenNick(spec) == "Gros Lard")
	local orders = NS:ShopOrders()
	Check("[R34] commandes : 3 par semaine, une récompense de 12 à 16", #orders.list == 3 and orders.list[1].reward >= 12
		and orders.list[1].reward <= 16)
	orders.list[3] = { kind = "zone", zone = 1413, reward = 14 }
	local paid = NS:Paillettes()
	local ok = NS:ShopOrderDeliver(3, spec)
	Check("[R34] livrer : le spécimen part, la récompense arrive", ok and NS:SpecimenGet(spec) == nil and NS:Paillettes() == paid + 14)
	Check("[R34] livrer un spécimen qui ne correspond pas : refusé", select(2, NS:ShopOrderDeliver(1, Add(981, 1))) ~= nil)
end
