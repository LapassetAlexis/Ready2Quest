-- QuestCompanion 2.0, lot 2 : le compagnon actif (CompanionEffects.lua).
-- Table des 8 types, force (rang, brillante, étoiles, complétion), envies,
-- mascottes (étape), délai de 2 minutes, enveloppes (capture, brillant,
-- aides, paliers, envies, repos, caresse), confirmation qui compare, page
-- Compagnon, fiche de la Ménagerie, infobulle, patte sur les barres de nom.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local EF = { saved = {}, random = math.random, units = {} }
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

-- 1. La table des 8 types ----------------------------------------------------------------------------
do
	Say("-- compagnon actif : la table des types")
	EF.Reset()
	local ok, strings = true, NS.EFFECT_STRINGS
	for _, key in ipairs(NS.CREATURE_TYPES) do
		local pair = NS.COMPANION_TYPE_EFFECTS[key]
		if not (pair and NS.COMPANION_EFFECTS[pair.hunt] and NS.COMPANION_EFFECTS[pair.comfort]) then ok = false end
	end
	Check("[EFF] chaque type : un effet de chasse et un de confort", ok)
	local seen, unique = {}, true
	for _, key in ipairs(NS.CREATURE_TYPES) do
		local hunt = NS.COMPANION_TYPE_EFFECTS[key].hunt
		if seen[hunt] then unique = false end
		seen[hunt] = true
	end
	Check("[EFF] chasse : un effet propre à chaque type", unique)
	local texts = true
	for id in pairs(NS.COMPANION_EFFECTS) do
		if not (strings.fr["EFF_" .. id] and strings.en["EFF_" .. id]) then texts = false end
	end
	for key in pairs(strings.fr) do if strings.en[key] == nil then texts = false end end
	for key in pairs(strings.en) do if strings.fr[key] == nil then texts = false end end
	Check("[EFF] textes : chaque effet en français et en anglais", texts)
	local modest = true
	for _, def in pairs(NS.COMPANION_EFFECTS) do
		if def.cap > 1.5 or def.base > 0.5 then modest = false end
	end
	Check("[EFF] valeurs modestes et plafonnées", modest)
end

-- 2. Force : rang, brillante, étoiles, complétion ; envies ----------------------------------------------
do
	Say("-- compagnon actif : force et envies")
	EF.Reset()
	EF.Add(5001, "Humanoïde", "normal")
	EF.Add(5002, "Humanoid", "elite")
	EF.Add(5003, "Humanoïde", "rare", true)
	EF.Add(5004, "Humanoïde", "worldboss")
	local function S(id) return NS:CompanionEffectsFor(id, { full = true }).strength end
	Check("[EFF] normal ×1, élite ×1,5 (type du client anglais compris)", S("cap:5001") == 1 and S("cap:5002") == 1.5)
	Check("[EFF] rare ×2, boss ×2,5", S("cap:5003") == 2 and S("cap:5004") == 2.5)
	Check("[EFF] brillante : +0,5", S("cap:5003:s") == 2.5)
	NS.CaptureStars = function(_, npc, shiny) if npc == 5001 and not shiny then return 3 end return nil end
	Check("[EFF] étoiles (lot 1) : +0,25 par étoile au-dessus de 1", S("cap:5001") == 1.5 and S("cap:5002") == 1.5)
	NS.MenagerieTypeBonus = function(_, key) return key == "humanoid" and 0.5 or 0 end
	Check("[EFF] complétion du type (lot 3) : ajoutée", S("cap:5001") == 2)
	NS.CaptureStars, NS.MenagerieTypeBonus = EF.savedStars, EF.savedBonus
	local e = NS:CompanionEffectsFor("cap:5002", { full = true })
	Check("[EFF] Humanoïde élite : capture des Humanoïdes +15 %", e.typeKey == "humanoid" and e.hunt.id == "capture_humanoid"
		and Near(e.hunt.value, 0.15) and e.hunt.label == "capture des Humanoïdes +15 %", e.hunt.label)
	Check("[EFF] … et son confort : friandise en plus aux paliers", e.comfort.id == "treat_zone" and Near(e.comfort.value, 0.225))
	local needs = NS:CompanionData().needs
	Check("[EFF] envies toutes à 50 % ou plus : pleine force", Near(NS:CompanionEffectNeeds(), 1))
	needs.hunger, needs.energy = 30, 49
	local factor, ok = NS:CompanionEffectNeeds()
	Check("[EFF] deux envies en dessous : 75 %", Near(factor, 0.75) and ok == 2)
	Check("[EFF] la valeur suit", Near(NS:CompanionEffectsFor("cap:5002").hunt.value, 0.15 * 0.75))
	for key in pairs(needs) do needs[key] = 15 end
	Check("[EFF] toutes au plancher : jamais sous la moitié", Near(NS:CompanionEffectNeeds(), 0.5))
	for key in pairs(needs) do needs[key] = 80 end
	EF.Add(5005, nil, "elite")
	Check("[EFF] type inconnu : l'effet général", NS:CompanionEffectsFor("cap:5005").mascot == true)
	EF.Add(5006, "Dragonkin", "worldboss", true)
	NS.CaptureStars = function() return 3 end
	NS.MenagerieTypeBonus = function() return 5 end
	local max = NS:CompanionEffectsFor("cap:5006:s", { full = true })
	Check("[EFF] plafonds tenus, même au plus fort", max.hunt.value == NS.COMPANION_EFFECTS.shiny_chain.cap
		and max.comfort.value == NS.COMPANION_EFFECTS.decay_mood.cap)
	NS.CaptureStars, NS.MenagerieTypeBonus = EF.savedStars, EF.savedBonus
end

-- 3. Mascottes : l'étape d'évolution ------------------------------------------------------------------
do
	Say("-- compagnon actif : mascottes")
	EF.Reset()
	local data = NS:CompanionData()
	data.appearance = NS.COMPANION_APPEARANCES[1].id
	data.stage = 1
	local e1 = NS:CompanionEffectsFor(NS.COMPANION_APPEARANCES[1])
	data.stage = 5
	local e5 = NS:CompanionEffectsFor(NS.COMPANION_APPEARANCES[1])
	Check("[EFF] mascotte : pas de type, effet général", e1.mascot and e1.typeKey == nil and e1.hunt.id == "capture_all"
		and e1.comfort.id == "mascot_decay")
	Check("[EFF] mascotte : grandit avec l'étape (2 % -> 10 % de capture)", Near(e1.hunt.value, 0.02) and Near(e5.hunt.value, 0.10))
	Check("[EFF] mascotte : envies 4 % -> 20 % moins vite", Near(e1.comfort.value, 0.04) and Near(e5.comfort.value, 0.20))
	data.stage = 1
end

-- 4. Délai de 2 minutes, contrat ------------------------------------------------------------------------
do
	Say("-- compagnon actif : délai et contrat")
	EF.Reset()
	EF.Add(5101, "Humanoïde", "normal")
	local first = NS:CompanionEffects()
	Check("[EFF] premier relevé : le délai démarre", first.active == false and first.remaining == NS.EFFECT_DELAY)
	Mock.now = Mock.now + NS.EFFECT_DELAY
	Check("[EFF] mascotte : active au bout de 2 min", NS:CompanionEffects().active == true
		and Near(NS:CompanionEffectValue("capture_all"), 0.02))
	NS:CompanionEffectsTick()
	NS:CompanionSetAppearance(NS.COMPANION_APPEARANCES[2].id)
	NS:CompanionData().unlocked["app:" .. NS.COMPANION_APPEARANCES[2].id] = true
	NS:CompanionSetAppearance(NS.COMPANION_APPEARANCES[2].id)
	Check("[EFF] mascotte vers mascotte : mêmes effets, délai inchangé", NS:CompanionEffects().active == true)
	NS:CompanionSetAppearance("cap:5101")
	local e = NS:CompanionEffects()
	Check("[EFF] nouvelle créature : pas encore active", e.active == false and e.typeKey == "humanoid"
		and e.remaining == NS.EFFECT_DELAY and e.activeAt == math.floor(Mock.now) + NS.EFFECT_DELAY)
	Check("[EFF] inactive : valeur 0", NS:CompanionEffectValue("capture_humanoid") == 0)
	Check("[EFF] contrat : hunt / comfort { id, value, label }", e.hunt.id == "capture_humanoid" and e.hunt.value > 0
		and type(e.hunt.label) == "string" and e.comfort.id == "treat_zone" and e.strength == 1)
	Mock.output = {}
	Mock.now = Mock.now + 60
	NS:CompanionEffectsTick()
	Check("[EFF] à mi-chemin : toujours pas", NS:CompanionEffects().remaining == 60)
	Mock.now = Mock.now + 60
	NS:CompanionEffectsTick()
	Check("[EFF] au bout de 2 min : active", NS:CompanionEffects().active
		and Near(NS:CompanionEffectValue("capture_humanoid"), 0.10))
	local said = false
	for _, line in ipairs(Mock.output) do if tostring(line):find("actifs", 1, true) then said = true end end
	Check("[EFF] activation annoncée une fois", said)
	Mock.output = {}
	NS:CompanionEffectsTick()
	said = false
	for _, line in ipairs(Mock.output) do if tostring(line):find("actifs", 1, true) then said = true end end
	Check("[EFF] … pas deux", not said)
	Check("[EFF] autre effet : 0", NS:CompanionEffectValue("shiny_undead") == 0)
	NS:DB().companionEnabled = false
	Check("[EFF] compagnon coupé : aucun effet", NS:CompanionEffectValue("capture_humanoid") == 0)
	NS:DB().companionEnabled = true
end

-- 5. Enveloppes : capture et brillant ------------------------------------------------------------------
do
	Say("-- compagnon actif : capture et brillant")
	EF.Reset()
	EF.Add(5201, "Humanoïde", "rare")
	EF.Take("cap:5201")
	local function Pct(info) return math.floor(NS:CaptureChance(info, nil, 20) * 100 + 0.5 + 1e-9) end
	Check("[EFF] Humanoïde rare : capture des Humanoïdes ×1,2 (50 % -> 60 %)",
		Pct({ class = "normal", level = 20, type = "Humanoïde" }) == 60)
	Check("[EFF] … pas sur une Bête", Pct({ class = "normal", level = 20, type = "Bête" }) == 50)
	Check("[EFF] chance de base gardée à part", math.floor(NS:CaptureChanceBase({ class = "normal", level = 20, type = "Humanoïde" },
		nil, 20) * 100 + 0.5) == 50)
	local chance, sure = NS:CaptureChance({ class = "normal", type = "Humanoïde" }, "sifflet")
	Check("[EFF] sifflet : toujours assuré, rien à ajouter", chance == 1 and sure == true)
	Check("[EFF] plafond de 95 % tenu", Pct({ class = "normal", level = 1, type = "Humanoïde" }) <= 95
		and math.floor(NS:CaptureChance({ class = "normal", level = 1, type = "Humanoïde" }, "lasso", 60) * 100 + 0.5) == 95)
	-- Démon : élites et rares
	EF.Add(5202, "Démon", "elite")
	EF.Take("cap:5202")
	Check("[EFF] Démon élite : élites ×1,18 (25 % -> 30 %)", Pct({ class = "elite", level = 20, type = "Bête" }) == 30)
	Check("[EFF] … pas sur un normal", Pct({ class = "normal", level = 20, type = "Bête" }) == 50)
	-- Bête : repérage, et capture en plus sur les Bêtes pas encore capturées
	EF.Add(5203, "Bête", "normal")
	EF.Take("cap:5203")
	Check("[EFF] Bête : +5 % sur une Bête pas encore capturée", Pct({ class = "normal", level = 20, type = "Bête", npcID = 6001 }) == 53)
	Check("[EFF] … rien sur une espèce déjà capturée", Pct({ class = "normal", level = 20, type = "Bête", npcID = 5203 }) == 50)
	-- Mort-vivant : brillant des Morts-vivants
	NS.SHINY_CHANCE = 1 / 150
	EF.Add(5204, "Mort-vivant", "rare")
	EF.Take("cap:5204")
	Check("[EFF] Mort-vivant rare : brillant des Morts-vivants ×1,3",
		Near(NS:ShinyChance("normal", 0, "undead"), 1.3 / 150) and Near(NS:ShinyChance("normal", 0, "beast"), 1 / 150))
	-- pendant le tirage d'une unité : son type à elle
	local seenType
	local before = NS.ShinyChance
	EF.units.target = { guid = EF.Guid(7001), ctype = "Mort-vivant" }
	EF.Roll(0.999)
	NS.ShinyChance = function(self, class, killed, typeKey) seenType = typeKey or self.effectShinyType; return 0 end
	NS:ShinyRoll("target", { npcID = 7001 })
	NS.ShinyChance = before
	Check("[EFF] tirage d'une brillante : le type de l'unité est connu", seenType == "undead" and NS.effectShinyType == nil)
	-- type secret (Forever) : CreatureTypeKey passe par ns.Plain avant toute comparaison
	local savedSecret = rawget(_G, "issecretvalue")
	_G.issecretvalue = function(v) return v == "Mort-vivant" end
	Check("[EFF] type secret : pas de clé, sans erreur", pcall(NS.CreatureTypeKey, NS, "Mort-vivant")
		and NS:CreatureTypeKey("Mort-vivant") == nil and NS:CreatureTypeKey("Bête") == "beast")
	_G.issecretvalue = savedSecret
	-- CreatureTypeKey en erreur : le tirage se fait quand même
	local savedKey = NS.CreatureTypeKey
	NS.CreatureTypeKey = function() error("valeur secrète") end
	seenType = "?"
	NS.ShinyChance = function(self, class, killed, typeKey) seenType = typeKey or self.effectShinyType; return 0 end
	local rolled = pcall(NS.ShinyRoll, NS, "target", { npcID = 7001 })
	NS.ShinyChance, NS.CreatureTypeKey = before, savedKey
	Check("[EFF] type illisible : ShinyRoll ne tombe pas, sans bonus de type", rolled and seenType == nil, tostring(seenType))
	-- Draconien : abattus comptés en plus
	EF.Add(5205, "Draconien", "normal")
	EF.Take("cap:5205")
	Check("[EFF] Draconien : 20 abattus comptent 30", Near(NS:ShinyChance("normal", 20), (1 / 150) * (1 + 2.75 * 30 / 50)))
	Check("[EFF] … le plafond de la chasse reste", Near(NS:ShinyChance("normal", 500), 1 / 40))
	NS.SHINY_CHANCE = 0
end

-- 6. Enveloppes : aides, paliers ------------------------------------------------------------------------
do
	Say("-- compagnon actif : aides et paliers")
	EF.Reset()
	-- Élémentaire : l'aide parfois gardée
	EF.Add(5301, "Élémentaire", "normal")
	EF.Take("cap:5301")
	NS:CaptureData().items.appat = 2
	EF.Roll(0)
	Check("[EFF] Élémentaire : aide utilisée mais pas consommée", NS:CaptureSpend("appat") == true
		and NS:CaptureData().items.appat == 2)
	EF.Roll(0.99)
	Check("[EFF] … sinon consommée", NS:CaptureSpend("appat") == true and NS:CaptureData().items.appat == 1)
	NS:CaptureData().items.appat = 0
	EF.Roll(0)
	Check("[EFF] … et rien sans aide en poche", NS:CaptureSpend("appat") == false)
	-- Mécanique : capture ratée, l'aide revient
	EF.Add(5302, "Mécanique", "normal")
	EF.Take("cap:5302")
	NS:CaptureData().items.lasso = 0
	EF.Roll(0)
	NS:CaptureResolve({ success = false, aid = "lasso", target = { npcID = 7100, name = "Loup", class = "normal" } })
	Check("[EFF] Mécanique : capture ratée, le lasso revient", NS:CaptureData().items.lasso == 1)
	EF.Roll(0.99)
	NS:CaptureResolve({ success = false, aid = "lasso", target = { npcID = 7100, name = "Loup", class = "normal" } })
	Check("[EFF] … pas toujours", NS:CaptureData().items.lasso == 1)
	-- Géant : une aide en plus au palier ; Humanoïde : une friandise
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
	-- garde-manger vide : la friandise tirée ne peut pas être mangée sur place (plafond 3)
	for kind in pairs(pantry) do pantry[kind] = 0 end
	local before = 0
	for _, n in pairs(pantry) do before = before + n end
	NS:TreatData().milestones[1414] = nil
	EF.Roll(0)
	NS:TreatCheckZone(1414)
	local after = 0
	for _, n in pairs(pantry) do after = after + n end
	Check("[EFF] Humanoïde : palier de zone, une friandise en plus", after == before + 2, before .. " -> " .. after)
	NS:TreatData().milestones[1415] = nil
	for kind in pairs(pantry) do pantry[kind] = 0 end
	local quiet = 0
	for _, n in pairs(pantry) do quiet = quiet + n end
	local quietGained = NS:TreatCheckZone(1415, { quiet = true })
	local quietAfter = 0
	for _, n in pairs(pantry) do quietAfter = quietAfter + n end
	Check("[EFF] rattrapage (mise à jour) : pas d'effet rétroactif", quietAfter == quiet + 1,
		quiet .. " -> " .. quietAfter .. " (" .. #quietGained .. " " .. tostring(quietGained[1] and quietGained[1].result) .. ")")
	NS.ZoneCompletion = saved
end

-- 7. Enveloppes : envies, repos, caresses ---------------------------------------------------------------
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
	Check("[EFF] Bête rare : la faim baisse 20 % moins vite", Near(hunger, 0.8), tostring(hunger))
	Check("[EFF] … les autres envies, comme avant", Near(NS:CompanionDecayFactor("energy"), 1))
	local needs = NS:CompanionData().needs
	needs.hunger = 80
	NS:CompanionTick(600)
	Check("[EFF] tick : la faim descend moins", Near(needs.hunger, 80 - base.hunger * 10 * NS:CompanionDecayFactor("hunger")),
		tostring(needs.hunger))
	-- Géant : toutes les envies
	EF.Add(5402, "Géant", "normal")
	EF.Take("cap:5402")
	local ratio = NS:CompanionDecayFactor("mood")
	NS:CompanionData().appearance = NS.COMPANION_APPEARANCES[1].id
	NS:CompanionEffectsSync()
	Mock.now = Mock.now + NS.EFFECT_DELAY + 1
	local mascot = NS:CompanionDecayFactor("mood")
	Check("[EFF] Géant : toutes les envies 5 % moins vite", Near(ratio / mascot, 0.95 / 0.96), ratio .. " / " .. mascot)
	-- Mécanique : repos
	EF.Add(5403, "Mécanique", "normal")
	EF.Take("cap:5403")
	EF.resting = true
	needs.energy = 40
	NS:CompanionTick(60)
	-- l'énergie à 40 : une envie sous 50 %, force à 87,5 %
	Check("[EFF] Mécanique : au repos, l'énergie remonte 15 % plus vite (moins, envie basse)",
		Near(needs.energy, 40 + NS.COMPANION_RULES.restGain * (1 + 0.15 * 0.875)), tostring(needs.energy))
	EF.resting = false
	-- Démon : caresse
	EF.Add(5404, "Démon", "normal")
	EF.Take("cap:5404")
	needs.mood, needs.energy, needs.hunger = 50, 80, 80
	NS.companionLastPet = nil
	NS:CompanionPet()
	Check("[EFF] Démon : une caresse remonte le moral de 25 % en plus", Near(needs.mood, 50 + 8 * 1.25), tostring(needs.mood))
	-- le garde-manger (Maj + clic) rend vrai aussi : pas de moral gratuit
	local savedShift = rawget(_G, "IsShiftKeyDown")
	_G.IsShiftKeyDown = function() return true end
	needs.mood = 50
	NS.companionLastPet = nil
	local opened = NS:CompanionPet()
	_G.IsShiftKeyDown = savedShift
	if NS.treatMenu then NS.treatMenu:Hide() end
	Check("[EFF] Démon : ouvrir le garde-manger (Maj + clic) ne donne pas de moral", opened and needs.mood == 50,
		tostring(opened) .. " " .. tostring(needs.mood))
	-- une caresse refusée (délai entre deux caresses) non plus
	NS:CompanionPet()
	local after = needs.mood
	NS:CompanionPet()
	Check("[EFF] Démon : caresse trop rapprochée, pas de bonus", needs.mood == after, tostring(needs.mood))
	NS.CompanionTrait = savedTrait
end

-- 8. Confirmation qui compare ---------------------------------------------------------------------------
do
	Say("-- compagnon actif : confirmation")
	EF.Reset()
	EF.Add(5501, "Mort-vivant", "elite")
	local data = NS:CompanionData()
	data.appearance = NS.COMPANION_APPEARANCES[1].id
	data.unlocked["app:" .. NS.COMPANION_APPEARANCES[2].id] = true
	local done = 0
	Check("[EFF] mascotte vers mascotte : pas de question",
		NS:CompanionAskAppearance(NS.COMPANION_APPEARANCES[2].id, function() done = done + 1 end) ~= "ask"
		and data.appearance == NS.COMPANION_APPEARANCES[2].id and done == 1)
	Check("[EFF] verrouillée : refusée", NS:CompanionAskAppearance("owl") == nil)
	Check("[EFF] vers une créature : la question", NS:CompanionAskAppearance("cap:5501", function() done = done + 1 end) == "ask"
		and NS.effectsConfirm:IsShown() and data.appearance ~= "cap:5501")
	local text = NS.effectsConfirm.text.text or ""
	Check("[EFF] elle compare : effets d'aujourd'hui et du nouveau", text:find("capture +2 %", 1, true)
		and text:find("Morts-vivants +23 %", 1, true) and text:find("Bête 5501", 1, true), text)
	NS:CompanionConfirmAnswer(false)
	Check("[EFF] Annuler : rien ne change", data.appearance ~= "cap:5501" and not NS.effectsConfirm:IsShown() and done == 1)
	NS:CompanionAskAppearance("cap:5501", function() done = done + 1 end)
	Mock.output = {}
	NS:CompanionConfirmAnswer(true)
	Check("[EFF] Emmener : c'est fait, le délai démarre", data.appearance == "cap:5501" and done == 2
		and NS:CompanionEffects().active == false)
	Check("[EFF] … et c'est annoncé", (Mock.output[#Mock.output] or ""):find("2 minutes", 1, true) ~= nil)
	-- réglages : la liste passe aussi par la confirmation
	local row
	for _, page in ipairs(NS.OPTION_PAGES or {}) do
		for _, r in ipairs(page.rows or {}) do if r.key == "companionAppearance" then row = r end end
	end
	data.appearance = NS.COMPANION_APPEARANCES[1].id
	row.choose("cap:5501")
	Check("[EFF] réglages : la liste demande aussi", NS.effectsConfirm:IsShown() and data.appearance ~= "cap:5501")
	NS:CompanionConfirmAnswer(false)
end

-- 9. Affichage : page Compagnon, fiche, infobulle ----------------------------------------------------------
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
	Check("[EFF] page Compagnon : chasse et confort", evo.effHunt.text == "Chasse : capture des Humanoïdes +15 %"
		and (evo.effComfort.text or ""):find("^Confort : ") ~= nil, evo.effHunt.text)
	Check("[EFF] page Compagnon : force et compte à rebours", (evo.effState.text or ""):find("Force ×1,5", 1, true)
		and evo.effState.text:find("Actifs dans 2:00", 1, true), evo.effState.text)
	Mock.now = Mock.now + 75
	NS:CompanionEffectsTick()
	Check("[EFF] le compte à rebours avance tout seul", evo.effState.text:find("Actifs dans 0:45", 1, true), evo.effState.text)
	Mock.now = Mock.now + 60
	NS:CompanionEffectsTick()
	Check("[EFF] puis « Actifs »", evo.effState.text:find("Actifs$") ~= nil, evo.effState.text)
	f:Hide()
	-- fiche de la Ménagerie
	local lines = NS:CompanionEffectsLines({ npc = 5601, known = true, class = "elite", type = "Humanoïde" }, false)
	Check("[EFF] fiche : « Chasse : … / Confort : … » avec ses valeurs", lines[1] == "Chasse : capture des Humanoïdes +15 %"
		and lines[2]:find("^Confort : 23 %%") ~= nil, tostring(lines[2]))
	Check("[EFF] fiche : la brillante, plus forte", NS:CompanionEffectsLines({ npc = 5601, known = true, class = "elite",
		type = "Humanoïde" }, true)[1] == "Chasse : capture des Humanoïdes +20 %")
	Check("[EFF] fiche : une inconnue, rien", #NS:CompanionEffectsLines({ npc = 5601, known = false }) == 0)
	-- infobulle : la chance avec le bonus
	NS:BestiaryData()[1413] = { [7301] = { name = "Bandit", class = "normal", type = "Humanoïde", seen = true, level = 20 } }
	local text = NS:BestiaryTooltipLine(EF.Guid(7301), 20)
	Check("[EFF] infobulle : « à capturer · 58 % (+8) »", text == "Ménagerie : à capturer · 58 % (+8)", text)
	NS:BestiaryData()[1413][7302] = { name = "Loup", class = "normal", type = "Bête", seen = true, level = 20 }
	text = NS:BestiaryTooltipLine(EF.Guid(7302), 20)
	Check("[EFF] infobulle : sans bonus, comme avant", text == "Ménagerie : à capturer · 50 %", text)
end

-- 10. Patte sur les barres de nom (repérage) -----------------------------------------------------------------
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
	NS.effectPlates = {}
	local wolf = Plate("nameplate1", 7401, "Bête")
	local bandit = Plate("nameplate2", 7402, "Humanoïde")
	local caught = Plate("nameplate3", 7403, "Bête")
	local friend = Plate("nameplate4", 7404, "Bête", { reaction = 5 })
	EF.Add(7403, "Bête", "normal")
	NS:EffectPlatesRefresh()
	Check("[EFF] sans l'effet : aucune patte", NS.effectPlateMarks[wolf] == nil or not NS.effectPlateMarks[wolf]:IsShown())
	EF.Add(5701, "Bête", "normal")
	EF.Take("cap:5701", false)
	NS:EffectPlatesRefresh()
	Check("[EFF] Bête emmenée mais pas encore active : pas de patte",
		NS.effectPlateMarks[wolf] == nil or not NS.effectPlateMarks[wolf]:IsShown())
	Mock.now = Mock.now + NS.EFFECT_DELAY + 1
	NS:CompanionEffectsTick()
	local mark = NS.effectPlateMarks[wolf]
	Check("[EFF] active : patte sur la Bête pas encore capturée", mark and mark:IsShown() and mark:GetParent() == wolf)
	Check("[EFF] … au-dessus de la barre, l'icône de pistage des bêtes", mark.lastPoint and mark.lastPoint.point == "BOTTOM"
		and mark.lastPoint.relPoint == "TOP" and mark.icon.texture == NS.EFFECT_PAW)
	Check("[EFF] pas sur un Humanoïde", NS.effectPlateMarks[bandit] == nil or not NS.effectPlateMarks[bandit]:IsShown())
	Check("[EFF] pas sur une espèce déjà capturée", NS.effectPlateMarks[caught] == nil or not NS.effectPlateMarks[caught]:IsShown())
	Check("[EFF] pas sur une créature amicale", NS.effectPlateMarks[friend] == nil or not NS.effectPlateMarks[friend]:IsShown())
	NS:DB().companionEffectPlate = false
	NS:EffectPlatesRefresh()
	Check("[EFF] réglage coupé : patte cachée", not mark:IsShown())
	NS:DB().companionEffectPlate = true
	NS:EffectPlatesRefresh()
	-- capturée : la patte s'en va
	NS:CaptureResolve({ success = true, target = { npcID = 7401, name = "Loup", class = "normal", type = "Bête" } })
	Check("[EFF] capturée : la patte s'en va", not mark:IsShown())
	NS.effectPlateFrame:GetScript("OnEvent")(NS.effectPlateFrame, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
	Check("[EFF] barre retirée : oubliée", NS.effectPlates.nameplate1 == nil)
	-- barre de nom qui apparaît : avec l'effet, la patte ; sans, rien de coûteux
	local onEvent = NS.effectPlateFrame:GetScript("OnEvent")
	local fox = Plate("nameplate5", 7405, "Bête")
	onEvent(NS.effectPlateFrame, "NAME_PLATE_UNIT_ADDED", "nameplate5")
	Check("[EFF] barre ajoutée, repérage actif : patte posée", NS.effectPlateMarks[fox] and NS.effectPlateMarks[fox]:IsShown())
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
		onEvent(NS.effectPlateFrame, "NAME_PLATE_UNIT_ADDED", "nameplate" .. (10 + index))
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
math.random = EF.random
NS.SHINY_CHANCE = EF.savedShiny
NS.CaptureStars, NS.MenagerieTypeBonus = EF.savedStars, EF.savedBonus
NS:CompanionData().appearance = NS.COMPANION_APPEARANCES[1].id
ResetWorld()
