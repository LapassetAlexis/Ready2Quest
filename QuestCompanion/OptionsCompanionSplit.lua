-- OptionsCompanionSplit.lua -- La page « Compagnon » des réglages, découpée (3.1.2)
--
-- Retour joueur : la page Compagnon était très longue (une vingtaine de
-- réglages : ceux de Companion.lua et ceux que d'autres fichiers y ajoutent,
-- style, raccourcis, blagues, lieux, Voile d'hiver, filet). Chargé en dernier,
-- ce fichier répartit ses lignes en quatre pages sous « Compagnon » :
--   * Compagnon : ce qu'on voit et où (afficher, style, taille, cadrage,
--     apparence, cadre, fond, Voile d'hiver, déplacer, filet) ;
--   * Discrétion : quand il s'efface (combat, donjon, vol, alerte d'aggro) ;
--   * Paroles : ce qu'il dit (bavardage, astuces, blagues, lieux, visite de
--     saison, tutoriel) ;
--   * Raccourcis : les touches du compagnon, du filet et du mode chasse.
-- Une ligne inconnue reste sur la page Compagnon. Aucun réglage ne change.
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L

local FR = {
	OPT_PAGE_COMPANION_QUIET     = "Discrétion",
	OPT_PAGE_COMPANION_QUIET_SUB = "Quand ton compagnon s'efface : en combat, en donjon, en vol, et son alerte d'aggro.",
	OPT_PAGE_COMPANION_TALK      = "Paroles",
	OPT_PAGE_COMPANION_TALK_SUB  = "Ce qu'il te dit : bavardage, astuces sur l'addon, blagues, histoire des lieux, tutoriel.",
	OPT_PAGE_COMPANION_KEYS      = "Raccourcis",
	OPT_PAGE_COMPANION_KEYS_SUB  = "Les touches pour le compagnon, le filet et le mode chasse.",
}
local EN = {
	OPT_PAGE_COMPANION_QUIET     = "Discretion",
	OPT_PAGE_COMPANION_QUIET_SUB = "When your companion steps aside: in combat, in dungeons, on flights, and its aggro alert.",
	OPT_PAGE_COMPANION_TALK      = "Chatter",
	OPT_PAGE_COMPANION_TALK_SUB  = "What it tells you: chatter, addon tips, jokes, place lore, tutorial.",
	OPT_PAGE_COMPANION_KEYS      = "Key bindings",
	OPT_PAGE_COMPANION_KEYS_SUB  = "Keys for the companion, the net and hunt mode.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.COMPANION_SPLIT_STRINGS = { fr = FR, en = EN } end

-- clé de la ligne -> page (absente : reste sur la page Compagnon)
ns.COMPANION_OPTION_SPLIT = {
	companionCombatFade = "companionQuiet", companionHideInstance = "companionQuiet",
	companionHideTaxi = "companionQuiet", companionAggroBlink = "companionQuiet",
	companionChatter = "companionTalk", companionDiscovery = "companionTalk", companionJokes = "companionTalk", companionShouts = "companionTalk",
	companionLore = "companionTalk", companionWinterVisit = "companionTalk", companionTutorial = "companionTalk",
	bindToggle = "companionKeys", bindNet = "companionKeys", bindHunt = "companionKeys",
}
local ORDER = { "companionQuiet", "companionTalk", "companionKeys" }
local TITLES = {
	companionQuiet = "OPT_PAGE_COMPANION_QUIET", companionTalk = "OPT_PAGE_COMPANION_TALK",
	companionKeys = "OPT_PAGE_COMPANION_KEYS",
}

local function FindPage(id)
	for index, page in ipairs(ns.OPTION_PAGES or {}) do
		if page.id == id then return page, index end
	end
	return nil
end

function ns:CompanionOptionsSplit()
	local main, mainIndex = FindPage("companionMain")
	if not (main and type(main.rows) == "table") or main.split then return false end
	local moved = { companionQuiet = {}, companionTalk = {}, companionKeys = {} }
	local keep = {}
	for _, row in ipairs(main.rows) do
		local target = ns.COMPANION_OPTION_SPLIT[row.key]
		if target and moved[target] then table.insert(moved[target], row) else table.insert(keep, row) end
	end
	main.rows, main.split = keep, true
	-- les nouvelles pages juste après « Compagnon », dans l'ordre
	local nextPage = ns.OPTION_PAGES[mainIndex + 1]
	for _, id in ipairs(ORDER) do
		if #moved[id] > 0 and not FindPage(id) then
			local def = { id = id, title = TITLES[id], parent = main.parent,
				group = main.group, rows = moved[id] }
			ns.AddOptionPage(def, nextPage and nextPage.id or nil)
		end
	end
	return true
end

ns:CompanionOptionsSplit()

if ns.Mark then ns.Mark("OptionsCompanionSplit") end
