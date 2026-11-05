-- Journal.lua -- module « Carnet de voyage » (v1.25.0)
--
-- Une collection de tampons, gagnés une seule fois par personnage, rien qu'en
-- jouant : pas de tirage, pas d'achat. Six sortes :
--   * zone      : première visite d'une zone (uiMapID de type « Zone ») ;
--   * subzone   : village ou hub de la base livrée (Hubs.lua, villes et hubs
--                 de ta faction ou neutres ; pas les auberges, qui doubleraient
--                 le village qui les contient) ;
--   * capital   : capitale visitée, quelle que soit sa faction (entrer à
--                 Orgrimmar en Alliance, c'est un voyage qui mérite un tampon) ;
--   * dungeon   : donjon à 5 (DungeonData.lua via ns:DetectDungeon, repli sur
--                 GetInstanceInfo de type "party") ;
--   * rare      : ennemi rare tué APRÈS que toi ou ton groupe l'avez engagé ;
--   * level     : paliers 10, 20, … 60.
--
-- Règle du rare tué (et pourquoi) : le journal de combat annonce la mort de
-- TOUT ce qui meurt à portée, y compris le rare qu'un inconnu tue à 30 m.
-- On retient donc un rare quand on le VOIT (cible, survol, plaque de nom :
-- UnitClassification "rare" / "rareelite"), on note qu'il est ENGAGÉ dès que
-- toi, ton familier ou un membre du groupe lui inflige des dégâts (ou le
-- rate : un « raté » prouve aussi le combat), puis on tamponne à UNIT_DIED
-- (ou PARTY_KILL) seulement s'il était engagé. Rien de plus fin n'est fiable
-- en Classic : le « tap » d'un cadavre n'est plus lisible après la mort.
--
-- Contrats avec le module parallèle « Compagnon » :
--   ns:FireCallback("STAMP", { id, kind, name, new = true, level, date })
--   ns:JournalCounts() -> { zone, subzone, dungeon, rare, level, capital, total }
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local KINDS = { "zone", "subzone", "capital", "dungeon", "rare", "level" }
ns.JOURNAL_KINDS = KINDS
-- onglets de la fenêtre : les objectifs d'abord (ce qui reste à faire se lit
-- avant ce qui est fait), puis une page par sorte de tampon
local TABS = { "goals", "zone", "subzone", "capital", "dungeon", "rare", "level" }
ns.JOURNAL_TABS = TABS
local MILESTONES = { 10, 20, 30, 40, 50, 60 }
-- partagés avec JournalTracker.lua (objectif « prochain palier »)
ns.JOURNAL_MILESTONES = MILESTONES
local TOAST_SECONDS = 4
local TOAST_COLLAPSE = 3      -- à partir de 3 tampons en attente : un seul bandeau groupé
local RARE_MEMORY = 900       -- un rare vu et jamais engagé est oublié après 15 min
local RARE_ENGAGED_MEMORY = 1800 -- engagé puis laissé (fuite, évitement) : oublié après 30 min sans coup

-- ---------------------------------------------------------------------------
-- Chaînes, réglages, page d'options, module
-- ---------------------------------------------------------------------------
local FR = {
	OPT_PAGE_JOURNAL      = "Carnet de voyage",
	OPT_PAGE_JOURNAL_SUB  = "Des tampons gagnés en jouant : zones, villages, capitales, donjons, rares, paliers.",
	OPT_JRN_TOAST         = "Bandeau « nouveau tampon »",
	OPT_JRN_CHAT          = "Ligne dans le chat",
	OPT_ACTION_JOURNAL    = "Ouvrir le carnet",
	JRN_TITLE             = "Carnet de voyage",
	JRN_TOTAL             = "%d tampon(s)",
	JRN_TAB_zone          = "Zones",
	JRN_TAB_subzone       = "Villages",
	JRN_TAB_capital       = "Capitales",
	JRN_TAB_dungeon       = "Donjons",
	JRN_TAB_rare          = "Rares",
	JRN_TAB_level         = "Paliers",
	JRN_TAB_goals         = "Objectifs",
	JRN_GOALS_COUNT       = "Objectifs : %d",
	JRN_GOALS_EMPTY       = "Rien en vue pour l'instant : ton carnet est à jour.",
	JRN_GOALS_HINT        = "Clic droit : masquer ou remettre un objectif.",
	JRN_GOAL_HIDDEN       = "masqué",
	JRN_COUNT             = "%s : %d",
	JRN_COUNT_OF          = "%s : %d / %d",
	JRN_TO_DISCOVER       = "à découvrir",
	JRN_LEVEL_NAME        = "Niveau %d",
	JRN_LEVEL_SHORT       = "niv. %d",
	JRN_EMPTY             = "Aucun tampon ici pour l'instant. Pars à l'aventure !",
	JRN_TOAST_TITLE       = "Nouveau tampon",
	JRN_TOAST             = "Nouveau tampon : %s",
	JRN_TOAST_MANY        = "%d nouveaux tampons",
	JRN_CHAT              = "Nouveau tampon (%s) : %s.",
	JRN_OFF_HINT          = "Carnet coupé : plus aucun tampon ne se gagne (/qc module carnet on).",
	JRN_DATE_FORMAT       = "%d/%m/%Y",
	HELP_JOURNAL          = "/qc carnet -- ton carnet de voyage : les tampons gagnés en jouant",
}
local EN = {
	OPT_PAGE_JOURNAL      = "Travel journal",
	OPT_PAGE_JOURNAL_SUB  = "Stamps earned by playing: zones, villages, capitals, dungeons, rares, milestones.",
	OPT_JRN_TOAST         = "\"New stamp\" banner",
	OPT_JRN_CHAT          = "Chat line",
	OPT_ACTION_JOURNAL    = "Open the journal",
	JRN_TITLE             = "Travel journal",
	JRN_TOTAL             = "%d stamp(s)",
	JRN_TAB_zone          = "Zones",
	JRN_TAB_subzone       = "Villages",
	JRN_TAB_capital       = "Capitals",
	JRN_TAB_dungeon       = "Dungeons",
	JRN_TAB_rare          = "Rares",
	JRN_TAB_level         = "Milestones",
	JRN_TAB_goals         = "Goals",
	JRN_GOALS_COUNT       = "Goals: %d",
	JRN_GOALS_EMPTY       = "Nothing in sight for now: your journal is up to date.",
	JRN_GOALS_HINT        = "Right-click: hide or restore a goal.",
	JRN_GOAL_HIDDEN       = "hidden",
	JRN_COUNT             = "%s: %d",
	JRN_COUNT_OF          = "%s: %d / %d",
	JRN_TO_DISCOVER       = "to discover",
	JRN_LEVEL_NAME        = "Level %d",
	JRN_LEVEL_SHORT       = "lvl %d",
	JRN_EMPTY             = "No stamp here yet. Go explore!",
	JRN_TOAST_TITLE       = "New stamp",
	JRN_TOAST             = "New stamp: %s",
	JRN_TOAST_MANY        = "%d new stamps",
	JRN_CHAT              = "New stamp (%s): %s.",
	JRN_OFF_HINT          = "Journal off: no stamp can be earned (/qc module carnet on).",
	JRN_DATE_FORMAT       = "%Y-%m-%d",
	HELP_JOURNAL          = "/qc carnet -- your travel journal: stamps earned by playing",
}
ns.RegisterStrings(FR, EN)
-- exposées aux tests : chaque clé doit exister dans les deux langues
ns.JOURNAL_STRINGS = { fr = FR, en = EN }

ns.RegisterDefaults({
	journalToast   = true,
	journalChat    = false,   -- le bandeau suffit ; le chat est pour qui veut une trace
})

if ns.AddOptionPage then
	ns.AddOptionPage({
		id = "journal", title = "OPT_PAGE_JOURNAL", parent = "companion", group = "OPT_GROUP_MODULES",
		rows = {
			{ key = "journalToast", label = "OPT_JRN_TOAST", kind = "bool" },
			{ key = "journalChat",  label = "OPT_JRN_CHAT",  kind = "bool" },
			-- suivi à l'écran (JournalTracker.lua : chaînes, défauts, action)
			{ key = "journalTracker",       label = "OPT_JRN_TRACKER",        kind = "bool" },
			{ key = "journalTrackerCombat", label = "OPT_JRN_TRACKER_COMBAT", kind = "bool" },
			{ key = "journalTrackerReset",  label = "OPT_JRN_TRACKER_RESET",  kind = "action" },
		},
		-- bouton construit par Options.lua (L.OPT_ACTION_JOURNAL), action
		-- traitée par le relais de RunOptionAction plus bas
		actions = { "journal" },
	})
end

-- plus de module à part : « /qc module carnet » vise le Compagnon de route
-- (alias déclarés dans Companion.lua)

if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_JOURNAL")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Accès robustes au client
-- ---------------------------------------------------------------------------
local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if ok then return a, b, c, d, e, f, g, h end
	return nil
end

local function Level() return tonumber(Call("UnitLevel", "player")) end

local function Today()
	local text = Call("date", L.JRN_DATE_FORMAT)
	return type(text) == "string" and text or nil
end

local function InCombat()
	return Call("InCombatLockdown") == true or Call("UnitAffectingCombat", "player") == true
end

local function ModuleOn()
	local db = ns:DB()
	-- même interrupteur que le compagnon : c'est un seul module (v1.25.0)
	return db.enabled ~= false and db.companionEnabled ~= false
end

-- Les tampons vivent dans les données du personnage (ns:CharData, socle commun Libs/Socle/Store.lua) :
-- la sauvegarde est partagée par le compte, le carnet ne l'est pas.
function ns:JournalData()
	local char = self:CharData()
	if type(char.journal) ~= "table" then char.journal = {} end
	if type(char.journal.stamps) ~= "table" then char.journal.stamps = {} end
	return char.journal
end

function ns:JournalCounts()
	local counts = { total = 0 }
	for _, kind in ipairs(KINDS) do counts[kind] = 0 end
	for _, stamp in pairs(self:JournalData().stamps) do
		if counts[stamp.kind] then counts[stamp.kind] = counts[stamp.kind] + 1 end
		counts.total = counts.total + 1
	end
	return counts
end

function ns:HasStamp(id) return self:JournalData().stamps[id] ~= nil end

-- ---------------------------------------------------------------------------
-- Gain d'un tampon
-- ---------------------------------------------------------------------------
-- `silent` : tampon rattrapé (paliers déjà atteints à l'installation, ou
-- pendant que le module était coupé). Il entre au carnet, mais ce n'est pas
-- un gain du moment : ni bandeau, ni chat, ni STAMP pour le Compagnon.
function ns:JournalEarn(kind, key, name, silent)
	if not ModuleOn() or key == nil then return nil end
	local data = self:JournalData()
	local id = kind .. ":" .. tostring(key)
	if data.stamps[id] then return nil end
	local stamp = {
		id = id, kind = kind, name = tostring(name or key),
		date = Today(), at = tonumber(Call("time")) or 0, level = Level(),
	}
	if silent then stamp.retro = true end
	data.stamps[id] = stamp
	if not silent then
		-- une copie : le Compagnon ne doit pas pouvoir abîmer le carnet
		self:FireCallback("STAMP", { id = id, kind = kind, name = stamp.name, new = true,
			level = stamp.level, date = stamp.date })
		self:JournalNotify(stamp)
	end
	if self.journalFrame and self.journalFrame:IsShown() then self:RefreshJournal() end
	return stamp
end

-- ---------------------------------------------------------------------------
-- Lieux : zone, village / hub, capitale
-- ---------------------------------------------------------------------------
local ZONE_TYPE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3
local CONTINENT_TYPE = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2

-- Zone sous le joueur : la première carte de type « Zone » en remontant les
-- parents (une sous-carte de quartier ou de grotte remonte à sa zone). Un
-- client sans mapType : la carte elle-même. Jamais en instance.
function ns:JournalZone()
	if self:InInstance() then return nil end
	local mapID = self:CurrentMap()
	if not mapID then return nil end
	local typed = false
	for _, id in ipairs(self:MapChain(mapID)) do
		local info = self:MapInfo(id)
		local mapType = info and info.mapType
		if mapType ~= nil then typed = true end
		if mapType == ZONE_TYPE then return id, info.name end
		if mapType ~= nil and mapType <= CONTINENT_TYPE then break end
	end
	if typed then return nil end
	local info = self:MapInfo(mapID)
	local name = info and info.name
	if not name or name == "" then name = Call("GetRealZoneText") end
	return mapID, name
end

-- Groupes de la base livrée, un par nom traduit (Hurlevent a deux areaID sur
-- Forever : un seul tampon). Clé = plus petit areaID du groupe, stable d'une
-- session à l'autre. `exists` : le client connaît le lieu (un hub de Forever
-- n'a pas de nom sur Era) ; sans C_Map.GetAreaInfo, on garde tout.
local AREA_OF = {}
for areaID, entry in pairs(ns.HUBS or {}) do AREA_OF[entry] = areaID end

function ns:JournalHubGroups()
	local index = self:HubIndex()
	if self.journalGroups and self.journalGroupsFor == index then return self.journalGroups end
	local getInfo = C_Map and C_Map.GetAreaInfo
	local groups = {}
	for name, entries in pairs(index) do
		local group = { name = name, kind = nil, faction = nil, exists = type(getInfo) ~= "function" }
		for _, entry in ipairs(entries) do
			local areaID = AREA_OF[entry]
			if areaID and (not group.areaID or areaID < group.areaID) then group.areaID = areaID end
			if entry.kind == "capital" or not group.kind then group.kind = entry.kind end
			group.faction = group.faction or entry.faction
			if areaID and type(getInfo) == "function" then
				local ok, localized = pcall(getInfo, areaID)
				if ok and type(localized) == "string" and localized ~= "" then group.exists = true end
			end
		end
		if group.areaID then groups[name] = group end
	end
	self.journalGroups, self.journalGroupsFor = groups, index
	return groups
end

local function Friendly(group, faction)
	return group.faction == "N" or faction == nil or group.faction == faction
end

-- Villages et hubs comptés au carnet : ville ou hub, ami ou neutre
local function IsVillage(group, faction)
	return (group.kind == "town" or group.kind == "hub") and Friendly(group, faction)
end
-- même règle pour les objectifs du suivi : un village ennemi n'est pas un but
function ns:JournalIsVillage(group, faction) return IsVillage(group, faction) end

-- Une passe complète : appelée à l'entrée dans le monde et à chaque
-- changement de zone ou de sous-zone. Chaque tampon ne se gagne qu'une fois.
function ns:JournalScan()
	if not ModuleOn() then return end
	local mapID, zoneName = self:JournalZone()
	if mapID then self:JournalEarn("zone", mapID, zoneName) end

	if not self:InInstance() then
		local groups, faction = self:JournalHubGroups(), self:PlayerFaction()
		local subzone = self:CurrentSubZone()
		local zoneText = Call("GetRealZoneText") or Call("GetZoneText")
		for _, name in ipairs({ subzone or false, zoneText or false }) do
			local group = name and groups[name]
			if group then
				if group.kind == "capital" then
					self:JournalEarn("capital", group.areaID, name)
				elseif name == subzone and IsVillage(group, faction) then
					self:JournalEarn("subzone", group.areaID, name)
				end
			end
		end
	end

	self:JournalDungeon()
end

-- ---------------------------------------------------------------------------
-- Donjons
-- ---------------------------------------------------------------------------
function ns:JournalDungeon()
	if not self:InInstance() then return end
	local name, instanceType, _, _, _, _, _, instanceID = Call("GetInstanceInfo")
	if instanceType ~= "party" then return end
	local entry
	if self.DetectDungeon then
		local found, where = self:DetectDungeon()
		if where == "instance" then entry = found end
	end
	if entry and entry.key then
		local display = self.DungeonName and self:DungeonName(entry, name) or name or entry.name
		return self:JournalEarn("dungeon", entry.key, display)
	end
	-- donjon absent de la base (client de lancement de Forever) : on le
	-- tamponne quand même, par son numéro d'instance, sinon par son nom
	local key = tonumber(instanceID) and ("i" .. instanceID) or name
	if key and key ~= "" then return self:JournalEarn("dungeon", key, name or key) end
end

-- Donjons de la base (DungeonData.lua)
function ns:JournalDungeonList()
	local list = {}
	for key, entry in pairs(self.DUNGEONS or {}) do
		list[#list + 1] = { key = key, name = self.DungeonName and self:DungeonName(entry) or entry.name or key }
	end
	return list
end

-- ---------------------------------------------------------------------------
-- Paliers de niveau
-- ---------------------------------------------------------------------------
-- Rattrapage silencieux de tout palier déjà atteint (installation en cours de
-- route, module rallumé) ; seul un PLAYER_LEVEL_UP sur un palier se fête.
function ns:JournalLevels(newLevel)
	if not ModuleOn() then return end
	local level = tonumber(newLevel) or Level()
	if not level then return end
	for _, milestone in ipairs(MILESTONES) do
		if level >= milestone then
			local celebrate = newLevel ~= nil and level == milestone
			self:JournalEarn("level", milestone, self:F("JRN_LEVEL_NAME", milestone), not celebrate)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Rares
-- ---------------------------------------------------------------------------
ns.journalRares = {}

local RARE_CLASSES = { rare = true, rareelite = true }

local function NpcID(guid)
	return type(guid) == "string" and guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or nil
end

-- Un rare repéré (cible, survol, plaque de nom). Seules les créatures :
-- pas un joueur, pas un familier de joueur.
function ns:JournalSeeUnit(unit)
	if not ModuleOn() or type(unit) ~= "string" then return end
	if not RARE_CLASSES[Call("UnitClassification", unit) or ""] then return end
	if Call("UnitIsPlayer", unit) then return end
	self:JournalSeeRare(Call("UnitGUID", unit), Call("UnitName", unit))
end

-- Un rare repéré par son GUID (unité lue ci-dessus, ou vignette de la
-- minicarte, LiveRares.lua) : retenu pour compter sa mort s'il est engagé.
function ns:JournalSeeRare(guid, name)
	if not ModuleOn() then return end
	guid, name = ns.Plain(guid), ns.Plain(name)
	if type(guid) ~= "string" or not (guid:find("^Creature%-") or guid:find("^Vehicle%-")) then return end
	local now = ns.Now()
	local rare = self.journalRares[guid] or {}
	rare.name = name or rare.name
	rare.seen = now
	self.journalRares[guid] = rare
	-- ménage : un rare croisé sans combat ne reste pas en mémoire
	for other, entry in pairs(self.journalRares) do
		local memory = entry.engaged and RARE_ENGAGED_MEMORY or RARE_MEMORY
		if now - (entry.seen or now) > memory then self.journalRares[other] = nil end
	end
end

-- Source dans ton camp : toi, ton familier (affiliation MINE), ton groupe ou
-- ton raid. Bits COMBATLOG_OBJECT_AFFILIATION_MINE / PARTY / RAID = 0x1/0x2/0x4,
-- lus sans la bibliothèque `bit` (absente de certains environnements).
local function FromGroup(sourceGUID, sourceFlags)
	if sourceGUID and sourceGUID == Call("UnitGUID", "player") then return true end
	local flags = tonumber(sourceFlags)
	return flags ~= nil and flags % 8 > 0
end

-- Un rare tué par toi, compté par le bestiaire (journal de combat ou message
-- d'XP) : son tampon. Le seul chemin quand le journal de combat est muet.
function ns:JournalRareKilled(guid)
	local rare = guid and self.journalRares[guid]
	if not rare then return false end
	self.journalRares[guid] = nil
	if not ModuleOn() then return false end
	return self:JournalEarn("rare", NpcID(guid) or rare.name, rare.name) ~= nil
end

function ns:JournalCombat(subevent, sourceGUID, sourceFlags, destGUID)
	if type(subevent) ~= "string" or not destGUID then return end
	local rare = self.journalRares[destGUID]
	if not rare then return end
	if subevent == "UNIT_DIED" or subevent == "UNIT_DESTROYED" then
		self.journalRares[destGUID] = nil
		if rare.engaged and ModuleOn() then
			self:JournalEarn("rare", NpcID(destGUID) or rare.name, rare.name)
		end
		return
	end
	if FromGroup(sourceGUID, sourceFlags) then
		if subevent == "PARTY_KILL" then
			self.journalRares[destGUID] = nil
			if ModuleOn() then self:JournalEarn("rare", NpcID(destGUID) or rare.name, rare.name) end
		elseif subevent:find("_DAMAGE$") or subevent:find("_MISSED$") then
			rare.engaged, rare.seen = true, ns.Now()
		end
	end
end

-- ---------------------------------------------------------------------------
-- Annonce : bandeau discret et ligne de chat, jamais en combat
-- ---------------------------------------------------------------------------
ns.journalToasts, ns.journalChats = {}, {}

function ns:JournalKindLabel(kind) return L["JRN_TAB_" .. tostring(kind)] or tostring(kind) end

function ns:JournalNotify(stamp)
	local db = self:DB()
	if db.journalToast ~= false then table.insert(self.journalToasts, stamp) end
	if db.journalChat == true then table.insert(self.journalChats, stamp) end
	self:JournalFlush()
end

function ns:EnsureJournalToast()
	if self.journalToast then return self.journalToast end
	if not (Theme and Theme.CreateDiscreet) then return nil end
	local frame = Theme.CreateDiscreet(UIParent, 250, 38)
	if not frame then return nil end
	frame.diamond = Theme.CreateDiamond(frame, 12, false)
	frame.diamond:SetPoint("LEFT", frame, "LEFT", 10, 0)
	frame.diamond:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
	frame.title = frame:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, -5)
	frame.title:SetTextColor(Theme.BLUE[1], Theme.BLUE[2], Theme.BLUE[3])
	frame.text = Theme.CreateTitle(frame, 13)
	frame.text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 30, 5)
	frame.text:SetWidth(210)
	frame.text:SetJustifyH("LEFT")
	frame.text:SetWordWrap(false)
	if self.RestorePoint then self:RestorePoint(frame, "journalToastPoint", { point = "TOP", x = 0, y = -190 }) end
	frame:Hide()
	self.journalToast = frame
	return frame
end

function ns:ShowNextJournalToast()
	local queue = self.journalToasts
	if #queue == 0 then return nil end
	local frame = self:EnsureJournalToast()
	if not frame then self.journalToasts = {}; return nil end
	if #queue >= TOAST_COLLAPSE then
		-- une rafale (première connexion) : un bandeau, pas six d'affilée
		frame.title:SetText(L.JRN_TOAST_TITLE)
		frame.text:SetText(self:F("JRN_TOAST_MANY", #queue))
		frame.message = self:F("JRN_TOAST_MANY", #queue)
		self.journalToasts = {}
	else
		local stamp = table.remove(queue, 1)
		frame.title:SetText(L.JRN_TOAST_TITLE .. Theme.T_GREY .. "  " .. self:JournalKindLabel(stamp.kind) .. "|r")
		frame.text:SetText(stamp.name)
		frame.message = self:F("JRN_TOAST", stamp.name)
	end
	frame:Show()
	if Theme.FadeIn then Theme.FadeIn(frame, 0.2) end
	self.journalToastHideAt = ns.Now() + TOAST_SECONDS
	return frame
end

-- File d'attente : rien ne s'affiche en combat ; tout part à la sortie
-- (PLAYER_REGEN_ENABLED), puis un bandeau à la fois.
function ns:JournalFlush()
	if InCombat() then return end
	for _, stamp in ipairs(self.journalChats) do
		self:Print(self:F("JRN_CHAT", self:JournalKindLabel(stamp.kind), stamp.name))
	end
	self.journalChats = {}
	if not self.journalToastHideAt then self:ShowNextJournalToast() end
end

function ns:UpdateJournalToast(now)
	if self.journalToastHideAt and now >= self.journalToastHideAt then
		self.journalToastHideAt = nil
		if self.journalToast then self.journalToast:Hide() end
	end
	if not self.journalToastHideAt and #self.journalToasts > 0 and not InCombat() then
		self:ShowNextJournalToast()
	end
end

-- ---------------------------------------------------------------------------
-- Fenêtre du carnet
-- ---------------------------------------------------------------------------
-- 520 de large : sept onglets (Objectifs + six sortes) restent lisibles
local WIDTH, HEIGHT = 520, 404
local LINES, LINE_H = 10, 22
local KIND_COLOR = {
	zone = Theme.GOLD, subzone = Theme.BLUE, capital = Theme.PARCHMENT,
	dungeon = Theme.BLUE, rare = Theme.RED, level = Theme.GREEN,
}

-- Totaux « à découvrir » et lieux encore vierges, selon les données connues :
-- villages / hubs amis (Hubs.lua), 6 capitales, donjons de ce client
-- (DungeonData.lua), 6 paliers. Zones et rares : pas de total fiable.
function ns:JournalMissing(kind)
	local stamps, missing = self:JournalData().stamps, {}
	if kind == "subzone" or kind == "capital" then
		local faction = self:PlayerFaction()
		for name, group in pairs(self:JournalHubGroups()) do
			local wanted = group.exists and ((kind == "capital" and group.kind == "capital")
				or (kind == "subzone" and IsVillage(group, faction)))
			if wanted and not stamps[kind .. ":" .. group.areaID] then missing[#missing + 1] = { name = name } end
		end
	elseif kind == "dungeon" then
		for _, entry in ipairs(self:JournalDungeonList()) do
			if not stamps["dungeon:" .. entry.key] then missing[#missing + 1] = { name = entry.name } end
		end
	elseif kind == "level" then
		for _, milestone in ipairs(MILESTONES) do
			if not stamps["level:" .. milestone] then
				missing[#missing + 1] = { name = self:F("JRN_LEVEL_NAME", milestone), order = milestone }
			end
		end
	else
		return nil
	end
	return missing
end

function ns:JournalTotal(kind)
	local missing = self:JournalMissing(kind)
	if not missing then return nil end
	return self:JournalCounts()[kind] + #missing
end

-- Lignes d'une page : tampons gagnés (du plus récent au plus ancien ; les
-- paliers dans l'ordre), puis ce qui reste à découvrir, en gris.
function ns:JournalItems(kind)
	local earned = {}
	for _, stamp in pairs(self:JournalData().stamps) do
		if stamp.kind == kind then
			local detail = {}
			if stamp.date then detail[#detail + 1] = stamp.date end
			if stamp.level then detail[#detail + 1] = self:F("JRN_LEVEL_SHORT", stamp.level) end
			earned[#earned + 1] = { name = stamp.name, earned = true, at = stamp.at or 0, id = stamp.id,
				detail = table.concat(detail, "  "), order = tonumber(stamp.id:match(":(%d+)$")) }
		end
	end
	table.sort(earned, function(a, b)
		if kind == "level" then return (a.order or 0) < (b.order or 0) end
		if a.at ~= b.at then return a.at > b.at end
		return a.name < b.name
	end)
	local missing = self:JournalMissing(kind) or {}
	table.sort(missing, function(a, b)
		if a.order and b.order then return a.order < b.order end
		return a.name < b.name
	end)
	for _, entry in ipairs(missing) do
		earned[#earned + 1] = { name = entry.name, earned = false, detail = L.JRN_TO_DISCOVER }
	end
	return earned
end

function ns:JournalCounterText(kind)
	local count = self:JournalCounts()[kind] or 0
	local total = self:JournalTotal(kind)
	if total then return self:F("JRN_COUNT_OF", self:JournalKindLabel(kind), count, total), count, total end
	return self:F("JRN_COUNT", self:JournalKindLabel(kind), count), count, nil
end

-- La fenêtre (Complétion / Évolution) vit dans JournalWindow.lua.

function ns:ToggleJournal(forceShow)
	local frame = self:EnsureJournalWindow()
	if not frame then return nil end
	if frame:IsShown() and not forceShow then frame:Hide(); return frame end
	if not ModuleOn() then self:Print(L.JRN_OFF_HINT) end
	self:RefreshJournal()
	if self.CloseOtherWindows then self:CloseOtherWindows(frame) end
	frame:Show()
	if Theme.FadeIn then Theme.FadeIn(frame, 0.15) end
	return frame
end

-- ---------------------------------------------------------------------------
-- Commandes et bouton des réglages
-- ---------------------------------------------------------------------------
ns.EXTRA_COMMANDS = ns.EXTRA_COMMANDS or {}
ns.EXTRA_COMMANDS["carnet"] = function(self) self:ToggleJournal() end
ns.EXTRA_COMMANDS["journal"] = ns.EXTRA_COMMANDS["carnet"]

-- RunOptionAction (Options.lua) ne connaît que ses propres actions : un relais
-- léger traite « journal » et laisse passer tout le reste.
do
	local previous = ns.RunOptionAction
	function ns:RunOptionAction(key, ...)
		if key == "journal" then return self:ToggleJournal(true) end
		if previous then return previous(self, key, ...) end
	end
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
local function CombatArgs(...)
	-- clients modernes : charge utile via CombatLogGetCurrentEventInfo ;
	-- très anciens : passée à l'événement
	local fn = rawget(_G, "CombatLogGetCurrentEventInfo")
	if type(fn) == "function" then
		local ok, _, subevent, _, sourceGUID, _, sourceFlags, _, destGUID = pcall(fn)
		if ok then return subevent, sourceGUID, sourceFlags, destGUID end
		return nil
	end
	local _, subevent, _, sourceGUID, _, sourceFlags, _, destGUID = ...
	return subevent, sourceGUID, sourceFlags, destGUID
end

local HANDLERS = {
	PLAYER_ENTERING_WORLD   = function() ns:JournalLevels(); ns:JournalScan() end,
	ZONE_CHANGED_NEW_AREA   = function() ns:JournalScan() end,
	ZONE_CHANGED            = function() ns:JournalScan() end,
	ZONE_CHANGED_INDOORS    = function() ns:JournalScan() end,
	PLAYER_LEVEL_UP         = function(level) ns:JournalLevels(level) end,
	PLAYER_TARGET_CHANGED   = function() ns:JournalSeeUnit("target") end,
	UPDATE_MOUSEOVER_UNIT   = function() ns:JournalSeeUnit("mouseover") end,
	NAME_PLATE_UNIT_ADDED   = function(unit) ns:JournalSeeUnit(unit) end,
	COMBAT_LOG_EVENT_UNFILTERED = function(...)
		if not next(ns.journalRares) then return end      -- coût nul sans rare repéré
		ns:JournalCombat(CombatArgs(...))
	end,
	-- moteur 12.0 (Forever) : journal de combat fermé
	PARTY_KILL = function(attacker, target)
		if not next(ns.journalRares) then return end
		target = ns.Plain(target)
		if target then ns:JournalCombat("PARTY_KILL", ns.Plain(attacker), ns.GroupFlags(attacker), target) end
	end,
	UNIT_DIED = function(guid)
		if not next(ns.journalRares) then return end
		guid = ns.Plain(guid)
		if guid then ns:JournalCombat("UNIT_DIED", nil, nil, guid) end
	end,
	PLAYER_REGEN_ENABLED    = function() ns:JournalFlush() end,
}

local eventFrame = CreateFrame("Frame")
ns.RegisterHandlers(eventFrame, HANDLERS)
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("journal:" .. tostring(event), err) end
end)
eventFrame:SetScript("OnUpdate", function()
	if ns.journalToastHideAt or #ns.journalToasts > 0 then ns:UpdateJournalToast(ns.Now()) end
end)
ns.journalEventFrame = eventFrame

if ns.Mark then ns.Mark("Journal") end
