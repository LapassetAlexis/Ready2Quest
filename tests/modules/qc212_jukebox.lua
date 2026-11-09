-- QuestCompanion 2.12.0 : Juke-box (catalogue généré, lecture PlayMusic /
-- StopMusic simulée, listes enchaînées par durée, favoris et absentes au
-- niveau du compte, /qc juke, page du carnet dans les deux styles, encres).
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local J = { saved = {} }
local GLOBALS = { "PlayMusic", "StopMusic", "GetCVar", "C_Timer", "UnitLevel", "InCombatLockdown", "UnitAffectingCombat" }
for _, name in ipairs(GLOBALS) do J.saved[name] = rawget(_G, name) end
local INK = NS.AZEROTH_INK
local RAW = NS.MUSIC_RAW or NS.MUSIC_RAW_KEPT
local GROUPS = NS.MUSIC_GROUPS or NS.MUSIC_GROUPS_KEPT
-- groupes de test : 1 Forêt, jour / 2 Forêt, nuit / 3 Été / 4 Hurlevent / 5 Riverglades
local G = "Forêt, jour\tForest, day\t12,40\nForêt, nuit\t\t\nÉté\tSummer\t\nHurlevent\tStormwind\t\nRiverglades\t\t\n"
local CATS = NS.MUSIC_CATEGORIES

-- PlayMusic simulé : `refuse[id]` rend false, `silent` ne rend rien
local calls
local function Install(refuse, silent)
	calls = { play = {}, stop = 0, timers = {} }
	_G.PlayMusic = function(id)
		calls.play[#calls.play + 1] = id
		if refuse and refuse[id] then return false end
		if silent then return nil end
		return true
	end
	_G.StopMusic = function() calls.stop = calls.stop + 1 end
	_G.GetCVar = function(name) if name == "Sound_EnableMusic" then return J.music or "1" end end
	_G.C_Timer = { After = function(delay, fn) calls.timers[#calls.timers + 1] = { delay = delay, fn = fn } end }
end
local function Fire()
	local list = calls.timers
	calls.timers = {}
	for _, t in ipairs(list) do t.fn() end
end

function J.Reset(style)
	ResetWorld()
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS.uiStyleCache = {}
	NS.errors = {}
	NS.carnetInkMisses = nil
	NS:DB().juke = nil
	NS:DB().journalState = nil
	NS:JukeStop(true)
	J.music = "1"
	Install()
	_G.UnitLevel = function() return 20 end
	_G.InCombatLockdown = function() return false end
	_G.UnitAffectingCombat = function() return false end
	if style == "azeroth" then Mock.InstallAtlas(true) else Mock.InstallAtlas(nil) end
	NS:AzerothAtlasOK(true)
	NS:DB().companionStyle = style == "azeroth" and "azeroth" or "sobre"
	NS:CompanionData().tutoDone = true
end
function J.Done()
	NS:JukeStop(true)
	if NS.journalFrame then NS.journalFrame:Hide() end
	NS.journalFrame = nil
	NS.uiStyleCache = {}
	NS:DB().juke = nil
	NS:DB().journalState = nil
	for _, name in ipairs(GLOBALS) do _G[name] = J.saved[name] end
	NS.MusicCatalogReset(RAW, CATS, GROUPS)
	ResetWorld()
end

-- 1. Données : le vrai catalogue, puis des chaînes de test -----------------------------------------------
do
	Say("-- 2.12.0 : catalogue du Juke-box")
	Check("[J212] MusicData : chaînes et catégories chargées", type(RAW) == "table" and type(CATS) == "table" and #CATS >= 6
		and type(GROUPS) == "string")
	NS.MusicCatalogReset(RAW, CATS, GROUPS)
	local cat = NS:MusicCatalog()
	local total, timed, sane = 0, 0, true
	for _, track in ipairs(cat.list) do
		total = total + 1
		if track.dur > 0 then timed = timed + 1 end
		if not (track.id > 0 and track.name ~= "" and cat.byId[track.id] == track) then sane = false end
	end
	Check("[J212] catalogue : plus de 300 pistes, toutes nommées", total > 300 and sane, total)
	Check("[J212] catalogue : durées connues pour 90 % au moins", timed >= total * 0.9, timed .. "/" .. total)
	Check("[J212] catalogue : thème principal (53223) dans les thèmes", cat.byId[53223] and cat.byId[53223].cat == "themes")
	Check("[J212] catalogue : chaînes libérées après lecture", NS.MUSIC_RAW == nil and NS.MUSIC_GROUPS == nil)
	local views = NS.JUKE_VIEWS
	Check("[J212] vues : catégories, favoris, 3 listes", views[#views] == "list3" and views[#views - 3] == "fav" and views[1] == CATS[1])

	-- chaînes de test : une piste sans durée, une absente
	NS.MusicCatalogReset({
		zones = "11\t60\t1\t1\tDay Forest 01\n12\t0\t2\t1\tNight Forest 01\n13\t30\t3\t\t\n",
		cities = "21\t90\t4\t1\tStormwind 04 Zone\n",
		forever = "31\t40\t5\tFarholde Keep A\t\n",
	}, { "zones", "cities", "forever" }, G)
	cat = NS:MusicCatalog()
	local t = cat.byId[11]
	Check("[J212] nom composé : rang, lieu, seul", cat.byId[31].name == "Riverglades : Farholde Keep A" and cat.byId[13].name == "Été")
	Check("[J212] lecture : champs (id, durée, nom FR, titre, zones)", t and t.dur == 60 and t.name == "Forêt, jour 1"
		and t.title == "Day Forest 01" and t.areas == "12,40" and t.cat == "zones")
	Check("[J212] lecture : durée 0 = inconnue, titre vide = nil", cat.byId[12].dur == 0 and cat.byId[13].title == nil)
	Check("[J212] durée affichée", NS.JukeTime(185) == "3:05" and NS.JukeTime(0) == "0:00")
	local found = NS:JukeTracks("zones", "foret")
	Check("[J212] recherche sans accents, dans tout le juke-box", #found == 2 and found[1].id == 11)
	found = NS:JukeTracks("zones", "ETE")
	Check("[J212] recherche insensible à la casse (ASCII)", #found == 1 and found[1].id == 13)
	_G.C_Map.GetAreaInfo = function(id) return ({ [12] = "Forêt d'Elwynn", [40] = "Marche de l'Ouest" })[id] end
	Check("[J212] zones de la piste, dans la langue du client", NS:JukeZones(t) == "Forêt d'Elwynn, Marche de l'Ouest")
	_G.C_Map.GetAreaInfo = nil
end

-- 2. Lecture, arrêt, absentes, CVar ----------------------------------------------------------------------
do
	Say("-- 2.12.0 : lecture")
	J.Reset("sobre")
	Check("[J212] PlayMusic : la piste joue", NS:JukePlay(11, nil, nil, true) == true and calls.play[1] == 11 and NS.juke.id == 11)
	Check("[J212] piste seule : pas de minuterie (elle boucle)", #calls.timers == 0)
	Check("[J212] StopMusic : la zone reprend", NS:JukeStop(true) == true and calls.stop == 1 and NS.juke.id == nil)
	Install({ [21] = true })
	Check("[J212] PlayMusic false : absente notée pour le compte", NS:JukePlay(21, nil, nil, true) == false
		and NS:DB().juke.missing[21] == true and NS:JukeMissing(21))
	Install()
	NS:JukePlay(21, nil, nil, true)
	Check("[J212] elle joue plus tard : retirée des absentes", NS:DB().juke.missing[21] == nil)
	Install(nil, true)
	Check("[J212] PlayMusic sans réponse : jouée, rien de noté", NS:JukePlay(11, nil, nil, true) == true and next(NS:DB().juke.missing) == nil)
	Check("[J212] piste inconnue : rien", NS:JukePlay(999, nil, nil, true) == nil)
	J.music = "0"
	Mock:Reset()
	NS:JukePlay(11)
	Check("[J212] musique coupée (Sound_EnableMusic 0) : le dire", not NS:JukeMusicOn() and Mock:Output():find(NS.L.JUKE_MUSIC_OFF, 1, true) ~= nil)
	J.Done()
end

-- 3. Listes : enchaînement par la durée, absentes sautées, hasard -----------------------------------------
do
	Say("-- 2.12.0 : listes")
	J.Reset("sobre")
	NS.MusicCatalogReset({
		zones = "11\t60\t1\t1\t\n12\t0\t2\t1\t\n13\t30\t3\t\t\n",
		cities = "21\t90\t4\t1\t\n",
	}, { "zones", "cities" }, G)
	Install({ [13] = true })
	NS:JukePlayList({ 11, 13, 21, 12 }, 1, "seq")
	Check("[J212] liste : première piste, minuterie de sa durée (+1 s)", NS.juke.id == 11 and #calls.timers == 1
		and calls.timers[1].delay == 60 + NS.JUKE_GAP)
	local now, nextTrack = NS:JukeNow()
	Check("[J212] « en cours » et « ensuite » (13 pas encore refusée)", now.id == 11 and nextTrack.id == 13)
	Fire()
	Check("[J212] fin de piste : 13 refusée et sautée, 21 joue", NS.juke.id == 21 and NS:JukeMissing(13) and calls.timers[1].delay == 91)
	Fire()
	Check("[J212] durée inconnue : la piste boucle (pas de minuterie)", NS.juke.id == 12 and #calls.timers == 0)
	NS:JukeNext()
	Check("[J212] fin de liste : StopMusic, la zone reprend", NS.juke.id == nil and calls.stop >= 1)
	-- une minuterie périmée (arrêt puis autre lecture) ne fait rien
	NS:JukePlayList({ 11, 21 }, 1, "seq")
	local stale = calls.timers[1]
	NS:JukePlayList({ 21, 11 }, 1, "seq")
	stale.fn()
	Check("[J212] minuterie périmée ignorée", NS.juke.id == 21)
	-- au hasard : la piste choisie d'abord, toutes une fois
	local ids = { 11, 12, 21 }
	NS:JukePlayList(ids, 2, "shuffle")
	local queue, seen = NS.juke.queue, {}
	for _, id in ipairs(queue) do seen[id] = true end
	Check("[J212] hasard : la piste choisie d'abord, file complète", queue[1] == 12 and #queue == 3 and seen[11] and seen[21])
	Check("[J212] la liste d'origine n'est pas touchée", ids[1] == 11 and ids[2] == 12 and ids[3] == 21)
	-- tout absent : arrêt
	Install({ [11] = true, [21] = true })
	Check("[J212] liste toute absente : rien ne joue", NS:JukePlayList({ 11, 21 }, 1, "seq") == false and NS.juke.id == nil)
	J.Done()
end

-- 4. Favoris, listes perso, sauvegarde du compte, test ---------------------------------------------------
do
	Say("-- 2.12.0 : favoris et listes")
	J.Reset("sobre")
	NS.MusicCatalogReset({ zones = "11\t60\t1\t1\t\n12\t0\t2\t1\t\n", cities = "21\t90\t4\t1\t\n" }, { "zones", "cities" }, G)
	Check("[J212] favori ajouté", NS:JukeToggleFav(12) == true and NS:DB().juke.fav[12] == true and NS:JukeIsFav(12))
	local favs = NS:JukeTracks("fav", "")
	Check("[J212] vue Favoris", #favs == 1 and favs[1].id == 12)
	Check("[J212] favori retiré", NS:JukeToggleFav(12) == false and NS:DB().juke.fav[12] == nil)
	Check("[J212] piste inconnue : pas de favori", NS:JukeToggleFav(777) == nil)
	NS:JukeListToggle(2, 21); NS:JukeListToggle(2, 11)
	local list = NS:JukeTracks("list2", "")
	Check("[J212] liste 2 : ordre d'ajout, devient active", #list == 2 and list[1].id == 21 and NS:DB().juke.active == 2)
	Check("[J212] retirer d'une liste", NS:JukeListToggle(2, 21) == false and #NS:DB().juke.lists[2] == 1)
	Check("[J212] sauvegarde au niveau du compte (QuestCompanionDB.juke)", rawget(_G, "QuestCompanionDB") and QuestCompanionDB.juke == NS:DB().juke)
	NS:DB().juke = { fav = "x", lists = { 5 }, mode = "??", active = 9 }
	local juke = NS:JukeData()
	Check("[J212] sauvegarde abîmée réparée", type(juke.fav) == "table" and type(juke.lists[1]) == "table" and juke.mode == "seq" and juke.active == 3)
	-- /qc juke test
	Install({ [21] = true })
	Mock:Reset()
	local counts, sample = NS:JukeTest()
	Check("[J212] /qc juke test : chaque catégorie essayée, résultat dit", #sample == 3 and counts.ok == 2 and counts.no == 1
		and NS:JukeMissing(21) and calls.stop == 1 and Mock:Output():find("21", 1, true) ~= nil)
	-- commandes
	Install()
	NS.EXTRA_COMMANDS.juke(NS, "11")
	Check("[J212] /qc juke <id> : joue", NS.juke.id == 11)
	NS.EXTRA_COMMANDS.juke(NS, "stop")
	Check("[J212] /qc juke stop : arrête", NS.juke.id == nil and calls.stop == 1)
	local help = false
	for _, section in ipairs(NS.HELP) do for _, key in ipairs(section[2]) do if key == "HELP_JUKE" then help = true end end end
	Check("[J212] aide : /qc juke", help)
	J.Done()
end

-- 5. Page du carnet, dans les deux styles ---------------------------------------------------------------
for _, style in ipairs({ "sobre", "azeroth" }) do
	Say("-- 2.12.0 : page Juke-box (" .. style .. ")")
	J.Reset(style)
	NS.MusicCatalogReset(RAW, CATS, GROUPS)
	local frame = NS:ToggleJournal(true)
	NS.EXTRA_COMMANDS.juke(NS, "")
	local pane = frame and frame.juke
	Check("[J212] " .. style .. " : /qc juke ouvre la page", pane and frame.kind == "juke" and pane:IsShown() and frame.sections.juke ~= nil)
	Check("[J212] " .. style .. " : une tuile par vue, rangées remplies", pane and #pane.cats == #NS.JUKE_VIEWS
		and pane.rows[1]:IsShown() and pane.rows[1].track ~= nil and pane.rows[1].text:GetText() == pane.rows[1].track.name)
	Check("[J212] " .. style .. " : aucune erreur du carnet", next(NS.errors or {}) == nil)
	local first = pane.rows[2].track
	pane.rows[2]:Click()
	Check("[J212] " .. style .. " : clic sur une piste = elle joue, la page devient la file", NS.juke.id == first.id
		and NS.juke.queue and #NS.juke.queue == #pane.tracks and NS.juke.pos == 2)
	Check("[J212] " .. style .. " : « en cours » affiché", (pane.now:GetText() or ""):find(first.name, 1, true) ~= nil)
	pane.rows[3].fav:Click()
	Check("[J212] " .. style .. " : étoile = favori", NS:JukeIsFav(pane.rows[3].track.id))
	NS:JukeSelect("fav")
	Check("[J212] " .. style .. " : vue Favoris", #pane.tracks == 1 and pane.rows[1]:IsShown() and not pane.rows[2]:IsShown())
	NS:JukeSelect("list1")
	Check("[J212] " .. style .. " : liste vide expliquée", (pane.empty:GetText() or "") ~= "" and not pane.rows[1]:IsShown())
	NS:JukeSelect("zones")
	local before = frame.jukeOffset
	NS:ScrollJournal(-1)
	Check("[J212] " .. style .. " : molette", frame.jukeOffset == before + 3)
	J.music = "0"
	NS:RefreshJournal()
	Check("[J212] " .. style .. " : musique coupée signalée sur la page", pane.hintLine:GetText() == NS.L.JUKE_MUSIC_OFF)
	pane.stop:Click()
	Check("[J212] " .. style .. " : Arrêter", NS.juke.id == nil)
	if style == "azeroth" then
		local row = pane.rows[1]
		Check("[J212] azeroth : lignes claires, encres des rôles juke.*", row.azStyle == "light" and row.text.azRole == "juke.name"
			and row.detail.azRole == "juke.detail" and pane.now.azRole == "juke.now" and pane.hintLine.azRole == "juke.hint")
		Check("[J212] azeroth : tuiles des vues sombres, page sur parchemin", pane.cats[1].azStyle == "dark" and pane.azPage ~= nil)
		Check("[J212] azeroth : aucun rôle manquant", NS.carnetInkMisses == nil)
	end
	J.Done()
end

-- 6. Contraste : rôles juke.* recalculés -----------------------------------------------------------------
do
	Say("-- 2.12.0 : encres du Juke-box")
	local bad = {}
	for _, role in ipairs({ "juke.name", "juke.playing", "juke.missing", "juke.detail", "juke.now", "juke.hint" }) do
		local r = NS.AZEROTH_CONTRAST[role]
		local ratio = r and NS.AzerothContrast(INK[r[1]], r[2]) or 0
		if not r or ratio < r[3] then bad[#bad + 1] = role .. string.format(" %.2f", ratio) end
	end
	Check("[J212] rôles juke.* : 4,5:1 au moins sur le pire fond mesuré", #bad == 0, table.concat(bad, ", "))
	Check("[J212] juke.name / detail : mêmes fonds que les lignes de quêtes", NS.AZEROTH_CONTRAST["juke.name"][2] == NS.AZEROTH_CONTRAST["quest.name"][2]
		and NS.AZEROTH_CONTRAST["juke.detail"][2] == NS.AZEROTH_CONTRAST["quest.detail"][2])
	local fr, en = NS.JUKE_STRINGS.fr, NS.JUKE_STRINGS.en
	local missing = {}
	for key in pairs(fr) do if en[key] == nil then missing[#missing + 1] = key end end
	for key in pairs(en) do if fr[key] == nil then missing[#missing + 1] = key end end
	Check("[J212] textes FR/EN au complet", #missing == 0, table.concat(missing, ", "))
end
