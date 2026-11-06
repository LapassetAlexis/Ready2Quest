-- Memories.lua -- souvenirs et photos du compagnon (QuestCompanion)
--
-- Le compagnon retient les grands moments de la route dans un album (carnet,
-- partie « Souvenirs ») : date, lieu, ce qui s'est passé. Pour certains, il
-- prend une photo (capture d'écran du jeu, rangée dans le dossier
-- Screenshots ; un addon ne peut pas l'afficher). L'album montre à la place
-- une photo recréée de chaque souvenir (polaroïd : décor, compagnon en 3D tel
-- qu'il était, créature du moment), le nom de la capture au survol.
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
	MEM_PHOTO_NOTE         = "Les captures d'écran du jeu restent dans le dossier Screenshots : un addon n'a pas le droit de les lire. Chaque souvenir a donc sa photo recréée par ton compagnon.",
	MEM_EMPTY              = "Pas encore de souvenir. Monte de niveau, explore un donjon, croise un rare : il retiendra les grands moments.",
	MEM_PHOTO              = "photo : %s",
	MEM_PHOTO_TIP          = "Capture d'écran : %s (dossier Screenshots).",
	MEM_PHOTO_TAKEN        = "Photo prise pour l'album : %s (dossier Screenshots).",
	MEM_ASK_TEXT           = "%s aimerait prendre une photo pour son album de souvenirs (capture d'écran du jeu, quelques-unes par jour au plus, jamais en combat). D'accord ?",
	MEM_ASK_YES            = "Oui",
	MEM_ASK_NO             = "Non",
	MEM_ASK_LATER          = "Plus tard",
	MEM_ASK_TITLE          = "Photos souvenirs",
	MEM_ASK_SUB            = "Pour l'album du carnet de voyage",
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
	MEM_PHOTO_NOTE         = "The game's screenshots stay in the Screenshots folder: an addon isn't allowed to read them. So each memory gets a photo recreated by your companion.",
	MEM_EMPTY              = "No memory yet. Level up, explore a dungeon, meet a rare: it will remember the big moments.",
	MEM_PHOTO              = "picture: %s",
	MEM_PHOTO_TIP          = "Screenshot: %s (Screenshots folder).",
	MEM_PHOTO_TAKEN        = "Picture taken for the album: %s (Screenshots folder).",
	MEM_ASK_TEXT           = "%s would like to take a picture for its memory album (a game screenshot, a few a day at most, never in combat). Is that OK?",
	MEM_ASK_YES            = "Yes",
	MEM_ASK_NO             = "No",
	MEM_ASK_LATER          = "Later",
	MEM_ASK_TITLE          = "Memory pictures",
	MEM_ASK_SUB            = "For the travel journal's album",
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
ns.MEMORY_TICK = 0.1             -- s entre deux passages de l'horloge (photo, relevé)
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

-- L'allure du compagnon au moment du souvenir (pour sa photo recréée) :
-- une mascotte a un `display`, une créature capturée un `npc`
local function LookNow(self)
	if not self.CompanionCurrentAppearance then return nil end
	local ok, app = pcall(self.CompanionCurrentAppearance, self)
	if not (ok and type(app) == "table") then return nil end
	local look = { display = tonumber(app.display), npc = tonumber(app.npc) }
	if not (look.display or look.npc) then return nil end
	return look
end

-- Retient un souvenir (une fois par clé) ; renvoie le souvenir, ou nil.
-- opts : zone, replace, photo (false : pas de capture d'écran), npc (la
-- créature du moment : capture, rare, brillante, sur la photo recréée)
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
		look = LookNow(self), npc = tonumber(opts.npc),
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
		-- « asking » sans question ouverte dans cette session (/reload, déconnexion
		-- pendant la question) : on redemande, sinon elle ne reviendrait jamais
		local lost = asked == "asking" and self:MemoryState().askedAt == nil
		if asked == nil or laterOk or lost then self:MemoryAsk(memory) end
		return false
	end
	if self:MemoryPhotosToday().count >= ns.MEMORY_PHOTO_PER_DAY then return false end
	local state = self:MemoryState()
	if state.shot then return false end        -- une photo à la fois
	state.shot = { memory = memory, at = Clock() + ns.MEMORY_PHOTO_DELAY, expires = Clock() + ns.MEMORY_PHOTO_WAIT }
	return true
end

-- La question : une fenêtre de module (docs/UI.md), texte, « Oui » plein,
-- « Non » au trait, « Plus tard » à gauche. Le [×] vaut « Plus tard » : la
-- question reviendra. Pas d'Échap (comme l'ancienne fenêtre du jeu).
local PROMPT_W = 420
function ns:EnsurePhotoPrompt()
	if self.photoPrompt then return self.photoPrompt end
	if not (Theme and Theme.CreateDialog) then return nil end
	local frame = Theme.CreateDialog(UIParent, PROMPT_W, 200, { title = L.MEM_ASK_TITLE, subtitle = L.MEM_ASK_SUB })
	if not frame then return nil end
	frame:SetPoint("TOP", UIParent, "TOP", 0, -160)
	frame.text = Theme.Text(frame, Theme.F_BODY, Theme.LABEL)
	frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", frame.pad, frame.contentTop - 18)
	frame.text:SetWidth(frame.innerWidth)
	frame.text:SetJustifyH("LEFT")
	if frame.text.SetWordWrap then frame.text:SetWordWrap(true) end
	local function Answer(answer) frame:Hide(); ns:MemoryAnswer(answer) end
	frame.yes = frame:AddFooterButton(L.MEM_ASK_YES, function() Answer("yes") end, "primary")
	frame.no = frame:AddFooterButton(L.MEM_ASK_NO, function() Answer("no") end, "outline")
	frame.later = frame:AddFooterButton(L.MEM_ASK_LATER, function() Answer("later") end, "outline", "left")
	frame.close:SetScript("OnClick", function() Answer("later") end)
	frame.asks = 0
	frame:Hide()
	self.photoPrompt = frame
	return frame
end

function ns:MemoryAsk(memory)
	local state = self:MemoryState()
	state.askedAt, state.askMemory = Clock(), memory
	self:DB().companionPhotosAsked = "asking"
	local prompt = self:EnsurePhotoPrompt()
	if prompt then
		prompt.text:SetText(self:F("MEM_ASK_TEXT", self:CompanionName()))
		local h = Theme.TextHeight(prompt.text, prompt.innerWidth, Theme.F_BODY)
		prompt:SetHeight(math.ceil(-prompt.contentTop + 18 + h + 22 + Theme.DIALOG_FOOTER))
		prompt.asks = prompt.asks + 1
		prompt:Show()
		if Theme.FadeIn then Theme.FadeIn(prompt, 0.15) end
		return prompt
	end
	-- repli : la fenêtre du jeu (client sans les briques du thème)
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
	-- GUID secret possible (moteur 12.0) : lu par ns.Plain avant d'être découpé
	local npc = ns.BestiaryNpcID and ns.BestiaryNpcID(ns.Plain(Call(G("UnitGUID"), "target")))
	if name then self:MemoryRecord("rare", "rare:" .. name, { name }, { npc = npc }) end
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
			{ key = "companionAlbum", label = "OPT_MEM_ALBUM", kind = "action", button = "OPT_BTN_OPEN" },
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
--
-- Un addon ne peut pas lire les captures d'écran du jeu : chaque souvenir a
-- une photo recréée, façon polaroïd. Papier clair, ombre légèrement de
-- travers, bout de ruban ; dans la photo, un ciel et un sol (couleurs tirées
-- du moment et du lieu, toujours les mêmes pour un souvenir), le compagnon en
-- 3D tel qu'il était ce jour-là, et la créature du moment à côté (capture,
-- rare, brillante). Dessous, la légende et « lieu · date ».
-- Les modèles 3D coûtent : une page de cartes (COLS × ROWS), réutilisées.
-- ---------------------------------------------------------------------------
local COLS, ROWS = 3, 2
local PAGE = COLS * ROWS
local GAP_X, GAP_Y = 24, 16
local BORDER = 10                -- marge du papier autour de la photo
local CAPTION_H, META_H = 30, 14 -- légende (deux lignes), « lieu · date »
local FOOT = 8 + CAPTION_H + 2 + META_H + 8
ns.MEMORY_ALBUM_COLS, ns.MEMORY_ALBUM_ROWS, ns.MEMORY_ALBUM_PAGE = COLS, ROWS, PAGE
-- les souvenirs où la créature du moment pose à côté du compagnon
ns.MEMORY_CREATURE_KINDS = { capture = true, rare = true, shiny = true }

local function Mix(a, b, t)
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
local function Method(object, name, ...)
	if type(object) ~= "table" and type(object) ~= "userdata" then return false end
	local fn = object[name]
	if type(fn) ~= "function" then return false end
	return pcall(fn, object, ...)
end

-- papier, encre de la légende : tirés des jetons du thème
local PAPER = Mix(Theme.PARCHMENT, { 1, 1, 1 }, 0.35)  -- #f6f0e3 environ
local INK_PEN = Mix(Theme.INK, Theme.BLUE, 0.22)    -- encre bleu nuit
ns.MEMORY_PAPER = PAPER

-- Décors de la photo : haut et bas du ciel, haut et bas du sol
local SCENES = {
	meadow  = { Mix(Theme.BLUE, Theme.INK, 0.15), Mix(Theme.BLUE, Theme.PARCHMENT, 0.55),
		Mix(Theme.GREEN, Theme.GOLD_SOFT, 0.3), Mix(Theme.GREEN, Theme.INK, 0.6) },
	dawn    = { Mix(Theme.ORANGE_DEEP, Theme.INK, 0.25), Mix(Theme.GOLD_LIGHT, Theme.PARCHMENT, 0.35),
		Mix(Theme.GREEN, Theme.GOLD_SOFT, 0.35), Mix(Theme.GREEN, Theme.INK, 0.65) },
	dusk    = { Mix(Theme.RED, Theme.INK, 0.55), Mix(Theme.ORANGE_DEEP, Theme.PARCHMENT, 0.25),
		Mix(Theme.GREEN, Theme.INK, 0.55), Mix(Theme.GREEN, Theme.INK, 0.8) },
	cave    = { Mix(Theme.EDGE, Theme.INK, 0.6), Mix(Theme.EDGE, Theme.GOLD_SOFT, 0.3),
		Mix(Theme.GOLD_SOFT, Theme.INK, 0.55), Mix(Theme.GOLD_SOFT, Theme.INK, 0.8) },
	city    = { Mix(Theme.BLUE, Theme.INK, 0.1), Mix(Theme.BLUE, Theme.PARCHMENT, 0.6),
		Mix(Theme.GREY, Theme.PARCHMENT, 0.35), Mix(Theme.GREY, Theme.INK, 0.45) },
	gold    = { Mix(Theme.GOLD, Theme.ORANGE_DEEP, 0.3), Mix(Theme.GOLD_LIGHT, Theme.PARCHMENT, 0.5),
		Mix(Theme.GOLD_SOFT, Theme.GREEN, 0.4), Mix(Theme.GOLD_SOFT, Theme.INK, 0.6) },
	storm   = { Mix(Theme.GREY, Theme.INK, 0.6), Mix(Theme.GREY, Theme.PARCHMENT, 0.2),
		Mix(Theme.GREEN, Theme.INK, 0.7), Mix(Theme.INK, Theme.GREEN, 0.15) },
	sky     = { Mix(Theme.BLUE, Theme.INK, 0.05), Mix(Theme.BLUE, Theme.PARCHMENT, 0.7),
		Mix(Theme.PARCHMENT, Theme.BLUE, 0.15), Mix(Theme.BLUE, Theme.PARCHMENT, 0.45) },
}
ns.MEMORY_SCENES = SCENES
local KIND_SCENE = {
	level = "meadow", capture = "meadow", mount = "meadow", groupFull = "meadow",
	stage = "dawn", anniv = "dawn",
	rare = "dusk",
	dungeon = "cave", groupDungeon = "cave",
	capital = "city",
	shiny = "gold", chest = "gold",
	death = "storm", deathSilly = "storm", deathFall = "storm",
	flight = "sky",
}

-- petit hachage stable d'un texte (le lieu) : même lieu, même lumière
local function Hash(text)
	local h = 0
	text = tostring(text or "")
	for index = 1, #text do h = (h * 31 + text:byte(index)) % 65521 end
	return h
end

-- Le décor d'un souvenir : { id, sky = { haut, bas }, ground = { haut, bas } },
-- le même à chaque affichage (moment, puis lieu pour la lumière)
function ns:MemoryScene(memory)
	memory = memory or {}
	local id = KIND_SCENE[memory.kind] or "meadow"
	local base = SCENES[id]
	-- -6 % à +6 % de lumière selon le lieu
	local shade = ((Hash(memory.zone) % 13) - 6) / 100
	local toward = shade < 0 and Theme.INK or Theme.PARCHMENT
	local t = math.abs(shade)
	return {
		id = id, shade = shade,
		sky = { Mix(base[1], toward, t), Mix(base[2], toward, t) },
		ground = { Mix(base[3], toward, t), Mix(base[4], toward, t) },
	}
end

-- L'allure du compagnon sur la photo : celle du jour du souvenir, sinon
-- (souvenirs d'avant) celle d'aujourd'hui
-- `now` : l'allure d'aujourd'hui déjà lue (une fois par page, pas par carte)
function ns:MemoryLook(memory, now)
	local look = type(memory) == "table" and memory.look
	if type(look) == "table" and (tonumber(look.display) or tonumber(look.npc)) then
		return { display = tonumber(look.display), npc = tonumber(look.npc) }
	end
	return now or LookNow(self)
end

-- la créature du moment (capture, rare, brillante), si on la connaît
function ns:MemoryCreature(memory)
	if type(memory) ~= "table" or not ns.MEMORY_CREATURE_KINDS[memory.kind] then return nil end
	return tonumber(memory.npc)
end

-- Pose un modèle (mascotte : SetDisplayInfo, créature : SetCreature), comme
-- CompanionApplyModel ; rien d'autre si c'est déjà lui
local function ShowModel(model, display, npc, facing)
	if not model then return false end
	local key = tostring(display) .. ":" .. tostring(npc)
	local shown = model.lookKey == key
	if not shown then
		local mascot = false
		if display and type(model.SetDisplayInfo) == "function" then
			shown = pcall(model.SetDisplayInfo, model, display)
			mascot = shown
		end
		if not shown and npc and type(model.SetCreature) == "function" then shown = pcall(model.SetCreature, model, npc) end
		-- une créature (capturée ou du moment) est de taille réelle : de plus loin
		if shown then Method(model, "SetCamDistanceScale", mascot and 1.6 or (ns.CAPTURE_CAM_DISTANCE or 2.4)) end
	end
	if shown then
		model.lookKey = key
		Method(model, "SetFacing", facing or 0)
		model:Show()
	else
		model.lookKey = nil
		Method(model, "ClearModel")
		model:Hide()
	end
	return shown
end

local function NewModel(parent)
	local ok, model = pcall(CreateFrame, "PlayerModel", nil, parent)
	if not (ok and model) then return nil end
	model:Hide()
	return model
end

-- Une carte polaroïd (réutilisée d'une page à l'autre)
local function NewCard(pane, index, w, h)
	local card = CreateFrame("Frame", nil, pane)
	card:SetSize(w, h)
	card.index = index
	-- ombre de travers (un coin de rotation si le client sait faire)
	card.shadow = Theme.Solid(card, "BACKGROUND", Theme.INK, 0.45)
	card.shadow:SetPoint("TOPLEFT", card, "TOPLEFT", 3, -4)
	card.shadow:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 3, -4)
	Method(card.shadow, "SetRotation", (index % 2 == 0 and 1 or -1) * 0.025)
	card.paper = Theme.Solid(card, "BORDER", PAPER, 1)
	card.paper:SetAllPoints(card)
	-- la photo
	local photoW, photoH = w - 2 * BORDER, h - BORDER - FOOT
	card.photoW, card.photoH = photoW, photoH
	local photo = CreateFrame("Frame", nil, card)
	photo:SetPoint("TOPLEFT", card, "TOPLEFT", BORDER, -BORDER)
	photo:SetSize(photoW, photoH)
	card.photo = photo
	local horizon = math.floor(photoH * 0.38)
	card.sky = Theme.Solid(photo, "BACKGROUND", Theme.BLUE, 1)
	card.sky:SetPoint("TOPLEFT", photo, "TOPLEFT", 0, 0)
	card.sky:SetPoint("BOTTOMRIGHT", photo, "BOTTOMRIGHT", 0, horizon)
	card.ground = Theme.Solid(photo, "BACKGROUND", Theme.GREEN, 1)
	card.ground:SetPoint("TOPLEFT", photo, "BOTTOMLEFT", 0, horizon)
	card.ground:SetPoint("BOTTOMRIGHT", photo, "BOTTOMRIGHT", 0, 0)
	card.fallback = photo:CreateTexture(nil, "ARTWORK")
	card.fallback:SetTexture(Theme.LOGO)
	card.fallback:SetSize(math.min(64, photoH - 16), math.min(64, photoH - 16))
	card.fallback:SetPoint("CENTER", photo, "CENTER", 0, 0)
	card.fallback:Hide()
	card.model = NewModel(photo)
	card.creature = NewModel(photo)
	-- une vraie capture d'écran existe : losange ambre dans le coin
	card.stamp = Theme.CreateDiamond(photo, 10)
	card.stamp:SetPoint("TOPRIGHT", photo, "TOPRIGHT", -6, -6)
	card.stamp:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
	card.stamp:Hide()
	-- bout de ruban adhésif en haut, de travers
	card.tape = Theme.Solid(card, "OVERLAY", Theme.GOLD_LIGHT, 0.5)
	card.tape:SetSize(48, 14)
	card.tape:SetPoint("CENTER", card, "TOP", (index % 2 == 0) and 8 or -8, 0)
	Method(card.tape, "SetRotation", (index % 2 == 0 and -1 or 1) * 0.07)
	-- légende et « lieu · date »
	card.caption = Theme.Text(card, Theme.F_BODY, INK_PEN)
	Theme.NoShadow(card.caption)
	card.caption:SetPoint("TOPLEFT", card, "TOPLEFT", BORDER, -(BORDER + photoH + 8))
	card.caption:SetSize(photoW, CAPTION_H)
	card.caption:SetJustifyH("CENTER")
	card.caption:SetJustifyV("MIDDLE")
	if card.caption.SetWordWrap then card.caption:SetWordWrap(true) end
	Method(card.caption, "SetMaxLines", 2)
	card.meta = Theme.Text(card, Theme.F_SMALL, Theme.MUTED)
	Theme.NoShadow(card.meta)
	card.meta:SetPoint("TOPLEFT", card, "TOPLEFT", BORDER, -(BORDER + photoH + 8 + CAPTION_H + 2))
	card.meta:SetSize(photoW, META_H)
	card.meta:SetJustifyH("CENTER")
	if card.meta.SetWordWrap then card.meta:SetWordWrap(false) end
	-- au survol : le souvenir en entier, et le nom de la vraie capture
	if card.EnableMouse then card:EnableMouse(true) end
	card:SetScript("OnEnter", function(self)
		local tip, memory = rawget(_G, "GameTooltip"), self.memory
		if type(tip) ~= "table" or not memory then return end
		pcall(tip.SetOwner, tip, self, "ANCHOR_RIGHT")
		if tip.ClearLines then tip:ClearLines() end
		Theme.TooltipTitle(tip, ns:MemoryText(memory))
		Theme.TooltipHint(tip, self.meta:GetText() or "")
		if memory.photo then Theme.TooltipLine(tip, ns:F("MEM_PHOTO_TIP", memory.photo), Theme.TEXT, true) end
		tip:Show()
	end)
	card:SetScript("OnLeave", function()
		local tip = rawget(_G, "GameTooltip")
		if type(tip) == "table" and tip.Hide then tip:Hide() end
	end)
	card:Hide()
	return card
end

-- Place les modèles : seul, le compagnon au milieu ; avec la créature du
-- moment, chacun sa moitié, tournés l'un vers l'autre
local function PlaceModels(card, duo)
	local photo, w, h = card.photo, card.photoW, card.photoH
	for _, model in ipairs({ card.model, card.creature }) do model:ClearAllPoints() end
	if duo then
		card.model:SetPoint("BOTTOMLEFT", photo, "BOTTOMLEFT", 0, 0)
		card.model:SetSize(math.floor(w * 0.56), h)
		card.creature:SetPoint("BOTTOMRIGHT", photo, "BOTTOMRIGHT", 0, 0)
		card.creature:SetSize(math.floor(w * 0.56), h)
	else
		card.model:SetPoint("BOTTOM", photo, "BOTTOM", 0, 0)
		card.model:SetSize(math.floor(w * 0.8), h)
	end
end

local function FillCard(self, card, memory, now)
	card.memory = memory
	card.caption:SetText(self:MemoryText(memory))
	local meta = {}
	if memory.zone then meta[#meta + 1] = tostring(memory.zone) end
	local date = DateText("%d/%m/%Y", memory.at)
	if date ~= "" then meta[#meta + 1] = date end
	card.meta:SetText(table.concat(meta, "  ·  "))
	local scene = self:MemoryScene(memory)
	card.scene = scene.id
	-- dégradés verticaux (de bas en haut) : ciel clair à l'horizon, sol sombre devant
	Theme.Gradient(card.sky, "VERTICAL", scene.sky[2], 1, scene.sky[1], 1)
	Theme.Gradient(card.ground, "VERTICAL", scene.ground[2], 1, scene.ground[1], 1)
	local look = self:MemoryLook(memory, now) or {}
	local npc = self:MemoryCreature(memory)
	local duo = npc ~= nil and card.creature ~= nil
	card.look, card.npc = look, duo and npc or nil
	local shown = false
	if card.model then
		PlaceModels(card, duo)
		shown = ShowModel(card.model, look.display, look.npc, duo and 0.6 or 0.35)
	end
	local creatureShown = false
	if card.creature then
		if duo then creatureShown = ShowModel(card.creature, nil, npc, -0.6)
		else ShowModel(card.creature, nil, nil) end
	end
	card.modelShown, card.creatureShown = shown, creatureShown
	if shown or creatureShown then card.fallback:Hide() else card.fallback:Show() end
	if memory.photo then card.stamp:Show() else card.stamp:Hide() end
	card:Show()
end

-- frame : la fenêtre du carnet ; content : sa zone de droite ; layout :
-- { pad, top, width, pagerTop } (JournalWindow.lua). En-tête (compte), la
-- note sur les captures d'écran, une page de polaroïds, la pagination.
function ns:BuildMemoriesPane(frame, content, layout)
	layout = layout or {}
	local pad, top, width = layout.pad or 24, layout.top or -106, layout.width or 710
	local anchor = content or frame
	local pane = CreateFrame("Frame", nil, anchor)
	pane:SetAllPoints()
	frame.mem = pane
	local function At(region, x, y)
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", anchor, "TOPLEFT", pad + x, y)
	end
	pane.header = Theme.Text(pane, Theme.F_LABEL, Theme.LABEL)
	At(pane.header, 0, top - 2)
	pane.header:SetJustifyH("LEFT")
	pane.header:SetSize(width, 16)
	-- la note : pourquoi des photos recréées (texte fixe, mesuré une fois)
	pane.hint = Theme.Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT)
	At(pane.hint, 0, top - 22)
	pane.hint:SetJustifyH("LEFT")
	if pane.hint.SetWordWrap then pane.hint:SetWordWrap(true) end
	pane.hint:SetWidth(width)
	pane.hint:SetText(L.MEM_PHOTO_NOTE)
	local noteH = math.max(14, math.ceil(Theme.TextHeight(pane.hint, width, Theme.F_SMALL)))
	pane.hint:SetHeight(noteH)
	-- la grille : entre la note et la pagination
	local gridTop = top - 22 - noteH - 14
	local pagerTop = layout.pagerTop or (gridTop - 2 * 220)
	local gridBottom = pagerTop + 10
	local cardW = math.floor((width - (COLS - 1) * GAP_X) / COLS)
	local cardH = math.max(BORDER + FOOT + 60, math.floor((gridTop - gridBottom - (ROWS - 1) * GAP_Y) / ROWS))
	pane.cardW, pane.cardH, pane.gridTop = cardW, cardH, gridTop
	pane.cards = {}
	for index = 1, PAGE do
		local card = NewCard(pane, index, cardW, cardH)
		local col, row = (index - 1) % COLS, math.floor((index - 1) / COLS)
		At(card, col * (cardW + GAP_X), gridTop - row * (cardH + GAP_Y))
		pane.cards[index] = card
	end
	pane.empty = Theme.Text(pane, Theme.F_BODY, Theme.MUTED_LIGHT)
	At(pane.empty, 0, gridTop - 4)
	pane.empty:SetWidth(width)
	pane.empty:SetJustifyH("LEFT")
	if pane.empty.SetWordWrap then pane.empty:SetWordWrap(true) end
	-- chevrons : une page entière ; la molette (ScrollJournal) : une rangée
	pane.pager = Theme.CreatePager(pane, function(delta)
		frame.offset = (tonumber(frame.offset) or 0) - delta * PAGE
		pane.lastOffset = frame.offset
		ns:RefreshJournal()
	end)
	pane.pager:SetPoint("TOPRIGHT", anchor, "TOPLEFT", pad + width, pagerTop)
	pane.position, pane.up, pane.down = pane.pager.position, pane.pager.up, pane.pager.down
	-- carnet fermé : les modèles seront reposés à la réouverture
	pane:SetScript("OnHide", function()
		for _, card in ipairs(pane.cards) do
			if card.model then card.model.lookKey = nil end
			if card.creature then card.creature.lookKey = nil end
		end
	end)
	pane:Hide()
	return pane
end

-- Album dans l'ordre chronologique, une page de polaroïds
function ns:RefreshMemoriesPane(frame)
	local pane = frame.mem
	if not pane then return end
	local list = self:MemoryData().memories
	local photos = 0
	for _, memory in ipairs(list) do if memory.photo then photos = photos + 1 end end
	pane.header:SetText(self:F("MEM_HEADER", #list, photos))
	pane.hint:SetText(L.MEM_PHOTO_NOTE)
	local offset = tonumber(frame.offset) or 0
	-- un cran de molette (ScrollJournal : ±1) avance d'une rangée entière
	local last = pane.lastOffset
	if last and math.abs(offset - last) == 1 then offset = last + (offset - last) * COLS end
	local maxOffset = math.max(0, math.ceil((#list - PAGE) / COLS) * COLS)
	offset = math.max(0, math.min(offset, maxOffset))
	offset = math.floor(offset / COLS) * COLS
	frame.offset, pane.lastOffset = offset, offset
	local now = LookNow(self)
	for index, card in ipairs(pane.cards) do
		local memory = list[offset + index]
		if memory then
			FillCard(self, card, memory, now)
		else
			card.memory = nil
			card:Hide()
		end
	end
	pane.empty:SetText(#list == 0 and L.MEM_EMPTY or "")
	pane.pager:Update(offset, PAGE, #list, maxOffset)
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
	-- dix fois par seconde : la photo attend 1 s, puis 0,4 s après « Clic ! »
	frame:SetScript("OnUpdate", ns.Throttle(ns.MEMORY_TICK, function()
		local now = Clock()
		local done, err = pcall(ns.MemoryPhotoStep, ns, now)
		if not done then ns:RecordError("memory:photo", err) end
		if (ns.memoryPollAt or 0) > now then return end
		ns.memoryPollAt = now + 2
		done, err = pcall(ns.MemoryPoll, ns)
		if not done then ns:RecordError("memory:poll", err) end
	end))
	ns.memoryEventFrame = frame
end

if ns.Mark then ns.Mark("Memories") end
