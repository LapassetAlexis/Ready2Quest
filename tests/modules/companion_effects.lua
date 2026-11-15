-- Le compagnon : ses effets de jeu et ses effets visuels.
--   1. Le compagnon actif (CompanionEffects.lua, 2.0) : la table des 8 types
--      (garde : chasse propre, confort, valeurs plafonnées, textes FR/EN), la
--      force (rang, brillante, étoiles, complétion), les envies, les mascottes,
--      le délai de 2 minutes, chaque enveloppe (capture, brillant, aides,
--      paliers, envies, repos, caresse), la confirmation qui compare, la page
--      Compagnon, la fiche, l'infobulle, la patte sur les barres de nom.
--   2. Les effets du style Azeroth (AzerothStyle.lua, 2.7.0) : bulle façon
--      « Talking Head », lueur ronde, éclats d'une brillante, évolution et
--      niveau, ailes des grandes récompenses, atlas manquants sans erreur,
--      changement de style à chaud.
-- 3.1.0 : affirme l'ancien habillage (carnet en parchemin, scènes en bois, bandeaux
-- dorés, anneau) : le drapeau QNS.AZEROTH_LEGACY rallumé pour tout le module
-- (remis à la valeur du produit à sa fin, tests/run_tests.lua)
T.Legacy(true)
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

-- 1. Le compagnon actif ---------------------------------------------------------------------------------
do
	local EF = { saved = {}, random = math.random, units = {} }
	-- 3.0.0 : le caractère du spécimen porté (tiré au hasard) ajoute son petit
	-- effet : neutralisé ici (ce module teste les effets de type), rendu à la fin
	EF.traitEffects = {}
	for k, v in pairs(NS.COMPANION_TRAIT_EFFECTS or {}) do EF.traitEffects[k] = v end
	for k in pairs(NS.COMPANION_TRAIT_EFFECTS or {}) do NS.COMPANION_TRAIT_EFFECTS[k] = nil end
	local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
		"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
		"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "C_NamePlate", "IsResting" }
	for _, name in ipairs(GLOBALS) do EF.saved[name] = rawget(_G, name) end
	EF.savedShiny = NS.SHINY_CHANCE
	EF.savedStars, EF.savedBonus = rawget(NS, "CaptureStars"), rawget(NS, "MenagerieTypeBonus")
	local PLAYER = "Player-1-00000001"

	function EF.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
	function EF.Install()
		local w = EF
		_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
		_G.UnitName = function(unit) local u = w.units[unit]; return u and u.name or "Testeur" end
		_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
		_G.UnitIsPlayer = function(unit) return unit == "player" end
		_G.UnitIsDead = function() return false end
		_G.UnitPlayerControlled = function() return false end
		_G.UnitReaction = function(unit) local u = w.units[unit]; return u and u.reaction or 2 end
		_G.UnitCanAttack = function() return true end
		_G.UnitClassification = function(unit) local u = w.units[unit]; return u and u.class or "normal" end
		_G.UnitCreatureType = function(unit) local u = w.units[unit]; return u and u.ctype or "Bête" end
		_G.UnitCreatureFamily = function() return nil end
		_G.UnitLevel = function() return 20 end
		_G.GetRaidTargetIndex = function() return nil end
		_G.SetRaidTarget = function() end
		_G.IsInGroup = function() return false end
		_G.UnitIsGroupLeader = function() return false end
		_G.IsInInstance = function() return false, "none" end
		_G.IsResting = function() return w.resting end
	end
	function EF.Reset()
		ResetWorld()
		for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt", "effectsConfirm" }) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
		NS.captureAppCache, NS.effectWasActive = nil, nil
		NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
		NS.CaptureStars, NS.MenagerieTypeBonus = EF.savedStars, EF.savedBonus
		EF.units, EF.resting = {}, false
		Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
		Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
		Mock.world.mapID, Mock.world.level = 1413, 20
		EF.Install()
		NS.SHINY_CHANCE = 0
		math.random = EF.random
		local data = NS:CompanionData()
		data.tutoDone, data.stage = true, 1
		for key in pairs(data.needs) do data.needs[key] = 80 end
		NS:TreatData().treatsInit = true
		NS:DB().companionCaptureAnim = false
		NS:CompanionUpdateVisibility()
	end
	function EF.Roll(value)
		math.random = function(a, b)
			if a and b then return EF.random(a, b) end
			if a then return EF.random(a) end
			return value
		end
	end
	-- une créature capturée de ce type et de ce rang
	function EF.Add(npc, ctype, class, shiny)
		local capture = NS:CaptureData()
		capture.creatures[npc] = { name = "Bête " .. npc, class = class or "normal", type = ctype, normal = true, at = npc,
			shiny = shiny or nil, shinyAt = shiny and npc or nil }
		capture.count = capture.count + 1
		NS.captureAppCache = nil
	end
	-- emmener une créature et laisser passer les 2 minutes
	function EF.Take(id, wait)
		NS:CompanionSetAppearance(id)
		if wait ~= false then Mock.now = Mock.now + NS.EFFECT_DELAY + 1 end
	end
	local function Near(a, b) return math.abs((a or 0) - (b or 0)) < 1e-6 end

	-- 1.1 La table des 8 types : chaque type, un effet de chasse propre et un de confort, modestes, nommés
	do
		Say("-- compagnon actif : la table des types")
		EF.Reset()
		local bad, seen, strings = {}, {}, NS.EFFECT_STRINGS
		for _, key in ipairs(NS.CREATURE_TYPES) do
			local pair = NS.COMPANION_TYPE_EFFECTS[key]
			if not (pair and NS.COMPANION_EFFECTS[pair.hunt] and NS.COMPANION_EFFECTS[pair.comfort]) then bad[#bad + 1] = key
			elseif seen[pair.hunt] then bad[#bad + 1] = key .. " (chasse en double)" end
			if pair then seen[pair.hunt] = true end
		end
		for id, def in pairs(NS.COMPANION_EFFECTS) do
			if def.cap > 1.5 or def.base > 0.5 then bad[#bad + 1] = id .. " (trop fort)" end
		end
		Check("[EFF] 8 types : chasse propre à chacun et confort, valeurs modestes et plafonnées", #NS.CREATURE_TYPES == 8
			and #bad == 0, table.concat(bad, ", "))
		local missing = {}
		for id in pairs(NS.COMPANION_EFFECTS) do
			if not (strings.fr["EFF_" .. id] and strings.en["EFF_" .. id]) then missing[#missing + 1] = id end
		end
		for key in pairs(strings.fr) do if strings.en[key] == nil then missing[#missing + 1] = "en:" .. key end end
		for key in pairs(strings.en) do if strings.fr[key] == nil then missing[#missing + 1] = "fr:" .. key end end
		Check("[EFF] textes : chaque effet en français et en anglais", #missing == 0, table.concat(missing, ", "))
	end

	-- 1.2 Force : rang, brillante, étoiles, complétion ; envies
	do
		Say("-- compagnon actif : force et envies")
		EF.Reset()
		EF.Add(5001, "Humanoïde", "normal")
		EF.Add(5002, "Humanoid", "elite")
		EF.Add(5003, "Humanoïde", "rare", true)
		EF.Add(5004, "Humanoïde", "worldboss")
		local function S(id) return NS:CompanionEffectsFor(id, { full = true }).strength end
		Check("[EFF] force : normal ×1, élite ×1,5 (type anglais compris), rare ×2, boss ×2,5, brillante +0,5", S("cap:5001") == 1
			and S("cap:5002") == 1.5 and S("cap:5003") == 2 and S("cap:5004") == 2.5 and S("cap:5003:s") == 2.5)
		NS.CaptureStars = function(_, npc, shiny) if npc == 5001 and not shiny then return 3 end return nil end
		local stars = S("cap:5001") == 1.5 and S("cap:5002") == 1.5
		NS.MenagerieTypeBonus = function(_, key) return key == "humanoid" and 0.5 or 0 end
		Check("[EFF] force : +0,25 par étoile au-dessus de 1, puis la complétion du type", stars and S("cap:5001") == 2)
		NS.CaptureStars, NS.MenagerieTypeBonus = EF.savedStars, EF.savedBonus
		local e = NS:CompanionEffectsFor("cap:5002", { full = true })
		Check("[EFF] Humanoïde élite : capture des Humanoïdes +15 %, friandise en plus aux paliers", e.typeKey == "humanoid"
			and e.hunt.id == "capture_humanoid" and Near(e.hunt.value, 0.15) and e.hunt.label == "capture des Humanoïdes +15 %"
			and e.comfort.id == "treat_zone" and Near(e.comfort.value, 0.225), e.hunt.label)
		local needs = NS:CompanionData().needs
		local full = Near(NS:CompanionEffectNeeds(), 1)
		needs.hunger, needs.energy = 30, 49
		local factor, ok = NS:CompanionEffectNeeds()
		local follows = Near(NS:CompanionEffectsFor("cap:5002").hunt.value, 0.15 * 0.75)
		for key in pairs(needs) do needs[key] = 15 end
		Check("[EFF] envies : ≥ 50 % pleine force, deux en dessous 75 % (la valeur suit), jamais sous la moitié", full
			and Near(factor, 0.75) and ok == 2 and follows and Near(NS:CompanionEffectNeeds(), 0.5))
		for key in pairs(needs) do needs[key] = 80 end
		EF.Add(5005, nil, "elite")
		EF.Add(5006, "Dragonkin", "worldboss", true)
		local general = NS:CompanionEffectsFor("cap:5005").mascot == true
		NS.CaptureStars = function() return 3 end
		NS.MenagerieTypeBonus = function() return 5 end
		local max = NS:CompanionEffectsFor("cap:5006:s", { full = true })
		Check("[EFF] type inconnu : l'effet général ; plafonds tenus au plus fort", general
			and max.hunt.value == NS.COMPANION_EFFECTS.shiny_chain.cap and max.comfort.value == NS.COMPANION_EFFECTS.decay_mood.cap)
		NS.CaptureStars, NS.MenagerieTypeBonus = EF.savedStars, EF.savedBonus
	end

	-- 1.3 Mascottes : l'étape d'évolution
	do
		Say("-- compagnon actif : mascottes")
		EF.Reset()
		local data = NS:CompanionData()
		data.appearance = NS.COMPANION_APPEARANCES[1].id
		data.stage = 1
		local e1 = NS:CompanionEffectsFor(NS.COMPANION_APPEARANCES[1])
		data.stage = 5
		local e5 = NS:CompanionEffectsFor(NS.COMPANION_APPEARANCES[1])
		Check("[EFF] mascotte : effet général, grandit avec l'étape (capture 2 → 10 %, envies 4 → 20 %)", e1.mascot
			and e1.typeKey == nil and e1.hunt.id == "capture_all" and e1.comfort.id == "mascot_decay" and Near(e1.hunt.value, 0.02)
			and Near(e5.hunt.value, 0.10) and Near(e1.comfort.value, 0.04) and Near(e5.comfort.value, 0.20))
		data.stage = 1
	end

	-- 1.4 Délai de 2 minutes, contrat
	do
		Say("-- compagnon actif : délai et contrat")
		EF.Reset()
		EF.Add(5101, "Humanoïde", "normal")
		local first = NS:CompanionEffects()
		local starts = first.active == false and first.remaining == NS.EFFECT_DELAY
		Mock.now = Mock.now + NS.EFFECT_DELAY
		Check("[EFF] premier relevé : le délai démarre ; mascotte active au bout de 2 min", starts and NS:CompanionEffects().active == true
			and Near(NS:CompanionEffectValue("capture_all"), 0.02))
		NS:CompanionEffectsTick()
		NS:CompanionSetAppearance(NS.COMPANION_APPEARANCES[2].id)
		NS:CompanionData().unlocked["app:" .. NS.COMPANION_APPEARANCES[2].id] = true
		NS:CompanionSetAppearance(NS.COMPANION_APPEARANCES[2].id)
		local same = NS:CompanionEffects().active == true
		NS:CompanionSetAppearance("cap:5101")
		local e = NS:CompanionEffects()
		Check("[EFF] mascotte vers mascotte : délai inchangé ; nouvelle créature : pas encore active, valeur 0", same
			and e.active == false and e.typeKey == "humanoid" and e.remaining == NS.EFFECT_DELAY
			and e.activeAt == math.floor(Mock.now) + NS.EFFECT_DELAY and NS:CompanionEffectValue("capture_humanoid") == 0)
		Check("[EFF] contrat : hunt / comfort { id, value, label }", e.hunt.id == "capture_humanoid" and e.hunt.value > 0
			and type(e.hunt.label) == "string" and e.comfort.id == "treat_zone" and e.strength == 1)
		local function Said()
			for _, line in ipairs(Mock.output) do if tostring(line):find("actifs", 1, true) then return true end end
			return false
		end
		Mock.output = {}
		Mock.now = Mock.now + 60
		NS:CompanionEffectsTick()
		local half = NS:CompanionEffects().remaining == 60
		Mock.now = Mock.now + 60
		NS:CompanionEffectsTick()
		local active = NS:CompanionEffects().active and Near(NS:CompanionEffectValue("capture_humanoid"), 0.10) and Said()
		Mock.output = {}
		NS:CompanionEffectsTick()
		Check("[EFF] à mi-chemin : pas encore ; au bout de 2 min : active, annoncée une fois", half and active and not Said())
		local other = NS:CompanionEffectValue("shiny_undead") == 0
		NS:DB().companionEnabled = false
		Check("[EFF] autre effet : 0 ; compagnon coupé : aucun effet", other and NS:CompanionEffectValue("capture_humanoid") == 0)
		NS:DB().companionEnabled = true
	end

	-- 1.5 Enveloppes : capture et brillant
	do
		Say("-- compagnon actif : capture et brillant")
		EF.Reset()
		EF.Add(5201, "Humanoïde", "rare")
		EF.Take("cap:5201")
		local function Pct(info) return math.floor(NS:CaptureChance(info, nil, 20) * 100 + 0.5 + 1e-9) end
		Check("[EFF] Humanoïde rare : capture des Humanoïdes ×1,2 (50 → 60 %), pas sur une Bête, chance de base à part",
			Pct({ class = "normal", level = 20, type = "Humanoïde" }) == 60 and Pct({ class = "normal", level = 20, type = "Bête" }) == 50
			and math.floor(NS:CaptureChanceBase({ class = "normal", level = 20, type = "Humanoïde" }, nil, 20) * 100 + 0.5) == 50)
		local chance, sure = NS:CaptureChance({ class = "normal", type = "Humanoïde" }, "sifflet")
		Check("[EFF] sifflet : toujours assuré ; plafond de 95 % tenu", chance == 1 and sure == true
			and Pct({ class = "normal", level = 1, type = "Humanoïde" }) <= 95
			and math.floor(NS:CaptureChance({ class = "normal", level = 1, type = "Humanoïde" }, "lasso", 60) * 100 + 0.5) == 95)
		EF.Add(5202, "Démon", "elite")
		EF.Take("cap:5202")
		Check("[EFF] Démon élite : élites ×1,18 (25 → 30 %), pas sur un normal", Pct({ class = "elite", level = 20, type = "Bête" }) == 30
			and Pct({ class = "normal", level = 20, type = "Bête" }) == 50)
		EF.Add(5203, "Bête", "normal")
		EF.Take("cap:5203")
		Check("[EFF] Bête : +5 % sur une Bête pas encore capturée, rien sur une espèce déjà capturée",
			Pct({ class = "normal", level = 20, type = "Bête", npcID = 6001 }) == 53
			and Pct({ class = "normal", level = 20, type = "Bête", npcID = 5203 }) == 50)
		-- Mort-vivant : brillant des Morts-vivants ; pendant le tirage d'une unité : son type à elle
		NS.SHINY_CHANCE = 1 / 150
		EF.Add(5204, "Mort-vivant", "rare")
		EF.Take("cap:5204")
		local undead = Near(NS:ShinyChance("normal", 0, "undead"), 1.3 / 150) and Near(NS:ShinyChance("normal", 0, "beast"), 1 / 150)
		local seenType
		local before = NS.ShinyChance
		EF.units.target = { guid = EF.Guid(7001), ctype = "Mort-vivant" }
		EF.Roll(0.999)
		NS.ShinyChance = function(self, class, killed, typeKey) seenType = typeKey or self.effectShinyType; return 0 end
		NS:ShinyRoll("target", { npcID = 7001 })
		NS.ShinyChance = before
		Check("[EFF] Mort-vivant rare : brillant des Morts-vivants ×1,3 ; le tirage connaît le type de l'unité", undead
			and seenType == "undead" and NS.effectShinyType == nil)
		-- type secret (Forever) : CreatureTypeKey passe par ns.Plain ; en erreur, le tirage se fait quand même
		local savedSecret = rawget(_G, "issecretvalue")
		_G.issecretvalue = function(v) return v == "Mort-vivant" end
		local secret = pcall(NS.CreatureTypeKey, NS, "Mort-vivant") and NS:CreatureTypeKey("Mort-vivant") == nil
			and NS:CreatureTypeKey("Bête") == "beast"
		_G.issecretvalue = savedSecret
		local savedKey = NS.CreatureTypeKey
		NS.CreatureTypeKey = function() error("valeur secrète") end
		seenType = "?"
		NS.ShinyChance = function(self, class, killed, typeKey) seenType = typeKey or self.effectShinyType; return 0 end
		local rolled = pcall(NS.ShinyRoll, NS, "target", { npcID = 7001 })
		NS.ShinyChance, NS.CreatureTypeKey = before, savedKey
		Check("[EFF] type secret : pas de clé, sans erreur ; type illisible : ShinyRoll ne tombe pas, sans bonus", secret
			and rolled and seenType == nil, tostring(seenType))
		EF.Add(5205, "Draconien", "normal")
		EF.Take("cap:5205")
		Check("[EFF] Draconien : 20 abattus comptent 30, le plafond de la chasse reste",
			Near(NS:ShinyChance("normal", 20), (1 / 150) * (1 + 2.75 * 30 / 50)) and Near(NS:ShinyChance("normal", 500), 1 / 40))
		NS.SHINY_CHANCE = 0
	end

	-- 1.6 Enveloppes : aides, paliers
	do
		Say("-- compagnon actif : aides et paliers")
		EF.Reset()
		EF.Add(5301, "Élémentaire", "normal")
		EF.Take("cap:5301")
		NS:CaptureData().items.appat = 2
		EF.Roll(0)
		local kept = NS:CaptureSpend("appat") == true and NS:CaptureData().items.appat == 2
		EF.Roll(0.99)
		local spent = NS:CaptureSpend("appat") == true and NS:CaptureData().items.appat == 1
		NS:CaptureData().items.appat = 0
		EF.Roll(0)
		Check("[EFF] Élémentaire : aide parfois gardée, sinon consommée, rien sans aide en poche", kept and spent
			and NS:CaptureSpend("appat") == false)
		EF.Add(5302, "Mécanique", "normal")
		EF.Take("cap:5302")
		NS:CaptureData().items.lasso = 0
		EF.Roll(0)
		NS:CaptureResolve({ success = false, aid = "lasso", target = { npcID = 7100, name = "Loup", class = "normal" } })
		local back = NS:CaptureData().items.lasso == 1
		EF.Roll(0.99)
		NS:CaptureResolve({ success = false, aid = "lasso", target = { npcID = 7100, name = "Loup", class = "normal" } })
		Check("[EFF] Mécanique : capture ratée, le lasso revient (pas toujours)", back and NS:CaptureData().items.lasso == 1)
		local saved = NS.ZoneCompletion
		NS.ZoneCompletion = function() return { percent = 30, parts = { {}, {} } } end
		EF.Add(5303, "Géant", "elite")
		EF.Take("cap:5303")
		local items = NS:CaptureData().items
		items.appat, items.lasso, items.sifflet = 0, 0, 0
		NS:TreatData().milestones[1413] = nil
		EF.Roll(0)
		local gained = NS:TreatCheckZone(1413)
		Check("[EFF] Géant : palier de zone, une aide en plus", items.appat + items.lasso + items.sifflet == 2,
			#gained .. " / " .. items.appat .. items.lasso .. items.sifflet)
		EF.Add(5304, "Humanoïde", "normal")
		EF.Take("cap:5304")
		local pantry = NS:TreatData().pantry
		local function Sum() local n = 0 for _, v in pairs(pantry) do n = n + v end return n end
		-- garde-manger vide : la friandise tirée ne peut pas être mangée sur place (plafond 3)
		for kind in pairs(pantry) do pantry[kind] = 0 end
		NS:TreatData().milestones[1414] = nil
		EF.Roll(0)
		NS:TreatCheckZone(1414)
		local live = Sum()
		NS:TreatData().milestones[1415] = nil
		for kind in pairs(pantry) do pantry[kind] = 0 end
		NS:TreatCheckZone(1415, { quiet = true })
		Check("[EFF] Humanoïde : palier de zone, une friandise en plus ; rattrapage (mise à jour) : pas d'effet rétroactif",
			live == 2 and Sum() == 1, live .. " / " .. Sum())
		NS.ZoneCompletion = saved
	end

	-- 1.7 Enveloppes : envies, repos, caresses
	do
		Say("-- compagnon actif : confort")
		EF.Reset()
		-- sans caractère : seul l'effet joue
		local savedTrait = NS.CompanionTrait
		NS.CompanionTrait = function() return nil end
		EF.Add(5401, "Bête", "rare")
		EF.Take("cap:5401")
		local base = NS.COMPANION_RULES.decay
		local hunger = NS:CompanionDecayFactor("hunger")
		local needs = NS:CompanionData().needs
		needs.hunger = 80
		NS:CompanionTick(600)
		Check("[EFF] Bête rare : la faim baisse 20 % moins vite (le tick le suit), les autres envies comme avant", Near(hunger, 0.8)
			and Near(NS:CompanionDecayFactor("energy"), 1)
			and Near(needs.hunger, 80 - base.hunger * 10 * NS:CompanionDecayFactor("hunger")), tostring(needs.hunger))
		EF.Add(5402, "Géant", "normal")
		EF.Take("cap:5402")
		local ratio = NS:CompanionDecayFactor("mood")
		NS:CompanionData().appearance = NS.COMPANION_APPEARANCES[1].id
		NS:CompanionEffectsSync()
		Mock.now = Mock.now + NS.EFFECT_DELAY + 1
		local mascot = NS:CompanionDecayFactor("mood")
		Check("[EFF] Géant : toutes les envies 5 % moins vite", Near(ratio / mascot, 0.95 / 0.96), ratio .. " / " .. mascot)
		EF.Add(5403, "Mécanique", "normal")
		EF.Take("cap:5403")
		EF.resting = true
		needs.energy = 40
		NS:CompanionTick(60)
		-- l'énergie à 40 : une envie sous 50 %, force à 87,5 %
		Check("[EFF] Mécanique : au repos, l'énergie remonte 15 % plus vite (moins, envie basse)",
			Near(needs.energy, 40 + NS.COMPANION_RULES.restGain * (1 + 0.15 * 0.875)), tostring(needs.energy))
		EF.resting = false
		EF.Add(5404, "Démon", "normal")
		EF.Take("cap:5404")
		needs.mood, needs.energy, needs.hunger = 50, 80, 80
		NS.companionLastPet = nil
		NS:CompanionPet()
		local pet = Near(needs.mood, 50 + 8 * 1.25)
		-- le garde-manger (Maj + clic) rend vrai aussi : pas de moral gratuit ; caresse refusée (délai) non plus
		local savedShift = rawget(_G, "IsShiftKeyDown")
		_G.IsShiftKeyDown = function() return true end
		needs.mood = 50
		NS.companionLastPet = nil
		local opened = NS:CompanionPet()
		_G.IsShiftKeyDown = savedShift
		if NS.treatMenu then NS.treatMenu:Hide() end
		local pantryFree = opened and needs.mood == 50
		NS:CompanionPet()
		local after = needs.mood
		NS:CompanionPet()
		Check("[EFF] Démon : une caresse +25 % de moral ; ni le garde-manger (Maj + clic) ni une caresse trop rapprochée",
			pet and pantryFree and needs.mood == after, tostring(needs.mood))
		NS.CompanionTrait = savedTrait
	end

	-- 1.8 Confirmation qui compare
	do
		Say("-- compagnon actif : confirmation")
		EF.Reset()
		EF.Add(5501, "Mort-vivant", "elite")
		local data = NS:CompanionData()
		data.appearance = NS.COMPANION_APPEARANCES[1].id
		data.unlocked["app:" .. NS.COMPANION_APPEARANCES[2].id] = true
		local done = 0
		Check("[EFF] mascotte vers mascotte : pas de question ; verrouillée : refusée",
			NS:CompanionAskAppearance(NS.COMPANION_APPEARANCES[2].id, function() done = done + 1 end) ~= "ask"
			and data.appearance == NS.COMPANION_APPEARANCES[2].id and done == 1 and NS:CompanionAskAppearance("owl") == nil)
		local asks = NS:CompanionAskAppearance("cap:5501", function() done = done + 1 end) == "ask"
			and NS.effectsConfirm:IsShown() and data.appearance ~= "cap:5501"
		local text = NS.effectsConfirm.text.text or ""
		Check("[EFF] vers une créature : la question, qui compare les effets d'aujourd'hui et du nouveau", asks
			and text:find("capture +2 %", 1, true) and text:find("Morts-vivants +23 %", 1, true) and text:find("Bête 5501", 1, true), text)
		NS:CompanionConfirmAnswer(false)
		local cancel = data.appearance ~= "cap:5501" and not NS.effectsConfirm:IsShown() and done == 1
		NS:CompanionAskAppearance("cap:5501", function() done = done + 1 end)
		Mock.output = {}
		NS:CompanionConfirmAnswer(true)
		Check("[EFF] Annuler : rien ne change ; Emmener : fait, le délai démarre, annoncé", cancel and data.appearance == "cap:5501"
			and done == 2 and NS:CompanionEffects().active == false and (Mock.output[#Mock.output] or ""):find("2 minutes", 1, true) ~= nil)
		local row
		for _, page in ipairs(NS.OPTION_PAGES or {}) do
			for _, r in ipairs(page.rows or {}) do if r.key == "companionAppearance" then row = r end end
		end
		data.appearance = NS.COMPANION_APPEARANCES[1].id
		row.choose("cap:5501")
		Check("[EFF] réglages : la liste demande aussi", NS.effectsConfirm:IsShown() and data.appearance ~= "cap:5501")
		NS:CompanionConfirmAnswer(false)
	end

	-- 1.9 Affichage : page Compagnon, fiche, infobulle
	do
		Say("-- compagnon actif : affichage")
		EF.Reset()
		EF.Add(5601, "Humanoïde", "elite")
		NS:CompanionSetAppearance("cap:5601")
		NS:DB().journalTracker = false
		NS:ToggleJournal(true)
		local f = NS.journalFrame
		f.sections.evolution:Click()
		local evo = f.evo
		local page = evo.effHunt.text == "Chasse : capture des Humanoïdes +15 %" and (evo.effComfort.text or ""):find("^Confort : ") ~= nil
			and (evo.effState.text or ""):find("Force ×1,5", 1, true) and evo.effState.text:find("Actifs dans 2:00", 1, true)
		Mock.now = Mock.now + 75
		NS:CompanionEffectsTick()
		local counting = evo.effState.text:find("Actifs dans 0:45", 1, true)
		Mock.now = Mock.now + 60
		NS:CompanionEffectsTick()
		Check("[EFF] page Compagnon : chasse, confort, force et compte à rebours qui avance, puis « Actifs »", page and counting
			and evo.effState.text:find("Actifs$") ~= nil, evo.effState.text)
		f:Hide()
		local lines = NS:CompanionEffectsLines({ npc = 5601, known = true, class = "elite", type = "Humanoïde" }, false)
		Check("[EFF] fiche : « Chasse / Confort » avec ses valeurs, la brillante plus forte, une inconnue rien",
			lines[1] == "Chasse : capture des Humanoïdes +15 %" and lines[2]:find("^Confort : 23 %%") ~= nil
			and NS:CompanionEffectsLines({ npc = 5601, known = true, class = "elite", type = "Humanoïde" }, true)[1]
				== "Chasse : capture des Humanoïdes +20 %" and #NS:CompanionEffectsLines({ npc = 5601, known = false }) == 0, tostring(lines[2]))
		NS:BestiaryData()[1413] = { [7301] = { name = "Bandit", class = "normal", type = "Humanoïde", seen = true, level = 20 } }
		local text = NS:BestiaryTooltipLine(EF.Guid(7301), 20)
		NS:BestiaryData()[1413][7302] = { name = "Loup", class = "normal", type = "Bête", seen = true, level = 20 }
		Check("[EFF] infobulle : « à capturer · 58 % (+8) », sans bonus comme avant", text == "Créatures : à capturer · 58 % (+8)"
			and NS:BestiaryTooltipLine(EF.Guid(7302), 20) == "Créatures : à capturer · 50 %", text)
	end

	-- 1.10 Patte sur les barres de nom (repérage)
	do
		Say("-- compagnon actif : patte de repérage")
		EF.Reset()
		local plates = {}
		_G.C_NamePlate = {
			GetNamePlateForUnit = function(unit) return plates[unit] end,
			GetNamePlates = function() local list = {} for _, p in pairs(plates) do list[#list + 1] = p end return list end,
		}
		local function Plate(unit, npc, ctype, extra)
			local plate = CreateFrame("Frame")
			plate.namePlateUnitToken = unit
			plates[unit] = plate
			EF.units[unit] = { guid = EF.Guid(npc), ctype = ctype }
			for k, v in pairs(extra or {}) do EF.units[unit][k] = v end
			return plate
		end
		local function Marked(plate) return NS.effectPlateMarks[plate] ~= nil and NS.effectPlateMarks[plate]:IsShown() end
		NS.effectPlates = {}
		local wolf = Plate("nameplate1", 7401, "Bête")
		local bandit = Plate("nameplate2", 7402, "Humanoïde")
		local caught = Plate("nameplate3", 7403, "Bête")
		local friend = Plate("nameplate4", 7404, "Bête", { reaction = 5 })
		EF.Add(7403, "Bête", "normal")
		NS:EffectPlatesRefresh()
		local none = not Marked(wolf)
		EF.Add(5701, "Bête", "normal")
		EF.Take("cap:5701", false)
		NS:EffectPlatesRefresh()
		Check("[EFF] sans l'effet, ou Bête emmenée pas encore active : aucune patte", none and not Marked(wolf))
		Mock.now = Mock.now + NS.EFFECT_DELAY + 1
		NS:CompanionEffectsTick()
		local mark = NS.effectPlateMarks[wolf]
		Check("[EFF] active : patte au-dessus de la barre de la Bête pas encore capturée (icône de pistage)", mark and mark:IsShown()
			and mark:GetParent() == wolf and mark.lastPoint and mark.lastPoint.point == "BOTTOM" and mark.lastPoint.relPoint == "TOP"
			and mark.icon.texture == NS.EFFECT_PAW)
		Check("[EFF] pas sur un Humanoïde, une espèce déjà capturée, une créature amicale", not Marked(bandit) and not Marked(caught)
			and not Marked(friend))
		NS:DB().companionEffectPlate = false
		NS:EffectPlatesRefresh()
		local off = not mark:IsShown()
		NS:DB().companionEffectPlate = true
		NS:EffectPlatesRefresh()
		NS:CaptureResolve({ success = true, target = { npcID = 7401, name = "Loup", class = "normal", type = "Bête" } })
		local gone = not mark:IsShown()
		NS.EventDeliver("effects", "NAME_PLATE_UNIT_REMOVED", "nameplate1")
		Check("[EFF] réglage coupé : cachée ; capturée : la patte s'en va ; barre retirée : oubliée", off and gone
			and NS.effectPlates.nameplate1 == nil)
		local function onEvent(_, event, ...) return NS.EventDeliver("effects", event, ...) end
		local fox = Plate("nameplate5", 7405, "Bête")
		onEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate5")
		Check("[EFF] barre ajoutée, repérage actif : patte posée", Marked(fox))
		EF.Add(5702, "Humanoïde", "normal")
		EF.Take("cap:5702")
		NS:EffectPlatesRefresh()
		local lookups, effects = 0, 0
		local getPlate = _G.C_NamePlate.GetNamePlateForUnit
		_G.C_NamePlate.GetNamePlateForUnit = function(unit) lookups = lookups + 1; return getPlate(unit) end
		local savedEffects = NS.CompanionEffects
		NS.CompanionEffects = function(...) effects = effects + 1; return savedEffects(...) end
		for index = 1, 20 do
			Plate("nameplate" .. (10 + index), 7500 + index, "Bête")
			onEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate" .. (10 + index))
		end
		NS.CompanionEffects = savedEffects
		_G.C_NamePlate.GetNamePlateForUnit = getPlate
		Check("[EFF] sans repérage : 20 barres ajoutées, ni barre lue ni effets recalculés", lookups == 0 and effects == 0,
			lookups .. " / " .. effects)
		-- retours secrets du client : pas de patte, sans erreur
		local savedSecret = rawget(_G, "issecretvalue")
		_G.issecretvalue = function(v) return v == true end
		_G.UnitIsPlayer = function() return true end
		Check("[EFF] UnitIsPlayer secret : lu par ns.Plain, sans erreur", pcall(NS.EffectSpotUnit, NS, "nameplate5", "beast"))
		_G.issecretvalue = savedSecret
		EF.Install()
		NS.effectPlates = {}
	end

	-- fin
	for _, name in ipairs(GLOBALS) do _G[name] = EF.saved[name] end
	for k, v in pairs(EF.traitEffects) do NS.COMPANION_TRAIT_EFFECTS[k] = v end
	math.random = EF.random
	NS.SHINY_CHANCE = EF.savedShiny
	NS.CaptureStars, NS.MenagerieTypeBonus = EF.savedStars, EF.savedBonus
	NS:CompanionData().appearance = NS.COMPANION_APPEARANCES[1].id
	ResetWorld()
end

-- 2. Les effets du style Azeroth ------------------------------------------------------------------------
do
	local FXT = { saved = {}, units = {}, savedHappy = NS.CompanionIsHappy }
	local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitLevel", "SetRaidTarget",
		"GetRaidTargetIndex", "InCombatLockdown", "UnitAffectingCombat", "C_Texture" }
	for _, name in ipairs(GLOBALS) do FXT.saved[name] = rawget(_G, name) end
	local A = NS.AZEROTH_FX_ATLAS
	local C = NS.AZEROTH_FX

	function FXT.Reset(atlas)
		ResetWorld()
		for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalToast" }) do
			if NS[field] then NS[field]:Hide() end
			NS[field] = nil
		end
		NS.uiStyleCache = {}
		NS.companionRT, NS.companionSession, NS.companionFx, NS.notifyState, NS.shinyState, NS.azFx = nil, nil, nil, nil, nil, nil
		NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
		NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
		Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
		Mock.world.mapID, Mock.world.level = 1413, 20
		_G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
		_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = FXT.units[unit]; return u and u.name end
		_G.UnitExists = function(unit) return unit == "player" end
		_G.UnitIsPlayer = function(unit) return unit == "player" end
		_G.UnitLevel = function() return 20 end
		_G.SetRaidTarget = function() end
		_G.GetRaidTargetIndex = function() return nil end
		_G.InCombatLockdown = function() return false end
		_G.UnitAffectingCombat = function() return false end
		if atlas == false then Mock.InstallAtlas(nil) else Mock.InstallAtlas(atlas or true) end
		NS:AzerothAtlasOK(true)
		NS:DB().companionStyle = "azeroth"
		NS:CompanionData().tutoDone = true
		NS.CompanionIsHappy = FXT.savedHappy
		NS:CompanionUpdateVisibility()
		return NS:EnsureCompanionFrame()
	end
	local function Quiet()
		NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
		if NS.companionRT then NS.companionRT.cool = {} end
	end
	local function Speak()
		Quiet()
		return NS:CompanionSay("EAT", { force = true })
	end
	-- fait tourner les horloges (Notify : la lueur ; AzerothStyle : les effets)
	local function Run(seconds, step)
		step = step or 0.1
		local t = 0
		while t < seconds - 1e-6 do Mock:Advance(step); t = t + step end
	end
	local function Edges(frame)
		for _, tex in ipairs(type(frame.glow) == "table" and frame.glow or {}) do if tex:IsShown() then return true end end
		return false
	end

	-- 2.1 La bulle Talking Head
	do
		Say("-- effets azeroth : bulle façon Talking Head")
		local frame = FXT.Reset()
		local spoke = Speak() == true
		local bubble = NS.companionBubble
		local skin = bubble and bubble.azTalk
		-- 2.8.2 : le parchemin des hauts faits (130661) par son fichier, recadré
		Check("[FX] il parle : bulle de parchemin, texte brun foncé sans ombre, le nom en capitales en haut", frame
			and frame.uiStyle == "azeroth" and spoke and skin and bubble.azBubble and skin.bg.texture == 130661
			and skin.bg.texCoord and skin.bg:IsShown() and skin.text:GetText() == NS.companionBubbleText
			and skin.text.textColor[1] < 0.3 and skin.text.textColor[3] < 0.1 and skin.text.shadow and skin.text.shadow[4] == 0
			and skin.name:GetText() == NS.AzerothUpper(NS:CompanionName()) and skin.name:IsShown())
		Check("[FX] l'habit Sobre masqué ; la bulle ne prend pas la souris, ancrée au-dessus du cadre", bubble.bg.mockHidden
			and bubble.rule.mockHidden and bubble.tail.mockHidden and bubble.text.mockHidden and bubble.border.top.mockHidden
			and not bubble.mouseEnabled and select(2, bubble:GetPoint(1)) == frame and select(3, bubble:GetPoint(1)) == "TOP")
		local short = bubble:GetHeight()
		local wide = bubble:GetWidth() == C.bubbleW and short >= C.bubbleMin
		bubble:SetText(string.rep("Un très long bavardage du compagnon sur la route. ", 6))
		local grows = bubble:GetHeight() > short
		bubble:SetText("Court.", 28)
		Check("[FX] largeur Talking Head, la hauteur suit le texte et la rangée de boutons du tutoriel", wide and grows
			and bubble:GetHeight() >= 30 + 14 + 18 + 28, tostring(bubble:GetHeight()))
		Run(0.3)
		local sheen = skin.sheen and skin.sheen:IsShown()
		Run(1)
		Check("[FX] un reflet passe sur le parchemin, puis s'en va", sheen and not skin.sheen:IsShown())
	end

	-- 2.2 La lueur ronde quand il parle
	do
		Say("-- effets azeroth : lueur ronde")
		local frame = FXT.Reset()
		Speak()
		Run(0.5)
		local glow = frame.azGlow
		Check("[FX] il parle : lueur ronde dorée centrée sur l'anneau, pas de liseré rectangulaire", glow and glow:IsShown()
			and glow.atlas == A.circle and glow.blendMode == "ADD" and glow.vertex[3] < 0.5 and glow.drawLayer == "BACKGROUND"
			and select(2, glow:GetPoint(1)) == frame and select(5, glow:GetPoint(1)) == NS.AZEROTH_RING.y and not Edges(frame))
		local a1, s1 = glow.alpha, glow:GetWidth()
		Run(1.1)
		local breathes = math.abs(glow.alpha - a1) > 0.05 and glow:GetWidth() ~= s1
		NS:CompanionHideBubble()
		Run(1)
		Check("[FX] elle respire ; la bulle finie, elle s'éteint", breathes and not glow:IsShown())
		NS:SetUIStyle("sobre")
		Speak()
		Run(0.3)
		Check("[FX] Sobre : le liseré pulse, la bulle d'avant revient, pas de lueur ronde", Edges(frame) and not glow:IsShown()
			and not NS.companionBubble.azBubble and NS.companionBubble.bg:IsShown() and NS.companionBubble.text:IsShown()
			and not NS.companionBubble.azTalk.bg:IsShown())
		NS:SetUIStyle("azeroth")
		Run(0.3)
		Check("[FX] retour en Azeroth à chaud : bulle rhabillée, lueur ronde, liseré éteint", NS.companionBubble.azBubble
			and NS.companionBubble.azTalk.text:GetText() == NS.companionBubbleText and glow:IsShown() and not Edges(frame))
		NS:CompanionHideBubble()
		Run(1)
	end

	-- 2.3 Brillante repérée
	do
		Say("-- effets azeroth : brillante repérée")
		local frame = FXT.Reset()
		FXT.units.target = { name = "Raptor brillant" }
		local live = NS:ShinySpot("target", "Creature-0-1-1-1-7100-0000AA", { zoneID = 1413, npcID = 7100 }, { name = "Raptor brillant" })
		Run(1.5)
		local sparks = frame.azSparks
		local shown = 0
		for _, tex in ipairs(sparks or {}) do if tex:IsShown() and (tex.alpha or 0) > 0 then shown = shown + 1 end end
		Check("[FX] brillante : 4 éclats d'étoile décalés, sur un calque sans souris au-dessus du cadre, la lueur bat plus vite",
			live ~= nil and NS.azFx and NS.azFx.shinyUntil ~= nil and sparks and #sparks == 4 and sparks[1].atlas == A.star
			and sparks[1].blendMode == "ADD" and shown >= 2 and sparks[1].alpha ~= sparks[3].alpha and frame.azFxLayer
			and not frame.azFxLayer.mouseEnabled and frame.azFxLayer:GetFrameLevel() > frame:GetFrameLevel()
			and frame.azGlow and frame.azGlow:IsShown() and select(2, NS:AzerothGlowEnvelope(NS.Now())), tostring(shown))
		NS:CompanionHideBubble()
		Run(C.shinyTime + 1)
		local any = false
		for _, tex in ipairs(sparks) do if tex:IsShown() then any = true end end
		Check("[FX] … puis tout s'éteint, horloge des effets retirée au repos", not any and not frame.azGlow:IsShown()
			and NS.azFx.sparkAt == nil and NS.azFxDriver and not NS.azFxDriver.running and NS.azFxDriver.scripts.OnUpdate == nil)
	end

	-- 2.4 Évolution et niveau
	do
		Say("-- effets azeroth : évolution et niveau")
		local frame = FXT.Reset()
		NS:CompanionData().stage = 2
		NS.CompanionIsHappy = function() return true end
		Quiet()
		local evolved = NS:CompanionCheckStage(20, true)
		local parts = frame.azLevel
		local group = parts and parts.group
		Check("[FX] évolution : « Aguerri ! » entre deux volutes collées au texte, groupe compact au-dessus du cadre, sans souris",
			evolved == true and NS.azFx.level and NS.azFx.level.kind == "evolve" and group and group:IsShown()
			and group.text:GetText() == "Aguerri !" and group.left.atlas == A.filigree and group.right.atlas == A.filigree
			and select(2, group.left:GetPoint(1)) == group.text and select(3, group.left:GetPoint(1)) == "LEFT"
			and select(2, group.right:GetPoint(1)) == group.text and group:GetHeight() <= 30
			and select(2, group:GetPoint(1)) == frame and select(3, group:GetPoint(1)) == "TOP"
			and not group.mouseEnabled and not frame.azFxLayer.mouseEnabled)
		Run(0.6)
		local bubble = NS.companionBubble
		local y1 = select(5, parts.dots[1]:GetPoint(1))
		local lit = parts.iglow:IsShown() and parts.iglow.atlas == "AftLevelup-IconGlow" and group.line.atlas == A.line
			and (group.line.alpha or 0) > 0 and parts.dots[1]:IsShown() and group.cloud.atlas == A.cloud
		local lifted = bubble:IsShown() and bubble.azLift and select(5, bubble:GetPoint(1)) == bubble.azLift[5] + C.groupLift
			and C.groupLift >= C.groupY + C.groupH - 4
		Run(0.4)
		Check("[FX] … lueur du portrait, ligne de lumière, poussière dorée qui monte ; la bulle monte au-dessus du groupe", lit
			and lifted and select(5, parts.dots[1]:GetPoint(1)) > y1)
		Run(C.levelTime)
		Check("[FX] … puis tout s'efface, la bulle revient à sa place", not group:IsShown() and not parts.iglow:IsShown()
			and not bubble.azLift and select(5, bubble:GetPoint(1)) == 12)
		NS:CompanionHideBubble()
		Quiet()
		NS:CompanionOnLevel(21)
		local level = group:IsShown() and group.text:GetText() == "Niveau 21 !" and NS.azFx.level.kind == "level"
		Run(C.levelTime + 0.5)
		NS:SetUIStyle("sobre")
		NS:CompanionOnLevel(22)
		local sobre = not group:IsShown() and NS.azFx.level == nil
		NS:SetUIStyle("azeroth")
		NS:AzerothLevelFX("Test !")
		NS:SetUIStyle("sobre")
		Check("[FX] niveau : « Niveau 21 ! » ; Sobre : pas d'effet ; style changé pendant l'effet : arrêté net", level and sobre
			and not group:IsShown() and NS.azFx.level == nil)
		NS:SetUIStyle("azeroth")
		NS.CompanionIsHappy = FXT.savedHappy
	end

	-- 2.5 Grandes récompenses
	do
		Say("-- effets azeroth : ailes des grandes récompenses")
		FXT.Reset()
		local banner = NS:EnsureJournalToast()
		banner:Show()
		local started = NS:AzerothRewardFX(banner) == true
		local fx = banner.azReward
		Run(0.8)
		local wings = fx and fx.left:IsShown() and fx.right:IsShown() and fx.burst:IsShown() and fx.left.atlas == A.wings
			and fx.burst.blendMode == "ADD" and fx.left.drawLayer == "BACKGROUND" and select(3, fx.left:GetPoint(1)) == "LEFT"
			and select(3, fx.right:GetPoint(1)) == "RIGHT"
		Run(C.rewardTime)
		Check("[FX] ns:AzerothRewardFX : ailes à gauche et à droite, éclat derrière, puis tout s'efface", started and wings
			and not fx.left:IsShown() and not fx.burst:IsShown())
		_G.C_Texture = { GetAtlasInfo = function() return { width = 277, height = 327, file = 123, leftTexCoord = 0.1,
			rightTexCoord = 0.5, topTexCoord = 0.2, bottomTexCoord = 0.9 } end }
		local tex = banner:CreateTexture(nil, "ARTWORK")
		NS.AzerothAtlasMirrored(tex, A.wings)
		Check("[FX] aile droite : coordonnées de l'atlas inversées", tex.texture == 123 and tex.texCoord[1] == 0.5
			and tex.texCoord[2] == 0.1 and tex.texCoord[3] == 0.2 and tex.texCoord[4] == 0.9)
		Mock.InstallAtlas(true)
		banner:Hide()
		NS.journalToastHideAt = nil
		NS:JournalToastPush({ kind = "rank", name = "Dresseur confirmé" })
		local rank = NS.journalToast:IsShown() and NS.journalToast.azReward and NS.journalToast.azReward.at ~= nil
		Run(C.rewardTime + 0.2)
		NS.journalToastHideAt = nil
		NS:JournalToastPush({ kind = "seal", name = "Les Tarides" })
		local seal = NS.journalToast.azReward.at == nil
		NS:SetUIStyle("sobre")
		Check("[FX] titre de dresseur : bandeau avec ailes ; sceau de zone : pas d'ailes ; Sobre : l'API ne fait rien", rank and seal
			and NS:AzerothRewardFX(NS:EnsureJournalToast()) == false)
		NS:SetUIStyle("azeroth")
	end

	-- 2.6 Atlas manquants : l'effet est sauté, sans erreur
	do
		Say("-- effets azeroth : atlas manquants")
		local missing = { [A.talk] = true, [A.circle] = true, [A.circleAlt] = true, [A.star] = true,
			[A.filigree] = true, [A.wings] = true, [A.burst] = true, [A.iconGlow] = true }
		local frame = FXT.Reset(missing)
		local errors = NS.errors and #NS.errors or 0
		Speak()
		Run(0.5)
		local bubble = NS.companionBubble
		-- 2.8.2 : la bulle ne dépend plus de l'atlas des Talking Heads
		local bad = {}
		if frame.uiStyle ~= "azeroth" then bad[#bad + 1] = "style" end
		if not (bubble.azBubble and bubble.bg.mockHidden and bubble.azTalk.bg.texture == 130661) then bad[#bad + 1] = "bulle" end
		if frame.azGlow or Edges(frame) then bad[#bad + 1] = "lueur" end
		if not (NS:AzerothShinyFX() == true and (Run(0.5) or true) and frame.azSparks == nil) then bad[#bad + 1] = "éclats" end
		if not (NS:AzerothLevelFX("Aguerri !") and frame.azLevel.group.left == nil and frame.azLevel.iglow == nil) then bad[#bad + 1] = "volutes" end
		Run(C.levelTime + 0.5)
		if NS:AzerothRewardFX(NS:EnsureJournalToast()) ~= false then bad[#bad + 1] = "ailes" end
		Check("[FX] atlas manquants : le style tient, bulle quand même, chaque effet sauté (lueur, éclats, volutes, ailes)", #bad == 0,
			table.concat(bad, ", "))
		Check("[FX] aucune erreur enregistrée", (NS.errors and #NS.errors or 0) == errors)
		NS:CompanionHideBubble()
	end

	-- Rangement : les autres scénarios testent le style Sobre (client sans atlas)
	NS:AzerothFxStop()
	Mock.InstallAtlas(nil)
	NS:AzerothAtlasOK(true)
	NS:ApplyUIStyle()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalToast" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.uiStyleCache, NS.azFx = {}, nil
	NS.journalToasts, NS.journalChats, NS.journalToastHideAt = {}, {}, nil
	NS.CompanionIsHappy = FXT.savedHappy
	for _, name in ipairs(GLOBALS) do _G[name] = FXT.saved[name] end
	ResetWorld()
end
