-- Memories.lua -- souvenirs et photos du compagnon (QuestCompanion)
--
-- Le compagnon retient les grands moments de la route dans un album (carnet,
-- partie « Souvenirs ») : date, lieu, ce qui s'est passé. Pour certains, il
-- prend une photo (capture d'écran du jeu, rangée dans le dossier
-- Screenshots ; un addon ne peut pas l'afficher, l'album donne son nom).
--   * photos : seulement avec l'accord du joueur (demandé une fois, au
--     premier grand moment : Oui / Non / Plus tard ; réglable ensuite), jamais
--     en combat (1 s après), PHOTO_PER_DAY par jour au plus, « Clic ! » dans
--     sa bulle juste avant ;
--   * souvenirs : niveaux 10 à 60, évolutions, premier passage dans chaque
--     donjon, chaque capitale (texte), premier de chaque rare vaincu, zone
--     terminée (coffre), première mort et mort « la plus bête » (texte),
--     premier groupe complet, premier donjon en groupe, premier vol, première
--     monture ;
--   * anniversaires de la rencontre (temps réel) : 1 jour, 1 semaine, 1 mois,
--     3 mois, 6 mois, 1 an, puis chaque année (texte, et il le dit) ;
--   * il se souvient à voix haute d'un souvenir, une fois par heure de jeu au plus.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	MEM_SEC                = "Souvenirs",
	MEM_HEADER             = "Souvenirs : %d  ·  photos : %d",
	MEM_HEADER_HINT        = "Les photos sont dans le dossier Screenshots du jeu.",
	MEM_EMPTY              = "Pas encore de souvenir. Monte de niveau, explore un donjon, croise un rare : il retiendra les grands moments.",
	MEM_PHOTO              = "photo : %s",
	MEM_PHOTO_TAKEN        = "Photo prise pour l'album : %s (dossier Screenshots).",
	MEM_ASK_TEXT           = "%s aimerait prendre une photo pour son album de souvenirs (capture d'écran du jeu, quelques-unes par jour au plus, jamais en combat). D'accord ?",
	MEM_ASK_YES            = "Oui",
	MEM_ASK_NO             = "Non",
	MEM_ASK_LATER          = "Plus tard",
	MEM_ASK_DONE_YES       = "Photos souvenirs activées. Tu peux les couper dans les réglages, page Souvenirs.",
	MEM_ASK_DONE_NO        = "Pas de photos : les souvenirs restent écrits dans l'album. Réglable dans les réglages, page Souvenirs.",
	OPT_PAGE_MEMORIES      = "Souvenirs",
	OPT_MEM_PHOTOS         = "Photos souvenirs",
	OPT_MEM_PHOTOS_DESC_ON = "Aux grands moments, une capture d'écran (dossier Screenshots), %d par jour au plus, jamais en combat.",
	OPT_MEM_PHOTOS_DESC_OFF= "Pas de capture d'écran : les souvenirs restent écrits dans l'album du carnet.",
	OPT_MEM_RECALL         = "Il se souvient à voix haute",
	OPT_MEM_ALBUM          = "Ouvrir l'album",
	-- ce que l'album écrit
	MEM_TXT_level          = "Niveau %s atteint.",
	MEM_TXT_stage          = "%s est devenu %s.",
	MEM_TXT_dungeon        = "Premier pas dans %s.",
	MEM_TXT_capital        = "Première visite de %s.",
	MEM_TXT_rare           = "%s vaincu, un rare !",
	MEM_TXT_chest          = "%s terminée à 100 %% : un coffre !",
	MEM_TXT_death          = "Première chute… on s'est relevés.",
	MEM_TXT_deathSilly     = "La mort la plus bête : %s, niveau %s.",
	MEM_TXT_deathFall      = "La mort la plus bête : une chute.",
	MEM_TXT_groupFull      = "Premier groupe complet, avec %s.",
	MEM_TXT_groupDungeon   = "Premier donjon en groupe : %s.",
	MEM_TXT_flight         = "Premier vol, vers l'inconnu.",
	MEM_TXT_mount          = "Première monture !",
	MEM_TXT_anniv          = "%s ensemble.",
	MEM_ANNIV_1d           = "Un jour",
	MEM_ANNIV_1w           = "Une semaine",
	MEM_ANNIV_1m           = "Un mois",
	MEM_ANNIV_3m           = "Trois mois",
	MEM_ANNIV_6m           = "Six mois",
	MEM_ANNIV_1y           = "Un an",
	MEM_ANNIV_ny           = "%d ans",
}
local EN = {
	MEM_SEC                = "Memories",
	MEM_HEADER             = "Memories: %d  ·  pictures: %d",
	MEM_HEADER_HINT        = "Pictures are in the game's Screenshots folder.",
	MEM_EMPTY              = "No memory yet. Level up, explore a dungeon, meet a rare: it will remember the big moments.",
	MEM_PHOTO              = "picture: %s",
	MEM_PHOTO_TAKEN        = "Picture taken for the album: %s (Screenshots folder).",
	MEM_ASK_TEXT           = "%s would like to take a picture for its memory album (a game screenshot, a few a day at most, never in combat). Is that OK?",
	MEM_ASK_YES            = "Yes",
	MEM_ASK_NO             = "No",
	MEM_ASK_LATER          = "Later",
	MEM_ASK_DONE_YES       = "Memory pictures on. You can turn them off in the settings, Memories page.",
	MEM_ASK_DONE_NO        = "No pictures: memories stay written in the album. Change it in the settings, Memories page.",
	OPT_PAGE_MEMORIES      = "Memories",
	OPT_MEM_PHOTOS         = "Memory pictures",
	OPT_MEM_PHOTOS_DESC_ON = "At big moments, a screenshot (Screenshots folder), %d a day at most, never in combat.",
	OPT_MEM_PHOTOS_DESC_OFF= "No screenshot: memories stay written in the journal's album.",
	OPT_MEM_RECALL         = "Recalls memories out loud",
	OPT_MEM_ALBUM          = "Open the album",
	MEM_TXT_level          = "Reached level %s.",
	MEM_TXT_stage          = "%s became %s.",
	MEM_TXT_dungeon        = "First steps in %s.",
	MEM_TXT_capital        = "First visit to %s.",
	MEM_TXT_rare           = "%s defeated, a rare!",
	MEM_TXT_chest          = "%s completed to 100 %%: a chest!",
	MEM_TXT_death          = "First fall… we got back up.",
	MEM_TXT_deathSilly     = "The silliest death: %s, level %s.",
	MEM_TXT_deathFall      = "The silliest death: a fall.",
	MEM_TXT_groupFull      = "First full group, with %s.",
	MEM_TXT_groupDungeon   = "First dungeon as a group: %s.",
	MEM_TXT_flight         = "First flight, into the unknown.",
	MEM_TXT_mount          = "First mount!",
	MEM_TXT_anniv          = "%s together.",
	MEM_ANNIV_1d           = "One day",
	MEM_ANNIV_1w           = "One week",
	MEM_ANNIV_1m           = "One month",
	MEM_ANNIV_3m           = "Three months",
	MEM_ANNIV_6m           = "Six months",
	MEM_ANNIV_1y           = "One year",
	MEM_ANNIV_ny           = "%d years",
}
ns.RegisterStrings(FR, EN)
ns.MEMORY_STRINGS = { fr = FR, en = EN }

ns.RegisterDefaults({
	companionPhotos = false,      -- accord du joueur : demandé une fois, au premier grand moment
	companionRecall = true,
})

local DAY = 86400
ns.MEMORY_LEVELS = { [10] = true, [20] = true, [30] = true, [40] = true, [50] = true, [60] = true }
ns.MEMORY_CAPITALS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
ns.MEMORY_PHOTO_PER_DAY = 3
ns.MEMORY_PHOTO_DELAY = 1        -- s après le moment (ou après le combat)
ns.MEMORY_PHOTO_CLICK = 0.4      -- s entre « Clic ! » et la capture (la bulle est sur la photo)
ns.MEMORY_PHOTO_WAIT = 120       -- s au plus à attendre la fin du combat
ns.MEMORY_RECALL_GAP = 3600      -- s de jeu entre deux rappels
ns.MEMORY_ASK_AGAIN = 3600       -- « Plus tard » : redemandé au grand moment suivant, pas avant 1 h
ns.MEMORY_ANNIVERSARIES = {
	{ id = "1d", days = 1 }, { id = "1w", days = 7 }, { id = "1m", days = 30 },
	{ id = "3m", days = 91 }, { id = "6m", days = 182 }, { id = "1y", days = 365 },
}
-- les moments qui méritent une photo (les autres restent écrits)
ns.MEMORY_PHOTO_KINDS = { level = true, stage = true, dungeon = true, rare = true, chest = true,
	groupFull = true, groupDungeon = true, flight = true, mount = true }

local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end
local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function RealTime() return tonumber(Call(G("time"))) or 0 end
local function DateText(format, at)
	local fn = G("date") or (os and os.date)
	return Call(fn, format, at) or ""
end
local function InCombat()
	return Call(G("InCombatLockdown")) == true or Call(G("UnitAffectingCombat"), "player") == true
end

-- ---------------------------------------------------------------------------
-- Données : album, clés déjà vues, date de la rencontre
-- ---------------------------------------------------------------------------
function ns:MemoryData()
	local data = self:CompanionData()
	if type(data.memories) ~= "table" then data.memories = {} end
	if type(data.memoryKeys) ~= "table" then data.memoryKeys = {} end
	if not tonumber(data.metAt) then data.metAt = RealTime() end
	return data
end

-- « Une semaine », « 3 ans »
function ns:MemoryAnnivLabel(id)
	id = tostring(id or "")
	local years = tonumber(id:match("^(%d+)y$"))
	if years and years > 1 then return self:F("MEM_ANNIV_ny", years) end
	return L["MEM_ANNIV_" .. id]
end

function ns:MemoryText(memory)
	local args = type(memory.args) == "table" and memory.args or {}
	if memory.kind == "anniv" then return self:F("MEM_TXT_anniv", self:MemoryAnnivLabel(args[1])) end
	return self:F("MEM_TXT_" .. tostring(memory.kind), unpack(args))
end

local function ZoneName(self)
	local mapID = self.CurrentMap and self:CurrentMap()
	local info = mapID and self.MapInfo and self:MapInfo(mapID)
	return info and info.name or nil
end

-- Retient un souvenir (une fois par clé) ; renvoie le souvenir, ou nil
function ns:MemoryRecord(kind, key, args, opts)
	if not (self.CompanionOn and self.CompanionOn()) then return nil end
	opts = opts or {}
	local data = self:MemoryData()
	key = tostring(key or kind)
	local existing = data.memoryKeys[key]
	if existing and not opts.replace then return nil end
	local memory = {
		at = RealTime(), kind = kind, args = args or {},
		zone = opts.zone or ZoneName(self),
	}
	if existing and opts.replace then
		for index, old in ipairs(data.memories) do
			if old.key == key then table.remove(data.memories, index); break end
		end
	end
	memory.key = key
	data.memoryKeys[key] = true
	data.memories[#data.memories + 1] = memory
	if ns.MEMORY_PHOTO_KINDS[kind] and opts.photo ~= false then self:MemoryWantPhoto(memory) end
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then pcall(self.RefreshJournal, self) end
	return memory
end

-- ---------------------------------------------------------------------------
-- Photos : accord, combat, quota du jour
-- ---------------------------------------------------------------------------
function ns:MemoryState()
	local state = self.memoryState
	if not state then
		state = {}
		self.memoryState = state
	end
	return state
end

function ns:MemoryPhotosToday()
	local data = self:MemoryData()
	local today = DateText("%Y-%m-%d", RealTime())
	if type(data.photoDay) ~= "table" or data.photoDay.day ~= today then data.photoDay = { day = today, count = 0 } end
	return data.photoDay
end

function ns:MemoryWantPhoto(memory)
	local db = self:DB()
	if db.companionPhotos ~= true then
		-- jamais demandé, ou « Plus tard » depuis assez longtemps : on demande
		local asked = db.companionPhotosAsked
		local laterOk = asked == "later" and Clock() - (self:MemoryState().askedAt or -math.huge) >= ns.MEMORY_ASK_AGAIN
		if asked == nil or laterOk then self:MemoryAsk(memory) end
		return false
	end
	if self:MemoryPhotosToday().count >= ns.MEMORY_PHOTO_PER_DAY then return false end
	local state = self:MemoryState()
	if state.shot then return false end        -- une photo à la fois
	state.shot = { memory = memory, at = Clock() + ns.MEMORY_PHOTO_DELAY, expires = Clock() + ns.MEMORY_PHOTO_WAIT }
	return true
end

function ns:MemoryAsk(memory)
	local state = self:MemoryState()
	state.askedAt, state.askMemory = Clock(), memory
	self:DB().companionPhotosAsked = "asking"
	local dialogs = G("StaticPopupDialogs")
	if type(dialogs) == "table" then
		dialogs.QUESTCOMPANION_PHOTO = dialogs.QUESTCOMPANION_PHOTO or {
			text = "%s", button1 = L.MEM_ASK_YES, button2 = L.MEM_ASK_NO, button3 = L.MEM_ASK_LATER,
			OnAccept = function() ns:MemoryAnswer("yes") end,
			OnCancel = function(_, _, reason) if reason ~= "timeout" then ns:MemoryAnswer("no") end end,
			OnAlt = function() ns:MemoryAnswer("later") end,
			timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
		}
		Call(G("StaticPopup_Show"), "QUESTCOMPANION_PHOTO", self:F("MEM_ASK_TEXT", self:CompanionName()))
	end
end

-- Réponse du joueur : « yes » (et la photo du moment, s'il est encore frais), « no », « later »
function ns:MemoryAnswer(answer)
	local db = self:DB()
	local state = self:MemoryState()
	if answer == "yes" then
		db.companionPhotos, db.companionPhotosAsked = true, "yes"
		self:Print(L.MEM_ASK_DONE_YES)
		local memory = state.askMemory
		state.askMemory = nil
		if memory and Clock() - (state.askedAt or 0) <= ns.MEMORY_PHOTO_WAIT then self:MemoryWantPhoto(memory) end
	elseif answer == "no" then
		db.companionPhotos, db.companionPhotosAsked = false, "no"
		state.askMemory = nil
		self:Print(L.MEM_ASK_DONE_NO)
	else
		db.companionPhotosAsked = "later"
		state.askMemory = nil
	end
	if self.RefreshOptions then pcall(self.RefreshOptions, self) end
end

-- Une étape de la photo en attente : « Clic ! », puis la capture
function ns:MemoryPhotoStep(now)
	local state = self:MemoryState()
	local shot = state.shot
	if not shot then return end
	now = now or Clock()
	if self:DB().companionPhotos ~= true or now > shot.expires then state.shot = nil; return end
	if InCombat() then
		shot.at = now + ns.MEMORY_PHOTO_DELAY        -- jamais en combat : 1 s après
		return
	end
	if now < shot.at then return end
	if not shot.clicked then
		shot.clicked = true
		shot.at = now + ns.MEMORY_PHOTO_CLICK
		self:CompanionSay("PHOTO", { force = true })
		return
	end
	state.shot = nil
	local take = G("Screenshot")
	if type(take) ~= "function" then return end
	state.taking = shot.memory
	local day = self:MemoryPhotosToday()
	day.count = day.count + 1
	Call(take)
end

-- SCREENSHOT_SUCCEEDED : le nom du fichier suit celui que le jeu donne
function ns:MemoryPhotoDone(ok)
	local state = self:MemoryState()
	local memory = state.taking
	state.taking = nil
	if not memory then return end
	if not ok then
		local day = self:MemoryPhotosToday()
		day.count = math.max(0, day.count - 1)
		return
	end
	memory.photo = DateText("WoWScrnShot_%m%d%y_%H%M%S.jpg", RealTime())
	if self.CompanionFx then self:CompanionFx("flash") end
	self:Print(self:F("MEM_PHOTO_TAKEN", memory.photo))
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then pcall(self.RefreshJournal, self) end
end

-- ---------------------------------------------------------------------------
-- Anniversaires et rappels
-- ---------------------------------------------------------------------------
function ns:MemoryCheckAnniversary()
	local data = self:MemoryData()
	local days = (RealTime() - data.metAt) / DAY
	local due
	for _, anniv in ipairs(ns.MEMORY_ANNIVERSARIES) do
		if days >= anniv.days and not data.memoryKeys["anniv:" .. anniv.id] then due = anniv.id end
	end
	local years = math.floor(days / 365)
	if years >= 2 and not data.memoryKeys["anniv:" .. years .. "y"] then due = years .. "y" end
	if not due then return nil end
	-- les paliers sautés (longue absence) ne sont pas rattrapés un par un
	for _, anniv in ipairs(ns.MEMORY_ANNIVERSARIES) do
		if days >= anniv.days then data.memoryKeys["anniv:" .. anniv.id] = true end
	end
	for year = 2, years do data.memoryKeys["anniv:" .. year .. "y"] = true end
	data.memoryKeys["anniv:" .. due] = nil
	local memory = self:MemoryRecord("anniv", "anniv:" .. due, { due })
	if memory then self:CompanionSay("ANNIV", { force = true, args = { self:MemoryAnnivLabel(due):lower() } }) end
	return memory
end

function ns:MemoryRecall(now)
	if self:DB().companionRecall == false then return false end
	now = now or Clock()
	local state = self:MemoryState()
	state.recallAt = state.recallAt or now           -- la première heure de jeu compte aussi
	if now - state.recallAt < ns.MEMORY_RECALL_GAP then return false end
	local data = self:MemoryData()
	local pool, real = {}, RealTime()
	for _, memory in ipairs(data.memories) do
		if memory.kind ~= "anniv" and real - (tonumber(memory.at) or real) >= 3600 then pool[#pool + 1] = memory end
	end
	if #pool == 0 then return false end
	local memory = pool[math.random(#pool)]
	local said = self:CompanionSay("RECALL", { args = { self:MemoryText(memory) } })
	if said then state.recallAt = now end
	return said and true or false
end

-- ---------------------------------------------------------------------------
-- Les moments : par enveloppe des réactions existantes, et un coup d'œil
-- régulier (vol, monture, groupe)
-- ---------------------------------------------------------------------------
local function Wrap(name, after)
	local original = ns[name]
	if type(original) ~= "function" then return end
	ns[name] = function(self, ...)
		local a, b, c = original(self, ...)
		local ok, err = pcall(after, self, a, ...)
		if not ok and self.RecordError then self:RecordError("memory:" .. name, err) end
		return a, b, c
	end
end

Wrap("CompanionOnLevel", function(self, _, level)
	level = tonumber(level)
	if level and ns.MEMORY_LEVELS[level] then self:MemoryRecord("level", "level:" .. level, { level }) end
end)
Wrap("CompanionCelebrate", function(self)
	local stage = self.CompanionStage and self:CompanionStage() or 1
	self:MemoryRecord("stage", "stage:" .. stage, { self:CompanionName(), self:CompanionStageLabel() })
end)

local function GroupSize()
	if Call(G("IsInRaid")) then return 0 end
	if not Call(G("IsInGroup")) then return 0 end
	local count = 0
	for index = 1, 4 do if Call(G("UnitExists"), "party" .. index) then count = count + 1 end end
	return count
end

Wrap("CompanionOnZone", function(self, _, newArea)
	if not newArea then return end
	local mapID = self.CurrentMap and self:CurrentMap()
	if mapID and ns.MEMORY_CAPITALS[mapID] then
		local info = self.MapInfo and self:MapInfo(mapID)
		self:MemoryRecord("capital", "capital:" .. mapID, { info and info.name or "?" }, { zone = info and info.name })
	end
	if self.InInstance and self:InInstance() then
		local name = Call(G("GetInstanceInfo")) or ZoneName(self) or "?"
		self:MemoryRecord("dungeon", "dungeon:" .. name, { name }, { zone = name })
		if GroupSize() > 0 then self:MemoryRecord("groupDungeon", "groupDungeon", { name }, { zone = name }) end
	end
end)

local RARES = { rare = true, rareelite = true }
Wrap("CompanionOnKill", function(self)
	if not Call(G("UnitIsDead"), "target") then return end
	if not RARES[Call(G("UnitClassification"), "target") or ""] then return end
	local name = Call(G("UnitName"), "target")
	if name then self:MemoryRecord("rare", "rare:" .. name, { name }) end
end)

Wrap("ChestCheck", function(self, chest)
	if type(chest) ~= "table" then return end
	self:MemoryRecord("chest", "chest:" .. tostring(chest.name), { chest.name or "?" })
end)

-- mort : la première, et « la plus bête » (une chute, ou l'ennemi le plus
-- faible par rapport à toi), qui remplace la précédente si elle l'est plus
Wrap("CompanionOnDead", function(self)
	self:MemoryRecord("death", "death", nil, { photo = false })
	local data = self:MemoryData()
	local score, kind, args
	if Call(G("IsFalling")) then
		score, kind, args = 100, "deathFall", {}
	elseif Call(G("UnitExists"), "target") and Call(G("UnitCanAttack"), "player", "target") then
		local mine = tonumber(Call(G("UnitLevel"), "player")) or 1
		local theirs = tonumber(Call(G("UnitLevel"), "target")) or mine
		local class = Call(G("UnitClassification"), "target") or "normal"
		if theirs > 0 and class == "normal" and mine - theirs >= 3 then
			score, kind, args = mine - theirs, "deathSilly", { Call(G("UnitName"), "target") or "?", theirs }
		end
	end
	if score and score > (tonumber(data.sillyScore) or 0) then
		data.sillyScore = score
		self:MemoryRecord(kind, "deathSilly", args, { replace = true, photo = false })
	end
end)

function ns:MemoryPoll()
	if not (self.CompanionOn and self.CompanionOn()) then return end
	local state = self:MemoryState()
	local data = self:MemoryData()
	local flying = Call(G("UnitOnTaxi"), "player") == true
	if flying and state.flying == false then self:MemoryRecord("flight", "flight") end
	state.flying = flying
	local mounted = Call(G("IsMounted")) == true
	if mounted and state.mounted == false and not data.memoryKeys.mount then self:MemoryRecord("mount", "mount") end
	state.mounted = mounted
	if GroupSize() >= 4 and not data.memoryKeys.groupFull then
		local names = {}
		for index = 1, 4 do names[#names + 1] = Call(G("UnitName"), "party" .. index) or "?" end
		self:MemoryRecord("groupFull", "groupFull", { table.concat(names, ", ") })
	end
	self:MemoryCheckAnniversary()
	self:MemoryRecall()
end

-- ---------------------------------------------------------------------------
-- Réglages : page « Souvenirs »
-- ---------------------------------------------------------------------------
if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "companionMemories", title = "OPT_PAGE_MEMORIES", parent = "companion", group = "OPT_GROUP_MODULES",
		rows = {
			{ key = "companionPhotos", label = "OPT_MEM_PHOTOS", kind = "bool",
				describe = function(on)
					return on and ns:F("OPT_MEM_PHOTOS_DESC_ON", ns.MEMORY_PHOTO_PER_DAY) or L.OPT_MEM_PHOTOS_DESC_OFF
				end,
				onChange = function(value)
					-- choisi dans les réglages : la question ne sera plus posée
					ns:DB().companionPhotosAsked = value and "yes" or "no"
				end },
			{ key = "companionRecall", label = "OPT_MEM_RECALL", kind = "bool" },
			{ key = "companionAlbum", label = "OPT_MEM_ALBUM", kind = "action" },
		},
	})
end
if type(ns.OPTION_ACTIONS) == "table" then
	ns.OPTION_ACTIONS.companionAlbum = function(self) self:OpenMemories() end
end

function ns:OpenMemories()
	if self.ToggleJournal then self:ToggleJournal(true) end
	if self.SelectJournalKind then self:SelectJournalKind("memories") end
end

-- ---------------------------------------------------------------------------
-- Album : la partie « Souvenirs » du carnet (JournalWindow.lua l'appelle)
-- ---------------------------------------------------------------------------
local ROWS, ROW_H = 8, 36
ns.MEMORY_ALBUM_ROWS = ROWS

function ns:BuildMemoriesPane(frame, top, width)
	local pane = CreateFrame("Frame", nil, frame)
	pane:SetAllPoints()
	frame.mem = pane
	pane.header = pane:CreateFontString(nil, "OVERLAY", Theme.F_NORMAL)
	pane.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 36)
	pane.hint = pane:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	pane.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, top - 56)
	pane.hint:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	pane.rows = {}
	local listTop = top - 80
	for index = 1, ROWS do
		local row = CreateFrame("Frame", nil, pane)
		row:SetSize(width, ROW_H - 2)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, listTop - (index - 1) * ROW_H)
		row.stamp = Theme.CreateDiamond(row, 10, false)
		row.stamp:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3)
		row.text = row:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
		row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 22, 0)
		row.text:SetWidth(width - 130)
		row.text:SetJustifyH("LEFT")
		row.date = row:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		row.date:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, 0)
		row.date:SetJustifyH("RIGHT")
		row.date:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
		row.detail = row:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
		row.detail:SetPoint("TOPLEFT", row, "TOPLEFT", 22, -16)
		row.detail:SetWidth(width - 24)
		row.detail:SetJustifyH("LEFT")
		row.detail:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
		row:Hide()
		pane.rows[index] = row
	end
	local bottom = listTop - ROWS * ROW_H
	pane.empty = pane:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	pane.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, listTop - 4)
	pane.empty:SetWidth(width - 4)
	pane.empty:SetJustifyH("LEFT")
	pane.empty:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	pane.position = pane:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	pane.position:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, bottom - 6)
	pane.up = Theme.CreateButton(pane, 22, 17, "^", function() ns:ScrollJournal(1) end)
	pane.up:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, bottom - 4)
	pane.down = Theme.CreateButton(pane, 22, 17, "v", function() ns:ScrollJournal(-1) end)
	pane.down:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, bottom - 4)
	pane:Hide()
	return pane
end

-- Album dans l'ordre chronologique
function ns:RefreshMemoriesPane(frame)
	local pane = frame.mem
	if not pane then return end
	local list = self:MemoryData().memories
	local photos = 0
	for _, memory in ipairs(list) do if memory.photo then photos = photos + 1 end end
	pane.header:SetText(self:F("MEM_HEADER", #list, photos))
	pane.hint:SetText(L.MEM_HEADER_HINT)
	local maxOffset = math.max(0, #list - ROWS)
	frame.offset = math.max(0, math.min(tonumber(frame.offset) or 0, maxOffset))
	for index, row in ipairs(pane.rows) do
		local memory = list[frame.offset + index]
		if memory then
			row.memory = memory
			row.text:SetText(self:MemoryText(memory))
			row.date:SetText(DateText("%d/%m/%Y", memory.at))
			local detail = {}
			if memory.zone then detail[#detail + 1] = tostring(memory.zone) end
			if memory.photo then detail[#detail + 1] = self:F("MEM_PHOTO", memory.photo) end
			row.detail:SetText(table.concat(detail, "  ·  "))
			local c = memory.photo and Theme.GOLD or Theme.MUTED
			row.stamp:SetVertexColor(c[1], c[2], c[3], 1)
			row:Show()
		else
			row.memory = nil
			row:Hide()
		end
	end
	pane.empty:SetText(#list == 0 and L.MEM_EMPTY or "")
	pane.position:SetText(#list > ROWS
		and string.format("%d-%d / %d", frame.offset + 1, math.min(#list, frame.offset + ROWS), #list) or "")
	if frame.offset > 0 then pane.up:Show() else pane.up:Hide() end
	if frame.offset < maxOffset then pane.down:Show() else pane.down:Hide() end
end

-- ---------------------------------------------------------------------------
-- Horloge et événements
-- ---------------------------------------------------------------------------
local ok, frame = pcall(CreateFrame, "Frame")
if ok and frame then
	for _, event in ipairs({ "SCREENSHOT_SUCCEEDED", "SCREENSHOT_FAILED" }) do pcall(frame.RegisterEvent, frame, event) end
	frame:SetScript("OnEvent", function(_, event)
		local done, err = pcall(ns.MemoryPhotoDone, ns, event == "SCREENSHOT_SUCCEEDED")
		if not done then ns:RecordError("memory:" .. tostring(event), err) end
	end)
	frame:SetScript("OnUpdate", function()
		local now = Clock()
		local done, err = pcall(ns.MemoryPhotoStep, ns, now)
		if not done then ns:RecordError("memory:photo", err) end
		if (ns.memoryPollAt or 0) > now then return end
		ns.memoryPollAt = now + 2
		done, err = pcall(ns.MemoryPoll, ns)
		if not done then ns:RecordError("memory:poll", err) end
	end)
	ns.memoryEventFrame = frame
end

if ns.Mark then ns.Mark("Memories") end
