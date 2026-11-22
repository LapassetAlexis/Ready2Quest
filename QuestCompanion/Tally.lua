-- Tally.lua -- compteurs de jeu (QuestCompanion 3.7.0, étape 1, chantier A)
--
-- Beaucoup d'événements ne laissaient aucune trace dans la sauvegarde
-- (spécimens relâchés, paillettes dépensées, aides employées, envies
-- comblées…). Ce fichier tient un magasin de compteurs et les relève par des
-- enveloppes posées sur les fonctions des modules de jeu. Aucun écran, aucun
-- haut fait : le moteur des hauts faits (Feats.lua) et la page de
-- statistiques les lisent par l'API ci-dessous.
--
-- Sauvegarde (créée à la première écriture) :
--   compte     : db.tally            = { v = 1, n = {}, m = {}, s = {}, week = { id, n = {} }, lastWeek }
--   personnage : CharData().tally    = { v = 1, n = {}, m = {}, s = {} }
--   n[clé] = nombre (compteur), m[clé] = maximum atteint, s[clé] = { [membre] = true }
--   (m._day : le dernier jour de jeu compté, AAAAMMJJ, interne au relevé de `days`)
--
-- API (scope : "account" par défaut, ou "char") :
--   ns:TallyAdd(key, delta, scope)        n[key] += delta (1 par défaut) ; rend le total
--   ns:TallyGet(key, scope)               n[key], 0 si absent
--   ns:TallyMax(key, value, scope)        m[key] = max(m[key], value) ; rend le maximum
--   ns:TallyBest(key, scope)              m[key], 0 si absent
--   ns:TallyMark(key, member, scope, cap) ajoute member à s[key] s'il reste de la place (cap 200) ; rend la taille
--   ns:TallySize(key, scope)              taille de l'ensemble
--   ns:TallyHas(key, member, scope)       appartenance
--   ns:TallyWeekAdd(key, delta)           compteur de la semaine (identifiant de ShopWeek : ns:WeeklyId) ;
--                                         bascule vers lastWeek quand l'identifiant change
--   ns:TallyWeek(), ns:TallyLastWeek()    les deux tables ({ id, n }) ; lastWeek peut manquer
-- Chaque écriture appelle ns:FeatTouch("tally") (le moteur l'ignore tant qu'il
-- dort). Les compteurs, eux, ne dorment jamais.
--
-- Relevés : les enveloppes sont posées à ADDON_LOADED (une fois), quand tous
-- les fichiers du .toc sont chargés : plusieurs fonctions relevées viennent de
-- fichiers chargés après celui-ci (ShopWeek, ReserveTidy, Share,
-- SpecimenBond, Jukebox…). Une enveloppe rend exactement ce que rend la
-- fonction relevée, après elle, et ne compte jamais une action refusée.
-- Une seule ligne hors de ce fichier : les partenaires d'échange
-- (CaptureTrades.lua, Commit : le nom complet de l'autre n'est ni dans les
-- arguments ni dans le retour d'une fonction publique).
local ADDON, ns = ...
if ns.blocked then return end

local A, CH = "account", "char"

-- ---------------------------------------------------------------------------
-- Réglages
-- ---------------------------------------------------------------------------
ns.TALLY_SET_CAP = 200          -- taille d'un ensemble par défaut
ns.TALLY_TICK = 60              -- s : l'horloge d'une minute
ns.TALLY_CLOSE_CALL = 10        -- s après une survie de justesse : closeCall
ns.TALLY_SMALL_PLAYER = 60      -- niveau du joueur pour smallGame
ns.TALLY_SMALL_LEVEL = 5        -- niveau de la créature (ou moins) pour smallGame
ns.TALLY_PARTNER_MIN = 10       -- minutes emmenée pour compter une créature (partners)
ns.TALLY_JUKE_HEARD = 30        -- s d'écoute d'un morceau (jukeHeard)
-- Morceaux du Voile d'hiver (FileDataID = true) : le catalogue du juke-box
-- (MusicData.lua) n'en a aucun ; tant que la liste est vide, winterSong ne
-- bouge pas
ns.JUKE_WINTER_TRACKS = ns.JUKE_WINTER_TRACKS or {}

local function G(name) return rawget(_G, name) end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function Plain(value) return ns.Plain and ns.Plain(value) or value end
local function Now() return (ns.Now and ns.Now()) or 0 end

-- ---------------------------------------------------------------------------
-- Magasin
-- ---------------------------------------------------------------------------
local function Scope(scope) return scope == CH and CH or A end

local function Store(self, scope)
	local root
	if Scope(scope) == CH then root = self:CharData() else root = self:DB() end
	local t = root.tally
	if type(t) ~= "table" then t = {}; root.tally = t end
	if t.v == nil then t.v = 1 end
	if type(t.n) ~= "table" then t.n = {} end
	if type(t.m) ~= "table" then t.m = {} end
	if type(t.s) ~= "table" then t.s = {} end
	return t
end

local function Touch(self)
	if type(self.FeatTouch) == "function" then pcall(self.FeatTouch, self, "tally") end
end

-- taille des ensembles, gardée à part (la sauvegarde garde { [membre] = true }) :
-- comptée une fois par ensemble, puis tenue à jour (écriture en O(1))
local sizes = setmetatable({}, { __mode = "k" })
local function SetSize(set)
	local size = sizes[set]
	if size then return size end
	size = 0
	for _ in pairs(set) do size = size + 1 end
	sizes[set] = size
	return size
end

local function Number(value) return tonumber(value) or 0 end

function ns:TallyAdd(key, delta, scope)
	if key == nil then return 0 end
	local n = Store(self, scope).n
	n[key] = math.max(0, Number(n[key]) + (tonumber(delta) or 1))
	Touch(self)
	return n[key]
end

function ns:TallyGet(key, scope)
	if key == nil then return 0 end
	return Number(Store(self, scope).n[key])
end

function ns:TallyMax(key, value, scope)
	if key == nil then return 0 end
	local m = Store(self, scope).m
	local best, v = Number(m[key]), tonumber(value)
	if v and v > best then
		m[key], best = v, v
		Touch(self)
	end
	return best
end

function ns:TallyBest(key, scope)
	if key == nil then return 0 end
	return Number(Store(self, scope).m[key])
end

function ns:TallyMark(key, member, scope, cap)
	if key == nil then return 0 end
	local s = Store(self, scope).s
	local set = s[key]
	if type(set) ~= "table" then set = {}; s[key] = set end
	local size = SetSize(set)
	if member == nil or set[member] then return size end
	if size >= (tonumber(cap) or ns.TALLY_SET_CAP) then return size end
	set[member] = true
	sizes[set] = size + 1
	Touch(self)
	return size + 1
end

function ns:TallySize(key, scope)
	if key == nil then return 0 end
	local set = Store(self, scope).s[key]
	return type(set) == "table" and SetSize(set) or 0
end

function ns:TallyHas(key, member, scope)
	if key == nil or member == nil then return false end
	local set = Store(self, scope).s[key]
	return type(set) == "table" and set[member] == true
end

-- La semaine (au compte) : identifiant de ShopWeek.lua (ns:WeeklyId, Weekly.lua)
local function WeekId(self)
	local id = self.WeeklyId and Call(self.WeeklyId, self)
	return id ~= nil and tostring(id) or "?"
end
local function Week(self)
	local store = Store(self, A)
	local id = WeekId(self)
	local week = store.week
	if type(week) ~= "table" then
		week = { id = id, n = {} }
		store.week = week
	elseif week.id ~= id then
		store.lastWeek = week
		week = { id = id, n = {} }
		store.week = week
	end
	if type(week.n) ~= "table" then week.n = {} end
	return week, store
end

function ns:TallyWeekAdd(key, delta)
	if key == nil then return 0 end
	local week = Week(self)
	week.n[key] = math.max(0, Number(week.n[key]) + (tonumber(delta) or 1))
	Touch(self)
	return week.n[key]
end

function ns:TallyWeek() return (Week(self)) end
function ns:TallyLastWeek()
	local _, store = Week(self)
	return type(store.lastWeek) == "table" and store.lastWeek or nil
end

-- une série remise à zéro (captureStreak à l'échec)
local function Reset(self, key, scope)
	local n = Store(self, scope).n
	if Number(n[key]) ~= 0 then
		n[key] = 0
		Touch(self)
	end
end

-- ---------------------------------------------------------------------------
-- Relevés
-- ---------------------------------------------------------------------------
-- after(self, pre, args, retour1, retour2, …) : après la fonction relevée,
-- sous pcall ; pre = ce qu'a rendu before(self, …) avant elle. Les retours
-- passent tels quels (tous).
local function Done(self, name, after, pre, args, ...)
	local ok, err = pcall(after, self, pre, args, ...)
	if not ok and self.RecordError then self:RecordError("tally:" .. name, err) end
	return ...
end

local function Wrap(name, after, before)
	local base = ns[name]
	if type(base) ~= "function" then return false end
	ns[name] = function(self, ...)
		local pre
		if before then
			local ok, value = pcall(before, self, ...)
			if ok then pre = value end
		end
		return Done(self, name, after, pre, { ... }, base(self, ...))
	end
	return true
end

local RARE = { rare = true, rareelite = true }
local survivedAt          -- ns.Now() du dernier cri de survie de justesse

local function InGroup()
	if Plain(Call(G("IsInGroup"))) == true then return true end
	return (tonumber(Plain(Call(G("GetNumGroupMembers")))) or 0) > 1
end

local function RareSize(size)
	local def = ns.SPECIMEN_SIZE_BY_ID and ns.SPECIMEN_SIZE_BY_ID[size or ""]
	return type(def) == "table" and def.rare == true
end

local function Radiant(self)
	return self.CompanionRadiant ~= nil and Call(self.CompanionRadiant, self) == true
end
local function RadiantEdge(self, before)
	if not before and Radiant(self) then self:TallyAdd("radiant", 1, CH) end
end

-- jukeHeard / winterSong : le morceau qui joue encore 30 s après son départ
local heard = {}
local function JukeHeard()
	local juke = ns.juke
	if type(juke) ~= "table" or juke.id == nil or juke.id ~= heard.id or juke.token ~= heard.token then return end
	ns:TallyMark("jukeHeard", juke.id, A, 500)
	if ns.JUKE_WINTER_TRACKS[juke.id] and ns.WinterVeilSeason and Call(ns.WinterVeilSeason, ns) then
		ns:TallyAdd("winterSong", 1, A)
	end
end

local hooked = false
function ns:TallyHook()
	if hooked then return false end
	hooked = true

	-- Capture : le verdict d'un lancer (lancer seul, volée, express)
	Wrap("CaptureResolve", function(self, _, args)
		local rolling = args[1]
		if type(rolling) ~= "table" then return end
		local target = type(rolling.target) == "table" and rolling.target or {}
		if not rolling.success then
			self:TallyAdd("captureFail", 1, A)
			Reset(self, "captureStreak", A)
			if target.class == "worldboss" then self:TallyAdd("bossFail", 1, A) end
			return
		end
		self:TallyMax("captureStreak", self:TallyAdd("captureStreak", 1, A), A)
		if target.hunt or (self.HuntActive and Call(self.HuntActive, self)) then self:TallyAdd("captureHunt", 1, A) end
		if InGroup() then self:TallyAdd("captureGroup", 1, A) end
		local aid = rolling.aid
		if aid then
			self:TallyAdd("captureAided", 1, A)
			if aid == "sifflet" then self:TallyAdd("captureWhistle", 1, A) end
		elseif RARE[target.class or ""] then
			self:TallyAdd("rareNoAid", 1, A)
		end
		local mine = tonumber(Plain(Call(G("UnitLevel"), "player")))
		local level = tonumber(Plain(target.level))
		if mine and mine >= ns.TALLY_SMALL_PLAYER and level and level > 0 and level <= ns.TALLY_SMALL_LEVEL then
			self:TallyAdd("smallGame", 1, A)
		end
		if survivedAt then
			local now = Now()
			if now >= survivedAt and now - survivedAt <= ns.TALLY_CLOSE_CALL then self:TallyAdd("closeCall", 1, A) end
		end
	end)
	-- Le cri de survie de justesse (CompanionShouts.lua) : l'heure (avant le
	-- cri, sans rien allouer : la fonction est appelée souvent)
	local shout = ns.CompanionShout
	if type(shout) == "function" then
		function ns:CompanionShout(pool, ...)
			if pool == "SHOUT_SURVIVED" then survivedAt = Now() end
			return shout(self, pool, ...)
		end
	end
	-- Le spécimen d'une capture (pas d'un échange) : étoiles, taille, brillante
	Wrap("SpecimenAdd", function(self, _, args, id)
		local spec = args[1]
		if id == nil or type(spec) ~= "table" or (spec.origin ~= nil and spec.origin ~= "capture") then return end
		local new = self:SpecimenGet(id)
		if type(new) ~= "table" or not RareSize(new.size) then return end
		local three = Number(new.stars) >= 3
		if three then self:TallyAdd("contest", 1, A) end
		if new.shiny then
			self:TallyAdd("shinyRareSize", 1, A)
			if three then self:TallyAdd("unfindable", 1, A) end
		end
	end)
	-- Fin d'une volée « Tout capturer »
	Wrap("CaptureBatchFlush", function(self, _, args)
		local batch = args[1]
		local got = type(batch) == "table" and Number(batch.got) or 0
		if got > 0 then self:TallyMax("batch", got, A) end
	end)
	-- Le mode chasse lancé (pas une chasse déjà en cours)
	Wrap("HuntStart", function(self, was, _, ok)
		if ok and not was then self:TallyAdd("huntStart", 1, A) end
	end, function(self) return self.HuntActive ~= nil and self:HuntActive() end)
	-- Aides dépensées
	Wrap("CaptureSpend", function(self, _, args, ok)
		if ok ~= true or args[1] == nil then return end
		self:TallyAdd("aidUsed", 1, A)
		self:TallyAdd("aidUsed:" .. tostring(args[1]), 1, A)
	end)
	-- Échoppe
	Wrap("ShopBuy", function(self, _, args, ok)
		if ok ~= true then return end
		self:TallyAdd("shopBuy", 1, A)
		local item = self.ShopItem and self:ShopItem(args[1])
		if type(item) == "table" and item.kind == "aid" then self:TallyAdd("aidBought", 1, A) end
	end)
	-- Brillante trouvée (abattue) : la série de chasse de l'espèce
	Wrap("ShinyKill", function(self, _, args)
		local info = args[2]
		if type(info) ~= "table" or info.npcID == nil or not ns.ShinySpeciesKills then return end
		local cap = tonumber(ns.SHINY_CHAIN_KILLS) or 50
		self:TallyMax("shinyChain", math.min(cap, Number(ns.ShinySpeciesKills(self, info.npcID))), A)
	end)
	-- Relâcher : un par un, puis le plus gros lot
	Wrap("SpecimenRelease", function(self, _, _, gain)
		if gain ~= nil and gain ~= false then self:TallyAdd("release", 1, A) end
	end)
	Wrap("ReserveTidyConfirm", function(self, _, _, count)
		if Number(count) > 0 then self:TallyMax("releaseBatch", Number(count), A) end
	end)
	-- Paillettes : dépensées et gagnées, par raison
	Wrap("PaillettesSpend", function(self, _, args, ok)
		local n = math.max(0, math.floor(Number(args[1])))
		if ok ~= true or n <= 0 then return end
		self:TallyAdd("glitterSpent", n, A)
		self:TallyAdd("glitterSpent:" .. tostring(args[2] or "?"), n, A)
	end)
	Wrap("PaillettesAdd", function(self, _, args)
		local n = math.max(0, math.floor(Number(args[1])))
		if n > 0 then self:TallyAdd("glitter:" .. tostring(args[2] or "?"), n, A) end
	end)
	-- Commandes de la semaine
	Wrap("ShopOrderDeliver", function(self, _, _, ok)
		if ok ~= true then return end
		self:TallyAdd("orderDone", 1, A)
		-- la troisième livrée : la semaine est pleine (une seule fois : plus rien à livrer)
		if self.ShopOrdersAllDone and self:ShopOrdersAllDone() then self:TallyAdd("orderWeek", 1, A) end
	end)
	Wrap("ShopOrdersReroll", function(self, _, _, ok)
		if ok == true then self:TallyAdd("orderReroll", 1, A) end
	end)
	-- Points de lien
	Wrap("SpecimenBondAdd", function(self, _, _, gain)
		if Number(gain) > 0 then self:TallyAdd("bondPoints", Number(gain), A) end
	end)
	-- Partage envoyé dans un canal (pas une copie, pas un texte laissé dans la saisie)
	Wrap("ShareSend", function(self, _, args, ok, why)
		local channel = args[2]
		if ok ~= true or why ~= nil or channel == nil or channel == "COPY" then return end
		self:TallyAdd("share", 1, A)
		self:TallyAdd("share:" .. tostring(channel), 1, A)
	end)
	-- Exploit de guilde envoyé
	Wrap("GuildFeatsFlush", function(self, _, _, sent)
		if sent == true then self:TallyAdd("guildSent", 1, A) end
	end)
	-- Un détenteur de QuestCompanion noté (clé de joueur ; jamais soi-même)
	Wrap("TrainerMarkHolder", function(self, _, args)
		local key = self.TrainerKey and self:TrainerKey(args[1])
		if key and self.TrainerHolders and self:TrainerHolders()[key] then self:TallyMark("holders", key, A, 200) end
	end)
	-- Juke-box : le morceau qui joue
	Wrap("JukePlay", function(self, _, _, ok)
		if ok ~= true or type(ns.juke) ~= "table" then return end
		heard.id, heard.token = ns.juke.id, ns.juke.token
		if ns.Cancel then ns.Cancel("tally:juke") end
		if ns.Soon then ns.Soon("tally:juke", ns.TALLY_JUKE_HEARD, JukeHeard) end
	end)

	-- Compagnon (par personnage)
	Wrap("CompanionWishMet", function(self) self:TallyAdd("wish", 1, CH) end)
	Wrap("CompanionGrant", function(self, before, _, ok)
		if ok ~= true then return end
		self:TallyAdd("state", 1, CH)
		RadiantEdge(self, before)
	end, Radiant)
	Wrap("CompanionWake", function(self, before, _, ok)
		if ok == true then RadiantEdge(self, before) end
	end, Radiant)
	Wrap("TreatGive", function(self, _, args, ok)
		local kind = args[1]
		if ok ~= true or kind == nil then return end
		self:TallyAdd("treat", 1, CH)
		self:TallyAdd("treat:" .. tostring(kind), 1, CH)
		self:TallyMark("treatKinds", kind, CH, 5)
	end)
	Wrap("MissionGrant", function(self, _, args)
		if args[1] == "allWeekly" then self:TallyAdd("weeklyAll", 1, CH) end
	end)
	-- Blague entendue : au repos ou demandée (/qc blague), dite pour de bon
	-- (sans rien allouer : chaque bulle passe par ici)
	local say = ns.CompanionSay
	if type(say) == "function" then
		local function Said(self, pool, said, ...)
			if pool == "JOKE" and said == true then pcall(self.TallyAdd, self, "joke", 1, CH) end
			return said, ...
		end
		function ns:CompanionSay(pool, ...)
			return Said(self, pool, say(self, pool, ...))
		end
	end
	-- Réveillé d'une caresse pendant sa somnolence (hors tutoriel)
	Wrap("CompanionPet", function(self, sleepy, _, done)
		if done and sleepy then self:TallyAdd("wake", 1, CH) end
	end, function(self)
		if self.CompanionTutorialActive and Call(self.CompanionTutorialActive, self) then return false end
		return self.CompanionData ~= nil and self:CompanionData().sleepy and true or false
	end)
	return true
end

-- ---------------------------------------------------------------------------
-- L'horloge d'une minute : Rayonnant, créatures emmenées, jours de jeu,
-- compagnons de saison
-- ---------------------------------------------------------------------------
local partnerMinutes = {}   -- [npc] = minutes emmenée pendant cette session

local function Today()
	local date = G("date") or (os and os.date)
	return tonumber(Call(date, "%Y%m%d"))
end

function ns:TallyMinute()
	if not self.savedVariablesLoaded then return false end
	local on = self.CompanionOn ~= nil and self.CompanionOn() and self:DB().companionShow ~= false
	if on and Radiant(self) then self:TallyAdd("radiantMin", 1, CH) end
	local winter = on and self.CompanionWinterKey and Call(self.CompanionWinterKey, self) or nil
	if winter then self:TallyMark("winterMates", winter, A, 3) end
	if on and not winter and self.CompanionData then
		local look = self:CompanionData().appearance
		local npc = type(look) == "string" and tonumber(look:match("^cap:(%d+)"))
		if npc and not self:TallyHas("partners", npc, CH) then
			partnerMinutes[npc] = (partnerMinutes[npc] or 0) + 1
			if partnerMinutes[npc] >= ns.TALLY_PARTNER_MIN then self:TallyMark("partners", npc, CH, 200) end
		end
	end
	local today = Today()
	if today and today > self:TallyBest("_day", CH) then
		self:TallyMax("_day", today, CH)
		self:TallyAdd("days", 1, CH)
	end
	return true
end
function ns.TallyPartnersForget() for npc in pairs(partnerMinutes) do partnerMinutes[npc] = nil end end

ns.Every("tally:minute", ns.TALLY_TICK, function()
	local ok, err = pcall(ns.TallyMinute, ns)
	if not ok and ns.RecordError then ns:RecordError("tally:minute", err) end
end)

-- Les enveloppes : une fois, quand la sauvegarde est lue (tous les fichiers chargés)
do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and frame then
		frame:RegisterEvent("ADDON_LOADED")
		frame:SetScript("OnEvent", function(f, _, name)
			if name ~= ADDON then return end
			if f.UnregisterEvent then f:UnregisterEvent("ADDON_LOADED") end
			local done, err = pcall(ns.TallyHook, ns)
			if not done and ns.RecordError then ns:RecordError("tally:hook", err) end
		end)
		ns.tallyFrame = frame
	end
end

if ns.Mark then ns.Mark("Tally") end
