-- Compagnon : créatures brillantes et ouverture de coffre animée (Shiny.lua).
-- Tirage une fois par monstre (×3 élite ou rare), alerte et étoile (seul ou
-- chef, pas d'icône déjà posée, réglable), abattue : friandise, souvenir,
-- fiche dorée ; 5 / 15 / 30 : cadre, fond, aura ; coffre révélé objet par objet.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local SH = { saved = {}, random = math.random, units = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot" }
for _, name in ipairs(GLOBALS) do SH.saved[name] = rawget(_G, name) end
SH.savedChance = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"

function SH.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function SH.Install()
	local w = SH
	_G.UnitGUID = function(unit) if unit == "player" then return PLAYER end local u = w.units[unit]; return u and u.guid end
	_G.UnitName = function(unit) if unit == "player" then return "Testeur" end local u = w.units[unit]; return u and u.name end
	_G.UnitExists = function(unit) return unit == "player" or w.units[unit] ~= nil end
	_G.UnitIsPlayer = function(unit) return unit == "player" end
	_G.UnitIsDead = function(unit) local u = w.units[unit]; return u and u.dead == true or false end
	_G.UnitPlayerControlled = function() return false end
	_G.UnitReaction = function() return 2 end
	_G.UnitCanAttack = function() return true end
	_G.UnitClassification = function(unit) local u = w.units[unit]; return u and u.class or "normal" end
	_G.UnitCreatureType = function(unit) local u = w.units[unit]; return u and u.type or "Bête" end
	_G.UnitCreatureFamily = function() return nil end
	_G.UnitLevel = function(unit) if unit == "player" or unit == nil then return 20 end return 18 end
	_G.GetRaidTargetIndex = function(unit) local u = w.units[unit]; return u and u.icon end
	_G.SetRaidTarget = function(unit, icon) local u = w.units[unit]; if u then u.icon = icon end; w.marked = (w.marked or 0) + 1 end
	_G.IsInGroup = function() return w.group == true end
	_G.UnitIsGroupLeader = function() return w.leader == true end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
end
function SH.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText = nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
function SH.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "chestFrame" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.chestReveal = nil, nil, nil, nil, nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt = {}, nil
	SH.units, SH.group, SH.leader, SH.marked = {}, false, false, 0
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	SH.Install()
	NS.SHINY_CHANCE = 1 / 150
	math.random = SH.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	NS:CompanionUpdateVisibility()
	SH.Quiet()
end
-- une créature sous la cible, vue
function SH.See(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or SH.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	SH.units.target = fields
	return NS:BestiarySeeUnit("target"), fields.guid
end
function SH.Kill(guid)
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
end
-- le tirage (math.random() sans argument) est imposé ; les tirages entiers
-- (choix d'une réplique) restent ceux du jeu
function SH.Roll(value)
	math.random = function(a, b)
		if a and b then return SH.random(a, b) end
		if a then return SH.random(a) end
		return value
	end
end
function SH.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = SH.saved[name] end
	math.random = SH.random
	NS.SHINY_CHANCE = SH.savedChance
	ResetWorld()
end

-- 1. Tirage ---------------------------------------------------------------------------------
do
	Say("-- brillantes : tirage")
	SH.Reset()
	Check("[SHINY] chance : 1 sur 150, ×3 élite ou rare", math.abs(NS.SHINY_CHANCE - 1 / 150) < 1e-9 and NS.SHINY_RANK_MULT == 3)
	SH.Roll(0.5)
	local species, guid = SH.See(3100)
	Check("[SHINY] tirage raté : rien", species and not NS:ShinyState().live[guid] and NS.companionBubbleKey == nil)
	SH.Roll(0)
	SH.See(3100)
	Check("[SHINY] même monstre revu : pas de second tirage", not NS:ShinyState().live[guid])
	SH.Roll(1 / 150 * 2)
	local _, normal = SH.See(3101)
	Check("[SHINY] normal, tirage au-dessus de la chance : rien", not NS:ShinyState().live[normal])
	local _, elite = SH.See(3102, { class = "elite" })
	Check("[SHINY] élite : chance ×3, brillant", NS:ShinyState().live[elite] ~= nil)
	SH.Reset()
	NS.SHINY_CHANCE = 0
	SH.Roll(0)
	local _, none = SH.See(3103)
	Check("[SHINY] chance nulle : jamais", not NS:ShinyState().live[none])
	NS.SHINY_CHANCE = 1 / 150
	SH.units.target = { guid = SH.Guid(3104), name = "Mort", dead = true }
	Check("[SHINY] monstre mort : pas au bestiaire, pas de tirage", NS:BestiarySeeUnit("target") == nil
		and not NS:ShinyState().rolled[SH.Guid(3104)])
end

-- 2. Repérée : alerte et étoile ------------------------------------------------------------------
do
	Say("-- brillantes : repérée")
	SH.Reset()
	SH.Roll(0)
	local _, guid = SH.See(3200, { name = "Loup des plaines" })
	local live = NS:ShinyState().live[guid]
	Check("[SHINY] repérée : retenue avec sa zone et son espèce", live and live.zoneID == 1413 and live.npcID == 3200)
	Check("[SHINY] … la créature l'annonce", NS.companionBubbleKey == "SHINY_SPOTTED"
		and NS.companionBubbleText:find("Loup des plaines", 1, true), NS.companionBubbleText)
	Check("[SHINY] … le « ! »", NS.companionFrame.alert and NS.companionFrame.alert:IsShown())
	Check("[SHINY] … une étoile au-dessus (seul)", SH.units.target.icon == NS.SHINY_MARK and live.marked == true)
	SH.Quiet()
	SH.units.target = nil
	SH.group, SH.leader = true, false
	local _, other = SH.See(3201)
	Check("[SHINY] en groupe sans être chef : pas d'étoile", SH.units.target.icon == nil and NS:ShinyState().live[other].marked == false)
	SH.leader = true
	local _, lead = SH.See(3202)
	Check("[SHINY] chef du groupe : l'étoile", SH.units.target.icon == NS.SHINY_MARK)
	SH.group = false
	local _, marked = SH.See(3203, { icon = 8 })
	Check("[SHINY] déjà une icône : on n'y touche pas", SH.units.target.icon == 8 and NS:ShinyState().live[marked].marked == false)
	NS:DB().companionShinyMark = false
	SH.See(3204)
	Check("[SHINY] réglage coupé : pas d'étoile", SH.units.target.icon == nil)
	NS:DB().companionShinyMark = true
end

-- 3. Abattue -----------------------------------------------------------------------------------------
do
	Say("-- brillantes : abattue")
	SH.Reset()
	SH.Roll(0)
	local _, guid = SH.See(3300, { name = "Kodo brillant" })
	SH.Quiet()
	SH.Roll(0.5)
	SH.Kill(guid)
	local shiny = NS:ShinyData()
	Check("[SHINY] abattue : comptée", shiny.count == 1 and NS:ShinyFound(1413, 3300) ~= nil)
	Check("[SHINY] … plus vivante", NS:ShinyState().live[guid] == nil)
	Check("[SHINY] … une friandise", NS:TreatTotal() == 1 and NS:TreatCount("festin") == 0, NS:TreatTotal())
	Check("[SHINY] … sa bulle", NS.companionBubbleKey == "SHINY_KILLED" and NS.companionBubbleText:find("Kodo brillant", 1, true),
		NS.companionBubbleText)
	local memory = NS:MemoryData().memories[#NS:MemoryData().memories]
	Check("[SHINY] … un souvenir (avec photo permise)", memory and memory.kind == "shiny"
		and NS:MemoryText(memory):find("Kodo brillant", 1, true) and NS.MEMORY_PHOTO_KINDS.shiny == true)
	Check("[SHINY] zone : une brillante", NS:ShinyZoneCount(1413) == 1)
	SH.Roll(0)
	local _, second = SH.See(3301)
	SH.Kill(second)
	Check("[SHINY] tirage bas : un Festin", NS:TreatCount("festin") == 1)
	-- une brillante tuée par un autre (pas comptée au bestiaire) : rien
	SH.Roll(0)
	local _, lost = SH.See(3302)
	NS:BestiaryCombat("UNIT_DIED", nil, 0, lost, 0)
	Check("[SHINY] morte sans nous : oubliée, pas comptée", NS:ShinyData().count == 2 and NS:ShinyState().live[lost] == nil)
end

-- 4. Cadeaux des brillantes --------------------------------------------------------------------------
do
	Say("-- brillantes : cadeaux")
	SH.Reset()
	local unlocked = NS:CompanionData().unlocked
	NS:ShinyData().count = 4
	Check("[SHINY] prochain cadeau : 5", NS:ShinyNextReward().count == 5)
	SH.Roll(0)
	local _, guid = SH.See(3400)
	SH.Kill(guid)
	Check("[SHINY] 5 brillantes : cadre Étincelant", unlocked["frame:sparkle"] == true
		and Mock:Output():find("Étincelant", 1, true), Mock:Output())
	Check("[SHINY] … équipable", NS:CompanionSetStyle("frame", "sparkle") ~= nil)
	NS:ShinyData().count = 15
	NS:ShinyCheckRewards()
	Check("[SHINY] 15 : fond Poussière d'étoiles", unlocked["bg:stardust"] == true and NS:CompanionSetStyle("bg", "stardust"))
	NS:ShinyData().count = 30
	NS:ShinyCheckRewards()
	local aura = NS:ShinyAuraDef()
	Check("[SHINY] 30 : l'aura, portée", unlocked["orn:aura"] == true and NS:CompanionOrnamentShown(aura))
	Check("[SHINY] après 30 : le bébé hippogriffe à 50", NS:ShinyNextReward().count == 50
		and NS:ShinyNextReward().def.id == "hippogryph")
	NS:ShinyData().count = 50
	NS:ShinyCheckRewards()
	Check("[SHINY] 50 : le bébé hippogriffe", unlocked["app:hippogryph"] == true
		and NS:CompanionIsUnlocked("app", NS:CompanionAppearanceDef("hippogryph")))
	Check("[SHINY] tout gagné : plus de prochain cadeau", NS:ShinyNextReward() == nil)
	Check("[SHINY] pas deux fois", #NS:ShinyCheckRewards() == 0)
	Check("[SHINY] condition lisible", NS:CompanionRequirement({ shiny = 15 }) == "15 brillantes")
	local listed = false
	for _, item in ipairs(NS:CompanionNextUnlocks()) do if item.id == "aura" or item.id == "sparkle" then listed = true end end
	Check("[SHINY] pas d'objectif au compteur pour eux", not listed)
	-- l'aura : des étincelles de temps en temps
	NS.companionFx = nil
	NS:ShinyState().auraAt = 0
	Check("[SHINY] aura portée : étincelles", NS:ShinyAuraTick(100) == true)
	Check("[SHINY] … pas à chaque image", NS:ShinyAuraTick(100.5) == false)
	NS:DB().companionOrnAura = false
	Check("[SHINY] aura enlevée : rien", NS:ShinyAuraTick(200) == false)
	NS:DB().companionOrnAura = true
end

-- 5. Carnet : fiche dorée, tuile, Créature -------------------------------------------------------------
do
	Say("-- brillantes : carnet")
	SH.Reset()
	-- une zone sans table livrée : seules nos créatures au bestiaire
	Mock.world.maps[9800] = { mapID = 9800, name = "Val doré", parentMapID = 1414, mapType = 3 }
	Mock.world.mapID = 9800
	SH.Roll(0)
	local _, guid = SH.See(3500, { name = "Hyène dorée" })
	SH.Kill(guid)
	NS:DB().journalTracker = false
	NS:ToggleJournal(true)
	local f = NS.journalFrame
	NS:OpenJournalZone(9800)
	f.comp.tabs.combat:Click()
	local card
	for _, c in ipairs(f.comp.cards) do if c.item and c.item.id == 3500 then card = c end end
	Check("[SHINY] fiche : étoile et liseré doré", card and card.star:IsShown() and card.accent:IsShown() and card.accent.vertex[2] > 0.85)
	card.scripts.OnEnter(card)
	local said = {}
	for _, line in ipairs(f.comp.preview.lines) do said[#said + 1] = line.text or "" end
	Check("[SHINY] aperçu : « Brillante, abattue le … »", table.concat(said, " "):find("Brillante, abattue le", 1, true))
	f.sections.zones:Click()
	for _ = 1, 20 do NS:ScrollJournal(-1) end
	local tile
	for _, t in ipairs(f.zones.tiles) do if t.zoneID == 9800 then tile = t end end
	Check("[SHINY] tuile : le nombre de brillantes", tile and tile.badge.text:find("UI-RaidTargetingIcon_1", 1, true)
		and tile.badge.text:find(" 1", 1, true), tile and tile.badge.text)
	f.sections.evolution:Click()
	Check("[SHINY] Créature : brillantes et prochain cadeau", f.evo.shiny.text == "Brillantes : 1  ·  prochain cadeau à 5",
		f.evo.shiny.text)
	f:Hide()
end

-- 6. Ouverture de coffre animée ----------------------------------------------------------------------------
do
	Say("-- coffre : ouverture animée")
	SH.Reset()
	NS:ChestData()[1413] = { tier = 1, name = "Les Tarides", at = 0 }
	local frame = NS:OpenChest(1413)
	local buttons = {}
	for _, b in ipairs(frame.options) do if b.reward and b:IsShown() then buttons[#buttons + 1] = b end end
	Check("[CHESTFX] à l'ouverture : objets cachés", #buttons > 1 and buttons[1].alpha == 0 and NS.chestReveal ~= nil)
	Mock:Advance(NS.CHEST_REVEAL_STEP + 0.05)
	Check("[CHESTFX] un objet après l'autre", buttons[1].alpha == 1 and buttons[2].alpha == 0)
	for _ = 2, #buttons do Mock:Advance(NS.CHEST_REVEAL_STEP + 0.05) end
	Check("[CHESTFX] le dernier révélé : fin de l'animation, sans attendre", buttons[#buttons].alpha == 1 and NS.chestReveal == nil)
	frame:Hide()
	NS:DB().companionChestAnim = false
	frame = NS:OpenChest(1413)
	Check("[CHESTFX] réglage coupé : tout de suite", frame.options[1].alpha ~= 0 and NS.chestReveal == nil)
	frame:Hide()
	NS:DB().companionChestAnim = true
	frame = NS:OpenChest(1413)
	frame:Hide()
	Mock:Advance(1)
	Check("[CHESTFX] fermé en cours : tout remis visible", frame.options[1].alpha == 1 and NS.chestReveal == nil)
end

-- 7. Réglages, textes --------------------------------------------------------------------------------------
do
	Say("-- brillantes : réglages")
	local page
	for _, p in ipairs(NS.OPTION_PAGES) do if p.id == "companionDaily" then page = p end end
	Check("[SHINY] page « Au jour le jour »", page and page.parent == "companion" and #page.rows >= 2)
	Check("[SHINY] réglages par défaut : étoile et coffre animé", NS:DB().companionShinyMark == true and NS:DB().companionChestAnim == true)
	local missing = {}
	for key in pairs(NS.SHINY_STRINGS.fr) do if not NS.SHINY_STRINGS.en[key] then missing[#missing + 1] = key end end
	for name, keys in pairs(NS.SHINY_POOLS) do
		Check("[SHINY] répliques enregistrées : " .. name, NS.COMPANION_POOLS[name] == keys)
	end
	Check("[SHINY] textes fr et en", #missing == 0, table.concat(missing, ", "))
end

SH.Done()
