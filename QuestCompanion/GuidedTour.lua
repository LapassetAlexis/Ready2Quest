-- GuidedTour.lua -- tutoriels guidés, « façon Pendo » (QuestCompanion 3.0.0)
--
-- 3.0.0 : un moteur de visites guidées, et trois visites.
--   * une ÉTAPE = { anchor = cadre ou fonction qui le rend, title, text
--     (clés de chaînes FR/EN, ou fonction), placement ("top", "bottom",
--     "left", "right", "center"), highlight (liseré doré qui bat autour de
--     l'ancre ; true par défaut), waitFor (fonction : l'étape passe d'elle-
--     même quand le joueur a fait le geste), ready (l'étape attend, cachée,
--     que ce soit vrai), when (l'étape n'existe que si c'est vrai, lu en y
--     arrivant), abort (rend "stop" : la visite s'arrête sans être marquée
--     vue ; "restart" : elle reprend à sa première étape), noNext (pas de
--     « Suivant » : le geste fait avancer), fallback (ancre absente : bulle
--     au centre de l'écran), visible (l'ancre se voit-elle ? sinon, son
--     IsVisible), onShow (à l'affichage : changer d'onglet…) ;
--   * une bulle (Azeroth : le parchemin de la bulle du compagnon ; Sobre : le
--     fond sombre du socle) : titre, « 2 / 6 », texte, « Passer le tutoriel »
--     et « Suivant » (« Terminer » à la dernière). Échap = passer ;
--   * jamais en combat : la visite se met en pause (bulle cachée) et
--     reprend à la même étape après le combat ; démarrée en combat, elle
--     attend la fin du combat ;
--   * ancre absente : l'étape attend quelques secondes (TOUR.missingWait)
--     puis passe ; une ancre qui disparaît après l'affichage (carte refermée,
--     filet lancé) fait passer à l'étape suivante ;
--   * vu une fois par COMPTE : ns:DB().tour30 = { capture, journal,
--     migration } (une clé propre à la 3.0 : aucun ancien drapeau, ni
--     tutoMenagerieDone ni tutoDone, ne l'empêche). /qc tuto [capture |
--     carnet | reset | passer] et les deux boutons de la page Guide les
--     rejouent.
-- Les visites :
--   * « capture » (les premières captures) : à la première occasion de
--     capture (CaptureQueue.lua, ns:TourCaptureOpportunity), hors combat, le
--     tutoriel de base du compagnon fini : le filet, la carte de
--     préparation, Lancer / Passer, où va la prise (Codex ou Réserve), le
--     mode chasse ;
--   * « journal » (le carnet) : à sa première ouverture, un onglet par étape
--     (l'onglet est montré et ouvert) ;
--   * « migration » : à la connexion (TOUR.migrationDelay s après), une fois,
--     pour qui avait des créatures avant la 3.0 (spécimens « migration ») :
--     ce qu'elles sont devenues, avec les vrais chiffres ; « Visiter le
--     carnet » lance la visite du carnet. Ouvert avant, le carnet la montre
--     en première étape.
-- Le tutoriel de la ménagerie en bulles (2.3.0) est retiré : ces visites le
-- remplacent (Companion.lua).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

-- départ automatique (coupé dans le banc de test, comme le tirage des missions)
ns.TOUR_AUTO = ns.TOUR_AUTO ~= false
ns.TOUR = {
	w = 290, wideW = 360, pad = 12, gap = 10, titleH = 16, button = 24, nextW = 112, skipW = 140,
	tick = 0.1,            -- s entre deux lectures des conditions (pas à chaque image)
	missingWait = 3,       -- s qu'une étape attend son ancre avant de passer
	migrationDelay = 6,    -- s après la connexion avant l'explication de la migration
	pulse = 1.6,           -- s d'un battement du liseré
	outset = 4,            -- px du liseré autour de l'ancre
	strata = "FULLSCREEN_DIALOG",
}
local TOUR = ns.TOUR
-- rôles mesurés (style Azeroth) : la bulle reprend le fond de celle du
-- compagnon (fichier 130661 en Cover, aplat parchemin, voile « bubble » 0,40),
-- donc les pires fonds mesurés pour « bubble.name » / « bubble.text » ;
-- versés dans ns.AZEROTH_CONTRAST à la première bulle.
ns.TOUR_CONTRAST = {
	["tour.title"] = { "title", 0.3918, 4.5, 12 },    -- comme bubble.name : 5.19:1
	["tour.text"] = { "ink", 0.3838, 4.5, 12 },       -- comme bubble.text : 7.78:1
	["tour.step"] = { "inkMuted", 0.3838, 4.5, 10 },  -- compteur « 2 / 6 », même fond : 5.85:1
}
-- Sobre : sur le fond du socle (Theme.WINDOW), contrastes mesurés dans le test
ns.TOUR_SOBRE = { title = Theme.PARCHMENT, text = Theme.TEXT, step = Theme.MUTED_LIGHT, ring = Theme.GOLD_LIGHT }

local FR = {
	TOUR_NEXT            = "Suivant",
	TOUR_DONE            = "Terminer",
	TOUR_SKIP            = "Passer le tutoriel",
	TOUR_STEP            = "%d / %d",
	TOUR_MSG_SKIPPED     = "Tutoriel passé. Pour le revoir : /qc tuto capture, /qc tuto carnet, ou la page Guide du carnet.",
	TOUR_MSG_COMBAT      = "Le tutoriel commencera après le combat.",
	TOUR_MSG_ARMED       = "Le tutoriel des captures t'accompagnera à ta prochaine occasion de capture.",
	TOUR_MSG_LATER       = "Le monstre est parti : le tutoriel des captures reprendra à la prochaine occasion.",
	TOUR_MSG_RESET       = "Tutoriels remis à zéro : les captures à la prochaine occasion, le carnet à sa prochaine ouverture.",
	TOUR_MSG_BUSY        = "Un tutoriel est déjà en cours (/qc tuto passer pour l'arrêter).",
	HELP_TOUR            = "/qc tuto [capture|carnet|reset|passer] -- les tutoriels guidés",
	-- visite des premières captures
	TOUR_A1_T            = "Un spécimen repéré !",
	TOUR_A1              = "Le filet n'apparaît que quand ça vaut le coup : espèce nouvelle, brillante, ou meilleur spécimen que le tien. Le badge d'étoiles montre sa qualité. Clique sur le filet.",
	TOUR_A2_T            = "La carte de préparation",
	TOUR_A2              = "En haut, la qualité (1 à 3 étoiles) : plus le spécimen est beau, plus il se débat. Dessous, ta chance. Choisis une aide : la chance se met à jour.",
	TOUR_A3_T            = "Lancer ou passer",
	TOUR_A3              = "Lancer : le filet part. Passer : le monstre sort du filet (clic droit : ne plus proposer l'espèce). Raccourci : Maj + clic sur le filet lance tout de suite.",
	TOUR_A4_T            = "Où va ta prise ?",
	TOUR_A4_codex        = "Capturé ! C'est ton meilleur spécimen de l'espèce : il va au Codex. Les suivants, s'ils ne le battent pas, iront dans ta Réserve. Clic droit sur ton compagnon : le carnet.",
	TOUR_A4_reserve      = "Capturé ! Ton Codex avait déjà mieux : ce spécimen rejoint ta Réserve. Clic droit sur ton compagnon : le carnet, pour voir Codex et Réserve.",
	TOUR_A4_fail         = "Il s'est échappé, ça arrive. Réussie, une capture va au Codex (ton meilleur de chaque espèce) ou dans ta Réserve. Clic droit sur ton compagnon : le carnet.",
	TOUR_A5_T            = "Le mode chasse",
	TOUR_A5              = "Maj + clic droit sur ton compagnon : le mode chasse. De 5 min à 1 h, chaque monstre abattu va au filet. Méfiance : chaque capture d'une même espèce dans la journée rend la suivante plus dure.",
	-- visite du carnet (titres : le nom de l'onglet)
	TOUR_B_evolution     = "Ton compagnon : son humeur, ses envies (faim, énergie, moral, curiosité) et ses effets. « Choisir… » change son allure.",
	TOUR_B_menagerie     = "Le Codex : ton meilleur spécimen de chaque espèce. « À compléter » montre ce qui manque ; épingle une espèce pour qu'elle passe toujours au filet, « Localiser » dit où la trouver.",
	TOUR_B_reserve       = "Tes spécimens en plus. « Mettre au Codex » en fait ta référence ; « Relâcher » rend des paillettes, à dépenser à l'Échoppe du dresseur. Chaque spécimen a son caractère (un petit effet quand ton compagnon le porte) et sa taille : un minuscule ou un géant, c'est rare ! Et pour échanger avec un autre joueur : /qc echange <nom> (vue Échanges).",
	TOUR_B_feats         = "Tes hauts faits et leurs points : certains donnent des titres et des apparences pour ton compagnon.",
	TOUR_B_day           = "Trois missions par jour et trois par semaine : friandises, aides et paillettes à la clé.",
	TOUR_B_progress      = "Chaque zone : lieux, récolte, quêtes. « n à compléter » compte les espèces de la zone sans 3 étoiles au Codex.",
	TOUR_B_juke          = "La musique du jeu : écoute, mets en favoris, fais ta liste.",
	TOUR_B_guide         = "Tout est expliqué ici, avec les chiffres. En bas à gauche, deux boutons rejouent ces tutoriels.",
	-- ta collection d'avant la 3.0
	TOUR_MIG_T           = "Ta collection passe en 3.0",
	TOUR_MIG             = "Tes créatures capturées avant la 3.0 (%d espèces) sont devenues %d spécimens au Codex, dont %d brillants, gardés à part. Rien n'est perdu : apparences, hauts faits et Ménagerie ne bougent pas ; ces spécimens portent la mention « %s ».\n\nDésormais, la qualité se tire au coup fatal et le filet ne vient que si ça vaut le coup : les réglages « Recaptures » ont disparu. Une nouvelle capture va au Codex si elle bat la tienne, sinon dans ta Réserve. À voir dans le carnet : Créatures et Réserve.",
	TOUR_MIG_GO          = "Visiter le carnet",
	TOUR_MIG_LATER       = "Plus tard",
	TOUR_MIG_GIFT        = "Et un cadeau t'attend : choisis jusqu'à %d de tes créatures, une copie de chacune ira dans ta Réserve.",
	TOUR_GIFT_T          = "Cadeau de la 3.0",
	TOUR_GIFT            = "Choisis jusqu'à %d créatures pour ta Réserve : une copie de chacune (version normale, mêmes étoiles que ton Codex), de quoi échanger plus tard. « Plus tard » : le bouton reste dans la page Réserve.",
	TOUR_GIFT_GO         = "Choisir mes créatures",
}
local EN = {
	TOUR_NEXT            = "Next",
	TOUR_DONE            = "Done",
	TOUR_SKIP            = "Skip tutorial",
	TOUR_STEP            = "%d / %d",
	TOUR_MSG_SKIPPED     = "Tutorial skipped. To see it again: /qc tuto capture, /qc tuto carnet, or the journal's Guide page.",
	TOUR_MSG_COMBAT      = "The tutorial will start after combat.",
	TOUR_MSG_ARMED       = "The captures tutorial will walk you through your next capture opportunity.",
	TOUR_MSG_LATER       = "The monster is gone: the captures tutorial will resume at the next opportunity.",
	TOUR_MSG_RESET       = "Tutorials reset: captures at the next opportunity, the journal the next time you open it.",
	TOUR_MSG_BUSY        = "A tutorial is already running (/qc tuto passer to stop it).",
	HELP_TOUR            = "/qc tuto [capture|carnet|reset|passer] -- the guided tutorials",
	TOUR_A1_T            = "A specimen spotted!",
	TOUR_A1              = "The net only shows up when it's worth it: new species, shiny, or a better specimen than yours. The star badge shows its quality. Click the net.",
	TOUR_A2_T            = "The preparation card",
	TOUR_A2              = "At the top, the quality (1 to 3 stars): the finer the specimen, the harder it struggles. Below, your odds. Pick an aid: the odds update.",
	TOUR_A3_T            = "Throw or skip",
	TOUR_A3              = "Throw: the net flies. Skip: the monster leaves the net (right-click: stop offering the species). Shortcut: Shift + click on the net throws right away.",
	TOUR_A4_T            = "Where does it go?",
	TOUR_A4_codex        = "Captured! It's your best specimen of the species: it goes to the Codex. The next ones, unless they beat it, will go to your Reserve. Right-click your companion: the journal.",
	TOUR_A4_reserve      = "Captured! Your Codex already had better: this specimen joins your Reserve. Right-click your companion: the journal, to see Codex and Reserve.",
	TOUR_A4_fail         = "It got away, it happens. When it works, a capture goes to the Codex (your best of each species) or to your Reserve. Right-click your companion: the journal.",
	TOUR_A5_T            = "Hunt mode",
	TOUR_A5              = "Shift + right-click your companion: hunt mode. From 5 min to 1 h, every defeated monster goes to the net. Wariness: each capture of the same species in a day makes the next one harder.",
	TOUR_B_evolution     = "Your companion: its mood, its needs (hunger, energy, mood, curiosity) and its effects. \"Choose…\" changes its look.",
	TOUR_B_menagerie     = "The Codex: your best specimen of each species. \"To complete\" shows what's missing; pin a species so it always comes to the net, \"Locate\" tells where to find it.",
	TOUR_B_reserve       = "Your extra specimens. \"Set in Codex\" makes one your reference; \"Release\" gives glitter, to spend at the Trainer's shop. Each specimen has its own character (a small effect when your companion wears it) and size: a tiny or a giant one is rare! And to trade with another player: /qc trade <name> (Trades view).",
	TOUR_B_feats         = "Your achievements and their points: some grant titles and looks for your companion.",
	TOUR_B_day           = "Three missions a day and three a week: treats, aids and glitter as rewards.",
	TOUR_B_progress      = "Each zone: places, gathering, quests. \"n to complete\" counts the zone's species without 3 stars in the Codex.",
	TOUR_B_juke          = "The game's music: listen, add favourites, build your list.",
	TOUR_B_guide         = "Everything is explained here, with the numbers. Bottom left, two buttons replay these tutorials.",
	TOUR_MIG_T           = "Your collection moves to 3.0",
	TOUR_MIG             = "Your creatures captured before 3.0 (%d species) became %d specimens in the Codex, including %d shinies, kept apart. Nothing is lost: looks, achievements and Menagerie stay the same; these specimens are marked \"%s\".\n\nFrom now on, quality is rolled at the kill and the net only shows up when it's worth it: the \"Recaptures\" settings are gone. A new capture goes to the Codex if it beats yours, otherwise to your Reserve. See it in the journal: Creatures and Reserve.",
	TOUR_MIG_GO          = "Visit the journal",
	TOUR_MIG_LATER       = "Later",
	TOUR_MIG_GIFT        = "And a gift awaits: pick up to %d of your creatures, a copy of each goes to your Reserve.",
	TOUR_GIFT_T          = "3.0 gift",
	TOUR_GIFT            = "Pick up to %d creatures for your Reserve: a copy of each (normal version, same stars as your Codex), something to trade later. \"Later\": the button stays on the Reserve page.",
	TOUR_GIFT_GO         = "Pick my creatures",
}
ns.RegisterStrings(FR, EN)
if ns.KEEP_STRINGS then ns.TOUR_STRINGS = { fr = FR, en = EN } end

local function G(name) return rawget(_G, name) end
local function Clock() return (ns.Now and ns.Now()) or 0 end
local function Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end
local function InCombat()
	if Call(G("InCombatLockdown")) then return true end
	return Call(G("UnitAffectingCombat"), "player") and true or false
end
local function Visible(frame)
	if type(frame) ~= "table" or not frame.IsShown then return false end
	if frame.IsVisible then
		local ok, shown = pcall(frame.IsVisible, frame)
		if ok then return shown and true or false end
	end
	return frame:IsShown() and true or false
end

-- ---------------------------------------------------------------------------
-- Sauvegarde (au compte) : ns:DB().tour30
-- ---------------------------------------------------------------------------
function ns:TourData()
	local db = self:DB()
	if type(db.tour30) ~= "table" then db.tour30 = {} end
	return db.tour30
end
function ns:TourDone(id) return self:TourData()[id] == true end
function ns:TourMark(id, done) self:TourData()[id] = done and true or nil end

-- Les spécimens venus de la migration (CaptureSpecimens.lua) : espèces,
-- spécimens, brillants
function ns:TourMigrationCounts()
	if not self.SpecimenMigratedCounts then return 0, 0, 0 end
	return self:SpecimenMigratedCounts()
end
local function GiftOpen(self) return self.Gift30Available and self:Gift30Available() or false end
local function MigrationPending(self)
	if self:TourDone("migration") then return false end
	local _, total = self:TourMigrationCounts()
	return total > 0
end
local function MigrationText(self)
	local species, total, shiny = self:TourMigrationCounts()
	local text = self:F("TOUR_MIG", species, total, shiny, L.RES_BY_MIGRATION or "")
	if GiftOpen(self) then text = text .. "\n\n" .. self:F("TOUR_MIG_GIFT", ns.GIFT30.max) end
	return text
end

-- ---------------------------------------------------------------------------
-- Les visites
-- ---------------------------------------------------------------------------
local function Stage()
	local frame = ns.captureStage
	if frame and frame.prep and frame:IsShown() then return frame end
	return nil
end
local function QueueCount()
	local state = ns.captureState
	return state and state.queue and #state.queue or 0
end
local function Rolling()
	local state = ns.captureState
	return state ~= nil and state.rolling ~= nil
end

local DEFS = {}
ns.TOUR_DEFS = DEFS

DEFS.capture = {
	steps = {
		{ id = "net", anchor = function() return ns.captureNetButton end, title = "TOUR_A1_T", text = "TOUR_A1",
			placement = "top", noNext = true, pulseNet = true,
			waitFor = function(_, ctx) return ctx.thrown or Stage() ~= nil end,
			-- le monstre est parti avant le clic : on reprendra à l'occasion suivante
			abort = function(_, ctx)
				if not ctx.thrown and QueueCount() == 0 and not Stage() and not Rolling() then return "stop" end
			end },
		{ id = "card", anchor = function() local f = Stage(); return f and f.details end, title = "TOUR_A2_T", text = "TOUR_A2",
			placement = "right", when = function(_, ctx) return not ctx.thrown end },
		{ id = "launch", anchor = function() local f = Stage(); return f and f.launch end, title = "TOUR_A3_T", text = "TOUR_A3",
			placement = "bottom", noNext = true, when = function(_, ctx) return not ctx.thrown end },
		{ id = "result", anchor = function() return ns.companionFrame end, fallback = true, title = "TOUR_A4_T",
			text = function(_, ctx) return L["TOUR_A4_" .. (ctx.result == "ok" and (ctx.place or "codex") or "fail")] end,
			placement = "top", ready = function(_, ctx) return ctx.result ~= nil end,
			waitFor = function(_, ctx) return ctx.journal end,
			-- carte fermée sans lancer : retour au filet ; filet vide : on reprendra
			abort = function(_, ctx)
				if ctx.result or Rolling() or Stage() then return nil end
				if QueueCount() > 0 then return "restart" end
				return "stop"
			end },
		{ id = "hunt", anchor = function() return ns.companionFrame end, fallback = true, title = "TOUR_A5_T", text = "TOUR_A5",
			placement = "top" },
	},
	-- fini : le carnet ouvert entre-temps a sa visite
	finish = function(self)
		local journal = self.journalFrame
		if journal and journal:IsShown() and not self:TourDone("journal") then self:TourStart("journal") end
	end,
}

local function JournalTab(key)
	return {
		id = key, anchor = function()
			local frame = ns.journalFrame
			return frame and frame.sections and frame.sections[key]
		end,
		title = function() return L["JRN_SEC_" .. key] end, text = "TOUR_B_" .. key, placement = "right",
		-- l'onglet se voit tant que le carnet est ouvert
		visible = function()
			local frame = ns.journalFrame
			return frame ~= nil and frame:IsShown()
		end,
		when = function()
			local frame = ns.journalFrame
			return frame ~= nil and frame.sections ~= nil and frame.sections[key] ~= nil
		end,
		onShow = function(self)
			local frame = self.journalFrame
			if frame and frame.kind ~= key and self.SelectJournalKind then self:SelectJournalKind(key) end
		end,
	}
end

DEFS.journal = {
	steps = {
		-- ta collection d'avant la 3.0, si la connexion ne l'a pas déjà dit
		{ id = "migration", anchor = function() return ns.journalFrame end, placement = "center", highlight = false,
			title = "TOUR_MIG_T", text = MigrationText, wide = true, count = true,
			when = function(self) return MigrationPending(self) end,
			onShow = function(self) self:TourMark("migration", true) end },
		JournalTab("evolution"), JournalTab("menagerie"), JournalTab("reserve"), JournalTab("feats"),
		JournalTab("day"), JournalTab("progress"), JournalTab("juke"), JournalTab("guide"),
	},
	-- le carnet refermé : la visite s'arrête (elle reprendra à sa prochaine ouverture)
	abort = function()
		local frame = ns.journalFrame
		if not (frame and frame:IsShown()) then return "stop" end
	end,
}

DEFS.migration = {
	steps = {
		{ id = "migration", anchor = function() return ns.companionFrame end, fallback = true, placement = "top",
			highlight = false, title = "TOUR_MIG_T", text = MigrationText, wide = true,
			nextLabel = function(self) return GiftOpen(self) and L.TOUR_NEXT or L.TOUR_MIG_GO end, skipLabel = "TOUR_MIG_LATER",
			onShow = function(self) self:TourMark("migration", true) end },
		-- le cadeau de la 3.0 (plus de 3 espèces avant la 3.0, pas encore choisi)
		{ id = "gift", anchor = function() return ns.companionFrame end, fallback = true, placement = "top",
			highlight = false, title = "TOUR_GIFT_T", text = function(self) return self:F("TOUR_GIFT", ns.GIFT30.max) end,
			wide = true, nextLabel = "TOUR_GIFT_GO", skipLabel = "TOUR_MIG_LATER",
			when = function(self) return GiftOpen(self) end },
	},
	-- « Choisir mes créatures » : le carnet s'ouvre sur le cadeau (page
	-- Réserve) ; sinon « Visiter le carnet » : le carnet et sa visite
	finish = function(self)
		if GiftOpen(self) and self.Gift30Open then return self:Gift30Open() end
		local journal = self.journalFrame
		if journal and journal:IsShown() then
			if not self:TourDone("journal") then self:TourStart("journal") end
		elseif self.ToggleJournal then
			self:ToggleJournal(true)
		end
	end,
}

-- ---------------------------------------------------------------------------
-- La bulle et le liseré (un jeu par style, créé une fois)
-- ---------------------------------------------------------------------------
local function TourStyle(self)
	return (self.AzerothOn and self:AzerothOn()) and "azeroth" or "sobre"
end

local function RoleInk(fs, role)
	local entry = ns.TOUR_CONTRAST[role]
	local ink = entry and ns.AZEROTH_INK and ns.AZEROTH_INK[entry[1]]
	if not ink then return false end
	fs:SetTextColor(ink[1], ink[2], ink[3], 1)
	if Theme.NoShadow then Theme.NoShadow(fs) end
	fs.azRole = role
	return true
end

function ns.TourContrastMerge()
	local table_ = ns.AZEROTH_CONTRAST
	if type(table_) ~= "table" then return false end
	for role, entry in pairs(ns.TOUR_CONTRAST) do
		if table_[role] == nil then table_[role] = entry end
	end
	return true
end

local function Paint(fs, az, role, color)
	if az and RoleInk(fs, role) then return end
	fs:SetTextColor(color[1], color[2], color[3], 1)
end

local function BuildCallout(self, style)
	local az = style == "azeroth"
	local name = az and "QuestCompanionTourCalloutAzeroth" or "QuestCompanionTourCallout"
	local frame = CreateFrame("Frame", name, UIParent)
	frame:SetSize(TOUR.w, 120)
	frame:SetFrameStrata(TOUR.strata)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame.uiStyle = style
	if az then
		ns.TourContrastMerge()
		local p = ns.AZEROTH_PARCH_SOLID or Theme.PARCHMENT
		frame.back = Theme.Solid(frame, "BACKGROUND", p, 1)
		frame.back:SetAllPoints(frame)
		frame.parch = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
		frame.parch:SetAllPoints(frame)
		if not (ns.AzerothFileTexture and ns.AZEROTH_TALK_FILE and ns.AzerothFileTexture(frame.parch, ns.AZEROTH_TALK_FILE)) then
			frame.parch:Hide()
		end
		if ns.AzerothVeil then frame.veil = ns.AzerothVeil(frame, frame, "bubble", 2) end
		local edge = ns.AZEROTH_INK and ns.AZEROTH_INK.bubbleEdge or Theme.EDGE
		frame.edge = Theme.Border(frame, edge, 1, "BORDER")
	else
		frame.bg = Theme.Solid(frame, "BACKGROUND", Theme.WINDOW, 0.97)
		frame.bg:SetAllPoints(frame)
		frame.edge = Theme.Border(frame, Theme.GOLD, 1, "BORDER")
	end
	frame.title = Theme.Text(frame, az and Theme.F_CAPS or Theme.F_LABEL, ns.TOUR_SOBRE.title)
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", TOUR.pad, -TOUR.pad)
	frame.title:SetJustifyH("LEFT")
	if frame.title.SetWordWrap then frame.title:SetWordWrap(false) end
	frame.step = Theme.Text(frame, Theme.F_SMALL, ns.TOUR_SOBRE.step)
	frame.step:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -TOUR.pad, -TOUR.pad)
	frame.step:SetJustifyH("RIGHT")
	frame.text = Theme.Text(frame, Theme.F_BODY, ns.TOUR_SOBRE.text)
	frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", TOUR.pad, -TOUR.pad - TOUR.titleH - 6)
	frame.text:SetJustifyH("LEFT")
	if frame.text.SetJustifyV then frame.text:SetJustifyV("TOP") end
	if frame.text.SetWordWrap then frame.text:SetWordWrap(true) end
	if az and ns.AzerothFont then
		ns.AzerothFont(frame.title, 12)
		ns.AzerothFont(frame.step, 10)
		ns.AzerothFont(frame.text, 12)
	end
	Paint(frame.title, az, "tour.title", ns.TOUR_SOBRE.title)
	Paint(frame.step, az, "tour.step", ns.TOUR_SOBRE.step)
	Paint(frame.text, az, "tour.text", ns.TOUR_SOBRE.text)
	local function Next() ns:TourNext() end
	local function Skip() ns:TourSkip() end
	if az and self.AzerothButton then
		frame.nextButton = self:AzerothButton(frame, TOUR.nextW, TOUR.button, L.TOUR_NEXT, Next, "gold")
		frame.skipButton = self:AzerothButton(frame, TOUR.skipW, TOUR.button, L.TOUR_SKIP, Skip, "dark")
	else
		frame.nextButton = Theme.CreateButton(frame, TOUR.nextW, TOUR.button, L.TOUR_NEXT, Next, "primary")
		frame.skipButton = Theme.CreateButton(frame, TOUR.skipW, TOUR.button, L.TOUR_SKIP, Skip, "outline")
	end
	frame.nextButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -TOUR.pad, TOUR.pad)
	frame.skipButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", TOUR.pad, TOUR.pad)
	-- Échap (UISpecialFrames) referme la bulle : la visite est passée.
	-- Nos propres masquages (pause, ancre absente) passent par `quiet`.
	if Theme.RegisterEscapeClose then pcall(Theme.RegisterEscapeClose, frame) end
	frame:SetScript("OnHide", function(f)
		if f.quiet then return end
		local st = ns.tourState
		if not st then return end
		-- toute l'interface cachée (Alt+Z, cinématique) : pas un Échap, la
		-- même étape reviendra
		local root = rawget(_G, "UIParent")
		if root and root.IsShown and not root:IsShown() then st.shownIndex = nil; return end
		ns:TourSkip()
	end)
	frame.quiet = true
	frame:Hide()
	frame.quiet = nil
	return frame
end

local function BuildRing(style)
	local az = style == "azeroth"
	local ring = CreateFrame("Frame", nil, UIParent)
	ring:SetFrameStrata(TOUR.strata)
	ring:EnableMouse(false)
	local outer = az and ns.AZEROTH_BUTTONS and ns.AZEROTH_BUTTONS.gold.edge or ns.TOUR_SOBRE.ring
	ring.outer = Theme.Border(ring, outer, 1, "OVERLAY")
	ring.inner = CreateFrame("Frame", nil, ring)
	ring.inner:SetPoint("TOPLEFT", ring, "TOPLEFT", 1, -1)
	ring.inner:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", -1, 1)
	ring.innerEdge = Theme.Border(ring, Theme.GOLD, 1, "OVERLAY", ring.inner)
	ring.shadow = Theme.Border(ring, Theme.SHADOW, 0.6, "ARTWORK")
	-- le battement : l'alpha seul, à chaque image (aucune table créée)
	ring:SetScript("OnUpdate", function(r)
		local period = TOUR.pulse
		local phase = (Clock() % period) / period
		r:SetAlpha(0.45 + 0.55 * math.abs(math.sin(phase * math.pi)))
	end)
	ring:Hide()
	return ring
end

local function Parts(self)
	local style = TourStyle(self)
	self.tourUI = self.tourUI or {}
	local ui = self.tourUI[style]
	if not ui then
		ui = { callout = BuildCallout(self, style), ring = BuildRing(style), style = style }
		self.tourUI[style] = ui
	end
	return ui
end

local function QuietHide(frame)
	if not (frame and frame:IsShown()) then return end
	frame.quiet = true
	frame:Hide()
	frame.quiet = nil
end

-- Cache la bulle et le liseré (tous styles), sans passer la visite
function ns:TourHideUI()
	ns.tourNetPulse = nil
	for _, ui in pairs(self.tourUI or {}) do
		QuietHide(ui.callout)
		if ui.ring then ui.ring:Hide() end
	end
end

local function Resolve(self, value, ctx)
	if type(value) == "function" then return value(self, ctx) end
	if type(value) == "string" then return L[value] or value end
	return value
end

local function Place(callout, anchor, placement)
	local gap = TOUR.gap + TOUR.outset
	callout:ClearAllPoints()
	if placement == "bottom" then callout:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
	elseif placement == "left" then callout:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
	elseif placement == "right" then callout:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
	elseif placement == "center" then callout:SetPoint("CENTER", anchor, "CENTER", 0, 0)
	else callout:SetPoint("BOTTOM", anchor, "TOP", 0, gap) end
end

-- Le numéro de l'étape parmi celles comptées au départ
local function StepNumber(st)
	local n = 0
	for index = 1, st.index do
		if st.counted[index] then n = n + 1 end
	end
	return math.max(1, math.min(n, st.total))
end

local function ShowStep(self, st, step, anchor, fallback)
	local ui = Parts(self)
	local callout, ring = ui.callout, ui.ring
	local width = step.wide and TOUR.wideW or TOUR.w
	callout:SetWidth(width)
	local inner = width - 2 * TOUR.pad
	callout.title:SetWidth(inner - 50)
	callout.text:SetWidth(inner)
	callout.title:SetText(Resolve(self, step.title, st.ctx) or "")
	local text = Resolve(self, step.text, st.ctx) or ""
	callout.text:SetText(text)
	callout.step:SetText(self:F("TOUR_STEP", StepNumber(st), st.total))
	local last = st.index >= #st.def.steps
	callout.nextButton:SetText(step.nextLabel and Resolve(self, step.nextLabel, st.ctx) or (last and L.TOUR_DONE or L.TOUR_NEXT))
	callout.skipButton:SetText(step.skipLabel and Resolve(self, step.skipLabel, st.ctx) or L.TOUR_SKIP)
	if step.noNext then callout.nextButton:Hide() else callout.nextButton:Show() end
	callout.skipButton:Show()
	local textH = Theme.TextHeight and Theme.TextHeight(callout.text, inner, Theme.F_BODY) or 40
	local height = TOUR.pad + TOUR.titleH + 6 + math.ceil(tonumber(textH) or 40) + TOUR.gap + TOUR.button + TOUR.pad
	callout:SetHeight(height)
	if ui.style == "azeroth" and callout.parch and callout.parch:IsShown() and ns.AzerothCover and ns.AZEROTH_TALK_FILE then
		pcall(ns.AzerothCover, callout.parch, ns.AZEROTH_TALK_FILE, width, height)
	end
	if fallback then
		Place(callout, UIParent, "center")
	else
		Place(callout, anchor, step.placement)
	end
	callout.anchor = anchor
	callout:Show()
	if Theme.FadeIn then pcall(Theme.FadeIn, callout, 0.15) end
	if step.highlight ~= false and not fallback then
		ring:ClearAllPoints()
		ring:SetPoint("TOPLEFT", anchor, "TOPLEFT", -TOUR.outset, TOUR.outset)
		ring:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", TOUR.outset, -TOUR.outset)
		ring.anchor = anchor
		ring:Show()
	else
		ring.anchor = nil
		ring:Hide()
	end
	ns.tourNetPulse = step.pulseNet and true or nil
	return callout
end

-- ---------------------------------------------------------------------------
-- La machine
-- ---------------------------------------------------------------------------
local driver

local function Wake()
	if driver then driver.acc = TOUR.tick end
end

-- Démarre une visite. opts.force : arrête celle en cours ; opts.manual : un
-- rejeu (le chat dit pourquoi ça ne part pas) ; opts.defer : la première
-- étape attend le prochain relevé (le carnet finit de s'ouvrir).
function ns:TourStart(id, opts)
	opts = opts or {}
	local def = DEFS[id]
	if not def then return false end
	local st = self.tourState
	if st then
		if st.id == id then return false end
		if not opts.force then
			if opts.manual then self:Print(L.TOUR_MSG_BUSY) end
			return false
		end
		self:TourStop()
	end
	if InCombat() then
		self.tourPending = id
		if opts.manual then self:Print(L.TOUR_MSG_COMBAT) end
		return false
	end
	self.tourPending = nil
	st = { id = id, def = def, index = 1, ctx = {}, counted = {}, total = 0 }
	for index, step in ipairs(def.steps) do
		local counts = step.count ~= false and (not step.when or step.when(self, st.ctx))
		st.counted[index] = counts and true or nil
		if counts then st.total = st.total + 1 end
	end
	st.total = math.max(1, st.total)
	self.tourState = st
	if driver then driver:Show() end
	if not opts.defer then self:TourEvaluate() else Wake() end
	return true
end

function ns:TourActive()
	return self.tourState and self.tourState.id or nil
end

-- Arrêt sans rien marquer (abandon, carnet refermé, filet vidé)
function ns:TourStop()
	self.tourState = nil
	self:TourHideUI()
	return true
end

-- Fin : la visite est vue (au compte) ; `skipped` : passée
function ns:TourFinish(skipped)
	local st = self.tourState
	if not st then return false end
	self.tourState = nil
	self:TourHideUI()
	self:TourMark(st.id, true)
	if skipped then
		if st.id ~= "migration" then self:Print(L.TOUR_MSG_SKIPPED) end
	elseif st.def.finish then
		local ok, err = pcall(st.def.finish, self)
		if not ok and self.RecordError then self:RecordError("tour:finish", err) end
	end
	return true
end

function ns:TourSkip()
	if not self.tourState then
		if self.tourPending then self.tourPending = nil; return true end
		return false
	end
	return self:TourFinish(true)
end

-- « Suivant » : l'étape suivante (la dernière : fin)
function ns:TourNext()
	local st = self.tourState
	if not st then return false end
	st.index = st.index + 1
	st.shownIndex, st.missingSince = nil, nil
	self:TourEvaluate()
	return true
end

-- Combat : bulle cachée, même étape à la reprise
function ns:TourPause()
	local st = self.tourState
	if not st then return false end
	st.paused = true
	st.shownIndex = nil
	self:TourHideUI()
	return true
end

-- Un geste venu des modules : "throw" (le filet part), "result" (verdict :
-- `info` vrai si capturé), "journal" (le carnet s'ouvre)
function ns:TourSignal(tag, info)
	local st = self.tourState
	if not st then return false end
	local ctx = st.ctx
	if tag == "throw" then ctx.thrown = true
	elseif tag == "result" then ctx.result = info and "ok" or "fail"
	elseif tag == "journal" then ctx.journal = true
	else ctx[tag] = info == nil and true or info end
	self:TourEvaluate()
	return true
end

-- Où est allé le spécimen capturé (SpecimenAdd : Codex ou Réserve)
if ns.RegisterCallback then
	ns:RegisterCallback("SPECIMENS", function(self, what, id)
		local st = self.tourState
		if what ~= "add" or not (st and st.id == "capture") then return end
		st.ctx.place = (self.SpecimenIsReference and self:SpecimenIsReference(id)) and "codex" or "reserve"
	end)
end

-- Le cœur : passe les étapes finies, attend ce qui doit l'être, montre la bonne
function ns:TourEvaluate()
	local st = self.tourState
	if not st then return nil end
	if InCombat() then
		if not st.paused then self:TourPause() end
		return "paused"
	end
	if st.paused then st.paused, st.shownIndex = nil, nil end
	local def, ctx = st.def, st.ctx
	if def.abort and def.abort(self, ctx) == "stop" then self:TourStop(); return "stopped" end
	for _ = 1, #def.steps + 2 do
		local step = def.steps[st.index]
		if not step then self:TourFinish(false); return "finished" end
		local verdict = step.abort and step.abort(self, ctx)
		if verdict == "stop" then
			self:TourStop()
			if st.id == "capture" then self:Print(L.TOUR_MSG_LATER) end
			return "stopped"
		elseif verdict == "restart" then
			st.index, st.shownIndex, st.missingSince = 1, nil, nil
			step = def.steps[1]
		end
		if st.shownIndex ~= st.index and step.when and not step.when(self, ctx) then
			st.index = st.index + 1
		elseif step.ready and not step.ready(self, ctx) then
			if st.shownIndex then st.shownIndex = nil; self:TourHideUI() end
			return "waiting"
		else
			local anchor = Resolve(self, step.anchor, ctx)
			local shown
			if step.visible then shown = anchor ~= nil and step.visible(self, ctx) and true or false else shown = Visible(anchor) end
			if not shown and st.shownIndex == st.index then
				-- l'ancre est partie (carte refermée, filet lancé) : étape suivante
				st.index, st.shownIndex, st.missingSince = st.index + 1, nil, nil
				self:TourHideUI()
			elseif not shown and not step.fallback then
				local now = Clock()
				st.missingSince = st.missingSince or now
				if now - st.missingSince >= TOUR.missingWait then
					st.index, st.missingSince = st.index + 1, nil
				else
					self:TourHideUI()
					return "missing"
				end
			elseif step.waitFor and step.waitFor(self, ctx) then
				st.index, st.shownIndex, st.missingSince = st.index + 1, nil, nil
				self:TourHideUI()
			else
				st.missingSince = nil
				if st.shownIndex ~= st.index then
					st.shownIndex = st.index
					if step.onShow then
						local ok, err = pcall(step.onShow, self, ctx)
						if not ok and self.RecordError then self:RecordError("tour:onShow", err) end
					end
					ShowStep(self, st, step, anchor, not shown)
				end
				return "shown"
			end
		end
	end
	return nil
end

-- Le relevé (driver, toutes les TOUR.tick s ; aussi appelé par les tests)
function ns:TourTick(now)
	now = now or Clock()
	if self.tourPending and not self.tourState and not InCombat() then
		self:TourStart(self.tourPending)
	end
	if self.tourMigrationAt and now >= self.tourMigrationAt and not self.tourState and not InCombat() then
		self.tourMigrationAt = nil
		if MigrationPending(self) then self:TourStart("migration") end
	end
	if self.tourState then self:TourEvaluate() end
	local idle = not self.tourState and not self.tourPending and not self.tourMigrationAt
	if idle and driver then driver:Hide() end
	return self.tourState ~= nil
end

-- ---------------------------------------------------------------------------
-- Déclencheurs
-- ---------------------------------------------------------------------------
-- Occasion de capture (CaptureQueue.lua, hors combat) : la visite des
-- premières captures, une fois par compte (ou réarmée par le Guide)
function ns:TourCaptureOpportunity()
	if not ns.TOUR_AUTO or self:TourDone("capture") or self.tourState or InCombat() then return false end
	-- le tutoriel de base du compagnon (bulles) d'abord, sans chevauchement
	if self.CompanionTutorialActive and self:CompanionTutorialActive() then return false end
	if not Visible(self.captureNetButton) then return false end
	return self:TourStart("capture")
end

-- Le carnet s'ouvre (enveloppe de ns:ToggleJournal) : la visite du carnet,
-- une fois par compte ; pendant celle des captures, c'est un geste attendu
function ns:TourJournalOpened()
	local st = self.tourState
	if st then
		if st.id == "capture" then self:TourSignal("journal") end
		return false
	end
	if not ns.TOUR_AUTO or self:TourDone("journal") then return false end
	-- le carnet s'ouvre sur le cadeau de la 3.0 : sa visite attendra
	if self.tourHoldJournal then return false end
	return self:TourStart("journal", { defer = true })
end

do
	local toggle = ns.ToggleJournal
	if toggle then
		function ns:ToggleJournal(...)
			local frame = toggle(self, ...)
			if frame and frame:IsShown() then
				local ok, err = pcall(self.TourJournalOpened, self)
				if not ok and self.RecordError then self:RecordError("tour:journal", err) end
			end
			return frame
		end
	end
end

-- Rejeu (boutons du Guide, /qc tuto capture|carnet)
function ns:TourReplay(which)
	which = which == "journal" and "journal" or "capture"
	self:TourMark(which, false)
	if self.tourState and self.tourState.id ~= which then self:TourStop() end
	if which == "journal" then
		local frame = self.journalFrame
		if frame and frame:IsShown() then return self:TourStart("journal", { manual = true }) end
		if not self.ToggleJournal then return false end
		if InCombat() then self.tourPending = "journal"; self:Print(L.TOUR_MSG_COMBAT); return false end
		self:ToggleJournal(true)
		if not self.tourState then return self:TourStart("journal", { manual = true, defer = true }) end
		return true
	end
	-- les captures : tout de suite si le filet attend, sinon à la prochaine occasion
	if QueueCount() > 0 and Visible(self.captureNetButton) and not InCombat() then
		return self:TourStart("capture", { manual = true })
	end
	self:Print(L.TOUR_MSG_ARMED)
	return false
end

-- /qc tuto [capture|carnet|reset|passer]
function ns:TourCommand(rest)
	local arg = (tostring(rest or ""):match("^%s*(%S*)") or ""):lower()
	if arg == "capture" or arg == "captures" or arg == "filet" or arg == "net" then return self:TourReplay("capture") end
	if arg == "carnet" or arg == "journal" then return self:TourReplay("journal") end
	if arg == "reset" or arg == "raz" then
		self:TourStop()
		self:DB().tour30 = {}
		self:Print(L.TOUR_MSG_RESET)
		return true
	end
	if arg == "passer" or arg == "skip" or arg == "stop" then return self:TourSkip() end
	self:Print(L.HELP_TOUR)
	return false
end

if type(ns.HELP) == "table" then
	for _, section in ipairs(ns.HELP) do
		if section[1] == "HELP_H_OPEN" and type(section[2]) == "table" then
			table.insert(section[2], "HELP_TOUR")
		end
	end
end
if type(ns.EXTRA_COMMANDS) == "table" then
	ns.EXTRA_COMMANDS["tuto"] = function(self, rest) return self:TourCommand(rest) end
	ns.EXTRA_COMMANDS["tutoriel"] = ns.EXTRA_COMMANDS["tuto"]
	ns.EXTRA_COMMANDS["tutorial"] = ns.EXTRA_COMMANDS["tuto"]
end

-- Le relevé et les événements : un cadre, actif seulement quand il y a de
-- quoi faire (visite, départ en attente, explication de la connexion)
do
	local ok, frame = pcall(CreateFrame, "Frame")
	if ok and frame then
		driver = frame
		ns.tourDriver = frame
		frame.acc = 0
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		frame:RegisterEvent("PLAYER_REGEN_DISABLED")
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		frame:SetScript("OnEvent", function(_, event, isLogin, isReload)
			if event == "PLAYER_REGEN_DISABLED" then
				ns:TourPause()
			elseif event == "PLAYER_REGEN_ENABLED" then
				Wake()
				if ns.tourState or ns.tourPending then frame:Show() end
			elseif event == "PLAYER_ENTERING_WORLD" and (isLogin or isReload) and ns.TOUR_AUTO then
				-- une fois, au compte : ce que sont devenues les créatures d'avant la 3.0
				local okCount, pending = pcall(MigrationPending, ns)
				if okCount and pending then
					ns.tourMigrationAt = Clock() + TOUR.migrationDelay
					frame:Show()
				end
			end
		end)
		frame:SetScript("OnUpdate", function(f, elapsed)
			if not (ns.tourState or ns.tourPending or ns.tourMigrationAt) then return end
			f.acc = (f.acc or 0) + (tonumber(elapsed) or 0)
			if f.acc < TOUR.tick then return end
			f.acc = 0
			local okTick, err = pcall(ns.TourTick, ns)
			if not okTick and ns.RecordError then ns:RecordError("tour:tick", err) end
		end)
		frame:Hide()
	end
end

if ns.Mark then ns.Mark("GuidedTour") end
