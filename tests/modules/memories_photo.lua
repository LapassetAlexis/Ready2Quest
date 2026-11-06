-- Souvenirs : la photo recréée (Memories.lua). Un addon ne peut pas lire les
-- captures d'écran du jeu : chaque souvenir a un polaroïd, ciel et sol tirés
-- du moment et du lieu, le compagnon en 3D tel qu'il était ce jour-là (look
-- retenu au souvenir), la créature du moment à côté (capture, rare,
-- brillante). Une page de cartes réutilisées : jamais un modèle par souvenir.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock
local ROOT = rawget(_G, "ADDON_ROOT") or "."
local Snap = assert(loadfile(ROOT .. "/tests/snapshot.lua"))()

local MP = { saved = {} }
local GLOBALS = { "Screenshot", "UnitGUID", "UnitIsDead", "UnitClassification", "UnitName", "UnitExists" }
for _, name in ipairs(GLOBALS) do MP.saved[name] = rawget(_G, name) end

function MP.Reset()
	ResetWorld()
	for _, field in ipairs({ "companionFrame", "companionBubble", "companionHover", "journalFrame", "photoPrompt" }) do
		if NS[field] then NS[field]:Hide() end
		NS[field] = nil
	end
	NS.companionRT, NS.companionSession, NS.memoryState, NS.memoryPollAt = nil, nil, nil, nil
	NS:CompanionData().tutoDone = true
	NS:DB().companionPhotos, NS:DB().companionPhotosAsked = false, "no"
	Mock.world.target = nil
	_G.Screenshot = function() end
	_G.UnitGUID = function(unit) return unit == "target" and Mock.world.target and Mock.world.target.guid or nil end
	_G.UnitExists = function(unit) return unit == "player" or (unit == "target" and Mock.world.target ~= nil) end
	_G.UnitName = function(unit) if unit == "target" then return Mock.world.target and Mock.world.target.name end return "Testeur" end
	_G.UnitIsDead = function(unit) return unit == "target" and Mock.world.target and Mock.world.target.dead end
	_G.UnitClassification = function(unit) return unit == "target" and Mock.world.target and Mock.world.target.class or "normal" end
	NS:CompanionUpdateVisibility()
end
function MP.Done()
	for _, name in ipairs(GLOBALS) do _G[name] = MP.saved[name] end
	ResetWorld()
end
function MP.Find(key)
	for _, memory in ipairs(NS:MemoryData().memories) do if memory.key == key then return memory end end
end
-- le mock n'a pas de vrai PlayerModel : on lui donne ses méthodes
function MP.StubModels(pane)
	local calls = { display = 0, creature = 0 }
	for _, card in ipairs(pane.cards) do
		for _, model in ipairs({ card.model, card.creature }) do
			model.SetDisplayInfo = function(m, id) m.shownDisplay, m.shownCreature = id, nil; calls.display = calls.display + 1 end
			model.SetCreature = function(m, id) m.shownCreature, m.shownDisplay = id, nil; calls.creature = calls.creature + 1 end
			model.SetCamDistanceScale = function(m, v) m.cam = v end
			model.SetFacing = function(m, v) m.facing = v end
			model.SetAnimation = function(m, v) m.anim = v end
			model.SetPortraitZoom = function(m, v) m.portrait = v end
			model.ClearModel = function(m) m.shownDisplay, m.shownCreature = nil, nil end
			model.lookKey = nil
		end
	end
	return calls
end
local function CountModels()
	local n = 0
	for _, region in ipairs(Mock.frames) do if region.kind == "PlayerModel" then n = n + 1 end end
	return n
end

-- 1. Données : l'allure du compagnon et la créature du moment ----------------
do
	Say("-- souvenirs : photo recréée, données")
	MP.Reset()
	local app = NS:CompanionCurrentAppearance()
	NS:CompanionOnLevel(10)
	local memory = MP.Find("level:10")
	Check("[MPH] souvenir : l'allure du compagnon retenue (mascotte : display)", memory and type(memory.look) == "table"
		and memory.look.display == tonumber(app.display) and memory.npc == nil,
		memory and memory.look and tostring(memory.look.display))

	local saved = NS.CompanionCurrentAppearance
	NS.CompanionCurrentAppearance = function() return { id = "cap:4321", npc = 4321, captured = true } end
	NS:MemoryRecord("dungeon", "dungeon:Mortemines", { "Mortemines" })
	NS.CompanionCurrentAppearance = saved
	local dungeon = MP.Find("dungeon:Mortemines")
	Check("[MPH] compagnon capturé : son npc retenu", dungeon and dungeon.look and dungeon.look.npc == 4321
		and dungeon.look.display == nil)

	NS:MemoryRecord("capture", "capture:42", { "Loup" }, { npc = 42 })
	Check("[MPH] capture : la créature du moment retenue", MP.Find("capture:42").npc == 42
		and NS:MemoryCreature(MP.Find("capture:42")) == 42)
	NS:MemoryRecord("level", "level:x", { 99 }, { npc = 7 })
	Check("[MPH] niveau : pas de créature sur la photo", NS:MemoryCreature(MP.Find("level:x")) == nil)

	-- rare vaincu : son npc lu dans le GUID de la cible
	Mock.world.target = { name = "Mor'Ladim", class = "rareelite", dead = true, level = 35,
		guid = "Creature-0-1234-0-5678-522-0000ABCDEF" }
	NS.companionRT.lastKill = nil
	NS:CompanionOnKill()
	Mock.world.target = nil
	Check("[MPH] rare : son npc (GUID de la cible)", MP.Find("rare:Mor'Ladim") and MP.Find("rare:Mor'Ladim").npc == 522,
		MP.Find("rare:Mor'Ladim") and tostring(MP.Find("rare:Mor'Ladim").npc))

	-- brillante abattue (Shiny.lua) : son npc passé au souvenir
	if NS.ShinyKill then
		local ok, err = pcall(NS.ShinyKill, NS, "Creature-0-1-2-3-3500-00000001",
			{ npcID = 3500, name = "Hyène dorée", zoneID = 10, zoneName = "Les Tarides" })
		local shiny
		for _, m in ipairs(NS:MemoryData().memories) do if m.kind == "shiny" then shiny = m end end
		Check("[MPH] brillante : son npc retenu", ok and shiny and shiny.npc == 3500, tostring(err))
	end
	-- capture (Capture.lua) : l'appel passe target.npcID
	local handle = io.open(ROOT .. "/QuestCompanion/Capture.lua", "r")
	local source = handle and handle:read("*a") or ""
	if handle then handle:close() end
	Check("[MPH] Capture.lua : le souvenir de capture reçoit le npc", source:find(
		'MemoryRecord("capture", "capture:" .. tostring(target.npcID), { target.name }, { npc = target.npcID })', 1, true) ~= nil)

	-- souvenir d'avant (sans look) : l'allure d'aujourd'hui
	local old = { kind = "level", args = { 20 }, at = 1, zone = "Durotar" }
	local look = NS:MemoryLook(old)
	Check("[MPH] ancien souvenir sans look : l'allure actuelle", look and look.display == tonumber(app.display))
	Check("[MPH] look retenu prioritaire", NS:MemoryLook({ look = { npc = 99 } }).npc == 99
		and NS:MemoryLook({ look = { npc = 99 } }).display == nil)
	MP.Done()
end

-- 2. Décor : du moment et du lieu, toujours le même --------------------------
do
	Say("-- souvenirs : photo recréée, décor")
	local a = NS:MemoryScene({ kind = "dungeon", zone = "Mortemines" })
	local b = NS:MemoryScene({ kind = "dungeon", zone = "Mortemines" })
	local c = NS:MemoryScene({ kind = "level", zone = "Mortemines" })
	Check("[MPH] décor : le même à chaque fois", a.id == b.id and a.sky[1][1] == b.sky[1][1] and a.ground[2][3] == b.ground[2][3])
	Check("[MPH] décor : selon le moment (donjon ≠ niveau)", a.id == "cave" and c.id == "forest")
	local shades = {}
	for _, zone in ipairs({ "Durotar", "Les Tarides", "Orgrimmar", "Mulgore", "Hurlevent" }) do
		shades[NS:MemoryScene({ kind = "level", zone = zone }).shade] = true
	end
	local distinct = 0
	for _ in pairs(shades) do distinct = distinct + 1 end
	Check("[MPH] décor : la lumière change avec le lieu", distinct >= 2, distinct)
	local valid = true
	for kind in pairs({ level = 1, stage = 1, rare = 1, capital = 1, shiny = 1, death = 1, flight = 1, anniv = 1, x = 1 }) do
		local s = NS:MemoryScene({ kind = kind, zone = "Durotar" })
		for _, color in ipairs({ s.sky[1], s.sky[2], s.ground[1], s.ground[2] }) do
			for i = 1, 3 do if not (color[i] >= 0 and color[i] <= 1) then valid = false end end
		end
	end
	Check("[MPH] décor : couleurs valides pour chaque moment (et un inconnu)", valid)
	Check("[MPH] papier clair (≈ #f4efe4)", NS.MEMORY_PAPER[1] > 0.93 and NS.MEMORY_PAPER[2] > 0.9 and NS.MEMORY_PAPER[3] > 0.85)
end

-- 2 bis. Pose : un vrai cadrage par souvenir (1.5.2) -----------------------------
do
	local anims = NS.MEMORY_ANIMS
	local level = { kind = "level", at = 1000, zone = "Durotar" }
	local p1, p2 = NS:MemoryPose(level, false, 4), NS:MemoryPose(level, false, 4)
	Check("[MPH] pose : la même à chaque affichage", p1.facing == p2.facing and p1.anim == p2.anim
		and p1.zoom == p2.zoom and p1.shot == p2.shot)
	Check("[MPH] pose : niveau = un geste de fête", ({ cheer = true, roar = true, jump = true, dance = true })[p1.gesture]
		and p1.anim == anims[p1.gesture], p1.gesture)
	Check("[MPH] pose : mort = blessé ou assis, en gros plan", ({ wound = true, sit = true })[NS:MemoryPose({ kind = "death", at = 7, zone = "x" }).gesture]
		and ({ close = true, medium = true })[NS:MemoryPose({ kind = "death", at = 7, zone = "x" }, false, 3).shot])
	Check("[MPH] pose : un vol se photographie en l'air ou de loin",
		({ high = true, farL = true, farR = true })[NS:MemoryPose({ kind = "flight", at = 9 }, false, 2).shot])
	-- huit souvenirs de suite : huit plans différents, deux voisins jamais pareils
	local shots, same = {}, false
	local last
	for position = 1, 8 do
		local pose = NS:MemoryPose({ kind = "level", at = position * 911, zone = "Z" }, false, position)
		shots[pose.shot] = true
		if pose.shot == last then same = true end
		last = pose.shot
	end
	local n = 0
	for _ in pairs(shots) do n = n + 1 end
	Check("[MPH] pose : 8 souvenirs, 8 plans (gros plan, au loin, de dos…)", n == 8 and not same and #NS.MEMORY_SHOTS == 8, n)
	local close, far = nil, nil
	for _, shot in ipairs(NS.MEMORY_SHOTS) do
		if shot.id == "close" then close = shot end
		if shot.id == "farL" then far = shot end
	end
	Check("[MPH] plans : gros plan sur la tête, petit dans le paysage", close.portrait > 0.5 and far.w < 0.5 and far.x < 0)
	local duo = NS:MemoryPose({ kind = "capture", at = 1, zone = "z" }, true, 5)
	Check("[MPH] pose en duo : en pied, tourné vers la créature (à droite)", duo.shot == "duo" and duo.facing > 0 and duo.portrait == 0)
	Check("[MPH] pose : souvenir vide sans erreur", pcall(NS.MemoryPose, NS, nil))
	-- décor peint : une image par scène, recadrée selon le souvenir
	local scene = NS:MemoryScene({ kind = "dungeon", zone = "Mortemines", at = 5 })
	-- décor selon la zone (1.5.4) : retenue par son uiMapID, sinon par son nom
	Check("[MPH] décor par zone : Durotar = canyon, Elwynn = forêt, Tirisfal = terres maudites",
		NS:MemoryBiome({ kind = "level", map = 1411 }) == "canyon" and NS:MemoryBiome({ kind = "level", map = 1429 }) == "forest"
		and NS:MemoryBiome({ kind = "level", map = 1420 }) == "blight")
	Check("[MPH] décor : donjon = grotte, vol = ciel, quelle que soit la zone",
		NS:MemoryBiome({ kind = "dungeon", map = 1411 }) == "cave" and NS:MemoryBiome({ kind = "flight", map = 1411 }) == "sky")
	-- images officielles du jeu (1.5.4) : donjons, lieux de Forever, vol
	local dm = NS:MemoryArt({ kind = "dungeon", instance = 36 })
	Check("[MPH] image officielle : Mortemines = son écran de chargement", dm and dm.file == 131833
		and dm.box == NS.MEMORY_ART_BOX.classic)
	Check("[MPH] image officielle : île de Zéphras, même pour un niveau", (NS:MemoryArt({ kind = "level", instance = 2991 }) or {}).file == 7950679)
	Check("[MPH] image officielle : premier vol = le continent vu du ciel", (NS:MemoryArt({ kind = "flight", instance = 1 }) or {}).file == 7963779
		and NS:MemoryArt({ kind = "level", instance = 1 }) == nil)
	Check("[MPH] image officielle : ancien souvenir de donjon retrouvé par son nom",
		(NS:MemoryArt({ kind = "dungeon", zone = "Wailing Caverns" }) or {}).file == 131882)
	Check("[MPH] image officielle : zone extérieure = pas d'image (paysage peint)", NS:MemoryArt({ kind = "level", map = 1411 }) == nil)
	-- recadrage : jamais hors de la partie peinte, aux proportions de la photo
	local u0, u1, v0, v1 = NS.MemoryCrop(NS.MEMORY_ART_BOX.wide, 1.5, 0)
	local ratio = ((u1 - u0) * 2992) / ((v1 - v0) * 1684)
	Check("[MPH] recadrage 16:9 : bandes retirées, proportions de la photo", math.abs(ratio - 1.5) < 0.01
		and v0 == 0.15 and v1 == 0.85 and u0 == 0)
	u0, u1, v0, v1 = NS.MemoryCrop(NS.MEMORY_ART_BOX.classic, 1.5, 1)
	Check("[MPH] recadrage classique : logo et cadre retirés", v0 == 0.24 and v1 == 0.77 and u1 <= 1 and u0 >= 0
		and math.abs(((u1 - u0) * 2048) / ((v1 - v0) * 2048) - 1.5) < 0.01)
	Check("[MPH] décor : zone inconnue = forêt", NS:MemoryBiome({ kind = "level", map = 99999 }) == "forest")
	local biomes = {}
	for _, biome in pairs(NS.MEMORY_ZONE_BIOME) do biomes[biome] = true end
	local nb = 0
	for _ in pairs(biomes) do nb = nb + 1 end
	Check("[MPH] décor : onze paysages pour les zones (et la ville)", nb == 11, nb)
	Check("[MPH] décor peint : la texture de la scène", scene.texture == NS.MEMORY_SCENE_TEXTURE .. "cave"
		and scene.pan >= 0 and scene.pan <= 1)
	local pans = {}
	for i = 1, 10 do pans[NS:MemoryScene({ kind = "level", zone = "Zone " .. i, at = i }).pan] = true end
	local np = 0
	for _ in pairs(pans) do np = np + 1 end
	Check("[MPH] décor peint : un cadrage différent selon le souvenir", np >= 5, np)
end

-- 3. Album : polaroïds, modèles, pool fixe, pagination, mise en page ---------
do
	Say("-- souvenirs : photo recréée, album")
	MP.Reset()
	NS:OpenMemories()
	local frame = NS.journalFrame
	local pane = frame.mem
	local page = NS.MEMORY_ALBUM_PAGE
	Check("[MPH] une page de polaroïds, pas plus", pane and #pane.cards == page and page == 6, pane and #pane.cards)
	Check("[MPH] la note : captures illisibles, photo recréée", pane.hint.text == NS.MEMORY_STRINGS.fr.MEM_PHOTO_NOTE
		and NS.MEMORY_STRINGS.fr.MEM_PHOTO_NOTE == "Les captures d'écran du jeu restent dans le dossier Screenshots : un addon n'a pas le droit de les lire. Chaque souvenir a donc sa photo recréée par ton compagnon."
		and NS.MEMORY_STRINGS.en.MEM_PHOTO_NOTE:find("Screenshots", 1, true))

	-- sans PlayerModel utilisable (mock) : le logo à la place, pas d'erreur
	NS:CompanionOnLevel(10)
	NS:RefreshJournal()
	local card = pane.cards[1]
	Check("[MPH] sans modèle 3D : le logo dans la photo", card:IsShown() and card.fallback:IsShown()
		and not card.model:IsShown() and not card.creature:IsShown())

	local calls = MP.StubModels(pane)
	local app = NS:CompanionCurrentAppearance()
	NS:MemoryRecord("capture", "capture:42", { "Loup" }, { npc = 42 })
	NS:MemoryRecord("rare", "rare:old", { "Vieux rare" })       -- sans npc : seul sur la photo
	NS:RefreshJournal()
	Check("[MPH] le compagnon en 3D (SetDisplayInfo), seul, au milieu", card.model.shownDisplay == tonumber(app.display)
		and card.model:IsShown() and not card.creature:IsShown() and not card.fallback:IsShown()
		and math.abs(card.model.cam - (card.pose.portrait > 0 and 1 or 1.6) * card.pose.zoom) < 1e-9, tostring(card.model.shownDisplay))
	local cap = pane.cards[2]
	Check("[MPH] capture : la créature (SetCreature) à côté du compagnon", cap.creature:IsShown()
		and cap.creature.shownCreature == 42 and cap.model:IsShown() and cap.model.shownDisplay == tonumber(app.display)
		and cap.model:GetWidth() < cap.photoW and cap.creature.facing < 0 and cap.model.facing > 0)
	Check("[MPH] compagnon posé : geste, angle et plan du souvenir", card.model.anim == card.pose.anim
		and card.model.facing == card.pose.facing and card.model:GetWidth() == math.floor(card.photoW * card.pose.w))
	Check("[MPH] décor peint posé et recadré", card.backdrop:IsShown() and card.backdrop.texture == NS.MEMORY_SCENE_TEXTURE .. card.scene)
	Check("[MPH] deux photos voisines : deux plans différents", pane.cards[1].pose.shot ~= pane.cards[3].pose.shot)
	Check("[MPH] rare sans npc connu : le compagnon seul", pane.cards[3].model:IsShown() and not pane.cards[3].creature:IsShown())
	local before = calls.display + calls.creature
	NS:RefreshJournal()
	Check("[MPH] même page : les modèles ne sont pas reposés", calls.display + calls.creature == before,
		(calls.display + calls.creature) .. " / " .. before)

	-- compagnon capturé ce jour-là : SetCreature, de plus loin
	local data = NS:MemoryData()
	data.memories[1].look = { npc = 777 }
	pane.cards[1].model.lookKey = nil
	NS:RefreshJournal()
	Check("[MPH] allure du jour retenue (créature capturée) : SetCreature", card.model.shownCreature == 777
		and math.abs(card.model.cam - (card.pose.portrait > 0 and 1 or (NS.CAPTURE_CAM_DISTANCE or 2.4)) * card.pose.zoom) < 1e-9)

	-- beaucoup de souvenirs : toujours les mêmes cartes et les mêmes modèles
	local models = CountModels()
	for i = 1, 30 do NS:MemoryRecord("chest", "chest:" .. i, { "Zone " .. i }) end
	NS:RefreshJournal()
	NS:ScrollJournal(-1)
	NS:ScrollJournal(-1)
	Check("[MPH] 33 souvenirs : aucun modèle de plus", CountModels() == models and #pane.cards == page, CountModels() .. " / " .. models)
	Check("[MPH] molette : une rangée par cran", frame.offset == 2 * NS.MEMORY_ALBUM_COLS, frame.offset)
	pane.down:Click()
	Check("[MPH] chevron : une page entière", frame.offset == 2 * NS.MEMORY_ALBUM_COLS + page
		and pane.position.text == (frame.offset + 1) .. "-" .. (frame.offset + page) .. " / " .. #data.memories, pane.position.text)
	for _ = 1, 20 do pane.down:Click() end
	local total = #data.memories
	local shown = 0
	for _, c in ipairs(pane.cards) do if c:IsShown() then shown = shown + 1 end end
	Check("[MPH] fin de l'album : la dernière page, rangée entière", frame.offset % NS.MEMORY_ALBUM_COLS == 0
		and frame.offset + shown == total and not pane.down:IsShown() and pane.up:IsShown(), frame.offset .. " + " .. shown)
	local last = frame.offset
	pane.up:Click()
	Check("[MPH] retour d'une page", frame.offset == math.max(0, last - page), frame.offset .. " / " .. last)

	-- mise en page : dans la zone de la page, sous la note, au-dessus de la pagination
	NS:ScrollJournal(100)
	data.memories[2].photo = "WoWScrnShot_110626_101010.jpg"
	NS:RefreshJournal()
	local content = pane.mockParent
	local layout = NS.JOURNAL_LAYOUT or {}
	local ctx = { memo = {} }
	local box = Snap.Rect(content, ctx)
	local note = Snap.Rect(pane.hint, ctx)
	local pager = Snap.Rect(pane.pager, ctx)
	local pad, inner = layout.pad or 24, layout.inner or 710
	local bad = {}
	local rects = {}
	for index, c in ipairs(pane.cards) do
		local r = Snap.Rect(c, ctx)
		rects[index] = r
		if r.left < box.left + pad - 0.5 or r.left + r.width > box.left + pad + inner + 0.5 then bad[#bad + 1] = index .. " : largeur" end
		if r.top < note.top + note.height then bad[#bad + 1] = index .. " : sur la note" end
		if r.top + r.height > pager.top - 4 then bad[#bad + 1] = index .. " : sur la pagination" end
		local overlaps, outside = Snap.Layout(c, Snap.Texts(c), r)
		for _, o in ipairs(overlaps) do bad[#bad + 1] = index .. " : " .. o end
		for _, o in ipairs(outside) do bad[#bad + 1] = index .. " hors carte : " .. o end
		local photo = Snap.Rect(c.photo, ctx)
		local caption = Snap.Rect(c.caption, ctx)
		if caption.top < photo.top + photo.height then bad[#bad + 1] = index .. " : légende sur la photo" end
	end
	for i = 1, #rects do
		for j = i + 1, #rects do
			local a, b = rects[i], rects[j]
			local w = math.min(a.left + a.width, b.left + b.width) - math.max(a.left, b.left)
			local h = math.min(a.top + a.height, b.top + b.height) - math.max(a.top, b.top)
			if w > 0 and h > 0 then bad[#bad + 1] = i .. " / " .. j end
		end
	end
	Check("[MPH] polaroïds dans la page, sans chevauchement (note, pagination, textes)", #bad == 0, table.concat(bad, " | "))
	local header = Snap.Rect(pane.header, ctx)
	Check("[MPH] en-tête au-dessus de la note", header.top + header.height <= note.top + 0.5)
	local photoCard = pane.cards[2]
	Check("[MPH] polaroïd : papier clair, photo au-dessus de la légende, losange si capture d'écran",
		photoCard.paper.vertex[1] > 0.9 and photoCard.stamp:IsShown() and not pane.cards[1].stamp:IsShown()
		and photoCard.caption.text ~= "" and photoCard.meta.text:find("·", 1, true))
	-- survol : le souvenir en entier, avec le nom de la capture
	local ok = pcall(photoCard.scripts.OnEnter, photoCard)
	Check("[MPH] survol : infobulle sans erreur", ok)
	if photoCard.scripts.OnLeave then photoCard.scripts.OnLeave(photoCard) end
	frame:Hide()
	MP.Done()
end
