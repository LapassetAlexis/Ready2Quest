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

-- Lit une aura du joueur par index. Retourne nil si l'API manque ou si la
-- valeur est secrète (restriction de type SecretWhenUnitAuraRestricted).
local function AuraByIndex(index)
	if C_UnitAuras and type(C_UnitAuras.GetAuraDataByIndex) == "function" then
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
		if ok then return aura end
		-- repli : l'API namespacée existe mais a refusé l'appel
	end
	if type(UnitAura) == "function" then
		local ok, name, _, _, _, duration, _, _, spellId = pcall(UnitAura, "player", index, "HELPFUL")
		if ok and name then
			return { name = name, duration = duration, spellId = spellId }
		end
	end
	return nil
end
ns.AuraByIndex = AuraByIndex

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

	local count = 0
	for spellId in pairs(db.buffs) do count = count + 1 end
	if count >= MAX_TRACKED then return end

	for i = 1, MAX_SCAN do
		local aura = AuraByIndex(i)
		if not aura then break end

		local spellId = aura.spellId
		local duration = aura.duration
		if type(spellId) == "number" and spellId > 0
			and type(duration) == "number" and duration >= MIN_DURATION
			and not db.buffs[spellId] then
			db.buffs[spellId] = {
				name     = tostring(aura.name or ("spell:" .. spellId)),
				duration = duration,
				enabled  = true,
				learned  = true,
			}
			count = count + 1
			if count >= MAX_TRACKED then break end
		end
	end
end

-- Retourne : manquants (table), suivis (nombre), illisibles (nombre)
function ns:EvaluateBuffs()
	local db = self:DB()
	local missing, unknown, watched = {}, 0, 0

	for spellId, entry in pairs(db.buffs) do
		if entry.enabled ~= false then
			watched = watched + 1
			local active = false
			local readable = false

			if C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function" then
				local ok, res = pcall(function()
					return C_UnitAuras.GetPlayerAuraBySpellID(spellId) ~= nil
				end)
				if ok then
					readable = true
					active = res == true
				end
			end

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
