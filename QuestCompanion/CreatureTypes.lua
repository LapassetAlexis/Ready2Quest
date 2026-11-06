-- CreatureTypes.lua -- types de créature (QuestCompanion 2.0, base commune)
--
-- Le client donne le type d'une créature en clair et dans sa langue
-- (UnitCreatureType : « Bête », « Beast »…). Les systèmes de la 2.0 (effets du
-- compagnon, complétion par type, missions par type) travaillent sur une clé
-- stable : beast, humanoid, undead, elemental, dragonkin, demon, giant,
-- mechanical. ns:CreatureTypeKey(texte) -> clé ou nil.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

ns.CREATURE_TYPES = { "beast", "humanoid", "undead", "elemental", "dragonkin", "demon", "giant", "mechanical" }

local FR = {
	CTYPE_beast = "Bête", CTYPE_humanoid = "Humanoïde", CTYPE_undead = "Mort-vivant",
	CTYPE_elemental = "Élémentaire", CTYPE_dragonkin = "Draconien", CTYPE_demon = "Démon",
	CTYPE_giant = "Géant", CTYPE_mechanical = "Mécanique",
}
local EN = {
	CTYPE_beast = "Beast", CTYPE_humanoid = "Humanoid", CTYPE_undead = "Undead",
	CTYPE_elemental = "Elemental", CTYPE_dragonkin = "Dragonkin", CTYPE_demon = "Demon",
	CTYPE_giant = "Giant", CTYPE_mechanical = "Mechanical",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.CREATURE_TYPE_STRINGS = { fr = FR, en = EN } end

-- noms du client (français et anglais, minuscules ASCII) -> clé
local BY_NAME = {}
for key, name in pairs(FR) do BY_NAME[ns.AsciiLower(name)] = key:gsub("^CTYPE_", "") end
for key, name in pairs(EN) do BY_NAME[ns.AsciiLower(name)] = key:gsub("^CTYPE_", "") end
-- autres noms possibles selon la version du client
BY_NAME[ns.AsciiLower("Machine")] = "mechanical"
BY_NAME[ns.AsciiLower("Machines")] = "mechanical"

function ns:CreatureTypeKey(text)
	-- ns.Plain d'abord : comparer une valeur secrète (même à "") lève une erreur
	if ns.Plain then text = ns.Plain(text) end
	if type(text) ~= "string" or text == "" then return nil end
	return BY_NAME[ns.AsciiLower(text)]
end

-- Libellé dans la langue du client
function ns:CreatureTypeLabel(key)
	return L["CTYPE_" .. tostring(key)]
end

if ns.Mark then ns.Mark("CreatureTypes") end
