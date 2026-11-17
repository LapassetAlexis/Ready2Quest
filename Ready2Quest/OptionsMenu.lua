-- OptionsMenu.lua -- le menu des réglages de Ready2Quest (2.0.0)
--
-- Maquette validée le 2026-11-17 : six familles fixes dans la colonne
-- (Accueil, Check avant le départ, Sacs & butin, Voyage, Quêtes & sorts,
-- Combat), leurs onglets en haut, une tête par fonction avec son
-- interrupteur. La navigation par familles est dans le socle
-- (Libs/Socle/Options.lua, ns.OPTION_FAMILIES) ; QuestCompanion garde la
-- navigation par pages.
--
-- Les modules déclarent toujours leurs pages (ns.AddOptionPage) et y
-- ajoutent leurs lignes : ce fichier, chargé après eux (dernier du TOC), les
-- range dans les familles à la première ouverture. Une ligne qu'un module
-- ajoute plus tard à sa page suit sa page (Rest) ; une clé qui devient
-- l'interrupteur d'une fonction quitte les lignes (le « Activer » en double).
--
-- Règles : aucune entrée de plus dans la colonne (un futur module devient
-- une section ou un onglet d'une famille, cinq onglets au plus) ; aucun
-- réglage nouveau, seulement leur place.
local ADDON, ns = ...
local L = ns.L

local FR = {
	OPT_FAM_HOME          = "Accueil",
	OPT_FAM_HOME_SUB      = "Tout voir, tout couper",
	OPT_FAM_HOME_POWER    = "Addon actif",
	OPT_FAM_CHECK         = "Check avant le départ",
	OPT_FAM_CHECK_SUB     = "Ta note avant de partir",
	OPT_FAM_CHECK_POWER   = "Check actif",
	OPT_FAM_BAGS          = "Sacs & butin",
	OPT_FAM_BAGS_SUB      = "Marchand, favoris, sacs",
	OPT_FAM_TRAVEL        = "Voyage",
	OPT_FAM_TRAVEL_SUB    = "Retour, mort, camp, donjon",
	OPT_FAM_QUESTS        = "Quêtes & sorts",
	OPT_FAM_QUESTS_SUB    = "Récompenses, XP, rangs",
	OPT_FAM_COMBAT        = "Combat",
	OPT_FAM_COMBAT_SUB    = "Aggro, portée, DoT, barres",

	OPT_TAB_OVERVIEW      = "Vue d'ensemble",
	OPT_TAB_OVERVIEW_SUB  = "Tout ce que fait Ready2Quest. Coupe ce qui ne te sert pas, clique un nom pour le régler.",
	OPT_TAB_GENERAL       = "Général",
	OPT_TAB_GENERAL_SUB   = "L'interface de l'addon : minicarte, cadres, style, et l'autre addon du projet.",
	OPT_TAB_WHEN          = "Quand & où",
	OPT_TAB_WHEN_SUB      = "Quand le check part, d'où, et comment il s'affiche.",
	OPT_TAB_MERCHANT      = "Marchand & favoris",
	OPT_TAB_MERCHANT_SUB  = "Chez un marchand : vendre les gris, réparer. Et les objets que tu veux toujours garder.",
	OPT_TAB_FULL          = "Sac plein & butin",
	OPT_TAB_FULL_SUB      = "Sacs pleins en route ou devant un butin : quoi jeter, et ramasser plus vite.",
	OPT_TAB_RETURN        = "Retour & mort",
	OPT_TAB_RETURN_SUB    = "Le bilan quand tu rentres en ville, et le conseil quand tu meurs.",
	OPT_TAB_CAMP_SUB      = "Feu de camp et objets de métier (Forever) : au camp, et en le quittant.",
	OPT_TAB_DUNGEON       = "Donjon & groupe",
	OPT_TAB_DUNGEON_SUB   = "Devant un donjon : ses quêtes, ton niveau, ta préparation, et qui est prêt.",
	OPT_TAB_XP            = "Quêtes & XP",
	OPT_TAB_XP_SUB        = "La récompense de quête qui te sert, et ton rythme vers le prochain niveau.",
	OPT_TAB_SPELLS        = "Sorts",
	OPT_TAB_SPELLS_SUB    = "Un sort de tes barres a un meilleur rang, et tout apprendre chez un maître.",
	OPT_TAB_RANGES        = "Portées",
	OPT_TAB_RANGES_SUB    = "À quelle distance un monstre te saute dessus, et si ta cible est à portée de tes sorts.",
	OPT_TAB_DOTS          = "DoT mortels",
	OPT_TAB_CAST          = "Prédiction",
	OPT_TAB_BARS          = "Chiffres des barres",

	OPT_SEC_CHECKS        = "Ce que le check vérifie",
	OPT_SEC_THRESHOLDS    = "Seuils",
	OPT_SEC_MYBUFFS       = "Tes buffs",
	OPT_SEC_CHECK_DISPLAY = "Affichage du check",
	OPT_SEC_SAFE          = "Zones sûres : villages et capitales appris",
	OPT_SEC_INTERFACE     = "Interface",
	OPT_SEC_RESET         = "Remise à zéro",
	OPT_SEC_FAVORITES     = "Favoris",
	OPT_SEC_QUICKLOOT     = "Butin rapide",
	OPT_SEC_GROUPREADY    = "Groupe prêt",
	OPT_SEC_TRAINALL      = "Tout apprendre",
	OPT_SEC_RANGE_SUB     = "Coche verte ou croix rouge au-dessus de ta cible ; les icônes des barres se grisent hors de portée.",
	OPT_SEC_CAST_SUB      = "Pendant l'incantation, les dégâts attendus sur la barre de vie ; une icône si le sort tue.",
	OPT_SEC_AGGRO_SUB     = "À quelle distance un monstre te saute dessus : dans son infobulle et sur sa barre de nom.",
	OPT_SEC_GROUPREADY_SUB = "En groupe, la fiche montre qui est sur place et qui est prêt (membres avec Ready2Quest).",
	OPT_SEC_TRAINALL_SUB  = "Chez un maître de classe ou de métier : un bouton qui apprend tout ce qui est disponible.",
	OPT_SEC_QUICKLOOT_SUB = "Avec le butin automatique du jeu : tout est ramassé d'un coup, sans le délai entre deux objets.",

	OPT_LINK_CAMP         = "Le kit de camp ajoute 2 contrôles au check",
	OPT_LINK_CAMP_BTN     = "Kit de camp",
	OPT_RESET_ALL         = "Remettre tous les réglages à zéro",
	OPT_RESET_ALL_BTN     = "Tout réinitialiser…",
	OPT_RESET_ALL_NOTE    = "Demande une confirmation. Tes zones sûres et tes buffs appris sont effacés aussi.",
	OPT_RESET_ALL_ASK     = "Remettre tous les réglages de Ready2Quest à zéro ? Zones sûres et buffs appris compris.",
	OPT_RESET_ALL_YES     = "Tout réinitialiser",
	OPT_DASH_SELLGRAY     = "Vente des gris",
	OPT_DASH_REPAIR       = "Réparation",
	OPT_DASH_FAVORITES    = "%d objet(s)",
	OPT_DASH_SCORE        = "dernière note : %d / 100",
	HELP_OPTIONS_WORD     = "/r2q options <mot> -- ouvre les réglages sur ce lieu (butin, combat, zones…)",
}
local EN = {
	OPT_FAM_HOME          = "Home",
	OPT_FAM_HOME_SUB      = "See everything, switch off",
	OPT_FAM_HOME_POWER    = "Addon on",
	OPT_FAM_CHECK         = "Departure check",
	OPT_FAM_CHECK_SUB     = "Your score before leaving",
	OPT_FAM_CHECK_POWER   = "Check on",
	OPT_FAM_BAGS          = "Bags & loot",
	OPT_FAM_BAGS_SUB      = "Merchant, favorites, bags",
	OPT_FAM_TRAVEL        = "Travel",
	OPT_FAM_TRAVEL_SUB    = "Return, death, camp, dungeon",
	OPT_FAM_QUESTS        = "Quests & spells",
	OPT_FAM_QUESTS_SUB    = "Rewards, XP, ranks",
	OPT_FAM_COMBAT        = "Combat",
	OPT_FAM_COMBAT_SUB    = "Aggro, range, DoTs, bars",

	OPT_TAB_OVERVIEW      = "Overview",
	OPT_TAB_OVERVIEW_SUB  = "Everything Ready2Quest does. Switch off what you don't use, click a name to set it up.",
	OPT_TAB_GENERAL       = "General",
	OPT_TAB_GENERAL_SUB   = "The addon's interface: minimap, frames, style, and the project's other addon.",
	OPT_TAB_WHEN          = "When & where",
	OPT_TAB_WHEN_SUB      = "When the check fires, from where, and how it shows.",
	OPT_TAB_MERCHANT      = "Merchant & favorites",
	OPT_TAB_MERCHANT_SUB  = "At a merchant: sell greys, repair. And the items you always want to keep.",
	OPT_TAB_FULL          = "Full bags & loot",
	OPT_TAB_FULL_SUB      = "Full bags on the road or in front of loot: what to drop, and looting faster.",
	OPT_TAB_RETURN        = "Return & death",
	OPT_TAB_RETURN_SUB    = "The report when you get back to town, and the advice when you die.",
	OPT_TAB_CAMP_SUB      = "Campfire and profession objects (Forever): at camp, and when you leave it.",
	OPT_TAB_DUNGEON       = "Dungeon & group",
	OPT_TAB_DUNGEON_SUB   = "At a dungeon: its quests, your level, your readiness, and who is ready.",
	OPT_TAB_XP            = "Quests & XP",
	OPT_TAB_XP_SUB        = "The quest reward that suits you, and your pace to the next level.",
	OPT_TAB_SPELLS        = "Spells",
	OPT_TAB_SPELLS_SUB    = "A spell on your bars has a higher rank, and learning everything at a trainer.",
	OPT_TAB_RANGES        = "Ranges",
	OPT_TAB_RANGES_SUB    = "How close a monster jumps on you, and whether your target is in range of your spells.",
	OPT_TAB_DOTS          = "Lethal DoTs",
	OPT_TAB_CAST          = "Prediction",
	OPT_TAB_BARS          = "Bar numbers",

	OPT_SEC_CHECKS        = "What the check looks at",
	OPT_SEC_THRESHOLDS    = "Thresholds",
	OPT_SEC_MYBUFFS       = "Your buffs",
	OPT_SEC_CHECK_DISPLAY = "Check display",
	OPT_SEC_SAFE          = "Safe areas: villages and capitals learned",
	OPT_SEC_INTERFACE     = "Interface",
	OPT_SEC_RESET         = "Reset",
	OPT_SEC_FAVORITES     = "Favorites",
	OPT_SEC_QUICKLOOT     = "Fast loot",
	OPT_SEC_GROUPREADY    = "Group ready",
	OPT_SEC_TRAINALL      = "Learn all",
	OPT_SEC_RANGE_SUB     = "Green check or red cross above your target; action bar icons grey out when out of range.",
	OPT_SEC_CAST_SUB      = "While you cast, the expected damage on the health bar; an icon if the spell kills.",
	OPT_SEC_AGGRO_SUB     = "How close a monster jumps on you: in its tooltip and on its nameplate.",
	OPT_SEC_GROUPREADY_SUB = "In a group, the sheet shows who is there and who is ready (members running Ready2Quest).",
	OPT_SEC_TRAINALL_SUB  = "At a class or profession trainer: one button that learns everything available.",
	OPT_SEC_QUICKLOOT_SUB = "With the game's auto loot: everything is picked up at once, without the delay between items.",

	OPT_LINK_CAMP         = "The camp kit adds 2 checks to the check",
	OPT_LINK_CAMP_BTN     = "Camp kit",
	OPT_RESET_ALL         = "Reset every setting",
	OPT_RESET_ALL_BTN     = "Reset all…",
	OPT_RESET_ALL_NOTE    = "Asks for confirmation. Your safe areas and learned buffs are erased too.",
	OPT_RESET_ALL_ASK     = "Reset every Ready2Quest setting? Safe areas and learned buffs included.",
	OPT_RESET_ALL_YES     = "Reset all",
	OPT_DASH_SELLGRAY     = "Grey selling",
	OPT_DASH_REPAIR       = "Repairs",
	OPT_DASH_FAVORITES    = "%d item(s)",
	OPT_DASH_SCORE        = "last score: %d / 100",
	HELP_OPTIONS_WORD     = "/r2q options <word> -- opens the settings on that place (loot, combat, safe…)",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.OPTIONS_MENU_STRINGS = { fr = FR, en = EN } end
if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then table.insert(section[2], "HELP_OPTIONS_WORD") end
	end
end

-- Icônes du client, par référence (aucune image livrée)
ns.OPTION_ICONS = {
	home   = "Interface\\Icons\\INV_Misc_Rune_01",
	check  = "Interface\\Icons\\INV_Misc_Note_01",
	sacs   = "Interface\\Icons\\INV_Misc_Bag_08",
	voyage = "Interface\\Icons\\INV_Misc_Map_01",
	quetes = "Interface\\Icons\\INV_Misc_Book_09",
	combat = "Interface\\Icons\\Ability_DualWield",
}

-- ---------------------------------------------------------------------------
-- Les lignes des pages déclarées par les modules
-- ---------------------------------------------------------------------------
local function Page(id)
	for _, def in ipairs(ns.OPTION_PAGES or {}) do
		if def.id == id then return def end
	end
	return nil
end

-- les lignes `keys` de la page, dans cet ordre
local function Pick(id, keys)
	local rows, page = {}, Page(id)
	for _, key in ipairs(keys) do
		for _, row in ipairs(page and page.rows or {}) do
			if row.key == key then rows[#rows + 1] = row; break end
		end
	end
	return rows
end

-- toutes les lignes de la page sauf `drop` (et ses titres de section)
local function Rest(id, drop)
	local skip, rows, page = {}, {}, Page(id)
	for _, key in ipairs(drop or {}) do skip[key] = true end
	for _, row in ipairs(page and page.rows or {}) do
		if not row.header and not skip[row.key] then rows[#rows + 1] = row end
	end
	return rows
end

local function Field(id, name)
	local page = Page(id)
	return page and page[name]
end

local function Without(list, drop)
	local out = {}
	for _, v in ipairs(list or {}) do if v ~= drop then out[#out + 1] = v end end
	return out
end

local function Concat(a, b)
	local list = {}
	for _, v in ipairs(a or {}) do list[#list + 1] = v end
	for _, v in ipairs(b or {}) do list[#list + 1] = v end
	return list
end

-- ---------------------------------------------------------------------------
-- Les familles
-- ---------------------------------------------------------------------------
local function Families()
	local I = ns.OPTION_ICONS
	return {
		{
			id = "home", title = "OPT_FAM_HOME", heading = "Ready2Quest", sub = "OPT_FAM_HOME_SUB", icon = I.home,
			power = "enabled", powerLabel = "OPT_FAM_HOME_POWER",
			tabs = {
				{ id = "overview", label = "OPT_TAB_OVERVIEW", phrase = "OPT_TAB_OVERVIEW_SUB", kind = "dashboard",
					columns = { { "check", "sacs" }, { "voyage", "quetes", "combat" } } },
				{ id = "general", label = "OPT_TAB_GENERAL", phrase = "OPT_TAB_GENERAL_SUB", sections = {
					{ id = "display", title = "OPT_SEC_INTERFACE", oldNames = { "OPT_PAGE_GENERAL" },
						rows = Pick("general", { "showMinimap", "minimapPos", "reportIcon", "uiStyle" }) },
					{ id = "frames", title = "OPT_SECTION_FRAMES", frameButtons = true },
					{ id = "qc", title = "OPT_SECTION_QC", rows = Pick("general", { "qcNote", "qcAction" }) },
					{ id = "reset", title = "OPT_SEC_RESET", rows = {
						{ key = "resetNote", kind = "note", small = true, text = "OPT_RESET_ALL_NOTE" },
						{ key = "resetAll", label = "OPT_RESET_ALL", kind = "action", button = "OPT_RESET_ALL_BTN", forgeStyle = "danger" },
					} },
				} },
			},
		},
		{
			id = "check", title = "OPT_FAM_CHECK", sub = "OPT_FAM_CHECK_SUB", icon = I.check,
			power = "departureEnabled", powerLabel = "OPT_FAM_CHECK_POWER", aliases = { "departure" }, dashTabs = true,
			oldNames = { "OPT_PAGE_DEPARTURE" },
			preview = Field("departure", "preview"),
			dash = {
				{ label = "OPT_FAM_CHECK_POWER", go = "check", key = "departureEnabled",
					text = function(self) return self.score and self:F("OPT_DASH_SCORE", self.score) or "" end },
			},
			tabs = {
				{ id = "bags", label = "OPT_PAGE_BAGS", phrase = "OPT_PAGE_BAGS_SUB", sections = {
					{ id = "bags_checks", title = "OPT_SEC_CHECKS", modules = Field("bags", "modules") },
					{ id = "bags_limits", title = "OPT_SEC_THRESHOLDS", rows = Concat(Rest("bags"), {
						{ key = "goCamp", label = "OPT_LINK_CAMP", kind = "action", button = "OPT_LINK_CAMP_BTN" },
					}) },
				} },
				{ id = "gear", label = "OPT_PAGE_GEAR", phrase = "OPT_PAGE_GEAR_SUB", sections = {
					{ id = "gear_checks", title = "OPT_SEC_CHECKS", modules = Concat(Field("gear", "modules"), { "barranks" }) },
					{ id = "gear_limits", title = "OPT_SEC_THRESHOLDS", rows = Rest("gear") },
				} },
				{ id = "buffs", label = "OPT_PAGE_BUFFS", phrase = "OPT_PAGE_BUFFS_SUB", sections = {
					{ id = "buffs_checks", title = "OPT_SEC_CHECKS", modules = Concat(Field("buffs", "modules"), { "profcap" }) },
					{ id = "buffs_mine", title = "OPT_SEC_MYBUFFS", rows = Rest("buffs"), list = Field("buffs", "list") },
				} },
				-- sans l'aperçu de la note : l'onglet tient sans défiler
				{ id = "when", label = "OPT_TAB_WHEN", phrase = "OPT_TAB_WHEN_SUB", preview = false, sections = {
					{ id = "trigger", title = "OPT_PAGE_TRIGGER", rows = Rest("trigger") },
					{ id = "checkdisplay", title = "OPT_SEC_CHECK_DISPLAY", rows = Pick("general", { "showWindow", "popupScore" }) },
					{ id = "safe", title = "OPT_SEC_SAFE", oldNames = { "OPT_PAGE_SAFE" }, list = "safe", listLines = 6 },
				} },
			},
		},
		{
			id = "sacs", title = "OPT_FAM_BAGS", sub = "OPT_FAM_BAGS_SUB", icon = I.sacs,
			aliases = { "qol" }, oldNames = { "OPT_PAGE_QOL" },
			dash = {
				{ label = "OPT_DASH_SELLGRAY", go = "merchant", key = "autoSellGray" },
				{ label = "OPT_DASH_REPAIR", go = "merchant", key = "autoRepair" },
				{ label = "OPT_SEC_FAVORITES", go = "favorites",
					text = function(self)
						local count = 0
						for _ in pairs(self:DB().favorites or {}) do count = count + 1 end
						return self:F("OPT_DASH_FAVORITES", count)
					end },
				{ label = "OPT_PAGE_BAGSPACE", go = "bagspace", key = "bagspaceEnabled" },
				{ label = "OPT_PAGE_LOOTROOM", go = "lootroom", key = "lootroomEnabled" },
				{ label = "OPT_SEC_QUICKLOOT", go = "quickloot", key = "quickLootEnabled" },
			},
			tabs = {
				{ id = "marchand", label = "OPT_TAB_MERCHANT", phrase = "OPT_TAB_MERCHANT_SUB", sections = {
					{ id = "merchant", title = "OPT_PAGE_MERCHANT", rows = Rest("merchant") },
					{ id = "favorites", title = "OPT_SEC_FAVORITES",
						rows = Pick("bagspace", { "favoriteClick", "favoriteAutoBuyback", "favoritesHowTo", "favorites" }) },
				} },
				{ id = "plein", label = "OPT_TAB_FULL", phrase = "OPT_TAB_FULL_SUB", sections = {
					{ id = "bagspace", title = "OPT_PAGE_BAGSPACE", phrase = "OPT_PAGE_BAGSPACE_SUB", power = "bagspaceEnabled",
						rows = Concat(Pick("bagspace", { "bagspaceFrame", "bagspaceConfirm" }), Concat({ { header = "OPT_BAGSPACE_DISCARD" } },
							Rest("bagspace", { "bagspaceEnabled", "bagspaceFrame", "bagspaceConfirm", "favoriteClick",
								"favoriteAutoBuyback", "favoritesHowTo", "favorites" }))) },
					{ id = "lootroom", title = "OPT_PAGE_LOOTROOM", phrase = "OPT_PAGE_LOOTROOM_SUB", power = "lootroomEnabled",
						rows = Rest("lootroom", { "lootroomEnabled", "quickLootEnabled" }) },
					{ id = "quickloot", title = "OPT_SEC_QUICKLOOT", phrase = "OPT_SEC_QUICKLOOT_SUB", power = "quickLootEnabled" },
				} },
			},
		},
		{
			id = "voyage", title = "OPT_FAM_TRAVEL", sub = "OPT_FAM_TRAVEL_SUB", icon = I.voyage,
			tabs = {
				{ id = "retour", label = "OPT_TAB_RETURN", phrase = "OPT_TAB_RETURN_SUB", sections = {
					{ id = "expedition", title = "OPT_PAGE_EXPEDITION", phrase = "OPT_PAGE_EXPEDITION_SUB", power = "expeditionEnabled",
						rows = Rest("expedition") },
					{ id = "death", title = "OPT_PAGE_DEATH", phrase = "OPT_PAGE_DEATH_SUB", power = "deathEnabled",
						rows = Rest("death", { "deathEnabled" }) },
				} },
				{ id = "camp", label = "OPT_PAGE_CAMP", phrase = "OPT_TAB_CAMP_SUB", sections = {
					{ id = "camp", title = "OPT_PAGE_CAMP", phrase = "OPT_PAGE_CAMP_SUB", tag = "Forever", power = "campEnabled",
						modules = Field("camp", "modules"), rows = Rest("camp") },
				} },
				{ id = "donjon", label = "OPT_TAB_DUNGEON", phrase = "OPT_TAB_DUNGEON_SUB", sections = {
					{ id = "dungeon", title = "OPT_PAGE_DUNGEON", phrase = "OPT_PAGE_DUNGEON_SUB", power = "dungeonEnabled",
						rows = Rest("dungeon", { "dungeonGroup" }) },
					{ id = "groupready", title = "OPT_SEC_GROUPREADY", phrase = "OPT_SEC_GROUPREADY_SUB", power = "dungeonGroup" },
				} },
			},
		},
		{
			id = "quetes", title = "OPT_FAM_QUESTS", sub = "OPT_FAM_QUESTS_SUB", icon = I.quetes,
			tabs = {
				{ id = "xp", label = "OPT_TAB_XP", phrase = "OPT_TAB_XP_SUB", sections = {
					{ id = "reward", title = "OPT_PAGE_REWARD", phrase = "OPT_PAGE_REWARD_SUB", power = "rewardEnabled",
						rows = Rest("reward", { "rewardEnabled" }) },
					{ id = "pace", title = "OPT_PAGE_PACE", phrase = "OPT_PAGE_PACE_SUB", power = "paceEnabled",
						rows = Rest("pace", { "paceEnabled" }) },
				} },
				{ id = "sorts", label = "OPT_TAB_SPELLS", phrase = "OPT_TAB_SPELLS_SUB", preview = Field("spellranks", "preview"), sections = {
					{ id = "spellranks", title = "OPT_PAGE_SPELLRANKS", phrase = "OPT_PAGE_SPELLRANKS_SUB", power = "spellranksEnabled",
						rows = Rest("spellranks", { "spellranksEnabled", "trainAllEnabled" }) },
					{ id = "trainall", title = "OPT_SEC_TRAINALL", phrase = "OPT_SEC_TRAINALL_SUB", power = "trainAllEnabled" },
				} },
			},
		},
		{
			id = "combat", title = "OPT_FAM_COMBAT", sub = "OPT_FAM_COMBAT_SUB", icon = I.combat,
			tabs = {
				{ id = "portees", label = "OPT_TAB_RANGES", phrase = "OPT_TAB_RANGES_SUB", sections = {
					{ id = "aggro", title = "OPT_PAGE_AGGRO", phrase = "OPT_SEC_AGGRO_SUB", power = "aggroEnabled",
						rows = Rest("aggro", { "aggroEnabled" }) },
					{ id = "combatRange", title = "OPT_PAGE_COMBAT_RANGE", phrase = "OPT_SEC_RANGE_SUB", tag = "2.0",
						power = "combatRange", info = Without(Field("combatRange", "info"), "OPT_COMBAT_INFO_RANGE_1"),
						rows = Rest("combatRange") },
				} },
				{ id = "dots", label = "OPT_TAB_DOTS", phrase = "OPT_PAGE_COMBAT_DOTS_SUB", sections = {
					{ id = "combatDots", title = "OPT_PAGE_COMBAT_DOTS", phrase = "OPT_PAGE_COMBAT_DOTS_SUB", tag = "2.0",
						power = "combatDots", info = Field("combatDots", "info"), rows = Rest("combatDots") },
				} },
				{ id = "cast", label = "OPT_TAB_CAST", phrase = "OPT_PAGE_COMBAT_CAST_SUB", sections = {
					{ id = "combatCast", title = "OPT_PAGE_COMBAT_CAST", phrase = "OPT_SEC_CAST_SUB", tag = "2.0",
						power = "combatCast", info = Field("combatCast", "info"), rows = Rest("combatCast") },
				} },
				{ id = "bars", label = "OPT_TAB_BARS", phrase = "OPT_PAGE_COMBAT_BARS_SUB", sections = {
					{ id = "combatBars", title = "OPT_PAGE_COMBAT_BARS", phrase = "OPT_PAGE_COMBAT_BARS_SUB", tag = "2.0",
						power = "combatBars", info = Field("combatBars", "info"), rows = Rest("combatBars") },
				} },
			},
		},
	}
end
ns.OPTION_FAMILIES = Families

-- ---------------------------------------------------------------------------
-- Actions : lien vers le kit de camp, remise à zéro avec confirmation
-- ---------------------------------------------------------------------------
ns.OPTION_ACTIONS.goCamp = function(self) self:SelectOptionsPage("camp") end

-- Rend la fenêtre de confirmation (ou nil sans StaticPopup : rien n'est effacé)
function ns:ConfirmResetAll()
	local dialogs, show = rawget(_G, "StaticPopupDialogs"), rawget(_G, "StaticPopup_Show")
	if type(dialogs) ~= "table" or type(show) ~= "function" then return nil end
	local key = "READY2QUEST_RESET_ALL"
	dialogs[key] = dialogs[key] or {
		text = L.OPT_RESET_ALL_ASK, button1 = L.OPT_RESET_ALL_YES, button2 = L.OPT_CLOSE,
		OnAccept = function() ns:ResetAllSettings() end,
		timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1, preferredIndex = 3,
	}
	local ok, dialog = pcall(show, key)
	return ok and (dialog or true) or nil
end

function ns:ResetAllSettings()
	self:HandleCommand("reset")
	if self.RefreshOptions then self:RefreshOptions() end
end
ns.OPTION_ACTIONS.resetAll = function(self) self:ConfirmResetAll() end

if ns.Mark then ns.Mark("OptionsMenu") end
