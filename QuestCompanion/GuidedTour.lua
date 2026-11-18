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
--   * une bulle (forgé : un bandeau du socle ; Sobre : le fond sombre du
--     socle) : titre, « 2 / 6 », texte, « Passer le tutoriel »
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
-- 3.6.0 (la première heure) :
--   * la visite des captures suit la capture express (active par défaut) :
--     un clic = lancer, Maj + clic = toute la file, Ctrl + clic = la carte de
--     préparation (ses deux étapes ne viennent que si on l'ouvre) ; capture
--     express coupée : le déroulé d'avant (carte, Lancer / Passer) ;
--   * après la toute première capture du compte, une bulle « Partir avec
--     lui » / « Plus tard » (visite « mate ») : il devient l'apparence du
--     compagnon, et la bulle explique le lien ;
--   * à la première tâche d'étude finie, une bulle, une fois (visite
--     « study ») : les cinq choses à apprendre d'une espèce ;
--   * ces deux bulles attendent leur tour (tour30.pending) : aucune visite en
--     cours, hors combat, compagnon à l'écran ; une étape peut cacher son
--     compteur (noStep) et son bouton « Passer » (noSkip) ; une visite peut
--     se passer sans message (quietSkip) et dire autre chose (onSkip).
local ADDON, ns = ...
if ns.blocked then return end
local L = ns.L
local Theme = ns.Theme

-- départ automatique (coupé dans le banc de test, comme le tirage des missions)
ns.TOUR_AUTO = ns.TOUR_AUTO ~= false
ns.TOUR = {
	w = 290, wideW = 360, pad = 12, gap = 10, titleH = 16, button = Theme.BUTTON_SIZES.sm, nextW = 112, skipW = 140,
	tick = 0.1,            -- s entre deux lectures des conditions (pas à chaque image)
	missingWait = 3,       -- s qu'une étape attend son ancre avant de passer
	migrationDelay = 6,    -- s après la connexion avant l'explication de la migration
	pulse = 1.6,           -- s d'un battement du liseré
	outset = 4,            -- px du liseré autour de l'ancre
	strata = "FULLSCREEN_DIALOG",
}
local TOUR = ns.TOUR
-- Sobre : sur le fond du socle (Theme.WINDOW), contrastes mesurés dans le test
ns.TOUR_SOBRE = { title = Theme.PARCHMENT, text = Theme.TEXT, step = Theme.MUTED_LIGHT, ring = Theme.GOLD_LIGHT }
-- 3.1.0 : thème forgé (jetons de rôle du socle, lus par référence : posés
-- par Theme.ApplySkin) : titre et liseré en couleur d'identité ; fond du
-- bandeau du socle (Theme.WINDOW à `alpha`), contrastes dans
-- tests/modules/forge_bandeaux.lua
ns.TOUR_FORGE = { title = Theme.TITLE, step = Theme.MUTED_LIGHT, ring = Theme.IDENTITY_LIGHT, ringInner = Theme.IDENTITY,
	alpha = 0.97 }

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
	-- 3.6.0 : capture express (active par défaut)
	TOUR_A1X             = "Le filet n'apparaît que quand ça vaut le coup : espèce nouvelle, brillante, ou meilleur spécimen que le tien. Clic : lancer. Maj + clic : toute la file. Ctrl + clic : la carte de préparation, pour choisir une aide.",
	TOUR_A3_T            = "Lancer ou passer",
	TOUR_A3              = "Lancer : le filet part. Passer : le monstre sort du filet (clic droit : ne plus proposer l'espèce). Avec la capture express (active par défaut), un clic sur le filet lance tout de suite et Ctrl + clic rouvre cette carte.",
	TOUR_A4_T            = "Où va ta prise ?",
	TOUR_A4_codex        = "Capturé ! C'est ton meilleur spécimen de l'espèce : il va au Codex. Les suivants, s'ils ne le battent pas, iront dans ta Réserve. Clic droit sur ton compagnon : le carnet.",
	TOUR_A4_reserve      = "Capturé ! Ton Codex avait déjà mieux : ce spécimen rejoint ta Réserve. Clic droit sur ton compagnon : le carnet, pour voir Codex et Réserve.",
	TOUR_A4_fail         = "Il s'est échappé, ça arrive. Réussie, une capture va au Codex (ton meilleur de chaque espèce) ou dans ta Réserve. Clic droit sur ton compagnon : le carnet.",
	TOUR_A5_T            = "Le mode chasse",
	TOUR_A5              = "Maj + clic droit sur ton compagnon : le mode chasse. De 5 min à 1 h, chaque monstre abattu va au filet. Méfiance : chaque capture d'une même espèce dans la journée rend la suivante plus dure.",
	-- visite du carnet (titres : le nom de l'onglet)
	TOUR_B_evolution     = "Ton compagnon : son humeur, ses trois états (Repu, Reposé, Éveillé), son envie du moment et ses effets. « Choisir… » change son allure.",
	TOUR_B_menagerie     = "Le Codex : ton meilleur spécimen de chaque espèce. « À compléter » montre ce qui manque ; épingle une espèce pour qu'elle passe toujours au filet, « Localiser » dit où la trouver.",
	TOUR_B_reserve       = "Tes spécimens en plus. « Mettre au Codex » en fait ta référence ; « Relâcher » rend des paillettes, à dépenser à l'Échoppe du dresseur (onglet suivant). Chaque spécimen a son caractère (un petit effet quand ton compagnon le porte) et sa taille : un minuscule ou un géant, c'est rare ! Et pour échanger avec un autre joueur : /qc echange <nom> (vue Échanges).",
	TOUR_B_shop          = "Tes paillettes s'y dépensent : aides de capture, places de Réserve, allure du compagnon. Ton solde est en haut à droite ; un article hors de portée te dit ce qui manque.",
	TOUR_B_feats         = "Tes hauts faits et leurs points : certains donnent des titres et des apparences pour ton compagnon.",
	TOUR_B_day           = "Trois missions par jour et trois par semaine : friandises, aides et paillettes à la clé.",
	TOUR_B_progress      = "Chaque zone : lieux, récolte, quêtes. « n à compléter » compte les espèces de la zone sans 3 étoiles au Codex.",
	TOUR_B_juke          = "La musique du jeu : écoute, mets en favoris, fais ta liste.",
	TOUR_B_guide         = "Tout est expliqué ici, avec les chiffres. En bas à gauche, deux boutons rejouent ces tutoriels.",
	TOUR_B_addons        = "L'autre addon du projet, Ready2Quest : s'il est là, et ce que les deux font ensemble.",
	-- ta collection d'avant la 3.0
	TOUR_MIG_T           = "Ta collection passe en 3.0",
	TOUR_MIG             = "Tes créatures capturées avant la 3.0 (%d espèces) sont devenues %d spécimens au Codex, dont %d brillants, gardés à part. Rien n'est perdu : apparences, hauts faits et page Créatures ne bougent pas ; ces spécimens portent la mention « %s ».\n\nDésormais, la qualité se tire au coup fatal et le filet ne vient que si ça vaut le coup : les réglages « Recaptures » ont disparu. Une nouvelle capture va au Codex si elle bat la tienne, sinon dans ta Réserve. À voir dans le carnet : Créatures et Réserve.",
	TOUR_MIG_GO          = "Visiter le carnet",
	TOUR_MIG_LATER       = "Plus tard",
	TOUR_MIG_GIFT        = "Et un cadeau t'attend : choisis jusqu'à %d de tes créatures, une copie de chacune ira dans ta Réserve.",
	TOUR_GIFT_T          = "Cadeau de la 3.0",
	TOUR_GIFT            = "Choisis jusqu'à %d créatures pour ta Réserve : une copie de chacune (version normale, mêmes étoiles que ton Codex), de quoi échanger plus tard. « Plus tard » : le bouton reste dans la page Réserve.",
	TOUR_GIFT_GO         = "Choisir mes créatures",
	-- 3.6.0 : après la toute première capture
	TOUR_MATE_T          = "On part ensemble ?",
	TOUR_MATE            = "Capturé : %s ! Emmène-le, il devient ton compagnon : plus tu voyages avec lui (route, friandises, caresses, quêtes, captures), plus ton lien avec lui grandit, et un lien fort lui donne des effets.",
	TOUR_MATE_GO         = "Partir avec lui",
	TOUR_MATE_LATER      = "Plus tard",
	TOUR_MATE_DONE       = "%s part avec toi : il est ton compagnon. La mascotte reste dans « Choisir… » (page Compagnon).",
	TOUR_MATE_SKIPPED    = "Plus tard, alors : page Créatures, un clic sur une créature capturée en fait ton compagnon.",
	-- 3.6.0 : la première tâche d'étude
	TOUR_STUDY_T         = "L'étude des espèces",
	TOUR_STUDY           = "Chaque espèce a cinq choses à apprendre : la capturer, en avoir une à 3 étoiles, 5 captures, 3 tailles, 3 caractères. Chaque tâche finie : %d paillettes ; les cinq, %d de plus. Regarde ses losanges, page Créatures.",
	TOUR_STUDY_OK        = "Compris",
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
	TOUR_A1X             = "The net only shows up when it's worth it: new species, shiny, or a better specimen than yours. Click: throw. Shift + click: the whole queue. Ctrl + click: the preparation card, to pick an aid.",
	TOUR_A3_T            = "Throw or skip",
	TOUR_A3              = "Throw: the net flies. Skip: the monster leaves the net (right-click: stop offering the species). With express capture (on by default), a click on the net throws right away and Ctrl + click brings this card back.",
	TOUR_A4_T            = "Where does it go?",
	TOUR_A4_codex        = "Captured! It's your best specimen of the species: it goes to the Codex. The next ones, unless they beat it, will go to your Reserve. Right-click your companion: the journal.",
	TOUR_A4_reserve      = "Captured! Your Codex already had better: this specimen joins your Reserve. Right-click your companion: the journal, to see Codex and Reserve.",
	TOUR_A4_fail         = "It got away, it happens. When it works, a capture goes to the Codex (your best of each species) or to your Reserve. Right-click your companion: the journal.",
	TOUR_A5_T            = "Hunt mode",
	TOUR_A5              = "Shift + right-click your companion: hunt mode. From 5 min to 1 h, every defeated monster goes to the net. Wariness: each capture of the same species in a day makes the next one harder.",
	TOUR_B_evolution     = "Your companion: its mood, its three states (Fed, Rested, Alert), its current wish and its effects. \"Choose…\" changes its look.",
	TOUR_B_menagerie     = "The Codex: your best specimen of each species. \"To complete\" shows what's missing; pin a species so it always comes to the net, \"Locate\" tells where to find it.",
	TOUR_B_reserve       = "Your extra specimens. \"Set in Codex\" makes one your reference; \"Release\" gives glitter, to spend at the Trainer's Stall (next tab). Each specimen has its own character (a small effect when your companion wears it) and size: a tiny or a giant one is rare! And to trade with another player: /qc trade <name> (Trades view).",
	TOUR_B_shop          = "Spend your glitter here: capture aids, Reserve slots, your companion's look. Your balance is at the top right; an item out of reach tells you what's missing.",
	TOUR_B_feats         = "Your achievements and their points: some grant titles and looks for your companion.",
	TOUR_B_day           = "Three missions a day and three a week: treats, aids and glitter as rewards.",
	TOUR_B_progress      = "Each zone: places, gathering, quests. \"n to complete\" counts the zone's species without 3 stars in the Codex.",
	TOUR_B_juke          = "The game's music: listen, add favourites, build your list.",
	TOUR_B_guide         = "Everything is explained here, with the numbers. Bottom left, two buttons replay these tutorials.",
	TOUR_B_addons        = "The project's other addon, Ready2Quest: whether it's there, and what the two do together.",
	TOUR_MIG_T           = "Your collection moves to 3.0",
	TOUR_MIG             = "Your creatures captured before 3.0 (%d species) became %d specimens in the Codex, including %d shinies, kept apart. Nothing is lost: looks, achievements and the Creatures page stay the same; these specimens are marked \"%s\".\n\nFrom now on, quality is rolled at the kill and the net only shows up when it's worth it: the \"Recaptures\" settings are gone. A new capture goes to the Codex if it beats yours, otherwise to your Reserve. See it in the journal: Creatures and Reserve.",
	TOUR_MIG_GO          = "Visit the journal",
	TOUR_MIG_LATER       = "Later",
	TOUR_MIG_GIFT        = "And a gift awaits: pick up to %d of your creatures, a copy of each goes to your Reserve.",
	TOUR_GIFT_T          = "3.0 gift",
	TOUR_GIFT            = "Pick up to %d creatures for your Reserve: a copy of each (normal version, same stars as your Codex), something to trade later. \"Later\": the button stays on the Reserve page.",
	TOUR_GIFT_GO         = "Pick my creatures",
	TOUR_MATE_T          = "Shall we go together?",
	TOUR_MATE            = "Captured: %s! Take it along, it becomes your companion: the more you travel together (roads, treats, pats, quests, captures), the more your bond grows, and a strong bond gives it effects.",
	TOUR_MATE_GO         = "Take it along",
	TOUR_MATE_LATER      = "Later",
	TOUR_MATE_DONE       = "%s comes with you: it is your companion now. The mascot stays in \"Choose…\" (Companion page).",
	TOUR_MATE_SKIPPED    = "Later, then: on the Creatures page, a click on a captured creature makes it your companion.",
	TOUR_STUDY_T         = "Studying species",
	TOUR_STUDY           = "Each species has five things to learn: capture it, get a 3-star one, 5 catches, 3 sizes, 3 personalities. Each task done: %d glitter; all five, %d more. Look at its diamonds, Creatures page.",
	TOUR_STUDY_OK        = "Got it",
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

-- 3.6.0 : la capture express est-elle le déroulé ? (réglage, capture allumée)
local function Express(self)
	return self.CaptureExpressOn ~= nil and self:CaptureExpressOn() and true or false
end
-- les étapes de la carte : sans capture express, ou carte ouverte d'un Ctrl + clic
local function CardStep(self, ctx)
	return not ctx.thrown and (not Express(self) or Stage() ~= nil)
end

local DEFS = {}
ns.TOUR_DEFS = DEFS

DEFS.capture = {
	steps = {
		{ id = "net", anchor = function() return ns.captureNetButton end, title = "TOUR_A1_T",
			text = function(self) return Express(self) and L.TOUR_A1X or L.TOUR_A1 end,
			placement = "top", noNext = true, pulseNet = true,
			waitFor = function(_, ctx) return ctx.thrown or Stage() ~= nil end,
			-- le monstre est parti avant le clic : on reprendra à l'occasion suivante
			abort = function(_, ctx)
				if not ctx.thrown and QueueCount() == 0 and not Stage() and not Rolling() then return "stop" end
			end },
		{ id = "card", anchor = function() local f = Stage(); return f and f.details end, title = "TOUR_A2_T", text = "TOUR_A2",
			placement = "right", when = CardStep },
		{ id = "launch", anchor = function() local f = Stage(); return f and f.launch end, title = "TOUR_A3_T", text = "TOUR_A3",
			placement = "bottom", noNext = true, when = CardStep },
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
		-- 3.0.0 : l'Échoppe du dresseur a son onglet, donc son étape
		JournalTab("evolution"), JournalTab("menagerie"), JournalTab("reserve"), JournalTab("shop"), JournalTab("feats"),
		JournalTab("day"), JournalTab("progress"), JournalTab("juke"), JournalTab("guide"),
		-- 3.0.1 : Addons liés (déjà vue : la visite ne repart pas)
		JournalTab("addons"),
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

-- 3.6.0 : les bulles qui attendent leur tour (au compte) : tour30.pending =
-- { mate = { npc, shiny, name }, study = true }
local function Pending(self)
	local data = self:TourData()
	if type(data.pending) ~= "table" then data.pending = {} end
	return data.pending
end
ns.TourPendingData = Pending

-- « Partir avec lui » : l'apparence de la capture (« cap:<npc>[:s] »)
local function MateLook(mate)
	return "cap:" .. tostring(mate.npc) .. (mate.shiny and ":s" or "")
end
local function MateName(self, mate)
	local name = mate.name
	if self.CreatureName then name = self:CreatureName(mate.npc) or name end
	if mate.shiny and self.F then name = self:F("CAPTURE_SHINY_TAG", tostring(name or "?")) end
	return tostring(name or "?")
end

DEFS.mate = {
	quietSkip = true,
	steps = {
		{ id = "mate", anchor = function() return ns.companionFrame end, fallback = true, placement = "top",
			highlight = false, noStep = true, wide = true, title = "TOUR_MATE_T",
			text = function(self) return self:F("TOUR_MATE", MateName(self, self.tourMate or {})) end,
			nextLabel = "TOUR_MATE_GO", skipLabel = "TOUR_MATE_LATER" },
	},
	finish = function(self)
		local mate = self.tourMate
		self.tourMate = nil
		if not (mate and self.CompanionSetAppearance) then return end
		if self:CompanionSetAppearance(MateLook(mate)) then
			if self.CompanionFx then pcall(self.CompanionFx, self, "hearts") end
			self:Print(self:F("TOUR_MATE_DONE", MateName(self, mate)))
		end
	end,
	onSkip = function(self)
		self.tourMate = nil
		self:Print(L.TOUR_MATE_SKIPPED)
	end,
}

DEFS.study = {
	quietSkip = true,
	steps = {
		{ id = "study", anchor = function() return ns.companionFrame end, fallback = true, placement = "top",
			highlight = false, noStep = true, noSkip = true, wide = true, title = "TOUR_STUDY_T",
			text = function(self)
				local reward = ns.STUDY_REWARD or { task = 2, mastered = 5 }
				return self:F("TOUR_STUDY", reward.task or 2, reward.mastered or 5)
			end,
			nextLabel = "TOUR_STUDY_OK" },
	},
}

-- ---------------------------------------------------------------------------
-- La bulle et le liseré (un jeu par style, créé une fois)
-- ---------------------------------------------------------------------------
local function TourStyle(self)
	return "sobre"
end

local function Paint(fs, color)
	fs:SetTextColor(color[1], color[2], color[3], 1)
end

local function BuildCallout(self, style, key)
	-- 3.1.0 : un nom par clé (ns:StyleKey : forgé, Sobre)
	key = key or style
	local name = ns.StyleName and ns.StyleName("QuestCompanionTourCallout", key) or "QuestCompanionTourCallout"
	local frame = CreateFrame("Frame", name, UIParent)
	frame.styleKey = key
	frame:SetSize(TOUR.w, 120)
	frame:SetFrameStrata(TOUR.strata)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame.uiStyle = style
	if key == "forge" and Theme.SkinToast then
		-- 3.1.0 : thème forgé : la bulle est un bandeau du socle (ombre, cadre
		-- d'orfèvre, sans barre d'accent), son titre en couleur d'identité
		Theme.SkinToast(frame, { accent = false, alpha = ns.TOUR_FORGE.alpha })
		frame.edge = frame.border
		frame.forgeTour = true
	else
		frame.bg = Theme.Solid(frame, "BACKGROUND", Theme.WINDOW, 0.97)
		frame.bg:SetAllPoints(frame)
		frame.edge = Theme.Border(frame, Theme.GOLD, 1, "BORDER")
	end
	frame.title = Theme.Text(frame, frame.forgeTour and Theme.F_CAPS or Theme.F_LABEL, ns.TOUR_SOBRE.title)
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
	Paint(frame.title, ns.TOUR_SOBRE.title)
	Paint(frame.step, ns.TOUR_SOBRE.step)
	Paint(frame.text, ns.TOUR_SOBRE.text)
	if frame.forgeTour then
		local F = ns.TOUR_FORGE
		frame.title:SetTextColor(F.title[1], F.title[2], F.title[3], 1)
		frame.step:SetTextColor(F.step[1], F.step[2], F.step[3], 1)
	end
	local function Next() ns:TourNext() end
	local function Skip() ns:TourSkip() end
	frame.nextButton = Theme.CreateButton(frame, TOUR.nextW, TOUR.button, L.TOUR_NEXT, Next, "primary")
	frame.skipButton = Theme.CreateButton(frame, TOUR.skipW, TOUR.button, L.TOUR_SKIP, Skip, "outline")
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

local function BuildRing(style, key)
	-- 3.1.0 : thème forgé : le liseré de la cible en couleur d'identité
	local forge = key == "forge"
	local ring = CreateFrame("Frame", nil, UIParent)
	ring:SetFrameStrata(TOUR.strata)
	ring:EnableMouse(false)
	local outer = (forge and ns.TOUR_FORGE.ring) or ns.TOUR_SOBRE.ring
	ring.outer = Theme.Border(ring, outer, 1, "OVERLAY")
	ring.inner = CreateFrame("Frame", nil, ring)
	ring.inner:SetPoint("TOPLEFT", ring, "TOPLEFT", 1, -1)
	ring.inner:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", -1, 1)
	ring.innerEdge = Theme.Border(ring, forge and ns.TOUR_FORGE.ringInner or Theme.GOLD, 1, "OVERLAY", ring.inner)
	ring.forge = forge or nil
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
	-- 3.1.0 : un jeu par clé (une bulle née forgée ne sert pas en Sobre)
	local key = self.StyleKey and self:StyleKey() or style
	self.tourUI = self.tourUI or {}
	local ui = self.tourUI[key]
	if not ui then
		ui = { callout = BuildCallout(self, style, key), ring = BuildRing(style, key), style = style, key = key }
		self.tourUI[key] = ui
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
	callout.step:SetText(step.noStep and "" or self:F("TOUR_STEP", StepNumber(st), st.total))
	local last = st.index >= #st.def.steps
	callout.nextButton:SetText(step.nextLabel and Resolve(self, step.nextLabel, st.ctx) or (last and L.TOUR_DONE or L.TOUR_NEXT))
	callout.skipButton:SetText(step.skipLabel and Resolve(self, step.skipLabel, st.ctx) or L.TOUR_SKIP)
	if step.noNext then callout.nextButton:Hide() else callout.nextButton:Show() end
	if step.noSkip then callout.skipButton:Hide() else callout.skipButton:Show() end
	local textH = Theme.TextHeight and Theme.TextHeight(callout.text, inner, Theme.F_BODY) or 40
	local height = TOUR.pad + TOUR.titleH + 6 + math.ceil(tonumber(textH) or 40) + TOUR.gap + TOUR.button + TOUR.pad
	callout:SetHeight(height)
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
		if st.def.onSkip then
			local ok, err = pcall(st.def.onSkip, self)
			if not ok and self.RecordError then self:RecordError("tour:skip", err) end
		elseif st.id ~= "migration" and not st.def.quietSkip then
			self:Print(L.TOUR_MSG_SKIPPED)
		end
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
	if not self.tourState and not self.tourPending and not InCombat() then self:TourPendingStart() end
	if self.tourState then self:TourEvaluate() end
	local idle = not self.tourState and not self.tourPending and not self.tourMigrationAt and not self:TourHasPending()
	if idle and driver then driver:Hide() end
	return self.tourState ~= nil
end

-- ---------------------------------------------------------------------------
-- 3.6.0 : les bulles qui attendent leur tour (après la première capture,
-- à la première tâche d'étude)
-- ---------------------------------------------------------------------------
function ns:TourHasPending()
	local data = self:DB().tour30
	local pending = type(data) == "table" and data.pending
	return type(pending) == "table" and next(pending) ~= nil
end

-- Une bulle en attente : `id` (mate, study), `info` (mate : le spécimen).
-- Déjà vue : rien. Le relevé la montre dès que la place est libre.
function ns:TourQueue(id, info)
	if not DEFS[id] or self:TourDone(id) then return false end
	Pending(self)[id] = info or true
	if driver then driver:Show() end
	return true
end

-- La suivante, si rien n'occupe la place : compagnon à l'écran, aucun
-- tutoriel de base, aucune visite ; « Partir avec lui » d'abord
local PENDING_ORDER = { "mate", "study" }
function ns:TourPendingStart()
	if not ns.TOUR_AUTO or self.tourState or not self:TourHasPending() then return false end
	if self.CompanionTutorialActive and self:CompanionTutorialActive() then return false end
	if not Visible(self.companionFrame) then return false end
	local pending = Pending(self)
	for _, id in ipairs(PENDING_ORDER) do
		local info = pending[id]
		if info ~= nil then
			pending[id] = nil
			if not self:TourDone(id) then
				if id == "mate" then
					-- déjà parti avec une capture (ou l'apparence refusée) : rien à proposer
					local look = type(info) == "table" and MateLook(info)
					local current = self.CompanionData and tostring(self:CompanionData().appearance or "") or ""
					if not look or current:find("^cap:") then self:TourMark("mate", true); return false end
					self.tourMate = info
				end
				-- la bulle du compagnon s'efface : la nôtre prend sa place
				if self.CompanionHideBubble then pcall(self.CompanionHideBubble, self) end
				return self:TourStart(id)
			end
		end
	end
	return false
end

-- La toute première capture du compte (une espèce nouvelle, la première du
-- Codex) : « Partir avec lui », une fois. Un compte qui avait déjà des
-- créatures ne la verra pas.
do
	local resolve = ns.CaptureResolve
	if resolve then
		function ns:CaptureResolve(rolling, ...)
			local a, b, c = resolve(self, rolling, ...)
			local target = type(rolling) == "table" and rolling.target
			if rolling and rolling.success and target and target.npcID and not self:TourDone("mate") then
				local count = self.CaptureData and tonumber(self:CaptureData().count) or 0
				if count > 1 then
					self:TourMark("mate", true)
				elseif count == 1 then
					self:TourQueue("mate", { npc = target.npcID, shiny = target.shiny and true or nil, name = target.name })
				end
			end
			return a, b, c
		end
	end
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
		-- 3.1.0 : événements sur le cadre commun de l'addon (ns.On,
		-- Libs/Socle/Compat.lua) ; ce cadre garde le relevé (OnUpdate)
		ns.On("PLAYER_REGEN_DISABLED", "tour", function() ns:TourPause() end)
		ns.On("PLAYER_REGEN_ENABLED", "tour", function()
			Wake()
			if ns.tourState or ns.tourPending or ns:TourHasPending() then frame:Show() end
		end)
		ns.On("PLAYER_ENTERING_WORLD", "tour", function(isLogin, isReload)
			if not ((isLogin or isReload) and ns.TOUR_AUTO) then return end
			-- 3.6.0 : une bulle restée en attente avant le /reload
			if ns:TourHasPending() then frame:Show() end
			-- une fois, au compte : ce que sont devenues les créatures d'avant la 3.0
			local okCount, pending = pcall(MigrationPending, ns)
			if okCount and pending then
				ns.tourMigrationAt = Clock() + TOUR.migrationDelay
				frame:Show()
			end
		end)
		frame:SetScript("OnUpdate", function(f, elapsed)
			if not (ns.tourState or ns.tourPending or ns.tourMigrationAt or ns:TourHasPending()) then return end
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
