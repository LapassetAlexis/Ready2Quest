-- Professions.lua -- Check avant le départ : un métier au plafond de son rang
-- (1.30.0, idée de Lex). Un métier bloqué à 75/75, 150/150 ou 225/225 ne
-- monte plus tant que tu n'as pas vu ton entraîneur : on le rappelle avant
-- de partir. 300 est le plafond du jeu : rien à rappeler.
local ADDON, ns = ...
local L = ns.L

local STRINGS_FR = {
	CHK_PROFCAP = "Métiers",
	CHK_PROFCAP_OK = "aucun au plafond",
	CHK_PROFCAP_CAPPED = "%s au plafond (%d/%d)",
	CHK_PROFCAP_MORE = "%s au plafond (%d/%d) et %d autre(s)",
	ADV_PROFCAP = "Un métier est au plafond de son rang : passe voir ton entraîneur pour continuer à progresser.",
}
local STRINGS_EN = {
	CHK_PROFCAP = "Professions",
	CHK_PROFCAP_OK = "none capped",
	CHK_PROFCAP_CAPPED = "%s capped (%d/%d)",
	CHK_PROFCAP_MORE = "%s capped (%d/%d) and %d more",
	ADV_PROFCAP = "A profession hit its rank cap: visit your trainer to keep improving it.",
}
if ns.KEEP_STRINGS then ns.PROFCAP_STRINGS = { fr = STRINGS_FR, en = STRINGS_EN } end
if ns.RegisterStrings then ns.RegisterStrings(STRINGS_FR, STRINGS_EN) end

-- plafonds de rang qu'un entraîneur fait monter (300 : le maximum du jeu)
ns.PROFESSION_TRAIN_CAPS = { [75] = true, [150] = true, [225] = true }
-- en-têtes de la fenêtre de compétences qui rangent les métiers (FR/EN) ; les
-- compétences d'armes, elles aussi plafonnées (niveau × 5), sont ailleurs
-- (fragments sans première lettre : ni majuscule ni lower(), qui abîme les
-- accents selon le client)
local HEADER_HINTS = { "rofession", "étier", "etier", "econda" }

local function IsProfessionHeader(name)
	if type(name) ~= "string" then return false end
	for _, hint in ipairs(HEADER_HINTS) do
		if name:find(hint, 1, true) then return true end
	end
	return false
end

-- Les métiers au plafond de leur rang : { { name, rank, max }, … }. Second
-- retour : false si l'API de la fenêtre de compétences manque.
function ns:ProfessionCaps()
	local list = {}
	local count, info = rawget(_G, "GetNumSkillLines"), rawget(_G, "GetSkillLineInfo")
	if type(count) ~= "function" or type(info) ~= "function" then return list, false end
	local ok, total = pcall(count)
	if not ok or type(total) ~= "number" then return list, false end
	local inProfessions = false
	for index = 1, total do
		local okLine, name, isHeader, _, rank, _, _, maxRank = pcall(info, index)
		if okLine and type(name) == "string" then
			if isHeader == true or isHeader == 1 then
				inProfessions = IsProfessionHeader(name)
			elseif inProfessions then
				rank, maxRank = tonumber(rank) or 0, tonumber(maxRank) or 0
				if ns.PROFESSION_TRAIN_CAPS[maxRank] and rank >= maxRank then
					list[#list + 1] = { name = name, rank = rank, max = maxRank }
				end
			end
		end
	end
	return list, true
end

if ns.AddCheck then
	ns.AddCheck{
		id = "profcap",
		-- seulement si la fenêtre de compétences répond
		active = function()
			local _, available = ns:ProfessionCaps()
			return available
		end,
		icon = "Interface\\Icons\\INV_Misc_Note_01",
		weight = 3,
		advice = "ADV_PROFCAP",
		label = function() return L.CHK_PROFCAP end,
		run = function()
			local capped = ns:ProfessionCaps()
			local first = capped[1]
			if not first then return true, L.CHK_PROFCAP_OK, 100 end
			if #capped > 1 then
				return false, ns:F("CHK_PROFCAP_MORE", first.name, first.rank, first.max, #capped - 1), 60
			end
			return false, ns:F("CHK_PROFCAP_CAPPED", first.name, first.rank, first.max), 60
		end,
	}
end
