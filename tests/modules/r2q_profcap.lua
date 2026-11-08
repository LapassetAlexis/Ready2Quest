-- Ready2Quest 1.30.0 : Check avant le départ, métier au plafond de son rang
-- (Professions.lua, idée de Lex).
local Check, ResetWorld, NS = T.Check, T.ResetWorld, T.NS

local savedNum, savedInfo = rawget(_G, "GetNumSkillLines"), rawget(_G, "GetSkillLineInfo")
local skills = {}
_G.GetNumSkillLines = function() return #skills end
-- name, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank
_G.GetSkillLineInfo = function(index)
	local s = skills[index]
	if not s then return nil end
	return s[1], s[2] == true, true, s[3] or 0, 0, 0, s[4] or 0
end

local function Def()
	for _, def in ipairs(NS.checks or {}) do if def.id == "profcap" then return def end end
end

do
	T.Say("-- R2Q : métiers au plafond")
	ResetWorld()
	local def = Def()
	Check("[PROF] contrôle déclaré, textes FR/EN", def ~= nil and NS.PROFCAP_STRINGS ~= nil
		and NS.PROFCAP_STRINGS.en.CHK_PROFCAP == "Professions")
	skills = {
		{ "Métiers", true },
		{ "Minage", false, 75, 75 },
		{ "Herboristerie", false, 60, 150 },
		{ "Compétences secondaires", true },
		{ "Cuisine", false, 150, 150 },
		{ "Compétences d'armes", true },
		{ "Épées", false, 75, 75 },        -- arme plafonnée au niveau : pas un métier
	}
	local capped = NS:ProfessionCaps()
	Check("[PROF] métiers au plafond seulement (pas les armes)", #capped == 2 and capped[1].name == "Minage"
		and capped[2].name == "Cuisine")
	local ok, detail = def.run()
	Check("[PROF] rappel : le premier et le compte des autres", ok == false and detail:find("Minage", 1, true)
		and detail:find("75/75", 1, true) and detail:find("1 autre", 1, true), detail)
	skills = { { "Professions", true }, { "Mining", false, 300, 300 }, { "Herbalism", false, 120, 150 } }
	ok, detail = def.run()
	Check("[PROF] 300/300 : plafond du jeu, rien à rappeler", ok == true and detail == NS.L.CHK_PROFCAP_OK, detail)
	Check("[PROF] actif quand la fenêtre de compétences répond", def.active() == true)
	_G.GetNumSkillLines = nil
	Check("[PROF] API absente : contrôle inactif", def.active() == false)
end

_G.GetNumSkillLines, _G.GetSkillLineInfo = savedNum, savedInfo
