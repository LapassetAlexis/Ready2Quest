-- Jukebox.lua -- Juke-box du carnet (QuestCompanion 2.12.0)
--
-- Écouter les musiques du jeu, au choix :
--   * le catalogue (MusicData.lua, généré) : des FileDataID du client rangés
--     par catégorie (zones, capitales, donjons, raids, tavernes, nouveautés
--     Forever, moments, thèmes), avec leur durée ; aucun son livré ;
--   * PlayMusic(id) remplace la musique de zone tant qu'elle joue, StopMusic()
--     la rend ; le canal Musique doit être ouvert (CVar Sound_EnableMusic) ;
--   * favoris et trois listes personnelles, au niveau du compte
--     (QuestCompanionDB.juke) ; lecture d'une liste dans l'ordre ou au hasard :
--     un seul C_Timer.After par piste (sa durée), jamais d'OnUpdate ; une piste
--     de durée inconnue boucle jusqu'au choix suivant ;
--   * PlayMusic qui répond false : la piste est notée absente pour le compte
--     (juke.missing), grisée et sautée par les listes ; /qc juke test essaie
--     un échantillon et dit ce qui a joué.
-- Page externe du carnet : ns.JOURNAL_PANES.juke (JournalWindow.lua), habit
-- Azeroth dans JournalAzeroth.lua (PAGE.juke / POST.juke).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	JRN_SEC_juke       = "Juke-box",
	JRN_SUB_juke       = "Les musiques du jeu, à la demande : clic sur une piste pour l'écouter, étoile pour la garder.",
	JUKE_CAT_zones     = "Zones",
	JUKE_CAT_cities    = "Capitales",
	JUKE_CAT_dungeons  = "Donjons",
	JUKE_CAT_raids     = "Raids",
	JUKE_CAT_taverns   = "Tavernes",
	JUKE_CAT_forever   = "Nouveautés Forever",
	JUKE_CAT_moments   = "Moments et batailles",
	JUKE_CAT_themes    = "Thèmes et fêtes",
	JUKE_CAT_fav       = "Favoris",
	JUKE_CAT_list      = "Liste %d",
	JUKE_COUNT         = "%s (%d)",
	JUKE_SEARCH        = "Rechercher une musique",
	JUKE_SEARCH_ALL    = "Recherche dans tout le juke-box",
	JUKE_MODE_seq      = "Dans l'ordre",
	JUKE_MODE_shuffle  = "Au hasard",
	JUKE_MODE_TIP      = "Ordre de lecture de « Tout jouer » : dans l'ordre de la page, ou au hasard.",
	JUKE_PLAY_ALL      = "Tout jouer",
	JUKE_PLAY_ALL_TIP  = "Joue toute la page, une piste après l'autre (les absentes sont sautées).",
	JUKE_STOP          = "Arrêter",
	JUKE_STOP_TIP      = "Arrête le juke-box : la musique de la zone reprend.",
	JUKE_NOW           = "En cours : %s",
	JUKE_NOW_NEXT      = "En cours : %s · ensuite : %s",
	JUKE_NOW_LOOP      = "%s (en boucle)",
	JUKE_IDLE          = "Rien ne joue : la musique de la zone suit son cours.",
	JUKE_MUSIC_OFF     = "La musique du jeu est coupée : Options, Son, cocher « Musique ».",
	JUKE_EMPTY         = "Aucune piste ici.",
	JUKE_EMPTY_FAV     = "Aucun favori : l'étoile d'une piste l'ajoute ici.",
	JUKE_EMPTY_LIST    = "Liste vide : le « + » d'une piste l'ajoute à la liste active (%s).",
	JUKE_ABSENT        = "absente",
	JUKE_FAV_TIP       = "Favori : clic pour l'ajouter ou le retirer.",
	JUKE_ADD_TIP       = "Ajouter à %s.",
	JUKE_REMOVE_TIP    = "Retirer de %s.",
	JUKE_ROW_TIP       = "Clic : écouter. La page devient la liste en cours.",
	JUKE_TIP_DUR       = "Durée : %s",
	JUKE_TIP_DUR_NONE  = "Durée inconnue : boucle jusqu'au choix suivant.",
	JUKE_TIP_ZONES     = "Jouée à : %s",
	JUKE_TIP_ID        = "Fichier du client : %d",
	JUKE_TIP_MISSING   = "Absente de ce client (PlayMusic a refusé) : sautée par les listes.",
	JUKE_MSG_PLAY      = "Juke-box : %s.",
	JUKE_MSG_STOP      = "Juke-box arrêté : la musique de la zone reprend.",
	JUKE_MSG_MISSING   = "Juke-box : %s n'est pas dans ce client (notée absente).",
	JUKE_MSG_UNKNOWN   = "Juke-box : piste inconnue (%s).",
	JUKE_MSG_TEST      = "Juke-box, essai de %d pistes :",
	JUKE_TEST_OK       = "joue",
	JUKE_TEST_NO       = "absente",
	JUKE_TEST_MAYBE    = "sans réponse du client",
	JUKE_MSG_TEST_DONE = "Essai fini : %d jouent, %d absentes, %d sans réponse. La musique de la zone reprend.",
	HELP_JUKE          = "/qc juke -- le juke-box (page du carnet) ; /qc juke stop ; /qc juke test ; /qc juke <n° de fichier>",
}
local EN = {
	JRN_SEC_juke       = "Jukebox",
	JRN_SUB_juke       = "The game's music on demand: click a track to listen, star it to keep it.",
	JUKE_CAT_zones     = "Zones",
	JUKE_CAT_cities    = "Capitals",
	JUKE_CAT_dungeons  = "Dungeons",
	JUKE_CAT_raids     = "Raids",
	JUKE_CAT_taverns   = "Taverns",
	JUKE_CAT_forever   = "New in Forever",
	JUKE_CAT_moments   = "Moments and battles",
	JUKE_CAT_themes    = "Themes and fairs",
	JUKE_CAT_fav       = "Favourites",
	JUKE_CAT_list      = "List %d",
	JUKE_COUNT         = "%s (%d)",
	JUKE_SEARCH        = "Search music",
	JUKE_SEARCH_ALL    = "Searching the whole jukebox",
	JUKE_MODE_seq      = "In order",
	JUKE_MODE_shuffle  = "Shuffle",
	JUKE_MODE_TIP      = "\"Play all\" order: as listed on the page, or shuffled.",
	JUKE_PLAY_ALL      = "Play all",
	JUKE_PLAY_ALL_TIP  = "Plays the whole page, one track after another (missing ones are skipped).",
	JUKE_STOP          = "Stop",
	JUKE_STOP_TIP      = "Stops the jukebox: the zone music comes back.",
	JUKE_NOW           = "Now playing: %s",
	JUKE_NOW_NEXT      = "Now playing: %s · next: %s",
	JUKE_NOW_LOOP      = "%s (looping)",
	JUKE_IDLE          = "Nothing playing: the zone music goes on.",
	JUKE_MUSIC_OFF     = "Game music is off: Options, Sound, tick \"Music\".",
	JUKE_EMPTY         = "No track here.",
	JUKE_EMPTY_FAV     = "No favourite yet: a track's star adds it here.",
	JUKE_EMPTY_LIST    = "Empty list: a track's \"+\" adds it to the active list (%s).",
	JUKE_ABSENT        = "missing",
	JUKE_FAV_TIP       = "Favourite: click to add or remove it.",
	JUKE_ADD_TIP       = "Add to %s.",
	JUKE_REMOVE_TIP    = "Remove from %s.",
	JUKE_ROW_TIP       = "Click: listen. The page becomes the current playlist.",
	JUKE_TIP_DUR       = "Length: %s",
	JUKE_TIP_DUR_NONE  = "Unknown length: loops until the next pick.",
	JUKE_TIP_ZONES     = "Played in: %s",
	JUKE_TIP_ID        = "Client file: %d",
	JUKE_TIP_MISSING   = "Not in this client (PlayMusic refused it): skipped by playlists.",
	JUKE_MSG_PLAY      = "Jukebox: %s.",
	JUKE_MSG_STOP      = "Jukebox stopped: the zone music comes back.",
	JUKE_MSG_MISSING   = "Jukebox: %s is not in this client (marked missing).",
	JUKE_MSG_UNKNOWN   = "Jukebox: unknown track (%s).",
	JUKE_MSG_TEST      = "Jukebox, trying %d tracks:",
	JUKE_TEST_OK       = "plays",
	JUKE_TEST_NO       = "missing",
	JUKE_TEST_MAYBE    = "no answer from the client",
	JUKE_MSG_TEST_DONE = "Test done: %d play, %d missing, %d without answer. The zone music comes back.",
	HELP_JUKE          = "/qc juke -- the jukebox (journal page); /qc juke stop; /qc juke test; /qc juke <file number>",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.JUKE_STRINGS = { fr = FR, en = EN } end

-- 2.12.0 : pictos du client (UiTextureAtlasMember 1.60.1.70753 : CGuy_Play
-- 32×32, CGuy_Stop, streamcinematic-playbutton 43×43, auctionhouse-icon-favorite
-- et -off 40×36, voicechat-icon-speaker 32×32), vérifiés à l'exécution
-- (Theme.PaintClient) ; sinon un fichier du client (2.12.1 : l'étoile des
-- marqueurs de raid pour les favoris)
ns.JUKE_ART = {
	play    = { atlases = { "CGuy_Play", "streamcinematic-playbutton" }, fallback = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" },
	stop    = { atlases = { "CGuy_Stop" }, fallback = "Interface\\Buttons\\UI-GroupLoot-Pass-Up" },
	speaker = { atlases = { "voicechat-icon-speaker", "chatframe-button-icon-speaker-on" }, fallback = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" },
	fav     = { atlases = { "auctionhouse-icon-favorite" }, fallback = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
	favOff  = { atlases = { "auctionhouse-icon-favorite-off" }, fallback = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", fallbackTint = true },
}
ns.JUKE_LISTS = 3                 -- listes personnelles
ns.JUKE_GAP = 1                   -- s entre deux pistes d'une liste
ns.JUKE_TEST_MAX = 12             -- pistes essayées par /qc juke test
local VIEWS = {}                  -- catégories, puis favoris et listes

-- ---------------------------------------------------------------------------
-- Catalogue : lu une fois, à la première demande (chaînes de MusicData.lua)
-- ---------------------------------------------------------------------------
-- Mémoire : une piste ne garde que 4 champs (id, dur, name, g = son groupe) ;
-- titre, zones et catégorie se lisent par la métatable (titres à part, clés
-- de recherche faites à la première recherche)
local catalog
local TRACK = { __index = function(track, key)
	if key == "title" then return catalog and catalog.titles[track.id] end
	if key == "areas" or key == "cat" then return track.g[key] end
	return nil
end }
function ns:MusicCatalog()
	if catalog then return catalog end
	catalog = { byId = {}, byCat = {}, list = {}, titles = {}, keys = {} }
	local french = ns.STRINGS_FRENCH ~= false
	-- groupes : nom dans la langue du client, zones
	local groups = {}
	for fr, en, areas in (ns.MUSIC_GROUPS or ""):gmatch("([^\t\n]*)\t([^\t\n]*)\t([^\t\n]*)") do
		groups[#groups + 1] = { name = (french or en == "") and fr or en, areas = areas ~= "" and areas or nil, cat = false }
	end
	local sep = french and " : " or ": "
	for _, cat in ipairs(ns.MUSIC_CATEGORIES or {}) do
		local tracks = {}
		local raw = ns.MUSIC_RAW and ns.MUSIC_RAW[cat] or ""
		for id, dur, group, suffix, title in raw:gmatch("(%d+)\t(%d+)\t(%d+)\t([^\t\n]*)\t([^\t\n]*)") do
			id = tonumber(id)
			local g = groups[tonumber(group)]
			if g and not catalog.byId[id] then
				g.cat = cat
				-- « Forêt, jour 2 », « Riverglades : Farholde Keep A », « Fossoyeuse »
				local name = g.name
				if suffix ~= "" then name = name .. (suffix:find("^%d+$") and " " or sep) .. suffix end
				local track = setmetatable({ id = id, dur = tonumber(dur) or 0, name = name, g = g }, TRACK)
				if title ~= "" then catalog.titles[id] = title end
				tracks[#tracks + 1] = track
				catalog.byId[id] = track
				catalog.list[#catalog.list + 1] = track
			end
		end
		catalog.byCat[cat] = tracks
	end
	-- vues de la page : les catégories non vides, les favoris, les listes
	for index in ipairs(VIEWS) do VIEWS[index] = nil end
	for _, cat in ipairs(ns.MUSIC_CATEGORIES or {}) do
		if #catalog.byCat[cat] > 0 then VIEWS[#VIEWS + 1] = cat end
	end
	VIEWS[#VIEWS + 1] = "fav"
	for index = 1, ns.JUKE_LISTS do VIEWS[#VIEWS + 1] = "list" .. index end
	-- les chaînes ne servent plus : la mémoire revient au ramassage
	-- (tests : gardées à part, pour relire le vrai catalogue)
	if ns.KEEP_STRINGS and ns.MUSIC_RAW then ns.MUSIC_RAW_KEPT, ns.MUSIC_GROUPS_KEPT = ns.MUSIC_RAW, ns.MUSIC_GROUPS end
	ns.MUSIC_RAW, ns.MUSIC_GROUPS = nil, nil
	return catalog
end
ns.JUKE_VIEWS = VIEWS
-- tests : le catalogue relu depuis des chaînes neuves
function ns.MusicCatalogReset(raw, categories, groups)
	catalog = nil
	if raw then ns.MUSIC_RAW = raw end
	if groups then ns.MUSIC_GROUPS = groups end
	if categories then ns.MUSIC_CATEGORIES = categories end
end

-- « 3:05 »
function ns.JukeTime(seconds)
	seconds = math.floor(tonumber(seconds) or 0)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- zones qui jouent la piste, dans la langue du client (C_Map.GetAreaInfo)
function ns:JukeZones(track)
	if not (track and track.areas) then return nil end
	local api = rawget(_G, "C_Map")
	local getArea = type(api) == "table" and api.GetAreaInfo or rawget(_G, "GetAreaInfo")
	if type(getArea) ~= "function" then return nil end
	local names, seen = {}, {}
	for area in track.areas:gmatch("%d+") do
		local ok, name = pcall(getArea, tonumber(area))
		if ok and type(name) == "string" and name ~= "" and not seen[name] then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	return #names > 0 and table.concat(names, ", ") or nil
end

-- ---------------------------------------------------------------------------
-- Sauvegarde du compte : favoris, listes, absentes, ordre de lecture
-- ---------------------------------------------------------------------------
function ns:JukeData()
	local db = self:DB()
	local juke = type(db.juke) == "table" and db.juke or {}
	db.juke = juke
	if type(juke.fav) ~= "table" then juke.fav = {} end
	if type(juke.missing) ~= "table" then juke.missing = {} end
	if type(juke.lists) ~= "table" then juke.lists = {} end
	for index = 1, ns.JUKE_LISTS do
		if type(juke.lists[index]) ~= "table" then juke.lists[index] = {} end
	end
	if juke.mode ~= "shuffle" then juke.mode = "seq" end
	juke.active = math.max(1, math.min(ns.JUKE_LISTS, math.floor(tonumber(juke.active) or 1)))
	return juke
end

function ns:JukeIsFav(id) return self:JukeData().fav[tonumber(id) or 0] == true end
function ns:JukeToggleFav(id)
	id = tonumber(id)
	if not (id and self:MusicCatalog().byId[id]) then return nil end
	local fav = self:JukeData().fav
	fav[id] = (not fav[id]) and true or nil
	return fav[id] == true
end

local function ListIndex(list, id)
	for index, value in ipairs(list) do if value == id then return index end end
	return nil
end
-- ajoute (ou retire, si elle y est) une piste d'une liste personnelle
function ns:JukeListToggle(listIndex, id)
	id = tonumber(id)
	local juke = self:JukeData()
	local list = juke.lists[tonumber(listIndex) or 0]
	if not (list and id and self:MusicCatalog().byId[id]) then return nil end
	local at = ListIndex(list, id)
	if at then table.remove(list, at); return false end
	list[#list + 1] = id
	juke.active = tonumber(listIndex)
	return true
end

function ns:JukeMissing(id) return self:JukeData().missing[tonumber(id) or 0] == true end

-- Pistes d'une vue (catégorie, « fav », « listN »), filtrées par la
-- recherche (repliée : minuscules, sans accents) ; la recherche vaut pour
-- tout le juke-box
function ns:JukeTracks(view, search, out)
	local cat = self:MusicCatalog()
	out = out or {}
	for index = #out, 1, -1 do out[index] = nil end
	local needle = search and search ~= "" and (ns.OptionFold and ns.OptionFold(search) or search) or nil
	if needle then
		local keys = cat.keys
		for _, track in ipairs(cat.list) do
			local key = keys[track.id]
			if not key then
				key = track.name .. " " .. (track.title or "")
				key = ns.OptionFold and ns.OptionFold(key) or key
				keys[track.id] = key
			end
			if key:find(needle, 1, true) then out[#out + 1] = track end
		end
		return out
	end
	if view == "fav" then
		local fav = self:JukeData().fav
		for _, track in ipairs(cat.list) do if fav[track.id] then out[#out + 1] = track end end
	elseif type(view) == "string" and view:match("^list%d$") then
		for _, id in ipairs(self:JukeData().lists[tonumber(view:sub(5))] or {}) do
			if cat.byId[id] then out[#out + 1] = cat.byId[id] end
		end
	else
		for _, track in ipairs(cat.byCat[view] or {}) do out[#out + 1] = track end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Lecture
-- ---------------------------------------------------------------------------
-- ns.juke : { id, queue = { id… }, pos, token } ; vide = rien ne joue
ns.juke = ns.juke or {}
local state = ns.juke

function ns:JukeMusicOn()
	local get = rawget(_G, "GetCVar")
	if type(get) ~= "function" then return true end
	local ok, value = pcall(get, "Sound_EnableMusic")
	return not ok or value == nil or tostring(value) ~= "0"
end

-- PlayMusic : true (joue), false (refusé : absent), nil (pas de réponse)
local function RawPlay(id)
	local play = rawget(_G, "PlayMusic")
	if type(play) ~= "function" then return false end
	local ok, result = pcall(play, id)
	if not ok then return false end
	if result == false then return false end
	return result == nil and nil or true
end
local function RawStop()
	local stop = rawget(_G, "StopMusic")
	if type(stop) == "function" then pcall(stop) end
end

local function Refresh()
	local frame = ns.journalFrame
	if frame and frame.kind == "juke" and frame.IsShown and frame:IsShown() then ns:RefreshJournal() end
end

-- la piste suivante de la file, absentes sautées (nil : fin de liste)
local function NextIndex(queue, from)
	if not queue then return nil end
	local juke = ns:JukeData()
	for index = from, #queue do
		if not juke.missing[queue[index]] then return index end
	end
	return nil
end

local function Schedule(track)
	state.token = (state.token or 0) + 1
	local timer = rawget(_G, "C_Timer")
	if not (state.queue and track.dur > 0) or type(timer) ~= "table" or type(timer.After) ~= "function" then return end
	local mine = state.token
	timer.After(track.dur + ns.JUKE_GAP, function()
		if state.token ~= mine or not state.id then return end
		ns:JukeNext()
	end)
end

-- Joue une piste. `queue`/`pos` : la liste en cours (sinon la piste seule,
-- qui boucle). Rend true, false (absente) ou nil (inconnue / non jouée).
function ns:JukePlay(id, queue, pos, quiet)
	id = tonumber(id)
	local track = id and self:MusicCatalog().byId[id]
	if not track then
		if not quiet then self:Print(self:F("JUKE_MSG_UNKNOWN", tostring(id))) end
		return nil
	end
	local result = RawPlay(id)
	if result == false then
		self:JukeData().missing[id] = true
		if not quiet then self:Print(self:F("JUKE_MSG_MISSING", track.name)) end
		Refresh()
		return false
	end
	-- elle joue (ou le client ne dit rien) : une absente notée reprend sa place
	if result then self:JukeData().missing[id] = nil end
	state.id, state.queue, state.pos = id, queue, queue and (pos or 1) or nil
	Schedule(track)
	if not quiet and not self:JukeMusicOn() then self:Print(L.JUKE_MUSIC_OFF) end
	Refresh()
	return true
end

-- Joue une liste à partir de `start` (dans l'ordre ou au hasard)
function ns:JukePlayList(ids, start, mode)
	local queue = {}
	for index, id in ipairs(ids or {}) do queue[index] = id end
	if #queue == 0 then return nil end
	mode = mode or self:JukeData().mode
	start = math.max(1, math.min(#queue, tonumber(start) or 1))
	if mode == "shuffle" then
		-- la piste choisie d'abord, le reste mélangé (Fisher-Yates)
		queue[1], queue[start] = queue[start], queue[1]
		for index = #queue, 3, -1 do
			local other = math.random(2, index)
			queue[index], queue[other] = queue[other], queue[index]
		end
		start = 1
	end
	local index = NextIndex(queue, start)
	-- une absente refusée en route : on tente la suivante (bornée par la file)
	while index do
		local played = self:JukePlay(queue[index], queue, index, true)
		if played ~= false then return played, queue[index] end
		index = NextIndex(queue, index + 1)
	end
	self:JukeStop(true)
	return false
end

-- Piste suivante de la liste en cours ; fin de liste : la zone reprend
function ns:JukeNext()
	local queue = state.queue
	if not queue then return self:JukeStop(true) end
	local index = NextIndex(queue, (state.pos or 0) + 1)
	while index do
		local played = self:JukePlay(queue[index], queue, index, true)
		if played ~= false then return played end
		index = NextIndex(queue, index + 1)
	end
	return self:JukeStop(true)
end

function ns:JukeStop(quiet)
	local was = state.id
	state.id, state.queue, state.pos = nil, nil, nil
	state.token = (state.token or 0) + 1
	RawStop()
	if was and not quiet then self:Print(L.JUKE_MSG_STOP) end
	Refresh()
	return was ~= nil
end

-- la piste en cours et la suivante (pour l'affichage)
function ns:JukeNow()
	local cat = self:MusicCatalog()
	local current = state.id and cat.byId[state.id] or nil
	local nextTrack
	if current and state.queue then
		local index = NextIndex(state.queue, (state.pos or 0) + 1)
		nextTrack = index and cat.byId[state.queue[index]] or nil
	end
	return current, nextTrack
end

-- /qc juke test : une piste par catégorie (puis d'autres), PlayMusic essayé
-- tour à tour ; on dit ce qui joue, puis la zone reprend
function ns:JukeTest(max)
	local cat = self:MusicCatalog()
	local sample, taken = {}, {}
	max = tonumber(max) or ns.JUKE_TEST_MAX
	local round = 1
	while #sample < max do
		local added = false
		for _, key in ipairs(ns.MUSIC_CATEGORIES or {}) do
			local track = cat.byCat[key] and cat.byCat[key][round]
			if track and not taken[track.id] and #sample < max then
				sample[#sample + 1], taken[track.id], added = track, true, true
			end
		end
		if not added then break end
		round = round + 1
	end
	self:Print(self:F("JUKE_MSG_TEST", #sample))
	local counts = { ok = 0, no = 0, maybe = 0 }
	local juke = self:JukeData()
	for _, track in ipairs(sample) do
		local result = RawPlay(track.id)
		local word
		if result == false then
			juke.missing[track.id] = true
			counts.no, word = counts.no + 1, L.JUKE_TEST_NO
		elseif result then
			juke.missing[track.id] = nil
			counts.ok, word = counts.ok + 1, L.JUKE_TEST_OK
		else
			counts.maybe, word = counts.maybe + 1, L.JUKE_TEST_MAYBE
		end
		print(string.format("   %d  %s : %s", track.id, track.name, word))
	end
	state.id, state.queue, state.pos = nil, nil, nil
	state.token = (state.token or 0) + 1
	RawStop()
	self:Print(self:F("JUKE_MSG_TEST_DONE", counts.ok, counts.no, counts.maybe))
	if not self:JukeMusicOn() then self:Print(L.JUKE_MUSIC_OFF) end
	Refresh()
	return counts, sample
end

-- ---------------------------------------------------------------------------
-- Commande : /qc juke [stop|test|<FileDataID>]
-- ---------------------------------------------------------------------------
function ns:OpenJournalJuke()
	if not self.ToggleJournal then return nil end
	local frame = self:ToggleJournal(true)
	if frame then self:SelectJournalKind("juke") end
	return frame
end

function ns:JukeCommand(rest)
	local word = ns.AsciiLower and ns.AsciiLower(tostring(rest or "")) or tostring(rest or "")
	if word == "stop" or word == "arret" then return self:JukeStop() end
	if word == "test" then return self:JukeTest() end
	if word:match("^%d+$") then
		local played = self:JukePlay(tonumber(word))
		if played then self:Print(self:F("JUKE_MSG_PLAY", self:MusicCatalog().byId[tonumber(word)].name)) end
		return played
	end
	return self:OpenJournalJuke()
end
ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["juke"] = function(self, rest) return self:JukeCommand(rest) end
ns.EXTRA_COMMANDS["jukebox"] = ns.EXTRA_COMMANDS["juke"]
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then table.insert(section[2], "HELP_JUKE") end
	end
end

-- ---------------------------------------------------------------------------
-- Page du carnet
-- ---------------------------------------------------------------------------
-- Mesures (depuis le haut gauche de la zone utile, comme ui.At)
local LIST_W, GAP = 190, 16
local CAT_H, CAT_STEP = 28, 30
local ROW_H, ROW_STEP = 24, 26
local ROWS = 13
local CTRL_Y, NOW_Y, LIST_Y = 36, 68, 100   -- sous ui.TOP : commandes, « en cours », pistes
local ICON = 16
ns.JUKE_LAYOUT = { listW = LIST_W, gap = GAP, catH = CAT_H, catStep = CAT_STEP, rowH = ROW_H, rowStep = ROW_STEP,
	rows = ROWS, ctrlY = CTRL_Y, nowY = NOW_Y, listY = LIST_Y }

local function Paint(region, c) region:SetTextColor(c[1], c[2], c[3]) end
local function NoWrap(text) if text.SetWordWrap then text:SetWordWrap(false) end return text end

local function ViewLabel(view)
	if type(view) == "string" and view:match("^list%d$") then return ns:F("JUKE_CAT_list", tonumber(view:sub(5))) end
	return L["JUKE_CAT_" .. tostring(view)] or tostring(view)
end
ns.JukeViewLabel = ViewLabel

local function ViewOf(view)
	ns:MusicCatalog()
	for _, key in ipairs(VIEWS) do if key == view then return key end end
	return VIEWS[1]
end

-- une rangée de piste : picto (lecture / en cours), nom, durée, étoile, « + »
local function NewRow(pane, ui, width)
	local row = Theme.CreateListRow(pane, width, ROW_H, { kind = "Button", detail = true, font = Theme.F_BODY })
	row.play = row:CreateTexture(nil, "OVERLAY")
	row.play:SetSize(ICON, ICON)
	row.play:SetPoint("LEFT", row, "LEFT", 6, 0)
	row.text:ClearAllPoints()
	row.text:SetPoint("LEFT", row, "LEFT", 6 + ICON + 6, 0)
	row.text:SetWidth(width - 6 - ICON - 6 - 154)
	row.add = CreateFrame("Button", nil, row)
	row.add:SetSize(ROW_H - 4, ROW_H - 4)
	row.add:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.add.label = Theme.Text(row.add, Theme.F_LABEL, Theme.LABEL)
	row.add.label:SetPoint("CENTER", row.add, "CENTER", 0, 0)
	row.add.label:SetText("+")
	row.fav = CreateFrame("Button", nil, row)
	row.fav:SetSize(ROW_H - 4, ROW_H - 4)
	row.fav:SetPoint("RIGHT", row.add, "LEFT", -2, 0)
	row.fav.icon = row.fav:CreateTexture(nil, "OVERLAY")
	row.fav.icon:SetSize(ICON, ICON)
	row.fav.icon:SetPoint("CENTER", row.fav, "CENTER", 0, 0)
	row.detail:ClearAllPoints()
	row.detail:SetPoint("RIGHT", row.fav, "LEFT", -8, 0)
	row:SetScript("OnClick", function(r) if r.track then ns:JukePick(r.index) end end)
	row:HookScript("OnEnter", function(r) if r.track then ns:JukeRowTip(r) end end)
	row:HookScript("OnLeave", ui.HideTip)
	row.fav:SetScript("OnClick", function(b)
		local r = b:GetParent()
		if r.track then ns:JukeToggleFav(r.track.id); ns:RefreshJournal() end
	end)
	-- 3.1.0 : « étoile » et « + » s'éclairent au survol (voile et filet du
	-- thème), comme toute commande cliquable du carnet
	row.fav.hover = Theme.CreateHover(row.fav)
	row.add.hover = Theme.CreateHover(row.add)
	local function Leave(b) b.hover:Hide(); ui.HideTip() end
	row.fav:SetScript("OnEnter", function(b) b.hover:Show(); ui.Tip(b, L.JRN_SEC_juke, { L.JUKE_FAV_TIP }, "above") end)
	row.fav:SetScript("OnLeave", Leave)
	row.add:SetScript("OnClick", function(b)
		local r = b:GetParent()
		if r.track then ns:JukeListToggle(r.listIndex or ns:JukeData().active, r.track.id); ns:RefreshJournal() end
	end)
	row.add:SetScript("OnEnter", function(b)
		b.hover:Show()
		local r = b:GetParent()
		local label = ViewLabel("list" .. (r.listIndex or ns:JukeData().active))
		ui.Tip(b, L.JRN_SEC_juke, { ns:F(r.listIndex and "JUKE_REMOVE_TIP" or "JUKE_ADD_TIP", label) }, "above")
	end)
	row.add:SetScript("OnLeave", Leave)
	return row
end

function ns:JukeRowTip(row)
	local ui, track = ns.JournalUI, row.track
	local lines = {}
	if track.title and track.title ~= track.name then lines[#lines + 1] = track.title end
	lines[#lines + 1] = track.dur > 0 and self:F("JUKE_TIP_DUR", ns.JukeTime(track.dur)) or L.JUKE_TIP_DUR_NONE
	local zones = self:JukeZones(track)
	if zones then lines[#lines + 1] = self:F("JUKE_TIP_ZONES", zones) end
	if self:JukeMissing(track.id) then lines[#lines + 1] = L.JUKE_TIP_MISSING end
	lines[#lines + 1] = self:F("JUKE_TIP_ID", track.id)
	lines[#lines + 1] = L.JUKE_ROW_TIP
	ui.Tip(row, track.name, lines, "above")
end

local function Build(self, frame, content, ui)
	local At, Text, Tip, HideTip = ui.At, ui.Text, ui.Tip, ui.HideTip
	local TOP, INNER, PAD, PAGER_Y = ui.TOP, ui.INNER, ui.PAD, ui.PAGER_Y
	local RX = LIST_W + GAP
	local RW = INNER - RX
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.juke = pane
	pane.RX, pane.RW = RX, RW
	frame.jukeView = frame.jukeView or "zones"
	frame.jukeOffset, frame.jukeSearch = frame.jukeOffset or 0, frame.jukeSearch or ""
	pane.tracks, pane.ids = {}, {}

	-- à gauche : une tuile par vue (catégories, favoris, listes)
	self:MusicCatalog()
	pane.cats = {}
	for index, key in ipairs(VIEWS) do
		local tile = Theme.CreateTile(pane, LIST_W, CAT_H)
		At(tile, content, 0, TOP - (index - 1) * CAT_STEP)
		tile.view = key
		tile.rowFill = index % 2 == 0 and Theme.ROW_ALT or Theme.ROW
		tile:SetFill(tile.rowFill)
		tile.label = NoWrap(Text(tile, Theme.F_BODY, Theme.LABEL, LIST_W - 20))
		tile.label:SetPoint("LEFT", tile, "LEFT", 10, 0)
		tile:SetScript("OnClick", function(t) ns:JukeSelect(t.view) end)
		pane.cats[index] = tile
	end

	-- à droite : titre de la vue, commandes, « en cours », pistes, pagination
	pane.title = NoWrap(Text(pane, Theme.F_TITLE, Theme.PARCHMENT, RW))
	At(pane.title, content, RX, TOP)
	pane.search = Theme.CreateSearchBox(pane, 180, L.JUKE_SEARCH, function(text)
		frame.jukeSearch, frame.jukeOffset = text or "", 0
		if frame.jukeSearch == "" then ns:RefreshJournal() else ns:JournalSoon("jukeSearch") end
	end)
	At(pane.search, content, RX, TOP - CTRL_Y)
	pane.mode = Theme.CreateButton(pane, 110, "sm", L.JUKE_MODE_seq, function()
		local juke = ns:JukeData()
		juke.mode = juke.mode == "shuffle" and "seq" or "shuffle"
		ns:RefreshJournal()
	end)
	At(pane.mode, content, RX + 190, TOP - CTRL_Y)
	pane.playAll = Theme.CreateButton(pane, 96, "sm", L.JUKE_PLAY_ALL, function() ns:JukePlayView() end, "accent")
	At(pane.playAll, content, RX + 306, TOP - CTRL_Y)
	pane.stop = Theme.CreateButton(pane, 92, "sm", L.JUKE_STOP, function() ns:JukeStop() end)
	At(pane.stop, content, RX + RW - 92, TOP - CTRL_Y)
	for _, def in ipairs({ { pane.mode, L.JUKE_MODE_TIP }, { pane.playAll, L.JUKE_PLAY_ALL_TIP }, { pane.stop, L.JUKE_STOP_TIP } }) do
		local button, tip = def[1], def[2]
		if button.HookScript then
			button:HookScript("OnEnter", function(b) Tip(b, b.GetText and b:GetText() or L.JRN_SEC_juke, { tip }, "above") end)
			button:HookScript("OnLeave", HideTip)
		end
	end
	pane.stop.icon = pane.stop:CreateTexture(nil, "OVERLAY")
	pane.stop.icon:SetSize(ICON - 4, ICON - 4)
	pane.stop.icon:SetPoint("LEFT", pane.stop, "LEFT", 8, 0)
	Theme.PaintClient(pane.stop.icon, ns.JUKE_ART.stop)
	pane.nowIcon = pane:CreateTexture(nil, "OVERLAY")
	pane.nowIcon:SetSize(ICON, ICON)
	At(pane.nowIcon, content, RX, TOP - NOW_Y)
	Theme.PaintClient(pane.nowIcon, ns.JUKE_ART.speaker)
	pane.now = NoWrap(Text(pane, Theme.F_BODY, Theme.TEXT, RW - ICON - 6))
	At(pane.now, content, RX + ICON + 6, TOP - NOW_Y)
	pane.hintLine = NoWrap(Text(pane, Theme.F_SMALL, Theme.ORANGE or Theme.GOLD, RW))
	At(pane.hintLine, content, RX, TOP - NOW_Y - 16)

	pane.rows = {}
	for index = 1, ROWS do
		local row = NewRow(pane, ui, RW)
		At(row, content, RX, TOP - LIST_Y - (index - 1) * ROW_STEP)
		row:SetIndex(index)
		pane.rows[index] = row
	end
	pane.empty = Text(pane, Theme.F_BODY, Theme.MUTED_LIGHT, RW)
	At(pane.empty, content, RX, TOP - LIST_Y - 6)
	pane.pager = Theme.CreatePager(pane, function(delta)
		frame.jukeOffset = (tonumber(frame.jukeOffset) or 0) - delta * ROWS
		ns:RefreshJournal()
	end)
	pane.pager:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, PAGER_Y)
	pane:Hide()
end

-- choix d'une vue (la recherche s'efface)
function ns:JukeSelect(view)
	local frame = self.journalFrame
	if not frame then return end
	frame.jukeView, frame.jukeOffset, frame.jukeSearch = ViewOf(view), 0, ""
	local pane = frame.juke
	if pane and pane.search and pane.search.SetText then pane.search:SetText("") end
	self:RefreshJournal()
end

-- clic sur une piste : la page devient la liste en cours, à partir d'elle
function ns:JukePick(index)
	local frame = self.journalFrame
	local pane = frame and frame.juke
	if not pane then return nil end
	local ids = pane.ids
	for i = #ids, 1, -1 do ids[i] = nil end
	for i, track in ipairs(pane.tracks) do ids[i] = track.id end
	local played, id = self:JukePlayList(ids, index, "seq")
	if played == false and #ids > 0 then self:Print(self:F("JUKE_MSG_MISSING", pane.tracks[index] and pane.tracks[index].name or "?")) end
	return played, id
end

-- « Tout jouer » : la page entière, dans l'ordre choisi
function ns:JukePlayView()
	local frame = self.journalFrame
	local pane = frame and frame.juke
	if not (pane and #pane.tracks > 0) then return nil end
	local ids = {}
	for i, track in ipairs(pane.tracks) do ids[i] = track.id end
	return self:JukePlayList(ids, 1)
end

local function Scroll(self, frame, delta)
	frame.jukeOffset = (tonumber(frame.jukeOffset) or 0) - (tonumber(delta) or 0) * 3
end

local function RefreshPage(self, frame, ui)
	local pane = frame.juke
	if not pane then return end
	local view = ViewOf(frame.jukeView)
	frame.jukeView = view
	local juke = self:JukeData()
	local cat = self:MusicCatalog()
	for _, tile in ipairs(pane.cats) do
		local on = tile.view == view and (frame.jukeSearch or "") == ""
		tile:SetSelected(on)
		tile:SetAccent(on and Theme.SELECT or nil)   -- choisi : la sélection (= or en Sobre)
		tile:SetFill(on and Theme.ROW_ALT or tile.rowFill)
		local count
		if tile.view == "fav" then
			count = 0
			for _ in pairs(juke.fav) do count = count + 1 end
		elseif tile.view:match("^list%d$") then
			count = #juke.lists[tonumber(tile.view:sub(5))]
		else
			count = #(cat.byCat[tile.view] or {})
		end
		tile.label:SetText(self:F("JUKE_COUNT", ViewLabel(tile.view), count))
		if not tile.label.azKeep then Paint(tile.label, on and Theme.PARCHMENT or Theme.LABEL) end
	end
	local search = frame.jukeSearch or ""
	self:JukeTracks(view, search, pane.tracks)
	local tracks = pane.tracks
	pane.title:SetText(search ~= "" and L.JUKE_SEARCH_ALL or self:F("JUKE_COUNT", ViewLabel(view), #tracks))
	pane.mode.text:SetText(L["JUKE_MODE_" .. juke.mode])
	-- en cours
	local current, nextTrack = self:JukeNow()
	if current then
		local name = current.dur > 0 and current.name or self:F("JUKE_NOW_LOOP", current.name)
		pane.now:SetText(nextTrack and self:F("JUKE_NOW_NEXT", name, nextTrack.name) or self:F("JUKE_NOW", name))
		pane.nowIcon:SetAlpha(1)
	else
		pane.now:SetText(L.JUKE_IDLE)
		pane.nowIcon:SetAlpha(0.45)
	end
	pane.hintLine:SetText(self:JukeMusicOn() and "" or L.JUKE_MUSIC_OFF)
	-- pistes
	local maxOffset = math.max(0, #tracks - ROWS)
	local offset = math.max(0, math.min(tonumber(frame.jukeOffset) or 0, maxOffset))
	frame.jukeOffset = offset
	local listIndex = view:match("^list%d$") and tonumber(view:sub(5)) or nil
	for index, row in ipairs(pane.rows) do
		local track = tracks[offset + index]
		row.track, row.index, row.listIndex = track, offset + index, listIndex
		if track then
			local missing = juke.missing[track.id] == true
			local playing = state.id == track.id
			row.text:SetText(track.name)
			row.detail:SetText(missing and L.JUKE_ABSENT or (track.dur > 0 and ns.JukeTime(track.dur) or "--:--"))
			row.missing, row.playing = missing, playing
			Theme.PaintClient(row.play, playing and ns.JUKE_ART.speaker or ns.JUKE_ART.play)
			row.play:SetAlpha(playing and 1 or (missing and 0.35 or 0.7))
			Theme.PaintClient(row.fav.icon, juke.fav[track.id] and ns.JUKE_ART.fav or ns.JUKE_ART.favOff)
			row.add.label:SetText(listIndex and "-" or "+")
			if not row.text.azKeep then
				-- piste qui joue : l'actif (= or en Sobre)
				Paint(row.text, missing and Theme.MUTED or (playing and Theme.ACTIVE or Theme.TEXT))
				Paint(row.detail, Theme.MUTED_LIGHT)
			end
			row:Show()
		else
			row:Hide()
		end
	end
	local empty = ""
	if #tracks == 0 then
		if search == "" and view == "fav" then empty = L.JUKE_EMPTY_FAV
		elseif search == "" and listIndex then empty = self:F("JUKE_EMPTY_LIST", ViewLabel("list" .. juke.active))
		else empty = L.JUKE_EMPTY end
	end
	pane.empty:SetText(empty)
	pane.pager:Update(offset, math.min(ROWS, #tracks - offset), #tracks, maxOffset)
end

ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.juke = {
	field = "juke", title = "JRN_SEC_juke", subtitle = "JRN_SUB_juke",
	build = Build, refresh = RefreshPage, scroll = Scroll,
}

if ns.Mark then ns.Mark("Jukebox") end
