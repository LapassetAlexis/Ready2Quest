-- QuestCompanion 3.1.0 : caractère et taille des spécimens (SpecimenTraits.lua).
--   * caractère tiré à la capture parmi ceux du compagnon (communs ×3,
--     rares ×1), taille tirée (2 / 18 / 60 / 18 / 2 %) ;
--   * le spécimen porté donne son caractère au compagnon (réglage
--     « Apparence »), sa voix teintée, et un petit effet (« Caractère : … ») ;
--   * la taille : échelle du modèle du cadre, rapprochée selon le cadrage,
--     bornée, caméra reculée au-dessus de 1 ;
--   * hauts faits « Un géant parmi les bêtes », « Petit mais costaud » ;
--   * migration 3.0 -> 3.1 idempotente, rien ne change pour le compagnon porté ;
--   * cadeau de la 3.0 : caractère tiré, taille normale ;
--   * affichage : message de capture, scène, Réserve (vignette, fiche,
--     infobulle), choix d'allure, fiche des Créatures, page Compagnon,
--     « Ses effets », les deux styles ; tutoriel ; contrastes.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local W = { saved = {}, random = math.random, units = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer",
	"UnitAffectingCombat", "InCombatLockdown", "IsShiftKeyDown" }
for _, name in ipairs(GLOBALS) do W.saved[name] = rawget(_G, name) end
W.savedShiny = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"
local ZONE = 1413
local FIELDS = { "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt", "captureQueueList",
	"captureNetButton", "captureToast", "effectsConfirm" }

function W.Guid(npcID) return string.format("Creature-0-4378-1-12-%d-%s", npcID, "00001A2B3C") end
function W.Install()
	local w = W
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function() return false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = w.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function() return "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function(unit)
		if unit == "player" or unit == nil then return 20 end
		local u = w.units[unit]; return u and u.level or 20
	end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	_G.C_Timer = { After = function(_, fn) fn() end }
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	_G.IsShiftKeyDown = function() return false end
end
function W.Reset(style)
	if NS.tourState and NS.TourStop then NS:TourStop() end
	ResetWorld()
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS.uiStyleCache = {}
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureAppCache, NS.specimenCountCache, NS.effectCache, NS.codexReserveCache, NS.codexZoneCache = nil, nil, nil, nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	NS:DB().capture, NS.captureMergedChar = nil, nil
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
	NS:DB().companionTraitSource, NS:DB().companionTraitPick = 1, 0
	NS:DB().journalState, NS:DB().journalTab = nil, nil
	W.units = {}
	Mock.world.maps[ZONE] = { mapID = ZONE, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = ZONE, 20
	W.Install()
	if style == "sobre" then Mock.InstallAtlas(nil) else Mock.InstallAtlas(true) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "sobre" and "sobre" or "azeroth"
	NS.SHINY_CHANCE = 0
	math.random = W.random
	local data = NS:CompanionData()
	data.tutoDone, data.appearance, data.persona, data.effects = true, nil, nil, nil
	NS:TreatData().treatsInit = true
	NS:DB().companionCaptureAnim = false
	NS:CompanionUpdateVisibility()
	if NS.CompanionWornForget then NS:CompanionWornForget() end
	Mock:Reset()
end
function W.Roll(value)
	math.random = function(a, b)
		if a and b then return W.random(a, b) end
		if a then return W.random(a) end
		return value
	end
end
-- une suite de tirages (puis le dernier, répété)
function W.Rolls(list)
	local i = 0
	math.random = function(a, b)
		if a and b then return W.random(a, b) end
		if a then return W.random(a) end
		i = i + 1
		return list[math.min(i, #list)]
	end
end
function W.SeeKill(npcID, fields)
	fields = fields or {}
	local guid = W.Guid(npcID)
	fields.guid = guid
	fields.name = fields.name or ("Bête " .. npcID)
	W.units.target = fields
	NS:BestiarySeeUnit("target")
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
	return guid
end
function W.Settle()
	for _ = 1, 12 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
end
function W.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = W.saved[name] end
	math.random = W.random
	NS.SHINY_CHANCE = W.savedShiny
	for _, field in ipairs(FIELDS) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS:DB().capture, NS.captureMergedChar = nil, nil
	NS:DB().captureHuntOn, NS:DB().captureHuntUntil = nil, nil
	NS:DB().companionTraitSource, NS:DB().companionTraitPick = 1, 0
	NS:DB().journalState, NS:DB().journalTab = nil, nil
	local data = NS:CompanionData()
	data.appearance, data.persona, data.effects = nil, nil, nil
	NS.uiStyleCache = {}
	ResetWorld()
end
local function Has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end
local function Near(a, b) return math.abs((a or -99) - b) < 1e-6 end
local function Lum(c)
	local function lin(v) if v <= 0.03928 then return v / 12.92 end return ((v + 0.055) / 1.055) ^ 2.4 end
	return 0.2126 * lin(c[1]) + 0.7152 * lin(c[2]) + 0.0722 * lin(c[3])
end
local function Ratio(a, b)
	local x, y = Lum(a), Lum(b)
	if x < y then x, y = y, x end
	return (x + 0.05) / (y + 0.05)
end
-- une créature capturée (fiche par espèce), son spécimen et l'apparence portée
local function Own(npc, fields)
	local data = NS:CaptureData()
	data.creatures[npc] = { name = fields.name or ("Bête " .. npc), normal = true, stars = fields.stars or 1, zoneID = ZONE,
		type = "Bête", class = "normal", at = 1793000000 }
	data.count = (data.count or 0) + 1
	NS:SpecimenReconcile(npc)
	local ref = NS:SpecimenReference(npc, false)
	ref.trait, ref.size = fields.trait, fields.size
	data.specSerial = (data.specSerial or 0) + 1
	return ref.id
end
local function Wear(npc, shiny)
	NS:CompanionData().appearance = "cap:" .. npc .. (shiny and ":s" or "")
end
local function Touch()
	local capture = NS:CaptureData()
	capture.specSerial = (capture.specSerial or 0) + 1
	capture.serial = (capture.serial or 0) + 1
end

-- 1. Tables : caractères, poids, tailles -------------------------------------------------------------------
do
	Say("-- qc31 : caractères et tailles, les tables")
	local total, rare, ok = 0, 0, true
	for _, item in ipairs(NS.SPECIMEN_TRAIT_WEIGHTS) do
		total = total + item[2]
		if not NS.PERSONALITY_TRAITS[item[1]] then ok = false end
		if NS.SPECIMEN_TRAIT_RARE[item[1]] then
			rare = rare + 1
			if item[2] ~= 1 then ok = false end
		elseif item[2] ~= 3 then ok = false end
	end
	local formed = {}
	for _, id in ipairs(NS.PERSONALITY_FORMED) do formed[id] = true end
	local commons = 0
	for _, item in ipairs(NS.SPECIMEN_TRAIT_WEIGHTS) do if formed[item[1]] then commons = commons + 1 end end
	Check("[T31] caractères tirés : ceux du compagnon, les six « formés » communs ×3, rares (Zen, Espiègle) ×1", ok
		and rare == 2 and total == 20 and #NS.SPECIMEN_TRAIT_WEIGHTS == 8 and commons == 6)
	local sum, byId = 0, {}
	for _, def in ipairs(NS.SPECIMEN_SIZES) do sum = sum + def.weight; byId[def.id] = def end
	Check("[T31] tailles : 2 / 18 / 60 / 18 / 2 %, échelles 0,75 / 0,88 / 1 / 1,12 / 1,25", sum == 100
		and byId.tiny.weight == 2 and byId.small.weight == 18 and byId.normal.weight == 60 and byId.large.weight == 18
		and byId.giant.weight == 2 and byId.tiny.scale == 0.75 and byId.small.scale == 0.88 and byId.normal.scale == 1
		and byId.large.scale == 1.12 and byId.giant.scale == 1.25 and byId.tiny.rare and byId.giant.rare and not byId.large.rare)
	local missing = {}
	for id in pairs(NS.PERSONALITY_TRAITS) do
		local effect = NS.COMPANION_TRAIT_EFFECTS[id]
		local def = effect and NS.COMPANION_EFFECTS[effect]
		if not def then missing[#missing + 1] = id
		elseif def.base > 0.25 or def.base ~= def.cap or def.kind == "sack" then missing[#missing + 1] = id .. "(valeur)" end
	end
	Check("[T31] chaque caractère a un petit effet fixe, d'une sorte existante", #missing == 0, table.concat(missing, ","))
	local strings, bad = NS.SPECIMEN_TRAIT_STRINGS, {}
	for key in pairs(strings.fr) do if strings.en[key] == nil then bad[#bad + 1] = key end end
	for key in pairs(strings.en) do if strings.fr[key] == nil then bad[#bad + 1] = key end end
	for id in pairs(NS.COMPANION_TRAIT_EFFECTS) do
		local key = "EFF_trait_" .. id
		if not (NS.EFFECT_STRINGS.fr[key] and NS.EFFECT_STRINGS.en[key]) then bad[#bad + 1] = key end
	end
	Check("[T31] textes FR/EN : mêmes clés", #bad == 0, table.concat(bad, ","))
end

-- 2. Tirages -----------------------------------------------------------------------------------------------
do
	Say("-- qc31 : tirages")
	local function T(v) W.Roll(v); local t = NS:SpecimenRollTrait(); math.random = W.random; return t end
	local function S(v) W.Roll(v); local s = NS:SpecimenRollSize(); math.random = W.random; return s end
	Check("[T31] caractère : 0 -> Curieux, 0,16 -> Gourmand, 0,92 -> Zen, 0,99 -> Espiègle",
		T(0) == "curious" and T(0.16) == "glutton" and T(0.92) == "zen" and T(0.99) == "mischievous")
	Check("[T31] taille : 0,59 -> normal, 0,61 -> petit, 0,79 -> grand, 0,97 -> minuscule, 0,99 -> géant",
		S(0.59) == "normal" and S(0.61) == "small" and S(0.79) == "large" and S(0.97) == "tiny" and S(0.99) == "giant")
	-- sur beaucoup de tirages : proportions proches
	local counts, traits = {}, {}
	for _ = 1, 20000 do
		local s = NS:SpecimenRollSize()
		counts[s] = (counts[s] or 0) + 1
		local t = NS:SpecimenRollTrait()
		traits[t] = (traits[t] or 0) + 1
	end
	Check("[T31] 20 000 tirages : normal ~60 %, géant ~2 %, Curieux ~15 %, Zen ~5 %",
		math.abs(counts.normal / 20000 - 0.6) < 0.02 and math.abs((counts.giant or 0) / 20000 - 0.02) < 0.006
		and math.abs(traits.curious / 20000 - 0.15) < 0.015 and math.abs((traits.zen or 0) / 20000 - 0.05) < 0.01)
end

-- 3. À la capture : tirés, dans le message, hauts faits ----------------------------------------------------
do
	Say("-- qc31 : à la capture")
	W.Reset("sobre")
	local lines = {}
	local print = NS.Print
	NS.Print = function(self, text) lines[#lines + 1] = tostring(text); return print(self, text) end
	W.Roll(0.99)
	W.SeeKill(5200, { name = "Raptor" })
	math.random = W.random
	NS:CaptureGrant("sifflet", { quiet = true, silent = true })
	NS:CaptureToggleAid("sifflet")
	-- lancer réussi (0), puis le caractère (0,92 : Zen), puis la taille (0,99 : géant)
	W.Rolls({ 0, 0, 0, 0, 0, 0 })
	local feats = NS.featsDormant
	NS.featsDormant = nil
	local flagged = {}
	local flag = NS.FeatFlag
	NS.FeatFlag = function(self, key, scope) flagged[key] = scope; return 1 end
	local rollTrait, rollSize = NS.SpecimenRollTrait, NS.SpecimenRollSize
	NS.SpecimenRollTrait = function() return "zen" end
	NS.SpecimenRollSize = function() return "giant" end
	NS:CaptureThrow()
	W.Settle()
	NS.SpecimenRollTrait, NS.SpecimenRollSize = rollTrait, rollSize
	NS.FeatFlag = flag
	NS.featsDormant = feats
	NS.Print = print
	math.random = W.random
	local ref = NS:SpecimenReference(5200, false)
	Check("[T31] capturé : caractère et taille tirés, gardés dans le spécimen", ref and ref.trait == "zen" and ref.size == "giant")
	local said, glyph = false, false
	for _, line in ipairs(lines) do
		if Has(line, "Raptor") and Has(line, " · Géant · Zen") then said = true end
		if Has(line, "★") or Has(line, "☆") then glyph = true end
	end
	Check("[T31] message de capture : « Raptor : <étoiles> · Géant · Zen », sans ★ ni ☆ (absents de la police du jeu)",
		said and not glyph, table.concat(lines, " | "))
	Check("[T31] géant : haut fait « Un géant parmi les bêtes » (drapeau du compte)", flagged.sizeGiant == "account"
		and flagged.sizeTiny == nil)
	-- minuscule
	NS.featsDormant = nil
	flagged = {}
	NS.FeatFlag = function(self, key, scope) flagged[key] = scope; return 1 end
	NS:SpecimenAdd({ npc = 5201, stars = 1, size = "tiny", name = "Souris" })
	NS:SpecimenAdd({ npc = 5202, stars = 1, size = "giant", origin = "gift3", name = "Ours" })
	NS.FeatFlag = flag
	NS.featsDormant = feats
	Check("[T31] minuscule capturé : « Petit mais costaud » ; un cadeau géant ne compte pas", flagged.sizeTiny == "account"
		and flagged.sizeGiant == nil)
	local giant, tiny = NS:FeatDef("men_size_giant"), NS:FeatDef("men_size_tiny")
	Check("[T31] hauts faits : Créatures, compte, 10 points, codes 176 et 177, drapeaux", giant and tiny and giant.cat == "men"
		and giant.scope == "account" and giant.pts == 10 and giant.n == 176 and tiny.n == 177 and giant.crit[2] == "sizeGiant"
		and tiny.crit[2] == "sizeTiny" and NS.L.FEAT_men_size_giant == "Un géant parmi les bêtes"
		and NS.L.FEAT_men_size_tiny == "Petit mais costaud" and NS:FeatDescription(giant) == "Capturer un spécimen géant")
	-- hors capture : taille normale, caractère tiré
	local id = NS:SpecimenAdd({ npc = 5203, stars = 2, origin = "migration", name = "Loup" })
	local spec = NS:SpecimenGet(id)
	Check("[T31] hors capture : taille normale, un caractère quand même", spec.size == "normal" and NS.PERSONALITY_TRAITS[spec.trait])
	W.Done()
end

-- 4. Le spécimen porté : caractère, voix -------------------------------------------------------------------
do
	Say("-- qc31 : le spécimen porté fait le caractère")
	W.Reset("sobre")
	local persona = NS:PersonaData()
	persona.formed = "lazy"
	Own(900, { name = "Raptor", stars = 2, trait = "daring", size = "large" })
	local mascot = NS:CompanionTrait() == "lazy"
	Wear(900)
	Check("[T31] mascotte : le caractère formé ; Raptor porté : son caractère (Téméraire), dit sur la page Caractère", mascot
		and NS:CompanionTrait() == "daring" and NS:CompanionWornSpecimen().size == "large" and Has(NS:PersonaDescribe(), "Téméraire"))
	NS:DB().companionTraitSource = 2
	local own = NS:CompanionTrait() == "lazy"
	NS:DB().companionTraitSource = 1
	NS:DB().companionTraitPick = 4
	Check("[T31] réglage « Le sien » : le caractère formé ; un caractère choisi ne passe pas devant celui du spécimen",
		own and NS:CompanionTrait() == "daring")
	NS:DB().companionTraitPick = 0
	-- voix teintée : « KILL » d'une bête téméraire
	W.Roll(0)
	local key = NS:CompanionVoicePick("KILL", { "Kodo" })
	math.random = W.random
	local pool, found = NS.COMPANION_POOLS["KILL_V_beast_daring"], false
	for _, k in ipairs(pool or {}) do if k == key then found = true end end
	Check("[T31] voix : la touche de son caractère (KILL_V_beast_daring)", found, tostring(key))
	-- un caractère rare : débloqué au choix, description sans la tortue
	Own(901, { name = "Kodo", trait = "zen", size = "normal" })
	Wear(901)
	Check("[T31] Zen capturé : son caractère, débloqué dans les réglages, description sans tortue", NS:CompanionTrait() == "zen"
		and NS:PersonaData().unlocked.zen == true and not Has(NS:PersonaDescribe(), "tortue") and Has(NS:PersonaDescribe(), "Zen"))
	-- version brillante : son propre spécimen
	NS:CaptureData().creatures[901].shiny, NS:CaptureData().creatures[901].shinyStars = true, 1
	NS:SpecimenAdd({ npc = 901, stars = 1, shiny = true, name = "Kodo", trait = "cuddly", size = "small" })
	Wear(901, true)
	Check("[T31] Kodo brillant porté : le caractère du spécimen brillant", NS:CompanionTrait() == "cuddly")
	-- Mettre au Codex : le caractère suit
	local other = NS:SpecimenAdd({ npc = 900, stars = 1, name = "Raptor", trait = "glutton", size = "tiny" })
	Wear(900)
	NS:SpecimenSetReference(other)
	Check("[T31] « Mettre au Codex » : le nouveau spécimen porté donne le sien", NS:CompanionTrait() == "glutton")
	-- rien n'est alloué à la lecture (gardé)
	local a = NS:CompanionWornSpecimen()
	collectgarbage("stop")
	local before = collectgarbage("count")
	for _ = 1, 200 do NS:CompanionTrait(); NS:CompanionWornSpecimen() end
	local grown = collectgarbage("count") - before
	collectgarbage("restart")
	Check("[T31] caractère lu 200 fois : rien d'alloué (spécimen porté gardé)", NS:CompanionWornSpecimen() == a and grown < 1,
		string.format("%.2f Ko", grown))
	W.Done()
end

-- 5. Effet du caractère ------------------------------------------------------------------------------------
do
	Say("-- qc31 : l'effet du caractère")
	W.Reset("sobre")
	local id = Own(900, { name = "Raptor", stars = 1, trait = "curious", size = "normal" })
	Wear(900)
	local effects = NS:CompanionEffects()
	local text = NS:CompanionEffectsText(effects)
	Check("[T31] effets : un troisième, celui du caractère (10 %) : « Caractère : Curieux, la curiosité baisse 10 % moins vite »",
		effects and effects.trait and effects.trait.id == "trait_curious" and Near(effects.trait.value, 0.10)
		and effects.trait.trait == "curious" and text[3] == "Caractère : Curieux, la curiosité baisse 10 % moins vite",
		tostring(text[3]))
	Mock.now = Mock.now + NS.EFFECT_DELAY + 1
	effects = NS:CompanionEffects()
	Check("[T31] actif après le délai", effects.active and NS:CompanionEffectValue("trait_curious") > 0)
	local withTrait = NS:CompanionDecayFactor("curiosity")
	NS:SpecimenGet(id).trait = "lazy"
	Touch()
	local without = NS:CompanionDecayFactor("curiosity")
	Check("[T31] Curieux : curiosité ×0,9 (et ×0,7 de son caractère)", Near(withTrait / without, 0.9 * NS.PERSONALITY_DECAY),
		string.format("%.4f", withTrait / without))
	-- sortes additionnées : un même effet de type et de caractère
	NS:SpecimenGet(id).trait = "mischievous"
	Touch()
	local bonus = NS:CompanionCaptureBonus({ class = "normal", type = "Bête", npcID = 900 })
	Check("[T31] Espiègle : capture +3 % sur tout", Near(bonus, 0.03), tostring(bonus))
	NS.SHINY_CHANCE = 1 / 150
	NS:SpecimenGet(id).trait = "mystic"
	Touch()
	local s1 = NS:ShinyChance("normal", 0, "humanoid")
	NS:SpecimenGet(id).trait = "lazy"
	Touch()
	local s0 = NS:ShinyChance("normal", 0, "humanoid")
	Check("[T31] Mystique : brillants +5 % sur toutes les créatures", s0 > 0 and Near(s1 / s0, 1.05), tostring(s1) .. "/" .. tostring(s0))
	-- jamais sur le combat, l'XP ni le butin
	local kinds = { decay = true, treatZone = true, capture = true, rest = true, pet = true, aidKeep = true, chain = true,
		shiny = true, aidZone = true, aidRefund = true }
	local odd = {}
	for traitId, effectId in pairs(NS.COMPANION_TRAIT_EFFECTS) do
		if not kinds[NS.COMPANION_EFFECTS[effectId].kind] then odd[#odd + 1] = traitId end
	end
	Check("[T31] sortes d'effet : envies, friandises, aides, capture, brillants seulement", #odd == 0, table.concat(odd, ","))
	-- mascotte : pas d'effet de caractère
	NS:CompanionData().appearance = nil
	local mascot = NS:CompanionEffects()
	-- fiche des Créatures : pas de troisième ligne d'effet (le caractère est sur la ligne des étoiles)
	local entry = { known = true, npc = 900, class = "normal", type = "Bête" }
	Check("[T31] mascotte, fiche des Créatures : pas de ligne « Caractère » (deux lignes d'effet)", mascot and mascot.trait == nil
		and #NS:CompanionEffectsText(mascot) == 2 and #NS:CompanionEffectsLines(entry, false) == 2)
	W.Done()
end

-- 6. La taille dans le cadre -------------------------------------------------------------------------------
do
	Say("-- qc31 : la taille dans le cadre du compagnon")
	W.Reset("sobre")
	Own(900, { name = "Raptor", trait = "curious", size = "giant" })
	Wear(900)
	local sp, cp = NS:CompanionSizeScale("pied")
	local sb, cb = NS:CompanionSizeScale("buste")
	local s, cam = NS:CompanionSizeScale("portrait")
	Check("[T31] géant : ×1,25 en pied, ×1,15 en buste, ×1,10 en portrait, caméra reculée d'autant",
		Near(sp, 1.25) and Near(cp, 1.125) and Near(sb, 1.15) and Near(cb, 1.075) and Near(s, 1.10) and Near(cam, 1.05))
	local bad = {}
	for _, framing in ipairs({ "pied", "buste", "portrait" }) do
		local a, b = NS:CompanionSizeScale(framing)
		if a / b > 1.12 + 1e-6 then bad[#bad + 1] = framing end
	end
	Check("[T31] taille vue à l'œil jamais au-delà de ×1,12 (échelle / caméra), il reste dans son cadre", #bad == 0,
		table.concat(bad, ","))
	NS:SpecimenGet(NS:SpecimenReference(900, false).id).size = "tiny"
	Touch()
	s, cam = NS:CompanionSizeScale("pied")
	local saved = NS.SPECIMEN_SIZE_BY_ID.tiny.scale
	NS.SPECIMEN_SIZE_BY_ID.tiny.scale = 0.2
	local bounded = NS:CompanionSizeScale("pied")
	NS.SPECIMEN_SIZE_BY_ID.tiny.scale = saved
	Check("[T31] minuscule : ×0,75, caméra inchangée ; échelle bornée (0,75 à 1,25)", Near(s, 0.75) and cam == 1 and Near(bounded, 0.75))
	-- appliquée au modèle du cadre
	NS:SpecimenGet(NS:SpecimenReference(900, false).id).size = "large"
	Touch()
	NS:DB().companionFraming = "pied"
	NS:EnsureCompanionFrame()
	NS:CompanionApplyModel()
	local frame = NS.companionFrame
	local large = frame and Near(frame.sizeScale, 1.12)
	NS:CompanionData().appearance = nil
	NS:CompanionApplyModel()
	Check("[T31] cadre du compagnon : échelle du spécimen (grand ×1,12) ; mascotte : ×1", large and Near(NS.companionFrame.sizeScale, 1))
	W.Done()
end

-- 7. Migration 3.0 -> 3.1 ----------------------------------------------------------------------------------
do
	Say("-- qc31 : migration 3.0 -> 3.1")
	W.Reset("sobre")
	local capture = NS:CaptureData()
	capture.creatures[11] = { name = "Kodo", normal = true, stars = 2, at = 100, zoneID = ZONE, type = "Bête" }
	capture.creatures[12] = { name = "Raptor", normal = true, stars = 3, at = 110, type = "Bête" }
	capture.creatures[13] = { name = "Ours", normal = true, stars = 1, at = 120, type = "Bête" }
	capture.count = 3
	NS:SpecimenMigrate()
	-- une sauvegarde 3.0 : spécimens sans caractère ni taille
	for _, spec in pairs(capture.specimens) do spec.trait, spec.size = nil, nil end
	capture.traitV, capture.traitDirty = nil, nil
	local persona = NS:PersonaData()
	persona.formed = "teasing"
	Wear(11)
	-- un autre personnage du compte porte le Raptor, son compagnon est Gourmand
	local db = NS:DB()
	db.chars = db.chars or {}
	db.chars["Autre - Royaume"] = { companion = { appearance = "cap:12", persona = { formed = "glutton", unlocked = {} } } }
	NS.CompanionWornForget(NS)
	local before = NS.CompanionTraitBase(NS) == "teasing"
	NS.SpecimenStore(NS)
	local kodo, raptor, ours = NS:SpecimenReference(11), NS:SpecimenReference(12), NS:SpecimenReference(13)
	Check("[T31] le spécimen porté garde le caractère du compagnon (Taquin)", before and kodo.trait == "teasing")
	Check("[T31] celui d'un autre personnage aussi (Gourmand)", raptor.trait == "glutton")
	Check("[T31] les autres : un caractère tiré", NS.PERSONALITY_TRAITS[ours.trait] ~= nil)
	local normal = true
	for _, spec in pairs(capture.specimens) do if spec.size ~= "normal" then normal = false end end
	Check("[T31] tous en taille normale (pas de taille rare rétroactive), version notée", normal
		and capture.traitV == NS.SPECIMEN_TRAIT_SCHEMA)
	Check("[T31] rien ne change pour le compagnon porté", NS:CompanionTrait() == "teasing")
	local snapshot = ours.trait
	local serial = capture.specSerial
	W.Roll(0.99)
	local again = NS.SpecimenTraitsFill(NS, capture)
	math.random = W.random
	Check("[T31] migration idempotente : rien de refait", again == 0 and ours.trait == snapshot and kodo.trait == "teasing"
		and capture.specSerial == serial)
	-- une fiche versée plus tard (collection d'un personnage) : son spécimen reçoit un caractère
	capture.creatures[14] = { name = "Grue", normal = true, stars = 1, at = 130, type = "Bête" }
	NS:SpecimenReconcile(14)
	NS.SpecimenStore(NS)
	local grue = NS:SpecimenReference(14)
	Check("[T31] spécimen refait plus tard : caractère et taille", grue and NS.PERSONALITY_TRAITS[grue.trait] and grue.size == "normal")
	-- compagnon pas encore formé : un caractère tiré pour le spécimen porté
	for _, spec in pairs(capture.specimens) do spec.trait = nil end
	capture.traitV = nil
	persona.formed = nil
	db.chars["Autre - Royaume"] = nil
	NS.SpecimenStore(NS)
	Check("[T31] compagnon pas encore formé : le spécimen porté reçoit un caractère tiré",
		NS.PERSONALITY_TRAITS[NS:SpecimenReference(11).trait] ~= nil)
	W.Done()
end

-- 8. Cadeau de la 3.0 --------------------------------------------------------------------------------------
do
	Say("-- qc31 : cadeau de la 3.0")
	W.Reset("sobre")
	local capture = NS:CaptureData()
	for npc = 21, 25 do capture.creatures[npc] = { name = "Bête " .. npc, normal = true, stars = 2, at = 100, type = "Bête" } end
	capture.count = 5
	NS:SpecimenMigrate()
	W.Roll(0.99)
	local ids = NS:Gift30Grant({ 21, 22 })
	math.random = W.random
	local a, b = NS:SpecimenGet(ids[1]), NS:SpecimenGet(ids[2])
	Check("[T31] copies du cadeau : un caractère tiré, taille normale", a.trait == "mischievous" and b.trait == "mischievous"
		and a.size == "normal" and b.size == "normal")
	W.Done()
end

-- 9. Affichage : Réserve, allure, Créatures, page Compagnon, Ses effets, scène (deux styles) ---------------
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- qc31 : affichage (" .. style .. ")")
	W.Reset(style)
	local data = NS:CaptureData()
	data.creatures[900] = { name = "Raptor", normal = true, stars = 3, zoneID = ZONE, type = "Bête", class = "normal", at = 1793000000 }
	data.count = 1
	NS:SpecimenMigrate()
	local ref = NS:SpecimenReference(900)
	ref.trait, ref.size = "curious", "large"
	Touch()
	local giant = NS:SpecimenAdd({ npc = 900, stars = 1, name = "Raptor", trait = "zen", size = "giant", origin = "capture" })
	local plain = NS:SpecimenAdd({ npc = 900, stars = 1, name = "Raptor", trait = "cuddly", size = "normal", origin = "capture" })
	local tips = {}
	local ui = NS.JournalUI
	local tip = ui.Tip
	ui.Tip = function(owner, title, lines) tips[#tips + 1] = { title = title, lines = lines } end
	-- Réserve
	local f = NS:OpenReserve()
	local rv = f.res.reserve
	local tileGiant, tilePlain
	for _, tile in ipairs(rv.tiles) do
		if tile:IsShown() and tile.spec and tile.spec.id == giant then tileGiant = tile end
		if tile:IsShown() and tile.spec and tile.spec.id == plain then tilePlain = tile end
	end
	local c = tileGiant and tileGiant.sizeTag.textColor or {}
	Check("[T31] " .. style .. " : vignette de Réserve : « XL » pour un géant (pastille lisible, ≥ 4,5:1 sur son pavé), rien pour un normal",
		tileGiant and tilePlain and tileGiant.sizeTag:IsShown() and tileGiant.sizeTag:GetText() == "XL" and tileGiant.sizeBack:IsShown()
		and not tilePlain.sizeTag:IsShown() and c[1] and Ratio(c, NS.Theme.NAV) >= 4.5 and tileGiant.sizeTag.azKeep == true)
	NS:ReservePick(giant)
	local p = rv.preview
	local sizeText = p.lines[rv.sizeLine] and p.lines[rv.sizeLine]:GetText()
	local traitText = p.lines[rv.traitLine] and p.lines[rv.traitLine]:GetText()
	Check("[T31] " .. style .. " : fiche : « Taille : Géant », « Caractère : Zen (les envies baissent 5 % moins vite) »",
		sizeText == "Taille : Géant" and traitText == "Caractère : Zen (les envies baissent 5 % moins vite)", tostring(sizeText) .. " / " .. tostring(traitText))
	if style == "sobre" then
		local tc = p.lines[rv.traitLine].textColor or {}
		Check("[T31] sobre : caractère à sa couleur (rare : ambre clair), taille aussi", tc[1] == NS.Theme.GOLD_LIGHT[1]
			and (p.lines[rv.sizeLine].textColor or {})[1] == NS.Theme.GOLD_LIGHT[1])
	else
		Check("[T31] azeroth : lignes à l'encre mesurée de la fiche", p.lines[rv.sizeLine].azRole == "reserve.detail"
			and p.lines[rv.traitLine].azRole == "reserve.detail")
	end
	tips = {}
	NS:ReserveTileTip(tileGiant)
	local tipText = tips[1] and table.concat(tips[1].lines, " | ") or ""
	-- choix d'allure
	tips = {}
	local def = NS:CompanionAppearanceDef("cap:900")
	NS:AllureTileTip({ def = def })
	local allureText = tips[1] and table.concat(tips[1].lines, " | ") or ""
	Check("[T31] " .. style .. " : infobulles : vignette « Géant · Zen », choix d'allure « Grand · Curieux » (celui du Codex)",
		Has(tipText, "Géant · Zen") and Has(allureText, "Grand · Curieux"), tipText .. " / " .. allureText)
	-- fiche des Créatures (ligne des étoiles)
	f = NS:ToggleJournal(true)
	NS:SelectJournalKind("menagerie")
	f = NS.journalFrame
	local entry
	for _, row in ipairs(f.men.items or {}) do if row.entry and row.entry.npc == 900 then entry = row.entry end end
	if not entry and NS.MenagerieList then
		for _, item in ipairs(NS:MenagerieList() or {}) do if item.npc == 900 then entry = item end end
	end
	local found = false
	if entry then
		NS:JournalPreviewMenagerie(entry)
		for _, line in ipairs(f.men.preview.lines) do if Has(line:GetText(), "Grand · Curieux") then found = true end end
	end
	Check("[T31] " .. style .. " : fiche des Créatures : « Grand · Curieux » après les étoiles", found)
	-- page Compagnon : étiquettes
	Wear(900)
	NS:SelectJournalKind("evolution")
	local pane = NS.journalFrame.evo
	Check("[T31] " .. style .. " : page Compagnon : étiquettes CURIEUX (à sa couleur : bleu) et GRAND", pane.traitTag:IsShown()
		and pane.traitTag.label:GetText() == NS.Theme.Upper("Curieux") and pane.traitTag.color == NS.Theme.BLUE
		and pane.sizeTag:IsShown() and pane.sizeTag.label:GetText() == NS.Theme.Upper("Grand"))
	local azKeep = true
	if style == "azeroth" then
		NS:CompanionEffectsRefreshPane(pane)
		azKeep = pane.effTrait.azKeep == true
	end
	Check("[T31] " .. style .. " : « Ses effets » : la ligne du caractère (à l'encre des effets en Azeroth), l'état en dessous",
		pane.effTrait and pane.effTrait:GetText() == "Caractère : Curieux, la curiosité baisse 10 % moins vite"
		and pane.effStateY < -58 and azKeep)
	NS:CompanionData().appearance = nil
	NS:RefreshJournal()
	Check("[T31] " .. style .. " : mascotte : pas d'étiquette de taille, pas de ligne de caractère", not pane.sizeTag:IsShown()
		and pane.effTrait:GetText() == "" and pane.effStateY == -58)
	ui.Tip = tip
	W.Done()
end

-- 10. Scène : écrite au verdict, une fois ------------------------------------------------------------------
do
	Say("-- qc31 : scène de capture")
	for _, style in ipairs({ "sobre", "azeroth" }) do
		W.Reset(style)
		NS:DB().companionCaptureAnim = true
		W.Roll(0.99)
		W.SeeKill(5300, { name = "Raptor" })
		math.random = W.random
		local rollTrait, rollSize = NS.SpecimenRollTrait, NS.SpecimenRollSize
		NS.SpecimenRollTrait = function() return "cuddly" end
		NS.SpecimenRollSize = function() return "small" end
		NS:CaptureGrant("sifflet", { quiet = true, silent = true })
		W.Roll(0)
		NS:CaptureThrow()
		local seen, sets = false, 0
		local stage = NS.captureStage
		local tags = stage and stage.specTags
		local set = tags and tags.SetText
		if tags then tags.SetText = function(fs, text) sets = sets + 1; return set(fs, text) end end
		for _ = 1, 40 do
			Mock:Advance(0.25)
			NS:CaptureTick(NS.Now())
			stage = NS.captureStage
			if stage and not tags then
				tags = stage.specTags
				set = tags and tags.SetText
				if tags then tags.SetText = function(fs, text) sets = sets + 1; return set(fs, text) end end
			end
			if stage and stage:IsShown() then NS:CaptureStageUpdate(NS.Now()) end
			if tags and tags:IsShown() and tags:GetText() == "Petit · Câlin" then seen = true end
		end
		NS.SpecimenRollTrait, NS.SpecimenRollSize = rollTrait, rollSize
		math.random = W.random
		local ref = NS:SpecimenReference(5300)
		Check("[T31] " .. style .. " : verdict : « Petit · Câlin » sous le bandeau, écrit au changement seulement (pas à chaque image)",
			ref and ref.trait == "cuddly" and seen and sets <= 4, tostring(sets))
		if style == "azeroth" then
			Check("[T31] azeroth : encre mesurée du pied (stage.status)", tags.azRole == "stage.status")
		else
			local c = tags and tags.textColor or {}
			Check("[T31] sobre : ambre clair, ≥ 4,5:1 sur la fenêtre", c[1] and Ratio(c, NS.Theme.WINDOW) >= 4.5)
		end
		if tags then tags.SetText = nil end
		W.Done()
	end
end

-- 11. Couleurs, tutoriel, réglages -------------------------------------------------------------------------
do
	Say("-- qc31 : couleurs, tutoriel, réglages")
	local low, lowName = 99, ""
	for id in pairs(NS.PERSONALITY_TRAITS) do
		local r = Ratio(NS:SpecimenTraitColor(id), NS.Theme.WINDOW)
		if r < low then low, lowName = r, id end
	end
	for _, def in ipairs(NS.SPECIMEN_SIZES) do
		local r = Ratio(NS:SpecimenSizeColor(def.id), NS.Theme.WINDOW)
		if r < low then low, lowName = r, def.id end
	end
	Check("[T31] couleurs des caractères et des tailles : jetons du thème, ≥ 4,5:1 sur la fenêtre", low >= 4.5,
		lowName .. "=" .. string.format("%.2f", low))
	local roles = NS.CarnetTokenRoles and NS.CarnetTokenRoles() or {}
	local inked = true
	for id in pairs(NS.PERSONALITY_TRAITS) do if not roles[NS:SpecimenTraitColor(id)] then inked = false end end
	for _, def in ipairs(NS.SPECIMEN_SIZES) do if not roles[NS:SpecimenSizeColor(def.id)] then inked = false end end
	Check("[T31] couleurs reconnues par le carnet Azeroth (encre mesurée sur parchemin)", inked)
	Check("[T31] textes : la visite guidée (Réserve) parle du caractère et de la taille, le réglage « Caractère : Apparence » aussi",
		Has(NS.L.TOUR_B_reserve, "caractère") and Has(NS.L.TOUR_B_reserve, "taille") and Has(NS.L.TOUR_B_reserve, "géant")
		and Has(NS.L.OPT_TRAIT_SOURCE_DESC_1, "créature capturée"))
end
