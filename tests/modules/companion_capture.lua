-- Compagnon : la ménagerie (Capture.lua). Un monstre abattu se propose à la
-- capture ; chance selon le rang et le niveau, aides (appât, lasso, sifflet)
-- gagnées aux tampons et paliers ; les créatures capturées deviennent des
-- apparences du compagnon.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local CP = { saved = {}, random = math.random, units = {} }
local GLOBALS = { "UnitGUID", "UnitName", "UnitExists", "UnitIsPlayer", "UnitIsDead", "UnitPlayerControlled",
	"UnitReaction", "UnitCanAttack", "UnitClassification", "UnitCreatureType", "UnitCreatureFamily", "UnitLevel",
	"GetRaidTargetIndex", "SetRaidTarget", "IsInGroup", "UnitIsGroupLeader", "IsInInstance", "Screenshot", "C_Timer" }
for _, name in ipairs(GLOBALS) do CP.saved[name] = rawget(_G, name) end
CP.savedShiny = NS.SHINY_CHANCE
local PLAYER = "Player-1-00000001"

function CP.Guid(npcID, spawn) return string.format("Creature-0-4378-1-12-%d-%s", npcID, spawn or "00001A2B3C") end
function CP.Install()
	local w = CP
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
		if unit == "player" or unit == nil then return w.playerLevel or 20 end
		local u = w.units[unit]; return u and u.level or 20
	end
	_G.GetRaidTargetIndex = function() return nil end
	_G.SetRaidTarget = function() end
	_G.IsInGroup = function() return false end
	_G.UnitIsGroupLeader = function() return false end
	_G.IsInInstance = function() return false, "none" end
	_G.Screenshot = function() end
	-- les bulles différées partent tout de suite (et sont comptées)
	w.later = {}
	_G.C_Timer = { After = function(_, fn) w.later[#w.later + 1] = fn; fn() end }
end
function CP.Quiet()
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.companionBubbleText = nil
	if NS.companionRT then NS.companionRT.cool = {} end
end
function CP.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "capturePrompt" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.companionFx, NS.shinyState, NS.captureState = nil, nil, nil, nil, nil
	NS.captureAppCache = nil
	NS.bestiaryUnits, NS.bestiaryPrunedAt, NS.bestiaryKilled = {}, nil, {}
	CP.units, CP.playerLevel = {}, 20
	Mock.world.maps[1413] = { mapID = 1413, name = "Les Tarides", parentMapID = 1414, mapType = 3 }
	Mock.world.maps[1414] = { mapID = 1414, name = "Kalimdor", parentMapID = 947, mapType = 2 }
	Mock.world.mapID, Mock.world.level = 1413, 20
	CP.Install()
	NS.SHINY_CHANCE = 0
	math.random = CP.random
	NS:CompanionData().tutoDone = true
	NS:TreatData().treatsInit = true
	-- la scène animée a ses propres tests (8.) : ici, la petite fenêtre seule
	NS:DB().companionCaptureAnim = false
	if NS.captureStage then NS.captureStage:Hide(); NS.captureStage.rolling = nil end
	NS:CompanionUpdateVisibility()
	CP.Quiet()
end
function CP.See(npcID, fields)
	fields = fields or {}
	fields.guid = fields.guid or CP.Guid(npcID, fields.spawn)
	fields.name = fields.name or ("Bête " .. npcID)
	CP.units.target = fields
	return NS:BestiarySeeUnit("target"), fields.guid
end
function CP.Kill(guid)
	NS:BestiaryCombat("SWING_DAMAGE", PLAYER, 0, guid, 0)
	NS:BestiaryCombat("PARTY_KILL", PLAYER, 0, guid, 0)
end
function CP.SeeKill(npcID, fields)
	local _, guid = CP.See(npcID, fields)
	CP.Kill(guid)
	return guid
end
function CP.Roll(value)
	math.random = function(a, b)
		if a and b then return CP.random(a, b) end
		if a then return CP.random(a) end
		return value
	end
end
-- fait tourner l'horloge jusqu'au verdict (secousses, puis fermeture)
function CP.Settle()
	for _ = 1, 12 do
		Mock:Advance(1)
		NS:CaptureTick(NS.Now())
	end
end
function CP.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = CP.saved[name] end
	math.random = CP.random
	NS.SHINY_CHANCE = CP.savedShiny
	ResetWorld()
end

-- 1. Chance --------------------------------------------------------------------------------------
do
	Say("-- capture : chance")
	CP.Reset()
	local function Pct(info, aid, level) return math.floor(NS:CaptureChance(info, aid, level) * 100 + 0.5 + 1e-9) end
	Check("[CAP] normal, même niveau : 30 %", Pct({ class = "normal", level = 20 }, nil, 20) == 30)
	Check("[CAP] élite 15 %, rare 8 %, rare élite 5 %, boss 2 %",
		Pct({ class = "elite", level = 20 }, nil, 20) == 15 and Pct({ class = "rare", level = 20 }, nil, 20) == 8
		and Pct({ class = "rareelite", level = 20 }, nil, 20) == 5 and Pct({ class = "worldboss", level = 20 }, nil, 20) == 2)
	Check("[CAP] 5 niveaux au-dessus : ×0,7", Pct({ class = "normal", level = 25 }, nil, 20) == 21)
	Check("[CAP] très au-dessus : plancher ×0,35", Pct({ class = "normal", level = 60 }, nil, 20) == 11)
	Check("[CAP] en dessous : +3 % par niveau, plafond ×1,5", Pct({ class = "normal", level = 15 }, nil, 20) == 35
		and Pct({ class = "normal", level = 1 }, nil, 60) == 45)
	Check("[CAP] appât ×1,5, lasso ×2,5", Pct({ class = "normal", level = 20 }, "appat", 20) == 45
		and Pct({ class = "normal", level = 20 }, "lasso", 20) == 75)
	Check("[CAP] plafond 95 % sans sifflet", Pct({ class = "normal", level = 1 }, "lasso", 60) == 95)
	local chance, sure = NS:CaptureChance({ class = "worldboss", level = 63 }, "sifflet", 20)
	Check("[CAP] sifflet : assurée, même un boss", chance == 1 and sure == true)
	Check("[CAP] rang inconnu : comme un normal", Pct({ class = "??", level = 20 }, nil, 20) == 30)
end

-- 2. Le coup fatal ouvre la fenêtre --------------------------------------------------------------
do
	Say("-- capture : proposée au coup fatal")
	CP.Reset()
	CP.SeeKill(3100, { name = "Loup des plaines", level = 19 })
	local pending = NS:CaptureState().pending
	Check("[CAP] abattu : capture proposée", pending and pending.npcID == 3100 and pending.name == "Loup des plaines")
	Check("[CAP] … fenêtre affichée avec son nom", NS.capturePrompt and NS.capturePrompt:IsShown()
		and NS.capturePrompt.name:GetText() == "Loup des plaines")
	Check("[CAP] … le compagnon pousse à tenter", NS.companionBubbleKey == "CAPTURE_PROMPT"
		and NS.companionBubbleText:find("Loup des plaines", 1, true) ~= nil, NS.companionBubbleText)
	Check("[CAP] … chance affichée (normal, 1 niveau dessous)", NS.capturePrompt.chance:GetText():find("31", 1, true) ~= nil,
		NS.capturePrompt.chance:GetText())
	Check("[CAP] … le modèle de la créature", NS.capturePrompt.model and NS.capturePrompt.model.creature == 3100
		or NS.capturePrompt.icon:IsShown())
	Mock:Advance(NS.CAPTURE_WINDOW + 1)
	NS:CaptureTick(NS.Now())
	Check("[CAP] temps écoulé : fenêtre fermée, plus d'essai", NS:CaptureState().pending == nil
		and not NS.capturePrompt:IsShown() and NS:CaptureThrow() == false)
	CP.Reset()
	NS:DB().companionCapture = false
	CP.SeeKill(3101)
	Check("[CAP] réglage coupé : rien proposé", NS:CaptureState().pending == nil and not NS.capturePrompt)
	NS:DB().companionCapture = true
	CP.Reset()
	NS:DB().companionEnabled = false
	CP.SeeKill(3102)
	Check("[CAP] compagnon coupé : rien", NS.captureState == nil or NS.captureState.pending == nil)
	NS:DB().companionEnabled = true
end

-- 3. Lancer : réussite, échec ----------------------------------------------------------------------
do
	Say("-- capture : lancer")
	CP.Reset()
	CP.SeeKill(3200, { name = "Kodo", level = 20 })
	CP.Roll(0.1)
	Check("[CAP] clic : filet lancé", NS:CaptureThrow() == true and NS:CaptureState().rolling ~= nil)
	Check("[CAP] … un seul essai à la fois", NS:CaptureThrow() == false)
	Check("[CAP] … les secousses s'affichent", NS.capturePrompt.status:IsShown() and not NS.capturePrompt.throw:IsShown())
	Mock:Reset()
	CP.Settle()
	local data = NS:CaptureData()
	local kodo = data.creatures[3200]
	Check("[CAP] réussite : dans la ménagerie", kodo and kodo.name == "Kodo" and kodo.zoneID == 1413 and data.count == 1)
	Check("[CAP] … annoncée dans le chat", Mock:Output():find("Kodo capturé", 1, true) ~= nil, Mock:Output())
	Check("[CAP] … le compagnon s'en réjouit", NS.companionBubbleKey == "CAPTURE_OK")
	Check("[CAP] … essai compté, fenêtre refermée", data.tries == 1 and not NS.capturePrompt:IsShown()
		and NS:CaptureState().rolling == nil)
	CP.Quiet()
	CP.SeeKill(3200, { name = "Kodo", spawn = "00002B" })
	Check("[CAP] espèce déjà capturée : plus proposée", NS:CaptureState().pending == nil)
	CP.SeeKill(3201, { name = "Hyène", level = 20 })
	CP.Roll(0.99)
	NS:CaptureThrow()
	Mock:Reset()
	CP.Settle()
	Check("[CAP] échec : pas dans la ménagerie", data.creatures[3201] == nil and data.count == 1 and data.tries == 2)
	Check("[CAP] … le compagnon se moque", NS.companionBubbleKey == "CAPTURE_FAIL"
		and NS.companionBubbleText:find("Hyène", 1, true) ~= nil, NS.companionBubbleText)
	Check("[CAP] … dit dans le chat", Mock:Output():find("Hyène s'est échappé", 1, true) ~= nil, Mock:Output())
	CP.Quiet()
	CP.SeeKill(3201, { name = "Hyène", spawn = "00003C" })
	Check("[CAP] espèce ratée : se repropose au prochain", NS:CaptureState().pending ~= nil)
end

-- 4. Aides --------------------------------------------------------------------------------------
do
	Say("-- capture : aides")
	CP.Reset()
	local items = NS:CaptureData().items
	Check("[CAP] besace vide au départ", items.appat == 0 and items.lasso == 0 and items.sifflet == 0)
	Check("[CAP] gagner un appât", NS:CaptureGrant("appat", { quiet = true }) == "ok" and items.appat == 1)
	for _ = 1, 12 do NS:CaptureGrant("appat", { quiet = true, silent = true }) end
	Check("[CAP] plafond : 10 appâts", items.appat == 10 and NS:CaptureGrant("appat", { quiet = true }) == "full")
	CP.SeeKill(3300, { name = "Raptor", class = "elite", level = 20 })
	Check("[CAP] choisir l'appât", NS:CaptureToggleAid("appat") == "appat"
		and NS.capturePrompt.chance:GetText():find("23", 1, true) ~= nil, NS.capturePrompt.chance:GetText())
	Check("[CAP] sans sifflet en poche : pas choisissable", NS:CaptureToggleAid("sifflet") == "appat")
	Check("[CAP] reclic : reposé", NS:CaptureToggleAid("appat") == nil)
	NS:CaptureToggleAid("appat")
	CP.Roll(0.99)
	NS:CaptureThrow()
	Check("[CAP] l'aide est dépensée au lancer", items.appat == 9)
	CP.Settle()
	NS:CaptureGrant("sifflet", { quiet = true })
	CP.SeeKill(3301, { name = "Seigneur", class = "worldboss", level = 63 })
	NS:CaptureToggleAid("sifflet")
	Check("[CAP] sifflet : « assurée » affiché", NS.capturePrompt.chance:GetText():find(NS.L.CAPTURE_SURE:gsub("%%s · ", ""), 1, true) ~= nil,
		NS.capturePrompt.chance:GetText())
	CP.Roll(0.999)
	NS:CaptureThrow()
	CP.Settle()
	Check("[CAP] sifflet : boss capturé à coup sûr", NS:CaptureData().creatures[3301] ~= nil and items.sifflet == 0)
	-- l'aide gardée d'une fois sur l'autre… tant qu'il en reste
	CP.SeeKill(3302)
	Check("[CAP] sifflet épuisé : plus choisi", NS:CaptureState().aid == nil)
end

-- 5. D'où viennent les aides -------------------------------------------------------------------
do
	Say("-- capture : tampons et paliers")
	CP.Reset()
	local items = NS:CaptureData().items
	CP.Roll(0)
	Mock:Reset()
	NS:CaptureOnStamp({ kind = "rare", name = "Rare", new = true })
	Check("[CAP] tampon de rare : un lasso", items.lasso == 1)
	Check("[CAP] … sans chat par défaut (le bandeau du carnet suffit)", Mock:Output() == "", Mock:Output())
	Check("[CAP] … une bulle, après celle du tampon", #CP.later == 1)
	NS:CaptureOnStamp({ kind = "dungeon", name = "Donjon", new = true })
	Check("[CAP] tampon de donjon : lasso, et la chance d'un sifflet", items.lasso == 2 and items.sifflet == 1)
	NS:CaptureOnStamp({ kind = "subzone", name = "Village", new = true })
	Check("[CAP] tampon de lieu : un appât (1 sur 4)", items.appat == 1)
	CP.Roll(0.9)
	NS:CaptureOnStamp({ kind = "subzone", name = "Village 2", new = true })
	Check("[CAP] tirage raté : rien", items.appat == 1)
	NS:CaptureOnStamp({ kind = "rare", name = "Rare", new = false })
	Check("[CAP] tampon déjà connu : rien", items.lasso == 2)
	NS:DB().journalChat = true
	CP.Roll(0)
	Mock:Reset()
	NS:CaptureOnStamp({ kind = "rare", name = "Rare 2", new = true })
	Check("[CAP] chat du carnet allumé : l'aide y est dite", Mock:Output():find("Lasso tressé", 1, true) ~= nil, Mock:Output())
	NS:DB().journalChat = false
	-- tirage pondéré : 60 / 33 / 7
	CP.Roll(0); local a = NS.CaptureDraw()
	CP.Roll(0.7); local b = NS.CaptureDraw()
	CP.Roll(0.97); local c = NS.CaptureDraw()
	Check("[CAP] tirage pondéré : appât, lasso, sifflet", a == "appat" and b == "lasso" and c == "sifflet")
	Check("[CAP] paliers de zone : 25 appât, 50 lasso, 75 tirage", NS.CAPTURE_MILESTONE_DROPS[25] == "appat"
		and NS.CAPTURE_MILESTONE_DROPS[50] == "lasso" and NS.CAPTURE_MILESTONE_DROPS[75] == "draw")
	-- brillante abattue : un lasso en prime
	CP.Reset()
	NS.SHINY_CHANCE = 1
	CP.Roll(0)
	local guid = CP.SeeKill(3400, { name = "Loup brillant" })
	Check("[CAP] brillante abattue : un lasso et la capture proposée", NS:CaptureData().items.lasso == 1
		and NS:CaptureState().pending and NS:CaptureState().pending.shiny == true, tostring(guid))
	NS:CaptureThrow()
	CP.Settle()
	Check("[CAP] brillante capturée : marquée", NS:CaptureData().creatures[3400].shiny == true)
	NS.SHINY_CHANCE = 0
end

-- 6. Les capturés deviennent des apparences ------------------------------------------------------
do
	Say("-- capture : apparences")
	CP.Reset()
	local before = #NS:CompanionUnlockedAppearances()
	CP.Roll(0)
	CP.SeeKill(3500, { name = "Ourson" })
	NS:CaptureThrow()
	CP.Settle()
	local list = NS:CompanionUnlockedAppearances()
	Check("[CAP] une apparence de plus", #list == before + 1 and list[#list].id == "cap:3500" and list[#list].npc == 3500)
	local found
	for _, choice in ipairs(NS:CompanionChoices("app")) do if choice.value == "cap:3500" then found = choice end end
	Check("[CAP] dans la liste des réglages, sous son nom", found and found.label == "Ourson" and not found.disabled)
	Check("[CAP] la choisir", NS:CompanionSetAppearance("cap:3500") ~= nil and NS:CompanionCurrentAppearance().id == "cap:3500")
	-- le simulacre n'a pas de PlayerModel : un cadre qui sait SetCreature
	local model = CreateFrame("Frame", nil, NS.companionFrame)
	model.SetCreature = function(self, id) self.creature = id end
	NS.companionFrame.model = model
	NS:CompanionApplyModel()
	Check("[CAP] le modèle de la créature (SetCreature)", model and model.creature == 3500, model and tostring(model.creature))
	local coll
	for _, entry in ipairs(NS:JournalCollection("app")) do if entry.def.id == "cap:3500" then coll = entry end end
	Check("[CAP] pas dans la Collection (elle vit dans la Ménagerie)", coll == nil)
	local men
	for _, entry in ipairs(NS:MenagerieList({ zone = "all", state = "captured" })) do if entry.npc == 3500 then men = entry end end
	Check("[CAP] dans la Ménagerie, capturée", men ~= nil and men.captured and men.known)
	-- dix captures : un sifflet offert
	local data = NS:CaptureData()
	for npc = 3501, 3509 do
		CP.SeeKill(npc)
		NS:CaptureThrow()
		CP.Settle()
	end
	Check("[CAP] 10 captures : un sifflet offert", data.count == 10 and data.items.sifflet == 1)
end

-- 7. Commande, textes, réglage -------------------------------------------------------------------
do
	Say("-- capture : commande et textes")
	CP.Reset()
	Mock:Reset()
	NS.EXTRA_COMMANDS["capture"](NS)
	Check("[CAP] /qc capture : ménagerie vide expliquée", Mock:Output():find("Ménagerie", 1, true) ~= nil, Mock:Output())
	local missing = {}
	for key in pairs(NS.CAPTURE_STRINGS.fr) do if not NS.CAPTURE_STRINGS.en[key] then missing[#missing + 1] = key end end
	Check("[CAP] textes fr et en", #missing == 0, table.concat(missing, ", "))
	for name, keys in pairs(NS.CAPTURE_POOLS) do
		Check("[CAP] répliques enregistrées : " .. name, NS.COMPANION_POOLS[name] == keys and #keys >= 2)
	end
	local row
	for _, r in ipairs(NS.DAILY_OPTION_ROWS) do if r.key == "companionCapture" then row = r end end
	Check("[CAP] réglage sur la page « Au jour le jour », allumé par défaut", row ~= nil and NS:DB().companionCapture == true)
end

-- 8. La scène animée -------------------------------------------------------------------------------
do
	Say("-- capture : scène animée")
	CP.Reset()
	NS:DB().companionCaptureAnim = true
	CP.SeeKill(3600, { name = "Ours gris", class = "rare", level = 20 })
	CP.Roll(0)
	Check("[CAPFX] clic : la scène remplace la petite fenêtre", NS:CaptureThrow() == true
		and NS.captureStage and NS.captureStage:IsShown() and not NS.capturePrompt:IsShown())
	local stage, rolling = NS.captureStage, NS:CaptureState().rolling
	Check("[CAPFX] rareté : rare = violet, trois losanges", stage.rarity == NS.CAPTURE_RARITY.rare
		and stage.pips[3]:IsShown() and not stage.pips[4]:IsShown())
	Check("[CAPFX] le nom à la couleur de la rareté", stage.name:GetText() == "Ours gris")
	Check("[CAPFX] t=0 : le filet est lancé", NS:CaptureStageUpdate(rolling.start) == "throw")
	Check("[CAPFX] en vol : le filet maillé encore replié", NS:CaptureStageUpdate(rolling.start + 0.1) == "throw"
		and not stage.mesh:IsShown())
	Check("[CAPFX] après le vol : les secousses", NS:CaptureStageUpdate(rolling.start + NS.CAPTURE_THROW_TIME + 0.1) == "shake")
	Check("[CAPFX] le filet maillé couvre la scène (cordes en losanges + bord)", stage.mesh:IsShown()
		and #stage.mesh.lines > 12 and stage.mesh.width == stage.scene.width)
	NS:CaptureStageUpdate(rolling.start + NS.CAPTURE_THROW_TIME + NS.CAPTURE_DRAPE_TIME + 0.01)
	Check("[CAPFX] posé : à sa taille, opaque, cordes à leur place", math.abs(stage.mesh:GetScale() - 1) < 0.08
		and stage.mesh.alpha == 1 and not stage.mesh.tear)
	Check("[CAPFX] le vol retarde la première secousse", rolling.nextAt >= rolling.start + NS.CAPTURE_THROW_TIME + NS.CAPTURE_SHAKE_STEP - 1e-6)
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[CAPFX] verdict : capturé, la scène reste affichée", rolling.result == "ok" and stage:IsShown())
	Check("[CAPFX] … bannière, gerbe de losanges", NS:CaptureStageUpdate(rolling.resultAt + 0.2) == "ok"
		and stage.bannerText:GetText() == NS.L.CAPTURE_GOT and stage.particles[1]:IsShown())
	Check("[CAPFX] … la gerbe s'éteint", NS:CaptureStageUpdate(rolling.resultAt + 1.5) == "ok" and not stage.particles[1]:IsShown())
	Check("[CAPFX] … le filet s'est refermé et effacé", not stage.mesh:IsShown())
	stage:GetScript("OnMouseUp")(stage)
	NS:CaptureTick(NS.Now())
	Check("[CAPFX] un clic ferme la scène", not stage:IsShown() and NS:CaptureState().rolling == nil)
	-- échec
	CP.SeeKill(3601, { name = "Loup", level = 20 })
	CP.Roll(0.99)
	NS:CaptureThrow()
	rolling = NS:CaptureState().rolling
	for _ = 1, 4 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[CAPFX] échec : « Échappé », en rouge", rolling.result == "fail"
		and NS:CaptureStageUpdate(rolling.resultAt + 0.3) == "fail" and stage.bannerText:GetText() == NS.L.CAPTURE_FLED)
	for _ = 1, 5 do Mock:Advance(1); NS:CaptureTick(NS.Now()) end
	Check("[CAPFX] fermée seule après le temps d'affichage", not stage:IsShown())
	-- brillante : dorée
	Check("[CAPFX] brillante : couleur dorée", NS:CaptureRarity({ class = "normal", shiny = true }).color == NS.Theme.GOLD_LIGHT)
	Check("[CAPFX] boss : cinq losanges", NS:CaptureRarity({ class = "worldboss" }).pips == 5)
	local row
	for _, r in ipairs(NS.DAILY_OPTION_ROWS) do if r.key == "companionCaptureAnim" then row = r end end
	Check("[CAPFX] réglage « Capture animée », allumé par défaut", row ~= nil)
	local missing = {}
	for key in pairs(NS.CAPTURE_STAGE_STRINGS.fr) do if not NS.CAPTURE_STAGE_STRINGS.en[key] then missing[#missing + 1] = key end end
	Check("[CAPFX] textes fr et en", #missing == 0, table.concat(missing, ", "))
	NS:DB().companionCaptureAnim = false
end

CP.Done()
