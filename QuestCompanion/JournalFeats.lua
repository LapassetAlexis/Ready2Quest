-- JournalFeats.lua -- page « Hauts faits » du carnet (QuestCompanion 2.7.0, lot A ; refaite en 3.7.0)
--
-- 3.7.0 (docs/qc-gameplay-viral, contrat « page Hauts faits », chantier C1a ;
-- maquette validée : carnet-j1 à j3) :
--   * en-tête (tous les onglets) : la plaque du total, le rang, « prochain
--     rang : <nom>, à <N> points » et sa barre ; à droite « n sur N obtenus »
--     et les secrets découverts ; six onglets (Aperçu, Dresseur, Compagnon et
--     voyage, Aventure, Titres, Statistiques) et le champ « Rechercher… » ;
--   * Aperçu : à portée de main (Suivre), rattrapés avec cette version, la
--     ligne vers la page Communauté, derniers obtenus, récompenses proches,
--     par catégorie ;
--   * listes par famille (JournalFeatsList.lua) : catégories à gauche,
--     filtres, une ligne par série, ligne dépliée, défilement ;
--   * recherche : nom et description de toutes les catégories, sans accents
--     ni casse ; un secret non obtenu ne se trouve pas par son vrai nom.
--   * Titres et Statistiques : leurs vues viendront (chantier C1b) par
--     ns.JOURNAL_FEATS_VIEWS[onglet] = { build, refresh, scroll } ; d'ici là,
--     une zone vide.
-- La page ne calcule rien fermée ; ouverte, elle se rafraîchit sur événement
-- (RefreshJournal), jamais par image. Positions : celles de la maquette, en
-- pixels depuis le haut gauche de la zone utile (710 × 510, sous l'en-tête).
-- Page externe du carnet : ns.JOURNAL_PANES.feats (JournalWindow.lua).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local FR = {
	JRN_SEC_feats       = "Hauts faits",
	JRN_SUB_feats       = "Tes exploits de dresseur et d'aventurier. Ceux du compte valent pour tous tes personnages.",
	JRN_TOTAL_FEATS     = "%d points de hauts faits",
	FEAT_PLATE          = "%s points · %s",
	FEAT_PLATE_NONE     = "%s points",
	FEAT_PLATE_SHORT    = "%s · %s",
	FEAT_FILTER_all     = "Tous",
	FEAT_FILTER_got     = "Obtenus",
	FEAT_FILTER_open    = "En cours",
	FEAT_FILTER_reward  = "Avec récompense",
	FEAT_TAB_overview   = "Aperçu",
	FEAT_TAB_titles     = "Titres",
	FEAT_TAB_stats      = "Statistiques",
	FEAT_SEARCH         = "Rechercher…",
	FEAT_RANK_NONE      = "Pas encore de rang",
	FEAT_RANK_NEXT      = "prochain rang : %s, à %s points",
	FEAT_RANK_SUMMIT    = "Le sommet : %s points",
	FEAT_HEAD_GOT       = "%s sur %s obtenus",
	FEAT_HEAD_SECRET_1  = "1 secret découvert",
	FEAT_HEAD_SECRETS   = "%d secrets découverts",
	FEAT_PAIR           = "%s sur %s",
	FEAT_COUNT_FMT      = "%s / %s",
	FEAT_SEC_NEAR       = "À portée de main",
	FEAT_SEC_CATCH      = "Rattrapés avec cette version",
	FEAT_SEC_RECENT     = "Derniers obtenus",
	FEAT_SEC_REWARDS    = "Récompenses proches",
	FEAT_SEC_CATS       = "Par catégorie",
	FEAT_FOLLOW         = "Suivre",
	FEAT_FOLLOWED       = "Suivi",
	FEAT_FOLLOW_FULL    = "Trois hauts faits suivis au plus : retires-en un.",
	FEAT_CATCH_HEAD_1   = "1 haut fait retrouvé dans ta progression",
	FEAT_CATCH_HEAD     = "%d hauts faits retrouvés dans ta progression",
	FEAT_CATCH_LINE     = "%s points et %s paillettes, comptés une fois à la mise à jour",
	FEAT_CATCH_SEE      = "Voir la liste",
	FEAT_COMMUNITY      = "Une minute ? %s : page Communauté, onglet « Ton avis ».",
	FEAT_COMMUNITY_LINK = "Dis-nous ce que tu en penses",
	FEAT_NEAR_NONE      = "Rien à portée pour l'instant : chaque capture, chaque zone fait avancer un haut fait.",
	FEAT_RECENT_NONE    = "Aucun haut fait obtenu pour l'instant.",
	FEAT_REWARDS_NONE   = "Aucune récompense en vue pour l'instant.",
	FEAT_CATS_NONE      = "Toutes les catégories sont terminées.",
	FEAT_NEAR_LINE      = "%s : %s",
	FEAT_GLITTER        = "%d paillettes",
	FEAT_DATE_SHORT     = "%d/%m",
	FEAT_NUM_SEP        = " ",
	FEAT_SEARCH_HEAD_1  = "1 résultat pour « %s »",
	FEAT_SEARCH_HEAD    = "%d résultats pour « %s »",
	FEAT_SEARCH_NONE    = "Aucun haut fait ne correspond à « %s ».",
	FEAT_ROW_TIP        = "Clic : déplier · Maj+clic : suivre",
	FEAT_TRK_HINT       = "Clic : le haut fait, déplié dans le carnet.",
	-- noms des séries (FEAT_SERIES_<clé>, FeatsData.lua : ns.FEAT_SERIES)
	FEAT_SERIES_species      = "Espèces capturées",
	FEAT_SERIES_rare         = "Créatures rares",
	FEAT_SERIES_stars3       = "Spécimens parfaits",
	FEAT_SERIES_study        = "Études",
	FEAT_SERIES_patron       = "Mécénat",
	FEAT_SERIES_shinyFound   = "Brillantes trouvées",
	FEAT_SERIES_shinyCap     = "Brillantes capturées",
	FEAT_SERIES_seals        = "Sceaux de zone",
	FEAT_SERIES_zones        = "Zones visitées",
	FEAT_SERIES_villages     = "Villages visités",
	FEAT_SERIES_zones100     = "Zones accomplies",
	FEAT_SERIES_missions     = "Missions",
	FEAT_SERIES_rares        = "Rares traqués",
	FEAT_SERIES_travel       = "Route parcourue",
	FEAT_SERIES_daysTogether = "Jours ensemble",
	FEAT_SERIES_level        = "Niveaux",
	FEAT_SERIES_kills        = "Adversaires vaincus",
	FEAT_SERIES_gold         = "Fortune",
	FEAT_SERIES_deaths       = "Morts",
	FEAT_SERIES_quests       = "Quêtes accomplies",
	FEAT_SERIES_exalted      = "Exalté",
	FEAT_SERIES_prof         = "Métier",
	FEAT_SERIES_gather       = "Récoltes",
	FEAT_SERIES_dungeons     = "Donjons visités",
	FEAT_SERIES_cards        = "Fiches de dresseur",
	FEAT_SERIES_trades       = "Échanges",
	-- séries de la deuxième édition (FeatsCatDresseur.lua, FeatsCatCompagnon.lua)
	FEAT_SERIES_bond5        = "Inséparables",
	FEAT_SERIES_captureHunt  = "Mode chasse",
	FEAT_SERIES_captureStreak = "Réussites d'affilée",
	FEAT_SERIES_captureZones = "Terrains de chasse",
	FEAT_SERIES_caught       = "Prises",
	FEAT_SERIES_chests       = "Coffres de zone",
	FEAT_SERIES_critters     = "Bestioles",
	FEAT_SERIES_dances       = "Danses",
	FEAT_SERIES_daysPlayed   = "Jours de route",
	FEAT_SERIES_elite        = "Élites",
	FEAT_SERIES_glitter      = "Paillettes gagnées",
	FEAT_SERIES_glitterSpent = "Paillettes dépensées",
	FEAT_SERIES_golden       = "Zones dorées",
	FEAT_SERIES_guildSeen    = "Exploits de guilde vus",
	FEAT_SERIES_innDays      = "Nuits à l'auberge",
	FEAT_SERIES_medal4       = "Palier 4 par type",
	FEAT_SERIES_medal5       = "Palier 5 par type",
	FEAT_SERIES_medalGold    = "Médailles d'or",
	FEAT_SERIES_mentees      = "Filleuls",
	FEAT_SERIES_milestones   = "Paliers de zone",
	FEAT_SERIES_murlocs      = "Murlocs",
	FEAT_SERIES_nicks        = "Surnoms",
	FEAT_SERIES_orderWeek    = "Semaines pleines",
	FEAT_SERIES_orders       = "Commandes livrées",
	FEAT_SERIES_partners     = "Créatures emmenées",
	FEAT_SERIES_perfect      = "Journées parfaites",
	FEAT_SERIES_pets         = "Caresses",
	FEAT_SERIES_points       = "Renommée",
	FEAT_SERIES_radiantTime  = "Temps Rayonnant",
	FEAT_SERIES_release      = "Relâchers",
	FEAT_SERIES_shares       = "Partages",
	FEAT_SERIES_shinySeen    = "Brillantes repérées",
	FEAT_SERIES_shinyZones   = "Zones à brillantes",
	FEAT_SERIES_stage        = "Stades du compagnon",
	FEAT_SERIES_studySame    = "Même espèce",
	FEAT_SERIES_treats       = "Friandises",
	FEAT_SERIES_wardrobe     = "Garde-robe",
	FEAT_SERIES_weekCatch    = "Créature de la semaine",
	FEAT_SERIES_weeksDone    = "Semaines bouclées",
	FEAT_SERIES_wishes       = "Envies comblées",
}
local EN = {
	JRN_SEC_feats       = "Achievements",
	JRN_SUB_feats       = "Your feats as a trainer and adventurer. Account achievements count for all your characters.",
	JRN_TOTAL_FEATS     = "%d achievement points",
	FEAT_PLATE          = "%s points · %s",
	FEAT_PLATE_NONE     = "%s points",
	FEAT_PLATE_SHORT    = "%s · %s",
	FEAT_FILTER_all     = "All",
	FEAT_FILTER_got     = "Earned",
	FEAT_FILTER_open    = "In progress",
	FEAT_FILTER_reward  = "With a reward",
	FEAT_TAB_overview   = "Overview",
	FEAT_TAB_titles     = "Titles",
	FEAT_TAB_stats      = "Statistics",
	FEAT_SEARCH         = "Search…",
	FEAT_RANK_NONE      = "No rank yet",
	FEAT_RANK_NEXT      = "next rank: %s, at %s points",
	FEAT_RANK_SUMMIT    = "The summit: %s points",
	FEAT_HEAD_GOT       = "%s of %s earned",
	FEAT_HEAD_SECRET_1  = "1 secret discovered",
	FEAT_HEAD_SECRETS   = "%d secrets discovered",
	FEAT_PAIR           = "%s of %s",
	FEAT_COUNT_FMT      = "%s / %s",
	FEAT_SEC_NEAR       = "Within reach",
	FEAT_SEC_CATCH      = "Caught up with this version",
	FEAT_SEC_RECENT     = "Latest earned",
	FEAT_SEC_REWARDS    = "Rewards within reach",
	FEAT_SEC_CATS       = "By category",
	FEAT_FOLLOW         = "Track",
	FEAT_FOLLOWED       = "Tracked",
	FEAT_FOLLOW_FULL    = "Three tracked achievements at most: remove one first.",
	FEAT_CATCH_HEAD_1   = "1 achievement found in your progress",
	FEAT_CATCH_HEAD     = "%d achievements found in your progress",
	FEAT_CATCH_LINE     = "%s points and %s glitter, counted once at the update",
	FEAT_CATCH_SEE      = "See the list",
	FEAT_COMMUNITY      = "Got a minute? %s: Community page, \"Your opinion\" tab.",
	FEAT_COMMUNITY_LINK = "Tell us what you think",
	FEAT_NEAR_NONE      = "Nothing within reach yet: every capture and every zone moves an achievement forward.",
	FEAT_RECENT_NONE    = "No achievement earned yet.",
	FEAT_REWARDS_NONE   = "No reward in sight for now.",
	FEAT_CATS_NONE      = "Every category is complete.",
	FEAT_NEAR_LINE      = "%s: %s",
	FEAT_GLITTER        = "%d glitter",
	FEAT_DATE_SHORT     = "%m/%d",
	FEAT_NUM_SEP        = ",",
	FEAT_SEARCH_HEAD_1  = "1 result for \"%s\"",
	FEAT_SEARCH_HEAD    = "%d results for \"%s\"",
	FEAT_SEARCH_NONE    = "No achievement matches \"%s\".",
	FEAT_ROW_TIP        = "Click: expand · Shift-click: track",
	FEAT_TRK_HINT       = "Click: the achievement, expanded in the journal.",
	FEAT_SERIES_species      = "Species Captured",
	FEAT_SERIES_rare         = "Rare Creatures",
	FEAT_SERIES_stars3       = "Perfect Specimens",
	FEAT_SERIES_study        = "Studies",
	FEAT_SERIES_patron       = "Patronage",
	FEAT_SERIES_shinyFound   = "Shinies Found",
	FEAT_SERIES_shinyCap     = "Shinies Captured",
	FEAT_SERIES_seals        = "Zone Seals",
	FEAT_SERIES_zones        = "Zones Visited",
	FEAT_SERIES_villages     = "Villages Visited",
	FEAT_SERIES_zones100     = "Zones Completed",
	FEAT_SERIES_missions     = "Missions",
	FEAT_SERIES_rares        = "Rares Tracked",
	FEAT_SERIES_travel       = "Distance Travelled",
	FEAT_SERIES_daysTogether = "Days Together",
	FEAT_SERIES_level        = "Levels",
	FEAT_SERIES_kills        = "Foes Defeated",
	FEAT_SERIES_gold         = "Fortune",
	FEAT_SERIES_deaths       = "Deaths",
	FEAT_SERIES_quests       = "Quests Completed",
	FEAT_SERIES_exalted      = "Exalted",
	FEAT_SERIES_prof         = "Profession",
	FEAT_SERIES_gather       = "Gathering",
	FEAT_SERIES_dungeons     = "Dungeons Visited",
	FEAT_SERIES_cards        = "Trainer Cards",
	FEAT_SERIES_trades       = "Trades",
	-- séries de la deuxième édition (FeatsCatDresseur.lua, FeatsCatCompagnon.lua)
	FEAT_SERIES_bond5        = "Inseparables",
	FEAT_SERIES_captureHunt  = "Hunt Mode",
	FEAT_SERIES_captureStreak = "Catch Streaks",
	FEAT_SERIES_captureZones = "Hunting Grounds",
	FEAT_SERIES_caught       = "Catches",
	FEAT_SERIES_chests       = "Zone Chests",
	FEAT_SERIES_critters     = "Critters",
	FEAT_SERIES_dances       = "Dances",
	FEAT_SERIES_daysPlayed   = "Days on the Road",
	FEAT_SERIES_elite        = "Elites",
	FEAT_SERIES_glitter      = "Glitter Earned",
	FEAT_SERIES_glitterSpent = "Glitter Spent",
	FEAT_SERIES_golden       = "Golden Zones",
	FEAT_SERIES_guildSeen    = "Guild Feats Seen",
	FEAT_SERIES_innDays      = "Nights at the Inn",
	FEAT_SERIES_medal4       = "Tier 4 by Type",
	FEAT_SERIES_medal5       = "Tier 5 by Type",
	FEAT_SERIES_medalGold    = "Gold Medals",
	FEAT_SERIES_mentees      = "Protégés",
	FEAT_SERIES_milestones   = "Zone Milestones",
	FEAT_SERIES_murlocs      = "Murlocs",
	FEAT_SERIES_nicks        = "Nicknames",
	FEAT_SERIES_orderWeek    = "Full Weeks",
	FEAT_SERIES_orders       = "Orders Delivered",
	FEAT_SERIES_partners     = "Travel Partners",
	FEAT_SERIES_perfect      = "Perfect Days",
	FEAT_SERIES_pets         = "Pets Given",
	FEAT_SERIES_points       = "Renown",
	FEAT_SERIES_radiantTime  = "Radiant Time",
	FEAT_SERIES_release      = "Releases",
	FEAT_SERIES_shares       = "Shares",
	FEAT_SERIES_shinySeen    = "Shinies Spotted",
	FEAT_SERIES_shinyZones   = "Shiny Zones",
	FEAT_SERIES_stage        = "Companion Stages",
	FEAT_SERIES_studySame    = "Same Species",
	FEAT_SERIES_treats       = "Treats",
	FEAT_SERIES_wardrobe     = "Wardrobe",
	FEAT_SERIES_weekCatch    = "Creature of the Week",
	FEAT_SERIES_weeksDone    = "Weeks Completed",
	FEAT_SERIES_wishes       = "Wishes Granted",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.JOURNAL_FEATS_STRINGS = { fr = FR, en = EN } end

-- ---------------------------------------------------------------------------
-- Mesures (maquette carnet_views.py : x depuis la gauche de la zone utile,
-- y depuis son haut ; la zone utile commence sous l'en-tête de page, TOP)
-- ---------------------------------------------------------------------------
ns.FEAT_SUMMIT = 5000      -- « Le sommet » après le dernier rang
ns.JOURNAL_FEATS_TABS = { "overview", "dresseur", "voyage", "aventure", "titles", "stats" }
ns.JOURNAL_FEATS_FILTERS = { "all", "open", "got", "reward" }
ns.JOURNAL_FEATS_LAYOUT = {
	-- en-tête
	rankX = 104, rankY = 2, rankR = 544, rankBarY = 25, rankBarH = 4, gotY = 0, secretY = 16,
	tabsY = 46, tabPad = 20, tabGap = 4, searchW = 118,
	-- Aperçu
	nearW = 446, nearH = 58, nearY = 104, nearStep = 62, nearSecY = 86, catchSecY = 360, catchY = 378,
	communityY = 446, rightX = 462, rightW = 248, recentSecY = 86, recentY = 104, recentStep = 20,
	rewardSecY = 196, rewardY = 214, rewardStep = 35, catsSecY = 324, catsY = 343, catsStep = 21, catsBarW = 62,
	catsCountW = 46, near = 4, rewards = 3, recent = 4, cats = 6,
	-- listes
	catW = 180, catH = 30, catY = 82, catStep = 32, listX = 196, filtersY = 82, listY = 114, listBottom = 489,
	positionY = 493, rowGap = 4,
	sectionLift = 4,   -- une section (20 de haut) : son milieu sur la ligne de texte de la maquette
}
ns.JOURNAL_FEATS_VIEWS = ns.JOURNAL_FEATS_VIEWS or {}
local K = ns.JOURNAL_FEATS_LAYOUT

-- ---------------------------------------------------------------------------
-- Petites aides partagées avec JournalFeatsList.lua (ns.FeatsPage)
-- ---------------------------------------------------------------------------
local FP = ns.FeatsPage or {}
ns.FeatsPage = FP

function FP.NoWrap(text) if text.SetWordWrap then text:SetWordWrap(false) end return text end
function FP.Paint(region, c, a) if region and c then region:SetTextColor(c[1], c[2], c[3], a or 1) end end
local NoWrap, Paint = FP.NoWrap, FP.Paint

-- 1 240 (français), 1,240 (anglais)
function FP.Num(n)
	n = math.floor((tonumber(n) or 0) + 0.5)
	local text = tostring(math.abs(n))
	local sep = L.FEAT_NUM_SEP
	if type(sep) ~= "string" or sep == "FEAT_NUM_SEP" then sep = " " end
	local count
	repeat text, count = text:gsub("^(%d+)(%d%d%d)", "%1" .. sep:gsub("%%", "%%%%") .. "%2") until count == 0
	return (n < 0 and "-" or "") .. text
end
local Num = FP.Num

-- « cur / max », séparateurs de milliers compris
function ns:FeatCountText(cur, max) return self:F("FEAT_COUNT_FMT", Num(cur), Num(max)) end

-- recherche : minuscules, sans accents, apostrophe typographique ramenée à '
local FOLD = {}
for from, to in pairs({ ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["á"] = "a", ["ã"] = "a", ["å"] = "a", ["ç"] = "c",
	["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e", ["í"] = "i", ["ì"] = "i", ["î"] = "i", ["ï"] = "i", ["ñ"] = "n",
	["ó"] = "o", ["ò"] = "o", ["ô"] = "o", ["ö"] = "o", ["õ"] = "o", ["ú"] = "u", ["ù"] = "u", ["û"] = "u", ["ü"] = "u",
	["ý"] = "y", ["ÿ"] = "y", ["œ"] = "oe", ["æ"] = "ae",
	["À"] = "a", ["Â"] = "a", ["Ä"] = "a", ["Á"] = "a", ["Ã"] = "a", ["Å"] = "a", ["Ç"] = "c", ["É"] = "e", ["È"] = "e",
	["Ê"] = "e", ["Ë"] = "e", ["Í"] = "i", ["Ì"] = "i", ["Î"] = "i", ["Ï"] = "i", ["Ñ"] = "n", ["Ó"] = "o", ["Ò"] = "o",
	["Ô"] = "o", ["Ö"] = "o", ["Õ"] = "o", ["Ú"] = "u", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u", ["Ý"] = "y", ["Œ"] = "oe",
	["Æ"] = "ae" }) do FOLD[from] = to end
function FP.Fold(text)
	-- (minuscules octet par octet, A à Z seulement : string.lower suit la
	-- locale C de l'hôte et peut casser l'UTF-8)
	text = tostring(text or ""):gsub("\226\128\153", "'")
	text = text:gsub("[\195\197][\128-\191]", function(c) return FOLD[c] or c end)
	text = text:gsub("[A-Z]", string.lower)
	return text
end

-- première lettre en capitale / en minuscule (accents courants compris)
local LOWER = { ["É"] = "é", ["È"] = "è", ["Ê"] = "ê", ["À"] = "à", ["Â"] = "â", ["Î"] = "î", ["Ô"] = "ô", ["Ç"] = "ç",
	["Û"] = "û", ["Œ"] = "œ" }
local FIRST = "^([%z\1-\127\194-\244][\128-\191]*)"
function FP.UpperFirst(text)
	text = tostring(text or "")
	return (text:gsub(FIRST, function(c) return Theme.Upper(c) end, 1))
end
function FP.LowerFirst(text)
	text = tostring(text or "")
	return (text:gsub(FIRST, function(c) return LOWER[c] or c:gsub("[A-Z]", string.lower) end, 1))
end

local function DateWith(format, at)
	local fn = rawget(_G, "date")
	if not (at and at > 0 and type(fn) == "function") then return "" end
	local ok, text = pcall(fn, format, at)
	return ok and type(text) == "string" and text or ""
end
function FP.DateShort(at) return DateWith(L.FEAT_DATE_SHORT, at) end
function FP.DateLong(self, at)
	local text = DateWith(L.FEAT_DATE_FORMAT, at)
	return text ~= "" and self:F("FEAT_EARNED_ON", text) or ""
end

-- récompense autre que les paillettes : titre, aide, cosmétique, apparence
function FP.HasReward(def)
	local reward = def and def.reward
	if type(reward) ~= "table" then return false end
	if reward.title ~= nil or reward.cosmetic ~= nil or reward.appearance ~= nil then return true end
	return type(reward.aids) == "table" and next(reward.aids) ~= nil
end

-- « Récompense : titre « … », 40 paillettes » (vide sans récompense autre que
-- les paillettes)
function FP.RewardLine(self, def)
	if not FP.HasReward(def) then return "" end
	local text = self:FeatRewardText(def)
	local glitter = self.FeatGlitterOf and self:FeatGlitterOf(def) or 0
	if glitter > 0 then text = (text ~= "" and (text .. ", ") or "") .. self:F("FEAT_GLITTER", glitter) end
	if text == "" then return "" end
	return self:F("FEAT_REWARD", text)
end

-- encre des étiquettes de secret : le violet « rare » du thème, éclairci (lisible sur son fond teinté)
ns.FEAT_SECRET_LIFT = 0.3
function FP.SecretInk() return Theme.Over(Theme.RANK.rare, Theme.WHITE, ns.FEAT_SECRET_LIFT) end

-- un secret pas encore obtenu : rien de lui ne se montre
function FP.Secret(self, def) return def and def.hidden and not self:FeatGot(def) end

-- nom d'une série : FEAT_SERIES_<clé>, sinon le nom de son premier palier
function FP.SeriesName(self, key, defs)
	local name = L["FEAT_SERIES_" .. tostring(key)]
	if name and name ~= "FEAT_SERIES_" .. tostring(key) then return name end
	return defs and defs[1] and self:FeatName(defs[1]) or tostring(key)
end

function FP.Shift()
	local fn = rawget(_G, "IsShiftKeyDown")
	if type(fn) ~= "function" then return false end
	local ok, down = pcall(fn)
	return ok and down and true or false
end

-- Les obtenus, les comptables et les secrets de chaque catégorie, en une
-- passe : { [cat] = { got, total, pts, ptsMax, secrets, secretsGot } }
function FP.CatStats(self)
	local out = { all = { got = 0, total = 0, pts = 0, ptsMax = 0, secrets = 0, secretsGot = 0 } }
	for _, def in ipairs(self:FeatDefs()) do
		if not def.pending then
			local s = out[def.cat]
			if not s then s = { got = 0, total = 0, pts = 0, ptsMax = 0, secrets = 0, secretsGot = 0, rawGot = 0, rawTotal = 0 }; out[def.cat] = s end
			local got = self:FeatGot(def) ~= nil
			s.rawTotal = s.rawTotal + 1
			if got then s.rawGot = s.rawGot + 1 end
			for _, t in ipairs({ s, out.all }) do
				if def.hidden then
					t.secrets = t.secrets + 1
					if got then t.secretsGot = t.secretsGot + 1 end
				end
				if self:FeatCountable(def) then
					local pts = tonumber(def.pts) or 0
					t.total, t.ptsMax = t.total + 1, t.ptsMax + pts
					if got then t.got, t.pts = t.got + 1, t.pts + pts end
				end
			end
		end
	end
	return out
end

-- Suivre / ne plus suivre (on nil : bascule) ; la limite répond d'une phrase
function FP.Follow(self, def, on)
	local frame = self.journalFrame
	if not def then return false end
	local ok, why = self:FeatFollow(def.id, on)
	if frame then frame.featsNotice = (not ok and why == "full") and L.FEAT_FOLLOW_FULL or nil end
	if ok and self.RefreshJournalTracker then pcall(self.RefreshJournalTracker, self) end
	if self.RefreshJournal then self:RefreshJournal() end
	return ok, why
end

function FP.Followed(self, id)
	for _, other in ipairs(self:FeatFollowed()) do if other == id then return true end end
	return false
end

-- ---------------------------------------------------------------------------
-- Données de la page (API gardée : FeatRows, FeatCategoryStats)
-- ---------------------------------------------------------------------------
-- Lignes d'une catégorie ("all" : toutes) selon un filtre : non obtenus par
-- progression décroissante (grisés à la fin), puis obtenus du plus récent au
-- plus ancien. Chaque ligne : { def, cur, max, state, got, at }
-- (3.7.0 : une ligne en attente n'est plus listée ; ordre et lignes : Feats.lua)
function ns:FeatRows(cat, filter)
	cat, filter = cat or "all", filter or "all"
	if self.FeatCacheReset then self:FeatCacheReset() end
	local rows = {}
	for _, def in ipairs(self:FeatDefs()) do
		if (cat == "all" or def.cat == cat) and not def.pending then
			local got = self:FeatGot(def)
			local wanted = filter == "all" or (filter == "got" and got) or (filter == "open" and not got)
			if wanted then rows[#rows + 1] = self:FeatEntry(def) end
		end
	end
	table.sort(rows, ns.FeatEntryBefore)
	return rows
end

-- Obtenus, total, points gagnés, points en jeu d'une catégorie ("all" : tout)
-- (3.7.0 : lignes comptables seulement : ni en attente, ni tour de force, ni
-- secret pas encore obtenu)
function ns:FeatCategoryStats(cat)
	local got, total, pts, ptsMax = 0, 0, 0, 0
	for _, def in ipairs(self:FeatDefs()) do
		if (cat == "all" or def.cat == cat) and self:FeatCountable(def) then
			total, ptsMax = total + 1, ptsMax + (tonumber(def.pts) or 0)
			if self:FeatGot(def) then got, pts = got + 1, pts + (tonumber(def.pts) or 0) end
		end
	end
	return got, total, pts, ptsMax
end

-- Les catégories d'une famille, dans l'ordre du catalogue (celles qui ont des lignes)
function ns:FeatFamilyCategories(family)
	local out = {}
	for _, cat in ipairs(self:FeatCategories()) do
		local def = self:FeatCategory(cat)
		if def and def.family == family then out[#out + 1] = cat end
	end
	return out
end

-- ---------------------------------------------------------------------------
-- Plaque du menu : « <points> points · <rang> »
-- ---------------------------------------------------------------------------
function ns:FeatPlateText(short)
	local pts = self:FeatPoints()
	local _, rank = self:FeatRank(pts)
	if not rank then return self:F("FEAT_PLATE_NONE", Num(pts)) end
	return self:F(short and "FEAT_PLATE_SHORT" or "FEAT_PLATE", Num(pts), rank)
end

-- Pose le texte sur la plaque du menu (JournalWindow.lua) : la police plus
-- petite, puis sans le mot « points » si le rang est long ; au-delà, le
-- client coupe (…)
function ns:FeatPlateSet(plate)
	if not (plate and plate.text) then return nil end
	local text = self:FeatPlateText()
	local width = (tonumber(plate.text.GetWidth and plate.text:GetWidth()) or 0)
	local font = Theme.F_LABEL
	if width > 0 and Theme.TextWidth(plate, text, Theme.F_LABEL) > width then
		font = Theme.F_SMALL
		if Theme.TextWidth(plate, text, Theme.F_SMALL) > width then text = self:FeatPlateText(true) end
	end
	if plate.text.SetFontObject then plate.text:SetFontObject(font) end
	plate.text:SetText(text)
	return text
end

-- ---------------------------------------------------------------------------
-- Construction : en-tête, onglets, recherche, vues
-- ---------------------------------------------------------------------------
-- puces au pas de la maquette (marge 10 de chaque côté, écart 4)
local function Relayout(row, pad, gap)
	local x = 0
	for _, chip in ipairs(row.chips) do
		local w = math.ceil(Theme.TextWidth(row, chip.text:GetText(), Theme.F_BODY) + pad)
		chip:SetWidth(w)
		chip:ClearAllPoints()
		chip:SetPoint("LEFT", row, "LEFT", x, 0)
		x = x + w + gap
	end
	row.used = math.max(1, x - gap)
	row:SetWidth(row.used)
end
FP.Relayout = Relayout

local function TabLabel(id)
	if id == "dresseur" or id == "voyage" or id == "aventure" then return L["FEATF_" .. id] end
	return L["FEAT_TAB_" .. id]
end

-- 3.1.0 : la plaque du total (thème forgé) : taille, losange, marge, écart
ns.JOURNAL_FEATS_PLATE = { w = 92, h = 36, diamond = 14, pad = 12, gap = 12, tint = "neutral" }

local function Build(self, frame, content, ui)
	local At, TOP, INNER = ui.At, ui.TOP, ui.INNER
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.feats = pane
	frame.featsTab = frame.featsTab or "overview"
	frame.featsCatOf = frame.featsCatOf or {}
	local function Place(region, x, y) return At(region, content, x, TOP - y) end
	pane.Place, pane.content, pane.ui = Place, content, ui

	-- en-tête : la plaque du total (forgé), le rang et sa barre, les comptes
	local headX = 0
	if frame.journalForged then
		local P = ns.JOURNAL_FEATS_PLATE
		local plate = CreateFrame("Frame", nil, pane)
		plate:SetSize(P.w, P.h)
		At(plate, content, 0, TOP + 1)
		plate.slice = Theme.ForgeSlice(plate, "plate", Theme.FORGE_PLATE[P.tint], { height = P.h, sub = 0 })
		plate.diamond = Theme.CreateDiamond(plate, P.diamond, false)
		plate.diamond:SetPoint("LEFT", plate, "LEFT", P.pad, 0)
		plate.diamond:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 1)
		plate.value = NoWrap(Theme.Text(plate, Theme.F_TITLE, Theme.GOLD_LIGHT))
		plate.value:SetPoint("LEFT", plate, "LEFT", P.pad + P.diamond + 6, 0)
		plate.value:SetWidth(P.w - (P.pad + P.diamond + 6) - P.pad + 4)
		plate.value:SetJustifyH("CENTER")
		if plate.value.SetJustifyV then plate.value:SetJustifyV("MIDDLE") end
		Theme.TextShadow(plate.value, 0.9)
		pane.pointsPlate = plate
		headX = K.rankX
	end
	pane.headX = headX
	pane.rankName = NoWrap(ui.Text(pane, Theme.F_LABEL, Theme.PARCHMENT, K.rankR - headX))
	Place(pane.rankName, headX, K.rankY)
	pane.rankNext = NoWrap(ui.Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, K.rankR - headX))
	pane.rankNext:SetJustifyH("RIGHT")
	pane.rankBar = Theme.CreateBar(pane, K.rankR - headX, K.rankBarH)
	Place(pane.rankBar, headX, K.rankBarY)
	pane.gotText = NoWrap(ui.Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, INNER - K.rankR - 8))
	pane.gotText:SetJustifyH("RIGHT")
	pane.gotText:SetPoint("TOPRIGHT", content, "TOPLEFT", ui.PAD + INNER, TOP - K.gotY)
	pane.secretText = NoWrap(ui.Text(pane, Theme.F_SMALL, Theme.MUTED_LIGHT, INNER - K.rankR - 8))
	pane.secretText:SetJustifyH("RIGHT")
	pane.secretText:SetPoint("TOPRIGHT", content, "TOPLEFT", ui.PAD + INNER, TOP - K.secretY)

	-- onglets (puces de la maquette) et recherche
	local defs = {}
	for _, id in ipairs(ns.JOURNAL_FEATS_TABS) do defs[#defs + 1] = { id = id, label = TabLabel(id) } end
	pane.tabs = Theme.CreateChips(pane, defs, function(id) ns:JournalFeatsTab(id) end, { gap = K.tabGap })
	pane.tabChips = pane.tabs.byId
	Relayout(pane.tabs, K.tabPad, K.tabGap)
	Place(pane.tabs, 0, K.tabsY)
	pane.search = Theme.CreateSearchBox(pane, K.searchW, L.FEAT_SEARCH, function(text) ns:JournalFeatsSearch(text) end)
	pane.search:SetPoint("TOPRIGHT", content, "TOPLEFT", ui.PAD + INNER, TOP - K.tabsY)
	-- le clavier n'est pris qu'au clic (SetAutoFocus(false) du socle) ; Échap
	-- vide le champ et le rend au jeu
	pane.search:SetScript("OnEscapePressed", function(box)
		if box.ClearFocus then box:ClearFocus() end
		box:SetText("")
		if box.Refresh then box:Refresh() end
		box.lastValue = ""
		ns:JournalFeatsSearch("")
	end)
	pane:SetScript("OnHide", function() if pane.search.ClearFocus then pane.search:ClearFocus() end end)

	-- vues : Aperçu, listes (familles, recherche, rattrapés), Titres, Statistiques
	pane.views = {}
	for _, id in ipairs({ "overview", "list", "titles", "stats" }) do
		local view = CreateFrame("Frame", nil, pane)
		view:SetAllPoints()
		view:Hide()
		pane.views[id] = view
	end
	FP.BuildOverview(self, frame, pane, pane.views.overview)
	if FP.BuildList then FP.BuildList(self, frame, pane, pane.views.list) end
	for _, id in ipairs({ "titles", "stats" }) do
		local def = ns.JOURNAL_FEATS_VIEWS[id]
		if def and type(def.build) == "function" then
			local ok, err = pcall(def.build, self, frame, pane.views[id], ui, Place)
			if not ok and self.RecordError then self:RecordError("journal:feats:" .. id, err) end
		end
	end
	-- la phrase d'une action refusée (suivre un quatrième), en bas à gauche
	pane.notice = NoWrap(ui.Text(pane, Theme.F_SMALL, Theme.GOLD_LIGHT, 440))
	Place(pane.notice, 0, K.positionY)
	pane:Hide()
end

-- ---------------------------------------------------------------------------
-- Aperçu
-- ---------------------------------------------------------------------------
local function Section(parent, text, width)
	local section = Theme.CreateSection(parent, text)
	section:SetWidth(width)
	if section.SetText then section:SetText(text) end
	return section
end
FP.Section = Section

local function FollowButtons(parent, w, onFollow, onUnfollow)
	local follow = Theme.CreateButton(parent, w, "sm", L.FEAT_FOLLOW, onFollow, "normal")
	local unfollow = Theme.CreateButton(parent, w, "sm", L.FEAT_FOLLOWED, onUnfollow, "accent")
	return follow, unfollow
end
FP.FollowButtons = FollowButtons

local function BuildNearRow(view, index)
	local row = Theme.CreateTile(view, K.nearW, K.nearH)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(36, 36)
	row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -11)
	row.name = NoWrap(Theme.Text(row, Theme.F_LABEL, Theme.LABEL))
	row.name:SetJustifyH("LEFT")
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 56, -6)
	row.name:SetWidth(250)
	row.desc = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
	row.desc:SetJustifyH("LEFT")
	row.desc:SetPoint("TOPLEFT", row, "TOPLEFT", 56, -22)
	row.desc:SetWidth(250)
	row.bar = Theme.CreateBar(row, 196, 4)
	row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", 56, -45)
	row.count = NoWrap(Theme.Text(row, Theme.F_SMALL, Theme.MUTED_LIGHT))
	row.count:SetJustifyH("RIGHT")
	row.count:SetPoint("TOPRIGHT", row, "TOPLEFT", 306, -39)
	row.count:SetWidth(64)
	row.diamond = Theme.CreateDiamond(row, 30, false)
	row.diamond:SetPoint("CENTER", row, "TOPLEFT", 331, -28)
	row.pts = Theme.Text(row, Theme.F_NUMBER, Theme.MUTED_LIGHT)
	row.pts:SetPoint("CENTER", row.diamond, "CENTER", 0, 0)
	row.pts:SetJustifyH("CENTER")
	row.follow, row.unfollow = FollowButtons(row, 78,
		function(b) FP.Follow(ns, b:GetParent().def, true) end,
		function(b) FP.Follow(ns, b:GetParent().def, false) end)
	row.follow:SetPoint("TOPLEFT", row, "TOPLEFT", 358, -17)
	row.unfollow:SetPoint("TOPLEFT", row, "TOPLEFT", 358, -17)
	row:SetScript("OnClick", function(r)
		if not r.def then return end
		if FP.Shift() then return FP.Follow(ns, r.def, nil) end
		ns:OpenJournalFeatsAt(r.def.id)
	end)
	row.onEnter = function(r) ns:JournalFeatsTip(r) end
	row.onLeave = function() local tip = rawget(_G, "GameTooltip"); if tip and tip.Hide then tip:Hide() end end
	view.Place(row, 0, K.nearY + (index - 1) * K.nearStep)
	return row
end

function FP.BuildOverview(self, frame, pane, view)
	local Place, ui = pane.Place, pane.ui
	view.Place = Place
	local lift = K.sectionLift
	view.nearSec = Section(view, L.FEAT_SEC_NEAR, K.nearW)
	Place(view.nearSec, 0, K.nearSecY - lift)
	view.near = {}
	for index = 1, K.near do view.near[index] = BuildNearRow(view, index) end
	view.nearNone = ui.Text(view, Theme.F_BODY, Theme.MUTED, K.nearW)
	Place(view.nearNone, 0, K.nearY + 4)

	-- rattrapés avec cette version
	view.catchSec = Section(view, L.FEAT_SEC_CATCH, K.nearW)
	Place(view.catchSec, 0, K.catchSecY - lift)
	local tile = Theme.CreateTile(view, K.nearW, K.nearH, { kind = "Frame" })
	Place(tile, 0, K.catchY)
	tile.icon = tile:CreateTexture(nil, "ARTWORK")
	tile.icon:SetSize(36, 36)
	tile.icon:SetPoint("TOPLEFT", tile, "TOPLEFT", 10, -11)
	tile.name = NoWrap(Theme.Text(tile, Theme.F_LABEL, Theme.PARCHMENT))
	tile.name:SetJustifyH("LEFT")
	tile.name:SetPoint("TOPLEFT", tile, "TOPLEFT", 56, -6)
	tile.name:SetWidth(282)
	tile.desc = Theme.Text(tile, Theme.F_SMALL, Theme.MUTED_LIGHT)
	tile.desc:SetJustifyH("LEFT")
	tile.desc:SetPoint("TOPLEFT", tile, "TOPLEFT", 56, -22)
	tile.desc:SetWidth(276)
	if tile.desc.SetWordWrap then tile.desc:SetWordWrap(true) end
	tile.see = Theme.CreateButton(tile, 90, "sm", L.FEAT_CATCH_SEE, function() ns:JournalFeatsCatchUpList() end, "normal")
	tile.see:SetPoint("TOPLEFT", tile, "TOPLEFT", 346, -17)
	view.catch = tile

	-- la ligne vers la page Communauté (si elle existe)
	view.community = CreateFrame("Button", nil, view)
	view.community:SetSize(K.nearW, 16)
	view.community.text = NoWrap(ui.Text(view.community, Theme.F_SMALL, Theme.MUTED_LIGHT, K.nearW))
	view.community.text:SetPoint("LEFT", view.community, "LEFT", 0, 0)
	view.community:SetScript("OnClick", function() ns:JournalFeatsCommunity() end)

	-- colonne de droite
	local X, W = K.rightX, K.rightW
	view.recentSec = Section(view, L.FEAT_SEC_RECENT, W)
	Place(view.recentSec, X, K.recentSecY - lift)
	view.recent = {}
	for index = 1, K.recent do
		local line = {}
		line.name = NoWrap(ui.Text(view, Theme.F_BODY, Theme.PARCHMENT, W - 52))
		Place(line.name, X, K.recentY + (index - 1) * K.recentStep)
		line.date = NoWrap(ui.Text(view, Theme.F_SMALL, Theme.MUTED_LIGHT, 48))
		line.date:SetJustifyH("RIGHT")
		Place(line.date, X + W - 48, K.recentY + (index - 1) * K.recentStep + 1)
		view.recent[index] = line
	end
	view.recentNone = ui.Text(view, Theme.F_SMALL, Theme.MUTED, W)
	Place(view.recentNone, X, K.recentY)

	view.rewardSec = Section(view, L.FEAT_SEC_REWARDS, W)
	Place(view.rewardSec, X, K.rewardSecY - lift)
	view.rewards = {}
	for index = 1, K.rewards do
		local line = {}
		local y = K.rewardY + (index - 1) * K.rewardStep
		line.reward = NoWrap(ui.Text(view, Theme.F_SMALL, Theme.GOLD, W))
		Place(line.reward, X, y)
		line.line = NoWrap(ui.Text(view, Theme.F_SMALL, Theme.MUTED_LIGHT, W))
		Place(line.line, X, y + 14)
		view.rewards[index] = line
	end
	view.rewardsNone = ui.Text(view, Theme.F_SMALL, Theme.MUTED, W)
	Place(view.rewardsNone, X, K.rewardY)

	view.catsSec = Section(view, L.FEAT_SEC_CATS, W)
	Place(view.catsSec, X, K.catsSecY - lift)
	view.cats = {}
	local nameW = W - K.catsBarW - K.catsCountW - 16
	for index = 1, K.cats do
		local y = K.catsY + (index - 1) * K.catsStep
		local line = CreateFrame("Button", nil, view)
		line:SetSize(W, 16)
		Place(line, X, y)
		line.name = NoWrap(ui.Text(line, Theme.F_BODY, Theme.TEXT, nameW))
		line.name:SetPoint("LEFT", line, "LEFT", 0, 0)
		line.bar = Theme.CreateBar(line, K.catsBarW, 4)
		line.bar:SetPoint("LEFT", line, "LEFT", nameW + 8, 0)
		line.count = NoWrap(ui.Text(line, Theme.F_SMALL, Theme.MUTED_LIGHT, K.catsCountW))
		line.count:SetJustifyH("RIGHT")
		line.count:SetPoint("RIGHT", line, "RIGHT", 0, 0)
		line:SetScript("OnClick", function(l) if l.cat then ns:OpenJournalFeats(l.cat) end end)
		view.cats[index] = line
	end
	view.catsNone = ui.Text(view, Theme.F_SMALL, Theme.MUTED, W)
	Place(view.catsNone, X, K.catsY)
end

local function Diamond(row, pts, got)
	local c = got and Theme.GOLD or Theme.CONTROL
	row.diamond:SetVertexColor(c[1], c[2], c[3], 1)
	row.diamond:Show()
	row.pts:SetText(pts)
	Paint(row.pts, got and Theme.INK or Theme.PARCHMENT)
	if Theme.NoShadow and got then Theme.NoShadow(row.pts) end
end
FP.Diamond = Diamond

-- l'ouverture de la page Communauté (JournalCommunity.lua : ns:CommunityOpen(onglet))
local function CommunityOpener()
	return ns.CommunityOpen or ns.JournalCommunityOpen
end
function ns:JournalFeatsCommunity()
	local open = CommunityOpener()
	if type(open) ~= "function" then return nil end
	return open(self, "avis")
end

local function RefreshOverview(self, frame, pane, view)
	local Place = pane.Place
	-- à portée de main
	local near = self:FeatNearest(K.near)
	for index, row in ipairs(view.near) do
		local item = near[index]
		if item then
			local def = item.def
			row.def, row.entry = def, { def = def, cur = item.cur, max = item.max, state = "open" }
			row.icon:SetTexture(self:FeatIcon(def))
			row.name:SetText(self:FeatName(def))
			row.desc:SetText(self:FeatDescription(def))
			row.bar:SetValue(item.max > 0 and item.cur / item.max or 0)
			row.count:SetText(self:FeatCountText(item.cur, item.max))
			Diamond(row, tostring(def.pts or 0), false)
			local followed = FP.Followed(self, def.id)
			if followed then row.follow:Hide(); row.unfollow:Show() else row.follow:Show(); row.unfollow:Hide() end
			row:Show()
		else
			row.def, row.entry = nil, nil
			row:Hide()
		end
	end
	view.nearNone:SetText(#near == 0 and L.FEAT_NEAR_NONE or "")

	-- rattrapés avec cette version (seulement si le rattrapage a donné quelque chose)
	local catch = self.FeatCatchUp and self:FeatCatchUp()
	local communityY = K.communityY
	if catch then
		local n = #catch.ids
		view.catch.name:SetText(n == 1 and L.FEAT_CATCH_HEAD_1 or self:F("FEAT_CATCH_HEAD", n))
		view.catch.desc:SetText(self:F("FEAT_CATCH_LINE", Num(catch.pts), Num(catch.glitter)))
		local meta = self:FeatCategory("meta")
		view.catch.icon:SetTexture(meta and meta.icon or Theme.LOGO_SMALL)
		view.catchSec:Show(); view.catch:Show()
	else
		view.catchSec:Hide(); view.catch:Hide()
		communityY = K.catchSecY
	end
	if type(CommunityOpener()) == "function" then
		local link = Theme.Hex(Theme.GOLD_LIGHT) .. L.FEAT_COMMUNITY_LINK .. "|r"
		view.community.text:SetText(self:F("FEAT_COMMUNITY", link))
		Place(view.community, 0, communityY)
		view.community:Show()
	else
		view.community:Hide()
	end

	-- derniers obtenus
	local got = {}
	for _, def in ipairs(self:FeatDefs()) do
		local entry = not def.pending and self:FeatGot(def)
		if entry then got[#got + 1] = { def = def, at = tonumber(entry.at) or 0 } end
	end
	table.sort(got, function(a, b)
		if a.at ~= b.at then return a.at > b.at end
		return (tonumber(a.def.n) or 0) > (tonumber(b.def.n) or 0)
	end)
	for index, line in ipairs(view.recent) do
		local item = got[index]
		line.name:SetText(item and self:FeatName(item.def) or "")
		line.date:SetText(item and FP.DateShort(item.at) or "")
	end
	view.recentNone:SetText(#got == 0 and L.FEAT_RECENT_NONE or "")

	-- récompenses proches
	local rewards = self:FeatNearest(K.rewards, FP.HasReward)
	for index, line in ipairs(view.rewards) do
		local item = rewards[index]
		if item then
			line.reward:SetText(FP.UpperFirst(self:FeatRewardText(item.def)))
			line.line:SetText(self:F("FEAT_NEAR_LINE", self:FeatName(item.def), self:FeatCountText(item.cur, item.max)))
		else
			line.reward:SetText(""); line.line:SetText("")
		end
	end
	view.rewardsNone:SetText(#rewards == 0 and L.FEAT_REWARDS_NONE or "")

	-- par catégorie : les non terminées les plus avancées, dans l'ordre du catalogue
	local stats = FP.CatStats(self)
	local open = {}
	for position, cat in ipairs(self:FeatCategories()) do
		local s = stats[cat]
		if s and s.total > 0 and s.got < s.total then
			open[#open + 1] = { cat = cat, pos = position, got = s.got, total = s.total, ratio = s.got / s.total }
		end
	end
	table.sort(open, function(a, b)
		if a.ratio ~= b.ratio then return a.ratio > b.ratio end
		return a.pos < b.pos
	end)
	local shown = {}
	for index = 1, math.min(K.cats, #open) do shown[index] = open[index] end
	table.sort(shown, function(a, b) return a.pos < b.pos end)
	for index, line in ipairs(view.cats) do
		local item = shown[index]
		if item then
			line.cat = item.cat
			line.name:SetText(L["FEATC_" .. item.cat])
			line.bar:SetValue(item.ratio)
			line.count:SetText(self:F("FEAT_COUNT_FMT", Num(item.got), Num(item.total)))
			line:Show()
		else
			line.cat = nil
			line:Hide()
		end
	end
	view.catsNone:SetText(#shown == 0 and L.FEAT_CATS_NONE or "")
end

-- ---------------------------------------------------------------------------
-- Rafraîchissement
-- ---------------------------------------------------------------------------
local function RefreshHeader(self, frame, pane)
	local pts = self:FeatPoints()
	local index, name, nextAt, nextName = self:FeatRank(pts)
	if pane.pointsPlate then pane.pointsPlate.value:SetText(Num(pts)) end
	name = name or L.FEAT_RANK_NONE
	pane.rankName:SetText(name)
	local lo = index > 0 and ns.FEAT_RANKS[index] or 0
	local nextText, ratio
	if nextAt then
		nextText, ratio = self:F("FEAT_RANK_NEXT", nextName, Num(nextAt)), (pts - lo) / math.max(1, nextAt - lo)
	elseif pts < ns.FEAT_SUMMIT then
		nextText, ratio = self:F("FEAT_RANK_SUMMIT", Num(ns.FEAT_SUMMIT)), (pts - lo) / math.max(1, ns.FEAT_SUMMIT - lo)
	end
	-- le prochain rang, aligné à droite, jamais sur le nom
	local nameW = math.ceil(Theme.TextWidth(pane, name, Theme.F_LABEL))
	local room = K.rankR - pane.headX - nameW - 12
	pane.rankName:SetWidth(math.min(nameW + 4, K.rankR - pane.headX))
	pane.rankNext:SetWidth(math.max(0, room))
	pane.rankNext:ClearAllPoints()
	pane.rankNext:SetPoint("TOPRIGHT", pane.content, "TOPLEFT", pane.ui.PAD + K.rankR, pane.ui.TOP - K.rankY - 1)
	pane.rankNext:SetText(nextText or "")
	if ratio then
		pane.rankBar:SetValue(math.max(0, math.min(1, ratio)))
		pane.rankBar:Show()
	else
		pane.rankBar:Hide()
	end
	local stats = FP.CatStats(self)
	pane.stats = stats
	pane.gotText:SetText(self:F("FEAT_HEAD_GOT", Num(stats.all.got), Num(stats.all.total)))
	local secrets = stats.all.secretsGot
	pane.secretText:SetText(secrets == 1 and L.FEAT_HEAD_SECRET_1 or (secrets > 1 and self:F("FEAT_HEAD_SECRETS", secrets) or ""))
end

local function SearchActive(frame)
	return #FP.Fold(frame.featsSearch or ""):gsub("^%s+", ""):gsub("%s+$", "") >= 2
end
FP.SearchActive = SearchActive

local function Refresh(self, frame, ui)
	local pane = frame.feats
	if not pane then return end
	local tab = frame.featsTab or "overview"
	local mode = (frame.featsResults or SearchActive(frame)) and "list"
		or ((tab == "dresseur" or tab == "voyage" or tab == "aventure") and "list") or tab
	if frame.scrollOnly then
		-- molette : seules les lignes de la liste bougent
		if mode == "list" and FP.LayoutList then FP.LayoutList(self, frame, pane, true) end
		local def = ns.JOURNAL_FEATS_VIEWS[mode]
		if def and type(def.refresh) == "function" and mode ~= "list" and mode ~= "overview" then
			pcall(def.refresh, self, frame, pane.views[mode], ui)
		end
		return
	end
	RefreshHeader(self, frame, pane)
	pane.tabs:Select(tab, true)
	for id, view in pairs(pane.views) do
		if id == mode then view:Show() else view:Hide() end
	end
	pane.notice:SetText(frame.featsNotice or "")
	if mode == "overview" then
		RefreshOverview(self, frame, pane, pane.views.overview)
	elseif mode == "list" then
		if FP.RefreshList then FP.RefreshList(self, frame, pane) end
	else
		local def = ns.JOURNAL_FEATS_VIEWS[mode]
		if def and type(def.refresh) == "function" then
			local ok, err = pcall(def.refresh, self, frame, pane.views[mode], ui)
			if not ok and self.RecordError then self:RecordError("journal:feats:" .. mode, err) end
		end
	end
end

local function Scroll(self, frame, delta)
	local tab = frame.featsTab or "overview"
	if frame.featsResults or SearchActive(frame) or tab == "dresseur" or tab == "voyage" or tab == "aventure" then
		frame.featsOffset = (tonumber(frame.featsOffset) or 0) - (tonumber(delta) or 0)
		return
	end
	local def = ns.JOURNAL_FEATS_VIEWS[tab]
	if def and type(def.scroll) == "function" then pcall(def.scroll, self, frame, delta) end
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------
local function ClearSearch(frame)
	frame.featsSearch, frame.featsResults = "", nil
	local box = frame.feats and frame.feats.search
	if box and (box:GetText() or "") ~= "" then
		box:SetText("")
		if box.Refresh then box:Refresh() end
		box.lastValue = ""
	end
end

-- Un onglet (gardé pour la session ; Aperçu à la première ouverture)
function ns:JournalFeatsTab(tab)
	local frame = self.journalFrame
	if not frame then return end
	frame.featsTab = tab or "overview"
	frame.featsOffset, frame.featsOpen, frame.featsNotice = 0, nil, nil
	ClearSearch(frame)
	self:RefreshJournal()
end

-- Une catégorie de la famille ouverte (gardée par famille pour la session)
function ns:JournalFeatsPick(cat)
	local frame = self.journalFrame
	if not frame then return end
	local def = cat and self:FeatCategory(cat)
	if not def then
		frame.featsTab = "overview"
	else
		frame.featsTab = def.family
		frame.featsCatOf = frame.featsCatOf or {}
		frame.featsCatOf[def.family] = cat
	end
	frame.featsOffset, frame.featsOpen, frame.featsNotice = 0, nil, nil
	ClearSearch(frame)
	self:RefreshJournal()
end

-- Le filtre des listes (gardé, comme avant)
function ns:JournalFeatsFilter(filter)
	local frame = self.journalFrame
	self:DB().featsFilter = filter
	if frame then frame.featsOffset, frame.featsOpen, frame.featsNotice = 0, nil, nil end
	self:RefreshJournal()
end

-- La recherche (dès deux caractères ; à la fin de la frappe)
function ns:JournalFeatsSearch(text)
	local frame = self.journalFrame
	if not frame then return end
	frame.featsSearch, frame.featsResults = tostring(text or ""), nil
	frame.featsOffset, frame.featsOpen, frame.featsNotice = 0, nil, nil
	if SearchActive(frame) and self.JournalSoon then self:JournalSoon("featsSearch") else self:RefreshJournal() end
end

-- « Voir la liste » des rattrapés : comme une recherche
function ns:JournalFeatsCatchUpList()
	local frame = self.journalFrame
	if not frame then return end
	ClearSearch(frame)
	frame.featsResults = "catchup"
	frame.featsOffset, frame.featsOpen, frame.featsNotice = 0, nil, nil
	self:RefreshJournal()
end

-- Infobulle d'une ligne : nom, description, récompense, portée, date ; ce
-- que font les clics (un secret non obtenu ne dit rien de plus que sa ligne)
function ns:JournalFeatsTip(row)
	local def, entry = row and row.def, row and row.entry
	local tip = rawget(_G, "GameTooltip")
	if not (def and type(tip) == "table") then return end
	ns.JournalTipAnchor(tip, row, "row")
	if tip.ClearLines then tip:ClearLines() end
	Theme.TooltipTitle(tip, self:FeatName(def))
	Theme.TooltipLine(tip, self:FeatDescription(def), Theme.TEXT, true)
	if not FP.Secret(self, def) then
		local reward = self:FeatRewardText(def)
		if reward ~= "" then Theme.TooltipLine(tip, self:F("FEAT_REWARD", reward), Theme.GOLD, true) end
	end
	if entry and entry.state == "pending" then Theme.TooltipLine(tip, L.FEAT_PENDING, Theme.MUTED, true) end
	Theme.TooltipHint(tip, L["FEAT_SCOPE_TIP_" .. tostring(def.scope)] or "", true)
	if entry and entry.got then Theme.TooltipHint(tip, FP.DateLong(self, entry.at), true) end
	if row.featsRow then Theme.TooltipHint(tip, L.FEAT_ROW_TIP, true) end
	tip:Show()
end

-- /qc hf : le carnet sur la page Hauts faits ; `cat` : une catégorie (sa
-- famille), sinon l'Aperçu
function ns:OpenJournalFeats(cat)
	if not self.ToggleJournal then return nil end
	local frame = self:ToggleJournal(true)
	if not frame then return nil end
	local def = cat and self.FeatCategory and self:FeatCategory(cat)
	if def then
		frame.featsTab = def.family
		frame.featsCatOf = frame.featsCatOf or {}
		frame.featsCatOf[def.family] = cat
		frame.featsOffset, frame.featsOpen = 0, nil
		ClearSearch(frame)
	elseif cat then
		frame.featsTab, frame.featsOffset, frame.featsOpen = "overview", 0, nil
		ClearSearch(frame)
	end
	self:SelectJournalKind("feats")
	return frame
end

-- Le carnet sur un haut fait : sa catégorie, filtre « Tous », sa ligne
-- dépliée et visible (suivi à l'écran, À portée de main)
function ns:OpenJournalFeatsAt(id)
	local def = self.FeatDef and self:FeatDef(id)
	if not def then return nil end
	self:DB().featsFilter = "all"
	local frame = self:OpenJournalFeats(def.cat)
	if not frame then return nil end
	local members = def.series and self:FeatSeries(def.series)
	frame.featsOpen = (members and #members > 1) and ("s:" .. def.series) or def.id
	frame.featsReveal = true
	self:RefreshJournal()
	return frame
end

ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.feats = {
	field = "feats", title = "JRN_SEC_feats", subtitle = "JRN_SUB_feats",
	build = Build, refresh = Refresh, scroll = Scroll,
}

if ns.Mark then ns.Mark("JournalFeats") end
