-- Portrait d'une capture (QuestCompanion 3.1.0, retour en jeu) : « Capturé !
-- Grande tarentule » montrait un loup. La sonde des unités lisait
-- GetDisplayInfo juste après SetUnit : le modèle pas encore chargé, c'était
-- celui d'avant (le loup), gardé sous la tarentule pour toujours. Ici :
-- lecture immédiate seulement si le modèle a changé, une demande à la fois
-- (réponse tardive d'une demande abandonnée ignorée), purge unique des
-- sauvegardes d'avant, re-vérification d'une espèce revue vivante, le
-- candidat de capture qui porte l'apparence lue sur l'unité, et le cadrage
-- automatique qui croit le modèle chargé plutôt qu'une valeur apprise.
local Check, Say, ResetWorld, NS, Mock = T.Check, T.Say, T.ResetWorld, T.QNS, T.Mock

local GLOBALS = { "InCombatLockdown", "SetPortraitTextureFromCreatureDisplayID" }
local saved = {}
for _, name in ipairs(GLOBALS) do saved[name] = rawget(_G, name) end

-- Les unités du monde simulé : un loup (pnj 100, apparence 500), une
-- tarentule (200 → 600), un sanglier (300 → 700)
local UNITS = {
	wolf = { npc = 100, display = 500 }, spider = { npc = 200, display = 600 }, boar = { npc = 300, display = 700 },
}
local CREATURES = { [100] = 500, [200] = 600, [300] = 700 }

-- Une sonde comme celle du client : un modèle déjà en cache est là tout de
-- suite ; sinon GetDisplayInfo rend encore L'ANCIEN modèle (même après
-- ClearModel : le pire cas) jusqu'au chargement (probe:Load()), qui envoie
-- OnModelLoaded.
local function FakeProbe(cached)
	local p = { scripts = {}, shown = nil, pending = nil, asked = {} }
	p.cached = cached or {}
	function p:SetSize() end
	function p:SetPoint() end
	function p:SetAlpha() end
	function p:SetScript(kind, fn) self.scripts[kind] = fn end
	function p:ClearModel() end
	local function Ask(self, display, key)
		self.asked[#self.asked + 1] = key
		if self.cached[key] then self.shown, self.pending = display, nil else self.pending = display end
	end
	function p:SetUnit(unit) Ask(self, UNITS[unit].display, unit) end
	function p:SetCreature(npc) Ask(self, CREATURES[npc], npc) end
	function p:GetDisplayInfo() return self.shown or 0 end
	function p:Load()
		if self.pending then self.shown, self.pending = self.pending, nil end
		if self.scripts.OnModelLoaded then self.scripts.OnModelLoaded(self) end
	end
	return p
end

local function Fresh()
	ResetWorld()
	NS:DB().capture = nil
	NS:CaptureAccount().display = {}
	NS:CaptureAccount().displayRev = NS.MODEL_DISPLAY_REV
	NS.modelLiveDisplay, NS.modelLearnTries = {}, {}   -- relues sur ns par Companion.lua
	NS.modelLearnAt = nil
	_G.InCombatLockdown = function() return false end
end
-- La sonde est créée par l'add-on lui-même (CreateFrame simulé) : il y pose
-- son OnModelLoaded comme en jeu
local function UseProbe(probe)
	local create = _G.CreateFrame
	_G.CreateFrame = function(kind, ...)
		if kind == "PlayerModel" then return probe end
		return create(kind, ...)
	end
	NS.modelLearnProbe, NS.modelLearnCreatureProbe = nil, nil
	return function() _G.CreateFrame = create end
end
local TIMEOUT, TRIES = NS.MODEL_LEARN_TIMEOUT or 5, NS.MODEL_LEARN_TRIES or 3
local function Book() return NS:CaptureAccount().display end
local function Later(seconds) Mock.now = Mock.now + seconds end

-- 1. La cause : deux espèces, la seconde pas encore chargée ----------------------------------------
do
	Say("-- portrait : la tarentule ne prend plus l'apparence du loup")
	Fresh()
	local probe = FakeProbe({ wolf = true })
	local restore = UseProbe(probe)
	local wolf = NS:ModelLearnDisplay("wolf", 100)
	Later(NS.MODEL_LEARN_GAP)
	local now = NS:ModelLearnDisplay("spider", 200)       -- pas en cache : GetDisplayInfo dit encore 500
	local wrongBefore = Book()[200]
	probe:Load()
	local painted
	_G.SetPortraitTextureFromCreatureDisplayID = function(_, id) painted = id end
	local tex = UIParent:CreateTexture()
	local kind = NS:CreaturePortrait(tex, { npcID = 200, type = "Bête" })
	Check("[PORTRAIT] sonde des unités : jamais l'ancien modèle sous le nouveau pnj ; la réponse au chargement",
		wolf == 500 and now == nil and wrongBefore == nil and Book()[100] == 500 and Book()[200] == 600
			and kind == "portrait" and painted == 600,
		string.format("loup=%s, tout de suite=%s, avant chargement=%s, après=%s, peint=%s",
			tostring(wolf), tostring(now), tostring(wrongBefore), tostring(Book()[200]), tostring(painted)))
	restore()
	NS.modelLearnProbe = nil
end

-- 2. Une demande à la fois ; la réponse tardive d'une demande abandonnée ignorée --------------------
do
	Say("-- portrait : demandes identifiées")
	Fresh()
	local probe = FakeProbe({ wolf = true, boar = true })
	local restore = UseProbe(probe)
	NS:ModelLearnDisplay("wolf", 100)
	Later(NS.MODEL_LEARN_GAP)
	NS:ModelLearnDisplay("spider", 200)                   -- en attente de chargement
	Later(NS.MODEL_LEARN_GAP)
	local busy = NS:ModelLearnDisplay("boar", 300) == nil and probe.asked[#probe.asked] == "spider"
	Later(TIMEOUT)
	local boar = NS:ModelLearnDisplay("boar", 300)        -- la tarentule abandonnée, le sanglier lu
	-- la tarentule arrive enfin : plus aucune demande ne l'attend
	probe.shown = 600
	probe:Load()
	Check("[PORTRAIT] une demande à la fois ; abandonnée après le délai, sa réponse tardive n'écrit rien",
		busy and boar == 700 and Book()[300] == 700 and Book()[200] == nil and Book()[100] == 500,
		string.format("demandes=%s 200=%s 300=%s", table.concat(probe.asked, ","), tostring(Book()[200]), tostring(Book()[300])))
	restore()
	NS.modelLearnProbe = nil
end

-- 3. Sonde des créatures : la suivante attend la réponse de la précédente -------------------------
do
	Say("-- portrait : sonde des créatures")
	Fresh()
	local probe = FakeProbe({ [100] = true })
	local restore = UseProbe(probe)
	NS.modelLearnCreatureAt, NS.modelLearnPending = nil, nil
	local timer = _G.C_Timer
	_G.C_Timer = { After = function() end }
	NS:ModelLearnCreatures({ 100, 200, 300 })            -- 100 tout de suite
	Later(NS.MODEL_LEARN_CREATURE_GAP)
	NS:ModelLearnPump()                                  -- 200 demandée, pas en cache
	local stale = Book()[200]                            -- GetDisplayInfo dit encore 500
	Later(NS.MODEL_LEARN_CREATURE_GAP)
	local started = NS:ModelLearnPump()                  -- 200 sans réponse : 300 attend
	probe:Load()
	Later(NS.MODEL_LEARN_CREATURE_GAP)
	probe.cached[300] = true
	local next = NS:ModelLearnPump()
	Check("[PORTRAIT] sonde des créatures : une demande à la fois, jamais l'ancien modèle",
		Book()[100] == 500 and stale == nil and started == nil and Book()[200] == 600 and next == 300 and Book()[300] == 700,
		string.format("100=%s 200(avant)=%s 200=%s lancée=%s suivante=%s 300=%s", tostring(Book()[100]), tostring(stale),
			tostring(Book()[200]), tostring(started), tostring(next), tostring(Book()[300])))
	_G.C_Timer = timer
	NS:ModelLearnStop()
	restore()
	NS.modelLearnCreatureProbe, NS.modelLearnCreatureAt, NS.modelLearnPending = nil, nil, nil
end

-- 4. Les sauvegardes déjà fausses : purge unique, re-vérification ---------------------------------
do
	Say("-- portrait : sauvegardes d'avant la correction")
	Fresh()
	NS:DB().capture = { creatures = {}, items = {}, display = { [200] = 500, [100] = 500 } }
	local dropped = NS.ModelDisplayMigrate and NS:ModelDisplayMigrate()
	local purged = next(NS:DB().capture.display) == nil and NS:DB().capture.displayRev == NS.MODEL_DISPLAY_REV
	NS:DB().capture.display[300] = 700
	local again = NS.ModelDisplayMigrate and NS:ModelDisplayMigrate()
	Check("[PORTRAIT] sauvegarde d'avant : la table des apparences vidée une fois (révision), pas ensuite",
		dropped == 2 and purged and again == 0 and NS:DB().capture.display[300] == 700,
		string.format("oubliées=%s, encore=%s", tostring(dropped), tostring(again)))

	-- à la lecture de la sauvegarde (ADDON_LOADED → ns:OnAddonLoaded)
	Fresh()
	NS:DB().capture = { creatures = {}, items = {}, display = { [200] = 500 } }
	NS:OnAddonLoaded()
	Check("[PORTRAIT] la purge se fait à la lecture de la sauvegarde",
		NS:DB().capture.display[200] == nil and NS:DB().capture.displayRev == NS.MODEL_DISPLAY_REV)

	-- une valeur fausse restée (révision à jour) : relue quand l'espèce est revue vivante
	Fresh()
	Book()[200] = 500
	local probe = FakeProbe({ spider = true })
	local restore = UseProbe(probe)
	local first = NS:ModelLearnDisplay("spider", 200)
	Later(NS.MODEL_LEARN_GAP)
	local n = #probe.asked
	local second = NS:ModelLearnDisplay("spider", 200)
	Check("[PORTRAIT] espèce connue revue vivante : relue une fois par session, la valeur vivante fait foi",
		first == 600 and Book()[200] == 600 and second == 600 and #probe.asked == n,
		string.format("1re=%s, gardée=%s, 2e=%s, demandes=%d", tostring(first), tostring(Book()[200]), tostring(second), #probe.asked))

	-- jamais chargée : au plus MODEL_LEARN_TRIES essais dans la session
	restore()
	Fresh()
	Book()[300] = 900
	probe = FakeProbe({})
	restore = UseProbe(probe)
	for _ = 1, TRIES + 3 do
		NS:ModelLearnDisplay("boar", 300)
		Later(TIMEOUT + NS.MODEL_LEARN_GAP)
	end
	_G.InCombatLockdown = function() return true end
	Later(TIMEOUT)
	NS.modelLearnTries[200] = nil
	local fight = NS:ModelLearnDisplay("spider", 200)
	Check("[PORTRAIT] re-vérification bornée (essais par session), jamais en combat",
		#probe.asked == TRIES and Book()[300] == 900 and fight == nil,
		string.format("demandes=%d", #probe.asked))
	restore()
	NS.modelLearnProbe = nil
end

-- 5. La capture : le portrait de la créature abattue ----------------------------------------------
do
	Say("-- portrait : le candidat porte l'apparence lue sur l'unité")
	Fresh()
	Book()[200] = 500                                      -- faux, pas encore revérifié
	local probe = FakeProbe({ spider = true })
	local restore = UseProbe(probe)
	local entry = { zoneID = 1, npcID = 200 }
	NS:ModelLearnDisplay("spider", 200, entry)
	restore()
	local rollQuality = NS.CaptureRollQuality
	NS.CaptureRollQuality = function() return 1 end
	local candidate = NS:CaptureOffer("Creature-0-1-1-1-200-00000000AA", entry)
	NS.CaptureRollQuality = rollQuality
	Book()[200] = 500                                      -- même si le compte se trompe encore
	local painted
	_G.SetPortraitTextureFromCreatureDisplayID = function(_, id) painted = id end
	local tex = UIParent:CreateTexture()
	NS:CreaturePortrait(tex, candidate or {})
	local fromCandidate = painted
	-- le bandeau qui ne garde que le pnj : l'apparence lue vivante dans la session
	painted = nil
	NS:CreaturePortrait(tex, { npcID = 200, type = "Bête" })
	Check("[PORTRAIT] « Capturé ! » : l'apparence lue sur l'unité vivante voyage avec le candidat (et la session)",
		entry.display == 600 and candidate ~= nil and candidate.liveDisplay == 600 and fromCandidate == 600 and painted == 600,
		string.format("fiche=%s, candidat=%s, peint=%s/%s", tostring(entry.display), tostring(candidate and candidate.liveDisplay),
			tostring(fromCandidate), tostring(painted)))
	-- une fiche d'un autre pnj ne reçoit rien
	Fresh()
	probe = FakeProbe({ spider = true })
	restore = UseProbe(probe)
	local other = { npcID = 100 }
	NS:ModelLearnDisplay("spider", 200, other)
	Check("[PORTRAIT] la fiche reçoit l'apparence seulement si c'est son pnj", other.display == nil and Book()[200] == 600)
	restore()
	NS.modelLearnProbe = nil
	NS:CaptureQueueClear()
end

-- 6. Cadrage automatique : le modèle chargé passe avant la valeur apprise -------------------------
do
	Say("-- portrait : cadrage automatique")
	Fresh()
	local fitScale = NS.CompanionFitScale
	NS.CompanionFitScale = function(_, id) return ({ [500] = 0.5, [600] = 2 })[id] end
	local m = { scripts = {}, shownDisplay = nil }
	function m:SetCreature() self.shownDisplay = nil end
	function m:GetDisplayInfo() return self.shownDisplay or 0 end
	function m:SetModelScale(v) self.scale = v end
	function m:SetCamDistanceScale() end
	function m:SetPortraitZoom() end
	function m:SetPosition() end
	function m:Show() end
	function m:Hide() end
	function m:ClearModel() end
	function m:HookScript(kind, fn) self.scripts[kind] = fn end
	NS.ShowModel(m, { npc = 200, fit = true, fitDisplay = 500 }, "tile")
	local before = m.fitDisplay
	m.shownDisplay = 600
	m.scripts.OnModelLoaded(m)
	Check("[PORTRAIT] cadrage automatique : l'apparence du modèle chargé passe avant celle apprise",
		before == 500 and m.fitDisplay == 600 and m.fitScale == 2,
		string.format("avant=%s, chargé=%s", tostring(before), tostring(m.fitDisplay)))
	NS.CompanionFitScale = fitScale
end

for _, name in ipairs(GLOBALS) do _G[name] = saved[name] end
