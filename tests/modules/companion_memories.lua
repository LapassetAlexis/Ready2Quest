-- Compagnon : souvenirs et photos (Memories.lua). Accord demandé une fois
-- (Oui / Non / Plus tard), jamais en combat, quelques photos par jour,
-- « Clic ! » avant la capture ; souvenirs des grands moments ; anniversaires ;
-- rappel une fois par heure de jeu ; album dans le carnet ; page de réglages.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local MM = { saved = {} }
local GLOBALS = { "Screenshot", "StaticPopup_Show", "StaticPopupDialogs", "IsMounted", "UnitOnTaxi", "IsInGroup",
	"IsInRaid", "UnitExists", "GetInstanceInfo", "IsFalling", "UnitCanAttack", "UnitLevel", "UnitName",
	"UnitClassification", "UnitIsDead", "InCombatLockdown", "UnitAffectingCombat", "IsInInstance" }
for _, name in ipairs(GLOBALS) do MM.saved[name] = rawget(_G, name) end

function MM.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "photoPrompt" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.memoryState, NS.memoryPollAt, NS.companionFx = nil, nil, nil, nil, nil
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS:CompanionData().tutoDone = true
	local w = Mock.world
	w.level, w.mapID = 20, 20
	w.shots, w.popups, w.party, w.combat = 0, {}, {}, false
	w.taxi, w.mounted, w.instance, w.instanceName, w.falling = false, false, false, nil, false
	w.target = nil
	_G.Screenshot = function() w.shots = w.shots + 1 end
	_G.StaticPopupDialogs = {}
	_G.StaticPopup_Show = function(which, text) w.popups[#w.popups + 1] = { which = which, text = text } end
	_G.IsMounted = function() return w.mounted end
	_G.UnitOnTaxi = function() return w.taxi end
	_G.IsInRaid = function() return false end
	_G.IsInGroup = function() return #w.party > 0 end
	_G.UnitExists = function(unit)
		if unit == "target" then return w.target ~= nil end
		local index = tonumber(tostring(unit):match("^party(%d)$") or "")
		return unit == "player" or (index ~= nil and w.party[index] ~= nil)
	end
	_G.UnitName = function(unit)
		if unit == "target" then return w.target and w.target.name end
		local index = tonumber(tostring(unit):match("^party(%d)$") or "")
		return index and w.party[index] or "Testeur"
	end
	_G.UnitLevel = function(unit) if unit == "target" then return w.target and w.target.level end return w.level end
	_G.UnitClassification = function(unit) return unit == "target" and w.target and w.target.class or "normal" end
	_G.UnitIsDead = function(unit) return unit == "target" and w.target and w.target.dead end
	_G.UnitCanAttack = function() return w.target ~= nil end
	_G.IsFalling = function() return w.falling end
	_G.GetInstanceInfo = function() return w.instanceName end
	_G.IsInInstance = function() return w.instance end
	_G.InCombatLockdown = function() return w.combat end
	_G.UnitAffectingCombat = function() return w.combat end
	NS:CompanionUpdateVisibility()
end
function MM.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = MM.saved[name] end
	ResetWorld()
end
function MM.List() return NS:MemoryData().memories end
-- la question des photos : combien de fois posée, et y répondre
function MM.Asked() return NS.photoPrompt and NS.photoPrompt.asks or 0 end
function MM.Answer(button) NS.photoPrompt[button]:Click() end
function MM.Find(key)
	for _, memory in ipairs(MM.List()) do if memory.key == key then return memory end end
end
function MM.Yes() NS:DB().companionPhotos, NS:DB().companionPhotosAsked = true, "yes" end
-- la photo en attente part : « Clic ! », puis la capture
function MM.Shoot()
	Mock:Advance(NS.MEMORY_PHOTO_DELAY)
	Mock:Advance(NS.MEMORY_PHOTO_CLICK)
end

-- 1. Souvenirs ---------------------------------------------------------------------------
do
	Say("-- souvenirs : les moments")
	MM.Reset()
	MM.Yes()
	NS:DB().companionPhotos = false
	NS:CompanionOnLevel(10)
	local memory = MM.Find("level:10")
	Check("[MEM] niveau 10 : souvenir avec date et lieu", memory and memory.kind == "level" and memory.at == math.floor(Mock.now)
		and memory.zone == "Plaine sauvage" and NS:MemoryText(memory) == "Niveau 10 atteint.", memory and NS:MemoryText(memory))
	NS:CompanionOnLevel(10)
	NS:CompanionOnLevel(11)
	Check("[MEM] pas de doublon, pas de souvenir au niveau 11", #MM.List() == 1, #MM.List())

	Mock.world.mapID = 1453
	Mock.world.maps[1453] = { mapID = 1453, name = "Hurlevent", parentMapID = 0 }
	NS:CompanionOnZone(true)
	Check("[MEM] première capitale", MM.Find("capital:1453") and NS:MemoryText(MM.Find("capital:1453")):find("Hurlevent", 1, true))
	Mock.world.mapID = 20

	Mock.world.instance, Mock.world.instanceName = true, "Gouffre de Ragefeu"
	NS:CompanionOnZone(true)
	Check("[MEM] premier donjon (son nom)", MM.Find("dungeon:Gouffre de Ragefeu") ~= nil
		and MM.Find("dungeon:Gouffre de Ragefeu").zone == "Gouffre de Ragefeu")
	Check("[MEM] seul : pas de « donjon en groupe »", MM.Find("groupDungeon") == nil)
	Mock.world.party = { "Thrall" }
	Mock.world.instanceName = "Mortemines"
	NS:CompanionOnZone(true)
	Check("[MEM] en groupe : premier donjon en groupe", MM.Find("groupDungeon") and MM.Find("dungeon:Mortemines"))
	Mock.world.instance, Mock.world.party = false, {}

	Mock.world.target = { name = "Mor'Ladim", class = "rareelite", dead = true, level = 35 }
	NS.companionRT.lastKill = nil
	NS:CompanionOnKill()
	Check("[MEM] rare vaincu", MM.Find("rare:Mor'Ladim") ~= nil)
	Mock.world.target = { name = "Ogre", class = "elite", dead = true, level = 30 }
	NS.companionRT.lastKill = nil
	NS:CompanionOnKill()
	Check("[MEM] élite ordinaire : pas un souvenir", MM.Find("rare:Ogre") == nil)
	Mock.world.target = nil

	local savedCompletion, savedTier = NS.ZoneCompletion, NS.ZoneTier
	NS.ZoneCompletion = function() return { parts = { 1, 2 }, percent = 100 } end
	NS.ZoneTier = function() return 1 end
	Mock.world.maps[77] = { mapID = 77, name = "Bois de la Pénombre", parentMapID = 0 }
	NS:ChestCheck(77)
	Check("[MEM] zone terminée : coffre", MM.Find("chest:Bois de la Pénombre") ~= nil)
	NS.ZoneCompletion, NS.ZoneTier = savedCompletion, savedTier
	NS:ChestData()[77] = nil

	NS:CompanionOnDead()
	Check("[MEM] première mort", MM.Find("death") ~= nil)
	Check("[MEM] mort sans cible ni chute : pas « la plus bête »", MM.Find("deathSilly") == nil)
	Mock.world.target = { name = "Sanglier", class = "normal", level = 19 }
	NS:CompanionOnDead()
	Check("[MEM] tué par un ennemi de ton niveau : pas bête", MM.Find("deathSilly") == nil)
	Mock.world.target = { name = "Lapin", class = "normal", level = 12 }
	NS:CompanionOnDead()
	local silly = MM.Find("deathSilly")
	Check("[MEM] la mort la plus bête : un lapin niveau 12", silly and NS:MemoryText(silly):find("Lapin", 1, true))
	Mock.world.target = { name = "Loup", class = "normal", level = 15 }
	NS:CompanionOnDead()
	Check("[MEM] moins bête : on garde le lapin", NS:MemoryText(MM.Find("deathSilly")):find("Lapin", 1, true))
	Mock.world.target = nil
	Mock.world.falling = true
	NS:CompanionOnDead()
	local count = 0
	for _, m in ipairs(MM.List()) do if m.key == "deathSilly" then count = count + 1 end end
	Check("[MEM] une chute : plus bête encore, elle remplace", MM.Find("deathSilly").kind == "deathFall" and count == 1)
	Mock.world.falling = false

	-- coup d'œil régulier : vol, monture, groupe complet
	Mock:Advance(2.1)
	Mock.world.taxi = true
	Mock:Advance(2.1)
	Check("[MEM] premier vol", MM.Find("flight") ~= nil)
	Mock.world.mounted = true
	Mock:Advance(2.1)
	Check("[MEM] première monture", MM.Find("mount") ~= nil)
	Mock.world.party = { "Thrall", "Jaina", "Anduin", "Rexxar" }
	Mock:Advance(2.1)
	Check("[MEM] premier groupe complet, avec les noms", MM.Find("groupFull")
		and NS:MemoryText(MM.Find("groupFull")):find("Thrall, Jaina, Anduin, Rexxar", 1, true))

	NS:DB().companionEnabled = false
	NS:CompanionOnLevel(20)
	Check("[MEM] module coupé : rien", MM.Find("level:20") == nil)
	NS:DB().companionEnabled = nil
	MM.Done()
end

-- 2. Photos : accord ---------------------------------------------------------------------
do
	Say("-- souvenirs : l'accord pour les photos")
	MM.Reset()
	Check("[MEM] photos coupées par défaut", NS:DB().companionPhotos == false)
	NS:CompanionOnZone(true)                   -- pas un moment à photo : rien demandé
	NS:CompanionOnLevel(10)
	local prompt = NS.photoPrompt
	Check("[MEM] premier grand moment : il demande (fenêtre de module)", MM.Asked() == 1 and prompt:IsShown()
		and prompt.chrome == "dialog" and prompt.text.text:find("photo", 1, true) and prompt.later:GetText() == "Plus tard"
		and prompt.yes.style == "primary" and #Mock.world.popups == 0)
	NS:CompanionOnLevel(20)
	Check("[MEM] pas deux fois la question", MM.Asked() == 1)
	MM.Shoot()
	Check("[MEM] sans réponse : pas de photo", Mock.world.shots == 0)
	MM.Answer("yes")
	Check("[MEM] Oui : photos activées, la question se ferme", NS:DB().companionPhotos == true
		and NS:DB().companionPhotosAsked == "yes" and not prompt:IsShown())
	Mock:Advance(NS.MEMORY_PHOTO_DELAY)
	Check("[MEM] « Clic ! » dans sa bulle avant la capture", NS.companionBubbleKey and NS.companionBubbleKey:find("PHOTO", 1, true)
		and Mock.world.shots == 0, NS.companionBubbleKey)
	Mock:Advance(NS.MEMORY_PHOTO_CLICK)
	Check("[MEM] … puis la photo du moment demandé", Mock.world.shots == 1)
	Mock:Fire("SCREENSHOT_SUCCEEDED")
	local memory = MM.Find("level:10")
	Check("[MEM] nom du fichier retenu", memory.photo and memory.photo:find("^WoWScrnShot_%d+_%d+%.jpg$"), memory.photo)
	Check("[MEM] éclair à la photo", NS.companionFrame.flash and NS.companionFrame.flash:IsShown())

	MM.Reset()
	NS:CompanionOnLevel(10)
	MM.Answer("no")
	Check("[MEM] Non : photos coupées, plus demandé", NS:DB().companionPhotos == false and NS:DB().companionPhotosAsked == "no")
	MM.Shoot()
	NS:CompanionOnLevel(20)
	MM.Shoot()
	Check("[MEM] Non : jamais de photo ni de question", Mock.world.shots == 0 and MM.Asked() == 1)
	Check("[MEM] Non : le souvenir reste écrit", MM.Find("level:20") ~= nil)

	MM.Reset()
	NS:CompanionOnLevel(10)
	MM.Answer("later")
	Check("[MEM] Plus tard : rien de décidé", NS:DB().companionPhotos == false and NS:DB().companionPhotosAsked == "later")
	Mock:Advance(60)
	NS:CompanionOnLevel(20)
	Check("[MEM] Plus tard : pas redemandé dans l'heure", MM.Asked() == 1)
	Mock:Advance(NS.MEMORY_ASK_AGAIN)
	NS:CompanionOnLevel(30)
	Check("[MEM] Plus tard : redemandé au grand moment suivant", MM.Asked() == 2)
	Mock:Advance(NS.MEMORY_PHOTO_WAIT + 1)
	MM.Answer("yes")
	MM.Shoot()
	Check("[MEM] Oui trop tard : pas de photo d'un moment passé", Mock.world.shots == 0 and NS:DB().companionPhotos == true)

	-- [×] : vaut « Plus tard », la question reviendra
	MM.Reset()
	NS:CompanionOnLevel(10)
	NS.photoPrompt.close:Click()
	Check("[MEM] [×] : « Plus tard », rien de décidé", NS:DB().companionPhotosAsked == "later"
		and NS:DB().companionPhotos == false and not NS.photoPrompt:IsShown())
	-- client sans les briques du thème : la fenêtre du jeu, mêmes réponses
	MM.Reset()
	local dialog = NS.Theme.CreateDialog
	NS.Theme.CreateDialog = nil
	NS:CompanionOnLevel(10)
	NS.Theme.CreateDialog = dialog
	Check("[MEM] repli : la fenêtre du jeu", NS.photoPrompt == nil and #Mock.world.popups == 1
		and Mock.world.popups[1].which == "QUESTCOMPANION_PHOTO" and StaticPopupDialogs.QUESTCOMPANION_PHOTO.button3 == "Plus tard")
	StaticPopupDialogs.QUESTCOMPANION_PHOTO.OnAccept()
	Check("[MEM] repli : Oui", NS:DB().companionPhotos == true and NS:DB().companionPhotosAsked == "yes")
	MM.Done()
end

-- 3. Photos : combat, quota, échec --------------------------------------------------------
do
	Say("-- souvenirs : combat et quota")
	MM.Reset()
	MM.Yes()
	Mock.world.combat = true
	NS:CompanionOnLevel(10)
	Mock:Advance(5)
	Mock:Advance(5)
	Check("[MEM] en combat : pas de photo", Mock.world.shots == 0 and NS.companionBubbleKey == nil or
		(Mock.world.shots == 0 and not tostring(NS.companionBubbleKey):find("PHOTO", 1, true)))
	Mock.world.combat = false
	Mock:Advance(0.5)
	Check("[MEM] fin du combat : pas tout de suite (ni « Clic ! »)", Mock.world.shots == 0
		and not tostring(NS.companionBubbleKey):find("PHOTO", 1, true), NS.companionBubbleKey)
	MM.Shoot()
	Check("[MEM] 1 s après le combat : la photo", Mock.world.shots == 1)
	Mock:Fire("SCREENSHOT_SUCCEEDED")

	Mock.world.combat = true
	NS:CompanionOnLevel(20)
	Mock:Advance(NS.MEMORY_PHOTO_WAIT + 5)
	Mock.world.combat = false
	MM.Shoot()
	Check("[MEM] combat trop long : photo abandonnée", Mock.world.shots == 1 and MM.Find("level:20").photo == nil)

	NS:CompanionOnLevel(30)
	MM.Shoot()
	Mock:Fire("SCREENSHOT_FAILED")
	Check("[MEM] capture ratée : pas de nom, le quota est rendu", MM.Find("level:30").photo == nil
		and NS:MemoryPhotosToday().count == 1, NS:MemoryPhotosToday().count)
	for level = 40, 60, 10 do
		NS:CompanionOnLevel(level)
		MM.Shoot()
		Mock:Fire("SCREENSHOT_SUCCEEDED")
	end
	Check("[MEM] trois photos par jour au plus", Mock.world.shots == 4 and MM.Find("level:50").photo ~= nil
		and MM.Find("level:60").photo == nil and NS:MemoryPhotosToday().count == 3, Mock.world.shots)
	Mock.now = Mock.now + 86400
	Mock.world.mounted = false
	Mock:Advance(2.1)
	Mock.world.mounted = true
	Mock:Advance(2.1)
	MM.Shoot()
	Check("[MEM] le lendemain : de nouveau", Mock.world.shots == 5)
	MM.Done()
end

-- 4. Anniversaires et rappels --------------------------------------------------------------
do
	Say("-- souvenirs : anniversaires et rappels")
	MM.Reset()
	local data = NS:MemoryData()
	data.metAt = math.floor(Mock.now) - 86400 - 10
	NS:MemoryCheckAnniversary()
	Check("[MEM] un jour ensemble : souvenir et bulle", MM.Find("anniv:1d") and NS.companionBubbleKey
		and NS.companionBubbleKey:find("ANNIV", 1, true) and NS.companionBubbleText:find("un jour", 1, true), NS.companionBubbleText)
	Check("[MEM] une seule fois", NS:MemoryCheckAnniversary() == nil)
	data.metAt = math.floor(Mock.now) - 400 * 86400
	NS:MemoryCheckAnniversary()
	Check("[MEM] longue absence : seulement « un an », pas les paliers sautés", MM.Find("anniv:1y") and not MM.Find("anniv:1w")
		and not MM.Find("anniv:6m") and NS:MemoryCheckAnniversary() == nil)
	data.metAt = math.floor(Mock.now) - (2 * 365 + 3) * 86400
	NS:MemoryCheckAnniversary()
	Check("[MEM] chaque année ensuite : deux ans", MM.Find("anniv:2y") and NS:MemoryText(MM.Find("anniv:2y")) == "2 ans ensemble.",
		MM.Find("anniv:2y") and NS:MemoryText(MM.Find("anniv:2y")))

	MM.Reset()
	NS:CompanionOnLevel(10)
	Check("[MEM] pas de rappel avant une heure de jeu", NS:MemoryRecall() == false)
	NS.memoryState.recallAt = Mock.now - NS.MEMORY_RECALL_GAP - 1
	Check("[MEM] souvenir tout frais : pas encore un « tu te souviens »", NS:MemoryRecall() == false)
	NS.memoryState.recallAt = Mock.now
	Mock:Advance(NS.MEMORY_RECALL_GAP + 1)
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	NS.memoryState.recallAt = Mock.now - NS.MEMORY_RECALL_GAP - 1
	Check("[MEM] une heure après : il se souvient", NS:MemoryRecall() == true and NS.companionBubbleText:find("Niveau 10", 1, true),
		NS.companionBubbleText)
	NS.companionLastBubble, NS.companionBubbleUntil, NS.companionBubblePrio, NS.companionBubbleKey = nil, nil, nil, nil
	Check("[MEM] pas deux fois dans l'heure", NS:MemoryRecall() == false)
	NS.memoryState.recallAt = Mock.now - NS.MEMORY_RECALL_GAP - 1
	NS:DB().companionRecall = false
	Check("[MEM] réglage coupé : il garde ses souvenirs pour lui", NS:MemoryRecall() == false)
	NS:DB().companionRecall = true
	NS:DB().companionChatter = 0
	Check("[MEM] sourdine : pas de rappel", NS:MemoryRecall() == false)
	MM.Done()
end

-- 5. Album et réglages --------------------------------------------------------------------
do
	Say("-- souvenirs : album et réglages")
	MM.Reset()
	NS:DB().companionPhotos, NS:DB().companionPhotosAsked = false, "no"
	NS:OpenMemories()
	local frame = NS.journalFrame
	Check("[MEM] album : section « Souvenirs » du carnet", frame and frame.kind == "memories" and frame.mem:IsShown()
		and not frame.evo:IsShown() and not frame.prog:IsShown() and frame.sections.memories.text.text == "Souvenirs")
	Check("[MEM] album vide : il explique", frame.mem.empty.text:find("Pas encore", 1, true))
	for level = 10, 60, 10 do NS:CompanionOnLevel(level) end
	Mock.world.mapID = 1453
	Mock.world.maps[1453] = { mapID = 1453, name = "Hurlevent", parentMapID = 0 }
	NS:CompanionOnZone(true)
	MM.Find("level:10").photo = "WoWScrnShot_110426_101010.jpg"
	NS:RefreshJournal()
	local card = frame.mem.cards[1]
	Check("[MEM] album : ordre chronologique, polaroïd (légende, lieu · date, losange de la capture)", card:IsShown()
		and card.caption.text == "Niveau 10 atteint." and card.meta.text:find("Plaine sauvage", 1, true)
		and card.meta.text:find("%d%d/%d%d/%d%d%d%d$") and card.stamp:IsShown() and not frame.mem.cards[2].stamp:IsShown(),
		card.meta.text)
	Check("[MEM] album : en-tête (souvenirs, photos) et la note sur les captures", frame.mem.header.text == "Souvenirs : " .. #MM.List() .. "  ·  photos : 1"
		and frame.mem.hint.text:find("Screenshots", 1, true) and frame.mem.hint.text:find("recréée", 1, true), frame.mem.header.text)
	for i = 1, 5 do NS:MemoryRecord("rare", "rare:" .. i, { "Rare " .. i }) end
	NS:RefreshJournal()
	local page = NS.MEMORY_ALBUM_PAGE
	Check("[MEM] album : une page de polaroïds, défilement", #frame.mem.cards == page and frame.mem.cards[page]:IsShown()
		and frame.mem.down:IsShown() and not frame.mem.up:IsShown()
		and frame.mem.position.text == "1-" .. page .. " / " .. #MM.List(), frame.mem.position.text)
	NS:ScrollJournal(-10)
	local lastShown
	for _, c in ipairs(frame.mem.cards) do if c:IsShown() then lastShown = c end end
	Check("[MEM] album : fin de liste", lastShown and lastShown.caption.text:find("Rare 5", 1, true) and frame.mem.up:IsShown()
		and not frame.mem.down:IsShown(), lastShown and lastShown.caption.text)
	NS:SelectJournalKind("evolution")
	Check("[MEM] retour à Évolution : album caché", frame.evo:IsShown() and not frame.mem:IsShown())
	frame:Hide()

	NS.optionsFrame = nil
	NS:ToggleOptions()
	NS:SelectOptionsPage("companionMemories")
	local photos, album
	for _, r in ipairs(NS.optionsFrame.rows) do
		if r.def and r.def.key == "companionPhotos" then photos = r end
		if r.def and r.def.key == "companionAlbum" then album = r end
	end
	Check("[MEM] réglages : page Souvenirs, photos coupées, et pourquoi", photos and photos.note
		and photos.note.text:find("Pas de capture", 1, true), photos and photos.note and photos.note.text)
	photos:Click()
	Check("[MEM] réglages : photos activées, la phrase suit", NS:DB().companionPhotos == true
		and NS:DB().companionPhotosAsked == "yes" and photos.note.text:find("3 par jour", 1, true), photos.note.text)
	album:Click()
	Check("[MEM] réglages : « Ouvrir l'album »", NS.journalFrame:IsShown() and NS.journalFrame.kind == "memories")
	NS.journalFrame:Hide()
	NS.optionsFrame:Hide()

	local S = NS.MEMORY_STRINGS
	local missing = {}
	for key in pairs(S.fr) do if not S.en[key] then missing[#missing + 1] = key end end
	for key in pairs(S.en) do if not S.fr[key] then missing[#missing + 1] = key end end
	for _, name in ipairs({ "PHOTO", "RECALL", "ANNIV" }) do
		for _, key in ipairs(NS.COMPANION_POOLS[name] or { "absent:" .. name }) do
			if not NS.COMPANION_LINE_STRINGS.en[key] then missing[#missing + 1] = key end
		end
	end
	Check("[MEM] textes en français et en anglais", #missing == 0, table.concat(missing, ", "))
	MM.Done()
end
