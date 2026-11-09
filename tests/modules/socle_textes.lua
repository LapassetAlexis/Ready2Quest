-- Socle 2.11.0 / Ready2Quest 1.32.0 (fiche 28) : codes couleur du texte
-- déclarés une fois (ns.TC, Base.lua), messages du chat traduits.
local Check, Say, NS, QNS = T.Check, T.Say, T.NS, T.QNS
local Theme = NS.Theme
local ROOT = rawget(_G, "ADDON_ROOT") or "."

local function ReadFile(path)
	local h = io.open(ROOT .. "/" .. path, "rb")
	if not h then return nil end
	local data = h:read("*a")
	h:close()
	return data
end

Say("-- fiche 28 : couleurs et textes en dur")
Check("[F28] ns.TC : alias Theme.T_*", NS.TC and NS.TC.GREY == Theme.T_GREY and NS.TC.RED == Theme.T_RED
	and NS.TC.GOLD == Theme.T_GOLD and NS.TC.BLUE == Theme.T_BLUE)
Check("[F28] QuestCompanion : son propre ns.TC, mêmes codes", QNS and QNS.TC and QNS.TC.GREY == NS.TC.GREY)

-- plus aucun code |cff écrit à la main dans ces fichiers (couleurs : ns.TC,
-- Theme.T_*, Theme.Hex). Les deux seuls endroits permis : Base.lua (ns.TC) et
-- Config.lua (avant le socle).
local CLEAN = {
	"Ready2Quest/Libs/Socle/Strings.lua", "Ready2Quest/Libs/Socle/Commands.lua", "Ready2Quest/Libs/Socle/Compat.lua",
	"Ready2Quest/Libs/Socle/Theme.lua", "Ready2Quest/Locales.lua", "Ready2Quest/Core.lua", "Ready2Quest/Reagents.lua",
	"Ready2Quest/OptionPages.lua", "QuestCompanion/Locales.lua", "QuestCompanion/Tooltips.lua", "QuestCompanion/GuildFeats.lua",
	"QuestCompanion/JournalCompletion.lua",
}
local dirty = {}
for _, path in ipairs(CLEAN) do
	local src = ReadFile(path) or ""
	for line in src:gmatch("[^\n]+") do
		-- les commentaires peuvent citer un code
		local code = line:gsub("%-%-.*$", "")
		if code:find("|cff%x%x%x%x%x%x") then dirty[#dirty + 1] = path .. " : " .. line:gsub("^%s+", "") end
	end
end
Check("[F28] aucun |cff en dur hors Base.lua et Config.lua", #dirty == 0, table.concat(dirty, " / "))

-- les nouvelles clés existent en français ET en anglais
local KEYS = { "MSG_DIAG_MODULES", "MSG_DIAG_MISSING", "MSG_DIAG_ERROR", "MSG_DIAG_WHERE", "MSG_DIAG_UNSUPPORTED",
	"MSG_CLIENT_MODERN", "MSG_CLIENT_UNKNOWN", "CHK_REAGENTS_HOWTO", "REAGENT_CRAFTABLE", "REAGENT_BLOCKED",
	"REAGENT_MISSING_ROW", "PACE_ROW" }
local function Has(src, key, english)
	-- deux déclarations dans le fichier (frFR puis enUS) : la seconde est l'anglaise
	local first = src:find("\n%s*" .. key .. "%s*=")
	if not first then return false end
	if not english then return true end
	return src:find("\n%s*" .. key .. "%s*=", first + 1) ~= nil
end
local all = (ReadFile("Ready2Quest/Libs/Socle/Strings.lua") or "") .. (ReadFile("Ready2Quest/Locales.lua") or "")
	.. (ReadFile("Ready2Quest/LevelPace.lua") or "")
local missing = {}
for _, key in ipairs(KEYS) do
	if not Has(all, key, true) then missing[#missing + 1] = key end
end
local best = ReadFile("QuestCompanion/Bestiary.lua") or ""
for _, key in ipairs({ "BESTIARY_DIAG", "BESTIARY_DIAG_CLOG" }) do
	if not Has(best, key, true) then missing[#missing + 1] = key end
end
Check("[F28] nouvelles clés en FR et en EN", #missing == 0, table.concat(missing, ", "))
Check("[F28] client français : diagnostic en français", NS:F("MSG_DIAG_MODULES", "", 3, 4):find("chargés", 1, true) ~= nil)
Check("[F28] rythme : espace française", NS:F("PACE_ROW", "Repos", "x") == "Repos : x")

-- messages de démarrage (avant Strings.lua) : table bilingue de Base.lua
local base = ReadFile("Ready2Quest/Libs/Socle/Base.lua") or ""
Check("[F28] démarrage : « files loaded » sur un client anglais", base:find('LOADED = "%%s — files loaded"') ~= nil
	and base:find('LOADED = "%%s — fichiers chargés"') ~= nil)
Check("[F28] démarrage : table choisie (client du test : frFR)", NS.BOOT_STRINGS and NS.BOOT_STRINGS.LOADED:find("chargés", 1, true) ~= nil)
local cfg = ReadFile("QuestCompanion/Config.lua") or ""
Check("[F28] ancien Ready2Quest : message anglais", cfg:find("already contains the companion", 1, true) ~= nil)
