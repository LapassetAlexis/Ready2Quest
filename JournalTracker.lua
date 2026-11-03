-- JournalTracker.lua -- objectifs du « Carnet de voyage » et suivi à l'écran (v1.25.0)
--
-- Retour joueur : « je ne sais pas ce qui me reste à faire ». Le carnet
-- montre ce qui est GAGNÉ ; ce fichier calcule ce qui est PROCHE et l'affiche
-- dans un petit cadre « Carnet », dans l'esprit du suivi de quêtes.
--
-- Pourquoi un cadre à nous plutôt que des lignes dans le suivi de Blizzard :
-- QuestWatchFrame (Era) et ObjectiveTrackerFrame (Forever, client moderne) ne
-- se ressemblent pas, et Questie ou d'autres addons les remplacent souvent.
-- Écrire dedans casserait au premier changement ; se poser JUSTE EN DESSOUS
-- donne le même confort sans dépendre de leur fonctionnement interne.
--
-- Sources d'objectifs (4 affichés : un mis en avant + 3, le plus proche d'abord ;
-- le survol dit quoi faire, noms à l'appui) :
--   * Compagnon de route : ns:CompanionNextUnlocks() (contrat avec
--     Companion.lua) -> liste de { label, kind = "app"|"orn"|"stage",
--     stat = "zone"|"subzone"|"dungeon"|"rare"|"level"|"total", have, need } ;
--     fonction absente : aucune ligne de cette source, rien d'inventé ;
--   * villages de la zone courante encore sans tampon (faction filtrée comme
--     au carnet) ;
--   * capitales (x / 6) ;
--   * donjons de ton niveau (plages de DungeonData.lua) ;
--   * prochain palier de niveau.
-- Chaque objectif se masque d'un clic droit (par personnage) ; la liste se
-- recalcule à chaque tampon, changement de zone et montée de niveau.
local ADDON, ns = ...
local L = ns.L
local Theme = ns.Theme

-- un objectif mis en avant (carte avec sa barre) + trois secondaires
local TRACKER_MAX = 4
local TRACKER_WIDTH, TITLE_H, LINE_H = 240, 18, 16
local FEATURED_H, FEATURED_GAP = 40, 4
local MINI_BAR_W = 44
local HINT_NAMES = 6        -- noms listés au survol, au-delà « … et N autres »
-- Ordre d'essai : Era d'abord (QuestWatchFrame), puis le client moderne de
-- Forever (le cadre global, puis le seul bloc des quêtes)
local BLIZZARD_TRACKERS = { "QuestWatchFrame", "ObjectiveTrackerFrame", "QuestObjectiveTracker" }
-- Sans suivi de Blizzard : à droite, sous la minicarte, là où on cherche un suivi
local FALLBACK = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -90, y = -260 }

-- ---------------------------------------------------------------------------
-- Chaînes, réglages
-- ---------------------------------------------------------------------------
local FR = {
	OPT_JRN_TRACKER        = "Suivi à l'écran",
	OPT_JRN_TRACKER_COMBAT = "Masquer en combat",
	OPT_JRN_TRACKER_RESET  = "Réinitialiser la position du suivi",
	JRN_TRK_TITLE          = "Carnet",
	JRN_TRK_TITLE_COUNT    = "Carnet (%d)",
	JRN_TRK_RESET          = "Suivi du carnet remis à sa place.",
	JRN_GOAL_UNLOCK        = "%s — %s",
	JRN_GOAL_VILLAGES      = "Villages de %s",
	JRN_GOAL_CAPITALS      = "Capitales",
	JRN_GOAL_DUNGEONS      = "Donjons de ton niveau",
	JRN_GOAL_LEVEL         = "Palier %d : niveau",
	JRN_STAT_zone          = "zones",
	JRN_STAT_subzone       = "villages",
	JRN_STAT_capital       = "capitales",
	JRN_STAT_dungeon       = "donjons",
	JRN_STAT_rare          = "rares",
	JRN_STAT_level         = "niveau",
	JRN_STAT_total         = "tampons",
	JRN_HINT_TODO          = "Pour avancer :",
	JRN_HINT_CLICK         = "Clic : ouvrir le carnet · clic droit : masquer",
	JRN_HINT_MORE          = "… et %d autres",
	JRN_HINT_app           = "Débloque une nouvelle apparence pour ton compagnon.",
	JRN_HINT_orn           = "Débloque un nouvel ornement pour le cadre du compagnon.",
	JRN_HINT_stage         = "Ton compagnon passe au stade suivant.",
	JRN_HINT_STAT_zone     = "Découvre des zones où tu n'es jamais allé : chaque nouvelle zone compte.",
	JRN_HINT_STAT_subzone  = "Entre dans des villages amis ou neutres pas encore tamponnés.",
	JRN_HINT_STAT_capital  = "Visite les capitales, même celles de l'autre faction.",
	JRN_HINT_STAT_dungeon  = "Entre dans des donjons : passer l'entrée suffit pour le tampon.",
	JRN_HINT_STAT_rare     = "Engage et abats des ennemis rares (portrait au dragon argenté).",
	JRN_HINT_STAT_level    = "Gagne des niveaux : quêtes et monstres de ton niveau.",
	JRN_HINT_STAT_total    = "Chaque première fois compte : zone, village, capitale, donjon, rare, palier.",
	JRN_HINT_VILLAGES      = "Villages à visiter dans %s :",
	JRN_HINT_CAPITALS      = "Capitales pas encore visitées (même celles de l'autre faction) :",
	JRN_HINT_DUNGEONS      = "Entre dans l'un de ces donjons (l'entrée suffit) :",
	JRN_HINT_LEVEL         = "Encore %d niveau(x). Quêtes et monstres de ton niveau.",
	JRN_HINT_XP            = "XP avant le prochain niveau : %d",
	JRN_GOAL_ZONE          = "Complétion de %s",
	JRN_GOAL_REACH_LEVEL   = "Atteins le niveau %d",
	JRN_GOAL_HAPPY         = "Rends %s heureux pour évoluer",
	JRN_REWARD             = "Récompense : %s",
	JRN_REWARD_STAGE       = "%s devient %s",
	JRN_STAT_happy         = "envies comblées",
	JRN_REWARD_MILESTONE   = "tampon « Palier %d »",
	JRN_ZONE_PCT           = "%d %%",
	JRN_ZONE_PARTS         = "Où tu en es :",
	JRN_ZONE_PART_LINE     = "  %s : %d/%d",
	JRN_ZONE_NEXT          = "Le plus simple pour avancer — %s :",
	JRN_PART_villages      = "Villages",
	JRN_ITEM_TO_VISIT      = "à visiter",
	JRN_ITEM_VISITED       = "visité",
}
local EN = {
	OPT_JRN_TRACKER        = "On-screen tracker",
	OPT_JRN_TRACKER_COMBAT = "Hide in combat",
	OPT_JRN_TRACKER_RESET  = "Reset the tracker position",
	JRN_TRK_TITLE          = "Journal",
	JRN_TRK_TITLE_COUNT    = "Journal (%d)",
	JRN_TRK_RESET          = "Journal tracker moved back to its place.",
	JRN_GOAL_UNLOCK        = "%s — %s",
	JRN_GOAL_VILLAGES      = "Villages of %s",
	JRN_GOAL_CAPITALS      = "Capitals",
	JRN_GOAL_DUNGEONS      = "Dungeons for your level",
	JRN_GOAL_LEVEL         = "Milestone %d: level",
	JRN_STAT_zone          = "zones",
	JRN_STAT_subzone       = "villages",
	JRN_STAT_capital       = "capitals",
	JRN_STAT_dungeon       = "dungeons",
	JRN_STAT_rare          = "rares",
	JRN_STAT_level         = "level",
	JRN_STAT_total         = "stamps",
	JRN_HINT_TODO          = "To make progress:",
	JRN_HINT_CLICK         = "Click: open the journal · right-click: hide",
	JRN_HINT_MORE          = "… and %d more",
	JRN_HINT_app           = "Unlocks a new look for your companion.",
	JRN_HINT_orn           = "Unlocks a new ornament for your companion's frame.",
	JRN_HINT_stage         = "Your companion reaches its next stage.",
	JRN_HINT_STAT_zone     = "Discover zones you've never been to: every new zone counts.",
	JRN_HINT_STAT_subzone  = "Enter friendly or neutral villages you haven't stamped yet.",
	JRN_HINT_STAT_capital  = "Visit capitals, even the other faction's.",
	JRN_HINT_STAT_dungeon  = "Enter dungeons: stepping through the entrance earns the stamp.",
	JRN_HINT_STAT_rare     = "Engage and defeat rare enemies (silver dragon portrait).",
	JRN_HINT_STAT_level    = "Gain levels: quests and monsters of your level.",
	JRN_HINT_STAT_total    = "Every first time counts: zone, village, capital, dungeon, rare, milestone.",
	JRN_HINT_VILLAGES      = "Villages to visit in %s:",
	JRN_HINT_CAPITALS      = "Capitals not visited yet (the other faction's count too):",
	JRN_HINT_DUNGEONS      = "Enter one of these dungeons (the entrance is enough):",
	JRN_HINT_LEVEL         = "%d level(s) to go. Quests and monsters of your level.",
	JRN_HINT_XP            = "XP to next level: %d",
	JRN_GOAL_ZONE          = "%s completion",
	JRN_GOAL_REACH_LEVEL   = "Reach level %d",
	JRN_GOAL_HAPPY         = "Make %s happy so it can grow",
	JRN_REWARD             = "Reward: %s",
	JRN_REWARD_STAGE       = "%s becomes %s",
	JRN_STAT_happy         = "needs filled",
	JRN_REWARD_MILESTONE   = "\"Milestone %d\" stamp",
	JRN_ZONE_PCT           = "%d %%",
	JRN_ZONE_PARTS         = "Where you stand:",
	JRN_ZONE_PART_LINE     = "  %s: %d/%d",
	JRN_ZONE_NEXT          = "Easiest way forward — %s:",
	JRN_PART_villages      = "Villages",
	JRN_ITEM_TO_VISIT      = "to visit",
	JRN_ITEM_VISITED       = "visited",
}
ns.RegisterStrings(FR, EN)
ns.JOURNAL_TRACKER_STRINGS = { fr = FR, en = EN }

ns.RegisterDefaults({
	journalTracker       = true,
	-- en combat, le regard est sur le combat : le suivi s'efface et revient après
	journalTrackerCombat = true,
})

-- ---------------------------------------------------------------------------
-- Village -> zone (uiMapID de type « Zone », mêmes numéros sur Era et Forever)
-- ---------------------------------------------------------------------------
-- Hubs.lua (généré) ne dit pas dans quelle zone est un village, et le client
-- n'a pas d'API areaID -> carte. Table posée à la main pour les villages et
-- hubs de la base ; les lieux propres à Forever (absents ici) s'apprennent en
-- passant (LearnHubZone), le premier passage suffit.
local HUB_ZONE = {
	-- Alliance
	[348] = 1425, [415] = 1440, [442] = 1439, [3197] = 1422, [42] = 1431, [16134] = 1431, [16161] = 1431,
	[186] = 1438, [1116] = 1444, [87] = 1429, [16524] = 1429, [131] = 1426, [69] = 1433, [150] = 1437,
	[2418] = 1428, [1438] = 1419, [608] = 1443, [320] = 1417, [702] = 1438, [108] = 1436, [271] = 1424,
	[2369] = 1424, [467] = 1442, [3137] = 1447, [16016] = 1447, [489] = 1444, [144] = 1432, [513] = 1445,
	-- Horde
	[222] = 1412, [496] = 1445, [159] = 1420, [1099] = 1444, [378] = 1413, [251] = 1428, [484] = 1441,
	[117] = 1434, [321] = 1417, [340] = 1418, [362] = 1411, [3317] = 1425, [2408] = 1443, [431] = 1440,
	[75] = 1435, [460] = 1442, [272] = 1424, [2368] = 1424, [380] = 1413, [228] = 1421, [1237] = 1447,
	[2897] = 1440,
	-- neutres
	[35] = 1434, [3425] = 1451, [2255] = 1452, [976] = 1446, [2268] = 1423, [541] = 1449, [2240] = 1441,
	[2361] = 1450, [392] = 1413, [977] = 1446, [1446] = 1427,
}
ns.JOURNAL_HUB_ZONE = HUB_ZONE

-- ---------------------------------------------------------------------------
-- Accès robustes
-- ---------------------------------------------------------------------------
local function Call(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c, d, e = pcall(fn, ...)
	if ok then return a, b, c, d, e end
	return nil
end

local function ModuleOn()
	local db = ns:DB()
	-- un seul interrupteur pour le Compagnon et son carnet (v1.25.0)
	return db.enabled ~= false and db.companionEnabled ~= false
end

-- PLAYER_LEVEL_UP arrive parfois avant que UnitLevel ne suive : le niveau
-- annoncé par l'événement vaut pendant son seul traitement (posé puis effacé)
local function Level()
	local level = tonumber(Call("UnitLevel", "player")) or 0
	local hint = tonumber(ns.journalLevelHint)
	if hint and hint > level then level = hint end
	return level
end

-- PLAYER_REGEN_DISABLED précède le verrouillage : le drapeau posé par
-- l'événement fait foi, InCombatLockdown en secours (/reload en combat)
local function InCombat()
	return ns.journalTrackerCombat == true or Call("InCombatLockdown") == true
end

function ns:JournalHubZone(areaID)
	if not areaID then return nil end
	local learned = self:DB().journalHubZones
	return HUB_ZONE[areaID] or (type(learned) == "table" and learned[areaID]) or nil
end

-- Un village visité dont la zone n'est pas dans la table : on la retient
-- (sauvegarde du compte : la géographie est la même pour tous tes personnages)
function ns:LearnHubZone()
	if self:InInstance() then return end
	local subzone = self:CurrentSubZone()
	local group = subzone and self:JournalHubGroups()[subzone]
	if not group or not group.areaID or HUB_ZONE[group.areaID] then return end
	if group.kind ~= "town" and group.kind ~= "hub" then return end
	local zoneID = self:JournalZone()
	if not zoneID then return end
	local db = self:DB()
	if type(db.journalHubZones) ~= "table" then db.journalHubZones = {} end
	db.journalHubZones[group.areaID] = zoneID
end

-- ---------------------------------------------------------------------------
-- Objectifs
-- ---------------------------------------------------------------------------
-- Un objectif atteint (have >= need) n'en est plus un : il disparaît.
-- `ratio` sert au tri et à la barre ; par défaut have / need.
local function Goal(id, label, have, need, ratio, source)
	have, need = tonumber(have), tonumber(need)
	if not have or not need or need <= 0 or have >= need then return nil end
	if have < 0 then have = 0 end
	return {
		id = id, label = label, have = have, need = need, source = source,
		ratio = ratio or (have / need), progress = string.format("%d/%d", have, need),
	}
end
ns.JournalGoal = Goal

-- Survol : « que faire ? ». Une liste de noms est coupée à HINT_NAMES.
local function NameLines(lines, names)
	for index, name in ipairs(names) do
		if index > HINT_NAMES then
			lines[#lines + 1] = ns:F("JRN_HINT_MORE", #names - HINT_NAMES)
			break
		end
		lines[#lines + 1] = "  · " .. tostring(name)
	end
	return lines
end

-- Villages de la zone où tu es, amis ou neutres, connus de ce client
local function ZoneVillages(self, zoneID, zoneName)
	if not zoneID then zoneID, zoneName = self:JournalZone() end
	if not zoneID then return nil end
	if not zoneName then
		local info = self.MapInfo and self:MapInfo(zoneID)
		zoneName = info and info.name
	end
	local faction, stamps = self:PlayerFaction(), self:JournalData().stamps
	local have, need, missing, visited = 0, 0, {}, {}
	for name, group in pairs(self:JournalHubGroups()) do
		if group.exists and self:JournalIsVillage(group, faction) and self:JournalHubZone(group.areaID) == zoneID then
			need = need + 1
			if stamps["subzone:" .. group.areaID] then
				have = have + 1
				visited[#visited + 1] = name
			else
				missing[#missing + 1] = name
			end
		end
	end
	table.sort(missing)
	table.sort(visited)
	return { zoneID = zoneID, zoneName = tostring(zoneName or "?"), have = have, need = need, missing = missing, visited = visited }
end

-- Donjons dont la plage (Era ou Forever) contient ton niveau
local function LevelDungeons(self)
	local level = Level()
	if level <= 0 or not self.DungeonRange then return nil end
	local forever = self.IsForeverClient and self:IsForeverClient()
	local stamps, inRange, missing, have = self:JournalData().stamps, {}, {}, 0
	for key, entry in pairs(self.DUNGEONS or {}) do
		if not entry.forever or forever then
			local low, high = self:DungeonRange(entry)
			if low and high and level >= low and level <= high then
				inRange[#inRange + 1] = key
				if stamps["dungeon:" .. key] then
					have = have + 1
				else
					missing[#missing + 1] = { low = low, high = high,
						name = self.DungeonName and self:DungeonName(entry) or entry.name or key }
				end
			end
		end
	end
	if #inRange == 0 then return nil end
	table.sort(inRange)
	table.sort(missing, function(a, b)
		if a.low ~= b.low then return a.low < b.low end
		return a.name < b.name
	end)
	local names = {}
	for _, entry in ipairs(missing) do names[#names + 1] = string.format("%s (%d-%d)", entry.name, entry.low, entry.high) end
	return { inRange = inRange, have = have, names = names }
end

local function CapitalNames(self)
	local names = {}
	for _, entry in ipairs(self:JournalMissing("capital") or {}) do names[#names + 1] = entry.name end
	table.sort(names)
	return names
end

-- Pistes concrètes pour une stat du compagnon, tirées des mêmes données
local function StatHint(self, stat, lines)
	lines[#lines + 1] = L["JRN_HINT_STAT_" .. tostring(stat)] or nil
	if stat == "subzone" then
		local villages = ZoneVillages(self)
		if villages and #villages.missing > 0 then
			lines[#lines + 1] = self:F("JRN_HINT_VILLAGES", villages.zoneName)
			NameLines(lines, villages.missing)
		end
	elseif stat == "dungeon" then
		local dungeons = LevelDungeons(self)
		if dungeons and #dungeons.names > 0 then
			lines[#lines + 1] = L.JRN_HINT_DUNGEONS
			NameLines(lines, dungeons.names)
		end
	elseif stat == "capital" then
		local names = CapitalNames(self)
		if #names > 0 then
			lines[#lines + 1] = L.JRN_HINT_CAPITALS
			NameLines(lines, names)
		end
	end
	return lines
end

-- Compagnon : le contrat seul, rien de recalculé ici (les seuils vivent dans
-- CompanionData.lua et peuvent changer sans que ce fichier le sache)
local function CompanionGoals(self, list)
	local fn = self.CompanionNextUnlocks
	if type(fn) ~= "function" then return end
	local ok, unlocks = pcall(fn, self)
	if not ok or type(unlocks) ~= "table" then return end
	for _, unlock in ipairs(unlocks) do
		if type(unlock) == "table" and type(unlock.label) == "string" and unlock.label ~= "" then
			local stat = L["JRN_STAT_" .. tostring(unlock.stat)] or tostring(unlock.stat or "")
			local goal = Goal("comp:" .. tostring(unlock.kind) .. ":" .. unlock.label,
				self:F("JRN_GOAL_UNLOCK", unlock.label, stat), unlock.have, unlock.need, nil, "companion")
			if goal then
				goal.kind, goal.short, goal.unit = unlock.kind, unlock.label, stat
				goal.hint = StatHint(self, unlock.stat, { L["JRN_HINT_" .. tostring(unlock.kind)] })
				if unlock.kind == "stage" then
					-- un stade : l'objectif est l'action, le stade la récompense
					local name = self.CompanionName and self:CompanionName() or "?"
					goal.reward = self:F("JRN_REWARD_STAGE", name, unlock.label)
					if unlock.stat == "happy" then
						goal.label = self:F("JRN_GOAL_HAPPY", name)
						goal.short = goal.label
						goal.hint = self.CompanionHappyHints and self:CompanionHappyHints() or {}
						goal.ratio = 1.5   -- prêt à évoluer : en tête, juste après un coffre
					else
						goal.label = self:F("JRN_GOAL_REACH_LEVEL", unlock.need)
						goal.short, goal.unit = goal.label, nil
						goal.merge = "level:" .. unlock.need
					end
				end
				list[#list + 1] = goal
			end
		end
	end
end

local function VillageGoals(self, list)
	local villages = ZoneVillages(self)
	if not villages then return end
	local goal = Goal("villages:" .. villages.zoneID, self:F("JRN_GOAL_VILLAGES", villages.zoneName),
		villages.have, villages.need, nil, "journal")
	if goal then
		goal.hint = NameLines({ self:F("JRN_HINT_VILLAGES", villages.zoneName) }, villages.missing)
		list[#list + 1] = goal
	end
end

local function CapitalGoals(self, list)
	local names = CapitalNames(self)
	local have = self:JournalCounts().capital or 0
	local goal = Goal("capitals", L.JRN_GOAL_CAPITALS, have, have + #names, nil, "journal")
	if goal then
		goal.hint = NameLines({ L.JRN_HINT_CAPITALS }, names)
		list[#list + 1] = goal
	end
end

-- L'identifiant suit la plage, pas les tampons : un objectif masqué reste
-- masqué quand tu en finis un, et revient quand de nouveaux donjons entrent
-- dans ta tranche. Les noms passent au survol, la ligne reste courte.
local function DungeonGoals(self, list)
	local dungeons = LevelDungeons(self)
	if not dungeons then return end
	local goal = Goal("dungeons:" .. table.concat(dungeons.inRange, ","), L.JRN_GOAL_DUNGEONS,
		dungeons.have, #dungeons.inRange, nil, "journal")
	if goal then
		goal.hint = NameLines({ L.JRN_HINT_DUNGEONS }, dungeons.names)
		list[#list + 1] = goal
	end
end

-- Prochain palier : affiché « niveau 27/30 », mais trié sur l'avancée dans la
-- tranche (27 sur 20 -> 30 = 70 %), sinon il serait toujours en tête
local function LevelGoals(self, list)
	local level = Level()
	if level <= 0 then return end
	local milestones = ns.JOURNAL_MILESTONES or { 10, 20, 30, 40, 50, 60 }
	for index, milestone in ipairs(milestones) do
		if level < milestone then
			local previous = milestones[index - 1] or 1
			local goal = Goal("level:" .. milestone, self:F("JRN_GOAL_REACH_LEVEL", milestone), level, milestone,
				(level - previous) / (milestone - previous), "journal")
			if goal then
				goal.hint = { self:F("JRN_HINT_LEVEL", milestone - level) }
				goal.reward = self:F("JRN_REWARD_MILESTONE", milestone)
				local xp, xpMax = tonumber(Call("UnitXP", "player")), tonumber(Call("UnitXPMax", "player"))
				if xp and xpMax and xpMax > xp then goal.hint[2] = self:F("JRN_HINT_XP", xpMax - xp) end
				list[#list + 1] = goal
			end
			return
		end
	end
end

local SOURCES = { CompanionGoals, VillageGoals, CapitalGoals, DungeonGoals, LevelGoals }

-- Extension : d'autres fichiers ajoutent leurs objectifs.
--   ns.RegisterGoalSource(function(self, list) ... end)
-- La fonction ajoute à `list` des objectifs construits avec ns.JournalGoal
-- (id, label, have, need, ratio, source) ; elle peut poser goal.hint (lignes
-- du survol), goal.short et goal.unit (carte mise en avant). Une source en
-- panne est isolée (pcall) et n'empêche pas les autres.
function ns.RegisterGoalSource(fn)
	if type(fn) == "function" then SOURCES[#SOURCES + 1] = fn end
end

-- Complétion de zone : chaque part (villages, bestiaire, récolte…) dit où tu
-- en es dans une zone.
--   ns.RegisterZonePart({ id = "bestiary", label = "JRN_PART_bestiary",
--     Compute = function(self, zoneID) return { have =, need =, hint = { … } } end })
-- Compute renvoie nil quand la part ne s'applique pas (pas de métier, rien vu).
ns.ZONE_PARTS = ns.ZONE_PARTS or {}
function ns.RegisterZonePart(def)
	if type(def) == "table" and def.id and type(def.Compute) == "function" then
		ns.ZONE_PARTS[#ns.ZONE_PARTS + 1] = def
	end
end

-- Villages : la première part, livrée ici
ns.RegisterZonePart({ id = "villages", label = "JRN_PART_villages", tab = "explore",
	Compute = function(self, zoneID)
		local villages = ZoneVillages(self, zoneID)
		if not villages or villages.need == 0 then return nil end
		return { have = villages.have, need = villages.need,
			hint = NameLines({}, villages.missing) }
	end,
	-- détail pour la fenêtre du carnet : à visiter d'abord, puis visités
	Items = function(self, zoneID)
		local villages = ZoneVillages(self, zoneID)
		if not villages then return {} end
		local items = {}
		for _, name in ipairs(villages.missing) do items[#items + 1] = { name = name, done = false, detail = L.JRN_ITEM_TO_VISIT } end
		for _, name in ipairs(villages.visited) do items[#items + 1] = { name = name, done = true, detail = L.JRN_ITEM_VISITED } end
		return items
	end })

-- Où tu en es dans une zone : chaque part qui s'applique pèse autant que les
-- autres (5 villages sur 5 et 2 espèces sur 10 = 60 %, pas 7/15). Renvoie
-- nil si aucune part ne s'applique.
function ns:ZoneCompletion(zoneID)
	if not zoneID then return nil end
	local parts, sum = {}, 0
	for _, def in ipairs(ns.ZONE_PARTS) do
		local ok, part = pcall(def.Compute, self, zoneID)
		if ok and type(part) == "table" and tonumber(part.need) and part.need > 0 then
			local have = math.min(math.max(tonumber(part.have) or 0, 0), part.need)
			parts[#parts + 1] = { id = def.id, label = L[def.label] or def.label or def.id,
				have = have, need = part.need, ratio = have / part.need, hint = part.hint }
			sum = sum + have / part.need
		elseif not ok and self.RecordError then
			self:RecordError("journal:zonepart:" .. tostring(def.id), part)
		end
	end
	if #parts == 0 then return nil end
	local ratio = sum / #parts
	return { zoneID = zoneID, parts = parts, ratio = ratio, percent = math.floor(ratio * 100 + 1e-9) }
end

-- Objectif « Complétion de <zone> » : seulement si au moins deux parts
-- s'appliquent (une seule, c'est déjà son propre objectif)
-- Zones suivies à l'écran (par personnage) : la zone où tu es l'est d'office,
-- sauf si tu la décoches ; une autre zone, seulement si tu la coches.
function ns:JournalWatchData()
	local data = self:JournalData()
	if type(data.watch) ~= "table" then data.watch = {} end
	return data.watch
end

function ns:JournalIsWatched(zoneID)
	if not zoneID then return false end
	local value = self:JournalWatchData()[zoneID]
	if zoneID == self:JournalZone() then return value ~= false end
	return value == true
end

-- Cocher une zone la réactive en entier : ses objectifs masqués d'un clic
-- droit (complétion, villages, bestiaire, nommés) reviennent dans le suivi.
local WATCH_PREFIXES = { "zone:", "villages:", "bestiary:", "named:" }
function ns:JournalSetWatched(zoneID, on)
	if not zoneID then return nil end
	self:JournalWatchData()[zoneID] = on and true or false
	if on then
		local dismissed = self:JournalData().dismissed
		if type(dismissed) == "table" then
			for _, prefix in ipairs(WATCH_PREFIXES) do dismissed[prefix .. zoneID] = nil end
		end
	end
	if self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then self:RefreshJournal() end
	return on and true or false
end

local function ZoneGoal(self, zoneID, zoneName, minParts)
	local done = self:ZoneCompletion(zoneID)
	if not done or #done.parts < minParts or done.percent >= 100 then return nil end
	if not zoneName then
		local info = self.MapInfo and self:MapInfo(zoneID)
		zoneName = info and info.name
	end
	local goal = Goal("zone:" .. zoneID, self:F("JRN_GOAL_ZONE", tostring(zoneName or zoneID)), done.percent, 100,
		done.ratio, "journal")
	if not goal then return nil end
	goal.progress = self:F("JRN_ZONE_PCT", done.percent)
	goal.zoneCompletion, goal.zoneID = true, zoneID
	local hint = { L.JRN_ZONE_PARTS }
	local easiest
	for _, part in ipairs(done.parts) do
		hint[#hint + 1] = self:F("JRN_ZONE_PART_LINE", part.label, part.have, part.need)
		if part.have < part.need and (not easiest or part.need - part.have < easiest.need - easiest.have) then easiest = part end
	end
	if easiest and type(easiest.hint) == "table" and #easiest.hint > 0 then
		hint[#hint + 1] = self:F("JRN_ZONE_NEXT", easiest.label)
		for _, text in ipairs(easiest.hint) do hint[#hint + 1] = text end
	end
	goal.hint = hint
	return goal
end

-- « Complétion de <zone> » : la zone d'ici (à partir de deux parts : une
-- seule, c'est déjà son propre objectif), plus chaque zone cochée
local function ZoneGoals(self, list)
	local here, hereName = self:JournalZone()
	if here then
		local goal = ZoneGoal(self, here, hereName, 2)
		if goal then list[#list + 1] = goal end
	end
	for zoneID, on in pairs(self:JournalWatchData()) do
		if on == true and zoneID ~= here then
			local goal = ZoneGoal(self, zoneID, nil, 1)
			-- cochée exprès : avant les objectifs automatiques (après un coffre
			-- ou une évolution qui attend)
			if goal then goal.ratio, goal.pinned = 1.2, true; list[#list + 1] = goal end
		end
	end
end
SOURCES[#SOURCES + 1] = ZoneGoals

-- Onglet Zones du carnet : le pourcentage à côté de chaque zone tamponnée
do
	local previous = ns.JournalItems
	if previous then
		function ns:JournalItems(kind)
			local items = previous(self, kind)
			if kind == "zone" then
				for _, item in ipairs(items) do
					local zoneID = item.id and tonumber(item.id:match("^zone:(%d+)$"))
					local done = zoneID and self:ZoneCompletion(zoneID)
					if done then
						local pct = self:F("JRN_ZONE_PCT", done.percent)
						item.detail = (item.detail and item.detail ~= "") and (item.detail .. "  " .. pct) or pct
						item.completion = done
					end
				end
			end
			return items
		end
	end
end

-- Le plus proche du but d'abord ; à égalité, le moins de pas restants, puis
-- le nom (ordre stable d'un rafraîchissement à l'autre). Masqués à la fin.
local function Closer(a, b)
	if (a.dismissed == true) ~= (b.dismissed == true) then return not a.dismissed end
	if a.ratio ~= b.ratio then return a.ratio > b.ratio end
	local ra, rb = a.need - a.have, b.need - b.have
	if ra ~= rb then return ra < rb end
	return a.label < b.label
end

-- Tous les objectifs, masqués compris (marqués), triés
function ns:JournalObjectives()
	local list = {}
	for _, source in ipairs(SOURCES) do
		-- une source en panne ne prive pas des autres
		local ok, err = pcall(source, self, list)
		if not ok and self.RecordError then self:RecordError("journal:objectives", err) end
	end
	-- même action, plusieurs récompenses : une seule ligne (le palier de
	-- niveau 20 et le stade qui l'attend ne font qu'un)
	local byId = {}
	for _, goal in ipairs(list) do byId[goal.id] = goal end
	for index = #list, 1, -1 do
		local goal = list[index]
		local host = goal.merge and byId[goal.merge]
		if host and host ~= goal then
			host.rewards = host.rewards or { host.reward }
			table.insert(host.rewards, 1, goal.reward)
			table.remove(list, index)
		end
	end
	for _, goal in ipairs(list) do
		if goal.reward and not goal.rewards then goal.rewards = { goal.reward } end
	end
	local dismissed = self:JournalData().dismissed or {}
	for _, goal in ipairs(list) do goal.dismissed = dismissed[goal.id] == true end
	table.sort(list, Closer)
	return list
end

-- Ceux du suivi : non masqués, les TRACKER_MAX premiers
-- La complétion de la zone affichée remplace ses parts (villages, bestiaire,
-- nommés de cette zone) : elles restent dans l'onglet Objectifs.
-- Une zone décochée sort du suivi avec toutes ses parts.
local ZONE_PART_PREFIX = { "villages:", "bestiary:", "named:" }
function ns:JournalTrackerObjectives()
	local all, zonesShown = self:JournalObjectives(), {}
	for _, goal in ipairs(all) do
		if goal.zoneCompletion and not goal.dismissed then zonesShown[goal.id:match("^zone:(%d+)$")] = true end
	end
	local function ZoneOf(goal)
		for _, prefix in ipairs(ZONE_PART_PREFIX) do
			local id = goal.id:match("^" .. prefix .. "(%d+)$")
			if id then return id end
		end
		return nil
	end
	local shown = {}
	for _, goal in ipairs(all) do
		local partZone = ZoneOf(goal)
		local zoneID = goal.zoneCompletion and goal.id:match("^zone:(%d+)$") or partZone
		local hidden = goal.dismissed
			or (zoneID and not self:JournalIsWatched(tonumber(zoneID)))
			or (partZone and zonesShown[partZone])
		if not hidden and #shown < TRACKER_MAX then shown[#shown + 1] = goal end
	end
	return shown
end

-- Lignes de l'onglet « Objectifs » de la fenêtre (Journal.lua)
function ns:JournalGoalItems()
	local items = {}
	for _, goal in ipairs(self:JournalObjectives()) do
		items[#items + 1] = { name = goal.label, earned = false, goal = goal,
			detail = goal.progress .. (goal.dismissed and ("  " .. L.JRN_GOAL_HIDDEN) or "") }
	end
	return items
end

-- Masquer / remettre (state nil : bascule). Par personnage, comme le carnet.
function ns:JournalDismiss(id, state)
	if id == nil then return nil end
	local data = self:JournalData()
	if type(data.dismissed) ~= "table" then data.dismissed = {} end
	if state == nil then state = not data.dismissed[id] end
	data.dismissed[id] = state and true or nil
	self:RefreshJournalTracker()
	if self.journalFrame and self.journalFrame:IsShown() and self.RefreshJournal then self:RefreshJournal() end
	return state
end

-- ---------------------------------------------------------------------------
-- Cadre « Carnet »
-- ---------------------------------------------------------------------------
-- Le suivi de Blizzard présent (le premier visible, sinon le premier qui existe)
function ns:BlizzardQuestTracker()
	local fallback
	for _, name in ipairs(BLIZZARD_TRACKERS) do
		local frame = rawget(_G, name)
		if type(frame) == "table" and type(frame.IsShown) == "function" then
			local ok, shown = pcall(frame.IsShown, frame)
			if ok and shown then return frame, name end
			fallback = fallback or { frame, name }
		end
	end
	if fallback then return fallback[1], fallback[2] end
	return nil
end

-- Sous le suivi de Blizzard tant que tu ne l'as pas déplacé. Suivi caché
-- (aucune quête suivie) : on prend sa place, en haut, pour ne pas flotter
-- au milieu de l'écran sous un cadre invisible.
function ns:PlaceJournalTracker()
	local frame = self.journalTracker
	if not frame then return nil end
	frame:ClearAllPoints()
	local saved = self:DB().journalTrackerPoint
	if type(saved) == "table" and saved.point then
		frame:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, tonumber(saved.x) or 0, tonumber(saved.y) or 0)
		frame.anchoredTo = "saved"
		return frame.anchoredTo
	end
	local anchor, name = self:BlizzardQuestTracker()
	if anchor then
		local shown = false
		pcall(function() shown = anchor:IsShown() == true end)
		local ok
		if shown then
			ok = pcall(frame.SetPoint, frame, "TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -8)
		else
			ok = pcall(frame.SetPoint, frame, "TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
		end
		if ok then
			frame.anchoredTo = name
			-- le suivi de Blizzard apparaît / disparaît avec tes quêtes suivies
			if not frame.hooked or frame.hooked ~= anchor then
				if type(anchor.HookScript) == "function" then
					local function Replace() if not ns:DB().journalTrackerPoint then ns:PlaceJournalTracker() end end
					pcall(anchor.HookScript, anchor, "OnShow", Replace)
					pcall(anchor.HookScript, anchor, "OnHide", Replace)
				end
				frame.hooked = anchor
			end
			return frame.anchoredTo
		end
		frame:ClearAllPoints()
	end
	frame:SetPoint(FALLBACK.point, UIParent, FALLBACK.relPoint, FALLBACK.x, FALLBACK.y)
	frame.anchoredTo = "UIParent"
	return frame.anchoredTo
end

-- Fin de glisser : position retenue, relative à UIParent (StartMoving
-- réancre le cadre sur l'écran, GetPoint le dit tel quel)
function ns:SaveJournalTrackerPoint()
	local frame = self.journalTracker
	if not frame then return end
	local point, _, relPoint, x, y = frame:GetPoint(1)
	if not point then return end
	self:DB().journalTrackerPoint = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
	frame.anchoredTo = "saved"
end

function ns:ResetJournalTracker()
	self:DB().journalTrackerPoint = nil
	if self.journalTracker then self:PlaceJournalTracker() end
	self:Print(L.JRN_TRK_RESET)
	self:RefreshJournalTracker()
end

function ns:ToggleJournalTrackerCollapsed()
	local db = self:DB()
	db.journalTrackerCollapsed = not db.journalTrackerCollapsed
	self:RefreshJournalTracker()
	return db.journalTrackerCollapsed
end

local function StartDrag()
	local frame = ns.journalTracker
	if frame and frame.StartMoving then frame:StartMoving() end
end
local function StopDrag()
	local frame = ns.journalTracker
	if not frame then return end
	if frame.StopMovingOrSizing then frame:StopMovingOrSizing() end
	ns:SaveJournalTrackerPoint()
end

-- Clic sur un objectif : le compagnon (stade, bonheur) ouvre l'Évolution ;
-- le reste ouvre la Complétion de la zone où tu es. Déjà ouvert : fermé.
function ns:OpenJournalFor(goal)
	if type(self.ToggleJournal) ~= "function" then return nil end
	local current = self.journalFrame
	if current and current:IsShown() then current:Hide(); return current end
	local frame = self:ToggleJournal(true)
	local evolution = goal and (goal.kind == "stage" or goal.source == "companion")
	if frame and self.SelectJournalKind then self:SelectJournalKind(evolution and "evolution" or "completion") end
	return frame
end

-- Survol d'un objectif : ce qu'il faut faire, avec des noms concrets
function ns:ShowJournalGoalTooltip(owner, goal)
	local tip = rawget(_G, "GameTooltip")
	if type(tip) ~= "table" or not goal then return end
	pcall(tip.SetOwner, tip, owner, "ANCHOR_LEFT")
	if tip.ClearLines then tip:ClearLines() end
	tip:AddLine(goal.label, Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	tip:AddLine(goal.progress .. (goal.unit and (" " .. goal.unit) or ""), 1, 1, 1)
	local rewards = goal.rewards or (goal.reward and { goal.reward })
	if rewards and #rewards > 0 then
		tip:AddLine(self:F("JRN_REWARD", table.concat(rewards, " · ")), Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], true)
	end
	if type(goal.hint) == "table" and #goal.hint > 0 then
		tip:AddLine(" ")
		tip:AddLine(L.JRN_HINT_TODO, Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
		for _, text in ipairs(goal.hint) do
			tip:AddLine(text, Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3], true)
		end
	end
	tip:AddLine(" ")
	tip:AddLine(L.JRN_HINT_CLICK, Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	tip:Show()
	return tip
end

local function HideTooltip()
	local tip = rawget(_G, "GameTooltip")
	if type(tip) == "table" and tip.Hide then tip:Hide() end
end

-- Une ligne d'objectif : losange, libellé, barre, progression. La première
-- est la « carte » mise en avant : fond, libellé court, grande barre.
local function BuildLine(frame, index)
	local featured = index == 1
	local line = CreateFrame("Button", nil, frame)
	line:SetSize(TRACKER_WIDTH, featured and FEATURED_H or LINE_H)
	local top = featured and -TITLE_H or -(TITLE_H + FEATURED_H + FEATURED_GAP + (index - 2) * LINE_H)
	line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, top)
	if line.RegisterForClicks then line:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
	if line.RegisterForDrag then line:RegisterForDrag("LeftButton") end
	line:SetScript("OnClick", function(self, button)
		if not self.goal then return end
		if button == "RightButton" then
			HideTooltip()
			return ns:JournalDismiss(self.goal.id, true)
		end
		if type(self.goal.onClick) == "function" then return self.goal.onClick() end
		ns:OpenJournalFor(self.goal)
	end)
	line:SetScript("OnDragStart", StartDrag)
	line:SetScript("OnDragStop", StopDrag)
	line:SetScript("OnEnter", function(self) ns:ShowJournalGoalTooltip(self, self.goal) end)
	line:SetScript("OnLeave", HideTooltip)

	if featured then
		line.bg = line:CreateTexture(nil, "BACKGROUND")
		line.bg:SetTexture(Theme.SOLID)
		line.bg:SetVertexColor(0, 0, 0, 0.55)
		line.bg:SetAllPoints()
		line.accent = line:CreateTexture(nil, "BORDER")
		line.accent:SetTexture(Theme.SOLID)
		line.accent:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		line.accent:SetPoint("TOPLEFT"); line.accent:SetPoint("BOTTOMLEFT")
		line.accent:SetWidth(2)
	end

	line.diamond = Theme.CreateDiamond(line, featured and 9 or 7, not featured)
	line.diamond:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
	line.text = line:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	line.text:SetJustifyH("LEFT")
	line.text:SetWordWrap(false)
	line.progress = line:CreateFontString(nil, "OVERLAY", Theme.F_BODY)
	line.progress:SetJustifyH("RIGHT")
	line.progress:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	if featured then
		line.diamond:SetPoint("TOPLEFT", line, "TOPLEFT", 9, -7)
		line.text:SetPoint("TOPLEFT", line, "TOPLEFT", 24, -5)
		line.text:SetWidth(TRACKER_WIDTH - 32)
		line.text:SetTextColor(Theme.PARCHMENT[1], Theme.PARCHMENT[2], Theme.PARCHMENT[3])
		line.bar = Theme.CreateBar(line, TRACKER_WIDTH - 24 - 78, 5)
		line.bar:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 24, 9)
		line.progress:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", -8, 6)
		line.progress:SetWidth(72)
	else
		line.diamond:SetPoint("LEFT", line, "LEFT", 12, 0)
		line.text:SetPoint("LEFT", line, "LEFT", 24, 0)
		line.text:SetWidth(TRACKER_WIDTH - 24 - MINI_BAR_W - 52)
		line.text:SetTextColor(Theme.TEXT[1], Theme.TEXT[2], Theme.TEXT[3])
		line.bar = Theme.CreateBar(line, MINI_BAR_W, 3)
		line.bar:SetPoint("RIGHT", line, "RIGHT", -46, 0)
		line.progress:SetPoint("RIGHT", line, "RIGHT", -8, 0)
		line.progress:SetWidth(38)
	end
	line.featured = featured
	line:Hide()
	return line
end

function ns:EnsureJournalTracker()
	if self.journalTracker then return self.journalTracker end
	if not Theme then return nil end
	local ok, frame = pcall(CreateFrame, "Frame", "Ready2QuestJournalTracker", UIParent)
	if not ok or not frame then return nil end
	frame:SetSize(TRACKER_WIDTH, TITLE_H)
	-- même couche que les suivis de quêtes : sous les fenêtres, au-dessus du monde
	frame:SetFrameStrata("LOW")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	-- le cadre lui-même laisse passer la souris : seuls le titre et les
	-- lignes la prennent, pas le vide entre elles
	frame:EnableMouse(false)

	-- titre : clic = replier / déplier, glisser = déplacer
	local title = CreateFrame("Button", nil, frame)
	title:SetSize(TRACKER_WIDTH, TITLE_H)
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	if title.RegisterForClicks then title:RegisterForClicks("LeftButtonUp") end
	if title.RegisterForDrag then title:RegisterForDrag("LeftButton") end
	title:SetScript("OnClick", function() ns:ToggleJournalTrackerCollapsed() end)
	title:SetScript("OnDragStart", StartDrag)
	title:SetScript("OnDragStop", StopDrag)
	title.text = Theme.CreateTitle(title, 13)
	title.text:SetPoint("RIGHT", title, "RIGHT", -16, 0)
	title.text:SetJustifyH("RIGHT")
	title.text:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
	-- repère ASCII « - » / « + » (pas de glyphe absent des polices du jeu)
	title.state = title:CreateFontString(nil, "OVERLAY", Theme.F_SMALL)
	title.state:SetPoint("RIGHT", title, "RIGHT", -2, 0)
	title.state:SetTextColor(Theme.MUTED[1], Theme.MUTED[2], Theme.MUTED[3])
	frame.title = title

	frame.lines = {}
	for index = 1, TRACKER_MAX do frame.lines[index] = BuildLine(frame, index) end
	frame:Hide()
	self.journalTracker = frame
	self:PlaceJournalTracker()
	return frame
end

-- Visible si : module allumé, suivi allumé, pas en combat (si réglé), et au
-- moins un objectif. Un titre seul, sans rien à suivre, ne serait que du bruit.
function ns:RefreshJournalTracker()
	local db = self:DB()
	local frame = self.journalTracker
	local wanted = ModuleOn() and db.journalTracker ~= false
		and not (db.journalTrackerCombat ~= false and InCombat())
	local goals = wanted and self:JournalTrackerObjectives() or {}
	if #goals == 0 then
		if frame then frame:Hide() end
		return frame
	end
	frame = frame or self:EnsureJournalTracker()
	if not frame then return nil end
	if frame.anchoredTo ~= "saved" then self:PlaceJournalTracker() end

	local collapsed = db.journalTrackerCollapsed == true
	frame.goals, frame.collapsed = goals, collapsed
	frame.title.text:SetText(collapsed and self:F("JRN_TRK_TITLE_COUNT", #goals) or L.JRN_TRK_TITLE)
	frame.title.state:SetText(collapsed and "+" or "-")
	local shown = 0
	for index, line in ipairs(frame.lines) do
		local goal = not collapsed and goals[index] or nil
		line.goal = goal
		if goal then
			if line.featured then
				line.text:SetText(goal.short or goal.label)
				line.progress:SetText(goal.progress .. (goal.unit and (" " .. goal.unit) or ""))
			else
				line.text:SetText(goal.label)
				line.progress:SetText(goal.progress)
			end
			line.bar:SetValue(goal.have / goal.need)
			line:Show()
			shown = shown + 1
		else
			line:Hide()
		end
	end
	local height = TITLE_H
	if shown > 0 then height = height + FEATURED_H + (shown - 1) * LINE_H + (shown > 1 and FEATURED_GAP or 0) end
	frame:SetHeight(height)
	frame:Show()
	return frame
end

-- ---------------------------------------------------------------------------
-- Relais : réglages, interrupteur du module, action « réinitialiser »
-- ---------------------------------------------------------------------------
do
	local previous = ns.RunOptionAction
	function ns:RunOptionAction(key, ...)
		if key == "journalTrackerReset" then return self:ResetJournalTracker() end
		if previous then return previous(self, key, ...) end
	end
end

-- Un interrupteur basculé dans les réglages passe par ApplyDisplayOptions ;
-- « /r2q module carnet off » et l'interrupteur de la navigation par
-- RefreshOptions. Les deux relais suffisent à suivre l'état du module.
do
	local previousApply = ns.ApplyDisplayOptions
	function ns:ApplyDisplayOptions(...)
		local result
		if previousApply then result = previousApply(self, ...) end
		-- jamais bloquant : un réglage doit s'appliquer même si le suivi échoue
		pcall(self.RefreshJournalTracker, self)
		return result
	end
	local previousRefresh = ns.RefreshOptions
	if previousRefresh then
		function ns:RefreshOptions(...)
			local result = previousRefresh(self, ...)
			pcall(self.RefreshJournalTracker, self)
			return result
		end
	end
end

-- ---------------------------------------------------------------------------
-- Événements
-- ---------------------------------------------------------------------------
-- Un tampon gagné (contrat STAMP de Journal.lua) : la liste bouge
ns:RegisterCallback("STAMP", function(self) self:RefreshJournalTracker() end)

local function Moved()
	ns:LearnHubZone()
	ns:RefreshJournalTracker()
	if ns.journalFrame and ns.journalFrame:IsShown() then ns:RefreshJournal() end
end

local HANDLERS = {
	PLAYER_ENTERING_WORLD = Moved,
	ZONE_CHANGED_NEW_AREA = Moved,
	ZONE_CHANGED          = Moved,
	ZONE_CHANGED_INDOORS  = Moved,
	PLAYER_LEVEL_UP       = function(level)
		ns.journalLevelHint = tonumber(level)
		local ok, err = pcall(Moved)
		ns.journalLevelHint = nil
		if not ok then error(err, 0) end
	end,
	PLAYER_REGEN_DISABLED = function() ns.journalTrackerCombat = true; ns:RefreshJournalTracker() end,
	PLAYER_REGEN_ENABLED  = function() ns.journalTrackerCombat = false; ns:RefreshJournalTracker() end,
}

local eventFrame = CreateFrame("Frame")
for event in pairs(HANDLERS) do pcall(eventFrame.RegisterEvent, eventFrame, event) end
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local ok, err = pcall(HANDLERS[event], ...)
	if not ok and ns.RecordError then ns:RecordError("journaltracker:" .. tostring(event), err) end
end)
ns.journalTrackerEventFrame = eventFrame

if ns.Mark then ns.Mark("JournalTracker") end
