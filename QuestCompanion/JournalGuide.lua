-- JournalGuide.lua -- page Guide du carnet (QuestCompanion 2.3.0)
--
-- La ménagerie expliquée, pour qui a raté le tutoriel ou veut les chiffres :
--   * à gauche, le sommaire (une tuile par section, clic = la section) et,
--     en bas, le bouton « Revoir le tutoriel » (le tutoriel de la ménagerie
--     en bulles, Companion.lua) ;
--   * à droite, le titre de la section et son texte, par blocs (paragraphes,
--     sous-titres, rangées d'une table), paginés quand ils ne tiennent pas
--     dans la page : la molette avance d'un bloc, les chevrons d'une page.
-- Les chiffres (30 s, 60/30/10 %, 1 sur 150, paliers, titres, forces…)
-- viennent des constantes des modules (CaptureQueue, Capture, Shiny,
-- CompanionEffects, MenagerieCollection, Daily) : rien n'est recopié à la
-- main, et la table des huit types est construite depuis celle des effets.
-- Page externe du carnet : ns.JOURNAL_PANES.guide (JournalWindow.lua).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

local SECTIONS = { "net", "stars", "shiny", "effects", "seals", "titles", "missions", "card", "settings" }
ns.GUIDE_SECTIONS = SECTIONS

local FR = {
	JRN_SEC_guide          = "Guide",
	JRN_SUB_guide          = "La ménagerie expliquée : filet, étoiles, brillantes, compagnon, sceaux, titres, missions, fiche.",
	GUIDE_REPLAY           = "Revoir le tutoriel",
	GUIDE_REPLAY_TIP       = "Ton compagnon rejoue le tutoriel de la ménagerie en bulles ; le carnet se ferme pour le laisser parler.",
	GUIDE_MORE             = "Suite : molette ou chevrons",
	GUIDE_LIST_AND         = "%s et %s",
	GUIDE_CAP              = "%s (au plus %d %%)",
	GUIDE_AID              = "%s ×%s",
	GUIDE_AID_SURE         = "%s (capture assurée)",
	GUIDE_MASCOT           = "Mascotte",
	GUIDE_COL_TYPE         = "Type",
	GUIDE_COL_HUNT         = "Chasse",
	GUIDE_COL_COMFORT      = "Confort",
	GUIDE_COL_SPECIES      = "Espèces",
	GUIDE_COL_TITLE        = "Titre",
	GUIDE_COL_GIFT         = "Récompense",
	GUIDE_SEC_net          = "Le filet",
	GUIDE_net_1            = "Plus de fenêtre qui s'ouvre toute seule. Quand un monstre abattu vaut le coup (une espèce qui manque à ta ménagerie, une brillante, ou un spécimen qui pourrait battre le tien), il tombe dans le filet posé à côté de ton compagnon.",
	GUIDE_net_2            = "Un pack entier se met en file (%d monstres au plus) ; chacun y reste %d s à partir de la fin du combat. Le bouton montre leur nombre, devient doré si une brillante attend et bat quelques secondes quand un monstre arrive. Il reste à l'écran si le compagnon est masqué.",
	GUIDE_net_3            = "Clic : la capture du meilleur candidat (brillante, puis espèce nouvelle, puis le plus rare, puis une amélioration d'étoiles). Clic droit : la liste, pour en choisir un, choisir une aide ou tout ignorer ; elle se referme d'elle-même quand le filet part, par son « × » ou par Échap. /qc filet fait la même chose.",
	GUIDE_net_4            = "Le bandeau « Capture possible » nomme la créature dès qu'elle peut être capturée, dit si tu as déjà l'espèce (et avec combien d'étoiles), ta chance, et « et N de plus » s'il y en a plusieurs. Clic dessus : le filet ; clic droit : la liste ; Ignorer la sort du filet ; Sourdine coupe bandeau et sons pendant %s (/qc filet sourdine [min|off]). Un carillon l'accompagne (réglage %s).",
	GUIDE_net_5            = "La scène de capture se joue (réglage %s) et se referme seule après le verdict ; un clic ou Échap la ferment avant. Ta chance dépend du rang (normal %d %%, élite %d %%, rare %d %%, boss %d %%) et de l'écart de niveau ; les aides la multiplient : %s, %s, %s. Elles tombent des tampons du carnet, des paliers de zone et des missions.",
	GUIDE_SEC_stars        = "Les étoiles",
	GUIDE_stars_1          = "Chaque capture est un spécimen de 1 à 3 étoiles, tirées au moment de la capture : %d %% de chance pour 1 étoile, %d %% pour 2, %d %% pour 3.",
	GUIDE_stars_2          = "Recapture une espèce pour tenter mieux : le meilleur spécimen est gardé, jamais remplacé par un moins bon. Le filet ne propose plus une espèce déjà à 3 étoiles dans cette version (normale ou brillante).",
	GUIDE_stars_3          = "Les étoiles se voient sur la scène de capture, dans le bandeau, dans la liste du filet et sur la fiche de la Ménagerie. Elles comptent aussi pour la force de ton compagnon : +%s par étoile au-dessus de la première.",
	GUIDE_SEC_shiny        = "Les brillantes",
	GUIDE_shiny_1          = "Toute espèce peut être brillante. La première fois que tu cibles ou survoles un monstre, il a 1 chance sur %d de l'être, ×%d pour un élite ou un rare.",
	GUIDE_shiny_2          = "Plus tu as abattu d'une espèce, plus ta chance monte : jusqu'à 1 sur %d après %d abattus. Un compagnon Draconien ou Mort-vivant, et une zone scellée (×%s), l'améliorent encore.",
	GUIDE_shiny_3          = "Une brillante repérée porte un losange doré au-dessus de son nom (réglage %s) et reste reconnue pour toujours : la Ménagerie la montre, capturée ou non, avec son filtre Brillantes.",
	GUIDE_shiny_4          = "Chaque espèce a deux versions à capturer, la normale et la brillante, chacune avec ses étoiles. Une brillante capturée devient une apparence à part : ton compagnon prend une lumière dorée et scintille, et sa force gagne +%s.",
	GUIDE_SEC_effects      = "Ton compagnon chasse avec toi",
	GUIDE_effects_1        = "Une créature capturée que tu emmènes donne deux effets liés à son type : un de chasse et un de confort. Les valeurs ci-dessous sont celles d'une créature normale à 1 étoile, à pleine force ; entre parenthèses, le plafond.",
	GUIDE_effects_H        = "La force",
	GUIDE_effects_2        = "Elle multiplie les effets : rang normal ×%s, élite ×%s, rare et rare élite ×%s, boss ×%s ; +%s si elle est brillante ; +%s par étoile au-dessus de la première ; +%s par palier de ta collection du type (voir Titres de dresseur).",
	GUIDE_effects_3        = "Un compagnon heureux (ses quatre envies à %d %% ou plus) donne ses effets en entier ; chaque envie en dessous en retire un huitième, jamais moins de la moitié. Les mascottes (les compagnons que tu n'as pas capturés) sont le compagnon de cœur : un bonus général modeste, qui grandit avec leur étape d'évolution.",
	GUIDE_effects_4        = "Changer de compagnon demande une confirmation (anciens et nouveaux effets côte à côte), et les effets arrivent au bout de %d minutes : on choisit un compagnon pour une sortie, pas pour chaque cible. La page Compagnon montre ses effets et le compte à rebours ; l'infobulle des monstres, ta chance avec le bonus.",
	GUIDE_SEC_seals        = "Explorer et sceller les zones",
	GUIDE_seals_1          = "Depuis la 2.0, le pourcentage d'une zone (page Exploration) ne compte que l'exploration : lieux, récolte et quêtes. Les créatures vivent dans la Ménagerie. Les paliers et coffres déjà gagnés restent acquis.",
	GUIDE_seals_2          = "Capture toutes les espèces d'une zone (version normale ; les boss du monde ne comptent pas) et elle reçoit un sceau, pour toujours : un cadre aux couleurs de son paysage au premier sceau d'un biome, un fond au deuxième, et brillantes ×%s dans la zone.",
	GUIDE_seals_3          = "La Ménagerie montre le sceau de la zone choisie et sa progression (espèces capturées sur espèces de la zone) ; la page Exploration en garde une ligne. Les sceaux font aussi les badges de ta fiche de dresseur.",
	GUIDE_SEC_titles       = "Titres de dresseur",
	GUIDE_titles_1         = "Chaque type de créature a ses paliers de captures : %s espèces pour les types courants, %s pour les plus rares (%s). Chaque palier atteint renforce l'effet d'un compagnon de ce type (+%s de force).",
	GUIDE_titles_H         = "Les titres",
	GUIDE_titles_2         = "Les captures d'avant la 2.0 sont rattrapées à la mise à jour : sceaux, paliers et titres déjà mérités sont donnés d'un coup. Ton titre s'affiche sur ta fiche de dresseur et dans la Ménagerie.",
	GUIDE_SEC_missions     = "Missions",
	GUIDE_missions_1       = "Chaque jour, trois missions : une de ménagerie (capturer une espèce jamais capturée de la zone, %d créatures d'un type, un élite ou un rare), une d'exploration (lieux, récolte, quêtes) et celle du caractère de ton compagnon. Chacune rapporte %s ; les trois, %s.",
	GUIDE_missions_2       = "Chaque semaine, trois missions plus longues, renouvelées à la remise à zéro hebdomadaire : toujours une chasse au brillant (en abattre une, ou en capturer une) et, si possible, une mission par type (« emmène un Mort-vivant et capture %d Morts-vivants » : seule compte une capture faite avec un compagnon de ce type). Chacune rapporte %s ; les trois, %s.",
	GUIDE_missions_3       = "Tout se suit sur la page Missions du carnet, avec la besace de capture (appâts, lassos, sifflets) à côté du garde-manger. Un %s est aussi offert toutes les %d captures.",
	GUIDE_SEC_card         = "Fiche de dresseur",
	GUIDE_card_1           = "Ta fiche de dresseur montre ton titre, ton compagnon en 3D avec ses effets, une vitrine de 3 créatures que tu choisis, tes chiffres (espèces, brillantes capturées et reconnues, sceaux) et les badges de tes sceaux par continent. Rien de privé.",
	GUIDE_card_2           = "/qc fiche ouvre la tienne (c'est là que tu choisis ta vitrine) ; /qc fiche <nom> demande celle d'un autre joueur. Les joueurs qui ont l'addon ont « %s » dans le menu du clic droit (seulement pour les joueurs connus comme détenteurs) et une ligne « %s » dans leur infobulle.",
	GUIDE_card_3           = "Partagée par défaut ; coupe « %s » dans les réglages (page Au jour le jour) : ta fiche n'est envoyée à personne et l'addon reste muet. Les échanges passent par des messages d'addon invisibles, jamais en combat.",
	GUIDE_SEC_settings     = "Réglages et commandes",
	GUIDE_settings_1       = "Page Au jour le jour : %s (tout coupe, infobulle comprise) · %s · %s · %s · %s · %s · %s.",
	GUIDE_settings_2       = "Page Compagnon de route : %s (%s), pour que la créature remplisse son cadre à l'écran, même une bête capturée de taille réelle ; la réglette %s (Muet coupe aussi les tutoriels).",
	GUIDE_settings_3       = "Commandes : /qc filet (capture le meilleur candidat), /qc filet sourdine [min|off], /qc capture (ta ménagerie et tes aides), /qc fiche [nom] (fiche de dresseur), /qc compagnon tuto menagerie (revoir ce tutoriel), /qc compagnon tuto (le tutoriel de base).",
	GUIDE_settings_4       = "Le tutoriel de la ménagerie se joue une fois par personnage, à ta première occasion de capture : ton compagnon te guide jusqu'au clic sur le filet, laisse la scène se jouer, puis t'explique le reste. Jamais en combat, jamais si la capture est coupée. Le bouton « %s » ci-dessous le rejoue.",
}
local EN = {
	JRN_SEC_guide          = "Guide",
	JRN_SUB_guide          = "The menagerie explained: net, stars, shinies, companion, seals, titles, missions, card.",
	GUIDE_REPLAY           = "Replay the tutorial",
	GUIDE_REPLAY_TIP       = "Your companion replays the menagerie tutorial in bubbles; the journal closes to let it talk.",
	GUIDE_MORE             = "More: mouse wheel or chevrons",
	GUIDE_LIST_AND         = "%s and %s",
	GUIDE_CAP              = "%s (up to %d%%)",
	GUIDE_AID              = "%s ×%s",
	GUIDE_AID_SURE         = "%s (guaranteed capture)",
	GUIDE_MASCOT           = "Mascot",
	GUIDE_COL_TYPE         = "Type",
	GUIDE_COL_HUNT         = "Hunt",
	GUIDE_COL_COMFORT      = "Comfort",
	GUIDE_COL_SPECIES      = "Species",
	GUIDE_COL_TITLE        = "Title",
	GUIDE_COL_GIFT         = "Reward",
	GUIDE_SEC_net          = "The net",
	GUIDE_net_1            = "No more pop-up. When a defeated monster is worth capturing (a species missing from your menagerie, a shiny, or a specimen that could beat yours), it lands in the net beside your companion.",
	GUIDE_net_2            = "Whole packs queue up (%d monsters at most); each one stays %d s from the end of the fight. The button shows their count, turns gold when a shiny is waiting and pulses for a few seconds when a monster arrives. It stays on screen when the companion is hidden.",
	GUIDE_net_3            = "Click: captures the best candidate (shiny, then new species, then rarest, then a star upgrade). Right-click: the list, to pick one, choose an aid or ignore them all; it closes by itself when the net goes, with its \"×\" or with Escape. /qc filet does the same.",
	GUIDE_net_4            = "The \"Capture possible\" banner names the creature as soon as it can be captured, says whether you already own the species (and with how many stars), your odds, and \"and N more\" when several wait. Click it: the net; right-click: the list; Ignore drops it from the net; Mute silences banner and sounds for %s (/qc filet sourdine [min|off]). A chime comes with it (%s setting).",
	GUIDE_net_5            = "The capture scene plays (%s setting) and closes by itself after the verdict; a click or Escape closes it sooner. Your odds depend on the rank (normal %d%%, elite %d%%, rare %d%%, boss %d%%) and the level gap; aids multiply them: %s, %s, %s. They drop from journal stamps, zone milestones and missions.",
	GUIDE_SEC_stars        = "Stars",
	GUIDE_stars_1          = "Each capture is a 1 to 3-star specimen, rolled at capture time: a %d%% chance of 1 star, %d%% of 2, %d%% of 3.",
	GUIDE_stars_2          = "Recapture a species to try for better: the best specimen is kept, never replaced by a worse one. The net no longer offers a species already at 3 stars in that version (normal or shiny).",
	GUIDE_stars_3          = "Stars show on the capture scene, in the banner, in the net list and on the Menagerie card. They also count toward your companion's strength: +%s per star above the first.",
	GUIDE_SEC_shiny        = "Shinies",
	GUIDE_shiny_1          = "Any species can be shiny. The first time you target or hover a monster, it has a 1 in %d chance to be one, ×%d for an elite or a rare.",
	GUIDE_shiny_2          = "The more of a species you have defeated, the higher your odds: up to 1 in %d after %d kills. A Dragonkin or Undead companion, and a sealed zone (×%s), improve them further.",
	GUIDE_shiny_3          = "A spotted shiny carries a gold diamond above its name (%s setting) and stays known for good: the Menagerie shows it, captured or not, with its Shiny filter.",
	GUIDE_shiny_4          = "Each species has two versions to capture, normal and shiny, each with its own stars. A captured shiny becomes a look of its own: your companion is golden-lit and sparkles, and its strength gains +%s.",
	GUIDE_SEC_effects      = "Your companion hunts with you",
	GUIDE_effects_1        = "A captured creature you take along gives two effects tied to its type: a hunt effect and a comfort effect. The values below are those of a normal 1-star creature at full strength; in brackets, the cap.",
	GUIDE_effects_H        = "Strength",
	GUIDE_effects_2        = "It multiplies the effects: normal rank ×%s, elite ×%s, rare and rare elite ×%s, boss ×%s; +%s if it is shiny; +%s per star above the first; +%s per milestone of your type collection (see Trainer titles).",
	GUIDE_effects_3        = "A happy companion (its four needs at %d%% or more) gives its effects in full; each need below takes an eighth away, never less than half. Mascots (the companions you did not capture) are the companion of the heart: a modest general bonus that grows with their evolution stage.",
	GUIDE_effects_4        = "Switching companion asks for confirmation (old and new effects side by side), and the effects kick in after %d minutes: you pick a companion for an outing, not for each target. The Companion page shows its effects and the countdown; the monster tooltip, your odds with the bonus.",
	GUIDE_SEC_seals        = "Explore and seal zones",
	GUIDE_seals_1          = "Since 2.0, a zone's percentage (Exploration page) only counts exploring: places, gathering and quests. Creatures live in the Menagerie. Milestones and chests already earned stay yours.",
	GUIDE_seals_2          = "Capture every species of a zone (normal version; world bosses do not count) and it gets a seal, for good: a frame in the colours of its landscape at the first seal of a biome, a background at the second, and shinies ×%s in the zone.",
	GUIDE_seals_3          = "The Menagerie shows the seal of the chosen zone and its progress (captured species over the zone's species); the Exploration page keeps a line about it. Seals also make the badges of your trainer card.",
	GUIDE_SEC_titles       = "Trainer titles",
	GUIDE_titles_1         = "Each creature type has its capture milestones: %s species for the common types, %s for the rarest (%s). Each milestone reached strengthens the effect of a companion of that type (+%s strength).",
	GUIDE_titles_H         = "The titles",
	GUIDE_titles_2         = "Captures from before 2.0 are caught up at the update: seals, milestones and titles already deserved are granted at once. Your title shows on your trainer card and in the Menagerie.",
	GUIDE_SEC_missions     = "Missions",
	GUIDE_missions_1       = "Every day, three missions: a menagerie one (capture a never-captured species of the zone, %d creatures of a type, an elite or a rare), an exploration one (places, gathering, quests) and your companion's character mission. Each gives %s; all three, %s.",
	GUIDE_missions_2       = "Every week, three longer missions, renewed at the weekly reset: always a shiny hunt (defeat one, or capture one) and, when possible, a mission by type (\"take an Undead along and capture %d Undead\": only a capture made with a companion of that type counts). Each gives %s; all three, %s.",
	GUIDE_missions_3       = "Everything is tracked on the journal's Missions page, with the capture pack (baits, lassos, whistles) next to the pantry. A %s is also given every %d captures.",
	GUIDE_SEC_card         = "Trainer card",
	GUIDE_card_1           = "Your trainer card shows your title, your companion in 3D with its effects, a showcase of 3 creatures you choose, your numbers (species, shinies captured and known, seals) and your seal badges per continent. Nothing private.",
	GUIDE_card_2           = "/qc fiche opens yours (that is where you pick your showcase); /qc fiche <name> asks for another player's. Players who have the addon get \"%s\" in the right-click menu (only for players known to have it) and a \"%s\" line in their tooltip.",
	GUIDE_card_3           = "Shared by default; turn off \"%s\" in the settings (Day by day page): your card is sent to nobody and the addon stays silent. Exchanges go through invisible addon messages, never in combat.",
	GUIDE_SEC_settings     = "Settings and commands",
	GUIDE_settings_1       = "Day by day page: %s (turns everything off, tooltip included) · %s · %s · %s · %s · %s · %s.",
	GUIDE_settings_2       = "Road companion page: %s (%s), so the creature fills its on-screen frame, even a life-size captured beast; the %s slider (Silent also turns the tutorials off).",
	GUIDE_settings_3       = "Commands: /qc filet (captures the best candidate), /qc filet sourdine [min|off], /qc capture (your menagerie and aids), /qc fiche [name] (trainer card), /qc compagnon tuto menagerie (replay this tutorial), /qc compagnon tuto (the base tutorial).",
	GUIDE_settings_4       = "The menagerie tutorial plays once per character, at your first capture opportunity: your companion guides you to the click on the net, lets the scene play, then explains the rest. Never in combat, never when capture is off. The \"%s\" button below replays it.",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.GUIDE_STRINGS = { fr = FR, en = EN } end

-- Mesures (depuis le haut gauche de la zone utile, comme ui.At)
local LIST_W, GAP = 210, 16
local ROW_H, ROW_STEP = 30, 32
local TITLE_H = 30                -- le titre de la section, puis les blocs
local P_GAP, H_BEFORE, H_AFTER = 8, 12, 2
local TYPE_W, CELL_GAP, CELL_PAD = 100, 10, 5
local AREA_BOTTOM = 8             -- entre le dernier bloc et la pagination

local function Paint(region, c) region:SetTextColor(c[1], c[2], c[3]) end
local function NoWrap(text) if text.SetWordWrap then text:SetWordWrap(false) end return text end
local function Wrap(text)
	if text.SetWordWrap then text:SetWordWrap(true) end
	if text.SetJustifyV then text:SetJustifyV("TOP") end
	return text
end
local function Pct(value) return math.floor((tonumber(value) or 0) * 100 + 0.5 + 1e-9) end
-- « 1,5 » / « 1.5 », selon la langue (CompanionEffects.lua)
local function Num(value) return ns.EffectNum and ns.EffectNum(value) or tostring(value) end
-- « 10, 20 et 40 »
local function AndList(self, list)
	local items = {}
	for index, value in ipairs(list or {}) do items[index] = tostring(value) end
	if #items <= 1 then return items[1] or "" end
	local last = table.remove(items)
	return self:F("GUIDE_LIST_AND", table.concat(items, ", "), last)
end

-- Blocs : paragraphe, sous-titre, rangée d'une table (cells, cols, head)
local function P(text) return { kind = "p", text = tostring(text or "") } end
local function H(text) return { kind = "h", text = tostring(text or "") } end
local function Row(cells, cols, head) return { kind = "row", cells = cells, cols = cols, head = head } end

-- ---------------------------------------------------------------------------
-- Le contenu de chaque section, depuis les constantes des modules
-- ---------------------------------------------------------------------------
local BUILD = {}

-- ce que rapporte une mission (« friandise + Appât savoureux »), sans le « Gain : »
local function Reward(self, scope)
	local def = ns.MISSION_REWARDS and ns.MISSION_REWARDS[scope]
	if not def then return "" end
	local parts = {}
	if def.treat == "festin" then parts[#parts + 1] = self.TreatLabel and self:TreatLabel("festin") or "festin"
	elseif def.treat then parts[#parts + 1] = L.MIS_REWARD_TREAT end
	if def.aid and self.CaptureAidLabel then
		parts[#parts + 1] = def.aid == "draw" and L.MIS_REWARD_AID or self:CaptureAidLabel(def.aid)
	end
	return table.concat(parts, " + ")
end

-- une aide : « Appât savoureux ×1,5 », « Sifflet du dompteur (capture assurée) »
local function AidText(self, aid)
	local label = self.CaptureAidLabel and self:CaptureAidLabel(aid.id) or aid.id
	if aid.sure then return self:F("GUIDE_AID_SURE", label) end
	return self:F("GUIDE_AID", label, Num(aid.mult or 1))
end

function BUILD.net(self)
	local rates = ns.CAPTURE_RATES or {}
	local aids = ns.CAPTURE_AIDS or {}
	local aidText = {}
	for index = 1, 3 do aidText[index] = aids[index] and AidText(self, aids[index]) or "" end
	local minutes = {}
	for index, value in ipairs(ns.CAPTURE_MUTE_CHOICES or {}) do minutes[index] = value end
	local mute = #minutes > 0 and (AndList(self, minutes) .. " min") or "15 min"
	return {
		P(L.GUIDE_net_1),
		P(self:F("GUIDE_net_2", ns.CAPTURE_QUEUE_MAX or 0, ns.CAPTURE_QUEUE_TIME or 0)),
		P(L.GUIDE_net_3),
		P(self:F("GUIDE_net_4", mute, L.OPT_DAILY_CAPTURE_SOUND)),
		P(self:F("GUIDE_net_5", L.OPT_DAILY_CAPTURE_ANIM, Pct(rates.normal), Pct(rates.elite), Pct(rates.rare), Pct(rates.worldboss),
			aidText[1], aidText[2], aidText[3])),
	}
end

function BUILD.stars(self)
	local odds = ns.CAPTURE_STAR_ODDS or {}
	return {
		P(self:F("GUIDE_stars_1", odds[1] or 0, odds[2] or 0, odds[3] or 0)),
		P(L.GUIDE_stars_2),
		P(self:F("GUIDE_stars_3", Num(ns.EFFECT_STAR_STRENGTH or 0))),
	}
end

function BUILD.shiny(self)
	local chance = tonumber(ns.SHINY_CHANCE) or 0
	local base = chance > 0 and math.floor(1 / chance + 0.5) or 0
	local best = chance > 0 and math.floor(1 / (chance * (tonumber(ns.SHINY_CHAIN_MAX) or 1)) + 0.5) or 0
	local seal = ns.MenagerieDecimal and ns.MenagerieDecimal(ns.SEAL_SHINY_MULT or 1) or tostring(ns.SEAL_SHINY_MULT or 1)
	return {
		P(self:F("GUIDE_shiny_1", base, ns.SHINY_RANK_MULT or 1)),
		P(self:F("GUIDE_shiny_2", best, ns.SHINY_CHAIN_KILLS or 0, seal)),
		P(self:F("GUIDE_shiny_3", L.OPT_DAILY_PLATE)),
		P(self:F("GUIDE_shiny_4", Num(ns.EFFECT_SHINY_STRENGTH or 0))),
	}
end

-- La table des huit types (et la mascotte) : chasse et confort, valeur de
-- base (force ×1) et plafond, depuis ns.COMPANION_EFFECTS / TYPE_EFFECTS
local function EffectText(self, id)
	local def = ns.COMPANION_EFFECTS and ns.COMPANION_EFFECTS[id]
	if not def then return tostring(id or "") end
	return self:F("GUIDE_CAP", self:F("EFF_" .. id, Pct(def.base)), Pct(def.cap))
end

function ns:JournalGuideTypeRows()
	local rows = {}
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do
		local pair = ns.COMPANION_TYPE_EFFECTS and ns.COMPANION_TYPE_EFFECTS[key]
		if pair then
			rows[#rows + 1] = { key = key, label = self.CreatureTypeLabel and self:CreatureTypeLabel(key) or key,
				hunt = EffectText(self, pair.hunt), comfort = EffectText(self, pair.comfort) }
		end
	end
	local mascot = ns.COMPANION_MASCOT_EFFECTS
	if mascot then
		rows[#rows + 1] = { key = "mascot", label = L.GUIDE_MASCOT, hunt = EffectText(self, mascot.hunt), comfort = EffectText(self, mascot.comfort) }
	end
	return rows
end

function BUILD.effects(self, cols)
	local blocks = { P(L.GUIDE_effects_1), Row({ L.GUIDE_COL_TYPE, L.GUIDE_COL_HUNT, L.GUIDE_COL_COMFORT }, cols.types, true) }
	for _, row in ipairs(self:JournalGuideTypeRows()) do
		blocks[#blocks + 1] = Row({ row.label, row.hunt, row.comfort }, cols.types)
	end
	local rank = ns.EFFECT_RANK_STRENGTH or {}
	blocks[#blocks + 1] = H(L.GUIDE_effects_H)
	blocks[#blocks + 1] = P(self:F("GUIDE_effects_2", Num(rank.normal or 1), Num(rank.elite or 1), Num(rank.rare or 1),
		Num(rank.worldboss or 1), Num(ns.EFFECT_SHINY_STRENGTH or 0), Num(ns.EFFECT_STAR_STRENGTH or 0), Num(ns.MENAGERIE_TYPE_STEP or 0)))
	blocks[#blocks + 1] = P(self:F("GUIDE_effects_3", ns.EFFECT_NEED_OK or 0))
	blocks[#blocks + 1] = P(self:F("GUIDE_effects_4", math.floor((ns.EFFECT_DELAY or 0) / 60 + 0.5)))
	return blocks
end

function BUILD.seals(self)
	local seal = ns.MenagerieDecimal and ns.MenagerieDecimal(ns.SEAL_SHINY_MULT or 1) or tostring(ns.SEAL_SHINY_MULT or 1)
	return { P(L.GUIDE_seals_1), P(self:F("GUIDE_seals_2", seal)), P(L.GUIDE_seals_3) }
end

function BUILD.titles(self, cols)
	local tiers = ns.MENAGERIE_TYPE_TIERS or {}
	local rare = {}
	for _, key in ipairs(ns.CREATURE_TYPES or {}) do
		if ns.MENAGERIE_TYPE_RARE and ns.MENAGERIE_TYPE_RARE[key] then
			rare[#rare + 1] = self.CreatureTypeLabel and self:CreatureTypeLabel(key) or key
		end
	end
	local blocks = {
		P(self:F("GUIDE_titles_1", AndList(self, tiers.common), AndList(self, tiers.rare), table.concat(rare, ", "),
			Num(ns.MENAGERIE_TYPE_STEP or 0))),
		H(L.GUIDE_titles_H),
		Row({ L.GUIDE_COL_SPECIES, L.GUIDE_COL_TITLE, L.GUIDE_COL_GIFT }, cols.titles, true),
	}
	for _, rank in ipairs(ns.TRAINER_RANKS or {}) do
		local gift = self.TrainerRankGift and self:TrainerRankGift(rank) or ""
		blocks[#blocks + 1] = Row({ tostring(rank.count), L["TRAINER_" .. rank.key], gift }, cols.titles)
	end
	blocks[#blocks + 1] = P(L.GUIDE_titles_2)
	return blocks
end

function BUILD.missions(self)
	local whistle = self.CaptureAidLabel and self:CaptureAidLabel("sifflet") or "sifflet"
	return {
		P(self:F("GUIDE_missions_1", ns.MENAGERIE_TYPE_NEED or 2, Reward(self, "zone"), Reward(self, "allDaily"))),
		P(self:F("GUIDE_missions_2", ns.MENAGERIE_WEEKLY_TYPE_NEED or 2, Reward(self, "weekly"), Reward(self, "allWeekly"))),
		P(self:F("GUIDE_missions_3", whistle, ns.CAPTURE_GIFT_EVERY or 10)),
	}
end

function BUILD.card(self)
	return {
		P(L.GUIDE_card_1),
		P(self:F("GUIDE_card_2", L.TRAINER_MENU, L.TRAINER_TOOLTIP)),
		P(self:F("GUIDE_card_3", L.OPT_DAILY_TRAINER)),
	}
end

function BUILD.settings(self)
	local framings = {}
	for index, id in ipairs(ns.COMPANION_FRAMINGS or {}) do framings[index] = L["COMP_FRAMING_" .. id] end
	return {
		P(self:F("GUIDE_settings_1", L.OPT_DAILY_CAPTURE, L.OPT_DAILY_CAPTURE_ANIM, L.OPT_DAILY_CAPTURE_TOAST, L.OPT_DAILY_CAPTURE_SOUND,
			L.OPT_DAILY_EFFECT_PLATE, L.OPT_DAILY_PLATE, L.OPT_DAILY_TRAINER)),
		P(self:F("GUIDE_settings_2", L.OPT_COMP_FRAMING, table.concat(framings, ", "), L.OPT_COMP_CHATTER)),
		P(L.GUIDE_settings_3),
		P(self:F("GUIDE_settings_4", L.GUIDE_REPLAY)),
	}
end

-- Les blocs d'une section ; `cols` : les largeurs des tables (celles de la
-- page, ou des largeurs par défaut hors carnet)
function ns:JournalGuideBlocks(section, cols)
	local build = BUILD[section]
	if not build then return {} end
	cols = cols or ns.GUIDE_DEFAULT_COLS
	return build(self, cols)
end

local function SectionOf(section)
	for _, key in ipairs(SECTIONS) do if key == section then return key end end
	return SECTIONS[1]
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
local function Build(self, frame, content, ui)
	local At, Text, Tip, HideTip = ui.At, ui.Text, ui.Tip, ui.HideTip
	local TOP, INNER, PAD, PAGER_Y = ui.TOP, ui.INNER, ui.PAD, ui.PAGER_Y
	local RX = LIST_W + GAP
	local RW = INNER - RX
	local pane = CreateFrame("Frame", nil, content)
	pane:SetAllPoints()
	frame.guide = pane
	pane.RX, pane.RW = RX, RW
	pane.bodyTop = TOP - TITLE_H
	pane.areaH = pane.bodyTop - (PAGER_Y + AREA_BOTTOM)
	local half = math.floor((RW - TYPE_W - 2 * CELL_GAP) / 2)
	pane.cols = { types = { TYPE_W, half, half }, titles = { 80, 170, RW - 80 - 170 - 2 * CELL_GAP } }

	-- sommaire : une tuile par section
	pane.rows = {}
	for index, key in ipairs(SECTIONS) do
		local row = Theme.CreateTile(pane, LIST_W, ROW_H)
		At(row, content, 0, TOP - (index - 1) * ROW_STEP)
		row.section = key
		row.rowFill = index % 2 == 0 and Theme.ROW_ALT or Theme.ROW
		row:SetFill(row.rowFill)
		row.label = NoWrap(Text(row, Theme.F_BODY, Theme.LABEL, LIST_W - 20))
		row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
		row.label:SetText(L["GUIDE_SEC_" .. key])
		row:SetScript("OnClick", function(r) ns:JournalGuidePick(r.section) end)
		pane.rows[index] = row
	end

	-- le bouton « Revoir le tutoriel », en bas de la colonne du sommaire
	pane.replay = Theme.CreateButton(pane, "auto", Theme.PAGER_HEIGHT, L.GUIDE_REPLAY, function() ns:JournalGuideReplay() end, "accent")
	At(pane.replay, content, 0, PAGER_Y)
	if pane.replay.HookScript then
		pane.replay:HookScript("OnEnter", function(b) Tip(b, L.GUIDE_REPLAY, { L.GUIDE_REPLAY_TIP }) end)
		pane.replay:HookScript("OnLeave", HideTip)
	end

	-- à droite : le titre de la section, les blocs, la pagination
	pane.title = NoWrap(Text(pane, Theme.F_TITLE, Theme.PARCHMENT, RW))
	At(pane.title, content, RX, TOP)
	pane.paras, pane.heads, pane.trows, pane.theads = {}, {}, {}, {}
	pane.probes = {}
	pane.pager = Theme.CreatePager(pane, function(delta)
		-- chevrons : une page entière (la molette, ScrollJournal : un bloc)
		frame.guideOffset = (tonumber(frame.guideOffset) or 0) - delta * math.max(1, pane.shown or 1)
		ns:RefreshJournal()
	end)
	pane.pager:SetPoint("TOPRIGHT", content, "TOPLEFT", PAD + INNER, PAGER_Y)
	pane.hint = NoWrap(Text(pane, Theme.F_SMALL, Theme.MUTED, 200))
	pane.hint:SetPoint("RIGHT", pane.pager, "LEFT", -12, 0)
	pane.hint:SetJustifyH("RIGHT")
	pane:Hide()
end

-- ---------------------------------------------------------------------------
-- Mesure et pose des blocs
-- ---------------------------------------------------------------------------
-- hauteur d'un texte dans une largeur, avec une sonde par police
local function MeasureText(pane, text, width, font)
	local probe = pane.probes[font]
	if not probe then
		probe = Theme.Text(pane, font, Theme.TEXT)
		probe:Hide()
		pane.probes[font] = probe
	end
	probe:SetWidth(width)
	if probe.SetWordWrap then probe:SetWordWrap(true) end
	probe:SetText(text)
	local height = Theme.TextHeight(probe, width, font)
	probe:SetText("")
	return math.max(14, math.ceil(height))
end

local function RowFonts(head)
	if head then return { Theme.F_CAPS, Theme.F_CAPS, Theme.F_CAPS } end
	return { Theme.F_LABEL, Theme.F_SMALL, Theme.F_SMALL }
end

local function MeasureBlock(pane, block)
	if block.kind == "p" then return MeasureText(pane, block.text, pane.RW, Theme.F_BODY) end
	if block.kind == "h" then return MeasureText(pane, block.text, pane.RW, Theme.F_LABEL) end
	local fonts = RowFonts(block.head)
	local tallest = 0
	for index, cell in ipairs(block.cells) do
		local text = block.head and Theme.Upper and Theme.Upper(cell) or cell
		tallest = math.max(tallest, MeasureText(pane, text, block.cols[index], fonts[index]))
	end
	return tallest + 2 * CELL_PAD + 1
end

-- espace au-dessus d'un bloc (rien pour le premier de la page)
local function GapBefore(blocks, index, first)
	if first then return 0 end
	local block, previous = blocks[index], blocks[index - 1]
	if block.kind == "h" then return H_BEFORE end
	if previous and previous.kind == "h" then return H_AFTER end
	if block.kind == "row" then return (previous and previous.kind == "row") and 0 or P_GAP end
	return P_GAP
end

local function NewText(pane, font, color)
	local text = Wrap(Theme.Text(pane, font, color))
	text:SetJustifyH("LEFT")
	return text
end

-- une rangée de table : trois cellules et un filet en dessous
local function NewRow(pane, head)
	local row = CreateFrame("Frame", nil, pane)
	local fonts = RowFonts(head)
	local colors = head and { Theme.MUTED_LIGHT, Theme.MUTED_LIGHT, Theme.MUTED_LIGHT } or { Theme.LABEL, Theme.TEXT, Theme.TEXT }
	row.cells = {}
	for index = 1, 3 do
		local cell = NewText(row, fonts[index], colors[index])
		row.cells[index] = cell
	end
	row.line = Theme.Solid(row, "ARTWORK", head and Theme.GOLD or Theme.EDGE_SOFT, head and 0.8 or 1)
	row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.line:SetHeight(1)
	return row
end

local function Pooled(pane, kind, head, used)
	local list, make
	if kind == "p" then list, make = pane.paras, function() return NewText(pane, Theme.F_BODY, Theme.TEXT) end
	elseif kind == "h" then list, make = pane.heads, function() return NewText(pane, Theme.F_LABEL, Theme.GOLD) end
	elseif head then list, make = pane.theads, function() return NewRow(pane, true) end
	else list, make = pane.trows, function() return NewRow(pane, false) end end
	local key = kind == "row" and (head and "thead" or "trow") or kind
	used[key] = (used[key] or 0) + 1
	local region = list[used[key]]
	if not region then
		region = make()
		list[used[key]] = region
	end
	return region
end

local function HideAll(pane)
	for _, list in ipairs({ pane.paras, pane.heads, pane.trows, pane.theads }) do
		for _, region in ipairs(list) do region:Hide() end
	end
end

local function Place(self, pane, content, block, y, height, used)
	local At = ns.JournalUI.At
	local region = Pooled(pane, block.kind, block.head, used)
	At(region, content, pane.RX, pane.bodyTop - y)
	if block.kind == "p" or block.kind == "h" then
		region:SetWidth(pane.RW)
		region:SetHeight(height)
		region:SetText(block.text)
	else
		region:SetSize(pane.RW, height)
		local x = 0
		for index, cell in ipairs(region.cells) do
			local text = block.cells[index] or ""
			if block.head and Theme.Upper then text = Theme.Upper(text) end
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", region, "TOPLEFT", x, -CELL_PAD)
			cell:SetWidth(block.cols[index])
			cell:SetHeight(height - 2 * CELL_PAD - 1)
			cell:SetText(text)
			x = x + block.cols[index] + CELL_GAP
		end
	end
	region:Show()
	return region
end

-- ---------------------------------------------------------------------------
-- Choix, molette, rejeu
-- ---------------------------------------------------------------------------
function ns:JournalGuidePick(section)
	local frame = self.journalFrame
	if not frame then return end
	frame.guideSection, frame.guideOffset = SectionOf(section), 0
	self:RefreshJournal()
end

local function Scroll(self, frame, delta)
	frame.guideOffset = (tonumber(frame.guideOffset) or 0) - (tonumber(delta) or 0)
end

-- Ouvre le carnet sur la page Guide (fin du tutoriel de la ménagerie, Companion.lua)
function ns:OpenJournalGuide(section)
	if not self.ToggleJournal then return nil end
	local frame = self:ToggleJournal(true)
	if not frame then return nil end
	if section then frame.guideSection, frame.guideOffset = SectionOf(section), 0 end
	self:SelectJournalKind("guide")
	return frame
end

-- « Revoir le tutoriel » : le carnet se ferme, le compagnon rejoue les bulles
function ns:JournalGuideReplay()
	if not self.CompanionStartMenagerieTutorial then return false end
	local frame = self.journalFrame
	if frame and frame:IsShown() then frame:Hide() end
	if self.CompanionUpdateVisibility then self:CompanionUpdateVisibility() end
	return self:CompanionStartMenagerieTutorial()
end

-- ---------------------------------------------------------------------------
-- Rafraîchissement
-- ---------------------------------------------------------------------------
local function Refresh(self, frame, ui)
	local pane = frame.guide
	if not pane then return end
	local section = SectionOf(frame.guideSection)
	frame.guideSection = section
	for _, row in ipairs(pane.rows) do
		local on = row.section == section
		row:SetSelected(on)
		row:SetAccent(on and Theme.GOLD or nil)
		row:SetFill(on and Theme.ROW_ALT or row.rowFill)
		Paint(row.label, on and Theme.PARCHMENT or Theme.LABEL)
	end
	pane.title:SetText(L["GUIDE_SEC_" .. section])
	local blocks = self:JournalGuideBlocks(section, pane.cols)
	local heights = {}
	for index, block in ipairs(blocks) do heights[index] = MeasureBlock(pane, block) end
	-- combien de blocs tiennent depuis `start` (au moins un)
	local function Fit(start)
		local y, count = 0, 0
		for index = start + 1, #blocks do
			local h = heights[index] + GapBefore(blocks, index, count == 0)
			if count > 0 and y + h > pane.areaH then break end
			y, count = y + h, count + 1
		end
		return count
	end
	-- la dernière page : la plus petite position d'où tout le reste tient
	local maxOffset = 0
	for start = 0, math.max(0, #blocks - 1) do
		if Fit(start) >= #blocks - start then maxOffset = start; break end
	end
	local offset = math.max(0, math.min(tonumber(frame.guideOffset) or 0, maxOffset))
	frame.guideOffset = offset
	HideAll(pane)
	local y, shown, used = 0, 0, {}
	for index = offset + 1, #blocks do
		local gap = GapBefore(blocks, index, shown == 0)
		local h = heights[index]
		if shown > 0 and y + gap + h > pane.areaH then break end
		y = y + gap
		Place(self, pane, frame.content, blocks[index], y, h, used)
		y = y + h
		shown = shown + 1
	end
	pane.shown, pane.blocks = shown, #blocks
	pane.pager:Update(offset, shown, #blocks, maxOffset)
	pane.hint:SetText(#blocks > shown and L.GUIDE_MORE or "")
end

ns.GUIDE_DEFAULT_COLS = { types = { TYPE_W, 190, 190 }, titles = { 80, 170, 220 } }
ns.JOURNAL_PANES = ns.JOURNAL_PANES or {}
ns.JOURNAL_PANES.guide = {
	field = "guide", title = "JRN_SEC_guide", subtitle = "JRN_SUB_guide",
	build = Build, refresh = Refresh, scroll = Scroll,
}
ns.JOURNAL_GUIDE_LAYOUT = { listW = LIST_W, gap = GAP, rowH = ROW_H, rowStep = ROW_STEP, titleH = TITLE_H }

if ns.Mark then ns.Mark("JournalGuide") end
