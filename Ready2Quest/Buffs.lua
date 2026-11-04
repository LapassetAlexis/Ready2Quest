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

local function BuffFamily(name)
	if type(name) ~= "string" then return nil end
	local key = ns.AsciiLower(name)
	key = FAMILY_ALIASES[key] or key
	for _, pair in ipairs(GROUP_PREFIXES) do
		if key:sub(1, #pair[1]) == pair[1] then key = pair[2] .. key:sub(#pair[1] + 1) end
	end
	return key
end
ns.BuffFamily = BuffFamily

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
		if family then families[family] = true end
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
	local list = {}
	for spellId, entry in pairs(db.buffs) do
		list[#list + 1] = {
			spellId = spellId,
			name    = entry.name,
			enabled = entry.enabled ~= false,
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

	local count, known = 0, {}
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
			-- juste qu'il a été vu
			known[family].lastSeen = stamp
		elseif type(spellId) == "number" and spellId > 0
			and type(duration) == "number" and duration >= MIN_DURATION
			and not (family and IGNORED_FAMILIES[family])
			and not IGNORED_SPELLS[spellId]
			and not db.buffs[spellId] and count < MAX_TRACKED then
			db.buffs[spellId] = {
				name     = tostring(aura.name or ("spell:" .. spellId)),
				duration = duration,
				enabled  = true,
				learned  = true,
				lastSeen = stamp,
			}
			if family then known[family] = db.buffs[spellId] end
			count = count + 1
		end
	end
end

-- Retourne : manquants (table), suivis (nombre), illisibles (nombre)
function ns:EvaluateBuffs()
	local db = self:DB()
	local missing, unknown, watched = {}, 0, 0
	local now = WallClock()
	local hasByID = C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function"
	local families = CurrentFamilies()
	local seen = {}

	for spellId, entry in pairs(db.buffs) do
		local family = BuffFamily(entry.name) or tostring(spellId)
		local stale = now and entry.learned and type(entry.lastSeen) == "number"
			and (now - entry.lastSeen) > FORGET_AFTER
		if entry.enabled ~= false and not stale and not seen[family] then
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
