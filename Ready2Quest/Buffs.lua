-- Buffs.lua -- découverte et suivi des buffs longue durée du joueur
--
-- Aucune liste de spellID n'est codée en dur : les buffs sont appris en
-- observant les auras du joueur. Ça couvre donc toutes les classes, y compris
-- celles qui n'existaient pas quand l'addon a été écrit.
local ADDON, ns = ...
local L = ns.L

local MIN_DURATION = 120   -- secondes : en dessous, c'est un proc, on ignore
local MAX_TRACKED  = 40
local MAX_SCAN      = 120

-- Lecture d'une aura par index : socle commun (Libs/Socle/World.lua).
local AuraByIndex = ns.AuraByIndex

-- ---------------------------------------------------------------------------
-- Familles de buffs. Sur Era, chaque rang a son propre spellID (Robustesse R5,
-- R6…) et la version de groupe porte un autre nom (Prière de robustesse, Don
-- du fauve, Bénédiction supérieure). On compare donc par famille : le nom,
-- normalisé, avec la version de groupe ramenée à la version simple.
-- ---------------------------------------------------------------------------
local FAMILY_ALIASES = {
	-- frFR
	["prière de robustesse"] = "mot de pouvoir : robustesse",
	["prière d'esprit"] = "esprit divin",
	["prière de protection contre l'ombre"] = "protection contre l'ombre",
	["don du fauve"] = "marque du fauve",
	["illumination des arcanes"] = "intelligence des arcanes",
	-- enUS
	["prayer of fortitude"] = "power word: fortitude",
	["prayer of spirit"] = "divine spirit",
	["prayer of shadow protection"] = "shadow protection",
	["gift of the wild"] = "mark of the wild",
	["arcane brilliance"] = "arcane intellect",
}
local GROUP_PREFIXES = {
	{ "bénédiction supérieure de ", "bénédiction de " },
	{ "bénédiction supérieure du ", "bénédiction du " },
	{ "bénédiction supérieure des ", "bénédiction des " },
	{ "greater blessing of ", "blessing of " },
}

-- Buffs de consommables : appris à tort (durée longue), puis signalés
-- « manquants » à chaque sortie. On ne les apprend pas.
local IGNORED_FAMILIES = {
	["bien nourri"] = true, ["well fed"] = true,
	["nourriture"] = true, ["boisson"] = true, ["food"] = true, ["drink"] = true,
}

-- Forever : auras du campement. Elles tiennent tant qu'on est au camp, puis
-- disparaissent : les apprendre ferait réclamer « Chaleur » à chaque départ.
-- Par numéro de sort, valable dans toutes les langues.
local IGNORED_SPELLS = {
	[1283391] = true,   -- Campfire Nearby
	[1289378] = true,   -- Warmth
	[1229741] = true,   -- Camp Benefits
	[1225478] = true,   -- Well Rested (talent de camp)
}
ns.IGNORED_BUFF_SPELLS = IGNORED_SPELLS

-- Gardée par nom : ScanBuffs la demande pour chaque aura et chaque buff
-- suivi toutes les 2 s (UNIT_AURA), chaque calcul fait plusieurs chaînes.
-- Les noms de buffs sont en nombre fini ; vidée au-delà de FAMILY_CACHE_MAX.
local familyCache, familyCount = {}, 0
local FAMILY_CACHE_MAX = 512
local function BuffFamily(name)
	if type(name) ~= "string" then return nil end
	local cached = familyCache[name]
	if cached then return cached end
	local key = ns.AsciiLower(name)
	key = FAMILY_ALIASES[key] or key
	for _, pair in ipairs(GROUP_PREFIXES) do
		if key:sub(1, #pair[1]) == pair[1] then key = pair[2] .. key:sub(#pair[1] + 1) end
	end
	if familyCount >= FAMILY_CACHE_MAX then familyCache, familyCount = {}, 0 end
	familyCache[name] = key
	familyCount = familyCount + 1
	return key
end
ns.BuffFamily = BuffFamily

-- Buffs exclusifs, toutes classes : un seul à la fois depuis le même lanceur
-- (le nouveau remplace l'ancien). Si l'un est actif, les autres du groupe ne
-- sont pas « manquants », et on n'en réclame qu'un : le dernier vu.
-- Noms normalisés (minuscules, version simple), frFR et enUS.
local EXCLUSIVE_GROUPS = {
	-- Paladin : une bénédiction par paladin, une aura, un sceau
	{ key = "blessing", prefixes = { "bénédiction de ", "bénédiction du ", "bénédiction des ",
		"blessing of " } },
	{ key = "paladin-aura", prefixes = { "aura de dévotion", "aura de vindicte", "aura de concentration",
		"aura de résistance", "aura de croisé", "aura de sainteté", "aura de rétribution",
		"devotion aura", "retribution aura", "concentration aura", "crusader aura", "sanctity aura" },
		suffixes = { " resistance aura" } },
	{ key = "seal", prefixes = { "sceau de ", "sceau du ", "sceau des ", "seal of " } },
	-- Mage : une armure, amplification ou atténuation
	{ key = "mage-armor", names = { "armure de givre", "armure de glace", "armure du mage",
		"armure de la fournaise", "armure de lave", "frost armor", "ice armor", "mage armor",
		"molten armor" } },
	{ key = "mage-magic", names = { "amplification de la magie", "atténuation de la magie",
		"amplify magic", "dampen magic" } },
	-- Démoniste : une peau / armure
	{ key = "warlock-armor", names = { "peau de démon", "armure démoniaque", "gangrarmure",
		"demon skin", "demon armor", "fel armor" } },
	-- Chaman : un bouclier sur soi
	{ key = "shaman-shield", names = { "bouclier de foudre", "bouclier d'eau", "lightning shield",
		"water shield" } },
	-- Guerrier : un cri à la fois
	{ key = "warrior-shout", names = { "cri de guerre", "cri de commandement", "battle shout",
		"commanding shout" } },
	-- Chasseur : un aspect
	{ key = "hunter-aspect", prefixes = { "aspect du ", "aspect de la ", "aspect des ", "aspect de l'",
		"aspect of the " } },
	-- Prêtre : feu intérieur ou volonté intérieure
	{ key = "priest-inner", names = { "feu intérieur", "volonté intérieure", "inner fire", "inner will" } },
	-- Druide : une forme
	{ key = "druid-form", names = { "forme d'ours", "forme d'ours redoutable", "forme de félin",
		"forme aquatique", "forme de voyage", "forme de sélénien", "bear form", "dire bear form",
		"cat form", "aquatic form", "travel form", "moonkin form" } },
}
local EXCLUSIVE_BY_NAME = {}
for _, group in ipairs(EXCLUSIVE_GROUPS) do
	for _, name in ipairs(group.names or {}) do EXCLUSIVE_BY_NAME[name] = group.key end
end

-- Groupe exclusif d'une famille (nil si le buff est indépendant)
local function ExclusiveGroup(family)
	if type(family) ~= "string" then return nil end
	if EXCLUSIVE_BY_NAME[family] then return EXCLUSIVE_BY_NAME[family] end
	for _, group in ipairs(EXCLUSIVE_GROUPS) do
		for _, prefix in ipairs(group.prefixes or {}) do
			if family:sub(1, #prefix) == prefix then return group.key end
		end
		for _, suffix in ipairs(group.suffixes or {}) do
			if #family > #suffix and family:sub(-#suffix) == suffix then return group.key end
		end
	end
	return nil
end
ns.BuffExclusiveGroup = ExclusiveGroup

-- ---------------------------------------------------------------------------
-- Buffs de classe (1.30.1) : qui peut les donner. Un buff de classe n'est
-- réclamé que si ta classe ou une classe de ton groupe le pose ; les autres
-- (élixirs, parchemins, objets, auras de monde) seulement sur le personnage
-- qui les a appris (la liste des buffs suivis est commune au compte).
-- Noms normalisés (BuffFamily), frFR et enUS.
-- ---------------------------------------------------------------------------
local GROUP_CLASS = {
	["blessing"] = "PALADIN", ["paladin-aura"] = "PALADIN", ["seal"] = "PALADIN",
	["mage-armor"] = "MAGE", ["mage-magic"] = "MAGE",
	["warlock-armor"] = "WARLOCK", ["shaman-shield"] = "SHAMAN",
	["warrior-shout"] = "WARRIOR", ["hunter-aspect"] = "HUNTER",
	["priest-inner"] = "PRIEST", ["druid-form"] = "DRUID",
}
local CLASS_BUFF_NAMES = {
	PRIEST = { "mot de pouvoir : robustesse", "power word: fortitude", "esprit divin", "divine spirit",
		"protection contre l'ombre", "shadow protection", "gardien de peur", "garde de peur", "fear ward",
		"mot de pouvoir : bouclier", "power word: shield", "rénovation", "renew" },
	MAGE = { "intelligence des arcanes", "arcane intellect", "protection contre le feu", "fire ward",
		"protection contre le givre", "frost ward", "bouclier de mana", "mana shield" },
	DRUID = { "marque du fauve", "mark of the wild", "épines", "thorns", "augure de clarté", "omen of clarity",
		"récupération", "rejuvenation" },
	WARLOCK = { "respiration interminable", "unending breath", "détection de l'invisibilité",
		"detect invisibility", "détection de l'invisibilité inférieure", "detect lesser invisibility" },
	HUNTER = { "aura de précision", "trueshot aura" },
	SHAMAN = { "marche sur l'eau", "water walking", "respiration aquatique", "water breathing" },
	WARRIOR = { "cri de démoralisation" },
}
local CLASS_BY_NAME = {}
for classFile, names in pairs(CLASS_BUFF_NAMES) do
	for _, name in ipairs(names) do CLASS_BY_NAME[name] = classFile end
end
ns.BUFF_CLASS_NAMES = CLASS_BUFF_NAMES

-- La classe qui pose ce buff (nom normalisé), ou nil s'il n'est pas de classe
local function BuffClass(family)
	if type(family) ~= "string" then return nil end
	if CLASS_BY_NAME[family] then return CLASS_BY_NAME[family] end
	local group = ExclusiveGroup(family)
	return group and GROUP_CLASS[group] or nil
end
ns.BuffClass = BuffClass

-- 1.31.0 : buffs qu'une classe ne pose que sur elle-même (Feu intérieur,
-- armures, boucliers, aspects, sceaux, formes, Augure de clarté…) : réclamés
-- seulement au personnage de cette classe, et s'il connaît le sort. Clés
-- écrites comme BuffFamily les produit (ns.AsciiLower garde les accents).
local SELF_ONLY_GROUPS = {
	["priest-inner"] = true, ["mage-armor"] = true, ["warlock-armor"] = true,
	["shaman-shield"] = true, ["hunter-aspect"] = true, ["seal"] = true, ["druid-form"] = true,
}
local SELF_ONLY_NAMES = {
	["augure de clarté"] = true, ["omen of clarity"] = true,
	["bouclier de mana"] = true, ["mana shield"] = true,
	["protection contre le feu"] = true, ["fire ward"] = true,
	["protection contre le givre"] = true, ["frost ward"] = true,
}
local function SelfOnly(family)
	if type(family) ~= "string" then return false end
	if SELF_ONLY_NAMES[family] then return true end
	local group = ExclusiveGroup(family)
	return group ~= nil and SELF_ONLY_GROUPS[group] == true
end
ns.BuffSelfOnly = SelfOnly

-- ---------------------------------------------------------------------------
-- 1.32.2 : réclamé par défaut, ou à activer. On réclamait « Force » (un
-- parchemin) et « Fureur vertueuse » (la posture de tank du paladin). Règle :
--   * buff de classe (BuffClass) : réclamé par défaut (puis BuffAvailability
--     dit si ta classe ou ton groupe peut le donner) ;
--   * posture du moment (TOGGLE_*) : Fureur vertueuse, camouflage, formes,
--     aspects, sceaux, auras de paladin, présences, postures… : pas par défaut ;
--   * consommable (CONSUMABLE_*) : parchemins, élixirs, flacons, potions…, ou
--     buff que tu t'es posé sans connaître le sort (il vient d'un objet) : pas
--     par défaut ;
--   * le reste (objets, auras de monde…) : pas par défaut.
-- Le joueur active ou coupe n'importe lequel dans la liste des buffs
-- (entry.userSet : son choix l'emporte sur la règle).
-- ---------------------------------------------------------------------------
local TOGGLE_GROUPS = {
	["druid-form"] = true, ["hunter-aspect"] = true, ["seal"] = true, ["paladin-aura"] = true,
}
local TOGGLE_NAMES = {}
for _, name in ipairs({ "fureur vertueuse", "righteous fury", "camouflage", "stealth", "rôder", "prowl",
	"forme d'ombre", "shadowform", "loup fantôme", "ghost wolf", "posture de combat", "posture défensive",
	"posture berserker", "battle stance", "defensive stance", "berserker stance", "présence de sang",
	"présence de givre", "présence impie", "blood presence", "frost presence", "unholy presence",
	"forme de voyage", "travel form", "forme aquatique", "aquatic form" }) do
	TOGGLE_NAMES[name] = true
end
-- Noms exacts (BuffFamily) des buffs de parchemins et d'élixirs courants
local CONSUMABLE_NAMES = {}
for _, name in ipairs({ "force", "strength", "agilité", "agility", "intelligence", "intellect", "esprit", "spirit",
	"endurance", "stamina", "protection", "armure", "armor", "agilité supérieure", "greater agility",
	"intelligence supérieure", "greater intellect", "armure supérieure", "greater armor", "santé ii", "health ii",
	"rage des âges", "rage of ages", "frappe du scorpok", "strike of the scorpok", "esprit de zanza",
	"spirit of zanza", "don d'arthas", "gift of arthas", "eau-de-feu de grumegueule", "winterfall firewater" }) do
	CONSUMABLE_NAMES[name] = true
end
-- (ns.AsciiLower ne baisse pas « É » : les deux formes)
local CONSUMABLE_PREFIXES = { "élixir", "Élixir", "elixir", "flacon", "flask", "potion", "philtre", "juju", "parchemin", "scroll" }

local function IsToggle(family)
	if type(family) ~= "string" then return false end
	if TOGGLE_NAMES[family] then return true end
	local group = ExclusiveGroup(family)
	return group ~= nil and TOGGLE_GROUPS[group] == true
end
ns.BuffIsToggle = IsToggle

local function IsConsumableName(family)
	if type(family) ~= "string" then return false end
	if CONSUMABLE_NAMES[family] then return true end
	for _, prefix in ipairs(CONSUMABLE_PREFIXES) do
		if family:sub(1, #prefix) == prefix then return true end
	end
	return false
end

-- Nature d'un buff suivi : "class", "toggle", "consumable" ou "other"
local KnowsSpell
local function BuffKind(spellId, entry)
	local family = BuffFamily(type(entry) == "table" and entry.name)
	if IsToggle(family) then return "toggle" end
	if IsConsumableName(family) then return "consumable" end
	if BuffClass(family) then return "class" end
	-- posé par toi, sans que tu connaisses le sort : il vient d'un objet
	if type(entry) == "table" and entry.self == true and KnowsSpell and not KnowsSpell(spellId) then
		return "consumable"
	end
	return "other"
end
ns.BuffKind = BuffKind

-- Réclamé ? Le choix du joueur, sinon la règle (buffs de classe seulement)
local function BuffEnabled(entry, spellId)
	if type(entry) ~= "table" then return false end
	if entry.userSet then return entry.enabled ~= false end
	return BuffKind(spellId, entry) == "class"
end
ns.BuffEnabled = BuffEnabled

-- Le joueur bascule un buff : son choix est retenu
function ns:BuffToggle(spellId)
	local entry = self:DB().buffs[spellId]
	if not entry then return nil end
	entry.enabled = not BuffEnabled(entry, spellId)
	entry.userSet = true
	return entry.enabled
end

-- Migration (schéma 2, 1.32.2) : jusqu'ici, tout buff appris était réclamé
-- (enabled = true) et seul « coupé » (enabled = false) venait du joueur.
-- Coupé : choix gardé ; le reste suit la nouvelle règle.
local BUFFS_SCHEMA = 2
function ns:MigrateBuffs(db)
	db = db or self:DB()
	if (tonumber(db.buffsSchema) or 1) >= BUFFS_SCHEMA then return false end
	for _, entry in pairs(type(db.buffs) == "table" and db.buffs or {}) do
		if type(entry) == "table" and not entry.userSet then
			if entry.enabled == false then entry.userSet = true else entry.enabled = nil end
		end
	end
	db.buffsSchema = BUFFS_SCHEMA
	return true
end

-- Un buff suivi qui n'a pas été vu depuis 7 jours n'est plus réclamé : buff
-- mondial ponctuel, ancien groupe, talent abandonné…
local FORGET_AFTER = 7 * 24 * 3600
local function WallClock()
	if type(time) == "function" then
		local ok, value = pcall(time)
		if ok and type(value) == "number" then return value end
	end
	return nil
end

-- Familles des auras actuellement sur le joueur
local function CurrentFamilies()
	local families, any = {}, false
	for i = 1, MAX_SCAN do
		local aura = AuraByIndex(i)
		if not aura then break end
		any = true
		local family = BuffFamily(aura.name)
		if family then
			families[family] = true
			local group = ExclusiveGroup(family)
			if group then families["group:" .. group] = true end
		end
	end
	return families, any
end

local function SortTracked(a, b)
	local an, bn = tostring(a.name or ""), tostring(b.name or "")
	if an == bn then return (a.spellId or 0) < (b.spellId or 0) end
	return an < bn
end

-- Liste triée des buffs suivis (utilisée par /sd buffs et /sd buff <n>)
function ns:TrackedBuffs()
	local db = self:DB()
	self:MigrateBuffs(db)
	local list = {}
	for spellId, entry in pairs(db.buffs) do
		list[#list + 1] = {
			spellId = spellId,
			name    = entry.name,
			enabled = BuffEnabled(entry, spellId),
			entry   = entry,
		}
	end
	table.sort(list, SortTracked)
	return list
end

-- Apprentissage : toute aura bénéfique d'au moins MIN_DURATION devient candidate.
function ns:ScanBuffs()
	local db = self:DB()
	if not db.enabled or db.learnBuffs == false then return end

	-- UNIT_AURA est très bavard : on ne scanne pas plus d'une fois toutes les 2 s.
	local now = ns.Now()
	if self.lastBuffScan and (now - self.lastBuffScan) < 2 then return end
	self.lastBuffScan = now

	-- table de travail réutilisée d'un passage à l'autre
	local count, known = 0, self.buffScanKnown
	if known then
		for k in pairs(known) do known[k] = nil end
	else
		known = {}
		self.buffScanKnown = known
	end
	for _, entry in pairs(db.buffs) do
		count = count + 1
		local family = BuffFamily(entry.name)
		if family then known[family] = entry end
	end

	local stamp = WallClock()
	for i = 1, MAX_SCAN do
		local aura = AuraByIndex(i)
		if not aura then break end

		local spellId = aura.spellId
		local duration = aura.duration
		local family = BuffFamily(aura.name)
		if family and known[family] then
			-- déjà suivi sous un autre rang ou en version de groupe : on note
			-- juste qu'il a été vu (et par qui)
			known[family].lastSeen = stamp
			ns.BuffNoteCaster(known[family], aura)
		elseif type(spellId) == "number" and spellId > 0
			and type(duration) == "number" and duration >= MIN_DURATION
			and not (family and IGNORED_FAMILIES[family])
			and not IGNORED_SPELLS[spellId]
			and not db.buffs[spellId] and count < MAX_TRACKED then
			db.buffs[spellId] = {
				name     = tostring(aura.name or ("spell:" .. spellId)),
				duration = duration,
				learned  = true,     -- 1.32.2 : réclamé selon BuffEnabled
				lastSeen = stamp,
			}
			ns.BuffNoteCaster(db.buffs[spellId], aura)
			if family then known[family] = db.buffs[spellId] end
			count = count + 1
		end
	end
end

-- ---------------------------------------------------------------------------
-- Qui peut le donner (1.30.0) : un buff appris d'un autre joueur (un cri de
-- guerrier reçu en groupe) n'est réclamé que si sa classe est là. Un buff que
-- tu poses toi-même (sort, nourriture, parchemin, élixir) l'est toujours.
-- ---------------------------------------------------------------------------
local function Plain(v) return ns.Plain and ns.Plain(v) or v end

-- Note le lanceur d'une aura sur la fiche du buff : self, ou sa classe
local function NoteCaster(entry, aura)
	if type(entry) ~= "table" or type(aura) ~= "table" then return end
	-- 1.30.1 : le personnage qui l'a eu (buffs hors classe : réclamés là seulement)
	if ns.CharKey then
		entry.chars = type(entry.chars) == "table" and entry.chars or {}
		entry.chars[ns:CharKey()] = true
	end
	local src = Plain(aura.sourceUnit)
	if Plain(aura.isFromPlayerOrPlayerPet) == true or src == "player" or src == "pet" or src == "vehicle" then
		entry.self, entry.casterClass = true, nil
		return
	end
	if entry.self or type(src) ~= "string" or type(UnitClass) ~= "function" then return end
	local ok, _, classFile = pcall(UnitClass, src)
	if ok and type(Plain(classFile)) == "string" then entry.casterClass = Plain(classFile) end
end
ns.BuffNoteCaster = NoteCaster

-- Les classes présentes : toi et ton groupe (ou raid) ; 1.31.0 : en
-- troisième, celles des AUTRES membres seulement (sans toi)
function ns:BuffGroupClasses()
	local classes, others = {}, {}
	local function Add(unit, other)
		if type(UnitClass) ~= "function" then return end
		local ok, _, classFile = pcall(UnitClass, unit)
		classFile = ok and Plain(classFile)
		if type(classFile) == "string" then
			classes[classFile] = true
			if other then others[classFile] = true end
		end
	end
	Add("player")
	local n = type(GetNumGroupMembers) == "function" and tonumber(Plain(GetNumGroupMembers())) or 0
	local raid = type(IsInRaid) == "function" and Plain(IsInRaid()) == true
	for i = 1, (raid and math.min(n, 40) or math.min(math.max(n - 1, 0), 4)) do
		local unit = (raid and "raid" or "party") .. i
		-- en raid, le joueur est aussi un « raidN »
		local isPlayer = raid and type(UnitIsUnit) == "function" and Plain(select(2, pcall(UnitIsUnit, unit, "player"))) == true
		Add(unit, not isPlayer)
	end
	return classes, n > 1, others
end

function KnowsSpell(spellId)
	for _, name in ipairs({ "IsPlayerSpell", "IsSpellKnown" }) do
		local fn = rawget(_G, name)
		if type(fn) == "function" then
			local ok, known = pcall(fn, spellId)
			if ok and Plain(known) == true then return true end
		end
	end
	return false
end

-- 1.31.0 : sort connu, cherché par son nom (la recherche par nom ne trouve
-- que les sorts du grimoire). nil : le client ne sait pas répondre.
local function KnowsByName(name)
	local api = rawget(_G, "C_Spell")
	local fn = (type(api) == "table" and type(api.GetSpellInfo) == "function" and api.GetSpellInfo)
		or rawget(_G, "GetSpellInfo")
	if type(fn) ~= "function" or type(name) ~= "string" then return nil end
	local ok, info = pcall(fn, name)
	if not ok then return nil end
	return Plain(info) ~= nil
end

local function SeenHere(entry)
	return type(entry.chars) == "table" and ns.CharKey ~= nil and entry.chars[ns:CharKey()] == true
end

-- Ce personnage connaît-il ce buff de classe ? Par l'identifiant, puis par
-- le nom (version de groupe et version simple) ; sans API par nom : posé par
-- toi, sur ce personnage (ou fiche d'avant la 1.30.1, sans personnages)
local function KnowsBuff(spellId, entry, family)
	if KnowsSpell(spellId) then return true end
	local byName = KnowsByName(entry.name)
	if byName ~= true and family then
		local byFamily = KnowsByName(family)
		if byFamily ~= nil then byName = byFamily or byName or false end
	end
	if byName == nil then return entry.self == true and (type(entry.chars) ~= "table" or SeenHere(entry)) end
	return byName
end

local function PlayerClass()
	local fn = ns.PlayerClassToken
	return type(fn) == "function" and Plain(fn()) or nil
end

-- Ce buff peut-il t'être donné maintenant ? ok, raison ("here", "self",
-- "class", "unknown", "other") et classe en cause. others : classes des
-- autres membres du groupe (BuffGroupClasses, troisième résultat).
function ns:BuffAvailability(spellId, entry, classes, grouped, others)
	classes, others = classes or {}, others or {}
	local family = BuffFamily(entry.name)
	-- 1.30.1 : un buff de classe ne vient que de cette classe (toi ou ton groupe)
	local cls = BuffClass(family)
	if cls then
		local mine = PlayerClass() == cls
		-- 1.31.0 : buff personnel : seulement au personnage de cette classe
		if SelfOnly(family) then
			if not mine then return false, "self", cls end
			if KnowsBuff(spellId, entry, family) then return true, "here", cls end
			return false, "unknown", cls
		end
		if others[cls] then return true, "here", cls end      -- un autre peut te le donner
		if mine then
			-- 1.31.0 : ta classe, mais sort pas connu (talent, rang) : pas ici
			if KnowsBuff(spellId, entry, family) then return true, "here", cls end
			return false, "unknown", cls
		end
		-- classes sans détail des autres (appel ancien) : la règle de la 1.30.1
		if classes[cls] then return true, "here", cls end
		return false, "class", cls
	end
	if KnowsSpell(spellId) then return true, "here" end
	-- hors classe (élixir, parchemin, objet…) : seulement sur le personnage qui
	-- l'a eu ; appris d'un joueur dont on connaît la classe : si elle est là
	if entry.casterClass and not entry.self then
		local here = classes[entry.casterClass] == true
		return here, here and "here" or "class", entry.casterClass
	end
	if SeenHere(entry) then return true, "here" end
	return false, "other"
end

function ns:BuffAvailable(spellId, entry, classes, grouped, others)
	return (self:BuffAvailability(spellId, entry, classes, grouped, others))
end

-- Nom de classe dans la langue du client (minuscule en français : « aucun
-- prêtre dans le groupe »)
function ns:ClassName(classFile)
	if type(classFile) ~= "string" then return "?" end
	local names = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
	local name = type(names) == "table" and Plain(names[classFile])
	if type(name) ~= "string" or name == "" then name = L["CLASS_" .. classFile] or classFile end
	local getLocale = rawget(_G, "GetLocale")
	if type(getLocale) == "function" and Plain(getLocale()) == "frFR" then
		name = name:gsub("^%u", string.lower)
	end
	return name
end

-- Retourne : manquants (table), suivis (nombre), illisibles (nombre)
function ns:EvaluateBuffs()
	local db = self:DB()
	self:MigrateBuffs(db)
	local missing, unknown, watched = {}, 0, 0
	local now = WallClock()
	local hasByID = C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function"
	local families = CurrentFamilies()
	local seen = {}
	local classes, grouped, others = self:BuffGroupClasses()

	-- Groupe exclusif : on ne réclame que le dernier vu (la bénédiction que
	-- le paladin pose d'habitude), pas la première trouvée au hasard.
	local groupPick = {}
	for spellId, entry in pairs(db.buffs) do
		local group = BuffEnabled(entry, spellId) and ExclusiveGroup(BuffFamily(entry.name))
		if group then
			local best = groupPick[group]
			local seenAt = type(entry.lastSeen) == "number" and entry.lastSeen or 0
			if not best or seenAt > best.seenAt
				or (seenAt == best.seenAt and spellId < best.spellId) then
				groupPick[group] = { spellId = spellId, seenAt = seenAt }
			end
		end
	end

	for spellId, entry in pairs(db.buffs) do
		local family = BuffFamily(entry.name) or tostring(spellId)
		local group = ExclusiveGroup(family)
		local skip = false
		if group then
			family = "group:" .. group
			skip = groupPick[group] and groupPick[group].spellId ~= spellId
		end
		local stale = now and entry.learned and type(entry.lastSeen) == "number"
			and (now - entry.lastSeen) > FORGET_AFTER
		if BuffEnabled(entry, spellId) and not skip and not stale and not seen[family]
			and self:BuffAvailable(spellId, entry, classes, grouped, others) then
			seen[family] = true
			watched = watched + 1
			local active = families[family] == true
			local readable = true

			if hasByID then
				-- une valeur secrète fait échouer l'appel : dans ce cas on ne
				-- sait pas, et on ne crie pas « manquant »
				local ok, res = pcall(function()
					return C_UnitAuras.GetPlayerAuraBySpellID(spellId) ~= nil
				end)
				if ok then
					active = active or res == true
				else
					readable = false
				end
			end
			if active and now then entry.lastSeen = now end

			if not readable then
				unknown = unknown + 1
			elseif not active then
				missing[#missing + 1] = entry.name or tostring(spellId)
			end
		end
	end

	table.sort(missing)
	return missing, watched, unknown
end

-- Diagnostic : dump des premiers champs d'aura, pour valider le contrat d'API
-- en jeu le jour du lancement.
function ns:DiagAuras()
	local printed = 0
	for i = 1, 8 do
		local aura = AuraByIndex(i)
		if not aura then break end
		self:Print(self:F("MSG_DIAG_AURA", i,
			tostring(aura.spellId), tostring(aura.duration), tostring(aura.name)))
		printed = printed + 1
	end
	if printed == 0 then
		self:Print(L.MSG_DIAG_NOAURA)
	end
end

if ns.Mark then ns.Mark("Buffs") end
